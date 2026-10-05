-- Amisia widgets: the building blocks the pages share, in the look of Forever's own windows (the
-- profession window): the client's general templates (Blizzard_SharedXML, always loaded) where it
-- has one, the client's atlases where Amisia draws itself. When a template or an atlas is missing
-- (a patch renamed it), each widget falls back to the flat look of before (dark, gold) and stays
-- usable; nothing is reported.
local ADDON, ns = ...

local W = {}
ns.W = W
W.GOLD = { 0.89, 0.72, 0.34 }
W.BG = { 0.055, 0.04, 0.08, 0.96 }
-- the client's title bar: content starts at least this far below a window's top edge
W.TITLE_H = 24
local GOLD = W.GOLD

-- the atlas exists in this client
local function hasAtlas(name)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end
W.HasAtlas = hasAtlas

-- A frame that inherits a template of the client, or nil. probe(frame) checks the parts the caller
-- needs: a client that only logs an unknown template would hand back a bare frame.
local function inherit(kind, name, parent, template, probe)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if not ok or not f then return nil end
    if probe and not probe(f) then
        f:Hide()
        f:ClearAllPoints()
        return nil
    end
    return f
end

function W.Text(parent, template, width, wrap)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(wrap and true or false)
    return fs
end

function W.Flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

function W.Border(frame, r, g, b, a)
    local function edge(p1, p2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        return t
    end
    return { edge("TOPLEFT", "TOPRIGHT", nil, 1), edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
             edge("TOPLEFT", "BOTTOMLEFT", 1, nil), edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil) }
end

function W.SetBorderColor(edges, r, g, b, a)
    for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, a) end
end

-- The input border of the client's edit boxes (InputBoxTemplate: common-search-border-left,
-- -middle, -right) on frame f, all inside its bounds; the flat field of before without the atlases.
local function fieldBorder(f)
    if not hasAtlas("common-search-border-left") then
        W.Flat(f, 0, 0, 0, 0.5)
        f.edges = W.Border(f, 1, 1, 1, 0.2)
        return
    end
    local l = f:CreateTexture(nil, "BACKGROUND")
    l:SetAtlas("common-search-border-left")
    l:SetWidth(8)
    l:SetPoint("TOPLEFT")
    l:SetPoint("BOTTOMLEFT")
    local r = f:CreateTexture(nil, "BACKGROUND")
    r:SetAtlas("common-search-border-right")
    r:SetWidth(8)
    r:SetPoint("TOPRIGHT")
    r:SetPoint("BOTTOMRIGHT")
    local m = f:CreateTexture(nil, "BACKGROUND")
    m:SetAtlas("common-search-border-middle")
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    f.Left, f.Middle, f.Right = l, m, r
end

