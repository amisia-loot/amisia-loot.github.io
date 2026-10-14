-- The caches of the points pass (2.35.2): the earnings of a raid are kept and the standings come out
-- the same as counted anew; a change through DATA_CHANGED, POINTS or ALTS (or replaced tables) counts
-- at once; the recording raid always counts now; the keeper's KV and LV hashes of the 5 second tick
-- are those of a fresh build, and a change goes out with the next tick; an old raid's export state
-- turns "changed" 5 seconds after an edit that fires DATA_CHANGED, and stays kept while nothing changes.
STUB.now = 1791400000
STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
STUB.roster = { { name = "Vulo Sturmwind", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Kim Eisherz", class = "MAGE" }, { name = "Chorf", class = "WARRIOR" } }
STUB.officer = true
NS.Set("ui.view", "officer")
NS.Set("points.system", "dkp")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local act = NS.Active()
assert(act and act.points and act.points.sys == "dkp", "the running raid counts DKP")
local DB = AmisiaDB

-- three old raids with members, kills (who was there), bench and a cost each
local olds = {}
for k = 1, 3 do
    local t = STUB.now - k * 7 * 86400
    local s = { id = os.date("%Y%m%d%H%M%S", t) .. "-533", start = t, last = t + 10800, date = os.date("%Y-%m-%d", t),
        zone = "Naxxramas", instanceID = 533, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, outside = {},
        members = { ["Vulo Sturmwind"] = { class = "PRIEST", first = t, last = t + 10800 },
                    ["Fraktur"] = { class = "SHAMAN", first = t, last = t + 10800 },
                    ["Kimtwink"] = { class = "MAGE", first = t + 3600, last = t + 10800, late = true } },
        kills = { { enc = 1107, name = "Anub'Rekhan", start = t + 600, t = t + 700, ok = true, who = { "Vulo Sturmwind", "Kimtwink" } },
                  { enc = 1108, name = "Faerlina", start = t + 900, t = t + 1000, ok = true, who = { "Fraktur", "Vulo" } } },
        bench = { ["Chorf"] = { t = t + 60, by = "Vulo Sturmwind" } } }
    s.points = { sys = "dkp", cfg = { sys = "dkp", raid = 10, boss = 5, time = 3, bench = 4 }, charges = {} }
    table.insert(DB.sessions, 1, s)
    local a = NS.AddAwardTo(s, { name = "Fraktur", item = 30000 + k, kind = "MS", src = "Anub'Rekhan", t = t + 800 })
    assert(NS.SetAwardPoints(s, a.id, 7 * k), "a cost")
    olds[k] = s
end
local old = olds[1]

local function dump()
    local parts = {}
    for _, e in ipairs(NS.PointsStandings()) do parts[#parts + 1] = ("%s=%d/%d"):format(e.name, e.a, e.b) end
    return table.concat(parts, " ")
end
-- counted anew: ALTS drops every kept list
local function anew()
    NS.Fire("ALTS")
    return dump()
end

---------------------------------------------------------------------------
-- the standings: kept the same as counted anew
---------------------------------------------------------------------------
local cold = anew()
assert(cold ~= "" and dump() == cold and dump() == cold, "the kept lists give the same standings")
assert(NS.PointsRaidEarnings(old) == NS.PointsRaidEarnings(old), "an old raid's earnings are kept")
local ids = {}
for _, e in ipairs(NS.PointsRaidEarnings(old)) do ids[#ids + 1] = e.id .. e.n end
local keptIds = table.concat(ids, ",")
NS.Fire("ALTS")
ids = {}
for _, e in ipairs(NS.PointsRaidEarnings(old)) do ids[#ids + 1] = e.id .. e.n end
assert(table.concat(ids, ",") == keptIds, "the same ids and amounts")
assert(NS.PointsOf("Vulo Sturmwind").a == (dump():match("Vulo Sturmwind=(%-?%d+)") + 0))

-- an edit in place with DATA_CHANGED counts at once
local before = NS.PointsOf("Chorf").a
old.kills[1].who[#old.kills[1].who + 1] = "Chorf"
NS.Fire("DATA_CHANGED")
assert(NS.PointsOf("Chorf").a == before + 5, "a kill's new name counts after DATA_CHANGED")
assert(dump() == anew(), "and the same as counted anew")
-- a member added with DATA_CHANGED
old.members["Neu Ling"] = { class = "ROGUE", first = old.start, last = old.last }
NS.Fire("DATA_CHANGED")
assert(NS.PointsOf("Neu Ling").a == 13, "raid and on time: " .. NS.PointsOf("Neu Ling").a)
-- a replaced table counts without an event
old.bench = {}
assert(NS.PointsOf("Chorf").a == before + 5 - 4, "the bench of the old raid is gone")
assert(dump() == anew())
-- POINTS: a raid out of the count, and back
NS.PointsRaidOff(old, true)
assert(#NS.PointsRaidEarnings(old) == 0 and NS.PointsOf("Neu Ling").a == 0, "out of the count")
NS.PointsRaidOff(old, false)
assert(NS.PointsOf("Neu Ling").a == 13)
-- ALTS: the alt's earnings go to its main
local kimBefore = NS.PointsOf("Kim Eisherz").a
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-06\nA Kimtwink Kim_Eisherz\n#END"))
assert(NS.PointsOf("Kim Eisherz").a > kimBefore, "the alt's raids count for the main at once")
for _, e in ipairs(NS.PointsRaidEarnings(old)) do
    if e.char == "Kimtwink" then assert(e.name == "Kim Eisherz", "the main's name in the kept list") end
end
NS.ClearAlts()
assert(NS.PointsOf("Kim Eisherz").a == kimBefore)

-- the recording raid always counts now (its roster grows without an event)
local cnt = NS.PointsOf("Spaet Kommer").a
act.members["Spaet Kommer"] = { class = "MAGE", first = time(), last = time() }
assert(NS.PointsOf("Spaet Kommer").a > cnt, "a new raider of the running raid counts at once")
assert(dump() == anew())

---------------------------------------------------------------------------
-- the keeper's tick: KV and LV hashes of a fresh build
---------------------------------------------------------------------------
NS.CommReady = function() return true end
NS.CommPacking = function() return true end
NS.SyncIsKeeper = function() return true end
local sent = {}
local send = NS.CommSend
NS.CommSend = function(kind, fields, ...)
    if kind == "KV" or kind == "LV" then
        sent[#sent + 1] = { kind = kind, h = fields[2], n = fields[3] }
        return false   -- not sent: every tick says its state again
    end
    return send(kind, fields, ...)
end
local function last(kind)
    for i = #sent, 1, -1 do
        if sent[i].kind == kind then return sent[i] end
    end
    return nil
end
assert(NS.SetLootPrio("#AMISIA-LC 1 forever 2026-10-07\nC 32235 1788000000 p:Kim_Eisherz:Tank,c:WARRIOR:Furor,o Erst Tanks\nC 32837 1788000100 p:Fraktur\n#END"))
STUB.tick(5)
local kv1, lv1 = last("KV"), last("LV")
assert(kv1 and lv1, "the keeper says its states")
STUB.tick(5)
local kv2, lv2 = last("KV"), last("LV")
assert(kv2 ~= kv1 and kv2.h == kv1.h and kv2.n == kv1.n, "KV kept: the same hash")
assert(lv2 ~= lv1 and lv2.h == lv1.h and lv2.n == lv1.n, "LV kept: the same hash")
-- the same as built anew
NS.Fire("ALTS"); NS.Fire("LOOT_PRIO")
STUB.tick(5)
assert(last("KV").h == kv1.h and last("LV").h == lv1.h, "a fresh build: the same hashes")
-- a cost in the running raid: the next tick says the new state
local a = NS.AddAwardTo(act, { name = "Kim Eisherz", item = 32235, kind = "MS", src = "Ragnaros", t = time() })
assert(NS.SetAwardPoints(act, a.id, 60))
STUB.tick(5)
local kv3 = last("KV")
assert(kv3.h ~= kv1.h, "the cost goes out with the next tick")
NS.Fire("ALTS")
STUB.tick(5)
assert(last("KV").h == kv3.h, "and it is the fresh build's hash")
-- a new raider of the running raid (no event): the next tick
act.members["Noch Einer"] = { class = "MAGE", first = time(), last = time() }
STUB.tick(5)
local kv4 = last("KV")
STUB.tick(5)
NS.Fire("ALTS")
STUB.tick(5)
assert(last("KV").h == kv4.h, "the kept hash after a new raider is the fresh one")
-- a prio edit: the next tick
assert(NS.EditLootPrio(32837, "Vulo Sturmwind", ""))
STUB.tick(5)
local lv3 = last("LV")
assert(lv3.h ~= lv1.h, "the prio change goes out with the next tick")
NS.Fire("LOOT_PRIO")
STUB.tick(5)
assert(last("LV").h == lv3.h, "and it is the fresh hash")
NS.CommSend = send

---------------------------------------------------------------------------
-- the export state of an old raid
---------------------------------------------------------------------------
local o2 = olds[2]
NS.MarkExported({ o2 })
assert(NS.ExportState(o2) == "done")
STUB.tick(1)
assert(NS.ExportState(o2) == "done", "kept")
assert(NS.BenchAdd(o2, "Ersatz Mann", { class = "ROGUE" }), "an edit of the old raid")
STUB.tick(4)
assert(NS.ExportState(o2) == "changed", "the edit counts once the 5 seconds passed")
NS.MarkExported({ o2 })
assert(NS.ExportState(o2) == "done")
local aw = NS.AddAwardTo(o2, { name = "Fraktur", item = 30100, kind = "OS", src = "Faerlina", t = o2.start + 900 })
STUB.tick(5)
assert(aw and NS.ExportState(o2) == "changed", "an award afterwards: changed after 5 seconds")
NS.MarkExported({ o2 })
STUB.tick(30)
assert(NS.ExportState(o2) == "done", "nothing changed: kept beyond 5 seconds")
