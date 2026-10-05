-- Review of 1.6 (Forever names): group loot announced once, a bare first name on the list only
-- for a single raider of that first name (roll rank, "du", "SR (du)", !sr), hand rolls in the
-- spelling of the round, ambiguous names, rolls after the hand-out, a stale "not announced" round,
-- reminders in the chat lockdown, forgetting name fixes, renaming without regard to case.
local failed = {}
local function check(label, fn)
    local ok, err = pcall(fn)
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(err) end
end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function roll(name, v) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, 1, 100)) end
local function lastMsg() return STUB.messages[#STUB.messages] end

local LEAD = { name = "Leiter Eins", class = "PRIEST" }
local STURM = { name = "Vulo Sturmwind", class = "WARRIOR" }
local EIS = { name = "Vulo Eisherz", class = "MAGE" }
local VULOO = { name = "Vuloo", class = "PRIEST" }
local FRAK = { name = "Fraktur Stein", class = "SHAMAN" }
STUB.player = "Leiter Eins"
STUB.roster = { LEAD, STURM, EIS, FRAK }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local l1 = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local l2 = STUB.item(32837, "Warglaive of Azzinoth", 5)

---------------------------------------------------------------------------
-- 1. group loot: the lead's loot window does not announce what the roll frames announce
---------------------------------------------------------------------------
check("1 group loot once", function()
    STUB.target, STUB.targetGUID = "Illidan Stormrage", "Creature-0-1-1-1-22917-1"
    local function corpse(guid)
        STUB.loot = { { link = l1, name = "x", src = guid }, { link = l2, name = "x", src = guid } }
    end
    corpse("Creature-0-1-1-1-22917-1")
    STUB.rolls[11], STUB.rolls[12] = l1, l2
    for _, method in ipairs({ 3, 4, 1 }) do   -- group loot, need before greed, round robin
        STUB.lootMethod = method
        STUB.tick(400); STUB.chat = {}
        STUB.fire("START_LOOT_ROLL", 11, 60000); STUB.fire("START_LOOT_ROLL", 12, 60000)
        STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED", false)
        STUB.tick(2)
        assert(#STUB.chat == 3 and STUB.chat[1].text == "Amisia Würfeln: 2 Items",
            ("method %d: %d lines, first %s"):format(method, #STUB.chat, tostring(STUB.chat[1] and STUB.chat[1].text)))
    end
    -- free-for-all: no rolls, the loot window announces
    STUB.lootMethod = 0
    corpse("Creature-0-1-1-1-22917-2")
    STUB.tick(10); STUB.chat = {}
    STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED", false)
    assert(#STUB.chat == 3 and has(STUB.chat[1].text, "Amisia Loot"), "free-for-all announces the corpse")
    -- group loot with the roll announcement switched off: the loot window announces
    STUB.lootMethod = 3
    NS.Set("loot.groupLoot", false)
    corpse("Creature-0-1-1-1-22917-3")
    STUB.tick(10); STUB.chat = {}
    STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED", false)
    assert(#STUB.chat == 3 and has(STUB.chat[1].text, "Amisia Loot"), "without roll announcements the corpse is announced")
    NS.Reset("loot.groupLoot")
    STUB.lootMethod = nil
    STUB.fire("LOOT_CLOSED")
    STUB.loot = {}
end)

---------------------------------------------------------------------------
-- 2. "Vulo" on the list while two raiders are called Vulo: no one's reservation
---------------------------------------------------------------------------
NS.SetSoftRes("Vulo 32235\n")
check("2 roll rank with two Vulos", function()
    STUB.tick(30)
    assert(NS.StartRoll(l1, 20))
    roll("Vulo Sturmwind", 40); roll("Vulo Eisherz", 90)
    STUB.tick(21)
    local r = NS.LastRoll()
    for _, e in ipairs(NS.RollRanking(r)) do assert(e.rank == "MS", e.name .. " ranks " .. tostring(e.rank)) end
    assert(NS.RollKind(32235, "Vulo Sturmwind") == "MS" and NS.RollKind(32235, "Vulo Eisherz") == "MS", "no SR for the award")
end)
check("2 roll rank with one Vulo", function()
    STUB.roster = { LEAD, STURM, FRAK }
    STUB.tick(30)
    assert(NS.StartRoll(l1, 20))
    roll("Vulo Sturmwind", 40); roll("Fraktur Stein", 90)
    STUB.tick(21)
    local r = NS.LastRoll()
    assert(r.winner == "Vulo Sturmwind" and NS.RollKind(32235, "Vulo Sturmwind") == "SR", "the only Vulo reserved it")
    STUB.roster = { LEAD, STURM, EIS, FRAK }
end)
check("2 du, SR (du) and !sr", function()
    STUB.player = "Vulo Sturmwind"
    local text = NS.SoftResTooltipText(32235)
    assert(text == "Reserviert: Vulo", tostring(text))
    local frame = GroupLootFrame1
    STUB.rolls[31] = l1
    frame:Hide(); frame.rollID = 31; frame:Show()
    assert(NS.RollMarkText(frame) == "SR", tostring(NS.RollMarkText(frame)))
    assert(#NS.ReservesOf("Vulo Sturmwind") == 0 and #NS.ReservesOf("Vulo Eisherz") == 0, "!sr of a Vulo")
    -- one Vulo in the raid: it is him
    STUB.roster = { LEAD, STURM, FRAK }
    assert(NS.SoftResTooltipText(32235) == "Reserviert: du", tostring(NS.SoftResTooltipText(32235)))
    frame:Hide(); frame:Show()
    assert(NS.RollMarkText(frame) == "SR (du)", tostring(NS.RollMarkText(frame)))
    assert(#NS.ReservesOf("Vulo Sturmwind") == 1, "!sr of the only Vulo")
    frame:Hide()
    STUB.player = "Leiter Eins"
    STUB.roster = { LEAD, STURM, EIS, FRAK }
end)
NS.ClearSoftRes()

---------------------------------------------------------------------------
-- 3. hand rolls
---------------------------------------------------------------------------
check("3a one entry per player", function()
    STUB.roster = { LEAD, VULOO, STURM }
    STUB.tick(30)
    assert(NS.StartRoll(l1, 20))
    local r = NS.CurrentRoll()
    roll("Vulo", 30)                       -- the chat without surname
    local e, why = NS.AddManualRoll("Vulo Sturmwind", 95, "MS")
    assert(e, why)
    assert(#r.order == 1 and r.order[1] == "Vulo" and r.rolls.Vulo.value == 95, "#order " .. #r.order)
    -- a chat roll after the hand roll: already rolled
    NS.AddManualRoll("Vuloo", 20, "MS")
    roll("Vuloo", 99)
    assert(r.rolls.Vuloo.value == 20 and r.ignored[#r.ignored].why == "schon gewürfelt", "the second roll is ignored")
    STUB.tick(21)
end)
check("3a tie-break in the chat spelling", function()
    STUB.tick(30)
    assert(NS.StartRoll(l1, 20))
    roll("Vulo", 50); roll("Vuloo", 50)
    STUB.tick(21)
    assert(NS.LastRoll().tie, "a tie")
    assert(NS.RerollTie())
    local t = NS.CurrentRoll()
    local e, why = NS.AddManualRoll("Vulo Sturmwind", 70, "MS")
    assert(e and e.name == "Vulo", tostring(why))
    roll("Vuloo", 40)
    STUB.tick(11)
    assert(t.winner == "Vulo", tostring(t.winner))
    STUB.roster = { LEAD, STURM, EIS, FRAK }
end)
check("3b an ambiguous first name", function()
    STUB.tick(30)
    assert(NS.StartRoll(l1, 20))
    local e, why = NS.AddManualRoll("Vulo", 87, "MS")
    assert(e == nil and why == "Name nicht eindeutig: Vulo Eisherz, Vulo Sturmwind", tostring(why))
    assert(next(NS.CurrentRoll().rolls) == nil, "nothing entered")
    assert(NS.AddManualRoll("vulo eisherz", 50, "MS").name == "Vulo Eisherz", "the full name works")
    NS.StopRoll()
end)
check("3c no new decision after the hand-out", function()
    STUB.tick(30)
    assert(NS.StartRoll(l1, 20))
    roll("Fraktur Stein", 60)
    STUB.tick(21)
    local r = NS.LastRoll()
    assert(r.winner == "Fraktur Stein")
    STUB.tick(5)
    assert(NS.AddAwardTo(NS.Active(), { name = "Fraktur Stein", item = 32235, kind = "MS", t = time(), to = "player" }))
    local e, why = NS.AddManualRoll("Vulo Eisherz", 90, "MS")
    assert(e == nil and why == "Das Item ist schon vergeben; erst die Vergabe ändern.", tostring(why))
    assert(r.winner == "Fraktur Stein" and not r.dirty and not r.rolls["Vulo Eisherz"], "the round stays decided")
end)
check("3d a stale unannounced round", function()
    STUB.tick(30)
    assert(NS.StartRoll(l2, 20))
    roll("Fraktur Stein", 60)
    STUB.tick(21)
    local A = NS.LastRoll()
    assert(NS.AddManualRoll("Vulo Eisherz", 90, "MS"))
    assert(A.dirty and A.winner == "Vulo Eisherz", "changed by hand, not announced")
    assert(NS.StartRoll(l1, 20))
    assert(not A.dirty, "the older round lets go of its result button")
    assert(has(lastMsg(), "nicht angesagt"), tostring(lastMsg()))
    NS.StopRoll()
end)

---------------------------------------------------------------------------
-- 6. reminders in the chat lockdown
---------------------------------------------------------------------------
check("6 reminders refused in the lockdown", function()
    NS.SetSoftRes("Fraktur Stein 32235\n")
    STUB.chatLock = true
    STUB.chat, STUB.popup = {}, nil
    local n, why = NS.SendSoftResReminders()
    assert(n == 0 and why == "Chat ist gerade gesperrt (Bosskampf). Nach dem Kampf erneut.", tostring(why))
    assert(next(AmisiaDB.softres.reminded) == nil and NS.ChatQueueSize() == 0, "no one marked, nothing queued")
    NS.ConfirmSoftResReminders()
    assert(STUB.popup == nil and lastMsg() == "|cffe2b857Amisia:|r Chat ist gerade gesperrt (Bosskampf). Nach dem Kampf erneut.", tostring(lastMsg()))
    STUB.chatLock = false
    STUB.fire("ADDON_RESTRICTION_STATE_CHANGED"); STUB.tick(1)
    assert(NS.SendSoftResReminders() == 2, "after the fight")
    STUB.tick(10)
end)

---------------------------------------------------------------------------
-- 7. forgetting name fixes; renaming without regard to case
---------------------------------------------------------------------------
check("7a /amisia sr vergessen", function()
    AmisiaDB.srAliases = { vulo = "Vulo Sturmwind", frak = "Fraktur Stein", chorf = "Chorf Eins" }
    NS.Dispatch("sr vergessen Vulo")
    assert(AmisiaDB.srAliases.vulo == nil and AmisiaDB.srAliases.frak, "one by its list name")
    assert(has(lastMsg(), "Vulo vergessen"), tostring(lastMsg()))
    NS.Dispatch("sr vergessen fraktur stein")
    assert(AmisiaDB.srAliases.frak == nil and AmisiaDB.srAliases.chorf, "one by its fixed name")
    NS.Dispatch("sr vergessen Gustav")
    assert(has(lastMsg(), "Keine gemerkte Namenskorrektur für Gustav"), tostring(lastMsg()))
    AmisiaDB.srAliases.anna = "Anna Berg"
    NS.Dispatch("sr vergessen")
    assert(next(AmisiaDB.srAliases) == nil and has(lastMsg(), "2 gemerkte Namenskorrekturen vergessen"), tostring(lastMsg()))
end)
check("7b rename ignores case", function()
    NS.SetSoftRes("Vulo 32235\nFraktur 32837\n")
    assert(NS.RenameReserve("vulo", "Vulo Sturmwind") == 1, "lower case finds the list's spelling")
    assert(NS.ReservedBy(32235)[1] == "Vulo Sturmwind" and #NS.ReservedBy(32235) == 1)
    assert(AmisiaDB.softres.renamed["Vulo Sturmwind"] == "Vulo", tostring(AmisiaDB.softres.renamed["Vulo Sturmwind"]))
    assert(NS.RenameReserve("FRAKTUR", "Fraktur Stein", true) == 1)
    assert(AmisiaDB.srAliases.fraktur == "Fraktur Stein", "remembered")
    NS.ClearSoftRes()
    AmisiaDB.srAliases = {}
end)

assert(#failed == 0, #failed .. " failed: " .. table.concat(failed, " | "))
