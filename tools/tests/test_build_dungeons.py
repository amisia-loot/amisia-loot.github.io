"""tools/forever_dungeons.json and tools/build_dungeons.py: the hand-kept dungeon and raid facts
(public facts only, every fact with its source), their coverage of the dungeon names the repo's
own data uses, and the generated DungeonData.lua (current, deterministic, valid Lua, in the TOC)."""
import json
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'Amisia')
sys.path.insert(0, TOOLS)
import build_dungeons  # noqa: E402

FACTS = os.path.join(TOOLS, 'forever_dungeons.json')
CLIENT = os.path.join(TOOLS, 'forever_dungeons_client.json')
WAGO = os.path.join(HERE, 'fixtures', 'wago')
OUT = os.path.join(ADDON, 'Data', 'DungeonData.lua')

# The public facts on Forever's new instances as the user gave them (2026-10-05); the boss lists are
# the item data's (GearData.lua), see test_every_label_says_where_its_facts_can_be_checked.
NEW = {
    'Hall of Thanes': (13, 18), 'Ruins of Lordaeron': (15, 20), 'Excavation Site': (26, 31),
    'City of Dalaran': (28, 33), 'Drowned City': (35, 40), "Krol'dok Stronghold": (40, 45),
    'Alcaz Prison': (48, 53), 'Blackmaw Hold': (55, 60), "Shaper's Terrace": (58, 60),
}
BOSSES = {
    'Hall of Thanes': ['Faldrim Anvilmar', 'Magmatus', 'Plunder', 'Durgen Dirgehammer'],
    'Ruins of Lordaeron': ['The Baron', 'Witherfang', 'The Abandoned', 'Bjork', "Rath'mael", 'Viktor the Vile'],
}
RAIDS = {'Barrow Deeps': 10, 'Hyjal Summit': 20, "Onyxia's Lair": 40}
# battlegrounds are no dungeons, even where the item data names them like one
NOT_DUNGEONS = {'Alterac Valley'}


def facts():
    with open(FACTS, encoding='utf-8') as fh:
        return json.load(fh)


def entries():
    return facts()['dungeons']


def repo_names():
    """Dungeon names the repo's own data uses: the item data's dungeon sources and dungeon quests,
    and the map data's entrances."""
    with open(os.path.join(ADDON, 'Data', 'GearData.lua'), encoding='utf-8') as fh:
        gear = fh.read()
    with open(os.path.join(ADDON, 'Data', 'MapData.lua'), encoding='utf-8') as fh:
        mapdata = fh.read()
    names = set(re.findall(r'\{"D",\s*"((?:[^"\\]|\\.)*)"', gear))
    # Q {name, quest level, minimum level, faction, zone, quest id, class mask, dungeon}
    for m in re.finditer(r'\{"Q",\s*"(?:[^"\\]|\\.)*",[^\n]*?,\s*"((?:[^"\\]|\\.)*)"\},', gear):
        names.add(m.group(1))
    names |= set(re.findall(r'\["N:((?:[^"\\]|\\.)*)"\]', mapdata))
    return {n.replace("\\'", "'") for n in names} - {'A', 'H'}


def test_every_entry_has_its_fields_and_a_known_source():
    f = facts()
    sources = f['sources']
    assert f['checked'] == '2026-10-05'
    keys = set()
    for e in entries():
        assert re.match(r'^[a-z][a-z0-9]*$', e['key']), e
        assert e['key'] not in keys, e['key']
        keys.add(e['key'])
        assert e['kind'] in ('party', 'raid'), e
        assert e['src'] in sources and sources[e['src']], e
        for k, v in e.items():
            if k.endswith('_src'):
                assert k[:-4] in e and v in sources and sources[v], (k, e)
        if e.get('min') is not None or e.get('max') is not None:
            assert 1 <= e['min'] <= e['max'] <= 60, e


def test_the_new_dungeons_and_their_level_ranges():
    by = {e['name']: e for e in entries()}
    for name, (lo, hi) in NEW.items():
        e = by[name]
        assert e['kind'] == 'party' and (e['min'], e['max']) == (lo, hi) and e['src'] == 'public', e
    for name, bosses in BOSSES.items():
        assert by[name]['bosses'] == bosses
    # what the item data calls the excavation site
    assert 'Excavation Site: Wetlands' in by['Excavation Site']['aliases']


