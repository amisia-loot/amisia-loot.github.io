-- Group loot roll log (Raid/GroupRolls.lua): START_LOOT_ROLL opens an entry, the roll lines of
-- CHAT_MSG_LOOT fill choices, rolls and the winner, LOOT_ROLLS_COMPLETE closes it, C_LootHistory
-- fills it where the client has it (secret names wait until they are readable), the entries go
-- into the running raid or a dungeon run, with caps; the R line of the export.
local GR = NS.GroupRolls
assert(GR, "the module loads")
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

-- the client's roll texts (the English client's; the German one has its own, the matchers follow)
_G.LOOT_ROLL_NEED = "%s has selected Need for: %s"
_G.LOOT_ROLL_GREED = "%s has selected Greed for: %s"
_G.LOOT_ROLL_DISENCHANT = "%s has selected Disenchant for: %s"
_G.LOOT_ROLL_PASSED = "%s passed on: %s"
_G.LOOT_ROLL_PASSED_AUTO = "%s automatically passed on: %s because he cannot loot that item."
_G.LOOT_ROLL_NEED_SELF = "You have selected Need for: %s"
_G.LOOT_ROLL_GREED_SELF = "You have selected Greed for: %s"
_G.LOOT_ROLL_PASSED_SELF = "You passed on: %s"
_G.LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"
_G.LOOT_ROLL_ROLLED_NEED_ROLE_BONUS = "Need Roll - %d for %s by %s + Role Bonus"
_G.LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s"
_G.LOOT_ROLL_ROLLED_DE = "Disenchant Roll - %d for %s by %s"
_G.LOOT_ROLL_WON = "%s won: %s"
_G.LOOT_ROLL_YOU_WON = "You won: %s"
_G.LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s"
_G.LOOT_ROLL_WON_NO_SPAM_GREED = "%1$s won: %3$s |cff818181(Greed - %2$d)|r"
GR._resetMatchers()

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Chorf Eisenfaust", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")
assert(NS.SettingItem("raidlog.groupRolls") and NS.Get("raidlog.groupRolls") == true, "the setting, on by default")

local vision = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local glaive = STUB.item(32837, "Warglaive of Azzinoth", 5)
local blue = STUB.item(30000, "Blue Thing", 3)

