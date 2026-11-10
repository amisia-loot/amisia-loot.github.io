-- Amisia NPC scan (/amisia scan npcs, spec 2026-11-10-quest-und-npc-scan, D-104): the names of NPCs by
-- their id, read from the tooltip of a creature link ("unit:Creature-0-0-0-0-<id>-0000000000") in the
-- client's language. Phase A asks for every NPC our data names (the list NA of Data/ScanLists.lua:
-- bosses, quest givers, vendors, rares, ...); phase B walks the id ranges where Forever's new NPCs live
-- (NB), to find the ids of NPCs we know only by name; it says up front how long it takes and asks
-- (W.Confirm). Only where the client answers: the probe's verdict (AmisiaDB.probe.npc), else a
-- mini-probe on three known ids first; without an answer it ends with one line. Throttled hard
-- (tools.npcRate per second, slower when known NPCs come back empty), one more ask after 1 s when no
-- name came, resumable, never in combat or in an instance.
--
-- AmisiaDB.scan.npcs = { loc, a (next index of NA), b (next id of phase B), n, at, doneA, doneB,
-- list = { [npcID] = "name\ttitle\trank\tkind" }, empty = ranges of ids that gave no name, v = 2 }.
-- tools/build_scan_archive.py keeps it in tools/scan_archive.json (per language);
-- Collect/ScanTrim.lua takes out what the archive holds.
local ADDON, ns = ...
local L = ns.L
local SB = ns.ScanById

local NS_ = {}
ns.NpcScan = NS_

NS_.LAYOUT = 2         -- the layout of a saved line (see NS_.DB)
NS_.RETRY = 1          -- seconds until the second ask of an id without a name
NS_.MINI_WAIT = { 1, 3 }   -- the mini-probe asks again after these seconds
NS_.MISS_BACKOFF = 5   -- known NPCs (phase A) empty in a row: half the rate, ask them once more
NS_.RECOVER = 50       -- names in a row before the rate goes up by one again
NS_.MIN_RATE = 1
NS_.REPORT_EVERY = { A = 250, B = 2000 }

local running        -- "A", "B", "mini" or nil
local ticker
local waiting = {}   -- id -> { at = time of the second ask }
local again = {}     -- ids of phase A to ask once more after a back-off
local asked2 = {}    -- ids already put into again
local misses = {}    -- the last empty ids of phase A in a row
local credit, rate, hits = 0, 5, 0
local nextReport

local function now() return GetTime() end

function NS_.DB()
    AmisiaDB.scan = AmisiaDB.scan or {}
    local s = AmisiaDB.scan
    local q = type(s.npcs) == "table" and s.npcs or {}
    if type(q.list) ~= "table" then q.list = {} end
    if type(q.empty) ~= "string" then q.empty = "" end
    if not ns.Int(q.a, 1) then q.a = 1 end
    if q.b ~= nil and not ns.Int(q.b, 1) then q.b = nil end
    if type(q.loc) ~= "string" then q.loc = nil end
    -- layout 2 (2.74.1): a line also holds the title without brackets, the rank and the kind; what
    -- an older scan left is asked again
    if q.v ~= NS_.LAYOUT then
        q.list, q.empty, q.a, q.b, q.doneA, q.doneB, q.n = {}, "", 1, nil, nil, nil, 0
        q.v = NS_.LAYOUT
    end
    -- counted once; the scan keeps it up to date, the trim sets it again
    if not ns.Int(q.n, 0) then q.n = ns.Count(q.list) end
    s.npcs = q
    return q
end

-- The name, title, rank and kind of an NPC now, or nil.
function NS_.Ask(id)
    local lines = SB.Lines(SB.NpcLink(id))
    return SB.NpcFrom(lines)
end

local function settingRate() return ns.Get("tools.npcRate") or 5 end

