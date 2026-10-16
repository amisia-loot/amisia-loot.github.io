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
                  ('oneforall', [(1413, 4600, 3650)])]) == ([(1413, 4769, 3498)], 'client'), \
        'the same entrance measured worse and a continent point stay out'
    assert merge([('client', [(1421, 4472, 6777)]), ('att', [(1421, 3660, 6560)])]) == ([(1421, 4472, 6777)], 'client'), \
        'a single point of a later source 8 % away is no second entrance'
    pts, won = merge([('client', [(1418, 3521, 1029)]), ('att', [(16, 3660, 2940), (1418, 6400, 4400)])])
    assert won == 'client' and pts == [(1418, 3521, 1029), (16, 3660, 2940), (1418, 6400, 4400)], \
        "Uldaman: its own outdoor map and the back door join"
    assert merge([('client', []), ('att', []), ('oneforall', [(1455, 2763, 4783)]), ('learned', [(1455, 2800, 4800)])]) == \
        ([(1455, 2763, 4783)], 'oneforall'), 'approximate before learned, the learned one does not join'
    assert merge([('client', []), ('att', []), ('oneforall', []), ('learned', [(1, 2, 3)])]) == ([(1, 2, 3)], 'learned')
    assert merge([('client', []), ('att', [(1414, 1, 1)])]) == ([], None), 'nothing but a continent point'


def test_entrances_per_fact_and_their_keys(tmp_path):
    c = build_map.Client(client_tables(tmp_path / 'wago'))
    facts = [{'key': 'wc', 'name': 'Wailing Caverns', 'kind': 'party', 'inst': 43},
             {'key': 'thanes', 'name': 'Hall of Thanes', 'kind': 'party', 'inst': 3065},
             {'key': 'drowned', 'name': 'Drowned City', 'kind': 'party'}]
    ofa = {'dungeons': [{'name': 'Wailing Caverns', 'inst': 43, 'zone': 'The Barrens', 'x': 46.0, 'y': 36.5},
                        {'name': 'Hall of Thanes', 'inst': None, 'zone': 'The Barrens', 'x': 27.63, 'y': 47.83}]}
    learned = {7777: {'map': 1413, 'x': 100, 'y': 200, 'name': 'The Drowned City', 'kind': 'party', 'seen': 5}}
    ent = build_map.entrances(facts, att_data.empty_db(), c, ofa, learned)
    assert ent['I:43'] == ([(1413, 6250, 2500)], 'client'), 'the client table on the zone OneForAll names'
    assert ent['I:3065'] == ([(1413, 2763, 4783)], 'oneforall')
    assert ent['N:Drowned City'] == ([(1413, 100, 200)], 'learned'), 'a learned instance found by its name'
    P = {'N:Wailing Caverns': [(1, 1, 1)], 'I:43': [], 'Q:1': [(1, 2, 3)]}
    E = build_map.apply_entrances(P, facts, ent)
    assert P['N:Wailing Caverns'] == P['I:43'] == [(1413, 6250, 2500)] and P['Q:1'] == [(1, 2, 3)], \
        'the gear data\'s keys of a dungeon get its entrance'
    assert E == {'I:43': 'c', 'N:Wailing Caverns': 'c', 'I:3065': 'o', 'N:Drowned City': 'l'}


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
    ofa = {'flights': [(1413, 5150, 3030, 'H', 'Devrak')],
           'zeppelins': [(1434, 3140, 2990, ['Orgrimmar', 'Undercity'])],
           'ships': [(1413, 6370, 3860, 'N', 'Booty Bay, Stranglethorn Vale')]}
    att = {'flights': {
        25: {'place': 'Crossroads', 'npc': 3615, 'name': 'Devrak', 'points': [(1413, 5140, 3020)], 'faction': 'H'},
        77: {'place': 'Camp Taurajo', 'npc': 10378, 'name': 'Omusa', 'points': [(1413, 4440, 5900)], 'faction': 'H'},
        80: {'place': 'Ratchet', 'npc': 16227, 'name': None, 'points': [(1413, 6300, 3700)], 'faction': ''},
        85: {'place': 'Tower', 'npc': None, 'name': None, 'points': [(1423, 1, 1)], 'faction': ''}}}
    F, added = build_map.flights(ofa, att)
    assert added == 2 and F == [(1413, 4440, 5900, 'H', 'Omusa'), (1413, 5150, 3030, 'H', 'Devrak'),
                                (1413, 6300, 3700, 'N', 'Ratchet')], F
    hand = [{'map': 1413, 'x': 63.7, 'y': 38.6, 'kind': 'ship', 'faction': 'AH', 'to': ['Booty Bay'], 'src': 'x'},
            {'map': 1437, 'x': 5.0, 'y': 63.4, 'kind': 'ship', 'faction': 'A', 'to': ['Theramore Isle'], 'src': 'x'}]
    T = build_map.transports(ofa, c, hand)
    assert T == [(1413, 6370, 3860, 'S', 'N', ((35, 'Booty Bay'),)),
                 (1434, 3140, 2990, 'Z', 'H', ((0, 'Orgrimmar'), (0, 'Undercity'))),
                 (1437, 500, 6340, 'S', 'A', ((0, 'Theramore Isle'),))], T
    with open(build_map.TRANSPORTS, encoding='utf-8') as fh:
        kept = json.load(fh)
    assert kept['checked'] and len(kept['routes']) >= 7, 'the classic routes are checked against OneForAll'
    for d in kept['docks']:
        assert d['src'] and d['kind'] in ('zeppelin', 'ship') and d['to'], d


