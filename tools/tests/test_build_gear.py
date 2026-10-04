"""The pure parts of tools/build_gear.py: QuestieDB's CBOR rows, source interning, factions,
wowsrc pages and the join with the scan."""
import base64
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import build_gear  # noqa: E402


def test_cbor_map_with_text_and_numbers():
    # {1: "Worn Shortsword", 9: 2, 10: 1, 12: 2, 13: 7}, the way QuestieDB stores an item row
    raw = base64.b64decode('pQFPV29ybiBTaG9ydHN3b3JkCQIKAQwCDQc=')
    assert build_gear._cbor(raw)[0] == {1: 'Worn Shortsword', 9: 2, 10: 1, 12: 2, 13: 7}


def test_cbor_nested_arrays_and_negative_numbers():
    # [[820], -1, [1, 2]]
    raw = bytes([0x83, 0x81, 0x19, 0x03, 0x34, 0x20, 0x82, 0x01, 0x02])
    assert build_gear._cbor(raw)[0] == [[820], -1, [1, 2]]


def test_sources_are_interned_and_trailing_nones_dropped():
    s = build_gear.Sources()
    a = s.add('D', 'Deadmines', 'VanCleef', None, None)
    b = s.add('D', 'Deadmines', 'VanCleef')
    assert a == b == 1 and s.rows == [('D', 'Deadmines', 'VanCleef')]
    assert s.add('Q', 'x', 1, 0, None, None, 5) == 2 and s.rows[1] == ('Q', 'x', 1, 0, None, None, 5)


def test_faction_from_race_bits():
    assert build_gear.faction_of(77) == 'A'
    assert build_gear.faction_of(178) == 'H'
    assert build_gear.faction_of(0) is None and build_gear.faction_of(None) is None
    assert build_gear.faction_of(77 | 2) is None


def test_pvp_vendors():
    assert build_gear.is_pvp_vendor({9: 2918, 14: 'Food and Drink'})
    assert build_gear.is_pvp_vendor({9: 1519, 14: 'Accessories Quartermaster'})
    assert not build_gear.is_pvp_vendor({9: 45, 14: 'League of Arathor Supply Officer'})


def test_parse_wowsrc_page():
    page = ('<h1 class="ph__h">The Deadmines</h1>'
            '<section class="bc" id="vancleef" x><h2 class="bc__h">Edwin VanCleef</h2><ul>'
            '<li data-tip="{&#34;n&#34;:&#34;Cruel Barb&#34;,&#34;l&#34;:19,&#34;d&#34;:&#34;12.5%&#34;,&#34;nw&#34;:false}"></li>'
            '</ul></section>')
    d = build_gear.parse_wowsrc(page, 'the-deadmines')
    assert d == {'slug': 'the-deadmines', 'name': 'The Deadmines',
                 'bosses': [{'name': 'Edwin VanCleef', 'items': [{'n': 'Cruel Barb', 'l': 19, 'd': '12.5%', 'nw': False}]}]}


def scan_item(name, loc='INVTYPE_HEAD', q=2, lvl=20, cls=4):
    return {'name': name, 'q': q, 'ilvl': lvl + 5, 'min': lvl, 'classID': cls, 'subclassID': 2,
            'equipLoc': loc, 'icon': '', 'bind': 1}


def test_join_keeps_wearable_scanned_items_and_quest_levels():
    questie = {
        'Item': {
            10: {1: 'Quest Helm', 6: [500]},
            11: {1: 'Not Scanned', 6: [500], 12: 4},
            12: {1: 'Some Bag', 6: [500]},
            13: {1: 'Vendor White', 14: [900]},
            14: {1: 'Cruel Barb'},
        },
        'Quest': {500: {1: 'The Quest', 4: 24, 5: 26, 6: 77, 17: 40}},
        'Npc': {900: {1: 'Smith', 9: 40, 13: 'A', 14: 'Weaponsmith'}},
    }
    zones = ({40: 'Westfall'}, {}, {40: 1436})
    scan = {10: scan_item('Quest Helm', lvl=20), 12: scan_item('Some Bag', loc='INVTYPE_BAG'),
            13: scan_item('Vendor White', q=1), 14: scan_item('Cruel Barb', loc='INVTYPE_WEAPON', cls=2)}
    wowsrc = {'dungeons': [{'name': 'The Deadmines', 'bosses': [{'name': 'Edwin VanCleef', 'items': [{'n': 'Cruel Barb', 'd': '12%'}]}]}]}
    collected = {10: ['Auktionshaus']}
    src, keep, zone_rows, stats, dropped, unmatched, missing = build_gear.build(
        scan, collected, questie, zones, ({}, {}), [], {}, wowsrc)
    assert set(keep) == {10, 14}
    assert dropped['not scanned'] == 1 and dropped['not gear'] == 1 and dropped['quality'] == 1
    it, nums, level, mask, speed, line = keep[10]
    recs = [src.rows[n - 1] for n in nums]
    assert ('Q', 'The Quest', 26, 24, 'A', 1436, 500, 0) in recs and ('A',) in recs
    assert level == 20, 'auction house is a second source, so the item level stands'
    assert zone_rows[1436] == 'Westfall'
    _, nums, _, _, _, _ = keep[14]
    assert src.rows[nums[0] - 1] == ('D', 'The Deadmines', 'Edwin VanCleef', '12%')
    assert unmatched == []
    assert missing == [11], 'the unscanned quest reward is asked for again' 


