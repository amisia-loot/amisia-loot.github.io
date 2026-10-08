"""The scan archive: everything the addon's item scan and item collector ever delivered, kept on the
N100, and the marker the addon gets of it.

    python3 tools/build_scan_archive.py [update] [--sv FILE...] [--wago DIR] [--archive FILE] [--marker FILE]
    python3 tools/build_scan_archive.py marker [--archive FILE] [--marker FILE]

`AmisiaDB.scan` (`items` from /amisia scan and the collector, `sources` the collector's notes, `suffix`
the random suffixes seen on links) exists only to reach the N100 through Syncthing. It is big: the
SavedVariables of 2026-10-07 were 2.3 MB and cost about 7 MB of Lua memory at every login. So:

- `update` (the default; `build.py data` runs it first) merges the scan of the SavedVariables
  (`--sv`, default `~/addons/_SavedVariables/Amisia.lua` and an installed Forever client's file) into
  `tools/scan_archive.json` (committed): an item's line of the SavedVariables replaces the archive's
  (newer wins), notes and suffixes are joined, nothing is ever dropped. With the client table
  ItemSparse in `--wago` it also keeps the ids the client knows (as ranges). Then it writes the marker.
- The marker `addon/Amisia/Data/ScanDone.lua` (lazy, `ns.Data("SCAN_DONE")`) says what the archive
  holds: per item id a hash of its line, per item the hashes of its notes, the ids the client's
  ItemSparse knows, and a stamp. The addon (Collect/ScanTrim.lua) removes from `scan.items`,
  `scan.sources` and `scan.retry` only what the marker covers, so its file keeps only what is new.
- The builds (build_scan.py full, build_gear.py, build_bis.py) read the archive and the
  SavedVariables together (`with_archive`, `overlay`), so a trimmed file builds the same data.

The hash is the addon's (ScanTrim.lua): h = (h * 31 + byte) % 1000000007 over the UTF-8 bytes,
written in base 36. Requires lupa (to read SavedVariables).
"""
import argparse
import csv
import datetime
import glob
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

ARCHIVE = os.path.join(HERE, 'scan_archive.json')
MARKER = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'ScanDone.lua')
DEFAULT_SV = os.path.expanduser('~/addons/_SavedVariables/Amisia.lua')
WAGO = os.path.expanduser('~/addons/_wago')
WOW_ROOT = os.environ.get('AMISIA_WOW_ROOT', r'C:\Program Files (x86)\World of Warcraft')
HASH_MOD = 1000000007
MAX_ID = 9999999

ABOUT = ('Amisia scan archive (tools/build_scan_archive.py): every item line of /amisia scan and the collector '
         '(items), the collector notes (sources) and random suffixes (suffix) any SavedVariables delivered; '
         'client: the ids the client table ItemSparse knows, as ranges. Never edit by hand.')


# ---------------------------------------------------------------- archive
def empty():
    return {'v': 1, 'updated': '', 'client': None, 'items': {}, 'sources': {}, 'suffix': {}}


def _pairs(v):
    """(key, value) of a table lupa gave as a list (keys 1..n) or a dict."""
    if isinstance(v, list):
        return enumerate(v, 1)
    if isinstance(v, dict):
        return v.items()
    return ()


def _id(k):
    try:
        k = int(k)
    except (TypeError, ValueError):
        return None
    return k if 1 <= k <= MAX_ID else None


def load(path=ARCHIVE):
    """The archive with int keys, or an empty one when the file does not exist."""
    arch = empty()
    if not path or not os.path.exists(path):
        return arch
    with open(path, encoding='utf-8') as fh:
        raw = json.load(fh)
    arch['updated'] = str(raw.get('updated') or '')
    arch['client'] = raw.get('client') or None
    for k, v in (raw.get('items') or {}).items():
        if _id(k) and isinstance(v, str):
            arch['items'][_id(k)] = v
    for k, v in (raw.get('sources') or {}).items():
        if _id(k) and isinstance(v, list):
            arch['sources'][_id(k)] = [str(x) for x in v if isinstance(x, str) and x]
    for k, v in (raw.get('suffix') or {}).items():
        if _id(k) and isinstance(v, dict):
            arch['suffix'][_id(k)] = {int(s): t for s, t in v.items() if str(s).lstrip('-').isdigit() and isinstance(t, str)}
    return arch


def text(arch):
    """The archive as the committed file: one entry per line, ids in order, so a diff shows what came."""
    out = ['{', f'"v": 1,', f'"about": {json.dumps(ABOUT)},', f'"updated": {json.dumps(arch["updated"])},',
           f'"client": {json.dumps(arch["client"], sort_keys=True)},']
    parts = (('items', arch['items']), ('sources', arch['sources']), ('suffix', arch['suffix']))
    for i, (key, val) in enumerate(parts):
        out.append(f'"{key}": {{')
        ids = sorted(val)
        for n, k in enumerate(ids):
            v = val[k]
            if key == 'suffix':
                v = {str(s): v[s] for s in sorted(v)}
            out.append(f'{json.dumps(str(k))}: {json.dumps(v, ensure_ascii=False)}' + (',' if n < len(ids) - 1 else ''))
        out.append('}' + (',' if i < 2 else ''))
    out.append('}')
    return '\n'.join(out) + '\n'


