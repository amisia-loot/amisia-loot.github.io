"""The pure parts of tools/build_gear.py: source interning, wowsrc pages, the item master (scan over
the last build over the item export), places of dungeons, and the join of AllTheThings' data (as
tools/att_data.py hands it over) and the collector with the items. No QuestieDB."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import att_data  # noqa: E402
import build_gear  # noqa: E402
import lua_data  # noqa: E402

FIXTURE = os.path.join(HERE, 'fixtures', 'att')


def scan_item(name, loc='INVTYPE_HEAD', q=2, lvl=20, cls=4):
    return {'name': name, 'q': q, 'ilvl': lvl + 5, 'min': lvl, 'classID': cls, 'subclassID': 2,
            'equipLoc': loc, 'icon': '', 'bind': 1}


def quest(name, minlvl, faction='', zone=1436, points=(), rewards=(), inst=None, classes=0, inside=False):
    return {'name': name, 'minLevel': minlvl, 'faction': faction, 'classes': classes, 'givers': [], 'giver': None,
            'points': list(points), 'objects': [], 'startItem': False, 'inside': inside, 'zone': zone, 'inst': inst,
            'pre': [], 'alt': [], 'rewards': list(rewards), 'file': 'x', 'old': False}


def npc(name, kinds, zone=1436, faction='', title=None, inst=None, points=()):
    return {'name': name, 'title': title, 'points': list(points), 'zone': zone, 'faction': faction,
            'kinds': set(kinds), 'inst': inst, 'old': False}


def att(**kw):
    db = att_data.empty_db()
    db.update(kw)
    return db


DEADMINES = {63: {'name': 'Deadmines', 'area': 1581, 'maps': [291], 'points': [(1436, 4220, 8260)], 'file': 'd',
                  'stem': 'the deadmines', 'old': False, 'mapID': 36}}
FACTS = [{'key': 'deadmines', 'name': 'The Deadmines', 'kind': 'party'},
         {'key': 'sm', 'name': 'Scarlet Monastery', 'kind': 'party', 'aliases': ['Scarlet Monastery - Armory']},
         {'key': 'onyxia', 'name': "Onyxia's Lair", 'kind': 'raid', 'inst': 249, 'area': 2159}]


def test_sources_are_interned_and_trailing_nones_dropped():
    s = build_gear.Sources()
    a = s.add('D', 'Deadmines', 'VanCleef', None, None)
    b = s.add('D', 'Deadmines', 'VanCleef')
    assert a == b == 1 and s.rows == [('D', 'Deadmines', 'VanCleef')]
    assert s.add('Q', 'x', 1, 0, None, None, 5) == 2 and s.rows[1] == ('Q', 'x', 1, 0, None, None, 5)


def test_parse_wowsrc_page():
    page = ('<h1 class="ph__h">The Deadmines</h1>'
            '<section class="bc" id="vancleef" x><h2 class="bc__h">Edwin VanCleef</h2><ul>'
            '<li data-tip="{&#34;n&#34;:&#34;Cruel Barb&#34;,&#34;l&#34;:19,&#34;d&#34;:&#34;12.5%&#34;,&#34;nw&#34;:false}"></li>'
            '</ul></section>')
    d = build_gear.parse_wowsrc(page, 'the-deadmines')
    assert d == {'slug': 'the-deadmines', 'name': 'The Deadmines',
                 'bosses': [{'name': 'Edwin VanCleef', 'items': [{'n': 'Cruel Barb', 'l': 19, 'd': '12.5%', 'nw': False}]}]}


def test_no_questie_left():
    with open(build_gear.__file__, encoding='utf-8') as fh:
        src = fh.read()
    assert 'questie' not in src.lower(), 'no data of that unlicensed database'
    assert not hasattr(build_gear, 'load_questie')


def test_join_keeps_wearable_items_and_quest_levels():
    a = att(quests={500: quest('The Quest', 24, 'A', 1436, [(1436, 5000, 5000)], [10, 11, 12])},
            items={10: dict(scan_item('Quest Helm', lvl=0), min=0), 12: scan_item('Some Bag', loc='INVTYPE_BAG')},
            maps={'WESTFALL': 1436})
    scan = {10: scan_item('Quest Helm', lvl=20), 13: scan_item('Cruel Barb', loc='INVTYPE_WEAPON', cls=2)}
    wowsrc = {'dungeons': [{'name': 'The Deadmines', 'bosses': [{'name': 'Edwin VanCleef', 'items': [{'n': 'Cruel Barb', 'd': '12%'}]}]}]}
    a['item_names'] = {13: 'Cruel Barb'}
    collected = {10: ['Auktionshaus']}
    src, keep, zone_rows, stats, dropped, unmatched, missing = build_gear.build(scan, collected, a, wowsrc=wowsrc)
    assert set(keep) == {10, 13}
    assert dropped['unknown item'] == 1 and dropped['not gear'] == 1
    it, nums, level, mask, speed, line = keep[10]
    recs = [src.rows[n - 1] for n in nums]
    assert ('Q', 'The Quest', 0, 24, 'A', 1436, 500, 0) in recs and ('A',) in recs, 'quest level unknown (0)'
    assert level == 20, 'the auction house is a second source, so the item level stands'
    assert zone_rows[1436] == 'Westfall'
    assert src.rows[keep[13][1][0] - 1] == ('D', 'The Deadmines', 'Edwin VanCleef', '12%')
    assert unmatched == [] and missing == [11], 'an item no table knows is asked for again'


def test_quest_only_item_counts_from_the_minimum_level():
    a = att(quests={500: quest('Q', 24, rewards=[10]), 501: quest('Big Game Hunter', 39, rewards=[11])})
    scan = {10: scan_item('Helm', lvl=20), 11: scan_item('Gun', lvl=28)}
    _, keep, *_ = build_gear.build(scan, {}, a)
    assert keep[10][2] == 24, 'can be taken at 24'
    assert keep[11][2] == 39


def test_item_master_scan_over_last_build_over_export():
    export = {1: dict(scan_item('Belt', lvl=5), classes=3, skill=0)}
    prev = {1: dict(scan_item('', lvl=24), classes=0), 2: dict(scan_item('', lvl=30), classes=0)}
    m = build_gear.item_master({}, export, prev, {2: 'Old Boots'})
    assert m[1]['min'] == 5 and m[1]['name'] == 'Belt', 'the export keeps the required level and the name'
    assert m[2]['min'] == 30 and m[2]['name'] == 'Old Boots'
    m = build_gear.item_master({1: scan_item('Gürtel', lvl=7)}, export, prev)
    assert m[1]['min'] == 7 and m[1]['name'] == 'Gürtel' and m[1]['classes'] == 3, 'the scan wins, class limits stay'


def test_last_build_is_read_back(tmp_path):
    src = build_gear.Sources()
    q = src.add('Q', 'Q', 0, 30, None, None, 5)
    v = src.add('V', 'Smith', 1436)
    keep = {10: (dict(scan_item('Helm'), stats='STRENGTH_SHORT=5'), [q], 34, 0, 0.0, 0),
            11: (scan_item('Hat', lvl=12), [q, v], 12, 1024, 0.0, 0)}
    out = tmp_path / 'GearData.lua'
    build_gear.write_lua(str(out), src, keep, {}, {'built': '2026-10-06'}, old_stats={11: 'AGILITY=3'})
    prev = build_gear.previous_items(str(out))
    assert prev[10]['min'] == 0, 'a quest-only item: its level was a quest level, so it is not kept'
    assert prev[11]['min'] == 12 and prev[11]['classes'] == 1024 and prev[11]['equipLoc'] == 'INVTYPE_HEAD'
    assert build_gear.previous_stats(str(out)) == {10: 'STRENGTH=5', 11: 'AGILITY=3'}, 'an older scan\'s stats stay'


def test_rare_dungeon_drops_count_as_world_drops():
    assert build_gear.drop_chance('12.5%') == 12.5 and build_gear.drop_chance('<0.1%') == 0.05
    assert build_gear.drop_chance(None) == 100.0
    a = att(item_names={12: 'Avenger Armor'})
    wowsrc = {'dungeons': [{'name': 'Razorfen Kraul', 'bosses': [{'name': 'Trash', 'items': [{'n': 'Avenger Armor', 'd': '<0.1%'}]}]}]}
    src, keep, *_ = build_gear.build({12: scan_item('Avenger Armor')}, {}, a, wowsrc=wowsrc)
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
    data = json.loads(out.read_text(encoding='utf-8'))
    assert data['classes'] == {'2': 2, '4': 1024}
    assert data['delay'] == {'1': 2600, '4': 3000}
    assert data['skill'] == {'3': [202, 280]}
    a = att(quests={500: quest('Q', 1, rewards=[4, 3])})
    _, keep, *_ = build_gear.build(scan, {}, a, itemsparse=data)
    assert keep[4][3:] == (1024, 3.0, 0)
    assert keep[3][2] == 56 and keep[3][5] == 202, 'engineering 280 is reached around level 56'


def test_class_limits_from_the_export_when_itemsparse_has_none():
    a = att(quests={500: quest('Q', 1, rewards=[5])}, items={5: dict(scan_item('Helm'), classes=1 | 2, skill=0)})
    _, keep, *_ = build_gear.build({}, {}, a)
    assert keep[5][3] == 3


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
    a = att(quests={500: quest('The Quest', 24, 'A', None)},
            npcs={639: npc('Edwin VanCleef', {'boss'}, zone=291, inst=63)}, instances=DEADMINES)
    scan = {i: scan_item(f'I{i}', q=3) for i in (1, 2, 3, 4, 5, 6)}
    collected = {
        1: ['Drop: ? [639] @Die Todesminen #party:36'],
        2: ['Drop: Wolf [299] @Wald von Elwynn'],
        3: ['Quest: Die Fackel [500] L23'],
        4: ['Quest: Neue Quest [99999] L31'],
        5: ['Drop: Ragnaros [11502] @Geschmolzener Kern #raid:409'],
        6: ['Drop: Cookie [645] @The Deadmines #party:36'],
    }
    src, keep, zone_rows, *_ = build_gear.build(scan, collected, a, facts=FACTS)
    rec = lambda i: src.rows[keep[i][1][0] - 1]  # noqa: E731
    assert rec(1) == ('D', 'The Deadmines', 'Edwin VanCleef', None, 36, 1581), 'with instance and area id'
    w = rec(2)
    assert w[:4] == ('W', 'Wolf', 0, 0) and zone_rows[w[4]] == 'Wald von Elwynn'
    assert rec(3) == ('Q', 'The Quest', 0, 24, 'A', None, 500, 0)
    assert rec(4) == ('Q', 'Neue Quest', 31, 0, None, None, 99999)
    assert 5 not in keep, 'raid drops stay out'
    assert rec(6) == ('D', 'The Deadmines', 'Cookie', None, 36, 1581)


def test_test_items_and_retired_items_stay_out():
    assert 8350 in build_gear.TEST_ITEMS
    a = att(quests={500: quest('Q', 1, rewards=[8350, 61099])},
            items={61099: dict(scan_item('OLDRetired Belt', loc='INVTYPE_WAIST'), classes=0, skill=0)})
    scan = {8350: scan_item('Der Eine Ring', loc='INVTYPE_FINGER')}
    _, keep, _, _, dropped, *_ = build_gear.build(scan, {}, a)
    assert 8350 not in keep and 61099 not in keep and dropped['junk'] == 2


def test_dungeon_drops_carry_instance_area_and_the_facts_name():
    a = att(instances=DEADMINES, npcs={645: npc('Cookie', {'boss'}, zone=291, inst=63)},
            drops=[(20, 645, 'boss', 63, 291, False, None), (22, None, 'boss', 63, 291, False, 'Sneed')],
            zone_drops=[(23, [624], 63, 291, False)], item_names={21: 'Cruel Barb'})
    scan = {20: scan_item('Cookie Hat', q=3), 21: scan_item('Cruel Barb', loc='INVTYPE_WEAPON', cls=2, q=3),
            22: scan_item('Gloves', q=3), 23: scan_item('Trash Boots', q=2)}
    wowsrc = {'dungeons': [{'name': 'Deadmines', 'bosses': [{'name': 'Edwin VanCleef', 'items': [{'n': 'Cruel Barb', 'd': '12%'}]}]}]}
    src, keep, *_ = build_gear.build(scan, {}, a, wowsrc=wowsrc, facts=FACTS)
    assert src.rows[keep[20][1][0] - 1] == ('D', 'The Deadmines', 'Cookie', None, 36, 1581)
    assert src.rows[keep[21][1][0] - 1] == ('D', 'The Deadmines', 'Edwin VanCleef', '12%', 36, 1581), 'found by name'
    assert src.rows[keep[22][1][0] - 1] == ('D', 'The Deadmines', 'Sneed', None, 36, 1581), 'an encounter boss'
    assert src.rows[keep[23][1][0] - 1] == ('W', 'Trash (The Deadmines)', 0, 0)


def test_places_learn_instance_ids_from_drop_notes():
    a = att(instances={63: dict(DEADMINES[63], mapID=None)})
    p = build_gear.Places(a, FACTS)
    assert p.of_att(63) == ('The Deadmines', None, 1581)
    p.learn(36, 'The Deadmines')
    assert p.of_name('Deadmines') == ('The Deadmines', 36, 1581) and p.of_instance(36)[0] == 'The Deadmines'
    assert p.of_name('Scarlet Monastery - Armory')[0] == 'Scarlet Monastery', 'a wing is its dungeon'
    assert p.of_name("Onyxia's Lair") == ("Onyxia's Lair", 249, 2159), 'from the facts'


FOREVER_JS = ('window.__LOOT=window.__LOOT||{};window.__LOOT["forever"]={"zones":['
              '{"key":"ony","name":"Onyxia\'s Lair","short":"Ony","color":["#b9915a","#8a6428"]},'
              '{"key":"field","name":"Seen in the world","short":"World","color":["#7c9a6d","#5d7452"]}],'
              '"bosses":[{"name":"Onyxia","zone":"ony"},{"name":"Alter Seekrabbler","zone":"field"}],'
              '"items":[{"id":18205,"name":"Eskhandar\'s Collar","sources":["Onyxia"]},'
              '{"id":262888,"name":"X","sources":["Alter Seekrabbler"]}]};\n')


def test_forever_raid_zones_become_raid_sources(tmp_path):
    js = tmp_path / 'forever.js'
    js.write_text(FOREVER_JS, encoding='utf-8')
    cfg = {"Onyxia's Lair": {'key': 'ony', 'raid': True, 'instance': 249, 'area': 2159},
           'Seen in the world': {'key': 'field'}}
    raids = build_gear.load_forever_raids(str(js), cfg)
    assert raids == [("Onyxia's Lair", 'Onyxia', 18205, 249, 2159)], 'only raid zones'
    scan = {18205: dict(scan_item("Eskhandar's Collar", loc='INVTYPE_NECK', q=4, lvl=60), ilvl=80)}
    src, keep, _, stats, dropped, *_ = build_gear.build(scan, {}, att(), forever_raids=raids)
    assert src.rows[keep[18205][1][0] - 1] == ('X', "Onyxia's Lair", 'Onyxia', 249, 2159, 1, 0)
    assert dropped['raid level'] == 0, 'raid gear of a Forever raid stays'
    assert build_gear.load_forever_raids(str(js), {}) == [], 'no raid zones, nothing new'


def test_the_real_zone_list_marks_forever_raids():
    with open(build_gear.FOREVER_ZONES, encoding='utf-8') as fh:
        cfg = json.load(fh)
    assert cfg["Onyxia's Lair"].get('raid') is True and cfg["Onyxia's Lair"].get('instance') == 249


def test_output_header_names_the_sources_and_no_guard(tmp_path):
    # the addon is WoW Forever only: the TOC load condition is the one lock, no IsForever guard
    src = build_gear.Sources()
    n = src.add('Q', 'Q', 1, 1, None, None, 5)
    keep = {10: (scan_item('Helm'), [n], 1, 0, 0.0, 0)}
    out = tmp_path / 'GearData.lua'
    build_gear.write_lua(str(out), src, keep, {}, {'built': '2026-10-05'})
    text = out.read_text(encoding='utf-8')
    lines = text.split('\n')
    assert 'AllTheThings' in lines[1] and 'MIT' in lines[1] and 'LICENSES' in lines[1]
    assert 'Questie' not in text and 'GPL-3.0' not in text
    assert lines[2] == 'local _, ns = ...' and lines[3] == ''
    assert 'IsForever' not in text
    assert lua_data.compact('game = "forever", cap = 60, built = "2026-10-05",') in lines

    # the stat weights are Amisia's own (build_bis.py): this build has no writer for them any more
    assert not hasattr(build_gear, 'write_weights') and not hasattr(build_gear, 'load_rxp_weights')


def test_lua_strings_escape_control_characters():
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    for text in ['a\nb', 'a\rb', 'tab\there', 'bell\x07', 'zero\x00one', 'del\x7f', 'q"uote\\back', 'digit\x012']:
        lit = build_gear.lua_str(text)
        assert not any(ord(c) < 32 or ord(c) == 127 for c in lit), repr(lit)
        assert lua.eval(lit) == text, (text, lit)
    assert build_gear.lua_str('a\nb') == '"a\\nb"' and build_gear.lua_str('a\rb') == '"a\\rb"'


def test_npc_id_rides_last_on_vendors_rares_and_named_mobs():
    # Gear.lua's fields stay where they are; the NPC id sits behind them at a fixed place per kind
    # (V and P after the phase field: 7, R: 5, W: 6), where the map data finds it.
    a = att(npcs={900: npc('Smith', {'vendor'}, 1436, 'A', 'Weaponsmith'), 901: npc('Muad', {'rare'}, 1420),
                  902: npc('Harvest Golem', {'mob'}, 1436), 903: npc('Sergeant', {'vendor'}, 1453, '', 'Accessories Quartermaster')},
            sold=[(30, 900, False), (33, 903, False)], drops=[(31, 901, 'rare', None, 1420, False, None)],
            zone_drops=[(32, [902], None, 1436, False)], pvp=[(34, 'H')])
    scan = {30: scan_item('Vendor Helm'), 31: scan_item('Rare Ring', loc='INVTYPE_FINGER'),
            32: scan_item('Mob Boots', loc='INVTYPE_FEET'), 33: scan_item('PvP Neck', loc='INVTYPE_NECK', q=3),
            34: scan_item('Rank Cloak', loc='INVTYPE_CLOAK', q=3)}
    collected = {30: ['Haendler: Grimm [904] @Dun Morogh'], 31: ['Drop: Wolf [299] @Wald von Elwynn']}
    src, keep, *_ = build_gear.build(scan, collected, a)
    recs = {src.rows[n - 1] for k in keep.values() for n in k[1]}
    assert ('V', 'Smith', 1436, 'A', 'Weaponsmith', None, 900) in recs
    assert ('R', 'Muad', 0, 1420, 901) in recs
    assert ('W', 'Harvest Golem', 0, 0, 1436, 902) in recs
    assert ('P', 'Sergeant', 1453, None, 'Accessories Quartermaster', None, 903) in recs
    assert ('P', build_gear.PVP_SOURCE, None, 'H') in recs, 'PvP rank gear per faction'
    grimm = [r for r in recs if r[1] == 'Grimm'][0]
    assert grimm[0] == 'V' and grimm[6] == 904, 'a vendor the collector noted with its id'
    wolf = [r for r in recs if r[1] == 'Wolf'][0]
    assert wolf[:4] == ('W', 'Wolf', 0, 0) and wolf[5] == 299, 'a mob the collector noted with its id'


def test_crafted_items_keep_a_known_skill():
    a = att(crafted=[(40, 'tailoring'), (41, 'tailoring')])
    scan = {40: dict(scan_item('Robe', loc='INVTYPE_ROBE'), bind=2), 41: dict(scan_item('Cap'), bind=2)}
    src, keep, *_ = build_gear.build(scan, {}, a, crafts={'tailoring': [(40, 75)]})
    assert [src.rows[n - 1] for n in keep[40][1]] == [('C', 'tailoring', 75)], 'the skill of the client tables wins'
    assert [src.rows[n - 1] for n in keep[41][1]] == [('C', 'tailoring', 0)], 'else the profession without a skill'


def test_the_fixture_end_to_end():
    db = att_data.load(FIXTURE)
    src, keep, zone_rows, stats, dropped, unmatched, missing = build_gear.build({}, {}, db, facts=[
        {'key': 'thanes', 'name': 'Test Halls', 'kind': 'party'}])
    rec = lambda i: [src.rows[n - 1] for n in keep[i][1]]  # noqa: E731
    assert rec(61001) == [('Q', 'Boar Trouble', 0, 6, 'A', 1426, 71001, 3)]
    assert keep[61001][2] == 6, 'the quest can be taken at 6, the belt is worn from 5'
    assert rec(61004) == [('R', 'Old Tusk', 0, 1426, 81002)]
    assert rec(61005) == [('V', 'Smith Fixture', 1426, 'H', 'Armorer', None, 81003)] and keep[61005][3] == 3
    assert rec(61006) == [('W', 'Gnoll Brute', 0, 0, 1426, 81004)]
    assert 61099 not in keep
    assert {61002, 61003, 61012, 61013, 61017} <= set(missing), 'a quest, dungeon or crafted item no table knows'
    assert not {61007, 61015, 61016} & set(missing), 'world drops and PvP gear are not asked for'


def test_zone_names_only_for_zone_fields(tmp_path):
    # an instance id (Blackrock Depths, 230) can equal a uiMapID (Uldaman's map, 230): a D record names no zone
    src = build_gear.Sources()
    d = src.add('D', 'Blackrock Depths', 'Boss', None, 230, 1584)
    q = src.add('Q', 'Quest', 30, 25, None, 301, 5)
    keep = {10: (scan_item('Helm'), [d, q], 30, 0, 0.0, 0)}
    out = tmp_path / 'GearData.lua'
    build_gear.write_lua(str(out), src, keep, {230: 'Uldaman', 301: 'Razorfen Kraul'}, {'built': '2026-10-06'})
    text = out.read_text(encoding='utf-8')
    assert '[301]="Razorfen Kraul",' in text and '"Uldaman"' not in text


# ---------------------------------------------------------------- the wings of one instance (F-174, D-106)
MONASTERY = {316: {'name': 'Scarlet Monastery', 'area': 796, 'maps': [302], 'points': [], 'file': 'd',
                   'stem': 'scarlet monastery', 'old': False, 'mapID': 189}}
WINGS = [{'key': w[0], 'name': 'Scarlet Monastery: ' + w[1], 'kind': 'party', 'part': 'Scarlet Monastery',
          'att_wing': w[1], 'aliases': ['Scarlet Monastery - ' + w[1]]}
         for w in (('smgy', 'Graveyard'), ('smlib', 'Library'), ('smarm', 'Armory'), ('smcath', 'Cathedral'))]


def monastery_att():
    return att(instances=MONASTERY,
               npcs={3983: dict(npc('Interrogator Vishas', {'npc'}, inst=316), wing='Graveyard'),
                     6489: dict(npc('Ironspine', {'rare'}, inst=316), wing='Graveyard'),
                     3974: dict(npc('Houndmaster Loksey', {'npc'}, inst=316), wing='Library'),
                     3975: dict(npc('Herod', {'npc'}, inst=316), wing='Armory'),
                     3976: dict(npc('Scarlet Commander Mograine', {'npc'}, inst=316), wing='Cathedral'),
                     3977: dict(npc('High Inquisitor Whitemane', {'npc'}, inst=316), wing='Cathedral')},
               encounters={448: {'name': 'Herod', 'npcs': [3975], 'inst': 316, 'wing': 'Armory'}})


def test_every_source_of_an_instance_of_wings_lands_in_its_wing():
    """The item data names the wing of a boss (D-106): an ATT drop by its NPC's header, a wing page of the drop
    chances by its own name, a drop the collector saw by its NPC, by the boss's name; trash and unknown names
    go to the first wing; the trash of the zone keeps the instance's name."""
    a = monastery_att()
    a['drops'] = [(30, 3983, 'boss', 316, 302, False, None), (31, 6489, 'rare', 316, 302, False, None),
                  (32, 3977, 'boss', 316, 302, False, None), (33, None, 'boss', 316, 302, False, 'Herod')]
    a['zone_drops'] = [(34, [9999], 316, 302, False)]
    a['item_names'] = {35: 'Ravager', 36: 'Scarlet Belt'}
    scan = {i: scan_item(f'I{i}', q=3) for i in range(30, 40)}
    scan[35], scan[36] = scan_item('Ravager', q=3), scan_item('Scarlet Belt', q=2)
    wowsrc = {'dungeons': [{'name': 'Scarlet Monastery - Armory', 'bosses': [
        {'name': 'Herod', 'items': [{'n': 'Ravager', 'd': '12%'}]}, {'name': 'Trash', 'items': [{'n': 'Scarlet Belt', 'd': '2%'}]}]}]}
    collected = {37: ['Drop: ? [3974] @Scharlachrotes Kloster #party:189'],
                 38: ['Drop: Scorn [14693] @Scharlachrotes Kloster #party:189']}
    src, keep, *_ = build_gear.build(scan, collected, a, wowsrc=wowsrc, facts=WINGS)
    rec = lambda i: src.rows[keep[i][1][0] - 1]  # noqa: E731
    assert rec(30)[:3] == ('D', 'Scarlet Monastery: Graveyard', 'Interrogator Vishas') and rec(30)[4:] == (189, 796)
    assert rec(31)[:3] == ('D', 'Scarlet Monastery: Graveyard', 'Ironspine'), 'a rare of the wing'
    assert rec(32)[:3] == ('D', 'Scarlet Monastery: Cathedral', 'High Inquisitor Whitemane')
    assert rec(33)[:3] == ('D', 'Scarlet Monastery: Armory', 'Herod'), 'an encounter boss by its name'
    assert rec(34) == ('W', 'Trash (Scarlet Monastery)', 0, 0), 'the zone drops keep the instance'
    assert rec(35)[:4] == ('D', 'Scarlet Monastery: Armory', 'Herod', '12%'), "the wing page's own name"
    assert rec(36)[:3] == ('D', 'Scarlet Monastery: Armory', 'Trash')
    assert rec(37)[:3] == ('D', 'Scarlet Monastery: Library', 'Houndmaster Loksey'), 'a drop seen in game by its NPC'
    assert rec(38)[:3] == ('D', 'Scarlet Monastery: Graveyard', 'Scorn'), 'an unknown boss: the first wing'


