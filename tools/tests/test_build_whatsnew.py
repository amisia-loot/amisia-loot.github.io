"""tools/build_whatsnew.py (F-236, D-168): the news of the newest versions from docs/FEATURES.md and CHANGELOG.md,
the shipped Amisia/Data/WhatsNew.lua current for the TOC's version, and build.py release writing it."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)
import build  # noqa: E402
import build_whatsnew as bw  # noqa: E402
import lua_data  # noqa: E402

FEATURES = """# Features

## Addon

### F-010 Raid-Aufnahme
- Version: 2.0.0
- Status: gebaut
- Prüfung: Wenn ..., dann ...

### F-011 Würfel-Fenster – neu
- Version: 2.1.0
- Status: gebaut
- Prüfung: Wenn ..., dann ...

### F-012 Gildenaufträge
- Version: 2.2.0
- Status: geplant
- Prüfung: Wenn ..., dann ...

### F-013 Nur ein Fix
- Version: 2.1.0
- Status: gebaut
- Prüfung: Wenn ..., dann ...
"""

CHANGELOG = """# Changelog

## Unreleased

- feat(orders): guild orders (F-012)

    Text.

## [v2.1.0](https://x/releases/tag/v2.1.0) (2026-11-02)

- fix(rolls): a "quoted" fix (F-013)

    Text.

- feat(rolls): the roll window — new (F-011, F-010)

    Text.

- feat(rolls): a second note of the same feature (F-011)
- feat(site): the website's new tab (F-010)

## [v2.0.0](https://x/releases/tag/v2.0.0) (2026-11-01)

