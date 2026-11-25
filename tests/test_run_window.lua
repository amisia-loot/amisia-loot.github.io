-- The run window's look and what it counts (F-180, D-112; Gear/RunTimer.lua, Gear/RunGains.lua): the
-- values Zeit, Mob-XP and Gold; mob XP from the XP bar with the level-up wrap (also before the level
-- changes), quest XP not counted (before or after the bar moves), secret values skipped until the next
-- plain reading; gold only from rises outside the trading and quest windows, never negative, quest money
-- not counted; nothing outside the instance; both values and the rares kept through a /reload, copied
-- into the finished run, reset with a new run; "-" at the level cap; the coins' text; the bosses as
-- portraits (grey alive, in colour killed, the tooltips); the rares (grey until seen dead as target,
-- mouseover or loot source; a living one or another NPC never); a dungeon without rare data; many
-- bosses in rows. German and English (run.py --locale enUS).
local EN = GetLocale() == "enUS"
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local RT, RG, TW = NS.RunTimes, NS.RunGains, NS.RunTimer
_G.INSTANCE_RESET_SUCCESS = "%s has been reset."
local DM = { name = "Die Todesminen", type = "party", id = 36 }
local THANES = { name = "Halle der Thane", type = "party", id = 3065 }
local BRD = { name = "Schwarzfelstiefen", type = "party", id = 230 }
local OUT = { name = "", type = "none", id = 0 }
local DM_ENC = { 2741, 2742, 3676, 2743, 2744, 2745, 2746, 2747 }
local function enter(i)
    STUB.instance = i
    STUB.fire("PLAYER_LEAVING_WORLD")
    STUB.fire("PLAYER_ENTERING_WORLD")
end
local function kill(enc) STUB.fire("ENCOUNTER_END", enc, "Boss", 1, 5, 1) end
local function fight() STUB.fire("PLAYER_REGEN_DISABLED"); STUB.fire("PLAYER_REGEN_ENABLED") end
local function bar(xp, max) STUB.xp = { xp, max }; STUB.fire("PLAYER_XP_UPDATE") end
local function money(c) STUB.money = c; STUB.fire("PLAYER_MONEY") end
local function live() return (RT.Live()) end

STUB.roster = {}
STUB.level, STUB.xp, STUB.money = 20, { 1000, 5000 }, 5000
_G.GetMoney = function() return STUB.money end
_G.GetMaxPlayerLevel = function() return 60 end
_G.GOLD_AMOUNT_SYMBOL, _G.SILVER_AMOUNT_SYMBOL, _G.COPPER_AMOUNT_SYMBOL = nil, nil, nil

---------------------------------------------------------------------------
-- the coins' text and the XP text
---------------------------------------------------------------------------
local function coins(text) return (text:gsub("|T[^|]-UI%-(%a)%a+Icon[^|]*|t", function(c) return c:lower() end)) end
assert(TW.Money(0) == "0" and coins(TW.Money(46)) == "46c" and coins(TW.Money(1234)) == "12s 34c", TW.Money(1234))
assert(coins(TW.Money(14620)) == "1g 46s" and coins(TW.Money(120745)) == "12g 7s" and TW.Money(-5) == "0", "from a gold coin on without copper")
assert(has(TW.Money(3676), "36|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:1:0|t 76|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:1:0|t"),
    "numbers with the client's coin icons: " .. TW.Money(3676))
-- the client's own coin function is not used (Forever has none; its letters read badly)
_G.GetCoinTextureString = function(c) return "coins:" .. c end
assert(not has(TW.Money(99), "coins:"), "never the client's text")
_G.GetCoinTextureString = nil
_G.GOLD_AMOUNT_SYMBOL, _G.SILVER_AMOUNT_SYMBOL, _G.COPPER_AMOUNT_SYMBOL = nil, nil, nil

---------------------------------------------------------------------------
-- a run of the Deadmines: the window, its values, its bosses and rares
---------------------------------------------------------------------------
enter(DM)
fight()
local W = _G.AmisiaRunTimer
local l = live()
assert(l and l.k == "deadmines" and l.x == 0 and l.g == 0 and next(l.rk) == nil, "a fresh clock counts from zero")
assert(W:IsShown() and W.total:GetText() == "0:00" and W.xp:GetText() == "0" and W.gold:GetText() == "0", W.xp:GetText())
assert(W.values[1].label:GetText() == (EN and "Time" or "Zeit") and W.values[2].label:GetText() == (EN and "Mob XP" or "Mob-XP")
    and W.values[3].label:GetText() == (EN and "Loot" or "Beute"), "the three words")
