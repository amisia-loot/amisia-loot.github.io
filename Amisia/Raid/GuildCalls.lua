-- Aufrufe der Gilde (F-211, D-136, spec docs/specs/2026-11-15-gilde-aufrufe.md): a member with Amisia puts
-- up a call (a dungeon, a group quest, help, anything else) with the roles it wants; every member with
-- Amisia sees it on the page Aufrufe (UI/Pages/Calls.lua) and once as a chat line with [Anmelden], signs up
-- with a role by whisper, and the creator invites the signed-up players (one by one or "Alle einladen" in
-- sign-up order up to the roles wanted; more than five turn the group into a raid). Messages (prefix
-- control): EA (the call, GUILD on every change at most every 10 s and as a heartbeat every 5 minutes,
-- WHISPER as the answer to EQ), EJ (a sign-up or a withdrawal, WHISPER to the creator), EX (the end, GUILD),
-- EQ (the question after the login, GUILD; every creator answers with its own call only). Only members of the
-- own guild count; a call is its sender's (keyed by the server's sender name), a sign-up its sender's. The
-- own running call with its sign-ups is saved (AmisiaDB.guildCall) and goes out again after a /reload; a
-- call ends with "Beenden", 2 hours after its time, or (for the others) 10 minutes without an EA. Nothing is
-- sent during the chat lockdown: the action waits with one chat line. The creator may change the own call
-- (GC.Edit, F-219, D-144): a new revision of the same call, its sign-ups kept.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local GC = {}
ns.GuildCalls = GC

local LIFE = 7200            -- seconds a call lives after its time
local HEARTBEAT = 300        -- seconds between two EA of an unchanged call
local REV_GAP = 10.5         -- seconds between two EA to the guild (the receivers drop one within 10 s)
local LOST = 600             -- seconds without an EA after which another's call is dropped
local JOIN_GAP = 5.5         -- seconds between two EJ to one call (the receiver drops one within 5 s)
local MAX_CALLS = 20         -- others' calls kept
local MAX_SIGNUPS = 30       -- sign-ups of the own call
local TITLE_CHARS, NOTE_CHARS = 40, 80
local TITLE_BYTES, NOTE_BYTES = 120, 240
local ASK_AFTER, ASK_SPREAD = 20, 20       -- the question after the login: 20 to 40 s
local REANNOUNCE_AFTER = 5                 -- the own call after a /reload: 5 to 10 s
local TICK = 1
-- the invites
local INVITE_GAP = 0.5
local NO_ANSWER = 90          -- seconds an invite counts as open
local CONVERT_WAIT = 10
local RUN_IDLE = 120          -- an invite run that waits this long without a step ends
local PARTY, RAID_MAX = 5, 40

GC.LIFE, GC.LOST, GC.MAX_CALLS, GC.MAX_SIGNUPS = LIFE, LOST, MAX_CALLS, MAX_SIGNUPS
GC.TITLE_CHARS, GC.NOTE_CHARS = TITLE_CHARS, NOTE_CHARS

GC.ARTS = { "D", "Q", "H", "S" }
GC.ART_NAMES = { D = L["Dungeon"], Q = L["Quest"], H = L["Hilfe"], S = L["Sonstiges"] }
GC.ROLES = { "T", "H", "S" }
GC.ROLE_NAMES = { T = L["Tank"], H = L["Heiler"], S = L["Schaden"] }
local ROLE_PLURAL = { T = L["%d Tanks"], H = L["%d Heiler"], S = L["%d Schaden"] }
local VALID_ART = { D = true, Q = true, H = true, S = true }
local VALID_ROLE = { T = true, H = true, S = true }

local calls = {}             -- [lower sender] = another's call
local mine = {}              -- [lower creator] = { id, role, at }: the own sign-ups
local announced = {}         -- ["lower sender:id"] = true: the chat line went
local saidAt = {}            -- [lower sender] = time of its last chat line: one a sender per CHAT_GAP
local CHAT_GAP = 300
local focus                  -- the lower sender the page shows first (a click on [Anmelden])
local lastEA                 -- GetTime() of the last own EA to the guild
local announceDue            -- GetTime() when the own call goes to the guild next
local owedEX = {}            -- ids of own calls whose EX waits for the lockdown's end
local joinAt = {}            -- ["lower creator:id"] = GetTime() of the last EJ
local joinOwed = {}          -- [lower creator] = { id, role, level, to }: an EJ that waits
local invitedAt = {}         -- [lower name] = GetTime() of the own invite
local run                    -- the invite run: { queue = { names }, sent, converting, lastStep }
local lastDigest             -- the counts of the own call last sent

local function now() return GetTime() end

