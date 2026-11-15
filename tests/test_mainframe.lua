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
-- the hub in the client's frame: 806 x 667 (its title bar, the head, the tabs and the footer, D-73,
-- D-84), the page area stays 602 x 478
assert(AmisiaFrame._w == 806 and AmisiaFrame._h == 667, "806 x 667")
local ML = dofile(ADDON_DIR .. "/../tests/layout.lua")(AmisiaFrame, 806, 667)
local cl, cr = ML.span(AmisiaFrame.content)
local ct, cb = ML.vspan(AmisiaFrame.content)
assert(cr - cl == 602 and ct - cb == 478, ("the page area 602 x 478: %d x %d"):format(cr - cl, ct - cb))
-- a test page without a group lands by its order: order 5 is "raid"
assert(NS.PanelGroup(NS.Panel("tp1")) == "raid")
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
-- F-208: the opacity slider, 30 to 100 %
assert(AmisiaFrame:GetAlpha() == 1, "opaque by default")
NS.Set("ui.alpha", 60); assert(math.abs(AmisiaFrame:GetAlpha() - 0.6) < 1e-6, "60 %")
NS.ApplyAlpha(10); assert(math.abs(AmisiaFrame:GetAlpha() - 0.3) < 1e-6, "not below 30 %")
NS.Reset("ui.alpha"); assert(AmisiaFrame:GetAlpha() == 1, "back to opaque")
-- F-208: a window opened while the main window is shown stands over it; back to its own strata after
local low = NS.W.Window("AmisiaTestLow", 200, 100, { strata = "MEDIUM" })
local top = NS.W.Window("AmisiaTestTop", 200, 100, { strata = "FULLSCREEN_DIALOG" })
assert(AmisiaFrame:IsShown() and AmisiaFrame:GetFrameStrata() == "FULLSCREEN")
low:Show()
assert(low:GetFrameStrata() == "FULLSCREEN" and (low.raised or 0) >= 1, "lifted over the main window")
top:Show()
assert(top:GetFrameStrata() == "FULLSCREEN_DIALOG", "a window above stays above")
AmisiaFrame:Hide()
assert(low:GetFrameStrata() == "MEDIUM", "its own strata back with the main window gone")
low:Hide()
low:Show()
assert(low:GetFrameStrata() == "MEDIUM", "without the main window: its own strata")
-- a protected window (a secure button on it): not lifted in combat; lifted before, it goes back after the fight
local prot = NS.W.Window("AmisiaTestProt", 200, 100, { strata = "MEDIUM" })
STUB.protectFrame(prot)
local nblocked = #STUB.blocked
AmisiaFrame:Show()
prot:Show()
assert(prot:GetFrameStrata() == "FULLSCREEN", "lifted out of combat")
STUB.combat = true
AmisiaFrame:Hide()
assert(#STUB.blocked == nblocked and prot:GetFrameStrata() == "FULLSCREEN", "kept in combat, nothing blocked")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
assert(prot:GetFrameStrata() == "MEDIUM", "back after the fight")
low:Hide(); top:Hide()
AmisiaFrame:Show()
AmisiaDB.settings.window = { point = "TOPLEFT", x = 10, y = -10 }
NS.ResetPositions(); assert(AmisiaDB.settings.window.point == nil)
SlashCmdList.AMISIA(""); assert(not AmisiaFrame:IsShown(), "/amisia alone toggles the window")