def test_the_quest_rule_of_an_instance_of_wings():
    """A quest of the instance (D-106): its own ATT header; else every wing whose boss an objective names, in
    the facts' order; else the first wing. The item data's quest names the first of them."""
    a = monastery_att()
    p = build_gear.Places(a, WINGS)
    place = p.of_att(316)
    assert place == ('Scarlet Monastery', 189, 796)
    names = lambda q: [x[0].split(': ')[1] for x in p.quest_wings(place, q)]  # noqa: E731
    assert names({'wing': 'Library', 'targets': [3977]}) == ['Library'], 'the header wins'
    assert names({'wing': None, 'targets': [3977, 3975, 3974, 3976]}) == ['Library', 'Armory', 'Cathedral']
    assert names({'wing': None, 'targets': []}) == ['Graveyard'], 'nothing places it: the first wing'
    assert names({'wing': None, 'targets': [12345]}) == ['Graveyard'], 'an NPC of no wing'
    assert p.quest_wings(('The Deadmines', 36, 1581), {'targets': [3977]}) == [('The Deadmines', 36, 1581)]
    a['quests'] = {1048: dict(quest('Into The Scarlet Monastery', 33, 'H', inst=316, rewards=[40]), targets=[3974, 3975, 3977])}
    src, keep, *_ = build_gear.build({40: scan_item('Sword', q=3)}, {}, a, facts=WINGS)
    assert src.rows[keep[40][1][0] - 1][8] == 'Scarlet Monastery: Library'


