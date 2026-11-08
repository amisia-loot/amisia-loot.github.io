-- The score of the own targets (F-111, D-11): ns.BisSummary sums the rows'
-- scores with the targets and with what is worn (a two-hander once, the worn item where the target
-- is no upgrade), the gain; "Bestes auf Stufe N" is the simulation's result with every source, no
-- exclusions and no own pick; the stat changes targets against worn, biggest first; the score under
-- the planner's doll (D-80; until 2.64.0 the window's head) follows an own pick.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-goals-summary", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "A" },                                                     -- 2: the auction house (off by default)
} }
STUB.areas[2717] = "Geschmolzener Kern"
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, stats, sources, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel = stats, 60
    if sources then
        NS.GEAR.I[id] = { loc, o.classID or 4, o.sub or 4, 60, 4, 1, 141, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
gear(701, "Helm Kern", "HEAD", str(40), { 1 })
gear(702, "Helm Auktion", "HEAD", str(50), { 2 })
gear(703, "Helm Schwach", "HEAD", str(20), { 1 })
gear(704, "Brust Kern", "CHEST", { ITEM_MOD_STRENGTH_SHORT = 30, ITEM_MOD_STAMINA_SHORT = 10 }, { 1 })
gear(705, "Zweihand", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60, ITEM_MOD_STRENGTH_SHORT = 20 }, { 1 }, { classID = 2, sub = 1 })
gear(710, "Alter Helm", "HEAD", str(10))
gear(711, "Alte Brust", "CHEST", { ITEM_MOD_STAMINA_SHORT = 40 })
STUB.worn[1] = LINKS[710]
STUB.worn[5] = LINKS[711]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
NS.BisSetSpec("dps")
local o = NS.BisOpts()
local w = Gear.Weights(o.class, o.spec, o.kind, o.level)

local function score(id, place)
    return Gear.Score(Gear.Stats(id), w, o.level, place, o.class)
end
local res = NS.BisTargets()
local s = NS.BisSummary(res, o)
local now = score(710) + score(711)
assert(near(s.now, now), "now: the worn ones " .. tostring(s.now) .. " " .. now)
local want = score(701) + math.max(score(704), score(711)) + score(705, "2H")
if not res.CHEST[1].upgrade then want = score(701) + score(711) + score(705, "2H") end
assert(near(s.score, want), "with the targets: " .. tostring(s.score) .. " " .. want)
assert(near(s.gain, s.score - s.now), "the gain")
assert(res.plan == "2H" and #res.OFFHAND == 0, "the two-hander counts once")
assert(NS.BisSummary(res, o) == s, "kept with the result")
-- the best on the level: every realistic source, no exclusions; the helm only ever seen at the
-- auction house has no fixed source (D-59)
local best = score(701) + score(704) + score(705, "2H")
assert(near(s.best, best), "Bestes auf Stufe 60: " .. tostring(s.best) .. " " .. best)
assert(s.level == 60)
-- the changes: strength up, stamina down (the old chest), biggest first
assert(#s.stats >= 2, "changes")
local strength, sta
for _, d in ipairs(s.stats) do
    if d.key == "STA" then sta = d end
    if d.key == "STR" then strength = d end
end
assert(strength and strength.up and has(strength.text, "Stärke +"), "strength rises")
assert(sta and not sta.up and has(sta.text, "Ausdauer -"), "stamina falls: " .. tostring(sta and sta.text))
for i = 2, #s.stats do assert(math.abs(s.stats[i - 1].points) >= math.abs(s.stats[i].points), "by weight") end

-- an own pick changes the score and the changes, not the best; an exclusion neither
assert(NS.BisSetPick("HEAD", 703))
local s2 = NS.BisSummary()
assert(near(s2.score, s.score - score(701) + score(703)), "the pick's score counts")
assert(near(s2.best, s.best), "the best stays")
assert(NS.BisExclude("item", 701))
assert(near(NS.BisSummary().best, s.best), "an exclusion leaves the best")
NS.BisClearExcludes()
assert(NS.BisSetPick("HEAD", nil))

---------------------------------------------------------------------------
-- the score under the planner's doll (D-80): "Wertung 350 · +130" over its bar, the tooltip with
-- now, the best and the changes; it follows an own pick
---------------------------------------------------------------------------
NS.ShowPlanner("suggest", nil, "HEAD")
local B = NS.PageFrame("planner").score
s = NS.BisSummary()
assert(plain(B.text:GetText()) == "Wertung " .. Gear.Num(s.score, 0) .. " · +" .. Gear.Num(s.gain, 0), plain(B.text:GetText()))
assert(B.bar.fill._w and B.bar.fill._w > 0 and B.bar.fill._w <= B:GetWidth(), "the fill up to the score")
local lines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(self, text, ...) lines[#lines + 1] = text; return addLine(self, text, ...) end
B:GetScript("OnEnter")(B)
GameTooltip.AddLine = addLine
local tip = table.concat(lines, "|")
assert(has(tip, "jetzt " .. Gear.Num(s.now, 1)) and has(tip, "Bestes auf Stufe 60: " .. Gear.Num(s.best, 1)) and has(tip, s.stats[1].text), tip)
-- a pick: the score follows, the best does not
assert(NS.BisSetPick("HEAD", 703))
assert(plain(B.text:GetText()):find("Wertung " .. Gear.Num(NS.BisSummary().score, 0), 1, true), "the score follows the pick")
assert(NS.BisSummary().best == s.best, "the best does not")
assert(NS.BisSetPick("HEAD", nil))

---------------------------------------------------------------------------
-- review fixes (2026-10-17): the same two rings swapped between the slots score the same; a
-- scale change and an own pick compute Gear.Best no more
---------------------------------------------------------------------------
gear(720, "Ring A", "FINGER", str(30), { 1 }, { sub = 0 })
gear(721, "Ring B", "FINGER", str(20), { 1 }, { sub = 0 })
Gear._reset()
local function summaryWith(a, b)
    STUB.worn = { [1] = LINKS[710], [5] = LINKS[711], [11] = LINKS[a], [12] = LINKS[b] }
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
    local x = NS.BisSummary()
    local stats = {}
    for _, d in ipairs(x.stats) do stats[#stats + 1] = d.text end
    return x.score, x.now, table.concat(stats, ";")
end
local sc1, now1, st1 = summaryWith(720, 721)
local sc2, now2, st2 = summaryWith(721, 720)
assert(near(sc1, sc2) and near(now1, now2), ("swapped rings: %s / %s"):format(sc1, sc2))
assert(st1 == st2, "the same changes: " .. st1 .. " | " .. st2)
-- without the shipped BiS picks: the stub's client never describes their items, so a result made
-- while they wait is never kept (in the game the client answers)
local keepBis = NS.BIS
NS.BIS = { PICK = {} }
NS.BisBump()
NS.BisTargets(); NS.BisSummary()
local bestCalls = 0
local origBest = Gear.Best
Gear.Best = function(...) bestCalls = bestCalls + 1; return origBest(...) end
assert(NS.Set("ui.talentScale", 110))
NS.BisTargets(); NS.BisSummary()
assert(bestCalls == 0, "a scale change computes nothing: " .. bestCalls)
NS.Reset("ui.talentScale")
assert(NS.BisSetPick("HEAD", 703))
NS.BisTargets(); NS.BisSummary()
assert(bestCalls == 0, "an own pick neither (Bestes ignores picks): " .. bestCalls)
assert(NS.BisSetPick("HEAD", nil))
Gear.Best = origBest
NS.BIS = keepBis
NS.BisBump()
