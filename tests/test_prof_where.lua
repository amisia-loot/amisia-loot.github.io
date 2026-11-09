-- Where a reagent comes from (F-160) and the own characters' counts (F-159) on the route fixture:
-- R.ReagentSources (vendors with price and place, the recipes that make it, the gathering zones of
-- PROFESSIONS.RS, mobs, world drop, nothing known), R.Craftable (bags, with the bank), R.TwinksBy;
-- and the page: the reagent row's menu "Woher?" with its lines (waypoint, world map, recipe), the
-- head "herstellbar", "(n)" behind a known recipe, the alts in orange and in the tooltip.
local R, Pr = NS.ProfRoute, NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/route_fixture.lua")
STUB.maps[1426] = { name = "Dun Morogh", parent = 1415, mapType = 3 }
NS.PROFESSIONS.RS = { [2770] = "H186@1426.1429", [2589] = "D80300,Z1453,W", [2447] = "H182" }
NS.Prof._reset()
R._reset()
STUB.item(2589, "Leinenstoff", 1)
STUB.item(2320, "Grobes Garn", 1)
STUB.item(2996, "Leinenstoffballen", 1)
STUB.item(2770, "Kupfererz", 1)
local function kinds(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.kind end
    return table.concat(out, ",")
end

-- a vendor material: its vendors with place and price, a waypoint each
local thread = R.ReagentSources(2320)
assert(kinds(thread) == "vendor,vendor", kinds(thread))
for _, e in ipairs(thread) do
    assert(e.point and has(e.text, "Händler: ") and has(e.text, "10c"), e.text)
end
-- the bolt: the recipe that makes it, which opens
local bolt = R.ReagentSources(2996)
assert(kinds(bolt) == "craft" and bolt[1].recipe.spell == 2963 and has(bolt[1].text, "Leinenstoffballen (Schneiderei)"), bolt[1].text)
-- ore: the gathering zones (each opens the world map), and the smelting does not make it
local ore = R.ReagentSources(2770)
assert(kinds(ore) == "gather,gather" and ore[1].map == 1426 and ore[2].map == 1429, kinds(ore))
assert(ore[1].text == "Sammeln (Bergbau): Dun Morogh", ore[1].text)
-- a herb without zones: one line without action
local herb = R.ReagentSources(2447)
assert(kinds(herb) == "gather" and not herb[1].map and not herb[1].point and herb[1].text == "Sammeln: Kräuterkunde", herb[1].text)
-- linen: the mob with its place, the zone drop, the world drop
local linen = R.ReagentSources(2589)
assert(kinds(linen) == "drop,zone,world", kinds(linen))
assert(linen[1].point and linen[1].point.map == 1429 and has(linen[1].text, "Drop: Skyforged Golem, Wald von Elwynn 70, 70"), linen[1].text)
assert(linen[2].map == 1453 and linen[2].text == "Zonendrop: Sturmwind", linen[2].text)
-- nothing known: one line, no action
local none = R.ReagentSources(99999)
assert(#none == 1 and none[1].kind == "none" and not none[1].point and not none[1].map)
-- the source word of the lists
assert(R.Source(2770, 197) == "gather" and select(2, R.Source(2770, 197)) == 186, "ore: gathered by mining")
assert(R.Source(2589, 197) == "drop", "linen: a drop")

-- how often it can be crafted: from the bags, with the bank
STUB.bags[0] = { 2589, 2589, 2589 }
STUB.bank[2589] = 4
local now, bank = R.Craftable(2963)
assert(now == 1 and bank == 3, ("bolt: 3 linen in the bags, 7 with the bank: %s, %s"):format(tostring(now), tostring(bank)))
assert(R.Craftable(3917) == 0, "no thread, no dye")
assert(R.Craftable(424242) == nil, "reagents unknown")

-- the alts of the same realm and faction, most first
local me = NS.UnitFullName("player")
GetRealmName = function() return "Forever" end
R.SaveBags()
AmisiaDB.prof.bags["Twink Eins"] = { day = 1, realm = "Forever", faction = "A", items = { [2589] = 5 }, bank = { [2589] = 2 } }
AmisiaDB.prof.bags["Twink Zwei"] = { day = 1, realm = "Forever", faction = "A", items = { [2589] = 9 } }
AmisiaDB.prof.bags["Horde Alt"] = { day = 1, realm = "Forever", faction = "H", items = { [2589] = 50 } }
local by, sum = R.TwinksBy(2589)
assert(sum == 14 and #by == 2 and by[1].name == "Twink Zwei" and by[2].bank == 2, "the two of the own faction")
assert(R.Twinks(2589) == 14)
AmisiaDB.prof.bags[me] = nil

-- the page: the recipe detail of the bolt, known
AmisiaDB.prof.chars = AmisiaDB.prof.chars or {}
AmisiaDB.prof.chars[me] = { [197] = { rank = 50, max = 75, known = { [2963] = true } } }
NS.ShowRecipe(197, 2963)
local f = NS.PageFrame("professions")
local rd = f.rd
assert(has(rd.reag.head:GetText(), "herstellbar: 1") and has(rd.reag.head:GetText(), "(3 mit Bank)"), rd.reag.head:GetText())
local row = rd.reag.rows[1]
assert(row:IsShown() and row.item == 2589, "the linen row")
-- 7 own and 14 on alts for 2: green (enough without them)
assert(has(row.have:GetText(), "7 / 2"), row.have:GetText())
-- the tooltip names the alts
local tip, realAdd, realDouble = {}, GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(_, t) tip[#tip + 1] = t end
GameTooltip.AddDoubleLine = function(_, a, b) tip[#tip + 1] = a .. "=" .. b end
row:GetScript("OnEnter")(row)
GameTooltip.AddLine, GameTooltip.AddDoubleLine = realAdd, realDouble
local tipText = table.concat(tip, "\n")
assert(has(tipText, "Bei deinen Twinks:") and has(tipText, "Twink Zwei=9") and has(tipText, "Twink Eins=5 (Bank 2)")
    and has(tipText, "Klick: woher"), tipText)
-- the click: the menu with its head, the mob's line sets the waypoint
row:Click()
local menu = _G.AmisiaMenu
assert(menu:IsShown() and has(menu.buttons[1].label:GetText(), "Woher kommt Leinenstoff?"), menu.buttons[1].label:GetText())
assert(menu.buttons[1]:GetScript("OnClick") == nil, "the head does nothing")
assert(has(menu.buttons[2].label:GetText(), "Drop: Skyforged Golem"), menu.buttons[2].label:GetText())
menu.buttons[2]:Click()
local target = NS.MapTarget()
assert(target and target.map == 1429 and math.abs(target.x - 0.7) < 1e-6 and not menu:IsShown(), "the mob's waypoint")
-- the world drop: a grey line without click
local world = menu.buttons[4]
row:Click()
assert(has(world.label:GetText(), "Weltdrop") and world:GetScript("OnClick") == nil and has(world.label:GetText(), "|cff"),
    world.label:GetText())
menu:Hide()

-- the recipe list: "(1)" behind the known bolt
local boltRow
for _, r in ipairs(f.list.rows) do
    if r:IsShown() and r.item and r.item.recipe and r.item.recipe.spell == 2963 then boltRow = r end
end
assert(boltRow and has(boltRow.name:GetText(), "(1)") and not has(boltRow.name:GetText(), "bekannt"), boltRow and boltRow.name:GetText())

-- the shirt needs a bolt and thread: not enough own, enough with the alts is orange
STUB.bags[0] = {}
STUB.bank[2589] = nil
AmisiaDB.prof.bags[me] = nil
NS.ShowRecipe(197, 3919)   -- wool vest: 3 linen
local vest = rd.reag.rows[1]
assert(vest.item == 2589 and has(vest.have:GetText(), "0+14 / 3") and has(vest.have:GetText(), "|cffe0a344"), vest.have:GetText())
assert(not has(rd.reag.head:GetText(), "herstellbar"), "not known: no count")
