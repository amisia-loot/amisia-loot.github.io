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

-- Awarded items still in the own bags (the trade helper, Handover.lua): Anna's belt with 72 minutes
-- and Fraktur's helm with 25 minutes to trade.
function S.handover()
    STUB.bags[0] = { LINK3, LINK }
    STUB.bagInfo[0] = { [1] = { guid = "Item-1-A", trade = "1 Std. 12 Min." }, [2] = { guid = "Item-1-B", trade = "25 Min." } }
    STUB.fire("BAG_UPDATE_DELAYED")
    STUB.tick(1)
end

-- A raid night's sign-ups (the lineup, Lineup.lua): a bot's text with headings, 22 guild members,
-- a likely, an ambiguous and an unknown name, a guest from the group, the bench and the absent;
-- then "Automatisch einteilen" with one held player.
local lineupDone
function S.lineup()
    if lineupDone then return end
    lineupDone = true
    local add = {
        { "Bob Eisherz", "WARRIOR" }, { "Grimm Felsfaust", "WARRIOR" }, { "Lina Sonnfeld", "PALADIN" },
        { "Mara Quell", "SHAMAN" }, { "Tobi Hain", "DRUID" }, { "Ella Licht", "PRIEST" }, { "Rurik Stahl", "WARRIOR" },
        { "Sven Dorn", "ROGUE" }, { "Jo Klinge", "ROGUE" }, { "Uli Donner", "SHAMAN" }, { "Pia Pfeil", "HUNTER" },
        { "Nora Frost", "MAGE" }, { "Zed Schatten", "WARLOCK" }, { "Ida Funke", "MAGE" }, { "Vulo Hunt", "HUNTER" },
        { "Vulo Pala", "PALADIN", 52 }, { "Kai Wind", "HUNTER" }, { "Eda Glut", "WARLOCK" },
    }
    for _, a in ipairs(add) do
        STUB.guild[#STUB.guild + 1] = { name = a[1], class = a[2], rank = 3, level = a[3], online = a[1] ~= "Ida Funke" }
    end
    STUB.guild[1].class, STUB.guild[2].class, STUB.guild[3].class = "PRIEST", "SHAMAN", "WARRIOR"
    STUB.guild[4].class, STUB.guild[5].class = "PRIEST", "ROGUE"
    STUB.fire("GUILD_ROSTER_UPDATE")
    STUB.tick(11)
    NS.SetLineupText(table.concat({
        "**Geschmolzener Kern** Donnerstag 20:00",
        "Tanks (3)", "1. :Warrior: Bob Eisherz", "2. :Warrior: Grimm Felsfaust", "3. :Paladin: Lina Sonnfeld",
        "Heiler (5)", "Mara Quell", "Tobi Hain", "Ella Licht", "Anna", "Vuloo",
        "Nahkampf", "Rurik Stahl", "Sven Dorn", "Jo Klinge", "Uli Donner", "Chorf", "Kimtaro",
        "Fernkampf", "Pia Pfeil", "Nora Frost", "Zed Schatten", "Ida Funke", "Bobbington", "Vulo", "Kai Windd",
        "Ersatz", "Eda Glut", "Fraktur", "Abgemeldet", "Niemand Nirgends",
    }, "\n"))
    NS.LineupAutoAssign()
    local n = NS.LineupNight()
    for i, e in ipairs(n.list) do
        if e.n == "Nora Frost" then NS.LineupHold(nil, i, true) end
    end
end

-- The game calendar (Raid/Calendar.lua): tonight's raid "Geschmolzener Kern" (an hour from now),
-- a meeting and Onyxia later; the raid's invite list holds names of the pasted list (one declined,
-- one tentative) and names only the calendar knows.
local calendarDone
function S.calendar()
    if calendarDone then return end
    calendarDone = true
    STUB.calendar({ events = {
        { title = "Geschmolzener Kern", at = STUB.now + 3600, eventType = 0, id = 31, inviteStatus = 3 },
        { title = "Gildentreffen", days = 2, eventType = 3, id = 32 },
        { title = "Onyxia", days = 4, eventType = 0, id = 33, inviteStatus = 6 },
    }, invites = { [31] = {
        { name = "Bob Eisherz", classFilename = "WARRIOR", level = 60, inviteStatus = 6 },
        { name = "Mara Quell", classFilename = "SHAMAN", level = 60, inviteStatus = 8 },
        { name = "Sven Dorn", classFilename = "ROGUE", level = 60, inviteStatus = 2 },
        { name = "Vuloo", classFilename = "PRIEST", level = 60, inviteStatus = 3 },
        { name = "Lea Morgen", classFilename = "MAGE", level = 60, inviteStatus = 6 },
        { name = "Tim Abend", classFilename = "DRUID", level = 60, inviteStatus = 5 },
        { name = "Ute Still", classFilename = "PRIEST", level = 60, inviteStatus = 7 },
    } } })
    STUB.guild[#STUB.guild + 1] = { name = "Lea Morgen", class = "MAGE", rank = 3 }
    STUB.guild[#STUB.guild + 1] = { name = "Tim Abend", class = "DRUID", rank = 3 }
    STUB.guild[#STUB.guild + 1] = { name = "Ute Still", class = "PRIEST", rank = 4, online = false }
    STUB.fire("GUILD_ROSTER_UPDATE")
    STUB.tick(11)
    NS.SignupLoadTerms()
    STUB.tick(1)
end

-- The sign-ups from Amisia this client keeps for tonight's raid (the raid calendar window): every
-- role, tentative and signed off ones, a long note.
local rcSignupsDone
function S.raidCalendarSignups()
    S.calendar()
    if rcSignupsDone then return end
    rcSignupsDone = true
    local ev = NS.Cal.Events()[1]
    local keep, t = NS._signup.keepSeen, math.floor(STUB.now)
    keep(ev.night, "Pia Pfeil", { s = "A", r = "R", c = "HUNTER", t = t, w = "komme 20:15" })
    keep(ev.night, "Jo Klinge", { s = "X", r = "M", c = "ROGUE", t = t, w = "Nachtschicht, sorry" })
    keep(ev.night, "Lea Morgen", { s = "A", r = "R", c = "MAGE", t = t, w = "Feuer" })
    keep(ev.night, "Bob Eisherz", { s = "A", r = "T", c = "WARRIOR", t = t })
    keep(ev.night, "Hanna Licht", { s = "A", r = "H", c = "PALADIN", t = t,
        w = "komme etwas später, muss noch das Kind ins Bett bringen" })
    keep(ev.night, "Kai Fels", { s = "A", r = "M", c = "WARRIOR", t = t })
    keep(ev.night, "Nele Mond", { s = "V", r = "H", c = "DRUID", t = t, w = "vielleicht" })
    keep(ev.night, "Olaf Grimm", { s = "V", r = "T", c = "PALADIN", t = t })
    keep(ev.night, "Rike Sturm", { s = "X", r = "R", c = "WARLOCK", t = t, w = "Urlaub" })
end

-- Tonight's lineup with the calendar's invite list and two sign-ups from Amisia (a note, a sign-off).
local lineupCalDone
function S.lineupCalendar()
    S.lineup()
    S.calendar()
    if lineupCalDone then return end
    lineupCalDone = true
    local ev = NS.Cal.Events()[1]
    NS.LineupReadCalendar(ev, function() end)
    STUB.tick(1)
    local night = ev.night
    NS.LineupSignup(night, "Pia Pfeil", { s = "A", r = "R", c = "HUNTER", t = math.floor(STUB.now), w = "komme 20:15" }, false)
    NS.LineupSignup(night, "Jo Klinge", { s = "X", r = "M", c = "ROGUE", t = math.floor(STUB.now) }, false)
    NS.LineupSignup(night, "Lea Morgen", { s = "A", r = "R", c = "MAGE", t = math.floor(STUB.now), w = "Feuer" }, false)
end

-- The raid check (Raid/RaidCheck.lua): the scene's raid with buffs (a flask, elixirs, food, class
-- buffs; one raider out of sight with an own report, one without anything), the own reports of
-- three raiders (durability red, orange, fine; empty and unenchanted slots; free points), and raid
-- IDs of the account and of the guild (Molten Core: locked, free, heard from another).
local raidCheckDone
function S.raidCheck()
    S.lineup()
    if raidCheckDone then return end
    raidCheckDone = true
    local function aura(id, dur) return { name = "Buff " .. id, spellId = id, duration = dur, expirationTime = GetTime() + dur - 300 } end
    local auras = {
        raid1 = { aura(17626, 7200), aura(19705, 900), aura(10938, 1800), aura(10157, 1800) },
        raid2 = { aura(17538, 3600), aura(11390, 3600), aura(19705, 900), aura(10938, 1800) },
        raid3 = { aura(10938, 1800), aura(10157, 1800) },
        raid4 = { aura(17627, 7200), aura(10938, 1800) },
        raid6 = { aura(17626, 7200), aura(19705, 900), aura(10938, 1800), aura(10157, 1800) },
    }
    auras.player = auras.raid1
    _G.C_UnitAuras = { GetAuraDataByIndex = function(unit, i) local l = auras[unit] return l and l[i] end }
    _G.UnitIsVisible = function(u) return u ~= "raid5" end
    STUB.playerRaidIndex = 1
    local answers = NS._raidcheck.answers()
    local t = math.floor(STUB.now)
    answers["fraktur"] = { name = "Fraktur", at = t - 120, dur = 24, below = 2, ilvl = 61.3, empty = {}, unench = { 9, 8 }, free = 0, heard = true,
                           cons = { elixirs = { {}, {} }, food = {}, have = {} } }
    answers["chorf"] = { name = "Chorf", at = t - 40, dur = 46, below = 0, ilvl = 58.1, empty = { 18 }, unench = {}, free = 2, heard = true,
                         cons = { elixirs = {}, have = {} } }
    answers["bobbington"] = { name = "Bobbington", at = t - 300, dur = 88, below = 0, ilvl = 60.4, empty = {}, unench = { 15 }, free = 0, heard = true,
                              cons = { flask = {}, elixirs = {}, food = {}, have = {} } }
    local st = AmisiaDB.raidcheck
    local r = t + 3 * 86400
    st.names[409] = "Geschmolzener Kern"
    st.names[249] = "Onyxias Hort"
    st.own["Vuloo"] = { at = t, c = "PRIEST", l = 24, ids = {} }
    st.own["Vulo Pala"] = { at = t - 3600, c = "PALADIN", l = 52, ids = { { m = 409, d = 9, r = r, k = 4, t = 10 } } }
    st.heard["Vulo Hunt"] = { by = "Vulo Hunt", at = t - 600, c = "HUNTER", l = 60, ids = { { m = 409, d = 9, r = r, k = 10, t = 10 },
                                                                                          { m = 249, d = 9, r = r, k = 1, t = 1 } } }
    st.heard["Bob Eisherz"] = { by = "Bob Eisherz", at = t - 900, c = "WARRIOR", l = 60, ids = {} }
    st.heard["Grimm Felsfaust"] = { by = "Bob Eisherz", at = t - 900, c = "WARRIOR", l = 60, ids = { { m = 409, d = 9, r = r, k = 2, t = 10 } } }
    st.heard["Mara Quell"] = { by = "Mara Quell", at = t - 60, c = "SHAMAN", l = 60, ids = {} }
    NS.ImportSiteText("#AMISIA-ALTS 1 forever 2026-10-12\nA Vulo_Pala Vulo_Hunt\nA Grimm_Felsfaust Bob_Eisherz\n#END")
    NS.RaidIDsChoose(409)
    NS.Set("raidcheck.chat", true)
end

-- A priest build with every talent state: full (gold frame, glow), partly learned, reachable,
-- locked, met and unmet prerequisite lines.
function S.priestPlan()
    local plan = NS.Talents.NewPlan("PRIEST")
    plan.ranks[105849], plan.ranks[105850], plan.ranks[105846] = 5, 1, 3
    plan.ranks[105833], plan.ranks[105832] = 5, 1
    return plan
end

-- Further states of pages, shot after the pages themselves (in every view the page shows in):
-- { page, name, open = fn() } opens the page in that state through its public entry point.
S.STATES = {
    { page = "gear", name = "gear-here", open = function() NS.ShowGear("here") end },
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
    -- the priest build of S.priestPlan (every talent state)
    { page = "talents", name = "talents-plan", open = function() NS.ShowTalents(NS.Talents.Encode(S.priestPlan())) end },
    { page = "bank", name = "bank-stock", open = function() NS.ShowBank("bestand") end },
    { page = "bank", name = "bank-needs", open = function() NS.ShowBank("bedarf") end },
    { page = "bank", name = "bank-log", open = function() NS.ShowBank("log") end },
    { page = "bank", name = "bank-text", open = function() NS.ShowBank("text") end },
    { page = "points", name = "points-paste", open = function() NS.ShowPoints("paste") end },
    { page = "settings", name = "settings-lootrules", open = function() NS.ShowSettingsSection("lootrules") end },
    -- the head button "Einstellungen" of the page Rolls: its sections, "Zurück zu Rolls" (D-49)
    { page = "settings", name = "settings-rolls", open = function() NS.ShowSettingsFor("rolls") end },
    { page = "settings", name = "settings-search", open = function() NS.ShowSettings("ton") end },
    { page = "points", name = "points-epgp", open = function() S.epgp(); NS.ShowPoints("list") end },
    { page = "awards", name = "awards-handover", open = function() S.handover(); NS.ShowHandover() end },
    -- the lineup: the match view, the planner, the paste field
    { page = "lineup", name = "lineup-match", open = function() S.lineup(); NS.ShowLineup("match") end },
    { page = "lineup", name = "lineup-planner", open = function() S.lineup(); NS.ShowLineup("planner") end },
    { page = "lineup", name = "lineup-paste", open = function() S.lineup(); NS.ShowLineup("paste") end },
    -- the invite view (F-084): every status, tries, the raiders not on the list
    { page = "lineup", name = "lineup-invite", open = function()
        S.lineup()
        local IV = NS.LineupInv
        IV._reset()
        IV._set(nil, "Bob Eisherz", "I", 1)
        IV._set(nil, "Grimm Felsfaust", "D", 1)
        IV._set(nil, "Lina Sonnfeld", "N", 2)
        IV._set(nil, "Mara Quell", "G", 1)
        IV._set(nil, "Tobi Hain", "U", 1)
        IV._set(nil, "Rurik Stahl", "D", 3)
        NS.ShowLineup("invite")
    end },
    -- the lineup with the calendar: the events to choose, then the rows with their sources
    { page = "lineup", name = "lineup-calendar", open = function() S.lineup(); S.calendar(); NS.ShowLineup("calendar"); STUB.tick(1) end },
    { page = "lineup", name = "lineup-sources", open = function()
        S.lineupCalendar()
        NS.ShowLineup("match", NS.Cal.Events()[1].night)
    end },
    { page = "lineup", name = "lineup-sources-planner", open = function()
        S.lineupCalendar()
        NS.ShowLineup("planner", NS.Cal.Events()[1].night)
    end },
    -- the raid check: buffs, gear, raid IDs; the lineup with the "ID" marks of Molten Core
    { page = "raidcheck", name = "raidcheck-buffs", open = function() S.raidCheck(); NS.ShowRaidCheck("buffs") end },
    { page = "raidcheck", name = "raidcheck-gear", open = function() S.raidCheck(); NS.ShowRaidCheck("gear") end },
    { page = "raidcheck", name = "raidcheck-ids", open = function() S.raidCheck(); NS.ShowRaidCheck("ids") end },
    { page = "lineup", name = "lineup-raidids", open = function() S.raidCheck(); NS.ShowLineup("match", NS.LineupTonight()) end },
    -- the card "Raid-Anmeldung" with the own sign-up for the first date
    { page = "overview", name = "overview-signup", open = function()
        S.calendar()
        local t = NS.SignupTerms()
        if t and t[1] and not NS.SignupOf()[t[1].night] then NS.SignupSet(t[1], "V", "H", "komme 20:15") end
        NS.ShowPage("overview")
    end },
    -- the calendar page with the scene's dates: tonight's raid chosen (its participants on the right),
    -- the meeting in two days, Onyxia in four, the recorded raid of the scene
    { page = "calendar", name = "calendar-dates", open = function()
        S.raidCalendarSignups()
        NS.ShowCalendar(NS.Cal.Events()[1].night)
        STUB.tick(1)
    end },
    -- a day without a date (ten days on): the day's inset says so, no buttons
    { page = "calendar", name = "calendar-empty-day", open = function()
        S.calendar()
        NS.ShowCalendar(NS.NightOf(time() + 10 * 86400))
    end },
    -- the search over the page list: pages, settings, items and (officers) players
    { page = "overview", name = "search-ra", open = function()
        NS.ShowPage("overview")
        local box = AmisiaFrame.search
        box:SetText("ra")
        box.scripts.OnTextChanged(box, true)
    end },
    { page = "overview", name = "search-cursed", open = function()
        NS.ShowPage("overview")
        local box = AmisiaFrame.search
        box:SetText("cursed")
        box.scripts.OnTextChanged(box, true)
    end },
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
    { key = "softresframe-code", view = "officer", open = function()
        -- the softres.it code (its Gargul export) in the import window: the preview of the code
        NS.ToggleSoftResFrame()
        local F = AmisiaSoftResFrame
        F.editBox:SetText("eNpljzFPxDAMhf+L5wxNVdoj27EwggSIAXVwa1dEpMnJSVmq/ncSDkErMsXv6X1+XmHmhIQJwaxgCQzgoOuRQMEojInpnMDo7la3N1V+CpYLHWX9LQtaekooKf46bd0U590SsQczoYusgGwcg9CLuLwMNgUxTEk4snxyBPO2gseZs3f2HksNhzHr8CiWY8qCD6nY+XdxS3zwJZXX2MTzNV/O0KeTbja1H/oy/rDvwrBDv6KIDfLHfkb/ceDrf/yu6tqM7PN9KHTof/XrqlEwZaqBe+uId81Lagh+iRKcK5l++wJJR3km")
        F.previewText:SetText(NS.SoftResPreviewText(F.editBox:GetText()))
        return F
    end },
    { key = "gearframe", view = "raider", open = function()
        NS.ToggleGearFrame()
        return AmisiaGearFrame
    end },
    { key = "talentframe", view = "raider", open = function()
        -- the big talent window ("Talentrechner") with the priest build of the page's state
        local plan = S.priestPlan()
        NS.Talents.State().class = plan.class
        NS.TalentsSetPlan(plan)
        NS.ShowTalentFrame()
        return AmisiaTalentFrame
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
    { key = "rollwindow-gargul", view = "raider", open = function()
        -- a round the loot lead started with Gargul: the window marked "(Gargul)" with its note
        NS.RollWindowForeign({ link = "item:32235::::::::70", secs = 20, note = "Tanks zuerst" }, "Fraktur", "Fraktur")
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
    { key = "tradehelper", view = "raider", open = function()
        -- the trade window with Anna: the helper beside it
        S.handover()
        _G.TradeFrame = _G.TradeFrame or CreateFrame("Frame", "TradeFrame", UIParent)
        STUB.npc = "Anna Bergmann"
        STUB.fire("TRADE_SHOW")
        return AmisiaTradeHelper
    end },
    -- the setup assistant (Setup.lua): the offer and each of its six steps
    { key = "setup-offer", view = "officer", open = function()
        return NS._setup.showOffer()
    end },
    { key = "setup-1", view = "officer", open = function()
        NS.Set("awards.deName", "")
        return NS.ShowSetup(1)
    end },
    { key = "setup-2", view = "officer", open = function() return NS.ShowSetup(2) end },
    { key = "setup-3", view = "officer", open = function()
        -- a DKP guild: the system's points rows show
        NS.Set("points.system", "dkp")
        return NS.ShowSetup(3)
    end },
    { key = "setup-3-epgp", view = "officer", open = function()
        NS.Set("points.system", "epgp")
        return NS.ShowSetup(3)
    end },
    { key = "setup-4", view = "officer", open = function() return NS.ShowSetup(4) end },
    { key = "setup-5", view = "officer", open = function()
        -- the scene's three rules and the materials preset (already there: the status line says so)
        NS.ShowSetup(5)
        NS._setup.addPreset(NS._setup.presets[3])
        return NS._setup.frame()
    end },
    { key = "setup-6", view = "officer", open = function() return NS.ShowSetup(6) end },
    -- the raid sign-up window (UI/Signup.lua) with the first date chosen
    { key = "signup", view = "raider", open = function()
        S.calendar()
        return NS.ShowSignup()
    end },
    -- the sign-up window after a click whose calendar entry did not work (part H3: the scene's
    -- calendar cannot write): the hint with "Kalender öffnen"
    { key = "signup-calendar-hint", view = "raider", open = function()
        S.calendar()
        local t = NS.SignupTerms()[1]
        _G.ToggleCalendar = _G.ToggleCalendar or function() end
        NS.SignupSet(t, "A", "H", "komme 20:15", { click = true })
        return NS.ShowSignup(t.night)
    end },
    -- the raid calendar window (UI/RaidCalendar.lua, part I): tonight's raid with the calendar's
    -- invites and sign-ups from Amisia (notes, a sign-off), the dates on the left
    -- (every group and role, a long note, guessed roles from the calendar's names; more names than
    -- rows, so the list scrolls)
    { key = "raidcalendar", view = "raider", open = function()
        S.raidCalendarSignups()
        NS.ShowRaidCalendar(NS.Cal.Events()[1].night)
        STUB.tick(1)
        return AmisiaRaidCalendarFrame
    end },
    { key = "raidcalendar-officer", view = "officer", open = function()
        S.raidCalendarSignups()
        NS.ShowRaidCalendar(NS.Cal.Events()[1].night)
        STUB.tick(1)
        return AmisiaRaidCalendarFrame
    end },
    -- the question before the calendar write probe (W.Confirm): the warning, "Ausführen", "Abbrechen"
    { key = "confirm", view = "raider", open = function()
        local text = NS.L["Kalender-Schreibprüfung: schreibt in den Kalender: meldet dich beim gewählten Ereignis an, vorläufig, entfernt dich und stellt danach deinen alten Stand wieder her. Ereignis: %s, %s (dein Status %s)."]:format(
            "test123", "12.10. 20:00", "7 NotSignedup")
        return NS.W.Confirm(NS.L["Kalender-Schreibprüfung"], text, NS.L["Ausführen"], function() end)
    end },
    { key = "selftest", view = "officer", open = function()
        NS.SelfTest.Show()
        return AmisiaSelfTestFrame
    end },
}

return S
