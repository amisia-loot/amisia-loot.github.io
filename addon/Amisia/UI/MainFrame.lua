-- Amisia main window in the look of Forever's profession window: the client's portrait frame, a
-- status bar with the recording state, a search box and under it the pages of the chosen tab on the
-- left, the page itself in an inset on the right, the client's panel tabs under the window (one per
-- page group, ns.PANEL_GROUPS; D-45) and side tabs on the right edge for the side windows. Typing
-- two characters into the search box turns the page list into the results (UI/Search.lua). Pages
-- are built the first time they are opened and refreshed only while shown.
local ADDON, ns = ...
local L = ns.L

local W, T = ns.W, ns.Theme
local M = T.MAIN
local WIDTH, HEIGHT = M.W, M.H
local NAV_W, NAV_MAX = M.NAV_W, M.NAV_ROWS
local ROW_H, INDENT = M.NAV_ROW_H, M.NAV_INDENT
local DOT = "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:10:10:0:0|t "
local PORTRAIT = "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia"

local F, nav, content, statusText, pauseBtn, viewBtn, search, results, noHits
local built, current = {}, nil
local navButtons = {}
local sideTabs = {}
local bottomTabs = {}     -- group key -> the tab under the window
local query = ""          -- the search text, trimmed and lower case

-- The side windows the tabs on the right edge open and close, top to bottom.
local SIDE_TABS = {
    { key = "gear", label = L["Ausrüstungstabelle"], icon = "Interface\\Icons\\INV_Chest_Chain_05", frame = "AmisiaGearFrame",
      visible = function() return ns.Gear ~= nil and ns.Gear.Available() and ns.ToggleGearFrame ~= nil end,
      toggle = function() ns.ToggleGearFrame() end },
    { key = "talents", label = L["Talentrechner"], icon = "Interface\\Icons\\Ability_Marksmanship", frame = "AmisiaTalentFrame",
      visible = function() return ns.Talents ~= nil and ns.Talents.Available() and ns.ToggleTalentFrame ~= nil end,
      toggle = function() ns.ToggleTalentFrame() end },
    { key = "rolls", label = "Rolls", icon = "Interface\\Icons\\INV_Misc_Dice_01", frame = "AmisiaRollFrame",
      visible = function() return ns.IsOfficerView() and ns.ToggleRollFrame ~= nil end,
      toggle = function() ns.ToggleRollFrame() end },
    { key = "softres", label = L["Soft-Reserve-Import"], icon = "Interface\\Icons\\INV_Scroll_03", frame = "AmisiaSoftResFrame",
      visible = function() return ns.IsOfficerView() and ns.ToggleSoftResFrame ~= nil end,
      toggle = function() ns.ToggleSoftResFrame() end },
}

-- settings.window: the place (point, rel, x, y), the last tab (tab: a group key) and the last page
-- of each tab (pages: { [group] = page key }); the collapsed sections of before 2.27.0 are dropped.
local function windowState()
    AmisiaDB.settings.window = type(AmisiaDB.settings.window) == "table" and AmisiaDB.settings.window or {}
    local w = AmisiaDB.settings.window
    w.collapsed = nil
    if type(w.pages) ~= "table" then w.pages = {} end
    if w.tab ~= nil and type(w.tab) ~= "string" then w.tab = nil end
    return w
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

-- The remembered tab and pages stay (settings.window.tab, pages), only the position goes.
function ns.ResetPositions()
    windowState().point = nil
    if F then restorePosition() end
    if ns.ResetGearPosition then ns.ResetGearPosition() end
    if ns.ResetRollWindowPosition then ns.ResetRollWindowPosition() end
    if ns.ResetTalentWindowPosition then ns.ResetTalentWindowPosition() end
    if ns.ResetRaidCalendarPosition then ns.ResetRaidCalendarPosition() end
    ns.msg(L["Fensterposition zurückgesetzt."])
end

local function reportError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function errorPage(parent, err)
    local f = CreateFrame("Frame", nil, parent)
    local t = W.Text(f, T.FONT.title, 560, true)
    t:SetPoint("TOPLEFT", 10, -10)
    t:SetText(L["Diese Seite konnte nicht geladen werden."] .. "\n|cff8f86a3" .. (tostring(err):match("^[^\n]*") or "?") .. "|r")
    return f
end

