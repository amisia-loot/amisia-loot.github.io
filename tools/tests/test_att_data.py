"""tools/att_data.py: the shared reader of AllTheThings' Forever data (MIT) for build_gear.py,
build_map.py and build_dungeonquests.py. Runs on the hand-made fixture in tools/tests/fixtures/att
(the builder language, no real data): the sandbox, the preprocessor, timelines, quests, NPCs, drops,
vendors, zone drops, world drops, PvP gear, crafted items, the item export and the instance map ids."""
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import att_data  # noqa: E402

FIXTURE = os.path.join(HERE, 'fixtures', 'att')


@pytest.fixture(scope='module')
def db():
    return att_data.load(FIXTURE)


def test_the_sandbox_has_no_io_os_load_or_python(tmp_path):
    lua, S = att_data.sandbox()
    for name in ('io', 'os', 'python', 'require', 'loadstring', 'load', 'dofile', 'debug', 'package'):
        assert lua.eval(name) is None, name
    target = tmp_path / 'touched'
    # inside a data file "io" is only a stand-in: the call records nothing and touches nothing
    assert S.run('local f = io.open(%r, "w"); f:write("x")' % str(target), 'evil.lua', S.new()) is None
    assert not target.exists()


def test_preprocessor_keeps_the_forever_branches():
    src = '\n'.join(['a', '-- #if SEASON_OF_DISCOVERY', 'sod', '-- #elseif AFTER CATA', 'cata', '-- #else', 'forever',
                     '-- #endif', '-- #if BEFORE 4.0.3', 'classic', '-- #endif', '-- #if NOT ANYCLASSIC', 'retail',
                     '-- #endif', '-- #if AFTER 1.13.5 AND CAMELOT', 'both', '-- #endif'])
    out = att_data.preprocess(src).split('\n')
    assert len(out) == len(src.split('\n')), 'line numbers stay'
    assert [x for x in out if x] == ['a', 'forever', 'classic', 'both']
    assert att_data.pp_true('ANYCLASSIC') and not att_data.pp_true('TBC') and att_data.pp_true('BEFORE WRATH')
    assert att_data.pp_true('SEASON_OF_DISCOVERY OR FOREVER') and not att_data.pp_true('SEASON_OF_DISCOVERY')


def test_nothing_failed_and_the_commit(db):
    assert db['errors'] == {}
    assert db['files'][0].startswith('dungeons & raids/'), 'the Forever dungeon files first'
    assert any(f.startswith('zzOLD/') for f in db['files'])


def test_quests_from_a_zone_file(db):
    q = db['quests'][71001]
    assert q['name'] == 'Boar Trouble' and q['giver'] == 'Farmer Fixture' and q['givers'] == [81001]
    assert q['faction'] == 'A', 'Human and Dwarf'
    assert q['classes'] == 1 | 2, 'warrior and paladin as class bits'
    assert q['minLevel'] == 6 and q['zone'] == 1426 and q['points'] == [(1426, 4000, 6000)]
    assert q['rewards'] == [61001, 61002, 61003], 'the rewards and what a container holds, not the objective item'
    assert 71002 not in db['quests'], 'added with Cataclysm: not in Forever'
    assert 71003 not in db['quests'], 'the Season of Discovery branch is preprocessed away'
    q = db['quests'][71004]
    assert q['objects'] == [91001] and q['points'] == [(1426, 1000, 1000), (1455, 2000, 2000)], 'a bare map constant too'


def test_dungeon_quests_and_the_old_copy(db):
    q = db['quests'][70001]
    assert q['inst'] == 9001 and not q['old'] and q['minLevel'] == 10, 'the Forever record wins over the zzOLD copy'
    assert db['quests'][70002]['inside'], 'a giver on the dungeon map stands inside'
    assert db['quests'][70003]['startItem'] and db['quests'][70003]['rewards'] == [60003]


def test_npcs(db):
    n = db['npcs']
    assert n[81001]['title'] == 'Farmer' and n[81001]['points'] == [(1426, 4000, 6000)], 'a giver stands where the quest starts'
    assert n[81002]['kinds'] == {'rare'} and len(n[81002]['points']) == 2
    assert n[81003]['kinds'] == {'vendor'} and n[81003]['faction'] == 'H' and n[81003]['title'] == 'Armorer'
    assert n[81003]['points'] == [(1426, 5000, 4000)], 'the old zone file does not add its points'
    assert n[81006]['kinds'] == {'boss'} and n[81006]['inst'] == 9003 and n[81006]['old']
    assert n[81007]['name'] == 'Encounter Boss', 'an encounter boss named by its encounter'
    assert n[81004]['name'] == 'Gnoll Brute' and n[81004]['kinds'] == {'mob'}, 'a mob only a drop names'


