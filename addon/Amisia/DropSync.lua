-- Amisia drop exchange: guild members share their drop records (Drops.lua) quietly, pulling only
-- what they miss. A client announces what it holds to the guild (DV: per week of the last four a
-- checksum and a count); whoever hears a different week asks that one sender (DQ), gets its buckets
-- (DI: day and instance with checksum and count), and asks for the buckets that differ (DR, up to 12
-- buckets in one request, naming per bucket the ids it already has with a digest of their items);
-- the answer is a DK blob with only the missing or different records (a big answer in two halves).
-- Both sides pull, neither pushes: a blob nobody asked for is dropped, and a request takes exactly
-- its one answer. A busy sender says so (DW) and the asker tries another sender or comes back later.
-- Everything goes at the lowest priority of the queue, only between guild members, never in an
-- instance, in combat, in the lockdown or while a raid is synced, within fixed caps. Records are
-- merged (Drops.lua), never overwritten; no names are sent or stored but the bosses' and
-- instances'.
--
-- Drop protocol 2 (1 checked ids only; 2 adds the items to the checksums, groups buckets in one
-- request and answers busy with DW): clients of protocol 1 and 2 ignore each other's DV, so they
-- never pull from each other.
local ADDON, ns = ...

ns.DROP_PROTO = 2

