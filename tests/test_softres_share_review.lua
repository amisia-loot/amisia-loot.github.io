--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Review 2026-10-17 of the soft-reserve sharing (F-107): an empty "Übernehmen" never replaces the
-- raid's copies; a clear or a second import right after the first still reaches the raid (the
-- receivers' 8 s gap); an officer in the raider view keeps his own list; an offer older than an own
-- newer import is gone; a list the receivers would refuse is not announced.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
BUS.setRaid({ VULO, FRAK, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player ~= "Kim Eisherz"
        if not STUB.officer then NS.Set("ui.view", "raider") end
        NS.Set("softres.announce", false)
        STUB.fire("GUILD_ROSTER_UPDATE"); STUB.fire("PLAYER_LOGIN"); STUB.fire("GROUP_ROSTER_UPDATE")]])
end
BUS.tick(10)

-- 1. a shared copy in an officer's window: "Übernehmen" with the empty box keeps everything
C(VULO, [[NS.SetSoftRes("Anna 18814\nBob 17076"); NS.SoftResShareNow()]])
BUS.tick(15)
assert(C(FRAK, "AmisiaDB.softres and AmisiaDB.softres.from") == VULO and C(KIM, "AmisiaDB.softres.count") == 2)
C(FRAK, [[NS.ToggleSoftResFrame(); AmisiaSoftResFrame.editBox:SetText(""); AmisiaSoftResFrame.applyBtn:Click()]])
assert(C(FRAK, "AmisiaSoftResFrame.resultText:GetText()"):find("Nichts eingefügt", 1, true))
BUS.tick(15)
assert(C(FRAK, "AmisiaDB.softres.from") == VULO and C(KIM, "AmisiaDB.softres.from") == VULO, "nothing replaced")

-- 2. a second import 3 s after the first reaches the raid within the gap, not after 240 s
C(VULO, [[NS.SetSoftRes("Anna 18814"); NS.SoftResShareNow()]])
BUS.tick(3)
C(VULO, [[NS.SetSoftRes("Anna 18814\nKim Eisherz 19019"); NS.SoftResShareNow()]])
BUS.tick(25)
assert(C(KIM, "NS.ReservedBy(19019)[1]") == KIM, "the second list arrived")
-- a clear right after an import still clears the copies
C(VULO, [[NS.SetSoftRes("Anna 32235"); NS.SoftResShareNow()]])
BUS.tick(9)
assert(C(KIM, "NS.ReservedBy(32235)[1]") == "Anna")
C(VULO, "NS.ClearSoftRes()")
BUS.tick(15)
assert(C(KIM, "AmisiaDB.softres == nil"), "cleared")

-- 3. an officer in the raider view keeps his own list (an offer only)
C(FRAK, [[NS.SetSoftRes("Fraktur 32235"); AmisiaDB.softres.at = AmisiaDB.softres.at - 600; NS.Set("ui.view", "raider")]])
C(VULO, [[NS.SetSoftRes("Anna 32837"); NS.SoftResShareNow()]])
BUS.tick(15)
assert(C(FRAK, "AmisiaDB.softres.from == nil and NS.ReservedBy(32235)[1] == 'Fraktur'"), "own list kept in the raider view")
C(FRAK, [[NS.Reset("ui.view")]])
assert(C(FRAK, "NS.SoftResOffer() and NS.SoftResOffer().from") == VULO, "offered")
-- 4. his own newer import makes the offer old
C(FRAK, [[NS.SetSoftRes("Fraktur 32837")]])
assert(C(FRAK, "NS.SoftResOffer() == nil and NS.TakeSoftResOffer() == false"), "the old offer is gone")

-- 5. a list the receivers would refuse is not announced (an old saved list with a long name)
local sv = BUS.count({ kind = "SV", sender = VULO })
C(VULO, [[NS.SetSoftRes("Anna 32235"); AmisiaDB.softres.byItem[32235] = { string.rep("x", 60) }; NS.SoftResShareNow()]])
BUS.tick(15)
assert(BUS.count({ kind = "SV", sender = VULO }) == sv, "not announced")
