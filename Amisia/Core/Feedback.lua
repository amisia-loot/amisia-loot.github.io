-- Feedback (F-130, spec docs/specs/2026-11-05-feedback.md, D-61): a bug report or a wish from any
-- player to the author, in game. The report goes as invisible addon messages (WHISPER, kind FB: one
-- part with the details, then up to three parts of text) to the author's character; when he is
-- offline (the server's "not online" line, swallowed, or no answer within ACK_WAIT) it waits in
-- AmisiaDB.feedback.out and is tried again (after a login in 2-5 minutes, then every 30 minutes at
-- most, never in combat, the lockdown or an instance, MAX_TRIES tries, then "nicht zugestellt").
-- Only the author's client takes FB; it keeps the report in the inbox and answers FA ("angekommen").
-- Strangers may send, so the receiver caps everything: 3 reports per sender and day, 500 characters,
-- 4 parts within 60 s, 300 reports in the inbox (the oldest done ones go first), codes and bars
-- stripped, the sender only from the server's name, blocked senders dropped. Also keeps the last Lua
-- error naming Amisia (the client's error handler, chained) for "Fehler anhängen".
-- Saved: AmisiaDB.feedback { v = 1, seq, out = { { id, kind = B/W, text, meta, at, state, tries, next } },
-- inbox = { { id, from, kind, text, meta, at, done, new } }, day = { date, n }, recv = { date, n = { [lower
-- name] = n } }, blocked = { [lower name] = true }, err = { m, at } }; meta = { v, g, loc, cls, lvl, page, err }.
local ADDON, ns = ...
local L = ns.L

local Fb = {}
ns.Feedback = Fb

-- The author's characters (D-61): who receives. game: the client (ns.GAME) the character lives on;
-- faction: his faction (a whisper does not cross it); the realm is not checked (Forever's realm of the
-- author is not written down here; a player of another realm just waits until MAX_TRIES).
Fb.AUTHORS = { { name = "Vulo Vultrox", game = "forever", faction = "Horde" } }

Fb.MAX_CHARS = 500      -- characters of a report's text
Fb.PER_DAY = 3          -- reports a player may send a day (and the author takes per sender and day)
Fb.MAX_TRIES = 10       -- tries of a report before "nicht zugestellt"
Fb.INBOX_MAX = 300      -- reports in the author's inbox
local OUT_MAX = 30          -- own reports kept (the oldest delivered ones go first)
local PIECE = 210           -- bytes of escaped text per part (the envelope keeps under 250)
local TEXT_PARTS = 3        -- text parts per report (plus the part with the details: 4)
local ERR_BYTES = 150       -- bytes of the attached error (escaped)
local ACK_WAIT = 30         -- seconds to wait for FA before the try counts as failed
local RETRY_GAP = 1800      -- seconds between two tries of a report
local LOGIN_MIN, LOGIN_MAX = 120, 300   -- the first try after a login, seconds
local TICK = 15             -- seconds between two looks at the waiting reports
local OFFLINE_WINDOW = 10   -- seconds after a send in which "not online" belongs to it
local SET_WAIT = 60         -- seconds all parts of one report must arrive in
local SUMMARY_AFTER = 20    -- seconds after the login the author's chat summary comes
local NAME_MAX = 60
local REACK_GAP = 5         -- seconds between two answers to the same report sent again

local GAME_CODE = { forever = "f", tbc = "t", era = "e" }
local GAME_OF = { f = "forever", t = "tbc", e = "era" }
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true,
                  MAGE = true, WARLOCK = true, DRUID = true }
local STATES = { wait = true, sent = true, done = true, lost = true }

local report = ns.ReportError

-- the clock in whole seconds (stored times are whole numbers)
local function epoch() return math.floor(time()) end

local function fbData() return AmisiaDB and type(AmisiaDB.feedback) == "table" and AmisiaDB.feedback or nil end

local function changed() ns.Fire("FEEDBACK") end

---------------------------------------------------------------------------
-- Text: plain, valid UTF-8, counted in characters
---------------------------------------------------------------------------
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- Characters of s (valid UTF-8 sequences).
function Fb.Chars(s)
    if type(s) ~= "string" then return 0 end
    local n = 0
    for _ in s:gmatch(CHAR) do n = n + 1 end
    return n
end

-- s as plain text: colour codes, links (their shown text stays), textures and every other bar away,
-- control characters but the line break away, only valid UTF-8, at most three line breaks in a row,
-- trimmed; cut to max characters when max is given.
function Fb.Clean(s, max)
    if type(s) ~= "string" then return "" end
    s = s:gsub("\r\n?", "\n")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
    s = s:gsub("|n", "\n"):gsub("|", "")
    s = s:gsub("[%z\1-\9\11-\31\127]", "")
    local out, n = {}, 0
    for ch in s:gmatch(CHAR) do
        n = n + 1
        if max and n > max then break end
        out[n] = ch
    end
    s = table.concat(out):gsub("\n\n\n+", "\n\n")
    return (s:match("^%s*(.-)%s*$"))
end

-- A line break and the backslash travel escaped (a field holds no control character).
local function escape(s) return (s:gsub("\\", "\\\\"):gsub("\n", "\\n")) end
local function unescape(s)
    return (s:gsub("\\(.)", function(c) return c == "n" and "\n" or c end))
end

-- The text in escaped pieces of at most PIECE bytes, never cutting a character or an escape.
local function pieces(text)
    local out, cur = {}, ""
    for ch in text:gmatch(CHAR) do
        local e = escape(ch)
        if #cur + #e > PIECE then
            out[#out + 1] = cur
            cur = ""
        end
        cur = cur .. e
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end

-- An escaped text of at most bytes bytes, cut at a character.
local function cutEscaped(text, bytes)
    local cur = ""
    for ch in text:gmatch(CHAR) do
        local e = escape(ch)
        if #cur + #e > bytes then break end
        cur = cur .. e
    end
    return cur
end

local function today(t) return date("%Y-%m-%d", t or epoch()) end

local function lowName(n) return type(n) == "string" and n:lower() or "" end

---------------------------------------------------------------------------
-- Who is the author, can he be reached
---------------------------------------------------------------------------
local function myName() return ns.UnitFullName("player") end

local function authorNamed(name)
    name = ns.FullName(name)
    if not name then return nil end
    for _, a in ipairs(Fb.AUTHORS) do
        if a.name:lower() == name:lower() and a.game == ns.GAME then return a end
    end
    return nil
end

-- Whether this character is one of the author's (on this client).
function Fb.IsAuthor() return authorNamed(myName()) ~= nil end

local function myFaction()
    local ok, f = pcall(function() return UnitFactionGroup and UnitFactionGroup("player") end)
    return ok and ns.Plain(f) or nil
end

-- The author characters a report can go to from here (this client, the faction), in list order; an
-- empty list when none.
function Fb.Targets()
    local out, fac = {}, myFaction()
    for _, a in ipairs(Fb.AUTHORS) do
        if a.game == ns.GAME and (not a.faction or not fac or a.faction == fac) then out[#out + 1] = a end
    end
    return out
end

-- Whether a report can reach the author from here at all (false: the page's hint, "Abschicken" off).
function Fb.Reachable()
    return Fb.IsAuthor() or #Fb.Targets() > 0
end

---------------------------------------------------------------------------
-- The last Amisia error (for "Fehler anhängen")
---------------------------------------------------------------------------
local lastErr   -- { m, at } before AmisiaDB is there

local function noteError(msg)
    msg = ns.Plain(msg)
    if type(msg) ~= "string" or not msg:find("Amisia", 1, true) then return end
    local m = Fb.Clean(msg:gsub("^.-AddOns[/\\]", ""), 300)
    if m == "" then return end
    lastErr = { m = m, at = epoch() }
    local fb = fbData()
    if fb then fb.err = lastErr end
end

-- Amisia chains itself in front of the client's error handler (whatever is set when it loads):
-- every error goes on to it unchanged, Amisia only notes one that names Amisia.
do
    local okGet, prev = pcall(function() return geterrorhandler and geterrorhandler() end)
    local set = _G.seterrorhandler
    if okGet and type(prev) == "function" and type(set) == "function" then
        pcall(set, function(msg, ...)
            pcall(noteError, msg)
            return prev(msg, ...)
        end)
    end
end

-- The last noted Amisia error as plain text, or nil.
function Fb.LastError()
    local fb = fbData()
    local e = (fb and fb.err) or lastErr
    return e and e.m or nil
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local int = ns.Int

local function isId(v) return type(v) == "string" and #v <= 20 and v:match("^%d+%-%d+$") ~= nil end

local function plainField(v, max)
    if type(v) ~= "string" or v == "" or #v > max or v:find("[%c|]") then return nil end
    return v
end

-- The details of a report, checked: { v, g, loc, cls, lvl, page, err }.
local function shapeMeta(m)
    m = type(m) == "table" and m or {}
    local v = plainField(m.v, 12)
    return {
        v = v and v:match("^%d+%.%d+%.%d+") and v or "?",
        g = GAME_OF[m.g] and m.g or nil,
        loc = type(m.loc) == "string" and m.loc:match("^%a%a%a%a$") and m.loc or nil,
        cls = CLASSES[m.cls] and m.cls or nil,
        lvl = int(m.lvl, 1, 99) and m.lvl or nil,
        page = type(m.page) == "string" and #m.page <= 24 and m.page:match("^[%w_]+$") and m.page or nil,
        err = type(m.err) == "string" and m.err ~= "" and Fb.Clean(m.err, 300) or nil,
    }
end

-- Shapes AmisiaDB.feedback: every entry checked (bad ones dropped), a report still "unterwegs"
-- waits again, the lists capped. Twice changes nothing.
function ns.FeedbackLoaded(root, now)
    now = now or epoch()
    local fb = type(root.feedback) == "table" and root.feedback or {}
    root.feedback = fb
    local out = {}
    for _, e in ipairs(type(fb.out) == "table" and fb.out or {}) do
        if type(e) == "table" and isId(e.id) and (e.kind == "B" or e.kind == "W") and int(e.at, 1) then
            local text = Fb.Clean(e.text, Fb.MAX_CHARS)
            if text ~= "" then
                local state = STATES[e.state] and e.state or "wait"
                if state == "sent" then state = "wait" end
                out[#out + 1] = { id = e.id, kind = e.kind, text = text, meta = shapeMeta(e.meta), at = e.at, state = state,
                                  tries = int(e.tries, 0, 99) and e.tries or 0, next = int(e.next, 0) and e.next or 0 }
            end
        end
    end
    local inbox, seen = {}, {}
    for _, e in ipairs(type(fb.inbox) == "table" and fb.inbox or {}) do
        if type(e) == "table" and isId(e.id) and (e.kind == "B" or e.kind == "W") and int(e.at, 1) then
            local from = plainField(e.from, NAME_MAX)
            local text = Fb.Clean(e.text, Fb.MAX_CHARS)
            local key = from and (from:lower() .. "/" .. e.id)
            if from and text ~= "" and not seen[key] then
                seen[key] = true
                inbox[#inbox + 1] = { id = e.id, from = from, kind = e.kind, text = text, meta = shapeMeta(e.meta), at = e.at,
                                      done = e.done == true or nil, new = e.new == true or nil }
            end
        end
    end
    local blocked = {}
    for name, on in pairs(type(fb.blocked) == "table" and fb.blocked or {}) do
        if on == true and plainField(name, NAME_MAX) then blocked[name:lower()] = true end
    end
    local day = type(fb.day) == "table" and fb.day or {}
    day = { date = type(day.date) == "string" and day.date:match("^%d%d%d%d%-%d%d%-%d%d$") and day.date or today(now),
            n = int(day.n, 0, 99) and day.n or 0 }
    local recv = type(fb.recv) == "table" and fb.recv or {}
    local counts = {}
    if recv.date == today(now) then
        for name, n in pairs(type(recv.n) == "table" and recv.n or {}) do
            if plainField(name, NAME_MAX) and int(n, 0, 99) then counts[name:lower()] = n end
        end
    end
    local err = type(fb.err) == "table" and fb.err or nil
    err = err and type(err.m) == "string" and err.m ~= "" and int(err.at, 1) and { m = Fb.Clean(err.m, 300), at = err.at } or nil
    local seq = int(fb.seq, 0, 999) and fb.seq or 0
    for k in pairs(fb) do fb[k] = nil end
    fb.v, fb.seq, fb.out, fb.inbox, fb.blocked, fb.day = 1, seq, out, inbox, blocked, day
    fb.recv = { date = today(now), n = counts }
    fb.err = err or lastErr
    Fb.Trim(fb)
    return fb
end

-- The lists capped: own reports OUT_MAX (delivered and lost ones go first), the inbox INBOX_MAX (the
-- oldest done ones first, then the oldest open ones).
function Fb.Trim(fb)
    local function drop(list, max, first)
        while #list > max do
            local at
            for i, e in ipairs(list) do
                if first(e) and (not at or e.at < list[at].at) then at = i end
            end
            if not at then
                for i, e in ipairs(list) do
                    if not at or e.at < list[at].at then at = i end
                end
            end
            table.remove(list, at)
        end
    end
    drop(fb.out, OUT_MAX, function(e) return e.state == "done" or e.state == "lost" end)
    drop(fb.inbox, Fb.INBOX_MAX, function(e) return e.done end)
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then
        ns.FeedbackLoaded(AmisiaDB)
        if Fb.UpdateLabel then Fb.UpdateLabel() end
    end
end)

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local inPvP = function()
    local ok, _, kind = pcall(GetInstanceInfo)
    if ok and (kind == "pvp" or kind == "arena") then return true end
    local pvp = _G.C_PvP
    if type(pvp) == "table" and type(pvp.IsActiveBattlefield) == "function" then
        local okB, on = pcall(pvp.IsActiveBattlefield)
        if okB and ns.Plain(on) then return true end
    end
    return false
end

-- Whether a report may go now: messages work, no combat, no lockdown, no battleground or arena;
-- a retry (retry) also not in any instance. false and the reason otherwise.
function Fb.CanSend(retry)
    if not ns.CommAvailable() then return false, L["Addon-Nachrichten sind nicht verfügbar."] end
    if InCombatLockdown() then return false, L["Im Kampf."] end
    if ns.CommHeld() then return false, L["Kampfsperre."] end
    if inPvP() then return false, L["Im Schlachtfeld oder in der Arena."] end
    if retry then
        local ok, inside = pcall(IsInInstance)
        if ok and inside then return false, L["In einer Instanz."] end
    end
    return true
end

-- The details that go with a report (shown under the field): Amisia version, game, client language,
-- class, level, the page open before; for a bug the last Amisia error when withErr.
function Fb.Meta(kind, withErr)
    local _, cls = UnitClass("player")
    local lvl = tonumber(ns.Plain(UnitLevel("player")))
    local page = ns.PreviousPage and ns.PreviousPage() or nil
    if page == "feedback" then page = nil end
    return shapeMeta({ v = ns.VERSION, g = GAME_CODE[ns.GAME], loc = GetLocale(), cls = ns.Plain(cls),
                       lvl = lvl and math.floor(lvl) or nil, page = page,
                       err = kind == "B" and withErr and Fb.LastError() or nil })
end

-- The details as one line of text.
function Fb.MetaText(meta)
    local parts = { "Amisia " .. (meta.v or "?") }
    parts[#parts + 1] = ns.GAME_NAMES[GAME_OF[meta.g or ""] or ""] or "?"
    if meta.loc then parts[#parts + 1] = meta.loc end
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    if meta.cls then parts[#parts + 1] = (type(names) == "table" and names[meta.cls]) or meta.cls end
    if meta.lvl then parts[#parts + 1] = L["Stufe %d"]:format(meta.lvl) end
    if meta.page then
        local p = ns.Panel(meta.page)
        parts[#parts + 1] = L["Seite: %s"]:format(p and p.label or meta.page)
    end
    return table.concat(parts, " · ")
end

-- The FB messages of a report: the details first, then the text in pieces; nil when it is too long.
local function messages(e)
    local list = pieces(e.text)
    if #list == 0 or #list > TEXT_PARTS then return nil end
    local m, n = e.meta, #list + 1
    local out = { { e.id, "1", tostring(n), e.kind, m.v or "?", m.g or "f", m.loc or "enUS", m.cls or "-",
                    tostring(m.lvl or 0), m.page or "-", m.err and cutEscaped(m.err, ERR_BYTES) or "-" } }
    for i, p in ipairs(list) do out[i + 1] = { e.id, tostring(i + 1), tostring(n), p } end
    return out
end

local flight = {}   -- id -> { target index, at (GetTime of the send), told (the click: chat lines) }
local lastSendTo, lastSendAt   -- the author name of the last send and when (for "not online")
local tickPending = false

local function targetOf(i) return Fb.Targets()[i] end

local scheduleTick, failed

local function sendTo(e, idx)
    local a = targetOf(idx)
    if not a then return false end
    for i, fields in ipairs(messages(e) or {}) do
        ns.CommSend("FB", fields, "WHISPER", a.name, { anyone = true, ttl = 60, key = "FB:" .. e.id .. ":" .. i })
    end
    local f = flight[e.id]
    local at = GetTime()
    f.idx, f.at = idx, at
    lastSendTo, lastSendAt = a.name, at
    -- no answer within ACK_WAIT: the try failed (unless a later send to the next character runs)
    C_Timer.After(ACK_WAIT, function()
        if flight[e.id] == f and f.at == at then failed(e, false) end
    end)
    return true
end

-- A try failed (no answer, or "not online"): the next author character of the list, else the report
-- waits again (or is lost after MAX_TRIES).
failed = function(e, offline)
    local f = flight[e.id]
    if f and offline and targetOf(f.idx + 1) then
        sendTo(e, f.idx + 1)
        return
    end
    flight[e.id] = nil
    if e.state ~= "sent" then return end
    e.state = e.tries >= Fb.MAX_TRIES and "lost" or "wait"
    e.next = epoch() + RETRY_GAP
    if f and f.told then
        ns.msg(L["Der Autor ist gerade nicht online; Amisia schickt die Meldung, sobald er da ist."])
    end
    changed()
    scheduleTick()
end

-- One try of a report now (the caller checked CanSend). told: chat lines (a click).
local function try(e, told)
    if not messages(e) then
        e.state = "lost"
        changed()
        return
    end
    e.state, e.tries = "sent", e.tries + 1
    flight[e.id] = { idx = 1, told = told }
    if told then ns.msg(L["Meldung an den Autor unterwegs."]) end
    sendTo(e, 1)
    changed()
end

-- The waiting reports whose time has come go, when they may.
local function tick()
    tickPending = false
    local fb = fbData()
    if not fb then return end
    local now, waiting = epoch(), false
    for _, e in ipairs(fb.out) do
        if e.state == "wait" then
            waiting = true
            if e.next <= now and Fb.CanSend(true) and #Fb.Targets() > 0 then try(e, false) end
        end
    end
    if waiting then scheduleTick() end
end

scheduleTick = function()
    if tickPending then return end
    tickPending = true
    C_Timer.After(TICK, tick)
end

local function newId(fb)
    fb.seq = (fb.seq or 0) % 999 + 1
    return ("%d-%d"):format(epoch(), fb.seq)
end

local storeReport

-- Sends a report: kind "B" (bug) or "W" (wish), the text (cleaned, 1-500 characters), withErr: a
-- bug takes the last Amisia error along. Returns true, or nil and the reason (shown in the chat).
function Fb.Submit(kind, text, withErr)
    local fb = fbData()
    if not fb then return nil, L["Amisia ist noch nicht geladen."] end
    if kind ~= "B" and kind ~= "W" then return nil, L["Bug oder Wunsch wählen."] end
    text = Fb.Clean(text)
    if text == "" then return nil, L["Bitte etwas schreiben."] end
    if Fb.Chars(text) > Fb.MAX_CHARS then return nil, L["Höchstens %d Zeichen."]:format(Fb.MAX_CHARS) end
    if not Fb.Reachable() then return nil, L["Auf diesem Server kann Amisia den Autor nicht erreichen."] end
    local d = today()
    if fb.day.date ~= d then fb.day = { date = d, n = 0 } end
    if fb.day.n >= Fb.PER_DAY then return nil, L["Höchstens 3 Meldungen am Tag."] end
    local e = { id = newId(fb), kind = kind, text = text, meta = Fb.Meta(kind, withErr), at = epoch(), state = "wait", tries = 0, next = 0 }
    if not messages(e) then return nil, L["Der Text ist zu lang (viele Sonderzeichen)."] end
    fb.day.n = fb.day.n + 1
    -- the author himself: straight into the inbox, nothing is sent
    if Fb.IsAuthor() then
        e.state = "done"
        table.insert(fb.out, e)
        storeReport(fb, myName(), e.id, kind, text, e.meta)
        Fb.Trim(fb)
        changed()
        return true
    end
    table.insert(fb.out, e)
    Fb.Trim(fb)
    if Fb.CanSend(false) then
        try(e, true)
    else
        ns.msg(L["Meldung gespeichert; Amisia schickt sie, sobald es geht."])
        changed()
    end
    scheduleTick()
    return true
end

-- "Nochmal": a lost report waits again and goes at the next chance, its tries start over.
function Fb.Retry(id)
    local fb = fbData()
    for _, e in ipairs(fb and fb.out or {}) do
        if e.id == id and e.state == "lost" then
            e.state, e.tries, e.next = "wait", 0, 0
            if Fb.CanSend(false) and #Fb.Targets() > 0 then try(e, true) else changed() end
            scheduleTick()
            return true
        end
    end
    return false
end

-- The own reports, newest first.
function Fb.Out()
    local fb, list = fbData(), {}
    for _, e in ipairs(fb and fb.out or {}) do list[#list + 1] = e end
    table.sort(list, function(a, b) if a.at ~= b.at then return a.at > b.at end return a.id > b.id end)
    return list
end

-- How many reports the player may still send today.
function Fb.LeftToday()
    local fb = fbData()
    if not fb then return Fb.PER_DAY end
    if fb.day.date ~= today() then return Fb.PER_DAY end
    return math.max(0, Fb.PER_DAY - fb.day.n)
end

-- After a login (also /reload): the waiting reports try in 2-5 minutes.
ns.OnEvent("PLAYER_LOGIN", function()
    local fb = fbData()
    if not fb then return end
    local at
    for _, e in ipairs(fb.out) do
        if e.state == "wait" then
            at = at or epoch() + math.random(LOGIN_MIN, LOGIN_MAX)
            e.next = at
        end
    end
    if at then
        tickPending = true
        C_Timer.After(at - epoch(), tick)
    end
end)

---------------------------------------------------------------------------
-- "Not online": the server's line for a whisper to an offline name, swallowed when it is the author
-- Amisia just sent to
---------------------------------------------------------------------------
local function offlineName(text)
    text = ns.Plain(text)
    local pattern = ns.TemplatePattern(_G.ERR_CHAT_PLAYER_NOT_FOUND_S)
    if type(text) ~= "string" or not pattern then return nil end
    local name = text:match(pattern)
    return name and ns.TemplateName(name) or nil
end

local function oursOffline(text)
    if not lastSendTo or not lastSendAt or GetTime() - lastSendAt > OFFLINE_WINDOW then return false end
    local name = offlineName(text)
    if not name then return false end
    local base = name:match("^(.-)%-[^%-]+$")
    return name:lower() == lastSendTo:lower() or (base ~= nil and base:lower() == lastSendTo:lower())
end

ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    if not oursOffline(text) then return end
    local fb = fbData()
    local target = lastSendTo:lower()
    for _, e in ipairs(fb and fb.out or {}) do
        local f = flight[e.id]
        local a = f and targetOf(f.idx)
        if e.state == "sent" and a and a.name:lower() == target then failed(e, true) end
    end
end)

do
    local add = _G.ChatFrame_AddMessageEventFilter
    local util = _G.ChatFrameUtil
    if type(add) ~= "function" and type(util) == "table" then add = util.AddMessageEventFilter end
    if type(add) == "function" then
        pcall(add, "CHAT_MSG_SYSTEM", function(_, _, text)
            local ok, ours = pcall(oursOffline, text)
            return ok and ours or false
        end)
    end
end

---------------------------------------------------------------------------
-- The author's client: the inbox
---------------------------------------------------------------------------
local sets = {}     -- lower sender -> { id, n, got = { [part] = fields }, at }
local told = false  -- the session's chat summary went
local acked = {}    -- "<lower sender>:<id>" -> GetTime of the last answer to a report sent again

storeReport = function(fb, from, id, kind, text, meta)
    for _, e in ipairs(fb.inbox) do
        if e.id == id and e.from:lower() == from:lower() then return e, false end
    end
    local e = { id = id, from = from, kind = kind, text = text, meta = meta, at = epoch(), new = true }
    fb.inbox[#fb.inbox + 1] = e
    Fb.Trim(fb)
    return e, true
end

local summary

-- The inbox: filter "open", "done" or "all" (default), newest first.
function Fb.Inbox(filter)
    local fb, list = fbData(), {}
    for _, e in ipairs(fb and fb.inbox or {}) do
        if filter == "open" and not e.done or filter == "done" and e.done or filter ~= "open" and filter ~= "done" then
            list[#list + 1] = e
        end
    end
    table.sort(list, function(a, b) if a.at ~= b.at then return a.at > b.at end return a.id > b.id end)
    return list
end

function Fb.OpenCount()
    local n = 0
    local fb = fbData()
    for _, e in ipairs(fb and fb.inbox or {}) do
        if not e.done then n = n + 1 end
    end
    return n
end

-- The page's name with the open reports on the author's characters ("Feedback (2)").
function Fb.UpdateLabel()
    local p = ns.Panel("feedback")
    if not p then return end
    local n = Fb.IsAuthor() and Fb.OpenCount() or 0
    p.label = n > 0 and ("%s (%d)"):format(L["Feedback"], n) or L["Feedback"]
end

function Fb.SetDone(e, on)
    e.done = on and true or nil
    e.new = nil
    Fb.UpdateLabel()
    changed()
end

function Fb.Delete(e)
    local fb = fbData()
    for i, x in ipairs(fb and fb.inbox or {}) do
        if x == e then
            table.remove(fb.inbox, i)
            break
        end
    end
    Fb.UpdateLabel()
    changed()
end

function Fb.IsBlocked(name)
    local fb = fbData()
    return fb ~= nil and fb.blocked[lowName(name)] == true
end

function Fb.Block(name, on)
    local fb = fbData()
    if not fb or type(name) ~= "string" then return end
    fb.blocked[name:lower()] = on and true or nil
    changed()
end

-- The inbox was looked at: nothing counts as new any more.
function Fb.MarkSeen()
    local fb = fbData()
    for _, e in ipairs(fb and fb.inbox or {}) do e.new = nil end
end

-- The author's chat line, once a session: "Amisia: 2 neue Meldungen (1 Bug, 1 Wunsch)."
summary = function()
    if told or not Fb.IsAuthor() then return end
    local fb = fbData()
    local bugs, wishes = 0, 0
    for _, e in ipairs(fb and fb.inbox or {}) do
        if e.new then
            if e.kind == "B" then bugs = bugs + 1 else wishes = wishes + 1 end
        end
    end
    if bugs + wishes == 0 then return end
    told = true
    ns.msg(L["%d neue Meldungen (%d Bug, %d Wunsch). /amisia feedback"]:format(bugs + wishes, bugs, wishes))
end

ns.OnEvent("PLAYER_LOGIN", function()
    Fb.UpdateLabel()
    C_Timer.After(SUMMARY_AFTER, function()
        local ok, err = pcall(summary)
        if not ok then report(err) end
    end)
end)

local function received(fb, from)
    local d = today()
    if fb.recv.date ~= d then fb.recv = { date = d, n = {} } end
    return fb.recv.n[from:lower()] or 0
end

-- A whole report: checked, stored, answered.
local function finish(fb, from, sender, s)
    local m = s.got[1]
    local text = {}
    for i = 2, s.n do text[#text + 1] = s.got[i][4] end
    text = unescape(table.concat(text))
    local clean = Fb.Clean(text)
    if clean == "" or Fb.Chars(clean) > Fb.MAX_CHARS then return end
    local errText = m[11] ~= nil and m[11] ~= "-" and Fb.Clean(unescape(m[11]), 300) or nil
    local meta = shapeMeta({ v = m[5], g = m[6], loc = m[7], cls = m[8], lvl = tonumber(m[9]), page = m[10] ~= "-" and m[10] or nil,
                             err = errText })
    local _, fresh = storeReport(fb, from, s.id, m[4], clean, meta)
    if fresh then
        fb.recv.n[from:lower()] = received(fb, from) + 1
        Fb.UpdateLabel()
        changed()
        if not told then C_Timer.After(5, function() pcall(summary) end) end
    end
    ns.CommSend("FA", { s.id }, "WHISPER", sender, { anyone = true, ttl = 60, key = "FA:" .. from:lower() .. ":" .. s.id })
end

ns.CommOn("FB", function(sender, f, chan)
    if chan ~= "WHISPER" or not Fb.IsAuthor() then return end
    local fb = fbData()
    if not fb then return end
    local from = ns.FullName(ns.StripOwnRealm(sender) or sender)
    if not from or #from > NAME_MAX or from:find("[%c|]") or fb.blocked[from:lower()] then return end
    local id, part, n = f[1], tonumber(f[2]), tonumber(f[3])
    -- a report already in the inbox: only the answer again (its FA got lost), once in REACK_GAP
    for _, e in ipairs(fb.inbox) do
        if e.id == id and e.from:lower() == from:lower() then
            local k, t = from:lower() .. ":" .. id, GetTime()
            if not acked[k] or t - acked[k] >= REACK_GAP then
                acked[k] = t
                ns.CommSend("FA", { id }, "WHISPER", sender, { anyone = true, ttl = 60, key = "FA:" .. k })
            end
            return
        end
    end
    if received(fb, from) >= Fb.PER_DAY then return end
    local low, t = from:lower(), GetTime()
    local s = sets[low]
    if s and (s.id ~= id or t - s.at > SET_WAIT) then
        -- one open report per sender: a newer one replaces an old one only after its time ran out
        if t - s.at <= SET_WAIT then return end
        s = nil
    end
    if not s then
        s = { id = id, n = n, got = {}, at = t }
        sets[low] = s
    end
    if s.n ~= n or s.got[part] then return end
    s.got[part] = f
    for i = 1, s.n do
        if not s.got[i] then return end
    end
    sets[low] = nil
    finish(fb, from, sender, s)
end)

---------------------------------------------------------------------------
-- The sender's client: "angekommen"
---------------------------------------------------------------------------
ns.CommOn("FA", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    local name = ns.StripOwnRealm(sender) or sender
    if not authorNamed(name) then return end
    local fb = fbData()
    for _, e in ipairs(fb and fb.out or {}) do
        if e.id == f[1] and e.state ~= "done" then
            e.state = "done"
            flight[e.id] = nil
            ns.msg(L["Deine Meldung ist beim Autor angekommen."])
            changed()
            return
        end
    end
end)

ns.RegisterSlash("feedback", { desc = L["Bug oder Wunsch an den Autor schicken"], run = function()
    if ns.ShowFeedback then ns.ShowFeedback() end
end })
