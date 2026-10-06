"""AllTheThings' hand-kept WoW Forever data, read into one neutral form for the build scripts
(build_gear.py, build_map.py, build_dungeonquests.py). Runs without a WoW install (on the N100).

Source: the folder .contrib/.db/forever of https://github.com/ATTWoWAddon/AllTheThings, MIT licence
(Copyright (c) 2026 AllTheThings WoW Addon); the licence text ships in addon/Amisia/LICENSES/.
refresh() downloads the files the builds read through the GitHub API (the repository is far too
large to clone) into ~/addons/_cache/att, outside the repo:

  - dungeons & raids/, zones/: the Forever dungeons and zones (quests with giver, coordinates,
    faction, level, pre-quests and rewards; bosses and their loot; rares, vendors, zone drops);
  - zzOLD/01 - Dungeons Raids/, zzOLD/02 - Outdoor Zones/: the Classic dungeons and zones the
    authors have not yet moved into the Forever folders. They are read after the Forever files;
    a quest or NPC both know keeps the Forever record. Their facts are Classic's;
  - world drops/, pvp/, crafted items/: world drops, PvP rank gear, crafted items per profession;
  - .config/constants/: the map constants (MAP.X -> uiMapID);
  - .config/exports/ItemDB.lua: the Forever client's item table as ATT exports it (slot, class,
    subclass, item level, quality, bind, required level, classes, required skill line);
  - .config/.wago/UiMapAssignment.*.csv: uiMapID -> instance map id (the client table ATT ships);
  - .config/.wago/AreaTable.*.csv: area id -> the map (ContinentID) it lies on, which for an
    instance's own area is the instance map id; ContentTuning.*.csv: the level the client tunes a
    dungeon to (build_dungeons.py, with the LFGDungeons table of the user's wago.tools download).

Client tables are read as <Table>.csv or <Table>.<build>.csv (wago.tools names its downloads so);
of several builds in one folder the newest counts (wago_csv()).

The files are a Lua builder language (root, maproot, inst, q, n, e, i, objective, ...). load()
runs them under lupa with stand-ins that only record what they are given; names come from the
files' comments. No other quest database is read.
"""
import csv
import glob
import json
import os
import re
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ATT_CACHE = os.path.expanduser('~/addons/_cache/att')
ATT_REPO = 'ATTWoWAddon/AllTheThings'
ATT_PATH = '.contrib/.db/forever'
ATT_LICENSE = 'MIT, Copyright (c) 2026 AllTheThings WoW Addon'
ATT_SOURCE = f'AllTheThings Forever data ({ATT_LICENSE}; see LICENSES/)'
USER_AGENT = 'AmisiaGuildTool/1.0 (+https://amisia-loot.github.io)'

# What refresh() keeps of the folder (paths relative to it).
KEEP_DIRS = ('dungeons & raids/', 'zones/', 'world drops/', 'pvp/', 'crafted items/',
             'zzOLD/01 - Dungeons Raids/', 'zzOLD/02 - Outdoor Zones/', '.config/constants/')
KEEP_FILES = ('.config/exports/ItemDB.lua',)
KEEP_WAGO = ('UiMapAssignment', 'AreaTable', 'ContentTuning')
# The data folders load() reads, in this order; a later folder never overwrites an earlier record.
DATA_DIRS = ('dungeons & raids', 'zones', 'world drops', 'pvp', 'crafted items',
             os.path.join('zzOLD', '01 - Dungeons Raids'), os.path.join('zzOLD', '02 - Outdoor Zones'))


def log(*a):
    print(*a, file=sys.stderr)


def kept(path):
    """Whether refresh() downloads a file of the folder."""
    if path in KEEP_FILES:
        return True
    if path.startswith('.config/.wago/') and path.endswith('.csv'):
        return os.path.basename(path).split('.')[0] in KEEP_WAGO
    return path.endswith('.lua') and path.startswith(KEEP_DIRS)


def _token():
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    if token:
        return token
    try:
        return subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True, timeout=20).stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def refresh(dest=ATT_CACHE, ref='master'):
    """Downloads the files the builds read (see kept()) through the GitHub API into dest; files of
    an older download that the folder no longer has are removed. Returns the commit. Uses the token
    of `gh` when there is one (the API allows few calls without)."""
    token = _token()

    def get(url, raw=False):
        headers = {'User-Agent': USER_AGENT}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if raw:
            headers['Accept'] = 'application/vnd.github.raw'
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
            return r.read()

    api = f'https://api.github.com/repos/{ATT_REPO}'
    trees = api + '/' + 'git/trees/'
    commit = json.loads(get(f'{api}/commits/{ref}'))['sha']
    sha = json.loads(get(f'{api}/' + f'git/commits/{commit}'))['tree']['sha']
    for part in ATT_PATH.split('/'):
        listing = json.loads(get(trees + sha))
        sha = next(t['sha'] for t in listing['tree'] if t['path'] == part)
    listing = json.loads(get(trees + sha + '?recursive=1'))
    if listing.get('truncated'):
        raise SystemExit('the folder listing is truncated')
    wanted = {t['path']: t['sha'] for t in listing['tree'] if t['type'] == 'blob' and kept(t['path'])}
    for path, blob in sorted(wanted.items()):
        out = os.path.join(dest, path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'wb') as fh:
            fh.write(get(f'{api}/' + f'git/blobs/{blob}', raw=True))
    removed = 0
    for path in sorted(glob.glob(os.path.join(dest, '**', '*'), recursive=True)):
        rel = os.path.relpath(path, dest).replace(os.sep, '/')
        if os.path.isfile(path) and rel != 'COMMIT' and rel not in wanted:
            os.remove(path)
            removed += 1
    with open(os.path.join(dest, 'COMMIT'), 'w', encoding='utf-8') as fh:
        fh.write(commit + '\n')
    log(f'AllTheThings {commit[:10]}: {len(wanted)} files -> {dest}' + (f' ({removed} old files removed)' if removed else ''))
    return commit


