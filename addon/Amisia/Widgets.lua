-- Amisia widgets: the building blocks the pages share, in the Amisia look (dark purple, gold).
-- Every control is built from plain frames and textures, so both clients draw it the same way.
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

-- A one-line edit box; Enter or leaving the box hands the text to onCommit.
function W.TimeBox(parent, width, onCommit)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 60, 20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetJustifyH("CENTER")
    e:SetTextInsets(4, 4, 0, 0)
    W.Flat(e, 0, 0, 0, 0.5)
    W.Border(e, 1, 1, 1, 0.2)
    local function commit(self)
        if self.committing then return end
        self.committing = true
        if onCommit then onCommit(self:GetText()) end
        self.committing = false
    end
    e:SetScript("OnEnterPressed", function(self)
        commit(self)
        -- losing the focus would commit the same text a second time
        self.committing = true
        self:ClearFocus()
        self.committing = false
    end)
    e:SetScript("OnEditFocusLost", commit)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
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
    f.rows, f.items, f.offset = {}, {}, 0
    f:SetHeight(rowCount * rowHeight)
    for i = 1, rowCount do
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(rowHeight - 1)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
        W.Flat(r, 1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        build(r, i)
        f.rows[i] = r
    end
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
        self.offset = math.max(0, math.min(self.offset, #self.items - rowCount))
        self:Redraw()
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(math.max(0, #self.items - rowCount), self.offset - delta))
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