-- The red button of the profession window (SharedButtonSmallTemplate: 128-RedButton in three
-- slices that follow the height). The template sets OnMouseDown/Up, OnShow, OnEnable/Disable and
-- OnSizeChanged itself: callers only set OnClick (and a tooltip). opts.height: 20 for buttons in
-- rows. Without the template the client's old panel button.
function W.Button(parent, label, width, onClick, opts)
    local b = inherit("Button", nil, parent, "SharedButtonSmallTemplate", function(f) return f.Left and f.Right and f.Center end)
        or inherit("Button", nil, parent, "UIPanelButtonTemplate")
    if not b then
        b = CreateFrame("Button", nil, parent)
        if b.SetNormalFontObject then b:SetNormalFontObject(GameFontNormal) end
        W.Flat(b, 0.5, 0.08, 0.06, 0.9)
        W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.6)
    end
    b:SetSize(width or 120, (opts and opts.height) or 22)
    b:SetText(label or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- The atlases of the client's filter button (WowStyle1FilterDropdown, Blizzard_Menu MenuConstants).
local CHIP = { normal = "common-dropdown-b-button", hover = "common-dropdown-b-button-hover",
               pressed = "common-dropdown-b-button-pressed", pressedhover = "common-dropdown-b-button-pressedhover",
               open = "common-dropdown-b-button-open", disabled = "common-dropdown-b-button-disabled" }
W.CHIP_ATLAS = CHIP

-- A toggle chip in the look of the client's filter button: open and gold text when on, the normal
-- button and grey text when off; hover, press and disabled as the client shows them. The atlas
-- lies on the chip itself (the client's sits 4 px outside, chips 3-4 px apart would touch).
-- Without the atlas the flat chip of before (gold frame).
function W.Chip(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 60, 20)
    b.label = W.Text(b, "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label or "")
    local styled = hasAtlas(CHIP.normal)
    if styled then
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
    else
        b.bg = W.Flat(b, 1, 1, 1, 0.06)
        b.edges = W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.35)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
    end
    function b:UpdateChip()
        if styled then
            local s
            if self.IsEnabled and not self:IsEnabled() then s = CHIP.disabled
            elseif self.chipDown and self.chipOver then s = CHIP.pressedhover
            elseif self.chipOver then s = CHIP.hover
            elseif self.chipDown then s = CHIP.pressed
            elseif self.on then s = CHIP.open
            else s = CHIP.normal end
            self.bg:SetAtlas(s)
        else
            local on = self.on
            self.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.28 or 0.04)
            W.SetBorderColor(self.edges, GOLD[1], GOLD[2], GOLD[3], on and 0.8 or 0.25)
        end
    end
    function b:SetOn(on)
        self.on = on
        if on then
            self.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            self.label:SetTextColor(0.6, 0.6, 0.6)
        end
        self:UpdateChip()
    end
    -- the hover look; W.Tooltip keeps it through this
    function b:SetOver(on)
        self.chipOver = on
        self:UpdateChip()
    end
    b:SetScript("OnEnter", function(self) self:SetOver(true) end)
    b:SetScript("OnLeave", function(self) self:SetOver(false) end)
    b:SetScript("OnMouseDown", function(self) self.chipDown = true self:UpdateChip() end)
    b:SetScript("OnMouseUp", function(self) self.chipDown = false self:UpdateChip() end)
    b:SetScript("OnEnable", function(self) self:UpdateChip() end)
    b:SetScript("OnDisable", function(self) self.chipDown = false self:UpdateChip() end)
    b:SetOn(true)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A chip that cycles through its values on click.
function W.Choice(parent, width, onChange)
    local c = W.Chip(parent, "", width or 120)
    function c:SetValues(values) self.values = values end
    function c:SetValue(v)
        self.current = v
        for _, x in ipairs(self.values or {}) do
            if x[1] == v then self.label:SetText(x[2]) end
        end
    end
    c:SetScript("OnClick", function(self)
        local vals, idx = self.values or {}, 0
        for i, x in ipairs(vals) do
            if x[1] == self.current then idx = i end
        end
        local nextValue = vals[idx % math.max(1, #vals) + 1]
        if nextValue then
            self:SetValue(nextValue[1])
            if onChange then onChange(nextValue[1]) end
        end
    end)
    return c
end

-- The client's dropdown arrow button (the WowStyle1 dropdown of Blizzard_Menu): a dark square with
-- a gold bevel and a gold triangle pointing down. One atlas per state, as the client picks them
-- (GetWowStyle1ArrowButtonState); turned for left and right, then without the drop shadow.
local ARROW = {
    shadow = { normal = "common-dropdown-a-button", hover = "common-dropdown-a-button-hover",
               pressed = "common-dropdown-a-button-pressed", pressedhover = "common-dropdown-a-button-pressedhover",
               open = "common-dropdown-a-button-open", disabled = "common-dropdown-a-button-disabled" },
    flat = { normal = "common-dropdown-a-button-shadowless", hover = "common-dropdown-a-button-hover-shadowless",
             pressed = "common-dropdown-a-button-pressed-shadowless",
             pressedhover = "common-dropdown-a-button-pressedhover-shadowless",
             open = "common-dropdown-a-button-open-shadowless", disabled = "common-dropdown-a-button-disabled-shadowless" },
}
W.ARROW_ATLAS = ARROW
local TURN = { down = 0, right = math.pi / 2, up = math.pi, left = -math.pi / 2 }

-- The atlas for the state of button b: its own flags (over, down) and isOpen() of the owner.
local function arrowState(b)
    local set = b.arrowSet
    if b.IsEnabled and not b:IsEnabled() then return set.disabled end
    if b.arrowDown and b.arrowOver then return set.pressedhover end
    if b.arrowOver then return set.hover end
    if b.arrowDown then return set.pressed end
    if b.isOpen and b.isOpen() then return set.open end
    return set.normal
end

-- A square arrow button (size px, 22 by default) pointing dir ("down", "up", "left", "right").
-- b:UpdateArrow() shows the state again (after an owner opened or closed what the button opens).
function W.ArrowButton(parent, dir, size, onClick)
    local b = CreateFrame("Button", nil, parent)
    size = size or 22
    b:SetSize(size, size)
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetAllPoints()
    local turn = TURN[dir or "down"] or 0
    -- a turned button would throw its shadow sideways: the flat atlases, where the client can turn
    if turn ~= 0 and b.arrow.SetRotation then
        b.arrowSet = ARROW.flat
        b.arrow:SetRotation(turn)
    else
        b.arrowSet = ARROW.shadow
    end
    function b:UpdateArrow()
        self.arrow:SetAtlas(arrowState(self), false)
    end
    -- the hover look; W.Tooltip keeps it through this
    function b:SetOver(on)
        self.arrowOver = on
        self:UpdateArrow()
    end
    b:SetScript("OnEnter", function(self) self.arrowOver = true self:UpdateArrow() end)
    b:SetScript("OnLeave", function(self) self.arrowOver = false self:UpdateArrow() end)
    b:SetScript("OnMouseDown", function(self) self.arrowDown = true self:UpdateArrow() end)
    b:SetScript("OnMouseUp", function(self) self.arrowDown = false self:UpdateArrow() end)
    b:SetScript("OnEnable", function(self) self:UpdateArrow() end)
    b:SetScript("OnDisable", function(self) self.arrowDown = false self:UpdateArrow() end)
    if onClick then b:SetScript("OnClick", onClick) end
    b:UpdateArrow()
    return b
end

function W.Tooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        if self.SetOver then self:SetOver(true) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 0.82, 0)
        if text and text ~= "" then GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if self.SetOver then self:SetOver(false) end
        GameTooltip:Hide()
    end)
end

-- The client's minimal check box (MinimalCheckboxTemplate, as the add-on list's force-load box).
-- A CheckButton turns itself over before OnClick runs; OnClick only reads the state. The field
-- checked mirrors it. The template's textures keep the atlas size (30 x 29), so they are pinned
-- to the 18 x 18 button. Without the template the gold square of before.
function W.Toggle(parent, onChange)
    local b = inherit("CheckButton", nil, parent, "MinimalCheckboxTemplate", function(f) return f.SetChecked and f.GetChecked end)
    if b then
        b:SetSize(18, 18)
        for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "DisabledCheckedTexture" }) do
            local t = b[key]
            if t and t.SetAllPoints then
                t:ClearAllPoints()
                t:SetAllPoints(b)
            end
        end
        local setChecked = b.SetChecked
        function b:SetChecked(on)
            self.checked = on and true or false
            setChecked(self, self.checked)
        end
        b:SetScript("OnClick", function(self)
            self.checked = self:GetChecked() and true or false
            if onChange then onChange(self.checked) end
        end)
        b:SetChecked(false)
        return b
    end
    b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    W.Flat(b, 0, 0, 0, 0.5)
    W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.6)
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("TOPLEFT", 4, -4)
    b.mark:SetPoint("BOTTOMRIGHT", -4, 4)
    b.mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    function b:SetChecked(on)
        self.checked = on and true or false
        if self.checked then self.mark:Show() else self.mark:Hide() end
    end
    function b:GetChecked() return self.checked end
    b:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if onChange then onChange(self.checked) end
    end)
    b:SetChecked(false)
    return b