local function changed() ns.FireSoon("GUILD_CALLS") end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------
-- s cut to at most chars characters and bytes bytes, never inside a character.
local function cut(s, chars, bytes)
    local out, n, i = {}, 0, 1
    while i <= #s and n < chars do
        local b = s:byte(i)
        local len = b < 0x80 and 1 or b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
        if i + len - 1 > bytes then break end
        out[#out + 1] = s:sub(i, i + len - 1)
        i, n = i + len, n + 1
    end
    return table.concat(out)
end

-- A title or note as the user typed it: no colour codes, links, bars, control characters or tabs, single
-- spaces, trimmed, at most chars characters (and bytes bytes); nil when nothing is left.
function GC.Clean(text, chars, bytes)
    if type(text) ~= "string" then return nil end
    text = ns.StripCodes(text):gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    text = cut(text, chars or TITLE_CHARS, bytes or TITLE_BYTES):match("^(.-)%s*$")
    if text == "" then return nil end
    return text
end

-- The characters of s (UTF-8).
function GC.Chars(s)
    local n = 0
    for _ in tostring(s or ""):gmatch("[^\128-\191]") do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Dungeons (only with the module Dungeons & Raids, F-202, F-228)
---------------------------------------------------------------------------
local function dungeons()
    local D = ns.HasModule("dungeons") and ns.Dungeons
    if not D or type(D.Facts) ~= "function" then return nil end
    local ok, facts = pcall(D.Facts)
    if not ok or type(facts) ~= "table" then return nil end
    return facts, D
end

-- The dungeons of Amisia's data for the picker: { { key, name, min } } by level, nil without the gear module.
function GC.DungeonChoices()
    local facts, D = dungeons()
    if not facts then return nil end
    local out = {}
    for _, e in ipairs(facts) do
        if type(e) == "table" and type(e.key) == "string" and e.kind ~= "raid" and #e.key <= 24 and e.key:match("^[%w_]+$") then
            local okN, name = pcall(D.Name, e)
            local min = tonumber(e.min) or tonumber(e.lvl)
            out[#out + 1] = { key = e.key, name = okN and type(name) == "string" and name or e.name or e.key,
                              min = min and math.max(1, math.min(99, math.floor(min))) or nil }
        end
    end
    table.sort(out, function(a, b)
        if (a.min or 0) ~= (b.min or 0) then return (a.min or 0) < (b.min or 0) end
        return a.name < b.name
    end)
    return out
end

-- A dungeon's name in this client's language, nil when the data lacks the key.
function GC.DungeonName(key)
    if type(key) ~= "string" then return nil end
    local facts, D = dungeons()
    if not facts then return nil end
    for _, e in ipairs(facts) do
        if type(e) == "table" and e.key == key then
            local ok, name = pcall(D.Name, e)
            return ok and type(name) == "string" and name or e.name
        end
    end
    return nil
end

-- What a call shows as its title: the dungeon's name in this client's language, else the sender's title.
function GC.Title(c)
    return (c.art == "D" and GC.DungeonName(c.key)) or c.title
end

---------------------------------------------------------------------------
-- Times
---------------------------------------------------------------------------
-- An epoch for "20:30" today (a time before now: tomorrow), nil for anything else.
function GC.ParseTime(text)
    local h, m = tostring(text or ""):match("^%s*(%d%d?)[:%.](%d%d)%s*$")
    h, m = tonumber(h), tonumber(m)
    if not h or h > 23 or m > 59 then return nil end
    local t = GetServerTime()
    local d = date("*t", t)
    local at = time({ year = d.year, month = d.month, day = d.day, hour = h, min = m, sec = 0 })
    if at <= t then at = at + 86400 end
    return at
end

-- The epoch the call's life counts from: its time, else when it was made (another's: first heard).
local function base(c) return (c.at and c.at > 0) and c.at or c.created or time() end
function GC.EndsAt(c) return base(c) + LIFE end

-- "jetzt" or "ab 20:30".
function GC.WhenText(c)
    if not c.at or c.at == 0 or c.at <= GetServerTime() then return L["jetzt"] end
    return L["ab %s##Aufruf"]:format(date("%H:%M", c.at))
end

-- "noch 1:45 h", "noch 12 min".
function GC.LeftText(c)
    local left = math.max(0, GC.EndsAt(c) - GetServerTime())
    if left >= 3600 then
        return L["noch %d:%02d h"]:format(math.floor(left / 3600), math.floor(left % 3600 / 60))
    end
    return L["noch %d min"]:format(math.max(1, math.ceil(left / 60)))
end

---------------------------------------------------------------------------
-- The own call
---------------------------------------------------------------------------
local function own()
    local c = type(AmisiaDB) == "table" and AmisiaDB.guildCall
    return type(c) == "table" and c or nil
end
function GC.Own() return own() end

local function inFight()
    return InCombatLockdown() or ns.AddOnRestricted(0)
end
local function locked()
    return ns.CommHeld() or ns.ChatLocked() or ns.AddOnRestricted(1)
end
GC.Locked = locked

