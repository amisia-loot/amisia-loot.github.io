--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Anna Pug]]
-- Rounds started with Gargul (RollWatch.lua, spec docs/specs/2026-10-11-softres-gargul.md, B1 and B4):
-- the start line in English and German, with and without a note; only from the master looter (or,
-- without master loot, the leader) with the officer rank in the own group; every raider with Amisia
-- gets the roll window marked "(Gargul)" (MS 1-100, OS 1-99; Passen sends nothing); the lead's Amisia
-- watches the rolls silently (no announcement, no WS, no result); "Stop your rolls!" (or German) ends
-- it; an Amisia round goes first; the chat lockdown; the English announcement (B4) when switched on.
local VULO, FRAK, KIM, ANNA, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Anna", "Pug"
local LINK = "|cffa335ee|Hitem:32235::::::::70:::::|h[Cursed Vision of Sargeras]|h|r"
local LINK2 = "|cffa335ee|Hitem:30000::::::::70:::::|h[Brustplatte]|h|r"

local function shown(name) return C(name, "AmisiaRollWindow ~= nil and AmisiaRollWindow:IsShown()") == true end
local function hint(name) return C(name, "return AmisiaRollWindow.rows[1].hint:GetText()") or "" end
local function status(name) return C(name, "return AmisiaRollWindow.rows[1].status:GetText()") or "" end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
-- a chat line every client sees (the server's sender)
local function chat(event, text, sender)
    for _, name in ipairs(CLIENTS) do
        C(name, ("STUB.fire(%q, %q, %q)"):format(event, text, sender))
    end
end
local function serverRoll(who, v, lo, hi)
    for _, name in ipairs(CLIENTS) do
        C(name, ("STUB.fire('CHAT_MSG_SYSTEM', (RANDOM_ROLL_RESULT):format(%q, %d, %d, %d))"):format(who, v, lo, hi))
    end
end
local function chatCount(name) return C(name, "return #STUB.chat") end
local function close(name) C(name, "if AmisiaRollWindow then AmisiaRollWindow:Hide() end") end

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
assert(C(VULO, "NS.IsLootLead()") == true and C(FRAK, "NS.IsLootLead()") == false)
assert(C(KIM, "NS.IsLootBossName('Vulo Sturmwind')") == true and C(KIM, "NS.IsLootBossName('Fraktur')") == false)
C(ANNA, "NS.Set('rollwin.foreign', false)")

---------------------------------------------------------------------------
-- the start line: English and German, with and without a note
---------------------------------------------------------------------------
local p = C(KIM, ("return NS.ParseForeignRollStart(%q)"):format("You have 20 seconds to roll on " .. LINK))
assert(p and p.item == 32235 and p.secs == 20 and p.note == nil and p.link == LINK, "English")
p = C(KIM, ("return NS.ParseForeignRollStart(%q)"):format("You have 15 seconds to roll on " .. LINK .. " - Tanks first"))
assert(p and p.secs == 15 and p.note == "Tanks first", "English with a note")
p = C(KIM, ("return NS.ParseForeignRollStart(%q)"):format("Du hast 20 Sekunden um auf " .. LINK .. " zu würfeln"))
assert(p and p.item == 32235 and p.secs == 20 and p.note == nil, "German")
p = C(KIM, ("return NS.ParseForeignRollStart(%q)"):format("Du hast 30 Sekunden um auf " .. LINK .. " zu würfeln - nur |cffff0000MS|r"))
assert(p and p.secs == 30 and p.note == "nur MS", "German with a note, codes dropped: " .. tostring(p and p.note))
assert(C(KIM, ("return NS.ParseForeignRollStart(%q)"):format("You have 999 seconds to roll on " .. LINK)).secs == 120, "capped")
assert(C(KIM, "return NS.ParseForeignRollStart('You have 20 seconds to roll on nothing')") == nil, "no item, no round")
assert(C(KIM, "return NS.ParseForeignRollStart('5 seconds to roll')") == nil, "the countdown is no start")
assert(C(KIM, "return NS.IsForeignRollStop('Stop your rolls!')") == true and C(KIM, "return NS.IsForeignRollStop('Stopp deine Würfe!')") == true)
assert(C(KIM, "return NS.IsForeignRollStop('roll on')") == false)

---------------------------------------------------------------------------
-- an untrusted sender opens nothing: an officer who is not the master looter, a guest
---------------------------------------------------------------------------
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK, FRAK)
BUS.tick(0.5)
assert(not shown(KIM) and not shown(VULO), "an officer who does not loot starts nothing")
assert(C(VULO, "return NS.CurrentRoll()") == nil, "the lead watches nothing either")
chat("CHAT_MSG_RAID", "You have 20 seconds to roll on " .. LINK, PUG)
BUS.tick(0.5)
assert(not shown(KIM), "a guest starts nothing")

