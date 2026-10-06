-- The comparison with the worn gear (Bis.lua ns.UpgradeOf, Compare.lua): one scoring for every
-- place an item is offered. Percent of the worn score, an empty slot, the weaker ring, a two-hander
-- against weapon plus off hand, the weapon switch, the level requirement, class limits; the tooltip
-- lines (percent and "statt"), the marks on the group loot roll frames and on quest rewards (quest
-- giver and quest log, loading stats tried again), the switch bis.compare, errors never break.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.class, STUB.level = "WARRIOR", 60

local LINKS = {}
local function gear(id, name, loc, stats, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, o.q or 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel, it.bind = stats, o.minLevel or 60, o.bind or 1
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
NS.GEAR = { game = "forever", cap = 60, built = "test-compare", I = {}, Z = {}, S = {} }
Gear._reset()
gear(301, "Helm A", "HEAD", str(40))
gear(302, "Helm B", "HEAD", str(30))
gear(303, "Helm Später", "HEAD", str(80), { minLevel = 62 })
gear(320, "Ring Stark", "FINGER", str(20))
gear(321, "Ring Schwach", "FINGER", str(10))
gear(322, "Ring Neu", "FINGER", str(15))
gear(330, "Brust Neu", "CHEST", str(25))
gear(310, "Zweihand", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60 }, { classID = 2, sub = 1 })
gear(311, "Axt", "WEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 }, { classID = 2, sub = 0 })
gear(312, "Schild", "SHIELD", str(5), { sub = 6 })
gear(313, "Neue Zweihand", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 80 }, { classID = 2, sub = 1 })
gear(306, "Zauberstab", "RANGEDRIGHT", { ITEM_MOD_INTELLECT_SHORT = 10 }, { classID = 2, sub = 19 })
STUB.items[307] = { name = "Erz", quality = 1, link = STUB.link(307, "Erz", 1), equipLoc = "", classID = 7 }
LINKS[307] = STUB.items[307].link

local function wear(slots)
    for k in pairs(STUB.worn) do STUB.worn[k] = nil end
    for slot, id in pairs(slots) do STUB.worn[slot] = LINKS[id] end
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
end
wear({ [1] = 302, [11] = 320, [12] = 321, [16] = 311, [17] = 312 })

