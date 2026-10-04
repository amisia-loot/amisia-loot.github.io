-- Amisia main window: a header with the recording state, a sidebar of the registered pages and
-- the page itself. Pages are built the first time they are opened and refreshed only while shown.
local ADDON, ns = ...

local W = ns.W
local GOLD = W.GOLD
local WIDTH, HEIGHT, SIDE, NAV_MAX = 800, 540, 160, 14
local DOT = "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:10:10:0:0|t "

local F, nav, content, statusText, pauseBtn
local built, current = {}, nil
local navButtons = {}

local function windowState()
    AmisiaDB.settings.window = AmisiaDB.settings.window or {}
    return AmisiaDB.settings.window
end

local function savePosition()
    local point, _, rel, x, y = F:GetPoint()
    local w = windowState()
    w.point, w.rel, w.x, w.y = point, rel, x, y
end

local function restorePosition()
    local w = windowState()
    F:ClearAllPoints()
    if w.point then
        F:SetPoint(w.point, UIParent, w.rel or w.point, w.x or 0, w.y or 0)
    else
        F:SetPoint("CENTER")
    end
end

function ns.ApplyScale(v)
    if F then F:SetScale((v or ns.Get("ui.scale") or 100) / 100) end
end

function ns.ResetPositions()
    windowState().point = nil
    if F then restorePosition() end
    if ns.ResetGearPosition then ns.ResetGearPosition() end
    ns.msg("Fensterposition zurückgesetzt.")
end

local function reportError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function errorPage(parent, err)
    local f = CreateFrame("Frame", nil, parent)
    local t = W.Text(f, "GameFontNormal", 560, true)
    t:SetPoint("TOPLEFT", 10, -10)
    t:SetText("Diese Seite konnte nicht geladen werden.\n|cff8f86a3" .. (tostring(err):match("^[^\n]*") or "?") .. "|r")
    return f
end

local function updateHeader()
    local act = ns.Active and ns.Active()
    if act then
        local late = ns.LateCount(act)
        statusText:SetText(("%s|cff4fbf7a%s|r · %d Raider%s"):format(DOT, act.zone or "?", ns.MemberCount(act),
            late > 0 and (" · |cffe0a344" .. late .. " zu spät|r") or ""))
    elseif ns.IsEnabled() then
        statusText:SetText("|cff8f86a3Keine Aufnahme, startet im Raid|r")
    else
        statusText:SetText("|cffe0a344Aufnahme pausiert|r")
    end
    pauseBtn:SetText(ns.IsEnabled() and "Pausieren" or "Fortsetzen")
end

