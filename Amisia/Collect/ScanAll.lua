-- Amisia "Alles Fehlende scannen" (F-188, D-120, spec 2026-11-13-alles-scannen): one queue over the
-- scans of the tools page. It runs, one after the other, what is still open: the gear scan (the list
-- of the gear planner), the quest scan, phase A of the NPC scan, and at the end the items without an
-- answer ("Offene wiederholen"). What is open each scan says itself (ns.ScanGearOpen, QS.Open,
-- NS_.Open): not through, or through under another client build or other shipped lists (SB.Stamp).
-- Phase B of the NPC scan (the search for new NPCs by number, hours) is never part of it.
--
-- While the queue is on, a scan that an instance stopped goes on by itself a few seconds after the
-- character is out (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA), and a step that cannot start in
-- combat or the lockdown starts after it (PLAYER_REGEN_ENABLED, ENCOUNTER_END,
-- ADDON_RESTRICTION_STATE_CHANGED); never inside an instance. It follows the scans' own ends (the
-- internal event SCAN_ENDED, fired by Scan.lua, ScanQuests.lua, ScanNpcs.lua) and has no per-frame
-- work. A scan stopped by hand ("Anhalten", /amisia scan stop) ends the queue. The queue lives for
-- the session only: after /reload or a login the tools page offers it again with what is still open.
--
-- After a new client build (newer than the one the shipped lists come from, while the scans last
-- finished under another one) one chat line at login tells expert-mode users there is something new
-- to scan (setting tools.scanNotice); nothing starts by itself.
local ADDON, ns = ...
local L = ns.L
local SB = ns.ScanById

local SA = {}
ns.ScanAll = SA

SA.DELAY = 5            -- seconds after the reason went before a scan goes on
SA.NEXT = 1             -- seconds between two steps
SA.NOTICE_DELAY = 12    -- seconds after the login before the new-build line
SA.ORDER = { "gear", "quests", "npcs", "retry" }
SA.NAME = { gear = L["Ausrüstung"], quests = L["Quests"], npcs = L["NPCs"], retry = L["Offene Items"] }

local active      -- the queue runs (this session only)
local steps       -- the keys still to do, the current one first
local wait        -- why the current step waits: "instance", "combat", "lockdown", "busy" or nil
local gen = 0     -- the pending check's number (a newer one makes it void)
local told        -- the new-build line was said this session

local function refresh() if ns.Refresh then ns.Refresh() end end

local function scanDB() return AmisiaDB and type(AmisiaDB.scan) == "table" and AmisiaDB.scan or nil end

---------------------------------------------------------------------------
-- What is open
---------------------------------------------------------------------------
-- The gear scan: open while its list never went through under this build and these lists.
function ns.ScanGearOpen()
    if not (C_Item and C_Item.RequestLoadItemDataByID) or not ns.HasData("GEAR") then return false end
    local s = scanDB()
    return not (s and s.gear == SB.Stamp())
end

local OPEN = {
    gear = function() return ns.ScanGearOpen() end,
    quests = function() return ns.QuestScan.Open() end,
    npcs = function() return ns.NpcScan.Open() end,
    retry = function()
        local s = scanDB()
        return s ~= nil and type(s.retry) == "table" and #s.retry > 0
    end,
}

local START = {
    gear = function() return ns.ScanGear() end,
    quests = function() return ns.QuestScan.StartOpen() end,
    npcs = function() return ns.NpcScan.StartOpen() end,
    retry = function() return ns.ScanRetry() end,
}

local RUNNING = {
    gear = function() return ns.ScanRunning() end,
    quests = function() return ns.QuestScan.Running() end,
    npcs = function() return ns.NpcScan.Running() ~= nil end,
}
RUNNING.retry = RUNNING.gear