def test_the_facts_carry_the_client_instance_ids():
    by = {f['key']: f for f in build_gear.load_facts()}
    assert by['ubrs']['inst'] == 229 and by['deadmines']['inst'] == 36, 'tools/forever_dungeons_client.json'
    assert by['onyxia']['inst'] == 249, 'the hand facts win'
    p = build_gear.Places({'instances': {}}, build_gear.load_facts())
    assert p.of_name('Upper Blackrock Spire')[1] == 229


def test_itemsparse_from_a_folder(tmp_path):
    f = tmp_path / 'ItemSparse.1.60.1.70235.csv'
    f.write_text('ID\n', encoding='utf-8')
    assert build_gear.itemsparse_path(str(tmp_path)) == str(f), 'the download name in a folder'
    assert build_gear.itemsparse_path(str(f)) == str(f), 'a file as it is'
    (tmp_path / 'empty').mkdir()
    try:
        build_gear.itemsparse_path(str(tmp_path / 'empty'))
        assert False, 'a folder without the table stops the build'
    except SystemExit as e:
        assert 'no ItemSparse' in str(e)


def test_no_rxp_era_weights_left():
    """Review 25: the weights are Amisia's own (build_bis.py). build_gear.py keeps none of the
    RestedXP-era weight constants, and tools/README.md claims no RestedXP weights or their licence."""
    for name in ('BRACKETS', 'CLASS_ORDER', 'SPECS', 'OWN', 'HEALER', 'TANK'):
        assert not hasattr(build_gear, name), name
    with open(build_gear.__file__, encoding='utf-8') as fh:
        assert 'RXP' not in fh.read()
    with open(os.path.join(os.path.dirname(build_gear.__file__), 'README.md'), encoding='utf-8') as fh:
        text = fh.read()
    assert 'RestedXP' not in text and 'CC BY-NC-SA' not in text and 'StatWeights' not in text


