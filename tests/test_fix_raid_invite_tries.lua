-- An invite whose client call fails (pcall false) uses up none of the three tries per name and
-- night (Raid/LineupInvite.lua invite(), audit 2026-11-07).
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
_G.IsInRaid = function() return false end
_G.IsInGroup = function() return false end
_G.UnitIsGroupLeader = function() return true end
STUB.roster, STUB.leader = {}, true

local fail = true
C_PartyInfo.InviteUnit = function() if fail then error("no") end end

local night = NS.SetLineupText("Anna Bergmann Heiler\nVuloo Heiler")
NS.LineupAutoAssign(night)
local function state() return NS.LineupInviteStates(night)["anna bergmann"] end

for _ = 1, 4 do
    NS.LineupInviteOne(night, "Anna Bergmann")
    STUB.tick(1)
end
local r = state()
assert(r and r.st == "P", "a failed call puts the name back: " .. tostring(r and r.st))
assert(r.tries == 0, "a failed call uses up no try: " .. tostring(r.tries))

fail = false
assert(NS.LineupInviteOne(night, "Anna Bergmann") == 1, "the name can still be invited")
STUB.tick(1)
r = state()
assert(r.st == "I" and r.tries == 1, "a taken invite counts: " .. tostring(r.st) .. " " .. tostring(r.tries))
