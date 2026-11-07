-- The planner of the page "Aufstellung" (Pages/Lineup.lua): the entry chosen by the first click is
-- kept by its name, so a list that changes before the second click (an entry before it leaves)
-- swaps the chosen player and not the one now at the old index.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Vulo Hunt", rank = 3, class = "HUNTER" },
    { name = "Vulo Pala", rank = 3, class = "PALADIN" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
NS.Dispatch("aufstellung")
local f = NS.PageFrame("lineup")
f.pasteBtn:Click()
f.paste.box:SetText("Tanks\nVulo Hunt\nBob Eisherz\nHeiler\nVulo Pala\nAnna Bergmann\nNahkampf\nKim Sturmwind\nVuloo")
f.take:Click()
f.auto:Click()
assert(f.plan:IsShown(), "the planner")

local function indexOf(name)
    for i, e in ipairs(NS.LineupNight().list) do if e.n == name then return i end end
end
local function slotOf(name)
    for _, box in ipairs(f.plan.groups) do
        for _, b in ipairs(box.slots) do
            local e = b.entry and NS.LineupNight().list[b.entry]
            if e and e.n == name then return b end
        end
    end
end
local function groupOf(name) local b = slotOf(name); return b and b.group end

-- choose the last entry, then an entry before it leaves the list
local list = NS.LineupNight().list
local chosen = list[#list].n
local other = chosen == "Bob Eisherz" and "Vulo Hunt" or "Bob Eisherz"
local leaving
for _, e in ipairs(list) do
    if e.n ~= chosen and e.n ~= other then leaving = e.n break end
end
assert(indexOf(leaving) < indexOf(chosen), "an entry before the chosen one")
-- both in different groups so a swap shows
local og = groupOf(other)
if groupOf(chosen) == og then
    for g = 1, 8 do if g ~= og and f.plan.groups[g]:IsShown() then NS.LineupMove(NS.LineupTonight(), indexOf(chosen), g) break end end
    NS.Refresh()
end
local chosenGroup, otherGroup = groupOf(chosen), groupOf(other)
assert(chosenGroup and otherGroup and chosenGroup ~= otherGroup, "two groups")
slotOf(chosen):Click()
assert(slotOf(chosen).sel:IsShown(), "chosen")
NS.LineupRemove(NS.LineupTonight(), indexOf(leaving))
NS.Refresh()
assert(slotOf(chosen) and slotOf(chosen).sel:IsShown(), "still chosen after the list changed")
slotOf(other):Click()
assert(groupOf(chosen) == otherGroup and groupOf(other) == chosenGroup, "the chosen player swapped: "
    .. tostring(groupOf(chosen)) .. " " .. tostring(groupOf(other)))
assert(not has(table.concat(STUB.messages or {}, "\n"), "Fehler"), "no error")
