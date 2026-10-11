--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Crafter records from another member (Crafters.lua apply): a sender may speak only of itself and
-- its known alts (the alts list of the website), a list keeps only the spells of the receiver's own
-- recipe index, and the records of one sender stay within the crafter and byte caps also over cut
-- answers (m = 1); the whole store stays within its byte budget.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local ME = { [VULO] = "a0010001", [FRAK] = "b0020002", [KIM] = "c0030003" }
local ALTS = { "Frak Eins", "Frak Zwei", "Frak Drei", "Frak Vier" }
local roster = { { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } }
for _, n in ipairs(ALTS) do roster[#roster + 1] = { name = n, rank = 4 } end
BUS.setGuild(roster)
BUS.guild = { VULO, FRAK, KIM }
for _, name in ipairs(CLIENTS) do
    C(name, ([[dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
        STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
-- only the blobs below travel (no real pull, whose whole answer would replace them)
BUS.drop(function(m) return m.kind == "PV" or m.kind == "PQ" or m.kind == "PW" end)
local function stat(field) return C(VULO, ("NS.CraftersStats().%s"):format(field)) end
local function crafter(who) return C(VULO, ("AmisiaDB.crafters and AmisiaDB.crafters.c[%q]"):format(who)) end
local nonce = 7000
local function send(tbl, f)
    nonce = nonce + 1
    C(VULO, ("NS.CraftersOpenAsk('Fraktur', %d, %q)"):format(nonce, f or "B"))
    assert(C(FRAK, ("return NS.CommSendBlob('PK', '0000-00-01:%d', %s, 'WHISPER', 'Vulo Sturmwind', {})"):format(nonce, tbl)))
    BUS.tick(70)
end

-- Fraktur (any member) answers with a record of Kim, who is no alt of his
local f0 = stat("foreign")
send([[{ v = 1, d = "0badf00d", f = "B", c = { { "Kim Eisherz", { { 164, 300, 300, "00000000", "ff" } } } } }]])
assert(crafter(KIM) == nil, "a record of another member is refused")
assert(stat("foreign") == f0 + 1)

-- with an alts list naming Kim an alt of Fraktur it is his character
C(VULO, [[assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-06\nA Kim_Eisherz Fraktur\nA Frak_Eins Fraktur\nA Frak_Zwei Fraktur\nA Frak_Drei Fraktur\nA Frak_Vier Fraktur\nA Nicht_Hier Fraktur\n#END"))]])
send([[{ v = 1, d = "0badf00d", f = "B", c = { { "Kim Eisherz", { { 164, 300, 300, "00000000", "ff" } } },
    { "Nicht Hier", { { 164, 1, 1, "00000000", "01" } } } } }]])
assert(crafter(KIM) and crafter(KIM).via == FRAK and crafter(KIM).p[164].r == 300, "a known alt is taken")
assert(crafter("Nicht Hier") == nil and stat("outsider") >= 1, "an alt outside the roster is not")

-- a list keeps only the spells of the own index; a profession without an index here is dropped
local IX = C(VULO, "NS.Crafters._index(164).list")
assert(#IX == 5)
send([[(function()
    local st = {}
    for i = 1, 300 do st[i] = 23 end            -- 300 spells nobody knows
    local steps, at = {}, 0
    for _, s in ipairs({ 2663, 3321, 50000, 1252229 }) do steps[#steps + 1] = s - at; at = s end
    return { v = 1, d = "0badf00d", f = "L", c = { { "Fraktur", { { 164, 10, 75, "00000000", steps }, { 101, 1, 1, "00000000", st } } } } }
end)()]], "L")
local fr = crafter(FRAK)
assert(fr and fr.p[164].l == "2663,3321,1252229", fr and tostring(fr.p[164].l))
assert(fr.p[101] == nil, "unknown profession dropped")
assert(C(VULO, "NS.Crafters.Bytes(AmisiaDB.crafters.c['Fraktur'])") == #"2663,3321,1252229")

-- cut answers pile up no more than crafterMax crafters of one sender
C(VULO, "NS.CRAFTERS_LIMITS.crafterMax = 3")
local cap0 = stat("capped")
for _, n in ipairs(ALTS) do
    send(([[{ v = 1, d = "0badf00d", f = "B", m = 1, c = { { %q, { { 164, 5, 75, "00000000", "01" } } } } }]]):format(n))
end
local mine = C(VULO, [[local n = 0
    for _, c in pairs(AmisiaDB.crafters.c) do if c.via == "Fraktur" then n = n + 1 end end
    return n]])
assert(mine == 3, "crafters of one sender: " .. tostring(mine))
assert(stat("capped") > cap0)
-- a known crafter of the sender is still updated at the cap
assert(crafter("Frak Eins") and crafter("Frak Zwei") and crafter("Frak Drei") == nil)
send([[{ v = 1, d = "0badf00d", f = "B", m = 1, c = { { "Frak Eins", { { 164, 6, 75, "00000000", "01" } } } } }]])
assert(crafter("Frak Eins").p[164].r == 6)
C(VULO, "NS.CRAFTERS_LIMITS.crafterMax = 12")

-- the bytes of one sender
C(VULO, "NS.CRAFTERS_LIMITS.viaBytes = 8")
cap0 = stat("capped")
send([[{ v = 1, d = "0badf00d", f = "B", m = 1, c = { { "Frak Vier", { { 164, 5, 75, "00000000", "0101010101" } } } } }]])
assert(crafter("Frak Vier") == nil and stat("capped") == cap0 + 1, "over the sender's bytes")
C(VULO, "NS.CRAFTERS_LIMITS.viaBytes = 24576")

-- the store's bytes: the oldest crafters go
C(VULO, [[local s = AmisiaDB.crafters
    s.c["Frak Eins"].seen = s.c["Frak Eins"].seen - 3
    NS.CRAFTERS_LIMITS.storeBytes = NS.Crafters.Bytes(s.c["Fraktur"]) + NS.Crafters.Bytes(s.c["Frak Zwei"])
    NS.Crafters.Prune()
    NS.CRAFTERS_LIMITS.storeBytes = 393216]])
assert(crafter("Frak Eins") == nil and crafter(FRAK) ~= nil and crafter("Frak Zwei") ~= nil, "the oldest went")