-- The counts of the own call: need, signed and in the group per role ({ T, H, S } each).
local function ownCounts(c)
    local signed, inGroup = { T = 0, H = 0, S = 0 }, { T = 0, H = 0, S = 0 }
    for _, s in ipairs(c.signups) do
        signed[s.r] = signed[s.r] + 1
        if ns.InMyGroup(s.n) then inGroup[s.r] = inGroup[s.r] + 1 end
    end
    return c.need, signed, inGroup
end

local function full(need, inGroup)
    for _, r in ipairs(GC.ROLES) do
        if (inGroup[r] or 0) < (need[r] or 0) then return false end
    end
    return true
end

-- need, signed and in group of any call ({ T, H, S }) and whether it is full.
function GC.Counts(c)
    if c == own() then
        local need, signed, inGroup = ownCounts(c)
        return need, signed, inGroup, full(need, inGroup)
    end
    return c.need, c.signed, c.inGroup, c.state == "F"
end

local function triple(t) return ("%d/%d/%d"):format(t.T or 0, t.H or 0, t.S or 0) end

-- The fields of the own EA, cut to the message's 250 bytes (the note first, then the title).
function GC.Fields(c)
    c = c or own()
    if not c then return nil end
    local need, signed, inGroup = ownCounts(c)
    local note, title = c.note, c.title
    local function build()
        return { c.id, tostring(c.rev), c.art, c.key or "-", title, tostring(c.min), tostring(c.at or 0),
                 triple(need), triple(signed), triple(inGroup), full(need, inGroup) and "F" or "O", note or "-" }
    end
    local max = (ns.COMM_MAX_TEXT or 250) - #tostring(ns.SYNC_PROTO) - 2
    local fields = build()
    local function size() return #table.concat(fields, "\t") + 1 end
    while size() > max and note do
        local n = GC.Chars(note) - 1
        note = n > 0 and cut(note, n, NOTE_BYTES) or nil
        fields = build()
    end
    while size() > max and GC.Chars(title) > 1 do
        title = cut(title, GC.Chars(title) - 1, TITLE_BYTES)
        fields = build()
    end
    return fields
end

local function digest(c)
    local need, signed, inGroup = ownCounts(c)
    return triple(signed) .. triple(inGroup) .. (full(need, inGroup) and "F" or "O")
end

-- The own call changed (a sign-up, the group): a new revision, to the guild at most every 10 s.
local function ownChanged()
    local c = own()
    if not c then return end
    c.rev = c.rev % 999999 + 1
    lastDigest = digest(c)
    announceDue = math.max(now(), (lastEA or -1e9) + REV_GAP)
    changed()
end

local function sendOwn()
    local c = own()
    if not c or not ns.CommAvailable() or not ns.InGuild() then return false end
    if locked() then return false end
    local ok = ns.CommSend("EA", GC.Fields(c), "GUILD", nil, { key = "EA:GUILD", ttl = 60 })
    if ok then
        lastEA, announceDue = now(), nil
        lastDigest = digest(c)
    end
    return ok
end

local function newId()
    return ("%04x"):format(math.random(0, 65535))
end

-- The checked fields of a call's spec, or nil and the reason. keepAt: the time the call has (a change may
-- keep it even when it is past).
local function checked(spec, keepAt)
    spec = type(spec) == "table" and spec or {}
    local art = VALID_ART[spec.art] and spec.art or nil
    if not art then return nil, L["Wähle eine Art."] end
    local key = art == "D" and type(spec.key) == "string" and spec.key:match("^[%w_]+$") and #spec.key <= 24 and spec.key or nil
    local title = GC.Clean(spec.title, TITLE_CHARS, TITLE_BYTES) or (key and GC.Clean(GC.DungeonName(key), TITLE_CHARS, TITLE_BYTES))
    if not title then return nil, art == "D" and L["Wähle einen Dungeon oder gib einen Titel ein."] or L["Gib einen Titel ein."] end
    local min = tonumber(spec.min)
    if not min or min < 1 or min > 99 or min ~= math.floor(min) then return nil, L["Stufe 1 bis 99."] end
    local need, sum = {}, 0
    for _, r in ipairs(GC.ROLES) do
        local n = tonumber(spec.need and spec.need[r]) or 0
        if n < 0 or n > 40 or n ~= math.floor(n) then return nil, L["Rollen: zusammen 1 bis 40."] end
        need[r], sum = n, sum + n
    end
    if sum < 1 or sum > 40 then return nil, L["Rollen: zusammen 1 bis 40."] end
    local at = tonumber(spec.at) or 0
    if at ~= 0 and at ~= keepAt and (at < GetServerTime() or at > GetServerTime() + 86400) then
        return nil, L["Die Uhrzeit fehlt oder ist falsch (z. B. 20:30)."]
    end
    return { art = art, key = key, title = title, min = min, at = at, need = need, note = GC.Clean(spec.note, NOTE_CHARS, NOTE_BYTES) }
