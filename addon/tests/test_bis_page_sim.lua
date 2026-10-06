-- The gear page's 2.4 parts (Pages/Gear.lua) on the real Forever data: the weapon plan beside the
-- source chips, the notes of an option, option 1 against 2 and against the worn item on the
-- explanation's hover, "Warum?" with the reason of the weights, and the simulation view (class,
-- spec, level, plan; seventeen slots from ns.BisFor); the layout at the main window's size.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"
STUB.instance = { name = "Elwynn", type = "none", id = 0 }
NS.BisSetSpec("dps")

NS.ShowGear("goals")
local f = NS.GearPageFrame()
assert(f and f:IsShown())
assert(f.plan:IsShown() and plain(f.plan.label:GetText()) == "Waffen: automatisch", f.plan.label:GetText())
f.plan.onPick("2H")
assert(NS.BisChar().plan == "2H" and NS.BisOpts().plan == "2H", "the picker sets the character's plan")
NS.Refresh()
assert(plain(f.plan.label:GetText()) == "Waffen: Zweihand")
NS.BisSetPlan("auto")
NS.Refresh()

-- the explanation's hover: the notes and the comparisons of the chosen slot
local G = f.goals
NS.ShowGear("goals", "CHEST")
local lines = G.explainHit.lines or {}
local joined = table.concat(lines, "\n")
local res = NS.BisTargets()
if res.CHEST[2] then
    assert(has(joined, "Option 1") and (has(joined, "vorn") or has(joined, "gleichauf")), joined)
end
G.explainHit:GetScript("OnEnter")(G.explainHit)
G.explainHit:GetScript("OnLeave")(G.explainHit)
-- "Warum?"
G.why:GetScript("OnEnter")(G.why)
G.why:GetScript("OnLeave")(G.why)

-- the simulation
G.sim:Click()
assert(AmisiaDB.settings.bis.view == "sim", "the button opens the simulation")
local S = f.sim
assert(S:IsShown() and not G:IsShown())
assert(not f.plan:IsShown(), "the own plan picker belongs to the targets")
assert(#S.list.items == #Gear.SLOTS, "seventeen slots")
assert(#S.class.values == 9 and S.class:GetValue() == "WARRIOR" and S.level.current == 30, "starts as the own character")
S.class.onPick("MAGE")
NS.Refresh()
local sim = NS.BisSimState()
assert(sim.class == "MAGE" and sim.spec == "frost", "a new class takes its first spec: " .. tostring(sim.spec))
assert(S.spec.values[1].text == "Frost" and #S.spec.values == 3)
S.level.plus:Click()
assert(NS.BisSimState().level == 31)
NS.Refresh()
local best = 0
for _, e in ipairs(S.list.items) do
    if e.opt then
        best = best + 1
        assert(Gear.Usable("MAGE", Gear.Item(e.opt[1]), 31), "a mage can wear " .. e.opt[1])
    end
end
assert(best >= 8, "most slots have an option: " .. best)
assert(has(plain(S.info:GetText()), "Ohne Besitz") and has(plain(S.info:GetText()), "Frost"), S.info:GetText())
-- the command
NS.ShowGear("goals")
NS.Dispatch("bis sim")
assert(AmisiaDB.settings.bis.view == "sim")

-- layout at the main window's size
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("sim head", S.class, S.spec, S.level, S.plan, S.back)
Lay.row("sim list", S.list, S.list.bar)
local _, sr = Lay.span(S.list.rows[1].score)
assert(sr <= 590, "the score ends in the row: " .. sr)
NS.ShowGear("goals")
Lay.row("sources and plan", f.src.Q, f.src.D, f.src.C, f.src.V, f.src.W, f.src.A, f.src.P, f.plan)
Lay.row("title row", G.title, G.why, G.sim)
S.back:Click()
assert(AmisiaDB.settings.bis.view == "goals")
