-- The group's quest state of a dungeon (F-178, D-110, ns.GroupQuests, spec
-- docs/specs/2026-11-11-gruppen-queststatus.md): which member of the own party has which quest of a
-- dungeon in the log, ready to turn in, done, or still lacks it, so the group sees before the first pull
-- whom a quest still has to be shared with and who can turn in.
--
-- Only in an own party of up to five (PARTY, ns.HomeGroup; never in a raid, never GUILD or WHISPER),
-- only between Amisia clients. Two message kinds:
--   QS <dungeon key> <version 1> <flags: "T" cut short, "-"> <list>   the sender's state of every quest
--        of that dungeon's list in its quest data: the quest ids ascending, each as the base-36
--        difference to the one before, followed by its state character: "." can take it, "<" not yet
--        (level, pre-quest), "+" in the log, "!" in the log and ready to turn in, "*" done, "/" can never
--        take it (faction, class, race, or a quest that excludes it is done); "-" for an empty list.
--        A quest the list does not name is unknown to that sender (another data version, cut short).
--   QR <dungeon keys, comma, at most 4> <version 1>   asks the party for its QS of those dungeons.
-- Sent: on entering a dungeon in a party and on joining a party inside one (QS, and QR while a member's
-- state is missing), when the own state of a watched dungeon changes (quest accepted, completed, turned
-- in, abandoned, a level; coalesced over 2 s, a dungeon at most every 6 s, 12 QS a minute), as the
-- answer to a QR (after 0.5-3.5 s by the name, none when the own QS went out after the last roster
-- change and within 10 s), and when the roster gains a member or the page Dungeons shows a dungeon's
-- quests while a member's state of it is missing (QR, one per 15 s; none while a QR of that dungeon
-- went within 30 s). Never in combat, in the lockdown, a battleground or before the quest log answered.
-- With "Meinen Dungeon-Queststand mit der Gruppe teilen" (quests.groupShare) off no QS goes out; what
-- the others send still shows. The state lives in memory only: dropped when a member leaves, when the
-- party ends or becomes a raid, and after 30 minutes.
--
-- What it shows: a mark per member on the Quests rows of the page Dungeons (ns.GroupQuests.Marks), the
-- tooltip's lines (GQ.TipLines), "N teilen" in the dungeon bar (GQ.ShareCount), and GQ.Share: the
-- client's quest share of a quest in the own log, only on a click and never in combat.
local ADDON, ns = ...
local L = ns.L

local GQ = {}
ns.GroupQuests = GQ

