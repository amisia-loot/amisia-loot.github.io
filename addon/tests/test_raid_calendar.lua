-- Part I: the raid calendar window (Raid/RaidCalendar.lua, UI/RaidCalendar.lua, D-43). Everyone in
-- the guild sees it (here a raider, Vulo Pala): the dates of the next 14 days on the left, the chosen
-- date's participants on the right in the groups "Angemeldet / Bestätigt", "Vorläufig", "Ersatz",
-- "Abgemeldet", "Ohne Antwort" with their counts, each row with role ("?" when guessed), name, level,
-- the source marks K and A and the note (whole in the tooltip), the role summary over them. The data
-- come from the calendar's invite list and the sign-ups from Amisia this client keeps (received AN,
-- the account's own characters); the valid status follows the officer's lineup rules (one function,
-- ns.LineupResolve). The kept sign-ups are pruned on load. An officer also gets "Zur Aufstellung".
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local RC = NS.RaidCal
RAID_CLASS_COLORS.DRUID = RAID_CLASS_COLORS.DRUID or { r = 1, g = 0.49, b = 0.04, colorStr = "ffff7d0a" }

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST", level = 60 },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR", level = 60 },
    { name = "Cara Wind", rank = 3, class = "MAGE", level = 60 },
    { name = "Dora Stein", rank = 3, class = "ROGUE", level = 60 },
    { name = "Eda Glut", rank = 3, class = "WARLOCK", level = 60 },
    { name = "Finn Laub", rank = 3, class = "DRUID", level = 55 },
}
local cal = STUB.calendar({ events = {
    { title = "Molten Core", days = 1, eventType = 0, id = 12, inviteStatus = 7 },
    { title = "Onyxia", days = 3, eventType = 0, id = 14, inviteStatus = 7 },
}, invites = { [12] = {
    { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 3 },
    { name = "Anna Bergmann", classFilename = "PRIEST", level = 60, inviteStatus = 6 },
    { name = "Bob Eisherz", classFilename = "WARRIOR", level = 60, inviteStatus = 8 },
    { name = "Cara Wind", classFilename = "MAGE", level = 60, inviteStatus = 2 },
    { name = "Dora Stein", classFilename = "ROGUE", level = 60, inviteStatus = 7 },
    { name = "Eda Glut", classFilename = "WARLOCK", level = 60, inviteStatus = 5 },
} } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local terms = NS.SignupTerms()
local N1, N2 = terms[1].night, terms[2].night
local now = math.floor(time())

-- the sign-ups this client received (a raider keeps them since part I)
local keep = NS._signup.keepSeen
assert(keep(N1, "Anna Bergmann", { s = "X", r = "H", t = now + 5, w = "Kind krank, sorry" }), "Anna signs off in Amisia")
assert(keep(N1, "Finn Laub", { s = "A", r = "T", c = "DRUID", t = now, w = "komme 20:15" }), "Finn only in Amisia")
assert(not keep(N1, "Finn Laub", { s = "X", r = "T", t = now - 10 }), "an older click (the sender's clock) does not count")
assert(not keep("2020-01-01", "Finn Laub", { s = "A", t = now }), "a past night is not kept")
-- the own sign-up (the account's characters, no message needed)
assert(NS.SignupSet(terms[1], "V", "H", "vielleicht später"))

-- /amisia kalender opens the window for a raider, at the next date
NS.Dispatch("kalender")
STUB.tick(1)
local F = NS._raidCalUI.frame()
assert(F and F:IsShown(), "the window for a raider")
assert(#F.dates.items == 2 and F.dates.items[1].title == "Molten Core", "the dates on the left")
assert(has(F.dates.rows[1].own:GetText(), "vorläufig (H)"), "the own state beside the date: " .. F.dates.rows[1].own:GetText())
assert(has(F.head:GetText(), "Molten Core"), F.head:GetText())
assert(not F.lineup:IsShown(), "no lineup button for a raider")
assert(has(F.status:GetText(), "Kalender gelesen"), F.status:GetText())
assert(cal.opens == 1 and cal.closes >= 1 and cal.writes == 0, "read once, closed, nothing written")

local function rows()
    local out = {}
    for _, it in ipairs(F.list.items) do out[#out + 1] = it end
    return out
end
local function heads()
    local out = {}
    for _, it in ipairs(rows()) do if it.head then out[#out + 1] = ("%s (%d)"):format(it.head, it.count) end end
    return table.concat(out, " | ")
end
assert(heads() == "Angemeldet / Bestätigt (2) | Vorläufig (2) | Ersatz (1) | Abgemeldet (2) | Ohne Antwort (1)", heads())
local function entry(name)
    for _, it in ipairs(rows()) do if it.e and it.e.n == name then return it.e end end
end
-- precedence: Anna's Amisia click is newer than the calendar status seen first
assert(entry("Anna Bergmann").st == "X" and entry("Anna Bergmann").f == "KA", "signed off in Amisia beats the calendar")
assert(entry("Vulo Hunt").st == "B" and entry("Vulo Hunt").f == "K", "confirmed in the calendar")
assert(entry("Finn Laub").st == "A" and entry("Finn Laub").f == "A" and entry("Finn Laub").lvl == 55, "Amisia only; level from the roster")
assert(entry("Vulo Pala").st == "V" and entry("Vulo Pala").r == "H" and entry("Vulo Pala").w == "vielleicht später", "the own sign-up")
assert(entry("Eda Glut").st == "E" and entry("Dora Stein").st == "O" and entry("Cara Wind").st == "X")
-- roles: from Amisia, else guessed from the class ("?")
assert(entry("Finn Laub").r == "T" and not entry("Finn Laub").q)
assert(entry("Vulo Hunt").r == "R" and entry("Vulo Hunt").q, "a hunter: ranged, guessed")
-- the summary counts those signed up or confirmed: Hunt (R?) and Finn (T)
assert(F.sum:GetText() == "Tanks 1 · Heiler 0 · Nahkampf 0 · Fernkampf 1", F.sum:GetText())

-- the rows on screen: role, name in class colour, level, marks, note; the note whole in the tooltip
local function rowOf(name)
    for _, r in ipairs(F.list.rows) do
        if r:IsShown() and r.item and r.item.e and r.item.e.n == name then return r end
    end
end
local finn = rowOf("Finn Laub")
assert(has(finn.cells.r:GetText(), "T") and not has(finn.cells.r:GetText(), "?"))
assert(has(finn.cells.name:GetText(), "Finn Laub") and has(finn.cells.name:GetText(), "|c"), "class colour")
assert(finn.cells.level:GetText() == "55" and has(finn.cells.src:GetText(), "A") and not has(finn.cells.src:GetText(), "K"))
assert(has(finn.cells.note:GetText(), "komme 20:15"))
assert(has(rowOf("Vulo Hunt").cells.r:GetText(), "F?"), "guessed: grey with ?")
local anna = rowOf("Anna Bergmann")
assert(has(anna.cells.src:GetText(), "K") and has(anna.cells.src:GetText(), "A"))
local tip = {}
GameTooltip.AddLine = function(_, text) tip[#tip + 1] = text end
anna:GetScript("OnEnter")(anna)
local all = table.concat(tip, "\n")
assert(has(all, "Notiz: Kind krank, sorry") and has(all, "Quellen: Kalender, Amisia") and has(all, "abgemeldet"), all)
-- a head row shows only its text
for _, r in ipairs(F.list.rows) do
    if r:IsShown() and r.item and r.item.head then assert(r.head:IsShown() and r.cells.name:GetText() == "") end
end

-- the calendar changes (Bob signs up there after his tentative): read again within 5 s, the change
-- is newer than his first-seen status
cal.invites[12][3].inviteStatus = 6
STUB.tick(6)
STUB.fire("CALENDAR_UPDATE_INVITE_LIST")
STUB.tick(6)
assert(entry("Bob Eisherz").st == "A", "the re-read: " .. tostring(entry("Bob Eisherz").st))
assert(cal.writes == 0)

-- the other date: chosen with a click; no calendar invites there yet
F.dates.rows[2]:Click()
assert(has(F.head:GetText(), "Onyxia"))
STUB.tick(1)
assert(F.empty:IsShown() and has(F.empty:GetText(), "Noch niemand angemeldet."), F.empty:GetText())
F.dates.rows[1]:Click()

-- the client's calendar window shows another event: nothing opened, the reason in the status line
_G.CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
local opens = cal.opens
STUB.tick(31)
assert(cal.opens == opens, "never while the calendar window is shown")
assert(has(F.status:GetText(), "Kalenderfenster des Spiels schließen"), F.status:GetText())
CalendarFrame:Hide()
-- in combat: not read
STUB.combat = true
STUB.tick(31)
assert(cal.opens == opens and has(F.status:GetText(), "Im Kampf"), F.status:GetText())
STUB.combat = false
STUB.tick(31)
assert(cal.opens == opens + 1, "after the fight the poll reads again")

-- "Anmelden ..." / "Ändern ..." opens the sign-up window at the chosen date
assert(F.signup:GetText() == "Ändern ...", F.signup:GetText())
F.signup:Click()
local S = NS._signupUI.frame()
assert(S:IsShown() and S.pick:GetValue() == N1)
-- the sign-up window's "Kalender" and the card's open this window too
F:Hide()
S.calOpen:Click()
assert(F:IsShown())
F:Hide()
NS.ShowPage("overview")
for _, c in ipairs(NS.OverviewPageFrame().cards) do
    if c:IsShown() and c.title:GetText() == NS.L["Raid-Anmeldung"] then
        assert(c.button2:IsShown() and c.button2:GetText() == "Kalender")
        c.button2:Click()
    end
end
assert(F:IsShown(), "the card's Kalender")
-- Escape closes it; the place is kept
local escape = false
for _, name in ipairs(UISpecialFrames) do if name == "AmisiaRaidCalendarFrame" then escape = true end end
assert(escape, "Escape closes it")
F:GetScript("OnDragStop")(F)
assert(AmisiaDB.settings.calendarWindow and AmisiaDB.settings.calendarWindow.point, "the place is saved")

-- the same rules as the officer's lineup: Vulo Hunt (same account) reads the same data
STUB.player, STUB.class, STUB.officer = "Vulo Hunt", "HUNTER", true
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.Set("ui.view", "officer")
assert(NS.LineupAllowed())
local ev = NS.Cal.Events()[1]
NS.LineupReadCalendar(ev, function() end)
STUB.tick(1)
for name, rec in pairs(NS.SignupSeen(N1)) do NS.LineupSignup(N1, name, rec) end
NS.SignupTakeOwn()
F:Hide()
NS.ShowRaidCalendar(N1)
STUB.tick(1)
local n = NS.LineupNight(N1)
for _, x in ipairs(n.list) do
    local w = entry(x.n)
    assert(w and w.st == x.st, x.n .. ": the window " .. tostring(w and w.st) .. ", the lineup " .. tostring(x.st))
end
-- the officer's "Zur Aufstellung"
assert(F.lineup:IsShown())
F.lineup:Click()
assert(NS.CurrentPage() == "lineup", "the lineup page")

-- the kept sign-ups are pruned on load: past nights, bad names and fields, 80 per night
local seen = { ["2020-01-01"] = { ["Alt Eins"] = { s = "A", t = 5 } }, [N1] = { ["Bad|Name"] = { s = "A", t = 5 }, ["Gut Name"] = { s = "Q", t = 5 } } }
seen[N2] = {}
for i = 1, 90 do seen[N2]["Name " .. string.char(64 + (i % 26) + 1) .. string.rep("a", math.floor(i / 26) + 1)] = { s = "A", t = 100 + i } end
local root = { signup = { v = 1, chars = {}, seen = seen } }
NS.SignupLoaded(root)
assert(root.signup.seen["2020-01-01"] == nil and root.signup.seen[N1] == nil, "past nights and bad entries go")
local count = 0
for _ in pairs(root.signup.seen[N2]) do count = count + 1 end
assert(count == 80, "80 per night: " .. count)
NS.SignupLoaded(AmisiaDB)
assert(cal.writes == 0, "the window never writes into the calendar")
print("raid calendar ok")
