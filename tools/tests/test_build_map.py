"""tools/build_map.py: the map keys of the gear data's sources, resolving every kind to a place
from AllTheThings' data (tools/att_data.py, on the hand-made fixture in tools/tests/fixtures/att)
and writing MapData.lua (WoW Forever only). No QuestieDB. The places of F-105: entrances from the
client tables, AllTheThings, OneForAll and the learned ones, flight masters and docks."""
import json
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


# ---------------------------------------------------------------- places (F-105)
def client_tables(folder):
    """A hand-made client table set: two overlapping zones on Kalimdor (map 1), the continent, one
    instance with its entrance, one without, the area names."""
    folder.mkdir(exist_ok=True)
    (folder / 'Map.1.60.1.1.csv').write_text(
        'ID,MapName_lang,Corpse_0,Corpse_1,InstanceType,CorpseMapID\n'
        '43,Wailing Caverns,-1000,-1500,1,1\n'
        '3065,The Hall of Thanes,0,0,1,-1\n'
        '1,Kalimdor,0,0,0,-1\n', encoding='utf-8')
    (folder / 'UiMapAssignment.1.60.1.1.csv').write_text(
        'UiMin_0,UiMin_1,UiMax_0,UiMax_1,Region_0,Region_1,Region_2,Region_3,Region_4,Region_5,ID,UiMapID,OrderIndex,MapID,AreaID\n'
        '0,0,1,1,-4000,-3000,-1000000,0,1000,1000000,1,1413,0,1,17\n'
        '0,0,1,1,-2000,-2000,-1000000,0,0,1000000,2,1411,0,1,14\n'
        '0,0,1,1,-9000,-9000,-1000000,9000,9000,1000000,3,1414,0,1,0\n', encoding='utf-8')
    (folder / 'AreaTable.1.60.1.1.csv').write_text(
        'ID,ZoneName,AreaName_lang,ContinentID,ParentAreaID\n'
        '17,Barrens,The Barrens,1,0\n14,Durotar,Durotar,1,0\n35,BootyBay,Booty Bay,0,33\n'
        "117,Gromgol,Grom'gol Base Camp,0,33\n", encoding='utf-8')
    return str(folder)


def test_client_entrance_on_the_zone_another_source_names(tmp_path):
    c = build_map.Client(client_tables(tmp_path / 'wago'))
    assert c.instances[43]['corpse'] == (1, -1000.0, -1500.0) and c.instances[3065]['corpse'] is None
    assert sorted(z[0] for z in c.on_zones(1, -1000, -1500)) == [1411, 1413], 'the continent is no zone'
    assert c.entrance(43, hints=[1413]) == (1413, 6250, 2500), 'the zone AllTheThings or OneForAll name'
    assert c.entrance(43) == (1411, 7500, 5000), 'without a hint the zone that holds it deepest (equal: the lower id)'
    assert c.entrance(3065) is None and c.entrance(9999) is None
    assert c.zone('The Barrens') == 1413 and c.zone('Nowhere') is None
    assert c.area('Booty Bay, Stranglethorn Vale') == 35 and c.area("Grom'gol, Stranglethorn Vale") == 117
    assert build_map.Client(str(tmp_path / 'none')).instances == {}, 'no tables: empty'


def test_the_first_source_wins_and_only_real_second_entrances_join():
    merge = build_map.merge_entrances
    assert merge([('client', [(1413, 4769, 3498)]), ('att', [(1413, 4590, 3570), (1414, 5200, 5520)]),
                  ('learned', [(1413, 4600, 3650)])]) == ([(1413, 4769, 3498)], 'client'), \
        'the same entrance measured worse and a continent point stay out'
    assert merge([('client', [(1421, 4472, 6777)]), ('att', [(1421, 3660, 6560)])]) == ([(1421, 4472, 6777)], 'client'), \
        'a single point of a later source 8 % away is no second entrance'
    pts, won = merge([('client', [(1418, 3521, 1029)]), ('att', [(16, 3660, 2940), (1418, 6400, 4400)])])
    assert won == 'client' and pts == [(1418, 3521, 1029), (16, 3660, 2940), (1418, 6400, 4400)], \
        "Uldaman: its own outdoor map and the back door join"
    assert merge([('client', []), ('att', [(1455, 2763, 4783)]), ('learned', [(1455, 2800, 4800)])]) == \
        ([(1455, 2763, 4783)], 'att'), 'AllTheThings before learned, the learned one does not join'
    assert merge([('client', []), ('att', []), ('learned', [(1, 2, 3)])]) == ([(1, 2, 3)], 'learned')
    assert merge([('client', []), ('att', [(1414, 1, 1)])]) == ([], None), 'nothing but a continent point'


