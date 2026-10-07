"""tools/build_talents.py: the talent trees of WoW Forever from the client's Trait* tables (fixture
CSVs in tests/fixtures/talents: a mage with three trees, two gated rows, a prerequisite, a parked
node and rank curves; a warrior with one node per tree; a legacy perk tree that is no class tree),
the description placeholders, and the generated addon/Amisia/Data/TalentData.lua (valid Lua, in the
TOC, the shape the addon reads)."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'addon', 'Amisia')
sys.path.insert(0, TOOLS)
import build_talents  # noqa: E402
import lua_data  # noqa: E402

FIX = os.path.join(HERE, 'fixtures', 'talents')
OUT = os.path.join(ADDON, 'Data', 'TalentData.lua')

# node ids of the fixture (tests/fixtures/talents, made in this order)
A1, A2, A3, A4, F1, R1, PARKED = range(105801, 105808)
W1, W2, W3 = range(105808, 105811)


@pytest.fixture(scope='module')
def data():
    return build_talents.build([FIX])


def nodes_by_id(cls):
    return {n['node']: n for n in cls['nodes']}


def test_only_class_trees_with_their_class(data):
    assert sorted(data['classes']) == ['MAGE', 'WARRIOR']
    mage = data['classes']['MAGE']
    assert mage['id'] == 8 and mage['tree'] == 1112 and mage['spec'] == 1482
    assert data['classes']['WARRIOR']['tree'] == 1117 and data['classes']['WARRIOR']['spec'] == 1491
    assert [t['name'] for t in mage['trees']] == ['Arcane', 'Fire', 'Frost']
    assert [t['icon'] for t in mage['trees']] == [135932, 135810, 135846]


def test_points_levels_and_talented(data):
    assert data['max'] == 51
    assert data['levels'] == list(range(10, 61))
    # Talented rank k gives the points from level 10 - k on, never more than 51
    assert data['talented'] == [9, 8, 7, 6, 5]


def test_grid_positions_and_parked_nodes(data):
    n = nodes_by_id(data['classes']['MAGE'])
    assert PARKED not in n, 'a node far off the grid is an old, replaced one'
    assert (n[A1]['tree'], n[A1]['row'], n[A1]['col']) == (1, 0, 0)
    assert (n[A2]['tree'], n[A2]['row'], n[A2]['col']) == (1, 0, 1)
    assert (n[A3]['row'], n[A3]['col']) == (1, 2)
    assert (n[A4]['row'], n[A4]['col']) == (2, 2)
    assert (n[F1]['tree'], n[F1]['row'], n[F1]['col']) == (2, 0, 0)
    assert (n[R1]['tree'], n[R1]['row'], n[R1]['col']) == (3, 0, 0), 'PosY 2120 is still row 0'
    # data order: tree, row, column
    order = [(x['tree'], x['row'], x['col']) for x in data['classes']['MAGE']['nodes']]
    assert order == sorted(order)


def test_ranks_names_icons_entries(data):
    n = nodes_by_id(data['classes']['MAGE'])
    assert n[A2]['max'] == 5 and n[A4]['max'] == 1
    assert n[A1]['name'] == 'Arcane Subtlety' and n[A1]['spell'] == 11210 and n[A1]['icon'] == 135894
    assert n[A1]['entry'] == 130501


def test_gates_from_group_conditions(data):
    mage = data['classes']['MAGE']
    n = nodes_by_id(mage)
    assert n[A1]['gates'] == [] and n[F1]['gates'] == []
    (g1, req1), = n[A3]['gates']
    assert req1 == 5 and sorted(mage['gates'][g1]) == [A1, A2]
    (g2, req2), = n[A4]['gates']
    assert req2 == 10 and sorted(mage['gates'][g2]) == [A1, A2, A3]


def test_prerequisites_from_edges(data):
    n = nodes_by_id(data['classes']['MAGE'])
    assert n[A4]['pre'] == [A3], 'edge type 2: the source must be full'
    assert n[A3]['pre'] == [], 'a visual-only edge (type 0) is no prerequisite'


def test_description_rank_values_from_curves(data):
    n = nodes_by_id(data['classes']['MAGE'])
    assert n[A2]['desc'] == 'Reduces the chance that the opponent can resist your Arcane spells by {1}%.'
    assert n[A2]['values'] == [['2', '4', '6', '8', '10']]
    # $/1000;S1: divided, shown without the sign
    assert n[F1]['desc'] == 'Reduces the casting time of your Fireball spell by {1} sec.'
    assert n[F1]['values'] == [['0.1', '0.2', '0.3', '0.4', '0.5']]


def test_description_other_spells_duration_period_radius(data):
    n = nodes_by_id(data['classes']['MAGE'])
    assert n[A3]['desc'] == ('Gives you a {1}% chance of entering a Clearcasting state for 10 sec. '
                             'Restores 170 mana every 3 sec to all within 30 yards.')
    assert n[A3]['values'] == [['2', '4', '6', '8', '10']]


def test_description_expressions_stacks_plurals_conditions(data):
    n = nodes_by_id(data['classes']['MAGE'])
    assert n[A4]['desc'] == ('When activated, your next spell with a casting time of less than 10 sec becomes an '
                             'instant cast spell. Lasts 179 sec. Stores up to 3 charges.')
    assert n[A4]['values'] == []
    # $h proc chance, $d of the spell, $?cond[a][b] takes the else part
    assert n[R1]['desc'] == 'Gives your Chill effects a 15% chance to freeze the target for 10 sec. Not known.'


def test_resolve_unknown_tokens_marked():
    text, values, unknown = build_talents.resolve_text('A $<maxDam> B $proccooldown C', None, {}, 1)
    assert text == 'A ? B ? C' and values == [] and unknown == 2


def test_lua_output_shape(data):
    lua = build_talents.render_lua(data)
    assert lua.startswith('-- Generated by tools/build_talents.py')
    assert 'ns.LazyData("TALENTS", [=[\nreturn {\n' in lua, 'the table waits for its first use (Core/LazyData.lua)'
    assert 'ns.TALENTS = {' in lua_data.eager(lua)
    assert re.search(r'MAGE = \{ id = 8, tree = 1112, spec = 1482,', lua)
    # a node row: { node, entry, spell, icon, tree, row, col, max, gates, pre, name, desc, values }
    assert '{ 105804, 130504, 12043, 136031, 1, 2, 2, 1, { 12705, 10 }, { 105803 }, "Presence of Mind", ' in lua
    assert '{ 105805, 130505, 11069, 135812, 2, 0, 0, 5, 0, 0, "Improved Fireball", ' \
           '"Reduces the casting time of your Fireball spell by {1} sec.", { { "0.1", "0.2", "0.3", "0.4", "0.5" } } },' in lua


def test_lua_is_valid_and_loads():
    lupa = pytest.importorskip('lupa.lua51')
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    src = build_talents.render_lua(build_talents.build([FIX]))
    t = lua_data.load(src, 'TalentData.lua', lua).TALENTS
    assert t.max == 51 and t.classes.MAGE.tree == 1112
    assert t.classes.MAGE.nodes[1][1] == A1


def test_shipped_data_file_in_toc_and_valid():
    with open(os.path.join(ADDON, 'Amisia.toc'), encoding='utf-8') as fh:
        toc = fh.read()
    assert 'Data\\TalentData.lua [AllowLoadGameType camelot]' in toc
    assert toc.index('Data\\TalentData.lua') < toc.index('Gear\\Talents.lua')
    with open(OUT, encoding='utf-8') as fh:
        src = fh.read()
    assert src.startswith('-- Generated by tools/build_talents.py')
    lupa = pytest.importorskip('lupa.lua51')
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    t = lua_data.load(src, 'TalentData.lua', lua).TALENTS
    assert t.max == 51
    classes = [k for k in t.classes.keys()]
    assert len(classes) in (0, 9), 'either no data yet or all nine Forever classes'
    for k in classes:
        c = t.classes[k]
        assert len(c.trees) == 3
        for _, row in c.nodes.items():
            assert 1 <= row[5] <= 3 and 0 <= row[6] <= 9 and 0 <= row[7] <= 3 and row[8] >= 1


def test_missing_table_fails_clearly(tmp_path):
    with pytest.raises(SystemExit) as e:
        build_talents.build([str(tmp_path)])
    assert 'TraitNode' in str(e.value)