def commit_of(base):
    p = os.path.join(base, 'COMMIT')
    if os.path.exists(p):
        with open(p, encoding='utf-8') as fh:
            return fh.read().strip() or None
    return None


def data_files(base):
    """The data files of a download, folder by folder in DATA_DIRS order, sorted within."""
    out = []
    for sub in DATA_DIRS:
        d = os.path.join(base, sub)
        found = []
        for root, _, files in os.walk(d):
            found += [os.path.join(root, f) for f in files if f.endswith('.lua') and not f.startswith('.')]
        out += sorted(found)
    return out


# ---------------------------------------------------------------- reading the builder language
# The downloaded files are third-party code. They run in a sandbox: lupa without its python bridge
# (register_eval/register_builtins off), an environment that holds only SAFE, and the dangerous
# globals removed from the runtime before any file runs.
#
# Stand-ins for the builder language: every other name the data uses is a "named proxy" that can
# be indexed (giving another named proxy), called (passing its last table argument on, so unknown
# wrappers keep their children) and used in arithmetic. Headers such as n(QUESTS, ...) keep their
# name that way, TIMELINE.ADDED_1_60_1 too.
STUB = r'''
local loadstring, setfenv, assert, pcall, tostring = loadstring, setfenv, assert, pcall, tostring
local NAMED, BY_NAME = {}, {}
local proxyMeta = {}
local proxy = setmetatable({}, proxyMeta)
local function named(k)
    local p = BY_NAME[k]
    if p then return p end
    p = setmetatable({}, proxyMeta)
    NAMED[p], BY_NAME[k] = k, p
    return p
end
local function plain(v) return type(v) == "table" and getmetatable(v) ~= proxyMeta end
proxyMeta.__index = function(_, k) if type(k) == "string" then return named(k) end return proxy end
proxyMeta.__call = function(_, ...)
    local last
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if plain(v) then last = v end
    end
    return last or proxy
end
for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__concat", "__pow" }) do
    proxyMeta[m] = function() return proxy end
end

-- the data files see only these, never io, os, load or python
local _pairs, _ipairs = pairs, ipairs
local function none() return nil end
local SAFE = { pairs = function(t) if type(t) ~= "table" then return none end return _pairs(t) end,
    ipairs = function(t) if type(t) ~= "table" then return none end return _ipairs(t) end, type = type, tostring = tostring, tonumber = tonumber,
    select = select, next = next, unpack = unpack, rawget = rawget, rawset = rawset,
    setmetatable = setmetatable, getmetatable = getmetatable, string = string, table = table, math = math,
    tinsert = table.insert, print = function() end }
local env = setmetatable({}, { __index = function(_, k)
    local v = SAFE[k]
    if v ~= nil then return v end
    return named(k)
end })

local rec = {}
local function node(kind, id, t)
    if t == nil and plain(id) and id._kind == nil then t, id = id, nil end
    if not plain(t) then t = {} end
    return { _kind = kind, _id = id, _t = t }
end
local function tagged(kind) return function(id, t) return node(kind, id, t) end end
for _, k in ipairs({ "inst", "q", "e", "i", "n", "o", "objective", "m", "cl", "prof", "r", "filter", "d", "fp",
                     "ach", "exploration", "visit_exploration", "recipe", "spell", "faction", "title", "mount" }) do
    env[k] = tagged(k)
end
env.header = function(_, id, t) return node("header", id, t) end
env.ALLIANCE_ONLY, env.HORDE_ONLY = "A", "H"
env.root = function(r, t) rec[#rec + 1] = { root = NAMED[r] or "?", t = t } end
env.maproot = function(_, map, t) rec[#rec + 1] = { root = "Zones", t = node("m", map, t) } end
-- Season of Discovery phases are not Forever's
env.applyclassicphase = function(phase, t)
    local name = NAMED[phase]
    if plain(t) and name and name:match("^SOD") then t._skip = true end
    return t
end
env.lvlsquish = function(a) return a end
env.bubbleDown = function(_, t) return t end
env.bubbleDownSelf = function(_, t) return t end
env.sharedData = function(_, t) return t end

local MAPS = {}
local RACE = { HUMAN = 1, ORC = 2, DWARF = 3, NIGHTELF = 4, UNDEAD = 5, SCOURGE = 5, TAUREN = 6, GNOME = 7, TROLL = 8 }
local ALLIANCE = { [1] = true, [3] = true, [4] = true, [7] = true }
local CLASS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

local S = {}
-- runs the map constants file; MAP for the data files (an unknown key gives nil, so its
-- coordinates fall away instead of failing the file)
function S.maps(src)
    local f = assert(loadstring(src, "@maps.lua"))
    local menv = setmetatable({ print = function() end }, { __index = SAFE })
    -- the file copies the constants into "_G": here that is its own environment
    menv._G = menv
    setfenv(f, menv)
    f()
    for k, v in pairs(menv.MAP or {}) do if type(v) == "number" then MAPS[k] = v end end
    env.MAP = setmetatable({}, { __index = function(_, k) return MAPS[k] end })
end
function S.mapNames()
    local out = {}
    for k, v in pairs(MAPS) do out[k] = v end
    return out
end
-- the item export (_.ItemDB = {...}): runs with an empty namespace and nothing else
function S.itemdb(src)
    local f = assert(loadstring(src, "@ItemDB.lua"))
    local ienv = { _ = {} }
    setfenv(f, ienv)
    f()
    return ienv._.ItemDB or {}
end

local function mapOf(v)
    if type(v) == "number" then return v end
    local name = NAMED[v]
    return name and MAPS[name] or nil
end
local function points(t)
    local out = {}
    local function add(c)
        if not plain(c) then return end
        local x, y, m = c[1], c[2], mapOf(c[3])
        if type(x) == "number" and type(y) == "number" and m then out[#out + 1] = { m, x, y } end
    end
    add(t.coord)
    if plain(t.coords) then for _, c in ipairs(t.coords) do add(c) end end
    return out
end
local function ids(v)
    local out = {}
    if type(v) == "number" then out[1] = v
    elseif plain(v) then for _, x in ipairs(v) do if type(x) == "number" then out[#out + 1] = x end end end
    return out
end
local function raceCode(v, inherited)
    if v == "A" or v == "H" then return v end
    if not plain(v) then return inherited end
    local a, h = false, false
    for _, r in ipairs(v) do
        local id = type(r) == "number" and r or RACE[NAMED[r] or ""]
        if id then if ALLIANCE[id] then a = true else h = true end end
    end
    if a and not h then return "A" elseif h and not a then return "H" end
    return ""
end
local function classMask(v)
    local mask = 0
    if plain(v) then
        for _, c in ipairs(v) do
            local id = type(c) == "number" and c or CLASS[NAMED[c] or ""]
            if id then mask = mask + 2 ^ (id - 1) end
        end
    end
    return mask
end
-- Whether a thing is not in Forever (patch 1.60.1) by its timeline (ADDED_4_0_3, REMOVED_1_15_3,
-- "added 1.60.1", ...). The 1.15 patches are the Era / Season of Discovery branch: something added
-- there only is not Forever's, something removed there still is. Otherwise the latest event up to
-- 1.60.1 decides; with none, a first event "added" later means not yet there.
local CUR = { 1, 60, 1 }
local function before(a, b)
    for i = 1, 3 do
        if (a[i] or 0) ~= (b[i] or 0) then return (a[i] or 0) < (b[i] or 0) end
    end
    return false
end
local function notInForever(t)
    local tl = t.timeline
    if not plain(tl) then return false end
    local events, sod = {}, false
    for _, v in ipairs(tl) do
        local s = (NAMED[v] or (type(v) == "string" and v) or ""):upper():gsub("[ .]", "_")
        local word, a, b, c = s:match("^(%u+)_(%d+)_(%d+)_(%d+)")
        if word then
            local ver = { tonumber(a), tonumber(b), tonumber(c) }
            local add = word == "ADDED" or word == "CREATED"
            if ver[1] == 1 and ver[2] == 15 then
                if add then sod = true end
            elseif add or word == "REMOVED" or word == "DELETED" then
                events[#events + 1] = { ver = ver, add = add }
            end
        end
    end
    if #events == 0 then return sod end
    local last, first
    for _, e in ipairs(events) do
        if not before(CUR, e.ver) and (not last or not before(e.ver, last.ver)) then last = e end
        if not first or before(e.ver, first.ver) then first = e end
    end
    if last then return not last.add end
    return first.add
end
local function headerName(id)
    if NAMED[id] then return NAMED[id] end
    if plain(id) and id._kind == nil then return id.readable or (plain(id.text) and id.text.en) or "?" end
    return nil
end

local OUT
local function emit(list, r) local l = OUT[list]; l[#l + 1] = r end

local function walk(v, ctx, depth)
    if depth > 80 or not plain(v) or v._skip then return end
    local kind = v._kind
    if kind == nil then
        for _, x in ipairs(v) do walk(x, ctx, depth + 1) end
        if plain(v.groups) then walk(v.groups, ctx, depth + 1) end
        return
    end
    local t, id = v._t, v._id
    if t._skip or kind == "objective" or notInForever(t) then return end
    local c = setmetatable({}, { __index = ctx })
    c.races = raceCode(t.races, ctx.races)
    if kind == "inst" then
        local maps = ids(t.mapID)
        for _, m in ipairs(ids(t.maps)) do maps[#maps + 1] = m end
        local area = t["zone-text-areaID"]
        emit("insts", { id = id, file = ctx.file, area = type(area) == "number" and area or nil, maps = maps,
                        pts = points(t) })
        c.inst, c.zone, c.hdr, c.npc, c.npcKind, c.quest = id, maps[1] or ctx.zone, nil, nil, nil, nil
        local set = {}
        for _, m in ipairs(maps) do set[m] = true end
        c.instMaps = set
    elseif kind == "m" then
        c.zone = mapOf(id) or ctx.zone
    elseif kind == "q" and type(id) == "number" then
        local givers, objs, startItem = ids(t.qg), {}, t.qs ~= nil or t.qi ~= nil or t.qis ~= nil
        for _, g in ipairs(ids(t.qgs)) do givers[#givers + 1] = g end
        local provs = plain(t.providers) and t.providers or { t.provider }
        for _, p in ipairs(provs) do
            if plain(p) and type(p[2]) == "number" then
                if p[1] == "n" then givers[#givers + 1] = p[2]
                elseif p[1] == "o" then objs[#objs + 1] = p[2]
                elseif p[1] == "i" then startItem = true end
            end
        end
        local pre = ids(t.sourceQuests)
        for _, p in ipairs(ids(t.sourceQuest)) do pre[#pre + 1] = p end
        local inside = true
        local pts = points(t)
        for _, p in ipairs(pts) do if not (ctx.instMaps and ctx.instMaps[p[1]]) then inside = false end end
        emit("quests", { id = id, file = ctx.file, zone = ctx.zone, inst = ctx.inst, givers = givers, objs = objs,
                         startItem = startItem, pts = pts, inside = #pts > 0 and inside, races = c.races,
                         classes = classMask(t.classes), lvl = type(t.lvl) == "number" and t.lvl or nil,
                         pre = pre, alt = ids(t.altQuests) })
        c.quest = id
    elseif kind == "n" or kind == "e" or kind == "header" then
        local npc
        if kind == "e" then npc = ids(t.creatureID)[1] or ids(t.crs)[1]
        elseif kind == "n" and type(id) == "number" and id > 0 then npc = id end
        if npc then
            local nk
            local desc = type(t.description) == "string" and t.description or ""
            if kind == "e" then nk = "boss"
            elseif ctx.hdr == "RARES" or desc:find("Rare Creature") then nk = "rare"
            elseif ctx.hdr == "VENDORS" then nk = "vendor"
            elseif ctx.inst and (ctx.hdr == nil or ctx.hdr == "COMMON_BOSS_DROPS") then nk = "boss"
            else nk = "npc" end
            emit("npcs", { id = npc, file = ctx.file, zone = ctx.zone, inst = ctx.inst, kind = nk, pts = points(t),
                           races = c.races, encounter = kind == "e" and id or nil })
            c.npc, c.npcKind, c.enc = npc, nk, kind == "e" and id or nil
        elseif kind == "e" then
            c.npc, c.npcKind, c.enc = nil, "boss", id
        else
            c.hdr = headerName(id) or ctx.hdr
        end
    elseif kind == "prof" then
        c.prof = NAMED[id] or ctx.prof
    elseif kind == "o" and type(id) == "number" then
        emit("objs", { id = id, file = ctx.file, zone = ctx.zone, pts = points(t) })
        c.obj = id
    elseif kind == "i" and type(id) == "number" then
        local crs = ids(t.crs)
        for _, x in ipairs(ids(t.cr)) do crs[#crs + 1] = x end
        emit("items", { id = id, file = ctx.file, root = ctx.root, zone = ctx.zone, inst = ctx.inst, hdr = ctx.hdr,
                        quest = ctx.quest, npc = ctx.npc, npcKind = ctx.npcKind, enc = ctx.enc, obj = ctx.obj, prof = ctx.prof,
                        races = c.races, crs = crs, pts = points(t) })
    end
    walk(t.groups, c, depth + 1)
    for _, x in ipairs(t) do walk(x, c, depth + 1) end
end

function S.new() return { insts = {}, quests = {}, npcs = {}, objs = {}, items = {} } end
-- runs one data file and walks what it handed to root(); the records go into out. Returns the
-- error text when the file failed (what it recorded before still counts)
function S.run(src, name, out)
    rec, OUT = {}, out
    local f, err = loadstring(src, "@" .. name)
    if not f then return tostring(err) end
    setfenv(f, env)
    local ok, e = pcall(f)
    for _, r in ipairs(rec) do walk(r.t, { file = name, root = r.root }, 0) end
    if not ok then return tostring(e) end
    return nil
end
-- the globals go (the locals above keep what the reader itself needs)
for _, k in ipairs({ "os", "io", "require", "package", "debug", "dofile", "loadfile", "load", "loadstring",
                     "setfenv", "getfenv", "python", "collectgarbage", "module", "newproxy" }) do
    _G[k] = nil
end
return S
'''


