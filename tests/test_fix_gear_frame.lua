-- The level-range table (GearFrame.lua) with a saved column outside its table (an edited file or
-- an older table): the column falls back to the own level's instead of indexing nothing.
local Gear = NS.Gear
STUB.class, STUB.level = "WARRIOR", 60
AmisiaDB.settings.gear = { col = 99, view = "list" }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(Gear.Available(), "the gear data")
local ok, err = pcall(NS.ToggleGearFrame)
assert(ok, "the table opens: " .. tostring(err))
local g = AmisiaDB.settings.gear
assert(g.col == Gear.ColumnOf(60), "the own level's column: " .. tostring(g.col))
for _, bad in ipairs({ 0, -3, 2.5, "x" }) do
    g.col = bad
    ok, err = pcall(NS.GearRefresh, false)
    assert(ok and g.col == Gear.ColumnOf(60), tostring(bad) .. ": " .. tostring(err))
end
g.col = 3
NS.GearRefresh(false)
assert(g.col == 3, "a valid column stays")
