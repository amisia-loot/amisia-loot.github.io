-- Progress and filters of the window "Ausrüstungsziele" (F-113): ns.BisProgress (worn, in bag or
-- bank, still to get, no target; a worn item the target does not beat counts as got; the shield
-- hand beside a worn two-hander), "N/17 Ziele hast du", the bar of 17 parts, the section heads
-- "Rüstung 2 von 9 hast du", the filters Alle / Zu holen / In der Tasche / Ohne Verzauberung (the
-- raid check's test: link, else the tooltip line type 15) with their counts; the filter is kept.
local Gear = NS.Gear
local G = NS.Theme.GOALS
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-goals-progress", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
} }
STUB.areas[2717] = "Geschmolzener Kern"
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, stats, sources, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel = stats, 60
    if sources then
        NS.GEAR.I[id] = { loc, o.classID or 4, o.sub or 4, 60, 4, 1, 141, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
gear(501, "Helm Ziel", "HEAD", str(40), { 1 })
gear(502, "Brust Ziel", "CHEST", str(50), { 1 })
gear(503, "Stiefel Ziel", "FEET", str(30), { 1 })
gear(504, "Zweihand Ziel", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60, ITEM_MOD_STRENGTH_SHORT = 20 }, { 1 }, { classID = 2, sub = 1 })
gear(505, "Handschuhe Ziel", "HAND", str(10), { 1 })
gear(510, "Alte Handschuhe", "HAND", str(60))
-- worn: the head's target (enchanted in the link), old hands better than their target (not
-- enchanted), the two-hander (not enchanted); the chest's target in the bags
STUB.worn[1] = "|cffa335ee|Hitem:501:2545::::::::60:::::|h[Helm Ziel]|h|r"
STUB.worn[10] = LINKS[510]
STUB.worn[16] = LINKS[504]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.bags[0] = { 502 }
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)

local res = NS.BisTargets()
local p = NS.BisProgress(res)
assert(p.total == 17, "17 rows")
assert(p.slot.HEAD == "done", "the head's target is worn")
assert(p.slot.CHEST == "bag", "the chest's target is in the bags")
assert(p.slot.FEET == "todo", "the feet's target is still to get")
assert(p.slot.HANDS == "done", "the worn hands beat their target: got")
assert(res.plan == "2H" and p.slot.MAINHAND == "done" and p.slot.OFFHAND == "done", "the shield hand beside the worn two-hander")
assert(p.slot.NECK == "none", "no target for the neck")
assert(p.done == 4 and p.bag == 1 and p.todo == 1 and p.none == 11, ("%d %d %d %d"):format(p.done, p.bag, p.todo, p.none))
assert(NS.BisProgress(res) == p, "kept with the result")

---------------------------------------------------------------------------
-- the window: the line, the bar, the heads, the filters
---------------------------------------------------------------------------
Enum.TooltipDataLineType = Enum.TooltipDataLineType or {}
Enum.TooltipDataLineType.ItemEnchantmentPermanent = 15
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetInventoryItem = function(_, slot)
    local lines = { { type = 22, leftText = "item" } }
    if slot == 16 then lines[#lines + 1] = { type = 15, leftText = "Verzaubert: +15 Stärke" } end
    return { lines = lines }
end
local win = assert(NS.ShowGoalsFrame())
local P = win.progress
assert(P.text:GetText() == "4/17 Ziele hast du", P.text:GetText())
assert(#P.parts == 17, "17 parts")
local function color(t) return t.color and table.concat({ t.color[1], t.color[2], t.color[3] }, ",") end
local function want(st) local c = G.STATE_COLOR[st] return table.concat({ c[1], c[2], c[3] }, ",") end
assert(color(P.parts[1]) == want("done") and color(P.parts[5]) == want("bag") and color(P.parts[10]) == want("todo")
    and color(P.parts[2]) == want("none"), "green, yellow, grey, dark")
-- the heads count every slot of the section
local rows = win.list.items
assert(rows[1].header and has(plain(rows[1].count), "2 von 9 hast du"), "head and hands got: " .. plain(rows[1].count))
-- the dots on the doll: green worn, yellow in the bags, none to get
local d = win.doll
assert(d.slots.HEAD.dot:IsShown() and d.slots.HEAD.dot.vertexColor and d.slots.HEAD.dot.vertexColor[1] == G.STATE_COLOR.done[1], "green dot")
assert(d.slots.CHEST.dot.vertexColor and d.slots.CHEST.dot.vertexColor[1] == G.STATE_COLOR.bag[1] and d.slots.CHEST.dot:IsShown(), "yellow dot")
assert(not d.slots.FEET.dot:IsShown(), "no dot: still to get")
-- the chips with their counts
local chips = P.chips
assert(chips.all.on and chips.all.label:GetText() == "Alle", "Alle first")
assert(chips.todo.label:GetText() == "Zu holen 1" and chips.bag.label:GetText() == "In der Tasche 1", chips.todo.label:GetText())
-- unenchanted: of the raid check's slots the hands (the link and the tooltip say nothing); the
-- two-hander by its tooltip line; the head by its link
assert(chips.ench.label:GetText() == "Ohne Verzauberung 1", chips.ench.label:GetText())
local function keys()
    local out = {}
    for _, e in ipairs(win.list.items) do if not e.header then out[#out + 1] = e.key end end
    return table.concat(out, ",")
end
chips.todo:Click()
assert(keys() == "FEET", "Zu holen: " .. keys())
assert(NS.GoalsFrameState().filter == "todo", "kept")
assert(win.list.items[1].header.key == "armor" and #win.list.items == 2, "an empty section is left out")
chips.bag:Click()
assert(keys() == "CHEST", "In der Tasche: " .. keys())
chips.ench:Click()
assert(keys() == "HANDS", "Ohne Verzauberung: " .. keys())
-- the doll shows every slot whatever the filter
local n = 0
for _, b in pairs(d.slots) do if b.item or b.art then n = n + 1 end end
assert(n == 17, "the doll shows them all")
chips.all:Click()
assert(select(2, keys():gsub(",", ",")) == 16, "all 17 again")
-- the window state survives the settings check
AmisiaDB.settings.goalWindow.filter, AmisiaDB.settings.goalWindow.mode = "bag", "worn"
NS.ApplySettings(AmisiaDB)
assert(AmisiaDB.settings.goalWindow.filter == "bag" and AmisiaDB.settings.goalWindow.mode == "worn", "kept through a load")
AmisiaDB.settings.goalWindow.filter = "nonsense"
NS.GoalsRefresh()
assert(chips.all.on, "an unknown filter shows all")
