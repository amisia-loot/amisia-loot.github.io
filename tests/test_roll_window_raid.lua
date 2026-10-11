--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Anna Pug]]
-- The roll window in a raid (RollWindow.lua, D-38): the loot lead (Vulo Sturmwind, officer and
-- master looter) starts a round, every raider client with Amisia shows the window, the guest (Pug)
-- and a client with the window off do not; Mainspec rolls through the client and counts at the lead
-- from the system line only; Passen goes as a whisper to the lead only and shows in the lead's roll
-- window ("passt: 1"); a bid and need/greed from the window count exactly like the whispered words,
-- with their checks and replies; the end shows the winner; a tie-break reaches only the tied; an
-- officer who is not the loot lead cannot start a round for others; the lockdown holds the round.
local VULO, FRAK, KIM, ANNA, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Anna", "Pug"
local LINK = "|cffa335ee|Hitem:32235::::::::70:::::|h[Cursed Vision of Sargeras]|h|r"

local function last(kind, sender)
    local out
    for _, m in ipairs(BUS.sent) do
        if m.kind == kind and (not sender or m.sender == sender) then out = m end
    end
    return out
end
local function shown(name) return C(name, "AmisiaRollWindow ~= nil and AmisiaRollWindow:IsShown()") == true end
local function status(name) return C(name, "return AmisiaRollWindow.rows[1].status:GetText()") or "" end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
-- the server's system line of a roll, seen by every client
local function serverRoll(who, v, lo, hi)
    for _, name in ipairs(CLIENTS) do
        C(name, ("STUB.fire('CHAT_MSG_SYSTEM', (RANDOM_ROLL_RESULT):format(%q, %d, %d, %d))"):format(who, v, lo, hi))
    end
end

