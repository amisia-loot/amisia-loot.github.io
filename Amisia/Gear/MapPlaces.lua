-- Amisia's places on the world map (F-105): the entrances of the dungeons and raids, the flight
-- masters of the own faction and the neutral ones, the zeppelin towers and ship docks, from the
-- generated MapData.lua (P with the entrance keys, F, T). The pins come from the same data provider
-- as the target pins (MapPins.lua), with their own template (MapPin.xml): only own pins, no hook
-- into any map method. A click on an entrance opens that dungeon on the page Dungeons, shift sets the
-- target; a click on a flight master or a dock sets the target.
--
-- And the entrances Amisia learns (AmisiaDB.entrances): the last place outdoors, at most 20 s
-- before the loading screen into a dungeon or raid, by the instance's id (GetInstanceInfo); the N100
-- takes them into tools/entrance_archive.json and the shipped data with the next build.py data
-- (D-50). Nothing is sent to anybody.
local ADDON, ns = ...
local Map, W = ns.Map, ns.W
local L = ns.L

local TEMPLATE = "AmisiaMapPlaceTemplate"
local MAX_PLACES = 60
-- the client's dungeon and raid marks where the client has them, else plain icons; the flight
-- master is the taxi map's node, the docks plain icons (the client has no transport art for maps)
local ICON = {
    party = { atlas = "Dungeon", file = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
    raid = { atlas = "Raid", file = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    flight = { file = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
    Z = { file = "Interface\\Icons\\Spell_Nature_Cyclone" },
    S = { file = "Interface\\Icons\\INV_Misc_Spyglass_02" },
}
local SIZE = { entrance = 22, flight = 16, dock = 20 }
local GOLD = W.GOLD
local BORDER = { flight = { 0.55, 0.8, 1 }, dock = { 0.85, 0.85, 0.85 } }
local SIDE_TEXT = { A = L["Allianz"], H = L["Horde"], N = L["beide Fraktionen"] }
local TEXT = {
    entranceHint = L["Klick: in Amisia öffnen. Shift-Klick: Ziel setzen."],
    placeHint = L["Klick: Ziel setzen."],
    more = L["Rechtsklick: ausblenden."],
    open = L["In Amisia öffnen"], target = L["Ziel setzen"],
    offEntrances = L["Eingänge ausblenden"], offFlights = L["Flugmeister ausblenden"],
    offTransports = L["Zeppeline und Schiffe ausblenden"],
}
local MAP_TYPE = Enum and Enum.UIMapType
local ZONE = MAP_TYPE and MAP_TYPE.Zone or 3
local CONTINENT = MAP_TYPE and MAP_TYPE.Continent or 2

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

---------------------------------------------------------------------------
-- The places of the data
---------------------------------------------------------------------------

local built = {}    -- data table -> { entrances, flights, docks }

local function pt(m, x, y)
    -- through the map's parser, so a map the client does not know drops out as everywhere
    return Map.ParsePoints(("%d:%d:%d"):format(m, x, y))[1]
end

-- The entrances: one per map key (Lower and Upper Blackrock Spire share theirs), with the facts it
-- opens, its points, whether a raid is among them, and how sure the place is (E of the data).
local function entrancesOf(data, facts)
    local out, byKey = {}, {}
    for _, f in ipairs(facts or {}) do
        if type(f) == "table" and type(f.key) == "string" then
            local keys = {}
            if type(f.inst) == "number" then keys[#keys + 1] = "I:" .. f.inst end
            if f.name then keys[#keys + 1] = "N:" .. f.name end
            for _, a in ipairs(type(f.aliases) == "table" and f.aliases or {}) do keys[#keys + 1] = "N:" .. a end
            for _, k in ipairs(keys) do
                local points = ns.MapPoints(k)
                if #points > 0 then
                    local e = byKey[k]
                    if not e then
                        e = { kind = "entrance", key = k, facts = {}, points = points, raid = false,
                            how = type(data.E) == "table" and data.E[k] or nil }
                        byKey[k] = e
                        out[#out + 1] = e
                    end
                    e.facts[#e.facts + 1] = f
                    if f.kind == "raid" then e.raid = true end
                    break
                end
            end
        end
    end
    return out
end

local function flightsOf(data)
    local out = {}
    for _, r in ipairs(type(data.F) == "table" and data.F or {}) do
        if type(r) == "table" and type(r[1]) == "number" and type(r[5]) == "string" then
            local p = pt(r[1], r[2] or 0, r[3] or 0)
            if p then out[#out + 1] = { kind = "flight", point = p, side = r[4], name = r[5] } end
        end
    end
    return out
end

local function docksOf(data)
    local out = {}
    for _, r in ipairs(type(data.T) == "table" and data.T or {}) do
        if type(r) == "table" and type(r[1]) == "number" and (r[4] == "Z" or r[4] == "S") then
            local p = pt(r[1], r[2] or 0, r[3] or 0)
            local to = {}
            for _, d in ipairs(type(r[6]) == "table" and r[6] or {}) do
                if type(d) == "table" then to[#to + 1] = { area = d[1], name = d[2] } end
            end
            if p then out[#out + 1] = { kind = "dock", point = p, ship = r[4] == "S", side = r[5], to = to } end
        end
    end
    return out
end

-- { entrances, flights, docks } of the data, built once per data table and facts.
function Map.Places()
    local data = ns.HasData("MAP") and ns.Data("MAP") or nil
    if type(data) ~= "table" then return { entrances = {}, flights = {}, docks = {} } end
    local facts = ns.Dungeons and ns.Dungeons.Facts() or nil
    local b = built[data]
    if not b or b.facts ~= facts then
        b = { facts = facts, entrances = entrancesOf(data, facts), flights = flightsOf(data), docks = docksOf(data) }
        built = { [data] = b }
    end
    return b
end

-- The own faction as the data writes it (A, H), nil when the client tells none.
local function ownSide()
    local f = UnitFactionGroup and ns.Plain((UnitFactionGroup("player")))
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end
Map.OwnSide = ownSide

-- A place of side ("A", "H", "N" both) for a player of mine: neutral always, the own faction's,
-- every one when the faction is unknown.
function Map.SideOk(side, mine)
    return side ~= "A" and side ~= "H" or not mine or side == mine
end

---------------------------------------------------------------------------
-- The client's own pins: where its map already shows entrances or flight points, Amisia leaves
-- that kind out (no doubled pins)
---------------------------------------------------------------------------

local CLIENT = {
    entrance = { "C_EncounterJournal", "GetDungeonEntrancesForMap", "DungeonEntranceDataProviderMixin" },
    flight = { "C_TaxiMap", "GetTaxiNodesForMap", "FlightPointDataProviderMixin" },
}
local clientSeen = {}   -- kind -> { [mapID] = true/false }, per session

-- Whether the world map has the client's own data provider of the kind (read only: the map's list
-- of providers is looked at, nothing in it is touched).
local function clientProvider(kind)
    local mixin = _G[CLIENT[kind][3]]
    local map = _G.WorldMapFrame
    if type(mixin) ~= "table" or type(mixin.RefreshAllData) ~= "function" or type(map) ~= "table"
        or type(map.dataProviders) ~= "table" then
        return false
    end
    for p in pairs(map.dataProviders) do
        if type(p) == "table" and p.RefreshAllData == mixin.RefreshAllData then return true end
    end
    return false
end

-- Whether the client's own map shows that kind on the map: its data provider is on the world map and
-- the client's function returns entries for the map. Also the count (nil without the function) and
-- whether the provider is there.
function Map.ClientPlaces(kind, mapID)
    local c = CLIENT[kind]
    local t = c and _G[c[1]]
    local f = type(t) == "table" and t[c[2]]
    local provider = c and clientProvider(kind) or false
    if type(f) ~= "function" then return false, nil, provider end
    local ok, list = pcall(f, mapID)
    local n = ok and type(list) == "table" and #list or 0
    return n > 0 and provider, n, provider
end

local function clientShows(kind, mapID)
    local seen = clientSeen[kind]
    if not seen then
        seen = {}
        clientSeen[kind] = seen
    end
    if seen[mapID] == nil then seen[mapID] = Map.ClientPlaces(kind, mapID) and true or false end
    return seen[mapID]
end

---------------------------------------------------------------------------
-- The pins of a map
---------------------------------------------------------------------------

local function near(a, b) return math.abs(a.x - b.x) < 0.01 and math.abs(a.y - b.y) < 0.01 end

-- The place pins of a map: { kind, place, point, x, y, continent }, entrances first, then docks,
-- then flight masters, at most MAX_PLACES; one point of an entrance is left out where another of
-- the same entrance stands (its zone and its own outdoor map on the continent).
local function buildPins(mapID)
    local kind = Map.MapKindOf and Map.MapKindOf(mapID)
    if kind ~= ZONE and kind ~= CONTINENT then return {} end
    if kind == CONTINENT and not ns.Get("map.pinsContinent") then return {} end
    local continent = kind == CONTINENT
    local P = Map.Places()
    local out = {}
    local function add(k, place, point)
        if #out >= MAX_PLACES then return nil end
        local x, y = Map.ProjectPoint(point, mapID, kind)
        if not x then return nil end
        local e = { kind = k, place = place, point = point, x = x, y = y, continent = continent }
        out[#out + 1] = e
        return e
    end
    if ns.Get("map.entrances") and not clientShows("entrance", mapID) then
        for _, ent in ipairs(P.entrances) do
            local mine = {}
            for _, point in ipairs(ent.points) do
                local x, y = Map.ProjectPoint(point, mapID, kind)
                local dup = false
                if x then
                    for _, m in ipairs(mine) do if near(m, { x = x, y = y }) then dup = true end end
                end
                if x and not dup then
                    local e = add("entrance", ent, point)
                    if e then mine[#mine + 1] = e end
                end
            end
        end
    end
    local side = ownSide()
    if ns.Get("map.transports") then
        for _, d in ipairs(P.docks) do
            if Map.SideOk(d.side, side) then add("dock", d, d.point) end
        end
    end
    if ns.Get("map.flights") and not clientShows("flight", mapID) then
        for _, f in ipairs(P.flights) do
            if Map.SideOk(f.side, side) then add("flight", f, f.point) end
        end
    end
    return out
end

local cache, cacheStamp = {}, nil
local version = 0

function Map.PlacePins(mapID)
    mapID = tonumber(mapID)
    if not mapID or not ns.HasData("MAP") then return {} end
    local stamp = version .. ":" .. tostring(ns.Data("MAP")) .. ":" .. tostring(ownSide())
    if stamp ~= cacheStamp then cache, cacheStamp = {}, stamp end
    local list = cache[mapID]
    if not list then
        list = buildPins(mapID)
        cache[mapID] = list
    end
    return list
end

ns.Listen("SETTING", function(path)
    if type(path) == "string" and path:sub(1, 4) == "map." then version = version + 1 end   -- l10n-ok: setting key prefix
end)

-- Test hook: forget what was built and what the client showed.
function Map._resetPlaces()
    built, cache, cacheStamp, clientSeen = {}, {}, nil, {}
    version = version + 1
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function factName(f)
    return ns.Dungeons and ns.Dungeons.Name(f) or f.name or f.key
end

-- "17-24" from the planner when it knows the dungeon, else the facts' range or tuning level.
local function rangeOf(f)
    local info = ns.Gear and ns.Gear.Available() and ns.DungeonInfo and ns.DungeonInfo(f.key)
    if info and info.min then return ns.Dungeons.RangeText(info) end
    if f.min and f.max then return f.min == f.max and tostring(f.min) or (f.min .. "-" .. f.max) end
    if type(f.lvl) == "number" then return "~" .. f.lvl end
    return nil
end

-- "öffnet am 09.12." for a fact that opens later, else nil.
local function opensText(f)
    local y, m, d = tostring(f.from or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    if not y or not date then return nil end
    if date("%Y-%m-%d") >= f.from then return nil end
    return L["öffnet am %s"]:format(ns.FmtDay(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })))
end

local function destName(d)
    if type(d.area) == "number" and d.area > 0 and C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, d.area)
        name = ok and ns.Plain(name) or nil
        if type(name) == "string" and name ~= "" then return name end
    end
    return d.name or "?"
end

-- The destinations of a dock as lines: "Schiff nach Beutebucht".
function Map.DockLines(dock)
    local out = {}
    for _, d in ipairs(dock.to) do
        out[#out + 1] = (dock.ship and L["Schiff nach %s"] or L["Zeppelin nach %s"]):format(destName(d))
    end
    return out
end

-- The label of a place as a target.
local function labelOf(e)
    local p = e.place
    if e.kind == "entrance" then return L["%s (Eingang)"]:format(factName(p.facts[1])) end
    if e.kind == "dock" then return Map.DockLines(p)[1] or "?" end
    return p.name
end
Map.PlaceLabel = labelOf

local function where(e)
    return ("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point))
end

local function tooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local p = e.place
    if e.kind == "entrance" then
        for _, f in ipairs(p.facts) do
            GameTooltip:AddLine(factName(f), 1, 0.82, 0)
            local parts = {}
            parts[#parts + 1] = f.kind == "raid" and "Raid" or "Dungeon"
            local range = rangeOf(f)
            if range then parts[#parts + 1] = L["Stufe %s"]:format(range) end
            parts[#parts + 1] = L["%d Spieler"]:format(f.size or (f.kind == "raid" and 40 or 5))
            GameTooltip:AddLine(table.concat(parts, " · "), 1, 1, 1)
            local opens = opensText(f)
            if opens then GameTooltip:AddLine(opens, 1, 0.5, 0.25) end
        end
        GameTooltip:AddLine(where(e), 0.7, 0.7, 0.7)
        if p.how == "o" then GameTooltip:AddLine(L["Ort ungefähr"], 0.7, 0.7, 0.7) end
        if p.how == "l" then GameTooltip:AddLine(L["Ort beim Betreten gemerkt"], 0.7, 0.7, 0.7) end
        GameTooltip:AddLine(TEXT.entranceHint, 0.6, 0.6, 0.6)
    elseif e.kind == "dock" then
        for _, line in ipairs(Map.DockLines(p)) do GameTooltip:AddLine(line, 1, 0.82, 0) end
        GameTooltip:AddLine(SIDE_TEXT[p.side] or SIDE_TEXT.N, 1, 1, 1)
        GameTooltip:AddLine(where(e), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(TEXT.placeHint, 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine(p.name, 1, 0.82, 0)
        GameTooltip:AddLine(L["Flugmeister"] .. " · " .. (SIDE_TEXT[p.side] or SIDE_TEXT.N), 1, 1, 1)
        GameTooltip:AddLine(where(e), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(TEXT.placeHint, 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(TEXT.more, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end
Map.PlaceTooltipOf = tooltip

---------------------------------------------------------------------------
-- Clicks
---------------------------------------------------------------------------

-- Opens a dungeon on the page Dungeons (the world map stays open in front, F-011); in combat, when
-- the window does not come up, a line in the chat. Returns true when the window shows.
function Map.OpenDungeon(key)
    local ok, shown = pcall(function() return ns.ShowDungeon and ns.ShowDungeon(key) end)
    if not ok then report(shown) end
    if ok and shown then return true end
    if InCombatLockdown and InCombatLockdown() then
        ns.msg(L["Im Kampf öffnet Amisia das Fenster nicht. Nach dem Kampf noch einmal klicken."])
    end
    return false
end

local function setTarget(e)
    return ns.MapSetPoint(e.point, labelOf(e), e.kind == "entrance" and e.place.key or nil)
end

local function menuOf(e)
    local entries = {}
    if e.kind == "entrance" then
        for _, f in ipairs(e.place.facts) do
            local text = #e.place.facts > 1 and (TEXT.open .. ": " .. factName(f)) or TEXT.open
            entries[#entries + 1] = { text, function() Map.OpenDungeon(f.key) end }
        end
    end
    entries[#entries + 1] = { TEXT.target, function() setTarget(e) end }
    entries[#entries + 1] = { TEXT.offEntrances, function() ns.Set("map.entrances", false) end }
    entries[#entries + 1] = { TEXT.offFlights, function() ns.Set("map.flights", false) end }
    entries[#entries + 1] = { TEXT.offTransports, function() ns.Set("map.transports", false) end }
    return entries
end
Map.PlaceMenuOf = menuOf

local function click(self, button)
    local e = self.entry
    if not e then return end
    if button == "RightButton" then
        W.Menu(self, menuOf(e))
    elseif button == "LeftButton" then
        if e.kind == "entrance" and not (IsShiftKeyDown and IsShiftKeyDown()) then
            Map.OpenDungeon(e.place.facts[1].key)
        else
            setTarget(e)
        end
    end
end

---------------------------------------------------------------------------
-- The pin (AmisiaMapPlaceMixin, the template in MapPin.xml)
---------------------------------------------------------------------------

AmisiaMapPlaceMixin = {}
local Pin = AmisiaMapPlaceMixin
local base

function Pin:OnLoad()
    self:SetSize(20, 20)
    self.icon = self:CreateTexture(nil, "ARTWORK")
    self.icon:SetPoint("CENTER")
    self.edges = W.Border(self, GOLD[1], GOLD[2], GOLD[3], 1)
end

local function iconOf(e)
    if e.kind == "entrance" then return ICON[e.place.raid and "raid" or "party"] end
    if e.kind == "dock" then return ICON[e.place.ship and "S" or "Z"] end
    return ICON.flight
end

-- entry: one of Map.PlacePins; scale: map.pinScale (and 70 % on a continent).
function Pin:OnAcquired(entry, scale)
    self.entry = entry
    scale = scale or 1
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, scale, 1.6 * scale)
    self:SetPosition(entry.x, entry.y)
    if self.ApplyCurrentScale then self:ApplyCurrentScale() end
    local size = SIZE[entry.kind] or 20
    self:SetSize(size, size)
    local icon = iconOf(entry)
    -- pins are pooled: the art is set every time
    if icon.atlas and W.HasAtlas(icon.atlas) then
        self.icon:SetAtlas(icon.atlas)
        self.icon:SetSize(size + 4, size + 4)
        self.icon:SetTexCoord(0, 1, 0, 1)
        for _, t in ipairs(self.edges) do t:Hide() end
    else
        self.icon:SetTexture(icon.file)
        self.icon:SetSize(size - 2, size - 2)
        -- the icons of the client's icon set get a frame; the taxi node is round art of its own
        local framed = entry.kind ~= "flight"
        local cut = framed and 0.08 or 0
        self.icon:SetTexCoord(cut, 1 - cut, cut, 1 - cut)
        local c = entry.kind == "entrance" and GOLD or BORDER[entry.kind]
        W.SetBorderColor(self.edges, c[1], c[2], c[3], 1)
        for _, t in ipairs(self.edges) do t:SetShown(framed) end
    end
end

function Pin:OnReleased()
    self.entry = nil
    if base and base.OnReleased then base.OnReleased(self) end
end

function Pin:OnMouseEnter()
    local e = self.entry
    if not e then return end
    local ok, err = pcall(tooltip, self, e)
    if not ok then report(err) end
end

function Pin:OnMouseLeave()
    GameTooltip:Hide()
end

-- as the target pins: right clicks stay on the pin, the restricted passthrough call never happens
function Pin:ShouldMouseButtonBePassthrough()
    return false
end
function Pin:CheckMouseButtonPassthrough() end
Pin.OnMouseClickAction = click

-- Completes the mixin with the client's pin mixin, once (called by MapPins.lua's register).
function Map.FillPlaceMixin(pinBase)
    if base then return end
    base = pinBase
    if pinBase.CheckMouseButtonPassthrough == nil then Pin.OnClick = click end
    for k, v in pairs(pinBase) do
        if Pin[k] == nil then Pin[k] = v end
    end
end

-- Puts the place pins of the shown map on it (called inside the provider's protected refresh).
function Map.AcquirePlaces(map, scale)
    map:RemoveAllPinsByTemplate(TEMPLATE)
    if not map:IsShown() then return end
    for _, e in ipairs(Map.PlacePins(ns.Plain(map:GetMapID()))) do
        map:AcquirePin(TEMPLATE, e, e.continent and scale * 0.7 or scale)
    end
end
Map.PLACE_TEMPLATE = TEMPLATE

---------------------------------------------------------------------------
-- Learned entrances (AmisiaDB.entrances)
---------------------------------------------------------------------------

local LEARN_MAX = 60       -- instances kept (the newest)
local LEARN_AGE = 20       -- seconds between the last place outdoors and the loading screen
local SUMMON_GAP = 120     -- a summon this short before: the last place is not the entrance
local SAMPLE_EVERY = 2

local function int(v, lo, hi)
    return type(v) == "number" and v == math.floor(v) and v >= lo and (not hi or v <= hi)
end

-- An instance name as kept: no colour codes, no control characters or bars, 60 bytes.
local function cleanName(n)
    if type(n) ~= "string" then return "" end
    n = n:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%c|]", "")
    return n:sub(1, 60)
end

-- Checks AmisiaDB.entrances on ADDON_LOADED: { v = 1, list = { [instance id] = { m = uiMapID,
-- x, y (0-10000), t = epoch, n = the client's instance name (60 bytes, no codes), k = party/raid } } },
-- at most 60 (the newest). Running it twice changes nothing.
function ns.EntrancesLoaded(root)
    local e = type(root.entrances) == "table" and root.entrances or {}
    root.entrances = e
    e.v = 1
    local list = type(e.list) == "table" and e.list or {}
    local keep = {}
    for k, r in pairs(list) do
        if int(k, 1) and type(r) == "table" and int(r.m, 1) and int(r.x, 0, 10000) and int(r.y, 0, 10000) and int(r.t, 1) then
            keep[#keep + 1] = { k, { m = r.m, x = r.x, y = r.y, t = r.t, n = cleanName(r.n), k = (r.k == "party" or r.k == "raid") and r.k or nil } }
        end
    end
    table.sort(keep, function(a, b)
        if a[2].t ~= b[2].t then return a[2].t > b[2].t end
        return a[1] < b[1]
    end)
    local out = {}
    for i = 1, math.min(#keep, LEARN_MAX) do out[keep[i][1]] = keep[i][2] end
    e.list = out
    for k in pairs(e) do
        if k ~= "v" and k ~= "list" then e[k] = nil end
    end
    return e
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.EntrancesLoaded(AmisiaDB) end
end)

local last          -- { m, x, y, at } the last place outdoors
local summonedAt    -- GetTime() of the last summon offer

local function inInstance()
    if not IsInInstance then return false end
    return ns.Plain(IsInInstance()) and true or false
end

-- The player's place outdoors, kept with the time; nothing inside an instance.
function Map.SamplePlace()
    if inInstance() or not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local m = ns.Plain(C_Map.GetBestMapForUnit("player"))
    if type(m) ~= "number" or m <= 0 then return nil end
    local pos = C_Map.GetPlayerMapPosition(m, "player")
    local x, y
    if pos then x, y = ns.Plain(pos.x), ns.Plain(pos.y) end
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    last = { m = m, x = math.floor(x * 10000 + 0.5), y = math.floor(y * 10000 + 0.5), at = GetTime() }
    return last
end

-- After a loading screen inside a dungeon or raid: the last place outdoors becomes its entrance
-- when it is at most 20 s old and no summon came in between. Returns the record or nil.
function Map.LearnEntrance()
    local sample = last
    last = nil
    if not inInstance() then return nil end
    local _, itype = IsInInstance()
    itype = ns.Plain(itype)
    if itype ~= "party" and itype ~= "raid" then return nil end
    if not sample or GetTime() - sample.at > LEARN_AGE then return nil end
    if summonedAt and GetTime() - summonedAt < SUMMON_GAP then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    id, name = ns.Plain(id), ns.Plain(name)
    if not int(id, 1) or not AmisiaDB then return nil end
    local e = type(AmisiaDB.entrances) == "table" and type(AmisiaDB.entrances.list) == "table" and AmisiaDB.entrances
        or ns.EntrancesLoaded(AmisiaDB)
    local r = { m = sample.m, x = sample.x, y = sample.y, t = time(), n = cleanName(name),
        k = itype }
    e.list[id] = r
    local n = 0
    for _ in pairs(e.list) do n = n + 1 end
    if n > LEARN_MAX then ns.EntrancesLoaded(AmisiaDB) end
    return r
end

local ticker
ns.OnEvent("PLAYER_LOGIN", function()
    if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(SAMPLE_EVERY, Map.SamplePlace) end
end)
ns.OnEvent("LOADING_SCREEN_ENABLED", function() Map.SamplePlace() end)
ns.OnEvent("PLAYER_LEAVING_WORLD", function() Map.SamplePlace() end)
ns.OnEvent("CONFIRM_SUMMON", function() summonedAt = GetTime() end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function() Map.LearnEntrance() end)

-- Test hook: the sample and the summon forgotten.
function Map._resetLearn() last, summonedAt = nil, nil end