---------------------------------------------------------------------------
-- a roll from start to end: choices, numbers, the winner, complete
---------------------------------------------------------------------------
STUB.rolls[7] = vision
STUB.fire("START_LOOT_ROLL", 7, 60000, 99)
local list = GR.Entries(s)
assert(#list == 1, "one entry")
local e = list[1]
assert(e.item == 32235 and e.roll == 7 and e.handle == 99 and e.t == STUB.now and not e.done, "opened by START_LOOT_ROLL")

local function loot(text) STUB.fire("CHAT_MSG_LOOT", text, "", "", "", "") end
loot("Fraktur has selected Need for: " .. vision)
loot("You passed on: " .. vision)
loot("Chorf Eisenfaust has selected Greed for: " .. vision)
assert(e.by.Fraktur.c == "N" and e.by.Vuloo.c == "P" and e.by["Chorf Eisenfaust"].c == "G", "the choices by name")
loot("Need Roll - 87 for " .. vision .. " by Fraktur")
loot("Greed Roll - 12 for " .. vision .. " by Chorf Eisenfaust")
assert(e.by.Fraktur.r == 87 and e.by["Chorf Eisenfaust"].r == 12, "the numbers")
loot("Fraktur won: " .. vision)
assert(e.win == "Fraktur", "the winner")
STUB.fire("LOOT_ROLLS_COMPLETE", 99)
assert(e.done, "LOOT_ROLLS_COMPLETE closes it")
assert(#GR.Entries(s) == 1, "the chat lines found the open entry, no second one")
-- the class comes from the recording
assert(e.by.Fraktur.cls == "SHAMAN", "class from the members")

---------------------------------------------------------------------------
-- chat only (no START_LOOT_ROLL seen): the entry is made from the lines; everyone passed
---------------------------------------------------------------------------
loot("Fraktur passed on: " .. blue)
loot("Everyone passed on: " .. blue)
list = GR.Entries(s)
assert(#list == 2, "a second entry from the chat")
local b = list[1]
assert(b.item == 30000 and b.by.Fraktur.c == "P" and b.all and b.done and not b.win, "all passed: " .. tostring(b.all))
-- the compact winner line of a newer client
STUB.rolls[8] = glaive
STUB.fire("START_LOOT_ROLL", 8, 60000)
loot("Chorf Eisenfaust won: " .. glaive .. " |cff818181(Greed - 44)|r")
local g = GR.Entries(s)[1]
assert(g.item == 32837 and g.win == "Chorf Eisenfaust" and g.by["Chorf Eisenfaust"].r == 44 and g.by["Chorf Eisenfaust"].c == "G",
    "the no-spam line: winner, choice and number")
loot("You won: " .. glaive)
assert(g.win == "Chorf Eisenfaust", "a later line for a closed roll of another item changes nothing")
-- other loot lines are no roll lines
loot("Fraktur receives loot: " .. vision .. ".")
assert(#GR.Entries(s) == 3, "a loot line makes no entry")

---------------------------------------------------------------------------
-- C_LootHistory: the client's own roll list; secret names wait
---------------------------------------------------------------------------
local helm = STUB.item(32373, "Helm of the Illidari Shatterer", 4)
local secretName = "Vulo Sturmwind"
local history = {
    lootListKey = 3, itemHyperlink = helm, playerRollState = 5, isTied = false, allPassed = false, startTime = 0, duration = 60,
    winner = { playerName = "Fraktur", playerClass = "SHAMAN", state = 0, isWinner = true, roll = 91 },
    rollInfos = {
        { playerName = "Fraktur", playerClass = "SHAMAN", state = 0, isWinner = true, roll = 91, isSelf = false },
        { playerName = "Vuloo", playerClass = "PRIEST", state = 5, isWinner = false, isSelf = true },
        { playerName = secretName, playerClass = "MAGE", state = 3, isWinner = false, roll = 33, isSelf = false },
        { playerName = "Chorf Eisenfaust", playerClass = "WARRIOR", state = 4, isWinner = false, isSelf = false },
    },
}
local asked = 0
_G.C_LootHistory = { GetSortedInfoForDrop = function(enc, key)
    asked = asked + 1
    if enc == 601 and key == 3 then return history end
    return nil
end }
STUB.secret[secretName] = true
STUB.fire("LOOT_HISTORY_UPDATE_DROP", 601, 3)
local h = GR.Entries(s)[1]
assert(h.item == 32373 and h.hk == "601:3", "an entry from the history")
assert(h.by.Fraktur.c == "N" and h.by.Fraktur.r == 91 and h.by.Vuloo.c == "P" and h.win == "Fraktur", "choices and winner")
assert(h.by["Chorf Eisenfaust"] == nil, "no roll yet is no choice")
assert(h.wait and h.done ~= true, "a secret name: the entry waits")
for k in pairs(h.by) do assert(k ~= secretName, "a secret name is never stored") end
STUB.secret[secretName] = nil
local before = asked
STUB.tick(3)
assert(asked > before, "read again")
assert(h.by[secretName] and h.by[secretName].c == "G" and h.by[secretName].r == 33 and h.by[secretName].cls == "MAGE", "read once readable")
assert(not h.wait and h.done, "complete with a winner")
-- the same drop again: no second entry; the chat lines of the same item join it
STUB.fire("LOOT_HISTORY_UPDATE_DROP", 601, 3)
loot("Vuloo has selected Greed for: " .. helm)
assert(#GR.Entries(s) == 4 and h.by.Vuloo.c == "P", "a closed entry keeps the history's choice")
-- a history that never becomes readable stops asking after a while
STUB.secret[secretName] = true
history.lootListKey, history.winner = 4, nil
_G.C_LootHistory.GetSortedInfoForDrop = function(enc, key) asked = asked + 1; if key == 4 then return history end end
STUB.fire("LOOT_HISTORY_UPDATE_DROP", 601, 4)
STUB.tick(400)
before = asked
STUB.tick(30)
assert(asked == before, "gave up")
STUB.secret[secretName] = nil

-- a secret link or roll id is skipped without error
STUB.secret[vision] = true
STUB.rolls[9] = vision
STUB.fire("START_LOOT_ROLL", 9, 60000)
loot("Fraktur has selected Need for: " .. vision)
STUB.secret[vision] = nil
local n5 = #GR.Entries(s)
assert(n5 == 5, "the secret roll made no entry: " .. n5)

---------------------------------------------------------------------------
-- the R line of the export
---------------------------------------------------------------------------
local text = NS.ExportText({ s })
assert(has(text, ("\nR 32235 %d W Fraktur Chorf_Eisenfaust:G:12 Fraktur:N:87 Vuloo:P\n"):format(e.t)), text)
assert(has(text, ("\nR 30000 %d A - Fraktur:P\n"):format(b.t)), "all passed")
assert(has(text, "Vulo_Sturmwind:G:33"), "space as _")
local open = text:match("\nR 32373 %d+ [WAO] [^\n]*")
assert(open, "the history roll")
-- the R lines stand inside the S..E block, before E
assert(text:find("\nR ") < text:find("\nE\n") or text:find("\nR ") < text:find("\nE$"), "inside the block")
-- a raid without rolls exports as before
s.rolls = nil
assert(not has(NS.ExportText({ s }), "\nR "), "no R line without rolls")

---------------------------------------------------------------------------
-- caps: items per raid, players per item
---------------------------------------------------------------------------
for i = 1, GR.MAX_ITEMS + 20 do
    STUB.rolls[1000 + i] = vision
    STUB.fire("START_LOOT_ROLL", 1000 + i, 60000)
end
assert(#s.rolls == GR.MAX_ITEMS, "capped at " .. GR.MAX_ITEMS .. ": " .. #s.rolls)
assert(s.rolls[#s.rolls].roll == 1000 + GR.MAX_ITEMS + 20, "the newest kept")
local last = s.rolls[#s.rolls]
for i = 1, GR.MAX_PLAYERS + 5 do loot(("Spieler%d has selected Greed for: %s"):format(i, vision)) end
local np = 0
for _ in pairs(last.by) do np = np + 1 end
assert(np == GR.MAX_PLAYERS, "players capped: " .. np)

-- off: nothing is recorded
NS.Set("raidlog.groupRolls", false)
local cnt = #s.rolls
STUB.rolls[5000] = glaive
STUB.fire("START_LOOT_ROLL", 5000, 60000)
assert(#s.rolls == cnt, "off records nothing")
NS.Set("raidlog.groupRolls", true)

---------------------------------------------------------------------------
-- a dungeon run: no recording, the rolls go into the run of that instance
---------------------------------------------------------------------------
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil, "no raid recording in a dungeon")
STUB.rolls[11] = blue
STUB.fire("START_LOOT_ROLL", 11, 60000)
local runs = GR.Runs()
assert(#runs == 1 and runs[1].zone == "Die Todesminen" and runs[1].instanceID == 36, "a run of the dungeon")
assert(#GR.Entries(runs[1]) == 1 and GR.Entries(runs[1])[1].item == 30000, "its roll")
loot("Fraktur has selected Need for: " .. blue)
assert(GR.Entries(runs[1])[1].by.Fraktur.c == "N", "chat lines join it")
-- the same dungeon an hour later: the same run; another dungeon: a new one
STUB.tick(3600)
STUB.rolls[12] = blue
STUB.fire("START_LOOT_ROLL", 12, 60000)
assert(#GR.Runs() == 1 and #GR.Entries(runs[1]) == 2, "the same run")
STUB.instance = { name = "Die Höhlen des Wehklagens", type = "party", id = 43 }
STUB.fire("START_LOOT_ROLL", 13, 60000)
assert(#GR.Runs() == 1, "a roll without an item makes nothing")
STUB.rolls[13] = blue
STUB.fire("START_LOOT_ROLL", 13, 60000)
assert(#GR.Runs() == 2 and GR.Runs()[2].instanceID == 43, "a second run")
-- runs are capped
for i = 1, GR.MAX_RUNS + 3 do
    STUB.instance = { name = "Dungeon " .. i, type = "party", id = 900 + i }
    STUB.rolls[2000 + i] = blue
    STUB.fire("START_LOOT_ROLL", 2000 + i, 60000)
end
assert(#GR.Runs() == GR.MAX_RUNS, "runs capped: " .. #GR.Runs())
assert(AmisiaDB.groupRolls and AmisiaDB.groupRolls.runs == GR.Runs(), "kept in the saved data")

-- the choice names
assert(GR.ChoiceText("N") == "Bedarf" and GR.ChoiceText("G") == "Gier" and GR.ChoiceText("P") == "Passen"
    and GR.ChoiceText("D") == "Entzaubern", "choice texts")
print("group rolls ok")
