-- The raid log page: officer and raider view, the timeline (start, late, from the bench, kill, wipe,
-- running attempt, end), the detail area, deleting with a question, "Boss eintragen" with a loot
-- window source, the bench view (enter, remove, "Alle eintragen", tonight before the raid), the
-- Discord view with its parts; the raids page details, the "raid" card and the quick menu; the
-- layout at the main window's size.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local function hm(t) return date("%H:%M", t) end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

RAID_CLASS_COLORS.MAGE = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" }

-- dialogs in this test can be lifted like the client's frames
local shownPopup
local origPopup = StaticPopup_Show
_G.StaticPopup_Show = function(...)
    local p = origPopup(...)
    p.SetFrameStrata = function(self, st) self.strata = st end
    p.Raise = function(self) self.raised = true end
    shownPopup = p
    return p
end

STUB.roster = {
    { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
    { name = "Chorf", class = "WARRIOR" }, { name = "Bob", class = "MAGE", zone = "Shattrath" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.outside.Bob, "recording, Bob waits outside")
local started = s.start
local zahn = STUB.item(30001, "Zahn des Naj'entus", 4)

-- Chorf came late, Kim came from the bench
s.members.Chorf.late = true
STUB.tick(60)
s.bench.Kim = { t = STUB.now - 30, class = "MAGE", by = "Vuloo", note = "Twink" }
s.members.Kim = { class = "MAGE", first = STUB.now, last = STUB.now, bench = true }
local kimCame = STUB.now

-- a kill, a wipe, a running attempt
STUB.tick(60)
STUB.fire("ENCOUNTER_START", 601, "Hochkriegsfürst Naj'entus", 4, 25)
STUB.tick(192)
STUB.fire("ENCOUNTER_END", 601, "Hochkriegsfürst Naj'entus", 4, 25, 1)
STUB.tick(1)
local kill = s.kills[1]
assert(kill and kill.ok and not kill.wait, "the kill is read")
NS.AddAwardTo(s, { name = "Fraktur", item = 30001, kind = "MS", src = "Hochkriegsfürst Naj'entus" })
STUB.tick(100)
STUB.fire("ENCOUNTER_START", 602, "Supremus", 4, 25)
STUB.tick(121)
STUB.fire("ENCOUNTER_END", 602, "Supremus", 4, 25, 0)
local wipe = s.kills[2]
assert(wipe and not wipe.ok)
STUB.tick(60)
s.drops["Creature-0-1-1-1-22947-1"] = { src = "Mutter Shahraz", t = STUB.now - 30, items = {} }
s.drops["Creature-0-1-1-1-1-2"] = { src = "?", t = STUB.now - 20, items = {} }
local shahrazAt = STUB.now - 30
STUB.fire("ENCOUNTER_START", 603, "Teron Blutschatten", 4, 25)
local pullAt = STUB.now

---------------------------------------------------------------------------
-- registration: page for everyone, the quick menu
---------------------------------------------------------------------------
local panel = NS.Panel("raidlog")
assert(panel and panel.label == "Raid-Log" and panel.order == 25 and not panel.officer
    and panel.icon == "Interface\\Icons\\INV_Misc_Note_01", "the page is registered for everyone")
local function menu()
    local out = {}
    for _, e in ipairs(NS.MinimapMenuEntries()) do out[#out + 1] = e[1] end
    return table.concat(out, "|")
end
assert(has(menu(), "Soft-Reserves|Raid-Log"), "after Soft-Reserves: " .. menu())
NS.Set("ui.view", "raider")
assert(has(menu(), "Soft-Reserves|Raid-Log"), "for raiders too: " .. menu())
NS.Reset("ui.view")
for _, e in ipairs(NS.MinimapMenuEntries()) do if e[1] == "Raid-Log" then e[2]() end end
assert(NS.CurrentPage() == "raidlog", "the entry opens the page")

---------------------------------------------------------------------------
-- officer view: head, counts, timeline
---------------------------------------------------------------------------
NS.ShowPage("overview")
NS.Dispatch("log")
assert(NS.CurrentPage() == "raidlog", "/amisia log opens the page")
local f = NS.RaidLogPageFrame()
assert(f and f.log and f.bench and f.discord, "the page frame is reachable, not the error page")
assert(f.views.verlauf.on and not f.views.bench.on and not f.views.discord.on, "view Verlauf")
assert(f.log:IsShown() and not f.bench:IsShown() and not f.discord:IsShown())
assert(f.raid:GetValue() == s.id and f.raid.values[1].value == s.id, "the recording first and chosen")
assert(f.addBoss:IsShown() and f.discordBtn:IsShown() and f.views.discord:IsShown(), "officer parts")
local counts = f.counts:GetText()
assert(has(counts, "1 Boss") and has(counts, "1 Wipe") and has(counts, "4 Raider") and has(counts, "1 zu spät")
    and has(counts, "1 Ersatzbank") and has(counts, hm(s.firstScan)), counts)
assert(has(f.views.bench.label:GetText(), "Ersatzbank (1)"), f.views.bench.label:GetText())

local L = f.log.list
local function rowsShown()
    local out = {}
    for _, r in ipairs(L.rows) do if r:IsShown() then out[#out + 1] = r end end
    return out
end
local function rowWith(text)
    for _, r in ipairs(rowsShown()) do if has(r.event:GetText(), text) then return r end end
    return nil
end
local rows = rowsShown()
assert(#rows == 6, "start, late, from the bench, kill, wipe, running: " .. #rows)
assert(rows[1].event:GetText() == "Aufnahme gestartet" and rows[1].time:GetText() == hm(started), rows[1].event:GetText())
local late = rowWith("Chorf kommt")
assert(late and has(late.result:GetText(), "zu spät"), "a late raider")
local sub = rowWith("Kim kommt von der Ersatzbank")
assert(sub and sub.time:GetText() == hm(kimCame), "a raider from the bench")
local kr = rowWith("Hochkriegsfürst Naj'entus")
assert(kr and has(kr.result:GetText(), "Kill") and kr.dur:GetText() == "3:12" and kr.who:GetText() == tostring(kill.n)
    and kr.src:GetText() == "Kampf", ("%s %s %s %s"):format(kr.result:GetText(), kr.dur:GetText(), kr.who:GetText(), kr.src:GetText()))
assert(has(kr.result:GetText(), "|cff4fbf7a"), "a kill is green")
local wr = rowWith("Supremus")
assert(wr and has(wr.result:GetText(), "Wipe") and has(wr.result:GetText(), "|cffe05a5a") and wr.dur:GetText() == "2:01", wr.result:GetText())
local pr = rowWith("Teron Blutschatten")
assert(pr and has(pr.result:GetText(), "läuft") and pr.time:GetText() == hm(pullAt) and pr.src:GetText() == "Kampf", "the running attempt")
assert(not rowWith("Aufnahme beendet"), "no end while recording")

---------------------------------------------------------------------------
-- the detail area of a kill
---------------------------------------------------------------------------
kr:Click()
assert(kr.sel:IsShown(), "the chosen row is marked")
local title = f.log.title:GetText()
assert(has(title, "Hochkriegsfürst Naj'entus") and has(title, "Kill " .. hm(kill.t)) and has(title, "Kampf 3:12"), title)
local detail = f.log.detail.fs:GetText()
assert(has(detail, ("Dabei (%d):"):format(#kill.who)) and has(detail, "Fraktur") and has(detail, "Chorf"), detail)
assert(has(detail, "|cff0070de" .. "Fraktur") or has(detail, "|cff0070deFraktur"), "class colours: " .. detail)
assert(has(detail, "Nicht dabei:") and has(detail, "Kim|r (kam") == false and has(detail, "Kim"), "Kim was there before the kill: " .. detail)
assert(has(detail, "Ersatzbank:") and has(detail, "Kim"), detail)
assert(has(detail, "Loot:") and has(detail, "Zahn des Naj'entus an Fraktur (MS)"), detail)
assert(f.log.del:IsShown(), "officers delete")

-- a raider who came after the kill is "not there" with the time he came
s.members.Spaet = { class = "WARRIOR", first = kill.t + 600, last = kill.t + 700 }
NS.Refresh()
detail = f.log.detail.fs:GetText()
assert(has(detail, "Nicht dabei:") and has(detail, "Spaet|r (kam " .. hm(kill.t + 600) .. ")"), detail)
s.members.Spaet = nil

-- the wipe: a head count, no names; deleting asks first
wr = rowWith("Supremus")
wr:Click()
assert(has(f.log.title:GetText(), "Wipe") and has(f.log.title:GetText(), "Kampf 2:01"), f.log.title:GetText())
detail = f.log.detail.fs:GetText()
assert(has(detail, "Dabei:|r " .. wipe.n .. " Raider") and not has(detail, "Loot:"), detail)
local count = #s.kills
f.log.del:Click()
assert(STUB.popup and STUB.popup.which == "AMISIA_RAIDLOG_DELETE", "a question first")
assert(StaticPopupDialogs.AMISIA_RAIDLOG_DELETE.text == "Diesen Eintrag aus dem Raid-Log löschen?")
assert(shownPopup.strata == "FULLSCREEN_DIALOG" and shownPopup.raised, "lifted above the main window")
assert(#s.kills == count, "nothing deleted before the answer")
STUB.acceptPopup()
assert(#s.kills == count - 1 and s.kills[1] == kill, "the wipe is gone")
assert(not rowWith("Supremus"), "and out of the list")

-- the running attempt has no delete
pr = rowWith("Teron Blutschatten")
pr:Click()
assert(has(f.log.title:GetText(), "läuft") and not f.log.del:IsShown(), f.log.title:GetText())

---------------------------------------------------------------------------
-- Boss eintragen: a loot window source and its time, or a free name
---------------------------------------------------------------------------
f.addBoss:Click()
local A = f.log.add
assert(A:IsShown() and f.views.verlauf.on, "the line in the detail area")
local found
for _, v in ipairs(A.pick.values) do
    assert(v.value ~= "?", "no unknown source")
    if v.value == "Mutter Shahraz" then found = v end
end
assert(found and found.text == ("Mutter Shahraz (Lootfenster %s)"):format(hm(shahrazAt)), found and found.text)
assert(A.pick.freeText == "Anderer Name")
assert(A.kill.on and not A.wipe.on, "a kill by default")
A.ok:Click()
assert(has(lastMsg(), "Boss"), "nothing chosen: " .. lastMsg())
A.pick:SetValue("Mutter Shahraz"); A.pick.onPick("Mutter Shahraz", false)
count = #s.kills
A.ok:Click()
assert(#s.kills == count + 1, "entered")
local hand
for _, k in ipairs(s.kills) do if k.name == "Mutter Shahraz" then hand = k end end
assert(hand and hand.src == "hand" and hand.ok and hand.t == shahrazAt, "at the time of the loot window")
assert(not A:IsShown(), "the line closes")
local hr = rowWith("Mutter Shahraz")
assert(hr and hr.src:GetText() == "von Hand", "by hand")
f.addBoss:Click()
A.pick:SetValue("Gurtogg"); A.pick.onPick("Gurtogg", true)
A.wipe:Click()
assert(A.wipe.on and not A.kill.on)
A.ok:Click()
local gw = s.kills[#s.kills]
assert(gw.name == "Gurtogg" and gw.ok == false and gw.t == STUB.now, "a wipe by hand, now")
f.addBoss:Click()
A.cancel:Click()
assert(not A:IsShown(), "cancel closes the line")

---------------------------------------------------------------------------
-- the bench view
---------------------------------------------------------------------------
STUB.guild = { { name = "Gildi", class = "ROGUE" } }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
local req = STUB.guildRequests
f.views.bench:Click()
assert(f.bench:IsShown() and not f.log:IsShown() and f.views.bench.on, "view Ersatzbank")
assert(STUB.guildRequests == req + 1, "the guild roster is asked for")
local B = f.bench
assert(B.pick:IsShown() and B.note:IsShown() and B.addBtn:IsShown(), "the input line for officers")
B.pick:Open()
local texts = {}
for _, v in ipairs(B.pick.values) do texts[#texts + 1] = v.text end
assert(has(table.concat(texts, ";"), "Bob (in der Gruppe, draußen)") and has(table.concat(texts, ";"), "Gildi (Gilde)"), table.concat(texts, ";"))
B.pick:Close()
assert(has(B.outside:GetText(), "In der Gruppe, nicht in der Instanz: Bob") and B.all:IsShown(), B.outside:GetText())
assert(has(B.hint:GetText(), "!bench"), B.hint:GetText())
B.pick:SetValue("Bob"); B.pick.onPick("Bob", false)
B.note:SetText("ab 21 Uhr")
B.addBtn:Click()
assert(s.bench.Bob and s.bench.Bob.note == "ab 21 Uhr" and s.bench.Bob.by == "Vuloo", "entered with the note")
assert(B.note:GetText() == "" and B.pick:GetValue() == nil, "the line empties")
assert(has(f.views.bench.label:GetText(), "Ersatzbank (2)"))
local function benchRow(name)
    for _, r in ipairs(B.list.rows) do if r:IsShown() and has(r.name:GetText(), name) then return r end end
    return nil
end
local br = benchRow("Bob")
assert(br and br.since:GetText() == hm(s.bench.Bob.t) and br.how:GetText() == "von Vuloo" and br.note:GetText() == "ab 21 Uhr"
    and br.joined:GetText() == "", "the row of Bob")
local kimRow = benchRow("Kim")
assert(kimRow and kimRow.joined:GetText() == "eingewechselt " .. hm(kimCame) and kimRow.note:GetText() == "Twink", kimRow and kimRow.joined:GetText())
assert(has(kimRow.name:GetText(), "|cff"), "class colour")
assert(not B.all:IsShown() or not has(B.outside:GetText(), "Bob"), "Bob is on the bench now")
br.x:Click()
assert(s.bench.Bob == nil and not benchRow("Bob"), "removed")
assert(has(B.outside:GetText(), "Bob"))
B.all:Click()
assert(s.bench.Bob and s.bench.Bob.by == "Vuloo", "Alle eintragen")
-- a refused name: the reason in the chat
B.pick:SetValue("Fraktur"); B.pick.onPick("Fraktur", true)
B.addBtn:Click()
assert(has(lastMsg(), "Fraktur ist im Raid."), lastMsg())
-- a !bench entry
s.bench.Selbst = { t = STUB.now, class = "", self = true }
NS.Refresh()
assert(benchRow("Selbst").how:GetText() == "selbst, !bench")
s.bench.Selbst = nil
NS.Refresh()

---------------------------------------------------------------------------
-- the Discord view
---------------------------------------------------------------------------
f.discordBtn:Click()
assert(f.views.discord.on and f.discord:IsShown() and not f.bench:IsShown(), "the button opens the view")
local D = f.discord
local parts = NS.RaidSummary(s)
assert(#parts == 1 and D.area.box:GetText() == parts[1], D.area.box:GetText())
assert(not D.chips[1]:IsShown(), "one part: no chips")
assert(has(D.hint:GetText(), "Strg+A, Strg+C, in Discord einfügen.") and has(D.hint:GetText(), NS.TextLength(parts[1]) .. " Zeichen."), D.hint:GetText())
-- typing puts the text back
D.area.box:SetText("kaputt")
D.area.box.scripts.OnTextChanged(D.area.box, true)
assert(D.area.box:GetText() == parts[1], "read-only")
-- many hand-outs: parts with chips (with the box left: a focused box keeps its text)
D.area.box:ClearFocus()
for i = 1, 80 do
    STUB.item(31000 + i, ("Langer Gegenstand der Prüfung Nummer %d"):format(i), 4)
    NS.AddAwardTo(s, { name = "Fraktur", item = 31000 + i, kind = "MS", src = "Hochkriegsfürst Naj'entus" })
end
parts = NS.RaidSummary(s)
assert(#parts >= 2, #parts)
assert(D.area.box:GetText() == parts[1], "DATA_CHANGED builds the text again")
assert(D.chips[1]:IsShown() and D.chips[2]:IsShown() and D.chips[1].label:GetText() == "Teil 1" and D.chips[1].on, "chips per part")
assert(not D.chips[#parts + 1] or not D.chips[#parts + 1]:IsShown())
D.chips[2]:Click()
assert(D.area.box:GetText() == parts[2] and D.chips[2].on and not D.chips[1].on, "part 2")
assert(has(D.hint:GetText(), NS.TextLength(parts[2]) .. " Zeichen."), D.hint:GetText())
NS.Refresh()
assert(D.area.box:GetText() == parts[2], "the chosen part stays")
-- /amisia discord opens the view of the newest raid
f.views.verlauf:Click()
NS.Dispatch("discord")
assert(f.views.discord.on, "/amisia discord")

---------------------------------------------------------------------------
-- raider view: the timeline and the bench list only
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
NS.Refresh()
assert(NS.CurrentPage() == "raidlog", "the page stays for raiders")
assert(f.views.verlauf.on and f.log:IsShown() and not f.discord:IsShown(), "no Discord for raiders")
assert(not f.views.discord:IsShown() and not f.addBoss:IsShown() and not f.discordBtn:IsShown(), "no officer parts")
NS.ShowRaidLog("discord")
assert(f.views.verlauf.on, "Discord falls back to Verlauf")
rowWith("Hochkriegsfürst Naj'entus"):Click()
assert(not f.log.del:IsShown(), "raiders delete nothing")
f.views.bench:Click()
assert(f.bench:IsShown() and not B.pick:IsShown() and not B.addBtn:IsShown() and not B.all:IsShown() and not B.hint:IsShown(),
    "the list only")
assert(benchRow("Kim") and not benchRow("Kim").x:IsShown(), "no remove for raiders")
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- the raids page and the card
---------------------------------------------------------------------------
local dt = NS.RaidDetailText(s)
assert(has(dt, "Bosse:|r Hochkriegsfürst Naj'entus " .. hm(kill.t)) and has(dt, "Mutter Shahraz") and has(dt, "Gurtogg (1 Wipe, kein Kill)"), dt)
assert(has(dt, "Ersatzbank:|r Bob, Kim"), dt)
local raiderAt, bossAt, benchAt = dt:find("Raider (", 1, true), dt:find("Bosse:", 1, true), dt:find("Ersatzbank:", 1, true)
local lootAt = dt:find("Loot:", 1, true)
assert(raiderAt < bossAt and bossAt < benchAt and benchAt < lootAt, "after the raiders")
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564, start = 1700000000,
              last = 1700003600, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
table.insert(AmisiaDB.sessions, 1, old)
dt = NS.RaidDetailText(old)
assert(has(dt, "Bosse:|r keine") and has(dt, "Ersatzbank:|r keine"), dt)
local card
for _, c in ipairs(NS.cards) do if c.key == "raid" then card = c end end
local c = NS.W.Card(UIParent, 296, 112)
card.fill(c)
assert(has(c.line2:GetText(), "Raider · 2 Bosse"), c.line2:GetText())

-- an old raid: the end of the recording, a kill by hand at its last time
f.views.verlauf:Click()
f.raid.onPick(old.id)
assert(f.raid:GetValue() == old.id and rowWith("Aufnahme beendet"), "the end of an old raid")
f.addBoss:Click()
A.pick:SetValue("Illidan"); A.pick.onPick("Illidan", true)
A.ok:Click()
assert(old.kills[1] and old.kills[1].t == old.last and old.last == 1700003600, "at the raid's end, s.last unchanged")

---------------------------------------------------------------------------
-- layout at the main window's size (content 602 x 478)
---------------------------------------------------------------------------
f.raid.onPick(s.id)
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
local span, vspan, row, column, fits = Lay.span, Lay.vspan, Lay.row, Lay.column, Lay.fits

f.views.verlauf:Click()
row("head", f.raid, f.addBoss, f.discordBtn)
row("views", f.views.verlauf, f.views.bench, f.views.discord)
local LH = f.log.head
row("columns", LH.time, LH.event, LH.result, LH.dur, LH.who, LH.src)
local r1 = L.rows[1]
-- the list ends 12 px before the edge; its thin bar sits in that gap, inside the page
row("timeline row", r1.time, r1.event, r1.result, r1.dur, r1.who, r1.src)
row("timeline list", L, L.bar)
local _, lr = span(L)
assert(lr == 590, "the timeline is 590 wide: " .. lr)
Lay.inside("timeline bar", L.bar)
for _, r in ipairs(rowsShown()) do fits(r.event); fits(r.src) end
column("verlauf", f.raid, f.counts, f.views.verlauf, LH.time, L, f.log.title, f.log.detail)
row("detail head", f.log.title, f.log.del)
row("detail text", f.log.detail, f.log.detail.bar)
Lay.inside("detail bar", f.log.detail.bar)
assert(r1.sel.atlas == "Professions_Recipe_Active", "the chosen row glows like the recipe list's")
f.addBoss:Click()
row("add line", A.pick, A.kill, A.wipe, A.ok, A.cancel)
column("add line", L, A, f.log.detail)
A.cancel:Click()

f.views.bench:Click()
row("bench input", B.pick, B.note, B.addBtn)
row("bench columns", B.head.name, B.head.since, B.head.how, B.head.note, B.head.joined)
local b1 = B.list.rows[1]
row("bench row", b1.name, b1.since, b1.how, b1.note, b1.joined, b1.x)
row("bench list", B.list, B.list.bar)
Lay.inside("bench bar", B.list.bar)
fits(kimRow.joined); fits(kimRow.how)
row("outside", B.outside, B.all)
column("bench", f.views.bench, B.label, B.pick, B.head.name, B.list, B.outside, B.hint)

f.views.discord:Click()
row("parts", D.chips[1], D.chips[2], D.chips[3], D.chips[4], D.chips[5], D.chips[6])
row("discord box", D.area)
-- the box's bar lies inside the box
local al, ar = span(D.area)
local bl, br = span(D.area.bar)
assert(bl >= al and br <= ar, ("the box's bar inside the box: %d..%d in %d..%d"):format(bl, br, al, ar))
Lay.inside("discord box", D.area)
column("discord", f.views.discord, D.chips[1], D.area, D.hint)
local _, at = vspan(D.area)
local top = vspan(D.area)
assert(top - at == 340, "the box is 340 high: " .. (top - at))

---------------------------------------------------------------------------
-- tonight before the raid: the bench goes to benchNext
---------------------------------------------------------------------------
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil)
NS.Dispatch("ersatz")
assert(NS.CurrentPage() == "raidlog" and f.views.bench.on, "/amisia ersatz opens the bench view")
assert(f.raid:GetValue() == "next" and has(f.raid.values[1].text, "Heute, vor dem Raid"), tostring(f.raid:GetValue()))
assert(B.label:GetText() == "Für heute, vor dem Raid:", tostring(B.label:GetText()))
B.pick:SetValue("Gastfreund"); B.pick.onPick("Gastfreund", true)
B.addBtn:Click()
assert(AmisiaDB.benchNext and AmisiaDB.benchNext.list.Gastfreund, "into benchNext")
assert(benchRow("Gastfreund"), "listed")
assert(not B.all:IsShown(), "no group outside without a recording")
assert(has(f.counts:GetText(), "Heute, vor dem Raid"), f.counts:GetText())
f.views.verlauf:Click()
assert(f.raid:GetValue() == s.id and #rowsShown() > 0, "Verlauf shows the newest raid")
f.raid.onPick("next")
assert(f.raid:GetValue() == "next" and #rowsShown() == 0, "no timeline before the raid")

---------------------------------------------------------------------------
-- texts stay within Latin-1
---------------------------------------------------------------------------
for _, file in ipairs({ "UI/Pages/RaidLog.lua", "UI/Pages/Raids.lua", "Core/Minimap.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for ch in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. ch) end
end
