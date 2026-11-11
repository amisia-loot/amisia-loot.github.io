-- The group's quest state of a dungeon (F-178, D-110, Gear/GroupQuests.lua): the wire form (QS, QR);
-- the own state of a quest (D.OwnQuestState); a party of five (Anna with Amisia, Kai with sending off,
-- Bob and Cid without Amisia); announcing on entering, asking while a state is missing, the answer to a
-- QR with its jitter and its skip, coalescing and the gaps, nothing in combat or the lockdown; what is
-- taken (only the party's members on PARTY, sizes, the keyed gap, the wings rule) and dropped (a member
-- leaving, the party ending, a raid, stale); sending off still shows the others; the page's marks
-- (five members fit), the row's tooltip, "Teilen", the dungeon bar's "teilen".
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", "#"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local L = NS.L
local GQ, Dn = NS.GroupQuests, NS.Dungeons
local realQuests = NS.DUNGEON_QUESTS

STUB.class, STUB.level, STUB.faction = "WARRIOR", 18, "Alliance"
STUB.roster = {}
STUB.questsComplete = {}
C_QuestLog.IsComplete = function(id) return STUB.questsComplete[id] == true end
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 500, 501, 502, 503, 504, 505 }, smarm = { 620 }, smcath = { 620, 630 } },
    Q = {
        [500] = { "Red Silk Bandanas", 14, 17, "A", 0, "O", "Scout Riell", nil, nil, nil, "deadmines" },
        [501] = { "Horde Errand", 14, 17, "H", 0, "O", nil, nil, nil, nil, "deadmines" },
        [502] = { "Warriors Only", 14, 18, "", 1, "O", nil, nil, nil, nil, "deadmines" },
        [503] = { "Later Quest", 25, 28, "", 0, "O", nil, nil, nil, nil, "deadmines" },
        [504] = { "The Defias Brotherhood", 14, 18, "A", 0, "O", "Gryan Stoutmantle", nil, nil, nil, "deadmines" },
        [505] = { "Quest 505", 0, 17, "", 0, "", nil, nil, nil, nil, "deadmines", nil, nil, nil, nil, nil, 0, 0, nil, nil,
                  nil, nil, nil, true },
        [620] = { "Armory and Cathedral", 30, 38, "", 0, "O", nil, nil, nil, nil, "smarm" },
        [630] = { "Cathedral Only", 30, 40, "", 0, "O", nil, nil, nil, nil, "smcath" },
    },
}
NS.GEAR = { built = "test-group", Z = {}, I = {}, S = {} }
NS.Gear._reset()
NS.BisBump()
GQ._reset()

local ANNA, KAI, BOB, CID = "Anna Bergmann", "Kai Fremder", "Bob Baum", "Cid Stein"
local ME = NS.UnitFullName("player")
local PARTY = { { name = ME, class = "WARRIOR" }, { name = ANNA, class = "MAGE" }, { name = KAI, class = "PRIEST" },
                { name = BOB, class = "MAGE" }, { name = CID, class = "ROGUE" } }
local DEADMINES = { name = "Die Todesminen", type = "party", id = 36 }
local OUT = { name = "Westfall", type = "none", id = 0 }

