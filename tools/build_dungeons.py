"""Builds Amisia/Data/DungeonData.lua from tools/forever_dungeons.json: the dungeons and raids of
WoW Forever for the addon's dungeon planner (Dungeons.lua).

The JSON file is kept by hand and holds facts only (names, level ranges, sizes, bosses known so
far, opening dates, instance ids), each entry with its source ("src", and "<field>_src" for a field
that comes from elsewhere, as boss lists read from the repo's item data); see its "sources" block.
tools/forever_dungeon_keys.json (kept by hand as well) adds the key and attunement items of a dungeon
(keys: item id, required or optional, what it opens, the quests that lead to it). Nothing is fetched.
Run it after changing either JSON file:

    python tools/build_dungeons.py [--wago [DIR ...]]

--wago reads the client tables (<Table>.csv or <Table>.<build>.csv; default the newest copy of each
table of the export, wago.tools' CSV exports and the copies ATT ships, tools/client_tables.py) and rewrites
tools/forever_dungeons_client.json: per dungeon of the facts the level the client tunes it to
(LFGDungeons -> ContentTuning; one level, the minimum of the range where the public facts give one),
its instance id (AreaTable) and its bosses in the game's order (DungeonEncounter: the rows of the
instance, by OrderIndex; F-139) with their encounter ids (enc, one per name of order, what ENCOUNTER_END
and BOSS_KILL report) and the UI maps of its floors (UiMapAssignment: every uiMap of the instance's map
id; maps). With --wago it also reads AllTheThings' encounters and NPCs (its cache, tools/att_data.py;
--no-att leaves them out; F-170, D-100): ATT's AreaTable copy after the user's tables, ATT's encounters
as the order of an instance the client has no DungeonEncounter rows of (order_src "att"), and each
boss's NPC id (npcs, one per name of order; npcs_of). Without --wago that file is read as it is. The
hand facts win: the client's values only fill what the JSON leaves open (lvl always; inst where the
facts have none; order and enc where the facts give none; npcs and maps always: the planner sorts the
bosses it knows by order).

The generated table is ns.DUNGEON_FACTS. Once tools/build_bis.py writes ns.BIS.DG (task 2 of the
2.3 design: the same facts plus the level ranges of the client's LFGDungeons table and the bosses'
NPC ids), the planner takes that instead and this file can go.
"""
import argparse
import csv
import json
import re
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
# where a client table in another language lies (build.py tables --locale deDE writes the first)
DE_DIRS = (os.path.expanduser('~/addons/_cache/wago'), os.path.expanduser('~/addons/_wago'))

# LFGDungeons names that differ from the facts' names and aliases (the client's own spellings).
LFG_NAMES = {'Stormwind Stockades': 'The Stockade', "Zul'Farak": "Zul'Farrak", 'Onyxia': "Onyxia's Lair"}
# LFGDungeons types that are no dungeon: 4 an outdoor zone, 5 a battleground.
LFG_SKIP_TYPES = ('4', '5')

# Field order in the Lua table; anything else in the JSON (src and the <field>_src labels) is not
# written. part: the client's name of an instance that hosts several dungeons (Blackrock Spire).
# lvl: the level the client tunes the dungeon to (forever_dungeons_client.json).
# order: the bosses' English names in the game's order (DungeonEncounter, forever_dungeons_client.json);
# enc: their encounter ids, one per name of order; npcs: their NPC ids, one per name of order (0 unknown;
# a dungeon of one wing of an instance keeps only the bosses of its wing, att_wing, D-106). maps: the uiMap
# ids of the instance's floors.
# keys: the key and attunement items (forever_dungeon_keys.json), each with the fields of KEY_FIELDS.
# wing: the English name of the wing a dungeon is (the Scarlet Monastery's four, F-174), part_area: the client's
# area id of the part's name (the addon shows "<part>: <wing>" in the client's language).
# rares: the dungeon's rare mobs, [NPC id, English name] each (AllTheThings, rares_of; F-180, D-112).
FIELDS = ('key', 'name', 'kind', 'min', 'max', 'lvl', 'size', 'inst', 'area', 'from', 'bosses', 'order', 'enc',
          'npcs', 'maps', 'aliases', 'part', 'wing', 'part_area', 'keys', 'rares')
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


