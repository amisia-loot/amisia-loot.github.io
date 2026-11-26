-- Amisia guild bank sharing (F-238, D-171, spec docs/specs/2026-11-26-gildenbank-abgleich.md): the guild bank
-- log (BankLog.lua, AmisiaDB.bankLog) and the last raid-material count (Record.lua, AmisiaDB.bank) reach every
-- Amisia user of the guild.
--
-- Who sends: only an officer (the officer rank of Trust.lua, as the bank needs' GN), checked by every receiver
-- from its own guild roster (ns.TrustWait "officer"); the client cannot tell which ranks may view another rank's
-- tab (GetGuildBankTabPermissions answers only for the rank GuildControlSetRank chose, the guild control UI's own
-- shared choice; D-171). Who receives: everybody of the guild with bank.share on (and, for the log, bank.log).
--
-- Messages (Comm.lua checks their fields; GUILD and WHISPER only, never raid, party or instance chat; the queue of
-- Comm.lua holds them in the chat lockdown and sends nothing in a battleground):
--   BE <batch> <part> <parts> <base> <flag> <entry>...   log entries of one read, in parts (one message holds as
--        many as fit 250 bytes); base the sender's realm clock (GetServerTime), flag "M" when the sender has more
--        for this asker, else "-"; an entry "<tab>:<kind>:<item>:<count>:<tab1tab2>:<age>:<width>:<name>" with
--        item, count, age (base - hi) and width (hi - lo) in base 36, the kind one letter (KIND_CODE)
--   BQ <ask> <count at> <tab:n:newest:oldest>...   "?" to the guild after the login: who has entries or a count I
--        lack; "L", "C" or "LC" by whisper to the one chosen: send me the log entries, the count
--   BH <entries> <count at>   an officer's whispered answer to "?": how many entries it would send, the time of
--        its count (0 none)
--   BC <at> <part> <parts> <by> <tabs> <filled> <total> <id:count,...>   a material count (ids and counts in
--        base 36), after an own count to the guild, by whisper when pulled
-- Times on the wire are the realm's clock (ns.ServerTime), so two PCs with clocks apart still match; every
-- client keeps its own clock in AmisiaDB (the difference is added on the way out and taken off on the way in).
-- Received entries are a read of the sender: BankLog.lua's one-to-one match, the overlap, the narrowing, the cap
-- and bank.logDays hold for them; a new one keeps the sender as r ("gemeldet von" on the Bank page).
local ADDON, ns = ...
ns.Load(function()
local DELTA_CAP = 120         -- entries one read sends to the guild at most (the newest)
local ANSWER_CAP = 100        -- entries one pulled answer sends at most (the rest on the next round)
local MAX_PARTS = 40          -- parts of one batch
local MAX_COUNT_PARTS = 5
local PER_COUNT_PART = 16     -- materials in one BC part (16 * 12 bytes + the head stay below 250)
local MAX_ROUNDS = 10         -- pulls per session (10 * 100 = the log's cap)
local ASK_AFTER, ASK_SPREAD = 40, 30   -- the question after the login
local OFFER_WAIT = 12         -- seconds the asker collects the offers (BH; more than the receivers' gap of BQ)
local PULL_WAIT = 60          -- seconds a pulled answer may take before the next offer is tried
local NEXT_ROUND = 12         -- seconds between two rounds of one transfer
local PART_WAIT = 30          -- seconds a batch waits for its next part
local OPEN_PER_SENDER, OPEN_ALL = 2, 6
local ANSWERS, ANSWER_WINDOW = 8, 600  -- pulled answers this client gives in ten minutes at most
local COUNT_WAIT = 5          -- seconds after the last count before it goes (the count runs on every tab's answer)
local RECV_SLACK = 120        -- seconds two windows may miss each other when one came from the guild
local FUTURE = 3600           -- a time this far ahead of the own clock drops the message
local MAX_AGE = 400 * 86400   -- an entry's age at most
local MAX_WIDTH = 8 * 86400   -- an entry's window at most (a month-old entry: an hour and six days)
local TTL = 900               -- seconds a message waits in the queue (the lockdown) before it falls

local KIND_CODE = { deposit = "d", withdraw = "w", move = "m", repair = "r", withdrawForTab = "t", buyTab = "b",
                    depositSummary = "s", buyRename = "n", refundRename = "f" }
local CODE_KIND = {}
for k, c in pairs(KIND_CODE) do CODE_KIND[c] = k end
local ITEM_KIND = { deposit = true, withdraw = true, move = true }

local DB
local batchSeq = math.floor((GetTime() or 0) * 10) % 65536
local open = {}               -- sender (lower case) -> { [batch] = { n, parts, got, at, base, more } }
local counts = {}             -- sender (lower case) -> { at, n, parts, got, at2 }
local answered = {}           -- GetTime() of the pulled answers given
local offers                  -- the asker's offers: { [name] = { n, c } } while collecting
local pull = { rounds = 0 }   -- the transfer in progress: name, at (GetTime), tried = { [name] = true }
local countTimer = 0

local function now() return math.floor(time()) end
local function skew() return ns.ServerTime() - now() end
local function me() return ns.UnitFullName("player") or "?" end
local function inGuild() return ns.InGuild() end
local function hasBank()
    return type(_G.GetGuildBankTabInfo) == "function" and type(_G.QueryGuildBankLog) == "function"
end
local function shareOn() return ns.Get("bank.share") ~= false end
local function logOn() return shareOn() and ns.Get("bank.log") ~= false end
local function ready() return DB ~= nil and inGuild() and ns.CommReady and ns.CommReady() and shareOn() end
local function changed() if ns.Refresh then ns.Refresh() end end

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return "0" end
    local out = {}
    while n > 0 do
        local d = n % 36
        table.insert(out, 1, DIGITS:sub(d + 1, d + 1))
        n = (n - d) / 36
    end
    return table.concat(out)
end
local function num36(s, lo, hi)
    if type(s) ~= "string" or s == "" or #s > 8 or s:find("[^0-9a-z]") then return nil end
    local v = tonumber(s, 36)
    if not v or v < lo or v > hi then return nil end
    return v
end
ns.BankShareB36 = b36

function ns.BankShareLoaded(root) DB = root end
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then ns.BankShareLoaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Entries on the wire
---------------------------------------------------------------------------
local function cleanName(n)
    if type(n) ~= "string" then return nil end
    n = n:gsub("[%c|]", "")
    if n == "" or #n > 48 then return nil end
    return n
end

local function encode(e, base)
    local code = KIND_CODE[e.y]
    if not code or type(e.k) ~= "number" or e.k < 0 or e.k > 9 then return nil end
    local name = cleanName(e.n)
    if not name then return nil end
    local ab = ""
    if e.y == "move" and tonumber(e.a) and tonumber(e.b) and e.a >= 1 and e.a <= 9 and e.b >= 1 and e.b <= 9 then
        ab = ("%d%d"):format(e.a, e.b)
    end
    local hi, lo = e.hi + skew(), e.lo + skew()
    return ("%d:%s:%s:%s:%s:%s:%s:%s"):format(e.k, code, b36(e.i or 0), b36(e.c or 0), ab, b36(base - hi), b36(hi - lo), name)
end

-- One entry of a BE back as a row on the own clock, or nil when a field is off.
local function decode(text, base)
    local k, code, i, c, ab, age, width, name = text:match("^(%d):(%l):([0-9a-z]+):([0-9a-z]+):(%d*):([0-9a-z]+):([0-9a-z]+):(.+)$")
    k = tonumber(k)
    local y = code and CODE_KIND[code]
    if not k or not y then return nil end
    i, c = num36(i, 0, 9999999), num36(c, 0, 2147483647)
    age, width = num36(age, 0, MAX_AGE), num36(width, 0, MAX_WIDTH)
    name = cleanName(name)
    if not i or not c or not age or not width or not name then return nil end
    if k == 0 then
        if i ~= 0 or y == "move" then return nil end
    elseif not ITEM_KIND[y] or i < 1 or c < 1 then
        return nil
    end
    local e = { k = k, y = y, n = name, i = i, c = c }
    if y == "move" then
        if #ab ~= 2 then return nil end
        e.a, e.b = tonumber(ab:sub(1, 1)), tonumber(ab:sub(2, 2))
        if e.a < 1 or e.b < 1 then return nil end
    elseif ab ~= "" then
        return nil
    end
    e.hi = base - age - skew()
    e.lo = e.hi - width
    return e
end

local function newestFirst(a, b)
    if a.hi ~= b.hi then return a.hi > b.hi end
    return (a.s or 0) > (b.s or 0)
end

-- Sends entries (newest first, at most cap) as one batch; more: the sender has more for this asker.
local function sendBatch(list, chan, target, more)
    local base = ns.ServerTime()
    local fields = {}
    for _, e in ipairs(list) do
        local text = encode(e, base)
        if text then fields[#fields + 1] = text end
    end
    if #fields == 0 then return false end
    batchSeq = batchSeq % 65535 + 1
    local batch = ("%04x"):format(batchSeq)
    -- pack: the head "1BE\t<batch>\t<part>\t<parts>\t<base>\t<flag>" takes at most 4 + 5 + 3 + 3 + 11 + 2 bytes
    local parts, cur, size = {}, {}, 0
    local room = ns.COMM_MAX_TEXT - 30
    for _, f in ipairs(fields) do
        if size + #f + 1 > room and #cur > 0 then
            parts[#parts + 1] = cur
            cur, size = {}, 0
        end
        cur[#cur + 1] = f
        size = size + #f + 1
    end
    if #cur > 0 then parts[#parts + 1] = cur end
    if #parts > MAX_PARTS then
        for p = #parts, MAX_PARTS + 1, -1 do parts[p] = nil end
        more = true
    end
    for p, chunk in ipairs(parts) do
        local msg = { batch, tostring(p), tostring(#parts), tostring(base), more and "M" or "-" }
        for _, f in ipairs(chunk) do msg[#msg + 1] = f end
        local ok = ns.CommSend("BE", msg, chan, target,
            { key = "BE:" .. batch .. ":" .. p, ttl = TTL, low = chan == "WHISPER" or nil })
        if not ok then return false end
    end
    return true
end

-- After an own read (BankLog.lua): the entries that were new go to the guild.
function ns.BankShareRead(list)
    if not ready() or not logOn() or not ns.SelfIsOfficer(true) or type(list) ~= "table" or #list == 0 then return false end
    local out = {}
    for _, e in ipairs(list) do if not e.r then out[#out + 1] = e end end
    table.sort(out, newestFirst)
    -- the newest DELTA_CAP; the rest reaches the others when they ask after their next login
    for i = #out, DELTA_CAP + 1, -1 do out[i] = nil end
    return sendBatch(out, "GUILD", nil, false)
end

---------------------------------------------------------------------------
-- Receiving entries
---------------------------------------------------------------------------
local function openCount()
    local n = 0
    for _, sets in pairs(open) do for _ in pairs(sets) do n = n + 1 end end
    return n
end

local function sweep(t)
    for key, sets in pairs(open) do
        for id, set in pairs(sets) do
            if t - set.at > PART_WAIT then sets[id] = nil end
        end
        if next(sets) == nil then open[key] = nil end
    end
end

local askAgain

local function finishBatch(name, set)
    local rows = {}
    for p = 1, set.n do
        for _, e in ipairs(set.parts[p]) do rows[#rows + 1] = e end
    end
    local added = ns.MergeBankLogRead(rows, RECV_SLACK, name)
    DB.bankLog.got = { by = name, at = now(), n = #added }
    changed()
    -- a pulled transfer: the next round while the sender has more and this one brought something
    if pull.name and ns.SameName(pull.name, name) then
        pull.at = nil
        if set.more and #added > 0 and pull.rounds < MAX_ROUNDS then
            C_Timer.After(NEXT_ROUND, function() askAgain(name) end)
        else
            pull.name = nil
        end
    end
end

ns.CommOn("BE", function(sender, f, chan)
    if not DB or not logOn() or (chan ~= "GUILD" and chan ~= "WHISPER") then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local batch, part, parts, base = f[1], tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
    if base > ns.ServerTime() + FUTURE then return end
    local rows = {}
    for i = 6, #f do
        local e = decode(f[i], base)
        if not e then return end
        rows[#rows + 1] = e
    end
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not logOn() then return end
        local t = GetTime()
        sweep(t)
        local key = name:lower()
        open[key] = open[key] or {}
        local set = open[key][batch]
        if not set or set.n ~= parts then
            local mine = 0
            for _ in pairs(open[key]) do mine = mine + 1 end
            if mine >= OPEN_PER_SENDER or openCount() >= OPEN_ALL then return end
            set = { n = parts, parts = {}, got = 0 }
            open[key][batch] = set
        end
        set.at = t
        if f[5] == "M" then set.more = true end
        if set.parts[part] then return end
        set.parts[part] = rows
        set.got = set.got + 1
        if set.got < set.n then return end
        open[key][batch] = nil
        finishBatch(name, set)
    end)
end)

---------------------------------------------------------------------------
-- The count
---------------------------------------------------------------------------
local function sendCount(chan, target)
    local bank = DB and DB.bank
    if type(bank) ~= "table" or type(bank.counts) ~= "table" or not tonumber(bank.at) then return false end
    local ids = {}
    for id, c in pairs(bank.counts) do
        if tonumber(id) and tonumber(c) and id >= 1 and id <= 9999999 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    if #ids == 0 or #ids > MAX_COUNT_PARTS * PER_COUNT_PART then return false end
    local parts = math.ceil(#ids / PER_COUNT_PART)
    local at = math.floor(bank.at) + skew()
    local by = ns.ExportName(bank.by or me()):gsub("[%c|,:%s]", "")
    if by == "" or #by > 60 then by = "?" end
    for p = 1, parts do
        local chunk = {}
        for i = (p - 1) * PER_COUNT_PART + 1, math.min(#ids, p * PER_COUNT_PART) do
            local id = ids[i]
            chunk[#chunk + 1] = b36(id) .. ":" .. b36(math.max(0, math.min(99999999, math.floor(bank.counts[id]))))
        end
        local function small(v) return tostring(math.max(0, math.min(99, math.floor(tonumber(v) or 0)))) end
        local ok = ns.CommSend("BC", { tostring(at), tostring(p), tostring(parts), by, small(bank.tabs), small(bank.filled),
            small(bank.total or bank.tabs), table.concat(chunk, ",") }, chan, target,
            { key = "BC:" .. chan .. ":" .. tostring(target or "") .. ":" .. p, ttl = TTL, low = chan == "WHISPER" or nil })
        if not ok then return false end
    end
    return true
end

-- After an own count (Record.lua): the count goes to the guild once the counting is over.
function ns.BankShareCounted()
    countTimer = countTimer + 1
    local mine = countTimer
    C_Timer.After(COUNT_WAIT, function()
        if mine ~= countTimer then return end
        if ready() and ns.SelfIsOfficer(true) and DB.bank and not DB.bank.via then sendCount("GUILD") end
    end)
end

ns.CommOn("BC", function(sender, f, chan)
    if not DB or not shareOn() or (chan ~= "GUILD" and chan ~= "WHISPER") then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local at, part, parts = tonumber(f[1]), tonumber(f[2]), tonumber(f[3])
    if at > ns.ServerTime() + FUTURE then return end
    local got = {}
    for e in (f[8] .. ","):gmatch("([^,]*),") do
        local id, c = e:match("^([0-9a-z]+):([0-9a-z]+)$")
        id, c = num36(id, 1, 9999999), num36(c, 0, 99999999)
        if not id or not c then return end
        got[id] = c
    end
    local local_at = at - skew()
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not shareOn() then return end
        local bank = DB.bank
        if type(bank) == "table" and (tonumber(bank.at) or 0) >= local_at then return end
        local key, t = name:lower(), GetTime()
        local set = counts[key]
        if not set or set.at ~= at or set.n ~= parts or t - set.t > PART_WAIT then
            set = { at = at, n = parts, parts = {}, got = 0 }
            counts[key] = set
        end
        set.t = t
        if set.parts[part] then return end
        set.parts[part] = got
        set.got = set.got + 1
        if set.got < set.n then return end
        counts[key] = nil
        local all = {}
        for p = 1, set.n do for id, c in pairs(set.parts[p]) do all[id] = c end end
        DB.bank = { at = local_at, by = (f[4]:gsub("_", " ")), via = name, guild = (GetGuildInfo and ns.Plain(GetGuildInfo("player"))) or "",
                    counts = all, tabs = tonumber(f[5]), filled = tonumber(f[6]), total = tonumber(f[7]) }
        changed()
    end)
end)

---------------------------------------------------------------------------
-- What a client holds, what another lacks
---------------------------------------------------------------------------
-- Per tab: { n, new, old } of the own log (local clock).
local function summary()
    local out = {}
    for _, e in ipairs(ns.BankLog().list) do
        local s = out[e.k]
        if not s then
            s = { n = 0, new = e.hi, old = e.hi }
            out[e.k] = s
        end
        s.n = s.n + 1
        if e.hi > s.new then s.new = e.hi end
        if e.hi < s.old then s.old = e.hi end
    end
    return out
end

local function summaryFields()
    local out, d = {}, skew()
    local tabs, s = {}, summary()
    for k in pairs(s) do tabs[#tabs + 1] = k end
    table.sort(tabs)
    for _, k in ipairs(tabs) do
        if k >= 0 and k <= 9 then out[#out + 1] = ("%d:%d:%s:%s"):format(k, math.min(s[k].n, 9999), b36(s[k].new + d), b36(s[k].old + d)) end
    end
    return out
end

-- The own entries another client lacks by its summary: per tab the entries newer than its newest, the
-- ones between its oldest and newest when there are more of them here than it has, then the ones older
-- than its oldest; each part newest first. Returns the list (all of them).
local function lacking(theirs)
    local newer, middle, older = {}, {}, {}
    local mine = {}
    for _, e in ipairs(ns.BankLog().list) do
        local s = theirs[e.k]
        if not s or e.hi > s.new + RECV_SLACK then
            newer[#newer + 1] = e
        elseif e.hi < s.old - RECV_SLACK then
            older[#older + 1] = e
        else
            mine[e.k] = mine[e.k] or {}
            table.insert(mine[e.k], e)
        end
    end
    for k, list in pairs(mine) do
        if #list > theirs[k].n then
            for _, e in ipairs(list) do middle[#middle + 1] = e end
        end
    end
    table.sort(newer, newestFirst)
    table.sort(middle, newestFirst)
    table.sort(older, newestFirst)
    local out = newer
    for _, e in ipairs(middle) do out[#out + 1] = e end
    for _, e in ipairs(older) do out[#out + 1] = e end
    return out
end

-- The summary fields of a BQ back on the own clock; nil when one is off.
local function readSummary(f)
    local out, d = {}, skew()
    for i = 3, #f do
        local k, n, new, old = f[i]:match("^(%d):(%d+):([0-9a-z]+):([0-9a-z]+)$")
        k, n = tonumber(k), tonumber(n)
        new, old = num36(new, 0, 4294967295), num36(old, 0, 4294967295)
        if not k or not n or not new or not old or old > new or out[k] then return nil end
        out[k] = { n = n, new = new - d, old = old - d }
    end
    return out
end

local function ownCountAt()
    local bank = DB and DB.bank
    return type(bank) == "table" and type(bank.counts) == "table" and tonumber(bank.at) and (math.floor(bank.at) + skew()) or 0
end

---------------------------------------------------------------------------
-- The question after the login and the pulls
---------------------------------------------------------------------------
local function sendAsk(ask, chan, target)
    local fields = { ask, tostring(shareOn() and ownCountAt() or 0) }
    if ask:find("[?L]") and logOn() then
        for _, s in ipairs(summaryFields()) do fields[#fields + 1] = s end
    end
    return ns.CommSend("BQ", fields, chan, target, { key = "BQ:" .. chan .. ":" .. tostring(target or ""), ttl = 120, low = true })
end

local function pickOffer(field, tried)
    local best, bestV
    for name, o in pairs(offers or {}) do
        local v = o[field]
        if v > 0 and not (tried and tried[name:lower()]) and (not best or v > bestV or (v == bestV and name < best)) then
            best, bestV = name, v
        end
    end
    return best, bestV
end

-- Pulls the log from name (a whisper "L"); after PULL_WAIT without an answer the next offer is tried.
local function pullFrom(name)
    pull.name, pull.at = name, GetTime()
    pull.tried = pull.tried or {}
    pull.tried[name:lower()] = true
    pull.rounds = pull.rounds + 1
    sendAsk(pull.count and "LC" or "L", "WHISPER", name)
    pull.count = nil
    local at = pull.at
    C_Timer.After(PULL_WAIT, function()
        if pull.at ~= at or not pull.name then return end
        pull.name, pull.at = nil, nil
        local nextName = pickOffer("n", pull.tried)
        if nextName and pull.rounds < MAX_ROUNDS then pullFrom(nextName) end
    end)
end

askAgain = function(name)
    if not ready() or not logOn() or pull.rounds >= MAX_ROUNDS then
        pull.name = nil
        return
    end
    pullFrom(name)
end

local function decide()
    if not offers or not ready() then return end
    local logName = logOn() and pickOffer("n") or nil
    local countName, countAt = pickOffer("c")
    if countName and countAt <= ownCountAt() then countName = nil end
    -- one whisper to one officer (a second within 10 s would fall to the receiver's gap)
    if countName and logName and countName == logName then
        pull.count = true
        return pullFrom(logName)
    end
    if countName then sendAsk("C", "WHISPER", countName) end
    if logName then pullFrom(logName) end
end

-- "Who has entries or a count I lack?" to the guild (after the login; also from the page, once in 60 s).
local askedAt
function ns.AskBankShare()
    if not ready() or not hasBank() then return false end
    if askedAt and GetTime() - askedAt < 60 then return false end
    askedAt = GetTime()
    offers = {}
    pull.rounds, pull.tried = 0, {}
    C_Timer.After(OFFER_WAIT, decide)
    return sendAsk("?", "GUILD") and true or false
end

ns.CommOn("BQ", function(sender, f, chan)
    if not DB or not ready() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local ask, theirCount = f[1], tonumber(f[2]) or 0
    local theirs = readSummary(f)
    if not theirs then return end
    if ask == "?" then
        if chan ~= "GUILD" then return end
    elseif chan ~= "WHISPER" then
        return
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ready() or not ns.SelfIsOfficer(true) then return end
        local entries = logOn() and lacking(theirs) or {}
        local mineAt = ownCountAt()
        if ask == "?" then
            local n, c = math.min(#entries, 9999), mineAt > theirCount and mineAt or 0
            if n == 0 and c == 0 then return end
            C_Timer.After(0.5 + ns.Spread(4, me()), function()
                ns.CommSend("BH", { tostring(n), tostring(c) }, "WHISPER", sender, { key = "BH:" .. name:lower(), ttl = 30, low = true })
            end)
            return
        end
        -- a pull: within the budget of answers
        local t, keep = GetTime(), {}
        for _, at in ipairs(answered) do if t - at < ANSWER_WINDOW then keep[#keep + 1] = at end end
        answered = keep
        if #answered >= ANSWERS then return end
        local any = false
        if ask:find("L", 1, true) and #entries > 0 then
            local more = #entries > ANSWER_CAP
            for i = #entries, ANSWER_CAP + 1, -1 do entries[i] = nil end
            any = sendBatch(entries, "WHISPER", sender, more) or any
        end
        if ask:find("C", 1, true) and mineAt > theirCount then any = sendCount("WHISPER", sender) or any end
        if any then answered[#answered + 1] = t end
    end)
end)

ns.CommOn("BH", function(sender, f, chan)
    if not offers or chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local n, c = tonumber(f[1]), tonumber(f[2])
    ns.TrustWait(name, "officer", function(ok)
        if ok and offers then offers[name] = { n = n, c = c } end
    end)
end)

local asked = false
ns.OnEvent("PLAYER_LOGIN", function()
    if asked then return end
    asked = true
    C_Timer.After(ASK_AFTER + ns.Spread(ASK_SPREAD, me()), function() ns.AskBankShare() end)
end)

-- The Bank page: the last entries heard from the guild ({ by, at, n } or nil), and whether sharing is on.
function ns.BankShareState()
    local log = ns.BankLog()
    return log.got, shareOn()
end
end)
