-- The calendar page (tab "Kalender", UI/Pages/Calendar.lua; D-45): the month sheet in the client
-- calendar's look. The week starts as the client's calendar does (German client: Monday), 42 days,
-- the days of other months darker, today framed in gold; a day with a guild event shows its time and
-- title and a dot in the own state's colour, a past day with a recorded raid its zone. Months go
-- back to the first recorded raid and forward to the last day read. A click on a day shows its dates
-- and the chosen one's participants (the raid calendar window's list), "Anmelden ..."/"Ändern ...",
-- for officers "Zur Aufstellung". The read follows ns.Cal's rules (not while the client's calendar
-- window is shown).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
RAID_CLASS_COLORS.DRUID = RAID_CLASS_COLORS.DRUID or { r = 1, g = 0.49, b = 0.04, colorStr = "ffff7d0a" }

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST", level = 60 },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR", level = 60 },
}
local cal = STUB.calendar({ events = {
    { title = "Molten Core", days = 1, eventType = 0, id = 12, inviteStatus = 7 },
    { title = "Gildentreffen mit langem Namen", days = 1, hour = 18, eventType = 3, id = 13, inviteStatus = 7 },
    { title = "Onyxia", days = 3, eventType = 0, id = 14, inviteStatus = 6 },
}, invites = { [12] = {
    { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 3 },
    { name = "Anna Bergmann", classFilename = "PRIEST", level = 60, inviteStatus = 6 },
    { name = "Bob Eisherz", classFilename = "WARRIOR", level = 60, inviteStatus = 8 },
} } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
-- a raid recorded 40 days ago: the months go back to it
local past = time() - 40 * 86400
table.insert(AmisiaDB.sessions, { id = "old", date = NS.NightOf(past), zone = "Molten Core", start = past, members = { Bob = { class = "WARRIOR" } }, awards = {} })

-- the sheet of a month: 42 days from the first weekday of the client's calendar (Monday on deDE)
local y, m = 2026, 10
local days = NS.CalendarSheet(y, m)
assert(#days == 42)
-- 2026-10-01 is a Thursday: three days of September before it (Mo 28., Di 29., Mi 30.)
assert(os.date("*t", os.time({ year = 2026, month = 10, day = 1, hour = 12 })).wday == 5, "the 1st is a Thursday")
assert(days[1].d == 28 and days[1].m == 9 and not days[1].inMonth, "starts on Monday the 28th of September")
assert(days[4].d == 1 and days[4].inMonth and days[4].key == "2026-10-01")
assert(days[34].d == 31 and days[34].inMonth and days[35].d == 1 and days[35].m == 11 and not days[35].inMonth)
-- an English client starts on Sunday: 27 September first
STUB.locale = "enUS"
days = NS.CalendarSheet(y, m)
assert(days[1].d == 27 and days[5].d == 1, "Sunday first on an English client")
STUB.locale = "deDE"

-- the page for a raider: the month of today, the next date chosen
NS.SignupLoadTerms(); STUB.tick(1)
local terms = NS.SignupTerms()
assert(#terms == 3)
local N1 = terms[1].night
NS.ShowPage("calendar")
STUB.tick(1)
local P = NS.CalendarPageFrame()
local F = AmisiaFrame
assert(P and P:IsShown() and F.tabs.calendar.selected, "the page in its tab")
local now = os.date("*t", time())
local MONTHS = { "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember" }
assert(P.title:GetText() == MONTHS[now.month] .. " " .. now.year, P.title:GetText())
assert(P.heads[1]:GetText() == "Mo" and P.heads[7]:GetText() == "So", "the weekdays from Monday: " .. P.heads[1]:GetText())
-- the cells: today framed, other months darker, the date in its day
local cellOf = {}
for _, c in ipairs(P.cells) do cellOf[c.info.key] = c end
local today = cellOf[os.date("%Y-%m-%d", time())]
assert(today and today.today[1]:IsShown(), "today framed in gold")
local other
for _, c in ipairs(P.cells) do
    if c ~= today then assert(not c.today[1]:IsShown(), "only today is framed") end
    if not other and c.bg.vertexColor[1] < 1 then other = c end
end
assert(other and other.bg.vertexColor[1] == NS.Theme.CALPAGE.DARK, "a day of another month is darker")
local c1 = cellOf[N1]
assert(c1, "the date's day is on the sheet")
assert(c1.lines[1]:GetText():find("20:00", 1, true), "the time: " .. tostring(c1.lines[1]:GetText()))
-- the raid first (the 18:00 meeting is earlier, but the raid is the date of the day)
assert(c1.lines[2]:GetText() == "Molten Core" or c1.lines[2]:GetText():find("%.%.%.$"), "the raid's title, cut to the cell: " .. c1.lines[2]:GetText())
assert(c1.lines[2]:GetStringWidth() <= NS.Theme.CALPAGE.CELL_W - 2 * NS.Theme.CALPAGE.PAD, "the title fits the cell")
assert(c1.lines[3]:GetText():find("+1", 1, true), "one more date that day")
assert(c1.dot:IsShown(), "the own state's dot")
assert(c1.sel:IsShown(), "the next date's day is chosen")
-- the right inset: the day's dates, the chosen raid's participants (read from the calendar)
assert(P.terms[1]:IsShown() and P.terms[2]:IsShown())
assert(has(P.terms[1].text:GetText(), "18:00") and has(P.terms[2].text:GetText(), "Molten Core"))
assert(P.terms[2].sel:IsShown() and not P.terms[1].sel:IsShown(), "the raid of the day is chosen")
assert(cal.opens >= 1 and cal.closes == cal.opens, "read like the window: opened, always closed")
local names = {}
for _, it in ipairs(P.list.items) do if it.e then names[#names + 1] = it.e.n end end
-- by group (signed up / confirmed, tentative), then role (Anna's guessed healer before the hunter)
assert(table.concat(names, ",") == "Anna Bergmann,Vulo Hunt,Bob Eisherz", table.concat(names, ","))
assert(P.list.items[1].head == "Angemeldet / Bestätigt", "the groups as section bars")
assert(has(P.totals:GetText(), "angemeldet") and has(P.totals:GetText(), "2"), P.totals:GetText())
assert(P.signup:IsShown() and P.signup:GetText() == "Anmelden ..." and not P.lineup:IsShown(), "a raider: no lineup button")
assert(has(P.status:GetText(), "Kalender gelesen"), P.status:GetText())
-- the participant rows are the window's (role icon, class icon, name, sources)
local row = P.list.rows[2]
assert(row.roleIcon and row.classIcon and row.cells.name and row.cells.src and not row.cells.note)
-- the other date of the day: a click on it reads its list (the participants are kept per night,
-- as in the window: the date read last counts)
P.terms[1]:Click()
STUB.tick(1)
assert(P.terms[1].sel:IsShown() and #P.list.items == 0 and P.empty:IsShown() and P.empty:GetText() == "Noch niemand angemeldet.")
-- "Anmelden ..." opens the sign-up window at that night
P.terms[2]:Click()
STUB.tick(1)
P.signup:Click()
assert(AmisiaSignupFrame and AmisiaSignupFrame:IsShown(), "the sign-up window")
AmisiaSignupFrame:Hide()
-- a sign-up turns the button and the dot
assert(NS.SignupSet(terms[1], "A", "H", "komme"))
NS.Refresh()
assert(P.signup:GetText() == "Ändern ...")
local col = c1.dot.vertexColor
assert(col[2] > col[1], "signed up: a green dot")

-- a click on an empty day: no date, no buttons
local empty
for _, c in ipairs(P.cells) do
    if c.info.key ~= N1 and not c.info.terms and not c.info.raids and c.info.key > N1 then empty = c break end
end
empty:Click()
assert(empty.sel:IsShown() and not c1.sel:IsShown())
assert(P.empty:GetText() == "Kein Termin an diesem Tag." and not P.signup:IsShown() and not P.terms[1]:IsShown(), P.empty:GetText())

-- months: forward to the last day read, back to the first recorded raid
local lastRead = os.date("*t", time() + NS.Cal.DAYS * 86400)
-- (the raid's night: a raid after midnight belongs to the evening before)
local fy, fm = NS.NightOf(past):match("^(%d+)%-(%d+)")
local first = { year = tonumber(fy), month = tonumber(fm) }
local function idx(t) return t.year * 12 + t.month end
local steps = 0
while P.next:IsEnabled() and steps < 5 do P.next:Click(); steps = steps + 1 end
assert(steps == idx(lastRead) - idx(now), "forward to the month of the last day read: " .. steps)
assert(P.next.arrow.atlas == "common-dropdown-a-button-disabled-shadowless", "the arrow shows it cannot go on")
steps = 0
while P.prev:IsEnabled() and steps < 5 do P.prev:Click(); steps = steps + 1 end
assert(P.title:GetText() == MONTHS[first.month] .. " " .. first.year, "back to the first raid's month: " .. P.title:GetText())
-- the recorded raid shows its zone; a click opens its Raid-Log from the day's inset
local rc
for _, c in ipairs(P.cells) do if c.info.key == NS.NightOf(past) then rc = c end end
assert(rc and rc.lines[1]:GetText():find("^Molt") and not rc.dot:IsShown(), "the zone of the recorded raid (cut to the cell): " .. tostring(rc and rc.lines[1]:GetText()))
rc:Click()
assert(P.terms[1]:IsShown() and has(P.terms[1].text:GetText(), "Aufgezeichnet: Molten Core"))
P.terms[1]:Click()
assert(NS.CurrentPage() == "raidlog", "the recorded raid's Raid-Log: " .. NS.CurrentPage())
assert(F.tabs.raid.selected)
-- "Heute" goes back to today's month
NS.ShowTab("calendar")
P.today:Click()
assert(P.title:GetText() == MONTHS[now.month] .. " " .. now.year)

-- the client's calendar window open: the page does not read (the line says why)
NS.RaidCal._reset()
local opens = cal.opens
CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
NS.ShowCalendar(N1)
STUB.tick(6)
assert(cal.opens == opens, "never opened while the calendar window is shown")
assert(has(P.status:GetText(), "Kalenderfenster"), P.status:GetText())
CalendarFrame:Hide()

-- an officer gets "Zur Aufstellung"
STUB.officer = true
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true }, [3] = { [22] = true } }
NS.Set("ui.view", "officer")
NS.ShowCalendar(N1)
assert(NS.LineupAllowed(), "an officer with the officer rank")
do
    assert(P.lineup:IsShown(), "the officer's lineup button")
    P.lineup:Click()
    assert(NS.CurrentPage() == "lineup", NS.CurrentPage())
end
print("calendar page ok")