def test_quest_only_item_counts_from_the_quest_level():
    questie = {'Item': {10: {1: 'Helm', 6: [500]}, 11: {1: 'Gun', 6: [501]}},
               'Quest': {500: {1: 'Q', 4: 24, 5: 26}, 501: {1: 'Big Game Hunter', 4: 28, 5: 43}}, 'Npc': {}}
    scan = {10: scan_item('Helm', lvl=20), 11: scan_item('Gun', lvl=28)}
    _, keep, *_ = build_gear.build(scan, {}, questie, ({}, {}, {}), ({}, {}), [], {}, {})
    assert keep[10][2] == 24, 'can be taken at 24'
    assert keep[11][2] == 39, 'an elite level 43 quest counts from 39, not from 28'


def test_rare_dungeon_drops_count_as_world_drops():
    assert build_gear.drop_chance('12.5%') == 12.5 and build_gear.drop_chance('<0.1%') == 0.05
    assert build_gear.drop_chance(None) == 100.0
    questie = {'Item': {12: {1: 'Avenger Armor'}}, 'Quest': {}, 'Npc': {}}
    wowsrc = {'dungeons': [{'name': 'Razorfen Kraul', 'bosses': [{'name': 'Trash', 'items': [{'n': 'Avenger Armor', 'd': '<0.1%'}]}]}]}
    src, keep, *_ = build_gear.build({12: scan_item('Avenger Armor')}, {}, questie, ({}, {}, {}), ({}, {}), [], {}, wowsrc)
    assert src.rows[keep[12][1][0] - 1][:2] == ('W', 'Razorfen Kraul: Trash <0.1%')


def test_drop_chance_page_wins_and_trash_gives_way():
    rows = [('D', 'Scarlet Monastery', 'Trash'), ('D', 'Scarlet Monastery - Armory', 'Herod', '18%'),
            ('D', 'Deadmines', 'Trash'), ('D', 'The Deadmines', 'Edwin VanCleef'), ('D', 'Deadmines', 'Edwin VanCleef'),
            ('Q', 'x', 1, 0), ('D', 'Stratholme', 'Trash', '1%')]
    keep = build_gear.merge_dungeon_sources([1, 2, 3, 4, 5, 6, 7], rows)
    assert keep == [2, 4, 6, 7], keep


def test_pick_id_prefers_scanned_and_forever_remakes():
    scan = {100: {}, 270100: {}}
    assert build_gear.pick_id({100, 270100}, scan) == 100
    assert build_gear.pick_id({100, 270100}, scan, new_in_forever=True) == 270100
    assert build_gear.pick_id({55}, scan) is None


def test_itemsparse_keeps_class_limits_and_weapon_speed(tmp_path):
    csv_path = tmp_path / 'ItemSparse.csv'
    csv_path.write_text('\n'.join(['ID,AllowableClass,ItemDelay,RequiredSkill,RequiredSkillRank', '1,-1,2600,0,0',
                                   '2,2,0,0,0', '3,1535,0,202,280', '4,1024,3000,0,0']) + '\n', encoding='utf-8')
    scan = {1: scan_item('Sword', loc='INVTYPE_WEAPON', cls=2), 2: scan_item('Libram Helm'),
            3: scan_item('Any'), 4: scan_item('Staff', loc='INVTYPE_2HWEAPON', cls=2)}
    out = tmp_path / 'is.json'
    build_gear.refresh_itemsparse(str(csv_path), scan, path=str(out))
    import json
    data = json.loads(out.read_text(encoding='utf-8'))
    assert data['classes'] == {'2': 2, '4': 1024}
    assert data['delay'] == {'1': 2600, '4': 3000}
    assert data['skill'] == {'3': [202, 280]}
    questie = {'Item': {4: {1: 'Staff', 6: [500]}}, 'Quest': {500: {1: 'Q', 4: 1, 5: 2}}, 'Npc': {}}
    _, keep, *_ = build_gear.build(scan, {}, questie, ({}, {}, {}), ({}, {}), [], {}, {}, data)
    assert keep[4][3:] == (1024, 3.0, 0)
    questie['Item'][3] = {1: 'Goggles', 6: [500]}
    _, keep, *_ = build_gear.build(scan, {}, questie, ({}, {}, {}), ({}, {}), [], {}, {}, data)
    assert keep[3][2] == 56 and keep[3][5] == 202, 'engineering 280 is reached around level 56'