assert(#W.bosses == 8 and not W.bosses[1].dim and not W.bosses[8].dim and not W.bosses[1].done and not W.bosses[1].cross:IsShown(),
    "every boss in colour, no cross, before its kill")
assert(W.rareHead:IsShown() and W.rareHead:GetText() == (EN and "Rares" or "Rare") and #W.rares == 3, "the three rares")
for _, p in ipairs(W.rares) do assert(p:IsShown() and p.dim and not p.done and not p.cross:IsShown(), "stepped back, no cross until seen dead") end
assert(W.rares[2].tip[1] == "Marisa du'Paige" and has(W.rares[2].tip[2], EN and "Not killed yet" or "Noch nicht getötet")
    and has(W.rares[2].tip[3], EN and "does not appear in every run" or "nicht in jedem Lauf"), "a rare's tooltip")
-- the boss's tooltip: its name (the scanned name in the client's language where there is one) and state
assert(W.bosses[1].tip[1] == "Rhahk'Zor" and W.bosses[1].creature == 644, "the name and the model of the order's NPC")
STUB.scanNames = { L = { [EN and "enUS" or "deDE"] = { N = { [644] = "Rhahk'Zor der Scanname" } } } }
TW.Refresh()
assert(W.bosses[1].tip[1] == "Rhahk'Zor der Scanname", "the scanned name")
STUB.scanNames = nil

-- mob XP: the bar's steps, the level-up wrap, also when the bar wraps before the level changes
bar(1300, 5000)
assert(live().x == 300 and W.xp:GetText() == "300", "a kill's XP")
bar(4900, 5000)
STUB.level = 21
bar(200, 6000)
assert(live().x == 300 + 3600 + 100 + 200, "the level-up: the old bar's rest and the new part " .. live().x)
bar(5900, 6000)
bar(50, 6000)            -- the bar wrapped, the level still says 21
STUB.level = 22
bar(50, 6000)            -- now it says 22: nothing twice
assert(live().x == 4200 + 5700 + 100 + 50, "the wrap before the level: " .. live().x)
local x = live().x
-- a quest's XP: before the bar moves, and just after
STUB.fire("QUEST_TURNED_IN", 123, 500, 0)
bar(550, 6000)
assert(live().x == x, "quest XP announced first is not counted")
bar(1550, 6000)
STUB.fire("QUEST_TURNED_IN", 124, 400, 0)
assert(live().x == x + 600, "quest XP right after the step is taken back: " .. live().x)
x = live().x
STUB.tick(5)
STUB.fire("QUEST_TURNED_IN", 125, 300, 0)   -- its step never comes
STUB.tick(5)
bar(1650, 6000)
assert(live().x == x + 100, "an old quest notice no longer counts")
x = live().x
-- secret in a boss fight: skipped, counted with the next plain reading
STUB.xp = { 2650, 6000 }
STUB.secret[2650] = true
STUB.fire("PLAYER_XP_UPDATE")
assert(live().x == x, "a secret bar is not read")
STUB.secret = {}
STUB.fire("PLAYER_REGEN_ENABLED")
assert(live().x == x + 1000, "after the fight the whole step: " .. live().x)
x = live().x

-- gold: rises outside the windows
money(6234)
assert(live().g == 1234 and coins(W.gold:GetText()) == "12s 34c", W.gold:GetText())
STUB.fire("MERCHANT_SHOW")
money(11234)             -- sold to a vendor
money(9234)              -- repaired
STUB.fire("MERCHANT_CLOSED")
assert(live().g == 1234, "a sale and a repair: nothing")
money(7234)              -- a purchase elsewhere (a flight)
assert(live().g == 1234, "never less")
STUB.fire("QUEST_TURNED_IN", 126, 0, 300)
money(7534)
assert(live().g == 1234, "a quest's money is not counted")
STUB.fire("QUEST_COMPLETE")
money(7834)
STUB.fire("QUEST_FINISHED")
assert(live().g == 1234, "money while the quest reward window is open")
for _, w in ipairs({ { "MAIL_SHOW", "MAIL_CLOSED" }, { "TRADE_SHOW", "TRADE_CLOSED" } }) do
    STUB.fire(w[1]); money(STUB.money + 1000); STUB.fire(w[2])
end
assert(live().g == 1234, "mail and trade")
money(STUB.money + 46)
assert(live().g == 1280, "loot again")
STUB.money = STUB.money + 50
STUB.secret[STUB.money] = true
STUB.fire("PLAYER_MONEY")
assert(live().g == 1280, "a secret purse is not read")
STUB.secret = {}
STUB.fire("ENCOUNTER_END", 99999, "Boss", 1, 5, 0)
assert(live().g == 1330, "the next plain reading counts it")

