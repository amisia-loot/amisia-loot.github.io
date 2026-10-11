-- Review of the calendar page (2.27.0, D-45): (1) a night with two dates (a meeting at 18:00, the
-- raid at 20:00): the raid calendar window reads the night's first date, the page the chosen one;
-- each shows its own event's participants, never the list the other read last, and a date not read
-- yet does not borrow another's list. (2) The page reads the calendar only while it is on the
-- screen: the open page of a closed main window does not read on every calendar change.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST", level = 60 },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR", level = 60 },
}
local cal = STUB.calendar({ events = {
    { title = "Molten Core", days = 1, eventType = 0, id = 12, inviteStatus = 7 },
    { title = "Gildentreffen", days = 1, hour = 18, eventType = 3, id = 13, inviteStatus = 7 },
}, invites = { [12] = {
    { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 3 },
    { name = "Anna Bergmann", classFilename = "PRIEST", level = 60, inviteStatus = 6 },
    { name = "Bob Eisherz", classFilename = "WARRIOR", level = 60, inviteStatus = 8 },
} } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local terms = NS.SignupTerms()
local N1 = terms[1].night
assert(terms[1].id == "13" and terms[2].id == "12" and terms[2].night == N1, "the meeting first, the raid the same night")

local function names(list)
    local out = {}
    for _, it in ipairs(list.items) do if it.e then out[#out + 1] = it.e.n end end
    return table.concat(out, ",")
end

-- the page: the raid of the night chosen and read
NS.ShowPage("calendar")
STUB.tick(1)
local P = NS.CalendarPageFrame()
assert(P.terms[2].sel:IsShown(), "the raid chosen")
assert(names(P.list) == "Anna Bergmann,Vulo Hunt,Bob Eisherz", names(P.list))

-- (1a) the raid calendar window at the same night reads its first date (the meeting, nobody invited)
local RF = NS.ShowRaidCalendar(N1)
STUB.tick(1)
assert(RF:IsShown())
assert(#RF.list.items == 0, "the window: the meeting's list (empty)")
NS.Refresh()
-- before the review: the page showed the meeting's empty list under the chosen raid, "Kalender gelesen"
assert(P.terms[2].sel:IsShown(), "still the raid")
assert(names(P.list) == "Anna Bergmann,Vulo Hunt,Bob Eisherz", "the page keeps the raid's list: " .. names(P.list))
assert(has(P.status:GetText(), "Kalender gelesen"), P.status:GetText())
-- and the window keeps its own after the page read again
P.terms[1]:Click(); STUB.tick(1)
P.terms[2]:Click(); STUB.tick(1)
assert(names(P.list) == "Anna Bergmann,Vulo Hunt,Bob Eisherz")
RF:Hide()
RF = NS.ShowRaidCalendar(N1)
assert(#RF.list.items == 0, "the window shows the meeting's list, not the raid the page read last")
RF:Hide()

-- (1b) a date not read yet does not show the list of the other date of its night
NS.RaidCal._reset()
P.terms[2]:Click(); STUB.tick(1)
assert(names(P.list) == "Anna Bergmann,Vulo Hunt,Bob Eisherz")
local opens = cal.opens
P.terms[1]:Click()           -- the meeting: its read runs, the answer not back yet
assert(cal.opens == opens + 1, "the meeting is read")
assert(names(P.list) == "", "no borrowed list while the meeting is read: " .. names(P.list))
assert(not has(P.status:GetText(), "Kalender gelesen"), "not 'read' before its answer: " .. P.status:GetText())
STUB.tick(1)
assert(has(P.status:GetText(), "Kalender gelesen"))

-- (2) the main window closed on the calendar page: a calendar change reads nothing
P.terms[2]:Click(); STUB.tick(1)
assert(NS.CurrentPage() == "calendar")
AmisiaFrame:Hide()
opens = cal.opens
NS.Fire("CALENDAR_CHANGED", "CALENDAR_UPDATE_INVITE_LIST")
STUB.tick(8)
assert(cal.opens == opens, "no read while the window is closed: " .. (cal.opens - opens))
-- open again: the page reads when it shows
NS.ToggleMain()
STUB.tick(6)
assert(AmisiaFrame:IsShown() and NS.CurrentPage() == "calendar")
print("calendar page review ok")
