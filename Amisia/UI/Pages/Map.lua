-- Map page: the places of the own upgrades ("Ziele"), wishes and the next steps of the open dungeon
-- quests ("Quests") with their source, coordinates and items. By default every zone, grouped (the own
-- zone first, then by distance where it can be computed, else by name; inside a zone the nearest
-- first); the picker also offers the own zone ("Hier") and each zone alone. A click sets the target,
-- the button "Karte" shows the place on the world map; the target card names it with distance and
-- direction. The items without a place have a view of their own ("Ohne Ort") with the reason. It lists
-- what the world map pins show, by the same switches. The index of all zones is built once per change
-- of what it depends on; a refresh only picks the view, and the sorted list is kept until the target,
-- the hidden places or the player's cell change.
local ADDON, ns = ...
local W, Gear, Map, T = ns.W, ns.Gear, ns.Map, ns.Theme
local L = ns.L
local GOLD = W.GOLD
local GREY = T.GREY
local P = T.MAPPAGE
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t"
local QUALITY = T.QUALITY_HEX
local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local GAP = 1            -- seconds between two rebuilds after changes
local TICK = 0.5         -- seconds between two updates of the target card's distance and direction
local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local KIND = { Q = "Quest", V = L["Händler"], P = L["PvP-Händler"], R = L["Rar"], W = L["Gegner"], X = L["Eingang"], D = L["Eingang"] }
local NO_PLACE_WHY = { C = L["Berufe"], A = L["Auktionshaus"] }
local TEXT = {
    rowHint = L["Klick: Ziel setzen. Shift-Klick: Weltkarte. Rechtsklick: mehr."],
    hint = L["Klick auf eine Zeile: Ziel setzen. Karte oder Shift-Klick: auf der Weltkarte zeigen."],
    npHint = L["Klick auf ein Item: Rezept oder Ausrüstung öffnen."],
    step = L["Quest-Schritt"],
    all = L["Alle Zonen (%d)"],
    noPlace = L["%s ohne Ort (%s)"],
    noPlaceTip = L["Die Items ohne bekannten Ort mit dem Grund zeigen."],
    back = L["Zurück zur Karte"],
    craft = L["Beruf: %s - %s"],
    craftPlain = L["Beruf: %s"],
    crafters = L["kann herstellen: %s"],
    noData = L["keine Ortsdaten"],
    target = L["Ziel: %s"],
    foreign = L["Dein eigener Wegpunkt ist gesetzt; ein neues Ziel ersetzt ihn."],
    dataSome = L["Kartendaten vom %s · Orte aus öffentlichen Questdaten, Namen teils englisch."],
    dataOwn = L["Kartendaten vom %s · Orte aus öffentlichen Questdaten."],
    emptyAll = L["Nichts aus deinen Zielen, Wünschen und Quests hat einen bekannten Ort."],
    emptyOff = L["Ziele, Wünsche und Quests sind ausgeblendet. Oben einschalten."],
    emptyNoPlace = L["Alle Items haben einen Ort."],
    openRecipe = L["Klick: Rezept auf der Seite Berufe öffnen."],
    openGear = L["Klick: Item auf der Seite Ausrüstung zeigen."],
    quests = L["Quests"],
    questsTip = L["Den nächsten Schritt jeder offenen Dungeon-Quest deiner Stufe zeigen, hier und auf der Weltkarte."],
}

local page
local builds = 0         -- index builds, for the tests
local nameMissing = false -- an item name the client did not have at the last fill

local function itemInfo(x)
    local f = C_Item and C_Item.GetItemInfo
    if f then return f(x) end
    return nil
end

local function itemText(id)
    local name, _, q = itemInfo(id)
    local row = Gear.Item(id)
    q = q or (row and (row[5] or 0) > 0 and row[5]) or 1
    if not name then nameMissing = true end
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or ("Item " .. tostring(id)))
end

-- The window state of the page in settings.map (zone: the chosen uiMapID, "here" for the own zone,
-- nil for every zone).
local function state()
    local s = AmisiaDB.settings
    s.map = type(s.map) == "table" and s.map or {}
    return s.map
end

local function hiddenSet()
    local m = AmisiaDB and AmisiaDB.map
    return m and type(m.hidden) == "table" and m.hidden or {}
end

local longDate = ns.LongDate

local function plural(n, one, many) return ("%d %s"):format(n, n == 1 and one or many) end
local function questsOn() return ns.Get("map.pinsQuests") and ns.DungeonQuestSteps ~= nil end

