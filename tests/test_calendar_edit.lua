-- F-222 (D-147, spec docs/specs/2026-11-16-kalender-bearbeiten-loeschen.md): events of the game calendar
-- changed and deleted from the calendar page. "Bearbeiten" and "Löschen" show only for an event the game
-- lets the player change or delete; "Bearbeiten" opens the event and fills the form with its values,
-- "Speichern" writes only the changed fields and UpdateEvent inside the click; "Löschen" asks first and
-- deletes inside the question's click. Never in combat or with the client's calendar window open; another
-- day, a fight or the window end an edit without a change; the game's refusal turns both off until /reload.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end

STUB.player, STUB.class = "Vulo Pala", "PALADIN"
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
}
_G.CanEditGuildEvent = function() return false end

local now = os.date("*t", STUB.now)
local function epochIn(days, hour, minute)
    return os.time({ year = now.year, month = now.month, day = now.day + days, hour = hour or 20, min = minute or 0 })
end
local far = os.date("*t", os.time({ year = now.year, month = now.month + 3, day = 10, hour = 20 }))
local farAt = os.time({ year = far.year, month = far.month, day = 10, hour = 20 })

local function world(extra)
    local opts = {
        events = {},
        month = {
            { title = "Molten Core", at = epochIn(5), eventType = 0, id = 41, calendarType = "GUILD_EVENT", modStatus = "CREATOR",
              textureIndex = 3, description = "Bitte |cffff0000Feuerresi|r" },
            { title = "Fremder Raid", at = epochIn(5, 21), eventType = 0, id = 42, calendarType = "GUILD_EVENT", invitedBy = "Vulo Hunt" },
            { title = "Angeln", at = epochIn(6, 21), eventType = 4, id = 44, calendarType = "PLAYER", modStatus = "CREATOR", inviteType = 0 },
            { title = "Gestern", at = epochIn(-1), eventType = 3, id = 45, calendarType = "GUILD_EVENT", modStatus = "CREATOR" },
            { title = "Zul'Gurub", at = farAt, eventType = 0, id = 46, calendarType = "GUILD_EVENT", modStatus = "CREATOR" },
        },
        create = true, edit = true, maxDays = 200,
        textures = { [0] = { { title = "Molten Core" }, { title = "Onyxias Hort" }, { title = "Molten Core" } }, [1] = { { title = "Burg Schattenfang" } } },
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return STUB.calendar(opts)
end
local cal = world()
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local CE, CC, Cal = NS.CalEdit, NS.CalCreate, NS.Cal
assert(CE and CE.Available("edit") and CE.Available("remove"), "the functions are there")

NS.SignupLoadTerms(); STUB.tick(1)
NS.ShowPage("calendar")
STUB.tick(1)
local P = NS.PageFrame("calendar")
local function show(at)
    NS.ShowCalendar(NS.NightOf(at))
    STUB.tick(5)
end
local function click(b)
    STUB.inClick = true
    b:Click()
    STUB.inClick = false
end
local function monthEvent(id)
    for _, e in ipairs(cal.month) do if e.eventID == id then return e end end
end
local confirm = function() return _G.AmisiaConfirmFrame end

-- the links: only for what the game allows
show(epochIn(5))
assert(has(P.terms[1].text:GetText(), "Molten Core") and has(P.terms[2].text:GetText(), "Fremder Raid"), "the day's events")
P.terms[1]:Click(); STUB.tick(1)
assert(P.edit:IsShown() and P.remove:IsShown(), "the own event: Bearbeiten and Löschen")
assert(P.edit:IsEnabled() and P.remove:IsEnabled())
P.terms[2]:Click(); STUB.tick(1)
assert(not P.edit:IsShown() and not P.remove:IsShown(), "another's event: neither")
local list
Cal.Month(os.date("*t", epochIn(5)).year, os.date("*t", epochIn(5)).month, function(l) list = l end)
local function item(id)
    for _, e in ipairs(list or {}) do if e.id == tostring(id) then return e end end
end
local res
assert(CE.Begin(item(42), "remove", function(ok, why) res = { ok, why } end) == true)
assert(res and res[1] == false and res[2] == "right", "the game is asked again: no right")
assert(not CE.Session() and not Cal.Busy(), "nothing held after a refusal")
assert(#cal.removed == 0)

-- the client's calendar window open or a fight: the links are grey with the reason
P.terms[1]:Click(); STUB.tick(1)
CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
NS.Refresh()
assert(P.edit:IsShown() and not P.edit:IsEnabled() and has(P.edit.why, "Spielkalender schließen"), tostring(P.edit.why))
assert(CE.Blocker() == "window")
CalendarFrame:Hide()
STUB.combat = true
NS.Refresh()
assert(not P.remove:IsEnabled() and CE.Blocker() == "combat")
STUB.combat = false
NS.Refresh()

-- "Bearbeiten": the event opened, the form with its values, day and kind fixed
click(P.edit)
STUB.tick(1)
assert(cal.open and cal.open.eventID == 41, "the event is open in the game")
assert(P.form:IsShown() and has(P.dayTitle:GetText(), "Termin ändern"), P.dayTitle:GetText())
assert(P.titleBox:GetText() == "Molten Core" and P.timeBox:GetText() == "20:00", P.titleBox:GetText() .. " " .. P.timeBox:GetText())
assert(P.descBox.box:GetText() == "Bitte Feuerresi", "the description without codes: " .. P.descBox.box:GetText())
assert(#P.kind.values == 1 and has(P.kind.values[1].text, "Gildenereignis"), "the kind stays")
assert(P.typePick:GetValue() == 0 and P.texPick:GetValue() == 1, "type and instance (the first of its name)")
assert(Cal.Busy(), "no own read opens another event meanwhile")
assert(not P.edit:IsShown() and not P.create:IsShown(), "no other calendar button beside the form")
assert(not P.formAdd:IsEnabled(), "Speichern is off without a change")
assert(select(2, CE.Save({ type = 0, tex = 3, time = 20 * 60, title = "Molten Core", desc = "Bitte Feuerresi" }, function() end)) == "same")
assert(#cal.updates == 0, "nothing written without a change")

-- "Speichern": only the changed fields, inside the click
P.titleBox:SetText("MC |cff00ff00Feuer|r")
P.timeBox:SetText("19:30")
NS.Refresh()
assert(P.formAdd:IsEnabled(), "a change turns Speichern on")
click(P.formAdd)
assert(#cal.updates == 1 and cal.updates[1].inClick and cal.updates[1].id == 41, "UpdateEvent once, in the click")
local ch = cal.updates[1].changes
assert(ch.title == "MC Feuer" and ch.hour == 19 and ch.minute == 30, "title without codes, the time")
assert(ch.description == nil and ch.eventType == nil and ch.textureIndex == nil, "nothing else touched")
assert(has(P.formHint:GetText(), "Wird im Spielkalender geändert"), P.formHint:GetText())
STUB.tick(2)
assert(said("Termin geändert") and said("19:30") and said("MC Feuer"), "the chat line")
assert(not P.form:IsShown() and cal.open == nil and not CE.Session() and not Cal.Busy(), "the form and the event closed")
assert(monthEvent(41).title == "MC Feuer" and monthEvent(41).startTime.hour == 19)

-- type and instance: the texture is set after the type
show(epochIn(5))
P.terms[1]:Click(); STUB.tick(1)
click(P.edit); STUB.tick(1)
assert(P.form:IsShown() and P.titleBox:GetText() == "MC Feuer")
P.texPick.onPick(2)
click(P.formAdd)
STUB.tick(2)
assert(#cal.updates == 2 and cal.updates[2].changes.textureIndex == 2 and cal.updates[2].changes.eventType == nil, "the instance alone")
assert(monthEvent(41).textureIndex == 2)

-- "Abbrechen", another day, another page: closed without a change
P.terms[1]:Click(); STUB.tick(1)
click(P.edit); STUB.tick(1)
assert(P.form:IsShown() and cal.open)
P.titleBox:SetText("Anders")
P.formCancel:Click()
assert(not P.form:IsShown() and cal.open == nil and not CE.Session() and #cal.updates == 2, "Abbrechen")
click(P.edit); STUB.tick(1)
assert(P.form:IsShown())
show(epochIn(6, 21))
assert(not P.form:IsShown() and cal.open == nil and not CE.Session(), "another day ends the edit")
show(epochIn(5))
P.terms[1]:Click(); STUB.tick(1)
click(P.edit); STUB.tick(1)
assert(P.form:IsShown())
NS.ShowPage("overview")
STUB.tick(1)
assert(not CE.Session() and cal.open == nil, "another page ends the edit")
NS.ShowPage("calendar")
STUB.tick(1)

-- a fight or the client's calendar window while the form shows: over, nothing written
show(epochIn(5))
P.terms[1]:Click(); STUB.tick(1)
click(P.edit); STUB.tick(1)
assert(P.form:IsShown())
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
assert(not CE.Session() and cal.open == nil, "a fight closes the event")
STUB.combat = false
NS.Refresh()
assert(not P.form:IsShown(), "and the form")
click(P.edit); STUB.tick(1)
assert(P.form:IsShown())
local closes = cal.closes
CalendarFrame:Show()
STUB.tick(1)
assert(not CE.Session() and cal.closes == closes, "the client's window takes the event: not closed by Amisia")
NS.Refresh()
assert(not P.form:IsShown())
CalendarFrame:Hide()
cal.open = nil

-- the client's error: the reason in the form, the event still open for another try
show(epochIn(5))
P.terms[1]:Click(); STUB.tick(1)
click(P.edit); STUB.tick(1)
cal.fail.UpdateEvent = true
P.timeBox:SetText("19:45")
NS.Refresh()
click(P.formAdd)
STUB.tick(1)
assert(P.form:IsShown() and has(P.formHint:GetText(), "Ändere ihn bitte im Spielkalender"), P.formHint:GetText())
assert(CE.Session() and cal.open, "the form's event stays open")
cal.fail.UpdateEvent = nil
cal.pendingEdit = {}
click(P.formAdd)
STUB.tick(2)
assert(monthEvent(41).startTime.minute == 45 and not CE.Session(), "the second try")

-- a past event: no edit, the delete is the game's call; an own (not guild) event names the invited
show(epochIn(-1))
STUB.tick(1)
local past = P.terms[1]:IsShown() and has(P.terms[1].text:GetText(), "Gestern")
if past then
    assert(not P.edit:IsShown() and P.remove:IsShown(), "a past event: only Löschen")
end
show(epochIn(6, 21))
assert(has(P.terms[1].text:GetText(), "Angeln") and P.remove:IsShown())
click(P.remove); STUB.tick(1)
assert(confirm() and confirm():IsShown() and has(confirm().text:GetText(), "Eingeladenen") and has(confirm().text:GetText(), "Angeln"), "the question")
assert(#cal.removed == 0, "nothing deleted before the answer")
confirm().cancel:Click()
assert(not CE.Session() and #cal.removed == 0, "Abbrechen: nothing deleted")

-- "Löschen": the question, then the client's two calls inside its click
show(epochIn(5))
P.terms[1]:Click(); STUB.tick(1)
click(P.remove); STUB.tick(1)
assert(confirm():IsShown() and has(confirm().text:GetText(), "ganze Gilde") and has(confirm().text:GetText(), "MC Feuer"), confirm().text:GetText())
click(confirm().ok)
assert(#cal.removed == 1 and cal.removed[1].id == 41 and cal.removed[1].inClick and cal.removed[1].selectedInClick, "selected and removed in the click")
STUB.tick(2)
assert(said("Termin gelöscht") and said("MC Feuer"), "the chat line")
assert(monthEvent(41) == nil and not CE.Session() and not Cal.Busy())
STUB.tick(5)
assert(has(P.terms[1].text:GetText(), "Fremder Raid"), "the sheet read again: " .. tostring(P.terms[1].text:GetText()))

-- the event deleted by someone else while the question shows: nothing called
show(epochIn(6, 21))
click(P.remove); STUB.tick(1)
assert(confirm():IsShown())
for i, e in ipairs(cal.month) do if e.eventID == 44 then table.remove(cal.month, i) break end end
click(confirm().ok)
assert(#cal.removed == 1 and said("Ereignis nicht mehr im Kalender"), "gone: no call")
assert(not CE.Session())

-- a month the client has not loaded: set for the delete, the month set before back afterwards
show(farAt)
assert(has(P.terms[1].text:GetText(), "Zul"), "the far month's event")
assert(P.remove:IsShown() and P.edit:IsShown(), "the own event of a far month")
local sets = #cal.monthSets
click(P.remove)
STUB.tick(2)
assert(#cal.monthSets == sets + 1 and cal.setM == far.month, "the event's month set")
assert(confirm():IsShown())
click(confirm().ok)
STUB.tick(2)
assert(#cal.removed == 2 and cal.removed[2].id == 46 and monthEvent(46) == nil, "deleted")
assert(cal.setM == now.month and cal.setY == now.year, "the month set before is back")

-- the game refuses (UpdateEvent blocked for Amisia): off until /reload
cal = world({ hw = true })
CE._reset(); CC._reset()
show(epochIn(5))
STUB.tick(5)
P.terms[1]:Click(); STUB.tick(1)
STUB.inClick = true
P.edit:Click()
STUB.inClick = false
STUB.tick(1)
assert(P.form:IsShown(), "the form again")
P.timeBox:SetText("18:00")
NS.Refresh()
P.formAdd:Click()   -- not a hardware click
STUB.tick(1)
assert(CE.Refused() and CE.Blocker() == "refused", "refused until /reload")
assert(not CE.Session() and cal.open == nil, "the session over")
NS.Refresh()
assert(not P.form:IsShown() and P.edit:IsShown() and not P.edit:IsEnabled() and not P.remove:IsEnabled(), "both links off")

-- no answer: the timeout ends the session
cal = world()
CE._reset(); CC._reset()
cal.quiet.ContextMenuEventRemove = true
Cal.Month(os.date("*t", epochIn(5)).year, os.date("*t", epochIn(5)).month, function(l) list = l end)
res = nil
assert(CE.Begin(item(41), "remove", function(ok) res = ok end) and res == true)
local out
assert(CE.Remove(function(ok, why) out = { ok, why } end))
STUB.tick(CE.WAIT + 1)
assert(out and out[1] == false and out[2] == "timeout" and not CE.Session(), "timeout")

-- a call of the guild is no event of the game calendar; an edit needs an event still to come
assert(not CE.IsEvent({ call = {}, at = epochIn(1) }) and not CE.Rights({ call = {}, at = epochIn(1) }).edit)
assert(select(2, CE.Begin(item(45) or { id = "45", at = epochIn(-1), title = "Gestern", kind = "GUILD_EVENT" }, "edit", function() end)) == "past")
