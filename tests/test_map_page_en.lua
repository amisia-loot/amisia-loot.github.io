--[[locale enUS]]
-- The map page on an English client: "All zones", the chip "Quests", the quest step row and its text,
-- the target card, the step's menu, the link to the items without a place, that view's reasons and
-- its way back, the hint and the footer, all from Locales/enUS_world.lua.
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/map_steps_fixture.lua")
assert(NS.WishAdd(803))

NS.ShowMap("all")
local f = NS.MapPageFrame()
assert(f.zone.label:GetText():find("^All zones %(%d+%)$"), f.zone.label:GetText())
assert(f.quests.label:GetText() == "Quests" and f.targets.label:GetText() == "Goals" and f.wishes.label:GetText() == "Wishes")
assert(f.head.go:GetText() == "Map" and f.list.rows[2].go:GetText() == "Map", f.head.go:GetText())
local step
for i, e in ipairs(f.list.items) do if e.key == "Q:501" then step = f.list.rows[i] end end
assert(step and step.kind:GetText() == "Quest step" and step.src:GetText() == "Root (for Final Quest, Second Final)",
    step and step.src:GetText())
step.scripts.OnClick(step, "LeftButton")
assert(has(f.target:GetText(), "Target: ") and has(f.target:GetText(), "Root Giver"), f.target:GetText())
assert(f.clear:GetText() == "Clear target", f.clear:GetText())
step.scripts.OnClick(step, "RightButton")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(table.concat(labels, ",") == "Set target,Show the quest path,Hide this place,Hide quest steps", table.concat(labels, ","))
AmisiaMenu:Hide()
NS.MapClearTarget()
assert(f.hint:GetText() == "Click a row: set target. Map or shift-click: show on the world map.", f.hint:GetText())
assert(has(f.data:GetText(), "places from public quest data, some names in English."), f.data:GetText())
-- the items without a place
local link = f.noPlace.label:GetText()
assert(has(link, "3 Items without a place ("), link)
f.noPlace:Click()
assert(f.back:GetText() == "Back to the map" and f.npHead.why:GetText() == "Reason", f.back:GetText())
local why = {}
for i, n in ipairs(f.npList.items) do why[n.id] = f.npList.rows[i].why:GetText() end
assert(why[2853] and why[2853]:find("^Profession: .+ %- "), tostring(why[2853]))
assert(why[804] and why[804]:find("^no place data: "), tostring(why[804]))
assert(f.hint:GetText() == "Click an item: open its recipe or the gear page.", f.hint:GetText())
f.back:Click()
assert(f.list:IsShown() and f.open:GetText() == "Open world map", f.open:GetText())
