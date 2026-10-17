-- Raids page (tab Ausrüstung, right after the page Dungeons; F-122): every raid at any level with
-- its size, when it opens, its value for the own character and the own raid ID; the chosen one's
-- image with its boss model, its bosses with their loot, the waypoint to its entrance. The values
-- come from Gear/Dungeons.lua (ns.RaidList, ns.RaidNext); the image and the boss list are the
-- page Dungeons' (ns.DungeonJournalKit), the item texts and the spec picker the gear page's
-- (ns.GearPageKit). The chosen raid stays in settings.bis.raid. Key "raidjournal": the officers'
-- page "raids" (the recorded raids, tab Raid) has the key "raids".
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local K = ns.GearPageKit
local J = ns.DungeonJournalKit
local ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_Black"
local ROW_H = J.ROW_H
-- 3 raids and 7 rows of the chosen one: as high as the page Dungeons (5 and 5)
local RAID_ROWS, DETAIL_ROWS = 3, 7
local state, say, hideTip = K.state, K.say, K.hideTip
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

local function fillRaidRow(r, e)
    r.name:SetText(e.name)
    if e.fit == "fit" then r.name:SetTextColor(1, 1, 1) else r.name:SetTextColor(0.56, 0.53, 0.64) end
    r.size:SetText(e.size and tostring(e.size) or "")
    r.fit:SetText(fitText(e))
    if e.fit == "fit" then r.fit:SetTextColor(0.31, 0.82, 0.42) else r.fit:SetTextColor(0.56, 0.53, 0.64) end
    if e.computed then
        r.upgrades:SetText(tostring(e.upgrades))
        r.run:SetText(e.perRun > 0 and signed(e.perRun) or "0")
        r.value:SetText(tostring(math.floor(e.value + 0.5)))
    else
        r.upgrades:SetText(""); r.run:SetText(""); r.value:SetText("")
    end
    local x = ownID(e)
    r.id:SetText(x and L["bis %s"]:format(ns.Cal and ns.Cal.When(x.r) or date("%H:%M", x.r)) or "")
    if r.owner and r.owner.chosen == e.key then r.sel:Show() else r.sel:Hide() end
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

local function create(parent)
    -- the head row: the spec (the gear page's); the next raid, why, the list, the image, the
    -- bosses, the hint in the footer
    local B = W.Page(parent)
    page = B
    B:Bands({ "row", "row", { "line", lines = 2 } })
    B.spec = K.specPicker(B)
    B.next = W.Text(B, T.FONT.title)
    B.why = B:Line(3)
    B:Place(1, { B.spec })
    B:Place(2, { { B.next, fill = true } })
    B:Footer({ { "hint", lines = 2 } })
    -- the list is 590 wide (12 px for its scroll bar)
    local cols = { { "name", 4, 150, "Raid" }, { "size", 158, 44, L["Größe"], justify = "RIGHT" }, { "fit", 210, 78, L["Passung"] },
        { "upgrades", 290, 56, "Upgrades", justify = "RIGHT" }, { "run", 350, 60, L["Je Lauf"], justify = "RIGHT" },
        { "value", 414, 50, L["Wert"], justify = "RIGHT" }, { "id", 472, 114, "ID" } }
    B.headFrame, B.head = B:Columns(cols)
    B.list = B:List(RAID_ROWS, ROW_H, function(r)
        r.owner = B
        r.sel = W.SelectBar(r)
        W.Cells(r, cols)
        r:SetScript("OnClick", function(self)
            if not self.item then return end
            state().raid = self.item.key
            ns.Refresh()
        end)
        r:SetScript("OnEnter", raidTip)
        r:SetScript("OnLeave", hideTip)
    end, fillRaidRow)
    -- the image under the list, the bosses' header under it, then their list
    local G = T.LAYOUT
    local artTop = B.listTop - RAID_ROWS * ROW_H - G.GAP
    B.art = J.buildArt(B, artTop)
    local headerTop = artTop - J.ART_H - G.GAP
    B.header = W.SectionHeader(B, "", false)
    B.header:SetPoint("TOPLEFT", 0, headerTop)
    B.header:SetPoint("TOPRIGHT", -132, headerTop)
    B.way = W.Button(B, L["Wegpunkt"], 120, function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    W.Row(B, { B.way }, T.CHIP_GAP, 0, headerTop - 1, { right = true })
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Raids."])
    B.detail = J.buildDetail(B, DETAIL_ROWS)
    B.detail:SetPoint("TOPLEFT", 0, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, headerTop - T.HEADER_H - G.GAP)
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
    B.list:SetItems(list)
    B.entry = e
    J.fillArt(B, e)
    if e then B.art.info:SetText(("Raid%s · %s"):format(e.size and (" " .. e.size) or "", fitText(e))) end
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
    if ns.ShowPage then ns.ShowPage("raidjournal") end
    local main, map = _G.AmisiaFrame, _G.WorldMapFrame
    if main and map and map.IsShown and map:IsShown() and ns.MapLowerMain then
        ns.MapLowerMain(map, main)
        if map.Raise then map:Raise() end
    end
    return main ~= nil and main:IsShown() and true or false
end

ns.RegisterPanel{ key = "raidjournal", label = "Raids", icon = ICON, order = 52, group = "gear",
    available = function() return ns.Gear.Available() end,
    create = create, refresh = refresh }

-- the own raid IDs were read again: the ID column
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