def test_every_label_says_where_its_facts_can_be_checked():
    """A boss list labelled as the repo's item data is exactly what that data says: each boss is a
    dungeon source of GearData.lua for that dungeon. Nothing is labelled as from Blizzard."""
    sources = facts()['sources']
    assert 'forever' not in sources and 'Blizzard' not in json.dumps(sources), 'no claim the repo cannot back'
    with open(os.path.join(ADDON, 'Data', 'GearData.lua'), encoding='utf-8') as fh:
        gear = fh.read()
    d_recs = set(re.findall(r'\{"D",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"', gear))
    d_recs = {(a.replace("\\'", "'"), b.replace("\\'", "'")) for a, b in d_recs}
    names = repo_names()
    labelled = 0
    for e in entries():
        if e.get('bosses'):
            assert e.get('bosses_src') == 'repo:GearData', e
            for b in e['bosses']:
                assert (e['name'], b) in d_recs, (e['name'], b)
            labelled += 1
        if e.get('aliases_src') == 'repo:GearData':
            assert all(a in names for a in e['aliases']), e
    assert labelled == 2


def test_blackrock_spire_hosts_two_dungeons():
    by = {e['key']: e for e in entries()}
    assert by['lbrs']['part'] == by['ubrs']['part'] == 'Blackrock Spire'
    assert [e['key'] for e in entries() if e.get('part')] == ['smgy', 'smlib', 'smarm', 'smcath', 'lbrs', 'ubrs']
    text = build_dungeons.render(facts())
    # the rares of the half (F-180) may follow the part
    assert 'aliases = { "Blackrock Spire" }, part = "Blackrock Spire"' in text
    assert re.search(r'\{ key = "ubrs", name = "Upper Blackrock Spire", kind = "party", lvl = 53, inst = 229, (order = \{[^}]*\}, enc = \{[^}]*\}, '
                     r'(npcs = \{[^}]*\}, )?)?part = "Blackrock Spire"( \}|, rares = )', text)
    # each half only its own bosses of the instance's order (att_wing, D-106; before: one shared order with false)
    c = client()['dungeons']
    assert c['lbrs']['order'][0] == 'Highlord Omokk' and c['lbrs']['order'][-1] == 'Overlord Wyrmthalak'
    assert c['ubrs']['order'] == ['Pyroguard Emberseer', 'Warchief Rend Blackhand', 'The Beast', 'General Drakkisath', 'Lord Valthalak']
    assert not set(c['lbrs']['order']) & set(c['ubrs']['order']) and not set(c['lbrs']['enc']) & set(c['ubrs']['enc'])
    assert ', npcs = { 9196, 9236, 9237, 10596, 10584, 9736, 10220, 10268, 9568 }, ' in text and 'false' not in text
    assert '_src' not in text, 'the labels stay in the JSON'


SM_WINGS = (('smgy', 'Graveyard', 'Friedhof', 30, 38), ('smlib', 'Library', 'Bibliothek', 33, 41),
            ('smarm', 'Armory', 'Waffenkammer', 36, 44), ('smcath', 'Cathedral', 'Kathedrale', 38, 46))


def test_the_scarlet_monastery_is_four_dungeons():
    """F-174, D-106: the four wings with the user's level ranges, ATT's headers, one map and area, each its own
    bosses in the game's order with their encounters and NPCs; the key on the Armory and the Cathedral."""
    by = {e['key']: e for e in entries()}
    assert 'sm' not in by
    for key, wing, _, lo, hi in SM_WINGS:
        e = by[key]
        assert e['name'] == 'Scarlet Monastery: ' + wing and e['aliases'] == ['Scarlet Monastery - ' + wing], e
        assert (e['min'], e['max']) == (lo, hi) and e['min_src'] == e['max_src'] == 'screenshot:sm'
        assert e['part'] == 'Scarlet Monastery' and e['att_wing'] == e['wing'] == wing and e['part_area'] == 796
    assert 'Nutzer 2026-11-10 (Bildschirmfoto)' in facts()['sources']['screenshot:sm']
    c = client()['dungeons']
    assert c['smgy']['order'] == ['Interrogator Vishas', 'Bloodmage Thalnos'] and c['smgy']['enc'] == [444, 2779]
    assert c['smlib']['order'] == ['Houndmaster Loksey', 'Arcanist Doan'] and c['smlib']['enc'] == [446, 447]
    assert c['smarm']['order'] == ['Herod'] and c['smarm']['enc'] == [448]
    assert c['smcath']['order'] == ['High Inquisitor Fairbanks', 'High Inquisitor Whitemane'] and c['smcath']['enc'] == [449, 450]
    assert c['smgy']['npcs'] == [3983, 4543] and c['smcath']['npcs'] == [4542, 3977]
    for key, *_ in SM_WINGS:
        assert c[key]['inst'] == 189 and c[key]['lvl'] == 30 and c[key]['lfg'] == ['Scarlet Monastery'], \
            "one map and one LFGDungeons row for the whole instance"
    text = build_dungeons.render(facts())
    assert ('{ key = "smarm", name = "Scarlet Monastery: Armory", kind = "party", min = 36, max = 44, lvl = 30, inst = 189, '
            'order = { "Herod" }, enc = { 448 }, npcs = { 3975 }, aliases = { "Scarlet Monastery - Armory" }, '
            'part = "Scarlet Monastery", wing = "Armory", part_area = 796, keys = { { item = 7146, need = "required", why = "door" } } },') in text
    assert 'key = "smgy"' in text and 'keys' not in text.split('key = "smgy"')[1].split('\n')[0], 'the Graveyard needs no key'


