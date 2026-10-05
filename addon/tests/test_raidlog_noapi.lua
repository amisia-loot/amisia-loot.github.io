--[[preload
UnitClassification = nil
UnitIsDead = nil
C_InstanceEncounter = nil
C_RestrictedActions = nil
]]
-- A client without UnitClassification, UnitIsDead, C_InstanceEncounter and C_RestrictedActions:
-- no loot window kills, who after 1 s, and no error anywhere.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording")
STUB.fire("ENCOUNTER_START", 601, "Hochkriegsfürst Naj'entus", 4, 25)
STUB.tick(100)
STUB.fire("ENCOUNTER_END", 601, "Hochkriegsfürst Naj'entus", 4, 25, 1)
assert(#s.kills == 1 and s.kills[1].wait)
STUB.tick(1)
assert(not s.kills[1].wait and table.concat(s.kills[1].who, ",") == "Fraktur,Vuloo", "who after 1 s")
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0); STUB.tick(0)
STUB.tick(1200)
local boss = "Creature-0-1-1-1-22949-1"
STUB.target, STUB.targetGUID, STUB.targetDead, STUB.targetClass = "Gathios", boss, true, "worldboss"
STUB.loot = { { link = STUB.item(32365, "Heartshatter Breastplate", 4), src = boss } }
STUB.fire("LOOT_OPENED")
assert(#s.kills == 1 and s.drops[boss], "no loot window kill without UnitClassification")
s.pull = { enc = 2, name = "Alt", start = STUB.now - 20 * 60, size = 25, diff = 4 }
NS.RaidLogLoaded()
assert(s.pull == nil, "without the encounter query an old pull is dropped")
