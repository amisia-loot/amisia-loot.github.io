-- Raids page (tab Dungeons & Raids, right after the page Dungeons; F-122): two views as on the page
-- Dungeons (F-143). The start: every raid at any level as a row of the table by size (F-148, D-74:
-- picture, name, size, when it opens, zone, keys, waypoint; the line under the name with its value for
-- the own character and the own raid ID); a click opens the detail: a link back to the table, the
-- chosen one's image with its boss model, its bosses with their loot, the waypoint to its entrance. The
-- values come from Gear/Dungeons.lua (ns.RaidList, ns.RaidNext); the table, the image and the boss list
-- are the page Dungeons' (ns.DungeonJournalKit), the item texts and the spec picker the gear page's
-- (ns.GearPageKit). The chosen raid stays in settings.bis.raid, the view only in memory (the first open
-- of a session shows the table). Key "raidjournal": the officers' page "raids" (the recorded raids, tab
-- Raid) has the key "raids".
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local K = ns.GearPageKit
local J = ns.DungeonJournalKit
local JP = ns.JournalParts   -- the detail's tabs, run, map and keys (D-72)
local ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_Black"
-- at least 5 rows of the chosen one under its image (they fill the page down to its bottom)
local DETAIL_ROWS = 5
local state, say = K.state, K.say
local signed = J.signed

local page

-- "ab 09.12." before the opening day, "ab Stufe 60" below the level cap, else "passt".
local function fitText(e)
    if e.fit == "later" or e.fit == "fit" or e.fit == "easy" then return ns.Dungeons.FitText(e) end
    return L["ab Stufe %d"]:format(e.min or ns.Gear.Cap())
end

-- The own raid ID of a raid: "locked" and the ID, or nil.
local function ownID(e)
    if not (e.inst and ns.RaidIDOf and ns.UnitFullName) then return nil end
    local me = ns.UnitFullName("player")
    if not me then return nil end
    local st, x = ns.RaidIDOf(me, e.inst)
    if st == "locked" and x then return x end
    return nil
end

-- A raid's row (F-148): its name, the line under it (the run, "Hier bist du", "Empfohlen", the own
-- raid ID, upgrades, gain per run and value); dim unless it fits now.
local GREEN, GREY, ORANGE = "|cff4fd06a", T.GREY, T.ORANGE
local VALUES = L["%d Upgrades · %s je Lauf · Wert %d"]
local RTEXT = { here = L["Hier bist du"], tag = L["Empfohlen"], size = L["Größe"], level = L["Stufe"], zone = "Zone",
    keys = L["Schlüssel"], act = L["Aktionen"], group = L["Raids für %d"], groupAny = "Raids",
    count = L["%d Raids"], one = L["1 Raid"] }