-- outside the instance: nothing counts (the clock runs on)
enter(OUT)
bar(2950, 6000); money(STUB.money + 500)
assert(live().x == x and live().g == 1330, "outside nothing counts")
enter(DM)
bar(3000, 6000)
assert(live().x == x + 50, "inside again: from the bar as it is now")
x = live().x

-- the bosses: in colour once killed, the tooltip with the split
STUB.tick(95)
kill(DM_ENC[1])
assert(W.bosses[1].done and W.bosses[1].dim and W.bosses[1].cross:IsShown() and not W.bosses[2].done and not W.bosses[2].dim
    and has(W.bosses[1].tip[2], EN and "Split" or "Zwischenzeit"), "killed: crossed out and stepped back")

-- rares: seen dead as the target, under the mouse, as a loot source
STUB.targetGUID, STUB.targetDead = "Creature-0-1-36-1-599-00001", false
STUB.fire("PLAYER_TARGET_CHANGED")
assert(not live().rk[599] and not W.rares[2].done, "a living rare is not killed")
STUB.targetDead = true
STUB.fire("UNIT_HEALTH", "target")
assert(live().rk[599] and W.rares[2].done and W.rares[2].cross:IsShown() and has(W.rares[2].tip[2], EN and "killed" or "getötet"), "dead as the target")
STUB.targetGUID = "Creature-0-1-36-1-644-00001"
STUB.fire("PLAYER_TARGET_CHANGED")
assert(NS.Count(live().rk) == 1, "a dead boss is no rare")
STUB.targetDead = false
local isDead = _G.UnitIsDead
_G.UnitIsDead = function(u) if u == "mouseover" then return true end return isDead(u) end
STUB.mouseoverGUID = "Creature-0-1-36-1-596-00002"
STUB.fire("UPDATE_MOUSEOVER_UNIT")
_G.UnitIsDead = isDead
assert(live().rk[596] and W.rares[1].done, "dead under the mouse")
local link = STUB.item(5195, "Brillant Smallfish", 1)
STUB.loot = { { link = link, name = "Brillant Smallfish", src = "Creature-0-1-36-1-626-00003" } }
STUB.fire("LOOT_OPENED")
STUB.fire("LOOT_CLOSED")
STUB.loot = {}
assert(live().rk[626] and W.rares[3].done, "its corpse looted")

-- a /reload: the values and the rares stay as the time does, the readings start again
local before = { x = live().x, g = live().g, at = live().at }
RT.Loaded()
RT._reset(); RG._reset()
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
l = live()
assert(l.x == before.x and l.g == before.g and l.at == before.at and l.rk[599] and l.rk[596] and l.rk[626], "kept through /reload")
bar(3100, 6000)
assert(live().x == before.x + 100, "counting goes on after the reload")
TW.Show("deadmines")
assert(W.xp:GetText() == tostring(before.x + 100) and W.rares[2].done, "the window after the reload")

-- the end: the values go into the run, the window keeps showing them
for i = 2, 8 do STUB.tick(10); kill(DM_ENC[i]) end
assert(live() == nil, "finished")
local run = RT.Of("deadmines").runs[1]
assert(run.d and run.x == before.x + 100 and run.g == 1330, "the run keeps XP and gold")
assert(W:IsShown() and W.xp:GetText() == tostring(run.x) and W.gold:GetText() == TW.Money(1330), "the final values")
assert(W.rares[1].done and W.bosses[8].done, "killed stays crossed out after the end")
-- the saved run: checked on load, an old run without the values stays valid
AmisiaDB.runTimes.inst.deadmines.runs[2] = { at = run.at - 100, t = 50, s = {}, n = 1, c = "Vuloo" }
AmisiaDB.runTimes.inst.deadmines.runs[3] = { at = run.at - 200, t = 50, s = {}, n = 1, c = "Vuloo", x = -5, g = "lots" }
RT.Loaded()
local runs = RT.Of("deadmines").runs
assert(#runs == 3 and runs[1].x == run.x and runs[1].g == 1330 and runs[2].x == nil and runs[3].x == nil and runs[3].g == nil,
    "old runs stay, bad values go")

-- a new run starts from zero
STUB.fire("CHAT_MSG_SYSTEM", "Die Todesminen has been reset.")
fight()
l = live()
assert(l and l.x == 0 and l.g == 0 and next(l.rk) == nil, "a new run resets the values")
assert(W.xp:GetText() == "0" and W.gold:GetText() == "0" and not W.rares[1].done and not W.bosses[1].done, "and the window")
RT.Stop()