def test_entrances_per_fact_and_their_keys(tmp_path):
    c = build_map.Client(client_tables(tmp_path / 'wago'))
    facts = [{'key': 'wc', 'name': 'Wailing Caverns', 'kind': 'party', 'inst': 43},
             {'key': 'thanes', 'name': 'Hall of Thanes', 'kind': 'party', 'inst': 3065},
             {'key': 'drowned', 'name': 'Drowned City', 'kind': 'party'}]
    learned = {7777: {'map': 1413, 'x': 100, 'y': 200, 'name': 'The Drowned City', 'kind': 'party', 'seen': 5}}
    ent = build_map.entrances(facts, att_data.empty_db(), c, learned)
    assert ent['I:43'][1] == 'client', 'the client table'
    assert ent['I:3065'] == ([], None), 'a new dungeon no source knows waits to be learned'
    assert ent['N:Drowned City'] == ([(1413, 100, 200)], 'learned'), 'a learned instance found by its name'
    P = {'N:Wailing Caverns': [(1, 1, 1)], 'I:43': [], 'Q:1': [(1, 2, 3)]}
    E = build_map.apply_entrances(P, facts, ent)
    assert P['N:Wailing Caverns'] == P['I:43'] == ent['I:43'][0] and P['Q:1'] == [(1, 2, 3)], \
        'the gear data\'s keys of a dungeon get its entrance'
    assert E == {'I:43': 'c', 'N:Wailing Caverns': 'c', 'N:Drowned City': 'l'}


def test_learned_entrances_join_the_archive(tmp_path):
    db = {'entrances': {'v': 1, 'list': {
        43: {'m': 1413, 'x': 4612, 'y': 3567, 't': 200, 'n': 'Die Höhlen des Wehklagens', 'k': 'party'},
        47: {'m': 1413, 'x': 20000, 'y': 1, 't': 200},
        'x': {'m': 1, 'x': 1, 'y': 1, 't': 1},
        48: {'m': 1440, 'x': 1, 'y': 1, 't': True}}}}
    got = build_map.learned_from_sv(db)
    assert got == {43: {'map': 1413, 'x': 4612, 'y': 3567, 'name': 'Die Höhlen des Wehklagens', 'kind': 'party', 'seen': 200}}
    assert build_map.learned_from_sv({}) == {} and build_map.learned_from_sv({'entrances': 'x'}) == {}
    path = str(tmp_path / 'entrance_archive.json')
    arch = build_map.load_entrance_archive(path)
    assert build_map.join_entrances(arch, got) == 1
    assert build_map.save_entrance_archive(arch, path, today='2026-10-16')
    assert not build_map.save_entrance_archive(build_map.load_entrance_archive(path), path, today='2026-10-17'), 'unchanged'
    arch = build_map.load_entrance_archive(path)
    assert arch['updated'] == '2026-10-16' and arch['entrances']['43']['x'] == 4612
    older = {43: dict(got[43], x=1, seen=100)}
    assert build_map.join_entrances(arch, older) == 0, 'an older sighting does not replace the newer'
    newer = {43: dict(got[43], x=5000, seen=300)}
    assert build_map.join_entrances(arch, newer) == 1 and arch['entrances']['43']['x'] == 5000


