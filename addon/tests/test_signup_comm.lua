--[[clients Vulo_Hunt Vulo_Pala Bob_Eisherz Kim_Fremd]]
-- The raid sign-up between clients (AN / AQ, Raid/Signup.lua, Core/Comm.lua): a raider's click
-- reaches the officer's lineup (source Amisia, role, note); the name is the sender, a field is never
-- a name; malformed fields, a second message for a night within 10 s, a fifth night, a night too far
-- ahead and a sender outside the guild are dropped; an officer's question AQ after the login is
-- answered by whisper, a member's is not; the sign-ups go again once after a login (not after a
-- /reload within 30 minutes) and once per officer in 10 minutes.
local HUNT, PALA, BOB, KIM = "Vulo Hunt", "Vulo Pala", "Bob Eisherz", "Kim Fremd"
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

BUS.setGuild({ { name = HUNT, rank = 2 }, { name = PALA, rank = 3 }, { name = BOB, rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Hunt"
        STUB.class = ({ ["Vulo Hunt"] = "HUNTER", ["Vulo Pala"] = "PALADIN", ["Bob Eisherz"] = "WARRIOR", ["Kim Fremd"] = "MAGE" })[STUB.player]
        STUB.calendar({ events = { { title = "Molten Core", days = 1, id = 12 }, { title = "Onyxia", days = 2, id = 13 },
            { title = "Zul'Gurub", days = 3, id = 14 }, { title = "AQ20", days = 4, id = 15 }, { title = "Naxx", days = 5, id = 16 } } })
        STUB.fire("PLAYER_ENTERING_WORLD")
        return true]])
end
C(KIM, "STUB.inGuild = false")
BUS.tick(12)
C(HUNT, "NS.Set('ui.view', 'officer')")
assert(C(HUNT, "NS.LineupAllowed()") == true, "Hunt is an officer")
assert(C(PALA, "NS.LineupAllowed()") == false, "Pala is not")

local function night(i) return C(PALA, "local t = NS.Cal.Events() return t[" .. i .. "].night") end
local N1 = night(1)
local function entry(name, key)
    return C(HUNT, ("local n = NS.LineupNight(%q) if not n then return false end for _, e in ipairs(n.list) do if e.n == %q then return e end end return false"):format(key or N1, name))
end

-- a click: AN to the guild, the officer's lineup
C(PALA, "NS.SignupLoadTerms()")
BUS.tick(1)
local ok, line = C(PALA, "return NS.SignupSet(NS.SignupTerms()[1], 'A', 'H', 'komme 20:15')")
assert(ok == true and has(line, "Gesendet."), tostring(line))
BUS.tick(2)
assert(BUS.count({ kind = "AN", sender = PALA, chan = "GUILD" }) == 1)
local e = entry(PALA)
assert(e and e.f == "A" and e.st == "A" and e.r == "H" and e.w == "komme 20:15" and e.c == "PALADIN", "in the officer's lineup")
assert(entry(PALA, N1) and not entry(BOB), "only the sender")
-- Bob (a member, no officer) keeps nothing
assert(C(BOB, "NS.LineupNight(" .. ("%q"):format(N1) .. ") == nil"), "a raider keeps no list")

