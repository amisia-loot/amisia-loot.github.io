-- Amisia main window in the look of Forever's profession window: the client's portrait frame, a
-- status bar with the recording state, on the left the side bar (D-68, D-70: a head with the logo, a
-- search box, every group as a heading with its pages and side windows as rows with their symbols),
-- the page itself in an inset on the right. The size can be dragged at the bottom right corner (D-68,
-- D-71); the minimize button folds the window to a small bar (D-71). Typing two
-- characters into the search box turns the side bar into the results (UI/Search.lua). Pages are built
-- the first time they are opened and refreshed only while shown.
local ADDON, ns = ...
local L = ns.L

local W, T = ns.W, ns.Theme
local M = T.MAIN
local WIDTH, HEIGHT = M.W, M.H
local NAV_W = M.NAV_W
local ROW_H = M.NAV_ROW_H
local PAGE_H0 = T.PAGE_H   -- the page area at the window's own height (HEIGHT)
local PAGE_W0 = T.PAGE_W   -- and at its own width (WIDTH)
local DOT = "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:10:10:0:0|t "
local PORTRAIT = "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia"
local WINDOW_SIGN = "Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up"
local GRABBER = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

local F, mini, minBtn, navHead, viewText, nav, content, statusBar, statusText, menuBtn, helpBtn, settingsBtn, search, results, noHits, searchHint, homeBtn, grip
local pageHead, pageTitle, pageSub   -- the page head over the page (D-69)
local built, current = {}, nil
local previous      -- the page shown before the current one (the feedback's details name it)
local navShownFor   -- the page (and what the settings show) the side bar last scrolled into view
local query = ""          -- the search text, trimmed and lower case

-- The side windows in the side bar (D-68; until 2.62.0 the side tabs on the right edge): each a row of
-- its group with the chat window's maximize sign, right under the page it goes with (after: else at the
-- group's end); row: a shorter name for the row where the full one does not fit (it stands right under
-- its page: "Importieren" under "Soft-Reserves"); tip: what the window is for (the row's tooltip under
-- its full name).
local SIDE_WINDOWS = {
    { key = "gear", label = L["Ausrüstungstabelle"], row = L["Tabelle"], group = "char", after = "gear", frame = "AmisiaGearFrame",
      tip = L["Das beste Item je Platz für jede Stufe, mit Quelle und Alternativen."],
      visible = function() return ns.Gear ~= nil and ns.Gear.Available() and ns.ToggleGearFrame ~= nil end,
      toggle = function() ns.ToggleGearFrame() end },
    { key = "goals", label = L["Ausrüstungsziele"], group = "char", after = "gear", frame = "AmisiaGoalsFrame",
      tip = L["Deine Ziele an deinem Charakter anprobieren, Platz für Platz mit Rangliste und Katalog."],
      visible = function() return ns.Gear ~= nil and ns.Gear.Available() and ns.ToggleGoalsFrame ~= nil end,
      toggle = function() ns.ToggleGoalsFrame() end },
    { key = "talents", label = L["Talentrechner"], group = "char", after = "talents", frame = "AmisiaTalentFrame",
      tip = L["Talente planen, im großen Fenster."],
      visible = function() return ns.Talents ~= nil and ns.Talents.Available() and ns.ToggleTalentFrame ~= nil end,
      toggle = function() ns.ToggleTalentFrame() end },
    { key = "rolls", label = L["Würfelfenster"], group = "raid", after = "rolls", frame = "AmisiaRollFrame",
      tip = L["Die laufende Würfelrunde: Würfe in Reihenfolge, Vergeben, Stechen."],
      visible = function() return ns.IsOfficerView() and ns.ToggleRollFrame ~= nil end,
      toggle = function() ns.ToggleRollFrame() end },
    { key = "softres", label = L["Soft-Reserve-Import"], row = L["Importieren"], group = "raid", after = "softres", frame = "AmisiaSoftResFrame",
      tip = L["Eine Soft-Reserve-Liste einfügen, prüfen und übernehmen."],
      visible = function() return ns.IsOfficerView() and ns.ToggleSoftResFrame ~= nil end,
      toggle = function() ns.ToggleSoftResFrame() end },
}

-- settings.window: the place (point, rel, x, y), the dragged height (h, H_MIN to H_MAX; nil: HEIGHT)
-- and width (w, W_MIN to W_MAX; nil: WIDTH),
-- the last group (tab: a group key) and the last page of each group (pages: { [group] = page key }); the
-- collapsed sections of before 2.27.0 are dropped. Once per session the group and the pages are checked
-- against today's groups (D-68 moved the pages of "gear", "calendar" and "pvp"): each page goes under its
-- group now, a page no longer there is dropped, an unknown tab becomes the group of its last page.
local windowChecked = false
local function windowState()
    AmisiaDB.settings.window = type(AmisiaDB.settings.window) == "table" and AmisiaDB.settings.window or {}
    local w = AmisiaDB.settings.window
    w.collapsed = nil
    if type(w.pages) ~= "table" then w.pages = {} end
    if w.tab ~= nil and type(w.tab) ~= "string" then w.tab = nil end
    if not windowChecked then
        windowChecked = true
        local known, pages = {}, {}
        for _, g in ipairs(ns.PANEL_GROUPS) do known[g.key] = true end
        -- in the order of the old keys: two old groups now in one keep the same page on every client
        local olds = {}
        for g in pairs(w.pages) do if type(g) == "string" then olds[#olds + 1] = g end end
        table.sort(olds)
        for _, g in ipairs(olds) do
            local key = w.pages[g]
            local p = type(key) == "string" and ns.Panel(key) or nil
            local now = p and ns.PanelGroup(p)
            if now and (pages[now] == nil or g == now) then pages[now] = key end
        end
        if w.tab ~= nil and not known[w.tab] then
            local p = type(w.pages[w.tab]) == "string" and ns.Panel(w.pages[w.tab]) or nil
            w.tab = p and ns.PanelGroup(p) or nil
        end
        w.pages = pages
        local h = tonumber(w.h)
        w.h = h and h >= M.H_MIN and h <= M.H_MAX and math.floor(h + 0.5) or nil
        local wd = tonumber(w.w)
        w.w = wd and wd >= M.W_MIN and wd <= M.W_MAX and math.floor(wd + 0.5) or nil
    end
    return w
end

local function savePosition()
    local point, _, rel, x, y = F:GetPoint()
    local w = windowState()
    w.point, w.rel, w.x, w.y = point, rel, x, y
end

-- Dragging b moves the window (and keeps its place).
local function dragMoves(b)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() F:StartMoving() end)
    b:SetScript("OnDragStop", function()
        F:StopMovingOrSizing()
        savePosition()
    end)
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

