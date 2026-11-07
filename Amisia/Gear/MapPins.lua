-- Amisia map pins: the places of the own upgrades ("Ziele") and wishes on the world map, on zone and
-- continent maps. They stand on Amisia's own layer: one frame of Amisia's, a child of the map canvas
-- (WorldMapFrame.ScrollContainer.Child), with Amisia's own buttons as pins. No data provider of the
-- map, no pin or pin pool of the canvas, no hook, no call of a map method that changes anything and
-- no write into any table of the map (each of those ran Amisia's code inside the map's secure
-- refresh and tainted the client's own pins after it): the layer only reads the shown map and the
-- canvas's size and scale in its own OnUpdate, which runs only while the map shows. The place pins of
-- MapPlaces.lua stand on the same layer. Pins are display only; a click sets Amisia's target. The
-- quest givers of a dungeon marked from the dungeon planner (ns.DungeonMarkPlaces) get pins with the
-- client's quest icon, and so do the next steps of the open dungeon quests (ns.DungeonQuestSteps,
-- map.pinsQuests).
local ADDON, ns = ...
local Gear, Map, W = ns.Gear, ns.Map, ns.W
local L = ns.L

local MAX_PINS = 60
local DOT = "Interface\\AddOns\\Amisia\\Media\\Icons\\dot"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- the quest giver marks: the plain yellow "!" of the gossip window, without a frame (the map legend's
-- quest atlas is a diamond on Forever)
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
-- a target without an item: a quest giver ("Q:") gets the "!", a dungeon entrance ("I:", "N:") the map
-- legend's dungeon mark; neither gets the frame or the ring
local DUNGEON_ATLAS = "Dungeon"
local MAX_MARKS = 40
-- the texts of the quest giver marks, in one place for the translation
local TEXT = { setTarget = L["Ziel setzen"], clearMarks = L["Markierung der Questgeber entfernen"],
    hint = L["Klick: Ziel setzen. Rechtsklick: mehr."], stepFor = L["%s (für %s)"], showPath = L["Questweg zeigen"],
    stepsOff = L["Quest-Schritte ausblenden"], turnIn = L["abgeben"] }
-- the layer's frame level above the canvas: above the map's area markers and quest areas, about
-- where its quest marks stand (the world map reserves some 300 levels for its own pin types); in the
-- layer the place pins, then the item and quest giver pins, the target on top
local LAYER_LEVEL = 300
local LEVEL = { place = 1, item = 2, target = 3 }
-- the pins grow with the zoom like the map's own did, up to 1.6 times; 70 % on a continent
local GROW, CONTINENT_SCALE = 0.6, 0.7
local MAP_TYPE = Enum and Enum.UIMapType
local ZONE = MAP_TYPE and MAP_TYPE.Zone or 3
local CONTINENT = MAP_TYPE and MAP_TYPE.Continent or 2
local QUALITY = ns.Theme.QUALITY_HEX
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

local report = ns.ReportError

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

-- For the place pins (MapPlaces.lua): the same projection and map kinds.
Map.ProjectPoint, Map.MapKindOf = project, mapKind

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

-- Whether the quest steps show (map.pins and map.pinsQuests).
local function stepsOn() return ns.Get("map.pins") and ns.Get("map.pinsQuests") and ns.DungeonQuestSteps ~= nil end

