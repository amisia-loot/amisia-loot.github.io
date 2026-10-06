-- Amisia main window in the look of Forever's profession window: the client's portrait frame, a
-- status bar with the recording state, a list of the registered pages in collapsible sections on
-- the left, the page itself in an inset on the right, and side tabs on the right edge for the side
-- windows. Pages are built the first time they are opened and refreshed only while shown.
local ADDON, ns = ...

local W = ns.W
local WIDTH, HEIGHT = 806, 560
local NAV_W, NAV_MAX, HEAD_MAX = 164, 16, 4
local HEAD_H, ROW_H, GAP, INDENT = 25, 22, 4, 8
local DOT = "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:10:10:0:0|t "
local PORTRAIT = "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia"

local F, nav, content, statusText, pauseBtn
local built, current = {}, nil
local navButtons, navHeaders = {}, {}
local sideTabs = {}

-- The side windows the tabs on the right edge open and close, top to bottom.
local SIDE_TABS = {
    { key = "gear", label = "Ausrüstungstabelle", icon = "Interface\\Icons\\INV_Chest_Chain_05", frame = "AmisiaGearFrame",
      visible = function() return ns.Gear ~= nil and ns.Gear.Available() and ns.ToggleGearFrame ~= nil end,
      toggle = function() ns.ToggleGearFrame() end },
    { key = "rolls", label = "Rolls", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", frame = "AmisiaRollFrame",
      visible = function() return ns.IsOfficerView() and ns.ToggleRollFrame ~= nil end,
      toggle = function() ns.ToggleRollFrame() end },
    { key = "softres", label = "Soft-Reserve-Import", icon = "Interface\\Icons\\INV_Scroll_03", frame = "AmisiaSoftResFrame",
      visible = function() return ns.IsOfficerView() and ns.ToggleSoftResFrame ~= nil end,
      toggle = function() ns.ToggleSoftResFrame() end },
}

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

-- The collapsed sections stay (settings.window.collapsed), only the position goes.
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

