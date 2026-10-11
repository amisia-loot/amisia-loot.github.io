-- Drop records (Drops.lua): a boss kill from a loot window becomes one record per corpse, keyed by
-- a hash of the corpse GUID, with a random client id as origin and no player name. Boss detection
-- by the base stock / dungeon facts, by a kill event of this instance within 120 s, or by an item of
-- quality 3 or better; trash stays out. Retention, migration, rates and the export text.
local GUID = "Creature-0-3110-2834-47-213450-00002E7CF2"
local function hex8(v) return type(v) == "string" and #v == 8 and v:match("^%x+$") ~= nil end
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function msgs(text)
    local n = 0
    for _, m in ipairs(STUB.messages) do if m:find(text, 1, true) then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- the table after loading
---------------------------------------------------------------------------
local d = AmisiaDB.drops
assert(type(d) == "table" and d.v == 1, "AmisiaDB.drops exists")
assert(hex8(d.me), "a random client id: " .. tostring(d.me))
assert(type(d.k) == "table" and type(d.npc) == "table" and type(d.inst) == "table" and type(d.peers) == "table")
assert(NS.Get("drops.record") == true and NS.Get("drops.share") == true, "both switches on by default")

local today = NS.DropsToday()
assert(today == math.floor((STUB.now - 1767225600) / 86400), "days since 2026-01-01 UTC")
assert(NS.DropsDate(0) == "2026-01-01" and NS.DropsDate(277) == "2026-10-05" and NS.DropsDate(365) == "2027-01-01")
assert(NS.DropsDay("2026-10-05") == 277 and NS.DropsDay("2026-01-01") == 0 and NS.DropsDay("nonsense") == nil)

-- the kill id: the same corpse gives the same id on every client, another spawn another one
local h, npc = NS.DropsKillID(GUID)
assert(hex8(h) and npc == 213450, tostring(h))
assert(NS.DropsKillID("Creature-0-3110-2834-47-213450-00002E7CF2") == h)
assert(NS.DropsKillID("Creature-0-3110-2834-47-213450-00002E7CF3") ~= h, "another spawn")
assert(NS.DropsKillID("Creature-0-3110-2834-48-213450-00002E7CF2") ~= h, "another instance copy")
assert(NS.DropsKillID("Vehicle-0-3110-2834-47-213450-00002E7CF2") == h, "a vehicle corpse is the same creature")
assert(NS.DropsKillID("Item-0-0-0-0-1-0000") == nil and NS.DropsKillID("Player-1-1") == nil and NS.DropsKillID(nil) == nil)
-- the fallback id of a kill event: the same 120 s window gives the same id
local e1 = NS.DropsFallbackID(3012, 2834, 1000 * 120 + 5)
assert(hex8(e1) and e1 == NS.DropsFallbackID(3012, 2834, 1000 * 120 + 119) and e1 ~= NS.DropsFallbackID(3012, 2834, 1001 * 120))
assert(e1 ~= NS.DropsFallbackID(3013, 2834, 1000 * 120 + 5) and e1 ~= h)

---------------------------------------------------------------------------
-- a boss of the base stock in a dungeon
---------------------------------------------------------------------------
NS.BIS = { O = { [213450] = { k = 4, it = { [219004] = 1 } } }, OT = today - 1,
           DG = { { key = "thanes", kind = "party", inst = 2834, bosses = { 213450, 213460 } } } }
STUB.instance = { name = "Halle der Thane", type = "party", id = 2834, diff = 1 }
local ring = STUB.item(219004, "Ring der Thane", 2)
local cloak = STUB.item(219005, "Umhang der Thane", 3)
local grey = STUB.item(219006, "Zerbrochener Krug", 0)
STUB.target, STUB.targetGUID = "Faldrim Ambossmahl", GUID
STUB.loot = { { link = ring, name = "Ring der Thane", src = GUID }, { link = grey, name = "Krug", src = GUID } }
STUB.fire("LOOT_OPENED")
local r = d.k[h]
assert(r, "a record for the corpse")
assert(r.npc == 213450 and r.inst == 2834 and r.diff == 1 and r.day == today and r.o == d.me and r.src == "G")
assert(r.it[219004] == 1 and r.it[219006] == nil, "green and better counts, grey not")
assert(r.enc == nil, "no kill event")
assert(d.npc[213450] == "Faldrim Ambossmahl", "the name the client shows")
assert(d.inst[2834][1] == "party" and d.inst[2834][2] == "Halle der Thane")
-- no player name anywhere in the record
for k, v in pairs(r) do
    assert(v ~= STUB.player and k ~= "name" and k ~= "by", "no player name: " .. tostring(k))
