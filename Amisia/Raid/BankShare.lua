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
--   BQ <ask> <count at> [<keep from> <entries> <oldest> <first day> <days> <counts> [<cursor>]]   "?" to the guild after the
--        login: who has entries or a count I lack ("?C": only a count, the asker keeps no log); "L", "C" or "LC" by
--        whisper to the one chosen: send me the log entries, the count. With "?", "L" and "LC" the asker's horizon:
--        keep from (its bank.logDays on the realm clock: it drops anything older), entries (how many it keeps; at
--        most ns.BANK_LOG_CAP), oldest (its oldest entry's end, 0 none), and its entries per day of the realm clock
--        from first day back over days (two base-36 digits a day, newest first, zeros at the end left out, "-" none);
--        a pull ("L", "LC") repeats the summary of its first round and adds the cursor: "<realm time>:<n>", the
--        oldest end received from this officer in this transfer and how many entries of that end, or "-" (the first
--        round); the officer sends only what lies after it, so no round sends an entry twice
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
local ANSWER_PARTS = 14       -- parts of one pulled answer at most: 14 * 250 bytes, at most four rounds a minute
                              -- (PULL_PACE), stay clearly below Comm's 20480 bytes a minute from one sender at the
                              -- receiver (room for the officer's own guild broadcast)
local MAX_PARTS = 40          -- parts of one batch
local MAX_COUNT_PARTS = 5
local PER_COUNT_PART = 16     -- materials in one BC part (16 * 12 bytes + the head stay below 250)
-- pulls per transfer: a pull carries a cursor (the oldest entry received in this transfer), so no round sends an
-- entry twice; 1000 entries (the log's cap) with names of about 15 bytes fill 15 answers of 14 parts, three to spare
-- (18 * 14 parts stay within one asker's budget, PARTS_PER_ASKER)
local MAX_ROUNDS = 18          -- rounds from one officer
local MAX_TOTAL = 2 * MAX_ROUNDS  -- rounds of one question over all officers it moves on to
local DRY_ROUNDS = 2          -- rounds in a row that add nothing end a transfer (the asker had them all), not
                              -- counted while the cursor walks through a day the asker holds at least as many of
local BARREN_FOR = 6 * 3600   -- seconds an officer whose last transfer added nothing is not pulled again while
                              -- its offer stays the same (windows of old entries filed under other days)
local ASK_AFTER, ASK_SPREAD = 40, 30   -- the question after the login
local ASK_GAP = 60            -- seconds between two questions of this client (the login's, the page's link)
local ASK_TTL = 120           -- seconds a question or a pull waits in the own queue before it falls
local OFFER_WAIT = 12         -- seconds the asker collects the offers (BH), counted from the moment the "?" went
                              -- out (more than the receivers' gap of BQ, so the first pull never falls to it)
local PULL_WAIT = 60          -- seconds a pulled answer may take, from the moment the pull went, before the next offer
local NEXT_ROUND = 12         -- seconds between an answer and the next round of one transfer
local PULL_PACE = 15          -- seconds between two pulls of one transfer at least (four rounds a minute)
local PART_WAIT = 30          -- seconds a batch waits for its next part
local TRUST_WAIT = 60         -- seconds more a batch waits while its sender cannot be checked yet (Trust.lua WAIT_FOR)
local OPEN_PER_SENDER, OPEN_ALL = 2, 6  -- open batches (and held counts); one of OPEN_ALL kept for the officer pulled
local REJECT_FOR = 30         -- seconds a sender that is no officer is not heard (its batches hold no slot)
local MISSED_ASK, MISSED_SPREAD = 5, 30  -- seconds after the lockdown (and up to 30 more, spread by name) before a
                              -- question for what fell while it lasted (a whole raid leaves it at once)
local ANSWER_WINDOW = 600     -- the parts this client sends as an officer's answers, per ten minutes:
local PARTS_PER_ASKER = 260   -- to one asker at most one whole transfer (MAX_ROUNDS answers and the count)
local PARTS_ALL = 780         -- to everybody together (three whole transfers)
local OFFER_VALID = 300       -- seconds after an offer (BH) or the last answer in which a pull of that asker is answered
local OFFER_MARGIN = 60       -- an asker moving on to an offer older than OFFER_VALID less this asks the guild afresh
local MAX_DAYS = 120          -- days of an asker's summary at most (the message's room sets fewer)
local KEEP_MARGIN = 300       -- seconds an entry must lie inside the asker's horizon (it moves on while it waits)
local COUNT_WAIT = 5          -- seconds after the last count before it goes (the count runs on every tab's answer)
local RECV_SLACK = 120        -- seconds two windows may miss each other when one came from the guild
local FUTURE = 3600           -- a time this far ahead of the own clock drops the message
local MAX_AGE = 400 * 86400   -- an entry's age at most
local MAX_WIDTH = 8 * 86400   -- an entry's window at most (a month-old entry: an hour and six days)
local TTL = 900               -- seconds a message waits in the queue (the lockdown) before it falls
local DAY = 86400
local function dayOf(t) return math.floor(t / DAY) end

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
local answered = {}           -- { t = GetTime(), n = parts } of the pulled answers given (all askers)
local served = {}             -- asker (lower case) -> { at = GetTime() of the first answer, n = parts } in the window
local offered = {}            -- asker (lower case) -> GetTime() of the offer (BH) or the last answer to it
-- asker (lower case) -> { list, pos, low, lowN }: what it lacked at the first pull after the offer (frozen copies,
-- newest first), how many of them went, and the cursor the asker holds after them; the later rounds go on by
-- position, so a log that changes meanwhile (an own read narrowing an entry) skips nothing. Dropped with a new
-- question, the last answer, or once the offer is no longer valid.
local snaps = {}
local checking = {}           -- raw sender (lower case) -> true while its one ns.TrustWait runs
local rejected = {}           -- raw sender (lower case) -> GetTime() until which its BE and BC are dropped
local missed = false          -- a guild batch or count fell while its sender could not be checked (the lockdown)
local offers                  -- the asker's offers: { [name] = { n, c } } while collecting
-- the transfer in progress: name (the officer pulled), countName (the one asked for the count, its answer awaited
-- until countUntil), at (a token while
-- the answer is awaited), tried = { [name] = true }, ask (the question's token), summary (the fields of the first
-- pull from name, the same in every round), low/lowN (the cursor: the oldest realm time received from name and how
-- many entries of that time), dry (rounds in a row that added nothing), added (entries this transfer added),
-- theirs (summary read back), perDay (entries received from name per realm day), rounds (pulls of name), total
-- (pulls of the question), lastAt (GetTime() of the last pull), manual (the Bank page's link: barren is ignored)
local pull = { rounds = 0, total = 0 }
local barren = {}             -- officer (lower case) -> { t = GetTime(), n = its offer } when a transfer added nothing
local countTimer = 0
local askToken = 0
local askedAt                 -- GetTime() of the last question to the guild

local function now() return math.floor(time()) end
-- The difference of the realm clock to the own, held steady (GetServerTime and time() tick apart, so the plain
-- difference wobbles by a second): the realm times of the own entries are the same in every round of a transfer,
-- which the cursor of a pull compares exactly.
local skewAt
local function skew()
    local d = ns.ServerTime() - now()
    if not skewAt or math.abs(d - skewAt) > 2 then skewAt = d end
    return skewAt
end
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
    e.w = base - age          -- the end on the sender's realm clock, exactly as sent (the cursor of a pull)
    e.hi = e.w - skew()
    e.lo = e.hi - width
    return e
end

-- Newest first, and always in the same order (a pull's cursor skips the first entries of one time): by the end,
-- the read, the start, then the fields.
local function newestFirst(a, b)
    if a.hi ~= b.hi then return a.hi > b.hi end
    if (a.s or 0) ~= (b.s or 0) then return (a.s or 0) > (b.s or 0) end
    if a.lo ~= b.lo then return a.lo > b.lo end
    if a.k ~= b.k then return a.k < b.k end
    if a.y ~= b.y then return a.y < b.y end
    if a.n ~= b.n then return a.n < b.n end
    if (a.i or 0) ~= (b.i or 0) then return (a.i or 0) < (b.i or 0) end
    if (a.c or 0) ~= (b.c or 0) then return (a.c or 0) < (b.c or 0) end
    if (a.a or 0) ~= (b.a or 0) then return (a.a or 0) < (b.a or 0) end
    return (a.b or 0) < (b.b or 0)
end

-- Sends entries (newest first) as one batch in at most maxParts parts (MAX_PARTS); more: the sender has more for
-- this asker. Returns whether it went, the parts sent and how many entries of list it covers (the ones that went
-- and the ones before them that cannot go on the wire; 0 when it did not go).
local function sendBatch(list, chan, target, more, maxParts)
    local base = ns.ServerTime()
    local fields, at = {}, {}
    for i, e in ipairs(list) do
        local text = encode(e, base)
        if text then fields[#fields + 1] = text; at[#fields] = i end
    end
    if #fields == 0 then return false, 0, 0 end
    batchSeq = batchSeq % 65535 + 1
    local batch = ("%04x"):format(batchSeq)
    -- pack: the head "1BE\t<batch>\t<part>\t<parts>\t<base>\t<flag>" takes at most 4 + 5 + 3 + 3 + 11 + 2 bytes
    local parts, cur, size, last = {}, {}, 0, {}
    local room = ns.COMM_MAX_TEXT - 30
    for n, f in ipairs(fields) do
        if size + #f + 1 > room and #cur > 0 then
            parts[#parts + 1] = cur
            cur, size = {}, 0
        end
        cur[#cur + 1] = f
        last[#parts + 1] = at[n]
        size = size + #f + 1
    end
    if #cur > 0 then parts[#parts + 1] = cur end
    local limit = math.min(MAX_PARTS, maxParts or MAX_PARTS)
    if limit < 1 then return false, 0, 0 end
    local covers = #list
    if #parts > limit then
        for p = #parts, limit + 1, -1 do parts[p] = nil end
        more = true
        covers = last[limit]
    end
    for p, chunk in ipairs(parts) do
        local msg = { batch, tostring(p), tostring(#parts), tostring(base), more and "M" or "-" }
        for _, f in ipairs(chunk) do msg[#msg + 1] = f end
        local ok = ns.CommSend("BE", msg, chan, target,
            { key = "BE:" .. batch .. ":" .. p, ttl = TTL, low = chan == "WHISPER" or nil })
        if not ok then return false, p - 1, 0 end
    end
    return true, #parts, covers
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
        return (sendBatch(out, "GUILD", nil, false))
    end) and true or false
end

---------------------------------------------------------------------------
-- Receiving entries and counts
---------------------------------------------------------------------------
local function openCount()
    local n = 0
    for _, sets in pairs(open) do for _ in pairs(sets) do n = n + 1 end end
    return n
end

local function countsHeld()
    local n = 0
    for _ in pairs(counts) do n = n + 1 end
    return n
end

-- Whether name is the officer whose answer this client awaits now (the log or the count): only its whisper is held
-- while the roster cannot be read, and one open slot stays free for it.
local function fromPulled(name)
    if pull.at and pull.name and ns.SameName(pull.name, name) then return true end
    return pull.countName ~= nil and (pull.countUntil or 0) > GetTime() and ns.SameName(pull.countName, name) or false
end

-- A guild batch or count fell undecided (its sender could not be checked in time: a lockdown longer than
-- Trust.lua's wait): one question to the guild once the lockdown is over brings it (ns.AskBankShare, its gap).
local function noteMissed()
    if missed then return end
    missed = true
    if not ns.ChatLocked() then
        C_Timer.After(MISSED_ASK + ns.Spread(MISSED_SPREAD, me()), function() if missed and not ns.ChatLocked() then ns.BankShareAskMissed() end end)
    end
end

function ns.BankShareAskMissed()
    if not missed then return false end
    local ok, why, left = ns.AskBankShare()
    if ok then
        missed = false
    elseif why == "wait" then
        C_Timer.After((left or ASK_GAP) + 1, function() if missed and not ns.ChatLocked() then ns.BankShareAskMissed() end end)
    else
        missed = false
    end
    return ok
end

ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    -- read the state after the dispatch (it is not final during it)
    C_Timer.After(0, function()
        if missed and inGuild() and not ns.ChatLocked() then
            C_Timer.After(MISSED_ASK + ns.Spread(MISSED_SPREAD, me()), function() if missed and not ns.ChatLocked() then ns.BankShareAskMissed() end end)
        end
    end)
end)

local function sweep(t)
    for key, sets in pairs(open) do
        for id, set in pairs(sets) do
            -- a batch whose sender is still being checked waits as long as the check may take
            if t - set.at > PART_WAIT + (set.trust == nil and TRUST_WAIT or 0) then
                sets[id] = nil
                if set.trust == nil and set.chan == "GUILD" then noteMissed() end
            end
        end
        if next(sets) == nil then open[key] = nil end
    end
    for key, set in pairs(counts) do
        if t - set.t > PART_WAIT + (set.trust == nil and TRUST_WAIT or 0) then
            counts[key] = nil
            if set.trust == nil and set.chan == "GUILD" then noteMissed() end
        end
    end
    for key, untilT in pairs(rejected) do if untilT <= t then rejected[key] = nil end end
end

local askAgain

-- The cursor of a pulled transfer after an answer: the oldest realm time received from the officer and how many
-- entries of that time; whether it moved (an answer that does not move it would come again).
local function advance(rows)
    local low, lowN = pull.low, pull.lowN or 0
    for _, e in ipairs(rows) do
        if not low or e.w < low then
            low, lowN = e.w, 1
        elseif e.w == low then
            lowN = lowN + 1
        end
    end
    local moved = low ~= pull.low or lowN ~= pull.lowN
    pull.low, pull.lowN = low, lowN
    pull.perDay = pull.perDay or {}
    for _, e in ipairs(rows) do
        local day = dayOf(e.w)
        pull.perDay[day] = (pull.perDay[day] or 0) + 1
    end
    return moved
end

-- Whether the cursor still lies in a day the asker's own summary (of the first round) holds at least as many
-- entries of as came from the officer for it so far: the officer walks through entries the asker had already,
-- the ones it lacks of that day may still come (a round adding nothing there is no dry round).
local function inKnownDay()
    if not pull.low or not pull.theirs then return false end
    local day = dayOf(pull.low)
    local theirs = pull.theirs.counts[day] or 0
    return theirs > 0 and theirs >= ((pull.perDay or {})[day] or 0)
end

local function finishBatch(name, set)
    local rows = {}
    for p = 1, set.n do
        for _, e in ipairs(set.parts[p]) do rows[#rows + 1] = e end
    end
    local added = ns.MergeBankLogRead(rows, RECV_SLACK, name)
    DB.bankLog.got = { by = name, at = now(), n = #added }
    changed()
    -- a pulled transfer (only a whispered batch answers it; the same officer's guild broadcast does not): the
    -- next round while the sender has more and the cursor moved, until two rounds in a row brought nothing kept
    if set.chan == "WHISPER" and pull.name and ns.SameName(pull.name, name) then
        pull.at = nil
        local moved = advance(rows)
        pull.added = (pull.added or 0) + #added
        if #added > 0 then
            pull.dry = 0
        elseif not (set.more and inKnownDay()) then
            pull.dry = (pull.dry or 0) + 1
        end
        if set.more and moved and pull.dry < DRY_ROUNDS and pull.rounds < MAX_ROUNDS and pull.total < MAX_TOTAL then
            local token = pull.ask
            -- at most four rounds a minute (the receiver's bytes a minute from one sender)
            local wait = math.max(NEXT_ROUND, PULL_PACE - (GetTime() - (pull.lastAt or 0)))
            C_Timer.After(wait, function() if pull.ask == token then askAgain(name) end end)
        else
            -- barren only when the officer had nothing more (not a transfer cut short by its rounds or the dry rule)
            if pull.added == 0 and not set.more then
                local o = offers and offers[pull.name]
                barren[pull.name:lower()] = { t = GetTime(), n = o and o.n or -1 }
            end
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

---------------------------------------------------------------------------
-- The count
---------------------------------------------------------------------------
-- Sends the own count in at most maxParts parts (none when it needs more). Returns whether it went and the parts.
local function sendCount(chan, target, maxParts)
    local bank = DB and DB.bank
    if type(bank) ~= "table" or type(bank.counts) ~= "table" or not tonumber(bank.at) then return false, 0 end
    local ids = {}
    for id, c in pairs(bank.counts) do
        if tonumber(id) and tonumber(c) and id >= 1 and id <= 9999999 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    if #ids == 0 or #ids > MAX_COUNT_PARTS * PER_COUNT_PART then return false, 0 end
    local parts = math.ceil(#ids / PER_COUNT_PART)
    if maxParts and parts > maxParts then return false, 0 end
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
        if not ok then return false, p - 1 end
    end
    return true, parts
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

---------------------------------------------------------------------------
-- Checking a sender: once at a time per raw sender, for all it holds open
---------------------------------------------------------------------------
-- The verdict on a raw sender for everything it holds open (batches and its count). An officer's are finished;
-- a sender that is no officer loses them at once (they hold no slot) and is not heard for REJECT_FOR; a check
-- that could not decide (the roster stayed unreadable past Trust.lua's wait, its waiting list was full) drops
-- them too, and a guild one is asked for again once the lockdown is over.
local function settle(key, sender, name, ok)
    checking[key] = nil
    if ok then
        local trusted = ns.TrustName(sender) or name
        local sets = {}
        for batch, set in pairs(open[key] or {}) do
            if set.trust == nil then
                set.trust, set.name = true, trusted
                sets[#sets + 1] = { batch, set }
            end
        end
        for _, s in ipairs(sets) do tryFinish(key, s[1], s[2]) end
        local c = counts[key]
        if c and c.trust == nil then
            c.trust, c.name = true, trusted
            finishCount(key, c)
        end
        return
    end
    local undecided = ns.IsVerifiedOfficer(name) == nil
    local guild = counts[key] and counts[key].chan == "GUILD"
    for _, set in pairs(open[key] or {}) do if set.chan == "GUILD" then guild = true end end
    open[key], counts[key] = nil, nil
    if undecided then
        if guild then noteMissed() end
    else
        rejected[key] = GetTime() + REJECT_FOR
    end
end

-- Starts the one check of a raw sender (ns.TrustWait "officer"; Trust.lua's 20 waiting checks are shared with
-- the raid sync, the roll window and the bank needs, so a sender never holds more than one of them).
local function check(key, sender, name)
    if checking[key] then return end
    checking[key] = true
    ns.TrustWait(name, "officer", function(ok) settle(key, sender, name, ok) end)
end

-- Whether a message of sender may be held: not a sender rejected a moment ago; while the roster cannot be read
-- (the lockdown, not loaded yet) only the guild channel (the server lets only members send there) and the
-- whisper of the officer this client pulls.
local function hearable(key, name, chan, t)
    if rejected[key] and rejected[key] > t then return false end
    if chan == "WHISPER" and ns.IsVerifiedMember(name) == nil and not fromPulled(name) then return false end
    return true
end

ns.CommOn("BE", function(sender, f, chan)
    if not DB or not logOn() or (chan ~= "GUILD" and chan ~= "WHISPER") then return end
    local name = senderName(sender)
    if not name then return end
    local key, t = sender:lower(), GetTime()
    sweep(t)
    if not hearable(key, name, chan, t) then return end
    local batch, part, parts, base = f[1], tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
    if base > ns.ServerTime() + FUTURE then return end
    local rows = {}
    for i = 6, #f do
        local e = decode(f[i], base)
        if not e then return end
        rows[#rows + 1] = e
    end
    -- the parts of a batch are held under the raw sender while it is checked (the roster may be unreadable for a
    -- while: the lockdown, not loaded yet)
    open[key] = open[key] or {}
    local set = open[key][batch]
    if set and (set.n ~= parts or set.chan ~= chan) then return end
    if not set then
        local mine = 0
        for _ in pairs(open[key]) do mine = mine + 1 end
        local all = (chan == "WHISPER" and fromPulled(name)) and OPEN_ALL or OPEN_ALL - 1
        if mine >= OPEN_PER_SENDER or openCount() >= all then
            if next(open[key]) == nil then open[key] = nil end
            return
        end
        set = { n = parts, parts = {}, got = 0, chan = chan, name = name }
        open[key][batch] = set
    end
    set.at = t
    if f[5] == "M" then set.more = true end
    if not set.parts[part] then
        set.parts[part] = rows
        set.got = set.got + 1
    end
    if set.trust == nil then check(key, sender, name) else tryFinish(key, batch, set) end
end)

ns.CommOn("BC", function(sender, f, chan)
    if not DB or not shareOn() or (chan ~= "GUILD" and chan ~= "WHISPER") then return end
    local name = senderName(sender)
    if not name then return end
    local key, t = sender:lower(), GetTime()
    sweep(t)
    if not hearable(key, name, chan, t) then return end
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
    -- one count held per sender (a newer one replaces it), at most OPEN_ALL senders' (one kept for the officer
    -- pulled); the sender's one check covers it
    local set = counts[key]
    if not set or set.at ~= at or set.n ~= parts or set.chan ~= chan then
        if not set then
            local all = (chan == "WHISPER" and fromPulled(name)) and OPEN_ALL or OPEN_ALL - 1
            if countsHeld() >= all then return end
        end
        set = { at = at, localAt = localAt, n = parts, parts = {}, got = 0, name = name, f = f, chan = chan,
                trust = set and set.trust or nil }
        counts[key] = set
    end
    set.t = t
    if not set.parts[part] then
        set.parts[part] = got
        set.got = set.got + 1
    end
    if set.trust == nil then check(key, sender, name) else finishCount(key, set) end
end)

---------------------------------------------------------------------------
-- What a client holds, what another lacks
---------------------------------------------------------------------------
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

-- The cursor of a pull ("<realm time>:<entries of that time>" or "-"): nil, or the time and the count.
local function readCursor(v)
    if type(v) ~= "string" or v == "-" then return nil end
    local hi, n = v:match("^(%d+):(%d+)$")
    return tonumber(hi), tonumber(n)
end

-- The end of an entry as the wire carries it: base - floor(base - hi) with base a whole second (encode).
local function wireEnd(e) return math.ceil(e.hi + skew()) end

-- Where the entries of a list (newest first, newestFirst) after a pull's cursor start: the first older than its
-- time, or of that time the one after the first n (the asker has them from an earlier round of this transfer).
local function cursorStart(list, low, lowN)
    if not low then return 1 end
    local same = 0
    for i, e in ipairs(list) do
        local hi = wireEnd(e)
        if hi < low then return i end
        if hi == low then
            same = same + 1
            if same > lowN then return i end
        end
    end
    return #list + 1
end

-- The entries of list from index i on (at most n).
local function slice(list, i, n)
    local out = {}
    for j = i, math.min(#list, i + n - 1) do out[#out + 1] = list[j] end
    return out
end

-- A frozen copy of the entries an asker lacks (the snapshot of its transfer): an own read changing an entry
-- meanwhile changes neither the order nor the ends the cursor counts.
local function freeze(list)
    local out = {}
    for i, e in ipairs(list) do
        local c = {}
        for k, v in pairs(e) do c[k] = v end
        out[i] = c
    end
    return out
end

---------------------------------------------------------------------------
-- The question after the login and the pulls
---------------------------------------------------------------------------
-- A question or a pull. With the log asked for ("?", "L", "LC") the own horizon and per-day counts go with it
-- (a pull: summary, the fields its first round sent, and the cursor); "?" of a client keeping no log (bank.log
-- off) is "?C", a question for the count alone. sent: called once the message really went (it may wait in the
-- own queue behind other messages). Returns whether it was queued and the summary fields sent.
local function sendAsk(ask, chan, target, sent, summary, cursor)
    if ask == "?" and not logOn() then ask = "?C" end
    local fields = { ask, tostring(shareOn() and ownCountAt() or 0) }
    local isPull = ask:sub(1, 1) ~= "?"
    if ask == "?" or ask:find("L", 1, true) then
        -- a pull keeps room for a count time of 10 digits and the cursor (the summary stays for every round)
        summary = summary or summaryFields(isPull and (#ask + 10 + 17) or (#fields[1] + #fields[2]))
        for _, v in ipairs(summary) do fields[#fields + 1] = v end
        if isPull then fields[#fields + 1] = cursor or "-" end
    end
    local ok = ns.CommSend("BQ", fields, chan, target, { key = "BQ:" .. chan .. ":" .. tostring(target or ""), ttl = ASK_TTL, low = true,
        sent = sent })
    return ok, summary
end

-- An officer whose last transfer added nothing and whose offer is the same since: not pulled again soon.
local function isBarren(name, o)
    local b = barren[name:lower()]
    if b and GetTime() - b.t >= BARREN_FOR then barren[name:lower()] = nil; b = nil end
    return b ~= nil and o ~= nil and b.n == o.n
end

local function pickOffer(field, tried)
    local best, bestV
    for name, o in pairs(offers or {}) do
        local v = o[field]
        if v > 0 and not (tried and tried[name:lower()]) and not (field == "n" and not pull.manual and isBarren(name, o))
            and (not best or v > bestV or (v == bestV and name < best)) then
            best, bestV = name, v
        end
    end
    return best, bestV
end

local decide

-- The question again while moving on to an officer whose offer is about to run out (OFFER_VALID at the officer):
-- the offers are collected afresh, the officers tried and the rounds of the question stay.
local function renew()
    local token = pull.ask
    local left = askedAt and ASK_GAP - (GetTime() - askedAt) or 0
    if left > 0 then
        C_Timer.After(left + 1, function() if pull.ask == token and not pull.name then renew() end end)
        return
    end
    if not ready() then return end
    askedAt = GetTime()
    askToken = askToken + 1
    local mine = askToken
    offers = {}
    pull.ask, pull.name, pull.at = mine, nil, nil
    sendAsk("?", "GUILD", nil, function()
        C_Timer.After(OFFER_WAIT, function() if mine == askToken then decide() end end)
    end)
end

-- Pulls the log from name (a whisper "L"); PULL_WAIT after the pull went without an answer (or when it never
-- went) the next offer is tried. A new officer starts a new cursor and summary, and its own MAX_ROUNDS.
local function pullFrom(name)
    local token = {}
    if not (pull.name and ns.SameName(pull.name, name)) then
        pull.summary, pull.theirs, pull.perDay, pull.low, pull.lowN, pull.dry, pull.added = nil, nil, nil, nil, 0, 0, 0
        pull.rounds = 0
    end
    pull.name, pull.at = name, token
    pull.tried = pull.tried or {}
    pull.tried[name:lower()] = true
    pull.rounds = pull.rounds + 1
    pull.total = (pull.total or 0) + 1
    pull.lastAt = GetTime()
    local function timeout()
        if pull.at ~= token or not pull.name then return end
        pull.name, pull.at = nil, nil
        local nextName = pickOffer("n", pull.tried)
        if not nextName or pull.total >= MAX_TOTAL then return end
        if GetTime() - (offers[nextName].t or 0) > OFFER_VALID - OFFER_MARGIN then
            renew()
        else
            pullFrom(nextName)
        end
    end
    local cursor = pull.low and ("%d:%d"):format(pull.low, pull.lowN or 0) or nil
    local _, summary = sendAsk(pull.count and "LC" or "L", "WHISPER", name, function() C_Timer.After(PULL_WAIT, timeout) end,
        pull.summary, cursor)
    if summary and not pull.theirs then
        local f = { "L", "0" }
        for _, v in ipairs(summary) do f[#f + 1] = v end
        pull.theirs = readSummary(f)
    end
    pull.summary = summary
    pull.count = nil
    C_Timer.After(ASK_TTL + PULL_WAIT, timeout)
end

askAgain = function(name)
    if not ready() or not logOn() or pull.rounds >= MAX_ROUNDS or pull.total >= MAX_TOTAL then
        pull.name = nil
        return
    end
    pullFrom(name)
end

decide = function()
    if not offers or not ready() then return end
    local logName = logOn() and pickOffer("n", pull.tried) or nil
    local countName, countAt = pickOffer("c")
    if countName and countAt <= ownCountAt() then countName = nil end
    pull.countName, pull.countUntil = countName, countName and GetTime() + ASK_TTL + PULL_WAIT or nil
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
-- manual: the link (an officer barren from an earlier transfer is pulled anyway).
-- Returns true, or false and the reason: "off" (no guild, no bank, sharing off) or "wait" with the seconds left.
function ns.AskBankShare(manual)
    if not ready() or not hasBank() then return false, "off" end
    if askedAt and GetTime() - askedAt < ASK_GAP then return false, "wait", math.ceil(ASK_GAP - (GetTime() - askedAt)) end
    askedAt = GetTime()
    askToken = askToken + 1
    local mine = askToken
    offers = {}
    -- a new question ends the transfer before (its next round and its timeouts check these tokens)
    pull = { rounds = 0, total = 0, tried = {}, ask = mine, manual = manual and true or nil }
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

-- The budget of an officer's answers, in parts sent: at most PARTS_PER_ASKER to one asker in ANSWER_WINDOW (one
-- whole transfer, its rounds and the count, counted from its first answer) and PARTS_ALL to everybody together.
-- Returns the parts this asker may still get.
local function partsLeft(key)
    local t, keep, all = GetTime(), {}, 0
    for _, a in ipairs(answered) do
        if t - a.t < ANSWER_WINDOW then
            keep[#keep + 1] = a
            all = all + a.n
        end
    end
    answered = keep
    for k, s in pairs(served) do if t - s.at >= ANSWER_WINDOW then served[k] = nil end end
    -- offers no longer valid, and the snapshots of their transfers
    for k, at in pairs(offered) do if t - at >= OFFER_VALID then offered[k] = nil end end
    for k in pairs(snaps) do if not offered[k] then snaps[k] = nil end end
    return math.max(0, math.min(PARTS_ALL - all, PARTS_PER_ASKER - (served[key] and served[key].n or 0)))
end
local function tookParts(key, n)
    if n <= 0 then return end
    local t = GetTime()
    served[key] = served[key] or { at = t, n = 0 }
    served[key].n = served[key].n + n
    answered[#answered + 1] = { t = t, n = n }
end

ns.CommOn("BQ", function(sender, f, chan)
    -- only an officer offers and answers (no check of the asker otherwise: Trust.lua's waiting list stays free)
    if not DB or not ready() or not ns.SelfIsOfficer(true) then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local ask, theirCount = f[1], tonumber(f[2]) or 0
    local question = ask:sub(1, 1) == "?"
    if question then
        if chan ~= "GUILD" then return end
    elseif chan ~= "WHISPER" then
        return
    end
    local key = name:lower()
    -- a new question: a new offer, a new transfer
    if question then snaps[key] = nil end
    -- a pull is answered only after an own offer to this asker (its question came first)
    if not question and not (offered[key] and GetTime() - offered[key] < OFFER_VALID) then return end
    local theirs
    if ask == "?" or ask:find("L", 1, true) then
        theirs = readSummary(f)
        if not theirs then return end
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ready() or not ns.SelfIsOfficer(true) then return end
        -- an asker whose budget is used up gets neither an offer nor an answer
        local left = partsLeft(key)
        if left <= 0 then return end
        local function lacks() return (theirs and logOn()) and lacking(theirs) or {} end
        local mineAt = ownCountAt()
        if question then
            local entries = lacks()
            local n, c = math.min(#entries, 9999), mineAt > theirCount and mineAt or 0
            if n == 0 and c == 0 then return end
            C_Timer.After(0.5 + ns.Spread(4, me()), function()
                -- tiny and awaited within OFFER_WAIT: not behind the low parts of other answers
                if ns.CommSend("BH", { tostring(n), tostring(c) }, "WHISPER", sender, { key = "BH:" .. key, ttl = 30 }) then
                    offered[key] = GetTime()
                end
            end)
            return
        end
        local used = 0
        if ask:find("C", 1, true) and mineAt > theirCount then
            local _, n = sendCount("WHISPER", sender, left)
            used = used + n
        end
        if ask:find("L", 1, true) and logOn() then
            local low, lowN = readCursor(f[9])
            local snap, list, start = snaps[key]
            if not low then
                -- the first round: what the asker lacks now, frozen for the rounds after it
                snap = { list = freeze(lacks()), pos = 0 }
                snaps[key] = snap
                list, start = snap.list, 1
            elseif snap then
                -- by position; the cursor checks it (an answer the asker did not get: from its cursor in the snapshot)
                list = snap.list
                start = (snap.low == low and snap.lowN == lowN) and snap.pos + 1 or cursorStart(list, low, lowN)
            else
                -- no snapshot (a reload since the first round): the log as it is now, after the cursor
                list = lacks()
                start = cursorStart(list, low, lowN)
            end
            local rest = #list - start + 1
            if rest > 0 then
                local went, n, covers = sendBatch(slice(list, start, ANSWER_CAP), "WHISPER", sender, rest > ANSWER_CAP,
                    math.min(ANSWER_PARTS, left - used))
                used = used + n
                if snap and went then
                    -- the cursor the asker holds after this answer (the entries that went on the wire)
                    snap.low, snap.lowN = low, lowN or 0
                    for j = start, start + covers - 1 do
                        local e = list[j]
                        if encode(e, 0) then
                            local w = wireEnd(e)
                            if w == snap.low then snap.lowN = snap.lowN + 1 else snap.low, snap.lowN = w, 1 end
                        end
                    end
                    snap.pos = start + covers - 1
                    if snap.pos >= #list then snaps[key] = nil end
                end
            elseif snap then
                snaps[key] = nil
            end
        end
        if used > 0 then
            tookParts(key, used)
            offered[key] = GetTime()
        end
    end)
end)

ns.CommOn("BH", function(sender, f, chan)
    if not offers or chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local n, c = tonumber(f[1]), tonumber(f[2])
    ns.TrustWait(name, "officer", function(ok)
        if ok and offers then offers[name] = { n = n, c = c, t = GetTime() } end
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
