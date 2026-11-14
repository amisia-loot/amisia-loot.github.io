-- A sender heard long ago expires while a newer one is ready to be pulled (e.g. after a long fight or
-- dungeon, when nothing may be asked): the pull goes to the newer one. The expired one used to be removed
-- while the ready ones were collected by index, which shifted them: "attempt to index local 'p' (a nil
-- value)" in CollectSync.lua, the same in DropSync.lua and Crafters.lua.
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.combat = false
STUB.guild = {
    { name = "Alt", class = "PRIEST", online = true, rank = 2 },
    { name = "Neu", class = "PRIEST", online = true, rank = 2 },
}
STUB.fire("GUILD_ROSTER_UPDATE")
AmisiaDB.drops.me = "12345678"
local function to(kind, name)
    local n = 0
    for _, m in ipairs(STUB.addon) do
        if m.text:match("^%d" .. kind .. "\t") and m.target == name then n = n + 1 end
    end
    return n
end
local function cv(sender)
    local text = ("%dCV\t%d\t5\tq:abcd:5,s:0000:0,w:0000:0"):format(NS.SYNC_PROTO, NS.COLLECT_PROTO)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", text, "GUILD", sender, "", 0, 0, "", 0)
end
local function dv(sender)
    local text = ("%dDV\t2\t24\t%d\t0:c3d4:24,1:0000:0,2:0000:0,3:0000:0"):format(NS.SYNC_PROTO, NS.DropsToday())
    STUB.fire("CHAT_MSG_ADDON", "Amisia", text, "GUILD", sender, "", 0, 0, "", 0)
end

-- in a fight nothing is asked: "Alt" waits until it is too old, "Neu" comes later
STUB.combat = true
cv("Alt")
dv("Alt")
STUB.tick(3000)
cv("Neu")
dv("Neu")
STUB.tick(700)
STUB.combat = false
STUB.tick(60)
assert(to("CQ", "Neu") >= 1, "the collector pull goes to the newer sender")
assert(to("CQ", "Alt") == 0, "the expired sender is not asked")
assert(to("DQ", "Neu") >= 1, "the drop pull goes to the newer sender")
assert(to("DQ", "Alt") == 0, "the expired drop sender is not asked")
