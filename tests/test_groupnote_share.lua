--[[clients Leo_Leiter Kim_Eisherz Ada_Hall Neu_Ling]]
-- The group note (F-213, D-138): in a party of five the leader Leo Leiter (not in the guild) sends the note
-- as TN parts over PARTY; Kim Eisherz takes it (chat line, the window "Gruppen-Notiz"); Ada Hall has
-- "Gruppen-Notiz annehmen" off and takes nothing; Kim, no leader, may not send and his forged parts are
-- refused; Neu Ling joins later and gets it again from the leader; leaving the party drops it. The
-- encoding (%XX) and its pieces, the bounds of a group note.
local LEO, KIM, ADA, NEU = "Leo Leiter", "Kim Eisherz", "Ada Hall", "Neu Ling"

local function party(names)
    BUS.setRaid(names)
    for _, name in ipairs(CLIENTS) do
        C(name, [[STUB.party = true
            STUB.leader = STUB.player == "Leo Leiter"
            for _, m in ipairs(STUB.roster) do m.rank = m.name == "Leo Leiter" and 2 or 0 end
            STUB.fire("GROUP_ROSTER_UPDATE")]])
    end
end
BUS.setGuild({ { name = KIM, rank = 4 }, { name = ADA, rank = 4 }, { name = NEU, rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[if STUB.player == "Leo Leiter" then STUB.inGuild = false end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")]])
end
C(ADA, "NS.Set('raidnote.party', false)")
party({ LEO, KIM, ADA })
BUS.tick(10)

-- the encoding: every escape whole, the pieces never cut one or a letter
local ok = C(KIM, [[local RN = NS.RaidNote
    local s = "a|b\n100%\tß" .. ("ä"):rep(200)
    if RN.Decode(RN.Encode(s)) ~= s then return "roundtrip" end
    local enc = RN.Encode(s)
    if enc:find("[|\n\t]") then return "raw codes" end
    local ps = RN.Pieces(enc)
    if table.concat(ps) ~= enc then return "pieces" end
    for _, p in ipairs(ps) do
        if #p > RN.PIECE then return "too long" end
        if p:find("%%%x?$") then return "cut escape" end
        local last = p:byte(#p)
        if last >= 192 then return "cut letter" end
    end
    return true]])
assert(ok == true, tostring(ok))

-- who may send: the leader, not a member
assert(C(LEO, "return NS.RaidNote.Mode()") == "party")
assert(C(LEO, "return (NS.RaidNote.CanSend())") == true, "the leader")
local kimOk, kimWhy = C(KIM, "return NS.RaidNote.CanSend()")
assert(kimOk == false and kimWhy:find("Gruppenleiter", 1, true), tostring(kimWhy))
assert(C(KIM, "return NS.RaidNote.Send('x')") == nil)
-- too long for a group note
assert(C(LEO, ("return NS.RaidNote.Send(%q)"):format(("x"):rep(1100))) == nil, "past 1000 bytes")

-- the leader sends: Kim takes it, Ada (off) does not
local NOTE = "{totenkopf} zuerst\nKim Eisherz unterbricht | den Heiler\n" .. ("Taktik "):rep(40)
assert(C(LEO, ("return NS.RaidNote.Send(%q)"):format(NOTE)) == true)
BUS.tick(5)
assert(BUS.count({ kind = "TN", sender = LEO, chan = "PARTY" }) >= 2, "in parts over PARTY")
assert(BUS.count(function(m) return m.kind == "TN" and m.chan ~= "PARTY" end) == 0, "only PARTY")
local H = C(LEO, "return NS.RaidNote.Party().h")
assert(H and C(KIM, "return NS.RaidNote.Party() and NS.RaidNote.Party().h") == H, "Kim has it whole")
assert(C(KIM, ("return NS.RaidNote.Party().text == %q"):format(NOTE)), "the same text")
assert(C(KIM, "return NS.RaidNote.Party().by") == LEO)
assert(C(ADA, "return NS.RaidNote.Party() == nil"), "Ada's switch is off")
assert(C(KIM, "return _G.AmisiaRaidNote ~= nil and _G.AmisiaRaidNote:IsShown()"), "the window opened")
assert(C(KIM, "return _G.AmisiaRaidNote:GetTitleText():GetText()") == "Gruppen-Notiz", "its title")
assert(C(KIM, "return _G.AmisiaRaidNote.note.fs:GetText():find('||', 1, true) ~= nil"), "the bar defused")
assert(C(KIM, "for _, m in ipairs(STUB.messages) do if m:find('Gruppen-Notiz von Leo Leiter', 1, true) then return true end end return false"),
    "the chat line")

-- a forged note from Kim (no leader) is refused
local before = C(LEO, "return NS.RaidNote.Party().h")
C(KIM, [[NS.CommSend("TN", { tostring(NS.ServerTime()), "1", "1", NS.Checksum("Fake"), "Fake" }, "PARTY")]])
BUS.tick(2)
assert(C(LEO, "return NS.RaidNote.Party().h") == before, "the leader keeps his own")
assert(C(KIM, "return NS.RaidNote.Party().h") == H, "Kim keeps the leader's")

-- Neu joins later: the leader sends it again
party({ LEO, KIM, ADA, NEU })
BUS.tick(20)
assert(C(NEU, "return NS.RaidNote.Party() and NS.RaidNote.Party().h") == H, "the newcomer has it")

-- a new note right after the newcomer's copy reaches him too (no hold on the receiving side)
local NOTE2 = "Neue Taktik"
BUS.tick(11)
assert(C(LEO, ("return NS.RaidNote.Send(%q)"):format(NOTE2)) == true)
BUS.tick(5)
local H2 = C(LEO, "return NS.RaidNote.Party().h")
assert(C(NEU, "return NS.RaidNote.Party().h") == H2 and C(KIM, "return NS.RaidNote.Party().h") == H2, "the newer note everywhere")
H = H2
-- in the chat lockdown a resend waits and goes once it is over
BUS.tick(11)
BUS.lock(true)
local tnLocked = BUS.count({ kind = "TN" })
C(LEO, "NS.RaidNote.Resend()")
BUS.tick(2)
assert(BUS.count({ kind = "TN" }) == tnLocked, "held in the lockdown")
BUS.lock(false)
BUS.tick(3)
assert(BUS.count({ kind = "TN" }) > tnLocked, "sent after the lockdown")

-- a /reload of Kim: he still has it, a question does not make the leader resend it
BUS.reload(KIM)
C(KIM, [[STUB.party = true; STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD", false, true)]])
local tn = BUS.count({ kind = "TN" })
BUS.tick(15)
assert(C(KIM, "return NS.RaidNote.Party() and NS.RaidNote.Party().h") == H, "kept over the reload")
assert(BUS.count({ kind = "TQ", sender = KIM }) >= 1, "Kim asked")
assert(BUS.count({ kind = "TN" }) == tn, "the same hash: no resend")

-- leaving the party drops it
party({ LEO, ADA, NEU })
C(KIM, "STUB.roster = {}; STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(KIM, "return NS.RaidNote.Party() == nil"), "gone with the party")

print("group note share: encoding, leader only, parts over PARTY, outside the guild, switch, forged, newcomer, reload, leave")
