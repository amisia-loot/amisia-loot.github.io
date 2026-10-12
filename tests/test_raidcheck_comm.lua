--[[clients Vulo_Hunt Vulo_Pala Bob_Eisherz Kim_Fremd]]
-- The raid check and the raid IDs between clients (XQ/XA, IV/IQ; Raid/RaidCheck.lua, Raid/RaidIDs.lua,
-- Core/Comm.lua): an officer's "Prüfen" is answered by every Amisia of the raid within a few seconds
-- and only the officer view keeps the answers (a raider keeps nothing, an outsider's answer is
-- dropped); a member's question is not answered; two officers asking within 10 s get one answer per
-- raider; malformed answers and a second one within 10 s are dropped; the ready check brings one
-- answer by itself, none in the lockdown. Raid IDs: every character of an account goes to the guild;
-- an officer's question is answered by whisper (once in 10 minutes), a member's is not; forged and
-- foreign characters, an alt of another main and a reset too far ahead are dropped; raiders keep none.
local HUNT, PALA, BOB, KIM = "Vulo Hunt", "Vulo Pala", "Bob Eisherz", "Kim Fremd"

BUS.setGuild({ { name = HUNT, rank = 2 }, { name = PALA, rank = 3 }, { name = BOB, rank = 1 }, { name = "Lia Pala", rank = 4 } })
BUS.setRaid({ HUNT, PALA, BOB, KIM })
for _, name in ipairs(CLIENTS) do
    C(name, [[
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Hunt" or STUB.player == "Bob Eisherz"
        STUB.class = ({ ["Vulo Hunt"] = "HUNTER", ["Vulo Pala"] = "PALADIN", ["Bob Eisherz"] = "WARRIOR", ["Kim Fremd"] = "MAGE" })[STUB.player]
        STUB.level = 60
        STUB.fire("PLAYER_ENTERING_WORLD")
        return true]])
end
C(KIM, "STUB.inGuild = false")
BUS.tick(12)
C(HUNT, "NS.Set('ui.view', 'officer')")
C(BOB, "NS.Set('ui.view', 'raider')")
assert(C(HUNT, "NS.RaidCheckAllowed()") == true, "Hunt is an officer")
assert(C(PALA, "NS.RaidCheckAllowed()") == false and C(BOB, "NS.RaidCheckAllowed()") == false, "Pala no officer, Bob in the raider view")

local function answers(name) return C(name, "local n = {} for k in pairs(NS._raidcheck.answers()) do n[#n + 1] = k end table.sort(n) return table.concat(n, ',')") end

-- 1. "Prüfen": every Amisia of the raid answers within a few seconds; only the officer keeps them
local ok = C(HUNT, "return NS.RaidCheck.Ask()")
assert(ok == true)
BUS.tick(5)
assert(BUS.count({ kind = "XQ", sender = HUNT, chan = "RAID" }) == 1)
for _, n in ipairs({ PALA, BOB }) do
    assert(BUS.count({ kind = "XA", sender = n, chan = "RAID" }) == 1, n .. " answers")
end
assert(BUS.count({ kind = "XA", sender = KIM }) == 0, "outside the guild the officer cannot be checked: no answer")
C(KIM, "return NS.CommSend('XA', { '-', '90', '0', '600', '-', '-', '0', 'F' }, 'RAID')")
BUS.tick(2)
assert(answers(HUNT) == "bob eisherz,vulo pala", "an outsider's answer is dropped: " .. answers(HUNT))
assert(answers(BOB) == "" and answers(PALA) == "", "raiders keep nothing")
-- the answer as the officer sees it
local rep = C(HUNT, "local a = NS.RaidCheck.AnswerOf('Vulo Pala') return a and (tostring(a.dur) .. ' ' .. a.below .. ' ' .. tostring(a.ilvl)) or false")
assert(rep == "nil 0 nil", "Pala's stub has no durability or item level: " .. tostring(rep))

-- 2. a member's question is not answered
BUS.tick(11)
C(PALA, "return NS.CommSend('XQ', { 'beef' }, 'RAID')")
BUS.tick(5)
assert(BUS.count({ kind = "XA", sender = BOB }) == 1 and BUS.count({ kind = "XA", sender = HUNT }) == 0, "nobody answers Pala")

