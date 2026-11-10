"""Builds Amisia/Data/MapData.lua (WoW Forever): where the sources of the gear data stand on the
world map. Quest givers and starts, vendors, rare and named mobs come from the coordinates the
data gives them, raids and dungeons from their entrances. Runs without a WoW install (on the N100).

    python tools/build_map.py [--att DIR] [--refresh-att] [--wago DIR] [--sv FILE...]

F-105 adds the places on the world map: the entrance of every dungeon and raid of the facts (client
table Map, AllTheThings, the learned ones), flight points (F) from the client table TaxiNodes with
the flight masters' names of AllTheThings (F-171), and docks (T) from the hand list
tools/forever_transports.json; see the block "places on the map" below and tools/README.md.

Sources (named with their licence in tools/README.md and in the header of the generated file):
  - AllTheThings' hand-kept Forever data (tools/att_data.py; MIT, the licence ships in
    Amisia/LICENSES/): the coordinates of quests (where the giver or start object stands),
    of rares, vendors and other NPCs, and of dungeon and raid entrances. --refresh-att downloads it
    into ~/addons/_cache/att (outside the repo); the folder's commit is named in the output.
    A place inside a dungeon stands for its entrance.
  - The generated gear data (GearData.lua): which places are needed at all.
  - Instance ids (I:<id> keys) are matched to the data's instances through the client's
    UiMapAssignment and AreaTable tables in --wago (default: the newest copy of each table, tools/client_tables.py)
    and tools/forever_dungeons.json; without them those keys stay without a place and the
    dungeon is found by its name (N:<name>).

Points are "uiMapID:x:y" with x and y in hundredths of a percent (0-10000), at most four per key.
No other quest database is read.
"""
import argparse
import json
import math
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402  (the AllTheThings reader)
import lua_data  # noqa: E402  (the lazy form of the data files)
import build_gear  # noqa: E402  (Lua strings, dungeon name keys, the dungeon facts)

GEAR = os.path.join(ROOT, 'Amisia', 'Data', 'GearData.lua')
OUT = os.path.join(ROOT, 'Amisia', 'Data', 'MapData.lua')
MAX_POINTS = 4
MERGE = 200          # points closer than 2 % (in hundredths of a percent) are one
PLACEHOLDER = (5000, 5000)   # an entrance given as the middle of its zone: not measured yet


def log(*a):
    print(*a, file=sys.stderr)


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


