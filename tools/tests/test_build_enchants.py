"""tools/build_enchants.py: the permanent enchantments of the enchant suggestions (F-128) from the
client tables (hand-made fixture CSVs in tests/fixtures/wago_enchants, not real data), and the
generated Amisia/Data/EnchantData.lua (valid Lua, lazy, Forever only, before Gear/Enchants.lua)."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'Amisia')
sys.path.insert(0, TOOLS)
import build_enchants  # noqa: E402
import lua_data  # noqa: E402

FIX = os.path.join(HERE, 'fixtures', 'wago_enchants')
OUT = os.path.join(ADDON, 'Data', 'EnchantData.lua')


@pytest.fixture(scope='module')
def data():
    return build_enchants.build([FIX])


def test_recipes_and_items_with_what_fits(data):
    src = [(s['kind'], s['id'], s['enchant']) for s in data['sources']]
    assert src == [('i', 2304, 15), ('r', 100, 24), ('i', 4406, 32), ('r', 204, 77)]
    by = {s['id']: s for s in data['sources']}
    assert by[100]['fits'] == (4, ['CHEST', 'ROBE'], []) and by[100]['skill'] == 333 and by[100]['level'] == 1
    assert by[2304]['fits'] == (4, ['CHEST', 'ROBE'], [1, 2, 3, 4]) and by[2304]['level'] == 1
    assert by[4406]['fits'] == (2, [], [2, 3, 18]) and by[4406]['level'] == 10


def test_left_out(data):
    ids = {s['id'] for s in data['sources']}
    # 201 is temporary (effect 54), 202 has no SpellEquippedItems row, 9001/9004 are recipe items,
    # 9002 a QA item, 9003 has no name in ItemSparse
    assert not ids & {201, 202, 9001, 9002, 9003, 9004}
    assert set(data['enchants']) == {15, 24, 32, 77}


def test_stats_from_stat_equip_spell_damage_and_procs(data):
    e = data['enchants']
    assert e[24]['stats'] == {'INTELLECT': 2} and not e[24]['fx']
    assert e[15]['stats'] == {'STAMINA': 1, 'RESISTANCE0_NAME': 8} and not e[15]['fx'], 'the $k values of the equip spell'
    assert e[32]['stats'] == {'WDMG': 2}
    assert e[77]['stats'] == {} and e[77]['fx'] and e[77]['ilvl'] == 35


def test_render_is_lazy_lua(data):
    lupa = pytest.importorskip('lupa.lua51')
    lua = build_enchants.render_lua(data, built='2026-10-31')
    assert 'ns.LazyData("ENCHANT", [=[\nreturn {\n' in lua and lua.rstrip().endswith(']=], 4)')
    t = lua_data.load(lua, 'EnchantData.lua', lupa.LuaRuntime(unpack_returned_tuples=True)).ENCHANT
    assert t.E[15] == 'RESISTANCE0_NAME=8;STAMINA=1|0|0|Stamina +$k2 and Armor +$k1'
    assert t.E[77] == '|1|35|Crusader'
    assert t.S[1] == 'i:2304:15:0:1:4:CHEST,ROBE:1,2,3,4' and t.S[2] == 'r:100:24:333:1:4:CHEST,ROBE:'


def test_shipped_data_file_in_toc_and_valid():
    with open(os.path.join(ADDON, 'Amisia.toc'), encoding='utf-8') as fh:
        toc = fh.read()
    assert 'Data\\EnchantData.lua [AllowLoadGameType camelot]' in toc
    assert 'Gear\\Enchants.lua [AllowLoadGameType camelot]' in toc
    assert toc.index('Data\\EnchantData.lua') < toc.index('Gear\\Enchants.lua')
    for name in ('Amisia_TBC.toc', 'Amisia_Vanilla.toc'):
        with open(os.path.join(ADDON, name), encoding='utf-8') as fh:
            assert 'Enchant' not in fh.read(), f'{name}: Forever only'
    with open(OUT, encoding='utf-8') as fh:
        src = fh.read()
    lupa = pytest.importorskip('lupa.lua51')
    t = lua_data.load(src, 'EnchantData.lua', lupa.LuaRuntime(unpack_returned_tuples=True)).ENCHANT
    n = int(src.rsplit(', ', 1)[1].rstrip(')\n'))
    assert n == len(list(t.S.keys())), 'the count is the number of sources'


@pytest.mark.skipif(not os.path.isdir(build_enchants.WAGO), reason='needs the client tables')
def test_shipped_file_is_current():
    import client_tables  # the newest copy of each table, as build.py data reads them (D-101)
    dirs = [client_tables.default_dir()]
    if any(build_enchants.find_table(dirs, t) is None for t in build_enchants.REQUIRED):
        pytest.skip('no client tables')
    with open(OUT, encoding='utf-8') as fh:
        shipped = fh.read()
    built = re.search(r'built\s*=\s*"([^"]*)"', shipped).group(1)
    assert build_enchants.render_lua(build_enchants.build(dirs), built=built) == shipped, \
        'rebuild: python3 tools/build_enchants.py'
