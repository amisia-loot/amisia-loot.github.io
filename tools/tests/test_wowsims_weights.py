"""tools/wowsims_weights.py: the WoWSims weights for WoW Forever (MIT) as templates of the own weights (F-230, D-161),
read as text from a cut of its presets.ts files (tools/tests/fixtures/wowsims), never run; the download's choice of
files and its one request at a time; the templates in GearWeights.lua; Python and Lua convert an own set alike."""
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
import wowsims_weights as ws  # noqa: E402

FIXTURE = os.path.join(HERE, 'fixtures', 'wowsims')


def read(*parts):
    with open(os.path.join(FIXTURE, *parts), encoding='utf-8') as fh:
        return fh.read()


def test_the_presets_are_read_as_text():
    got = ws.parse_presets(read('ui', 'specs', 'priest', 'dps', 'presets.ts'))
    names = [g[0] for g in got]
    assert names == ['Shadow', 'Mind Flay Only', 'Smite']
    shadow = got[0][1]
    assert shadow == {'INT': 0.24, 'SP': 1.0, 'SP_SHADOW': 1.0, 'SPI': 0.01, 'HIT': 1.14, 'CRIT': 0.84, 'HASTE': 0.73}
    # an unknown stat is named, a known one Amisia does not score is left out quietly
    smite, skipped = got[2][1], got[2][2]
    assert smite == {'INT': 0.58, 'SP': 1.0, 'SP_HOLY': 0.81, 'MP5': 1.46}
    assert skipped == ['StatFancyNewStat (no key in Amisia)']


def test_a_name_leads_to_the_shared_weights_and_a_computed_one_is_never_run():
    shared = [read('ui', 'specs', 'druid', 'feral_ep.ts')]
    got = dict((g[0], g) for g in ws.parse_presets(read('ui', 'specs', 'druid', 'feralbear', 'presets.ts'), shared))
    bear = got['Bear'][1]
    # FeralAttackPower and BonusArmor have no key of their own; MainHandDps is the weapon's damage per second
    assert bear == {'STA': 1.0029, 'ARMOR': 0.1744, 'DPS': 3.0931}
    assert got['Hybrid'][1] is None and 'not a plain map' in got['Hybrid'][2][0]


def test_a_value_that_is_no_plain_number_is_left_out_with_its_reason():
    got = ws.parse_presets(read('ui', 'specs', 'paladin', 'retribution', 'presets.ts'))
    name, w, skipped = got[0]
    assert name == 'Holy Shock' and w == {'STR': 2.5, 'AP': 1.0, 'HIT': 10.25, 'DPS': 13.04}
    assert any('SchoolHitPercentHoly' in s and 'not a plain number' in s for s in skipped)


def test_load_maps_the_specs_by_hand(capsys):
    sims = ws.load(FIXTURE)
    assert list(sims) == ['PALADIN', 'PRIEST', 'DRUID'], 'in the classes\' order'
    assert sims['PRIEST'] == [
        {'name': 'Schatten', 'spec': 'shadow', 'w': {'INT': 0.24, 'SP': 1.0, 'SP_SHADOW': 1.0, 'SPI': 0.01, 'HIT': 1.14,
                                                      'CRIT': 0.84, 'HASTE': 0.73}},
        {'name': 'Schmettern', 'spec': None, 'w': {'INT': 0.58, 'SP': 1.0, 'SP_HOLY': 0.81, 'MP5': 1.46}}]
    assert sims['DRUID'] == [{'name': 'Bär', 'spec': 'bear', 'w': {'STA': 1.0029, 'ARMOR': 0.1744, 'DPS': 3.0931}}]
    err = capsys.readouterr().err
    assert '"Mind Flay Only" has no name in SPECS' in err and 'StatFancyNewStat' in err
    # the folders the fixture lacks are named, nothing breaks
    assert 'shaman/elemental/presets.ts is missing' in err


def test_every_template_fits_amisia():
    """Every mapped spec is one of Amisia's (GearWeights.lua), every name short enough for "<Name> (Sim)", every key
    one of the own keys (Gear.OWN_KEYS), every value within -10 .. 100."""
    import build_bis as bb
    keys = set(bb.OWN_KEYS)
    specs = {(c, k) for c, k, *_ in bb.SPECS}
    for folder, (cls, spec, names) in ws.SPECS.items():
        assert cls in ws.CLASS_ORDER, folder
        for de, own in names.values():
            assert (own or spec) is None or (cls, own or spec) in specs, (folder, de)
            assert len(de + ' (Sim)') <= 32, de
    assert set(ws.STAT_KEY.values()) <= keys
    assert not (set(ws.STAT_KEY) & ws.SKIPPED)


