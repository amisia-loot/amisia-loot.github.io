-- The caches of the performance pass (2.35.0): an old raid's export fingerprint is kept 5 seconds,
-- and up to 60 seconds while nothing changed (DATA_CHANGED and the other change events); the export
-- itself and the recording raid always count now; the version list sorts a short chat name
-- into the raid by its first name and keeps two of one first name apart; the lineup's people are built
-- once per frame.
STUB.roster = { { name = "Vulo Sturmwind", class = "WARRIOR" }, { name = "Mira Eisherz", class = "MAGE" },
                { name = "Mira Stein", class = "PRIEST" } }
NS.Set("ui.view", "officer")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local DB = AmisiaDB
local old = { id = "20260901200000-409", start = 1756757000, last = 1756760000, date = "2026-09-01", zone = "Alt", instanceID = 409,
    members = { ["Vulo Sturmwind"] = { class = "WARRIOR", first = 1756757000, last = 1756760000 } }, loot = {}, items = {}, drops = {},
    awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
table.insert(DB.sessions, 1, old)
NS.MarkExported({ old })
assert(NS.ExportState(old) == "done")
old.awards[1] = { id = 1, name = "Vulo Sturmwind", item = 16800, t = 1756758000, kind = "MS", src = "Ragnaros" }
assert(NS.ExportState(old, true) == "changed", "the export counts now")
local fresh = NS.PendingExport(true)
local found = false
for _, s in ipairs(fresh) do if s == old then found = true end end
assert(found, "the export takes the changed raid at once")
NS.MarkExported({ old })
STUB.tick(1)
old.awards[2] = { id = 2, name = "Vulo Sturmwind", item = 16801, t = 1756758100, kind = "OS", src = "Ragnaros" }
assert(NS.ExportState(old) == "done", "a write without an event: the kept fingerprint")
NS.Fire("DATA_CHANGED")
STUB.tick(5)
assert(NS.ExportState(old) == "changed", "after DATA_CHANGED the kept fingerprint goes after 5 seconds")
NS.MarkExported({ old })
STUB.tick(1)
old.awards[3] = { id = 3, name = "Vulo Sturmwind", item = 16802, t = 1756758200, kind = "OS", src = "Ragnaros" }
assert(NS.ExportState(old) == "done")
STUB.tick(10)
assert(NS.ExportState(old) == "done", "nothing changed: kept longer")
STUB.tick(50)
assert(NS.ExportState(old) == "changed", "and after 60 seconds at the latest")
-- the recording raid is never kept
local act = NS.Active()
NS.MarkExported({ act })
assert(NS.ExportState(act) == "done")
act.awards[#act.awards + 1] = { id = 99, name = "Mira Eisherz", item = 16801, t = time(), kind = "OS", src = "Ragnaros" }
assert(NS.ExportState(act) == "changed", "the recording raid counts now")

-- the version list: "Vulo" is the raid's Vulo Sturmwind, "Mira" is two people: guild
DB.sync = DB.sync or {}
DB.sync.seen = { Vulo = { v = "2.30.0", flags = "", at = 1 }, Mira = { v = "2.30.0", flags = "", at = 2 },
                 ["Mira Stein"] = { v = "2.30.0", flags = "", at = 3 }, ["Kim Fern"] = { v = "2.30.0", flags = "", at = 4 } }
local where = {}
for _, e in ipairs(NS.VersionSeen()) do where[e.name] = e.where end
assert(where.Vulo == "raid" and where["Mira Stein"] == "raid", "by first name and exactly")
assert(where.Mira == "guild" and where["Kim Fern"] == "guild", "two Miras: no one; not in the group: guild")

-- the lineup's people: one build per frame
if NS.LineupPeople then
    local a = NS.LineupPeople()
    assert(NS.LineupPeople() == a, "the same frame: kept")
    STUB.tick(0.1)
    assert(NS.LineupPeople() ~= a, "the next frame: built again")
end
