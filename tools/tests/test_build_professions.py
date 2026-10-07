"""tools/build_professions.py: the recipes of every profession for the addon's professions page.
Client tables as hand-made CSVs (tools/tests/fixtures/wago_prof, no real data), AllTheThings'
builder language as a hand-made fixture (tools/tests/fixtures/att_prof): recipes and their
difficulty, recipe items and their sources, the Season of Discovery filter, trainers, Merchant's
Favor, camp objects, writs, reagents with and without SpellReagents, and the generated Lua file
(valid, deterministic, compact, in the TOC)."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'addon', 'Amisia')
WAGO = os.path.join(HERE, 'fixtures', 'wago_prof')
REAGENTS = os.path.join(WAGO, 'reagents')
ATT = os.path.join(HERE, 'fixtures', 'att_prof')
sys.path.insert(0, TOOLS)
import build_professions as bp  # noqa: E402


@pytest.fixture(scope='module')
def data():
    return bp.combine(bp.read_client(REAGENTS, WAGO), bp.read_att(ATT))


@pytest.fixture(scope='module')
def plain():
    return bp.combine(bp.read_client(WAGO), bp.read_att(ATT))


def lua_load(text):
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{}')
    lua.eval('function(s) return assert(loadstring(s, "@ProfessionData.lua")) end')(text)('Amisia', ns)
    return ns.PROFESSIONS


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
    assert bs[10011] == '10011:7723:1:1:240:260:T0', 'a trainer list without a tier'
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
    assert att['trainer'][1252229] == 1 and att['trainer'][3491] == 3 and att['trainer'][10011] == 0
    assert 2018 not in att['trainer'] and 3538 not in att['trainer'], 'rank spells are no recipes'


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
    assert data['G'] == {2663: '2840:2', 3321: '2840:4,2880:1'}
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
    assert P.G[3321] == '2840:4,2880:1'


def test_empty_file_is_valid():
    P = lua_load(bp.render(bp.empty(), '2026-10-06'))
    assert P.P[1] is None and P.built == '2026-10-06'


def test_shipped_file_is_in_the_toc_and_compact():
    with open(os.path.join(ADDON, 'Amisia.toc'), encoding='utf-8') as fh:
        toc = fh.read()
    assert re.search(r'^Data\\ProfessionData\.lua \[AllowLoadGameType camelot\]$', toc, re.M)
    assert toc.index('Data\\ProfessionData.lua') < toc.index('Gear\\Professions.lua\n') < toc.index('UI\\Pages\\Professions.lua')
    path = os.path.join(ADDON, 'Data', 'ProfessionData.lua')
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    assert text.startswith('-- GENERATED by tools/build_professions.py')
    assert os.path.getsize(path) < 300 * 1024, 'compact: numbers only, names come from the client'
    P = lua_load(text)
    assert P.P[1] is not None