---------------------------------------------------------------------------
-- the level cap: "-"
---------------------------------------------------------------------------
STUB.tick(1)   -- a run of the same second gets no clock of its own (D-96)
STUB.fire("CHAT_MSG_SYSTEM", "Die Todesminen has been reset.")
STUB.level, STUB.xp = 60, { 0, 0 }
fight()
assert(RG.Capped() and TW.XPText(0) == "-", "no XP at the cap")
-- at the cap the reputation takes the XP's place (F-235)
assert(W.values[2].label:GetText() == (EN and "Reputation" or "Ruf") and W.xp:GetText() == "0", "the reputation at the cap: " .. W.xp:GetText())
STUB.level, STUB.xp = 22, { 3100, 6000 }
assert(not RG.Capped())
RT.Stop()

---------------------------------------------------------------------------
-- a dungeon without rare data: no heading, no row
---------------------------------------------------------------------------
enter(THANES)
fight()
assert(W:IsShown() and NS.RunTimer.Shown() == "thanes" and #RT.Rares("thanes") == 0, "the Hall of Thanes")
assert(not W.rareHead:IsShown(), "no heading Rare")
for _, p in ipairs(W.rares) do assert(not p:IsShown(), "no rare portraits") end
local thanesH = W:GetHeight()
RT.Stop()

---------------------------------------------------------------------------
-- many bosses wrap into rows
---------------------------------------------------------------------------
enter(BRD)
fight()
assert(NS.RunTimer.Shown() == "brd" and #W.bosses == 21, "21 bosses")
local S = NS.Theme.RUNTIMER
local function at(p) local _, _, _, px, py = p:GetPoint(1) return px, py end
local x1, y1 = at(W.bosses[1])
local x7 = at(W.bosses[S.COLS])
local x8, y8 = at(W.bosses[S.COLS + 1])
local _, y21 = at(W.bosses[21])
assert(x8 == x1 and y8 < y1 and y21 < y8, "a new row after " .. S.COLS)
assert(x7 + S.PORT <= S.W - S.PAD, "a row stays inside the window")
assert(W:GetHeight() > thanesH + 2 * S.PORT, "the window grows with the rows")
assert(#W.rares >= 1 and W.rares[1]:IsShown(), "its rare")
RT.Stop()

-- stepping a portrait back never darkens the model with a veil or its own desaturation (both left the
-- circles black on the client): only the frame's alpha, the skull and the ring change
do
    local p = W.bosses[1]
    local desat = 0
    p.model.SetDesaturation = function() desat = desat + 1 end
    NS.W.DimPortrait(p, true)
    assert(p.dim and not p.veil and desat == 0 and p.model:GetAlpha() == NS.Theme.DBOSS.DIM_ALPHA, "dimmed by alpha only")
    NS.W.DimPortrait(p, false)
    assert(not p.dim and p.model:GetAlpha() == 1, "and back")
    p.model.SetDesaturation = nil
end

-- the grip scales the window between the limits, the scale is saved and comes back; a reset puts 1 back
do
    local S = NS.Theme.RUNTIMER
    assert(W.grip and W.grip:IsShown(), "the grip")
    assert(TW.SetScale(0.8) == 0.8 and W:GetScale() == 0.8 and AmisiaDB.settings.runTimerWindow.scale == 0.8)
    assert(TW.SetScale(0.1) == S.SCALE_MIN and TW.SetScale(9) == S.SCALE_MAX, "clamped")
    assert(TW.SetScale(1) == 1 and AmisiaDB.settings.runTimerWindow.scale == nil, "1 is not saved")
    -- a drag: the right edge follows the cursor, the top left corner stays
    W._left, W._top = 400, 600
    UIParent._top = 768
    STUB.cursorX = 400 + S.W
    W.grip:GetScript("OnMouseDown")(W.grip, "LeftButton")
    STUB.cursorX = 400 + S.W * 0.7
    W.grip:GetScript("OnUpdate")(W.grip, 0.1)
    assert(math.abs(W:GetScale() - 0.7) < 0.001, "dragged to 0.7: " .. W:GetScale())
    local point, rel, relPoint, x, y = W:GetPoint(1)
    assert(point == "TOPLEFT" and rel == UIParent and relPoint == "TOPLEFT", "anchored at the top left")
    assert(math.abs(x * 0.7 - 400) < 0.01 and math.abs(y * 0.7 - (600 - 768)) < 0.01, "the corner stays: " .. x .. " " .. y)
    W.grip:GetScript("OnMouseUp")(W.grip, "LeftButton")
    assert(AmisiaDB.settings.runTimerWindow.scale == 0.7 and AmisiaDB.settings.runTimerWindow.point == "TOPLEFT", "saved")
    assert(not W.grip:GetScript("OnUpdate"), "the drag ended")
    NS.ResetRunTimerPosition()
    assert(W:GetScale() == 1 and AmisiaDB.settings.runTimerWindow.scale == nil, "the reset")
end
---------------------------------------------------------------------------
-- F-235: a critter starts no clock; the loot's vendor value; the reputation; the rares learned in the game
---------------------------------------------------------------------------
STUB.tick(1)
enter(DM)
STUB.fire("CHAT_MSG_SYSTEM", "Die Todesminen has been reset.")
STUB.targetGUID, STUB.target, STUB.targetClass = nil, nil, nil
local units = {}
local inCombat = false
local unitLevel = _G.UnitLevel
_G.UnitExists = function(u) return units[u] ~= nil end
_G.UnitIsPlayer = function(u) return units[u] ~= nil and units[u].player == true end
_G.UnitCreatureType = function(u) return units[u] and units[u].kind end
_G.UnitLevel = function(u) if units[u] then return units[u].level end return unitLevel(u) end
_G.UnitAffectingCombat = function() return inCombat end
local CRITTER = EN and "Critter" or "Kleintier"
local function pull(target)
    units.target = target
    inCombat = true
    STUB.fire("PLAYER_REGEN_DISABLED")
end
local function calm() inCombat = false; STUB.fire("PLAYER_REGEN_ENABLED") end
-- a critter as the target: no clock; the fight ends: still none
pull({ kind = CRITTER, level = 1 })
assert(live() == nil, "a fight with a critter starts no clock")
calm()
STUB.fire("PLAYER_TARGET_CHANGED")
assert(live() == nil, "a target after the fight starts nothing")
-- "no target" is a real fight only at its start: clearing the target within a critter fight starts nothing
pull({ kind = CRITTER, level = 1 })
units.target = nil
STUB.fire("PLAYER_TARGET_CHANGED")
assert(live() == nil, "the target cleared in a critter fight starts no clock")
-- a friendly or dead unit as the new target neither
STUB.targetDead = true
units.target = { kind = "Humanoid", level = 18 }
STUB.fire("PLAYER_TARGET_CHANGED")
assert(live() == nil, "a dead target within it starts nothing")
STUB.targetDead = false
calm()
-- a critter left targeted: a mob fighting the group (its threat list, a name plate) starts the clock,
-- dated at the fight's start
local function again()
    RT.Stop()
    STUB.tick(1)
    STUB.fire("CHAT_MSG_SYSTEM", "Die Todesminen has been reset.")
    calm()
    units.nameplate3 = nil
end
units.target = { kind = CRITTER, level = 1 }
pull(units.target)
local pulledAt = time()
STUB.tick(7)
units.nameplate3 = { kind = "Humanoid", level = 18 }
STUB.fire("UNIT_THREAT_LIST_UPDATE", "nameplate3")
assert(live() and live().k == "deadmines" and live().at == pulledAt, "a mob's threat list starts it, dated at the pull")
again()
-- the mob already on a name plate when the fight begins: at once
units.nameplate3 = { kind = "Humanoid", level = 18 }
pull(units.target)
assert(live() and live().at == time(), "a fighting name plate at the start")
again()
-- or appearing later
pull(units.target)
pulledAt = time()
STUB.tick(3)
units.nameplate3 = { kind = "Humanoid", level = 18 }
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(live() and live().at == pulledAt, "a name plate that comes later")
again()
-- a critter name plate or one of a player is no foe
units.nameplate3 = { kind = CRITTER, level = 1 }
pull(units.target)
STUB.fire("UNIT_THREAT_LIST_UPDATE", "nameplate3")
units.nameplate3 = { kind = "Humanoid", level = 18, player = true }
STUB.fire("UNIT_THREAT_LIST_UPDATE", "nameplate3")
assert(live() == nil, "no foe from a critter or a player")
calm()
-- the critter's corpse left targeted did not cause the next fight: it counts
STUB.targetDead = true
assert(not RT.Harmless("target"), "a dead critter is not harmless")
pull(units.target)
assert(live() and live().k == "deadmines", "a fight with a corpse as the target starts the clock")
STUB.targetDead = false
again()
-- a creature of level 1 of another type (a language the table lacks): harmless as well
pull({ kind = "Wildtier", level = 1 })
assert(live() == nil and RT.Harmless("target"), "level 1 is harmless")
-- while that fight goes on, a real target starts the clock
units.target = { kind = "Humanoid", level = 18 }
STUB.fire("PLAYER_TARGET_CHANGED")
assert(live() and live().k == "deadmines", "a real target in the same fight starts it")
calm()
assert(not RT.Harmless("target") and not RT.Harmless("focus"), "a mob or no unit is no critter")
units.target = { kind = CRITTER, level = 1, player = true }
assert(not RT.Harmless("target"), "a player is never harmless")
units.target = nil

-- the loot's vendor value: own loot lines only, an item without data counts once it arrives
local prices, loaded = { [2589] = 13, [4306] = 150, [5000] = 7 }, { [2589] = true, [5000] = true }
local getInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(x)
    local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
    if prices[id] then
        if not loaded[id] then return nil end
        return "Item " .. id, nil, 1, 10, 1, "", "", 20, "", 134, prices[id]
    end
    return getInfo(x)
end
local function itemLink(id) return "|cffffffff|Hitem:" .. id .. "::::::::20:::::|h[Item " .. id .. "]|h|r" end
local function lootLine(id, n)
    STUB.fire("CHAT_MSG_LOOT", n and _G.LOOT_ITEM_SELF_MULTIPLE:format(itemLink(id), n) or _G.LOOT_ITEM_SELF:format(itemLink(id)))
end
lootLine(2589, 3)
assert(live().v == 39, "three linen at 13: " .. tostring(live().v))
lootLine(4306)
assert(live().v == 39, "an item without data waits")
loaded[4306] = true
STUB.fire("GET_ITEM_INFO_RECEIVED", 4306, true)
assert(live().v == 189, "and counts when it arrives: " .. live().v)
STUB.fire("GET_ITEM_INFO_RECEIVED", 4306, true)
assert(live().v == 189, "once")
-- an item whose data comes after a minute is dropped
prices[4307] = 500
lootLine(4307)
STUB.tick(61)
loaded[4307] = true
STUB.fire("GET_ITEM_INFO_RECEIVED", 4307, true)
assert(live().v == 189, "too late: not counted")
STUB.fire("CHAT_MSG_LOOT", _G.LOOT_ITEM:format("Anna", itemLink(5000)))
STUB.fire("CHAT_MSG_LOOT", _G.LOOT_ITEM_PUSHED_SELF:format(itemLink(5000)))
assert(live().v == 189, "another's loot and an item handed over are not loot")
local secretLine = _G.LOOT_ITEM_SELF:format(itemLink(5000))
STUB.secret[secretLine] = true
STUB.fire("CHAT_MSG_LOOT", secretLine)
STUB.secret = {}
assert(live().v == 189, "a secret line is not read")
-- the window: "Beute" the gold and the items, the mouse splits them
money(STUB.money + 300)
assert(live().g == 300 and coins(W.gold:GetText()) == coins(TW.Money(489)), W.gold:GetText())
assert(W.values[3].tip and has(W.values[3].tip[2], coins and "|T") and has(W.values[3].tip[3], EN and "Vendor value" or "Verkaufswert"), "the split")
NS.Set("runtimes.lootValue", false)
TW.Refresh()
assert(W.values[3].label:GetText() == "Gold" and W.gold:GetText() == TW.Money(300), "the setting off: the gold alone")
NS.Set("runtimes.lootValue", true)
TW.Refresh()
assert(W.values[3].label:GetText() == (EN and "Loot" or "Beute"), "and back")

-- the reputation: the gains of the client's lines, a loss never, a quest's not
_G.FACTION_STANDING_INCREASED = EN and "Your %s reputation has increased by %d." or "Euer Ruf bei der Fraktion '%s' hat sich um %d verbessert."
_G.FACTION_STANDING_INCREASED_BONUS = EN and "Reputation with %s increased by %d. (+%.1f bonus)" or "Euer Ruf bei der Fraktion '%s' hat sich um %d verbessert. (+%.1f Bonus)"
_G.FACTION_STANDING_DECREASED = EN and "Your %s reputation has decreased by %d." or "Euer Ruf bei der Fraktion '%s' hat sich um %d verschlechtert."
local function rep(fmt, ...) STUB.fire("CHAT_MSG_COMBAT_FACTION_CHANGE", fmt:format(...)) end
rep(_G.FACTION_STANDING_INCREASED, "Sturmwind", 25)
assert(live().f == 25, "a gain: " .. tostring(live().f))
rep(_G.FACTION_STANDING_INCREASED_BONUS, "Sturmwind", 30, 2.5)
assert(live().f == 55, "a gain with a bonus: " .. live().f)
rep(_G.FACTION_STANDING_DECREASED, "Defias", 50)
assert(live().f == 55, "a loss never counts")
STUB.tick(5)
rep(_G.FACTION_STANDING_INCREASED, "Sturmwind", 75)
STUB.fire("QUEST_TURNED_IN", 127, 0, 0)
assert(live().f == 55, "a quest's reputation just before it is taken back: " .. live().f)
rep(_G.FACTION_STANDING_INCREASED, "Sturmwind", 75)
assert(live().f == 55, "and just after it is not counted")
STUB.tick(5)
STUB.fire("QUEST_COMPLETE")
rep(_G.FACTION_STANDING_INCREASED, "Sturmwind", 10)
STUB.fire("QUEST_FINISHED")
assert(live().f == 55, "nor while the quest reward window is open")
rep(_G.FACTION_STANDING_INCREASED, "Sturmwind", 5)
assert(live().f == 60, "a kill's again")
-- below the cap "Mob-XP" with the reputation in its tooltip; at the cap "Ruf" in its place
assert(W.values[2].label:GetText() == (EN and "Mob XP" or "Mob-XP") and has(W.values[2].tip[3], "+60"), "below the cap")
STUB.level, STUB.xp = 60, { 0, 0 }
TW.Refresh()
assert(W.values[2].label:GetText() == (EN and "Reputation" or "Ruf") and W.xp:GetText() == "60", "at the cap the reputation: " .. W.xp:GetText())
STUB.level, STUB.xp = 22, { 3100, 6000 }

-- the rares learned in the game: a rare creature seen inside, alive or dead, for this dungeon
STUB.targetGUID, STUB.target, STUB.targetClass, STUB.targetDead = "Creature-0-1-36-1-99002-00001", "Gelernter Rarer", "rareelite", false
STUB.fire("PLAYER_TARGET_CHANGED")
local learnedSet = AmisiaDB.rares.list.deadmines
assert(learnedSet and learnedSet[99002] and learnedSet[99002].n == "Gelernter Rarer", "learned alive as the target")
assert(#RT.Rares("deadmines") == 4 and RT.Rares("deadmines")[4][1] == 99002, "after the data's rares")
assert(#W.rares == 4 and W.rares[4]:IsShown() and W.rares[4].creature == 99002 and not W.rares[4].done, "its portrait")
STUB.targetDead = true
STUB.fire("UNIT_HEALTH", "target")
assert(live().rk[99002] and W.rares[4].done, "and crossed out once dead")
-- a data rare, a boss and a normal creature are not learned; a name plate is
STUB.targetGUID, STUB.target, STUB.targetDead = "Creature-0-1-36-1-599-00001", "Marisa du'Paige", false
STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID, STUB.target = "Creature-0-1-36-1-644-00001", "Rhahk'Zor"
STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID, STUB.target, STUB.targetClass = "Creature-0-1-36-1-99003-00001", "Normaler Mob", "elite"
STUB.fire("PLAYER_TARGET_CHANGED")
assert(NS.Count(learnedSet) == 1, "only the new rare")
local classify, nameOf = _G.UnitClassification, _G.UnitName
_G.UnitClassification = function(u) if u == "nameplate2" then return "rare" end return classify(u) end
_G.UnitName = function(u) if u == "nameplate2" then return "Rarer der Leiste" end return nameOf(u) end
STUB.unitGUIDs.nameplate2 = "Creature-0-1-36-1-99004-00001"
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(learnedSet[99004] and learnedSet[99004].n == "Rarer der Leiste", "a name plate")
_G.UnitClassification, _G.UnitName = classify, nameOf
STUB.unitGUIDs.nameplate2 = nil
STUB.targetGUID, STUB.target, STUB.targetClass = nil, nil, nil

-- the end: loot value and reputation go into the run; its row on the page names them
for i = 1, 8 do STUB.tick(10); kill(DM_ENC[i]) end
assert(live() == nil, "finished")
run = RT.Of("deadmines").runs[1]
assert(run.v == 189 and run.f == 60 and run.g == 300, "the run keeps the loot value and the reputation")
assert(W.gold:GetText() == TW.Money(489), "the final loot")
local tipLine = NS.JournalParts.GainsTip(run)
assert(has(tipLine, "60") and has(coins(tipLine), "1s 89c"), tipLine)
assert(NS.JournalParts.GainsTip({ at = 1, t = 1, s = {}, n = 1, c = "Vuloo" }) == nil, "an old run has no line")
local rowTip
for _, row in ipairs(NS.JournalParts.TimesRows("deadmines")) do
    if row.tip and has(row.tip, "60") then rowTip = row.tip end
end
assert(rowTip, "the row of the run carries it")
-- checked on load: bad values go, old runs stay
AmisiaDB.runTimes.inst.deadmines.runs[2].v, AmisiaDB.runTimes.inst.deadmines.runs[2].f = -1, "viel"
RT.Loaded()
runs = RT.Of("deadmines").runs
assert(runs[1].v == 189 and runs[1].f == 60 and runs[2].v == nil and runs[2].f == nil, "checked on load")

-- the learned rares on load: shaped, the oldest go over the cap
local many = {}
for i = 1, 15 do many[100000 + i] = { n = "Rarer " .. i, t = 1000 + i } end
many[5] = { n = "bad|name", t = 1 }
AmisiaDB.rares = { v = 1, list = { deadmines = many, ["bad key"] = { [1] = { n = "x", t = 1 } } } }
NS.RunGains.LearnedLoaded()
local kept = AmisiaDB.rares.list.deadmines
assert(NS.Count(kept) == 12 and kept[100015] and not kept[100003] and not kept[5] and not AmisiaDB.rares.list["bad key"], "capped and checked")
local order = NS.RunGains.Learned("deadmines")
assert(#order == 12 and order[1][1] == 100004 and order[12][1] == 100015, "in the order first seen")
AmisiaDB.rares = nil

-- a map of several dungeons (D-106): nothing is learned while the wing is a guess; once a kill tells it,
-- for that wing; a rare or boss of any wing of the map is no news; never the client's "Unknown"; never
-- in a raid. The page Dungeons builds its boss list anew.
RT.Stop()
_G.UNKNOWNOBJECT = EN and "Unknown" or "Unbekannt"
enter({ name = "Schwarzfelsspitze", type = "party", id = 229 })
local function seeRare(npc, name, inst)
    STUB.targetGUID, STUB.target, STUB.targetClass, STUB.targetDead = "Creature-0-1-" .. (inst or 229) .. "-1-" .. npc .. "-00001", name, "rare", false
    STUB.fire("PLAYER_TARGET_CHANGED")
end
local function learnedIn(key, npc)
    local s = AmisiaDB.rares and AmisiaDB.rares.list[key]
    return s ~= nil and s[npc] ~= nil
end
seeRare(99010, "Rarer der Spitze")
assert(not learnedIn("lbrs", 99010) and not learnedIn("ubrs", 99010), "the wing is a guess before a kill: nothing learned")
kill(267)
assert(select(2, NS.Runs.Here()) == true, "a kill tells the wing")
seeRare(10509, "Jed Runenblick")
assert(not learnedIn("lbrs", 10509), "a rare of the other wing is no news")
seeRare(10363, "General Drakkisath")
assert(not learnedIn("lbrs", 10363), "nor a boss of the other wing")
seeRare(99011, _G.UNKNOWNOBJECT)
assert(not learnedIn("lbrs", 99011), "the client's Unknown is no name")
NS.ItemKit.cached().detail = { stale = true }
seeRare(99010, "Rarer der Spitze")
assert(learnedIn("lbrs", 99010) and not learnedIn("ubrs", 99010), "learned for the wing a kill told")
assert(NS.ItemKit.cached().detail == nil, "the page's boss lists are built anew")
assert(RT.IsRare("lbrs", 99010) and not RT.IsRare("ubrs", 99010) and RT.IsRare("ubrs", 10509), "the look-up")
-- an Unknown kept from before goes on load
AmisiaDB.rares.list.lbrs[99012] = { n = _G.UNKNOWNOBJECT, t = 5 }
RG.LearnedLoaded()
assert(not learnedIn("lbrs", 99012) and learnedIn("lbrs", 99010), "an Unknown is dropped on load")
-- a raid: its rare elites are no dungeon rares
enter({ name = "Onyxias Hort", type = "raid", id = 249 })
seeRare(99013, "Raidwache", 249)
assert(not learnedIn("onyxia", 99013), "nothing learned in a raid")
STUB.targetGUID, STUB.target, STUB.targetClass = nil, nil, nil
_G.UNKNOWNOBJECT = nil
AmisiaDB.rares = nil
enter(OUT)

C_Item.GetItemInfo = getInfo
_G.UnitExists, _G.UnitIsPlayer, _G.UnitCreatureType, _G.UnitAffectingCombat, _G.UnitLevel = nil, nil, nil, nil, unitLevel
print(EN and "run window enUS ok" or "run window ok")
