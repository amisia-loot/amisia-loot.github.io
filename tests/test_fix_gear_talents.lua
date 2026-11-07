-- The class list of the talent planner (Talents.lua T.Classes): the own class first, then by class
-- id, with a valid order function (never "less than" itself; table.sort may compare an element with
-- itself and fails or sorts wrongly on one that says so).
local T = NS.Talents
assert(T and T.Classes, "the talent module")
STUB.class = "MAGE"
local realSort = table.sort
local cmp
table.sort = function(t, f)
    cmp = cmp or f
    return realSort(t, f)
end
local list = T.Classes()
table.sort = realSort
assert(#list > 1, "the shipped talent data has classes")
assert(list[1] == "MAGE", "the own class first: " .. tostring(list[1]))
assert(cmp, "sorted with an order function")
assert(cmp("MAGE", "MAGE") == false, "the own class is not less than itself")
for _, a in ipairs(list) do
    assert(cmp(a, a) == false, a .. " is not less than itself")
    for _, b in ipairs(list) do
        assert(not (cmp(a, b) and cmp(b, a)), "a strict order: " .. a .. " / " .. b)
    end
end
