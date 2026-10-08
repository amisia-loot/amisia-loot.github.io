--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Guild bank needs: officers set a minimum (and a target) per material, the list goes to the guild
-- through addon messages and only an officer's list counts; members pledge donations, the pledges
-- reach the officers and expire; a text of the shortfalls for the chat or Discord; the BQ and BP
-- lines of the export; asking for the list after a login.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
C(KIM, "STUB.officer = false")
for _, name in ipairs(CLIENTS) do
    C(name, [[
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.item(61001, "Feuerkern", 3); STUB.item(61002, "Runenstoff", 1)
        AmisiaDB.mats[61001] = { name = "Feuerkern", q = 3, first = 1 }
        AmisiaDB.mats[61002] = { name = "Runenstoff", q = 1, first = 2 }
        NS.RebuildMats()
        AmisiaDB.bank = { at = STUB.now - 600, counts = { [61001] = 12, [61002] = 80 }, tabs = 1, filled = 1, total = 1, by = "Vulo Sturmwind" }
        return true]])
end
BUS.tick(1)

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local days = C(KIM, "local it = NS.SettingItem('bank.pledgeDays'); return { it.type, it.default, it.min, it.max }")
assert(days[1] == "slider" and days[2] == 7 and days[3] == 1 and days[4] == 30, "pledges expire after 7 days by default")

---------------------------------------------------------------------------
-- an officer sets a need; the guild gets it
---------------------------------------------------------------------------
local ok, why = C(VULO, "return NS.SetBankNeed(61001, 40, 80)")
assert(ok == true, tostring(why))
assert(C(VULO, "NS.BankNeeds().list[61001].min") == 40 and C(VULO, "NS.BankNeeds().list[61001].target") == 80)
assert(BUS.count({ kind = "GN", sender = VULO }) == 0, "the list goes out a moment later (several changes, one message)")
C(VULO, "NS.SetBankNeed(61001, 40, 80)")
BUS.tick(3)
assert(BUS.count({ kind = "GN", sender = VULO, chan = "GUILD" }) == 1, "one message to the guild")
for _, name in ipairs({ FRAK, KIM }) do
    local n = C(name, "local e = NS.BankNeeds().list[61001]; return e and { e.min, e.target or 0, NS.BankNeeds().by }")
    assert(n and n[1] == 40 and n[2] == 80 and n[3] == VULO, name .. " has the need")
end
-- a member cannot set one
ok, why = C(KIM, "return NS.SetBankNeed(61002, 10)")
assert(ok == false and has(why, "Offiziere"), tostring(why))
-- bad values are refused
assert(C(VULO, "return (NS.SetBankNeed(61001, 50, 20))") == false, "the target is not below the minimum")
assert(C(VULO, "return (NS.SetBankNeed('x', 5))") == false and C(VULO, "return (NS.SetBankNeed(61001, -1))") == false)

-- a list sent by a member counts nowhere
C(KIM, "NS.CommSend('GN', { tostring(STUB.now + 100), '1', '1', 'Kim_Eisherz', '61002:999:0' }, 'GUILD')")
BUS.tick(2)
assert(C(FRAK, "NS.BankNeeds().list[61002] == nil") and C(VULO, "NS.BankNeeds().list[61002] == nil"), "only officers' lists count")

-- a second officer changes the list later: everybody takes the newer one
BUS.tick(5)
assert(C(FRAK, "return (NS.SetBankNeed(61002, 100))") == true)
BUS.tick(3)
for _, name in ipairs({ VULO, KIM }) do
    assert(C(name, "NS.BankNeeds().list[61002] and NS.BankNeeds().list[61002].min") == 100, name)
    assert(C(name, "NS.BankNeeds().list[61001].min") == 40, "the rest of the list stays: " .. name)
    assert(C(name, "NS.BankNeeds().by") == FRAK)
end
-- an older list never rolls a newer one back
C(VULO, "NS.CommSend('GN', { tostring(NS.BankNeeds().rev - 50), '1', '1', 'Vulo_Sturmwind', '61001:1:0' }, 'GUILD')")
BUS.tick(2)
assert(C(KIM, "NS.BankNeeds().list[61001].min") == 40, "older list ignored")

