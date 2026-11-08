-- The journal's start (F-146 step 3, D-72): the own run of a dungeon (kills by encounter id, a
-- reset, another instance, back after a long time outside, saved per character), the cards' badge
-- (kills "n/m", open quests) and "Hier bist du"; the filter row (search, Alle/Passend/Quests, "Wo
-- bin ich"); the page opens the dungeon the character stands in (once per entry).
local R = NS.Runs
local fact
for _, e in ipairs(NS.DUNGEON_FACTS.list) do if e.key == "thanes" then fact = e end end
assert(fact and fact.inst == 3065, "the thanes in the facts")
-- the encounter ids in the game's order (the facts get them from DungeonEncounter)
local keepEnc = fact.enc
fact.enc = { 3001, 3002, 3003, 3004 }
local clock = 1000000
local keepTime = time
time = function() return clock end

-- outside: no run
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(R.Here() == nil and R.Of("thanes") == nil, "no run outside")
-- entering the thanes: a run, nothing killed
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(R.Here() == "thanes")
local killed, n, m = R.Of("thanes")
assert(killed and n == 0 and m == 4, "a fresh run: " .. tostring(n) .. "/" .. tostring(m))
-- a kill (ENCOUNTER_END with success), the same fight's BOSS_KILL counts once, a wipe not at all
STUB.fire("ENCOUNTER_END", 3001, "Faldrim Anvilmar", 1, 5, 1)
STUB.fire("BOSS_KILL", 3001, "Faldrim Anvilmar")
STUB.fire("ENCOUNTER_END", 3002, "Infurnus", 1, 5, 0)
_, n = R.Of("thanes")
assert(n == 1 and R.Killed("thanes", 1) and not R.Killed("thanes", 2), "one kill")
-- saved per character, checked on load
local c = NS.BisChar()
assert(c.run.inst == 3065 and c.run.enc[3001] == true)
c.run.enc.bad = 7
NS.BisMigrate(AmisiaDB)
assert(c.run.enc.bad == nil and c.run.enc[3001] == true, "the saved run checked")
-- a /reload inside: the run stays
STUB.fire("PLAYER_ENTERING_WORLD")
assert(select(2, R.Of("thanes")) == 1, "a reload keeps the run")
-- out and back in soon: the same run; after more than half an hour: a fresh one
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("ZONE_CHANGED_NEW_AREA")
clock = clock + 600
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("ZONE_CHANGED_NEW_AREA")
assert(select(2, R.Of("thanes")) == 1, "back soon: the same run")
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("ZONE_CHANGED_NEW_AREA")
clock = clock + 1900
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("ZONE_CHANGED_NEW_AREA")
assert(select(2, R.Of("thanes")) == 0, "back after a long time: a fresh run")
-- marked by hand; the reset message of another instance changes nothing, its own starts afresh
-- (inside: a new run with nothing killed)
assert(R.Mark("thanes", 2, true) and R.Killed("thanes", 2))
assert(R.Mark("thanes", 2, false) and not R.Killed("thanes", 2))
R.Mark("thanes", 3, true)
_G.INSTANCE_RESET_SUCCESS = "%s has been reset."
STUB.fire("CHAT_MSG_SYSTEM", "Ragefire Chasm has been reset.")
assert(R.Killed("thanes", 3), "another instance's reset")
STUB.fire("CHAT_MSG_SYSTEM", "Hall of Thanes has been reset.")
assert(select(2, R.Of("thanes")) == 0 and NS.BisChar().run.name == "Hall of Thanes", "the reset: a fresh run inside")
STUB.fire("CHAT_MSG_SYSTEM", "Hall of Thanes (has been reset.")   -- no pattern error from a magic character
-- a logout inside counts as leaving: back the next day, a fresh run
R.Mark("thanes", 1, true)
STUB.fire("PLAYER_LEAVING_WORLD")
clock = clock + 86400
STUB.fire("PLAYER_ENTERING_WORLD")
assert(select(2, R.Of("thanes")) == 0, "a logout inside, back the next day: a fresh run")
-- outside, the reset message ends the run
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("CHAT_MSG_SYSTEM", "Hall of Thanes has been reset.")
assert(NS.BisChar().run == nil, "the reset outside ends the run")
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
-- another instance: the thanes' run is gone
STUB.fire("ENCOUNTER_END", 3004, "Durgen Dirgehammer", 1, 5, 1)
assert(select(2, R.Of("thanes")) == 1)
STUB.instance = { name = "Ragefire Chasm", type = "party", id = 389 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(R.Of("thanes") == nil and R.Here() == "rfc", "another instance, another run")
-- a mark by hand only for the instance the character stands in
assert(not R.Mark("thanes", 1, true), "no mark for a dungeon elsewhere")

-- the page: inside the thanes it opens their detail, once per entry
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("ENCOUNTER_END", 3001, "Faldrim Anvilmar", 1, 5, 1)
NS.ShowPage("dungeons")
local B = NS.PageFrame("dungeons")
assert(B and B.chosen == "thanes" and B.art:IsShown() and not B.table:IsShown(), "the dungeon the character stands in")
B.back:Click()
assert(B.table:IsShown(), "back to the cards: it stays there")
NS.Refresh()
assert(B.table:IsShown(), "no second jump while still inside")
-- the rows: the thanes "Hier bist du" with the full frame round its picture, the run's kills
local card = B.table:RowOf("thanes")
assert(card and card.sub:GetText():find("Hier bist du", 1, true), "here: " .. tostring(card and card.sub:GetText()))
assert(card.artFrame.edges[1].color[4] == 1, "the full gold frame")
assert(card.sub:GetText():find("1/4", 1, true), tostring(card.sub:GetText()))
-- another row has no run (its quests in their column)
local other = B.table:RowOf("rfc")
assert(not other.sub:GetText():find("Hier bist du", 1, true) and not other.sub:GetText():find("/", 1, true))
-- the filter row: on the start only, between the head row and the recommendation
assert(B.search:IsShown() and B.filterTabs.all:IsShown() and B.filterTabs.fit and B.filterTabs.quests and B.hereLink:IsShown())
assert(B.filterTabs.all.on and B.filter.mode == "all")
local all = #B.table.entries
-- the search: from two characters; a boss's name finds its dungeon
B.search:SetText("f")
B.search.scripts.OnTextChanged(B.search, true)
assert(#B.table.entries == all, "one character filters nothing")
B.search:SetText("faldrim")
B.search.scripts.OnTextChanged(B.search, true)
assert(#B.table.entries == 1 and B.table.entries[1].key == "thanes", "a boss finds its dungeon: " .. #B.table.entries)
B.search:SetText("zzzz")
B.search.scripts.OnTextChanged(B.search, true)
assert(#B.table.entries == 0 and B.emptyGrid:IsShown(), "nothing found: the empty state")
B.search:SetText("")
B.search.scripts.OnTextChanged(B.search, true)
assert(#B.table.entries == all and not B.emptyGrid:IsShown())
-- "Passend": only the fitting ones
B.filterTabs.fit:Click()
for _, e in ipairs(B.table.entries) do assert(e.fit == "fit", e.key .. " " .. tostring(e.fit)) end
assert(B.filterTabs.fit.on and not B.filterTabs.all.on)
-- "Quests": only dungeons with open quests
B.filterTabs.quests:Click()
for _, e in ipairs(B.table.entries) do
    local open = 0
    for _, q in ipairs((NS.DungeonQuests(e.key))) do
        local st = NS.Dungeons.QuestState(q)
        if st == "open" or st == "active" or st == "ready" then open = open + 1 end
    end
    assert(open > 0, e.key)
end
B.filterTabs.all:Click()
-- "Wo bin ich": the dungeon the character stands in; outside a message
B.hereLink:Click()
assert(B.chosen == "thanes" and B.art:IsShown(), "where am I")
B.back:Click()
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
local said
local msg = NS.msg
NS.msg = function(t) said = t end
B.hereLink:Click()
NS.msg = msg
assert(said and said:find("keiner Instanz", 1, true), tostring(said))
-- entering while the page is open: it jumps there
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
NS.Refresh()
assert(B.art:IsShown() and B.chosen == "thanes", "entered while open: its detail")
-- the raids page has the filter row too, without the choice Quests
NS.ShowPage("raidjournal")
local RB = NS.PageFrame("raidjournal")
assert(RB.search and RB.filterTabs.all and RB.filterTabs.fit and RB.filterTabs.quests == nil and RB.hereLink, "the raids' filter row")

fact.enc = keepEnc
time = keepTime
print("journal start ok")
