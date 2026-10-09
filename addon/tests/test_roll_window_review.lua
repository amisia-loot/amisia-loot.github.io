--[[clients Vulo_Sturmwind Kim_Eisherz Kim Fraktur]]
-- The roll window in a raid, review cases (RollWindow.lua, PointsRounds.lua, D-38): an answer from
-- the window counts for the right raider also when the client adds a realm ending to the addon
-- sender; a first name two raiders share ("Kim" and "Kim Eisherz") books a bid for the one who sent
-- it, never the first of them; a round held by the lockdown longer than a few seconds falls instead
-- of starting the raiders' clocks late.
local VULO, KIMS, KIM, FRAK = "Vulo Sturmwind", "Kim Eisherz", "Kim", "Fraktur"
local LINK = "|cffa335ee|Hitem:32235::::::::70:::::|h[Cursed Vision of Sargeras]|h|r"

local function shown(name) return C(name, "AmisiaRollWindow ~= nil and AmisiaRollWindow:IsShown()") == true end

BUS.setRaid({ VULO, KIMS, KIM, FRAK })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = KIMS, rank = 4 }, { name = KIM, rank = 4 }, { name = FRAK, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.rankFlags = { [1] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
        RandomRoll = function() end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.NeedCanAsk()") == true, "Vulo leads the loot")

-- a DKP raid with bids
C(VULO, [[NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 mode=bid seal=0 min=10 step=5\nP Vulo_Sturmwind 100\nP Kim_Eisherz 60\nP Kim 80\nP Fraktur 40\n#END")]])
C(VULO, "STUB.instance = { name = 'Shattrath', type = 'none', id = 0 }; STUB.fire('PLAYER_ENTERING_WORLD')")
BUS.tick(3)
C(VULO, "STUB.now = STUB.now + 4 * 3600; STUB.instance = { name = 'Naxxramas', type = 'raid', id = 533 }; STUB.fire('PLAYER_ENTERING_WORLD')")
BUS.tick(3)

---------------------------------------------------------------------------
-- the addon sender carries the realm: the window's bid still counts for its raider
---------------------------------------------------------------------------
C(VULO, ("NS.StartRoll(%q, 30)"):format(LINK))
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().mode") == "bid")
assert(shown(FRAK), "Fraktur sees the bid round")
BUS.realm = "-Realm"
C(FRAK, "local r = AmisiaRollWindow.rows[1]; r.bidEdit:SetText('20'); r.bidBtn:Click()")
BUS.tick(0.5)
assert(C(VULO, "local e = NS.CurrentRoll().rolls.Fraktur; return e ~= nil and e.value == 20"), "the bid of Fraktur-Realm counts for Fraktur")

---------------------------------------------------------------------------
-- "Kim" bids: the bid is Kim's, not Kim Eisherz's (the first Kim of the raid)
---------------------------------------------------------------------------
C(KIM, "local r = AmisiaRollWindow.rows[1]; r.bidEdit:SetText('70'); r.bidBtn:Click()")
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().rolls['Kim Eisherz'] == nil"), "nothing booked for Kim Eisherz")
assert(C(VULO, "local e = NS.CurrentRoll().rolls.Kim; return e ~= nil and e.value == 70"), "Kim's bid of 70 (her standing 80) counts for Kim")
-- the whispered word, raw sender "Kim": the same
BUS.realm = ""
C(VULO, "STUB.fire('CHAT_MSG_WHISPER', '!bid 75', 'Kim')")
assert(C(VULO, "return NS.CurrentRoll().rolls.Kim.value") == 75 and C(VULO, "return NS.CurrentRoll().rolls['Kim Eisherz'] == nil"),
    "a whispered !bid of Kim is Kim's")
C(VULO, "NS.StopRoll()")
BUS.tick(6)
C(VULO, "NS.Set('points.system', 'roll')")
C(VULO, "STUB.instance = { name = 'Shattrath', type = 'none', id = 0 }; STUB.fire('PLAYER_ENTERING_WORLD')")
BUS.tick(3)
C(VULO, "STUB.now = STUB.now + 4 * 3600; STUB.instance = { name = 'Naxxramas', type = 'raid', id = 533 }; STUB.fire('PLAYER_ENTERING_WORLD')")
BUS.tick(3)

---------------------------------------------------------------------------
-- a round held by the lockdown for longer than a few seconds never reaches the raiders late
---------------------------------------------------------------------------
BUS.lock(true)
C(VULO, ("NS.StartRoll(%q, 30)"):format(LINK))
assert(C(VULO, "return NS.CurrentRoll().mode") == nil, "a rolling round")
BUS.tick(10)
BUS.lock(false)
BUS.tick(1)
assert(not shown(FRAK), "the round held 10 s falls: the raider's clock would show 30 s with 19 s left")
C(VULO, "NS.StopRoll()")
BUS.tick(6)
-- a short hold still delivers it
BUS.lock(true)
C(VULO, ("NS.StartRoll(%q, 30)"):format(LINK))
BUS.tick(2)
BUS.lock(false)
BUS.tick(1)
assert(shown(FRAK), "held 2 s: the round arrives")
print("roll window review ok")