-- 3. two officers within 10 s: one answer per raider
BUS.tick(11)
C(BOB, "NS.Set('ui.view', 'officer')")
C(HUNT, "return NS.RaidCheck.Ask()")
BUS.tick(2)
C(BOB, "return NS.RaidCheck.Ask()")
BUS.tick(5)
assert(BUS.count({ kind = "XQ" }) == 4, "both asked (and Pala's)")
assert(BUS.count({ kind = "XA", sender = PALA }) == 2, "Pala answered the two officers once")
assert(C(BOB, "NS._raidcheck.answers()['vulo pala'] ~= nil"), "both officers see the answer (RAID)")
C(BOB, "NS.Set('ui.view', 'raider')")

-- 4. malformed answers and a second one within 10 s are dropped
local function sendXA(fields)
    local list = {}
    for _, f in ipairs(fields) do list[#list + 1] = ("%q"):format(f) end
    C(PALA, ("return NS.CommSend('XA', { %s }, 'RAID')"):format(table.concat(list, ", ")))
end
local function palaDur() return C(HUNT, "local a = NS._raidcheck.answers()['vulo pala'] return a and a.dur or false") end
BUS.tick(11)
for _, bad in ipairs({
    { "-", "101", "0", "600", "-", "-", "0", "-" },   -- durability over 100
    { "-", "50", "20", "600", "-", "-", "0", "-" },   -- 20 under the threshold
    { "-", "50", "0", "x", "-", "-", "0", "-" },      -- item level
    { "-", "50", "0", "600", "20", "-", "0", "-" },   -- slot 20
    { "-", "50", "0", "600", "-", "-", "100", "-" },  -- free points
    { "-", "50", "0", "600", "-", "-", "0", "E0" },   -- no elixir is not "E0"
    { "-", "50", "0", "600", "-", "-", "0", "WF" },   -- order
    { "zz", "50", "0", "600", "-", "-", "0", "-" },   -- question id
    { "-", "50", "0", "600", "-", "-", "0" },         -- a field missing
}) do
    sendXA(bad)
    BUS.tick(11)
end
assert(palaDur() == false, "nothing malformed taken")
sendXA({ "-", "44", "1", "602", "2,3", "8", "3", "FE2W" })
BUS.tick(2)
assert(palaDur() == 44, "a good one")
sendXA({ "-", "12", "1", "602", "-", "-", "0", "-" })
BUS.tick(2)
assert(palaDur() == 44, "a second within 10 s is dropped")
local parsed = C(HUNT, [[local a = NS._raidcheck.answers()['vulo pala'] return a.ilvl .. ' ' .. table.concat(a.empty, ',') .. ' ' .. table.concat(a.unench, ',') .. ' ' .. a.free .. ' ' .. tostring(a.cons.flask ~= nil) .. #a.cons.elixirs .. tostring(a.cons.food ~= nil)]])
assert(parsed == "60.2 2,3 8 3 true2true", parsed)

-- 5. the ready check: one answer by itself, none in the lockdown
BUS.tick(11)
local before = BUS.count({ kind = "XA", sender = PALA })
C(PALA, "STUB.fire('READY_CHECK', 'Vulo Hunt', 30)")
BUS.tick(4)
assert(BUS.count({ kind = "XA", sender = PALA }) == before + 1, "the ready check's answer")
BUS.tick(11)
BUS.lock(true)
C(PALA, "STUB.fire('READY_CHECK', 'Vulo Hunt', 30)")
BUS.tick(4)
BUS.lock(false)
BUS.tick(12)
assert(BUS.count({ kind = "XA", sender = PALA }) == before + 1, "none in the lockdown")

-- 6. raid IDs: every character of Pala's account goes to the guild; the officer keeps them
C(PALA, [[
    local now = math.floor(STUB.now)
    AmisiaDB.raidcheck.own["Vulo Pala"] = { at = now, c = "PALADIN", l = 52, ids = { { m = 409, d = 9, r = now + 3 * 86400, k = 4, t = 10 } } }
    AmisiaDB.raidcheck.own["Lia Pala"] = { at = now - 100, c = "MAGE", l = 60, ids = {} }
    return NS.RaidIDsSendAll("GUILD", nil, { low = true })]])
BUS.tick(3)
assert(BUS.count({ kind = "IV", sender = PALA, chan = "GUILD" }) == 2)
assert(C(HUNT, "NS.RaidIDOf('Vulo Pala', 409)") == "locked" and C(HUNT, "NS.RaidIDOf('Lia Pala', 409)") == "free")
assert(C(HUNT, "local _, _, r, s = NS.RaidIDOf('Lia Pala', 409) return s == 'by' and r.by == 'Vulo Pala'"), "laut Vulo Pala")
assert(C(BOB, "next(AmisiaDB.raidcheck.heard) == nil"), "a raider keeps none")
assert(C(KIM, "next(AmisiaDB.raidcheck.heard) == nil"))

-- 7. the officer asks (IQ): answered by whisper within 20 s, once in 10 minutes; a member's IQ is not answered
C(HUNT, "AmisiaDB.raidcheck.heard = {}")
BUS.tick(61)   -- the keyed gap of IV: one per character in 60 s
assert(C(HUNT, "return NS.RaidIDsAsk()") == true)
local again, why = C(HUNT, "return NS.RaidIDsAsk()")
assert(again == nil and why:find("Gerade gefragt", 1, true), tostring(why))
BUS.tick(25)
assert(BUS.count({ kind = "IQ", sender = HUNT, chan = "GUILD" }) == 1)
assert(BUS.count({ kind = "IV", sender = PALA, chan = "WHISPER", target = HUNT }) == 2, "the answer by whisper")
assert(C(HUNT, "NS.RaidIDOf('Vulo Pala', 409)") == "locked")
C(PALA, "return NS.CommSend('IQ', { '-' }, 'GUILD')")
BUS.tick(25)
assert(BUS.count({ kind = "IV", sender = HUNT }) == 0 and BUS.count({ kind = "IV", sender = BOB }) == 0, "nobody answers a member")
BUS.tick(301)
C(HUNT, "return NS.RaidIDsAsk()")
BUS.tick(25)
assert(BUS.count({ kind = "IV", sender = PALA, chan = "WHISPER", target = HUNT }) == 2, "not again within 10 minutes")

-- 8. forged and foreign characters, an alt of another main, a reset too far ahead
local function sendIV(from, fields)
    local list = {}
    for _, f in ipairs(fields) do list[#list + 1] = ("%q"):format(f) end
    C(from, ("return NS.CommSend('IV', { %s }, 'GUILD')"):format(table.concat(list, ", ")))
    BUS.tick(2)
end
local now = C(HUNT, "math.floor(STUB.now)")
local id = ("409:9:%d:2/10"):format(now + 86400)
C(HUNT, "NS.ImportSiteText('#AMISIA-ALTS 1 forever 2026-10-12\\nA Lia_Pala Vulo_Pala\\n#END')")
sendIV(KIM, { BOB, "WARRIOR", "60", id })
assert(C(HUNT, "NS.RaidIDOf('Bob Eisherz', 409)") == "unknown", "from outside the guild")
sendIV(BOB, { KIM, "MAGE", "60", id })
assert(C(HUNT, "NS.RaidIDOf('Kim Fremd', 409)") == "unknown", "a character outside the guild")
sendIV(BOB, { "Lia Pala", "MAGE", "60", id })
assert(C(HUNT, "NS.RaidIDOf('Lia Pala', 409)") == "free", "an alt of another main")
sendIV(BOB, { PALA, "PALADIN", "52", "-" })
assert(C(HUNT, "NS.RaidIDOf('Vulo Pala', 409)") == "locked", "Pala's own word stays")
sendIV(BOB, { BOB, "WARRIOR", "60", ("409:9:%d:2/10"):format(now + 40 * 86400) })
assert(C(HUNT, "NS.RaidIDOf('Bob Eisherz', 409)") == "unknown", "a reset too far ahead")
for _, bad in ipairs({ { BOB, "WARRIOR", "60", "409:9:x:2/10" }, { BOB, "WARRIOR", "61x", id }, { "Bob9", "WARRIOR", "60", id },
                       { BOB, "BARD", "60", id }, { BOB, "WARRIOR", "60", id .. "," .. id .. "," .. id .. "," .. id .. "," .. id .. "," .. id .. "," .. id },
                       { BOB, "WARRIOR", "60", "409:9:1999999999:11/10" } }) do
    sendIV(BOB, bad)
    BUS.tick(60)
end
assert(C(HUNT, "NS.RaidIDOf('Bob Eisherz', 409)") == "unknown", "nothing malformed")
sendIV(BOB, { BOB, "WARRIOR", "60", id })
assert(C(HUNT, "NS.RaidIDOf('Bob Eisherz', 409)") == "locked", "a good one")
sendIV(BOB, { BOB, "WARRIOR", "60", "-" })
assert(C(HUNT, "NS.RaidIDOf('Bob Eisherz', 409)") == "locked", "a second for the character within 60 s is dropped")
