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


def test_the_download_keeps_the_presets_the_gear_sets_and_the_licence_only():
    assert ws.kept('ui/specs/priest/dps/presets.ts') and ws.kept('LICENSE')
    assert ws.kept('ui/specs/druid/feral_ep.ts')
    assert not ws.kept('ui/specs/priest/dps/apls/default.apl.json')
    # the gear sets (F-239) and the proto with their slot order
    assert ws.kept('ui/specs/priest/dps/gear_sets/p1.gear.json') and ws.kept('ui/specs/mage/dps/gear_sets/preraidFire.gear.json')
    assert ws.kept('ui/specs/hunter/dps/gear_sets/prebis_weave.gear.siml') and ws.kept('proto/common.proto')
    assert not ws.kept('ui/specs/priest/dps/gear_sets/notes.md') and not ws.kept('ui/specs/priest/dps/builds/x.build.json')
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


# ---------------------------------------------------------------- gear sets (F-239)
NAMES = {15411: 'Mark of Fordring', 12640: 'Lionheart Helm', 19587: "Forest Stalker's Bracers",
         19589: "Forest Stalker's Bracers", 19590: "Forest Stalker's Bracers", 15063: 'Devilsaur Gauntlets',
         99063: 'Devilsaur Gauntlets', 22086: 'Soulforge Belt', 226994: 'Soulforge Belt',
         10388: 'Masterwork Legplates', 21477: "Don Julio's Band"}
LEVELS = {19587: 65, 19589: 55, 19590: 45, 22086: 65, 226994: 60}


def test_the_slot_order_is_the_sims_item_slot():
    """SLOT_ORDER is ItemSlot of proto/common.proto, checked against the download when this machine has one."""
    assert ws.SLOT_ORDER[0] == 'HEAD' and ws.SLOT_ORDER[14] == 'MAINHAND' and len(ws.SLOT_ORDER) == 17
    assert set(ws.SIML_SLOT.values()) == set(ws.SLOT_ORDER)
    proto = os.path.join(ws.WOWSIMS_CACHE, 'proto', 'common.proto')
    if os.path.exists(proto):
        with open(proto, encoding='utf-8') as fh:
            text = fh.read()
        body = text[text.index('enum ItemSlot {'):]
        body = body[:body.index('}')]
        import re
        names = re.findall(r'ItemSlot(\w+)\s*=\s*(\d+)', body)
        assert [n.upper() for n, _ in names] == list(ws.SLOT_ORDER)
        assert [int(i) for _, i in names] == list(range(17))


def test_the_gear_presets_are_read_as_text():
    got = ws.parse_gear_presets(read('ui', 'specs', 'mage', 'dps', 'presets.ts'))
    assert got == [('Preraid', 'Arcane', './gear_sets/preraid.gear.json', 'PreRaidArcaneGearJson'),
                   ('Preraid', 'Fire', './gear_sets/preraidFire.gear.json', 'PreRaidFireGearJson'),
                   ('Preraid', 'Frost', './gear_sets/preraidFrost.gear.json', 'PreRaidFrostGearJson'),
                   ('Preraid', 'Arcane', None, 'DefaultsJson.player.equipment'),
                   ('Odd', None, './gear_sets/preraidFire.gear.json', 'PreRaidFireGearJson')]
    # the options as a const of the file and as an object over several lines
    got = ws.parse_gear_presets(read('ui', 'specs', 'warrior', 'dps', 'presets.ts'))
    assert [(g[0], g[1]) for g in got] == [('Pre-BiS', 'Fury'), ('Pre-BiS', 'Arms')]


def test_a_gear_json_lists_its_items_in_slot_order():
    items = ws.parse_gear_json(read('ui', 'specs', 'mage', 'dps', 'gear_sets', 'preraid.gear.json'))
    # empty slots and id 0 left out
    assert items == {'HEAD': 10041, 'NECK': 18691, 'CHEST': 14152, 'MAINHAND': 22799, 'RANGED': 13938}