def test_drops_vendors_and_the_rest(db):
    assert (60200, 80100, 'boss', 9001, 9101, False, 'Boss') in db['drops']
    assert (61004, 81002, 'rare', None, 1426, False, None) in db['drops']
    assert (61013, 81007, 'boss', 9003, 9102, True, 'Encounter Boss') in db['drops']
    assert (61006, [81004], None, 1426, False) in db['zone_drops'] and (61007, [], None, 1426, False) in db['zone_drops']
    assert (61011, [81005], 9003, 9102, True) in db['zone_drops']
    assert db['sold'] == [(61005, 81003, False), (61014, 81003, True)]
    assert db['world'] == [61015] and db['pvp'] == [(61016, 'A')] and db['crafted'] == [(61017, 'tailoring')]


def test_instances_and_their_map_ids(db):
    i = db['instances']
    assert i[9001]['name'] == 'Test Halls' and i[9001]['area'] == 99001 and i[9001]['mapID'] == 4001
    assert i[9003]['mapID'] == 4002, 'the first assignment of a uiMap'
    assert i[9003]['points'] == [(1426, 7000, 2000)] and i[9003]['old']
    assert i[9002]['mapID'] is None


def test_the_item_export(db):
    it = db['items']
    assert it[61001] == {'name': 'Boar Hide Belt', 'q': 2, 'ilvl': 10, 'min': 5, 'classID': 4, 'subclassID': 2,
                         'equipLoc': 'INVTYPE_WAIST', 'icon': '', 'bind': 1, 'classes': 0, 'skill': 0, 'stats': ''}
    assert it[61005]['classes'] == 1 | 2 and it[61006]['equipLoc'] == 'INVTYPE_2HWEAPON'
    assert db['item_names'][61017] == 'Woven Robe'


def test_what_a_refresh_keeps():
    assert att_data.kept('zones/kalimdor/durotar.lua') and att_data.kept('zzOLD/02 - Outdoor Zones/x.lua')
    assert att_data.kept('.config/exports/ItemDB.lua') and att_data.kept('.config/.wago/UiMapAssignment.1.60.1.70170.csv')
    assert not att_data.kept('.config/.wago/Item.1.60.1.70170.csv') and not att_data.kept('holidays/x.lua')
    assert not att_data.kept('zzOLD/10 - Professions/x.lua') and not att_data.kept('00 - Missing DB/MissingItems.txt')


def test_class_race_profession_and_flags(db):
    q = db['quests']
    assert q[72001]['classes'] == 1 << 2 and q[72001]['races'] == 1 << 3 and q[72001]['faction'] == 'A', 'a night elf hunter'
    assert q[72002]['pre'] == [72001] and q[72002]['rewards'] == [61090, 61098]
    assert q[72003]['skill'] == 171 and q[72003]['races'] == 0 and q[72003]['faction'] == 'A', 'ALCHEMY by name'
    assert q[72004]['breadcrumb'] and q[72004]['repeatable'] and q[72004]['races'] == 0, 'all Alliance races are no race limit'
    assert q[72005]['alt'] == [72006] and q[72005]['skill'] == 164 and not q[72005]['breadcrumb']
    assert q[71001]['races'] == 1 | 4, 'Human and Dwarf'
    assert q[72100]['old'] and q[72100]['skill'] == 164 and q[72100]['minLevel'] == 20
    assert q[71001]['skill'] == 0 and not q[71001]['repeatable']
    assert q[72007]['pre'] == [72005, 72006] and q[72007]['sqreq'] == 1, 'any one of the two'
    assert q[72002]['sqreq'] == 0, 'without sourceQuestNumRequired every pre-quest counts'


def test_names_from_comments():
    src = ('q(5, {\t-- A Quest -- note\n\t["qg"] = 7,\t-- Giver <Title>\n\tcrs = {\n\t\t8,\t-- Mob\n\t},\n'
           'i(9),\t-- Sword [Classic] / New Name [CATA+]\nn(10, {\t-- Vendor (PET!)\n')
    names = att_data.comment_names(src)
    assert names[('q', 5)] == ('A Quest', None) and names[('n', 7)] == ('Giver', 'Title')
    assert names[('n', 8)] == ('Mob', None) and names[('i', 9)] == ('Sword', None) and names[('n', 10)] == ('Vendor', None)


# hand-made client tables in the shape of wago.tools downloads (<Table>.<build>.csv), not real data
WAGO = os.path.join(HERE, 'fixtures', 'wago')


