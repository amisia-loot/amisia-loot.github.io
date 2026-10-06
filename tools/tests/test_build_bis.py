"""tools/build_bis.py: the extract of the wago CSVs (fixture CSVs written here, never the real
ones), the conversions and in-game measurements, the derivation of the weights (signs, unit,
fixpoint, tank and Hardcore), the computed stats with their 98 % check, sets, observed random
suffixes, the dungeon facts with their bosses' NPC ids, the drop base stock, and a whole build into
a temporary folder (own header, valid Lua, the same twice)."""
import csv
import json
import math
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import build_bis as bb  # noqa: E402

BUILD = '1.60.1.99999'


def write_csv(folder, table, header, rows):
    path = os.path.join(folder, f'{table}.{BUILD}.csv')
    with open(path, 'w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)
    return path


SPARSE_HEADER = (['ID', 'Display_lang', 'InventoryType', 'OverallQualityID', 'ItemLevel', 'RequiredLevel', 'ItemSet']
                 + [f'StatModifier_bonusStat_{i}' for i in range(10)] + [f'StatPercentEditor_{i}' for i in range(10)])


def sparse_row(iid, inv, q, ilvl, stats=(), item_set=0, req=0):
    ids = [s for s, _ in stats] + [-1] * (10 - len(stats))
    alloc = [a for _, a in stats] + [0] * (10 - len(stats))
    return [iid, f'Item {iid}', inv, q, ilvl, req, item_set] + ids + alloc


def rpp_rows():
    head = ['ID'] + [f'{q}_{i}' for q in ('GoodF', 'SuperiorF', 'EpicF') for i in range(5)]
    rows = []
    for ilvl in range(1, 81):
        # a simple budget: item level per slot column 0, less for the others
        rows.append([ilvl] + [round(ilvl * f * m, 2) for f in (0.5, 0.65, 0.8) for m in (1, 0.75, 0.55, 0.42, 0.3)])
    return head, rows


@pytest.fixture
def wago(tmp_path):
    folder = tmp_path / 'wago'
    folder.mkdir()
    write_csv(folder, 'ItemSparse', SPARSE_HEADER, [
        sparse_row(1001, 1, 2, 30, [(4, 6000), (7, 4000)], item_set=7),   # head: strength, stamina
        sparse_row(1002, 7, 3, 40, [(5, 7000), (6, 3000)], item_set=7),   # legs: intellect, spirit
        sparse_row(1003, 13, 2, 30, [(7, 10000)]),                        # a one-hand weapon: no SC
        sparse_row(1004, 4, 1, 5, []),                                    # a shirt: no gear
        sparse_row(1005, 8, 2, 20, []),                                   # feet without stats: left out
        sparse_row(1006, 10, 2, 20, [(3, 10000), (999, 5000)]),           # an unknown stat id is skipped
    ])
    head, rows = rpp_rows()
    write_csv(folder, 'RandPropPoints', head, rows)
    write_csv(folder, 'ItemSet', ['ID', 'Name_lang'] + [f'ItemID_{i}' for i in range(17)],
              [[7, 'Garb of Tests', 1001, 1002] + [0] * 15, [8, 'Lonely', 1003] + [0] * 16])
    write_csv(folder, 'ItemSetSpell', ['ID', 'SpellID', 'ChrSpecID', 'Threshold', 'ItemSetID'],
              [[1, 501, 0, 2, 7], [2, 502, 0, 2, 7]])
    write_csv(folder, 'SpellEffect', ['ID', 'SpellID', 'EffectIndex', 'Effect', 'EffectAura', 'EffectBasePointsF',
                                      'EffectMiscValue_0'],
              [[1, 501, 0, 6, 29, 12, 0], [2, 502, 0, 6, 42, 5, 0], [3, 999, 0, 6, 29, 1, 0]])
    write_csv(folder, 'LFGDungeons', ['ID', 'Name_lang', 'TypeID', 'ContentTuningID'],
              [[1, 'Wailing Caverns', 0, 11], [57, 'Elwynn Forest', 4, 12]])
    write_csv(folder, 'ContentTuning', ['ID', 'MinLevel', 'MaxLevel'], [[11, 17, 24], [12, 1, 60]])
    return str(folder)


# ---------------------------------------------------------------- the extract
def test_extract_keeps_only_what_the_build_uses(wago):
    gd = bb.extract(wago)
    assert gd['build'] == BUILD
    assert set(gd['items']) == {1001, 1002, 1003, 1006}, 'gear with stats or a set; no shirt, no statless feet'
    assert gd['items'][1001] == [1, 2, 30, 0, 7, [[4, 6000], [7, 4000]]]
    assert gd['rpp'][30]['GoodF'][0] == 15.0
    assert gd['sets'] == {7: {'name': 'Garb of Tests', 'items': [1001, 1002]}}, 'a set needs two items'
    assert gd['setspells'][7] == [[2, 501], [2, 502]]
    assert set(gd['spells']) == {501, 502}, 'only the spells of set bonuses'
    assert gd['lfg'] == {1: ['Wailing Caverns', 17, 24]}, 'dungeons only, levels from ContentTuning'
    # what wago does not publish for Forever is named, with what is missing in the folder
    for t in ('ItemRandomSuffix', 'ItemRandomProperties', 'gtCombatRatings', 'gtChanceToMeleeCrit', 'Item',
              'SpellItemEnchantment'):
        assert t in gd['missing'], t


def test_gamedata_round_trip(wago, tmp_path):
    gd = bb.extract(wago)
    path = tmp_path / 'gd.json'
    bb.save_gamedata(gd, str(path))
    back = bb.load_gamedata(str(path))
    assert back['items'] == gd['items'] and back['rpp'] == gd['rpp'] and back['sets'] == gd['sets']
    text = path.read_text(encoding='utf-8')
    bb.save_gamedata(back, str(path))
    assert path.read_text(encoding='utf-8') == text, 'the same file twice'


def test_find_csv_takes_the_newest_build(tmp_path):
    for b in ('1.60.1.70100', '1.60.1.70235'):
        (tmp_path / f'ItemSparse.{b}.csv').write_text('ID\n', encoding='utf-8')
    assert bb.find_csv(str(tmp_path), 'ItemSparse').endswith('ItemSparse.1.60.1.70235.csv')
    assert bb.find_csv(str(tmp_path), 'ItemSet') is None
    assert bb.find_csv(str(tmp_path / 'nowhere'), 'ItemSparse') is None


# ---------------------------------------------------------------- computed stats
def test_computed_stats_from_allocation_and_budget(wago):
    gd = bb.extract(wago)
    # head (column 0), uncommon: budget 15 at item level 30
    assert bb.computed_stats(gd, 1001) == {'STRENGTH': 9, 'STAMINA': 6}
    # legs, rare, item level 40: budget 26
    assert bb.computed_stats(gd, 1002) == {'INTELLECT': 18, 'SPIRIT': 8}
    assert bb.computed_stats(gd, 1003) is None, 'weapons get no computed stats'
    assert bb.computed_stats(gd, 1006) == {'AGILITY': 8}, 'the unknown stat is left out'
    assert bb.computed_stats(gd, 4242) is None


def test_the_check_against_scans(wago):
    gd = bb.extract(wago)
    rate, n, misses = bb.check_computed(gd, {1001: 'STRENGTH=9;STAMINA=6;RESISTANCE0_NAME=80',
                                             1002: 'INTELLECT=18;SPIRIT=8', 1003: 'STAMINA=4'})
    assert (rate, n, misses) == (1.0, 2, []), 'armour ignored, the weapon not checked'
    rate, n, misses = bb.check_computed(gd, {1001: 'STRENGTH=9;STAMINA=7', 1002: 'INTELLECT=18;SPIRIT=8'})
    assert rate == 0.5 and n == 2 and misses[0][0] == 1001


# ---------------------------------------------------------------- conversions and measurements
def test_rating_curve_matches_gear_lua():
    c = bb.Conv()
    assert math.isclose(c.rating_pp('HIT', 60) * 10, 1)
    assert math.isclose(c.rating_pp('CRIT', 60) * 14, 1)
    assert math.isclose(c.rating_pp('HIT', 34), 2 * c.rating_pp('HIT', 60))
    assert c.rating_pp('HIT', 5) == c.rating_pp('HIT', 10)


REAL_LINE = ('AMISIA-WERTE 1 SHAMAN 18 race=Orc hp=509 mana=553 str=53,53,15,0 agi=35,35,11,0 sta=53,53,15,0 '
             'int=34,34,0,0 spi=48,48,9,0 apstr=106 apagi=0 apsta=0 apint=0 apspi=0 crit=11.563 rcrit=2.403 sc2=10.2516 '
             'sc3=10.2516 sc4=10.2516 sc5=10.2516 sc6=10.2516 sc7=10.2516 dodge=5.483 parry=0 block=4.8 ap=156,0,0 '
             'rap=0,0,0 regen=12.001,0.001 hm=0,0 hr=0,0 hs=0,0 cm=0,0 cr=0,0 cs=0,0 am=0,0 ar=0,0 as=0,0 def=0,0 dr=0,0 '
             'pr=0,0 br=0,0 exp=0,0')


def test_the_self_test_line():
    """The first line from the game (2026-10-06): one shaman at 18 without any rating."""
    s = bb.parse_werte(REAL_LINE)
    assert s['class'] == 'SHAMAN' and s['level'] == 18 and s['race'] == 'Orc'
    assert s['agi'] == 35 and s['int'] == 34 and s['str'] == 53, 'the effective value of base,effective,plus,minus'
    assert s['crit'] == 11.563 and s['spellcrit'] == 10.2516 and s['apstr'] == 106 and s['ap'] == 156
    assert s['ratings']['CRIT'] == [0, 0] and s['ratings']['HIT'] == [0, 0]
    m = bb.derive_measured([s])
    # no rating to pin, and one point cannot separate base crit from agility per percent
    assert m['rating60'] == {} and m['agiPerCritScale'] == {} and m['intPerCritScale'] == {}
    assert m['unpinned'] == ['SHAMAN 18'] and m['sources'] == ['SHAMAN 18']
    # shamans get two attack power per strength (the planner's assumption)
    assert s['apstr'] == 2 * s['str']


def test_measured_slopes_and_ratings(tmp_path):
    a = bb.parse_werte('AMISIA-WERTE 1 ROGUE 60 agi=300,300,0,0 crit=20 int=40,40,0,0 sc2=2 cm=28,2 hm=20,1.6')
    b = bb.parse_werte('AMISIA-WERTE 1 ROGUE 60 agi=271,271,0,0 crit=19 int=40,40,0,0 sc2=2')
    m = bb.derive_measured([a, b])
    assert m['rating60']['CRIT'] == 14 and m['rating60']['HIT'] == 12.5, 'one rating pair pins its kind'
    # 29 agility for 1 % between the two: the default for rogues at 60
    assert m['agiPerCritScale']['ROGUE'] == pytest.approx(1.0)
    assert 'ROGUE' not in m['intPerCritScale'], 'the same intellect pins nothing'
    assert m['unpinned'] == []
    old = bb.parse_werte('AMISIA-WERTE level=60 class=ROGUE agi=300 crit=10.35;cr_CRIT=28:2 junk=x')
    assert old['level'] == 60 and old['class'] == 'ROGUE' and old['ratings']['CRIT'] == [28, 2], 'the older test form'
    path = tmp_path / 'measured.json'
    path.write_text(json.dumps({'samples': [a, b], 'overrides': {'manaPerSpirit5': {'MAGE': 0.7}}}), encoding='utf-8')
    c = bb.Conv(bb.load_measured(str(path)))
    assert c.rating60['HIT'] == 12.5 and c.spirit['MAGE'] == 0.7 and c.sources == ['ROGUE 60', 'ROGUE 60']
    assert bb.Conv(bb.load_measured(str(tmp_path / 'none.json'))).rating60 == bb.RATING_60


def test_the_committed_measurements_load():
    """tools/bis_measured.json: the shaman at 18 with and without an agility item pins the slope
    (8.79 agility per percent, about 1.46 times Classic's curve) and the base crit; the paladin at 9
    is a single point. Unmeasured classes take the shaman's factor."""
    m = bb.load_measured(bb.MEASURED)
    assert m['agiPerCritScale']['SHAMAN'] == pytest.approx(8.79 / 6.0, rel=0.01)
    assert m['baseCrit']['SHAMAN'] == pytest.approx(7.58, abs=0.01)
    assert 'PALADIN 9' in m['unpinned'] and 'PALADIN' not in m['agiPerCritScale']
    c = bb.Conv(m)
    assert c.agi_per_crit('SHAMAN', 18) == pytest.approx(8.79, rel=0.01)
    assert c.agi_per_crit('PALADIN', 9) == pytest.approx(20 * 10 / 60 * m['agiPerCritScale']['SHAMAN'])
    assert c.base_crit('PALADIN') == bb.BASE_CRIT['PALADIN'] and c.base_crit('SHAMAN') == pytest.approx(7.58, abs=0.01)
    # the paladin's point as a check of that estimate: within a percent of crit
    pal = next(s for s in json.load(open(bb.MEASURED, encoding='utf-8'))['samples'] if s['class'] == 'PALADIN')
    assert abs(c.base_crit('PALADIN') + pal['agi'] / c.agi_per_crit('PALADIN', 9) - pal['crit']) < 1.0


# ---------------------------------------------------------------- the weights
def ref(cls, level, **kw):
    r = {'level': level, 'hit': 0, 'spellhit': 0, 'critRating': 0, 'spellCritRating': 0, 'dodgeRating': 0,
         'parryRating': 0, 'block': 0, 'def': 0, 'AP': 0, 'RAP': 0, 'FAP': 0, 'SPP': 0, 'SPD': 0, 'HEAL': 0, 'MP5': 0,
         'ARMOR': 0, 'BLOCKVAL': 0, 'wDPS': 40, 'speed': 3.3, 'ohDPS': 0, 'rDPS': 30, 'rSpeed': 2.8, 'plan': '2H'}
    for k in ('STR', 'AGI', 'STA', 'INT', 'SPI'):
        r[k] = bb.base_attr(cls, level, k)
    for s in bb.SCHOOLS:
        r[s] = 0
    r.update(kw)
    return r


@pytest.mark.parametrize('cls,key,model,p', [(s[0], s[1], s[4], s[5]) for s in bb.SPECS])
def test_every_spec_derives_sane_weights(cls, key, model, p):
    conv = bb.Conv()
    for level in (9, 30, 60):
        speed, hard, shown = bb.derive(cls, model, p, ref(cls, level, ARMOR=300 + 30 * level), conv)
        unit = bb.UNIT[model]
        assert speed[unit] == 1, f'{cls} {key}: the unit weighs 1'
        bb.check_signs(cls, key, speed)
        assert all(v >= 0 for k, v in speed.items()), f'{cls} {key}: no negative weight'
        # Hardcore adds survival: stamina never weighs less, for a damage dealer more
        assert hard['STA'] >= speed['STA']
        if model != 'tank':
            assert hard['STA'] > speed['STA'] and hard.get('ARMOR', 0) > speed.get('ARMOR', 0)
        assert p['why'] and '–' not in p['why'] and '...' not in p['why']


def test_physical_weights_follow_the_formula():
    conv = bb.Conv()
    p = dict(ap_str=2, ap_agi=0, r_spec=0, plan='2H', mana100=0)
    r = ref('WARRIOR', 60, AP=100, wDPS=50)
    w, shown = bb.phys_weights('WARRIOR', p, r, conv)
    ap = 100 + 2 * r['STR'] + 3 * 60 - 20
    B = 50 + ap / 14
    c = (r['AGI'] / conv.agi_per_crit('WARRIOR', 60)) / 100
    assert shown['AP'] == round(ap)
    assert w['CRIT'] == pytest.approx(14 * 0.01 * B / (1 + c))
    t = 1 - 0.08 - 0.056
    assert w['HIT'] == pytest.approx(14 * 0.01 * B / t)
    assert w['DPS'] == 14 and w['STR'] == 2
    assert w['AGI'] == pytest.approx(w['CRIT'] / conv.agi_per_crit('WARRIOR', 60))
    # weapon speed only with specials
    assert 'SPD_2H' not in w
    w2, _ = bb.phys_weights('WARRIOR', dict(p, r_spec=0.2), r, conv)
    assert w2['SPD_2H'] == pytest.approx(14 * 0.2 * B / (1 + 0.2 * 3.3), rel=1e-3) and w2['SPDREF_2H'] == 3.3
    # an off hand: half the damage, more misses
    assert w2['OHDPS'] == pytest.approx(0.5 * (1 - 0.27 - 0.056) / (1 - 0.08 - 0.056), rel=1e-3)


def test_tank_weights_are_the_derivative_of_effective_health():
    conv = bb.Conv()
    p = dict(parry=True, block=True, armor_mult=1.0, threat='WARRIOR')
    r = ref('WARRIOR', 60, ARMOR=5000)
    w, _ = bb.tank_weights('WARRIOR', p, r, conv)

    def eh(armor_items, sta):
        rr = dict(r, ARMOR=armor_items, STA=sta)
        hp = bb.base_hp('WARRIOR', 60) + 10 * rr['STA']
        K = 400 + 85 * 62
        armor = rr['ARMOR'] + 2 * rr['AGI']
        dodge = (rr['AGI'] / conv.agi_per_crit('WARRIOR', 60)) / 100
        av = min(0.6, 0.05 + dodge + 0.05 + 0.3 * 0.05)
        return hp * (armor + K) / K / (1 - av)
    d_sta = eh(5000, r['STA'] + 1) - eh(5000, r['STA'])
    d_arm = eh(5001, r['STA']) - eh(5000, r['STA'])
    assert w['STA'] == 1
    assert w['ARMOR'] == pytest.approx(d_arm / d_sta, rel=1e-3)
    assert w['DODGE'] > 0 and w['PARRY'] == w['DODGE'] and 0 < w['BLOCK'] < w['DODGE']
    # threat at 15 %: strength counts, but far below stamina
    assert 0 < w['STR'] < 0.5


def test_caster_mana_and_crit():
    conv = bb.Conv()
    frost = next(s for s in bb.SPECS if s[1] == 'frost')[5]
    lo, _ = bb.caster_weights('MAGE', frost, ref('MAGE', 60, SPD=50), conv)
    hi, _ = bb.caster_weights('MAGE', frost, ref('MAGE', 60, SPD=400), conv)
    assert hi['SCRIT'] > lo['SCRIT'], 'crit grows with spell damage'
    assert lo['SP_FROST'] == 1 and 'SP_FIRE' not in lo
    assert lo['SHIT'] > lo['SCRIT'] > 0 and lo['INT'] > 0 and lo['MP5'] > 0 and lo['SPI'] > 0 and lo['RDPS'] > 0
    holy = next(s for s in bb.SPECS if s[0] == 'PRIEST' and s[1] == 'holy')[5]
    h, _ = bb.caster_weights('PRIEST', holy, ref('PRIEST', 60, HEAL=300), conv, heal=True)
    assert h['HEAL'] == 1 and 'SHIT' not in h and 'SP' not in h


# ---------------------------------------------------------------- sets, suffixes, dungeons, drops
def test_set_bonus_text():
    assert bb.set_bonus_text([[6, 29, 12, 0]]) == 'STRENGTH=12'
    assert bb.set_bonus_text([[6, 29, 5, 2], [6, 99, 20, 0]]) == 'ATTACK_POWER=20;STAMINA=5'
    assert bb.set_bonus_text([[6, 13, 23, 126]]) == 'SPELL_DAMAGE_DONE=23'
    assert bb.set_bonus_text([[6, 42, 5, 0]]) is None, 'a proc is not a simple stat'
    assert bb.set_bonus_text([[3, 29, 5, 0]]) is None


def test_build_sets(wago):
    gd = bb.extract(wago)
    sets = bb.build_sets(gd, {1001, 1002, 1003})
    assert sets == {7: {'name': 'Garb of Tests', 'items': [1001, 1002], 'b': [[2, 'STRENGTH=12'], [2, '']]}}
    assert bb.build_sets(gd, {1001}) == {}, 'a set needs two planner items'


def test_observed_suffixes():
    sv = {'scan': {'suffix': {12345: {-71: 'AGILITY=7;STAMINA=6', 5: 'bad text', 0: 'STRENGTH=1'}, 'x': {}, 99: 'no'}}}
    assert bb.observed_suffixes(sv) == {12345: {-71: 'AGILITY=7;STAMINA=6'}}
    assert bb.observed_suffixes(None) == {}


FACTS = {'checked': '2026-10-05', 'dungeons': [
    {'key': 'thanes', 'name': 'Hall of Thanes', 'kind': 'party', 'min': 13, 'max': 18,
     'bosses': ['Faldrim Anvilmar', 'Plunder', 'Somebody New']},
    {'key': 'wc', 'name': 'Wailing Caverns', 'kind': 'party'},
    {'key': 'lbrs', 'name': 'Lower Blackrock Spire', 'kind': 'party', 'aliases': ['Blackrock Spire'], 'part': 'Blackrock Spire'},
    {'key': 'ubrs', 'name': 'Upper Blackrock Spire', 'kind': 'party', 'part': 'Blackrock Spire'},
]}


def fake_att():
    return {'instances': {1: {'name': 'Hall of Thanes'}, 2: {'name': 'Wailing Caverns'}, 3: {'name': 'Blackrock Spire'},
                          4: {'name': 'Somewhere Else'}},
            'npcs': {261306: {'name': 'Faldrim Anvilmar', 'kinds': {'boss'}, 'inst': 1},
                     261311: {'name': 'Plunder', 'kinds': {'boss'}, 'inst': 1},
                     5000: {'name': 'A Giver', 'kinds': {'giver'}, 'inst': 1},
                     3653: {'name': 'Kresh', 'kinds': {'boss'}, 'inst': 2},
                     9196: {'name': 'Highlord Omokk', 'kinds': {'boss'}, 'inst': 3},
                     10363: {'name': 'General Drakkisath', 'kinds': {'boss'}, 'inst': 3},
                     777: {'name': 'Mystery', 'kinds': {'boss'}, 'inst': 3},
                     8: {'name': 'Elsewhere', 'kinds': {'boss'}, 'inst': 4}}}


def test_bosses_get_their_npc_ids():
    gear = {'S': [['D', 'Lower Blackrock Spire', 'Highlord Omokk'], ['D', 'Upper Blackrock Spire', 'General Drakkisath']]}
    bosses = bb.boss_npcs(FACTS, fake_att(), gear)
    assert bosses['thanes'] == [(261306, 'Faldrim Anvilmar'), (261311, 'Plunder')], 'bosses only, no quest giver'
    assert bosses['wc'] == [(3653, 'Kresh')]
    # one instance, two dungeons: each boss where the item data names it, an unknown one nowhere
    assert bosses['lbrs'] == [(9196, 'Highlord Omokk')] and bosses['ubrs'] == [(10363, 'General Drakkisath')]
    assert 777 not in [n for v in bosses.values() for n, _ in v]
    dg = bb.build_dungeons(FACTS, bosses, {'lfg': {1: ['Wailing Caverns', 17, 24]}})
    thanes = next(d for d in dg if d['key'] == 'thanes')
    assert thanes['bosses'] == [261306, 261311, 'Somebody New'], 'ids first, a name without an id stays a name'
    assert thanes['bossNames'] == {261306: 'Faldrim Anvilmar', 261311: 'Plunder'}
    assert thanes['min'] == 13 and thanes['max'] == 18
    wc = next(d for d in dg if d['key'] == 'wc')
    assert (wc['min'], wc['max']) == (17, 24), 'levels from LFGDungeons'
    assert bb.boss_npcs(FACTS, None, gear) == {}


def test_base_stock():
    arch = {'k': {'aaaaaaaa': {'npc': 10, 'day': 270, 'it': {'5': 1}}, 'bbbbbbbb': {'npc': 10, 'day': 272, 'it': {}},
                  'cccccccc': {'npc': 0, 'day': 272, 'it': {'6': 1}}}}
    O, OT, OI = bb.base_stock(arch)
    assert O == {10: {'k': 2, 'it': {5: 1}}} and OT == 272 and OI == {'bbbbbbbb': True, 'cccccccc': True}
    assert bb.base_stock({'k': {}}) == ({}, -1, {})


# ---------------------------------------------------------------- a whole build
GEAR_LUA = '''local _, ns = ...
ns.GEAR = { game = "forever", cap = 60, built = "test",
    S = { {"Q", "A Quest", 0, 1, "", 1429, 1, 0}, {"D", "Wailing Caverns", "Kresh", "10%%"}, {"V", "Smith", 1429, "", nil, 9} },
    Z = {},
    I = {
%s
    },
    ST = {
%s
    },
}
'''


def gear_file(tmp_path, scanned_ok=True):
    rows, st = [], []
    # 50 scanned heads whose computed stats match (or 2 of them do not), plus unscanned ones
    for i in range(50):
        iid = 20000 + i
        rows.append(f'        [{iid}] = {{"HEAD", 4, 1, {10 + i % 40}, 2, 0, 30, 0, 0, 0, 1}},')
        val = '9' if scanned_ok or i > 1 else '8'
        st.append(f'        [{iid}] = "STRENGTH={val};STAMINA=6",')
    for iid, loc, sub, lvl in ((1001, 'HEAD', 1, 20), (1002, 'LEGS', 1, 30), (30001, 'WEAPON', 7, 20), (30002, '2HWEAPON', 1, 25)):
        rows.append(f'        [{iid}] = {{"{loc}", {2 if loc in ("WEAPON", "2HWEAPON") else 4}, {sub}, {lvl}, 2, 0, 30, 0, '
                    f'{2.6 if loc == "WEAPON" else 3.4 if loc == "2HWEAPON" else 0}, 0, 2, 3}},')
    st.append('        [30001] = "DAMAGE_PER_SECOND=12;STRENGTH=3",')
    st.append('        [30002] = "DAMAGE_PER_SECOND=18;STRENGTH=6;CRIT_RATING=10",')
    path = tmp_path / 'GearData.lua'
    path.write_text(GEAR_LUA % ('\n'.join(rows), '\n'.join(st)), encoding='utf-8')
    return str(path)


def sparse_for_gear(folder):
    rows = [sparse_row(20000 + i, 1, 2, 30, [(4, 6000), (7, 4000)]) for i in range(50)]
    rows += [sparse_row(1001, 1, 2, 30, [(4, 6000), (7, 4000)], item_set=7), sparse_row(1002, 7, 3, 40, [(5, 7000)], item_set=7)]
    write_csv(folder, 'ItemSparse', SPARSE_HEADER, rows)


def build(tmp_path, wago, gear, specs=(('WARRIOR', 'dps'), ('MAGE', 'frost'))):
    facts = tmp_path / 'facts.json'
    facts.write_text(json.dumps(FACTS), encoding='utf-8')
    out_w, out_b = tmp_path / 'GearWeights.lua', tmp_path / 'BisData.lua'
    report, result = bb.run(wago=wago, gamedata_path=str(tmp_path / 'gd.json'), measured_path=None, gear_path=gear,
                            facts_path=str(facts), archive_path=None, sv_path=None, att=fake_att(),
                            out_weights=str(out_w), out_bis=str(out_b), built='2026-10-06', specs=set(specs))
    return report, result, out_w, out_b


def lua_load(path):
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{}')
    lua.eval('function(s, ns) return assert(loadstring(s))("Amisia", ns) end')(path.read_text(encoding='utf-8'), ns)
    return ns


def test_a_whole_build(tmp_path, wago):
    sparse_for_gear(wago)
    report, result, out_w, out_b = build(tmp_path, wago, gear_file(tmp_path))
    assert report['sc'][1] == 1.0 and report['sc'][0] == 2, report
    assert report['fixpoint'] < 0.01
    # the subset build writes BisData, the weights file only for every spec
    assert not out_w.exists()
    text = out_b.read_text(encoding='utf-8')
    assert text.startswith('-- GENERATED by tools/build_bis.py')
    assert 'IsForever' not in text, 'the TOC limits the file to Forever'
    ns = lua_load(out_b)
    B = ns.BIS
    assert B.SC[1001] == 'STAMINA=6;STRENGTH=9' and B.SC[20000] is None, 'scanned items keep their scan'
    assert B.SET[7]['items'][1] == 1001 and B.SET[7].b[1][2] == 'STRENGTH=12' and B.SET[7].b[2][2] == ''
    assert B.EF.V == 1 and B.EF.D == 3 and B.OT == -1
    keys = [B.DG[i].key for i in range(1, len(B.DG) + 1)]
    assert keys == ['thanes', 'wc', 'lbrs', 'ubrs']
    assert B.DG[1].bosses[1] == 261306 and B.DG[1].bossNames[261306] == 'Faldrim Anvilmar'
    # the same twice
    build(tmp_path, wago, gear_file(tmp_path))
    assert out_b.read_text(encoding='utf-8') == text
    sr, hc, shown = result[('WARRIOR', 'dps')]
    assert len(sr) == len(bb.BRACKETS) == 12 and all(w['AP'] == 1 for w in sr)


def test_no_computed_stats_below_98_percent(tmp_path, wago):
    sparse_for_gear(wago)
    report, _, _, out_b = build(tmp_path, wago, gear_file(tmp_path, scanned_ok=False))
    assert report['sc'][0] == 0 and report['sc'][1] == pytest.approx(48 / 50), report
    assert 'SC = {\n    },' in out_b.read_text(encoding='utf-8')


def test_weights_file_has_our_own_header(tmp_path, wago):
    sparse_for_gear(wago)
    (tmp_path / 'facts.json').write_text(json.dumps(FACTS), encoding='utf-8')
    out_w = tmp_path / 'GearWeights.lua'
    bb.run(wago=wago, gamedata_path=str(tmp_path / 'gd.json'), measured_path=None, gear_path=gear_file(tmp_path),
           facts_path=str(tmp_path / 'facts.json'), archive_path=None, sv_path=None, att=None,
           out_weights=str(out_w), out_bis=str(tmp_path / 'B.lua'), built='2026-10-06')
    text = out_w.read_text(encoding='utf-8')
    assert "Amisia's own weights" in text and 'RestedXP' not in text and 'CC BY' not in text
    ns = lua_load(out_w)
    G = ns.GEAR_WEIGHTS
    assert [G.brackets[i] for i in range(1, 13)] == bb.BRACKETS
    assert G.ratings.CRIT == 14
    n = 0
    for cls in bb.CLASS_ORDER:
        specs = G.specs[cls]
        for i in range(1, len(specs) + 1):
            sp = specs[i]
            n += 1
            assert sp.unit in ('AP', 'SP', 'HEAL', 'STA') and sp.why
            assert len(sp.Speedrun) == 12 and len(sp.Hardcore) == 12 and len(sp.ref) == 12
            assert sp.Speedrun[12][sp.unit] == 1
    assert n == len(bb.SPECS) == 22


def test_the_committed_data_is_current():
    """GearWeights.lua and BisData.lua come from build_bis.py (header) and hold every spec."""
    with open(os.path.join(ROOT, 'addon', 'Amisia', 'GearWeights.lua'), encoding='utf-8') as fh:
        w = fh.read()
    assert w.startswith('-- GENERATED by tools/build_bis.py') and "Amisia's own weights" in w
    with open(os.path.join(ROOT, 'addon', 'Amisia', 'BisData.lua'), encoding='utf-8') as fh:
        b = fh.read()
    assert b.startswith('-- GENERATED by tools/build_bis.py') and 'DG = {' in b
    with open(os.path.join(ROOT, 'addon', 'Amisia', 'Amisia.toc'), encoding='utf-8') as fh:
        toc = [ln.strip() for ln in fh if ln.strip() and not ln.startswith('#')]
    assert 'BisData.lua [AllowLoadGameType camelot]' in toc
    assert toc.index('GearWeights.lua [AllowLoadGameType camelot]') < toc.index('BisData.lua [AllowLoadGameType camelot]') \
        < toc.index('Gear.lua')


def test_attack_power_per_stat_matches_the_game():
    """The planner's attack power per strength and agility against the measured lines: shaman and
    paladin 2 per strength, 0 per agility; hunter ranged 2 per agility - 10 without a level part."""
    samples = json.load(open(bb.MEASURED, encoding='utf-8'))['samples']
    melee = {cls: p for cls, key, _, _, model, p in bb.SPECS if model == 'phys' and not p.get('ranged')}
    for s in samples:
        cls = s['class']
        if cls in melee and s.get('apstr') is not None:
            assert s['apstr'] == melee[cls]['ap_str'] * s['str'], (cls, s['apstr'])
        if cls in melee and s.get('apagi') is not None:
            assert s['apagi'] == melee[cls]['ap_agi'] * s['agi'], (cls, s['apagi'])
    hunter = next(s for s in samples if s['class'] == 'HUNTER')
    assert hunter['apagi'] == hunter['agi'] and hunter['apstr'] == hunter['str'], 'hunter melee: 1 per strength and agility'
    p = next(sp[5] for sp in bb.SPECS if sp[0] == 'HUNTER')
    r = ref('HUNTER', 5, AGI=hunter['agi'])
    _, shown = bb.phys_weights('HUNTER', p, r, bb.Conv())
    assert shown['AP'] == 2 * hunter['agi'] - 10 == 40, 'ranged attack power as the game shows it'


def test_spell_power_counts_for_casters_and_healers():
    """Forever items carry ITEM_MOD_SPELL_POWER_SHORT (seen in game 2026-10-06 on a random-suffix
    cloak): ItemSparse's stat 45 computes to it, Gear.lua maps it to SPP, and SPP counts with the
    spell damage plus the healing weight - one for every caster and healer."""
    assert bb.STAT_KEY[45] == 'SPELL_POWER'
    stat_map = bb.gear_stat_map()
    assert stat_map['SPELL_POWER'] == 'SPP'
    assert bb.parse_stats('SPELL_POWER=12;INTELLECT=4', stat_map) == {'SPP': 12, 'INT': 4}
    conv = bb.Conv()
    for cls, key, _, role, model, p in bb.SPECS:
        if model in ('caster', 'heal'):
            w, hard, _ = bb.derive(cls, model, p, ref(cls, 30), conv)
            assert bb.score({'SPP': 10}, w, 30, None, cls, conv) >= 10, (cls, key)


def test_measured_pairs_confirm_the_model():
    """Warrior 15 with a strength/stamina item off: 2 attack power per strength, 10 health per
    stamina (the tank model's unit), crit unchanged. Priest 23 with an intellect/spirit cloak off:
    19.8 intellect per 1 % spell crit and 0.625 mana per spirit and five seconds (Classic's value)."""
    samples = json.load(open(bb.MEASURED, encoding='utf-8'))['samples']
    war = sorted((s for s in samples if s['class'] == 'WARRIOR'), key=lambda s: s['str'])
    assert len(war) == 2
    lo, hi = war
    assert hi['ap'] - lo['ap'] == 2 * (hi['str'] - lo['str'])
    assert hi['hp'] - lo['hp'] == 10 * (hi['sta'] - lo['sta'])
    assert hi['crit'] == lo['crit']
    m = bb.load_measured(bb.MEASURED)
    c = bb.Conv(m)
    assert c.int_per_crit('PRIEST', 23) == pytest.approx(19.8, rel=0.01)
    assert c.base_spell_crit('PRIEST') == pytest.approx(0.8, abs=0.01)
    assert m['manaPerSpirit5']['PRIEST'] == pytest.approx(0.625)


def test_werte_lines_must_be_finite(tmp_path, capsys):
    """Review 25: float() takes nan, inf and 1e400; such a value never becomes a sample value, a
    line without a class or with a level outside 1-60 is refused before anything is saved, and an
    invalid line already in the file is skipped with a warning (the build goes on)."""
    for line in ('AMISIA-WERTE level=nan class=ROGUE', 'AMISIA-WERTE level=inf class=ROGUE',
                 'AMISIA-WERTE level=1e400 class=ROGUE', 'AMISIA-WERTE 1 ROGUE 61', 'AMISIA-WERTE 1 ROGUE 0',
                 'AMISIA-WERTE level=12.5 class=ROGUE', 'AMISIA-WERTE 1 KNIGHT 20', 'AMISIA-WERTE 1 60'):
        assert bb.werte_problem(bb.parse_werte(line)), line
    s = bb.parse_werte('AMISIA-WERTE 1 ROGUE 60 agi=nan,nan,0,0 crit=inf cm=1e400,2 hm=20,nan dodge=-inf')
    assert bb.werte_problem(s) is None and s['level'] == 60
    assert 'agi' not in s and 'crit' not in s and 'dodge' not in s and s['ratings'] == {}, s
    # main: refused before the file is written
    path = tmp_path / 'measured.json'
    path.write_text(json.dumps({'samples': []}), encoding='utf-8')
    rc = bb.main(['--measured', str(path), '--werte', 'AMISIA-WERTE 1 ROGUE 60 cm=28,2',
                  '--werte', 'AMISIA-WERTE level=nan', '--no-att', '--wago', str(tmp_path)])
    assert rc == 2 and json.loads(path.read_text(encoding='utf-8')) == {'samples': []}, 'nothing saved'
    # saved before this check: skipped with a warning
    good = bb.parse_werte('AMISIA-WERTE 1 ROGUE 60 cm=28,2')
    path.write_text(json.dumps({'samples': [{'line': 'AMISIA-WERTE level=nan class=ROGUE'},
                                            {'class': 'ROGUE', 'level': float('inf'), 'ratings': {}},
                                            dict(good, line='AMISIA-WERTE 1 ROGUE 60 cm=28,2')]}), encoding='utf-8')
    capsys.readouterr()
    m = bb.load_measured(str(path))
    assert m['rating60'] == {'CRIT': 14} and m['sources'] == ['ROGUE 60']
    assert capsys.readouterr().err.count('skipped') == 2


def test_set_bonus_percent_auras_become_level_60_ratings():
    # +2 % hit (Devilsaur), +1 % spell hit, +1 % crit, +1 % spell crit, +10 defence
    assert bb.set_bonus_text([[6, 54, 2, 0]]) == 'HIT_MELEE_RATING=20'
    assert bb.set_bonus_text([[6, 55, 1, 0]]) == 'HIT_SPELL_RATING=8'
    assert bb.set_bonus_text([[6, 52, 1, 0]]) == 'CRIT_MELEE_RATING=14'
    assert bb.set_bonus_text([[6, 57, 1, 0]]) == 'CRIT_SPELL_RATING=14'
    assert bb.set_bonus_text([[6, 30, 10, 95]]) == 'DEFENSE_SKILL_RATING=15'
    # a proc or a spell modifier stays unscored
    assert bb.set_bonus_text([[6, 42, 0, 0]]) is None and bb.set_bonus_text([[6, 107, 5, 11]]) is None