# ATT's preprocessor: "-- #if COND" ... "-- #elseif COND" ... "-- #else" ... "-- #endif" around plain
# Lua. The Forever build (.config/forever.config) sets these tags and patch 1.60.1.
PP_TAGS = {'ANYCLASSIC', 'FOREVER', 'CAMELOT', 'CLASSIC', 'CRIEVE', 'EXPLORATION', 'OBJECTIVES', 'NOSIMPLIFY'}
PP_PATCH = (1, 60, 1)
PP_EXPANSIONS = {'TBC': (2, 0, 1), 'WRATH': (3, 0, 2), 'CATA': (4, 0, 3), 'MOP': (5, 0, 4), 'WOD': (6, 0, 2),
                 'LEGION': (7, 0, 3), 'BFA': (8, 0, 1), 'SHADOWLANDS': (9, 0, 1), 'DF': (10, 0, 2), 'TWW': (11, 0, 2)}
_PP_LINE = re.compile(r'^\s*--\s*#(if|elseif|else|endif)\b(.*)$')


def _pp_version(word):
    if word in PP_EXPANSIONS:
        return PP_EXPANSIONS[word]
    try:
        return tuple(int(x) for x in word.split('.'))[:3]
    except ValueError:
        return None


def pp_true(cond):
    """Whether a preprocessor condition holds for the Forever build ("ANYCLASSIC", "NOT X",
    "BEFORE 4.0.3", "AFTER CATA", joined with AND / OR). Unknown words are false."""
    def atom(words):
        if words and words[0] == 'NOT':
            return not atom(words[1:])
        if len(words) == 2 and words[0] in ('BEFORE', 'AFTER'):
            v = _pp_version(words[1])
            if v is None:
                return False
            return PP_PATCH < v if words[0] == 'BEFORE' else PP_PATCH >= v
        return len(words) == 1 and words[0] in PP_TAGS
    cond = re.split(r'\s+--', cond, maxsplit=1)[0].strip()
    return any(all(atom(part.split()) for part in re.split(r'\s+AND\s+', alt))
               for alt in re.split(r'\s+OR\s+', cond))