local function finish(why)
    local was = running
    running = nil
    if ticker then ticker:Cancel(); ticker = nil end
    local q = NS_.DB()
    -- the ids waiting for their second ask are asked again on the next start
    for id, w in pairs(waiting) do
        if was == "A" and w.index and w.index < q.a then q.a = w.index end
        if was == "B" and q.b and id < q.b then q.b = id end
    end
    waiting, again, misses = {}, {}, {}
    if SB.Busy() == "npcs" then SB.SetBusy(nil) end
    q.at = time()
    if why and was ~= "mini" then
        ns.msg(L["NPC-Scan %s: %d Namen gespeichert, %d Nummern ohne Namen."]:format(why, q.n, SB.RangesCount(q.empty)))
    end
    if ns.Refresh then ns.Refresh() end
end

-- "name\ttitle\trank\tkind", the empty ones at the end left out.
local function store(id, name, sub, rank, kind)
    local q = NS_.DB()
    if not q.list[id] then q.n = q.n + 1 end
    local f = { name, sub or "", rank or "", kind or "" }
    while #f > 1 and f[#f] == "" do f[#f] = nil end
    q.list[id] = table.concat(f, "\t")
end

-- An id without a name after the second ask: remembered as empty; in phase A, known NPCs empty in a
-- row slow the scan down and are asked once more.
local function empty(id, phase)
    local q = NS_.DB()
    q.empty = SB.AddToRanges(q.empty, id)
    hits = 0
    if phase ~= "A" then return end
    misses[#misses + 1] = id
    if #misses >= NS_.MISS_BACKOFF then
        rate = math.max(NS_.MIN_RATE, rate / 2)
        for _, m in ipairs(misses) do
            if not asked2[m] then asked2[m] = true; again[#again + 1] = m end
        end
        misses = {}
    end
end

local function named(id, name, sub, rank, kind)
    store(id, name, sub, rank, kind)
    misses = {}
    hits = hits + 1
    if hits >= NS_.RECOVER and rate < settingRate() then
        rate = math.min(settingRate(), rate + 1)
        hits = 0
    end
end

-- The next id of the running phase, or nil when it is through.
local function nextId(q)
    if running == "A" then
        if #again > 0 then return table.remove(again, 1), true end
        local list = SB.List("NA") or {}
        local id = list[q.a]
        if not id then return nil end
        q.a = q.a + 1
        return id
    end
    local ranges = SB.RangesB() or {}
    local b = q.b or (ranges[1] and ranges[1][1])
    for _, r in ipairs(ranges) do
        if b <= r[2] then
            if b < r[1] then b = r[1] end
            q.b = b + 1
            return b
        end
    end
    q.b = b
    return nil
end

local function remaining(q)
    if running == "A" or (not running and not q.doneA) then
        local list = SB.List("NA") or {}
        return math.max(0, #list - q.a + 1) + #again
    end
    local ranges = SB.RangesB() or {}
    local b, n = q.b or (ranges[1] and ranges[1][1]) or 0, 0
    for _, r in ipairs(ranges) do
        if b <= r[2] then n = n + r[2] - math.max(b, r[1]) + 1 end
    end
    return n
end

-- Seconds for n ids at the rate r: an id without a name costs two asks (phase B: most of them).
local function estimate(n, r, phase)
    return n * (phase == "B" and 2 or 1.2) / math.max(r, 0.1)
end
NS_.Estimate = estimate

local function tick()
    if not running then return end
    if SB.Blocked(false) then return end
    if SB.Blocked(true) then finish(L["pausiert in der Instanz"]) return end
    local q = NS_.DB()
    local t = now()
    credit = credit + rate / 10
    -- second asks first, in id order (the empty ranges stay joined)
    local due = {}
    for id, w in pairs(waiting) do
        if t >= w.at then due[#due + 1] = id end
    end
    table.sort(due)
    for _, id in ipairs(due) do
        if credit < 1 then break end
        waiting[id] = nil
        credit = credit - 1
        local name, sub, rank, kind = NS_.Ask(id)
        if name then named(id, name, sub, rank, kind) else empty(id, running) end
    end
    while credit >= 1 do
        local id, repeated = nextId(q)
        if not id then break end
        credit = credit - 1
        if not q.list[id] then
            local name, sub, rank, kind = NS_.Ask(id)
            if name then
                named(id, name, sub, rank, kind)
            else
                waiting[id] = { at = t + NS_.RETRY, index = (running == "A" and not repeated) and q.a - 1 or nil }
            end
        end
        if (running == "A" and q.a > nextReport) or (running == "B" and (q.b or 0) > nextReport) then
            nextReport = nextReport + NS_.REPORT_EVERY[running]
            ns.msg(NS_.Status())
            if ns.Refresh then ns.Refresh() end
        end
    end
    if credit > 1 then credit = 1 end
    if not next(waiting) and #again == 0 and remaining(q) == 0 then
        if running == "A" then
            q.doneA = time()
            local _, nb = SB.RangesB()
            finish(L["Phase A fertig"])
            if nb and nb > 0 and not q.doneB then
                ns.msg(L["Phase B (neue NPCs suchen, %d Nummern, bis zu %s): /amisia scan npcs"]:format(nb, SB.Duration(estimate(remaining(q), settingRate(), "B"))))
            end
        else
            q.doneB = time()
            finish(L["fertig"])
        end
    end
end

local function startPhase(phase)
    local q = NS_.DB()
    waiting, again, asked2, misses = {}, {}, {}, {}
    credit, hits = 0, 0
    rate = settingRate()
    running = phase
    SB.SetBusy("npcs")
    nextReport = phase == "A" and (math.floor(q.a / NS_.REPORT_EVERY.A) + 1) * NS_.REPORT_EVERY.A
        or ((q.b or 0) + NS_.REPORT_EVERY.B)
    ticker = C_Timer.NewTicker(0.1, tick)
    local n = remaining(q)
    ns.msg(L["NPC-Scan Phase %s gestartet: %d Nummern, %d pro Sekunde, bis zu %s. /amisia scan npcs stop hält an."]:format(
        phase, n, rate, SB.Duration(estimate(n, rate, phase))))
    if ns.Refresh then ns.Refresh() end
end

-- The mini-probe: three NPCs of the list, asked at once and again after 1 and 3 s. done(true) when
-- one of them gave a name.
function NS_.MiniProbe(done)
    local list = SB.List("NA") or {}
    local ids = {}
    for i = 1, math.min(3, #list) do ids[i] = list[i] end
    running = "mini"
    SB.SetBusy("npcs")
    local function try(when)
        if running ~= "mini" then return end
        for _, id in ipairs(ids) do
            if NS_.Ask(id) then
                running = nil
                SB.SetBusy(nil)
                SB.SaveProbe({ npc = when == 0 and "ok" or "retry" }, "mini")
                done(true)
                return true
            end
        end
        return false
    end
    if try(0) then return end
    for i, wait in ipairs(NS_.MINI_WAIT) do
        C_Timer.After(wait, function()
            if running ~= "mini" or try(wait) then return end
            if i == #NS_.MINI_WAIT then
                running = nil
                SB.SetBusy(nil)
                SB.SaveProbe({ npc = "none" }, "mini")
                done(false)
            end
        end)
    end
end

-- Whether a start is possible now: true, or nil and why.
local function ready()
    if running then return nil, L["Der NPC-Scan läuft schon. /amisia scan npcs stop hält ihn an."] end
    local busy = SB.Busy() or (ns.ScanRunning and ns.ScanRunning() and "items")
    if busy then return nil, L["Erst den laufenden Scan anhalten (/amisia scan stop)."] end
    local why = SB.Blocked(true)
    if why then return nil, L["Der NPC-Scan läuft nicht %s."]:format(why) end
    local list = SB.List("NA")
    if not list or #list == 0 then return nil, L["Diese Version hat keine Liste der NPCs (Data/ScanLists.lua)."] end
    if SB.Verdict("npc") == "none" then return nil, L["Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet."] end
    local q = NS_.DB()
    local loc = SB.Locale()
    if q.loc and q.loc ~= loc and next(q.list) then
        return nil, L["Es warten noch %d NPC-Namen in %s auf den nächsten Datenbau; erst danach in einer anderen Sprache scannen."]:format(q.n, q.loc)
    end
    if q.loc ~= loc then q.a, q.b, q.doneA, q.doneB, q.empty = 1, nil, nil, nil, "" end
    q.loc = loc
    return true
end

-- Phase B after the question (the estimate up front). Returns the question window.
function NS_.AskB()
    local q = NS_.DB()
    local ranges, nb = SB.RangesB()
    if not ranges or nb == 0 then
        ns.msg(L["Diese Version hat keine Bereiche für Phase B."])
        return nil
    end
    local left = remaining({ a = q.a, b = q.b, doneA = true })
    return ns.W.Confirm(L["NPC-Scan Phase B"],
        L["Phase B fragt %d Nummern in %d Bereichen ab, um neue NPCs von Forever zu finden. Bei %d pro Sekunde dauert das bis zu %s; anhalten (/amisia scan npcs stop) und fortsetzen geht jederzeit, nur nicht im Kampf und in Instanzen. Starten?"]:format(
            left, #ranges, settingRate(), SB.Duration(estimate(left, settingRate(), "B"))),
        L["Starten"], function()
            local ok, why = ready()
            if not ok then ns.msg(why) return end
            startPhase("B")
        end)
end

-- /amisia scan npcs: the mini-probe where no verdict is there, then phase A, or the question for B.
function NS_.Start()
    local ok, why = ready()
    if not ok then return nil, why end
    local q = NS_.DB()
    local function go()
        if not q.doneA then
            startPhase("A")
        elseif not q.doneB then
            NS_.AskB()
        else
            ns.msg(NS_.Status())
        end
    end
    if SB.Verdict("npc") then
        go()
    else
        ns.msg(L["NPC-Scan: erst eine kurze Probe mit drei bekannten NPCs ..."])
        NS_.MiniProbe(function(answered)
            if answered then go() else ns.msg(L["Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet."]) end
        end)
    end
    return true
end

function NS_.Running() return running end

function NS_.Stop()
    if running == "mini" then
        running = nil
        SB.SetBusy(nil)
    elseif running then
        finish(L["angehalten"])
    end
end

function NS_.Status()
    local q = AmisiaDB and AmisiaDB.scan and type(AmisiaDB.scan.npcs) == "table" and AmisiaDB.scan.npcs or nil
    local list = SB.List("NA")
    local _, nb = SB.RangesB()
    if not q or (q.a == 1 and not q.b and not q.doneA and not running) then
        return L["NPC-Scan: noch nicht gelaufen (Phase A %d NPCs, Phase B %d Nummern)."]:format(list and #list or 0, nb or 0)
    end
    local n = q.n or ns.Count(q.list or {})
    if running == "A" or running == "B" then
        local left = remaining(q)
        return L["NPC-Scan Phase %s läuft: %d Namen, noch %d Nummern, etwa %s."]:format(running, n, left, SB.Duration(estimate(left, rate, running)))
    end
    if q.doneA and q.doneB then return L["NPC-Scan fertig: %d Namen gespeichert."]:format(n) end
    if q.doneA then return L["NPC-Scan: Phase A fertig, %d Namen; Phase B offen."]:format(n) end
    return L["NPC-Scan angehalten: Phase A %d von %d, %d Namen."]:format(q.a - 1, list and #list or 0, n)
end

-- /amisia scan npcs [stop|status]
function NS_.Command(rest)
    local word = (rest or ""):lower():match("^%s*(%S*)")
    if word == "stop" then
        NS_.Stop()
    elseif word == "status" then
        ns.msg(NS_.Status())
    else
        local ok, why = NS_.Start()
        if not ok and why then ns.msg(why) end
    end
end