def client_facts(facts, dirs=WAGO_DIRS, att=None, scans=None, enc_names=None):
    """{'tables': {table: file name}, 'dungeons': {fact key: {'lvl', 'inst', 'lfg', 'order', 'enc', 'npcs',
    'order_src', 'maps'}}, 'unmatched': [names]} from the client tables in dirs (the first folder holding a
    table wins, its newest build) and, with att (att_data.load()), AllTheThings' encounters and NPCs.

    lvl: LFGDungeons' ContentTuningID -> ContentTuning's MinLevelSquish (or MinLevel in tables of
    other builds); a dungeon split into wings ("Dire Maul - East") counts for the facts' dungeon.
    inst: the AreaTable row of the dungeon's name (an area at the top whose map is no continent).
    With att the AreaTable copy AllTheThings ships counts after dirs: the user's export lacks the rows of
    the dungeons the base data of the build does not have yet (the Drowned City and the other new ones).
    order: the DungeonEncounter rows of its instance (the facts' inst, else the client's) of the normal
    difficulty (0 and 1) by OrderIndex, each name once (only the first folder holding the table counts);
    an instance without rows there takes ATT's encounters of the instance in its file's order
    (order_src 'att': ATT's e() id is the client's encounter id in Forever's new dungeons).
    npcs: the boss NPC of each name of the order (the facts' own order where they have one; see npcs_of());
    where no source names one, the NPC scan by id (scans, enc_names; boss_npcs_from_scan(), D-104).
    rares: the dungeon's rare mobs from AllTheThings (rares_of(), F-180)."""
    tables = {}
    for t in ('LFGDungeons', 'ContentTuning', 'AreaTable', 'DungeonEncounter', 'UiMapAssignment'):
        for d in dirs:
            path = att_data.wago_csv(d, t)
            if path:
                tables[t] = os.path.basename(path)
                break
    tuning = {cid: lo for cid, (lo, _) in tuning_levels(att_data.wago_rows('ContentTuning', *dirs)).items()}
    by_key, by_part = {}, {}
    for e in facts['dungeons']:
        for k in _keys(e):
            by_key.setdefault(k, e['key'])
        if e.get('part'):
            by_part.setdefault(att_data.name_key(e['part']), []).append(e['key'])
    out, unmatched, seen = {}, [], set()
    for row in att_data.wago_rows('LFGDungeons', *dirs):
        lid = _int(row.get('ID'))
        if lid is None or lid in seen or row.get('TypeID') in LFG_SKIP_TYPES:
            continue
        seen.add(lid)
        raw = (row.get('Name_lang') or '').strip()
        name = LFG_NAMES.get(raw, raw)
        key = by_key.get(att_data.name_key(name)) or by_key.get(att_data.name_key(name.split(' - ')[0]))
        # the row of an instance whose wings are dungeons of their own (the Scarlet Monastery, F-174): the
        # client has one row for the whole instance; it counts for every wing
        keys = [key] if key is not None else by_part.get(att_data.name_key(name), [])
        if not keys:
            unmatched.append(raw)
            continue
        lvl = tuning.get(_int(row.get('ContentTuningID')))
        for key in keys if lvl else ():
            rec = out.setdefault(key, {})
            rec.setdefault('lvl', lvl)
            rec.setdefault('lfg', [])
            rec['lfg'].append(raw)
    area_dirs = tuple(dirs) + (tuple(d for d in WAGO_DIRS[1:] if d not in dirs) if att else ())
    _, by_name = att_data.read_area_instances(*area_dirs)
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
    if att:
        index = att_data.boss_index(att)
        for e in facts['dungeons']:
            rec = out.get(e['key']) or {}
            inst = e.get('inst') or rec.get('inst')
            iid = att_instance(att, e, inst)
            if iid is None:
                continue
            if not rec.get('order') and not e.get('order'):
                encs = [(eid, x['name']) for eid, x in att.get('encounters', {}).items()
                        if x.get('inst') == iid and x.get('name') and not x.get('old')]
                if encs:
                    rec = out.setdefault(e['key'], rec)
                    rec['order'], rec['enc'], rec['order_src'] = [n for _, n in encs], [i for i, _ in encs], 'att'
            order = e.get('order') or rec.get('order')
            if order:
                npcs = npcs_of(e, order, e.get('enc') or rec.get('enc'), index, iid)
                out.setdefault(e['key'], rec)['npcs'] = npcs
                if e.get('att_wing') and not e.get('order') and False in npcs:
                    # a dungeon of one wing keeps only the bosses of its wing (D-106): the order, the
                    # encounters and the NPCs of the other wings go
                    keep = [i for i, n in enumerate(npcs) if n is not False]
                    rec['order'] = [rec['order'][i] for i in keep]
                    rec['enc'] = [rec['enc'][i] for i in keep]
                    rec['npcs'] = [npcs[i] for i in keep]
            # the dungeon's rare mobs (F-180, D-112)
            rares = rares_of(att, iid, e, e.get('order') or rec.get('order') or [], rec.get('npcs') or [])
            if rares:
                out.setdefault(e['key'], rec)['rares'] = rares
    if scans:
        for key, name, npc in boss_npcs_from_scan(out, scans, enc_names or {}):
            print(f'NPC scan: {key} {name} -> {npc}')
    if tables.get('UiMapAssignment'):
        out_maps = uimap_floors(next(d for d in dirs if att_data.wago_csv(d, 'UiMapAssignment')))
        for e in facts['dungeons']:
            inst = e.get('inst') or (out.get(e['key']) or {}).get('inst')
            if out_maps.get(inst):
                out.setdefault(e['key'], {})['maps'] = out_maps[inst]
    return {'tables': tables, 'dungeons': {k: out[k] for k in sorted(out)}, 'unmatched': sorted(set(unmatched))}