def save(path, arch):
    """Writes the archive when it changed; True then."""
    new = text(arch)
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            if fh.read() == new:
                return False
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(new)
    return True


def absorb(arch, db):
    """Merges the scan of one SavedVariables table into the archive: an item line of the file replaces
    the archive's (the file is newer), notes and suffixes are joined (a suffix's stats of the file win).
    Returns the counts of what was new or changed."""
    stats = {'items': 0, 'changed': 0, 'sources': 0, 'suffix': 0}
    scan = (db or {}).get('scan') if isinstance(db, dict) else None
    if not isinstance(scan, dict):
        return stats
    for k, line in _pairs(scan.get('items')):
        k = _id(k)
        if not k or not isinstance(line, str) or not line:
            continue
        old = arch['items'].get(k)
        if old is None:
            stats['items'] += 1
        elif old != line:
            stats['changed'] += 1
        arch['items'][k] = line
    for k, notes in _pairs(scan.get('sources')):
        k = _id(k)
        if not k:
            continue
        have = arch['sources'].setdefault(k, [])
        for note in (notes if isinstance(notes, list) else [notes]):
            note = str(note).strip() if isinstance(note, str) else ''
            if note and note not in have:
                have.append(note)
                stats['sources'] += 1
        if not have:
            del arch['sources'][k]
    for k, seen in _pairs(scan.get('suffix')):
        k = _id(k)
        if not k:
            continue
        for s, t in _pairs(seen):
            try:
                s = int(s)
            except (TypeError, ValueError):
                continue
            if s and isinstance(t, str) and t:
                have = arch['suffix'].setdefault(k, {})
                if have.get(s) != t:
                    stats['suffix'] += 1
                have[s] = t
    return stats


def as_db(arch):
    """The archive in the shape of a SavedVariables table (only `scan`), for the builds' readers."""
    return {'scan': {'items': dict(arch['items']), 'sources': {k: list(v) for k, v in arch['sources'].items()},
                     'suffix': {k: dict(v) for k, v in arch['suffix'].items()}}}


def with_archive(dbs, path=ARCHIVE):
    """The SavedVariables tables with the archive in front (the files after it win, build_scan.collect
    takes the later item line), or dbs as they are when there is no archive."""
    if not path or not os.path.exists(path):
        return list(dbs)
    return [as_db(load(path))] + list(dbs)


def overlay(sv, path=ARCHIVE):
    """One SavedVariables table (or None) with its scan joined to the archive's (the file wins)."""
    if not path or not os.path.exists(path):
        return sv
    arch = load(path)
    absorb(arch, sv)
    out = dict(sv) if isinstance(sv, dict) else {}
    out['scan'] = dict((sv or {}).get('scan') or {}, **as_db(arch)['scan'])
    return out


# ---------------------------------------------------------------- client ids
def client_ids(wago):
    """(build, sorted ids) of the client table ItemSparse in wago, or None."""
    import att_data
    path = att_data.wago_csv(wago, 'ItemSparse') if wago else None
    if not path:
        return None
    ids = set()
    with open(path, encoding='utf-8', newline='') as fh:
        for row in csv.DictReader(fh):
            if (row.get('ID') or '').isdigit():
                ids.add(int(row['ID']))
    base = os.path.basename(path)
    build = base[len('ItemSparse.'):-len('.csv')] if base.count('.') > 1 else ''
    return build, sorted(ids)


def ranges(ids):
    """Sorted ids as [[first, last], ...]."""
    out = []
    for i in sorted(set(ids)):
        if out and i == out[-1][1] + 1:
            out[-1][1] = i
        else:
            out.append([i, i])
    return out


# ---------------------------------------------------------------- marker
def lua_hash(s):
    """The addon's hash of a text (ScanTrim.lua): over the UTF-8 bytes, h = (h * 31 + byte) % 1000000007."""
    h = 0
    for b in s.encode('utf-8'):
        h = (h * 31 + b) % HASH_MOD
    return h


def b36(n):
    digits = '0123456789abcdefghijklmnopqrstuvwxyz'
    if n == 0:
        return '0'
    out = ''
    while n:
        n, r = divmod(n, 36)
        out = digits[r] + out
    return out