local function updateHeader()
    local act = ns.Active and ns.Active()
    if act then
        local late = ns.LateCount(act)
        statusText:SetText(("%s|cff4fbf7a%s|r · %s%s"):format(DOT, act.zone or "?", L["%d Raider"]:format(ns.MemberCount(act)),
            late > 0 and (" · |cffe0a344" .. L["%d zu spät"]:format(late) .. "|r") or ""))
    elseif ns.IsEnabled() then
        statusText:SetText("|cff8f86a3" .. L["Keine Aufnahme, startet im Raid"] .. "|r")
    else
        statusText:SetText("|cffe0a344" .. L["Aufnahme pausiert"] .. "|r")
    end
    pauseBtn:SetText(ns.IsEnabled() and L["Pausieren"] or L["Fortsetzen"])
    viewBtn:SetText(ns.IsOfficerView() and L["Offiziersansicht"] or L["Raider-Ansicht"])
end

-- The view switch in the head: a click shows the other view (and sets it, as the setting
-- "Ansicht" does); "Automatisch" stays in the settings and in /amisia ansicht auto.
function ns.ToggleView()
    ns.Set("ui.view", ns.IsOfficerView() and "raider" or "officer")
    ns.Refresh()
end

local function groupOf(key)
    local p = ns.Panel(key)
    return p and ns.PanelGroup(p) or nil
end

