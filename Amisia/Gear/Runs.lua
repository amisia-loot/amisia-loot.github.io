-- The own run of a dungeon or raid (F-146, D-72): which bosses this character killed since entering
-- a fresh instance. The kills come from the client's kill events (ENCOUNTER_END with success,
-- BOSS_KILL: the encounter's id), a boss can be marked by hand; the run ends when the instance is
-- reset (the client's message naming it), when the character enters another instance, and in a
-- dungeon when it comes back after FRESH seconds outside (the client resets an empty instance by
-- then; leaving counts from the logout too), in a raid when its raid ID ran out (the lockout keeps
-- the kills until then). Kept per character in AmisiaDB.bis.chars[name].run = { inst, name, enc =
-- { [encounter id] = true }, at, left, reset } (Bis.lua checks it); the pages Dungeons and Raids show
-- it (n/m on the cards, ticks on the bosses) and refresh on "RUN". An instance map that hosts several
-- dungeons (the halves of Blackrock Spire, the Scarlet Monastery's four wings; F-174, D-106) is one run
-- with each dungeon's own encounters; run.here names the dungeon of the last kill since the character
-- entered (R.Here: sure from the first kill on, a guess before).
local ADDON, ns = ...
ns.Load(function()

local R = {}
ns.Runs = R

local FRESH = 30 * 60       -- outside longer than this: the next entry is a fresh instance
local MAX_ENC = 40          -- encounters kept per run at most

local function now() return time() end

-- The facts of a dungeon or raid key (DungeonData.lua): inst, order, enc (encounter ids in the
-- game's order, lined up with order), maps, keys; nil for an unknown key.
function R.Fact(dkey)
    local F = ns.DUNGEON_FACTS
    for _, e in ipairs(type(F) == "table" and type(F.list) == "table" and F.list or {}) do
        if e.key == dkey then return e end
    end
    return nil
end

-- The instance the character stands in: its map id, or nil outside a dungeon or raid.
-- The instance the character stands in: its map id, kind ("party", "raid") and name; nil outside.
local function instanceNow()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local ok, name, kind, _, _, _, _, _, inst = pcall(GetInstanceInfo)
    if not ok then return nil end
    kind, inst = ns.Plain(kind), tonumber(ns.Plain(inst))
    if (kind ~= "party" and kind ~= "raid") or not inst or inst < 1 then return nil end
    return inst, kind, ns.Plain(name)
end

-- When the character's raid ID of instance inst runs out (Raid/RaidIDs.lua), or nil.
local function lockEnd(inst)
    local me = ns.RaidIDOf and ns.UnitFullName and ns.UnitFullName("player")
    if not me then return nil end
    local st, x = ns.RaidIDOf(me, inst)
    return st == "locked" and type(x) == "table" and tonumber(x.r) or nil
end

-- A new run of instance inst (name) in run table r.
local function fresh(r, inst, name)
    r.inst, r.name, r.enc, r.at, r.left, r.reset, r.here = inst, name, {}, now(), nil, nil, nil
end

-- The floors of the instances (D-72): Forever's client tables list no dungeon floors, so the
-- character learns them inside: the client's map of the place stood in and the other floors of its
-- map group. AmisiaDB.floors = { [instance map id] = { uiMapID, ... } } (top floor first), checked on
-- load (R.Migrate).
local MAX_FLOORS = 12
function R.Migrate(root)
    local t = type(root.floors) == "table" and root.floors or {}
    local drop = {}
    for inst, list in pairs(t) do
        local ok = type(inst) == "number" and inst > 0 and type(list) == "table" and #list > 0 and #list <= MAX_FLOORS
        for _, id in ipairs(ok and list or {}) do
            if type(id) ~= "number" or id < 1 then ok = false end
        end
        if not ok then drop[#drop + 1] = inst end
    end
    for _, k in ipairs(drop) do t[k] = nil end
    root.floors = t
    return t
end

local function floorsDB()
    if not AmisiaDB then return nil end
    if type(AmisiaDB.floors) ~= "table" then R.Migrate(AmisiaDB) end
    return AmisiaDB.floors
end

-- The learned floors of an instance (map id), or nil.
function R.Floors(inst)
    local t = floorsDB()
    return t and inst and t[inst] or nil
end

local function call(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, ...)
    return ok and ns.Plain(v) or nil
end

-- Learns the floors of instance inst from where the character stands.
local function learnFloors(inst)
    local M, t = C_Map, floorsDB()
    if not (inst and t and M) then return end
    local here = tonumber(call(M.GetBestMapForUnit, "player"))
    if not here then return end
    local list, seen = {}, {}
    local group = tonumber(call(M.GetMapGroupID, here))
    local members = group and call(M.GetMapGroupMembersInfo, group)
    if type(members) == "table" then
        local sorted = {}
        for _, m in ipairs(members) do
            if type(m) == "table" and tonumber(m.mapID) then sorted[#sorted + 1] = m end
        end
        table.sort(sorted, function(a, b)
            local ha, hb = tonumber(a.relativeHeightIndex) or 0, tonumber(b.relativeHeightIndex) or 0
            if ha ~= hb then return ha > hb end
            return a.mapID < b.mapID
        end)
        for _, m in ipairs(sorted) do
            if not seen[m.mapID] then seen[m.mapID] = true list[#list + 1] = m.mapID end
        end
    end
    -- the floor stood on, and the ones learned before, stay
    for _, id in ipairs({ here, unpack(t[inst] or {}) }) do
        if not seen[id] then seen[id] = true list[#list + 1] = id end
    end
    while #list > MAX_FLOORS do list[#list] = nil end
    local old = t[inst]
    local same = old and #old == #list
    for i = 1, same and #list or 0 do
        if old[i] ~= list[i] then same = false end
    end
    if not same then
        t[inst] = list
        ns.Fire("RUN")
    end
end

-- The character's run table, made on first use (nil before the saved data is there).
local function charRun(make)
    local c = ns.BisChar and ns.BisChar()
    if not c then return nil end
    if c.run == nil and make then c.run = { enc = {} } end
    return c.run
end

-- The keys of the facts on instance map inst, in the facts' order (several where one map hosts
-- several dungeons: the halves of Blackrock Spire, the Scarlet Monastery's four wings, D-106).
function R.KeysOf(inst)
    local out = {}
    local F = ns.DUNGEON_FACTS
    for _, e in ipairs(type(F) == "table" and type(F.list) == "table" and F.list or {}) do
        if inst and e.inst == inst then out[#out + 1] = e.key end
    end
    return out
end

-- The key among keys whose encounters hold enc, or nil.
local function keyOfEncounter(keys, enc)
    for _, k in ipairs(keys) do
        local f = R.Fact(k)
        for _, id in ipairs(f and type(f.enc) == "table" and f.enc or {}) do
            if id == enc then return k end
        end
    end
    return nil
end
R.KeyOfEncounter = function(inst, enc) return keyOfEncounter(R.KeysOf(inst), enc) end

-- The dungeon or raid key of the instance the character stands in, whether that is sure, and the
-- keys of its map; nil outside. A map of several dungeons (D-106): the one of the last kill since the
-- character entered (sure); before it a guess, the first of them without a kill in this run (else
-- the first), with all of them as the candidates. The client names no wing: one map, one area, and
-- the sub zone's names are no table Amisia has.
function R.Here()
    local inst = instanceNow()
    if not inst then return nil end
    local keys = R.KeysOf(inst)
    if #keys <= 1 then return keys[1], keys[1] ~= nil, keys end
    local run = charRun(false)
    local mine = run and run.inst == inst and type(run.enc) == "table"
    if mine and type(run.here) == "string" then
        for _, k in ipairs(keys) do
            if k == run.here then return k, true, keys end
        end
    end
    for _, k in ipairs(keys) do
        local f = R.Fact(k)
        local hit = false
        for _, id in ipairs(mine and f and type(f.enc) == "table" and f.enc or {}) do
            if run.enc[id] then hit = true end
        end
        if not hit then return k, false, keys end
    end
    return keys[1], false, keys
end

-- the pages Dungeons and Raids refresh on "RUN" (not DATA_CHANGED: no other part cares)
local function changed()
    ns.Fire("RUN")
end

-- Every entry into an instance counts (R.entry; not saved): a page opens the instance once per
-- entry (D-72). lastInst: the instance of the last world, nil outside.
R.entry = 0
local lastInst

-- Entering or leaving a world: a new run for another instance or after a long time outside; the
-- time it was left. login, reload: PLAYER_ENTERING_WORLD's (the character stands where it stood: the
-- dungeon of the last kill stays known); any other entry forgets it (D-106).
function R.Update(login, reload)
    local inst, kind, name = instanceNow()
    local entered = false
    if inst ~= lastInst then
        lastInst = inst
        if inst then
            R.entry = R.entry + 1
            entered = not (login or reload)
        end
        changed()
    end
    local run = charRun(inst ~= nil)
    if not run then return end
    if entered then run.here = nil end
    if inst then
        local stale
        if kind == "raid" then
            -- a raid's kills last while its raid ID does
            stale = run.reset ~= nil and now() > run.reset
        else
            stale = run.left ~= nil and now() - run.left > FRESH
        end
        if run.inst ~= inst or stale then
            fresh(run, inst, name)
            changed()
        end
        run.left = nil
        run.name = run.name or name
        if kind == "raid" then run.reset = lockEnd(inst) or run.reset end
        learnFloors(inst)
    elseif run.inst and not run.left then
        run.left = now()
    end
end

-- Leaving the world (a loading screen, the logout): the time the run's instance was left.
function R.Leave()
    local run = charRun(false)
    if run and run.inst and not run.left then run.left = now() end
end

-- A kill in the instance the character stands in (an encounter id).
function R.Kill(enc)
    enc = tonumber(ns.Plain(enc))
    local inst = instanceNow()
    if not enc or enc < 1 or not inst then return end
    local run = charRun(true)
    if not run then return end
    if run.inst ~= inst then fresh(run, inst, select(3, instanceNow())) end
    -- a map of several dungeons: the kill tells which one the character is in (D-106)
    local keys = R.KeysOf(inst)
    local here = #keys > 1 and keyOfEncounter(keys, enc) or nil
    local n = 0
    for _ in pairs(run.enc) do n = n + 1 end
    if not run.enc[enc] and n < MAX_ENC then
        run.enc[enc] = true
        run.here = here or run.here
        changed()
    elseif here and run.here ~= here then
        run.here = here
        changed()
    end
end

-- Whether every boss of dkey's order with an encounter is killed in the run (the dungeon is done).
function R.Done(dkey)
    local _, n, m = R.Of(dkey)
    return n ~= nil and m > 0 and n >= m
end

-- The run ends (the instance was reset; "Lauf zurücksetzen"). name: only when the run is of the
-- instance of that name (the client's message names it). Inside the instance a fresh run begins.
function R.Reset(name)
    local c = ns.BisChar and ns.BisChar()
    if not (c and c.run) then return end
    if name and c.run.name and c.run.name ~= name then return end
    local inst, _, here = instanceNow()
    if inst then fresh(c.run, inst, here) else c.run = nil end
    changed()
end

-- The encounter ids of a dungeon in the game's order (the facts' enc), or nil without them.
function R.Encounters(dkey)
    local f = R.Fact(dkey)
    return f and type(f.enc) == "table" and #f.enc > 0 and f.enc or nil
end

-- The run of dungeon dkey: killed (the set of encounter ids), n killed of m; nil when the
-- character's run is of another instance (or there is none) or the dungeon has no encounters.
function R.Of(dkey)
    local f, encs = R.Fact(dkey), R.Encounters(dkey)
    local run = charRun(false)
    if not f or not encs or not run or run.inst ~= f.inst then return nil end
    local n = 0
    for _, id in ipairs(encs) do
        if run.enc[id] then n = n + 1 end
    end
    return run.enc, n, #encs
end

-- The i-th boss of the game's order (the facts' order) of dungeon dkey killed in the run.
function R.Killed(dkey, i)
    local killed = R.Of(dkey)
    local encs = R.Encounters(dkey)
    return killed ~= nil and encs ~= nil and encs[i] ~= nil and killed[encs[i]] == true
end

-- Marks the i-th boss of dkey's order killed (on) or not by hand; only for the instance the
-- character stands in or its current run. Answers whether it could.
function R.Mark(dkey, i, on)
    local f, encs = R.Fact(dkey), R.Encounters(dkey)
    if not f or not encs or not encs[i] then return false end
    local run = charRun(true)
    if not run then return false end
    if run.inst ~= f.inst then
        if instanceNow() ~= f.inst then return false end
        fresh(run, f.inst, select(3, instanceNow()))
    end
    run.enc[encs[i]] = on and true or nil
    changed()
    return true
end

-- The client's "<instance> has been reset." (INSTANCE_RESET_SUCCESS) as a pattern: the instance's
-- name, or nil for another line.
local resetPattern
local function resetName(text)
    if not resetPattern and type(INSTANCE_RESET_SUCCESS) == "string" then
        -- every magic character escaped (the % of "%s" too), then the escaped "%s" as a capture
        local escaped = INSTANCE_RESET_SUCCESS:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        resetPattern = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
    end
    return resetPattern and type(text) == "string" and text:match(resetPattern) or nil
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then R.Migrate(AmisiaDB) end
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function(login, reload) R.Update(login, reload) end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() R.Update() end)
-- another floor of the instance
ns.OnEvent("ZONE_CHANGED", function() learnFloors(instanceNow()) end)
ns.OnEvent("ZONE_CHANGED_INDOORS", function() learnFloors(instanceNow()) end)
ns.OnEvent("ENCOUNTER_END", function(enc, _, _, _, success)
    if tonumber(ns.Plain(success)) == 1 then R.Kill(enc) end
end)
ns.OnEvent("BOSS_KILL", function(enc) R.Kill(enc) end)
ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    local name = resetName(ns.Plain(text))
    if name then R.Reset(name) end
end)
ns.OnEvent("PLAYER_LEAVING_WORLD", function() R.Leave() end)
end)
