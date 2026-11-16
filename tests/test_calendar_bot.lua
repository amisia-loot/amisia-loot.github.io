-- F-223 (D-148, spec docs/specs/2026-11-16-kalender-termin-aus-discord.md): an event of the sign-up bot
-- in Discord, pasted as its JSON. "Termin anlegen ..." > "Aus Discord ..." fills the form with the
-- event's day, time (the calendar's clock), title (31 characters, the whole one into the description)
-- and description (Discord's decorations away) and picks the instance the title names; the player still
-- clicks "Anlegen". The same JSON pasted into the lineup gives the sign-ups with role and class. The
-- JSON below is made up after the bot's documented fields (no real event was at hand).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

STUB.player, STUB.class = "Vulo Pala", "PALADIN"
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
    { name = "Xorgok", rank = 3, class = "WARRIOR", level = 60 },
    { name = "Thymae", rank = 3, class = "DRUID", level = 60 },
}
_G.CanEditGuildEvent = function() return false end

local now = os.date("*t", STUB.now)
local function epochIn(days, hour, minute)
    return os.time({ year = now.year, month = now.month, day = now.day + days, hour = hour or 20, min = minute or 0 })
end
local start = epochIn(6, 19, 45)

local cal = STUB.calendar({
    events = {},
    month = { { title = "Schon da", at = start, eventType = 0, id = 71, calendarType = "GUILD_EVENT" } },
    create = true, maxDays = 60,
    textures = { [0] = { { title = "Molten Core" }, { title = "Black Temple" } }, [1] = { { title = "Burg Schattenfang" } } },
})
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local CB, CC = NS.CalBot, NS.CalCreate
assert(CB and CB.Available(), "the client reads JSON")

local function json(at, title, extra)
    return ([[{"id":"998707032230203474","serverId":"1","leaderName":"Vulo","channelName":"raids",
 "title":"%s","description":"**Bitte** Feuerresi mitbringen <@123456> :fire:\nInfos: https://example.org/x <t:1800000000:R>",
 "startTime":%s,"endTime":%s,"date":"22-11-2026","time":"19:45",
 "advancedSettings":{"duration":180,"limit":25,"classes":[{"name":"Tank"}]},
 "signUps":[
  {"name":"Xorgok","id":1,"userId":"11","className":"Tank","specName":"Protection","roleName":"Tanks","status":"primary","position":2},
  {"name":"Thymae","id":2,"userId":"12","className":"Druid","specName":"Balance","roleName":"Ranged","status":"primary","position":1},
  {"name":"Belugia","id":3,"userId":"13","className":"Priest","specName":"Holy1","roleName":"Healers","status":"primary","position":7},
  {"name":"Fervorstrike","id":4,"userId":"14","className":"Absence","specName":"Absence","status":"primary","position":14},
  {"name":"Essa","id":5,"userId":"15","className":"Tentative","specName":"Tentative","status":"primary","position":15},
  {"name":"Kinnell","id":6,"userId":"16","className":"Hunter","specName":"Marksmanship","roleName":"Ranged","status":"queued","position":16},
  {"name":"12345","id":7,"userId":"17","className":"Mage","specName":"Fire","roleName":"Ranged","status":"primary","position":17}
 ]%s}]]):format(title or "Black Temple", tostring(at), tostring(at + 3 * 3600), extra or "")
end

-- the reader: only an event of the bot, sizes and nesting capped
assert(CB.Looks(json(start)) and not CB.Looks("Tank\nXorgok") and not CB.Looks('{"title":"x"}'))
assert(select(2, CB.Read("Black Temple 19:45")) == "not")
assert(select(2, CB.Read('{"startTime":"bald","title":"x"}')) == "not", "a start that is no time")
assert(select(2, CB.Read('{"startTime":12,"title":"x"}')) == "not", "a start that is no sensible moment")
assert(select(2, CB.Read('{"startTime":' .. start .. ',"x":"' .. ("a"):rep(CB.MAX_JSON) .. '"}')) == "big")
assert(select(2, CB.Read('{"startTime":' .. start .. ',"x":' .. ("["):rep(30) .. ("]"):rep(30) .. '}')) == "not", "nested too deep")
assert(CB.Start({ startTime = start * 1000 }) == start, "a start in milliseconds")
assert(CB.Plain("**Hallo** <:Tank:123> <@&99> [Plan](https://example.org/a) ~~alt~~ :smile:", 80) == "Hallo Plan alt", CB.Plain("**Hallo** <:Tank:123> <@&99> [Plan](https://example.org/a) ~~alt~~ :smile:", 80))

