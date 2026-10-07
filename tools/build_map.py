"""Builds addon/Amisia/Data/MapData.lua (WoW Forever): where the sources of the gear data stand on the
world map. Quest givers and starts, vendors, rare and named mobs come from the coordinates the
data gives them, raids and dungeons from their entrances. Runs without a WoW install (on the N100).

    python tools/build_map.py [--att DIR] [--refresh-att] [--wago DIR]

Sources (named with their licence in tools/README.md and in the header of the generated file):
  - AllTheThings' hand-kept Forever data (tools/att_data.py; MIT, the licence ships in
    addon/Amisia/LICENSES/): the coordinates of quests (where the giver or start object stands),
    of rares, vendors and other NPCs, and of dungeon and raid entrances. --refresh-att downloads it
    into ~/addons/_cache/att (outside the repo); the folder's commit is named in the output.
    A place inside a dungeon stands for its entrance.
  - The generated gear data (GearData.lua): which places are needed at all.
  - Instance ids (I:<id> keys) are matched to the data's instances through the client's
    UiMapAssignment and AreaTable tables in --wago (default ~/addons/_wago, downloaded by hand from wago.tools)
    and tools/forever_dungeons.json; without them those keys stay without a place and the
    dungeon is found by its name (N:<name>).

Points are "uiMapID:x:y" with x and y in hundredths of a percent (0-10000), at most four per key.
No other quest database is read.
"""
import argparse
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

GEAR = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'GearData.lua')
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'MapData.lua')
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


# ---------------------------------------------------------------- output
def write_lua(out, P, G, commit, built):
    lua_str = build_gear.lua_str
    commit = (commit or '')[:10]
    lines = [
        '-- GENERATED by tools/build_map.py. Do not edit; rebuild instead.',
        f'-- Sources: {att_data.ATT_SOURCE}' + (f' at {commit}' if commit else '') + '.',
        'local _, ns = ...',
        '',
        '-- P: [source key] = up to four points "uiMapID:x:y" (x, y in hundredths of a percent, 0-10000),',
        '-- separated by spaces. Keys: Q:<quest id> (where the quest starts), V:, R:, W:<NPC name> (vendor,',
        '-- rare, named mob), U:<NPC id>, I:<instance id> and N:<dungeon name> (entrance).',
        '-- G: [source key] = who stands there (the quest giver), English.',
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
    lines.append('}')
    text = '\n'.join(lines) + '\n'
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    # the addon builds the table on first use (Core/LazyData.lua)
    text = lua_data.lazy(text, 'MAP', sum(1 for k in P if P[k]))
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    return sum(1 for k in P if P[k])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=att_data.ATT_CACHE, help=f'AllTheThings download (default {att_data.ATT_CACHE})')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever files first')
    ap.add_argument('--wago', default=build_gear.WAGO, help='folder with client tables from wago.tools (UiMapAssignment, AreaTable)')
    ap.add_argument('--gear', default=GEAR)
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)

    recs, has_game = load_gear(args.gear)
    needed = needed_keys(recs, has_game)
    if args.refresh_att:
        att_data.refresh(args.att)
    if not os.path.isdir(os.path.join(args.att, 'dungeons & raids')):
        raise SystemExit(f'no AllTheThings download in {args.att}: run with --refresh-att')
    att = att_data.load(args.att, items=False, wago=args.wago)
    P, G, report = resolve(att, needed, build_gear.load_facts())
    n = write_lua(args.out, P, G, att.get('commit'), time.strftime('%Y-%m-%d'))
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
    log(f'{os.path.relpath(args.out, ROOT)}: {n} keys with a place, {os.path.getsize(args.out) // 1024} KB')


if __name__ == '__main__':
    main()