def test_the_source_collector_fills_what_att_lacks():
    # ATT knows quest 500 (without the reward 41), vendor 900 and the rare 901; the collector saw
    # them and more: a new shaman quest with Rage of the Storm, a vendor and mobs ATT does not know
    a = att(quests={500: quest('The Quest', 24, 'A', 1436, rewards=[40])},
            npcs={900: npc('Smith', {'vendor'}, 1436, 'A', 'Weaponsmith'), 901: npc('Muad', {'rare'}, 1420),
                  639: npc('Edwin VanCleef', {'boss'}, zone=291, inst=63)},
            sold=[(42, 900, False)], instances=DEADMINES)
    scan = {i: scan_item(f'I{i}', q=3) for i in (40, 41, 42, 43, 44, 45, 46, 47, 48)}
    scan[280604] = scan_item('Rage of the Storm', loc='INVTYPE_2HWEAPON', cls=2, q=3, lvl=30)
    sb = build_gear.build_scan
    # what the account saw itself (own values)
    def own(kind, recs):
        return {k: sb.mark_collect_record(kind, v, 'own') for k, v in recs.items()}
    observed = sb.collect_observed([{'collect': {
        'q': own('q', {500: '280;0;3344;1436:5000:5000;0;;40,41;;0;20;A;0;Gryan;;;Die Quest',
                       2001: '280;0;3344;1440:5234:4011;0;;280604;;34;30;H;0;Sturmrufer;;;The Tempest\'s Weapons'}),
        's': own('s', {900: '280;0;1436:1:1;42:100::,43:200:L:;Schmied', 904: '280;0;1411:2500:7500;44:1520::6@Orgrimmar;Grimm'}),
        'w': own('w', {901: '280;0;r;1420:1:1;0;45:1;Muad', 299: '280;0;n;1411:2500:7500;0;46:2;Wolf', 300: '280;0;R;1411:1:1;0;47:1;Eber',
                       302: '280;0;n;;36;48:1;Defias'})}}])
    assert len(observed['q']) == 2 and len(observed['s']) == 2 and len(observed['w']) == 4
    src, keep, zone_rows, *_ = build_gear.build(scan, {}, a, facts=FACTS, observed=observed)
    recs = lambda i: {src.rows[n - 1] for n in keep[i][1]}  # noqa: E731
    att_quest = ('Q', 'The Quest', 0, 24, 'A', 1436, 500, 0)
    assert recs(40) == {att_quest}, 'ATT wins for a quest it knows: one source'
    assert recs(41) == {att_quest}, 'a reward ATT does not list gets ATT\'s quest record'
    assert recs(280604) == {('Q', "The Tempest's Weapons", 34, 30, 'H', 1440, 2001)}, 'the observed quest'
    assert recs(42) == {('V', 'Smith', 1436, 'A', 'Weaponsmith', None, 900)}, 'ATT\'s vendor record'
    assert recs(43) == {('V', 'Smith', 1436, 'A', 'Weaponsmith', None, 900)}
    assert recs(44) == {('V', 'Grimm', 1411, None, None, None, 904)}, 'a vendor ATT does not know'
    assert recs(45) == {('R', 'Muad', 0, 1420, 901)}
    assert recs(46) == {('W', 'Wolf', 0, 0, 1411, 299)}
    assert recs(47) == {('R', 'Eber', 0, 1411, 300)}, 'a rare by its classification'
    assert recs(48) == {('W', 'Trash (The Deadmines)', 0, 0)}, 'dungeon trash'
    assert 1440 in zone_rows and 1411 in zone_rows


