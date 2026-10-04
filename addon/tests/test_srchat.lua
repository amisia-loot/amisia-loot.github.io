-- Soft-reserves in the chat: the loot lead, !sr and !sr <Item> for raiders without the addon (limits,
-- whispers to the raw sender), reminders with a confirmation, the raid summary and /amisia sr.
STUB.instance = { name = "Dalaran", type = "none", id = 0 }
local function roster(...)
    local out = {}
    for i, n in ipairs({ ... }) do out[i] = { name = n, class = "WARRIOR" } end
    STUB.roster = out
end
roster("Vuloo", "Fraktur-Realm", "Chorf", "Anna", "Bob")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
local LIST = "Fraktur 32235\nFraktur 32235\nVuloo 32837\nAnna 32235\nGustav 32837\n"
NS.SetSoftRes(LIST)
local short = date("%d.%m.")
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local function last() return STUB.chat[#STUB.chat] end
local function ask(text, sender, event) STUB.fire(event or "CHAT_MSG_WHISPER", text, sender) end
-- every test step starts with a full chat bucket and outside the 15 s window
local function later() STUB.tick(20) end

---------------------------------------------------------------------------
-- the loot lead
---------------------------------------------------------------------------
assert(type(NS.IsLootLead) == "function")
assert(NS.IsLootLead() == true, "the leader without master loot")
STUB.leader = false
assert(NS.IsLootLead() == false, "not the leader")
STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 3, 1
assert(NS.IsLootLead() == false, "master loot by someone else")
STUB.playerRaidIndex = 3
assert(NS.IsLootLead() == true, "master looter myself")
STUB.leader = true; STUB.playerRaidIndex = 1
assert(NS.IsLootLead() == false, "master loot beats the leader")
STUB.lootMethod, STUB.mlRaidID = nil, nil
STUB.leader = false
assert(NS.Set("loot.lead", "me"))
assert(NS.IsLootLead() == true, "loot.lead = me")
NS.Reset("loot.lead")
STUB.leader = true
NS.Set("ui.view", "raider")
assert(NS.IsLootLead() == false, "never in the raider view")
NS.Reset("ui.view")
-- the global of an older client: "master" and the raid index of the looter
local cpi = C_PartyInfo
C_PartyInfo = nil
_G.GetLootMethod = function() return "master", nil, 4 end
STUB.playerRaidIndex = 4
assert(NS.IsLootLead() == true, "the old global")
STUB.playerRaidIndex = 1
assert(NS.IsLootLead() == false)
_G.GetLootMethod = nil
assert(NS.IsLootLead() == true, "without any loot method the leader leads")
C_PartyInfo = cpi
local saved = STUB.roster
STUB.roster = {}
assert(NS.IsLootLead() == false, "only in a raid")
STUB.roster = saved
local item = NS.SettingItem("loot.lead")
assert(item and item.type == "choice" and item.default == "auto" and item.section.officer, "loot.lead in the officer section loot")

---------------------------------------------------------------------------
-- !sr: own reservations, by whisper to the raw sender
---------------------------------------------------------------------------
STUB.chat = {}
ask("!sr", "Fraktur-Realm")
assert(#STUB.chat == 1, #STUB.chat)
assert(last().chan == "WHISPER" and last().target == "Fraktur-Realm", "whisper to the sender as the client gave it")
assert(last().text == "Amisia: Deine Reservierungen (Liste vom " .. short .. "): " .. link .. " x2", last().text)
-- asked in the raid chat: the answer is still a whisper
ask("!SR", "Chorf", "CHAT_MSG_RAID")
assert(#STUB.chat == 2 and last().chan == "WHISPER" and last().target == "Chorf")
assert(last().text == "Amisia: Du hast nichts reserviert (Liste vom " .. short .. ").", last().text)
ask("!softres", "Anna", "CHAT_MSG_RAID_LEADER")
assert(#STUB.chat == 3 and last().target == "Anna" and has(last().text, link), "the alias")
-- one answer per sender every 15 s
ask("!sr", "Fraktur-Realm")
assert(#STUB.chat == 3, "the same sender within 15 s is ignored")
STUB.tick(15)
ask("!sr", "Fraktur-Realm")
assert(#STUB.chat == 4, "after 15 s again")

---------------------------------------------------------------------------
-- !sr <Item>: by link or by part of the name
---------------------------------------------------------------------------
later()
ask("!sr " .. link, "Bob")
assert(last().target == "Bob" and last().text == "Amisia: " .. link .. " reserviert von Anna, Fraktur x2", last().text)
ask("!sr warg", "Anna")
assert(last().target == "Anna" and last().text == "Amisia: " .. link2 .. " reserviert von Gustav, Vuloo", last().text)
ask("!sr Zzz", "Chorf")
assert(last().target == "Chorf" and last().text == "Amisia: Kein reserviertes Item passt zu \"zzz\".", last().text)
later()
-- several matches: the first three in one answer
ask("!sr a", "Bob")
assert(has(last().text, link .. " reserviert von Anna, Fraktur x2") and has(last().text, link2 .. " reserviert von Gustav, Vuloo"), last().text)
assert(not has(last().text, "\n"))
-- an item nobody reserved
later()
local link3 = STUB.item(30000, "Plain Thing", 4)
ask("!sr " .. link3, "Bob")
assert(last().text == "Amisia: " .. link3 .. " reserviert von niemand.", last().text)

---------------------------------------------------------------------------
-- no answer
---------------------------------------------------------------------------
local function silent(why, fn)
    later()
    local n = #STUB.chat
    fn()
    ask("!sr", "Bob")
    assert(#STUB.chat == n, why)
end
silent("softres.chat off", function() NS.Set("softres.chat", false) end); NS.Reset("softres.chat")
silent("not the loot lead", function() STUB.leader = false end); STUB.leader = true
silent("raider view", function() NS.Set("ui.view", "raider") end); NS.Reset("ui.view")
silent("no list", function() NS.ClearSoftRes() end); NS.SetSoftRes(LIST)
silent("no raid", function() STUB.roster = {} end); roster("Vuloo", "Fraktur-Realm", "Chorf", "Anna", "Bob")
later()
local n0 = #STUB.chat
ask("!sr", "Fremder")
assert(#STUB.chat == n0, "a sender outside the group")
STUB.secret.Bob = true
ask("!sr", "Bob")
assert(#STUB.chat == n0, "a secret sender is skipped")
STUB.secret.Bob = nil
ask("!sr", "Vuloo")
assert(#STUB.chat == n0, "my own line")

---------------------------------------------------------------------------
-- at most 20 answers a minute
---------------------------------------------------------------------------
later()
local many = { "Vuloo" }
for i = 1, 24 do many[#many + 1] = "Raider" .. string.char(64 + i) end
roster(unpack(many))
STUB.chat = {}
local msgs = #STUB.messages
for i = 2, 23 do ask("!sr", many[i]) end
assert(#STUB.chat == 20, "20 a minute: " .. #STUB.chat)
assert(#STUB.messages == msgs + 1 and has(STUB.messages[#STUB.messages], "!sr"), "one note of its own")
ask("!sr", many[24])
assert(#STUB.chat == 20 and #STUB.messages == msgs + 1, "still quiet, no second note")
STUB.tick(60)
ask("!sr", many[24])
assert(#STUB.chat == 21, "the next minute answers again")
roster("Vuloo", "Fraktur-Realm", "Chorf", "Anna", "Bob")

---------------------------------------------------------------------------
-- an old list says so
---------------------------------------------------------------------------
later()
AmisiaDB.softres.date = date("%Y-%m-%d", STUB.now - 10 * 86400)
local age = NS.SoftResAge()
assert(age and age > 7, tostring(age))
local note = ("(Liste ist %d Tage alt)"):format(age)
ask("!sr", "Chorf")
assert(has(last().text, note), last().text)
ask("!sr", "Fraktur")
assert(has(last().text, link .. " x2 " .. note), last().text)
AmisiaDB.softres.date = date("%Y-%m-%d")

---------------------------------------------------------------------------
-- a long answer stays within three lines
---------------------------------------------------------------------------
later()
local lines = {}
for i = 1, 30 do
    local id = 40000 + i
    STUB.item(id, "Very Long Item Name Number " .. i, 4)
    lines[#lines + 1] = "Bob " .. id
end
NS.SetSoftRes(table.concat(lines, "\n"))
STUB.chat = {}
ask("!sr", "Bob")
assert(#STUB.chat == 3, "three lines at most: " .. #STUB.chat)
for _, c in ipairs(STUB.chat) do assert(#c.text <= 255 and c.target == "Bob") end
assert(has(STUB.chat[3].text, "weitere"), STUB.chat[3].text)
NS.SetSoftRes(LIST)

---------------------------------------------------------------------------
-- reminders: only those without a reservation, once per list, after a confirmation
---------------------------------------------------------------------------
later()
local origShow = StaticPopup_Show
_G.StaticPopup_Show = function(...)
    local p = origShow(...)
    p.SetFrameStrata = function(self, s) self.strata = s end
    p.Raise = function(self) self.raised = true end
    return p
end
local names = NS.SoftResReminders()
assert(table.concat(names, ",") == "Bob,Chorf", table.concat(names, ","))
assert(NS.Set("softres.remindText", "Liste: softres.it/abc"))
STUB.chat = {}
STUB.popup = nil
NS.ConfirmSoftResReminders()
assert(STUB.popup and STUB.popup.which == "AMISIA_SR_REMIND" and STUB.popup.a1 == 2, "asks first")
assert(STUB.popup.strata == "FULLSCREEN_DIALOG" and STUB.popup.raised, "lifted above the main window")
assert(StaticPopupDialogs.AMISIA_SR_REMIND.text == "%d Raidern ohne Reserve flüstern?")
assert(#STUB.chat == 0, "nothing before the confirmation")
STUB.acceptPopup()
assert(#STUB.chat == 2, #STUB.chat)
assert(STUB.chat[1].chan == "WHISPER" and STUB.chat[1].target == "Bob" and STUB.chat[2].target == "Chorf")
assert(STUB.chat[1].text == "Amisia: Du hast für heute noch nichts reserviert. Liste: softres.it/abc", STUB.chat[1].text)
assert(AmisiaDB.softres.reminded.Bob == STUB.now and AmisiaDB.softres.reminded.Chorf == STUB.now)
assert(#NS.SoftResReminders() == 0 and NS.SendSoftResReminders() == 0, "once per list")
STUB.popup = nil
NS.ConfirmSoftResReminders()
assert(STUB.popup == nil and has(STUB.messages[#STUB.messages], "schon erinnert"), STUB.messages[#STUB.messages])
NS.Reset("softres.remindText")
-- a new list reminds again; I am never whispered; the raw roster name is the target
roster("Vuloo", "Fraktur-Realm", "Chorf")
NS.SetSoftRes("Chorf 32235")
names = NS.SoftResReminders()
assert(table.concat(names, ",") == "Fraktur", "not myself: " .. table.concat(names, ","))
STUB.chat = {}
assert(NS.SendSoftResReminders() == 1)
assert(STUB.chat[1].target == "Fraktur-Realm" and STUB.chat[1].text == "Amisia: Du hast für heute noch nichts reserviert.", STUB.chat[1].target)
-- outside a raid or in the raider view: no dialog
STUB.roster = {}
STUB.popup = nil
NS.ConfirmSoftResReminders()
assert(STUB.popup == nil and has(STUB.messages[#STUB.messages], "Raid"), STUB.messages[#STUB.messages])
roster("Vuloo", "Fraktur-Realm", "Chorf", "Anna", "Bob")
NS.Set("ui.view", "raider")
NS.ConfirmSoftResReminders()
assert(STUB.popup == nil and has(STUB.messages[#STUB.messages], "Offiziersansicht"), STUB.messages[#STUB.messages])
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- the summary in the raid chat
---------------------------------------------------------------------------
later()
NS.SetSoftRes(LIST)
STUB.chat = {}
assert(NS.PostSoftResSummary() == 1)
assert(last().chan == "RAID" and last().text == "Soft-Reserves: 3 von 5 haben reserviert. Ohne Reserve: Bob, Chorf.", last().text)
later()
roster("Vuloo", "Fraktur", "Anna")
STUB.chat = {}
NS.PostSoftResSummary()
assert(last().text == "Soft-Reserves: alle 3 haben reserviert.", last().text)
-- many without a reservation: two lines at most, the rest counted
later()
many = { "Vuloo" }
for i = 1, 39 do many[#many + 1] = ("Langername%02d"):format(i) end
roster(unpack(many))
STUB.chat = {}
assert(NS.PostSoftResSummary() == 2)
assert(#STUB.chat == 2)
assert(has(STUB.chat[1].text, "Soft-Reserves: 1 von 40 haben reserviert. Ohne Reserve: Langername01"), STUB.chat[1].text)
assert(STUB.chat[2].text:find("und %d+ weitere%.$"), STUB.chat[2].text)
for _, c in ipairs(STUB.chat) do assert(#c.text <= 255) end
STUB.roster = {}
STUB.chat = {}
assert(NS.PostSoftResSummary() == nil and #STUB.chat == 0, "only in a raid")

---------------------------------------------------------------------------
-- /amisia sr with its sub-words
---------------------------------------------------------------------------
later()
roster("Vuloo", "Fraktur-Realm", "Chorf", "Anna", "Bob")
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(has(help, "/amisia sr [pruefen|erinnern|posten]"), help)
msgs = #STUB.messages
NS.Dispatch("sr pruefen")
local out = table.concat(STUB.messages, "\n", msgs + 1)
assert(has(out, "Abgleich mit Raid (5): 3 reserviert") and has(out, "Ohne Reserve: Bob, Chorf") and has(out, "Nicht im Raid: Gustav"), out)
assert(#STUB.chat == 0 or STUB.chat[#STUB.chat].chan ~= "RAID", "the check only goes to my own chat")
msgs = #STUB.messages
NS.Dispatch("sr check")
assert(#STUB.messages > msgs, "the alias")
STUB.chat = {}
NS.Dispatch("sr posten")
assert(#STUB.chat == 1 and last().chan == "RAID")
later()
STUB.chat = {}
NS.Dispatch("sr post")
assert(#STUB.chat == 1, "the alias")
STUB.popup = nil
NS.Dispatch("sr erinnern")
assert(STUB.popup and STUB.popup.which == "AMISIA_SR_REMIND")
STUB.popup = nil
NS.Dispatch("sr remind")
assert(STUB.popup and STUB.popup.which == "AMISIA_SR_REMIND", "the alias")
STUB.popup = nil
NS.Set("ui.view", "raider")
STUB.chat = {}
NS.Dispatch("sr posten")
assert(#STUB.chat == 0 and has(STUB.messages[#STUB.messages], "Offiziersansicht"), "officers only")
msgs = #STUB.messages
NS.Dispatch("sr pruefen")
assert(#STUB.messages > msgs, "everyone may check")
NS.Reset("ui.view")
NS.Dispatch("sr")
assert(NS.CurrentPage() == "softres", "the page as before")

---------------------------------------------------------------------------
-- the buttons on the page
---------------------------------------------------------------------------
local f = NS.SoftResPageFrame()
NS.Refresh()
assert(f.remind:IsShown() and f.post:IsShown())
assert(f.remind:GetText() == "Erinnern (2)" and f.remind:IsEnabled(), f.remind:GetText())
assert(f.post:GetText() == "Im Raid posten" and f.post:IsEnabled())
STUB.popup = nil
f.remind:Click()
assert(STUB.popup and STUB.popup.which == "AMISIA_SR_REMIND")
STUB.chat = {}
STUB.acceptPopup()
assert(#STUB.chat == 2)
assert(f.remind:GetText() == "Erinnern (0)" and not f.remind:IsEnabled(), "nobody left to remind")
later()
STUB.chat = {}
f.post:Click()
assert(#STUB.chat == 1 and last().chan == "RAID")
STUB.roster = {}
NS.Refresh()
assert(not f.remind:IsEnabled() and not f.post:IsEnabled(), "locked without a raid")
NS.Set("ui.view", "raider")
assert(not f.remind:IsShown() and not f.post:IsShown(), "no buttons for raiders")
NS.Reset("ui.view")
_G.StaticPopup_Show = origShow
