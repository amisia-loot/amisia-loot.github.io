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
-- - Rares: a rare of the dungeon (DungeonData.lua rares) counts as killed when the character sees its
--   creature dead: the target or the mouseover dead (UnitIsDead) with its NPC id in the GUID, or a loot
--   window from its corpse (GetLootSourceInfo). A rare never seen dead stays grey.
local ADDON, ns = ...
ns.Load(function()

local RG = {}
ns.RunGains = RG

local OWE = 3          -- seconds a quest's XP or money waits for (or looks back at) the bar's step
local MAX_ID = 9999999

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
end)
ns.OnEvent("PLAYER_TARGET_CHANGED", function() seeUnit("target") end)
ns.OnEvent("UNIT_HEALTH", function(unit) if ns.Plain(unit) == "target" then seeUnit("target") end end)
ns.OnEvent("UPDATE_MOUSEOVER_UNIT", function() seeUnit("mouseover") end)
ns.OnEvent("LOOT_OPENED", seeLoot)
-- a new clock counts from the bar and the purse as they are now
ns.Listen("RUNTIMES", function(what)
    if what == "start" then
        owe, recent = {}, {}
        sync()
    end
end)

-- for the tests
RG._reset = function()
    bar, purse, owe, recent, busy = nil, nil, {}, {}, {}
end
end)
