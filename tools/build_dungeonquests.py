"""Builds addon/Amisia/DungeonQuestData.lua (WoW Forever): the quests of every dungeon and raid of
tools/forever_dungeons.json for the addon's dungeon planner - where each quest starts (the quest
giver with map points, inside the dungeon, or by an item), its level, faction, pre-quests and gear
rewards. Runs without a WoW install (on the N100).

    python tools/build_dungeonquests.py [--att DIR] [--refresh-att] [--json FILE]

The input is pluggable: every reader turns its source into one neutral form (see NEUTRAL below),
and render() writes the Lua file from that form only.

- --att DIR (default ~/addons/_cache/att): AllTheThings' hand-kept Forever data, the folder
  .contrib/.db/forever of https://github.com/ATTWoWAddon/AllTheThings (MIT licence; the copyright
  line and the licence text ship in addon/Amisia/LICENSES/). --refresh-att downloads that folder
  through the GitHub API (the repository is far too large to clone). The files are a Lua builder
  language (inst, q, e, i, n, objective, ...); read_att() runs them under lupa with stand-ins that
  only record what they are given. Names live in the files' comments; they are read from there.
- --json FILE: the neutral form as JSON (hand-made data, tests).
- Without any input the file is written empty: the addon then says the quest data is missing.

No data of other quest databases goes in.
"""
import argparse
import copy
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import build_gear  # noqa: E402  (dungeon name keys, Lua strings)

FACTS = os.path.join(HERE, 'forever_dungeons.json')
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'DungeonQuestData.lua')
ATT_CACHE = os.path.expanduser('~/addons/_cache/att')
ATT_REPO = 'ATTWoWAddon/AllTheThings'
ATT_PATH = '.contrib/.db/forever'
ATT_SOURCE = 'AllTheThings Forever data (MIT, Copyright (c) 2026 AllTheThings WoW Addon; see LICENSES/)'
USER_AGENT = build_gear.USER_AGENT

# NEUTRAL: {'source': text for the header, 'commit': text or None,
#           'dungeons': {fact key: [quest ids]},
#           'quests': {quest id: {'name', 'minLevel', 'level', 'faction' ('A', 'H', ''), 'classes' (mask),
#                                 'start' ('O' outside, 'I' inside, 'X' by an item, '' unknown), 'giver',
#                                 'points' ([(uiMapID, x, y) in hundredths of a percent]), 'preAll' [ids],
#                                 'preOne' [ids], 'dungeon' (fact key or None), 'rewards' [item ids]}}}
MAX_POINTS = 4


def log(*a):
    print(*a, file=sys.stderr)


def load_facts(path=FACTS):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)['dungeons']


def fact_key_of(facts, name=None, area=None):
    """The fact key of a dungeon by its area id or its name (name or alias), else None."""
    if area:
        for e in facts:
            if e.get('area') == area:
                return e['key']
    if name:
        k = build_gear.dungeon_key(name)
        for e in facts:
            for n in [e.get('name')] + list(e.get('aliases') or []):
                if n and build_gear.dungeon_key(n) == k:
                    return e['key']
    return None


def hundredths(v):
    return max(0, min(10000, int(v * 100 + 0.5)))


# ---------------------------------------------------------------- AllTheThings reader
ATT_STUB = r'''
local rec = {}
local function node(kind, id, t)
    if type(id) == "table" and t == nil then t, id = id, nil end
    return { _kind = kind, _id = id, _t = type(t) == "table" and t or {} }
end
local function tagged(kind) return function(id, t) return node(kind, id, t) end end
-- anything the data uses that is not stood in for: a value that can be indexed and called; a call
-- passes its last table on, so unknown wrappers keep their children
local proxy
proxy = setmetatable({}, {
    __index = function() return proxy end,
    __call = function(_, ...)
        local args, last = { ... }, nil
        for i = 1, select("#", ...) do if type(args[i]) == "table" and args[i] ~= proxy then last = args[i] end end
        return last or proxy
    end,
    __add = function() return proxy end, __sub = function() return proxy end, __mul = function() return proxy end,
    __div = function() return proxy end, __mod = function() return proxy end, __unm = function() return proxy end,
    __concat = function() return proxy end, __pow = function() return proxy end,
})
local env = setmetatable({}, { __index = function(_, k)
    local v = _G[k]
    if v ~= nil and k ~= "MAP" then return v end
    return proxy
end })
env.inst, env.q, env.e, env.i, env.n, env.objective = tagged("inst"), tagged("q"), tagged("e"), tagged("i"), tagged("n"), tagged("objective")
env.ALLIANCE_ONLY, env.HORDE_ONLY = "A", "H"
env.root = function(_, t) rec[#rec + 1] = t end
local S = {}
-- runs one data file; its root tables
function S.run(src, name)
    rec = {}
    local f = assert(loadstring(src, "@" .. name))
    setfenv(f, env)
    f()
    return rec
end
-- runs the map constants file; MAP for the data files
function S.maps(src)
    local f = assert(loadstring(src, "@maps.lua"))
    local menv = setmetatable({ print = function() end }, { __index = _G })
    setfenv(f, menv)
    f()
    env.MAP = menv.MAP
end
-- a table of the data (no stand-in)
function S.plain(v) return type(v) == "table" and v ~= proxy end
return S
'''