def test_no_boss_of_the_old_scarlet_monastery_is_lost():
    """Against the one dungeon before F-174 (fixture): every boss of its order in exactly one wing, in the same
    order, with its encounter and NPC; every boss NPC of the build in a wing; every item of a boss with its wing;
    every quest in at least one wing."""
    with open(os.path.join(HERE, 'fixtures', 'scarlet_monastery_2026-11-10.json'), encoding='utf-8') as fh:
        old = json.load(fh)
    c = client()['dungeons']
    keys = [k for k, *_ in SM_WINGS]
    order = [n for k in keys for n in c[k]['order']]
    assert order == old['order'], 'the same bosses in the same order, wing after wing'
    assert [x for k in keys for x in c[k]['enc']] == old['enc'] and [x for k in keys for x in c[k]['npcs']] == old['npcs']
    with open(os.path.join(ADDON, 'Data', 'BisData.lua'), encoding='utf-8') as fh:
        bis = fh.read()
    npcs = {}
    for line in bis.splitlines():
        key, names = re.search(r'\bkey = "([a-z0-9]+)"', line), re.search(r'\bbossNames = \{ (.*?) \}, bosses = ', line)
        if key and key.group(1) in keys and names:
            for i, n in re.findall(r'\[(\d+)\] = "((?:[^"\\]|\\.)*)"', names.group(1)):
                assert i not in npcs, ('one wing per NPC', i)
                npcs[i] = (key.group(1), n)
    assert {i: n for i, (_, n) in npcs.items()} == old['bossNames'], 'every boss NPC of the build, under its name'
    assert npcs['3976'][0] == 'smcath' and npcs['6489'][0] == 'smgy', 'Mograine in the Cathedral, the rares in the Graveyard'
    with open(os.path.join(ADDON, 'Data', 'GearData.lua'), encoding='utf-8') as fh:
        gear = fh.read()
    recs = set(re.findall(r'\{"D","Scarlet Monastery: (\w+)","((?:[^"\\]|\\.)*)"', gear))
    wing_of = {}
    for wing, boss in recs:
        wing_of.setdefault(boss.replace("\\'", "'"), set()).add(wing)
    for boss in old['loot']:
        assert boss in wing_of, boss
        assert len(wing_of[boss]) == 1 or boss == 'Trash', (boss, wing_of[boss])
    assert wing_of['Trash'] == {'Graveyard', 'Library', 'Armory', 'Cathedral'}, 'each wing page lists its trash'
    assert '{"D","Scarlet Monastery",' not in gear and ',"Scarlet Monastery"},' not in gear, 'no source names the old dungeon'
    with open(os.path.join(ADDON, 'Data', 'DungeonQuestData.lua'), encoding='utf-8') as fh:
        dq = fh.read()
    listed = set()
    for k in keys:
        listed |= {int(x) for x in re.search(r'\b' + k + r' = \{ ([\d, ]+) \}', dq).group(1).split(', ')}
    assert listed == set(old['quests'])


def test_the_raids_open_on_the_ninth_of_december():
    by = {e['name']: e for e in entries()}
    for name, size in RAIDS.items():
        e = by[name]
        assert e['kind'] == 'raid' and e['size'] == size and e['from'] == '2026-12-09', e
    assert by["Onyxia's Lair"]['inst'] == 249 and by["Onyxia's Lair"]['area'] == 2159, 'from forever_zones.json'
    assert len([e for e in entries() if e['kind'] == 'raid']) == 3, 'no other raid on Forever yet'


