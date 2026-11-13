-- Amisia item scan: asks the client for every item id in a range, throttled, and keeps what
-- exists. The result feeds tools/build_scan.py, which reads the SavedVariables file.
local ADDON, ns = ...
local L = ns.L

local MAX_PENDING = 200
local TIMEOUT = 6
local MAX_TRIES = 3
local DEFAULT_TO = 250000
local DEFAULT_RATE = 100
local REPORT_EVERY = 5000

local running = false
local ticker
local pending, pendingCount = {}, 0
local clock = 0
local nextReport
local queue   -- ids from the retry list while /amisia scan retry runs, else nil
local savedRate   -- the rate to put back after a retry run
local listTotal, listKind   -- the ids of a list run (gear list, retry) and its kind ("list", "retry")
local pausedIn    -- the last run ended because the character entered an instance
local gearRun     -- the list run is the gear scan (/amisia scan gear; F-188 stamps it when through)
local added = 0   -- new lines and notes since the addon loaded (item scan, quest and NPC scans, collector)

local GetItemInfoAny = C_Item.GetItemInfo
local GetItemInfoInstantAny = C_Item.GetItemInfoInstant
local request = C_Item and C_Item.RequestLoadItemDataByID

local function now()
    return GetTime and GetTime() or clock
end

local function scanDB()
    AmisiaDB.scan = AmisiaDB.scan or {}
    local s = AmisiaDB.scan
    s.items = s.items or {}
    s.retry = s.retry or {}
    -- a retry run slows the rate down until it ends; keep that instead of the setting
    if not savedRate then s.rate = ns.Get("tools.scanRate") or DEFAULT_RATE end
    s.count = s.count or 0
    return s
end

local function inInstance()
    local _, kind = GetInstanceInfo()
    return kind == "raid" or kind == "party"
end

