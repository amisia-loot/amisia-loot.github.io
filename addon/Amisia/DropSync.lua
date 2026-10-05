-- Amisia drop exchange: guild members share their drop records (Drops.lua) quietly, pulling only
-- what they miss. A client announces what it holds to the guild (DV: per week of the last four a
-- checksum and a count); whoever hears a different week asks that one sender (DQ), gets its buckets
-- (DI: day and instance with checksum and count), and asks for each bucket that differs (DR, naming
-- the ids it already has); the answer is a DK blob with only the missing records. Both sides pull,
-- neither pushes: a blob nobody asked for is dropped. Everything goes at the lowest priority of the
-- queue, only between guild members, never in an instance, in combat, in the lockdown or while a raid
-- is synced, within fixed caps. Records are merged (Drops.lua), never overwritten; no names are sent
-- or stored but the bosses' and instances'.
local ADDON, ns = ...

ns.DROP_PROTO = 1

-- the caps and times; a table so a test can lower one
local L = {
    firstMin = 60, firstSpread = 120,   -- the first announcement 60 to 180 s after the login
    every = 1800,                       -- later ones at most every 30 minutes, after new own records
    tick = 5,
    diWait = 60,                        -- seconds the bucket list of a week may take
    drWait = 90,                        -- seconds a request waits for its blob (one open at a time)
    askKeep = 1800,                     -- seconds a blob for an asked bucket is still taken
    drPerHour = 30,
    serveGap = 30, partsWindow = 600, partsMax = 40,   -- an answering client: a blob per 30 s, 40 parts per 10 min
    blobParts = 20, blobRecords = 300,
    sessionBytes = 61440,               -- everything this module sends in a session
    peerKeep = 1800, peersMax = 10,     -- announcements heard and not pulled yet
    serveMax = 6, serveKeep = 1200,     -- requests waiting for their blob
    starEvery = 7 * 86400,              -- a whole bucket ("*") at most once a week per bucket
    listMax = 16, diEntries = 12, diChars = 200,
}
ns.DROPSYNC_LIMITS = L

local PART_OVERHEAD = 45   -- prefix and fields of one data part, above its 200 characters

local stats = { bytes = 0, dv = 0, dq = 0, di = 0, dr = 0, served = 0, blobs = 0, records = 0, new = 0, merged = 0,
                bad = 0, unasked = 0, refused = 0, pulls = 0 }
local drTimes = {}        -- GetTime() of the requests of the last hour
local asked = {}          -- "key|lower name" -> GetTime() of the request
local peers = {}          -- { name, low, weeks, at }: announcements heard, waiting to be pulled
local pull                -- the one pull running: { name, low, weeks, wants, wi, w, stage, parts, n, got, drs, key, deadline }
local serve = {}          -- { name, low, key, ids, at }: requests this client answers
local lastBlob
local partsLog = {}       -- { GetTime(), parts } of the blobs sent
local firstAt, announced, lastDV, addedAtDV

local function now() return GetTime() end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function hex4(s) return ns.Checksum(s):sub(13, 16) end
local function isHex8(v) return type(v) == "string" and #v == 8 and v:match("^%x+$") ~= nil end
local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function nameOk(v) return type(v) == "string" and v ~= "" and #v <= 48 and not v:find("[%c|]") end

local function debugLine(text)
    if ns.Get("sync.debug") then DEFAULT_CHAT_FRAME:AddMessage("|cff999999Amisia Drops: " .. text .. "|r") end
end

---------------------------------------------------------------------------
-- When the exchange may talk
---------------------------------------------------------------------------
local function raidSynced()
    local s = ns.Active and ns.Active()
    return s ~= nil and ns.CommReady() and true or false
end

local function battlefield()
    local pvp = _G.C_PvP
    if type(pvp) ~= "table" or type(pvp.IsActiveBattlefield) ~= "function" then return false end
    local ok, on = pcall(pvp.IsActiveBattlefield)
    return ok and ns.Plain(on) == true
end

