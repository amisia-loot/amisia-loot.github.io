-- Amisia lineup, part C (F-084, D-41): "Alle einladen" invites the placed players of a raid night
-- who are online and not in the group yet, from a timer, one every GAP seconds (InviteUnit works
-- from a timer, check 11 of the spec, 2026-10-12). Alone or in a party Amisia invites the first
-- ones up to five in the group, converts the group into a raid as soon as the first has joined and
-- invites the rest. The status of every name comes from the client's system messages (read through
-- its templates, never German text) and the group roster: geplant, eingeladen, im Raid, abgelehnt,
-- keine Antwort (90 s), schon in Gruppe, offline, unbekannt. "Nochmal einladen" invites the declined,
-- the unanswered and those in another group again, once per click; at most three invites per name
-- and night. Optional, off by default: a whisper with a fixed text to each invited player, once per
-- name and night. Guests only with lineup.guests. Never in combat, the lockdown or a battleground;
-- in a group only as leader or assistant (a party: the leader); only for tonight's night.
-- Invite on whisper (lineup.inv, off by default; user 2026-10-12): a whisper "inv" or "invite" (the
-- whole text, any case) from a guild member (by the roster; a guest of tonight's lineup only with
-- lineup.guests) is invited while a recording runs or tonight has a lineup, by the same engine; one
-- per sender every INV_GAP seconds, INV_PER_MIN a minute; lines only in the own chat.
-- The states live in memory only (D-41: never saved); a /reload rebuilds them from the roster.
local ADDON, ns = ...
local L = ns.L

local GAP = 0.5            -- seconds between two invites
local PARTY = 5            -- places of a party; the first invites fill it, then the raid comes
local RAID_MAX = 40
local NO_ANSWER = 90       -- seconds until an unanswered invite is "keine Antwort"
local MAX_TRIES = 3        -- invites per name and night (click, "Nochmal", whisper together)
local CONVERT_WAIT = 10    -- seconds the run waits for the raid after ConvertToRaid
local INV_GAP = 30         -- whisper "inv": one per sender in this many seconds
local INV_PER_MIN = 10     -- and this many a minute in all
local INV_WORDS = { inv = true, invite = true }
-- the system messages the status reads: template global -> status (nil: no name in it)
local MESSAGES = {
    { "ERR_INVITE_PLAYER_S", "I" }, { "ERR_DECLINE_GROUP_S", "D" }, { "ERR_ALREADY_IN_GROUP_S", "G" },
    { "ERR_BAD_PLAYER_NAME_S", "U" }, { "ERR_JOINED_GROUP_S", "R" }, { "ERR_RAID_MEMBER_ADDED_S", "R" },
}
-- statuses: P geplant, I eingeladen, R im Raid, D abgelehnt, N keine Antwort, G schon in Gruppe,
-- O offline, U unbekannt (the server found nobody, or the name is unclear in the lineup)
local AGAIN = { D = true, N = true, G = true }

local IV = {}
ns.LineupInv = IV
IV.MAX_TRIES, IV.NO_ANSWER, IV.GAP = MAX_TRIES, NO_ANSWER, GAP

local nights = {}          -- [night] = { [lower name] = { n, st, at, tries, whispered, back, by } }
local started = {}         -- [night] = true: this client clicked "Alle einladen" (auto sort follows it)
local run                  -- the invite run: { night, queue = { name }, quiet, sent, converting }
local ticker               -- the answer timeout while invites wait

local function tonight() return ns.LineupTonight() end

local function rec(night, name, create)
    local t = nights[night]
    if not t then
        if not create then return nil end
        t = {}
        nights[night] = t
    end
    local low = name:lower()
    local r = t[low]
    if not r and create then
        r = { n = name, st = "P", tries = 0 }
        t[low] = r
    end
    return r
end

---------------------------------------------------------------------------
-- Who may, and when
---------------------------------------------------------------------------
local function restrictionOn(kind)
    local api = _G.C_RestrictedActions
    local fn = type(api) == "table" and api.IsAddOnRestrictionActive
    if type(fn) ~= "function" then return false end
    local ok, on = pcall(fn, kind)
    return ok and ns.Plain(on) == true
