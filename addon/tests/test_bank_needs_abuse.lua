--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Guild bank needs against a hostile or unlucky member: a flood of pledges for materials nobody
-- needs pushes out no real pledge and spams no officer; the pledges of one name are capped and the
-- overflow goes from the name with the most; a cleared list reaches a member who missed the
-- clearing; a revision far in the future is refused; the export mark covers a revision that ran
-- ahead of the clock.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
C(KIM, "STUB.officer = false")
for _, name in ipairs(CLIENTS) do
    C(name, [[
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.item(61001, "Feuerkern", 3)
        AmisiaDB.mats[61001] = { name = "Feuerkern", q = 3, first = 1 }
        NS.RebuildMats()
        return true]])
end
BUS.tick(1)
C(VULO, "NS.SetBankNeed(61001, 40, 80)")
BUS.tick(3)
assert(C(KIM, "NS.BankNeeds().list[61001] ~= nil"), "Kim has the need")

---------------------------------------------------------------------------
-- a pledge flood for materials without a need
---------------------------------------------------------------------------
C(FRAK, "NS.PledgeBankNeed(61001, 10)")
BUS.tick(3)
assert(C(VULO, "#NS.BankPledgeList()") == 1)
local lines0 = C(VULO, "#STUB.messages")
for i = 1, 200 do
    C(KIM, ("NS.CommSend('GP', { '%d', '1', tostring(math.floor(STUB.now)) }, 'GUILD')"):format(70000 + i))
    if i % 10 == 0 then BUS.tick(11) end
