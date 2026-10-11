-- Review 24: the keeper's plus-one snapshot keeps every player under the 80-line cap (mains first,
-- then the names that won, then the other linked alts); MainOf / SameMain / PlusList / PlusCount
-- stay cheap with a long alt list (a SameName call budget); the waypoint of a quest that starts
-- inside a dungeon goes to the dungeon's entrance; the site import names the skipped alt lines.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

---------------------------------------------------------------------------
-- 30 players with 3 alts each, 10 of them with two mainspec wins
---------------------------------------------------------------------------
local lines = { "#AMISIA-ALTS 1 forever 2026-10-06" }
local mains = {}
for i = 1, 30 do
    local main = "Main" .. string.char(64 + (i % 26) + 1) .. string.rep("a", math.floor(i / 26) + 1)
    mains[i] = main
    for j = 1, 3 do lines[#lines + 1] = ("A Alt%s%s %s"):format(string.char(96 + j), main:lower(), main) end
end
lines[#lines + 1] = "#END"
local res, why = NS.SetAlts(table.concat(lines, "\n"))
assert(res and res.n == 90, tostring(why))
STUB.roster = {}
for i = 1, 30 do STUB.roster[i] = { name = mains[i], class = "MAGE" } end
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording")
STUB.item(32235, "Cursed Vision of Sargeras", 4)
for i = 1, 30 do
    for _ = 1, (i <= 10 and 2 or 1) do NS.AddAwardTo(s, { name = mains[i], item = 32235, kind = "MS", src = "?" }) end
end
-- one player won on an alt: that name goes before the other alts
NS.AddAwardTo(s, { name = "Altb" .. mains[30]:lower(), item = 32235, kind = "MS", src = "?" })

---------------------------------------------------------------------------
-- 3. the snapshot: every player's main is in, the won alt too, the cap holds
---------------------------------------------------------------------------
local sp = NS.SyncBuild(s)
local n, missing = 0, {}
for _ in pairs(sp.p.n) do n = n + 1 end
for i = 1, 30 do if sp.p.n[mains[i]] == nil then missing[#missing + 1] = mains[i] end end
assert(#missing == 0, "players missing from the snapshot: " .. table.concat(missing, ","))
assert(n == 80, "the cap is used: " .. n)
assert(sp.p.n[mains[30]] == 2 and sp.p.n["Altb" .. mains[30]:lower()] == 2, "the alt that won is in")
assert(sp.p.n[mains[11]] == 1 and sp.p.n[mains[1]] == 2)
-- a raider without the alt list finds a low-plus player by the main's name
s.sync = s.sync or {}
s.sync.plus = sp.p
local keeper, officer = NS.SyncIsKeeper, NS.IsOfficerView
NS.SyncIsKeeper = function() return false end
NS.IsOfficerView = function() return false end
assert(NS.PlusCount(mains[25]) == 1, "a raider sees the keeper's number: " .. NS.PlusCount(mains[25]))
NS.SyncIsKeeper, NS.IsOfficerView = keeper, officer
s.sync.plus = nil

---------------------------------------------------------------------------
-- 4. the plus-one stays cheap with 90 alts: a budget of SameName calls
---------------------------------------------------------------------------
local same, calls = NS.SameName, 0
NS.SameName = function(a, b) calls = calls + 1 return same(a, b) end
local list = NS.PlusList()
assert(#list == 30 and list[1].n == 2 and list[30].n == 1, "one entry per player")
local last = list[#list]
for i = 1, 30 do
    if list[i].name == mains[30] then last = list[i] end
end
assert(last.n == 2 and last.names["Altb" .. mains[30]:lower()] and last.names["Alta" .. mains[30]:lower()], "the alt's win counts for the main")
for i = 1, 30 do assert(NS.PlusCount(mains[i]) == (i <= 10 and 2 or (i == 30 and 2 or 1)), "PlusCount " .. mains[i]) end
assert(NS.PlusCount("Altc" .. mains[3]:lower()) == 2 and NS.PlusCount("Fremder") == 0)
NS.SyncBuild(s)
NS.SameName = same
assert(calls < 6000, "SameName calls for PlusList, 32 PlusCounts and a snapshot: " .. calls)
-- the memo follows the list: a new list, a cleared list
assert(NS.MainOf("Alta" .. mains[1]:lower()) == mains[1])
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-06\nA Alta" .. mains[1]:lower() .. " " .. mains[2] .. "\n#END"))
assert(NS.MainOf("Alta" .. mains[1]:lower()) == mains[2], "a new list, a new main")
assert(#NS.AltsOf(mains[1]) == 0 and #NS.AltsOf(mains[2]) == 1)
NS.ClearAlts()
assert(NS.MainOf("Alta" .. mains[1]:lower()) == "Alta" .. mains[1]:lower(), "no list: its own main")
assert(#NS.AltsOf(mains[2]) == 0)
-- the spelling of a name that is no alt is kept
assert(NS.MainOf("fremder") == "fremder" and NS.MainOf("Fremder") == "Fremder")

---------------------------------------------------------------------------
-- the site import names the skipped alt lines
---------------------------------------------------------------------------
local text, ok = NS.ImportSiteText("#AMISIA-ALTS 1 forever 2026-10-06\nA Bob Anna\nA Zed Anna\nkaputt\nA Bob Carla\n#END")
assert(ok and text == "2 Twinks übernommen, 2 übersprungen.", text)
text, ok = NS.ImportSiteText("#AMISIA-ALTS 1 forever 2026-10-06\nA Bob Anna\n#END")
assert(ok and text == "1 Twink übernommen.", text)
NS.ClearAlts()

---------------------------------------------------------------------------
-- 5. a quest that starts inside a dungeon: the waypoint goes to the entrance
---------------------------------------------------------------------------
NS.DUNGEON_QUESTS = {
    built = "test", questie = "test",
    D = { deadmines = { 99020 }, thanes = { 99021 } },
    Q = {
        [99020] = { "Deep Inside", 15, 19, "", 0, "I", "Mine Giver", "1436:1000:2000", nil, nil, "deadmines" },
        [99021] = { "Inside the Halls", 15, 17, "", 0, "I", "Halls Giver", "1436:4250:7170", nil, nil, "thanes" },
    },
}
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
local entrance, key = NS.DungeonEntrance("deadmines")
assert(entrance and key, "the mines have an entrance in the map data")
assert(NS.DungeonQuestWaypoint(99020), "the entrance")
local t = NS.MapTarget()
assert(t.label == "The Deadmines (Eingang)", t.label)
assert(t.map == entrance.map and t.x == entrance.x and t.y == entrance.y,
    ("the entrance's point, not the giver's: %s %s %s"):format(tostring(t.map), tostring(t.x), tostring(t.y)))
-- no entrance known: the giver's point inside, named as the giver
assert(NS.DungeonEntrance("thanes") == nil)
assert(NS.DungeonQuestWaypoint(99021), "the giver's point as the fallback")
t = NS.MapTarget()
assert(t.map == 1436 and math.abs(t.x - 0.425) < 1e-6 and math.abs(t.y - 0.717) < 1e-6, "the giver's point")
assert(t.label == "Questgeber Halls Giver (im Dungeon)", t.label)
NS.MapClearTarget()
assert(has("x", "x"))