-- The page list: per section of ns.PANEL_GROUPS with a visible page a bar, under it the visible
-- pages as indented rows unless the section is collapsed; 4 px after each section. F.navOrder
-- holds what is shown, top to bottom ({ header = bar } or { button = row }).
local function updateNav()
    local collapsed = windowState().collapsed or {}
    local order, y, usedRows, usedHeads = {}, 0, 0, 0
    for _, g in ipairs(ns.PANEL_GROUPS) do
        local pages = {}
        for _, p in ipairs(ns.panels) do
            if ns.PanelGroup(p) == g.key and ns.Visible(p) then pages[#pages + 1] = p end
        end
        local h = #pages > 0 and navHeaders[usedHeads + 1]
        if h then
            usedHeads = usedHeads + 1
            if #order > 0 then y = y - GAP end
            h.group = g.key
            -- a collapsed section hides its rows, so its bar names the open page in grey
            local openPage
            if collapsed[g.key] then
                for _, p in ipairs(pages) do if p.key == current then openPage = p end end
            end
            h:SetHeaderText(openPage and (g.label .. " |cff8f86a3\194\183 " .. openPage.label .. "|r") or g.label)
            h:SetCollapsed(collapsed[g.key] and true or false)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, y)
            h:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, y)
            h:Show()
            order[#order + 1] = { header = h }
            y = y - HEAD_H
            if not collapsed[g.key] then
                for _, p in ipairs(pages) do
                    local b = navButtons[usedRows + 1]
                    if not b then break end
                    usedRows = usedRows + 1
                    b.key = p.key
                    b.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    b.label:SetText(p.label)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", nav, "TOPLEFT", INDENT, y)
                    if p.key == current then b.sel:Show() else b.sel:Hide() end
                    b:Show()
                    order[#order + 1] = { button = b }
                    y = y - ROW_H
                end
            end
        end
    end
    for i = usedRows + 1, NAV_MAX do navButtons[i]:Hide() end
    for i = usedHeads + 1, HEAD_MAX do navHeaders[i]:Hide() end
    F.navOrder = order
end

local function toggleGroup(group, isCollapsed)
    if not group then return end
    local w = windowState()
    w.collapsed = w.collapsed or {}
    w.collapsed[group] = isCollapsed and true or nil
    updateNav()
end

-- Shows, places (one under the other, no gaps) and marks the side tabs. Runs in ns.Refresh and
-- whenever a side window shows or hides (each window calls it through W.Window's onVisibility, so
-- the windows need not know this file).
function ns.UpdateSideTabs()
    if not F then return end
    local prev, firstShown
    for _, def in ipairs(SIDE_TABS) do
        local tab = sideTabs[def.key]
        if tab then
            local win = _G[def.frame]
            if def.visible() then
                firstShown = firstShown or tab
                tab:ClearAllPoints()
                if prev then
                    tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
                else
                    tab:SetPoint("TOPLEFT", F, "TOPRIGHT", 0, -60)
                end
                tab:Show()
                prev = tab
            else
                tab:Hide()
            end
            tab:SetChecked(win ~= nil and win:IsShown() and true or false)
        end
    end
    -- the tabs hang outside the frame on the right: keep them on the screen when moving it, but only
    -- while at least one is shown
    if F.SetClampRectInsets then F:SetClampRectInsets(0, firstShown and firstShown:GetWidth() or 0, 0, 0) end
end

local function navRow()
    local b = CreateFrame("Button", nil, nav)
    b:SetSize(NAV_W - INDENT, ROW_H)
    b.sel = W.SelectBar(b)
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetAllPoints()
    if W.HasAtlas("Professions_Recipe_Hover") then
        b.hover:SetAtlas("Professions_Recipe_Hover")
        b.hover:SetAlpha(0.5)
    else
        b.hover:SetColorTexture(1, 1, 1, 0.08)
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.label = W.Text(b, "GameFontHighlight", 130)
    b.label:SetPoint("LEFT", 26, 0)
    b:SetScript("OnClick", function(self) ns.ShowPage(self.key) end)
    b:Hide()
    return b
end

local function navHeader()
    local h
    h = W.SectionHeader(nav, "", true, function(isCollapsed) toggleGroup(h.group, isCollapsed) end)
    h:Hide()
    return h
end

-- A side tab as on the profession window (LargeSideTabButtonTemplate); nil without the template,
-- the side windows stay reachable from the pages and the quick menu.
local function sideTab(def)
    local ok, tab = pcall(CreateFrame, "Frame", nil, F, "LargeSideTabButtonTemplate")
    if not ok or not tab or not tab.SetCustomOnMouseUpHandler or not tab.Icon or not tab.SetChecked then
        if ok and tab then tab:Hide() end
        return nil
    end
    tab.fillToInterior = true
    tab.tooltipText = def.label
    tab.Icon:SetTexture(def.icon)
    tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
        if button ~= "LeftButton" or not upInside then return end
        def.toggle()
        ns.UpdateSideTabs()
    end)
    tab:Hide()
    return tab
end

local function build()
    F = W.Window("AmisiaFrame", WIDTH, HEIGHT, { portrait = PORTRAIT, strata = "FULLSCREEN",
        title = "Amisia |cff8f86a3" .. (ns.VERSION or "") .. "|r", background = "Profession-Background-Overview",
        onShow = function(self)
            if self.Raise then self:Raise() end
            ns.Refresh()
        end,
        onDragStop = function() savePosition() end })
    restorePosition()
    ns.ApplyScale()

    -- the head: the recording state as plain text between the portrait and the button, on the
    -- frame's own ground (a dark bar there did not fit the window's look)
    local BAR_W = WIDTH - 66 - 10 - 110 - 12
    local bar = CreateFrame("Frame", nil, F)
    bar:SetSize(BAR_W, 22)
    bar:SetPoint("TOPLEFT", 66, -26)
    statusText = W.Text(bar, "GameFontHighlight", BAR_W - 20)
    statusText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    statusText:SetJustifyH("CENTER")
    if statusText.SetShadowOffset then statusText:SetShadowOffset(1, -1) end
    pauseBtn = W.Button(F, "Pausieren", 110, function() ns.SetEnabled(not ns.IsEnabled()) end)
    pauseBtn:SetPoint("TOPRIGHT", -10, -26)

    -- the page list in an inset with the recipe list's ground, the page in an inset beside it
    local listInset = W.Inset(F)
    listInset:SetPoint("TOPLEFT", 6, -62)
    listInset:SetPoint("BOTTOMLEFT", 6, 6)
    listInset:SetWidth(176)
    listInset.fill("Professions-background-summarylist")
    local contentInset = W.Inset(F)
    contentInset:SetPoint("TOPLEFT", 184, -62)
    contentInset:SetPoint("BOTTOMRIGHT", -6, 6)

    nav = CreateFrame("Frame", nil, listInset)
    nav:SetPoint("TOPLEFT", 6, -6)
    nav:SetPoint("BOTTOMRIGHT", -6, 6)
    for i = 1, HEAD_MAX do navHeaders[i] = navHeader() end
    for i = 1, NAV_MAX do navButtons[i] = navRow() end

    -- 602 x 478, as before: the pages keep their layout
    content = CreateFrame("Frame", nil, contentInset)
    content:SetPoint("TOPLEFT", 7, -7)
    content:SetPoint("BOTTOMRIGHT", -7, 7)

    for _, def in ipairs(SIDE_TABS) do
        local tab = sideTab(def)
        if tab then sideTabs[def.key] = tab end
    end
    -- test hooks and the parts the layout tests read
    F.statusBar, F.statusText, F.pauseBtn = bar, statusText, pauseBtn
    F.listInset, F.contentInset, F.nav, F.content = listInset, contentInset, nav, content
    F.sideTabs, F.navOrder = sideTabs, {}
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
    ns.UpdateSideTabs()
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