def preprocess(src):
    """The source as the Forever build sees it: lines of branches that do not apply become empty
    (line numbers stay)."""
    out, stack, active = [], [], True
    for line in src.split('\n'):
        m = _PP_LINE.match(line)
        if not m:
            out.append(line if active else '')
            continue
        word, cond = m.group(1), m.group(2)
        if word == 'if':
            take = active and pp_true(cond)
            stack.append((active, take))
            active = take
        elif word == 'elseif' and stack:
            parent, taken = stack[-1]
            take = parent and not taken and pp_true(cond)
            stack[-1] = (parent, taken or take)
            active = take
        elif word == 'else' and stack:
            parent, taken = stack[-1]
            active = parent and not taken
            stack[-1] = (parent, True)
        elif word == 'endif' and stack:
            active = stack.pop()[0]
        out.append('')
    return '\n'.join(out)


def sandbox():
    """A lupa runtime without its python bridge, and the reader running in it (STUB)."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    return lua, lua.execute(STUB)


def _py(v):
    """A lupa value as plain Python: arrays (1..n) as lists, other tables as dicts."""
    if v is None or isinstance(v, (int, float, str, bool)):
        return v
    keys = list(v.keys())
    if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [_py(v[k]) for k in range(1, len(keys) + 1)]
    return {k: _py(v[k]) for k in keys}


def _int(v):
    return int(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def hundredths(v):
    return max(0, min(10000, int(v * 100 + 0.5)))


# Names live in the files' comments: "q(166, {	-- The Defias Brotherhood (7/7)",
# "qg = 234,	-- Gryan Stoutmantle <The People's Militia>", "n(644, {	-- Rhahk'Zor <The Foreman>".
_NAMED_NODE = re.compile(r'\b(q|n|inst|e|o|i)\(\s*(\d+)\s*(?:,\s*\{|\)\s*,?)\s*--\s*([^\n]+)')
_NPC_FIELD = re.compile(r'(?:\b(?:qg|cr|creatureID)|\["(?:qg|cr|creatureID)"\])\s*=\s*(\d+)\s*,\s*--\s*([^\n]+)')
_NPC_LIST = re.compile(r'(?:\b(?:crs|qgs)|\["(?:crs|qgs)"\])\s*=\s*\{([^}]*)\}')
_LIST_ENTRY = re.compile(r'(\d+)\s*,\s*--\s*([^\n]+)')
_NPC_PROVIDER = re.compile(r'\{\s*"n"\s*,\s*(\d+)\s*\}\s*,?\s*--\s*([^\n]+)')


def clean_name(text):
    """A name from a comment, without the authors' notes after it ("Name -- note", "Name // note")
    and without a title in angle brackets."""
    name = re.split(r'\s+--|\s*//|\s*<|\s+\[|\s+/\s', text, maxsplit=1)[0]
    return re.sub(r'\s*\([A-Z ]+!\)', '', name).strip()


def title_of(text):
    m = re.search(r'<([^>]+)>', text)
    return m.group(1).strip() if m else None


def comment_names(src):
    """{('q'|'n'|'inst'|'e'|'o', id): (name, title or None)} from one file's comments."""
    out = {}

    def put(kind, i, text):
        name = clean_name(text)
        if name:
            out.setdefault((kind, int(i)), (name, title_of(text)))
    for m in _NAMED_NODE.finditer(src):
        put(m.group(1), m.group(2), m.group(3))
    for m in _NPC_FIELD.finditer(src):
        put('n', m.group(1), m.group(2))
    for m in _NPC_PROVIDER.finditer(src):
        put('n', m.group(1), m.group(2))
    for lst in _NPC_LIST.finditer(src):
        for m in _LIST_ENTRY.finditer(lst.group(1)):
            put('n', m.group(1), m.group(2))
    return out


