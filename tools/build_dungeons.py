"""Builds Amisia/Data/DungeonData.lua from tools/forever_dungeons.json: the dungeons and raids of
WoW Forever for the addon's dungeon planner (Dungeons.lua).

The JSON file is kept by hand and holds facts only (names, level ranges, sizes, bosses known so
far, opening dates, instance ids), each entry with its source ("src", and "<field>_src" for a field
that comes from elsewhere, as boss lists read from the repo's item data); see its "sources" block.
tools/forever_dungeon_keys.json (kept by hand as well) adds the key and attunement items of a dungeon
(keys: item id, required or optional, what it opens, the quests that lead to it). Nothing is fetched.
Run it after changing either JSON file:

    python tools/build_dungeons.py [--wago [DIR ...]]

--wago reads the client tables (wago.tools CSV downloads, <Table>.csv or <Table>.<build>.csv, in
~/addons/_wago, then the copies ATT ships in ~/addons/_cache/att/.config/.wago) and rewrites
tools/forever_dungeons_client.json: per dungeon of the facts the level the client tunes it to
(LFGDungeons -> ContentTuning; one level, the minimum of the range where the public facts give one),
its instance id (AreaTable) and its bosses in the game's order (DungeonEncounter: the rows of the
instance, by OrderIndex; F-139) with their encounter ids (enc, one per name of order, what ENCOUNTER_END
and BOSS_KILL report) and the UI maps of its floors (UiMapAssignment: every uiMap of the instance's map
id; maps). Without --wago that file is read as it is. The hand facts win: the
client's values only fill what the JSON leaves open (lvl always; inst where the facts have none;
order, enc and maps always: the planner sorts the bosses it knows by order).

The generated table is ns.DUNGEON_FACTS. Once tools/build_bis.py writes ns.BIS.DG (task 2 of the
2.3 design: the same facts plus the level ranges of the client's LFGDungeons table and the bosses'
NPC ids), the planner takes that instead and this file can go.
"""
import argparse
import json
import os
import sys

import att_data

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FACTS = os.path.join(HERE, 'forever_dungeons.json')
CLIENT = os.path.join(HERE, 'forever_dungeons_client.json')
KEYS = os.path.join(HERE, 'forever_dungeon_keys.json')
OUT = os.path.join(ROOT, 'Amisia', 'Data', 'DungeonData.lua')
WAGO_DIRS = (os.path.expanduser('~/addons/_wago'), os.path.join(att_data.ATT_CACHE, '.config', '.wago'))

# LFGDungeons names that differ from the facts' names and aliases (the client's own spellings).
LFG_NAMES = {'Stormwind Stockades': 'The Stockade', "Zul'Farak": "Zul'Farrak", 'Onyxia': "Onyxia's Lair"}
# LFGDungeons types that are no dungeon: 4 an outdoor zone, 5 a battleground.
LFG_SKIP_TYPES = ('4', '5')

# Field order in the Lua table; anything else in the JSON (src and the <field>_src labels) is not
# written. part: the client's name of an instance that hosts several dungeons (Blackrock Spire).
# lvl: the level the client tunes the dungeon to (forever_dungeons_client.json).
# order: the bosses' English names in the game's order (DungeonEncounter, forever_dungeons_client.json);
# enc: their encounter ids, one per name of order. maps: the uiMap ids of the instance's floors.
# keys: the key and attunement items (forever_dungeon_keys.json), each with the fields of KEY_FIELDS.
FIELDS = ('key', 'name', 'kind', 'min', 'max', 'lvl', 'size', 'inst', 'area', 'from', 'bosses', 'order', 'enc',
          'maps', 'aliases', 'part', 'keys')
KEY_FIELDS = ('item', 'need', 'why', 'quests', 'questsA', 'questsH')
KEY_NEED = ('required', 'optional')
KEY_WHY = ('door', 'part', 'summon', 'attune', 'boss')