def test_classic_dungeons_come_from_the_repo_and_wait_for_the_client_table():
    names = repo_names()
    sources = facts()['sources']
    assert 'LFGDungeons' in sources['repo'], 'says where the levels will come from'
    classic = [e for e in entries() if e['src'] == 'repo']
    assert len(classic) >= 17, len(classic)
    for e in classic:
        assert e['kind'] == 'party' and e.get('min') is None and e.get('max') is None, e
        assert e['name'] in names or any(a in names for a in e.get('aliases', [])), e['name']


def test_every_dungeon_the_data_names_has_an_entry():
    known = set()
    for e in entries():
        known.add(e['name'])
        known.update(e.get('aliases', []))
        # the instance of several dungeons by its own name (the entrances, the zone's trash; D-106)
        if e.get('part'):
            known.add(e['part'])
    missing = sorted(n for n in repo_names() - NOT_DUNGEONS if n not in known)
    assert not missing, missing


def test_no_loot_table_and_no_link():
    text = open(FACTS, encoding='utf-8').read()
    for e in entries():
        assert not set(e) - {'key', 'name', 'kind', 'src', 'min', 'max', 'size', 'inst', 'area', 'from', 'bosses',
                              'aliases', 'part', 'bosses_src', 'aliases_src', 'inst_src', 'order', 'order_src', 'enc',
                              'enc_src', 'boss_alias', 'boss_alias_src', 'att_wing', 'att_wing_src', 'min_src', 'max_src',
                              'wing', 'part_area', 'part_area_src'}, e
        # a boss alias names another boss name, never an NPC id (the ids come from AllTheThings, D-100)
        assert all(isinstance(a, str) and isinstance(b, str) for a, b in (e.get('boss_alias') or {}).items()), e
    assert 'http' not in text and 'www.' not in text
    text.encode('latin-1')


def test_the_generated_file_is_current_and_deterministic():
    data = facts()
    one = build_dungeons.render(data)
    assert one == build_dungeons.render(facts()), 'the same input gives the same file'
    with open(OUT, encoding='utf-8') as fh:
        assert fh.read() == one, 'DungeonData.lua is behind: python tools/build_dungeons.py'
    assert one.startswith('-- GENERATED by tools/build_dungeons.py from tools/forever_dungeons.json and\n'
                          '-- tools/forever_dungeons_client.json.')
    assert 'IsForever' not in one and 'then return end' not in one, 'no guard: the TOC loads it on Forever only'
    one.encode('latin-1')


def test_the_generated_file_is_valid_lua():
    lupa = pytest.importorskip('lupa.lua51')
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{}')
    with open(OUT, encoding='utf-8') as fh:
        chunk = lua.eval('function(s) return assert(loadstring(s)) end')(fh.read())
    chunk('Amisia', ns)
    f = ns.DUNGEON_FACTS
    assert f.checked == '2026-10-05'
    n = len(entries())
    assert len(f.list) == n
    first = entries()[0]
    assert f.list[1].key == first['key'] and f.list[1].name == first['name']
    ony = [f.list[i] for i in range(1, n + 1) if f.list[i].key == 'onyxia'][0]
    assert ony.inst == 249 and ony.size == 40 and ony['from'] == '2026-12-09' and ony.kind == 'raid'
    thanes = [f.list[i] for i in range(1, n + 1) if f.list[i].key == 'thanes'][0]
    assert thanes.min == 13 and thanes.max == 18 and thanes.bosses[1] == 'Faldrim Anvilmar'


def test_the_toc_loads_the_facts_on_forever_and_the_planner_after_bis():
    with open(os.path.join(ADDON, 'Amisia.toc'), encoding='utf-8') as fh:
        lines = [l.strip() for l in fh if l.strip() and not l.startswith('#')]
    assert 'Data\\DungeonData.lua [AllowLoadGameType camelot]' in lines
    names = [re.sub(r'\s*\[.*\]', '', l) for l in lines]
    assert names.index('Data\\MapData.lua') < names.index('Data\\DungeonData.lua') < names.index('Gear\\Dungeons.lua')
    assert names.index('Gear\\Bis.lua') < names.index('Gear\\Dungeons.lua') < names.index('UI\\Pages\\Gear.lua')


