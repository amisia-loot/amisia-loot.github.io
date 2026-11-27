--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Udo_Fremd]]
-- F-240 (D-174): the question after the login and passing on. Kim installed Amisia today (nothing heard), Udo heard
-- nobody today either; Vulo heard someone today. Kim and Udo ask the guild once (PH) 60-120 s after the login, Vulo
-- does not. Vulo answers each by whisper with his PV and the count he passes on; Kim pulls Vulo's own crafters and
-- what Vulo passes on (PQ format R): Fraktur, heard first-hand three days ago, with that day and "via Vulo"; not
-- the member heard 20 days ago, not one Vulo only got passed on, not a name outside the roster. Fraktur, offline
-- until then, comes online: his own word replaces the one passed on. One answer per asker an hour; the old flow
-- without a question; sharing off answers nothing.
local VULO, FRAK, KIM, UDO = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Udo Fremd"
local ME = { [VULO] = "a0010001", [FRAK] = "b0020002", [KIM] = "c0030003", [UDO] = "e0050005" }
local function crafter(name, who) return C(name, ("AmisiaDB.crafters and AmisiaDB.crafters.c[%q]"):format(who)) end
local function stat(name, field) return C(name, ("NS.CraftersStats().%s"):format(field)) end
local function isPK(m) return m.prefix == "AmisiaD" and m.text:match("^1BL\tPK\t") ~= nil end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = UDO, rank = 4 },
    { name = "Lena Kraus", rank = 4 }, { name = "Alt Mitglied", rank = 4 } })
BUS.guild = { VULO, FRAK, KIM, UDO }
for _, name in ipairs(CLIENTS) do
    C(name, ([[dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
        STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
local D = C(VULO, "NS.DropsToday()")

-- Vulo: blacksmithing; he heard Fraktur himself three days ago, "Alt Mitglied" 20 days ago, Lena only passed on,
-- Pug (not in the roster) himself; he heard a sender today
C(VULO, ([[AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = %d, known = { [2663] = true } } } } }
    AmisiaDB.crafters = { v = 1, src = { ["fraktur"] = { at = %d } }, c = {
        ["Fraktur"] = { via = "Fraktur", self = true, seen = %d, p = { [185] = { r = 10, m = 75, h = "00000000", l = "1229737" } } },
        ["Alt Mitglied"] = { via = "Alt Mitglied", self = true, seen = %d, p = { [185] = { r = 5, m = 75, h = "00000000", l = "1229737" } } },
        ["Lena Kraus"] = { via = "Fraktur", relay = true, seen = %d, p = { [185] = { r = 7, m = 75, h = "00000000", l = "1229737" } } },
        ["Pug"] = { via = "Pug", self = true, seen = %d, p = { [185] = { r = 9, m = 75, h = "00000000", l = "1229737" } } },
    } }
    NS.Fire("PROF_CHANGED")]]):format(D, D, D - 3, D - 20, D - 1, D - 2))
-- Fraktur is offline: sharing off until he comes online
C(FRAK, ([[AmisiaDB.prof = { chars = { ["Fraktur"] = { [185] = { rank = 12, max = 75, day = %d, known = { [1229737] = true } } } } }
    NS.Set("crafters.share", false)
    NS.Fire("PROF_CHANGED")]]):format(D))
