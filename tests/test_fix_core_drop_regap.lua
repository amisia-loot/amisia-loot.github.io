--[[clients Vulo_Sturmwind Fraktur]]
-- A drop pull cut off by combat right after its DQ and started again within a minute: the sender's
-- Comm takes one DQ per week from one asker in 60 s and drops the second silently. The asker must
-- wait out that gap before asking again, so the announcement is still pulled (audit 2026-11-07).
local VULO, FRAK = "Vulo Sturmwind", "Fraktur"
local ME = { [VULO] = "a0000001", [FRAK] = "b0000002" }

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 } })
for _, name in ipairs(CLIENTS) do
    C(name, ([[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
-- Fraktur holds one record Vulo lacks
assert(C(FRAK, [[local r = { h = "33333333", npc = 213460, inst = 2834, diff = 1, day = NS.DropsToday(), o = AmisiaDB.drops.me, src = "G", it = {} }
    return NS.DropsMerge(r)]]) == "new")
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end

-- the first bucket list never arrives: Vulo's pull stays at its DQ
BUS.drop(function(m) return m.kind == "DI" end)
local waited = 0
while BUS.count({ kind = "DQ", sender = VULO }) == 0 and waited < 400 do
    BUS.tick(1)
    waited = waited + 1
end
assert(BUS.count({ kind = "DQ", sender = VULO }) == 1, "Vulo asked Fraktur")
-- combat cuts the pull off, it ends 10 s later
C(VULO, "STUB.combat = true")
BUS.tick(6)
assert(C(VULO, "NS.DropSyncState().pulling") == nil, "combat stopped the pull")
C(VULO, "STUB.combat = false")
BUS.drop(nil)
BUS.tick(10)
-- the record arrives within a few minutes (the next announcement is 30 minutes away)
BUS.tick(240)
assert(C(VULO, "AmisiaDB.drops.k['33333333'] ~= nil") == true, "the interrupted announcement was pulled")
assert(C(VULO, "NS.DropSyncStats().unasked") == 0)