def test_a_gear_siml_names_its_items():
    assert ws.slug("Don Julio's Band") == 'don_julios_band' and ws.slug('Thunderfury, Blessed Blade') == 'thunderfury_blessed_blade'
    items, missing = ws.parse_gear_siml(read('ui', 'specs', 'warrior', 'dps', 'gear_sets', 'prebis_arms.gear.siml'),
                                        ws.item_slugs(NAMES), known={15411}, levels=LEVELS)
    assert items == {'HEAD': 12640, 'NECK': 15411,
                     'WRIST': 19587,      # one name in three item levels: the highest
                     'HANDS': 15063,      # _<id> picks among the name's items
                     'WAIST': 22086,      # _ilvl<N> picks the item level
                     'LEGS': 10388,       # the random suffix is dropped
                     'FINGER1': 21477}
    assert missing == ['main_hand something_nobody_knows']


def test_load_sets_maps_the_presets_by_hand(capsys):
    sets = ws.load_sets(FIXTURE, NAMES, (), LEVELS)
    assert list(sets) == ['WARRIOR', 'MAGE'], "in the classes' order"
    assert sets['MAGE'] == [
        {'name': 'Arkan Pre-BiS', 'spec': 'arcane',
         'items': {'HEAD': 10041, 'NECK': 18691, 'CHEST': 14152, 'MAINHAND': 22799, 'RANGED': 13938}},
        {'name': 'Feuer Pre-BiS', 'spec': 'fire',
         'items': {'HEAD': 10041, 'NECK': 18691, 'CHEST': 14152, 'FINGER1': 942, 'FINGER2': 1156}}]
    assert [(t['name'], t['spec']) for t in sets['WARRIOR']] == [('Furor Pre-BiS', 'dps'), ('Waffen Pre-BiS', 'dps')]
    assert sets['WARRIOR'][0]['items'] == {'HEAD': 12640, 'MAINHAND': 12940, 'OFFHAND': 12939}
    err = capsys.readouterr().err
    assert 'the same items as "Arkan Pre-BiS"' in err
    assert '"Odd" has no name in SET_NAMES' in err and 'DefaultsJson.player.equipment' in err
    assert 'no item for main_hand something_nobody_knows' in err
    # without item names a .gear.siml is left out, a .gear.json still reads
    sets = ws.load_sets(FIXTURE, None, (), None, quiet=True)
    assert [t['name'] for t in sets['WARRIOR']] == ['Furor Pre-BiS']


def test_every_set_fits_amisia():
    """Every mapped spec is one of Amisia's, every set name short enough for the menu."""
    import build_bis as bb
    specs = {(c, k) for c, k, *_ in bb.SPECS}
    for folder, (cls, spec, labels) in ws.SET_NAMES.items():
        assert cls in ws.CLASS_ORDER, folder
        for de, own in labels.values():
            assert (own or spec) is None or (cls, own or spec) in specs, (folder, de)
            assert len(de) <= 28, de


def test_the_sets_stand_in_the_weights_file_with_their_source():
    import build_bis as bb
    sets = ws.load_sets(FIXTURE, NAMES, (), LEVELS, quiet=True)
    conv = bb.Conv({})
    result = {}
    for cls, key, name, role, model, p in bb.SPECS:
        w = {'AP': 1} if model != 'caster' else {'SP': 1}
        result[(cls, key)] = ([w] * len(bb.BRACKETS), [w] * len(bb.BRACKETS), [{}] * len(bb.BRACKETS))
    text = bb.render_weights(result, conv, {'built': 'x', 'sim_commit': '0123456789abcdef'}, None, None, sets)
    head = [line for line in text.splitlines() if line.startswith('-- SETS')]
    assert head and 'WoWSims' in head[0] and '0123456789' in head[0]
    flat = text.replace(' ', '')
    assert 'SETS={' in flat and 'SIM={' not in flat
    assert '{name="Arkan Pre-BiS",spec="arcane",items={HEAD=10041,NECK=18691,CHEST=14152,MAINHAND=22799,RANGED=13938}},'.replace(' ', '') in flat
    assert 'SETS' not in bb.render_weights(result, conv, {'built': 'x'}, None, None, None)


@pytest.mark.skipif(not os.path.exists(os.path.join(ws.WOWSIMS_CACHE, 'ui', 'specs', 'mage', 'dps', 'gear_sets')),
                    reason='no WoWSims gear sets on this machine')
def test_the_real_gear_sets_read():
    sets = ws.load_sets(quiet=True)
    arcane = next(t for t in sets['MAGE'] if t['name'] == 'Arkan Pre-BiS')
    assert arcane['spec'] == 'arcane' and len(arcane['items']) >= 15