def test_oneforall_places_in_the_sandbox(tmp_path):
    base = tmp_path / 'ofa'
    (base / 'Data').mkdir(parents=True)
    (base / 'OneForAll.toc').write_text('## Version: 9.9.9\nData\\MapLandmarks.lua\nDungeonData.lua\nMapLandmarks.lua\n',
                                        encoding='utf-8')
    (base / 'Data' / 'MapLandmarks.lua').write_text(
        'local _, FLT = ...\nFLT.MAP_LANDMARKS = { flight = { {1413,63.1,37.2,"AH","Bragok"} },\n'
        ' zeppelin = { {1434,31.4,29.9,"Orgrimmar","Undercity"} }, ship = { {1413,63.7,38.6,"AH","Booty Bay, X"} } }\n',
        encoding='utf-8')
    (base / 'DungeonData.lua').write_text(
        'local _, FLT = ...\nFLT.DUNGEONS = { { name = "Hall of Thanes", mapZone = "Ironforge", mapX = 27.63, mapY = 47.83 } }\n',
        encoding='utf-8')
    (base / 'MapLandmarks.lua').write_text('os.exit(1)\n', encoding='utf-8')   # runtime code: never run
    o = build_map.load_ofa_places(str(base))
    assert o['version'] == '9.9.9' and o['flights'] == [(1413, 6310, 3720, 'N', 'Bragok')]
    assert o['zeppelins'] == [(1434, 3140, 2990, ['Orgrimmar', 'Undercity'])] and o['ships'] == [(1413, 6370, 3860, 'N', 'Booty Bay, X')]
    assert o['dungeons'] == [{'name': 'Hall of Thanes', 'inst': None, 'zone': 'Ironforge', 'x': 27.63, 'y': 47.83}]
    assert build_map.load_ofa_places(str(tmp_path / 'none')) is None


def test_places_in_the_output(tmp_path):
    out = tmp_path / 'MapData.lua'
    P = {'I:43': [(1413, 4769, 3498)]}
    build_map.write_lua(str(out), P, {}, 'abc', '2026-10-16', {'I:43': 'c', 'I:9': 'a'},
                        [(1413, 5150, 3030, 'H', 'Devrak')], [(1434, 3140, 2990, 'Z', 'H', ((1637, 'Orgrimmar'),))],
                        ['OneForAll 5.6.2 (GPL-3.0-or-later; see LICENSES/) at x: flight masters.'])
    text = out.read_text(encoding='utf-8')
    lines = text.split('\n')
    assert lines[2].startswith('-- OneForAll') and lines[3] == 'local _, ns = ...'
    ns = lua_data.load(text, 'MapData.lua')
    assert ns.MAP.E['I:43'] == 'c' and ns.MAP.E['I:9'] is None, 'sources only of keys with points'
    assert ns.MAP.F[1][5] == 'Devrak' and ns.MAP.F[1][4] == 'H'
    assert ns.MAP.T[1][4] == 'Z' and ns.MAP.T[1][6][1][1] == 1637 and ns.MAP.T[1][6][1][2] == 'Orgrimmar'


def test_the_shipped_map_data_has_its_places():
    with open(build_map.OUT, encoding='utf-8') as fh:
        text = fh.read()
    ns = lua_data.load(text, 'MapData.lua')
    m = ns.MAP
    assert m.F is not None and m.T is not None and m.E is not None, 'MapData.lua carries F, T and E'
    head = text.split('local _, ns')[0]
    assert 'OneForAll' in head and 'GPL-3.0' in head and 'Client tables' in head


def test_there_is_no_game_switch():
    with pytest.raises(SystemExit):
        build_map.main(['--game', 'tbc'])
    assert not hasattr(build_map, 'QUARTERMASTERS')
