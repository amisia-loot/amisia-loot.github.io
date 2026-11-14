-- The map page's new parts on small data: the chip "Quests" (map.pinsQuests) with the next step of each
-- open dungeon quest of a dungeon that fits the own level (its giver while it can be taken, its
-- turn-in once it is in the log and complete, nothing while it is under way or out of reach), one
-- place per step and point with the dungeon quests' upgrade rewards; a click sets the target, the
-- menu opens the quest path; the same steps as plain yellow "!" pins on Amisia's own layer of the world
-- map, by the same setting, cheap (the steps are built once per change); the view "Ohne Ort" (the
-- profession with its recipe and crafters, the auction house, no place data) with its way back and a
-- click that opens the recipe or the gear page; German names the collector saw itself instead of
-- the data's English ones, and the footer's "Namen teils englisch" only while a row still shows one.
local Gear, Map, Dn = NS.Gear, NS.Map, NS.Dungeons
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

local ready = dofile(ADDON_DIR .. "/../tests/map_steps_fixture.lua")

local deadmines
for _, e in ipairs(NS.DungeonList()) do if e.key == "deadmines" then deadmines = e end end
assert(deadmines and (deadmines.fit == "fit" or deadmines.fit == "soon"), "the Deadmines fit level 16: " .. tostring(deadmines and deadmines.fit))

