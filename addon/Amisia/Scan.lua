-- Amisia item scan: asks the client for every item id in a range, throttled, and keeps what
-- exists. The result feeds tools/build_scan.py, which reads the SavedVariables file.
local ADDON, ns = ...

local MAX_PENDING = 200
local TIMEOUT = 3
local MAX_TRIES = 2
local DEFAULT_TO = 250000
local DEFAULT_RATE = 100
local REPORT_EVERY = 5000

local running = false
local ticker
local pending, pendingCount = {}, 0
local clock = 0
local nextReport

local GetItemInfoAny = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstantAny = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local request = C_Item and C_Item.RequestLoadItemDataByID

local function now()
    return GetTime and GetTime() or clock
end

local function scanDB()
    AmisiaDB.scan = AmisiaDB.scan or {}
    local s = AmisiaDB.scan
    s.items = s.items or {}
    s.retry = s.retry or {}
    s.rate = tonumber(s.rate) or DEFAULT_RATE
    s.count = s.count or 0
    return s
end

local function inInstance()
    local _, kind = GetInstanceInfo()
    return kind == "raid" or kind == "party"
end

local function store(id)
    local name, _, q, ilvl, minLevel, _, _, _, equipLoc, icon, _, classID, subclassID, bindType = GetItemInfoAny(id)
    if not name then return false end
    if GetItemInfoInstantAny and (not icon or not classID) then
        local _, _, _, loc, ico, cls, sub = GetItemInfoInstantAny(id)
        equipLoc, icon, classID, subclassID = equipLoc or loc, icon or ico, classID or cls, subclassID or sub
    end
    local s = scanDB()
    if not s.items[id] then s.count = s.count + 1 end
    s.items[id] = table.concat({
        (name:gsub("[\t\n]", " ")), tostring(q or 0), tostring(ilvl or 0), tostring(minLevel or 0),
        tostring(classID or ""), tostring(subclassID or ""), tostring(equipLoc or ""), tostring(icon or ""), tostring(bindType or ""),
    }, "\t")
    return true
end

local function finish(why)
    running = false
    if ticker then ticker:Cancel(); ticker = nil end
    pending, pendingCount = {}, 0
    local s = scanDB()
    s.at = time()
    ns.msg(("Scan %s: %d Items gespeichert, naechste ID %d, %d offen zum Wiederholen."):format(why or "beendet", s.count, s.next or 0, #s.retry))
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
    if scanDB().next > scanDB().to and pendingCount == 0 then finish("fertig") end
end
ns.OnEvent("ITEM_DATA_LOAD_RESULT", onResult)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", onResult)

function ns.ScanRunning() return running end

function ns.ScanStart(from, to)
    if not request then return nil, "Dieser Client kann keine Items nachladen." end
    if running then return nil, "Der Scan laeuft schon. /amisia scan stop haelt ihn an." end
    if inInstance() then return nil, "Der Scan laeuft nur ausserhalb von Instanzen." end
    local s = scanDB()
    from = tonumber(from) or s.next or 1
    to = tonumber(to) or s.to or DEFAULT_TO
    if from < 1 or to < from then return nil, "Bereich pruefen: /amisia scan <von> <bis>" end
    s.from, s.to, s.next = math.floor(from), math.floor(to), math.floor(from)
    pending, pendingCount = {}, 0
    nextReport = (math.floor(s.next / REPORT_EVERY) + 1) * REPORT_EVERY
    running = true
    ticker = C_Timer.NewTicker(0.1, tick)
    ns.msg(("Scan gestartet: ID %d bis %d, %d Anfragen pro Sekunde. /amisia scan stop haelt an."):format(s.from, s.to, s.rate))
    if ns.Refresh then ns.Refresh() end
    return true
end

function ns.ScanStop()
    if not running then return end
    finish("angehalten")
end

function ns.ScanStatus()
    local s = AmisiaDB and AmisiaDB.scan
    if not s or not s.next then return "Noch kein Scan. /amisia scan <von> <bis> startet einen." end
    if running then
        return ("Scan laeuft: ID %d von %d, %d Items."):format(s.next - 1, s.to, s.count or 0)
    end
    return ("Scan: %d Items, naechste ID %d von %d%s."):format(s.count or 0, s.next, s.to or 0,
        (#(s.retry or {}) > 0) and (", " .. #s.retry .. " offen") or "")
end

function ns.ScanCommand(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    local word, arg = rest:match("^(%S*)%s*(.*)$")
    word = (word or ""):lower()
    if word == "stop" then
        ns.ScanStop()
    elseif word == "status" then
        ns.msg(ns.ScanStatus())
    elseif word == "rate" then
        local n = tonumber(arg)
        if n and n >= 10 and n <= 1000 then
            scanDB().rate = math.floor(n)
            ns.msg(("Scan-Rate: %d Anfragen pro Sekunde."):format(scanDB().rate))
        else
            ns.msg("Aufruf: /amisia scan rate <10-1000>")
        end
    else
        local from, to = rest:match("^(%d+)%s+(%d+)$")
        if not from and rest ~= "" then
            ns.msg("Aufruf: /amisia scan [<von> <bis>] | stop | status | rate <n>")
            return
        end
        local ok, why = ns.ScanStart(from and tonumber(from), to and tonumber(to))
        if not ok and why then ns.msg(why) end
    end
end