# --- the client tables (tools/forever_dungeons_client.json, build_dungeons.py --wago)

def client():
    with open(CLIENT, encoding='utf-8') as fh:
        return json.load(fh)


def test_the_client_levels_and_instance_ids():
    c = client()
    keys = {e['key'] for e in entries()}
    assert set(c['tables']) == {'LFGDungeons', 'ContentTuning', 'AreaTable', 'DungeonEncounter', 'UiMapAssignment'}
    assert set(c['dungeons']) <= keys
    by = {e['key']: e for e in entries()}
    for k, v in c['dungeons'].items():
        assert set(v) <= {'lvl', 'inst', 'lfg', 'order', 'enc', 'npcs', 'npcs_scan', 'order_src', 'maps', 'rares'}, v
        assert v.get('order_src') in (None, 'att'), (k, v)
        if 'npcs' in v:
            order = v.get('order') or by[k].get('order')
            assert len(v['npcs']) == len(order), (k, v)
        assert v.get('lvl') is None or 1 <= v['lvl'] <= 60, (k, v)
    by = {e['key']: e for e in entries()}
    # the client's level is the low end of the public range wherever both are known; Shaper's Terrace
    # alone is tuned to the top of its range (60 of 58-60, build 1.60.1.70888; the range stays the facts', D-101);
    # the Scarlet Monastery's wings have the level of the whole instance (30), their ranges are the user's (D-106)
    both = [k for k, v in c['dungeons'].items() if v.get('lvl') and by[k].get('min') is not None and by[k]['kind'] == 'party']
    assert len(both) >= 13, both
    assert [k for k in both if c['dungeons'][k]['lvl'] != by[k]['min']] == ['shaper', 'smarm', 'smcath', 'smlib'], both
    assert c['dungeons']['shaper']['lvl'] == by['shaper']['max'] == 60
    # (its rares, F-180, are AllTheThings' and may change with its data: test_the_rares_... checks their form)
    assert {k: v for k, v in c['dungeons']['deadmines'].items() if k != 'rares'} == {'lvl': 16, 'lfg': ['Deadmines'], 'inst': 36, 'order': [
        "Rhahk'Zor", 'Sneed', 'Miner Johnson', 'Gilnid', 'Captain Greenskin', 'Mr. Smite', 'Cookie', 'Edwin VanCleef'],
        'enc': [2741, 2742, 3676, 2743, 2744, 2745, 2746, 2747],
        'npcs': [644, 643, 3586, 1763, 647, 646, 645, 639]}, \
        "the bosses in the game's order (F-139)"
    assert c['dungeons']['dire']['lfg'] == ['Dire Maul - East', 'Dire Maul - West', 'Dire Maul - North']
    assert c['dungeons']['lbrs']['inst'] == c['dungeons']['ubrs']['inst'] == 229, 'one instance, two dungeons'
    assert build_dungeons.conflicts(facts(), c) == ["Shaper's Terrace: level 60 in the client, 58 in the facts"]