-- The remembered group and pages stay (settings.window.tab, pages), the position and the size go.
local applySize, applyHeight
function ns.ResetPositions()
    local w = windowState()
    w.point, w.h, w.w = nil, nil, nil
    if F then
        applySize(WIDTH, HEIGHT)
        restorePosition()
        W.FitLists()
        W.FitWidths()
        ns.Refresh()
    end
    if ns.ResetGearPosition then ns.ResetGearPosition() end
    if ns.ResetRollWindowPosition then ns.ResetRollWindowPosition() end
    if ns.ResetTalentWindowPosition then ns.ResetTalentWindowPosition() end
    if ns.ResetGoalsWindowPosition then ns.ResetGoalsWindowPosition() end
    if ns.ResetRaidCalendarPosition then ns.ResetRaidCalendarPosition() end
    ns.msg(L["Fensterposition zurückgesetzt."])
end

local reportError = ns.ReportError

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
    viewText:SetText(("v%s · %s"):format(ns.VERSION or "?", ns.IsOfficerView() and L["Offiziersansicht"] or L["Raider-Ansicht"]))
    settingsBtn:SetShown(current ~= "settings" and ns.SettingsSectionsOf ~= nil and #ns.SettingsSectionsOf(current) > 0)
    -- the "?" sits left of the gear, or at the head's end when the page has no settings
    helpBtn:ClearAllPoints()
    if settingsBtn:IsShown() then
        helpBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -M.ICON_GAP, 0)
    else
        helpBtn:SetPoint("TOPRIGHT", pageHead, "TOPRIGHT", 0, -M.ICON_Y)
    end
end

-- The page head (D-69): the open page's name and its one line (sub: a text; none: the name alone, a
-- little lower).
local function updatePageHead(p)
    pageTitle:SetText(p and p.label or "")
    local sub = p and p.sub
    pageSub:SetText(type(sub) == "string" and sub or "")
    pageSub:SetShown(type(sub) == "string" and sub ~= "")
end

