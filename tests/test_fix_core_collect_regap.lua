--[[clients Vulo_Sturmwind Fraktur]]
-- A source pull cut off by combat right after its CQ and started again within a minute: the sender's
-- Comm takes one CQ per kind from one asker in 60 s and drops the second silently. The asker must
-- wait out that gap before asking again, so the announcement is still pulled (audit 2026-11-07).
local VULO, FRAK = "Vulo Sturmwind", "Fraktur"
local ME = { [VULO] = "a0000001", [FRAK] = "b0000002" }

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 } })
for _, name in ipairs(CLIENTS) do
    C(name, ([[STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
-- Fraktur holds one quest Vulo lacks
local D = C(FRAK, "NS.DropsToday()")
assert(C(FRAK, ([[local s = NS.CollectFromWire("q", "%d;0;100;1411:1:1;0;;;;0;10;A;0;Gryan;Die Defias", 2)
    return NS.CollectPut("q", 2065, s, "own") and true]]):format(D)) == true)
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end

-- the first bucket list never arrives: Vulo's pull stays at its CQ
BUS.drop(function(m) return m.kind == "CI" end)
local waited = 0
while BUS.count({ kind = "CQ", sender = VULO }) == 0 and waited < 400 do
    BUS.tick(1)
    waited = waited + 1
end
assert(BUS.count({ kind = "CQ", sender = VULO }) == 1, "Vulo asked Fraktur")
C(VULO, "STUB.combat = true")
BUS.tick(6)
assert(C(VULO, "NS.CollectSyncState().pulling") == nil, "combat stopped the pull")
C(VULO, "STUB.combat = false")
BUS.drop(nil)
BUS.tick(250)
assert(C(VULO, "AmisiaDB.collect.q[2065] ~= nil") == true, "the interrupted announcement was pulled")
