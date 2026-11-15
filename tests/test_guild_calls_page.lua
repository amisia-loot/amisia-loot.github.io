-- The page Aufrufe (tab Gilde, F-211, UI/Pages/Calls.lua): the others' calls as rows (title in this
-- client's language for a dungeon key, the creator, level, roles, sign-ups, time left, note; "voll"), the
-- filters, "Anmelden" with a role and "Abmelden"; the form with its checks (roles 1 to 40, the time, a title or
-- dungeon) and a dungeon from Amisia's data filling title and level; the creator's view (the sign-ups with
-- level, role, item level and status, "Alle einladen" with the reason when inviting is off, "Beenden"); the
-- message's 250 bytes (the note is cut first); the saved call checked on load.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local GC = NS.GuildCalls

STUB.player = "Vuloo"
STUB.level = 40
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 40 },
    { name = "Anna Berg", class = "WARRIOR", rank = 3, level = 42 },
    { name = "Bert Stein", class = "MAGE", rank = 4, level = 38 },
    { name = "Carl Moor", class = "ROGUE", rank = 4, level = 39, online = false },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

local panel = assert(NS.Panel("calls"))
assert(panel.group == "guild" and not panel.officer and not panel.expert, "everyone, tab Gilde")
local members = NS.Panel("members")
assert(panel.order > members.order and panel.order < NS.Panel("calendar").order, "right after Mitglieder")

-- empty
NS.ShowPage("calls")
local f = assert(NS.PageFrame("calls"))
assert(f.listView:IsShown() and f.empty:IsShown() and has(f.empty.title:GetText(), "Keine Aufrufe"), "no calls yet")
assert(f.main:GetText() == "Aufruf erstellen" and f.main:IsEnabled())

