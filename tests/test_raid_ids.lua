-- Raid IDs on one client (Raid/RaidIDs.lua, F-099, D-46): the saved instances of the logged-in
-- character are kept per character of the account (AmisiaDB is account-wide), only locked ones with
-- a reset, raids first, 6 at most, the client's instance name remembered; another character of the
-- same account logging in sees them ("allein": Vulo Pala locked, Vulo Hunt free); after the reset the
-- ID is gone; the load prunes (IDs past their reset, own characters after 60 days, the 12 newest,
-- heard ones after 30 days, the 300 newest, bad fields); what an officer takes from IV (the
-- character in the guild roster, its own report first, the alt list, 12 per sender); the rows of the
-- view grouped by main with the filters; the own lines of a raider.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local DAY = 86400

STUB.guild = { { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 }, { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 52 },
               { name = "Bob Eisherz", rank = 3, class = "WARRIOR", level = 60 }, { name = "Lia Eisherz", rank = 4, class = "MAGE", level = 60 },
               { name = "Kai Wind", rank = 4, class = "HUNTER", level = 60 } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)

local SAVED = {}
local asked = 0
_G.RequestRaidInfo = function()
    asked = asked + 1
    C_Timer.After(0.5, function() STUB.fire("UPDATE_INSTANCE_INFO") end)
end
_G.GetNumSavedInstances = function() return #SAVED end
_G.GetSavedInstanceInfo = function(i) return unpack(SAVED[i]) end
-- name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress, extendDisabled, instanceID
local MC = { "Geschmolzener Kern", 1234, 3 * DAY, 9, true, false, 0, true, 40, "40 Spieler", 10, 4, false, 409 }
local ONY_OPEN = { "Onyxias Hort", 98765, 86400, 9, false, false, 0, true, 40, "40 Spieler", 1, 1, false, 249 }
local DM = { "Die Todesminen", 555, DAY, 1, true, false, 0, false, 5, "Normal", 5, 2, false, 36 }