_Q_NAME = re.compile(r'\bq\(\s*(\d+)\s*,\s*\{\s*--\s*([^\n]+)')
_GIVER = re.compile(r'\bqg\s*"?\]?\s*=\s*(\d+)\s*,\s*--\s*([^\n<]+)')


def clean_name(text):
    """A name from a comment, without the authors' notes after it ("Name -- note", "Name // note")."""
    return re.split(r'\s+--|\s*//', text, maxsplit=1)[0].strip()


def _att_lua():
    from lupa.lua51 import LuaRuntime
    return LuaRuntime(unpack_returned_tuples=True)


def _seq(t):
    if t is None or not hasattr(t, 'items'):
        return []
    n = 0
    while t[n + 1] is not None:
        n += 1
    return [t[i] for i in range(1, n + 1)]


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def att_files(base):
    """The data files of a download: every dungeon and zone file (pre-quests live in the zones)."""
    out = []
    for sub in ('dungeons & raids', 'zones'):
        d = os.path.join(base, sub)
        for root, _, files in os.walk(d):
            for f in sorted(files):
                if f.endswith('.lua'):
                    out.append(os.path.join(root, f))
    return sorted(out)


def read_att(base, facts, commit=None):
    """The neutral form from a download of AllTheThings' .contrib/.db/forever folder."""
    lua = _att_lua()
    with open(os.path.join(base, '.config', 'constants', 'maps.lua'), encoding='utf-8') as fh:
        maps_src = fh.read()
    S = lua.execute(ATT_STUB)
    S.maps(maps_src)
    plain = S.plain
    names, givers, quests, dungeons = {}, {}, {}, {}
    report = {'files': 0, 'instances without facts': [], 'quests': 0}

    def points_of(t):
        pts = []
        c = t['coord']
        cs = [c] if c is not None else _seq(t['coords'])
        for p in cs:
            x, y, m = (_seq(p) + [None, None, None])[:3]
            if _num(x) and _num(y) and _num(m):
                pt = (int(m), hundredths(x), hundredths(y))
                if pt not in pts:
                    pts.append(pt)
        return pts[:MAX_POINTS]

    def ids_of(v):
        if _num(v):
            return [int(v)]
        return [int(x) for x in _seq(v) if _num(x)]

    def rewards_of(t):
        out = []
        for g in _seq(t['groups']):
            if plain(g) and g['_kind'] == 'i' and _num(g['_id']):
                out.append(int(g['_id']))
        return out

    def add_quest(qid, t, key, inst_maps):
        old = quests.get(qid)
        races = t['races']
        fac = races if races in ('A', 'H') else ''
        giver_id = t['qg'] if _num(t['qg']) else None
        pts = points_of(t)
        start = ''
        if pts:
            start = 'I' if all(p[0] in inst_maps for p in pts) else 'O'
        elif giver_id is None and (t['qs'] is not None or t['qi'] is not None):
            start = 'X'
        rec = {'name': names.get(qid), 'minLevel': int(t['lvl']) if _num(t['lvl']) else 0, 'level': 0,
               'faction': fac, 'classes': 0, 'start': start,
               'giver': givers.get(giver_id) if giver_id else None, 'points': pts,
               'preAll': ids_of(t['sourceQuests']) + ids_of(t['sourceQuest']),
               'preOne': ids_of(t['altQuests']), 'dungeon': key, 'rewards': rewards_of(t)}
        if old:
            # a quest listed twice: what the first left open
            for k, v in rec.items():
                if not old.get(k) and v:
                    old[k] = v
        else:
            quests[qid] = rec
        if key:
            quests[qid]['dungeon'] = quests[qid]['dungeon'] or key
            lst = dungeons.setdefault(key, [])
            if qid not in lst:
                lst.append(qid)

    def walk(v, key, inst_maps, depth=0):
        if depth > 60 or not plain(v):
            return
        kind = v['_kind']
        if kind is not None:
            t = v['_t']
            if kind == 'q' and _num(v['_id']):
                add_quest(int(v['_id']), t, key, inst_maps)
            walk(t['groups'], key, inst_maps, depth + 1)
            for x in _seq(t):
                walk(x, key, inst_maps, depth + 1)
            return
        for x in _seq(v):
            walk(x, key, inst_maps, depth + 1)
        if v['groups'] is not None:
            walk(v['groups'], key, inst_maps, depth + 1)

    for path in att_files(base):
        with open(path, encoding='utf-8') as fh:
            src = fh.read()
        for m in _Q_NAME.finditer(src):
            names.setdefault(int(m.group(1)), clean_name(m.group(2)))
        for m in _GIVER.finditer(src):
            givers.setdefault(int(m.group(1)), clean_name(m.group(2)))
        rel = os.path.relpath(path, base)
        roots = S.run(src, rel)
        report['files'] += 1
        stem = os.path.splitext(os.path.basename(path))[0]
        for r in _seq(roots):
            for top in _seq(r):
                if plain(top) and top['_kind'] == 'inst':
                    t = top['_t']
                    area = int(t['zone-text-areaID']) if _num(t['zone-text-areaID']) else None
                    key = fact_key_of(facts, stem, area) if rel.startswith('dungeons') else None
                    if rel.startswith('dungeons') and not key:
                        report['instances without facts'].append(stem)
                    maps = set(ids_of(t['mapID'])) | set(ids_of(t['maps']))
                    walk(t['groups'], key, maps)
                else:
                    walk(top, None, set())
    for qid, q in quests.items():
        if not q['name']:
            q['name'] = f'Quest {qid}'
    report['quests'] = len(quests)
    return {'source': ATT_SOURCE, 'commit': commit, 'dungeons': dungeons, 'quests': quests}, report


