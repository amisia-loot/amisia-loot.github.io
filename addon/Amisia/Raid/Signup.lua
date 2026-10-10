-- Amisia raid sign-up (D-42, part H of the spec docs/specs/2026-10-10-raid-aufstellung.md): a raider
-- with Amisia signs up for a coming date of the game calendar (a guild event of the next 14 days,
-- Raid/Calendar.lua) with "Anmelden", "Vorläufig" or "Abmelden", a role and a short note. Saved on
-- the raider's side (AmisiaDB.signup, per character), sent to the guild as the message AN; every
-- officer with Amisia in the officer view takes it into the lineup of the night (Raid/Lineup.lua,
-- source "Amisia"). AmisiaDB is account-wide: an officer takes the sign-ups of the own characters
-- of the same account straight from it, without a message.
--
-- Messages (Core/Comm.lua):
--   AN <night> <A|V|X> <T|H|M|R|-> <class|-> <epoch of the click> <event id|-> [<note|->]
--        raider -> GUILD on the click and once after the login (low); WHISPER as the answer to AQ
--   AQ <O|-> <rev>   an officer -> GUILD once 40-70 s after the login (low): "who signed up?"
-- Trust: the name is the sender the server sets (never a field); the officer takes AN only from a
-- guild member, for tonight up to 14 days ahead, 4 nights per sender; a raider answers AQ only to a
-- verified officer (rank flag 22), at most once in 10 minutes with at most 4 messages.
-- Writing into the game calendar (part H3: EventSignUp, EventTentative, EventDecline, RemoveEvent)
-- waits for the in-game checks 23 to 25; until then the window says "Bitte auch im Kalender
-- eintragen" with a button that opens the client's calendar window (ns.SignupCalendarWrite is the
-- seam for it).
local ADDON, ns = ...
local L = ns.L

local MAX_NIGHTS = 4       -- sign-ups kept per character (the soonest); nights per sender at the officer
local MAX_CHARS = 12       -- characters kept
local NOTE_MAX = 40        -- bytes of a note
local LOGIN_AFTER, LOGIN_SPREAD = 40, 30   -- the login's work 40-70 s after the login
local RESEND_EVERY = 1800  -- the own sign-ups go out again after a login at most this often (/reload too)
local ANSWER_EVERY = 600   -- one answer to an officer's AQ in this many seconds
local ANSWER_MAX = 4       -- messages of one answer
local ANSWER_SPREAD = 20   -- the answer waits 0 to this many seconds (not every raider at once)
local CLICK_TTL = 900      -- a click's message waits this long in the queue (lockdown, throttle)

local IS_ROLE = { T = true, H = true, M = true, R = true }
local OWN = { A = true, V = true, X = true }
-- what the player types after /amisia anmelden: German T/H/N/F, English T/H/M/R
local ROLE_WORD = { t = "T", h = "H", n = "M", f = "R", m = "M", r = "R" } -- l10n-ok: the typed role letters

local DB
local terms               -- the coming dates (ns.Cal.Events()); nil until read
local loading = false
local resent, asked = false, false
local answered = {}       -- [officer, lower] = GetTime() of the last answer

local function me() return ns.UnitFullName("player") end
local function tonight() return ns.NightOf(time()) end

local function posNum(v)
    v = tonumber(v)
    if v and v > 0 and v < 4294967296 then return math.floor(v) end
    return nil
end

