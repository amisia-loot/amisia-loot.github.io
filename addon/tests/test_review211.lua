-- Review of DKP/EPGP (Raid/Points.lua, PointsRounds.lua, PointsSync.lua, Rolls.lua, AwardDialog.lua):
-- an earlier round's item still carries its bid and kind when it is handed out after later rounds;
-- a bid is capped by the standing less the bids won and not paid yet; a raid recorded while the guild
-- rolled gets no points afterwards (no cost, no earnings for everyone), and a switch of the system
-- leaves the running raid alone; a loot master outside the officers hears that the cost needs an
-- officer; the keeper's KS blob fits its 20 parts and takes keys of newer versions; costs and
-- corrections carry the realm's time; corrections the site does not have are never dropped; the
-- roll window's value cell fits a six-digit bid.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function msgSince(from, part)
    for i = from + 1, #STUB.messages do if has(STUB.messages[i], part) then return STUB.messages[i] end end
    return nil
end
local function say(text, sender, event) STUB.fire(event or "CHAT_MSG_RAID", text, sender) end
local function leave()
    STUB.instance = { name = "Shattrath", type = "none", id = 0 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
end
local function enter()
    STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    return NS.Active()
end
local DKP = "#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 mode=bid seal=0 min=10 step=5\n"

STUB.now = 1791400000
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
local link = STUB.item(30000, "Brustplatte", 4)
local link2 = STUB.item(30001, "Helm", 4)
STUB.items[30000].ilvl, STUB.items[30000].equipLoc = 92, "INVTYPE_CHEST"

---------------------------------------------------------------------------
-- an earlier round: its winner, its bid and its kind; won bids count against the standing
---------------------------------------------------------------------------
assert(NS.SetPointsSite(DKP .. "P Vuloo 100\nP Fraktur 200\nP Chorf 100\n#END"))
local s = enter()
assert(s and s.points and s.points.sys == "dkp")
assert(NS.StartRoll(link, 20)); local r1 = NS.CurrentRoll()
say("!bid 100", "Fraktur"); STUB.tick(21)
assert(r1.winner == "Fraktur")
assert(NS.StartRoll(link2, 20)); local r2 = NS.CurrentRoll()
say("!bid 150", "Fraktur")
assert(not r2.rolls.Fraktur, "200 less the 100 won and not paid: 150 is too much")
assert(has(r2.ignored[#r2.ignored].why, "100"), tostring(r2.ignored[#r2.ignored].why))
say("!bid 100", "Fraktur")
assert(r2.rolls.Fraktur and r2.rolls.Fraktur.value == 100, "100 is free")
STUB.tick(21)
assert(r2.winner == "Fraktur")
-- the first item's round is found after the second one ended
assert(NS.PointsCostFor(30000, "Fraktur") == 100, tostring(NS.PointsCostFor(30000, "Fraktur")))
assert(NS.RollKind(30000, "Fraktur") == "MS", NS.RollKind(30000, "Fraktur"))
-- both handed out through master loot when the loot window is emptied
STUB.loot = { { link = link, name = "Brustplatte" }, { link = link2, name = "Helm" } }
STUB.fire("LOOT_OPENED")
NS.AwardFromRoll("Fraktur", 30000, link)
STUB.fire("LOOT_SLOT_CLEARED", 1)
local a1 = s.awards[#s.awards]
assert(a1.item == 30000 and a1.kind == "MS", tostring(a1.kind))
assert(NS.AwardPoints(s, a1.id) and NS.AwardPoints(s, a1.id).n == 100, "the earlier round's bid is the cost")
NS.AwardFromRoll("Fraktur", 30001, link2)
STUB.fire("LOOT_SLOT_CLEARED", 2)
local a2 = s.awards[#s.awards]
assert(a2.item == 30001 and NS.AwardPoints(s, a2.id).n == 100)
STUB.fire("LOOT_CLOSED"); STUB.loot = {}
assert(NS.PointsOf("Fraktur").a == 0, "both paid: " .. NS.PointsOf("Fraktur").a)
-- paid wins no longer count twice: Chorf won, was paid, and bids his remaining standing
assert(NS.StartRoll(link, 20)); local r3 = NS.CurrentRoll()
say("!bid 60", "Chorf"); STUB.tick(21)
local a3 = NS.AddAwardTo(s, { name = "Chorf", item = 30000, kind = "MS", src = "x", t = time() })
assert(NS.SetAwardPoints(s, a3.id, NS.PointsCostFor(30000, "Chorf")) and NS.PointsOf("Chorf").a == 40)
assert(NS.StartRoll(link2, 20)); local r4 = NS.CurrentRoll()
say("!bid 40", "Chorf")
assert(r4.rolls.Chorf and r4.rolls.Chorf.value == 40, "the paid win is in the standing once")
NS.StopRoll()

-- the roll window: a six-digit bid fits its cell
assert(NS.SetPointsSite(DKP .. "P Vuloo 100\nP Fraktur 999999\nP Chorf 100\n#END"))
assert(NS.StartRoll(link, 20)); local big = NS.CurrentRoll()
say("!bid 123456", "Fraktur")
say("!bid 999999", "Chorf")
NS.ShowRollFrame()
local F = NS.RollFrame
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(F, F:GetWidth(), F:GetHeight())
assert(F.rows[1].value:GetText() == "123k", F.rows[1].value:GetText())
Lay.fits(F.rows[1].value)
assert(has(F.rows[2].value:GetText(), "999k"), "a refused bid is short too: " .. F.rows[2].value:GetText())
Lay.fits(F.rows[2].value)
NS.StopRoll()
F:Hide()

---------------------------------------------------------------------------
-- a raid recorded while the guild rolled stays without points
---------------------------------------------------------------------------
leave()
NS.ClearPoints()
NS.Set("points.system", "roll")
STUB.now = STUB.now + 86400
local old = enter()
assert(old and old ~= s and old.points == nil, "a roll raid")
-- the guild switches during the raid: the raid keeps rolling, the officer hears it
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 epgp 1791300000\nCFG raid=10 boss=10 time=5 bench=10 base=100 scale=100 ref=66 os=50\nP Vuloo 0 0\nP Fraktur 0 0\n#END"))
assert(old.points == nil, "a paste does not convert the running raid")
assert(has(lastMsg(), "bleibt beim Würfeln"), lastMsg())
assert(NS.StartRoll(link, 10) and NS.CurrentRoll().mode == nil, "its rounds stay rolls")
NS.StopRoll()
NS.Dispatch("punkteraid aus")
assert(has(lastMsg(), "kein Punktesystem") and old.points == nil, lastMsg())
leave()
STUB.now = STUB.now + 86400
assert(NS.PointsOf("Vuloo").a == 0)
-- an officer adds a forgotten award to that raid on the Awards page: no cost row, no points
NS.ShowAwardDialog(link, old)
local D = AmisiaAwardDialog
assert(not D.pts:IsShown(), "no cost field for a raid that rolled")
D.winner.onPick("Fraktur"); D.kinds.MS:Click(); D.give:Click()
assert(#old.awards == 1 and old.points == nil, "the award, no points")
assert(NS.PointsOf("Vuloo").a == 0 and NS.PointsOf("Chorf").a == 0, "nobody earns the old raid")
local c, why = NS.SetAwardPoints(old, old.awards[1].id, 200)
assert(c == nil and why == "Dieser Raid hat kein Punktesystem.", tostring(why))
assert(NS.PointsTakeCharge(old, old.awards[1].id, "G", 5, time(), "Fraktur") == false and old.points == nil, "nor from another officer")
local lines = {}
NS.PointsSessionLines(old, lines)
assert(#lines == 0, table.concat(lines, " | "))
-- the next raid takes the new system
local s5 = enter()
assert(s5.points and s5.points.sys == "epgp", "a new raid takes EPGP")

---------------------------------------------------------------------------
-- a loot master outside the officers: the award is kept, the cost waits for an officer
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
assert(not NS.IsOfficerView())
STUB.loot = { { link = link, name = "Brustplatte" } }
STUB.fire("LOOT_OPENED")
local before, said = #s5.awards, #STUB.messages
NS.AwardFromRoll("Fraktur", 30000, link)
NS.PendingAward(1).pts = 150
STUB.fire("LOOT_SLOT_CLEARED", 1)
STUB.fire("LOOT_CLOSED"); STUB.loot = {}
assert(#s5.awards == before + 1, "the award is recorded")
local a5 = s5.awards[#s5.awards]
assert(NS.AwardPoints(s5, a5.id) == nil)
assert(has(msgSince(said, "Offizier"), "150"), "the loot master hears that the cost needs an officer")
NS.Set("ui.view", "auto")
assert(NS.SetAwardPoints(s5, a5.id, 150), "an officer adds it")

---------------------------------------------------------------------------
-- the realm's time for costs, corrections and prio edits
---------------------------------------------------------------------------
local realGST = GetServerTime
GetServerTime = function() return STUB.now + 3600 end
local c5 = NS.SetAwardPoints(s5, a5.id, 140)
assert(c5.at == STUB.now + 3600, "the cost's time: " .. tostring(c5.at))
local x = NS.PointsAdjust("Fraktur", 5, "Nachtrag")
assert(x.t == STUB.now + 3600, "the correction's time")
local e = NS.EditLootPrio(30000, "Fraktur", "")
assert(e and e.at == STUB.now + 3600, "the prio edit's time")
GetServerTime = realGST

---------------------------------------------------------------------------
-- corrections the site does not have are never dropped
---------------------------------------------------------------------------
AmisiaDB.points.adj = {}
for i = 1, 1000 do assert(NS.PointsAdjust("Chorf", 1, "Nr " .. i)) end
local first = AmisiaDB.points.adj[1].id
local n, nwhy = NS.PointsAdjust("Chorf", 1, "eins zu viel")
assert(n == nil and has(nwhy, "exportieren"), tostring(nwhy))
assert(#AmisiaDB.points.adj == 1000 and AmisiaDB.points.adj[1].id == first, "nothing dropped")
local ids = {}
for i = 1, 10 do ids[i] = AmisiaDB.points.adj[i].id end
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 epgp 1791300000\nCFG raid=10\nP Vuloo 0 0\nI " .. table.concat(ids, " ") .. "\n#END"))
assert(#AmisiaDB.points.adj == 990 and NS.PointsAdjust("Chorf", 1, "jetzt geht es"), "room once the site has some")
AmisiaDB.points.adj = {}

---------------------------------------------------------------------------
-- the site names a raid by its key: another officer's recording of it counts once
---------------------------------------------------------------------------
local key = NS.RaidKey(s5)
local mine = NS.PointsOf("Vuloo").a
assert(mine >= 10, "the running raid's EP: " .. mine)
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 epgp 1791300000\nCFG raid=10\nP Vuloo 15 0\nR 20991231000000-533\nK " .. key .. "\n#END"))
assert(NS.PointsOf("Vuloo").a == 15, "the site's 15 alone: " .. NS.PointsOf("Vuloo").a)

---------------------------------------------------------------------------
-- the keeper's blob fits 20 parts, newest costs first; keys of newer versions are left out
---------------------------------------------------------------------------
local roster = {}
for i = 1, 40 do
    roster[i] = { name = ("Spieler%s%s Nachname%s"):format(string.char(65 + i % 26), string.char(97 + math.floor(i / 26)), string.char(97 + (i * 7) % 26)), class = "MAGE" }
end
STUB.roster = roster
STUB.fire("GROUP_ROSTER_UPDATE")
for i = 1, 120 do
    STUB.now = STUB.now + 61
    local aw = NS.AddAwardTo(s5, { name = roster[(i % 40) + 1].name, item = 30000, kind = "MS", src = "x", t = time() })
    assert(NS.SetAwardPoints(s5, aw.id, 100 + i))
end
local blob = NS.PointsShareBlob(s5)
assert(#blob.s == 40, "every main of the group: " .. #blob.s)
assert(#blob.c > 0 and #blob.c < 120, "some costs, not all: " .. #blob.c)
assert(#NS.CommChunks(NS.CommPack(blob)) <= 20, "fits: " .. #NS.CommChunks(NS.CommPack(blob)))
local newest = 0
for _, cst in ipairs(blob.c) do newest = math.max(newest, cst[4]) end
assert(newest == STUB.now, "the newest cost stays")
local ok = NS.PointsCheckShared({ v = 1, sys = "dkp", cfg = { min = 10, step = 5, seal = 0, mode = "bid", pub = 1, future = 7 }, s = { { "Vuloo", 5, 0 } }, c = {} })
assert(ok and ok.cfg.min == 10 and ok.cfg.future == nil, "a newer key is left out")
assert(NS.PointsCheckShared({ v = 1, sys = "dkp", cfg = { min = -1 }, s = {}, c = {} }) == nil, "a known key must be right")
print(("review 211 ok (KS: %d mains, %d of 120 costs, %d parts)"):format(#blob.s, #blob.c, #NS.CommChunks(NS.CommPack(blob))))