-- Sharing on, the message layer there, in a guild, outside instances and battlegrounds, out of
-- combat, no lockdown, no raid recording with sync.
function ns.DropSyncCanTalk()
    if not AmisiaDB or not ns.Get("drops.share") then return false end
    if not ns.CommAvailable() or not ns.CommPacking() then return false end
    if type(IsInGuild) ~= "function" or ns.Plain(IsInGuild()) ~= true then return false end
    if type(IsInInstance) == "function" and ns.Plain((IsInInstance())) == true then return false end
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind ~= nil and kind ~= "none" then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return false end
    if ns.CommHeld() then return false end
    if raidSynced() or battlefield() then return false end
    return true
end
local canTalk = function() return ns.DropSyncCanTalk() end

---------------------------------------------------------------------------
-- Sending, within the session's bytes
---------------------------------------------------------------------------
local function afford(n) return stats.bytes + n <= L.sessionBytes end

local function send(kind, fields, chan, target, key)
    local n = #"Amisia" + #tostring(ns.SYNC_PROTO) + #kind + 1 + #table.concat(fields, "\t")
    if not afford(n) then
        debugLine("Sendegrenze der Sitzung erreicht.")
        return false
    end
    local ok = ns.CommSend(kind, fields, chan, target, { low = true, when = canTalk, key = key })
    if not ok then return false end
    stats.bytes = stats.bytes + n
    stats[kind:lower()] = stats[kind:lower()] + 1
    return true
end

---------------------------------------------------------------------------
-- Buckets (day and instance) and weeks of the own records
---------------------------------------------------------------------------
local index
ns.Listen("DROPS_CHANGED", function() index = nil end)

