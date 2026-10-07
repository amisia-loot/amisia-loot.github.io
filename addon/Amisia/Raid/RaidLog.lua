-- Amisia raid log: the boss attempts of the running recording from the client's encounter events
-- (ENCOUNTER_START, ENCOUNTER_END, BOSS_KILL), with who stood in the instance at a kill. Without
-- those events a dead world boss whose corpse is looted counts as a kill, and officers can enter
-- a kill by hand. No combat log: neither client gives addons a usable one.
-- On Forever the raid roster may be secret during and right after a boss fight, so the names of
-- a kill are read once the encounter restriction has lifted (with a fallback to the roster
-- snapshots of the recording after 60 s).
local ADDON, ns = ...
local L = ns.L

local RESTRICTION_ENCOUNTER = 1   -- Enum.AddOnRestrictionType.Encounter
local SAME_FIGHT = 120            -- seconds: two kill events of one encounter this close are one kill
local LOOT_WINDOW = 600           -- seconds between a kill and the loot window of its corpse
local READ_FOR = 60               -- seconds to wait for a readable roster after a kill
local READ_FIRST = 1
local READ_EVERY = 2
local PULL_STALE = 15 * 60        -- an open attempt older than this is dropped on load (no fight running)
local PULL_DEAD = 2 * 3600        -- an open attempt older than this is always dropped on load
local TRACE_MAX = 20
local MAX_WHO = 40

local trace = {}      -- the last encounter events, only in memory, for /amisia log ereignisse
local waiting = {}    -- kills waiting for their names: { s, k, giveUp = GetTime() }
local polling = false
local poll

