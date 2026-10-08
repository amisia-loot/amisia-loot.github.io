--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- DKP standings and award costs shared in the raid (Raid/PointsSync.lua): Vulo Sturmwind is master
-- looter, officer and sync keeper; Fraktur an officer, Kim Eisherz a raider, Pug a guest outside
-- the guild. The keeper announces its standings (KV), the others ask (KQ) and get them whole (KS); an
-- officer who sets the cost of an award tells the raid (KC) and the other officers take the newer
-- one. A raider sees the live standing; forged and broken messages and those of raiders and guests
-- are refused; with points.share off nothing is asked or taken; a rolling guild sends nothing.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local SITE = "#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=10 boss=0 time=0 bench=0 mode=bid min=10 step=5 pub=1\nP Vulo_Sturmwind 100\nP Fraktur 80\nP Kim_Eisherz 300\n#END"

local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end

BUS.setRaid({ VULO, FRAK, KIM, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.now = 1791400000
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        if not STUB.officer then NS.Set("ui.view", "raider") end
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true, "Vulo keeps the raid")
assert(BUS.count({ kind = "KV" }) == 0, "a rolling guild announces nothing")
local KEY = S(VULO, "NS.RaidKey(s)")

-- the officers paste the site's block; the keeper announces, the raider asks and gets the standings
assert(C(VULO, ("return NS.SetPointsSite(%q) ~= nil"):format(SITE)))
assert(C(FRAK, ("return NS.SetPointsSite(%q) ~= nil"):format(SITE)))
assert(S(VULO, "s.points and s.points.sys") == "dkp", "the running raid takes the system")
BUS.tick(20)
assert(BUS.count({ kind = "KV", sender = VULO, chan = "RAID" }) >= 1, "the keeper announced")
assert(BUS.count({ kind = "KV", sender = FRAK }) == 0 and BUS.count({ kind = "KV", sender = KIM }) == 0, "only the keeper")
assert(BUS.count({ kind = "KQ", sender = KIM, chan = "WHISPER" }) >= 1, "the raider asked")
assert(C(KIM, "NS.PointsSystem()") == "dkp", "the raider follows the keeper's system")
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 310, "the live standing: 300 and the raid: " .. tostring(C(KIM, "NS.PointsOf('Kim Eisherz').a")))
assert(C(KIM, "#NS.PointsStandings()") == 4, "the list of the group (the site shows it), the guest with his raid points")
assert(C(PUG, "NS.PointsSharedList and NS.PointsSharedList() == nil"), "the guest gets nothing")

-- an award with a cost at the keeper: KC to the raid, Fraktur takes it, the raider sees the new standing
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 32235, kind = 'MS', src = 'Ragnaros', t = time() }).id")
assert(S(VULO, ("NS.SetAwardPoints(s, %q, 60) ~= nil"):format(a1)))
assert(BUS.count({ kind = "KC", sender = VULO, chan = "RAID" }) == 1, "the cost goes out")
BUS.tick(30)
assert(S(FRAK, ("NS.AwardPoints(s, %q) and NS.AwardPoints(s, %q).n"):format(a1, a1)) == 60, "the officer took the cost")
assert(C(FRAK, "NS.PointsOf('Kim Eisherz').a") == 250, "and counts it: " .. tostring(C(FRAK, "NS.PointsOf('Kim Eisherz').a")))
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 250, "the raider's live standing: " .. tostring(C(KIM, "NS.PointsOf('Kim Eisherz').a")))
assert(S(KIM, ("NS.AwardPoints(s, %q)"):format(a1)) == nil, "a raider keeps no costs")

-- a non-keeper officer changes the cost: the keeper takes it (newer) and shares it again
assert(S(FRAK, ("NS.SetAwardPoints(s, %q, 40) ~= nil"):format(a1)))
BUS.tick(30)
assert(S(VULO, ("NS.AwardPoints(s, %q).n"):format(a1)) == 40, "the keeper took Fraktur's change")
assert(S(VULO, ("NS.AwardPoints(s, %q).by"):format(a1)) == FRAK)
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 270, "and the raid sees it")
-- an older cost changes nothing
S(FRAK, ([[NS.CommSend("KC", { %q, %q, "D", "99", tostring(time() - 3600) }, "RAID")]]):format(KEY, a1))
BUS.tick(5)
assert(S(VULO, ("NS.AwardPoints(s, %q).n"):format(a1)) == 40, "an older cost is left")

-- forged and broken: a raider's cost, a guest's standings, a broken list, another raid
local before = S(VULO, ("NS.AwardPoints(s, %q).n"):format(a1))
S(KIM, ([[NS.CommSend("KC", { %q, %q, "D", "1", tostring(time() + 10) }, "RAID")]]):format(KEY, a1))
BUS.tick(5)
assert(S(VULO, ("NS.AwardPoints(s, %q).n"):format(a1)) == before and S(FRAK, ("NS.AwardPoints(s, %q).n"):format(a1)) == before, "a raider's cost is refused")
local forged = [[return NS.CommSendBlob("KS", %q, { v = 1, sys = "dkp", cfg = { min = 1, step = 1, seal = 0, mode = "bid", pub = 1 },
    s = { { "Kim Eisherz", 9999, 0 } }, c = {} }, "WHISPER", %q)]]
C(PUG, forged:format(KEY, KIM))
BUS.tick(5)
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 270, "a guest's list is refused")
C(FRAK, forged:format(KEY, KIM))
BUS.tick(5)
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 9999, "an officer's list in the group is taken (whole)")
local refused = C(KIM, "NS.PointsSyncStats().refused")
C(FRAK, ([[return NS.CommSendBlob("KS", %q, { v = 1, sys = "dkp", cfg = {}, s = { { "Kim1", 5, 0 } }, c = {} }, "WHISPER", %q)]]):format(KEY, KIM))
C(FRAK, ([[return NS.CommSendBlob("KS", %q, { v = 1, sys = "golf", cfg = {}, s = {}, c = {} }, "WHISPER", %q)]]):format(KEY, KIM))
C(FRAK, ([[return NS.CommSendBlob("KS", %q, { v = 1, sys = "dkp", cfg = {}, s = { { "Kim Eisherz", 1.5, 0 } }, c = {} }, "WHISPER", %q)]]):format(KEY, KIM))
BUS.tick(5)
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 9999 and C(KIM, "NS.PointsSyncStats().refused") == refused + 3, "broken lists are refused whole")
C(FRAK, ([[return NS.CommSendBlob("KS", "2020-01-01:1", { v = 1, sys = "dkp", cfg = {}, s = { { "Kim Eisherz", 1, 0 } }, c = {} }, "WHISPER", %q)]]):format(KIM))
BUS.tick(5)
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 9999, "another raid's list is left")
-- the keeper's next announcement brings the right list back
S(VULO, ("NS.SetAwardPoints(s, %q, 41)"):format(a1))
BUS.tick(30)
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 269, "back to the keeper's: " .. tostring(C(KIM, "NS.PointsOf('Kim Eisherz').a")))

-- points.share off: no asking, no taking
C(KIM, "NS.Set('points.share', false)")
local asked = BUS.count({ kind = "KQ", sender = KIM })
S(VULO, ("NS.SetAwardPoints(s, %q, 50)"):format(a1))
BUS.tick(30)
assert(BUS.count({ kind = "KQ", sender = KIM }) == asked, "no question with sharing off")
assert(C(KIM, "NS.PointsOf('Kim Eisherz').a") == 269)
assert(C(FRAK, "NS.PointsOf('Kim Eisherz').a") == 260, "the officer still follows")