def test_without_observations_nothing_changes():
    a = att(quests={500: quest('The Quest', 24, 'A', None, rewards=[40])})
    scan = {40: scan_item('I40', q=3)}
    one = build_gear.build(scan, {}, a)
    two = build_gear.build(scan, {}, a, observed={'q': {}, 's': {}, 'w': {}})
    assert one[0].rows == two[0].rows and one[1].keys() == two[1].keys()


def test_scan_gear_asks_only_for_ids_the_client_has(tmp_path):
    # an id the client's ItemSparse lacks does not exist in Forever: /amisia scan gear leaves it out
    (tmp_path / 'ItemSparse.1.60.1.70235.csv').write_text('ID,Display_lang\n10,A\n30,C\n', encoding='utf-8')
    assert build_gear.client_known([10, 20, 30], str(tmp_path)) == [10, 30]
    assert build_gear.client_known([10, 20], str(tmp_path / 'none')) == [10, 20]


# ---------------------------------------------------------------- recipes from the client tables
def test_recipes_and_their_skill_come_from_the_client_tables(tmp_path):
    """The item a recipe makes (SpellEffect 24) and its skill: the higher of MinSkillLineRank and the
    RequiredSkillRank of the recipe item that teaches it (ItemXItemEffect, trigger 6)."""
    w = tmp_path / 'wago'
    w.mkdir()
    b = '1.60.1.70755'
    (w / f'SkillLineAbility.{b}.csv').write_text(
        'ID,SkillLine,Spell,MinSkillLineRank,AcquireMethod,TrivialSkillLineRankLow,TrivialSkillLineRankHigh\n'
        '1,197,100,1,1,60,80\n2,197,101,1,0,140,160\n3,197,102,1,0,0,0\n4,186,103,1,0,0,0\n'
        '5,164,410001,1,0,0,0\n6,164,410002,50,0,0,0\n', encoding='utf-8')
    (w / f'SpellEffect.{b}.csv').write_text(
        'ID,SpellID,Effect,EffectItemType,EffectBasePointsF\n1,100,24,40,1\n2,101,24,41,1\n3,102,53,0,0\n'
        '4,103,24,42,1\n5,410001,24,43,1\n6,410002,24,44,1\n', encoding='utf-8')
    (w / f'ItemEffect.{b}.csv').write_text('ID,SpellID,TriggerType\n7,101,6\n', encoding='utf-8')
    (w / f'ItemXItemEffect.{b}.csv').write_text('ID,ItemID,ItemEffectID\n1,900,7\n', encoding='utf-8')
    (w / f'ItemSparse.{b}.csv').write_text('ID,Display_lang,RequiredSkillRank\n900,Pattern,125\n40,Robe,0\n',
                                           encoding='utf-8')
    crafts = build_gear.client_crafts(str(w), att_crafted=[(44, 'blacksmithing')])
    # a trainer recipe keeps its rank, one from a pattern the pattern's skill; no item no recipe;
    # mining is no crafting profession; a Season of Discovery recipe only for an item ATT has for Forever
    assert crafts == {'blacksmithing': [(44, 50)], 'tailoring': [(40, 1), (41, 125)]}
    assert build_gear.client_crafts(str(tmp_path / 'none')) == {}


