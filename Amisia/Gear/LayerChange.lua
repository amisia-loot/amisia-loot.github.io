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
-- "Gruppe verlassen" (SW.Leave) and (F-229: always) leaving by itself after layer.leaveSeconds,
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
-- Part 10 (F-220, D-145): the most widely used layer addon. With layer.foreign on and that addon not loaded
-- (Gear/LayerForeign.lua, LF.Active), ZQ goes only to the names AmisiaDB.layerHosts knows as Amisia users (a
-- positive time: they answered ZA); every other name of the /who gets that addon's quiet ask alone (LF.Ask),
-- at most one whisper per name and click; guild members of the /who (they had YQ) with layer.guildLast only
-- GUILD_WAIT seconds later when no helper from another layer answered by then. Its answers (heard, same) count
-- like ZA (SW._foreignAnswer: reached, heard, other layer) and keep the name in layerHosts with a negative time;
-- the first invite of a player who answered (and did not name the own layer) is the swap's, accepted with
-- layer.autoAccept; a heard helper from another layer holds "none" back once. The world restart (Layer.lua,
-- LY.Refresh) pauses helping; SHARD_TRANSFER during an own swap counts as the change.
-- Part 11 (F-221, D-146, changes D-139): behaves as the other layer addon does.
-- Helfen (the lock and the "on while the own ask runs" of D-146 are gone since F-229, part 12): off is kept
-- through /reload (layerHelp.off); only a real login
-- (PLAYER_ENTERING_WORLD with isInitialLogin) turns it on. SW.PauseReason: why helping waits (instance, group or
-- dungeon finder, someone else's group, combat, world restart, the invite break). Invites one a second
-- (INVITE_SPACING); open invites count PENDING_FOR seconds towards a full group; the game's "already in a
-- group" frees the place; a late accept after Helfen off (LATE_ACCEPT) is taken out again; the loot goes back to
-- the method before once a player Amisia did not invite joins.
-- Asking: one /who per search with the map filter of the zone (SendWho's third argument), the zone first, then
-- one class per search; refused: the zone by the client's WHO_TAG_ZONE and level bands. ZONE_MAX names, the own
-- zone first; the who lists of the game muted unless open. Asked without an answer: AmisiaDB.layerAsked (6 h,
-- ASKED_MAX); answered: layerHosts (7 days, HOST_MAX, h = it was helping: first in line); a name the server
-- calls offline rests GONE_FOR seconds; a host that invited from the own layer is skipped AVOID_FOR seconds. A
-- search lives REQ_LIFE seconds; a click on the running search stops it (not in its first STOP_GUARD second).
-- Judging a swap: scans after joining and every JUDGE_EVERY seconds; "not moved" from NO_MOVE_AFTER seconds on
-- without SHARD_TRANSFER and FRESH_OLD creatures of the old layer read since joining, or a restart that kept the
-- layer; leaving at STUCK_WAIT at the earliest; SHARD_TRANSFER alone is no success, a new layer read is (also
-- AFTER_GROUP seconds after the group ended); the real leader is the host after LEADER_WAIT; the automatic leave
-- (layer.leaveSeconds, 4) only from a helper who answered the ask. Warnings on an invite of a host that did
-- not move the player (NOT_MOVED_KEEP) or named the own layer.
-- Part 12 (F-229, D-159, changes D-146): as the other layer addon does it since game build 71037.
-- Helfen: no lock and no "on while the own ask runs" any more; off is off (an old forced "on" goes off at load).
-- Leaving: always (no setting) from the group of a helper who answered, layer.leaveSeconds after the join once the
-- game moved us, or that long after a later move. At the move the helper's answered number is taken for the own
-- layer (LY.Take "host", shown at once). REFUSE_AFTER seconds after the join without a move the game's phase mark on
-- the helper (UnitPhaseReason, only when the group shows it in the own zone) decides: "apart" = the game refused to
-- move us (left at once, the hour held: below); no mark where the numbers are private (LY.Private) = it stands with
-- us (left at once, its number taken unless the own one came from a helper, skipped MOVER_FOR seconds). Where the
-- numbers are private and the game tells nothing, no move STUCK_WAIT seconds after the join is "not moved".
-- The game's limit: CAP moves as a guest in an hour; an hour opens with the first move after the last one closed.
-- AmisiaDB.layerCap[character] = { start, moves, hold, unsure } (epochs) keeps them through /reload and logins;
-- with CAP in the running hour, or while a refusal holds (until the first of the last CAP moves is CAP_FOR old, with
-- fewer known CAP_UNSURE seconds), no ask goes out. No ask either in a fight and COMBAT_REST seconds after it, while
-- dead or a ghost, or on a flight path (SW.Blocked); a fight that starts ends the search (an invite already in stays).
-- layer.combatPause (on) pauses helping in a fight and HOST_REST seconds after it. A search ends INVITE_WAIT seconds
-- after it began when no invite came (an invite later still counts for REQ_LIFE). Asked without an answer: SILENT_KEEP
-- (15 minutes). SW.Event: what the window's event field says (a happening for EVENT_FOR seconds, a wait while it lasts).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local SW = {}
ns.LayerChange = SW
local LY = ns.Layer

SW.ASK_GAP = 10          -- seconds between two own questions
SW.ANSWER_WAIT = 10      -- seconds the window waits before "no answer"
SW.REQ_LIFE = 120        -- seconds a search, its answers and a request for an invite stay good (F-221: 120)
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
SW.ZONE_MAX = 49        -- quiet questions per search (F-221: 49, the own name never)
SW.ZQ_TTL = 45          -- seconds a quiet question may wait in the send queue
SW.HOST_KEEP = 7 * 86400   -- seconds a player who answered stays first in line (AmisiaDB.layerHosts)
SW.HOST_MAX = 300
SW.SILENT_KEEP = 15 * 60   -- seconds a player asked without an answer is not asked again (F-229: 15 minutes)
SW.ZQ_WINDOW, SW.ZQ_MAX = 60, 20   -- quiet questions answered per minute at most
SW.STUCK_WAIT = 15      -- seconds after joining before a read of the old layer means "not moved"
SW.GUILD_WAITS = { 3 }   -- F-221: seconds after the zone's asks went before the guild members of the /who are asked
-- F-221 (D-146)
SW.INVITE_SPACING = 1    -- seconds between two invites
SW.PENDING_FOR = 60      -- seconds an open invite counts towards a full group
SW.LATE_ACCEPT = 300     -- seconds an invite accepted after Helfen off is taken out again
SW.ASKED_MAX = 3000      -- names in AmisiaDB.layerAsked
SW.GONE_FOR = 600        -- seconds a name the server called offline is not asked
SW.AVOID_FOR = 20        -- seconds a host that invited from the own layer is not asked
SW.NOT_MOVED_KEEP = 600  -- seconds a host that did not move the player is warned of
SW.JUDGE_STEPS = { 0, 1, 3 }   -- seconds after joining: a scan
SW.JUDGE_EVERY = 2       -- then a scan every this many seconds until CHANGE_WAIT
SW.NO_MOVE_AFTER = 5     -- seconds after joining before "not moved" may be said
SW.FRESH_OLD = 3         -- creatures of the old layer read after joining that mean "not moved"
SW.AFTER_GROUP = 30      -- seconds after the group ended in which a new layer still counts
SW.LEADER_WAIT = 5       -- seconds after joining when the group's leader counts as the host
SW.STOP_GUARD = 1        -- seconds a search runs before its button stops it
SW.WARN_FOR = 30         -- seconds a warning on an invite shows
SW.WHO_CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }   -- the classes of Forever, one per search
SW.WHO_BANDS = 6         -- level bands of the /who by text
-- F-229 (D-159)
SW.INVITE_WAIT = 8       -- seconds a search waits for an invite, then it ends
SW.REFUSE_AFTER = 3      -- seconds after joining without a move before the game's phase mark on the helper is read
SW.MOVER_FOR = 600       -- seconds a helper the game showed on the own layer is not asked
SW.CAP, SW.CAP_FOR, SW.CAP_UNSURE = 10, 3600, 15 * 60   -- the game's moves per hour; a refusal with fewer known holds
SW.CAP_WARN = 3          -- from this many moves left the button counts them
SW.COMBAT_REST = 6       -- seconds after a fight without an ask
SW.HOST_REST = 2         -- seconds after a fight helping stays paused (layer.combatPause)
SW.EVENT_FOR = 60        -- seconds the event field shows a happening
SW.LATE_MOVE = 5         -- seconds after the verdict of refusal in which a move still counts as one
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
local silentMem = {} -- asker: [lower name] = epoch a quiet question went without an answer (without AmisiaDB)
local zqAt = {}      -- host: times of the quiet questions answered within ZQ_WINDOW
local muted = {}     -- [frame name] = the client's who list while it does not hear WHO_LIST_UPDATE
local mutedAt
-- F-221
local warning        -- { text, at, name }: the warning on an invite
local offAt          -- host: the time Helfen went off
local lastInviteAt   -- host: the time of the last invite
local lootWas, lootBack   -- host: the loot method before free for all; set back once
local gone = {}      -- asker: [lower name] = time the server called the name offline
local avoid = {}     -- asker: [lower name] = { at, uid } a host that invited from the own layer
local notMoved = {}  -- asker: [lower name] = time the host did not move the player
local afterGroup     -- { s, untilAt }: a swap whose group ended before the verdict
local whoRound = 0   -- the /who of the next search: 0 the zone, then a class (map) or a level band (text)
local noMap          -- the client refused the map filter this session
-- F-229
local fighting, foughtAt   -- in a fight; the time the last fight ended (or the fight's start while in it)
local event          -- { kind, at, ... }: the last happening for the event field

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

-- F-221: the invites sent within PENDING_FOR seconds that neither joined nor were refused (they count towards
-- a full group).
local function pendingInvites()
    local t, n = now(), 0
    for _, x in ipairs(invited) do
        if not x.joined and not x.freed and t - x.at < SW.PENDING_FOR and not (x.name and ns.InMyGroup(x.name)) then n = n + 1 end
    end
    return n
end

-- Whether the own character may invite now (F-216): alone, or the leader of a party with room that holds
-- only players Amisia invited for swaps; open invites take room too (F-221).
function SW.CanInvite()
    local open = pendingInvites()
    if not inGroup() then return 1 + open < 5 end
    if inRaid() or not unitFlag("UnitIsGroupLeader", "player") or members() + open >= 5 then return false end
    return #guestsInGroup() >= members() - 1
end

-- Whether the own character is listed in the group finder or (F-221) queued in the dungeon finder, in its role
-- check or proposal.
local function inGroupFinder()
    local api = rawget(_G, "C_LFGList")
    local f = type(api) == "table" and api.HasActiveEntryInfo
    if type(f) == "function" then
        local ok, v = pcall(f)
        if ok and ns.Plain(v) == true then return true end
    end
    local mode = rawget(_G, "GetLFGMode")
    if type(mode) ~= "function" then return false end
    for c = 1, math.min(tonumber(ns.Plain(rawget(_G, "NUM_LE_LFG_CATEGORYS"))) or 0, 10) do
        local ok, m = pcall(mode, c)
        m = ok and ns.Plain(m) or nil
        if m == "queued" or m == "listed" or m == "rolecheck" or m == "proposal" then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- F-229: fights, death, the flight path
---------------------------------------------------------------------------
-- The poll catches a fight whose events were missed; it ends one only a second after the last sign of it (in
-- PLAYER_REGEN_DISABLED itself InCombatLockdown still says no).
local function watchFight()
    local f = inCombat()
    if f then
        fighting, foughtAt = true, now()
    elseif fighting and now() - foughtAt > 1 then
        fighting, foughtAt = nil, now()
    end
end

-- true in a fight, the seconds of COMBAT_REST left after it, nil when an ask may go.
function SW.FightLeft()
    watchFight()
    if fighting then return true end
    if not foughtAt then return nil end
    local left = SW.COMBAT_REST - (now() - foughtAt)
    return left > 0 and left or nil
end

-- Whether helping rests for combat now: in a fight or HOST_REST seconds after it.
function SW.HostResting()
    watchFight()
    return fighting == true or (foughtAt ~= nil and now() - foughtAt < SW.HOST_REST)
end

local function dead() return unitFlag("UnitIsDeadOrGhost", "player") end
local function onTaxi() return unitFlag("UnitOnTaxi", "player") end

-- A fight starts or the player dies: the search ends and nobody new is asked; an invite already in, and the
-- helper's group, stay.
local function fightStart()
    if swap then return end
    local stopped = false
    if auto or zone then stopped = true end
    auto, zone = nil, nil
    if pending and not pending.invited then pending, stopped = nil, true end
    if chatAt then chatAt, chatAll, stopped = nil, nil, true end
    if ns.LayerForeign and ns.LayerForeign.StopAsks then ns.LayerForeign.StopAsks() end
    if stopped then ns.Fire("LAYER_CHANGE") end
end
SW._fightStart = fightStart
ns.OnEvent("PLAYER_REGEN_DISABLED", function()
    fighting, foughtAt = true, now()
    fightStart()
end)
ns.OnEvent("PLAYER_REGEN_ENABLED", function()
    fighting, foughtAt = nil, now()
    ns.Fire("LAYER_CHANGE")
end)
ns.OnEvent("PLAYER_DEAD", function() fightStart() end)

-- Why no ask may go now (a fight and its rest, death, a flight path, the game's hourly limit), nil when one may.
-- Returns the reason and its kind ("fight", "dead", "taxi", "cap").
function SW.Blocked()
    local fight = SW.FightLeft()
    if fight == true then return L["Kein Layer-Wechsel im Kampf."], "fight" end
    if fight then return L["Kein Layer-Wechsel direkt nach dem Kampf: noch %d s."]:format(math.ceil(fight)), "fight" end
    if dead() then return L["Kein Layer-Wechsel, solange du tot bist."], "dead" end
    if onTaxi() then return L["Kein Layer-Wechsel im Flug."], "taxi" end
    local left = SW.CapLeft()
    if left > 0 then return L["Keine Layer-Wechsel mehr für diese Stunde: noch %s."]:format(SW.Clock(left)), "cap" end
    return nil
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
local function canHelp()
    if not hosting then return false end
    -- F-220: no invites while the game counts down to a world restart
    if LY.Refresh and LY.Refresh() then return false end
    if ns.Get("layer.combatPause") and SW.HostResting() then return false end
    return not inGroupFinder()
end
SW.CanHelp = canHelp

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
    if not LY.Known() then return nil, L["Layer unbekannt: ziele oder überfahre erst einen NPC."] end
    if req and now() - req.at < SW.ASK_GAP then return nil, L["Einmal alle 10 Sekunden."] end
    local blockedWhy = SW.Blocked()
    if blockedWhy then return nil, blockedWhy end
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
    if not LY.Known() then return nil, L["Layer unbekannt: ziele oder überfahre erst einen NPC."] end
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

-- Whether the own ask runs (F-221): a search not ended (REQ_LIFE), a request for an invite, a chat request, the
-- swap's group. Helfen stays on meanwhile.
local function ownAsk()
    local t = now()
    if swap or (pending and t - pending.at <= SW.ACCEPT_WAIT) or (chatAt and t - chatAt <= SW.ACCEPT_WAIT) then return true end
    local a = auto
    return a ~= nil and req ~= nil and a.req == req and not a.none and not (a.picked and not pending) and t - req.at <= SW.REQ_LIFE
end
SW.OwnAsk = ownAsk

-- Whether the own character is asking for a layer change right now (a question to the guild, a request
-- for an invite, a chat request): then it is nobody's host, or two askers would invite each other (F-214: two
-- players pressing "Layer wechseln" together neither answer nor ask each other).
local function asking()
    return ownAsk() or (req ~= nil and now() - req.at <= SW.ANSWER_WAIT)
end
SW.Asking = asking

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
        -- F-221: an unknown own layer is read from the units in view first
        if not mine then
            LY.Rescan()
            mine, myMap = LY.Current()
        end
        -- F-229: the number given up for a taken one counts as the own layer too (LY.Ours)
        if not mine or myMap ~= map or LY.Ours(uid) then return end
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
    if a and a.req == r and not a.picking and not a.picked and not pending and not swap and (not a.target or a.target == uid) then
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
    if not req or now() - req.at > SW.REQ_LIFE then return nil, L["Die Antworten sind älter als zwei Minuten: frag noch einmal."] end
    local a
    for _, x in ipairs(req.answers) do
        if x.name:lower() == tostring(name):lower() then a = x break end
    end
    if not a then return nil, L["Dieses Mitglied hat nicht geantwortet."] end
    local blockedWhy = SW.Blocked()
    if blockedWhy then return nil, blockedWhy end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    if pending and now() - pending.at < SW.REQUEST_GAP then return nil, L["Einmal alle 10 Sekunden."] end
    local sent, err = ns.CommSend("YI", { req.id, req.map, a.uid }, "WHISPER", a.name, { ttl = SW.ANSWER_WAIT, anyone = a.stranger })
    if not sent then return nil, err end
    pending = { name = a.name, uid = a.uid, map = req.map, from = req.uid, at = now(), answered = true }
    changed()
    return true
end

-- Host: invites name (guild member who asked). Returns true, or nil and the reason. F-221: one invite a second
-- (a second one within it goes a moment later).
function SW.Invite(name, quiet)
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    local t, low = now(), name:lower()
    if lastInviteAt and t - lastInviteAt < SW.INVITE_SPACING then
        C_Timer.After(SW.INVITE_SPACING - (t - lastInviteAt) + 0.01, function()
            if not hosting then return end
            local ok, why = SW.Invite(name, quiet)
            if not ok and why then ns.msg(why) end
        end)
        return true
    end
    if not SW.CanInvite() then return nil, L["Du kannst gerade niemanden einladen (Gruppe voll oder nicht Leiter)."] end
    local keep, n = {}, 0
    for _, x in ipairs(invited) do
        local recent = t - x.at < SW.INVITE_WINDOW
        -- a guest still in the group stays known (SW.CanInvite, SW.Kick), without counting for the limit
        if recent or (x.joined and x.name and ns.InMyGroup(x.name)) then keep[#keep + 1] = x end
        if recent then
            n = n + 1
            if x.low == low and t - x.at < SW.INVITE_GAP and not x.freed then
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
    lastInviteAt = t
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
        -- a stranger: without a question only with "Fremde ohne Frage einladen" (layer.othersAuto)
        SW.Offer(a.name or name, L["%s möchte auf deinen Layer wechseln (%s). Einladen?"]:format(a.name or name, LY.Name(myMap, mine)), true,
            nil, a.stranger and "layer.othersAuto" or nil)
    end
    -- a player outside the guild that this client answered with ZA (F-216): no roster to wait for; only while
    -- layer.others is on (it may have been turned off since the answer)
    if a.stranger then
        if ns.Get("layer.others") ~= true and not ns.GuildMember(name) then return end
        return go()
    end
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
-- "Helfen" (part 8, F-214; F-221: kept in AmisiaDB.layerHelp, held on by the own ask and the lock)
---------------------------------------------------------------------------
function SW.Hosting() return hosting end
function SW.Helped() return helped end

local function myName() return ns.UnitFullName("player") end
local function isMe(name)
    local me = myName()
    return type(name) == "string" and type(me) == "string" and name:lower() == me:lower()
end

local function helpDB()
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.layerHelp) ~= "table" then AmisiaDB.layerHelp = {} end
    return AmisiaDB.layerHelp
end

-- "3:41"
local function clock(secs)
    secs = math.max(0, math.ceil(tonumber(secs) or 0))
    return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end
SW.Clock = clock

-- Off: closes an open "... Einladen?" of Amisia's and (F-216) takes the guests of swaps out of the group.
local function goOff()
    hosting = false
    offAt = now()
    local q = question
    if q then
        question = nil
        if q.frame and q.frame.IsShown and q.frame:IsShown() and q.frame.onOk == q.fn then q.frame:Hide() end
    end
    SW.Kick(true)
end

-- Switches the helping (F-229: off is off; nothing holds it on). Off lasts through /reload until the next login.
-- Returns hosting.
function SW.SetHosting(on)
    on = on and true or false
    local hd = helpDB()
    if hd then hd.off = (not on) or nil end
    if on then hosting = true else goOff() end
    changed()
    return hosting
end

-- Why helping waits now (F-221), nil when it does not (or Helfen is off).
function SW.PauseReason()
    if not hosting then return nil end
    if LY.InInstance() then return L["in einer Instanz"] end
    if inGroupFinder() then return L["in der Gruppensuche oder Dungeonsuche"] end
    if inGroup() and not SW.CanInvite() then return L["in einer fremden Gruppe"] end
    if ns.Get("layer.combatPause") and SW.HostResting() then return L["im Kampf"] end
    if LY.Refresh and LY.Refresh() then return L["Neustart der Welt"] end
    if SW.InviteBreak() > 0 then return L["Pause nach sechs Einladungen"] end
    return nil
end

-- The saved switch kept clean (on load): off true only. F-229: the lock of D-146 is gone; a Helfen that Amisia had
-- turned on for an own ask (forced, this character) goes off again, as it said it would.
function SW.LoadedHelp(DB)
    local hd = DB and DB.layerHelp
    if hd == nil then return end
    if type(hd) ~= "table" then DB.layerHelp = nil return end
    if isMe(hd.forced) then hd.off = true end
    for k in pairs(hd) do
        if k ~= "off" then hd[k] = nil end
    end
    if hd.off ~= true then hd.off = nil end
end

local function loadHelp()
    if type(AmisiaDB) ~= "table" then return end
    SW.LoadedHelp(AmisiaDB)
    local hd = AmisiaDB.layerHelp
    hosting = not (hd and hd.off)
end

-- A real login turns Helfen on; a /reload keeps it as it was.
ns.OnEvent("PLAYER_ENTERING_WORLD", function(initial)
    if ns.Plain(initial) ~= true then return end
    local hd = helpDB()
    if hd then hd.off = nil end
    if not hosting then
        hosting = true
        changed()
    end
end)

---------------------------------------------------------------------------
-- F-229: the game's limit of CAP moves an hour (AmisiaDB.layerCap, per character, by the clock)
---------------------------------------------------------------------------
local function capDB()
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.layerCap) ~= "table" then AmisiaDB.layerCap = {} end
    return AmisiaDB.layerCap
end

-- This character's record, nil when none (create: a new one).
local function capRecord(create)
    local db, me = capDB(), myName()
    if not db or type(me) ~= "string" then return nil end
    local c = db[me]
    if type(c) ~= "table" or type(c.start) ~= "number" or type(c.moves) ~= "table" then
        if not create then return nil end
        c = { start = time(), moves = {} }
        db[me] = c
    end
    return c
end

-- The running hour of c: its start and the moves in it (none when it closed).
local function capHour(c, t)
    if t - c.start >= SW.CAP_FOR then return t, 0 end
    local n = 0
    for _, at in ipairs(c.moves) do
        if at >= c.start then n = n + 1 end
    end
    return c.start, n
end

-- The moves of the running hour (0 while none is known).
function SW.CapUsed()
    local c = capRecord()
    if not c then return 0 end
    local _, n = capHour(c, time())
    return n
end

-- Seconds until the game moves this character again; 0 when it does now.
function SW.CapLeft()
    local c = capRecord()
    if not c then return 0 end
    local t = time()
    if type(c.hold) == "number" and t < c.hold then return c.hold - t end
    local from, n = capHour(c, t)
    if n >= SW.CAP then return from + SW.CAP_FOR - t end
    return 0
end

-- Whether the last hold came from the game's refusal (not from the count).
function SW.CapRefused()
    local c = capRecord()
    return c ~= nil and type(c.hold) == "number" and time() < c.hold
end

-- A move as a guest in a helper's group: counted. Moved although held: the game's hour was over before ours, the
-- hours start anew with this move.
function SW._capMoved()
    local c = capRecord(true)
    if not c then return end
    local t = time()
    if SW.CapLeft() > 0 then c.start, c.moves, c.hold, c.unsure = t, {}, nil, nil end
    if t - c.start >= SW.CAP_FOR then c.start = t end
    c.moves[#c.moves + 1] = t
    while #c.moves > 2 * SW.CAP or (c.moves[1] and t - c.moves[1] > 2 * SW.CAP_FOR) do table.remove(c.moves, 1) end
end

-- The game refused to move us: with CAP moves known within the hour, held until the first of them is CAP_FOR old
-- (the hours counted from it); with fewer, CAP_UNSURE seconds.
function SW._capRefused()
    local c = capRecord(true)
    if not c then return end
    local t = time()
    local first = c.moves[#c.moves - SW.CAP + 1]
    if first and t - first < SW.CAP_FOR then
        c.start, c.hold, c.unsure = first, first + SW.CAP_FOR, nil
    else
        c.hold, c.unsure = t + SW.CAP_UNSURE, true
    end
end

-- The record as it is (for SW._capRestore), false when there is none.
function SW._capSnapshot()
    local c = capRecord()
    if not c then return false end
    local moves = {}
    for i, at in ipairs(c.moves) do moves[i] = at end
    return { start = c.start, moves = moves, hold = c.hold, unsure = c.unsure }
end

-- A refusal taken back: the record as it was before it (false: none).
function SW._capRestore(before)
    local db, me = capDB(), myName()
    if not db or type(me) ~= "string" then return end
    db[me] = before or nil
end

-- The saved counts kept clean (on load): a name, numbers only, and only what still holds or counts.
function SW.LoadedCap(DB)
    local db = DB and DB.layerCap
    if db == nil then return end
    if type(db) ~= "table" then DB.layerCap = nil return end
    local t, n = time(), 0
    for who, c in pairs(db) do
        local ok = type(who) == "string" and who ~= "" and #who <= 64 and not who:find("[%c|]") and type(c) == "table"
            and type(c.start) == "number" and c.start <= t + 60 and type(c.moves) == "table" and n < 50
        if ok then
            local moves = {}
            for _, at in ipairs(c.moves) do
                if type(at) == "number" and at <= t + 60 and t - at <= 2 * SW.CAP_FOR and #moves < 2 * SW.CAP then moves[#moves + 1] = at end
            end
            c.moves = moves
            if type(c.hold) ~= "number" or c.hold < t or c.hold > t + SW.CAP_FOR + 60 then c.hold = nil end
            c.unsure = (c.hold and c.unsure == true) or nil
            for k in pairs(c) do
                if k ~= "start" and k ~= "moves" and k ~= "hold" and k ~= "unsure" then c[k] = nil end
            end
            local last = moves[#moves]
            ok = c.hold ~= nil or (last ~= nil and t - last < SW.CAP_FOR)
        end
        if ok then n = n + 1 else db[who] = nil end
    end
    if next(db) == nil then DB.layerCap = nil end
end

---------------------------------------------------------------------------
-- F-229: the event field (what just happened, or why no ask goes)
---------------------------------------------------------------------------
-- A happening: kind "moved", "same", "elsewhere", "refused", "none", "notMoved"; name the helper.
local function note(kind, name)
    event = { kind = kind, at = now(), name = name }
    changed()
end
SW._note = note

-- What the event field says now, nil while nothing happens: { kind, col ("ok", "warn", "info"), head, body, tag (a time
-- at the right), used (the moves of the hour) }.
function SW.Event()
    local t = now()
    local used = SW.CapUsed()
    local e = event
    if e and t - e.at < SW.EVENT_FOR then
        local who = e.name or L["Der Helfer"]
        if e.kind == "moved" then
            return { kind = e.kind, col = "ok", head = L["Gewechselt"], used = used,
                body = L["%s hat dich auf einen anderen Layer gebracht. Amisia verlässt die Gruppe gleich."]:format(who) }
        elseif e.kind == "same" then
            return { kind = e.kind, col = "warn", head = L["Der Helfer stand auf deinem Layer"], used = used,
                body = L["%s stand auf deinem Layer, das Spiel hatte nichts zu bewegen; kein Wechsel verbraucht. Layer wechseln fragt andere Helfer."]:format(who) }
        elseif e.kind == "elsewhere" then
            return { kind = e.kind, col = "info", head = L["Helfer in einer anderen Zone"], used = used,
                body = L["%s war in einer anderen Zone, darum hat das Spiel dich nicht bewegt; kein Wechsel verbraucht."]:format(who) }
        elseif e.kind == "notMoved" then
            return { kind = e.kind, col = "warn", head = L["Nicht gewechselt"], used = used,
                body = L["%s hat dich nicht bewegt. Amisia hat die Gruppe verlassen; Layer wechseln fragt andere Helfer."]:format(who) }
        elseif e.kind == "none" then
            return { kind = e.kind, col = "info", head = L["Kein Helfer hat geantwortet"], used = used,
                body = L["Niemand, der dich bewegen kann, hat eingeladen. Helfer sind Spieler mit Amisia oder dem anderen Layer-Addon und eingeschaltetem Helfen; in belebten Zonen gibt es mehr."] }
        end
    end
    local left = SW.CapLeft()
    if left > 0 then
        if SW.CapRefused() then
            return { kind = "refused", col = "warn", head = L["Das Spiel hat dich nicht bewegt"], tag = clock(left), used = used,
                body = L["Ein Helfer auf einem anderen Layer hat eingeladen, aber das Spiel hat dich nicht bewegt: es erlaubt %d Wechsel je Stunde. Amisia wartet so lange."]:format(SW.CAP) }
        end
        return { kind = "full", col = "warn", head = L["Keine Wechsel mehr für diese Stunde"], tag = clock(left), used = used,
            body = L["Das Spiel bewegt einen Charakter %d-mal je Stunde, deine sind verbraucht. Amisia wartet, damit dich niemand umsonst einlädt."]:format(SW.CAP) }
    end
    if swap then return nil end
    local why, kind = SW.Blocked()
    if kind == "fight" then
        local f = SW.FightLeft()
        return { kind = "fight", col = "warn", head = L["Warum Layer wechseln aus ist"], tag = f ~= true and clock(f) or nil, used = used,
            body = L["Kein Layer-Wechsel im Kampf und %d Sekunden danach: ein Wechsel ist kein Weg aus einem Kampf."]:format(SW.COMBAT_REST) }
    elseif kind == "dead" then
        return { kind = "dead", col = "warn", head = L["Warum Layer wechseln aus ist"], used = used,
            body = L["Kein Layer-Wechsel, solange du tot oder ein Geist bist: ein Wechsel ist kein Weg an Spielern an deiner Leiche vorbei."] }
    elseif kind == "taxi" then
        return { kind = "taxi", col = "warn", head = L["Warum Layer wechseln aus ist"], used = used,
            body = L["Du fliegst. Das Spiel bewegt niemanden in der Luft; nach der Landung geht Layer wechseln wieder."] }
    end
    if inGroup() and not ownAsk() then
        return { kind = "group", col = "warn", head = L["Warum Layer wechseln aus ist"], used = used,
            body = L["Du bist in einer Gruppe. Ein Wechsel ist die Einladung eines Helfers in seine Gruppe: erst diese verlassen."] }
    end
    return why and { kind = "off", col = "warn", head = L["Warum Layer wechseln aus ist"], body = why, used = used } or nil
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
ns.OnEvent("CHAT_MSG_GUILD", function(text, sender)
    -- F-221: the other layer addon's tagged line (Gear/LayerForeign.lua answers it)
    local LF = ns.LayerForeign
    if LF and LF.GuildLine and LF.GuildLine(text, sender) then return end
    SW.ChatLine(text, sender, "GUILD")
end)
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

-- Asker: "Im Gildenchat fragen" opens the chat box with "/g <text>" (the player sends it with Enter). F-221: with
-- the other layer addon's way on and the own layer known, the line carries zone, layer and place
-- ("inv layer <LS ...>", LF.GuildText), which that addon's helpers need to answer a guild line.
function SW.AskChat()
    if not ns.InGuild() then return nil, L["Du bist in keiner Gilde."] end
    if LY.InInstance() then return nil, L["Nicht in einer Instanz."] end
    local blockedWhy = SW.Blocked()
    if blockedWhy then return nil, blockedWhy end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    local LF = ns.LayerForeign
    local tagged = LF and LF.Active() and LF.GuildText and LF.GuildText() or nil
    local ok, why = openChat("/g " .. (tagged or SW.ChatText(ns.Get("layer.chatText")) or "inv layer"))
    if not ok then return nil, why end
    chatAt, chatAll, pending, auto, zone, event = now(), nil, nil, nil, nil, nil
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
    local blockedWhy = SW.Blocked()
    if blockedWhy then return nil, blockedWhy end
    if inGroup() then return nil, L["Erst die Gruppe verlassen: nur wer allein ist, kann eingeladen werden."] end
    local n, name = SW.Channel()
    if not name then return nil, L["Du bist in keinem Kanal %d (Einstellungen, Layer: Kanal)."]:format(n) end
    local ok, why = openChat(("/%d %s"):format(n, SW.ChatText(ns.Get("layer.chatText")) or "inv layer"))
    if not ok then return nil, why end
    chatAt, chatAll, pending, auto, zone, event = now(), true, nil, nil, nil, nil
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
    -- F-229: never by itself in a fight, dead, in flight or with the hour's moves used up (the game's question stays)
    if SW.Blocked() then return false end
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

-- F-220: the first invite of a player who answered the own search on the other layer addon's prefix (not one
-- that named the own layer) is the swap's; it takes the place of a request for an invite that got none yet.
local function foreignInvite(f)
    pending = { name = f.name, uid = f.uid, zuid = f.zuid, map = req and req.map or LY.Map(), from = req and req.uid, at = now(),
        invited = now(), foreign = true, answered = true }
    -- F-221: the first invite ends the asks still waiting to go
    if ns.LayerForeign and ns.LayerForeign.StopAsks then ns.LayerForeign.StopAsks() end
    changed()
    if not ns.Get("layer.autoAccept") or inGroup() or LY.InInstance() then return end
    if accept() then
        pending.accepted = true
        ns.msg(L["Einladung von %s angenommen (Layer-Wechsel)."]:format(f.name))
    end
end

-- F-221: the warning on an invite of name, nil when none: a host that did not move the player within
-- NOT_MOVED_KEEP, one whose answer named the own layer.
function SW.InviteWarning(name)
    local low = tostring(name):lower()
    local t = now()
    if notMoved[low] and t - notMoved[low] < SW.NOT_MOVED_KEEP then
        return L["%s hat dich vor Kurzem nicht bewegt: ablehnen und warten."]:format(name)
    end
    local z = zone
    local a = z and z.req == req and req and t - req.at <= SW.REQ_LIFE and z.answered and z.answered[low]
    if a and a.uid and a.uid == req.uid then return L["%s ist auf deinem Layer: ablehnen und warten."]:format(name) end
    return nil
end

-- The warning of the last invite while it shows (WARN_FOR), else nil.
function SW.Warning()
    if warning and now() - warning.at <= SW.WARN_FOR and not swap then return warning.text end
    warning = nil
    return nil
end

function SW.InviteRequest(raw)
    local name = nameOf(raw)
    if not name then return end
    -- F-229: also after the search ended (8 s): the answers and the hosts that did not move us still warn
    local warn = not swap and SW.InviteWarning(name) or nil
    if warn then
        -- never taken by itself; the game's own question stays
        warning = { text = warn, at = now(), name = name }
        -- a host on the own layer is not asked again for a while (AVOID_FOR)
        local za = zone and zone.answered and zone.answered[name:lower()]
        if za and req and za.uid == req.uid then avoid[name:lower()] = { at = now(), uid = req.uid } end
        ns.msg(warn)
        changed()
        return
    end
    local f = not swap and SW._foreignInviter(name) or nil
    if f and (not pending or (not pending.invited and not pending.accepted) or now() - pending.at > SW.ACCEPT_WAIT) then
        return foreignInvite(f)
    end
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
    swap.leaving = true
    return true
end

-- The host did not move the player (F-216; F-221 as the other layer addon judges it): from NO_MOVE_AFTER seconds
-- on without SHARD_TRANSFER, FRESH_OLD creatures of the old layer read since joining; or a world restart that
-- kept the old layer; F-229: where the numbers are private (no creature ever shows the old one) no move STUCK_WAIT
-- seconds after joining. Amisia leaves the group STUCK_WAIT seconds after joining at the earliest; "Layer wechseln"
-- is offered again, and that host is skipped for a while.
local function checkStuck(s)
    if swap ~= s or s.changed or s.stuck or not s.from then return end
    local since = now() - s.at
    local uid, map = LY.Current()
    local kept = s.transferAt and uid == s.from and map == s.map
    local old = not s.transferAt and since >= SW.NO_MOVE_AFTER and s.freshN >= SW.FRESH_OLD
    local silent = not s.transferAt and LY.Private() and since >= SW.STUCK_WAIT
    if not kept and not old and not silent then return end
    s.stuck, s.failed = true, true
    trace.stuck = trace.stuck + 1
    local low = s.host:lower()
    notMoved[low] = now()
    avoid[low] = { at = now(), uid = s.from }
    note("notMoved", s.host)
    C_Timer.After(math.max(0, SW.STUCK_WAIT - since), function()
        if swap ~= s then return end
        if not s.leaving and SW.Leave(true) then
            ns.msg(L["Der Wechsel über %s hat nicht geklappt: Amisia verlässt die Gruppe, Layer wechseln geht wieder."]:format(s.host))
        else
            ns.msg(L["Der Wechsel über %s hat nicht geklappt."]:format(s.host))
        end
    end)
end

-- F-229: the zone map of the group member called name and its unit, nil when not in the group or unknown.
local function memberUnit(name)
    local low = tostring(name):lower()
    for i = 1, 4 do
        local unit = "party" .. i
        if unitFlag("UnitExists", unit) then
            local ok, n = pcall(ns.UnitFullName, unit)
            n = ok and nameOf(n) or nil
            if n and n:lower() == low then return unit end
        end
    end
    return nil
end

-- F-229: how the game marks the group member name against us (UnitPhaseReason, the party frame's phase symbol):
-- "here" no mark, "apart" another layer (sharding), nil when the game tells nothing; and whether the group shows
-- it in the own zone (true), in another (false) or nobody knows (nil).
function SW._hostMark(name)
    local unit = memberUnit(name)
    if not unit then return nil, nil end
    local zoneHere
    local api = rawget(_G, "C_Map")
    if type(api) == "table" and type(api.GetBestMapForUnit) == "function" then
        local ok1, a = pcall(api.GetBestMapForUnit, "player")
        local ok2, b = pcall(api.GetBestMapForUnit, unit)
        a, b = ok1 and tonumber(ns.Plain(a)) or nil, ok2 and tonumber(ns.Plain(b)) or nil
        if a and b then zoneHere = a == b end
    end
    local f = rawget(_G, "UnitPhaseReason")
    if type(f) ~= "function" then return nil, zoneHere end
    local ok, r = pcall(f, unit)
    if not ok then return nil, zoneHere end
    if r == nil then return "here", zoneHere end
    r = ns.Plain(r)
    local sharding = Enum and Enum.PhaseReason and Enum.PhaseReason.Sharding or 1
    if r == sharding then return "apart", zoneHere end
    return nil, zoneHere
end

-- F-229: REFUSE_AFTER seconds into the helper's group without a move, the game's mark on the helper decides
-- (only while the group shows it in the own zone; in another zone it is marked the same way and moves nobody).
local function readMark(s)
    if swap ~= s or s.changed or s.stuck or s.transferAt then return end
    local mark, zoneHere = SW._hostMark(s.host)
    if not mark then return end
    local low = s.host:lower()
    if zoneHere == false then
        s.stuck, s.failed, s.elsewhere = true, true, true
        trace.stuck = trace.stuck + 1
        notMoved[low] = now()
        note("elsewhere", s.host)
        if SW.Leave(true) then ns.msg(L["%s war in einer anderen Zone und hat dich nicht bewegt: Amisia verlässt die Gruppe."]:format(s.host)) end
        return
    end
    if zoneHere ~= true then return end
    local private = LY.Private()
    -- outside private numbers: a helper that answered with another layer and is now shown with us was moved over
    local over = not private and mark == "here" and s.wanted and s.from and s.wanted ~= s.from
    if mark == "apart" or over then
        s.stuck, s.failed, s.refused = true, true, true
        trace.refused = (trace.refused or 0) + 1
        s.capBefore = SW._capSnapshot()
        SW._capRefused()
        note("refused", s.host)
        if SW.Leave(true) then ns.msg(L["Das Spiel hat dich nicht bewegt (zehn Wechsel je Stunde): Amisia verlässt die Gruppe."]) end
        return
    end
    if private and mark == "here" then
        -- the helper stands with us: its number is our layer's too, unless ours came from a helper already
        s.stuck, s.failed, s.sameMark = true, true, true
        trace.stuck = trace.stuck + 1
        local was = LY.Current()
        if s.wanted and s.wanted ~= was and not LY.Taken() then LY.Take(s.map, s.wanted, s.zuid or 0, "same") end
        notMoved[low] = now()
        avoid[low] = { at = now(), uid = LY.Current() or was, keep = SW.MOVER_FOR }
        note("same", s.host)
        if SW.Leave(true) then ns.msg(L["%s stand auf deinem Layer: Amisia verlässt die Gruppe, kein Wechsel verbraucht."]:format(s.host)) end
    end
end

-- F-221: every reading while the swap is judged: a creature of the old layer read after joining (each once).
LY.onRead = function(uid, map, guid)
    local s = swap
    if not s or s.changed or s.stuck or not s.from or uid ~= s.from or map ~= s.map or s.fresh[guid] then return end
    s.fresh[guid] = true
    s.freshN = s.freshN + 1
    checkStuck(s)
end

-- F-229: the group of a helper who answered the ask is left layer.leaveSeconds after the join once the game moved
-- us, or that long after a later move (always; no setting since F-229).
local function leaveLater(s)
    if s.leaveAt or not s.answered then return end
    local secs = tonumber(ns.Get("layer.leaveSeconds")) or 4
    local t = now()
    s.leaveAt = (t - s.at <= secs) and (s.at + secs) or (t + secs)
    C_Timer.After(math.max(0, s.leaveAt - t), function()
        if swap == s then SW.Leave(true) end
    end)
end

-- The change found: say it and (F-229) leave the group of a helper who answered. noLeave: the group is gone already.
local function changeDone(s, noLeave)
    s.changed, s.failed = now(), nil
    -- the search is over: "Weiter fragen" after the leave would say nobody answered
    auto = nil
    trace.changed = trace.changed + 1
    note("moved", s.host)
    if LY.Private() then
        ns.msg(L["Gewechselt auf einen anderen Layer."])
    elseif s.wanted and s.target ~= s.wanted then
        ns.msg(L["Gewechselt, aber nicht auf den gewünschten Layer: %s"]:format(LY.Name(s.map, s.target)))
    else
        ns.msg(L["Gewechselt: %s"]:format(LY.Name(s.map, s.target)))
    end
    changed()
    if noLeave then return end
    leaveLater(s)
end

-- Whether the layer read now is the change of s: another layer than before in the same zone (the one asked for,
-- or since F-221 any other one); without a layer from before only the host's.
local function moved(s)
    local uid, map = LY.Current()
    if not uid or map ~= s.map then return nil end
    if s.from then return uid ~= s.from and uid or nil end
    return s.wanted and uid == s.wanted and uid or nil
end

local function checkChange()
    local g = afterGroup
    if g and now() > g.untilAt then
        afterGroup = nil
        g = nil
    end
    if g and not g.s.changed then
        local uid = moved(g.s)
        if uid then
            afterGroup = nil
            g.s.target = uid
            changeDone(g.s, true)
        end
    end
    local s = swap
    if not s or s.changed or s.stuck then return end
    checkStuck(s)
    if s.stuck then return end
    local uid = moved(s)
    if not uid then return end
    s.target = uid
    changeDone(s)
end
-- The group's leader (F-221): the real host after LEADER_WAIT; nil when none can be read.
local function leaderName()
    for i = 1, 4 do
        local unit = "party" .. i
        if unitFlag("UnitIsGroupLeader", unit) then
            local ok, name = pcall(ns.UnitFullName, unit)
            name = ok and nameOf(name) or nil
            if name and not isMe(name) then return name end
        end
    end
    return nil
end

-- F-221: SHARD_TRANSFER in the swap's group marks the move. F-229: the first move as a guest counts for the game's
-- hour; the helper's answered number (from the own zone, not the layer left) is taken for the new layer at once
-- (LY.Take "host"), and the group is left layer.leaveSeconds after the join.
local function transferred()
    local s = swap
    -- a move that comes just after a verdict of refusal: the game did move us after all, the hold goes back
    if s and s.refused and s.capBefore ~= nil and not s.counted and now() - s.at <= SW.REFUSE_AFTER + SW.LATE_MOVE then
        SW._capRestore(s.capBefore)
        s.capBefore, s.refused, s.stuck, s.failed = nil, nil, nil, nil
    end
    if not s or s.changed or s.stuck or not inGroup() then return end
    s.transferAt, s.moved = now(), true
    if not s.counted then
        s.counted = true
        SW._capMoved()
    end
    -- the game moves us to the leader's layer: the answer counts only when the leader is the one who answered
    local lead = leaderName()
    if s.wanted and s.wanted ~= s.from and s.map == LY.Map() and (not lead or lead:lower() == s.answerer:lower()) then
        LY.Take(s.map, s.wanted, s.zuid or 0, "host")
    end
    leaveLater(s)
    changed()
end
-- F-229: for LY.SaveOwn: in a helper's group before the game's move (the move may come while the interface reloads)
LY.Between = function() return swap ~= nil and not swap.transferAt and not swap.stuck end
ns.Listen("LAYER", function(what)
    if what == "transfer" then transferred() end
    checkChange()
end)


-- The swap's judging: scans at JUDGE_STEPS, then every JUDGE_EVERY seconds until CHANGE_WAIT.
local function judge(s)
    local function look()
        if swap ~= s or s.changed or s.stuck then return end
        LY.Scan()
        checkChange()
    end
    for _, d in ipairs(SW.JUDGE_STEPS) do
        if d == 0 then look() else C_Timer.After(d, look) end
    end
    local last = SW.JUDGE_STEPS[#SW.JUDGE_STEPS]
    local function every()
        if swap ~= s or s.changed or s.stuck or now() - s.at > SW.CHANGE_WAIT then return end
        look()
        C_Timer.After(SW.JUDGE_EVERY, every)
    end
    C_Timer.After(last + SW.JUDGE_EVERY, every)
    C_Timer.After(SW.REFUSE_AFTER, function() readMark(s) end)
    C_Timer.After(SW.LEADER_WAIT, function()
        if swap ~= s then return end
        local lead = leaderName()
        if lead and lead:lower() ~= s.host:lower() then
            s.host, s.lead = lead, lead
            changed()
        end
    end)
    C_Timer.After(SW.CHANGE_WAIT, function()
        if swap == s and not s.changed and not s.stuck then
            -- without a layer before and without the host's layer nothing can be compared
            if s.wanted or s.from then s.failed = true else s.unknown = true end
            if s.failed then trace.failed = trace.failed + 1 else trace.unknown = trace.unknown + 1 end
            changed()
        end
    end)
end

-- The swap party (F-216): free for all, once, when the leader is the host of a party Amisia filled. F-221: the
-- method before is kept and set again once a player Amisia did not invite joins.
local function lootApi()
    local api = rawget(_G, "C_PartyInfo")
    local get = type(api) == "table" and api.GetLootMethod or rawget(_G, "GetLootMethod")
    local set = type(api) == "table" and api.SetLootMethod or rawget(_G, "SetLootMethod")
    return api, get, set
end

local function setLoot()
    if not inGroup() then return end
    local api, get, set = lootApi()
    if type(set) ~= "function" or lootBlocked then return end
    if lootDone then
        -- a player Amisia did not invite joined: the method before, once
        if not lootBack and lootWas ~= nil and unitFlag("UnitIsGroupLeader", "player") and members() - 1 > #guestsInGroup() then
            lootBack = true
            tried("loot")
            pcall(set, lootWas)
        end
        return
    end
    if not SW.CanInvite() or #guestsInGroup() == 0 then return end
    lootDone = true
    local ffa = Enum and Enum.LootMethod and Enum.LootMethod.Freeforall
    if type(get) == "function" then
        local ok, method = pcall(get)
        method = ok and ns.Plain(method)
        if method == "freeforall" or (ffa ~= nil and method == ffa) then return end
        lootWas = method
    end
    tried("loot")
    pcall(set, ffa ~= nil and api and set == api.SetLootMethod and ffa or "freeforall")
end

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local t = now()
    if not inGroup() then lootDone, lootWas, lootBack = nil, nil, nil end
    if swap and not inGroup() then
        local s = swap
        if lastCall and lastCall.kind == "leave" and t - lastCall.at <= SW.TRACE_WAIT + 3 then
            trace.leave.left = trace.leave.left + 1
            lastCall = nil
        end
        if s.changed then
            ns.msg(L["Gruppe verlassen: du bleibst auf deinem neuen Layer."])
        elseif not s.failed and not s.unknown then
            -- F-221: the group ended before the verdict: a new layer still counts for a while
            afterGroup = { s = s, untilAt = t + SW.AFTER_GROUP }
        end
        swap = nil
        changed()
        return
    end
    -- the trace: a player Amisia invited is in the group now; F-221: one who accepts after Helfen went off
    -- (within LATE_ACCEPT) is taken out again
    for _, x in ipairs(invited) do
        if not x.joined and x.name and t - x.at <= SW.LATE_ACCEPT and ns.InMyGroup(x.name) then
            x.joined = true
            if not hosting and offAt and offAt >= x.at and unitFlag("UnitIsGroupLeader", "player") then
                local api = rawget(_G, "C_PartyInfo")
                local fn = type(api) == "table" and api.UninviteUnit or rawget(_G, "UninviteUnit")
                if type(fn) == "function" then
                    tried("kick")
                    pcall(fn, x.name)
                    ns.msg(L["%s nahm eine Einladung von vor \"Helfen aus\" an und ist wieder aus der Gruppe."]:format(x.name))
                end
            elseif t - x.at <= SW.JOIN_WAIT then
                trace.invite.joined = trace.invite.joined + 1
                helped.joined = helped.joined + 1
                changed()
            end
        end
    end
    setLoot()
    local p = pending
    if not swap and p and inGroup() and t - p.at <= SW.ACCEPT_WAIT + 30 and ns.InMyGroup(p.name) then
        local s = { host = p.name, answerer = p.name, map = p.map, from = p.from, wanted = p.uid, zuid = p.zuid, at = t,
            answered = p.answered, fresh = {}, freshN = 0 }
        if p.accepted then trace.accept.joined = trace.accept.joined + 1 end
        swap, pending, chatAt, chatAll, zone, afterGroup = s, nil, nil, nil, nil, nil
        if ns.LayerForeign and ns.LayerForeign.StopAsks then ns.LayerForeign.StopAsks() end
        changed()
        judge(s)
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

-- The book's entry of low (F-221: { t = epoch, negative for the other layer addon's way; h = 1 it was helping }),
-- an old plain number turned into one; nil when none.
local function bookEntry(db, low)
    local e = db and db[low]
    if type(e) == "number" then
        e = { t = e }
        db[low] = e
    end
    return type(e) == "table" and e or nil
end

-- A player who answered a quiet question: first in line for a week (HOST_MAX names, the oldest go). foreign
-- (F-220): the answer came on the other layer addon's prefix: kept with a negative time (asked that way next
-- time, not with ZQ), unless the name answered ZA within the week. helps (F-221): it answered as a helper; only
-- helpers go first.
local function rememberHost(name, foreign, helps)
    local db = hostsDB()
    if not db then return end
    local low = name:lower()
    local t = time()
    local e = bookEntry(db, low)
    if not e then
        local n, oldest, oldKey = 0, nil, nil
        for k, v in pairs(db) do
            n = n + 1
            local at = math.abs(tonumber(type(v) == "table" and v.t or v) or 0)
            if not oldest or at < oldest then oldest, oldKey = at, k end
        end
        if n >= SW.HOST_MAX and oldKey then db[oldKey] = nil end
        e = {}
        db[low] = e
    end
    if not (foreign and (tonumber(e.t) or 0) >= t - SW.HOST_KEEP) then e.t = foreign and -t or t end
    e.h = helps and 1 or nil
end

-- The saved list kept clean (on load): names, recent times and the helper mark only, HOST_MAX at most.
function SW.LoadedHosts(DB)
    local db = DB and DB.layerHosts
    if db == nil then return end
    if type(db) ~= "table" then DB.layerHosts = nil return end
    local cut, n = time() - SW.HOST_KEEP, 0
    for k, v in pairs(db) do
        local at = type(v) == "table" and v.t or v
        if type(k) ~= "string" or k == "" or #k > 48 or k:find("[%c|]") or type(at) ~= "number" or math.abs(at) < cut or n >= SW.HOST_MAX then
            db[k] = nil
        else
            n = n + 1
            db[k] = { t = at, h = type(v) == "table" and v.h == 1 and 1 or nil }
        end
    end
end

-- Asked without an answer (F-221, AmisiaDB.layerAsked = { [lower name] = epoch }, SILENT_KEEP, ASKED_MAX).
local askedN
local function askedDB()
    if type(AmisiaDB) ~= "table" then return silentMem end
    if type(AmisiaDB.layerAsked) ~= "table" then AmisiaDB.layerAsked, askedN = {}, 0 end
    return AmisiaDB.layerAsked
end

local function askedAt(low)
    local at = tonumber(askedDB()[low])
    if at and time() - at < SW.SILENT_KEEP then return at end
    return nil
end

local function markAsked(low)
    local db = askedDB()
    if db[low] then return end
    if not askedN then
        askedN = 0
        for _ in pairs(db) do askedN = askedN + 1 end
    end
    if askedN >= SW.ASKED_MAX then
        -- the old ones go first; the oldest when none is old
        local cut, oldest, oldKey = time() - SW.SILENT_KEEP, nil, nil
        for k, at in pairs(db) do
            at = tonumber(at) or 0
            if at < cut then
                db[k] = nil
                askedN = askedN - 1
            elseif not oldest or at < oldest then
                oldest, oldKey = at, k
            end
        end
        if askedN >= SW.ASKED_MAX and oldKey then
            db[oldKey] = nil
            askedN = askedN - 1
        end
    end
    db[low] = time()
    askedN = askedN + 1
end

local function clearAsked(low)
    local db = askedDB()
    if db[low] then
        db[low] = nil
        askedN = askedN and askedN - 1 or nil
    end
end

function SW.LoadedAsked(DB)
    local db = DB and DB.layerAsked
    askedN = nil
    if db == nil then return end
    if type(db) ~= "table" then DB.layerAsked = nil return end
    local cut, n = time() - SW.SILENT_KEEP, 0
    for k, at in pairs(db) do
        if type(k) ~= "string" or k == "" or #k > 48 or k:find("[%c|]") or type(at) ~= "number" or at < cut or at > time() + 60
            or n >= SW.ASKED_MAX then
            db[k] = nil
        else
            n = n + 1
        end
    end
end

-- The classes of Forever (WHO_CLASSES) in /who order with the client's names, one per search.
local function whoClasses()
    local out = {}
    local api = rawget(_G, "C_CreatureInfo")
    for _, id in ipairs(SW.WHO_CLASSES) do
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

-- The zone's word of a /who in the client's own language (WHO_TAG_ZONE, not "z-" on every client).
local function zoneTerm(where)
    local tag = ns.Plain(rawget(_G, "WHO_TAG_ZONE"))
    if type(tag) ~= "string" or tag == "" then tag = "z-" end
    return tag .. '"' .. where .. '"'
end

-- A level band of the /who by text (1 to WHO_BANDS): its lowest and highest level.
local function levelBand(i)
    local f = rawget(_G, "GetMaxPlayerLevel")
    local ok, m = false, nil
    if type(f) == "function" then ok, m = pcall(f) end
    local max = ok and tonumber(ns.Plain(m)) or nil
    if not max or max < 10 then max = 60 end
    local size = math.ceil(max / SW.WHO_BANDS)
    local lo = (i - 1) * size + 1
    return lo, math.min(max, lo + size - 1)
end

-- How many /who a round has after the zone's own: the classes with the map filter, else the level bands.
local function rounds(map)
    if map and not noMap then return #whoClasses() end
    return SW.WHO_BANDS
end

-- The /who of round (0 the zone): its text, the filter (SendWho's third argument; nil: the text alone) and the
-- button's word for it.
function SW._whoQuery(round, where, map)
    local term = zoneTerm(where)
    if map and not noMap then
        local c = round > 0 and whoClasses()[round] or nil
        return term, { classIDs = c and { c.id } or {}, raceIDs = {}, uiMapIDs = { map } }, c and c.name or where
    end
    if round > 0 and round <= SW.WHO_BANDS then
        local lo, hi = levelBand(round)
        return ("%s %d-%d"):format(term, lo, hi), nil, L["Stufe %d-%d"]:format(lo, hi)
    end
    return term, nil, where
end

-- Whether the zone can be asked at all: the client has /who and did not block it.
function SW.ZonePossible()
    local fl = rawget(_G, "C_FriendList")
    return not whoBlocked and type(fl) == "table" and type(fl.SendWho) == "function" and ns.CommReady ~= nil and ns.CommReady() == true
end

-- What the next search's /who asks (the zone's name, a class, a level band), nil when the zone cannot be asked.
function SW.ZoneNext()
    if not SW.ZonePossible() then return nil end
    local where = SW._zoneText()
    if not where then return nil end
    local map = LY.Map()
    local _, _, label = SW._whoQuery(whoRound % (rounds(map) + 1), where, map)
    return label
end

-- The game's who lists (Forever's group finder list, the old Friends window): shut out of the next answer
-- (their event) unless open, and back. One state for every search and the probe; whatever happens to them,
-- the next WHO_LIST_UPDATE or WHO_WAIT brings the lists' event back.
local WHO_LISTS = { "LFGWhoListFrame", "FriendsFrame" }
local function unmute()
    local list = muted
    muted, mutedAt = {}, nil
    local fl = rawget(_G, "C_FriendList")
    if type(fl) == "table" and type(fl.SetWhoToUi) == "function" then pcall(fl.SetWhoToUi, false) end
    for _, f in pairs(list) do pcall(f.RegisterEvent, f, "WHO_LIST_UPDATE") end
