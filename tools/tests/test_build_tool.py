"""tools/build.py: the TOC helpers, the UTF-8 and TOC checks, the order and skipping of the data
builds, and the release in a temporary git repository (a local bare repository stands in for origin;
nothing is pushed anywhere else)."""
import os
import subprocess
import sys
import zipfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import build  # noqa: E402

TOC = """## Interface: 16001
## Title: Amisia
## Version: {v}
## SavedVariables: AmisiaDB

Core\\Core.lua
Data\\GearData.lua [AllowLoadGameType camelot]
"""


def sh(cwd, *args, input=None):
    p = subprocess.run(list(args), cwd=cwd, input=input, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr
    return p.stdout


def write(path, text, mode='w'):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, mode, **({} if 'b' in mode else {'encoding': 'utf-8', 'newline': ''})) as fh:
        fh.write(text)


def make_addon(root, version='1.0.0'):
    a = os.path.join(root, 'addon', 'Amisia')
    write(os.path.join(a, 'Amisia.toc'), TOC.format(v=version))
    write(os.path.join(a, 'Core', 'Core.lua'), 'local ADDON, ns = ...\nns.x = "ü"\n')
    write(os.path.join(a, 'Data', 'GearData.lua'), '-- GENERATED\n')
    write(os.path.join(a, 'Media', 'Icons', 'x.tga'), b'\x00\x01\xff', 'wb')
    write(os.path.join(a, '.stignore'), '.vscode\n')
    return a


@pytest.fixture
def repo(tmp_path):
    """A repository on main with a release commit, two commits after it and a bare origin."""
    root = str(tmp_path / 'repo')
    os.makedirs(root)
    sh(root, 'git', 'init', '-q', '-b', 'main')
    sh(root, 'git', 'config', 'user.name', 'Test')
    sh(root, 'git', 'config', 'user.email', 'test@example.invalid')
    sh(root, 'git', 'config', 'commit.gpgsign', 'false')
    make_addon(root)
    marker = str(tmp_path / 'copied')
    write(os.path.join(root, 'tools', 'release_addon.sh'), f'#!/usr/bin/env bash\necho copied > "{marker}"\n')
    sh(root, 'git', 'add', '-A')
    sh(root, 'git', 'commit', '-q', '-m', 'Amisia 1.0.0: the first')
    write(os.path.join(root, 'addon', 'Amisia', 'Core', 'Core.lua'), 'local ADDON, ns = ...\nns.x = 2\n')
    sh(root, 'git', 'commit', '-q', '-am', 'Core: x is two')
    write(os.path.join(root, 'notes.txt'), 'n\n')
    sh(root, 'git', 'add', 'notes.txt')
    sh(root, 'git', 'commit', '-q', '-m', 'Notes for the next steps')
    bare = str(tmp_path / 'origin.git')
    sh(str(tmp_path), 'git', 'init', '-q', '--bare', bare)
    sh(root, 'git', 'remote', 'add', 'origin', bare)
    sh(root, 'git', 'push', '-q', 'origin', 'main')
    return {'root': root, 'bare': bare, 'marker': marker}


def head(root, fmt='%s'):
    return sh(root, 'git', 'log', '-1', '--format=' + fmt).strip()


# ---------------------------------------------------------------- TOC and checks
def test_the_repo_toc_has_the_version_and_matches_the_folder():
    v = build.toc_version(ROOT)
    assert v and len(v.split('.')) == 3
    assert build.check_toc(ROOT) == []
    files = build.toc_files(ROOT)
    assert 'Core/Core.lua' in files and 'Gear/MapPin.xml' in files and 'UI/Pages/About.lua' in files
    assert files.index('Core/Registry.lua') == 0, 'the registry loads first'


def test_set_toc_version(tmp_path):
    make_addon(str(tmp_path), '1.2.3')
    assert build.toc_version(str(tmp_path)) == '1.2.3'
    build.set_toc_version(str(tmp_path), '1.10.0')
    assert build.toc_version(str(tmp_path)) == '1.10.0'
    with open(build.toc_path(str(tmp_path)), encoding='utf-8') as fh:
        assert fh.read() == TOC.format(v='1.10.0'), 'nothing else in the TOC changes'
    assert build.version_key('1.10.0') > build.version_key('1.9.9')