# ---------------------------------------------------------------- points
def pick_points(points, n=MAX_POINTS):
    """At most n points far apart: points within 2 % are one, then greedily the point farthest from
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
return function(src)
    local ns = {}
    local f = assert(loadstring(src, "@gear"))
    setfenv(f, {})
    f("Amisia", ns)
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


def load_gear_text(text):
    """The source records of a gear data file (as lists, trailing nils dropped) and whether it has
    the game field (data built before it holds a zone in a dungeon record's instance field)."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    recs, has_game = lua.execute(GEAR_STUB)(lua_data.eager(text))
    out = []
    for rec in seq(py(recs)):
        out.append([None if v == '\0nil' else v for v in seq(rec)])
    return out, bool(has_game)


def load_gear(path=GEAR):
    with open(path, encoding='utf-8') as fh:
        return load_gear_text(fh.read())


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
    """The zones (uiMapIDs) the records name for their place."""
    out = set()
    for rec in recs:
        field = {'V': 3, 'P': 3, 'R': 4, 'W': 5}.get(rec[0])
        z = _at(rec, field) if field else None
        if isinstance(z, (int, float)) and z > 0:
            out.add(int(z))
    return out


def _rec_names(recs):
    """The dungeon or raid names the records give (for an I:<id> key whose id the data lacks)."""
    return [rec[1] for rec in recs if rec[0] in ('D', 'X') and isinstance(_at(rec, 2), str)]


# ---------------------------------------------------------------- resolving keys to points
class Atlas:
    """The places of the AllTheThings data: entrances per instance, points per NPC and quest."""

    def __init__(self, att, facts=()):
        self.att = att
        self.npcs, self.quests = att.get('npcs', {}), att.get('quests', {})
        self.instances = att.get('instances', {})
        self.inst_maps = {}     # uiMapID of an instance -> ATT instance id
        for iid, i in sorted(self.instances.items()):
            for m in i.get('maps') or []:
                self.inst_maps.setdefault(m, iid)
        self.places = build_gear.Places(att, facts)
        self.by_key = {}        # dungeon_key(name) -> ATT instance id
        for iid in sorted(self.instances):
            i = self.instances[iid]
            for n in (i['name'], i.get('stem'), self.places.of_att(iid)[0]):
                if n:
                    self.by_key.setdefault(build_gear.dungeon_key(n), iid)
        for f in facts or ():
            iid = self.by_key.get(build_gear.dungeon_key(f['name']))
            for n in list(f.get('aliases') or []) + ([f['part']] if f.get('part') else []):
                if iid is not None:
                    self.by_key.setdefault(build_gear.dungeon_key(n), iid)
        self.by_name = {}
        for nid in sorted(self.npcs):
            name = self.npcs[nid].get('name')
            if name:
                self.by_name.setdefault(name, []).append(nid)

    def entrance(self, iid):
        """An instance's entrance points: its coordinates outside its own maps. The data marks an
        entrance nobody has measured yet with the middle of the zone (50, 50): that is no place."""
        i = self.instances.get(iid)
        if not i:
            return []
        own = set(i.get('maps') or [])
        return [p for p in i.get('points') or [] if p[0] not in own and p[1:] != PLACEHOLDER]

    def outside(self, points):
        """Points, those on an instance's map replaced by that instance's entrance."""
        out = []
        for p in points:
            iid = self.inst_maps.get(p[0])
            for q in (self.entrance(iid) if iid is not None else [p]):
                if q not in out:
                    out.append(q)
        return out

    def npc_points(self, nid):
        n = self.npcs.get(nid)
        if not n:
            return []
        if n.get('points'):
            return self.outside(n['points'])
        # an NPC inside an instance without coordinates of its own: the entrance
        return self.entrance(n['inst']) if n.get('inst') is not None else []

    def instance_by_name(self, name):
        key = build_gear.dungeon_key(name or '')
        if key in self.by_key:
            return self.by_key[key]
        near = sorted((abs(len(k) - len(key)), k) for k in self.by_key if key and k and (k in key or key in k))
        return self.by_key[near[0][1]] if near else None

    def instance_by_id(self, inst):
        for iid in sorted(self.instances):
            if self.places.of_att(iid)[1] == inst:
                return iid
        return None


def resolve(att, needed, facts=()):
    """{key: [points]} for every needed key (empty where no place is known), {key: who stands there}
    and a report."""
    atlas = Atlas(att, facts)
    report = {'kinds': {}, 'ambiguous': [], 'quest item start': 0, 'quest without place': 0, 'unknown quests': 0,
              'unknown instances': []}
    P, G = {}, {}
    for key in sorted(needed):
        recs = needed[key]
        kind, _, rest = key.partition(':')
        points = []
        if kind == 'Q':
            q = atlas.quests.get(int(rest))
            if not q:
                report['unknown quests'] += 1
            else:
                points = atlas.outside(q.get('points') or [])
                if not points:
                    for nid in q.get('givers') or []:
                        points += atlas.npc_points(nid)
                if not points and q.get('inst') is not None and q.get('inside'):
                    points = atlas.entrance(q['inst'])
                if q.get('giver'):
                    G[key] = q['giver']
                if not points:
                    report['quest item start' if q.get('startItem') else 'quest without place'] += 1
        elif kind in ('V', 'R', 'W'):
            cands = atlas.by_name.get(rest, [])
            zones = _rec_zones(recs)
            inzone = [n for n in cands if atlas.npcs[n].get('zone') in zones
                      or any(p[0] in zones for p in atlas.npcs[n].get('points') or [])]
            if inzone:
                cands = inzone
            elif len({atlas.npcs[n].get('zone') for n in cands}) > 1:
                report['ambiguous'].append(key)
            for n in cands:
                points += atlas.npc_points(n)
        elif kind == 'U':
            points = atlas.npc_points(int(rest))
        elif kind == 'I':
            iid = atlas.instance_by_id(int(rest))
            if iid is None:
                for name in _rec_names(recs):
                    iid = atlas.instance_by_name(name)
                    if iid is not None:
                        break
            if iid is None:
                report['unknown instances'].append(int(rest))
            else:
                points = atlas.entrance(iid)
        elif kind == 'N':
            iid = atlas.instance_by_name(rest)
            if iid is not None:
                points = atlas.entrance(iid)
        P[key] = pick_points(points)
        for k in sorted({r[0] for r in recs}):
            w, wo = report['kinds'].get(k, (0, 0))
            report['kinds'][k] = (w + 1, wo) if P[key] else (w, wo + 1)
    return P, G, report


# ---------------------------------------------------------------- places on the map (F-105)
# Flight masters, zeppelin towers and ship docks, and the entrance of every dungeon and raid of the
# facts, from these sources in this order:
#   entrances:  the client table Map (Corpse_0/Corpse_1 on CorpseMapID: where a ghost comes back,
#               at the instance portal; turned into a zone map's x/y through UiMapAssignment),
#               AllTheThings, then the entrances the addon learned when a player entered
#               (tools/entrance_archive.json).
#   flights:    the client table TaxiNodes (position, side, place; F-171, D-102) with the names of
#               AllTheThings' flight masters, then the hand list's it lacks; without the table
#               AllTheThings' fp() records with their flight master, then the hand list's.
#   docks:      the hand list tools/forever_transports.json.
ENTRANCES = os.path.join(HERE, 'entrance_archive.json')
TRANSPORTS = os.path.join(HERE, 'forever_transports.json')
CONTINENTS = (947, 1414, 1415, 1463, 1464)   # world and continent maps: an entrance stands on a zone
FAR = 800            # a second entrance of a later source counts from 8 % away
SOURCE_CODES = {'client': 'c', 'att': 'a', 'learned': 'l'}
# short destination names that are not the client's area names
AREA_ALIASES = {"Grom'gol": "Grom'gol Base Camp", 'Theramore': 'Theramore Isle'}


def hundredths(v):
    return max(0, min(10000, int(round(float(v) * 100))))


class Client:
    """The client tables the places need: instance names and entrances (Map), zone rectangles
    (UiMapAssignment), area names (AreaTable). Empty without them."""

    def __init__(self, wago):
        dirs = (wago,)
        self.rects = []        # (continent, uiMap, area, (minX, minY, maxX, maxY, ui box))
        self.zone_of_area = {}
        for r in att_data.wago_rows('UiMapAssignment', *dirs):
            try:
                ui, mid, order, area = int(r['UiMapID']), int(r['MapID']), int(r['OrderIndex'] or 0), int(r['AreaID'] or 0)
                box = tuple(float(r[k]) for k in ('Region_0', 'Region_1', 'Region_3', 'Region_4',
                                                  'UiMin_0', 'UiMin_1', 'UiMax_0', 'UiMax_1'))
            except (KeyError, ValueError):
                continue
            if mid not in (0, 1) or ui in CONTINENTS or area == 0:
                continue
            self.rects.append((mid, ui, area, box))
            if order == 0:
                self.zone_of_area.setdefault(area, ui)
        self.areas = {}        # area name -> area id (the open world's first)
        for r in att_data.wago_rows('AreaTable', *dirs):
            try:
                aid, cont = int(r['ID']), int(r['ContinentID'])
            except (KeyError, ValueError):
                continue
            name = r.get('AreaName_lang') or ''
            if cont in (0, 1) and name:
                self.areas.setdefault(name, aid)
        self.instances = {}    # instance id -> {'name', 'corpse': (continent, x, y) or None}
        for r in att_data.wago_rows('Map', *dirs):
            try:
                mid, itype = int(r['ID']), int(r['InstanceType'] or 0)
                cx, cy, cm = float(r['Corpse_0']), float(r['Corpse_1']), int(r['CorpseMapID'])
            except (KeyError, ValueError):
                continue
            if itype not in (1, 2) or mid in self.instances:
                continue
            self.instances[mid] = {'name': r.get('MapName_lang') or '',
                                   'corpse': (cm, cx, cy) if cm in (0, 1) and (cx or cy) else None}

    def zone(self, name):
        """The uiMap of a zone by its English name, or None."""
        aid = self.areas.get(name or '')
        return self.zone_of_area.get(aid) if aid is not None else None

    def area(self, name):
        """The area id of a place name ("Booty Bay, Stranglethorn Vale": its first part), or None."""
        first = (name or '').split(',')[0].strip()
        return self.areas.get(AREA_ALIASES.get(first, first))

    def on_zones(self, cont, wx, wy):
        """[(uiMap, x, y, depth)] of every zone whose rectangle holds the world point; depth is how
        far inside (0 at an edge, 0.5 in the middle)."""
        out = []
        for mid, ui, _, (x0, y0, x1, y1, u0, v0, u1, v1) in self.rects:
            if mid != cont or x1 <= x0 or y1 <= y0 or not (x0 <= wx <= x1 and y0 <= wy <= y1):
                continue
            # the map's x runs west to east (the world's y falls), its y north to south (x falls)
            fx, fy = (y1 - wy) / (y1 - y0), (x1 - wx) / (x1 - x0)
            x, y = u0 + (u1 - u0) * fx, v0 + (v1 - v0) * fy
            out.append((ui, hundredths(x * 100), hundredths(y * 100), min(fx, 1 - fx, fy, 1 - fy)))
        return out

    def entrance(self, inst, hints=()):
        """The entrance of an instance as a zone point, or None: on a hinted zone (where another
        source puts it) when one holds it, else on the zone that holds it deepest."""
        i = self.instances.get(inst)
        if not i or not i['corpse']:
            return None
        cands = self.on_zones(*i['corpse'])
        if not cands:
            return None
        for h in hints:
            for c in cands:
                if c[0] == h:
                    return c[:3]
        return max(cands, key=lambda c: (c[3], -c[0]))[:3]


def _near(p, points, d):
    return any(q[0] == p[0] and math.hypot(p[1] - q[1], p[2] - q[2]) < d for q in points)


def merge_entrances(sources):
    """The points of an entrance from [(source name, [points])] in their order: the first source with
    a point wins; a later client or AllTheThings point joins it on a map the winner has no point on
    (the dungeon's own outdoor map, as Uldaman's or Blackrock Mountain's), or, when that source knows
    more than one entrance, 8 % away from every point (Uldaman's back door). A single point of a
    later source elsewhere on the same zone is the same entrance measured worse. Continent maps are
    left out. Returns (points, the winning source or None)."""
    out, won = [], None
    for name, pts in sources:
        pts = [p for p in pts if p[0] not in CONTINENTS]
        if not pts:
            continue
        if won is None:
            won = name
            for p in pts:
                if not _near(p, out, MERGE):
                    out.append(p)
        elif name in ('client', 'att'):
            maps = {q[0] for q in out}
            for p in pts:
                if (p[0] not in maps or (len(pts) > 1 and not _near(p, out, FAR))) and not _near(p, out, MERGE):
                    out.append(p)
    return out[:MAX_POINTS], won


# ---------------------------------------------------------------- learned entrances (AmisiaDB.entrances)
def load_entrance_archive(path=ENTRANCES):
    if not os.path.exists(path):
        return {'updated': None, 'entrances': {}}
    with open(path, encoding='utf-8') as fh:
        arch = json.load(fh)
    arch.setdefault('entrances', {})
    return arch


def learned_from_sv(db):
    """{instance id: {'map', 'x', 'y', 'name', 'kind', 'seen'}} of a SavedVariables' AmisiaDB.entrances
    (the addon's record when a player entered an instance), checked as the addon checks it."""
    out = {}
    e = db.get('entrances') if isinstance(db, dict) else None
    lst = e.get('list') if isinstance(e, dict) else None
    if not isinstance(lst, dict):
        return out
    for k, r in lst.items():
        inst = k if isinstance(k, int) else None
        if inst is None or inst <= 0 or not isinstance(r, dict):
            continue
        m, x, y, t = r.get('m'), r.get('x'), r.get('y'), r.get('t')
        if not all(isinstance(v, int) and not isinstance(v, bool) for v in (m, x, y, t)):
            continue
        if m <= 0 or not (0 <= x <= 10000 and 0 <= y <= 10000) or t <= 0:
            continue
        name = r.get('n') if isinstance(r.get('n'), str) else ''
        out[inst] = {'map': m, 'x': x, 'y': y, 'name': name[:60],
                     'kind': r.get('k') if r.get('k') in ('party', 'raid') else '', 'seen': t}
    return out


def join_entrances(arch, learned):
    """Joins learned entrances into the archive: a newer sighting of an instance replaces the older,
    nothing is dropped. Returns how many changed."""
    n = 0
    for inst, r in sorted(learned.items()):
        key = str(inst)
        have = arch['entrances'].get(key)
        if (have is None or r['seen'] > have.get('seen', 0)) and have != r:
            arch['entrances'][key] = r
            n += 1
    return n


def _archive_text(arch):
    ents = dict(sorted(arch['entrances'].items(), key=lambda kv: int(kv[0])))
    return json.dumps({'updated': arch.get('updated'), 'entrances': ents}, ensure_ascii=False, indent=1) + '\n'


def save_entrance_archive(arch, path=ENTRANCES, today=None):
    """Writes the archive when its entrances changed (then with today's date). True when it wrote."""
    old = load_entrance_archive(path)
    if old['entrances'] == arch['entrances'] and os.path.exists(path):
        return False
    arch['updated'] = today or time.strftime('%Y-%m-%d')
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(_archive_text(arch))
    return True


def update_learned(svs, path=ENTRANCES):
    """Joins the SavedVariables' learned entrances into the archive; returns the archive's
    entrances as {instance id: record}."""
    import build_scan
    arch = load_entrance_archive(path)
    for p in svs:
        n = join_entrances(arch, learned_from_sv(build_scan.load_sv(p)))
        log(f'{p}: {n} learned entrances new or newer')
    if save_entrance_archive(arch, path):
        log(f'{os.path.relpath(path, ROOT)}: {len(arch["entrances"])} learned entrances')
    return {int(k): v for k, v in arch['entrances'].items()}


# ---------------------------------------------------------------- entrances, flights, docks
def fact_key(f):
    """The map key of a fact's entrance: I:<instance id> where the facts know it, else N:<name>."""
    return f'I:{f["inst"]}' if isinstance(f.get('inst'), int) and f['inst'] > 0 else f'N:{f["name"]}'


def fact_names(f):
    return [f['name']] + list(f.get('aliases') or []) + ([f['part']] if f.get('part') else [])


def entrances(facts, att, client, learned):
    """{fact key: (points, winning source)} for every fact; see merge_entrances for the order."""
    atlas = Atlas(att, facts)
    # learned entrances by instance id, and by the client's (English) name of the instance for a
    # dungeon the facts know no id of
    learned_by = {}
    for inst, r in sorted((learned or {}).items()):
        learned_by[('inst', inst)] = r
        for n in ((client.instances.get(inst) or {}).get('name'), r.get('name')):
            if n:
                learned_by.setdefault(build_gear.dungeon_key(n), r)
    out = {}
    for f in facts:
        keys = [build_gear.dungeon_key(n) for n in fact_names(f)]
        inst = f.get('inst') if isinstance(f.get('inst'), int) else None
        iid = atlas.instance_by_id(inst) if inst else None
        if iid is None:
            iid = next((atlas.by_key[k] for k in keys if k in atlas.by_key), None)
        att_pts = atlas.entrance(iid) if iid is not None else []
        hints = [p[0] for p in att_pts]
        cl = client.entrance(inst, hints) if inst else None
        lr = (learned_by.get(('inst', inst)) if inst else None) or next((learned_by[k] for k in keys if k in learned_by), None)
        lr_pts = [(lr['map'], lr['x'], lr['y'])] if lr else []
        out[fact_key(f)] = merge_entrances([('client', [cl] if cl else []), ('att', att_pts),
                                            ('learned', lr_pts)])
    return out


def apply_entrances(P, facts, ent):
    """Puts the entrances into P: the facts' keys, and every I:/N: key of the gear data that names
    one of them (by instance id or name) gets the same points. Returns {key: source code}."""
    by = {}
    for f in facts:
        e = ent.get(fact_key(f))
        if not e or not e[0]:
            continue
        if isinstance(f.get('inst'), int):
            by.setdefault(f'I:{f["inst"]}', e)
        for n in fact_names(f):
            by.setdefault('N:' + build_gear.dungeon_key(n), e)
    E = {}
    for f in facts:
        k = fact_key(f)
        if ent.get(k) and ent[k][0]:
            P[k] = ent[k][0]
            E[k] = SOURCE_CODES[ent[k][1]]
    for k in list(P):
        e = None
        if k.startswith('I:'):
            e = by.get(k)
        elif k.startswith('N:'):
            e = by.get('N:' + build_gear.dungeon_key(k[2:]))
        if e:
            P[k] = e[0]
            E[k] = SOURCE_CODES[e[1]]
    return E


def flights(att, hand=()):
    """[(map, x, y, faction A/H/N, name)]: AllTheThings' flight masters, then the hand list's it lacks
    (neither the same NPC name nor a point within 2 % of one for the same faction: Booty Bay and
    Everlook have one per faction side by side). Returns (list, count from AllTheThings)."""
    out = []

    def add(p, side, name):
        side = side or 'N'
        rivals = [f[:3] for f in out if 'N' in (f[3], side) or f[3] == side]
        if name in {f[4] for f in out} or _near(p, rivals, MERGE):
            return False
        out.append((p[0], p[1], p[2], side, name))
        return True
    from_att = 0
    for _, r in sorted((att or {}).get('flights', {}).items()):
        if not r.get('npc') or not r.get('points'):
            continue      # a path without its flight master (the tower flights) is no place to go
        from_att += add(r['points'][0], r['faction'], r.get('name') or r.get('place') or '?')
    for f in hand or []:
        add((int(f['map']), hundredths(f['x']), hundredths(f['y'])), {'A': 'A', 'H': 'H'}.get(f.get('faction')), f['name'])
    return sorted(out), from_att


# ---------------------------------------------------------------- flight points of the client (F-171)
# TaxiNodes holds every flight point of the client with its world position (Pos_0 the world's x, Pos_1
# its y, as Map's Corpse_0/1). Its Flags bit 0x1 shows a node on the Alliance's flight map, 0x2 on the
# Horde's; CharacterBitNumber is the node's bit in what a character has learned (0: nobody learns it).
# Read from the data of 1.60.1.70888 against the 60 flight masters AllTheThings knows (D-102): 58 stand
# on a node with one of the two bits and a bit number, of the same side as AllTheThings' races; the
# other two are the druids' Nighthaven nodes (no bit number, sides swapped against AllTheThings). The
# nodes without either bit are quest paths, transports, "Generic" targets, test places.
TAXI_ALLIANCE, TAXI_HORDE = 0x1, 0x2
TAXI_CONTINENTS = (0, 1)        # Eastern Kingdoms, Kalimdor: the continents UiMapAssignment places
MATCH = 300                     # a flight master of AllTheThings within 3 % of a node is that node's


def taxi_nodes(wago):
    """The rows of TaxiNodes in wago as [{'id', 'name', 'cont', 'x', 'y', 'flags', 'bit', 'cond'}]
    (empty without the table)."""
    out = []
    for r in att_data.wago_rows('TaxiNodes', wago):
        try:
            out.append({'id': int(r['ID']), 'name': (r.get('Name_lang') or '').strip(),
                        'cont': int(r['ContinentID']), 'x': float(r['Pos_0']), 'y': float(r['Pos_1']),
                        'flags': int(r.get('Flags') or 0), 'bit': int(r.get('CharacterBitNumber') or 0),
                        'cond': int(r.get('ConditionID') or 0)})
        except (KeyError, ValueError):
            continue
    return sorted(out, key=lambda n: n['id'])


def node_side(n):
    """A, H or N (both) by the node's flags; None when neither side's flight map shows it."""
    a, h = bool(n['flags'] & TAXI_ALLIANCE), bool(n['flags'] & TAXI_HORDE)
    return 'N' if a and h else 'A' if a else 'H' if h else None


def node_unusable(n):
    """Why a player never flies from this node (a short English reason), or None when it is a flight
    point: the client's own "zzOLD" names (old copies, each on the spot of a live node), another
    continent than the two the map places (Alterac Valley, a scenario's quest path), no side's flight
    map shows it (quest paths, transports, test places; Powderfuse Port and Tidegear Coast too), no
    character learns it (the druids' Nighthaven flights, the Plaguelands towers)."""
    if n['name'].lower().startswith('zzold'):
        return 'an old copy (the client names it zzOLD)'
    if n['cont'] not in TAXI_CONTINENTS:
        return f'continent {n["cont"]} (not Eastern Kingdoms or Kalimdor)'
    if node_side(n) is None:
        return f'no side\'s flight map shows it (flags 0x{n["flags"]:x})'
    if n['bit'] <= 0:
        return 'no character learns it (no CharacterBitNumber)'
    return None


def node_points(client, n):
    """Every zone point (uiMap, x, y) that holds the node, the best first: the zone its name ends in
    ("Gadgetzan, Tanaris") when that zone holds it, then by how deep inside; empty when none does."""
    cands = client.on_zones(n['cont'], n['x'], n['y'])
    zone = client.zone(n['name'].split(',')[-1].strip())
    cands.sort(key=lambda c: (c[0] != zone, -c[3], c[0]))
    return [c[:3] for c in cands]


def _dist(pts, q):
    """The distance of q from the point of pts on q's zone (inf when none is on it) and that point."""
    for p in pts:
        if p[0] == q[0]:
            return math.hypot(p[1] - q[1], p[2] - q[2]), p
    return math.inf, None


def table_flights(client, nodes, att, hand=()):
    """[(map, x, y, side, name, place)] of the client's flight points and a report. Position, side and
    place name (field 6) come from TaxiNodes; name is the flight master's from AllTheThings where one of
    the same side stands within 3 % of the node (each one used once, the closest pairs first), else one
    of the same id and side further away (the place moved), else the node's name. A flight master of
    the hand list joins only where no node stands (neither its name nor a point within 2 % of the same
    side). Report: 'excluded' [(id, name, why)], 'matched' [(id, npc name, distance)], 'far' (matched
    by id only), 'side' [(id, name, table side, ATT side)] where both know the id, 'att_only' (ATT
    flight masters no node took), 'no_zone' (nodes no zone holds), 'hand' (hand entries kept)."""
    rep = {'excluded': [], 'matched': [], 'far': [], 'side': [], 'att_only': [], 'no_zone': [], 'hand': []}
    att_fl = {fid: r for fid, r in sorted(((att or {}).get('flights') or {}).items())
              if r.get('npc') and r.get('points')}
    live = []
    for n in nodes:
        why = node_unusable(n)
        if why:
            rep['excluded'].append((n['id'], n['name'], why))
            continue
        pts = node_points(client, n)
        if not pts:
            rep['no_zone'].append((n['id'], n['name']))
            continue
        live.append((n, pts, node_side(n)))
    by_id = {n['id']: n for n in nodes}
    for fid, r in att_fl.items():
        if fid in by_id and node_side(by_id[fid]) and (r.get('faction') or 'N') != node_side(by_id[fid]):
            rep['side'].append((fid, by_id[fid]['name'], node_side(by_id[fid]), r.get('faction') or 'N'))
    # the flight masters: closest pairs of the same side first
    pairs = sorted((_dist(pts, r['points'][0])[0], n['id'], fid) for n, pts, side in live
                   for fid, r in att_fl.items() if (r.get('faction') or 'N') == side
                   and _dist(pts, r['points'][0])[0] <= MATCH)
    npc_of, used = {}, set()
    for d, nid, fid in pairs:
        if nid in npc_of or fid in used:
            continue
        npc_of[nid] = fid
        used.add(fid)
        rep['matched'].append((nid, att_fl[fid].get('name') or '?', round(d)))
    for n, pts, side in live:
        fid = n['id']
        if fid not in npc_of and fid in att_fl and fid not in used and (att_fl[fid].get('faction') or 'N') == side:
            npc_of[fid] = fid
            used.add(fid)
            d = _dist(pts, att_fl[fid]['points'][0])[0]
            rep['far'].append((fid, att_fl[fid].get('name') or '?', None if d == math.inf else round(d)))
    rep['att_only'] = [(fid, r.get('name') or '?', r.get('faction') or 'N') for fid, r in att_fl.items()
                       if fid not in used]
    out = []
    for n, pts, side in live:
        fid = npc_of.get(n['id'])
        # on the zone AllTheThings puts its flight master (a city rather than the zone around it)
        p = (_dist(pts, att_fl[fid]['points'][0])[1] if fid is not None else None) or pts[0]
        name = (att_fl[fid].get('name') if fid is not None else None) or n['name']
        out.append((p[0], p[1], p[2], side, name, n['name']))
    for f in hand or []:
        p = (int(f['map']), hundredths(f['x']), hundredths(f['y']))
        side = {'A': 'A', 'H': 'H'}.get(f.get('faction'), 'N')
        rivals = [o[:3] for o in out if 'N' in (o[3], side) or o[3] == side]
        if f['name'] in {o[4] for o in out} or _near(p, rivals, MERGE):
            continue
        out.append(p + (side, f['name'], ''))
        rep['hand'].append(f['name'])
    return sorted(out), rep


def report_flights(F, rep, client):
    """The report of the client's flight points (build_map.py's output and D-102)."""
    cont_of = {ui: mid for mid, ui, _, _ in client.rects}
    sides = {}
    for f in F:
        cont = {0: 'Eastern Kingdoms', 1: 'Kalimdor'}.get(cont_of.get(f[0]), 'elsewhere')
        sides[(cont, f[3])] = sides.get((cont, f[3]), 0) + 1
    log(f'flight points from TaxiNodes: {len(F)} ('
        + ', '.join(f'{c} {s} {k}' for (c, s), k in sorted(sides.items())) + ')')
    log(f'  flight masters of AllTheThings matched: {len(rep["matched"])} within 3 %, {len(rep["far"])} by id further away'
        + (': ' + ', '.join(f'{i} {nm} ({d / 100 if d is not None else "?"} %)' for i, nm, d in rep['far']) if rep['far'] else ''))
    if rep['side']:
        log('  side of TaxiNodes against AllTheThings (same id): '
            + ', '.join(f'{i} {nm} table {a} ATT {b}' for i, nm, a, b in rep['side']))
    if rep['att_only']:
        log('  flight masters of AllTheThings no node took: ' + ', '.join(f'{i} {nm} ({s})' for i, nm, s in rep['att_only']))
    if rep['no_zone']:
        log('  nodes no zone holds: ' + ', '.join(f'{i} {nm}' for i, nm in rep['no_zone']))
    if rep['hand']:
        log('  by hand (no node there): ' + ', '.join(rep['hand']))
    log(f'  left out: {len(rep["excluded"])}')
    for i, nm, why in rep['excluded']:
        log(f'    {i} {nm}: {why}')


def load_transports(path=TRANSPORTS):
    """The hand list: {'docks': [...], 'flights': [...]} (empty lists without the file)."""
    data = {}
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
    return {'docks': data.get('docks', []), 'flights': data.get('flights', [])}


def transports(client, hand):
    """[(map, x, y, kind Z/S, faction A/H/N, ((area id or 0, English name), ...))]: the hand list's
    zeppelin towers and ship docks, one per place and kind."""
    out = []

    def dests(names):
        return tuple((client.area(n) or 0, n.split(',')[0].strip()) for n in names)
    for d in hand or []:
        p = (int(d['map']), hundredths(d['x']), hundredths(d['y']))
        kind = 'Z' if d['kind'] == 'zeppelin' else 'S'
        if any(t[3] == kind and _near(p, [t[:3]], MERGE) for t in out):
            continue
        out.append(p + (kind, {'A': 'A', 'H': 'H'}.get(d.get('faction'), 'N'), dests(d['to'])))
    return sorted(out)


# ---------------------------------------------------------------- output
def write_lua(out, P, G, commit, built, E=None, F=(), T=(), sources=()):
    """Writes MapData.lua. E, F and T are the places of F-105 (entrance sources, flight masters,
    docks); sources are further header lines (the client tables, the hand list)."""
    lua_str = build_gear.lua_str
    commit = (commit or '')[:10]
    lines = [
        '-- GENERATED by tools/build_map.py. Do not edit; rebuild instead.',
        f'-- Sources: {att_data.ATT_SOURCE}' + (f' at {commit}' if commit else '') + '.',
    ]
    lines += [f'-- {s}' for s in sources]
    lines += [
        'local _, ns = ...',
        '',
        '-- P: [source key] = up to four points "uiMapID:x:y" (x, y in hundredths of a percent, 0-10000),',
        '-- separated by spaces. Keys: Q:<quest id> (where the quest starts), V:, R:, W:<NPC name> (vendor,',
        '-- rare, named mob), U:<NPC id>, I:<instance id> and N:<dungeon name> (entrance).',
        '-- G: [source key] = who stands there (the quest giver), English.',
        '-- E: [entrance key] = where its points come from: c client table, a AllTheThings, l learned when a',
        '-- player entered.',
        '-- F: flight points { uiMapID, x, y, faction A/H/N (both), name (English: the flight master, else the',
        '-- place), place (English, the client\'s name of the flight point; missing for one by hand) }.',
        '-- T: docks { uiMapID, x, y, kind Z (zeppelin) / S (ship), faction A/H/N, { { area id, English name }, ... } }.',
        'ns.MAP = {',
        f'    game = "forever", built = {lua_str(built)}, source = {lua_str(commit or "none")},',
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
    if E is not None:
        lines.append('    E = {')
        for key in sorted(E):
            if P.get(key):
                lines.append(f'        [{lua_str(key)}] = {lua_str(E[key])},')
        lines.append('    },')
        lines.append('    F = {')
        for m, x, y, side, name, *place in F:
            more = f', {lua_str(place[0])}' if place and place[0] else ''
            lines.append(f'        {{ {m}, {x}, {y}, {lua_str(side)}, {lua_str(name)}{more} }},')
        lines.append('    },')
        lines.append('    T = {')
        for m, x, y, kind, side, dests in T:
            to = ', '.join(f'{{ {a}, {lua_str(n)} }}' for a, n in dests)
            lines.append(f'        {{ {m}, {x}, {y}, {lua_str(kind)}, {lua_str(side)}, {{ {to} }} }},')
        lines.append('    },')
    lines.append('}')
    text = '\n'.join(lines) + '\n'
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    # the addon builds the table on first use (Core/LazyData.lua)
    text = lua_data.lazy(text, 'MAP', sum(1 for k in P if P[k]))
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    return sum(1 for k in P if P[k])


def report_places(facts, ent, F, att_flights, T):
    """The report of F-105's places: the winning source per dungeon and what is still missing."""
    won = {}
    for f in facts:
        src = ent.get(fact_key(f), ([], None))[1]
        won.setdefault(src or 'none', []).append(f['key'])
    log('entrances per winning source: ' + ', '.join(f'{k} {len(v)}' for k, v in sorted(won.items())))
    for k, v in sorted(won.items()):
        log(f'  {k}: {" ".join(v)}')
    fl = (f'{att_flights} AllTheThings, {len(F) - att_flights} by hand' if att_flights is not None
          else f'client table TaxiNodes, {sum(1 for f in F if len(f) < 6 or not f[5])} by hand')
    log(f'flight masters: {len(F)} ({fl}); '
        f'docks: {len(T)} ({sum(1 for t in T if t[3] == "Z")} zeppelin towers, {sum(1 for t in T if t[3] == "S")} ships)')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=att_data.ATT_CACHE, help=f'AllTheThings download (default {att_data.ATT_CACHE})')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever files first')
    ap.add_argument('--wago', default=None, help='folder with the client tables (Map, UiMapAssignment, AreaTable, TaxiNodes; default: the newest copy of each table, tools/client_tables.py)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables with learned entrances (default: '
                                            '~/addons/_SavedVariables/Amisia.lua and an installed Forever client\'s)')
    ap.add_argument('--entrances', default=ENTRANCES, help='the archive of learned entrances')
    ap.add_argument('--gear', default=GEAR)
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    if args.wago is None:
        import client_tables
        args.wago = client_tables.default_dir()

    recs, has_game = load_gear(args.gear)
    needed = needed_keys(recs, has_game)
    if args.refresh_att:
        att_data.refresh(args.att)
    if not os.path.isdir(os.path.join(args.att, 'dungeons & raids')):
        raise SystemExit(f'no AllTheThings download in {args.att}: run with --refresh-att')
    att = att_data.load(args.att, items=False, wago=args.wago)
    facts = build_gear.load_facts()
    P, G, report = resolve(att, needed, facts)

    import build_scan_archive
    learned = update_learned(build_scan_archive.default_svs() if args.sv is None else args.sv, args.entrances)
    client = Client(args.wago)
    if not client.instances:
        log(f'no client table Map in {args.wago}: entrances from the other sources only '
            '(export it on the PC: tools/export_db2.ps1 -Tables Map,UiMapAssignment,AreaTable)')
    ent = entrances(facts, att, client, learned)
    E = apply_entrances(P, facts, ent)
    hand = load_transports()
    nodes = taxi_nodes(args.wago) if client.rects else []
    if nodes:
        F, flight_rep = table_flights(client, nodes, att, hand['flights'])
        att_flights = None
    else:
        log(f'no client table TaxiNodes in {args.wago}: flight masters from AllTheThings and the hand list '
            '(build.py tables, or export it on the PC: tools/export_db2.ps1 -Tables TaxiNodes)')
        F, att_flights = flights(att, hand['flights'])
    T = transports(client, hand['docks'])
    sources = []
    if client.instances:
        sources.append('Client tables Map, UiMapAssignment, AreaTable (Blizzard game data): entrances, area ids. '
                       'Learned entrances: tools/entrance_archive.json.')
    if nodes:
        sources.append('Client table TaxiNodes (Blizzard game data): flight points, their side and place; '
                       'the flight masters\' names from AllTheThings.')
    sources.append('Docks by hand: tools/forever_transports.json.' if nodes else
                   'Docks and the flight masters AllTheThings lacks by hand: tools/forever_transports.json.')
    n = write_lua(args.out, P, G, att.get('commit'), time.strftime('%Y-%m-%d'), E, F, T, sources)
    log('places per source kind (with / without): '
        + ', '.join(f'{k} {w}/{wo}' for k, (w, wo) in sorted(report['kinds'].items())))
    for kind in ('Q', 'V', 'R', 'W', 'U', 'I', 'N'):
        keys = [k for k in P if k.startswith(kind + ':')]
        if keys:
            log(f'  keys {kind}: {sum(1 for k in keys if P[k])} of {len(keys)} with a place')
    if report['ambiguous']:
        log(f'  names in more than one zone, none in the source zone: {len(report["ambiguous"])} '
            f'({report["ambiguous"][:8]})')
    if report['unknown instances']:
        log(f'  instance ids the data cannot place: {report["unknown instances"]}')
    log(f'  quests started by an item: {report["quest item start"]}, without a place: '
        f'{report["quest without place"]}, unknown: {report["unknown quests"]}')
    report_places(facts, ent, F, att_flights, T)
    if nodes:
        report_flights(F, flight_rep, client)
    log(f'{os.path.relpath(args.out, ROOT)}: {n} keys with a place, {os.path.getsize(args.out) // 1024} KB')


if __name__ == '__main__':
    main()