def test_reading_the_client_tables():
    facts_ = {'dungeons': [
        {'key': 'halls', 'name': 'Test Halls', 'kind': 'party', 'min': 13, 'max': 18},
        {'key': 'wing', 'name': 'Test Wing', 'kind': 'party'},
        {'key': 'stock', 'name': 'The Stockade', 'kind': 'party'},
        {'key': 'raid', 'name': 'Test Raid', 'kind': 'raid', 'inst': 999},
        {'key': 'upper', 'name': 'Upper Test', 'kind': 'party', 'part': 'Test Raid'},
    ]}
    c = build_dungeons.client_facts(facts_, [WAGO])
    assert c['tables'] == {'LFGDungeons': 'LFGDungeons.1.60.1.10.csv', 'ContentTuning': 'ContentTuning.1.60.1.10.csv',
                           'AreaTable': 'AreaTable.1.60.1.10.csv', 'DungeonEncounter': 'DungeonEncounter.1.60.1.10.csv'}
    d = c['dungeons']
    assert d['halls'] == {'lvl': 13, 'lfg': ['Test Halls'], 'inst': 4777, 'order': ['First Boss', 'Second Boss', 'Third Boss'],
                          'enc': [10, 11, 12]}, \
        'by OrderIndex, difficulties 0 and 1 together, each name once (its first row\'s encounter id), never another difficulty (F-139)'
    assert d['wing'] == {'lvl': 40, 'lfg': ['Test Wing - East', 'Test Wing - West'], 'inst': 4020, 'order': ['Wing Boss', 'Wing Boss B'],
                         'enc': [30, 31]}, \
        'the wings count for the dungeon; without a normal difficulty the one with the most bosses'
    assert d['stock'] == {'lvl': 23, 'lfg': ['Stormwind Stockades']}, "the client's own spelling"
    assert d['raid'] == {'inst': 4003, 'order': ['Raid Boss'], 'enc': [20]} and d['upper'] == {'inst': 4003}, \
        "the instance of its part; the order by the facts' own instance"
    assert c['unmatched'] == ['Unknown Place'], 'zones and battlegrounds are no dungeons'
    merged = {e['key']: e for e in build_dungeons.merge(facts_, c)}
    assert merged['halls']['order'] == ['First Boss', 'Second Boss', 'Third Boss']
    assert merged['halls']['lvl'] == 13 and merged['halls']['min'] == 13 and merged['raid']['inst'] == 999, 'the facts win'
    assert merged['wing']['inst'] == 4020 and 'lvl' not in facts_['dungeons'][1], 'the facts stay as they are'
    assert build_dungeons.conflicts(facts_, c) == ['Test Raid: instance 4003 in the client, 999 in the facts']
    text = build_dungeons.render({'checked': 'x', 'dungeons': facts_['dungeons']}, c, {})
    assert ('{ key = "wing", name = "Test Wing", kind = "party", lvl = 40, inst = 4020, order = { "Wing Boss", "Wing Boss B" }, '
            'enc = { 30, 31 } },') in text
    assert build_dungeons.render({'checked': 'x', 'dungeons': facts_['dungeons'][:1]}, {'dungeons': {}}, {}).count('lvl') == 1, \
        'without the client file no level (only the header names it)'


def test_without_client_tables_the_build_stops(tmp_path):
    with pytest.raises(SystemExit):
        build_dungeons.main(['--wago', str(tmp_path)])


# ---------------------------------------------------------------- AllTheThings' encounters (F-170, D-100)
def fake_att():
    return {'instances': {10: {'name': 'The Test Halls', 'mapID': 4777}, 11: {'name': 'New Place', 'mapID': 4900},
                          12: {'name': 'Test Raid', 'mapID': 4003}},
            'encounters': {50: {'name': 'Second Boss', 'npcs': [9002], 'inst': 10},
                           3001: {'name': 'New One', 'npcs': [9101], 'inst': 11},
                           3002: {'name': 'New Pair', 'npcs': [9102, 9103], 'inst': 11},
                           3003: {'name': 'Raid Boss', 'npcs': [9201], 'inst': 12, 'wing': 'Upper'}},
            'npcs': {9001: {'name': 'First Boss', 'kinds': {'npc'}, 'inst': 10},
                     9003: {'name': 'Third Boss the Long', 'kinds': {'boss'}, 'inst': 10},
                     9101: {'name': 'New One', 'kinds': {'boss'}, 'inst': 11}}}


def test_the_bosses_npcs_and_the_order_of_a_dungeon_the_client_lacks():
    facts_ = {'dungeons': [
        {'key': 'halls', 'name': 'Test Halls', 'kind': 'party', 'min': 13, 'max': 18, 'boss_alias': {'Third Boss': 'Third Boss the Long'}},
        {'key': 'new', 'name': 'New Place', 'kind': 'party', 'inst': 4900},
        {'key': 'raid', 'name': 'Test Raid', 'kind': 'raid', 'inst': 999},
        {'key': 'upper', 'name': 'Upper Test', 'kind': 'party', 'part': 'Test Raid', 'att_wing': 'Lower'},
    ]}
    c = build_dungeons.client_facts(facts_, [WAGO], fake_att())
    d = c['dungeons']
    assert d['halls']['order'] == ['First Boss', 'Second Boss', 'Third Boss'] and d['halls']['npcs'] == [9001, 9002, 9003], \
        "the client's order, an NPC by name, by the encounter's name, by the facts' alias"
    assert d['new'] == {'order': ['New One', 'New Pair'], 'enc': [3001, 3002], 'order_src': 'att', 'npcs': [9101, 9102]}, \
        "no client rows: ATT's encounters in its order, a group by its first creature"
    assert d['upper']['npcs'] == [] and d['upper']['order'] == [], 'a boss of the other wing leaves the order (D-106)'
    merged = {e['key']: e for e in build_dungeons.merge(facts_, c)}
    assert merged['new']['order'] == ['New One', 'New Pair'] and merged['new']['npcs'] == [9101, 9102]
    text = build_dungeons.render({'checked': 'x', 'dungeons': facts_['dungeons']}, c, {})
    assert 'order = { "New One", "New Pair" }, enc = { 3001, 3002 }, npcs = { 9101, 9102 } },' in text
    assert 'false' not in text
    # without ATT as before: no npcs, no order of its own
    assert 'npcs' not in build_dungeons.client_facts(facts_, [WAGO])['dungeons']['halls']


