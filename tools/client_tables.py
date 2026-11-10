"""The client tables Amisia's builders read, and which copy of each table they read (D-101).

    python3 tools/client_tables.py [--out DIR]     lays the choice out and prints it

Three folders hold copies of the client tables, each file named <Table>.<version>.csv (the name the
CSV exports of wago.tools carry; a file <Table>.csv without a version counts as the oldest):

  export      ~/addons/_wago             the user's own export on the PC (tools/export_db2.ps1, Syncthing)
  wago.tools  ~/addons/_cache/wago       the CSV exports of wago.tools (tools/fetch_tables.py)
  att         <ATT cache>/.config/.wago  the few tables AllTheThings ships (tools/att_data.py)

choose() takes per table the file of the highest version; at the same version the one with more rows
(the user's export of a build lacks the rows of sections the client keeps encrypted, the copies of the
other two have them); a file without any row counts only when no file of the table has rows.
chosen_dir() lays that choice out as a folder of links, one <Table>.<version>.csv per table
(~/addons/_cache/wago_chosen), and writes what it chose into chosen.txt there. Every builder reads
that folder when it is given no --wago folder; an explicit folder still wins. Nothing here touches the
network: only tools/fetch_tables.py (`build.py tables`) does.

TABLES is the one list of the tables the builders read: the lists of tools/export_db2.ps1
($RequiredTables, $OptionalTables, $TalentTables), which the PC's export and tools/fetch_tables.py
both ask for (tools/tests/test_client_tables.py checks that every builder's tables are in it).
"""
import argparse
import csv
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT_SCRIPT = os.path.join(HERE, 'export_db2.ps1')
EXPORT = os.path.expanduser('~/addons/_wago')
FETCHED = os.path.expanduser('~/addons/_cache/wago')
CHOSEN = os.path.expanduser('~/addons/_cache/wago_chosen')
REPORT = 'chosen.txt'
ROWS_CACHE = '.rows.json'

FILE = re.compile(r'^([A-Za-z0-9_]+?)(?:\.(\d+(?:\.\d+)*))?\.csv$')


def att_dir():
    """The tables AllTheThings ships, in the ATT download the builders read ($AMISIA_ATT_CACHE honoured
    at the time of the call: `build.py data --att DIR` sets it)."""
    base = os.path.expanduser(os.environ.get('AMISIA_ATT_CACHE') or '~/addons/_cache/att')
    return os.path.join(base, '.config', '.wago')


def sources():
    """(label, folder) of the three places, in the order a tie of version and rows is broken."""
    return [('export', EXPORT), ('wago.tools', FETCHED), ('att', att_dir())]


def _ps_array(text, name):
    m = re.search(r'^\$' + name + r' = @\((.*?)^\)', text, re.S | re.M)
    if not m:
        return []
    out = []
    for line in m.group(1).split('\n'):
        out += re.findall(r"'([A-Za-z0-9_]+)'", line.split('#')[0])
    return out


def read_tables(script=EXPORT_SCRIPT):
    """Every table of the lists of tools/export_db2.ps1, each once, in the script's order."""
    try:
        with open(script, encoding='utf-8') as fh:
            text = fh.read()
    except OSError:
        return []
    names = []
    for arr in ('RequiredTables', 'OptionalTables', 'TalentTables'):
        names += _ps_array(text, arr)
    return list(dict.fromkeys(names))


TABLES = read_tables()


def version_key(version):
    return tuple(int(x) for x in version.split('.')) if version else ()


def count_rows(path):
    """The data rows of a CSV file (a quoted field may span lines); -1 when it cannot be read."""
    try:
        with open(path, encoding='utf-8-sig', newline='') as fh:
            return max(0, sum(1 for _ in csv.reader(fh)) - 1)
    except (OSError, UnicodeDecodeError, csv.Error):
        return -1


class Rows:
    """Row counts of files, kept by path, size and time in a small JSON file (counting ItemSparse
    takes a second; the choice is made before every build)."""

    def __init__(self, path=None):
        self.path, self.data, self.dirty = path, {}, False
        if path:
            try:
                with open(path, encoding='utf-8') as fh:
                    self.data = json.load(fh)
            except (OSError, ValueError):
                self.data = {}

    def __call__(self, path):
        st = os.stat(path)
        key = os.path.realpath(path)
        rec = self.data.get(key)
        if rec and rec[0] == st.st_size and rec[1] == st.st_mtime_ns:
            return rec[2]
        n = count_rows(path)
        self.data[key] = [st.st_size, st.st_mtime_ns, n]
        self.dirty = True
        return n

    def save(self):
        if self.path and self.dirty:
            tmp = self.path + '.tmp%d' % os.getpid()
            with open(tmp, 'w', encoding='utf-8') as fh:
                json.dump(self.data, fh, indent=0, sort_keys=True)
            os.replace(tmp, self.path)
            self.dirty = False


def files_of(folder):
    """{table: [(version, path), ...]} of the client table files in folder."""
    out = {}
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return out
    for name in names:
        m = FILE.match(name)
        path = os.path.join(folder, name)
        if m and os.path.isfile(path):
            out.setdefault(m.group(1), []).append((m.group(2) or '', path))
    return out