end

-- the same corpse opened again: no second kill, the items are the larger count
STUB.loot = { { link = ring, name = "Ring der Thane", src = GUID, qty = 2 }, { link = cloak, name = "Umhang", src = GUID } }
STUB.fire("LOOT_OPENED")
assert(size(d.k) == 1, "one kill")
assert(d.k[h].it[219004] == 2 and d.k[h].it[219005] == 1)
STUB.loot = { { link = ring, name = "Ring der Thane", src = GUID } }
STUB.fire("LOOT_OPENED")
assert(d.k[h].it[219004] == 2 and d.k[h].it[219005] == 1, "an item already taken stays")
-- a boss of the dungeon facts (DG) without a base stock entry
local G2 = "Creature-0-3110-2834-47-213460-0000000001"
STUB.loot = { { link = ring, name = "Ring", src = G2 } }
STUB.target, STUB.targetGUID = "Ritter", "Creature-0-1-1-1-1-1"
STUB.fire("LOOT_OPENED")
local h2 = NS.DropsKillID(G2)
assert(d.k[h2] and d.k[h2].npc == 213460, "boss of the dungeon facts")
assert(d.npc[213460] == nil, "a corpse that is not the target has no name yet")

-- a boss with nothing worth counting: the kill still counts for the rate
local G3 = "Creature-0-3110-2834-47-213450-0000000002"
STUB.loot = { { link = grey, name = "Krug", src = G3 } }
STUB.fire("LOOT_OPENED")
local h3 = NS.DropsKillID(G3)
assert(d.k[h3] and size(d.k[h3].it) == 0, "a kill without items")
-- a window of coins only (no item link) on a boss corpse counts as well
local G4 = "Creature-0-3110-2834-47-213450-0000000003"
STUB.loot = { { name = "12 Silber", src = G4 } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G4)], "coins only")

---------------------------------------------------------------------------
-- boss by the kill event, by quality; trash not
---------------------------------------------------------------------------
STUB.fire("ENCOUNTER_END", 3012, "Kurgor der Wächter", 1, 5, 1)
STUB.tick(30)
local G5 = "Creature-0-3110-2834-47-213470-0000000001"
STUB.loot = { { link = ring, name = "Ring", src = G5 } }
STUB.fire("LOOT_OPENED")
local h5 = NS.DropsKillID(G5)
assert(d.k[h5] and d.k[h5].enc == 3012 and d.k[h5].npc == 213470, "boss by the kill event")
assert(d.npc[213470] == "Kurgor der Wächter", "named after the event when it is not the target")
-- the event is used once: another corpse right after is trash
local G6 = "Creature-0-3110-2834-47-213471-0000000001"
STUB.loot = { { link = ring, name = "Ring", src = G6 } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G6)] == nil, "one kill event, one corpse")
-- a wipe is no kill, and an event older than 120 s is not used
STUB.fire("ENCOUNTER_END", 3013, "Brakka", 1, 5, 0)
local G7 = "Creature-0-3110-2834-47-213472-0000000001"
STUB.loot = { { link = ring, name = "Ring", src = G7 } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G7)] == nil, "a wipe")
STUB.fire("BOSS_KILL", 3014, "Ulgra")
STUB.tick(121)
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G7)] == nil, "too late after the kill")
-- BOSS_KILL within 120 s counts
STUB.fire("BOSS_KILL", 3015, "Ulgra")
STUB.tick(5)
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G7)] and d.k[NS.DropsKillID(G7)].enc == 3015, "BOSS_KILL")
-- boss by quality: a rare item
local G8 = "Creature-0-3110-2834-47-213480-0000000001"
STUB.loot = { { link = cloak, name = "Umhang", src = G8 }, { link = ring, name = "Ring", src = G8 } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G8)] and d.k[NS.DropsKillID(G8)].it[219005] == 1, "a rare item marks a boss")
-- trash: green only, nothing known, no event
local G9 = "Creature-0-3110-2834-47-1234-0000000001"
local before = size(d.k)
STUB.loot = { { link = ring, name = "Ring", src = G9 } }
STUB.fire("LOOT_OPENED")
assert(size(d.k) == before, "trash is not recorded")
-- a recipe of any quality counts
local recipe = STUB.item(219100, "Rezept: Thanebräu", 1)
STUB.items[219100].classID = 9
STUB.loot = { { link = recipe, name = "Rezept", src = G8 } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(G8)].it[219100] == 1, "recipes count")
-- two corpses in one window: each its own record
local GA, GB = "Creature-0-3110-2834-47-213450-00000000A1", "Creature-0-3110-2834-47-213460-00000000B1"
STUB.loot = { { link = ring, name = "Ring", src = GA }, { link = cloak, name = "Umhang", src = GB } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(GA)].it[219004] == 1 and d.k[NS.DropsKillID(GB)].it[219005] == 1, "two corpses")

