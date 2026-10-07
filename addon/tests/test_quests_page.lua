-- The quests page (Pages/Quests.lua): the head (zone pick, search), the status and filter chips,
-- zone rows that fold, quest rows with level, status or reason, chain progress and the best
-- reward's mark, a click opening the chain and the rewards, the waypoint button, the empty texts,
-- the layout at 602 x 478 and the command.
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 12, "Alliance"
_G.UnitRace = function() return "Mensch", "Human", 1 end
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.maps[425] = { name = "Nordhain", parent = 1429, mapType = 5 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.place.map = 425
STUB.instance = { name = "Wald von Elwynn", type = "none", id = 0 }

NS.QUEST_DATA = { built = "2026-10-06", source = "test", count = 6,
    Z = { [1429] = "Elwynn Forest" },
    N = { [197] = "Marshal McBride;425:4810:4180", [234] = "Gryan Stoutmantle;1436:5630:4760" },
    Q = {
        [7] = "425;Kobold Camp Cleanup;0;A;0;0;0;197;;O;;;;",
        [15] = "425;Investigate Echo Ridge;0;A;0;0;0;197;;O;7;;;",
        [21] = "425;Skirmish at Echo Ridge;5;A;0;0;0;197;;O;15;;5001;",
        [100] = "1436;Westfall Stew;14;A;0;0;0;234;;O;;;;",
        [200] = "1436;Horde Thing;1;H;0;0;0;234;;O;;;;",
        [600] = "1436;Found a Note;8;;0;0;0;0;;X;;;;C",
    },
}
NS.Quests._reset()
NS.GEAR = { game = "forever", cap = 60, built = "test-quests-page", I = {}, Z = {}, S = {} }
NS.Gear._reset()
local link = STUB.item(5001, "Echohelm", 2)
STUB.items[5001].equipLoc, STUB.items[5001].classID, STUB.items[5001].subclassID = "INVTYPE_HEAD", 4, 3
STUB.items[5001].minLevel, STUB.items[5001].stats = 5, { ITEM_MOD_STRENGTH_SHORT = 20 }
assert(link)

NS.Dispatch("quests")
assert(NS.CurrentPage() == "quests")
local f = assert(NS.QuestPageFrame())
local function texts()
    local out = {}
    for _, r in ipairs(f.list.rows) do
        if r:IsShown() then out[#out + 1] = plain(r.title:GetText()) end
    end
    return out
end
local function rowOf(part)
    for _, r in ipairs(f.list.rows) do
        if r:IsShown() and has(plain(r.title:GetText()), part) then return r end
    end
end

-- defaults: open and in the log, for me; zones by name
assert(f.show.open.on and f.show.active.on and not f.show.locked.on and not f.show.done.on and f.mine.on)
local t = texts()
assert(t[1] == "- Wald von Elwynn (1)" and t[2] == "  Kobold Camp Cleanup [0/3]", t[1] .. " / " .. tostring(t[2]))
assert(t[3] == "- Westfall (1)" and t[4] == "  Found a Note", table.concat(t, " | "))
assert(plain(f.counts:GetText()) == "0 im Log · 2 annehmbar · 3 gesperrt · 0 erledigt", plain(f.counts:GetText()))
assert(plain(rowOf("Kobold").status:GetText()) == "annehmbar" and rowOf("Kobold").go:IsShown())
assert(not rowOf("Found a Note").go:IsShown(), "an item start has no waypoint")
assert(has(plain(f.data:GetText()), "06.10.2026") and has(plain(f.data:GetText()), "6 Quests"))

-- the locked chip: the reason in the row
f.show.locked:Click()
assert(f.show.locked.on and AmisiaDB.settings.quests.show.locked)
assert(plain(rowOf("Investigate").status:GetText()) == "Vorquest fehlt: Kobold Camp Cleanup")
assert(plain(rowOf("Westfall Stew").level:GetText()) == "14" and plain(rowOf("Westfall Stew").status:GetText()) == "ab Level 14")
assert(plain(rowOf("Skirmish").reward:GetText()) == "neu", "the best reward's mark: " .. plain(rowOf("Skirmish").reward:GetText()))
assert(not rowOf("Horde Thing"), "only for me")
f.mine:Click()
assert(plain(rowOf("Horde Thing").status:GetText()) == "nur Horde")
f.mine:Click()

-- a click opens the chain and the rewards below the quest
rowOf("Skirmish"):Click()
assert(AmisiaDB.settings.quests.expanded[21])
t = texts()
local at
for i, x in ipairs(t) do if has(x, "Skirmish at Echo Ridge") then at = i break end end
assert(t[at + 1] == "      1. Kobold Camp Cleanup" and t[at + 3] == "      3. Skirmish at Echo Ridge", tostring(t[at + 1]))
assert(has(t[at + 4], "Echohelm"), tostring(t[at + 4]))
rowOf("Skirmish"):Click()
assert(not AmisiaDB.settings.quests.expanded[21])

-- the waypoint button
rowOf("Kobold").go:Click()
assert(NS.MapTarget() and NS.MapTarget().label == "Questgeber Marshal McBride")
NS.MapClearTarget()

-- a zone row folds
rowOf("Wald von Elwynn"):Click()
assert(AmisiaDB.settings.quests.collapsed[1429] and plain(texts()[1]) == "+ Wald von Elwynn (3)" and not rowOf("Kobold"))
rowOf("Wald von Elwynn"):Click()
assert(rowOf("Kobold"))

-- the zone pick: here (Northshire counts as Elwynn), then one zone
f.zone.onPick("here")
f.zone:SetValue("here")
assert(not rowOf("Westfall") and rowOf("Kobold") and has(plain(f.zone.label:GetText()), "Hier: Wald von Elwynn"), plain(f.zone.label:GetText()))
f.zone.onPick(1436)
assert(rowOf("Westfall") and not rowOf("Kobold"))
f.zone.onPick("all")

-- search
NS.Dispatch("quests echo")
t = texts()
assert(#t == 3 and has(t[2], "Investigate") and has(t[3], "Skirmish"), table.concat(t, " | "))
assert(f.search:GetText() == "echo")
NS.Dispatch("quests nichtsdergleichen")
assert(#texts() == 0 and f.empty:IsShown() and has(f.empty:GetText(), "Keine Quests"))
NS.Dispatch("quests")
assert(#texts() > 0 and not f.empty:IsShown())

-- the layout
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
local r1 = f.list.rows[2]
L.row("head", f.zone, f.search)
L.row("chips", f.show.open, f.show.active, f.show.locked, f.show.done, f.chains, f.upgrades, f.mine)
L.row("columns", f.head.title, f.head.level, f.head.status, f.head.reward, f.head.go)
L.row("row", r1.title, r1.level, r1.status, r1.reward, r1.go)
L.row("list", f.list, f.list.bar)
L.inside("list bar", f.list.bar)
L.column("page", f.zone, f.show.open, f.counts, f.head.title, f.list, f.hint, f.data)
for _, fs in ipairs({ f.counts, f.hint, f.data, f.head.reward, f.head.go }) do L.fits(fs) end

-- the switch takes the page away
NS.Set("quests.enabled", false)
assert(NS.CurrentPage() ~= "quests", "the page closes")
NS.Set("quests.enabled", true)
print("quests page: rows, chips, chain, waypoint, zones, search, layout")