local function recv(kind, fields, from, chan)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1" .. kind .. "\t" .. table.concat(fields, "\t"), chan or "PARTY", from or ANNA)
end
local function sent(kind)
    local out = {}
    for _, m in ipairs(STUB.addon) do
        if m.text:match("^%d(%u%u)") == kind then out[#out + 1] = m end
    end
    return out
end
local function member(name)
    for _, m in ipairs(GQ.Members()) do if m.name == name then return m end end
end
local function enter(i)
    STUB.instance = i
    STUB.fire("PLAYER_LEAVING_WORLD")
    STUB.fire("PLAYER_ENTERING_WORLD")
end

---------------------------------------------------------------------------
-- the wire form
---------------------------------------------------------------------------
local text, cut = GQ.Encode({ { 500, "open" }, { 501, "na" }, { 502, "active" }, { 503, "locked" }, { 540, "ready" }, { 99187, "done" } })
-- 500 = "dw", then the steps 1, 1, 1, 37 ("11") and 98647, each with its state character
assert(text:sub(1, 12) == "dw.1/1+1<11!" and text:sub(-1) == "*", text)
assert(not cut)
local back, n = GQ.Decode(text)
assert(n == 6 and back[500] == "open" and back[501] == "na" and back[502] == "active" and back[503] == "locked"
    and back[540] == "ready" and back[99187] == "done", "round trip")
assert(GQ.Decode("-") and next((GQ.Decode("-"))) == nil, "an empty list")
for _, bad in ipairs({ "", "dw", "dw.x", "0.", "dw?", "abcde.", "DW." }) do
    assert(GQ.Decode(bad) == nil, "not a list: " .. bad)
end
-- cut to the room it has: the rest is unknown to the receiver
local many = {}
for i = 1, 120 do many[i] = { 1000 + i, "done" } end
local short, wasCut = GQ.Encode(many, 60)
assert(wasCut and #short <= 60, #short)
local _, nShort = GQ.Decode(short)
assert(nShort == 29, "the first three bytes, then two each: " .. tostring(nShort))
local capped, cappedCut = GQ.Encode(many, 1000)
assert(cappedCut and select(2, GQ.Decode(capped)) == GQ.MAX_ENTRIES, "never more than 100 quests")

---------------------------------------------------------------------------
-- the own state of a quest by its id
---------------------------------------------------------------------------
STUB.questsDone[504] = true
STUB.questsActive[500] = true
assert(Dn.OwnQuestState(500) == "active" and Dn.OwnQuestState(504) == "done")
STUB.questsComplete[500] = true
assert(Dn.OwnQuestState(500) == "ready", "in the log and complete")
STUB.questsComplete[500] = nil
assert(Dn.OwnQuestState(501) == "na", "the other faction")
assert(Dn.OwnQuestState(502) == "open", "the own class")
assert(Dn.OwnQuestState(503) == "locked", "level 25 at 18")
assert(Dn.OwnQuestState(505) == "open", "a scanned quest without faction: possible")
assert(Dn.OwnQuestState(999) == "open", "a quest the data lacks: by the client's flags")
local fields = GQ.OwnFields("deadmines")
assert(fields[1] == "deadmines" and fields[2] == "1" and fields[3] == "-", table.concat(fields, " "))
local own = GQ.Decode(fields[4])
assert(own[500] == "active" and own[501] == "na" and own[502] == "open" and own[503] == "locked" and own[504] == "done"
    and own[505] == "open", fields[4])

---------------------------------------------------------------------------
-- alone and in a raid nothing goes
---------------------------------------------------------------------------
STUB.addon = {}
STUB.fire("QUEST_LOG_UPDATE")
enter(DEADMINES)
STUB.tick(10)
assert(#sent("QS") == 0 and #sent("QR") == 0, "alone: nothing")
recv("QS", { "deadmines", "1", "-", "dw." })
assert(#GQ.Members() == 0, "no members alone")

---------------------------------------------------------------------------
-- a party of five inside the Deadmines: the own state goes, the missing ones are asked for
---------------------------------------------------------------------------
STUB.roster, STUB.party = PARTY, true
STUB.fire("GROUP_ROSTER_UPDATE")
enter(DEADMINES)
STUB.tick(1.5)
assert(#GQ.Here() == 1 and GQ.Here()[1] == "deadmines", "here: the Deadmines")
assert(#sent("QS") == 0, "the own state waits a moment after entering")
STUB.tick(6)
local qs, qr = sent("QS"), sent("QR")
assert(#qs == 1 and qs[1].chan == "PARTY" and qs[1].text == "1QS\tdeadmines\t1\t-\t" .. fields[4], qs[1] and qs[1].text)
assert(#qr == 1 and qr[1].chan == "PARTY" and qr[1].text == "1QR\tdeadmines\t1", qr[1] and qr[1].text)
assert(#GQ.Members() == 4 and GQ.Members()[1].name == ANNA, "the four others in roster order")

-- Anna answers; the others stay unknown, never "does not have it"
recv("QS", { "deadmines", "1", "-", "dw.1/1/1<1+1." })
local anna, kai, bob, cid = member(ANNA), member(KAI), member(BOB), member(CID)
assert(GQ.StateOf(anna, "deadmines", 500) == "open" and GQ.StateOf(anna, "deadmines", 504) == "active"
    and GQ.StateOf(anna, "deadmines", 503) == "locked" and GQ.StateOf(anna, "deadmines", 502) == "na")
assert(GQ.HasState(anna, "deadmines") and not GQ.HasState(kai, "deadmines"))
assert(GQ.StateOf(kai, "deadmines", 500) == "unknown" and GQ.StateOf(bob, "deadmines", 504) == "unknown", "no message: unknown")
-- without a message the data's class and faction still say "can never take it"
assert(GQ.StateOf(bob, "deadmines", 502) == "na" and GQ.StateOf(cid, "deadmines", 501) == "na", "class and faction")
assert(GQ.StateOf(bob, "deadmines", 505) == "unknown", "a scanned quest without faction: possible, so unknown")
-- a quest Anna's data does not name: unknown
assert(GQ.StateOf(anna, "deadmines", 999) == "unknown")

-- what is not taken: a stranger, the wrong channel, a raid's channel, a broken list, too many quests
recv("QS", { "deadmines", "1", "-", "dw*" }, "Fremder Mann")
recv("QS", { "deadmines", "1", "-", "dw*" }, ANNA, "GUILD")
recv("QS", { "deadmines", "1", "-", "dw*" }, ANNA, "RAID")
recv("QS", { "deadmines", "1", "-", "dw*?" })
local tooMany = {}
for i = 1, 101 do tooMany[i] = "1*" end
recv("QS", { "deadmines", "1", "-", "dw" .. table.concat(tooMany) })
recv("QS", { "onyxia", "1", "-", "dw*" })
recv("QS", { "deadmines", "0", "-", "dw*" })
assert(GQ.StateOf(anna, "deadmines", 500) == "open", "none of them changed Anna's state")
assert(GQ.StateOf(member("Fremder Mann") or { low = "fremder mann" }, "deadmines", 500) == "unknown")
-- a second state of the same dungeon within 3 s is dropped, after them it counts
STUB.tick(3.5)
recv("QS", { "deadmines", "1", "-", "dw!" })
recv("QS", { "deadmines", "1", "-", "dw*" })
assert(GQ.StateOf(anna, "deadmines", 500) == "ready", "the second within 3 s dropped")
STUB.tick(3.5)
recv("QS", { "deadmines", "1", "-", "dw.1/1/1<1+1." })
assert(GQ.StateOf(anna, "deadmines", 500) == "open")

-- the wings rule (D-106): a state of the Armory never shows under the Cathedral
recv("QS", { "smarm", "1", "-", "h8+" })
assert(GQ.StateOf(anna, "smarm", 620) == "active" and GQ.StateOf(anna, "smcath", 620) == "unknown", "per dungeon key")
assert(GQ.StateOf(anna, "deadmines", 500) == "open", "the Deadmines' state stays")

---------------------------------------------------------------------------
-- the answer to a question: after a jitter, none right after the own state, never twice at once
---------------------------------------------------------------------------
STUB.addon = {}
recv("QR", { "deadmines", "1" }, KAI)
STUB.tick(0.3)
assert(#sent("QS") == 0, "not at once (jitter)")
STUB.tick(5)
assert(#sent("QS") == 1, "the answer")
recv("QR", { "deadmines", "1" }, ANNA)
STUB.tick(5)
assert(#sent("QS") == 1, "the own state went within 10 s: Anna's question is answered by it")
STUB.tick(10)
recv("QR", { "deadmines,smarm", "1" }, KAI)
STUB.tick(5)
qs = sent("QS")
assert(#qs == 3, "an answer per dungeon asked for: " .. #qs)
assert(qs[3].text == "1QS\tsmarm\t1\t-\th8<" or qs[2].text == "1QS\tsmarm\t1\t-\th8<", "the Armory too")
-- a second question of Kai within 10 s is dropped by the receiver's gap
STUB.addon = {}
recv("QR", { "smcath", "1" }, KAI)
STUB.tick(5)
assert(#sent("QS") == 0)

---------------------------------------------------------------------------
-- own changes: coalesced, a dungeon at most every 6 s, nothing in combat
---------------------------------------------------------------------------
STUB.tick(20)
STUB.addon = {}
STUB.questsComplete[500] = true
for _ = 1, 5 do
    STUB.fire("QUEST_LOG_UPDATE")
    STUB.tick(0.5)
end
STUB.tick(3)
qs = sent("QS")
assert(#qs >= 1, "the change went out")
local mine
for _, m in ipairs(qs) do if has(m.text, "\tdeadmines\t") then mine = m end end
assert(mine and has(mine.text, "dw!"), "once, with the ready quest: " .. tostring(mine and mine.text))
assert(#qs == 1, "the Armory others asked for did not change: not again: " .. #qs)
-- nothing changed: nothing goes
STUB.addon = {}
STUB.fire("QUEST_LOG_UPDATE")
STUB.tick(10)
assert(#sent("QS") == 0, "the same state is not sent again")
-- two changes close together: the second waits for the gap
STUB.addon = {}
STUB.questsDone[500], STUB.questsActive[500] = true, nil
STUB.fire("QUEST_TURNED_IN", 500)
STUB.tick(2.5)
assert(#sent("QS") >= 1)
STUB.questsActive[502] = true
STUB.fire("QUEST_ACCEPTED", 502)
STUB.tick(2.5)
local count = #sent("QS")
STUB.tick(5)
assert(#sent("QS") > count, "the second after the gap")
-- in combat nothing goes; after it, it does
STUB.tick(10)
STUB.addon = {}
STUB.combat = true
STUB.questsActive[502] = nil
STUB.fire("QUEST_REMOVED", 502)
STUB.tick(15)
assert(#sent("QS") == 0 and #sent("QR") == 0, "nothing in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(3)
assert(#sent("QS") >= 1, "after the fight")
-- in the lockdown nothing goes and nothing is taken
STUB.tick(10)
STUB.addon = {}
STUB.chatLock = true
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.questsActive[503] = true
STUB.fire("QUEST_ACCEPTED", 503)
STUB.tick(10)
assert(#sent("QS") == 0, "nothing in the lockdown")
recv("QS", { "deadmines", "1", "-", "dw*" })
assert(GQ.StateOf(anna, "deadmines", 500) == "open", "nothing taken in the lockdown")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.tick(5)
assert(#sent("QS") >= 1, "after the lockdown")

---------------------------------------------------------------------------
-- sending off: nothing goes, the others still show
---------------------------------------------------------------------------
assert(NS.Get("quests.groupShare") == true, "on by default")
NS.Set("quests.groupShare", false)
STUB.tick(10)
STUB.addon = {}
STUB.questsActive[503] = nil
STUB.fire("QUEST_REMOVED", 503)
recv("QR", { "deadmines", "1" }, BOB)
STUB.tick(10)
assert(#sent("QS") == 0, "sending off: no state, no answer")
recv("QS", { "deadmines", "1", "-", "dw+" })
assert(GQ.StateOf(anna, "deadmines", 500) == "active", "what Anna sends still shows")
NS.Set("quests.groupShare", true)

---------------------------------------------------------------------------
-- the page and the bar: marks of four members, the tooltip, "Teilen", "teilen"
---------------------------------------------------------------------------
STUB.questsDone[500], STUB.questsActive[500] = nil, true
STUB.questsComplete[500] = nil
STUB.tick(4)
recv("QS", { "deadmines", "1", "-", "dw.1/1/1<1+1." })
NS.BisBump()
AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.dpart = "quests"
NS.ShowDungeon("deadmines")
local B = NS.PageFrame("dungeons")
local rows = {}
for _, r in ipairs(B.detail.rows) do if r.item and r.item.qid then rows[r.item.qid] = r end end
local row = rows[500]
assert(row and row.grp:IsShown(), "the row of the quest in the own log")
local marks = row.grp:GetText()
assert(plain(marks) == "A# K? B? C?", plain(marks))
assert(row.grp:GetStringWidth() <= row.grp:GetWidth(), ("four marks fit: %d of %d"):format(row.grp:GetStringWidth(), row.grp:GetWidth()))
assert(row.rate:GetWidth() + row.grp:GetWidth() <= 188, "the start and the marks in the start's old room")
assert(has(plain(rows[502].grp:GetText()), "B-"), "Bob can never take the warriors' quest: " .. plain(rows[502].grp:GetText()))
-- the tooltip names the members by state and says who it can be shared with
local tipLines, addLine0 = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
local okTip, errTip = pcall(row.scripts.OnEnter, row)
GameTooltip.AddLine = addLine0
assert(okTip, tostring(errTip))
local tip = plain(table.concat(tipLines, "\n"))
assert(has(tip, L["Gruppe:"]) and has(tip, L["Fehlt: %s"]:format(ANNA)), tip)
assert(has(tip, L["Unbekannt (kein Amisia oder Teilen aus): %s"]:format(KAI .. ", " .. BOB .. ", " .. CID)), tip)
assert(has(tip, L["Kannst du teilen: %s"]:format(ANNA)), tip)
row.scripts.OnLeave(row)
-- "Teilen": only with the client's share call; it selects, pushes and puts the selection back
assert(not row.share:IsShown(), "no share call on this client: no link, the tooltip says it")
local calls = {}
C_QuestLog.GetLogIndexForQuestID = function(id) return id == 500 and 3 or nil end
C_QuestLog.GetSelectedQuest = function() return 777 end
C_QuestLog.SetSelectedQuest = function(id) calls[#calls + 1] = "select " .. id end
C_QuestLog.IsPushableQuest = function() return true end
_G.QuestLogPushQuest = function() calls[#calls + 1] = "push" end
NS.Refresh()
assert(row.share:IsShown(), "shown (as a row action) for a quest a member lacks")
assert(not rows[504].share:IsShown(), "not for a done one")
STUB.messages = {}
row.share:Click()
assert(table.concat(calls, ",") == "select 500,push,select 777", table.concat(calls, ","))
assert(has(STUB.messages[#STUB.messages], L["Quest \"%s\" mit der Gruppe geteilt."]:format(row.item.q.title)), STUB.messages[#STUB.messages])
STUB.combat = true
local ok, why = GQ.Share(500)
assert(not ok and why == L["Nicht im Kampf."], "never in combat")
STUB.combat = false
C_QuestLog.IsPushableQuest = function() return false end
calls = {}
ok, why = GQ.Share(500)
assert(not ok and why == L["Diese Quest lässt sich nicht teilen."] and table.concat(calls, ",") == "select 500,select 777", table.concat(calls, ","))
-- the dungeon bar: "· 1 teilen", "fehlt 1" in its list
local bar = _G.AmisiaDungeonBar
assert(bar and bar:IsShown(), "the bar shows in the Deadmines")
NS.DungeonBar.Refresh()
assert(has(plain(bar.seg.quests:GetText()), L["· %d teilen"]:format(1)), plain(bar.seg.quests:GetText()))
NS.DungeonBar.Toggle("quests")
local noted
for _, r in ipairs(_G.AmisiaDungeonBarList.rows) do
    if r:IsShown() and r.entry and r.entry.qid == 500 then noted = plain(r.note:GetText()) end
end
assert(noted == L["fehlt %d##Gruppe"]:format(1), tostring(noted))
NS.DungeonBar.Toggle("quests")

---------------------------------------------------------------------------
-- outside: the page asks for the dungeon it shows (the summoning stone)
---------------------------------------------------------------------------
enter(OUT)
STUB.tick(2)
assert(#GQ.Here() == 0)
STUB.tick(60)
STUB.addon = {}
NS.ShowDungeon("deadmines")
NS.Refresh()
STUB.tick(2)
qr = sent("QR")
assert(#qr == 1 and qr[1].text == "1QR\tdeadmines\t1", "the page asks while Kai, Bob and Cid are missing")
NS.Refresh()
STUB.tick(20)
assert(#sent("QR") == 1, "once a minute at most")

---------------------------------------------------------------------------
-- a newcomer is asked for; who leaves is dropped; the end of the party drops everything
---------------------------------------------------------------------------
STUB.tick(60)
STUB.roster = { PARTY[1], PARTY[2], PARTY[4], PARTY[5] }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(1)
assert(member(KAI) == nil and #GQ.Members() == 3)
assert(GQ.StateOf(anna, "deadmines", 500) == "open", "Anna's state stays")
STUB.addon = {}
STUB.roster = PARTY
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(8)
assert(#sent("QR") == 1, "a newcomer: asked for the watched dungeon")
-- held back by anyone's question of the same dungeon
STUB.tick(60)
STUB.addon = {}
STUB.roster = { PARTY[1], PARTY[2], PARTY[3], PARTY[4] }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.roster = PARTY
STUB.fire("GROUP_ROSTER_UPDATE")
recv("QR", { "deadmines,smarm", "1" }, ANNA)
STUB.tick(8)
assert(#sent("QR") == 0, "Anna asked already")
STUB.roster = { PARTY[1], PARTY[3], PARTY[4], PARTY[5] }
STUB.fire("GROUP_ROSTER_UPDATE")
assert(GQ.StateOf({ low = ANNA:lower(), name = ANNA }, "deadmines", 500) == "unknown", "Anna left: her state goes")
-- stale after 30 minutes
STUB.roster = PARTY
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
recv("QS", { "deadmines", "1", "-", "dw*" })
anna = member(ANNA)
assert(GQ.StateOf(anna, "deadmines", 500) == "done")
STUB.tick(GQ.STALE + 1)
assert(GQ.StateOf(anna, "deadmines", 500) == "unknown", "stale")
recv("QS", { "deadmines", "1", "-", "dw*" })
-- a raid: nothing kept, nothing taken
STUB.party = nil
STUB.fire("GROUP_ROSTER_UPDATE")
assert(#GQ.Members() == 0 and not GQ.HasState(anna, "deadmines"), "a raid drops it")
STUB.tick(4)
recv("QS", { "deadmines", "1", "-", "dw*" })
assert(not GQ.HasState(anna, "deadmines"), "nothing taken in a raid")
STUB.party = true
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(4)
recv("QS", { "deadmines", "1", "-", "dw*" })
assert(GQ.HasState(member(ANNA), "deadmines"))
STUB.roster, STUB.party = {}, nil
STUB.fire("GROUP_ROSTER_UPDATE")
assert(next(GQ._state().members) == nil, "the end of the party drops everything")

NS.DUNGEON_QUESTS = realQuests
NS.BisBump()
print("test_group_quests ok")
