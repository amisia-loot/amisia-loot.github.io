"""Builds addon/Amisia/MapData.lua (WoW Forever) and addon/Amisia/MapDataTBC.lua (TBC Anniversary):
where the sources of the gear data stand on the world map. Quest givers and start objects, vendors,
rare and named mobs come from NPC and object spawns, raids and dungeons from their entrances,
reputation rewards from the faction's quartermaster. Runs without a WoW install (on the N100).

    python tools/build_map.py [--refresh-questie] [--game forever|tbc|both]

Sources (named with their licence in tools/README.md and in the header of the generated files):
  - QuestieDB on GitHub (QUESTIE_REPO): the Forever and TBC npc, object and quest databases and the
    zone tables (dungeon entrances, area id -> uiMapID, instance id -> area id). Every database file
    holds its table as a "[[return {...}]]" string; only that block is run.
    --refresh-questie downloads them into tools/cache/questiedb/ (not in git). Whenever that download
    is complete, what the gear data needs from it is kept in tools/map_questie.json, so a build
    without network repeats exactly.
  - The generated gear data (GearData.lua, BisDataTBC.lua): which places are needed at all.
  - Amisia's own list of the TBC quartermasters (QUARTERMASTERS).

Points are "uiMapID:x:y" with x and y in hundredths of a percent (0-10000), at most four per key.
"""
import argparse
import json
import math
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import build_gear  # noqa: E402  (Lua strings, dungeon name keys, user agent)

QUESTIE_REPO = 'Questie/QuestieDB'
# The one place the data's licence is written; the generated headers and the JSON take it from here.
QUESTIE_LICENSE = 'GPL-3.0'
RAW = 'https://raw.githubusercontent.com/{repo}/{ref}/{path}'
FILES = {
    'forever': {
        'npc': 'data/Forever/foreverNpcDB.lua', 'quest': 'data/Forever/foreverQuestDB.lua',
        'object': 'data/Forever/foreverObjectDB.lua', 'dungeons': 'support/Forever/Zones/dungeons.lua',
        'area': 'support/Forever/Zones/areaIdToUiMapId.lua', 'instance': 'support/Forever/Zones/instanceIdToAreaId.lua',
    },
    'tbc': {
        'npc': 'data/TBC/tbcNpcDB.lua', 'quest': 'data/TBC/tbcQuestDB.lua', 'object': 'data/TBC/tbcObjectDB.lua',
        'dungeons': 'support/Zones/dungeons.lua', 'area': 'support/Zones/areaIdToUiMapId.lua',
        'instance': 'support/Zones/instanceIdToAreaId.lua',
    },
}
# The data's expansion order (Era 1, Tbc 2, Wotlk 3, ...); Forever counts as Era. The dungeon file
# corrects entrances for later expansions, and only the corrections of the own one apply.
EXPANSION = {'forever': 1, 'tbc': 2}
CACHE_DIR = os.path.join(HERE, 'cache', 'questiedb')
MAP_JSON = os.path.join(HERE, 'map_questie.json')
GEAR = {'forever': os.path.join(ROOT, 'addon', 'Amisia', 'GearData.lua'),
        'tbc': os.path.join(ROOT, 'addon', 'Amisia', 'BisDataTBC.lua')}
OUT = {'forever': os.path.join(ROOT, 'addon', 'Amisia', 'MapData.lua'),
       'tbc': os.path.join(ROOT, 'addon', 'Amisia', 'MapDataTBC.lua')}
USER_AGENT = build_gear.USER_AGENT
MAX_POINTS = 4
MERGE = 200          # spawns closer than 2 % (in hundredths of a percent) are one point

