-- Rolls entered by hand: into the running and the finished round, range and name checks, a new
-- decision with "Ergebnis ansagen", the lockdown marks (r.lockdown, r.hidden), the countdown that
-- runs out in the lockdown, the roll window's entry row and hint, the Rolls page and /amisia wurf.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Vulo Sturmwind", class = "WARRIOR" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")
NS.NoteMember(s, "Anna", "MAGE", time())   -- was in the raid, left the group
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastChat() return STUB.chat[#STUB.chat] and STUB.chat[#STUB.chat].text end
local function lastMsg() return STUB.messages[#STUB.messages] end
local RANGE = "Wurf 1-100 (MS) oder 1-99 (OS)."

---------------------------------------------------------------------------
-- into the running round
---------------------------------------------------------------------------
local e, why = NS.AddManualRoll("Fraktur", 50, "MS")
assert(e == nil and why == "Keine Runde.", tostring(why))

assert(NS.StartRoll(link, 20))
local r = NS.CurrentRoll()
assert(not r.lockdown and (r.hidden or 0) == 0, "an open round")
e = NS.AddManualRoll("Fraktur", 87, "MS")
assert(e and e.manual and e.low == 1 and e.high == 100 and e.kind == "MS" and e.value == 87, "entered")
assert(r.rolls.Fraktur == e and r.order[#r.order] == "Fraktur" and e.class == "SHAMAN")
-- ranges
for _, bad in ipairs({ { 100, "OS" }, { 0, "MS" }, { 101, "MS" }, { 50.5, "MS" }, { "abc", "MS" }, { 50, "XX" } }) do
    local ok, w = NS.AddManualRoll("Chorf", bad[1], bad[2])
    assert(ok == nil and w == RANGE, tostring(bad[1]) .. " " .. tostring(bad[2]) .. ": " .. tostring(w))
end
e = NS.AddManualRoll("Chorf", 99, "os")
assert(e and e.kind == "OS" and e.high == 99, "offspec, any case")
assert(NS.AddManualRoll("Chorf", "45").kind == "MS", "mainspec by default, the number as text, replaces")
assert(r.rolls.Chorf.value == 45)
NS.AddManualRoll("Chorf", 99, "OS")
-- names: the group, the recording, nobody else
local ok, w = NS.AddManualRoll("Gustav", 50, "MS")
assert(ok == nil and w == "Gustav ist nicht in der Gruppe.", tostring(w))
e = NS.AddManualRoll("anna", 40, "MS")
assert(e and e.name == "Anna" and r.rolls.Anna, "a member of the recording, in its spelling")
assert(r.plus.Anna ~= nil, "plus-one frozen for the hand roll")
e = NS.AddManualRoll("vulo sturmwind", 10, "MS")
assert(e and e.name == "Vulo Sturmwind", "the group's spelling")
-- a chat roll replaced by hand
roll("Vuloo", 30, 1, 100)
assert(r.rolls.Vuloo.value == 30 and not r.rolls.Vuloo.manual)
NS.AddManualRoll("Vuloo", 95, "MS")
local n = 0
for _, name in ipairs(r.order) do if name == "Vuloo" then n = n + 1 end end
assert(n == 1 and r.rolls.Vuloo.value == 95 and r.rolls.Vuloo.manual, "one entry per name")
STUB.tick(20)
assert(r.done and r.winner == "Vuloo" and not r.dirty, "the round ends as ever")
assert(lastChat() == "Stopp! Gewinner: Vuloo (95, MS).", lastChat())

---------------------------------------------------------------------------
-- into the finished round: decided anew, announced only on request
---------------------------------------------------------------------------
local before = #STUB.chat
e = NS.AddManualRoll("Fraktur", 99, "MS")
assert(e and r.rolls.Fraktur.value == 99, "replaced in the finished round")
assert(r.winner == "Fraktur" and r.dirty, "decided anew")
assert(#STUB.chat == before, "nothing announced by itself")
NS.ShowRollFrame()
local F = NS.RollFrame
assert(F.resultBtn:IsEnabled(), "Ergebnis ansagen while dirty")
assert(F.rows[1].who == "Fraktur" and F.rows[1].hand:GetText() == "Hand", "Hand behind a hand roll")
local plain
for i = 1, #F.rows do if F.rows[i].who == "Chorf" then plain = F.rows[i] end end
assert(plain and plain.hand:GetText() == "Hand")
F.resultBtn:Click()
assert(has(lastChat(), "Gewinner: Fraktur (99, MS)"), lastChat())
assert(not r.dirty and not F.resultBtn:IsEnabled(), "announced, the button rests")
-- a tie by hand
NS.AddManualRoll("Vuloo", 99, "MS")
assert(r.tie and #r.tie == 2 and not r.winner and r.dirty)
assert(NS.AnnounceRollResult(r))
assert(has(lastChat(), "Gleichstand: Fraktur und Vuloo (99, MS)"), lastChat())
assert(not r.dirty)
-- not after 10 minutes
STUB.tick(601)
ok, w = NS.AddManualRoll("Fraktur", 50, "MS")
assert(ok == nil and w == "Keine Runde.", "too late")

---------------------------------------------------------------------------
-- the lockdown
---------------------------------------------------------------------------
STUB.tick(10)
STUB.chat = {}
STUB.chatLock = true
assert(NS.StartRoll(link, 10))
r = NS.CurrentRoll()
assert(r.lockdown, "started in the lockdown")
local secret1 = (RANDOM_ROLL_RESULT):format("Fraktur", 66, 1, 100)
local secret2 = (RANDOM_ROLL_RESULT):format("Chorf", 12, 1, 100)
STUB.secret[secret1], STUB.secret[secret2] = true, true
STUB.fire("CHAT_MSG_SYSTEM", secret1)
STUB.fire("CHAT_MSG_SYSTEM", secret2)
assert(r.hidden == 2 and not r.rolls.Fraktur, "secret lines counted, not read")
NS.ShowRollFrame()
assert(F.lockHint:IsShown() and has(F.lockHint:GetText(), "Bosskampf") and has(F.lockHint:GetText(), "(2 Zeilen)"), F.lockHint:GetText())
-- the entry row: name, number, OS, Enter
F.namePick:SetValue("Chorf")
F.valueEdit:SetText("42")
F.osChip:Click()
F.valueEdit.scripts.OnEnterPressed(F.valueEdit)
assert(r.rolls.Chorf and r.rolls.Chorf.value == 42 and r.rolls.Chorf.kind == "OS" and r.rolls.Chorf.manual, "entered in the window")
assert(F.valueEdit:GetText() == "", "the number box is emptied")
F.namePick:SetValue("Fraktur")
F.valueEdit:SetText("150")
F.msChip:Click()
F.addBtn:Click()
assert(not r.rolls.Fraktur and has(F.note:GetText(), RANGE), "the reason shows in the window")
F.valueEdit:SetText("66")
F.addBtn:Click()
assert(r.rolls.Fraktur and r.rolls.Fraktur.kind == "MS" and r.rolls.Fraktur.value == 66)
assert(F.rows[1].who == "Fraktur" and F.rows[1].hand:GetText() == "Hand")
-- the Rolls page names the lockdown and the hand rolls
NS.ShowPage("rolls")
local page = NS.RollsPageFrame()
assert(has(page.current:GetText(), "Bosskampf, 2 Zeilen nicht lesbar"), page.current:GetText())
assert(has(page.current:GetText(), "2 von Hand"), page.current:GetText())
assert(has(page.hint:GetText(), "Im Bosskampf Würfe im Roll-Fenster von Hand eintragen."), page.hint:GetText())
-- the countdown runs out while the chat waits
STUB.tick(10)
assert(r.done and r.winner == "Fraktur")
STUB.chatLock = false
STUB.tick(3)
for _, c in ipairs(STUB.chat) do
    assert(c.text ~= "5 Sekunden." and c.text ~= "3 Sekunden.", "a stale countdown line went out")
end
assert(has(lastChat(), "Gewinner: Fraktur (66, MS)"), lastChat())
assert(has(STUB.chat[1].text, "Roll auf"), "the start waited and went out")
-- the round's history line names the hand rolls
assert(has(NS.RoundLine(r), "2 von Hand"), NS.RoundLine(r))

-- a lockdown that begins during the round
STUB.tick(10)
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
assert(not r.lockdown)
STUB.chatLock = true
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.tick(0.1)
assert(r.lockdown, "set by the restriction event")
STUB.chatLock = false
NS.StopRoll()
STUB.tick(3)
NS.ShowRollFrame()
-- no hint in an open round; the window's entry row fits above the buttons
assert(NS.StartRoll(link, 20))
assert(not F.lockHint:IsShown() or not has(F.lockHint:GetText(), "Bosskampf"), "no lockdown hint in an open round")
NS.StopRoll()
local W_ = F:GetWidth()
local right = 0
for _, part in ipairs({ F.namePick, F.valueEdit, F.msChip, F.osChip, F.addBtn }) do
    local p = part.points.TOPLEFT
    assert(p and (p.rel == nil or p.rel == F), "anchored to the window")
    assert(p.x >= right, "no overlap in the entry row")
    right = p.x + part:GetWidth()
end
assert(right <= W_ - 12, ("the entry row fits: %d of %d"):format(right, W_))
local rowBottom = 50 + #F.rows * 18
assert(-F.namePick.points.TOPLEFT.y >= rowBottom, "the entry row lies below the list")
assert(-F.namePick.points.TOPLEFT.y + 20 <= F:GetHeight() - 32 - 14, "and above the hint and the buttons")
for i = 1, #F.rows do
    local row = F.rows[i]
    local edge = 0
    for _, fs in ipairs({ row.name, row.kind, row.value, row.hand, row.why }) do
        local p = fs.points.LEFT
        assert(p.x >= edge, "row parts do not overlap")
        edge = p.x + fs._w
    end
    assert(edge <= row:GetWidth() - 2 - 64, "row parts end before the button")
end

---------------------------------------------------------------------------
-- /amisia wurf
---------------------------------------------------------------------------
STUB.tick(10)
assert(NS.StartRoll(link, 20))
r = NS.CurrentRoll()
NS.Dispatch("wurf Vulo Sturmwind 87 os")
assert(r.rolls["Vulo Sturmwind"] and r.rolls["Vulo Sturmwind"].value == 87 and r.rolls["Vulo Sturmwind"].kind == "OS", "name with a space")
assert(has(lastMsg(), "Vulo Sturmwind") and has(lastMsg(), "87"), lastMsg())
NS.Dispatch("addroll Fraktur 12")
assert(r.rolls.Fraktur.value == 12 and r.rolls.Fraktur.kind == "MS", "the alias")
NS.Dispatch("wurf Gustav 50")
assert(lastMsg():find("Gustav ist nicht in der Gruppe.", 1, true), lastMsg())
NS.Dispatch("wurf Fraktur")
assert(has(lastMsg(), "/amisia wurf"), lastMsg())
NS.Set("ui.view", "raider")
NS.Dispatch("wurf Chorf 50")
assert(not r.rolls.Chorf, "officers only")
NS.Reset("ui.view")
NS.StopRoll()

-- every UI and chat string stays Latin-1
for _, file in ipairs({ "Raid/Rolls.lua", "Raid/RollFrame.lua", "UI/Pages/Rolls.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for c in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. c) end
end