-- the caps and times; a table so a test can lower one
local L = {
    firstMin = 60, firstSpread = 120,   -- the first announcement 60 to 180 s after the login
    every = 1800,                       -- later ones at most every 30 minutes, after new records
    tick = 5,
    diWait = 60,                        -- seconds the bucket list of a week may take
    drWait = 90,                        -- seconds a request waits for its blob (one open at a time)
    askKeep = 600,                      -- seconds the answer to a request is still taken
    drPerHour = 30,
    drBuckets = 12, drRecords = 100,    -- buckets and (by the sender's counts) records of one request
    serveGap = 30, partsWindow = 600, partsMax = 40,   -- an answering client: a blob per 30 s, 40 parts per 10 min
    blobParts = 20, blobRecords = 300,
    sessionBytes = 61440,               -- everything this module sends in a session
    askerShare = 3,                     -- one asker gets at most a third of that
    peerKeep = 1800, peersMax = 10,     -- announcements heard and not pulled yet
    pullJitter = 30,                    -- a pull starts 0 to 30 s after the announcement
    serveMax = 12, servePerAsker = 2, serveKeep = 1200,   -- requests waiting for their blob
    servePeers = 2, activeKeep = 120,   -- askers served at once (seen within 120 s)
    busyWait = 120,                     -- what a busy client tells an asker to wait
    originMax = 600, senderMax = 1500,  -- new records per origin and per sender in a session
    starEvery = 7 * 86400,              -- a whole bucket ("*") at most once a week per bucket
    listMax = 16, diEntries = 12, diChars = 200, drChars = 230,
}
ns.DROPSYNC_LIMITS = L

local PART_OVERHEAD = 45   -- prefix and fields of one data part, above its 200 characters

local stats = { bytes = 0, dv = 0, dq = 0, di = 0, dr = 0, dw = 0, served = 0, blobs = 0, records = 0, new = 0, merged = 0,
                bad = 0, unasked = 0, refused = 0, pulls = 0, listed = 0, capped = 0, busy = 0 }
local drTimes = {}        -- GetTime() of the requests of the last hour
local asked = {}          -- "first key|lower name" -> { at, keys = { [key] = { known, cnt } }, blobs, recs, max }
local peers = {}          -- { name, low, weeks, at, nb }: announcements heard, waiting to be pulled (nb: not before)
local pull                -- the one pull running: { name, low, weeks, wants, wi, w, stage, parts, n, got, drs, akey, deadline }
local serve = {}          -- { name, low, key, ids, at, rest }: requests this client answers
local askers = {}         -- lower name -> { bytes, at (last seen), served (last blob) }
local lastBlob
local partsLog = {}       -- { GetTime(), parts } of the blobs sent
local originNew, senderNew = {}, {}
local firstAt, announced, lastDV, addedAtDV, learnedAtDV, reannounced, emptyAtFirst
local learned = 0         -- records new to this client from the exchange this session

local function now() return GetTime() end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function hex4(s) return ns.Checksum(s):sub(13, 16) end
local function isHex8(v) return type(v) == "string" and #v == 8 and v:match("^%x+$") ~= nil end
local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function nameOk(v) return type(v) == "string" and ns.DropsCleanName(v) == v end

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
-- Sending, within the session's bytes and each asker's share of them
---------------------------------------------------------------------------
local function askerOf(low)
    local a = askers[low]
    if not a then
        a = { bytes = 0 }
        askers[low] = a
    end
    return a
end

-- Whether n more bytes fit the session, and (for an answer to low) that asker's share.
local function afford(n, low)
    if stats.bytes + n > L.sessionBytes then return false end
    if low and askerOf(low).bytes + n > L.sessionBytes / L.askerShare then return false end
    return true
end

local function charge(n, low)
    stats.bytes = stats.bytes + n
    if low then askerOf(low).bytes = askerOf(low).bytes + n end
end

-- low: the asker this message answers (its bytes count against its share).
local function send(kind, fields, chan, target, key, low)
    local n = #"Amisia" + #tostring(ns.SYNC_PROTO) + #kind + 1 + #table.concat(fields, "\t")
    if not afford(n, low) then
        debugLine("Sendegrenze erreicht.")
        return false
    end
    local ok = ns.CommSend(kind, fields, chan, target, { low = true, when = canTalk, key = key })
    if not ok then return false end
    charge(n, low)
    stats[kind:lower()] = stats[kind:lower()] + 1
    return true
end

---------------------------------------------------------------------------
-- Buckets (day and instance) and weeks of the own records
---------------------------------------------------------------------------
local index
ns.Listen("DROPS_CHANGED", function() index = nil end)

-- The digest of a record's items and encounter (4 hex), kept per item table (a merge replaces it).
local digests = setmetatable({}, { __mode = "k" })
local function digest(r)
    local c = digests[r.it]
    if c and c[1] == (r.enc or 0) then return c[2] end
    local ids = {}
    for id in pairs(r.it) do ids[#ids + 1] = id end
    table.sort(ids)
    for i, id in ipairs(ids) do ids[i] = id .. ":" .. r.it[id] end
    local h = hex4(tostring(r.enc or 0) .. ";" .. table.concat(ids, ","))
    digests[r.it] = { r.enc or 0, h }
    return h
end

-- { today, buckets = { [key] = { key, day, inst, ids (sorted), dig = { [id] = digest }, hash, w } },
--   weeks = { [0..3] = { n, hash, list } }, total, newest }. A bucket's checksum covers its ids and
-- the digests of their items, so two clients with the same kills but other items pull too.
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
                b = { key = key, day = r.day, inst = r.inst, ids = {}, dig = {}, w = w }
                buckets[key] = b
            end
            b.ids[#b.ids + 1] = id
            b.dig[id] = digest(r)
            total = total + 1
            if not newest or r.day > newest then newest = r.day end
        end
    end
    local weeks = {}
    for w = 0, 3 do weeks[w] = { n = 0, list = {} } end
    for _, b in pairs(buckets) do
        table.sort(b.ids)
        local parts = {}
        for i, id in ipairs(b.ids) do parts[i] = id .. b.dig[id] end
        b.hash = hex4(table.concat(parts, ","))
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
local function setFirst()
    if firstAt then return end
    local d = ns.DropsDB()
    local spread = d and tonumber(d.me:sub(1, 4), 16) or 0
    firstAt = now() + L.firstMin + spread % (L.firstSpread + 1)
end
ns.OnEvent("PLAYER_LOGIN", setFirst)

-- The first DV at its time when there is something to offer; a client that had nothing then
-- announces as soon as it has records and its pull is done (so the guild can pull from it too).
-- Later DVs at most every 30 minutes: after new own records, and once in a session after records
-- learned from the guild.
local function announce()
    -- a client that learned records before its login was seen (a /reload keeps no login) still
    -- announces them
    if not firstAt and learned > 0 then setFirst() end
    if not firstAt or now() < firstAt or not canTalk() then return end
    local total = indexNow().total
    if not announced then
        if total == 0 then
            emptyAtFirst = true
        elseif not (emptyAtFirst and pull) and sendDV() then
            announced, lastDV, addedAtDV, learnedAtDV = true, now(), ns.DropsAdded(), learned
        end
        return
    end
    if now() - lastDV < L.every then return end
    local own = ns.DropsAdded() > addedAtDV
    local heard = not reannounced and learned > learnedAtDV
    if (own or heard) and sendDV() then
        if heard then reannounced = true end
        lastDV, addedAtDV, learnedAtDV = now(), ns.DropsAdded(), learned
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

local function queuePeer(name, weeks, at, nb)
    local low = name:lower()
    for i, p in ipairs(peers) do
        if p.low == low then table.remove(peers, i) break end
    end
    peers[#peers + 1] = { name = name, low = low, weeks = weeks, at = at or now(), nb = nb or now() }
    while #peers > L.peersMax do table.remove(peers, 1) end
end

-- Stops the pull; a peer that was cut off by the conditions (not by silence) waits again.
local function stopPull(again)
    if pull and again then queuePeer(pull.name, pull.weeks, pull.at, now()) end
    pull = nil
end

-- The next pull: a random one of the senders heard that may be asked now (so the listeners of one
-- announcement spread over the senders that hold the same).
startNext = function()
    if pull or not canTalk() then return end
    local t, ready = now(), {}
    for i = #peers, 1, -1 do
        local p = peers[i]
        if t - p.at > L.peerKeep then
            table.remove(peers, i)
        elseif p.nb <= t then
            ready[#ready + 1] = i
        end
    end
    while #ready > 0 do
        local pick = math.random(#ready)
        local i = ready[pick]
        local p = table.remove(peers, i)
        table.remove(ready, pick)
        for j, x in ipairs(ready) do if x > i then ready[j] = x - 1 end end
        local wants = wantsOf(p.weeks)
        if #wants > 0 then
            pull = { name = p.name, low = p.low, weeks = p.weeks, at = p.at, wants = wants, wi = 0 }
            stats.pulls = stats.pulls + 1
            return nextWeek()
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

-- The known field of a bucket in a request: the own ids with their digests (16 at most), or "*" for
-- a bucket without own records or with more than 16 of them (a whole bucket at most once a week).
-- Returns the field and the known ids { [id] = digest }.
local function knownField(key, b)
    if not b or #b.ids == 0 then return "*", {} end
    local d = ns.DropsDB()
    if #b.ids > L.listMax then
        d.star = type(d.star) == "table" and d.star or {}
        local last = d.star[key]
        if not last or time() - last >= L.starEvery then
            d.star[key] = time()
            return "*", {}
        end
    end
    local parts, known = {}, {}
    for i = 1, math.min(#b.ids, L.listMax) do
        local id = b.ids[i]
        parts[i] = id .. b.dig[id]
        known[id] = b.dig[id]
    end
    return table.concat(parts, ","), known
end

-- The next request: as many waiting buckets as fit one message, 12 and (by the sender's counts) 100
-- records at most.
nextDR = function()
    if #pull.drs == 0 then return nextWeek() end
    if hourCount() >= L.drPerHour then
        debugLine("30 Anfragen in der Stunde erreicht.")
        return stopPull(true)
    end
    local ix = indexNow()
    local fields, keys, len, cnt, nb = {}, {}, 0, 0, 0
    while #pull.drs > 0 and nb < L.drBuckets do
        local dr = pull.drs[1]
        local field, known = knownField(dr.key, ix.buckets[dr.key])
        local add = #dr.key + #field + 2
        if nb > 0 and (len + add > L.drChars or cnt + dr.cnt > L.drRecords) then break end
        table.remove(pull.drs, 1)
        fields[#fields + 1], fields[#fields + 2] = dr.key, field
        keys[dr.key] = { known = known, cnt = dr.cnt }
        len, cnt, nb = len + add, cnt + dr.cnt, nb + 1
    end
    if not send("DR", fields, "WHISPER", pull.name) then return stopPull(false) end
    drTimes[#drTimes + 1] = now()
    local akey = fields[1] .. "|" .. pull.low
    asked[akey] = { at = now(), keys = keys, blobs = 0, recs = 0, max = math.min(cnt, L.blobRecords) }
    pull.stage, pull.akey, pull.deadline = "DK", akey, now() + L.drWait
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
        queuePeer(name, weeks, now(), now() + math.random() * L.pullJitter)
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
                if day and day >= today - ns.DROPS_KEEP_DAYS + 1 and day <= today then
                    local key = ns.DropsDate(day) .. ":" .. inst
                    local mine = ix.buckets[key]
                    if not mine or mine.hash ~= h:lower() or #mine.ids ~= cnt then
                        drs[#drs + 1] = { key = key, cnt = cnt }
                    end
                end
            end
        end
    end
    pull.drs, pull.stage = drs, "DR"
    nextDR()
end)

-- A busy sender: its pull ends, the sender is asked again after the wait, another one first.
ns.CommOn("DW", function(sender, f, chan)
    if chan ~= "WHISPER" or not pull then return end
    local name = ns.TrustName(sender)
    if not name or name:lower() ~= pull.low then return end
    stats.busy = stats.busy + 1
    if pull.akey then asked[pull.akey] = nil end
    local wait = math.max(30, math.min(tonumber(f[1]) or L.busyWait, 3600))
    queuePeer(pull.name, pull.weeks, now(), now() + wait + math.random() * L.pullJitter)
    pull = nil
    startNext()
end)

-- A blob checked whole: { v = 1, m = 1 when a second half follows, r = { { h, npc, inst, diff, day,
-- o, enc, { id, n, ... }, src } }, n = { [npc] = name }, z = { [inst] = { kind, name } }, e = { [enc]
-- = name } }; every record of a bucket of the request, not more per bucket than the sender counted
-- there. Returns the records and the names, or nil.
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

local function checkBlob(tbl, ask)
    if type(tbl) ~= "table" or tbl.v ~= 1 or type(tbl.r) ~= "table" or (tbl.m ~= nil and tbl.m ~= 1) then return nil end
    local n = #tbl.r
    if n < 1 or n > L.blobRecords or size(tbl.r) ~= n then return nil end
    local maxItems, maxCount = ns.DROPS_MAX_ITEMS, ns.DROPS_MAX_COUNT
    local today, out, per = ns.DropsToday(), {}, {}
    for i = 1, n do
        local x = tbl.r[i]
        if type(x) ~= "table" then return nil end
        local h, npc, inst, diff, day, o, enc, items, src = x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9]
        if not isHex8(h) or not isHex8(o) or not int(enc, 0, 99999999) or not int(day, 0, today) or not int(inst, 1, 99999) then return nil end
        local key = ns.DropsDate(day) .. ":" .. inst
        local k = ask.keys[key]
        if not k then return nil end
        per[key] = (per[key] or 0) + 1
        if per[key] > k.cnt then return nil end
        if type(items) ~= "table" or #items % 2 ~= 0 or #items > 2 * maxItems or size(items) ~= #items then return nil end
        local it = {}
        for j = 1, #items, 2 do
            local id, c = items[j], items[j + 1]
            if not int(id, 1, 9999999) or not int(c, 1, maxCount) or it[id] then return nil end
            it[id] = c
        end
        local r = { h = h:lower(), npc = npc, inst = inst, diff = diff, day = day, o = o:lower(), enc = enc > 0 and enc or nil, it = it, src = src }
        if not ns.DropsValidRecord(r, today) then return nil end
        r.key = key
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

-- Rules for what an answer may bring: only records of the asked buckets; a record the request named
-- as known with the same digest is dropped (the sender had to leave it out); at most as many
-- records per request as the sender counted (300 at most), and per session at most 600 new records
-- of one origin and 1500 from one sender. The items of a heard record never go beyond the caps of
-- Drops.lua (16 items, 20 each), whatever the blob says.
ns.CommOnBlob("DK", function(sender, tbl, chan, key)
    if chan ~= "WHISPER" then
        stats.bad = stats.bad + 1
        return
    end
    local name = ns.TrustName(sender)
    local low = name and name:lower()
    local akey = low and (key .. "|" .. low)
    local ask = akey and asked[akey]
    if not ask or now() - ask.at > L.askKeep then
        -- nobody asked for this, or its answer came already: nothing is pushed into the records
        stats.unasked = stats.unasked + 1
        debugLine("Drop-Daten ohne Anfrage verworfen.")
        return
    end
    local recs, names, zones, encs = checkBlob(tbl, ask)
    if not recs then
        stats.bad = stats.bad + 1
        debugLine("Ungültige Drop-Daten verworfen.")
        return
    end
    stats.blobs = stats.blobs + 1
    local d = ns.DropsDB()
    local take = {}
    for _, r in ipairs(recs) do
        local known = ask.keys[r.key].known[r.h]
        r.key = nil
        if known and known == digest(r) then
            stats.listed = stats.listed + 1
        elseif ask.recs >= ask.max then
            stats.capped = stats.capped + 1
        elseif d and not d.k[r.h] and ((originNew[r.o] or 0) >= L.originMax or (senderNew[low] or 0) >= L.senderMax) then
            stats.capped = stats.capped + 1
        else
            ask.recs = ask.recs + 1
            if d and not d.k[r.h] then
                originNew[r.o] = (originNew[r.o] or 0) + 1
                senderNew[low] = (senderNew[low] or 0) + 1
            end
            take[#take + 1] = r
        end
    end
    stats.records = stats.records + #take
    local _, n = ns.DropsMergeAll(take)
    stats.new, stats.merged = stats.new + n.new, stats.merged + n.merged
    learned = learned + n.new
    ns.DropsLearnNames(names, zones, encs)
    if d then d.heard = time() end
    -- a request takes its one answer: one blob, or the two halves of a big one
    ask.blobs = ask.blobs + 1
    local done = tbl.m == nil or ask.blobs >= 2
    if done then asked[akey] = nil end
    if pull and pull.stage == "DK" and pull.akey == akey then
        if done then nextDR() else pull.deadline = now() + L.drWait end
    end
end)

---------------------------------------------------------------------------
-- Answering: DQ with the buckets of a week, DR with a blob of the missing records, DW when busy
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

-- Askers served at once: those seen within two minutes or with a request waiting. Another one is
-- busy-waited (DW) while two are being served.
local function busyFor(low)
    local t, active = now(), {}
    for x, a in pairs(askers) do
        if a.at and t - a.at < L.activeKeep then active[x] = true end
    end
    for _, s in ipairs(serve) do active[s.low] = true end
    if active[low] then return false end
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n >= L.servePeers
end

-- The share of this asker is used up: it gets no more answers this session.
local function shareLeft(low) return askerOf(low).bytes < L.sessionBytes / L.askerShare end

local function sendDW(name, low)
    send("DW", { tostring(L.busyWait) }, "WHISPER", name, nil, low)
end

ns.CommOn("DQ", function(sender, f, chan)
    fromMember(sender, chan, function(name)
        local low = name:lower()
        if not shareLeft(low) then return end
        if busyFor(low) then return sendDW(name, low) end
        askerOf(low).at = now()
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
            if not send("DI", { tostring(w), tostring(i), tostring(n), parts[i] }, "WHISPER", name, nil, low) then break end
        end
    end)
end)

ns.CommOn("DR", function(sender, f, chan)
    fromMember(sender, chan, function(name)
        local low = name:lower()
        if not shareLeft(low) then return end
        local ix, ids = indexNow(), {}
        for i = 1, #f - 1, 2 do
            local b = ix.buckets[f[i]]
            if b then
                local known = {}
                if f[i + 1] ~= "*" then
                    for e in (f[i + 1] .. ","):gmatch("([^,]*),") do known[e:sub(1, 8):lower()] = e:sub(9, 12):lower() end
                end
                -- what the asker lacks, or holds with other items
                for _, id in ipairs(b.ids) do
                    if known[id] ~= b.dig[id] then ids[#ids + 1] = id end
                end
            end
        end
        if #ids == 0 then return end
        local key, mine = f[1], 0
        for i = #serve, 1, -1 do
            local s = serve[i]
            if s.low == low then
                if s.key == key then table.remove(serve, i) else mine = mine + 1 end
            end
        end
        if busyFor(low) or mine >= L.servePerAsker or #serve >= L.serveMax then return sendDW(name, low) end
        askerOf(low).at = now()
        serve[#serve + 1] = { name = name, low = low, key = key, ids = ids, at = now() }
    end)
end)

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- The blob of records ids: the records, and the names of their bosses and instances; m = 1 when a
-- second half follows.
local function wire(ids, more)
    local d = ns.DropsDB()
    local t = { v = 1, r = {}, n = {}, z = {}, e = {}, m = more and 1 or nil }
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

-- The longest front of ids that packs into one blob (20 parts, 300 records): ids, table, packed.
local function fit(ids, more)
    local n = math.min(#ids, L.blobRecords)
    for _ = 1, 8 do
        local list = {}
        for i = 1, n do list[i] = ids[i] end
        local tbl = wire(list, more)
        if #tbl.r == 0 then return nil end
        local packed = ns.CommPack(tbl)
        if not packed then return nil end
        local parts = math.ceil(#packed / 200)
        if parts <= L.blobParts then return list, tbl, packed end
        if n <= 1 then return nil end
        n = math.max(1, math.min(n - 1, math.floor(n * L.blobParts / parts * 0.95)))
    end
    return nil
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

-- The waiting request to serve next: the asker served longest ago first, then the oldest request.
local function nextServe()
    local t, best = now(), nil
    for i = #serve, 1, -1 do
        if t - serve[i].at > L.serveKeep then table.remove(serve, i) end
    end
    for i, s in ipairs(serve) do
        local last = askerOf(s.low).served or -math.huge
        if not best or last < best.last then best = { i = i, last = last } end
    end
    return best and best.i
end

-- One blob of a waiting request, when the gaps allow it. An answer too big for one blob goes in two
-- halves (by id), one blob at a time; what does not fit a half is left for a later request.
local function serveOne()
    if #serve == 0 or not canTalk() then return end
    local t = now()
    if lastBlob and t - lastBlob < L.serveGap then return end
    local i = nextServe()
    if not i then return end
    local s = serve[i]
    local ids, tbl, packed, more
    if s.rest then
        ids, tbl, packed = fit(s.ids, false)
    else
        ids, tbl, packed = fit(s.ids, false)
        if ids and #ids < #s.ids then
            local half = {}
            for j = 1, math.ceil(#s.ids / 2) do half[j] = s.ids[j] end
            ids, tbl, packed = fit(half, true)
            more = true
        end
    end
    if not ids then
        table.remove(serve, i)
        return
    end
    local parts = math.ceil(#packed / 200)
    if partsRecent() + parts > L.partsMax then return end
    local estimate = #packed + parts * PART_OVERHEAD
    if not afford(estimate, s.low) then
        debugLine("Sendegrenze erreicht.")
        table.remove(serve, i)
        return
    end
    local ok, n, bytes = ns.CommSendBlob("DK", s.key, tbl, "WHISPER", s.name, { low = true, when = canTalk })
    if not ok then
        table.remove(serve, i)
        return
    end
    charge(bytes or estimate, s.low)
    stats.served = stats.served + 1
    lastBlob = t
    local a = askerOf(s.low)
    a.served, a.at = t, t
    partsLog[#partsLog + 1] = { t, n or parts }
    if more then
        -- the second half: the ids after the first half
        local rest = {}
        for j = math.ceil(#s.ids / 2) + 1, #s.ids do rest[#rest + 1] = s.ids[j] end
        s.ids, s.rest, s.at = rest, true, t
    else
        table.remove(serve, i)
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
    for k, a in pairs(asked) do
        if t - a.at > L.askKeep then asked[k] = nil end
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

-- { bytes, dv, dq, di, dr, dw, served, blobs, records, new, merged, bad, unasked, refused, pulls,
--   listed, capped, busy, drHour }
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

-- The bytes sent to one asker this session (its share is a third of the session's).
function ns.DropSyncAskerBytes(name)
    local a = type(name) == "string" and askers[name:lower()]
    return a and a.bytes or 0
end
