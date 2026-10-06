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
OUT = os.path.join(ADDON, 'DungeonData.lua')

# What Blizzard and the public dungeon list say about Forever's new instances (checked 2026-10-05).
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
    with open(os.path.join(ADDON, 'GearData.lua'), encoding='utf-8') as fh:
        gear = fh.read()
    with open(os.path.join(ADDON, 'MapData.lua'), encoding='utf-8') as fh:
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
        if e.get('min') is not None or e.get('max') is not None:
            assert 1 <= e['min'] <= e['max'] <= 60, e


def test_the_new_dungeons_and_their_level_ranges():
    by = {e['name']: e for e in entries()}
    for name, (lo, hi) in NEW.items():
        e = by[name]
        assert e['kind'] == 'party' and (e['min'], e['max']) == (lo, hi) and e['src'] == 'forever', e
    for name, bosses in BOSSES.items():
        assert by[name]['bosses'] == bosses
    # what the item data calls the excavation site
    assert 'Excavation Site: Wetlands' in by['Excavation Site']['aliases']


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
                              'aliases'}, e
    assert 'http' not in text and 'www.' not in text
    text.encode('latin-1')


def test_the_generated_file_is_current_and_deterministic():
    data = facts()
    one = build_dungeons.render(data)
    assert one == build_dungeons.render(facts()), 'the same input gives the same file'
    with open(OUT, encoding='utf-8') as fh:
        assert fh.read() == one, 'DungeonData.lua is behind: python tools/build_dungeons.py'
    assert one.startswith('-- GENERATED by tools/build_dungeons.py from tools/forever_dungeons.json.')
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
    assert 'DungeonData.lua [AllowLoadGameType camelot]' in lines
    names = [re.sub(r'\s*\[.*\]', '', l) for l in lines]
    assert names.index('MapData.lua') < names.index('DungeonData.lua') < names.index('Dungeons.lua')
    assert names.index('Bis.lua') < names.index('Dungeons.lua') < names.index('Pages\\Gear.lua')