def refresh_att(dest=ATT_CACHE, ref='master'):
    """Downloads AllTheThings' .contrib/.db/forever folder through the GitHub API into dest; returns
    the commit. Uses the token of `gh` when there is one (the API allows few calls without)."""
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    if not token:
        try:
            token = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True, timeout=20).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            token = None

    def get(url, raw=False):
        headers = {'User-Agent': USER_AGENT}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if raw:
            headers['Accept'] = 'application/vnd.github.raw'
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
            return r.read()

    api = f'https://api.github.com/repos/{ATT_REPO}'
    commit = json.loads(get(f'{api}/commits/{ref}'))['sha']
    sha = json.loads(get(f'{api}/git/commits/{commit}'))['tree']['sha']
    for part in ATT_PATH.split('/'):
        listing = json.loads(get(f'{api}/git/trees/{sha}'))
        sha = next(t['sha'] for t in listing['tree'] if t['path'] == part)
    listing = json.loads(get(f'{api}/git/trees/{sha}?recursive=1'))
    if listing.get('truncated'):
        raise SystemExit('the folder listing is truncated')
    n = 0
    for t in listing['tree']:
        if t['type'] != 'blob' or not t['path'].endswith('.lua'):
            continue
        keep = t['path'].startswith(('dungeons & raids/', 'zones/')) or t['path'] == '.config/constants/maps.lua'
        if not keep:
            continue
        out = os.path.join(dest, t['path'])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'wb') as fh:
            fh.write(get(f'{api}/git/blobs/{t["sha"]}', raw=True))
        n += 1
    with open(os.path.join(dest, 'COMMIT'), 'w', encoding='utf-8') as fh:
        fh.write(commit + '\n')
    log(f'AllTheThings {commit[:10]}: {n} files -> {dest}')
    return commit


def read_json(path):
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    data['quests'] = {int(k): v for k, v in data.get('quests', {}).items()}
    for v in data['quests'].values():
        v['points'] = [tuple(p) for p in v.get('points') or []]
    return data


def empty():
    return {'source': 'none yet', 'commit': None, 'dungeons': {}, 'quests': {}}


# ---------------------------------------------------------------- output
def complete(data):
    """Drops pre-quests the data has no record of and sorts the lists (the addon walks what it gets)."""
    Q = data['quests']
    for q in Q.values():
        for k in ('preAll', 'preOne'):
            q[k] = sorted({p for p in q.get(k) or [] if p in Q and p != None})  # noqa: E711
    for key in data['dungeons']:
        data['dungeons'][key] = sorted(set(data['dungeons'][key]))
    return data


def ancestors(Q, qid):
    """Every pre-quest of a quest once, nearest first; a loop ends."""
    out, seen, todo = [], {qid}, [qid]
    while todo:
        q = Q.get(todo.pop(0))
        if not q:
            continue
        for p in (q.get('preAll') or []) + (q.get('preOne') or []):
            if p not in seen:
                seen.add(p)
                out.append(p)
                todo.append(p)
    return out


