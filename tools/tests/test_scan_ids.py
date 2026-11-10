"""The scans by id on the N100 (D-104): the quest and NPC parts of the scan archive (per language, the
file wins, empty answers as ranges), the marker the addon trims them by (and the trim itself in the
addon's runtime), the lists and names of tools/build_scan_lists.py, and the builders using the scans
(quest levels and types, boss NPCs by the encounter's name in the scan's language). An empty part
changes nothing in the generated data."""
import copy
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'tests'))
import build_scan_archive as sa  # noqa: E402
import build_scan_lists as sl  # noqa: E402

REAL_ARCHIVE = sa.ARCHIVE


def sv(quests=None, npcs=None):
    scan = {'items': {}, 'sources': {}}
    if quests is not None:
        scan['quests'] = quests
    if npcs is not None:
        scan['npcs'] = npcs
    return {'scan': scan}


DE = sv(quests={'loc': 'deDE', 'next': 4, 'list': {1: 'Die Kobolde\t12\t0\tG\t3', 2: 'Im Verlies\t24\t26\tD'}, 'none': '3,7-9'},
        npcs={'loc': 'deDE', 'a': 3, 'list': {644: "Rhahk'Zor", 261306: 'Faldrim Ambossmar\t<Thane>'}, 'empty': '100-120,130'})
EN = sv(quests={'loc': 'enUS', 'list': {1: 'The Kobolds\t12'}}, npcs={'loc': 'enUS', 'list': {644: "Rhahk'Zor"}})


# ---------------------------------------------------------------- the archive
def test_the_parts_are_kept_per_language_and_the_file_wins():
    arch = sa.empty()
    st = sa.absorb(arch, DE)
    assert st['quests'] == 2 and st['npcs'] == 2
    sa.absorb(arch, EN)
    assert arch['quests']['deDE'][1] == 'Die Kobolde\t12\t0\tG\t3'
    assert arch['quests']['enUS'][1] == 'The Kobolds\t12', 'an English title does not replace the German one'
    assert arch['quest_none']['deDE'] == [[3, 3], [7, 9]]
    assert arch['npc_empty']['deDE'] == [[100, 120], [130, 130]]
    # a later file: a changed line wins, an id found later leaves the empty ranges
    later = sv(quests={'loc': 'deDE', 'list': {2: 'Im Verlies\t24\t26\tD\t5'}, 'none': ''},
               npcs={'loc': 'deDE', 'list': {110: 'Gefunden'}, 'empty': '200'})
    sa.absorb(arch, later)
    assert arch['quests']['deDE'][2] == 'Im Verlies\t24\t26\tD\t5' and arch['quests']['deDE'][1]
    assert arch['npc_empty']['deDE'] == [[100, 109], [111, 120], [130, 130], [200, 200]]
    # bad input is skipped
    sa.absorb(arch, sv(quests={'loc': 'xxXX', 'list': {5: 'x'}}, npcs={'loc': 'deDE', 'list': {0: 'x', 7: '', 8: 5}}))
    assert 'xxXX' not in arch['quests'] and 7 not in arch['npcs']['deDE'] and 8 not in arch['npcs']['deDE']


def test_the_archive_file_round_trips_and_has_no_parts_without_scans(tmp_path):
    arch = sa.empty()
    arch['items'][5] = 'Item\t1'
    plain = sa.text(arch)
    assert '"quests"' not in plain and '"npcs"' not in plain, 'an archive without the scans stays as it was'
    sa.absorb(arch, DE)
    sa.absorb(arch, EN)
    path = tmp_path / 'a.json'
    sa.save(str(path), arch)
    back = sa.load(str(path))
    assert back['quests'] == arch['quests'] and back['npcs'] == arch['npcs']
    assert back['quest_none'] == arch['quest_none'] and back['npc_empty'] == arch['npc_empty']
    assert sa.text(back) == sa.text(arch)


