-- Amisia soft-reserves shared with the raid (F-107, spec 2026-10-17 part A, D-53). An officer in the
-- officer view with a list he took himself (AmisiaDB.softres without "from") announces it: "SV <import
-- epoch> <hash> <reservations>" into the raid 10 s after a change, every 240 s and soon after someone
-- joins. A client with another state asks by whisper "SQ <epoch> <own hash>"; the officer answers
-- with the whole list as blob "SR" (key "<list date>:<epoch>"; three or more askers within 2 s: one
-- send into the raid). Only a verified officer of the own guild in the own group is listened to, a
-- list is taken only when asked for and checked whole, and its hash must be the one announced.
-- Raiders and officers without an own list take it (AmisiaDB.softres with "from" = the officer);
-- an officer with an own list in the officer view gets it only as an offer (memory, until /reload)
-- and takes it with "Liste übernehmen" on the page. The newest import wins (equal: the smaller name).
-- "SV <epoch> - 0" after clearing: who holds that officer's list of that epoch clears it too.
local ADDON, ns = ...
local L = ns.L

local SV_EVERY = 240           -- an officer repeats his state this often
local SV_GAP = 10              -- and not more often than this after a change
local ANSWER_AFTER = 2         -- requests within this go out together
local ANSWER_RAID = 3          -- this many requesters: one send into the raid
local MAX_RAIDERS, MAX_ITEMS, MAX_HARD = 100, 2000, 200
local MAX_NAME, MAX_NOTE, MAX_ID = 48, 60, 9999999

local lastSV                   -- { at, h, t }: the last own announcement
local asks, askTimer = {}, false
local wanted = {}              -- officer name -> { at, h }: the list asked for
local offer                    -- { from, at, h, sr }: a newer list for an officer with his own
local stats = { sent = 0, taken = 0, offered = 0, refused = 0, cleared = 0 }

local function now() return GetTime() end
local function shareOn() return ns.Get("softres.share") and true or false end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function homeRaid()
    if _G.LE_PARTY_CATEGORY_HOME then return IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false end
    return IsInRaid() and true or false
end

-- The list this client may announce: its own (not one received), in the officer view.
local function ownList()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or sr.from or not ns.IsOfficerView() then return nil end
    if type(sr.at) ~= "number" then sr.at = ns.ServerTime() end
    return sr
end

