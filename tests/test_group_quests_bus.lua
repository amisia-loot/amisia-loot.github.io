--[[clients Vulo_Sturmwind Anna_Bergmann Kai_Fremder]]
-- The group's quest state between Amisia clients (F-178, D-110): a party of five, Vulo and Anna with
-- Amisia, Kai with sending off, Bob and Cid without Amisia (no runtime: they never answer). Entering
-- the Deadmines together: each announces once over PARTY, one question at most per client; Vulo sees
-- what Anna lacks and that he can share it; Kai sends nothing but sees the others; an accepted quest
-- reaches the others; a newcomer asks and gets answers; outside, the page's question is answered.
local ALL = { "Vulo Sturmwind", "Anna Bergmann", "Kai Fremder", "Bob Baum", "Cid Stein" }
local SETUP = [[
    STUB.class, STUB.level, STUB.faction = "WARRIOR", 18, "Alliance"
    STUB.party = true
    STUB.instance = { name = "Westfall", type = "none", id = 0 }
    NS.DUNGEON_QUESTS = { built = "test", source = "test",
        D = { deadmines = { 500, 503, 504 } },
        Q = { [500] = { "Red Silk Bandanas", 14, 17, "A", 0, "O", nil, nil, nil, nil, "deadmines" },
              [503] = { "Later Quest", 25, 28, "", 0, "O", nil, nil, nil, nil, "deadmines" },
              [504] = { "The Defias Brotherhood", 14, 18, "A", 0, "O", nil, nil, nil, nil, "deadmines" } } }
    STUB.questsComplete = {}
    C_QuestLog.IsComplete = function(id) return STUB.questsComplete[id] == true end
    STUB.fire("QUEST_LOG_UPDATE")
]]
for _, name in ipairs(CLIENTS) do C(name, SETUP) end
C("Vulo Sturmwind", "STUB.questsActive[500] = true")
C("Anna Bergmann", "STUB.questsDone[504] = true")
C("Kai Fremder", "STUB.questsActive[500] = true; NS.Set('quests.groupShare', false)")
BUS.setRaid(ALL)
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.tick(20)
assert(BUS.count({ kind = "QS" }) == 0 and BUS.count({ kind = "QR" }) == 0, "outside, nothing watched: nothing")

-- everyone enters the Deadmines
local t0 = C("Vulo Sturmwind", "STUB.clock")
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
        STUB.fire("PLAYER_LEAVING_WORLD"); STUB.fire("PLAYER_ENTERING_WORLD")]])
end
BUS.tick(15)
assert(BUS.count({ kind = "QS", sender = "Vulo Sturmwind", chan = "PARTY" }) == 1, "Vulo announces once")
assert(BUS.count({ kind = "QS", sender = "Anna Bergmann", chan = "PARTY" }) == 1, "Anna announces once")
assert(BUS.count({ kind = "QS", sender = "Kai Fremder" }) == 0, "Kai's sending is off")
assert(BUS.count({ kind = "QR", from = t0 }) <= 3, "one question per client at most: " .. BUS.count({ kind = "QR", from = t0 }))
assert(BUS.count(function(m) return m.chan ~= "PARTY" and (m.kind == "QS" or m.kind == "QR") end) == 0, "only PARTY")

-- Vulo: Anna lacks the bandanas and has done the Brotherhood; Kai, Bob and Cid are unknown
local function stateOf(client, who, qid)
    return C(client, ([[local m
        for _, x in ipairs(NS.GroupQuests.Members()) do if x.name == %q then m = x end end
        return m and NS.GroupQuests.StateOf(m, "deadmines", %d) or "none"]]):format(who, qid))
end
assert(stateOf("Vulo Sturmwind", "Anna Bergmann", 500) == "open" and stateOf("Vulo Sturmwind", "Anna Bergmann", 504) == "done")
assert(stateOf("Vulo Sturmwind", "Anna Bergmann", 503) == "locked")
for _, who in ipairs({ "Kai Fremder", "Bob Baum", "Cid Stein" }) do
    assert(stateOf("Vulo Sturmwind", who, 500) == "unknown", who .. " is unknown, never lacking it")