def test_id_scans_for_the_builders(tmp_path):
    path = tmp_path / 'a.json'
    arch = sa.empty()
    sa.absorb(arch, EN)
    sa.save(str(path), arch)
    got = sa.id_scans(str(path), [DE])
    assert got['quests']['deDE'][2] == {'title': 'Im Verlies', 'level': 24, 'qlevel': 26, 'tag': 'D', 'group': 0, 'obj': '',
                                        'rewards': [], 'choices': [], 'money': 0, 'xp': 0}, 'an older line: no rewards'
    # a line of layout 2 (2.74.1): rewards with their count, choices, money, XP after the objectives
    assert sa.quest_fields('Eins\t5\t0\t\t0\t\t2001,2002*5\t3001,3002\t150\t400') == {
        'title': 'Eins', 'level': 5, 'qlevel': 0, 'tag': '', 'group': 0, 'obj': '', 'rewards': [(2001, 1), (2002, 5)],
        'choices': [3001, 3002], 'money': 150, 'xp': 400}
    assert sa.quest_fields('Zwei\t7\t0\t\t0\t\t\t3003')['choices'] == [3003]
    assert sa.reward_items('x,12*0,0,99999999,7*2') == [(12, 1), (7, 2)], 'bad parts left out, a count at least 1'
    assert got['quests']['enUS'][1]['title'] == 'The Kobolds'
    assert got['npcs']['deDE'][261306] == {'name': 'Faldrim Ambossmar', 'sub': '<Thane>', 'rank': '', 'kind': ''}
    # a line of the layout since 2.74.1: the title, the rank of the level line and the kind
    assert sa.npc_fields('Flintauge\tRagefire-Häuptling\tElite\tHumanoid') == {
        'name': 'Flintauge', 'sub': 'Ragefire-Häuptling', 'rank': 'Elite', 'kind': 'Humanoid'}
    assert sa.npc_fields('Gill\t\tRar') == {'name': 'Gill', 'sub': '', 'rank': 'Rar', 'kind': ''}
    assert 115 in got['npc_empty']['deDE']
    # the real archive has no scan by id yet: nothing for the builders
    real = sa.id_scans(REAL_ARCHIVE, [])
    assert real == {'quests': {}, 'npcs': {}, 'npc_empty': {}}


# ---------------------------------------------------------------- the marker and the trim
def test_the_marker_lists_the_parts_only_when_there_are_any():
    arch = sa.empty()
    arch['items'][5] = 'Item\t1'
    before = sa.marker_text(arch)
    assert 'QL=' not in before and 'NE=' not in before
    sa.absorb(arch, DE)
    m = sa.id_marker(arch)
    assert set(m) == {'QL', 'QE', 'NL', 'NE'}
    assert m['QE'] == {'deDE': '3,7-9'} and m['NE'] == {'deDE': '100-120,130'}
    assert m['QL']['deDE'].startswith('1.' + sa.b36(sa.lua_hash('Die Kobolde\t12\t0\tG\t3')))
    text = sa.marker_text(arch)
    assert 'QL={deDE="' in text and text != before
    # the stamp changes with the parts, so the addon trims again after a build that added some
    assert sa.marker_parts(arch)[3] != sa.marker_parts(sa.empty())[3]


def test_the_addon_trims_what_the_marker_lists():
    pytest.importorskip('lupa')
    import run
    arch = sa.empty()
    sa.absorb(arch, DE)
    marker = sa.marker_text(arch)
    lua = run.fresh('')
    lua.globals().MARKER = marker
    lua.execute('''
        assert(loadstring(MARKER))("Amisia", NS)
        AmisiaDB.scan = { items = {}, sources = {}, retry = {},
            quests = { loc = "deDE", next = 4, list = { [1] = "Die Kobolde\\t12\\t0\\tG\\t3", [2] = "Im Verlies neu\\t24", [5] = "Neu\\t3" }, none = "3,7-9,11" },
            npcs = { loc = "deDE", a = 3, list = { [644] = "Rhahk'Zor", [99] = "Neu" }, empty = "100-125,130" } }
        assert(NS.ScanTrimNow())
    ''')
    q = lua.eval('AmisiaDB.scan.quests')
    n = lua.eval('AmisiaDB.scan.npcs')
    assert sorted(q.list.keys()) == [2, 5] and q.none == '11' and q.next == 4
    assert sorted(n.list.keys()) == [99] and n.empty == '121-125'


# ---------------------------------------------------------------- the lists and names
def test_phase_b_ranges_are_clusters_of_forever_ids():
    ids = [644, 11517, 205729, 245000, 245600, 246400, 250000]
    assert sl.ranges_b(ids, low=200000, gap=1000, pad=100) == [[205629, 205829], [244900, 246500], [249900, 250100]]
    assert sl.ranges_b([200050], low=200000, gap=1000, pad=100) == [[200000, 200150]]
    assert sl.ranges_b([1, 2, 3]) == []


