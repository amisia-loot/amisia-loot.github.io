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
    with open(os.path.join(auto_data.ROOT, 'Amisia_Gear', 'Data', 'TalentData.lua'), encoding='utf-8') as fh:
        assert auto_data.data_build(fh.read())


def test_the_data_build_takes_the_newest_copy_of_each_table():
    """Without a folder of its own the data build chooses per table (tools/client_tables.py, D-101)."""
    assert auto_data.data_args(auto_data.WAGO) == []
    assert auto_data.data_args('/elsewhere') == ['--wago', '/elsewhere']


# ---------------------------------------------------------------- the daily look at wago.tools (D-103)
import argparse  # noqa: E402
import json  # noqa: E402

import pytest  # noqa: E402

OLD, NEW = '1.60.1.70888', '1.60.1.70999'
DAY = auto_data.DAILY


@pytest.fixture(autouse=True)
def no_switches(monkeypatch):
    """The tests do not depend on the switches of the service's environment (a run of the check inside
    auto_data.py with AMISIA_AUTO_WAGO=0 turned the look's tests red)."""
    monkeypatch.delenv(auto_data.WAGO_OFF_ENV, raising=False)
    monkeypatch.delenv(auto_data.SV_OFF_ENV, raising=False)


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


# ---------------------------------------------------------------- trigger C: the SavedVariables (D-122)
import subprocess  # noqa: E402
import time  # noqa: E402

# A stand-in for tools/build.py in a temporary repository: `data --sv FILE` reads lines "-- item N",
# "-- quest N", "-- kill N" and "-- red" of the file into the archives of ITS OWN checkout (beside this
# script, as the real builders do with HERE), `check` is red when the data build left Amisia_Gear/Data/Red.lua.
FAKE_BUILD = r'''
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def p(rel): return os.path.join(ROOT, rel)
def load(rel):
    with open(p(rel), encoding='utf-8') as fh: return json.load(fh)
def save(rel, data):
    with open(p(rel), 'w', encoding='utf-8') as fh: fh.write(json.dumps(data, indent=1, sort_keys=True) + '\n')
if sys.argv[1] == 'data':
    sv = sys.argv[sys.argv.index('--sv') + 1]
    text = open(sv, encoding='utf-8').read()
    if 'BROKEN' in text:
        print(sv + ': [string "Amisia.lua"]:3: unexpected symbol near "BROKEN"'); sys.exit(1)
    arch, drops = load('tools/scan_archive.json'), load('tools/drop_obs.json')
    for line in text.splitlines():
        w = line.split()
        if len(w) >= 2 and w[0] == '--':
            if w[1] == 'item': arch['items'][w[2]] = 'name ' + w[2]
            if w[1] == 'quest': arch['quests']['deDE'][w[2]] = 'quest ' + w[2]
            if w[1] == 'kill': drops['k'][w[2]] = [int(w[2])]
            if w[1] == 'red':
                with open(p('Amisia_Gear/Data/Red.lua'), 'w') as fh: fh.write('-- a dungeon without an entry\n')
    save('tools/scan_archive.json', arch); save('tools/drop_obs.json', drops)
    with open(p('Amisia_Gear/Data/ScanDone.lua'), 'w') as fh: fh.write('-- items %d\n' % len(arch['items']))
    print('built: scan archive')
elif sys.argv[1] == 'check':
    if os.path.exists(p('Amisia_Gear/Data/Red.lua')):
        print('ok    luacheck (1.0s)')
        print('FAILED tools/tests/test_dungeons.py::test_every_dungeon_has_an_entry - KeyError')
        print('check: 1 failed'); sys.exit(1)
    print('check: all ok')
'''


def sh(*args, cwd):
    return subprocess.run(args, cwd=cwd, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)


