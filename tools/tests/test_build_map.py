"""tools/build_map.py: the map keys of the gear data's sources, resolving every kind to a place
from AllTheThings' data (tools/att_data.py, on the hand-made fixture in tools/tests/fixtures/att)
and writing MapData.lua (WoW Forever only). No QuestieDB."""
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import att_data  # noqa: E402
import build_map  # noqa: E402
import lua_data  # noqa: E402

FIXTURE = os.path.join(HERE, 'fixtures', 'att')
FACTS = [{'key': 'thanes', 'name': 'Test Halls', 'kind': 'party', 'aliases': ['Halls of Testing']},
         {'key': 'deep', 'name': 'Test Deep', 'kind': 'party'}]

GEAR = r"""local _, ns = ...
ns.GEAR = {
    game = "forever", cap = 60, built = "2026-10-06",
    S = {
        {"Q", "Boar Trouble", 0, 6, "A", 1426, 71001, 3},
        {"Q", "Forever Quest", 0, 7, nil, 1426, 71004, 0},
        {"Q", "Inside Job", 0, 12, "H", 9101, 70002, 0, "Test Halls"},
        {"Q", "Found Note", 0, 9, nil, nil, 70003, 0},
        {"Q", "Unknown", 0, 9, nil, nil, 79998, 0},
        {"V", "Smith Fixture", 1426, "H", "Armorer", nil, 81003},
        {"V", "Smith Fixture", 1426},
        {"R", "Old Tusk", 0, 1426, 81002},
        {"W", "Gnoll Brute", 0, 0, 1426, 81004},
        {"W", "Trash (Test Deep)", 0, 0},
        {"D", "Test Deep", "Deep Boss", nil, 4002, 99003},
        {"D", "Test Halls", "Boss", nil, nil, 99001},
        {"D", "Halls of Testing", "Boss", nil, 4001, 99001},
        {"D", "Nowhere Keep", "Boss", nil, 4999, 0},
        {"C", "tailoring", 0},
        {"A"},
    },
    Z = {},
    I = {},
}
"""

OLD_GEAR = r"""local _, ns = ...
ns.GEAR = {
    built = "2026-10-04",
    S = {
        {"Q", "Kobold Camp Cleanup", 2, 1, "A", 1429, 7, 0},
        {"D", "Deadmines", "Cookie", nil, 291},
    },
    Z = {},
    I = {},
}
"""


@pytest.fixture(scope='module')
def resolved():
    recs, has_game = build_map.load_gear_text(GEAR)
    needed = build_map.needed_keys(recs, has_game)
    db = att_data.load(FIXTURE, items=False)
    return build_map.resolve(db, needed, FACTS), needed


def test_no_questie_left():
    with open(build_map.__file__, encoding='utf-8') as fh:
        assert 'questie' not in fh.read().lower()
    assert not os.path.exists(os.path.join(os.path.dirname(HERE), 'map_questie.json')), 'the cached subset is gone'


def test_at_most_four_points_far_apart():
    pts = [(1, 3510, 5520), (1, 3515, 5525), (1, 3820, 5010), (1, 9000, 9000), (1, 1000, 9000), (1, 9000, 1000)]
    picked = build_map.pick_points(pts)
    assert len(picked) == 4
    assert (1, 3515, 5525) not in picked, 'the near twin within 2 % is merged'
    assert {(1, 9000, 9000), (1, 1000, 9000), (1, 9000, 1000)} <= set(picked)
    assert build_map.pick_points([(1, 10, 10), (2, 10, 10)]) == [(1, 10, 10), (2, 10, 10)], 'other maps always count'
    assert build_map.fmt_points([(1429, 4232, 6510), (1, 0, 10000)]) == '1429:4232:6510 1:0:10000'


def test_keys_per_source_kind():
    k = build_map.key_of
    assert k(['Q', 'x', 1, 1, 'A', 1429, 7, 0], False) == 'Q:7'
    assert k(['Q', 'x', 1, 1, None, None, None, 0, 'Dungeon'], False) is None
    assert k(['V', 'Gorn One Eye', 1448], False) == 'V:Gorn One Eye'
    assert k(['P', 'Gorn One Eye', 1448, 'H', 'Armorer', None, 101], False) == 'U:101'
    assert k(['V', 'Gorn One Eye', 1448, 'H', 'Armorer', None, 101], False) == 'U:101'
    assert k(['R', 'Muad', 10, 1420], False) == 'R:Muad' and k(['R', 'Muad', 10, 1420, 103], False) == 'U:103'
    assert k(['W', 'Trash (The Deadmines)', 18, 19], False) == 'N:The Deadmines'
    assert k(['W', 'Twin', 10, 10, 1411], False) == 'W:Twin' and k(['W', 'Twin', 10, 10, None, 111], False) == 'U:111'
    assert k(['W', 'Twin', 10, 10], False) is None, 'a named mob without zone has no place'
    assert k(['W', None, 10, 20], False) is None
    assert k(['D', 'Deadmines', 'Cookie', None, 291], False) == 'N:Deadmines', 'old Forever data: by name'
    assert k(['D', 'The Deadmines', 'Cookie', None, 36, 1581], True) == 'I:36'
    assert k(['X', 'Molten Core', 'Ragnaros', 409, 2717, 0, 0], False) == 'I:409'
    assert k(['C', 'tailoring', 50], False) is None and k(['A'], False) is None


