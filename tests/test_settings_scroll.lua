-- The settings page keeps the row the player changed in its place on screen when the change shows
-- or hides sections above it (the view: the officer sections come in above "Oberfläche").
-- Without the fix the scroll offset stays and the row lands elsewhere.
local function topOf(f) local p, _, _, _, y = f:GetPoint(1); assert(p == "TOPLEFT", p); return -y end

-- The tabs go A to Z, "Allgemein" first: no real officer section stands above the view row, so the
-- test puts one there.
NS.RegisterSettings{ key = "aaatest", label = "Testabschnitt", order = 1, group = "amisia", officer = true, items = {
    { key = "aaatest.a", type = "toggle", label = "Test eins", default = false },
    { key = "aaatest.b", type = "toggle", label = "Test zwei", default = false },
    { key = "aaatest.c", type = "toggle", label = "Test drei", default = false },
    { key = "aaatest.d", type = "toggle", label = "Test vier", default = false },
} }
NS.Set("ui.view", "raider")
-- a search that finds rows of nearly every section, so that sections come and go above the row (D-49:
-- without a search the page shows one section)
NS.ShowSettings("e")
NS.Refresh()
local page = NS.PageFrame("settings")
local scroll, rows = page.scroll, NS.SettingsRows()
local view = rows["ui.view"]
assert(view and view:IsShown(), "the view row is there")
local before = topOf(view)
assert(before > 300, "the view row sits below the first screen: " .. before)
-- scrolled down, as in the game: the row sits low in the view
local child = page.child
scroll:SetVerticalScroll(before - scroll:GetHeight() + 60)
local screen = before - scroll:GetVerticalScroll()
assert(screen > 0 and screen < scroll:GetHeight(), "the row is in view: " .. screen)

-- the player picks the officer view in that row: sections come in above it
-- the choice goes auto -> officer -> raider: set it to auto, the next value is officer
local choice = view.control
choice:SetValue("auto")
choice:Cycle()
assert(NS.Get("ui.view") == "officer", tostring(NS.Get("ui.view")))
NS.Refresh()
STUB.tick(0.1)
local after = topOf(view)
assert(after > before, "officer sections came in above: " .. before .. " -> " .. after)
assert(math.abs((after - scroll:GetVerticalScroll()) - screen) < 0.5,
    "the row stays where it was on screen: " .. screen .. " -> " .. (after - scroll:GetVerticalScroll()))

-- the client's scroll bar keeps the old share of the range when the range grows: the hook on the
-- range change puts the row back (it ran last in the game, where sections came in)
local kept = scroll:GetVerticalScroll()
choice:Cycle()   -- raider: sections go
NS.Refresh()
choice:Cycle()   -- auto (no officer here): no change
NS.Refresh()
NS.Set("ui.view", "officer")          -- the click on "Automatisch" goes to officer: sections come
NS.Refresh()
local want = scroll:GetVerticalScroll()
scroll:SetVerticalScroll(want * 0.6)  -- what the bar's share would make of it
local hooked = scroll:GetScript("OnScrollRangeChanged")
assert(hooked, "the page hooks the range change")
hooked(scroll)
assert(math.abs(scroll:GetVerticalScroll() - want) < 0.5, "back in place after the range change: " .. scroll:GetVerticalScroll() .. " / " .. want)
STUB.tick(1)
scroll:SetVerticalScroll(want - 50)   -- the player scrolls later: the hook leaves it alone
hooked(scroll)
assert(scroll:GetVerticalScroll() == want - 50, "no pull back after the moment")
assert(kept > 0)

-- a refresh that changes nothing keeps the scroll
local at = scroll:GetVerticalScroll()
NS.Refresh(); STUB.tick(0.1)
assert(scroll:GetVerticalScroll() == at, "nothing moves without a change")

-- back to the raider view: the row is still where it was on screen
screen = topOf(view) - scroll:GetVerticalScroll()
choice:Cycle()
assert(NS.Get("ui.view") == "raider", tostring(NS.Get("ui.view")))
NS.Refresh(); STUB.tick(0.1)
assert(math.abs((topOf(view) - scroll:GetVerticalScroll()) - screen) < 0.5, "and back")
NS.Set("ui.view", "auto")
