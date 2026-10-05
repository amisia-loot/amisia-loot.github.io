-- Amisia widgets: the building blocks the pages share, in the Amisia look (dark purple, gold).
-- Every control is built from plain frames and textures, so it looks the same everywhere.
local ADDON, ns = ...

local W = {}
ns.W = W
W.GOLD = { 0.89, 0.72, 0.34 }
W.BG = { 0.055, 0.04, 0.08, 0.96 }
local GOLD = W.GOLD

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

function W.Button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 22)
    b:SetText(label or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A flat toggle chip: gold when on.
function W.Chip(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 60, 20)
    b.bg = W.Flat(b, 1, 1, 1, 0.06)
    b.edges = W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.35)
    b.label = W.Text(b, "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label or "")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    function b:SetOn(on)
        self.on = on
        self.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.28 or 0.04)
        self.label:SetTextColor(on and 1 or 0.6, on and 0.92 or 0.6, on and 0.7 or 0.6)
        W.SetBorderColor(self.edges, GOLD[1], GOLD[2], GOLD[3], on and 0.8 or 0.25)
    end
    b:SetOn(true)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 0.82, 0)
        if text and text ~= "" then GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A check box: a gold square when on.
function W.Toggle(parent, onChange)
    local b = CreateFrame("Button", nil, parent)
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

-- A number with minus and plus; shift steps ten times as far, the mouse wheel steps too.
function W.Stepper(parent, width, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 120, 20)
    f.min, f.max, f.step = 0, 100, 1
    f.minus = W.Chip(f, "-", 22)
    f.minus:SetPoint("LEFT")
    f.plus = W.Chip(f, "+", 22)
    f.plus:SetPoint("RIGHT")
    f.value = W.Text(f, "GameFontHighlightSmall")
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

-- A one-line edit box on a dark field; Enter or leaving the box hands the text to onCommit once.
-- With restore, Escape puts back what the box held when it took the focus, without a commit.
local function editBox(parent, width, justify, onCommit, restore)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 60, 20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetJustifyH(justify)
    e:SetTextInsets(4, 4, 0, 0)
    W.Flat(e, 0, 0, 0, 0.5)
    W.Border(e, 1, 1, 1, 0.2)
    local function commit(self)
        if self.committing then return end
        self.committing = true
        if onCommit then onCommit(self:GetText()) end
        self.committing = false
    end
    -- leaving the box on purpose must not commit a second time (Enter) or at all (Escape)
    local function leave(self)
        self.committing = true
        self:ClearFocus()
        self.committing = false
    end
    -- the focus goes first, so a refresh from the commit may write the stored value back into the box
    e:SetScript("OnEnterPressed", function(self)
        leave(self)
        commit(self)
    end)
    e:SetScript("OnEditFocusLost", commit)
    if restore then
        e:SetScript("OnEditFocusGained", function(self) self.before = self:GetText() end)
        e:SetScript("OnEscapePressed", function(self)
            if self.before ~= nil then self:SetText(self.before) end
            leave(self)
        end)
    else
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
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

-- A multi-line edit box in a scroll frame, on a dark field.
function W.EditArea(parent)
    local bg = CreateFrame("Frame", nil, parent)
    W.Flat(bg, 0, 0, 0, 0.45)
    W.Border(bg, 1, 1, 1, 0.12)
    local sf = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -28, 6)
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
    bg:SetScript("OnSizeChanged", function(_, w) box:SetWidth(math.max(100, (w or 500) - 40)) end)
    bg.box, bg.scroll = box, sf
    return bg
end

-- Wrapped read-only text that scrolls.
function W.ScrollText(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(10, 10)
    sf:SetScrollChild(child)
    local fs = W.Text(child, "GameFontHighlightSmall", nil, true)
    fs:SetPoint("TOPLEFT")
    fs:SetJustifyV("TOP")
    function sf:SetText(t)
        local w = math.max(100, (self:GetWidth() or 400) - 24)
        fs:SetWidth(w)
        child:SetWidth(w)
        fs:SetText(t or "")
        child:SetHeight((fs:GetStringHeight() or 14) + 8)
    end
    sf.fs = fs
    return sf
end

-- A list with a fixed number of visible rows; the mouse wheel scrolls. build(row, i) makes a row's
-- parts once, fill(row, item, index) shows an item in it.
function W.List(parent, rowCount, rowHeight, build, fill)
    local f = CreateFrame("Frame", nil, parent)
    f.rows, f.items, f.offset, f.rowCount = {}, {}, 0, 0
    -- More rows can be added later (Grow); a list never gets shorter.
    function f:Grow(n)
        for i = self.rowCount + 1, n do
            local r = CreateFrame("Button", nil, self)
            r:SetHeight(rowHeight - 1)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
            r:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
            W.Flat(r, 1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
            local hl = r:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            build(r, i)
            self.rows[i] = r
        end
        if n > self.rowCount then
            self.rowCount = n
            self:SetHeight(n * rowHeight)
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
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(math.max(0, #self.items - self.rowCount), self.offset - delta))
        self:Redraw()
    end)
    return f
end

-- An overview card: title, two lines and at most one button.
function W.Card(parent, width, height)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width, height)
    W.Flat(c, 1, 1, 1, 0.04)
    W.Border(c, GOLD[1], GOLD[2], GOLD[3], 0.3)
    c.title = W.Text(c, "GameFontNormal", width - 20)
    c.title:SetPoint("TOPLEFT", 10, -8)
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
        W.Flat(menu, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
        W.Border(menu, GOLD[1], GOLD[2], GOLD[3], 0.6)
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
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
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
    W.Flat(picker, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
    W.Border(picker, GOLD[1], GOLD[2], GOLD[3], 0.6)
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaPicker") end

    local filter = CreateFrame("EditBox", nil, picker)
    filter:SetHeight(20)
    filter:SetPoint("TOPLEFT", 6, -6)
    filter:SetPoint("TOPRIGHT", -6, -6)
    filter:SetAutoFocus(false)
    filter:SetFontObject(ChatFontNormal)
    filter:SetJustifyH("LEFT")
    filter:SetTextInsets(4, 4, 0, 0)
    W.Flat(filter, 0, 0, 0, 0.5)
    W.Border(filter, 1, 1, 1, 0.2)
    filter:SetScript("OnTextChanged", function() picker:Fill(false) end)
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
    picker.list:SetPoint("TOPLEFT", 6, -30)
    picker.list:SetPoint("TOPRIGHT", -6, -30)

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
    W.Flat(p, 0, 0, 0, 0.5)
    W.Border(p, 1, 1, 1, 0.2)
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
        -- above the window the widget lives in: its top frame under UIParent, and the widget itself
        local top = self
        while top:GetParent() and top:GetParent() ~= UIParent do top = top:GetParent() end
        panel:SetFrameStrata("FULLSCREEN_DIALOG")
        panel:SetFrameLevel(math.min(9000, math.max(top:GetFrameLevel() or 1, self:GetFrameLevel() or 1) + 10))
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
