"""Builds addon/Amisia/DungeonData.lua from tools/forever_dungeons.json: the dungeons and raids of
WoW Forever for the addon's dungeon planner (Dungeons.lua).

The JSON file is kept by hand and holds facts only (names, level ranges, sizes, bosses known so
far, opening dates, instance ids), each entry with its source ("src", and "<field>_src" for a field
that comes from elsewhere, as boss lists read from the repo's item data); see its "sources" block.
Nothing is fetched. Run it after changing the JSON:

    python tools/build_dungeons.py [--wago [DIR ...]]

--wago reads the client tables (wago.tools CSV downloads, <Table>.csv or <Table>.<build>.csv, in
~/addons/_wago, then the copies ATT ships in ~/addons/_cache/att/.config/.wago) and rewrites
tools/forever_dungeons_client.json: per dungeon of the facts the level the client tunes it to
(LFGDungeons -> ContentTuning; one level, the minimum of the range where the public facts give one)
and its instance id (AreaTable). Without --wago that file is read as it is. The hand facts win: the
client's values only fill what the JSON leaves open (lvl always; inst where the facts have none).

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
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'DungeonData.lua')
WAGO_DIRS = (os.path.expanduser('~/addons/_wago'), os.path.join(att_data.ATT_CACHE, '.config', '.wago'))

# LFGDungeons names that differ from the facts' names and aliases (the client's own spellings).
LFG_NAMES = {'Stormwind Stockades': 'The Stockade', "Zul'Farak": "Zul'Farrak", 'Onyxia': "Onyxia's Lair"}
# LFGDungeons types that are no dungeon: 4 an outdoor zone, 5 a battleground.
LFG_SKIP_TYPES = ('4', '5')

# Field order in the Lua table; anything else in the JSON (src and the <field>_src labels) is not
# written. part: the client's name of an instance that hosts several dungeons (Blackrock Spire).
# lvl: the level the client tunes the dungeon to (forever_dungeons_client.json).
FIELDS = ('key', 'name', 'kind', 'min', 'max', 'lvl', 'size', 'inst', 'area', 'from', 'bosses', 'aliases', 'part')


def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def lua_val(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return '{ ' + ', '.join(lua_val(x) for x in v) + ' }'
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
    """{'tables': {table: file name}, 'dungeons': {fact key: {'lvl', 'inst', 'lfg'}}, 'unmatched': [names]}
    from the client tables in dirs (the first folder holding a table wins, its newest build).

    lvl: LFGDungeons' ContentTuningID -> ContentTuning's MinLevelSquish (or MinLevel in tables of
    other builds); a dungeon split into wings ("Dire Maul - East") counts for the facts' dungeon.
    inst: the AreaTable row of the dungeon's name (an area at the top whose map is no continent)."""
    tables = {}
    for t in ('LFGDungeons', 'ContentTuning', 'AreaTable'):
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
    return {'tables': tables, 'dungeons': {k: out[k] for k in sorted(out)}, 'unmatched': sorted(set(unmatched))}


def load_client(path=CLIENT):
    if not os.path.exists(path):
        return {'dungeons': {}}
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def merge(facts, client):
    """The facts with the client's values filled in: lvl, and inst where the facts give none. The
    hand facts never change."""
    cd = (client or {}).get('dungeons') or {}
    out = []
    for e in facts['dungeons']:
        c = cd.get(e['key']) or {}
        m = dict(e)
        if c.get('lvl') and m.get('lvl') is None:
            m['lvl'] = c['lvl']
        if c.get('inst') and m.get('inst') is None:
            m['inst'] = c['inst']
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


def render(facts, client=None):
    """The Lua file for the facts (with the client's values, see merge()), always the same text for
    the same input."""
    if client is None:
        client = load_client()
    lines = [
        '-- GENERATED by tools/build_dungeons.py from tools/forever_dungeons.json and',
        '-- tools/forever_dungeons_client.json. Do not edit; rebuild instead.',
        '-- Facts only (names, level ranges, sizes, bosses known so far, opening dates), checked by hand on '
        + facts['checked'] + ';',
        '-- the sources of every entry are named in the JSON file. lvl is the level the client tunes a dungeon',
        "-- to (its LFGDungeons and ContentTuning tables), the low end of its range; dungeons without a fact",
        '-- range take the high end from their items meanwhile.',
        'local _, ns = ...',
        '',
        'ns.DUNGEON_FACTS = {',
        '    checked = ' + lua_str(facts['checked']) + ',',
        '    list = {',
    ]
    for e in merge(facts, client):
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
                       'the level the client tunes it to (LFGDungeons, ContentTuning) and its instance id '
                       '(AreaTable). Game data, no loot. Do not edit; rebuild instead.',
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
