-- The roll window's upgrade view (RollFrame.lua): a column per roller from the answers to "Wer
-- braucht das?" (upgrade percent, a new slot, a wish, nothing), the own comparison for the own row,
-- a line naming everyone it is an upgrade or a wish for (answers, guild wishes, the own scoring), the
-- window asks by itself when a round starts and the item was not asked, the appearance hint by
-- quality, binding, instance type and setting, and the switch bis.compare.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.class, STUB.level = "WARRIOR", 60
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Anna", class = "WARRIOR" },
    { name = "Bob", class = "MAGE" }, { name = "Kim", class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

NS.GEAR = { game = "forever", cap = 60, built = "test-rollup", I = {}, Z = {}, S = {} }
Gear._reset()
local function gear(id, name, loc, s, q, bind)
    local link = STUB.item(id, name, q or 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 4
    it.stats, it.minLevel, it.bind = { ITEM_MOD_STRENGTH_SHORT = s }, 60, bind or 1
    return link
end
local helm = gear(301, "Helm A", "HEAD", 40, 3, 1)       -- blue, bind on pickup
local worn = gear(302, "Helm B", "HEAD", 30)
local epic = gear(303, "Helm Episch", "HEAD", 50, 4, 1)
local boe = gear(304, "Helm Grün", "HEAD", 35, 2, 2)     -- green, bind on equip
STUB.worn[1] = worn
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

-- "Wer braucht das?" as the window reads it
local asked = {}
local answers = {}
NS.NeedCanAsk = function() return true end
NS.NeedAsk = function(items) asked[#asked + 1] = items[1]; return "abcd" end
NS.NeedOf = function(item) return answers[NS.ItemID(item) or item] end
local realWishers = NS.WishersOf
NS.WishersOf = function(item, groupOnly)
    if NS.ItemID(item) == 301 or item == 301 then return { { name = "Kim", prio = 3, inGroup = true } } end
    return {}
end

STUB.instance = { name = "Ruins of Lordaeron", type = "party", id = 9001 }
assert(NS.StartRoll(helm, 20))
NS.ShowRollFrame()
local F = NS.RollFrame
assert(#asked == 1 and asked[1] == 301, "the window asks when the round starts")
NS.OnRollChanged()
assert(#asked == 1, "once per round")

answers[301] = { up = { { name = "Anna", gain = 30, pct = 25, slot = "HEAD" }, { name = "Fraktur", gain = 10, pct = 999, slot = "HEAD" } },
    wish = { { name = "Bob", prio = 2 } }, none = 1, asked = 4, missing = 0, without = {} }
NS.Fire("NEED", { 301 })
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Anna", 90, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 80, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Bob", 70, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo", 60, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Kim", 50, 1, 100))
local col = {}
for i = 1, 5 do col[F.rows[i].who] = F.rows[i].up:GetText() end
local own = NS.UpgradeOf(helm)
assert(has(col.Anna, "+25%"), "Anna's answer: " .. tostring(col.Anna))
assert(has(col.Fraktur, "neu"), "an empty slot: " .. tostring(col.Fraktur))
assert(has(col.Bob, "W"), "a wish: " .. tostring(col.Bob))
assert(has(col.Vuloo, ("+%d%%"):format(own.pct)), "the own row from the own scoring: " .. tostring(col.Vuloo))
assert(has(col.Kim, "W"), "a guild wish counts as a wish: " .. tostring(col.Kim))

local line = F.upLine:GetText()
assert(has(line, "Upgrade für: Fraktur neu") and has(line, "Anna +25 %") and has(line, ("du +%d %%"):format(own.pct)), "the line: " .. line)
assert(has(line, "Wunsch: Bob") and has(line, "Kim"), "wishes in the line: " .. line)

-- the appearance: a blue bind-on-pickup item in a dungeon
local look = F.lookLine
assert(look:IsShown() and has(look:GetText(), "Aussehen") and has(look:GetText(), "laut Blizzard"), "the hint: " .. tostring(look:GetText()))
assert(look:GetStringWidth() <= look._w * 2, "two lines at most")
-- in a raid only with "überall"
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
NS.OnRollChanged()
assert(not look:IsShown(), "not in a raid by default")
assert(NS.Set("rolls.lookHint", "all"))
assert(look:IsShown(), "everywhere")
assert(NS.Set("rolls.lookHint", "off"))
assert(not look:IsShown(), "off")
NS.Reset("rolls.lookHint")
STUB.instance = { name = "Ruins of Lordaeron", type = "party", id = 9001 }
NS.StopRoll()

-- an epic: never (its look goes to the winner only); bind on equip: never
assert(NS.StartRoll(epic, 20))
assert(not look:IsShown(), "no hint for an epic")
assert(#asked == 2 and asked[2] == 303)
NS.StopRoll()
assert(NS.StartRoll(boe, 20))
assert(not look:IsShown(), "no hint for bind on equip")
NS.StopRoll()

-- nobody: the line says so
answers[303] = { up = {}, wish = {}, none = 3, asked = 3, missing = 0, without = {} }
STUB.worn[1] = gear(305, "Helm Super", "HEAD", 90)
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
assert(NS.StartRoll(epic, 20))
assert(has(F.upLine:GetText(), "Für niemanden ein Upgrade"), "nobody: " .. F.upLine:GetText())
NS.StopRoll()

-- not asked again within the same round; not asked when asking does not work
NS.NeedCanAsk = function() return false, "Fragen kann nur die Lootleitung.", "lead" end
local before = #asked
assert(NS.StartRoll(boe, 20))
assert(#asked == before, "no question without the right to ask")
NS.StopRoll()
NS.NeedCanAsk = function() return true end
assert(NS.Set("sync.askUpgrades", false))
assert(NS.StartRoll(helm, 20))
assert(#asked == before, "no question with asking switched off")
NS.Reset("sync.askUpgrades")
NS.StopRoll()

-- switched off: no column, no line
assert(NS.Set("bis.compare", false))
assert(NS.StartRoll(helm, 20))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Anna", 90, 1, 100))
assert(F.rows[1].up:GetText() == "" and not F.upLine:IsShown(), "switched off")
NS.Reset("bis.compare")
NS.StopRoll()
NS.WishersOf = realWishers

-- the settings
assert(NS.SettingItem("rolls.lookHint").default == "dungeon" and NS.SettingItem("rolls.lookHint").officer ~= false)
