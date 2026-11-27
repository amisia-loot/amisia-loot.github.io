"""QuestieDB's WoW Forever data, read into one neutral form for tools/build_gear.py (D-157).

Source: the folder data/Forever of https://github.com/Questie/questiedb (branch master). Its LICENSE.md:
contributions since 2026-10-21 are GPL-3.0; older content imported from Questie has no clear licence ("when in
doubt all rights reserved"). Amisia is GPL-3.0 since 2026-11-20 (D-157) and names the source in
Amisia/LICENSES/THIRD-PARTY.md.

refresh() (`python3 tools/build.py questie`) downloads through the GitHub API, one request after the other,
only data/Forever/*.lua and the repository's LICENSE.md and PROVENANCE.md into ~/addons/_cache/questiedb (or
$AMISIA_QUESTIE_CACHE), outside the repo. `build.py data` never downloads: load() reads the cache, and a missing
cache means no QuestieDB sources (a printed note).

The files are Lua: each sets one table of the global QuestieDB (or returns it) as a string "return {...}" or as
a table, keyed by id, with numbered fields whose meaning the file's own key list gives. load() runs them in a
sandbox (lupa without its python bridge, an empty environment, no string methods, an instruction budget, a
precompiled chunk refused) and keeps for every item: the NPCs that drop it, the objects that hold it, the
vendors that sell it, the quests that give it; and the names, zones and levels of those NPCs, objects and quests.
"""
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
QUESTIE_CACHE = os.path.expanduser(os.environ.get('AMISIA_QUESTIE_CACHE') or '~/addons/_cache/questiedb')
QUESTIE_REPO = 'Questie/questiedb'
QUESTIE_PATH = 'data/Forever'
QUESTIE_LICENSE = 'GPL-3.0 (contributions since 2026-10-21; older imported content of unclear licence)'
QUESTIE_SOURCE = f'QuestieDB Forever data (github.com/{QUESTIE_REPO}, {QUESTIE_LICENSE}; see LICENSES/THIRD-PARTY.md)'
USER_AGENT = 'Amisia-build-tool/1.0 (tools/questie_data.py; +https://amisia-loot.github.io)'
KEEP_FILES = ('LICENSE.md', 'PROVENANCE.md')
PAUSE = 1.0   # seconds between two requests


def log(*a):
    print(*a, file=sys.stderr)


def kept(path):
    """Whether refresh() downloads a file of the repository."""
    if path in KEEP_FILES:
        return True
    return path.startswith(QUESTIE_PATH + '/') and path.endswith('.lua') and path.count('/') == 2


def _token():
    import att_data
    return att_data._token()


def refresh(dest=QUESTIE_CACHE, ref='master'):
    """Downloads the files kept() names through the GitHub API into dest, one request at a time; files of an
    older download that the repository no longer has are removed. Returns the commit."""
    token = _token()

    def get(url, raw=False):
        headers = {'User-Agent': USER_AGENT}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if raw:
            headers['Accept'] = 'application/vnd.github.raw'
        time.sleep(PAUSE)
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
            return r.read()

    api = f'https://api.github.com/repos/{QUESTIE_REPO}'
    commit = json.loads(get(f'{api}/commits/{ref}'))['sha']
    tree = json.loads(get(f'{api}/' + f'git/commits/{commit}'))['tree']['sha']
    listing = json.loads(get(f'{api}/' + f'git/trees/{tree}?recursive=1'))
    if listing.get('truncated'):
        raise SystemExit('the repository listing is truncated')
    wanted = {t['path']: t['sha'] for t in listing['tree'] if t['type'] == 'blob' and kept(t['path'])}
    if not any(p.startswith(QUESTIE_PATH) for p in wanted):
        raise SystemExit(f'{QUESTIE_REPO}@{commit[:10]} has no {QUESTIE_PATH}/*.lua')
    for path, blob in sorted(wanted.items()):
        out = os.path.join(dest, path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'wb') as fh:
            fh.write(get(f'{api}/' + f'git/blobs/{blob}', raw=True))
    removed = 0
    for d, _dirs, files in os.walk(dest):
        for f in files:
            rel = os.path.relpath(os.path.join(d, f), dest).replace(os.sep, '/')
            if rel != 'COMMIT' and rel not in wanted:
                os.remove(os.path.join(d, f))
                removed += 1
    with open(os.path.join(dest, 'COMMIT'), 'w', encoding='utf-8') as fh:
        fh.write(commit + '\n')
    log(f'QuestieDB {commit[:10]}: {len(wanted)} files -> {dest}' + (f' ({removed} old files removed)' if removed else ''))
    return commit


