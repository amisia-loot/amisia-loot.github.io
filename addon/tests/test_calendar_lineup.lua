-- Part G of the raid lineup (Raid/Calendar.lua, Raid/Lineup.lua, the page "Aufstellung"): the
-- guild events of the game calendar (every guild event, the raid type chosen first, 14 days), the
-- invite list read into the night of the event (after CALENDAR_OPEN_EVENT, the event closed again
-- every time), the statuses, names with the surname, nothing opened while the calendar window shows
-- another event, nothing read in combat, a client that does not answer; the merge with a pasted list
-- and the sign-ups from Amisia (one row per name, the newest statement, Amisia within 2 minutes of
-- the calendar, the officer's hand stays, a pasted list is older); the live re-read while the page is
-- open, an event that is gone, a removed name. Amisia never calls a calendar write function.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end

STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Vulo Hunt", rank = 3, class = "HUNTER" },
    { name = "Vulo Pala", rank = 3, class = "PALADIN" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
local Cal = NS.Cal

-- no calendar: the button is grey, the line says why
_G.C_Calendar = nil
NS.ShowLineup("match")
local f = NS.LineupPageFrame()
assert(not f.calBtn:IsEnabled() and has(f.calLine:GetText(), "Kalender nicht verfügbar."), tostring(f.calLine:GetText()))

-- the calendar: a meeting tomorrow, a raid the day after, an announcement, a player's event, one
-- too far ahead
local cal = STUB.calendar({ loaded = false, events = {
    { title = "Gildentreffen", days = 1, eventType = 3, id = 11 },
    { title = "Molten Core", days = 2, eventType = 0, id = 12, inviteStatus = 3 },
    { title = "Ankündigung", days = 1, calendarType = "GUILD_ANNOUNCEMENT", id = 13 },
    { title = "Privat", days = 1, calendarType = "PLAYER", id = 14 },
    { title = "Weit weg", days = 20, id = 15 },
}, invites = {
    [12] = {
        { name = "Vuloo", classFilename = "PRIEST", level = 60, inviteStatus = 3 },
        { name = "Vulo Pala", classFilename = "PALADIN", level = 60, inviteStatus = 6 },
        { name = "Anna Bergmann", classFilename = "PRIEST", level = 60, inviteStatus = 8, notes = "|cffff0000rot|r" },
        { name = "Bob Eisherz", classFilename = "WARRIOR", level = 60, inviteStatus = 2 },
        { name = "Kim Sturmwind", classFilename = "ROGUE", level = 60, inviteStatus = 5 },
        { name = "Fremder Gast", classFilename = "MAGE", level = 60, inviteStatus = 0 },
        { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 7 },
    },
    [11] = { { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 6 } },
} })
NS.Refresh()
assert(f.calBtn:IsEnabled(), "the button with a calendar")
f.calBtn:Click()
assert(f.empty:IsShown() and has(f.empty.title:GetText(), "Kalender wird gelesen"), "reading")
STUB.tick(1)
assert(f.cal:IsShown() and not f.empty:IsShown(), "the events")
local rows = {}
for _, r in ipairs(f.calRows.rows) do if r:IsShown() then rows[#rows + 1] = r end end
assert(#rows == 2, "only the guild events of the next 14 days: " .. #rows)
assert(has(rows[1].title:GetText(), "Gildentreffen") and has(rows[2].title:GetText(), "Molten Core"), "by time")
assert(has(rows[1].kind:GetText(), "Treffen") and has(rows[2].kind:GetText(), "Schlachtzug"))
assert(has(rows[2].own:GetText(), "bestätigt"), "the own status")
assert(rows[2].sel:IsShown() and not rows[1].sel:IsShown(), "the raid type is chosen, not the sooner meeting")
assert(f.calTake:IsShown() and f.calTake:IsEnabled() and f.cancel:IsShown())

-- the window shows another event: nothing is opened
_G.CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
STUB.messages = {}
f.calTake:Click()
STUB.tick(1)
assert(said("Kalenderfenster schließen, dann Übernehmen."), STUB.messages[1])
assert(cal.opens == 0, "no open while the calendar window is shown")
-- in combat: not read
CalendarFrame:Hide()
STUB.combat = true
f.calTake:Click()
assert(said("Im Kampf liest Amisia den Kalender nicht."), "combat")
assert(cal.opens == 0)
STUB.combat = false

-- "Übernehmen": opened, read after CALENDAR_OPEN_EVENT, closed; the night of the event
STUB.messages = {}
f.calTake:Click()
assert(cal.opens == 1, "opened")
STUB.tick(1)
assert(cal.closes == 1 and not cal.open, "closed after the read")
local line = said("Aufstellung: Kalender Molten Core, ")
assert(line and has(line, ": 7 Einträge, 2 angemeldet, 1 vorläufig, 1 abgesagt.") and has(line, "1 auf Ersatz.") and has(line, "2 ohne Antwort."), tostring(line))
local ev = cal.events[2]
local night = ("%04d-%02d-%02d"):format(ev.year, ev.month, ev.monthDay)
assert(night == NS.NightOf(time({ year = ev.year, month = ev.month, day = ev.monthDay, hour = 20 })), "the event's night")
assert(f.match:IsShown() and has(f.night.label:GetText(), ("%02d.%02d."):format(ev.monthDay, ev.month)), "the page shows the night")
local n = NS.LineupNight(night)
assert(n.cal and n.cal.id == "12" and n.cal.title == "Molten Core", "the night keeps its event")
local function e(name)
    for _, x in ipairs(NS.LineupNight(night).list) do if x.n == name then return x end end
end
assert(e("Vuloo").st == "B" and e("Vuloo").f == "K" and not e("Vuloo").a, "confirmed")
assert(e("Vulo Pala").st == "A" and e("Vulo Pala").c == "PALADIN" and e("Vulo Pala").r == "H" and e("Vulo Pala").q, "signed up, role guessed")
assert(e("Anna Bergmann").st == "V" and e("Anna Bergmann").m, "tentative")
assert(e("Bob Eisherz").st == "X" and e("Bob Eisherz").a, "declined: not placed")
assert(e("Kim Sturmwind").st == "E" and e("Kim Sturmwind").b, "standby: on the bench")
assert(e("Fremder Gast").st == "I" and e("Fremder Gast").a and e("Fremder Gast").x == "g", "invited guest")
assert(e("Vulo Hunt").st == "O" and e("Vulo Hunt").a, "no answer")
assert(has(f.calLine:GetText(), "Kalender: Molten Core · ") and has(f.calLine:GetText(), "gelesen ") and has(f.calLine:GetText(), "Liste 0 · Kalender 7 · Amisia 0"),
    f.calLine:GetText())
local function rowOf(name)
    for _, r in ipairs(f.mlist.rows) do
        if r:IsShown() and r.item and r.item.e.n == name then return r end
    end
end
assert(has(rowOf("Vulo Pala").src:GetText(), "K") and has(rowOf("Vulo Pala").state:GetText(), "angemeldet"))
assert(has(rowOf("Anna Bergmann").state:GetText(), "vorläufig") and has(rowOf("Vulo Hunt").state:GetText(), "ohne Antwort"))
assert(cal.writes == 0, "nothing written")

-- a pasted list after the calendar: the calendar's rows stay, a name in both is one row with two marks;
-- the list is older: a sign-off in the calendar beats "angemeldet" in Discord, with the hint
STUB.messages = {}
local key, pasted = NS.SetLineupText("Heiler\nVulo Pala\nTanks\nBob Eisherz\nAbgemeldet\nAnna Bergmann", night)
assert(key == night)
assert(has(pasted, "Aufstellung: 2 Anmeldungen"), pasted)
assert(#NS.LineupNight(night).list == 7, "no doubles, the calendar's rows stay")
assert(e("Vulo Pala").f == "LK" and e("Vulo Pala").r == "H" and not e("Vulo Pala").q, "two marks, the list's role")
assert(e("Bob Eisherz").st == "X" and e("Bob Eisherz").d == "A" and e("Bob Eisherz").r == "T", "the calendar's sign-off counts")
assert(e("Anna Bergmann").st == "V" and e("Anna Bergmann").d == "X", "the calendar's tentative beats the list's absent")
NS.ShowLineup("match", night)
assert(has(rowOf("Bob Eisherz").act:GetText(), "Discord: angemeldet") and has(rowOf("Bob Eisherz").src:GetText(), "L|r ") and has(rowOf("Bob Eisherz").src:GetText(), "K|r"), "the hint")
-- a new paste takes only the list's rows away
NS.SetLineupText("Vulo Pala Heiler", night)
assert(e("Bob Eisherz") and e("Bob Eisherz").f == "K" and not e("Bob Eisherz").d, "the calendar's row stays without the list's mark")

-- Amisia and the calendar: the newest statement of the player; within 2 minutes Amisia counts
local now = time()
assert(NS.LineupSignup(night, "Anna Bergmann", { s = "A", r = "H", t = now, w = "komme 20:15" }, true))
assert(e("Anna Bergmann").st == "A" and e("Anna Bergmann").f == "KA" and e("Anna Bergmann").w == "komme 20:15", "Amisia's click is newer than the first sighting")
assert(not NS.LineupSignup(night, "Anna Bergmann", { s = "X", t = now - 10 }, true), "an older click changes nothing")
STUB.tick(56)
cal.invites[12][3].inviteStatus = 2
STUB.tick(4)   -- (a change within 3 s of an own read is taken for the read's echo)
STUB.fire("CALENDAR_UPDATE_GUILD_EVENTS")   -- the page is open: read again within 5 s
STUB.tick(6)
assert(cal.opens >= 2 and not cal.open, "read again and closed")
assert(e("Anna Bergmann").ks == "X" and e("Anna Bergmann").st == "A", "the calendar 60 s after the click: the same click, Amisia counts")
STUB.tick(200)
cal.invites[12][3].inviteStatus = 8
STUB.tick(4)
STUB.fire("CALENDAR_UPDATE_GUILD_EVENTS")
STUB.tick(6)
assert(e("Anna Bergmann").st == "V", "a later change in the calendar is newer")
NS.ShowLineup("match", night)
assert(has(rowOf("Anna Bergmann").name:GetText(), " *"), "the note mark")

-- the officer's hand stays: a group, a held player, a role
local list = NS.LineupNight(night).list
local pala
for i, x in ipairs(list) do if x.n == "Vulo Pala" then pala = i end end
assert(NS.LineupMove(night, pala, 3) and NS.LineupSetRole(night, pala, "T"))
assert(NS.LineupSignup(night, "Vulo Pala", { s = "A", r = "H", t = time() }, true))
assert(e("Vulo Pala").g == 3 and e("Vulo Pala").r == "T", "a new sign-up moves nobody, the role by hand stays")
-- signing off: out of the group, one chat line
STUB.messages = {}
STUB.tick(1)
assert(NS.LineupSignup(night, "Vulo Pala", { s = "X", t = time() }, true))
assert(not e("Vulo Pala").g and e("Vulo Pala").a, "out of the group")
assert(said("Aufstellung: Vulo Pala hat sich abgemeldet (war Gruppe 3)."), STUB.messages[1])
-- held: stays, red
list = NS.LineupNight(night).list
local vuloo
for i, x in ipairs(list) do if x.n == "Vuloo" then vuloo = i end end
NS.LineupMove(night, vuloo, 2)
NS.LineupHold(night, vuloo, true)
STUB.messages = {}
assert(NS.LineupSignup(night, "Vuloo", { s = "X", t = time() }, true))
assert(e("Vuloo").g == 2 and e("Vuloo").k and not e("Vuloo").a, "the held player stays")
assert(said("hat sich abgemeldet (Gruppe 2, festgehalten)."))
NS.Refresh()
assert(has(rowOf("Vuloo").state:GetText(), "|cffe0574a"), "red")

-- removed by the officer: the same calendar status does not bring the name back, a new one does
list = NS.LineupNight(night).list
for i, x in ipairs(list) do if x.n == "Kim Sturmwind" then NS.LineupRemove(night, i) break end end
NS.LineupCalendarAgain(night)
STUB.tick(1)
assert(not e("Kim Sturmwind"), "not back with the old status")
cal.invites[12][5].inviteStatus = 6
NS.LineupCalendarAgain(night)
STUB.tick(1)
assert(e("Kim Sturmwind") and e("Kim Sturmwind").st == "A", "back after a new status")

-- someone leaves the calendar: grey "nicht mehr im Kalender" when it was the only source
table.remove(cal.invites[12], 7)   -- Vulo Hunt
NS.LineupCalendarAgain(night)
STUB.tick(1)
assert(e("Vulo Hunt").st == "G" and e("Vulo Hunt").a, "no longer in the calendar")

-- the page closed: no reading on a change
local opens = cal.opens
AmisiaFrame:Hide()
STUB.fire("CALENDAR_UPDATE_GUILD_EVENTS")
STUB.tick(40)
assert(cal.opens == opens, "nothing read while the page is closed")
-- open again: no endless reading (the own read is no change)
NS.ShowLineup("match", night)
STUB.tick(61)
assert(cal.opens - opens <= 3, "a read now and then, no loop: " .. (cal.opens - opens))

-- the event is gone: the rows stay, the calendar mark turns grey
cal.set({ { title = "Gildentreffen", days = 1, eventType = 3, id = 11 } })
NS.LineupCalendarAgain(night)
STUB.tick(1)
assert(NS.LineupNight(night).cal.lost, "lost")
NS.Refresh()
assert(has(f.calLine:GetText(), "Ereignis nicht mehr im Kalender") and #NS.LineupNight(night).list >= 7, f.calLine:GetText())
assert(has(rowOf("Vuloo").src:GetText(), "|cff8f86a3"), "grey mark")

-- a client that does not answer: the event is closed after 10 s, the chat says so
cal = STUB.calendar({ silent = true, events = { { title = "Onyxia", days = 3, id = 21 } }, invites = { [21] = {} } })
STUB.messages = {}
NS.ShowLineup("calendar")
STUB.tick(1)
f.calTake:Click()
assert(cal.opens == 1)
STUB.tick(11)
assert(said("Kalender antwortet nicht, gleich nochmal."), STUB.messages[#STUB.messages])
assert(cal.closes == 1 and not cal.open, "closed after the time out")
-- the client refuses the open
cal = STUB.calendar({ refuse = true, events = { { title = "Onyxia", days = 3, id = 21 } } })
STUB.messages = {}
Cal._reset()
NS.ShowLineup("calendar")
STUB.tick(1)
f.calTake:Click()
STUB.tick(1)
assert(said("Der Kalender hat das Ereignis nicht geöffnet."), STUB.messages[#STUB.messages])
assert(cal.closes == 1, "closed all the same")

-- the calendar window shows exactly the chosen event: read without an own open and left open
cal = STUB.calendar({ events = { { title = "Onyxia", days = 3, id = 21 } }, invites = { [21] = { { name = "Bob Eisherz", classFilename = "WARRIOR", inviteStatus = 6 } } } })
NS.ShowLineup("calendar")
STUB.tick(1)
CalendarFrame:Show()
cal.open = cal.events[1]
STUB.messages = {}
f.calTake:Click()
STUB.tick(1)
assert(said("Aufstellung: Kalender Onyxia, "), STUB.messages[1])
assert(cal.opens == 0 and cal.closes == 0 and cal.open, "the window's event stays open")
CalendarFrame:Hide()
-- while the calendar probe runs (/amisia selbsttest kalender) the lineup opens nothing
cal.open = nil
Cal.Hold(true)
NS.ShowLineup("calendar")
STUB.tick(1)
STUB.messages = {}
f.calTake:Click()
STUB.tick(1)
assert(said("Der Kalender wird gerade gelesen."), tostring(STUB.messages[1]) .. " " .. tostring(f.calTake:IsEnabled()))
assert(cal.opens == 0)
Cal.Hold(false)
assert(cal.writes == 0, "no calendar write function was called")
print("calendar lineup ok")