# The profession keys the addon translates (Gear.PROFESSIONS), by ATT's constant names.
PROFESSIONS = {'ALCHEMY': 'alchemy', 'BLACKSMITHING': 'blacksmithing', 'LEATHERWORKING': 'leatherworking',
               'TAILORING': 'tailoring', 'ENGINEERING': 'engineering', 'ENCHANTING': 'enchanting',
               'COOKING': 'cooking', 'FIRST_AID': 'firstaid', 'JEWELCRAFTING': 'jewelcrafting'}
# Client inventory types (Enum.InventoryType) as the INVTYPE_ tokens the scan gives.
INVTYPE = {1: 'INVTYPE_HEAD', 2: 'INVTYPE_NECK', 3: 'INVTYPE_SHOULDER', 4: 'INVTYPE_BODY', 5: 'INVTYPE_CHEST',
           6: 'INVTYPE_WAIST', 7: 'INVTYPE_LEGS', 8: 'INVTYPE_FEET', 9: 'INVTYPE_WRIST', 10: 'INVTYPE_HAND',
           11: 'INVTYPE_FINGER', 12: 'INVTYPE_TRINKET', 13: 'INVTYPE_WEAPON', 14: 'INVTYPE_SHIELD',
           15: 'INVTYPE_RANGED', 16: 'INVTYPE_CLOAK', 17: 'INVTYPE_2HWEAPON', 18: 'INVTYPE_BAG',
           19: 'INVTYPE_TABARD', 20: 'INVTYPE_ROBE', 21: 'INVTYPE_WEAPONMAINHAND', 22: 'INVTYPE_WEAPONOFFHAND',
           23: 'INVTYPE_HOLDABLE', 24: 'INVTYPE_AMMO', 25: 'INVTYPE_THROWN', 26: 'INVTYPE_RANGEDRIGHT',
           27: 'INVTYPE_QUIVER', 28: 'INVTYPE_RELIC'}


