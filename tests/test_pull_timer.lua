-- Pull and break timer (Raid/PullTimer.lua, F-164, D-94): /amisia pull [Sekunden | stop] (3-60, the
-- setting pull.seconds), /amisia raidpause [Minuten | stop] (en break; 1-30, pull.minutes) and
-- /amisia pause <Minuten>; alone only here, in a raid the leader or an assistant, in a party the
-- leader; the client's countdown (C_PartyInfo.DoCountdown) when it has one and then one chat line,
-- else 5 4 3 2 1 "Pull!" in the chat; the break's three lines; never a pull in combat; the chat
-- lockdown stops it with one own line; the status line and its menu.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function lines()
    local out = {}
    for _, c in ipairs(STUB.chat) do out[#out + 1] = c.chan .. ":" .. c.text end
    return table.concat(out, " | ")
end
local PT = NS.PullTimer

STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local COUNT = {}
C_PartyInfo.DoCountdown = function(s) COUNT[#COUNT + 1] = s end
_G.UnitIsGroupAssistant = function() return STUB.assist == true end
local function reset()
    PT._reset()
    STUB.chat, STUB.messages, COUNT = {}, {}, {}
end

assert(NS.Get("pull.seconds") == 10 and NS.Get("pull.minutes") == 5, "the defaults")

---------------------------------------------------------------------------
-- alone: only here, no chat line, no client countdown
---------------------------------------------------------------------------
STUB.roster, STUB.leader = {}, true
reset()
NS.Dispatch("pull")
assert(said("Pull in 10 Sekunden (nur bei dir: du bist in keiner Gruppe)"), STUB.messages[1])
assert(#STUB.chat == 0 and #COUNT == 0, "nothing to others")
NS.ShowPage("overview")
local F = AmisiaFrame
STUB.tick(3)
assert(has(F.statusText:GetText(), "Pull in 7 s"), F.statusText:GetText())
STUB.tick(7.5)
assert(said("Pull!") and not PT.Running(), "over")
assert(not has(F.statusText:GetText(), "Pull in"), F.statusText:GetText())

---------------------------------------------------------------------------
-- a raid as leader: the client's countdown and one raid warning
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo" }, { name = "Anna Bergmann" } }
reset()
NS.Dispatch("pull 15")
assert(COUNT[1] == 15, "the client's countdown")
assert(lines() == "RAID_WARNING:Pull in 15 Sekunden", lines())
STUB.tick(16)
assert(lines() == "RAID_WARNING:Pull in 15 Sekunden", "no numbers next to the client's countdown: " .. lines())
assert(not PT.Running())
-- without the client's countdown: the chat counts the last five and says "Pull!"
local keep = C_PartyInfo.DoCountdown
C_PartyInfo.DoCountdown = nil
reset()
NS.Dispatch("pull")
STUB.tick(11)
assert(lines() == "RAID_WARNING:Pull in 10 Sekunden | RAID_WARNING:5 | RAID_WARNING:4 | RAID_WARNING:3 | RAID_WARNING:2 | RAID_WARNING:1 | RAID_WARNING:Pull!", lines())
C_PartyInfo.DoCountdown = keep
-- cancel: the client's countdown with 0, one line
reset()
NS.Dispatch("pull 20")
STUB.tick(2)
NS.Dispatch("pull stop")
assert(COUNT[1] == 20 and COUNT[2] == 0, "the countdown ended")
assert(has(lines(), "RAID_WARNING:Pull abgebrochen!") and not PT.Running(), lines())
NS.Dispatch("pull 0")
assert(said("Es läuft kein Pull-Timer."), STUB.messages[#STUB.messages])
-- out of range, a bad word
reset()
NS.Dispatch("pull 2")
assert(said("Pull-Timer: 3 bis 60 Sekunden.") and not PT.Running())
NS.Dispatch("pull 61")
NS.Dispatch("pull bald")
assert(said("Aufruf: /amisia pull [Sekunden | stop]") and #STUB.chat == 0)

---------------------------------------------------------------------------
-- who: an assistant may, a raider not; a party: the leader, party chat; never a pull in combat
---------------------------------------------------------------------------
STUB.leader, STUB.assist = false, false
reset()
NS.Dispatch("pull")
assert(said("Nur als Leiter oder Assistent") and #STUB.chat == 0 and #COUNT == 0)
STUB.assist = true
NS.Dispatch("pull")
assert(COUNT[1] == 10 and has(lines(), "RAID_WARNING:Pull in 10 Sekunden"), lines())
STUB.assist, STUB.leader = false, true
local realRaid, realGroup = _G.IsInRaid, _G.IsInGroup
_G.IsInRaid = function() return false end
_G.IsInGroup = function(cat) return cat ~= LE_PARTY_CATEGORY_INSTANCE and #STUB.roster > 0 end
reset()
NS.Dispatch("pull")
assert(lines() == "PARTY:Pull in 10 Sekunden", lines())
STUB.leader = false
reset()
NS.Dispatch("pull")
assert(said("Nur als Gruppenleiter") and #STUB.chat == 0)
STUB.leader = true
_G.IsInRaid, _G.IsInGroup = realRaid, realGroup
reset()
STUB.combat = true
NS.Dispatch("pull")
assert(said("Nicht im Kampf") and #STUB.chat == 0 and #COUNT == 0)
STUB.combat = false
-- a fight starts during the countdown: the timer ends here (the pull happened)
C_PartyInfo.DoCountdown = nil
reset()
NS.Dispatch("pull")
STUB.tick(2)
STUB.fire("PLAYER_REGEN_DISABLED")
STUB.tick(10)
assert(lines() == "RAID_WARNING:Pull in 10 Sekunden", "no numbers after the pull: " .. lines())
C_PartyInfo.DoCountdown = keep

---------------------------------------------------------------------------
-- the chat lockdown of a boss fight: not started, or stopped with one own line
---------------------------------------------------------------------------
reset()
STUB.chatLock = true
NS.Dispatch("pull")
assert(said("Der Chat ist im Bosskampf gesperrt.") and #STUB.chat == 0 and not PT.Running())
STUB.chatLock = false
C_PartyInfo.DoCountdown = nil
reset()
NS.Dispatch("pull")
STUB.tick(3)
STUB.chatLock = true
STUB.tick(3)
assert(said("Timer angehalten: der Chat ist im Bosskampf gesperrt.") and not PT.Running(), STUB.messages[1])
assert(lines() == "RAID_WARNING:Pull in 10 Sekunden", lines())
STUB.chatLock = false
C_PartyInfo.DoCountdown = keep

---------------------------------------------------------------------------
-- the break: the end's time, one minute before, the end; also in combat; /amisia pause <Minuten>
---------------------------------------------------------------------------
reset()
NS.Dispatch("raidpause")
local til = date("%H:%M", STUB.now + 300)
assert(lines() == "RAID_WARNING:Pause: 5 Minuten (bis " .. til .. ")", lines())
STUB.tick(10)
assert(has(F.statusText:GetText(), "Pause: noch 4:50"), F.statusText:GetText())
STUB.tick(225)
assert(lines() == "RAID_WARNING:Pause: 5 Minuten (bis " .. til .. ")", "nothing until a minute is left")
STUB.tick(10)
assert(has(lines(), "RAID_WARNING:Pause: noch 1 Minute"), lines())
STUB.tick(60)
assert(has(lines(), "RAID_WARNING:Pause vorbei") and not PT.Running(), lines())
-- "/amisia pause 2" is the break, "/amisia pause" alone still the recording's switch
reset()
local was = NS.IsEnabled()
NS.Dispatch("pause 2")
assert(NS.IsEnabled() == was and PT.Running() == "break" and has(lines(), "Pause: 2 Minuten"), lines())
NS.Dispatch("pause stop")
assert(has(lines(), "Pause abgebrochen") and not PT.Running())
NS.Dispatch("pause")
assert(NS.IsEnabled() ~= was, "the recording's switch")
NS.SetEnabled(was)
-- a one-minute break says no "noch 1 Minute"; in combat it goes; English word "break"
reset()
STUB.combat = true
NS.Dispatch("break 1")
STUB.combat = false
STUB.tick(61)
assert(lines():find("Pause: 1 Minute (bis", 1, true) and not has(lines(), "noch 1 Minute") and has(lines(), "Pause vorbei"), lines())
NS.Dispatch("raidpause 31")
assert(said("Pause: 1 bis 30 Minuten."))
-- a pull during a break replaces it; a break during a pull ends the pull
reset()
NS.Dispatch("raidpause")
NS.Dispatch("pull")
assert(PT.Running() == "pull")
NS.Dispatch("raidpause")
assert(PT.Running() == "break" and COUNT[#COUNT] == 0, "the pull's countdown ended")
PT._reset()

---------------------------------------------------------------------------
-- the status line's menu: start and cancel, the settings' numbers, the reason when it may not
---------------------------------------------------------------------------
NS.Set("pull.seconds", 15)
reset()
local function entry(part)
    for _, e in ipairs(F.headMenu()) do if has(e[1], part) then return e end end
end
local e = entry("Pull-Timer (15 s)")
assert(e and e[2], "the pull entry with the setting's seconds")
e[2]()
assert(COUNT[1] == 15 and PT.Running() == "pull")
e = entry("Pull-Timer abbrechen")
assert(e and e[2], "while it runs: cancel")
e[2]()
assert(not PT.Running())
e = entry("Pause (5 min)")
assert(e and e[2])
STUB.leader = false
e = entry("Pull-Timer (15 s)")
assert(e and e[2] == nil and e.tip == "Nur als Leiter oder Assistent", "grey with the reason for a raider")
STUB.leader = true
NS.Reset("pull.seconds")
print("pull timer ok")