end
BUS.tick(15)
local list = C(VULO, "return NS.BankPledgeList()")
assert(#list == 1 and list[1].name == FRAK, "the real pledge stays, the flood is dropped: " .. #list)
assert(not C(VULO, "NS.ExportText({})"):find("\nBP 7", 1, true), "no flood in the export")
-- one chat line per pledger and minute
C(KIM, "NS.PledgeBankNeed(61001, 3)")
BUS.tick(2)
C(KIM, "NS.PledgeBankNeed(61001, 4)")
BUS.tick(2)
C(KIM, "NS.PledgeBankNeed(61001, 5)")
BUS.tick(2)
local said = C(VULO, ("local n = 0; for i = %d + 1, #STUB.messages do if STUB.messages[i]:find('Kim Eisherz sagt', 1, true) then n = n + 1 end end; return n"):format(lines0))
assert(said == 1, "one line in the minute: " .. said)
assert(C(VULO, "NS.BankPledgeList()[2].count") == 5 or C(VULO, "NS.BankPledgeList()[1].count") == 5, "the pledge itself is kept")
-- a need taken away takes its pledges with it
BUS.tick(60)
C(VULO, "NS.SetBankNeed(61001, 0, 0)")
assert(C(VULO, "#NS.BankPledgeList()") == 0, "no need, no pledges")
BUS.tick(5)
assert(C(KIM, "#NS.BankPledgeList()") == 0, "at the members too")

---------------------------------------------------------------------------
-- the overflow goes from the name with the most pledges
---------------------------------------------------------------------------
C(VULO, [[for i = 1, 40 do
    STUB.item(62000 + i, "Stoff " .. i, 2)
    AmisiaDB.mats[62000 + i] = { name = "Stoff " .. i, q = 2, first = 10 + i }
end
NS.RebuildMats()
for i = 1, 40 do assert(NS.SetBankNeed(62000 + i, i)) end
local p, t = {}, math.floor(STUB.now)
p[1] = { name = "Anna Alt", item = 62001, count = 1, t = t - 3600 }
for k, who in ipairs({ "Bea Eins", "Cid Zwei", "Dan Drei", "Eva Vier", "Flut Fuenf", "Gus Sechs" }) do
    for i = 1, 40 do p[#p + 1] = { name = who, item = 62000 + i, count = 1, t = t - k } end
end
p[#p + 1] = { name = "Flut Fuenf", item = 99999, count = 1, t = t }   -- no need
AmisiaDB.bankPledges = p]])
local per = C(VULO, [[local per = {}
    for _, p in ipairs(NS.BankPledgeList()) do per[p.name] = (per[p.name] or 0) + 1 end
    return per]])
local total = 0
for _, n in pairs(per) do total = total + n end
assert(total == 200, "200 at most: " .. total)
assert(per["Anna Alt"] == 1, "the small pledger keeps hers")
for _, who in ipairs({ "Bea Eins", "Cid Zwei", "Dan Drei", "Eva Vier", "Flut Fuenf", "Gus Sechs" }) do
    assert(per[who] >= 33 and per[who] <= 34, who .. " " .. tostring(per[who]))
end
C(VULO, "AmisiaDB.bankPledges = {}; for i = 1, 40 do NS.SetBankNeed(62000 + i, 0) end")
BUS.tick(5)

---------------------------------------------------------------------------
-- a cleared list reaches a member who missed the clearing
---------------------------------------------------------------------------
C(VULO, "NS.SetBankNeed(61001, 40, 80)")
BUS.tick(5)
assert(C(KIM, "NS.BankNeeds().list[61001] ~= nil"))
BUS.drop(function(m) return m.kind == "GN" end)
BUS.tick(5)
C(VULO, "NS.SetBankNeed(61001, 0, 0)")
BUS.tick(5)
BUS.drop(nil)
assert(C(VULO, "next(NS.BankNeeds().list) == nil") and C(KIM, "NS.BankNeeds().list[61001] ~= nil"))
BUS.tick(40)
C(KIM, "NS.AskBankNeeds()")
BUS.tick(20)
assert(BUS.count(function(m) return m.kind == "GN" and m.chan == "WHISPER" and m.target == KIM end) >= 1, "an officer answers")
assert(C(KIM, "next(NS.BankNeeds().list) == nil"), "the empty list arrived")
assert(C(KIM, "NS.BankNeeds().rev") == C(VULO, "NS.BankNeeds().rev"))

---------------------------------------------------------------------------
-- a revision far in the future is refused; a stored one is clamped at load
---------------------------------------------------------------------------
local rev0 = C(KIM, "NS.BankNeeds().rev")
C(VULO, [[NS.CommSend("GN", { tostring(math.floor(STUB.now) + 3 * 86400), "1", "1", "Vulo_Sturmwind", "61001:5:0" }, "GUILD")]])
BUS.tick(5)
assert(C(KIM, "NS.BankNeeds().rev") == rev0 and C(KIM, "next(NS.BankNeeds().list) == nil"), "a revision three days ahead")
assert(C(KIM, [[AmisiaDB.bankNeeds.rev = math.floor(STUB.now) + 9 * 86400
    NS.BankNeedsLoaded(AmisiaDB)
    return NS.BankNeeds().rev <= math.floor(STUB.now) + 86400]]), "clamped at load")

---------------------------------------------------------------------------
-- the export mark: a revision ahead of the clock is covered
---------------------------------------------------------------------------
assert(C(VULO, [[for i = 1, 5 do assert(NS.SetBankNeed(61001, 10 + i, 0)) end
    assert(NS.BankNeeds().rev > math.floor(time()))
    NS.MarkExported({})
    return NS.BankNeedsPending() == false]]), "nothing pending right after the export")
assert(C(VULO, "STUB.now = STUB.now + 3600; return NS.BankNeedsPending() == false"), "nor an hour later")

---------------------------------------------------------------------------
-- the "set by" field: no escape bars, no control characters
---------------------------------------------------------------------------
local bad0 = C(KIM, "NS.CommStats().bad")
BUS.tick(40)
C(VULO, [[C_ChatInfo.SendAddonMessage("Amisia", "1GN\t" .. (math.floor(STUB.now) + 60) .. "\t1\t1\tVulo|cffff0000\t61001:5:0", "GUILD")]])
BUS.tick(5)
C(VULO, [[C_ChatInfo.SendAddonMessage("Amisia", "1GN\t" .. (math.floor(STUB.now) + 61) .. "\t1\t1\tVulo\1x\t61001:5:0", "GUILD")]])
BUS.tick(5)
assert(C(KIM, "NS.CommStats().bad") == bad0 + 2 and C(KIM, "NS.BankNeeds().list[61001] == nil or NS.BankNeeds().list[61001].min ~= 5"),
    "a set-by field with a bar or a control character is refused")