def _build_key(build):
    return tuple(int(x) for x in build.split('.')) if build else ()


def wago_csv(folder, table):
    """The client table <table> in folder: <Table>.csv or <Table>.<build>.csv (the name wago.tools
    gives a download, e.g. UiMapAssignment.1.60.1.70235.csv); of several builds the newest, a file
    without a build last. None when the folder has none."""
    if not folder or not os.path.isdir(folder):
        return None
    pat = re.compile(r'^' + re.escape(table) + r'(?:\.(\d+(?:\.\d+)*))?\.csv$', re.I)
    found = []
    for name in os.listdir(folder):
        m = pat.match(name)
        if m:
            found.append((_build_key(m.group(1)), name))
    return os.path.join(folder, max(found)[1]) if found else None


def wago_rows(table, *dirs):
    """The rows of the newest <table> CSV of each folder, the folders in the order given (the
    user's wago.tools download first, then the copy ATT ships)."""
    for d in dirs:
        path = wago_csv(d, table)
        if path:
            with open(path, encoding='utf-8-sig') as fh:
                yield from csv.DictReader(fh)


def read_uimap_instances(*dirs):
    """uiMapID -> instance map id (the client's Map id, what GetInstanceInfo reports) from the
    UiMapAssignment client tables in the given folders (the user's wago.tools download first, then
    the copy ATT ships); the first assignment of a uiMap wins. The tables of WoW Forever 1.60.1 hold
    the outdoor zones and battlegrounds only, no Classic dungeon map (see read_area_instances)."""
    out = {}
    for row in wago_rows('UiMapAssignment', *dirs):
        try:
            ui, mid, order = int(row['UiMapID']), int(row['MapID']), int(row.get('OrderIndex') or 0)
        except (KeyError, ValueError):
            continue
        if order == 0:
            out.setdefault(ui, mid)
    return out


# ATT's instance names the client's AreaTable spells otherwise.
CLIENT_NAMES = {"The Temple of Atal'hakkar": 'Sunken Temple'}

# The maps of the open world (Eastern Kingdoms, Kalimdor): an area on one of them is no instance.
OUTDOOR_MAPS = (0, 1)


def name_key(name):
    """Instance names compared without case, punctuation and a leading "The"."""
    return re.sub(r'^the', '', re.sub(r'[^a-z0-9]+', '', (name or '').lower()))


def read_area_instances(*dirs):
    """({area id: instance map id}, {name_key(name): instance map id}) from the AreaTable client
    tables: an area's ContinentID is the map it lies on, the instance map for an area inside an
    instance. Areas of the open world (OUTDOOR_MAPS) are left out. By name only areas at the top
    (no parent area), and only names that point at one map (not "Westfall", which several test and
    event maps share); the first folder's table wins."""
    by_area, names = {}, {}
    for row in wago_rows('AreaTable', *dirs):
        try:
            aid, mid, parent = int(row['ID']), int(row['ContinentID']), int(row.get('ParentAreaID') or 0)
        except (KeyError, ValueError):
            continue
        if mid in OUTDOOR_MAPS or aid in by_area:
            continue
        by_area[aid] = mid
        if parent == 0:
            for n in {row.get('AreaName_lang'), row.get('ZoneName')}:
                if n:
                    names.setdefault(name_key(n), set()).add(mid)
    return by_area, {k: next(iter(v)) for k, v in names.items() if len(v) == 1}


def instance_map_id(maps, area, names, uimap_instance, area_instance):
    """The instance map id of an ATT instance: through its uiMaps (UiMapAssignment), else its area
    (AreaTable; ATT gives the outdoor area of some, as Gnomeregan's in Dun Morogh), else its name."""
    for m in maps:
        if m in uimap_instance:
            return uimap_instance[m]
    by_area, by_name = area_instance
    if area in by_area:
        return by_area[area]
    for n in [x for n in names for x in (n, CLIENT_NAMES.get(n))]:
        if n and name_key(n) in by_name:
            return by_name[name_key(n)]
    return None


