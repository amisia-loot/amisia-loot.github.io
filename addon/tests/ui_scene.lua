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
    -- the guild bank: three learned materials, a count, the officers' needs, a pledge, a few log entries
    for i, m in ipairs({ { 61001, "Feuerkern", 3 }, { 61002, "Runenstoff", 1 }, { 61003, "Arkanit", 2 } }) do
        STUB.item(m[1], m[2], m[3])
        AmisiaDB.mats[m[1]] = { name = m[2], q = m[3], first = i }
    end
    NS.RebuildMats()
    AmisiaDB.bank = { at = STUB.now - 600, counts = { [61001] = 12, [61002] = 80, [61003] = 300 }, tabs = 3, filled = 3, total = 4, by = "Vuloo" }
    NS.SetBankNeed(61001, 40, 80)
    NS.SetBankNeed(61002, 50, 100)
    NS.SetBankNeed(61003, 100)
    AmisiaDB.bankPledges = { { name = "Anna Bergmann", item = 61001, count = 20, t = math.floor(STUB.now) - 3600 } }
    AmisiaDB.bankLog.tabs = { [1] = "Raidmaterial", [2] = "Rüstungen", [3] = "Verbrauchsgüter" }
    NS.MergeBankLog({
        { k = 1, y = "deposit", n = "Anna Bergmann", i = 61001, c = 20, ago = 1 },
        { k = 1, y = "withdraw", n = "Bobbington", i = 61002, c = 10, ago = 5 },
        { k = 2, y = "move", n = "Vuloo", i = 61003, c = 20, a = 2, b = 1, ago = 26 },
        { k = 0, y = "deposit", n = "Fraktur", i = 0, c = 1234567, ago = 30 },
        { k = 0, y = "repair", n = "Chorf", i = 0, c = 52340, ago = 50 },
    }, math.floor(STUB.now))
    AmisiaDB.bankLog.at = math.floor(STUB.now)
    -- two group loot rolls: one won, one still open
    _G.LOOT_ROLL_NEED = _G.LOOT_ROLL_NEED or "%s hat Bedarf ausgewählt für: %s"
    _G.LOOT_ROLL_GREED = _G.LOOT_ROLL_GREED or "%s hat Gier ausgewählt für: %s"
    _G.LOOT_ROLL_ROLLED_NEED = _G.LOOT_ROLL_ROLLED_NEED or "Bedarfswurf - %d für %s von %s"
    _G.LOOT_ROLL_WON = _G.LOOT_ROLL_WON or "%s gewinnt: %s"
    if NS.GroupRolls then NS.GroupRolls._resetMatchers() end
    STUB.rolls[1] = LINK3
    STUB.fire("START_LOOT_ROLL", 1, 60000, 1)
    for _, line in ipairs({ LOOT_ROLL_NEED:format("Anna Bergmann", LINK3), LOOT_ROLL_GREED:format("Chorf", LINK3),
                            LOOT_ROLL_ROLLED_NEED:format(71, LINK3, "Anna Bergmann"), LOOT_ROLL_WON:format("Anna Bergmann", LINK3) }) do
        STUB.fire("CHAT_MSG_LOOT", line, "", "", "", "")
    end
    STUB.rolls[2] = LINK2
    STUB.fire("START_LOOT_ROLL", 2, 60000, 2)
    STUB.fire("CHAT_MSG_LOOT", LOOT_ROLL_NEED:format("Kimtaro", LINK2), "", "", "", "")
    -- the officers' loot rules: three own (the disenchanter's name is missing) and an offer
    NS.Set("awards.bankName", "Bobbington")
    NS.AddLootRule({ k = "m", to = "bank" })
    NS.AddLootRule({ k = "q", q = 3, to = "de" })
    NS.AddLootRule({ k = "p", items = "32837", to = "Kimtaro" })
    AmisiaDB.lootRules.offer = { from = "Fraktur", rev = math.floor(STUB.now) + 5, at = math.floor(STUB.now),
        list = { AmisiaDB.lootRules.list[1], { id = "beef", k = "i", items = { 30000, 32235 }, to = "bank", by = "Fraktur" } } }
    -- the guild bids DKP: the site's standings (the list shown to everyone) and the two awards' costs
    S.dkp()
    if s then
        for i, a in ipairs(s.awards) do NS.SetAwardPoints(s, a.id, i == 1 and 60 or 25) end
    end
end

-- The site's DKP block (bids, open) and its EPGP block.
function S.dkp()
    NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-07 dkp 1788000000\nCFG raid=10 boss=5 time=5 bench=10 mode=bid seal=0 min=10 step=5 decay=10 pub=1\n"
        .. "P Vuloo 240\nP Fraktur 185\nP Chorf 90\nP Anna_Bergmann 310\nP Kimtaro 45\nP Bobbington 1200\n#END")