def test_gear_data_is_read_with_and_without_the_game_field():
    recs, has_game = build_map.load_gear_text(OLD_GEAR)
    assert not has_game and recs[0] == ['Q', 'Kobold Camp Cleanup', 2, 1, 'A', 1429, 7, 0]
    recs, has_game = build_map.load_gear_text(GEAR)
    assert has_game and recs[10] == ['D', 'Test Deep', 'Deep Boss', None, 4002, 99003]


def test_quests_start_where_the_giver_or_object_stands(resolved):
    (P, G, report), _ = resolved
    assert P['Q:71001'] == [(1426, 4000, 6000)] and G['Q:71001'] == 'Farmer Fixture'
    assert P['Q:71004'] == [(1426, 1000, 1000), (1455, 2000, 2000)] and 'Q:71004' not in G, 'object starter, no giver'
    assert P['Q:70002'] == [], 'a giver inside a dungeon whose entrance is not measured: no place'
    assert P['Q:70003'] == [] and report['quest item start'] == 1
    assert P['Q:79998'] == [] and report['unknown quests'] == 1


def test_npcs_by_id_and_by_name(resolved):
    (P, G, report), _ = resolved
    assert P['U:81003'] == [(1426, 5000, 4000)], 'the Forever record, not the old zone file'
    assert P['V:Smith Fixture'] == P['U:81003']
    assert P['U:81002'] == [(1426, 3000, 3000), (1426, 3100, 3100)]
    assert P['U:81004'] == [], 'a mob only a drop names has no coordinates'


def test_entrances_by_instance_id_and_name(resolved):
    (P, G, report), _ = resolved
    assert P['I:4002'] == [(1426, 7000, 2000)], 'the instance map id from UiMapAssignment'
    assert P['N:Test Deep'] == P['I:4002'], 'trash of a dungeon: its entrance'
    assert P['N:Test Halls'] == [], 'an entrance given as the middle of the zone is not measured: no place'
    assert P['I:4999'] == [] and report['unknown instances'] == [4999], 'an instance the data does not know'
    assert report['kinds']['D'] == (1, 3)


def test_output_header_without_guard_sorted_and_repeatable(tmp_path, resolved):
    (P, G, _), needed = resolved
    assert set(P) == set(needed)
    out = tmp_path / 'MapData.lua'
    build_map.write_lua(str(out), P, G, 'f8d7232b7c988cb31f927f076d4692bc85c6fd0c', '2026-10-06')
    text = out.read_text(encoding='utf-8')
    lines = text.split('\n')
    assert lines[0] == '-- GENERATED by tools/build_map.py. Do not edit; rebuild instead.'
    assert 'AllTheThings' in lines[1] and 'MIT' in lines[1] and 'LICENSES' in lines[1] and 'f8d7232b7c' in lines[1]
    assert 'Questie' not in text and 'GPL' not in text
    assert lines[2] == 'local _, ns = ...' and lines[3] == '', 'no guard line'
    assert lua_data.compact('game = "forever", built = "2026-10-06", source = "f8d7232b7c",') in lines
    keys = [ln.split('"')[1] for ln in lines if ln.startswith('["')]
    pkeys = keys[:len([k for k in P if P[k]])]
    assert pkeys == sorted(pkeys)
    assert '["U:81004"]' not in text, 'keys without points stay out'
    assert '["Q:71001"]="1426:4000:6000",' in text
    first = text
    build_map.write_lua(str(out), P, G, 'f8d7232b7c988cb31f927f076d4692bc85c6fd0c', '2026-10-06')
    assert out.read_text(encoding='utf-8') == first

    # the table waits for its first use in the addon (Core/LazyData.lua)
    assert 'ns.LazyData("MAP", [=[\nreturn {\n' in text and 'ns.MAP = {' not in text
    ns = lua_data.load(text, 'MapData.lua')
    assert ns.MAP.P['Q:71001'] == '1426:4000:6000' and ns.MAP.G['Q:71001'] == 'Farmer Fixture' and ns.MAP.game == 'forever'


def test_there_is_no_game_switch():
    with pytest.raises(SystemExit):
        build_map.main(['--game', 'tbc'])
    assert not hasattr(build_map, 'QUARTERMASTERS')
