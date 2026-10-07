-- Amisia map pins: the places of the own upgrades ("Ziele") and wishes on the world map, on zone and
-- continent maps, through the map canvas's data provider interface (WorldMapFrame:AddDataProvider,
-- AcquirePin with Amisia's own template from MapPin.xml). The provider only acquires and releases
-- its own pins: it writes into none of the map's tables, hooks none of its methods and touches no
-- other frame of the map. Pins are display only; a click sets Amisia's target. The quest givers of a
-- dungeon marked from the dungeon planner (ns.DungeonMarkPlaces) get pins with the client's quest icon.
local ADDON, ns = ...
local Gear, Map, W = ns.Gear, ns.Map, ns.W

local TEMPLATE = "AmisiaMapPinTemplate"
local MAX_PINS = 60
local DOT = "Interface\\AddOns\\Amisia\\Media\\Icons\\dot"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- the quest giver marks: the client's quest icon of its map legend, else the classic gossip icon
local QUEST_ATLAS, QUEST_ICON = "QuestNormal", "Interface\\GossipFrame\\AvailableQuestIcon"
local MAX_MARKS = 40
-- the texts of the quest giver marks, in one place for the translation
local TEXT = { setTarget = "Ziel setzen", clearMarks = "Markierung der Questgeber entfernen",
    hint = "Klick: Ziel setzen. Rechtsklick: mehr." }
-- frame level types the world map defines (Blizzard_WorldMap); an unknown type would fall back to
-- the canvas default
local LEVEL, TARGET_LEVEL = "PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST"
local MAP_TYPE = Enum and Enum.UIMapType
local ZONE = MAP_TYPE and MAP_TYPE.Zone or 3
local CONTINENT = MAP_TYPE and MAP_TYPE.Continent or 2
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local GOLD = W.GOLD
local GREEN = { 0.3, 0.85, 0.3 }

local function itemInfo(x)
    local f = C_Item and C_Item.GetItemInfo
    if f then return f(x) end
    return nil
end
local function itemIcon(id)
    local f = C_Item and C_Item.GetItemIconByID
    if not f then return nil end
    local ok, icon = pcall(f, id)
    return ok and ns.Plain(icon) or nil
end
local function itemText(id)
    local name, _, q = itemInfo(id)
    local row = Gear.Item(id)
    q = q or (row and (row[5] or 0) > 0 and row[5]) or 1
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or ("Item " .. tostring(id)))
end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

---------------------------------------------------------------------------
-- Which places: targets and wishes with a place on the shown map
---------------------------------------------------------------------------

local function rank(e)
    return (e.wish and (1000000 + (e.prio or 0) * 100000) or 0) + (e.gain or 0)
end

