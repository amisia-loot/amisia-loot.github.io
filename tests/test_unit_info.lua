-- The player tooltip's lines (F-169, UI/UnitInfo.lua, Core/Inspect.lua): the own character with the
-- client's item level; the gear score's formula on a fixed set with a two-hander and an empty slot;
-- another player: no value -> one inspect request, the answer -> the line, a cache hit without a new
-- request, the expiry; not in combat, not with the inspect window open; items the client lacks at
-- first (provisional, then the full value); the settings off; the profession icons of an own
-- character, a twink, a guild member (note and recipe exchange), none for a stranger; NPCs nothing;
-- no line twice after a refresh; German and English (run.py --locale enUS).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local UI, In = NS.UnitInfo, NS.Inspect
local Cr = NS.Crafters
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
local EN = GetLocale() == "enUS"
local WORD = EN and "Gear score " or "Gearscore "

STUB.player = "Vuloo"
-- units: [token] = { name, surname, guid, npc }
STUB.units = {
    player = { "Vuloo", nil, "Player-1-1" },
}
_G.UnitName = function(u) local e = STUB.units[u]; if e then return e[1], e[2] end end
_G.UnitGUID = function(u) local e = STUB.units[u]; return e and e[3] end
_G.UnitExists = function(u) return STUB.units[u] ~= nil end
_G.UnitIsPlayer = function(u) local e = STUB.units[u]; return e ~= nil and not e[4] end
_G.UnitIsUnit = function(a, b)
    local x, y = STUB.units[a], STUB.units[b]
    return x ~= nil and y ~= nil and x[3] == y[3]
end

-- items: id -> { name, link, quality, ilvl, equipLoc }; gear by GUID: [slot] = id
local function item(id, ilvl, q, loc)
    STUB.items[id] = { name = "Item " .. id, link = "|cff0070dd|Hitem:" .. id .. "::::::::|h[Item " .. id .. "]|h|r",
                       quality = q or 3, ilvl = ilvl, equipLoc = loc or "INVTYPE_HEAD" }
    return id
end
local SET = {   -- the waist and the off hand empty, a two-hander in the main hand
    [1] = item(101, 40), [2] = item(102, 36), [3] = item(103, 40), [5] = item(105, 40), [7] = item(107, 40),
    [8] = item(108, 40), [9] = item(109, 36), [10] = item(110, 40), [11] = item(111, 36), [12] = item(112, 36),
    [13] = item(113, 36), [14] = item(114, 36), [15] = item(115, 36), [16] = item(116, 44, 4, "INVTYPE_2HWEAPON"),
    [18] = item(118, 32),
}
local gear = { ["Player-1-1"] = SET, ["Player-1-50"] = SET }
local hidden = {}   -- id -> true: the link stays nil (the client lacks the item), the id is there
_G.GetInventoryItemID = function(unit, slot)
    local g = gear[UnitGUID(unit)]
    return g and g[slot]
end
_G.GetInventoryItemLink = function(unit, slot)
    local id = GetInventoryItemID(unit, slot)
    if not id or hidden[id] then return nil end
    return STUB.items[id].link
end
_G.GetAverageItemLevel = function() return 35.2, 33.7, 33.7 end

-- the client's tooltip: lines, the unit it shows, SetUnit runs the unit post calls as the client does
local tip = GameTooltip
tip.lines, tip.shownUnit, tip.shown = {}, nil, false
tip.AddLine = function(self, text, r, g, b) self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b } end
tip.ClearLines = function(self) self.lines = {} end
tip.NumLines = function(self) return #self.lines end
tip.GetUnit = function(self)
    local e = STUB.units[self.shownUnit]
    return e and e[1], self.shownUnit
end
tip.IsShown = function(self) return self.shown end
tip.Hide = function(self) self.shown, self.shownUnit = false, nil end
tip.SetUnit = function(self, unit)
    self:ClearLines()
    self.shownUnit, self.shown = unit, true
    self:AddLine(UnitName(unit))
    for _, e in ipairs(STUB.tdp) do if e.kind == Enum.TooltipDataType.Unit then e.fn(self) end end
