-- Amisia item scan: asks the client for every item id in a range, throttled, and keeps what
-- exists. The result feeds tools/build_scan.py, which reads the SavedVariables file.
local ADDON, ns = ...

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
-- off: the gear planner's build reads them, so the planner needs no loading in game.
local function statText(id, classID)
    local getStats = C_Item.GetItemStats
    if (classID ~= 2 and classID ~= 4) or not getStats then return "" end
    local raw = getStats("item:" .. id)
    if not raw then return "" end
    local parts = {}
    for k, v in pairs(raw) do
        if type(v) == "number" and v ~= 0 then
            parts[#parts + 1] = tostring(k):gsub("^ITEM_MOD_", "") .. "=" .. tostring(v)
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
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
    if not s.items[id] then s.count = s.count + 1 end
    local fields = {
        (name:gsub("[\t\n]", " ")), tostring(q or 0), tostring(ilvl or 0), tostring(minLevel or 0),
        tostring(classID or ""), tostring(subclassID or ""), tostring(equipLoc or ""), tostring(icon or ""), tostring(bindType or ""),
    }
    -- a tenth field with the stats, only for gear
    local st = statText(id, tonumber(classID))
    if st ~= "" then fields[#fields + 1] = st end
    s.items[id] = table.concat(fields, "\t")
    return true
end
ns.StoreItem = store
ns.ScanDB = scanDB

local function finish(why)
    running = false
    queue = nil
    if savedRate then scanDB().rate = savedRate; savedRate = nil end
    if ticker then ticker:Cancel(); ticker = nil end
    pending, pendingCount = {}, 0
    local s = scanDB()
    s.at = time()
    ns.msg(("Scan %s: %d Items gespeichert, nächste ID %d, %d offen zum Wiederholen."):format(why or "beendet", s.count, s.next or 0, #s.retry))
    if ns.Refresh then ns.Refresh() end
end

local function send(id, tries)
    pending[id] = { sent = now(), tries = tries }
    request(id)
end

local function tick()
    local s = scanDB()
    if not running then return end
    if InCombatLockdown() then return end
    if inInstance() then finish("pausiert in der Instanz") return end
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
            send(table.remove(queue, 1), 1)
            pendingCount = pendingCount + 1
            batch = batch - 1
        end
        if #queue == 0 and pendingCount == 0 then finish("fertig") end
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
            ns.msg(("Scan: ID %d von %d, %d Items."):format(s.next - 1, s.to, s.count))
            if ns.Refresh then ns.Refresh() end
        end
    end
    if s.next > s.to and pendingCount == 0 then finish("fertig") end
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
    if pendingCount == 0 and ((queue and #queue == 0) or (not queue and s.next > s.to)) then finish("fertig") end
end
ns.OnEvent("ITEM_DATA_LOAD_RESULT", onResult)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", onResult)

function ns.ScanRunning() return running end

function ns.ScanStart(from, to)
    if not request then return nil, "Dieser Client kann keine Items nachladen." end
    if running then return nil, "Der Scan läuft schon. /amisia scan stop hält ihn an." end
    if inInstance() then return nil, "Der Scan läuft nur außerhalb von Instanzen." end
    local s = scanDB()
    from = tonumber(from) or s.next or 1
    to = tonumber(to) or s.to or DEFAULT_TO
    if from < 1 or to < from then return nil, "Bereich prüfen: /amisia scan <von> <bis>" end
    s.from, s.to, s.next = math.floor(from), math.floor(to), math.floor(from)
    pending, pendingCount = {}, 0
    nextReport = (math.floor(s.next / REPORT_EVERY) + 1) * REPORT_EVERY
    running = true
    ticker = C_Timer.NewTicker(0.1, tick)
    ns.msg(("Scan gestartet: ID %d bis %d, %d Anfragen pro Sekunde. /amisia scan stop hält an."):format(s.from, s.to, s.rate))
    if ns.Refresh then ns.Refresh() end
    return true
end

-- Asks again for every id that got no usable answer, at a quarter of the rate.
function ns.ScanRetry()
    if not request then return nil, "Dieser Client kann keine Items nachladen." end
    if running then return nil, "Der Scan läuft schon. /amisia scan stop hält ihn an." end
    if inInstance() then return nil, "Der Scan läuft nur außerhalb von Instanzen." end
    local s = scanDB()
    if #s.retry == 0 then return nil, "Keine offenen IDs." end
    queue = s.retry
    s.retry = {}
    pending, pendingCount = {}, 0
    nextReport = math.huge
    running = true
    local slow = math.max(10, math.floor(s.rate / 4))
    savedRate = s.rate
    s.rate = slow
    ticker = C_Timer.NewTicker(0.1, tick)
    ns.msg(("Wiederholung gestartet: %d IDs mit %d Anfragen pro Sekunde."):format(#queue, slow))
    return true
end

-- Scans a list of ids, e.g. everything the gear planner lists plus what its sources name but no scan
-- has seen yet (items Forever only reveals later).
function ns.ScanList(ids, label)
    if not request then return nil, "Dieser Client kann keine Items nachladen." end
    if running then return nil, "Der Scan läuft schon. /amisia scan stop hält ihn an." end
    if inInstance() then return nil, "Der Scan läuft nur außerhalb von Instanzen." end
    if not ids or #ids == 0 then return nil, "Keine IDs zu scannen." end
    local s = scanDB()
    queue = {}
    for i = 1, #ids do queue[i] = ids[i] end
    pending, pendingCount = {}, 0
    nextReport = math.huge
    running = true
    ticker = C_Timer.NewTicker(0.1, tick)
    ns.msg(("%s: %d IDs mit %d Anfragen pro Sekunde. Danach ausloggen, damit die Datei geschrieben wird."):format(label or "Scan", #ids, s.rate))
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

function ns.ScanStop()
    if not running then return end
    finish("angehalten")
end

function ns.ScanStatus()
    local s = AmisiaDB and AmisiaDB.scan
    if not s or not s.next then
        return ("Noch kein Scan. /amisia scan <von> <bis> startet einen. %d Items gesammelt."):format(s and s.count or 0)
    end
    if running then
        return ("Scan läuft: ID %d von %d, %d Items."):format(s.next - 1, s.to, s.count or 0)
    end
    return ("Scan: %d Items, nächste ID %d von %d%s%s."):format(s.count or 0, s.next, s.to or 0,
        (#(s.retry or {}) > 0) and (", " .. #s.retry .. " offen") or "",
        ns.CollectCount and (", " .. ns.CollectCount() .. " Quellen gesammelt") or "")
end

function ns.ScanCommand(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    local word, arg = rest:match("^(%S*)%s*(.*)$")
    word = (word or ""):lower()
    if word == "stop" then
        ns.ScanStop()
    elseif word == "retry" then
        local ok, why = ns.ScanRetry()
        if not ok and why then ns.msg(why) end
    elseif word == "status" then
        ns.msg(ns.ScanStatus())
    elseif word == "gear" then
        local ids = ns.GearScanIDs()
        if not ids then
            ns.msg("Die Ausrüstungstabelle gibt es nur in WoW Forever.")
            return
        end
        local ok, why = ns.ScanList(ids, "Ausrüstungs-Scan")
        if not ok and why then ns.msg(why) end
    elseif word == "rate" then
        if ns.Set("tools.scanRate", tonumber(arg)) then
            scanDB()
            ns.msg(("Scan-Rate: %d Anfragen pro Sekunde."):format(ns.Get("tools.scanRate")))
        else
            ns.msg("Aufruf: /amisia scan rate <10-1000>")
        end
    else
        local from, to = rest:match("^(%d+)%s+(%d+)$")
        if not from and rest ~= "" then
            ns.msg("Aufruf: /amisia scan [<von> <bis>] | gear | retry | stop | status | rate <n>")
            return
        end
        local ok, why = ns.ScanStart(from and tonumber(from), to and tonumber(to))
        if not ok and why then ns.msg(why) end
    end
end

ns.RegisterSettings{ key = "tools", label = "Werkzeuge", order = 95, expert = true, items = {
    { key = "tools.collect", type = "toggle", label = "Item-Sammler", default = true,
      tip = "Merkt sich Items aus Taschen, Händlern, Quests, Auktionshaus, Tooltips und Loot mit ihrer Quelle." },
    { key = "tools.scanRate", type = "slider", label = "Scan-Rate (Anfragen pro Sekunde)", default = 100, min = 10, max = 1000, step = 10 },
}}
ns.RegisterSlash("scan", { args = "[von bis] | gear | retry | stop | status | rate <n>", desc = "Item-Scan", run = function(rest)
    ns.ScanCommand(rest)
end })