end

-- Puts up the own call. spec: { art, key, title, min, at (0 now, else an epoch), need = { T, H, S }, note }.
-- true, or nil and the reason.
function GC.Create(spec)
    if type(AmisiaDB) ~= "table" then return nil, L["Noch nicht geladen."] end
    if own() then return nil, L["Du hast schon einen Aufruf. Erst beenden."] end
    if not ns.InGuild() then return nil, L["Du bist in keiner Gilde."] end
    if not ns.CommAvailable() then return nil, L["Addon-Nachrichten sind nicht verfügbar."] end
    local x, why = checked(spec)
    if not x then return nil, why end
    AmisiaDB.guildCall = { v = 1, id = newId(), rev = 1, art = x.art, key = x.key, title = x.title, min = x.min, at = x.at,
        created = time(), need = x.need, note = x.note, signups = {}, declined = {} }
    lastDigest = nil
    announceDue = now()
    if locked() then
        ns.msg(L["Kampfsperre: Dein Aufruf geht an die Gilde, sobald sie vorbei ist."])
    else
        sendOwn()
    end
    changed()
    return true
end

-- Changes the own call (F-219, D-144): the same id, its sign-ups and declined names kept, a new revision to the
-- guild (EA at most every 10.5 s; in the lockdown once it is over). The time may stay as it is even when past.
-- true (also when nothing changed), or nil and the reason.
function GC.Edit(spec)
    local c = own()
    if not c then return nil, L["Du hast keinen Aufruf."] end
    local x, why = checked(spec, c.at)
    if not x then return nil, why end
    local same = x.art == c.art and x.key == c.key and x.title == c.title and x.min == c.min and x.at == (c.at or 0)
        and x.note == c.note
    for _, r in ipairs(GC.ROLES) do same = same and x.need[r] == (c.need[r] or 0) end
    if same then return true end
    -- switched to "jetzt": its life counts from now, not from when it was made (else it could end at once)
    if x.at == 0 and (c.at or 0) > 0 then c.created = time() end
    c.art, c.key, c.title, c.min, c.at, c.need, c.note = x.art, x.key, x.title, x.min, x.at, x.need, x.note
    ownChanged()
    if locked() then ns.msg(L["Kampfsperre: Die Änderung geht an die Gilde, sobald sie vorbei ist."]) end
    return true
end