end
SW._unmute = unmute
local function visible(f)
    local fn = f.IsVisible or f.IsShown
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, f)
    return ok and v == true
end
local function mute()
    mutedAt = now()
    local at = mutedAt
    C_Timer.After(SW.WHO_WAIT + 0.5, function() if mutedAt == at then unmute() end end)
    for _, name in ipairs(WHO_LISTS) do
        local f = rawget(_G, name)
        if type(f) == "table" and not muted[name] and type(f.UnregisterEvent) == "function" and type(f.IsEventRegistered) == "function" then
            local ok, reg = pcall(f.IsEventRegistered, f, "WHO_LIST_UPDATE")
            if ok and reg == true and not visible(f) and pcall(f.UnregisterEvent, f, "WHO_LIST_UPDATE") then muted[name] = f end
        end
    end
end

-- The /who of the search (inside a click): the zone's map with the next round's class (F-221); the client refused
-- the map filter: the zone by name and a level band. true, or nil and the reason.
function SW.AskZone()
    local z = zone
    if not z or z.req ~= req then return nil end
    if not SW.ZonePossible() then return nil, L["Das Spiel erlaubt Amisia gerade keine Wer-Abfrage."] end
    if z.waiting or z.round then return nil, L["Gefragt, warte auf Antworten ..."] end
    local where = SW._zoneText()
    if not where then return nil, L["Das Spiel nennt deine Zone nicht."] end
    local fl = rawget(_G, "C_FriendList")
    local map = LY.Map()
    local round = whoRound % (rounds(map) + 1)
    local text, filter, label = SW._whoQuery(round, where, map)
    mute()
    if type(fl.SetWhoToUi) == "function" then pcall(fl.SetWhoToUi, true) end
    tried("who")
    local ok = false
    if filter then
        local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social or 1
        ok = pcall(fl.SendWho, text, origin, filter)
        if not ok then
            -- the client does not take the map filter: by name from now on
            noMap = true
            round = whoRound % (rounds(map) + 1)
            local byName, _, word = SW._whoQuery(round, where, map)
            text, label = byName, word
        end
    end
    if not ok then ok = pcall(fl.SendWho, text) end
    if not ok then
        unmute()
        return nil, L["Das Spiel hat die Wer-Abfrage abgelehnt."]
    end
    whoRound = round + 1
    z.round, z.waiting, z.whoAt, z.asked, z.err = round, true, now(), label, nil
    C_Timer.After(SW.WHO_WAIT, function()
        if zone == z and z.waiting then
            -- the same query again with the next search
            z.waiting = nil
            whoRound = z.round
            z.err = L["Das Spiel hat die Wer-Liste nicht geschickt; der nächste Klick versucht es wieder."]
            changed()
        end
    end)
    changed()
    return true