BUS.setRaid({ VULO, FRAK, KIM, ANNA, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = ANNA, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.item(30000, "Brustplatte", 4)
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
        if STUB.player == "Pug" then STUB.inGuild = false end
        RANDOMS = {}
        RandomRoll = function(lo, hi) RANDOMS[#RANDOMS + 1] = { lo, hi } end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.IsLootLead()") == true and C(VULO, "NS.NeedCanAsk()") == true, "Vulo leads the loot")
assert(C(FRAK, "NS.IsLootLead()") == false)
C(ANNA, "NS.Set('rollwin.enabled', false)")

---------------------------------------------------------------------------
-- the lead starts a round: the raiders with Amisia see the window
---------------------------------------------------------------------------
assert(C(VULO, ("return NS.StartRoll(%q, 20) == true"):format(LINK)))
local wid = C(VULO, "return NS.CurrentRoll().wid")
assert(type(wid) == "string" and #wid == 4)
BUS.tick(0.5)
local ws = last("WS", VULO)
assert(ws and ws.chan == "RAID" and has(ws.text, "item:32235") and not has(ws.text, "|"), ws and ws.text)
assert(C(VULO, "return #STUB.chat > 0 and STUB.chat[1].text:find('/roll', 1, true) ~= nil"), "the raid chat announcement stays")
assert(shown(KIM) and shown(FRAK), "raiders and officers with Amisia see the window")
assert(shown(VULO), "the lead sees its own small window")
assert(not shown(ANNA), "the window switched off")
assert(not shown(PUG), "a guest outside the guild sees none")

-- Mainspec: the client rolls, the lead reads the server's line
assert(C(KIM, "AmisiaRollWindow.rows[1].ms:Click(); return #RANDOMS == 1 and RANDOMS[1][1] == 1 and RANDOMS[1][2] == 100"), "1-100")
serverRoll(KIM, 77, 1, 100)
assert(C(VULO, "local e = NS.CurrentRoll().rolls['Kim Eisherz']; return e and e.value == 77 and e.kind == 'MS'"), "the roll counts like /roll")
assert(has(status(KIM), "Gewürfelt: Mainspec 77"), status(KIM))
-- a WA with a number counts nothing: a forged roll is just not a kind
C(KIM, ("NS.CommSend('WA', { %q, 'B', '99' }, 'WHISPER', 'Vulo Sturmwind')"):format(wid))
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().rolls['Kim Eisherz'].value") == 77, "an addon message never sets a roll")

-- Passen: a whisper to the lead only, nothing in the chat
local chatBefore = C(FRAK, "return #STUB.chat")
C(FRAK, "AmisiaRollWindow.rows[1].pass:Click()")
BUS.tick(0.5)
local wa = last("WA", FRAK)
assert(wa and wa.chan == "WHISPER" and wa.target == VULO and wa.text == "1WA\t" .. wid .. "\tP", wa and wa.text)
assert(C(FRAK, "return #STUB.chat") == chatBefore, "Passen writes nothing in the chat")
local tally = C(VULO, "return NS.RollWindowTally(NS.CurrentRoll())")
assert(tally == "passt: 1 · ohne Antwort: 1", tally)
assert(C(VULO, "NS.ShowRollFrame(); return AmisiaRollFrame.lockHint:GetText():find('passt: 1', 1, true) ~= nil"), "the lead's roll window shows it")
-- a pass for another round or from a stranger counts nothing
C(PUG, ("NS.CommSend('WA', { %q, 'P' }, 'WHISPER', 'Vulo Sturmwind')"):format(wid))
C(ANNA, "NS.CommSend('WA', { 'ffff', 'P' }, 'WHISPER', 'Vulo Sturmwind')")
BUS.tick(3)
assert(C(VULO, "return NS.RollWindowTally(NS.CurrentRoll())") == "passt: 1 · ohne Antwort: 1", "the guest's and the wrong round's pass do not count")

-- Fraktur passed but may still roll; the roll counts
serverRoll(FRAK, 91, 1, 99)
assert(C(VULO, "local e = NS.CurrentRoll().rolls.Fraktur; return e and e.kind == 'OS'"))
assert(C(VULO, "return NS.RollWindowTally(NS.CurrentRoll())") == "passt: 0 · ohne Antwort: 1")

-- the end: the winner for 5 s
C(VULO, "NS.StopRoll()")
BUS.tick(0.5)
local we = last("WE", VULO)
assert(we and has(we.text, wid) and has(we.text, "Kim Eisherz") and has(we.text, "77:MS"), we and we.text)
assert(has(status(KIM), "Gewinner: Kim Eisherz (77, MS)"), status(KIM))
assert(has(status(VULO), "Gewinner: Kim Eisherz"), "the lead's own window too")
BUS.tick(5.5)
assert(not shown(KIM) and not shown(FRAK), "closed after 5 s")

---------------------------------------------------------------------------
-- an officer who does not lead the loot cannot open windows for others
---------------------------------------------------------------------------
C(FRAK, ("NS.StartRoll(%q, 20)"):format(LINK))
BUS.tick(1)
assert(last("WS", FRAK) == nil, "Fraktur's client sends no round: not the loot lead")
C(FRAK, "NS.StopRoll()")
C(FRAK, "NS.CommSend('WS', { 'abcd', 'item:32235', '20', 'R', '-', '-', '-', '-', '-' }, 'RAID')")
BUS.tick(1)
assert(not shown(KIM), "a round forged by a non-lead officer opens nothing")
C(KIM, "NS.CommSend('WS', { 'abce', 'item:32235', '20', 'R', '-', '-', '-', '-', '-' }, 'RAID')")
BUS.tick(1)
assert(not shown(FRAK), "a raider's forged round opens nothing")

---------------------------------------------------------------------------
-- DKP: a bid from the window counts like a whispered !bid, with the same checks
---------------------------------------------------------------------------
C(VULO, [[NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 mode=bid seal=0 min=10 step=5\nP Vulo_Sturmwind 100\nP Fraktur 80\nP Kim_Eisherz 60\nP Anna 40\n#END")]])
-- a new raid takes the system of now (a running raid keeps its own)
local function newRaid()
    C(VULO, "STUB.instance = { name = 'Shattrath', type = 'none', id = 0 }; STUB.fire('PLAYER_ENTERING_WORLD')")
    BUS.tick(3)
    C(VULO, "STUB.now = STUB.now + 4 * 3600; STUB.instance = { name = 'Naxxramas', type = 'raid', id = 533 }; STUB.fire('PLAYER_ENTERING_WORLD')")
    BUS.tick(3)
end
newRaid()
C(VULO, ("NS.StartRoll(%q, 30)"):format(LINK))
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().mode") == "bid")
local bws = last("WS", VULO)
assert(has(bws.text, "\tB\t") and has(bws.text, "\t10\t"), bws.text)
assert(C(KIM, "local r = AmisiaRollWindow.rows[1]; return r.bidBtn:IsShown() and r.bidEdit:IsShown() and not r.ms:IsShown()"), "bid field and button")
-- more than the own standing: refused with the reply of !bid
C(KIM, "local r = AmisiaRollWindow.rows[1]; r.bidEdit:SetText('70'); r.bidBtn:Click()")
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().rolls['Kim Eisherz'] == nil"), "over the standing: refused")
local reason = C(VULO, "local r = NS.CurrentRoll(); return r.ignored[#r.ignored].why")
-- the same bid whispered gives the same reason
C(VULO, "STUB.fire('CHAT_MSG_WHISPER', '!bid 70', 'Anna')")
local whyWhisper = C(VULO, "local r = NS.CurrentRoll(); return r.ignored[#r.ignored].why")
assert(has(reason, "Stand") and has(whyWhisper, "Stand"), tostring(reason) .. " / " .. tostring(whyWhisper))
assert(C(VULO, "for _, c in ipairs(STUB.chat) do if c.chan == 'WHISPER' and c.target == 'Kim Eisherz' and c.text:find('Gebot abgelehnt', 1, true) then return true end end return false"),
    "the window's bidder hears why, as with !bid")
BUS.tick(3)
C(KIM, "local r = AmisiaRollWindow.rows[1]; r.bidEdit:SetText('50'); r.bidBtn:Click()")
BUS.tick(0.5)
assert(C(VULO, "local e = NS.CurrentRoll().rolls['Kim Eisherz']; return e and e.value == 50"), "a bid within the standing counts")
assert(C(VULO, "for _, c in ipairs(STUB.chat) do if c.text:find('Höchstgebot: 50', 1, true) then return true end end return false"), "the open bid is announced as today")
-- under the step, quickly after: waits for the gap and still counts the checks of !bid
C(KIM, "local r = AmisiaRollWindow.rows[1]; r.bidEdit:SetText('52'); r.bidBtn:Click()")
BUS.tick(3)
assert(C(VULO, "return NS.CurrentRoll().rolls['Kim Eisherz'].value") == 50, "under the step: refused like !bid")
C(VULO, "NS.StopRoll()")
BUS.tick(6)

---------------------------------------------------------------------------
-- EPGP need/greed: the buttons say the price and count like !need / !greed
---------------------------------------------------------------------------
C(VULO, [[NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-09 epgp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 base=100 minep=0 scale=100 ref=66 os=50\nP Vulo_Sturmwind 500 100\nP Fraktur 400 100\nP Kim_Eisherz 300 100\nP Anna 200 100\n#END")]])
newRaid()
C(VULO, ("NS.StartRoll(%q, 30)"):format(LINK))
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().mode") == "pr", "need/greed")
assert(C(KIM, "local r = AmisiaRollWindow.rows[1]; return r.need:IsShown() and r.greed:IsShown() and r.need:GetText():find('Bedarf', 1, true) ~= nil"))
C(KIM, "AmisiaRollWindow.rows[1].greed:Click()")
BUS.tick(0.5)
assert(C(VULO, "local e = NS.CurrentRoll().rolls['Kim Eisherz']; return e and e.kind == 'OS'"), "greed counts like !greed")
C(KIM, "AmisiaRollWindow.rows[1].need:Click()")
BUS.tick(3)
assert(C(VULO, "local e = NS.CurrentRoll().rolls['Kim Eisherz']; return e and e.kind == 'MS'"), "the last answer counts")
C(KIM, "AmisiaRollWindow.rows[1].pass:Click()")
BUS.tick(3)
assert(C(VULO, "return NS.CurrentRoll().rolls['Kim Eisherz'] == nil"), "a pass takes the entry out, as !pass")
assert(C(VULO, "return NS.RollWindowTally(NS.CurrentRoll())"):find("passt: 1", 1, true))
-- the whispered word gives the same entry
C(VULO, "STUB.fire('CHAT_MSG_WHISPER', '!need', 'Fraktur')")
C(FRAK, "AmisiaRollWindow.rows[1].need:Click()")
BUS.tick(3)
assert(C(VULO, "local e = NS.CurrentRoll().rolls.Fraktur; return e and e.kind == 'MS'"))
C(VULO, "NS.StopRoll()")
BUS.tick(0.5)
assert(has(status(KIM), "Gewinner: Fraktur (Bedarf)"), status(KIM))
BUS.tick(6)
C(VULO, "NS.Set('points.system', 'roll')")
newRaid()

---------------------------------------------------------------------------
-- a tie-break reaches only the tied
---------------------------------------------------------------------------
C(VULO, ("NS.StartRoll(%q, 20)"):format(LINK))
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().mode") == nil, "a rolling raid again")
do
    serverRoll(KIM, 80, 1, 100)
    serverRoll(FRAK, 80, 1, 100)
    C(VULO, "NS.StopRoll()")
    BUS.tick(0.5)
    assert(has(status(KIM), "Gleichstand"), status(KIM))
    BUS.tick(1)   -- one round per second and sender (Comm.lua)
    assert(C(VULO, "return NS.RerollTie() == true"))
    BUS.tick(0.5)
    local tws = last("WS", VULO)
    assert(has(tws.text, "\tT\t") and has(tws.text, "Kim Eisherz") and has(tws.text, "Fraktur"), tws.text)
    assert(C(KIM, "local r = AmisiaRollWindow.rows[1].r; return r.tie ~= nil and not r.done"), "Kim is tied: the tie-break window")
    assert(C(FRAK, "local r = AmisiaRollWindow.rows[1].r; return r.tie ~= nil and not r.done"), "Fraktur is tied")
    assert(C(VULO, "for _, r in ipairs(NS._rollWindow.rounds()) do if r.tie and not r.done then return false end end return true"),
        "the lead is not tied: no tie-break window")
    C(VULO, "NS.StopRoll()")
    BUS.tick(6)
end

---------------------------------------------------------------------------
-- the lockdown holds the round and expires it after the round's time
---------------------------------------------------------------------------
BUS.lock(true)
C(VULO, ("NS.StartRoll(%q, 5)"):format(LINK))
BUS.tick(1)
assert(not shown(KIM), "held in the lockdown")
BUS.tick(6)
BUS.lock(false)
BUS.tick(1)
assert(not shown(KIM), "the held round fell after its time")
print("roll window raid ok")
