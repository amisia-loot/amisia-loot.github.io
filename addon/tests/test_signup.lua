-- Part H of the raid lineup (Raid/Signup.lua, UI/Signup.lua): the raider's side. The dates come
-- from the game calendar 40-70 s after the login (no event is opened); the card "Raid-Anmeldung"
-- shows the next three with the own sign-up; the window signs up, tentative or off with a role and a
-- note (40 characters, no codes); /amisia anmelden; the chat line with "Gesendet." or "Kein Offizier
-- online"; the saved sign-ups (pruned on load); a raider sees no list of others; not in a guild,
-- no dates. Then the same account's officer (Vulo Hunt) takes the sign-ups of Vulo Pala without a
-- message, his own too, and gets one chat line when a placed player signs off.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function sent(kind)
    local out = {}
    for _, m in ipairs(STUB.addonTries) do
        if m.text:sub(2, 3) == kind then out[#out + 1] = m end
    end
    return out
end
local function fields(m)
    local out = {}
    for x in (m.text:sub(5) .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = x end
    return out
end

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER" },
    { name = "Vulo Pala", rank = 3, class = "PALADIN" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
}
local cal = STUB.calendar({ loaded = false, events = {
    { title = "Molten Core", days = 1, eventType = 0, id = 12 },
    { title = "Gildentreffen", days = 3, eventType = 3, id = 13 },
    { title = "Onyxia", days = 5, eventType = 0, id = 14 },
    { title = "Zul'Gurub", days = 6, eventType = 0, id = 15 },
} })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.ShowPage and not NS.IsOfficerView(), "a raider")

-- the login: the dates come 40-70 s later; the calendar is only listed, never opened
STUB.fire("PLAYER_LOGIN")
STUB.tick(30)
assert(NS.SignupTerms() == nil, "not before 40 s")
STUB.tick(45)
local terms = NS.SignupTerms()
assert(terms and #terms == 4 and terms[1].title == "Molten Core", "the dates by time")
for _, c in ipairs(cal.calls) do assert(c ~= "OpenEvent", "a raider never opens an event") end
assert(#sent("AN") == 0 and #sent("AQ") == 0, "nothing signed up yet, a raider does not ask")

-- the card on the overview: the next three, each "noch offen"
NS.ShowPage("overview")
local function card()
    for _, c in ipairs(NS.OverviewPageFrame().cards) do
        if c:IsShown() and c.title:GetText() == "Raid-Anmeldung" then return c end
    end
end
local c = card()
assert(c, "the card for a raider")
assert(has(c.line1:GetText(), "Molten Core · ") and has(c.line1:GetText(), "noch offen"), c.line1:GetText())
assert(has(c.line2:GetText(), "Gildentreffen") and has(c.line2:GetText(), "Onyxia") and not has(c.line2:GetText(), "Zul'Gurub"), c.line2:GetText())
assert(c.button:IsShown() and c.button:GetText() == "Anmelden")
-- the lineup page is not there for a raider
assert(not NS.Visible(NS.Panel("lineup")), "no list of who signed up")

-- the window: the next raid date, the role from the class, the note, three buttons
c.button:Click()
local F = NS._signupUI.frame()
assert(F and F:IsShown(), "the window")
assert(has(F.pick.label:GetText(), "Molten Core") and has(F.state:GetText(), "Deine Anmeldung: ") and has(F.state:GetText(), "noch offen"))
local on
for _, b in ipairs(F.roles) do if b.on then on = b.role end end
assert(on == "H", "a paladin: healer")
assert(has(F.hint:GetText(), "Für alle Offiziere sichtbar."))
assert(F.calHint:IsShown() and has(F.calHint:GetText(), "Bitte auch im Kalender eintragen"), "part H3 is not built: the player signs up there too")
F.roles[1]:Click()   -- T
F.roles[2]:Click()   -- H again
F.note:SetText("|cffff0000rot|r " .. ("x"):rep(100))
STUB.messages = {}
F.maybe:Click()
local night = terms[1].night
local rec = AmisiaDB.signup.chars["Vulo Pala"][night]
assert(rec and rec.s == "V" and rec.r == "H" and rec.e == "12", "saved")
assert(#rec.w <= 40 and not has(rec.w, "|") and has(rec.w, "rot xxx"), rec.w)
assert(said("Raid-Anmeldung: ") and said(" Molten Core · vorläufig als Heiler. Gesendet."), STUB.messages[1])
STUB.tick(1)
local an = sent("AN")
assert(#an == 1 and an[1].chan == "GUILD", "one message to the guild")
local fl = fields(an[1])
assert(fl[1] == night and fl[2] == "V" and fl[3] == "H" and fl[4] == "PALADIN" and fl[6] == "12" and fl[7] == rec.w, an[1].text)
assert(not has(an[1].text, "|"), "no codes in the message")
assert(has(F.state:GetText(), "vorläufig (H)"))
assert(#STUB.chat == 0, "nothing in a chat channel: the note never")
NS.Refresh()
assert(has(card().line1:GetText(), "vorläufig (H)"), card().line1:GetText())

-- the command: off for the next date, then healer with a note; no officer online
STUB.guild[1].online = false
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
STUB.messages = {}
NS.Dispatch("anmelden ab")
STUB.tick(1)
assert(AmisiaDB.signup.chars["Vulo Pala"][night].s == "X", "signed off")
assert(said("Molten Core · abgemeldet. Kein Offizier online: Amisia schickt es, sobald einer kommt."), STUB.messages[1])
STUB.tick(11)
STUB.messages = {}
NS.Dispatch("signup h komme 20:15")
STUB.tick(1)
rec = AmisiaDB.signup.chars["Vulo Pala"][night]
assert(rec.s == "A" and rec.r == "H" and rec.w == "komme 20:15", "healer with a note")
assert(said("angemeldet als Heiler."))
STUB.messages = {}
NS.Dispatch("anmelden x")
assert(said("Aufruf: /amisia anmelden"), "usage")
-- 4 nights at most per character
for i = 2, 4 do
    assert(NS.SignupSet(terms[i], "A", "H"))
end
local ok, why = NS.SignupSet({ night = NS.NightOf(time() + 8 * 86400), at = time() + 8 * 86400, title = "Fünfter" }, "A", "H")
assert(not ok and has(why, "Höchstens 4"), tostring(why))
STUB.guild[1].online = true
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

-- saved: pruned on load (past nights, bad fields, 4 nights, 12 characters)
local saved = { v = 1, sent = 5, chars = {
    ["Vulo Pala"] = AmisiaDB.signup.chars["Vulo Pala"],
    ["Alt Eins"] = { ["2020-01-01"] = { s = "A", t = 5 }, [night] = { s = "Q", t = 5 } },
    ["Bad|Name"] = { [night] = { s = "A", t = 5 } },
} }
for i = 1, 14 do saved.chars["Twink" .. string.char(64 + i)] = { [night] = { s = "A", t = 100 + i, r = "Z", w = "|cffffffffx|r" } } end
local root = { signup = saved }
NS.SignupLoaded(root)
local n = 0
for name, map in pairs(root.signup.chars) do
    n = n + 1
    assert(not name:find("|", 1, true), "bad names go")
    for _, r in pairs(map) do assert(r.s ~= "Q" and (r.r == nil or r.r == "H"), "bad fields go") end
end
assert(n == 12 and root.signup.chars["Vulo Pala"] and not root.signup.chars["Alt Eins"], "12 characters, past nights gone")
assert(root.signup.chars["TwinkN"][night].w == "x", "codes gone")
NS.SignupLoaded(AmisiaDB)
NS.SignupLoaded(AmisiaDB)

-- not in a guild: no card text but the reason, the command sends nothing
STUB.inGuild = false
STUB.messages = {}
local before = #sent("AN")
NS.Dispatch("anmelden ab")
assert(said("Nur in einer Gilde."))
assert(#sent("AN") == before)
NS.Refresh()
assert(has(card().line1:GetText(), "Nur in einer Gilde"))
STUB.inGuild = true
-- no dates
cal.set({})
STUB.fire("CALENDAR_UPDATE_GUILD_EVENTS")
NS.Refresh()
assert(has(card().line1:GetText(), "Keine Raidtermine in den nächsten 14 Tagen."), card().line1:GetText())
cal.set({ { title = "Molten Core", days = 1, eventType = 0, id = 12 }, { title = "Onyxia", days = 5, eventType = 0, id = 14 } })
STUB.fire("CALENDAR_UPDATE_GUILD_EVENTS")
assert(cal.writes == 0, "no calendar write function")

---------------------------------------------------------------------------
-- The same account, the officer: Vulo Hunt takes Vulo Pala's sign-ups without a message
---------------------------------------------------------------------------
STUB.player, STUB.class, STUB.officer = "Vulo Hunt", "HUNTER", true
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.Set("ui.view", "officer")
assert(NS.LineupAllowed(), "an officer")
local tries = #STUB.addonTries
assert(NS.SignupTakeOwn() >= 1)
local function e(name, key)
    for _, x in ipairs((NS.LineupNight(key or night) or { list = {} }).list) do if x.n == name then return x end end
end
local pala = e("Vulo Pala")
assert(pala and pala.f == "A" and pala.st == "A" and pala.r == "H" and pala.w == "komme 20:15", "taken over")
assert(#STUB.addonTries == tries, "without a message")
assert(NS.SignupTakeOwn() == 0, "once")
-- his own sign-up: tank with a note, in his lineup at once
STUB.messages = {}
NS.ShowSignup(night)
F = NS._signupUI.frame()
F.roles[1]:Click()
F.note:SetText("komme 20:15")
F.yes:Click()
local hunt = e("Vulo Hunt")
assert(hunt and hunt.as == "A" and hunt.r == "T" and hunt.w == "komme 20:15" and hunt.f == "A", "the own sign-up")
assert(said("angemeldet als Tank. Gesendet.") or said("angemeldet als Tank. Kein Offizier online"), STUB.messages[1])
-- the other character in the window and on the card
assert(has(F.alts:GetText(), "Vulo Pala: ") and has(F.alts:GetText(), "angemeldet (H)"), F.alts:GetText())
-- the lineup page shows the source, the role and the note mark
NS.ShowLineup("match", night)
local f = NS.LineupPageFrame()
local function rowOf(name)
    for _, r in ipairs(f.mlist.rows) do
        if r:IsShown() and r.item and r.item.e.n == name then return r end
    end
end
assert(has(rowOf("Vulo Hunt").src:GetText(), "A") and has(rowOf("Vulo Hunt").r:GetText(), "T") and has(rowOf("Vulo Hunt").name:GetText(), " *"))
assert(has(f.calLine:GetText(), "Liste 0 · Kalender 0 · Amisia 2"), f.calLine:GetText())
-- a pasted Discord list: Vulo Pala "Heiler"; he signs off in Amisia afterwards: "abgemeldet" with the hint
NS.SetLineupText("Heiler\nVulo Pala", night)
for i, x in ipairs(NS.LineupNight(night).list) do
    if x.n == "Vulo Pala" then NS.LineupMove(night, i, 2) end
end
STUB.tick(5)
AmisiaDB.signup.chars["Vulo Pala"][night] = { s = "X", r = "H", t = time() }
STUB.messages = {}
NS.Refresh()
pala = e("Vulo Pala")
assert(pala.st == "X" and pala.a and not pala.g and pala.d == "A", "signed off, out of the group")
assert(said("Aufstellung: Vulo Pala hat sich abgemeldet (war Gruppe 2)."), STUB.messages[1])
assert(has(rowOf("Vulo Pala").state:GetText(), "abgemeldet") and has(rowOf("Vulo Pala").act:GetText(), "Discord: angemeldet"))
-- lineup.signups off: nothing taken
NS.Set("lineup.signups", false)
AmisiaDB.signup.chars["Vulo Pala"][night] = { s = "A", r = "H", t = time() + 1 }
assert(NS.SignupTakeOwn() == 0, "off")
NS.Set("lineup.signups", true)
print("signup ok")
