--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- The multi-client bus of run.py with the message layer: raid, guild and whisper delivery, the own
-- echo, dropped messages, the lockdown on every client and a blob from one client to another.
assert(#CLIENTS == 3 and CLIENTS[1] == "Vulo Sturmwind")
assert(C("Fraktur", "STUB.player") == "Fraktur" and C("Vulo_Sturmwind", "NS.UnitFullName('player')") == "Vulo Sturmwind")
-- several values and tables come back
local a, b = C("Kim Eisherz", "1, 'zwei'")
assert(a == 1 and b == "zwei")
local t = C("Kim Eisherz", "{ x = 1, y = { 'a', 'b' }, z = true }")
assert(t.x == 1 and t.y[2] == "b" and t.z == true)
assert(C("Kim Eisherz", "local v = 2; return v * 3") == 6)

BUS.setRaid({ "Vulo Sturmwind", "Fraktur", "Kim Eisherz" })
BUS.setGuild({ { name = "Vulo Sturmwind", rank = 2 }, { name = "Fraktur", rank = 2 }, { name = "Kim Eisherz", rank = 4 } })
assert(C("Fraktur", "#STUB.roster") == 3 and C("Fraktur", "STUB.guild[3].rank") == 4)
for _, name in ipairs(CLIENTS) do
    C(name, [[GOT = {}
        NS.CommOn("HI", function(sender, f, chan) GOT[#GOT + 1] = sender .. "|" .. chan .. "|" .. f[1] end)
        BLOBS = {}
        NS.CommOnBlob("SP", function(sender, tbl, chan, key) BLOBS[#BLOBS + 1] = { sender = sender, tbl = tbl, chan = chan, key = key } end)]])
end

-- RAID reaches everyone else; the sender's own echo is ignored
assert(C("Vulo Sturmwind", "NS.CommSend('HI', { '2.1.0', '1', 'L', '-' }, 'RAID')") == true)
assert(BUS.count({ kind = "HI", chan = "RAID", sender = "Vulo Sturmwind" }) == 1)
assert(C("Fraktur", "#GOT") == 0, "nothing before delivery")
BUS.deliver()
assert(C("Fraktur", "GOT[1]") == "Vulo Sturmwind|RAID|2.1.0")
assert(C("Kim Eisherz", "#GOT") == 1 and C("Vulo Sturmwind", "#GOT") == 0)

-- WHISPER reaches one client, also with a realm ending on the target
C("Fraktur", "NS.CommSend('HI', { '2.1.1', '1', '-', '-' }, 'WHISPER', 'Kim Eisherz-Realm')")
BUS.deliver()
assert(C("Kim Eisherz", "GOT[2]") == "Fraktur|WHISPER|2.1.1" and C("Vulo Sturmwind", "#GOT") == 0)

-- GUILD reaches the guild only
BUS.setRaid({ "Vulo Sturmwind", "Fraktur" })
assert(C("Kim Eisherz", "#STUB.roster") == 0)
C("Kim Eisherz", "NS.CommSend('HI', { '2.0.9', '1', '-', '-' }, 'GUILD')")
BUS.deliver()
assert(C("Vulo Sturmwind", "GOT[1]") == "Kim Eisherz|GUILD|2.0.9" and C("Fraktur", "#GOT") == 2)
-- RAID from a client outside the raid goes nowhere (the client refuses it)
assert(C("Kim Eisherz", "NS.CommSend('HI', { '2.0.9', '1', '-', '-' }, 'RAID')") == nil)

-- the sender's realm, as some clients add it
BUS.realm = "-Realm"
C("Fraktur", "NS.CommSend('HI', { '2.1.2', '1', '-', '-' }, 'RAID')")
BUS.deliver()
assert(C("Vulo Sturmwind", "GOT[2]") == "Fraktur-Realm|RAID|2.1.2")
BUS.realm = ""

-- dropped messages are counted as sent but never arrive
BUS.drop(function(m) return m.kind == "HI" and m.sender == "Fraktur" end)
C("Fraktur", "NS.CommSend('HI', { '2.1.3', '1', '-', '-' }, 'RAID')")
BUS.deliver()
assert(C("Vulo Sturmwind", "#GOT") == 2 and BUS.count({ sender = "Fraktur", kind = "HI" }) == 3)
assert(BUS.count(function(m) return m.dropped end) == 1)
BUS.drop(nil)

-- the lockdown on every client: held, then released one tick after the event
BUS.lock(true)
C("Vulo Sturmwind", "NS.CommSend('HI', { '2.1.4', '1', '-', '-' }, 'RAID')")
assert(C("Vulo Sturmwind", "NS.CommHeld()") == true and C("Vulo Sturmwind", "NS.CommQueueSize()") == 1)
BUS.tick(3)
assert(C("Fraktur", "#GOT") == 2, "nothing during the lockdown")
local before = #BUS.sent
BUS.lock(false)
BUS.tick(0.1)
assert(#BUS.sent == before + 1 and C("Fraktur", "GOT[3]") == "Vulo Sturmwind|RAID|2.1.4")
local at = BUS.sent[#BUS.sent].t
assert(BUS.count({ from = at, to = at }) == 1 and BUS.count({ from = at + 1 }) == 0)

-- a blob from one client reaches the other whole, through the throttled queue
C("Vulo Sturmwind", [[BIG = { k = "2026-10-05:409", a = {} }
    for i = 1, 40 do BIG.a[i] = { ("%012x"):format(i), "Spieler " .. i, 30000 + i, "MS" } end
    return NS.CommSendBlob("SP", "2026-10-05:409", BIG, "RAID", nil, { key = "SP:2026-10-05:409" })]])
BUS.tick(30)
local parts = BUS.count({ prefix = "AmisiaD", sender = "Vulo Sturmwind" })
assert(parts > 1, "several parts: " .. parts)
assert(C("Fraktur", "#BLOBS") == 1 and C("Fraktur", "BLOBS[1].sender") == "Vulo Sturmwind")
local got = C("Fraktur", "BLOBS[1].tbl")
assert(got.k == "2026-10-05:409" and #got.a == 40 and got.a[40][2] == "Spieler 40")
assert(C("Vulo Sturmwind", "#BLOBS") == 0, "own echo of a blob")
