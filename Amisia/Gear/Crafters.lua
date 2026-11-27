-- Amisia crafters ("Wer kann was herstellen"): guild members share the recipes their own characters
-- know (Professions.lua reads them from the own profession window); every client keeps per crafter
-- name what it heard, with the day it last heard of it, and shows who can make a recipe or an item.
--
-- The exchange works like the drop and source exchanges (DropSync.lua, CollectSync.lua), only much
-- smaller. A client announces a digest of its own crafters to the guild (PV); whoever holds another
-- digest from that sender asks it by whisper (PQ: a format and a request number); the answer is one
-- PK blob (20 parts at most) with the sender's own crafters: per profession the rank and the known
-- recipes as a bitset over the sender's recipe index of that profession (the spells of
-- ProfessionData sorted by id, with the index's checksum), or, after the asker found another index
-- (other data), as a list of spell steps. A busy or spent sender says so (PW). Both sides pull,
-- neither pushes: a blob nobody asked for is dropped, a request takes its one answer. Only between
-- guild members, only the sender's own characters of this guild, and a heard crafter must stand in
-- the roster and be the sender or its known alt (the website's alts list); a list keeps only the
-- spells of the own recipe index; per sender and in all the store stays within byte caps; never in the lockdown or
-- while a raid is synced (combat holds nothing back); inside an instance or a battleground nothing goes, what wanted
-- to (an announcement, a request, an answer to one) waits and goes 5 to 15 s after the character is out again; at
-- the lowest priority of the queue within fixed byte caps. A search on the professions page asks the heard
-- crafters of its hits whose list is older than 3 days and who are online now at once (Cr.AskOld, the same PQ).
--
-- F-240 (spec docs/specs/2026-11-27-rezepte-abgleich.md, D-174): a client that heard no sender today asks the guild
-- once, 60 to 120 s after the login (PH); every member that shares answers it 5 to 60 s later with its PV by
-- whisper, which also names how many crafters it heard first-hand (each once an hour per asker, ten askers an hour);
-- for the hour after the question the asker may pull pqBoost times. From the two answerers with the most it pulls
-- those (PQ format R): the crafters that sent themselves to the answerer within relayDays, standing in its roster,
-- never the answerer's own and never what was passed on (no chains). A passed-on crafter keeps the day it sent
-- itself and the answerer (via, relay = true); one that sent itself is never replaced by one passed on that is not
-- newer, and replaces it always.
--
-- Crafter protocol 1. Older clients do not know PV and drop it as an unknown message; they never send
-- PQ, so nothing else reaches them. PH and the format R are additions within protocol 1: an older client drops
-- PH (an unknown kind) and the format R (Comm's PQ check); R is only asked of an answer that named its count.
--
-- AmisiaDB.crafters = { v = 1, src = { [lower sender] = { d = digest, at = day, f = "L" (lists) } },
--   c = { [name] = { via = sender, self = true (the crafter sent it), relay = true (passed on by via, F-240), seen = day,
--   p = { [skill] = { r = rank, m = max, h = index checksum, b = bitset hex | l = "spell,spell,..." } } } } }
-- AmisiaDB.prof.guild = { [own character] = guild name } (which guild an own character's recipes go to)
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local Cr = {}
ns.Crafters = Cr

ns.CRAFT_PROTO = 1

-- the caps and times; a table so a test can lower one
local LIM = {
    firstMin = 120, firstSpread = 120,  -- the first announcement 120 to 240 s after the login
    every = 3600,                       -- again every hour (a member who logged in later hears it too)
    changeGap = 600,                    -- after a change of the own recipes at most every 10 minutes
    tick = 5,
    pqWait = 90,                        -- seconds a request waits for its blob
    pqPerHour = 20,                     -- requests of this client in an hour
    retryWait = 300, retries = 1,       -- a sender that did not answer is asked once more after 5 min
    askKeep = 300,                      -- seconds the answer to a request is still taken
    peersMax = 20, peerKeep = 3600, pullJitter = 30,
    serveGap = 20, partsWindow = 600, partsMax = 60,   -- an answering client: a blob per 20 s, 60 parts per 10 min
    serveMax = 4, serveKeep = 300,      -- requests waiting for their blob (one per asker)
    busyWait = 120, doneWait = 3600,
    blobParts = 20,
    sessionBytes = 32768, askerShare = 4, pwReserve = 512,
    crafterMax = 12, profMax = 8, knownMax = 1200,
    keepDays = 45,                      -- a crafter not heard of for 45 days is forgotten
    selfDays = 14,                      -- what a crafter sent itself is not replaced by another sender's word for 14 days
    storeMax = 500,                     -- crafters kept at most (the oldest go first)
    storeBytes = 393216,                -- bytes of bitsets and lists kept at most (the oldest crafters go first)
    viaBytes = 24576,                   -- bytes of bitsets and lists kept at most from one sender
    bitsMax = 300,                      -- hex characters of one bitset (1200 recipes)
    outWait = 5, outSpread = 10,        -- seconds after leaving an instance before the exchange talks again
    askOldDays = 3,                     -- a search asks a crafter heard of more than 3 days ago
    askPerMinute = 6,                   -- asks of a search in a minute
    askGap = 60,                        -- seconds between two requests to one crafter (the receiver's gap for PQ)
    askScan = 200,                      -- hits of a search looked at
    -- F-240: the question after the login (PH) and the answers to it
    helloMin = 60, helloSpread = 60,    -- the question 60 to 120 s after the login, once a session
    helloKeep = 600,                    -- seconds a whispered PV is taken as an answer to it
    replyMin = 5, replySpread = 55,     -- an answer 5 to 60 s after the question
    replyGap = 3600, replyPerHour = 10, -- one answer per asker in an hour, ten askers in an hour
    pqBoost = 40,                       -- requests in the hour after the own question (else pqPerHour)
    -- F-240: passing on what a crafter sent itself (the format R)
    relayDays = 14,                     -- heard first-hand within 14 days
    relayPick = 2,                      -- the answerers with the most asked for them
    relayMax = 40,                      -- crafters in one R answer at most
}
ns.CRAFTERS_LIMITS = LIM

local PART_OVERHEAD = 45
local KEY_PREFIX = "0000-00-01:"

local stats = { bytes = 0, pv = 0, pq = 0, pw = 0, served = 0, blobs = 0, crafters = 0, bad = 0, unasked = 0, refused = 0,
                outsider = 0, kept = 0, mismatch = 0, pulls = 0, busy = 0, other = 0, pruned = 0, missed = 0, foreign = 0,
                capped = 0, unknown = 0, searched = 0, ph = 0, phHeard = 0, replies = 0, relayed = 0, relayServed = 0 }
local pqTimes = {}
local asked = {}          -- nonce -> { low, f, at }
local peers = {}          -- { name, low, d, n, at, nb, f, retry }
local pull                -- { name, low, d, f, nonce, deadline, retry }
local serve = {}          -- { name, low, f, nonce, at }
local askers = {}         -- lower name -> { bytes, served }
local lastBlob
local partsLog = {}
local firstAt, lastPV, lastD
local nonceSeq
local askedAt = {}        -- lower name -> GetTime() of the last request to it
-- F-240: the own question after the login and the answers to others' questions
local helloAt, helloSent  -- when the own question goes (set at the login); GetTime() it went, false: not needed
local boostUntil = 0      -- until then pqBoost requests in the hour
local offers = {}         -- lower name -> { name, n }: answerers of the own question and how many they pass on
local relayPicked, relayPickedN = false, 0
local replies = {}        -- answers waiting: { name, low, at }
local repliedAt = {}      -- lower name -> GetTime() of the last answer to its question
local replyTimes = {}     -- GetTime() of the answers of the last hour
local searchAsks = {}     -- GetTime() of the search's requests of the last minute
local asking = {}         -- lower name -> GetTime() until which a search's request to it waits for its answer

local function now() return GetTime() end
local function today() return ns.DropsToday and ns.DropsToday() or 0 end
local report = ns.ReportError
local function hex8(s) return ns.Checksum(s):sub(9, 16) end
local function isHex8(v) return type(v) == "string" and #v == 8 and v:match("^%x+$") ~= nil end
local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
local function debugLine(text)
    if ns.Get("sync.debug") then DEFAULT_CHAT_FRAME:AddMessage("|cff999999" .. L["Amisia Rezepte: %s"]:format(text) .. "|r") end
end

---------------------------------------------------------------------------
-- The store of heard crafters
---------------------------------------------------------------------------
local function store(create)
    if not AmisiaDB then return nil end
    local s = AmisiaDB.crafters
    if type(s) ~= "table" or s.v ~= 1 or type(s.c) ~= "table" or type(s.src) ~= "table" then
        if not create then return nil end
        s = { v = 1, c = {}, src = {} }
        AmisiaDB.crafters = s
    end
    return s
end

local gen = 0             -- the crafters (heard or own) changed: indexes and caches are built again
local function changed()
    gen = gen + 1
    ns.Fire("CRAFTERS_CHANGED")
end
Cr.Changed = changed

local function validName(v)
    return type(v) == "string" and #v <= 48 and ns.FullName(v) == v and ns.DropsCleanName and ns.DropsCleanName(v) == v
end

-- A stored profession as it may stay: rank, max, index checksum and a bitset or a spell list.
local function validProf(skill, p)
    if not int(skill, 1, 99999) or type(p) ~= "table" or not int(p.r, 0, 999) or not int(p.m or 0, 0, 999) then return false end
    if p.b ~= nil then
        return isHex8(p.h) and type(p.b) == "string" and #p.b <= LIM.bitsMax and #p.b % 2 == 0 and p.b:match("^%x*$") ~= nil and p.l == nil
    end
    return type(p.l) == "string" and #p.l <= LIM.knownMax * 8 and p.l:match("^[%d,]*$") ~= nil
end

-- The bytes of a crafter's bitsets and lists.
function Cr.Bytes(c)
    local n = 0
    for _, p in pairs(type(c) == "table" and type(c.p) == "table" and c.p or {}) do
        if type(p) == "table" then n = n + #(type(p.l) == "string" and p.l or type(p.b) == "string" and p.b or "") end
    end
    return n
end

-- Drops what is malformed, what was not heard of for keepDays and, above storeMax, the oldest.
-- Returns how many crafters went.
function Cr.Prune()
    local s = store(false)
    if not s then
        if AmisiaDB and AmisiaDB.crafters ~= nil then AmisiaDB.crafters = nil end
        return 0
    end
    local min, gone, list = today() - LIM.keepDays, 0, {}
    for name, c in pairs(s.c) do
        local ok = validName(name) and type(c) == "table" and int(c.seen, 0, 999999) and c.seen >= min
            and type(c.via) == "string" and type(c.p) == "table"
        if ok then
            for skill, p in pairs(c.p) do
                if not validProf(skill, p) then c.p[skill] = nil end
            end
            ok = next(c.p) ~= nil
        end
        if ok then
            list[#list + 1] = { name = name, seen = c.seen }
        else
            s.c[name] = nil
            gone = gone + 1
        end
    end
    -- above storeMax crafters or storeBytes of bitsets and lists: the oldest go
    local bytes = 0
    for _, x in ipairs(list) do
        x.bytes = Cr.Bytes(s.c[x.name])
        bytes = bytes + x.bytes
    end
    if #list > LIM.storeMax or bytes > LIM.storeBytes then
        table.sort(list, function(a, b)
            if a.seen ~= b.seen then return a.seen < b.seen end
            return a.name < b.name
        end)
        local left = #list
        for i = 1, #list do
            if left <= LIM.storeMax and bytes <= LIM.storeBytes then break end
            s.c[list[i].name] = nil
            gone, left, bytes = gone + 1, left - 1, bytes - list[i].bytes
        end
    end
    for low, e in pairs(s.src) do
        if type(low) ~= "string" or type(e) ~= "table" or not int(e.at, 0, 999999) or e.at < min then s.src[low] = nil end
    end
    stats.pruned = stats.pruned + gone
    if gone > 0 then changed() end
    return gone
end

---------------------------------------------------------------------------
-- The own crafters: the characters of this account that stand in the current guild
---------------------------------------------------------------------------
local function guildName()
    if type(IsInGuild) ~= "function" or ns.Plain(IsInGuild()) ~= true then return nil end
    local g = type(GetGuildInfo) == "function" and ns.Plain((GetGuildInfo("player"))) or nil
    return type(g) == "string" and g ~= "" and g or nil
end

local function profDB()
    local p = AmisiaDB and AmisiaDB.prof
    return type(p) == "table" and type(p.chars) == "table" and p or nil
end

-- The current character's guild (kept so its recipes go to that guild only, also from an alt).
local function markGuild(p, me)
    if not p.chars[me] then return end
    local g = guildName()
    local out = type(IsInGuild) == "function" and ns.Plain(IsInGuild()) == false
    if not g and not out then return end   -- the guild is not known yet (just after the login)
    p.guild = type(p.guild) == "table" and p.guild or {}
    p.guild[me] = g
end

local ownGen, ownCache = 0, nil
ns.Listen("PROF_CHANGED", function()
    ownGen = ownGen + 1
    changed()
end)

-- The own crafters announced to the guild: { { name, profs = { { skill, rank, max, known = { [spell]
-- = true }, day (read on that day) } } } }, the current character first, then by name; at most
-- crafterMax with profMax professions each, only professions read from the window.
local NONE = {}          -- the one empty list (the same table each time, so the caches keyed by it hold)
function Cr.Own()
    local p, g = profDB(), guildName()
    if not p then return NONE end
    local me = ns.UnitFullName and ns.UnitFullName("player") or "?"
    markGuild(p, me)
    if not g then return NONE end
    if ownCache and ownCache.gen == ownGen and ownCache.guild == g and ownCache.me == me then return ownCache.list end
    local names = {}
    for name, c in pairs(p.chars) do
        if validName(name) and type(c) == "table" and (name == me or (type(p.guild) == "table" and p.guild[name] == g)) then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b)
        if (a == me) ~= (b == me) then return a == me end
        return a < b
    end)
    local list = {}
    for _, name in ipairs(names) do
        local profs, skills = {}, {}
        for skill, s in pairs(p.chars[name]) do
            if int(skill, 1, 99999) and type(s) == "table" and type(s.known) == "table" then skills[#skills + 1] = skill end
        end
        table.sort(skills)
        for _, skill in ipairs(skills) do
            if #profs >= LIM.profMax then break end
            local s = p.chars[name][skill]
            profs[#profs + 1] = { skill = skill, rank = int(s.rank, 0, 999) and s.rank or 0, max = int(s.max, 0, 999) and s.max or 0,
                known = s.known, day = int(s.day, 0, 999999) and s.day or nil }
        end
        if #profs > 0 and #list < LIM.crafterMax then list[#list + 1] = { name = name, profs = profs } end
    end
    ownCache = { gen = ownGen, guild = g, me = me, list = list }
    return list
end

local function sortedSpells(known)
    local out = {}
    for spell, on in pairs(known) do
        if on == true and int(spell, 1, 9999999) then out[#out + 1] = spell end
    end
    table.sort(out)
    return out
end

-- The digest of the own crafters (8 hex): names, professions, ranks and every known spell. The same
-- whatever format a blob uses, so an asker can compare it with what it pulled.
local digestCache
function Cr.Digest()
    local list = Cr.Own()
    if digestCache and digestCache.list == list then return digestCache.d, #list end
    local parts = {}
    for _, c in ipairs(list) do
        local row = { c.name }
        for _, pr in ipairs(c.profs) do
            local spells = sortedSpells(pr.known)
            if #spells > LIM.knownMax then
                for i = #spells, LIM.knownMax + 1, -1 do spells[i] = nil end
            end
            row[#row + 1] = ("%d:%d:%d:%s"):format(pr.skill, pr.rank, pr.max, table.concat(spells, ","))
        end
        parts[#parts + 1] = table.concat(row, "|")
    end
    local d = #list > 0 and hex8(table.concat(parts, "\n")) or "00000000"
    digestCache = { list = list, d = d }
    return d, #list
end

---------------------------------------------------------------------------
-- The recipe index of a profession: its spells sorted by id, with a checksum
---------------------------------------------------------------------------
local idxData, idxCache = nil, {}
local function indexOf(skill)
    local d = ns.Data("PROFESSIONS")
    if not d or not ns.Prof then return nil end
    if idxData ~= d then idxData, idxCache = d, {} end
    -- kept while the parsed recipes are the same table (Professions.lua parses them again after a reset)
    local recipes = ns.Prof.Recipes(skill)
    local ix = idxCache[skill]
    if ix and ix.src == recipes then return ix.list and ix or nil end
    local list, seen = {}, {}
    for _, r in ipairs(recipes) do
        if not seen[r.spell] then
            seen[r.spell] = true
            list[#list + 1] = r.spell
        end
    end
    table.sort(list)
    if #list == 0 then
        idxCache[skill] = { src = recipes }
        return nil
    end
    ix = { src = recipes, list = list, hash = hex8(table.concat(list, ",")) }
    idxCache[skill] = ix
    return ix
end
Cr._index = indexOf

-- The known spells of the index as hex, bit i of the index in byte floor(i / 8), the lowest bit
-- first.
local function toBits(ix, known)
    local out = {}
    local nb = math.ceil(#ix.list / 8)
    for b = 0, nb - 1 do
        local v, w = 0, 1
        for j = 1, 8 do
            local spell = ix.list[b * 8 + j]
            if spell and known[spell] then v = v + w end
            w = w * 2
        end
        out[#out + 1] = ("%02x"):format(v)
    end
    return table.concat(out)
end

-- The spells of a bitset over the index, or nil when it does not fit the index.
local function fromBits(ix, hex)
    if #hex ~= 2 * math.ceil(#ix.list / 8) then return nil end
    local out = {}
    for b = 0, #hex / 2 - 1 do
        local v = tonumber(hex:sub(2 * b + 1, 2 * b + 2), 16)
        for j = 1, 8 do
            if v % 2 == 1 then
                local spell = ix.list[b * 8 + j]
                if not spell then return nil end
                out[#out + 1] = spell
            end
            v = math.floor(v / 2)
        end
    end
    return out
end
Cr._toBits, Cr._fromBits = toBits, fromBits

---------------------------------------------------------------------------
-- When the exchange may talk
---------------------------------------------------------------------------
local function battlefield()
    local pvp = _G.C_PvP
    if type(pvp) ~= "table" or type(pvp.IsActiveBattlefield) ~= "function" then return false end
    local ok, on = pcall(pvp.IsActiveBattlefield)
    return ok and ns.Plain(on) == true
end

local function inside()
    if type(IsInInstance) == "function" and ns.Plain((IsInInstance())) == true then return true end
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind ~= nil and kind ~= "none" then return true end
    return battlefield()
end

-- Whether the character is inside an instance or a battleground, or came out of one only moments ago (5 to 15 s,
-- so the guild's members leaving one dungeon do not all talk at once). What wanted to go waits meanwhile.
local wasInside, outAt = false, nil
local function away()
    if inside() then
        wasInside, outAt = true, nil
        return true
    end
    if wasInside then
        wasInside = false
        outAt = now() + LIM.outWait + math.random() * LIM.outSpread
    end
    if outAt and now() >= outAt then outAt = nil end
    return outAt ~= nil
end
ns.OnEvent("PLAYER_ENTERING_WORLD", function() away() end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() away() end)

-- Whether nothing may go and nothing waits: sharing off, no messages, no guild, the lockdown, a raid synced.
-- Combat holds nothing back.
local function shut()
    if not AmisiaDB or not ns.Get("crafters.share") then return true end
    if not ns.CommAvailable() or not ns.CommPacking() then return true end
    if type(IsInGuild) ~= "function" or ns.Plain(IsInGuild()) ~= true then return true end
    if ns.CommHeld() then return true end
    return ns.Active ~= nil and ns.Active() ~= nil and ns.RaidSyncReady() and true or false
end

function ns.CraftersCanTalk()
    local out = away()
    return not shut() and not out
end
local canTalk = function() return ns.CraftersCanTalk() end

---------------------------------------------------------------------------
-- Sending within the session's bytes and each asker's share
---------------------------------------------------------------------------
local function askerOf(low)
    local a = askers[low]
    if not a then
        a = { bytes = 0 }
        askers[low] = a
    end
    return a
end
local function afford(n, low)
    if stats.bytes + n > LIM.sessionBytes then return false end
    if low and askerOf(low).bytes + n > LIM.sessionBytes / LIM.askerShare then return false end
    return true
end
local function charge(n, low)
    stats.bytes = stats.bytes + n
    if low then askerOf(low).bytes = askerOf(low).bytes + n end
end

local function send(kind, fields, chan, target, key, low, reserve)
    local n = #"Amisia" + #tostring(ns.SYNC_PROTO) + #kind + 1 + #table.concat(fields, "\t")
    if reserve then
        -- a PW answers a request even when the bytes are spent, within a small reserve
        if stats.bytes + n > LIM.sessionBytes + LIM.pwReserve then return false end
    elseif not afford(n, low) then
        debugLine(L["Sendegrenze erreicht."])
        return false
    end
    local ok = ns.CommSend(kind, fields, chan, target, { low = true, when = canTalk, key = key })
    if not ok then return false end
    charge(n, low)
    stats[kind:lower()] = stats[kind:lower()] + 1
    return true
end

---------------------------------------------------------------------------
-- Announcing (PV)
---------------------------------------------------------------------------
local function setFirst()
    if firstAt then return end
    local d = ns.DropsDB and ns.DropsDB()
    local spread = d and type(d.me) == "string" and tonumber(d.me:sub(3, 6), 16) or 0
    firstAt = now() + LIM.firstMin + spread % (LIM.firstSpread + 1)
end
ns.OnEvent("PLAYER_LOGIN", setFirst)

local function announce()
    if not firstAt or now() < firstAt or not canTalk() then return end
    local d, n = Cr.Digest()
    if n == 0 then return end
    if lastPV then
        local since = now() - lastPV
        if since < LIM.changeGap then return end
        if since < LIM.every and d == lastD then return end
    end
    if send("PV", { tostring(ns.CRAFT_PROTO), tostring(n), d }, "GUILD", nil, "PV") then
        lastPV, lastD = now(), d
    end
end

---------------------------------------------------------------------------
-- Pulling: PQ and the PK blob
---------------------------------------------------------------------------
local function queuePeer(name, d, n, nb, f, retry)
    local low = name:lower()
    -- one waiting pull per sender, and apart from it one of what it passes on (format R, F-240)
    for i, p in ipairs(peers) do
        if p.low == low and (p.f == "R") == (f == "R") then table.remove(peers, i) break end
    end
    peers[#peers + 1] = { name = name, low = low, d = d, n = n or 0, at = now(), nb = nb or now(), f = f, retry = retry or 0 }
    while #peers > LIM.peersMax do
        -- the one with the fewest crafters, the oldest of those
        local worst
        for i, p in ipairs(peers) do
            if not worst or p.n < peers[worst].n or (p.n == peers[worst].n and p.at < peers[worst].at) then worst = i end
        end
        table.remove(peers, worst)
    end
end

local function hourCount()
    local t, keep = now(), {}
    for _, at in ipairs(pqTimes) do
        if t - at < 3600 then keep[#keep + 1] = at end
    end
    pqTimes = keep
    return #keep
end

local function nextNonce()
    if not nonceSeq then nonceSeq = math.floor(now() * 10) % 999999 end
    nonceSeq = nonceSeq % 999999 + 1
    return nonceSeq
end

local function startNext()
    if pull or #peers == 0 or not canTalk() then return end
    local t, ready = now(), {}
    -- the stale ones go first: removing one while collecting would shift the indices kept already
    for i = #peers, 1, -1 do
        if t - peers[i].at > LIM.peerKeep then table.remove(peers, i) end
    end
    -- not within the receiver's gap for PQ after the last request to it (a pull of what it passes on follows one of
    -- its own crafters, F-240)
    for i, p in ipairs(peers) do
        if p.nb <= t and not (askedAt[p.low] and t - askedAt[p.low] < LIM.askGap + 2) then ready[#ready + 1] = i end
    end
    if #ready == 0 then return end
    if hourCount() >= (now() < boostUntil and LIM.pqBoost or LIM.pqPerHour) then
        debugLine(L["Anfragen der Stunde erreicht."])
        return
    end
    local i = ready[math.random(#ready)]
    local p = table.remove(peers, i)
    local s = store(false)
    local src = s and s.src[p.low]
    if p.f ~= "R" and src and src.d == p.d then return end   -- pulled meanwhile
    local f = p.f == "R" and "R" or p.f or (src and src.f) or "B"
    local nonce = nextNonce()
    if not send("PQ", { tostring(ns.CRAFT_PROTO), f, tostring(nonce) }, "WHISPER", p.name) then return end
    pqTimes[#pqTimes + 1] = t
    askedAt[p.low] = t
    stats.pulls = stats.pulls + 1
    asked[nonce] = { low = p.low, f = f, at = t }
    pull = { name = p.name, low = p.low, d = p.d, n = p.n, f = f, nonce = nonce, deadline = t + LIM.pqWait, retry = p.retry }
end

-- The crafters of this sender heard again (an announcement with the digest pulled): seen today.
local function touch(low)
    local s = store(false)
    if not s then return end
    local d = today()
    if s.src[low] then s.src[low].at = d end
    for _, c in pairs(s.c) do
        if type(c) == "table" and type(c.via) == "string" and c.via:lower() == low and not c.relay then c.seen = d end
    end
end

ns.CommOn("PV", function(sender, f, chan)
    -- F-240: by whisper only as an answer to the own question, with the count of crafters passed on
    local answer = chan == "WHISPER" and helloSent and now() - helloSent <= LIM.helloKeep
    if chan ~= "GUILD" and not answer then return end
    if tonumber(f[1]) ~= ns.CRAFT_PROTO then
        stats.other = stats.other + 1
        return
    end
    if not AmisiaDB or not ns.Get("crafters.share") then return end
    local d, n = f[3]:lower(), tonumber(f[2])
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
        local low = name:lower()
        local relayN = answer and tonumber(f[4]) or nil
        if relayN and relayN > 0 and relayN <= 999 and relayN == math.floor(relayN) then
            offers[low] = { name = name, n = relayN }
            -- an answer after the pick: pulled too while fewer than relayPick were picked
            if relayPicked and relayPickedN < LIM.relayPick then
                relayPickedN = relayPickedN + 1
                queuePeer(name, "relay", relayN, now() + math.random() * LIM.pullJitter, "R")
            end
        end
        local s = store(false)
        local src = s and s.src[low]
        -- the sender's own entry passed on by someone else (F-240): its own word is pulled, whatever the digest
        local relayed = false
        for cname, c in pairs(s and s.c or {}) do
            if type(cname) == "string" and cname:lower() == low and type(c) == "table" and c.relay then relayed = true end
        end
        if src and src.d == d and not relayed then return touch(low) end
        if n == 0 or (pull and pull.low == low) then return end
        queuePeer(name, d, n, now() + math.random() * LIM.pullJitter, src and src.f)
    end)
end)

ns.CommOn("PW", function(sender, f, chan)
    if chan ~= "WHISPER" or not pull then return end
    local name = ns.TrustName(sender)
    if not name or name:lower() ~= pull.low then return end
    stats.busy = stats.busy + 1
    asked[pull.nonce] = nil
    local wait = math.max(60, math.min(tonumber(f[1]) or LIM.busyWait, 3600))
    queuePeer(pull.name, pull.d, pull.n, now() + wait + math.random() * LIM.pullJitter, pull.f, pull.retry)
    pull = nil
end)

-- A blob checked whole: { v = 1, d = digest, f = "B"|"L", m = 1 (cut), c = { { name, { { skill, rank,
-- max, index checksum, bitset hex | { spell steps } } } } } }; at most crafterMax crafters with
-- profMax professions each, every name a plain character name, every field in its range; one bad
-- field drops the whole blob. Returns the crafters { { name, p = { [skill] = stored profession } } }.
local BLOB_KEYS = { v = true, d = true, f = true, m = true, c = true }
local function checkSteps(steps)
    if type(steps) ~= "table" then return nil end
    local n = #steps
    if n > LIM.knownMax or size(steps) ~= n then return nil end
    local out, at = {}, 0
    for i = 1, n do
        local s = steps[i]
        if not int(s, 1, 9999999) then return nil end
        at = at + s
        if at > 9999999 then return nil end
        out[i] = at
    end
    return table.concat(out, ",")
end

local function checkBlob(tbl, ask)
    if type(tbl) ~= "table" or tbl.v ~= 1 or not isHex8(tbl.d) or tbl.f ~= ask.f or (tbl.m ~= nil and tbl.m ~= 1) then return nil end
    for k in pairs(tbl) do
        if not BLOB_KEYS[k] then return nil end
    end
    local c = tbl.c
    if c == nil then return {} end
    if type(c) ~= "table" then return nil end
    local n = #c
    if n > LIM.crafterMax or size(c) ~= n then return nil end
    local out, names = {}, {}
    for i = 1, n do
        local x = c[i]
        if type(x) ~= "table" or size(x) ~= 2 or not validName(x[1]) or type(x[2]) ~= "table" then return nil end
        local low = x[1]:lower()
        if names[low] then return nil end
        names[low] = true
        local profs, np = x[2], #x[2]
        if np < 1 or np > LIM.profMax or size(profs) ~= np then return nil end
        local p = {}
        for j = 1, np do
            local e = profs[j]
            if type(e) ~= "table" or size(e) ~= 5 then return nil end
            local skill, rank, max, h, data = e[1], e[2], e[3], e[4], e[5]
            if not int(skill, 1, 99999) or p[skill] or not int(rank, 0, 999) or not int(max, 0, 999) or not isHex8(h) then return nil end
            if ask.f == "B" then
                if type(data) ~= "string" or #data > LIM.bitsMax or #data % 2 ~= 0 or not data:match("^%x*$") then return nil end
                p[skill] = { r = rank, m = max, h = h:lower(), b = data:lower() }
            else
                local list = checkSteps(data)
                if not list then return nil end
                p[skill] = { r = rank, m = max, h = h:lower(), l = list }
            end
        end
        out[#out + 1] = { name = x[1], p = p }
    end
    return out
end

-- Whether the profession data is built already (a check that needs it builds nothing else).
local function dataBuilt() return ns.DataLoaded("PROFESSIONS") end

-- Takes the checked crafters of a sender: each must stand in the guild; what a crafter sent itself
-- is not replaced by another sender's word for selfDays; a whole answer drops the sender's crafters
-- it no longer names (a cut one keeps them and is pulled again at the next announcement). Returns
-- true when a bitset did not fit the own index (other data).
-- Whether name is the sender or one of its characters: a known alt of the sender's main (the alts
-- list pasted from the website). Another member's word about someone else is never taken.
local function sameAccount(senderName, name)
    if name:lower() == senderName:lower() then return true end
    local ms = ns.AltMain and ns.AltMain(senderName)
    local mn = ns.AltMain and ns.AltMain(name)
    if not ms and not mn then return false end
    return ns.SameName(ms or senderName, mn or name)
end

-- The spells of a list kept: only those of the own recipe index of the profession (nil when the
-- profession has no index here).
local function knownList(skill, l)
    local ix = indexOf(skill)
    if not ix then return nil end
    local inIx = ix.set
    if not inIx then
        inIx = {}
        for _, spell in ipairs(ix.list) do inIx[spell] = true end
        ix.set = inIx
    end
    local out = {}
    for spell in l:gmatch("%d+") do
        spell = tonumber(spell)
        if inIx[spell] and #out < #ix.list then out[#out + 1] = spell end
    end
    return table.concat(out, ",")
end

local function apply(senderName, low, list, tbl)
    local s = store(true)
    local d, mismatch, names = today(), false, {}
    local own = {}
    for _, c in ipairs(Cr.Own()) do own[c.name:lower()] = true end
    -- what this sender gave already (a cut answer keeps it): counted against the caps per sender
    local held, heldN, heldBytes = {}, 0, 0
    for name, c in pairs(s.c) do
        if type(c) == "table" and type(c.via) == "string" and c.via:lower() == low and not c.relay then
            held[name], heldN, heldBytes = Cr.Bytes(c), heldN + 1, heldBytes + Cr.Bytes(c)
        end
    end
    for _, x in ipairs(list) do
        local cl = x.name:lower()
        if tbl.f == "L" then
            for skill, p in pairs(x.p) do
                local l = knownList(skill, p.l)
                if l then
                    p.l = l
                else
                    x.p[skill] = nil
                    stats.unknown = stats.unknown + 1
                end
            end
        end
        local bytes = Cr.Bytes(x)
        if own[cl] then
            stats.kept = stats.kept + 1
        elseif not sameAccount(senderName, x.name) then
            stats.foreign = stats.foreign + 1
        elseif ns.IsVerifiedMember(x.name) ~= true then
            stats.outsider = stats.outsider + 1
        elseif next(x.p) == nil then
            stats.unknown = stats.unknown + 1
        elseif (not held[x.name] and heldN >= LIM.crafterMax)
            or heldBytes - (held[x.name] or 0) + bytes > LIM.viaBytes then
            stats.capped = stats.capped + 1
        else
            local cur = s.c[x.name]
            local self = cl == low
            if type(cur) == "table" and cur.self and not self and type(cur.via) == "string" and cur.via:lower() ~= low
                and d - (cur.seen or 0) < LIM.selfDays then
                stats.kept = stats.kept + 1
            else
                if not held[x.name] then heldN = heldN + 1 end
                heldBytes = heldBytes - (held[x.name] or 0) + bytes
                held[x.name] = bytes
                names[x.name] = true
                s.c[x.name] = { via = senderName, self = self or nil, seen = d, p = x.p }
                stats.crafters = stats.crafters + 1
            end
            if tbl.f == "B" and dataBuilt() then
                for skill, p in pairs(x.p) do
                    local ix = indexOf(skill)
                    if ix and (ix.hash ~= p.h or not fromBits(ix, p.b)) then mismatch = true end
                end
            end
        end
    end
    if not tbl.m then
        for name, c in pairs(s.c) do
            if not names[name] and type(c) == "table" and type(c.via) == "string" and c.via:lower() == low and not c.relay then
                s.c[name] = nil
            end
        end
    end
    local src = s.src[low] or {}
    s.src[low] = { d = tbl.d:lower(), at = d, f = (mismatch or src.f == "L" or tbl.f == "L") and "L" or nil }
    -- other data, or a cut answer: pulled again at the next announcement
    if mismatch or tbl.m then s.src[low].d = nil end
    Cr.Prune()
    changed()
    return mismatch
end

-- F-240: an answer in the format R checked whole: { v = 1, d, f = "R", m, c = { { name, { { skill, rank, max, index
-- checksum, bitset hex | { spell steps } } }, age in days 0..relayDays } } }; at most relayMax crafters; one bad
-- field drops the whole answer. Returns { { name, p, age } }.
local function checkRelay(tbl)
    if type(tbl) ~= "table" or tbl.v ~= 1 or not isHex8(tbl.d) or tbl.f ~= "R" or (tbl.m ~= nil and tbl.m ~= 1) then return nil end
    for k in pairs(tbl) do
        if not BLOB_KEYS[k] then return nil end
    end
    local c = tbl.c
    if c == nil then return {} end
    if type(c) ~= "table" then return nil end
    local n = #c
    if n > LIM.relayMax or size(c) ~= n then return nil end
    local out, names = {}, {}
    for i = 1, n do
        local x = c[i]
        if type(x) ~= "table" or size(x) ~= 3 or not validName(x[1]) or type(x[2]) ~= "table" or not int(x[3], 0, LIM.relayDays) then
            return nil
        end
        local low = x[1]:lower()
        if names[low] then return nil end
        names[low] = true
        local profs, np = x[2], #x[2]
        if np < 1 or np > LIM.profMax or size(profs) ~= np then return nil end
        local p = {}
        for j = 1, np do
            local e = profs[j]
            if type(e) ~= "table" or size(e) ~= 5 then return nil end
            local skill, rank, max, h, data = e[1], e[2], e[3], e[4], e[5]
            if not int(skill, 1, 99999) or p[skill] or not int(rank, 0, 999) or not int(max, 0, 999) or not isHex8(h) then return nil end
            if type(data) == "string" then
                if #data > LIM.bitsMax or #data % 2 ~= 0 or not data:match("^%x*$") then return nil end
                p[skill] = { r = rank, m = max, h = h:lower(), b = data:lower() }
            else
                local list = checkSteps(data)
                if not list then return nil end
                p[skill] = { r = rank, m = max, h = h:lower(), l = list }
            end
        end
        out[#out + 1] = { name = x[1], p = p, age = x[3] }
    end
    return out
end

-- F-240: takes the crafters a sender passed on: each must stand in the guild, be none of the own characters and
-- not the sender's (those come the usual way); one is kept with the day it sent itself, unless the store has it
-- from that day or later; the sender's passed-on crafters stay within viaBytes. Returns how many were taken.
local function applyRelay(senderName, low, list)
    local s = store(true)
    local d, n = today(), 0
    local own = {}
    for _, c in ipairs(Cr.Own()) do own[c.name:lower()] = true end
    local heldBytes = 0
    for _, c in pairs(s.c) do
        if type(c) == "table" and c.relay and type(c.via) == "string" and c.via:lower() == low then heldBytes = heldBytes + Cr.Bytes(c) end
    end
    for _, x in ipairs(list) do
        local cl = x.name:lower()
        if own[cl] then
            stats.kept = stats.kept + 1
        elseif sameAccount(senderName, x.name) then
            stats.foreign = stats.foreign + 1
        elseif ns.IsVerifiedMember(x.name) ~= true then
            stats.outsider = stats.outsider + 1
        else
            for skill, p in pairs(x.p) do
                if p.l then
                    local l = knownList(skill, p.l)
                    if l then p.l = l else x.p[skill] = nil end
                elseif dataBuilt() then
                    -- a bitset of another recipe index is of no use here (and asking the passer for lists would not
                    -- change what it passes on)
                    local ix = indexOf(skill)
                    if ix and (ix.hash ~= p.h or not fromBits(ix, p.b)) then x.p[skill] = nil end
                end
            end
            local seen = d - x.age
            local cur = s.c[x.name]
            local curSeen = type(cur) == "table" and int(cur.seen, 0, 999999) and cur.seen or nil
            if next(x.p) == nil then
                stats.unknown = stats.unknown + 1
            elseif (type(cur) == "table" and cur.self) or (curSeen and curSeen >= seen) then
                -- what the crafter sent itself is never replaced by a word passed on; else the newer stays
                stats.kept = stats.kept + 1
            else
                local mineBefore = type(cur) == "table" and cur.relay and type(cur.via) == "string" and cur.via:lower() == low
                local bytes = Cr.Bytes(x)
                if heldBytes - (mineBefore and Cr.Bytes(cur) or 0) + bytes > LIM.viaBytes then
                    stats.capped = stats.capped + 1
                else
                    heldBytes = heldBytes - (mineBefore and Cr.Bytes(cur) or 0) + bytes
                    s.c[x.name] = { via = senderName, relay = true, seen = seen, p = x.p }
                    n = n + 1
                end
            end
        end
    end
    local src = s.src[low]
    if type(src) == "table" then src.r = d else s.src[low] = { at = d, r = d } end
    stats.relayed = stats.relayed + n
    Cr.Prune()
    changed()
    return n
end

ns.CommOnBlob("PK", function(sender, tbl, chan, key)
    if chan ~= "WHISPER" then
        stats.bad = stats.bad + 1
        return
    end
    local name = ns.TrustName(sender)
    local low = name and name:lower()
    local nonce = tonumber(type(key) == "string" and key:match("^0000%-00%-01:(%d+)$") or nil)
    local ask = nonce and asked[nonce]
    if not ask or ask.low ~= low or now() - ask.at > LIM.askKeep then
        stats.unasked = stats.unasked + 1
        debugLine(L["Rezeptdaten ohne Anfrage verworfen."])
        return
    end
    asked[nonce] = nil
    asking[low] = nil
    local mine = pull and pull.nonce == nonce
    local list
    if ask.f == "R" then list = checkRelay(tbl) else list = checkBlob(tbl, ask) end
    if not list then
        stats.bad = stats.bad + 1
        debugLine(L["Ungültige Rezeptdaten verworfen."])
        if mine then pull = nil end
        return
    end
    stats.blobs = stats.blobs + 1
    if not AmisiaDB or not ns.Get("crafters.share") then
        if mine then pull = nil end
        return
    end
    if ask.f == "R" then
        applyRelay(name, low, list)
        if mine then pull = nil end
        return
    end
    local mismatch = apply(name, low, list, tbl)
    if mismatch then
        stats.mismatch = stats.mismatch + 1
        -- other data: the same sender once more, as a list (after the sender's minute per question)
        if ask.f == "B" then queuePeer(name, tbl.d:lower(), #list, now() + 65, "L") end
    end
    if mine then pull = nil end
end)

---------------------------------------------------------------------------
-- Answering: PQ with a PK blob, PW when busy or spent
---------------------------------------------------------------------------
local function shareLeft(low) return askerOf(low).bytes < LIM.sessionBytes / LIM.askerShare and stats.bytes < LIM.sessionBytes end
local function sendPW(name, low, wait)
    send("PW", { tostring(math.max(1, math.min(3600, math.floor(wait or LIM.busyWait)))) }, "WHISPER", name, nil, low, true)
end

ns.CommOn("PQ", function(sender, f, chan)
    if chan ~= "WHISPER" or not AmisiaDB or not ns.Get("crafters.share") then return end
    if tonumber(f[1]) ~= ns.CRAFT_PROTO then
        stats.other = stats.other + 1
        return
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
        if shut() then return end
        -- inside an instance the request waits for the way out (as long as the asker takes the answer, serveKeep);
        -- a refusal is not sent from there, the asker asks again
        local wait = away()
        local low = name:lower()
        if not shareLeft(low) then
            if wait then return end
            return sendPW(name, low, LIM.doneWait)
        end
        -- an asker has one request open at a time: a new one replaces what still waits for it
        for i = #serve, 1, -1 do
            if serve[i].low == low then table.remove(serve, i) end
        end
        if #serve >= LIM.serveMax then
            if wait then return end
            return sendPW(name, low, LIM.busyWait)
        end
        serve[#serve + 1] = { name = name, low = low, f = f[2], nonce = tonumber(f[3]), at = now() }
    end)
end)

-- The blob of the own crafters in format f; the first n crafters.
local function wire(f, list, n)
    local t = { v = 1, d = Cr.Digest(), f = f, c = {} }
    for i = 1, n do
        local c = list[i]
        local profs = {}
        for _, pr in ipairs(c.profs) do
            local ix = indexOf(pr.skill)
            if f == "B" then
                if ix then profs[#profs + 1] = { pr.skill, pr.rank, pr.max, ix.hash, toBits(ix, pr.known) } end
            else
                local spells, steps, at = sortedSpells(pr.known), {}, 0
                for j = 1, math.min(#spells, LIM.knownMax) do
                    steps[j] = spells[j] - at
                    at = spells[j]
                end
                profs[#profs + 1] = { pr.skill, pr.rank, pr.max, ix and ix.hash or "00000000", steps }
            end
        end
        if #profs > 0 then t.c[#t.c + 1] = { c.name, profs } end
    end
    if n < #list then t.m = 1 end
    if #t.c == 0 then t.c = nil end
    return t
end

local fitRelay, relayCount, hello, replyDue, pickRelays   -- F-240, below (they read the roster)

-- The most crafters that pack into maxParts: table and packed text, or nil.
local function fit(f, maxParts)
    local list = Cr.Own()
    local n = #list
    while n >= 0 do
        local tbl = wire(f, list, n)
        local packed = ns.CommPack(tbl)
        if not packed then return nil end
        if math.ceil(#packed / 200) <= maxParts then return tbl, packed end
        n = n - 1
    end
    return nil
end

local function partsRecent()
    local t, keep, n = now(), {}, 0
    for _, p in ipairs(partsLog) do
        if t - p[1] < LIM.partsWindow then
            keep[#keep + 1] = p
            n = n + p[2]
        end
    end
    partsLog = keep
    return n
end

local function serveOne()
    if #serve == 0 or not canTalk() then return end
    local t = now()
    for i = #serve, 1, -1 do
        if t - serve[i].at > LIM.serveKeep then table.remove(serve, i) end
    end
    if #serve == 0 or (lastBlob and t - lastBlob < LIM.serveGap) then return end
    -- the asker served longest ago first
    local pick, best
    for i, s in ipairs(serve) do
        local last = askerOf(s.low).served or -math.huge
        if not pick or last < best then pick, best = i, last end
    end
    local s = table.remove(serve, pick)
    local room = LIM.partsMax - partsRecent()
    if room < 1 then return sendPW(s.name, s.low, LIM.busyWait) end
    local a = askerOf(s.low)
    local left = math.min(LIM.sessionBytes - stats.bytes, LIM.sessionBytes / LIM.askerShare - a.bytes)
    local maxParts = math.min(LIM.blobParts, room, math.floor(left / (200 + PART_OVERHEAD)))
    if maxParts < 1 then
        debugLine(L["Sendegrenze erreicht."])
        return sendPW(s.name, s.low, LIM.doneWait)
    end
    local tbl, packed
    if s.f == "R" then tbl, packed = fitRelay(maxParts) else tbl, packed = fit(s.f, maxParts) end
    if not tbl then return sendPW(s.name, s.low, LIM.busyWait) end
    local parts = math.ceil(#packed / 200)
    local estimate = #packed + parts * PART_OVERHEAD
    if not afford(estimate, s.low) then
        debugLine(L["Sendegrenze erreicht."])
        return sendPW(s.name, s.low, LIM.doneWait)
    end
    local ok, n, bytes = ns.CommSendBlob("PK", KEY_PREFIX .. s.nonce, tbl, "WHISPER", s.name, { low = true, when = canTalk })
    if not ok then return end
    charge(bytes or estimate, s.low)
    stats.served = stats.served + 1
    if s.f == "R" then stats.relayServed = stats.relayServed + 1 end
    lastBlob, a.served = t, t
    partsLog[#partsLog + 1] = { t, n or parts }
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------
local function tick()
    if not AmisiaDB then return end
    local t = now()
    if pull and not canTalk() then
        -- cut off by the conditions: asked again later
        queuePeer(pull.name, pull.d, pull.n, t + LIM.pullJitter, pull.f, pull.retry)
        asked[pull.nonce] = nil
        pull = nil
    elseif pull and t > pull.deadline then
        stats.missed = stats.missed + 1
        if pull.retry < LIM.retries then queuePeer(pull.name, pull.d, pull.n, t + LIM.retryWait, pull.f, pull.retry + 1) end
        pull = nil
    end
    if not pull then startNext() end
    announce()
    hello()
    replyDue()
    pickRelays()
    serveOne()
    for k, a in pairs(asked) do
        if t - a.at > LIM.askKeep then asked[k] = nil end
    end
end

C_Timer.NewTicker(LIM.tick, ns.Perf.Wrap("Ticker Crafters", function()
    local ok, err = pcall(tick)
    if not ok then report(err) end
end))

ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ns.ADDON or not AmisiaDB then return end
    Cr.Prune()
end)

function ns.CraftersStats()
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    out.pqHour = hourCount()
    return out
end

function ns.CraftersState()
    return { pulling = pull and pull.name or nil, waiting = #peers, serving = #serve }
end

-- Opens a request at a sender as a pull would (tests).
function ns.CraftersOpenAsk(name, nonce, f)
    asked[nonce] = { low = name:lower(), f = f or "B", at = now() }
end

---------------------------------------------------------------------------
-- Who can make what
---------------------------------------------------------------------------
local index               -- { gen, bySpell = { [spell] = { [name] = { rank, own } } }, byItem }
local function stale(low)
    local s = store(false)
    if s and s.src[low] then
        s.src[low].d, s.src[low].f = nil, "L"
    end
end

-- The guild roster as lower name -> member (online), read at most every 10 s; nil when unreadable.
local rosterAt, rosterMap
local function roster()
    local t = now()
    if rosterAt and t - rosterAt < 10 then return rosterMap end
    rosterAt = t
    local list = ns.GuildRoster and ns.GuildRoster()
    if not list then
        rosterMap = nil
        return nil
    end
    rosterMap = {}
    for _, m in ipairs(list) do rosterMap[m.name:lower()] = m end
    return rosterMap
end

---------------------------------------------------------------------------
-- F-240: what this client passes on (format R), the own question after the login and the answers to others'
---------------------------------------------------------------------------

-- The crafters that sent themselves to this client within relayDays and stand in the roster, none of the own
-- characters, never one passed on: { { name, c, age } }, the newest first.
local function relayList()
    local s, r = store(false), roster()
    if not s or not r then return {} end
    local d = today()
    local own = {}
    for _, c in ipairs(Cr.Own()) do own[c.name:lower()] = true end
    local list = {}
    for name, c in pairs(s.c) do
        if type(name) == "string" and type(c) == "table" and c.self and not c.relay and int(c.seen, 0, 999999)
            and d - c.seen <= LIM.relayDays and d >= c.seen and not own[name:lower()] and r[name:lower()] and type(c.p) == "table" then
            list[#list + 1] = { name = name, c = c, age = d - c.seen }
        end
    end
    table.sort(list, function(a, b)
        if a.age ~= b.age then return a.age < b.age end
        return a.name < b.name
    end)
    return list
end

relayCount = function() return math.min(#relayList(), 999) end

-- The answer in the format R: the first n crafters of list, each profession as it is stored (a bitset with its
-- index checksum, or the spell list as steps with the checksum 00000000).
local function wireRelay(list, n)
    local t = { v = 1, d = Cr.Digest(), f = "R", c = {} }
    for i = 1, n do
        local x = list[i]
        local skills = {}
        for skill, p in pairs(x.c.p) do
            if validProf(skill, p) then skills[#skills + 1] = skill end
        end
        table.sort(skills)
        local profs = {}
        for k = 1, math.min(#skills, LIM.profMax) do
            local skill = skills[k]
            local p = x.c.p[skill]
            if p.b then
                profs[#profs + 1] = { skill, p.r, p.m or 0, p.h, p.b }
            else
                local steps, at = {}, 0
                for id in p.l:gmatch("%d+") do
                    id = tonumber(id)
                    if id > at and #steps < LIM.knownMax then
                        steps[#steps + 1] = id - at
                        at = id
                    end
                end
                profs[#profs + 1] = { skill, p.r, p.m or 0, "00000000", steps }
            end
        end
        if #profs > 0 then t.c[#t.c + 1] = { x.name, profs, x.age } end
    end
    if n < #list then t.m = 1 end
    if #t.c == 0 then t.c = nil end
    return t
end

-- The most of them that pack into maxParts: table and packed text, or nil.
fitRelay = function(maxParts)
    local list = relayList()
    local n = math.min(#list, LIM.relayMax)
    while n >= 0 do
        local tbl = wireRelay(list, n)
        local packed = ns.CommPack(tbl)
        if not packed then return nil end
        if math.ceil(#packed / 200) <= maxParts then return tbl, packed end
        n = n > 8 and math.floor(n * 0.75) or n - 1
    end
    return nil
end

-- Whether this client heard any sender today (then it does not ask after the login).
local function heardToday()
    local s, d = store(false), today()
    for _, src in pairs(s and s.src or {}) do
        if type(src) == "table" and (src.at == d or src.r == d) then return true end
    end
    return false
end

-- the spread from the client's own id, as the first announcement takes it (no draw of math.random at the login)
ns.OnEvent("PLAYER_LOGIN", function()
    if helloAt then return end
    local dd = ns.DropsDB and ns.DropsDB()
    local spread = dd and type(dd.me) == "string" and tonumber(dd.me:sub(5, 8), 16) or 0
    helloAt = now() + LIM.helloMin + spread % (LIM.helloSpread + 1)
end)

-- The own question (PH), once a session, only without a sender heard today.
hello = function()
    if helloSent ~= nil or not helloAt or now() < helloAt or not canTalk() then return end
    if heardToday() then
        helloSent = false
        return
    end
    local s, n = store(false), 0
    for _ in pairs(s and s.c or {}) do n = n + 1 end
    if send("PH", { tostring(ns.CRAFT_PROTO), tostring(math.min(n, 999)) }, "GUILD", nil, "PH") then
        helloSent = now()
        boostUntil = helloSent + 3600
    end
end

-- After the answers: what the answerers with the most pass on is pulled (format R), relayPick of them.
pickRelays = function()
    if relayPicked or not helloSent or now() < helloSent + LIM.replyMin + LIM.replySpread + 15 then return end
    relayPicked = true
    local list = {}
    for _, o in pairs(offers) do list[#list + 1] = o end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    for i = 1, math.min(LIM.relayPick, #list) do
        queuePeer(list[i].name, "relay", list[i].n, now() + math.random() * LIM.pullJitter, "R")
    end
    relayPickedN = math.min(LIM.relayPick, #list)
end

-- Another member's question: an answer (the own PV by whisper with the count passed on) 5 to 60 s later, once an
-- hour per asker and replyPerHour askers an hour; nothing without anything to give.
ns.CommOn("PH", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    if tonumber(f[1]) ~= ns.CRAFT_PROTO then
        stats.other = stats.other + 1
        return
    end
    if not AmisiaDB or not ns.Get("crafters.share") then return end
    local name = ns.TrustName(sender)
    if not name then
        stats.refused = stats.refused + 1
        return
    end
    stats.phHeard = stats.phHeard + 1
    ns.TrustWait(name, "member", function(ok)
        if not ok then
            stats.refused = stats.refused + 1
            return
        end
        local low = name:lower()
        if repliedAt[low] and now() - repliedAt[low] < LIM.replyGap then return end
        for _, r in ipairs(replies) do
            if r.low == low then return end
        end
        replies[#replies + 1] = { name = name, low = low, at = now() + LIM.replyMin + math.random() * LIM.replySpread }
    end)
end)

replyDue = function()
    if #replies == 0 or not canTalk() then return end
    local t = now()
    local keep = {}
    for _, at in ipairs(replyTimes) do
        if t - at < 3600 then keep[#keep + 1] = at end
    end
    replyTimes = keep
    for i, r in ipairs(replies) do
        if r.at <= t then
            table.remove(replies, i)
            if #replyTimes >= LIM.replyPerHour then return end
            local d, n = Cr.Digest()
            local relayN = relayCount()
            if n == 0 and relayN == 0 then return end
            if send("PV", { tostring(ns.CRAFT_PROTO), tostring(n), d, tostring(relayN) }, "WHISPER", r.name, nil, r.low) then
                repliedAt[r.low] = t
                replyTimes[#replyTimes + 1] = t
                stats.replies = stats.replies + 1
            end
            return
        end
    end
end
ns.OnEvent("GUILD_ROSTER_UPDATE", function() rosterAt = nil end)

local function decode(skill, p)
    if p.l then
        local out = {}
        for id in p.l:gmatch("%d+") do out[#out + 1] = tonumber(id) end
        return out
    end
    local ix = indexOf(skill)
    if not ix then return {} end   -- a profession the own data does not have
    if ix.hash ~= p.h then return nil end
    return fromBits(ix, p.b)
end

local function build()
    if index and index.gen == gen then return index end
    local bySpell = {}
    -- via, age: a crafter passed on (F-240), by whom and how many days ago it sent itself
    local function add(name, rank, own, spell, via, age)
        local e = bySpell[spell]
        if not e then
            e = {}
            bySpell[spell] = e
        end
        local cur = e[name]
        if not cur or rank > cur.rank then e[name] = { rank = rank, own = own, via = via, age = age } end
    end
    if ns.HasData("PROFESSIONS") then
        local own = {}
        for _, c in ipairs(Cr.Own()) do
            own[c.name:lower()] = true
            for _, pr in ipairs(c.profs) do
                for spell, on in pairs(pr.known) do
                    if on == true then add(c.name, pr.rank, true, spell) end
                end
            end
        end
        local s = store(false)
        for name, c in pairs(s and s.c or {}) do
            if not own[name:lower()] and type(c) == "table" and type(c.p) == "table" then
                for skill, p in pairs(c.p) do
                    local spells = decode(skill, p)
                    if not spells then
                        -- the bitset fits other data: that sender is asked for lists next time (not a passer, F-240:
                        -- its lists would not change what it passes on)
                        if not c.relay then stale(c.via:lower()) end
                    else
                        local via = c.relay and c.via or nil
                        local age = via and int(c.seen, 0, 999999) and math.max(0, today() - c.seen) or nil
                        for _, spell in ipairs(spells) do add(name, p.r, false, spell, via, age) end
                    end
                end
            end
        end
    end
    index = { gen = gen, bySpell = bySpell, byItem = nil }
    return index
end

-- The crafters of entries { [name] = { rank, own, via, age } } as a sorted list { { name, rank, own, online, via, age } }
-- (via: passed on by that member, F-240):
-- online first (when the roster says so), then the higher rank, then the name; a heard crafter that
-- left the guild (the roster can be read and lacks it) is left out.
local function sorted(entries)
    local r = roster()
    local out = {}
    for name, e in pairs(entries or {}) do
        local m = r and r[name:lower()]
        if e.own or not r or m then
            out[#out + 1] = { name = name, rank = e.rank, own = e.own or false, online = m and m.online or false, via = e.via, age = e.age }
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.name < b.name
    end)
    return out
end

-- Who of the guild (and the own characters of this guild) knows a recipe.
function Cr.ForSpell(spell)
    return sorted(build().bySpell[tonumber(spell)])
end

-- Whether anyone of the guild knows the recipe (the page's filter): the same crafters as Cr.ForSpell,
-- so a heard crafter who left the guild counts as little there as here (F-233).
function Cr.Has(spell)
    local e = build().bySpell[tonumber(spell)]
    if e == nil or next(e) == nil then return false end
    local r = roster()
    if not r then return true end
    for name, x in pairs(e) do
        if x.own or r[name:lower()] then return true end
    end
    return false
end

-- Who can make an item: the crafters of every recipe that makes it (the highest rank per name).
function Cr.ForItem(item)
    item = tonumber(item)
    local ix = build()
    if not ix.byItem then
        ix.byItem = {}
        if ns.Prof and ns.HasData("PROFESSIONS") then
            for _, skill in ipairs(ns.Prof.Skills()) do
                for _, r in ipairs(ns.Prof.Recipes(skill)) do
                    if r.item > 0 and ix.bySpell[r.spell] then
                        local list = ix.byItem[r.item] or {}
                        ix.byItem[r.item] = list
                        list[#list + 1] = r.spell
                    end
                end
            end
        end
    end
    local merged = {}
    for _, spell in ipairs(ix.byItem[item] or {}) do
        for name, e in pairs(ix.bySpell[spell]) do
            local cur = merged[name]
            if not cur or e.rank > cur.rank then merged[name] = e end
        end
    end
    return sorted(merged)
end

-- F-240: "laut Vulo, Stand vor 3 Tagen" of a crafter passed on (an entry of Cr.ForSpell or Cr.Professions), nil
-- for one heard from itself.
function Cr.ViaText(c)
    if type(c) ~= "table" or type(c.via) ~= "string" then return nil end
    local age = tonumber(c.age)
    if age and age > 0 then return L["laut %s, Stand vor %d Tagen"]:format(c.via, age) end
    return L["laut %s, Stand von heute"]:format(c.via)
end

-- "Anna (300), Bob (275)" of a sorted list, at most max names and "+n" for the rest; online names
-- in green when color.
function Cr.Text(list, max, color)
    local parts = {}
    for i, c in ipairs(list) do
        if max and i > max then
            parts[#parts + 1] = L["+%d weitere"]:format(#list - max)
            break
        end
        local text = ("%s (%d)"):format(c.name, c.rank)
        if color and c.online then text = ns.Theme.GREEN .. text .. "|r" end
        parts[#parts + 1] = text
    end
    return table.concat(parts, ", ")
end

-- Whether there is anyone to tell of (an own crafter or a heard one), without building anything.
local function anyone()
    local s = store(false)
    if s and next(s.c) then return true end
    return #Cr.Own() > 0
end

-- The tooltip line of an item ("Kann herstellen: Anna (300), Bob (275)"), or nil; kept per item for
-- 30 s and while nothing changes (at most TIP_CACHE_MAX items, then it starts again). Builds the
-- profession data only out of combat.
local TIP_CACHE_MAX = 200
local tipCache, tipGen, tipN = {}, -1, 0
function Cr.TooltipLine(item)
    item = tonumber(item)
    if not item or not AmisiaDB or not anyone() then return nil end
    if tipGen ~= gen then tipCache, tipGen, tipN = {}, gen, 0 end
    local hit = tipCache[item]
    if hit and now() - hit.at < 30 then return hit.line or nil end
    if not dataBuilt() and type(InCombatLockdown) == "function" and InCombatLockdown() then return nil end
    local list = Cr.ForItem(item)
    local line = #list > 0 and L["Kann herstellen: %s"]:format(Cr.Text(list, 4)) or false
    if not hit then
        if tipN >= TIP_CACHE_MAX then tipCache, tipN = {}, 0 end
        tipN = tipN + 1
    end
    tipCache[item] = { at = now(), line = line }
    return line or nil
end

local TIP_GREY = { 0.56, 0.53, 0.64 }
local tipHooked = false
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ns.ADDON or tipHooked then return end
    tipHooked = true
    ns.OnItemTooltip("crafters", function(tip, _, id)
        if not ns.Get("crafters.tooltip") then return false end
        local line = Cr.TooltipLine(id)
        if not line then return false end
        tip:AddLine(line, TIP_GREY[1], TIP_GREY[2], TIP_GREY[3])
        return true
    end)
end)

-- The crafter to ask first for a recipe: an online one that is not an own character, else any one
-- that is not; nil when there is none.
function Cr.AskWhom(spell)
    local first
    for _, c in ipairs(Cr.ForSpell(spell)) do
        if not c.own then
            if c.online then return c end
            first = first or c
        end
    end
    return first
end

-- Opens a whisper to name with a prefilled question for what (a link or a name); false when the
-- client has no way to.
function Cr.Whisper(name, what)
    if type(name) ~= "string" or name == "" then return false end
    local text = L["Hallo! Kannst du mir %s herstellen? Die Materialien bringe ich mit."]:format(what or "?")
    local util = _G.ChatFrameUtil
    if type(util) == "table" and type(util.SendTellWithMessage) == "function" then
        return (pcall(util.SendTellWithMessage, name, text))
    end
    -- "/w First Surname text" would whisper "First": a name with a space only opens the whisper
    if name:find(" ", 1, true) then
        if type(_G.ChatFrame_SendTell) == "function" then return (pcall(_G.ChatFrame_SendTell, name)) end
        return false
    end
    if type(_G.ChatFrame_OpenChat) == "function" then
        return (pcall(_G.ChatFrame_OpenChat, ("/w %s %s"):format(name, text)))
    end
    return false
end

---------------------------------------------------------------------------
-- Asking on a search (F-035): the heard crafters of the hits whose list is old and who are online now
---------------------------------------------------------------------------
-- Asks the heard crafters of spells (the hits of a search, the first askScan) whose list was last heard of more
-- than askOldDays days ago and whom the roster names online for a fresh list: the same PQ a pull sends, to the
-- crafter itself, its answer taken like a pull's. Oldest first; askPerMinute requests a minute, one request to a
-- crafter per askGap seconds, within the requests of the hour (pqPerHour); never where the exchange may not
-- talk (canTalk: an instance, the lockdown, sharing off, ...), never to an own character or the one being pulled.
-- Returns the names asked.
function Cr.AskOld(spells)
    local out = {}
    if type(spells) ~= "table" or #spells == 0 or not canTalk() then return out end
    local s = store(false)
    local r = roster()
    if not s or not r then return out end
    local t, d = now(), today()
    local keep = {}
    for _, at in ipairs(searchAsks) do
        if t - at < 60 then keep[#keep + 1] = at end
    end
    searchAsks = keep
    local bySpell, seen, list = build().bySpell, {}, {}
    for i = 1, math.min(#spells, LIM.askScan) do
        for name, e in pairs(bySpell[tonumber(spells[i])] or NONE) do
            local low = name:lower()
            if not e.own and not seen[low] then
                seen[low] = true
                local c, m = s.c[name], r[low]
                if type(c) == "table" and type(c.seen) == "number" and d - c.seen > LIM.askOldDays and m and m.online
                    and not (pull and pull.low == low) and t - (askedAt[low] or -math.huge) >= LIM.askGap then
                    list[#list + 1] = { name = name, low = low, seen = c.seen }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.seen ~= b.seen then return a.seen < b.seen end
        return a.low < b.low
    end)
    for _, c in ipairs(list) do
        if #searchAsks >= LIM.askPerMinute or hourCount() >= LIM.pqPerHour then break end
        local src = s.src[c.low]
        local f = src and src.f or "B"
        local nonce = nextNonce()
        if send("PQ", { tostring(ns.CRAFT_PROTO), f, tostring(nonce) }, "WHISPER", c.name) then
            pqTimes[#pqTimes + 1] = t
            searchAsks[#searchAsks + 1] = t
            askedAt[c.low] = t
            asked[nonce] = { low = c.low, f = f, at = t }
            asking[c.low] = t + LIM.pqWait
            stats.searched = stats.searched + 1
            out[#out + 1] = c.name
        end
    end
    if #out > 0 then
        -- the page says "fragt nach" while the answers are awaited, and no more once they are not
        ns.Fire("CRAFTERS_CHANGED")
        C_Timer.After(LIM.pqWait + 1, function() ns.Fire("CRAFTERS_CHANGED") end)
    end
    return out
end

-- Whether a search's request to name waits for its answer (the page's "fragt nach").
function Cr.Asking(name)
    local till = type(name) == "string" and asking[name:lower()]
    return till and now() < till or false
end

---------------------------------------------------------------------------
-- The professions per crafter (the members page): read only, no profession data needed
---------------------------------------------------------------------------
local BITS = {}            -- [hex digit] = the bits it sets
for i = 0, 15 do
    local n, v = 0, i
    while v > 0 do
        n, v = n + v % 2, math.floor(v / 2)
    end
    BITS[("%x"):format(i)] = n
end
local function hexBits(hex)
    local n = 0
    for c in hex:lower():gmatch("%x") do n = n + BITS[c] end
    return n
end

local profsCache          -- { gen, own (the list of Cr.Own it read), day, map }

-- The professions of every crafter Amisia knows, the own characters of this guild and the heard
-- ones: [lower name] = { { skill, rank, max, known = recipes known, age = days since it was read or
-- heard (nil: unknown), own, relay, via (passed on by that member, F-240) } } by skill line. Built again after a change of the crafters or the day.
function Cr.Professions()
    local own, d = Cr.Own(), today()
    local c = profsCache
    if c and c.gen == gen and c.own == own and c.day == d then return c.map end
    local map = {}
    for _, o in ipairs(own) do
        local list = {}
        for _, pr in ipairs(o.profs) do
            local n = 0
            for _, on in pairs(pr.known) do if on == true then n = n + 1 end end
            list[#list + 1] = { skill = pr.skill, rank = pr.rank, max = pr.max, known = n,
                                age = pr.day and math.max(0, d - pr.day) or nil, own = true }
        end
        map[o.name:lower()] = list
    end
    local s = store(false)
    for name, e in pairs(s and s.c or {}) do
        local low = type(name) == "string" and name:lower()
        if low and not map[low] and type(e) == "table" and type(e.p) == "table" then
            local skills = {}
            for skill, p in pairs(e.p) do
                if validProf(skill, p) then skills[#skills + 1] = skill end
            end
            table.sort(skills)
            local list = {}
            for _, skill in ipairs(skills) do
                local p = e.p[skill]
                local n = 0
                if p.l then
                    for _ in p.l:gmatch("%d+") do n = n + 1 end
                else
                    n = hexBits(p.b)
                end
                list[#list + 1] = { skill = skill, rank = p.r, max = p.m or 0, known = n,
                                    age = int(e.seen, 0, 999999) and math.max(0, d - e.seen) or nil, own = false,
                                    relay = e.relay or nil, via = e.relay and e.via or nil }
            end
            if #list > 0 then map[low] = list end
        end
    end
    profsCache = { gen = gen, own = own, day = d, map = map }
    return map
end

-- The recipes one crafter shares for one profession (the Berufe page's member mode, F-182, D-114):
-- a set { [spell] = true }, its size, and when there is none why not: "unknown" (no own character of
-- this guild and no heard crafter by that name), "none" (that profession is not shared), "foreign"
-- (a bitset of another recipe index: its sender is asked for lists next time, as build() does) or
-- "nodata" (a bitset of a profession the own data lacks). Any case of the name; an own character
-- before a heard one. Kept per gen (and own list) like the other indexes.
local knownCache          -- { gen, own, map = { [lower name .. "#" .. skill] = { set, n, why } } }
function Cr.KnownOf(name, skill)
    skill = tonumber(skill)
    if type(name) ~= "string" or name == "" or not skill then return nil, 0, "unknown" end
    local own = Cr.Own()
    if not (knownCache and knownCache.gen == gen and knownCache.own == own) then
        knownCache = { gen = gen, own = own, map = {} }
    end
    local low = name:lower()
    local key = low .. "#" .. skill
    local hit = knownCache.map[key]
    if hit then return hit.set, hit.n, hit.why end
    local set, n, why = nil, 0, "unknown"
    for _, o in ipairs(own) do
        if o.name:lower() == low then
            why = "none"
            for _, pr in ipairs(o.profs) do
                if pr.skill == skill then
                    set, why = {}, nil
                    for spell, on in pairs(pr.known) do
                        if on == true then
                            set[spell] = true
                            n = n + 1
                        end
                    end
                end
            end
            break
        end
    end
    local s = why == "unknown" and store(false)
    for cname, c in pairs(s and s.c or {}) do
        if type(cname) == "string" and cname:lower() == low and type(c) == "table" and type(c.p) == "table" then
            why = "none"
            local p = c.p[skill]
            if validProf(skill, p) then
                local spells = decode(skill, p)
                if not spells then
                    why = "foreign"
                    if type(c.via) == "string" and not c.relay then stale(c.via:lower()) end
                elseif #spells == 0 and p.b and hexBits(p.b) > 0 then
                    why = "nodata"
                else
                    set, why = {}, nil
                    for _, spell in ipairs(spells) do
                        if not set[spell] then
                            set[spell] = true
                            n = n + 1
                        end
                    end
                end
            end
            break
        end
    end
    knownCache.map[key] = { set = set, n = n, why = why }
    return set, n, why
end

---------------------------------------------------------------------------
-- The guild's professions (F-233): per profession who has it, from the recipe exchange and the notes
---------------------------------------------------------------------------
local guildCache          -- { roster list, profs map, top, map }

-- Per skill line { members, amisia, note, top = how many stand on the data's highest rank, best = the
-- highest rank known, oldest = days since the oldest list used }, and whether anyone but the own
-- characters shares recipes (others). A member counts once per character (an own alt too, as in
-- "Hergestellt von"): with the profession from the recipe exchange (Cr.Professions: the own characters
-- of this guild, the heard crafters that stand in the roster, all of them while it cannot be read) or,
-- when that has none, from its public or officer note (Prof.FromNote; such a member counts for members
-- and ranks, never for recipes). Built again when the roster, the crafters or the data change.
function Cr.GuildProfs()
    local list = ns.GuildRoster and ns.GuildRoster() or nil
    local profs = Cr.Professions()
    local Pr = ns.Prof
    local top = Pr and Pr.TopRank and Pr.TopRank() or nil
    local c = guildCache
    if c and c.roster == list and c.profs == profs and c.top == top then return c.map, c.others end
    local map, others = {}, false
    local function at(skill)
        local e = map[skill]
        if not e then
            e = { members = 0, amisia = 0, note = 0, top = 0, best = 0 }
            map[skill] = e
        end
        return e
    end
    local function rank(e, r)
        r = tonumber(r) or 0
        if r > e.best then e.best = r end
        if top and r >= top then e.top = e.top + 1 end
    end
    local r = roster()
    for low, plist in pairs(profs) do
        local own = plist[1] and plist[1].own
        if own or not r or r[low] then
            for _, p in ipairs(plist) do
                local e = at(p.skill)
                e.members, e.amisia = e.members + 1, e.amisia + 1
                rank(e, p.rank)
                if p.age and (not e.oldest or p.age > e.oldest) then e.oldest = p.age end
                if not p.own then others = true end
            end
        end
    end
    for _, m in ipairs(Pr and Pr.FromNote and list or {}) do
        local have = {}
        for _, p in ipairs(profs[m.name:lower()] or {}) do have[p.skill] = true end
        for _, text in ipairs({ m.note or "", m.officerNote or "" }) do
            for _, n in ipairs(Pr.FromNote(text)) do
                if not have[n.skill] then
                    have[n.skill] = true
                    local e = at(n.skill)
                    e.members, e.note = e.members + 1, e.note + 1
                    rank(e, n.rank)
                end
            end
        end
    end
    guildCache = { roster = list, profs = profs, top = top, map = map, others = others }
    return map, others
end

---------------------------------------------------------------------------
-- Settings and command
---------------------------------------------------------------------------
ns.CRAFTERS_SETTINGS = { key = "crafters", label = L["Hersteller der Gilde"], order = 55, group = "prof", pages = { "professions" }, items = {
    { key = "crafters.share", type = "toggle", label = L["Rezepte mit der Gilde teilen"], default = true,
      tip = L["Welche Rezepte deine Charaktere dieser Gilde kennen; nicht aus Instanzen (was dort wartet, geht danach)"] },
    { key = "crafters.tooltip", type = "toggle", label = L["Hersteller im Item-Tooltip"], default = true,
      tip = L["Eine graue Zeile an hergestellten Items: wer aus der Gilde sie herstellen kann."] },
} }
ns.RegisterSettings(ns.CRAFTERS_SETTINGS)

ns.RegisterSlash("hersteller", { en = "crafters", desc = L["Stand des Rezept-Austauschs"], run = function()
    local s = store(false)
    local n = 0
    for _ in pairs(s and s.c or {}) do n = n + 1 end
    local st = ns.CraftersStats()
    ns.msg(L["Hersteller: %d eigene, %d aus der Gilde. Gelernt %d, gesendet %d Bytes. Teilen %s."]:format(#Cr.Own(), n,
        st.crafters, st.bytes, ns.Get("crafters.share") and L["an"] or L["aus"]))
    -- F-240: the question after the login, the answers, what was passed on
    ns.msg(L["Login-Frage %s, %d Antworten gegeben, %d Hersteller weitergegeben bekommen, %d Mal weitergegeben."]:format(
        helloSent and L["gestellt"] or (helloSent == false and L["nicht nötig"] or L["noch nicht"]), st.replies, st.relayed,
        st.relayServed))
end })
end)
