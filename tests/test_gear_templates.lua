-- The planner's templates (F-239, Gear/Templates.lua): the menu "Vorlagen" (Leere Plätze füllen, Plan erstellen
-- with the own level, 20 to 55 and Pre-Raid, Bekannte Sets of the simulation, Liste einfügen); a plan per level is the
-- best reachable item per row up to it, Pre-Raid leaves the raids out; replacing own picks asks first, filling the
-- empty rows keeps them; a set becomes the own picks; a pasted list: links, ids, item=, names, two rings, a
-- two-hander keeps the shield hand free, the unknown and the refused named in the preview; the caps.
local Gear = NS.Gear
local PL = NS.Theme.PLANNER
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
-- the lines a tooltip got (the stub keeps none)
local function tipOf(fn)
    local out, keep = {}, GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
    fn()
    GameTooltip.AddLine = keep
    return table.concat(out, "\n")
end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 58
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-planner", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },   -- 2
    { "C", "leatherworking", 300 },                                -- 3
    { "Q", "Endlich frei", 30, 25, "", 1429, 0, 0 },               -- 4
} }
STUB.areas[2717], STUB.areas[2017] = "Geschmolzener Kern", "Stratholme"
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, strength, level, sources, quality)
    LINKS[id] = STUB.item(id, name, quality or 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 4
    it.stats, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = strength }, level
    if sources then
        NS.GEAR.I[id] = { loc, 4, 4, level, quality or 4, 1, 60, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
end
gear(401, "Helm des Kerns", "HEAD", 40, 60, { 1 })
gear(402, "Helm der Pest", "HEAD", 30, 58, { 2 }, 3)
gear(403, "Brust der Pest", "CHEST", 35, 58, { 2 })
gear(404, "Teufelssaurier-Stulpen", "HAND", 20, 53, { 3 })
gear(405, "Teufelssaurier-Gamaschen", "LEGS", 25, 53, { 3 })
gear(406, "Anfängerhelm", "HEAD", 5, 10, { 2 }, 2)
gear(407, "Armschiene", "WRIST", 5, 40, { 2 })
gear(410, "Alter Helm", "HEAD", 2, 1)
gear(408, "Queststiefel", "FEET", 10, 25, { 4 })
NS.BIS = { SET = {
    [1] = { name = "Pestset", items = { 402, 403 }, b = { { 2, "STRENGTH=10" } } },
    [2] = { name = "Teufelssaurier", items = { 404, 405 }, b = { { 2, "" } } },
} }
NS.Catalog._reset()
-- the enchantments: intellect on the chest now, strength for chest and wrist
NS.ENCHANT = { build = "test", built = "test", E = {
    [24] = "INTELLECT=2|0|0|Intellect +2", [41] = "STRENGTH=5|0|0|Strength +5", [60] = "STRENGTH=9|0|0|Strength +9",
}, S = { "r:100:24:333:1:4:CHEST,ROBE:", "r:101:41:333:150:4:CHEST,ROBE:", "r:103:60:333:150:4:WRIST:" } }
STUB.worn[1] = LINKS[410]
STUB.worn[5] = "|cffa335ee|Hitem:403:24::::::::58:::::|h[Brust der Pest]|h|r"
STUB.worn[9] = LINKS[407]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
assert(Gear.Available())
NS.BisSetSpec("dps")
local TP = NS.GearTemplates
NS.GEAR_WEIGHTS = NS.GEAR_WEIGHTS or {}
NS.GEAR_WEIGHTS.SETS = { WARRIOR = { { name = "Waffen Pre-BiS", spec = "dps", items = { HEAD = 402, CHEST = 403, LEGS = 405 } } } }
NS.ShowPlanner("suggest")
local f = NS.PageFrame("planner")
local ask = function() return _G.AmisiaConfirmFrame end
local said = {}
local msg = NS.msg
NS.msg = function(t) said[#said + 1] = plain(t) end

-- the menu
f.tpl:Click()
assert(AmisiaMenu:IsShown(), "the menu")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = plain(b.label:GetText()) end end
local all = table.concat(labels, "|")
assert(all == "Leere Plätze füllen|Plan erstellen|Aktuelle Stufe (58)|Stufe 20|Stufe 30|Stufe 40|Stufe 50|Stufe 55|Pre-Raid (BiS)"
    .. "|Bekannte Sets|WoWSims Forever: Waffen Pre-BiS|Liste einfügen ...|Zurücksetzen", all)
AmisiaMenu:Hide()

-- a plan per level: up to 40 the starter helmet, Pre-Raid the Stratholme helmet, not the raid's
local map, lv = TP.Plan(40)
assert(lv == 40 and map.HEAD == 406 and map.FEET == 408 and map.CHEST == nil, "level 40: " .. tostring(map.HEAD))
map = TP.Plan(60, true)
assert(map.HEAD == 402 and map.CHEST == 403, "pre-raid without the raid: " .. tostring(map.HEAD))
assert(TP.Plan(60).HEAD == 401, "with raids the Kern's helmet")

-- applying: no own pick yet, so no question
TP.Apply((TP.Plan(40)), true, "Stufe 40")
assert(not (ask() and ask():IsShown()), "nothing to replace, no question")
assert(NS.BisPick("HEAD") == 406 and NS.BisPick("FEET") == 408, "the plan as own picks")
assert(has(said[#said], "Stufe 40") and has(said[#said], "Plätze gesetzt"), said[#said])
-- Pre-Raid now asks first; "no" leaves everything
TP.Apply((TP.Plan(60, true)), true, "Pre-Raid (BiS)")
assert(ask():IsShown() and NS.BisPick("HEAD") == 406, "a question first")
ask():Hide()
assert(NS.BisPick("HEAD") == 406)
TP.Apply((TP.Plan(60, true)), true, "Pre-Raid (BiS)")
ask().ok:Click()
assert(NS.BisPick("HEAD") == 402 and NS.BisPick("CHEST") == 403, "replaced")
-- the empty rows: the own picks stay
NS.BisSetPick("HEAD", 406)
NS.BisSetPick("CHEST", nil)
TP.Apply(TP.Fill(), false, "Leere Plätze füllen")
assert(not ask():IsShown(), "filling asks nothing")
assert(NS.BisPick("HEAD") == 406 and NS.BisPick("CHEST") == 403, "the own pick kept, the empty chest filled")

-- a known set
for _, sl in ipairs(Gear.SLOTS) do NS.BisSetPick(sl.key, nil) end
TP.Apply(TP.Sets()[1].items, true, "WoWSims Forever: Waffen Pre-BiS")
assert(NS.BisPick("HEAD") == 402 and NS.BisPick("CHEST") == 403 and NS.BisPick("LEGS") == 405 and NS.BisPick("FEET") == nil, "the set")

-- a pasted list
STUB.item(501, "Ring der Probe", 3); STUB.items[501].equipLoc, STUB.items[501].classID, STUB.items[501].subclassID = "INVTYPE_FINGER", 4, 0
STUB.item(502, "Ring des Zweifels", 3); STUB.items[502].equipLoc, STUB.items[502].classID, STUB.items[502].subclassID = "INVTYPE_FINGER", 4, 0
STUB.item(503, "Dritter Ring", 3); STUB.items[503].equipLoc, STUB.items[503].classID, STUB.items[503].subclassID = "INVTYPE_FINGER", 4, 0
STUB.item(504, "Großes Schwert", 4); STUB.items[504].equipLoc, STUB.items[504].classID, STUB.items[504].subclassID = "INVTYPE_2HWEAPON", 2, 8
STUB.item(505, "Schild der Probe", 3); STUB.items[505].equipLoc, STUB.items[505].classID, STUB.items[505].subclassID = "INVTYPE_SHIELD", 4, 6
local text = table.concat({
    "Kopf: " .. LINKS[402],
    "Brust - https://www.wowhead.com/classic/item=403/brust-der-pest",
    "Hände: 404",
    "Ring 1: 501", "Ring 2: 502", "Ring 3: 503",
    "Zweihand: 504", "Schildhand: 505",
    "* Teufelssaurier-Gamaschen - Lederverarbeitung",
    "Irgendwas ohne Sinn",
}, "\n")
local res = TP.Parse(text)
assert(res.map.HEAD == 402 and res.map.CHEST == 403 and res.map.HANDS == 404, "link, address, id")
assert(res.map.FINGER1 == 501 and res.map.FINGER2 == 502, "two rings")
assert(res.map.MAINHAND == 504 and res.map.OFFHAND == nil, "the two-hander, the shield hand free")
assert(res.map.LEGS == 405, "a name: " .. tostring(res.map.LEGS))
assert(#res.unknown == 1 and res.unknown[1] == "Irgendwas ohne Sinn", table.concat(res.unknown, "/"))
local why = {}
for _, r in ipairs(res.refused) do why[#why + 1] = r.id .. "=" .. tostring(r.why) end
assert(#res.refused == 2, table.concat(why, " / "))
assert(res.n == 7, "seven taken: " .. res.n)
-- the same ring twice: once; the weapon plan: with "Waffe und Schild" no two-hander
res = TP.Parse("501\n501")
assert(res.map.FINGER1 == 501 and res.map.FINGER2 == nil and res.refused[1].why == "Steht schon im anderen Platz.", "a ring once")
NS.BisSetPlan("SHIELD")
res = TP.Parse("504\n505")
assert(res.map.MAINHAND == nil and res.map.OFFHAND == 505 and res.refused[1].why == "Passt nicht zum Waffenplan", tostring(res.refused[1] and res.refused[1].why))
NS.BisSetPlan("auto")
-- only what the character can wear now: plate at 20 for a warrior goes unused, so it is not set
STUB.level = 20
res = TP.Parse(LINKS[402])
assert(res.n == 0 and res.refused[1].why == "Das kann dein Charakter nicht tragen.", tostring(res.refused[1] and res.refused[1].why))
STUB.level = 58
-- nothing fits: the own picks stay, the chat says so
NS.BisSetPick("HEAD", 402)
local before = #said
TP.Apply({ HEAD = 501 }, true, "Kaputt")
ask().ok:Click()
assert(NS.BisPick("HEAD") == 402 and has(said[#said], "nichts gesetzt") and has(said[#said], "Passt nicht: Kopf"), said[#said])
-- nothing empty to fill
for _, sl in ipairs(Gear.SLOTS) do NS.BisSetPick(sl.key, TP.Fill()[sl.key] or NS.BisPick(sl.key)) end
TP.Apply(TP.Fill(), false, "Leere Plätze füllen")
assert(#said > before and has(said[#said], "Kein Platz ohne eigene Wahl"), said[#said])
for _, sl in ipairs(Gear.SLOTS) do NS.BisSetPick(sl.key, nil) end
-- the caps
local long = {}
for i = 1, 300 do long[i] = "x" end
assert(TP.Parse(table.concat(long, "\n")).cut, "more than 200 lines: cut")
assert(#TP.Parse(string.rep("y", 9000)).unknown == 1, "8000 characters at most")

-- the window: the preview, then Übernehmen replaces after the question
NS.BisSetPick("HEAD", 406)
f.tpl:Click()
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() and plain(b.label:GetText()) == "Liste einfügen ..." then b:Click() break end end
local P = TP._paste()
assert(P and P:IsShown() and not P.apply:IsEnabled(), "the window, nothing to apply yet")
P.area.box:SetText(text)
TP._preview()
local pv = plain(P.preview:GetText())
assert(has(pv, "7 erkannt, 3 nicht erkannt") and has(pv, "Kopf: Helm der Pest") and has(pv, "unbekannt: Irgendwas ohne Sinn"), pv)
assert(P.apply:IsEnabled())
P.apply:Click()
assert(not P:IsShown() and ask():IsShown(), "the question before replacing")
ask().ok:Click()
assert(NS.BisPick("FINGER2") == 502 and NS.BisPick("MAINHAND") == 504 and NS.BisPick("CHEST") == 403, "the list as own picks")
NS.msg = msg
print("templates ok")
