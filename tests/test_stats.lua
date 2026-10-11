-- Loot statistics (Raid/Stats.lua): per player over every character (alts counted for the main,
-- the split per character kept), items won with the MS/OS/SR split, items per raid, attendance as
-- raids there (the bench counts, late is counted) over the raids since first seen, the last item,
-- bosses seen, the longest streak, items per week; the ranges (4 weeks, the phase since the newest
-- raid first showed up, all), the class and role filters, sorting, and the hall of fame.
local DAY = 86400
local now = STUB.now

-- four raids, oldest first: BT, BT, Hyjal (the newest raid: the phase starts here), BT
local function raid(id, ago, zone, inst)
    local start = now - ago * DAY
    local s = { id = id, date = date("%Y-%m-%d", start), zone = zone, instanceID = inst, start = start, last = start + 3600,
                members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    AmisiaDB.sessions[#AmisiaDB.sessions + 1] = s
    return s
end
local function member(s, name, class, opts)
    opts = opts or {}
    s.members[name] = { class = class, first = s.start + (opts.after or 0), last = s.start + 3000, late = opts.late }
end
local function award(s, name, item, kind, to)
    NS.AddAwardTo(s, { name = name, item = item, kind = kind, src = "?", t = s.start + 100, to = to })
end

local s1 = raid("s1", 40, "Der Schwarze Tempel", 564)
member(s1, "Anna", "PRIEST"); member(s1, "Bob", "MAGE")
award(s1, "Anna", 1001, "MS")

local s2 = raid("s2", 20, "Der Schwarze Tempel", 564)
member(s2, "Anna", "PRIEST"); member(s2, "Bob", "MAGE", { late = true }); member(s2, "Chorf", "WARRIOR")
s2.bench.Dora = { t = s2.start, class = "ROGUE", by = "Anna" }
award(s2, "Bob", 1002, "OS"); award(s2, "Chorf", 1003, "MS")
s2.kills = { { enc = 601, name = "Naj'entus", start = s2.start + 500, t = s2.start + 600, ok = true, who = { "Anna", "Bob", "Chorf" } },
             { enc = 602, name = "Supremus", start = s2.start + 700, t = s2.start + 800, ok = false, who = { "Anna" } } }

local s3 = raid("s3", 10, "Hyjal", 534)
member(s3, "Anna", "PRIEST"); member(s3, "Bobalt", "MAGE"); member(s3, "Dora", "ROGUE", { after = 1200 })
award(s3, "Bobalt", 1004, "SR"); award(s3, "Bobalt", 1005, "MS")
award(s3, "Anna", 1006, "MS", "bank")      -- the bank is nobody's item
award(s3, "-", 1008, "-", "de")
-- a kill without a list of who was there: the members seen before it count
s3.kills = { { enc = 618, name = "Winterchill", start = s3.start + 500, t = s3.start + 600, ok = true } }
local gone = NS.AddAwardTo(s3, { name = "Anna", item = 1009, kind = "MS", src = "?", t = s3.start + 200 })
NS.DeleteAward(s3, gone.id)                -- a deleted award does not count

local s4 = raid("s4", 3, "Der Schwarze Tempel", 564)
member(s4, "Anna", "PRIEST", { late = true }); member(s4, "Chorf", "WARRIOR")
award(s4, "Chorf", 1007, "MS")
s4.kills = { { enc = 603, name = "Teron", start = s4.start + 500, t = s4.start + 600, ok = true, who = { "Anna", "Chorf" } } }

assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-01\nA Bobalt Bob\n#END"))

local function byName(res)
    local out = {}
    for _, p in ipairs(res.players) do out[p.name] = p end
    return out
end
local function near(a, b) return math.abs(a - b) < 0.001 end

---------------------------------------------------------------------------
-- every raid
---------------------------------------------------------------------------
local res = NS.StatsBuild({ range = "all" })
assert(res.raids == 4, "four raids: " .. tostring(res.raids))
local P = byName(res)
assert(#res.players == 4, "four players: " .. #res.players)
assert(not P.Bobalt, "an alt counts for its main")

local a = P.Anna
assert(a.items == 1 and a.ms == 1 and a.os == 0 and a.sr == 0, "Anna: one MS item, the bank and the deleted one left out")
assert(a.raids == 4 and a.total == 4 and near(a.rate, 1) and a.late == 1 and a.bench == 0, "Anna was at all four, once late")
assert(near(a.perRaid, 0.25), "one item in four raids")
assert(a.last == s1.start + 100, "the last item")
assert(a.bosses == 3, "Anna saw three kills (a wipe is no boss seen): " .. a.bosses)
assert(a.streak == 4, "four in a row")
assert(a.class == "PRIEST" and a.role == "unknown", "a priest may heal or deal damage: unknown")

local b = P.Bob
assert(b.items == 3 and b.ms == 1 and b.os == 1 and b.sr == 1, "Bob with his alt: MS, OS, SR")
assert(b.raids == 3 and b.total == 4 and near(b.rate, 0.75) and b.late == 1, "Bob: three of four since first seen")
assert(b.bosses == 2, "Naj'entus as Bob, Winterchill as Bobalt: " .. b.bosses)
assert(b.streak == 3)
assert(b.class == "MAGE" and b.role == "dps", "a mage deals damage")
assert(#b.chars == 2, "two characters")
local split = {}
for _, c in ipairs(b.chars) do split[c.name] = c end
assert(split.Bob.items == 1 and split.Bob.raids == 2, "Bob himself: one item, two raids")
assert(split.Bobalt.items == 2 and split.Bobalt.raids == 1, "the alt: two items, one raid")
assert(b.chars[1].name == "Bob", "the main first")

local c = P.Chorf
assert(c.items == 2 and c.ms == 2 and c.raids == 2 and c.total == 3, "Chorf from his first raid on: 2 of 3")
assert(c.streak == 1 and c.bosses == 2)

local d = P.Dora
assert(d.items == 0 and d.raids == 2 and d.total == 3 and d.bench == 1, "Dora: on the bench once, it counts as there")
assert(d.bosses == 0, "Dora came after the kill")
assert(d.streak == 2 and d.last == nil)
assert(d.class == "ROGUE" and d.role == "dps", "the class from the bench entry")

-- items per week, the newest week first
assert(#b.weeks == 8, "eight weeks")
assert(b.weeks[1] == 0 and b.weeks[2] == 2 and b.weeks[3] == 1, "two items ten days ago, one twenty days ago")

---------------------------------------------------------------------------
-- the ranges
---------------------------------------------------------------------------
res = NS.StatsBuild({ range = "4w" })
assert(res.raids == 3, "three raids in four weeks")
P = byName(res)
assert(P.Anna.items == 0 and P.Anna.raids == 3 and P.Anna.total == 3)
assert(P.Bob.items == 3 and P.Bob.raids == 2 and P.Bob.total == 3, "Bob first seen before the range: every raid in it counts")
assert(P.Bob.weeks[2] == 2, "the weeks do not depend on the range")

res = NS.StatsBuild({ range = "phase" })
assert(res.raids == 2, "the phase began with the first Hyjal raid")
assert(res.phase and res.phase.zone == "Hyjal" and res.phase.from == s3.start, "the phase start is named")
P = byName(res)
assert(P.Bob.items == 2 and P.Bob.raids == 1 and P.Bob.total == 2)
assert(P.Anna.raids == 2 and near(P.Anna.rate, 1))

---------------------------------------------------------------------------
-- filters and sorting
---------------------------------------------------------------------------
res = NS.StatsBuild({ range = "all", class = "MAGE" })
assert(#res.players == 1 and res.players[1].name == "Bob", "only mages")
res = NS.StatsBuild({ range = "all", role = "dps" })
assert(#res.players == 2, "the mage and the rogue")
res = NS.StatsBuild({ range = "all", role = "unknown" })
assert(#res.players == 2, "the priest and the warrior")
assert(NS.StatsRole("HUNTER") == "dps" and NS.StatsRole("WARLOCK") == "dps" and NS.StatsRole("DRUID") == "unknown")
assert(NS.StatsRole(nil) == "unknown")

res = NS.StatsBuild({ range = "all" })
local function order(list)
    local out = {}
    for i, p in ipairs(list) do out[i] = p.name end
    return table.concat(out, ",")
end
NS.StatsSort(res.players, "items", true)
assert(order(res.players) == "Bob,Chorf,Anna,Dora", order(res.players))
NS.StatsSort(res.players, "rate", true)
assert(order(res.players) == "Anna,Bob,Chorf,Dora", "ties by name: " .. order(res.players))
NS.StatsSort(res.players, "name", false)
assert(order(res.players) == "Anna,Bob,Chorf,Dora")
NS.StatsSort(res.players, "last", true)
assert(res.players[1].name == "Chorf" and res.players[4].name == "Dora", "no item sorts last: " .. order(res.players))
NS.StatsSort(res.players, "perRaid", false)
assert(res.players[1].name == "Dora")

---------------------------------------------------------------------------
-- hall of fame
---------------------------------------------------------------------------
assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-01\nW 1003 3 Anna\nW 1003 2 Dora\nW 1005 2 Kim\n#END"))
local fame = {}
for _, e in ipairs(NS.StatsFame(NS.StatsBuild({ range = "all" }))) do fame[e.key] = e end
assert(fame.items.name == "Bob" and fame.items.n == 3, "most items")
assert(fame.rate.name == "Anna" and near(fame.rate.n, 1), "best attendance")
assert(fame.bosses.name == "Anna" and fame.bosses.n == 3, "most bosses seen")
assert(fame.streak.name == "Anna" and fame.streak.n == 4, "longest streak")
assert(fame.wanted.name == "Chorf" and fame.wanted.item == 1003 and fame.wanted.n == 2, "the most wished item that was won")
assert(not fame.upgrade, "no upgrade numbers: the addon does not know them for the past")
for _, e in pairs(fame) do assert(type(e.title) == "string" and type(e.text) == "string", "every entry has a title and a text") end

-- attendance needs three raids: a single raid at 100 % is no record
local s5 = raid("s5", 1, "Der Schwarze Tempel", 564)
member(s5, "Neu", "PALADIN")
fame = {}
for _, e in ipairs(NS.StatsFame(NS.StatsBuild({ range = "all" }))) do fame[e.key] = e end
assert(fame.rate.name == "Anna" and near(fame.rate.n, 0.8), "one raid at 100 % is not enough for best attendance")

-- nothing recorded: no players, no fame, no error
for i = #AmisiaDB.sessions, 1, -1 do AmisiaDB.sessions[i] = nil end
res = NS.StatsBuild({ range = "phase" })
assert(res.raids == 0 and #res.players == 0 and res.phase == nil)
assert(#NS.StatsFame(res) == 0)