---------------------------------------------------------------------------
-- secret values, the fallback id, places where nothing is recorded
---------------------------------------------------------------------------
-- the corpse GUID is secret: the kill event gives the fallback id
local GS = "Creature-0-3110-2834-47-213490-0000000001"
STUB.secret[GS] = true
STUB.fire("ENCOUNTER_END", 3020, "Geheimer Boss", 1, 5, 1)
local killAt = STUB.now
STUB.loot = { { link = cloak, name = "Umhang", src = GS } }
STUB.fire("LOOT_OPENED")
local he = NS.DropsFallbackID(3020, 2834, killAt)
assert(d.k[he] and d.k[he].src == "E" and d.k[he].npc == 0 and d.k[he].enc == 3020, "fallback record")
assert(d.k[he].it[219005] == 1)
assert(d.enc[3020] == "Geheimer Boss", "the boss of a fallback record is named after the event")
-- a secret GUID without a kill event: nothing
STUB.tick(200)
local count = size(d.k)
STUB.fire("LOOT_OPENED")
assert(size(d.k) == count, "no id, no record")
STUB.secret[GS] = nil
-- a secret link is skipped, the kill still counts
local GL = "Creature-0-3110-2834-47-213450-00000000C1"
STUB.secret[cloak] = true
STUB.loot = { { link = cloak, name = "Umhang", src = GL } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(GL)] and size(d.k[NS.DropsKillID(GL)].it) == 0, "the secret link is skipped")
STUB.secret[cloak] = nil
-- a secret target name: no name now, filled in later when the boss is the target again
local GN = "Creature-0-3110-2834-47-213500-0000000001"
STUB.target, STUB.targetGUID = "Namenlos", GN
STUB.secret["Namenlos"] = true
STUB.loot = { { link = cloak, name = "Umhang", src = GN } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(GN)] and d.npc[213500] == nil, "no secret name")
STUB.secret["Namenlos"] = nil
STUB.fire("PLAYER_TARGET_CHANGED")
assert(d.npc[213500] == "Namenlos", "named later")
-- a container from the bags is no drop
count = size(d.k)
STUB.loot = { { link = cloak, name = "Umhang", src = "Item-0-0-0-0-1-0000000001" } }
STUB.fire("LOOT_OPENED")
assert(size(d.k) == count, "a container")
-- outside instances, in battlegrounds, with the switch off: nothing
for _, inst in ipairs({ { name = "Sturmwind", type = "none", id = 0 }, { name = "Alteractal", type = "pvp", id = 30 },
                        { name = "Arena", type = "arena", id = 559 } }) do
    STUB.instance = inst
    STUB.loot = { { link = cloak, name = "Umhang", src = "Creature-0-3110-2834-47-213450-00000000D" .. inst.id } }
    STUB.fire("LOOT_OPENED")
    assert(size(d.k) == count, "nothing in " .. inst.type)
