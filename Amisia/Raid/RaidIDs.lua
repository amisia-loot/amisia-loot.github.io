-- Raid IDs of mains and alts (F-099, spec docs/specs/2026-10-12-raid-check.md, part C, D-46): every
-- Amisia keeps the saved instances of each character of the account (AmisiaDB is account-wide) until
-- their reset, and tells the officers of the guild: once 60-180 s after the login (every character
-- of the account, low priority), after a new ID (the logged-in character, at most every 5 minutes)
-- and on an officer's question. An officer sees per instance who of the guild is free, locked
-- ("4/10, Reset Mi 05:00") or unknown (no Amisia), grouped by main (the site's alt list, F-028), and
-- a green or red "ID" per name on the page Aufstellung.
--
-- Messages (Core/Comm.lua):
--   IV <character> <class|-> <level> <ids|->   everyone -> GUILD (login, new ID; low) or WHISPER as the
--        answer to IQ; ids "instance:difficulty:reset epoch:killed/total", 6 at most
--   IQ -   an officer -> GUILD ("Raid-IDs abfragen", every 5 minutes at most); the answer by WHISPER
--        after 0-20 s, at most once in 10 minutes per officer
-- Trust: IV from a guild member, kept only in the officer view with the officer rank; the character
-- must stand in the guild roster; a character's own report wins over any other (D-12: one of the
-- last 7 days is never replaced by another sender's); a character the alt list gives another main
-- than the sender's is dropped, any other one of another sender shows grey "laut <sender>"; 12
-- characters per sender, 300 in all. IQ is answered only for a verified officer (rank flag 22).
local ADDON, ns = ...
local L = ns.L
local RR = ns.RaidRead

local LOGIN_AFTER, LOGIN_SPREAD = 60, 120   -- the login's report 60-180 s after the login
local NEW_GAP = 300          -- a new ID is reported at most this often
local ASK_GAP = 300          -- "Raid-IDs abfragen" at most this often
local ANSWER_EVERY = 600     -- one answer per officer in this many seconds
local ANSWER_SPREAD = 20     -- the answer waits 0 to this many seconds
local ANSWER_TTL = 30
local MAX_IDS = 6            -- IDs per character (raids first)
local MAX_OWN = 12           -- characters of the account kept (the newest logins)
local OWN_DAYS = 60          -- a character of the account without a login for this long goes
local HEARD_DAYS = 30
local HEARD_MAX = 300
local PER_SENDER = 12        -- characters one sender may report
local SELF_WINS = 7 * 86400  -- a character's own report is not replaced by another sender's for this long
local AHEAD = 31 * 86400     -- a reset further ahead than this drops the whole message
local NAMES_MAX = 100
local RESEND_EVERY = 1800    -- the login's report at most this often (a /reload sends nothing new)

local DB
local loginDone = false
local lastNew = -1e9         -- GetTime() of the last report after a new ID
local newPending = false
local lastAsk = -1e9
local answered = {}          -- [officer, lower] = GetTime() of the last answer
local chosen                 -- the instance chosen on the page (and the lineup's "ID" marks)

local function me() return ns.UnitFullName("player") end
local function now() return math.floor(ns.ServerTime and ns.ServerTime() or time()) end

local function posNum(v, max)
    v = tonumber(v)
    if v and v >= 0 and v <= (max or 4294967295) then return math.floor(v) end
    return nil
end

local function validName(name)
    local cn = type(name) == "string" and ns.FullName(name)
    if cn and #cn <= 48 and not cn:find("[%d%c|,:]") then return cn end
    return nil
end

local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true,
                  WARLOCK = true, DRUID = true }

-- One ID checked: { m, d, r, k, t }, nil when broken or past its reset.
local function cleanId(x, t)
    if type(x) ~= "table" then return nil end
    local m, d, r, k, tot = posNum(x.m, 999999), posNum(x.d, 255), posNum(x.r), posNum(x.k, 99), posNum(x.t, 99)
    if not (m and m > 0 and d and r and k and tot) or r <= t then return nil end
    return { m = m, d = d, r = r, k = k, t = tot }
end

local function cleanIds(list, t)
    local out = {}
    for _, x in ipairs(type(list) == "table" and list or {}) do
        local id = cleanId(x, t)
        if id and #out < MAX_IDS then out[#out + 1] = id end
    end
    return out
end

local function cleanRec(r, t)
    if type(r) ~= "table" then return nil end
    local at = posNum(r.at)
    if not at or at <= 0 then return nil end
    return { at = at, c = CLASSES[r.c] and r.c or nil, l = posNum(r.l, 99), ids = cleanIds(r.ids, t) }
end

---------------------------------------------------------------------------
-- Saved: AmisiaDB.raidcheck = { v = 1, own = { [char] = { at, c, l, ids } }, heard = { [char] = { by,
-- at, c, l, ids } }, names = { [instance] = name }, sent = epoch of the last login report }
---------------------------------------------------------------------------
-- IDs past their reset go; own characters after 60 days without a login, the 12 newest; heard ones
-- after 30 days, the 300 newest; the instance names 100 at most.
function ns.RaidIDsLoaded(root)
    local s = type(root.raidcheck) == "table" and root.raidcheck or {}
    local t = now()
    local own, list = {}, {}
    for name, r in pairs(type(s.own) == "table" and s.own or {}) do
        local cn, rec = validName(name), cleanRec(r, t)
        if cn and rec and t - rec.at <= OWN_DAYS * 86400 then list[#list + 1] = { name = cn, rec = rec } end
    end
    table.sort(list, function(a, b) return a.rec.at > b.rec.at end)
    for i = 1, math.min(#list, MAX_OWN) do own[list[i].name] = list[i].rec end
    local heard = {}
    list = {}
    for name, r in pairs(type(s.heard) == "table" and s.heard or {}) do
        local cn, rec = validName(name), cleanRec(r, t)
        local by = type(r) == "table" and validName(r.by)
        if cn and rec and by and t - rec.at <= HEARD_DAYS * 86400 then
            rec.by = by
            list[#list + 1] = { name = cn, rec = rec }
        end
    end
    table.sort(list, function(a, b) return a.rec.at > b.rec.at end)
    for i = 1, math.min(#list, HEARD_MAX) do heard[list[i].name] = list[i].rec end
    local names, n = {}, 0
    for m, name in pairs(type(s.names) == "table" and s.names or {}) do
        m = posNum(m, 999999)
        if m and m > 0 and type(name) == "string" and name ~= "" and #name <= 60 and not name:find("[%c|]") and n < NAMES_MAX then
            names[m], n = name, n + 1
        end
    end
    local sent = posNum(s.sent)
    root.raidcheck = { v = 1, own = own, heard = heard, names = names, sent = (sent and sent > 0 and sent <= t + 86400) and sent or nil }
    DB = root
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.RaidIDsLoaded(AmisiaDB) end
end)

function ns.RaidIDsState() return DB and DB.raidcheck or nil end

---------------------------------------------------------------------------
-- The own IDs: read from the client, kept per character of the account
---------------------------------------------------------------------------
local function idsKey(ids)
    local parts = {}
    for i, x in ipairs(ids or {}) do parts[i] = ("%d:%d:%d:%d/%d"):format(x.m, x.d, x.r, x.k, x.t) end
    return table.concat(parts, ",")
end

-- The client's name of an instance (its own language), 100 at most.
local function rememberName(m, label)
    if type(label) ~= "string" or label == "" or #label > 60 or label:find("[%c|]") then return end
    local names = DB.raidcheck.names
    if not names[m] then
        local n = 0
        for _ in pairs(names) do n = n + 1 end
        if n >= NAMES_MAX then return end
    end
    names[m] = label
end

-- Reads the saved instances of the logged-in character into own[me]. Returns whether its IDs
-- changed (a new ID or a new boss) and nil when nothing could be read.
function ns.RaidIDsReadOwn()
    local name = me()
    if not DB or not name or InCombatLockdown() then return nil end
    local ok, n = pcall(RR.SavedCount)
    if not ok then return nil end
    local t = now()
    local raids, others = {}, {}
    for i = 1, math.min(n or 0, 40) do
        local okS, v = pcall(RR.Saved, i)
        if okS then
            local locked, reset, m = ns.Plain(v.locked), tonumber(ns.Plain(v.reset)), tonumber(ns.Plain(v.mapID))
            if locked == true and reset and reset > 0 and m and m > 0 then
                local id = cleanId({ m = m, d = tonumber(ns.Plain(v.difficulty)) or 0, r = t + math.floor(reset),
                                     k = tonumber(ns.Plain(v.progress)) or 0, t = tonumber(ns.Plain(v.encounters)) or 0 }, t)
                if id then
                    if ns.Plain(v.isRaid) == true then raids[#raids + 1] = id else others[#others + 1] = id end
                    rememberName(m, ns.Plain(v.name))
                end
            end
        end
    end
    for _, x in ipairs(others) do raids[#raids + 1] = x end
    local ids = {}
    for i = 1, math.min(#raids, MAX_IDS) do ids[i] = raids[i] end
    local own = DB.raidcheck.own
    local old = own[name]
    local _, class = UnitClass("player")
    class = ns.Plain(class)
    own[name] = { at = t, c = CLASSES[class or ""] and class or nil, l = tonumber(ns.Plain(UnitLevel("player"))), ids = ids }
    -- the 12 newest characters
    local list = {}
    for cn, r in pairs(own) do list[#list + 1] = { name = cn, at = r.at } end
    if #list > MAX_OWN then
        table.sort(list, function(a, b) return a.at > b.at end)
        for i = MAX_OWN + 1, #list do own[list[i].name] = nil end
    end
    ns.Fire("RAIDIDS")
    -- a new ID or a new boss (the same IDs with a later reset is no change)
    local function shape(l)
        local parts = {}
        for i, x in ipairs(l or {}) do parts[i] = ("%d:%d:%d"):format(x.m, x.d, x.k) end
        table.sort(parts)
        return table.concat(parts, ",")
    end
    return old == nil and #ids > 0 or (old ~= nil and shape(old.ids) ~= shape(ids))
end

-- The IV fields of a character of the account.
local function fields(name, rec)
    local ids = idsKey(cleanIds(rec.ids, now()))
    return { name, rec.c or "-", tostring(math.max(1, math.min(rec.l or 1, 99))), ids ~= "" and ids or "-" }
end

local function sendOne(name, chan, target, opts)
    local rec = DB and DB.raidcheck.own[name]
    if not rec then return false end
    return ns.CommSend("IV", fields(name, rec), chan, target, opts) and true or false
end

local function canSend()
    return DB ~= nil and IsInGuild() and ns.Get("raidcheck.lockouts") ~= false and ns.CommReady and ns.CommReady()
end

-- Every character of the account to the guild (low priority). Returns how many were queued.
function ns.RaidIDsSendAll(chan, target, opts)
    if not canSend() then return 0 end
    local names = {}
    for name in pairs(DB.raidcheck.own) do names[#names + 1] = name end
    table.sort(names)
    local n = 0
    for i = 1, math.min(#names, MAX_OWN) do
        local o = {}
        for k, v in pairs(opts or {}) do o[k] = v end
        if chan == "GUILD" then o.key = "IV:" .. names[i] end
        if sendOne(names[i], chan, target, o) then n = n + 1 end
    end
    return n
end

-- After a new ID: the logged-in character to the guild, at most every 5 minutes.
local function reportNew()
    if not canSend() then return end
    local wait = NEW_GAP - (GetTime() - lastNew)
    if wait > 0 then
        if newPending then return end
        newPending = true
        C_Timer.After(wait, function()
            newPending = false
            reportNew()
        end)
        return
    end
    local name = me()
    if name and sendOne(name, "GUILD", nil, { low = true, key = "IV:" .. name }) then lastNew = GetTime() end
end

local function ask()
    local f = _G.RequestRaidInfo
    if type(f) == "function" then pcall(f) end
end

-- Runs fn now, or once after the fight (one waiting call per fn).
local waiting, waitFrame = {}, nil
local function afterCombat(fn)
    if not InCombatLockdown() then return fn() end
    waiting[fn] = true
    if not waitFrame then
        waitFrame = CreateFrame("Frame")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local list = waiting
            waiting = {}
            for f in pairs(list) do f() end
        end)
    end
    waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function readAndReport()
    local changed = ns.RaidIDsReadOwn()
    if changed and loginDone then reportNew() end
end
ns.OnEvent("UPDATE_INSTANCE_INFO", function() afterCombat(readAndReport) end)

-- A boss died: after the fight the client is asked for the IDs (UPDATE_INSTANCE_INFO follows).
local function bossDied() C_Timer.After(5, function() afterCombat(ask) end) end
local function askNow() afterCombat(ask) end
ns.OnEvent("BOSS_KILL", bossDied)
ns.OnEvent("ENCOUNTER_END", function(_, _, _, _, success)
    if ns.Plain(success) == 1 then bossDied() end
end)

-- A delay of 0 to n seconds that differs per character (from its name).
local function spread(n)
    local h = ns.Checksum and tonumber(ns.Checksum(me() or "?"):sub(1, 6), 16) or 0
    return (h % (n * 10)) / 10
end

local loginSeen = false
ns.OnEvent("PLAYER_LOGIN", function()
    if loginSeen then return end
    loginSeen = true
    C_Timer.After(5, askNow)
    C_Timer.After(LOGIN_AFTER + spread(LOGIN_SPREAD), function()
        afterCombat(ns.RaidIDsLogin)
    end)
end)

-- The login's report: the IDs asked for again, then every character of the account to the guild
-- (low priority), not within 30 minutes of the last one (a /reload sends nothing new).
function ns.RaidIDsLogin()
    ask()
    -- the client answers with UPDATE_INSTANCE_INFO; the report a moment later
    C_Timer.After(3, function()
        loginDone = true
        ns.RaidIDsReadOwn()
        local st = DB and DB.raidcheck
        if not st or (st.sent and now() - st.sent < RESEND_EVERY) then return end
        if ns.RaidIDsSendAll("GUILD", nil, { low = true, ttl = 120 }) > 0 then st.sent = now() end
    end)
end

---------------------------------------------------------------------------
-- The officer: asking and what was heard
---------------------------------------------------------------------------
-- "Raid-IDs abfragen": IQ to the guild, at most every 5 minutes. Returns true, or nil and why.
function ns.RaidIDsAsk()
    if not ns.RaidCheckAllowed() then return nil, L["Der Raid-Check ist nur für Offiziere."] end
    if not IsInGuild() then return nil, L["Nur in einer Gilde."] end
    local wait = ASK_GAP - (GetTime() - lastAsk)
    if wait > 0 then return nil, L["Gerade gefragt: wieder in %d Min."]:format(math.ceil(wait / 60)) end
    if not (ns.CommReady and ns.CommReady()) then return nil, L["Addon-Nachrichten sind nicht verfügbar."] end
    lastAsk = GetTime()
    ns.RaidIDsReadOwn()
    return ns.CommSend("IQ", { "-" }, "GUILD", nil, { key = "IQ", ttl = 30 }) and true or nil
end

-- Seconds until "Raid-IDs abfragen" works again (0: now).
function ns.RaidIDsAskWait() return math.max(0, math.ceil(ASK_GAP - (GetTime() - lastAsk))) end

ns.CommOn("IQ", function(sender)
    if not DB or ns.Get("raidcheck.lockouts") == false then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "officer", function(ok)
        if not ok then return end
        local key = name:lower()
        if answered[key] and GetTime() - answered[key] < ANSWER_EVERY then return end
        answered[key] = GetTime()
        C_Timer.After(spread(ANSWER_SPREAD), function()
            ns.RaidIDsSendAll("WHISPER", sender, { ttl = ANSWER_TTL })
        end)
    end)
end)

-- Parses the ids field: the list (past resets left out), or nil when a reset lies too far ahead.
local function parseIds(v, t)
    local out = {}
    if v == "-" then return out end
    for e in (v .. ","):gmatch("([^,]*),") do
        local m, d, r, k, tot = e:match("^(%d+):(%d+):(%d+):(%d+)/(%d+)$")
        r = tonumber(r)
        if not r or r > t + AHEAD then return nil end
        local id = cleanId({ m = tonumber(m), d = tonumber(d), r = r, k = tonumber(k), t = tonumber(tot) }, t)
        if id then out[#out + 1] = id end
    end
    return out
end

-- How many characters a sender reported (besides char).
local function reportedBy(from, char)
    local n = 0
    for name, r in pairs(DB.raidcheck.heard) do
        if ns.SameName(r.by, from) and not ns.SameName(name, char) then n = n + 1 end
    end
    return n
end

-- Takes one IV (the fields checked by Comm.lua). Returns whether it was kept.
function ns.RaidIDsTake(from, f)
    if not DB then return false end
    local char = validName(f[1])
    local t = now()
    local ids = parseIds(f[4], t)
    if not char or not ids then return false end
    if not ns.GuildMember(char) then return false end
    local heard = DB.raidcheck.heard
    local old = heard[char]
    local selfReport = ns.SameName(char, from)
    if not selfReport then
        -- the alt list gives the character another main than the sender's: dropped
        if ns.AltMain and (ns.AltMain(char) or ns.AltMain(from)) and not ns.SameMain(char, from) then return false end
        -- the character's own report of the last 7 days stays
        if old and ns.SameName(old.by, char) and t - old.at < SELF_WINS then return false end
    end
    if not old and reportedBy(from, char) >= PER_SENDER then return false end
    if not old then
        local n = 0
        for _ in pairs(heard) do n = n + 1 end
        if n >= HEARD_MAX then return false end
    end
    heard[char] = { by = from, at = t, c = f[2] ~= "-" and f[2] or nil, l = tonumber(f[3]), ids = ids }
    ns.Fire("RAIDIDS")
    return true
end

ns.CommOn("IV", function(sender, f)
    if not DB or not IsInGuild() or not ns.RaidCheckAllowed() then return end
    local from = ns.TrustName(sender)
    if not from then return end
    ns.TrustWait(from, "member", function(ok)
        if ok and ns.RaidCheckAllowed() then ns.RaidIDsTake(from, f) end
    end)
end)

---------------------------------------------------------------------------
-- What the officer sees
---------------------------------------------------------------------------
-- The record of a character: the own account's first, else what was heard; and whether it is the
-- character's own word ("self") or another's ("by").
local function recOf(name)
    local st = DB and DB.raidcheck
    if not st or not name then return nil end
    for cn, r in pairs(st.own) do
        if ns.SameName(cn, name) then return r, "own" end
    end
    for cn, r in pairs(st.heard) do
        if ns.SameName(cn, name) then return r, ns.SameName(r.by, cn) and "self" or "by" end
    end
    return nil
end

-- The name of an instance: what the own client called it, else the dungeon facts, else "Instanz N".
function ns.RaidIDsName(m)
    local st = DB and DB.raidcheck
    if st and st.names[m] then return st.names[m] end
    for _, d in ipairs(ns.DUNGEON_FACTS and ns.DUNGEON_FACTS.list or {}) do
        if d.inst == m then return d.name end
    end
    return L["Instanz %d"]:format(m)
end

-- The state of a character for instance m: "free", "locked" or "unknown", the ID (locked), the
-- record and its source ("own", "self", "by").
function ns.RaidIDOf(name, m)
    local rec, src = recOf(name)
    if not rec then return "unknown" end
    local t = now()
    for _, x in ipairs(rec.ids or {}) do
        if x.m == m and x.r > t then return "locked", x, rec, src end
    end
    return "free", nil, rec, src
end

-- The instances with an ID somebody known holds: { { m, name, n } }, the most IDs first.
function ns.RaidIDsInstances()
    local st = DB and DB.raidcheck
    local count = {}
    local t = now()
    for _, part in ipairs({ st and st.own or {}, st and st.heard or {} }) do
        for _, r in pairs(part) do
            for _, x in ipairs(r.ids or {}) do
                if x.r > t then count[x.m] = (count[x.m] or 0) + 1 end
            end
        end
    end
    local out = {}
    for m, n in pairs(count) do out[#out + 1] = { m = m, name = ns.RaidIDsName(m), n = n } end
    table.sort(out, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    return out
end

-- The instance chosen on the page (default: the one with the most IDs).
function ns.RaidIDsChosen()
    local list = ns.RaidIDsInstances()
    for _, x in ipairs(list) do
        if x.m == chosen then return chosen end
    end
    return list[1] and list[1].m or chosen
end
function ns.RaidIDsChoose(m)
    chosen = tonumber(m)
    ns.Fire("RAIDIDS")
end

-- "4/10, Reset Mi 05:00"
function ns.RaidIDText(x)
    return L["%d/%d, Reset %s"]:format(x.k, x.t, ns.Cal and ns.Cal.When(x.r) or date("%H:%M", x.r))
end

-- The free alts of a name's main for instance m (the alt list), without the name itself.
function ns.RaidIDFreeAlts(name, m)
    local out = {}
    local main = ns.MainOf and ns.MainOf(name) or name
    local cands = ns.AltsOf and ns.AltsOf(main) or {}
    cands[#cands + 1] = main
    for _, alt in ipairs(cands) do
        if not ns.SameName(alt, name) and ns.RaidIDOf(alt, m) == "free" then out[#out + 1] = alt end
    end
    table.sort(out)
    return out
end

-- The rows of the view Raid-IDs for instance m: every name of the guild roster, the account and
-- what was heard, grouped by main (alts indented). opts.free: only free ones; opts.top: only the
-- highest level. { { n, alt = true for an alt, state, id, by, c, l } }
function ns.RaidIDsRows(m, opts)
    opts = opts or {}
    local people = {}
    local function add(name, c, l)
        name = validName(name)
        if not name then return end
        local low = name:lower()
        local p = people[low]
        if not p then
            p = { n = name }
            people[low] = p
        end
        p.c = p.c or c
        p.l = p.l or l
    end
    for _, g in ipairs(ns.GuildRoster and ns.GuildRoster() or {}) do add(g.name, g.class, tonumber(g.level)) end
    local st = DB and DB.raidcheck
    for name, r in pairs(st and st.own or {}) do add(name, r.c, r.l) end
    for name, r in pairs(st and st.heard or {}) do add(name, r.c, r.l) end
    local top = tonumber(type(GetMaxPlayerLevel) == "function" and GetMaxPlayerLevel()) or 60
    local mains = {}
    for _, p in pairs(people) do
        local state, x, rec, src = ns.RaidIDOf(p.n, m)
        p.state, p.id = state, x
        p.l = p.l or (rec and rec.l)
        p.by = src == "by" and rec.by or nil
        local keep = (not opts.free or state == "free") and (not opts.top or (p.l or 0) >= top)
        if keep then
            local main = ns.MainOf and ns.MainOf(p.n) or p.n
            local key = main:lower()
            mains[key] = mains[key] or { main = main, list = {} }
            table.insert(mains[key].list, p)
        end
    end
    local keys = {}
    for k in pairs(mains) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local g = mains[k]
        table.sort(g.list, function(a, b)
            local am, bm = ns.SameName(a.n, g.main), ns.SameName(b.n, g.main)
            if am ~= bm then return am end
            return a.n:lower() < b.n:lower()
        end)
        for i, p in ipairs(g.list) do
            p.alt = not ns.SameName(p.n, g.main) and (i > 1)
            out[#out + 1] = p
        end
    end
    return out
end

-- The own characters' IDs as chat lines (raiders see their own: /amisia raidcheck).
function ns.RaidIDsOwnLines()
    local st = DB and DB.raidcheck
    local names = {}
    for name in pairs(st and st.own or {}) do names[#names + 1] = name end
    table.sort(names)
    local out = {}
    local t = now()
    for _, name in ipairs(names) do
        local parts = {}
        for _, x in ipairs(st.own[name].ids or {}) do
            if x.r > t then parts[#parts + 1] = ("%s %s"):format(ns.RaidIDsName(x.m), ns.RaidIDText(x)) end
        end
        out[#out + 1] = L["Raid-IDs %s: %s"]:format(name, #parts > 0 and table.concat(parts, " · ") or L["keine"])
    end
    if #out == 0 then out[1] = L["Raid-IDs: noch keine gelesen (nach dem Login oder einem Boss-Kill)."] end
    return out
end

-- for the tests
ns._raidids = { reset = function() loginDone, lastNew, newPending, lastAsk, answered, chosen = false, -1e9, false, -1e9, {}, nil end,
                reportNew = function() reportNew() end,
                login = function() loginDone = true end, PER_SENDER = PER_SENDER, HEARD_MAX = HEARD_MAX }