def test_every_boss_of_the_order_has_its_npc():
    """Of the game's order of every dungeon only the bosses no source names stay without an NPC (D-100)."""
    c = client()['dungeons']
    by = {e['key']: e for e in entries()}
    missing = []
    for k, v in c.items():
        order = v.get('order') or by[k].get('order') or []
        missing += [f'{k}: {n}' for n, npc in zip(order, v.get('npcs') or []) if npc is not False and npc == 0]
    # Overseer Wrex (Alcaz Prison, 3403) and King Op (Shaper's Terrace, 3504) stand in the client's order since
    # build 1.60.1.70888 (D-101); AllTheThings has their encounters only as comments, without a creature. The NPC
    # scan (D-104) can fill them (npcs_scan names those it filled), so only these may stay without one
    assert set(missing) <= {'alcaz: Overseer Wrex', 'scholo: Lady Illucia Barov', 'shaper: King Op'}, missing
    for k, v in c.items():
        assert set(v.get('npcs_scan') or []) <= {'Overseer Wrex', 'Lady Illucia Barov', 'King Op'}, (k, v.get('npcs_scan'))
    # the new Forever dungeons: the game's own order and encounters from the client table (DungeonEncounter of
    # build 1.60.1.70888, D-101), no hand order and no order of AllTheThings any more
    drowned = c['drowned']
    assert 'order' not in by['drowned'] and drowned['inst'] == 2970 and drowned['lvl'] == 35
    assert drowned['order'] == ["Zul'Alai", "Var'Taka", 'Captain Dreadrise', 'Deathless Guardians', 'Primeval Elemental',
                                "Min'loth the Serpent"]
    assert drowned['enc'] == [3474, 3475, 3476, 3478, 3511, 3479]
    assert drowned['npcs'] == [258905, 258924, 260042, 260213, 273738, 260243]
    for k, inst in (('kroldok', 3039), ('alcaz', 2994), ('blackmaw', 2974), ('shaper', 3001)):
        assert 'order_src' not in c[k] and c[k]['inst'] == inst and c[k]['lvl'], k
        assert all(npc > 0 for name, npc in zip(c[k]['order'], c[k]['npcs']) if name not in ('Overseer Wrex', 'King Op')), k
    assert c['alcaz']['order'][0] == 'Overseer Wrex' and c['alcaz']['enc'][0] == 3403
    assert c['shaper']['order'][6] == 'King Op' and c['shaper']['enc'][6] == 3504


def test_the_sunken_temple_is_a_dungeon():
    """F-183, D-115: one entry catches every spelling (the item data's and the client's AreaTable "The Temple of
    Atal'Hakkar", AllTheThings' "The Temple of Atal'hakkar", the client's map and LFGDungeons name "Sunken Temple");
    the client gives its level, instance and the eight encounters; every boss has its NPC (Shade of Eranikus by
    AllTheThings' spelling, the dragons by the creatures of its encounter Wardens of the Dream)."""
    es = entries()
    keys = [e['key'] for e in es]
    assert keys.index('mara') < keys.index('st') < keys.index('alcaz'), 'among the dungeons of its level'
    st = es[keys.index('st')]
    assert st['name'] == "The Temple of Atal'Hakkar" and st['kind'] == 'party' and st['src'] == 'repo'
    assert st['aliases'] == ["The Temple of Atal'hakkar", 'Sunken Temple'] and st['aliases_src'] == 'client:st'
    assert st['boss_alias'] == {'Shade of Eranikus': 'Shade of Erankikus'} and st['boss_alias_src'] == 'att:alias'
    assert '2026-11-12' in facts()['sources']['client:st']
    assert 'min' not in st and 'max' not in st and 'order' not in st, 'the range and the order come from the client'
    c = client()['dungeons']['st']
    assert c['inst'] == 109 and c['lfg'] == ['Sunken Temple'] and isinstance(c['lvl'], int) and c['lvl'] > 0
    assert len(c['order']) == len(c['enc']) == len(c['npcs']) == 8 and 'order_src' not in c
    assert {"Atal'alarion", 'Avatar of Hakkar', 'Shade of Eranikus', 'Hazzas', 'Morphaz', 'Weaver', 'Dreamscythe',
            "Jammal'an the Prophet"} == set(c['order'])
    npc = dict(zip(c['order'], c['npcs']))
    assert npc['Shade of Eranikus'] == 5709 and npc['Hazzas'] == 5722 and npc['Morphaz'] == 5719 and npc['Weaver'] == 5720
    assert all(n > 0 for n in c['npcs']) and 'npcs_scan' not in c
    text = build_dungeons.render(facts())
    assert '{ key = "st", name = "The Temple of Atal\'Hakkar", kind = "party", lvl = ' in text
    assert 'inst = 109' in text.split('key = "st"')[1].split('\n')[0]