-- The keys that are open now, in order.
function SA.Open()
    local out = {}
    for _, key in ipairs(SA.ORDER) do
        if OPEN[key]() then out[#out + 1] = key end
    end
    return out
end

local function busy()
    return RUNNING.gear() or RUNNING.quests() or RUNNING.npcs()
end

-- Why nothing may start now: "combat", "lockdown", "instance" or nil.
local function reason()
    if SB.Blocked(false) then return InCombatLockdown() and "combat" or "lockdown" end
    if SB.Blocked(true) then return "instance" end
    return nil
end

-- The names of keys, "Ausrüstung, Quests"; the items without an answer only while there are any.
local function names(keys)
    local out = {}
    for _, key in ipairs(keys) do
        if key ~= "retry" or OPEN.retry() then out[#out + 1] = SA.NAME[key] end
    end
    return table.concat(out, ", ")
end

---------------------------------------------------------------------------
-- The queue
---------------------------------------------------------------------------
local go

local function later(seconds)
    gen = gen + 1
    local mine = gen
    C_Timer.After(seconds, function()
        if mine == gen then go() end
    end)
end

local function finished()
    active, steps, wait = nil, nil, nil
    gen = gen + 1
    ns.msg(L["Alles Fehlende scannen: fertig. Ausloggen oder /reload, damit es gespeichert wird."])
    refresh()
end

-- Starts the first step that is still open, or waits for its reason to go.
go = function()
    if not active then return end
    while steps[1] do
        local key = steps[1]
        if RUNNING[key]() then
            -- started by hand in its row meanwhile: its end moves the queue on
            wait = nil
            refresh()
            return
        end
        if not OPEN[key]() then
            table.remove(steps, 1)
        else
            local why = reason()
            if why then
                wait = why
                refresh()
                return
            end
            if busy() then
                wait = "busy"
                refresh()
                return
            end
            local ok, err = START[key]()
            if ok then
                wait = nil
                refresh()
                return
            end
            if err then ns.msg(err) end
            table.remove(steps, 1)
        end
    end
    finished()
end

function SA.Start()
    if active then return nil, L["Alles Fehlende scannen läuft schon."] end
    if busy() then return nil, L["Erst den laufenden Scan anhalten (/amisia scan stop)."] end
    local open = SA.Open()
    if #open == 0 then return nil, L["Nichts offen."] end
    -- the gear scan may leave items without an answer: they are asked again at the end
    if open[1] == "gear" and open[#open] ~= "retry" then open[#open + 1] = "retry" end
    active, steps, wait = true, open, nil
    ns.msg(L["Alles Fehlende scannen: %s, nacheinander. In Instanzen und im Kampf wartet es und geht danach von selbst weiter."]:format(names(open)))
    go()
    return true
end

-- Ends the queue (the scan that runs stays as it is: /amisia scan stop stops it too). Returns whether
-- it was on.
function SA.Stop()
    if not active then return false end
    active, steps, wait = nil, nil, nil
    gen = gen + 1
    ns.msg(L["Alles Fehlende scannen: angehalten. Was noch offen ist, startet erst, wenn du es wieder startest."])
    refresh()
    return true
end

function SA.Active() return active and true or false end

-- The queue for the tools page: { active, current, after = { keys }, running, wait, open = { keys } }
-- (open only while it is off).
function SA.State()
    if not active then return { active = false, open = SA.Open() } end
    local after = {}
    for i = 2, #steps do
        if steps[i] ~= "retry" or OPEN.retry() then after[#after + 1] = steps[i] end
    end
    local cur = steps[1]
    return { active = true, current = cur, after = after, running = cur ~= nil and RUNNING[cur]() or false, wait = wait }
end

-- The line of the tools page: the plan while it runs, else what is open.
function SA.PlanText()
    local st = SA.State()
    if not st.active then
        if #st.open == 0 then return L["Nichts offen."] end
        return L["Noch offen: %s."]:format(names(st.open))
    end
    local cur = SA.NAME[st.current] or ""
    if #st.after == 0 then
        return (st.running and L["Alles Fehlende: %s läuft, danach ist alles gescannt."] or L["Alles Fehlende: %s wartet, danach ist alles gescannt."]):format(cur)
    end
    return (st.running and L["Alles Fehlende: %s läuft, danach %s."] or L["Alles Fehlende: %s wartet, danach %s."]):format(cur, names(st.after))
end

-- The tools page's "Nächster Schritt" while the queue waits (nil while a step runs or it is off).
function SA.NextStep()
    local st = SA.State()
    if not st.active or st.running then return nil end
    local why = reason() or st.wait
    if why == "instance" then return L["Alles Fehlende geht außerhalb der Instanz von selbst weiter."] end
    if why == "combat" then return L["Alles Fehlende geht nach dem Kampf von selbst weiter."] end
    if why == "lockdown" then return L["Alles Fehlende geht nach der Kampfsperre von selbst weiter."] end
    if why == "busy" then return L["Alles Fehlende geht weiter, wenn der laufende Scan endet."] end
    return L["Alles Fehlende geht gleich von selbst weiter."]
end

-- A scan ended (Scan.lua, ScanQuests.lua, ScanNpcs.lua): run "gear", "retry", "list", "range",
-- "quests" or "npcs"; how "done", "instance", "stop", "fail" or nil.
ns.Listen("SCAN_ENDED", function(run, how)
    if not active then return end
    if how == "stop" then
        -- stopped by hand: nothing starts again against the player's will
        SA.Stop()
        return
    end
    if run ~= steps[1] then
        -- another scan ended (a step waited for it)
        if wait == "busy" then later(SA.NEXT) end
        return
    end
    if how == "instance" then
        -- out of the instance it goes on (PLAYER_ENTERING_WORLD)
        wait = "instance"
        refresh()
        return
    end
    -- through, or the client refused: the next step
    table.remove(steps, 1)
    wait = nil
    later(SA.NEXT)
end)

-- The reason may be gone: a check a few seconds later (never inside an instance: go() looks again).
local function maybeGoOn()
    if active and wait and not busy() then later(SA.DELAY) end
end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "ENCOUNTER_END",
                         "ADDON_RESTRICTION_STATE_CHANGED" }) do
    ns.OnEvent(event, maybeGoOn)
end

-- /amisia scan all [stop]
function SA.Command(rest)
    local word = (rest or ""):lower():match("^%s*(%S*)")
    if word == "stop" then
        ns.ScanCommand("stop")
        return
    end
    local ok, why = SA.Start()
    if not ok and why then ns.msg(why) end
end

---------------------------------------------------------------------------
-- A new client build
---------------------------------------------------------------------------
-- The stamps of the finished scans (gear list, quests, NPC phase A).
local function stamps()
    local s, out = scanDB(), {}
    if not s then return out end
    if type(s.gear) == "string" then out[#out + 1] = s.gear end
    for _, key in ipairs({ "quests", "npcs" }) do
        local q = s[key]
        if type(q) == "table" and type(q.stamp) == "string" then out[#out + 1] = q.stamp end
    end
    return out
end

-- Whether the client is newer than the shipped lists and the scans last finished under another build.
function SA.NewBuild()
    local now = SB.BuildNumber(SB.Build())
    local data = SB.BuildNumber(SB.ListsClient())
    if not now or not data or data >= now then return false end
    for _, st in ipairs(stamps()) do
        if SB.BuildNumber(st:match("^([^/]*)")) ~= now then return true end
    end
    return false
end

-- Scans that finished before stamps came (F-188) count as finished under this build and lists.
function SA.Adopt()
    local s = scanDB()
    if not s then return end
    local stamp = SB.Stamp()
    if s.done and s.gear == nil then s.gear = stamp end
    local q = type(s.quests) == "table" and s.quests or nil
    if q and q.done and q.stamp == nil then q.stamp = stamp end
    local n = type(s.npcs) == "table" and s.npcs or nil
    if n and n.doneA and n.stamp == nil and n.v == ns.NpcScan.LAYOUT then n.stamp = stamp end
end

-- The new-build line: expert mode, the setting on, once a session.
function SA.Notice()
    if told or not ns.Get("ui.expert") or not ns.Get("tools.scanNotice") or not SA.NewBuild() then return false end
    told = true
    ns.msg(L["Neuer Spiel-Build: es gibt Neues zu scannen (Gilde > Werkzeuge, \"Alles Fehlende scannen\")."])
    return true
end

ns.OnEvent("PLAYER_LOGIN", function()
    SA.Adopt()
    C_Timer.After(SA.NOTICE_DELAY, SA.Notice)
end)