-- The items the pins stand for: { id, gain, slot (target), wish, prio, wishSlot }, best first.
-- Targets: options 1-3 of a slot that are an upgrade and not owned; wishes: not owned.
local function wantedItems()
    local items, order = {}, {}
    local function add(id)
        local e = items[id]
        if not e then
            e = { id = id }
            items[id] = e
            order[#order + 1] = e
        end
        return e
    end
    if ns.Get("map.pinsTargets") and Gear.Available() then
        local r = ns.BisTargets()
        for _, sl in ipairs(Gear.SLOTS) do
            for _, o in ipairs(r[sl.key] or {}) do
                if o.upgrade and not o.owned then
                    local e = add(o.id)
                    if not e.gain or (o.gain or 0) > e.gain then e.gain, e.slot = o.gain or 0, sl.key end
                end
            end
        end
    end
    if ns.Get("map.pinsWishes") then
        for _, w in ipairs(ns.Wishes()) do
            if not w.owned then
                local e = add(w.id)
                e.wish, e.prio, e.wishSlot = true, w.e and w.e.prio or 2, w.slotKey
            end
        end
    end
    table.sort(order, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra ~= rb then return ra > rb end
        return a.id < b.id
    end)
    return order
end
-- For the map page: the same items, by the same switches.
Map.WantedItems = wantedItems

local rects = {}   -- [continent][zone] = { left, right, top, bottom } or false; fixed per session
local function rectOn(zone, continent)
    local byZone = rects[continent]
    if not byZone then
        byZone = {}
        rects[continent] = byZone
    end
    local r = byZone[zone]
    if r == nil then
        r = false
        if C_Map and C_Map.GetMapRectOnMap then
            local ok, l, rt, t, b = pcall(C_Map.GetMapRectOnMap, zone, continent)
            l, rt, t, b = ns.Plain(l), ns.Plain(rt), ns.Plain(t), ns.Plain(b)
            if ok and type(l) == "number" and type(rt) == "number" and type(t) == "number" and type(b) == "number"
                and rt > l and b > t then
                r = { l, rt, t, b }
            end
        end
        byZone[zone] = r
    end
    return r or nil
end

-- Where a point { map, x, y } lies on the shown map: x, y (0-1) or nil.
local function project(point, mapID, kind)
    if kind == ZONE then
        if point.map == mapID then return point.x, point.y end
        return nil
    end
    local r = rectOn(point.map, mapID)
    if not r then return nil end
    local x, y = r[1] + point.x * (r[2] - r[1]), r[3] + point.y * (r[4] - r[3])
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end

local function mapKind(mapID)
    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    return ok and type(info) == "table" and ns.Plain(info.mapType) or nil
end

local function samePoint(a, b)
    return a.map == b.map and math.abs(a.x - b.x) <= 0.001 and math.abs(a.y - b.y) <= 0.001
end

-- The marked quest givers on the shown map: spots { key, mark, giver, label, quests, point, x, y }.
local function markSpots(mapID, kind, continent)
    local out = {}
    if not ns.DungeonMarkPlaces then return out end
    for _, place in ipairs(ns.DungeonMarkPlaces()) do
        for _, pt in ipairs(place.points) do
            local x, y = project(pt, mapID, kind)
            if x and #out < MAX_MARKS then
                out[#out + 1] = { key = place.key, mark = true, giver = place.giver, label = place.label, quests = place.quests,
                    point = pt, x = x, y = y, items = {}, continent = continent }
            end
        end
    end
    return out
end

local function build(mapID)
    local kind = mapKind(mapID)
    if kind ~= ZONE and kind ~= CONTINENT then return {} end
    if kind == CONTINENT and not ns.Get("map.pinsContinent") then return {} end
    local continent = kind == CONTINENT
    local out, spots = {}, {}
    local m = AmisiaDB and AmisiaDB.map
    local hidden = m and type(m.hidden) == "table" and m.hidden or {}
    if ns.Get("map.pins") then
        -- items come best first, so every spot's first item is its best and the spots come in
        -- the order of their best item
        for _, e in ipairs(wantedItems()) do
            for _, place in ipairs(ns.MapItemPlaces(e.id)) do
                if not hidden[place.key] then
                    for _, pt in ipairs(place.points) do
                        local x, y = project(pt, mapID, kind)
                        if x then
                            local sk = ("%s@%d:%d"):format(place.key, math.floor(x * 200 + 0.5), math.floor(y * 200 + 0.5))
                            local spot = spots[sk]
                            if not spot then
                                spot = { key = place.key, rec = place.rec, giver = place.giver, point = pt, x = x, y = y,
                                    items = {}, has = {}, continent = continent }
                                spots[sk] = spot
                                out[#out + 1] = spot
                            end
                            if not spot.has[e.id] then
                                spot.has[e.id] = true
                                spot.items[#spot.items + 1] = e
                            end
                        end
                    end
                end
            end
        end
    end
    local marks = markSpots(mapID, kind, continent)
    -- the target: its spot is highlighted (kept even past the limit), else a pin of its own
    local t = ns.MapTarget()
    local late, extra       -- the target's spot past the limit, or a pin of its own
    if t then
        local x, y = project(t, mapID, kind)
        if x then
            local at
            for i, s in ipairs(out) do
                if s.key == t.key and samePoint(s.point, t) then
                    s.target, at = true, i
                    break
                end
            end
            if not at then
                for _, s in ipairs(marks) do
                    if s.key == t.key and samePoint(s.point, t) then
                        s.target, at = true, 0
                        break
                    end
                end
            end
            if not at then
                extra = { key = t.key, label = t.label, point = { map = t.map, x = t.x, y = t.y }, x = x, y = y,
                    items = t.item and { { id = t.item } } or {}, continent = continent, target = true }
            elseif at > MAX_PINS then
                late = out[at]
            end
        end
    end
    for i = #out, MAX_PINS + 1, -1 do out[i] = nil end
    for _, s in ipairs(marks) do out[#out + 1] = s end
    out[#out + 1] = late or extra
    return out
end

local cache, cacheStamp = {}, nil
local version = 0     -- bumped by the target, hidden places and the map settings

-- The pins of a map: { key, rec, giver, point (on its own zone), x, y (on this map), items, target,
-- continent }, at most 60 (plus the target), wishes first, then by gain. Kept until anything changes.
function Map.PinPlaces(mapID)
    mapID = tonumber(mapID)
    if not mapID or not ns.HasData("MAP") then return {} end
    local stamp = ns.BisStamp() .. ":" .. version .. ":" .. (ns.DungeonMarkStamp and ns.DungeonMarkStamp() or "")
    if stamp ~= cacheStamp then
        cache, cacheStamp = {}, stamp
    end
    local list = cache[mapID]
    if not list then
        list = build(mapID)
        cache[mapID] = list
    end
    return list
end

---------------------------------------------------------------------------
-- The pin (AmisiaMapPinMixin, used by the template in MapPin.xml)
---------------------------------------------------------------------------

AmisiaMapPinMixin = {}
local Pin = AmisiaMapPinMixin
local base   -- the client's MapCanvasPinMixin, once the provider is added

local function setTarget(e)
    local best = e.items[1]
    return ns.MapSetPoint(e.point, e.label or Map.LabelOf(e), e.key, best and best.id)
end

-- Shift: the place into the chat input; on Forever the client's waypoint link, else as text.
local function insertPlace(e)
    local insert = ChatFrameUtil and ChatFrameUtil.InsertLink
    if not insert then return end
    local t = ns.MapTarget()
    if t and t.ours and C_Map and C_Map.GetUserWaypointHyperlink then
        local ok, link = pcall(C_Map.GetUserWaypointHyperlink)
        link = ok and ns.Plain(link) or nil
        if type(link) == "string" and link ~= "" then
            insert(link)
            return
        end
    end
    local name = e.rec and Map.PlaceName(e) or e.label or "?"
    insert(("%s %s %s"):format(name, Map.ZoneName(e.point.map), Map.Coords(e.point)))
end

-- The menu of a place (a pin, a row of the map page); a hidden place offers to show it again.
local function placeMenu(e)
    if e.mark then
        return { { TEXT.setTarget, function() setTarget(e) end },
            { TEXT.clearMarks, function() if ns.DungeonClearMarks then ns.DungeonClearMarks() end end } }
    end
    local entries = {
        { "Ziel setzen", function() setTarget(e) end },
        { "Item auf der Seite zeigen", function()
            local best = e.items[1]
            if best and ns.ShowGear then ns.ShowGear(best.wish and "wish" or "goals", best.slot or best.wishSlot) end
        end },
    }
    if e.key then
        local m = AmisiaDB and AmisiaDB.map
        local hidden = m and type(m.hidden) == "table" and m.hidden[e.key] or false
        entries[#entries + 1] = { hidden and "Wieder einblenden" or "Diesen Ort ausblenden", function()
            local mm = AmisiaDB and AmisiaDB.map
            if mm and type(mm.hidden) == "table" then
                mm.hidden[e.key] = (not hidden) or nil
                ns.Fire("MAP_TARGET")
            end
        end }
    end
    entries[#entries + 1] = { "Alle Pins aus", function() ns.Set("map.pins", false) end }
    return entries
end

local function pinMenu(self)
    local e = self.entry
    if not e then return end
    W.Menu(self, placeMenu(e))
end

local function click(self, button)
    local e = self.entry
    if not e then return end
    if button == "RightButton" then
        pinMenu(self)
    elseif button == "LeftButton" then
        setTarget(e)
        if IsShiftKeyDown and IsShiftKeyDown() then insertPlace(e) end
    end
end

-- The tooltip of a place at owner: the source, the coordinates, every item with its gain or wish,
-- and the hint (the pin's by default).
local function placeTooltip(owner, e, hint)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if e.mark then
        -- a marked quest giver: who, where, the quests to take there
        GameTooltip:AddLine(e.label or e.giver or "?", 1, 0.82, 0)
        if e.target then GameTooltip:AddLine("Aktuelles Ziel", GOLD[1], GOLD[2], GOLD[3]) end
        GameTooltip:AddLine(("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point)), 0.7, 0.7, 0.7)
        for _, title in ipairs(e.quests or {}) do GameTooltip:AddLine(title, 1, 1, 1, true) end
        GameTooltip:AddLine(hint or TEXT.hint, 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    local title
    if e.rec then
        title = Gear.SourceText(e.rec, true)
        if e.rec[1] == "Q" and e.giver then title = title .. " · " .. e.giver end
    else
        title = e.label or "?"
    end
    GameTooltip:AddLine(title, 1, 0.82, 0)
    if e.target then GameTooltip:AddLine("Aktuelles Ziel", GOLD[1], GOLD[2], GOLD[3]) end
    GameTooltip:AddLine(("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point)), 0.7, 0.7, 0.7)
    for _, it in ipairs(e.items) do
        local right, color = "", GREEN
        if it.wish then
            right, color = ("Wunsch (%s)"):format((ns.BIS_PRIO_TEXT or {})[it.prio] or "mittel"), GOLD
        elseif it.gain then
            right = ("%+d (%s)"):format(math.floor(it.gain + 0.5), (ns.BIS_SLOT_NAME or {})[it.slot] or "?")
        end
        GameTooltip:AddDoubleLine(itemText(it.id), right, 1, 1, 1, color[1], color[2], color[3])
    end
    GameTooltip:AddLine(hint or "Klick: Ziel setzen. Rechtsklick: mehr.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function tooltip(self)
    local e = self.entry
    if not e then return end
    placeTooltip(self, e)
end

-- For the map page: a place's target, menu entries and tooltip, as on the pin.
Map.SetPlaceTarget, Map.PlaceMenu, Map.PlaceTooltip = setTarget, placeMenu, placeTooltip

function Pin:OnLoad()
    self:SetSize(20, 20)
    self.ring = self:CreateTexture(nil, "BACKGROUND")
    self.ring:SetSize(24, 24)
    self.ring:SetPoint("CENTER")
    self.ring:SetTexture(DOT)
    self.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    self.icon = self:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(18, 18)
    self.icon:SetPoint("CENTER")
    self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.edges = W.Border(self, GREEN[1], GREEN[2], GREEN[3], 1)
    self.count = W.Text(self, "GameFontHighlightSmall")
    self.count:SetPoint("BOTTOMRIGHT", 4, -3)
end

-- entry: one of Map.PinPlaces; scale: map.pinScale (and 70 % on a continent).
function Pin:OnAcquired(entry, scale)
    self.entry = entry
    scale = scale or 1
    self:UseFrameLevelType(entry.target and TARGET_LEVEL or LEVEL)
    self:SetScalingLimits(1, scale, 1.6 * scale)
    self:SetPosition(entry.x, entry.y)
    if self.ApplyCurrentScale then self:ApplyCurrentScale() end
    local best = entry.items[1]
    -- pins are pooled: the icon and its coordinates are set every time
    if entry.mark and W.HasAtlas(QUEST_ATLAS) then
        self.icon:SetAtlas(QUEST_ATLAS)
    elseif entry.mark then
        self.icon:SetTexture(QUEST_ICON)
        self.icon:SetTexCoord(0, 1, 0, 1)
    else
        self.icon:SetTexture(best and itemIcon(best.id) or QUESTION)
        self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local wish = entry.mark or false
    for _, it in ipairs(entry.items) do
        if it.wish then wish = true end
    end
    local c = wish and GOLD or GREEN
    W.SetBorderColor(self.edges, c[1], c[2], c[3], 1)
    self.ring:SetShown(entry.target and true or false)
    local count = entry.mark and #(entry.quests or {}) or #entry.items
    if count > 1 then
        self.count:SetText(tostring(count))
        self.count:Show()
    else
        self.count:Hide()
    end
end

function Pin:OnReleased()
    self.entry = nil
    if base and base.OnReleased then base.OnReleased(self) end
end

function Pin:OnMouseEnter()
    local ok, err = pcall(tooltip, self)
    if not ok then report(err) end
end

function Pin:OnMouseLeave()
    GameTooltip:Hide()
end

-- Forever: right clicks would pass through to the map (zoom out); this pin keeps them for its menu.
-- AcquirePin asks CheckMouseButtonPassthrough, whose base calls SetPassThroughButtons, a function
-- the client restricts in combat; a fresh frame passes nothing through and these pins never ask
-- for it, so the check does nothing here and the restricted call never comes from Amisia's refresh.
function Pin:ShouldMouseButtonBePassthrough()
    return false
end
function Pin:CheckMouseButtonPassthrough() end

-- Forever's base OnClick runs the map's own click handlers and then this.
Pin.OnMouseClickAction = click

-- Completes the mixin with the client's pin mixin, once; the own methods stay. Where the base
-- OnClick is the empty one to override (a pin mixin without the passthrough buttons), the click
-- goes there.
local function fillMixin(pinBase)
    if base then return end
    base = pinBase
    if pinBase.CheckMouseButtonPassthrough == nil then Pin.OnClick = click end
    for k, v in pairs(pinBase) do
        if Pin[k] == nil then Pin[k] = v end
    end
end

---------------------------------------------------------------------------
-- The data provider
---------------------------------------------------------------------------

local Provider = {}
local provider
local refreshes = 0

function Provider:RemoveAllData()
    local map = self:GetMap()
    if map then map:RemoveAllPinsByTemplate(TEMPLATE) end
end

-- Builds the list first; on an error no pin stays and the error goes to the error handler.
function Provider:RefreshAllData()
    refreshes = refreshes + 1
    local map = self:GetMap()
    if not map then return end
    local ok, err = pcall(function()
        local list = map:IsShown() and Map.PinPlaces(ns.Plain(map:GetMapID())) or {}
        map:RemoveAllPinsByTemplate(TEMPLATE)
        local scale = (tonumber(ns.Get("map.pinScale")) or 100) / 100
        for _, e in ipairs(list) do
            map:AcquirePin(TEMPLATE, e, e.continent and scale * 0.7 or scale)
        end
    end)
    if not ok then
        pcall(map.RemoveAllPinsByTemplate, map, TEMPLATE)
        report(err)
    end
end

function Map.PinProvider() return provider end
function Map.PinRefreshes() return refreshes end

-- Adds the provider once the world map and the canvas mixins exist; without them there are no pins.
local function register()
    if provider then return true end
    local map = _G.WorldMapFrame
    if type(map) ~= "table" or type(map.AddDataProvider) ~= "function" or type(map.AcquirePin) ~= "function"
        or type(map.RemoveAllPinsByTemplate) ~= "function" then
        return false
    end
    if type(MapCanvasDataProviderMixin) ~= "table" or type(MapCanvasPinMixin) ~= "table" or type(CreateFromMixins) ~= "function" then
        return false
    end
    fillMixin(MapCanvasPinMixin)
    local p = CreateFromMixins(MapCanvasDataProviderMixin, Provider)
    local ok, err = pcall(map.AddDataProvider, map, p)
    if not ok then
        report(err)
        return false
    end
    provider = p
    return true
end
ns.OnEvent("PLAYER_LOGIN", register)
ns.OnEvent("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then register() end
end)

-- A change refreshes the pins half a second later, only while the world map shows.
local pending = false
local function schedule()
    if pending or not provider then return end
    local map = provider:GetMap()
    if not (map and map:IsShown()) then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        local m = provider and provider:GetMap()
        if m and m:IsShown() then provider:RefreshAllData() end
    end)
end

ns.Listen("BIS_CHANGED", schedule)
ns.Listen("MAP_MARKS", function()
    version = version + 1
    schedule()
end)
ns.Listen("MAP_TARGET", function()
    version = version + 1
    schedule()
end)
ns.Listen("SETTING", function(path)
    if type(path) == "string" and (path:sub(1, 4) == "map." or path:sub(1, 4) == "bis.") then
        version = version + 1
        schedule()
    end
end)
ns.BisOnOwned(schedule)