def read_itemdb(base, lua_S=None):
    """{item id: scan-like dict} from ATT's export of the Forever client's item table: name, q
    (quality), ilvl, min (required level), classID, subclassID, equipLoc, bind, classes (mask, 0 all),
    skill (required skill line). Missing fields are the client's defaults (0)."""
    path = os.path.join(base, '.config', 'exports', 'ItemDB.lua')
    if not os.path.exists(path):
        return {}
    if lua_S is None:
        lua_S = sandbox()[1]
    with open(path, encoding='utf-8-sig') as fh:
        db = lua_S.itemdb(fh.read())
    out = {}
    for iid, row in db.items():
        g = lambda k: row[k]  # noqa: E731
        mask = 0
        cl = g('classes')
        if cl is not None:
            for c in cl.values():
                if _int(c):
                    mask |= 1 << (int(c) - 1)
        out[int(iid)] = {
            'name': str(g('name') or ''), 'q': _int(g('q')) or 0, 'ilvl': _int(g('iLvl')) or 0, 'min': _int(g('lvl')) or 0,
            'classID': _int(g('class')) or 0, 'subclassID': _int(g('subclass')) or 0,
            'equipLoc': INVTYPE.get(_int(g('inventoryType')) or 0, ''), 'icon': '', 'bind': _int(g('b')) or 0,
            'classes': mask, 'skill': _int(g('requireSkill')) or 0, 'stats': '',
        }
    return out