def test_reputation_and_quest_types_reach_the_data(tmp_path):
    """The reputation an item asks for comes from the client's ItemSparse (RP, F-124); the quest types
    the addon learned join tools/quest_tag_archive.json and reach the gear data (QT) for its quests."""
    wago = tmp_path / 'wago'
    wago.mkdir()
    (wago / 'ItemSparse.1.60.1.70532.csv').write_text(
        'ID,MinFactionID,MinReputation\n10,72,5\n11,0,0\n12,509,9\n', encoding='utf-8')
    assert build_gear.client_reputation(str(wago)) == {10: (72, 5)}, 'a standing beyond exalted is dropped'
    assert build_gear.client_reputation(str(tmp_path / 'none')) == {}

    arch = tmp_path / 'quest_tag_archive.json'
    db1 = {'questtags': {'v': 1, 'list': {5: 'G', 6: 'X', 7: 'D'}}}
    db2 = {'questtags': {'v': 1, 'list': {5: 'D'}}}
    tags = build_gear.update_quest_tags([db1, db2], path=str(arch), today='2026-10-24')
    assert tags == {5: 'D', 7: 'D'}, 'a later file wins, an unknown code is dropped'
    saved = json.loads(arch.read_text(encoding='utf-8'))
    assert saved == {'updated': '2026-10-24', 'tags': {'5': 'D', '7': 'D'}}
    assert build_gear.update_quest_tags([{}], path=str(arch), today='2026-10-25') == tags, 'nothing is forgotten'
    assert json.loads(arch.read_text(encoding='utf-8'))['updated'] == '2026-10-24', 'unchanged: not written again'

    src = build_gear.Sources()
    q = src.add('Q', 'Q', 0, 30, None, 1436, 5)
    v = src.add('V', 'Smith', 1436)
    keep = {10: (scan_item('Helm'), [v], 20, 0, 0.0, 0), 11: (scan_item('Hat'), [q], 20, 0, 0.0, 0)}
    out = tmp_path / 'GearData.lua'
    build_gear.write_lua(str(out), src, keep, {}, {'built': '2026-10-24', 'rep': {10: (72, 5), 99: (1, 1)},
                                                   'qtags': {5: 'D', 8: 'G'}})
    text = lua_data.expand(out.read_text(encoding='utf-8')) if hasattr(lua_data, 'expand') else out.read_text(encoding='utf-8')
    assert '[10]=725' in text.replace(' ', ''), 'Stormwind honored for the helm'
    assert '[99]' not in text.split('RP')[1].split('M')[0], 'only items of the data'
    assert '[5]="D"' in text.replace(' ', ''), 'the quest of the data has its type'
    assert '[8]=' not in text.split('QT')[1].split('M')[0].replace(' ', ''), 'a quest the data lacks is left out'


