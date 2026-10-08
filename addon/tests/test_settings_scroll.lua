-- The settings page keeps the row the player changed in its place on screen when the change shows
-- or hides sections above it (the view: the officer sections come in above "Oberfläche").
-- Without the fix the scroll offset stays and the row lands elsewhere.
local function topOf(f) local p, _, _, _, y = f:GetPoint(1); assert(p == "TOPLEFT", p); return -y end

NS.Set("ui.view", "raider")
NS.ShowPage("settings")
NS.Refresh()
local page = NS.SettingsPageFrame()
local scroll, rows = page.scroll, NS.SettingsRows()
local view = rows["ui.view"]
assert(view and view:IsShown(), "the view row is there")
local before = topOf(view)
assert(before > 300, "the view row sits below the first screen: " .. before)
-- scrolled to the end, as in the game: the row sits low in the view
local child = page.child
scroll:SetVerticalScroll(child:GetHeight() - scroll:GetHeight())
local screen = before - scroll:GetVerticalScroll()
assert(screen > 0 and screen < scroll:GetHeight(), "the row is in view: " .. screen)

-- the player picks the officer view in that row: sections come in above it
-- the choice goes auto -> officer -> raider: set it to auto, a click picks officer
local choice = view.control
choice:SetValue("auto")
choice:GetScript("OnClick")(choice)
assert(NS.Get("ui.view") == "officer", tostring(NS.Get("ui.view")))
NS.Refresh()
STUB.tick(0.1)
local after = topOf(view)
assert(after > before, "officer sections came in above: " .. before .. " -> " .. after)
assert(math.abs((after - scroll:GetVerticalScroll()) - screen) < 0.5,
    "the row stays where it was on screen: " .. screen .. " -> " .. (after - scroll:GetVerticalScroll()))

-- a refresh that changes nothing keeps the scroll
local at = scroll:GetVerticalScroll()
NS.Refresh(); STUB.tick(0.1)
assert(scroll:GetVerticalScroll() == at, "nothing moves without a change")

-- back to the raider view: the row is still where it was on screen
choice:GetScript("OnClick")(choice)
assert(NS.Get("ui.view") == "raider", tostring(NS.Get("ui.view")))
NS.Refresh(); STUB.tick(0.1)
assert(math.abs((topOf(view) - scroll:GetVerticalScroll()) - screen) < 0.5, "and back")
NS.Set("ui.view", "auto")
