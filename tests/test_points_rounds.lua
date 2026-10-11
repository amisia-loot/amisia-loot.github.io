-- DKP bids and the EPGP need/greed list in the roll window (Raid/PointsRounds.lua with Rolls.lua):
-- "!bid 50" in the raid chat or whispered (open and sealed, minimum, step, at most the own standing,
-- hostile text, strangers), the winner and ties (sealed: the higher standing, else a roll-off), the
-- window's rows, bids and need/greed entered by hand, "!need"/"!greed" sorted by PR (minimum EP),
-- fixed DKP prices, the award with its cost (master loot and the dialog), and rolling unchanged.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastChat() return STUB.chat[#STUB.chat] and STUB.chat[#STUB.chat].text or "" end
local function chatHas(part)
    for _, c in ipairs(STUB.chat) do if has(c.text, part) then return c end end
    return nil
end
local function say(text, sender, event) STUB.fire(event or "CHAT_MSG_RAID", text, sender) end
local function whisper(text, sender) STUB.fire("CHAT_MSG_WHISPER", text, sender) end
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end
-- a new raid (it freezes the system of now): out of the instance, three hours later back in
local function newRaid()
    STUB.instance = { name = "Shattrath", type = "none", id = 0 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    STUB.now = STUB.now + 3 * 3600
    STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    return NS.Active()
end
local ZERO = "raid=0 boss=0 time=0 bench=0 "

STUB.now = 1791400000
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
                { name = "Kim Eisherz", class = "MAGE" }, { name = "Anna", class = "DRUID" } }
STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
local link = STUB.item(30000, "Brustplatte", 4)
STUB.items[30000].ilvl, STUB.items[30000].equipLoc = 92, "INVTYPE_CHEST"

-- rolling is untouched while no system is chosen
assert(NS.StartRoll(link, 10))
local r = NS.CurrentRoll()
assert(r.mode == nil and has(lastChat(), "/roll 99"), lastChat())
say("!bid 50", "Fraktur")
assert(next(r.rolls) == nil, "a bid means nothing in a roll round")
NS.StopRoll()

---------------------------------------------------------------------------
-- open bids
---------------------------------------------------------------------------
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG " .. ZERO .. "mode=bid seal=0 min=10 step=5\nP Vuloo 100\nP Fraktur 80\nP Chorf 200\nP Kim_Eisherz 60\nP Anna 5\n#END"))
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.points.sys == "dkp")
local before = #STUB.chat
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
assert(r.mode == "bid", "a DKP guild bids")
assert(has(STUB.chat[before + 1].text, "!bid") and has(STUB.chat[before + 1].text, "10") and has(STUB.chat[before + 1].text, "20 Sekunden"), STUB.chat[before + 1].text)
roll("Fraktur", 99, 1, 100)
assert(next(r.rolls) == nil, "a /roll is no bid")
say("!bid 50", "Fraktur")
assert(r.rolls.Fraktur and r.rolls.Fraktur.value == 50 and r.rolls.Fraktur.bal == 80)
assert(chatHas("Höchstgebot: 50 (Fraktur)"), "an open bid is announced")
say("!bid 52", "Chorf")
assert(not r.rolls.Chorf, "under the step")
assert(r.ignored[#r.ignored].name == "Chorf" and has(r.ignored[#r.ignored].why, "mindestens 55"), tostring(r.ignored[#r.ignored].why))
local w = STUB.chat[#STUB.chat]
assert(w.chan == "WHISPER" and w.target == "Chorf" and has(w.text, "mindestens 55"), "the bidder hears why")
whisper("!gebot 55", "Chorf")
assert(r.rolls.Chorf.value == 55, "whispered and in German")
say("!bid 90", "Fraktur")
assert(r.rolls.Fraktur.value == 50 and has(r.ignored[#r.ignored].why, "80"), "more than the own standing")
say("!bid 5", "Anna")
assert(not r.rolls.Anna and has(r.ignored[#r.ignored].why, "Mindestgebot"), "under the minimum")
-- hostile text and strangers
local n = #r.ignored
for _, text in ipairs({ "!bid -5", "!bid 1e3", "!bid 0x40", "!bid 60.5", "!bid |cffff0000|Hitem:1|h[x]|h|r", "!bid " .. ("9"):rep(30), "!bid" }) do
    say(text, "Kim Eisherz")
end
assert(not r.rolls["Kim Eisherz"] and #r.ignored == n + 7, "every hostile bid listed, none taken")
say("!bid 70", "Fremder")
assert(not r.rolls.Fremder and #r.ignored == n + 7, "a stranger is not even listed")
-- an alt bids with the main's standing
NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-08\nA Kimtwink Kim_Eisherz\n#END")
STUB.roster[6] = { name = "Kimtwink", class = "MAGE" }
say("!bid 60", "Kimtwink")
assert(r.rolls.Kimtwink and r.rolls.Kimtwink.bal == 60, "the main's 60")
-- the window
NS.ShowRollFrame()
local F = NS.RollFrame
local first = F.rows[1]
assert(first.who == "Kimtwink" and first.value:GetText() == "60" and has(first.kind:GetText(), "Gebot"), first.kind:GetText())
assert(has(first.up:GetText(), "60"), "the standing beside the bid")
assert(has(F.note:GetText(), "!bid"), F.note:GetText())
STUB.tick(20)
assert(r.done and r.winner == "Kimtwink", tostring(r.winner))
assert(has(lastChat(), "Gewinner: Kimtwink (60 DKP)"), lastChat())
assert(NS.PointsCostFor(30000, "Kimtwink") == 60 and NS.PointsCostFor(30000, "Chorf") == 55 and NS.PointsCostFor(30000, "Anna") == nil)
assert(NS.RollKind(30000, "Kimtwink") == "MS")
say("!bid 99", "Chorf")
assert(r.rolls.Chorf.value == 55, "after the end nothing counts")

-- the hand-out through master loot carries the bid as the cost
STUB.loot = { { link = link, name = "Brustplatte" } }
STUB.fire("LOOT_OPENED")
NS.AwardFromRoll("Kimtwink", 30000, link)
STUB.fire("LOOT_SLOT_CLEARED", 1)
local a = s.awards[#s.awards]
assert(a and a.name == "Kimtwink" and a.kind == "MS")
assert(NS.AwardPoints(s, a.id) and NS.AwardPoints(s, a.id).n == 60, "the bid is the cost")
assert(NS.PointsOf("Kim Eisherz").a < 60, "the main paid: " .. NS.PointsOf("Kim Eisherz").a)
STUB.fire("LOOT_CLOSED")
STUB.loot = {}

---------------------------------------------------------------------------
-- sealed bids
---------------------------------------------------------------------------
NS.Set("points.sealed", true)
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
assert(r.mode == "bid" and r.seal, "sealed")
assert(has(lastChat(), "Flüstern") or has(STUB.chat[#STUB.chat - 1].text, "Flüstern"), lastChat())
say("!bid 50", "Fraktur")
assert(not r.rolls.Fraktur and has(r.ignored[#r.ignored].why, "Flüstern"), "sealed: not in the raid chat")
local said = #STUB.chat
whisper("!bid 50", "Fraktur")
assert(r.rolls.Fraktur.value == 50)
assert(STUB.chat[#STUB.chat].chan == "WHISPER" and has(STUB.chat[#STUB.chat].text, "angenommen"), "a quiet confirmation")
for i = said + 1, #STUB.chat do assert(STUB.chat[i].chan == "WHISPER", "nothing in the raid while sealed") end
whisper("!bid 40", "Fraktur")
assert(r.rolls.Fraktur.value == 50, "sealed: only up")
whisper("!bid 50", "Chorf")
whisper("!bid 45", "Anna")
assert(not r.rolls.Anna, "Anna has 5")
-- Chorf (200) and Fraktur (80) both bid 50: the higher standing wins (the officer's own "!bid" is
-- not read: the client skips its own lines, the loot master enters his bid by hand)
STUB.tick(20)
assert(r.winner == "Chorf", tostring(r.winner))
local list = NS.RollRanking(r)
assert(list[1].name == "Chorf" and list[2].name == "Fraktur" and #list == 2)
-- equal bids and equal standings: a tie, and "Nochmal" rolls among them (ten minutes on: Chorf's
-- won and not handed out 50 no longer count against his standing)
STUB.now = STUB.now + 601
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG mode=bid seal=1 min=10 step=5\nP Vuloo 100\nP Fraktur 100\nP Chorf 100\n#END"))
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
whisper("!bid 70", "Fraktur"); whisper("!bid 70", "Chorf")
STUB.tick(20)
assert(r.tie and #r.tie == 2 and not r.winner, "a tie")
assert(has(lastChat(), "Gleichstand"), lastChat())
assert(NS.RerollTie())
local tb = NS.CurrentRoll()
assert(tb.mode == nil and tb.only, "the tie-break is a roll")
roll("Fraktur", 12, 1, 100); roll("Chorf", 90, 1, 100)
STUB.tick(10)
assert(tb.winner == "Chorf")
assert(NS.PointsCostFor(30000, "Chorf") == 70, "the cost is still the bid")

-- bids by hand (boss fight: the chat is secret)
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
local e, why = NS.AddManualRoll("Chorf", 90, "MS")
assert(e and r.rolls.Chorf.value == 90 and r.rolls.Chorf.manual, tostring(why))
e, why = NS.AddManualRoll("Fraktur", 500, "MS")
assert(not e and has(why, "100"), "by hand too: not over the standing")
e, why = NS.AddManualRoll("Fraktur", 5, "MS")
assert(not e and has(why, "Mindestgebot"), tostring(why))
NS.StopRoll()
assert(r.winner == "Chorf")
NS.Set("points.sealed", false)

---------------------------------------------------------------------------
-- EPGP: need and greed by PR
---------------------------------------------------------------------------
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 epgp 1791300000\nCFG " .. ZERO .. "base=100 minep=50 scale=100 ref=66 os=50\nP Vuloo 500 100\nP Fraktur 300 50\nP Chorf 40 0\nP Kim_Eisherz 600 200\nP Anna 400 100\n#END"))
s = newRaid()
assert(s.points.sys == "epgp")
before = #STUB.chat
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
assert(r.mode == "pr" and r.cost == 200 and r.costOS == 100, tostring(r.cost))
assert(has(STUB.chat[before + 1].text, "!need") and has(STUB.chat[before + 1].text, "200"), STUB.chat[before + 1].text)
say("!need", "Fraktur")          -- 300/150 = 2
NS.AddManualRoll("Vuloo", nil, "MS")   -- 500/200 = 2.5 (the own chat line is never read)
say("!greed", "Kim Eisherz")     -- 600/300 = 2 (greed)
say("!need bitte", "Chorf")      -- 40/100, under the minimum EP
whisper("!bedarf", "Anna")       -- 400/200 = 2
say("!bid 50", "Fraktur")
assert(r.rolls.Fraktur.kind == "MS", "a bid means nothing in a need round")
list = NS.RollRanking(r)
local order = {}
for i, x in ipairs(list) do order[i] = x.name end
assert(table.concat(order, ",") == "Vuloo,Anna,Fraktur,Chorf,Kim Eisherz", table.concat(order, ","))
NS.ShowRollFrame()
assert(F.rows[1].who == "Vuloo" and F.rows[1].value:GetText() == NS.PointsPRText(2.5) and has(F.rows[1].kind:GetText(), "Bedarf"))
assert(has(F.rows[1].up:GetText(), "500/100"), F.rows[1].up:GetText())
-- Fraktur and Anna: both PR 2, Anna has more EP and stands first
STUB.tick(20)
assert(r.winner == "Vuloo")
assert(has(lastChat(), "Vuloo") and has(lastChat(), "PR"), lastChat())
assert(NS.PointsCostFor(30000, "Vuloo") == 200 and NS.PointsCostFor(30000, "Kim Eisherz") == 100, "need full, greed half")
assert(NS.RollKind(30000, "Kim Eisherz") == "OS")
-- a change of mind and a pass
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
say("!need", "Kim Eisherz"); say("!gier", "Kim Eisherz")
assert(r.rolls["Kim Eisherz"].kind == "OS", "the last word counts")
say("!pass", "Kim Eisherz")
assert(not r.rolls["Kim Eisherz"], "passed")
-- need and greed by hand
e = NS.AddManualRoll("Fraktur", nil, "MS")
assert(e and r.rolls.Fraktur.kind == "MS" and r.rolls.Fraktur.manual, "need by hand")
NS.AddManualRoll("Anna", "", "OS")
assert(r.rolls.Anna.kind == "OS")
NS.StopRoll()
assert(r.winner == "Fraktur")

---------------------------------------------------------------------------
-- the award dialog: the cost field
---------------------------------------------------------------------------
NS.ShowAwardDialog(link, s)
local D = AmisiaAwardDialog
assert(D.pts and D.pts:IsShown() and has(D.ptsLabel:GetText(), "GP"), "the GP field")
assert(D.winner:GetValue() == "Fraktur" and D.pts:GetText() == "200", "the round's winner and the full GP: " .. tostring(D.pts:GetText()))
D.kinds.OS:Click()
assert(D.pts:GetText() == "100", "offspec: the share")
D.pts:SetFocus(); D.pts:SetText("150"); D.pts.scripts.OnEnterPressed(D.pts)
D.give:Click()
a = s.awards[#s.awards]
assert(a.name == "Fraktur" and NS.AwardPoints(s, a.id).n == 150 and NS.AwardPoints(s, a.id).p == "G", "the typed amount")
-- back to rolling: the running raid keeps its system (field and need rounds), the next raid rolls
NS.Set("points.system", "roll")
assert(has(STUB.messages[#STUB.messages], "behält sein System (EPGP)"), "the officer hears that the raid keeps its system")
NS.ShowAwardDialog(link, s)
assert(D.pts:IsShown(), "the EPGP raid keeps its cost field")
D:Hide()
assert(NS.StartRoll(link, 10) and NS.CurrentRoll().mode == "pr", "and its need rounds")
NS.StopRoll()
local rolled = newRaid()
assert(rolled.points == nil, "the next raid rolls")
NS.ShowAwardDialog(link, rolled)
assert(not D.pts:IsShown(), "no field in a raid that rolls")
D:Hide()
assert(NS.StartRoll(link, 10) and NS.CurrentRoll().mode == nil, "back to rolling")
NS.StopRoll()

---------------------------------------------------------------------------
-- DKP with fixed prices: need/greed by standing, the price from the formula
---------------------------------------------------------------------------
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG " .. ZERO .. "mode=fixed price=50 ref=66 os=50\nP Vuloo 100\nP Fraktur 300\nP Chorf 300\n#END"))
s = newRaid()
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
assert(r.mode == "pr" and r.cost == 100 and r.costOS == 50, tostring(r.cost))
NS.AddManualRoll("Vuloo", nil, "MS"); say("!need", "Fraktur"); whisper("!os", "Chorf")
list = NS.RollRanking(r)
assert(list[1].name == "Fraktur" and list[2].name == "Vuloo" and list[3].name == "Chorf", "need by standing, then greed")
STUB.tick(20)
assert(r.winner == "Fraktur" and has(lastChat(), "Fraktur"), lastChat())
assert(NS.PointsCostFor(30000, "Fraktur") == 100 and NS.PointsCostFor(30000, "Chorf") == 50)
