-- Profession trainers read in the game (ProfTrainers.lua, F-155): the offers of an open trainer matched
-- to the data's recipes (by item, else by a unique name), the window's filters set back, the readings
-- saved and checked on load, the real learn rank with "(vom Lehrer)" and the trainer as a source, the
-- "?" of estimated learn ranks, the route's learning cost, the trim once the data holds a reading,
-- `/amisia lehrer`.
local Pr, Tr = NS.Prof, NS.ProfTrainers
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
Pr._reset()
Tr._reset()
AmisiaDB.trainers = nil

-- before any reading: the trainer recipe 1252229 (T1, learn 1) is an estimate, the others are not
local boots = Pr.Recipe(1252229)
assert(not Pr.LearnExact(boots) and Pr.LearnRank(boots) == 50, "estimated: the yellow rank")
assert(Pr.LearnExact(Pr.Recipe(2663)) and Pr.LearnExact(Pr.Recipe(3321)), "with the profession, by recipe item")
assert(not Pr.HasTrainer(boots) and Pr.PresumedTrainer(Pr.Recipe(9999)) == false, "the skill line has a trainer list")

-- the trainer window: a header, the boots (by the item it makes), the bracers (by name, no item link),
-- an offer the data does not have; the filter "used" is off and "unavailable" too
local OFFERS = {
    { name = "Schmiedekunst", category = "header" },
    { name = "Edelsteinbesetzte Kupferstiefel", category = "available", item = 251001, rank = 35, cost = 150, level = 10 },
    { name = "Kupferarmschienen", category = "used", rank = 1, cost = 10, level = 5 },
    { name = "Unbekanntes Ding", category = "available", item = 999999, rank = 70, cost = 1, level = 1 },
}
local filters = { available = 1, unavailable = 0, used = 0 }
local setCalls = {}
local function visible()
    local out = {}
    for _, o in ipairs(OFFERS) do
        if o.category == "header" or filters[o.category] == 1 then out[#out + 1] = o end
    end
    return out
end
GetTrainerServiceTypeFilter = function(k) return filters[k] == 1 end
SetTrainerServiceTypeFilter = function(k, on) filters[k] = on and on ~= 0 and 1 or 0 setCalls[#setCalls + 1] = k .. "=" .. filters[k] end
GetNumTrainerServices = function() return #visible() end
GetTrainerServiceInfo = function(i) local o = visible()[i] return o.name, nil, o.category end
GetTrainerServiceItemLink = function(i) local o = visible()[i] return o.item and ("|Hitem:" .. o.item .. "::|h[x]|h") or nil end
GetTrainerServiceSkillReq = function(i) local o = visible()[i] return "Schmiedekunst", o.rank, true end
GetTrainerServiceCost = function(i) return visible()[i].cost end
GetTrainerServiceLevelReq = function(i) return visible()[i].level end
STUB.npcGUID = "Creature-0-3110-0-47-80502-00002E7CF2"
STUB.npc = "Brikk"
STUB.fire("TRAINER_SHOW")
STUB.tick(1)

local saved = AmisiaDB.trainers and AmisiaDB.trainers[80502]
assert(saved and saved.n == "Brikk" and saved.t == math.floor(saved.t) and saved.t > 0 and saved.t <= STUB.now, "the trainer saved")
assert(saved.s[1252229] == "35:150:10" and saved.s[2663] == "1:10:5", "by item and by name, also the used one")
local n = 0
for _ in pairs(saved.s) do n = n + 1 end
assert(n == 2, "nothing for the offer the data does not have")
assert(filters.unavailable == 0 and filters.used == 0 and filters.available == 1, "the filters as they were")
assert(#setCalls == 4, "two on, two back: " .. table.concat(setCalls, ","))
-- read again without the filter functions (only the available offers): the earlier ones stay
local getF, setF = GetTrainerServiceTypeFilter, SetTrainerServiceTypeFilter
GetTrainerServiceTypeFilter, SetTrainerServiceTypeFilter = nil, nil
assert(Tr.Read() == 2 and AmisiaDB.trainers[80502].s[2663] == "1:10:5", "the used one kept")
GetTrainerServiceTypeFilter, SetTrainerServiceTypeFilter = getF, setF
saved = AmisiaDB.trainers[80502]

-- the real learn rank, exact, from the trainer; the trainer as a source; the route's learning cost
assert(Pr.LearnRank(boots) == 35 and Pr.LearnExact(boots) and Pr.LearnFromTrainer(boots) == "own", "the trainer's rank")
assert(Pr.HasTrainer(boots) and Pr.SourceKinds(boots).T, "a trainer recipe")
local src = Pr.Sources(boots)
local line
for _, s in ipairs(src) do if s.npc == 80502 then line = s end end
assert(line and line.kind == "T" and has(line.text, "Lehrer: Brikk") and has(line.text, "ab 35"), line and line.text)
assert(NS.ProfRoute.LearnCost(1252229) == 150, "the cost read")

-- a second reading of the same recipe elsewhere, later: the newest wins
STUB.now = STUB.now + 100
AmisiaDB.trainers[80100] = { t = STUB.now, n = "Suppla", s = { [1252229] = "40:200:10" } }
Tr._reset()
assert(Pr.LearnRank(boots) == 40 and Tr.Of(1252229).npc == 80100, "the newest reading")

-- checked on load: bad entries dropped, good ones kept
AmisiaDB.trainers.bad = { t = 1, s = { [1] = "1:1:1" } }
AmisiaDB.trainers[80300] = { t = 5, s = { [2663] = "x" } }
AmisiaDB.trainers[80400] = { t = 5, n = "A|cffff0000B", p = "nope", s = { [2663] = "2:3:4", foo = "1:1:1" } }
NS.TrainersLoaded(AmisiaDB)
assert(AmisiaDB.trainers.bad == nil and AmisiaDB.trainers[80300] == nil, "no npc id, no good offer")
local e = AmisiaDB.trainers[80400]
assert(e and e.n == nil and e.p == nil and e.s[2663] == "2:3:4" and e.s.foo == nil, "field by field")
assert(AmisiaDB.trainers[80502].s[1252229] == "35:150:10", "a good one kept")

-- the page: "(vom Lehrer)" in Details, the head's count of estimated learn ranks
NS.Dispatch("berufe schmied")
local f = NS.PageFrame("professions")
for _, r in ipairs(f.list.rows) do
    if r:IsShown() and r.item and r.item.recipe and r.item.recipe.spell == 1252229 then r:Click() end
end
assert(has(f.rd.info:GetText(), "(vom Lehrer)") and has(f.rd.info:GetText(), "40"), f.rd.info:GetText())

-- the data holds a reading (TD): dropped here once the data is in use; data trainers count as exact
NS.PROFESSIONS.TD = { [80502] = STUB.now }
NS.PROFESSIONS.R[164][3] = "1252229:251001:1:35:50:80:T1,N80502"
Pr._reset()
Tr._reset()
assert(AmisiaDB.trainers[80502] ~= nil, "not trimmed before the data is used")
assert(Tr.Of(2663) ~= nil)
assert(AmisiaDB.trainers[80502] == nil and AmisiaDB.trainers[80100] ~= nil, "the archived reading dropped, the newer kept")
local b2 = Pr.Recipe(1252229)
assert(#b2.trainers == 1 and b2.trainers[1] == 80502 and #b2.src == 1, "N is a trainer, not a source token")
AmisiaDB.trainers[80100] = nil
Tr._reset()
assert(Pr.LearnRank(b2) == 35 and Pr.LearnExact(b2) and Pr.LearnFromTrainer(b2) == "data", "the data's trainer rank")
local brikk
for _, s in ipairs(Pr.Sources(b2)) do if s.npc == 80502 then brikk = s end end
assert(brikk and has(brikk.text, "Lehrer: Brikk") and brikk.point ~= nil, "the data's trainer with its place")

-- in combat nothing is read
InCombatLockdown = function() return true end
STUB.npcGUID = "Creature-0-3110-0-47-80201-00002E7CF2"
STUB.fire("TRAINER_SHOW")
STUB.tick(3)
assert(AmisiaDB.trainers[80201] == nil, "not in combat")
InCombatLockdown = function() return false end

-- the command
local said = {}
local realMsg = NS.msg
NS.msg = function(t) said[#said + 1] = t end
NS.Dispatch("lehrer")
NS.msg = realMsg
assert(has(said[1], "Lehrer: 1 gelesen, 1 Angebote"), said[1])
print("prof trainers ok")
