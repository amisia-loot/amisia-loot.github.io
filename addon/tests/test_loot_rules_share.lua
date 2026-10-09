--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Loot rules between officers (MR/MQ, Raid/LootRules.lua): a sent set reaches the other officers as
-- an offer and stays inactive until "Übernehmen"; only verified officers of the guild count;
-- malformed fields are dropped by Comm.lua; older sets, a second set within 30 s and a declined set
-- are not offered; a long item list goes in parts; an officer asks after the login (MQ) and gets
-- the newest sent set by whisper.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
C(KIM, "STUB.officer = false")
for _, name in ipairs(CLIENTS) do
    C(name, [[
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.item(70001, "Grüner Gürtel", 2); STUB.item(70007, "Episches Schwert", 4)
        return true]])
end
BUS.tick(1)

local function list(name) return C(name, "local out = {} for i, r in ipairs(NS.LootRules().list) do out[i] = r.k .. ':' .. r.to end return out") end
local function offer(name) return C(name, "local o = NS.LootRules().offer return o and { o.from, o.rev, #o.list } or false") end

---------------------------------------------------------------------------
-- an officer sends; the others get an offer that does nothing until taken over
---------------------------------------------------------------------------
assert(C(VULO, "return NS.AddLootRule({ k = 'q', q = 3, to = 'de' }) ~= nil"))
assert(C(VULO, "return NS.AddLootRule({ k = 'm', to = 'bank' }) ~= nil"))
assert(C(VULO, "return NS.AddLootRule({ k = 'p', items = '70007', to = 'Anna Berg' }) ~= nil"))
assert(BUS.count({ kind = "MR" }) == 0, "nothing goes out without the button")
local ok, why = C(VULO, "return NS.SendLootRules()")
assert(ok == true, tostring(why))
BUS.tick(2)
assert(BUS.count({ kind = "MR", sender = VULO, chan = "GUILD" }) == 1, "one message to the guild")
local o = offer(FRAK)
assert(o and o[1] == VULO and o[3] == 3, "Fraktur has the offer")
assert(#list(FRAK) == 0, "an offer is not active")
assert(has(C(FRAK, "table.concat(STUB.messages, '\\n')"), "Neue Lootregeln von Vulo Sturmwind (3 Regeln)"), "the officer is told")
local d = C(FRAK, "return NS.LootRulesDiff()")
assert(d.new == 3 and d.changed == 0 and d.removed == 0)
-- the player rule keeps the surname, the maker is the server's sender
local p = C(FRAK, "local r = NS.LootRules().offer.list[3] return { r.to, r.items[1], r.by }")
assert(p[1] == "Anna Berg" and p[2] == 70007 and p[3] == VULO, table.concat({ tostring(p[1]), tostring(p[2]), tostring(p[3]) }, "/"))
-- a member cannot send
ok, why = C(KIM, "return NS.SendLootRules()")
assert(ok == false and has(why, "Offiziere"), tostring(why))

-- "Übernehmen": the set becomes Fraktur's own
assert(C(FRAK, "return NS.AcceptLootRules()") == true)
local l = list(FRAK)
assert(#l == 3 and l[1] == "q:de" and l[2] == "m:bank" and l[3] == "p:Anna Berg", "taken over")
assert(offer(FRAK) == false and C(FRAK, "NS.LootRules().by") == VULO)

---------------------------------------------------------------------------
-- only verified officers of the guild count
---------------------------------------------------------------------------
local function rev() return tostring(C(FRAK, "NS.LootRules().rev") + 100) end
C(KIM, "NS.CommSend('MR', { '" .. rev() .. "', '1', '1', 'Kim_Eisherz', 'abcd:q:3:de' }, 'GUILD')")
BUS.tick(2)
assert(offer(FRAK) == false and offer(VULO) == false, "a member's set counts nowhere")
-- somebody outside the guild (Fraktur's roster without Vulo)
C(FRAK, [[STUB.guild = { { name = "Fraktur", rank = 2, online = true, class = "PRIEST" }, { name = "Kim Eisherz", rank = 4, online = true, class = "PRIEST" } }
    STUB.fire("GUILD_ROSTER_UPDATE")]])
BUS.tick(12)
C(VULO, "NS.CommSend('MR', { '" .. rev() .. "', '1', '1', 'Vulo_Sturmwind', 'abcd:q:3:de' }, 'GUILD')")
BUS.tick(2)
assert(offer(FRAK) == false, "not in the guild: dropped")
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
C(FRAK, "STUB.fire('GUILD_ROSTER_UPDATE')")
BUS.tick(12)

---------------------------------------------------------------------------
-- malformed fields are dropped before any handler
---------------------------------------------------------------------------
local bad = {
    { rev(), "1", "1", "Vulo_Sturmwind", "abcd:q:4:de" },            -- quality above rare
    { rev(), "1", "1", "Vulo_Sturmwind", "abcd:q:3:Anna" },          -- a quality to a player
    { rev(), "1", "1", "Vulo_Sturmwind", "abcd:p:70007:bank" },      -- a player rule to the bank
    { rev(), "1", "1", "Vulo_Sturmwind", "abcd:p:70007:Anna2" },     -- a digit in the name
    { rev(), "1", "1", "Vulo_Sturmwind", "abcd:m:5:bank" },          -- a value for the materials
    { rev(), "2", "1", "Vulo_Sturmwind", "abcd:m:-:bank" },          -- part above parts
    { rev(), "1", "5", "Vulo_Sturmwind", "abcd:m:-:bank" },          -- more than 4 parts
    { rev(), "1", "1", "Vulo Sturmwind", "abcd:m:-:bank" },          -- a space in the setter
    { rev(), "1", "1", "Vulo_Sturmwind", "xyz:m:-:bank" },           -- no 4 hex id
    { rev(), "1", "1", "Vulo_Sturmwind", "a1:m:-:bank,a2:m:-:bank,a3:m:-:bank,a4:m:-:bank,a5:m:-:bank,a6:m:-:bank,a7:m:-:bank" },
    { "x", "1", "1", "Vulo_Sturmwind", "abcd:m:-:bank" },
}
local many = {}
for i = 1, 51 do many[i] = tostring(70000 + i) end
bad[#bad + 1] = { rev(), "1", "1", "Vulo_Sturmwind", "abcd:i:" .. table.concat(many, "+", 1, 30) .. "+" .. table.concat(many, "+", 31, 51) .. ":bank" }
local badBefore = C(FRAK, "NS.CommStats().bad")
for _, f in ipairs(bad) do
    local fields = {}
    for i, x in ipairs(f) do fields[i] = ("%q"):format(x) end
    C(VULO, "NS.CommSend('MR', { " .. table.concat(fields, ", ") .. " }, 'GUILD')")
end
BUS.tick(3)
assert(offer(FRAK) == false, "no malformed set becomes an offer")
assert(C(FRAK, "NS.CommStats().bad") - badBefore >= #bad - 1, "dropped as bad: " .. tostring(C(FRAK, "NS.CommStats().bad") - badBefore))
-- an MQ with a bad revision
C(VULO, "NS.CommSend('MQ', { 'abc' }, 'GUILD')")
BUS.tick(2)

---------------------------------------------------------------------------
-- older sets, one set per officer every 30 s, decline
---------------------------------------------------------------------------
BUS.tick(31)
C(VULO, "NS.CommSend('MR', { tostring(NS.LootRules().rev - 10), '1', '1', 'Vulo_Sturmwind', 'abcd:m:-:bank' }, 'GUILD')")
BUS.tick(2)
assert(offer(FRAK) == false, "an older set is not offered")
C(VULO, "NS.AddLootRule({ k = 'i', items = '70001', to = 'bank' })")
assert(C(VULO, "return NS.SendLootRules()") == true)
BUS.tick(2)
o = offer(FRAK)
assert(o and o[3] == 4, "the newer set is offered")
d = C(FRAK, "return NS.LootRulesDiff()")
assert(d.new == 1 and d.changed == 0 and d.removed == 0, ("%d %d %d"):format(d.new, d.changed, d.removed))
C(VULO, "NS.RemoveLootRule(NS.LootRules().list[1].id)")
assert(C(VULO, "return NS.SendLootRules()") == true)
BUS.tick(2)
assert(offer(FRAK)[3] == 4, "a second set within 30 s is dropped")
BUS.tick(31)
assert(C(VULO, "return NS.SendLootRules()") == true)
BUS.tick(2)
o = offer(FRAK)
assert(o and o[3] == 3, "after 30 s it comes")
d = C(FRAK, "return NS.LootRulesDiff()")
assert(d.new == 1 and d.removed == 1, ("%d %d %d"):format(d.new, d.changed, d.removed))
assert(C(FRAK, "return NS.DeclineLootRules()") == true and offer(FRAK) == false)
assert(#list(FRAK) == 3, "declined: the own rules stay")
-- the same set again (an answer to a question) is not offered once more
BUS.tick(31)
C(VULO, "NS.SendLootRules()")
BUS.tick(2)
assert(offer(FRAK) == false, "a declined set comes not again")

---------------------------------------------------------------------------
-- a long item list goes in parts and arrives whole
---------------------------------------------------------------------------
BUS.tick(31)
local ids = {}
for i = 1, 50 do ids[i] = tostring(100000 + i) end
assert(C(VULO, "return NS.AddLootRule({ k = 'i', items = '" .. table.concat(ids, " ") .. "', to = 'de' }) ~= nil"))
local before = BUS.count({ kind = "MR", sender = VULO })
assert(C(VULO, "return NS.SendLootRules()") == true)
BUS.tick(2)
local parts = BUS.count({ kind = "MR", sender = VULO }) - before
assert(parts >= 2 and parts <= 4, "in parts: " .. parts)
for _, m in ipairs(BUS.sent) do assert(#m.text <= 250, "every part fits") end
o = offer(FRAK)
assert(o and o[3] == 4, "arrived whole")
assert(C(FRAK, "#NS.LootRules().offer.list[4].items") == 50, "all 50 items")
C(FRAK, "NS.DeclineLootRules()")

---------------------------------------------------------------------------
-- MQ: an officer asks after the login and gets the newest sent set by whisper
---------------------------------------------------------------------------
C(FRAK, "AmisiaDB.lootRules = nil; NS.LootRulesLoaded(AmisiaDB)")
BUS.tick(31)
assert(C(KIM, "return NS.AskLootRules()") == false, "members do not ask")
local wb = BUS.count({ kind = "MR", sender = VULO, chan = "WHISPER" })
assert(C(FRAK, "return NS.AskLootRules()") == true)
BUS.tick(6)
assert(BUS.count({ kind = "MQ", sender = FRAK, chan = "GUILD" }) == 1)
assert(BUS.count({ kind = "MR", sender = VULO, chan = "WHISPER", target = FRAK }) - wb >= 1, "answered by whisper")
o = offer(FRAK)
assert(o and o[1] == VULO and o[3] == 4, "the offer after the question")
assert(#list(FRAK) == 0, "still only an offer")
-- a set that was changed after sending is not handed out on a question
C(VULO, "NS.AddLootRule({ k = 'q', q = 2, to = 'bank' })")
C(FRAK, "AmisiaDB.lootRules = nil; NS.LootRulesLoaded(AmisiaDB)")
wb = BUS.count({ kind = "MR", sender = VULO, chan = "WHISPER" })
BUS.tick(31)
C(FRAK, "NS.AskLootRules()")
BUS.tick(6)
assert(BUS.count({ kind = "MR", sender = VULO, chan = "WHISPER" }) == wb, "an unsent change is no answer")

print("loot rules share ok")
