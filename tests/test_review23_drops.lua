-- Review of the 2.3 drop records (Drops.lua): trash looted after a boss kill never becomes the kill
-- or takes the boss's name; merged records stay within the item caps, keep the own origin and the
-- earlier day; nothing after today; a kill counts once against the base stock's last day; merging at
-- the 4000 cap is cheap and refuses what would go again at once; the names of encounters and
-- instances are capped; a name of any bytes is cleaned in bounded time; learned names fire
-- DROPS_CHANGED.
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local d = AmisiaDB.drops
local today = NS.DropsToday()

---------------------------------------------------------------------------
-- 1. trash after a boss kill event: the boss corpse takes the event over
---------------------------------------------------------------------------
NS.BIS = { O = {}, OT = today - 1, DG = {} }
STUB.instance = { name = "Halle der Thane", type = "party", id = 2834, diff = 1 }
local green = STUB.item(219004, "Ring", 2)
local blue = STUB.item(219005, "Umhang", 3)
STUB.fire("ENCOUNTER_END", 3012, "Faldrim", 1, 5, 1)
local ADD = "Creature-0-3110-2834-47-99001-00002E7C01"
STUB.loot = { { link = green, name = "Ring", src = ADD } }
STUB.fire("LOOT_OPENED")
local BOSS = "Creature-0-3110-2834-47-213450-00002E7CF2"
STUB.loot = { { link = blue, name = "Umhang", src = BOSS } }
STUB.fire("LOOT_OPENED")
local hAdd, hBoss = NS.DropsKillID(ADD), NS.DropsKillID(BOSS)
assert(d.k[hAdd] == nil, "the add looted first is not a kill")
assert(d.k[hBoss] and d.k[hBoss].enc == 3012, "the boss corpse has the kill event")
assert(d.npc[99001] == nil, "the add never keeps the boss's name")
assert(d.npc[213450] == "Faldrim", "the boss is named after the event")
assert(not NS.DropsExportText():find("DN 99001", 1, true), "no add in the export")
assert(NS.DropsAdded() == 1, "one own new record: " .. NS.DropsAdded())

---------------------------------------------------------------------------
-- 2. merging: the caps, the own origin, today at most
---------------------------------------------------------------------------
local mine = { h = "a2300001", npc = 213450, inst = 2834, diff = 1, day = today, o = d.me, src = "G", it = { [219004] = 1 } }
assert(NS.DropsMerge(mine) == "new")
d.k.a2300001.mine = true
local big = {}
for i = 1, 30 do big[219000 + i] = 200 end
assert(NS.DropsMerge({ h = "a2300001", npc = 213450, inst = 2834, diff = 1, day = today, o = "00000000", src = "G", it = big }) == nil,
    "30 items of 200 are refused")
local full = {}
for i = 1, 16 do full[219100 + i] = 20 end
assert(NS.DropsMerge({ h = "a2300001", npc = 213450, inst = 2834, diff = 1, day = today, o = "00000000", src = "G", it = full }) == "merged")
local r = d.k.a2300001
assert(size(r.it) == 16, "16 items at most: " .. size(r.it))
for id, c in pairs(r.it) do assert(c <= 20, "20 of one item at most") end
assert(r.it[219004] == 1, "the 16 lowest ids stay")
assert(r.o == d.me, "an own record keeps the own origin")
assert(NS.DropsMerge({ h = "a2300002", npc = 213450, inst = 2834, diff = 1, day = today + 1, o = "11111111", src = "G", it = {} }) == nil,
    "a day after today is refused")
assert(NS.DropsMerge({ h = "a2300003", npc = 213450, inst = 2834, diff = 1, day = today, o = "11111111", src = "G", it = { [1] = 21 } }) == nil,
    "21 of one item is refused")
-- the order does not matter for the capped union
local function snap(list)
    local saved = AmisiaDB.drops
    AmisiaDB.drops = { v = 1, me = "12345678", k = {}, npc = {}, inst = {}, enc = {}, peers = {} }
    for _, x in ipairs(list) do NS.DropsMerge(x) end
    local out = STUB.dump(AmisiaDB.drops.k)
    AmisiaDB.drops = saved
    return out
end
local A, B = {}, {}
for i = 1, 12 do A[100 + i] = 1; B[106 + i] = 2 end
local ra = { h = "b2300001", npc = 5, inst = 2834, diff = 1, day = today, o = "0000000a", src = "G", it = A }
local rb = { h = "b2300001", npc = 5, inst = 2834, diff = 1, day = today, o = "0000000b", src = "G", it = B }
assert(snap({ ra, rb }) == snap({ rb, ra }), "the capped union in any order")

---------------------------------------------------------------------------
-- 5. midnight: the earlier day; the base stock's last day counts once
---------------------------------------------------------------------------
assert(NS.DropsMerge({ h = "c2300001", npc = 500, inst = 2834, diff = 1, day = today, o = "22222222", src = "G", it = { [601] = 1 } }) == "new")
assert(NS.DropsMerge({ h = "c2300001", npc = 500, inst = 2834, diff = 1, day = today - 1, o = "22222222", src = "G", it = { [601] = 1 } }) == "merged")
assert(d.k.c2300001.day == today - 1, "the earlier day")
NS.BIS = { O = { [500] = { k = 10, it = { [601] = 4 } } }, OT = today - 2, OI = { c2300001 = true } }
local _, n, K = NS.DropRate(500, 601)
assert(K == 10 and n == 4, "a kill the base stock holds counts once: " .. K .. " " .. n)
NS.BIS.OI = nil
_, n, K = NS.DropRate(500, 601)
assert(K == 11 and n == 5, "without the id it counts")