def commit_of(base):
    p = os.path.join(base, 'COMMIT')
    if os.path.exists(p):
        with open(p, encoding='utf-8') as fh:
            return fh.read().strip() or None
    return None


# ---------------------------------------------------------------- reading
# A data file is Lua from another repository: it runs in a sandbox as the SavedVariables do
# (tools/build_scan.py SV_SANDBOX): lupa without its python bridge, an empty environment of its own that
# offers only QuestieLoader:ImportModule (it hands out the one table the file fills), the dangerous globals
# gone, string methods out of reach, an instruction budget, and a precompiled chunk (it starts with ESC:
# Lua 5.1 bytecode can break out of a sandbox) refused, the file and every data string it holds.
SANDBOX = r'''
local loadstring, setfenv, pcall, tostring, error, type, pairs = loadstring, setfenv, pcall, tostring, error, type, pairs
local byte = string.byte
local sethook = debug.sethook
local strmeta = getmetatable("")
for _, k in ipairs({ "os", "io", "require", "package", "debug", "dofile", "loadfile", "load", "loadstring",
                     "setfenv", "getfenv", "python", "collectgarbage", "module", "newproxy", "string" }) do
    _G[k] = nil
end
local function chunk(src, name)
    if byte(src, 1) == 27 then return nil, "binary chunk refused" end
    local f, err = loadstring(src, "@" .. name)
    if not f then return nil, tostring(err) end
    return f
end
return function(src, name, budget)
    local f, err = chunk(src, name)
    if not f then return nil, err end
    local DB = {}
    local loader = {}
    function loader.ImportModule(_, _) return DB end
    setfenv(f, { QuestieLoader = loader })
    local index = strmeta.__index
    strmeta.__index = nil
    sethook(function() error("the file runs too long", 0) end, "", budget)
    local ok, e = pcall(function()
        f()
        -- the data tables stand as a string "return {...}" (or as the table itself)
        for k, v in pairs(DB) do
            if type(v) == "string" then
                local g, gerr = chunk(v, name .. ":" .. k)
                if not g then error(gerr, 0) end
                setfenv(g, {})
                DB[k] = g()
            end
        end
    end)
    sethook()
    strmeta.__index = index
    if not ok then return nil, tostring(e) end
    return DB
end
'''
BUDGET = 400000000   # Lua instructions; the four files of 2026-11 need a small part of it
MAX_BYTES = 32 * 1024 * 1024   # a real file is about 2 MB; a bigger one is refused before it runs
FILES = {'item': 'foreverItemDB.lua', 'npc': 'foreverNpcDB.lua', 'object': 'foreverObjectDB.lua',
         'quest': 'foreverQuestDB.lua'}
GEAR_CLASSES = (2, 4)   # the item classes kept: weapons and armour
ALLIANCE_RACES = 1 | 4 | 8 | 64     # human, dwarf, night elf, gnome
HORDE_RACES = 2 | 16 | 32 | 128     # orc, undead, tauren, troll


def run(text, name, budget=BUDGET):
    """Runs one data file in the sandbox. Returns (the QuestieDB table it filled, None) or (None, the error)."""
    if text.startswith('\x1b'):
        return None, 'binary chunk refused'
    if len(text) > MAX_BYTES:
        return None, f'the file is larger than {MAX_BYTES // (1024 * 1024)} MB'
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    res = lua.execute(SANDBOX)(text, name, budget)
    return res if isinstance(res, tuple) else (res, None)


def _rows(db, kind):
    """(the field index of each key name, the data table) of one kind ("item", "npc", ...)."""
    keys, data = db[kind + 'Keys'], db[kind + 'Data']
    if keys is None or data is None:
        raise ValueError(f'no QuestieDB.{kind}Keys / {kind}Data')
    return {str(k): int(v) for k, v in keys.items()}, data


def _ids(v):
    """A Lua list of ids as sorted Python ints (anything else: [])."""
    if v is None or not hasattr(v, 'values'):
        return []
    return sorted({int(x) for x in v.values() if isinstance(x, (int, float)) and not isinstance(x, bool) and x > 0})


