--[[clients Vulo_Sturmwind Kim_Eisherz]]
--[[locale enUS]]
-- A blob over its parts in an English client (Comm.lua): the reason reads "Data too large.", not
-- the German key; the raid sync still knows it (one warning, in English) and the loot prio still
-- sends the newest part of a list too big for one blob.
local VULO, KIM = "Vulo Sturmwind", "Kim Eisherz"
local function german(text) return type(text) == "string" and text:find("[\195][\164\182\188\132\150\156\159]") ~= nil end

BUS.setRaid({ VULO, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind"
        if not STUB.officer then NS.Set("ui.view", "raider") end
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true, "Vulo keeps the raid")

-- the reason itself, in English
C(VULO, [[REAL_CHUNKS = NS.CommChunks
    HUGE = function() local t = {}; for i = 1, 999 do t[i] = "A" end; return t end]])
local ok, why = C(VULO, [[NS.CommChunks = HUGE
    local ok, why = NS.CommSendBlob("SP", "2026-10-05:409", { a = 1 }, "RAID")
    NS.CommChunks = REAL_CHUNKS
    return ok, why]])
assert(ok == nil and why == "Data too large.", tostring(why))
assert(not german(why))

-- the raid sync: its snapshot too big, one warning in English, not one per try
local function warnings()
    return C(VULO, [[local n = 0
        for _, m in ipairs(STUB.messages) do if m:find("too big for the sync", 1, true) then n = n + 1 end end
        return n]])
end
assert(warnings() == 0)
assert(C(VULO, "NS.CommChunks = HUGE; local r = NS.SyncNow(); NS.CommChunks = REAL_CHUNKS; return r") == "keeper")
assert(warnings() == 1, "the keeper is told its raid state is too big: " .. warnings())
C(VULO, "NS.CommChunks = HUGE; NS.SyncNow(); NS.CommChunks = REAL_CHUNKS")
assert(warnings() == 1, "told once")

-- the loot prio: a list too big for one blob, the newest part goes out
C(KIM, "NS.Set('prio.share', true)")
assert(C(VULO, [[local lines = { "#AMISIA-LC 1 forever 2026-10-07" }
    for i = 1, 150 do lines[#lines + 1] = ("C %d %d p:Anna_Bergmann:Tank,c:WARRIOR:Furor,p:Kimtaro,c:MAGE,o Tanks first, then DPS"):format(40000 + i, 1788000000 + i) end
    lines[#lines + 1] = "#END"
    return NS.SetLootPrio(table.concat(lines, "\n")) ~= nil]]))
BUS.tick(60)
local got = C(KIM, "local n = 0; for id = 40001, 40150 do if NS.LootPrioOf(id) then n = n + 1 end end; return n")
assert(got >= 10 and got < 150, "a part of the big list: " .. tostring(got))
assert(C(KIM, "NS.LootPrioOf(40150) ~= nil"), "the newest item is in it")
print("comm too big (enUS) ok")
