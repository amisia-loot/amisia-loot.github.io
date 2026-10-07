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
ADDON = os.path.join(ROOT, 'addon', 'Amisia')
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
    names = set(re.findall(r'\{"D", "((?:[^"\\]|\\.)*)"', gear))
    # Q {name, quest level, minimum level, faction, zone, quest id, class mask, dungeon}
    for m in re.finditer(r'\{"Q", "(?:[^"\\]|\\.)*", [^\n]*?, "((?:[^"\\]|\\.)*)"\},', gear):
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
    d_recs = set(re.findall(r'\{"D", "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"', gear))
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
    assert [e['key'] for e in entries() if e.get('part')] == ['lbrs', 'ubrs']
    text = build_dungeons.render(facts())
    assert 'aliases = { "Blackrock Spire" }, part = "Blackrock Spire" }' in text
    assert '{ key = "ubrs", name = "Upper Blackrock Spire", kind = "party", lvl = 53, inst = 229, part = "Blackrock Spire" },' in text
    assert '_src' not in text, 'the labels stay in the JSON'


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
    assert len(classic) >= 18, len(classic)
    for e in classic:
        assert e['kind'] == 'party' and e.get('min') is None and e.get('max') is None, e
        assert e['name'] in names or any(a in names for a in e.get('aliases', [])), e['name']


def test_every_dungeon_the_data_names_has_an_entry():
    known = set()
    for e in entries():
        known.add(e['name'])
        known.update(e.get('aliases', []))
    missing = sorted(n for n in repo_names() - NOT_DUNGEONS if n not in known)
    assert not missing, missing


def test_no_loot_table_and_no_link():
    text = open(FACTS, encoding='utf-8').read()
    for e in entries():
        assert not set(e) - {'key', 'name', 'kind', 'src', 'min', 'max', 'size', 'inst', 'area', 'from', 'bosses',
                              'aliases', 'part', 'bosses_src', 'aliases_src', 'inst_src'}, e
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
    assert set(c['tables']) == {'LFGDungeons', 'ContentTuning', 'AreaTable'}
    assert set(c['dungeons']) <= keys
    for k, v in c['dungeons'].items():
        assert set(v) <= {'lvl', 'inst', 'lfg'}, v
        assert v.get('lvl') is None or 1 <= v['lvl'] <= 60, (k, v)
    by = {e['key']: e for e in entries()}
    # the client's level is the low end of the public range wherever both are known
    both = [k for k, v in c['dungeons'].items() if v.get('lvl') and by[k].get('min') is not None and by[k]['kind'] == 'party']
    assert len(both) >= 4 and all(c['dungeons'][k]['lvl'] == by[k]['min'] for k in both), both
    assert c['dungeons']['deadmines'] == {'lvl': 16, 'lfg': ['Deadmines'], 'inst': 36}
    assert c['dungeons']['dire']['lfg'] == ['Dire Maul - East', 'Dire Maul - West', 'Dire Maul - North']
    assert c['dungeons']['lbrs']['inst'] == c['dungeons']['ubrs']['inst'] == 229, 'one instance, two dungeons'
    assert build_dungeons.conflicts(facts(), c) == []


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
                           'AreaTable': 'AreaTable.1.60.1.10.csv'}
    d = c['dungeons']
    assert d['halls'] == {'lvl': 13, 'lfg': ['Test Halls'], 'inst': 4777}
    assert d['wing'] == {'lvl': 40, 'lfg': ['Test Wing - East', 'Test Wing - West'], 'inst': 4020}, 'the wings count for the dungeon'
    assert d['stock'] == {'lvl': 23, 'lfg': ['Stormwind Stockades']}, "the client's own spelling"
    assert d['raid'] == {'inst': 4003} and d['upper'] == {'inst': 4003}, 'the instance of its part'
    assert c['unmatched'] == ['Unknown Place'], 'zones and battlegrounds are no dungeons'
    merged = {e['key']: e for e in build_dungeons.merge(facts_, c)}
    assert merged['halls']['lvl'] == 13 and merged['halls']['min'] == 13 and merged['raid']['inst'] == 999, 'the facts win'
    assert merged['wing']['inst'] == 4020 and 'lvl' not in facts_['dungeons'][1], 'the facts stay as they are'
    assert build_dungeons.conflicts(facts_, c) == ['Test Raid: instance 4003 in the client, 999 in the facts']
    text = build_dungeons.render({'checked': 'x', 'dungeons': facts_['dungeons']}, c)
    assert '{ key = "wing", name = "Test Wing", kind = "party", lvl = 40, inst = 4020 },' in text
    assert build_dungeons.render({'checked': 'x', 'dungeons': facts_['dungeons'][:1]}, {'dungeons': {}}).count('lvl') == 1, \
        'without the client file no level (only the header names it)'


def test_without_client_tables_the_build_stops(tmp_path):
    with pytest.raises(SystemExit):
        build_dungeons.main(['--wago', str(tmp_path)])