end
STUB.instance = { name = "Halle der Thane", type = "party", id = 2834, diff = 1 }
NS.Set("drops.record", false)
STUB.loot = { { link = cloak, name = "Umhang", src = "Creature-0-3110-2834-47-213450-00000000E1" } }
STUB.fire("LOOT_OPENED")
assert(size(d.k) == count, "recording off")
NS.Set("drops.record", true)
-- a raid counts as well, with its kind
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409, diff = 9 }
local GR = "Creature-0-3110-409-47-11502-0000000001"
STUB.target, STUB.targetGUID = "Ragnaros", GR
STUB.loot = { { link = cloak, name = "Umhang", src = GR } }
STUB.fire("LOOT_OPENED")
assert(d.k[NS.DropsKillID(GR)].inst == 409 and d.k[NS.DropsKillID(GR)].diff == 9 and d.inst[409][1] == "raid")
-- the item collector still notes the drop (Collect.lua hands the window on and goes on)
assert(AmisiaDB.scan.sources[219005], "the collector saw the window too")
-- an error in the drop records loses only that kill: the collector goes on
STUB.instance = { name = "Halle der Thane", type = "party", id = 2834, diff = 1 }
local realKill = NS.DropsKillID
NS.DropsKillID = function() error("kaputt") end
local errors = 0
_G.geterrorhandler = function() return function() errors = errors + 1 end end
local spear = STUB.item(219200, "Speer", 3)
STUB.loot = { { link = spear, name = "Speer", src = "Creature-0-3110-2834-47-213450-00000000F1" } }
STUB.fire("LOOT_OPENED")
assert(errors >= 1 and AmisiaDB.scan.sources[219200], "the error is reported and the collector noted the item")
NS.DropsKillID = realKill
_G.geterrorhandler = function() return function(e) error(e, 0) end end

---------------------------------------------------------------------------
-- merging records (the exchange uses the same function)
---------------------------------------------------------------------------
local function rec(id, day, o, items, extra)
    local x = { h = id, npc = 213999, inst = 2834, diff = 1, day = day, o = o, src = "G", it = items or {} }
    for k, v in pairs(extra or {}) do x[k] = v end
    return x
end
local n0 = size(d.k)
assert(NS.DropsMerge(rec("aaaa0001", today, "ffffffff", { [219004] = 1 })) == "new")
assert(size(d.k) == n0 + 1 and not d.k.aaaa0001.mine, "a heard record is not the own")
assert(NS.DropsMerge(rec("aaaa0001", today, "00000001", { [219004] = 3, [219005] = 1 })) == "merged")
assert(d.k.aaaa0001.it[219004] == 3 and d.k.aaaa0001.it[219005] == 1 and d.k.aaaa0001.o == "00000001", "max items, smaller origin")
assert(NS.DropsMerge(rec("aaaa0001", today, "ffffffff", { [219004] = 1 })) == "same", "nothing lost, nothing new")
assert(d.k.aaaa0001.it[219004] == 3 and d.k.aaaa0001.o == "00000001")
-- enc is filled in when one side has it; a different npc or place is not taken over
assert(NS.DropsMerge(rec("aaaa0001", today, "00000001", {}, { enc = 3012 })) == "merged" and d.k.aaaa0001.enc == 3012)
NS.DropsMerge(rec("aaaa0001", today, "00000001", {}, { npc = 999 }))
assert(d.k.aaaa0001.npc == 213999, "never overwritten")
-- broken records are refused
assert(NS.DropsMerge(rec("xyz", today, "00000001")) == nil, "bad id")
assert(NS.DropsMerge(rec("aaaa0002", today, "0001")) == nil, "bad origin")
assert(NS.DropsMerge(rec("aaaa0003", today - 28, "00000001")) == nil, "older than 28 days")
assert(NS.DropsMerge(rec("aaaa0004", today + 2, "00000001")) == nil, "in the future")
assert(NS.DropsMerge(rec("aaaa0005", today, "00000001", { [0] = 1 })) == nil, "bad item")
assert(NS.DropsMerge(rec("aaaa0006", today, "00000001", { [5] = 201 })) == nil, "bad count")
assert(NS.DropsMerge(rec("aaaa0007", today, "00000001", {}, { src = "X" })) == nil, "bad source")
-- order independence: the same records in any order give the same table
local function snapshot(list)
    local saved = AmisiaDB.drops
    AmisiaDB.drops = { v = 1, me = "12345678", k = {}, npc = {}, inst = {}, enc = {}, peers = {} }
    for _, x in ipairs(list) do NS.DropsMerge(x) end
    local out = STUB.dump(AmisiaDB.drops.k)
    AmisiaDB.drops = saved
    return out
end
local A = rec("bbbb0001", today, "0000000a", { [1] = 2 })
local B = rec("bbbb0001", today, "00000009", { [1] = 1, [2] = 1 }, { enc = 7 })
local C = rec("bbbb0002", today - 1, "0000000b", {})
assert(snapshot({ A, B, C }) == snapshot({ C, B, A }) and snapshot({ A, B, C }) == snapshot({ B, A, C, A, B }), "order independent")

