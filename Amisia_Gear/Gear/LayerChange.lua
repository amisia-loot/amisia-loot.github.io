-- Changing the layer (F-185, D-117; beyond the guild F-191, D-124; ns.LayerChange). Amisia's own
-- messages (prefix of Core/Comm.lua) go between guild members with Amisia only; players outside the
-- guild are reached through the plain chat line alone (part 7 below).
-- Asker: "Gilde fragen" (SW.Ask; alone, not in a group, not in an instance, a fresh current layer of
-- Gear/Layer.lua, once in ASK_GAP) sends YQ to GUILD (zone map, own zoneUID, request id). A member on
-- the same map with a fresh, other layer, out of an instance, able to invite (alone, or since F-216 the
-- leader of a party of own guests) and layer.answer on whispers YA (request id, map, own zoneUID) 0-2 s later; the
-- asker lists the answers (SW.Answers; the guild's ids also go to Layer.Heard, so letters agree) and
-- "Einladung erbitten" (SW.RequestInvite) whispers YI to that member. The member (only for an asker it
-- answered within REQ_LIFE, the same request and the own layer unchanged) asks "... Einladen?" (W.Confirm)
-- or with layer.autoInvite invites at once out of combat (SW.Invite: C_PartyInfo.InviteUnit, else
-- InviteUnit; never in an instance, not the same player within INVITE_GAP, INVITE_MAX in INVITE_WINDOW).
-- The asker accepts with layer.autoAccept exactly the invite of the member asked within ACCEPT_WAIT
-- (AcceptGroup, the client's window "PARTY_INVITE" hidden); every other invite stays the client's.
-- Once in that group (the swap): the layer reaching the host's zoneUID says "Gewechselt: Layer C";
-- "Gruppe verlassen" (SW.Leave) and, with layer.autoLeave, leaving by itself after layer.leaveSeconds,
-- only from the host's party of five at most (since F-216 also with other guests in it), never in an instance. After CHANGE_WAIT without a
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
-- Part 8 (F-214): "Helfen" (SW.Hosting/SW.SetHosting), a switch of this session over all helping: off,
-- Amisia answers no YQ, takes no YI and no request line, asks nothing and invites nobody (an open
-- "... Einladen?" closes); on after every login; the settings still say whom and whether with a question.
-- SW.Helped(): this session's requests that reached the helping, invites sent, invited who joined.
-- "Layer wechseln" (SW.Swap, SW.SwapStep): asks the guild (SW.Ask); PICK_WAIT after the first fitting
-- answer (of the layer target when a row of the window was clicked) it asks for the invite by itself, at a
-- layer the own client has not seen first (SW.Answers' order); without one within ANSWER_WAIT the next
-- click opens the channel line (SW.AskChannel), outside a guild already the first. Never opens the chat
-- by itself.
-- Part 9 (F-216, D-141): the zone. "Layer wechseln" also asks the Amisia users of the zone outside the guild:
-- each click (the client allows /who only from a click) one /who (the zone, then one class per click), the
-- client's own who window kept shut for that answer; a quiet ZQ (request id, zone map, own zoneUID) to each
-- name not in the guild (players who answered within 7 days first, AmisiaDB.layerHosts; nobody asked in the
-- last 6 hours without an answer again), 50 per click at most; every Amisia user who hears it in the same zone
-- whispers ZA (request id, map, its zoneUID or 0, 1 when it helps). A helping answer from another layer joins
-- the answers and the pick of part 8; YI goes to such a stranger too, and the host takes YI from a stranger it
-- answered with ZA. Helping (SW.CanHelp): "Helfen" on, layer.combatPause, not listed in the group finder;
-- inviting (SW.CanInvite) only alone or as the leader of a party Amisia filled for swaps; the swap's party is
-- set to free for all (once, given up when the client blocks it); "Helfen" off and SW.Kick take the guests
-- out. After a swap: leaving after layer.leaveSeconds (default on, 5 s); a host that did not move the player
-- (a creature read 15 s or more after joining shows the old layer) makes Amisia leave and offer the swap
-- again. The server's "no player named ..." line for a name Amisia just whispered stays out of the chat
-- (Core/Comm.lua, for every whisper of Amisia's).
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
SW.PICK_WAIT = 2.5      -- seconds after the first fitting answer before "Layer wechseln" picks one
SW.WHO_WAIT = 5         -- seconds a /who answer is waited for
SW.ZONE_MAX = 50        -- quiet questions per click
SW.ZQ_TTL = 45          -- seconds a quiet question may wait in the send queue
SW.HOST_KEEP = 7 * 86400   -- seconds a player who answered stays first in line (AmisiaDB.layerHosts)
SW.HOST_MAX = 200
SW.SILENT_KEEP = 6 * 3600  -- seconds a player asked without an answer is not asked again
SW.ZQ_WINDOW, SW.ZQ_MAX = 60, 20   -- quiet questions answered per minute at most
SW.STUCK_WAIT = 15      -- seconds after joining before a read of the old layer means "not moved"
SW.NEW_AGE = 3600       -- "Nur neue Layer": a layer seen in the zone within this many seconds is not new
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
local hosting = true -- "Helfen" (F-214): off until the next login
local helped = { asked = 0, invited = 0, joined = 0 }
local auto           -- "Layer wechseln": { req, target, picking, picked, none }
local question       -- host: { frame, fn } the open "... Einladen?"
local zone           -- asker: the zone search { req, step, classes, sent, heard, reached, found, hosts, other, waiting, whoAt, err }
local whoBlocked     -- the client blocked /who this session: the zone is not asked any more
local lootBlocked    -- the client blocked setting the loot: not tried again this session
local lootDone       -- the swap party was set to free for all
local silent = {}    -- asker: [lower name] = time a quiet question went without an answer yet
local zqAt = {}      -- host: times of the quiet questions answered within ZQ_WINDOW
local mutedFrame     -- the client's FriendsFrame while it does not hear WHO_LIST_UPDATE (one for all searches)
local mutedAt

local function newTrace()
    return { invite = { tried = 0, blocked = 0, joined = 0 }, accept = { tried = 0, blocked = 0, joined = 0 },
        leave = { tried = 0, blocked = 0, left = 0 }, who = { tried = 0, blocked = 0 }, loot = { tried = 0, blocked = 0 },
        kick = { tried = 0, blocked = 0 }, changed = 0, failed = 0, unknown = 0, stuck = 0, lines = {} }
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

-- The players Amisia invited for swaps who are in the own group now (each once).
local function guestsInGroup()
    local out, seen = {}, {}
    for _, x in ipairs(invited) do
        if x.name and not seen[x.low] and ns.InMyGroup(x.name) then
            seen[x.low] = true
            out[#out + 1] = x.name
        end
    end
    return out
end

-- Whether the own character may invite now (F-216): alone, or the leader of a party with room that holds
-- only players Amisia invited for swaps.
function SW.CanInvite()
    if not inGroup() then return true end
    if inRaid() or not unitFlag("UnitIsGroupLeader", "player") or members() >= 5 then return false end
    return #guestsInGroup() >= members() - 1
end

-- Whether the own character is listed in the group finder.
local function inGroupFinder()
    local api = rawget(_G, "C_LFGList")
    local f = type(api) == "table" and api.HasActiveEntryInfo
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f)
    return ok and ns.Plain(v) == true
end

-- The name the guild would write for an invite's sender: the own realm's ending dropped.
local function nameOf(raw)
    raw = ns.Plain(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    return ns.StripOwnRealm(raw) or ns.FullName(raw)
end

local function changed() ns.Fire("LAYER_CHANGE") end

-- Whether Amisia helps others now: "Helfen" on, not paused for combat (layer.combatPause), not listed in the
-- group finder. Inviting needs SW.CanInvite besides.
function SW.CanHelp()
    if not hosting then return false end
    if ns.Get("layer.combatPause") and inCombat() then return false end
    return not inGroupFinder()
end

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
    if lastCall.kind == "who" then whoBlocked = true end
    if lastCall.kind == "loot" then lootBlocked = true end
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

-- A question without the guild (the zone alone, F-216): the same checks but the guild.
local function askAlone()
    if not (ns.CommReady and ns.CommReady()) then return nil, L["Addon-Nachrichten sind gerade nicht verfügbar."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    if not LY.Fresh() then return nil, L["Layer unbekannt: ziele oder überfahre erst einen NPC."] end
    if req and now() - req.at < SW.ASK_GAP then return nil, L["Einmal alle 10 Sekunden."] end
    local uid, map = LY.Current()
    req = { id = ("%04x"):format(math.random(0, 65535)), map = map, uid = uid, at = now(), answers = {} }
    pending = nil
    C_Timer.After(SW.ANSWER_WAIT, changed)
    return true
end

-- The answers of the open question, newest layers first: the ones the own client has not seen
-- itself, then by letter and name: { { name, uid, layer = "Layer C", seen, age } }.
function SW.Answers()
    local out = {}
    if not req or now() - req.at > SW.REQ_LIFE then return out end
    for _, a in ipairs(req.answers) do
        out[#out + 1] = { name = a.name, uid = a.uid, layer = LY.Name(req.map, a.uid), letter = LY.Letter(req.map, a.uid) or "?",
            seen = LY.Seen(req.map, a.uid), age = now() - a.at, stranger = a.stranger }
    end
    table.sort(out, function(a, b)
        if a.seen ~= b.seen then return not a.seen end
        if a.letter ~= b.letter then return a.letter < b.letter end
        return a.name < b.name
    end)
    return out
end

-- Whether the own character is asking for a layer change right now (a question to the guild, a request
-- for an invite, a chat request): then it is nobody's host, or two askers would invite each other (F-214: two
-- players pressing "Layer wechseln" together neither answer nor ask each other).
local function asking()
    local t = now()
    return (chatAt ~= nil and t - chatAt <= SW.ACCEPT_WAIT) or (pending ~= nil and t - pending.at <= SW.ACCEPT_WAIT)
        or (req ~= nil and t - req.at <= SW.ANSWER_WAIT) or swap ~= nil or (auto ~= nil and auto.picking == true)
end

-- Host: remembers an answer (YA or a helping ZA) for the YI that may follow; MAX_ANSWERED at most.
function SW._answered(low, entry)
    if not answered[low] then
        local n, oldest, oldKey = 0, nil, nil
        for k, a in pairs(answered) do
            n = n + 1
            if not oldest or a.at < oldest then oldest, oldKey = a.at, k end
        end
        if n >= MAX_ANSWERED and oldKey then answered[oldKey] = nil end
    end
    answered[low] = entry
end

-- Host: a guild member asks. Answers by whisper from another layer of the same map only.
ns.CommOn("YQ", function(sender, f, chan)
    if chan ~= "GUILD" or not hosting or not ns.Get("layer.answer") then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local map, uid, id = tonumber(f[1]), tonumber(f[2]), f[3]
    ns.TrustWait(name, "member", function(member)
        if not member or not SW.CanHelp() or not ns.Get("layer.answer") or asking() then return end
        local mine, myMap = LY.Current()
        if not mine or myMap ~= map or mine == uid or not LY.Fresh() then return end
        if LY.InInstance() or not SW.CanInvite() then return end
        SW._answered(name:lower(), { id = id, map = map, uid = mine, at = now() })
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
        SW._addAnswer(r, name, uid, false)
    end)
end)

-- An answer from another layer to the open question r (stranger: a player outside the guild, F-216); it
-- starts the pick of "Layer wechseln" when it fits.
function SW._addAnswer(r, name, uid, stranger)
    for i, a in ipairs(r.answers) do
        if a.name:lower() == name:lower() then table.remove(r.answers, i) break end
    end
    if #r.answers >= SW.MAX_ANSWERS then return end
    r.answers[#r.answers + 1] = { name = name, uid = uid, at = now(), stranger = stranger or nil }
    LY.Heard(r.map, uid)
    local a = auto
    -- a late answer picks too (F-216: the quiet questions go out one a second, the last ones after 40 s)
    if a and a.req == r and not a.picking and not a.picked and not pending and not swap and (not a.target or a.target == uid)
        and not (a.recent and a.recent[uid]) then
        a.picking, a.none = true, nil
        C_Timer.After(SW.PICK_WAIT, function() SW._pick(a) end)
    end
    changed()
end

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
    local sent, err = ns.CommSend("YI", { req.id, req.map, a.uid }, "WHISPER", a.name, { ttl = SW.ANSWER_WAIT, anyone = a.stranger })
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
        local recent = t - x.at < SW.INVITE_WINDOW
        -- a guest still in the group stays known (SW.CanInvite, SW.Kick), without counting for the limit
        if recent or (x.joined and x.name and ns.InMyGroup(x.name)) then keep[#keep + 1] = x end
        if recent then
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
    helped.invited = helped.invited + 1
    ns.msg(L["%s eingeladen (Layer-Wechsel)."]:format(name))
    return true
end

-- Host: a guild member it answered asks for the invite.
ns.CommOn("YI", function(sender, f, chan)
    if chan ~= "WHISPER" or not hosting then return end
    -- a stranger answered by ZA is keyed by its plain name; a member by the roster's spelling
    local plain = nameOf(sender)
    local name = plain and answered[plain:lower()] and answered[plain:lower()].stranger and plain or ns.TrustName(sender) or plain
    if not name then return end
    local low = name:lower()
    local a = answered[low]
    if not a or a.id ~= f[1] or now() - a.at > SW.REQ_LIFE or tonumber(f[2]) ~= a.map or tonumber(f[3]) ~= a.uid then return end
    local function go()
        if answered[low] ~= a then return end
        local mine, myMap = LY.Current()
        if mine ~= a.uid or myMap ~= a.map then return end
        answered[low] = nil
        SW.Offer(a.name or name, L["%s möchte auf deinen Layer wechseln (%s). Einladen?"]:format(a.name or name, LY.Name(myMap, mine)), true)
    end
    -- a player outside the guild that this client answered with ZA (F-216): no roster to wait for
    if a.stranger then return go() end
    ns.TrustWait(name, "member", function(member) if member then go() end end)
end)

-- Host: the question or (auto true and the setting on, out of combat) the invite for name, once per
-- player within DEDUPE (a YI and a chat line of the same member make one). quiet: no line when the
-- invite cannot go (another addon may have invited already). setting: layer.autoInvite for the guild
-- (the default), layer.othersAuto for players outside it.
function SW.Offer(name, text, autoInvite, quiet, setting)
    if not SW.CanHelp() or asking() then return false end
    local low, at = name:lower(), now()
    if offered[low] and at - offered[low] < SW.DEDUPE then return false end
    offered[low] = at
    for k, t in pairs(offered) do
        if at - t >= SW.DEDUPE then offered[k] = nil end
    end
    helped.asked = helped.asked + 1
    changed()
    if autoInvite and ns.Get(setting or "layer.autoInvite") and not inCombat() then
        local ok, why = SW.Invite(name, quiet)
        if not ok and why then ns.msg(why) end
        return true
    end
    local function ok()
        question = nil
        if not hosting then return end
        if now() - at > SW.REQ_LIFE then return ns.msg(L["Die Bitte ist älter als eine Minute."]) end
        local done, why = SW.Invite(name, quiet)
        if not done and why then ns.msg(why) end
    end
    question = { frame = ns.W.Confirm(L["Layer-Wechsel"], text, L["Einladen"], ok), fn = ok }
    return true
end

---------------------------------------------------------------------------
-- "Helfen" (part 8, F-214)
---------------------------------------------------------------------------
function SW.Hosting() return hosting end
function SW.Helped() return helped end

-- Switches the helping; off closes an open "... Einladen?" of Amisia's.
function SW.SetHosting(on)
    hosting = on and true or false
    local q = question
    if not hosting and q then
        question = nil
        if q.frame and q.frame.IsShown and q.frame:IsShown() and q.frame.onOk == q.fn then q.frame:Hide() end
    end
    -- F-216: off takes the guests of swaps out of the group
    if not hosting then SW.Kick(true) end
    changed()
    return hosting
end

-- The seconds until the next invite may go (six in ten minutes), 0 when one may go now.
function SW.InviteBreak()
    local t, n, oldest = now(), 0, nil
    for _, x in ipairs(invited) do
        if t - x.at < SW.INVITE_WINDOW then
            n = n + 1
            if not oldest or x.at < oldest then oldest = x.at end
        end
    end
    if n < SW.INVITE_MAX or not oldest then return 0 end
    return math.max(0, math.ceil(oldest + SW.INVITE_WINDOW - t))
end

-- Takes the players Amisia invited for swaps out of the own group (leader only, out of an instance).
-- quiet: no line when there is nobody. Returns the number taken out, or nil and the reason.
function SW.Kick(quiet)
    local guests = inGroup() and unitFlag("UnitIsGroupLeader", "player") and not LY.InInstance() and guestsInGroup() or {}
    if #guests == 0 then
        if quiet then return 0 end
        return nil, L["Keine Gäste aus Layer-Wechseln in deiner Gruppe."]
    end
    local api = rawget(_G, "C_PartyInfo")
    local fn = type(api) == "table" and api.UninviteUnit or rawget(_G, "UninviteUnit")
    if type(fn) ~= "function" then return nil, L["Das Spiel bietet Amisia kein Entfernen an."] end
    local n = 0
    for _, name in ipairs(guests) do
        tried("kick")
        if pcall(fn, name) then n = n + 1 end
    end
    ns.msg(L["%d Gäste aus Layer-Wechseln aus der Gruppe genommen."]:format(n))
    return n
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
    if not hosting then return end
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
        if not hosting or now() - at > SW.DEDUPE or LY.InInstance() or not SW.CanInvite() or ns.InMyGroup(name) or asking() then return end
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
    chatAt, chatAll, pending, auto, zone = now(), nil, nil, nil, nil
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
    chatAt, chatAll, pending, auto, zone = now(), true, nil, nil, nil
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
    return s == swap and inGroup() and not inRaid() and members() <= 5 and ns.InMyGroup(s.host) and not LY.InInstance()
end

function SW.Leave(byItself)
    if not swap or not inGroup() then return nil, L["Keine Gruppe aus einem Layer-Wechsel."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if byItself and not ownPair(swap) then return nil end
    local api = rawget(_G, "C_PartyInfo")
    local fn = type(api) == "table" and api.LeaveParty or rawget(_G, "LeaveParty")
    if type(fn) ~= "function" then return nil, L["Das Spiel bietet Amisia kein Verlassen an."] end
    tried("leave")
    if not pcall(fn) then return nil, L["Das Spiel hat das Verlassen abgelehnt."] end
    if byItself then ns.msg(L["Gruppe nach dem Layer-Wechsel verlassen."]) end
    return true
end

-- The host did not move the player (F-216): a creature read STUCK_WAIT or more after joining still shows the
-- layer from before; Amisia leaves the pair and "Layer wechseln" is offered again.
local function checkStuck(s)
    if swap ~= s or s.changed or s.stuck or not s.from or now() - s.at < SW.STUCK_WAIT then return end
    local uid, map, _, age = LY.Current()
    if uid ~= s.from or map ~= s.map or not age or now() - age < s.at + SW.STUCK_WAIT then return end
    s.stuck, s.failed = true, true
    trace.stuck = trace.stuck + 1
    if SW.Leave(true) then
        ns.msg(L["Der Wechsel über %s hat nicht geklappt: Amisia verlässt die Gruppe, Layer wechseln geht wieder."]:format(s.host))
    else
        ns.msg(L["Der Wechsel über %s hat nicht geklappt."]:format(s.host))
    end
    changed()
end

local function checkChange()
    local s = swap
    if not s or s.changed then return end
    checkStuck(s)
    if s.stuck then return end
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
        C_Timer.After(tonumber(ns.Get("layer.leaveSeconds")) or 5, function()
            if swap == s and ns.Get("layer.autoLeave") then SW.Leave(true) end
        end)
    end
end
ns.Listen("LAYER", checkChange)

-- The swap party (F-216): free for all, once, when the leader is the host of a party Amisia filled.
local function setLoot()
    if lootDone or lootBlocked or not inGroup() or not SW.CanInvite() or #guestsInGroup() == 0 then return end
    local api = rawget(_G, "C_PartyInfo")
    local get = type(api) == "table" and api.GetLootMethod or rawget(_G, "GetLootMethod")
    local set = type(api) == "table" and api.SetLootMethod or rawget(_G, "SetLootMethod")
    if type(set) ~= "function" then return end
    lootDone = true
    if type(get) == "function" then
        local ok, method = pcall(get)
        method = ok and ns.Plain(method)
        local ffa = Enum and Enum.LootMethod and Enum.LootMethod.Freeforall
        if method == "freeforall" or (ffa ~= nil and method == ffa) then return end
    end
    local ffa = Enum and Enum.LootMethod and Enum.LootMethod.Freeforall
    tried("loot")
    pcall(set, ffa ~= nil and api and set == api.SetLootMethod and ffa or "freeforall")
end

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local t = now()
    if not inGroup() then lootDone = nil end
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
            helped.joined = helped.joined + 1
            changed()
        end
    end
    setLoot()
    local p = pending
    if not swap and p and inGroup() and t - p.at <= SW.ACCEPT_WAIT + 30 and ns.InMyGroup(p.name) then
        local s = { host = p.name, map = p.map, from = p.from, target = p.uid, at = t }
        if p.accepted then trace.accept.joined = trace.accept.joined + 1 end
        swap, pending, chatAt, chatAll, zone = s, nil, nil, nil, nil
        -- the same layer read again fires nothing: look every 5 s until the change or CHANGE_WAIT
        local function look()
            if swap ~= s or s.changed or s.stuck or now() - s.at > SW.CHANGE_WAIT then return end
            checkStuck(s)
            C_Timer.After(5, look)
        end
        C_Timer.After(SW.STUCK_WAIT + 0.5, look)
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

---------------------------------------------------------------------------
-- The zone (part 9, F-216)
---------------------------------------------------------------------------
local function hostsDB()
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.layerHosts) ~= "table" then AmisiaDB.layerHosts = {} end
    return AmisiaDB.layerHosts
end

-- A player who answered a quiet question: first in line for a week (HOST_MAX names, the oldest go).
local function rememberHost(name)
    local db = hostsDB()
    if not db then return end
    local low = name:lower()
    if not db[low] then
        local n, oldest, oldKey = 0, nil, nil
        for k, at in pairs(db) do
            n = n + 1
            if not oldest or at < oldest then oldest, oldKey = at, k end
        end
        if n >= SW.HOST_MAX and oldKey then db[oldKey] = nil end
    end
    db[low] = time()
end

-- The saved list kept clean (on load): names and recent times only.
function SW.LoadedHosts(DB)
    local db = DB and DB.layerHosts
    if db == nil then return end
    if type(db) ~= "table" then DB.layerHosts = nil return end
    local cut, n = time() - SW.HOST_KEEP, 0
    for k, at in pairs(db) do
        if type(k) ~= "string" or k == "" or #k > 48 or k:find("[%c|]") or type(at) ~= "number" or at < cut or n >= SW.HOST_MAX then
            db[k] = nil
        else
            n = n + 1
        end
    end
end

-- The classes of the client in /who order (the client's names), for a search one class per click.
local function whoClasses()
    local out = {}
    local api = rawget(_G, "C_CreatureInfo")
    for id = 1, 12 do
        local name
        if type(api) == "table" and type(api.GetClassInfo) == "function" then
            local ok, info = pcall(api.GetClassInfo, id)
            info = ok and ns.Plain(info) or nil
            name = type(info) == "table" and ns.Plain(info.className) or nil
        elseif type(rawget(_G, "GetClassInfo")) == "function" then
            local ok, n = pcall(GetClassInfo, id)
            name = ok and ns.Plain(n) or nil
        end
        if type(name) == "string" and name ~= "" then out[#out + 1] = { id = id, name = name } end
    end
    return out
end

-- Whether the zone can be asked at all: the client has /who and did not block it.
function SW.ZonePossible()
    local fl = rawget(_G, "C_FriendList")
    return not whoBlocked and type(fl) == "table" and type(fl.SendWho) == "function" and ns.CommReady ~= nil and ns.CommReady() == true
end

-- Whether another click reaches new players: the next class of the zone search; its name or nil.
function SW.ZoneNext()
    local z = zone
    if not z or z.req ~= req or not SW.ZonePossible() then return nil end
    if z.step == 0 then return SW._zoneText() end
    local c = z.classes[z.step]
    return c and c.name or nil
end

-- The client's who window: shut out of the next answer (its event), and back. One state for every search and
-- the probe; whatever happens to them, the next WHO_LIST_UPDATE or WHO_WAIT brings the window's event back.
local function unmute()
    local ff = mutedFrame
    mutedFrame, mutedAt = nil, nil
    local fl = rawget(_G, "C_FriendList")
    if type(fl) == "table" and type(fl.SetWhoToUi) == "function" then pcall(fl.SetWhoToUi, false) end
    if ff then pcall(ff.RegisterEvent, ff, "WHO_LIST_UPDATE") end
end
SW._unmute = unmute
local function mute()
    mutedAt = now()
    local at = mutedAt
    C_Timer.After(SW.WHO_WAIT + 0.5, function() if mutedAt == at then unmute() end end)
    if mutedFrame then return end
    local ff = rawget(_G, "FriendsFrame")
    if type(ff) == "table" and type(ff.UnregisterEvent) == "function" and type(ff.IsEventRegistered) == "function"
        and ff:IsEventRegistered("WHO_LIST_UPDATE") then
        pcall(ff.UnregisterEvent, ff, "WHO_LIST_UPDATE")
        mutedFrame = ff
    end
end

-- One /who for the zone search (inside a click): the zone, then the next class. true, or nil and the reason.
function SW.AskZone()
    local z = zone
    if not z or z.req ~= req then return nil end
    if not SW.ZonePossible() then return nil, L["Das Spiel erlaubt Amisia gerade keine Wer-Abfrage."] end
    local ff = rawget(_G, "FriendsFrame")
    if type(ff) == "table" and type(ff.IsShown) == "function" and ff:IsShown() then
        return nil, L["Das Fenster Freunde ist offen: Amisia fragt die Zone erst, wenn es zu ist."]
    end
    if z.waiting then return nil, L["Gefragt, warte auf Antworten ..."] end
    local where = SW._zoneText()
    if not where then return nil, L["Das Spiel nennt deine Zone nicht."] end
    local c = z.step > 0 and z.classes[z.step] or nil
    if z.step > 0 and not c then return nil, L["Alle Klassen der Zone sind gefragt."] end
    local filter = ('z-"%s"'):format(where) .. (c and (' c-"%s"'):format(c.name) or "")
    local fl = rawget(_G, "C_FriendList")
    mute()
    if type(fl.SetWhoToUi) == "function" then pcall(fl.SetWhoToUi, true) end
    tried("who")
    if not pcall(fl.SendWho, filter) then
        unmute()
        return nil, L["Das Spiel hat die Wer-Abfrage abgelehnt."]
    end
    z.waiting, z.whoAt, z.asked, z.err = true, now(), c and c.name or where, nil
    z.step = z.step + 1
    C_Timer.After(SW.WHO_WAIT, function()
        if zone == z and z.waiting then
            -- the same query again with the next click
            z.waiting = nil
            z.step = z.step - 1
            z.err = L["Das Spiel hat die Wer-Liste nicht geschickt; ein Klick versucht es wieder."]
            changed()
        end
    end)
    changed()
    return true
end

-- The zone's name as /who takes it.
function SW._zoneText() return ownZone() end

-- The /who answer: the names in the zone (own realm dropped), 50 at most.
local function whoNames(where)
    local fl = rawget(_G, "C_FriendList")
    local out = {}
    if type(fl) ~= "table" or type(fl.GetNumWhoResults) ~= "function" or type(fl.GetWhoInfo) ~= "function" then return out end
    local ok, n = pcall(fl.GetNumWhoResults)
    n = ok and tonumber(ns.Plain(n)) or 0
    for i = 1, math.min(n, SW.ZONE_MAX) do
        local okI, info = pcall(fl.GetWhoInfo, i)
        info = okI and ns.Plain(info) or nil
        local full = type(info) == "table" and ns.Plain(info.fullName) or nil
        local area = type(info) == "table" and ns.Plain(info.area) or nil
        local name = nameOf(full)
        if name and (not where or area == nil or area == where) then out[#out + 1] = name end
    end
    return out
end

-- The quiet questions to the names of one /who: not the own, not the guild's (they had YQ), not asked in this
-- search, not silent within SILENT_KEEP unless they answered within a week; who answered before goes first.
function SW._sendZone(z, names)
    local me = ns.UnitFullName("player")
    local db = hostsDB() or {}
    local t, cut = now(), time() - SW.HOST_KEEP
    local list = {}
    for _, name in ipairs(names) do
        local low = name:lower()
        local known = (tonumber(db[low]) or 0) >= cut
        local quiet = silent[low] and t - silent[low] < SW.SILENT_KEEP
        if not z.sent[low] and not (me and low == me:lower()) and not (ns.InGuild() and ns.GuildMember(name))
            and (known or not quiet) then
            list[#list + 1] = { name = name, low = low, known = known }
        end
    end
    table.sort(list, function(a, b)
        if a.known ~= b.known then return a.known end
        return a.low < b.low
    end)
    z.found = (z.found or 0) + #names
    for i = 1, math.min(#list, SW.ZONE_MAX) do
        local x = list[i]
        z.sent[x.low] = true
        ns.CommSend("ZQ", { z.req.id, z.req.map, z.req.uid or 0 }, "WHISPER", x.name, { anyone = true, low = true,
            ttl = SW.ZQ_TTL, key = "ZQ:" .. x.low, sent = function()
                if not silent[x.low] then silent[x.low] = now() end
                z.reached = z.reached + 1
                changed()
            end })
    end
    changed()
end

-- The self-test's probe (F-216, /amisia selbsttest layer, typed: a key press): one /who of the zone, whether the
-- client's who window stayed shut, one quiet question to the first name outside the guild and its answer.
local probe
function SW.ProbeZone()
    probe = { at = now() }
    local fl = rawget(_G, "C_FriendList")
    if whoBlocked then probe.skipped = "blocked" return probe end
    if type(fl) ~= "table" or type(fl.SendWho) ~= "function" then probe.skipped = "missing" return probe end
    if LY.InInstance() then probe.skipped = "instance" return probe end
    local ff = rawget(_G, "FriendsFrame")
    if type(ff) == "table" and type(ff.IsShown) == "function" and ff:IsShown() then probe.skipped = "friends" return probe end
    local where = SW._zoneText()
    if not where then probe.skipped = "zone" return probe end
    local p = probe
    mute()
    if type(fl.SetWhoToUi) == "function" then pcall(fl.SetWhoToUi, true) end
    tried("who")
    if not pcall(fl.SendWho, ('z-"%s"'):format(where)) then
        unmute()
        p.skipped = "error"
        return p
    end
    p.waiting = true
    -- no answer: nothing is whispered later from somebody else's list
    C_Timer.After(SW.WHO_WAIT, function() p.waiting = nil end)
    return p
end
function SW.Probe() return probe end

local function probeAnswer(p, names)
    p.waiting = nil
    p.count = #names
    local me = ns.UnitFullName("player")
    for _, name in ipairs(names) do
        if not (me and name:lower() == me:lower()) and not (ns.InGuild() and ns.GuildMember(name)) then
            p.to = name
            break
        end
    end
    local uid, map = LY.Current()
    map = map or LY.Map()
    if not p.to or not map then return end
    p.id = ("%04x"):format(math.random(0, 65535))
    ns.CommSend("ZQ", { p.id, map, uid or 0 }, "WHISPER", p.to, { anyone = true, ttl = 10,
        sent = function() p.sent = true end })
end

ns.OnEvent("WHO_LIST_UPDATE", function()
    local p, z = probe, zone
    local forProbe = p and p.waiting
    local forZone = z and z.waiting and z.req == req
    if mutedFrame then
        -- the window's event comes back on the next frame, after this answer went past it; the probe looks then
        -- whether the window opened anyway
        C_Timer.After(0, function()
            unmute()
            if forProbe then
                local ff = rawget(_G, "FriendsFrame")
                p.frameShown = type(ff) == "table" and type(ff.IsShown) == "function" and ff:IsShown() and true or false
            end
        end)
    end
    if not forProbe and not forZone then return end
    local names = whoNames(SW._zoneText())
    if forProbe then probeAnswer(p, names) end
    if forZone then
        z.waiting = nil
        SW._sendZone(z, names)
    end
end)

-- Host: a quiet question of a player in the zone. Every Amisia user in the same zone answers (ZA), with "helps"
-- when it would invite; a helping answer is remembered for the YI that follows.
ns.CommOn("ZQ", function(sender, f, chan)
    if chan ~= "WHISPER" or LY.InInstance() then return end
    local name = nameOf(sender)
    if not name then return end
    local id, map, uid = f[1], tonumber(f[2]), tonumber(f[3])
    if map ~= LY.Map() then return end
    local t = now()
    local keep = {}
    for _, at in ipairs(zqAt) do if t - at < SW.ZQ_WINDOW then keep[#keep + 1] = at end end
    zqAt = keep
    if #zqAt >= SW.ZQ_MAX then return end
    zqAt[#zqAt + 1] = t
    local mine, myMap = LY.Current()
    local fresh = mine ~= nil and myMap == map and LY.Fresh()
    local helps = fresh and mine ~= uid and SW.CanHelp() and ns.Get("layer.answer") and not asking() and SW.CanInvite()
    local low = name:lower()
    if helps then SW._answered(low, { id = id, map = map, uid = mine, at = t, stranger = true, name = name }) end
    ns.CommSend("ZA", { id, map, fresh and mine or 0, helps and 1 or 0 }, "WHISPER", name,
        { anyone = true, ttl = SW.ANSWER_WAIT, jitter = 1 })
end)

-- Asker: an answer to a quiet question of the open search.
ns.CommOn("ZA", function(sender, f, chan)
    local p = probe
    if chan == "WHISPER" and p and p.id and f[1] == p.id and p.to and (nameOf(sender) or ""):lower() == p.to:lower() then
        p.answer = { uid = tonumber(f[3]) or 0, helps = f[4] == "1" }
        return
    end
    local z = zone
    if chan ~= "WHISPER" or not z or not req or z.req ~= req or f[1] ~= req.id or now() - req.at > SW.REQ_LIFE then return end
    local name = nameOf(sender)
    if not name then return end
    local low = name:lower()
    if not z.sent[low] or tonumber(f[2]) ~= req.map then return end
    local uid, helps = tonumber(f[3]) or 0, f[4] == "1"
    silent[low] = nil
    rememberHost(name)
    if not z.heard[low] then
        z.heard[low] = true
        z.heardN = z.heardN + 1
        if helps then z.hosts = z.hosts + 1 end
        if helps and uid > 0 and uid ~= req.uid then z.other = z.other + 1 end
    end
    if helps and uid > 0 and uid ~= req.uid then return SW._addAnswer(req, name, uid, true) end
    changed()
end)

-- for the tests: name counts as asked by the open search
function SW._zoneSent(name) if zone then zone.sent[name:lower()] = true end end

---------------------------------------------------------------------------
-- "Layer wechseln" (part 8, F-214; the zone F-216)
---------------------------------------------------------------------------
-- What the button does now: "ask" (a new search), "wait" (asked, no answer picked yet), "more" (no answer:
-- the next click asks the next class of the zone), "channel" (no answer and nobody left to ask, or neither
-- guild nor zone: the channel line), "busy" (a request for an invite or a swap is open).
function SW.SwapStep()
    if swap or (pending and now() - pending.at <= SW.ACCEPT_WAIT) then return "busy" end
    local a = auto
    if a and req and a.req == req and now() - req.at <= SW.REQ_LIFE then
        if a.none then return SW.ZoneNext() and "more" or "channel" end
        if not a.picked then return "wait" end
    end
    if not ns.InGuild() and not SW.ZonePossible() then return "channel" end
    return "ask"
end

-- Stops the own search: no pick, no more questions, no invite taken by itself.
function SW.Stop()
    if not auto and not zone and not pending and not chatAt then return nil, L["Amisia fragt gerade nicht."] end
    auto, zone, pending, chatAt, chatAll = nil, nil, nil, nil, nil
    changed()
    return true
end

-- The pick's clock: no fitting answer within ANSWER_WAIT means "none".
local function armNone(a)
    C_Timer.After(SW.ANSWER_WAIT, function()
        if auto == a and not a.picking and not a.picked then
            a.none = true
            changed()
        end
    end)
end

-- The pick PICK_WAIT after the first fitting answer: the invite of the first answer in SW.Answers' order
-- (layers the own client has not seen first) of the layer a.target, else of any.
function SW._pick(a)
    if auto ~= a or req ~= a.req then return end
    a.picking = nil
    if pending or swap or inGroup() then a.picked = true return changed() end
    for _, x in ipairs(SW.Answers()) do
        if (not a.target or x.uid == a.target) and not (a.recent and a.recent[x.uid]) then
            a.picked = true
            local ok, why = SW.RequestInvite(x.name)
            if not ok and why then ns.msg(why) end
            return changed()
        end
    end
    a.none = true
    changed()
end

-- "Layer wechseln" (target nil) or a click on a layer's row (target its zoneUID). Returns true, or nil
-- and the reason.
-- onlyNew (or layer.onlyNew): only layers nobody saw in this zone within NEW_AGE. Inside a click (the zone's
-- /who needs one); a click while waiting or after no answer asks the next class of the zone.
function SW.Swap(target, onlyNew)
    target = tonumber(target)
    local step = SW.SwapStep()
    if step == "busy" then return nil, L["Ein Layer-Wechsel läuft schon."] end
    if (step == "wait" or step == "more") and not target then
        if not SW.ZoneNext() then return nil, L["Gefragt, warte auf Antworten ..."] end
        local a = auto
        a.none, a.picked = nil, nil
        req.at = now()
        armNone(a)
        return SW.AskZone()
    end
    if step == "wait" then return nil, L["Gefragt, warte auf Antworten ..."] end
    if step == "channel" and (not target or (not ns.InGuild() and not SW.ZonePossible())) then
        auto, zone = nil, nil
        return SW.AskChannel()
    end
    if target and LY.Current() == target then return nil, L["Du bist schon auf diesem Layer."] end
    local ok, why
    if ns.InGuild() then ok, why = SW.Ask() end
    local zoneOk = SW.ZonePossible()
    if not ok and not zoneOk then return nil, why or L["Das Spiel erlaubt Amisia gerade keine Wer-Abfrage."] end
    if not ok then
        ok, why = askAlone()
        if not ok then return nil, why end
    end
    local recent
    if onlyNew or ns.Get("layer.onlyNew") then
        recent = {}
        for _, e in ipairs(LY.List(req.map)) do
            if e.age < SW.NEW_AGE then recent[e.uid] = true end
        end
    end
    local a = { req = req, target = target, recent = recent }
    auto = a
    zone = nil
    if zoneOk then
        zone = { req = req, step = 0, classes = whoClasses(), sent = {}, heard = {}, heardN = 0, reached = 0, hosts = 0, other = 0 }
        local okZ, whyZ = SW.AskZone()
        if not okZ and whyZ then ns.msg(whyZ) end
    end
    armNone(a)
    changed()
    return true
end

-- What the window shows: the open question, the request, the swap.
function SW.State()
    local open = chatAt ~= nil and now() - chatAt <= SW.ACCEPT_WAIT
    local a = auto
    if a and a.req ~= req then a = nil end
    local z = zone
    if z and z.req ~= req then z = nil end
    return { req = req, pending = pending, swap = swap, answers = SW.Answers(),
        chat = open or nil, chatAll = open and chatAll or nil, auto = a, step = SW.SwapStep(),
        hosting = hosting, helped = helped, zone = z, zoneNext = SW.ZoneNext(), helping = SW.CanHelp(),
        pause = SW.InviteBreak() }
end

-- for the tests and the UI scene: st = { req, pending, swap } to start from (nil: nothing open)
function SW._reset(st)
    st = st or {}
    req, pending, swap, answered, invited, offered, chatAt = st.req, st.pending, st.swap, {}, {}, {}, st.chatAt
    chatAll, othersAt, lastCall, trace = st.chatAll, nil, nil, newTrace()
    hosting, helped, auto, question = true, { asked = 0, invited = 0, joined = 0 }, nil, nil
    zone, whoBlocked, lootBlocked, lootDone, silent, zqAt, probe = nil, nil, nil, nil, {}, {}, nil
    if mutedFrame then unmute() end
end

-- the saved hosts cleaned once the file is read (the body may run after that moment, D-128)
if type(AmisiaDB) == "table" then SW.LoadedHosts(AmisiaDB) end
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and type(AmisiaDB) == "table" then SW.LoadedHosts(AmisiaDB) end
end)
end)
