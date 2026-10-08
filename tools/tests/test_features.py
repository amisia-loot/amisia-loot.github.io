"""docs/FEATURES.md and tools/features.py: the real file parses and is complete, the test list of a
tiny fixture, `tested` rewrites only the status of the named entry, the release's test list."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import build  # noqa: E402
import features as fe  # noqa: E402

FEATURES = os.path.join(ROOT, 'docs', 'FEATURES.md')

TINY = """# Features

```
### F-999 An example in the description, not an entry
- Version: 9.9.9
```

## Addon

### F-001 Alt und geprüft
- Version: 1.0.0
- Status: im Spiel geprüft (2026-10-01)
- Prüfung: Wenn du A tust, dann passiert A.

### F-002 Neu, allein prüfbar
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du B tust, dann passiert B.
- Prüfung: Wenn du B2 tust, dann passiert B2.
- Notiz: nur eine Notiz

### F-003 Neu, braucht eine Gruppe
- Version: 1.1.0
- Status: gebaut
- Braucht: Gruppe, Raid
- Prüfung: Wenn ihr C tut, dann passiert C.

## Seite

### F-004 Älter, allein prüfbar
- Version: 1.0.0
- Status: gebaut
- Prüfung: Wenn du D tust, dann passiert D.

### F-005 Geplant
- Version: -
- Status: geplant
- Prüfung: Wenn du E tust, dann passiert E.
"""


@pytest.fixture(scope='module')
def real():
    return fe.load(FEATURES)


# ---------------------------------------------------------------- the real file
def test_the_real_file_parses_and_every_entry_is_complete(real):
    assert 40 <= len(real) <= 120, f'{len(real)} entries'
    for f in real:
        assert re.fullmatch(r'F-\d{3}', f.id)
        assert f.title.strip(), f.id
        assert f.status in fe.STATUSES, f.id
        assert 1 <= len(f.checks) <= fe.MAX_CHECKS, f.id
        for c in f.checks:
            assert c.startswith('Wenn '), f'{f.id}: a check reads "Wenn ..., dann ...": {c[:50]}'
            assert 'dann' in c, f'{f.id}: a check reads "Wenn ..., dann ...": {c[:50]}'
        if f.status in (fe.CHECKED, fe.PROVEN):
            assert f.date and f.notes, f'{f.id}: a checked feature names its date and its evidence (Notiz)'
        assert set(f.needs) <= set(fe.NEEDS)


def test_ids_are_unique(real):
    ids = [f.id for f in real]
    assert len(ids) == len(set(ids))


def test_versions_are_real_versions(real):
    current = build.toc_version()
    for f in real:
        if f.status == fe.PLANNED and f.version == '-':
            continue
        assert re.fullmatch(r'\d+\.\d+\.\d+', f.version), f.id
        assert fe.version_key(f.version) <= fe.version_key(current), \
            f'{f.id}: version {f.version} is newer than the TOC version {current}'


def test_addon_and_site_have_their_sections(real):
    sections = {f.section for f in real}
    assert any(s.startswith('Addon') for s in sections)
    assert 'Seite' in sections


# ---------------------------------------------------------------- the parser
def test_parse_reads_the_fields_and_skips_fenced_examples():
    feats = fe.parse(TINY)
    assert [f.id for f in feats] == ['F-001', 'F-002', 'F-003', 'F-004', 'F-005']
    one, two, three = feats[:3]
    assert (one.status, one.date) == (fe.CHECKED, '2026-10-01')
    assert two.checks == ['Wenn du B tust, dann passiert B.', 'Wenn du B2 tust, dann passiert B2.']
    assert two.notes == ['nur eine Notiz'] and two.alone
    assert three.needs == ['Gruppe', 'Raid'] and not three.alone
    assert feats[3].section == 'Seite'


@pytest.mark.parametrize('bad, says', [
    (TINY.replace('- Status: gebaut\n- Prüfung: Wenn du D', '- Status: fertig\n- Prüfung: Wenn du D'), 'status "fertig"'),
    (TINY.replace('im Spiel geprüft (2026-10-01)', 'im Spiel geprüft'), 'needs its date'),
    (TINY.replace('### F-004', '### F-002'), 'F-002 again'),
    (TINY.replace('- Prüfung: Wenn du D tust, dann passiert D.\n', ''), '0 checks'),
    (TINY.replace('- Braucht: Gruppe, Raid', '- Braucht: Freunde'), 'Braucht takes'),
    (TINY.replace('- Notiz: nur eine Notiz', 'freier Text'), 'line 20'),
    (TINY.replace('- Version: 1.0.0\n- Status: gebaut', '- Version: 1.0\n- Status: gebaut'), 'not X.Y.Z'),
])
def test_parse_refuses_malformed_entries(bad, says):
    with pytest.raises(fe.FeatureError, match=re.escape(says)):
        fe.parse(bad)


# ---------------------------------------------------------------- test list
def test_testlist_of_a_tiny_file():
    text = fe.testlist(fe.parse(TINY), version='1.1.0')
    assert text == (
        '# Testliste Amisia (Stand 1.1.0)\n\n'
        'Gebaute Features, die noch niemand im Spiel geprüft hat. Was klappt: `python3 tools/build.py tested F-xxx`.\n\n'
        '## 1.1.0\n\n'
        '### F-002 Neu, allein prüfbar\n'
        '- [ ] Wenn du B tust, dann passiert B.\n'
        '- [ ] Wenn du B2 tust, dann passiert B2.\n\n'
        '## 1.0.0\n\n'
        '### F-004 Älter, allein prüfbar\n'
        '- [ ] Wenn du D tust, dann passiert D.\n')


def test_testlist_all_adds_the_group_features_in_their_own_section():
    text = fe.testlist(fe.parse(TINY), all_=True)
    head, later = text.split('## Erst nach dem Start (Gruppe/Gilde/Raid)\n')
    assert 'F-003' not in head and 'F-002' in head
    assert '### F-003 Neu, braucht eine Gruppe (braucht: Gruppe, Raid)\n- [ ] Wenn ihr C tut, dann passiert C.\n' in later
    assert 'F-001' not in text and 'F-005' not in text, 'checked and planned features are no tests'


def test_release_list_names_the_features_of_the_version():
    feats = fe.parse(TINY)
    text = fe.release_list(feats, '1.1.0')
    assert 'F-002' in text and 'F-003 Neu, braucht eine Gruppe (braucht: Gruppe, Raid)' in text and 'F-004' not in text
    assert fe.release_list(feats, '1.2.0') is None


# ---------------------------------------------------------------- tested
def test_tested_rewrites_only_the_status_of_the_named_entry():
    new, msgs = fe.mark_tested(TINY, ['f-002'], day='2026-10-08')
    old_lines, new_lines = TINY.split('\n'), new.split('\n')
    changed = [(a, b) for a, b in zip(old_lines, new_lines) if a != b]
    assert changed == [('- Status: gebaut', '- Status: im Spiel geprüft (2026-10-08)')]
    assert new_lines.index('- Status: im Spiel geprüft (2026-10-08)') == old_lines.index('### F-002 Neu, allein prüfbar') + 2
    assert len(msgs) == 1 and 'F-002' in msgs[0]
    assert {f.id: f.status for f in fe.parse(new)}['F-002'] == fe.CHECKED


def test_tested_with_raid_and_a_raid_status_that_stays():
    new, _ = fe.mark_tested(TINY, ['F-003'], raid=True, day='2026-12-10')
    assert '- Status: im Raid bewährt (2026-12-10)' in new
    again, msgs = fe.mark_tested(new, ['F-003'], day='2026-12-11')
    assert again == new and 'stays' in msgs[0]


def test_tested_refuses_unknown_ids_and_changes_nothing():
    with pytest.raises(fe.FeatureError, match='F-777'):
        fe.mark_tested(TINY, ['F-002', 'F-777'], day='2026-10-08')
    with pytest.raises(fe.FeatureError, match='YYYY-MM-DD'):
        fe.mark_tested(TINY, ['F-002'], day='8.10.2026')


# ---------------------------------------------------------------- build.py around it
def test_the_release_warns_when_no_feature_carries_its_version(tmp_path):
    os.makedirs(tmp_path / 'docs')
    (tmp_path / 'docs' / 'FEATURES.md').write_text(TINY, encoding='utf-8')
    lines = build.release_test_list(str(tmp_path), '1.1.0')
    assert lines[0].startswith('Zum Testen im Spiel (1.1.0)') and any('F-002' in ln for ln in lines)
    assert build.release_test_list(str(tmp_path), '1.2.0')[0].startswith('WARNING: no feature')
    (tmp_path / 'docs' / 'FEATURES.md').write_text(TINY.replace('- Status: gebaut', '- Status: neu'), encoding='utf-8')
    assert build.release_test_list(str(tmp_path), '1.1.0')[0].startswith('WARNING:')
    os.remove(tmp_path / 'docs' / 'FEATURES.md')
    assert build.release_test_list(str(tmp_path), '1.1.0')[0].startswith('WARNING: no docs/FEATURES.md')
