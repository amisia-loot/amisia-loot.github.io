-- The announcements a client keeps (ten at most) while it waits to pull: a full list drops the one
-- worth least (nothing new for this client, else the fewest records, the oldest of those), never by
-- age alone. Here the one sender that holds everything announced first and ten half-pulled members
-- after it; dropping the oldest would lose the full sender, which announces only once.
STUB.instance = { name = "Sturmwind", type = "none", id = 0 }
STUB.combat = false
STUB.guild = { { name = "Voll", class = "PRIEST", online = true, rank = 2 } }
for i = 1, 10 do STUB.guild[#STUB.guild + 1] = { name = ("Halb%02d"):format(i), class = "PRIEST", online = true, rank = 2 } end
STUB.fire("GUILD_ROSTER_UPDATE")
AmisiaDB.drops.me = "12345678"
local function dv(sender, hash, n)
    local text = ("%dDV\t2\t%d\t%d\t0:%s:%d,1:0000:0,2:0000:0,3:0000:0"):format(NS.SYNC_PROTO, n, NS.DropsToday(), hash, n)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", text, "GUILD", sender, "", 0, 0, "", 0)
end
local function dqTo(name)
    local n = 0
    for _, m in ipairs(STUB.addon) do
        if m.prefix == "Amisia" and m.text:match("^%dDQ\t") and m.target == name then n = n + 1 end
    end
    return n
end
dv("Voll", "a1b2", 84)
for i = 1, 10 do dv(("Halb%02d"):format(i), "c3d4", 24) end
assert(NS.DropSyncState().waiting == 10, "ten announcements kept")
-- nobody answers: every kept sender is asked once (a silent one is given up after a minute)
STUB.tick(900)
assert(dqTo("Voll") == 1, "the sender that holds everything was kept and asked")
assert(dqTo("Halb01") == 0, "the oldest of the half-pulled ones was dropped")
local asked = 0
for i = 2, 10 do asked = asked + dqTo(("Halb%02d"):format(i)) end
assert(asked == 9, "the other nine were asked: " .. asked)