def test_the_download_keeps_the_presets_and_the_licence_only():
    assert ws.kept('ui/specs/priest/dps/presets.ts') and ws.kept('LICENSE')
    assert ws.kept('ui/specs/druid/feral_ep.ts')
    assert not ws.kept('ui/specs/priest/dps/apls/default.apl.json')
    assert not ws.kept('ui/specs/priest/dps/gear_sets/p1.gear.json')
    assert not ws.kept('sim/priest/shadow.go') and not ws.kept('README.md')
    assert not ws.kept('ui/specs/priest/dps/sim.tsx')


def test_the_download_asks_one_file_after_the_other(tmp_path, monkeypatch):
    blobs = {'a1': b"makePresetEpWeights('Shadow', Stats.fromMap({}))", 'b2': b'MIT License', 'c3': b'nope'}
    tree = {'tree': [{'path': 'ui/specs/priest/dps/presets.ts', 'type': 'blob', 'sha': 'a1'},
                     {'path': 'LICENSE', 'type': 'blob', 'sha': 'b2'},
                     {'path': 'ui/specs/priest/dps/sim.tsx', 'type': 'blob', 'sha': 'c3'},
                     {'path': 'ui/specs', 'type': 'tree', 'sha': 'd4'}]}
    asked, sleeps = [], []

    class Answer:
        def __init__(self, body):
            self.body = body

        def read(self):
            return self.body

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    def urlopen(req, timeout=None):
        url = req.full_url
        asked.append(url)
        assert url.startswith('https://api.github.com/repos/wowsims/forever/')
        assert req.get_method() == 'GET' and 'Amisia-build-tool' in req.headers['User-agent']
        if url.endswith('/commits/master'):
            return Answer(json.dumps({'sha': 'c0ffee'}).encode())
        if '/git/commits/' in url:
            return Answer(json.dumps({'tree': {'sha': 't1'}}).encode())
        if '/git/trees/' in url:
            return Answer(json.dumps(tree).encode())
        return Answer(blobs[url.rsplit('/', 1)[1]])

    monkeypatch.setattr(ws.urllib.request, 'urlopen', urlopen)
    monkeypatch.setattr(ws.time, 'sleep', sleeps.append)
    monkeypatch.setattr(ws, '_token', lambda: None)
    (tmp_path / 'old.ts').write_text('x')
    assert ws.refresh(str(tmp_path)) == 'c0ffee'
    assert len(asked) == 5 and len(sleeps) == 5, 'commit, tree, listing and the two kept files, each after a pause'
    assert not any(u.endswith('/c3') for u in asked)
    assert (tmp_path / 'ui' / 'specs' / 'priest' / 'dps' / 'presets.ts').read_bytes() == blobs['a1']
    assert (tmp_path / 'LICENSE').read_bytes() == b'MIT License'
    assert not (tmp_path / 'old.ts').exists() and (tmp_path / 'COMMIT').read_text().strip() == 'c0ffee'


def test_a_missing_download_is_no_template_with_a_note(tmp_path, capsys):
    assert ws.load(str(tmp_path)) is None
    assert 'build.py wowsims' in capsys.readouterr().err


def test_the_templates_stand_in_the_weights_file_with_their_source(tmp_path):
    import build_bis as bb
    sims = ws.load(FIXTURE, quiet=True)
    conv = bb.Conv({})
    result = {}
    for cls, key, name, role, model, p in bb.SPECS:
        w = {'AP': 1} if model != 'caster' else {'SP': 1}
        result[(cls, key)] = ([w] * len(bb.BRACKETS), [w] * len(bb.BRACKETS), [{}] * len(bb.BRACKETS))
    text = bb.render_weights(result, conv, {'built': 'x', 'sim_commit': '0123456789abcdef'}, None, sims)
    head = '\n'.join(line for line in text.splitlines() if line.startswith('--'))
    assert 'WoWSims' in head and 'MIT' in head and 'LICENSES/WoWSims-MIT.txt' in head and '0123456789' in head
    assert 'SIM={' in text.replace(' ', '') and 'name="Schatten",spec="shadow"' in text.replace(' ', '')
    plain = bb.render_weights(result, conv, {'built': 'x'}, None, None)
    assert 'WoWSims' not in plain and 'SIM' not in plain


@pytest.mark.skipif(not os.path.exists(os.path.join(ws.WOWSIMS_CACHE, 'ui', 'specs', 'priest', 'dps', 'presets.ts')),
                    reason='no WoWSims download on this machine')
def test_the_real_download_reads():
    sims = ws.load(quiet=True)
    shadow = next(t for t in sims['PRIEST'] if t['name'] == 'Schatten')
    assert shadow['spec'] == 'shadow' and shadow['w']['SP'] == 1 and shadow['w']['HIT'] > 1
    assert sum(len(v) for v in sims.values()) >= 20