def test_scanned_stats_keep_what_the_planner_scores():
    keys = build_gear.scored_stat_keys()
    assert {'STRENGTH', 'RESISTANCE0_NAME', 'DAMAGE_PER_SECOND', 'SPELL_POWER', 'HIT_RATING'} <= keys
    text = 'FIRE_RESISTANCE_SHORT=16;RESISTANCE0_NAME=62;RESISTANCE2_NAME=16;SPELL_POWER_SHORT=19;ATTACK_POWER_VS_BEAST_SHORT=5'
    assert build_gear.compact_stats(text, keys) == 'RESISTANCE0_NAME=62;SPELL_POWER=19'
    assert build_gear.compact_stats('', keys) == ''


def test_collector_notes_old_and_new():
    p = build_gear.build_scan.parse_note
    assert p('Drop: Wolf') == {'kind': 'drop', 'name': 'Wolf', 'id': None, 'level': None, 'place': None, 'itype': None, 'instance': None}
    n = p('Drop: ? [639] @Die Todesminen #party:36')
    assert n['name'] is None and n['id'] == 639 and n['place'] == 'Die Todesminen' and n['itype'] == 'party' and n['instance'] == 36
    n = p('Quest: Die Fackel [4711] L23')
    assert n['kind'] == 'quest' and n['name'] == 'Die Fackel' and n['id'] == 4711 and n['level'] == 23
    assert p('Haendler: Griselda [123] @Wald von Elwynn')['place'] == 'Wald von Elwynn'
    assert p('Auktionshaus') == {'kind': 'ah'} and p('something else') is None
    assert build_gear.build_scan.note_label('Haendler: Griselda [123] @Wald von Elwynn') == 'Haendler: Griselda (Wald von Elwynn)'


def test_collector_drops_become_dungeon_world_and_quest_sources():
    questie = {'Item': {}, 'Quest': {500: {1: 'The Quest', 4: 24, 5: 26, 6: 77}},
               'Npc': {639: {1: 'Edwin VanCleef', 4: 21, 5: 21, 9: 1581}}}
    zones = ({1581: 'The Deadmines'}, {1581: 'The Deadmines'}, {}, {36: 1581})
    scan = {i: scan_item(f'I{i}', q=3) for i in (1, 2, 3, 4, 5)}
    collected = {
        1: ['Drop: ? [639] @Die Todesminen #party:36'],
        2: ['Drop: Wolf [299] @Wald von Elwynn'],
        3: ['Quest: Die Fackel [500] L23'],
        4: ['Quest: Neue Quest [99999] L31'],
        5: ['Drop: Ragnaros [11502] @Geschmolzener Kern #raid:409'],
    }
    src, keep, zone_rows, *_ = build_gear.build(scan, collected, questie, zones, ({}, {}), [], {}, {})
    rec = lambda i: src.rows[keep[i][1][0] - 1]
    assert rec(1) == ('D', 'The Deadmines', 'Edwin VanCleef')
    w = rec(2)
    assert w[:4] == ('W', 'Wolf', 0, 0) and zone_rows[w[4]] == 'Wald von Elwynn'
    assert rec(3) == ('Q', 'The Quest', 26, 24, 'A', None, 500, 0)
    assert rec(4) == ('Q', 'Neue Quest', 31, 0, None, None, 99999)
    assert 5 not in keep, 'raid drops stay out'


def test_test_items_stay_out():
    assert 8350 in build_gear.TEST_ITEMS
    questie = {'Item': {8350: {1: 'The 1 Ring', 6: [500]}}, 'Quest': {500: {1: 'Q', 4: 1, 5: 2}}, 'Npc': {}}
    scan = {8350: scan_item('Der Eine Ring', loc='INVTYPE_FINGER')}
    _, keep, _, _, dropped, *_ = build_gear.build(scan, {}, questie, ({}, {}, {}), ({}, {}), [], {}, {})
    assert 8350 not in keep and dropped['junk'] == 1