---------------------------------------------------------------------------
-- the master looter starts a round with Gargul
---------------------------------------------------------------------------
local before = chatCount(VULO)
local sentBefore = #BUS.sent
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK .. " - Tanks first", VULO)
BUS.tick(0.5)
assert(shown(KIM) and shown(FRAK), "the raiders with Amisia see their window")
assert(has(hint(KIM), "Runde von Vulo Sturmwind (Gargul)") and has(hint(KIM), "Tanks first"), hint(KIM))
assert(not shown(ANNA), "the window for other loot addons switched off")
assert(not shown(PUG), "a guest outside the guild sees none")
assert(not shown(VULO), "the starter has Gargul's own window")
-- the lead watches: no announcement, no WS, its roll window says who decides
local r = C(VULO, "local r = NS.CurrentRoll(); return { foreign = r.foreign, item = r.item, secs = r.seconds, wsSent = r.wsSent }")
assert(r.foreign == VULO and r.item == 32235 and r.secs == 20 and not r.wsSent, "a watched round")
assert(chatCount(VULO) == before, "the lead's Amisia says nothing")
for i = sentBefore + 1, #BUS.sent do
    assert(BUS.sent[i].kind ~= "WS", "no WS for a watched round")
end
assert(C(VULO, "return AmisiaRollFrame and AmisiaRollFrame:IsShown()") == true, "the lead's roll window opens")
assert(has(C(VULO, "return AmisiaRollFrame.lockHint:GetText()"), "Gargul-Runde: Gargul sagt den Gewinner an."))

-- Mainspec rolls 1-100 through the client; the lead's Amisia reads the server's line
assert(C(KIM, "AmisiaRollWindow.rows[1].ms:Click(); return #RANDOMS == 1 and RANDOMS[1][1] == 1 and RANDOMS[1][2] == 100"))
serverRoll(KIM, 77, 1, 100)
assert(C(FRAK, "AmisiaRollWindow.rows[1].os:Click(); return RANDOMS[1][1] == 1 and RANDOMS[1][2] == 99"), "Offspec 1-99")
serverRoll(FRAK, 98, 1, 99)
assert(C(VULO, "local e = NS.CurrentRoll().rolls['Kim Eisherz']; return e and e.value == 77 and e.kind == 'MS'"))
assert(has(status(KIM), "Gewürfelt: Mainspec 77"), status(KIM))
-- Passen sends nothing
local wa = BUS.count({ kind = "WA" })
C(KIM, "AmisiaRollWindow.rows[1].pass:Click()")
BUS.tick(0.5)
assert(BUS.count({ kind = "WA" }) == wa, "Passen in a Gargul round sends nothing")

-- "Stop your rolls!" ends it on every client; the lead announces nothing and decides nothing aloud
chat("CHAT_MSG_RAID_WARNING", "Stop your rolls!", VULO)
BUS.tick(0.5)
assert(has(status(KIM), "Runde vorbei."), status(KIM))
assert(C(VULO, "return NS.CurrentRoll().done") == true and C(VULO, "return NS.CurrentRoll().winner") == KIM)
assert(chatCount(VULO) == before, "no result in the chat")
local refused = C(VULO, "return select(2, NS.AnnounceRollResult())")
assert(refused == "Gargul-Runde: Gargul sagt den Gewinner an.", tostring(refused))
-- the award is known as MS for the loot record
assert(C(VULO, "return NS.RollKind(32235, 'Kim Eisherz')") == "MS")
BUS.tick(6)
assert(not shown(KIM), "the window closes after the result")

---------------------------------------------------------------------------
-- German, a stop from someone else does not end it, the clock does
---------------------------------------------------------------------------
chat("CHAT_MSG_RAID_WARNING", "Du hast 10 Sekunden um auf " .. LINK2 .. " zu würfeln", VULO)
BUS.tick(0.5)
assert(shown(KIM) and has(hint(KIM), "(Gargul)"), "German start")
chat("CHAT_MSG_RAID_WARNING", "Stopp deine Würfe!", FRAK)
BUS.tick(0.5)
assert(not has(status(KIM), "Runde vorbei."), "only the starter ends the round")
assert(C(VULO, "return NS.CurrentRoll().done") ~= true)
BUS.tick(14)
assert(not shown(KIM), "the clock closes it")
assert(C(VULO, "return NS.CurrentRoll().done") == true)
assert(chatCount(VULO) == before)