def _lua_list(v):
    return 'nil' if not v else '{ ' + ', '.join(str(int(x)) for x in v) + ' }'


def render(data, built):
    lua_str, lua_val = build_gear.lua_str, build_gear.lua_val
    data = complete(copy.deepcopy(data))
    # only the dungeon quests and their pre-quests go in
    keep = set()
    for ids in data['dungeons'].values():
        for qid in ids:
            keep.add(qid)
            keep.update(ancestors(data['quests'], qid))
    commit = (data.get('commit') or '')[:10]
    lines = [
        '-- GENERATED by tools/build_dungeonquests.py. Do not edit; rebuild instead.',
        f'-- Source: {data["source"]}' + (f' at {commit}.' if commit else '.'),
        'local _, ns = ...',
        '',
        '-- D: [dungeon key of DungeonData.lua] = its quests.',
        '-- Q: [quest id] = { name (English), required level, quest level (0 unknown), faction ("A", "H", "" both),',
        '-- class mask (0 all), start ("O" outside, "I" inside the dungeon, "X" by an item, "" unknown), giver,',
        '-- points (up to four "uiMapID:x:y", x and y in hundredths of a percent), pre-quests all of, pre-quests',
        '-- one of, dungeon key (nil for a pre-quest only), gear rewards }.',
        'ns.DUNGEON_QUESTS = {',
        f'    built = {lua_str(built)}, source = {lua_str(commit or data["source"][:20])},',
        '    D = {',
    ]
    for key in sorted(data['dungeons']):
        k = key if key.isidentifier() else f'[{lua_str(key)}]'
        lines.append(f'        {k} = {_lua_list(data["dungeons"][key])},')
    lines += ['    },', '    Q = {']
    for qid in sorted(keep):
        q = data['quests'].get(qid)
        if not q:
            continue
        pts = ' '.join(f'{m}:{x}:{y}' for m, x, y in (q.get('points') or [])[:MAX_POINTS]) or None
        parts = [lua_str(q.get('name') or f'Quest {qid}'), str(int(q.get('minLevel') or 0)), str(int(q.get('level') or 0)),
                 lua_str(q.get('faction') or ''), str(int(q.get('classes') or 0)), lua_str(q.get('start') or ''),
                 lua_val(q.get('giver')), lua_val(pts), _lua_list(q.get('preAll')), _lua_list(q.get('preOne')),
                 lua_val(q.get('dungeon')), _lua_list(q.get('rewards'))]
        lines.append(f'        [{qid}] = {{ {", ".join(parts)} }},')
    lines += ['    },', '}', '']
    text = '\n'.join(lines)
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    return text


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=None, help=f'AllTheThings download (default {ATT_CACHE} when it exists)')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever folder first')
    ap.add_argument('--json', default=None, help='the neutral form as JSON')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    facts = load_facts()
    report = {}
    if args.json:
        data = read_json(args.json)
    elif args.empty:
        data = empty()
    else:
        base = args.att or ATT_CACHE
        commit = None
        if args.refresh_att:
            commit = refresh_att(base)
        elif os.path.exists(os.path.join(base, 'COMMIT')):
            with open(os.path.join(base, 'COMMIT'), encoding='utf-8') as fh:
                commit = fh.read().strip() or None
        if not os.path.isdir(os.path.join(base, 'dungeons & raids')):
            raise SystemExit(f'no AllTheThings download in {base}: run with --refresh-att (or --empty)')
        data, report = read_att(base, facts, commit)
    text = render(data, time.strftime('%Y-%m-%d'))
    old = None
    if os.path.exists(args.out):
        with open(args.out, encoding='utf-8') as fh:
            old = fh.read()
    if old is not None and re.sub(r'built = "[^"]*"', '', old) == re.sub(r'built = "[^"]*"', '', text):
        log(f'{os.path.relpath(args.out, ROOT)} is current')
    else:
        with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        log(f'wrote {os.path.relpath(args.out, ROOT)} ({os.path.getsize(args.out) // 1024} KB)')
    for key in sorted(data['dungeons']):
        log(f'  {key}: {len(data["dungeons"][key])} quests')
    missing = [e['key'] for e in facts if e['key'] not in data['dungeons']]
    if missing:
        log(f'  without quests (data missing): {", ".join(missing)}')
    if report.get('instances without facts'):
        log(f'  instances without facts: {report["instances without facts"]}')


if __name__ == '__main__':
    main()
