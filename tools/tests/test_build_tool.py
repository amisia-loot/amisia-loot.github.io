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

TOC = """## Interface: 16001, 20506, 11509
## Title: Amisia
## Version: {v}
## SavedVariables: AmisiaDB

Core\\Core.lua
"""
# the modules (F-202, D-130): the raid module on every client with one Forever-only file, the gear module
# on Forever only
RAID_TOC = """## Interface: 16001, 20506, 11509
## Title: Amisia: Raid
## Version: {v}
## Dependencies: Amisia

Raid\\Rolls.lua
Raid\\Handover.lua [AllowLoadGameType camelot]
"""
GEAR_TOC = """## Interface: 16001
## Title: Amisia: Gear & Dungeons
## Version: {v}
## Dependencies: Amisia

Data\\GearData.lua
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
    a = os.path.join(root, 'Amisia')
    write(os.path.join(a, 'Amisia.toc'), TOC.format(v=version))
    write(os.path.join(a, 'Core', 'Core.lua'), 'local ADDON, ns = ...\nns.x = "ü"\n')
    write(os.path.join(a, 'Media', 'Icons', 'x.tga'), b'\x00\x01\xff', 'wb')
    write(os.path.join(a, '.stignore'), '.vscode\n')
    r = os.path.join(root, 'Amisia_Raid')
    write(os.path.join(r, 'Amisia_Raid.toc'), RAID_TOC.format(v=version))
    write(os.path.join(r, 'Raid', 'Rolls.lua'), '-- rolls\n')
    write(os.path.join(r, 'Raid', 'Handover.lua'), '-- trade\n')
    g = os.path.join(root, 'Amisia_Gear')
    write(os.path.join(g, 'Amisia_Gear.toc'), GEAR_TOC.format(v=version))
    write(os.path.join(g, 'Data', 'GearData.lua'), '-- GENERATED\n')
    build.flavor_tocs(root, write=True)
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
    write(os.path.join(root, 'Amisia-Website', 'index.html'), '<!doctype html>\n')
    marker = str(tmp_path / 'copied')
    write(os.path.join(root, 'tools', 'release_addon.sh'), f'#!/usr/bin/env bash\necho copied > "{marker}"\n')
    sh(root, 'git', 'add', '-A')
    sh(root, 'git', 'commit', '-q', '-m', 'Amisia 1.0.0: the first')
    write(os.path.join(root, 'Amisia', 'Core', 'Core.lua'), 'local ADDON, ns = ...\nns.x = 2\n')
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
    assert 'Core/Core.lua' in files and 'UI/Pages/About.lua' in files
    assert files.index('Locales/Locale.lua') == 0, 'the locale loads first'
    first = [f for f in files if not f.startswith('Locales/')][0]
    assert first == 'Core/Registry.lua', 'the registry loads right after the locale files'
    # the modules (F-202): their own folders and TOCs, the same version
    assert build.addon_folders(ROOT) == ['Amisia', 'Amisia_Raid', 'Amisia_Gear']
    assert 'Gear/MapPins.lua' in build.toc_files(ROOT, 'Amisia_Gear') and 'Raid/Awards.lua' in build.toc_files(ROOT, 'Amisia_Raid')
    assert build.toc_version(ROOT, 'Amisia_Raid') == v and build.toc_version(ROOT, 'Amisia_Gear') == v


def test_set_toc_version(tmp_path):
    make_addon(str(tmp_path), '1.2.3')
    assert build.toc_version(str(tmp_path)) == '1.2.3'
    build.set_toc_version(str(tmp_path), '1.10.0')
    assert build.toc_version(str(tmp_path)) == '1.10.0'
    with open(build.toc_path(str(tmp_path)), encoding='utf-8') as fh:
        assert fh.read() == TOC.format(v='1.10.0'), 'nothing else in the TOC changes'
    # the modules follow the core (D-16, D-130)
    with open(build.toc_path(str(tmp_path), 'Amisia_Gear'), encoding='utf-8') as fh:
        assert fh.read() == GEAR_TOC.format(v='1.10.0')
    assert build.version_key('1.10.0') > build.version_key('1.9.9')


def test_check_toc_finds_missing_and_unlisted_files(tmp_path):
    a = make_addon(str(tmp_path))
    assert build.check_toc(str(tmp_path)) == []
    write(os.path.join(a, 'Raid', 'New.lua'), '-- new\n')
    os.remove(os.path.join(str(tmp_path), 'Amisia_Gear', 'Data', 'GearData.lua'))
    write(os.path.join(a, 'Raid', 'Rolls.lua'), '-- twice\n')
    bad = build.check_toc(str(tmp_path))
    assert 'Amisia_Gear/Data/GearData.lua: in the TOC, but no such file' in bad
    assert 'Raid/New.lua: not in the TOC' in bad
    assert 'Raid/Rolls.lua: in Amisia and in Amisia_Raid (a path stands in one folder only)' in bad


def test_check_toc_wants_the_core_version_in_the_modules(tmp_path):
    make_addon(str(tmp_path))
    path = build.toc_path(str(tmp_path), 'Amisia_Raid')
    write(path, RAID_TOC.format(v='0.9.0'))
    build.flavor_tocs(str(tmp_path), write=True)
    assert build.check_toc(str(tmp_path)) == [
        "Amisia_Raid.toc: ## Version 0.9.0 is not the core's 1.0.0 (python3 tools/build.py tocs)"]


def test_flavor_tocs_leave_out_the_forever_parts(tmp_path):
    a = make_addon(str(tmp_path))
    with open(os.path.join(a, 'Amisia.toc'), 'a', encoding='utf-8') as fh:
        fh.write('Gear\\Gear.lua [AllowLoadGameType camelot]\nRaid\\New.lua\n')
    write(os.path.join(a, 'Gear', 'Gear.lua'), '-- gear\n')
    write(os.path.join(a, 'Raid', 'New.lua'), '-- new\n')
    assert 'Amisia_TBC.toc: not current with Amisia.toc (python3 tools/build.py tocs)' in build.check_toc(str(tmp_path))
    build.flavor_tocs(str(tmp_path), write=True)
    assert build.check_toc(str(tmp_path)) == []
    with open(os.path.join(a, 'Amisia_TBC.toc'), encoding='utf-8') as fh:
        tbc = fh.read()
    assert '## Interface: 20506\n' in tbc and 'Raid\\New.lua' in tbc and 'Gear' not in tbc
    # the raid module without its Forever-only file; the gear module (Forever only) without any file
    with open(os.path.join(str(tmp_path), 'Amisia_Raid', 'Amisia_Raid_Vanilla.toc'), encoding='utf-8') as fh:
        era = fh.read()
    assert '## Interface: 11509\n' in era and 'Raid\\Rolls.lua' in era and 'Handover' not in era
    with open(os.path.join(str(tmp_path), 'Amisia_Gear', 'Amisia_Gear_TBC.toc'), encoding='utf-8') as fh:
        gear = fh.read()
    assert '## Interface: 20506\n' in gear and '## Dependencies: Amisia\n' in gear and '.lua' not in gear


def test_check_utf8(tmp_path):
    a = make_addon(str(tmp_path))
    assert build.check_utf8(str(tmp_path)) == [], 'UTF-8 text and a binary texture pass'
    write(os.path.join(a, 'Core', 'Bad.lua'), 'local a = 1\n-- K\xf6nig\n'.encode('latin-1'), 'wb')
    write(os.path.join(a, 'Core', 'Bom.lua'), b'\xef\xbb\xbf-- x\n', 'wb')
    bad = build.check_utf8(str(tmp_path))
    assert any(b.startswith('Amisia/Core/Bad.lua:2: not UTF-8') for b in bad), bad
    assert 'Amisia/Core/Bom.lua: byte order mark' in bad


# ---------------------------------------------------------------- data
def test_data_steps_order():
    names = [s[0] for s in build.data_steps()]
    assert names == ['scan archive', 'dungeons', 'gear', 'map', 'dungeon quests', 'quests', 'quest items', 'professions', 'talents',
                     'mage scrolls', 'raid check', 'enchants', 'dungeon art', 'site drops', 'bis', 'scan lists']
    steps = {s[0]: s for s in build.data_steps(sv='/x/Amisia.lua', wago='/w', refresh_att=True)}
    assert steps['gear'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua', '--refresh-att']
    assert steps['bis'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua']
    assert steps['dungeon quests'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua'], \
        "the collector's own quest observations; the client tables for the scanned dungeon quests (D-109)"
    assert steps['quest items'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua'], 'the own item links (F-173)'
    assert steps['scan archive'][2] == ['update', '--wago', '/w', '--sv', '/x/Amisia.lua']
    # the scans by id (D-104): boss NPCs from the NPC scan, the lists and names last
    assert steps['dungeons'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua']
    assert steps['scan lists'][2] == ['--wago', '/w', '--sv', '/x/Amisia.lua']
    # the guild's boss kills for the site (F-187): before the BiS build, which reads the same archive
    assert steps['site drops'][1:] == ('build_site_drops.py', ['--sv', '/x/Amisia.lua'], None, None)
    assert {s[0]: s for s in build.data_steps()}['site drops'][2] == [], 'without --sv: the default file when it is there'
    assert steps['talents'][4] == 'skip' and steps['professions'][4] == 'skip'
    assert steps['mage scrolls'][2] == ['--wago', '/w'] and steps['mage scrolls'][4] == 'skip'
    import build_magescrolls
    assert steps['mage scrolls'][3] == build_magescrolls.REQUIRED
    import build_raidcheck
    assert steps['raid check'][3] == build_raidcheck.REQUIRED and steps['raid check'][4] == 'skip'
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
def notes(root, text, message='Notes'):
    """English notes under "## Unreleased" (D-60), committed."""
    path = os.path.join(root, 'CHANGELOG.md')
    old = open(path, encoding='utf-8').read() if os.path.exists(path) else build.CHANGELOG_HEAD + '\n## Unreleased\n'
    write(path, old.replace('## Unreleased\n', '## Unreleased\n\n' + text + '\n', 1))
    sh(root, 'git', 'add', 'CHANGELOG.md')
    sh(root, 'git', 'commit', '-q', '-m', message)


def test_release(repo):
    root = repo['root']
    notes(root, '- feat(core): x is two (F-1)\n  Core now says two.', 'Changelog notes')
    assert build.release(root, '1.1.0', push=True, copy=True, check=lambda: 0, day='2026-10-07') == 0
    assert build.toc_version(root) == '1.1.0'
    subject = head(root)
    assert subject == 'Amisia 1.1.0: Core: x is two; Notes for the next steps; Changelog notes'
    assert head(root, '%B').rstrip().endswith(build.TRAILER)
    assert sh(root, 'git', 'status', '--porcelain') == '', 'everything committed'
    with zipfile.ZipFile(os.path.join(root, 'Amisia-Website', 'Amisia.zip')) as zf:
        names = sorted(zf.namelist())
        assert names == ['Amisia/Amisia.toc', 'Amisia/Amisia_TBC.toc', 'Amisia/Amisia_Vanilla.toc',
                         'Amisia/Core/Core.lua', 'Amisia/Media/Icons/x.tga',
                         'Amisia_Gear/Amisia_Gear.toc', 'Amisia_Gear/Amisia_Gear_TBC.toc', 'Amisia_Gear/Amisia_Gear_Vanilla.toc',
                         'Amisia_Gear/Data/GearData.lua',
                         'Amisia_Raid/Amisia_Raid.toc', 'Amisia_Raid/Amisia_Raid_TBC.toc', 'Amisia_Raid/Amisia_Raid_Vanilla.toc',
                         'Amisia_Raid/Raid/Handover.lua', 'Amisia_Raid/Raid/Rolls.lua'], names
        assert '## Version: 1.1.0' in zf.read('Amisia/Amisia.toc').decode('utf-8')
        assert '## Version: 1.1.0' in zf.read('Amisia/Amisia_TBC.toc').decode('utf-8'), 'the classic TOCs follow'
        assert '## Version: 1.1.0' in zf.read('Amisia_Raid/Amisia_Raid.toc').decode('utf-8'), 'the modules follow'
        assert '## Version: 1.1.0' in zf.read('Amisia_Gear/Amisia_Gear_TBC.toc').decode('utf-8')
    with open(os.path.join(root, 'CHANGELOG.md'), encoding='utf-8') as fh:
        log = fh.read()
    url = build.REPO_URL
    assert (f'## [v1.1.0]({url}/releases/tag/v1.1.0) (2026-10-07)\n\n'
            f'[Full Changelog]({url}/compare/v1.0.0...v1.1.0) [Previous Releases]({url}/releases)\n\n'
            '- feat(core): x is two (F-1)\n  Core now says two.\n') in log
    assert '## Unreleased\n\n## [v1.1.0]' in log, 'an empty Unreleased above the new section'
    assert build.changelog_section(root, '1.1.0').endswith('Core now says two.')
    assert sh(repo['bare'], 'git', 'tag').split() == ['v1.1.0'], 'the tag is pushed'
    assert sh(repo['bare'], 'git', 'log', '-1', '--format=%s', 'main').strip() == subject, 'pushed to origin'
    assert os.path.exists(repo['marker']), 'tools/release_addon.sh ran'

    # the next release lists only what came after this one, above the old section
    write(os.path.join(root, 'notes.txt'), 'more\n')
    sh(root, 'git', 'commit', '-q', '-am', 'More notes')
    # no English notes: the release stops before anything changes
    with pytest.raises(SystemExit, match='Unreleased'):
        build.release(root, '1.1.1', push=False, copy=False, check=lambda: 0)
    assert build.toc_version(root) == '1.1.0' and sh(root, 'git', 'status', '--porcelain') == ''
    notes(root, '- fix(notes): more notes')
    assert build.release(root, '1.1.1', summary='small fixes', push=False, copy=False, check=lambda: 0,
                         day='2026-10-08') == 0
    assert head(root) == 'Amisia 1.1.1: small fixes'
    with open(os.path.join(root, 'CHANGELOG.md'), encoding='utf-8') as fh:
        log = fh.read()
    assert log.index('## [v1.1.1]') < log.index('- fix(notes): more notes') < log.index('## [v1.1.0]')
    assert 'compare/v1.1.0...v1.1.1' in log and log.count('# Changelog') == 1 and log.count('## Unreleased') == 1
    assert 'v1.1.1' in sh(root, 'git', 'tag').split(), 'tagged locally without a push'


def test_release_uploads_only_what_was_pushed(repo, capsys):
    root, sent, published = repo['root'], [], []
    notes(root, '- feat: one')
    assert build.release(root, '1.1.0', push=True, copy=False, check=lambda: 0,
                         upload=lambda r: sent.append(build.toc_version(r)) or 0,
                         publish=lambda r, v: published.append(v) or 0) == 0
    assert sent == ['1.1.0'] and published == ['1.1.0'], 'after the push, with the new version'
    notes(root, '- feat: two', 'Nothing')
    assert build.release(root, '1.1.1', push=False, copy=False, check=lambda: 0, upload=lambda r: sent.append(r) or 0,
                         publish=lambda r, v: published.append(v) or 0) == 0
    assert sent == ['1.1.0'] and published == ['1.1.0'], 'no push, no upload, no GitHub release'
    notes(root, '- feat: three', 'Again')
    assert build.release(root, '1.1.2', push=True, copy=False, check=lambda: 0, upload=lambda r: 1,
                         publish=lambda r, v: 1) == 1
    out = capsys.readouterr().out
    assert 'CurseForge has not got it: python3 tools/curseforge.py upload' in out
    assert 'no GitHub release for v1.1.2: python3 tools/build.py github-release 1.1.2' in out


def test_restart_note(repo):
    root = repo['root']
    first = build.last_release_commit(root)
    assert first and build.restart_note(root, first) == 'Im Spiel: /reload.', 'only Lua changed'
    assert 'neu starten' in build.restart_note(root, None)
    toc = os.path.join(root, 'Amisia', 'Amisia.toc')
    with open(toc, encoding='utf-8') as fh:
        text = fh.read()
    write(toc, text.rstrip('\n') + '\nCore/New.lua\n')
    write(os.path.join(root, 'Amisia', 'Core', 'New.lua'), '-- new\n')
    write(os.path.join(root, 'Amisia', 'Media', 'Icons', 'y.tga'), b'\x00', 'wb')
    sh(root, 'git', 'add', '-A')
    sh(root, 'git', 'commit', '-q', '-m', 'A new file and a new icon')
    note = build.restart_note(root, first)
    assert 'neu starten' in note and 'TOC' in note and 'Bilder' in note, note


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
    assert not os.path.exists(os.path.join(root, 'Amisia-Website', 'Amisia.zip'))
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
    write(os.path.join(root, 'Amisia', 'Core', 'Untracked.lua'), '-- new\n')
    with pytest.raises(SystemExit, match='not clean'):
        build.release(root, '1.1.0', push=False, copy=False, check=lambda: 0)
    os.remove(os.path.join(root, 'Amisia', 'Core', 'Untracked.lua'))
    sh(root, 'git', 'checkout', '-q', '-b', 'dev')
    with pytest.raises(SystemExit, match='from main'):
        build.release(root, '1.1.0', push=True, copy=False, check=lambda: 0)
    assert build.toc_version(root) == '1.0.0'