def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def lua_val(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return '{ ' + ', '.join(lua_val(x) for x in v) + ' }'
    if isinstance(v, dict):
        # the fields of a key item in KEY_FIELDS' order, empty lists left out
        return '{ ' + ', '.join(lua_key(k) + ' = ' + lua_val(v[k]) for k in KEY_FIELDS
                                if v.get(k) is not None and v.get(k) != []) + ' }'
    return lua_str(v)


def lua_key(k):
    # "from" is no Lua keyword, but a bracketed key reads the same in every Lua
    return k if k.isidentifier() else '[' + lua_str(k) + ']'


def _int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _keys(e):
    return {att_data.name_key(n) for n in [e['name']] + list(e.get('aliases') or []) if n}


def tuning_levels(rows):
    """{ContentTuning id: (min level, max level)} of ContentTuning rows: the squished levels
    (MinLevelSquish/MaxLevelSquish, Forever 1.60 and the other modern clients) or MinLevel/MaxLevel
    (tables of older builds). Forever gives every dungeon one level (min = max). Rows without a level
    are left out; the first row of an id wins. tools/build_bis.py reads the table through this too."""
    out = {}
    for row in rows:
        cid = _int(row.get('ID'))
        lo = _int(row.get('MinLevelSquish') or row.get('MinLevel'))
        hi = _int(row.get('MaxLevelSquish') or row.get('MaxLevel'))
        if cid is not None and cid not in out and lo:
            out[cid] = (lo, max(lo, hi or lo))
    return out


def client_facts(facts, dirs=WAGO_DIRS):
    """{'tables': {table: file name}, 'dungeons': {fact key: {'lvl', 'inst', 'lfg', 'order'}}, 'unmatched': [names]}
    from the client tables in dirs (the first folder holding a table wins, its newest build).

    lvl: LFGDungeons' ContentTuningID -> ContentTuning's MinLevelSquish (or MinLevel in tables of
    other builds); a dungeon split into wings ("Dire Maul - East") counts for the facts' dungeon.
    inst: the AreaTable row of the dungeon's name (an area at the top whose map is no continent).
    order: the DungeonEncounter rows of its instance (the facts' inst, else the client's) of the normal
    difficulty (0 and 1) by OrderIndex, each name once (only the first folder holding the table counts)."""
    tables = {}
    for t in ('LFGDungeons', 'ContentTuning', 'AreaTable', 'DungeonEncounter', 'UiMapAssignment'):
        for d in dirs:
            path = att_data.wago_csv(d, t)
            if path:
                tables[t] = os.path.basename(path)
                break
    tuning = {cid: lo for cid, (lo, _) in tuning_levels(att_data.wago_rows('ContentTuning', *dirs)).items()}
    by_key = {}
    for e in facts['dungeons']:
        for k in _keys(e):
            by_key.setdefault(k, e['key'])
    out, unmatched, seen = {}, [], set()
    for row in att_data.wago_rows('LFGDungeons', *dirs):
        lid = _int(row.get('ID'))
        if lid is None or lid in seen or row.get('TypeID') in LFG_SKIP_TYPES:
            continue
        seen.add(lid)
        raw = (row.get('Name_lang') or '').strip()
        name = LFG_NAMES.get(raw, raw)
        key = by_key.get(att_data.name_key(name)) or by_key.get(att_data.name_key(name.split(' - ')[0]))
        if key is None:
            unmatched.append(raw)
            continue
        lvl = tuning.get(_int(row.get('ContentTuningID')))
        if lvl:
            rec = out.setdefault(key, {})
            rec.setdefault('lvl', lvl)
            rec.setdefault('lfg', [])
            rec['lfg'].append(raw)
    _, by_name = att_data.read_area_instances(*dirs)
    for e in facts['dungeons']:
        names = [e['name']] + list(e.get('aliases') or []) + ([e['part']] if e.get('part') else [])
        inst = next((by_name[att_data.name_key(n)] for n in names if att_data.name_key(n) in by_name), None)
        if inst:
            out.setdefault(e['key'], {})['inst'] = inst
    if tables.get('DungeonEncounter'):
        folder = next(d for d in dirs if att_data.wago_csv(d, 'DungeonEncounter'))
        # per map and difficulty; the normal dungeon is difficulty 0 and 1 together (the client splits a
        # dungeon's bosses over both), other difficulties (198, 201: other versions of the dungeon) only
        # where a map has no normal one: then the difficulty with the most bosses
        groups = {}
        for row in att_data.wago_rows('DungeonEncounter', folder):
            mid, name = _int(row.get('MapID')), (row.get('Name_lang') or '').strip()
            if mid is not None and name:
                diff = _int(row.get('DifficultyID')) or 0
                diff = 0 if diff in (0, 1) else diff
                groups.setdefault(mid, {}).setdefault(diff, []).append(
                    (_int(row.get('OrderIndex')) or 0, _int(row.get('ID')) or 0, name))
        by_map = {mid: g[0] if 0 in g else max(g.values(), key=len) for mid, g in groups.items()}
        for e in facts['dungeons']:
            inst = e.get('inst') or (out.get(e['key']) or {}).get('inst')
            names, enc = [], []
            for _, eid, name in sorted(by_map.get(inst, [])):
                if name not in names:
                    names.append(name)
                    enc.append(eid)
            if names:
                out.setdefault(e['key'], {})['order'] = names
                out[e['key']]['enc'] = enc
    if tables.get('UiMapAssignment'):
        out_maps = uimap_floors(next(d for d in dirs if att_data.wago_csv(d, 'UiMapAssignment')))
        for e in facts['dungeons']:
            inst = e.get('inst') or (out.get(e['key']) or {}).get('inst')
            if out_maps.get(inst):
                out.setdefault(e['key'], {})['maps'] = out_maps[inst]
    return {'tables': tables, 'dungeons': {k: out[k] for k in sorted(out)}, 'unmatched': sorted(set(unmatched))}


def uimap_floors(folder):
    """{map id: [uiMap id, ...]} from the UiMapAssignment table in folder: every uiMap assigned to the
    map, in the order of its first assignment (smallest OrderIndex, then smallest row ID, then the uiMap
    id). The client keeps a dungeon's floors in that order (OrderIndex 0 the first floor). The tables of
    Forever 1.60.1 hold the outdoor zones and battlegrounds only (see att_data.read_uimap_instances), so
    there no dungeon gets floors yet."""
    first = {}
    for row in att_data.wago_rows('UiMapAssignment', folder):
        ui, mid = _int(row.get('UiMapID')), _int(row.get('MapID'))
        if ui is None or mid is None:
            continue
        rank = (_int(row.get('OrderIndex')) or 0, _int(row.get('ID')) or 0)
        if (mid, ui) not in first or rank < first[(mid, ui)]:
            first[(mid, ui)] = rank
    out = {}
    for (mid, ui), rank in sorted(first.items(), key=lambda kv: (kv[0][0], kv[1], kv[0][1])):
        out.setdefault(mid, []).append(ui)
    return out


def load_keys(path=KEYS):
    """{dungeon key: [key item, ...]} of forever_dungeon_keys.json (empty without the file)."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as fh:
        return json.load(fh).get('dungeons') or {}


def load_client(path=CLIENT):
    if not os.path.exists(path):
        return {'dungeons': {}}
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def merge(facts, client, keys=None):
    """The facts with the client's values filled in: lvl, and inst where the facts give none; order,
    enc and maps; the key items of keys (forever_dungeon_keys.json's dungeons). The hand facts never
    change. enc lines up with order: one encounter id per boss name."""
    cd = (client or {}).get('dungeons') or {}
    keys = keys or {}
    out = []
    for e in facts['dungeons']:
        c = cd.get(e['key']) or {}
        m = dict(e)
        if c.get('lvl') and m.get('lvl') is None:
            m['lvl'] = c['lvl']
        if c.get('inst') and m.get('inst') is None:
            m['inst'] = c['inst']
        if c.get('order') and m.get('order') is None:
            m['order'] = c['order']
            if c.get('enc'):
                m['enc'] = c['enc']
        if m.get('enc') is not None and len(m['enc']) != len(m.get('order') or []):
            raise ValueError('%s: %d encounter ids for %d bosses' % (e['key'], len(m['enc']), len(m.get('order') or [])))
        if c.get('maps'):
            m['maps'] = c['maps']
        if keys.get(e['key']):
            m['keys'] = [{k: v for k, v in item.items() if k in KEY_FIELDS} for item in keys[e['key']]]
        out.append(m)
    return out


def conflicts(facts, client):
    """Where the client and the hand facts disagree: a fact's minimum level or instance id."""
    cd = (client or {}).get('dungeons') or {}
    out = []
    for e in facts['dungeons']:
        c = cd.get(e['key']) or {}
        if c.get('lvl') and e.get('min') is not None and c['lvl'] != e['min']:
            out.append(f"{e['name']}: level {c['lvl']} in the client, {e['min']} in the facts")
        if c.get('inst') and e.get('inst') is not None and c['inst'] != e['inst']:
            out.append(f"{e['name']}: instance {c['inst']} in the client, {e['inst']} in the facts")
    return out


def render(facts, client=None, keys=None):
    """The Lua file for the facts (with the client's values and the key items, see merge()), always
    the same text for the same input."""
    if client is None:
        client = load_client()
    if keys is None:
        keys = load_keys()
    lines = [
        '-- GENERATED by tools/build_dungeons.py from tools/forever_dungeons.json and',
        '-- tools/forever_dungeons_client.json. The keys from tools/forever_dungeon_keys.json. Do not edit; rebuild instead.',
        '-- Facts only (names, level ranges, sizes, bosses known so far, opening dates), checked by hand on '
        + facts['checked'] + ';',
        '-- the sources of every entry are named in the JSON file. lvl is the level the client tunes a dungeon',
        "-- to (its LFGDungeons and ContentTuning tables), the low end of its range; dungeons without a fact",
        '-- range take the high end from their items meanwhile. order: the bosses in the game\'s order, enc their',
        '-- encounter ids (DungeonEncounter, one per name of order); maps: the uiMap ids of the floors',
        '-- (UiMapAssignment, empty in the Forever tables so far); keys: the key and attunement items, checked',
        '-- by hand (item, need required/optional, why door/part/summon/attune/boss, quests or questsA/questsH',
        '-- leading to it).',
        'local _, ns = ...',
        '',
        'ns.DUNGEON_FACTS = {',
        '    checked = ' + lua_str(facts['checked']) + ',',
        '    list = {',
    ]
    for e in merge(facts, client, keys):
        parts = []
        for k in FIELDS:
            v = e.get(k)
            if v is None or v == []:
                continue
            parts.append(lua_key(k) + ' = ' + lua_val(v))
        lines.append('        { ' + ', '.join(parts) + ' },')
    lines += ['    },', '}', '']
    return '\n'.join(lines)


def write_client(client, path=CLIENT):
    doc = {'_comment': 'GENERATED by tools/build_dungeons.py --wago from the WoW Forever client tables (wago.tools '
                       'CSV downloads, or the copies AllTheThings ships): per dungeon of tools/forever_dungeons.json '
                       'the level the client tunes it to (LFGDungeons, ContentTuning), its instance id '
                       '(AreaTable), its bosses in the game\'s order with their encounter ids (DungeonEncounter) and '
                       'the uiMaps of its floors (UiMapAssignment). Game data, no loot. Do not edit; rebuild instead.',
           **client}
    text = json.dumps(doc, indent=1, sort_keys=False, ensure_ascii=False) + '\n'
    old = None
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            old = fh.read()
    if old != text:
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        print('wrote %s (%d dungeons)' % (os.path.relpath(path, ROOT), len(client['dungeons'])))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', nargs='*', default=None,
                    help='read the client tables first (default folders: ~/addons/_wago, then ATT\'s copies)')
    args = ap.parse_args(argv)
    with open(FACTS, encoding='utf-8') as fh:
        facts = json.load(fh)
    if args.wago is not None:
        client = client_facts(facts, args.wago or WAGO_DIRS)
        if not client['tables'].get('LFGDungeons') and not client['tables'].get('AreaTable'):
            raise SystemExit('no LFGDungeons or AreaTable CSV in ' + ', '.join(args.wago or WAGO_DIRS))
        print('client tables: ' + ', '.join(f'{t} {n}' for t, n in sorted(client['tables'].items())))
        print('client: %d dungeons with a level, %d with an instance id; LFGDungeons names without facts: %s' % (
            sum(1 for c in client['dungeons'].values() if c.get('lvl')),
            sum(1 for c in client['dungeons'].values() if c.get('inst')), ', '.join(client['unmatched']) or '-'))
        write_client(client)
    client = load_client()
    for c in conflicts(facts, client):
        print('differs: ' + c)
    text = render(facts, client)
    old = None
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8') as fh:
            old = fh.read()
    if old == text:
        print('DungeonData.lua is current (%d entries)' % len(facts['dungeons']))
        return 0
    with open(OUT, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    print('wrote %s (%d entries)' % (os.path.relpath(OUT, ROOT), len(facts['dungeons'])))
    return 0


if __name__ == '__main__':
    sys.exit(main())