end

-- The zone's name as /who takes it.
function SW._zoneText() return ownZone() end

-- The /who answer: up to ZONE_MAX names, the own name never, the own zone's first (own realm dropped); and whether
-- the game's list was full (another search reaches other players).
local function whoNames(where)
    local fl = rawget(_G, "C_FriendList")
    if type(fl) ~= "table" or type(fl.GetNumWhoResults) ~= "function" or type(fl.GetWhoInfo) ~= "function" then return {}, false end
    local ok, n, total = pcall(fl.GetNumWhoResults)
    n = ok and tonumber(ns.Plain(n)) or 0
    total = ok and tonumber(ns.Plain(total)) or n
    local here, there = {}, {}
    for i = 1, math.min(n, SW.ZONE_MAX + 1) do
        local okI, info = pcall(fl.GetWhoInfo, i)
        info = okI and ns.Plain(info) or nil
        local full = type(info) == "table" and ns.Plain(info.fullName) or nil
        local area = type(info) == "table" and ns.Plain(info.area) or nil
        local name = nameOf(full)
        if name and not isMe(name) then
            if not where or area == nil or area == where then here[#here + 1] = name else there[#there + 1] = name end
        end
    end
    local out = {}
    for _, list in ipairs({ here, there }) do
        for _, name in ipairs(list) do
            if #out < SW.ZONE_MAX then out[#out + 1] = name end
        end
    end
    return out, n >= SW.ZONE_MAX + 1 or (total or 0) >= SW.ZONE_MAX + 1
end

-- One quiet question to x ({ name, low, amisia }): ZQ to a known Amisia user or without the other layer
-- addon's way (F-220), else that addon's ask alone.
local function askOne(z, x, foreign)
    z.sent[x.low] = true
    local function sent()
        markAsked(x.low)
        z.reached = z.reached + 1
        changed()
    end
    if foreign and not x.amisia then return foreign.Ask(z, x.name, sent) end
    ns.CommSend("ZQ", { z.req.id, z.req.map, z.req.uid or 0 }, "WHISPER", x.name, { anyone = true, low = true,
        ttl = SW.ZQ_TTL, key = "ZQ:" .. x.low, sent = sent })
end

-- The quiet questions to the names of one /who: not the own, not asked in this search, not asked without an
-- answer within SILENT_KEEP unless they answered within a week, not a name gone offline (GONE_FOR) or a host
-- that invited from the own layer (AVOID_FOR); who answered as a helper goes first. The guild's (they had YQ):
-- none, or (F-220, the other layer addon's way) with layer.guildLast its ask after the others, GUILD_WAITS
-- seconds after they went when nobody invited and no helper of another layer answered; at once when nobody
-- else is in the list; layer.guildLast off: not that way at all (F-221).
function SW._sendZone(z, names, full)
    local db = hostsDB() or {}
    local t, cut = now(), time() - SW.HOST_KEEP
    local LF = ns.LayerForeign
    local foreign = LF and LF.Active() and LF or nil
    local mine = LY.Current()
    local list, guild = {}, {}
    for _, name in ipairs(names) do
        local low = name:lower()
        local e = bookEntry(db, low)
        local at = e and tonumber(e.t) or 0
        local known = math.abs(at) >= cut
        local quiet = askedAt(low) ~= nil
        local resting = gone[low] and t - gone[low] < SW.GONE_FOR
        local av = avoid[low]
        local avoided = av and t - av.at < (av.keep or SW.AVOID_FOR) and av.uid == mine
        if not z.sent[low] and not isMe(name) and not resting and not avoided and (known or not quiet) then
            local x = { name = name, low = low, helper = known and e and e.h == 1 or false, amisia = at >= cut }
            if not (ns.InGuild() and ns.GuildMember(name)) then
                list[#list + 1] = x
            elseif foreign then
                guild[#guild + 1] = x
            end
        end
    end
    local function order(a, b)
        if a.helper ~= b.helper then return a.helper end
        return a.low < b.low
    end
    table.sort(list, order)
    table.sort(guild, order)
    z.found = (z.found or 0) + #names
    z.full = full or nil
    local n = math.min(#list, SW.ZONE_MAX)
    for i = 1, n do askOne(z, list[i], foreign) end
    if #guild > 0 and ns.Get("layer.guildLast") then
        local function askGuild(last)
            if last then z.guildDue = nil end
            if zone ~= z or z.req ~= req or pending or swap or z.guildAsked then return end
            if n > 0 and (z.other or 0) > 0 then return end
            z.guildAsked = true
            local left = SW.ZONE_MAX - n
            for i = 1, math.min(#guild, left) do
                if not z.sent[guild[i].low] then askOne(z, guild[i], foreign) end
            end
        end
        if n == 0 then
            askGuild()
        else
            z.guildDue = true
            local burst = math.ceil(n / ((LF and LF.BURST) or 8))
            for i, w in ipairs(SW.GUILD_WAITS) do
                C_Timer.After(burst + w, function() askGuild(i == #SW.GUILD_WAITS) end)
            end
        end
    end
    changed()
end

-- F-220: an answer on the other layer addon's prefix (Gear/LayerForeign.lua) to the open search: name (the
-- sender), the layer it named (uid: server part, zuid; nil for "-"), helps ("h"), same (it stands on the own
-- layer). Counted like ZA; the name is kept in layerHosts. Returns whether it belonged to the search.
function SW._foreignAnswer(name, uid, zuid, helps, same)
    local z = zone
    if not z or not req or z.req ~= req or now() - req.at > SW.REQ_LIFE or type(name) ~= "string" then return false end
    local low = name:lower()
    if not z.sent[low] then return false end
    if same then uid = req.uid end
    clearAsked(low)
    rememberHost(name, true, helps or same)
    z.answered = z.answered or {}
    local other = uid ~= nil and uid ~= req.uid
    z.answered[low] = { name = name, uid = uid, zuid = (not same) and zuid or nil, helps = helps or same, at = now() }
    if not z.heard[low] then
        z.heard[low] = true
        z.heardN = z.heardN + 1
        if helps or same then z.hosts = z.hosts + 1 end
        if helps and other then z.other = z.other + 1 end
        if uid ~= nil and uid == req.uid then z.same = (z.same or 0) + 1 end
    end
    if other then LY.Heard(req.map, uid, zuid) end
    changed()
    return true
end

-- F-220: the answer of name to the open search on the other layer addon's prefix whose invite counts (not one
-- that named the own layer), nil when none. F-221: the search's whole life (REQ_LIFE).
function SW._foreignInviter(name)
    local z = zone
    local a = z and z.answered and z.answered[tostring(name):lower()]
    if not a or z.req ~= req or not req or now() - a.at > SW.REQ_LIFE then return nil end
    if a.uid ~= nil and a.uid == req.uid then return nil end
    return a
end

-- F-220: the open search for the other layer addon's ask (Gear/LayerForeign.lua): zone search, question, the
-- layer target of a row's click.
function SW._search()
    local z, a = zone, auto
    if not z or not req or z.req ~= req then return nil end
    return z, req, a and a.req == req and a.target or nil
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
    if not pcall(fl.SendWho, zoneTerm(where)) then
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
    for _, name in ipairs(names) do
        if not isMe(name) and not (ns.InGuild() and ns.GuildMember(name)) then
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
    if next(muted) ~= nil then
        -- the lists' event comes back on the next frame, after this answer went past them; the probe looks then
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
    local names, full = whoNames(SW._zoneText())
    if forProbe then probeAnswer(p, names) end
    if forZone then
        z.waiting = nil
        SW._sendZone(z, names, full)
    end
end)

-- F-221: the server's "no player named ..." for a name Amisia whispered (Core/Comm.lua keeps the line out of the
-- chat): the name rests GONE_FOR seconds and counts as asked; the game's "already in a group" (or "already been
-- invited") for a name Amisia invited frees its place and its minute.
ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local ours, k = ns.CommOfflineLine(text)
    if ours and k then
        gone[k] = now()
        markAsked(k)
        return
    end
    local pat = ns.TemplatePattern(rawget(_G, "ERR_ALREADY_IN_GROUP_S"))
    local who = pat and text:match(pat)
    who = who and (ns.TemplateName(who) or who)
    if not who and not text:lower():find("already been invited", 1, true) then return end
    local short = who and (who:match("^([^%-]+)") or who):lower()
    for _, x in ipairs(invited) do
        local xs = x.name and (x.name:match("^([^%-]+)") or x.name)
        if xs and not x.joined and not x.freed and ((short and xs:lower() == short) or (not short and text:find(xs, 1, true))) then
            x.freed = true
            changed()
        end
    end
end)

-- Host: a quiet question of a player in the zone. Every Amisia user in the same zone answers (ZA), with "helps"
-- when it would invite; a helping answer is remembered for the YI that follows. F-221: an unknown own layer is
-- read from the units in view first.
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
    if not mine then
        LY.Rescan()
        mine, myMap = LY.Current()
    end
    local known = mine ~= nil and myMap == map
    -- a player outside the guild only with "Auch Spielern außerhalb der Gilde helfen" (layer.others)
    local member = ns.GuildMember(name) ~= nil
    local helps = known and not LY.Ours(uid) and SW.CanHelp() and ns.Get("layer.answer") and not asking() and SW.CanInvite()
        and (member or ns.Get("layer.others") == true)
    local low = name:lower()
    if helps then SW._answered(low, { id = id, map = map, uid = mine, at = t, stranger = true, name = name }) end
    ns.CommSend("ZA", { id, map, known and mine or 0, helps and 1 or 0 }, "WHISPER", name,
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
    clearAsked(low)
    rememberHost(name, false, helps)
    if not z.heard[low] then
        z.heard[low] = true
        z.heardN = z.heardN + 1
        if helps then z.hosts = z.hosts + 1 end
        if helps and uid > 0 and uid ~= req.uid then z.other = z.other + 1 end
        if uid > 0 and uid == req.uid then z.same = (z.same or 0) + 1 end
    end
    if helps and uid > 0 and uid ~= req.uid then return SW._addAnswer(req, name, uid, true) end
    changed()
end)

-- for the tests: name counts as asked by the open search
function SW._zoneSent(name) if zone then zone.sent[name:lower()] = true end end

---------------------------------------------------------------------------
-- "Layer wechseln" (part 8, F-214; the zone F-216; the button's states F-221)
---------------------------------------------------------------------------
-- What the button does now: "ask" (a new search), "stop" (a search, a request for an invite or a chat request
-- runs: the click stops it), "more" (the search ended without a helper: the next click starts a new one, its
-- /who the next class or band), "channel" (no answer and the zone cannot be asked, or neither guild nor zone:
-- the channel line), "leave" (in the swap's group), "leaveAsk" (in the group of a host that did not move us).
function SW.SwapStep()
    if swap then return (swap.failed or swap.stuck) and "leaveAsk" or "leave" end
    if ownAsk() then return "stop" end
    local a = auto
    if a and req and a.req == req and now() - req.at <= SW.REQ_LIFE then
        return SW.ZoneNext() and "more" or "channel"
    end
    if not ns.InGuild() and not SW.ZonePossible() then return "channel" end
    return "ask"
end

-- Seconds the running search has run (the button stops it only after STOP_GUARD), nil without one.
function SW.AskAge()
    if pending then return now() - pending.at end
    if chatAt then return now() - chatAt end
    if req then return now() - req.at end
    return nil
end

-- Stops the own search: no pick, no more questions, no invite taken by itself. The search's time still counts
-- for the next one (once in ASK_GAP).
function SW.Stop()
    if not auto and not zone and not pending and not chatAt then return nil, L["Amisia fragt gerade nicht."] end
    auto, zone, pending, chatAt, chatAll = nil, nil, nil, nil, nil
    if ns.LayerForeign and ns.LayerForeign.StopAsks then ns.LayerForeign.StopAsks() end
    changed()
    return true
end

-- The search's clock (F-229): no invite within INVITE_WAIT seconds ends it ("none"; the asks still waiting are
-- dropped), unless a pick is running or the /who answer is still awaited. An invite that comes later still counts.
local function armNone(a)
    local function check()
        if auto ~= a or a.picked or a.none or pending or swap then return end
        local z = zone
        if (a.picking or (z and z.req == a.req and z.waiting)) and now() - a.req.at < SW.REQ_LIFE then return C_Timer.After(1, check) end
        a.none = true
        local LF = ns.LayerForeign
        if LF and LF.StopAsks then LF.StopAsks() end
        note("none")
    end
    C_Timer.After(SW.INVITE_WAIT, check)
end

-- The pick PICK_WAIT after the first fitting answer: the invite of the first answer in SW.Answers' order
-- (layers the own client has not seen first) of the layer a.target, else of any.
function SW._pick(a)
    if auto ~= a or req ~= a.req then return end
    a.picking = nil
    if pending or swap or inGroup() then a.picked = true return changed() end
    local t, mine = now(), LY.Current()
    for _, x in ipairs(SW.Answers()) do
        local av = avoid[x.name:lower()]
        if (not a.target or x.uid == a.target) and not (av and t - av.at < (av.keep or SW.AVOID_FOR) and av.uid == mine) then
            a.picked = true
            local ok, why = SW.RequestInvite(x.name)
            if not ok and why then ns.msg(why) end
            return changed()
        end
    end
    a.none = true
    changed()
end

-- "Layer wechseln" (target nil) or a click on a layer's row (target its server part). Returns true, or nil
-- and the reason. Inside a click (the zone's /who needs one); every search asks one /who, the next search the next
-- class. F-229: never in a fight and COMBAT_REST seconds after it, dead, on a flight path, or with the hour's moves
-- used up (SW.Blocked); no row where the numbers are private.
function SW.Swap(target)
    target = tonumber(target)
    local step = SW.SwapStep()
    if step == "leave" or step == "leaveAsk" or step == "stop" then return nil, L["Ein Layer-Wechsel läuft schon."] end
    local blockedWhy = SW.Blocked()
    if blockedWhy then return nil, blockedWhy end
    if target and LY.Private() then target = nil end
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
    local a = { req = req, target = target }
    auto = a
    zone = nil
    warning, event = nil, nil
    if zoneOk then
        zone = { req = req, sent = {}, heard = {}, heardN = 0, reached = 0, hosts = 0, other = 0, same = 0 }
        local okZ, whyZ = SW.AskZone()
        if not okZ and whyZ then ns.msg(whyZ) end
    end
    armNone(a)
    changed()
    return true
end

-- Whether an invite came for the own ask (the swap's group or an invite noted).
function SW.Invited() return swap ~= nil or (pending ~= nil and pending.invited ~= nil) end

-- The window's red button: what SW.SwapStep says (a search's stop only after STOP_GUARD seconds).
function SW.Press()
    local step = SW.SwapStep()
    if step == "stop" then
        if (SW.AskAge() or SW.STOP_GUARD) < SW.STOP_GUARD then return nil end
        return SW.Stop()
    end
    if step == "leave" or step == "leaveAsk" then return SW.Leave() end
    return SW.Swap()
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
        pause = SW.InviteBreak(), refresh = LY.RefreshText and LY.RefreshText() or nil,
        why = SW.PauseReason(), warning = SW.Warning(), age = SW.AskAge(), event = SW.Event(), cap = SW.CapLeft(),
        capUsed = SW.CapUsed(), blocked = SW.Blocked() }
end

-- for the tests and the UI scene: st = { req, pending, swap } to start from (nil: nothing open); a login: Helfen on
function SW._reset(st)
    st = st or {}
    req, pending, swap, answered, invited, offered, chatAt = st.req, st.pending, st.swap, {}, {}, {}, st.chatAt
    chatAll, othersAt, lastCall, trace = st.chatAll, nil, nil, newTrace()
    hosting, helped, auto, question = true, { asked = 0, invited = 0, joined = 0 }, nil, nil
    zone, whoBlocked, lootBlocked, lootDone, silentMem, zqAt, probe = nil, nil, nil, nil, {}, {}, nil
    warning, offAt, lastInviteAt, lootWas, lootBack, afterGroup = nil, nil, nil, nil, nil, nil
    gone, avoid, notMoved, whoRound, noMap = {}, {}, {}, 0, nil
    fighting, foughtAt, event = nil, nil, nil
    -- the hour's count stays (a login keeps it, F-229)
    if type(AmisiaDB) == "table" then AmisiaDB.layerHelp, AmisiaDB.layerAsked, askedN = nil, nil, nil end
    if next(muted) ~= nil then unmute() end
end

-- the saved lists cleaned once the file is read (the body may run after that moment, D-128)
local function loaded()
    if type(AmisiaDB) ~= "table" then return end
    SW.LoadedHosts(AmisiaDB)
    SW.LoadedAsked(AmisiaDB)
    SW.LoadedCap(AmisiaDB)
    loadHelp()
end
loaded()
SW._loaded = loaded   -- for the tests: a /reload
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON then loaded() end
end)
end)