end

-- A number with arrow buttons left and right, as the profession window's count field; shift steps
-- ten times as far, the mouse wheel steps too. The value sits in a field with the input border.
function W.Stepper(parent, width, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 120, 20)
    f.min, f.max, f.step = 0, 100, 1
    f.minus = W.ArrowButton(f, "left", 20)
    f.minus:SetPoint("LEFT")
    f.plus = W.ArrowButton(f, "right", 20)
    f.plus:SetPoint("RIGHT")
    f.field = CreateFrame("Frame", nil, f)
    f.field:SetHeight(20)
    f.field:SetPoint("LEFT", f.minus, "RIGHT", 2, 0)
    f.field:SetPoint("RIGHT", f.plus, "LEFT", -2, 0)
    fieldBorder(f.field)
    f.value = W.Text(f.field, "ChatFontNormal")
    f.value:SetPoint("CENTER")
    f.value:SetJustifyH("CENTER")
    function f:Configure(min, max, step, fmt)
        self.min, self.max, self.step, self.fmt = min, max, step or 1, fmt
    end
    function f:SetValue(v)
        self.current = v
        self.value:SetText(self.fmt and self.fmt(v) or tostring(v))
    end
    local function bump(dir)
        local mult = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
        local v = math.max(f.min, math.min(f.max, (f.current or f.min) + dir * f.step * mult))
        if v ~= f.current then
            f:SetValue(v)
            if onChange then onChange(v) end
        end
    end
    f.minus:SetScript("OnClick", function() bump(-1) end)
    f.plus:SetScript("OnClick", function() bump(1) end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) bump(delta > 0 and 1 or -1) end)
    return f
end

-- Enter or leaving box e hands its text to onCommit once. With restore, Escape puts back what the
-- box held when it took the focus, without a commit. hook: the focus scripts are added to the
-- template's (a search box shows its clear button and hint through them) instead of replacing them.
local function wireCommit(e, onCommit, restore, hook)
    local function commit(self)
        if self.committing then return end
        self.committing = true
        self.lastCommit = self:GetText()
        if onCommit then onCommit(self:GetText()) end
        self.committing = false
    end
    -- leaving the box on purpose must not commit a second time (Enter) or at all (Escape)
    local function leave(self)
        self.committing = true
        self:ClearFocus()
        self.committing = false
    end
    local function before(self) self.before = self:GetText() end
    -- the focus goes first, so a refresh from the commit may write the stored value back into the box
    e:SetScript("OnEnterPressed", function(self)
        leave(self)
        commit(self)
    end)
    if hook then
        e:HookScript("OnEditFocusLost", commit)
        e:HookScript("OnEditFocusGained", before)
    else
        e:SetScript("OnEditFocusLost", commit)
        -- replaces the template's (it would mark the whole text)
        e:SetScript("OnEditFocusGained", before)
    end
    if restore then
        e:SetScript("OnEscapePressed", function(self)
            if self.before ~= nil then self:SetText(self.before) end
            leave(self)
        end)
    else
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    return commit
end

