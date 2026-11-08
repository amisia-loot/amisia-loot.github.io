--[[preload
STUB.noDressUp = true
]]
-- The page Ausrüstungsplaner on a client whose DressUpModel lacks SetUnit, Undress and TryOn (F-110,
-- Sonderfälle; until 2.64.0 the window "Ausrüstungsziele", D-80): the self-test says what is missing,
-- the doll shows the slots without a model and "Modell nicht verfügbar", the rest works; without gear
-- data the command says so.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

local report = NS.SelfTest.Run().text
assert(has(report, "Charaktermodell") and has(report, "DressUpModel ohne SetUnit, Undress, TryOn"), "the self-test names what is missing")

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.ShowPlanner("goals")
local f = assert(NS.PageFrame("planner"), "the page opens")
local d = f.doll
assert(d.model == nil, "no model")
assert(d.noModel:GetText() == "Modell nicht verfügbar" and d.noModel.vis ~= false, "the hint instead")
local n = 0
for _ in pairs(d.slots) do n = n + 1 end
assert(n == 19, "the slots all the same")
f.showWorn:Click()
f.showGoals:Click()
assert(f.list.items[1].header, "the goals list works")

-- without gear data: a chat line
local avail = NS.Gear.Available
NS.Gear.Available = function() return false end
local before = #STUB.messages
NS.Dispatch("bis gross")
local said = table.concat(STUB.messages, "\n", before + 1)
NS.Gear.Available = avail
assert(has(said, "Für diesen Client gibt es keine Ausrüstungsdaten."), "the chat says why: " .. said)
print("planner without model ok")
