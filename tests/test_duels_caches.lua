-- Duels (F-106, F-114, Core/Duels.lua): a class or a tree learned patches the rows and the numbers in
-- memory instead of building them again; patched they equal a full build (D.All, D.PlayerStats and
-- what D.Stats, D.Board, D.ClassTable and D.Rivals make of them), also for a name recorded in two
-- spellings. A duel and a tournament start or stop still build them again.
local D = NS.Duels
local d = AmisiaDB.duels
STUB.player = "Vuloo"

-- a deep copy without functions, keys sorted, as text: two tables give the same text when equal
local function dump(v, seen)
    if type(v) ~= "table" then return type(v) == "string" and ("%q"):format(v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local now = time()
d.list, d.zones, d.cls, d.spec = {}, { "Goldhain" }, { Anna = "MAGE" }, { Anna = 2 }
local names = { "Anna", "Bob Eisherz", "Cara", "Dirk", "Bob eisherz", "Vuloo" }
for i = 1, 400 do
    local w, l = names[i % 6 + 1], names[math.floor(i / 6) % 6 + 1]
    if w ~= l and w:lower() ~= l:lower() then
        d.list[#d.list + 1] = ("%d\t%s\t%s\t1\t%s%s"):format(now - 1000 + i, w, l, i % 3 == 0 and "F" or "K",
            i % 7 == 0 and "\t1" or "")
    end
end
D.Changed()

local function views()
    local rows = D.All()
    local out = { rows = rows, stats = {} }
    for _, n in ipairs(names) do
        local e = D.PlayerStats(n)
        out.stats[n] = e
        local nemesis, favourite = D.Rivals(e)
        out["rivals " .. n] = { nemesis, favourite }
    end
    out.board = D.Board(rows, {})
    out.boardMage = D.Board(rows, { class = "MAGE", sort = "name" })
    out.classes = { D.ClassTable(rows) }
    out.mage = { D.ClassTable(rows, "MAGE") }
    out.spec = { D.ClassTable(rows, nil, true) }
    out.filtered = D.Filter({ class = "WARRIOR" })
    return dump(out)
end

local function rebuilt()
    D.Changed(true)
    return views()
end

-- the caches are built, then a class and a tree are learned
views()
local before = D.All()
assert(D.Learn("Bob Eisherz", "WARRIOR"), "Bob learns his class")
assert(D.All() == before, "the rows are patched, not built again")
local patched = views()
assert(patched == rebuilt(), "a patched class equals a full build")
local carried = 0
for _, r in ipairs(D.All()) do
    if r.wc == "WARRIOR" or r.lc == "WARRIOR" then carried = carried + 1 end
end
assert(carried > 0, "the rows carry the class")

views()
before = D.All()
assert(D.LearnSpec("Bob Eisherz", 3), "Bob learns his tree")
assert(D.All() == before, "patched")
patched = views()
assert(patched == rebuilt(), "a patched tree equals a full build")

-- the name recorded in a second spelling keeps its own (unknown) class, as a build gives it
views()
assert(D.Learn("Cara", "PRIEST") and D.LearnSpec("Cara", 1), "Cara")
patched = views()
assert(patched == rebuilt(), "class and tree in a row")

-- only the rows exist (no numbers yet): patched as well
D.Changed(true)
D.All()
assert(D.Learn("Dirk", "ROGUE"), "Dirk")
patched = views()
assert(patched == rebuilt(), "the rows alone patched")

-- nothing in memory: built on the next read
D.Changed(true)
assert(D.LearnSpec("Dirk", 2), "Dirk's tree")
patched = views()
assert(patched == rebuilt(), "nothing built before")

-- a tournament start and stop still build the rows again
before = D.All()
assert(D.TourStart(), "tournament")
assert(D.All() ~= before, "a tournament start builds again")
before = D.All()
assert(D.TourStop(), "stopped")
assert(D.All() ~= before, "a tournament stop builds again")

-- a learned class tells the page
local fired = 0
NS.Listen("DUELS", function() fired = fired + 1 end)
d.list[#d.list + 1] = ("%d\t%s\t%s\t1\tK"):format(now, "Emil", "Anna")
D.Changed()
views()
assert(D.Learn("Emil", "HUNTER") and fired == 2, "DUELS fires on a learned class")
assert(views() == rebuilt(), "a new name patched")