def test_flight_masters_and_docks(tmp_path):
    c = build_map.Client(client_tables(tmp_path / 'wago'))
    att = {'flights': {
        25: {'place': 'Crossroads', 'npc': 3615, 'name': 'Devrak', 'points': [(1413, 5140, 3020)], 'faction': 'H'},
        77: {'place': 'Camp Taurajo', 'npc': 10378, 'name': 'Omusa', 'points': [(1413, 4440, 5900)], 'faction': 'H'},
        80: {'place': 'Ratchet', 'npc': 16227, 'name': None, 'points': [(1413, 6300, 3700)], 'faction': ''},
        85: {'place': 'Tower', 'npc': None, 'name': None, 'points': [(1423, 1, 1)], 'faction': ''}}}
    by_hand = [{'map': 1413, 'x': 51.5, 'y': 30.3, 'faction': 'H', 'name': 'Devrak', 'src': 'x'},
               {'map': 1444, 'x': 75.5, 'y': 44.4, 'faction': 'H', 'name': 'Shyn', 'src': 'x'},
               {'map': 1413, 'x': 44.9, 'y': 59.5, 'faction': 'A', 'name': 'Other side', 'src': 'x'},
               {'map': 1413, 'x': 63.5, 'y': 37.5, 'faction': 'A', 'name': 'Near the neutral', 'src': 'x'}]
    F, from_att = build_map.flights(att, by_hand)
    assert from_att == 3 and F == [(1413, 4440, 5900, 'H', 'Omusa'), (1413, 4490, 5950, 'A', 'Other side'),
                                   (1413, 5140, 3020, 'H', 'Devrak'), (1413, 6300, 3700, 'N', 'Ratchet'),
                                   (1444, 7550, 4440, 'H', 'Shyn')], 'the other faction may stand close by, not one at a neutral'
    hand = [{'map': 1413, 'x': 63.7, 'y': 38.6, 'kind': 'ship', 'faction': 'AH', 'to': ['Booty Bay, Stranglethorn Vale']},
            {'map': 1413, 'x': 63.8, 'y': 38.7, 'kind': 'ship', 'faction': 'AH', 'to': ['Booty Bay']},
            {'map': 1434, 'x': 31.4, 'y': 29.9, 'kind': 'zeppelin', 'faction': 'H', 'to': ['Orgrimmar', 'Undercity']},
            {'map': 1437, 'x': 5.0, 'y': 63.4, 'kind': 'ship', 'faction': 'A', 'to': ['Theramore Isle']}]
    T = build_map.transports(c, hand)
    assert T == [(1413, 6370, 3860, 'S', 'N', ((35, 'Booty Bay'),)),
                 (1434, 3140, 2990, 'Z', 'H', ((0, 'Orgrimmar'), (0, 'Undercity'))),
                 (1437, 500, 6340, 'S', 'A', ((0, 'Theramore Isle'),))], 'one dock per place and kind'
    kept = build_map.load_transports()
    assert len(kept['docks']) >= 11, 'the classic docks'
    assert kept['flights'] == [], 'the six flight masters by hand are all TaxiNodes nodes now (F-171)'
    for d in kept['docks']:
        assert d['src'] and d['kind'] in ('zeppelin', 'ship') and d['to'], d
    for f in kept['flights']:
        assert f['src'] and f['name'] and f['faction'] in ('A', 'H', 'AH'), f
    assert build_map.load_transports(str(tmp_path / 'none')) == {'docks': [], 'flights': []}


TAXI = ('Name_lang,Pos_0,Pos_1,Pos_2,ID,ContinentID,ConditionID,CharacterBitNumber,Flags,MountCreatureID_0,MountCreatureID_1\n'
        '"Crossroads, The Barrens",-1000,-1500,0,25,1,0,25,1026,2224,0\n'
        '"Ratchet, The Barrens",-2000,-2600,0,80,1,0,80,1027,2224,541\n'
        '"Camp Taurajo, The Barrens",-3000,-1000,0,77,1,0,77,1026,2224,0\n'
        '"Nighthaven, Moonglade",-1000,-1400,0,62,1,0,0,1025,0,3837\n'
        '"Transport, Booty Bay - Ratchet",-1200,-1500,0,34,1,0,0,1024,0,0\n'
        '"zzOLDPowderfuse Port, Riverglades",-2000,-2600,0,3208,1,0,34,1027,2224,541\n'
        '"Dun Baldar, Alterac Valley",574,-46,0,59,30,0,0,1025,0,541\n'
        '"Far Away",50000,50000,0,90,1,0,90,1025,0,541\n')