# ---------------------------------------------------------------- the rare mobs of a dungeon (F-180, D-112)
def test_the_rares_of_a_dungeon_come_from_allthethings_and_are_never_a_boss():
    att = fake_att()
    att['npcs'].update({
        9301: {'name': 'Odd Rare', 'kinds': {'rare'}, 'inst': 10},
        9302: {'name': 'Spire Thing (Rare)', 'kinds': {'rare'}, 'inst': 10},
        # a rare that is a boss of the order (by its NPC id, and by its name), a rare also filed as a boss
        9001: {'name': 'First Boss', 'kinds': {'rare'}, 'inst': 10},
        9304: {'name': 'Second Boss', 'kinds': {'rare'}, 'inst': 10},
        9305: {'name': 'Both', 'kinds': {'rare', 'boss'}, 'inst': 10},
        # an old one, one of another instance, the wings of an instance of several dungeons
        9306: {'name': 'Gone', 'kinds': {'rare'}, 'inst': 10, 'old': True},
        9307: {'name': 'Elsewhere', 'kinds': {'rare'}, 'inst': 11},
        9308: {'name': 'Lower Rare', 'kinds': {'rare'}, 'inst': 12, 'wing': 'Lower'},
        9309: {'name': 'Upper Rare', 'kinds': {'rare'}, 'inst': 12, 'wing': 'Upper'},
        9310: {'name': 'No Wing', 'kinds': {'rare'}, 'inst': 12},
    })
    facts_ = {'dungeons': [
        {'key': 'halls', 'name': 'Test Halls', 'kind': 'party', 'boss_alias': {'Third Boss': 'Third Boss the Long'}},
        {'key': 'lower', 'name': 'Lower Test', 'kind': 'party', 'part': 'Test Raid', 'att_wing': 'Lower'},
        {'key': 'raid', 'name': 'Test Raid', 'kind': 'raid', 'inst': 4003},
    ]}
    c = build_dungeons.client_facts(facts_, [WAGO], att)
    d = c['dungeons']
    assert d['halls']['rares'] == [[9301, 'Odd Rare'], [9302, 'Spire Thing']], d['halls'].get('rares')
    assert d['lower']['rares'] == [[9308, 'Lower Rare']], 'only the rares of its wing'
    assert d['raid']['rares'] == [[9308, 'Lower Rare'], [9309, 'Upper Rare'], [9310, 'No Wing']], 'one dungeon: every rare'
    assert 'rares' not in d.get('new', {}), 'no rares: no field'
    text = build_dungeons.render({'checked': 'x', 'dungeons': facts_['dungeons']}, c, {})
    assert 'rares = { { 9301, "Odd Rare" }, { 9302, "Spire Thing" } }' in text
    # without ATT no rares
    assert 'rares' not in build_dungeons.client_facts(facts_, [WAGO])['dungeons'].get('halls', {})


def test_the_rares_in_the_generated_facts_have_their_form():
    """Only the form: the list may grow with the next data build."""
    for k, v in client()['dungeons'].items():
        for r in v.get('rares') or []:
            assert isinstance(r, list) and len(r) == 2 and isinstance(r[0], int) and r[0] > 0, (k, r)
            assert isinstance(r[1], str) and r[1] and '(Rare)' not in r[1], (k, r)
            assert r[0] not in (v.get('npcs') or []), (k, r)