-- two calls of the guild: a dungeon (its key gives this client's name) and help, full
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tabcd\t1\tD\tsmcath\tCathedral\t38\t0\t1/1/3\t0/1/1\t0/0/1\tO\tQuest Herod", "GUILD", "Anna Berg")
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tbeef\t3\tH\t-\tHilfe bei Elite\t30\t0\t0/1/1\t0/1/1\t0/1/1\tF\t-", "GUILD", "Bert Stein")
STUB.tick(2)
assert(GC.Count() == 2)
local name = GC.DungeonName("smcath")
assert(name and name ~= "Cathedral", "the dungeon's name in this client's language: " .. tostring(name))
NS.Refresh()
local items = f.list.items
assert(#items == 2 and items[1].low == "bert stein" or items[1].low == "anna berg", "both")
local rowA
for _, r in ipairs(f.list.rows) do if r:IsShown() and r.call and r.call.low == "anna berg" then rowA = r end end
assert(rowA, "Anna's row")
assert(rowA.title:GetText() == name, rowA.title:GetText())
assert(rowA.when:GetText() == "jetzt", rowA.when:GetText())
assert(has(rowA.info:GetText(), "Dungeon") and has(rowA.info:GetText(), "Anna Berg") and has(rowA.info:GetText(), "ab Stufe 38"), rowA.info:GetText())
assert(has(rowA.roles:GetText(), "Tank 0/1 · Heiler 0/1 · Schaden 1/3") and has(rowA.roles:GetText(), "2 angemeldet")
    and has(rowA.roles:GetText(), "noch 1:59 h"), rowA.roles:GetText())
assert(rowA.note:GetText() == "Quest Herod" and rowA.action:GetText() == "Anmelden")
local rowB
for _, r in ipairs(f.list.rows) do if r:IsShown() and r.call and r.call.low == "bert stein" then rowB = r end end
assert(has(rowB.when:GetText(), "voll"), "a full call: " .. rowB.when:GetText())
assert(has(f.data:GetText(), "2 Aufrufe der Gilde"), f.data:GetText())
-- the filters
f.tabs.H:Click()
assert(#f.list.items == 1 and f.list.items[1].low == "bert stein", "help only")
f.tabs.Q:Click()
assert(#f.list.items == 0 and f.empty:IsShown() and has(f.empty.title:GetText(), "Nichts gefunden"))
f.tabs.all:Click()
assert(#f.list.items == 2)

-- "Anmelden": the role menu; then "Abmelden"
local sent = {}
local realSend = NS.CommSend
NS.CommSend = function(kind, fields, chan, target, opts)
    sent[#sent + 1] = { kind = kind, fields = fields, chan = chan, target = target }
    return true
end
rowA.action:Click()
local menu = assert(_G.AmisiaMenu)
assert(menu:IsShown(), "the role menu")
local heal
for _, b in ipairs(menu.buttons) do
    if b:IsShown() and has(b.label and b.label:GetText() or b:GetText(), "Heiler") then heal = b end
end
assert(heal and has(heal.label and heal.label:GetText() or heal:GetText(), "(1 gesucht)"), "the healer still wanted")
heal:Click()
assert(#sent == 1 and sent[1].kind == "EJ" and sent[1].chan == "WHISPER" and sent[1].target == "Anna Berg"
    and table.concat(sent[1].fields, " ") == "abcd H 40", "the sign-up")
NS.Refresh()
assert(rowA.action:GetText() == "Abmelden", rowA.action:GetText())
STUB.tick(6)
rowA.action:Click()
STUB.tick(1)
assert(#sent == 2 and table.concat(sent[2].fields, " ") == "abcd -", "the withdrawal")
NS.Refresh()
assert(rowA.action:GetText() == "Anmelden")
-- under the level: refused
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tcafe\t1\tQ\t-\tElite\t50\t0\t0/1/1\t0/0/0\t0/0/0\tO\t-", "GUILD", "Carl Moor")
STUB.tick(1)
local ok, why = GC.SignUp("Carl Moor", "S")
assert(not ok and has(why, "Erst ab Stufe 50"), tostring(why))

---------------------------------------------------------------------------
-- the form
---------------------------------------------------------------------------
f.main:Click()
assert(GC.PageMode() == "form" and f.formView:IsShown() and not f.listView:IsShown() and f.main:GetText() == "Aufruf senden")
assert(f.back:IsShown() and not f.tabs.all:IsShown(), "Zurück instead of the filters")
assert(f.art:GetValue() == "D" and f.dungeon:IsShown(), "a dungeon by default, the picker with Amisia's data")
local smcath
for _, v in ipairs(f.dungeon.values) do if v.value == "smcath" then smcath = v end end
assert(smcath and smcath.min == 38, "the dungeons with their level")
f.dungeon.onPick("smcath")
assert(f.titleBox:GetText() == GC.Clean(name, GC.TITLE_CHARS) and f.level.current == 38, "the dungeon fills title and level")
-- roles: none in all is too few (one is enough since F-215)
for _, r in ipairs({ "T", "H", "S" }) do
    local st = f.roleSteppers[r]
    while st.current > 0 do st.minus:Click() end
end
f.main:Click()
assert(GC.Own() == nil and has(f.formHint:GetText(), "zusammen 1 bis 40"), f.formHint:GetText())
-- the level and the roles can be typed (F-215): Enter takes the number, held to its range; an empty box
-- and Escape put the old number back
local function typeIn(st, text)
    st.edit:SetText(text)
    st.edit:GetScript("OnEnterPressed")(st.edit)
end
assert(f.level.edit:GetText() == "38" and f.level.edit.maxLetters == 2, "the box shows the level, two digits")
typeIn(f.level, "0")
assert(f.level.current == 1 and f.level.edit:GetText() == "1", "held to 1")
typeIn(f.level, "99")
assert(f.level.current == 99 and f.level.edit:GetText() == "99")
typeIn(f.level, "")
assert(f.level.current == 99 and f.level.edit:GetText() == "99", "empty: the old number")
f.level.edit:GetScript("OnEditFocusGained")(f.level.edit)
f.level.edit:SetText("12")
f.level.edit:GetScript("OnEscapePressed")(f.level.edit)
assert(f.level.current == 99 and f.level.edit:GetText() == "99", "Escape: the old number")
typeIn(f.level, "38")
assert(f.level.current == 38)
f.level.plus:Click()
assert(f.level.edit:GetText() == "39", "the arrows still step")
f.level.minus:Click()
typeIn(f.roleSteppers.S, "1")
assert(f.roleSteppers.S.current == 1)
f.roleSteppers.H.plus:Click()
-- a time: "Uhrzeit" without a time is refused
f.timeMode.onPick("clock")
f.timeBox:SetText("25:00")
f.main:Click()
assert(GC.Own() == nil and has(f.formHint:GetText(), "Uhrzeit fehlt oder ist falsch"), f.formHint:GetText())
local t = date("*t", GetServerTime())
local hh = (t.hour + 2) % 24
f.timeBox:SetText(("%02d:%02d"):format(hh, t.min))
f.noteBox:SetText(string.rep("Notiz ", 30))
f.main:Click()
local own = assert(GC.Own(), "created")
assert(own.art == "D" and own.key == "smcath" and own.min == 38 and own.need.H == 1 and own.need.S == 1 and own.need.T == 0)
assert(own.at > GetServerTime() and own.at - GetServerTime() <= 2 * 3600 + 60 and own.at - GetServerTime() >= 3600, "today in two hours")
assert(GC.Chars(own.note) <= 80, "the note at most 80 characters")
assert(GC.PageMode() == "mine" and f.mineView:IsShown(), "the creator's view after sending")
local ea
for _, m in ipairs(sent) do if m.kind == "EA" then ea = m end end
assert(ea and ea.chan == "GUILD" and ea.fields[4] == "smcath" and ea.fields[3] == "D", "sent to the guild")
assert(#table.concat(ea.fields, "\t") + 4 <= 250, "within 250 bytes")
-- a long title and note: the note is cut first, then the title
local fields = GC.Fields({ id = "abcd", rev = 1, art = "S", title = string.rep("ä", 40), min = 1, at = 0,
    need = { T = 1, H = 1, S = 1 }, note = string.rep("ü", 80), signups = {} })
assert(#("1EA\t" .. table.concat(fields, "\t")) <= 250 and fields[5] == string.rep("ä", 40) and GC.Chars(fields[12]) < 80,
    "the note cut, the title whole")

---------------------------------------------------------------------------
-- the creator's view
---------------------------------------------------------------------------
own.signups = { { n = "Anna Berg", r = "H", l = 42, c = "WARRIOR", t = time() }, { n = "Carl Moor", r = "S", l = 39, t = time() } }
AmisiaDB.guildChars = { v = 1, list = { ["Anna Berg"] = { il = 51, at = time() } } }
NS.GuildCharsLoaded(AmisiaDB)
NS.Refresh()
assert(has(f.summary:GetText(), "ab Stufe 38") and has(f.summary:GetText(), "ab " .. ("%02d:%02d"):format(hh, t.min)), f.summary:GetText())
assert(has(f.summary2:GetText(), "Heiler 0/1 · Schaden 0/1") and has(f.summary2:GetText(), "2 angemeldet"), f.summary2:GetText())
local r1, r2 = f.mineList.rows[1], f.mineList.rows[2]
assert(has(r1.name:GetText(), "Anna Berg") and r1.level:GetText() == "42" and r1.role:GetText() == "Heiler" and r1.il:GetText() == "51", r1.il:GetText())
assert(has(r2.name:GetText(), "Carl Moor") and has(r2.status:GetText(), "offline") and not r2.invite:IsEnabled(), "offline: no invite")
assert(r1.invite:IsEnabled() and f.endLink:IsShown(), "Einladen, Beenden")
assert(f.main:GetText() == "Alle einladen" and f.main:IsEnabled())
STUB.combat = true
NS.Refresh()
assert(f.main:GetText() == "Nicht im Kampf" and not f.main:IsEnabled() and not r1.invite:IsEnabled(), "the reason on the button")
STUB.combat = false
STUB.roster = { { name = "Vuloo" }, { name = "Bert Stein" } }
STUB.party, STUB.leader = true, false
STUB.fire("GROUP_ROSTER_UPDATE")
NS.Refresh()
assert(f.main:GetText() == "Nur als Gruppenleiter" and not f.main:IsEnabled(), "not the leader")
STUB.roster, STUB.party, STUB.leader = {}, nil, true
STUB.fire("GROUP_ROSTER_UPDATE")
local INV = {}
C_PartyInfo.InviteUnit = function(n) INV[#INV + 1] = n end
NS.Refresh()
r1.invite:Click()
assert(INV[1] == "Anna Berg", "one invite")
NS.Refresh()
assert(has(r1.status:GetText(), "eingeladen"), r1.status:GetText())
r1.decline:Click()
assert(#own.signups == 1 and own.signups[1].n == "Carl Moor" and own.declined["anna berg"], "declined")
-- Beenden: asks, then ends
f.endLink:Click()
local ask = assert(_G.AmisiaConfirmFrame)
assert(ask:IsShown() and GC.Own() ~= nil, "asked first")
ask.ok:Click()
NS.Refresh()
assert(GC.Own() == nil and GC.PageMode() == "list", "ended")
local ex
for _, m in ipairs(sent) do if m.kind == "EX" then ex = m end end
assert(ex and ex.chan == "GUILD" and ex.fields[1] == own.id, "EX to the guild")
NS.CommSend = realSend

---------------------------------------------------------------------------
-- the saved call checked on load
---------------------------------------------------------------------------
local good = { v = 1, id = "a1b2", rev = 4, art = "Q", title = "Quest", min = 30, at = 0, created = time() - 600,
    need = { T = 1, H = 1, S = 1 }, note = "x|y", signups = { { n = "Anna Berg", r = "H", l = 42 }, { n = "Bad9", r = "H" }, { n = "Bert", r = "Z" } },
    declined = { ["carl moor"] = true, ["x9"] = true } }
local DB = { guildCall = good }
GC.Loaded(DB)
assert(DB.guildCall and #DB.guildCall.signups == 1 and DB.guildCall.note == nil and DB.guildCall.declined["carl moor"]
    and not DB.guildCall.declined["x9"], "bad parts dropped")
GC.Loaded(DB)
assert(#DB.guildCall.signups == 1, "twice without change")
DB = { guildCall = { v = 1, id = "a1b2", rev = 4, art = "Q", title = "Quest", min = 30, at = 0, created = time() - 7300,
    need = { T = 1, H = 1, S = 1 }, signups = {} } }
GC.Loaded(DB)
assert(DB.guildCall == nil, "older than 2 hours: dropped")
DB = { guildCall = { v = 1, id = "a1b2", rev = 4, art = "Q", title = "Quest", min = 30, at = 0, created = time(), need = { T = 1, H = 0, S = 0 } } }
GC.Loaded(DB)
assert(DB.guildCall ~= nil, "one player wanted: kept (F-215)")
DB = { guildCall = { v = 1, id = "a1b2", rev = 4, art = "Q", title = "Quest", min = 30, at = 0, created = time(), need = { T = 0, H = 0, S = 0 } } }
GC.Loaded(DB)
assert(DB.guildCall == nil, "nobody wanted: dropped")
-- the setting
assert(NS.Get("guildCalls.chat") == true and NS.SettingItem("guildCalls.chat").section.group == "guild")
print("guild calls page ok")
