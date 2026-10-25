-- The client switch (D-57): ns.GAME from WOW_PROJECT_ID (WOW_PROJECT_CAMELOT first), else from the
-- build's interface number; ns.FOREVER; ns.Visible hides "forever = true" off Forever; the reset button
-- of a setting stands right beside its control on Forever too.
local function gameWith(id, camelot, toc)
    local keepId, keepCamelot, keepBuild, keepSlash = WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, GetBuildInfo, SlashCmdList.AMISIA
    WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = id, camelot
    GetBuildInfo = toc and function() return "x", "1", "d", toc end or nil
    local ns = { L = NS.L }
    assert(loadfile(ADDON_DIR .. "/Core/Registry.lua"))("Amisia", ns)
    WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, GetBuildInfo, SlashCmdList.AMISIA = keepId, keepCamelot, keepBuild, keepSlash
    return ns.GAME, ns.FOREVER
end
assert(NS.GAME == "forever" and NS.FOREVER == true, "the stub is Forever")
local g, f = gameWith(18, 18, 16001)
assert(g == "forever" and f == true, g)
g, f = gameWith(5, nil, 20506)
assert(g == "tbc" and f == false, g)
g, f = gameWith(2, nil, 11509)
assert(g == "era" and f == false, g)
-- without a project id: the interface number
assert(gameWith(nil, nil, 20506) == "tbc" and gameWith(nil, nil, 11509) == "era" and gameWith(nil, nil, 16001) == "forever")
assert(gameWith(nil, nil, nil) == "forever", "nothing known: Forever")
-- a project id of another client with Forever's constant missing is not Forever
assert(gameWith(18, nil, 16001) == "forever", "the interface number decides then")

-- the gate
assert(NS.Visible({ forever = true }) and NS.Visible(NS.SettingItem("ui.talentScale")), "on Forever shown")
NS.FOREVER = false
assert(not NS.Visible({ forever = true }) and not NS.Visible(NS.SettingItem("ui.goalScale")), "off Forever hidden")
assert(not NS.Visible(NS.SettingItem("record.exportWarn")))
NS.FOREVER = true

-- the reset button beside its control (all clients), the stepper's arrows the Forever atlases here
NS.ToggleMain()
NS.Dispatch("einstellungen")
NS.Set("record.keepSessions", 80)
NS.Refresh()
local r = NS.SettingsRows()["record.keepSessions"]
local p = r.reset.points.LEFT
assert(p and p.rel == r.control and p.relPoint == "RIGHT" and p.x == 8, "right of the stepper")
assert(not r.control.minus.arrowSet.texture and r.control.minus.arrow.atlas, "Forever's arrow atlas")
print("game switch ok")