-- A one-line edit box with the client's input border (InputBoxTemplate); its left edge, which the
-- template puts 5 px outside the box, and the text stay inside the box. Without the template the
-- dark field of before.
local function editBox(parent, width, justify, onCommit, restore)
    local e = inherit("EditBox", nil, parent, "InputBoxTemplate", function(f) return f.Left end)
    if e then
        e.Left:ClearAllPoints()
        e.Left:SetPoint("LEFT", 0, 0)
        e:SetTextInsets(6, 4, 0, 0)
    else
        e = CreateFrame("EditBox", nil, parent)
        W.Flat(e, 0, 0, 0, 0.5)
        W.Border(e, 1, 1, 1, 0.2)
        e:SetTextInsets(4, 4, 0, 0)
    end
    e:SetSize(width or 60, 20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetJustifyH(justify)
    wireCommit(e, onCommit, restore, false)
    return e
end

-- A centred box for a time of day.
function W.TimeBox(parent, width, onCommit)
    return editBox(parent, width or 60, "CENTER", onCommit, false)
end

-- A left-aligned box for a name or a note; Escape restores the text.
function W.LineEdit(parent, width, onCommit)
    return editBox(parent, width or 150, "LEFT", onCommit, true)
end

-- The client's search box (SearchBoxTemplate: magnifying glass, clear button, a grey hint while
-- empty; hint defaults to the client's word for search). It commits like W.LineEdit: Enter or
-- leaving the box once, Escape restores. The template's focus and text scripts stay (hooked); its
-- Enter and Escape only drop the focus, so the box's own take their place (a hook would come too
-- late for Escape to restore without a commit). The clear button commits the empty text when the
-- box did not have the focus. Without the template a line edit with the hint.
function W.SearchBox(parent, width, onCommit, hint)
    hint = hint or SEARCH or "Suchen"
    local e = inherit("EditBox", nil, parent, "SearchBoxTemplate", function(f) return f.Left and f.Instructions and f.clearButton end)
    if not e then
        e = W.LineEdit(parent, width, onCommit)
        e.Instructions = W.Text(e, "GameFontDisableSmall")
        e.Instructions:SetPoint("LEFT", 6, 0)
        e.Instructions:SetPoint("RIGHT", -4, 0)
        e.Instructions:SetText(hint)
        e:HookScript("OnTextChanged", function(self) self.Instructions:SetShown(self:GetText() == "") end)
        return e
    end
    e:SetSize(width or 150, 20)
    e:SetAutoFocus(false)
    e.Left:ClearAllPoints()
    e.Left:SetPoint("LEFT", 0, 0)
    -- the cap moved 5 px in from the template's -5: the magnifier moves with it (template: x 1)
    if e.searchIcon then
        e.searchIcon:ClearAllPoints()
        e.searchIcon:SetPoint("LEFT", 6, -1)
    end
    e.Instructions:SetText(hint)
    local commit = wireCommit(e, onCommit, true, true)
    e.clearButton:HookScript("OnClick", function()
        if e.lastCommit ~= e:GetText() then commit(e) end
    end)
    return e
end

-- Forever's inset (common-insideframe, as the profession window's detail field and the character
-- frame have it): a bevelled frame without a ground of its own, the window's shows through.
-- inset.fill(atlas) or inset.fill(r, g, b, a) puts a ground under it. Without the atlas a thin
-- gold frame. kind makes it another frame type ("Button" for an inset that takes clicks).
function W.Inset(parent, kind)
    local f = CreateFrame(kind or "Frame", nil, parent)
    if hasAtlas("common-insideframe") then
        f.border = f:CreateTexture(nil, "BORDER")
        f.border:SetAllPoints()
        f.border:SetAtlas("common-insideframe")
    else
        f.edges = W.Border(f, GOLD[1], GOLD[2], GOLD[3], 0.3)
    end
    f.fill = function(a, g, b, alpha)
        if not f.ground then
            f.ground = f:CreateTexture(nil, "BACKGROUND")
            f.ground:SetAllPoints()
        end
        if type(a) == "string" then
            if hasAtlas(a) then f.ground:SetAtlas(a) else f.ground:Hide() end
        else
            f.ground:SetColorTexture(a or 0, g or 0, b or 0, alpha or 1)
        end
        return f.ground
    end
    return f
end

-- The glow of a chosen row (the recipe list's Professions_Recipe_Active), stretched over the row,
-- hidden; the gold area of before when the atlas is missing, so a choice stays visible.
function W.SelectBar(row)
    if hasAtlas("Professions_Recipe_Active") then
        local t = row:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetAllPoints()
        t:SetAtlas("Professions_Recipe_Active")
        t:Hide()
        return t
    end
    local t = W.Flat(row, GOLD[1], GOLD[2], GOLD[3], 0.22, "BORDER")
    t:Hide()
    return t
end

-- A section header as in the profession window's recipe list (ListHeaderVisualTemplate with
-- ListHeaderCodeTemplate): gold text on the dark bar, 25 high, a minus to collapse when
-- collapsible. A click turns the state and hands it to onToggle(collapsed); h:SetCollapsed(on)
-- shows a state. The click goes through the template's click handler, so its scripts stay.
function W.SectionHeader(parent, label, collapsible, onToggle)
    local h = inherit("Button", nil, parent, "ListHeaderVisualTemplate, ListHeaderCodeTemplate",
        function(f) return f.ButtonText and f.SetClickHandler and f.SetHeaderText end)
    local function toggle(self)
        if not collapsible then return end
        self:SetCollapsed(not self.collapsed)
        if onToggle then onToggle(self.collapsed) end
    end
    if h then
        h:SetHeight(25)
        h:SetHeaderText(label or "")
        if h.SetTitleColor and NORMAL_FONT_COLOR then h:SetTitleColor(false, NORMAL_FONT_COLOR) end
        if not collapsible then
            -- a plain bar: no hover glow, and the template's OnEnter/OnLeave must not reach the shared
            -- tooltip (it hides whatever another frame shows there)
            if h.CollapseButton then h.CollapseButton:Hide() end
            h:EnableMouse(false)
            h:SetScript("OnEnter", function() end)
            h:SetScript("OnLeave", function() end)
        end
        function h:SetCollapsed(on)
            self.collapsed = on and true or false
            if self.UpdateCollapsedState then self:UpdateCollapsedState(self.collapsed) end
        end
        h:SetClickHandler(toggle)
        h:SetCollapsed(false)
        return h
    end
    h = CreateFrame("Button", nil, parent)
    h:SetHeight(25)
    W.Flat(h, GOLD[1], GOLD[2], GOLD[3], 0.12)
    h.ButtonText = W.Text(h, "GameFontNormal")
    h.ButtonText:SetPoint("LEFT", 8, 0)
    h.ButtonText:SetPoint("RIGHT", -24, 0)
    h.ButtonText:SetText(label or "")
    h.ButtonText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    function h:SetHeaderText(t) self.ButtonText:SetText(t) end
    function h:SetCollapsed(on) self.collapsed = on and true or false end
    h:SetScript("OnClick", toggle)
    h:SetCollapsed(false)
    return h
