-- What a run brings besides its time (F-180, D-112): the own character's mob experience, the money it
-- looted and the dungeon's rare mobs seen dead, kept in the running clock of Gear/RunTimes.lua (live.x,
-- live.g, live.rk; saved with it, so a /reload keeps them as it keeps the time) and copied into the run
-- record at its end (run.x, run.g). Counted only while a clock runs and the character stands in its
-- instance; never sent.
-- - Mob XP: the change of the XP bar (UnitXP, UnitXPMax, UnitLevel on PLAYER_XP_UPDATE; a level-up
--   counts the rest of the old bar and the new part, also when the bar wraps before the level changes;
--   PLAYER_LEVEL_UP is not read: during it the client may still name the old level), less the XP of a turned-in quest (QUEST_TURNED_IN
--   names it; it may come just before or just after the bar moves). A secret value (a boss fight) skips
--   the reading: the next plain one (after the fight: PLAYER_REGEN_ENABLED, ENCOUNTER_END) counts the
--   whole step. No chat line and no combat log is read.
-- - Gold: a rise of GetMoney (PLAYER_MONEY) while no merchant, mail, trade, bank, auction house, guild
--   bank or quest reward window is open, less the money of a turned-in quest; a fall (repairs, a
--   purchase, a flight) never counts: the value only grows.
-- - Loot value (F-235, D-169): the vendor price (C_Item.GetItemInfo's sell price) times the count of every
--   item of the own loot lines ("Ihr erhaltet Beute: ...", the client's LOOT_ITEM_SELF and
--   LOOT_ITEM_SELF_MULTIPLE; an item handed over without looting, LOOT_ITEM_PUSHED_SELF: a quest reward,
--   a purchase, is not loot) into live.v; an item the client has not loaded yet counts once
--   GET_ITEM_INFO_RECEIVED brings its price (into the clock it was looted in).
-- - Reputation (F-235): the gains of the client's reputation lines (CHAT_MSG_COMBAT_FACTION_CHANGE, read
--   with the client's FACTION_STANDING_INCREASED and its bonus forms) into live.f, all factions together;
--   a loss never counts, nor a gain while the quest reward window is open or within 3 seconds of a
--   turned-in quest (before or after it). A secret line (a boss fight) is not read.
-- - Rares: a rare of the dungeon (DungeonData.lua rares, or learned) counts as killed when the character
--   sees its creature dead: the target or the mouseover dead (UnitIsDead) with its NPC id in the GUID, or
--   a loot window from its corpse (GetLootSourceInfo). A rare never seen dead stays grey.
-- - Learned rares (F-235): a creature the client classifies "rare" or "rareelite" (UnitClassification)
--   seen inside a dungeon or raid as the target, under the mouse or as a name plate, alive or dead, is
--   remembered for that dungeon (its NPC id and the client's name; no boss of the game's order or of the
--   item data, none the data knows already). Account-wide in AmisiaDB.rares = { v = 1, list = {
--   [dungeon or raid key] = { [NPC id] = { n = name, t = epoch first seen } } } }, at most 12 per key and
--   80 keys (the oldest go); never sent. tools/build_dungeons.py carries them into Data/DungeonData.lua.
local ADDON, ns = ...
ns.Load(function()

local RG = {}
ns.RunGains = RG

local OWE = 3          -- seconds a quest's XP or money waits for (or looks back at) the bar's step
local MAX_ID = 9999999
local MAX_PENDING = 40 -- looted items waiting for their price
local MAX_LEARN_KEY, MAX_LEARN = 12, 80   -- learned rares per key, keys

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function plainNum(v)
    v = ns.Plain(v)
    return type(v) == "number" and v == v and v or nil
end

local function clockNow()
    return type(GetTime) == "function" and GetTime() or 0
end

-- The running clock of the character while it stands in that clock's instance, else nil.
local function counting()
    local RT = ns.RunTimes
    local l = RT and RT.Live()
    if not l then return nil end
    if RT.InstanceNow() ~= l.i then return nil end
    return l
end

---------------------------------------------------------------------------
-- Quest rewards: taken off the next step, or off the step just counted
---------------------------------------------------------------------------
local owe = {}      -- [field] = { n, at }: quest XP or money not yet met by a step
local recent = {}   -- [field] = { n, at, l }: the last step counted into clock l

local function add(field, d)
    if d <= 0 then return end
    local o = owe[field]
    if o and clockNow() - o.at <= OWE then
        local take = math.min(d, o.n)
        d, o.n = d - take, o.n - take
        if o.n <= 0 then owe[field] = nil end
    end
    if d <= 0 then return end
    local l = counting()
    if not l then return end
    l[field] = math.floor((tonumber(l[field]) or 0) + d)
    recent[field] = { n = d, at = clockNow(), l = l }
    ns.Fire("RUNTIMES", "gain")
end

-- A quest's reward n of field ("x" or "g"): off the step counted just before, the rest off the next one.
local function quest(field, n)
    n = plainNum(n)
    if not n or n <= 0 then return end
    local r = recent[field]
    if r and clockNow() - r.at <= OWE and r.n > 0 then
        local back = math.min(n, r.n)
        r.l[field] = math.max(0, (tonumber(r.l[field]) or 0) - back)
        r.n, n = r.n - back, n - back
        ns.Fire("RUNTIMES", "gain")
    end
    if n > 0 then owe[field] = { n = n, at = clockNow() } end
end

---------------------------------------------------------------------------
-- Mob XP: the XP bar
---------------------------------------------------------------------------
local bar   -- { lvl, xp, max }: the bar at the last plain reading (this session)

local function readBar()
    local lvl = plainNum(call(UnitLevel, "player"))
    local xp = plainNum(call(UnitXP, "player"))
    local max = plainNum(call(UnitXPMax, "player"))
    if not (lvl and xp and max) then return nil end
    return { lvl = lvl, xp = xp, max = max }
end

-- Reads the bar and counts its step since the last reading (count false: only remembers it).
local function xpStep(count)
    local cur = readBar()
    if not cur then return end   -- secret (a boss fight) or no answer: the next reading counts it
    local was = bar
    bar = cur
    if not (was and count) then return end
    local d = 0
    if cur.lvl == was.lvl then
        if cur.xp >= was.xp then
            d = cur.xp - was.xp
        else
            -- the bar wrapped before the level says so: the rest of the old bar and the new part
            d = math.max(0, was.max - was.xp) + cur.xp
            bar.lvl = was.lvl + 1
        end
    elseif cur.lvl == was.lvl + 1 then
        d = math.max(0, was.max - was.xp) + cur.xp
    end
    -- several levels at once or a level down: not knowable, nothing counted
    add("x", d)
end
RG.XPStep = xpStep

-- Whether the character earns no XP: the level cap (GetMaxPlayerLevel, a bar of 0) or XP turned off.
function RG.Capped()
    local lvl = plainNum(call(UnitLevel, "player"))
    local max = plainNum(call(UnitXPMax, "player"))
    if max == 0 then return true end
    local cap = plainNum(call(_G.GetMaxPlayerLevel))
    if lvl and cap and cap > 0 and lvl >= cap then return true end
    return ns.Plain(call(_G.IsXPUserDisabled)) == true
end

---------------------------------------------------------------------------
-- Gold: rises of the purse outside the trading windows
---------------------------------------------------------------------------
local purse          -- the money at the last plain reading (this session)
local busy = {}      -- the windows open now in which money moves without loot
for open, close in pairs({ MERCHANT_SHOW = "MERCHANT_CLOSED", TRADE_SHOW = "TRADE_CLOSED", MAIL_SHOW = "MAIL_CLOSED",
                           BANKFRAME_OPENED = "BANKFRAME_CLOSED", AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED",
                           GUILDBANKFRAME_OPENED = "GUILDBANKFRAME_CLOSED", QUEST_COMPLETE = "QUEST_FINISHED" }) do
    local name = open
    ns.OnEvent(open, function() busy[name] = true end)
    ns.OnEvent(close, function() busy[name] = nil end)
end
function RG.Busy() return next(busy) ~= nil end

local function moneyStep(count)
    local cur = plainNum(call(_G.GetMoney))
    if not cur then return end
    local was = purse
    purse = cur
    if not (was and count) or cur <= was or RG.Busy() then return end
    add("g", cur - was)
end
RG.MoneyStep = moneyStep

---------------------------------------------------------------------------
-- Rares seen dead
---------------------------------------------------------------------------
-- The NPC id in a creature's GUID ("Creature-0-3110-0-47-644-00002E7CF2" -> 644), or nil.
local function npcOf(guid)
    guid = ns.Plain(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    id = tonumber(id)
    if not id or id < 1 or id > MAX_ID or (kind ~= "Creature" and kind ~= "Vehicle") then return nil end
    return id
end
RG.NpcOf = npcOf

-- Whether npc is a rare of a dungeon on the map of clock l (a map of several: any of them; the clock's
-- key is a guess until the first kill, D-106).
local function rareOfMap(l, npc)
    for _, key in ipairs(ns.Runs.KeysOf(l.i)) do
        for _, r in ipairs(ns.RunTimes.Rares(key)) do
            if r[1] == npc then return true end
        end
    end
    return false
end

local function rareDead(npc)
    local l = npc and counting()
    if not l or not rareOfMap(l, npc) then return end
    l.rk = type(l.rk) == "table" and l.rk or {}
    if l.rk[npc] then return end
    l.rk[npc] = true
    ns.Fire("RUNTIMES", "rare")
end
RG.RareDead = rareDead

-- unit dead and a rare of the run's map: killed.
local function seeUnit(unit)
    -- the cheap question first: UNIT_HEALTH of the target comes often in a fight
    if ns.Plain(call(UnitIsDead, unit)) ~= true then return end
    rareDead(npcOf(call(UnitGUID, unit)))
end

-- unit seen (target, mouseover): a rare creature is learned (F-235), then counted when dead.
local function meetUnit(unit)
    RG.Learn(unit)
    seeUnit(unit)
end
RG.SeeUnit = seeUnit

-- A loot window: the corpses it comes from (GetLootSourceInfo: GUID, count, GUID, count, ...).
local function seeLoot()
    if not counting() or type(_G.GetLootSourceInfo) ~= "function" then return end
    local n = tonumber(ns.Plain(call(_G.GetNumLootItems))) or 0
    for slot = 1, math.min(n, 40) do
        local src = { pcall(_G.GetLootSourceInfo, slot) }
        if src[1] then
            for i = 2, math.min(#src, 21), 2 do rareDead(npcOf(src[i])) end
        end
    end
end

---------------------------------------------------------------------------
-- The vendor value of the looted items (F-235)
---------------------------------------------------------------------------
local lootMatch      -- the own loot lines' matchers, built on first use (the global strings are loaded then)
local pending = {}   -- { id, n, l }: items looted before the client knew their price

local function ownLoot(text)
    if not lootMatch then
        lootMatch = {}
        -- the line with a count first: the single pattern would also take "...x3"
        for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }) do
            local m = ns.BuildMatcher and type(_G[key]) == "string" and ns.BuildMatcher(_G[key])
            if m then lootMatch[#lootMatch + 1] = m end
        end
    end
    for _, m in ipairs(lootMatch) do
        local a = m(text)
        local id = a and type(a[1]) == "string" and ns.ItemID(a[1])
        if id then return id, math.max(1, math.floor(tonumber(a[2]) or 1)) end
    end
    return nil
end

-- the sell price of item id, or nil while the client has not loaded it
local function sellPrice(id)
    local f = C_Item and C_Item.GetItemInfo
    if type(f) ~= "function" then return nil end
    local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(f, id)
    if not ok or ns.Plain(name) == nil then return nil end
    return math.max(0, math.floor(plainNum(price) or 0))
end
RG.SellPrice = sellPrice

local function addValue(l, d)
    if d <= 0 then return end
    l.v = math.floor((tonumber(l.v) or 0) + d)
    ns.Fire("RUNTIMES", "gain")
end

local function onLoot(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local l = counting()
    if not l then return end
    local id, n = ownLoot(text)
    if not id then return end
    local price = sellPrice(id)
    if price then
        addValue(l, price * n)
    elseif #pending < MAX_PENDING then
        pending[#pending + 1] = { id = id, n = n, l = l }
    end
end
RG.OnLoot = onLoot

-- An item's data arrived: the items looted before it count now (into the clock they were looted in,
-- while that clock still runs).
local function itemArrived(id)
    id = plainNum(id)
    if not id or #pending == 0 then return end
    local price = sellPrice(id)
    if not price then return end
    local live = ns.RunTimes.Live()
    for i = #pending, 1, -1 do
        local p = pending[i]
        if p.id == id then
            table.remove(pending, i)
            if p.l == live then addValue(p.l, price * p.n) end
        end
    end
end

---------------------------------------------------------------------------
-- Reputation (F-235)
---------------------------------------------------------------------------
local repMatch      -- the matchers of the gain lines, the most specific first
local questAt       -- clockNow() of the last turned-in quest
local repRecent = {}   -- { n, at, l }: the gains counted in the last seconds (a quest may name itself after)

-- A format of the client with a decimal number ("(+%.1f bonus)") made readable for ns.BuildMatcher: the
-- decimal is read as text.
local function plainFormat(fmt)
    return (fmt:gsub("%%%.?%d*f", "%%s"))
end

local function repGain(text)
    if not repMatch then
        repMatch = {}
        for _, key in ipairs({ "FACTION_STANDING_INCREASED_DOUBLE_BONUS", "FACTION_STANDING_INCREASED_ACH_BONUS",
                               "FACTION_STANDING_INCREASED_BONUS", "FACTION_STANDING_INCREASED" }) do
            local m = ns.BuildMatcher and type(_G[key]) == "string" and ns.BuildMatcher(plainFormat(_G[key]))
            if m then repMatch[#repMatch + 1] = m end
        end
    end
    for _, m in ipairs(repMatch) do
        local a = m(text)
        if a then
            -- the faction is a name, the gain the first whole number after it
            for i = 2, #a do
                local n = type(a[i]) == "string" and a[i]:match("^%d+$") and tonumber(a[i])
                if n then return n end
            end
        end
    end
    return nil
end
RG.RepGain = repGain

local function onFaction(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local l = counting()
    if not l then return end
    local n = repGain(text)
    if not n or n <= 0 then return end
    -- a quest's reputation is not the run's
    if busy.QUEST_COMPLETE or (questAt and clockNow() - questAt <= OWE) then return end
    l.f = math.floor((tonumber(l.f) or 0) + n)
    repRecent[#repRecent + 1] = { n = n, at = clockNow(), l = l }
    if #repRecent > 20 then table.remove(repRecent, 1) end
    ns.Fire("RUNTIMES", "gain")
end
RG.OnFaction = onFaction

-- A quest turned in: the reputation counted just before it was the quest's.
local function repQuest()
    questAt = clockNow()
    local back = false
    for i = #repRecent, 1, -1 do
        local r = repRecent[i]
        if questAt - r.at <= OWE then
            r.l.f = math.max(0, (tonumber(r.l.f) or 0) - r.n)
            back = true
        end
        table.remove(repRecent, i)
    end
    if back then ns.Fire("RUNTIMES", "gain") end
end

---------------------------------------------------------------------------
-- Rares learned in the game (F-235)
---------------------------------------------------------------------------
local RARE_CLASS = { rare = true, rareelite = true }

local function plainName(s)
    return type(s) == "string" and s ~= "" and #s <= 60 and not s:find("[|%c]") and s or nil
end

-- Shapes AmisiaDB.rares (ADDON_LOADED): keys and NPC ids checked, names plain, the caps kept.
function RG.LearnedLoaded()
    if not AmisiaDB then return nil end
    local src = type(AmisiaDB.rares) == "table" and type(AmisiaDB.rares.list) == "table" and AmisiaDB.rares.list or {}
    local out, keys = {}, {}
    for key, set in pairs(src) do
        if type(key) == "string" and #key <= 40 and key:match("^[%w_%-]+$") and type(set) == "table" then
            local list = {}
            for npc, x in pairs(set) do
                local name = type(x) == "table" and plainName(x.n)
                local t = type(x) == "table" and tonumber(x.t)
                if type(npc) == "number" and npc >= 1 and npc <= MAX_ID and npc == math.floor(npc) and name and t and t > 0 then
                    list[#list + 1] = { npc = npc, n = name, t = math.floor(t) }
                end
            end
            table.sort(list, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.npc < b.npc end)
            if #list > 0 then
                local kept = {}
                for i = 1, math.min(#list, MAX_LEARN_KEY) do kept[list[i].npc] = { n = list[i].n, t = list[i].t } end
                out[key] = kept
                keys[#keys + 1] = { key = key, t = list[1].t }
            end
        end
    end
    if #keys > MAX_LEARN then
        table.sort(keys, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.key < b.key end)
        for i = MAX_LEARN + 1, #keys do out[keys[i].key] = nil end
    end
    AmisiaDB.rares = { v = 1, list = out }
    return AmisiaDB.rares
end

local function learnedDB()
    if not AmisiaDB then return nil end
    if type(AmisiaDB.rares) ~= "table" or AmisiaDB.rares.v ~= 1 or type(AmisiaDB.rares.list) ~= "table" then
        return RG.LearnedLoaded()
    end
    return AmisiaDB.rares
end

-- The rares learned for key: { { npc, name }, ... } in the order they were first seen.
function RG.Learned(key)
    local learnedSet = learnedDB()
    local set = learnedSet and key and learnedSet.list[key]
    if type(set) ~= "table" then return {} end
    local list = {}
    for npc, x in pairs(set) do list[#list + 1] = { npc, x.n, x.t } end
    table.sort(list, function(a, b) if a[3] ~= b[3] then return a[3] < b[3] end return a[1] < b[1] end)
    for i, x in ipairs(list) do list[i] = { x[1], x[2] } end
    return list
end

-- Whether npc is a boss of key: of the game's order (the facts' npcs) or of the item data (D-152).
local function isBoss(key, npc)
    local f = ns.Runs.Fact(key)
    for _, id in ipairs(f and type(f.npcs) == "table" and f.npcs or {}) do
        if id == npc then return true end
    end
    local B = ns.BIS
    for _, e in ipairs(type(B) == "table" and type(B.DG) == "table" and B.DG or {}) do
        if e.key == key then return type(e.bossNames) == "table" and e.bossNames[npc] ~= nil end
    end
    return false
end

-- The dungeon key a creature seen now belongs to: the dungeon stood in, else the only one of the map,
-- else the running clock's; nil outside or where none can be told.
local function keyHere()
    local inst = ns.RunTimes.InstanceNow()
    if not inst then return nil end
    local keys = ns.Runs.KeysOf(inst)
    local here = ns.Runs.Here and ns.Runs.Here()
    for _, k in ipairs(keys) do
        if k == here then return k end
    end
    if #keys == 1 then return keys[1] end
    local l = ns.RunTimes.Live()
    if l and l.i == inst then return l.k end
    return nil
end

-- unit (target, mouseover, a name plate): a rare creature inside a dungeon is remembered for it.
local function learn(unit)
    if not RARE_CLASS[ns.Plain(call(UnitClassification, unit)) or ""] then return end
    local npc = npcOf(call(UnitGUID, unit))
    if not npc then return end
    local key = keyHere()
    if not key or isBoss(key, npc) then return end
    for _, r in ipairs(ns.RunTimes.Rares(key)) do
        if r[1] == npc then return end
    end
    local name = plainName(ns.Plain(call(UnitName, unit)))
    local learnedSet = name and learnedDB()
    if not learnedSet then return end
    local fresh = learnedSet.list[key] == nil
    local set = learnedSet.list[key] or {}
    learnedSet.list[key] = set
    set[npc] = { n = name, t = time() }
    local n, keys = 0, 0
    for _ in pairs(set) do n = n + 1 end
    if fresh then
        for _ in pairs(learnedSet.list) do keys = keys + 1 end
    end
    -- over a cap: the shaping drops the oldest
    if n > MAX_LEARN_KEY or keys > MAX_LEARN then RG.LearnedLoaded() end
    ns.Fire("RUNTIMES", "rare")
end
RG.Learn = learn

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- A world entered (also after a /reload): the readings start again from here, nothing counted.
local function sync()
    xpStep(false)
    moneyStep(false)
end
RG.Sync = sync

ns.OnEvent("PLAYER_ENTERING_WORLD", function() bar, purse = nil, nil; sync() end)
ns.OnEvent("PLAYER_XP_UPDATE", function() xpStep(true) end)
ns.OnEvent("PLAYER_MONEY", function() moneyStep(true) end)
-- after a fight the values are plain again: what a secret reading skipped
ns.OnEvent("PLAYER_REGEN_ENABLED", function()
    xpStep(true)
    moneyStep(true)
    seeUnit("target")
end)
ns.OnEvent("ENCOUNTER_END", function() xpStep(true); moneyStep(true) end)
ns.OnEvent("QUEST_TURNED_IN", function(_, xp, money)
    quest("x", xp)
    quest("g", money)
    repQuest()
end)
ns.OnEvent("PLAYER_TARGET_CHANGED", function() meetUnit("target") end)
ns.OnEvent("UNIT_HEALTH", function(unit) if ns.Plain(unit) == "target" then seeUnit("target") end end)
ns.OnEvent("UPDATE_MOUSEOVER_UNIT", function() meetUnit("mouseover") end)
ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit)
    unit = ns.Plain(unit)
    if type(unit) == "string" then RG.Learn(unit) end
end)
ns.OnEvent("LOOT_OPENED", seeLoot)
ns.OnEvent("CHAT_MSG_LOOT", function(text) onLoot(text) end)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function(id) itemArrived(id) end)
ns.OnEvent("CHAT_MSG_COMBAT_FACTION_CHANGE", function(text) onFaction(text) end)
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then RG.LearnedLoaded() end
end)
-- a new clock counts from the bar and the purse as they are now
ns.Listen("RUNTIMES", function(what)
    if what == "start" then
        owe, recent, pending, repRecent = {}, {}, {}, {}
        sync()
    end
end)

-- for the tests
RG._reset = function()
    bar, purse, owe, recent, busy = nil, nil, {}, {}, {}
    pending, repRecent, questAt, lootMatch, repMatch = {}, {}, nil, nil, nil
end
end)