def test_a_client_table_by_its_download_name(tmp_path):
    assert os.path.basename(att_data.wago_csv(WAGO, 'AreaTable')) == 'AreaTable.1.60.1.10.csv', 'the newest build, by number'
    assert att_data.wago_csv(WAGO, 'HolidayNames') is None, 'a localised table is another table'
    assert att_data.wago_csv(WAGO, 'Map') is None and att_data.wago_csv(str(tmp_path / 'none'), 'AreaTable') is None
    (tmp_path / 'ItemSparse.csv').write_text('ID\n1\n', encoding='utf-8')
    assert att_data.wago_csv(str(tmp_path), 'ItemSparse').endswith('ItemSparse.csv'), 'the plain name too'
    (tmp_path / 'ItemSparse.1.60.1.70235.csv').write_text('ID\n2\n', encoding='utf-8')
    assert att_data.wago_csv(str(tmp_path), 'ItemSparse').endswith('ItemSparse.1.60.1.70235.csv'), 'a build beats none'
    assert [r['ID'] for r in att_data.wago_rows('ItemSparse', None, str(tmp_path))] == ['2']


def test_instance_ids_from_the_area_table():
    by_area, by_name = att_data.read_area_instances(WAGO)
    assert by_area == {99001: 4777, 99002: 4003, 99003: 4003, 99011: 4100, 99012: 4101, 99020: 4020}, 'no open-world area'
    assert by_name == {'testhalls': 4777, 'testraid': 4003, 'testwing': 4020}, \
        'top areas only, a name on two maps left out, a leading "The" ignored'
    # the uiMap first, then the area, then the name (ATT's own spelling or the client's)
    assert att_data.instance_map_id([9101], 99001, ['Test Halls'], {9101: 4001}, (by_area, by_name)) == 4001
    assert att_data.instance_map_id([], 99003, ['Nothing'], {}, (by_area, by_name)) == 4003
    assert att_data.instance_map_id([], 99010, ['The Test Raid'], {}, (by_area, by_name)) == 4003, 'an outdoor area: by name'
    assert att_data.instance_map_id([], None, ['Westfall'], {}, (by_area, by_name)) is None


def test_load_takes_the_area_table_of_the_download():
    db = att_data.load(FIXTURE, items=False, wago=WAGO)
    i = db['instances']
    assert i[9001]['mapID'] == 4001, 'UiMapAssignment wins over the area'
    assert i[9002]['mapID'] == 4003, 'an instance without uiMap and area: by its name'
    assert i[9003]['mapID'] == 4002


def test_a_refresh_keeps_the_area_and_tuning_tables():
    assert att_data.kept('.config/.wago/AreaTable.1.60.1.70170.csv') and att_data.kept('.config/.wago/ContentTuning.1.60.1.70170.csv')
    assert not att_data.kept('.config/.wago/AreaTableX.1.60.1.70170.csv')


def test_expansion_features_quest_givers_of_a_header_and_quest_maps():
    db = att_data.load(FIXTURE, items=False, dirs=('expansion features',))
    assert db['errors'] == {} and db['files'] == ['expansion features/library books.lua']
    q = db['quests']
    assert q[78501]['name'] == 'A Dusty Tome' and q[78501]['givers'] == [81501, 81502], 'aqd and hqd give every quest below'
    assert q[78501]['startItem'] and q[78501]['rewards'] == [69500] and q[78501]['maps'] == [1426]
    assert q[78502]['faction'] == 'A' and q[78502]['maps'] == [1455, 1426], 'a map constant or a number'
    assert q[78503]['pre'] == [78501, 78502] and q[78503]['sqreq'] == 2 and q[78503]['minLevel'] == 20
    n = db['npcs']
    assert n[81501]['name'] == 'Fixture Librarian' and n[81501]['title'] == 'Librarian'
    assert n[81501]['faction'] == 'A' and n[81501]['points'] == [(1455, 4900, 8640)]
    assert n[81502]['faction'] == 'H' and n[81502]['points'] == [(1426, 7360, 3300)]


def test_the_default_folders_leave_expansion_features_out(db):
    assert not any(f.startswith('expansion features/') for f in db['files'])
    assert 78501 not in db['quests']
    assert att_data.kept('expansion features/library books.lua')


def test_map_constants_of_the_newer_file_fill_the_shared_map():
    # since October 2026 the file keeps its constants in a local _MAP and copies them into MAP
    src = ('local _MAP = setmetatable({ TEST_TOWN = 1453; }, { __index = function(t, k) error("x") end });\n'
           'for k, v in pairs(_MAP) do _G[k] = v; MAP[k] = v end\n')
    lua, S = att_data.sandbox()
    S.maps(src)
    assert dict(S.mapNames()) == {'TEST_TOWN': 1453}
