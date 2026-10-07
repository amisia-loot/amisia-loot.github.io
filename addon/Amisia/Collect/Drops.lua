-- Amisia drop records: every boss kill whose loot window the player opens in a dungeon or raid
-- becomes one record, keyed by a hash of the corpse GUID (the same corpse gives the same key on
-- every client, so a kill counts once however many guild members record it). A record holds the
-- NPC, the instance, the difficulty, the day, a random client id as its origin and the items of the
-- window, never a player name. Records are kept 28 days (4000 at most); the guild shares them
-- (DropSync.lua), the website reads them from the text "Drops für die Website", and the observed
-- drop rates per boss come from them plus the generated base stock (ns.BIS.O).
--
-- The items of a record stay within fixed caps wherever they come from (own loot window, another
-- client, the saved table): at most 16 different items (the loot slots of one corpse) and at most
-- 20 of one item. Above that the 16 lowest item ids stay and a count is cut to 20, so two clients
-- that merge the same records always reach the same items, and a heard record can never blow up an
-- own one.
local ADDON, ns = ...

local EPOCH = 1767225600      -- 2026-01-01 00:00 UTC: day 0 of the records
local KEEP_DAYS = 28
local MAX_RECORDS = 4000
local MAX_NAMES = 2000
local MAX_ENCS = 2000
local MAX_INSTS = 500
local MAX_PEERS = 500
local KILL_WINDOW = 120       -- seconds between a kill event and the loot window of its corpse
local MAX_ITEMS, MAX_COUNT = 16, 20
local MAX_NAME = 48
local MIN_QUALITY = 2         -- uncommon and better count, recipes of any quality
local RARE = 3                -- a window with a rare item is a boss (every boss drops one on Forever)
local CLASS_RECIPE = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9
local SMOOTH = 3              -- weight of the expected chance in the observed rate
local SHOW_RATE_FROM = 5      -- kills before a rate is shown as a share

ns.DROPS_KEEP_DAYS = KEEP_DAYS
ns.DROPS_MAX_ITEMS, ns.DROPS_MAX_COUNT = MAX_ITEMS, MAX_COUNT

-- the last boss kill event in an instance: { enc, name, t, inst, used = record id, rank = rank of
-- that corpse, made = the record was made for the event, named = npc named after the event }
local lastKill
local nameless = {}   -- npc -> true: a record of this NPC still waits for its name
local added = 0       -- own new records this session (the exchange announces after new ones)
local version = 0     -- bumped on every change (rate sums are rebuilt after one)

local function now() return (GetServerTime and GetServerTime()) or time() end

local function hex8(s) return ns.Checksum(s):sub(9, 16) end
local function isHex8(v) return type(v) == "string" and #v == 8 and v:match("^%x+$") ~= nil end
local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end