---------------------------------------------------------------------------
-- ns.UpgradeOf
---------------------------------------------------------------------------
local u = assert(NS.UpgradeOf(LINKS[301]), "helm A")
assert(u.slotKey == "HEAD" and u.gain > 0 and u.mine > 0 and u.up == true, "helm A beats helm B")
assert(u.pct == math.floor(u.gain / u.mine * 100 + 0.5), "percent of the worn score: " .. tostring(u.pct))
assert(#u.against == 1 and u.against[1] == LINKS[302] and not u.weaker, "against the worn helm")
-- one scoring: the same gain as ns.BisGain
local g, slot, mine = NS.BisGain(LINKS[301])
assert(g == u.gain and slot == u.slotKey and mine == u.mine, "the same scoring as BisGain")

-- an empty slot: no percent
u = assert(NS.UpgradeOf(LINKS[330]))
assert(u.pct == nil and u.mine == 0 and u.up == true and #u.against == 0, "an empty slot")

-- rings: against the weaker one
u = assert(NS.UpgradeOf(LINKS[322]))
assert(u.weaker == true and #u.against == 1 and u.against[1] == LINKS[321], "the weaker ring: " .. tostring(u.against[1]))
assert(u.gain > 0 and u.up, "beats the weaker ring")

-- a two-hander against weapon plus off hand
u = assert(NS.UpgradeOf(LINKS[313]))
assert(#u.against == 2 and u.against[1] == LINKS[311] and u.against[2] == LINKS[312], "against both hands")

-- a one-hander against a worn two-hander: the weapon switch
wear({ [1] = 302, [11] = 320, [12] = 321, [16] = 310 })
local none, why, code = NS.UpgradeOf(LINKS[311])
assert(none == nil and code == "switch", "weapon switch: " .. tostring(code))

-- the level requirement: scored, but later
u = assert(NS.UpgradeOf(LINKS[303]))
assert(u.later == 62 and u.up == false and u.gain > 0, "level 62 needed: " .. tostring(u.later))
STUB.level = 62
NS.Fire("BIS_CHANGED")
u = assert(NS.UpgradeOf(LINKS[303]))
assert(u.later == nil and u.up == true, "at level 62 it counts")
STUB.level = 60
NS.Fire("BIS_CHANGED")

-- no gear, a class that cannot wear it
none, why, code = NS.UpgradeOf(LINKS[307])
assert(none == nil and code == "notgear", tostring(code))
none, why, code = NS.UpgradeOf(LINKS[306])
assert(none == nil and code == "class", tostring(code))

-- the short texts the marks show
assert(NS.UpgradeShort({ up = true, pct = 12, gain = 5 }) == "+12%")
assert(NS.UpgradeShort({ up = true, gain = 5, mine = 0 }) == "neu")
assert(NS.UpgradeShort({ up = false, later = 62, gain = 5, pct = 20 }) == "ab 62")
assert(NS.UpgradeShort({ up = false, pct = -8, gain = -3 }) == "-8%")

---------------------------------------------------------------------------
-- the tooltip: percent and what it is compared with
---------------------------------------------------------------------------
local tip = CreateFrame("GameTooltip", "TestTooltip")
local lines = {}
tip.AddLine = function(_, t, r, g2, b) lines[#lines + 1] = { t = t, r = r, g = g2, b = b } end
local function show(link)
    wipe(lines)
    if tip.scripts.OnTooltipCleared then tip.scripts.OnTooltipCleared(tip) end
    tip.shownLink = link
    for _, h in ipairs(STUB.tdp) do h.fn(tip) end
    return lines
end
local function texts()
    local out = {}
    for i, l in ipairs(lines) do out[i] = l.t end
    return table.concat(out, " / ")
end
wear({ [1] = 302, [11] = 320, [12] = 321 })
u = NS.UpgradeOf(LINKS[301])
show(LINKS[301])
assert(lines[1] and lines[1].t == ("Upgrade für dich: +%d %% (+%d, Kopf)"):format(u.pct, math.floor(u.gain + 0.5)), "percent first: " .. texts())
assert(lines[2] and lines[2].t == "statt Helm B" and lines[2].g < 0.7, "the worn helm, grey: " .. texts())
show(LINKS[322])
assert(lines[2] and lines[2].t == "statt Ring Schwach (schwächerer Ring)", "the weaker ring: " .. texts())
show(LINKS[330])
assert(lines[1] and has(lines[1].t, "(Brust, Platz leer)") and #lines == 1, "an empty slot: " .. texts())
show(LINKS[303])
assert(lines[1] and has(lines[1].t, "Upgrade für dich ab Stufe 62: +") and lines[1].r > 0.9 and lines[1].g < 0.8,
    "later, orange: " .. texts())
-- switched off: the line as before, no "statt"
assert(NS.Set("bis.compare", false))
show(LINKS[301])
assert(#lines == 1 and lines[1].t == ("Upgrade für dich: +%d (Kopf)"):format(math.floor(u.gain + 0.5)), "as before: " .. texts())
NS.Reset("bis.compare")

---------------------------------------------------------------------------
-- group loot roll frames
---------------------------------------------------------------------------
local frame = GroupLootFrame2
STUB.rolls[51], STUB.rolls[52], STUB.rolls[53] = LINKS[301], LINKS[307], LINKS[303]
frame.rollID = 51; frame:Show()
assert(NS.UpgradeMarkText(frame) == ("+%d%%"):format(u.pct), "the percent on the roll frame: " .. tostring(NS.UpgradeMarkText(frame)))
frame:Hide(); frame.rollID = 52; frame:Show()
assert(NS.UpgradeMarkText(frame) == nil, "no gear, no mark")
frame:Hide(); frame.rollID = 53; frame:Show()
assert(NS.UpgradeMarkText(frame) == "ab 62", "later")
assert(NS.Set("bis.compare", false))
frame:Hide(); frame.rollID = 51; frame:Show()
assert(NS.UpgradeMarkText(frame) == nil, "switched off")
NS.Reset("bis.compare")
-- stats still loading: tried again
local slow = STUB.link(399, "Langsam", 3)
STUB.rolls[54] = slow
frame:Hide(); frame.rollID = 54; frame:Show()
assert(NS.UpgradeMarkText(frame) == nil, "nothing while loading")
gear(399, "Langsam", "HEAD", str(50), { q = 3 })
STUB.tick(0.6)
assert(NS.UpgradeMarkText(frame) == "+67%", "marked once the stats are there: " .. tostring(NS.UpgradeMarkText(frame)))
-- an error never reaches the client's frame
local errors = {}
local realHandler, realOf = geterrorhandler, NS.UpgradeOf
_G.geterrorhandler = function() return function(e) errors[#errors + 1] = tostring(e) end end
NS.UpgradeOf = function() error("kaputt") end
frame:Hide(); frame.rollID = 51; frame:Show()
assert(#errors == 1 and has(errors[1], "kaputt"), "to the error handler")
NS.UpgradeOf, _G.geterrorhandler = realOf, realHandler
frame:Hide()

---------------------------------------------------------------------------
-- quest rewards: the quest giver and the quest log
---------------------------------------------------------------------------
STUB.questItems.choice = { LINKS[301], LINKS[322] }
STUB.questItems.reward = { LINKS[307] }
local b1 = STUB.questButton(1, "choice", 1)
local b2 = STUB.questButton(2, "choice", 2)
local b3 = STUB.questButton(3, "reward", 1)
local b4 = STUB.questButton(4, "reward", 1, "currency")
QuestInfo_Display(QUEST_TEMPLATE_DETAIL)
assert(NS.UpgradeMarkText(b1) == ("+%d%%"):format(u.pct), "choice 1: " .. tostring(NS.UpgradeMarkText(b1)))
local ring = NS.UpgradeOf(LINKS[322])
assert(NS.UpgradeMarkText(b2) == ("+%d%%"):format(ring.pct), "choice 2 against the weaker ring")
assert(NS.UpgradeMarkText(b3) == nil and NS.UpgradeMarkText(b4) == nil, "no gear, a currency: no mark")
-- the quest log reads its own links; a reused button loses its old mark
STUB.questLogItems.choice = { LINKS[307], LINKS[330] }
QuestInfo_Display(QUEST_TEMPLATE_LOG)
assert(NS.UpgradeMarkText(b1) == nil and NS.UpgradeMarkText(b2) == "neu", "the quest log: " .. tostring(NS.UpgradeMarkText(b2)))
-- a hidden button keeps no mark
b2:Hide()
QuestInfo_Display(QUEST_TEMPLATE_LOG)
assert(NS.UpgradeMarkText(b2) == nil, "hidden button")
assert(NS.Set("bis.compare", false))
b2:Show()
QuestInfo_Display(QUEST_TEMPLATE_LOG)
assert(NS.UpgradeMarkText(b2) == nil, "switched off")
NS.Reset("bis.compare")

-- the settings
assert(NS.SettingItem("bis.compare").default == true)

-- the toast of an upgrade carries the percent too
wear({ [1] = 302, [11] = 320, [12] = 321 })
NS.BisToast(301, "upgrade", LINKS[301], "Test")
local toast = NS.BisToastState().frame
assert(toast and has(toast.item:GetText(), ("+%d %% (+%d, Kopf)"):format(u.pct, math.floor(u.gain + 0.5))), tostring(toast and toast.item:GetText()))