def test_the_lists_file_expands_in_the_addon(tmp_path):
    pytest.importorskip('lupa')
    import run
    qids = [1, 2, 3, 10, 11, 500]
    npcs = [644, 645, 261306]
    text = sl.lists_text('1.60.1.70888', qids, npcs, [[260000, 260010]])
    lua = run.fresh('')
    lua.globals().LISTS = text
    lua.execute('assert(loadstring(LISTS))("Amisia", NS); NS.ScanById.Reset()')
    assert list(lua.eval('NS.ScanById.List("Q")').values()) == qids
    assert list(lua.eval('NS.ScanById.List("NA")').values()) == npcs
    assert lua.eval('select(2, NS.ScanById.RangesB())') == 11
    assert lua.eval('NS.DataSize("SCAN_LISTS")') == len(qids) + len(npcs)


def test_quest_ids_come_from_questv2(tmp_path):
    (tmp_path / 'QuestV2.1.60.1.70888.csv').write_text('ID,UniqueBitFlag,UiQuestDetailsThemeID\n1,2,0\n5,3,0\n6,4,0\n', encoding='utf-8')
    assert sl.quest_ids(str(tmp_path)) == ('1.60.1.70888', [1, 5, 6])
    assert sl.quest_ids(str(tmp_path / 'none')) == (None, [])


def test_names_leave_english_out_and_load_in_the_addon():
    pytest.importorskip('lupa')
    import run
    scans = sa.id_scans(None, [DE, EN])
    parts = sl.names_parts(scans)
    assert set(parts) == {'deDE'}
    assert parts['deDE']['Q'] == {1: 'Die Kobolde', 2: 'Im Verlies'}
    assert parts['deDE']['N'][261306] == 'Faldrim Ambossmar'
    lua = run.fresh('')
    lua.globals().NAMES = sl.names_text(parts)
    lua.execute('assert(loadstring(NAMES))("Amisia", NS)')
    assert lua.eval('NS.ScannedQuestTitle(2)') == 'Im Verlies'
    assert lua.eval('NS.ScannedNpcName(261306)') == 'Faldrim Ambossmar'
    assert lua.eval('NS.ScannedNpcName(1)') is None
    # an English client gets nothing from it
    lua.execute('STUB.locale = "enUS"')
    assert lua.eval('NS.ScannedQuestTitle(2)') is None
    # without a scan: no names
    assert sl.names_parts(sa.id_scans(None, [])) == {}
    assert 'L={\n}' in sl.names_text({}) or 'L={}' in sl.names_text({})


def test_the_committed_lists_and_names_are_current():
    """Data/ScanLists.lua and ScanNames.lua are what the build writes (python3 tools/build.py data)."""
    import client_tables
    build, qids = sl.quest_ids(client_tables.default_dir())
    if not qids:
        pytest.skip('no QuestV2 on this machine')
    with open(sl.LISTS, encoding='utf-8') as fh:
        assert fh.read() == sl.lists_text(build, qids, sorted(sl.data_npcs()), sl.ranges_b(sorted(sl.data_npcs()))), \
            'rebuild: python3 tools/build_scan_lists.py'
    with open(sl.NAMES, encoding='utf-8') as fh:
        assert fh.read() == sl.names_text(sl.names_parts(sa.id_scans(REAL_ARCHIVE, []))), 'rebuild: python3 tools/build_scan_lists.py'


def test_phase_a_holds_the_npcs_of_the_data():
    found = sl.data_npcs()
    assert 644 in found and 'dungeon boss' in found[644]       # Rhahk'Zor, the Deadmines
    assert len(found) > 1500
    assert any('quest giver' in s for s in found.values()) and any('rare' in s for s in found.values())


# ---------------------------------------------------------------- the builders using the scans
def test_dungeon_quests_take_the_scanned_level_where_none_is_known():
    import build_dungeonquests as bd
    data = {'quests': {1: {'level': 0}, 2: {'level': 30}, 3: {'level': 0}}}
    scans = sa.id_scans(None, [DE])
    assert bd.apply_scanned(data, scans) == 1
    assert data['quests'][1]['level'] == 12 and data['quests'][2]['level'] == 30 and data['quests'][3]['level'] == 0
    # the quest level wins over the difficulty level where the client gave one
    data = {'quests': {2: {'level': 0}}}
    bd.apply_scanned(data, scans)
    assert data['quests'][2]['level'] == 26
    # an empty scan changes nothing
    before = {'quests': {1: {'level': 0}}}
    data = copy.deepcopy(before)
    assert bd.apply_scanned(data, sa.id_scans(None, [])) == 0 and data == before