---------------------------------------------------------------------------
-- Days and dates (UTC, without the client's time zone)
---------------------------------------------------------------------------
local function daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

local function civil(z)
    z = z + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end

local DAY0 = daysFromCivil(2026, 1, 1)

-- Days since 2026-01-01 (server time, UTC).
function ns.DropsToday(t)
    return math.floor(((t or now()) - EPOCH) / 86400)
end

-- "YYYY-MM-DD" of a day number.
function ns.DropsDate(day)
    local y, m, d = civil(DAY0 + day)
    return ("%04d-%02d-%02d"):format(y, m, d)
end

-- The day number of "YYYY-MM-DD", or nil.
function ns.DropsDay(text)
    if type(text) ~= "string" then return nil end
    local y, m, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    local day = daysFromCivil(y, m, d) - DAY0
    if ns.DropsDate(day) ~= text then return nil end
    return day
end

---------------------------------------------------------------------------
-- Kill ids
---------------------------------------------------------------------------
-- The id of a corpse: 8 hex of server, zone UID, NPC and spawn UID of its GUID
-- ("Creature-0-<server>-<map>-<zoneUID>-<npc>-<spawnUID>"), and the NPC id. nil for anything else.
function ns.DropsKillID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, server, zone, npc, spawn = guid:match("^(%a+)%-%d+%-(%d+)%-%d+%-(%d+)%-(%d+)%-(%x+)$")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    npc = tonumber(npc)
    if not npc or npc < 1 or npc > 9999999 then return nil end
    return hex8(server .. "-" .. zone .. "-" .. npc .. "-" .. spawn), npc
end

-- The id of a kill known only by its event: encounter, instance and the two-minute window.
function ns.DropsFallbackID(enc, inst, t)
    return hex8(("E:%d:%d:%d"):format(enc, inst, math.floor(t / KILL_WINDOW)))
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
-- Whether s is well-formed UTF-8 (every name the client shows is).
local function utf8Ok(s)
    local i, n = 1, #s
    while i <= n do
        local c = s:byte(i)
        local len = (c < 0x80 and 1) or (c >= 0xC2 and c <= 0xDF and 2) or (c >= 0xE0 and c <= 0xEF and 3)
            or (c >= 0xF0 and c <= 0xF4 and 4) or nil
        if not len or i + len - 1 > n then return false end
        for j = i + 1, i + len - 1 do
            local x = s:byte(j)
            if x < 0x80 or x > 0xBF then return false end
        end
        i = i + len
    end
    return true
end

-- A name as it may be stored: plain, well-formed UTF-8 without control characters and bars, at most
-- 48 bytes (cut at a whole character); nil when nothing is left. Ends on any input.
local function cleanName(v)
    v = ns.Plain(v)
    if type(v) ~= "string" then return nil end
    v = v:gsub("[%c|]", "")
    if not utf8Ok(v) then return nil end
    v = v:match("^%s*(.-)%s*$")
    if #v > MAX_NAME then
        -- step back over continuation bytes, so the cut falls before a whole character
        local cut = MAX_NAME
        while cut > 0 do
            local next = v:byte(cut + 1)
            if next < 0x80 or next > 0xBF then break end
            cut = cut - 1
        end
        v = v:sub(1, cut):match("^%s*(.-)%s*$")
    end
    if v == "" then return nil end
    return v
end
ns.DropsCleanName = cleanName

local function nameOk(v) return type(v) == "string" and cleanName(v) == v end

-- The name of the unit whose GUID this is (target, mouseover, focus), or nil.
local function nameOfGUID(guid)
    if type(guid) ~= "string" then return nil end
    for _, unit in ipairs({ "target", "mouseover", "focus" }) do
        if ns.Plain(UnitGUID(unit)) == guid then return cleanName(UnitName(unit)) end
    end
    return nil
end

---------------------------------------------------------------------------
-- The saved table
---------------------------------------------------------------------------
-- A random client id, made once: a hash of a fresh table's address and the clocks. It never draws
-- from or seeds math.random (that would shift every other random delay of the session, and a seed
-- from the server time would make other addons' draws predictable), and it reads no name.
local function newId()
    local profile = type(debugprofilestop) == "function" and debugprofilestop() or 0
    return hex8(("%s:%s:%s:%s"):format(tostring({}), tostring(now()), tostring(GetTime()), tostring(profile)))
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- A record as it may be stored or merged: day within the kept days and not after today (UTC server
-- days, the same on every client) unless anyDay (the saved table: a day ahead is tolerated there).
local function validRecord(r, today, anyDay)
    if type(r) ~= "table" then return false end
    if not int(r.npc, 0, 9999999) or not int(r.inst, 1, 99999) or not int(r.diff, 0, 255) then return false end
    if anyDay then
        if not int(r.day, 0, today + 1) then return false end
    elseif not int(r.day, today - KEEP_DAYS + 1, today) then
        return false
    end
    if not isHex8(r.o) then return false end
    if r.enc ~= nil and not int(r.enc, 1, 99999999) then return false end
    if r.src == "G" then
        if r.npc < 1 then return false end
    elseif r.src == "E" then
        if r.npc ~= 0 or r.enc == nil then return false end
    else
        return false
    end
    if type(r.it) ~= "table" then return false end
    local n = 0
    for id, c in pairs(r.it) do
        n = n + 1
        if n > MAX_ITEMS or not int(id, 1, 9999999) or not int(c, 1, MAX_COUNT) then return false end
    end
    return true
end
ns.DropsValidRecord = validRecord

-- Items within the caps: counts cut to 20, the 16 lowest item ids. A new table; nil for a broken one.
local function capItems(it)
    if type(it) ~= "table" then return nil end
    local ids = {}
    for id, c in pairs(it) do
        if not int(id, 1, 9999999) or not int(c, 1, 9999999) then return nil end
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local out = {}
    for i = 1, math.min(#ids, MAX_ITEMS) do out[ids[i]] = math.min(it[ids[i]], MAX_COUNT) end
    return out
end
ns.DropsCapItems = capItems

local function bump()
    version = version + 1
    if ns.Fire then ns.Fire("DROPS_CHANGED") end
end

-- The number of records (kept up to date by merging and recording, counted again by prune) and the
-- order in which the oldest go when the 4000 are full: ids sorted by day, then id, from evictAt on.
local nRecords, kOf = 0, nil
local evict, evictAt = nil, 1

local function byAge(k)
    return function(a, b)
        local ra, rb = k[a], k[b]
        if ra.day ~= rb.day then return ra.day < rb.day end
        return a < b
    end
end

local function cappedNames(t, max, used)
    if count(t) <= max then return end
    local list = {}
    for key in pairs(t) do list[#list + 1] = key end
    -- names without records go first, then the lowest ids
    table.sort(list, function(a, b)
        if (used[a] or false) ~= (used[b] or false) then return not used[a] end
        return a < b
    end)
    for i = 1, #list - max do t[list[i]] = nil end
end

-- Records older than 28 days go, then the oldest above 4000; names without records above 2000
-- (bosses, encounters) and 500 (instances).
local function prune(d)
    local min = ns.DropsToday() - KEEP_DAYS + 1
    local ids = {}
    for id, r in pairs(d.k) do
        if r.day < min then d.k[id] = nil else ids[#ids + 1] = id end
    end
    if #ids > MAX_RECORDS then
        table.sort(ids, byAge(d.k))
        for i = 1, #ids - MAX_RECORDS do d.k[ids[i]] = nil end
    end
    nRecords, kOf, evict, evictAt = math.min(#ids, MAX_RECORDS), d.k, nil, 1
    for o, day in pairs(d.peers) do
        if day < min then d.peers[o] = nil end
    end
    if count(d.peers) > MAX_PEERS then
        local list = {}
        for o in pairs(d.peers) do list[#list + 1] = o end
        table.sort(list, function(a, b) if d.peers[a] ~= d.peers[b] then return d.peers[a] < d.peers[b] end return a < b end)
        for i = 1, #list - MAX_PEERS do d.peers[list[i]] = nil end
    end
    if count(d.npc) > MAX_NAMES or count(d.enc) > MAX_ENCS or count(d.inst) > MAX_INSTS then
        local npcs, encs, insts = {}, {}, {}
        for _, r in pairs(d.k) do
            npcs[r.npc] = true
            insts[r.inst] = true
            if r.enc then encs[r.enc] = true end
        end
        cappedNames(d.npc, MAX_NAMES, npcs)
        cappedNames(d.enc, MAX_ENCS, encs)
        cappedNames(d.inst, MAX_INSTS, insts)
    end
end

-- The record count, counted again when the table was replaced.
local function records(d)
    if kOf ~= d.k then
        nRecords, kOf, evict, evictAt = count(d.k), d.k, nil, 1
    end
    return nRecords
end

-- The day of the oldest record that would go next, or nil (the list is made once and used up
-- from the front; records made after it are newer or as old as its first).
local function oldestDay(d)
    if not evict or evictAt > #evict then
        evict, evictAt = {}, 1
        for id in pairs(d.k) do evict[#evict + 1] = id end
        table.sort(evict, byAge(d.k))
    end
    while evictAt <= #evict and not d.k[evict[evictAt]] do evictAt = evictAt + 1 end
    local id = evict[evictAt]
    return id and d.k[id].day or nil
end

-- A record just made: counted, and placed in the order of the oldest when that list exists.
local function track(d, id)
    records(d)
    nRecords = nRecords + 1
    if not evict then return end
    local before = byAge(d.k)
    local lo, hi = evictAt, #evict + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if not d.k[evict[mid]] or before(evict[mid], id) then lo = mid + 1 else hi = mid end
    end
    table.insert(evict, lo, id)
end

-- Removes the oldest records while more than 4000 are kept.
local function evictOldest(d)
    while records(d) > MAX_RECORDS do
        if not oldestDay(d) then prune(d) return end
        d.k[evict[evictAt]] = nil
        evictAt = evictAt + 1
        nRecords = nRecords - 1
    end
end

-- Shape of AmisiaDB.drops on ADDON_LOADED: a client id (created once), checked records and names,
-- retention. Running it twice changes nothing. No records come from the collector's notes.
function ns.DropsMigrate(root)
    local d = type(root.drops) == "table" and root.drops or {}
    root.drops = d
    d.v = 1
    if not isHex8(d.me) then d.me = newId() end
    for _, f in ipairs({ "k", "npc", "inst", "enc", "peers" }) do
        if type(d[f]) ~= "table" then d[f] = {} end
    end
    local today = ns.DropsToday()
    for id, r in pairs(d.k) do
        -- items of an older build (30 items, counts to 200) are brought within the caps
        local it = type(r) == "table" and capItems(r.it) or nil
        if it then r.it = it end
        if not isHex8(id) or not it or not validRecord(r, today, true) then
            d.k[id] = nil
        elseif r.mine ~= nil and r.mine ~= true then
            r.mine = nil
        end
    end
    for npc, name in pairs(d.npc) do
        if not int(npc, 1, 9999999) or not nameOk(name) then d.npc[npc] = nil end
    end
    for enc, name in pairs(d.enc) do
        if not int(enc, 1, 99999999) or not nameOk(name) then d.enc[enc] = nil end
    end
    for inst, z in pairs(d.inst) do
        if not int(inst, 1, 99999) or type(z) ~= "table" or (z[1] ~= "party" and z[1] ~= "raid") or not nameOk(z[2]) then
            d.inst[inst] = nil
        end
    end
    for o, day in pairs(d.peers) do
        if not isHex8(o) or not int(day, 0, today + 1) then d.peers[o] = nil end
    end
    if d.heard ~= nil and type(d.heard) ~= "number" then d.heard = nil end
    prune(d)
    version = version + 1
    return d
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.DropsMigrate(AmisiaDB) end
end)

function ns.DropsDB()
    if not AmisiaDB then return nil end
    local d = AmisiaDB.drops
    if type(d) ~= "table" or type(d.k) ~= "table" or type(d.npc) ~= "table" or type(d.inst) ~= "table"
        or type(d.enc) ~= "table" or type(d.peers) ~= "table" then
        d = ns.DropsMigrate(AmisiaDB)
    end
    return d
end

function ns.DropsPrune()
    local d = ns.DropsDB()
    if d then prune(d); bump() end
end

-- Own new records this session.
function ns.DropsAdded() return added end

---------------------------------------------------------------------------
-- Merging (the exchange hands every received record to this)
---------------------------------------------------------------------------
local function copyItems(it)
    local out = {}
    for id, n in pairs(it) do out[id] = n end
    return out
end

-- The union of two item tables: each item at its larger count, then within the caps (the 16 lowest
-- ids, counts to 20). The same result in any order. Whether it differs from cur, and the union.
local function unionItems(cur, it)
    local all, changed = copyItems(cur), false
    for id, c in pairs(it) do
        if (all[id] or 0) < c then all[id] = c end
    end
    all = capItems(all)
    for id, c in pairs(all) do if cur[id] ~= c then changed = true end end
    for id in pairs(cur) do if all[id] == nil then changed = true end end
    return changed, all
end

-- Merges one record into d; nothing is fired. See ns.DropsMerge.
local function mergeOne(d, r, today)
    if type(r) ~= "table" or not isHex8(r.h) then return nil, "id" end
    if r.enc == 0 then r.enc = nil end
    if not validRecord(r, today) then return nil, "record" end
    local it = capItems(r.it)
    local cur = d.k[r.h]
    if not cur then
        -- with 4000 kept, a record older than the oldest kept one would go again at once
        if records(d) >= MAX_RECORDS then
            local oldest = oldestDay(d)
            if oldest and r.day < oldest then return nil, "full" end
        end
        if r.o ~= d.me and (d.peers[r.o] or -1) < r.day then d.peers[r.o] = r.day end
        d.k[r.h] = { npc = r.npc, inst = r.inst, diff = r.diff, day = r.day, o = r.o, enc = r.enc, it = it, src = r.src }
        track(d, r.h)
        return "new"
    end
    if r.o ~= d.me and (d.peers[r.o] or -1) < r.day then d.peers[r.o] = r.day end
    local changed, union = unionItems(cur.it, it)
    if changed then cur.it = union end
    -- a corpse looted on both sides of midnight (UTC) is one kill of the earlier day
    if r.day < cur.day then cur.day, changed = r.day, true end
    -- the own record keeps the own origin; between heard ones the smaller id wins on every client
    if not cur.mine and r.o < cur.o then cur.o, changed = r.o, true end
    if cur.enc == nil and r.enc ~= nil then cur.enc, changed = r.enc, true end
    if cur.npc == 0 and r.npc > 0 and cur.src == r.src then cur.npc, changed = r.npc, true end
    return changed and "merged" or "same"
end

-- Merges one record { h, npc, inst, diff, day, o, enc, it, src }: the same id is one kill. Items are
-- the union at the larger count within the caps (16 items, 20 each); the day the earlier one; the
-- origin stays on an own record and is the smaller id on a heard one; enc and npc are filled in when
-- missing; nothing else is overwritten. A record after today, older than 28 days or (with 4000 kept)
-- older than the oldest kept one is refused. Returns "new", "merged", "same", or nil and the reason.
function ns.DropsMerge(r)
    local d = ns.DropsDB()
    if not d then return nil, "not loaded" end
    local res, why = mergeOne(d, r, ns.DropsToday())
    if res == "new" then evictOldest(d) end
    if res == "new" or res == "merged" then bump() end
    return res, why
end

-- Merges a list of records with one prune and one change event at the end (the exchange hands a
-- whole blob to this). Returns the results in the order of the list and the counts { new, merged,
-- same, refused }.
function ns.DropsMergeAll(list)
    local d = ns.DropsDB()
    local out, n = {}, { new = 0, merged = 0, same = 0, refused = 0 }
    if not d then return out, n end
    local today = ns.DropsToday()
    for i, r in ipairs(list) do
        local res = mergeOne(d, r, today)
        out[i] = res
        if res then n[res] = n[res] + 1 else n.refused = n.refused + 1 end
        if res == "new" and records(d) > MAX_RECORDS then evictOldest(d) end
    end
    if n.new > 0 or n.merged > 0 then bump() end
    return out, n
end

-- Raised whenever a name is added (learned from another client or recorded), so a view keyed on
-- names knows it is stale; DROPS_CHANGED fires with it.
local namesGen = 0
function ns.DropsNamesGen() return namesGen end

-- A name heard from another client: taken only where none is known. Fires DROPS_CHANGED once when
-- at least one name was added. Returns the number of names added.
function ns.DropsLearnNames(npcNames, zones, encNames)
    local d = ns.DropsDB()
    if not d then return 0 end
    local n = 0
    for npc, name in pairs(type(npcNames) == "table" and npcNames or {}) do
        if int(npc, 1, 9999999) and nameOk(name) and d.npc[npc] == nil then d.npc[npc] = name; nameless[npc] = nil; n = n + 1 end
    end
    for enc, name in pairs(type(encNames) == "table" and encNames or {}) do
        if int(enc, 1, 99999999) and nameOk(name) and d.enc[enc] == nil then d.enc[enc] = name; n = n + 1 end
    end
    for inst, z in pairs(type(zones) == "table" and zones or {}) do
        if int(inst, 1, 99999) and type(z) == "table" and (z[1] == "party" or z[1] == "raid") and nameOk(z[2]) and d.inst[inst] == nil then
            d.inst[inst] = { z[1], z[2] }
            n = n + 1
        end
    end
    if n > 0 then
        if count(d.npc) > MAX_NAMES or count(d.enc) > MAX_ENCS or count(d.inst) > MAX_INSTS then prune(d) end
        namesGen = namesGen + 1
        bump()
    end
    return n
end

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------
local bossSet, bossOf

-- A boss NPC: among the bosses of the dungeon facts (ns.BIS.DG), or in the base stock (ns.BIS.O)
-- with at least BOSS_FROM_KILLS archived kills. The base stock alone is no proof: a trash corpse
-- that held a kill event for the time being (see ns.DropsFromLoot) can reach the archive, but it
-- rarely does so again and again, while a boss the facts miss is recorded on every run.
local BOSS_FROM_KILLS = 3
local function isBoss(npc)
    local B = ns.BIS
    if B ~= bossOf or not bossSet then
        bossOf, bossSet = B, {}
        if type(B) == "table" then
            if type(B.O) == "table" then
                for k, e in pairs(B.O) do
                    if type(e) == "table" and (tonumber(e.k) or 0) >= BOSS_FROM_KILLS then bossSet[k] = true end
                end
            end
            if type(B.DG) == "table" then
                for _, dg in ipairs(B.DG) do
                    if type(dg) == "table" and type(dg.bosses) == "table" then
                        for _, n in ipairs(dg.bosses) do bossSet[n] = true end
                    end
                end
            end
        end
    end
    return npc ~= nil and bossSet[npc] == true
end
ns.DropsIsBoss = isBoss

local function itemClass(id)
    local instant = C_Item and C_Item.GetItemInfoInstant
    if type(instant) ~= "function" then return nil end
    local ok, _, _, _, _, _, class = pcall(instant, id)
    return ok and tonumber(ns.Plain(class)) or nil
end

local function instanceNow()
    local name, kind, diff, _, _, _, _, inst = GetInstanceInfo()
    kind, inst = ns.Plain(kind), tonumber(ns.Plain(inst))
    if (kind ~= "party" and kind ~= "raid") or not int(inst, 1, 99999) then return nil end
    diff = tonumber(ns.Plain(diff)) or 0
    if not int(diff, 0, 255) then diff = 0 end
    return inst, kind, diff, cleanName(name)
end

-- A boss kill event of the current instance (ENCOUNTER_END with success, BOSS_KILL).
local function onKill(enc, name)
    enc = tonumber(ns.Plain(enc))
    if not int(enc, 1, 99999999) then return end
    local inst = instanceNow()
    if not inst then return end
    local t = now()
    -- END and BOSS_KILL of one fight are one kill
    if lastKill and lastKill.enc == enc and lastKill.inst == inst and t - lastKill.t <= KILL_WINDOW then return end
    lastKill = { enc = enc, name = cleanName(name), t = t, inst = inst }
end

ns.OnEvent("ENCOUNTER_END", function(enc, name, _, _, success)
    if tonumber(ns.Plain(success)) == 1 then onKill(enc, name) end
end)
ns.OnEvent("BOSS_KILL", onKill)

local function setName(d, npc, name)
    if not name or npc < 1 then return end
    if d.npc[npc] == nil then
        d.npc[npc] = name
        namesGen = namesGen + 1
        if count(d.npc) > MAX_NAMES then prune(d) end
    end
    nameless[npc] = nil
end

-- What the loot window holds, by corpse: { id, npc, guid, items, rare }; "?" for slots whose source
-- cannot be read (a secret GUID): only the fallback id of a kill event can take them.
local function readWindow()
    local groups, order = {}, {}
    local n = tonumber(ns.Plain(GetNumLootItems())) or 0
    for slot = 1, n do
        local src = GetLootSourceInfo and ns.Plain((GetLootSourceInfo(slot))) or nil
        local id, npc
        if type(src) == "string" then id, npc = ns.DropsKillID(src) end
        local key = id or (src == nil and "?") or nil
        if key then
            local g = groups[key]
            if not g then
                g = { id = id, npc = npc, guid = src, items = {}, rare = false }
                groups[key] = g
                order[#order + 1] = key
            end
            local link = ns.Plain(GetLootSlotLink(slot))
            local item = ns.ItemID(link)
            if item and item >= 1 and item <= 9999999 then
                local _, _, qty, _, q = GetLootSlotInfo(slot)
                q = tonumber(ns.Plain(q)) or ns.LinkQuality(link)
                qty = math.max(1, math.floor(tonumber(ns.Plain(qty)) or 1))
                if (q and q >= MIN_QUALITY) or itemClass(item) == CLASS_RECIPE then
                    g.items[item] = math.min(MAX_COUNT, (g.items[item] or 0) + qty)
                end
                if q and q >= RARE then g.rare = true end
            end
        end
    end
    return groups, order
end

-- Called by Collect.lua on LOOT_OPENED: the boss corpses of the window become records (or add their
-- items to the record of a corpse opened before).
--
-- Which corpse a kill event belongs to: a corpse of a known boss or with a rare item takes it at
-- once. A corpse with neither takes it only for the time being (it may be the boss: unknown, nothing
-- rare in its window); a corpse of a known boss or with a rare item opened later within the 120 s
-- takes the event over, and the first one, trash after all, loses its record and the name it got
-- from the event. So trash looted between a boss kill and its corpse never becomes the kill.
function ns.DropsFromLoot()
    if not AmisiaDB or not ns.Get("drops.record") then return end
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return end
    local inst, kind, diff, instName = instanceNow()
    if not inst then return end
    local d = ns.DropsDB()
    local t, today = now(), ns.DropsToday()
    local kill = lastKill
    if kill and (kill.inst ~= inst or t - kill.t > KILL_WINDOW) then kill = nil end
    local groups, order = readWindow()
    if #order == 0 then return end
    local changed = false

    local function add(id, g, src, npc, enc)
        local r = d.k[id]
        if r then
            local more, union = unionItems(r.it, capItems(g.items) or {})
            if more then r.it = union; changed = true end
            return r
        end
        r = { npc = npc, inst = inst, diff = diff, day = today, o = d.me, enc = enc, it = capItems(g.items) or {}, src = src, mine = true }
        d.k[id] = r
        track(d, id)
        added = added + 1
        changed = true
        return r
    end

    -- the corpse that held the event for the time being gives it up: its record goes when it was
    -- made for the event, the name it got from the event too
    local function takeOver()
        local old = kill.used and d.k[kill.used]
        if old and kill.made and old.mine then
            d.k[kill.used] = nil
            nRecords = nRecords - 1
            added = math.max(0, added - 1)
        elseif old and old.enc == kill.enc then
            old.enc = nil
        end
        if kill.named and d.npc[kill.named] == kill.name then
            d.npc[kill.named] = nil
            nameless[kill.named] = nil
        end
        kill.used, kill.weak, kill.made, kill.named = nil, nil, nil, nil
        changed = true
    end

    -- corpses opened before, then known bosses and windows with a rare item, then the rest; a kill
    -- event goes to the first new corpse that takes it
    local rank = {}
    for _, key in ipairs(order) do
        local g = groups[key]
        rank[key] = (g.id and d.k[g.id]) and 0 or ((g.id and (isBoss(g.npc) or g.rare)) and 1 or 2)
    end
    local sorted = {}
    for i, key in ipairs(order) do sorted[i] = key end
    table.sort(sorted, function(a, b)
        if rank[a] ~= rank[b] then return rank[a] < rank[b] end
        return a < b
    end)
    for _, key in ipairs(sorted) do
        local g = groups[key]
        if g.id then
            local r = d.k[g.id]
            if r then
                add(g.id, g)
            elseif rank[key] == 1 then
                local enc
                if kill and kill.used and kill.weak and kill.used ~= g.id then takeOver() end
                if kill and not kill.used then enc, kill.used = kill.enc, g.id end
                r = add(g.id, g, "G", g.npc, enc)
            elseif kill and not kill.used then
                -- only for the time being, see above
                kill.used, kill.weak, kill.made = g.id, true, true
                r = add(g.id, g, "G", g.npc, kill.enc)
            end
            if r then
                local name = nameOfGUID(g.guid)
                if not name and kill and kill.used == g.id and r.enc == kill.enc and kill.name and d.npc[g.npc] == nil then
                    name, kill.named = kill.name, g.npc
                end
                if name then setName(d, g.npc, name) elseif d.npc[g.npc] == nil then nameless[g.npc] = true end
            end
        elseif kill then
            -- no readable corpse: the kill event's fallback id (the same window on every client)
            local id = ns.DropsFallbackID(kill.enc, inst, kill.t)
            if d.k[id] or not kill.used or kill.used == id then
                kill.used = id
                add(id, g, "E", 0, kill.enc)
                if kill.name and d.enc[kill.enc] == nil then d.enc[kill.enc] = kill.name end
            end
        end
    end
    if changed then
        if instName and (d.inst[inst] == nil or d.inst[inst][2] ~= instName or d.inst[inst][1] ~= kind) then
            d.inst[inst] = { kind, instName }
            if count(d.inst) > MAX_INSTS then prune(d) end
        end
        evictOldest(d)
        bump()
    end
end

-- A boss whose name was secret when its corpse was looted is named once it is targeted again.
ns.OnEvent("PLAYER_TARGET_CHANGED", function()
    if not next(nameless) then return end
    local _, npc = ns.DropsKillID(ns.Plain(UnitGUID("target")))
    if not npc or not nameless[npc] then return end
    local d = ns.DropsDB()
    local name = cleanName(UnitName("target"))
    if d and name then
        setName(d, npc, name)
        bump()
    end
end)

---------------------------------------------------------------------------
-- Rates
---------------------------------------------------------------------------
local sums, sumsVersion, sumsOT, sumsOI, sumsBIS   -- npc -> { k = kills, it = { [item] = kills with it } } after OT

-- Whether a record counts on top of the base stock: a day after its day (ns.BIS.OT) and an id it
-- does not hold. ns.BIS.OI lists the ids of the base stock's last day, so a corpse looted on both
-- sides of midnight (UTC) counts once.
local function afterBase(id, r, ot, oi)
    return r.day > ot and not (oi and oi[id])
end

local function baseIds()
    local B = ns.BIS
    return type(B) == "table" and type(B.OI) == "table" and B.OI or nil
end

-- The boss NPC of a record: its own, or for a fallback record (NPC 0, known by its encounter) the
-- boss the client's encounter table names for that encounter (ns.BIS.EN, tools/build_bis.py); 0
-- when neither says.
function ns.DropsBossOf(r)
    if r.npc > 0 then return r.npc end
    local B = ns.BIS
    local npc = r.enc and type(B) == "table" and type(B.EN) == "table" and tonumber(B.EN[r.enc])
    return npc and npc > 0 and npc or 0
end

local function ownSums(ot)
    local oi = baseIds()
    if sums and sumsVersion == version and sumsOT == ot and sumsOI == oi and sumsBIS == ns.BIS then return sums end
    sums, sumsVersion, sumsOT, sumsOI, sumsBIS = {}, version, ot, oi, ns.BIS
    local d = ns.DropsDB()
    for id, r in pairs(d and d.k or {}) do
        local npc = ns.DropsBossOf(r)
        if afterBase(id, r, ot, oi) and npc > 0 then
            local s = sums[npc]
            if not s then s = { k = 0, it = {} }; sums[npc] = s end
            s.k = s.k + 1
            for item in pairs(r.it) do s.it[item] = (s.it[item] or 0) + 1 end
        end
    end
    return sums
end

local function quality(id)
    local info = C_Item and C_Item.GetItemInfo
    if type(info) ~= "function" then return nil end
    local ok, _, _, q = pcall(info, id)
    return ok and tonumber(ns.Plain(q)) or nil
end

-- The expected chance without observations: one of the boss's known items of the same quality.
local function qualityShare(item, base, own)
    local known = { [item] = true }
    if base and type(base.it) == "table" then for id in pairs(base.it) do known[id] = true end end
    if own then for id in pairs(own.it) do known[id] = true end end
    local q = quality(item)
    local n = 0
    for id in pairs(known) do
        if q == nil or quality(id) == q then n = n + 1 end
    end
    return 1 / math.max(1, n)
end

-- The drop rate of item at npc: p = (n + 3 * p0) / (K + 3), with K kills and n kills with the item
-- (base stock ns.BIS.O plus the records after its day ns.BIS.OT) and p0 the expected chance (given,
-- else one of the boss's known items of the same quality). Returns p, n, K; nil when nothing is
-- known.
function ns.DropRate(npc, item, p0)
    npc, item = tonumber(npc), tonumber(item)
    if not npc or not item then return nil end
    local B = ns.BIS
    local base = type(B) == "table" and type(B.O) == "table" and type(B.O[npc]) == "table" and B.O[npc] or nil
    local ot = type(B) == "table" and tonumber(B.OT) or -1
    local own = ownSums(ot)[npc]
    local K = (base and tonumber(base.k) or 0) + (own and own.k or 0)
    local n = (base and type(base.it) == "table" and tonumber(base.it[item]) or 0) + (own and own.it[item] or 0)
    p0 = tonumber(p0)
    if K == 0 and not p0 then return nil end
    p0 = p0 or qualityShare(item, base, own)
    return (n + SMOOTH * p0) / (K + SMOOTH), n, K
end

-- n sightings in K kills as text: a share from five kills on, a count below; nil without kills.
local function countText(n, K)
    if K and K >= SHOW_RATE_FROM then
        return ("%d von %d Kills der Gilde (%d %%)"):format(n, K, math.floor(n / K * 100 + 0.5))
    elseif K and K > 0 then
        return ("gesehen %d-mal in %d Kills"):format(n, K)
    end
    return nil
end

-- "9 von 41 Kills der Gilde (22 %)", below five kills "gesehen 2-mal in 3 Kills", else the
-- expected chance or "Chance unbekannt".
function ns.DropRateText(npc, item, p0)
    local p, n, K = ns.DropRate(npc, item, p0)
    if K and K > 0 then
        return countText(n, K)
    elseif p then
        return ("Chance %d %%"):format(math.floor(p * 100 + 0.5))
    end
    return "Chance unbekannt"
end

---------------------------------------------------------------------------
-- The tooltip line: "Drop bei <Boss>: <rate>" on items the guild saw drop
---------------------------------------------------------------------------
-- item -> npc of the boss that drops it most often (base stock plus the records after its day).
-- Built once per change of the records or the base stock, never per hover.
local tipIndex, tipVersion, tipBase, tipOT
local tipStats = { builds = 0 }

local function tipBoss(item)
    local B = ns.BIS
    local base = type(B) == "table" and type(B.O) == "table" and B.O or nil
    local ot = type(B) == "table" and tonumber(B.OT) or -1
    if not tipIndex or tipVersion ~= version or tipBase ~= base or tipOT ~= ot then
        tipIndex, tipVersion, tipBase, tipOT = {}, version, base, ot
        tipStats.builds = tipStats.builds + 1
        local counts = {}   -- npc -> { k, it }
        local function add(npc, k, it)
            local c = counts[npc]
            if not c then c = { k = 0, it = {} }; counts[npc] = c end
            c.k = c.k + k
            for id, n in pairs(it) do c.it[id] = (c.it[id] or 0) + n end
        end
        for npc, e in pairs(base or {}) do
            if type(npc) == "number" and type(e) == "table" then
                add(npc, tonumber(e.k) or 0, type(e.it) == "table" and e.it or {})
            end
        end
        for npc, s in pairs(ownSums(ot)) do add(npc, s.k, s.it) end
        for npc, c in pairs(counts) do
            for id, n in pairs(c.it) do
                if type(id) == "number" and n > 0 and c.k > 0 then
                    local best = tipIndex[id]
                    -- the boss that drops it most often, then the higher share, then the lower id
                    if not best or n > best.n or (n == best.n and (n / c.k > best.n / best.k
                        or (n / c.k == best.n / best.k and npc < best.npc))) then
                        tipIndex[id] = { npc = npc, n = n, k = c.k }
                    end
                end
            end
        end
    end
    local e = tipIndex[item]
    return e and e.npc or nil
end

-- "Drop bei Faldrim Ambossmahl: 9 von 41 Kills der Gilde (22 %)" for an item the guild saw drop,
-- or nil.
function ns.DropsTooltipLine(item)
    item = tonumber(item)
    if not item or not AmisiaDB then return nil end
    local npc = tipBoss(item)
    if not npc then return nil end
    local d = ns.DropsDB()
    local name = d and d.npc[npc] or ("Boss " .. npc)
    return ("Drop bei %s: %s"):format(name, ns.DropRateText(npc, item))
end

function ns.DropsTooltipStats() return { builds = tipStats.builds } end

local TIP_GREY = { 0.56, 0.53, 0.64 }

-- Registered once every file has loaded, so the line stands under the upgrade line of Bis.lua.
local tipHooked = false
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ADDON or tipHooked then return end
    tipHooked = true
    ns.OnItemTooltip("drops", function(tip, _, id)
        if not ns.Get("drops.tooltip") then return false end
        local line = ns.DropsTooltipLine(id)
        if not line then return false end
        tip:AddLine(line, TIP_GREY[1], TIP_GREY[2], TIP_GREY[3])
        return true
    end)
end)

---------------------------------------------------------------------------
-- The list per instance and boss (tools page)
---------------------------------------------------------------------------
local KIND_TEXT = { party = "Dungeon", raid = "Raid" }

-- Rows for the page: { kind = "inst", inst, text, rate, K }, then per boss { kind = "boss", npc,
-- enc, text, rate, K } and its items { kind = "item", npc, id, n, K, text, rate }. Kills and
-- sightings as for the rates (base stock plus the records after its day); a fallback record
-- (no NPC) counts under its encounter. Instances and bosses by name, items by count, then id.
function ns.DropsBossList()
    local d = ns.DropsDB()
    if not d then return {} end
    local B = ns.BIS
    local base = type(B) == "table" and type(B.O) == "table" and B.O or {}
    local ot = type(B) == "table" and tonumber(B.OT) or -1
    local bosses = {}   -- key -> { npc, enc, inst, k, it }
    local function boss(key, npc, enc)
        local b = bosses[key]
        if not b then b = { npc = npc, enc = enc, k = 0, it = {} }; bosses[key] = b end
        return b
    end
    local oi = baseIds()
    for id, r in pairs(d.k) do
        -- a fallback record counts under the boss of its encounter where the client's table names one
        local npc = ns.DropsBossOf(r)
        local key = npc > 0 and npc or ("e" .. tostring(r.enc))
        local b = boss(key, npc, npc > 0 and nil or r.enc)
        if npc ~= r.npc and not b.encName then b.encName = d.enc[r.enc] end
        if not b.inst or (b.day or -1) < r.day then b.inst, b.day = r.inst, r.day end
        if afterBase(id, r, ot, oi) then
            b.k = b.k + 1
            for item in pairs(r.it) do b.it[item] = (b.it[item] or 0) + 1 end
        end
    end
    for npc, e in pairs(base) do
        if type(npc) == "number" and type(e) == "table" then
            local b = boss(npc, npc)
            b.k = b.k + (tonumber(e.k) or 0)
            for id, n in pairs(type(e.it) == "table" and e.it or {}) do
                if type(id) == "number" and tonumber(n) then b.it[id] = (b.it[id] or 0) + n end
            end
        end
    end
    -- the dungeon facts place the bosses of the base stock
    local dgInst, dgName = {}, {}
    if type(B) == "table" and type(B.DG) == "table" then
        for _, dg in ipairs(B.DG) do
            if type(dg) == "table" and type(dg.inst) == "number" then
                dgName[dg.inst] = { dg.kind, dg.name }
                for _, n in ipairs(type(dg.bosses) == "table" and dg.bosses or {}) do dgInst[n] = dg.inst end
            end
        end
    end
    local insts = {}
    for _, b in pairs(bosses) do
        if b.k > 0 then
            local inst = b.inst or dgInst[b.npc] or 0
            local g = insts[inst]
            if not g then
                local z = d.inst[inst] or dgName[inst]
                g = { inst = inst, kind = z and z[1], name = z and z[2], k = 0, list = {} }
                insts[inst] = g
            end
            g.k = g.k + b.k
            if b.npc > 0 then
                b.name = d.npc[b.npc] or b.encName or ("Boss " .. b.npc)
            else
                b.name = d.enc[b.enc] or ("Begegnung " .. tostring(b.enc))
            end
            g.list[#g.list + 1] = b
        end
    end
    local order = {}
    for _, g in pairs(insts) do order[#order + 1] = g end
    table.sort(order, function(a, b)
        -- the bosses without an instance last
        if (a.inst == 0) ~= (b.inst == 0) then return b.inst == 0 end
        local na, nb = a.name or ("Instanz " .. a.inst), b.name or ("Instanz " .. b.inst)
        if na ~= nb then return na < nb end
        return a.inst < b.inst
    end)
    local rows = {}
    local function kills(k) return ("%d %s"):format(k, k == 1 and "Kill" or "Kills") end
    for _, g in ipairs(order) do
        local text
        if g.inst == 0 then
            text = "Ohne Instanz"
        else
            text = (g.name or ("Instanz " .. g.inst)) .. (KIND_TEXT[g.kind] and (" · " .. KIND_TEXT[g.kind]) or "")
        end
        rows[#rows + 1] = { kind = "inst", inst = g.inst, text = text, rate = kills(g.k), K = g.k }
        table.sort(g.list, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            return (a.npc or 0) < (b.npc or 0)
        end)
        for _, b in ipairs(g.list) do
            rows[#rows + 1] = { kind = "boss", inst = g.inst, npc = b.npc, enc = b.enc, text = b.name, rate = kills(b.k), K = b.k }
            local items = {}
            for id, n in pairs(b.it) do
                if n > 0 then items[#items + 1] = { id = id, n = n } end
            end
            table.sort(items, function(x, y)
                if x.n ~= y.n then return x.n > y.n end
                return x.id < y.id
            end)
            for _, it in ipairs(items) do
                rows[#rows + 1] = { kind = "item", inst = g.inst, npc = b.npc, id = it.id, n = it.n, K = b.k,
                    text = ns.ItemName(it.id), rate = countText(math.min(it.n, b.k), b.k) }
            end
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Status and the text "Drops für die Website"
---------------------------------------------------------------------------
-- { kills, own, heard, bosses, newest (day or nil), heardAt (epoch or nil) }
function ns.DropsStatus()
    local d = ns.DropsDB()
    local out = { kills = 0, own = 0, heard = 0, bosses = 0 }
    if not d then return out end
    local bosses = {}
    for _, r in pairs(d.k) do
        out.kills = out.kills + 1
        if r.mine then out.own = out.own + 1 else out.heard = out.heard + 1 end
        local npc = ns.DropsBossOf(r)
        bosses[npc > 0 and npc or ("e" .. tostring(r.enc))] = true
        if not out.newest or r.day > out.newest then out.newest = r.day end
    end
    out.bosses = count(bosses)
    out.heardAt = d.heard
    return out
end

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Every kept record as text for the website: "#AMISIA 2 <who exports>", DZ (instances), DN (boss
-- names), DK (one line per kill, sorted by day, then id), "#END". No player name in the lines. Not
-- part of the raid export.
function ns.DropsExportText()
    local d = ns.DropsDB()
    local lines = { "#AMISIA 2 " .. ns.ExportName(ns.UnitFullName("player") or "?") }
    local ids, insts, npcs, encs = {}, {}, {}, {}
    for id, r in pairs(d and d.k or {}) do
        ids[#ids + 1] = id
        insts[r.inst] = true
        if r.npc > 0 then
            local e = npcs[r.npc] or {}
            npcs[r.npc] = e
            if r.enc then e[r.enc] = (e[r.enc] or 0) + 1 end
        elseif r.enc then
            encs[r.enc] = true
        end
    end
    table.sort(ids, function(a, b)
        local ra, rb = d.k[a], d.k[b]
        if ra.day ~= rb.day then return ra.day < rb.day end
        return a < b
    end)
    -- DZ <instanceID> <party|raid> <name>
    for _, inst in ipairs(sortedKeys(insts)) do
        local z = d.inst[inst]
        if z then
            lines[#lines + 1] = ("DZ %d %s %s"):format(inst, z[1], z[2])
        end
    end
    -- DN <npcID> <encounterID|0> <name>: the encounter most of its records name
    for _, npc in ipairs(sortedKeys(npcs)) do
        local name = d.npc[npc]
        if name then
            local best, most = 0, 0
            for enc, n in pairs(npcs[npc]) do
                if n > most or (n == most and enc < best) then best, most = enc, n end
            end
            lines[#lines + 1] = ("DN %d %d %s"):format(npc, best, name)
        end
    end
    for _, enc in ipairs(sortedKeys(encs)) do
        local name = d.enc[enc]
        if name then lines[#lines + 1] = ("DN %d %d %s"):format(0, enc, name) end
    end
    -- DK <h> <npcID> <instanceID> <difficultyID> <YYYY-MM-DD> <origin> <G|E> <itemID>:<n>,...|-
    for _, id in ipairs(ids) do
        local r = d.k[id]
        local items = {}
        for _, item in ipairs(sortedKeys(r.it)) do items[#items + 1] = item .. ":" .. r.it[item] end
        lines[#lines + 1] = ("DK %s %d %d %d %s %s %s %s"):format(id, r.npc, r.inst, r.diff, ns.DropsDate(r.day), r.o, r.src,
            #items > 0 and table.concat(items, ",") or "-")
    end
    lines[#lines + 1] = "#END"
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Settings and command
---------------------------------------------------------------------------
ns.DROPS_SETTINGS = { key = "drops", label = "Drop-Daten", order = 46, items = {
    { key = "drops.record", type = "toggle", label = "Boss-Loot in Dungeons und Raids aufzeichnen", default = true,
      tip = "Ein geöffnetes Lootfenster eines Bosses wird ein Kill mit seinen Items, ohne Spielernamen." },
    { key = "drops.share", type = "toggle", label = "Drop-Daten mit der Gilde teilen", default = true,
      tip = "ohne Namen, nur außerhalb von Instanzen" },
    { key = "drops.tooltip", type = "toggle", label = "Dropraten der Gilde im Tooltip", default = true,
      tip = "Eine graue Zeile an Items, die die Gilde bei einem Boss droppen sah, mit der Zahl der Kills." },
} }
ns.RegisterSettings(ns.DROPS_SETTINGS)

ns.RegisterSlash("drops", { args = "[export]", desc = "Stand der Drop-Daten der Gilde", run = function(rest)
    local word = (rest or ""):match("^(%S*)"):lower()
    if word == "export" then
        ns.ShowDropsExport()
        return
    elseif word ~= "" then
        ns.msg("Aufruf: /amisia drops [export]")
        return
    end
    local s = ns.DropsStatus()
    ns.msg(("Drop-Daten: %d Kills (%d eigene, %d gehörte), %d Bosse, neuester Tag %s, letzter Austausch %s. Aufzeichnen %s, Teilen %s."):format(
        s.kills, s.own, s.heard, s.bosses, s.newest and ns.DropsDate(s.newest) or "keiner",
        s.heardAt and date("%d.%m. %H:%M", s.heardAt) or "noch keiner",
        ns.Get("drops.record") and "an" or "aus", ns.Get("drops.share") and "an" or "aus"))
end })
