-- The NPC scan by id (Collect/ScanNpcs.lua, D-104): phase A over the list of our data, the second ask
-- after 1 s, ids without a name kept as ranges, the back-off when known NPCs stay empty, resume and
-- pause, the question before phase B with its estimate, the mini-probe and the end without an answer,
-- combat and instances, the tooltip route of our own.
local SB, NP = NS.ScanById, NS.NpcScan
assert(SB and NP, "the NPC scan loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function msgsHave(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end

STUB.instance = { name = "Elwynn", type = "none", id = 0 }

-- the lists: phase A 10, 20, ..., 100 (ten NPCs), phase B 1000-1019 and 2000-2009
local function lists(na, nb)
    rawset(NS, "SCAN_LISTS", { Q = "", NA = na or "a,a,a,a,a,a,a,a,a,a", NB = nb or { { 1000, 1019 }, { 2000, 2009 } } })
    SB.Reset()
end
lists()
assert(#SB.List("NA") == 10 and SB.List("NA")[10] == 100)
local rb, nb = SB.RangesB()
assert(#rb == 2 and nb == 30)

-- the client: a name per id after "after" asks (0 at once, 1 on the second ask), else nothing
local W
local function client(names, after)
    W = { asks = {}, names = names or {}, after = after or {}, count = {} }
    C_TooltipInfo.GetHyperlink = function(link)
        local id = tonumber(link:match("^unit:Creature%-0%-0%-0%-0%-(%d+)%-0000000000$"))
        assert(id, "the creature link: " .. link)
        W.asks[#W.asks + 1] = id
        W.count[id] = (W.count[id] or 0) + 1
        local n = W.names[id]
        if not n or W.count[id] <= (W.after[id] or 0) then return { lines = {} } end
        local lines = { { leftText = n[1] } }
        if n[2] then lines[2] = { leftText = n[2] } end
        lines[#lines + 1] = { leftText = "Stufe 60" }
        return { lines = lines }
    end
end

local names = {}
for i = 1, 10 do names[i * 10] = { "Npc " .. i } end
names[20] = { "Edwin van Cleef", "<Defias-Bruderschaft>" }
names[1005] = { "Fürst Wrex" }
names[2003] = { "König Op" }
client(names, { [30] = 1 })

-- no verdict yet: the mini-probe asks three NPCs of the list first and keeps the verdict
assert(not SB.Verdict("npc"))
assert(NP.Start())
assert(SB.Verdict("npc") == "ok" and AmisiaDB.probe.src == "mini", tostring(AmisiaDB.probe and AmisiaDB.probe.npc))
assert(NP.Running() == "A")
assert(has(lastMsg(), "Phase A gestartet: 10 Nummern, 5 pro Sekunde"), lastMsg())

-- 5 per second: one ask every other tick; 30 needs a second ask after 1 s
STUB.tick(1)
local q = AmisiaDB.scan.npcs
assert(q.list[10] == "Npc 1", tostring(q.list[10]))
assert(q.list[20] == "Edwin van Cleef\t<Defias-Bruderschaft>", tostring(q.list[20]))
assert(not q.list[30], "30 waits for its second ask")
-- the second line only when it is a title in angle brackets
assert(not q.list[10]:find("Stufe", 1, true))

-- pause and resume: an id waiting for its second ask is asked again
NP.Command("stop")
assert(not NP.Running() and not SB.Busy())
assert(q.a == 3, "back to 30: " .. q.a)
local asked = #W.asks
STUB.tick(2)
assert(#W.asks == asked)
assert(has(NP.Status(), "angehalten"), NP.Status())
NP.Command("")
assert(NP.Running() == "A" and q.a == 3)
STUB.tick(1)
assert(q.list[30] == "Npc 3", "the second ask finds it")
STUB.tick(6)
assert(not NP.Running(), "phase A ends")
assert(q.doneA and q.n == 10, q.n)
assert(msgsHave("Phase B (neue NPCs suchen, 30 Nummern"), "phase B is offered with its size")

-- phase B: the question with the estimate first; nothing runs before "Starten"
local before = #W.asks
NP.Command("")
local cf = _G.AmisiaConfirmFrame
assert(cf and cf:IsShown(), "W.Confirm asks before phase B")
assert(has(cf.text:GetText(), "30 Nummern in 2 Bereichen"), cf.text:GetText())
assert(has(cf.text:GetText(), "bis zu 12 s"), cf.text:GetText())   -- 30 ids, two asks each, 5 per second
assert(not NP.Running() and #W.asks == before)
cf.ok:Click()
assert(NP.Running() == "B")
STUB.tick(20)
assert(not NP.Running() and q.doneB)
assert(q.list[1005] == "Fürst Wrex" and q.list[2003] == "König Op")
-- the ids without a name as ranges, asked twice each
assert(q.empty == "1000-1004,1006-1019,2000-2002,2004-2009", q.empty)
assert(W.count[1000] == 2 and W.count[1005] == 1)
assert(has(NP.Status(), "fertig: 12 Namen"), NP.Status())

-- the question can be cancelled
AmisiaDB.scan.npcs.doneB = nil
AmisiaDB.scan.npcs.b = nil
NP.Command("")
assert(cf:IsShown())
cf.cancel:Click()
assert(not NP.Running())

-- back-off: known NPCs that stay empty halve the rate and are asked once more
AmisiaDB.scan.npcs = nil
lists("a,a,a,a,a,a,a,a,a,a")
client({}, {})
SB.SaveProbe({ npc = "ok" })
assert(NP.Start())
STUB.tick(4)
assert(NP.Running() == "A")
-- five misses in a row: from 5 to 2.5 per second, the five go into the queue again
STUB.tick(30)
assert(not NP.Running())
q = AmisiaDB.scan.npcs
assert(q.empty == "10,20,30,40,50,60,70,80,90,100" or SB.RangesCount(q.empty) == 10, q.empty)
local twice = 0
for _, id in ipairs({ 10, 20, 30, 40, 50 }) do if W.count[id] == 4 then twice = twice + 1 end end
assert(twice == 5, "the first five were asked a second time after the back-off")

-- a probe that found no names ends the scan with one line
AmisiaDB.scan.npcs = nil
SB.SaveProbe({ npc = "none" })
local ok, why = NP.Start()
assert(not ok and why == "Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet.", why)

-- the mini-probe without any name: one line, and the verdict "none" for this build
AmisiaDB.probe = nil
client({}, {})
assert(NP.Start())
STUB.tick(4)
assert(not NP.Running() and not SB.Busy())
assert(lastMsg():find("Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet.", 1, true), lastMsg())
assert(AmisiaDB.probe.npc == "none" and AmisiaDB.probe.src == "mini")
assert(not AmisiaDB.scan.npcs.doneA and AmisiaDB.scan.npcs.a == 1, "nothing of phase A ran")

-- a verdict of another client build does not count
AmisiaDB.probe.build = "1.0.0.1"
assert(SB.Verdict("npc") == nil)
AmisiaDB.probe = nil

-- combat waits, an instance pauses, no start there
SB.SaveProbe({ npc = "ok" })
AmisiaDB.scan.npcs = nil
client(names, {})
assert(NP.Start())
STUB.combat = true
asked = #W.asks
STUB.tick(2)
assert(#W.asks == asked and NP.Running() == "A")
STUB.combat = false
STUB.instance = { name = "Deadmines", type = "party", id = 36 }
STUB.tick(0.2)
assert(not NP.Running() and has(lastMsg(), "pausiert in der Instanz"), lastMsg())
ok, why = NP.Start()
assert(not ok and has(why, "in einer Instanz"), why)
STUB.instance = { name = "Elwynn", type = "none", id = 0 }

-- the hidden tooltip of our own where the client has no C_TooltipInfo (never GameTooltip)
local info = C_TooltipInfo.GetHyperlink
C_TooltipInfo.GetHyperlink = nil
AmisiaDB.probe = nil
SB.SaveProbe({ npc = "ok" })
local tip = SB.Tip()
assert(tip and tip ~= GameTooltip)
local shown = {}
tip.SetHyperlink = function(_, link) shown[#shown + 1] = link end
tip.NumLines = function() return 2 end
_G.AmisiaIdTipTextLeft1 = { GetText = function() return "Hogger" end }
_G.AmisiaIdTipTextLeft2 = { GetText = function() return "<Gnoll>" end }
local name, sub = NP.Ask(448)
assert(name == "Hogger" and sub == "<Gnoll>" and shown[1] == "unit:Creature-0-0-0-0-448-0000000000")
-- secret lines count as no name
STUB.secret["Hogger"], STUB.secret["<Gnoll>"] = true, true
assert(NP.Ask(448) == nil)
STUB.secret = {}
C_TooltipInfo.GetHyperlink = info

-- the slash word and the stop of every scan
AmisiaDB.scan.npcs = nil
client(names, {})
NS.ScanCommand("npcs")
assert(NP.Running() == "A")
NS.ScanCommand("stop")
assert(not NP.Running())
print("npc scan: phase A, second ask, back-off, resume, the question of phase B, ranges, mini-probe, combat, instance")
