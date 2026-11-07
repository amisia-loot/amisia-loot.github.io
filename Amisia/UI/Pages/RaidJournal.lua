-- Raids page (group Welt, right after the page Dungeons; F-122): two views as on the page Dungeons
-- (F-143). The start: every raid at any level as a card with its size, when it opens, its value for
-- the own character and the own raid ID (the recommended one tagged); a click opens the detail: a
-- link back to the cards, the chosen one's image with its boss model, its bosses with their loot, the
-- waypoint to its entrance. The values come from Gear/Dungeons.lua (ns.RaidList, ns.RaidNext); the
-- cards, the image and the boss list are the page Dungeons' (ns.DungeonJournalKit), the item texts
-- and the spec picker the gear page's (ns.GearPageKit). The chosen raid stays in settings.bis.raid,
-- the view only in memory (the first open of a session shows the cards). Key "raidjournal": the
-- officers' page "raids" (the recorded raids, group Raid) has the key "raids".
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local K = ns.GearPageKit
local J = ns.DungeonJournalKit
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

-- A raid's card: size, fit and the own raid ID; upgrades, gain per run and value; dim unless it fits
-- now (as the table's rows were).
local GREEN, GREY, ORANGE = "|cff4fd06a", T.GREY, T.ORANGE
local VALUES = L["%d Upgrades · %s je Lauf · Wert %d"]
local function raidCardTexts(c, e)
    c.name:SetText(e.name)
    local parts = {}
    if e.size then parts[#parts + 1] = "Raid " .. e.size end
    parts[#parts + 1] = (e.fit == "fit" and GREEN or GREY) .. fitText(e) .. "|r"
    local x = ownID(e)
    if x then parts[#parts + 1] = ORANGE .. L["ID bis %s"]:format(ns.Cal and ns.Cal.When(x.r) or date("%H:%M", x.r)) .. "|r" end
    c.line1:SetText(table.concat(parts, " · "))
    if e.computed then
        c.line2:SetText(VALUES:format(e.upgrades, e.perRun > 0 and signed(e.perRun) or "0", math.floor(e.value + 0.5)))
    else
        c.line2:SetText("")
    end
    return e.fit ~= "fit"
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
    B:Bands({ "row", "row", { "line", lines = 2 } })
    B.back = W.Link(B, L["< Alle Raids"], nil, function()
        view = "start"
        ns.Refresh()
    end)
    W.Tooltip(B.back, L["Alle Raids"], L["Zurück zu den Kacheln aller Raids."])
    B.spec = K.specPicker(B)
    B.next = W.Text(B, T.FONT.title)
    B.why = B:Line(3)
    placeHead(B, false)
    B:Place(2, { { B.next, fill = true } })
    B:Footer({ { "hint", lines = 2, help = true } })
    -- the start: the cards down to the page's bottom; a click chooses the raid and opens its detail
    B.grid = J.buildGrid(B, B.top, { texts = raidCardTexts, tip = raidTip, pick = function(e)
        state().raid = e.key
        view = "detail"
        ns.Refresh()
    end })
    -- the detail: the image right under the head row, the bosses' header under it, then their list
    local G = T.LAYOUT
    local artTop = -(G.ROW_H + G.GAP)
    B.art = J.buildArt(B, artTop)
    local headerTop = artTop - J.ART_H - G.GAP
    B.header = W.SectionHeader(B, "", false)
    B.header:SetPoint("TOPLEFT", 0, headerTop)
    B.header:SetPoint("TOPRIGHT", -132, headerTop)
    B.way = W.Link(B, L["Wegpunkt"], 120, function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    W.Row(B, { B.way }, T.CHIP_GAP, 0, headerTop - 1, { right = true })
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Raids."])
    B.detail = J.buildDetail(B, DETAIL_ROWS, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPLEFT", 0, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, headerTop - T.HEADER_H - G.GAP)
    B.startParts = { B.next, B.why, B.grid }
    B.detailParts = { B.back, B.header, B.way, B.detail }
    return B
end

local function refresh(B)
    K.namesFresh()
    K.fillSpec(B.spec, ns.BisOpts())
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
    B.grid:SetEntries(list, B.chosen, nextE and nextE.key or nil)
    B.entry = e
    local detail = view == "detail" and e ~= nil
    -- back on the start: the chosen card in view
    if not detail and B.wasDetail and B.chosen then B.grid:CardOf(B.chosen) end
    B.wasDetail = detail
    for _, f in ipairs(B.startParts) do f:SetShown(not detail) end
    for _, f in ipairs(B.detailParts) do f:SetShown(detail) end
    placeHead(B, detail)
    if detail then
        J.fillArt(B, e)
        B.art.info:SetText(("Raid%s · %s"):format(e.size and (" " .. e.size) or "", fitText(e)))
    else
        B.art:Hide()
    end
    if e ~= B.detailEntry and (not e or not B.detailEntry or e.key ~= B.detailEntry.key) then B.detail.offset = 0 end
    B.detailEntry = e
    if e then
        B.header:SetHeaderText(e.name .. " · " .. L["Bosse"])
        B.detail:SetItems(J.detailItems(e))
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    else
        B.header:SetHeaderText("")
        B.detail:SetItems({})
        B.way:SetEnabled(false)
    end
    local hint = L["Je Lauf: Zuwachs der Upgrades mal Dropchance. Beute und Chance aus den Drop-Aufzeichnungen der Gilde."]
    if not detail then
        B.hint:SetText(L["Klick auf eine Kachel: Bild, Bosse und Beute des Raids. Grün markiert: der empfohlene."] .. " " .. hint)
        return
    end
    if e and #B.detail.items == 0 then hint = L["Für diesen Raid kennt Amisia noch keine Beute."] .. " " .. hint end
    B.hint:SetText(hint .. " " .. J.itemHint)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function ns.RaidJournalPageFrame() return page end

-- Opens the page Raids with that raid chosen (the search, a click on its entrance on the world
-- map through ns.ShowDungeon). While the world map shows, the window stays under it (F-011).
-- Returns true when the window shows.
function ns.ShowRaid(key)
    if type(key) ~= "string" then return false end
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

ns.RegisterPanel{ key = "raidjournal", label = "Raids", sub = L["Bosse und Beute der Raids, mit deinen Upgrades."], icon = ICON, order = 52, group = "world",
    available = function() return ns.Gear.Available() end,
    create = create, refresh = refresh }

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
