-- Review 2026-10-11 (Core, Raid): secret values of the Forever client (names and GUIDs in an
-- instance, a boss fight) never become a table key, a stored source name or a compared name.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "a recording runs")

local function anySecret(t)
    for k, v in pairs(t) do
        if STUB.secret[k] or STUB.secret[v] then return true end
    end
    return false
end

-- 1. Core's loot window: the slot's source, the target's GUID and its name are all secret
local GUID = "Creature-0-1-564-1-22917-00000SECRET"
local link = STUB.item(32235, "Verfluchte Vision", 4)
STUB.secret[GUID] = true
STUB.secret["Geheimer Boss"] = true
STUB.target, STUB.targetGUID = "Geheimer Boss", GUID
STUB.loot = { { link = link, name = "Verfluchte Vision", src = GUID } }
STUB.fire("LOOT_OPENED")
assert(not anySecret(s.drops), "no secret GUID as a key of the drops")
for _, d in pairs(s.drops) do
    assert(not STUB.secret[d.src], "no secret name as a drop's source")
end
assert(NS.DropCount(s) == 1, "the item still counts, under an unknown source")
STUB.fire("LOOT_CLOSED")

-- 2. the source name of a loot slot: a secret slot GUID or target name is never returned
STUB.loot = { { link = link, name = "Verfluchte Vision", src = GUID } }
local src = NS.LootSourceName(1)
assert(src == "?", "a secret slot source gives no name: " .. tostring(src))
STUB.loot = { { link = link, name = "Verfluchte Vision", src = "Creature-0-1-564-1-22917-0000000PLAIN" } }
STUB.targetGUID = "Creature-0-1-564-1-22917-0000000PLAIN"
src = NS.LootSourceName(1)
assert(src == "?", "a secret target name is never the source: " .. tostring(src))
STUB.target = "Illidan Sturmgrimm"
assert(NS.LootSourceName(1) == "Illidan Sturmgrimm", "a plain target of the slot is its source")
STUB.target, STUB.targetGUID, STUB.loot = nil, nil, {}

-- 3. a master loot hand-out to a secret candidate name is not remembered under that name
STUB.secret["Geheim Name"] = true
local oldCand = _G.GetMasterLootCandidate
_G.GetMasterLootCandidate = function() return "Geheim Name" end
STUB.loot = { { link = link, name = "Verfluchte Vision" } }
GiveMasterLoot(1, 1)
local p = NS.PendingAward(1)
assert(not (p and STUB.secret[p.name]), "no hand-out under a secret name")
_G.GetMasterLootCandidate = oldCand
STUB.fire("LOOT_CLOSED")
STUB.loot = {}

-- 4. a secret roster name is never compared: ns.InGroup and the roll round's group check skip it
STUB.roster[3] = { name = "Geheim Name", class = "MAGE" }
assert(NS.InGroup("Geheim Name") == false, "a secret roster line is skipped")
assert(NS.InGroup("Fraktur") == true, "the readable lines still count")
assert(NS.StartRoll(link, 20))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Geheim Name", 77, 1, 100))
local r = NS.CurrentRoll()
assert(not r.rolls["Geheim Name"], "a roll whose roster line is secret is not counted")
NS.StopRoll()
STUB.roster[3] = nil