end

local function homeRaid()
    if _G.LE_PARTY_CATEGORY_HOME then return IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false end
    return IsInRaid() and true or false
end
IV.HomeRaid = homeRaid

local function battleground()
    if _G.LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return true
    end
    if type(IsInInstance) ~= "function" then return false end
    local _, kind = IsInInstance()
    kind = ns.Plain(kind)
    return kind == "pvp" or kind == "arena"
end

-- Combat or the lockdown of a boss fight: "combat", "lock" or nil.
function IV.Fight()
    if InCombatLockdown() or restrictionOn(0) then return "combat" end
    if ns.ChatLocked() or restrictionOn(1) then return "lock" end
    return nil
end

local REASON = {
    officer = L["Nur für Offiziere"], combat = L["Nicht im Kampf"], lock = L["Nicht im Bosskampf"],
    pvp = L["Nicht im Schlachtfeld"], raid = L["Nur im Raid"], lead = L["Nur als Leiter oder Assistent"],
    night = L["Nur für heute Abend"],
}
IV.REASON = REASON

-- Why the lead's tools (invite, convert, sort) are off now: a code and its text, or nil. needRaid:
-- sorting needs a raid. In a raid the leader or an assistant; in a party only the leader.
function ns.LineupLeadBlocked(needRaid)
    local why
    if not ns.LineupAllowed() then
        why = "officer"
    else
        why = IV.Fight()
        if not why and battleground() then why = "pvp" end
        if not why and needRaid and not homeRaid() then why = "raid" end
        if not why and IsInGroup() and not (UnitIsGroupLeader("player") or (homeRaid() and UnitIsGroupAssistant("player"))) then
            why = "lead"
        end
    end
    if why then return why, REASON[why] end
    return nil
end

-- Why the invite buttons of night are off: ns.LineupLeadBlocked, else "night" for any night but
-- tonight's (review 2026-10-13: next week's lineup is not invited now).
function ns.LineupInviteBlocked(night)
    local why, text = ns.LineupLeadBlocked()
    if why then return why, text end
    if (night or tonight()) ~= tonight() then return "night", REASON.night end
    return nil
end

---------------------------------------------------------------------------
-- The statuses: the roster and the guild say who is in the raid and who is online
---------------------------------------------------------------------------
local function groupSet()
    local out = {}
    for _, n in ipairs(ns.GroupRoster()) do out[n:lower()] = n end
    return out
end