---------------------------------------------------------------------------
-- an Amisia round goes first; the same item started with both addons is one round
---------------------------------------------------------------------------
assert(C(VULO, ("return NS.StartRoll(%q, 20) == true"):format(LINK)))
BUS.tick(0.5)
assert(shown(KIM) and not has(hint(KIM), "(Gargul)"), "the Amisia round")
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK, VULO)
BUS.tick(0.5)
assert(not has(hint(KIM), "(Gargul)"), "no second window for the same round")
assert(C(VULO, "return NS.CurrentRoll().foreign") == nil, "the Amisia round stays")
C(VULO, "STUB.messages = {}")
BUS.tick(3)
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK2, VULO)
BUS.tick(0.5)
assert(C(VULO, "for _, m in ipairs(STUB.messages) do if m:find('während eine Amisia-Runde läuft', 1, true) then return true end end return false") == true,
    "the lead is told")
assert(C(VULO, "return NS.CurrentRoll().foreign") == nil and C(VULO, "return NS.CurrentRoll().item") == 32235)
assert(not has(hint(KIM), "(Gargul)"), "the raiders keep the Amisia round")
C(VULO, "NS.StopRoll()")
BUS.tick(6)

---------------------------------------------------------------------------
-- the chat lockdown: a secret line is not read; a readable start in the lockdown waits like the window
---------------------------------------------------------------------------
close(KIM)
for _, name in ipairs(CLIENTS) do
    C(name, ("local t = %q; STUB.secret[t] = true; STUB.fire('CHAT_MSG_RAID_WARNING', t, 'Vulo Sturmwind'); STUB.secret[t] = nil")
        :format("You have 20 seconds to roll on " .. LINK2))
end
BUS.tick(0.5)
assert(not shown(KIM), "a secret line opens nothing")
-- the lockdown begins while the round runs: the buttons wait as in an Amisia round
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK2, VULO)
BUS.tick(0.5)
assert(shown(KIM) and C(KIM, "return AmisiaRollWindow.rows[1].ms:IsEnabled()") == true)
BUS.lock(true)
BUS.tick(0.2)
assert(has(status(KIM), "Würfeln erst nach dem Kampf."), status(KIM))
assert(C(KIM, "return AmisiaRollWindow.rows[1].ms:IsEnabled()") == false)
BUS.lock(false)
BUS.tick(0.5)
assert(C(KIM, "return AmisiaRollWindow.rows[1].ms:IsEnabled()") == true)
chat("CHAT_MSG_RAID_WARNING", "Stop your rolls!", VULO)
BUS.tick(6)

---------------------------------------------------------------------------
-- the lead's setting off: no watched round; the raiders still get their window
---------------------------------------------------------------------------
C(VULO, "NS.Set('rolls.foreignWatch', false)")
local cur = C(VULO, "return NS.CurrentRoll() and NS.CurrentRoll().started")
BUS.tick(2)
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK, VULO)
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll() and NS.CurrentRoll().started") == cur, "no new round at the lead")
assert(shown(KIM))
chat("CHAT_MSG_RAID_WARNING", "Stop your rolls!", VULO)
BUS.tick(6)

---------------------------------------------------------------------------
-- B4: the announcement in English, off by default
---------------------------------------------------------------------------
assert(C(VULO, "return NS.SettingItem('rolls.announceEnglish').default") == false)
assert(C(VULO, "return NS.SettingItem('rolls.foreignWatch').default") == true and C(KIM, "return NS.SettingItem('rollwin.foreign').default") == true)
local function englishLines()
    return C(VULO, "local n = 0; for _, m in ipairs(STUB.chat) do if m.text:find('/roll 99 for off spec', 1, true) then n = n + 1 end end; return n")
end
C(VULO, ("NS.StartRoll(%q, 20)"):format(LINK))
BUS.tick(0.5)
assert(englishLines() == 0, "off by default")
C(VULO, "NS.StopRoll()")
BUS.tick(6)
C(VULO, "NS.Set('rolls.announceEnglish', true); NS.SetSoftRes('Anna 32235')")
C(VULO, ("NS.StartRoll(%q, 20)"):format(LINK))
BUS.tick(0.5)
assert(englishLines() == 1, "one English line")
assert(C(VULO, "for _, m in ipairs(STUB.chat) do if m.text:find('^Roll on ') then return m.text end end"):find("Reserved by Anna.", 1, true),
    "the reservers in English too")
assert(C(VULO, "for _, m in ipairs(STUB.chat) do if m.text:find('Roll auf', 1, true) then return true end end return false") == true,
    "the German line stays")
C(VULO, "NS.StopRoll()")