def test_check_toc_finds_missing_and_unlisted_files(tmp_path):
    a = make_addon(str(tmp_path))
    assert build.check_toc(str(tmp_path)) == []
    write(os.path.join(a, 'Raid', 'New.lua'), '-- new\n')
    os.remove(os.path.join(a, 'Data', 'GearData.lua'))
    bad = build.check_toc(str(tmp_path))
    assert 'Data/GearData.lua: in the TOC, but no such file' in bad
    assert 'Raid/New.lua: not in the TOC' in bad


def test_check_utf8(tmp_path):
    a = make_addon(str(tmp_path))
    assert build.check_utf8(str(tmp_path)) == [], 'UTF-8 text and a binary texture pass'
    write(os.path.join(a, 'Core', 'Bad.lua'), 'local a = 1\n-- K\xf6nig\n'.encode('latin-1'), 'wb')
    write(os.path.join(a, 'Core', 'Bom.lua'), b'\xef\xbb\xbf-- x\n', 'wb')
    bad = build.check_utf8(str(tmp_path))
    assert any(b.startswith('Core/Bad.lua:2: not UTF-8') for b in bad), bad
    assert 'Core/Bom.lua: byte order mark' in bad


# ---------------------------------------------------------------- data
def test_data_steps_order():
    names = [s[0] for s in build.data_steps()]
    assert names == ['dungeons', 'gear', 'map', 'dungeon quests', 'quests', 'professions', 'talents',
                     'dungeon art', 'bis']
    steps = {s[0]: s for s in build.data_steps(sv='/x/Amisia.lua', wago='/w', refresh_att=True)}
    assert steps['gear'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua', '--refresh-att']
    assert steps['bis'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua']
    assert steps['talents'][4] == 'skip' and steps['professions'][4] == 'skip'
    assert steps['dungeon art'][4] == [] and steps['dungeons'][4] == [], 'without tables: from the snapshot'


def test_missing_tables(tmp_path):
    import build_talents
    assert build.missing_tables('talents', str(tmp_path)) == build_talents.REQUIRED
    assert build.missing_tables('talents', os.path.join(HERE, 'fixtures', 'talents')) == []
    write(str(tmp_path / 'AreaTable.1.60.1.70235.csv'), 'ID\n')
    assert build.missing_tables([('LFGDungeons', 'AreaTable'), 'Map'], str(tmp_path)) == ['Map']


def test_data_stops_at_the_first_error_and_skips_without_tables(tmp_path, monkeypatch, capsys):
    ran = []

    def fake_run(cmd, cwd=build.ROOT, env=None, capture=False):
        ran.append(os.path.basename(cmd[1]))
        return (3 if cmd[1].endswith('two.py') else 0), ''
    monkeypatch.setattr(build, 'run', fake_run)
    monkeypatch.setattr(build, 'data_steps', lambda sv, wago, refresh: [
        ('one', 'one.py', [], None, None),
        ('needs', 'needs.py', [], ['NoSuchTable'], 'skip'),
        ('two', 'two.py', [], None, None),
        ('three', 'three.py', [], None, None)])
    args = type('A', (), {'sv': None, 'wago': str(tmp_path), 'refresh_att': False})()
    assert build.cmd_data(args) == 1
    assert ran == ['one.py', 'two.py'], 'the skipped step and the one after the failure never ran'
    out = capsys.readouterr().out
    assert 'skip  needs: client tables missing' in out and 'export_db2.ps1 -Tables NoSuchTable' in out
    assert 'FAIL  two (exit 3)' in out


# ---------------------------------------------------------------- release
def test_release(repo):
    root = repo['root']
    assert build.release(root, '1.1.0', push=True, copy=True, check=lambda: 0, day='2026-10-07') == 0
    assert build.toc_version(root) == '1.1.0'
    subject = head(root)
    assert subject == 'Amisia 1.1.0: Core: x is two; Notes for the next steps'
    assert head(root, '%B').rstrip().endswith(build.TRAILER)
    assert sh(root, 'git', 'status', '--porcelain') == '', 'everything committed'
    with zipfile.ZipFile(os.path.join(root, 'addon', 'Amisia.zip')) as zf:
        names = sorted(zf.namelist())
        assert names == ['Amisia/Amisia.toc', 'Amisia/Core/Core.lua', 'Amisia/Data/GearData.lua',
                         'Amisia/Media/Icons/x.tga'], names
        assert '## Version: 1.1.0' in zf.read('Amisia/Amisia.toc').decode('utf-8')
    with open(os.path.join(root, 'CHANGELOG.md'), encoding='utf-8') as fh:
        log = fh.read()
    assert '## 1.1.0 (2026-10-07)\n\n- Core: x is two\n- Notes for the next steps\n' in log
    assert 'Amisia 1.0.0' not in log
    assert sh(repo['bare'], 'git', 'log', '-1', '--format=%s', 'main').strip() == subject, 'pushed to origin'
    assert os.path.exists(repo['marker']), 'tools/release_addon.sh ran'

    # the next release lists only what came after this one, above the old section
    write(os.path.join(root, 'notes.txt'), 'more\n')
    sh(root, 'git', 'commit', '-q', '-am', 'More notes')
    assert build.release(root, '1.1.1', summary='small fixes', push=False, copy=False, check=lambda: 0,
                         day='2026-10-08') == 0
    assert head(root) == 'Amisia 1.1.1: small fixes'
    with open(os.path.join(root, 'CHANGELOG.md'), encoding='utf-8') as fh:
        log = fh.read()
    assert log.index('## 1.1.1 (2026-10-08)\n\n- More notes\n') < log.index('## 1.1.0')
    assert log.count('# Changelog') == 1


def test_release_never_bumps_on_a_failed_check(repo):
    root = repo['root']
    before = head(root, '%H')
    assert build.release(root, '1.1.0', push=False, copy=False, check=lambda: 1) == 1
    assert build.toc_version(root) == '1.0.0'
    assert head(root, '%H') == before
    assert sh(root, 'git', 'status', '--porcelain') == ''
    assert not os.path.exists(os.path.join(root, 'CHANGELOG.md'))
    assert not os.path.exists(repo['marker'])

    def broken():
        raise RuntimeError('the check itself broke')
    with pytest.raises(RuntimeError):
        build.release(root, '1.1.0', push=False, copy=False, check=broken)
    assert build.toc_version(root) == '1.0.0' and sh(root, 'git', 'status', '--porcelain') == ''

    # a changelog that already has the version: the release stops after zip and changelog, and undoes both
    write(os.path.join(root, 'CHANGELOG.md'), '# Changelog\n\n## 1.1.0 (2026-01-01)\n\n- old\n')
    sh(root, 'git', 'add', 'CHANGELOG.md')
    sh(root, 'git', 'commit', '-q', '-m', 'A changelog')
    with pytest.raises(SystemExit, match='already has 1.1.0'):
        build.release(root, '1.1.0', push=False, copy=False, check=lambda: 0)
    assert build.toc_version(root) == '1.0.0' and sh(root, 'git', 'status', '--porcelain') == ''
    assert not os.path.exists(os.path.join(root, 'addon', 'Amisia.zip'))
    assert head(root) == 'A changelog'


def test_release_refuses(repo):
    root = repo['root']
    with pytest.raises(SystemExit, match='not newer'):
        build.release(root, '1.0.0', push=False, copy=False, check=lambda: 0)
    with pytest.raises(SystemExit, match='X.Y.Z'):
        build.release(root, '1.1', push=False, copy=False, check=lambda: 0)
    write(os.path.join(root, 'notes.txt'), 'dirty\n')
    with pytest.raises(SystemExit, match='not clean'):
        build.release(root, '1.1.0', push=False, copy=False, check=lambda: 0)
    sh(root, 'git', 'checkout', '--', 'notes.txt')
    write(os.path.join(root, 'addon', 'Amisia', 'Core', 'Untracked.lua'), '-- new\n')
    with pytest.raises(SystemExit, match='not clean'):
        build.release(root, '1.1.0', push=False, copy=False, check=lambda: 0)
    os.remove(os.path.join(root, 'addon', 'Amisia', 'Core', 'Untracked.lua'))
    sh(root, 'git', 'checkout', '-q', '-b', 'dev')
    with pytest.raises(SystemExit, match='from main'):
        build.release(root, '1.1.0', push=True, copy=False, check=lambda: 0)
    assert build.toc_version(root) == '1.0.0'