-- the form's values: day, time, title, description, the instance the title names
local f = assert(CB.Form(json(start)))
local sd = os.date("*t", start)
assert(f.time == 19 * 60 + 45 and os.date("%Y-%m-%d", f.day) == os.date("%Y-%m-%d", start), "day and time")
assert(f.title == "Black Temple" and f.type == 0 and f.tex == 2 and f.texTitle == "Black Temple", "title and instance")
assert(f.desc == "Bitte Feuerresi mitbringen Infos:", "the description without Discord's marks: [" .. f.desc .. "]")
assert(f.signups == 7 and f.kind == "signup")
-- a long title: cut to 31, whole at the start of the description
local long = "Black Temple Farmrun mit Gildenbank und Kuchen"
local f2 = assert(CB.Form(json(start, long)))
assert(#f2.title <= 31 and has(long, f2.title) and f2.desc:sub(1, #long) == long, f2.title .. " / " .. f2.desc)
-- no instance in the title: the player picks
local f3 = assert(CB.Form(json(start, "Gildentreffen")))
assert(f3.type == nil and f3.tex == nil)
-- past and too far ahead
assert(select(2, CB.Form(json(STUB.now - 3600))) == "past")
assert(select(2, CB.Form(json(STUB.now + 200 * 86400))) == "late")

-- the page: "Termin anlegen ..." > "Aus Discord ..." > paste > the form on the event's day
NS.SignupLoadTerms(); STUB.tick(1)
NS.ShowPage("calendar")
STUB.tick(1)
local P = NS.PageFrame("calendar")
NS.ShowCalendar(NS.NightOf(epochIn(2)))
STUB.tick(1)
P.create:Click()
assert(P.form:IsShown() and P.formBot:IsShown(), "the link in the form")
P.formBot:Click()
assert(P.botBox:IsShown() and not P.form:IsShown() and has(P.dayTitle:GetText(), "Termin aus Discord"), P.dayTitle:GetText())
assert(has(P.botHint:GetText(), "JSON"), "how to get it")
-- something else: the reason, the paste field stays
P.botBox.box:SetText("Black Temple\nTank (3): Xorgok")
P.botTake:Click()
assert(P.botBox:IsShown() and has(P.botHint:GetText(), "kein Termin des Anmelde-Bots"), P.botHint:GetText())
P.botBox.box:SetText(json(STUB.now - 3600))
P.botTake:Click()
assert(P.botBox:IsShown() and has(P.botHint:GetText(), "Vergangenheit"), P.botHint:GetText())
-- the event
P.botBox.box:SetText(json(start))
P.botTake:Click()
STUB.tick(1)
assert(P.form:IsShown() and not P.botBox:IsShown(), "the form again")
assert(has(P.dayTitle:GetText(), "Neuer Termin") and has(P.dayTitle:GetText(), ("%02d.%02d."):format(sd.day, sd.month)), P.dayTitle:GetText())
assert(P.titleBox:GetText() == "Black Temple" and P.timeBox:GetText() == "19:45", P.titleBox:GetText() .. " " .. P.timeBox:GetText())
assert(P.descBox.box:GetText() == "Bitte Feuerresi mitbringen Infos:")
assert(P.typePick:GetValue() == 0 and P.texPick:GetValue() == 2, "raid and the instance")
assert(P.kind:GetValue() == "signup")
-- an event at the same time stands already: said, not refused
assert(has(P.formHint:GetText(), "steht schon") and has(P.formHint:GetText(), "Schon da"), P.formHint:GetText())
assert(P.formAdd:IsEnabled())
-- nothing was made by the paste; "Anlegen" makes it with the player's click
assert(#cal.made == 0, "the paste makes nothing")
STUB.inClick = true
P.formAdd:Click()
STUB.inClick = false
assert(#cal.made == 1)
local m = cal.made[1]
assert(m.inClick and m.title == "Black Temple" and m.hour == 19 and m.minute == 45 and m.eventType == 0 and m.textureIndex == 2, "the client's calls")
assert(m.year == sd.year and m.month == sd.month and m.monthDay == sd.day, "on the event's day")
assert(m.calendarType == "GUILD_EVENT" and m.description == "Bitte Feuerresi mitbringen Infos:")
STUB.tick(2)

-- "Zurück" leaves the paste field for the form
NS.ShowCalendar(NS.NightOf(epochIn(2)))
STUB.tick(1)
P.create:Click()
P.formBot:Click()
P.botBack:Click()
assert(P.form:IsShown() and not P.botBox:IsShown())
P.formCancel:Click()

-- the lineup: the same JSON gives the sign-ups with role, class and state, on the event's night
local res = assert(NS.ParseLineup(json(start)))
local by = {}
for _, e in ipairs(res.list) do by[e.n] = e end
assert(res.bot and res.date == NS.NightOf(start) and res.title == "Black Temple", tostring(res.date))
assert(by.Xorgok and by.Xorgok.r == "T", "the tank")
assert(by.Thymae and by.Thymae.r == "R" and by.Thymae.c == "DRUID", "role and class")
assert(by.Belugia and by.Belugia.r == "H" and by.Belugia.c == "PRIEST", "a numbered spec")
assert(by.Fervorstrike and by.Fervorstrike.a, "absent")
assert(by.Essa and by.Essa.m, "tentative")
assert(by.Kinnell and by.Kinnell.b and by.Kinnell.c == "HUNTER", "the waiting list is the bench")
assert(#res.list == 6 and res.skipped == 1, "a name of digits is no name: " .. #res.list .. "/" .. res.skipped)
local key, line = NS.SetLineupText(json(start))
assert(key == NS.NightOf(start), tostring(key) .. " " .. tostring(line))
local n = 0
for _ in ipairs(NS.LineupNight(key).list) do n = n + 1 end
assert(n == 6, "the night's list: " .. n)
-- an event without sign-ups, and a broken paste
assert(select(2, NS.ParseLineup(json(start):gsub('"signUps":%b[]', '"signUps":[]'))) ~= nil)
assert(NS.ParseLineup('{"startTime":"x","signUps":[]}') == nil)

-- a client without the JSON reader: no link, the reason
local real = C_EncodingUtil.DeserializeJSON
C_EncodingUtil.DeserializeJSON = nil
assert(not CB.Available() and select(2, CB.Read(json(start))) == "api")
NS.ShowCalendar(NS.NightOf(epochIn(2)))
STUB.tick(1)
P.create:Click()
assert(P.form:IsShown() and not P.formBot:IsShown(), "no link without the reader")
P.formCancel:Click()
C_EncodingUtil.DeserializeJSON = real
