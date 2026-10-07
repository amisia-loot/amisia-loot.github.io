-- The world the UI snapshots and the layout rules show (tools/ui_layout.py): an officer's raid with
-- members, loot, a finished roll round, awards and soft-reserves, a level 24 priest with professions.
-- Load with dofile(ADDON_DIR .. "/../tests/ui_scene.lua"); it returns S:
--   S.setup()             builds the world (once per runtime, before any page opens)
--   S.VIEWS[view]         the settings of a view (raider, officer, expert)
--   S.WINDOWS             the side windows: { key, view, open = fn() -> frame }
local S = {}

S.VIEWS = {
    raider = { ["ui.view"] = "raider", ["ui.expert"] = false },
    officer = { ["ui.view"] = "officer", ["ui.expert"] = false },
    expert = { ["ui.view"] = "officer", ["ui.expert"] = true },
}

local LINK, LINK2, LINK3

function S.setup()
    RAID_CLASS_COLORS.MAGE = RAID_CLASS_COLORS.MAGE or { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" }
    RAID_CLASS_COLORS.ROGUE = RAID_CLASS_COLORS.ROGUE or { r = 1, g = 0.96, b = 0.41, colorStr = "fffff569" }
    STUB.class, STUB.level, STUB.faction = "PRIEST", 24, "Alliance"
    STUB.skills = { { name = "Berufe", header = true }, { name = "Schneiderei", rank = 120, id = 197 },
                    { name = "Verzauberkunst", rank = 95, id = 333 } }
    STUB.roster = {
        { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
        { name = "Chorf", class = "WARRIOR" }, { name = "Anna Bergmann", class = "PRIEST" },
        { name = "Bobbington", class = "MAGE", zone = "Shattrath" }, { name = "Kimtaro", class = "ROGUE" },
    }
    STUB.guild = {
        { name = "Vuloo", rank = 2 }, { name = "Fraktur", rank = 1 }, { name = "Chorf", rank = 3 },
        { name = "Anna Bergmann", rank = 4 }, { name = "Kimtaro", rank = 3, online = false },
    }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    LINK = STUB.item(32235, "Cursed Vision of Sargeras", 4)
    LINK2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
    LINK3 = STUB.item(30000, "Gürtel der unendlichen Weiten", 4)
    STUB.loot = { { link = LINK, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" },
                  { link = LINK2, name = "Warglaive of Azzinoth", src = "Creature-0-1-1-1-22917-1" } }
    STUB.target, STUB.targetGUID = "Illidan Stormrage", "Creature-0-1-1-1-22917-1"
    STUB.fire("LOOT_OPENED")
    -- a finished roll round and two awards
    NS.StartRoll(LINK, 5)
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 87, 1, 100))
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Anna Bergmann", 64, 1, 100))
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Chorf", 33, 1, 50))
    NS.StopRoll()
    local s = NS.Active()
    if s then
        NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Stormrage" })
        NS.AddAwardTo(s, { name = "Anna Bergmann", item = 30000, kind = "OS", src = "Illidan Stormrage", note = "Tausch" })
    end
    NS.SetSoftRes("Vuloo 32235\nFraktur 32235\nBobbington 32837\nAnna Bergmann 30000\nGustav 32837\n")
    -- the officers' loot prio of two items
    NS.SetLootPrio("#AMISIA-LC 1 forever 2026-10-07\nC 32837 1788000000 p:Kimtaro:Tank,c:WARRIOR:Furor,p:Bobbington,o Erst Tanks, dann DPS\n"
        .. "C 32235 1788000000 p:Anna_Bergmann:Heal,o\n#END")
    STUB.fire("LOOT_CLOSED")
end

-- Further states of pages, shot after the pages themselves (in every view the page shows in):
-- { page, name, open = fn() } opens the page in that state through its public entry point.
S.STATES = {
    { page = "gear", name = "gear-here", open = function() NS.ShowGear("here") end },
    { page = "gear", name = "gear-dungeons", open = function() NS.ShowGear("dungeons") end },
    { page = "gear", name = "gear-wish", open = function() NS.ShowGear("wish") end },
    { page = "gear", name = "gear-guild", open = function() NS.ShowGear("guild") end },
    { page = "gear", name = "gear-sim", open = function() NS.ShowGear("sim") end },
    { page = "raidlog", name = "raidlog-bench", open = function() NS.ShowRaidLog("bench") end },
    { page = "raidlog", name = "raidlog-discord", open = function() NS.ShowRaidLog("discord") end },
    { page = "stats", name = "stats-fame", open = function() NS.ShowStats("fame") end },
    { page = "softres", name = "softres-raider", open = function() NS.ShowSoftRes("raider") end },
    { page = "softres", name = "softres-check", open = function() NS.ShowSoftRes("check") end },
    { page = "professions", name = "professions-camp", open = function() NS.ShowProfessions("lager") end },
    { page = "professions", name = "professions-favor", open = function() NS.ShowProfessions("gunst") end },
    { page = "professions", name = "professions-tailoring", open = function() NS.ShowProfessions("schneiderei") end },
}

S.WINDOWS = {
    { key = "rollframe", view = "officer", open = function()
        NS.StartRoll(LINK2, 30)
        STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Kimtaro", 92, 1, 100))
        STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Bobbington", 41, 1, 100))
        NS.ShowRollFrame()
        return AmisiaRollFrame
    end },
    { key = "awarddialog", view = "officer", open = function()
        NS.ShowAwardDialog(LINK)
        return AmisiaAwardDialog
    end },
    { key = "priodialog", view = "officer", open = function()
        NS.ShowPrioDialog(LINK2)
        return AmisiaPrioDialog
    end },
    { key = "softresframe", view = "officer", open = function()
        NS.ToggleSoftResFrame()
        return AmisiaSoftResFrame
    end },
    { key = "gearframe", view = "raider", open = function()
        NS.ToggleGearFrame()
        return AmisiaGearFrame
    end },
    { key = "selftest", view = "officer", open = function()
        NS.SelfTest.Show()
        return AmisiaSelfTestFrame
    end },
}

return S