---------------------------------------------------------------------------
-- shortfalls: have vs need, with the level for the colour
---------------------------------------------------------------------------
local rows = C(KIM, "return NS.BankNeedList()")
assert(#rows == 2, #rows)
assert(rows[1].id == 61001 and rows[1].have == 12 and rows[1].short == 28 and rows[1].level == "low", "below the minimum")
assert(rows[2].id == 61002 and rows[2].have == 80 and rows[2].short == 20 and rows[2].level == "low")
C(KIM, "AmisiaDB.bank.counts[61002] = 120")
rows = C(KIM, "return NS.BankNeedList()")
assert(rows[2].short == 0 and rows[2].level == "ok", "enough")
C(KIM, "AmisiaDB.bank.counts[61001] = 50")
rows = C(KIM, "return NS.BankNeedList()")
assert(rows[1].short == 30 and rows[1].level == "target", "above the minimum, below the target")
C(KIM, "AmisiaDB.bank.counts[61001] = 12; AmisiaDB.bank.counts[61002] = 80")
-- no count yet: unknown, not short
local none = C(FRAK, "local b = AmisiaDB.bank; AmisiaDB.bank = nil; local r = NS.BankNeedList(); AmisiaDB.bank = b; return r")
assert(none[1].have == nil and none[1].level == "unknown", "no count")

---------------------------------------------------------------------------
-- pledges
---------------------------------------------------------------------------
ok, why = C(KIM, "return NS.PledgeBankNeed(61001, 15)")
assert(ok == true, tostring(why))
BUS.tick(2)
assert(BUS.count({ kind = "GP", sender = KIM, chan = "GUILD" }) == 1, "the pledge goes to the guild")
for _, name in ipairs({ VULO, FRAK, KIM }) do
    local p = C(name, "return NS.BankPledgeList()")
    assert(#p == 1 and p[1].name == KIM and p[1].item == 61001 and p[1].count == 15, name .. " lists the pledge")
end
assert(C(VULO, "NS.BankNeedList()[1].pledged") == 15, "pledged on the row")
assert(has(C(VULO, "table.concat(STUB.messages, '\\n')"), "Kim Eisherz sagt 15 Feuerkern für die Gildenbank zu."), "the officer is told")
-- a pledge only for a needed material, a sane count
assert(C(KIM, "return (NS.PledgeBankNeed(4242, 3))") == false, "no need, no pledge")
assert(C(KIM, "return (NS.PledgeBankNeed(61001, 0.5))") == false)
-- a new pledge for the same material replaces the old
C(KIM, "NS.PledgeBankNeed(61001, 20)")
BUS.tick(2)
assert(C(VULO, "#NS.BankPledgeList()") == 1 and C(VULO, "NS.BankPledgeList()[1].count") == 20, "replaced")
-- withdrawn: gone everywhere
C(KIM, "NS.PledgeBankNeed(61001, 0)")
BUS.tick(2)
assert(C(VULO, "#NS.BankPledgeList()") == 0 and C(KIM, "#NS.BankPledgeList()") == 0, "withdrawn")
-- a pledge from somebody the officer's roster does not know is dropped
C(VULO, [[STUB.guild = { { name = "Vulo Sturmwind", rank = 1, online = true, class = "PRIEST" }, { name = "Fraktur", rank = 2, online = true, class = "PRIEST" } }
    STUB.fire("GUILD_ROSTER_UPDATE")]])
BUS.tick(12)
C(KIM, "NS.PledgeBankNeed(61001, 9)")
BUS.tick(3)
assert(C(VULO, "#NS.BankPledgeList()") == 0, "only guild members pledge")
assert(C(FRAK, "#NS.BankPledgeList()") == 1, "the other officer knows Kim")
C(KIM, "NS.PledgeBankNeed(61001, 0)")
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
C(VULO, "STUB.fire('GUILD_ROSTER_UPDATE')")
BUS.tick(12)
C(KIM, "NS.PledgeBankNeed(61001, 10)")
BUS.tick(2)
assert(C(VULO, "#NS.BankPledgeList()") == 1)
-- the officer ticks a pledge off: local only
C(VULO, "NS.RemovePledge('Kim Eisherz', 61001)")
assert(C(VULO, "#NS.BankPledgeList()") == 0 and C(KIM, "#NS.BankPledgeList()") == 1, "ticked off on the officer's side only")

---------------------------------------------------------------------------
-- asking after a login: members get the list from an officer, officers get the members' pledges
---------------------------------------------------------------------------
C(KIM, "AmisiaDB.bankNeeds = nil; NS.BankNeedsLoaded(AmisiaDB)")
assert(C(KIM, "next(NS.BankNeeds().list) == nil"), "forgotten")
C(KIM, "NS.AskBankNeeds()")
BUS.tick(10)
assert(BUS.count({ kind = "GQ", sender = KIM, chan = "GUILD" }) >= 1)
assert(C(KIM, "NS.BankNeeds().list[61001] and NS.BankNeeds().list[61001].min") == 40, "an officer answered with the list")
assert(BUS.count(function(m) return m.kind == "GN" and m.chan == "WHISPER" and m.target == KIM end) >= 1, "by whisper")
-- the officer asks: Kim's own pledge comes back to him
C(VULO, "NS.AskBankNeeds()")
BUS.tick(10)
local p = C(VULO, "return NS.BankPledgeList()")
assert(#p == 1 and p[1].name == KIM and p[1].count == 10, "the member sends their pledge again")

---------------------------------------------------------------------------
-- the copy text and the export lines
---------------------------------------------------------------------------
local text = C(KIM, "NS.BankNeedText()")
assert(has(text, "Feuerkern: 12 von 40") and has(text, "fehlen 28") and has(text, "zugesagt 10"), text)
assert(has(text, "Runenstoff: 80 von 100"), text)
local ex = C(VULO, "NS.ExportText({})"):gsub("\\n", "\n")
local rev = C(VULO, "NS.BankNeeds().rev")
assert(has(ex, "\nBQ 61001 40 80 " .. rev .. " Fraktur\n"), ex)
assert(has(ex, "\nBQ 61002 100 0 " .. rev .. " Fraktur\n"), ex)
assert(ex:find("\nBP 61001 10 %d+ Kim_Eisherz\n"), ex)
assert(ex:find("\nN 61001 %d Feuerkern\n"), "the needed items are named: " .. ex)

---------------------------------------------------------------------------
-- pledges expire
---------------------------------------------------------------------------
C(VULO, "STUB.now = STUB.now + 8 * 86400")
assert(C(VULO, "#NS.BankPledgeList()") == 0, "older than 7 days")

---------------------------------------------------------------------------
-- a long list goes in parts; a lost part keeps the old list
---------------------------------------------------------------------------
BUS.tick(5)
C(VULO, [[for i = 1, 25 do
    STUB.item(62000 + i, "Stoff " .. i, 2)
    AmisiaDB.mats[62000 + i] = { name = "Stoff " .. i, q = 2, first = 10 + i }
end
NS.RebuildMats()
for i = 1, 25 do NS.SetBankNeed(62000 + i, i) end]])
BUS.tick(3)
local parts = BUS.count(function(m) return m.kind == "GN" and m.sender == VULO and m.chan == "GUILD" and m.text:find("^1GN\t%d+\t%d\t4\t") end)
assert(parts == 4, "27 entries go in four parts of 8: " .. parts)
assert(C(KIM, "local n = 0; for _ in pairs(NS.BankNeeds().list) do n = n + 1 end; return n") == 27, "all parts arrived")
BUS.tick(5)
BUS.drop(function(m) return m.kind == "GN" and m.text:find("^1GN\t%d+\t2\t4\t") end)
C(VULO, "NS.SetBankNeed(62001, 0)")
BUS.tick(3)
BUS.drop(nil)
assert(C(KIM, "NS.BankNeeds().list[62001] ~= nil"), "an incomplete list is not taken")
-- 0 removes a need; the removal reaches the guild
BUS.tick(5)
C(VULO, "NS.SetBankNeed(62002, 0)")
BUS.tick(3)
assert(C(KIM, "NS.BankNeeds().list[62001] == nil and NS.BankNeeds().list[62002] == nil"), "removed")
-- every need taken out: the empty list reaches the guild, and the export says so (BQ with item 0)
BUS.tick(5)
C(VULO, "for id in pairs(NS.BankNeeds().list) do NS.SetBankNeed(id, 0) end")
BUS.tick(3)
assert(C(KIM, "next(NS.BankNeeds().list) == nil"), "the empty list arrived")
local empty = C(VULO, "NS.ExportText({})"):gsub("\\n", "\n")
assert(empty:find("\nBQ 0 0 0 %d+ Vulo_Sturmwind\n") and not empty:find("\nBP "), empty)