def load(base=ATT_CACHE, items=True, wago=None):
    """The neutral form of a download (see NEUTRAL in tools/README.md, section att_data.py):

    {'commit', 'files', 'errors': {file: text}, 'maps': {MAP constant: uiMapID},
     'instances': {ATT instance id: {'name', 'area', 'maps', 'points', 'file', 'old', 'mapID'}},
     'quests': {id: {'name', 'minLevel', 'faction', 'classes', 'givers', 'giver', 'points', 'objects',
                     'startItem', 'inside', 'zone', 'inst', 'pre', 'alt', 'rewards', 'file', 'old'}},
     'npcs': {id: {'name', 'title', 'points', 'zone', 'faction', 'kinds' (set), 'inst', 'old'}},
     'drops': [(item, npc id or None, kind, ATT instance id or None, zone uiMapID or None, old, encounter name)],
     'zone_drops': [(item, [npc ids], ATT instance id or None, zone, old)],
     'sold': [(item, vendor id, old)], 'world': [item], 'pvp': [(item, faction)],
     'crafted': [(item, profession key)], 'items': {id: item dict (read_itemdb)}, 'uimap_instance': {},
     'item_names': {id: English name from the comments}}

    Points are (uiMapID, x, y) in hundredths of a percent. Files under zzOLD/ are "old": the
    Classic records the authors have not moved into the Forever folders yet; a quest or NPC a
    Forever file knows keeps its Forever record."""
    lua, S = sandbox()
    with open(os.path.join(base, '.config', 'constants', 'maps.lua'), encoding='utf-8') as fh:
        S.maps(fh.read())
    raw = S.new()
    names, errors, files = {}, {}, []
    for path in data_files(base):
        rel = os.path.relpath(path, base).replace(os.sep, '/')
        with open(path, encoding='utf-8-sig') as fh:
            src = preprocess(fh.read())
        for k, v in comment_names(src).items():
            names.setdefault(k, v)
        err = S.run(src, rel, raw)
        if err:
            errors[rel] = err
        files.append(rel)
    raw = _py(raw)
    old = lambda f: (f or '').startswith('zzOLD/')  # noqa: E731
    wago_dirs = (wago, os.path.join(base, ".config", ".wago"))
    uimap_instance, area_instance = read_uimap_instances(*wago_dirs), read_area_instances(*wago_dirs)

    def pts(lst):
        out = []
        for p in lst or []:
            pt = (int(p[0]), hundredths(p[1]), hundredths(p[2]))
            if pt not in out:
                out.append(pt)
        return out

    instances = {}
    for r in raw['insts'] or []:
        iid = _int(r.get('id'))
        if iid is None or iid in instances:
            continue
        maps = [int(m) for m in r.get('maps') or []]
        stem = os.path.splitext(os.path.basename(r['file']))[0]
        # "1.7 Zul'Gurub", "1.0 - molten core": the authors' order number is no part of the name
        stem = re.sub(r'^[\d.]+\s*(?:-\s*)?', '', stem)
        name = (names.get(('inst', iid)) or (None,))[0] or stem
        instances[iid] = {'name': name, 'area': _int(r.get('area')), 'maps': maps, 'points': pts(r.get('pts')),
                          'file': r['file'], 'stem': stem, 'old': old(r['file']),
                          'mapID': instance_map_id(maps, _int(r.get('area')), (name, stem), uimap_instance,
                                                   area_instance)}

    def faction(code):
        return code if code in ('A', 'H') else ''

    quests = {}
    for r in raw['quests'] or []:
        qid = int(r['id'])
        givers = [int(g) for g in r.get('givers') or []]
        rec = {'name': (names.get(('q', qid)) or (None,))[0], 'minLevel': _int(r.get('lvl')) or 0,
               'faction': faction(r.get('races')), 'classes': int(r.get('classes') or 0), 'givers': givers,
               'giver': next((names[('n', g)][0] for g in givers if ('n', g) in names), None),
               'points': pts(r.get('pts'))[:4], 'objects': [int(o) for o in r.get('objs') or []],
               'startItem': bool(r.get('startItem')), 'inside': bool(r.get('inside')),
               'zone': _int(r.get('zone')), 'inst': _int(r.get('inst')),
               'pre': [int(p) for p in r.get('pre') or []], 'alt': [int(p) for p in r.get('alt') or []],
               'rewards': [], 'file': r['file'], 'old': old(r['file'])}
        have = quests.get(qid)
        if have is None:
            quests[qid] = rec
        elif have['old'] == rec['old']:
            # a quest listed twice in the same tier: the second fills what the first left open
            for k, v in rec.items():
                if not have.get(k) and v:
                    have[k] = v
    for q in quests.values():
        if not q['name']:
            q['name'] = None

    npcs = {}
    for r in raw['npcs'] or []:
        nid = int(r['id'])
        name, title = names.get(('n', nid)) or names.get(('e', _int(r.get('encounter')) or -1)) or (None, None)
        rec = npcs.get(nid)
        if rec is None or (rec['old'] and not old(r['file'])):
            rec = npcs[nid] = {'name': name, 'title': title, 'points': [], 'zone': _int(r.get('zone')),
                               'faction': faction(r.get('races')), 'kinds': set(), 'inst': _int(r.get('inst')),
                               'old': old(r['file'])}
        elif rec['old'] != old(r['file']):
            continue
        rec['kinds'].add(r['kind'])
        for p in pts(r.get('pts')):
            if p not in rec['points']:
                rec['points'].append(p)
    # a quest giver stands where the quest starts: its points count for the NPC too
    for q in sorted(quests.values(), key=lambda q: q['old']):
        if len(q['givers']) != 1 or not q['points']:
            continue
        g = q['givers'][0]
        rec = npcs.get(g)
        if rec is None:
            name, title = names.get(('n', g)) or (None, None)
            rec = npcs[g] = {'name': name, 'title': title, 'points': [], 'zone': q['zone'], 'faction': q['faction'],
                             'kinds': {'giver'}, 'inst': q['inst'], 'old': q['old']}
        if rec['old'] and not q['old']:
            continue
        rec['kinds'].add('giver')
        for p in q['points']:
            if p not in rec['points']:
                rec['points'].append(p)
    for nid, rec in npcs.items():
        if not rec['name']:
            rec['name'] = (names.get(('n', nid)) or (None,))[0]

    drops, zone_drops, sold, world, pvp, crafted = [], [], [], [], [], []
    drop_points = {}   # item -> where the data says it drops
    for r in raw['items'] or []:
        item = int(r['id'])
        o = old(r.get('file'))
        quest, npc, kind = _int(r.get('quest')), _int(r.get('npc')), r.get('npcKind')
        inst, zone, root, hdr = _int(r.get('inst')), _int(r.get('zone')), r.get('root'), r.get('hdr')
        if quest is not None:
            q = quests.get(quest)
            if q is not None and q['old'] == o and item not in q['rewards']:
                q['rewards'].append(item)
            continue
        if root == 'Craftables':
            prof = PROFESSIONS.get(r.get('prof') or '')
            if prof:
                crafted.append((item, prof))
            continue
        if root == 'WorldDrops':
            world.append(item)
            continue
        if root == 'PVP':
            pvp.append((item, faction(r.get('races'))))
            continue
        if npc is not None and kind == 'vendor':
            sold.append((item, npc, o))
        elif npc is not None or kind == 'boss':
            enc = _int(r.get('enc'))
            boss = (names.get(('e', enc)) or (None,))[0] if enc is not None else None
            drops.append((item, npc, kind, inst, zone, o, boss))
        elif hdr == 'ZONE_DROPS' or r.get('crs'):
            zone_drops.append((item, [int(c) for c in r.get('crs') or []], inst, zone, o))
            drop_points.setdefault(item, []).extend(pts(r.get('pts')))
    # mobs the zone drops name only by id (crs): a record with their name, the drop's zone and,
    # where the data says where the item drops, those points (the mobs that drop it stand there)
    for item, crs, inst, zone, o in zone_drops:
        for c in crs:
            if c not in npcs:
                name, title = names.get(('n', c)) or (None, None)
                npcs[c] = {'name': name, 'title': title, 'points': [], 'zone': zone, 'faction': '',
                           'kinds': {'mob'}, 'inst': inst, 'old': o}
            rec = npcs[c]
            if rec['kinds'] == {'mob'}:
                for p in drop_points.get(item, []):
                    if p not in rec['points']:
                        rec['points'].append(p)
    db = {'commit': commit_of(base), 'files': files, 'errors': errors, 'maps': _py(S.mapNames()),
          'instances': instances, 'quests': quests, 'npcs': npcs, 'drops': drops, 'zone_drops': zone_drops,
          'sold': sold, 'world': sorted(set(world)), 'pvp': sorted(set(pvp)), 'crafted': sorted(set(crafted)),
          'items': read_itemdb(base, S) if items else {}, 'uimap_instance': uimap_instance,
          'item_names': {i: v[0] for (k, i), v in names.items() if k == 'i'}}
    return db


def empty_db():
    """The neutral form without any data (tests, or a build without a download)."""
    return {'commit': None, 'files': [], 'errors': {}, 'maps': {}, 'instances': {}, 'quests': {}, 'npcs': {},
            'drops': [], 'zone_drops': [], 'sold': [], 'world': [], 'pvp': [], 'crafted': [], 'items': {},
            'uimap_instance': {}, 'item_names': {}}