# Amisia's own list: who hands out the reputation rewards of a TBC faction (faction id -> NPC name).
# Tranquillien (922) has no quartermaster in the data and no pin.
QUARTERMASTERS = {
    946: 'Logistics Officer Ulrike', 947: 'Quartermaster Urgronn', 942: 'Fedryen Swiftspear', 1011: 'Nakodu',
    935: 'Almaador', 989: 'Alurmi', 932: 'Quartermaster Endarin', 934: 'Quartermaster Enuril', 978: 'Trader Narasu',
    941: 'Provisioner Nasela', 933: 'Karaaz', 967: 'Archmage Leryda', 1015: 'Yarzill the Merc', 1031: 'Grella',
    1038: "Jho'nass", 1077: 'Eldara Dawnrunner', 1012: 'Okuno', 990: 'Indormi', 970: 'Mycah',
}
# Quartermasters whose title in the data does not say so.
QUARTERMASTER_EXCEPTIONS = {'Archmage Leryda', 'Yarzill the Merc', 'Indormi'}
# Instance keys whose dungeon the data spells differently.
INSTANCE_ALIASES = {'SERPENTSHRINE_CAVERN': 'Serpentshire Cavern', 'AHN_QIRAJ': "Temple of Ahn'Qiraj"}


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- download and cache
def refresh_questie(dest=CACHE_DIR, ref='master'):
    """Downloads the database files of both games. Returns {game: {name: text}} and the commit."""
    def get(url):
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read().decode('utf-8')

    commit = ref
    try:
        commit = json.loads(get(f'https://api.github.com/repos/{QUESTIE_REPO}/commits/{ref}'))['sha']
    except Exception as exc:  # noqa: BLE001 - the commit is only recorded, the files are what counts
        log(f'quest database: could not read the commit of {ref}: {exc}')
    texts = {}
    for game, files in FILES.items():
        os.makedirs(os.path.join(dest, game), exist_ok=True)
        texts[game] = {}
        for name, path in files.items():
            text = get(RAW.format(repo=QUESTIE_REPO, ref=commit, path=path))
            with open(os.path.join(dest, game, name + '.lua'), 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(text)
            texts[game][name] = text
    with open(os.path.join(dest, 'COMMIT'), 'w', encoding='utf-8') as fh:
        fh.write(commit + '\n')
    log(f'quest database: {sum(len(f) for f in FILES.values())} files of {QUESTIE_REPO}@{commit[:10]} '
        f'-> {os.path.relpath(dest, ROOT)}')
    return texts, commit


def load_cached(dest=CACHE_DIR):
    """The downloaded files and their commit, or (None, None) when the download is incomplete."""
    texts = {}
    for game, files in FILES.items():
        texts[game] = {}
        for name in files:
            p = os.path.join(dest, game, name + '.lua')
            if not os.path.exists(p):
                return None, None
            with open(p, encoding='utf-8') as fh:
                texts[game][name] = fh.read()
    commit = None
    if os.path.exists(os.path.join(dest, 'COMMIT')):
        with open(os.path.join(dest, 'COMMIT'), encoding='utf-8') as fh:
            commit = fh.read().strip() or None
    return texts, commit


# ---------------------------------------------------------------- reading the Lua tables
def _lua():
    from lupa.lua51 import LuaRuntime
    return LuaRuntime(unpack_returned_tuples=True)


def py(v):
    """A lupa value as plain Python: tables become dicts keyed like Lua, numbers stay numbers."""
    if hasattr(v, 'items') and not isinstance(v, dict):
        return {k: py(x) for k, x in v.items()}
    return v


def seq(t):
    """A Lua array (as py() gives it) as a list, holes as None."""
    if not isinstance(t, dict):
        return []
    n = max((k for k in t if isinstance(k, int)), default=0)
    return [t.get(i) for i in range(1, n + 1)]


BLOCK = re.compile(r'([\w.]+)\s*=\s*\[\[(return\s*\{.*?)\]\]', re.S)


def return_blocks(text):
    """{assigned name: "return {...}"} for every long-string table of a file."""
    return {m.group(1): m.group(2) for m in BLOCK.finditer(text)}


def read_table(block, lua=None):
    lua = lua or _lua()
    return py(lua.eval('function(s) return assert(loadstring(s))() end')(block))


def _lua_table(block, lua):
    return lua.eval('function(s) return assert(loadstring(s))() end')(block)


def area_to_ui(text):
    """area id -> uiMapID; the file's overrides win, 0 means no map."""
    blocks = return_blocks(text)
    out = {}
    for name in sorted(blocks, key=lambda n: n.endswith('Override')):
        out.update(read_table(blocks[name]))
    return {int(a): int(u) for a, u in out.items() if u}


ZONE_STUB = r'''
local modules = { ZoneDB = { private = {}, zoneIDs = setmetatable({}, { __index = function(_, k) return k end }) },
                  Expansions = { Era = 1, Tbc = 2, Wotlk = 3, Cata = 4, MoP = 5, Current = EXPANSION } }
QuestieLoader = { ImportModule = function(_, name) return modules[name] end }
function UnitFactionGroup() return "Alliance" end
return modules.ZoneDB
'''


def _run_zone_file(text, expansion=1):
    lua = _lua()
    lua.globals().EXPANSION = expansion
    zone_db = lua.execute(ZONE_STUB)
    lua.eval('function(s) return assert(loadstring(s))() end')(text)
    return zone_db


def read_dungeons(text, expansion):
    """{area: {'name', 'alt': [area...], 'entrances': [(area, x, y)...]}} as the expansion sees it."""
    zone_db = _run_zone_file(text, expansion)
    out = {}
    for area, row in py(zone_db.private.dungeons).items():
        r = seq(row)
        out[int(area)] = {
            'name': r[0], 'alt': [int(a) for a in seq(r[1])] if len(r) > 1 else [],
            'entrances': [tuple(seq(e)) for e in seq(r[3])] if len(r) > 3 else [],
        }
    return out


def read_instances(text, dungeons):
    """{instance id: dungeon area}, the file's zone names matched to the dungeons by name; and the
    names no dungeon matched."""
    zone_db = _run_zone_file(text)
    by_key = {}
    for area in sorted(dungeons):
        by_key.setdefault(build_gear.dungeon_key(dungeons[area]['name']), area)
    out, unknown = {}, []
    for inst, key in sorted(py(zone_db.instanceIdToAreaId).items()):
        if isinstance(key, (int, float)):
            # some lines give the area id itself
            out[int(inst)] = int(key)
            continue
        name = INSTANCE_ALIASES.get(key) or key.replace('_', ' ')
        area = by_key.get(build_gear.dungeon_key(name))
        if area:
            out[int(inst)] = area
        else:
            unknown.append(key)
    return out, unknown


# ---------------------------------------------------------------- points
def dungeon_of_area(dungeons):
    """area (the dungeon's own and its aliases) -> dungeon area."""
    out = {}
    for area, d in dungeons.items():
        out.setdefault(area, area)
        for a in d['alt']:
            out.setdefault(a, area)
    return out


def _hundredths(v):
    return max(0, min(10000, int(math.floor(v * 100 + 0.5))))


def entrance_points(dungeon, areas, unknown):
    out = []
    for area, x, y in dungeon['entrances']:
        ui = areas.get(int(area))
        if not ui:
            unknown.add(int(area))
            continue
        out.append((ui, _hundredths(x), _hundredths(y)))
    return out


def spawn_points(spawns, areas, dungeons, unknown):
    """Spawns {area: [[x, y]...]} as points (uiMapID, x, y). A spawn inside an instance stands for
    its entrance; -1/-1 elsewhere and areas without a map fall away (the latter are noted)."""
    inside = dungeon_of_area(dungeons)
    out = []
    for key in sorted(spawns):
        area = int(key)
        if area in inside:
            for p in entrance_points(dungeons[inside[area]], areas, unknown):
                if p not in out:
                    out.append(p)
            continue
        ui = areas.get(area)
        for xy in spawns[key]:
            x, y = (xy.get(1), xy.get(2)) if isinstance(xy, dict) else (xy[0], xy[1])
            if x is None or y is None or x < 0 or y < 0:
                continue
            if not ui:
                unknown.add(area)
                continue
            out.append((ui, _hundredths(x), _hundredths(y)))
    return out


def pick_points(points, n=MAX_POINTS):
    """At most n points far apart: spawns within 2 % are one, then greedily the point farthest from
    those already taken (another map counts as farthest)."""
    cand, cells = [], set()
    for p in sorted(set(points)):
        cell = (p[0], round(p[1] / MERGE), round(p[2] / MERGE))
        if cell not in cells:
            cells.add(cell)
            cand.append(p)
    if not cand:
        return []
    chosen = [cand[0]]
    rest = cand[1:]
    while rest and len(chosen) < n:
        def gap(p):
            return min(math.inf if p[0] != c[0] else math.hypot(p[1] - c[1], p[2] - c[2]) for c in chosen)
        best = max(rest, key=gap)   # max keeps the first of equals: sorted order decides ties
        chosen.append(best)
        rest.remove(best)
    return chosen


def fmt_points(points):
    return ' '.join(f'{m}:{x}:{y}' for m, x, y in points)


def parse_points(text):
    return [tuple(int(v) for v in p.split(':')) for p in (text or '').split()]


# ---------------------------------------------------------------- the gear data and its keys
GEAR_STUB = r'''
return function(src, forever)
    local ns = { IsForever = function() return forever end }
    assert(loadstring(src, "@gear"))("Amisia", ns)
    local out = {}
    local d = ns.GEAR
    if not d then return out, false end
    for i, rec in ipairs(d.S) do
        local r = {}
        for j = 1, table.maxn(rec) do r[j] = rec[j] == nil and "\0nil" or rec[j] end
        out[i] = r
    end
    return out, d.game ~= nil
end
'''


def load_gear_text(text, game):
    """The source records of a gear data file (as lists, trailing nils dropped) and whether it has
    the game field."""
    lua = _lua()
    recs, has_game = lua.execute(GEAR_STUB)(text, game == 'forever')
    out = []
    for rec in seq(py(recs)):
        out.append([None if v == '\0nil' else v for v in seq(rec)])
    return out, bool(has_game)


def load_gear(path, game):
    with open(path, encoding='utf-8') as fh:
        return load_gear_text(fh.read(), game)


def _at(rec, i):
    """Field i of a record, 1-based as in Lua."""
    return rec[i - 1] if len(rec) >= i else None


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0


def key_of(rec, has_game):
    """The stable map key of a source record; Map.lua's ns.MapKeyOf does the same."""
    k = rec[0]
    if k == 'Q':
        qid = _at(rec, 7)
        return f'Q:{int(qid)}' if _num(qid) else None
    if k in ('V', 'P'):
        nid = _at(rec, 7)
        if _num(nid):
            return f'U:{int(nid)}'
        return f'V:{rec[1]}' if _at(rec, 2) else None
    if k == 'R':
        nid = _at(rec, 5)
        if _num(nid):
            return f'U:{int(nid)}'
        return f'R:{rec[1]}' if _at(rec, 2) else None
    if k == 'W':
        name = _at(rec, 2)
        if not isinstance(name, str):
            return None
        m = re.match(r'^Trash \((.+)\)$', name)
        if m:
            return f'N:{m.group(1)}'
        nid = _at(rec, 6)
        if _num(nid):
            return f'U:{int(nid)}'
        zone = _at(rec, 5)
        return f'W:{name}' if isinstance(zone, (int, float)) and zone != 0 else None
    if k in ('X', 'D'):
        inst = _at(rec, 4) if k == 'X' else _at(rec, 5)
        if k == 'D' and not has_game:
            inst = None
        if _num(inst):
            return f'I:{int(inst)}'
        return f'N:{rec[1]}' if _at(rec, 2) else None
    if k == 'F':
        fid = _at(rec, 4)
        return f'F:{int(fid)}' if _num(fid) else None
    return None


def needed_keys(recs, has_game):
    """{key: [records]} for every record that has a place."""
    out = {}
    for rec in recs:
        key = key_of(rec, has_game)
        if key:
            out.setdefault(key, []).append(rec)
    return out


def _rec_zones(recs):
    """The zones (uiMapIDs; negative area ids as they are) the records name for their place."""
    out = set()
    for rec in recs:
        field = {'V': 3, 'P': 3, 'R': 4, 'W': 5}.get(rec[0])
        z = _at(rec, field) if field else None
        if isinstance(z, (int, float)) and z != 0:
            out.add(int(z))
    return out


def _rec_areas(recs):
    """Dungeon area ids the raid and dungeon records carry."""
    out = set()
    for rec in recs:
        a = _at(rec, 5) if rec[0] == 'X' else _at(rec, 6) if rec[0] == 'D' else None
        if _num(a):
            out.add(int(a))
    return out


# ---------------------------------------------------------------- the subset the data needs
def parse_questie(texts, game, needed):
    """What the needed keys use from the database files, as plain JSON-ready data:
    npcs {id: [name, zone uiMapID, title, points]}, objects {id: [name, points]} (points as in the output),
    quests {id: [npc starters, object starters, item start 1/0]}, dungeons {area: [name, points]},
    instances {id: area}, areas (area -> uiMapID for the records' negative zones), unknown areas."""
    lua = _lua()
    areas = area_to_ui(texts['area'])
    dungeons = read_dungeons(texts['dungeons'], EXPANSION[game])
    instances, _ = read_instances(texts['instance'], dungeons)
    unknown = set()

    npc_t = _lua_table(return_blocks(texts['npc'])['QuestieDB.npcData'], lua)
    quest_t = _lua_table(return_blocks(texts['quest'])['QuestieDB.questData'], lua)
    obj_t = _lua_table(return_blocks(texts['object'])['QuestieDB.objectData'], lua)

    names, ids, qids = set(), set(), set()
    for key in needed:
        kind, _, rest = key.partition(':')
        if kind in ('V', 'R', 'W'):
            names.add(rest)
        elif kind == 'U':
            ids.add(int(rest))
        elif kind == 'Q':
            qids.add(int(rest))
        elif kind == 'F' and int(rest) in QUARTERMASTERS:
            names.add(QUARTERMASTERS[int(rest)])

    quests, objects_needed = {}, set()
    for qid in sorted(qids):
        row = quest_t[qid]
        if row is None:
            continue
        started = seq(py(row[2])) if row[2] is not None else []
        npcs = [int(n) for n in seq(started[0])] if len(started) > 0 and started[0] else []
        objs = [int(o) for o in seq(started[1])] if len(started) > 1 and started[1] else []
        items = 1 if len(started) > 2 and started[2] else 0
        quests[str(qid)] = [npcs, objs, items]
        ids.update(npcs)
        objects_needed.update(objs)

    if names:
        for nid, row in npc_t.items():
            if row[1] in names:
                ids.add(int(nid))

    def ui_of(area):
        return areas.get(int(area)) if area else None

    npcs = {}
    for nid in sorted(ids):
        row = npc_t[nid]
        if row is None:
            continue
        spawns = py(row[7]) or {}
        pts = spawn_points({a: seq(v) for a, v in spawns.items()} if spawns else {}, areas, dungeons, unknown)
        npcs[str(nid)] = [row[1], ui_of(row[9]), row[14], fmt_points(pts)]
    objects = {}
    for oid in sorted(objects_needed):
        row = obj_t[oid]
        if row is None:
            continue
        spawns = py(row[4]) or {}
        pts = spawn_points({a: seq(v) for a, v in spawns.items()}, areas, dungeons, unknown)
        objects[str(oid)] = [row[1], fmt_points(pts)]
    dun = {}
    for area in sorted(dungeons):
        d = dungeons[area]
        dun[str(area)] = [d['name'], fmt_points(entrance_points(d, areas, set()))]
    neg = {}
    for recs in needed.values():
        for z in _rec_zones(recs):
            if z < 0 and -z in areas:
                neg[str(-z)] = areas[-z]
    return {'npcs': npcs, 'objects': objects, 'quests': quests, 'dungeons': dun,
            'instances': {str(k): v for k, v in sorted(instances.items())}, 'areas': neg,
            'unknown': sorted(unknown)}


# ---------------------------------------------------------------- resolving keys to points
def resolve(subset, needed, game):
    """{key: [points]} for every needed key (empty where no place is known), {key: who stands there}
    and a report."""
    npcs = {int(k): v for k, v in subset['npcs'].items()}
    objects = {int(k): v for k, v in subset['objects'].items()}
    quests = {int(k): v for k, v in subset['quests'].items()}
    dungeons = {int(k): v for k, v in subset['dungeons'].items()}
    instances = {int(k): v for k, v in subset['instances'].items()}
    neg = {int(k): v for k, v in subset.get('areas', {}).items()}
    by_name = {}
    for nid in sorted(npcs):
        by_name.setdefault(npcs[nid][0], []).append(nid)
    dkeys = sorted((build_gear.dungeon_key(d[0]), a) for a, d in dungeons.items())

    def pts(text):
        return parse_points(text)

    def dungeon_by_name(name):
        key = build_gear.dungeon_key(name)
        exact = [a for k, a in dkeys if k == key]
        if exact:
            return exact[0]
        near = sorted((abs(len(k) - len(key)), a) for k, a in dkeys if key and k and (key in k or k in key))
        return near[0][1] if near else None

    report = {'kinds': {}, 'ambiguous': [], 'quest item start': 0, 'quest without starter': 0,
              'unknown quests': 0, 'factions without quartermaster': [], 'unknown areas': list(subset.get('unknown', []))}
    P, G = {}, {}
    for key in sorted(needed):
        recs = needed[key]
        kind, _, rest = key.partition(':')
        points = []
        if kind == 'Q':
            q = quests.get(int(rest))
            if not q:
                report['unknown quests'] += 1
            else:
                for nid in q[0]:
                    if nid in npcs:
                        points += pts(npcs[nid][3])
                        G.setdefault(key, npcs[nid][0])
                for oid in q[1]:
                    if oid in objects:
                        points += pts(objects[oid][1])
                if not q[0] and not q[1]:
                    report['quest item start' if q[2] else 'quest without starter'] += 1
        elif kind in ('V', 'R', 'W'):
            cands = by_name.get(rest, [])
            zones = {z if z > 0 else neg.get(-z) for z in _rec_zones(recs)} - {None}
            inzone = [n for n in cands if npcs[n][1] in zones or any(p[0] in zones for p in pts(npcs[n][3]))]
            if inzone:
                cands = inzone
            elif len({npcs[n][1] for n in cands}) > 1:
                report['ambiguous'].append(key)
            for n in cands:
                points += pts(npcs[n][3])
        elif kind == 'U':
            n = npcs.get(int(rest))
            if n:
                points = pts(n[3])
        elif kind == 'I':
            area = next(iter(sorted(_rec_areas(recs))), None) or instances.get(int(rest))
            if area in dungeons:
                points = pts(dungeons[area][1])
        elif kind == 'N':
            area = dungeon_by_name(rest)
            if area:
                points = pts(dungeons[area][1])
        elif kind == 'F':
            name = QUARTERMASTERS.get(int(rest))
            if not name:
                report['factions without quartermaster'].append(int(rest))
            else:
                G[key] = name
                for n in by_name.get(name, []):
                    points += pts(npcs[n][3])
        P[key] = pick_points(points)
        for k in sorted({r[0] for r in recs}):
            w, wo = report['kinds'].get(k, (0, 0))
            report['kinds'][k] = (w + 1, wo) if P[key] else (w, wo + 1)
    return P, G, report


# ---------------------------------------------------------------- output
def write_lua(out, game, P, G, commit, built):
    lua_str = build_gear.lua_str
    commit = (commit or 'master')[:10]
    guard = ('if not (ns.IsForever and ns.IsForever()) then return end' if game == 'forever'
             else 'if ns.IsForever and ns.IsForever() then return end')
    lines = [
        '-- GENERATED by tools/build_map.py. Do not edit; rebuild instead.',
        f'-- Sources: QuestieDB ({QUESTIE_LICENSE}) npc, object, quest and zone data at {commit}; '
        f"Amisia's quartermaster list.",
        'local _, ns = ...',
        guard,
        '',
        '-- P: [source key] = up to four points "uiMapID:x:y" (x, y in hundredths of a percent, 0-10000),',
        '-- separated by spaces. Keys: Q:<quest id> (where the quest starts), V:, R:, W:<NPC name> (vendor,',
        '-- rare, named mob), U:<NPC id>, I:<instance id> and N:<dungeon name> (entrance), F:<faction id>',
        '-- (quartermaster). G: [source key] = who stands there (quest giver, quartermaster), English.',
        'ns.MAP = {',
        f'    game = {lua_str(game)}, built = {lua_str(built)}, questie = {lua_str(commit)},',
        '    P = {',
    ]
    for key in sorted(P):
        if P[key]:
            lines.append(f'        [{lua_str(key)}] = {lua_str(fmt_points(P[key]))},')
    lines.append('    },')
    lines.append('    G = {')
    for key in sorted(G):
        if P.get(key):
            lines.append(f'        [{lua_str(key)}] = {lua_str(G[key])},')
    lines.append('    },')
    lines.append('}')
    text = '\n'.join(lines) + '\n'
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    return sum(1 for k in P if P[k])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--refresh-questie', action='store_true', help='download the database files again (see tools/README.md)')
    ap.add_argument('--questie-ref', default='master', help='branch, tag or commit to download (default master)')
    ap.add_argument('--game', choices=('forever', 'tbc', 'both'), default='both')
    args = ap.parse_args(argv)
    games = ['forever', 'tbc'] if args.game == 'both' else [args.game]

    gear = {}
    for game in games:
        recs, has_game = load_gear(GEAR[game], game)
        gear[game] = needed_keys(recs, has_game)

    texts, commit = (None, None) if args.refresh_questie else load_cached()
    if args.refresh_questie:
        texts, commit = refresh_questie(ref=args.questie_ref)
    stored = {}
    if os.path.exists(MAP_JSON):
        with open(MAP_JSON, encoding='utf-8') as fh:
            stored = json.load(fh)
    if texts is not None:
        fresh = dict(stored)
        if stored.get('commit') != commit:
            fresh = {}
        fresh.update({'source': f'https://github.com/{QUESTIE_REPO}', 'license': QUESTIE_LICENSE,
                      'commit': commit or args.questie_ref,
                      'fetched': stored.get('fetched') if stored.get('commit') == commit and stored.get('fetched')
                      else time.strftime('%Y-%m-%d')})
        for game in games:
            fresh[game] = parse_questie(texts[game], game, gear[game])
        with open(MAP_JSON, 'w', encoding='utf-8', newline='\n') as fh:
            json.dump(fresh, fh, ensure_ascii=False, indent=1, sort_keys=True)
            fh.write('\n')
        log(f'quest database: read -> {os.path.relpath(MAP_JSON, ROOT)} ({os.path.getsize(MAP_JSON) // 1024} KB)')
        stored = fresh
    elif not stored:
        raise SystemExit('no tools/map_questie.json and no download in tools/cache/questiedb: run with --refresh-questie')
    else:
        log('quest database: no complete download in tools/cache/questiedb, building from tools/map_questie.json')

    for game in games:
        if game not in stored:
            raise SystemExit(f'tools/map_questie.json has no {game} data: run with --refresh-questie')
        P, G, report = resolve(stored[game], gear[game], game)
        n = write_lua(OUT[game], game, P, G, stored.get('commit'), stored.get('fetched') or time.strftime('%Y-%m-%d'))
        log(f'{game}: places per source kind (with / without): '
            + ', '.join(f'{k} {w}/{wo}' for k, (w, wo) in sorted(report['kinds'].items())))
        for kind in ('Q', 'V', 'R', 'W', 'U', 'I', 'N', 'F'):
            keys = [k for k in P if k.startswith(kind + ':')]
            if keys:
                log(f'  keys {kind}: {sum(1 for k in keys if P[k])} of {len(keys)} with a place')
        if report['unknown areas']:
            log(f'  areas without a map: {len(report["unknown areas"])} ({report["unknown areas"][:12]})')
        if report['ambiguous']:
            log(f'  names in more than one zone, none in the source zone: {len(report["ambiguous"])} '
                f'({report["ambiguous"][:8]})')
        log(f'  quests started by an item: {report["quest item start"]}, without starter: '
            f'{report["quest without starter"]}, unknown: {report["unknown quests"]}')
        if report['factions without quartermaster']:
            log(f'  factions without quartermaster: {report["factions without quartermaster"]}')
        missing = [k for k in P if not P[k]]
        if missing:
            log(f'  without a place: {missing[:20]}{" ..." if len(missing) > 20 else ""}')
        log(f'{os.path.relpath(OUT[game], ROOT)}: {n} keys with a place, {os.path.getsize(OUT[game]) // 1024} KB')


if __name__ == '__main__':
    main()