end
function S.epgp()
    NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-07 epgp 1788000000\nCFG raid=10 boss=10 time=5 bench=10 base=100 minep=50 scale=100 ref=66 os=50 decay=10 pub=1\n"
        .. "P Vuloo 1240 380\nP Fraktur 985 120\nP Chorf 40 0\nP Anna_Bergmann 1310 640\nP Kimtaro 450 75\nP Bobbington 2200 1500\n#END")
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
    { page = "raidlog", name = "raidlog-rolls", open = function() NS.ShowRaidLog("rolls") end },
    { page = "raidlog", name = "raidlog-discord", open = function() NS.ShowRaidLog("discord") end },
    { page = "stats", name = "stats-fame", open = function() NS.ShowStats("fame") end },
    { page = "softres", name = "softres-raider", open = function() NS.ShowSoftRes("raider") end },
    { page = "softres", name = "softres-check", open = function() NS.ShowSoftRes("check") end },
    { page = "professions", name = "professions-camp", open = function() NS.ShowProfessions("lager") end },
    { page = "professions", name = "professions-favor", open = function() NS.ShowProfessions("gunst") end },
    { page = "professions", name = "professions-tailoring", open = function() NS.ShowProfessions("schneiderei") end },
    { page = "bank", name = "bank-stock", open = function() NS.ShowBank("bestand") end },
    { page = "bank", name = "bank-needs", open = function() NS.ShowBank("bedarf") end },
    { page = "bank", name = "bank-log", open = function() NS.ShowBank("log") end },
    { page = "bank", name = "bank-text", open = function() NS.ShowBank("text") end },
    { page = "points", name = "points-paste", open = function() NS.ShowPoints("paste") end },
    { page = "settings", name = "settings-lootrules", open = function() NS.ShowSettings(NS.L["Lootregeln"]) end },
    { page = "points", name = "points-epgp", open = function() S.epgp(); NS.ShowPoints("list") end },
    -- the scene's priest opens the mage scrolls by command (any class may); last, as the page list
    -- keeps its row from then on
    { page = "scrolls", name = "scrolls", always = true, open = function() NS.ShowMageScrolls() end },
}

S.WINDOWS = {
    { key = "rollframe", view = "officer", open = function()
        -- a rolling guild's round (the scene's guild bids DKP; the windows after it show that)
        NS.Set("points.system", "roll")
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
    { key = "rollframe-bid", view = "officer", open = function()
        S.dkp()
        NS.StartRoll(LINK2, 30)
        STUB.fire("CHAT_MSG_RAID", "!bid 50", "Kimtaro")
        STUB.fire("CHAT_MSG_RAID", "!bid 80", "Anna Bergmann")
        STUB.fire("CHAT_MSG_RAID", "!bid 900", "Chorf")
        NS.ShowRollFrame()
        return AmisiaRollFrame
    end },
    { key = "rollframe-need", view = "officer", open = function()
        S.epgp()
        NS.StartRoll(LINK3, 30)
        STUB.fire("CHAT_MSG_RAID", "!need", "Anna Bergmann")
        STUB.fire("CHAT_MSG_RAID", "!need", "Chorf")
        STUB.fire("CHAT_MSG_WHISPER", "!greed", "Kimtaro")
        STUB.fire("CHAT_MSG_RAID", "!need", "Bobbington")
        NS.ShowRollFrame()
        return AmisiaRollFrame
    end },
    { key = "awarddialog-points", view = "officer", open = function()
        NS.StopRoll()
        NS.ShowAwardDialog(LINK3)
        return AmisiaAwardDialog
    end },
    { key = "softresframe", view = "officer", open = function()
        NS.ToggleSoftResFrame()
        return AmisiaSoftResFrame
    end },
    { key = "gearframe", view = "raider", open = function()
        NS.ToggleGearFrame()
        return AmisiaGearFrame
    end },
    { key = "lootrules-bar", view = "officer", open = function()
        -- one click: the bar beside the loot window with what the rules would hand out
        NS.Set("lootrules.mode", "click")
        NS.Set("awards.deName", "Chorf")
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, 1
        local green = STUB.item(70001, "Grüner Gürtel", 2)
        STUB.loot = { { link = green, name = "Grüner Gürtel", src = "Creature-0-1-1-1-22918-1" },
                      { link = STUB.item(61001, "Feuerkern", 3), name = "Feuerkern", src = "Creature-0-1-1-1-22918-1" } }
        STUB.fire("LOOT_OPENED", false)
        return NS.LootRulesBar()
    end },
    { key = "rollwindow", view = "raider", open = function()
        -- the raiders' roll window: the result of the round before under the running one
        local rw = NS._rollWindow
        rw.start({ "a1b2", "item:32837", "20", "R", "-", "-", "-", "-", "-" }, "Fraktur", "Fraktur")
        rw.finish("a1b2", "Fraktur", "Anna Bergmann", "95:MS", false, "D")
        rw.start({ "c3d4", "item:32235::::::::70", "20", "R", "-", "Vuloo,Chorf", "-", "-", "-" }, "Fraktur", "Fraktur")
        return AmisiaRollWindow
    end },
    { key = "rollwindow-bid", view = "raider", open = function()
        S.dkp()
        NS.RollWindowTest(LINK, "B")
        return AmisiaRollWindow
    end },
    { key = "rollwindow-need", view = "raider", open = function()
        S.epgp()
        NS._rollWindow.start({ "e5f6", "item:30000", "20", "N", "-", "-", "150", "75", "-" }, "Fraktur", "Fraktur")
        return AmisiaRollWindow
    end },
    { key = "rollwindow-tie", view = "raider", open = function()
        STUB.chatLock = true
        NS._rollWindow.start({ "0707", "item:32837", "10", "R", "T", "-", "-", "-", "Vuloo,Kimtaro" }, "Fraktur", "Fraktur")
        NS._rollWindow.refresh()
        STUB.chatLock = false
        return AmisiaRollWindow
    end },
    { key = "selftest", view = "officer", open = function()
        NS.SelfTest.Show()
        return AmisiaSelfTestFrame
    end },
}

return S