-- The client's stats of a weapon or armour piece, as "KEY=value;..." with the ITEM_MOD_ prefix cut
-- off: the gear planner's build reads them, so the planner needs no loading in game. The second
-- value: whether there is nothing more to ask (not gear, or the client gave its stats table, an empty
-- one for a shirt or a tabard); false while the client has no stats for it yet.
local function statText(id, classID)
    local getStats = C_Item.GetItemStats
    if (classID ~= 2 and classID ~= 4) or not getStats then return "", true end
    local raw = getStats("item:" .. id)
    if type(raw) ~= "table" then return "", false end
    local parts = {}
    for k, v in pairs(raw) do
        if type(v) == "number" and v ~= 0 then
            parts[#parts + 1] = tostring(k):gsub("^ITEM_MOD_", "") .. "=" .. tostring(v)
        end
    end
    table.sort(parts)
    return table.concat(parts, ";"), true
end

local function store(id)
    id = tonumber(id)
    if not id then return false end
    local name, _, q, ilvl, minLevel, _, _, _, equipLoc, icon, _, classID, subclassID, bindType = GetItemInfoAny(id)
    if not name then return false end
    if GetItemInfoInstantAny and (not icon or not classID) then
        local _, _, _, loc, ico, cls, sub = GetItemInfoInstantAny(id)
        equipLoc, icon, classID, subclassID = equipLoc or loc, icon or ico, classID or cls, subclassID or sub
    end
    local s = scanDB()
    if not s.items[id] then s.count = s.count + 1; added = added + 1 end
    local fields = {
        (name:gsub("[\t\n]", " ")), tostring(q or 0), tostring(ilvl or 0), tostring(minLevel or 0),
        tostring(classID or ""), tostring(subclassID or ""), tostring(equipLoc or ""), tostring(icon or ""), tostring(bindType or ""),
    }
    -- a tenth field with the stats, only for gear
    local st, settled = statText(id, tonumber(classID))
    if st ~= "" then fields[#fields + 1] = st end
    s.items[id] = table.concat(fields, "\t")
    return true, settled
end
ns.StoreItem = store
ns.ScanDB = scanDB

-- New entries this session (F-186): the SavedVariables are written at logout and /reload only, so the
-- tools page says how many wait for that. The quest and NPC scans and the collector count here too.
function ns.ScanAdded(n) added = added + (n or 1) end
function ns.ScanAddedCount() return added end

-- how a run ended: "done" (everything asked), "instance" (paused by an instance), "stop" (stopped by
-- hand), nil (else). Fires SCAN_ENDED with the run ("gear", "retry", "list", "range") and how (F-188).
local function finish(why, how)
    local run = gearRun and "gear" or (queue and listKind) or "range"
    running = false
    queue, listTotal, listKind, gearRun = nil, nil, nil, nil
    pausedIn = how == "instance" or nil
    if savedRate then scanDB().rate = savedRate; savedRate = nil end
    if ticker then ticker:Cancel(); ticker = nil end
    pending, pendingCount = {}, 0
    local s = scanDB()
    s.at = time()
    s.done = how == "done" and s.at or nil
    -- the gear list asked through: stamped with the build (F-188, "Alles Fehlende scannen")
    if how == "done" and run == "gear" and ns.ScanById then s.gear = ns.ScanById.Stamp() end
    ns.msg(L["Scan %s: %d Items gespeichert, nächste ID %d, %d offen zum Wiederholen."]:format(why or L["beendet"], s.count, s.next or 0, #s.retry))
    if ns.Refresh then ns.Refresh() end
    ns.Fire("SCAN_ENDED", run, how)
end

local function send(id, tries)
    pending[id] = { sent = now(), tries = tries }
    request(id)
end

local function tick()
    local s = scanDB()
    if not running then return end
    if InCombatLockdown() then return end
    if inInstance() then finish(L["pausiert in der Instanz"], "instance") return end
    if not GetTime then clock = clock + 0.1 end
    local t = now()
    for id, p in pairs(pending) do
        if t - p.sent > TIMEOUT then
            if p.tries < MAX_TRIES then
                send(id, p.tries + 1)
            else
                pending[id] = nil
                pendingCount = pendingCount - 1
                s.retry[#s.retry + 1] = id
            end
        end
    end
    local batch = math.max(1, math.floor(s.rate / 10))
    if queue then
        while batch > 0 and pendingCount < MAX_PENDING and #queue > 0 do
            -- an id twice in the list (parked by two scans of one range) is asked once: a second
            -- count would never come down and the scan would never end
            local id = table.remove(queue, 1)
            if not pending[id] then
                send(id, 1)
                pendingCount = pendingCount + 1
                batch = batch - 1
            end
        end
        if #queue == 0 and pendingCount == 0 then finish(L["fertig"], "done") end
        return
    end
    while batch > 0 and pendingCount < MAX_PENDING and s.next <= s.to do
        -- an id the client's own data does not know needs no server request
        local exists = C_Item and C_Item.DoesItemExistByID
        if not exists or exists(s.next) then
            send(s.next, 1)
            pendingCount = pendingCount + 1
        end
        s.next = s.next + 1
        batch = batch - 1
        if s.next > nextReport then
            nextReport = nextReport + REPORT_EVERY
            ns.msg(L["Scan: ID %d von %d, %d Items."]:format(s.next - 1, s.to, s.count))
            if ns.Refresh then ns.Refresh() end
        end
    end
    if s.next > s.to and pendingCount == 0 then finish(L["fertig"], "done") end
end

local function onResult(id, success)
    id = tonumber(id)
    if not running or not id or not pending[id] then return end
    pending[id] = nil
    pendingCount = pendingCount - 1
    if success ~= false then
        if not store(id) then
            local s = scanDB()
            s.retry[#s.retry + 1] = id
        end
    end
    local s = scanDB()
    if pendingCount == 0 and ((queue and #queue == 0) or (not queue and s.next > s.to)) then finish(L["fertig"], "done") end
end
ns.OnEvent("ITEM_DATA_LOAD_RESULT", onResult)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", onResult)

function ns.ScanRunning() return running end

-- Why no item run may start now, or nil: one runs, a scan by id runs (D-104: one scan at a time),
-- an instance.
local function blocked()
    if running then return L["Der Scan läuft schon. /amisia scan stop hält ihn an."] end
    if ns.ScanById and ns.ScanById.Busy() then return L["Erst den laufenden Scan anhalten (/amisia scan stop)."] end
    if inInstance() then return L["Der Scan läuft nur außerhalb von Instanzen."] end
    return nil
end

local function startList(ids, kind)
    queue, listTotal, listKind = ids, #ids, kind
    pausedIn = nil
    scanDB().done = nil
    pending, pendingCount = {}, 0
    nextReport = math.huge
    running = true
end

function ns.ScanStart(from, to)
    if not request then return nil, L["Dieser Client kann keine Items nachladen."] end
    local why = blocked()
    if why then return nil, why end
    local s = scanDB()
    -- a resume (no start given) keeps the range's start, so its progress counts the whole range
    local first = tonumber(s.from)
    local resume = not tonumber(from) and not tonumber(to) and first and s.next and s.to and first <= s.next and s.next <= s.to
    from = tonumber(from) or s.next or 1
    to = tonumber(to) or s.to or DEFAULT_TO
    if from < 1 or to < from then return nil, L["Bereich prüfen: /amisia scan <von> <bis>"] end
    s.from, s.to, s.next = math.floor(resume and first or from), math.floor(to), math.floor(from)
    s.done, pausedIn = nil, nil
    pending, pendingCount = {}, 0
    nextReport = (math.floor(s.next / REPORT_EVERY) + 1) * REPORT_EVERY
    running = true
    ticker = C_Timer.NewTicker(0.1, ns.Perf.Wrap("Ticker Scan items", tick))
    ns.msg(L["Scan gestartet: ID %d bis %d, %d Anfragen pro Sekunde. /amisia scan stop hält an."]:format(s.from, s.to, s.rate))
    if ns.Refresh then ns.Refresh() end
    return true
end

-- Asks again for every id that got no usable answer, at a quarter of the rate.
function ns.ScanRetry()
    if not request then return nil, L["Dieser Client kann keine Items nachladen."] end
    local why = blocked()
    if why then return nil, why end
    local s = scanDB()
    if #s.retry == 0 then return nil, L["Keine offenen IDs."] end
    startList(s.retry, "retry")
    s.retry = {}
    local slow = math.max(10, math.floor(s.rate / 4))
    savedRate = s.rate
    s.rate = slow
    ticker = C_Timer.NewTicker(0.1, ns.Perf.Wrap("Ticker Scan items", tick))
    ns.msg(L["Wiederholung gestartet: %d IDs mit %d Anfragen pro Sekunde."]:format(#queue, slow))
    return true
end

-- Scans a list of ids, e.g. everything the gear planner lists plus what its sources name but no scan
-- has seen yet (items Forever only reveals later).
function ns.ScanList(ids, label, gear)
    if not request then return nil, L["Dieser Client kann keine Items nachladen."] end
    local why = blocked()
    if why then return nil, why end
    if not ids or #ids == 0 then return nil, L["Keine IDs zu scannen."] end
    local s = scanDB()
    local copy = {}
    for i = 1, #ids do copy[i] = ids[i] end
    startList(copy, "list")
    gearRun = gear and true or nil
    ticker = C_Timer.NewTicker(0.1, ns.Perf.Wrap("Ticker Scan items", tick))
    ns.msg(L["%s: %d IDs mit %d Anfragen pro Sekunde. Danach ausloggen, damit die Datei geschrieben wird."]:format(label or "Scan", #ids, s.rate))
    return true
end

-- The ids the gear planner wants scanned: its items and the ones its sources name but lack.
function ns.GearScanIDs()
    local d = ns.Data("GEAR")
    if not d then return nil end
    local ids = {}
    for id in pairs(d.I) do ids[#ids + 1] = id end
    for _, id in ipairs(d.M or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- The gear scan (/amisia scan gear): every id the gear planner lists. Returns true, or nil and why.
function ns.ScanGear()
    local ids = ns.GearScanIDs()
    if not ids then return nil, L["Die Ausrüstungstabelle gibt es nur in WoW Forever."] end
    return ns.ScanList(ids, L["Ausrüstungs-Scan"], true)
end

function ns.ScanStop()
    if not running then return end
    finish(L["angehalten"], "stop")
end

-- The item scan's progress for the tools page (F-186): { running, kind ("range", "list", "retry"),
-- done, total (the ids this run asks: its range or its list; nil when unknown), seconds (left at the
-- rate), resumable (a range not through), finished (the last run asked everything), pausedIn, items
-- (lines waiting in the file), retry (ids to ask again) }.
function ns.ScanProgress()
    local s = AmisiaDB and AmisiaDB.scan or {}
    local rate = math.max(tonumber(s.rate) or DEFAULT_RATE, 1)
    local p = { running = running, pausedIn = pausedIn, items = tonumber(s.count) or 0,
                retry = type(s.retry) == "table" and #s.retry or 0, finished = s.done ~= nil }
    local from, to, nxt = tonumber(s.from), tonumber(s.to), tonumber(s.next)
    local rangeOpen = from and to and nxt and to >= from and nxt <= to
    if running and queue then
        p.kind, p.total = listKind, listTotal
        local left = #queue + pendingCount
        p.done = math.max(0, (listTotal or 0) - left)
        p.seconds = left / rate
    elseif running or rangeOpen then
        -- the range asks every id from its start to its end (ids the client knows to be missing cost
        -- no request, but a place in the batch all the same)
        p.kind, p.total = "range", to - from + 1
        p.done = math.max(0, math.min(p.total, nxt - from))
        p.seconds = (p.total - p.done) / rate
        p.resumable = not running
    end
    return p
end

function ns.ScanStatus()
    local s = AmisiaDB and AmisiaDB.scan
    if not s or not s.next then
        return L["Noch kein Scan. /amisia scan <von> <bis> startet einen. %d Items gesammelt."]:format(s and s.count or 0)
    end
    if running then
        return L["Scan läuft: ID %d von %d, %d Items."]:format(s.next - 1, s.to, s.count or 0)
    end
    return L["Scan: %d Items, nächste ID %d von %d%s%s."]:format(s.count or 0, s.next, s.to or 0,
        (#(s.retry or {}) > 0) and L[", %d offen"]:format(#s.retry) or "",
        ns.CollectCount and L[", %d Quellen gesammelt"]:format(ns.CollectCount()) or "")
end

function ns.ScanCommand(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    local word, arg = rest:match("^(%S*)%s*(.*)$")
    word = (word or ""):lower()
    if word == "stop" then
        -- every scan: items, quests, NPCs; and "Alles Fehlende scannen" (first, so it starts nothing)
        if ns.ScanAll then ns.ScanAll.Stop() end
        ns.ScanStop()
        if ns.QuestScan then ns.QuestScan.Stop() end
        if ns.NpcScan then ns.NpcScan.Stop() end
    elseif word == "quests" or word == "quest" then   -- l10n-ok: typed sub-words
        if ns.QuestScan then ns.QuestScan.Command(arg) else ns.msg(L["Den Quest-Scan gibt es nur in WoW Forever."]) end
    elseif word == "npcs" or word == "npc" then   -- l10n-ok: typed sub-words
        if ns.NpcScan then ns.NpcScan.Command(arg) else ns.msg(L["Den NPC-Scan gibt es nur in WoW Forever."]) end
    elseif word == "retry" then
        local ok, why = ns.ScanRetry()
        if not ok and why then ns.msg(why) end
    elseif word == "status" then
        ns.msg(ns.ScanStatus())
    elseif word == "aufräumen" or word == "aufraeumen" or word == "cleanup" then   -- l10n-ok: typed sub-words
        if ns.ScanTrimNow then ns.ScanTrimNow() end
    elseif word == "gear" then
        local ok, why = ns.ScanGear()
        if not ok and why then ns.msg(why) end
    elseif word == "all" or word == "alles" then   -- l10n-ok: typed sub-words
        if ns.ScanAll then ns.ScanAll.Command(arg) end
    elseif word == "rate" then
        if ns.Set("tools.scanRate", tonumber(arg)) then
            scanDB()
            ns.msg(L["Scan-Rate: %d Anfragen pro Sekunde."]:format(ns.Get("tools.scanRate")))
        else
            ns.msg(L["Aufruf: /amisia scan rate <10-1000>"])
        end
    else
        local from, to = rest:match("^(%d+)%s+(%d+)$")
        if not from and rest ~= "" then
            ns.msg(L["Aufruf: /amisia scan [<von> <bis>] | gear | quests | npcs | all | retry | aufräumen | stop | status | rate <n>"])
            return
        end
        local ok, why = ns.ScanStart(from and tonumber(from), to and tonumber(to))
        if not ok and why then ns.msg(why) end
    end
end

ns.RegisterSettings{ key = "tools", label = L["Werkzeuge"], order = 95, group = "amisia", pages = { "tools" }, expert = true, items = {
    { key = "tools.collect", type = "toggle", label = L["Item-Sammler"], default = true,
      tip = L["Merkt sich Items aus Taschen, Händlern, Quests, Auktionshaus, Tooltips und Loot mit ihrer Quelle."] },
    { key = "tools.scanRate", type = "slider", label = L["Scan-Rate (Anfragen pro Sekunde)"], default = 100, min = 10, max = 1000, step = 10, tip = L["So viele Items fragt /amisia scan pro Sekunde beim Spiel an. Weniger ist schonender."] },
    { key = "tools.questRate", type = "slider", label = L["Quest-Scan (Abfragen pro Sekunde)"], default = 20, min = 5, max = 50, step = 5,
      tip = L["So viele Quests fragt /amisia scan quests pro Sekunde beim Spiel an; kommen Antworten zu spät, wird der Scan von selbst langsamer."] },
    { key = "tools.npcRate", type = "slider", label = L["NPC-Scan (Abfragen pro Sekunde)"], default = 5, min = 1, max = 20, step = 1,
      tip = L["So viele NPC-Tooltips liest /amisia scan npcs pro Sekunde; bleiben bekannte NPCs leer, wird der Scan von selbst langsamer."] },
    { key = "tools.scanAutotrim", type = "toggle", label = L["Ausgewertete Scan-Daten beim Login entfernen"], default = true,
      tip = L["Was der Datenbau schon übernommen hat, fliegt ein paar Sekunden nach dem Login aus der gespeicherten Datei; nur Neues bleibt. /amisia scan aufräumen macht es sofort."] },
    { key = "tools.scanNotice", type = "toggle", label = L["Neuen Spiel-Build melden"], default = true,
      tip = L["Nach einem neuen Spiel-Build sagt eine Chatzeile beim Login, dass es Neues zu scannen gibt (Werkzeuge, \"Alles Fehlende scannen\"). Es startet nichts von selbst."] },
}}
ns.RegisterSlash("scan", { args = L["[von bis] | gear | quests | npcs | all | retry | aufräumen | stop | status | rate <n>"], desc = L["Item-Scan, Quest-Scan, NPC-Scan"], run = function(rest)
    ns.ScanCommand(rest)
end })
