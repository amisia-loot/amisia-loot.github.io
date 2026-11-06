"""tools/build_professions.py: the recipes of every profession for the addon's professions page.
Client tables as hand-made CSVs (tools/tests/fixtures/wago_prof, no real data), AllTheThings'
builder language as a hand-made fixture (tools/tests/fixtures/att_prof): recipes and their
difficulty, recipe items and their sources, the Season of Discovery filter, trainers, Merchant's
Favor, camp objects, writs, reagents with and without SpellReagents, the vendor price list V (with
hand-made collector notes, tools/tests/fixtures/scan_archive_prof.json), and the generated Lua file
(valid, deterministic, compact, in the TOC)."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'Amisia')
WAGO = os.path.join(HERE, 'fixtures', 'wago_prof')
REAGENTS = os.path.join(WAGO, 'reagents')
ATT = os.path.join(HERE, 'fixtures', 'att_prof')
SCAN = os.path.join(HERE, 'fixtures', 'scan_archive_prof.json')
sys.path.insert(0, TOOLS)
import build_professions as bp  # noqa: E402
import lua_data  # noqa: E402


@pytest.fixture(scope='module')
def data():
    return bp.combine(bp.read_client(REAGENTS, WAGO), bp.read_att(ATT), bp.read_seen_vendors(SCAN))


@pytest.fixture(scope='module')
def plain():
    return bp.combine(bp.read_client(WAGO), bp.read_att(ATT))


def lua_load(text):
    # the table comes as text for ns.LazyData (Core/LazyData.lua)
    assert 'ns.LazyData("PROFESSIONS", [' in text
    return lua_data.load(text, 'ProfessionData.lua').PROFESSIONS


def lines(data, skill):
    return {int(r.split(':')[0]): r for r in data['R'][skill]}


def test_professions_in_display_order(data):
    assert [p[0] for p in data['P']] == [171, 164, 333, 185], 'only professions with recipes, crafting first'
    assert data['P'][1] == (164, 'blacksmithing')
    assert data['client'] == '1.60.1.1'


def test_recipe_lines(data):
    bs = lines(data, 164)
    assert bs[2663] == '2663:2853:1:1:20:60:A', 'learned with the profession; the duplicate row counts once'
    assert bs[3321] == '3321:3471:1:10:35:75:I3609', 'taught by a recipe item: learn rank from the item'
    assert bs[1252229] == '1252229:251001:1:1:50:80:T1', 'an apprentice trainer recipe'
    assert bs[3491] == '3491:3848:1:105:130:170:T3', 'expert trainer, learn rank from MinSkillLineRank'
    assert bs[10011] == '10011:7723:1:1:240:260:S', "a specialisation's recipe: S, no plain trainer recipe"
    assert bs[1301421] == '1301421:276992:1:60:60:100:I276928'
    assert lines(data, 333)[7418] == '7418:0:0:1:40:70:', 'an enchant makes no item; no source known'
    assert lines(data, 171)[2330] == '2330:118:3:1:25:55:A', 'three potions per craft'
    assert 2018 not in bs, 'the profession rank spell is no recipe'
    assert all(not str(k).startswith('762') for k in data['R']), 'riding is no profession'


def test_season_of_discovery_filter(data):
    bs = lines(data, 164)
    assert 439120 in bs, 'an SoD-range spell AllTheThings lists for Forever stays'
    assert 439122 not in bs, 'an SoD-range spell nobody lists for Forever goes'
    assert data['report']['sod dropped'] == 1
    assert 888002 not in data['I'], 'its recipe item goes with it'


def test_recipe_items_and_sources(data):
    I = data['I']
    assert I[3609] == '3321:10:0:0:V80100', 'sold by a vendor'
    assert I[276928] == '1301421:60:2758:5:D80300', 'reputation requirement and the NPC that drops it'
    assert I[251358] == '1252255:1:0:0:F30@5A,F35@6H', "Merchant's Favor per faction with price and standing"
    assert I[250388] == '1234001:50:0:0:F45@4A,D80400', 'favor and a zone drop of a named mob'
    assert I[273086] == '1263041:140:0:0:Q70900', 'a quest reward'
    assert 250999 not in I, 'a branch the Forever build does not see stays out'
    assert 2901 not in I, 'a vendor item that teaches nothing is no recipe item'


def test_names_of_sources(data):
    assert data['N'][80100] == 'Suppla Smith|1455:1250:3300|'
    assert data['N'][80300] == 'Skyforged Golem|1455:7000:7000|'
    assert data['N'][80400] == 'Vale Ooze|1455|', 'a mob named only by id: the zone of its drop'
    assert data['N'][80200].startswith("Gor'mak|1455:4980:2960|")
    assert data['Q'] == {70900: 'The Anvil Plan'}


def test_trainer_lists_skip_removed_and_rank_spells(data):
    att = bp.read_att(ATT)
    assert 5555 not in att['trainer'], 'removed before Forever'
    assert att['trainer'][1252229] == 1 and att['trainer'][3491] == 3
    assert 10011 not in att['trainer'] and 10011 in att['spec'], 'Weaponsmithing: a specialisation, not the trainer'
    assert 2018 not in att['trainer'] and 3538 not in att['trainer'], 'rank spells are no recipes'


def test_sell_prices_for_the_route_estimate(data, plain):
    assert data['S'] == {2840: 15}, ('Copper Bar: no vendor sells it, so what a vendor pays for one; '
                                     'Weak Flux and Empty Vial have a vendor price (V) instead')
    assert plain['S'] == {}, 'without reagents no estimate'


def test_cooldown_recipes(data, plain):
    assert data['CD'] == [3321], 'SpellCooldowns: a day on Copper Chain Vest; 1.5 s on Copper Bracers is no cooldown'
    assert data['report']['cooldowns'] == {'from': 'table', 'recipes': 1}
    assert plain['CD'] == [], 'without the table and without a hand-kept list: none'
    fallback = bp.combine(bp.read_client(WAGO), bp.read_att(ATT), cooldowns={2663, 999999})
    assert fallback['CD'] == [2663], 'the hand-kept list serves without the table, only for listed recipes'
    assert fallback['report']['cooldowns']['from'] == 'file'
    table = bp.combine(bp.read_client(REAGENTS, WAGO), bp.read_att(ATT), cooldowns={2663})
    assert table['CD'] == [3321], 'with the table the hand-kept list is not used'


def test_the_shipped_cooldown_list():
    spells = bp.read_cooldown_file()
    assert {11479, 17187, 17562, 18560} <= spells, 'Iron to Gold, Arcanite, Water to Air, Mooncloth'
    assert bp.read_cooldown_file(os.path.join(HERE, 'no such file.json')) == set()


def test_favor(data):
    F = data['FAVOR']
    assert F['currency'] == 3402
    assert F['vendor'] == {'A': [80201], 'H': [80200]}
    assert F['cert'] == {164: 271622}
    assert F['writ'] == {3471: 264020}, "Craftsman's Writ: Copper Chain Vest -> the item the recipe makes"


def test_camp(data):
    assert data['CAMP'] == [
        '279981:185:1:1307227:1229737:3:0',
        '279944:164:20:1307392:1230171:0:0',
        '279988:164:140:1307175:1263041:0:279944',
    ], 'campfire with its places first, then by profession and rank; the anvil replaces the wheel'


def test_reagents_only_with_the_table(data, plain):
    assert data['G'] == {2663: '2840:2', 3321: '2840:4,2880:1,3371:1'}
    assert plain['G'] == {}, 'without SpellReagents the addon asks the client'
    assert plain['report']['reagents'] == 'client'


def test_render_is_valid_deterministic_lua(data):
    text = bp.render(data, '2026-10-06')
    assert text == bp.render(data, '2026-10-06')
    assert text.startswith('-- GENERATED by tools/build_professions.py')
    P = lua_load(text)
    assert P.built == '2026-10-06' and P.client == '1.60.1.1'
    assert P.R[164][1] is not None and P.I[3609] == '3321:10:0:0:V80100'
    assert P.P[2][1] == 164 and P.P[2][2] == 'blacksmithing'
    assert P.FAVOR.vendor.A[1] == 80201 and P.FAVOR.writ[3471] == 264020
    assert P.CAMP[3] == '279988:164:140:1307175:1263041:0:279944'
    assert P.G[3321] == '2840:4,2880:1,3371:1'
    assert P.V[2880] == '100:80100' and P.V[3371] == '4:80600'
    assert P.S[2840] == 15 and P.S[2880] is None, 'S: the sell price of a reagent without a vendor price'
    assert P.CD[3321] == 1 and P.CD[2663] is None, 'CD: the cooldown recipes as a set'


def test_vendor_prices(data, plain):
    V = data['V']
    assert V[2880] == '100:80100', ('a reagent AllTheThings lists at a vendor; the barterer wants copper bars and '
                                    'the stranger no record names: both left out')
    assert V[3371] == '4:80600', 'only the collector saw it: 20 copper for a stack of 5 is 4 each'
    assert V[3609] == '500:80100', 'a recipe item a vendor sells'
    assert 2840 not in V, 'a reagent no vendor sells (a drop note is no vendor)'
    assert 251358 not in V, "a Merchant's Favor recipe costs the currency, not gold"
    assert data['N'][80600] == 'Tamar|1455:6000:4000|H', 'the vendor goes into N with place and faction'
    assert 80700 not in data['N'] and 80999 not in data['N']
    assert data['report']['prices'] == {'items': 3, 'recipe items': 1, 'reagents': 2}
    assert plain['V'] == {3609: '500:80100'}, 'without reagents and collector notes only the recipe items'


def test_unit_price():
    assert bp.unit_price(10, 1) == 10, 'Coarse Thread: 10 copper each'
    assert bp.unit_price(20, 5) == 4 and bp.unit_price(25, 5) == 5
    assert bp.unit_price(10, 3) == 4, 'rounded up'
    assert bp.unit_price(1, 5) == 1, 'at least one copper'
    assert bp.unit_price(0, 1) == 0, 'no client price: not in the list'


def test_pick_vendors_keeps_both_factions_and_places_first():
    npcs = {1: ('A1', '1453:1:1', 'A'), 2: ('A2', '1453:2:2', 'A'), 3: ('A3', '1453:3:3', 'A'),
            4: ('A4', '1453:4:4', 'A'), 5: ('A5', '1453:5:5', 'A'), 6: ('A6', '1453:6:6', 'A'),
            7: ('A7', '1453:7:7', 'A'), 8: ('H1', '1411', 'H'), 9: ('H2', '1454:9:9', 'H'), 10: ('N1', '', '')}
    got = bp.pick_vendors(list(range(1, 12)), npcs)
    assert got == [1, 2, 3, 4, 5, 9], 'at most six with a known place, the Horde one kept; no record, no vendor'
    assert bp.pick_vendors([8, 10, 1], npcs) == [1, 8, 10], 'known place first, then without one by id'
    assert bp.pick_vendors([], npcs) == []


def test_empty_file_is_valid():
    P = lua_load(bp.render(bp.empty(), '2026-10-06'))
    assert P.P[1] is None and P.built == '2026-10-06'


def test_shipped_file_is_in_the_toc_and_compact():
    with open(os.path.join(ADDON, 'Amisia.toc'), encoding='utf-8') as fh:
        toc = fh.read()
    assert re.search(r'^Data\\ProfessionData\.lua \[AllowLoadGameType camelot\]$', toc, re.M)
    assert toc.index('Data\\ProfessionData.lua') < toc.index('Gear\\Professions.lua [AllowLoadGameType camelot]\n') < toc.index('UI\\Pages\\Professions.lua')
    path = os.path.join(ADDON, 'Data', 'ProfessionData.lua')
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    assert text.startswith('-- GENERATED by tools/build_professions.py')
    assert os.path.getsize(path) < 300 * 1024, 'compact: numbers only, names come from the client'
    P = lua_load(text)
    assert P.P[1] is not None


def test_shipped_vendor_prices():
    path = os.path.join(ADDON, 'Data', 'ProfessionData.lua')
    with open(path, encoding='utf-8') as fh:
        P = lua_load(fh.read())
    V, N, I = P.V, P.N, P.I
    reagents = {int(x.split(':')[0]) for _, g in P.G.items() for x in g.split(',')}
    seen = 0
    for item, line in V.items():
        m = re.fullmatch(r'(\d+):((?:\d+(?:,\d+){0,5})?)', line)
        assert m and int(m.group(1)) >= 1, f'V[{item}] = {line}'
        assert item in reagents or I[item] is not None, f'{item}: neither a reagent nor a recipe item'
        for npc in filter(None, m.group(2).split(',')):
            assert N[int(npc)] is not None, f'vendor {npc} of {item} has no N entry'
        seen += 1
    assert seen > 100
    price, npcs = V[2320].split(':')
    assert price == '10' and npcs, 'Coarse Thread: 10 copper at a vendor with a record'
    assert V[2840] is None, 'Copper Bar: no vendor sells it, so no price'
    recipe = [i for i, l in V.items() if I[i] is not None and l.split(':')[1]]
    assert recipe, 'recipe items a vendor sells are in V'


def test_shipped_estimates_and_cooldowns():
    path = os.path.join(ADDON, 'Data', 'ProfessionData.lua')
    with open(path, encoding='utf-8') as fh:
        P = lua_load(fh.read())
    reagents = {int(x.split(':')[0]) for _, g in P.G.items() for x in g.split(',')}
    n = 0
    for item, sell in P.S.items():
        assert item in reagents and P.V[item] is None and sell >= 1, f'S[{item}] = {sell}'
        n += 1
    assert n > 200, 'most reagents without a vendor price have a sell price'
    assert P.S[14047] and P.S[2840], 'Runecloth and Copper Bar: estimated'
    assert P.CD[11479] == 1 and P.CD[18560] == 1, 'Transmute: Iron to Gold and Mooncloth have a cooldown'
    assert P.CD[2963] is None, 'Bolt of Linen Cloth has none'
