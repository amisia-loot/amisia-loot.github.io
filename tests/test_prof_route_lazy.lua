-- The bag counts of the profession route (Gear/ProfRoute.lua, F-137) never build the profession data
-- (D-28): login, bag updates, the bank and the logout count only the list of reagents saved the last
-- time the data was built (the char's bags entry, track), with realm and faction; the real data
-- waits as text throughout. Opening the route builds it and refreshes the list.
local R = NS.ProfRoute
local function built() return NS.DataBuilt().PROFESSIONS ~= nil or rawget(NS, "PROFESSIONS") ~= nil end
local me = NS.UnitFullName("player")
GetRealmName = function() return "Forever" end   -- the realm the client names (Forever's names carry none)
GetProfessions = function() return 1 end
GetProfessionInfo = function() return "Schneiderei", 136249, 120, 150, 2, 0, 197 end
AmisiaDB.prof = { chars = {}, bags = { [me] = { day = 1, items = {}, track = { 2589, 2320 } } } }
NS.ProfBagsLoaded(AmisiaDB)
assert(NS.HasData("PROFESSIONS") and not built(), "the profession data waits")

STUB.bags[0] = { 2589, 2589, 2320, 4306 }
STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("BAG_UPDATE_DELAYED")
STUB.tick(10)
STUB.fire("BANKFRAME_OPENED"); STUB.fire("BANKFRAME_CLOSED")
STUB.fire("PLAYER_LOGOUT")
assert(not built(), "login, bags, bank and logout build no profession data")
local e = AmisiaDB.prof.bags[me]
assert(e.items[2589] == 2 and e.items[2320] == 1 and e.items[4306] == nil, "the saved list counted, nothing else")
assert(e.realm == "Forever" and e.faction == "A" and e.track[1] == 2589, "realm, faction and the list kept")

-- without a saved list nothing is counted and nothing is built
AmisiaDB.prof.bags = {}
STUB.fire("BAG_UPDATE_DELAYED")
STUB.tick(10)
assert(not built() and AmisiaDB.prof.bags[me] == nil, "no list: no count, no build")

-- the route builds the data and refreshes the list from it
local route = R.Get(197, false)
assert(route and built(), "the route builds the data")
local list = AmisiaDB.prof.bags[me].track
local set = {}
for _, item in ipairs(list) do set[item] = true end
assert(#list > 100 and set[2589] and set[4306] and set[14047], "the tailoring reagents from the data")
assert(AmisiaDB.prof.bags[me].items[4306] == 1, "silk counted now")