---------------------------------------------------------------------------
-- 6. at the 4000 cap: cheap merges, nothing older than the oldest kept one
---------------------------------------------------------------------------
NS.BIS = nil
AmisiaDB.drops = { v = 1, me = "12345678", k = {}, npc = {}, inst = {}, enc = {}, peers = {} }
NS.DropsMigrate(AmisiaDB)
d = AmisiaDB.drops
for i = 1, 4000 do
    d.k[("%08x"):format(i)] = { npc = 1000 + i % 50, inst = 2000 + i % 12, diff = 1, day = today - 1 - (i % 26), o = d.me, src = "G",
                               it = { [219004] = 1 } }
end
NS.DropsPrune()
local list = {}
for i = 1, 300 do list[i] = { h = ("f%07x"):format(i), npc = 1000, inst = 2001, diff = 1, day = today, o = "33333333", src = "G", it = { [219004] = 1 } } end
local t0 = os.clock()
for _, x in ipairs(list) do assert(NS.DropsMerge(x) == "new") end
local spent = os.clock() - t0
assert(spent < 0.1, ("300 merges at the cap took %.3f s"):format(spent))
assert(size(d.k) == 4000, "still 4000: " .. size(d.k))
-- 153 records of the oldest day (i % 26 == 25) and 147 of the next went, the new ones stayed
local oldest = 0
for _, x in pairs(d.k) do if x.day == today - 26 then oldest = oldest + 1 end end
assert(oldest == 0, "the oldest went first: " .. oldest)
for i = 1, 300 do assert(d.k[("f%07x"):format(i)], "a new record stays") end
-- a record older than every kept one would go again at once: refused
local res, why = NS.DropsMerge({ h = "e2300001", npc = 1, inst = 1, diff = 1, day = today - 27, o = "33333333", src = "G", it = {} })
assert(res == nil and why == "full" and size(d.k) == 4000, tostring(why))
-- a whole blob through the batch
local list2 = {}
for i = 1, 300 do list2[i] = { h = ("e%07x"):format(i), npc = 1000, inst = 2001, diff = 1, day = today, o = "33333333", src = "G", it = {} } end
local fired = 0
NS.Listen("DROPS_CHANGED", function() fired = fired + 1 end)
t0 = os.clock()
local _, cnt = NS.DropsMergeAll(list2)
spent = os.clock() - t0
assert(cnt.new == 300 and size(d.k) == 4000 and spent < 0.1, ("a 300-record blob: %d new, %.3f s"):format(cnt.new, spent))
assert(fired == 1, "one change event per blob: " .. fired)

---------------------------------------------------------------------------
-- 9. encounter and instance names are capped and checked on load
---------------------------------------------------------------------------
for i = 1, 2100 do d.enc[i] = "Begegnung " .. i end
for i = 1, 600 do d.inst[i] = { "party", "Instanz " .. i } end
d.enc[99] = "Bad|Name"
d.inst[98] = { "pvp", "Arena" }
NS.DropsMigrate(AmisiaDB)
assert(size(d.enc) <= 2000 and size(d.inst) <= 500, size(d.enc) .. " " .. size(d.inst))
assert(d.enc[99] == nil and d.inst[98] == nil, "broken names go")
assert(d.inst[2001] ~= nil and d.inst[2011] ~= nil or size(d.inst) == 500, "instances of records stay first")

---------------------------------------------------------------------------
-- B. a name of any bytes ends: broken bytes give nil, long names are cut at a whole character
---------------------------------------------------------------------------
local steps = 0
debug.sethook(function() steps = steps + 1; if steps > 200 then error("cleanName does not end") end end, "", 100000)
local okA = NS.DropsCleanName(("a"):rep(60) .. "\255")
local okB = NS.DropsCleanName(("\128"):rep(80))
local okC = NS.DropsCleanName(("ä"):rep(40))
debug.sethook()
assert(okA == nil and okB == nil, "broken bytes are no name")
assert(okC and #okC <= 48 and #okC % 2 == 0 and NS.DropsCleanName(okC) == okC, "cut at a whole character")

---------------------------------------------------------------------------
-- learned names fire DROPS_CHANGED and raise the names generation
---------------------------------------------------------------------------
local gen, before = NS.DropsNamesGen(), fired
assert(NS.DropsLearnNames({ [777001] = "Neuer Boss" }, nil, nil) == 1)
assert(fired == before + 1 and NS.DropsNamesGen() == gen + 1, "a new name fires once")
assert(NS.DropsLearnNames({ [777001] = "Anderer Name" }, nil, nil) == 0)
assert(fired == before + 1 and NS.DropsNamesGen() == gen + 1, "a known name changes nothing")
assert(NS.DropsLearnNames(nil, { [2834] = { "party", "Halle der Thane" } }, { [3012] = "Faldrim" }) == 2 and fired == before + 2)
