--[[locale enUS]]
-- English for the gear and world area: the gear page (targets, explanation, menu, wishlist, the
-- overview card), the tooltip line, the gear window, the wish and bis commands with their English
-- sub-words, the dungeon planner's texts, the drop rates, the professions' names and sources, the
-- quests page; numbers and dates the English way; no German umlaut word shows.
local Gear = NS.Gear
local L = NS.L
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function german(t) return type(t) == "string" and t:find("[\195][\164\182\188\132\150\156\159]") ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function msgs() return table.concat(STUB.messages, "\n") end

-- every text a frame tree shows, joined
local function texts(frame, out, seen)
    out, seen = out or {}, seen or {}
    if type(frame) ~= "table" or seen[frame] then return out end
    seen[frame] = true
    if frame.GetText and frame.IsShown and frame:IsShown() then
        local ok, t = pcall(frame.GetText, frame)
        if ok and type(t) == "string" and t ~= "" then out[#out + 1] = t end
    end
    for _, v in pairs(frame) do
        if type(v) == "table" and v ~= frame and (v.GetText or v.GetObjectType or #v > 0) then texts(v, out, seen) end
    end
    return out
end
local function shown(frame) return table.concat(texts(frame), "\n") end

STUB.class, STUB.level = "WARRIOR", 60
STUB.instance = { name = "Molten Core", type = "raid", id = 409 }
STUB.areas[2717], STUB.areas[2677], STUB.areas[2017] = "Molten Core", "Blackwing Lair", "Stratholme"
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Anna", class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

---------------------------------------------------------------------------
-- numbers, slot and class names, the spec names and reasons of the generated weights
---------------------------------------------------------------------------
assert(Gear.Num(2.5, 1) == "2.5", Gear.Num(2.5, 1))
assert(Gear.SLOTS[1].name == "Head" and Gear.SLOTS[16].name == "Off hand", Gear.SLOTS[1].name)
assert(Gear.CLASS_NAMES.WARLOCK == "Warlock")
assert(L["Waffen/Furor"] == "Arms/Fury" and L["Wilder Kampf"] == "Feral Combat" and L["Gebrechen"] == "Affliction")
assert(NS.BIS_PLANS.SHIELD == "weapon and shield" and NS.BIS_PRIO_TEXT[3] == "high")

---------------------------------------------------------------------------
-- a small Forever data set
---------------------------------------------------------------------------
NS.GEAR = { game = "forever", cap = 60, built = "test-l10n", I = {}, Z = {}, S = {
    { "X", "Molten Core", "Ragnaros", 409, 2717, 1, 0 },
    { "X", "Molten Core", "Lucifron", 409, 2717, 1, 0 },
    { "X", "Blackwing Lair", "Nefarian", 469, 2677, 1, 0 },
    { "D", "Stratholme", "Baron Rivendare", nil, 329, 2017 },
} }
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, stats, sources)
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 4
    it.stats, it.minLevel = stats, 60
    if sources then
        NS.GEAR.I[id] = { loc, 4, 4, 60, 4, 1, 141, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
gear(301, "Helm A", "HEAD", str(40), { 1 })
gear(302, "Helm B", "HEAD", str(30), { 2 })
gear(304, "Core Chest", "CHEST", str(50), { 2 })
gear(306, "Dungeon Helm", "HEAD", str(25), { 4 })
gear(310, "Old Helm", "HEAD", str(10))
STUB.worn[1] = LINKS[310]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

---------------------------------------------------------------------------
-- the gear page
---------------------------------------------------------------------------
NS.ShowPage("gear")
local f = NS.GearPageFrame()
assert(f and f:IsShown())
assert(plain(f.spec.label:GetText()) == "Arms/Fury (guessed)", f.spec.label:GetText())
assert(f.views.goals.label:GetText() == "Goals" and f.views.wish.label:GetText() == "Wishlist (0)", f.views.wish.label:GetText())
assert(f.open:GetText() == "Table" and f.src.C.label:GetText() == "Profs: all" and f.src.W.label:GetText() == "World")
local counts = f.counts:GetText()
assert(has(counts, "Level 60") and has(counts, "Bank not opened yet"), counts)
local G = f.goals
assert(G.head.worn:GetText() == "Worn" and G.head.gain:GetText() == "Gain" and G.why:GetText() == "Why?",
    tostring(G.head.worn:GetText()) .. "/" .. tostring(G.head.gain:GetText()) .. "/" .. tostring(G.why:GetText()))
local rows = G.list.rows
assert(plain(rows[1].slot:GetText()) == "Head")
assert(has(rows[2].best:GetText(), "no option") and has(rows[2].worn:GetText(), "nothing"), "an empty neck")
assert(G.title:GetText() == "Head · best for Arms/Fury (guessed)", G.title:GetText())
assert(G.opts[1].wish:GetText() == "Wish" and G.opts[1].ex:GetText() == "Skip", tostring(G.opts[1].wish:GetText()) .. "/" .. tostring(G.opts[1].ex:GetText()))
local ex = G.explain:GetText()
assert(has(ex, "+60 points, worth 60 Attack power") and has(ex, "40 Strength x 2.0 = 80"), ex)
-- the right-click menu
G.opts[1].scripts.OnClick(G.opts[1], "RightButton")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(table.concat(labels, "|") == "Exclude item|Exclude boss|Exclude place|Add to the wishlist|Link in chat", table.concat(labels, "|"))
AmisiaMenu:Hide()
-- a wish and an exclusion
G.opts[2].wish:Click()
assert(G.opts[2].wish:GetText() == "Unwish" and f.views.wish.label:GetText() == "Wishlist (1)")
G.opts[1].ex:Click()
assert(has(f.counts:GetText(), "1 excluded") and f.reset:GetText() == "reset", f.counts:GetText())
assert(StaticPopupDialogs.AMISIA_BIS_CLEAR_EX.text == "Lift all exclusions?" and StaticPopupDialogs.AMISIA_BIS_CLEAR_EX.button2 == "Cancel")
NS.BisClearExcludes()
-- the why tooltip: the spec's reason in English
local why = table.concat(NS.BisWhy(), "\n")
assert(has(why, "Warrior: weapon damage counts in full") and has(why, "One point of score is worth 1 Attack power."), why)
assert(not german(shown(f)), "no German on the gear page: " .. shown(f))

-- the wishlist
NS.Dispatch("bis")
f.views.wish:Click()
local V = f.wish
assert(V:IsShown() and V.head.prio:GetText() == "Priority" and V.web:GetText() == "For the website", V.web:GetText())
assert(plain(V.list.rows[1].prio.label:GetText()) == "medium", V.list.rows[1].prio.label:GetText())
assert(has(V.hint:GetText(), "1 of 50 wishes"), V.hint:GetText())
assert(not german(shown(V)), shown(V))

-- the overview card
local card = { title = {}, line1 = {}, line2 = {} }
for _, k in ipairs({ "title", "line1", "line2" }) do
    card[k].SetText = function(self, t) self.text = t end
    card[k].SetMaxLines = function() end
end
card.SetAction = function(self, label) self.action = label end
for _, c in ipairs(NS.cards) do
    if c.key == "gear" then c.fill(card) end
end
assert(card.title.text == "Your gear" and card.action == "View", tostring(card.title.text))
assert(has(card.line1.text, "1 wish"), tostring(card.line1.text))

---------------------------------------------------------------------------
-- the tooltip line and the toast's titles
---------------------------------------------------------------------------
local lines = {}
for _, l in ipairs(NS.BisTooltipLines(LINKS[301]) or {}) do lines[#lines + 1] = l[1] end
local tip = table.concat(lines, "\n")
assert(has(tip, "Upgrade for you") and has(tip, "Head") and has(tip, "instead of Old Helm"), tip)

---------------------------------------------------------------------------
-- commands: wish, bis (English sub-words), gear
---------------------------------------------------------------------------
STUB.messages = {}
NS.Dispatch("wish " .. LINKS[304] .. " high best chest")
assert(has(msgs(), "on your wishlist (high, best chest)."), msgs())
STUB.messages = {}
NS.Dispatch("wish remove " .. LINKS[304])
assert(has(msgs(), "removed from your wishlist."), msgs())
STUB.messages = {}
NS.Dispatch("wish nonsense")
assert(has(msgs(), "Usage: /amisia wish <item link> [high|medium|low] [note]"), msgs())
STUB.messages = {}
NS.Dispatch("bis exclude " .. LINKS[301])
assert(has(msgs(), "excluded. /amisia bis reset lifts all exclusions."), msgs())
STUB.messages = {}
NS.Dispatch("bis reset")
assert(has(msgs(), "1 exclusion lifted."), msgs())
STUB.messages = {}
NS.Dispatch("bis weights")
assert(has(msgs(), "Weights (Speedrun, level 60):") and has(msgs(), "Strength 2.0"), msgs())
STUB.messages = {}
NS.Dispatch("bis compare " .. LINKS[301] .. " " .. LINKS[302])
assert(has(msgs(), "The first leads by 20, mostly from Strength."), msgs())
STUB.messages = {}
NS.Dispatch("bis plan shield")
assert(has(msgs(), "Weapon plan: weapon and shield."), msgs())
STUB.messages = {}
NS.Dispatch("bis what")
assert(has(msgs(), "Usage: /amisia bis [here | item <link> | exclude <link> | reset"), msgs())
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(has(help, "/amisia wish [<link> [high|medium|low] [note] | remove <link>] - Wishlist: add, change or remove an item"), help)
assert(has(help, "/amisia professions [profession|camp|favor]") and has(help, "/amisia map ") and has(help, "/amisia talents"), help)
assert(not german(help), help)

---------------------------------------------------------------------------
-- the gear window
---------------------------------------------------------------------------
NS.ToggleGearFrame()
local gw = shown(UIParent)
assert(has(gw, "Weights: Speedrun") and has(gw, "My character") and has(gw, "List"), gw)
NS.ToggleGearFrame()

---------------------------------------------------------------------------
-- the dungeon planner's texts, drop rates
---------------------------------------------------------------------------
local Dn = NS.Dungeons
assert(Dn.FitText({ fit = "fit" }) == "fits" and Dn.FitText({ fit = "high" }) == "too high")
assert(Dn.FitText({ fit = "later", from = "2026-12-09" }) == "from Dec 9", Dn.FitText({ fit = "later", from = "2026-12-09" }))
assert(Dn.QuestLevelText({ level = 20, minLevel = 15 }) == "20 (from 15)")
assert(Dn.QuestStartText({ start = "I" }) == "in the dungeon")
assert(Dn.ChainText({}, nil) == "At your level no dungeon has upgrades left for you.")
STUB.messages = {}
NS.Dispatch("dungeon what")
assert(has(msgs(), "Usage: /amisia dungeon [next|chain|quests <dungeon>]"), msgs())
assert(NS.DropRateText(999, 601) == "Chance unknown", NS.DropRateText(999, 601))
assert(NS.DropRateText(999, 601, 0.25) == "Chance 25 %")
STUB.messages = {}
NS.Dispatch("drops")
assert(has(msgs(), "Drop data: 0 kills (0 own, 0 heard)") and has(msgs(), "Recording on, sharing on."), msgs())

---------------------------------------------------------------------------
-- professions: names, standings, trainers
---------------------------------------------------------------------------
local Pr = NS.Prof
assert(Pr.NAMES.blacksmithing == "Blacksmithing" and Pr.NAMES.firstaid == "First Aid")
assert(Pr.STANDING[8] == "Exalted" and Pr.STANDING[5] == "Friendly" and Pr.TIERS[3] == "Trainer (Expert)")
assert(Pr.FACTION_NAME.A == "Alliance")

---------------------------------------------------------------------------
-- the quests page
---------------------------------------------------------------------------
STUB.class, STUB.level, STUB.faction = "WARRIOR", 12, "Alliance"
_G.UnitRace = function() return "Human", "Human", 1 end
STUB.maps[1429] = { name = "Elwynn Forest", mapType = 3 }
STUB.maps[425] = { name = "Northshire", parent = 1429, mapType = 5 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.place.map = 425
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
NS.QUEST_DATA = { built = "2026-10-06", source = "test", count = 3,
    Z = { [1429] = "Elwynn Forest" },
    N = { [197] = "Marshal McBride;425:4810:4180" },
    Q = {
        [7] = "425;Kobold Camp Cleanup;0;A;0;0;0;197;;O;;;;",
        [15] = "425;Investigate Echo Ridge;0;A;0;0;0;197;;O;7;;;",
        [100] = "1436;Westfall Stew;14;A;0;0;0;197;;O;;;;",
    },
}
NS.Quests._reset()
NS.Dispatch("quests")
assert(NS.CurrentPage() == "quests")
local q = assert(NS.QuestPageFrame())
assert(q.show.open.label:GetText() == "Available" and q.show.active.label:GetText() == "In log" and q.mine.label:GetText() == "Only mine")
assert(plain(q.counts:GetText()) == "0 in log · 1 available · 2 locked · 0 done", plain(q.counts:GetText()))
assert(has(q.data:GetText(), "Quest data of Oct 6, 2026 · 3 quests"), q.data:GetText())
assert(q.head.reward:GetText() == "Reward" and q.head.go:GetText() == "Go")
assert(not german(shown(q)), shown(q))

-- nothing the area asked for lacks its English
local miss = {}
for k in pairs(NS.MissingTranslations()) do miss[#miss + 1] = k end
assert(#miss == 0, "missing English: " .. table.concat(miss, " | "))
