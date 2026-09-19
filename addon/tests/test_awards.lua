-- Master loot hand-outs: confirmed by the chat line or the emptied slot, dropped otherwise.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.target, STUB.targetGUID = "Illidan Stormrage", "Creature-0-1-1-1-22917-1"
STUB.fire("LOOT_OPENED")
assert(s.drops["Creature-0-1-1-1-22917-1"].src == "Illidan Stormrage", "drop source named from the target")

GiveMasterLoot(1, 2)
assert(NS.PendingAward() and NS.PendingAward().name == "Fraktur" and NS.PendingAward().src == "Illidan Stormrage")
assert(#s.awards == 0, "not written before confirmation")
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", link))
assert(#s.awards == 1 and s.awards[1].item == 32235 and s.awards[1].src == "Illidan Stormrage", "confirmed by chat line")
assert(NS.PendingAward() == nil)

-- confirmation by slot cleared
GiveMasterLoot(1, 2); STUB.fire("LOOT_SLOT_CLEARED", 1)
assert(#s.awards == 2, "confirmed by slot cleared")
STUB.fire("LOOT_SLOT_CLEARED", 1)
assert(#s.awards == 2, "a second clear does nothing")

-- expiry
GiveMasterLoot(1, 2); STUB.tick(6)
assert(NS.PendingAward() == nil and #s.awards == 2, "pending expired")

-- loot closed drops pending
GiveMasterLoot(1, 2); STUB.fire("LOOT_CLOSED"); assert(NS.PendingAward() == nil)

-- a chat line for someone else does not confirm, a new hand-out replaces the old one
GiveMasterLoot(1, 2); STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Vuloo", link))
assert(#s.awards == 2 and NS.PendingAward())
GiveMasterLoot(1, 1); assert(NS.PendingAward().name == "Vuloo")
STUB.fire("LOOT_CLOSED")

-- the realm suffix of a candidate is dropped
STUB.roster[2].name = "Fraktur-Thunderstrike"
GiveMasterLoot(1, 2); assert(NS.PendingAward().name == "Fraktur")
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur-Thunderstrike", link))
assert(#s.awards == 3 and s.awards[3].name == "Fraktur")
STUB.roster[2].name = "Fraktur"

-- manual
NS.AwardCommand("Fraktur " .. link .. " os"); assert(s.awards[4].kind == "OS")
NS.AwardCommand("Fraktur 32235"); assert(s.awards[5].kind == "-" and s.awards[5].item == 32235)
NS.AwardCommand("Fraktur"); assert(#s.awards == 5, "missing item refused")
NS.AwardCommand(""); assert(#s.awards == 5)
NS.AwardCommand("unaward"); assert(#s.awards == 4)

-- roll context feeds the kind
NS.RollKind = function(item, name) return item == 32235 and name == "Fraktur" and "MS" or "-" end
GiveMasterLoot(1, 2); STUB.fire("LOOT_SLOT_CLEARED", 1)
assert(s.awards[5].kind == "MS", "kind from the roll round")

-- export carries them
local txt = NS.ExportText({ s })
assert(txt:find("\nA Fraktur 32235 %d+ MS Illidan Stormrage\n"), txt)
