-- Item stats the server does not answer in time (Gear.lua tick, Gear.Stats): after its tries time
-- out an item counts as failed, but not for the whole session: a minute later it is asked again when
-- it is needed, a few rounds at most (so it never loops forever). A failed answer by event is final.
local Gear = NS.Gear
local ID = 987001
Gear._reset()
assert(Gear.Stats(ID) == nil, "unknown: requested")
STUB.tick(13)   -- both tries time out
local s, failed = Gear.Stats(ID)
assert(failed, "timed out: failed for now")
STUB.tick(61)
STUB.requested = {}
s, failed = Gear.Stats(ID)
assert(s == nil and not failed, "a minute later it is asked again")
STUB.tick(0.2)
assert(STUB.requested[1] == ID, "requested again")
-- the answer comes this time
STUB.item(ID, "Langsamer Helm", 2)
STUB.items[ID].equipLoc, STUB.items[ID].classID = "INVTYPE_HEAD", 4
STUB.items[ID].stats = { ITEM_MOD_STRENGTH_SHORT = 7 }
STUB.tick(1)
s, failed = Gear.Stats(ID)
assert(s and s.STR == 7 and not failed, "the late answer counts")

-- an item that never answers: asked a few rounds, then failed for good
local NONE = 987002
Gear._reset()
Gear.Stats(NONE)
local rounds = 0
for _ = 1, 10 do
    STUB.tick(13)
    rounds = rounds + 1
    STUB.tick(61)
    s, failed = Gear.Stats(NONE)
    if failed then break end
end
assert(failed and rounds == 3, "failed for good after three rounds: " .. rounds)
STUB.tick(600)
assert(select(2, Gear.Stats(NONE)), "not asked any more")
