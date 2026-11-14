-- The run times of dungeons and raids (F-166, D-96): a clock per run of an instance. It starts with the
-- first fight (PLAYER_REGEN_DISABLED) inside the instance while the own run of Gear/Runs.lua has no
-- boss killed yet (entering alone starts nothing: people wait at the entrance), once per run of
-- Runs.lua; each boss kill of the instance's list (ENCOUNTER_END with success, BOSS_KILL) stores its
-- split (seconds since the start, wall time: outside and logged out counts too) and the kill of the
-- last boss of the game's order (the facts' enc) ends it as finished. A run of Runs.lua that ends
-- before (the instance reset, another instance, 30 minutes outside, 12 hours) or `/amisia zeiten stop`
-- ends the clock "nicht beendet": kept in the history, never a best time. A map of several dungeons (the
-- halves of Blackrock Spire, the Scarlet Monastery's four wings; F-174, D-106): the first kill decides the
-- dungeon of the clock; once that dungeon is done, the first fight of the next entry starts the clock of
-- the next; a kill of another of them while a clock with kills runs ends it unfinished and starts the
-- other's from the first fight of this entry. Saved account-wide in
-- AmisiaDB.runTimes = { v = 1, inst = { [dungeon key] = { nm, best = run, seg = { [encounter id] =
-- { t, at, c } }, runs = { run, ... } } }, live = { [character] = { k, i, nm, at, r, s, n, x, g, rk } }, last =
-- { [character] = { r = the Runs run's at, i = its instance, k = the key of that clock } whose clock ran } }; a run = { at, t, s = { [encounter id] =
-- seconds }, n = group size, c = character, d = true when finished, x = mob experience, g = looted copper
-- (F-180, Gear/RunGains.lua; older runs have neither) }; live.rk = { [NPC id] = true } the rares seen
-- dead. The key is the dungeon or raid
-- key alone: this client has one difficulty per instance and the raids a fixed size (D-96).
-- Fires "RUNTIMES" (what changed) for the window (Gear/RunTimer.lua) and the part Zeiten of the pages.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local RT = {}
ns.RunTimes = RT

local MAX_RUNS = 20          -- history per instance
local MAX_INST = 60          -- instances kept (the latest ones)
local MAX_CHARS = 12         -- running clocks kept (one per character)
local MAX_LAST = 40
local MAX_ENC = 40
local AWAY = 30 * 60         -- outside longer than this: the run is over (as Runs.lua's fresh run)
local MAX_LIVE = 12 * 3600   -- a clock older than this is over
local MAX_T = 7 * 86400      -- no run is longer than a week
local MAX_XP = 1e9           -- experience of one run at most (F-180)
local MAX_COPPER = 1e11      -- money of one run at most (copper)
local MAX_RARES = 40         -- rare kills kept per clock
RT.MAX_RUNS, RT.MAX_INST, RT.AWAY, RT.MAX_LIVE = MAX_RUNS, MAX_INST, AWAY, MAX_LIVE

local function now() return time() end

---------------------------------------------------------------------------
-- The saved data and its cleanup
---------------------------------------------------------------------------
local function plainName(s, max)
    return type(s) == "string" and s ~= "" and #s <= (max or 60) and not s:find("|", 1, true) and s or nil
end

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v or v < lo or v > hi then return nil end
    return v
end

-- A run record checked field by field, or nil.
local function cleanRun(r)
    if type(r) ~= "table" then return nil end
    local at, t = num(r.at, 1, 4e9), num(r.t, 0, MAX_T)
    local c = plainName(r.c)
    if not (at and t and c) then return nil end
    local s, n = {}, 0
    if type(r.s) == "table" then
        for enc, v in pairs(r.s) do
            local secs = num(v, 0, MAX_T)
            if type(enc) == "number" and enc >= 1 and enc == math.floor(enc) and secs and n < MAX_ENC then
                s[enc], n = secs, n + 1
            end
        end
    end
    local size = num(r.n, 1, 40)
    -- the mob experience and the looted money of the run (F-180, D-112): optional, older runs have none
    local x, g = num(r.x, 0, MAX_XP), num(r.g, 0, MAX_COPPER)
    return { at = math.floor(at), t = t, s = s, n = size and math.floor(size) or 1, c = c, d = r.d == true or nil,
        x = x and math.floor(x) or nil, g = g and math.floor(g) or nil }
end
RT.CleanRun = cleanRun

local function cleanSeg(seg)
    local out = {}
    if type(seg) ~= "table" then return out end
    for enc, v in pairs(seg) do
        if type(enc) == "number" and enc >= 1 and enc == math.floor(enc) and type(v) == "table" then
            local t, at, c = num(v.t, 0, MAX_T), num(v.at, 1, 4e9), plainName(v.c)
            if t and at and c then out[enc] = { t = t, at = math.floor(at), c = c } end
        end
    end
    return out
end

-- The newest moment an instance record holds (to keep the latest instances).
local function lastAt(rec)
    local t = rec.best and rec.best.at or 0
    if rec.runs[1] and rec.runs[1].at > t then t = rec.runs[1].at end
    return t
end

-- Shapes AmisiaDB.runTimes (ADDON_LOADED): every field checked, bad entries dropped, the history
-- 20 per instance (newest first), 60 instances (the latest), a best only from a finished run.
function RT.Loaded()
    if not AmisiaDB then return nil end
    local src = AmisiaDB.runTimes
    if type(src) ~= "table" then src = {} end
    local out = { v = 1, inst = {}, live = {}, last = {} }
    local keep = {}
    for key, rec in pairs(type(src.inst) == "table" and src.inst or {}) do
        if type(key) == "string" and key:match("^[%w_%-]+$") and #key <= 40 and type(rec) == "table" then
            local runs = {}
            for _, r in ipairs(type(rec.runs) == "table" and rec.runs or {}) do
                local c = cleanRun(r)
                if c then runs[#runs + 1] = c end
            end
            table.sort(runs, function(a, b) return a.at > b.at end)
            while #runs > MAX_RUNS do runs[#runs] = nil end
            local best = cleanRun(rec.best)
            if best and not best.d then best = nil end
            local x = { nm = plainName(rec.nm), best = best, seg = cleanSeg(rec.seg), runs = runs }
            if best or #runs > 0 or next(x.seg) then
                out.inst[key] = x
                keep[#keep + 1] = key
            end
        end
    end
    if #keep > MAX_INST then
        table.sort(keep, function(a, b)
            local ta, tb = lastAt(out.inst[a]), lastAt(out.inst[b])
            if ta ~= tb then return ta > tb end
            return a < b
        end)
        for i = MAX_INST + 1, #keep do out.inst[keep[i]] = nil end
    end
    local chars = {}
    for c, l in pairs(type(src.live) == "table" and src.live or {}) do
        if plainName(c) and type(l) == "table" and type(l.k) == "string" and l.k:match("^[%w_%-]+$") then
            local i, at, r = num(l.i, 1, 1e9), num(l.at, 1, 4e9), num(l.r, 1, 4e9)
            local run = i and at and r and cleanRun({ at = at, t = 0, s = l.s, n = l.n, c = c, x = l.x, g = l.g })
            if run then
                -- the rares seen dead in this run (F-180): NPC ids
                local rk, nr = {}, 0
                for npc, v in pairs(type(l.rk) == "table" and l.rk or {}) do
                    if v == true and type(npc) == "number" and npc >= 1 and npc == math.floor(npc) and nr < MAX_RARES then
                        rk[npc], nr = true, nr + 1
                    end
                end
                out.live[c] = { k = l.k, i = math.floor(i), nm = plainName(l.nm), at = run.at, r = math.floor(r), s = run.s, n = run.n,
                    x = run.x or 0, g = run.g or 0, rk = rk }
                chars[#chars + 1] = c
            end
        end
    end
    if #chars > MAX_CHARS then
        table.sort(chars, function(a, b) return out.live[a].at > out.live[b].at end)
        for i = MAX_CHARS + 1, #chars do out.live[chars[i]] = nil end
    end
    local lasts = {}
    for c, x in pairs(type(src.last) == "table" and src.last or {}) do
        local at, i = type(x) == "table" and num(x.r, 1, 4e9), type(x) == "table" and num(x.i, 1, 1e9)
        if plainName(c) and at and i then
            local k = type(x.k) == "string" and #x.k <= 40 and x.k:match("^[%w_%-]+$") and x.k or nil
            out.last[c] = { r = math.floor(at), i = math.floor(i), k = k }
            lasts[#lasts + 1] = c
        end
    end
    if #lasts > MAX_LAST then
        table.sort(lasts, function(a, b) return out.last[a].r > out.last[b].r end)
        for i = MAX_LAST + 1, #lasts do out.last[lasts[i]] = nil end
    end
    AmisiaDB.runTimes = out
    return out
end

local function store()
    if not AmisiaDB then return nil end
    if type(AmisiaDB.runTimes) ~= "table" or AmisiaDB.runTimes.v ~= 1 then return RT.Loaded() end
    return AmisiaDB.runTimes
end

local function me() return ns.UnitFullName and ns.UnitFullName("player") or nil end

---------------------------------------------------------------------------
-- Where the character is
---------------------------------------------------------------------------
-- The instance stood in: its map id, kind ("party", "raid") and the client's name; nil outside.
local function instanceNow()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local ok, name, kind, _, _, _, _, _, inst = pcall(GetInstanceInfo)
    if not ok then return nil end
    kind, inst = ns.Plain(kind), tonumber(ns.Plain(inst))
    if (kind ~= "party" and kind ~= "raid") or not inst or inst < 1 then return nil end
    name = ns.Plain(name)
    return inst, kind, type(name) == "string" and name or nil
end
RT.InstanceNow = instanceNow

-- The own run of Runs.lua (read only), or nil.
local function runsRun()
    local c = ns.BisChar and ns.BisChar()
    return c and type(c.run) == "table" and c.run or nil
end

-- The dungeon or raid key of instance inst whose encounters hold enc (two keys share one map:
-- Blackrock Spire), else the first of inst with encounters; nil when none has any.
local function keyFor(inst, enc)
    local F = ns.DUNGEON_FACTS
    local first
    for _, e in ipairs(type(F) == "table" and type(F.list) == "table" and F.list or {}) do
        if e.inst == inst and type(e.enc) == "table" and #e.enc > 0 then
            if not enc then return e.key end
            first = first or e.key
            for _, id in ipairs(e.enc) do
                if id == enc then return e.key end
            end
        end
    end
    return first
end
RT.KeyFor = keyFor

local function groupSize()
    local n = type(GetNumGroupMembers) == "function" and tonumber(ns.Plain(GetNumGroupMembers())) or 0
    return math.max(1, math.min(40, math.floor(n or 0)))
end

-- The name of key: the client's name kept with its times, else the facts' name. A dungeon of a map of
-- several (D-106) always its own name (the client names only the map: "Scharlachrotes Kloster").
function RT.Name(key)
    local f = ns.Runs and ns.Runs.Fact(key)
    if f and f.part and ns.Dungeons and ns.Dungeons.Name then return ns.Dungeons.Name(f) end
    local t = store()
    local rec = t and t.inst[key]
    if rec and rec.nm then return rec.nm end
    return f and f.name or tostring(key)
end

-- The name a clock of key keeps: the client's instance name, none for a dungeon of a map of several.
local function keptName(key, name)
    local f = ns.Runs and ns.Runs.Fact(key)
    if f and f.part then return nil end
    return name
end

---------------------------------------------------------------------------
-- Formats
---------------------------------------------------------------------------
-- seconds as "m:ss", from an hour "h:mm:ss"
function RT.Fmt(secs)
    secs = math.max(0, math.floor((tonumber(secs) or 0) + 0.5))
    local h, m, s = math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
    return ("%d:%02d"):format(m, s)
end

-- a difference as "-0:12" (faster) or "+0:07" (slower); "0:00" the same
function RT.Diff(d)
    d = tonumber(d) or 0
    d = d < 0 and -math.floor(-d + 0.5) or math.floor(d + 0.5)
    if d == 0 then return "0:00" end
    return (d < 0 and "-" or "+") .. RT.Fmt(math.abs(d))
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------
local clock = {}   -- [character] = GetTime() at the start (this session; the live display only)
RT.lastDone = nil  -- the run just ended here: { k, run, prev (the best total before), best = true when new }

local function changed(what) ns.Fire("RUNTIMES", what) end

-- The record of key, made on first use.
local function instRec(t, key)
    local rec = t.inst[key]
    if not rec then
        rec = { seg = {}, runs = {} }
        t.inst[key] = rec
    end
    return rec
end

-- The segments of a run: per boss the time from the kill before (by time) to its own.
local function segments(s)
    local list = {}
    for enc, secs in pairs(s) do list[#list + 1] = { enc = enc, t = secs } end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.enc < b.enc
    end)
    local out, before = {}, 0
    for _, x in ipairs(list) do
        out[x.enc] = x.t - before
        before = x.t
    end
    return out
end
RT.Segments = segments

-- Ends the clock of character c: finished (done) or not. Returns the run.
local function finish(t, c, done)
    local l = t.live[c]
    if not l then return nil end
    t.live[c] = nil
    clock[c] = nil
    local total = 0
    if done then
        total = now() - l.at
    else
        -- an unfinished run: the time up to its last kill
        for _, secs in pairs(l.s) do
            if secs > total then total = secs end
        end
    end
    local run = { at = l.at, t = math.max(0, total), s = l.s, n = l.n, c = c, d = done or nil,
        x = math.floor(tonumber(l.x) or 0), g = math.floor(tonumber(l.g) or 0) }
    local rec = instRec(t, l.k)
    rec.nm = rec.nm or l.nm
    local prev = rec.best and rec.best.t or nil
    local newBest = false
    if done then
        if not prev or run.t < prev then
            local s = {}
            for enc, secs in pairs(run.s) do s[enc] = secs end
            rec.best = { at = run.at, t = run.t, s = s, n = run.n, c = c, d = true }
            newBest = true
        end
        for enc, secs in pairs(segments(run.s)) do
            local had = rec.seg[enc]
            if not had or secs < had.t then rec.seg[enc] = { t = secs, at = run.at, c = c } end
        end
    end
    table.insert(rec.runs, 1, run)
    while #rec.runs > MAX_RUNS do rec.runs[#rec.runs] = nil end
    -- the latest 60 instances
    local keys = {}
    for k in pairs(t.inst) do keys[#keys + 1] = k end
    if #keys > MAX_INST then
        table.sort(keys, function(a, b) return lastAt(t.inst[a]) > lastAt(t.inst[b]) end)
        for i = MAX_INST + 1, #keys do t.inst[keys[i]] = nil end
    end
    RT.lastDone = { k = l.k, run = run, prev = prev, best = newBest, nm = l.nm, rk = l.rk or {} }
    if done then
        local name = l.nm or RT.Name(l.k)
        if prev then
            ns.msg(L["%s in %s (Bestzeit %s, %s)."]:format(name, RT.Fmt(run.t), RT.Fmt(prev), RT.Diff(run.t - prev)))
        else
            ns.msg(L["%s in %s (erste gemessene Zeit)."]:format(name, RT.Fmt(run.t)))
        end
    end
    changed(done and "done" or "end")
    return run
end

-- The clock of the character ends unfinished when its run of Runs.lua is over: reset, another
-- instance or a fresh run, 30 minutes outside, 12 hours.
function RT.Check()
    local t, c = store(), me()
    local l = t and c and t.live[c]
    if not l then return end
    local run = runsRun()
    local over = not run or run.at ~= l.r or run.inst ~= l.i
        or (run.left ~= nil and now() - run.left > AWAY)
        or now() - l.at > MAX_LIVE
    if over then finish(t, c, false) end
end

local entryFight    -- { entry = ns.Runs.entry, at } the first fight since the character entered (memory)
local doneEntry     -- the entry in which a clock of a map of several dungeons ended finished (memory)

-- Whether the run of Runs.lua lets a clock start in inst. One dungeon on the map: the run has no kill
-- and no clock ran in it. Several (D-106): every dungeon with a kill in the run is done, the last clock
-- of the run (if any) was of a done dungeon, and that did not end in this entry (no fresh clock from
-- the trash after the last boss).
local function canStart(t, c, run, inst)
    local had = t.last[c]
    local same = had and had.r == run.at and had.i == inst
    local keys = ns.Runs.KeysOf and ns.Runs.KeysOf(inst) or {}
    if #keys <= 1 then
        return not same and not (type(run.enc) == "table" and next(run.enc))
    end
    for enc in pairs(type(run.enc) == "table" and run.enc or {}) do
        local k = ns.Runs.KeyOfEncounter(inst, enc)
        if k and not ns.Runs.Done(k) then return false end
    end
    if same and not (had.k and ns.Runs.Done(had.k)) then return false end
    return doneEntry ~= ns.Runs.entry
end

-- Starts the clock of key in instance inst at the moment at (the run of Runs.lua: run).
local function start(t, c, key, inst, name, run, at)
    t.live[c] = { k = key, i = inst, nm = keptName(key, name or run.name), at = at, r = run.at, s = {}, n = groupSize(),
        x = 0, g = 0, rk = {} }
    t.last[c] = { r = run.at, i = inst, k = key }
    clock[c] = GetTime() - (now() - at)
    RT.lastDone = nil
end

-- A fight starts: the clock of a fresh run starts (inside an instance with encounters, the run of
-- Runs.lua of this instance without a kill and without a clock before; a map of several: canStart).
function RT.Fight()
    local t, c = store(), me()
    if not (t and c) then return end
    local entry = ns.Runs and ns.Runs.entry
    if not entryFight or entryFight.entry ~= entry then entryFight = { entry = entry, at = now() } end
    RT.Check()
    if t.live[c] then return end
    local inst, kind, name = instanceNow()
    if not inst then return end
    local run = runsRun()
    if not run or run.inst ~= inst or not tonumber(run.at) then return end
    if not canStart(t, c, run, inst) then return end
    -- the dungeon stood in (a guess in a map of several until the first kill), else the first with encounters
    local key = ns.Runs.Here and ns.Runs.Here()
    if not (key and ns.Runs.Encounters(key)) then key = keyFor(inst) end
    if not key then return end
    start(t, c, key, inst, name, run, now())
    changed("start")
    if ns.RunTimer and ns.RunTimer.Started then ns.RunTimer.Started(kind) end
end

-- A boss killed (an encounter id): its split; the last boss of the game's order ends the run.
function RT.Kill(enc)
    enc = tonumber(ns.Plain(enc))
    local t, c = store(), me()
    local l = t and c and t.live[c]
    if not (l and enc and enc >= 1) then return end
    if instanceNow() ~= l.i then return end
    -- the key of this map whose encounters hold enc (an encounter of none: nil)
    local other = ns.Runs.KeyOfEncounter and ns.Runs.KeyOfEncounter(l.i, enc)
    -- a kill of another key of this map (no split yet): that key
    if not next(l.s) and other and other ~= l.k then
        l.k, l.nm = other, keptName(other, l.nm)
        if t.last[c] then t.last[c].k = other end
    elseif other and other ~= l.k and ns.Runs.Encounters(other) then
        -- a kill in another dungeon of the map while this clock has kills (D-106): this one ends
        -- unfinished, the other's starts with the first fight of this entry
        local run = runsRun()
        local entry = ns.Runs and ns.Runs.entry
        local at = entryFight and entryFight.entry == entry and entryFight.at or now()
        finish(t, c, false)
        if not run then return end
        start(t, c, other, l.i, l.nm, run, math.max(at, l.at))
        l = t.live[c]
        changed("start")
    end
    local encs = ns.Runs.Encounters(l.k)
    if not encs or l.s[enc] then return end
    local known = false
    for _, id in ipairs(encs) do
        if id == enc then known = true end
    end
    if not known then return end
    l.s[enc] = now() - l.at
    l.n = math.max(l.n or 1, groupSize())
    if enc == encs[#encs] then
        local several = ns.Runs.KeysOf and #ns.Runs.KeysOf(l.i) > 1
        finish(t, c, true)
        if several then doneEntry = ns.Runs and ns.Runs.entry end
    else
        changed("split")
    end
end

-- `/amisia zeiten stop`: ends the running clock without a best. Returns true when one ran.
function RT.Stop()
    local t, c = store(), me()
    if not (t and c and t.live[c]) then return false end
    finish(t, c, false)
    return true
end

-- The running clock of the character: its record and the seconds so far (GetTime for the display
-- within the session), or nil.
function RT.Live()
    local t, c = store(), me()
    local l = t and c and t.live[c]
    if not l then return nil end
    local secs
    if clock[c] then
        secs = GetTime() - clock[c]
    else
        secs = now() - l.at
        clock[c] = GetTime() - secs
    end
    return l, math.max(0, secs)
end

-- The rare mobs of key (DungeonData.lua rares, F-180): { { npc, English name }, ... } checked, or an
-- empty list where the data knows none.
function RT.Rares(key)
    local f = ns.Runs.Fact(key)
    local out = {}
    for _, r in ipairs(f and type(f.rares) == "table" and f.rares or {}) do
        if type(r) == "table" and type(r[1]) == "number" and r[1] > 0 and type(r[2]) == "string" then out[#out + 1] = r end
    end
    return out
end

-- The times of key: { nm, best, seg, runs } or nil.
function RT.Of(key)
    local t = store()
    return t and key and t.inst[key] or nil
end

-- Forgets the times of key (nil: of every instance); a running clock stays.
function RT.Clear(key)
    local t = store()
    if not t then return end
    if key then t.inst[key] = nil else t.inst = {} end
    if RT.lastDone and (not key or RT.lastDone.k == key) then RT.lastDone = nil end
    changed("clear")
end

---------------------------------------------------------------------------
-- What the window and the page show
---------------------------------------------------------------------------
-- The bosses of key in the game's order against rec (a live or finished run, or nil): per boss
-- { enc, name, split (rec's), best (the best run's split), diff (split - best), seg (the best
-- segment), next = true for the first boss not killed yet }.
function RT.Lines(key, rec)
    local f = ns.Runs.Fact(key)
    local encs = ns.Runs.Encounters(key)
    if not (f and encs) then return {} end
    local times = RT.Of(key)
    local best = times and times.best
    local out, nextSet = {}, false
    for i, enc in ipairs(encs) do
        local split = rec and rec.s and rec.s[enc] or nil
        local b = best and best.s[enc] or nil
        local x = { enc = enc, name = type(f.order) == "table" and f.order[i] or ("#" .. i), split = split, best = b,
            seg = times and times.seg[enc] and times.seg[enc].t or nil }
        if split and b then x.diff = split - b end
        if not split and not nextSet and rec then
            x.next = true
            nextSet = true
        end
        out[#out + 1] = x
    end
    return out
end

---------------------------------------------------------------------------
-- Events, settings, slash
---------------------------------------------------------------------------
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then RT.Loaded() end
end)
-- after Runs.lua (loaded before) has seen the new world
ns.OnEvent("PLAYER_ENTERING_WORLD", function() RT.Check() end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() RT.Check() end)
ns.Listen("RUN", function() RT.Check() end)
ns.OnEvent("PLAYER_REGEN_DISABLED", function() RT.Fight() end)
ns.OnEvent("ENCOUNTER_END", function(enc, _, _, _, success)
    if tonumber(ns.Plain(success)) == 1 then RT.Kill(enc) end
end)
ns.OnEvent("BOSS_KILL", function(enc) RT.Kill(enc) end)

-- Opens the part Zeiten of key on the page Dungeons or Raids.
function RT.ShowPart(key)
    if not ns.ShowDungeon then return false end
    return ns.ShowDungeon(key, "times")
end

local function confirmClear(key)
    local text = key and L["Alle Zeiten von %s löschen? Bestzeit, Zeiten je Boss und Verlauf fangen von vorn an."]:format(RT.Name(key))
        or L["Die Zeiten aller Dungeons und Raids löschen? Bestzeiten, Zeiten je Boss und Verlauf fangen von vorn an."]
    ns.W.Confirm(L["Zeiten löschen"], text, L["Löschen##Knopf"], function()
        RT.Clear(key)
        ns.msg(key and L["Zeiten von %s gelöscht."]:format(RT.Name(key)) or L["Alle Zeiten gelöscht."])
        if ns.Refresh then ns.Refresh() end
    end)
end
RT.ConfirmClear = confirmClear

-- `/amisia zeiten`: the window of the running clock or of the instance stood in; outside the times of
-- the last instance timed on its page. `stop`: ends the clock.
local function slash(rest)
    local word = (type(rest) == "string" and rest:match("^%s*(%S*)") or ""):lower()
    if word == "stop" or word == "aus" or word == "abbrechen" then   -- l10n-ok: typed words
        if RT.Stop() then
            ns.msg(L["Uhr angehalten: der Lauf zählt als nicht beendet."])
            if ns.RunTimer then ns.RunTimer.Hide() end
        else
            ns.msg(L["Es läuft keine Uhr."])
        end
        return
    end
    if word ~= "" then
        ns.msg(L["Aufruf: /amisia zeiten [stop]"])
        return
    end
    RT.Check()
    local l = RT.Live()
    local inst = instanceNow()
    local here = inst and (ns.Runs.Here() or keyFor(inst))
    if (l or here) and ns.RunTimer then
        ns.RunTimer.Show(l and l.k or here)
        return
    end
    -- outside: the instance timed last
    local t, key, at = store(), nil, 0
    for k, rec in pairs(t and t.inst or {}) do
        if lastAt(rec) > at then key, at = k, lastAt(rec) end
    end
    if key then
        RT.ShowPart(key)
    else
        ns.msg(L["Noch keine Zeiten. Die Uhr läuft ab dem ersten Kampf in einem Dungeon oder Raid."])
    end
end
RT.Slash = slash

ns.RegisterSlash("zeiten", { en = "times", args = L["[stop]"], desc = L["Lauf-Zeiten: Zwischenzeiten und Bestzeit des Dungeons oder Raids"],
    run = function(rest) slash(rest) end })

ns.RegisterSettings{ key = "runtimes", label = L["Lauf-Zeiten"], order = 52, group = "dungeons", pages = { "dungeons", "raidjournal" }, items = {
    { key = "runtimes.window", type = "toggle", label = L["Zeitfenster in Dungeons"], default = true,
      tip = L["Öffnet ein kleines Fenster mit der Uhr, Mob-XP, Gold, den Bossen und den Rare des Dungeons, sobald dort der erste Kampf beginnt. Gemessen wird auch ohne das Fenster."] },
    { key = "runtimes.raids", type = "toggle", label = L["Zeitfenster auch in Raids"], default = true,
      tip = L["Das Fenster öffnet sich auch beim ersten Kampf in einem Raid."] },
    { key = "runtimes.clear", type = "button", label = L["Alle Bestzeiten löschen"], run = function() confirmClear(nil) end,
      tip = L["Löscht nach einer Rückfrage die Zeiten aller Dungeons und Raids: Bestzeiten, Zeiten je Boss und Verlauf. Eine laufende Uhr läuft weiter."] },
} }

-- for the tests
RT._reset = function()
    clock = {}
    RT.lastDone = nil
    entryFight, doneEntry = nil, nil
end
end)