end
assert(C("Vulo Sturmwind", "NS.GroupQuests.CanShare('deadmines', 500)") == true, "Vulo can share it with Anna")
assert(C("Vulo Sturmwind", "NS.GroupQuests.ShareCount({ 'deadmines' })") == 1)
-- Kai sends nothing but sees the others
assert(stateOf("Kai Fremder", "Vulo Sturmwind", 500) == "active" and stateOf("Kai Fremder", "Anna Bergmann", 500) == "open")
assert(stateOf("Anna Bergmann", "Vulo Sturmwind", 500) == "active")

-- Anna takes the quest: the others learn it
C("Anna Bergmann", "STUB.questsActive[500] = true; STUB.fire('QUEST_ACCEPTED', 500)")
BUS.tick(5)
assert(stateOf("Vulo Sturmwind", "Anna Bergmann", 500) == "active", "the accepted quest arrived")
assert(C("Vulo Sturmwind", "NS.GroupQuests.CanShare('deadmines', 500)") == false, "nobody lacks it now")
-- ready to turn in
C("Anna Bergmann", "STUB.questsComplete[500] = true; STUB.fire('QUEST_LOG_UPDATE')")
BUS.tick(8)
assert(stateOf("Vulo Sturmwind", "Anna Bergmann", 500) == "ready")

-- Kai leaves and comes back: dropped, then he asks and the others answer
BUS.tick(60)
BUS.setRaid({ "Vulo Sturmwind", "Anna Bergmann", "Bob Baum", "Cid Stein" })
for _, name in ipairs({ "Vulo Sturmwind", "Anna Bergmann" }) do C(name, "STUB.fire('GROUP_ROSTER_UPDATE')") end
C("Kai Fremder", "STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C("Kai Fremder", "#NS.GroupQuests.Members()") == 0 and C("Kai Fremder", "next(NS.GroupQuests._state().members) == nil"),
    "out of the party: nothing kept")
BUS.tick(20)
local t1 = C("Vulo Sturmwind", "STUB.clock")
BUS.setRaid(ALL)
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.tick(10)
assert(BUS.count({ kind = "QR", from = t1 }) >= 1, "the newcomer is asked for (or asks)")
assert(BUS.count({ kind = "QR", from = t1 }) <= 2, "held back by the first question: " .. BUS.count({ kind = "QR", from = t1 }))
assert(stateOf("Kai Fremder", "Vulo Sturmwind", 500) == "active" and stateOf("Kai Fremder", "Anna Bergmann", 500) == "ready",
    "Kai learns the others' state again")
assert(BUS.count({ kind = "QS", sender = "Kai Fremder" }) == 0, "Kai still sends nothing")

-- outside: Anna's page asks for the Deadmines, Vulo answers
BUS.tick(60)
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.instance = { name = "Westfall", type = "none", id = 0 }
        STUB.fire("PLAYER_LEAVING_WORLD"); STUB.fire("PLAYER_ENTERING_WORLD")]])
end
BUS.tick(5)
C("Vulo Sturmwind", "STUB.questsActive[500] = nil; STUB.questsDone[500] = true")
BUS.tick(1900)
assert(stateOf("Anna Bergmann", "Vulo Sturmwind", 500) == "unknown", "stale after 30 minutes")
local t2 = C("Vulo Sturmwind", "STUB.clock")
C("Anna Bergmann", "NS.GroupQuests.Look('deadmines')")
BUS.tick(6)
assert(BUS.count({ kind = "QR", sender = "Anna Bergmann", from = t2 }) == 1, "the page asks")
assert(BUS.count({ kind = "QS", sender = "Vulo Sturmwind", from = t2 }) == 1, "Vulo answers")
assert(stateOf("Anna Bergmann", "Vulo Sturmwind", 500) == "done", "Vulo's turned-in quest")
print("test_group_quests_bus ok")
