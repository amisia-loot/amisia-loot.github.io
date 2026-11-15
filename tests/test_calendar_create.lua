-- F-217 (D-142, spec docs/specs/2026-11-15-kalender-termin-anlegen.md): the calendar page in both
-- directions. The shown month lists every guild event, guild announcement and own event of the game
-- calendar (ns.Cal.Month; no holidays; a guild event of the sign-up dates once), a far month is set with
-- SetAbsMonth and the month set before comes back. "Termin anlegen ..." opens the form; "Anlegen" makes
-- the event with the client's calls inside the click (AddEvent last), never in combat, with the client's
-- calendar window open, while a read holds the calendar, from a past day or a past time; the game's
-- refusal turns the button off until /reload. "Für Discord" shows the date as Discord text.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local DAY = 86400

STUB.player, STUB.class = "Vulo Pala", "PALADIN"
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
}
local announce = false
_G.CanEditGuildEvent = function() return announce end

local now = os.date("*t", STUB.now)
local function epochIn(days, hour, minute)
    return os.time({ year = now.year, month = now.month, day = now.day + days, hour = hour or 20, min = minute or 0 })
end
-- a month two ahead of the set one: the client has to set it
local far = os.date("*t", os.time({ year = now.year, month = now.month + 2, day = 10, hour = 20 }))

local cal = STUB.calendar({
    events = { { title = "Molten Core", days = 2, eventType = 0, id = 12, inviteStatus = 7 } },
    month = {
        -- the same guild event as the sign-up date: once on the sheet
        { title = "Molten Core", at = epochIn(2), eventType = 0, id = 12, calendarType = "GUILD_EVENT" },
        { title = "Gildentreffen", at = epochIn(3, 19), eventType = 3, id = 31, calendarType = "GUILD_ANNOUNCEMENT", invitedBy = "Vulo Hunt", inviteType = 0 },
        { title = "Angeln", at = epochIn(3, 21), eventType = 4, id = 32, calendarType = "PLAYER", invitedBy = "Kim", inviteType = 0, inviteStatus = 0 },
        { title = "Dunkelmond", at = epochIn(4), calendarType = "HOLIDAY", id = 33 },
        { title = "Zul'Gurub", at = os.time({ year = far.year, month = far.month, day = 10, hour = 20 }), eventType = 0, id = 34, calendarType = "GUILD_EVENT" },
    },
    create = true, maxDays = 90,
    textures = { [0] = { { title = "Molten Core" }, { title = "Onyxias Hort" }, { title = "Molten Core" } }, [1] = { { title = "Burg Schattenfang" } } },
})
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local CC, Cal = NS.CalCreate, NS.Cal
assert(CC and CC.Available(), "the entry functions are there")
assert(Cal.CanReadMonth(), "the month functions are there")

