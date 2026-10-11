-- Lazy data (Core/LazyData.lua): the five big generated tables wait as text until their first use;
-- the login, the settings page and the availability checks build none; ns.Data builds once; a
-- fixture or nil assigned to a waiting key replaces it; ns.DropData lets go; a broken text is
-- reported and gives nil.
local KEYS = { GEAR = "GearData", MAP = "MapData", QUEST_DATA = "QuestData", PROFESSIONS = "ProfessionData",
               TALENTS = "TalentData", GEAR_WEIGHTS = "GearWeights" }

local function built(k) return NS.DataBuilt()[k] ~= nil end

-- every file hands its table over as text
for k, file in pairs(KEYS) do
    local fh = assert(io.open(ADDON_DIR .. "/Data/" .. file .. ".lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    assert(src:find('ns.LazyData("' .. k .. '", [', 1, true), file .. " is in the lazy form")
    assert(not src:find("\nns." .. k .. " = {", 1, true), file .. " builds no table at load")
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" } }
STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(10)
for k in pairs(KEYS) do
    assert(NS.HasData(k), k .. " is there")
    assert(rawget(NS, k) == nil and not built(k), k .. " is not built at login")
end
assert(NS.Gear.Available() and not built("GEAR") and not built("GEAR_WEIGHTS"), "the availability check builds nothing")

-- the main window on the settings page: the sections ask only whether the data is there
NS.ShowPage("settings")
for k in pairs(KEYS) do assert(not built(k), k .. " is not built by the settings page") end

-- the first use builds the table once; a read of the field goes the same way
local q = NS.Data("QUEST_DATA")
assert(type(q) == "table" and q.count > 0 and built("QUEST_DATA"), "built on first use")
assert(NS.Data("QUEST_DATA") == q and NS.QUEST_DATA == q and rawget(NS, "QUEST_DATA") == q, "once")
assert(NS.TALENTS and built("TALENTS"), "ns.TALENTS builds it too")
assert(NS.DataBuilt().QUEST_DATA.kb, "the build's memory is noted")

-- the quests page builds the quest data only
NS.ShowPage("quests")
assert(not built("PROFESSIONS"), "the quests page leaves the professions alone")

-- a fixture replaces what waits; nil takes it away
NS.LazyData("TEST_X", "return { n = 1 }")
NS.TEST_X = { n = 2 }
assert(NS.Data("TEST_X").n == 2, "the fixture wins")
NS.LazyData("TEST_Y", "return { n = 1 }")
NS.TEST_Y = nil
assert(not NS.HasData("TEST_Y") and NS.Data("TEST_Y") == nil, "nil takes it away")
NS.DropData("QUEST_DATA")
assert(NS.QUEST_DATA == nil and not NS.HasData("QUEST_DATA"), "dropped")

-- a broken text: the error handler hears of it (the stub's raises), nothing is kept
NS.LazyData("TEST_Z", "return {")
local ok, err = pcall(NS.Data, "TEST_Z")
assert(not ok and tostring(err):find("TEST_Z", 1, true), tostring(err))
assert(NS.Data("TEST_Z") == nil and not NS.HasData("TEST_Z"))
print("lazy data: nothing built at login, built once on first use")