-- The visible pages of a tab, in their order.
local function pagesOf(group)
    local out = {}
    for _, p in ipairs(ns.panels) do
        if ns.PanelGroup(p) == group and ns.Visible(p) then out[#out + 1] = p end
    end
    return out
end

-- The page list: the visible pages of the open page's tab, one row each from the top; the rows are
-- 20 high, lower (NAV_ROW_MIN at least) when more than fit the list. F.navOrder holds what is shown,
-- top to bottom ({ button = row }).
local function updateNav()
    local order, y = {}, 0
    local pages = pagesOf(groupOf(current))
    local rowH = ROW_H
    if #pages > 0 then
        rowH = math.max(M.NAV_ROW_MIN, math.min(ROW_H, math.floor(M.NAV_LIST_H / #pages)))
    end
    local used = 0
    for _, p in ipairs(pages) do
        local b = navButtons[used + 1]
        if not b then break end
        used = used + 1
        b.key = p.key
        b.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.label:SetText(p.label)
        b:SetHeight(rowH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", INDENT, y)
        if p.key == current then b.sel:Show() else b.sel:Hide() end
        b:Show()
        order[#order + 1] = { button = b }
        y = y - rowH
    end
    for i = used + 1, NAV_MAX do navButtons[i]:Hide() end
    F.navOrder, F.navRowH = order, rowH
end

---------------------------------------------------------------------------
-- The tabs under the window
---------------------------------------------------------------------------
-- The page a tab opens: the one last open there when it is still shown, else its first.
local function tabPage(group)
    local pages = pagesOf(group)
    local last = windowState().pages[group]
    for _, p in ipairs(pages) do
        if p.key == last then return p.key end
    end
    return pages[1] and pages[1].key or nil
end

-- Opens the tab of group (its last page); nothing when it has no visible page.
function ns.ShowTab(group)
    local key = tabPage(group)
    if key then ns.ShowPage(key) end
end

-- The tab's look: the client's PanelTemplates helpers when there, else the slices by hand.
local function selectTab(tab, on)
    if tab.flat then
        tab.ground:SetAlpha(on and 0.9 or 0.45)
        tab.Text:SetTextColor(on and 1 or T.GOLD[1], on and 1 or T.GOLD[2], on and 1 or T.GOLD[3])
        tab:SetEnabled(not on)
    elseif on and PanelTemplates_SelectTab then
        PanelTemplates_SelectTab(tab)
    elseif not on and PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(tab)
    end
    tab.selected = on and true or false
end

local function sizeTab(tab)
    if not tab.flat and PanelTemplates_TabResize then
        PanelTemplates_TabResize(tab, 0, nil, M.BTAB_MIN_W)
    else
        local w = math.max(M.BTAB_MIN_W, (tab.Text:GetStringWidth() or 0) + 20)
        tab.Text:SetWidth(w - 20)
        tab:SetWidth(w)
    end
end

-- A tab under the window: the client's panel tab (PanelTabButtonTemplate, as under the character
-- window); without the template a flat tab of the same size.
local function bottomTab(g)
    local ok, tab = pcall(CreateFrame, "Button", nil, F, "PanelTabButtonTemplate")
    if not ok or not tab or not tab.Text or not tab.Left or not tab.LeftActive then
        if ok and tab then tab:Hide() end
        tab = CreateFrame("Button", nil, F)
        tab:SetHeight(M.BTAB_H - 4)
        tab.ground = W.Flat(tab, 0.18, 0.08, 0.05, 0.45)
        tab.Text = W.Text(tab, "GameFontNormalSmall")
        tab.Text:SetPoint("CENTER", 0, 2)
        tab.flat = true
    end
    tab.group = g.key
    tab:SetText(g.label)
    if tab.flat then tab.Text:SetText(g.label) end
    -- a click while the search shows its results clears it: the tab's page list comes back
    tab:SetScript("OnClick", function(self)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        ns.ClearSearch()
        ns.ShowTab(self.group)
    end)
    tab:Hide()
    return tab
end

-- The window's clamp: the side tabs on the right and the bottom tabs below stay on the screen.
local function clamp()
    if not F.SetClampRectInsets then return end
    local right = 0
    for _, def in ipairs(SIDE_TABS) do
        local tab = sideTabs[def.key]
        if tab and tab:IsShown() then right = tab:GetWidth() break end
    end
    local below = 0
    for _, g in ipairs(ns.PANEL_GROUPS) do
        local tab = bottomTabs[g.key]
        if tab and tab:IsShown() then below = M.BTAB_H - M.BTAB_Y break end
    end
    F:SetClampRectInsets(0, right, 0, -below)
end

-- Shows the tabs whose group has a visible page, left to right without gaps, the open page's selected
-- (and, while the search shows its results, still clickable: a click brings its page list back).
local function updateTabs()
    local searching = #query >= M.SEARCH_MIN
    local open = groupOf(current)
    local prev
    F.tabOrder = {}
    for _, g in ipairs(ns.PANEL_GROUPS) do
        local tab = bottomTabs[g.key]
        if tab then
            if #pagesOf(g.key) > 0 then
                tab:ClearAllPoints()
                if prev then
                    tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", M.BTAB_GAP, 0)
                else
                    tab:SetPoint("TOPLEFT", F, "BOTTOMLEFT", M.BTAB_X, M.BTAB_Y)
                end
                tab:Show()
                sizeTab(tab)
                selectTab(tab, g.key == open)
                if searching and g.key == open then tab:SetEnabled(true) end
                F.tabOrder[#F.tabOrder + 1] = g.key
                prev = tab
            else
                tab:Hide()
            end
        end
    end
    clamp()
end

---------------------------------------------------------------------------
-- The search over the page list (UI/Search.lua finds, this shows)
---------------------------------------------------------------------------
local function showResults()
    local searching = #query >= M.SEARCH_MIN
    nav:SetShown(not searching)
    results:SetShown(searching)
    if not searching then
        noHits:Hide()
        return
    end
    local rows = {}
    for _, grp in ipairs(ns.Search(query)) do
        rows[#rows + 1] = { head = grp.label, count = #grp.hits }
        for _, hit in ipairs(grp.hits) do rows[#rows + 1] = hit end
    end
    results.offset = 0
    results:SetItems(rows)
    noHits:SetShown(#rows == 0)
end

local function setQuery(text)
    text = (tostring(text or ""):match("^%s*(.-)%s*$") or ""):lower()
    if text == query then return end
    query = text
    showResults()
    if F and F:IsShown() then updateTabs() end
end

-- Clears the search box (Escape, the clear button, a click on a result).
function ns.ClearSearch()
    if not search then return end
    search:SetText("")
    search:ClearFocus()
    setQuery("")
end

local function buildResult(r)
    r.bar = W.SectionHeader(r, "", false)
    r.bar:SetPoint("TOPLEFT", 0, 0)
    r.bar:SetPoint("BOTTOMRIGHT", 0, 0)
    r.bar:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(M.RES_ICON, M.RES_ICON)
    r.icon:SetPoint("LEFT", 4, 0)
    r.label = W.Text(r, T.FONT.text, NAV_W - T.SCROLL_ROOM - M.NAV_LABEL_X + 4)
    r.label:SetPoint("LEFT", M.NAV_LABEL_X - 4, 0)
    r:SetScript("OnClick", function(self)
        local hit = self.item
        if not hit or hit.head or not hit.run then return end
        ns.ClearSearch()
        hit.run()
    end)
    r:SetScript("OnEnter", function(self)
        local hit = self.item
        if not hit or hit.head then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if hit.item and GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(hit.item)
        else
            GameTooltip:AddLine(hit.text, 1, 0.82, 0)
            if hit.tip then GameTooltip:AddLine(hit.tip, 0.85, 0.85, 0.85, true) end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fillResult(r, hit)
    if hit.head then
        r.bar:SetHeaderText(("%s |cffffffff%d|r"):format(hit.head, hit.count))
        r.bar:Show()
        r.bg:Hide()
        r.icon:Hide()
        r.label:SetText("")
        return
    end
    r.bar:Hide()
    r.bg:Show()
    r.icon:SetTexCoord(0, 1, 0, 1)
    if hit.atlas and W.HasAtlas(hit.atlas) then
        r.icon:SetAtlas(hit.atlas)
    else
        r.icon:SetTexture(hit.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    r.icon:Show()
    r.label:SetText(hit.label or hit.text)
end

-- The client fills the tab's interior with the icon (fillToInterior, through SetChecked); the
-- player found that too large: pull the icon in by M.TAB_ICON_INSET on every side. Done after each
-- SetChecked, and only on the anchors the client set (not twice on ours).
local function insetIcon(tab)
    local icon, d = tab.Icon, M.TAB_ICON_INSET or 0
    if not icon or d <= 0 or not icon.GetNumPoints then return end
    local n = icon:GetNumPoints()
    local p1, _, _, x1, y1 = icon:GetPoint(1)
    local w1, h1 = icon:GetSize()
    -- what we left last time, unchanged: done (the size counts only for an icon on one point; on
    -- two the client works it out later, and comparing it would pull the icon in again and again)
    local was = tab.insetAt
    if n == 0 or (was and was[1] == p1 and was[2] == x1 and was[3] == y1 and was[6] == n
        and (n >= 2 or (was[4] == w1 and was[5] == h1))) then return end
    if n >= 2 then
        local pts = {}
        for i = 1, n do pts[i] = { icon:GetPoint(i) } end
        icon:ClearAllPoints()
        for _, p in ipairs(pts) do
            local point, rel, relPoint, x, y = p[1], p[2], p[3], p[4] or 0, p[5] or 0
            local dx = point:find("LEFT") and d or point:find("RIGHT") and -d or 0
            local dy = point:find("TOP") and -d or point:find("BOTTOM") and d or 0
            icon:SetPoint(point, rel, relPoint, x + dx, y + dy)
        end
    elseif (w1 or 0) > 2 * d and (h1 or 0) > 2 * d then
        icon:SetSize(w1 - 2 * d, h1 - 2 * d)
    end
    local p2, _, _, x2, y2 = icon:GetPoint(1)
    local w2, h2 = icon:GetSize()
    tab.insetAt = { p2, x2, y2, w2, h2, n }
end

-- Shows, places (one under the other, no gaps) and marks the side tabs. Runs in ns.Refresh and
-- whenever a side window shows or hides (each window calls it through W.Window's onVisibility, so
-- the windows need not know this file).
function ns.UpdateSideTabs()
    if not F then return end
    local prev
    for _, def in ipairs(SIDE_TABS) do
        local tab = sideTabs[def.key]
        if tab then
            local win = _G[def.frame]
            if def.visible() then
                tab:ClearAllPoints()
                if prev then
                    tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -M.TAB_GAP)
                else
                    tab:SetPoint("TOPLEFT", F, "TOPRIGHT", 0, -M.TAB_Y)
                end
                tab:Show()
                prev = tab
            else
                tab:Hide()
            end
            tab:SetChecked(win ~= nil and win:IsShown() and true or false)
            insetIcon(tab)
        end
    end
    -- the tabs hang outside the frame on the right: keep them on the screen when moving it, but only
    -- while at least one is shown (and the bottom tabs below it)
    clamp()
end

local function navRow()
    local b = CreateFrame("Button", nil, nav)
    b:SetSize(NAV_W - INDENT, ROW_H)
    b.sel = W.SelectBar(b)
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetAllPoints()
    if W.HasAtlas("Professions_Recipe_Hover") then
        b.hover:SetAtlas("Professions_Recipe_Hover")
        b.hover:SetAlpha(T.HOVER_ALPHA)
    else
        b.hover:SetColorTexture(1, 1, 1, 0.08)
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(M.NAV_ICON, M.NAV_ICON)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.label = W.Text(b, T.FONT.body, M.NAV_LABEL_W)
    b.label:SetPoint("LEFT", M.NAV_LABEL_X, 0)
    b:SetScript("OnClick", function(self) ns.ShowPage(self.key) end)
    b:Hide()
    return b
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
            -- the setup offer (Setup.lua) at the first open after a login
            ns.Fire("MAIN_SHOWN")
        end,
        onDragStop = function() savePosition() end })
    restorePosition()
    ns.ApplyScale()

    -- the head: the recording state as plain text between the portrait and the button, on the
    -- frame's own ground (a dark bar there did not fit the window's look)
    local BAR_W = WIDTH - M.HEAD_X - 10 - M.PAUSE_W - M.VIEW_GAP - M.VIEW_W - 12
    local bar = CreateFrame("Frame", nil, F)
    bar:SetSize(BAR_W, M.HEAD_H)
    bar:SetPoint("TOPLEFT", M.HEAD_X, -M.HEAD_Y)
    statusText = W.Text(bar, T.FONT.body, BAR_W - 20)
    statusText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    statusText:SetJustifyH("CENTER")
    if statusText.SetShadowOffset then statusText:SetShadowOffset(1, -1) end
    pauseBtn = W.Button(F, L["Pausieren"], M.PAUSE_W, function() ns.SetEnabled(not ns.IsEnabled()) end)
    pauseBtn:SetPoint("TOPRIGHT", -10, -M.HEAD_Y)
    viewBtn = W.Button(F, L["Raider-Ansicht"], M.VIEW_W, function() ns.ToggleView() end)
    viewBtn:SetPoint("TOPRIGHT", pauseBtn, "TOPLEFT", -M.VIEW_GAP, 0)
    W.Tooltip(viewBtn, L["Ansicht"], L["Ein Klick zeigt die andere Ansicht: Raider sehen ihre Seiten, Offiziere auch Raids, Rolls, Punkte und den Export. Für die Gilde bist du dadurch kein Offizier; Rechte prüft Amisia am Rang. Die Ansicht nach Rang (Automatisch) stellst du unter Einstellungen, Oberfläche ein."])

    -- the page list in an inset with the recipe list's ground, the page in an inset beside it
    local listInset = W.Inset(F)
    listInset:SetPoint("TOPLEFT", M.MARGIN, -M.TOP)
    listInset:SetPoint("BOTTOMLEFT", M.MARGIN, M.MARGIN)
    listInset:SetWidth(M.LIST_W)
    listInset.fill("Professions-background-summarylist")
    local contentInset = W.Inset(F)
    contentInset:SetPoint("TOPLEFT", M.CONTENT_X, -M.TOP)
    contentInset:SetPoint("BOTTOMRIGHT", -M.MARGIN, M.MARGIN)

    -- the search box at the list's top, the pages (or the results) under it
    search = W.SearchBox(listInset, NAV_W, nil)
    search:SetPoint("TOPLEFT", M.INNER, -M.INNER)
    search:HookScript("OnTextChanged", function(self) setQuery(self:GetText()) end)
    search:SetScript("OnEscapePressed", function() ns.ClearSearch() end)
    if search.clearButton then search.clearButton:HookScript("OnClick", function() ns.ClearSearch() end) end
    local listTop = M.INNER + T.FIELD_H + M.SEARCH_GAP
    nav = CreateFrame("Frame", nil, listInset)
    nav:SetPoint("TOPLEFT", M.INNER, -listTop)
    nav:SetPoint("BOTTOMRIGHT", -M.INNER, M.INNER)
    for i = 1, NAV_MAX do navButtons[i] = navRow() end
    results = W.List(listInset, M.RES_ROWS, M.RES_ROW_H, buildResult, fillResult)
    results:SetPoint("TOPLEFT", M.INNER, -listTop)
    results:SetWidth(NAV_W - T.SCROLL_ROOM)
    results:Hide()
    noHits = W.Text(listInset, T.FONT.hint, NAV_W - 8, true)
    noHits:SetPoint("TOP", results, "TOP", 0, -T.LAYOUT.EMPTY_Y)
    noHits:SetJustifyH("CENTER")
    noHits:SetText(L["Nichts gefunden."])
    noHits:Hide()

    -- 602 x 478, as before: the pages keep their layout
    content = CreateFrame("Frame", nil, contentInset)
    content:SetPoint("TOPLEFT", M.PAGE_PAD, -M.PAGE_PAD)
    content:SetPoint("BOTTOMRIGHT", -M.PAGE_PAD, M.PAGE_PAD)

    for _, def in ipairs(SIDE_TABS) do
        local tab = sideTab(def)
        if tab then sideTabs[def.key] = tab end
    end
    -- the client's tab mixin sizes its tabs again on show and on a display change by these fields of
    -- the parent: the same as Amisia's sizing
    F.tabPadding, F.minTabWidth = 0, M.BTAB_MIN_W
    for _, g in ipairs(ns.PANEL_GROUPS) do bottomTabs[g.key] = bottomTab(g) end
    -- test hooks and the parts the layout tests read
    F.statusBar, F.statusText, F.pauseBtn, F.viewBtn = bar, statusText, pauseBtn, viewBtn
    F.listInset, F.contentInset, F.nav, F.content = listInset, contentInset, nav, content
    F.sideTabs, F.navOrder, F.tabs, F.tabOrder = sideTabs, {}, bottomTabs, {}
    F.search, F.results, F.noHits = search, results, noHits
end

function ns.CurrentPage() return current end

-- Shows the page key (a page not shown now: the overview, else the first shown). chosen: the player
-- (or a command) asked for it, so it is remembered as its tab's page; a redirect is not (the page
-- before it stays the tab's page, and the tab follows what is shown).
local function showPage(key, chosen)
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
    -- the tab follows the page; both are remembered for the next open, the page only when asked for
    local w = windowState()
    w.tab = ns.PanelGroup(p)
    if chosen and p.key == key then w.pages[w.tab] = current end
    for k, frame in pairs(built) do
        if k ~= current then frame:Hide() end
    end
    if not built[current] then
        local ok, frame = pcall(p.create, content)
        if not ok or type(frame) ~= "table" then
            -- not passed to the error handler: the error page shows it and the window stays usable
            frame = errorPage(content, ok and L["create gab keinen Frame zurück"] or frame)
        end
        frame:SetAllPoints(content)
        built[current] = frame
    end
    built[current]:Show()
    if F:IsShown() then ns.Refresh() else F:Show() end
end

function ns.ShowPage(key) showPage(key, true) end

function ns.Refresh()
    if not F or not F:IsShown() then return end
    local p = ns.Panel(current)
    if not ns.Visible(p) then
        showPage("overview", false)
        return
    end
    updateHeader()
    updateNav()
    updateTabs()
    if #query >= M.SEARCH_MIN then showResults() end
    ns.UpdateSideTabs()
    local frame = built[current]
    if p.refresh and frame then
        local ok, err = pcall(p.refresh, frame)
        if not ok then reportError(err) end
    end
end

-- The page the window opens with: the open one, else the last of the last tab, else the overview.
local function startPage()
    if current then return current end
    local w = AmisiaDB and AmisiaDB.settings and windowState()
    return (w and w.tab and tabPage(w.tab)) or "overview"
end

function ns.ToggleMain()
    if F and F:IsShown() then F:Hide() else ns.ShowPage(startPage()) end
end

-- The old entry point: /amisia export and the minimap called it with the newest session.
function ns.Toggle(exportLatest)
    if exportLatest and ns.ShowExport then ns.ShowExport(true) else ns.ToggleMain() end
end

ns.Listen("SETTING", function() ns.Refresh() end)
ns.Listen("DATA_CHANGED", function() ns.Refresh() end)

local VIEW_WORDS = { offizier = "officer", officer = "officer", raider = "raider", auto = "auto", automatisch = "auto" }   -- l10n-ok: typed words
ns.RegisterSlash("ansicht", { en = "view", args = L["[offizier|raider|auto]"], desc = L["Offiziers- oder Raider-Ansicht"],
    run = function(rest)
        local word = (type(rest) == "string" and rest:match("^%s*(%S*)") or ""):lower()
        local view = VIEW_WORDS[word]
        if word ~= "" and not view then
            ns.msg(L["Aufruf: /amisia ansicht [offizier|raider|auto]"])
            return
        end
        if view then
            ns.Set("ui.view", view)
            if ns.Refresh then ns.Refresh() end
        end
        local set = ns.Get("ui.view")
        ns.msg(L["Ansicht: %s%s."]:format(ns.IsOfficerView() and L["Offizier"] or "Raider",
            set == "auto" and (" (" .. L["Automatisch"] .. ")") or ""))
    end })

ns.RegisterSlash("einstellungen", { en = "settings", aliases = { "optionen", "config" }, desc = L["Einstellungen öffnen"],
    run = function() ns.ShowPage("settings") end })