---------------------------------------------------------------------------
-- The list as it travels: names sorted, a name's items sorted with doubles repeated
---------------------------------------------------------------------------
local function sortedNames(sr)
    local set, out = {}, {}
    for _, names in pairs(sr.byItem or {}) do
        for _, name in ipairs(names) do
            if not set[name] then set[name] = true; out[#out + 1] = name end
        end
    end
    table.sort(out)
    return out
end

-- { v = 1, at, d, sid, r = { { n, c, i, o, p } }, h = { { id, to, note } } } of a stored list.
local function payloadOf(sr)
    local items = {}
    for item, names in pairs(sr.byItem or {}) do
        for _, name in ipairs(names) do
            items[name] = items[name] or {}
            for _ = 1, ns.SoftResTimes(sr, item, name) do items[name][#items[name] + 1] = item end
        end
    end
    local r = {}
    for _, name in ipairs(sortedNames(sr)) do
        table.sort(items[name])
        r[#r + 1] = { n = name, c = (sr.classes or {})[name], i = items[name], o = (sr.notes or {})[name],
                      p = (sr.plus or {})[name] }
    end
    local h, ids = {}, {}
    for id in pairs(type(sr.hard) == "table" and sr.hard or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do h[#h + 1] = { id, sr.hard[id].to or "", sr.hard[id].note or "" } end
    return { v = 1, at = sr.at, d = sr.date, sid = sr.sid, r = r, h = h }
end

-- The hash of a list: what travels, in one text.
local function hashOf(sr)
    local p = payloadOf(sr)
    local lines = { tostring(p.d or "") .. "|" .. tostring(p.sid or "") }
    for _, e in ipairs(p.r) do
        local ids = {}
        for k, id in ipairs(e.i) do ids[k] = tostring(id) end
        lines[#lines + 1] = table.concat({ e.n, e.c or "", table.concat(ids, ","), e.o or "", tostring(e.p or "") }, "|")
    end
    for _, x in ipairs(p.h) do lines[#lines + 1] = ("H|%d|%s|%s"):format(x[1], x[2], x[3]) end
    return ns.Checksum(table.concat(lines, "\n"))
end
ns.SoftResHash = hashOf

local function count(sr) return tonumber(sr.count) or 0 end

-- A received list checked whole, as a stored list; nil when anything is off.
local function checkList(tbl, at)
    if type(tbl) ~= "table" or tbl.v ~= 1 or tbl.at ~= at or type(tbl.r) ~= "table" or type(tbl.h) ~= "table" then return nil end
    if type(tbl.d) ~= "string" or not tbl.d:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil end
    if tbl.sid ~= nil and (type(tbl.sid) ~= "string" or #tbl.sid > 40 or not tbl.sid:match("^[%w%-_]+$")) then return nil end
    local function clean(s, max) return type(s) == "string" and ns.SoftResClean(s, max) == s end
    local sr = { version = 3, date = tbl.d, raw = "", byItem = {}, times = {}, renamed = {}, reminded = {}, src = "shared",
                 sid = tbl.sid, at = at, notes = {}, classes = {}, plus = {}, hard = {}, count = 0 }
    local seen, total = {}, 0
    if #tbl.r > MAX_RAIDERS or #tbl.h > MAX_HARD then return nil end
    for k, e in ipairs(tbl.r) do
        if type(e) ~= "table" or not clean(e.n, MAX_NAME) or e.n:find("[%d,;:]") or seen[e.n] then return nil end
        if k > 1 and tbl.r[k - 1].n >= e.n then return nil end
        seen[e.n] = true
        if e.c ~= nil and (not clean(e.c, 20) or not ns.SoftResClassToken(e.c)) then return nil end
        if e.o ~= nil and not clean(e.o, MAX_NOTE) then return nil end
        if e.p ~= nil and (type(e.p) ~= "number" or e.p % 1 ~= 0 or e.p < 1 or e.p > 99) then return nil end
        if type(e.i) ~= "table" or #e.i == 0 then return nil end
        local prev = 0
        for _, id in ipairs(e.i) do
            total = total + 1
            if total > MAX_ITEMS or type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > MAX_ID or id < prev then return nil end
            if id == prev then
                sr.times[id] = sr.times[id] or {}
                sr.times[id][e.n] = (sr.times[id][e.n] or 1) + 1
            else
                sr.byItem[id] = sr.byItem[id] or {}
                sr.byItem[id][#sr.byItem[id] + 1] = e.n
            end
            prev = id
        end
        sr.classes[e.n], sr.notes[e.n], sr.plus[e.n] = e.c, e.o, e.p
    end
    local prevHard = 0
    for _, x in ipairs(tbl.h) do
        if type(x) ~= "table" then return nil end
        local id, to, note = x[1], x[2], x[3]
        if type(id) ~= "number" or id % 1 ~= 0 or id <= prevHard or id > MAX_ID then return nil end
        if not (to == "" or clean(to, MAX_NAME)) or not (note == "" or clean(note, MAX_NOTE)) then return nil end
        sr.hard[id] = { to = to, note = note }
        prevHard = id
    end
    for _, names in pairs(sr.byItem) do table.sort(names) end
    sr.count = total
    return sr
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function sendSV()
    if not shareOn() or not homeRaid() then lastSV = nil return end
    local sr = ownList()
    if not sr then return end
    local h = hashOf(sr)
    local t = now()
    if lastSV and lastSV.at == sr.at then
        if lastSV.h == h and t - lastSV.t < SV_EVERY then return end
        if t - lastSV.t < SV_GAP then return end
    end
    if ns.CommSend("SV", { tostring(sr.at), h, tostring(count(sr)) }, "RAID", nil, { ttl = 60, key = "SV" }) then
        lastSV = { at = sr.at, h = h, t = t }
    end
end

local function sendList()
    askTimer = false
    local sr = ownList()
    local who = {}
    for s in pairs(asks) do who[#who + 1] = s end
    asks = {}
    if not sr or not shareOn() then return end
    local key = ("%s:%d"):format(sr.date, sr.at)
    local tbl = payloadOf(sr)
    local function send(chan, target, opts)
        local ok, why = ns.CommSendBlob("SR", key, tbl, chan, target, opts)
        if ok then
            stats.sent = stats.sent + 1
        elseif why == L["Daten zu groß."] then
            ns.msg(L["Soft-Reserves: Liste zu groß zum Teilen."])
        end
    end
    if #who >= ANSWER_RAID then
        send("RAID", nil, { ttl = 600, low = true })
        return
    end
    for _, s in ipairs(who) do send("WHISPER", s, { ttl = 600, key = "SR:" .. s, low = true }) end
end

-- After an import: announce at once (the window's "Übernehmen", "/amisia sr <code>"). Whether the
-- list goes to the raid.
function ns.SoftResShareNow()
    if not shareOn() or not homeRaid() or not ownList() then return false end
    lastSV = nil
    local ok, err = pcall(sendSV)
    if not ok then report(err) end
    return true
end

-- The own list was cleared: the raid hears it once ("-"), so the copies of it go too.
function ns.SoftResShareCleared(sr)
    offer = nil
    if not sr or sr.from or not lastSV or lastSV.at ~= sr.at or not homeRaid() then return end
    ns.CommSend("SV", { tostring(sr.at), "-", "0" }, "RAID", nil, { ttl = 60, key = "SV" })
    lastSV = nil
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
-- Whether a list (from, at) beats the one held (sr): newer wins, equal by the smaller name.
local function beats(from, at, sr)
    if not sr then return true end
    local held = tonumber(sr.at) or 0
    if at ~= held then return at > held end
    return from < (sr.from or "")
end

-- Whether this client takes lists only as offers (an officer with his own list).
local function offerOnly()
    local sr = AmisiaDB and AmisiaDB.softres
    return sr ~= nil and sr.from == nil and ns.IsOfficerView()
end

ns.CommOn("SV", function(sender, f, chan)
    if chan ~= "RAID" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local at, h = tonumber(f[1]), f[2]
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        local sr = AmisiaDB and AmisiaDB.softres
        if h == "-" then
            if offer and offer.from == name and offer.at == at then offer = nil; ns.Refresh() end
            if sr and sr.from == name and sr.at == at then
                AmisiaDB.softres = nil
                stats.cleared = stats.cleared + 1
                ns.MarkSoftResLoot()
                if ns.SoftResImportChanged then ns.SoftResImportChanged() end
                if ns.Refresh then ns.Refresh() end
            end
            return
        end
        if sr and sr.from == name and sr.at == at and sr.hash == h then return end
        if offerOnly() then
            if offer and offer.from == name and offer.at == at and offer.h == h then return end
            if not beats(name, at, sr) or (offer and offer.from ~= name and not beats(name, at, { at = offer.at, from = offer.from })) then return end
        elseif sr and not (sr.from == name and sr.at == at) and not beats(name, at, sr) then
            return
        end
        wanted[name] = { at = at, h = h }
        ns.CommSend("SQ", { tostring(at), (sr and sr.hash) or "-" }, "WHISPER", sender,
            { jitter = 2.75, ttl = 60, key = "SQ:" .. name })
    end)
end)

ns.CommOn("SQ", function(sender, f, chan)
    if chan ~= "WHISPER" or not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        local sr = ownList()
        if not sr or sr.at ~= tonumber(f[1]) then return end
        asks[sender] = true
        if not askTimer then
            askTimer = true
            C_Timer.After(ANSWER_AFTER, function()
                local okSend, err = pcall(sendList)
                if not okSend then askTimer = false; report(err) end
            end)
        end
    end)
end)

ns.CommOnBlob("SR", function(sender, tbl, chan, key)
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "officer", function(ok)
        local want = wanted[name]
        if not ok or not ns.InMyGroup(name) or not want then
            stats.refused = stats.refused + 1
            return
        end
        local sr = checkList(tbl, want.at)
        if not sr or key ~= ("%s:%d"):format(sr.date, sr.at) or hashOf(sr) ~= want.h then
            stats.refused = stats.refused + 1
            return
        end
        wanted[name] = nil
        sr.from, sr.hash = name, want.h
        if offerOnly() then
            offer = { from = name, at = sr.at, h = want.h, sr = sr }
            stats.offered = stats.offered + 1
            ns.msg(L["Soft-Reserves: %s hat eine neuere Liste geteilt (%d Reservierungen). Auf der Seite Soft-Reserves \"Liste übernehmen\"."]:format(name, sr.count))
        else
            AmisiaDB.softres = sr
            stats.taken = stats.taken + 1
            ns.MarkSoftResLoot()
            if ns.SoftResImportChanged then ns.SoftResImportChanged() end
        end
        if ns.Refresh then ns.Refresh() end
    end)
end)

-- The offered list for the page: { from, at, n }, or nil.
function ns.SoftResOffer()
    if not offer or not offerOnly() then return nil end
    return { from = offer.from, at = offer.at, n = offer.sr.count }
end

-- Takes the offered list in place of the own one (the page's "Liste übernehmen").
function ns.TakeSoftResOffer()
    if not offer then return false end
    AmisiaDB.softres = offer.sr
    offer = nil
    lastSV = nil
    stats.taken = stats.taken + 1
    ns.MarkSoftResLoot()
    if ns.SoftResImportChanged then ns.SoftResImportChanged() end
    if ns.Refresh then ns.Refresh() end
    return true
end

function ns.SoftResShareStats() return stats end

-- someone joined: the next tick announces again (within SV_GAP)
local members = 0
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local n = GetNumGroupMembers() or 0
    if n > members and lastSV then lastSV.h = nil end
    members = n
end)

C_Timer.NewTicker(5, function()
    local ok, err = pcall(sendSV)
    if not ok then report(err) end
end)
