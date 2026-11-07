-- The view "Ohne Ort" of the map page (Pages/Map.lua npDetail): a crafted item's line drawn in combat
-- leaves out the guild's crafters and is not kept, so the next fill out of combat names them.
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/map_steps_fixture.lua")
assert(NS.WishAdd(803))
NS.ShowMap("alle")
local f = NS.PageFrame("map")
local realFor = NS.Crafters.ForItem
NS.Crafters.ForItem = function(id) return id == 2853 and { { name = "Anna", rank = 75 } } or {} end
local function whyOf(id)
    for i, n in ipairs(f.npList.items) do if n.id == id then return f.npList.rows[i].why:GetText() end end
end

STUB.combat = true
f.noPlace:Click()
local fight = whyOf(2853)
assert(f.view == "noplace" and fight == "Beruf: Schmiedekunst - Kupferarmschienen", "in combat without the crafters: " .. tostring(fight))
STUB.combat = false
NS.Refresh()
local calm = whyOf(2853)
assert(calm == "Beruf: Schmiedekunst - Kupferarmschienen · kann herstellen: Anna (75)", "out of combat with them: " .. tostring(calm))
NS.Crafters.ForItem = realFor
assert(has(whyOf(803), "Auktionshaus"), "the other reasons as before")
