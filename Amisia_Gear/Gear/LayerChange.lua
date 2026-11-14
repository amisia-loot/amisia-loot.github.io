-- Changing the layer (F-185, D-117; beyond the guild F-191, D-124; ns.LayerChange). Amisia's own
-- messages (prefix of Core/Comm.lua) go between guild members with Amisia only; players outside the
-- guild are reached through the plain chat line alone (part 7 below).
-- Asker: "Gilde fragen" (SW.Ask; alone, not in a group, not in an instance, a fresh current layer of
-- Gear/Layer.lua, once in ASK_GAP) sends YQ to GUILD (zone map, own zoneUID, request id). A member on
-- the same map with a fresh, other layer, out of an instance, able to invite (no group, or leader or
-- assistant with room) and layer.answer on whispers YA (request id, map, own zoneUID) 0-2 s later; the
-- asker lists the answers (SW.Answers; the guild's ids also go to Layer.Heard, so letters agree) and
-- "Einladung erbitten" (SW.RequestInvite) whispers YI to that member. The member (only for an asker it
-- answered within REQ_LIFE, the same request and the own layer unchanged) asks "... Einladen?" (W.Confirm)
-- or with layer.autoInvite invites at once out of combat (SW.Invite: C_PartyInfo.InviteUnit, else
-- InviteUnit; never in an instance, not the same player within INVITE_GAP, INVITE_MAX in INVITE_WINDOW).
-- The asker accepts with layer.autoAccept exactly the invite of the member asked within ACCEPT_WAIT
-- (AcceptGroup, the client's window "PARTY_INVITE" hidden); every other invite stays the client's.
-- Once in that group (the swap): the layer reaching the host's zoneUID says "Gewechselt: Layer C";
-- "Gruppe verlassen" (SW.Leave) and, with layer.autoLeave, leaving by itself after layer.leaveSeconds,
-- only while the group is exactly the two of them, never in an instance. After CHANGE_WAIT without a
-- change: "Kein Wechsel". The host changes nothing in its group but the invite. Fires LAYER_CHANGE.
-- Part 6, the plain chat convention of other layer addons (D-117): a short guild chat line or whisper of a
-- guild member that looks like a layer request (SW.IsRequestLine: "inv layer", "layer 1,3", ...; numbers
-- ignored) is handled like a YI (layer.chat): the same question or automatic invite and the same limits;
-- the member's zone from the guild roster must be the own zone text (unknown: only the question). One
-- question or invite per member within DEDUPE seconds, whichever came first. The asker's "Im Gildenchat
-- fragen" (SW.AskChat) opens the chat box with "/g <layer.chatText>" for the player to send; for 60 s
-- after it, an invite of any guild member counts as the swap (accepted with layer.autoAccept).
-- Part 7, players outside the guild (F-191, D-124), by the same chat line only. Host, with layer.others
-- (off by default): a request line whispered by anyone or written into a chat channel the player is in
-- (CHAT_MSG_CHANNEL) gets the question "... (nicht in der Gilde) ... Einladen?", one question for
-- strangers in OTHERS_GAP seconds, the same invite limits; with layer.othersAuto the invite goes without
-- the question, but only for a line in a channel of the own zone (ZONE_CHANNELS: General, LocalDefense),
-- where the asker stands in the same zone. A guild member's line in a channel is handled as in the guild
-- chat. Asker: "Im Kanal fragen" (SW.AskChannel) opens the chat box with "/<layer.channel> <layer.chatText>";
-- for ACCEPT_WAIT seconds the next invite, whoever sends it, counts as the swap. Without layer.others no
-- channel line is looked at. Say and yell are never read; another addon's hidden messages never.
-- Who is asking itself (asking()) hosts nobody; a channel line never waits for the roster; nothing is
-- accepted inside an instance; a second player's invite replaces the first one's that was not taken.
-- SW.Trace(): what this session's invites, accepts and leaves did (tried, blocked by the client, joined)
-- and how the swaps ended, for /amisia selbsttest layer (Core/SelfTestLayer.lua).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local SW = {}
ns.LayerChange = SW
local LY = ns.Layer

SW.ASK_GAP = 10          -- seconds between two own questions
SW.ANSWER_WAIT = 10      -- seconds the window waits before "no answer"
SW.REQ_LIFE = 60         -- seconds an answer and a request for an invite stay good
SW.MAX_ANSWERS = 20
SW.INVITE_GAP = 60       -- the same player is invited once in this many seconds
SW.INVITE_MAX, SW.INVITE_WINDOW = 6, 600
SW.ACCEPT_WAIT = 60      -- seconds the asked member's invite is accepted by itself
SW.CHANGE_WAIT = 60      -- seconds after joining before "Kein Wechsel"
SW.REQUEST_GAP = 10      -- seconds between two own requests for an invite
local MAX_ANSWERED = 50
SW.DEDUPE = 10          -- seconds in which a chat line and a YI of one member make one question or invite
SW.CHAT_MAX = 40        -- characters of a chat request line at most
SW.OTHERS_GAP = 5       -- seconds between two questions or invites for players outside the guild
SW.TRACE_WAIT = 2       -- seconds after a call in which the client's "blocked" event counts for it
SW.JOIN_WAIT = 120      -- seconds after an invite in which the invited joining counts for it
local ZONE_CHANNELS = { [1] = true, [22] = true }   -- the client's zone channels: General, LocalDefense
local MAX_LINE_KEYS = 8
local INVITE_WORDS = { inv = true, invite = true, einladen = true, pls = true, bitte = true }
local QUESTION_WORDS = { which = true, what = true, welcher = true, wer = true, wo = true }

local req        -- the own open question: { id, map, uid, at, answers = { { name, uid, at } } }
local pending    -- the own request for an invite: { name, uid, map, from, at, invited }
local swap       -- the group formed by the request: { host, map, from, target, at, changed, failed, unknown }
local answered = {}   -- host: [lower name] = { id, map, uid, at }
local invited = {}    -- host: { { low, at } } the invites sent
local offered = {}    -- host: [lower name] = time of the last question or invite for that member
local chatAt         -- asker: time of the own "Im Gildenchat fragen" or "Im Kanal fragen"
local chatAll        -- asker: the request went to a channel, so anyone's invite counts
local othersAt       -- host: time of the last question or invite for a player outside the guild
local lastCall       -- { kind = "invite"|"accept"|"leave", at }: the newest call the client may block

local function newTrace()
    return { invite = { tried = 0, blocked = 0, joined = 0 }, accept = { tried = 0, blocked = 0, joined = 0 },
        leave = { tried = 0, blocked = 0, left = 0 }, changed = 0, failed = 0, unknown = 0, lines = {} }
end
local trace = newTrace()

local function now() return GetTime() end

local function inGroup()
    local f = rawget(_G, "IsInGroup")
    return type(f) == "function" and f() and true or false
end

local function members()
    local f = rawget(_G, "GetNumGroupMembers")
    return type(f) == "function" and tonumber(ns.Plain(f())) or 0
end

local function inRaid()
    local f = rawget(_G, "IsInRaid")
    return type(f) == "function" and f() and true or false
end

local function inCombat()
    local f = rawget(_G, "InCombatLockdown")
    return type(f) == "function" and f() and true or false
end

local function unitFlag(name, unit)
    local f = rawget(_G, name)
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f, unit)
    return ok and ns.Plain(v) == true
end

-- Whether the own character may invite now: no group, or leader or assistant with room.
function SW.CanInvite()
    if not inGroup() then return true end
    if not unitFlag("UnitIsGroupLeader", "player") and not unitFlag("UnitIsGroupAssistant", "player") then return false end
    return members() < (inRaid() and 40 or 5)
end

-- The name the guild would write for an invite's sender: the own realm's ending dropped.
local function nameOf(raw)
    raw = ns.Plain(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    return ns.StripOwnRealm(raw) or ns.FullName(raw)
end

local function changed() ns.Fire("LAYER_CHANGE") end

-- The trace: a call that the client may block is about to go.
local function tried(kind)
    trace[kind].tried = trace[kind].tried + 1
    lastCall = { kind = kind, at = now() }
end

-- The client blocked an action of Amisia: it counts for the call made just before.
local function blockedEvent(who, what)
    if not ns.OwnAddon(ns.Plain(who)) or not lastCall or now() - lastCall.at > SW.TRACE_WAIT then return end
    local c = trace[lastCall.kind]
    c.blocked = c.blocked + 1
    what = ns.Plain(what)
    c.what = type(what) == "string" and what:sub(1, 60) or nil
    lastCall = nil
end
ns.OnEvent("ADDON_ACTION_BLOCKED", blockedEvent)
ns.OnEvent("ADDON_ACTION_FORBIDDEN", blockedEvent)

function SW.Trace() return trace end
-- The layer probe makes such calls itself: a block of one of them is not the swap's.
function SW.ForgetCall() lastCall = nil end

---------------------------------------------------------------------------
-- Asking
---------------------------------------------------------------------------
-- Whether "Gilde fragen" can go now: true, or nil and the reason.
function SW.CanAsk()
    if not (ns.CommReady and ns.CommReady()) then return nil, L["Addon-Nachrichten sind gerade nicht verfügbar."] end
    if not ns.InGuild() then return nil, L["Du bist in keiner Gilde."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    if not LY.Fresh() then return nil, L["Layer unbekannt: ziele oder überfahre erst einen NPC."] end
    if req and now() - req.at < SW.ASK_GAP then return nil, L["Einmal alle 10 Sekunden."] end
    return true
end

-- "Gilde fragen": one YQ to the guild. Returns true, or nil and the reason.
function SW.Ask()
    local ok, why = SW.CanAsk()
    if not ok then return nil, why end
    local uid, map = LY.Current()
    local id = ("%04x"):format(math.random(0, 65535))
    local sent, err = ns.CommSend("YQ", { map, uid, id }, "GUILD", nil, { ttl = SW.ANSWER_WAIT, key = "YQ" })
    if not sent then return nil, err end
    req = { id = id, map = map, uid = uid, at = now(), answers = {} }
    pending = nil
    C_Timer.After(SW.ANSWER_WAIT, changed)
    changed()
    return true
end

-- The answers of the open question, newest layers first: the ones the own client has not seen
-- itself, then by letter and name: { { name, uid, layer = "Layer C", seen, age } }.
function SW.Answers()
    local out = {}
    if not req or now() - req.at > SW.REQ_LIFE then return out end
    for _, a in ipairs(req.answers) do
        out[#out + 1] = { name = a.name, uid = a.uid, layer = LY.Name(req.map, a.uid), letter = LY.Letter(req.map, a.uid) or "?",
            seen = LY.Seen(req.map, a.uid), age = now() - a.at }
    end
    table.sort(out, function(a, b)
        if a.seen ~= b.seen then return not a.seen end
        if a.letter ~= b.letter then return a.letter < b.letter end
        return a.name < b.name
    end)
    return out
end

-- Host: a guild member asks. Answers by whisper from another layer of the same map only.
ns.CommOn("YQ", function(sender, f, chan)
    if chan ~= "GUILD" or not ns.Get("layer.answer") then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local map, uid, id = tonumber(f[1]), tonumber(f[2]), f[3]
    ns.TrustWait(name, "member", function(member)
        if not member or not ns.Get("layer.answer") then return end
        local mine, myMap = LY.Current()
        if not mine or myMap ~= map or mine == uid or not LY.Fresh() then return end
        if LY.InInstance() or not SW.CanInvite() then return end
        local low = name:lower()
        if not answered[low] then
            local n, oldest, oldKey = 0, nil, nil
            for k, a in pairs(answered) do
                n = n + 1
                if not oldest or a.at < oldest then oldest, oldKey = a.at, k end
            end
            if n >= MAX_ANSWERED then answered[oldKey] = nil end
        end
        answered[low] = { id = id, map = map, uid = mine, at = now() }
        ns.CommSend("YA", { id, map, mine }, "WHISPER", name, { ttl = SW.ANSWER_WAIT, jitter = 2 })
    end)
end)

-- Asker: an answer to the own open question.
ns.CommOn("YA", function(sender, f, chan)
    if chan ~= "WHISPER" or not req or f[1] ~= req.id or now() - req.at > SW.REQ_LIFE then return end
    local map, uid = tonumber(f[2]), tonumber(f[3])
    if map ~= req.map or uid == req.uid then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local r = req
    ns.TrustWait(name, "member", function(member)
        if not member or req ~= r then return end
        for i, a in ipairs(r.answers) do
            if a.name:lower() == name:lower() then table.remove(r.answers, i) break end
        end
        if #r.answers >= SW.MAX_ANSWERS then return end
        r.answers[#r.answers + 1] = { name = name, uid = uid, at = now() }
        LY.Heard(map, uid)
        changed()
    end)
end)

---------------------------------------------------------------------------
-- The invite
---------------------------------------------------------------------------
-- "Einladung erbitten" at name (one of the answers). Returns true, or nil and the reason.
function SW.RequestInvite(name)
    if not req or now() - req.at > SW.REQ_LIFE then return nil, L["Die Antworten sind älter als eine Minute: frag die Gilde noch einmal."] end
    local a
    for _, x in ipairs(req.answers) do
        if x.name:lower() == tostring(name):lower() then a = x break end
    end
    if not a then return nil, L["Dieses Mitglied hat nicht geantwortet."] end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if pending and now() - pending.at < SW.REQUEST_GAP then return nil, L["Einmal alle 10 Sekunden."] end
    local sent, err = ns.CommSend("YI", { req.id, req.map, a.uid }, "WHISPER", a.name, { ttl = SW.ANSWER_WAIT })
    if not sent then return nil, err end
    pending = { name = a.name, uid = a.uid, map = req.map, from = req.uid, at = now() }
    changed()
    return true
end

-- Host: invites name (guild member who asked). Returns true, or nil and the reason.
function SW.Invite(name, quiet)
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if not SW.CanInvite() then return nil, L["Du kannst gerade niemanden einladen (Gruppe voll oder nicht Leiter)."] end
    local t, low = now(), name:lower()
    local keep, n = {}, 0
    for _, x in ipairs(invited) do
        if t - x.at < SW.INVITE_WINDOW then
            keep[#keep + 1] = x
            n = n + 1
            if x.low == low and t - x.at < SW.INVITE_GAP then
                invited = keep
                return nil, not quiet and L["%s wurde gerade erst eingeladen."]:format(name) or nil
            end
        end
    end
    invited = keep
    if n >= SW.INVITE_MAX then return nil, L["Schon sechs Layer-Einladungen in zehn Minuten."] end
    local api = rawget(_G, "C_PartyInfo")
    local fn = type(api) == "table" and api.InviteUnit or rawget(_G, "InviteUnit")
    if type(fn) ~= "function" then return nil, L["Das Spiel bietet Amisia kein Einladen an."] end
    tried("invite")
    if not pcall(fn, name) then return nil, L["Das Spiel hat die Einladung abgelehnt."] end
    invited[#invited + 1] = { low = low, name = name, at = t }
    ns.msg(L["%s eingeladen (Layer-Wechsel)."]:format(name))
    return true
end

-- Host: a guild member it answered asks for the invite.
ns.CommOn("YI", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local low = name:lower()
    local a = answered[low]
    if not a or a.id ~= f[1] or now() - a.at > SW.REQ_LIFE or tonumber(f[2]) ~= a.map or tonumber(f[3]) ~= a.uid then return end
    ns.TrustWait(name, "member", function(member)
        if not member or answered[low] ~= a then return end
        local mine, myMap = LY.Current()
        if mine ~= a.uid or myMap ~= a.map then return end
        answered[low] = nil
        SW.Offer(name, L["%s möchte auf deinen Layer wechseln (%s). Einladen?"]:format(name, LY.Name(myMap, mine)), true)
    end)
end)

-- Host: the question or (auto true and the setting on, out of combat) the invite for name, once per
-- player within DEDUPE (a YI and a chat line of the same member make one). quiet: no line when the
-- invite cannot go (another addon may have invited already). setting: layer.autoInvite for the guild
-- (the default), layer.othersAuto for players outside it.
function SW.Offer(name, question, auto, quiet, setting)
    local low, at = name:lower(), now()
    if offered[low] and at - offered[low] < SW.DEDUPE then return false end
    offered[low] = at
    for k, t in pairs(offered) do
        if at - t >= SW.DEDUPE then offered[k] = nil end
    end
    if auto and ns.Get(setting or "layer.autoInvite") and not inCombat() then
        local ok, why = SW.Invite(name, quiet)
        if not ok and why then ns.msg(why) end
        return true
    end
    ns.W.Confirm(L["Layer-Wechsel"], question, L["Einladen"], function()
        if now() - at > SW.REQ_LIFE then return ns.msg(L["Die Bitte ist älter als eine Minute."]) end
        local ok, why = SW.Invite(name, quiet)
        if not ok and why then ns.msg(why) end
    end)
    return true
end

---------------------------------------------------------------------------
-- The plain chat convention (part 6)
---------------------------------------------------------------------------
-- Whether a chat line looks like a layer request: at most CHAT_MAX characters, no "?", not starting with
-- "[" (an addon's tag), the whole word "layer" with an invite word (inv, invite, einladen, pls, bitte), or
-- "layer" alone with numbers and commas; none of the question words. Numbers are ignored (no shared numbering).
function SW.IsRequestLine(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return false end
    local t = text:match("^%s*(.-)%s*$"):lower()
    if t == "" or #t > SW.CHAT_MAX or t:find("?", 1, true) or t:sub(1, 1) == "[" or t:find("[%c|]") then return false end
    if t:match("^layer[%d%s,]*$") then return true end
    local layer, invite = false, false
    for w in t:gmatch("[^%s%p]+") do
        if w == "layer" then layer = true end
        if INVITE_WORDS[w] then invite = true end
        if QUESTION_WORDS[w] then return false end
    end
    return layer and invite
end

-- The zone text of the own character (the roster's spelling), nil when unknown.
local function ownZone()
    for _, fname in ipairs({ "GetRealZoneText", "GetZoneText" }) do
        local f = rawget(_G, fname)
        if type(f) == "function" then
            local ok, z = pcall(f)
            z = ok and ns.Plain(z)
            if type(z) == "string" and z ~= "" then return z end
        end
    end
    return nil
end

-- The roster's zone text of member name, nil when unknown.
local function memberZone(name)
    local low = name:lower()
    for _, m in ipairs(ns.GuildRoster and ns.GuildRoster() or {}) do
        if type(m.name) == "string" and m.name:lower() == low then
            return type(m.zone) == "string" and m.zone ~= "" and m.zone or nil
        end
    end
    return nil
end

-- Whether the own character is asking for a layer change right now (a question to the guild, a request
-- for an invite, a chat request): then it is nobody's host, or two askers would invite each other.
local function asking()
    local t = now()
    return (chatAt ~= nil and t - chatAt <= SW.ACCEPT_WAIT) or (pending ~= nil and t - pending.at <= SW.ACCEPT_WAIT)
        or (req ~= nil and t - req.at <= SW.ANSWER_WAIT) or swap ~= nil
end

-- The trace: a request line was seen on chan (a channel by its base name), at most MAX_LINE_KEYS kinds.
local function countLine(chan, base)
    local key = chan
    if chan == "CHANNEL" then
        base = ns.Plain(base)
        key = type(base) == "string" and base ~= "" and base:sub(1, 30) or "?"
    end
    if not trace.lines[key] then
        local n = 0
        for _ in pairs(trace.lines) do n = n + 1 end
        if n >= MAX_LINE_KEYS then return end
    end
    trace.lines[key] = (trace.lines[key] or 0) + 1
end

-- Host: a chat line that may be a layer request: chan "GUILD", "WHISPER" or "CHANNEL" (then zoneChan is
-- the client's id of a zone channel, else 0 or nil, and base the channel's name for the trace). A line in
-- the guild chat needs layer.chat, one in a channel layer.others, a whisper either; a player outside the
-- guild is only answered with layer.others.
function SW.ChatLine(text, sender, chan, zoneChan, base)
    local others = ns.Get("layer.others")
    if chan == "CHANNEL" then
        if not others then return end
    elseif not others and not ns.Get("layer.chat") then
        return
    end
    if not SW.IsRequestLine(text) then return end
    sender = ns.Plain(sender)
    if type(sender) ~= "string" or sender == "" then return end
    local name = ns.TrustName(sender) or ns.StripOwnRealm(sender) or ns.FullName(sender)
    local me = ns.UnitFullName("player")
    if not name or (me and name:lower() == me:lower()) then return end
    if chan == "GUILD" and not ns.InGuild() then return end
    countLine(chan, base)
    local at = now()
    local function handle(member)
        -- the roster's answer may come late: an old line is nobody's request any more
        if now() - at > SW.DEDUPE or LY.InInstance() or not SW.CanInvite() or ns.InMyGroup(name) or asking() then return end
        local m = member and ns.GuildMember(name)
        if m and type(m.name) == "string" and m.name:lower() == name:lower() then
            -- the guild's way (layer.chat; in a channel layer.others let the line in): the roster's zone
            -- decides. With layer.chat off a member's whisper is anyone's whisper: only the question.
            local guildWay = chan == "CHANNEL" or ns.Get("layer.chat")
            if not guildWay and (chan == "GUILD" or not ns.Get("layer.others")) then return end
            local theirs, mine = memberZone(m.name), ownZone()
            if theirs and mine and theirs ~= mine then return end
            local same = guildWay and theirs ~= nil and mine ~= nil
            SW.Offer(m.name, L["%s bittet im Chat um einen Layer-Wechsel. Einladen?"]:format(m.name), same, true)
            return
        end
        -- a player outside the guild: never from the guild chat (the roster did not know the name)
        if chan == "GUILD" or not ns.Get("layer.others") then return end
        if othersAt and now() - othersAt < SW.OTHERS_GAP then return end
        -- only in a channel of the own zone the asker surely stands in the same zone
        local same = chan == "CHANNEL" and ZONE_CHANNELS[tonumber(ns.Plain(zoneChan)) or 0] == true
        if SW.Offer(name, L["%s (nicht in der Gilde) bittet im Chat um einen Layer-Wechsel. Einladen?"]:format(name), same, true,
            "layer.othersAuto") then
            othersAt = now()
        end
    end
    if not ns.InGuild() then return handle(false) end
    if chan == "CHANNEL" then
        -- channel lines come in numbers: they never wait for the roster (the waiting list is the guild's);
        -- while the roster cannot answer, the line is skipped
        local member = ns.IsVerifiedMember(name)
        if member == nil then return end
        return handle(member)
    end
    ns.TrustWait(name, "member", handle)
end
ns.OnEvent("CHAT_MSG_GUILD", function(text, sender) SW.ChatLine(text, sender, "GUILD") end)
ns.OnEvent("CHAT_MSG_WHISPER", function(text, sender) SW.ChatLine(text, sender, "WHISPER") end)
ns.OnEvent("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, zoneChan, _, base)
    if not ns.Get("layer.others") then return end
    SW.ChatLine(text, sender, "CHANNEL", zoneChan, base)
end)

-- The request text of layer.chatText: one line without codes, at most CHAT_MAX characters.
function SW.ChatText(v)
    if type(v) ~= "string" then return nil end
    v = v:gsub("[%c|]", " "):match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if v == "" or #v > SW.CHAT_MAX then return nil end
    return v
end

-- Opens the chat box with line (the player sends it with Enter). Returns true, or nil and the reason.
local function openChat(line)
    local util = rawget(_G, "ChatFrameUtil")
    local open = rawget(_G, "ChatFrame_OpenChat") or (type(util) == "table" and util.OpenChat) or nil
    if type(open) ~= "function" or not pcall(open, line) then return nil, L["Das Spiel öffnet die Chatzeile nicht."] end
    return true
end

-- Asker: "Im Gildenchat fragen" opens the chat box with "/g <text>" (the player sends it with Enter).
function SW.AskChat()
    if not ns.InGuild() then return nil, L["Du bist in keiner Gilde."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    local ok, why = openChat("/g " .. (SW.ChatText(ns.Get("layer.chatText")) or "inv layer"))
    if not ok then return nil, why end
    chatAt, chatAll, pending = now(), nil, nil
    changed()
    return true
end

-- The channel of "Im Kanal fragen": its number (layer.channel, 1 to 10) and, where the client tells it,
-- its name; the name is nil when the player is in no channel of that number.
function SW.Channel()
    local n = math.floor(tonumber(ns.Get("layer.channel")) or 1)
    if n < 1 or n > 10 then n = 1 end
    local f = rawget(_G, "GetChannelName")
    if type(f) ~= "function" then return n, "" end
    local ok, id, name = pcall(f, n)
    id, name = ok and tonumber(ns.Plain(id)) or 0, ok and ns.Plain(name) or nil
    if id == 0 then return n, nil end
    return n, type(name) == "string" and name or ""
end

-- Asker: "Im Kanal fragen" opens the chat box with "/<channel> <text>"; for ACCEPT_WAIT seconds the next
-- invite counts as the swap, whoever sends it (players outside the guild answer a channel line).
function SW.AskChannel()
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    local n, name = SW.Channel()
    if not name then return nil, L["Du bist in keinem Kanal %d (Einstellungen, Layer: Kanal)."]:format(n) end
    local ok, why = openChat(("/%d %s"):format(n, SW.ChatText(ns.Get("layer.chatText")) or "inv layer"))
    if not ok then return nil, why end
    chatAt, chatAll, pending = now(), true, nil
    changed()
    return true
end

---------------------------------------------------------------------------
-- Accepting, the change, leaving
---------------------------------------------------------------------------
local function hidePopup()
    local hide = rawget(_G, "StaticPopup_Hide")
    if type(hide) == "function" then pcall(hide, "PARTY_INVITE") end
end

-- Asker: an invite came. Only the invite of exactly the member asked, within ACCEPT_WAIT, is taken.
local function accept()
    local fn = rawget(_G, "AcceptGroup")
    if type(fn) ~= "function" then return false end
    tried("accept")
    if not pcall(fn) then return false end
    hidePopup()
    C_Timer.After(0, hidePopup)
    return true
end

-- After "Im Gildenchat fragen": the invite of a guild member (exactly its roster spelling) within
-- ACCEPT_WAIT is the swap's; anyone else's stays the client's. After "Im Kanal fragen": anyone's.
local function chatInvite(name)
    if pending or not chatAt or now() - chatAt > SW.ACCEPT_WAIT then return end
    local at = chatAt
    local function take(shown)
        local uid, map = LY.Current()
        pending = { name = shown, map = map or LY.Map(), from = uid, at = now(), invited = now(), chat = true }
        changed()
        if not ns.Get("layer.autoAccept") or inGroup() or LY.InInstance() then return end
        if accept() then
            pending.accepted = true
            ns.msg(L["Einladung von %s angenommen (Layer-Wechsel)."]:format(shown))
        end
    end
    if chatAll then return take(name) end
    ns.TrustWait(name, "member", function(member)
        local m = member and ns.GuildMember(name)
        if not m or type(m.name) ~= "string" or m.name:lower() ~= name:lower() or chatAt ~= at or pending then return end
        take(m.name)
    end)
end

function SW.InviteRequest(raw)
    local name = nameOf(raw)
    if not name then return end
    -- a request older than ACCEPT_WAIT is over; after "Im Kanal fragen" a second player's invite takes the
    -- place of the first one's (which was not taken)
    if pending and (now() - pending.at > SW.ACCEPT_WAIT
        or (pending.chat and chatAll and name:lower() ~= pending.name:lower())) then
        pending = nil
    end
    if not pending then return chatInvite(name) end
    if name:lower() ~= pending.name:lower() then return end
    pending.invited = now()
    if not ns.Get("layer.autoAccept") or inGroup() or LY.InInstance() then return end
    if accept() then
        pending.accepted = true
        ns.msg(L["Einladung von %s angenommen (Layer-Wechsel)."]:format(pending.name))
    end
end
ns.OnEvent("PARTY_INVITE_REQUEST", function(raw) SW.InviteRequest(raw) end)

-- The group of the swap: the two of them, out of an instance.
local function ownPair(s)
    return s == swap and inGroup() and not inRaid() and members() == 2 and ns.InMyGroup(s.host) and not LY.InInstance()
end

function SW.Leave(auto)
    if not swap or not inGroup() then return nil, L["Keine Gruppe aus einem Layer-Wechsel."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if auto and not ownPair(swap) then return nil end
    local api = rawget(_G, "C_PartyInfo")
    local fn = type(api) == "table" and api.LeaveParty or rawget(_G, "LeaveParty")
    if type(fn) ~= "function" then return nil, L["Das Spiel bietet Amisia kein Verlassen an."] end
    tried("leave")
    if not pcall(fn) then return nil, L["Das Spiel hat das Verlassen abgelehnt."] end
    if auto then ns.msg(L["Gruppe nach dem Layer-Wechsel verlassen."]) end
    return true
end

local function checkChange()
    local s = swap
    if not s or s.changed then return end
    local uid, map = LY.Current()
    if not uid or map ~= s.map then return end
    -- after a chat request the host's layer is unknown: any other layer than before is the change
    if s.target and uid ~= s.target then return end
    if not s.target and (not s.from or uid == s.from) then return end
    s.target = uid
    s.changed, s.failed = now(), nil
    trace.changed = trace.changed + 1
    ns.msg(L["Gewechselt: %s"]:format(LY.Name(map, uid)))
    changed()
    if ns.Get("layer.autoLeave") then
        C_Timer.After(tonumber(ns.Get("layer.leaveSeconds")) or 30, function()
            if swap == s and ns.Get("layer.autoLeave") then SW.Leave(true) end
        end)
    end
end
ns.Listen("LAYER", checkChange)

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local t = now()
    if swap and not inGroup() then
        if lastCall and lastCall.kind == "leave" and t - lastCall.at <= SW.TRACE_WAIT + 3 then
            trace.leave.left = trace.leave.left + 1
            lastCall = nil
        end
        swap = nil
        changed()
        return
    end
    -- the trace: a player Amisia invited is in the group now
    for _, x in ipairs(invited) do
        if not x.joined and x.name and t - x.at <= SW.JOIN_WAIT and ns.InMyGroup(x.name) then
            x.joined = true
            trace.invite.joined = trace.invite.joined + 1
        end
    end
    local p = pending
    if not swap and p and inGroup() and t - p.at <= SW.ACCEPT_WAIT + 30 and ns.InMyGroup(p.name) then
        local s = { host = p.name, map = p.map, from = p.from, target = p.uid, at = t }
        if p.accepted then trace.accept.joined = trace.accept.joined + 1 end
        swap, pending, chatAt, chatAll = s, nil, nil, nil
        C_Timer.After(SW.CHANGE_WAIT, function()
            if swap == s and not s.changed then
                -- without a layer before and without the host's layer nothing can be compared
                if s.target or s.from then s.failed = true else s.unknown = true end
                if s.failed then trace.failed = trace.failed + 1 else trace.unknown = trace.unknown + 1 end
                changed()
            end
        end)
        changed()
        checkChange()
    end
end)

-- What the window shows: the open question, the request, the swap.
function SW.State()
    local open = chatAt ~= nil and now() - chatAt <= SW.ACCEPT_WAIT
    return { req = req, pending = pending, swap = swap, answers = SW.Answers(),
        chat = open or nil, chatAll = open and chatAll or nil }
end

-- for the tests and the UI scene: st = { req, pending, swap } to start from (nil: nothing open)
function SW._reset(st)
    st = st or {}
    req, pending, swap, answered, invited, offered, chatAt = st.req, st.pending, st.swap, {}, {}, {}, st.chatAt
    chatAll, othersAt, lastCall, trace = st.chatAll, nil, nil, newTrace()
end
end)