def test_gear_quest_sources_take_the_scanned_level_and_type():
    import build_gear as bg
    src = bg.Sources()
    a = src.add('Q', 'The Kobolds', 0, 10, None, 12, 1)
    b = src.add('Q', 'Other', 18, 15, None, 12, 2)
    c = src.add('D', 'Deadmines', 'Boss', None, 36, 1581)
    info = bg.scan_quest_info(sa.id_scans(None, [DE]))
    assert info == {1: (12, 'G'), 2: (26, 'D')}
    assert bg.apply_quest_scan(src, info) == 1
    assert src.rows[a - 1][2] == 12 and src.rows[b - 1][2] == 18 and src.rows[c - 1][0] == 'D'
    assert bg.scan_quest_tags({2: 'R'}, info) == {2: 'R', 1: 'G'}, 'a type the quest log taught stays'
    # empty
    src2 = bg.Sources()
    src2.add('Q', 'X', 0, 1, None, 1, 9)
    assert bg.apply_quest_scan(src2, bg.scan_quest_info(sa.id_scans(None, []))) == 0 and src2.rows[0][2] == 0
    assert bg.scan_quest_tags({}, {}) == {}


def test_boss_npcs_by_the_encounter_name_in_the_scan_language(tmp_path):
    import build_dungeons as bdn
    (tmp_path / 'DungeonEncounter.1.60.1.70888.deDE.csv').write_text(
        'Name_lang,ID,MapID,DifficultyID,OrderIndex\n"Aufseher Wrex",3403,2994,0,0\n"König Op",3504,3001,0,6000\n', encoding='utf-8')
    names = bdn.encounter_names([str(tmp_path / 'none'), str(tmp_path)], 'deDE')
    assert names == {3403: 'Aufseher Wrex', 3504: 'König Op'}
    assert bdn.encounter_names([str(tmp_path)], 'frFR') == {}
    dungeons = {
        'alcaz': {'order': ['Overseer Wrex', 'Warden'], 'enc': [3403, 3404], 'npcs': [0, 262000]},
        'terrace': {'order': ['King Op'], 'enc': [3504], 'npcs': [0]},
        'scholo': {'order': ['Lady Illucia Barov'], 'enc': [2806], 'npcs': [0]},
    }
    scans = {'npcs': {'deDE': {261990: {'name': 'Aufseher Wrex', 'sub': ''}, 150000: {'name': 'Aufseher Wrex', 'sub': ''},
                               263000: {'name': 'könig op', 'sub': ''}},
                      'enUS': {10505: {'name': 'Lady Illucia Barov', 'sub': ''}}}}
    taken = bdn.boss_npcs_from_scan(dungeons, scans, {'deDE': names})
    assert dungeons['alcaz']['npcs'] == [261990, 262000], 'of two with the name the one near the other bosses'
    assert dungeons['terrace']['npcs'] == [263000], 'case and blanks aside'
    assert dungeons['scholo']['npcs'] == [10505], 'an English scan matches the order\'s own name'
    assert len(taken) == 3 and dungeons['alcaz']['npcs_scan'] == ['Overseer Wrex']
    # without the German encounter names a German scan cannot match; a known NPC is never replaced
    d2 = {'alcaz': {'order': ['Overseer Wrex', 'Warden'], 'enc': [3403, 3404], 'npcs': [0, 262000]}}
    assert bdn.boss_npcs_from_scan(d2, {'npcs': {'deDE': scans['npcs']['deDE']}}, {}) == []
    assert d2['alcaz']['npcs'] == [0, 262000]
    d3 = {'x': {'order': ['A'], 'enc': [1], 'npcs': [5]}}
    assert bdn.boss_npcs_from_scan(d3, {'npcs': {'enUS': {6: {'name': 'A', 'sub': ''}}}}, {}) == [] and d3['x']['npcs'] == [5]
    # an empty scan changes nothing
    d4 = copy.deepcopy(dungeons)
    assert bdn.boss_npcs_from_scan(d4, sa.id_scans(None, []), {}) == [] and d4 == dungeons
