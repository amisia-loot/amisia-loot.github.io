--[[clients Vulo M01 M02 M03 M04 M05 M06 M07 M08 M09 M10 M11 M12 M13 M14]]
-- Review of the 2.3 drop exchange: one announcement heard by fourteen members with nothing. Busy
-- senders answer DW, pulls spread over the senders, members announce what they learned and serve
-- it: within an hour every member has all 84 records (84 buckets of seven days and twelve
-- instances), and nobody sends beyond the session's bytes.
local rows = {}
for i, n in ipairs(CLIENTS) do rows[i] = { name = n, rank = 2 } end
BUS.setGuild(rows)
-- The client ids are fixed: a new one hashes a table address (another one in every run), and the
-- id sets the first announcement's time, so the run would differ from run to run.
local IDS = { "d82c07cd", "629f6fbe", "c2094cac", "e3e70682", "6baa9455", "0a5d2f34", "42485e3a", "f728b4fa",
              "82e2e662", "7c65c1e5", "67a9c378", "eb1167b3", "c8a70639", "d4713d60", "4da5e709" }
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