def choose(table, srcs=None, rows=None, listing=None):
    """The copy of table the builders read: a dict with table, version, rows, source, path and
    others (the newest file of each other source, with its version and rows, for the report), or None
    when no source has the table. Highest version first; at the same version more rows; a file with
    no row only when no file has rows; a last tie goes to the order of sources()."""
    srcs = sources() if srcs is None else srcs
    rows = rows or Rows()
    listing = listing if listing is not None else {folder: files_of(folder) for _, folder in srcs}
    cands = []
    for rank, (label, folder) in enumerate(srcs):
        for version, path in listing.get(folder, {}).get(table, []):
            cands.append({'table': table, 'version': version, 'source': label, 'path': path, 'rank': rank})
    if not cands:
        return None
    by_version = {}
    for c in cands:
        by_version.setdefault(version_key(c['version']), []).append(c)
    best = None
    for key in sorted(by_version, reverse=True):
        group = by_version[key]
        for c in group:
            c['rows'] = rows(c['path'])
        group.sort(key=lambda c: (-c['rows'], c['rank']))
        if group[0]['rows'] > 0:
            best = group[0]
            break
        best = best or group[0]
    # the newest file of every other source, so the report can say what lost and a smaller table shows
    others = []
    for label, folder in srcs:
        own = [c for c in cands if c['source'] == label] if label != best['source'] else []
        if not own:
            continue
        top = max(own, key=lambda c: version_key(c['version']))
        if 'rows' not in top:
            top['rows'] = rows(top['path'])
        others.append({k: top[k] for k in ('source', 'version', 'rows', 'path')})
    out = {k: best[k] for k in ('table', 'version', 'rows', 'source', 'path')}
    out['others'] = others
    # fewer rows than an older copy: worth a look before the data ships (a cut export, a broken download)
    out['fewer'] = [o for o in others if o['rows'] > best['rows']]
    return out


def choose_all(srcs=None, rows=None, tables=None):
    """{table: choice} for every table any source has (or only those of tables)."""
    srcs = sources() if srcs is None else srcs
    listing = {folder: files_of(folder) for _, folder in srcs}
    names = set()
    for files in listing.values():
        names.update(files)
    if tables is not None:
        names &= set(tables)
    rows = rows or Rows()
    return {t: choose(t, srcs, rows, listing) for t in sorted(names)}


def report_lines(chosen):
    """One line per table: name, version, rows, where from; a warning where an older copy has more rows."""
    lines = []
    for t in sorted(chosen):
        c = chosen[t]
        if not c:
            continue
        others = ', '.join(f'{o["source"]} {o["version"] or "-"} {o["rows"]}' for o in c['others'])
        lines.append(f'{t:<28} {c["version"] or "-":<14} {c["rows"]:>7} rows  {c["source"]:<10}'
                     + (f'  (also: {others})' if others else ''))
        for o in c['fewer']:
            lines.append(f'  WARNING {t}: {o["source"]} {o["version"] or "-"} has {o["rows"]} rows, '
                         f'more than the {c["rows"]} of the newest ({c["source"]} {c["version"] or "-"})')
    return lines


def missing_wanted(chosen, wanted=None):
    """The tables of TABLES (or wanted) no source has."""
    return [t for t in (TABLES if wanted is None else wanted) if not chosen.get(t)]


def chosen_dir(dest=CHOSEN, srcs=None, log=None):
    """Lays the choice out in dest: one link <Table>.<version>.csv per table to the chosen file (other
    CSV files there are removed) and chosen.txt with report_lines(). Returns dest. Safe to run twice at
    once: every link is replaced in one step and both runs write the same."""
    os.makedirs(dest, exist_ok=True)
    rows = Rows(os.path.join(dest, ROWS_CACHE))
    chosen = choose_all(srcs, rows)
    rows.save()
    want = {}
    for t, c in chosen.items():
        if c:
            want[f'{t}.{c["version"]}.csv' if c['version'] else f'{t}.csv'] = os.path.abspath(c['path'])
    for name in os.listdir(dest):
        if name.endswith('.csv') and name not in want:
            try:
                os.remove(os.path.join(dest, name))
            except OSError:
                pass
    for name, target in want.items():
        link = os.path.join(dest, name)
        if os.path.islink(link) and os.readlink(link) == target:
            continue
        tmp = f'{link}.tmp{os.getpid()}'
        if os.path.lexists(tmp):
            os.remove(tmp)
        os.symlink(target, tmp)
        os.replace(tmp, link)
    lines = report_lines(chosen)
    miss = missing_wanted(chosen)
    if miss:
        lines.append('no source has: ' + ', '.join(miss))
    text = '\n'.join(lines) + '\n'
    path = os.path.join(dest, REPORT)
    try:
        with open(path, encoding='utf-8') as fh:
            same = fh.read() == text
    except OSError:
        same = False
    if not same:
        tmp = f'{path}.tmp{os.getpid()}'
        with open(tmp, 'w', encoding='utf-8') as fh:
            fh.write(text)
        os.replace(tmp, path)
    if log:
        for line in lines:
            log(line)
    return dest


def default_dir():
    """The folder a builder reads when it is given no --wago: the choice laid out (chosen_dir())."""
    return chosen_dir()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--out', default=CHOSEN, help=f'the folder of links (default {CHOSEN})')
    args = ap.parse_args(argv)
    print(f'client tables chosen from {", ".join(f"{lab} {d}" for lab, d in sources())}:')
    chosen_dir(args.out, log=print)
    print(f'laid out in {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