- feat(raid): raids are recorded (F-010)
"""


def test_items_per_version_newest_first():
    data = bw.collect(FEATURES, CHANGELOG, '2.1.0')
    assert [v for v, _ in data] == ['2.1.0', '2.0.0'], 'the Unreleased notes wait for a version of their own'
    items = dict(data)['2.1.0']
    # the feat notes first (one line per feature, the site left out), then a feature of the version without one
    assert items == [('F-011', 'Würfel-Fenster - neu', 'The roll window - new', 'all'),
                     ('F-013', 'Nur ein Fix', 'A "quoted" fix', 'all')]
    assert dict(data)['2.0.0'] == [('F-010', 'Raid-Aufnahme', 'Raids are recorded', 'all')]


def test_unreleased_notes_belong_to_the_new_version():
    data = bw.collect(FEATURES, CHANGELOG, '2.2.0')
    assert data[0] == ('2.2.0', [('F-012', 'Gildenaufträge', 'Guild orders', 'forever')]), 'an unknown scope: Forever'
    assert len(bw.collect(FEATURES, CHANGELOG, '2.2.0', keep=1)) == 1


def test_newer_versions_and_empty_ones_stay_out():
    assert [v for v, _ in bw.collect(FEATURES, CHANGELOG, '2.0.0')] == ['2.0.0']
    log = CHANGELOG.replace('- feat(raid): raids are recorded (F-010)', '- data(raid): tables (F-099)')
    feats = FEATURES.replace('- Version: 2.0.0', '- Version: 2.1.0')
    assert [v for v, _ in bw.collect(feats, log, '2.0.0')] == [], 'no feat note, no feature of that version'


def test_notes_without_a_scope_or_with_decisions_are_read():
    """A feat note may lack its scope and name decisions in its trailing group; a note naming no feature is none."""
    text = ('- feat(dungeons): foo (F-1, D-2)\n- feat: bar (F-3)\n- feat(ui): baz (D-4, F-5)\n'
            '- feat(ui): only a decision (D-6)\n- feat(ui) broken (F-7)\n')
    assert bw.notes(text) == [('feat', 'dungeons', 'foo', ['F-1']), ('feat', '', 'bar', ['F-3']),
                              ('feat', 'ui', 'baz', ['F-5'])]


def test_each_item_names_the_part_it_is_about():
    """The scope of its note mapped by WHERE (every client, Forever's core, a module); a note without a scope takes
    another note's of the same feature, else Forever."""
    log = CHANGELOG.replace('## Unreleased\n', '## Unreleased\n\n- feat(dungeons): runs (F-020, D-169)\n'
                            '- feat: news (F-021)\n- fix(talents): talents fixed (F-021)\n- feat: alone (F-022)\n'
                            '- feat(layer): layers (F-023)\n- feat(gear): weights (F-024)\n')
    items = bw.collect(FEATURES, log, '2.2.0')[0][1]
    where = {fid: w for fid, _, _, w in items}
    assert where == {'F-020': 'dungeons', 'F-021': 'talents', 'F-022': 'forever', 'F-023': 'forever',
                     'F-024': 'gear', 'F-012': 'forever'}
    assert bw.WHERE['raid'] == 'all' and bw.WHERE['professions'] == 'forever' and 'site' not in bw.WHERE


def test_lint_names_feat_notes_the_reader_drops():
    """build.py check: a feat note of the coming or current version without a readable feature, or with a scope
    WHERE does not know, is named; older sections are not."""
    log = CHANGELOG.replace('## Unreleased\n', '## Unreleased\n\n- feat(ui) no colon (F-030)\n'
                            '- feat(ui): only a decision (D-9)\n- feat(nowhere): unknown scope (F-031)\n'
                            '- feat(dungeons): fine (F-032, D-1)\n')
    problems = bw.lint(log, '2.1.0')
    assert len(problems) == 4 and all(p.startswith('Unreleased: ') for p in problems), problems
    assert 'no colon' in problems[0] and 'only a decision' in problems[1] and '"nowhere"' in problems[2]
    assert '"orders"' in problems[3]
    assert bw.lint(log.replace('(F-011, F-010)', 'F-011'), '2.1.0')[-1].startswith('2.1.0: '), 'the current version'


def test_the_changelog_has_no_feat_note_the_reader_drops():
    with open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8') as fh:
        log = fh.read()
    with open(os.path.join(ROOT, 'Amisia', 'Amisia.toc'), encoding='utf-8') as fh:
        version = re.search(r'^## Version:\s*(\S+)', fh.read(), re.M).group(1)
    assert bw.lint(log, version) == []


def test_render_is_lazy_data_with_escaped_strings():
    text = bw.render([('2.1.0', [('F-011', 'Ein "Fenster"', 'A back\\slash', 'dungeons')])], '2.1.0')
    assert 'generated by tools/build_whatsnew.py from' in text.lower()
    assert '\nns.LazyData("WHATSNEW", [' in text and text.rstrip().endswith(', 1)')
    pytest.importorskip('lupa')
    ns = lua_data.load(text, 'WhatsNew.lua')
    t = ns.WHATSNEW
    assert t.version == '2.1.0'
    assert t.versions[1][1] == '2.1.0' and t.versions[1][2][1][2] == 'Ein "Fenster"'
    assert t.versions[1][2][1][3] == 'A back\\slash' and t.versions[1][2][1][4] == 'dungeons'


def test_the_shipped_file_is_current():
    path = bw.out_path()
    with open(path, encoding='utf-8') as fh:
        shipped = fh.read()
    assert shipped == bw.build(), f'{os.path.relpath(path, ROOT)} is not current: python3 tools/build.py whatsnew'
    assert 'Data\\WhatsNew.lua' in open(os.path.join(ROOT, 'Amisia', 'Amisia.toc'), encoding='utf-8').read()


def test_release_writes_it_for_the_new_version(tmp_path):
    from test_build_tool import make_addon, sh, write
    root = str(tmp_path / 'repo')
    os.makedirs(root)
    sh(root, 'git', 'init', '-q', '-b', 'main')
    sh(root, 'git', 'config', 'user.name', 'Test')
    sh(root, 'git', 'config', 'user.email', 'test@example.invalid')
    sh(root, 'git', 'config', 'commit.gpgsign', 'false')
    make_addon(root, '2.1.0')
    write(os.path.join(root, 'Amisia-Website', 'index.html'), '<!doctype html>\n')
    write(os.path.join(root, 'tools', 'release_addon.sh'), '#!/usr/bin/env bash\n')
    write(os.path.join(root, 'docs', 'FEATURES.md'), FEATURES)
    write(os.path.join(root, 'CHANGELOG.md'), CHANGELOG)
    news = bw.out_path(root)
    write(news, bw.build(root, '2.1.0'))
    sh(root, 'git', 'add', '-A')
    sh(root, 'git', 'commit', '-q', '-m', 'Amisia 2.1.0: first')
    seen = {}

    def check():
        with open(news, encoding='utf-8') as fh:
            seen['text'] = fh.read()
        return 0

    assert build.release(root, '2.2.0', push=False, copy=False, check=check, day='2026-11-25') == 0
    assert 'version="2.2.0"' in seen['text'] and '"F-012","Gildenaufträge","Guild orders","forever"' in seen['text'], \
        'written before the check'
    assert sh(root, 'git', 'status', '--porcelain') == '', 'committed with the release'
    with open(news, encoding='utf-8') as fh:
        assert fh.read() == bw.build(root, '2.2.0'), 'the same once the notes are the version\'s section'