-- a second message for the night within 10 s is dropped (keyed gap); later it counts
local function send(from, fields, chan, target)
    local list = {}
    for _, f in ipairs(fields) do list[#list + 1] = ("%q"):format(f) end
    C(from, ("return NS.CommSend('AN', { %s }, %q, %s)"):format(table.concat(list, ", "), chan or "GUILD", target and ("%q"):format(target) or "nil"))
end
local now = C(PALA, "math.floor(time())")
send(PALA, { N1, "X", "H", "PALADIN", tostring(now + 1), "12", "-" })
BUS.tick(1)
assert(entry(PALA).st == "A", "within 10 s of the first: dropped")
BUS.tick(10)
send(PALA, { N1, "V", "H", "PALADIN", tostring(now + 20), "12", "-" })
BUS.tick(1)
assert(entry(PALA).st == "V" and entry(PALA).w == nil, "a later one counts")

-- malformed fields drop the whole message
BUS.tick(11)
for _, bad in ipairs({
    { N1, "A", "Z", "PALADIN", tostring(now + 40), "12", "-" },       -- role
    { N1, "A", "H", "BARD", tostring(now + 40), "12", "-" },          -- class
    { N1, "Q", "H", "PALADIN", tostring(now + 40), "12", "-" },       -- status
    { "morgen", "A", "H", "PALADIN", tostring(now + 40), "12", "-" }, -- night
    { N1, "A", "H", "PALADIN", "x", "12", "-" },                      -- epoch
}) do
    send(PALA, bad)
    BUS.tick(11)
end
assert(entry(PALA).st == "V", "nothing malformed taken")
-- a note: codes are cut by the receiver, at most 40
send(PALA, { N1, "A", "H", "PALADIN", tostring(now + 60), "-", ("ä"):rep(50) })
BUS.tick(1)
assert(entry(PALA).st == "A" and #entry(PALA).w <= 40, "the note cut to 40 bytes")
-- the future: the officer takes "now"
BUS.tick(11)
send(PALA, { N1, "V", "H", "PALADIN", tostring(now + 99999), "-", "-" })
BUS.tick(1)
assert(entry(PALA).st == "V" and entry(PALA).ag <= C(HUNT, "time()"), "a clock ahead counts as now")

-- outside the guild: a whisper from Kim is dropped; a field never names someone else
send(KIM, { N1, "A", "T", "MAGE", tostring(now + 70), "-", "-" }, "WHISPER", HUNT)
BUS.tick(2)
assert(not entry(KIM), "not a guild member")
-- too far ahead and a fifth night
local far = C(HUNT, "NS.NightOf(time() + 20 * 86400)")
send(BOB, { far, "A", "M", "WARRIOR", tostring(now + 70), "-", "-" })
BUS.tick(1)
assert(not entry(BOB, far), "too far ahead")
for i = 1, 5 do
    send(BOB, { night(i), "A", "M", "WARRIOR", tostring(now + 80 + i), "-", "-" })
    BUS.tick(1)
end
local nights = C(HUNT, "#NS.LineupSignupNights('Bob Eisherz')")
assert(nights == 4, "4 nights per sender: " .. tostring(nights))
assert(not entry(BOB, night(5)), "the fifth is dropped")

-- the officer asks after his login (AQ); Pala answers by whisper with her sign-ups, once in 10 minutes
C(PALA, "NS.SignupSet(NS.SignupTerms()[2], 'A', 'H')")
BUS.tick(12)
C(HUNT, "AmisiaDB.lineup = nil")
assert(C(HUNT, "NS.SignupAsk()") == true)
assert(C(HUNT, "NS.SignupAsk()") == false, "once per session")
BUS.tick(25)
assert(BUS.count({ kind = "AQ", sender = HUNT, chan = "GUILD" }) == 1)
assert(BUS.count({ kind = "AN", sender = PALA, chan = "WHISPER", target = HUNT }) == 2, "the answer: both nights")
assert(entry(PALA) and entry(PALA, night(2)), "the officer has them again")
assert(BUS.count({ kind = "AN", sender = BOB, chan = "WHISPER" }) == 0, "Bob has no sign-ups of his own")
-- a member's question (Bob) is not answered
local before = BUS.count({ kind = "AN", sender = PALA, chan = "WHISPER" })
C(BOB, "NS.CommSend('AQ', { 'O', '0' }, 'GUILD')")
BUS.tick(25)
assert(BUS.count({ kind = "AN", sender = PALA, chan = "WHISPER" }) == before, "only to a verified officer")
-- the officer again within 10 minutes: no second answer
C(HUNT, "NS.CommSend('AQ', { 'O', '0' }, 'GUILD')")
BUS.tick(40)
assert(BUS.count({ kind = "AN", sender = PALA, chan = "WHISPER" }) == before, "once in 10 minutes")

-- the re-send after the login: once, not again after a /reload within 30 minutes
local g = BUS.count({ kind = "AN", sender = PALA, chan = "GUILD" })
assert(C(PALA, "NS.SignupResend()") == 2)
assert(C(PALA, "NS.SignupResend()") == 0, "once per session")
BUS.tick(15)
assert(BUS.count({ kind = "AN", sender = PALA, chan = "GUILD" }) == g + 2)
BUS.reload(PALA)
C(PALA, "STUB.calendar({ events = { { title = 'Molten Core', days = 1, id = 12 } } })")
assert(C(PALA, "NS.SignupResend()") == 0, "not again within 30 minutes")
-- Kim (no guild) sends nothing at all
assert(C(KIM, "NS.SignupResend()") == 0 and BUS.count({ kind = "AN", sender = KIM, chan = "GUILD" }) == 0)
-- review 2026-10-10: a second click for the same night within 10 s is not lost (the officer drops a
-- second AN within 10 s): it waits until 11 s after the first went
C(HUNT, "AmisiaDB.lineup = nil")
C(BOB, "NS.SignupLoadTerms()")
BUS.tick(1)
C(BOB, "NS.SignupSet(NS.SignupTerms()[1], 'A', 'M')")
BUS.tick(2)
assert(entry(BOB) and entry(BOB).st == "A")
C(BOB, "NS.SignupSet(NS.SignupTerms()[1], 'X', 'M')")
BUS.tick(2)
assert(entry(BOB).st == "A", "still waiting")
BUS.tick(10)
assert(entry(BOB).st == "X", "the second click arrived")
for _, name in ipairs(CLIENTS) do
    assert(C(name, "#STUB.chat") == 0, "no chat line to others: " .. name)
end
print("signup comm ok")