GQ.VERSION = 1
GQ.SEND_GAP = 6        -- seconds between two QS of one dungeon
GQ.PER_MINUTE = 12     -- QS in any 60 s
GQ.ASK_GAP = 15        -- seconds between two own QR
GQ.ASKED_KEEP = 30     -- a QR of a dungeon (anyone's) holds an own QR of it back this long
GQ.LOOK_GAP = 60       -- the page asks for one dungeon at most this often
GQ.ANSWER_SKIP = 10    -- an own QS this recent (and after the last roster change) answers a QR already
GQ.SETTLE = 2          -- a change waits this long for more (coalescing), at most SETTLE_MAX after the first
GQ.SETTLE_MAX = 5
GQ.ENTER_WAIT = 3      -- seconds after entering a world or joining a party before anything goes
GQ.STALE = 1800        -- a member's state older than this is dropped
GQ.WATCH = 1800        -- a dungeon asked for (by anyone) stays watched this long
GQ.MAX_KEYS = 4        -- keys per QR, watched keys, keys kept per member
GQ.MAX_ENTRIES = 100   -- quests per QS
local MAX_TEXT = 250   -- bytes of one message (Comm.lua)

local STATE_CHAR = { open = ".", locked = "<", active = "+", ready = "!", done = "*", na = "/" }
local CHAR_STATE = {}
for k, v in pairs(STATE_CHAR) do CHAR_STATE[v] = k end
GQ.STATE_CHAR, GQ.CHAR_STATE = STATE_CHAR, CHAR_STATE

local function now() return GetTime() end
local function plain(v) return ns.Plain(v) end

---------------------------------------------------------------------------
-- The wire form
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
    local s = ""
    repeat
        local d = n % 36
        s = DIGITS:sub(d + 1, d + 1) .. s
        n = math.floor(n / 36)
    until n == 0
    return s
end

-- The quest ids of a dungeon's list in the quest data, ascending, each once; {} without one.
local function listOf(dkey)
    local dq = ns.DUNGEON_QUESTS
    local l = type(dq) == "table" and type(dq.D) == "table" and dq.D[dkey]
    if type(l) ~= "table" then return {} end
    local out, seen = {}, {}
    for _, id in ipairs(l) do
        if type(id) == "number" and id >= 1 and id <= 999999 and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end
GQ.ListOf = listOf

-- A dungeon key this client may take a message of: in its quest data, not a raid (D-98: a raid's page
-- has no quests).
local function knownKey(dkey)
    if type(dkey) ~= "string" or #dkey > 24 or not dkey:match("^[%w_]+$") then return false end
    local dq = ns.DUNGEON_QUESTS
    if type(dq) ~= "table" or type(dq.D) ~= "table" or type(dq.D[dkey]) ~= "table" then return false end
    local D = ns.Dungeons
    return not (D and D.IsRaid and D.IsRaid(dkey))
end
GQ.KnownKey = knownKey

-- entries: { { qid, state }, ... } ascending -> the list text ("-" when empty) and whether it was cut
-- to fit room bytes.
function GQ.Encode(entries, room)
    room = room or (MAX_TEXT - 40)
    local parts, size, prev, cut = {}, 0, 0, false
    for i, e in ipairs(entries) do
        local piece = b36(e[1] - prev) .. (STATE_CHAR[e[2]] or ".")
        if i > GQ.MAX_ENTRIES or size + #piece > room then
            cut = true
            break
        end
        parts[#parts + 1] = piece
        size = size + #piece
        prev = e[1]
    end
    if #parts == 0 then return "-", cut end
    return table.concat(parts), cut
end

-- The list text of a QS -> { [qid] = state } and the number of quests; nil when it is not one.
function GQ.Decode(text)
    if text == "-" then return {}, 0 end
    if type(text) ~= "string" or text == "" or #text > MAX_TEXT then return nil end
    local out, n, at, id = {}, 0, 1, 0
    while at <= #text do
        local s, e, d, c = text:find("^([0-9a-z]+)([%.%+!%*/<])", at)
        if not s or #d > 4 then return nil end
        local step = tonumber(d, 36)
        if not step or step < 1 then return nil end
        id = id + step
        n = n + 1
        if n > GQ.MAX_ENTRIES or id > 999999 then return nil end
        out[id] = CHAR_STATE[c]
        at = e + 1
    end
    return out, n
end

---------------------------------------------------------------------------
-- The own state
---------------------------------------------------------------------------
-- { { qid, state }, ... } of every quest of dkey's list.
function GQ.OwnEntries(dkey)
    local D = ns.Dungeons
    local o = ns.QuestOpts and ns.QuestOpts() or nil
    local out = {}
    for _, qid in ipairs(listOf(dkey)) do
        out[#out + 1] = { qid, D and D.OwnQuestState and D.OwnQuestState(qid, o) or "open" }
    end
    return out
end

-- The fields of the own QS of dkey.
function GQ.OwnFields(dkey)
    -- the envelope: proto digit, kind, then tab-separated fields; the flag takes one character
    local head = #("1QS\t" .. dkey .. "\t" .. GQ.VERSION .. "\tT\t")
    local text, cut = GQ.Encode(GQ.OwnEntries(dkey), MAX_TEXT - head)
    return { dkey, tostring(GQ.VERSION), cut and "T" or "-", text }
end

---------------------------------------------------------------------------
-- The party
---------------------------------------------------------------------------
local function inParty() return ns.HomeGroup() and not ns.HomeRaid() end
GQ.InParty = inParty

local function selfName() return ns.UnitFullName("player") end

-- The other members of the own party in roster order: { { name, class, low } }; {} in a raid or alone.
function GQ.Members()
    local out = {}
    if not inParty() then return out end
    local idx = ns.GroupIndex()
    local me = selfName()
    for i, n in ipairs(idx.list) do
        if not (me and ns.SameName(n, me)) then
            out[#out + 1] = { name = n, class = idx.class[i], low = n:lower() }
        end
    end
    return out
end

local members = {}   -- [lower name] = { name, keys = { [dkey] = { at, q = { [qid] = state }, cut } } }
local roster = {}    -- [lower name] = true: the others at the last roster read
local rosterAt = 0   -- when the roster last changed
local watched = {}   -- [dkey] = time it was last of interest (here, asked by anyone, the page)
local lastSent = {}  -- [dkey] = { at, text }
local sentTimes = {} -- times of the own QS in the last minute
local pending = {}   -- [dkey] = { due, force, first }
local askWant = {}   -- [dkey] = due: own QR to send
local askedAt = {}   -- [dkey] = time of the last QR of it (anyone's)
local lookedAt = {}  -- [dkey] = time the page last asked for it
local lastAsk = -1000
local hereKeys = {}  -- the keys of the dungeon stood in (several before the first kill, D-106)
local logReady = false
local wakeAt

local function fire(dkey) ns.Fire("GROUP_QUESTS", dkey) end

local function dropAll()
    local had = next(members) ~= nil
    members, roster, watched, pending, askWant, askedAt, lookedAt = {}, {}, {}, {}, {}, {}, {}
    lastSent, sentTimes = {}, {}
    if had then fire(nil) end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function inCombat()
    if InCombatLockdown() then return true end
    local f = _G.UnitAffectingCombat
    if type(f) == "function" then
        local ok, c = pcall(f, "player")
        if ok and plain(c) then return true end
    end
    return false
end

-- Whether anything may be sent now.
local function mayTalk()
    if not ns.CommAvailable() or not inParty() then return false end
    if inCombat() or ns.CommHeld() or ns.ChatLocked() or ns.InPvPInstance() then return false end
    return logReady
end
GQ.MayTalk = mayTalk

local function sharing() return ns.Get("quests.groupShare") ~= false end
GQ.Sharing = sharing

local flush
local function wake(delay)
    local at = now() + math.max(0, delay)
    if wakeAt and wakeAt <= at + 0.01 then return end
    wakeAt = at
    C_Timer.After(math.max(0, delay), function()
        if wakeAt and now() + 0.01 >= wakeAt then
            wakeAt = nil
            flush()
        end
    end)
end

-- An own QS of dkey to send in delay seconds (force: also when nothing changed since the last).
local function schedule(dkey, delay, force)
    if not sharing() or not knownKey(dkey) then return end
    local t = now()
    local p = pending[dkey]
    if p then
        p.due = math.min(math.max(p.due, t + delay), p.first + GQ.SETTLE_MAX)
        p.force = p.force or force
    else
        pending[dkey] = { due = t + delay, force = force, first = t }
    end
    wake(pending[dkey].due - t)
end

-- An own QR of keys, in delay seconds.
local function ask(keys, delay)
    local t = now()
    for _, k in ipairs(keys) do
        if knownKey(k) and not (askedAt[k] and t - askedAt[k] < GQ.ASKED_KEEP) then
            askWant[k] = math.min(askWant[k] or math.huge, t + delay)
        end
    end
    local due
    for _, d in pairs(askWant) do due = math.min(due or d, d) end
    if due then wake(math.max(due, lastAsk + GQ.ASK_GAP) - t) end
end

local function budgetLeft()
    local t, keep = now(), {}
    for _, at in ipairs(sentTimes) do
        if t - at < 60 then keep[#keep + 1] = at end
    end
    sentTimes = keep
    return GQ.PER_MINUTE - #keep
end

local function notInCombat() return not inCombat() end

local function sendState(dkey, p)
    local t = now()
    local last = lastSent[dkey]
    local fields = GQ.OwnFields(dkey)
    local text = table.concat(fields, "\t")
    if not p.force and last and last.text == text and last.at >= rosterAt then return true end
    if p.force and last and last.text == text and last.at >= rosterAt and t - last.at < GQ.ANSWER_SKIP then return true end
    local ok = ns.CommSend("QS", fields, "PARTY", nil, { key = "QS:" .. dkey, ttl = 30, when = notInCombat })
    if ok then
        lastSent[dkey] = { at = t, text = text }
        sentTimes[#sentTimes + 1] = t
    end
    return true
end

flush = function()
    local t = now()
    if not inParty() then
        pending, askWant = {}, {}
        return
    end
    if not mayTalk() then
        -- combat, the lockdown, the quest log not there yet: again in a moment (and on the events)
        if next(pending) or next(askWant) then wake(2) end
        return
    end
    local nextDue
    local function soonest(at) nextDue = math.min(nextDue or at, at) end
    -- the own questions first: one QR with every key due
    local keys = {}
    for k, due in pairs(askWant) do
        if due <= t + 0.01 then keys[#keys + 1] = k else soonest(due) end
    end
    if #keys > 0 then
        if t - lastAsk < GQ.ASK_GAP then
            soonest(lastAsk + GQ.ASK_GAP)
        else
            table.sort(keys)
            while #keys > GQ.MAX_KEYS do
                soonest(t + GQ.ASK_GAP)
                table.remove(keys)
            end
            if ns.CommSend("QR", { table.concat(keys, ","), tostring(GQ.VERSION) }, "PARTY", nil, { ttl = 20, when = notInCombat }) then
                lastAsk = t
                for _, k in ipairs(keys) do
                    askWant[k] = nil
                    askedAt[k] = t
                end
            end
        end
    end
    if sharing() then
        for k, p in pairs(pending) do
            local last = lastSent[k]
            local gapAt = last and (last.at + GQ.SEND_GAP) or 0
            if p.due > t + 0.01 then
                soonest(p.due)
            elseif gapAt > t then
                soonest(gapAt)
            elseif budgetLeft() <= 0 then
                soonest(sentTimes[1] + 60)
            else
                pending[k] = nil
                sendState(k, p)
            end
        end
    else
        pending = {}
    end
    if nextDue then wake(nextDue - t) end
end

-- The keys whose own state others look at now: the dungeon stood in, those asked for in the last
-- 30 minutes.
local function interest()
    local t, out, seen = now(), {}, {}
    for _, k in ipairs(hereKeys) do
        if not seen[k] then seen[k] = true; out[#out + 1] = k end
    end
    for k, at in pairs(watched) do
        if t - at >= GQ.WATCH then watched[k] = nil
        elseif not seen[k] then seen[k] = true; out[#out + 1] = k end
    end
    return out
end
GQ.Interest = interest

local function watch(k)
    watched[k] = now()
    -- at most MAX_KEYS watched: the oldest goes
    local n, oldest = 0, nil
    for key, at in pairs(watched) do
        n = n + 1
        if not oldest or at < watched[oldest] then oldest = key end
    end
    if n > GQ.MAX_KEYS and oldest then watched[oldest] = nil end
end

-- Whether some member has no fresh state of dkey.
local function missing(dkey)
    local t = now()
    for _, m in ipairs(GQ.Members()) do
        local e = members[m.low] and members[m.low].keys[dkey]
        if not e or t - e.at >= GQ.STALE then return true end
    end
    return false
end

-- The own quest state changed: every key others look at, after a moment.
local function ownChanged()
    if not inParty() then return end
    for _, k in ipairs(interest()) do schedule(k, GQ.SETTLE, false) end
end

---------------------------------------------------------------------------
-- Where the character stands, the roster
---------------------------------------------------------------------------
local function readHere()
    local R = ns.Runs
    if not (R and R.Here) then return {} end
    local k, sure, keys = R.Here()
    if not k then return {} end
    local out = {}
    for _, key in ipairs((not sure and keys and #keys > 1) and keys or { k }) do
        if knownKey(key) and #out < GQ.MAX_KEYS then out[#out + 1] = key end
    end
    return out
end

local function sameKeys(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

-- Entering a world: a new dungeon in a party announces the own state and asks for the missing ones.
function GQ.UpdateHere()
    local keys = readHere()
    local changed = not sameKeys(keys, hereKeys)
    hereKeys = keys
    if changed and #keys > 0 and inParty() then
        for _, k in ipairs(keys) do schedule(k, GQ.ENTER_WAIT, true) end
        local want = {}
        for _, k in ipairs(keys) do if missing(k) then want[#want + 1] = k end end
        if #want > 0 then ask(want, GQ.ENTER_WAIT + ns.Spread(3, selfName() or "?")) end
    end
    return keys
end

function GQ.Here() return hereKeys end

-- The roster changed: who left is dropped; joining a party inside a dungeon announces and asks; a
-- newcomer is asked for the watched dungeons (after a jitter, held back by anyone's QR).
function GQ.UpdateRoster()
    if not inParty() then
        dropAll()
        return
    end
    local current = {}
    local wasAlone = next(roster) == nil
    local joined = false
    for _, m in ipairs(GQ.Members()) do
        current[m.low] = true
        if not roster[m.low] then joined = true end
    end
    local left = false
    for low in pairs(members) do
        if not current[low] then
            members[low] = nil
            left = true
        end
    end
    local changedRoster = joined
    for low in pairs(roster) do if not current[low] then changedRoster = true end end
    roster = current
    if changedRoster then rosterAt = now() end
    if left then fire(nil) end
    if not joined then return end
    local keys = interest()
    if #keys == 0 then return end
    for _, k in ipairs(keys) do schedule(k, GQ.ENTER_WAIT, wasAlone) end
    ask(keys, GQ.ENTER_WAIT + ns.Spread(3, selfName() or "?"))
end

-- The page Dungeons shows dkey's quests: watched, and asked for while a member's state is missing.
function GQ.Look(dkey)
    if not inParty() or not knownKey(dkey) then return end
    watch(dkey)
    local t = now()
    if lookedAt[dkey] and t - lookedAt[dkey] < GQ.LOOK_GAP then return end
    if not missing(dkey) then return end
    lookedAt[dkey] = t
    schedule(dkey, 0.5, false)
    ask({ dkey }, 0.5)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
-- The member a message is from, or nil: the server's sender in the own party, on PARTY only, not in
-- the own lockdown.
local function from(sender, chan)
    if chan ~= "PARTY" or not inParty() then return nil end
    if ns.CommHeld() or ns.ChatLocked() then return nil end
    local name = ns.TrustName(sender)
    if not name or not ns.InMyGroup(name) then return nil end
    local me = selfName()
    if me and ns.SameName(name, me) then return nil end
    return name
end

local function store(name, dkey, q, cut)
    local low = name:lower()
    local m = members[low]
    if not m then
        m = { name = name, keys = {} }
        members[low] = m
    end
    m.keys[dkey] = { at = now(), q = q, cut = cut }
    -- at most MAX_KEYS dungeons a member: the oldest goes
    local n, oldest = 0, nil
    for k, e in pairs(m.keys) do
        n = n + 1
        if not oldest or e.at < m.keys[oldest].at then oldest = k end
    end
    if n > GQ.MAX_KEYS and oldest then m.keys[oldest] = nil end
end

ns.CommOn("QS", function(sender, f, chan)
    local name = from(sender, chan)
    if not name then return end
    local dkey = f[1]
    local v = tonumber(f[2])
    if not knownKey(dkey) or not v or v < 1 then return end
    local q = GQ.Decode(f[4])
    if not q then return end
    store(name, dkey, q, f[3] == "T")
    fire(dkey)
end)

ns.CommOn("QR", function(sender, f, chan)
    local name = from(sender, chan)
    if not name then return end
    local v = tonumber(f[2])
    if not v or v < 1 then return end
    local t = now()
    local n = 0
    for k in (f[1] .. ","):gmatch("([^,]*),") do
        n = n + 1
        if n > GQ.MAX_KEYS then break end
        if knownKey(k) then
            askedAt[k] = t
            askWant[k] = nil
            watch(k)
            schedule(k, 0.5 + ns.Spread(3, selfName() or "?"), true)
        end
    end
end)

---------------------------------------------------------------------------
-- What the pages read
---------------------------------------------------------------------------
-- The state of quest qid of dungeon dkey for member m (GQ.Members): "done", "ready", "active",
-- "open" (lacks it, can take it), "locked" (lacks it, not yet), "na" (can never take it) or "unknown"
-- (no Amisia, sending off, another data version). Without a message the quest data's class and
-- faction still say "na" (the party shares the own faction).
function GQ.StateOf(m, dkey, qid)
    local e = members[m.low] and members[m.low].keys[dkey]
    if e and now() - e.at >= GQ.STALE then
        members[m.low].keys[dkey] = nil
        e = nil
    end
    local s = e and e.q[qid]
    if s then return s end
    local dq = ns.DUNGEON_QUESTS
    local r = type(dq) == "table" and type(dq.Q) == "table" and dq.Q[qid] or nil
    if type(r) == "table" then
        local fac = ns.OwnFaction()
        if (r[4] == "A" or r[4] == "H") and fac and r[4] ~= fac then return "na" end
        if type(r[5]) == "number" and r[5] > 0 and m.class and ns.Gear and ns.Gear.HasClassBit
            and not ns.Gear.HasClassBit(r[5], m.class) then return "na" end
    end
    return "unknown"
end

-- Whether member m sent a fresh state of dkey.
function GQ.HasState(m, dkey)
    local e = members[m.low] and members[m.low].keys[dkey]
    return e ~= nil and now() - e.at < GQ.STALE
end

-- The marks, one per member: its initial in its class colour, then the client's quest mark of its
-- state (as the own row's: "!" can take it, grey not yet; "?" in the log, yellow ready; the tick done),
-- "-" can never take it, a grey initial and "?" unknown.
local ICON = {
    open = "|TInterface\\GossipFrame\\AvailableQuestIcon:12:12|t",
    locked = "|TInterface\\GossipFrame\\AvailableQuestIcon:12:12:0:0:16:16:0:16:0:16:110:110:110|t",
    ready = "|TInterface\\GossipFrame\\ActiveQuestIcon:12:12|t",
    active = "|TInterface\\GossipFrame\\ActiveQuestIcon:12:12:0:0:16:16:0:16:0:16:110:110:110|t",
    done = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11:11|t",
}
local GREY = ns.Theme and ns.Theme.GREY or "|cff808080"
local function initial(name)
    return (name or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?"
end
GQ.Initial = initial

function GQ.Mark(m, state)
    local ini = initial(m.name)
    if state == "unknown" then return GREY .. ini .. "?|r" end
    if state == "na" then return GREY .. ini .. "-|r" end
    return ns.ClassColored(ini, m.class) .. (ICON[state] or "")
end

-- The marks of quest qid of dkey for the party, or "" alone.
function GQ.Marks(dkey, qid)
    if type(qid) ~= "number" then return "" end
    local parts = {}
    for _, m in ipairs(GQ.Members()) do parts[#parts + 1] = GQ.Mark(m, GQ.StateOf(m, dkey, qid)) end
    return table.concat(parts, " ")
end

-- The members of the party by their state of qid: { [state] = { name, ... } }.
function GQ.ByState(dkey, qid)
    local out = {}
    for _, m in ipairs(GQ.Members()) do
        local s = GQ.StateOf(m, dkey, qid)
        out[s] = out[s] or {}
        table.insert(out[s], ns.ClassColored(m.name, m.class))
    end
    return out
end

-- Whether the own quest qid is in the log (to share).
local function ownInLog(qid)
    local D = ns.Dungeons
    local s = D and D.OwnQuestState and D.OwnQuestState(qid) or nil
    return s == "active" or s == "ready"
end

-- The members who lack quest qid and can take it now (state "open").
function GQ.Lacking(dkey, qid)
    local out = {}
    for _, m in ipairs(GQ.Members()) do
        if GQ.StateOf(m, dkey, qid) == "open" then out[#out + 1] = m end
    end
    return out
end

-- Whether the own quest qid of dkey is in the log and some member lacks it (it can be shared).
function GQ.CanShare(dkey, qid)
    if type(qid) ~= "number" or not ownInLog(qid) then return false end
    return #GQ.Lacking(dkey, qid) > 0
end

local LINES = {
    { "ready", L["Fertig zum Abgeben: %s"] }, { "active", L["Im Log: %s"] }, { "done", L["Erledigt: %s"] },
    { "open", L["Fehlt: %s"] }, { "locked", L["Fehlt, noch nicht annehmbar: %s"] },
    { "na", L["Kann sie nicht annehmen: %s"] }, { "unknown", L["Unbekannt (kein Amisia oder Teilen aus): %s"] },
}
-- The tooltip lines of quest qid of dkey for the party: { text, ... }; {} alone.
function GQ.TipLines(dkey, qid)
    if type(qid) ~= "number" or #GQ.Members() == 0 then return {} end
    local by = GQ.ByState(dkey, qid)
    local out = { L["Gruppe:"] }
    for _, l in ipairs(LINES) do
        if by[l[1]] then out[#out + 1] = l[2]:format(table.concat(by[l[1]], ", ")) end
    end
    if GQ.CanShare(dkey, qid) then
        local names = {}
        for _, m in ipairs(GQ.Lacking(dkey, qid)) do names[#names + 1] = m.name end
        out[#out + 1] = L["Kannst du teilen: %s"]:format(table.concat(names, ", "))
    end
    return out
end

-- How many of the own quests in the log of keys (each once) some member lacks: the dungeon bar's
-- "N teilen".
function GQ.ShareCount(keys)
    local n, seen = 0, {}
    if #GQ.Members() == 0 then return 0 end
    for _, k in ipairs(keys or {}) do
        for _, qid in ipairs(listOf(k)) do
            if not seen[qid] then
                seen[qid] = true
                if GQ.CanShare(k, qid) then n = n + 1 end
            end
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Sharing a quest with the party (the client's quest share)
---------------------------------------------------------------------------
local function call(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, a = pcall(f, ...)
    if not ok then return nil end
    return plain(a)
end

-- Whether this client has a quest share call.
function GQ.ShareAvailable()
    local Q = _G.C_QuestLog
    local select_ = (type(Q) == "table" and type(Q.SetSelectedQuest) == "function") or type(_G.SelectQuestLogEntry) == "function"
    return type(_G.QuestLogPushQuest) == "function" and select_
end

-- Shares the own quest qid with the party: selects it in the quest log, asks whether it can be shared,
-- calls QuestLogPushQuest, puts the selection back. Only out of combat and inside a click. Returns true,
-- or nil and why.
function GQ.Share(qid)
    if type(qid) ~= "number" then return nil, L["Keine Quest."] end
    if inCombat() then return nil, L["Nicht im Kampf."] end
    if not inParty() then return nil, L["Du bist in keiner Gruppe."] end
    if not GQ.ShareAvailable() then return nil, L["Dieser Client kann keine Quest teilen; teile sie im Questlog."] end
    local Q = type(_G.C_QuestLog) == "table" and _G.C_QuestLog or {}
    local idx = tonumber(call(Q.GetLogIndexForQuestID, qid)) or tonumber(call(_G.GetQuestLogIndexByID, qid))
    if not idx or idx <= 0 then return nil, L["Die Quest steht nicht in deinem Questlog."] end
    local restore
    if type(Q.SetSelectedQuest) == "function" then
        local before = call(Q.GetSelectedQuest)
        pcall(Q.SetSelectedQuest, qid)
        restore = function() if type(before) == "number" and before > 0 then pcall(Q.SetSelectedQuest, before) end end
    else
        local before = call(_G.GetQuestLogSelection)
        pcall(_G.SelectQuestLogEntry, idx)
        restore = function() if type(before) == "number" and before > 0 then pcall(_G.SelectQuestLogEntry, before) end end
    end
    local pushable
    if type(Q.IsPushableQuest) == "function" then
        pushable = call(Q.IsPushableQuest, qid)
    elseif type(_G.GetQuestLogPushable) == "function" then
        pushable = call(_G.GetQuestLogPushable) and true or false
    end
    if pushable == false then
        restore()
        return nil, L["Diese Quest lässt sich nicht teilen."]
    end
    local ok = pcall(_G.QuestLogPushQuest)
    restore()
    if not ok then return nil, L["Das Spiel hat das Teilen abgelehnt."] end
    return true
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.OnEvent("QUEST_LOG_UPDATE", function()
    if not logReady then
        logReady = true
        if next(pending) or next(askWant) then wake(0.1) end
    end
    ownChanged()
end)
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
    ns.OnEvent(e, ownChanged)
end
ns.OnEvent("GROUP_ROSTER_UPDATE", function() GQ.UpdateRoster() end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(1, function()
        GQ.UpdateRoster()
        GQ.UpdateHere()
    end)
end)
-- a fight or the lockdown ended: what waits goes
ns.OnEvent("PLAYER_REGEN_ENABLED", function() if next(pending) or next(askWant) then wake(0.5) end end)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function() if next(pending) or next(askWant) then wake(1) end end)
-- the first kill on a map of several dungeons says which one (D-106)
ns.Listen("RUN", function() GQ.UpdateHere() end)

-- for the tests
function GQ._reset()
    dropAll()
    hereKeys, lastAsk, wakeAt = {}, -1000, nil
    logReady = false
end
function GQ._state() return { members = members, pending = pending, askWant = askWant, watched = watched, lastSent = lastSent } end
