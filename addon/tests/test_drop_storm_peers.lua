--[[clients Vulo M01 M02 M03 M04 M05 M06 M07 M08 M09 M10 M11 M12 M13 M14]]
-- The storm of test_review23_storm with the client ids of a run that stalled: the members announced
-- what they pulled first (the same 24 records, all in the sender's bucket order), the senders that
-- held all 84 announced once, and M05, busy-waited by them, heard ten half-pulled announcements
-- after theirs. Its list of announcements (ten at most) dropped the oldest, the full senders, and
-- nobody announced again: M05 stayed at 72. Now a full list drops the announcement worth least
-- (test_drop_peers), and pulls take the buckets in a random order.
local rows = {}
for i, n in ipairs(CLIENTS) do rows[i] = { name = n, rank = 2 } end
BUS.setGuild(rows)
local IDS = { "8c5187c1", "137c56af", "58886f39", "993955be", "d848292d", "9b11bf0c", "49e1859f", "1634106f",
              "82a5f8b3", "ed60f364", "58043666", "64961c01", "6a5dcf77", "04c66342", "f94ecf68" }
for i, n in ipairs(CLIENTS) do C(n, "AmisiaDB.drops.me = '" .. IDS[i] .. "'") end
for _, n in ipairs(CLIENTS) do
    C(n, [[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }; STUB.combat = false; STUB.fire("GUILD_ROSTER_UPDATE")]])
end
C("Vulo", [[local today = NS.DropsToday()
    local i = 0
    for day = 0, 6 do for inst = 1, 12 do
        i = i + 1
        NS.DropsMerge({ h = ("%08x"):format(i), npc = 1000 + inst, inst = 2000 + inst, diff = 1, day = today - day, o = AmisiaDB.drops.me, src = "G", it = {} })
    end end]])
C("Vulo", "STUB.fire('PLAYER_LOGIN')")
BUS.tick(3600)
local full, got = 0, {}
for i = 2, #CLIENTS do
    local k = C(CLIENTS[i], "NS.DropsStatus().kills")
    got[#got + 1] = k
    if k == 84 then full = full + 1 end
end
assert(full == #CLIENTS - 1, "members with all 84 after an hour: " .. table.concat(got, " "))
for _, n in ipairs(CLIENTS) do
    assert(C(n, "NS.DropSyncStats().bytes") <= 61440, n .. " within the session's bytes")
end
assert(BUS.count({ kind = "DW", sender = "Vulo" }) >= 1, "the busy sender said so")