local function updateNav()
    local top, bottom = {}, {}
    for _, p in ipairs(ns.panels) do
        if ns.Visible(p) then
            if p.bottom then bottom[#bottom + 1] = p else top[#top + 1] = p end
        end
    end
    local used = 0
    local function place(p, anchor, y)
        used = used + 1
        local b = navButtons[used]
        if not b then return end
        b.key = p.key
        b.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.label:SetText(p.label)
        b:ClearAllPoints()
        b:SetPoint(anchor, nav, anchor, 0, y)
        if p.key == current then b.sel:Show() else b.sel:Hide() end
        b:Show()
    end
    for i, p in ipairs(top) do place(p, "TOPLEFT", -(i - 1) * 30) end
    for i, p in ipairs(bottom) do place(p, "BOTTOMLEFT", (#bottom - i) * 30) end
    for i = used + 1, NAV_MAX do navButtons[i]:Hide() end
end

local function build()
    F = CreateFrame("Frame", "AmisiaFrame", UIParent)
    F:SetSize(WIDTH, HEIGHT)
    F:SetFrameStrata("FULLSCREEN")
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition() end)
    F:SetScript("OnShow", function(self)
        if self.Raise then self:Raise() end
        ns.Refresh()
    end)
    F:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaFrame") end
    W.Flat(F, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
    W.Border(F, GOLD[1], GOLD[2], GOLD[3], 0.6)
    restorePosition()
    ns.ApplyScale()

    local logo = F:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 12, -7)
    logo:SetTexture("Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia")
    local title = W.Text(F, "GameFontNormalLarge", 220)
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("Amisia |cff8f86a3" .. (ns.VERSION or "") .. "|r")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    pauseBtn = W.Button(F, "Pausieren", 100, function() ns.SetEnabled(not ns.IsEnabled()) end)
    pauseBtn:SetPoint("TOPRIGHT", -34, -12)
    statusText = W.Text(F, "GameFontHighlightSmall", 320)
    statusText:SetPoint("RIGHT", pauseBtn, "LEFT", -10, 0)
    statusText:SetJustifyH("RIGHT")
    local line = F:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    line:SetPoint("TOPLEFT", 10, -44)
    line:SetPoint("TOPRIGHT", -10, -44)
    line:SetHeight(1)

    nav = CreateFrame("Frame", nil, F)
    nav:SetPoint("TOPLEFT", 10, -52)
    nav:SetPoint("BOTTOMLEFT", 10, 10)
    nav:SetWidth(SIDE)
    for i = 1, NAV_MAX do
        local b = CreateFrame("Button", nil, nav)
        b:SetSize(SIDE, 28)
        b.sel = W.Flat(b, GOLD[1], GOLD[2], GOLD[3], 0.25, "BORDER")
        b.sel:Hide()
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 6, 0)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.label = W.Text(b, "GameFontNormal", SIDE - 36)
        b.label:SetPoint("LEFT", 32, 0)
        b:SetScript("OnClick", function(self) ns.ShowPage(self.key) end)
        b:Hide()
        navButtons[i] = b
    end
    local sep = F:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.2)
    sep:SetPoint("TOPLEFT", SIDE + 16, -52)
    sep:SetPoint("BOTTOMLEFT", SIDE + 16, 10)
    sep:SetWidth(1)

    content = CreateFrame("Frame", nil, F)
    content:SetPoint("TOPLEFT", SIDE + 26, -52)
    content:SetPoint("BOTTOMRIGHT", -12, 10)
end

function ns.CurrentPage() return current end

function ns.ShowPage(key)
    if not F then build() end
    local p = ns.Panel(key)
    if not ns.Visible(p) then p = ns.Panel("overview") end
    if not ns.Visible(p) then
        for _, other in ipairs(ns.panels) do
            if ns.Visible(other) then p = other break end
        end
    end
    if not p then return end
    current = p.key
    for k, frame in pairs(built) do
        if k ~= current then frame:Hide() end
    end
    if not built[current] then
        local ok, frame = pcall(p.create, content)
        if not ok or type(frame) ~= "table" then
            -- not passed to the error handler: the error page shows it and the window stays usable
            frame = errorPage(content, ok and "create gab keinen Frame zurück" or frame)
        end
        frame:SetAllPoints(content)
        built[current] = frame
    end
    built[current]:Show()
    if F:IsShown() then ns.Refresh() else F:Show() end
end

function ns.Refresh()
    if not F or not F:IsShown() then return end
    local p = ns.Panel(current)
    if not ns.Visible(p) then
        ns.ShowPage("overview")
        return
    end
    updateHeader()
    updateNav()
    local frame = built[current]
    if p.refresh and frame then
        local ok, err = pcall(p.refresh, frame)
        if not ok then reportError(err) end
    end
end

function ns.ToggleMain()
    if F and F:IsShown() then F:Hide() else ns.ShowPage(current or "overview") end
end

-- The old entry point: /amisia export and the minimap called it with the newest session.
function ns.Toggle(exportLatest)
    if exportLatest and ns.ShowExport then ns.ShowExport(true) else ns.ToggleMain() end
end

ns.Listen("SETTING", function() ns.Refresh() end)
ns.Listen("DATA_CHANGED", function() ns.Refresh() end)

ns.RegisterSlash("einstellungen", { aliases = { "optionen", "config" }, desc = "Einstellungen öffnen",
    run = function() ns.ShowPage("settings") end })