-- 1. Vulo Pala has the Molten Core ID (and an open Onyxia entry, and a dungeon)
STUB.player, STUB.class, STUB.level = "Vulo Pala", "PALADIN", 52
SAVED = { DM, MC, ONY_OPEN }
RequestRaidInfo()
STUB.tick(1)
local own = AmisiaDB.raidcheck.own["Vulo Pala"]
assert(own and own.c == "PALADIN" and own.l == 52 and #own.ids == 2, "two locked IDs")
assert(own.ids[1].m == 409 and own.ids[1].k == 4 and own.ids[1].t == 10 and own.ids[1].d == 9, "the raid first")
assert(math.abs(own.ids[1].r - (STUB.now + 3 * DAY)) <= 1, "the reset as an epoch")
assert(own.ids[2].m == 36, "then the dungeon")
assert(AmisiaDB.raidcheck.names[409] == "Geschmolzener Kern", "the client's name")

-- 2. then Vulo Hunt logs in (the same account): Pala locked with bosses and reset, Hunt free
STUB.player, STUB.class, STUB.level = "Vulo Hunt", "HUNTER", 60
SAVED = {}
RequestRaidInfo()
STUB.tick(1)
assert(AmisiaDB.raidcheck.own["Vulo Hunt"] and #AmisiaDB.raidcheck.own["Vulo Hunt"].ids == 0)
NS.Set("ui.view", "officer")
assert(NS.RaidCheckAllowed())
local state, x, _, src = NS.RaidIDOf("Vulo Pala", 409)
assert(state == "locked" and x.k == 4 and src == "own", tostring(state))
assert(has(NS.RaidIDText(x), "4/10, Reset "), NS.RaidIDText(x))
assert(NS.RaidIDOf("Vulo Hunt", 409) == "free" and NS.RaidIDOf("Bob Eisherz", 409) == "unknown")
local inst = NS.RaidIDsInstances()
assert(#inst == 2 and inst[1].name == "Die Todesminen" and inst[2].m == 409 and inst[2].name == "Geschmolzener Kern", "as many IDs: by name")
assert(NS.RaidIDsChosen() == 36, "the first by default")
NS.RaidIDsChoose(409)
assert(NS.RaidIDsChosen() == 409, "the chosen one")
assert(NS.RaidIDsName(36) == "Die Todesminen" and NS.RaidIDsName(999) == "Instanz 999")
local lines = NS.RaidIDsOwnLines()
assert(#lines == 2 and has(lines[1], "Raid-IDs Vulo Hunt: keine") and has(lines[2], "Raid-IDs Vulo Pala: Geschmolzener Kern 4/10, Reset "), table.concat(lines, "\n"))

-- 3. the rows: the guild, grouped by main (the alt list), filters "nur frei" and "nur Stufe 60"
NS.ImportSiteText("#AMISIA-ALTS 1 forever 2026-10-12\nA Vulo_Pala Vulo_Hunt\nA Lia_Eisherz Bob_Eisherz\n#END")
local rows = NS.RaidIDsRows(409)
local order = {}
for _, r in ipairs(rows) do order[#order + 1] = r.n .. (r.alt and "+" or "") .. ":" .. r.state end
assert(table.concat(order, " ") == "Bob Eisherz:unknown Lia Eisherz+:unknown Kai Wind:unknown Vulo Hunt:free Vulo Pala+:locked",
    table.concat(order, " "))
rows = NS.RaidIDsRows(409, { free = true })
assert(#rows == 1 and rows[1].n == "Vulo Hunt", "only free")
rows = NS.RaidIDsRows(409, { top = true })
for _, r in ipairs(rows) do assert(r.n ~= "Vulo Pala", "level 52 is not 60") end
local free = NS.RaidIDFreeAlts("Vulo Pala", 409)
assert(#free == 1 and free[1] == "Vulo Hunt", "the main is free")

-- 4. after the reset the ID is gone (next login reads again; the view never shows an old one)
STUB.tick(3 * DAY + 10)
assert(NS.RaidIDOf("Vulo Pala", 409) == "free", "past the reset: free")
assert(#NS.RaidIDsInstances() == 1 and NS.RaidIDsInstances()[1].m ~= 409 or #NS.RaidIDsInstances() == 0)
STUB.tick(-1)

-- 5. what an officer takes from IV
local T = math.floor(STUB.now)
local function iv(char, ids, class, level) return { char, class or "WARRIOR", tostring(level or 60), ids or "-" } end
local id = ("409:9:%d:2/10"):format(T + 2 * DAY)
assert(NS.RaidIDsTake("Bob Eisherz", iv("Bob Eisherz", id)) == true, "a self report")
assert(NS.RaidIDOf("Bob Eisherz", 409) == "locked")
assert(NS.RaidIDsTake("Bob Eisherz", iv("Lia Eisherz", "-", "MAGE")) == true, "his alt (the same main)")
local _, _, rec, from = NS.RaidIDOf("Lia Eisherz", 409)
assert(from == "by" and rec.by == "Bob Eisherz", "laut Bob")
assert(NS.RaidIDsTake("Bob Eisherz", iv("Kim Fremd", id)) == false, "not in the guild roster")
assert(NS.RaidIDsTake("Bob Eisherz", iv("Vulo Pala", id)) == false, "the alt list gives Vulo Pala another main")
assert(NS.RaidIDsTake("Kai Wind", iv("Bob Eisherz", "-")) == false, "Bob's own report of the last 7 days wins")
assert(NS.RaidIDOf("Bob Eisherz", 409) == "locked")
assert(NS.RaidIDsTake("Lia Eisherz", iv("Lia Eisherz", id, "MAGE")) == true, "Lia's own word replaces Bob's")
assert(NS.RaidIDsTake("Bob Eisherz", iv("Lia Eisherz", "-", "MAGE")) == false, "and stays")
-- a reset too far ahead drops the whole message; one past its reset is left out
assert(NS.RaidIDsTake("Kai Wind", iv("Kai Wind", ("409:9:%d:1/10"):format(T + 40 * DAY), "HUNTER")) == false, "too far ahead")
assert(NS.RaidIDsTake("Kai Wind", iv("Kai Wind", ("409:9:%d:1/10,36:1:%d:1/5"):format(T - 10, T + DAY), "HUNTER")) == true)
assert(NS.RaidIDOf("Kai Wind", 409) == "free" and NS.RaidIDOf("Kai Wind", 36) == "locked", "the old one is left out")
-- 12 characters per sender
local letters = "ABCDEFGHIJKLMN"
for i = 1, 13 do
    STUB.guild[#STUB.guild + 1] = { name = "Twink " .. letters:sub(i, i) .. "bc", rank = 4, class = "ROGUE" }
end
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
local kept = 0
for i = 1, 13 do
    if NS.RaidIDsTake("Kai Wind", iv("Twink " .. letters:sub(i, i) .. "bc", "-", "ROGUE")) then kept = kept + 1 end
end
assert(kept == 11, "12 characters per sender (Kai already had his own): " .. kept)

-- 6. the load prunes
local now = math.floor(STUB.now)
AmisiaDB.raidcheck = {
    v = 1,
    own = {
        ["Vulo Pala"] = { at = now, c = "PALADIN", l = 52, ids = { { m = 409, d = 9, r = now - 5, k = 4, t = 10 },
                                                                            { m = 249, d = 9, r = now + DAY, k = 1, t = 1 } } },
        ["Alt Weg"] = { at = now - 61 * DAY, c = "MAGE", l = 60, ids = {} },
        ["Kaputt9"] = { at = now, ids = {} },
        ["Vulo Hunt"] = { at = "gestern", ids = {} },
    },
    heard = {
        ["Bob Eisherz"] = { by = "Bob Eisherz", at = now - DAY, c = "WARRIOR", l = 60, ids = { { m = 409, d = 9, r = now + DAY, k = 2, t = 10 } } },
        ["Lia Eisherz"] = { by = "Bob Eisherz", at = now - 31 * DAY, ids = {} },
        ["Kai Wind"] = { at = now, ids = {} },
    },
    names = { [409] = "Geschmolzener Kern", [0] = "x", [249] = "a|cbad" },
    stray = true,
}
for i = 1, 14 do AmisiaDB.raidcheck.own["Char " .. letters:sub(i, i) .. "x"] = { at = now - i, ids = {} } end
NS.RaidIDsLoaded(AmisiaDB)
local st = AmisiaDB.raidcheck
assert(st.stray == nil and st.v == 1)
assert(st.own["Vulo Pala"] and #st.own["Vulo Pala"].ids == 1 and st.own["Vulo Pala"].ids[1].m == 249, "the past ID is gone")
assert(not st.own["Alt Weg"] and not st.own["Kaputt9"] and not st.own["Vulo Hunt"], "60 days, a digit, a broken time")
local n = 0
for _ in pairs(st.own) do n = n + 1 end
assert(n == 12, "the 12 newest characters: " .. n)
assert(st.heard["Bob Eisherz"] and not st.heard["Lia Eisherz"] and not st.heard["Kai Wind"], "30 days; no sender")
assert(st.names[409] and not st.names[0] and not st.names[249], "bad names dropped")
-- twice without change
local function dump(t) return STUB.dump(t) end
local a = dump(st)
NS.RaidIDsLoaded(AmisiaDB)
assert(dump(AmisiaDB.raidcheck) == a, "a second load changes nothing")
-- 300 heard at most
AmisiaDB.raidcheck.heard = {}
for i = 1, 320 do
    local nm = "Name " .. string.char(65 + i % 26) .. string.char(97 + math.floor(i / 26) % 26) .. string.char(97 + math.floor(i / 676))
    AmisiaDB.raidcheck.heard[nm] = { by = nm, at = now - i, ids = {} }
end
NS.RaidIDsLoaded(AmisiaDB)
n = 0
for _ in pairs(AmisiaDB.raidcheck.heard) do n = n + 1 end
assert(n == 300, "300 heard: " .. n)

-- 7. the raider view keeps nothing heard; the page's question needs the officer
NS.Set("ui.view", "raider")
local ok, why = NS.RaidIDsAsk()
assert(ok == nil and has(why, "nur für Offiziere"))

-- 8. the login's report: every character of the account to the guild, not again within 30 minutes
-- (a /reload); a new ID or boss: the logged-in character, at most every 5 minutes; a boss kill asks
-- the client after the fight
NS.Set("ui.view", "officer")
STUB.player, STUB.class, STUB.level = "Vulo Hunt", "HUNTER", 60
SAVED = {}
AmisiaDB.raidcheck.sent = nil
STUB.addon = {}
local function ivs(who)
    local k = 0
    for _, m in ipairs(STUB.addon) do
        if m.text:find("^1IV\t") and (not who or m.text:find("^1IV\t" .. who .. "\t")) then k = k + 1 end
    end
    return k
end
NS.RaidIDsLogin()
STUB.tick(5)
local mine = 0
for _ in pairs(AmisiaDB.raidcheck.own) do mine = mine + 1 end
assert(ivs() == mine and mine == 12, "every character of the account: " .. ivs())
assert(AmisiaDB.raidcheck.sent ~= nil)
NS.RaidIDsLogin()
STUB.tick(5)
assert(ivs() == mine, "not again within 30 minutes")
local mc = { unpack(MC) }
SAVED = { mc }
RequestRaidInfo()
STUB.tick(1)
assert(ivs("Vulo Hunt") == 2, "a new ID goes out")
local text = STUB.addon[#STUB.addon].text
assert(text:find("^1IV\tVulo Hunt\tHUNTER\t60\t409:9:%d+:4/10$"), text)
mc[12] = 5
RequestRaidInfo()
STUB.tick(1)
assert(ivs("Vulo Hunt") == 2, "the next boss waits (5 minutes)")
STUB.tick(300)
assert(ivs("Vulo Hunt") == 3 and STUB.addon[#STUB.addon].text:find(":5/10$"), "then it goes")
RequestRaidInfo()
STUB.tick(1)
assert(ivs("Vulo Hunt") == 3, "no change, nothing sent")
-- a boss kill in combat: the client is asked after the fight
asked = 0
STUB.combat = true
STUB.fire("BOSS_KILL", 663, "Lucifron")
STUB.tick(6)
assert(asked == 0, "not in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(1)
assert(asked == 1, "after the fight")
-- raidcheck.lockouts off: nothing sent
NS.Set("raidcheck.lockouts", false)
AmisiaDB.raidcheck.sent = nil
NS.RaidIDsLogin()
STUB.tick(5)
assert(ivs("Vulo Hunt") == 3, "off: nothing")
NS.Set("raidcheck.lockouts", true)
