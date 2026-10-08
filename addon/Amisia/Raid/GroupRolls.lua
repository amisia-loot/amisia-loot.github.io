-- Amisia group loot roll log: who chose Need, Greed, Disenchant or Pass on a group loot item, the
-- numbers and who won. START_LOOT_ROLL opens an entry (the item from GetLootRollItemLink), the roll
-- lines of CHAT_MSG_LOOT ("X has selected Need for: [item]", "Need Roll - 87 for [item] by X",
-- "X won: [item]", built from the client's own LOOT_ROLL_* texts) fill it, LOOT_ROLLS_COMPLETE closes
-- it. Where the client has C_LootHistory (Forever: the roll list of the loot history frame),
-- LOOT_HISTORY_UPDATE_DROP reads the whole drop at once; a name or value that is secret (a boss
-- fight on Forever) is never stored: the drop is read again every few seconds until it is readable
-- (at most READ_FOR seconds).
-- The entries go into the running raid recording (s.rolls), else into a dungeon run of the instance
-- (AmisiaDB.groupRolls.runs; outside an instance: of the zone). Caps: MAX_ITEMS per raid or run,
-- MAX_PLAYERS per item, MAX_RUNS runs.
--
-- entry = { item, t, roll = rollID, handle = lootHandle, hk = "encounter:lootListKey", done, win = name,
--           all = everyone passed, wait = a secret value waits, by = { [name] = { c = N|O|T|G|D|P, r = number, cls } } }
-- run   = { id, zone, instanceID, start, last, rolls = { entry ... } }
local ADDON, ns = ...
local L = ns.L

local GR = {}
ns.GroupRolls = GR

GR.MAX_ITEMS = 150      -- entries per raid or run
GR.MAX_PLAYERS = 40     -- choices per entry
GR.MAX_RUNS = 20        -- dungeon runs kept
local RUN_RESUME = 2 * 3600   -- seconds: a roll this soon after the last one in the same place joins that run
local MATCH_FOR = 15 * 60     -- seconds: a chat line belongs to an entry of its item this young
local READ_EVERY = 2          -- seconds between reads of a history drop that still waits
local READ_FOR = 300          -- seconds a history drop is read again at most

-- Enum.EncounterLootDropRollState -> choice (4 NoRoll: not chosen yet)
local STATE = { [0] = "N", [1] = "O", [2] = "T", [3] = "G", [5] = "P" }
local CHOICE_TEXT = { N = ns.N_("Bedarf"), O = ns.N_("Bedarf (Zweitspec)"), T = ns.N_("Transmog"), G = ns.N_("Gier"),
    D = ns.N_("Entzaubern"), P = ns.N_("Passen") }
GR.CHOICES = { "N", "O", "T", "G", "D", "P" }

function GR.ChoiceText(c) return L[CHOICE_TEXT[c] or "?"] end

local function plainNumber(v) return tonumber(ns.Plain(v)) end
local function plainText(v)
    v = ns.Plain(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

---------------------------------------------------------------------------
-- Where the entries go
---------------------------------------------------------------------------
local function store()
    if not AmisiaDB then return nil end
    local g = AmisiaDB.groupRolls
    if type(g) ~= "table" or type(g.runs) ~= "table" then
        g = { runs = {} }
        AmisiaDB.groupRolls = g
    end
    return g
end

-- The dungeon runs, oldest first.
function GR.Runs()
    local g = store()
    return g and g.runs or {}
end

local function place()
    local name, kind, _, _, _, _, _, id = GetInstanceInfo()
    name, kind, id = plainText(name), plainText(kind), plainNumber(id)
    if kind == nil or kind == "none" then
        name = plainText(GetRealZoneText and GetRealZoneText()) or name
        id = 0
    end
    return name or "?", id or 0
end

-- The raid recording or the run of this place, made when create; nil when the log is off.
local function container(create)
    if not ns.Get("raidlog.groupRolls") then return nil end
    local s = ns.Active and ns.Active()
    if s then
        s.rolls = type(s.rolls) == "table" and s.rolls or {}
        return s
    end
    local g = store()
    if not g then return nil end
    local zone, id = place()
    local t = time()
    local last = g.runs[#g.runs]
    if last and last.zone == zone and last.instanceID == id and t - (last.last or 0) <= RUN_RESUME then
        return last
    end
    if not create then return nil end
    local run = { id = date("%Y%m%d%H%M%S", t) .. "-" .. tostring(id), zone = zone, instanceID = id, start = t, last = t, rolls = {} }
    g.runs[#g.runs + 1] = run
    while #g.runs > GR.MAX_RUNS do table.remove(g.runs, 1) end
    return run
end
GR._container = container

local function add(c, e)
    c.rolls[#c.rolls + 1] = e
    while #c.rolls > GR.MAX_ITEMS do table.remove(c.rolls, 1) end
    c.last = math.max(c.last or 0, e.t)
    return e
end

local function newEntry(c, item)
    return add(c, { item = item, t = time(), by = {} })
end

-- The entries of a raid or run, newest first.
function GR.Entries(c)
    local out = {}
    local list = type(c) == "table" and type(c.rolls) == "table" and c.rolls or {}
    for i = #list, 1, -1 do out[#out + 1] = list[i] end
    return out
end

function GR.Count(c)
    return type(c) == "table" and type(c.rolls) == "table" and #c.rolls or 0
end

local function classOf(c, name)
    local m = c.members and c.members[name]
    return m and m.class ~= "" and m.class or nil
end

local function count(by)
    local n = 0
    for _ in pairs(by) do n = n + 1 end
    return n
end

-- The key of name in by: the same spelling, else the one key ns.SameName matches ("Anna" and "Anna
-- Sturmwind": the chat line and the loot history spell a name differently); nil for none or two.
local function keyIn(by, name)
    if by[name] then return name end
    local hit
    for k in pairs(by) do
        if ns.SameName(k, name) then
            if hit then return nil end
            hit = k
        end
    end
    return hit
end
GR._keyIn = keyIn

-- Notes a choice (and number) of name; an entry full of names takes no new one. One player is one
-- row, under the fullest spelling heard.
local function note(c, e, name, choice, roll, cls)
    local k = keyIn(e.by, name)
    if k and k ~= name and name:find(" ", 1, true) and not k:find(" ", 1, true) then
        e.by[name], e.by[k] = e.by[k], nil
        if e.win == k then e.win = name end
        k = name
    end
    local p = k and e.by[k]
    if p then name = k end
    if not p then
        if count(e.by) >= GR.MAX_PLAYERS then return end
        p = {}
        e.by[name] = p
    end
    if choice then p.c = choice end
    if roll then p.r = roll end
    p.cls = cls or p.cls or classOf(c, name)
end

local function finish(e, winner)
    if winner then e.win = keyIn(e.by, winner) or winner end
    e.done = true
end

---------------------------------------------------------------------------
-- START_LOOT_ROLL, LOOT_ROLLS_COMPLETE, LOOT_ITEM_ROLL_WON
---------------------------------------------------------------------------
local function itemOf(link)
    link = plainText(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

local function onStart(rollID, _, handle)
    rollID = plainNumber(rollID)
    if not rollID or type(_G.GetLootRollItemLink) ~= "function" then return end
    local ok, link = pcall(_G.GetLootRollItemLink, rollID)
    local item = ok and itemOf(link)
    if not item then return end
    local c = container(true)
    if not c then return end
    for _, e in ipairs(c.rolls) do
        if e.roll == rollID and not e.done and time() - e.t <= MATCH_FOR then return end
    end
    local e = newEntry(c, item)
    e.roll, e.handle = rollID, plainNumber(handle)
    if ns.Refresh then ns.Refresh() end
end

local function onComplete(handle)
    handle = plainNumber(handle)
    local c = handle and container(false)
    if not c then return end
    for _, e in ipairs(c.rolls) do
        if e.handle == handle then e.done = true end
    end
    if ns.Refresh then ns.Refresh() end
end

---------------------------------------------------------------------------
-- The roll lines of CHAT_MSG_LOOT
---------------------------------------------------------------------------
-- { global, kind, choice, fields }: fields names the matcher's captures in order (name, link, roll);
-- "self" lines are the player's own. Most specific first: a plain line would also take a longer one,
-- and "%s passed on: %s" the line "Everyone passed on: [item]".
local LINES = {
    { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", "N", { "name", "roll", "link" } },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", "G", { "name", "roll", "link" } },
    { "LOOT_ROLL_WON_NO_SPAM_DE", "won", "D", { "name", "roll", "link" } },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "won", "N", { "roll", "link" }, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "won", "G", { "roll", "link" }, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "won", "D", { "roll", "link" }, true },
    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "rolled", "N", { "roll", "link", "name" } },
    { "LOOT_ROLL_ROLLED_NEED", "rolled", "N", { "roll", "link", "name" } },
    { "LOOT_ROLL_ROLLED_GREED", "rolled", "G", { "roll", "link", "name" } },
    { "LOOT_ROLL_ROLLED_DE", "rolled", "D", { "roll", "link", "name" } },
    { "LOOT_ROLL_ALL_PASSED", "all", nil, { "link" } },
    { "LOOT_ROLL_PASSED_SELF_AUTO", "chose", "P", { "link" }, true },
    { "LOOT_ROLL_PASSED_AUTO", "chose", "P", { "name", "link" } },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", "chose", "P", { "name", "link" } },
    { "LOOT_ROLL_NEED_SELF", "chose", "N", { "link" }, true },
    { "LOOT_ROLL_GREED_SELF", "chose", "G", { "link" }, true },
    { "LOOT_ROLL_DISENCHANT_SELF", "chose", "D", { "link" }, true },
    { "LOOT_ROLL_PASSED_SELF", "chose", "P", { "link" }, true },
    { "LOOT_ROLL_NEED", "chose", "N", { "name", "link" } },
    { "LOOT_ROLL_GREED", "chose", "G", { "name", "link" } },
    { "LOOT_ROLL_DISENCHANT", "chose", "D", { "name", "link" } },
    { "LOOT_ROLL_PASSED", "chose", "P", { "name", "link" } },
    { "LOOT_ROLL_YOU_WON", "won", nil, { "link" }, true },
    { "LOOT_ROLL_WON", "won", nil, { "name", "link" } },
}
GR.LINES = LINES

local matchers
function GR._resetMatchers() matchers = nil end

local function getMatchers()
    if matchers then return matchers end
    matchers = {}
    for _, d in ipairs(LINES) do
        local m = ns.BuildMatcher(_G[d[1]])
        if m then matchers[#matchers + 1] = { match = m, kind = d[2], choice = d[3], fields = d[4], self = d[5] } end
    end
    return matchers
end

-- A roll line as { kind, choice, name, item, roll }, or nil.
function GR.ParseLine(text)
    if type(text) ~= "string" or not text:find("item:", 1, true) then return nil end
    for _, m in ipairs(getMatchers()) do
        local a = m.match(text)
        if a then
            local r = { kind = m.kind, choice = m.choice }
            for i, f in ipairs(m.fields) do r[f] = a[i] end
            r.item = itemOf(r.link)
            r.roll = tonumber(r.roll)
            if m.self then r.name = ns.UnitFullName("player") else r.name = ns.FullName(r.name) end
            if r.item and (r.name or m.kind == "all") then return r end
        end
    end
    return nil
end

-- The entry a chat line of item belongs to: open entries first (choices and numbers: the newest
-- without that name's choice; a winner: the oldest without a winner), else for a choice the newest
-- young entry still without that name. nil: make a new one (fresh) or drop the line (false).
local function entryFor(c, item, kind, name)
    local t = time()
    local open, recent = {}, {}
    for _, e in ipairs(c.rolls) do
        if e.item == item and t - e.t <= MATCH_FOR then
            recent[#recent + 1] = e
            if not e.done then open[#open + 1] = e end
        end
    end
    if kind == "won" or kind == "all" then
        for _, e in ipairs(open) do
            if not e.win then return e end
        end
        if #recent > 0 then return false end
        return nil
    end
    for i = #open, 1, -1 do
        local p = open[i].by[keyIn(open[i].by, name) or name]
        if not p or (kind == "rolled" and not p.r) or (kind == "chose" and not p.c) then return open[i] end
    end
    for i = #recent, 1, -1 do
        if not keyIn(recent[i].by, name) then return recent[i] end
    end
    if #recent > 0 then return false end
    return nil
end

local function onChat(text)
    text = plainText(text)
    local r = text and GR.ParseLine(text)
    if not r then return end
    local c = container(true)
    if not c then return end
    local e = entryFor(c, r.item, r.kind, r.name)
    if e == false then return end
    e = e or newEntry(c, r.item)
    if r.kind == "all" then
        e.all = true
        finish(e)
    elseif r.kind == "won" then
        if r.choice or r.roll then note(c, e, r.name, r.choice, r.roll) end
        finish(e, r.name)
    else
        note(c, e, r.name, r.choice, r.roll)
    end
    if ns.Refresh then ns.Refresh() end
end
GR._onChat = onChat

---------------------------------------------------------------------------
-- C_LootHistory (Forever)
---------------------------------------------------------------------------
local pending = {}   -- "enc:key" -> { enc, key, since }
local reading = false

-- Reads one drop of the loot history into its entry; returns true when every value was readable.
local function readDrop(enc, key)
    local api = _G.C_LootHistory
    local fn = type(api) == "table" and api.GetSortedInfoForDrop
    if type(fn) ~= "function" then return true end
    local ok, info = pcall(fn, enc, key)
    if not ok or type(info) ~= "table" then return true end
    local item = itemOf(info.itemHyperlink)
    if not item then return false end
    local c = container(true)
    if not c then return true end
    local hk = enc .. ":" .. key
    local e
    for _, x in ipairs(c.rolls) do
        if x.hk == hk then e = x end
    end
    if not e then
        -- the entry START_LOOT_ROLL opened for this item, while no history drop has it yet
        for i = #c.rolls, 1, -1 do
            local x = c.rolls[i]
            if x.item == item and not x.hk and not x.done and time() - x.t <= MATCH_FOR then e = x break end
        end
    end
    e = e or newEntry(c, item)
    e.hk = hk
    local complete = true
    for _, r in ipairs(type(info.rollInfos) == "table" and info.rollInfos or {}) do
        local name = plainText(r.playerName)
        local state = plainNumber(r.state)
        if type(r.playerName) ~= "nil" and not name then complete = false end
        if type(r.state) ~= "nil" and not state then complete = false end
        local roll = ns.Plain(r.roll)
        if type(r.roll) ~= "nil" and roll == nil then complete = false end
        local cls = plainText(r.playerClass)
        local choice = state and STATE[state]
        if name and choice then
            note(c, e, ns.FullName(name), choice, tonumber(roll), cls)
        end
    end
    local all = ns.Plain(info.allPassed)
    local w = type(info.winner) == "table" and info.winner or nil
    local winner = w and plainText(w.playerName)
    if w and type(w.playerName) ~= "nil" and not winner then complete = false end
    -- the result: closed only once every value was read (a waiting entry is read again)
    if all == true then e.all = true elseif winner then e.win = keyIn(e.by, ns.FullName(winner)) or ns.FullName(winner) end
    if complete and (e.all or e.win) then e.done = true end
    e.wait = (not complete) or nil
    if ns.Refresh then ns.Refresh() end
    return complete
end

local function readPending()
    reading = false
    local now, any = GetTime(), false
    for k, p in pairs(pending) do
        local ok, done = pcall(readDrop, p.enc, p.key)
        if (ok and done) or not ok or now - p.since > READ_FOR then
            pending[k] = nil
        else
            any = true
        end
    end
    if any and not reading then
        reading = true
        C_Timer.After(READ_EVERY, readPending)
    end
end

local function onHistory(enc, key)
    enc, key = plainNumber(enc), plainNumber(key)
    if not enc or not key or not ns.Get("raidlog.groupRolls") then return end
    if readDrop(enc, key) then
        pending[enc .. ":" .. key] = nil
        return
    end
    local k = enc .. ":" .. key
    pending[k] = pending[k] or { enc = enc, key = key, since = GetTime() }
    if not reading then
        reading = true
        C_Timer.After(READ_EVERY, readPending)
    end
end

-- the own win (the client's toast): the winner and the number
local function onWon(link, _, rollType, roll)
    local item = itemOf(link)
    local c = item and container(false)
    if not c then return end
    local me = ns.UnitFullName("player")
    local e = entryFor(c, item, "won", me)
    if not e then return end
    local choice = ({ [1] = "N", [2] = "G", [3] = "D" })[plainNumber(rollType) or -1]
    note(c, e, me, choice, plainNumber(roll))
    finish(e, me)
end

ns.OnEvent("START_LOOT_ROLL", function(...) if ns.Get("raidlog.groupRolls") then onStart(...) end end)
ns.OnEvent("LOOT_ROLLS_COMPLETE", onComplete)
ns.OnEvent("LOOT_ITEM_ROLL_WON", onWon)
ns.OnEvent("LOOT_HISTORY_UPDATE_DROP", onHistory)
ns.OnEvent("CHAT_MSG_LOOT", function(text) if ns.Get("raidlog.groupRolls") then onChat(text) end end)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    if next(pending) and not reading then
        reading = true
        C_Timer.After(READ_EVERY, readPending)
    end
end)

---------------------------------------------------------------------------
-- The export: one R line per entry of a raid
---------------------------------------------------------------------------
-- R <itemID> <epoch> <W|A|O> <winner|-> <name>:<N|O|T|G|D|P|?>[:<roll>] ...
-- W: a winner, A: everyone passed, O: open (no result seen). Inside the S..E block of the raid.
function ns.GroupRollLines(s, lines, used)
    local list = type(s.rolls) == "table" and s.rolls or {}
    for _, e in ipairs(list) do
        local names = {}
        for name in pairs(e.by or {}) do names[#names + 1] = name end
        table.sort(names)
        local parts = {}
        for i, name in ipairs(names) do
            local p = e.by[name]
            parts[i] = ("%s:%s%s"):format(ns.ExportName(name), p.c or "?", p.r and (":" .. p.r) or "")
        end
        local state = e.win and "W" or (e.all and "A") or "O"
        lines[#lines + 1] = ("R %d %d %s %s%s"):format(e.item, e.t or 0, state, e.win and ns.ExportName(e.win) or "-",
            #parts > 0 and (" " .. table.concat(parts, " ")) or "")
        used[e.item] = true
    end
end

ns.RaidLogSettings.items[#ns.RaidLogSettings.items + 1] = { key = "raidlog.groupRolls", type = "toggle",
    label = L["Würfe bei Gruppenloot aufzeichnen"], default = true,
    tip = L["Bedarf, Gier, Entzaubern und Passen jedes Spielers mit Zahl und Gewinner, im Raid oder im Dungeon."] }
ns.RegisterSettings(ns.RaidLogSettings)