def test_names_and_icons_only_for_items_the_client_lacks():
    """N and IC (D-59): the scan's name and icon for the items only the server describes; the client's
    id ranges as the scan archive keeps them, or a set."""
    ranges = [[1, 10], [20, 30]]
    assert build_gear.client_has(ranges, 5) and build_gear.client_has(ranges, 30)
    assert not build_gear.client_has(ranges, 15) and not build_gear.client_has(ranges, 31)
    assert build_gear.client_has({7}, 7) and not build_gear.client_has({7}, 8)
    assert build_gear.client_has(None, 99), 'unknown: every id counts as known'
    assert build_gear.clean_name('|cffa335eeReif der Prophezeiung|r') == 'Reif der Prophezeiung'
    assert build_gear.clean_name('a|b') == 'ab' and build_gear.clean_name('x' * 65) == ''


# ---------------------------------------------------------------- the quest scan's rewards (D-104, D-107)
def scanned_quests(lines, loc='deDE'):
    import build_scan_archive as sa
    return {'quests': {loc: {qid: sa.quest_fields(line) for qid, line in lines.items()}}}


def test_scanned_rewards_become_quest_sources_where_none_is_known():
    """A reward or choice of a scanned quest (layout 2) gets the quest as its source when no quest names
    it: AllTheThings' record of a quest it knows, the collector's of one it saw, else the scanned title
    and level without a faction; an item with a quest source keeps only that one; a raid quest gives none."""
    a = att(quests={500: quest('The Quest', 24, 'A', None, rewards=[40]), 510: quest('Raid Q', 58, inst=1)},
            instances={1: {'name': 'Molten Core', 'area': 1, 'maps': [], 'points': [], 'file': 'r', 'stem': 'mc',
                           'old': False, 'mapID': 409}})
    scan = {i: scan_item(f'I{i}', q=3) for i in (40, 41, 42, 43, 44, 45)}
    scan[274998] = scan_item('Schattenlichtathame', loc='INVTYPE_WEAPONMAINHAND', cls=2, q=3, lvl=40)
    sb = build_gear.build_scan
    observed = sb.collect_observed([{'collect': {'q': {
        2001: sb.mark_collect_record('q', '280;0;3344;1440:5234:4011;0;;45;;34;30;H;0;Sturmrufer;;;Seen Quest', 'own')}}}])
    lines = {500: 'Die Quest\t24\t26\t\t0\t\t40,41', 600: 'Neue Quest\t41\t0\t\t0\t\t274998\t42,43', 510: 'Raid\t58\t0\t\t0\t\t44',
             2001: 'Gesehen\t30\t0\t\t0\t\t\t45*2'}
    scanned = build_gear.scan_quest_rewards(scanned_quests(lines))
    assert scanned[600] == {'title': 'Neue Quest', 'level': 41, 'items': [274998, 42, 43]}
    assert scanned[500]['level'] == 26, 'the quest level before the difficulty'
    src, keep, *_ = build_gear.build(scan, {}, a, observed=observed, scanned=scanned)
    recs = lambda i: {src.rows[n - 1] for n in keep[i][1]}  # noqa: E731
    att_quest = ('Q', 'The Quest', 0, 24, 'A', None, 500, 0)
    assert recs(40) == {att_quest}, 'ATT names it already: one source'
    assert recs(41) == {att_quest}, 'a reward ATT does not list: ATT\'s record of the quest'
    new = ('Q', 'Neue Quest', 41, 0, None, None, 600)
    assert recs(274998) == recs(42) == recs(43) == {new}, 'a quest no source knows: the scan\'s title and level'
    assert keep[274998][2] == 40, 'the required level stays (quest level - 4 = 37 is below it)'
    assert 44 not in keep, 'a raid quest is no source'
    assert recs(45) == {('Q', 'Seen Quest', 34, 30, 'H', 1440, 2001)}, 'the collector\'s record of a quest it saw'
    assert 274998 in src.named and 44 not in src.named


def test_an_empty_scan_part_changes_nothing(tmp_path):
    """No scan with rewards yet (the real archive today): the build and its file stay byte for byte."""
    a = att(quests={500: quest('The Quest', 24, 'A', 1436, rewards=[40])})
    scan = {40: scan_item('I40', q=3), 41: scan_item('I41', q=3)}
    old = scanned_quests({500: 'Die Quest\t24', 9: 'Alt\t3\t0\t\t0\tZiele'})
    assert build_gear.scan_quest_rewards(old) == {} and build_gear.scan_quest_rewards({}) == {}
    outs = []
    for scanned in (None, {}, build_gear.scan_quest_rewards(old)):
        src, keep, zone_rows, *_ = build_gear.build(scan, {}, a, scanned=scanned)
        out = tmp_path / f'G{len(outs)}.lua'
        build_gear.write_lua(str(out), src, keep, zone_rows, {'built': '2026-11-10'})
        outs.append(out.read_bytes())
    assert outs[0] == outs[1] == outs[2]
    import build_scan_archive as sa
    real = build_gear.scan_quest_rewards(sa.id_scans(sa.ARCHIVE, []))
    assert real == {}, 'the committed archive has no rewards yet'