---------------------------------------------------------------------------
-- the steps: one place for 501 (the first step of 500 and 510), nothing for 520 (level 40)
---------------------------------------------------------------------------
local steps = NS.DungeonQuestSteps()
assert(#steps == 1, "one step: " .. #steps)
local s = steps[1]
assert(s.key == "Q:501" and s.step and s.title == "Root" and s.point.map == 1436 and math.abs(s.point.x - 0.1) < 1e-6, s.key)
assert(table.concat(s.fors, ",") == "Final Quest,Second Final" and s.label == "Questgeber Root Giver" and s.dataName, table.concat(s.fors, ","))
assert(s.items[1] and s.items[1].id == 804 and #s.items == 1, "the dungeon quest's upgrade reward")
assert(Map.StepText(s) == "Root (für Final Quest, Second Final)", Map.StepText(s))
-- kept while nothing changes
local stamp = NS.DungeonQuestStepsStamp()
assert(NS.DungeonQuestSteps() == steps and NS.DungeonQuestStepsStamp() == stamp, "kept")
-- 501 in the log and under way: no place; complete: its turn-in (unknown here: none); done: 502's giver
STUB.questsActive[501] = true
STUB.fire("QUEST_ACCEPTED", 501)
assert(#NS.DungeonQuestSteps() == 0, "a step under way has no place")
ready[501] = true
assert(#NS.DungeonQuestSteps() == 0, "complete, but no turn-in known")
STUB.questsActive[501], ready[501] = nil, nil
STUB.questsDone[501] = true
STUB.fire("QUEST_TURNED_IN", 501)
steps = NS.DungeonQuestSteps()
local keys = {}
for _, p in ipairs(steps) do keys[#keys + 1] = p.key .. "=" .. Map.StepText(p) end
table.sort(keys)
assert(table.concat(keys, "|") == "Q:502=Middle (für Final Quest)|Q:510=Second Final", table.concat(keys, "|"))
-- 502 in the log and complete: where it is handed in
STUB.questsActive[502] = true
STUB.fire("QUEST_ACCEPTED", 502)
assert(#NS.DungeonQuestSteps() == 1, "under way: only 510")
ready[502] = true
local turn
for _, p in ipairs(NS.DungeonQuestSteps()) do if p.key == "Q:502" then turn = p end end
assert(turn and turn.turnIn and turn.label == "Abgabe Mid Ender" and math.abs(turn.point.x - 0.25) < 1e-6, "the turn-in once complete")
assert(Map.StepText(turn) == "Middle abgeben (für Final Quest)", Map.StepText(turn))
-- back to the start for the page
STUB.questsActive[502], ready[502], STUB.questsDone[501] = nil, nil, nil
STUB.fire("QUEST_REMOVED", 502)
assert(#NS.DungeonQuestSteps() == 1 and NS.DungeonQuestSteps()[1].key == "Q:501")

---------------------------------------------------------------------------
-- the page: all zones, the step row under Westfall
---------------------------------------------------------------------------
-- the boots are a wish (the auction house is no source of the targets)
assert(NS.WishAdd(803))
NS.ShowMap("alle")
local f = NS.PageFrame("map")
local rows = f.list.rows
local function find(key)
    for i, e in ipairs(f.list.items) do if e.key == key then return e, rows[i] end end
end
local e, row = find("Q:501")
assert(e and row and f.quests.on, "the step's row")
assert(row.kind:GetText() == "Quest-Schritt" and row.src:GetText() == "Root (für Final Quest, Second Final)", row.src:GetText())
assert(row.where:GetText():find("^10, 10 · %d+ m$") and has(row.items:GetText(), "Van-Cleef-Gurt"), row.where:GetText())
assert(f.list.items[1].header and f.list.items[1].name == "Westfall", "Westfall first")
-- a click: the target at the giver, without an item
row.scripts.OnClick(row, "LeftButton")
local t = NS.MapTarget()
assert(t and t.key == "Q:501" and t.label == "Questgeber Root Giver" and t.item == nil, "the step as the target")
assert(f.target:GetText() == "Ziel: Questgeber Root Giver", f.target:GetText())
NS.MapClearTarget()
-- the menu: the quest path
row.scripts.OnClick(row, "RightButton")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(table.concat(labels, ",") == "Ziel setzen,Questweg zeigen,Diesen Ort ausblenden,Quest-Schritte ausblenden", table.concat(labels, ","))
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() and b.label:GetText() == "Questweg zeigen" then b:Click() break end end
assert(NS.CurrentPage() == "dungeons", "the quest path on the page Dungeons")
NS.ShowMap()
-- the tooltip names the step and the reward
local lines = {}
local addLine, addDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. " = " .. b end
row.scripts.OnEnter(row)
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble
local tip = table.concat(lines, "|")
assert(lines[1] == "Questgeber Root Giver" and has(tip, "Root (für Final Quest, Second Final)") and has(tip, "Van-Cleef-Gurt"), tip)
-- the chip switches them off, here and on the map
f.quests:Click()
assert(NS.Get("map.pinsQuests") == false and not find("Q:501"), "Quests off")
f.quests:Click()
assert(find("Q:501"), "on again")

---------------------------------------------------------------------------
-- the pins: a plain yellow "!" on Westfall, by the same setting; built once per change
---------------------------------------------------------------------------
local pins = Map.PinPlaces(1436)
local pin
for _, p in ipairs(pins) do if p.step then pin = p end end
assert(pin and pin.key == "Q:501" and math.abs(pin.x - 0.1) < 1e-6, "the step's pin")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1436)
STUB.tick(1)
local shown
for _, p in ipairs(Map.ShownPins("item")) do if p.entry.step then shown = p end end
assert(shown and shown.icon.texture == "Interface\\GossipFrame\\AvailableQuestIcon", "the gossip window's yellow !")
for _, edge in ipairs(shown.edges) do assert(not edge:IsShown(), "no frame") end
assert(not shown.count:IsShown(), "no count")
-- cheap: drawing again builds no steps
local calls, real = 0, NS.DungeonQuests
NS.DungeonQuests = function(...) calls = calls + 1; return real(...) end
for _ = 1, 20 do Map.PinPlaces(1436); Map.PinPlaces(1415); NS.Refresh() end
NS.DungeonQuests = real
assert(calls == 0, "no quest lists for redraws: " .. calls)
NS.Set("map.pinsQuests", false)
for _, p in ipairs(Map.PinPlaces(1436)) do assert(not p.step, "no step pin with map.pinsQuests off") end
NS.Set("map.pinsQuests", true)
NS.Set("map.pins", false)
for _, p in ipairs(Map.PinPlaces(1436)) do assert(not p.step, "no step pin with map.pins off") end
NS.Set("map.pins", true)
-- a click on the pin sets the target
local again
for _, p in ipairs(Map.PinPlaces(1436)) do if p.step then again = p end end
assert(Map.SetPlaceTarget(again) and NS.MapTarget().key == "Q:501", "the pin's click")
NS.MapClearTarget()
WorldMapFrame:Hide()
NS.ShowMap()

---------------------------------------------------------------------------
-- the view "Ohne Ort": the link, the reasons, the clicks, the way back
---------------------------------------------------------------------------
assert(f.noPlace:IsShown(), "the link")
local link = f.noPlace.label:GetText()
assert(has(link, "3 Items ohne Ort") and has(link, "Auktionshaus") and has(link, "Berufe") and has(link, "keine Ortsdaten"), link)
local realFor = NS.Crafters.ForItem
NS.Crafters.ForItem = function(id) return id == 2853 and { { name = "Anna", rank = 75 } } or {} end
f.noPlace:Click()
assert(f.view == "noplace" and f.npList:IsShown() and not f.list:IsShown() and f.back:IsShown() and not f.open:IsShown(), "the view")
assert(not f.noPlace:IsShown() and f.counts:GetText() == link:gsub("^· ", ""), f.counts:GetText())
local why = {}
for i, n in ipairs(f.npList.items) do why[n.id] = f.npList.rows[i].why:GetText() end
assert(why[2853] == "Beruf: Schmiedekunst - Kupferarmschienen · kann herstellen: Anna (75)", tostring(why[2853]))
assert(why[803] == "Auktionshaus (bindet beim Anlegen)", tostring(why[803]))
assert(why[804] and why[804]:find("^keine Ortsdaten: Quest: Final Quest"), tostring(why[804]))
assert(f.hint:GetText() == "Klick auf ein Item: Rezept oder Ausrüstung öffnen.", f.hint:GetText())
NS.Crafters.ForItem = realFor
-- a click on the crafted item: the recipe on the professions page
local opened
local realShow = NS.ShowRecipe
NS.ShowRecipe = function(skill, spell, name) opened = { skill, spell, name } end
for i, n in ipairs(f.npList.items) do if n.id == 2853 then f.npList.rows[i].scripts.OnClick(f.npList.rows[i]) end end
NS.ShowRecipe = realShow
assert(opened and opened[1] == 164 and opened[2] == 2663 and opened[3] == "Kupferarmschienen", "the recipe")
-- the boots: the gear page
for i, n in ipairs(f.npList.items) do if n.id == 803 then f.npList.rows[i].scripts.OnClick(f.npList.rows[i]) end end
assert(NS.CurrentPage() == "gear" and AmisiaDB.settings.bis.view == "wish", "the wish on the gear page")
NS.ShowPage("map")
-- the page stays in its view; the button leads back
assert(f.view == "noplace", "kept while the page changes")
f.back:Click()
assert(f.view == nil and f.list:IsShown() and not f.npList:IsShown() and f.open:IsShown(), "back")

---------------------------------------------------------------------------
-- German names: the collector's own vendor record names the helm's vendor; the footer
---------------------------------------------------------------------------
local _, vrow = find("U:491")
assert(vrow.src:GetText() == "Quartermaster Lewis", vrow.src:GetText())
assert(has(f.data:GetText(), "Namen teils englisch"), f.data:GetText())
local day = NS.DropsToday()
assert(NS.CollectPut("s", 491, NS.CollectFormat("s", { day = day, pos = "1436:5700:4700", items = {}, name = "Rüstmeister Lewis" }), "own"))
assert(NS.CollectPut("q", 501, NS.CollectFormat("q", { day = day, giver = 99, gpos = "1436:1000:1000", ender = 0, epos = "",
    rewards = {}, choices = {}, qlevel = 0, minlvl = 0, fac = "", pre = 0, gname = "Wurzelgeber", ename = "", obj = "", title = "" }), "own"))
assert(NS.CollectOwnName(491) == "Rüstmeister Lewis" and Map.OwnName("U:491") == "Rüstmeister Lewis", tostring(NS.CollectOwnName(491)))
NS.Refresh()
_, vrow = find("U:491")
assert(vrow.src:GetText() == "Rüstmeister Lewis", "the own name: " .. vrow.src:GetText())
local srow
e, srow = find("Q:501")
assert(e and not e.dataName and e.label == "Questgeber Wurzelgeber", tostring(e and e.label))
assert(f.data:GetText() == "Kartendaten vom 05.11.2026 · Orte aus öffentlichen Questdaten.", f.data:GetText())
-- a name only heard from the guild does not count
assert(NS.CollectPut("s", 492, NS.CollectFormat("s", { day = day, pos = "1436:5000:5000", items = {}, name = "Gehörter Name" }), "heard"))
assert(NS.CollectOwnName(492) == nil and Map.OwnName("U:492") == nil, "heard only")

---------------------------------------------------------------------------
-- English: the step and the view's texts
---------------------------------------------------------------------------
for _, name in ipairs({ "UI/Pages/Map.lua", "Gear/Dungeons.lua", "Gear/MapPins.lua", "Collect/Collector.lua" }) do
    local fh = assert(io.open(ADDON_FILE(name), "rb"))
    local src = fh:read("*a")
    fh:close()
    for c in src:gmatch("[\196-\255][\128-\191]") do error(name .. ": character above Latin-1: " .. c) end
end
