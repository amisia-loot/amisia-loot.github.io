--[[clients Vulo M01 M02 M03 M04 M05 M06 M07 M08 M09 M10 M11 M12 M13 M14]]
-- Review of the 2.3 drop exchange: one announcement heard by fourteen members with nothing. Busy
-- senders answer DW, pulls spread over the senders, members announce what they learned and serve
-- it: within an hour every member has all 84 records (84 buckets of seven days and twelve
-- instances), and nobody sends beyond the session's bytes.
local rows = {}
for i, n in ipairs(CLIENTS) do rows[i] = { name = n, rank = 2 } end
BUS.setGuild(rows)
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