@pytest.fixture
def repo(tmp_path, monkeypatch):
    """A temporary main repository with the fake build tool; auto_data's ROOT points at it."""
    r = str(tmp_path / 'repo')
    put(os.path.join(r, 'tools', 'build.py'), FAKE_BUILD)
    put(os.path.join(r, 'tools', 'scan_archive.json'), json.dumps(
        {'items': {'1': 'name 1'}, 'quests': {'deDE': {}}}, indent=1, sort_keys=True) + '\n')
    put(os.path.join(r, 'tools', 'drop_obs.json'), json.dumps({'k': {}}, indent=1, sort_keys=True) + '\n')
    put(os.path.join(r, 'Amisia_Gear', 'Data', 'ScanDone.lua'), '-- items 1\n')
    put(os.path.join(r, 'Amisia_Gear', 'Data', 'TalentData.lua'), f'build="{OLD}",max=51,\n')
    put(os.path.join(r, 'Amisia-Website', 'data', 'drops-forever.js'), '// none\n')
    sh('git', 'init', '-q', '-b', 'main', cwd=r)
    sh('git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'add', '-A', cwd=r)
    sh('git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q', '-m', 'start', cwd=r)
    sh('git', 'config', 'user.name', 't', cwd=r)
    sh('git', 'config', 'user.email', 't@t', cwd=r)
    monkeypatch.setattr(auto_data, 'ROOT', r)
    monkeypatch.delenv(auto_data.SV_OFF_ENV, raising=False)
    return r


def sv_args(tmp_path, **kw):
    a = look_args(tmp_path, sv=str(tmp_path / 'sv' / 'Amisia.lua'), force_sv=False)
    os.makedirs(a.wago, exist_ok=True)
    vars(a).update(kw)
    return a


def write_sv(args, body, age):
    """The SavedVariables with body, last written age seconds ago (real time)."""
    put(args.sv, 'AmisiaDB = {\n}\n' + body)
    t = time.time() - age
    os.utime(args.sv, (t, t))


def branches(r, pattern='auto/*'):
    return sh('git', 'for-each-ref', '--format=%(refname:short)', f'refs/heads/{pattern}', cwd=r).split()


def main_state(r):
    """Everything of the main checkout a run must not touch: its commit, its files, its worktrees."""
    files = {}
    for d, _, names in os.walk(r):
        if '.git' in d.split(os.sep):
            continue
        for n in names:
            with open(os.path.join(d, n), 'rb') as fh:
                files[os.path.relpath(os.path.join(d, n), r)] = fh.read()
    return (sh('git', 'rev-parse', 'HEAD', cwd=r), sh('git', 'status', '--porcelain', cwd=r), files,
            sh('git', 'worktree', 'list', cwd=r).count('\n'))


def run_c(args, now=None):
    out = []
    rc = auto_data.sv_trigger(args, OLD, now=time.time() if now is None else now, log=out.append)
    return rc, '\n'.join(out)


def test_a_changed_file_is_taken_over_after_settle_and_gap(repo, tmp_path):
    args = sv_args(tmp_path)
    before = main_state(repo)
    write_sv(args, '-- item 25\n-- item 26\n-- quest 8\n-- kill 7\n', age=60)
    rc, out = run_c(args)
    assert rc == 0 and 'waiting until it settles' in out and branches(repo) == []
    write_sv(args, '-- item 25\n-- item 26\n-- quest 8\n-- kill 7\n', age=auto_data.SV_SETTLE + 60)
    rc, out = run_c(args)
    day = time.strftime('%Y-%m-%d')
    assert rc == 0 and branches(repo) == [f'auto/sv-{day}']
    text = status(args)
    assert f'übernommen auf Branch auto/sv-{day} (' in text and 'Prüfung grün.' in text
    assert 'Neu gegenüber main: 2 Items, 1 Questnamen, 1 Kills.' in text
    assert 'Amisia_Gear/Data/ScanDone.lua' in text and 'tools/scan_archive.json' in text
    assert 'Zum Veröffentlichen: build.py data auf main, dann build.py release.' in text
    # the branch has the build's archives; the main checkout, its commit and its worktrees are untouched
    assert '"25": "name 25"' in sh('git', 'show', f'auto/sv-{day}:tools/scan_archive.json', cwd=repo)
    assert main_state(repo) == before
    assert not os.path.exists(args.worktree), 'the worktree is removed again'
    # the same file again: nothing
    first = sh('git', 'rev-parse', f'auto/sv-{day}', cwd=repo)
    rc, out = run_c(args)
    assert rc == 0 and 'unchanged' in out
    # a new logout inside the gap waits; --force-sv takes it now and moves the day's branch
    write_sv(args, '-- item 25\n-- item 26\n-- item 27\n-- quest 8\n-- kill 7\n', age=auto_data.SV_SETTLE + 60)
    rc, out = run_c(args)
    assert rc == 0 and 'next take-over from' in out
    assert sh('git', 'rev-parse', f'auto/sv-{day}', cwd=repo) == first
    args.force_sv = True
    rc, out = run_c(args)
    args.force_sv = False
    assert rc == 0 and sh('git', 'rev-parse', f'auto/sv-{day}', cwd=repo) != first
    assert 'Neu gegenüber main: 3 Items' in status(args), 'counted against main, not against the earlier branch'
    assert branches(repo) == [f'auto/sv-{day}'] and main_state(repo) == before
    # after the gap a new file is taken over by itself
    write_sv(args, '-- item 28\n', age=auto_data.SV_SETTLE + 60)
    rc, out = run_c(args, now=time.time() + auto_data.SV_GAP)
    assert rc == 0 and 'Neu gegenüber main: 1 Items.' in status(args)


def test_an_unchanged_content_does_nothing(repo, tmp_path):
    args = sv_args(tmp_path)
    write_sv(args, '-- item 25\n', age=auto_data.SV_SETTLE + 60)
    assert run_c(args)[0] == 0
    sha = sh('git', 'rev-parse', f'auto/sv-{time.strftime("%Y-%m-%d")}', cwd=repo)
    # Syncthing writes the same bytes again later: a new mtime, the same hash
    write_sv(args, '-- item 25\n', age=auto_data.SV_SETTLE + 30)
    rc, out = run_c(args, now=time.time() + auto_data.SV_GAP)
    assert rc == 0 and 'content unchanged' in out
    assert sh('git', 'rev-parse', f'auto/sv-{time.strftime("%Y-%m-%d")}', cwd=repo) == sha
    with open(os.path.join(args.state_dir, auto_data.SV_STATE), encoding='utf-8') as fh:
        assert json.load(fh)['mtime'] == os.path.getmtime(args.sv), 'the next run skips the hash'


def test_nothing_new_is_one_line_and_no_branch(repo, tmp_path):
    args = sv_args(tmp_path)
    before = main_state(repo)
    write_sv(args, '-- nothing the build keeps\n', age=auto_data.SV_SETTLE + 60)
    rc, out = run_c(args)
    assert rc == 0 and branches(repo) == []
    block = auto_data.split_status(args.state_dir)[1]
    assert len(block) == 1 and block[0].startswith('Spielstand vom ') and block[0].endswith(': nichts Neues gegenüber main.')
    assert main_state(repo) == before and not os.path.exists(args.worktree)


def test_a_red_check_is_reported_and_the_branch_kept(repo, tmp_path):
    args = sv_args(tmp_path)
    before = main_state(repo)
    write_sv(args, '-- item 30\n-- red\n', age=auto_data.SV_SETTLE + 60)
    rc, out = run_c(args)
    day = time.strftime('%Y-%m-%d')
    assert rc == 1 and branches(repo) == [f'auto/sv-{day}']
    block = auto_data.split_status(args.state_dir)[1]
    assert block[0].endswith('Prüfung ROT:')
    assert '  FAILED tools/tests/test_dungeons.py::test_every_dungeon_has_an_entry - KeyError' in block
    assert '  check: 1 failed' in block and block[-1].startswith('Vor dem nächsten Release klären')
    assert 'Amisia_Gear/Data/Red.lua' in sh('git', 'show', '--stat', f'auto/sv-{day}', cwd=repo)
    assert main_state(repo) == before and not os.path.exists(args.worktree)


def test_a_broken_file_is_a_status_line(repo, tmp_path):
    args = sv_args(tmp_path)
    put(args.sv, 'garbage, no table\n')
    os.utime(args.sv, (time.time() - 900,) * 2)
    rc, out = run_c(args)
    assert rc == 1 and 'nicht lesbar (keine Tabelle AmisiaDB' in status(args) and branches(repo) == []
    # a file the build's parser refuses: the build's own message, no branch, the worktree gone
    write_sv(args, 'BROKEN\n', age=900)
    rc, out = run_c(args, now=time.time() + auto_data.SV_GAP)
    text = status(args)
    assert rc == 1 and 'build.py data ist damit fehlgeschlagen, nichts übernommen:' in text
    assert 'unexpected symbol near "BROKEN"' in text and branches(repo) == []
    assert not os.path.exists(args.worktree)
    # it is not tried again until the file changes
    assert 'unchanged' in run_c(args, now=time.time() + 2 * auto_data.SV_GAP)[1]


def test_dry_run_and_the_switch(repo, tmp_path, monkeypatch):
    args = sv_args(tmp_path, dry_run=True)
    write_sv(args, '-- item 25\n', age=900)
    rc, out = run_c(args)
    assert rc == 0 and f'would take over {args.sv}' in out and 'auto/sv-' in out
    assert branches(repo) == [] and not os.path.exists(os.path.join(args.state_dir, auto_data.SV_STATE))
    args.dry_run = False
    monkeypatch.setenv(auto_data.SV_OFF_ENV, '0')
    assert 'trigger off' in run_c(args)[1] and branches(repo) == []
    monkeypatch.delenv(auto_data.SV_OFF_ENV)
    put(os.path.join(args.state_dir, auto_data.SV_OFF_FILE), '')
    assert 'trigger off' in run_c(args)[1]
    os.remove(os.path.join(args.state_dir, auto_data.SV_OFF_FILE))
    assert run_c(args)[0] == 0 and len(branches(repo)) == 1
    assert 'no SavedVariables' in run_c(sv_args(tmp_path, sv=str(tmp_path / 'none.lua')))[1]


def test_a_dirty_main_checkout_does_not_matter(repo, tmp_path):
    """The work happens from the committed main in the worktree: an edit in the main checkout neither goes
    into the branch nor gets lost."""
    args = sv_args(tmp_path)
    put(os.path.join(repo, 'tools', 'drop_obs.json'), '{"k": {"half-done": [1]}}\n')
    before = main_state(repo)
    write_sv(args, '-- kill 9\n', age=900)
    assert run_c(args)[0] == 0
    on_branch = sh('git', 'show', f'auto/sv-{time.strftime("%Y-%m-%d")}:tools/drop_obs.json', cwd=repo)
    assert '"9"' in on_branch and 'half-done' not in on_branch
    assert main_state(repo) == before


def test_only_the_newest_sv_branches_stay(repo):
    for d in range(1, 8):
        sh('git', 'branch', f'auto/sv-2026-11-0{d}', cwd=repo)
    sh('git', 'branch', 'auto/data-1.60.1.70000', cwd=repo)
    auto_data.prune_sv_branches()
    assert branches(repo, 'auto/sv-*') == [f'auto/sv-2026-11-0{d}' for d in range(3, 8)]
    assert branches(repo, 'auto/data-*') == ['auto/data-1.60.1.70000'] and 'main' in sh('git', 'branch', cwd=repo)


def test_the_block_keeps_the_build_report_and_the_look(tmp_path):
    d = str(tmp_path)
    auto_data.write_report(d, {}, ['Amisia-Daten für Client-Build X: bereit', 'Prüfung grün.', '', 'Neu in diesem Build:', 'Items: 2 new'])
    auto_data.set_status_line(d, auto_data.WAGO_LINE + ', 2026-11-13 08:00): nichts Neues.')
    auto_data.set_sv_block(d, ['Spielstand vom 2026-11-13 12:01: nichts Neues gegenüber main.'])
    auto_data.set_sv_block(d, ['Spielstand vom 2026-11-13 19:01: übernommen auf Branch auto/sv-2026-11-13 (abc1234), Prüfung grün.',
                               'Neu gegenüber main: 3 Items.'])
    auto_data.set_status_line(d, auto_data.WAGO_LINE + ', 2026-11-14 08:00): nichts Neues.')
    with open(os.path.join(d, 'amisia-data.txt'), encoding='utf-8') as fh:
        lines = fh.read().splitlines()
    assert lines == ['Amisia-Daten für Client-Build X: bereit', 'Prüfung grün.', '', 'Neu in diesem Build:', 'Items: 2 new', '',
                     'Spielstand vom 2026-11-13 19:01: übernommen auf Branch auto/sv-2026-11-13 (abc1234), Prüfung grün.',
                     'Neu gegenüber main: 3 Items.', '',
                     'wago.tools (täglich, 2026-11-14 08:00): nichts Neues.'], 'one block, the newest; the look last'


def test_a_new_build_report_keeps_the_block(repo, tmp_path, monkeypatch):
    """build_branch rewrites the status file: the block of the SavedVariables and the look come back."""
    args = sv_args(tmp_path)
    os.makedirs(args.state_dir)
    with open(os.path.join(args.state_dir, auto_data.SV_STATE), 'w', encoding='utf-8') as fh:
        json.dump({'lines': ['Spielstand vom 2026-11-13 12:01: nichts Neues gegenüber main.']}, fh)
    with open(os.path.join(args.state_dir, auto_data.WAGO_STATE), 'w', encoding='utf-8') as fh:
        json.dump({'line': auto_data.WAGO_LINE + ', 2026-11-13 08:00): nichts Neues.'}, fh)
    monkeypatch.setattr(auto_data, 'run', lambda cmd, cwd: (0, 'check: all ok'))
    assert auto_data.build_branch(args, NEW, OLD, 'wago.tools') == 0
    rest, block, look = auto_data.split_status(args.state_dir)
    assert rest[0].startswith(f'Amisia-Daten für Client-Build {NEW}') and block == ['Spielstand vom 2026-11-13 12:01: nichts Neues gegenüber main.']
    assert look.endswith('nichts Neues.') and not os.path.exists(args.worktree)


def test_a_stale_report_is_replaced_when_main_has_the_build(tmp_path):
    args = look_args(tmp_path)
    state = {'build': NEW, 'branch': f'auto/data-{NEW}', 'commit': 'bbe0bfc', 'result': 'failed', 'at': '2026-11-13 09:17',
             'main': OLD, 'trigger': 'export'}
    auto_data.write_report(args.state_dir, state, [f'Amisia-Daten für Client-Build {NEW} (2026-11-13 09:17): FEHLER', 'build.py check ist rot.'])
    auto_data.set_sv_block(args.state_dir, ['Spielstand vom 2026-11-13 12:01: nichts Neues gegenüber main.'])
    auto_data.set_status_line(args.state_dir, auto_data.WAGO_LINE + ', 2026-11-13 08:00): nichts Neues.')
    assert auto_data.settle_stale(args, OLD, dict(state), log=lambda *_: None) is False, 'main is older: the report stays'
    args.dry_run = True
    assert auto_data.settle_stale(args, NEW, dict(state), log=lambda *_: None) is True and 'FEHLER' in status(args)
    args.dry_run = False
    assert auto_data.settle_stale(args, NEW, state, log=lambda *_: None) is True
    rest, block, look = auto_data.split_status(args.state_dir)
    assert rest == [f'Amisia-Daten für Client-Build {NEW}: main hat diese Daten inzwischen (bemerkt {state["settled"]}); '
                    f'der Bericht vom 2026-11-13 09:17 (FEHLER, Branch auto/data-{NEW}) ist erledigt.']
    assert block and look, 'the block and the look stay'
    saved = auto_data.load_state(os.path.join(args.state_dir, 'amisia-data.json'))
    assert saved['build'] == NEW and saved['settled']
    assert auto_data.settle_stale(args, NEW, saved, log=lambda *_: None) is False, 'once'


def run_main(args, monkeypatch, look_builds=False):
    """main() of the temporary repository with A's build, B and C recorded."""
    calls = []
    monkeypatch.setattr(auto_data, 'build_branch', lambda a, b, m, t: calls.append(('build', b, t)) or 0)

    def look(a, on_main, state, build=None):
        calls.append(('look',))
        return build(a, NEW, on_main, 'wago.tools') if look_builds else 0
    monkeypatch.setattr(auto_data, 'daily_look', look)
    monkeypatch.setattr(auto_data, 'sv_trigger', lambda a, on_main: calls.append(('sv', on_main)) or 0)
    argv = ['--state-dir', args.state_dir, '--wago', args.wago, '--worktree', args.worktree, '--sv', args.sv]
    assert auto_data.main(argv) == 0
    return calls


def test_a_new_client_build_comes_before_the_savedvariables(repo, tmp_path, monkeypatch):
    args = sv_args(tmp_path)
    # nothing for A and B: C runs, with main's build
    assert run_main(args, monkeypatch) == [('look',), ('sv', OLD)]
    # B builds a new client build: C waits for the next run
    assert run_main(args, monkeypatch, look_builds=True) == [('look',), ('build', NEW, 'wago.tools')]
    # A has a complete, settled export: A builds, neither B nor C runs
    write(os.path.join(args.wago, f'_export.{NEW}.txt'), 'Item\tok\tx\n', 0)
    write(os.path.join(args.wago, f'Item.{NEW}.csv'), 'ID\n', 0)
    os.utime(os.path.join(args.wago, f'_export.{NEW}.txt'), (time.time() - 900,) * 2)
    os.utime(os.path.join(args.wago, f'Item.{NEW}.csv'), (time.time() - 900,) * 2)
    assert run_main(args, monkeypatch) == [('build', NEW, 'export')]
    # the export still arriving (a table missing): it waits, and so does C
    os.remove(os.path.join(args.wago, f'Item.{NEW}.csv'))
    assert run_main(args, monkeypatch) == [('look',)]
    # tried already (A's state): C runs again
    with open(os.path.join(args.state_dir, 'amisia-data.json'), 'w', encoding='utf-8') as fh:
        json.dump({'build': NEW, 'result': 'failed'}, fh)
    assert run_main(args, monkeypatch) == [('look',), ('sv', OLD)]
    # a wago.tools fetch that came back incomplete for a newer build: C waits too
    os.remove(os.path.join(args.wago, f'_export.{NEW}.txt'))
    os.remove(os.path.join(args.state_dir, 'amisia-data.json'))
    with open(os.path.join(args.state_dir, auto_data.WAGO_STATE), 'w', encoding='utf-8') as fh:
        json.dump({'answer': NEW, 'result': 'fetch incomplete'}, fh)
    assert run_main(args, monkeypatch) == [('look',)]


def test_main_dry_run_names_what_c_would_do(repo, tmp_path, monkeypatch, capsys):
    args = sv_args(tmp_path)
    write_sv(args, '-- item 25\n', age=900)
    monkeypatch.setenv(auto_data.WAGO_OFF_ENV, '0')
    argv = ['--state-dir', args.state_dir, '--wago', args.wago, '--worktree', args.worktree, '--sv', args.sv, '--dry-run']
    assert auto_data.main(argv) == 0
    out = capsys.readouterr().out
    assert f'would take over {args.sv}' in out and branches(repo) == []


def test_the_failing_lines_are_the_steps_and_tests():
    out = '\n'.join(['ok    luacheck (9.5s)', 'FAIL  tool tests (pytest tools/tests) (32.9s)',
                     "        E       FileNotFoundError: [Errno 2] No such file or directory: 'x'",
                     "                    raise RuntimeError('git worktree add failed')",
                     '        FAILED tools/tests/test_auto_data.py::test_one', 'ok    TOC (0.0s)', 'check: 1 failed'])
    assert auto_data.failing_lines(out) == ['FAIL  tool tests (pytest tools/tests) (32.9s)',
                                            '        FAILED tools/tests/test_auto_data.py::test_one', 'check: 1 failed']
    assert auto_data.failing_lines('a\nb\ncheck: 2 failed', n=2) == ['b', 'check: 2 failed'], 'no step line: the end'