-- A note as it is kept and sent: codes, links, bars, tabs and control characters away, 40 bytes.
function ns.SignupCleanNote(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("[%c|]", " "):gsub("%s+", " ")
    return ns.CleanNote(text, NOTE_MAX)
end
local cleanNote = ns.SignupCleanNote

local function eventId(v)
    v = type(v) == "number" and ("%.0f"):format(v) or v
    return type(v) == "string" and #v <= 20 and v:match("^%d+$") and v or nil
end

local function cleanRec(r)
    if type(r) ~= "table" or not OWN[r.s] or not posNum(r.t) then return nil end
    return { s = r.s, r = IS_ROLE[r.r] and r.r or nil, c = ns.LINEUP_CLASSES[r.c] and r.c or nil, t = posNum(r.t),
             w = cleanNote(r.w), e = eventId(r.e) }
end

---------------------------------------------------------------------------
-- Saved: AmisiaDB.signup = { v = 1, chars = { [name] = { [night] = { s, r, c, t, w, e } } }, sent }
---------------------------------------------------------------------------
-- Nights before tonight go, 4 nights per character (the soonest), 12 characters (the newest clicks).
function ns.SignupLoaded(root)
    local s = type(root.signup) == "table" and root.signup or {}
    local first = tonight()
    local chars = {}
    for name, nights in pairs(type(s.chars) == "table" and s.chars or {}) do
        local cn = type(name) == "string" and ns.FullName(name)
        if cn and #cn <= 48 and not cn:find("[%d%c|]") and type(nights) == "table" then
            local list = {}
            for night, r in pairs(nights) do
                local rec = type(night) == "string" and night:match("^%d%d%d%d%-%d%d%-%d%d$") and night >= first and cleanRec(r)
                if rec then list[#list + 1] = { night = night, rec = rec } end
            end
            table.sort(list, function(a, b) return a.night < b.night end)
            if #list > 0 then
                local map, newest = {}, 0
                for i = 1, math.min(#list, MAX_NIGHTS) do
                    map[list[i].night] = list[i].rec
                    newest = math.max(newest, list[i].rec.t)
                end
                chars[#chars + 1] = { name = cn, map = map, newest = newest }
            end
        end
    end
    table.sort(chars, function(a, b) return a.newest > b.newest end)
    local out = {}
    for i = 1, math.min(#chars, MAX_CHARS) do out[chars[i].name] = chars[i].map end
    root.signup = { v = 1, chars = out, sent = posNum(s.sent) }
    DB = root
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.SignupLoaded(AmisiaDB) end
end)

function ns.SignupState() return DB and DB.signup or nil end

-- The sign-ups of a character (default: the own), tonight on: { [night] = rec }.
function ns.SignupOf(name)
    local st = ns.SignupState()
    local map = st and st.chars[name or me() or ""]
    local out, first = {}, tonight()
    for night, rec in pairs(map or {}) do
        if night >= first then out[night] = rec end
    end
    return out
end

-- The own coming sign-ups as a list by night: { { night, rec } }.
local function upcoming(name)
    local list = {}
    for night, rec in pairs(ns.SignupOf(name)) do list[#list + 1] = { night = night, rec = rec } end
    table.sort(list, function(a, b) return a.night < b.night end)
    return list
end

-- The other characters of this account with a sign-up for night: { { name, rec } }.
function ns.SignupAlts(night)
    local st = ns.SignupState()
    local out, mine = {}, (me() or ""):lower()
    for name, map in pairs(st and st.chars or {}) do
        if name:lower() ~= mine and map[night] then out[#out + 1] = { name = name, rec = map[night] } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- The role to offer: the newest own sign-up's, else from the class.
function ns.SignupDefaultRole()
    local best, bt
    for _, it in ipairs(upcoming()) do
        if it.rec.r and (not bt or it.rec.t > bt) then best, bt = it.rec.r, it.rec.t end
    end
    if best then return best end
    local _, class = UnitClass("player")
    return ns.LINEUP_GUESS[ns.Plain(class) or ""] or "R"
end

---------------------------------------------------------------------------
-- The dates: the guild events of the next 14 days from the calendar
---------------------------------------------------------------------------
-- The dates read last (nil: not yet), and whether a read runs.
function ns.SignupTerms() return terms, loading end

-- Reads the dates (ns.Cal.Load) and calls fn(list or nil, why) when given.
function ns.SignupLoadTerms(fn)
    if not IsInGuild() then
        if fn then fn(nil, "guild") end
        return
    end
    if not ns.Cal.Available() then
        terms = nil
        if fn then fn(nil, "off") end
        return
    end
    loading = true
    ns.Cal.Load(function(list)
        loading = false
        terms = list or {}
        ns.Fire("SIGNUP")
        if fn then fn(terms) end
    end)
end

-- The calendar changed (a guild event made, moved or deleted): the dates are read anew.
ns.Listen("CALENDAR_CHANGED", function(event)
    if terms and (event == "CALENDAR_UPDATE_GUILD_EVENTS" or event == "CALENDAR_UPDATE_EVENT_LIST") and ns.Cal.Available() then
        terms = ns.Cal.Events()
        ns.Fire("SIGNUP")
    end
end)

local function termOf(night, id)
    for _, t in ipairs(terms or {}) do
        if t.night == night and (not id or t.id == id) then return t end
    end
    return nil
end

-- "Fr 20:00 Molten Core"
function ns.SignupTermText(t)
    return ("%s %s"):format(ns.Cal.When(t.at), t.title or "?")
end

local ROLE_NAME = { T = L["Tank"], H = L["Heiler"], M = L["Nahkampf"], R = L["Fernkampf"] }
local ROLE_SHORT = { T = L["T##Rolle"], H = L["H##Rolle"], M = L["N##Rolle"], R = L["F##Rolle"] }
ns.SIGNUP_ROLE_SHORT = ROLE_SHORT

-- "angemeldet (H)", "vorläufig (H)", "abgemeldet" or "noch offen".
function ns.SignupStateText(rec)
    if not rec then return L["noch offen"] end
    if rec.s == "X" then return L["abgemeldet"] end
    local word = rec.s == "V" and L["vorläufig"] or L["angemeldet"]
    return rec.r and ("%s (%s)"):format(word, ROLE_SHORT[rec.r]) or word
end

-- "angemeldet als Heiler", "vorläufig als Heiler", "abgemeldet".
local function stateLong(rec)
    if rec.s == "X" then return L["abgemeldet"] end
    local role = ROLE_NAME[rec.r] or L["ohne Rolle"]
    return (rec.s == "V" and L["vorläufig als %s"] or L["angemeldet als %s"]):format(role)
end

---------------------------------------------------------------------------
-- Sending and the officer's side
---------------------------------------------------------------------------
-- The officer drops a second AN of a sender for the same night within 10 s (Core/Comm.lua, keyed
-- gap): a message for a night waits until AN_GAP seconds after the last one for it went, so a quick
-- second click (another role, "Abmelden") is not lost.
local AN_GAP = 11
local lastSent = {}       -- [night] = GetTime() when its last AN went

local function sendAN(night, rec, chan, target, opts)
    if not (ns.CommReady and ns.CommReady()) then return false end
    local fields = { night, rec.s, rec.r or "-", rec.c or "-", tostring(rec.t), rec.e or "-", rec.w or "-" }
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.when = function() return not lastSent[night] or GetTime() - lastSent[night] >= AN_GAP end
    o.sent = function() lastSent[night] = GetTime() end
    return ns.CommSend("AN", fields, chan, target, o) and true or false
end

-- Whether a guild officer other than oneself is online (by the roster): nil when it cannot be read.
local function officerOnline()
    local list = ns.GuildRoster and ns.GuildRoster()
    if not list then return nil end
    local mine = me()
    for _, m in ipairs(list) do
        if m.online and not ns.SameName(m.name, mine) and ns.IsOfficerRank(m.rank) then return true end
    end
    return false
end

-- The officer takes sign-ups only in the officer view with the officer rank and lineup.signups.
local function takes()
    return ns.LineupAllowed and ns.LineupAllowed() and ns.Get("lineup.signups") ~= false
end

-- The officer: the sign-ups of every character of this account into the lineup, without a
-- message (AmisiaDB is account-wide). Returns how many changed it.
function ns.SignupTakeOwn()
    if not takes() or not ns.LineupSignup then return 0 end
    local st = ns.SignupState()
    local n = 0
    for name in pairs(st and st.chars or {}) do
        for night, rec in pairs(ns.SignupOf(name)) do
            if ns.LineupSignup(night, name, rec, true) then n = n + 1 end
        end
    end
    return n
end

ns.CommOn("AN", function(sender, f)
    if not DB or not takes() then return end
    local name = ns.TrustName(sender)
    local night = f[1]
    if not name or not ns.LineupSignupNight(night) then return end
    local rec = { s = f[2], r = IS_ROLE[f[3]] and f[3] or nil, c = f[4] ~= "-" and f[4] or nil, t = tonumber(f[5]),
                  w = f[7] and f[7] ~= "-" and cleanNote(f[7]) or nil }
    ns.TrustWait(name, "member", function(ok)
        if not ok or not takes() then return end
        -- at most 4 nights per sender
        local nights = ns.LineupSignupNights(name)
        if #nights >= MAX_NIGHTS then
            local has = false
            for _, x in ipairs(nights) do if x == night then has = true end end
            if not has then return end
        end
        ns.LineupSignup(night, name, rec, true)
    end)
end)

-- A delay of 0 to n seconds that differs per character (from its name).
local function spread(n)
    local h = ns.Checksum and tonumber(ns.Checksum(me() or "?"):sub(1, 6), 16) or 0
    return (h % (n * 10)) / 10
end

-- A raider answers a verified officer's question with the own coming sign-ups (WHISPER).
ns.CommOn("AQ", function(sender, f)
    if not DB or f[1] ~= "O" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "officer", function(ok)
        if not ok then return end
        local key = name:lower()
        if answered[key] and GetTime() - answered[key] < ANSWER_EVERY then return end
        local list = upcoming()
        if #list == 0 then return end
        answered[key] = GetTime()
        C_Timer.After(spread(ANSWER_SPREAD), function()
            for i = 1, math.min(#list, ANSWER_MAX) do
                sendAN(list[i].night, list[i].rec, "WHISPER", sender, { low = true })
            end
        end)
    end)
end)

-- Once after the login: the own coming sign-ups again (not within 30 minutes of the last time).
function ns.SignupResend()
    if resent or not DB or not IsInGuild() or not (ns.CommReady and ns.CommReady()) then return 0 end
    resent = true
    local st = DB.signup
    if st.sent and time() - st.sent < RESEND_EVERY then return 0 end
    local list, n = upcoming(), 0
    for i = 1, math.min(#list, MAX_NIGHTS) do
        if sendAN(list[i].night, list[i].rec, "GUILD", nil, { low = true, key = "AN:" .. list[i].night, jitter = 5 }) then n = n + 1 end
    end
    if n > 0 then st.sent = math.floor(time()) end
    return n
end

-- Once after the login, an officer asks the guild for the sign-ups (AQ).
function ns.SignupAsk()
    if asked or not DB or not IsInGuild() or not takes() or not (ns.CommReady and ns.CommReady()) then return false end
    asked = true
    return ns.CommSend("AQ", { "O", "0" }, "GUILD", nil, { key = "AQ", ttl = 120, low = true }) and true or false
end

local function loginWork()
    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            loginWork()
        end)
        return
    end
    ns.SignupLoadTerms()
    ns.SignupResend()
    ns.SignupAsk()
    ns.SignupTakeOwn()
end

local loginSeen = false
ns.OnEvent("PLAYER_LOGIN", function()
    if loginSeen then return end
    loginSeen = true
    C_Timer.After(LOGIN_AFTER + spread(LOGIN_SPREAD), loginWork)
end)

---------------------------------------------------------------------------
-- The click: Anmelden, Vorläufig, Abmelden
---------------------------------------------------------------------------
-- Writing into the game calendar (part H3) waits for the in-game checks 23 to 25: false, so the
-- window asks the player to sign up in the calendar too.
function ns.SignupCalendarWrite() return false end

-- Signs the own character up for term (an entry of ns.SignupTerms()) with status "A", "V" or "X",
-- role (T/H/M/R) and note. Saves, sends AN to the guild, takes it into the own lineup (an officer).
-- Returns true and the chat line, or nil and the reason.
function ns.SignupSet(term, status, role, note)
    if not DB then return nil, L["Amisia ist noch nicht geladen."] end
    if not IsInGuild() then return nil, L["Nur in einer Gilde."] end
    if type(term) ~= "table" or not term.night or not ns.LineupSignupNight(term.night) then
        return nil, L["Keine Raidtermine in den nächsten 14 Tagen."]
    end
    if not OWN[status] then return nil end
    local name = me()
    if not name then return nil end
    local _, class = UnitClass("player")
    local rec = { s = status, r = IS_ROLE[role] and role or nil, c = ns.LINEUP_CLASSES[ns.Plain(class) or ""] and ns.Plain(class) or nil,
                  t = math.floor(time()), w = cleanNote(note), e = eventId(term.id) }
    local st = DB.signup
    st.chars[name] = st.chars[name] or {}
    local map = st.chars[name]
    -- an earlier click for the same night with the same second: the new one is a second later
    if map[term.night] and map[term.night].t >= rec.t then rec.t = map[term.night].t + 1 end
    map[term.night] = rec
    -- 4 nights per character: the soonest stay
    local nights = {}
    for night in pairs(map) do
        if night < tonight() then map[night] = nil else nights[#nights + 1] = night end
    end
    table.sort(nights)
    for i = MAX_NIGHTS + 1, #nights do map[nights[i]] = nil end
    if not map[term.night] then return nil, L["Höchstens %d Anmeldungen gleichzeitig."]:format(MAX_NIGHTS) end
    local line = L["Raid-Anmeldung: %s · %s."]:format(ns.SignupTermText(term), stateLong(rec))
    local sent = sendAN(term.night, rec, "GUILD", nil, { key = "AN:" .. term.night, ttl = CLICK_TTL })
    if takes() then ns.LineupSignup(term.night, name, rec, true) end
    if not sent then
        line = line .. " " .. L["Gespeichert, nicht gesendet (Addon-Nachrichten sind aus)."]
    elseif officerOnline() == false and not takes() then
        line = line .. " " .. L["Kein Offizier online: Amisia schickt es, sobald einer kommt."]
    else
        line = line .. " " .. L["Gesendet."]
    end
    ns.Fire("SIGNUP")
    return true, line
end

-- The date a command or the window starts with: the next of the raid type, else the next.
function ns.SignupNextTerm()
    return ns.Cal.Next(terms or {})
end

---------------------------------------------------------------------------
-- Settings and /amisia anmelden
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "signup", label = L["Raid-Anmeldung"], order = 23, items = {
    { key = "signup.card", type = "toggle", label = L["Karte auf der Übersicht"], default = true,
      tip = L["Die Karte \"Raid-Anmeldung\" zeigt die nächsten drei Termine aus dem Spielkalender mit deiner Anmeldung."],
      onChange = function() if ns.Refresh then ns.Refresh() end end },
}}

local function usage()
    ns.msg(L["Aufruf: /amisia anmelden [T/H/N/F [Notiz]]"])
end

-- Signs the own character up (status A with role and note) or off (X) for the next date.
local function signupFor(status, role, note)
    if not IsInGuild() then
        ns.msg(L["Nur in einer Gilde."])
        return
    end
    ns.SignupLoadTerms(function(list, why)
        if not list then
            ns.msg(why == "off" and ns.Cal.Why("off") or L["Nur in einer Gilde."])
            return
        end
        local term = ns.SignupNextTerm()
        if not term then
            ns.msg(L["Keine Raidtermine in den nächsten 14 Tagen."])
            return
        end
        local old = ns.SignupOf()[term.night]
        local _, line = ns.SignupSet(term, status, role or (old and old.r) or ns.SignupDefaultRole(), note)
        if line then ns.msg(line) end
    end)
end

-- /amisia anmelden [T/H/N/F [Notiz]]: the window, or signed up with a role and a note.
ns.RegisterSlash("anmelden", { en = "signup", args = L["[T/H/N/F [Notiz]]"],
    desc = L["Raid-Anmeldung für den nächsten Termin aus dem Spielkalender"], run = function(rest)
        local word, more = (rest or ""):match("^(%S*)%s*(.-)$")
        word = (word or ""):lower()
        if not IsInGuild() then
            ns.msg(L["Nur in einer Gilde."])
            return
        end
        if word == "" then
            if ns.ShowSignup then ns.ShowSignup() end
            return
        end
        if not ROLE_WORD[word] then return usage() end
        signupFor("A", ROLE_WORD[word], more)
    end })
-- /amisia abmelden: signed off for the next date.
ns.RegisterSlash("abmelden", { en = "signoff", desc = L["Vom nächsten Termin aus dem Spielkalender abmelden"],
    run = function() signupFor("X") end })

-- for the tests
ns._signup = { termOf = termOf, reset = function() resent, asked, answered, terms, loading, lastSent = false, false, {}, nil, false, {} end,
               MAX_NIGHTS = MAX_NIGHTS }
