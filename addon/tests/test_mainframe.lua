-- The main window: pages from the registry, built once, refreshed while shown, officer pages gated,
-- a broken page does not break the window.
local built, refreshed = 0, 0
NS.RegisterPanel{ key = "tp1", label = "Testseite", order = 5,
    create = function(p) built = built + 1; return CreateFrame("Frame", nil, p) end,
    refresh = function() refreshed = refreshed + 1 end }
NS.RegisterPanel{ key = "tpoff", label = "Offizier", order = 6, officer = true, create = function(p) return CreateFrame("Frame", nil, p) end }
NS.RegisterPanel{ key = "tpbad", label = "Kaputt", order = 7, create = function() error("kaputt") end }

NS.ShowPage("tp1")
assert(AmisiaFrame and AmisiaFrame:IsShown() and NS.CurrentPage() == "tp1")
assert(built == 1 and refreshed >= 1)
NS.ShowPage("tp1"); assert(built == 1, "built once")
local r = refreshed
NS.Refresh(); assert(refreshed == r + 1, "refreshed while shown")
AmisiaFrame:Hide(); NS.Refresh(); assert(refreshed == r + 1, "not while hidden")

-- officer page falls back for a raider
STUB.officer = false
NS.ShowPage("tpoff")
assert(NS.CurrentPage() ~= "tpoff", "raider view does not open officer pages")
STUB.officer = true
NS.ShowPage("tpoff"); assert(NS.CurrentPage() == "tpoff")

-- a page that fails to build shows an error page and the window lives on
NS.ShowPage("tpbad"); assert(NS.CurrentPage() == "tpbad" and AmisiaFrame:IsShown())
NS.ShowPage("tp1"); assert(NS.CurrentPage() == "tp1")

-- toggle, scale, position reset
NS.ToggleMain(); assert(not AmisiaFrame:IsShown())
NS.ToggleMain(); assert(AmisiaFrame:IsShown())
NS.Set("ui.scale", 80); assert(math.abs(AmisiaFrame:GetScale() - 0.8) < 1e-6)
NS.Reset("ui.scale")
AmisiaDB.settings.window = { point = "TOPLEFT", x = 10, y = -10 }
NS.ResetPositions(); assert(AmisiaDB.settings.window.point == nil)
SlashCmdList.AMISIA(""); assert(not AmisiaFrame:IsShown(), "/amisia alone toggles the window")