end
local function hover(unit)
    tip:SetUnit(unit)
    local out = {}
    for _, l in ipairs(tip.lines) do out[#out + 1] = l.text end
    return table.concat(out, "\n")
end
local function count(text, part)
    local n, i = 0, 1
    while true do
        local a, b = text:find(part, i, true)
        if not a then return n end
        n, i = n + 1, b + 1
    end
end

local inspects, cleared = {}, 0
_G.NotifyInspect = function(u) inspects[#inspects + 1] = u end
_G.ClearInspectPlayer = function() cleared = cleared + 1 end
_G.CanInspect = function() return true end
_G.UnitAffectingCombat = function() return false end

---------------------------------------------------------------------------
-- the formula
---------------------------------------------------------------------------
local items = {}
for slot, id in pairs(SET) do
    local it = STUB.items[id]
    items[slot] = { ilvl = it.ilvl, q = it.quality, two = it.equipLoc == "INVTYPE_2HWEAPON" }
end
local e = UI.Score(items)
-- 40 + 36*.5625 + 40*.75 + 40 + 40 + 40*.75 + 36*.5625 + 40*.75 + 2*36*.5625 + 2*36*.75 + 36*.5625 + 44*2 + 32*.3164
assert(e.gs == 463, "gear score " .. tostring(e.gs))
-- (12 items + the two-hander twice + 32) / 17 slots, the empty waist 0
assert(e.ilvl == 36 and e.n == 15, ("item level %s, %s items"):format(tostring(e.ilvl), tostring(e.n)))
assert(e.q == 3, "the average quality: rare")
assert(UI.Score({}) == nil, "nothing worn: no value")
local one = UI.Score({ [16] = { ilvl = 50, q = 2 } })
assert(one.gs == 50 and one.ilvl == 2, "a one-hander counts once: " .. one.gs .. " " .. one.ilvl)

---------------------------------------------------------------------------
-- the own character: at once, the client's item level
---------------------------------------------------------------------------
local own = hover("player")
assert(has(own, WORD) and has(own, "463") and has(own, "33"), own)
assert(not has(own, "36"), "the client's number, not the computed one: " .. own)
assert(has(own, "|cff0070dd463|r") and has(own, "|cffffffff33|r"), "score in the quality's colour, level white: " .. own)
local gl = tip.lines[#tip.lines]
assert(gl.r == 0.56 and gl.g == 0.53 and gl.b == 0.64, "the words grey")
assert(#inspects == 0, "the own character is never inspected")

---------------------------------------------------------------------------
-- another player: one request, the answer, the cache, the expiry
---------------------------------------------------------------------------
STUB.units.mouseover = { "Tuoppi", "Foreverpvp", "Player-1-50" }
local t = hover("mouseover")
assert(not has(t, WORD), "nothing while waiting: " .. t)
assert(#inspects == 1 and inspects[1] == "mouseover", "inspect requested")
hover("mouseover")
STUB.tick(0.5)
assert(#inspects == 1, "once: the answer is awaited")
STUB.fire("INSPECT_READY", "Player-1-99")
assert(not has(hover("mouseover"), WORD), "another character's answer")
STUB.fire("INSPECT_READY", "Player-1-50")
t = table.concat((function() local o = {} for _, l in ipairs(tip.lines) do o[#o + 1] = l.text end return o end)(), "\n")
assert(has(t, WORD .. "|cff0070dd463|r") and has(t, "|cffffffff36|r"), "the answer refreshes the tooltip: " .. t)
assert(count(t, WORD) == 1, "one line after the refresh: " .. t)
assert(cleared == 1, "the inspect cleared")
tip:Hide()
STUB.tick(60)
t = hover("mouseover")
assert(has(t, "463") and count(t, WORD) == 1 and #inspects == 1, "a cache hit without a request")
STUB.tick(UI.FRESH)
t = hover("mouseover")
assert(not has(t, WORD) and #inspects == 2, "too old: asked again")
STUB.fire("INSPECT_READY", "Player-1-50")
assert(count(hover("mouseover"), WORD) == 1, "the fresh value")

-- an NPC: nothing, never inspected
STUB.units.npc1 = { "Wache", nil, "Creature-0-1-1-1-3296-1", true }
assert(hover("npc1") == "Wache" and #inspects == 2, "NPC")

---------------------------------------------------------------------------
-- not in combat, not with the inspect window open, one request a second
---------------------------------------------------------------------------
STUB.tick(5)
gear["Player-1-51"] = SET
STUB.units.mouseover = { "Kovu", "Foreverpvp", "Player-1-51" }
_G.UnitAffectingCombat = function() return true end
hover("mouseover"); STUB.tick(2)
assert(#inspects == 2, "never in combat")
_G.UnitAffectingCombat = function() return false end
_G.InspectFrame = { IsShown = function() return true end }
hover("mouseover"); STUB.tick(2)
assert(#inspects == 2, "never while the inspect window is open")
_G.InspectFrame = nil
hover("mouseover")
assert(#inspects == 3 and inspects[3] == "mouseover", "then")
-- a second player right after: waits for the answer or the time out, then goes by itself while hovered
gear["Player-1-52"] = SET
STUB.units.mouseover = { "Beasty", "Foreverpvp", "Player-1-52" }
hover("mouseover")
assert(#inspects == 3, "one at a time")
STUB.tick(In.WAIT + 0.2)
assert(#inspects == 4, "after the time out, as long as he is under the mouse: " .. #inspects)
STUB.fire("INSPECT_READY", "Player-1-51")
assert(not UI.Cached("Player-1-51"), "a late answer of the timed-out request is dropped")
STUB.fire("INSPECT_READY", "Player-1-52")
assert(UI.Cached("Player-1-52"), "his answer")

---------------------------------------------------------------------------
-- items the client lacks at first: provisional, then the whole value
---------------------------------------------------------------------------
STUB.tick(2)
gear["Player-1-53"] = SET
hidden[101], hidden[116] = true, true
STUB.units.mouseover = { "Lanni", "Foreverpvp", "Player-1-53" }
local clearedBefore = cleared
hover("mouseover")
STUB.fire("INSPECT_READY", "Player-1-53")
local c = UI.Cached("Player-1-53")
assert(c and c.prov and c.gs == 463 - 40 - 88, "counted without the missing two, provisional: " .. tostring(c and c.gs))
assert(cleared == clearedBefore, "the inspect stays while items are missing")
hidden[101], hidden[116] = nil, nil
STUB.fire("GET_ITEM_INFO_RECEIVED", 101, true)
STUB.tick(0.4)
c = UI.Cached("Player-1-53")
assert(c and not c.prov and c.gs == 463, "the whole value once the client has them")
t = table.concat((function() local o = {} for _, l in ipairs(tip.lines) do o[#o + 1] = l.text end return o end)(), "\n")
assert(has(t, "463") and count(t, WORD) == 1, "the tooltip refreshed, one line: " .. t)
assert(cleared == clearedBefore + 1, "then cleared")

---------------------------------------------------------------------------
-- the settings
---------------------------------------------------------------------------
NS.Set("ui.unitGear", false)
assert(not has(hover("player"), WORD) and not has(hover("mouseover"), WORD), "gear line off")
NS.Set("ui.unitGear", true)
NS.Set("ui.unitInspect", false)
STUB.tick(5)
gear["Player-1-54"] = SET
STUB.units.mouseover = { "Mira", "Foreverpvp", "Player-1-54" }
local n0 = #inspects
assert(not has(hover("mouseover"), WORD) and #inspects == n0, "inspect off: nobody inspected")
assert(has(hover("player"), WORD), "inspect off: the own character still")
STUB.units.mouseover = { "Lanni", "Foreverpvp", "Player-1-53" }
assert(has(hover("mouseover"), WORD), "inspect off: a cached player still")
NS.Set("ui.unitInspect", true)

---------------------------------------------------------------------------
-- the profession icons
---------------------------------------------------------------------------
local D = NS.DropsToday()
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 60 },
    { name = "Anna Amboss", class = "WARRIOR", rank = 3, level = 58, note = "Kräuter 300 / Alchi" },
    { name = "Bert Bach", class = "MAGE", rank = 3, level = 60 },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
AmisiaDB.prof = { chars = {
    ["Vuloo"] = { [171] = { rank = 120, max = 150, day = D, known = { [2330] = true } },
                  [185] = { rank = 40, max = 75, day = D, known = { [1229737] = true } } },
    ["Twinky"] = { [356] = { rank = 10, max = 75, day = D, known = {} } },
} }
local ix = Cr._index(164)
AmisiaDB.crafters = { v = 1, src = {}, c = {
    ["Bert Bach"] = { via = "Bert Bach", self = true, seen = D, p = { [164] = { r = 225, m = 300, h = ix.hash,
        b = Cr._toBits(ix, { [2663] = true }) } } },
} }
Cr.Changed()
STUB.tick(11)
local ALCH, COOK = "Trade_Alchemy", "INV_Misc_Food_15"
t = hover("player")
local lines = tip.lines
assert(has(lines[2].text, ALCH) and has(lines[2].text, COOK) and lines[2].text:find(ALCH, 1, true) < lines[2].text:find(COOK, 1, true),
    "own: the main profession first, then the secondary: " .. t)
assert(has(lines[2].text, "|T") and has(lines[2].text, ":14:14|t") and has(lines[3].text, WORD), "icons above the gear line")
STUB.units.twink = { "Twinky", nil, "Player-1-2" }
assert(has(hover("twink"), "Trade_Fishing"), "a twink of the account")
STUB.units.anna = { "Anna", "Amboss", "Player-1-60" }
t = hover("anna")
assert(has(t, "Trade_Herbalism") and has(t, ALCH) and t:find(ALCH, 1, true) < t:find("Trade_Herbalism", 1, true),
    "a guild member from the note, in the fixed order: " .. t)
STUB.units.bert = { "Bert", "Bach", "Player-1-61" }
assert(has(hover("bert"), "Trade_BlackSmithing"), "a guild member from the recipe exchange")
STUB.units.stranger = { "Fremder", "Foreverpvp", "Player-1-70" }
assert(not has(hover("stranger"), "|T"), "a stranger: no icons")
NS.Set("ui.unitProfs", false)
assert(not has(hover("player"), "|T"), "icons off")
NS.Set("ui.unitProfs", true)

-- the text in the client's language
assert(has(UI.Text({ gs = 1, ilvl = 2 }), EN and " · item level " or " · Itemstufe "), "language")
assert(has(UI.Text({ gs = 1, ilvl = 2 }), "|cffffd1001|r"), "no quality: gold")
tip:Hide()
print(EN and "unit info enUS ok" or "unit info ok")