def _int(v):
    return int(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else 0


def _str(v):
    return v if isinstance(v, str) else None


def _faction(text):
    """friendlyToFaction ("A", "H", "AH" or nil) as the faction a vendor serves: A, H or None (both, or none)."""
    text = text or ''
    if text in ('A', 'H'):
        return text
    return None


def race_faction(mask):
    """A quest's requiredRaces as its faction: A or H when it names only one side's races, else None."""
    mask = _int(mask)
    a, h = mask & ALLIANCE_RACES, mask & HORDE_RACES
    if a and not h:
        return 'A'
    if h and not a:
        return 'H'
    return None


def empty_db():
    return {'commit': None, 'items': {}, 'npcs': {}, 'objects': {}, 'quests': {}}


def load(base=QUESTIE_CACHE):
    """QuestieDB's Forever data in a neutral form, or None when the cache has no data (a note is printed):

    {'commit': sha or None,
     'items':   {item id: {'name', 'npcs': [npc ids that drop it], 'objects': [object ids that hold it],
                           'vendors': [npc ids that sell it], 'quests': [quest ids that give it]}}  (weapons and
                armour with at least one source only),
     'npcs':    {npc id: {'name', 'min', 'max' (levels), 'rank' (0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare),
                          'zone' (AreaTable id of its main zone, 0 unknown), 'title', 'friendly' (A, H or None)}},
     'objects': {object id: {'name', 'zone'}},
     'quests':  {quest id: {'name', 'level', 'min', 'faction' (A, H or None), 'classes', 'zone' (AreaTable id
                            when > 0)}}}

    Only the NPCs, objects and quests an item names are kept. A file that fails to run stops with its error."""
    folder = os.path.join(base, *QUESTIE_PATH.split('/'))
    paths = {k: os.path.join(folder, f) for k, f in FILES.items()}
    if not os.path.exists(paths['item']):
        log(f'QuestieDB: no download in {base} (python3 tools/build.py questie); no QuestieDB sources')
        return None
    dbs = {}
    for kind, path in paths.items():
        if not os.path.exists(path):
            dbs[kind] = None
            continue
        with open(path, encoding='utf-8', errors='replace') as fh:
            db, err = run(fh.read(), os.path.basename(path))
        if db is None:
            raise SystemExit(f'{path}: {err}')
        dbs[kind] = db
    out = empty_db()
    out['commit'] = commit_of(base)
    keys, data = _rows(dbs['item'], 'item')
    k = {n: keys.get(n) for n in ('name', 'npcDrops', 'objectDrops', 'vendors', 'questRewards', 'class')}
    for iid, rec in data.items():
        if not isinstance(iid, int) or rec is None or not hasattr(rec, 'keys'):
            continue
        if k['class'] and _int(rec[k['class']]) not in GEAR_CLASSES:
            continue
        it = {'name': _str(rec[k['name']]) if k['name'] else None,
              'npcs': _ids(rec[k['npcDrops']]) if k['npcDrops'] else [],
              'objects': _ids(rec[k['objectDrops']]) if k['objectDrops'] else [],
              'vendors': _ids(rec[k['vendors']]) if k['vendors'] else [],
              'quests': _ids(rec[k['questRewards']]) if k['questRewards'] else []}
        if it['npcs'] or it['objects'] or it['vendors'] or it['quests']:
            out['items'][iid] = it
    want_npcs = {n for it in out['items'].values() for n in it['npcs'] + it['vendors']}
    want_objs = {o for it in out['items'].values() for o in it['objects']}
    want_quests = {q for it in out['items'].values() for q in it['quests']}
    if dbs['npc'] is not None:
        keys, data = _rows(dbs['npc'], 'npc')
        for nid in sorted(want_npcs):
            rec = data[nid]
            if rec is None:
                continue
            g = lambda n: rec[keys[n]] if n in keys else None   # noqa: E731
            out['npcs'][nid] = {'name': _str(g('name')), 'min': _int(g('minLevel')), 'max': _int(g('maxLevel')),
                                'rank': _int(g('rank')), 'zone': _int(g('zoneID')), 'title': _str(g('subName')),
                                'friendly': _faction(_str(g('friendlyToFaction')))}
    if dbs['object'] is not None:
        keys, data = _rows(dbs['object'], 'object')
        for oid in sorted(want_objs):
            rec = data[oid]
            if rec is None:
                continue
            out['objects'][oid] = {'name': _str(rec[keys['name']]), 'zone': _int(rec[keys['zoneID']]) if 'zoneID' in keys else 0}
    if dbs['quest'] is not None:
        keys, data = _rows(dbs['quest'], 'quest')
        for qid in sorted(want_quests):
            rec = data[qid]
            if rec is None:
                continue
            g = lambda n: rec[keys[n]] if n in keys else None   # noqa: E731
            zone = _int(g('zoneOrSort'))
            out['quests'][qid] = {'name': _str(g('name')), 'level': max(0, _int(g('questLevel'))),
                                  'min': max(0, _int(g('requiredLevel'))), 'faction': race_faction(g('requiredRaces')),
                                  'classes': _int(g('requiredClasses')), 'zone': zone if zone > 0 else 0}
    log(f'QuestieDB {(out["commit"] or "?")[:10]}: {len(out["items"])} weapons and armour with a source, '
        f'{len(out["npcs"])} NPCs, {len(out["objects"])} objects, {len(out["quests"])} quests')
    return out


ITEM_LINE = re.compile(r"^\[(\d+)\]\s*=\s*\{'((?:[^'\\]|\\.)*)'(.*)\},?\s*$", re.M)


def item_names(base=QUESTIE_CACHE):
    """{item id: (English name, item level)} of the weapons and armour in QuestieDB's item file, read as text line by
    line (nothing runs; the gear sets of tools/wowsims_weights.py name their items, F-239); {} without a download."""
    path = os.path.join(base, *QUESTIE_PATH.split('/'), FILES['item'])
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8', errors='replace') as fh:
        text = fh.read()
    out = {}
    for m in ITEM_LINE.finditer(text):
        fields, depth, cur = [], 0, ''
        for ch in m.group(3).lstrip(','):
            if ch == ',' and depth == 0:
                fields.append(cur.strip())
                cur = ''
                continue
            depth += (ch == '{') - (ch == '}')
            cur += ch
        fields.append(cur.strip())
        # fields after the name: itemLevel is the 8th (QuestieDB.itemKeys 9), class the 11th (12)
        if len(fields) < 11 or not fields[10].isdigit() or int(fields[10]) not in GEAR_CLASSES:
            continue
        ilvl = int(fields[7]) if fields[7].isdigit() else 0
        out[int(m.group(1))] = (m.group(2).replace("\\'", "'"), ilvl)
    return out


def area_zones(*dirs):
    """{AreaTable id: uiMapID} from the client tables: an area's own map (UiMapAssignment, the first
    assignment), else its parent area's, up the chain. QuestieDB names zones by area, the gear data by uiMapID."""
    import att_data
    ui = {}
    for row in att_data.wago_rows('UiMapAssignment', *dirs):
        try:
            aid, um, order = int(row['AreaID']), int(row['UiMapID']), int(row.get('OrderIndex') or 0)
        except (KeyError, ValueError):
            continue
        if aid and order == 0:
            ui.setdefault(aid, um)
    parent = {}
    for row in att_data.wago_rows('AreaTable', *dirs):
        try:
            parent.setdefault(int(row['ID']), int(row.get('ParentAreaID') or 0))
        except (KeyError, ValueError):
            continue
    out = {}
    for aid in parent:
        a, seen = aid, set()
        while a and a not in ui and a not in seen:
            seen.add(a)
            a = parent.get(a, 0)
        if a in ui:
            out[aid] = ui[a]
    for aid, um in ui.items():
        out.setdefault(aid, um)
    return out


# QuestieDB's own zone ids that the client's AreaTable lacks (its Blackrock Depths)
ZONE_NAMES = {1585: 'Blackrock Depths'}


def area_names(*dirs):
    """{AreaTable id: name} of the top areas (no parent) of the client tables, with QuestieDB's own ids
    (ZONE_NAMES); build_gear places an area without a map of its own by this name when it is a dungeon's."""
    import att_data
    out = {}
    for row in att_data.wago_rows('AreaTable', *dirs):
        try:
            aid, parent = int(row['ID']), int(row.get('ParentAreaID') or 0)
        except (KeyError, ValueError):
            continue
        if not parent and row.get('AreaName_lang'):
            out.setdefault(aid, row['AreaName_lang'])
    for aid, name in ZONE_NAMES.items():
        out.setdefault(aid, name)
    return out


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description='Download QuestieDB\'s WoW Forever data into the cache (D-157).')
    ap.add_argument('--dest', default=QUESTIE_CACHE)
    ap.add_argument('--ref', default='master')
    args = ap.parse_args(argv)
    refresh(args.dest, args.ref)


if __name__ == '__main__':
    main()