# ---------------------------------------------------------------- boss NPCs from the NPC scan (D-104)
def scan_key(name):
    """A name compared without case, blanks and punctuation (letters of every language kept)."""
    return re.sub(r'[\W_]+', '', (name or '').casefold())


def encounter_names(dirs, locale='deDE'):
    """{encounter id: name} of the client table DungeonEncounter in another language
    (DungeonEncounter.<build>.<locale>.csv, as `build.py tables --tables DungeonEncounter --locale deDE`
    writes it; the newest build of the first folder holding one), or {} without one."""
    pat = re.compile(r'^DungeonEncounter\.(\d+(?:\.\d+)*)\.' + re.escape(locale) + r'\.csv$')
    for d in dirs:
        if not d or not os.path.isdir(d):
            continue
        found = sorted((tuple(int(x) for x in m.group(1).split('.')), name)
                       for name in os.listdir(d) for m in [pat.match(name)] if m)
        if found:
            out = {}
            with open(os.path.join(d, found[-1][1]), encoding='utf-8-sig', newline='') as fh:
                for row in csv.DictReader(fh):
                    eid, name = _int(row.get('ID')), (row.get('Name_lang') or '').strip()
                    if eid is not None and name:
                        out[eid] = name
            return out
    return {}


def boss_npcs_from_scan(dungeons, scans, enc_names):
    """Fills the NPC id of a boss no other source names (npcs 0) from the NPC scan by id
    (build_scan_archive.id_scans): a scanned NPC whose name is the encounter's name in the scan's
    language: the order's own name for an English scan, the DungeonEncounter name of that language
    (enc_names {locale: {encounter id: name}}) for any other. Of several NPCs with that name the one
    nearest to the dungeon's other boss NPCs. In place; returns [(dungeon key, boss, NPC id)]."""
    taken = []
    for key, rec in dungeons.items():
        order, enc, npcs = rec.get('order') or [], rec.get('enc') or [], rec.get('npcs')
        if not npcs or len(npcs) != len(order):
            continue
        known = [n for n in npcs if n]
        for i, name in enumerate(order):
            if npcs[i] != 0:
                continue
            eid = enc[i] if i < len(enc) else None
            for loc, part in sorted(((scans or {}).get('npcs') or {}).items()):
                target = name if loc in ('enUS', 'enGB') else (enc_names.get(loc) or {}).get(eid)
                if not target:
                    continue
                cands = sorted(nid for nid, f in part.items() if scan_key(f.get('name')) == scan_key(target))
                if not cands:
                    continue
                npc = min(cands, key=lambda c: (min((abs(c - k) for k in known), default=0), c))
                npcs[i] = npc
                rec.setdefault('npcs_scan', []).append(name)
                taken.append((key, name, npc))
                break
    return taken


