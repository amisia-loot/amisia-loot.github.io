--[[clients Vulo_Sturmwind Kim_Eisherz Ada_Hall Pug Neu_Ling]]
-- The raid note shared with the raid (F-196, D-126): Vulo Sturmwind (officer) sends it into the raid;
-- Kim Eisherz (raider) takes it and sees the chat line and the window; Ada Hall (an assistant, no
-- officer) may send, Kim may not (his note is refused); Pug outside the guild gets nothing; Neu Ling
-- joins later and gets it by NV/NQ. A whisper nobody asked for and a forged text are refused.
local VULO, KIM, ADA, PUG, NEU = "Vulo Sturmwind", "Kim Eisherz", "Ada Hall", "Pug", "Neu Ling"

BUS.setRaid({ VULO, KIM, ADA, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = KIM, rank = 4 }, { name = ADA, rank = 4 }, { name = NEU, rank = 4 } })
local function setup(name)
    C(name, [[STUB.rankFlags = { [1] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind"
        if not STUB.officer then NS.Set("ui.view", "raider") end
        if STUB.player == "Pug" then STUB.inGuild = false end
        for _, m in ipairs(STUB.roster) do if m.name == "Ada Hall" then m.rank = 1 end end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]])
end
for _, name in ipairs(CLIENTS) do setup(name) end
BUS.tick(5)

-- who may send
assert(C(VULO, "return (NS.RaidNote.CanSend())") == true, "the officer")
assert(C(ADA, "return (NS.RaidNote.CanSend())") == true, "the assistant")
assert(C(KIM, "return (NS.RaidNote.CanSend())") == false, "a raider without a rank")
assert(C(KIM, "return NS.RaidNote.Send('x')") == nil)

-- the officer sends: everyone in the raid and the guild takes it
local NOTE = "{totenkopf} Tank: Kim Eisherz\nHeiler: Ada Hall"
assert(C(VULO, ("return NS.RaidNote.Send(%q)"):format(NOTE)) == true)
BUS.tick(5)
local H = C(VULO, "return NS.RaidNote.Current().h")
assert(H and C(KIM, "return NS.RaidNote.Current() and NS.RaidNote.Current().h") == H, "the raider has it")
assert(C(KIM, "return NS.RaidNote.Current().by") == VULO)
assert(C(ADA, "return NS.RaidNote.Current() ~= nil"), "the assistant has it")
assert(C(PUG, "return NS.RaidNote.Current() == nil"), "the guest outside the guild has nothing")
assert(C(KIM, "return _G.AmisiaRaidNote ~= nil and _G.AmisiaRaidNote:IsShown()"), "the window opened by itself")
assert(C(KIM, "return _G.AmisiaRaidNote.note.fs:GetText():find('|cffffd100', 1, true) ~= nil"), "Kim's line in gold")
-- a second note within 10 s is held
assert(C(VULO, "return NS.RaidNote.Send('zu schnell')") == nil)

-- too long: refused, not cut
BUS.tick(11)
assert(C(VULO, "return NS.RaidNote.Send(('ä'):rep(2001))") == nil, "too long")
-- an old note is neither taken nor announced
local refusedOld = C(KIM, "return NS.RaidNote.Stats().refused")
C(VULO, [[local id = NS.ServerTime() - 13 * 3600
    NS.CommSendBlob("RN", "2026-01-01:" .. id, { v = 1, id = id, at = id, t = "alt" }, "RAID")]])
BUS.tick(5)
assert(C(KIM, "return NS.RaidNote.Stats().refused") == refusedOld + 1, "an old note refused")

-- the latecomer asks after the announcement
BUS.setRaid({ VULO, KIM, ADA, PUG, NEU })
setup(NEU)
-- a new roster: Ada is the assistant again on every client
for _, name in ipairs(CLIENTS) do
    C(name, [[for _, m in ipairs(STUB.roster) do if m.name == "Ada Hall" then m.rank = 1 end end
        STUB.fire("GROUP_ROSTER_UPDATE")]])
end
BUS.tick(30)
assert(BUS.count({ kind = "NV", sender = VULO, chan = "RAID" }) >= 1, "announced")
assert(BUS.count({ kind = "NQ", sender = NEU, chan = "WHISPER" }) >= 1, "the latecomer asked")
assert(C(NEU, "return NS.RaidNote.Current() and NS.RaidNote.Current().h") == H, "the latecomer has it")
local nq = BUS.count({ kind = "NQ", sender = KIM })
BUS.tick(250)
assert(BUS.count({ kind = "NQ", sender = KIM }) == nq, "who has it does not ask again")

-- the assistant sends a newer one: it replaces the officer's
BUS.tick(15)
assert(C(ADA, "return NS.RaidNote.Send('Neu: {stern} Kick')") == true)
BUS.tick(5)
assert(C(KIM, "return NS.RaidNote.Current().by") == ADA and C(VULO, "return NS.RaidNote.Current().by") == ADA, "replaced")

-- a raider without a rank forging a note: refused
local refused = C(VULO, "return NS.RaidNote.Stats().refused")
C(KIM, [[local id = NS.ServerTime() + 5
    NS.CommSendBlob("RN", date("%Y-%m-%d") .. ":" .. id, { v = 1, id = id, at = id, t = "falsch" }, "RAID")]])
BUS.tick(5)
assert(C(VULO, "return NS.RaidNote.Stats().refused") == refused + 1 and C(VULO, "return NS.RaidNote.Current().by") == ADA, "a raider's note refused")
-- an unasked whisper from the assistant: refused
refused = C(NEU, "return NS.RaidNote.Stats().refused")
C(ADA, [[local id = NS.ServerTime() + 9
    NS.CommSendBlob("RN", date("%Y-%m-%d") .. ":" .. id, { v = 1, id = id, at = id, t = "geflüstert" }, "WHISPER", "Neu Ling")]])
BUS.tick(5)
assert(C(NEU, "return NS.RaidNote.Stats().refused") == refused + 1, "not asked: refused")
-- a text with a control character: refused
refused = C(KIM, "return NS.RaidNote.Stats().refused")
BUS.tick(15)
C(ADA, [[local id = NS.ServerTime() + 20
    NS.CommSendBlob("RN", date("%Y-%m-%d") .. ":" .. id, { v = 1, id = id, at = id, t = "a\7b" }, "RAID")]])
BUS.tick(5)
assert(C(KIM, "return NS.RaidNote.Stats().refused") == refused + 1, "a dirty text refused")

-- in a fight nothing is sent and a new note does not open the window until after it
C(KIM, [[_G.AmisiaRaidNote:Hide(); STUB.combat = true]])
BUS.tick(15)
assert(C(ADA, "return NS.RaidNote.Send('Phase 2')") == true)
BUS.tick(5)
assert(C(KIM, "return NS.RaidNote.Current().text") == "Phase 2" and C(KIM, "return _G.AmisiaRaidNote:IsShown()") == false, "held in the fight")
C(KIM, [[STUB.combat = false; STUB.fire("PLAYER_REGEN_ENABLED")]])
assert(C(KIM, "return _G.AmisiaRaidNote:IsShown()") == true, "after the fight")
C(ADA, "STUB.combat = true")
BUS.tick(15)
assert(C(ADA, "return NS.RaidNote.Send('nicht jetzt')") == nil, "not in a fight")
C(ADA, "STUB.combat = false")
-- a week later the sender's old note is not announced again
local nv = BUS.count({ kind = "NV", sender = ADA })
C(ADA, "local c = NS.RaidNote.Current(); c.id = c.id - 13 * 3600; c.at = c.id")
for _, name in ipairs(CLIENTS) do C(name, [[STUB.fire("GROUP_ROSTER_UPDATE")]]) end
BUS.tick(250)
assert(BUS.count({ kind = "NV", sender = ADA }) == nv, "an old note is not announced")
print("raid note share ok")