-- { today, buckets = { [key] = { key, day, inst, ids (sorted), hash, w } }, weeks = { [0..3] = { n, hash, list } },
--   total, newest }
local function indexNow()
    local today = ns.DropsToday()
    if index and index.today == today then return index end
    local d = ns.DropsDB()
    local buckets, total, newest = {}, 0, nil
    for id, r in pairs(d and d.k or {}) do
        local w = math.floor((today - r.day) / 7)
        if w >= 0 and w <= 3 then
            local key = ns.DropsDate(r.day) .. ":" .. r.inst
            local b = buckets[key]
            if not b then
                b = { key = key, day = r.day, inst = r.inst, ids = {}, w = w }
                buckets[key] = b
            end
            b.ids[#b.ids + 1] = id
            total = total + 1
            if not newest or r.day > newest then newest = r.day end
        end
    end
    local weeks = {}
    for w = 0, 3 do weeks[w] = { n = 0, list = {} } end
    for _, b in pairs(buckets) do
        table.sort(b.ids)
        b.hash = hex4(table.concat(b.ids, ","))
        local wk = weeks[b.w]
        wk.n = wk.n + #b.ids
        wk.list[#wk.list + 1] = b
    end
    for w = 0, 3 do
        local wk = weeks[w]
        table.sort(wk.list, function(a, b) return a.key < b.key end)
        if wk.n == 0 then
            wk.hash = "0000"
        else
            local parts = {}
            for i, b in ipairs(wk.list) do parts[i] = b.key .. "=" .. b.hash end
            wk.hash = hex4(table.concat(parts, ","))
        end
    end
    index = { today = today, buckets = buckets, weeks = weeks, total = total, newest = newest }
    return index
end

---------------------------------------------------------------------------
-- Announcing (DV)
---------------------------------------------------------------------------
local function sendDV()
    local ix = indexNow()
    if ix.total == 0 then return false end
    local weeks = {}
    for w = 0, 3 do weeks[#weeks + 1] = ("%d:%s:%d"):format(w, ix.weeks[w].hash, ix.weeks[w].n) end
    return send("DV", { tostring(ns.DROP_PROTO), tostring(ix.total), tostring(ix.newest), table.concat(weeks, ",") }, "GUILD", nil, "DV")
end

-- The first announcement after the login: 60 to 180 s, spread by the random client id (no draw
-- from math.random, which would shift every other random delay).
ns.OnEvent("PLAYER_LOGIN", function()
    if firstAt then return end
    local d = ns.DropsDB()
    local spread = d and tonumber(d.me:sub(1, 4), 16) or 0
    firstAt = now() + L.firstMin + spread % (L.firstSpread + 1)
end)

local function announce()
    if not firstAt or now() < firstAt or not canTalk() then return end
    if not announced then
        -- nothing to offer counts as said; the next own record is announced after the usual wait
        if sendDV() or indexNow().total == 0 then announced, lastDV, addedAtDV = true, now(), ns.DropsAdded() end
    elseif ns.DropsAdded() > addedAtDV and now() - lastDV >= L.every then
        if sendDV() then lastDV, addedAtDV = now(), ns.DropsAdded() end
    end
end

---------------------------------------------------------------------------
-- Pulling: DQ, DI, DR, and the DK blob
---------------------------------------------------------------------------
local nextWeek, nextDR, startNext

-- The weeks an announcement holds that differ from the own.
local function wantsOf(weeks)
    local ix, out = indexNow(), {}
    for w = 0, 3 do
        local t, m = weeks[w], ix.weeks[w]
        if t and t.n > 0 and (t.h ~= m.hash or t.n ~= m.n) then out[#out + 1] = w end
    end
    return out
end

local function queuePeer(name, weeks, at, front)
    local low = name:lower()
    for i, p in ipairs(peers) do
        if p.low == low then table.remove(peers, i) break end
    end
    local p = { name = name, low = low, weeks = weeks, at = at or now() }
    if front then table.insert(peers, 1, p) else peers[#peers + 1] = p end
    while #peers > L.peersMax do table.remove(peers, 1) end
end

-- Stops the pull; a peer that was cut off by the conditions (not by silence) waits again.
local function stopPull(again)
    if pull and again then queuePeer(pull.name, pull.weeks, pull.at, true) end
    pull = nil
end

startNext = function()
    if pull or not canTalk() then return end
    while #peers > 0 do
        local p = table.remove(peers, 1)
        if now() - p.at <= L.peerKeep then
            local wants = wantsOf(p.weeks)
            if #wants > 0 then
                pull = { name = p.name, low = p.low, weeks = p.weeks, at = p.at, wants = wants, wi = 0 }
                stats.pulls = stats.pulls + 1
                return nextWeek()
            end
        end
    end
end

nextWeek = function()
    pull.wi = pull.wi + 1
    local w = pull.wants[pull.wi]
    if not w then
        pull = nil
        return startNext()
    end
    pull.w, pull.stage, pull.parts, pull.n, pull.got, pull.deadline = w, "DI", {}, nil, 0, now() + L.diWait
    if not send("DQ", { tostring(w) }, "WHISPER", pull.name) then pull = nil end
end

local function hourCount()
    local t, keep = now(), {}
    for _, at in ipairs(drTimes) do
        if t - at < 3600 then keep[#keep + 1] = at end
    end
    drTimes = keep
    return #keep
end

-- The ids field of a request: the own ids (16 at most), or "*" for a bucket without own records or
-- with more than 16 of them (a whole bucket at most once a week, which also evens out the items).
local function idsField(key, ids)
    if #ids == 0 then return "*" end
    if #ids <= L.listMax then return table.concat(ids, ",") end
    local d = ns.DropsDB()
    d.star = type(d.star) == "table" and d.star or {}
    local last = d.star[key]
    if not last or time() - last >= L.starEvery then
        d.star[key] = time()
        return "*"
    end
    return table.concat(ids, ",", 1, L.listMax)
end

nextDR = function()
    local dr = table.remove(pull.drs, 1)
    if not dr then return nextWeek() end
    if hourCount() >= L.drPerHour then
        debugLine("30 Anfragen in der Stunde erreicht.")
        return stopPull(true)
    end
    if not send("DR", { dr.key, idsField(dr.key, dr.ids) }, "WHISPER", pull.name) then return stopPull(false) end
    drTimes[#drTimes + 1] = now()
    asked[dr.key .. "|" .. pull.low] = now()
    pull.stage, pull.key, pull.deadline = "DK", dr.key, now() + L.drWait
end

ns.CommOn("DV", function(sender, f, chan)
    if chan ~= "GUILD" or tonumber(f[1]) ~= ns.DROP_PROTO then return end
    if not AmisiaDB or not ns.Get("drops.share") then return end
    local weeks = {}
    for e in (f[4] .. ","):gmatch("([^,]*),") do
        local w, h, n = e:match("^(%d):(%x+):(%d+)$")
        weeks[tonumber(w)] = { h = h:lower(), n = tonumber(n) }
    end
    local name = ns.TrustName(sender)
    if not name then
        stats.refused = stats.refused + 1
        return
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok then
            stats.refused = stats.refused + 1
            return
        end
        if pull and pull.low == name:lower() then return end
        queuePeer(name, weeks)
        startNext()
    end)
end)

ns.CommOn("DI", function(sender, f, chan)
    if chan ~= "WHISPER" or not pull or pull.stage ~= "DI" then return end
    local name = ns.TrustName(sender)
    if not name or name:lower() ~= pull.low or tonumber(f[1]) ~= pull.w then return end
    local i, n = tonumber(f[2]), tonumber(f[3])
    if pull.n and pull.n ~= n then
        stats.bad = stats.bad + 1
        pull = nil
        return startNext()
    end
    pull.n = n
    if not pull.parts[i] then
        pull.parts[i] = f[4]
        pull.got = pull.got + 1
    end
    if pull.got < n then return end
    -- every bucket of the sender that is missing here or differs
    local ix, today, drs = indexNow(), ns.DropsToday(), {}
    for p = 1, n do
        if pull.parts[p] ~= "-" then
            for e in (pull.parts[p] .. ","):gmatch("([^,]*),") do
                local day, inst, h, cnt = e:match("^(%d+):(%d+):(%x+):(%d+)$")
                day, inst, cnt = tonumber(day), tonumber(inst), tonumber(cnt)
                if day and day >= today - ns.DROPS_KEEP_DAYS + 1 and day <= today + 1 then
                    local key = ns.DropsDate(day) .. ":" .. inst
                    local mine = ix.buckets[key]
                    if not mine or mine.hash ~= h:lower() or #mine.ids ~= cnt then
                        drs[#drs + 1] = { key = key, ids = mine and mine.ids or {} }
                    end
                end
            end
        end
    end
    pull.drs, pull.stage = drs, "DR"
    nextDR()
end)

-- A blob checked whole: { v = 1, r = { { h, npc, inst, diff, day, o, enc, { id, n, ... }, src } },
-- n = { [npc] = name }, z = { [inst] = { kind, name } }, e = { [enc] = name } }; every record of the
-- bucket key. Returns the records and the names, or nil.
local function size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function checkNames(t, lo, hi)
    if t == nil then return {} end
    if type(t) ~= "table" or size(t) > L.blobRecords then return nil end
    local out = {}
    for k, v in pairs(t) do
        if not int(k, lo, hi) or not nameOk(v) then return nil end
        out[k] = v
    end
    return out
end

local function checkBlob(tbl, key)
    if type(tbl) ~= "table" or tbl.v ~= 1 or type(tbl.r) ~= "table" then return nil end
    local n = #tbl.r
    if n < 1 or n > L.blobRecords or size(tbl.r) ~= n then return nil end
    local date, kinst = key:match("^(%d%d%d%d%-%d%d%-%d%d):(%d+)$")
    local kday = ns.DropsDay(date)
    kinst = tonumber(kinst)
    if not kday or not kinst then return nil end
    local today, out = ns.DropsToday(), {}
    for i = 1, n do
        local x = tbl.r[i]
        if type(x) ~= "table" then return nil end
        local h, npc, inst, diff, day, o, enc, items, src = x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9]
        if not isHex8(h) or not isHex8(o) or not int(enc, 0, 99999999) or day ~= kday or inst ~= kinst then return nil end
        if type(items) ~= "table" or #items % 2 ~= 0 or #items > 60 or size(items) ~= #items then return nil end
        local it = {}
        for j = 1, #items, 2 do
            local id, c = items[j], items[j + 1]
            if not int(id, 1, 9999999) or not int(c, 1, 200) or it[id] then return nil end
            it[id] = c
        end
        local r = { h = h:lower(), npc = npc, inst = inst, diff = diff, day = day, o = o:lower(), enc = enc > 0 and enc or nil, it = it, src = src }
        if not ns.DropsValidRecord(r, today) then return nil end
        out[i] = r
    end
    local names, encs = checkNames(tbl.n, 1, 9999999), checkNames(tbl.e, 1, 99999999)
    if not names or not encs then return nil end
    local zones = {}
    if tbl.z ~= nil then
        if type(tbl.z) ~= "table" or size(tbl.z) > L.blobRecords then return nil end
        for k, v in pairs(tbl.z) do
            if not int(k, 1, 99999) or type(v) ~= "table" or (v[1] ~= "party" and v[1] ~= "raid") or not nameOk(v[2]) then return nil end
            zones[k] = { v[1], v[2] }
        end
    end
    return out, names, zones, encs
end

ns.CommOnBlob("DK", function(sender, tbl, chan, key)
    if chan ~= "WHISPER" then
        stats.bad = stats.bad + 1
        return
    end
    local name = ns.TrustName(sender)
    local low = name and name:lower()
    local at = low and asked[key .. "|" .. low]
    if not at or now() - at > L.askKeep then
        -- nobody asked for this bucket: nothing is pushed into the records
        stats.unasked = stats.unasked + 1
        debugLine("Drop-Daten ohne Anfrage verworfen.")
        return
    end
    local recs, names, zones, encs = checkBlob(tbl, key)
    if not recs then
        stats.bad = stats.bad + 1
        debugLine("Ungültige Drop-Daten verworfen.")
        return
    end
    stats.blobs = stats.blobs + 1
    for _, r in ipairs(recs) do
        stats.records = stats.records + 1
        local result = ns.DropsMerge(r)
        if result == "new" then stats.new = stats.new + 1 elseif result == "merged" then stats.merged = stats.merged + 1 end
    end
    ns.DropsLearnNames(names, zones, encs)
    local d = ns.DropsDB()
    if d then d.heard = time() end
    if pull and pull.stage == "DK" and pull.low == low and pull.key == key then nextDR() end
end)

---------------------------------------------------------------------------
-- Answering: DQ with the buckets of a week, DR with a blob of the missing records
---------------------------------------------------------------------------
-- fn(name) for a member asking by whisper while the exchange may talk.
local function fromMember(sender, chan, fn)
    if chan ~= "WHISPER" or not AmisiaDB or not ns.Get("drops.share") then return end
    local name = ns.TrustName(sender)
    if not name then
        stats.refused = stats.refused + 1
        return
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok then
            stats.refused = stats.refused + 1
            return
        end
        if canTalk() then fn(name) end
    end)
end

ns.CommOn("DQ", function(sender, f, chan)
    fromMember(sender, chan, function(name)
        local w = tonumber(f[1])
        local parts, cur, len = {}, {}, 0
        for _, b in ipairs(indexNow().weeks[w].list) do
            local e = ("%d:%d:%s:%d"):format(b.day, b.inst, b.hash, #b.ids)
            if #cur >= L.diEntries or len + #e + 1 > L.diChars then
                parts[#parts + 1] = table.concat(cur, ",")
                cur, len = {}, 0
            end
            cur[#cur + 1] = e
            len = len + #e + 1
        end
        if #cur > 0 then parts[#parts + 1] = table.concat(cur, ",") end
        if #parts == 0 then parts[1] = "-" end
        local n = math.min(#parts, 20)
        for i = 1, n do
            if not send("DI", { tostring(w), tostring(i), tostring(n), parts[i] }, "WHISPER", name) then break end
        end
    end)
end)

ns.CommOn("DR", function(sender, f, chan)
    fromMember(sender, chan, function(name)
        local key = f[1]
        local b = indexNow().buckets[key]
        if not b then return end
        local known = {}
        if f[2] ~= "*" then
            for id in (f[2] .. ","):gmatch("([^,]*),") do known[id:lower()] = true end
        end
        local ids = {}
        for _, id in ipairs(b.ids) do
            if not known[id] then ids[#ids + 1] = id end
        end
        if #ids == 0 then return end
        local low = name:lower()
        for i, s in ipairs(serve) do
            if s.low == low and s.key == key then table.remove(serve, i) break end
        end
        if #serve >= L.serveMax then return end
        serve[#serve + 1] = { name = name, low = low, key = key, ids = ids, at = now() }
    end)
end)

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- The blob of records ids: the records, and the names of their bosses and instances.
local function wire(ids)
    local d = ns.DropsDB()
    local t = { v = 1, r = {}, n = {}, z = {}, e = {} }
    for _, id in ipairs(ids) do
        local r = d.k[id]
        if r then
            local items = {}
            for _, item in ipairs(sortedKeys(r.it)) do
                items[#items + 1] = item
                items[#items + 1] = r.it[item]
            end
            t.r[#t.r + 1] = { id, r.npc, r.inst, r.diff, r.day, r.o, r.enc or 0, items, r.src }
            if r.npc > 0 and d.npc[r.npc] then t.n[r.npc] = d.npc[r.npc] end
            if r.npc == 0 and r.enc and d.enc[r.enc] then t.e[r.enc] = d.enc[r.enc] end
            local z = d.inst[r.inst]
            if z then t.z[r.inst] = { z[1], z[2] } end
        end
    end
    for _, f in ipairs({ "n", "z", "e" }) do
        if not next(t[f]) then t[f] = nil end
    end
    return t
end

local function partsRecent()
    local t, keep, n = now(), {}, 0
    for _, p in ipairs(partsLog) do
        if t - p[1] < L.partsWindow then
            keep[#keep + 1] = p
            n = n + p[2]
        end
    end
    partsLog = keep
    return n
end

-- One blob of the first waiting request, when the gaps allow it. A bucket too big for 20 parts goes
-- in halves (by id), one blob at a time.
local function serveOne()
    if #serve == 0 or not canTalk() then return end
    local t = now()
    if lastBlob and t - lastBlob < L.serveGap then return end
    local s = serve[1]
    if t - s.at > L.serveKeep then
        table.remove(serve, 1)
        return
    end
    local ids, tbl, packed = s.ids, nil, nil
    while true do
        if #ids <= L.blobRecords then
            tbl = wire(ids)
            if #tbl.r == 0 then
                table.remove(serve, 1)
                return
            end
            packed = ns.CommPack(tbl)
            if not packed then
                table.remove(serve, 1)
                return
            end
            if math.ceil(#packed / 200) <= L.blobParts then break end
        end
        if #ids <= 1 then
            table.remove(serve, 1)
            return
        end
        local half = {}
        for i = 1, math.ceil(#ids / 2) do half[i] = ids[i] end
        ids = half
    end
    local parts = math.ceil(#packed / 200)
    if partsRecent() + parts > L.partsMax then return end
    local estimate = #packed + parts * PART_OVERHEAD
    if not afford(estimate) then
        debugLine("Sendegrenze der Sitzung erreicht.")
        table.remove(serve, 1)
        return
    end
    local ok, n, bytes = ns.CommSendBlob("DK", s.key, tbl, "WHISPER", s.name, { low = true, when = canTalk })
    if not ok then
        table.remove(serve, 1)
        return
    end
    stats.bytes = stats.bytes + (bytes or estimate)
    stats.served = stats.served + 1
    lastBlob = t
    partsLog[#partsLog + 1] = { t, n or parts }
    if #ids < #s.ids then
        local rest = {}
        for i = #ids + 1, #s.ids do rest[#rest + 1] = s.ids[i] end
        s.ids = rest
    else
        table.remove(serve, 1)
    end
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------
local function tick()
    if not AmisiaDB then return end
    local t = now()
    if pull and not canTalk() then
        stopPull(true)
    elseif pull and t > pull.deadline then
        if pull.stage == "DK" then
            nextDR()
        else
            -- the sender went quiet
            pull = nil
        end
    end
    if not pull then startNext() end
    announce()
    serveOne()
    for k, at in pairs(asked) do
        if t - at > L.askKeep then asked[k] = nil end
    end
end

C_Timer.NewTicker(L.tick, function()
    local ok, err = pcall(tick)
    if not ok then report(err) end
end)

-- The weekly whole-bucket marks: valid keys of the kept days only.
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ADDON or not AmisiaDB then return end
    local d = ns.DropsDB()
    if not d then return end
    if type(d.star) ~= "table" then
        d.star = nil
        return
    end
    local min = ns.DropsToday() - ns.DROPS_KEEP_DAYS + 1
    for key, at in pairs(d.star) do
        local day = type(key) == "string" and ns.DropsDay(key:match("^(%d%d%d%d%-%d%d%-%d%d):%d+$"))
        if not day or day < min or type(at) ~= "number" then d.star[key] = nil end
    end
end)

-- { bytes, dv, dq, di, dr, served, blobs, records, new, merged, bad, unasked, refused, pulls, drHour }
function ns.DropSyncStats()
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    out.drHour = hourCount()
    return out
end

-- { pulling = name or nil, waiting = peers heard, serving = requests waiting }
function ns.DropSyncState()
    return { pulling = pull and pull.name or nil, waiting = #peers, serving = #serve }
end