-- the month of the set month: read at once, holidays left out
local list
Cal.Month(now.year, now.month, function(l) list = l end)
local titles = {}
for _, e in ipairs(list or {}) do titles[#titles + 1] = e.title end
local nd = os.date("*t", epochIn(4))
if nd.month == now.month then
    assert(not table.concat(titles, ","):find("Dunkelmond"), "no holidays")
end
assert(#cal.monthSets == 0, "the set month needs no SetAbsMonth")

-- the page: the announcement and the own invite stand on their day in their colour, the guild event once
NS.SignupLoadTerms(); STUB.tick(1)
NS.ShowPage("calendar")
STUB.tick(1)
local P = NS.PageFrame("calendar")
local function cellOf(key)
    for _, c in ipairs(P.cells) do if c.info.key == key then return c end end
end
local function showMonthOf(at)
    NS.ShowCalendar(NS.NightOf(at))
    STUB.tick(4)
end
showMonthOf(epochIn(3, 19))
local c3 = cellOf(NS.NightOf(epochIn(3, 19)))
assert(c3 and has(c3.lines[2]:GetText(), "Gildentr"), "the announcement on its day: " .. tostring(c3 and c3.lines[2]:GetText()))
assert(has(c3.lines[3]:GetText(), "+1"), "and the own invite beside it")
local c2 = cellOf(NS.NightOf(epochIn(2)))
if c2 then assert(not has(c2.lines[3]:GetText() or "", "+"), "the guild event of the sign-up dates once") end
c3:Click()
STUB.tick(1)
assert(P.terms[1]:IsShown() and has(P.terms[1].text:GetText(), "Gildentreffen"))
assert(P.info:IsShown() and has(P.info:GetText(), "Gildenankündigung") and has(P.info:GetText(), "Vulo Hunt"), P.info:GetText())
assert(not P.signup:IsShown(), "no sign-up for an announcement")
P.terms[2]:Click()
STUB.tick(1)
assert(has(P.info:GetText(), "Einladung von Kim"), P.info:GetText())

-- a far month: set with SetAbsMonth, read after the client's answer, the month before comes back
NS.ShowCalendar(("%04d-%02d-10"):format(far.year, far.month))
STUB.tick(5)
assert(#cal.monthSets >= 2, "the far month set and the old one back: " .. #cal.monthSets)
assert(cal.monthSets[1].m == far.month and cal.monthSets[#cal.monthSets].m == now.month, "back to the month set before")
assert(cal.setM == now.month, "the client's month is the old one again")
local cz = cellOf(("%04d-%02d-10"):format(far.year, far.month))
assert(cz and has(cz.lines[2]:GetText() or "", "Zul"), "the far month's event: " .. tostring(cz and cz.lines[2]:GetText()))
-- the client's calendar window open: no other month is set
local sets = #cal.monthSets
CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
local why
Cal.Month(far.year, far.month + 1 > 12 and far.year + 1 or far.year, function(_, w) why = w end)
assert(why == "window" and #cal.monthSets == sets, "never while the client's window is shown")
assert(CC.Blocker() == "window", "no entry with the client's window open")
CalendarFrame:Hide()
-- the window opens while a far month is read: its own month counts, nothing read, nothing set back
local res2
cal.setM, cal.setY = now.month, now.year
Cal.Month(far.year, far.month, function(l, w) res2 = { l, w } end)
CalendarFrame:Show()
cal.setM, cal.setY = now.month, now.year   -- the window's OnShow sets the present month
STUB.tick(1)
assert(res2 and res2[1] == nil and res2[2] == "window", "nothing read when the window took the month")
CalendarFrame:Hide()

-- the form: a day ahead, a raid, an instance, a time; "Anlegen" inside the click
local target = epochIn(5)
NS.ShowCalendar(NS.NightOf(target))
STUB.tick(1)
assert(P.create:IsShown(), "Termin anlegen on a coming day")
P.create:Click()
assert(P.form:IsShown() and not P.terms[1]:IsShown(), "the form over the day")
assert(has(P.dayTitle:GetText(), "Neuer Termin"), P.dayTitle:GetText())
assert(#P.kind.values == 1, "an announcement only with the game's right")
P.typePick.onPick(0)
assert(#P.texPick.values == 2, "the instances, one per name")
P.texPick.onPick(2)
assert(P.titleBox:GetText() == "Onyxias Hort", "the title follows the instance: " .. P.titleBox:GetText())
P.timeBox:SetText("19:30")
P.descBox.box:SetText("Feuerresi |cffff0000mitbringen|r")
local before = #cal.made
STUB.inClick = true
P.formAdd:Click()
STUB.inClick = false
assert(#cal.made == before + 1, "AddEvent called once")
local m = cal.made[#cal.made]
assert(m.inClick and m.calendarType == "GUILD_EVENT" and m.title == "Onyxias Hort" and m.eventType == 0 and m.textureIndex == 2, "the client's calls")
local td = os.date("*t", target)
assert(m.year == td.year and m.month == td.month and m.monthDay == td.day and m.hour == 19 and m.minute == 30, "date and time")
assert(m.description == "Feuerresi mitbringen", "codes away: " .. tostring(m.description))
assert(has(P.formHint:GetText(), "Wird im Spielkalender angelegt"), P.formHint:GetText())
STUB.tick(2)
assert(said("Termin im Spielkalender angelegt") and said("19:30") and said("Onyxias Hort"), "the chat line")
assert(not P.form:IsShown(), "the form closes")
assert(AmisiaDB.calForm and AmisiaDB.calForm.type == 0 and AmisiaDB.calForm.h == 19 and AmisiaDB.calForm.m == 30 and AmisiaDB.calForm.tex == "Onyxias Hort", "the form remembered")
assert(cal.draft == nil, "the draft closed")
-- the new event on the sheet (read again after the change)
STUB.tick(5)
local ct = cellOf(NS.NightOf(target))
assert(ct and (has(ct.lines[2]:GetText(), "Onyx")), "the new event on the sheet: " .. tostring(ct and ct.lines[2]:GetText()))

-- the next form starts with the last values
P.create:Click()
assert(P.typePick:GetValue() == 0 and P.texPick:GetValue() == 2 and P.timeBox:GetText() == "19:30", "the last form")
-- the arrows step 15 minutes
P.timePlus:Click()
assert(P.timeBox:GetText() == "19:45", P.timeBox:GetText())
P.timeMinus:Click(); P.timeMinus:Click()
assert(P.timeBox:GetText() == "19:15", P.timeBox:GetText())
P.formCancel:Click()
assert(not P.form:IsShown() and P.create:IsShown(), "Abbrechen closes the form")

-- checks: a past time today, combat, a missing title, an announcement without the right, a day too far
local today = CC.Today()
local f = { kind = "signup", type = 3, day = today, time = 0, title = "x" }
assert(CC.Check(f) == "passed", "a time already over today")
f.time = 23 * 60 + 59
f.day = today - DAY
assert(CC.Check(f) == "past")
f.day = today + 200 * DAY
assert(CC.Check(f) == "late")
f.day = today + DAY
f.title = "  |cff00ff00|r "
assert(CC.Check(f) == "title")
f.title = "Treffen"
f.kind = "announce"
assert(CC.Check(f) == "announce")
announce = true
assert(CC.Check(f) == nil)
f.type, f.tex = 0, nil
assert(CC.Check(f) == "instance")
f.type = 3
STUB.combat = true
assert(CC.Check(f) == "combat")
STUB.combat = false
Cal.Hold(true)
assert(CC.Check(f) == "busy", "not while a probe holds the calendar")
Cal.Hold(false)
assert(CC.Clean("Ä" .. ("b"):rep(40), 31) == "Ä" .. ("b"):rep(30), "31 characters, not bytes")

-- the client's error: the reason in the form, "im Spielkalender anlegen"
cal = STUB.calendar({ month = {}, create = true, createFail = true })
CC._reset()
local res
assert(CC.Create({ kind = "signup", type = 3, day = today + DAY, time = 20 * 60, title = "Treffen" }, function(ok, w, d) res = { ok, w, d } end))
STUB.tick(1)
assert(res and res[1] == false and res[2] == "error", "the client's error")

-- the game refuses (AddEvent without a hardware event): no more tries until /reload
cal = STUB.calendar({ month = {}, create = true, hw = true })
CC._reset()
res = nil
C_Timer.After(0.1, function()
    CC.Create({ kind = "signup", type = 3, day = today + DAY, time = 20 * 60, title = "Treffen" }, function(ok, w) res = { ok, w } end)
end)
STUB.tick(1)
assert(res and res[1] == false and res[2] == "blocked", "blocked from a timer")
assert(CC.Refused() and CC.Blocker() == "refused", "refused until /reload")
NS.Refresh()
assert(not P.create:IsEnabled(), "the button off")

-- no answer: timeout, the draft closed
cal = STUB.calendar({ month = {}, create = true, createSilent = true })
CC._reset()
res = nil
assert(CC.Create({ kind = "signup", type = 3, day = today + DAY, time = 20 * 60, title = "Treffen" }, function(ok, w) res = { ok, w } end))
STUB.tick(CC.WAIT + 1)
assert(res and res[2] == "timeout" and cal.draft == nil)

-- a far month without the client's answer: what is there, marked to be read again
local silent = STUB.calendar({ month = {}, monthSilent = true })
local part
Cal.Month(far.year, far.month, function(l, p) part = { l, p } end)
STUB.tick(Cal.MONTH_WAIT + 1)
assert(part and part[1] and part[2] == true, "partial without the answer")
assert(silent.setM == now.month, "the month set back")

-- Discord text: timestamps, escaped title, the sign-up line only for guild events
local text = CC.DiscordText({ at = 1800000000, title = "MC @everyone *jetzt*", type = 0, kind = "GUILD_EVENT" }, "Bitte pünktlich")
assert(has(text, "<t:1800000000:F>") and has(text, "<t:1800000000:R>"), text)
assert(not has(text, "@everyone") and has(text, "\\*jetzt\\*"), "escaped: " .. text)
assert(has(text, "Schlachtzug") and has(text, "Bitte pünktlich") and has(text, "Anmelden: im Spielkalender"), text)
assert(not has(CC.DiscordText({ at = 1800000000, title = "Treffen", kind = "GUILD_ANNOUNCEMENT" }), "Anmelden"), "no sign-up line for an announcement")
-- the page's Discord view
cal = STUB.calendar({ events = { { title = "Molten Core", days = 2, eventType = 0, id = 12 } }, month = {}, create = true })
CC._reset()
NS.SignupLoadTerms(); STUB.tick(1)
NS.ShowCalendar(NS.NightOf(epochIn(2)))
STUB.tick(1)
assert(P.discord:IsShown())
P.discord:Click()
assert(P.discordBox:IsShown() and has(P.discordBox.box:GetText(), "**Molten Core**"), P.discordBox.box:GetText())
P.discordClose:Click()
assert(not P.discordBox:IsShown() and P.terms[1]:IsShown())

-- the saved form is checked on load
local DB = { calForm = { kind = "signup", type = 9, h = 20, m = 0 } }
CC.Loaded(DB)
assert(DB.calForm == nil, "a bad type drops it")
DB = { calForm = { kind = "announce", type = 0, h = 20, m = 15, tex = "Onyxias Hort", junk = 1 } }
CC.Loaded(DB)
assert(DB.calForm and DB.calForm.junk == nil and DB.calForm.tex == "Onyxias Hort")
DB = { calForm = { kind = "signup", type = 0, h = 20, m = 0, tex = "a|cff" } }
CC.Loaded(DB)
assert(DB.calForm == nil, "codes in the instance drop it")
print("calendar create ok")
