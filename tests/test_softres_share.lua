--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug Neu_Ling]]
-- Soft-reserves shared with the raid (F-107, spec 2026-10-17 part A): Vulo Sturmwind (officer) takes
-- a list and announces it (SV); Kim Eisherz (raider) asks (SQ) and gets it whole (SR); Fraktur
-- (officer with his own older list) gets it only as an offer; Pug outside the guild gets nothing;
-- Neu Ling joins later and gets it too. A rename goes out again, clearing clears the copies, and a
-- raider's announcement or a list nobody asked for is not taken.
local VULO, FRAK, KIM, PUG, NEU = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug", "Neu Ling"
local CODE = "eNpljzFPxDAMhf+L5wxNVdoj27EwggSIAXVwa1dEpMnJSVmq/ncSDkErMsXv6X1+XmHmhIQJwaxgCQzgoOuRQMEojInpnMDo7la3N1V+CpYLHWX9LQtaekooKf46bd0U590SsQczoYusgGwcg9CLuLwMNgUxTEk4snxyBPO2gseZs3f2HksNhzHr8CiWY8qCD6nY+XdxS3zwJZXX2MTzNV/O0KeTbja1H/oy/rDvwrBDv6KIDfLHfkb/ceDrf/yu6tqM7PN9KHTof/XrqlEwZaqBe+uId81Lagh+iRKcK5l++wJJR3km"

BUS.setRaid({ VULO, FRAK, KIM, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = NEU, rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        if not STUB.officer then NS.Set("ui.view", "raider") end
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]])
end
-- Fraktur holds an own, older list
C(FRAK, [[NS.SetSoftRes("Fraktur 32235"); AmisiaDB.softres.at = AmisiaDB.softres.at - 3600]])
BUS.tick(30)
assert(BUS.count({ kind = "SV", sender = VULO }) == 0, "no list, nothing announced")

-- Vulo takes the code: announced at once, the others ask and get it
assert(C(VULO, ("NS.Set('softres.announce', false); NS.SetSoftRes(%q); return NS.SoftResShareNow()"):format(CODE)) == true)
BUS.tick(10)
assert(BUS.count({ kind = "SV", sender = VULO, chan = "RAID" }) >= 1, "announced")
assert(BUS.count({ kind = "SQ", sender = KIM, chan = "WHISPER" }) >= 1, "the raider asked")
assert(C(KIM, "AmisiaDB.softres and AmisiaDB.softres.from") == VULO, "the raider has the list")
assert(C(KIM, "NS.ReservedBy(18814)[1]") == "Anna" and C(KIM, "NS.SoftResTimes(AmisiaDB.softres, 18814, 'Anna')") == 2, "doubles kept")
assert(C(KIM, "NS.HardReserveOf(17204).to") == "Gilde", "hard reserves too")
assert(C(KIM, "AmisiaDB.softres.notes.Bob") == "Tank" and C(KIM, "AmisiaDB.softres.raw") == "")
assert(C(KIM, "NS.SoftResHash(AmisiaDB.softres)") == C(VULO, "NS.SoftResHash(AmisiaDB.softres)"), "the same list")
assert(C(PUG, "AmisiaDB.softres == nil"), "the guest outside the guild gets nothing")
assert(BUS.count({ kind = "SV", sender = KIM }) == 0 and BUS.count({ kind = "SV", sender = FRAK }) >= 0)
-- Fraktur: only an offer; his own list stays until he takes it
assert(C(FRAK, "AmisiaDB.softres.from == nil and NS.ReservedBy(32235)[1] == 'Fraktur'"), "own list kept")
assert(C(FRAK, "NS.SoftResOffer() and NS.SoftResOffer().from") == VULO, "offered")
-- the raider's page names the officer
assert(C(KIM, [[NS.ShowPage("softres"); return NS.SoftResPageFrame().state:GetText()]]):find("von Vulo Sturmwind", 1, true))
assert(C(FRAK, [[NS.ShowPage("softres"); local f = NS.SoftResPageFrame()
    return f.take:IsShown() and f.check:GetText():find("Neuere Liste von Vulo Sturmwind", 1, true) ~= nil]]), "the offer on the page")
assert(C(FRAK, "NS.TakeSoftResOffer()") == true)
assert(C(FRAK, "AmisiaDB.softres.from") == VULO and C(FRAK, "NS.SoftResOffer() == nil"))

-- a later member gets it after joining
local asked = BUS.count({ kind = "SQ", sender = NEU })
BUS.setRaid({ VULO, FRAK, KIM, PUG, NEU })
for _, name in ipairs(CLIENTS) do C(name, [[STUB.fire("GROUP_ROSTER_UPDATE")]]) end
BUS.tick(20)
assert(BUS.count({ kind = "SQ", sender = NEU }) > asked and C(NEU, "AmisiaDB.softres and AmisiaDB.softres.from") == VULO, "the latecomer")

-- a rename by Vulo goes out again; the copies follow
C(VULO, [[NS.RenameReserve("Bob", "Bob Stein", true)]])
BUS.tick(20)
assert(C(KIM, "NS.ReservedBy(17076)[1]") == "Bob Stein", "the renamed list arrived")

-- a raider announcing a list is not asked; an unasked list is refused
local before = BUS.count({ kind = "SQ" })
C(KIM, [[NS.CommSend("SV", { tostring(NS.ServerTime()), "0123456789abcdef", "3" }, "RAID")]])
BUS.tick(10)
assert(BUS.count({ kind = "SQ" }) == before, "nobody asks a raider")
local refused = C(NEU, "NS.SoftResShareStats().refused")
C(VULO, [[local sr = AmisiaDB.softres
    NS.CommSendBlob("SR", sr.date .. ":" .. sr.at, { v = 1, at = sr.at, d = sr.date, r = {}, h = {} }, "WHISPER", "Neu Ling")]])
BUS.tick(5)
assert(C(NEU, "NS.SoftResShareStats().refused") == refused + 1, "not asked: refused")

-- clearing: the copies of Vulo's list go
C(VULO, "NS.ClearSoftRes()")
BUS.tick(5)
assert(C(KIM, "AmisiaDB.softres == nil") and C(NEU, "AmisiaDB.softres == nil") and C(FRAK, "AmisiaDB.softres == nil"), "cleared everywhere")

-- with sharing off nothing is announced
C(VULO, ("NS.Set('softres.share', false); NS.SetSoftRes(%q); return NS.SoftResShareNow()"):format(CODE))
local sv = BUS.count({ kind = "SV", sender = VULO })
BUS.tick(30)
assert(BUS.count({ kind = "SV", sender = VULO }) == sv, "share off")
