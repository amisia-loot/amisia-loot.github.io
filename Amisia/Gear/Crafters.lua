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
-- spells of the own recipe index; per sender and in all the store stays within byte caps; never in an instance, a battleground, in combat, in the lockdown or while a raid is
-- synced; at the lowest priority of the queue within fixed byte caps.
--
-- Crafter protocol 1. Older clients do not know PV and drop it as an unknown message; they never send
-- PQ, so nothing else reaches them.
--
-- AmisiaDB.crafters = { v = 1, src = { [lower sender] = { d = digest, at = day, f = "L" (lists) } },
--   c = { [name] = { via = sender, self = true (the crafter sent it), seen = day,
--   p = { [skill] = { r = rank, m = max, h = index checksum, b = bitset hex | l = "spell,spell,..." } } } } }
-- AmisiaDB.prof.guild = { [own character] = guild name } (which guild an own character's recipes go to)
local ADDON, ns = ...
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
}
ns.CRAFTERS_LIMITS = LIM

local PART_OVERHEAD = 45
local KEY_PREFIX = "0000-00-01:"

local stats = { bytes = 0, pv = 0, pq = 0, pw = 0, served = 0, blobs = 0, crafters = 0, bad = 0, unasked = 0, refused = 0,
                outsider = 0, kept = 0, mismatch = 0, pulls = 0, busy = 0, other = 0, pruned = 0, missed = 0, foreign = 0,
                capped = 0, unknown = 0 }
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

local function now() return GetTime() end
local function today() return ns.DropsToday and ns.DropsToday() or 0 end
local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end
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
function Cr.Gen() return gen end
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
-- = true } } } } }, the current character first, then by name; at most crafterMax with profMax
-- professions each, only professions read from the window.
function Cr.Own()
    local p, g = profDB(), guildName()
    if not p then return {} end
    local me = ns.UnitFullName and ns.UnitFullName("player") or "?"
    markGuild(p, me)
    if not g then return {} end
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
                known = s.known }
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

function ns.CraftersCanTalk()
    if not AmisiaDB or not ns.Get("crafters.share") then return false end
    if not ns.CommAvailable() or not ns.CommPacking() then return false end
    if type(IsInGuild) ~= "function" or ns.Plain(IsInGuild()) ~= true then return false end
    if type(IsInInstance) == "function" and ns.Plain((IsInInstance())) == true then return false end
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind ~= nil and kind ~= "none" then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return false end
    if ns.CommHeld() then return false end
    if (ns.Active and ns.Active() ~= nil and ns.CommReady()) or battlefield() then return false end
    return true
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
    for i, p in ipairs(peers) do
        if p.low == low then table.remove(peers, i) break end
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
    for i = #peers, 1, -1 do
        local p = peers[i]
        if t - p.at > LIM.peerKeep then
            table.remove(peers, i)
        elseif p.nb <= t then
            ready[#ready + 1] = i
        end
    end
    if #ready == 0 then return end
    if hourCount() >= LIM.pqPerHour then
        debugLine(L["Anfragen der Stunde erreicht."])
        return
    end
    local i = ready[math.random(#ready)]
    local p = table.remove(peers, i)
    local s = store(false)
    local src = s and s.src[p.low]
    if src and src.d == p.d then return end   -- pulled meanwhile
    local f = p.f or (src and src.f) or "B"
    local nonce = nextNonce()
    if not send("PQ", { tostring(ns.CRAFT_PROTO), f, tostring(nonce) }, "WHISPER", p.name) then return end
    pqTimes[#pqTimes + 1] = t
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
        if type(c) == "table" and type(c.via) == "string" and c.via:lower() == low then c.seen = d end
    end
end

ns.CommOn("PV", function(sender, f, chan)
    if chan ~= "GUILD" then return end
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
        local s = store(false)
        local src = s and s.src[low]
        if src and src.d == d then return touch(low) end
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
local function dataBuilt() return rawget(ns, "PROFESSIONS") ~= nil end

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
        if type(c) == "table" and type(c.via) == "string" and c.via:lower() == low then
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
            if not names[name] and type(c) == "table" and type(c.via) == "string" and c.via:lower() == low then s.c[name] = nil end
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
    local mine = pull and pull.nonce == nonce
    local list = checkBlob(tbl, ask)
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
        if not canTalk() then return end
        local low = name:lower()
        if not shareLeft(low) then return sendPW(name, low, LIM.doneWait) end
        -- an asker has one request open at a time: a new one replaces what still waits for it
        for i = #serve, 1, -1 do
            if serve[i].low == low then table.remove(serve, i) end
        end
        if #serve >= LIM.serveMax then return sendPW(name, low, LIM.busyWait) end
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
    local tbl, packed = fit(s.f, maxParts)
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
    serveOne()
    for k, a in pairs(asked) do
        if t - a.at > LIM.askKeep then asked[k] = nil end
    end
end

C_Timer.NewTicker(LIM.tick, function()
    local ok, err = pcall(tick)
    if not ok then report(err) end
end)

ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ADDON or not AmisiaDB then return end
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
    local function add(name, rank, own, spell)
        local e = bySpell[spell]
        if not e then
            e = {}
            bySpell[spell] = e
        end
        local cur = e[name]
        if not cur or rank > cur.rank then e[name] = { rank = rank, own = own } end
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
                        -- the bitset fits other data: that sender is asked for lists next time
                        stale(c.via:lower())
                    else
                        for _, spell in ipairs(spells) do add(name, p.r, false, spell) end
                    end
                end
            end
        end
    end
    index = { gen = gen, bySpell = bySpell, byItem = nil }
    return index
end

-- The crafters of entries { [name] = { rank, own } } as a sorted list { { name, rank, own, online } }:
-- online first (when the roster says so), then the higher rank, then the name; a heard crafter that
-- left the guild (the roster can be read and lacks it) is left out.
local function sorted(entries)
    local r = roster()
    local out = {}
    for name, e in pairs(entries or {}) do
        local m = r and r[name:lower()]
        if e.own or not r or m then
            out[#out + 1] = { name = name, rank = e.rank, own = e.own or false, online = m and m.online or false }
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

-- Whether anyone of the guild knows the recipe (the page's filter).
function Cr.Has(spell)
    local e = build().bySpell[tonumber(spell)]
    return e ~= nil and next(e) ~= nil
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
-- 30 s and while nothing changes. Builds the profession data only out of combat.
local tipCache, tipGen = {}, -1
function Cr.TooltipLine(item)
    item = tonumber(item)
    if not item or not AmisiaDB or not anyone() then return nil end
    if tipGen ~= gen then tipCache, tipGen = {}, gen end
    local hit = tipCache[item]
    if hit and now() - hit.at < 30 then return hit.line or nil end
    if not dataBuilt() and type(InCombatLockdown) == "function" and InCombatLockdown() then return nil end
    local list = Cr.ForItem(item)
    local line = #list > 0 and L["Kann herstellen: %s"]:format(Cr.Text(list, 4)) or false
    tipCache[item] = { at = now(), line = line }
    return line or nil
end

local TIP_GREY = { 0.56, 0.53, 0.64 }
local tipHooked = false
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ADDON or tipHooked then return end
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
-- Settings and command
---------------------------------------------------------------------------
ns.CRAFTERS_SETTINGS = { key = "crafters", label = L["Hersteller der Gilde"], order = 48, items = {
    { key = "crafters.share", type = "toggle", label = L["Rezepte mit der Gilde teilen"], default = true,
      tip = L["Welche Rezepte deine Charaktere dieser Gilde kennen; nur außerhalb von Instanzen und Kämpfen"] },
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
end })
