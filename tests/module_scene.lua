-- Amisia with one module left out (F-202, D-130): tests/test_without_raid.lua and test_without_gear.lua
-- run it in a runtime without that module's files (tests/run.py, "--[[without raid]]"). It builds the
-- scene of the snapshots (tests/ui_scene.lua), then in every view opens every visible page, every state of
-- a page there and every side window of the modules that are there, and runs what a player reaches
-- without the main window (help, minimap menu, search, events, timers). A Lua error fails the test.
-- Load with dofile(ADDON_DIR .. "/../tests/module_scene.lua")(missing), missing "raid" or "gear".
return function(missing)
    local other = missing == "raid" and "gear" or "raid"
    assert(not NS.HasModule(missing), "the module is left out: " .. missing)
    assert(NS.HasModule(other), "the other module is there: " .. other)
    local S = dofile(ADDON_DIR .. "/../tests/ui_scene.lua")
    S.setup()
    local opened = {}
    for _, view in ipairs({ "raider", "officer", "expert" }) do
        for k, v in pairs(S.VIEWS[view]) do NS.Set(k, v) end
        NS.ShowPage("overview")
        for _, p in ipairs(NS.panels) do
            if NS.Visible(p) then
                NS.ShowPage(p.key)
                STUB.tick(1)
                opened[p.key] = true
            end
        end
        for _, st in ipairs(S.STATES) do
            local p = NS.Panel(st.page)
            if p and NS.Visible(p) and st.module ~= missing then
                st.open()
                STUB.tick(1)
            end
        end
        for _, w in ipairs(S.WINDOWS) do
            if w.view == view and w.module ~= missing then
                local f = w.open()
                if type(f) == "table" and f.Hide then f:Hide() end
                STUB.tick(1)
            end
        end
    end
    -- the pages of the module that is not there are not registered; the core's and the other's are
    local mine = { raid = { "raids", "rolls", "awards", "softres", "lineup", "bank" },
                   gear = { "gear", "planner", "dungeons", "professions", "talents", "map" } }
    for _, key in ipairs(mine[missing]) do assert(NS.Panel(key) == nil, "a page of the missing module: " .. key) end
    for _, key in ipairs(mine[other]) do assert(NS.Panel(key) ~= nil, "a page of the other module is missing: " .. key) end
    assert(opened.overview and opened.settings and opened.about, "the core's pages open")
    -- what a player reaches without the main window
    NS.ShowHelp()
    NS.Dispatch("status")
    NS.Dispatch("hilfe")
    NS.Dispatch("selbsttest kurz")
    STUB.tick(5)
    if NS.MinimapMenu then NS.MinimapMenu() end
    if NS.SearchResults then NS.SearchResults("feuer") end
    for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "LOOT_OPENED",
                          "LOOT_CLOSED", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED" }) do
        STUB.fire(ev)
    end
    STUB.fire("CHAT_MSG_LOOT", (LOOT_ITEM_SELF or "Ihr erhaltet Beute: %s."):format(STUB.item(32235, "Cursed Vision of Sargeras", 4)),
        "", "", "", "")
    STUB.tick(70)
    -- the settings of the module that is not there stay in AmisiaDB (F-202: only the migration steps
    -- remove a key), and the saved data is checked again on the next load
    AmisiaDB.settings.lootrules = { mode = "auto" }
    AmisiaDB.settings.planner = { keep = 3 }
    NS.ApplySettings(AmisiaDB)
    assert(AmisiaDB.settings.lootrules.mode == "auto" and AmisiaDB.settings.planner.keep == 3)
end