---------------------------------------------------------------------------
-- retention: 28 days and 4000 records
---------------------------------------------------------------------------
d.k["cccc0001"] = { npc = 1, inst = 2834, diff = 1, day = today - 28, o = d.me, src = "G", it = {} }
d.k["cccc0002"] = { npc = 1, inst = 2834, diff = 1, day = today - 27, o = d.me, src = "G", it = {} }
NS.DropsPrune()
assert(d.k.cccc0001 == nil and d.k.cccc0002 ~= nil, "28 days kept, older gone")
for i = 1, 4100 do
    d.k[("dd%06x"):format(i)] = { npc = 2, inst = 2834, diff = 1, day = today - 27 + (i > 100 and 1 or 0), o = d.me, src = "G", it = {} }
end
NS.DropsPrune()
assert(size(d.k) == 4000, "4000 at most: " .. size(d.k))
assert(d.k.cccc0002 == nil and d.k.dd000001 == nil and d.k[("dd%06x"):format(4100)] ~= nil, "the oldest go first")
for id in pairs(d.k) do if id:match("^dd") then d.k[id] = nil end end

---------------------------------------------------------------------------
-- migration: broken entries go, twice changes nothing, the client id stays
---------------------------------------------------------------------------
local me = d.me
AmisiaDB.drops.k.broken1 = { npc = "x" }
AmisiaDB.drops.k.broken2 = "nope"
AmisiaDB.drops.k[17] = { npc = 1 }
AmisiaDB.drops.k.eeee0001 = { npc = 1, inst = 2834, diff = 1, day = today - 40, o = me, src = "G", it = {} }
AmisiaDB.drops.npc.bad = 5
AmisiaDB.drops.npc[777] = "Name|mit Strich"
NS.DropsMigrate(AmisiaDB)
local once = STUB.dump(AmisiaDB.drops)
NS.DropsMigrate(AmisiaDB)
assert(STUB.dump(AmisiaDB.drops) == once, "twice changes nothing")
assert(AmisiaDB.drops.me == me and AmisiaDB.drops.k.broken1 == nil and AmisiaDB.drops.k.broken2 == nil and AmisiaDB.drops.k[17] == nil)
assert(AmisiaDB.drops.k.eeee0001 == nil, "retention on load")
assert(AmisiaDB.drops.npc.bad == nil and AmisiaDB.drops.npc[777] == nil)
assert(AmisiaDB.drops.k[h], "good records stay")
-- a table without a client id gets one; a broken one is replaced
local root = { drops = { v = 1, k = {}, npc = {}, inst = {}, peers = {} } }
NS.DropsMigrate(root)
assert(hex8(root.drops.me))
root = { drops = "kaputt" }
NS.DropsMigrate(root)
assert(type(root.drops) == "table" and hex8(root.drops.me) and type(root.drops.k) == "table")
root = { drops = { me = "Vuloo" } }
NS.DropsMigrate(root)
assert(hex8(root.drops.me), "a name is never an id")
-- the collector notes of 1.x build no records
root = { scan = { sources = { [219004] = { "Drop: Faldrim [213450] @Halle der Thane #party:2834" } } } }
NS.DropsMigrate(root)
assert(size(root.drops.k) == 0, "no records from collector notes")

---------------------------------------------------------------------------
-- rates: base stock plus the records after its day, smoothed with p0
---------------------------------------------------------------------------
local saved = AmisiaDB.drops
AmisiaDB.drops = { v = 1, me = "12345678", k = {}, npc = {}, inst = {}, enc = {}, peers = {} }
NS.BIS = { O = { [500] = { k = 10, it = { [601] = 4, [602] = 6 } } }, OT = today - 5 }
STUB.item(601, "Eins", 3); STUB.item(602, "Zwei", 3); STUB.item(603, "Drei", 2)
-- p0 from the known items of the same quality: two rare items -> 1/2
local p, n, K = NS.DropRate(500, 601)
assert(K == 10 and n == 4 and math.abs(p - (4 + 3 * 0.5) / 13) < 1e-9, tostring(p))
-- records after the base stock's day count, those up to it are already in it
NS.DropsMerge({ h = "f0000001", npc = 500, inst = 2834, diff = 1, day = today, o = "12345678", src = "G", it = { [601] = 1 } })
NS.DropsMerge({ h = "f0000002", npc = 500, inst = 2834, diff = 1, day = today - 1, o = "12345678", src = "G", it = {} })
NS.DropsMerge({ h = "f0000003", npc = 500, inst = 2834, diff = 1, day = today - 5, o = "12345678", src = "G", it = { [601] = 1 } })
p, n, K = NS.DropRate(500, 601)
assert(K == 12 and n == 5, K .. " " .. n)
assert(math.abs(p - (5 + 3 * 0.5) / 15) < 1e-9)
-- a source chance given as p0 wins over the quality rule
p = NS.DropRate(500, 602, 0.2)
assert(math.abs(p - (6 + 0.6) / 15) < 1e-9)
-- a boss nobody saw: no rate without a source chance, the source chance with one
assert(NS.DropRate(999, 601) == nil)
assert(NS.DropRate(999, 601, 0.25) == 0.25)
-- the text: kills of the guild from five kills on, a count below
assert(NS.DropRateText(500, 601) == "5 von 12 Kills der Gilde (42 %)", NS.DropRateText(500, 601))
NS.BIS = nil
assert(NS.DropRateText(500, 601) == "gesehen 2-mal in 3 Kills", NS.DropRateText(500, 601))
assert(NS.DropRateText(999, 601) == "Chance unbekannt")
AmisiaDB.drops = saved

