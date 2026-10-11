-- The raid log page's view "Würfe": the group loot rolls of the chosen raid (item, result, number of
-- choices; the choices of the chosen roll below), the dungeon runs, /amisia log würfe.
local GR = NS.GroupRolls
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

_G.LOOT_ROLL_NEED = "%s has selected Need for: %s"
_G.LOOT_ROLL_GREED = "%s has selected Greed for: %s"
_G.LOOT_ROLL_PASSED = "%s passed on: %s"
_G.LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"
_G.LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s"
_G.LOOT_ROLL_WON = "%s won: %s"
_G.LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s"
GR._resetMatchers()
local function loot(text) STUB.fire("CHAT_MSG_LOOT", text, "", "", "", "") end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording")
local vision = STUB.item(32235, "Fluchbehaftete Vision", 4)
local blue = STUB.item(30000, "Blaues Ding", 3)

-- the view without rolls
NS.ShowRaidLog("würfe")
assert(NS.CurrentPage() == "raidlog", "the page opens")
local f = NS.RaidLogPageFrame()
assert(f.views.rolls and f.views.rolls.on and f.rolls and f.rolls:IsShown(), "view Würfe")
assert(not f.log:IsShown() and not f.bench:IsShown() and not f.discord:IsShown(), "only the rolls")
assert(f.rolls.empty:IsShown() and has(f.rolls.empty.title:GetText(), "Keine Würfe"), "empty: " .. tostring(f.rolls.empty.title:GetText()))

STUB.rolls[1] = vision
STUB.fire("START_LOOT_ROLL", 1, 60000, 5)
loot("Fraktur has selected Need for: " .. vision)
loot("Chorf has selected Greed for: " .. vision)
loot("Need Roll - 87 for " .. vision .. " by Fraktur")
loot("Greed Roll - 40 for " .. vision .. " by Chorf")
loot("Fraktur won: " .. vision)
STUB.tick(60)
loot("Fraktur passed on: " .. blue)
loot("Everyone passed on: " .. blue)
STUB.tick(60)
STUB.rolls[2] = vision
STUB.fire("START_LOOT_ROLL", 2, 60000, 6)
loot("Chorf has selected Need for: " .. vision)
NS.Refresh()

local list = f.rolls.list
local function rows()
    local out = {}
    for _, r in ipairs(list.rows) do if r:IsShown() then out[#out + 1] = r end end
    return out
end
local shown = rows()
assert(#shown == 3, "three rolls: " .. #shown)
assert(not f.rolls.empty:IsShown(), "no empty state")
assert(has(f.views.rolls.label:GetText(), "Würfe (3)"), f.views.rolls.label:GetText())
-- newest first: the open one, everyone passed, the won one
assert(has(shown[1].what:GetText(), "Fluchbehaftete Vision") and has(shown[1].result:GetText(), "offen"), shown[1].result:GetText())
assert(has(shown[2].what:GetText(), "Blaues Ding") and has(shown[2].result:GetText(), "alle gepasst"), shown[2].result:GetText())
assert(has(shown[3].result:GetText(), "Fraktur") and has(shown[3].result:GetText(), "Bedarf") and has(shown[3].result:GetText(), "87"),
    shown[3].result:GetText())
assert(shown[3].n:GetText() == "2", "two choices")
assert(shown[1].time:GetText() == date("%H:%M", s.rolls[3].t), "the time")
-- the item colour of its quality
assert(has(shown[3].what:GetText(), "|cffa335ee"), "epic colour: " .. shown[3].what:GetText())

-- the choices of a roll
shown[3]:Click()
assert(shown[3].sel:IsShown(), "marked")
local d = f.rolls.detail.fs:GetText()
assert(has(d, "Fraktur") and has(d, "Bedarf 87") and has(d, "Chorf") and has(d, "Gier 40") and has(d, "Gewinner"), d)
assert(d:find("Fraktur", 1, true) < d:find("Chorf", 1, true), "the winner first")
assert(has(f.rolls.title:GetText(), "Fluchbehaftete Vision"), f.rolls.title:GetText())

-- raider view: the same
NS.Set("ui.view", "raider")
NS.Refresh()
assert(f.rolls:IsShown() and #rows() == 3, "raiders see the rolls")
NS.Reset("ui.view")

-- dungeons: the runs, newest first, a header per run
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.rolls[3] = blue
STUB.fire("START_LOOT_ROLL", 3, 60000)
loot("Fraktur has selected Greed for: " .. blue)
NS.ShowRaidLog("würfe")
f.rolls.source:Click()
assert(f.rolls.source.current == "runs", "source Dungeons")
shown = rows()
assert(#shown == 2 and has(shown[1].what:GetText(), "Die Todesminen") and has(shown[2].what:GetText(), "Blaues Ding"),
    "a header and its roll: " .. (shown[1] and shown[1].what:GetText() or "-"))
shown[2]:Click()
assert(has(f.rolls.detail.fs:GetText(), "Gier"), f.rolls.detail.fs:GetText())
f.rolls.source:Click()
assert(f.rolls.source.current == "raid", "back to the raid")

-- the slash word, German and English
NS.ShowPage("overview")
NS.Dispatch("log würfe")
assert(NS.CurrentPage() == "raidlog" and f.rolls:IsShown(), "/amisia log würfe")
NS.ShowRaidLog("verlauf")
assert(f.log:IsShown() and not f.rolls:IsShown(), "back to Verlauf")
NS.Dispatch("log rolls")
assert(f.rolls:IsShown(), "/amisia log rolls")
print("group rolls page ok")