---------------------------------------------------------------------------
-- The index: every zone with its places, built per change
---------------------------------------------------------------------------

local function isEntrance(key) return type(key) == "string" and (key:sub(1, 2) == "I:" or key:sub(1, 2) == "N:") end

-- The first source of an item without a place and its kind of reason ("Berufe", "Auktionshaus",
-- "Weltdrops", "keine Ortsdaten").
local function noPlaceWhy(id)
    local rec = Gear.Sources(id, (Map.PageOpts()))[1] or Gear.Sources(id)[1]
    local k = rec and rec[1]
    if k == "W" and not rec[2] then return L["Weltdrops"], rec end
    return NO_PLACE_WHY[k] or TEXT.noData, rec
end

local function zoneOf(zones, list, map)
    local z = zones[map]
    if not z then
        z = { map = map, name = Map.ZoneName(map), spots = {}, byKey = {} }
        zones[map] = z
        list[#list + 1] = z
    end
    return z
end

local function buildIndex()
    builds = builds + 1
    local zones, list, without, why, items, nop = {}, {}, 0, {}, 0, {}
    for _, e in ipairs(Map.WantedItems()) do
        items = items + 1
        local places = ns.MapItemPlaces(e.id)
        if #places == 0 then
            without = without + 1
            local kind, rec = noPlaceWhy(e.id)
            why[kind] = true
            nop[#nop + 1] = { id = e.id, e = e, rec = rec, why = kind }
        end
        for _, place in ipairs(places) do
            for _, pt in ipairs(place.points) do
                local z = zoneOf(zones, list, pt.map)
                local sk = ("%s@%d:%d"):format(place.key, math.floor(pt.x * 200 + 0.5), math.floor(pt.y * 200 + 0.5))
                local spot = z.byKey[sk]
                if not spot then
                    -- items come best first: the spots in the order of their best item
                    spot = { key = place.key, rec = place.rec, giver = place.giver, point = pt, items = {}, has = {},
                        rank = #z.spots + 1, dataName = Map.DataNamed(place) }
                    z.byKey[sk] = spot
                    z.spots[#z.spots + 1] = spot
                end
                if not spot.has[e.id] then
                    spot.has[e.id] = true
                    spot.items[#spot.items + 1] = e
                end
            end
        end
    end
    -- the next quest steps (one place each), after the items' places
    local steps = 0
    if questsOn() then
        for _, place in ipairs(ns.DungeonQuestSteps()) do
            local z = zoneOf(zones, list, place.point.map)
            local spot = { rank = #z.spots + 1 }
            for k, v in pairs(place) do spot[k] = v end
            z.spots[#z.spots + 1] = spot
            steps = steps + 1
        end
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.map < b.map
    end)
    local reasons, spots = {}, 0
    for k in pairs(why) do reasons[#reasons + 1] = k end
    table.sort(reasons)
    for _, z in ipairs(list) do spots = spots + #z.spots end
    return { zones = zones, list = list, items = items, without = without, reasons = reasons, nop = nop, steps = steps,
        spots = spots }
end

local index, idxKey
local function currentIndex()
    local _, gen = Map.PageOpts()
    -- the targets and wishes follow Bis.lua's stamp, which the options follow; the steps their own
    -- stamp, the names the collector's records
    local key = table.concat({ gen, tostring(ns.Data("MAP")), tostring(ns.Data("GEAR")),
        questsOn() and ns.DungeonQuestStepsStamp() or "-", ns.CollectGen and ns.CollectGen() or 0 }, "|")
    if not index or key ~= idxKey then
        index = buildIndex()
        idxKey = key
    end
    return index
end

---------------------------------------------------------------------------
-- The shown zone and its list
---------------------------------------------------------------------------

local function inInstance()
    if not IsInInstance then return false end
    return ns.Plain(IsInInstance()) and true or false
end

-- The player's zone: uiMapID and its name, a sub zone counting as the zone above it; inside an
-- instance the zone of its entrance. Returns nil and a text when there is none.
local function hereZone()
    if inInstance() then
        local name, _, _, _, _, _, _, instID = GetInstanceInfo()
        name, instID = ns.Plain(name), ns.Plain(instID)
        local pts = type(instID) == "number" and ns.MapPoints("I:" .. instID) or {}
        if #pts == 0 and type(name) == "string" and name ~= "" then pts = ns.MapPoints("N:" .. name) end
        if pts[1] then return pts[1].map end
        return nil, L["in einer Instanz"]
    end
    local map = C_Map and C_Map.GetBestMapForUnit and ns.Plain(C_Map.GetBestMapForUnit("player"))
    for _ = 1, 10 do
        if type(map) ~= "number" or map <= 0 then break end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        if type(info) ~= "table" then break end
        local kind = tonumber(ns.Plain(info.mapType)) or ZONE
        if kind == ZONE then return map end
        if kind < ZONE then break end
        map = ns.Plain(info.parentMapID)
    end
    return nil, L["unbekannt"]
end

local viewKey = {}
local viewList
local version = 0         -- bumped by the target and the hidden places (MAP_TARGET)

-- Yards from the player (me: Map.PlayerPosition) to a spot on the same continent, or nil; the
-- spot's world position is asked once per index.
local function distOf(s, me)
    if not me or not me.wx then return nil end
    if s.world == nil then
        local cont, wx, wy = Map.WorldOf(s.point.map, s.point.x, s.point.y)
        s.world = cont and { cont, wx, wy } or false
    end
    local w = s.world
    if not w or w[1] ~= me.cont then return nil end
    return math.sqrt((w[2] - me.wx) ^ 2 + (w[3] - me.wy) ^ 2)
end

local function sameTarget(s, t)
    return t ~= nil and s.key == t.key and s.point.map == t.map and math.abs(s.point.x - t.x) <= 0.001
        and math.abs(s.point.y - t.y) <= 0.001
end

-- hidden ones at the bottom, then by distance, then by their best item
local function bySpot(a, b)
    if a.hidden ~= b.hidden then return b.hidden end
    if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
    if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
    return a.rank < b.rank
end

-- The sorted places of a zone; each entry carries target, hidden and dist for the row. Returns the
-- list and the nearest distance of a shown place.
local function sortedSpots(z, t, me, hidden)
    local out, near = {}, nil
    for _, s in ipairs(z.spots) do
        s.hidden = hidden[s.key] and true or false
        s.target = sameTarget(s, t)
        s.dist = distOf(s, me)
        if s.dist and not s.hidden and (not near or s.dist < near) then near = s.dist end
        out[#out + 1] = s
    end
    table.sort(out, bySpot)
    return out, near
end

-- The rows of a view: one zone's places (zone: a uiMapID), or with all every zone's under a head row
-- { header, zone, name, count, dist }: the own zone (here) first, then by distance, else by name.
local function viewRows(idx, all, zone, here)
    local t = ns.MapTarget()
    local m, cx, cy = Map.PlayerCell()
    local k = viewKey
    if viewList and k.idx == idx and k.all == all and k.zone == zone and k.here == here and k.version == version
        and k.t == t and k.m == m and k.cx == cx and k.cy == cy then
        return viewList
    end
    local me = Map.PlayerPosition()
    local hidden = hiddenSet()
    local out = {}
    if all then
        local groups = {}
        for _, z in ipairs(idx.list) do
            local rows, near = sortedSpots(z, t, me, hidden)
            groups[#groups + 1] = { z = z, rows = rows, near = near, here = z.map == here }
        end
        table.sort(groups, function(a, b)
            if a.here ~= b.here then return a.here end
            if a.near and b.near and a.near ~= b.near then return a.near < b.near end
            if (a.near ~= nil) ~= (b.near ~= nil) then return a.near ~= nil end
            if a.z.name ~= b.z.name then return a.z.name < b.z.name end
            return a.z.map < b.z.map
        end)
        for _, g in ipairs(groups) do
            out[#out + 1] = { header = true, zone = g.z.map, name = g.z.name, count = #g.rows, dist = not g.here and g.near or nil }
            for _, s in ipairs(g.rows) do out[#out + 1] = s end
        end
    elseif zone and idx.zones[zone] then
        out = sortedSpots(idx.zones[zone], t, me, hidden)
    end
    viewKey = { idx = idx, all = all, zone = zone, here = here, version = version, t = t, m = m, cx = cx, cy = cy }
    viewList = out
    return out
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function kindText(e)
    if e.step then return TEXT.step end
    if isEntrance(e.key) then return L["Eingang"] end
    return KIND[e.rec and e.rec[1]] or ""
end

local function sourceText(e)
    if e.step then return Map.StepText(e) end
    local rec = e.rec
    if not rec or isEntrance(e.key) then return Map.PlaceName(e) end
    if rec[1] == "Q" then
        local title = Gear.SourceText(rec, true):gsub("^Quest: ", "")
        local giver = Map.OwnName(e.key) or e.giver
        return giver and (title .. " (" .. giver .. ")") or title
    end
    return Map.PlaceName(e)
end

local function itemsText(e)
    local best = e.items[1]
    if not best then return "" end
    local text = (best.wish and (STAR .. " ") or "") .. itemText(best.id)
    if #e.items > 1 then text = text .. (" +%d"):format(#e.items - 1) end
    return text
end

local function meters(d) return L[" · %d m"]:format(math.floor(d + 0.5)) end

-- Whether the client holds a waypoint that is not Amisia's (Forever).
local function foreignWaypoint()
    if not Map.ClientWaypoints() then return false end
    local t = ns.MapTarget()
    if t and t.ours then return false end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    return ok and point ~= nil
end

-- The player's facing in radians (counter-clockwise from north), or nil.
local function facing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    f = ok and ns.Plain(f) or nil
    return type(f) == "number" and f or nil
end

-- The target card: the name line, the line of zone, coordinates, distance and direction, and the
-- arrow's turn relative to the player's facing (nil: no arrow).
local function targetLines()
    local t = ns.MapTarget()
    if not t then
        if foreignWaypoint() then return GREY .. TEXT.foreign .. "|r", "", nil end
        return L["Kein Ziel gesetzt."], "", nil
    end
    local me = Map.PlayerPosition()
    local sub = ("%s %s"):format(Map.ZoneName(t.map), Map.Coords(t))
    local d = Map.Distance(t, me)
    local turn
    if d then
        sub = sub .. meters(d)
        local bearing = Map.Bearing(t, me)
        local word = Map.DirectionWord(bearing)
        if word then sub = sub .. " · " .. word end
        local face = bearing and facing()
        if face then turn = -(bearing + face) end
    elseif me then
        sub = sub .. " · " .. L["Anderer Kontinent"]
    end
    return TEXT.target:format(t.label or "?"), sub, turn
end

local function fillCard(f)
    local name, sub, turn = targetLines()
    f.target:SetText(name)
    f.targetSub:SetText(sub)
    if turn and f.arrow.SetRotation then
        f.arrow:SetRotation(turn)
        f.arrow:Show()
    else
        f.arrow:Hide()
    end
end

---------------------------------------------------------------------------
-- The items without a place
---------------------------------------------------------------------------

-- The recipe that makes an item in the profession of key ("tailoring"): skill line, spell, name.
local function recipeOf(id, key)
    local Pr = ns.Prof
    if not (Pr and key and ns.HasData("PROFESSIONS")) then return nil end
    for _, skill in ipairs(Pr.Skills()) do
        if Pr.Key(skill) == key then
            for _, r in ipairs(Pr.Recipes(skill)) do
                if r.item == id then return skill, r.spell, Pr.RecipeName(r) end
            end
        end
    end
    return nil
end

-- The reason of an item without a place as one line, worked out when its row first shows: the
-- profession and recipe with the guild's crafters (not in combat), the auction house, the world drop,
-- else "keine Ortsdaten" with the source.
local function npDetail(n)
    if n.detail then return n.detail end
    local rec = n.rec
    local k = rec and rec[1]
    local text, partial
    if k == "C" then
        local skill, spell, name = recipeOf(n.id, rec[2])
        n.skill, n.spell, n.recipe = skill, spell, name
        local prof = Gear.PROFESSIONS[rec[2]] or tostring(rec[2])
        text = name and TEXT.craft:format(prof, name) or TEXT.craftPlain:format(Gear.SourceText(rec))
        local Cr = ns.Crafters
        if Cr and Cr.ForItem then
            if InCombatLockdown and InCombatLockdown() then
                -- the crafters wait for the end of combat: this text is not kept, the next fill
                -- out of combat makes it whole
                partial = true
            else
                local list = Cr.ForItem(n.id)
                if #list > 0 then text = text .. " · " .. TEXT.crafters:format(Cr.Text(list, 3)) end
            end
        end
    elseif k == "A" or (k == "W" and not rec[2]) then
        text = Gear.SourceText(rec)
    else
        text = rec and (TEXT.noData .. ": " .. Gear.SourceText(rec, true)) or TEXT.noData
    end
    if not partial then n.detail = text end
    return text
end

local function openNoPlace(n)
    if not n then return end
    npDetail(n)
    if n.skill and n.spell and ns.ShowRecipe then
        ns.ShowRecipe(n.skill, n.spell, n.recipe)
    elseif ns.ShowGear then
        ns.ShowGear(n.e.wish and "wish" or "goals", n.e.slot or n.e.wishSlot)
    end
end

local function fillNoPlace(r, n)
    r.name:SetText((n.e.wish and (STAR .. " ") or "") .. itemText(n.id))
    r.why:SetText(npDetail(n))
end

local function noPlaceTooltip(self)
    local n = self.item
    if not n then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(n.id) else GameTooltip:SetHyperlink("item:" .. n.id) end
    GameTooltip:AddLine(npDetail(n), 1, 1, 1, true)
    GameTooltip:AddLine((n.skill and n.spell) and TEXT.openRecipe or TEXT.openGear, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function go(e)
    if not e or e.header then return end
    local ok, why = Map.SetPlaceTarget(e)
    if not ok and why then ns.msg(why) end
    ns.Refresh()
end

local function fillRow(r, e)
    if e.header then
        for _, fs in ipairs({ r.kind, r.src, r.where, r.items }) do fs:SetText("") end
        r.go:Hide()
        r.head:SetText(("%s (%d)%s"):format(e.name, e.count, e.dist and meters(e.dist) or ""))
        r.head:Show()
        return
    end
    r.head:Hide()
    r.go:Show()
    r.kind:SetText(kindText(e))
    r.src:SetText(sourceText(e))
    local where = Map.Coords(e.point)
    if e.dist then where = where .. meters(e.dist) end
    r.where:SetText(where)
    -- a hidden place is grey throughout, its items without their quality colour
    if e.hidden then
        for _, fs in ipairs({ r.kind, r.src, r.where, r.items }) do fs:SetTextColor(0.56, 0.53, 0.64) end
        r.items:SetText(GREY .. (itemsText(e):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) .. "|r")
        return
    end
    r.kind:SetTextColor(1, 1, 1)
    r.where:SetTextColor(1, 1, 1)
    r.items:SetTextColor(1, 1, 1)
    if e.target then r.src:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else r.src:SetTextColor(1, 1, 1) end
    r.items:SetText(itemsText(e))
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function Map.PageBuilds() return builds end

-- The chosen zone: a uiMapID, "here", or nil for every zone.
local function chosenZone()
    local z = state().zone
    if type(z) == "number" or z == "here" then return z end
    return nil
end

local function pickerValues(idx, hereMap, hereText, chosen)
    local values = { { value = "all", text = TEXT.all:format(idx.spots) },
        { value = "here", text = L["Hier: %s"]:format(hereMap and Map.ZoneName(hereMap) or hereText or L["unbekannt"]) } }
    local found = false
    for _, z in ipairs(idx.list) do
        values[#values + 1] = { value = z.map, text = ("%s (%d)"):format(z.name, #z.spots) }
        if z.map == chosen then found = true end
    end
    -- a chosen zone without places now: still listed, with nothing
    if type(chosen) == "number" and not found then
        values[#values + 1] = { value = chosen, text = ("%s (0)"):format(Map.ZoneName(chosen)) }
    end
    return values
end

-- "2 Orte · 4 Items" of the shown places.
local function countsText(rows)
    local n, items, seen = 0, 0, {}
    for _, s in ipairs(rows) do
        if not s.header then
            n = n + 1
            for _, e in ipairs(s.items) do
                if not seen[e.id] then seen[e.id], items = true, items + 1 end
            end
        end
    end
    return plural(n, L["Ort"], L["Orte"]) .. " · " .. plural(items, "Item", "Items")
end

local function noPlaceText(idx)
    return TEXT.noPlace:format(plural(idx.without, "Item", "Items"), table.concat(idx.reasons, ", "))
end

local function setEmpty(f, idx, all, noPlace)
    if noPlace then
        f.empty:Set(L["Keine Orte"], TEXT.emptyNoPlace)
    elseif not ns.HasData("MAP") then
        f.empty:Set(L["Keine Orte"], L["Für diesen Client gibt es keine Kartendaten."])
    elseif not ns.Get("map.pinsTargets") and not ns.Get("map.pinsWishes") and not ns.Get("map.pinsQuests") then
        f.empty:Set(L["Keine Orte"], TEXT.emptyOff)
    elseif not ns.Get("map.pinsTargets") and not ns.Get("map.pinsWishes") then
        f.empty:Set(L["Keine Orte"], L["Ziele und Wünsche sind ausgeblendet. Oben einschalten."])
    elseif idx.items == 0 and idx.steps == 0 then
        f.empty:Set(L["Keine Orte"], L["Noch keine Ziele oder Wünsche. Siehe Seite Ausrüstung."])
    elseif all then
        f.empty:Set(L["Keine Orte"], TEXT.emptyAll)
    else
        f.empty:Set(L["Keine Orte"], L["In dieser Zone liegt nichts aus deinen Zielen und Wünschen."])
    end
end

local function refresh(f)
    local idx = currentIndex()
    if idx.without == 0 then f.view = nil end
    local noPlace = f.view == "noplace"
    local chosen = chosenZone()
    local hereMap, hereText = hereZone()
    local all = chosen == nil
    local zone = type(chosen) == "number" and chosen or hereMap
    -- another view starts at the top of its list
    local shownKey = tostring(noPlace) .. ":" .. tostring(all) .. ":" .. tostring(zone)
    if f.shownKey ~= shownKey then
        f.list.offset = 0
        f.npList.offset = 0
    end
    f.shownKey = shownKey
    f.zone:SetValues(pickerValues(idx, hereMap, hereText, chosen))
    f.zone:SetValue(chosen or "all")
    f.shownZone = zone
    f.targets:SetOn(ns.Get("map.pinsTargets") and true or false)
    f.wishes:SetOn(ns.Get("map.pinsWishes") and true or false)
    f.quests:SetOn(ns.Get("map.pinsQuests") and true or false)
    f.open:SetEnabled(zone ~= nil)
    f.open:SetShown(not noPlace)
    f.back:SetShown(noPlace)
    f:Place(1, { f.zone, f.targets, f.wishes, f.quests }, { noPlace and f.back or f.open })
    fillCard(f)
    local hasTarget = ns.MapTarget() ~= nil
    f.clear:SetShown(hasTarget)
    f:Place(3, { { f.card, fill = true } }, hasTarget and { f.clear } or nil)
    -- the anchors give the card's texts their width; also set (the tests measure against it)
    local textW = math.max(10, (f.card:GetWidth() or 0) - P.TEXT_X - P.TEXT_Y)
    f.target:SetWidth(textW)
    f.targetSub:SetWidth(textW)
    local rows = noPlace and idx.nop or viewRows(idx, all, zone, hereMap)
    -- the counts and the link to the items without a place
    if noPlace then
        f.counts:SetText(noPlaceText(idx))
        f.noPlace:Hide()
    else
        f.counts:SetText(countsText(rows))
        if idx.without > 0 then
            f.noPlace.label:SetText("· " .. noPlaceText(idx))
            f.noPlace:SetWidth(math.ceil(f.noPlace.label:GetStringWidth() or 0) + 2 * T.CHIP_PAD)
            f.noPlace:Show()
        else
            f.noPlace:Hide()
        end
    end
    f.counts:SetWidth(math.ceil(f.counts:GetStringWidth() or 0) + 2)
    f:Place(2, { f.counts, (not noPlace and idx.without > 0) and f.noPlace or nil })
    nameMissing = false
    f.headFrame:SetShown(not noPlace)
    f.list:SetShown(not noPlace)
    f.npHeadFrame:SetShown(noPlace)
    f.npList:SetShown(noPlace)
    local dataName = false
    if noPlace then
        f.npList:SetItems(rows)
        f.hint:SetText(TEXT.npHint)
    else
        f.list:SetItems(rows)
        f.hint:SetText(TEXT.hint)
        for _, e in ipairs(rows) do
            if e.dataName then
                dataName = true
                break
            end
        end
    end
    if #rows > 0 then
        f.empty:Hide()
    else
        setEmpty(f, idx, all, noPlace)
        f.empty:Show()
    end
    f.data:SetText((dataName and TEXT.dataSome or TEXT.dataOwn):format(longDate(ns.HasData("MAP") and ns.Data("MAP").built)))
    local hidden = 0
    for _ in pairs(hiddenSet()) do hidden = hidden + 1 end
    if hidden > 0 and not noPlace then
        f.showHidden:SetText((L["Ausgeblendete zeigen (%d)"]):format(hidden))
        f.showHidden:Show()
    else
        f.showHidden:Hide()
    end
    f.wait = 0
end

local COLS, NP_COLS = {}, {}
for i, c in ipairs(P.COLS) do COLS[i] = { c[1], c[2], c[3], cell = c.cell } end
COLS[1][4], COLS[2][4], COLS[3][4], COLS[4][4], COLS[5][4] = L["Art"], L["Quelle"], L["Ort##Spalte"], "Items", L["Karte"]
for i, c in ipairs(P.NP_COLS) do NP_COLS[i] = { c[1], c[2], c[3] } end
NP_COLS[1][4], NP_COLS[2][4] = "Item", L["Grund"]

local function create(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: zone and the three switches, the world map (or the way back) at the right; then
    -- the counts with the link to the items without a place, and the target card
    f:Bands({ "row", "line", { "line", lines = P.CARD_LINES } })
    f.zone = W.Picker(f, P.PICKER_W, function(v)
        local s = state()
        if v == "all" then s.zone = nil elseif v == "here" then s.zone = "here" else s.zone = tonumber(v) end
        f.view = nil
        ns.Refresh()
    end)
    f.targets = W.TabCheck(f, L["Ziele"], function() ns.Set("map.pinsTargets", not ns.Get("map.pinsTargets")); ns.Refresh() end)
    f.wishes = W.TabCheck(f, L["Wünsche"], function() ns.Set("map.pinsWishes", not ns.Get("map.pinsWishes")); ns.Refresh() end)
    f.quests = W.TabCheck(f, TEXT.quests, function() ns.Set("map.pinsQuests", not ns.Get("map.pinsQuests")); ns.Refresh() end)
    W.FitChip(f.targets)
    W.FitChip(f.wishes)
    W.FitChip(f.quests)
    W.Tooltip(f.targets, L["Ziele"], L["Orte der Upgrades aus Ziele zeigen, hier und auf der Weltkarte."])
    W.Tooltip(f.wishes, L["Wünsche"], L["Orte der Wünsche zeigen, hier und auf der Weltkarte."])
    W.Tooltip(f.quests, TEXT.quests, TEXT.questsTip)
    f.open = W.Button(f, L["Weltkarte öffnen"], P.OPEN_W, function()
        local zone = f.shownZone
        if zone then ns.MapShowOnWorldMap({ map = zone, x = 0.5, y = 0.5 }) end
    end)
    W.FitChip(f.open, P.OPEN_W)
    f.back = W.Link(f, TEXT.back, function()
        f.view = nil
        ns.Refresh()
    end)
    W.FitChip(f.back)
    f.back:Hide()
    f:Place(1, { f.zone, f.targets, f.wishes, f.quests }, { f.open })
    -- the counts and the link "N Items ohne Ort (...)" (a plain button in the gold of the heads)
    f.counts = W.Text(f, T.FONT.hint)
    f.noPlace = CreateFrame("Button", nil, f)
    f.noPlace:SetHeight(T.LAYOUT.LINE_H)
    f.noPlace.label = W.Text(f.noPlace, T.FONT.head)
    f.noPlace.label:SetPoint("LEFT", 0, 0)
    f.noPlace:SetScript("OnClick", function()
        f.view = "noplace"
        ns.Refresh()
    end)
    W.Tooltip(f.noPlace, L["Ohne Ort"], TEXT.noPlaceTip)
    f.noPlace:Hide()
    f:Place(2, { f.counts })
    -- the target card: the arrow, the name over zone, coordinates, distance and direction
    f.card = CreateFrame("Frame", nil, f)
    f.card:SetHeight(T.LAYOUT.LINE_H * P.CARD_LINES)
    W.Flat(f.card, 1, 1, 1, P.CARD_SHADE)
    f.arrow = f.card:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(P.ARROW, P.ARROW)
    f.arrow:SetPoint("LEFT", P.ARROW_X, 0)
    f.arrow:SetTexture(P.ARROW_TEX)
    f.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    f.arrow:Hide()
    f.target = W.Text(f.card, T.FONT.body)
    f.target:SetPoint("TOPLEFT", P.TEXT_X, -P.TEXT_Y)
    f.target:SetPoint("TOPRIGHT", -P.TEXT_Y, -P.TEXT_Y)
    f.targetSub = W.Text(f.card, T.FONT.text)
    f.targetSub:SetPoint("BOTTOMLEFT", P.TEXT_X, P.TEXT_Y)
    f.targetSub:SetPoint("BOTTOMRIGHT", -P.TEXT_Y, P.TEXT_Y)
    f.targetSub:SetTextColor(0.75, 0.75, 0.75)
    f.clear = W.Link(f, L["Ziel löschen"], function()
        ns.MapClearTarget()
        ns.Refresh()
    end)
    W.FitChip(f.clear)
    f:Place(3, { { f.card, fill = true } }, { f.clear })
    f:Footer({ { "hint", help = true }, { "data", help = true } })
    f.hint:SetText(TEXT.hint)
    f.showHidden = W.Link(f, L["Ausgeblendete zeigen"], function()
        wipe(hiddenSet())
        ns.Fire("MAP_TARGET")
        ns.Refresh()
    end)
    f:BottomRow(nil, { f.showHidden })
    f.showHidden:Hide()

    f.headFrame, f.head = f:Columns(COLS)
    f.list = f:List(P.ROWS, P.ROW_H, function(r)
        W.Cells(r, COLS)
        r.head = W.Text(r, T.FONT.head, P.HEAD_W)
        r.head:SetPoint("LEFT", P.HEAD_X, 0)
        r.head:Hide()
        r.go = W.Button(r, L["Karte"], P.GO_W, function(self)
            local e = self:GetParent().item
            if e and not e.header then ns.MapShowOnWorldMap(e.point) end
        end, { height = T.ROW_BUTTON_H })
        r.go:SetPoint("LEFT", P.GO_X, 0)
        W.RowAction(r, r.go)   -- shown while the mouse is on the row (D-67)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e or e.header then return end
            if button == "RightButton" then
                W.Menu(self, Map.PlaceMenu(e))
            elseif IsShiftKeyDown and IsShiftKeyDown() then
                ns.MapShowOnWorldMap(e.point)
            else
                go(e)
            end
        end)
        r:SetScript("OnEnter", function(self)
            if self.item and not self.item.header then Map.PlaceTooltip(self, self.item, TEXT.rowHint) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, fillRow, { fill = true })
    -- the view "Ohne Ort" in the same place
    f.npHeadFrame, f.npHead = f:Columns(NP_COLS)
    f.npList = f:List(P.ROWS, P.ROW_H, function(r)
        W.Cells(r, NP_COLS)
        r:SetScript("OnClick", function(self) openNoPlace(self.item) end)
        r:SetScript("OnEnter", noPlaceTooltip)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, fillNoPlace, { fill = true })
    f.npHeadFrame:Hide()
    f.npList:Hide()
    f.empty = f:Empty(nil, f.list)

    -- the target card's distance and direction follow the player while the page shows
    f.wait = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.wait = (self.wait or 0) + (elapsed or 0)
        if self.wait < TICK - 1e-9 then return end
        self.wait = 0
        if ns.MapTarget() then fillCard(self) end
    end)
    return f
end

ns.RegisterPanel{ key = "map", label = L["Karte"], sub = L["Deine Ziele, Wünsche und Quests auf der Weltkarte."], icon = ICON, order = 55, group = "dungeons",
    available = function() return Gear.Available() and ns.HasData("MAP") end,
    create = create, refresh = refresh }

-- Opens the page; zone: a uiMapID to show, "hier"/"here" for the own zone, "alle"/"all" for every
-- zone, nil for the last choice.
function ns.ShowMap(zone)
    if AmisiaDB and AmisiaDB.settings then
        local z = tonumber(zone)
        if z then
            state().zone = z
        elseif zone == "hier" or zone == "here" then   -- l10n-ok: command word
            state().zone = "here"
        elseif zone == "alle" or zone == "all" then     -- l10n-ok: command word
            state().zone = nil
        end
    end
    if page then page.view = nil end
    if ns.ShowPage then ns.ShowPage("map") end
end

---------------------------------------------------------------------------
-- Changes: rebuilt while the page shows, at most once a second
---------------------------------------------------------------------------

local function shown()
    return page ~= nil and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "map"
end

local schedule = W.RefreshWhileShown(shown, GAP)

ns.Listen("BIS_CHANGED", schedule)
ns.Listen("MAP_TARGET", function()
    version = version + 1
    schedule()
end)
ns.BisOnOwned(schedule)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function()
    if type(chosenZone()) ~= "number" then schedule() end
end)
-- a quest taken, handed in or dropped moves the quest steps
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do ns.OnEvent(event, schedule) end

-- Item names the client did not have at the last fill: once item data arrives the shown rows are
-- filled again, once for a burst of answers.
W.RefreshOnItemNames(function() return nameMissing end, shown)
