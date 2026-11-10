"""tools/auto_data.py: when an export counts as complete, which build the data has (DECISIONS D-51)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import auto_data  # noqa: E402


def write(path, text, age):
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)
    t = 1_000_000 - age
    os.utime(path, (t, t))


def test_complete_builds_wants_every_ok_table_and_a_quiet_folder(tmp_path):
    d = str(tmp_path)
    now = 1_000_000
    # complete and settled
    write(os.path.join(d, '_export.1.60.1.70338.txt'), 'Item\tok\tx\nJournalInstance\tleer\tx\n', 900)
    write(os.path.join(d, 'Item.1.60.1.70338.csv'), 'ID\n', 900)
    # a table still missing (Syncthing busy)
    write(os.path.join(d, '_export.1.60.1.70425.txt'), 'Item\tok\tx\nSpell\tok\tx\n', 900)
    write(os.path.join(d, 'Item.1.60.1.70425.csv'), 'ID\n', 900)
    assert auto_data.complete_builds(d, now=now) == ['1.60.1.70338']
    # all there, but one file only a minute old
    write(os.path.join(d, 'Spell.1.60.1.70425.csv'), 'ID\n', 60)
    assert auto_data.complete_builds(d, now=now) == ['1.60.1.70338']
    # settled: the newest comes last, sorted by number, not by text
    write(os.path.join(d, 'Spell.1.60.1.70425.csv'), 'ID\n', 600)
    write(os.path.join(d, '_export.1.60.1.9999.txt'), 'Item\tok\tx\n', 900)
    write(os.path.join(d, 'Item.1.60.1.9999.csv'), 'ID\n', 900)
    assert auto_data.complete_builds(d, now=now) == ['1.60.1.9999', '1.60.1.70338', '1.60.1.70425']
    # a report without any exported table is no export
    write(os.path.join(d, '_export.1.60.1.80000.txt'), 'Item\tleer\tx\n', 900)
    assert '1.60.1.80000' not in auto_data.complete_builds(d, now=now)
    assert auto_data.complete_builds(str(tmp_path / 'none'), now=now) == []


def test_data_build_reads_the_talent_data_line():
    text = '-- header\nns.LazyData("TALENTS", [=[\nreturn {\nbuild="1.60.1.70425",max=51,\n'
    assert auto_data.data_build(text) == '1.60.1.70425'
    assert auto_data.data_build('') is None
    assert auto_data.build_key('1.60.1.9999') < auto_data.build_key('1.60.1.70338')


def test_the_repo_talent_data_has_a_build():
    with open(os.path.join(auto_data.ROOT, 'Amisia', 'Data', 'TalentData.lua'), encoding='utf-8') as fh:
        assert auto_data.data_build(fh.read())


def test_the_data_build_takes_the_newest_copy_of_each_table():
    """Without a folder of its own the data build chooses per table (tools/client_tables.py, D-101)."""
    assert auto_data.data_args(auto_data.WAGO) == []
    assert auto_data.data_args('/elsewhere') == ['--wago', '/elsewhere']


# ---------------------------------------------------------------- the daily look at wago.tools (D-103)
import argparse  # noqa: E402
import json  # noqa: E402

OLD, NEW = '1.60.1.70888', '1.60.1.70999'
DAY = auto_data.DAILY


def look_args(tmp_path, **kw):
    a = dict(state_dir=str(tmp_path / 'auto'), fetched=str(tmp_path / 'wago'), wago=str(tmp_path / 'export'),
             worktree=str(tmp_path / 'wt'), base='main', dry_run=False, force=False, look_now=False)
    a.update(kw)
    (tmp_path / 'wago').mkdir(exist_ok=True)
    return argparse.Namespace(**a)


def manifest(folder, version, tables, errors=None):
    with open(os.path.join(folder, f'_fetch.wowf.{version}.json'), 'w', encoding='utf-8') as fh:
        json.dump({'product': 'wowf', 'version': version, 'tables': {t: {'rows': 1} for t in tables},
                   'missing': {}, 'errors': errors or {}}, fh)


class Calls:
    """Canned answers for the look: the site's newest build (or why there is none), what the fetch leaves
    behind, which branches exist; records every call."""

    def __init__(self, args, answer=(NEW, None), tables=('Item', 'Map'), errors=None, branches=()):
        self.args, self.answer, self.tables, self.errors, self.branches = args, answer, tables, errors, branches
        self.asked = self.fetched = 0
        self.built = []

    def ask(self):
        self.asked += 1
        return self.answer

    def fetch(self, version, out):
        self.fetched += 1
        if self.tables is not None:
            manifest(out, version, self.tables, self.errors)
        return (1 if self.errors else 0), ''

    def exists(self, branch):
        return branch in self.branches

    def build(self, args, version, on_main, trigger):
        self.built.append((version, on_main, trigger))
        return 0

    def look(self, now, on_main=OLD, state=None):
        return auto_data.daily_look(self.args, on_main, state or {}, now=now, ask=self.ask, fetch=self.fetch,
                                    built=self.exists, build=self.build, log=lambda *_: None)


def status(args):
    with open(os.path.join(args.state_dir, 'amisia-data.txt'), encoding='utf-8') as fh:
        return fh.read()


def test_a_newer_build_is_fetched_and_built_once_a_day_at_most(tmp_path):
    args = look_args(tmp_path)
    manifest(args.fetched, OLD, ('Item', 'Map'))
    c = Calls(args)
    assert c.look(now=1_000_000) == 0
    assert (c.asked, c.fetched, c.built) == (1, 1, [(NEW, OLD, 'wago.tools')])
    assert 'neuer Build 1.60.1.70999 von wago.tools geladen und gebaut' in status(args)
    # the next run within the day asks nothing
    assert c.look(now=1_000_000 + DAY - 60) == 0 and c.asked == 1
    # a day later it asks again; the build is tried already: not fetched or built again
    assert c.look(now=1_000_000 + DAY) == 0 and (c.asked, c.fetched, len(c.built)) == (2, 1, 1)
    assert 'schon gebaut oder versucht' in status(args)
    # --look-now asks inside the day
    args.look_now = True
    assert c.look(now=1_000_000 + DAY + 60) == 0 and c.asked == 3


def test_not_newer_or_on_a_branch_already_is_nothing_new(tmp_path):
    args = look_args(tmp_path)
    c = Calls(args, answer=(OLD, None))
    c.look(now=1)
    assert (c.fetched, c.built) == (0, []) and 'nichts Neues' in status(args)
    args.look_now = True
    c = Calls(args, branches=(f'auto/data-{NEW}',))
    c.look(now=2)
    assert (c.fetched, c.built) == (0, []) and 'schon gebaut' in status(args)
    c = Calls(args)
    c.look(now=3, state={'build': NEW, 'result': 'ok'})
    assert (c.fetched, c.built) == (0, []), 'the PC export built it first: whichever sees it first wins'


def test_a_failed_look_or_fetch_ends_quietly_without_a_branch(tmp_path):
    args = look_args(tmp_path, look_now=True)
    manifest(args.fetched, OLD, ('Item', 'Map'))
    # the network or an answer the tool does not expect
    c = Calls(args, answer=(None, 'status 0: timed out'))
    assert c.look(now=1) == 0 and (c.fetched, c.built) == (0, []) and 'keine Antwort (status 0: timed out)' in status(args)
    # errors in the manifest
    c = Calls(args, errors={'Item': 'status 502: Bad Gateway'})
    assert c.look(now=2) == 0 and c.built == [] and 'Tabellen unvollständig' in status(args) and 'Item: status 502' in status(args)
    # a table the last fetched build had is missing
    c = Calls(args, tables=('Item',))
    assert c.look(now=3) == 0 and c.built == [] and 'Map: missing' in status(args)
    # no manifest at all
    os.remove(os.path.join(args.fetched, f'_fetch.wowf.{NEW}.json'))
    c = Calls(args, tables=None)
    assert c.look(now=4) == 0 and c.built == [] and 'no manifest' in status(args)
    with open(os.path.join(args.state_dir, auto_data.WAGO_STATE), encoding='utf-8') as fh:
        assert json.load(fh)['result'] == 'fetch incomplete'
    # complete at last: built
    c = Calls(args)
    assert c.look(now=5) == 0 and c.built == [(NEW, OLD, 'wago.tools')]


def test_the_switch_turns_the_look_off(tmp_path, monkeypatch):
    args = look_args(tmp_path)
    os.makedirs(args.state_dir)
    c = Calls(args)
    monkeypatch.setenv(auto_data.WAGO_OFF_ENV, '0')
    assert c.look(now=1) == 0 and c.asked == 0
    monkeypatch.delenv(auto_data.WAGO_OFF_ENV)
    open(os.path.join(args.state_dir, auto_data.WAGO_OFF_FILE), 'w').close()
    assert c.look(now=1) == 0 and c.asked == 0
    os.remove(os.path.join(args.state_dir, auto_data.WAGO_OFF_FILE))
    assert c.look(now=1) == 0 and c.asked == 1
    assert auto_data.wago_on(args.state_dir, env={'AMISIA_AUTO_WAGO': 'off'}) is False
    assert auto_data.wago_on(args.state_dir, env={'AMISIA_AUTO_WAGO': '1'}) is True


def test_the_status_line_of_the_look_keeps_the_build_report(tmp_path):
    d = str(tmp_path)
    auto_data.write_report(d, {}, ['Amisia-Daten für Client-Build X: bereit', 'Prüfung grün.'])
    auto_data.set_status_line(d, auto_data.WAGO_LINE + ', 2026-11-10 18:00): nichts Neues.')
    auto_data.set_status_line(d, auto_data.WAGO_LINE + ', 2026-11-11 18:00): nichts Neues.')
    with open(os.path.join(d, 'amisia-data.txt'), encoding='utf-8') as fh:
        lines = fh.read().splitlines()
    assert lines == ['Amisia-Daten für Client-Build X: bereit', 'Prüfung grün.', '',
                     'wago.tools (täglich, 2026-11-11 18:00): nichts Neues.'], 'one line of the look, the newest'


def test_the_look_asks_through_the_fetch_tool_only():
    """No second way to the site: the look runs tools/fetch_tables.py --latest, the fetch its --version."""
    with open(os.path.join(auto_data.ROOT, 'tools', 'auto_data.py'), encoding='utf-8') as fh:
        text = fh.read()
    assert 'urlopen' not in text and 'http' not in text.replace('https?', '')
    assert "'fetch_tables.py'), '--latest'" in text and "'fetch_tables.py'), '--version'" in text


def test_the_new_build_report_goes_beside_the_status_file(tmp_path, monkeypatch):
    import build_diff
    monkeypatch.setattr(build_diff, 'report', lambda old, new: (['New in B against A', 'Items: 2 new'],
                                                               ['New in B against A', 'Items: 2 new', '', 'details']))
    lines = auto_data.diff_lines('A', 'B', str(tmp_path))
    assert lines[1].startswith('Neu in diesem Build') and lines[2:] == ['Items: 2 new']
    with open(os.path.join(str(tmp_path), auto_data.DIFF_FILE), encoding='utf-8') as fh:
        assert fh.read().endswith('details\n')

    def broken(old, new):
        raise ValueError('bad table')
    monkeypatch.setattr(build_diff, 'report', broken)
    assert auto_data.diff_lines('A', 'B', str(tmp_path))[-1] == 'Neu in diesem Build: kein Bericht (ValueError: bad table)'
    assert auto_data.diff_lines(None, 'B', str(tmp_path)) == []


def test_a_look_that_breaks_off_still_counts_for_the_day(tmp_path):
    args = look_args(tmp_path)
    manifest(args.fetched, OLD, ('Item', 'Map'))
    c = Calls(args)

    def broken(*a):
        raise RuntimeError('git worktree add failed')
    c.build = broken
    try:
        c.look(now=100)
    except RuntimeError:
        pass
    c.build = Calls.build.__get__(c)
    assert c.look(now=100 + 900) == 0 and c.asked == 1, 'the next run 15 minutes later does not ask again'