end

-- The client's thin scroll bar (MinimalScrollBar, 8 px) 4 px to the right of scroll frame sf, as a
-- child of parent; ScrollUtil ties them together (it sets the scroll frame's OnVerticalScroll,
-- OnScrollRangeChanged and OnMouseWheel). Hidden while everything fits. Without the bar the mouse
-- wheel scrolls on its own; returns the bar or nil.
function W.Scroll(sf, parent)
    parent = parent or sf:GetParent()
    local bar = ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar
        and inherit("EventFrame", nil, parent, "MinimalScrollBar", function(f) return f.SetScrollPercentage and f.RegisterCallback end)
    if bar then
        bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
        bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 0)
        ScrollUtil.InitScrollFrameWithScrollBar(sf, bar)
        bar:SetHideIfUnscrollable(true)
        sf:EnableMouseWheel(true)
        sf.bar = bar
        return bar
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 20)))
    end)
    return nil
end

-- A multi-line edit box in a scroll frame, on an inset with a dark ground; the thin bar at the
-- right edge.
function W.EditArea(parent)
    local bg = W.Inset(parent)
    bg.fill(0, 0, 0, 0.35)
    local sf = CreateFrame("ScrollFrame", nil, bg)
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -16, 6)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(500)
    box:SetHeight(200)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(box)
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() box:SetFocus() end)
    bg:SetScript("OnSizeChanged", function(_, w) box:SetWidth(math.max(100, (w or 500) - 28)) end)
    bg.box, bg.scroll = box, sf
    bg.bar = W.Scroll(sf, bg)
    return bg
end

