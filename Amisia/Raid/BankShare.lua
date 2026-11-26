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
--   BQ <ask> <count at> [<keep from> <entries> <oldest> <first day> <days> <counts>]   "?" to the guild after the
--        login: who has entries or a count I lack ("?C": only a count, the asker keeps no log); "L", "C" or "LC" by
--        whisper to the one chosen: send me the log entries, the count. With "?", "L" and "LC" the asker's horizon:
--        keep from (its bank.logDays on the realm clock: it drops anything older), entries (how many it keeps; at
--        most ns.BANK_LOG_CAP), oldest (its oldest entry's end, 0 none), and its entries per day of the realm clock
--        from first day back over days (two base-36 digits a day, newest first, zeros at the end left out, "-" none)
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
-- pulls per transfer: 10 * 100 is the log's cap, and a round sends the whole of the day the round before cut
-- (the asker's part of it again), so two rounds more
local MAX_ROUNDS = 12
local ASK_AFTER, ASK_SPREAD = 40, 30   -- the question after the login
local ASK_GAP = 60            -- seconds between two questions of this client (the login's, the page's link)
local ASK_TTL = 120           -- seconds a question or a pull waits in the own queue before it falls
local OFFER_WAIT = 12         -- seconds the asker collects the offers (BH), counted from the moment the "?" went
                              -- out (more than the receivers' gap of BQ, so the first pull never falls to it)
local PULL_WAIT = 60          -- seconds a pulled answer may take, from the moment the pull went, before the next offer
local NEXT_ROUND = 12         -- seconds between two rounds of one transfer
local PART_WAIT = 30          -- seconds a batch waits for its next part
local TRUST_WAIT = 60         -- seconds more a batch waits while its sender cannot be checked yet (Trust.lua WAIT_FOR)
local OPEN_PER_SENDER, OPEN_ALL = 2, 6
local ANSWER_WINDOW = 600     -- the answers this client gives as an officer, per ten minutes:
local PER_ASKER = MAX_ROUNDS + 1  -- to one asker at most one whole transfer (its rounds and the count)
local ANSWERS_ALL = 40        -- to everybody together (three whole transfers)
local MAX_DAYS = 120          -- days of an asker's summary at most (the message's room sets fewer)
local KEEP_MARGIN = 300       -- seconds an entry must lie inside the asker's horizon (it moves on while it waits)
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
-- raw sender (lower case) -> { [batch] = { n, parts, got, at, more, chan, trust (nil: being checked, true, false), name } }
local open = {}
local counts = {}             -- raw sender (lower case) -> { at, n, parts, got, t, trust, name, f }
local answered = {}           -- GetTime() of the pulled answers given (all askers)
local served = {}             -- asker (lower case) -> { at = GetTime() of the first answer, n = answers } in the window
local offers                  -- the asker's offers: { [name] = { n, c } } while collecting
local pull = { rounds = 0 }   -- the transfer in progress: name, at (a token while the answer is awaited), tried = { [name] = true }
local countTimer = 0
local askToken = 0

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

-- Runs fn when the own character is an officer. When the roster is not built yet (just logged in, or the
-- lockdown before the first build), it waits for it (ns.TrustWait on the own name) instead of dropping.
local function asOfficer(fn)
    if ns.SelfIsOfficer(true) then return fn() end
    if ns.GuildRoster() ~= nil then return false end
    ns.TrustWait(me(), "officer", function(ok) if ok and ready() then fn() end end)
    return true
end

-- The name to check a sender of shared bank data by: its roster or group name, else, while the roster
-- cannot be read (the lockdown, not loaded yet), the raw sender without the own realm (ns.TrustWait waits
-- for the roster with it); nil for a sender the readable roster does not know.
local function senderName(sender)
    local name = ns.TrustName(sender)
    if name then return name end
    if ns.IsVerifiedMember(sender) ~= nil then return nil end
    return ns.StripOwnRealm(sender) or sender
end

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
-- A name on the wire: no control characters or bars, 1-48 bytes (BankLog.lua cuts read names at 48 bytes
-- on a character's boundary).
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

-- After an own read (BankLog.lua): the entries that were new go to the guild (once the roster tells the
-- own rank, when it is not built yet).
function ns.BankShareRead(list)
    if not ready() or not logOn() or type(list) ~= "table" or #list == 0 then return false end
    local out = {}
    for _, e in ipairs(list) do if not e.r then out[#out + 1] = e end end
    table.sort(out, newestFirst)
    -- the newest DELTA_CAP; the rest reaches the others when they ask after their next login
    for i = #out, DELTA_CAP + 1, -1 do out[i] = nil end
    if #out == 0 then return false end
    return asOfficer(function()
        if not logOn() then return false end
        return sendBatch(out, "GUILD", nil, false)
    end) and true or false
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
            -- a batch whose sender is still being checked waits as long as the check may take
            if t - set.at > PART_WAIT + (set.trust == nil and TRUST_WAIT or 0) then sets[id] = nil end
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
    -- a pulled transfer (only a whispered batch answers it; the same officer's guild broadcast does not): the
    -- next round while the sender has more and this one brought something new that is kept
    if set.chan == "WHISPER" and pull.name and ns.SameName(pull.name, name) then
        pull.at = nil
        if set.more and #added > 0 and pull.rounds < MAX_ROUNDS then
            C_Timer.After(NEXT_ROUND, function() askAgain(name) end)
        else
            pull.name = nil
        end
    end
end

-- A batch is complete and its sender a checked officer: merged once.
local function tryFinish(key, batch, set)
    if set.trust ~= true or set.got < set.n or not open[key] or open[key][batch] ~= set then return end
    open[key][batch] = nil
    if next(open[key]) == nil then open[key] = nil end
    if logOn() then finishBatch(set.name, set) end
end

ns.CommOn("BE", function(sender, f, chan)
    if not DB or not logOn() or (chan ~= "GUILD" and chan ~= "WHISPER") then return end
    local name = senderName(sender)
    if not name then return end
    local batch, part, parts, base = f[1], tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
    if base > ns.ServerTime() + FUTURE then return end
    local rows = {}
    for i = 6, #f do
        local e = decode(f[i], base)
        if not e then return end
        rows[#rows + 1] = e
    end
    local t = GetTime()
    sweep(t)
    -- the parts of a batch are held under the raw sender while it is checked once, with its first part (the
    -- roster may be unreadable for a while: the lockdown, not loaded yet; Trust.lua's 20 waiting checks stay free)
    local key = sender:lower()
    open[key] = open[key] or {}
    local set = open[key][batch]
    if set and (set.n ~= parts or set.chan ~= chan) then return end
    local fresh = false
    if not set then
        local mine = 0
        for _ in pairs(open[key]) do mine = mine + 1 end
        if mine >= OPEN_PER_SENDER or openCount() >= OPEN_ALL then
            if next(open[key]) == nil then open[key] = nil end
            return
        end
        set = { n = parts, parts = {}, got = 0, chan = chan, name = name }
        open[key][batch] = set
        fresh = true
    end
    if set.trust == false then return end
    set.at = t
    if f[5] == "M" then set.more = true end
    if not set.parts[part] then
        set.parts[part] = rows
        set.got = set.got + 1
    end
    if fresh then
        ns.TrustWait(name, "officer", function(ok)
            if not open[key] or open[key][batch] ~= set then return end
            set.trust = ok and true or false
            if not ok then return end
            set.name = ns.TrustName(sender) or name
            tryFinish(key, batch, set)
        end)
    else
        tryFinish(key, batch, set)
    end
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
        if ready() and DB.bank and not DB.bank.via then
            asOfficer(function() if DB.bank and not DB.bank.via then sendCount("GUILD") end end)
        end
    end)
end

-- A complete count of a checked officer: taken when it is newer than the own.
local function finishCount(key, set)
    if set.trust ~= true or set.got < set.n or counts[key] ~= set then return end
    counts[key] = nil
    if not shareOn() then return end
    local bank = DB.bank
    if type(bank) == "table" and (tonumber(bank.at) or 0) >= set.localAt then return end
    local all = {}
    for p = 1, set.n do for id, c in pairs(set.parts[p]) do all[id] = c end end
    local f = set.f
    DB.bank = { at = set.localAt, by = (f[4]:gsub("_", " ")), via = set.name, guild = (GetGuildInfo and ns.Plain(GetGuildInfo("player"))) or "",
                counts = all, tabs = tonumber(f[5]), filled = tonumber(f[6]), total = tonumber(f[7]) }
    changed()
end

ns.CommOn("BC", function(sender, f, chan)
    if not DB or not shareOn() or (chan ~= "GUILD" and chan ~= "WHISPER") then return end
    local name = senderName(sender)
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
    local localAt = at - skew()
    local bank = DB.bank
    if type(bank) == "table" and (tonumber(bank.at) or 0) >= localAt then return end
    -- one check of the sender per count (its first part), as for the entries
    local key, t = sender:lower(), GetTime()
    local set = counts[key]
    if set and t - set.t > PART_WAIT + (set.trust == nil and TRUST_WAIT or 0) then set = nil end
    local fresh = false
    if not set or set.at ~= at or set.n ~= parts then
        set = { at = at, localAt = localAt, n = parts, parts = {}, got = 0, name = name, f = f }
        counts[key] = set
        fresh = true
    end
    if set.trust == false then return end
    set.t = t
    if not set.parts[part] then
        set.parts[part] = got
        set.got = set.got + 1
    end
    if fresh then
        ns.TrustWait(name, "officer", function(ok)
            if counts[key] ~= set then return end
            set.trust = ok and true or false
            if not ok then return end
            set.name = ns.TrustName(sender) or name
            finishCount(key, set)
        end)
    else
        finishCount(key, set)
    end
end)

---------------------------------------------------------------------------
-- What a client holds, what another lacks
---------------------------------------------------------------------------
local DAY = 86400
local function dayOf(t) return math.floor(t / DAY) end
local function pair36(n)
    n = math.max(0, math.min(1295, n))
    local hi, lo = math.floor(n / 36), n % 36
    return DIGITS:sub(hi + 1, hi + 1) .. DIGITS:sub(lo + 1, lo + 1)
end

-- The own horizon and the own entries per day as the fields of a BQ after ask and count time (realm clock):
-- keep from, entries, oldest, first day, days, counts. As many days as the message has room for (at most
-- MAX_DAYS, back to the own horizon); fixed: the size of the head.
local function summaryFields(fixed)
    local d = skew()
    local list = ns.BankLog().list
    local keep = math.max(0, math.floor(ns.BankLogKeepFrom() + d))
    local per, oldest = {}, nil
    for _, e in ipairs(list) do
        local hi = e.hi + d
        local day = dayOf(hi)
        per[day] = (per[day] or 0) + 1
        if not oldest or hi < oldest then oldest = hi end
    end
    local first = dayOf(ns.ServerTime())
    local out = { tostring(keep), tostring(math.min(#list, 9999)), tostring(math.max(0, math.floor(oldest or 0))), tostring(first) }
    -- the room: "1BQ", a tab before each of the 8 fields, the fields; 3 bytes for days
    local used = 3 + 8 + fixed + 3
    for _, v in ipairs(out) do used = used + #v end
    local days = math.max(1, math.min(first - dayOf(keep) + 1, MAX_DAYS, math.floor((ns.COMM_MAX_TEXT - used) / 2)))
    local cells, last = {}, 0
    for i = 1, days do
        local n = per[first - i + 1] or 0
        cells[i] = pair36(n)
        if n > 0 then last = i end
    end
    out[#out + 1] = tostring(days)
    out[#out + 1] = last > 0 and table.concat(cells, "", 1, last) or "-"
    return out
end

-- The asker's summary of a BQ (realm clock): { keep, n, oldest, first, days, counts = { [day] = n } }; nil
-- when the BQ carries none or a field is off.
local function readSummary(f)
    if #f < 8 then return nil end
    local out = { keep = tonumber(f[3]), n = tonumber(f[4]), oldest = tonumber(f[5]), first = tonumber(f[6]),
                  days = tonumber(f[7]), counts = {} }
    if not (out.keep and out.n and out.oldest and out.first and out.days) then return nil end
    if f[8] ~= "-" then
        for i = 1, #f[8] / 2 do
            local n = num36(f[8]:sub(2 * i - 1, 2 * i), 0, 1295)
            if not n then return nil end
            out.counts[out.first - i + 1] = n
        end
    end
    return out
end

-- The own entries another client lacks by its summary (realm days): the entries of each day where this
-- client has more than the asker and also more over that day and its two neighbours (an entry whose window
-- lies on the other side of midnight on one of the two counts there); the entries of days newer than its
-- summary; the ones older than its summary when they are older than its oldest entry. Never what the asker
-- would drop at once: older than its horizon, or beyond its newest ns.BANK_LOG_CAP. Days go newest first;
-- a day goes whole while the asker has room (its entries on newer days and that day, and what the days
-- before are expected to add: this client's count less the asker's), none once it has no room left.
local function lacking(theirs)
    local d = skew()
    local first, last = theirs.first, theirs.first - theirs.days + 1
    local byDay, newer, older = {}, {}, {}
    for _, e in ipairs(ns.BankLog().list) do
        local hi = e.hi + d
        if hi >= theirs.keep + KEEP_MARGIN then
            local day = dayOf(hi)
            if day > first then
                newer[#newer + 1] = e
            elseif day >= last then
                byDay[day] = byDay[day] or {}
                table.insert(byDay[day], e)
            elseif theirs.oldest == 0 or hi < theirs.oldest - RECV_SLACK then
                older[#older + 1] = e
            end
        end
    end
    local function their(day) return (day >= last and day <= first) and (theirs.counts[day] or 0) or 0 end
    local function mine(day) return byDay[day] and #byDay[day] or 0 end
    local days = {}
    for day, list in pairs(byDay) do
        if #list > their(day) and mine(day - 1) + #list + mine(day + 1) > their(day - 1) + their(day) + their(day + 1) then
            days[#days + 1] = day
        end
    end
    table.sort(days, function(a, b) return a > b end)
    local cap = ns.BANK_LOG_CAP or 1000
    table.sort(newer, newestFirst)
    local out = {}
    for i = 1, math.min(#newer, cap) do out[i] = newer[i] end
    local added = #out
    local held, at = 0, first + 1
    for _, day in ipairs(days) do
        while at > day do
            at = at - 1
            held = held + their(at)
        end
        local room = cap - held - added
        if room <= 0 then break end
        local list = byDay[day]
        table.sort(list, newestFirst)
        for _, e in ipairs(list) do out[#out + 1] = e end
        added = added + math.min(room, math.max(1, #list - their(day)))
    end
    table.sort(older, newestFirst)
    for i = 1, math.min(#older, math.max(0, cap - math.max(theirs.n, held) - added)) do out[#out + 1] = older[i] end
    return out
end

local function ownCountAt()
    local bank = DB and DB.bank
    return type(bank) == "table" and type(bank.counts) == "table" and tonumber(bank.at) and (math.floor(bank.at) + skew()) or 0
end

---------------------------------------------------------------------------
-- The question after the login and the pulls
---------------------------------------------------------------------------
-- A question or a pull. With the log asked for ("?", "L", "LC") the own horizon and per-day counts go with it;
-- "?" of a client keeping no log (bank.log off) is "?C", a question for the count alone. sent: called once
-- the message really went (it may wait in the own queue behind other messages).
local function sendAsk(ask, chan, target, sent)
    if ask == "?" and not logOn() then ask = "?C" end
    local fields = { ask, tostring(shareOn() and ownCountAt() or 0) }
    if ask == "?" or ask:find("L", 1, true) then
        local fixed = 0
        for _, v in ipairs(fields) do fixed = fixed + #v end
        for _, v in ipairs(summaryFields(fixed)) do fields[#fields + 1] = v end
    end
    return ns.CommSend("BQ", fields, chan, target, { key = "BQ:" .. chan .. ":" .. tostring(target or ""), ttl = ASK_TTL, low = true,
        sent = sent })
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

-- Pulls the log from name (a whisper "L"); PULL_WAIT after the pull went without an answer (or when it never
-- went) the next offer is tried.
local function pullFrom(name)
    local token = {}
    pull.name, pull.at = name, token
    pull.tried = pull.tried or {}
    pull.tried[name:lower()] = true
    pull.rounds = pull.rounds + 1
    local function timeout()
        if pull.at ~= token or not pull.name then return end
        pull.name, pull.at = nil, nil
        local nextName = pickOffer("n", pull.tried)
        if nextName and pull.rounds < MAX_ROUNDS then pullFrom(nextName) end
    end
    sendAsk(pull.count and "LC" or "L", "WHISPER", name, function() C_Timer.After(PULL_WAIT, timeout) end)
    pull.count = nil
    C_Timer.After(ASK_TTL + PULL_WAIT, timeout)
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
    -- one whisper to one officer (a second within 10 s would fall to the receiver's gap of a pull)
    if countName and logName and countName == logName then
        pull.count = true
        return pullFrom(logName)
    end
    if countName then sendAsk("C", "WHISPER", countName) end
    if logName then pullFrom(logName) end
end

-- "Who has entries or a count I lack?" to the guild (after the login; also from the Bank page's link "Jetzt
-- abgleichen", once in ASK_GAP). The offers are collected for OFFER_WAIT from the moment the question went out.
-- Returns true, or false and the reason: "off" (no guild, no bank, sharing off) or "wait" with the seconds left.
local askedAt
function ns.AskBankShare()
    if not ready() or not hasBank() then return false, "off" end
    if askedAt and GetTime() - askedAt < ASK_GAP then return false, "wait", math.ceil(ASK_GAP - (GetTime() - askedAt)) end
    askedAt = GetTime()
    askToken = askToken + 1
    local mine = askToken
    offers = {}
    pull.rounds, pull.tried, pull.name, pull.at = 0, {}, nil, nil
    local ok = sendAsk("?", "GUILD", nil, function()
        C_Timer.After(OFFER_WAIT, function() if mine == askToken then decide() end end)
    end)
    return ok and true or false, not ok and "off" or nil
end

-- The Bank page's link: whether a question can go now (in a guild with a bank and sharing on), and the
-- seconds until the next one may.
function ns.BankShareCanAsk()
    if not ready() or not hasBank() then return false, 0 end
    local left = askedAt and math.max(0, math.ceil(ASK_GAP - (GetTime() - askedAt))) or 0
    return true, left
end

-- The budget of answers (an officer): at most PER_ASKER to one asker in ANSWER_WINDOW (one whole transfer, its
-- rounds and the count, counted from its first answer) and ANSWERS_ALL to everybody together.
local function canAnswer(key)
    local t, keep = GetTime(), {}
    for _, at in ipairs(answered) do if t - at < ANSWER_WINDOW then keep[#keep + 1] = at end end
    answered = keep
    for k, s in pairs(served) do if t - s.at >= ANSWER_WINDOW then served[k] = nil end end
    return #answered < ANSWERS_ALL and not (served[key] and served[key].n >= PER_ASKER)
end
local function tookAnswer(key)
    local t = GetTime()
    served[key] = served[key] or { at = t, n = 0 }
    served[key].n = served[key].n + 1
    answered[#answered + 1] = t
end

ns.CommOn("BQ", function(sender, f, chan)
    if not DB or not ready() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local ask, theirCount = f[1], tonumber(f[2]) or 0
    local question = ask:sub(1, 1) == "?"
    if question then
        if chan ~= "GUILD" then return end
    elseif chan ~= "WHISPER" then
        return
    end
    local theirs
    if ask == "?" or ask:find("L", 1, true) then
        theirs = readSummary(f)
        if not theirs then return end
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ready() or not ns.SelfIsOfficer(true) then return end
        local key = name:lower()
        -- an asker whose budget is used up gets neither an offer nor an answer
        if not canAnswer(key) then return end
        local entries = (theirs and logOn()) and lacking(theirs) or {}
        local mineAt = ownCountAt()
        if question then
            local n, c = math.min(#entries, 9999), mineAt > theirCount and mineAt or 0
            if n == 0 and c == 0 then return end
            C_Timer.After(0.5 + ns.Spread(4, me()), function()
                ns.CommSend("BH", { tostring(n), tostring(c) }, "WHISPER", sender, { key = "BH:" .. key, ttl = 30, low = true })
            end)
            return
        end
        local any = false
        if ask:find("L", 1, true) and #entries > 0 then
            local more = #entries > ANSWER_CAP
            for i = #entries, ANSWER_CAP + 1, -1 do entries[i] = nil end
            any = sendBatch(entries, "WHISPER", sender, more) or any
        end
        if ask:find("C", 1, true) and mineAt > theirCount then any = sendCount("WHISPER", sender) or any end
        if any then tookAnswer(key) end
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