local function inSet(set, name)
    if set[name:lower()] then return true end
    local list = {}
    for _, n in pairs(set) do list[#list + 1] = n end
    for _, n in ipairs(list) do
        if ns.SameNameIn(name, n, list) then return true end
    end
    return false
end

local function isMe(name) return ns.SameName(name, ns.UnitFullName("player")) end

-- The placed players of a night (in a group, not absent, not on the bench), group by group.
local function placed(n)
    local out = {}
    for i, e in ipairs(n and n.list or {}) do
        if e.g and not e.a and not e.b and not e.v then out[#out + 1] = { e = e, i = i } end
    end
    table.sort(out, function(a, b)
        if a.e.g ~= b.e.g then return a.e.g < b.e.g end
        return a.i < b.i
    end)
    return out
end

-- Brings the statuses of night up to date: in the group "im Raid" (one who left: "geplant"),
-- offline "offline" (online again: "geplant", marked back), an unclear name "unbekannt". Returns
-- the names that just joined and fires LINEUP_JOINED for them itself: the page's refresh reads the
-- roster too and may see a join before the roster event does (review 2026-10-13).
local function sync(night)
    -- in the lockdown the roster's names are secret: nobody would seem in the raid
    if IV.Fight() == "lock" then return {} end
    local n = ns.LineupNight(night, false)
    local group = groupSet()
    local people = ns.LineupPeople()
    local joined = {}
    for _, it in ipairs(placed(n)) do
        local e = it.e
        local r = rec(night, e.n, true)
        local p = people[e.n:lower()]
        if isMe(e.n) or inSet(group, e.n) then
            -- joined: new in the roster (the system message may have said "im Raid" first)
            if not r.inGroup and not isMe(e.n) then joined[#joined + 1] = e.n end
            r.st, r.back, r.inGroup = "R", nil, true
        elseif r.st == "R" then
            r.st, r.inGroup = "P", nil
        elseif e.x and e.x ~= "g" then
            -- an unclear name is not invited until the officer clears it up
            if r.st == "P" or r.st == "O" then r.st, r.unclear = "U", true end
        elseif r.unclear then
            r.st, r.unclear = "P", nil
        elseif p and not p.online then
            if r.st == "P" or r.st == "U" then r.st = "O" end
        elseif r.st == "O" and p and p.online then
            r.st, r.back = "P", true
        end
    end
    -- whisper invites of tonight that are not on the lineup
    for _, r in pairs(nights[night] or {}) do
        if r.by == "inv" and not r.inGroup and inSet(group, r.n) then
            r.st, r.inGroup = "R", true
            joined[#joined + 1] = r.n
        end
    end
    if #joined > 0 then ns.Fire("LINEUP_JOINED", night, joined) end
    return joined
end

-- The statuses of night for the page: { [lower name] = { n, st, at, tries, back } } (a copy is not
-- needed: the page only reads).
function ns.LineupInviteStates(night)
    night = night or tonight()
    sync(night)
    return nights[night] or {}
end

-- Whether this client clicked "Alle einladen" for night in this session (auto sort follows it).
function ns.LineupInviteStarted(night) return started[night or tonight()] == true end

function ns.LineupInviteRunning() return run ~= nil and not run.quiet end

-- What the buttons count: those to invite now, those for "Nochmal einladen".
function ns.LineupInviteCounts(night)
    night = night or tonight()
    sync(night)
    local c = { todo = 0, again = 0, P = 0, I = 0, R = 0, D = 0, N = 0, G = 0, O = 0, U = 0 }
    local n = ns.LineupNight(night, false)
    for _, it in ipairs(placed(n)) do
        local r = rec(night, it.e.n, true)
        c[r.st] = (c[r.st] or 0) + 1
        local guestOk = it.e.x ~= "g" or ns.Get("lineup.guests") == true
        if guestOk and r.tries < MAX_TRIES then
            if r.st == "P" then c.todo = c.todo + 1 end
            if AGAIN[r.st] then c.again = c.again + 1 end
        end
    end
    return c
end

---------------------------------------------------------------------------
-- The run: one invite every GAP seconds, the raid after the first join
---------------------------------------------------------------------------
local function pending()
    local c = 0
    for _, r in pairs(nights[run and run.night or tonight()] or {}) do
        if r.st == "I" then c = c + 1 end
    end
    return c
end

local function changed() ns.Fire("LINEUP_INVITE") end

local function timeouts()
    local now, waiting = GetTime(), false
    for _, t in pairs(nights) do
        for _, r in pairs(t) do
            if r.st == "I" then
                if now - (r.at or now) >= NO_ANSWER then
                    r.st = "N"
                    changed()
                else
                    waiting = true
                end
            end
        end
    end
    if not waiting and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function watchAnswers()
    if not ticker then ticker = C_Timer.NewTicker(1, timeouts) end
end

local lastInvited          -- the record of the newest invite (ERR_GROUP_FULL names nobody)
local lastInvitedAt        -- and when Amisia sent it: ERR_GROUP_FULL counts only within FULL_PIN s
local FULL_PIN = 3

local function invite(night, name, group)
    local r = rec(night, name, true)
    local api = _G.C_PartyInfo
    local fn = type(api) == "table" and api.InviteUnit or _G.InviteUnit
    if type(fn) ~= "function" then return false end
    r.tries = r.tries + 1
    r.st, r.at, r.back, r.unclear = "I", GetTime(), nil, nil
    lastInvited, lastInvitedAt = r, GetTime()
    local ok = pcall(fn, name)
    if not ok then
        r.st = "P"
        return false
    end
    watchAnswers()
    -- the optional whisper: a fixed text, only the group changes; once per name and night
    if ns.Get("lineup.whisper") and not r.whispered and group then
        r.whispered = true
        ns.Say(L["Amisia: Einladung zum Raid (Gruppe %d). Bitte annehmen."]:format(group), "WHISPER", name, { ttl = 30 })
    end
    return true
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
    elseif not r.quiet then
        ns.msg(L["Einladen: %d eingeladen."]:format(r.sent))
    end
    changed()
end

-- The places left now: in a raid up to 40, in a party or alone up to five (with the invites that
-- wait for an answer).
local function members()
    local n = tonumber(ns.Plain(GetNumGroupMembers())) or 0
    return math.max(n, 1)
end

step = function()
    if not run then return end
    local why, text = ns.LineupLeadBlocked()
    if why then return finish(text) end
    -- never faster than one invite every GAP seconds (a roster update calls early)
    local wait = run.lastAt and (GAP - (GetTime() - run.lastAt)) or 0
    if wait > 0.001 then return schedule(wait) end
    local count = members()
    if not homeRaid() then
        local need = count + pending() + #run.queue > PARTY
        if need and count >= 2 then
            -- the first has joined: the group becomes a raid (the leader only)
            if not UnitIsGroupLeader("player") then return finish(REASON.lead) end
            if not run.converting then
                run.converting = GetTime()
                local api = _G.C_PartyInfo
                local fn = type(api) == "table" and api.ConvertToRaid or _G.ConvertToRaid
                if type(fn) ~= "function" or not pcall(fn) then return finish(L["Umwandeln in einen Raid ging nicht"]) end
            elseif GetTime() - run.converting > CONVERT_WAIT then
                return finish(L["Umwandeln in einen Raid ging nicht"])
            end
            return schedule(1)
        end
        if count + pending() >= PARTY then
            -- the party is full of invites: wait for an answer
            if #run.queue == 0 then return finish() end
            return schedule(1)
        end
    elseif count + pending() >= RAID_MAX then
        return finish(L["der Raid ist voll"])
    end
    -- the next name that may still be invited
    local item
    while #run.queue > 0 do
        local it = table.remove(run.queue, 1)
        local r = rec(run.night, it.n, true)
        if not inSet(groupSet(), it.n) and r.tries < MAX_TRIES and r.st ~= "I" and r.st ~= "R" then
            item = it
            break
        end
    end
    -- nobody left: the run ends, the answers still come in
    if not item then return finish() end
    if invite(run.night, item.n, item.g) then run.sent = run.sent + 1 end
    run.lastAt = GetTime()
    changed()
    schedule(GAP)
end

-- Adds names to the run (a new one starts): items = { { n = name, g = group } }.
local function enqueue(night, items, quiet)
    if run and run.night ~= night then return false end
    if not run then
        run = { night = night, queue = {}, quiet = quiet, sent = 0 }
        for _, it in ipairs(items) do run.queue[#run.queue + 1] = it end
        schedule(0)
    else
        for _, it in ipairs(items) do run.queue[#run.queue + 1] = it end
        if not quiet then run.quiet = false end
    end
    return true
end

-- The names a click invites: "all" those planned and online, "again" the declined, unanswered and
-- those in another group; under three invites each; guests only with lineup.guests.
local function pick(night, which)
    sync(night)
    local items = {}
    local guests = ns.Get("lineup.guests") == true
    for _, it in ipairs(placed(ns.LineupNight(night, false))) do
        local e = it.e
        local r = rec(night, e.n, true)
        local ok = (e.x == nil or (e.x == "g" and guests)) and r.tries < MAX_TRIES and not isMe(e.n)
        if ok and ((which == "all" and r.st == "P") or (which == "again" and AGAIN[r.st])) then
            items[#items + 1] = { n = e.n, g = e.g }
        end
    end
    return items
end

-- "Alle einladen" (which "all") and "Nochmal einladen" (which "again") for night (tonight). Returns
-- the number queued, or nil and the reason (also said in the chat by the caller).
function ns.LineupInvite(night, which)
    night = night or tonight()
    local _, text = ns.LineupInviteBlocked(night)
    if text then return nil, text end
    if run and not run.quiet then return nil, L["Einladen läuft schon"] end
    local items = pick(night, which or "all")
    if #items == 0 then return nil, L["Niemand einzuladen"] end
    if run and run.night ~= night then return nil, L["Einladen läuft schon"] end
    started[night] = true
    enqueue(night, items, false)
    return #items
end

function ns.LineupInviteAll(night) return ns.LineupInvite(night, "all") end

-- One name by its row's chip (a click): counts as an invite of that name.
function ns.LineupInviteOne(night, name)
    night = night or tonight()
    local _, text = ns.LineupInviteBlocked(night)
    if text then return nil, text end
    local n = ns.LineupNight(night, false)
    for _, it in ipairs(placed(n)) do
        if it.e.n:lower() == tostring(name):lower() then
            local r = rec(night, it.e.n, true)
            if r.tries >= MAX_TRIES then return nil, L["Höchstens %d Einladungen pro Name und Abend"]:format(MAX_TRIES) end
            if it.e.x == "g" and not ns.Get("lineup.guests") then return nil, L["Gäste nur mit der Einstellung \"Gäste einladen\"."] end
            if r.st == "R" or r.st == "I" then return nil end
            if r.st == "O" then return nil, L["%s ist offline."]:format(it.e.n) end
            started[night] = true
            if not enqueue(night, { { n = it.e.n, g = it.e.g } }, false) then return nil, L["Einladen läuft schon"] end
            return 1
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The answers: system messages (read through the client's templates) and the roster
---------------------------------------------------------------------------
-- The record a captured name means: the same spelling, else a first name only one tracked name
-- of the night carries; the own realm's ending dropped.
local function recByMessage(night, raw)
    local t = nights[night]
    local name = ns.TemplateName(raw)
    if not t or not name then return nil end
    local function find(x)
        if t[x:lower()] then return t[x:lower()] end
        local list = {}
        for _, r in pairs(t) do list[#list + 1] = r.n end
        local hit
        for _, n in ipairs(list) do
            if ns.SameNameIn(x, n, list) then
                if hit then return nil end
                hit = t[n:lower()]
            end
        end
        return hit
    end
    local r = find(name)
    if not r then
        local base = ns.StripOwnRealm(name)
        if base then r = find(base) end
    end
    return r
end

-- the patterns of the templates, made once per template text
local patterns = {}
local function pattern(global)
    local t = ns.Plain(rawget(_G, global))
    if type(t) ~= "string" then return nil end
    local p = patterns[t]
    if p == nil then
        p = ns.TemplatePattern(t) or false
        patterns[t] = p
    end
    return p or nil
end

ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    -- a secret message (the lockdown) is skipped; the roster tells the rest later
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local night = run and run.night or tonight()
    if not nights[night] then return end
    local full = pattern("ERR_GROUP_FULL")
    if full and text:find(full) then
        -- the newest invite did not go out: back to "geplant", the invite not counted; only within
        -- FULL_PIN seconds of Amisia's invite (later it answers the officer's own invite, review
        -- 2026-10-13)
        local r = lastInvited
        if r and r.st == "I" and lastInvitedAt and GetTime() - lastInvitedAt < FULL_PIN then
            r.st, r.tries = "P", math.max(0, r.tries - 1)
            -- the run stops: a full raid (or a party that is no raid yet) takes nobody more
            if run then finish(L["die Gruppe ist voll"]) end
            changed()
        end
        return
    end
    for _, m in ipairs(MESSAGES) do
        local p = pattern(m[1])
        local cap = p and text:match(p)
        if cap then
            local r = recByMessage(night, cap)
            if r then
                if m[2] == "I" then
                    if r.st == "I" then r.at = GetTime() end
                elseif m[2] == "R" or r.st == "I" then
                    -- an answer only to a waiting invite; a join always
                    r.st = m[2]
                end
                changed()
            end
            return
        end
    end
end)

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local night = run and run.night or tonight()
    if not nights[night] then return end
    local joined = sync(night)
    if #joined > 0 then changed() end
    -- the run waits for a join or the raid: go on now
    if run and (run.converting or pending() > 0) then
        if run.converting and homeRaid() then run.converting = nil end
        schedule(0.2)
    end
end)

-- A fight starts: a run stops (no invite, no convert in combat); a new click goes on.
ns.OnEvent("PLAYER_REGEN_DISABLED", function()
    if run then finish(REASON.combat) end
    changed()
end)
ns.OnEvent("PLAYER_REGEN_ENABLED", changed)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function() C_Timer.After(0, changed) end)

---------------------------------------------------------------------------
-- Invite on whisper "inv"
---------------------------------------------------------------------------
local invLast, invTimes = {}, {}

local function invGate(key)
    local t = GetTime()
    if invLast[key] and t - invLast[key] < INV_GAP then return false end
    local keep = {}
    for _, at in ipairs(invTimes) do
        if t - at < 60 then keep[#keep + 1] = at end
    end
    invTimes = keep
    if #keep >= INV_PER_MIN then return false end
    for k, at in pairs(invLast) do
        if t - at >= INV_GAP then invLast[k] = nil end
    end
    invLast[key] = t
    invTimes[#invTimes + 1] = t
    return true
end

-- A guest of tonight's lineup (x "g"): invited on a whisper only with lineup.guests.
local function lineupGuest(night, name)
    if not ns.Get("lineup.guests") then return nil end
    local n = ns.LineupNight(night, false)
    for _, e in ipairs(n and n.list or {}) do
        if e.x == "g" and not e.a and ns.SameName(e.n, name) then return e end
    end
    return nil
end

-- Whether a whisper invite may run now: the setting, the officer, a night that is on.
local function invOn()
    if not ns.Get("lineup.inv") or not ns.LineupAllowed() then return false end
    if ns.Active and ns.Active() then return true end
    local n = ns.LineupNight(tonight(), false)
    return n ~= nil and #n.list > 0
end

local function invTake(night, name)
    if ns.LineupLeadBlocked() then return end
    if inSet(groupSet(), name) then return end
    local onLineup = false
    for _, it in ipairs(placed(ns.LineupNight(night, false))) do
        if it.e.n:lower() == name:lower() then onLineup = true end
    end
    local r = rec(night, name, true)
    if not onLineup then r.by = "inv" end
    if r.tries >= MAX_TRIES then
        ns.msg(L["Einladen auf Flüstern: %s hat schon %d Einladungen heute."]:format(name, MAX_TRIES))
        return
    end
    if r.st == "I" then return end
    if enqueue(night, { { n = name } }, true) then
        ns.msg(L["Einladen auf Flüstern: %s wird eingeladen."]:format(name))
    end
end

-- The whisper itself: the whole text "inv" or "invite"; secret whispers (the lockdown) are skipped.
function IV.Whisper(text, sender)
    text, sender = ns.Plain(text), ns.Plain(sender)
    if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    local word = text:match("^%s*(%S+)%s*$")
    if not word or not INV_WORDS[word:lower()] then return end
    if not invOn() or ns.LineupLeadBlocked() then return end
    local name = ns.TrustName(sender) or ns.StripOwnRealm(sender) or ns.FullName(sender)
    if not name or isMe(name) then return end
    if not invGate(name:lower()) then return end
    local night = tonight()
    ns.TrustWait(name, "member", function(member)
        -- the roster may have taken a while: the setting and the night again
        if not invOn() then return end
        -- a member under exactly this spelling, invited as the roster writes it: a first name alone
        -- (ns.GuildMember's match when one side has no surname) is the one ns.TrustName found unclear
        -- (review 2026-10-13)
        local m = member and ns.GuildMember(name) or nil
        if m and m.name:lower() == name:lower() then return invTake(night, m.name) end
        local guest = lineupGuest(night, name)
        if guest then return invTake(night, guest.n) end
        ns.msg(L["Einladen auf Flüstern: %s ist nicht in der Gilde, nicht eingeladen."]:format(name))
    end)
end
ns.OnEvent("CHAT_MSG_WHISPER", function(text, sender) IV.Whisper(text, sender) end)

-- for the tests and the scene
IV._reset = function()
    nights, started, run, lastInvited, lastInvitedAt = {}, {}, nil, nil, nil
    invLast, invTimes = {}, {}
    if ticker then ticker:Cancel() ticker = nil end
end
IV._set = function(night, name, st, tries)
    local r = rec(night or tonight(), name, true)
    r.st, r.tries, r.at = st, tries or r.tries, GetTime()
end
IV._run = function() return run end
