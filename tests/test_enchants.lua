-- Enchant suggestions per slot (Gear/Enchants.lua, F-128): the enchantment of a link, what fits the
-- worn item (class, equip location, subclass), the order by what it brings the own spec, an item
-- above the own level at the end of the scored ones, unscored effects after them, nothing for an
-- empty slot or an item nothing fits; the goals window's section and the slot card's line.
local Gear = NS.Gear
local E = NS.Enchants
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-ench", I = {}, Z = {}, S = { { "D", "Stratholme", "Baron", nil, 329, 2017 } } }
Gear._reset()
local function gear(id, name, loc, stats, o)
    o = o or {}
    STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel = stats, 60
    NS.GEAR.I[id] = { loc, o.classID or 4, o.sub or 4, 60, 4, 1, 141, 0, 0, 0, 1 }
    return it.link
end
gear(403, "Brust Kern", "CHEST", { ITEM_MOD_STRENGTH_SHORT = 50 })
gear(404, "Ring Hort", "FINGER", { ITEM_MOD_STRENGTH_SHORT = 20 }, { sub = 0 })
gear(405, "Zweihand", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60 }, { classID = 2, sub = 1 })
STUB.items[405].stats.ITEM_MOD_STRENGTH_SHORT = 20

-- the enchantments: intellect (on the chest now), strength, stamina (an item), agility (an item for
-- level 65), a proc for weapons, strength for the wrist only, weapon damage for two-handers
NS.ENCHANT = { build = "test", built = "test", E = {
    [24] = "INTELLECT=2|0|0|Intellect +2", [41] = "STRENGTH=5|0|0|Strength +5", [42] = "STAMINA=3|0|0|Stamina +3",
    [50] = "AGILITY=7|0|0|Agility +7", [99] = "|1|0|Crusader", [60] = "STRENGTH=9|0|0|Strength +9",
    [70] = "WDMG=6|0|0|Scope (+6 Damage)",
}, S = {
    "r:100:24:333:1:4:CHEST,ROBE:", "r:101:41:333:150:4:CHEST,ROBE:", "i:5001:42:0:1:4:CHEST,ROBE:",
    "i:5002:50:0:65:4:CHEST:", "r:102:99:333:200:2::", "r:103:60:333:150:4:WRIST:", "r:104:70:333:200:2:2HWEAPON:1,8",
} }
assert(E.Available(), "the data is there")

---------------------------------------------------------------------------
-- the enchantment of a link
---------------------------------------------------------------------------
assert(E.OfLink("|cffa335ee|Hitem:403:24::::::::60:::::|h[Brust Kern]|h|r") == 24)
assert(E.OfLink(STUB.items[403].link) == nil, "no enchantment")
assert(E.OfLink("item:403:0:0") == nil)

---------------------------------------------------------------------------
-- the chest with intellect: strength first, stamina after, agility (level 65) last of the scored,
-- nothing for weapons or the wrist, not the one on it
---------------------------------------------------------------------------
STUB.worn[5] = "|cffa335ee|Hitem:403:24::::::::60:::::|h[Brust Kern]|h|r"
STUB.worn[11] = STUB.items[404].link
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local res = assert(E.ForSlot("CHEST"))
assert(res.current and res.current.id == 24 and res.current.name == "Intellect +2", "the one on it, by its English name")
local ids = {}
for _, r in ipairs(res.list) do ids[#ids + 1] = r.id end
assert(table.concat(ids, ",") == "41,42,50", "strength, stamina, then agility above the own level: " .. table.concat(ids, ","))
assert(res.list[1].scored and res.list[1].sources[1].kind == "r" and res.list[3].later == 65)
assert(res.better, "something brings more")
assert(has(E.Text(41), "+5 Stärke") and has(E.GainText(res.list[1]), "+"), E.Text(41))
assert(has(E.SourceText(res.list[3]), "ab Stufe 65") and has(E.SourceText(res.list[3]), "Gegenstand"))
assert(has(E.SourceText(res.list[1]), "150"), E.SourceText(res.list[1]))

-- nothing fits a ring; an empty slot has no section
assert(E.ForSlot("FINGER1") == nil, "nothing fits a ring")
assert(E.ForSlot("HEAD") == nil, "an empty slot")

-- the two-hander: weapon damage through its speed, the proc after it without a number
STUB.items[405].stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60
NS.GEAR.I[405][9] = 3.6
STUB.worn[16] = STUB.items[405].link
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local w = assert(E.ForSlot("MAINHAND"))
assert(#w.list == 2 and w.list[1].id == 70 and w.list[1].scored and w.list[2].id == 99 and not w.list[2].scored,
    "the scope's damage counts, the proc comes after it")
assert(E.GainText(w.list[2]) == "")

-- the best one on it already: nothing better
STUB.worn[5] = "|cffa335ee|Hitem:403:41::::::::60:::::|h[Brust Kern]|h|r"
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local best = assert(E.ForSlot("CHEST"))
for _, r in ipairs(best.list) do assert(r.id ~= 41) end
assert(best.list[1] == nil or best.list[1].id ~= 24, "intellect brings a warrior nothing")

---------------------------------------------------------------------------
-- the slot card's line and the goals window's section
---------------------------------------------------------------------------
STUB.worn[5] = "|cffa335ee|Hitem:403:24::::::::60:::::|h[Brust Kern]|h|r"
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local line = plain(E.CardLine("CHEST"))
assert(has(line, "Verzauberung: Intellect +2") and has(line, "besser:"), line)
assert(E.CardLine("FINGER1") == nil)
local card = NS.ShowSlotCard("CHEST")
assert(card and card.ench:IsShown() and has(plain(card.ench.text:GetText()), "besser:"), "the card's line")
card:Hide()

-- the planner's square beside the chest (D-80): the enchantment on it as its icon, the menu with
-- what brings more; nothing on it: "+"; a ring: no square
NS.ShowPlanner("suggest", nil, "CHEST")
local doll = NS.PageFrame("planner").doll
local q = doll.slots.CHEST.ench
assert(q:IsShown() and q.icon:IsShown() and not q.plus:IsShown() and q.data.current.id == 24, "the one on it")
q:Click()
local menu = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then menu[#menu + 1] = plain(b.label:GetText()) end end
AmisiaMenu:Hide()
assert(#menu == 3 and has(menu[1], "Strength +5"), table.concat(menu, "|"))
STUB.worn[5] = STUB.items[403].link
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
NS.Refresh()
assert(q:IsShown() and q.plus:IsShown() and not q.icon:IsShown(), "nothing on it: +")
assert(not doll.slots.FINGER1.ench:IsShown(), "no square for a ring")