-- The "?" shows only when the open page has explanations (footer lines with help = true, D-67);
-- after the page's refresh, which writes them.
local function updateHelp()
    helpBtn:SetShown(#W.HelpLines(content) > 0)
end

-- The menu behind the status line (D-67): the recording and the view, which were two red buttons in
-- the head. Each entry says what a click does; its tip says more.
local function headMenu()
    return {
        { ns.IsEnabled() and L["Aufnahme pausieren"] or L["Aufnahme fortsetzen"], function()
            ns.SetEnabled(not ns.IsEnabled())
            ns.Refresh()
        end, tip = ns.IsEnabled()
            and L["Pausiert die Raid-Aufnahme: Teilnehmer, Bosse und Beute werden nicht mehr mitgeschrieben. Die Pause bleibt auch nach einem /reload, bis du sie hier fortsetzt (oder im Schnellmenü der Minimap, /amisia pause)."]
            or L["Die Raid-Aufnahme ist pausiert. \"Aufnahme fortsetzen\" schaltet sie wieder an; sie startet dann von selbst in einer Raidinstanz mit Raidgruppe."] },
        { ns.IsOfficerView() and L["Zur Raider-Ansicht"] or L["Zur Offiziersansicht"], function() ns.ToggleView() end,
          tip = L["Ein Klick zeigt die andere Ansicht: Raider sehen ihre Seiten, Offiziere auch Rolls, Punkte, das Raid-Archiv und den Export. Für die Gilde bist du dadurch kein Offizier; Rechte prüft Amisia am Rang. Die Ansicht nach Rang (Automatisch) stellst du unter Einstellungen, Oberfläche ein."] },
    }
end

-- The view switch in the head: a click shows the other view (and sets it, as the setting
-- "Ansicht" does); "Automatisch" stays in the settings and in /amisia ansicht auto.
function ns.ToggleView()
    ns.Set("ui.view", ns.IsOfficerView() and "raider" or "officer")
    ns.Refresh()
end

-- The visible pages of every group at once (group -> pages, in their order): one pass for a refresh.
local function pagesByGroup()
    local out = {}
    for _, g in ipairs(ns.PANEL_GROUPS) do out[g.key] = {} end
    for _, p in ipairs(ns.panels) do
        local g = ns.PanelGroup(p)
        if ns.Visible(p) then
            out[g] = out[g] or {}
            out[g][#out[g] + 1] = p
        end
    end
    return out
end

-- What the settings show (the chosen section, or the sorted keys of a page's sections; "" while
-- searching): a fold in the page list holds only while this stays the same.
local function settingsShown(chosen, set)
    if chosen then return chosen end
    if not set then return "" end
    local keys = {}
    for k in pairs(set) do keys[#keys + 1] = k end
    table.sort(keys)
    return table.concat(keys, " ")
end

-- Folded by a click in the page list, as the auction house's categories: the tabs under "Einstellungen"
-- (treeShut) and the open tab's sections (tabShut = { key, at }); both hold for what the settings show
-- at the click (at), another section or page's sections unfold everything again.
local treeShut, tabShut

-- The side windows of a group that are there (the view, the data), in their order.
local function windowsOf(group)
    local out = {}
    for _, def in ipairs(SIDE_WINDOWS) do
        if def.group == group and def.visible() then out[#out + 1] = def end
    end
    return out
end

local function windowEntry(def)
    local win = _G[def.frame]
    return { kind = "win", key = def.key, label = def.row or def.label, def = def, on = win ~= nil and win:IsShown() and true or false }
end

-- What the side bar shows (D-70): every group with a visible page or side window as a heading, under
-- it its pages, each side window right under its page (or at the end), and while the settings page
-- is open, under it its tabs and, under the tab of the chosen section, that tab's sections (D-49),
-- unless folded: { kind = "cat"|"page"|"group"|"section"|"win", key, label, on = chosen, changed,
-- open, has, first = the first heading }.
local function navEntries(byGroup)
    local out = {}
    byGroup = byGroup or pagesByGroup()
    for _, g in ipairs(ns.PANEL_GROUPS) do
        local pages, wins = byGroup[g.key], windowsOf(g.key)
        if #pages + #wins > 0 then
            out[#out + 1] = { kind = "cat", key = g.key, label = g.label, first = #out == 0 }
            local placed = {}
            for _, p in ipairs(pages) do
                out[#out + 1] = { kind = "page", key = p.key, label = p.label, on = p.key == current }
                if p.key == "settings" and current == "settings" and ns.SettingsGroups and ns.SettingsChosen then
                    local chosen, set = ns.SettingsChosen()
                    local at = settingsShown(chosen, set)
                    -- a fold ends once the settings show something else (and does not come back with it)
                    if treeShut ~= at then treeShut = nil end
                    if tabShut and tabShut.at ~= at then tabShut = nil end
                    local tree = treeShut == nil
                    out[#out].open, out[#out].at = tree, at
                    for _, sg in ipairs(tree and ns.SettingsGroups() or {}) do
                        local has = false
                        for _, sec in ipairs(sg.sections) do
                            if sec.key == chosen or (set and set[sec.key]) then has = true end
                        end
                        local open = has and not (tabShut and tabShut.key == sg.key and tabShut.at == at)
                        out[#out + 1] = { kind = "group", key = sg.key, label = sg.label, first = sg.sections[1].key, open = open,
                            has = has, at = at }
                        if open then
                            for _, sec in ipairs(sg.sections) do
                                out[#out + 1] = { kind = "section", key = sec.key, label = sec.label,
                                    on = sec.key == chosen or (set and set[sec.key]) or false, changed = ns.SectionChanged(sec) }
                            end
                        end
                    end
                end
                for _, def in ipairs(wins) do
                    if def.after == p.key then
                        out[#out + 1] = windowEntry(def)
                        placed[def.key] = true
                    end
                end
            end
            for _, def in ipairs(wins) do
                if not placed[def.key] then out[#out + 1] = windowEntry(def) end
            end
        end
    end
    return out
end

-- The side bar: one row each, packed as the auction house's category list, NAV_ROW_H high; it
-- scrolls (wheel, bar) when not all fit, and scrolls the open page into view when it changed.
-- F.navOrder holds what is shown, top to bottom ({ button = row, entry = what it shows }).
local function updateNav(byGroup)
    local entries = navEntries(byGroup)
    for i, e in ipairs(entries) do
        if e.kind == "page" and e.key == current then
            -- once per page and view, and again when the settings show something else (their tree
            -- changed; a view switch adds or drops rows above it):
            -- what hangs under it (the settings' tabs and sections) comes into view with it; above
            -- the view, its group's heading too when that is right above
            local shown = current .. "\0" .. tostring(ns.IsOfficerView()) .. "\0" .. tostring(e.at or "")
            if navShownFor ~= shown then
                navShownFor = shown
                local last = i
                while entries[last + 1] and (entries[last + 1].kind == "group" or entries[last + 1].kind == "section") do
                    last = last + 1
                end
                if i - 1 < nav.offset or last > nav.offset + nav.rowCount then
                    nav.offset = math.max(0, math.min(i - 2, last - nav.rowCount))
                end
            end
            break
        end
    end
    nav:SetItems(entries)
    local order = {}
    for i = 1, nav.rowCount do
        local r = nav.rows[i]
        if r and r.item then order[#order + 1] = { button = r, entry = r.item } end
    end
    F.navOrder = order
end

---------------------------------------------------------------------------
-- Groups
---------------------------------------------------------------------------
-- The page a group opens: the one last open there when it is still shown, else its first.
local function tabPage(group)
    local pages = pagesByGroup()[group] or {}
    local last = windowState().pages[group]
    for _, p in ipairs(pages) do
        if p.key == last then return p.key end
    end
    return pages[1] and pages[1].key or nil
end

-- Opens the group's last page (a group with side windows only: nothing to open).
function ns.ShowTab(group)
    local key = tabPage(group)
    if key then ns.ShowPage(key) end
end

---------------------------------------------------------------------------
-- The window's size (D-68: the height, D-71: the width)
---------------------------------------------------------------------------
-- The most room the screen gives at the window's scale along one axis (UIParent's GetHeight or
-- GetWidth), never less than lo nor more than hi.
local function screenRoom(lo, hi, side)
    local top = hi
    local ui = UIParent and UIParent[side] and UIParent[side](UIParent) or 0
    local mine = F and F.GetEffectiveScale and F:GetEffectiveScale() or 1
    local theirs = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if ui > 0 and mine > 0 then top = math.min(top, math.floor(ui * theirs / mine)) end
    return math.max(lo, top)
end
local function heightRoom() return screenRoom(M.H_MIN, M.H_MAX, "GetHeight") end
local function widthRoom() return screenRoom(M.W_MIN, M.W_MAX, "GetWidth") end

-- Sets the window's size (clamped), the page area (T.PAGE_H, T.PAGE_W_NOW) and the side bar's rows;
-- the pages' lists and bands follow with W.FitLists and W.FitWidths (at the end of a drag, not on
-- every step). The width and the height it got.
applySize = function(w, h)
    w = math.floor(math.max(M.W_MIN, math.min(widthRoom(), tonumber(w) or WIDTH)) + 0.5)
    h = math.floor(math.max(M.H_MIN, math.min(heightRoom(), tonumber(h) or HEIGHT)) + 0.5)
    F:SetSize(w, h)
    T.PAGE_H = PAGE_H0 + h - HEIGHT
    T.PAGE_W_NOW = PAGE_W0 + w - WIDTH
    local rows = math.floor((M.NAV_LIST_H + h - HEIGHT) / ROW_H)
    nav:Fit(rows)
    results:Fit(rows)
    return w, h
end
-- the height alone (the width kept)
applyHeight = function(h)
    local _, got = applySize(F:GetWidth(), h)
    return got
end

-- The end of a drag (or a new screen): remembered (nil at the window's own size), the pages fit.
local function sizeDone()
    local w, h = math.floor(F:GetWidth() + 0.5), math.floor(F:GetHeight() + 0.5)
    local state = windowState()
    state.h = h ~= HEIGHT and h or nil
    state.w = w ~= WIDTH and w or nil
    savePosition()
    W.FitLists()
    W.FitWidths()
    ns.Refresh()
end

-- The grip at the bottom right corner: the chat window's size grabber. Dragging it sets the size
-- under the cursor; the window's top left stays where it is (anchored there for the drag).
local function buildGrip()
    local g = CreateFrame("Button", nil, F)
    g:SetSize(M.GRIP, M.GRIP)
    g:SetPoint("BOTTOMRIGHT", M.GRIP_OUT, -M.GRIP_OUT)
    g:SetFrameLevel(F:GetFrameLevel() + 20)
    g:SetNormalTexture(GRABBER .. "Up")
    g:SetPushedTexture(GRABBER .. "Down")
    g:SetHighlightTexture(GRABBER .. "Highlight")
    local startX, startY, startW, startH
    local function cursor()
        local x, y = GetCursorPosition()
        local scale = F:GetEffectiveScale()
        scale = scale > 0 and scale or 1
        return (x or 0) / scale, (y or 0) / scale
    end
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local left, top = F:GetLeft(), F:GetTop()
        if left and top then
            F:ClearAllPoints()
            F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        startX, startY = cursor()
        startW, startH = F:GetWidth(), F:GetHeight()
        self:SetScript("OnUpdate", function()
            local x, y = cursor()
            applySize(startW + (x - startX), startH + (startY - y))
        end)
    end)
    local function stop(self)
        if not startY then return end
        self:SetScript("OnUpdate", nil)
        startX, startY = nil, nil
        sizeDone()
    end
    g:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then stop(self) end
    end)
    -- the window hidden mid-drag (Escape, minimize): no mouse up comes, the drag ends here
    g:SetScript("OnHide", stop)
    W.Tooltip(g, L["Größe ändern"], L["Ziehen: das Fenster breiter oder schmaler, höher oder niedriger. Listen und Kacheln nutzen den Platz."])
    g:Show()
    return g
end

---------------------------------------------------------------------------
-- Minimize (D-71): the window folds to a small bar in the tooltip's frame, at its top right corner
---------------------------------------------------------------------------
local function minimize()
    if not F or not mini then return end
    local p = ns.Panel(current)
    mini.page:SetText(p and p.label or "")
    mini:SetScale(F:GetScale())
    mini:ClearAllPoints()
    local right, top = F:GetRight(), F:GetTop()
    if right and top then
        mini:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
    else
        mini:SetPoint("CENTER")
    end
    F:Hide()
    mini:Show()
end

-- The bar's click: the window again, its top right corner where the bar's is.
local function restore()
    if not mini or not mini:IsShown() then return end
    local right, top = mini:GetRight(), mini:GetTop()
    mini:Hide()
    if right and top then
        F:ClearAllPoints()
        F:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
        savePosition()
    end
    ns.ShowPage(current or "overview")
end

local function buildMini()
    local B = M.MINI
    local ok, bar = pcall(CreateFrame, "Button", "AmisiaMiniBar", UIParent, "TooltipBackdropTemplate")
    if not ok or not bar then
        bar = CreateFrame("Button", "AmisiaMiniBar", UIParent)
        W.Flat(bar, 0.05, 0.05, 0.06, 0.95)
    end
    bar:SetSize(B.W, B.H)
    bar:SetFrameStrata("FULLSCREEN")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    -- a drag is no click: the client sends none after a drag, an old one may (moved, cleared at
    -- every press)
    bar:SetScript("OnMouseDown", function(self) self.moved = nil end)
    bar:SetScript("OnDragStart", function(self) self.moved = true self:StartMoving() end)
    bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    bar:SetScript("OnClick", function(self)
        if self.moved then self.moved = nil return end
        restore()
    end)
    bar.logo = bar:CreateTexture(nil, "ARTWORK")
    bar.logo:SetSize(B.LOGO, B.LOGO)
    bar.logo:SetPoint("LEFT", B.LOGO_X, 0)
    bar.logo:SetTexture(PORTRAIT)
    if bar.CreateMaskTexture and bar.logo.AddMaskTexture then
        local mask = bar:CreateMaskTexture()
        mask:SetAllPoints(bar.logo)
        mask:SetTexture(W.DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        bar.logo:AddMaskTexture(mask)
    end
    bar.name = W.Text(bar, T.FONT.title, B.TEXT_W)
    bar.name:SetPoint("LEFT", B.TEXT_X, B.NAME_Y)
    bar.name:SetText("Amisia")
    bar.page = W.Text(bar, T.FONT.hint, B.TEXT_W)
    bar.page:SetPoint("LEFT", B.TEXT_X, B.PAGE_Y)
    local okX, x = pcall(CreateFrame, "Button", nil, bar, "UIPanelCloseButtonNoScripts")
    if not okX or not x then
        x = CreateFrame("Button", nil, bar)
        local t = W.Text(x, T.FONT.title)
        t:SetPoint("CENTER")
        t:SetText("x")
    end
    x:SetSize(B.X, B.X)
    x:SetPoint("RIGHT", -B.X_R, 0)
    x:SetScript("OnClick", function() bar:Hide() end)
    W.Tooltip(x, L["Schließen"], L["Schließt die Leiste; /amisia öffnet das Fenster wieder."])
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Amisia", 1, 0.82, 0)
        GameTooltip:AddLine(L["Klick: das Fenster wieder öffnen. Ziehen: die Leiste verschieben."], 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.close = x
    bar:Hide()
    return bar
end

-- The minimize button: the client's (UIPanelHideButtonNoScripts, the red "-"), left of the close
-- button, the frame's corner art for two buttons as the client's own minimizable windows
-- (PortraitFrameTemplateMinimizable); without the template the old client's smaller-window button.
-- In the flat window of TBC and Era (no TitleContainer: the old 32 px close button) MIN_SIZE_OLD,
-- centred on the close button and clear of the status line.
local function buildMinButton()
    local modern = F.TitleContainer ~= nil
    local ok, b = pcall(CreateFrame, "Button", nil, F, "UIPanelHideButtonNoScripts")
    if not ok or not b then
        b = CreateFrame("Button", nil, F)
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Highlight", "ADD")
    end
    local size = modern and M.MIN_SIZE or M.MIN_SIZE_OLD
    b:SetSize(size, size)
    if F.CloseButton and modern then
        -- its top at the window's top (the close button's template hangs 1 px over it)
        b:SetPoint("TOPRIGHT", F.CloseButton, "TOPLEFT", 0, -1)
        if F.SetBorder then pcall(F.SetBorder, F, "PortraitFrameTemplateMinimizable") end
    elseif F.CloseButton then
        b:SetPoint("RIGHT", F.CloseButton, "LEFT", 0, 0)
    else
        b:SetPoint("TOPRIGHT", -M.MIN_SIZE, 0)
    end
    b:SetScript("OnClick", minimize)
    W.Tooltip(b, L["Minimieren"], L["Klappt das Fenster zu einer kleinen Leiste zusammen; ein Klick darauf öffnet es wieder."])
    return b
end

---------------------------------------------------------------------------
-- The search over the page list (UI/Search.lua finds, this shows)
---------------------------------------------------------------------------
-- While the box holds fewer than SEARCH_MIN characters, the line "Noch 1 Zeichen für die Suche" in
-- place of the side bar (D-70: the list fills the side bar, there is no room under it).
local function updateSearchHint()
    local left = M.SEARCH_MIN - #query
    if #query == 0 or left <= 0 then
        searchHint:Hide()
        return
    end
    searchHint:ClearAllPoints()
    searchHint:SetPoint("TOPLEFT", nav, "TOPLEFT", M.NAV_LABEL_X, -M.SEARCH_GAP)
    searchHint:SetText(left == 1 and L["Noch 1 Zeichen für die Suche"] or L["Noch %d Zeichen für die Suche"]:format(left))
    searchHint:Show()
end

-- The hits of the search text in place of the page list. A refresh (data, a setting) keeps the
-- scroll place (SetItems clamps it); only a new text starts at the top (setQuery).
local function showResults()
    local searching = #query >= M.SEARCH_MIN
    nav:SetShown(#query == 0)
    results:SetShown(searching)
    if F then updateSearchHint() end
    if not searching then
        noHits:Hide()
        return
    end
    local rows = {}
    for _, grp in ipairs(ns.Search(query)) do
        rows[#rows + 1] = { head = grp.label, count = #grp.hits }
        for _, hit in ipairs(grp.hits) do rows[#rows + 1] = hit end
    end
    results:SetItems(rows)
    -- under ITEM_MIN characters items, recipes and commands are not searched yet: the hint says so
    local itemMin = ns.SearchIndex.ITEM_MIN
    noHits:SetText(#query < itemMin and L["Nichts gefunden. Items, Rezepte und Befehle ab %d Zeichen."]:format(itemMin)
        or L["Nichts gefunden."])
    noHits:SetShown(#rows == 0)
end

local function setQuery(text)
    text = (tostring(text or ""):match("^%s*(.-)%s*$") or ""):lower()
    if text == query then return end
    query = text
    results.offset = 0
    showResults()
end

-- Clears the search box (Escape, the clear button, a click on a result or a group).
function ns.ClearSearch()
    if not search then return end
    search:SetText("")
    search:ClearFocus()
    setQuery("")
end

-- A result row: a group as the auction house's category bar (gold name, the count white), a hit as
-- its indented sub-category bar (white, from RES_HIT_X); no icons, as there. Without the client's
-- bars: the group as a section bar and the hit as a plain list row, as before 2.29.0.
local function buildResult(r)
    local w = NAV_W - T.SCROLL_ROOM
    r.headArt = W.NavBar(r, false)
    r.hitArt = r.headArt and W.NavBar(r, true)
    if r.headArt and r.hitArt then
        r.headArt:Fit(M.RES_ROW_H - 1)
        r.hitArt:Fit(M.RES_ROW_H - 1)
        r.bg:Hide()
        r.hover:SetAlpha(0)       -- the bars bring their own glow
        r.headArt.hover:Hide()    -- a group is no button: no glow over it
    else
        r.headArt, r.hitArt = nil, nil
        r.bar = W.SectionHeader(r, "", false)
        r.bar:SetPoint("TOPLEFT", 0, 0)
        r.bar:SetPoint("BOTTOMRIGHT", 0, 0)
        r.bar:Hide()
    end
    r.label = W.Text(r, T.FONT.text, w - M.RES_HIT_X - 6)
    r.label:SetPoint("LEFT", M.RES_HIT_X, 0)
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
    local head = hit.head ~= nil
    if r.headArt then
        r.headArt.normal:SetShown(head)
        r.hitArt.normal:SetShown(not head)
        r.hitArt.hover:SetShown(not head)
        r.label:ClearAllPoints()
        if head then
            r.label:SetPoint("LEFT", M.NAV_LABEL_X, 0)
            r.label:SetWidth(NAV_W - T.SCROLL_ROOM - M.NAV_LABEL_X - 6)
            r.label:SetFontObject(T.FONT.title)
            r.label:SetText(("%s |cffffffff%d|r"):format(hit.head, hit.count))
        else
            r.label:SetPoint("LEFT", M.RES_HIT_X, 0)
            r.label:SetWidth(NAV_W - T.SCROLL_ROOM - M.RES_HIT_X - 6)
            r.label:SetFontObject(T.FONT.text)
            r.label:SetText(hit.label or hit.text)
        end
        return
    end
    if head then
        r.bar:SetHeaderText(("%s |cffffffff%d|r"):format(hit.head, hit.count))
        r.bar:Show()
        r.bg:Hide()
        r.label:SetText("")
        return
    end
    r.bar:Hide()
    r.bg:Show()
    r.label:SetText(hit.label or hit.text)
end

-- The side windows' rows follow their windows: each window calls this when it shows or hides (through
-- W.Window's onVisibility, so the windows need not know this file; the name is from the side tabs).
function ns.UpdateSideTabs()
    -- also while the search shows its results: the side bar comes back as it is now
    if F and F:IsShown() then updateNav() end
end

-- A row of the side bar (a row of the W.List nav, D-70): a group as a heading (gold capitals from
-- NAV_LABEL_X, no bar, the gold line over it from the second on); a page and a side window on the
-- auction house's sub-category bar with its symbol (T.NAV_ICONS) and the name gold from NAV_SUB_X; the
-- settings' tabs on that bar from NAV_SUB2_X (gold), a section white from NAV_SUB3_X (D-49); a side
-- window with the chat window's maximize sign at the right. The name white while the mouse is over
-- it. Without the client's bars: the recipe list's glow when chosen and its hover, the same names.
local LABEL_X = { cat = M.NAV_LABEL_X, page = M.NAV_SUB_X, win = M.NAV_SUB_X, group = M.NAV_SUB2_X, section = M.NAV_SUB3_X }

-- A heading in capitals (the umlauts too, which string.upper leaves).
local function caps(text)
    return (tostring(text):upper():gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))   -- l10n-ok: letters, not text
end

-- The symbol of a row: its page's or side window's (T.NAV_ICONS), else none; none either when the
-- client lacks the atlas or (where it can tell, GetFileIDFromPath) the file. A pooled row's texture
-- coordinates from an atlas are reset for a file.
local function setSymbol(tex, key)
    local def = key and T.NAV_ICONS[key]
    if def and def.atlas and W.HasAtlas(def.atlas) then
        tex:SetAtlas(def.atlas, false)
        tex:Show()
    elseif def and def.file and not (GetFileIDFromPath and GetFileIDFromPath(def.file) == nil) then
        tex:SetTexture(def.file)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:Show()
    else
        tex:Hide()
    end
end

local function navClick(self)
    local e = self.item
    if not e then return end
    if e.kind == "cat" then
        return   -- a heading
    elseif e.kind == "win" then
        e.def.toggle()
        ns.UpdateSideTabs()
    elseif e.kind == "section" then
        navShownFor = nil   -- the settings' tree may grow: into view again
        ns.ShowSettingsSection(e.key)
    elseif e.kind == "group" then
        navShownFor = nil
        -- an open tab folds, a folded one with the chosen section unfolds, another opens its first
        if e.open then
            tabShut = { key = e.key, at = e.at }
            ns.Refresh()
        elseif e.has then
            tabShut = nil
            ns.Refresh()
        else
            ns.ShowSettingsSection(e.first)
        end
    elseif e.key == "settings" and current == "settings" and ns.ShowSettingsSection then
        navShownFor = nil
        -- the chosen section with the tabs open, folds the tabs, unfolds them again
        local chosen = ns.SettingsChosen()
        if chosen then
            treeShut = e.open and e.at or nil
            ns.Refresh()
        else
            treeShut = nil
            ns.ShowSettingsSection()
        end
    else
        ns.ShowPage(e.key)
    end
end

local function buildNav(b)
    local w = NAV_W - T.SCROLL_ROOM
    b.subArt = W.NavBar(b, true)
    if b.subArt then
        b.subArt:Fit(ROW_H - 1)
        b.bg:Hide()
        b.hover:SetAlpha(0)    -- the bars bring their own glow
    else
        b.bg:Hide()
        b.sel = W.SelectBar(b)
    end
    b.symbol = b:CreateTexture(nil, "OVERLAY")
    b.symbol:SetSize(M.NAV_ICON, M.NAV_ICON)
    b.symbol:SetPoint("LEFT", M.NAV_ICON_X, 0)
    b.symbol:Hide()
    b.rule = W.GoldRule(b, M.RULE_ALPHA)
    b.rule:SetPoint("TOPLEFT", M.NAV_LABEL_X, 0)
    b.rule:SetPoint("TOPRIGHT", -M.NAV_LABEL_X, 0)
    b.rule:Hide()
    b.sign = b:CreateTexture(nil, "OVERLAY")
    b.sign:SetSize(M.FOLD, M.FOLD)
    b.sign:SetPoint("RIGHT", -M.FOLD_R, 0)
    b.label = W.Text(b, T.FONT.title, M.NAV_LABEL_W)
    b.label:SetPoint("LEFT", M.NAV_LABEL_X, 0)
    if b.label.SetShadowOffset then b.label:SetShadowOffset(1, -1) end
    b.font = T.FONT.title
    -- the bar, the indent, the font and the sign of what the row shows
    function b:SetKind(kind)
        self.kind = kind
        local head = kind == "cat"
        if self.subArt then
            self.subArt.normal:SetShown(not head)
            self.subArt.hover:SetShown(not head)
        else
            self.hover:SetShown(not head)
        end
        local x = LABEL_X[kind] or M.NAV_SUB_X
        local signed = kind == "win"
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", x, 0)
        self.label:SetWidth(w - x - 6 - (signed and (M.FOLD + M.FOLD_R) or 0))
        self.font = (head and T.FONT.head) or (kind == "section" and T.FONT.text) or T.FONT.title
        self.label:SetFontObject(self.font)
    end
    function b:SetSelected(on)
        on = (on and self.kind ~= "cat") and true or false
        if self.subArt then self.subArt:SetSelected(on) else self.sel:SetShown(on) end
    end
    b:SetScript("OnClick", navClick)
    b:SetScript("OnEnter", function(self)
        local e = self.item
        if not e or e.kind == "cat" then return end
        self.label:SetFontObject(T.FONT.body)
        if e.kind == "win" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.def.label, 1, 0.82, 0)
            GameTooltip:AddLine(e.def.tip, 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine(e.on and L["Klick: Fenster schließen."] or L["Klick: Fenster öffnen."], 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.label:SetFontObject(self.font or T.FONT.title)
        GameTooltip:Hide()
    end)
end

local function fillNav(b, e)
    b.key = e.key
    b:SetKind(e.kind)
    if e.kind == "cat" then
        b.label:SetText(caps(e.label))
    else
        b.label:SetText(e.kind == "section" and e.changed and (DOT .. e.label) or e.label)
    end
    b.rule:SetShown(e.kind == "cat" and not e.first)
    if e.kind == "page" then
        setSymbol(b.symbol, e.key)
    elseif e.kind == "win" then
        setSymbol(b.symbol, "win:" .. e.key)
    else
        setSymbol(b.symbol, nil)
    end
    if e.kind == "win" then
        b.sign:SetTexture(WINDOW_SIGN)
        b.sign:Show()
    else
        b.sign:Hide()
    end
    b:SetSelected(e.on)
end

local function build()
    F = W.Window("AmisiaFrame", WIDTH, HEIGHT, { portrait = PORTRAIT, strata = "FULLSCREEN",
        title = "Amisia", background = "Profession-Background-Overview",
        onShow = function(self)
            if self.Raise then self:Raise() end
            -- another screen or scale since the last open: the size stays on it
            if nav and (math.floor(self:GetHeight() + 0.5) > heightRoom() or math.floor(self:GetWidth() + 0.5) > widthRoom()) then
                applySize(self:GetWidth(), self:GetHeight())
                W.FitLists()
                W.FitWidths()
            end
            -- opened again (/amisia, the minimap): the bar goes
            if mini then mini:Hide() end
            ns.Refresh()
            -- the setup offer (Setup.lua) at the first open after a login
            ns.Fire("MAIN_SHOWN")
        end,
        onDragStop = function() savePosition() end })
    restorePosition()
    ns.ApplyScale()

    -- the head (D-67): the recording state as plain text, centred right of the portrait, on the
    -- frame's own ground (a dark bar there did not fit the window's look); a click on it or on its arrow
    -- opens the menu with the recording and the view. No red buttons; "?" and the gear went to the page
    -- head (D-69).
    local bar = CreateFrame("Button", nil, F)
    bar:SetHeight(M.HEAD_H)
    bar:SetPoint("TOPLEFT", M.HEAD_X, -M.HEAD_Y)
    bar:SetPoint("TOPRIGHT", -M.ICON_RIGHT, -M.HEAD_Y)   -- as wide as the window (D-71)
    statusBar = bar
    statusText = W.Text(bar, T.FONT.body)
    statusText:SetPoint("CENTER", bar, "CENTER", -(M.MENU_SIZE + M.ICON_GAP) / 2, 0)
    statusText:SetJustifyH("CENTER")
    if statusText.SetShadowOffset then statusText:SetShadowOffset(1, -1) end
    local function openMenu() W.Menu(menuBtn, headMenu()) end
    menuBtn = W.ArrowButton(bar, "down", M.MENU_SIZE, openMenu)
    menuBtn:SetPoint("LEFT", statusText, "RIGHT", M.ICON_GAP, 0)
    bar:SetScript("OnClick", openMenu)
    -- the status line still moves the window, as the head did before it took the mouse
    dragMoves(bar)
    local function statusTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["Raid-Aufnahme"], 1, 0.82, 0)
        GameTooltip:AddLine(ns.IsEnabled() and L["Aufnahme an: startet von selbst in einer Raidinstanz mit Raidgruppe."]
            or L["Aufnahme pausiert."], 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine(ns.IsOfficerView() and L["Ansicht: Offiziere"] or L["Ansicht: Raider"], 0.85, 0.85, 0.85)
        GameTooltip:AddLine(L["Klick: pausieren, fortsetzen oder die Ansicht wechseln."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end
    bar:SetScript("OnEnter", statusTip)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    menuBtn:HookScript("OnEnter", statusTip)
    menuBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- the portrait: a click opens the overview from every tab (the window's "home")
    local portrait = F.PortraitContainer and F.PortraitContainer.portrait or F.portrait
    if portrait then
        homeBtn = CreateFrame("Button", nil, F.PortraitContainer or F)
        homeBtn:SetAllPoints(portrait)
        -- dragging the portrait still moves the window
        dragMoves(homeBtn)
        homeBtn:SetScript("OnClick", function()
            ns.ClearSearch()
            ns.ShowPage("overview")
        end)
        W.Tooltip(homeBtn, L["Übersicht"], L["Ein Klick auf das Bild öffnet die Übersicht, von jeder Seite aus."])
    end

    -- the side bar in an inset with the recipe list's ground, the page in an inset beside it
    local listInset = W.Inset(F)
    listInset:SetPoint("TOPLEFT", M.MARGIN, -M.TOP)
    listInset:SetPoint("BOTTOMLEFT", M.MARGIN, M.MARGIN)
    listInset:SetWidth(M.LIST_W)
    listInset.fill("Professions-background-summarylist")
    local contentInset = W.Inset(F)
    contentInset:SetPoint("TOPLEFT", M.CONTENT_X, -M.TOP)
    contentInset:SetPoint("BOTTOMRIGHT", -M.MARGIN, M.MARGIN)

    -- the side bar's head (D-70): the logo, the name, the version and the view, the gold line under it
    navHead = CreateFrame("Frame", nil, listInset)
    navHead:SetPoint("TOPLEFT", M.INNER, -M.INNER)
    navHead:SetSize(NAV_W, M.NAV_HEAD)
    local logo = navHead:CreateTexture(nil, "ARTWORK")
    logo:SetSize(M.LOGO, M.LOGO)
    logo:SetPoint("TOPLEFT", M.LOGO_X, -math.floor((M.HEAD_RULE_Y - M.LOGO) / 2))
    -- round as the window's portrait (the client's template: the texture under a round mask), on a
    -- black disc
    logo:SetTexture(PORTRAIT)
    if navHead.CreateMaskTexture and logo.AddMaskTexture then
        local mask = navHead:CreateMaskTexture()
        mask:SetAllPoints(logo)
        mask:SetTexture(W.DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        logo:AddMaskTexture(mask)
    end
    local disc = navHead:CreateTexture(nil, "BORDER")
    disc:SetTexture(W.DISC)
    disc:SetVertexColor(0, 0, 0, 1)
    disc:SetAllPoints(logo)
    local name = W.Text(navHead, T.FONT.big, NAV_W - M.HEAD_TEXT_X)
    name:SetPoint("TOPLEFT", M.HEAD_TEXT_X, -M.HEAD_NAME_Y)
    name:SetText("Amisia")
    if name.SetShadowOffset then name:SetShadowOffset(1, -1) end
    viewText = W.Text(navHead, T.FONT.hint, NAV_W - M.HEAD_TEXT_X)
    viewText:SetPoint("TOPLEFT", M.HEAD_TEXT_X, -M.HEAD_SUB_Y)
    navHead.rule = W.GoldRule(navHead, M.RULE_ALPHA)
    navHead.rule:SetPoint("TOPLEFT", 0, -M.HEAD_RULE_Y)
    navHead.rule:SetPoint("TOPRIGHT", 0, -M.HEAD_RULE_Y)
    navHead.logo, navHead.name, navHead.view = logo, name, viewText

    -- the search box under the head, the groups and pages (or the results) under it
    search = W.SearchBox(listInset, NAV_W, nil)
    search:SetPoint("TOPLEFT", M.INNER, -(M.INNER + M.NAV_HEAD))
    search:HookScript("OnTextChanged", function(self) setQuery(self:GetText()) end)
    search:SetScript("OnEscapePressed", function() ns.ClearSearch() end)
    if search.clearButton then search.clearButton:HookScript("OnClick", function() ns.ClearSearch() end) end
    -- what the box finds and from how many characters; above the window, so it never covers the hits
    search:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Suchen"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Ab %d Zeichen: Seiten, Einstellungen, Dungeons und in der Offiziersansicht Spieler. Ab %d Zeichen auch Items, Rezepte und Befehle. Stichwörter finden die passende Seite, z. B. \"dkp\" die Punkte. Escape leert das Feld."]
            :format(M.SEARCH_MIN, ns.SearchIndex.ITEM_MIN), 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    search:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local listTop = M.INNER + M.NAV_HEAD + T.FIELD_H + M.SEARCH_GAP
    nav = W.List(listInset, math.floor(M.NAV_LIST_H / ROW_H), ROW_H, buildNav, fillNav)
    nav:SetPoint("TOPLEFT", M.INNER, -listTop)
    nav:SetWidth(NAV_W - T.SCROLL_ROOM)
    results = W.List(listInset, M.RES_ROWS, M.RES_ROW_H, buildResult, fillResult)
    results:SetPoint("TOPLEFT", M.INNER, -listTop)
    results:SetWidth(NAV_W - T.SCROLL_ROOM)
    results:Hide()
    noHits = W.Text(listInset, T.FONT.hint, NAV_W - 8, true)
    noHits:SetPoint("TOP", results, "TOP", 0, -T.LAYOUT.EMPTY_Y)
    noHits:SetJustifyH("CENTER")
    noHits:SetText(L["Nichts gefunden."])
    noHits:Hide()
    -- under SEARCH_MIN characters: how many more (updateSearchHint places it under the last bar)
    searchHint = W.Text(listInset, T.FONT.hint, NAV_W - 2 * M.NAV_LABEL_X)
    searchHint:Hide()

    -- the page head (D-69): name, one line, the gold line fading to both ends, "?" and the gear
    pageHead = CreateFrame("Frame", nil, contentInset)
    pageHead:SetPoint("TOPLEFT", M.PAGE_PAD, -M.PAGE_PAD)
    pageHead:SetPoint("TOPRIGHT", -M.PAGE_PAD, -M.PAGE_PAD)
    pageHead:SetHeight(M.PAGE_HEAD)
    local textW = T.PAGE_W - 2 * (M.ICON_SIZE + M.ICON_GAP) - T.LAYOUT.TEXT_X
    pageTitle = W.Text(pageHead, T.FONT.big, textW)
    pageTitle:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X, -M.TITLE_Y)
    if pageTitle.SetShadowOffset then pageTitle:SetShadowOffset(1, -1) end
    pageSub = W.Text(pageHead, T.FONT.hint, textW)
    pageSub:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X, -M.SUB_Y)
    pageHead.rule = W.GoldRule(pageHead, M.RULE_ALPHA)
    pageHead.rule:SetPoint("TOPLEFT", 0, -M.RULE_Y)
    pageHead.rule:SetPoint("TOPRIGHT", 0, -M.RULE_Y)
    -- the settings of the open page (D-49): the quest log's gear, shown only when it has some
    settingsBtn = W.IconButton(pageHead, M.ICON_SIZE, { atlas = "questlog-icon-setting" }, function() ns.ShowSettingsFor(current) end,
        L["E##Einstellungen"])
    settingsBtn:SetPoint("TOPRIGHT", pageHead, "TOPRIGHT", 0, -M.ICON_Y)
    settingsBtn:SetScript("OnEnter", function(self)
        local names = {}
        for _, sec in ipairs(ns.SettingsSectionsOf(current)) do names[#names + 1] = sec.label end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["Einstellungen"], 1, 0.82, 0)
        GameTooltip:AddLine(table.concat(names, ", "), 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    settingsBtn:Hide()
    -- the open page's explanations (D-67): the client's help sign, as on its own windows
    helpBtn = W.IconButton(pageHead, M.ICON_SIZE, { file = "Interface\\common\\help-i" }, nil, "?")
    helpBtn:SetPoint("TOPRIGHT", pageHead, "TOPRIGHT", 0, -M.ICON_Y)
    helpBtn:SetScript("OnEnter", function(self)
        local p = ns.Panel(current)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(p and p.label or L["Hilfe"], 1, 0.82, 0)
        for _, line in ipairs(W.HelpLines(content)) do GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    helpBtn:Hide()

    -- 602 x 478 at the window's own height, as before: the pages keep their layout; a taller window
    -- gives the pages' lists more rows (T.PAGE_H, W.FitLists)
    content = CreateFrame("Frame", nil, contentInset)
    content:SetPoint("TOPLEFT", M.PAGE_PAD, -(M.PAGE_PAD + M.PAGE_HEAD))
    content:SetPoint("BOTTOMRIGHT", -M.PAGE_PAD, M.PAGE_PAD)

    grip = buildGrip()
    minBtn = buildMinButton()
    mini = buildMini()
    local state = windowState()
    applySize(state.w or WIDTH, state.h or HEIGHT)
    -- test hooks and the parts the layout tests read
    F.statusBar, F.statusText, F.menuBtn, F.helpBtn, F.settingsBtn, F.headMenu = statusBar, statusText, menuBtn, helpBtn, settingsBtn, headMenu
    F.listInset, F.contentInset, F.nav, F.content, F.navHead = listInset, contentInset, nav, content, navHead
    F.pageHead, F.pageTitle, F.pageSub = pageHead, pageTitle, pageSub
    F.navOrder, F.grip, F.applyHeight, F.applySize, F.heightDone = {}, grip, applyHeight, applySize, sizeDone
    F.minBtn, F.mini, F.Minimize, F.Restore = minBtn, mini, minimize, restore
    F.search, F.results, F.noHits, F.searchHint, F.homeBtn = search, results, noHits, searchHint, homeBtn
end

function ns.CurrentPage() return current end
-- The frame of a page once built (tests, the layout tool), else nil.
function ns.PageFrame(key) return built[key] end
function ns.PreviousPage() return previous end

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
    if current ~= p.key then previous = current end
    current = p.key
    -- its group and the page are remembered for the next open, the page only when asked for
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

local soonPending, soonDirty = false, false
function ns.Refresh()
    if not F or not F:IsShown() then return end
    soonDirty = false
    local p = ns.Panel(current)
    if not ns.Visible(p) then
        showPage("overview", false)
        return
    end
    updateHeader()
    updatePageHead(p)
    local byGroup = pagesByGroup()
    updateNav(byGroup)
    -- the hits again for the new data, at the same scroll place
    if #query >= M.SEARCH_MIN then showResults() else updateSearchHint() end
    local frame = built[current]
    if p.refresh and frame then
        local ok, err = pcall(p.refresh, frame)
        if not ok then reportError(err) end
    end
    updateHelp()
end

-- A refresh at the next frame for data changes (a loot line, an award, a sync, a roster snapshot, a
-- setting): many in one frame make one refresh; nothing while the window is closed (its show
-- refreshes). A refresh in between (a click) takes the place of the waiting one.
function ns.RefreshSoon()
    if not F or not F:IsShown() then return end
    soonDirty = true
    if soonPending then return end
    soonPending = true
    C_Timer.After(0, function()
        soonPending = false
        if soonDirty then ns.Refresh() end
    end)
end

-- The page the window opens with: the open one, else the last of the last group, else the overview.
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

ns.Listen("SETTING", function() ns.RefreshSoon() end)
ns.Listen("DATA_CHANGED", function() ns.RefreshSoon() end)

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

-- With a word: the section it names (ns.SettingsSection), else the settings searched for it.
ns.RegisterSlash("einstellungen", { en = "settings", aliases = { "optionen", "config" }, args = L["[Abschnitt oder Suchwort]"],
    desc = L["Einstellungen öffnen"],
    run = function(rest)
        rest = rest:match("^%s*(.-)%s*$") or ""
        if rest == "" then return ns.ShowPage("settings") end
        local sec = ns.SettingsSection(rest)
        if sec then ns.ShowSettingsSection(sec.key) elseif ns.ShowSettings then ns.ShowSettings(rest) end
    end })
