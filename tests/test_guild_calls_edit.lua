-- F-219 (D-144): the creator changes the own call. "Ändern" in the creator's view opens the form with the call's
-- values, "Speichern" sends them as a new revision of the same call (same id, sign-ups kept, EA to the guild at
-- most every 10.5 s), a time left as it was stays even when it is past, a new time must be ahead, "Zurück" leads
-- back to the own call. The others take the revision (title, roles, time) without a second chat line.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local GC = NS.GuildCalls

STUB.player, STUB.level = "Vuloo", 40
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 40 },
    { name = "Anna Berg", class = "WARRIOR", rank = 3, level = 42 },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

local sent = {}
local realSend = NS.CommSend
NS.CommSend = function(kind, fields, chan, target, opts)
    sent[#sent + 1] = { kind = kind, fields = fields, chan = chan }
    return realSend(kind, fields, chan, target, opts)
end
local function lastEA()
    local ea
    for _, m in ipairs(sent) do if m.kind == "EA" and m.chan == "GUILD" then ea = m end end
    return ea
end

assert(GC.Edit({ art = "H", title = "x", min = 1, need = { S = 1 } }) == nil, "no own call: nothing to change")
local at = GetServerTime() + 600
assert(GC.Create({ art = "H", title = "Hilfe bei Elite", min = 30, need = { T = 0, H = 1, S = 1 }, at = at, note = "am Turm" }))
STUB.tick(1)
local own = GC.Own()
local id = own.id
-- Anna signs up as healer
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EJ\t" .. id .. "\tH\t42", "WHISPER", "Anna Berg")
STUB.tick(1)
assert(#own.signups == 1, "Anna signed up")

NS.ShowPage("calls")
GC.PageMode("mine")
NS.Refresh()
local f = assert(NS.PageFrame("calls"))
assert(f.editLink:IsShown() and f.endLink:IsShown(), "Ändern beside Beenden")
f.editLink:Click()
assert(GC.PageMode() == "form" and f.formView:IsShown(), "the form")
assert(f.main:GetText() == "Speichern", f.main:GetText())
assert(f.titleBox:GetText() == "Hilfe bei Elite" and f.noteBox:GetText() == "am Turm" and f.art:GetValue() == "H", "the call's values")
assert(f.timeMode:GetValue() == "clock" and f.timeBox:GetText() == date("%H:%M", at), "its time")
assert(f.level.current == 30 and f.roleSteppers.S.current == 1 and f.roleSteppers.H.current == 1)
-- "Zurück": back to the own call, nothing changed
f.back:Click()
assert(GC.PageMode() == "mine" and GC.Own().rev == own.rev, "back to the own call")

-- the change: title, one more damage, the note; the time left as it was
f.editLink:Click()
f.titleBox:SetText("Hilfe bei den Elite-Ogern")
f.roleSteppers.S.plus:Click()
f.noteBox:SetText("am Turm, Westseite")
local rev = own.rev
sent = {}
f.main:Click()
own = GC.Own()
assert(GC.PageMode() == "mine", "back in the creator's view")
assert(own.id == id and own.rev ~= rev, "the same call, a new revision")
assert(own.title == "Hilfe bei den Elite-Ogern" and own.need.S == 2 and own.note == "am Turm, Westseite" and own.at == at)
assert(#own.signups == 1 and own.signups[1].r == "H", "the sign-ups stay")
STUB.tick(11)
local ea = assert(lastEA(), "the change went to the guild")
assert(ea.fields[1] == id and ea.fields[5] == "Hilfe bei den Elite-Ogern" and ea.fields[8] == "0/1/2" and ea.fields[9] == "0/1/0", table.concat(ea.fields, " "))

-- the time has come: a change that leaves it keeps it
STUB.tick(700)
assert(GC.Own() and GC.Own().at < GetServerTime())
f.editLink:Click()
f.noteBox:SetText("jetzt am Turm")
f.main:Click()
assert(GC.Own().note == "jetzt am Turm" and GC.Own().at == at, "the past time kept")
-- a new time must be ahead (a past "HH:MM" is tomorrow; a broken one is refused)
f.editLink:Click()
f.timeBox:SetText("99:99")
f.main:Click()
assert(GC.PageMode() == "form" and has(f.formHint:GetText(), "Uhrzeit fehlt oder ist falsch"), f.formHint:GetText())
f.timeMode.onPick("now")
f.main:Click()
assert(GC.Own().at == 0 and GC.PageMode() == "mine", "now: jetzt")
assert(time() - GC.Own().created <= 1, "switched to now: its life counts from now, not from when it was made")
-- nothing changed: no new revision
rev = GC.Own().rev
assert(GC.Edit({ art = "H", title = GC.Own().title, min = 30, need = GC.Own().need, note = GC.Own().note, at = 0 }))
assert(GC.Own().rev == rev, "no revision without a change")
-- a broken change is refused and leaves the call as it was
local ok, why = GC.Edit({ art = "H", title = "x", min = 30, need = { T = 0, H = 0, S = 0 }, at = 0 })
assert(not ok and has(why, "zusammen 1 bis 40") and GC.Own().title == "Hilfe bei den Elite-Ogern")

-- the others: a new revision of the same call changes it, without a second chat line
NS.CommSend = realSend
STUB.messages = {}
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tbeef\t1\tD\tsmcath\tCathedral\t38\t0\t1/1/3\t0/0/0\t0/0/0\tO\t-", "GUILD", "Anna Berg")
STUB.tick(2)
local lines = #STUB.messages
STUB.tick(11)   -- the receiver takes one EA per sender every 10 s
local later = GetServerTime() + 3600
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tbeef\t2\tD\tsmcath\tKloster\t40\t" .. later .. "\t1/1/2\t0/0/0\t0/0/0\tO\tum acht", "GUILD", "Anna Berg")
STUB.tick(2)
local c = GC.Get("anna berg")
assert(c and c.id == "beef" and c.title == "Kloster" and c.min == 40 and c.at == later and c.need.S == 2 and c.note == "um acht", "the revision taken")
assert(#STUB.messages == lines, "no second chat line")
