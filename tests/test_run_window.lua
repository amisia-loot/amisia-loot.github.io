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
assert(TW.Money(0) == "0" and TW.Money(46) == "46c" and TW.Money(1234) == "12s 34c", TW.Money(1234))
assert(TW.Money(14620) == "1g 46s" and TW.Money(120745) == "12g 7s" and TW.Money(-5) == "0", "from a gold coin on without copper")
_G.GOLD_AMOUNT_SYMBOL, _G.SILVER_AMOUNT_SYMBOL, _G.COPPER_AMOUNT_SYMBOL = "G", "S", "K"
assert(TW.Money(10203) == "1G 2S", "the client's symbols: " .. TW.Money(10203))
_G.GetCoinTextureString = function(c) return "coins:" .. c end
assert(TW.Money(14620) == "coins:14600" and TW.Money(99) == "coins:99", "the client's coins")
STUB.secret["coins:5"] = true
assert(TW.Money(5) == "5K", "a secret answer: our own text")
STUB.secret = {}
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
    and W.values[3].label:GetText() == "Gold", "the three words")
assert(#W.bosses == 8 and W.bosses[1].dim and W.bosses[8].dim, "every boss grey before its kill")
assert(W.rareHead:IsShown() and W.rareHead:GetText() == (EN and "Rares" or "Rare") and #W.rares == 3, "the three rares")
for _, p in ipairs(W.rares) do assert(p:IsShown() and p.dim, "grey until seen dead") end
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
assert(live().g == 1234 and W.gold:GetText() == "12s 34c", W.gold:GetText())
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
assert(not W.bosses[1].dim and W.bosses[2].dim and has(W.bosses[1].tip[2], EN and "Split" or "Zwischenzeit"), "killed: in colour")

-- rares: seen dead as the target, under the mouse, as a loot source
STUB.targetGUID, STUB.targetDead = "Creature-0-1-36-1-599-00001", false
STUB.fire("PLAYER_TARGET_CHANGED")
assert(not live().rk[599] and W.rares[2].dim, "a living rare is not killed")
STUB.targetDead = true
STUB.fire("UNIT_HEALTH", "target")
assert(live().rk[599] and not W.rares[2].dim and has(W.rares[2].tip[2], EN and "killed" or "getötet"), "dead as the target")
STUB.targetGUID = "Creature-0-1-36-1-644-00001"
STUB.fire("PLAYER_TARGET_CHANGED")
assert(NS.Count(live().rk) == 1, "a dead boss is no rare")
STUB.targetDead = false
local isDead = _G.UnitIsDead
_G.UnitIsDead = function(u) if u == "mouseover" then return true end return isDead(u) end
STUB.mouseoverGUID = "Creature-0-1-36-1-596-00002"
STUB.fire("UPDATE_MOUSEOVER_UNIT")
_G.UnitIsDead = isDead
assert(live().rk[596] and not W.rares[1].dim, "dead under the mouse")
local link = STUB.item(5195, "Brillant Smallfish", 1)
STUB.loot = { { link = link, name = "Brillant Smallfish", src = "Creature-0-1-36-1-626-00003" } }
STUB.fire("LOOT_OPENED")
STUB.fire("LOOT_CLOSED")
STUB.loot = {}
assert(live().rk[626] and not W.rares[3].dim, "its corpse looted")

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
assert(W.xp:GetText() == tostring(before.x + 100) and not W.rares[2].dim, "the window after the reload")

-- the end: the values go into the run, the window keeps showing them
for i = 2, 8 do STUB.tick(10); kill(DM_ENC[i]) end
assert(live() == nil, "finished")
local run = RT.Of("deadmines").runs[1]
assert(run.d and run.x == before.x + 100 and run.g == 1330, "the run keeps XP and gold")
assert(W:IsShown() and W.xp:GetText() == tostring(run.x) and W.gold:GetText() == TW.Money(1330), "the final values")
assert(not W.rares[1].dim and not W.bosses[8].dim, "killed stays coloured after the end")
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
assert(W.xp:GetText() == "0" and W.gold:GetText() == "0" and W.rares[1].dim and W.bosses[1].dim, "and the window")
RT.Stop()

---------------------------------------------------------------------------
-- the level cap: "-"
---------------------------------------------------------------------------
STUB.tick(1)   -- a run of the same second gets no clock of its own (D-96)
STUB.fire("CHAT_MSG_SYSTEM", "Die Todesminen has been reset.")
STUB.level, STUB.xp = 60, { 0, 0 }
fight()
assert(RG.Capped() and W.xp:GetText() == "-", "no XP at the cap: " .. W.xp:GetText())
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

print(EN and "run window enUS ok" or "run window ok")
