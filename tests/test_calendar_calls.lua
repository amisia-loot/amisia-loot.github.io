-- F-218 (D-143), F-219 (D-144): the guild's running calls stand on Amisia's calendar sheet (the own and the
-- others', in their own colour), one for "jetzt" tonight with "jetzt" instead of a time; the inset names art,
-- creator, level and roles, "Zum Aufruf" opens the page Aufrufe at that call (the own one: its creator's view),
-- "Für Discord" and "Anmelden ..." stay hidden. Nothing goes into the game calendar.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local GC = NS.GuildCalls

STUB.player, STUB.class, STUB.level = "Vuloo", "PRIEST", 40
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 40 },
    { name = "Anna Berg", class = "WARRIOR", rank = 3, level = 42 },
    { name = "Bert Stein", class = "MAGE", rank = 4, level = 38 },
}
local cal = STUB.calendar({ events = {}, create = true, maxDays = 90 })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

local now = os.date("*t", STUB.now)
local annaAt = os.time({ year = now.year, month = now.month, day = now.day + 1, hour = 20, min = 30 })
-- Anna: a dungeon tomorrow 20:30; Bert: help "jetzt" (tonight, "jetzt")
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tabcd\t1\tD\tsmcath\tCathedral\t38\t" .. annaAt .. "\t1/1/3\t0/1/1\t0/0/1\tO\tQuest Herod", "GUILD", "Anna Berg")
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tbeef\t1\tH\t-\tHilfe bei Elite\t30\t0\t0/1/1\t0/0/0\t0/0/0\tO\t-", "GUILD", "Bert Stein")
STUB.tick(2)
assert(GC.Count() == 2, "both calls heard")
-- the own call in an hour
local ownAt = STUB.now + 3600
assert(GC.Create({ art = "H", title = "Ruf der Elite", min = 30, need = { T = 0, H = 1, S = 1 }, at = ownAt }))
STUB.tick(1)

NS.SignupLoadTerms(); STUB.tick(1)
NS.ShowCalendar(NS.NightOf(annaAt))
STUB.tick(2)
local P = NS.PageFrame("calendar")
local function cellOf(key)
    for _, c in ipairs(P.cells) do if c.info.key == key then return c end end
end
local name = GC.DungeonName("smcath")
local ca = assert(cellOf(NS.NightOf(annaAt)), "Anna's day on the sheet")
local found
for _, fs in ipairs(ca.lines) do if fs:IsShown() and has(fs:GetText(), name:sub(1, 6)) then found = fs end end
assert(found, "Anna's call on its day: " .. tostring(ca.lines[2]:GetText()))
local r, g, b = unpack(ca.dot.vertexColor)
assert(math.abs(r - 0.86) < 0.01 and math.abs(g - 0.68) < 0.01 and math.abs(b - 1) < 0.01, "the dot in the calls' colour")
-- Bert's call for "jetzt" stands tonight with "jetzt"
local tonight = NS.NightOf(time())
NS.ShowCalendar(tonight)
STUB.tick(1)
local ct = assert(cellOf(tonight))
ct:Click(); STUB.tick(1)
local jetzt
for _, bt in ipairs(P.terms) do if bt:IsShown() and has(bt.text:GetText(), "jetzt Hilfe bei") then jetzt = true end end
assert(jetzt, "the call for jetzt tonight with jetzt")
-- the own call on its day
NS.ShowCalendar(NS.NightOf(ownAt))
STUB.tick(1)
local co = assert(cellOf(NS.NightOf(ownAt)))
co:Click(); STUB.tick(1)
local idx
for i, bt in ipairs(P.terms) do if bt:IsShown() and has(bt.text:GetText(), date("%H:%M", ownAt) .. " Ruf der Elite") then idx = i end end
assert(idx, "the own call on its day with its time")
P.terms[idx]:Click(); STUB.tick(1)
assert(has(P.info:GetText(), "Dein Aufruf"), P.info:GetText())
-- "Zum Aufruf" of the own call: the creator's view
P.toCall:Click(); STUB.tick(1)
assert(NS.CurrentPage() == "calls" and GC.PageMode() == "mine", "the own call's view")
GC.PageMode("list")

-- Anna's call chosen: the inset, no sign-up and no Discord text, "Zum Aufruf"
NS.ShowCalendar(NS.NightOf(annaAt))
STUB.tick(1)
ca:Click(); STUB.tick(1)
idx = nil
for i, bt in ipairs(P.terms) do if bt:IsShown() and has(bt.text:GetText(), name:sub(1, 6)) then idx = i end end
assert(idx, "Anna's call in the day's list")
assert(has(P.terms[idx].text:GetText(), "20:30"), P.terms[idx].text:GetText())
P.terms[idx]:Click(); STUB.tick(1)
local info = P.info:GetText()
assert(P.info:IsShown() and has(info, "Aufruf (Dungeon)") and has(info, "Anna Berg") and has(info, "Stufe ab:|r 38")
    and has(info, "Tank 0/1 · Heiler 0/1 · Schaden 1/3") and has(info, "Quest Herod")
    and has(info, "Anmelden auf der Seite Aufrufe."), info)
assert(not P.signup:IsShown() and not P.discord:IsShown() and not P.lineup:IsShown(), "no sign-up, no Discord text")
assert(P.toCall:IsShown(), "Zum Aufruf")
-- signed up: the dot turns green and the inset says so
local realSend = NS.CommSend
NS.CommSend = function() return true end
GC.SignUp("anna berg", "H")
STUB.tick(1); NS.Refresh()
NS.CommSend = realSend
assert(has(P.info:GetText(), "Du bist angemeldet als Heiler."), P.info:GetText())
local dr, dg = unpack(P.terms[idx].dot.vertexColor)
assert(math.abs(dr - 0.31) < 0.01 and math.abs(dg - 0.75) < 0.01, "the dot green when signed up")
-- "Zum Aufruf": the page Aufrufe at Anna's call
P.toCall:Click(); STUB.tick(1)
assert(NS.CurrentPage() == "calls" and GC.Focus() == "anna berg", "the page Aufrufe at the call")

-- nothing went into the game calendar
assert(#(cal.made or {}) == 0, "no call in the game calendar")

-- the call ends (EX): gone from the sheet
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EX\tabcd", "GUILD", "Anna Berg")
STUB.tick(2)
NS.ShowCalendar(NS.NightOf(annaAt))
STUB.tick(1)
for _, fs in ipairs(cellOf(NS.NightOf(annaAt)).lines) do
    assert(not has(fs:GetText(), name:sub(1, 6)), "an ended call leaves the sheet")
end
