--[[clients Vulo_Sturmwind Anna_Amboss]]
-- F-242 (D-177): who of the guild holds the reagents that bind when picked up. Anna holds 3 Demonic Runes in her bank
-- and her alt Anna Zwei 2 Blood of Heroes (prof.bags); 60-180 s after her login PB tells the guild, Vulo keeps both
-- and shows them (holders, text, tooltip line). Vulo holds nothing and says nothing. Anna uses her runes: her next PB
-- (at most every 5 minutes) drops her from Vulo's list; nothing held any more: "1" clears it all. A message with an
-- item outside the list, a count of 0 or 8 items is dropped whole; an own character is never taken; sharing off
-- sends nothing; the load check.
local VULO, ANNA = "Vulo Sturmwind", "Anna Amboss"
local RUNE, BLOOD = 12662, 12938
local ME = { [VULO] = "a0010001", [ANNA] = "0b200002" }
BUS.setGuild({ { name = VULO, rank = 1 }, { name = ANNA, rank = 3 }, { name = "Anna Zwei", rank = 4 } })
BUS.guild = { VULO, ANNA }
for _, name in ipairs(CLIENTS) do
    C(name, ([[dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
        STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        NS.PROF_BOP = { [12662] = true, [12938] = true }
        NS.CRAFTERS_LIMITS.helloMin = 1e9
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
local D = C(ANNA, "NS.DropsToday()")
C(ANNA, ([[STUB.bank[12662] = 3
    local g = GetGuildInfo("player")
    AmisiaDB.account = AmisiaDB.account or {}
    AmisiaDB.account.chars = AmisiaDB.account.chars or {}
    AmisiaDB.account.chars["Anna Amboss"] = { guild = g, level = 60 }
    AmisiaDB.account.chars["Anna Zwei"] = { guild = g, level = 40 }
    AmisiaDB.prof = AmisiaDB.prof or { chars = {} }
    AmisiaDB.prof.bags = { ["Anna Zwei"] = { day = %d, realm = "Kargath", faction = "A", items = { [12938] = 2 } } }]]):format(D))

-- Anna's own counts
local own = C(ANNA, "NS.ProfBound.Own()")
assert(#own == 2 and own[1].name == ANNA and own[1].items[RUNE] == 3 and own[2].name == "Anna Zwei" and own[2].items[BLOOD] == 2,
    "the current character live, the alt from prof.bags")
assert(C(ANNA, "NS.ProfBound.Holders(12938)[1].own") == true, "her alt is hers")
assert(C(ANNA, "NS.ProfBound.Text(12938, 4)") == "Anna Zwei 2 (Twink)")

-- the first PB, 60-180 s after the login
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_ENTERING_WORLD')") end
BUS.tick(55)
assert(BUS.count({ kind = "PB" }) == 0, "not in the first minute")
BUS.tick(140)
assert(BUS.count({ kind = "PB", sender = ANNA, chan = "GUILD" }) == 1, "Anna tells the guild")
assert(BUS.count({ kind = "PB", sender = VULO }) == 0, "Vulo holds nothing: silent")
local h = C(VULO, "NS.ProfBound.Holders(12662)")
assert(#h == 1 and h[1].name == ANNA and h[1].n == 3 and h[1].online == true, "Vulo sees Anna's runes")
assert(C(VULO, "NS.ProfBound.Holders(12938)[1].name") == "Anna Zwei", "and her alt's blood")
assert(C(VULO, "NS.ProfBound.TooltipLine(12662)") == "Gebunden in der Gilde: Anna Amboss 3", C(VULO, "NS.ProfBound.TooltipLine(12662)"))
assert(C(VULO, "NS.ProfBound.TooltipLine(2589)") == nil, "linen does not bind")
local reag = C(VULO, "NS.ProfBound.ForReagents({ { 2589, 2 }, { 12662, 1 } })")
assert(#reag == 1 and reag[1].item == RUNE, "only the bound reagent of a recipe")

-- the same again: nothing new, nothing sent
local t0 = C(ANNA, "STUB.clock")
C(ANNA, "STUB.fire('BAG_UPDATE_DELAYED')")
BUS.tick(400)
assert(BUS.count({ kind = "PB", sender = ANNA, from = t0 }) == 0, "unchanged: silent")

-- Anna uses her runes (the bank count holds until she sees her bank again): gone at Vulo's within 5 minutes
C(ANNA, "STUB.bank[12662] = nil; STUB.fire('BANKFRAME_OPENED'); STUB.fire('BANKFRAME_CLOSED')")
BUS.tick(320)
assert(#C(VULO, "NS.ProfBound.Holders(12662)") == 0, "the runes are gone")
assert(#C(VULO, "NS.ProfBound.Holders(12938)") == 1, "the alt's blood stays")
-- nothing held any more: "1" clears it
C(ANNA, "AmisiaDB.prof.bags['Anna Zwei'].items = {}; STUB.fire('BAG_UPDATE_DELAYED')")
BUS.tick(320)
assert(#C(VULO, "NS.ProfBound.Holders(12938)") == 0, "all gone")
assert(C(ANNA, "AmisiaDB.prof.bopSent") == nil, "the last PB said nothing")

-- bad messages drop whole; an own character is never taken
assert(C(VULO, "NS.ProfBound.Take('Anna Amboss', { '1', 'Anna Amboss:12662=1', 'Anna Zwei:2589=1' })") == -1, "linen")
assert(C(VULO, "NS.ProfBound.Take('Anna Amboss', { '1', 'Anna Amboss:12662=0' })") == -1, "count 0")
assert(C(VULO, "NS.ProfBound.Take('Anna Amboss', { '1', 'Anna Amboss:12662=1000' })") == -1, "count 1000")
assert(C(VULO, "NS.ProfBound.Take('Anna Amboss', { '1', 'Anna Amboss:12662=1,12662=2' })") == -1, "an item twice")
assert(#C(VULO, "NS.ProfBound.Holders(12662)") == 0, "nothing stored")
assert(C(VULO, "NS.ProfBound.Take('Anna Amboss', { '1', 'Vulo Sturmwind:12662=5' })") == 0, "never an own character")
-- another sender cannot replace a character's own report
C(VULO, "NS.ProfBound.Take('Anna Amboss', { '1', 'Anna Amboss:12662=2' })")
assert(C(VULO, "NS.ProfBound.Take('Anna Zwei', { '1', 'Anna Amboss:12662=9' })") == 0, "Anna's own word stays")
assert(C(VULO, "NS.ProfBound.Holders(12662)[1].n") == 2)

-- sharing off: nothing goes
C(ANNA, "NS.Set('prof.bopShare', false); STUB.bank[12662] = 4; STUB.fire('BAG_UPDATE_DELAYED')")
local t1 = C(ANNA, "STUB.clock")
BUS.tick(400)
assert(BUS.count({ kind = "PB", sender = ANNA, from = t1 }) == 0, "sharing off")

-- the load check: only bound items, counts 1-999, a sender, 14 days
C(VULO, ([[local t = math.floor(time())
    AmisiaDB.prof.bopHeard["Bert"] = { by = "Bert", at = t, [12662] = 2, [2589] = 4, x = 1 }
    AmisiaDB.prof.bopHeard["Cleo"] = { by = "Cleo", at = t - 15 * 86400, [12662] = 1 }
    AmisiaDB.prof.bopHeard["Dora"] = { by = "Dora", at = t, [12662] = 0 }
    AmisiaDB.prof.bopSent = "ja"
    NS.ProfBoundLoaded(AmisiaDB)]]))
local heard = C(VULO, "AmisiaDB.prof.bopHeard")
assert(heard.Bert and heard.Bert[12662] == 2 and heard.Bert[2589] == nil and heard.Bert.x == nil, "only bound items")
assert(heard.Cleo == nil and heard.Dora == nil, "too old, count 0")
assert(C(VULO, "AmisiaDB.prof.bopSent") == nil)
print("prof bound ok")
