--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- The recipe exchange (Crafters.lua over Comm.lua): Vulo Sturmwind, Fraktur and Kim Eisherz are guild
-- members (Vulo Zweit, Vulo's alt, too), Pug reaches the guild channel but no roster names him. Each
-- member announces a digest of its own crafters (PV); the others pull them (PQ, PK blob). Only the
-- sender's own characters of this guild travel; Pug is ignored both ways; an unchanged digest pulls
-- nothing and only marks the crafters seen; a change pulls again; other profession data is pulled
-- as lists; forged, malformed, hostile and unasked data is refused; the caps hold (bytes, requests,
-- parts, crafters); nothing goes in an instance, in combat, in the lockdown or with sharing off;
-- another protocol and an unknown kind change nothing; old crafters are pruned at load.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local MEMBERS = { VULO, FRAK, KIM }
local ME = { [VULO] = "a0010001", [FRAK] = "b0020002", [KIM] = "c0030003", [PUG] = "d0040004" }
local KINDS = { PV = true, PQ = true, PW = true }
local function isPK(m) return m.prefix == "AmisiaD" and m.text:match("^1BL\tPK\t") ~= nil end
local function craftMsg(m) return KINDS[m.kind] or isPK(m) end
local function stat(name, field) return C(name, ("NS.CraftersStats().%s"):format(field)) end
local function crafter(name, who) return C(name, ("AmisiaDB.crafters and AmisiaDB.crafters.c[%q]"):format(who)) end
local function makers(name, spell)
    return C(name, ([[local out = {}
        for _, c in ipairs(NS.Crafters.ForSpell(%d)) do out[#out + 1] = c.name .. ":" .. c.rank end
        return table.concat(out, ",")]]):format(spell))
end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = "Vulo Zweit", rank = 4 } })
BUS.guild = { VULO, FRAK, KIM, PUG }
for _, name in ipairs(CLIENTS) do
    C(name, ([[dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
        STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
local D = C(VULO, "NS.DropsToday()")
assert(C(VULO, "NS.CraftersCanTalk()") == true)
assert(C(VULO, "NS.CRAFT_PROTO") == 1)

-- Vulo: blacksmithing, his alt Vulo Zweit (alchemy) of this guild, Vulo Fremd of another guild
C(VULO, ([[AmisiaDB.prof = { chars = {
        ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = %d, known = { [2663] = true, [1252229] = true } } },
        ["Vulo Zweit"] = { [171] = { rank = 60, max = 75, day = %d, known = { [2330] = true } } },
        ["Vulo Fremd"] = { [164] = { rank = 300, max = 300, day = %d, known = { [3321] = true } } },
    }, guild = { ["Vulo Zweit"] = "Amisia", ["Vulo Fremd"] = "Andere" } }
    NS.Fire("PROF_CHANGED")]]):format(D, D, D))
C(FRAK, ([[AmisiaDB.prof = { chars = { ["Fraktur"] = { [185] = { rank = 10, max = 75, day = %d, known = { [1229737] = true } } } } }
    NS.Fire("PROF_CHANGED")]]):format(D))
C(PUG, ([[AmisiaDB.prof = { chars = { ["Pug"] = { [164] = { rank = 300, max = 300, day = %d, known = { [3321] = true } } } } }
    NS.Fire("PROF_CHANGED")]]):format(D))

---------------------------------------------------------------------------
-- members pull each other's crafters; Pug is ignored
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end
BUS.tick(119)
assert(BUS.count({ kind = "PV" }) == 0, "no announcement in the first two minutes")
BUS.tick(600)
assert(BUS.count({ kind = "PV", sender = VULO }) == 1 and BUS.count({ kind = "PV", sender = FRAK }) == 1, "announced once")
assert(BUS.count({ kind = "PV", sender = KIM }) == 0, "Kim has no crafter")
for _, name in ipairs({ FRAK, KIM }) do
    local v = crafter(name, VULO)
    assert(v and v.p[164].r == 45 and v.p[164].b and v.self == true and v.seen == D, name .. " has Vulo")
    assert(crafter(name, "Vulo Zweit") and crafter(name, "Vulo Zweit").p[171].r == 60, name .. " has the alt of this guild")
    assert(crafter(name, "Vulo Fremd") == nil, "an alt of another guild never travels")
    assert(makers(name, 2663) == "Vulo Sturmwind:45", makers(name, 2663))
end
assert(crafter(KIM, FRAK).p[185].r == 10 and crafter(VULO, FRAK), "Fraktur at Kim and Vulo")
assert(makers(KIM, 1229737) == "Fraktur:10")
-- nothing from or to Pug
for _, name in ipairs(MEMBERS) do assert(crafter(name, PUG) == nil, "Pug's crafter at " .. name) end
assert(C(PUG, "AmisiaDB.crafters == nil"), "Pug got nothing")
assert(BUS.count(function(m) return craftMsg(m) and m.target == PUG end) == 0, "no answer to Pug")
assert(stat(KIM, "refused") >= 1, "Pug's announcement refused")
-- blobs within 20 parts, whispered; no PV names anyone
for _, m in ipairs(BUS.sent) do
    if isPK(m) then
        local n = tonumber(m.text:match("^1BL\tPK\t[^\t]+\t%d+\t%d+\t(%d+)\t"))
        assert(n <= 20 and m.chan == "WHISPER" and m.target ~= nil)
    end
    if m.kind == "PV" then assert(m.chan == "GUILD" and not m.text:find("Vulo", 1, true), m.text) end
end
local pkBytes = 0
for _, m in ipairs(BUS.sent) do if isPK(m) and m.sender == VULO then pkBytes = pkBytes + #m.text end end
assert(stat(VULO, "bytes") > 0 and stat(VULO, "bytes") <= C(VULO, "NS.CRAFTERS_LIMITS.sessionBytes"))

---------------------------------------------------------------------------
-- an unchanged digest pulls nothing and marks the crafters seen
---------------------------------------------------------------------------
C(KIM, "AmisiaDB.crafters.c['Vulo Sturmwind'].seen = AmisiaDB.crafters.c['Vulo Sturmwind'].seen - 5")
local t1 = C(VULO, "STUB.clock")
BUS.tick(3700)
assert(BUS.count({ kind = "PV", sender = VULO, from = t1 }) == 1, "again after an hour")
assert(BUS.count(function(m) return m.kind == "PQ" and m.t >= t1 and m.sender ~= PUG end) == 0, "nothing to pull")
assert(crafter(KIM, VULO).seen == D, "seen again")

---------------------------------------------------------------------------
-- a new recipe: announced again (after the change gap), pulled again
---------------------------------------------------------------------------
local t2 = C(VULO, "STUB.clock")
C(VULO, "AmisiaDB.prof.chars['Vulo Sturmwind'][164].known[3321] = true; NS.Fire('PROF_CHANGED', 164)")
BUS.tick(700)
assert(BUS.count({ kind = "PV", sender = VULO, from = t2 }) == 1, "the change is announced")
assert(BUS.count(function(m) return m.kind == "PQ" and m.target == VULO and m.t >= t2 and m.sender ~= PUG end) == 2,
    "Kim and Fraktur ask again")
assert(makers(KIM, 3321) == "Vulo Sturmwind:45" and makers(FRAK, 3321) == "Vulo Sturmwind:45")

---------------------------------------------------------------------------
-- other profession data (another index): pulled once more as lists
---------------------------------------------------------------------------
C(KIM, [[table.insert(NS.PROFESSIONS.R[164], "4444:0:0:1:1:2:A")
    NS.Prof._reset()
    NS.Crafters.Changed()]])
assert(makers(KIM, 2663) == "", "Vulo's bitset no longer fits Kim's index")
assert(C(KIM, "AmisiaDB.crafters.src['vulo sturmwind'].f") == "L", "lists next time")
local t3 = C(VULO, "STUB.clock")
C(VULO, "AmisiaDB.prof.chars['Vulo Sturmwind'][164].rank = 46; NS.Fire('PROF_CHANGED', 164)")
BUS.tick(700)
assert(BUS.count(function(m) return m.kind == "PQ" and m.sender == KIM and m.t >= t3 and m.text:find("\tL\t", 1, true) end) == 1,
    "Kim asks for lists")
assert(crafter(KIM, VULO).p[164].l == "2663,3321,1252229", tostring(crafter(KIM, VULO).p[164].l))
assert(makers(KIM, 2663) == "Vulo Sturmwind:46", makers(KIM, 2663))
assert(crafter(FRAK, VULO).p[164].b and crafter(FRAK, VULO).p[164].r == 46, "Fraktur keeps the bitset")
-- a bitset that arrives while the index is built already: found at once, asked again as lists
C(FRAK, [[table.insert(NS.PROFESSIONS.R[164], "4444:0:0:1:1:2:A")
    NS.Prof._reset()
    AmisiaDB.crafters.src['vulo sturmwind'] = nil]])
local t4 = C(VULO, "STUB.clock")
BUS.tick(3700)
assert(stat(FRAK, "mismatch") == 1, "found at the answer")
assert(BUS.count(function(m) return m.kind == "PQ" and m.sender == FRAK and m.t >= t4 and m.text:find("\tL\t", 1, true) end) == 1)
assert(makers(FRAK, 2663) == "Vulo Sturmwind:46", makers(FRAK, 2663))

---------------------------------------------------------------------------
-- forged, malformed and unasked data
---------------------------------------------------------------------------
-- the real announcements wait meanwhile (they would start real pulls)
BUS.drop(function(m) return m.kind == "PV" end)
BUS.tick(200)
local function blob(nonce, tbl, from, ask)
    from = from or FRAK
    if ask ~= false then C(KIM, ("NS.CraftersOpenAsk(%q, %d, %q)"):format(from, nonce, ask or "B")) end
    C(from, ("assert(NS.CommSendBlob('PK', '0000-00-01:%d', %s, 'WHISPER', 'Kim Eisherz', {}))"):format(nonce, tbl))
    BUS.tick(5)
end
-- cooking's index at Kim (the same data as Fraktur's): a bitset of it fits
local H185 = C(KIM, "NS.Crafters._index(185).hash")
local GOOD = ([[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 11, 75, "%s", "01" } } } } }]]):format(H185)
-- unasked, and asked of someone else
local un = stat(KIM, "unasked")
blob(4001, GOOD, FRAK, false)
assert(stat(KIM, "unasked") == un + 1, "a blob nobody asked for")
C(KIM, "NS.CraftersOpenAsk('Vulo Sturmwind', 4002, 'B')")
blob(4002, GOOD, FRAK, false)
assert(stat(KIM, "unasked") == un + 2, "asked of Vulo, sent by Fraktur")
-- an answer is taken once
blob(4003, GOOD)
assert(stat(KIM, "unasked") == un + 2 and crafter(KIM, FRAK).p[185].r == 11, "the asked answer is taken")
blob(4003, GOOD, FRAK, false)
assert(stat(KIM, "unasked") == un + 3, "a second answer to the same request is dropped")
-- malformed: each refused whole, nothing changes
local many = {}
for i = 1, 13 do many[i] = ('{ "Kraft Nr%s", { { 185, 1, 1, "00000000", "01" } } }'):format(string.char(64 + i)) end
local BAD = {
    [[{ v = 2, d = "0badf00d", f = "B", c = {} }]],
    [[{ v = 1, d = "nothex!!", f = "B", c = {} }]],
    [[{ v = 1, d = "0badf00d", f = "L", c = {} }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = {}, x = 1 }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { ]] .. table.concat(many, ",") .. [[ } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur|cff00", { { 185, 1, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1000, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1, 1, "00000000", "0g" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1, 1, "00000000", "]] .. ("ff"):rep(151) .. [[" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1, 1, "00000000", "01" }, { 185, 2, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1, 1, "00000000", "01" } } }, { "fraktur", { { 185, 1, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", {} } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1, 1, "00000000" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1.5, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { [2] = { "Fraktur", { { 185, 1, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "", { { 185, 1, 1, "00000000", "01" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = "Fraktur" }]],
    [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 1, 1, "00000000", "01" }, { 1, 1, 1, "00000000", "01" },
        { 2, 1, 1, "00000000", "01" }, { 3, 1, 1, "00000000", "01" }, { 4, 1, 1, "00000000", "01" }, { 5, 1, 1, "00000000", "01" },
        { 6, 1, 1, "00000000", "01" }, { 7, 1, 1, "00000000", "01" }, { 8, 1, 1, "00000000", "01" } } } } }]],
}
local bad0 = stat(KIM, "bad")
local now = C(KIM, "STUB.dump(AmisiaDB.crafters.c)")
for i, tbl in ipairs(BAD) do
    blob(5000 + i, tbl)
    assert(stat(KIM, "bad") == bad0 + i, "malformed blob " .. i .. " refused")