def att_instance(att, e, inst):
    """The ATT instance id of fact e: the one whose map id is the dungeon's instance id, else the one
    whose name is the dungeon's name, an alias or its part (att_data.name_key: "The Drowned City" =
    "Drowned City"); None without one."""
    insts = att.get('instances') or {}
    if inst:
        hit = sorted(iid for iid, x in insts.items() if x.get('mapID') == inst and not x.get('old'))
        if hit:
            return hit[0]
    names = {att_data.name_key(n) for n in [e['name']] + list(e.get('aliases') or []) + ([e['part']] if e.get('part') else [])}
    hit = sorted(iid for iid, x in insts.items() if att_data.name_key(x.get('name')) in names and not x.get('old'))
    return hit[0] if hit else None


def npcs_of(e, order, enc, index, iid):
    """The boss NPC of each name of order (att_data.find_boss in ATT instance iid; a name of the facts'
    boss_alias is looked up by its alias where its own name finds none), lined up with order: the NPC id,
    0 where no source names one, False where the boss stands in the wing of another dungeon of the same
    instance (the facts' att_wing: the two halves of Blackrock Spire, the Scarlet Monastery's four wings;
    client_facts() then drops those bosses from the dungeon's order, D-106)."""
    alias = e.get('boss_alias') or {}
    wing = e.get('att_wing')
    out = []
    for i, name in enumerate(order):
        eid = enc[i] if enc and i < len(enc) else None
        npc, _, at = att_data.find_boss(index, iid, name, eid, order)
        if npc is None and alias.get(name):
            npc, _, at = att_data.find_boss(index, iid, alias[name], None, order)
        if npc is not None and wing and at and at != wing:
            out.append(False)
        else:
            out.append(npc or 0)
    return out


RARE_SUFFIX = re.compile(r'\s*\(rare\)\s*$', re.I)


