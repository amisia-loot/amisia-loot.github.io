--[[preload
-- raids recorded before the automatic list: a blue trade good in the loot, an epic helm, a reagent
-- in a loot window and a green trade good handed out
local function known(id, name, q, class)
    STUB.items[id] = { name = name, quality = q, link = STUB.link(id, name, q), classID = class, subclassID = 0 }
end
known(71001, "Altes Erz", 3, 7)
known(71002, "Alter Helm", 4, 4)
known(71003, "Altes Fell", 2, 7)
known(71004, "Alter Kern", 3, 5)
AmisiaDB = {
    itemNames = { [71001] = { n = "Altes Erz", q = 3 }, [71002] = { n = "Alter Helm", q = 4 } },
    sessions = {
        { id = "20261001200000-409", date = "2026-10-01", zone = "Geschmolzener Kern", instanceID = 409, start = 100, last = 300,
          members = { Fraktur = { class = "SHAMAN", first = 100, last = 300 } }, loot = {},
          items = { { name = "Fraktur", item = 71001, count = 2, t = 150 }, { name = "Fraktur", item = 71002, count = 1, t = 140 } },
          drops = { ["Creature-0-1-1-1-11988-1"] = { src = "Golemagg", t = 160, items = { [71004] = 1 } } },
          awards = { { id = "0123456789ab", name = "Fraktur", item = 71003, t = 170, kind = "-", src = "Golemagg", to = "player" } } },
    },
}
]]
-- Raids recorded before 2.1 teach their materials once on load (trade goods and reagents of the
-- quality setting, from loot, loot windows and hand-outs); the recorded raids stay as they are.
local m = AmisiaDB.mats
assert(type(m) == "table", "the list exists")
assert(m[71001] and m[71001].name == "Altes Erz" and m[71001].q == 3 and m[71001].first == 150, "from the loot")
assert(m[71004] and m[71004].first == 160, "a reagent from a loot window")
assert(m[71003] and m[71003].first == 170, "a green trade good from a hand-out")
assert(not m[71002], "armor stays out")
assert(NS.MAT_ORDER[1] == 71001 and NS.MAT_ORDER[2] == 71004 and NS.MAT_ORDER[3] == 71003, "in the order first seen")
local s = AmisiaDB.sessions[1]
assert(#s.items == 2 and #s.loot == 0, "the recorded raid is not rewritten")
assert(AmisiaDB.matsScan == 1, "done once")

-- once only: a material taken out is not brought back by the next load
NS.RemoveMat(71001)
NS.MatsLoaded(AmisiaDB)
assert(not NS.MATS[71001] and AmisiaDB.mats[71001].hide, "stays out after the next load")
assert(NS.MAT_ORDER[1] == 71004, "the rest moves up")