-- The next quest steps on the shown map: spots { key, step, label, point, x, y, items, ... } (the
-- step's own fields), not the hidden ones, at most MAX_MARKS.
local function stepSpots(mapID, kind, continent, hidden)
    local out = {}
    if not stepsOn() then return out end
    for _, place in ipairs(ns.DungeonQuestSteps()) do
        if not hidden[place.key] then
            local x, y = project(place.point, mapID, kind)
            if x and #out < MAX_MARKS then
                local spot = { x = x, y = y, continent = continent }
                for k, v in pairs(place) do spot[k] = v end
                out[#out + 1] = spot
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
    for _, s in ipairs(stepSpots(mapID, kind, continent, hidden)) do marks[#marks + 1] = s end
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
        .. ":" .. (stepsOn() and ns.DungeonQuestStepsStamp() or "")
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
-- The target pins: what they do
---------------------------------------------------------------------------

local function setTarget(e)
    -- a quest step: its giver or turn-in, without an item (the rewards are the dungeon quest's)
    if e.step then return ns.MapSetPoint(e.point, e.label, e.key) end
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

-- The menu entry that hides a place's pins or shows them again (AmisiaDB.map.hidden).
local function hideEntry(e)
    local m = AmisiaDB and AmisiaDB.map
    local hidden = m and type(m.hidden) == "table" and m.hidden[e.key] or false
    return { hidden and L["Wieder einblenden"] or L["Diesen Ort ausblenden"], function()
        local mm = AmisiaDB and AmisiaDB.map
        if mm and type(mm.hidden) == "table" then
            mm.hidden[e.key] = (not hidden) or nil
            ns.Fire("MAP_TARGET")
        end
    end }
end

-- The menu of a place (a pin, a row of the map page); a hidden place offers to show it again.
local function placeMenu(e)
    if e.mark then
        return { { TEXT.setTarget, function() setTarget(e) end },
            { TEXT.clearMarks, function() if ns.DungeonClearMarks then ns.DungeonClearMarks() end end } }
    end
    if e.step then
        local q = e.quests and e.quests[1]
        return { { TEXT.setTarget, function() setTarget(e) end },
            { TEXT.showPath, function() if q and ns.ShowDungeonQuest then ns.ShowDungeonQuest(q.dkey, q.qid) end end },
            hideEntry(e),
            { TEXT.stepsOff, function() ns.Set("map.pinsQuests", false) end } }
    end
    local entries = {
        { TEXT.setTarget, function() setTarget(e) end },
        { L["Item auf der Seite zeigen"], function()
            local best = e.items[1]
            if best and ns.ShowGear then ns.ShowGear(best.wish and "wish" or "goals", best.slot or best.wishSlot) end
        end },
    }
    if e.key then entries[#entries + 1] = hideEntry(e) end
    entries[#entries + 1] = { L["Alle Pins aus"], function() ns.Set("map.pins", false) end }
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
        if e.target then GameTooltip:AddLine(L["Aktuelles Ziel"], GOLD[1], GOLD[2], GOLD[3]) end
        GameTooltip:AddLine(("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point)), 0.7, 0.7, 0.7)
        for _, title in ipairs(e.quests or {}) do GameTooltip:AddLine(title, 1, 1, 1, true) end
        GameTooltip:AddLine(hint or TEXT.hint, 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    if e.step then
        -- a quest step: who and where, the step's quest (and what it is for), the dungeon quests' upgrades
        GameTooltip:AddLine(e.label or "?", 1, 0.82, 0)
        if e.target then GameTooltip:AddLine(L["Aktuelles Ziel"], GOLD[1], GOLD[2], GOLD[3]) end
        GameTooltip:AddLine(("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point)), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(Map.StepText(e), 1, 1, 1, true)
        for _, it in ipairs(e.items) do
            GameTooltip:AddDoubleLine(itemText(it.id), ("%+d (%s)"):format(math.floor((it.gain or 0) + 0.5),
                (ns.BIS_SLOT_NAME or {})[it.slot] or "?"), 1, 1, 1, GREEN[1], GREEN[2], GREEN[3])
        end
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
    if e.target then GameTooltip:AddLine(L["Aktuelles Ziel"], GOLD[1], GOLD[2], GOLD[3]) end
    GameTooltip:AddLine(("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point)), 0.7, 0.7, 0.7)
    for _, it in ipairs(e.items) do
        local right, color = "", GREEN
        if it.wish then
            right, color = (L["Wunsch (%s)"]):format((ns.BIS_PRIO_TEXT or {})[it.prio] or L["mittel"]), GOLD
        elseif it.gain then
            right = ("%+d (%s)"):format(math.floor(it.gain + 0.5), (ns.BIS_SLOT_NAME or {})[it.slot] or "?")
        end
        GameTooltip:AddDoubleLine(itemText(it.id), right, 1, 1, 1, color[1], color[2], color[3])
    end
    GameTooltip:AddLine(hint or TEXT.hint, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function tooltip(self)
    local e = self.entry
    if not e then return end
    placeTooltip(self, e)
end

-- A quest step as text: "<step quest> (für <dungeon quest>, ...)", "abgeben" for a turn-in.
function Map.StepText(e)
    local title = e.turnIn and (e.title .. " " .. TEXT.turnIn) or e.title
    if e.fors and #e.fors > 0 then return TEXT.stepFor:format(title, table.concat(e.fors, ", ")) end
    return title
end

-- For the map page: a place's target, menu entries and tooltip, as on the pin.
Map.SetPlaceTarget, Map.PlaceMenu, Map.PlaceTooltip = setTarget, placeMenu, placeTooltip

-- The parts of a target pin, made once.
local function setupPin(pin)
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetSize(24, 24)
    pin.ring:SetPoint("CENTER")
    pin.ring:SetTexture(DOT)
    pin.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetSize(18, 18)
    pin.icon:SetPoint("CENTER")
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin.edges = W.Border(pin, GREEN[1], GREEN[2], GREEN[3], 1)
    pin.count = W.Text(pin, "GameFontHighlightSmall")
    pin.count:SetPoint("BOTTOMRIGHT", 4, -3)
end

-- What a target pin shows for entry (one of Map.PinPlaces); returns the pin's size. Pins are used
-- again for other places: the icon and its coordinates are set every time.
local function showPin(pin, entry)
    local best = entry.items[1]
    local key = not best and type(entry.key) == "string" and entry.key:sub(1, 2) or nil
    local quest = entry.mark or entry.step or key == "Q:"
    local bare = quest
    if quest then
        pin.icon:SetTexture(QUEST_ICON)
        pin.icon:SetTexCoord(0, 1, 0, 1)
        pin.icon:SetSize(22, 22)
    elseif (key == "I:" or key == "N:") and W.HasAtlas(DUNGEON_ATLAS) then
        pin.icon:SetAtlas(DUNGEON_ATLAS)
        pin.icon:SetSize(22, 22)
        bare = true
    else
        pin.icon:SetTexture(best and itemIcon(best.id) or QUESTION)
        pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        pin.icon:SetSize(18, 18)
    end
    for _, t in ipairs(pin.edges) do t:SetShown(not bare) end
    local wish = entry.mark or entry.step or false
    for _, it in ipairs(entry.items) do
        if it.wish then wish = true end
    end
    local c = wish and GOLD or GREEN
    W.SetBorderColor(pin.edges, c[1], c[2], c[3], 1)
    pin.ring:SetShown(entry.target and not bare or false)
    local count = entry.mark and #(entry.quests or {}) or (not entry.step and #entry.items) or 0
    if count > 1 then
        pin.count:SetText(tostring(count))
        pin.count:Show()
    else
        pin.count:Hide()
    end
    return 20, 20
end

local function enter(pin)
    local ok, err = pcall(tooltip, pin)
    if not ok then report(err) end
end

---------------------------------------------------------------------------
-- Amisia's layer on the world map
---------------------------------------------------------------------------

-- The kinds of pins on the layer: { setup(pin), show(pin, entry) -> w, h, click(pin, button),
-- enter(pin), list(mapID) }. MapPlaces.lua adds "place" while loading; it is drawn first.
local KINDS, ORDER = {}, {}
function Map.RegisterPinKind(name, kind)
    if not KINDS[name] then
        if name == "place" then table.insert(ORDER, 1, name) else ORDER[#ORDER + 1] = name end
    end
    KINDS[name] = kind
end
Map.RegisterPinKind("item", { setup = setupPin, show = showPin, click = click, enter = enter, list = Map.PinPlaces })

local layer, canvas
local pools = {}          -- kind -> its buttons, used from the first
local seen = {}           -- what the last redraw and layout read: map, w, h, scale
local due                 -- GetTime() after which a change of Amisia's data redraws, or nil
local now = false         -- redraw on the next frame (the map came up)
local refreshes = 0

local function onClick(pin, button)
    local k = KINDS[pin.kind]
    if k and pin.entry then k.click(pin, button) end
end
local function onEnter(pin)
    local k = KINDS[pin.kind]
    if k and pin.entry then k.enter(pin) end
end
local function onLeave()
    GameTooltip:Hide()
end

local function pinOf(kind, i)
    local pool = pools[kind]
    if not pool then
        pool = {}
        pools[kind] = pool
    end
    local pin = pool[i]
    if not pin then
        pin = CreateFrame("Button", nil, layer)
        pin.kind = kind
        pin:EnableMouse(true)
        pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        pin:SetScript("OnClick", onClick)
        pin:SetScript("OnEnter", onEnter)
        pin:SetScript("OnLeave", onLeave)
        KINDS[kind].setup(pin)
        pool[i] = pin
    end
    return pin
end

-- Hides the pins of a kind from the index from on.
local function release(kind, from)
    local pool = pools[kind] or {}
    for i = from, #pool do
        local pin = pool[i]
        if pin.entry then
            pin.entry = nil
            pin:Hide()
        end
    end
end

-- How far the map is zoomed in, 0 to 1 (a read only call; 0 where the client lacks it).
local function zoomOf()
    local map = _G.WorldMapFrame
    local fn = type(map) == "table" and map.GetCanvasZoomPercent
    if type(fn) ~= "function" then return 0 end
    local ok, z = pcall(fn, map)
    z = ok and ns.Plain(z) or nil
    if type(z) ~= "number" then return 0 end
    return math.max(0, math.min(1, z))
end

-- Where the pins stand and how large: normalized x, y times the canvas's size; the canvas's scale is
-- divided out, so a pin keeps its size on screen and grows only a little as the map zooms in
-- (map.pinScale, 70 % on a continent).
local function layout()
    local w, h, cs = canvas:GetWidth(), canvas:GetHeight(), canvas:GetScale()
    seen.w, seen.h, seen.scale = w, h, cs
    if not (type(w) == "number" and type(h) == "number" and type(cs) == "number" and cs > 0) then return end
    local base = (tonumber(ns.Get("map.pinScale")) or 100) / 100 * (1 + GROW * zoomOf()) / cs
    for _, name in ipairs(ORDER) do
        for _, pin in ipairs(pools[name] or {}) do
            local e = pin.entry
            if e then
                local s = base * (e.continent and CONTINENT_SCALE or 1)
                pin:SetScale(s)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", layer, "TOPLEFT", e.x * w / s, -e.y * h / s)
            end
        end
    end
end

-- Puts the pins of the shown map on the layer; on an error no pin stays and the error goes to the
-- error handler.
local function redraw(mapID)
    refreshes = refreshes + 1
    local ok, err = pcall(function()
        local top = layer:GetFrameLevel()
        for _, name in ipairs(ORDER) do
            local kind = KINDS[name]
            local list = mapID and kind.list(mapID) or {}
            for i, e in ipairs(list) do
                local pin = pinOf(name, i)
                pin.entry = e
                local w, h = kind.show(pin, e)
                pin:SetSize(w, h)
                pin:SetFrameLevel(top + (e.target and LEVEL.target or LEVEL[name] or LEVEL.item))
                pin:Show()
            end
            release(name, #list + 1)
        end
        layout()
    end)
    if not ok then
        for _, name in ipairs(ORDER) do release(name, 1) end
        report(err)
    end
end

-- Every frame while the map shows (the layer is hidden with it, and a hidden frame gets no
-- OnUpdate): reads the shown map and the canvas. A new map, the map coming up or a change of
-- Amisia's data (at most every half second) redraws; a zoom or a new size of the canvas only moves
-- the pins.
local function onUpdate()
    local id = tonumber(ns.Plain(_G.WorldMapFrame:GetMapID()))
    if id ~= seen.map or now or (due and GetTime() >= due) then
        seen.map, now, due = id, false, nil
        redraw(id)
    elseif canvas:GetWidth() ~= seen.w or canvas:GetHeight() ~= seen.h or canvas:GetScale() ~= seen.scale then
        layout()
    end
end

local function ownsTooltip()
    local owner = GameTooltip.GetOwner and GameTooltip:GetOwner()
    return type(owner) == "table" and owner.kind ~= nil and KINDS[owner.kind] ~= nil and owner.entry ~= nil
end

-- Makes the layer once the world map and its canvas exist; without them there are no pins. Only
-- frames of Amisia's own are made: the canvas gets a child, nothing of it is changed.
local function create()
    if layer then return true end
    local map = _G.WorldMapFrame
    local scroll = type(map) == "table" and map.ScrollContainer
    local child = type(scroll) == "table" and scroll.Child
    if type(child) ~= "table" or type(child.GetScale) ~= "function" or type(map.GetMapID) ~= "function" then
        return false
    end
    canvas = child
    layer = CreateFrame("Frame", nil, canvas)
    layer:SetAllPoints(canvas)
    -- the layer takes no mouse: a click beside a pin reaches the map
    layer:EnableMouse(false)
    layer:SetFrameLevel(canvas:GetFrameLevel() + LAYER_LEVEL)
    -- the scripts only mark: the work is done in the layer's own OnUpdate, never inside the map's
    -- show
    layer:SetScript("OnShow", function() now = true end)
    layer:SetScript("OnHide", function() if ownsTooltip() then GameTooltip:Hide() end end)
    layer:SetScript("OnUpdate", onUpdate)
    layer:Show()
    now = true
    return true
end
-- at login, else (a world map loaded later) on the next loading screen or change of Amisia's data
ns.OnEvent("PLAYER_LOGIN", create)
ns.OnEvent("PLAYER_ENTERING_WORLD", create)

-- For the tests and the self-test: the layer, the shown pins of a kind ("item", "place"), the
-- redraws so far.
function Map.PinLayer() return layer end
function Map.ShownPins(kind)
    local out = {}
    for _, pin in ipairs(pools[kind or "item"] or {}) do
        if pin.entry then out[#out + 1] = pin end
    end
    return out
end
function Map.PinRefreshes() return refreshes end

-- A change redraws half a second later, on a frame of the layer: only while the map shows. A change
-- of the own items alone (looting, sorting the bags) waits two seconds: each redraw costs ~20 ms.
local function scheduleIn(delay)
    if not layer then create() end
    local at = GetTime() + delay
    if not due or at < due then due = at end
end
local function schedule() scheduleIn(0.5) end
local function scheduleOwned() scheduleIn(2) end

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
    if type(path) == "string" and (path:sub(1, 4) == "map." or path:sub(1, 4) == "bis.") then   -- l10n-ok: setting key prefix
        version = version + 1
        schedule()
    end
end)
ns.BisOnOwned(scheduleOwned)
-- a quest taken, handed in or dropped moves the quest steps
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do ns.OnEvent(event, schedule) end