def rares_of(att, iid, e, order, npcs):
    """The rare mobs of fact e in ATT instance iid (F-180, D-112): [[NPC id, English name], ...] by id, every
    NPC of the instance AllTheThings files as rare (under its header "Rares" or described as a rare creature,
    att_data: kind 'rare') and never as a boss; in a dungeon of one wing (the facts' att_wing) only those
    under its wing (a rare without a wing there is left out). A rare that is a boss of the dungeon's order
    (its NPC in npcs or its name in order: Miner Johnson, Skul, Stonespine) stays a boss. ATT's " (Rare)"
    after a name goes. [] where ATT knows none."""
    wing = e.get('att_wing')
    bosses = {n for n in npcs if n}
    names = {att_data.boss_key(n) for n in order}
    out = []
    for nid, n in sorted((att.get('npcs') or {}).items()):
        kinds = set(n.get('kinds') or ())
        if n.get('inst') != iid or 'rare' not in kinds or 'boss' in kinds or n.get('old') or not n.get('name'):
            continue
        if wing and n.get('wing') != wing:
            continue
        name = RARE_SUFFIX.sub('', n['name']).strip()
        if not name or nid in bosses or att_data.boss_key(name) in names:
            continue
        out.append([nid, name])
    return out


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
    enc, npcs and maps; the key items of keys (forever_dungeon_keys.json's dungeons). The hand facts never
    change. enc and npcs line up with order: one encounter id and one NPC id per boss name."""
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
        if c.get('npcs') and len(c['npcs']) == len(m.get('order') or []):
            m['npcs'] = c['npcs']
        if c.get('maps'):
            m['maps'] = c['maps']
        if c.get('rares'):
            m['rares'] = c['rares']
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
        # the client tunes an instance of several wings as a whole: the wings' own ranges are facts (F-174)
        if c.get('lvl') and e.get('min') is not None and c['lvl'] != e['min'] and not e.get('part'):
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
        '-- The bosses\' NPC ids (npcs) and the encounters of dungeons the client tables lack from AllTheThings\' Forever',
        '-- data (MIT, Copyright (c) 2026 AllTheThings WoW Addon; see LICENSES/AllTheThings-MIT.txt).',
        '-- Facts only (names, level ranges, sizes, bosses known so far, opening dates), checked by hand on '
        + facts['checked'] + ';',
        '-- the sources of every entry are named in the JSON file. lvl is the level the client tunes a dungeon',
        "-- to (its LFGDungeons and ContentTuning tables), the low end of its range; dungeons without a fact",
        '-- range take the high end from their items meanwhile. order: the bosses in the game\'s order, enc their',
        '-- encounter ids (DungeonEncounter, else AllTheThings\' encounters; one per name of order), npcs their NPC ids',
        '-- (AllTheThings; 0 unknown; a wing of an instance has only its own bosses); maps: the uiMap ids of the floors',
        '-- (UiMapAssignment, empty in the Forever tables so far); keys: the key and attunement items, checked',
        '-- by hand (item, need required/optional, why door/part/summon/attune/boss, quests or questsA/questsH',
        '-- leading to it); rares: the rare mobs, { NPC id, English name } each (AllTheThings\' rares, never a boss',
        '-- of the order).',
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
                       'the uiMaps of its floors (UiMapAssignment); where the client has no encounters of an instance, '
                       'AllTheThings\' encounters (order_src "att"), and per name of the order its boss NPC from '
                       'AllTheThings (npcs: 0 unknown; a wing of an instance keeps only the bosses of its wing); '
                       'the rare mobs AllTheThings files under the instance (rares: [NPC id, name], never a boss). '
                       'Game data, no loot. Do not edit; rebuild instead.',
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
                    help='read the client tables first (default: the newest copy of each table, tools/client_tables.py)')
    ap.add_argument('--no-att', action='store_true',
                    help='with --wago: without AllTheThings\' encounters and NPCs (default: its cache, see tools/att_data.py)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables with the NPC scan (default: ~/addons/_SavedVariables/Amisia.lua ...)')
    ap.add_argument('--scan-archive', default=os.path.join(HERE, 'scan_archive.json'),
                    help='the scan archive with the NPC scan by id ("" for none)')
    args = ap.parse_args(argv)
    with open(FACTS, encoding='utf-8') as fh:
        facts = json.load(fh)
    if args.wago is not None:
        att = None
        if not args.no_att and att_data.commit_of(att_data.ATT_CACHE):
            att = att_data.load(att_data.ATT_CACHE, items=False)
            print('AllTheThings %s: %d encounters' % ((att.get('commit') or '?')[:10], len(att.get('encounters') or {})))
        if not args.wago:
            import client_tables
            args.wago = [client_tables.default_dir()]
        # the NPC scan by id (D-104): boss NPCs no other source names, matched by the encounter's name
        import build_scan
        import build_scan_archive
        svs = args.sv if args.sv is not None else build_scan_archive.default_svs()
        scans = build_scan_archive.id_scans(args.scan_archive or None, [build_scan.load_sv(p) for p in svs])
        enc_names = {loc: encounter_names(DE_DIRS, loc) for loc in (scans.get('npcs') or {}) if loc not in ('enUS', 'enGB')}
        for loc, names in sorted(enc_names.items()):
            print(f'NPC scan {loc}: {len(scans["npcs"][loc])} names; DungeonEncounter.{loc}: '
                  + (f'{len(names)} encounters' if names else 'missing (python3 tools/build.py tables --tables DungeonEncounter --locale ' + loc + ')'))
        client = client_facts(facts, args.wago, att, scans, enc_names)
        if not client['tables'].get('LFGDungeons') and not client['tables'].get('AreaTable'):
            raise SystemExit('no LFGDungeons or AreaTable CSV in ' + ', '.join(args.wago))
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
