-- Amisia minimap button and addon compartment entry: left click opens the Amisia window, right click
-- a quick menu with the pages and the recording switch. Drag the button around the minimap;
-- /amisia minimap hides or shows it.
local ADDON, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\Amisia\\Media\\Icons\\Minimap"
local DEFAULT_ANGLE = 200
local button

local function settings()
    AmisiaDB.settings.minimap = AmisiaDB.settings.minimap or {}
    local m = AmisiaDB.settings.minimap
    m.angle = tonumber(m.angle) or DEFAULT_ANGLE
    return m
end

local function gearAvailable()
    return ns.Gear and ns.Gear.Available() and ns.ShowGear
end

function ns.MinimapMenuEntries()
    local officer = ns.IsOfficerView()
    local e = {}
    if gearAvailable() then
        e[#e + 1] = { L["Ausrüstung"], function() ns.ShowGear("goals") end }
        if ns.ToggleGearFrame then
            e[#e + 1] = { L["Ausrüstungstabelle"], function() ns.ToggleGearFrame() end }
        end
        -- the map page goes with the gear page
        if ns.ShowMap and ns.Visible(ns.Panel("map")) then
            e[#e + 1] = { L["Karte"], function() ns.ShowMap() end }
        end
    end
    if officer then e[#e + 1] = { "Rolls", function() ns.ShowPage("rolls") end } end
    if officer then e[#e + 1] = { L["Vergaben"], function() ns.ShowPage("awards") end } end
    e[#e + 1] = { L["Soft-Reserves"], function() ns.ShowPage("softres") end }
    e[#e + 1] = { L["Raid-Log"], function() ns.ShowPage("raidlog") end }
    if officer then e[#e + 1] = { "Export", function() ns.ShowPage("export") end } end
    e[#e + 1] = { L["Einstellungen"], function() ns.ShowPage("settings") end }
    e[#e + 1] = { ns.IsEnabled() and L["Aufnahme pausieren"] or L["Aufnahme fortsetzen"], function() ns.SetEnabled(not ns.IsEnabled()) end }
    return e
end

-- What both the button and the compartment entry do on a click.
local function click(mouse)
    if mouse == "RightButton" then
        ns.W.Menu((button and button:IsShown()) and button or UIParent, ns.MinimapMenuEntries())
    else
        ns.ToggleMain()
    end
end

local function tooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Amisia |cff8f86a3" .. (ns.VERSION or "") .. "|r", 0.89, 0.72, 0.34)
    local act = ns.Active and ns.Active()
    if act then
        GameTooltip:AddLine(L["Aufnahme läuft: %s"]:format(act.zone or "?"), 0.31, 0.75, 0.48)
    elseif ns.IsEnabled and not ns.IsEnabled() then
        GameTooltip:AddLine(L["Aufnahme pausiert"], 0.88, 0.64, 0.27)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Linksklick"], L["Amisia-Fenster"], 1, 1, 1, 0.8, 0.8, 0.8)
    GameTooltip:AddDoubleLine(L["Rechtsklick"], L["Schnellmenü"], 1, 1, 1, 0.8, 0.8, 0.8)
    if owner == button then
        GameTooltip:AddDoubleLine(L["Ziehen"], L["Verschieben"], 1, 1, 1, 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function place()
    if not button then return end
    local angle = math.rad(settings().angle)
    local radius = (Minimap:GetWidth() or 140) / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging, the button follows the cursor around the minimap's edge.
local function follow()
    local mx, my = Minimap:GetCenter()
    if not mx then return end
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    settings().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    place()
end

local function build()
    if button or not Minimap then return end
    button = CreateFrame("Button", "AmisiaMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER", 0, 1)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ICON)
    button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouse) click(mouse) end)
    button:SetScript("OnEnter", function(self) tooltip(self, "ANCHOR_LEFT") end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", follow)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    place()
    ns.ShowMinimapButton(ns.Get("ui.minimap"))
end
ns.OnEvent("PLAYER_LOGIN", build)

function ns.ShowMinimapButton(on)
    if not button then build() end
    if not button then return end
    if on then button:Show() else button:Hide() end
end

ns.RegisterSlash("minimap", { desc = L["Minimap-Button ein- oder ausblenden"], run = function()
    ns.Set("ui.minimap", not ns.Get("ui.minimap"))
    ns.msg(ns.Get("ui.minimap") and L["Minimap-Button eingeblendet."] or L["Minimap-Button ausgeblendet. /amisia minimap holt ihn zurück."])
end })

-- The addon compartment (the addon menu at the minimap) calls these by name, from the TOC.
function Amisia_OnAddonCompartmentClick(_, mouse) click(mouse) end
function Amisia_OnAddonCompartmentEnter(_, frame) tooltip(frame, "ANCHOR_LEFT") end
function Amisia_OnAddonCompartmentLeave() GameTooltip:Hide() end

ns._minimap = { place = place, follow = follow, button = function() return button end }