-- Ends the own call (EX to the guild; in the lockdown once it is over).
function GC.End(quiet)
    local c = own()
    if not c then return nil end
    AmisiaDB.guildCall = nil
    announceDue, lastDigest = nil, nil
    run = nil
    if locked() then
        owedEX[#owedEX + 1] = c.id
        if not quiet then ns.msg(L["Kampfsperre: Das Ende deines Aufrufs geht an die Gilde, sobald sie vorbei ist."]) end
    elseif ns.CommAvailable() and ns.InGuild() then
        ns.CommSend("EX", { c.id }, "GUILD", nil, { key = "EX:" .. c.id, ttl = 120 })
    end
    changed()
    return true
end

-- A sign-up of the own call by name, or nil.
local function signupOf(name)
    local c = own()
    if not c then return nil end
    for i, s in ipairs(c.signups) do
        if ns.SameName(s.n, name) then return s, i end
    end
    return nil
end
GC.SignupOf = signupOf

-- Whether a guild member is online (true when the roster does not say).
local function online(name)
    local m = ns.GuildMember(name)
    if not m then return true end
    return m.online ~= false
end
GC.Online = online

---------------------------------------------------------------------------
-- Invites (the creator)
---------------------------------------------------------------------------
local REASON = { combat = L["Nicht im Kampf"], lock = L["Nicht im Bosskampf"], lead = L["Nur als Gruppenleiter"],
                 pvp = L["Nicht im Schlachtfeld"] }
GC.REASON = REASON

-- Why inviting is off now: a code and its text, or nil.
function GC.InviteBlocked()
    local why
    if inFight() then why = "combat"
    elseif ns.ChatLocked() or ns.AddOnRestricted(1) then why = "lock"
    elseif ns.InPvPInstance and ns.InPvPInstance() then why = "pvp"
    elseif IsInGroup() and not UnitIsGroupLeader("player") then why = "lead" end
    if why then return why, REASON[why] end
    return nil
end

local function pending()
    local n, t = 0, now()
    for low, at in pairs(invitedAt) do
        if t - at >= NO_ANSWER or ns.InMyGroup(low) then invitedAt[low] = nil else n = n + 1 end
    end
    return n
end

local function inviteUnit(name)
    local api = _G.C_PartyInfo
    local fn = type(api) == "table" and api.InviteUnit or rawget(_G, "InviteUnit")
    if type(fn) ~= "function" then return false end
    if not pcall(fn, name) then return false end
    invitedAt[name:lower()] = now()
    return true
end

-- Whether a sign-up waits for the answer to an own invite.
function GC.Invited(name)
    local at = invitedAt[tostring(name):lower()]
    return at ~= nil and now() - at < NO_ANSWER
end

-- Invites one sign-up: true, or nil and the reason (said in the chat by the page).
function GC.Invite(name)
    local s = signupOf(name)
    if not s then return nil, L["Nicht angemeldet."] end
    local _, why = GC.InviteBlocked()
    if why then return nil, why end
    if ns.InMyGroup(s.n) then return nil, L["%s ist schon in deiner Gruppe."]:format(s.n) end
    if not online(s.n) then return nil, L["%s ist offline."]:format(s.n) end
    local count = math.max(1, tonumber(ns.Plain(GetNumGroupMembers())) or 0)
    if not IsInRaid() and count + pending() >= PARTY then return nil, L["Die Gruppe ist voll. Mit \"Alle einladen\" wird sie ein Schlachtzug."] end
    if not inviteUnit(s.n) then return nil, L["Einladen ging nicht."] end
    ns.msg(L["Eingeladen: %s"]:format(s.n))
    changed()
    return true
end

-- Declines a sign-up: it leaves the list and cannot sign up to this call again.
function GC.Decline(name)
    local c = own()
    local s, i = signupOf(name)
    if not s then return nil end
    table.remove(c.signups, i)
    c.declined[s.n:lower()] = true
    ownChanged()
    return true
end

-- The names "Alle einladen" takes: sign-ups in order, not in the group, online, not invited, as many per
-- role as the role still needs.
function GC.InviteList()
    local c = own()
    if not c then return {} end
    local need, _, inGroup = ownCounts(c)
    local left = {}
    for _, r in ipairs(GC.ROLES) do left[r] = (need[r] or 0) - (inGroup[r] or 0) end
    for _, s in ipairs(c.signups) do
        if GC.Invited(s.n) and not ns.InMyGroup(s.n) then left[s.r] = left[s.r] - 1 end
    end
    local out = {}
    for _, s in ipairs(c.signups) do
        if left[s.r] > 0 and not ns.InMyGroup(s.n) and not GC.Invited(s.n) and online(s.n) then
            out[#out + 1] = s.n
            left[s.r] = left[s.r] - 1
        end
    end
    return out
end

local step
local function schedule(s)
    local token = (run.token or 0) + 1
    run.token = token
    C_Timer.After(s, function()
        if run and run.token == token then step() end
    end)
end

local function finish(why)
    local r = run
    run = nil
    if not r then return end
    if why then
        ns.msg(L["Einladen angehalten: %s."]:format(why))
    else
        ns.msg(L["Einladen: %d eingeladen."]:format(r.sent))
    end
    changed()
end

step = function()
    if not run then return end
    local _, why = GC.InviteBlocked()
    if why then return finish(why) end
    if now() - run.lastStep > RUN_IDLE then return finish(L["keine Antwort"]) end
    local count = math.max(1, tonumber(ns.Plain(GetNumGroupMembers())) or 0)
    local open = pending()
    if not IsInRaid() then
        if count + open + #run.queue > PARTY and count >= 2 then
            -- more than five: the group becomes a raid (the leader only, once someone joined)
            if not UnitIsGroupLeader("player") then return finish(REASON.lead) end
            if not run.converting then
                run.converting = now()
                local api = _G.C_PartyInfo
                local fn = type(api) == "table" and api.ConvertToRaid or rawget(_G, "ConvertToRaid")
                if type(fn) ~= "function" or not pcall(fn) then return finish(L["Umwandeln in einen Raid ging nicht"]) end
            elseif now() - run.converting > CONVERT_WAIT then
                return finish(L["Umwandeln in einen Raid ging nicht"])
            end
            return schedule(1)
        end
        if count + open >= PARTY then
            if #run.queue == 0 then return finish() end
            return schedule(1)
        end
    elseif count + open >= RAID_MAX then
        return finish(L["der Raid ist voll"])
    end
    local name
    while #run.queue > 0 do
        local n = table.remove(run.queue, 1)
        if signupOf(n) and not ns.InMyGroup(n) and not GC.Invited(n) and online(n) then name = n break end
    end
    if not name then return finish() end
    if inviteUnit(name) then run.sent = run.sent + 1 end
    run.lastStep = now()
    changed()
    schedule(INVITE_GAP)
end

-- "Alle einladen": true, or nil and the reason.
function GC.InviteAll()
    if not own() then return nil, L["Kein eigener Aufruf."] end
    local _, why = GC.InviteBlocked()
    if why then return nil, why end
    if run then return nil, L["Einladen läuft schon."] end
    local list = GC.InviteList()
    if #list == 0 then return nil, L["Niemand mehr einzuladen."] end
    run = { queue = list, sent = 0, lastStep = now() }
    step()
    return true
end

function GC.Running() return run ~= nil end

---------------------------------------------------------------------------
-- Signing up (another's call)
---------------------------------------------------------------------------
function GC.MySignup(low)
    local m = mine[tostring(low):lower()]
    local c = calls[tostring(low):lower()]
    if not m or not c or m.id ~= c.id then return nil end
    return m.role, joinOwed[tostring(low):lower()] ~= nil
end

local function ownLevel()
    local l = tonumber(ns.Plain(UnitLevel("player"))) or 1
    return math.max(1, math.min(99, math.floor(l)))
end

local function sendJoin(low)
    local j = joinOwed[low]
    if not j then return end
    if locked() or not ns.CommAvailable() then return end
    local key = low .. ":" .. j.id
    local wait = joinAt[key] and (joinAt[key] + JOIN_GAP - now()) or 0
    if wait > 0 then return end
    local fields = j.role and { j.id, j.role, tostring(j.level) } or { j.id, "-" }
    if ns.CommSend("EJ", fields, "WHISPER", j.to, { key = "EJ:" .. key, ttl = 60 }) then
        joinAt[key] = now()
        joinOwed[low] = nil
    end
end

-- Signs up to the call of the sender low with role ("T"/"H"/"S"); role nil withdraws. true, or nil and why.
function GC.SignUp(low, role)
    low = tostring(low or ""):lower()
    local c = calls[low]
    if not c then return nil, L["Der Aufruf ist nicht mehr da."] end
    if role ~= nil and not VALID_ROLE[role] then return nil, L["Wähle eine Rolle."] end
    if role and ownLevel() < c.min then return nil, L["Erst ab Stufe %d."]:format(c.min) end
    if role then mine[low] = { id = c.id, role = role, at = time() } else mine[low] = nil end
    joinOwed[low] = { id = c.id, role = role, level = ownLevel(), to = c.by }
    if locked() then
        ns.msg(role and L["Kampfsperre: Deine Anmeldung geht raus, sobald sie vorbei ist."]
            or L["Kampfsperre: Deine Abmeldung geht raus, sobald sie vorbei ist."])
    else
        sendJoin(low)
    end
    changed()
    return true
end
function GC.Withdraw(low) return GC.SignUp(low, nil) end

---------------------------------------------------------------------------
-- Others' calls
---------------------------------------------------------------------------
-- Others' calls, newest first, filtered by art ("all" or nil: every one).
function GC.List(art)
    local out = {}
    for _, c in pairs(calls) do
        if not art or art == "all" or c.art == art then out[#out + 1] = c end
    end
    table.sort(out, function(a, b)
        if a.created ~= b.created then return a.created > b.created end
        return a.low < b.low
    end)
    return out
end
function GC.Get(low) return calls[tostring(low or ""):lower()] end
function GC.Count() return ns.Count(calls) end

local focusClicks = 0          -- clicks on [Anmelden]: each one opens the list at its call again
function GC.Focus() return focus end
function GC.FocusClicks() return focusClicks end
function GC.SetFocus(low) focus = low and tostring(low):lower() or nil end

-- "Heiler, 2 Schaden": what a call still lacks.
function GC.MissingText(c)
    local need, _, inGroup = GC.Counts(c)
    local parts = {}
    for _, r in ipairs(GC.ROLES) do
        local n = (need[r] or 0) - (inGroup[r] or 0)
        if n == 1 then parts[#parts + 1] = GC.ROLE_NAMES[r] elseif n > 1 then parts[#parts + 1] = ROLE_PLURAL[r]:format(n) end
    end
    return table.concat(parts, ", ")
end

-- "Tank 1/1 · Heiler 0/1 · Schaden 2/3" (in the group of wanted).
function GC.RolesText(c)
    local need, _, inGroup = GC.Counts(c)
    local parts = {}
    for _, r in ipairs(GC.ROLES) do
        if (need[r] or 0) > 0 then parts[#parts + 1] = ("%s %d/%d"):format(GC.ROLE_NAMES[r], inGroup[r] or 0, need[r]) end
    end
    return table.concat(parts, " · ")
end

function GC.SignedCount(c)
    local _, signed = GC.Counts(c)
    return (signed.T or 0) + (signed.H or 0) + (signed.S or 0)
end

local LINK = "addon:Amisia:call:"
local LINK_COLOUR = "|cff4fb8ff"

-- The chat line of a new call: "Vulo sucht: Kloster - Kathedrale (ab 35), Heiler, 2 Schaden [Anmelden]".
function GC.ChatLine(c)
    local missing = GC.MissingText(c)
    local text = L["%s sucht: %s (ab %d)"]:format(ns.ClassColored(c.by, c.class), GC.Title(c), c.min)
    if missing ~= "" then text = text .. ", " .. missing end
    return text .. " " .. ("%s|H%s%s|h[%s]|h|r"):format(LINK_COLOUR, LINK, c.id, L["Anmelden##Aufruf"])
end

local function parseTriple(v)
    local t, h, s = v:match("^(%d+)/(%d+)/(%d+)$")
    return { T = tonumber(t), H = tonumber(h), S = tonumber(s) }
end

local function dropOldest()
    local oldest
    for _, c in pairs(calls) do
        if not oldest or c.heard < oldest.heard then oldest = c end
    end
    if oldest then calls[oldest.low] = nil end
end

local function take(name, f)
    local low = name:lower()
    local at = tonumber(f[7])
    local c = calls[low]
    local rev = tonumber(f[2])
    if c and c.id == f[1] and rev < c.rev then
        c.heard = now()
        return
    end
    local fresh = not c or c.id ~= f[1]
    if fresh then
        if at > 0 and at + LIFE < GetServerTime() then return end
        if not c and ns.Count(calls) >= MAX_CALLS then dropOldest() end
        local m = ns.GuildMember(name)
        c = { low = low, by = name, id = f[1], created = time(), class = m and m.class ~= "" and m.class or nil }
        calls[low] = c
        if mine[low] and mine[low].id ~= f[1] then mine[low] = nil end
    end
    c.rev, c.art, c.key = rev, f[3], f[4] ~= "-" and f[4] or nil
    -- another's call switched to "jetzt": its life counts from now here too
    if not fresh and at == 0 and (c.at or 0) > 0 then c.created = time() end
    c.title, c.min, c.at = f[5], tonumber(f[6]), at
    c.need, c.signed, c.inGroup = parseTriple(f[8]), parseTriple(f[9]), parseTriple(f[10])
    c.state, c.note = f[11], f[12] ~= "-" and f[12] or nil
    c.heard = now()
    local key = low .. ":" .. c.id
    if fresh and not announced[key] then
        announced[key] = true
        -- a new call id every 10 s would else put a line into every member's chat each time
        local t = now()
        if c.state == "O" and ns.Get("guildCalls.chat") ~= false and not (saidAt[low] and t - saidAt[low] < CHAT_GAP) then
            saidAt[low] = t
            ns.msg(GC.ChatLine(c))
        end
    end
    changed()
end

local function drop(low)
    if calls[low] then
        calls[low] = nil
        mine[low], joinOwed[low] = nil, nil
        if focus == low then focus = nil end
        changed()
    end
end

ns.CommOn("EA", function(sender, f, chan)
    if chan ~= "GUILD" and chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok then take(name, f) end
    end)
end)

ns.CommOn("EX", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        local c = ok and calls[name:lower()]
        if c and c.id == f[1] then drop(name:lower()) end
    end)
end)

-- A sign-up or withdrawal for the own call: only by whisper, only from a member, only for the sender itself.
ns.CommOn("EJ", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        local c = own()
        if not ok or not c or c.id ~= f[1] then return end
        local s, i = signupOf(name)
        if f[2] == "-" then
            if s then
                table.remove(c.signups, i)
                ownChanged()
            end
            return
        end
        if c.declined[name:lower()] then return end
        local level = tonumber(f[3])
        if s then
            if s.r == f[2] and s.l == level then return end
            s.r, s.l = f[2], level
        else
            if #c.signups >= MAX_SIGNUPS then return end
            local m = ns.GuildMember(name)
            c.signups[#c.signups + 1] = { n = name, r = f[2], l = level, c = m and m.class ~= "" and m.class or nil, t = time() }
        end
        ownChanged()
    end)
end)

-- The question after a login: only the own call, by whisper after 0 to 5 s.
ns.CommOn("EQ", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        local c = own()
        if not ok or not c or locked() then return end
        local fields = GC.Fields(c)
        if fields then ns.CommSend("EA", fields, "WHISPER", sender, { key = "EA:W:" .. name:lower(), jitter = 4.75, ttl = 60 }) end
    end)
end)

---------------------------------------------------------------------------
-- The clock: the heartbeat, the lockdown's waiting actions, the ends
---------------------------------------------------------------------------
local function tick()
    local t, server = now(), GetServerTime()
    local c = own()
    if c and server > GC.EndsAt(c) then
        GC.End(true)
        c = nil
    end
    if not locked() and ns.CommAvailable() then
        while #owedEX > 0 do
            local id = table.remove(owedEX, 1)
            if ns.InGuild() then ns.CommSend("EX", { id }, "GUILD", nil, { key = "EX:" .. id, ttl = 120 }) end
        end
        for low in pairs(joinOwed) do sendJoin(low) end
        if c then
            if lastDigest and digest(c) ~= lastDigest then ownChanged() end
            if (announceDue and t >= announceDue) or (lastEA and t - lastEA >= HEARTBEAT) then sendOwn() end
        end
    end
    for low, x in pairs(calls) do
        if t - x.heard > LOST or server > GC.EndsAt(x) then drop(low) end
    end
end
C_Timer.NewTicker(TICK, ns.Perf.Wrap("Ticker GuildCalls", tick))
GC.Tick = tick

-- The group changed: who is in it counts as "dabei" (a new revision when the counts changed).
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local c = own()
    if c and lastDigest and digest(c) ~= lastDigest then ownChanged() end
    if run then schedule(0.2) end
    changed()
end)

-- A fraction 0 to 1 of the own name and the clock: the spread after the login without math.random (the
-- other login timers keep the random numbers they had before this file).
local function spread()
    local n = math.floor((GetTime() or 0) * 1000)
    for i = 1, #(ns.UnitFullName("player") or "") do n = n + ns.UnitFullName("player"):byte(i) * i end
    return (n % 1000) / 1000
end

-- After the login (and a /reload): the question to the guild; the own call goes out again.
ns.OnEvent("PLAYER_LOGIN", function()
    local f = spread()
    C_Timer.After(ASK_AFTER + f * ASK_SPREAD, function()
        if not ns.InGuild() or not ns.CommAvailable() then return end
        ns.CommSend("EQ", { ("%04x"):format(math.floor((GetTime() or 0) * 1000) % 65536) }, "GUILD", nil,
            { key = "EQ", ttl = 120, low = true })
    end)
    if own() then
        lastDigest = nil
        announceDue = now() + REANNOUNCE_AFTER + f * 5
    end
end)

---------------------------------------------------------------------------
-- The chat link
---------------------------------------------------------------------------
-- A click on [Anmelden]: the page Aufrufe at that call.
function GC.OnLink(_, link)
    if type(link) ~= "string" or link:sub(1, #LINK) ~= LINK then return end
    local id = link:sub(#LINK + 1)
    for low, c in pairs(calls) do
        if c.id == id then focus = low end
    end
    focusClicks = focusClicks + 1
    if ns.ShowPage then ns.ShowPage("calls") end
end

do
    local reg = _G.EventRegistry
    if type(reg) == "table" and type(reg.RegisterCallback) == "function" then
        pcall(reg.RegisterCallback, reg, "SetItemRef", GC.OnLink, GC)
    end
end

---------------------------------------------------------------------------
-- On load: the saved own call checked, dropped 2 hours after its time
---------------------------------------------------------------------------
local function validName(v) return type(v) == "string" and v ~= "" and #v <= 48 and not v:find("[%c,:|%d]") end

function GC.Loaded(DB)
    local c = DB.guildCall
    if c == nil then return end
    local ok = type(c) == "table" and type(c.id) == "string" and #c.id == 4 and c.id:match("^%x+$")
        and VALID_ART[c.art] and type(c.title) == "string" and c.title ~= "" and not c.title:find("[%c|]") and #c.title <= TITLE_BYTES
        and ns.Int(c.min, 1, 99) and ns.Int(c.at, 0) and ns.Int(c.created, 1) and ns.Int(c.rev, 1, 999999) and type(c.need) == "table"
    if ok then
        local sum = 0
        for _, r in ipairs(GC.ROLES) do
            if not ns.Int(c.need[r], 0, 40) then ok = false break end
            sum = sum + c.need[r]
        end
        ok = ok and sum >= 1 and sum <= 40
    end
    if not ok or time() > base(c) + LIFE then
        DB.guildCall = nil
        return
    end
    c.v = 1
    if c.key ~= nil and not (type(c.key) == "string" and c.key:match("^[%w_]+$") and #c.key <= 24) then c.key = nil end
    if c.art ~= "D" then c.key = nil end
    if c.note ~= nil and not (type(c.note) == "string" and c.note ~= "" and not c.note:find("[%c|]") and #c.note <= NOTE_BYTES) then c.note = nil end
    local keep = {}
    for _, s in ipairs(type(c.signups) == "table" and c.signups or {}) do
        if #keep < MAX_SIGNUPS and type(s) == "table" and validName(s.n) and VALID_ROLE[s.r] then
            if not ns.Int(s.l, 1, 99) then s.l = nil end
            if type(s.c) ~= "string" or not s.c:match("^%u+$") then s.c = nil end
            if not ns.Int(s.t, 1) then s.t = nil end
            keep[#keep + 1] = s
        end
    end
    c.signups = keep
    local declined = {}
    for k, v in pairs(type(c.declined) == "table" and c.declined or {}) do
        if v == true and validName(k) then declined[k] = true end
    end
    c.declined = declined
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then GC.Loaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Setting
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "guildCalls", label = L["Aufrufe"], order = 61, group = "guild", pages = { "calls" }, items = {
    { key = "guildCalls.chat", type = "toggle", label = L["Neue Aufrufe der Gilde im Chat melden"], default = true,
      tip = L["Eine Zeile mit [Anmelden], wenn ein Gildenmitglied einen Aufruf einstellt; einmal je Aufruf."] },
} }
end)
