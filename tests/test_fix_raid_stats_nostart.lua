-- A saved session without its start time does not break the statistics (Raid/Stats.lua, the
-- per-character raid count compared s.start without a default; audit 2026-11-07).
AmisiaDB.sessions[#AmisiaDB.sessions + 1] = { id = "old", date = "2026-01-01", zone = "Der Schwarze Tempel",
    members = { Anna = { class = "PRIEST" } }, loot = {}, items = {}, drops = {}, awards = {}, gone = {},
    kills = {}, bench = {}, outside = {} }
local ok, res = pcall(NS.StatsBuild, { range = "all" })
assert(ok, "the build runs: " .. tostring(res))
assert(type(res) == "table" and res.raids == 1, "the session counts: " .. tostring(type(res) == "table" and res.raids))
ok, res = pcall(NS.StatsBuild, { range = "4w" })
assert(ok, "the 4-week range runs: " .. tostring(res))
