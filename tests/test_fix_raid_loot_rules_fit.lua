-- Loot rules (Raid/LootRules.lua, audit 2026-11-07): a rule that would make the set too big for its
-- 4 MR parts ("An Offiziere senden") is refused when it is added; every set that is kept still goes.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.guild = { { name = "Vuloo", rank = 1 }, { name = "Fraktur", rank = 3 } }
STUB.rankFlags = { [1] = { [22] = true } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

-- quality rules: one entry each, 6 entries per part, 4 parts: 24 fit, the 25th not (30 allowed)
local n, why = 0, nil
for _ = 1, 30 do
    local r, w = NS.AddLootRule({ k = "q", q = 3, to = "de" })
    if not r then why = w break end
    n = n + 1
end
assert(n == 24, "24 single-entry rules fit: " .. n)
assert(has(why, "Nachricht an die Offiziere"), tostring(why))
assert(#NS.LootRules().list == 24, "the refused rule is not kept")
local ok, w = NS.SendLootRules()
assert(ok, "the kept set goes out: " .. tostring(w))

-- long item lists: 50 ids are 4 entries; a set of several such lists stops before it is too big
NS.LootRules().list = {}
local ids = {}
for i = 1, 50 do ids[i] = tostring(100000 + i) end
local list = table.concat(ids, " ")
n = 0
for _ = 1, 10 do
    if not NS.AddLootRule({ k = "i", items = list, to = "bank" }) then break end
    n = n + 1
end
assert(n >= 1 and n < 10, "long lists stop in time: " .. n)
ok, w = NS.SendLootRules()
assert(ok, "the set of long lists goes out: " .. tostring(w))