end
-- lists: steps must be whole, positive and add up below 10 million
local BADL = {
    [[{ v = 1, d = "0badf00d", f = "L", c = { { "Fraktur", { { 185, 1, 1, "00000000", { 0 } } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "L", c = { { "Fraktur", { { 185, 1, 1, "00000000", { 9999999, 1 } } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "L", c = { { "Fraktur", { { 185, 1, 1, "00000000", "1,2" } } } } }]],
    [[{ v = 1, d = "0badf00d", f = "L", c = { { "Fraktur", { { 185, 1, 1, "00000000", { -5, 10 } } } } } }]],
}
for i, tbl in ipairs(BADL) do
    blob(5100 + i, tbl, FRAK, "L")
    assert(stat(KIM, "bad") == bad0 + #BAD + i, "malformed list " .. i .. " refused")
end
assert(C(KIM, "STUB.dump(AmisiaDB.crafters.c)") == now, "nothing changed")
-- hostile: a crafter outside the guild is left out, the crafter's own word stays
local out0, kept0 = stat(KIM, "outsider"), stat(KIM, "kept")
blob(5200, [[{ v = 1, d = "0badf00d", f = "B", c = { { "Nicht Hier", { { 185, 300, 300, "00000000", "01" } } },
    { "Vulo Sturmwind", { { 164, 300, 300, "00000000", "ff" } } }, { "Fraktur", { { 185, 12, 75, "]] .. H185 .. [[", "01" } } } } }]])
assert(stat(KIM, "outsider") == out0 + 1 and crafter(KIM, "Nicht Hier") == nil, "not in the roster")
assert(stat(KIM, "kept") == kept0 + 1 and crafter(KIM, VULO).p[164].r == 46 and crafter(KIM, VULO).via == VULO,
    "Fraktur cannot overwrite what Vulo said of himself")
assert(crafter(KIM, FRAK).p[185].r == 12, "his own crafter is taken")
-- a whole answer drops the sender's crafters it no longer names; a cut one keeps them
C(KIM, "AmisiaDB.crafters.c['Vulo Zweit'].via = 'Fraktur'")
blob(5201, [[{ v = 1, d = "0badf00d", f = "B", m = 1, c = { { "Fraktur", { { 185, 12, 75, "]] .. H185 .. [[", "01" } } } } }]])
assert(crafter(KIM, "Vulo Zweit"), "a cut answer keeps the rest")
blob(5202, [[{ v = 1, d = "0badf00d", f = "B", c = { { "Fraktur", { { 185, 12, 75, "]] .. H185 .. [[", "01" } } } } }]])
assert(crafter(KIM, "Vulo Zweit") == nil, "a whole answer drops what the sender no longer names")
-- Pug's data never reaches the handler, even with a request open for him
local cbad = C(KIM, "NS.CommStats().bad")
blob(5300, GOOD, PUG)
assert(C(KIM, "NS.CommStats().bad") > cbad and crafter(KIM, PUG) == nil, "an outsider's parts are dropped")
-- malformed and foreign control messages: dropped by the message layer or passed over (after a
-- minute: Fraktur sent much just now, Kim's receive limit would drop more)
BUS.drop(nil)
BUS.tick(65)
cbad = C(KIM, "NS.CommStats().bad")
for i, msg in ipairs({ [[NS.CommSend("PV", { "1", "2", "xyz" }, "GUILD")]], [[NS.CommSend("PV", { "1", "999", "0badf00d" }, "GUILD")]],
    [[NS.CommSend("PQ", { "1", "X", "5" }, "WHISPER", "Kim Eisherz")]], [[NS.CommSend("PQ", { "1", "B", "0" }, "WHISPER", "Kim Eisherz")]],
    [[NS.CommSend("PW", { "0" }, "WHISPER", "Kim Eisherz")]], [[NS.CommSend("PZ", { "1" }, "GUILD")]] }) do
    C(FRAK, msg)
    BUS.tick(1)
    assert(C(KIM, "NS.CommStats().bad") == cbad + i, "refused: " .. msg)
end
local other = stat(KIM, "other")
C(FRAK, [[NS.CommSend("PV", { "2", "1", "0badf00d" }, "GUILD")]])
BUS.tick(65)
assert(stat(KIM, "other") == other + 1 and C(KIM, "NS.CraftersState().waiting") == 0, "another protocol is passed over")
-- a whispered announcement is no announcement
C(FRAK, [[NS.CommSend("PV", { "1", "1", "0badf00d" }, "WHISPER", "Kim Eisherz")]])
BUS.tick(5)
assert(C(KIM, "NS.CraftersState().waiting") == 0, "PV only from the guild channel")
assert(C(KIM, "NS.CraftersCanTalk()") == true, "Kim still works")

---------------------------------------------------------------------------
-- caps: the sender's bytes, the requests of the hour, the parts of a blob
---------------------------------------------------------------------------
-- Vulo's bytes spent: Kim's request is answered with a wait of an hour
C(KIM, "AmisiaDB.crafters.src['vulo sturmwind'] = nil")
C(VULO, "NS.CRAFTERS_LIMITS.sessionBytes = NS.CraftersStats().bytes + 20")
local t5 = C(VULO, "STUB.clock")
local busy = stat(KIM, "busy")
C(VULO, "AmisiaDB.prof.chars['Vulo Sturmwind'][164].rank = 47; NS.Fire('PROF_CHANGED', 164)")
C(VULO, "NS.CRAFTERS_LIMITS.sessionBytes = NS.CRAFTERS_LIMITS.sessionBytes + 60")   -- room for the PV only
BUS.tick(700)
assert(BUS.count({ kind = "PW", sender = VULO, from = t5 }) >= 1, "spent: PW")
assert(BUS.count(function(m) return isPK(m) and m.sender == VULO and m.t >= t5 end) == 0, "no blob over the cap")
assert(stat(KIM, "busy") > busy, "Kim heard the wait")
assert(C(KIM, "NS.CraftersState().waiting") >= 1, "and asks later")
C(VULO, "NS.CRAFTERS_LIMITS.sessionBytes = 32768")
-- Kim's requests of the hour
C(KIM, "NS.CRAFTERS_LIMITS.pqPerHour = 0")
local t6 = C(KIM, "STUB.clock")
BUS.tick(4000)
assert(BUS.count({ kind = "PQ", sender = KIM, from = t6 }) == 0, "no request over the hour's cap")
C(KIM, "NS.CRAFTERS_LIMITS.pqPerHour = 20")
-- a blob of one part: only the first crafter, cut (m); the receiver keeps the rest
C(VULO, "NS.CRAFTERS_LIMITS.blobParts = 1")
C(FRAK, "AmisiaDB.crafters.src['vulo sturmwind'] = nil")
local t7 = C(VULO, "STUB.clock")
BUS.tick(3700)
-- (Fraktur's data differs since above: a bitset, then the lists; each blob one part)
assert(BUS.count(function(m) return isPK(m) and m.sender == VULO and m.target == FRAK and m.t >= t7 end) == 2, "one part each")
assert(BUS.count(function(m) return isPK(m) and m.t >= t7 and not m.text:find("^1BL\tPK\t[^\t]+\t%d+\t1\t1\t") end) == 0)
assert(crafter(FRAK, VULO).p[164].r == 47 and crafter(FRAK, "Vulo Zweit"), "the first crafter new, the alt kept")
C(VULO, "NS.CRAFTERS_LIMITS.blobParts = 20")

---------------------------------------------------------------------------
-- nothing in an instance, in combat, in the lockdown, or with sharing off
---------------------------------------------------------------------------
local function quiet(label, on, off)
    C(VULO, on)
    C(VULO, "AmisiaDB.prof.chars['Vulo Sturmwind'][164].rank = AmisiaDB.prof.chars['Vulo Sturmwind'][164].rank + 1; NS.Fire('PROF_CHANGED', 164)")
    local t = C(VULO, "STUB.clock")
    BUS.tick(4000)
    assert(BUS.count(function(m) return craftMsg(m) and m.sender == VULO and m.t >= t end) == 0, label)
    C(VULO, off)
end
quiet("instance", "STUB.instance = { name = 'Höhlen', type = 'party', id = 1 }", "STUB.instance = { name = 'Durotar', type = 'none', id = 0 }")
quiet("combat", "STUB.combat = true", "STUB.combat = false")
quiet("sharing off", "NS.Set('crafters.share', false)", "NS.Set('crafters.share', true)")
BUS.lock(true)
local tl = C(VULO, "STUB.clock")
C(VULO, "AmisiaDB.prof.chars['Vulo Sturmwind'][164].rank = 60; NS.Fire('PROF_CHANGED', 164)")
BUS.tick(4000)
assert(BUS.count(function(m) return craftMsg(m) and m.t >= tl end) == 0, "lockdown")
BUS.lock(false)
BUS.tick(4000)
assert(crafter(KIM, VULO).p[164].r == 60, "after the lockdown it goes on")

---------------------------------------------------------------------------
-- pruning at load: a crafter not heard of for 45 days is gone and pulled again when announced
---------------------------------------------------------------------------
C(KIM, ("AmisiaDB.crafters.c['Vulo Sturmwind'].seen = %d; AmisiaDB.crafters.src['vulo sturmwind'].at = %d"):format(D - 46, D - 46))
BUS.reload(KIM)
C(KIM, [[dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
    STUB.fire("GUILD_ROSTER_UPDATE")
    STUB.fire("PLAYER_LOGIN")]])
assert(crafter(KIM, VULO) == nil and C(KIM, "AmisiaDB.crafters.src['vulo sturmwind'] == nil"), "pruned")
assert(crafter(KIM, FRAK) ~= nil, "the others stay")
BUS.tick(3700)
assert(crafter(KIM, VULO) and crafter(KIM, VULO).seen == D, "pulled again")