local function raidTexts(e, ctx)
    local parts = {}
    if ctx.here == e.key then parts[#parts + 1] = GREEN .. RTEXT.here .. "|r" end
    local badge = J.runBadge(e, false, true)
    if badge ~= "" then parts[#parts + 1] = badge end
    if ctx.recommended == e.key then parts[#parts + 1] = GREEN .. RTEXT.tag .. "|r" end
    local x = ownID(e)
    if x then parts[#parts + 1] = ORANGE .. L["ID bis %s"]:format(ns.Cal and ns.Cal.When(x.r) or date("%H:%M", x.r)) .. "|r" end
    if e.computed then
        parts[#parts + 1] = VALUES:format(e.upgrades, e.perRun > 0 and signed(e.perRun) or "0", math.floor(e.value + 0.5))
    end
    return e.name, table.concat(parts, " · "), e.fit ~= "fit"
end

-- The raids by size ("Raids für 20"), the smaller first.
local function sizeGroup(e)
    if not e.size then return "S0", RTEXT.groupAny, 999 end
    return "S" .. e.size, RTEXT.group:format(e.size), e.size
end

local function raidTip(self)
    local e = self.item
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.name, 1, 0.82, 0)
    GameTooltip:AddLine(("Raid%s · %s"):format(e.size and L[" für %s"]:format(e.size) or "", fitText(e)), 0.85, 0.85, 0.85)
    if e.computed then
        GameTooltip:AddLine(L["%d Upgrades, je Lauf %s, Wert %d"]:format(e.upgrades, signed(e.perRun), math.floor(e.value + 0.5)),
            0.6, 0.6, 0.6)
    end
    local x = ownID(e)
    if x then GameTooltip:AddLine(L["Deine Raid-ID: %s"]:format(ns.RaidIDText(x)), 1, 0.5, 0.25) end
    GameTooltip:Show()
end

-- The view: "start" (the cards) until a card is clicked or a raid is asked for, then "detail";
-- only in memory.
local view = "start"

local function placeHead(B, detail)
    if B.headView == detail then return end
    B.headView = detail
    B:Place(1, detail and { B.back, B.spec } or { B.spec })
end

local function create(parent)
    -- the head row: the spec (the gear page's), in the detail the link back to the cards before it;
    -- the next raid, why and the cards (start); the image and the bosses (detail); the hint behind
    -- the "i"
    local B = W.Page(parent)
    page = B
    -- the head row, the filter row (D-72), the next raid, why
    B:Bands({ "row", "row", "row", { "line", lines = 2 } })
    B.back = W.Link(B, L["< Alle Raids"], function()
        view = "start"
        ns.Refresh()
    end)
    W.Tooltip(B.back, L["Alle Raids"], L["Zurück zur Liste aller Raids."])
    B.spec = K.specPicker(B)
    B.next = W.Text(B, T.FONT.title)
    B.why = B:Line(4)
    placeHead(B, false)
    J.buildFilter(B, 2, { here = function(key) ns.ShowDungeon(key) end })
    B:Place(3, { { B.next, fill = true } })
    B:Footer({ { "hint", lines = 2, help = true } })
    -- the start: the table down to the page's bottom (F-148); a click chooses the raid and opens its
    -- detail
    local tctx
    tctx = { nameLabel = "Raid", cols = {
            { key = "size", label = RTEXT.size },
            { key = "level", label = RTEXT.level },
            { key = "zone", label = RTEXT.zone, justify = "LEFT" },
            { key = "keys", label = RTEXT.keys, kind = "keys" },
            { key = "act", label = RTEXT.act, kind = "act" } },
        texts = function(e) return raidTexts(e, tctx) end,
        cell = function(e, key)
            if key == "size" then return e.size and tostring(e.size) or (GREY .. "-|r") end
            if key == "level" then return (e.fit == "fit" and "|cffffff00" or GREY) .. fitText(e) .. "|r" end
            if key == "zone" then return select(2, J.instanceZone(e.key)) or (GREY .. "-|r") end
        end,
        tip = raidTip,
        pick = function(e)
            state().raid = e.key
            view = "detail"
            ns.Refresh()
        end,
        action = function(e) say(ns.DungeonWaypoint(e.key)) end,
        group = sizeGroup,
        countText = function(n) return n == 1 and RTEXT.one or RTEXT.count:format(n) end,
        grouped = function() return true end,
        sortField = "rcol",
        sorts = {
            name = function(e) return e.name end,
            size = function(e) return e.size or 0 end,
            level = function(e) return (e.min or 0) * 100 + (e.max or 0) end,
            zone = function(e) return select(2, J.instanceZone(e.key)) or "~" end,
        } }
    B.table = J.buildTable(B, B.top, tctx)
    B.emptyGrid = B:Empty(nil, B.table)
    -- the detail: the image right under the head row, the bosses' header under it, then their list
    local G = T.LAYOUT
    local artTop = -(G.ROW_H + G.GAP)
    B.art = J.buildArt(B, artTop)
    -- the tabs under the image (D-72): Übersicht, Karte, Wunschliste, Zugang (only with a key; the
    -- chosen one in settings.bis.rpart), the part's header under them
    local tabTop = artTop - J.ART_H - G.GAP
    local headerTop = tabTop - G.ROW_H - G.GAP
    B.header = W.SectionHeader(B, "", false)
    B.header:SetPoint("TOPLEFT", 0, headerTop)
    B.header:SetPoint("TOPRIGHT", -132, headerTop)
    JP.BuildTabs(B, tabTop, { "bosses", "map", "wish", "access" }, "rpart")
    B.way = W.Link(B, L["Wegpunkt"], function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Raids."])
    W.Row(B, { B.way }, 0, 0, tabTop - 1, { right = true })
    -- the bosses' fold (F-144) and the run (D-72) at the right end of the header's line
    B.foldAll = J.foldLink(B)
    JP.BuildRun(B)
    B.partRow = { B.runBar, { B.foldAll, gap = G.ITEM_GAP }, { B.resetRun, gap = G.ITEM_GAP } }
    function B:PlaceParts() J.placeParts(self, headerTop) end
    B:PlaceParts()
    B.detail = J.buildDetail(B, DETAIL_ROWS, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPLEFT", 0, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, headerTop - T.HEADER_H - G.GAP)
    JP.BuildMap(B, headerTop - T.HEADER_H - G.GAP)
    JP.BuildAccess(B, headerTop - T.HEADER_H - G.GAP)
    B.startParts = { B.next, B.why, B.table, B.table.head }
    for _, f in ipairs(B.filterParts) do B.startParts[#B.startParts + 1] = f end
    B.detailParts = { B.back, B.header, B.way }
    for _, k in ipairs(B.partKeys) do B.detailParts[#B.detailParts + 1] = B.parts[k] end
    -- shown by the part (refresh): the list, the map, the keys, the run, the fold link
    B.partViews = { B.detail, B.mapView, B.accessView, B.runBar, B.resetRun, B.foldAll }
    return B
end

local function refresh(B)
    K.namesFresh()
    K.fillSpec(B.spec, ns.BisOpts())
    -- in a raid (its first show there, or entered while open): its detail (D-72)
    local here = J.newHere(B, true)
    if here then
        state().raid = here
        view = "detail"
    end
    local list = ns.RaidList()
    local nextE, why = ns.RaidNext()
    if nextE then
        B.next:SetText(L["Nächster Raid: %s"]:format(nextE.name))
        B.why:SetText(nextE.why or "")
    else
        B.next:SetText(why or ns.Dungeons.NO_DATA)
        B.why:SetText("")
    end
    -- the chosen raid: the saved one, else the recommended, else the first
    local key, e = state().raid, nil
    for _, x in ipairs(list) do
        if x.key == key then e = x end
    end
    e = e or nextE or list[1]
    B.chosen = e and e.key or nil
    B.table.ctx.here = ns.Runs.Here()
    local filtered = J.applyFilter(B, list, false)
    B.table:SetEntries(filtered, B.chosen, nextE and nextE.key or nil)
    B.entry = e
    local detail = view == "detail" and e ~= nil
    -- back on the start: the chosen row in view
    if not detail and B.wasDetail and B.chosen then B.table:RowOf(B.chosen) end
    B.wasDetail = detail
    for _, f in ipairs(B.startParts) do f:SetShown(not detail) end
    for _, f in ipairs(B.partViews) do f:Hide() end
    B.emptyGrid:SetShown(not detail and #filtered == 0 and #list > 0)
    for _, f in ipairs(B.detailParts) do f:SetShown(detail) end
    placeHead(B, detail)
    if detail then
        J.fillArt(B, e)
        B.art.info:SetText(("Raid%s · %s"):format(e.size and (" " .. e.size) or "", fitText(e)))
    else
        B.art:Hide()
    end
    local part = JP.PartOf(B, e)
    if e ~= B.detailEntry and (not e or not B.detailEntry or e.key ~= B.detailEntry.key) then B.detail.offset = 0 end
    B.detailEntry = e
    if detail then
        B.parts.access:SetShown(JP.Keys(e.key) ~= nil)
        JP.PlaceTabs(B)
        B.detail:SetShown(part == "bosses" or part == "wish")
        B.mapView:SetShown(part == "map")
        B.accessView:SetShown(part == "access")
    end
    B.way:SetEnabled(e ~= nil and ns.DungeonEntrance(e.key) ~= nil)
    if e and part == "wish" then
        B.header:SetHeaderText(L["Wunschliste"])
        B.foldEntry = nil
        B.detail:SetItems(J.wishItems(e))
    elseif e and part == "map" then
        B.header:SetHeaderText(L["Karte"])
        JP.FillMap(B, e)
    elseif e and part == "access" then
        B.header:SetHeaderText(L["Zugang"])
        JP.FillAccess(B, e)
    elseif e then
        B.header:SetHeaderText(L["Bosse"])
        J.showBosses(B, e)
    else
        B.header:SetHeaderText("")
        J.showBosses(B, nil)
    end
    -- the fold link only in the part Übersicht for a raid with a boss that has items (F-144)
    B.foldAll:SetShown(detail and part == "bosses" and e ~= nil and select(2, J.foldState(B, e)) and true or false)
    JP.FillRun(B, detail and e or nil, part == "bosses")
    B:PlaceParts()
    local hint = L["Je Lauf: Zuwachs der Upgrades mal Dropchance. Beute und Chance aus den Drop-Aufzeichnungen der Gilde."]
    if not detail then
        B.hint:SetText(L["Klick auf eine Zeile: Bild, Bosse und Beute des Raids. Klick auf einen Spaltenkopf: sortieren."] .. " " .. hint)
        return
    end
    if part == "wish" then
        B.hint:SetText(J.WISH_HINT)
        return
    elseif part == "map" or part == "access" then
        B.hint:SetText(part == "map" and J.MAP_HINT or J.ACCESS_HINT)
        return
    end
    if e and #B.detail.items == 0 then hint = L["Für diesen Raid kennt Amisia noch keine Beute."] .. " " .. hint end
    B.hint:SetText(hint .. " " .. J.foldHint .. " " .. J.itemHint)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

-- Opens the page Raids with that raid chosen (the search, a click on its entrance on the world
-- map through ns.ShowDungeon). While the world map shows, the window stays under it (F-011).
-- Returns true when the window shows.
function ns.ShowRaid(key)
    if type(key) ~= "string" then return false end
    J.holdHere(true)   -- asked for: no jump to the raid stood in (D-72)
    state().raid = key
    view = "detail"
    if ns.ShowPage then ns.ShowPage("raidjournal") end
    local main, map = _G.AmisiaFrame, _G.WorldMapFrame
    if main and map and map.IsShown and map:IsShown() and ns.MapLowerMain then
        ns.MapLowerMain(map, main)
        if map.Raise then map:Raise() end
    end
    return main ~= nil and main:IsShown() and true or false
end

ns.RegisterPanel{ key = "raidjournal", label = "Raids", sub = L["Bosse und Beute der Raids, mit deinen Upgrades."], icon = ICON, order = 52, group = "dungeons",
    available = function() return ns.Gear.Available() end,
    create = create, refresh = refresh,
    -- the raid sizes of the table in the side bar while the start shows (D-74)
    jumps = function(B) return B.table and B.table:IsShown() and B.table.groups or {} end,
    jump = function(B, key) if B.table then B.table:JumpTo(key) end end }

-- the own raid IDs were read again: the cards' ID
ns.Listen("RAIDIDS", function()
    if page and page:IsShown() and ns.RefreshSoon then ns.RefreshSoon() end
end)

ns.RegisterSlash("raids", { desc = L["Raids: Bosse, Beute und Upgrades der Raids, deine Raid-IDs"], run = function()
    if not ns.Gear.Available() then
        ns.msg(L["Für diesen Client gibt es keine Ausrüstungsdaten."])
        return
    end
    ns.ShowPage("raidjournal")
end })