def marker_parts(arch):
    """I, S, C and the stamp of the marker.
    I: "<step>.<hash>" per archived item line, the step from the previous id (the first from 0);
    S: "<step>.<hash>.<hash>..." per item with notes; C: "<step>.<length>" per range of client ids,
    the step from the end of the previous range. Every number in base 36, entries apart by ","."""
    def stepped(ids, entry):
        out, prev = [], 0
        for k in ids:
            out.append(b36(k - prev) + entry(k))
            prev = k
        return ','.join(out)
    items = stepped(sorted(arch['items']), lambda k: '.' + b36(lua_hash(arch['items'][k])))
    srcs = stepped(sorted(arch['sources']), lambda k: ''.join('.' + b36(lua_hash(n)) for n in arch['sources'][k]))
    client = arch.get('client') or {}
    parts, prev = [], 0
    for first, last in client.get('ids') or []:
        parts.append(b36(first - prev) + '.' + b36(last - first + 1))
        prev = last
    digest = hashlib.sha1((items + '|' + srcs + '|' + ','.join(parts)).encode('utf-8')).hexdigest()[:8]
    return items, srcs, ','.join(parts), f'{arch["updated"] or "-"}:{digest}'


def marker_text(arch):
    items, srcs, client, stamp = marker_parts(arch)
    c = arch.get('client') or {}
    build = c.get('build') or ''
    cmax = (c.get('ids') or [[0, 0]])[-1][1]
    lines = [
        '-- GENERATED by tools/build_scan_archive.py. Do not edit; rebuild instead.',
        '-- Sources: the Amisia item scan and item collector (tools/scan_archive.json, the archive of every',
        f'-- SavedVariables the N100 got) and the WoW Forever client table ItemSparse ({build or "none"}).',
        'local _, ns = ...',
        '',
        '-- What the scan archive holds, so Collect/ScanTrim.lua can take it out of AmisiaDB.scan. built: the',
        '-- stamp; I: item lines "<step>.<hash>", S: collector notes "<step>.<hash>.<hash>...", C: ids the',
        '-- client knows "<step>.<length>" up to cmax (an id above cmax is unknown here, not missing); every',
        '-- number base 36, steps from the previous id (C: from the end of the previous range), entries apart',
        '-- by ",". hash: h = (h * 31 + byte) % 1000000007 over the text.',
        'ns.SCAN_DONE = {',
        f'    built = "{stamp}", items = {len(arch["items"])}, sources = {len(arch["sources"])}, client = "{build}", cmax = {cmax},',
        f'    I = "{items}",',
        f'    S = "{srcs}",',
        f'    C = "{client}",',
        '}',
    ]
    import lua_data
    return lua_data.lazy('\n'.join(lines) + '\n', 'SCAN_DONE', len(arch['items']))


def write_marker(path, arch):
    new = marker_text(arch)
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            if fh.read() == new:
                return False
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(new)
    return True


# ---------------------------------------------------------------- update
def default_svs():
    """The SavedVariables Syncthing brings to the N100 and those of an installed Forever client."""
    paths = [DEFAULT_SV]
    paths += sorted(glob.glob(os.path.join(WOW_ROOT, '_classic_beta_', 'WTF', 'Account', '*', 'SavedVariables', 'Amisia.lua')))
    return [p for p in paths if os.path.exists(p)]


def update(archive=ARCHIVE, svs=None, wago=WAGO, marker=MARKER, today=None, log=print):
    """Merges the SavedVariables into the archive, refreshes the client ids, writes both files."""
    import build_scan
    arch = load(archive)
    before = text(arch)
    for p in (default_svs() if svs is None else svs):
        s = absorb(arch, build_scan.load_sv(p))
        log(f'{p}: {s["items"]} new items, {s["changed"]} changed, {s["sources"]} new notes, {s["suffix"]} suffixes')
    got = client_ids(wago)
    if got:
        build, ids = got
        arch['client'] = {'build': build, 'ids': ranges(ids)}
    if text(arch) != before:
        arch['updated'] = (today or datetime.date.today()).isoformat()
    changed = save(archive, arch)
    log(f'scan archive: {len(arch["items"])} items, {len(arch["sources"])} with notes, {len(arch["suffix"])} with suffixes'
        + (f'; client {arch["client"]["build"]}: {sum(b - a + 1 for a, b in arch["client"]["ids"])} ids' if arch['client'] else '')
        + (' -> ' + os.path.relpath(archive, ROOT) if changed else ' (unchanged)'))
    if marker:
        wrote = write_marker(marker, arch)
        log(f'marker: {os.path.relpath(marker, ROOT)}' + ('' if wrote else ' (unchanged)'))
    return arch


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('what', nargs='?', default='update', choices=('update', 'marker'))
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables files (default: ~/addons/_SavedVariables/Amisia.lua '
                                            'and an installed Forever client\'s)')
    ap.add_argument('--wago', default=WAGO, help='folder with the client table ItemSparse (default ~/addons/_wago)')
    ap.add_argument('--archive', default=ARCHIVE)
    ap.add_argument('--marker', default=MARKER)
    args = ap.parse_args(argv)
    if args.what == 'marker':
        wrote = write_marker(args.marker, load(args.archive))
        print(f'marker: {args.marker}' + ('' if wrote else ' (unchanged)'))
        return 0
    update(args.archive, args.sv, args.wago, args.marker)
    return 0


if __name__ == '__main__':
    sys.exit(main())
