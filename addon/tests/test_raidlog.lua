-- Raid log: boss kills and wipes from the encounter events, who was there at the kill (read after
-- the restriction of the fight lifts), BOSS_KILL, s.pull across a /reload, the loot window fallback,
-- kills by hand, ns.KillFor, the event trace, /amisia log and /amisia boss.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local function lastKill(s) return s.kills[#s.kills] end
local function names(list) return table.concat(list or {}, ",") end

STUB.roster = {
    { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
    { name = "Chorf", class = "WARRIOR" }, { name = "Bob", class = "MAGE", zone = "Shattrath" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording")
assert(type(s.kills) == "table" and type(s.bench) == "table" and type(s.outside) == "table", "the new fields of a raid")
assert(s.members.Fraktur and not s.members.Bob, "Bob waits outside")
assert(s.outside.Bob == s.members.Fraktur.last, "the group outside is remembered: " .. tostring(s.outside.Bob))

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local sec
for _, x in ipairs(NS.schema) do if x.key == "raidlog" then sec = x end end
assert(sec and sec.label == "Raid-Log" and sec.order == 12 and not sec.officer, "settings section raidlog")
local track, lootKills = NS.SettingItem("raidlog.track"), NS.SettingItem("raidlog.lootKills")
assert(track and track.type == "toggle" and track.default == true and track.label == "Bosskämpfe aufzeichnen" and not track.officer and not track.expert)
assert(lootKills and lootKills.type == "toggle" and lootKills.default == true and lootKills.expert, "lootKills for experts")

---------------------------------------------------------------------------
-- a kill: ENCOUNTER_START, ENCOUNTER_END, who was there after 1 s
---------------------------------------------------------------------------
STUB.tick(10)
STUB.fire("ENCOUNTER_START", 601, "Hochkriegsfürst Naj'entus", 4, 25)
local started = STUB.now
assert(s.pull and s.pull.enc == 601 and s.pull.name == "Hochkriegsfürst Naj'entus" and s.pull.start == started
    and s.pull.size == 25 and s.pull.diff == 4, "the running attempt")
STUB.tick(192)
STUB.fire("ENCOUNTER_END", 601, "Hochkriegsfürst Naj'entus", 4, 25, 1, {})
assert(s.pull == nil, "the attempt is over")
assert(#s.kills == 1, #s.kills)
local k = s.kills[1]
assert(k.enc == 601 and k.name == "Hochkriegsfürst Naj'entus" and k.ok == true and k.src == "enc", "a kill")
assert(k.start == started and k.t == STUB.now and k.t - k.start == 192, "with its length")
assert(k.size == 25 and k.diff == 4 and k.n == 3, "size, difficulty and head count")
assert(k.wait == true and k.who == nil, "who is read after the fight")
STUB.tick(1)
assert(k.wait == nil and names(k.who) == "Chorf,Fraktur,Vuloo", names(k.who))

---------------------------------------------------------------------------
-- a wipe: only the head count
---------------------------------------------------------------------------
STUB.tick(200)
STUB.fire("ENCOUNTER_START", 602, "Supremus", 4, 25)
STUB.tick(121)
STUB.fire("ENCOUNTER_END", 602, "Supremus", 4, 25, 0)
local w = lastKill(s)
assert(#s.kills == 2 and w.ok == false and w.enc == 602 and w.t - w.start == 121, "a wipe")
assert(w.who == nil and not w.wait and w.n == 3, "a wipe keeps the number, no names")
STUB.tick(5)
assert(w.who == nil, "and never reads names")
local kills, wipes, bosses = NS.KillCount(s)
assert(kills == 1 and wipes == 1 and bosses == 1, ("%s %s %s"):format(kills, wipes, bosses))

---------------------------------------------------------------------------
-- BOSS_KILL alone, and with ENCOUNTER_END after or before it: one entry
---------------------------------------------------------------------------
STUB.tick(300)
STUB.fire("BOSS_KILL", 603, "Schattenmond")
local bk = lastKill(s)
assert(#s.kills == 3 and bk.src == "kill" and bk.ok and bk.enc == 603 and bk.start == bk.t and bk.wait, "BOSS_KILL alone")
STUB.tick(1)
assert(names(bk.who) == "Chorf,Fraktur,Vuloo")
STUB.fire("ENCOUNTER_END", 603, "Schattenmond", 4, 25, 1)
assert(#s.kills == 3 and bk.src == "enc" and bk.size == 25 and bk.diff == 4, "END after BOSS_KILL completes the entry")
STUB.tick(300)
STUB.fire("ENCOUNTER_START", 604, "Teron Blutschatten", 4, 25)
local tStart = STUB.now
STUB.tick(60)
STUB.fire("ENCOUNTER_END", 604, "Teron Blutschatten", 4, 25, 1)
STUB.fire("BOSS_KILL", 604, "Teron Blutschatten")
assert(#s.kills == 4 and lastKill(s).src == "enc" and lastKill(s).start == tStart, "BOSS_KILL after END adds nothing")
STUB.fire("ENCOUNTER_END", 604, "Teron Blutschatten", 4, 25, 1)
assert(#s.kills == 4, "a second END adds nothing")
STUB.tick(1)
-- BOSS_KILL during a pull takes its start
STUB.tick(300)
STUB.fire("ENCOUNTER_START", 605, "Gurtogg Siedeblut", 4, 25)
tStart = STUB.now
STUB.tick(100)
STUB.fire("BOSS_KILL", 605, "Gurtogg Siedeblut")
assert(lastKill(s).start == tStart and lastKill(s).src == "kill" and s.pull == nil, "start from the pull")
STUB.fire("ENCOUNTER_END", 605, "Gurtogg Siedeblut", 4, 25, 1)
assert(#s.kills == 5 and lastKill(s).src == "enc")
STUB.tick(1)

---------------------------------------------------------------------------
-- a restricted or secret roster delays who until ADDON_RESTRICTION_STATE_CHANGED
---------------------------------------------------------------------------
STUB.tick(300)
STUB.fire("ENCOUNTER_START", 606, "Reliquiar der Seelen", 4, 25)
STUB.tick(90)
STUB.restricted = true
STUB.fire("ENCOUNTER_END", 606, "Reliquiar der Seelen", 4, 25, 1)
local r = lastKill(s)
STUB.tick(10)
assert(r.wait and r.who == nil, "restricted: still waiting")
STUB.restricted = false
STUB.secret.Chorf = true
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0); STUB.tick(0)
assert(r.wait and r.who == nil, "a secret name keeps it waiting, never a part of the list")
STUB.secret.Chorf = nil
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0); STUB.tick(0)
assert(not r.wait and names(r.who) == "Chorf,Fraktur,Vuloo", names(r.who))

-- after 60 s the minute snapshots of s.members stand in
STUB.tick(300)
STUB.fire("ENCOUNTER_START", 607, "Mutter Shahraz", 4, 25)
STUB.tick(60)
STUB.secret.Fraktur = true
STUB.fire("ENCOUNTER_END", 607, "Mutter Shahraz", 4, 25, 1)
local fb = lastKill(s)
STUB.tick(30)
assert(fb.wait, "still trying after 30 s")
STUB.tick(31)
assert(not fb.wait and names(fb.who) == "Chorf,Fraktur,Vuloo", "the fallback: " .. names(fb.who))

-- the snapshot skips a secret name and keeps the others
local before = s.members.Fraktur.last
STUB.tick(61)
assert(s.members.Fraktur.last == before, "a secret name is skipped")
assert(s.members.Chorf.last > before, "the others still count")
for name in pairs(s.members) do assert(type(name) == "string") end
STUB.secret.Fraktur = nil

---------------------------------------------------------------------------
-- a secret encounter name
---------------------------------------------------------------------------
STUB.tick(300)
STUB.secret["Der Illidari-Rat"] = true
STUB.fire("ENCOUNTER_START", 608, "Der Illidari-Rat", 4, 25)
assert(s.pull.name == "Boss 608", s.pull.name)
STUB.tick(60)
STUB.fire("ENCOUNTER_END", 608, "Der Illidari-Rat", 4, 25, 0)
assert(lastKill(s).name == "Boss 608" and lastKill(s).ok == false)
STUB.secret["Der Illidari-Rat"] = nil

---------------------------------------------------------------------------
-- /reload in the fight: s.pull is kept in the saved raid
---------------------------------------------------------------------------
STUB.tick(300)
STUB.fire("ENCOUNTER_START", 609, "Der Illidari-Rat", 4, 25)
local pullStart = STUB.now
STUB.tick(30)
local chunk = assert(loadfile(ADDON_DIR .. "/RaidLog.lua"))
chunk("Amisia", NS)
NS.RaidLogLoaded()
assert(s.pull and s.pull.enc == 609, "the pull survives the reload")
STUB.tick(100)
local count = #s.kills
STUB.fire("ENCOUNTER_END", 609, "Der Illidari-Rat", 4, 25, 1)
assert(#s.kills == count + 1 and lastKill(s).start == pullStart and lastKill(s).ok, "the end after the reload fits")
STUB.tick(1)
assert(not lastKill(s).wait)
-- on load an old pull is dropped unless the fight still runs
s.pull = { enc = 610, name = "Alt", start = STUB.now - 16 * 60, size = 25, diff = 4 }
STUB.encounter = true
NS.RaidLogLoaded()
assert(s.pull, "kept while a fight runs")
STUB.encounter = false
NS.RaidLogLoaded()
assert(s.pull == nil, "older than 15 minutes and no fight: dropped")
s.pull = { enc = 610, name = "Neu", start = STUB.now - 60, size = 25, diff = 4 }
NS.RaidLogLoaded()
assert(s.pull, "a fresh pull stays")
s.pull = { enc = 610, name = "Uralt", start = STUB.now - 3 * 3600, size = 25, diff = 4 }
STUB.encounter = true
NS.RaidLogLoaded()
assert(s.pull == nil, "older than two hours: always dropped")
STUB.encounter = false
-- a kill still waiting for its names when the game reloaded takes the snapshots
local stale = { enc = 1, name = "X", start = STUB.now - 100, t = STUB.now - 10, ok = true, size = 0, diff = 0, src = "enc", wait = true, n = 3 }
table.insert(s.kills, stale)
NS.RaidLogLoaded()
assert(not stale.wait and names(stale.who) == "Chorf,Fraktur,Vuloo", names(stale.who))
NS.DeleteKill(s, stale)

---------------------------------------------------------------------------
-- the loot window fallback
---------------------------------------------------------------------------
STUB.tick(1200)
local boss = "Creature-0-1-1-1-22947-1"
STUB.target, STUB.targetGUID, STUB.targetDead, STUB.targetClass = "Mutter Shahraz", boss, true, "worldboss"
STUB.loot = { { link = STUB.item(32365, "Heartshatter Breastplate", 4), src = boss } }
count = #s.kills
-- a kill with the same name (Mutter Shahraz above) keeps the corpse out
STUB.fire("LOOT_OPENED")
assert(#s.kills == count, "same name as a kill")
STUB.target = "Gathios der Zerschmetterer"
boss = "Creature-0-1-1-1-22949-1"
STUB.targetGUID = boss
STUB.loot = { { link = STUB.link(32365, "Heartshatter Breastplate", 4), src = boss } }
STUB.fire("LOOT_OPENED")
local lk = lastKill(s)
assert(#s.kills == count + 1 and lk.src == "loot" and lk.enc == 0 and lk.name == "Gathios der Zerschmetterer", "a loot window kill")
assert(lk.ok and lk.t == s.drops[boss].t and lk.start == lk.t and not lk.wait and names(lk.who) == "Chorf,Fraktur,Vuloo")
STUB.tick(30)
STUB.fire("LOOT_OPENED")
assert(#s.kills == count + 1, "reopening adds nothing")
-- not a world boss, alive, or a kill within 10 minutes before
STUB.tick(1200)
local function corpse(guid, name, class, dead)
    STUB.target, STUB.targetGUID, STUB.targetClass, STUB.targetDead = name, guid, class, dead
    STUB.loot = { { link = STUB.link(32365, "Heartshatter Breastplate", 4), src = guid } }
    STUB.fire("LOOT_OPENED")
end
count = #s.kills
corpse("Creature-0-1-1-1-23030-2", "Wache", "elite", true)
assert(#s.kills == count, "an elite is no boss")
corpse("Creature-0-1-1-1-23030-3", "Lebender", "worldboss", false)
assert(#s.kills == count, "alive")
STUB.fire("ENCOUNTER_START", 611, "Najentus", 4, 25); STUB.tick(60)
STUB.fire("ENCOUNTER_END", 611, "Najentus", 4, 25, 1); STUB.tick(1)
STUB.tick(300)
count = #s.kills
corpse("Creature-0-1-1-1-22887-4", "Hochkriegsfuerst", "worldboss", true)
assert(#s.kills == count, "a kill 5 minutes before")
-- lootKills off, track off
STUB.tick(1200)
NS.Set("raidlog.lootKills", false)
corpse("Creature-0-1-1-1-22887-5", "Ohne Schalter", "worldboss", true)
assert(#s.kills == count, "raidlog.lootKills off")
NS.Reset("raidlog.lootKills")
-- a later END replaces the loot window kill
STUB.tick(1200)
corpse("Creature-0-1-1-1-22950-6", "Hohepriesterin Shahraz", "worldboss", true)
local repl = lastKill(s)
assert(repl.src == "loot")
count = #s.kills
STUB.tick(60)
STUB.fire("ENCOUNTER_END", 612, "Rat der Illidari", 4, 25, 1)
assert(#s.kills == count and repl.src == "enc" and repl.enc == 612 and repl.name == "Rat der Illidari", "END replaces the loot kill")
STUB.fire("BOSS_KILL", 612, "Rat der Illidari")
assert(#s.kills == count, "and BOSS_KILL then adds nothing")
STUB.tick(1)
STUB.target, STUB.targetGUID, STUB.targetClass, STUB.targetDead = nil, nil, nil, nil

---------------------------------------------------------------------------
-- raidlog.track off records nothing; without a recording nothing either
---------------------------------------------------------------------------
STUB.tick(600)
count = #s.kills
NS.Set("raidlog.track", false)
STUB.fire("ENCOUNTER_START", 613, "Aus", 4, 25)
assert(s.pull == nil, "no pull while off")
STUB.fire("ENCOUNTER_END", 613, "Aus", 4, 25, 1)
STUB.fire("BOSS_KILL", 613, "Aus")
assert(#s.kills == count, "nothing while off")
NS.Reset("raidlog.track")
-- events with nil payloads do not break anything
STUB.fire("ENCOUNTER_START")
STUB.fire("ENCOUNTER_END")
STUB.fire("BOSS_KILL")
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.tick(1)
assert(#s.kills == count, "nil payloads are ignored")
s.pull = nil

---------------------------------------------------------------------------
-- kills by hand, also into an old raid; deleting
---------------------------------------------------------------------------
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Black Temple", instanceID = 564, start = 1000,
              last = 5000, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
local hk, why = NS.AddKill(old, { name = "", ok = true })
assert(hk == nil and why == "Name fehlt.", tostring(why))
hk = NS.AddKill(old, { name = "  Archi|monde\n", ok = true, t = 4000 })
assert(hk and hk.name == "Archimonde" and hk.src == "hand" and hk.enc == 0 and hk.t == 4000 and hk.start == 4000 and hk.ok, "a kill by hand")
assert(type(hk.who) == "table" and #hk.who == 0 and not hk.wait, "an old raid: nobody to read")
assert(old.last == 5000, "s.last is never touched")
local hw = NS.AddKill(old, { name = "Azgalor", ok = false, t = 3000 })
assert(hw.ok == false and hw.who == nil and old.kills[1] == hw, "sorted by end")
local long = NS.AddKill(old, { name = ("x"):rep(80), ok = true })
assert(#long.name == 60, #long.name)
assert(NS.DeleteKill(old, long) == true and NS.DeleteKill(old, long) == nil, "delete once")
assert(NS.DeleteKill(old, hw) and #old.kills == 1 and old.last == 5000)
local copy = NS.Kills(old)
assert(copy ~= old.kills and copy[1] == hk, "a copy of the list")
-- into the running recording: who from the roster
count = #s.kills
local ak = NS.AddKill(s, { name = "Illidan Sturmgrimm", ok = true })
assert(ak and ak.t == STUB.now and names(ak.who) == "Chorf,Fraktur,Vuloo" and ak.n == 3 and #s.kills == count + 1)
NS.DeleteKill(s, ak)

---------------------------------------------------------------------------
-- ns.KillFor: by name, through the loot window time
---------------------------------------------------------------------------
assert(NS.KillFor(s, "hochkriegsfürst naj'entus") == k, "by name, case aside")
local rat = s.kills[#s.kills]
for _, x in ipairs(s.kills) do if x.enc == 609 then rat = x end end
s.drops["Creature-0-1-1-1-22951-9"] = { src = "Veras Schwarzschatten", t = rat.t + 40, items = {} }
assert(NS.KillFor(s, "Veras Schwarzschatten") == rat, "through the loot window")
s.drops["Creature-0-1-1-1-22952-9"] = { src = "Spaeter Trash", t = STUB.now + 5000, items = {} }
assert(NS.KillFor(s, "Spaeter Trash") == nil, "too long after any kill")
assert(NS.KillFor(s, "Niemand") == nil and NS.KillFor(s, nil) == nil)

---------------------------------------------------------------------------
-- the event trace and /amisia log
---------------------------------------------------------------------------
local tr = NS.EncounterTrace()
assert(#tr > 0 and #tr <= 20 and tr[#tr].event == "BOSS_KILL", tostring(#tr))
NS.Set("raidlog.track", false)
count = #s.kills
for i = 1, 25 do STUB.fire("BOSS_KILL", 900 + i, "Spur " .. i) end
NS.Reset("raidlog.track")
assert(#s.kills == count)
tr = NS.EncounterTrace()
assert(#tr == 20, "a ring of 20: " .. #tr)
assert(has(tr[1].text, "Spur 6") and has(tr[20].text, "Spur 25") and has(tr[20].text, "nicht aufgezeichnet"), tr[20].text)
for _, e in ipairs(tr) do assert(type(e.t) == "number" and type(e.text) == "string") end
local msgs = #STUB.messages
NS.Dispatch("log ereignisse")
local out = table.concat(STUB.messages, "\n", msgs + 1)
assert(has(out, "Letzte Kampfereignisse") and has(out, "BOSS_KILL 925 Spur 25"), out)
msgs = #STUB.messages
NS.Dispatch("log events")
assert(#STUB.messages > msgs, "the alias")
if not NS.ShowRaidLog then
    -- until the page exists, /amisia log lists the bosses of the raid in the chat
    msgs = #STUB.messages
    NS.Dispatch("raidlog")
    out = table.concat(STUB.messages, "\n", msgs + 1)
    assert(has(out, "Hochkriegsfürst Naj'entus"), out)
end
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(has(help, "/amisia log") and has(help, "/amisia boss"), help)
assert(not has(table.concat(NS.SlashHelpLines(false), "\n"), "/amisia boss"), "boss is for officers")

---------------------------------------------------------------------------
-- /amisia boss <Name> [wipe]
---------------------------------------------------------------------------
count = #s.kills
NS.Dispatch("boss Mutter Shahraz")
assert(#s.kills == count + 1 and lastKill(s).name == "Mutter Shahraz" and lastKill(s).ok and lastKill(s).src == "hand")
NS.Dispatch("kill Illidan Sturmgrimm WIPE")
assert(#s.kills == count + 2 and lastKill(s).name == "Illidan Sturmgrimm" and lastKill(s).ok == false, lastKill(s).name)
msgs = #STUB.messages
NS.Dispatch("boss")
assert(#s.kills == count + 2 and has(STUB.messages[#STUB.messages], "/amisia boss"), STUB.messages[#STUB.messages])
NS.Set("ui.view", "raider")
NS.Dispatch("boss Kein Offizier")
assert(#s.kills == count + 2 and has(STUB.messages[#STUB.messages], "Offiziersansicht"), STUB.messages[#STUB.messages])
NS.Reset("ui.view")
-- without a recording: into the newest raid, s.last untouched
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil, "recording over")
local lastBefore = s.last
STUB.tick(100)
NS.Dispatch("boss Nachgetragen")
assert(lastKill(s).name == "Nachgetragen" and s.last == lastBefore, "into the newest raid")
assert(type(lastKill(s).who) == "table" and #lastKill(s).who == 0)
-- events without a recording record nothing
count = #s.kills
STUB.fire("ENCOUNTER_START", 614, "Draussen", 4, 25)
STUB.fire("ENCOUNTER_END", 614, "Draussen", 4, 25, 1)
assert(#s.kills == count and s.pull == nil, "no recording, no kill")
assert(NS.EncounterTrace()[20].text:find("Draussen", 1, true), "the trace still sees it")

---------------------------------------------------------------------------
-- UI and chat texts stay within Latin-1
---------------------------------------------------------------------------
local src = assert(io.open(ADDON_DIR .. "/RaidLog.lua", "rb")):read("*a")
for c in src:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1: " .. c) end
