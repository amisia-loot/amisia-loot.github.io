-- The upgrade line on item tooltips (Bis.lua): one shared, protected hook for every Amisia line;
-- one line per tooltip build; "Upgrade für dich: +N (Slot)", "Option N für Slot", "angelegt,
-- Option 1", "Kein Upgrade" only with its switch, the weapon switch, the wish suffix; nothing for
-- items that are no gear, that the class cannot wear or that have no stats yet (then requested);
-- the explanation on Shift; an error never breaks the tooltip; the switch; cached per link, and the
-- targets are never computed inside a hover.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.class, STUB.level = "WARRIOR", 70

assert(#STUB.tdp == 1 and STUB.tdp[1].kind == Enum.TooltipDataType.Item, "one shared item tooltip hook: " .. #STUB.tdp)

-- a tooltip that records its lines and must never be rebuilt
local tip = CreateFrame("GameTooltip", "TestTooltip")
local lines = {}
tip.AddLine = function(_, t, r, g, b) lines[#lines + 1] = { t = t, r = r, g = g, b = b } end
tip.SetText = function() error("the tooltip was rebuilt (SetText)") end
tip.ClearLines = function() error("the tooltip was cleared (ClearLines)") end
tip.Show = function() error("the tooltip was shown again (Show)") end
-- one build: cleared, then the item set; returns the lines added
local function show(link, again)
    if not again then
        wipe(lines)
        if tip.scripts.OnTooltipCleared then tip.scripts.OnTooltipCleared(tip) end
    end
    tip.shownLink = link
    for _, h in ipairs(STUB.tdp) do h.fn(tip) end
    return lines
end
local function texts()
    local out = {}
    for i, l in ipairs(lines) do out[i] = l.t end
    return table.concat(out, " / ")
end

-- a small TBC data set; the client describes every item
local LINKS = {}
local function gear(id, name, loc, stats, sources, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel = stats, 70
    if sources then
        NS.GEAR.I[id] = { "", 0, 0, 0, 0, 0, 0, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
NS.GEAR = { game = "tbc", cap = 70, built = "test-tip", I = {}, Z = {},
    S = { { "X", "Karazhan", "Prinz Malchezaar", 532, 3457, 1, 0 }, { "X", "Gruul's Lair", "Gruul", 565, 3923, 1, 0 } } }
Gear._reset()
gear(301, "Helm A", "HEAD", str(40), { 1 })
gear(302, "Helm B", "HEAD", str(30), { 1 })
gear(303, "Helm C", "HEAD", str(20), { 2 })
gear(312, "Helm D", "HEAD", str(10), { 2 })
gear(304, "Brust", "CHEST", { ITEM_MOD_STRENGTH_SHORT = 50, ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 10,
    ITEM_MOD_CRIT_RATING_SHORT = 22, ITEM_MOD_HIT_RATING_SHORT = 15, ITEM_MOD_ATTACK_POWER_SHORT = 20 }, { 1 })
gear(306, "Zauberstab", "RANGEDRIGHT", { ITEM_MOD_INTELLECT_SHORT = 10 }, { 2 }, { classID = 2, sub = 19 })
gear(310, "Alte Zweihand", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 50 }, nil, { classID = 2, sub = 1 })
gear(311, "Axt", "WEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 80, ITEM_MOD_STRENGTH_SHORT = 20 }, { 1 }, { classID = 2, sub = 0 })
STUB.items[307] = { name = "Erz", quality = 1, link = STUB.link(307, "Erz", 1), equipLoc = "", classID = 7 }
LINKS[307] = STUB.items[307].link

-- the targets are never computed inside a hover: only deferred, after it
local best = 0
local realBest = Gear.Best
Gear.Best = function(...) best = best + 1; return realBest(...) end

---------------------------------------------------------------------------
-- the upgrade line
---------------------------------------------------------------------------
show(LINKS[301])
assert(#lines == 1 and lines[1].t == "Upgrade für dich: +80 (Kopf)", "the upgrade: " .. texts())
assert(lines[1].g > 0.7 and lines[1].r < 0.5, "green")
-- handed to the hook twice in one build: still one line
show(LINKS[301], true)
assert(#lines == 1, "one line per tooltip build: " .. texts())
-- the next build gets it again
show(LINKS[301])
assert(#lines == 1, "again after the tooltip was cleared")
assert(best == 0, "no targets computed inside a hover: " .. best)

---------------------------------------------------------------------------
-- options of the targets, worn items, "Kein Upgrade" with its switch
---------------------------------------------------------------------------
STUB.worn[1] = LINKS[301]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1)
show(LINKS[302])
assert(#lines == 0, "the targets are not there yet: " .. texts())
assert(best == 0, "and are not computed in the hover")
STUB.tick(0)
assert(best == 1, "computed once after the hover: " .. best)
show(LINKS[302])
assert(#lines == 1 and lines[1].t == "Option 2 für Kopf", "option 2: " .. texts())
assert(lines[1].r < 0.7 and lines[1].g < 0.7, "grey")
show(LINKS[301])
assert(lines[1] and lines[1].t == "angelegt, Option 1 für Kopf", "worn: " .. texts())
show(LINKS[303])
assert(lines[1] and lines[1].t == "Option 3 für Kopf", texts())
show(LINKS[312])
assert(#lines == 0, "no option, no upgrade: nothing by default: " .. texts())
assert(NS.Set("bis.tooltipNone", true))
show(LINKS[312])
assert(lines[1] and lines[1].t == "Kein Upgrade für dich (-60)", "with the switch: " .. texts())
NS.Reset("bis.tooltipNone")
STUB.tick(2)
assert(best == 2, "a setting changes the targets: computed again, once, a little later: " .. best)

---------------------------------------------------------------------------
-- a wish, and the explanation on Shift
---------------------------------------------------------------------------
assert(NS.WishAdd(304))
show(LINKS[304])
assert(#lines == 1 and has(lines[1].t, "Upgrade für dich: +") and has(lines[1].t, " (Brust) · auf deiner Wunschliste"), texts())
STUB.shift = true
show(LINKS[304])
assert(#lines == 5, "the line and the four biggest parts: " .. texts())
assert(has(lines[2].t, "50 Stärke x 2") and has(lines[2].t, "= 100"), "the biggest part first: " .. tostring(lines[2].t))
for i = 2, 5 do assert(lines[i].r < 0.7 and not has(lines[i].t, "Waffen/Furor"), "grey parts, no head line: " .. lines[i].t) end
STUB.shift = false
show(LINKS[304])
assert(#lines == 1, "without Shift the line alone")

---------------------------------------------------------------------------
-- no line: no gear, a class that cannot wear it, no stats yet (then requested), weapon switch
---------------------------------------------------------------------------
show(LINKS[307])
assert(#lines == 0, "no gear: " .. texts())
show(LINKS[306])
assert(#lines == 0, "a wand for a warrior: " .. texts())
local unknown = STUB.link(999, "Unbekannt", 4)
show(unknown)
assert(#lines == 0, "no stats yet: " .. texts())
Gear._tick()
local asked = false
for _, id in ipairs(STUB.requested) do if id == 999 then asked = true end end
assert(asked, "the item is requested from the client")
STUB.worn[16] = LINKS[310]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 16)
show(LINKS[311])
assert(#lines == 1 and lines[1].t == "Waffenwechsel für dich", "a one-hander against a worn two-hander: " .. texts())

---------------------------------------------------------------------------
-- cached per link until something changes
---------------------------------------------------------------------------
show(LINKS[302]); STUB.tick(2)
local calls = 0
local realGain = NS.BisGain
NS.BisGain = function(...) calls = calls + 1; return realGain(...) end
show(LINKS[302]); show(LINKS[302]); show(LINKS[302])
assert(calls <= 1 and lines[1] and lines[1].t == "Option 2 für Kopf", "one evaluation for three hovers: " .. calls)
local before = calls
NS.Fire("BIS_CHANGED")
show(LINKS[302])
assert(calls == before + 1, "evaluated again after a change")
before = calls
show(LINKS[302])
assert(calls == before, "and cached again")
NS.BisGain = realGain

---------------------------------------------------------------------------
-- an error never breaks the tooltip or the other lines
---------------------------------------------------------------------------
NS.SetSoftRes("Chorf 301")
local errors = {}
local realHandler = geterrorhandler
_G.geterrorhandler = function() return function(e) errors[#errors + 1] = tostring(e) end end
NS.BisGain = function() error("kaputt") end
NS.Fire("BIS_CHANGED")
show(LINKS[301])
assert(#errors == 1 and has(errors[1], "kaputt"), "the error goes to the error handler: " .. #errors)
assert(#lines == 1 and has(lines[1].t, "Reserviert: Chorf"), "the reserve line stays: " .. texts())
_G.geterrorhandler = realHandler
NS.BisGain = realGain
NS.Fire("BIS_CHANGED")
show(LINKS[301]); STUB.tick(2)
show(LINKS[301])
assert(#lines == 2 and has(lines[1].t, "Reserviert") and lines[2].t == "angelegt, Option 1 für Kopf", "both lines: " .. texts())

-- the hidden scan tooltip gets no lines (it is filled inside a hover on clients without GetItemStats)
local scan = _G.AmisiaScanTip or CreateFrame("GameTooltip", "AmisiaScanTip")
local scanLines = 0
local realAdd = scan.AddLine
scan.AddLine = function() scanLines = scanLines + 1 end
scan.shownLink = LINKS[301]
for _, h in ipairs(STUB.tdp) do h.fn(scan) end
assert(scanLines == 0, "nothing on the scan tooltip")
scan.AddLine = realAdd

-- the switch
assert(NS.Set("bis.tooltip", false))
show(LINKS[302])
assert(#lines == 0, "switched off: " .. texts())
NS.Reset("bis.tooltip")
-- without a data set: nothing
local data = NS.GEAR
NS.GEAR = nil
NS.Fire("BIS_CHANGED")
show(LINKS[304])
assert(#lines == 0, "no data, no line")
NS.GEAR = data