-- Wrapped read-only text that scrolls; the thin bar sits 4 px right of the scroll frame.
function W.ScrollText(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(10, 10)
    sf:SetScrollChild(child)
    local fs = W.Text(child, "GameFontHighlightSmall", nil, true)
    fs:SetPoint("TOPLEFT")
    fs:SetJustifyV("TOP")
    function sf:SetText(t)
        local w = math.max(100, (self:GetWidth() or 400) - 4)
        fs:SetWidth(w)
        child:SetWidth(w)
        fs:SetText(t or "")
        child:SetHeight((fs:GetStringHeight() or 14) + 8)
    end
    sf.fs = fs
    W.Scroll(sf, parent)
    return sf
end

-- A list with a fixed number of visible rows; the mouse wheel scrolls. build(row, i) makes a row's
-- parts once, fill(row, item, index) shows an item in it. Rows change their shade faintly and
-- light up as the recipe list's do. f.bar: the thin scroll bar outside the list on the right
-- (4 px off, 8 wide), hidden while all items fit; opts.bar = false for a list that never scrolls.
function W.List(parent, rowCount, rowHeight, build, fill, opts)
    local f = CreateFrame("Frame", nil, parent)
    f.rows, f.items, f.offset, f.rowCount = {}, {}, 0, 0
    local hover = hasAtlas("Professions_Recipe_Hover")
    -- the bar shows the position; while the list sets it, its answer is not needed
    local function syncBar(self)
        local bar = self.bar
        if not bar then return end
        local n, span = #self.items, math.max(0, #self.items - self.rowCount)
        self.syncing = true
        bar:SetVisibleExtentPercentage(n > 0 and math.min(1, self.rowCount / n) or 1)
        bar:SetPanExtentPercentage(span > 0 and 1 / span or 0)
        bar:SetScrollPercentage(span > 0 and self.offset / span or 0, true)
        self.syncing = false
    end
    -- More rows can be added later (Grow); a list never gets shorter.
    function f:Grow(n)
        for i = self.rowCount + 1, n do
            local r = CreateFrame("Button", nil, self)
            r:SetHeight(rowHeight - 1)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
            r:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
            r.bg = W.Flat(r, 1, 1, 1, (i % 2 == 0) and 0.045 or 0.025)
            r.hover = r:CreateTexture(nil, "HIGHLIGHT")
            r.hover:SetAllPoints()
            if hover then
                r.hover:SetAtlas("Professions_Recipe_Hover")
                r.hover:SetAlpha(0.5)
            else
                r.hover:SetColorTexture(1, 1, 1, 0.08)
            end
            build(r, i)
            self.rows[i] = r
        end
        if n > self.rowCount then
            self.rowCount = n
            self:SetHeight(n * rowHeight)
            syncBar(self)
        end
    end
    if not (opts and opts.bar == false) then
        local bar = inherit("EventFrame", nil, f, "MinimalScrollBar", function(b) return b.SetScrollPercentage and b.RegisterCallback end)
        if bar then
            bar:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
            bar:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 4, 0)
            bar:SetHideIfUnscrollable(true)
            -- the controller's wheel steps pan extent x 2.0; one notch is one row here, as on the list
            bar.wheelPanScalar = 1
            bar:RegisterCallback(BaseScrollBoxEvents and BaseScrollBoxEvents.OnScroll or "OnScroll", function(_, pct)
                if f.syncing then return end
                local span = #f.items - f.rowCount
                if span <= 0 then return end
                local o = math.max(0, math.min(span, math.floor((pct or 0) * span + 0.5)))
                if o ~= f.offset then
                    f.offset = o
                    f:Redraw()
                end
            end, f)
            f.bar = bar
        end
    end
    f:Grow(rowCount)
    function f:Redraw()
        for i, r in ipairs(self.rows) do
            local item = self.items[i + self.offset]
            r.item = item
            if item ~= nil then
                fill(r, item, i + self.offset)
                r:Show()
            else
                r:Hide()
            end
        end
    end
    function f:SetItems(list)
        self.items = list or {}
        self.offset = math.max(0, math.min(self.offset, #self.items - self.rowCount))
        self:Redraw()
        syncBar(self)
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(math.max(0, #self.items - self.rowCount), self.offset - delta))
        self:Redraw()
        syncBar(self)
    end)
    syncBar(f)
    return f
end

-- An overview card: an inset with a gold title, two lines and at most one red button.
function W.Card(parent, width, height)
    local c = W.Inset(parent)
    c:SetSize(width, height)
    c.title = W.Text(c, "GameFontNormal", width - 20)
    c.title:SetPoint("TOPLEFT", 10, -8)
    c.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.line1 = W.Text(c, "GameFontHighlight", width - 20)
    c.line1:SetPoint("TOPLEFT", 10, -28)
    c.line2 = W.Text(c, "GameFontDisableSmall", width - 20, true)
    c.line2:SetPoint("TOPLEFT", 10, -48)
    c.button = W.Button(c, "", 110)
    c.button:SetPoint("BOTTOMLEFT", 10, 8)
    function c:SetAction(label, fn)
        if label then
            self.button:SetText(label)
            self.button:SetScript("OnClick", fn)
            self.button:Show()
        else
            self.button:Hide()
        end
    end
    return c
end

-- The ground of the client's menus (MenuStyle1Mixin: common-dropdown-bg 10 px wider and 3 px
-- higher than the menu, alpha 0.925) on frame f; the dark field with a gold frame without it.
local function menuGround(f)
    if hasAtlas("common-dropdown-bg") then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAtlas("common-dropdown-bg")
        f.bg:SetPoint("TOPLEFT", -10, 3)
        f.bg:SetPoint("BOTTOMRIGHT", 10, -3)
        f.bg:SetAlpha(0.925)
    else
        f.bg = W.Flat(f, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
        f.edges = W.Border(f, GOLD[1], GOLD[2], GOLD[3], 0.6)
    end
end

-- The frame level for a panel that opens from widget w: above the window w lives in (its top
-- frame under UIParent), whose client frame lies at 500 and its title and close button at 510.
local function levelAbove(w)
    local top = w
    while top:GetParent() and top:GetParent() ~= UIParent do top = top:GetParent() end
    return math.min(9000, math.max(top:GetFrameLevel() or 1, w:GetFrameLevel() or 1) + 520), top
end

-- A small popup menu under owner; a click runs the entry and closes it. Leaving it for two seconds
-- or Escape closes it too.
local menu
function W.Menu(owner, entries)
    if menu and menu:IsShown() and menu.owner == owner then
        menu:Hide()
        return menu
    end
    if not menu then
        menu = CreateFrame("Frame", "AmisiaMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        menuGround(menu)
        menu.buttons = {}
        if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaMenu") end
        menu:SetScript("OnUpdate", function(self, elapsed)
            local owner = self.owner ~= UIParent and self.owner or nil
            if self:IsMouseOver() or (owner and owner:IsMouseOver()) then
                self.away = 0
            else
                self.away = (self.away or 0) + (elapsed or 0)
                if self.away > 2 then self:Hide() end
            end
        end)
    end
    menu.owner = owner
    menu.away = 0
    for i, e in ipairs(entries) do
        local b = menu.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetSize(170, 20)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
            b.label = W.Text(b, "GameFontHighlightSmall", 160)
            b.label:SetPoint("LEFT", 6, 0)
            -- the client menu's hover (MenuVariants.CreateHighlight)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetAllPoints()
            b.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b.hl:SetBlendMode("ADD")
            menu.buttons[i] = b
        end
        b.label:SetText(e[1])
        b:SetScript("OnClick", function()
            menu:Hide()
            e[2]()
        end)
        b:Show()
    end
    for i = #entries + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:SetSize(182, 12 + #entries * 20)
    menu:ClearAllPoints()
    if owner == UIParent and GetCursorPosition then
        -- no button to hang it on (the compartment entry with the minimap button hidden): at the cursor
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / s, y / s)
    else
        menu:SetPoint("TOPRIGHT", owner, "BOTTOMLEFT", 0, 0)
        -- an owner in a window of the menu's strata: above that window's frame
        local level, top = levelAbove(owner)
        if top ~= owner and top.GetFrameStrata and top:GetFrameStrata() == "FULLSCREEN_DIALOG" then
            menu:SetFrameLevel(level)
        end
    end
    menu:Show()
    return menu
end

-- A pick from a list. The widget shows the current text; a click opens the shared panel under it
-- with a filter box and a scrolling list. values = { { value = x, text = "..." } }, onPick(value,
-- isFree). An optional last entry (freeText, "Anderer Name") takes the filter text as a value of
-- its own. Enter in the filter picks the single match, or the typed text when nothing matches and
-- free text is allowed. Escape, a pick or a second click on the widget close the panel.
local picker
local PICK_ROWS, PICK_ROW_H = 8, 20

local function pickerChoose(entry)
    local owner = picker.owner
    if not owner or not entry then return end
    local value, free = entry.value, false
    if entry.free then
        value = (picker.filter:GetText() or ""):match("^%s*(.-)%s*$")
        if value == "" then
            picker.filter:SetFocus()
            return
        end
        free = true
    end
    picker:Hide()
    owner:SetValue(value)
    if owner.onPick then owner.onPick(value, free) end
end

local function pickerPanel()
    if picker then return picker end
    picker = CreateFrame("Frame", "AmisiaPicker", UIParent)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    -- the owner may sit in a top-level dialog of the same strata; the panel must come out on top
    picker:SetToplevel(true)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    menuGround(picker)
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaPicker") end

    -- the filter is a search box; Enter and Escape pick and close instead of committing
    local filter = W.SearchBox(picker, nil, nil, SEARCH or "Suchen")
    filter:ClearAllPoints()
    filter:SetHeight(20)
    filter:SetPoint("TOPLEFT", 6, -6)
    filter:SetPoint("TOPRIGHT", -6, -6)
    filter:HookScript("OnTextChanged", function() picker:Fill(false) end)
    filter:SetScript("OnEscapePressed", function() picker:Hide() end)
    filter:SetScript("OnEnterPressed", function()
        local real, free = {}, nil
        for _, e in ipairs(picker.shown or {}) do
            if e.free then free = e else real[#real + 1] = e end
        end
        if #real == 1 then
            pickerChoose(real[1])
        elseif #real == 0 and free then
            pickerChoose(free)
        end
    end)
    picker.filter = filter

    picker.list = W.List(picker, PICK_ROWS, PICK_ROW_H, function(r)
        r.text = W.Text(r, "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 6, 0)
        r.text:SetPoint("RIGHT", -6, 0)
        r:SetScript("OnClick", function(self) pickerChoose(self.item) end)
    end, function(r, e)
        r.text:SetText(e.text or "")
        local owner = picker.owner
        if e.free then
            r.text:SetTextColor(0.56, 0.53, 0.64)
        elseif owner and e.value == owner.current then
            r.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            r.text:SetTextColor(1, 1, 1)
        end
    end)
    -- the rows end before the bar (4 px gap, 8 wide, 6 to the edge)
    picker.list:SetPoint("TOPLEFT", 6, -30)
    picker.list:SetPoint("TOPRIGHT", -18, -30)

    -- the entries the filter leaves, the free entry always last; keep holds the scroll position
    function picker:Fill(keep)
        local owner = self.owner
        if not owner then return end
        local q = (self.filter:GetText() or ""):lower():match("^%s*(.-)%s*$")
        local shown = {}
        for _, e in ipairs(owner.values or {}) do
            if q == "" or tostring(e.text or ""):lower():find(q, 1, true) then shown[#shown + 1] = e end
        end
        if owner.freeText then shown[#shown + 1] = { free = true, text = owner.freeText } end
        self.shown = shown
        if not keep then self.list.offset = 0 end
        self.list:SetItems(shown)
    end
    -- closes when the mouse stays away for two seconds without the filter in use, or when the
    -- widget it belongs to disappears
    picker:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        if owner and not owner:IsVisible() then self:Hide() return end
        if self:IsMouseOver() or (owner and owner:IsMouseOver()) or self.filter:HasFocus() then
            self.away = 0
        else
            self.away = (self.away or 0) + (elapsed or 0)
            if self.away > 2 then self:Hide() end
        end
    end)
    picker:SetScript("OnHide", function(self)
        self.filter:ClearFocus()
        -- the owner's arrow leaves its open state
        if self.owner and self.owner.arrow then self.owner.arrow:UpdateArrow() end
    end)
    picker:Hide()
    return picker
end

function W.Picker(parent, width, onPick)
    local p = CreateFrame("Button", nil, parent)
    p:SetSize(width or 150, 20)
    -- the field looks like every edit box: the client's input border
    fieldBorder(p)
    local hl = p:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    p.label = W.Text(p, "GameFontHighlightSmall")
    p.label:SetPoint("LEFT", 6, 0)
    p.label:SetPoint("RIGHT", -26, 0)
    -- the client's dropdown button at the right end (22 px, one over the 20 px field top and
    -- bottom); a click on it opens like a click on the field, hovering the field lights it too
    p.arrow = W.ArrowButton(p, "down", 22, function() p:Click() end)
    p.arrow:SetPoint("RIGHT", 1, 0)
    p.arrow.isOpen = function() return picker ~= nil and picker:IsShown() and picker.owner == p end
    local function over(on)
        return function()
            p.arrow.arrowOver = on
            p.arrow:UpdateArrow()
        end
    end
    p:HookScript("OnEnter", over(true))
    p:HookScript("OnLeave", over(false))
    p:HookScript("OnMouseDown", function() p.arrow.arrowDown = true p.arrow:UpdateArrow() end)
    p:HookScript("OnMouseUp", function() p.arrow.arrowDown = false p.arrow:UpdateArrow() end)
    p:HookScript("OnEnable", function() p.arrow:Enable() end)
    p:HookScript("OnDisable", function() p.arrow:Disable() end)
    p.onPick = onPick
    p.values = {}
    -- the list to pick from; freeText names the optional free-text entry at its end. A page
    -- refresh hands the same list again: the open panel keeps its filter and scroll position.
    function p:SetValues(values, freeText)
        values = values or {}
        local same = freeText == self.freeText and #values == #self.values
        if same then
            for i, e in ipairs(values) do
                local o = self.values[i]
                if e.value ~= o.value or e.text ~= o.text then same = false break end
            end
        end
        self.values, self.freeText = values, freeText
        if not same and picker and picker:IsShown() and picker.owner == self then picker:Fill(true) end
    end
    function p:SetValue(v)
        self.current = v
        local text
        for _, e in ipairs(self.values) do
            if e.value == v then text = e.text break end
        end
        self.label:SetText(text or (v ~= nil and tostring(v)) or "")
    end
    function p:GetValue() return self.current end
    function p:Open()
        local panel = pickerPanel()
        -- another picker's panel moves here: that arrow closes
        local before = panel:IsShown() and panel.owner ~= self and panel.owner or nil
        panel.owner = self
        if before and before.arrow then before.arrow:UpdateArrow() end
        panel.away = 0
        panel:SetSize(math.max(180, self:GetWidth() or 0), 36 + PICK_ROWS * PICK_ROW_H + 6)
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        -- above the window the widget lives in, its frame (level 500) and title bar (510) included
        panel:SetFrameStrata("FULLSCREEN_DIALOG")
        panel:SetFrameLevel((levelAbove(self)))
        panel.filter:SetText("")
        panel:Fill(false)
        panel:Show()
        panel:Raise()
        panel.filter:SetFocus()
        self.arrow:UpdateArrow()
    end
    function p:Close()
        if picker and picker.owner == self then picker:Hide() end
    end
    p:SetScript("OnClick", function(self)
        if picker and picker:IsShown() and picker.owner == self then picker:Hide() else self:Open() end
    end)
    p:SetScript("OnHide", function(self) self:Close() end)
    return p
end

-- A window in the look of Forever's own (PortraitFrameTemplate: the metal frame, the title bar
-- with the gold title in the middle and the red close button, the portrait at the top left).
-- opts: portrait (a texture; none makes a dialog without one, title over the whole bar), title,
-- strata, background (an atlas stretched over the ground, or the template's rock), onShow,
-- onVisibility (runs on show and hide), onDragStop, escape (false: Escape does not close it). The
-- close button hides the window directly: the
-- template's goes through HideUIPanel, which is blocked in combat for an addon's button. Without
-- the template the flat window of before, with the same fields and methods.
function W.Window(name, width, height, opts)
    opts = opts or {}
    local F = inherit("Frame", name, UIParent, "PortraitFrameTemplate",
        function(f) return f.TitleContainer and f.TitleContainer.TitleText and f.CloseButton and f.SetTitle end)
    if F then
        if opts.portrait then
            F:SetPortraitToAsset(opts.portrait)
        else
            if F.SetBorder then pcall(F.SetBorder, F, "ButtonFrameTemplateNoPortrait") end
            if F.SetPortraitShown then F:SetPortraitShown(false) end
            if F.SetTitleOffsets then F:SetTitleOffsets(0, 0) end
        end
        if opts.background and F.Bg and hasAtlas(opts.background) then
            if F.Bg.SetHorizTile then F.Bg:SetHorizTile(false) end
            if F.Bg.SetVertTile then F.Bg:SetVertTile(false) end
            F.Bg:SetAtlas(opts.background)
            if F.TopTileStreaks then F.TopTileStreaks:Hide() end
        end
    else
        F = CreateFrame("Frame", name, UIParent)
        W.Flat(F, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
        F.edges = W.Border(F, GOLD[1], GOLD[2], GOLD[3], 0.6)
        F.TitleContainer = CreateFrame("Frame", nil, F)
        F.TitleContainer:SetHeight(20)
        F.TitleContainer:SetPoint("TOPLEFT", 12, -1)
        F.TitleContainer:SetPoint("TOPRIGHT", -28, -1)
        local title = W.Text(F.TitleContainer, "GameFontNormal")
        title:SetPoint("TOP", 0, -5)
        title:SetPoint("LEFT")
        title:SetPoint("RIGHT")
        title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        F.TitleContainer.TitleText = title
        F.CloseButton = inherit("Button", nil, F, "UIPanelCloseButton")
        if not F.CloseButton then
            F.CloseButton = CreateFrame("Button", nil, F)
            F.CloseButton:SetSize(24, 24)
            local x = W.Text(F.CloseButton, "GameFontNormal")
            x:SetPoint("CENTER")
            x:SetText("x")
        end
        F.CloseButton:SetPoint("TOPRIGHT", 0, 0)
        function F:GetTitleText() return self.TitleContainer.TitleText end
        function F:SetTitle(t) self.TitleContainer.TitleText:SetText(t) end
        function F:SetPortraitToAsset(tex) self.portraitAsset = tex end
        function F:SetPortraitShown() end
        function F:SetTitleOffsets() end
        function F:SetBorder() end
    end
    F.CloseButton:SetScript("OnClick", function(b) b:GetParent():Hide() end)
    F:SetSize(width, height)
    if opts.strata then F:SetFrameStrata(opts.strata) end
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if opts.onDragStop then opts.onDragStop(self) end
    end)
    if opts.title then F:SetTitle(opts.title) end
    F:Hide()
    if opts.onShow then F:SetScript("OnShow", opts.onShow) end
    if opts.onVisibility then
        F:HookScript("OnShow", opts.onVisibility)
        F:HookScript("OnHide", opts.onVisibility)
    end
    -- Escape closes it, unless opts.escape is false (a window that stays through Escape)
    if name and UISpecialFrames and opts.escape ~= false then tinsert(UISpecialFrames, name) end
    return F
end