# ---------------------------------------------------------------- gear without a known source (D-107)
def test_no_source_rules():
    """What GearNoSource.lua keeps: scanned gear no source names, uncommon or better, with a scored stat,
    no test or placeholder name, no old raid gear; a required level of 0 stays (its level from the item
    level)."""
    keys = build_gear.scored_stat_keys()
    def it(name, q=3, req=40, ilvl=45, loc='INVTYPE_WEAPONMAINHAND', cls=2, stats='STAMINA_SHORT=9;INTELLECT_SHORT=5'):
        return {'name': name, 'q': q, 'ilvl': ilvl, 'min': req, 'classID': cls, 'subclassID': 15, 'equipLoc': loc,
                'icon': '135656', 'bind': 1, 'stats': stats}
    scan = {274998: it('Schattenlichtathame'), 275836: it('Akolythenklinge', q=2, req=0, ilvl=57),
            253884: it('Template Item', q=2), 273878: it('[DNT] Crafted Tier Piece Placeholder', q=4),
            274027: it('Placeholder'), 277555: it('Monster - Shield, Skyborne (Gray)', loc='INVTYPE_SHIELD', cls=4),
            2189: it("Tigole's Boomstick (TEST)"), 18968: it('Ring of Critical Testing', loc='INVTYPE_FINGER', cls=4),
            20322: it('63 Green Rogue Spaulders', q=2, loc='INVTYPE_SHOULDER', cls=4), 21124: it("Ahn'Qiraj Wand [PH]"),
            23034: it('Nax PH Crit Plate Shoulders'), 10037: it('DEPRECATED'), 99001: it('DNT HEAD'),
            24358: it('QATest +1000 Spell Dmg Ring'), 21276: it('Blessed Qiraji Naturalist Staff UNUSED'),
            99002: it('Grauer Dolch', q=1), 99003: it('Ohne Werte', stats=''), 99004: it('Nur Proc', stats='SOCKET=1'),
            99005: it('Eine Tasche', loc='INVTYPE_BAG', cls=1), 99006: it('Ein Hemd', loc='INVTYPE_BODY', cls=4),
            19324: it('Der Geistesbrecher', q=4, req=60, ilvl=65), 20069: it('Eisenborkenstab', q=4, req=60, ilvl=70),
            280001: it('Hoher Forever-Dolch', q=4, req=60, ilvl=80), 274999: it('Hat schon eine Quelle'),
            99007: it('Testament des Lichts', q=3, req=30, ilvl=35)}
    rows, dropped = build_gear.no_source(scan, {274999}, keys, {'classes': {'274998': 16}, 'delay': {'274998': 1800}})
    assert set(rows) == {274998, 275836, 19324, 280001, 99007}, sorted(rows)
    it0, level, mask, speed, st = rows[274998]
    assert (level, mask, speed) == (40, 16, 1.8) and st == 'STAMINA=9;INTELLECT=5'
    assert rows[275836][1] == 52, 'required level 0: the item level less five, kept'
    names = {k: sorted(n for _, n in v) for k, v in dropped.items()}
    assert len(names['junk']) == 13 and 'Template Item' in names['junk'] and '63 Green Rogue Spaulders' in names['junk']
    assert names['quality'] == ['Grauer Dolch'] and names['raid level'] == ['Eisenborkenstab']
    assert names['no stats'] == ['Nur Proc', 'Ohne Werte']
    assert names['not gear'] == [], 'a bag or shirt is no gear and not worth a word'
    assert 274999 not in rows, 'an item a source names is never in both files'


def test_an_item_that_gets_a_source_leaves_the_no_source_file(tmp_path):
    """No duplicates: once a kill record, a quest reward or AllTheThings names an item, it is a normal entry
    of GearData.lua and GearNoSource.lua no longer holds it."""
    keys = build_gear.scored_stat_keys()
    dagger = dict(scan_item('Schattenlichtathame', loc='INVTYPE_WEAPONMAINHAND', cls=2, q=3, lvl=40),
                  stats='STAMINA_SHORT=9;INTELLECT_SHORT=5;SPELL_POWER_SHORT=52')
    scan = {274998: dagger}
    src, keep, *_ = build_gear.build(scan, {}, att())
    rows, _ = build_gear.no_source(scan, src.named, keys)
    assert 274998 not in keep and 274998 in rows
    cases = [
        ('a kill record', {274998: ['Drop: Twilight Commander Zarmok [261001] @Krol\'dok Stronghold #party:2998']}, att(), None),
        ('a quest reward', {}, att(), build_gear.scan_quest_rewards(scanned_quests({600: 'Neue Quest\t41\t0\t\t0\t\t274998'}))),
        ('AllTheThings', {}, att(quests={700: quest('Q', 40, rewards=[274998])}), None),
    ]
    for why, collected, a, scanned in cases:
        src, keep, zone_rows, *_ = build_gear.build(scan, collected, a, scanned=scanned)
        rows, _ = build_gear.no_source(scan, src.named, keys)
        assert 274998 in keep and 274998 not in rows, why
    out = tmp_path / 'GearNoSource.lua'
    rows, _ = build_gear.no_source({274998: dagger, 275836: dict(dagger, name='Akolythenklinge', min=0)}, set(), keys)
    build_gear.write_no_source(str(out), rows, {'built': '2026-11-10', 'client': [[1, 274998]]})
    text = out.read_text(encoding='utf-8')
    assert text.startswith('-- GENERATED by tools/build_gear.py') and 'ns.LazyData("GEAR_NOSRC"' in text
    body = lua_data.eager(text).replace(' ', '')
    assert '[274998]={"WEAPONMAINHAND",2,2,40,3,1,45,0,0,0}' in body, body
    assert '[274998]="STAMINA=9;INTELLECT=5;SPELL_POWER=52"' in body
    assert '[275836]="Akolythenklinge"' in body and '[274998]="Schattenlichtathame"' not in body, \
        'names only for items the client lacks'
