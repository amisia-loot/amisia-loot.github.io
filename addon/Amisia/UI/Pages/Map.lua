-- Map page: the places of the own upgrades ("Ziele") and wishes in one zone (the
-- player's own by default) with their source, coordinates and items, a button to set the target
-- and the target line. It lists what the world map pins show, by the same switches. The index of
-- all zones is built once per change of what it depends on; a refresh only picks the zone, and a
-- zone's sorted list is kept until the target, the hidden places or the player's cell change.
local ADDON, ns = ...
local W, Gear, Map, T = ns.W, ns.Gear, ns.Map, ns.Theme
local GOLD = W.GOLD
local GREY = T.GREY
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t"
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local ROWS, ROW_H = 12, 24
local GAP = 1            -- seconds between two rebuilds after changes
local TICK = 0.5         -- seconds between two updates of the target line's distance
local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local KIND = { Q = "Quest", V = "Händler", P = "PvP-Händler", R = "Rar", W = "Gegner", X = "Eingang", D = "Eingang" }
local NO_PLACE_WHY = { C = "Berufe", A = "Auktionshaus" }
local ROW_HINT = "Klick: Ziel setzen. Shift-Klick: Weltkarte. Rechtsklick: mehr."

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

-- The window state of the page in settings.map (zone: the chosen uiMapID, nil for "Hier").
local function state()
    local s = AmisiaDB.settings
    s.map = type(s.map) == "table" and s.map or {}
    return s.map
end

local function hiddenSet()
    local m = AmisiaDB and AmisiaDB.map
    return m and type(m.hidden) == "table" and m.hidden or {}
end

local function longDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    return y and (d .. "." .. m .. "." .. y) or "?"
end

local function plural(n, one, many) return ("%d %s"):format(n, n == 1 and one or many) end

---------------------------------------------------------------------------
-- The index: every zone with its places, built per change
---------------------------------------------------------------------------

local function noPlaceWhy(id)
    local rec = Gear.Sources(id, (Map.PageOpts()))[1] or Gear.Sources(id)[1]
    local k = rec and rec[1]
    if k == "W" and not rec[2] then return "Weltdrops" end
    return NO_PLACE_WHY[k] or "keine Ortsdaten"
end

local function buildIndex()
    builds = builds + 1
    local zones, list, without, why, items = {}, {}, 0, {}, 0
    for _, e in ipairs(Map.WantedItems()) do
        items = items + 1
        local places = ns.MapItemPlaces(e.id)
        if #places == 0 then
            without = without + 1
            why[noPlaceWhy(e.id)] = true
        end
        for _, place in ipairs(places) do
            for _, pt in ipairs(place.points) do
                local z = zones[pt.map]
                if not z then
                    z = { map = pt.map, name = Map.ZoneName(pt.map), spots = {}, byKey = {} }
                    zones[pt.map] = z
                    list[#list + 1] = z
                end
                local sk = ("%s@%d:%d"):format(place.key, math.floor(pt.x * 200 + 0.5), math.floor(pt.y * 200 + 0.5))
                local spot = z.byKey[sk]
                if not spot then
                    -- items come best first: the spots in the order of their best item
                    spot = { key = place.key, rec = place.rec, giver = place.giver, point = pt, items = {}, has = {},
                        rank = #z.spots + 1 }
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
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.map < b.map
    end)
    local reasons = {}
    for k in pairs(why) do reasons[#reasons + 1] = k end
    table.sort(reasons)
    return { zones = zones, list = list, items = items, without = without, reasons = reasons }
end

local index, idxGen, idxMap, idxGear
local function currentIndex()
    local _, gen = Map.PageOpts()
    if not index or gen ~= idxGen or idxMap ~= ns.Data("MAP") or idxGear ~= ns.Data("GEAR") then
        -- the targets and wishes follow Bis.lua's stamp, which the options follow
        index = buildIndex()
        idxGen, idxMap, idxGear = gen, ns.Data("MAP"), ns.Data("GEAR")
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
        return nil, "in einer Instanz"
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
    return nil, "unbekannt"
end

local viewKey = {}
local viewList
local version = 0         -- bumped by the target and the hidden places (MAP_TARGET)

-- The places of a zone: hidden ones at the bottom, then by distance when the player is in the zone,
-- then by their best item. Each entry carries target, hidden and dist for the row.
local function zoneList(z, zone)
    local t = ns.MapTarget()
    local m, cx, cy = Map.PlayerCell()
    local inZone = m ~= nil and z ~= nil and m == zone
    if not inZone then m, cx, cy = nil, nil, nil end
    local k = viewKey
    if viewList and k.z == z and k.zone == zone and k.version == version and k.t == t and k.m == m and k.cx == cx and k.cy == cy then
        return viewList
    end
    local out = {}
    if z then
        local hidden = hiddenSet()
        local me = inZone and Map.PlayerPosition() or nil
        for _, s in ipairs(z.spots) do
            s.hidden = hidden[s.key] and true or false
            s.target = t ~= nil and s.key == t.key and math.abs(s.point.x - t.x) <= 0.001 and math.abs(s.point.y - t.y) <= 0.001
                and s.point.map == t.map
            s.dist = me and Map.Distance(s.point, me) or nil
            out[#out + 1] = s
        end
        table.sort(out, function(a, b)
            if a.hidden ~= b.hidden then return b.hidden end
            if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
            if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
            return a.rank < b.rank
        end)
    end
    viewKey = { z = z, zone = zone, version = version, t = t, m = m, cx = cx, cy = cy }
    viewList = out
    return out
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function isEntrance(key) return type(key) == "string" and (key:sub(1, 2) == "I:" or key:sub(1, 2) == "N:") end

local function kindText(e)
    if isEntrance(e.key) then return "Eingang" end
    return KIND[e.rec and e.rec[1]] or ""
end

local function sourceText(e)
    local rec = e.rec
    if not rec or isEntrance(e.key) then return Map.PlaceName(e) end
    if rec[1] == "Q" then
        local title = Gear.SourceText(rec, true):gsub("^Quest: ", "")
        return e.giver and (title .. " (" .. e.giver .. ")") or title
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

-- Whether the client holds a waypoint that is not Amisia's (Forever).
local function foreignWaypoint()
    if not Map.ClientWaypoints() then return false end
    local t = ns.MapTarget()
    if t and t.ours then return false end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    return ok and point ~= nil
end

local function targetText()
    local t = ns.MapTarget()
    if not t then
        if foreignWaypoint() then return GREY .. "Dein eigener Wegpunkt ist gesetzt; Weg ersetzt ihn.|r" end
        return "Kein Ziel gesetzt."
    end
    local d = Map.Distance(t)
    return ("Ziel: %s, %s %s%s"):format(t.label or "?", Map.ZoneName(t.map), Map.Coords(t),
        d and (" · %d m"):format(math.floor(d + 0.5)) or "")
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function go(e)
    if not e then return end
    local ok, why = Map.SetPlaceTarget(e)
    if not ok and why then ns.msg(why) end
    ns.Refresh()
end

local function fillRow(r, e)
    r.kind:SetText(kindText(e))
    r.src:SetText(sourceText(e))
    local where = Map.Coords(e.point)
    if e.dist then where = where .. (" · %d m"):format(math.floor(e.dist + 0.5)) end
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

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or T.FONT.head, w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function ns.MapPageFrame() return page end
function Map.PageBuilds() return builds end

local function chosenZone()
    local z = state().zone
    return type(z) == "number" and z or nil
end

local function pickerValues(idx, hereMap, hereText, chosen)
    local values = { { value = "here", text = "Hier: " .. (hereMap and Map.ZoneName(hereMap) or hereText or "unbekannt") } }
    local found = false
    for _, z in ipairs(idx.list) do
        values[#values + 1] = { value = z.map, text = ("%s (%d)"):format(z.name, #z.spots) }
        if z.map == chosen then found = true end
    end
    -- a chosen zone without places now: still listed, with nothing
    if chosen and not found then values[#values + 1] = { value = chosen, text = ("%s (0)"):format(Map.ZoneName(chosen)) } end
    return values
end

local function countsText(idx, z)
    local n, items = 0, 0
    if z then
        n = #z.spots
        local seen = {}
        for _, s in ipairs(z.spots) do
            for _, e in ipairs(s.items) do
                if not seen[e.id] then seen[e.id], items = true, items + 1 end
            end
        end
    end
    local text = plural(n, "Ort", "Orte") .. " · " .. plural(items, "Item", "Items")
    if idx.without > 0 then
        text = text .. (" · %s ohne Ort (%s)"):format(plural(idx.without, "Item", "Items"), table.concat(idx.reasons, ", "))
    end
    return text
end

local function refresh(f)
    local idx = currentIndex()
    local chosen = chosenZone()
    local hereMap, hereText = hereZone()
    local zone = chosen or hereMap
    -- another zone starts at the top of its list
    if f.shownZone ~= zone then f.list.offset = 0 end
    f.zone:SetValues(pickerValues(idx, hereMap, hereText, chosen))
    f.zone:SetValue(chosen or "here")
    f.shownZone = zone
    f.targets:SetOn(ns.Get("map.pinsTargets") and true or false)
    f.wishes:SetOn(ns.Get("map.pinsWishes") and true or false)
    f.open:SetEnabled(zone ~= nil)
    local z = zone and idx.zones[zone] or nil
    f.counts:SetText(countsText(idx, z))
    f.target:SetText(targetText())
    if ns.MapTarget() then f.clear:Show() else f.clear:Hide() end
    local list = zoneList(z, zone)
    nameMissing = false
    f.list:SetItems(list)
    if #list > 0 then
        f.empty:Hide()
    else
        if not ns.HasData("MAP") then
            f.empty:SetText("Für diesen Client gibt es keine Kartendaten.")
        elseif not ns.Get("map.pinsTargets") and not ns.Get("map.pinsWishes") then
            f.empty:SetText("Ziele und Wünsche sind ausgeblendet. Oben einschalten.")
        elseif idx.items == 0 then
            f.empty:SetText("Noch keine Ziele oder Wünsche. Siehe Seite Ausrüstung.")
        else
            f.empty:SetText("In dieser Zone liegt nichts aus deinen Zielen und Wünschen.")
        end
        f.empty:Show()
    end
    f.data:SetText(("Kartendaten vom %s · Orte aus öffentlichen Questdaten, Namen englisch."):format(longDate(ns.HasData("MAP") and ns.Data("MAP").built)))
    local hidden = 0
    for _ in pairs(hiddenSet()) do hidden = hidden + 1 end
    if hidden > 0 then
        f.showHidden:SetText(("Ausgeblendete zeigen (%d)"):format(hidden))
        f.showHidden:Show()
    else
        f.showHidden:Hide()
    end
    f.wait = 0
end

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)
    page = f
    f.zone = W.Picker(f, 240, function(v)
        state().zone = (v ~= "here") and tonumber(v) or nil
        ns.Refresh()
    end)
    f.zone:SetPoint("TOPLEFT", 0, -1)
    f.targets = W.Chip(f, "Ziele", 60, function() ns.Set("map.pinsTargets", not ns.Get("map.pinsTargets")) end)
    f.targets:SetPoint("TOPLEFT", 248, -1)
    f.wishes = W.Chip(f, "Wünsche", 70, function() ns.Set("map.pinsWishes", not ns.Get("map.pinsWishes")) end)
    f.wishes:SetPoint("TOPLEFT", 314, -1)
    W.Tooltip(f.targets, "Ziele", "Orte der Upgrades aus Ziele zeigen, hier und auf der Weltkarte.")
    W.Tooltip(f.wishes, "Wünsche", "Orte der Wünsche zeigen, hier und auf der Weltkarte.")
    f.open = W.Button(f, "Weltkarte öffnen", 130, function()
        local zone = f.shownZone
        if zone then ns.MapShowOnWorldMap({ map = zone, x = 0.5, y = 0.5 }) end
    end)
    f.open:SetPoint("TOPRIGHT", 0, 0)
    f.counts = W.Text(f, T.FONT.hint, 598)
    f.counts:SetPoint("TOPLEFT", 4, -28)
    f.target = W.Text(f, T.FONT.text, 484)
    f.target:SetPoint("TOPLEFT", 4, -52)
    f.clear = W.Button(f, "Ziel löschen", 110, function()
        ns.MapClearTarget()
        ns.Refresh()
    end)
    f.clear:SetPoint("TOPRIGHT", 0, -48)

    local h = CreateFrame("Frame", nil, f)
    h:SetHeight(14)
    h:SetPoint("TOPLEFT", 0, -76)
    h:SetPoint("TOPRIGHT", 0, -76)
    -- the list is 590 wide (12 px for its scroll bar): the items give them, the button moves left
    f.head = { kind = col(h, 4, 66, "Art"), src = col(h, 74, 186, "Quelle"), where = col(h, 264, 100, "Ort"),
        items = col(h, 368, 164, "Items"), go = col(h, 540, 46, "Weg") }
    f.list = W.List(f, ROWS, ROW_H, function(r)
        r.kind = col(r, 4, 66, nil, T.FONT.text)
        r.src = col(r, 74, 186, nil, T.FONT.text)
        r.where = col(r, 264, 100, nil, T.FONT.text)
        r.items = col(r, 368, 164, nil, T.FONT.text)
        r.go = W.Button(r, "Weg", 54, function(self) go(self:GetParent().item) end)
        r.go:SetPoint("LEFT", 536, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if button == "RightButton" then
                W.Menu(self, Map.PlaceMenu(e))
            elseif IsShiftKeyDown and IsShiftKeyDown() then
                ns.MapShowOnWorldMap(e.point)
            else
                go(e)
            end
        end)
        r:SetScript("OnEnter", function(self) if self.item then Map.PlaceTooltip(self, self.item, ROW_HINT) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, fillRow)
    f.list:SetPoint("TOPLEFT", 0, -92)
    f.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -92)
    f.empty = W.Text(f, T.FONT.hint, 590, true)
    f.empty:SetPoint("TOPLEFT", 6, -100)
    f.empty:Hide()

    f.hint = W.Text(f, T.FONT.hint, 598)
    f.hint:SetPoint("TOPLEFT", 4, -390)
    f.hint:SetText("Klick auf eine Zeile: Ziel setzen. Shift-Klick: auf der Weltkarte zeigen.")
    f.data = W.Text(f, T.FONT.hint, 598)
    f.data:SetPoint("TOPLEFT", 4, -408)
    f.showHidden = W.Button(f, "Ausgeblendete zeigen", 170, function()
        wipe(hiddenSet())
        ns.Fire("MAP_TARGET")
        ns.Refresh()
    end)
    f.showHidden:SetPoint("TOPRIGHT", 0, -428)
    f.showHidden:Hide()

    -- the target line's distance follows the player while the page shows
    f.wait = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.wait = (self.wait or 0) + (elapsed or 0)
        if self.wait < TICK - 1e-9 then return end
        self.wait = 0
        if ns.MapTarget() then self.target:SetText(targetText()) end
    end)
    return f
end

ns.RegisterPanel{ key = "map", label = "Karte", icon = ICON, order = 55, group = "gear",
    available = function() return Gear.Available() and ns.HasData("MAP") end,
    create = create, refresh = refresh }

-- Opens the page; zone: a uiMapID to show, "hier"/"here" for the own zone, nil for the last choice.
function ns.ShowMap(zone)
    if AmisiaDB and AmisiaDB.settings then
        local z = tonumber(zone)
        if z then
            state().zone = z
        elseif zone == "hier" or zone == "here" then
            state().zone = nil
        end
    end
    if ns.ShowPage then ns.ShowPage("map") end
end

---------------------------------------------------------------------------
-- Changes: rebuilt while the page shows, at most once a second
---------------------------------------------------------------------------

local function shown()
    return page ~= nil and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "map"
end

local due, lastAt = false, nil
local function schedule()
    if due or not shown() then return end
    due = true
    local now = GetTime and GetTime() or 0
    local wait = lastAt and math.max(0, GAP - (now - lastAt)) or 0
    C_Timer.After(wait, function()
        due = false
        if not shown() then return end
        lastAt = GetTime and GetTime() or 0
        ns.Refresh()
    end)
end

ns.Listen("BIS_CHANGED", schedule)
ns.Listen("MAP_TARGET", function()
    version = version + 1
    schedule()
end)
ns.BisOnOwned(schedule)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function()
    if not chosenZone() then schedule() end
end)

-- Item names the client did not have at the last fill: once item data arrives the shown rows are
-- filled again, once for a burst of answers.
local namesDue = false
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if not nameMissing or namesDue or not shown() then return end
    namesDue = true
    C_Timer.After(0.3, function()
        namesDue = false
        if not nameMissing or not shown() then return end
        ns.Refresh()
    end)
end)