local function plainNumber(v) return tonumber(ns.Plain(v)) end
local function plainText(v)
    v = ns.Plain(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

local function remember(event, text)
    trace[#trace + 1] = { t = time(), event = event, text = text }
    while #trace > TRACE_MAX do table.remove(trace, 1) end
end

function ns.EncounterTrace()
    local out = {}
    for i, e in ipairs(trace) do out[i] = { t = e.t, event = e.event, text = e.text } end
    return out
end

-- The running recording while boss fights are tracked, else nil.
local function recording()
    local s = ns.Active and ns.Active()
    if not s or not ns.Get("raidlog.track") then return nil end
    s.kills = s.kills or {}
    return s
end

local function sortKills(s)
    table.sort(s.kills, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return (a.start or a.t) < (b.start or b.t)
    end)
end

local function insert(s, k)
    s.kills[#s.kills + 1] = k
    sortKills(s)
end

-- A kill header of s was added or changed ("kill+") or deleted ("kill-"): the sync hears of it.
local function synced(s, op, k)
    if ns.SyncNote then ns.SyncNote(op, s, { enc = k.enc, t = k.t, k = k }) end
end

---------------------------------------------------------------------------
-- Who was there
---------------------------------------------------------------------------
-- The raiders online in the recorder's zone as sorted full names (the rule of the roster snapshot);
-- nil while a name, a zone or an online flag of the roster is secret.
local function readPresent()
    local rows, me, here = {}, ns.UnitFullName("player"), nil
    for i = 1, GetNumGroupMembers() or 0 do
        local name, _, _, _, _, _, zone, online = GetRaidRosterInfo(i)
        local pName, pZone, pOnline = ns.Plain(name), ns.Plain(zone), ns.Plain(online)
        -- type() only: a secret value is never compared
        if (type(name) ~= "nil" and pName == nil) or (type(zone) ~= "nil" and pZone == nil)
            or (type(online) ~= "nil" and pOnline == nil) then
            return nil
        end
        local full = type(pName) == "string" and ns.FullName(pName)
        if full then
            rows[#rows + 1] = { name = full, zone = pZone, online = pOnline }
            if here == nil and ns.SameName(full, me) then here = pZone end
        end
    end
    local out, seen = {}, {}
    for _, r in ipairs(rows) do
        if r.online and (here == nil or r.zone == here) and not seen[r.name] then
            seen[r.name] = true
            out[#out + 1] = r.name
        end
    end
    table.sort(out)
    while #out > MAX_WHO do table.remove(out) end
    return out
end

-- The raiders of the minute snapshots seen between from and to.
local function membersAt(s, from, to)
    local out = {}
    for name, m in pairs(s.members or {}) do
        if (m.last or 0) >= from and (m.first or 0) <= to then out[#out + 1] = name end
    end
    table.sort(out)
    while #out > MAX_WHO do table.remove(out) end
    return out
end

-- readPresent that never fails: a roster read that errors counts as unreadable (nil).
local function presentSafe()
    local ok, p = pcall(readPresent)
    return ok and p or nil
end

-- The head count at the end of an attempt: readable raiders in the zone, else the snapshots.
local function countNow(s, start)
    local p = presentSafe()
    if p then return #p end
    return #membersAt(s, start - 60, time())
end

local function finish(k, who)
    k.who, k.n, k.wait = who, #who, nil
end

local function fallback(s, k)
    finish(k, membersAt(s, (k.start or k.t) - 60, k.t))
end

local function restricted()
    local api = _G.C_RestrictedActions
    local fn = type(api) == "table" and api.IsAddOnRestrictionActive
    if type(fn) ~= "function" then return false end
    local ok, on = pcall(fn, RESTRICTION_ENCOUNTER)
    return ok and ns.Plain(on) == true
end

local function tryRead()
    if #waiting == 0 then return end
    local names = (not restricted()) and presentSafe() or nil
    local now, keep, changed = GetTime(), {}, false
    for _, w in ipairs(waiting) do
        if not w.k.wait then
            -- read already, or deleted
        elseif w.s ~= ns.Active() then
            -- the recording ended: the snapshots stand in
            fallback(w.s, w.k)
            changed = true
        elseif names then
            finish(w.k, names)
            changed = true
        elseif now >= w.giveUp then
            fallback(w.s, w.k)
            changed = true
        else
            keep[#keep + 1] = w
        end
    end
    waiting = keep
    if changed then ns.Fire("DATA_CHANGED") end
    if #waiting > 0 then poll(READ_EVERY) end
end

poll = function(delay)
    if polling then return end
    polling = true
    C_Timer.After(delay, function()
        polling = false
        tryRead()
    end)
end

local function waitFor(s, k)
    k.wait = true
    waiting[#waiting + 1] = { s = s, k = k, giveUp = GetTime() + READ_FOR }
    poll(READ_FIRST)
end

-- The restriction changed: the state is only final after the dispatch.
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    if #waiting > 0 then C_Timer.After(0, tryRead) end
end)

---------------------------------------------------------------------------
-- Boss attempts from the encounter events
---------------------------------------------------------------------------
-- A kill of the same encounter within 120 s of t.
local function sameKill(s, enc, t)
    for _, k in ipairs(s.kills) do
        if k.ok and k.enc == enc and math.abs((k.t or 0) - t) <= SAME_FIGHT then return k end
    end
    return nil
end

-- A loot window kill the event at t stands for: looted at most 10 minutes before t, and not before
-- the start of the attempt when that is known.
local function lootKillBefore(s, t, start)
    local found
    for _, k in ipairs(s.kills) do
        if k.src == "loot" and k.ok and k.t <= t and t - k.t <= LOOT_WINDOW and (not start or k.t >= start) then
            found = k
        end
    end
    return found
end

local function eventText(enc, name, extra)
    return ("%s %s%s"):format(tostring(enc or "?"), name or L["(ohne Namen)"], extra or "")
end

ns.OnEvent("ENCOUNTER_START", function(enc, name, diff, size)
    enc, name, diff, size = plainNumber(enc), plainText(name), plainNumber(diff), plainNumber(size)
    local s = recording()
    remember("ENCOUNTER_START", eventText(enc, name, L[", %s Spieler, Schwierigkeit %s%s"]:format(tostring(size or "?"),
        tostring(diff or "?"), s and "" or L[" (nicht aufgezeichnet)"])))
    if s then s.encSeen = true end
    if not s or not enc then return end
    -- an open attempt of another encounter never saw its end
    s.pull = { enc = enc, name = ns.CleanNote(name) or ("Boss " .. enc), start = time(), size = size or 0, diff = diff or 0 }
    ns.Fire("DATA_CHANGED")
end)

ns.OnEvent("ENCOUNTER_END", function(enc, name, diff, size, success)
    enc, name, diff, size, success = plainNumber(enc), plainText(name), plainNumber(diff), plainNumber(size), plainNumber(success)
    local s = recording()
    local result = success == 1 and "Kill" or (success == 0 and "Wipe" or L["Ergebnis ?"])
    remember("ENCOUNTER_END", eventText(enc, name, ": " .. result .. (s and "" or L[" (nicht aufgezeichnet)"])))
    if s then s.encSeen = true end
    if not s or not enc then return end
    local t = time()
    local pull = (s.pull and s.pull.enc == enc) and s.pull or nil
    s.pull = nil
    local start = pull and pull.start or nil
    name = ns.CleanNote(name) or (pull and pull.name) or ("Boss " .. enc)
    size = size or (pull and pull.size) or 0
    diff = diff or (pull and pull.diff) or 0
    if success == 1 then
        local k = sameKill(s, enc, t)
        if k then
            -- BOSS_KILL came first: this event completes it; a second END adds nothing
            if k.src == "kill" then
                k.src, k.size, k.diff = "enc", size, diff
                if start then k.start = start end
                ns.Fire("DATA_CHANGED")
                synced(s, "kill+", k)
            end
            return
        end
        k = lootKillBefore(s, t, start)
        if k then
            -- the corpse was looted before the event arrived: the event names the fight
            k.enc, k.name, k.src, k.size, k.diff = enc, name, "enc", size, diff
            if start then k.start = math.min(start, k.t) end
            sortKills(s)
            ns.Fire("DATA_CHANGED")
            synced(s, "kill+", k)
            return
        end
        k = { enc = enc, name = name, start = start or t, t = t, ok = true, size = size, diff = diff, src = "enc",
              n = countNow(s, start or t) }
        insert(s, k)
        waitFor(s, k)
        ns.Fire("DATA_CHANGED")
        synced(s, "kill+", k)
        return
    else
        -- the same wipe twice (a second handler, a repeated event)
        for _, x in ipairs(s.kills) do
            if not x.ok and x.enc == enc and math.abs(x.t - t) <= 2 then return end
        end
        local k = { enc = enc, name = name, start = start or t, t = t, ok = false, size = size, diff = diff, src = "enc",
                    n = countNow(s, start or t) }
        insert(s, k)
        ns.Fire("DATA_CHANGED")
        synced(s, "kill+", k)
    end
end)

ns.OnEvent("BOSS_KILL", function(enc, name)
    enc, name = plainNumber(enc), plainText(name)
    local s = recording()
    remember("BOSS_KILL", eventText(enc, name, s and "" or L[" (nicht aufgezeichnet)"]))
    if s then s.encSeen = true end
    if not s or not enc then return end
    local t = time()
    if sameKill(s, enc, t) then return end
    local pull = (s.pull and s.pull.enc == enc) and s.pull or nil
    if pull then s.pull = nil end
    local start = pull and pull.start or nil
    name = ns.CleanNote(name) or (pull and pull.name) or ("Boss " .. enc)
    local k = lootKillBefore(s, t, start)
    if k then
        k.enc, k.name, k.src = enc, name, "kill"
        if start then k.start = math.min(start, k.t) end
        sortKills(s)
        ns.Fire("DATA_CHANGED")
        synced(s, "kill+", k)
        return
    end
    k = { enc = enc, name = name, start = start or t, t = t, ok = true, size = pull and pull.size or 0,
          diff = pull and pull.diff or 0, src = "kill", n = countNow(s, start or t) }
    insert(s, k)
    waitFor(s, k)
    ns.Fire("DATA_CHANGED")
    synced(s, "kill+", k)
end)

---------------------------------------------------------------------------
-- The loot window fallback: a dead world boss whose corpse is looted
---------------------------------------------------------------------------
-- Runs after Core's own LOOT_OPENED handler, so s.drops already holds this window.
ns.OnEvent("LOOT_OPENED", function()
    local s = recording()
    -- s.encSeen: this recording saw an encounter event, so the client reports its fights; the loot
    -- of a fight can come from a differently named creature much later, so no loot window kills
    if not s or not ns.Get("raidlog.lootKills") or s.encSeen then return end
    if type(UnitIsDead) ~= "function" or type(UnitClassification) ~= "function" or type(UnitGUID) ~= "function" then return end
    if ns.Plain(UnitIsDead("target")) ~= true then return end
    if ns.Plain(UnitClassification("target")) ~= "worldboss" then return end
    local name, guid = plainText(UnitName("target")), plainText(UnitGUID("target"))
    if not name or not guid then return end
    local d = s.drops and s.drops[guid]
    if type(d) ~= "table" or not d.t then return end
    name = ns.CleanNote(name)
    if not name then return end
    local low = name:lower()
    for _, k in ipairs(s.kills) do
        if k.ok then
            -- the same boss, or a kill shortly before (a fight's name differs from the creature's)
            if type(k.name) == "string" and k.name:lower() == low then return end
            if k.t <= d.t + 5 and d.t - k.t <= LOOT_WINDOW then return end
        end
    end
    local who = presentSafe() or membersAt(s, d.t - 60, d.t)
    local k = { enc = 0, name = name, start = d.t, t = d.t, ok = true, size = 0, diff = 0, src = "loot", who = who, n = #who }
    insert(s, k)
    remember("LOOT", name .. L[" (Lootfenster)"])
    ns.Fire("DATA_CHANGED")
    synced(s, "kill+", k)
end)

---------------------------------------------------------------------------
-- The raid log of a raid
---------------------------------------------------------------------------
-- The attempts of a raid sorted by end (a copy of the list, not of the entries).
function ns.Kills(s)
    local out = {}
    for i, k in ipairs((s and s.kills) or {}) do out[i] = k end
    table.sort(out, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return (a.start or a.t) < (b.start or b.t)
    end)
    return out
end

local function bossKey(k)
    if k.enc and k.enc ~= 0 then return "e" .. k.enc end
    return "n" .. tostring(k.name or ""):lower()
end
ns.BossKey = bossKey

-- Kills, wipes and the number of different bosses killed.
function ns.KillCount(s)
    local kills, wipes, bosses, seen = 0, 0, 0, {}
    for _, k in ipairs((s and s.kills) or {}) do
        if k.ok then
            kills = kills + 1
            local key = bossKey(k)
            if not seen[key] then
                seen[key] = true
                bosses = bosses + 1
            end
        else
            wipes = wipes + 1
        end
    end
    return kills, wipes, bosses
end

-- A kill or wipe by hand: { name, ok, t, start, enc }. Works on old raids too and never moves s.last.
function ns.AddKill(s, spec)
    if type(s) ~= "table" then return nil, L["Kein Raid."] end
    spec = type(spec) == "table" and spec or {}
    local name = ns.CleanNote(type(spec.name) == "string" and spec.name or nil)
    if not name then return nil, L["Name fehlt."] end
    s.kills = s.kills or {}
    local t = tonumber(spec.t) or time()
    local ok = spec.ok ~= false
    local k = { enc = tonumber(spec.enc) or 0, name = name, start = tonumber(spec.start) or t, t = t, ok = ok,
                size = 0, diff = 0, src = "hand" }
    local live = ns.Active and s == ns.Active()
    if ok then
        local who = live and (presentSafe() or membersAt(s, k.start - 60, t)) or {}
        k.who, k.n = who, #who
    else
        k.n = live and countNow(s, k.start) or 0
    end
    insert(s, k)
    ns.Fire("DATA_CHANGED")
    synced(s, "kill+", k)
    return k
end

function ns.DeleteKill(s, k)
    if type(s) ~= "table" or type(s.kills) ~= "table" then return nil end
    for i, x in ipairs(s.kills) do
        if x == k then
            table.remove(s.kills, i)
            k.wait = nil
            ns.Fire("DATA_CHANGED")
            synced(s, "kill-", k)
            return true
        end
    end
    return nil
end

-- The kill a loot source belongs to: a kill of that name, else the last kill at most 10 minutes
-- before the first loot window of that source. t (optional): the time of the hand-out.
function ns.KillFor(s, srcName, t)
    if type(s) ~= "table" or type(srcName) ~= "string" or srcName == "" then return nil end
    local low = srcName:lower()
    local byName
    for _, k in ipairs(ns.Kills(s)) do
        if k.ok and type(k.name) == "string" and k.name:lower() == low then
            if not byName or (t and k.t <= t) then byName = k end
        end
    end
    if byName then return byName end
    local drop
    for _, d in pairs(s.drops or {}) do
        if type(d) == "table" and d.src == srcName and d.t then
            if not drop then
                drop = d
            elseif t then
                -- the window opened last before the hand-out
                if d.t <= t and (drop.t > t or d.t > drop.t) then drop = d end
            elseif d.t < drop.t then
                drop = d
            end
        end
    end
    if not drop then return nil end
    local found
    for _, k in ipairs(ns.Kills(s)) do
        if k.ok and k.t <= drop.t and drop.t - k.t <= LOOT_WINDOW then found = k end
    end
    return found
end

-- On load: an open attempt of an earlier session is dropped when it is old, and a kill that still
-- waited for its names (a /reload right after it) takes the roster snapshots.
function ns.RaidLogLoaded()
    local api = _G.C_InstanceEncounter
    local inFight = false
    if type(api) == "table" and type(api.IsEncounterInProgress) == "function" then
        local ok, v = pcall(api.IsEncounterInProgress)
        inFight = ok and ns.Plain(v) == true
    end
    local now = time()
    for _, s in ipairs(ns.Sessions()) do
        s.kills = s.kills or {}
        local p = s.pull
        if type(p) ~= "table" then
            s.pull = nil
        else
            local age = now - (tonumber(p.start) or 0)
            if age > PULL_DEAD or (not inFight and age > PULL_STALE) then s.pull = nil end
        end
        for _, k in ipairs(s.kills) do
            if k.wait then fallback(s, k) end
            -- a recording from before s.encSeen existed
            if k.src == "enc" or k.src == "kill" then s.encSeen = true end
        end
    end
end

---------------------------------------------------------------------------
-- Settings and commands
---------------------------------------------------------------------------
-- Bench.lua adds its items to this section.
ns.RaidLogSettings = { key = "raidlog", label = L["Raid-Log"], order = 12, items = {
    { key = "raidlog.track", type = "toggle", label = L["Bosskämpfe aufzeichnen"], default = true,
      tip = L["Kills und Wipes mit Uhrzeit und Anwesenden."] },
    { key = "raidlog.lootKills", type = "toggle", label = L["Boss am Lootfenster erkennen"], default = true, expert = true,
      tip = L["Wenn der Client keine Kampfereignisse meldet."] },
}}
ns.RegisterSettings(ns.RaidLogSettings)

-- The running recording, else the newest raid.
local function newestRaid()
    local s = ns.Active and ns.Active()
    if s then return s end
    local list = ns.Sessions()
    return list[#list]
end
ns.NewestRaid = newestRaid

local function printLog(s)
    if not s then
        ns.msg(L["Noch kein Raid aufgezeichnet."])
        return
    end
    local kills, wipes = ns.KillCount(s)
    ns.msg(L["Raid-Log %s (%s): %d Kills, %d Wipes."]:format(s.zone or "?", s.date or "?", kills, wipes))
    for _, k in ipairs(ns.Kills(s)) do
        DEFAULT_CHAT_FRAME:AddMessage(("  %s %s, %s"):format(date("%H:%M", k.t), k.name or "?", k.ok and "Kill" or "Wipe"))
    end
end

ns.RegisterSlash("log", { aliases = { "raidlog" }, args = L["[ereignisse]"],
    desc = L["Raid-Log des Raids; \"ereignisse\" zeigt die letzten Kampfereignisse"], run = function(rest)
        local word = (rest or ""):lower():match("^%s*(%S*)")
        if word == "ereignisse" or word == "events" then   -- l10n-ok: typed sub-words, both work
            if #trace == 0 then
                ns.msg(L["Seit dem Laden kein Kampfereignis."])
                return
            end
            ns.msg(L["Letzte Kampfereignisse:"])
            for _, e in ipairs(trace) do
                DEFAULT_CHAT_FRAME:AddMessage(("  %s %s %s"):format(date("%H:%M:%S", e.t), e.event, e.text))
            end
        elseif ns.ShowRaidLog then
            ns.ShowRaidLog("verlauf")
        else
            printLog(newestRaid())
        end
    end })

ns.RegisterSlash("boss", { aliases = { "kill" }, officer = true, args = L["<Name> [wipe]"],
    desc = L["Bosskill oder Wipe von Hand eintragen"], run = function(rest)
        if not ns.IsOfficerView() then
            ns.msg(L["Bosse von Hand nur in der Offiziersansicht."])
            return
        end
        rest = (rest or ""):match("^%s*(.-)%s*$")
        local name, wipe = rest, false
        local head = rest:match("^(.-)%s+[Ww][Ii][Pp][Ee]$")
        if head then name, wipe = head, true end
        if name == "" or rest:lower() == "wipe" then
            ns.msg(L["Aufruf: /amisia boss <Name> [wipe]"])
            return
        end
        local s = newestRaid()
        if not s then
            ns.msg(L["Noch kein Raid aufgezeichnet."])
            return
        end
        local live = s == ns.Active()
        local k, why = ns.AddKill(s, { name = name, ok = not wipe, t = live and time() or (s.last or s.start) })
        if not k then
            ns.msg(why)
            return
        end
        ns.msg(L["%s eingetragen: %s (%s, %s)."]:format(wipe and "Wipe" or "Kill", k.name, s.zone or "?", s.date or "?"))

    end })
