-- The score head of the window "Ausrüstungsziele" (F-111, D-11): ns.BisSummary sums the rows'
-- scores with the targets and with what is worn (a two-hander once, the worn item where the target
-- is no upgrade), the gain; "Bestes auf Stufe N" is the simulation's result with every source, no
-- exclusions and no own pick; the stat changes targets against worn, biggest first; the head in the
-- window (Wertung, jetzt, +N, the bar, six changes, the tooltips) follows an own pick.
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
-- the best on the level: every source (the auction house too), no exclusions
local best = score(702) + score(704) + score(705, "2H")
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
-- the head in the window
---------------------------------------------------------------------------
local win = assert(NS.ShowGoalsFrame())
local B = win.score
s = NS.BisSummary()
assert(B.score:GetText() == "Wertung " .. Gear.Num(s.score, 1), B.score:GetText())
assert(plain(B.now:GetText()) == "jetzt " .. Gear.Num(s.now, 1), plain(B.now:GetText()))
assert(plain(B.gain:GetText()) == "+" .. Gear.Num(s.gain, 1), plain(B.gain:GetText()))
assert(B.best:GetText() == "Bestes auf Stufe 60: " .. Gear.Num(s.best, 1), B.best:GetText())
assert(B.bar.fill._w and B.bar.fill._w > 0 and B.bar.fill._w <= NS.Theme.GOALS.DOLL_W, "the fill up to the score")
assert(B.cells[1].label:GetText() == s.stats[1].label and has(plain(B.cells[1].value:GetText()), "+"), "the first change")
assert(#B.cells == 6, "six at most")
-- the tooltips: what "Bestes" means, every change
B.bar:GetScript("OnEnter")(B.bar)
B.stats:GetScript("OnEnter")(B.stats)
-- a pick: the head follows
win.side.slot = "HEAD"
NS.GoalsFrameState().slot = "HEAD"
assert(NS.BisSetPick("HEAD", 703))
assert(B.score:GetText() == "Wertung " .. Gear.Num(NS.BisSummary().score, 1), "the head follows the pick")
assert(B.best:GetText() == "Bestes auf Stufe 60: " .. Gear.Num(s.best, 1), "the best does not")
assert(NS.BisSetPick("HEAD", nil))
