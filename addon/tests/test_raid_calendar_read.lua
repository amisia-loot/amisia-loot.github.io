-- The raid calendar window's line about the calendar read (2.25.1, user screenshot 2026-10-11: the
-- line said "Kalender wird gelesen ..." for good and only the Amisia marks "A" showed, although both
-- characters stood in the game calendar). The line follows every read: "wird gelesen" only while
-- one runs, then "Kalender gelesen <Uhrzeit>" or the reason; a date whose event id the client does
-- not give as a number is read too (found by its time and title); a calendar that stays busy says
-- so after RC.BUSY_SHOW seconds; an open whose answer got lost no longer keeps the calendar busy
-- until /reload (Cal.STUCK after its time-out).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local RC, Cal = NS.RaidCal, NS.Cal

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
}
-- the client answers the open a moment later (silent: the test fires CALENDAR_OPEN_EVENT itself)
local cal = STUB.calendar({ silent = true, events = {
    { title = "test123", days = 1, eventType = 4, id = 18866, inviteStatus = 6 },
}, invites = { [18866] = {
    { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 6 },
    { name = "Vulo Pala", classFilename = "PALADIN", level = 58, inviteStatus = 6 },
} } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local t = NS.SignupTerms()[1]
-- both characters of the account signed up in Amisia (the "A" marks)
local now = math.floor(time())
NS._signup.keepSeen(t.night, "Vulo Hunt", { s = "A", r = "R", c = "HUNTER", t = now, w = "lul" })

local F = NS.ShowRaidCalendar(t.night)
assert(cal.opens == 1, "opened at once")
assert(F.status:GetText() == "Kalender wird gelesen ...", "while the read runs: " .. F.status:GetText())
-- the client answers: the line changes to the time of the read, the calendar's marks come
STUB.fire("CALENDAR_OPEN_EVENT", "GUILD_EVENT")
STUB.tick(0.1)
assert(has(F.status:GetText(), "Kalender gelesen " .. date("%H:%M")), "after the read: " .. F.status:GetText())
local function entry(name)
    for _, it in ipairs(F.list.items) do if it.e and it.e.n == name then return it.e end end
end
assert(entry("Vulo Hunt").f == "KA" and entry("Vulo Pala").f == "K", "the calendar's marks K")

-- no answer: after Cal.WAIT the reason, not "wird gelesen" for good
STUB.tick(31)
assert(cal.opens == 2 and has(F.status:GetText(), "Kalender gelesen"), "the poll reads again; the old time stays while it runs")
STUB.tick(Cal.WAIT + 0.5)
assert(F.status:GetText() == "Kalender antwortet nicht, gleich nochmal.", F.status:GetText())
STUB.fire("CALENDAR_OPEN_EVENT", "GUILD_EVENT")   -- a late answer is not taken
STUB.tick(0.1)

-- a date whose event id the client does not give as a number (2.25.0 never read it)
F:Hide()
RC._reset()
Cal._reset()
cal.events[1].eventID = "18866"
cal.invites["18866"] = cal.invites[18866]
NS.SignupLoadTerms(); STUB.tick(1)
t = NS.SignupTerms()[1]
assert(t.id == nil, "no id")
local opens = cal.opens
NS.ShowRaidCalendar(t.night)
assert(cal.opens == opens + 1, "read without an id (found by its time and title)")
STUB.fire("CALENDAR_OPEN_EVENT", "GUILD_EVENT")
STUB.tick(0.1)
assert(has(F.status:GetText(), "Kalender gelesen"), F.status:GetText())
assert(entry("Vulo Pala") and entry("Vulo Pala").f == "K", "its invites read")

-- the calendar busy with another reader (here the probe's hold): "wird gelesen" while it is tried
-- again, after RC.BUSY_SHOW seconds that the calendar is busy; read as soon as it is free
F:Hide()
RC._reset()
Cal.Hold(true)
opens = cal.opens
NS.ShowRaidCalendar(t.night)
assert(cal.opens == opens and F.status:GetText() == "Kalender wird gelesen ...", F.status:GetText())
STUB.tick(RC.BUSY_SHOW + RC.BUSY_RETRY)
assert(has(F.status:GetText(), "Kalender belegt"), "busy for long: " .. F.status:GetText())
Cal.Hold(false)
STUB.tick(RC.BUSY_RETRY + 0.1)
assert(cal.opens == opens + 1, "read once the calendar is free")
STUB.fire("CALENDAR_OPEN_EVENT", "GUILD_EVENT")
STUB.tick(0.1)
assert(has(F.status:GetText(), "Kalender gelesen"), F.status:GetText())

-- an open whose answer got lost (an error in the handler after the open): the calendar is busy at
-- most Cal.WAIT + Cal.STUCK seconds, then the next read goes through
F:Hide()
Cal._reset()
local okOpen = pcall(Cal.Open, NS.Cal.Events()[1], function() error("lost") end, function() end)
assert(okOpen)
STUB.fire("CALENDAR_OPEN_EVENT", "GUILD_EVENT")
assert(not pcall(STUB.tick, 0.1), "the handler's error")
assert(Cal.Busy(), "busy after the lost answer")
STUB.tick(Cal.WAIT + Cal.STUCK + 1)
assert(not Cal.Busy(), "no longer busy after its time-out and Cal.STUCK")
print("raid calendar read ok")