-- Udo heard Fraktur himself five days ago (an older word than Vulo's): a word passed on never replaces it
C(UDO, ([[AmisiaDB.prof = { chars = { ["Udo Fremd"] = { [171] = { rank = 30, max = 75, day = %d, known = { [2330] = true } } } } }
    AmisiaDB.crafters = { v = 1, src = { ["fraktur"] = { at = %d, d = "0badf00d" } }, c = {
        ["Fraktur"] = { via = "Fraktur", self = true, seen = %d, p = { [185] = { r = 11, m = 75, h = "00000000", l = "1229737" } } },
    } }
    NS.Fire("PROF_CHANGED")]]):format(D, D - 5, D - 5))

---------------------------------------------------------------------------
-- the question: Kim and Udo ask once, Vulo (heard someone today) does not
---------------------------------------------------------------------------
for _, name in ipairs({ VULO, KIM, UDO }) do C(name, "STUB.fire('PLAYER_LOGIN')") end
BUS.tick(59)
assert(BUS.count({ kind = "PH" }) == 0, "not in the first minute")
BUS.tick(65)
assert(BUS.count({ kind = "PH", sender = KIM, chan = "GUILD" }) == 1 and BUS.count({ kind = "PH", sender = UDO }) == 1, "Kim and Udo ask")
assert(BUS.count({ kind = "PH", sender = VULO }) == 0, "Vulo heard someone today")
local asked = C(KIM, "STUB.clock")
BUS.tick(70)
-- the answers: by whisper, with the count passed on (Fraktur only: not Alt Mitglied, Lena or Pug)
assert(BUS.count({ kind = "PV", chan = "WHISPER", sender = VULO, target = KIM }) == 1, "Vulo answers Kim")
assert(BUS.count({ kind = "PV", chan = "WHISPER", sender = VULO, target = UDO }) == 1, "and Udo")
assert(BUS.count({ kind = "PV", sender = FRAK }) == 0, "Fraktur shares nothing")
for _, m in ipairs(BUS.sent) do
    if m.kind == "PV" and m.chan == "WHISPER" and m.sender == VULO then assert(m.text:match("\t1$"), m.text) end
end
BUS.tick(300)

---------------------------------------------------------------------------
-- Kim pulled Vulo's own and what he passes on
---------------------------------------------------------------------------
local v = crafter(KIM, VULO)
assert(v and v.self == true and v.p[164].r == 45, "Vulo's own")
local f = crafter(KIM, FRAK)
assert(f and f.relay == true and f.via == VULO and f.seen == D - 3 and f.p[185].r == 10, "Fraktur passed on, his day kept")
assert(crafter(KIM, "Alt Mitglied") == nil and crafter(KIM, "Lena Kraus") == nil and crafter(KIM, "Pug") == nil, "only first-hand, fresh, members")
assert(BUS.count({ kind = "PQ", sender = KIM, target = VULO }) == 2, "one pull of each kind")
-- Udo answered too (late) and passes Vulo on; Vulo's own word replaced that when Kim pulled it
assert(stat(KIM, "relayed") >= 1 and stat(VULO, "relayServed") >= 1)
for _, m in ipairs(BUS.sent) do
    if isPK(m) then assert(m.chan == "WHISPER") end
end
-- Kim passes nothing on that it got passed on
assert(C(KIM, "NS.Crafters.Professions()['fraktur'][1].relay") == true, "the page knows it is passed on")
assert(C(KIM, "NS.Crafters.Professions()['fraktur'][1].via") == VULO)
assert(C(KIM, "NS.Crafters.ViaText(NS.Crafters.ForSpell(1229737)[1])") == "laut Vulo Sturmwind, Stand vor 3 Tagen",
    tostring(C(KIM, "NS.Crafters.ViaText(NS.Crafters.ForSpell(1229737)[1])")))
C(KIM, "NS.Dispatch('hersteller')")
assert(C(KIM, "STUB.messages[#STUB.messages]"):find("Login-Frage gestellt", 1, true), C(KIM, "STUB.messages[#STUB.messages]"))

-- Udo pulled what Vulo passes on too, but keeps Fraktur's own word
local uf = crafter(UDO, FRAK)
assert(BUS.count({ kind = "PQ", sender = UDO, target = VULO }) == 2 and uf.self == true and not uf.relay and uf.p[185].r == 11,
    "the crafter's own word stays")

---------------------------------------------------------------------------
-- one answer per asker an hour; a question from someone not in the roster gets nothing
---------------------------------------------------------------------------
local t1 = C(VULO, "STUB.clock")
C(KIM, "NS.CommSend('PH', { '1', '2' }, 'GUILD')")
BUS.tick(120)
assert(BUS.count({ kind = "PV", chan = "WHISPER", sender = VULO, target = KIM, from = t1 }) == 0, "once an hour per asker")
assert(C(VULO, "NS.CraftersStats().replies") == 2)

---------------------------------------------------------------------------
-- Fraktur comes online: his own word replaces the one passed on
---------------------------------------------------------------------------
C(FRAK, "NS.Set('crafters.share', true); STUB.fire('PLAYER_LOGIN')")
BUS.tick(400)
f = crafter(KIM, FRAK)
assert(f and f.self == true and not f.relay and f.seen == D and f.p[185].r == 12, "his own word")

---------------------------------------------------------------------------
-- a whispered PV without an own question is ignored; sharing off answers nothing
---------------------------------------------------------------------------
local before = stat(UDO, "pulls")
C(FRAK, "NS.CommSend('PV', { '1', '1', 'deadbeef', '5' }, 'WHISPER', 'Udo Fremd')")
BUS.tick(60)
C(VULO, "NS.Set('crafters.share', false)")
local t2 = C(VULO, "STUB.clock")
C(FRAK, "NS.CommSend('PH', { '1', '0' }, 'GUILD')")
BUS.tick(120)
assert(BUS.count({ kind = "PV", sender = VULO, from = t2 }) == 0, "sharing off: no answer")
print("crafters hello ok")