def test_flight_points_from_taxinodes(tmp_path):
    """F-171, D-102: the client's flight points with side and place; AllTheThings' flight master names by
    side and distance, by id further away; the unusable nodes left out with their reason."""
    folder = client_tables(tmp_path / 'wago')
    (tmp_path / 'wago' / 'TaxiNodes.1.60.1.1.csv').write_text(TAXI, encoding='utf-8')
    c = build_map.Client(folder)
    nodes = build_map.taxi_nodes(folder)
    assert [n['id'] for n in nodes] == [25, 34, 59, 62, 77, 80, 90, 3208]
    assert build_map.taxi_nodes(str(tmp_path / 'none')) == []
    why = {n['id']: build_map.node_unusable(n) for n in nodes}
    assert why[25] is None and why[80] is None and why[77] is None and why[90] is None
    assert 'zzOLD' in why[3208] and 'continent 30' in why[59] and 'flags 0x400' in why[34] and 'learns' in why[62]
    assert [build_map.node_side(n) for n in nodes if n['id'] in (25, 62, 80)] == ['H', 'A', 'N']
    assert build_map.node_points(c, nodes[0]) == [(1413, 6250, 2500), (1411, 7500, 5000)], 'the zone of its name first'
    att = {'flights': {
        25: {'npc': 3615, 'name': 'Devrak', 'points': [(1413, 6200, 2550)], 'faction': 'H'},
        80: {'npc': 16227, 'name': 'Bragok', 'points': [(1413, 2000, 2000)], 'faction': ''},
        62: {'npc': 11798, 'name': 'Bunthen Plainswind', 'points': [(1413, 100, 100)], 'faction': 'H'},
        99: {'npc': 1, 'name': 'Other Side', 'points': [(1413, 6250, 2500)], 'faction': 'A'},
        84: {'npc': None, 'name': None, 'points': [(1423, 1, 1)], 'faction': ''}}}
    hand = [{'map': 1413, 'x': 62.4, 'y': 25.1, 'faction': 'H', 'name': 'Devrak', 'src': 'x'},
            {'map': 1444, 'x': 75.5, 'y': 44.4, 'faction': 'H', 'name': 'Shyn', 'src': 'x'}]
    F, rep = build_map.table_flights(c, nodes, att, hand)
    assert F == [(1413, 5000, 7500, 'H', 'Camp Taurajo, The Barrens', 'Camp Taurajo, The Barrens'),
                 (1413, 6250, 2500, 'H', 'Devrak', 'Crossroads, The Barrens'),
                 (1413, 9000, 5000, 'N', 'Bragok', 'Ratchet, The Barrens'),
                 (1444, 7550, 4440, 'H', 'Shyn', '')], F
    assert rep['matched'] == [(25, 'Devrak', 71)] and rep['far'] == [(80, 'Bragok', 7616)]
    assert rep['side'] == [(62, 'Nighthaven, Moonglade', 'A', 'H')], 'the table and AllTheThings disagree'
    assert rep['att_only'] == [(62, 'Bunthen Plainswind', 'H'), (99, 'Other Side', 'A')], 'not the other side\'s node'
    assert rep['no_zone'] == [(90, 'Far Away')] and rep['hand'] == ['Shyn']
    assert sorted(i for i, _, _ in rep['excluded']) == [34, 59, 62, 3208]


def test_places_in_the_output(tmp_path):
    out = tmp_path / 'MapData.lua'
    P = {'I:43': [(1413, 4769, 3498)]}
    build_map.write_lua(str(out), P, {}, 'abc', '2026-10-16', {'I:43': 'c', 'I:9': 'a'},
                        [(1413, 5150, 3030, 'H', 'Devrak', 'Crossroads, The Barrens'), (1413, 1, 1, 'A', 'By Hand', '')],
                        [(1434, 3140, 2990, 'Z', 'H', ((1637, 'Orgrimmar'),))],
                        ['OneForAll 5.6.2 (GPL-3.0-or-later; see LICENSES/) at x: flight masters.'])
    text = out.read_text(encoding='utf-8')
    lines = text.split('\n')
    assert lines[2].startswith('-- OneForAll') and lines[3] == 'local _, ns = ...'
    ns = lua_data.load(text, 'MapData.lua')
    assert ns.MAP.E['I:43'] == 'c' and ns.MAP.E['I:9'] is None, 'sources only of keys with points'
    assert ns.MAP.F[1][5] == 'Devrak' and ns.MAP.F[1][4] == 'H' and ns.MAP.F[1][6] == 'Crossroads, The Barrens'
    assert ns.MAP.F[2][5] == 'By Hand' and ns.MAP.F[2][6] is None, 'no place for one by hand'
    assert ns.MAP.T[1][4] == 'Z' and ns.MAP.T[1][6][1][1] == 1637 and ns.MAP.T[1][6][1][2] == 'Orgrimmar'


def test_the_shipped_map_data_has_its_places():
    with open(build_map.OUT, encoding='utf-8') as fh:
        text = fh.read()
    ns = lua_data.load(text, 'MapData.lua')
    m = ns.MAP
    assert m.F is not None and m.T is not None and m.E is not None, 'MapData.lua carries F, T and E'
    head = text.split('local _, ns')[0]
    assert 'Client tables' in head and 'forever_transports.json' in head and 'GPL' not in head
    assert len(build_map.seq(build_map.py(m.T))) >= 11 and len(build_map.seq(build_map.py(m.F))) >= 60, 'the docks by hand, the flight masters'
    assert 'TaxiNodes' in head, 'the flight points from the client table (F-171)'
    places = [f.get(6) for f in build_map.seq(build_map.py(m.F))]
    assert all(places) and "Rog'mar, Riverglades" in places, 'every flight point with its place; a new Forever one'


def test_there_is_no_game_switch():
    with pytest.raises(SystemExit):
        build_map.main(['--game', 'tbc'])
    assert not hasattr(build_map, 'QUARTERMASTERS')