---------------------------------------------------------------------------
-- the export text "Drops für die Website"
---------------------------------------------------------------------------
STUB.player = "Vulo Sturmwind"
local text = NS.DropsExportText()
local lines = {}
for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
assert(lines[1] == "#AMISIA 2 Vulo_Sturmwind", lines[1])
assert(lines[#lines] == "#END")
local dk, dn, dz, lastKey = 0, 0, 0, nil
for i = 2, #lines - 1 do
    local l = lines[i]
    local kind = l:match("^(%u%u) ")
    assert(kind == "DZ" or kind == "DN" or kind == "DK", "only drop lines: " .. l)
    if kind == "DK" then
        dk = dk + 1
        local id, npcId, inst, diff, date, o, src, items = l:match("^DK (%x+) (%d+) (%d+) (%d+) (%d%d%d%d%-%d%d%-%d%d) (%x+) ([GE]) (%S+)$")
        assert(id and hex8(id) and hex8(o), l)
        assert(items == "-" or items:match("^%d+:%d+[%d:,]*$"), l)
        assert(not l:find("Vulo", 1, true) and not l:find("Faldrim", 1, true), "no names in DK lines")
        local key = date .. " " .. id
        assert(not lastKey or lastKey <= key, "sorted by day, then id")
        lastKey = key
    elseif kind == "DN" then
        dn = dn + 1
        assert(l:match("^DN %d+ %d+ .+$"), l)
    else
        dz = dz + 1
        assert(l:match("^DZ %d+ party .+$") or l:match("^DZ %d+ raid .+$"), l)
    end
end
assert(dk == size(d.k), "every record: " .. dk .. "/" .. size(d.k))
assert(text:find("\nDN 213450 0 Faldrim Ambossmahl\n", 1, true), "boss names")
assert(text:find("\nDN 213470 3012 Kurgor der Wächter\n", 1, true), "with the encounter")
assert(text:find("\nDN 0 3020 Geheimer Boss\n", 1, true), "the boss of a fallback record")
assert(text:find("\nDZ 2834 party Halle der Thane\n", 1, true) and text:find("\nDZ 409 raid Geschmolzener Kern\n", 1, true))
local hline = ("DK %s 213450 2834 1 %s %s G 219004:2,219005:1"):format(h, NS.DropsDate(today), d.k[h].o)
assert(text:find("\n" .. hline .. "\n", 1, true), "the first kill: " .. hline)
assert(text:find(("\nDK %s 213450 2834 1 %s %s G -\n"):format(h3, NS.DropsDate(today), d.me), 1, true), "a kill without items")
-- the raid export is not touched
assert(not NS.ExportText({}):find("\nDK ", 1, true))

---------------------------------------------------------------------------
-- the command
---------------------------------------------------------------------------
STUB.messages = {}
SlashCmdList.AMISIA("drops")
assert(msgs("Drop-Daten:") == 1, table.concat(STUB.messages, " / "))
assert(msgs(("%d Kills"):format(size(d.k))) == 1, table.concat(STUB.messages, " / "))
assert(table.concat(NS.SlashHelpLines(false), "\n"):find("/amisia drops", 1, true))
STUB.messages = {}
SlashCmdList.AMISIA("drops quatsch")
assert(msgs("Aufruf: /amisia drops") == 1)
