--[[preload
STUB.noDressUp = true
]]
-- The window "Ausrüstungsziele" on a client whose DressUpModel lacks SetUnit, Undress and TryOn
-- (F-110, Sonderfälle): the self-test says what is missing, the doll shows the slots without a
-- model and "Modell nicht verfügbar", the rest works; without gear data the command says so.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

local report = NS.SelfTest.Run().text
assert(has(report, "Charaktermodell") and has(report, "DressUpModel ohne SetUnit, Undress, TryOn"), "the self-test names what is missing")

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local win = assert(NS.ShowGoalsFrame(), "the window opens")
local d = win.doll
assert(d.model == nil, "no model")
assert(d.noModel:GetText() == "Modell nicht verfügbar" and d.noModel.vis ~= false, "the hint instead")
assert(d.hint:GetText() == "", "no mouse hint without a model")
local n = 0
for _ in pairs(d.slots) do n = n + 1 end
assert(n == 17, "the slots all the same")
d.worn:Click()
d.goals:Click()
assert(win.list.items[1].header, "the list works")
win:Hide()

-- without gear data: no window, a chat line
local avail = NS.Gear.Available
NS.Gear.Available = function() return false end

local before = #STUB.messages
NS.Dispatch("bis gross")
assert(not win:IsShown(), "it stays closed")
local said = table.concat(STUB.messages, "\n", before + 1)
assert(has(said, "Für diesen Client gibt es keine Ausrüstungsdaten."), "the chat says why: " .. said)
assert(NS.ShowGoalsFrame() == nil, "nor through the function")
NS.Gear.Available = avail
