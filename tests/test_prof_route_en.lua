--[[locale enUS]]
-- The profession route (F-137) on an English client: the switch, the head, the steps, the trainer
-- and buy steps and the shopping list read in English (Locales/enUS_world.lua).
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/route_fixture.lua")
AmisiaDB.settings.professions = { mode = "route", routeVendor = true }
NS.ShowProfessions("tailoring")
local f = NS.PageFrame("professions")
assert(f.routeView:IsShown(), "the route view")
assert(f.modeRecipes.label:GetText() == "Recipes" and f.modeRoute.label:GetText() == "Route")
assert(f.vendorT.label:GetText() == "trainer only" and f.vendorV.label:GetText() == "vendors too")
assert(f.tabSteps.label:GetText() == "Steps" and f.tabShop.label:GetText() == "Shopping")
local head = f.routeHead:GetText()
assert(has(head, "Not learned, preview from rank 1 to 300 · about ") and has(head, " steps"), head)
local seen = {}
for _, r in ipairs(f.steps.rows) do
    if r:IsShown() and r.item then
        local l1 = r.line1:GetText()
        -- the recipe names are the (stubbed German) client's; the rest is English
        assert(not has(l1, " bis ") and not has(l1, "Lehrer"), "no German: " .. l1)
        if r.item.kind == "trainer" then seen.trainer = seen.trainer or l1 end
        if r.item.kind == "recipe" then seen.recipe, seen.line2 = l1, r.line2:GetText() end
    end
end
assert(has(seen.trainer, "At 1: visit the trainer, learn Apprentice (up to 75)"), seen.trainer)
assert(has(seen.recipe, "x ") and has(seen.recipe, " to "), seen.recipe)
assert(has(seen.line2, "about "), seen.line2)
f.tabShop:Click()
local cols = {}
for _, r in ipairs(f.shop.rows) do
    if r:IsShown() and r.item then cols[#cols + 1] = r.src:GetText() end
end
local all = table.concat(cols, ",")
assert(has(all, "Vendor") and has(all, "farm or auction house"), all)
