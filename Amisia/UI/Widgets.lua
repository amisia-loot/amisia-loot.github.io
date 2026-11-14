-- Amisia widgets: the building blocks the pages share, in the look of Forever's own windows (the
-- profession window): the client's general templates (Blizzard_SharedXML, always loaded) where it
-- has one, the client's atlases where Amisia draws itself. When a template or an atlas is missing
-- (a patch renamed it), each widget falls back to the flat look of before (dark, gold) and stays
-- usable; nothing is reported.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local T = ns.Theme
local W = {}
ns.W = W
W.GOLD = T.GOLD
W.BG = T.BG
-- the client's title bar: content starts at least this far below a window's top edge
W.TITLE_H = T.TITLE_H
local GOLD = W.GOLD

-- the atlas exists in this client
local function hasAtlas(name)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end
W.HasAtlas = hasAtlas

-- The wish list star of a row (Planner, Dungeons): b.tex gold when on, grey when off; b.on keeps it.
function W.WishStar(b, on)
    local PL = T.PLANNER
    local tex = b.tex
    if hasAtlas(PL.STAR_ATLAS) then tex:SetAtlas(PL.STAR_ATLAS, false) else tex:SetTexture(PL.STAR_FILE) end
    if tex.SetDesaturated then tex:SetDesaturated(not on) end
    local c = on and { 1, 1, 1 } or PL.STAR_OFF
    tex:SetVertexColor(c[1], c[2], c[3])
    b.on = on
end

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
    local fs = parent:CreateFontString(nil, "OVERLAY", template or T.FONT.text)
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(wrap and true or false)
    return fs
end

---------------------------------------------------------------------------
-- Layout helpers: rows, columns and grids of frames, and chips sized to their text
---------------------------------------------------------------------------

-- An entry of W.Row or W.Column: a frame, or { frame, gap = px before it (instead of the row's),
-- y = its own offset across a row (a label beside a field sits lower), right = in a column, its
-- right edge that far from the parent's (it spans the width) }.
local function rowEntry(e)
    if type(e) == "table" and e[1] ~= nil and type(e[1]) == "table" then return e[1], e.gap, e.y, e.right end
    return e, nil, nil, nil
end

-- Places items (listed left to right) in a row in parent: the first with its point (opts.point,
-- "TOPLEFT") at x, y, each next gap px after the one before, every one at its own width. With
-- opts.right the row hangs from the parent's right edge instead (point "TOPRIGHT"): the last item x px
-- from that edge, the others to its left. Hidden items are passed over with opts.shown (a row whose
-- parts come and go). Returns how far the row reaches from where it starts (x plus its width).
function W.Row(parent, items, gap, x, y, opts)
    local right = opts and opts.right
    local point = opts and opts.point or (right and "TOPRIGHT" or "TOPLEFT")
    local onlyShown = opts and opts.shown
    local at, placed = x or 0, false
    local first, last, step = 1, #items, 1
    if right then first, last, step = #items, 1, -1 end
    local pendingGap, prev
    for i = first, last, step do
        local f, own, ownY = rowEntry(items[i])
        if f and not (onlyShown and not f:IsShown()) then
            -- the gap that belongs between two items stands before the right one of them; two text
            -- tabs keep at least their own gap (D-67), whatever a chip row asked for
            if placed then
                local g = (right and pendingGap or own) or gap or 0
                if f.isTab and prev and prev.isTab and g < T.TAB_GAP then g = T.TAB_GAP end
                at = at + g
            end
            prev = f
            if f.isTab then f.replace = function() W.Row(parent, items, gap, x, y, opts) end end
            f:ClearAllPoints()
            f:SetPoint(point, parent, point, right and -at or at, ownY or y or 0)
            at = at + (f:GetWidth() or 0)
            placed = true
            pendingGap = own
        end
    end
    return at
end

-- Stacks items top to bottom in parent from y (a SetPoint offset, 0 or below): each at x (TOPLEFT),
-- gap px under the one before, at its own height. opts.right: every item's right edge that far from
-- the parent's (they span the width; an entry's own right wins); opts.shown: hidden items are passed
-- over. Returns the offset below the last placed item (y when none was placed).
function W.Column(parent, items, gap, x, y, opts)
    local onlyShown = opts and opts.shown
    local at, placed = y or 0, false
    for _, e in ipairs(items) do
        local f, own, _, ownRight = rowEntry(e)
        if f and not (onlyShown and not f:IsShown()) then
            if placed then at = at - (own or gap or 0) end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, at)
            local right = ownRight or (opts and opts.right)
            if right then f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -right, at) end
            at = at - (f:GetHeight() or 0)
            placed = true
        end
    end
    return at
end

-- Places items in a grid of cols columns from x, y (TOPLEFT): cells as large as the first item,
-- gapX and gapY between them, row by row. Returns the offset below the last row.
function W.Grid(parent, items, cols, gapX, gapY, x, y)
    local first = items[1]
    if not first then return y or 0 end
    local w, h = first:GetWidth() or 0, first:GetHeight() or 0
    for i, f in ipairs(items) do
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", (x or 0) + c * (w + gapX), (y or 0) - r * (h + gapY))
    end
    return (y or 0) - math.ceil(#items / cols) * (h + gapY) + gapY
end

-- Sizes a chip or a red button to its text and the padding on both sides (pad, else the theme's),
-- at least minW wide and at most maxW (both optional). Returns the width.
function W.FitChip(b, minW, maxW, pad)
    -- a text tab is as wide as its word (D-67): no minimum, its own cap unless one is given
    if b.isTab then
        if maxW then b.maxW = maxW end
        return b:Fit()
    end
    local fs = b.label or b.Text or (b.GetFontString and b:GetFontString())
    local text = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
    local w = text + 2 * (pad or T.CHIP_PAD)
    if minW and w < minW then w = minW end
    if maxW and w > maxW then w = maxW end
    b:SetWidth(w)
    return w
end

function W.Flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

-- A frame of four edges round frame in one colour; px: their thickness (1 without).
function W.Border(frame, r, g, b, a, px)
    px = px or 1
    local function edge(p1, p2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        return t
    end
    return { edge("TOPLEFT", "TOPRIGHT", nil, px), edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, px),
             edge("TOPLEFT", "BOTTOMLEFT", px, nil), edge("TOPRIGHT", "BOTTOMRIGHT", px, nil) }
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
    l:SetWidth(T.FIELD_CAP)
    l:SetPoint("TOPLEFT")
    l:SetPoint("BOTTOMLEFT")
    local r = f:CreateTexture(nil, "BACKGROUND")
    r:SetAtlas("common-search-border-right")
    r:SetWidth(T.FIELD_CAP)
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
    b:SetSize(width or T.BUTTON_W, (opts and opts.height) or T.BUTTON_H)
    b:SetText(label or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- The client's small reset button (UIResetButtonTemplate: the red circle with the gold x), for
-- "back to the default" and "remove this". Without the template or its atlas a small red button.
function W.ResetButton(parent, size, onClick)
    size = size or T.RESET
    local b = hasAtlas("auctionhouse-ui-filter-redx") and CreateFrame("Button", nil, parent)
    if b then
        b:SetSize(size, size)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetAtlas("auctionhouse-ui-filter-redx")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetAtlas("auctionhouse-ui-filter-redx")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
    else
        b = W.Button(parent, "x", size + 4, nil, { height = size })
    end
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A quiet text tab (D-67) with the chip's interface (SetOn, on, label, dim, SetOver, UpdateChip), so a
-- page swaps W.Chip for W.Tab and keeps its logic: views and filters as gold words, the chosen one white
-- over a thin gold line (as the client's settings tabs). opts.check: an on/off filter with the client's
-- small check box (MinimalCheckboxTemplate, not clickable itself) before its word instead of the line.
-- Its width follows its word (W.FitChip ignores a minimum for tabs and sets a cap).
function W.Tab(parent, label, onClick, opts)
    local b = CreateFrame("Button", nil, parent)
    b.isTab = true
    -- the width a chip was given is no limit for a word: a tab is as wide as its word (a cap only
    -- through W.FitChip's maxW)
    b:SetHeight(T.CHIP_H)
    local x = T.TAB_PAD
    if opts and opts.check then
        b.box = W.Toggle(b, nil)
        b.box:SetSize(T.TAB_CHECK, T.TAB_CHECK)
        b.box:SetPoint("LEFT", T.TAB_PAD, 0)
        if b.box.EnableMouse then b.box:EnableMouse(false) end
        x = T.TAB_PAD + T.TAB_CHECK + T.TAB_CHECK_GAP
    end
    b.textX = x
    b.label = W.Text(b, T.FONT.text)
    b.label:SetPoint("LEFT", x, 0)
    b.label:SetJustifyH("LEFT")
    -- a page that writes the word straight into the label (a count) still gets a tab that fits it
    local setLabel = b.label.SetText
    b.label.SetText = function(fs, t)
        setLabel(fs, t)
        if b.Fit then b:Fit() end
    end
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetHeight(T.TAB_LINE)
    b.line:SetPoint("BOTTOMLEFT", b.label, "BOTTOMLEFT", 0, -3)
    b.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 0, 0)
    hl:SetPoint("BOTTOMRIGHT", 0, 0)
    hl:SetColorTexture(1, 1, 1, 0.06)
    function b:Fit()
        local w = self.textX + (self.label:GetStringWidth() or 0) + T.TAB_PAD
        if self.maxW and w > self.maxW then w = self.maxW end
        local before = self:GetWidth()
        self:SetWidth(w)
        self.line:SetWidth(math.max(1, math.min(self.label:GetStringWidth() or 0, w - self.textX - T.TAB_PAD)))
        -- a new word (a count) changes the width: the row it sits in places its items again
        if self.replace and before and math.abs(before - w) > 0.5 then self.replace() end
        return w
    end
    function b:SetText(t)
        self.label:SetText(t or "")
    end
    function b:GetText() return self.label:GetText() end
    function b:UpdateChip()
        local on, over = self.on, self.chipOver
        if self.box then
            self.box:SetChecked(on)
            -- a filter that cannot be used now: its box greyed with its word
            self.box:SetAlpha(((self.IsEnabled and not self:IsEnabled()) or self.dim) and 0.5 or 1)
            self.line:Hide()
        else
            self.line:SetShown(on and true or false)
        end
        local c
        if (self.IsEnabled and not self:IsEnabled()) or self.dim then
            c = T.TEXT_DISABLED
        elseif on or over then
            c = T.TAB_ON
        else
            c = T.TAB_OFF
        end
        self.label:SetTextColor(c[1], c[2], c[3])
    end
    function b:SetOn(on)
        self.on = on
        self:UpdateChip()
    end
    function b:SetOver(on)
        self.chipOver = on
        self:UpdateChip()
    end
    b:HookScript("OnEnter", function(self) self:SetOver(true) end)
    b:HookScript("OnLeave", function(self) self:SetOver(false) end)
    -- a page that sets its own hover scripts (a tooltip) keeps the white word under the mouse
    local setScript = b.SetScript
    b.SetScript = function(self, kind, fn)
        if fn and (kind == "OnEnter" or kind == "OnLeave") then
            local on = kind == "OnEnter"
            local own = fn
            fn = function(f, ...)
                f:SetOver(on)
                return own(f, ...)
            end
        end
        return setScript(self, kind, fn)
    end
    b:HookScript("OnEnable", function(self) self:UpdateChip() end)
    b:HookScript("OnDisable", function(self) self:UpdateChip() end)
    b:SetText(label)
    b:SetOn(true)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A quiet action (D-67): a gold word that lights up under the mouse, for every action of a view but
-- its one red button ("Warum?", "Alle auf Karte", "Öffnen" on a card). The text tab's look without a
-- chosen state; label, SetText, Click, Enable/Disable as a button.
function W.Link(parent, label, onClick)
    -- as wide as its word
    local b = W.Tab(parent, label, onClick)
    b.isLink = true
    b:SetOn(false)
    b.SetOn = function(self) self.on = false; self:UpdateChip() end
    return b
end

-- An on/off filter as a text tab with the client's small check box before its word (D-67).
function W.TabCheck(parent, label, onClick)
    return W.Tab(parent, label, onClick, { check = true })
end

-- A small icon button of the client, without a red ground (D-67): art.atlas (with the client's
-- additive highlight, as UIPanelIconDropdownButtonTemplate) or art.file (a texture). Without either
-- the fallback text in gold, so the button stays usable after a patch renamed the art.
function W.IconButton(parent, size, art, onClick, fallback)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local function paint(tex)
        if art.atlas and hasAtlas(art.atlas) then
            tex:SetAtlas(art.atlas)
            return true
        elseif art.file then
            tex:SetTexture(art.file)
            if art.coords then tex:SetTexCoord(unpack(art.coords)) end
            return true
        end
        return false
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    if paint(b.icon) then
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        paint(hl)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
    else
        b.icon:Hide()
        b.label = W.Text(b, T.FONT.title)
        b.label:SetPoint("CENTER")
        b.label:SetText(fallback or "?")
    end
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- Row actions (D-67): a button of a list row ("Karte", "Wunsch", "Entfernen") shows only while the
-- mouse is on its row, so a list reads as text and the action is there where you point. Only the
-- alpha follows the mouse: the fill code shows and hides the button as before, and a button at
-- alpha 0 is never clicked by chance, because the mouse is on its row as soon as it is on the button.
-- row.actionsPinned (W.PinRowActions) keeps them visible, as for the chosen row. One driver checks
-- the shown rows a few times a second; rows need no mouse scripts of their own.
local actionRows = setmetatable({}, { __mode = "k" })
local actionDriver
local function syncActions(row)
    local on = row.actionsPinned or (row.IsMouseOver ~= nil and row:IsMouseOver()) or false
    if row.actionsOn == on then return end
    row.actionsOn = on
    for _, b in ipairs(row.rowActions) do b:SetAlpha(on and 1 or 0) end
end
function W.RowAction(row, btn)
    if not row.rowActions then
        row.rowActions = {}
        actionRows[row] = true
    end
    row.rowActions[#row.rowActions + 1] = btn
    btn:SetAlpha(row.actionsPinned and 1 or 0)
    row.actionsOn = row.actionsPinned and true or false
    if not actionDriver then
        actionDriver = CreateFrame("Frame")
        local wait = 0
        actionDriver:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate RowActions", function(_, elapsed)
            wait = wait - (elapsed or 0)
            if wait > 0 then return end
            wait = T.ROW_ACTION_TICK
            W.SyncRowActions()
        end))
    end
    return btn
end
-- One pass of the driver: every visible row with actions follows the mouse (tests call it directly).
function W.SyncRowActions()
    for r in pairs(actionRows) do
        if r:IsVisible() then syncActions(r) end
    end
end
function W.PinRowActions(row, on)
    row.actionsPinned = on and true or nil
    if row.rowActions then syncActions(row) end
end

-- A toggle chip in the classic look of the window: the client's small red button
-- (SharedButtonSmallTemplate, as "Pausieren" and the profession window's "Erstellen"). On: the
-- button as it is, gold text. Off: the same button darkened, grey text. Press, hover and disabled
-- as the template shows them (its scripts are hooked, never replaced). Without the template the
-- flat chip of before (gold frame).
local CHIP_OFF = T.CHIP_OFF
function W.Chip(parent, label, width, onClick)
    local b = inherit("Button", nil, parent, "SharedButtonSmallTemplate", function(f) return f.Left and f.Right and f.Center end)
    local styled = b ~= nil
    if not b then b = CreateFrame("Button", nil, parent) end
    b:SetSize(width or T.CHIP_W, T.CHIP_H)
    if styled and b.SetText then b:SetText("") end
    b.label = W.Text(b, T.FONT.text)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label or "")
    b.styled = styled
    if not styled then
        b.bg = W.Flat(b, 1, 1, 1, 0.06)
        b.edges = W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.35)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
    end
    function b:UpdateChip()
        local on = self.on
        if self.styled then
            local v = on and 1 or CHIP_OFF
            for _, k in ipairs({ "Left", "Right", "Center" }) do self[k]:SetVertexColor(v, v, v) end
        else
            self.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.28 or 0.04)
            W.SetBorderColor(self.edges, GOLD[1], GOLD[2], GOLD[3], on and 0.8 or 0.25)
        end
        -- dim: greyed text while it filters nothing, the chip still works (a count of 0)
        local c = ((self.IsEnabled and not self:IsEnabled()) or self.dim) and T.TEXT_DISABLED or (on and GOLD or T.TEXT_OFF)
        self.label:SetTextColor(c[1], c[2], c[3])
    end
    function b:SetOn(on)
        self.on = on
        self:UpdateChip()
    end
    -- the hover look (the template's highlight); W.Tooltip calls this
    function b:SetOver(on) self.chipOver = on end
    local function hook(script, fn)
        if b.HookScript then b:HookScript(script, fn) else b:SetScript(script, fn) end
    end
    hook("OnEnable", function(self) self:UpdateChip() end)
    hook("OnDisable", function(self) self:UpdateChip() end)
    -- the template sets its slices again on a press: the darkening follows
    hook("OnMouseDown", function(self) self:UpdateChip() end)
    hook("OnMouseUp", function(self) self:UpdateChip() end)
    b:SetOn(true)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A value field to choose from (the client's dropdown, D-67).
function W.Choice(parent, width, onChange)
    -- a value to choose (D-67): the client's dropdown field (W.Picker) instead of a red button that
    -- went to the next value on each click. values = { { value, text }, ... } as before; c.current
    -- holds the chosen value; c:Cycle() picks the next one (as a click did, for tests and keys).
    local c
    c = W.Picker(parent, width or T.CHOICE_W, function(v)
        c:SetValue(v)
        if onChange then onChange(v) end
    end)
    c.isChoice = true
    local setValues = c.SetValues
    function c:SetValues(values)
        self.choices = values or {}
        local list = {}
        for _, x in ipairs(self.choices) do list[#list + 1] = { value = x[1], text = x[2] } end
        setValues(self, list)
        if self.current ~= nil then self:SetValue(self.current) end
    end
    function c:Cycle()
        local vals, idx = self.choices or {}, 0
        for k, x in ipairs(vals) do
            if x[1] == self.current then idx = k end
        end
        local nextValue = vals[idx % math.max(1, #vals) + 1]
        if nextValue then self.onPick(nextValue[1]) end
    end
    return c
end

-- An atlas drawn as three pieces across holder: the left and right cap (cap px of the atlas at
-- its own size) stay as they are, the middle stretches. For the client's fixed-width bars that
-- have to fill a wider place without bending their round ends. Returns the three textures, or nil
-- without the atlas data (the caller keeps its fallback).
function W.SlicedAtlas(holder, layer, sublevel, atlas, cap, height)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    if not ok or type(info) ~= "table" or type(info.width) ~= "number" or info.width <= 2 * cap then return nil end
    local l, r = info.leftTexCoord, info.rightTexCoord
    local t, b = info.topTexCoord, info.bottomTexCoord
    if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return nil end
    local cut = (r - l) * cap / info.width
    local h = height or info.height
    local parts = {}
    for i, span in ipairs({ { l, l + cut }, { l + cut, r - cut }, { r - cut, r } }) do
        local tex = holder:CreateTexture(nil, layer, nil, sublevel)
        tex:SetAtlas(atlas, false)
        tex:SetTexCoord(span[1], span[2], t, b)
        tex:SetHeight(h)
        parts[i] = tex
    end
    parts[1]:SetWidth(cap)
    parts[3]:SetWidth(cap)
    parts[1]:SetPoint("TOPLEFT", holder, "TOPLEFT")
    parts[3]:SetPoint("TOPRIGHT", holder, "TOPRIGHT")
    parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT")
    parts[2]:SetPoint("TOPRIGHT", parts[3], "TOPLEFT")
    return parts
end

-- A progress bar in the look of the profession window's skill bar (T.PROGRESS: width, height, the
-- fill's inset and colour; without the atlas a dark flat ground). bar:SetValue(f) fills it to f (0 to
-- 1; nil or below 0 empty); bar.value keeps it.
function W.ProgressBar(parent, width)
    local P = T.PROGRESS
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width or P.W, P.H)
    if not W.SlicedAtlas(bar, "BACKGROUND", 0, "Professions-skillbar-bg", P.CAP, P.H) then
        W.Flat(bar, P.BG[1], P.BG[2], P.BG[3], P.BG[4], "BACKGROUND")
    end
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetColorTexture(P.COLOR[1], P.COLOR[2], P.COLOR[3], P.COLOR[4])
    bar.fill:SetPoint("LEFT", P.INSET, 0)
    bar.fill:SetHeight(P.H - 2 * P.INSET)
    W.SlicedAtlas(bar, "OVERLAY", 0, "Professions-skillbar-frame", P.CAP, P.H)
    function bar:SetValue(f)
        f = tonumber(f) or 0
        f = math.max(0, math.min(1, f))
        self.value = f
        local w = math.floor((self:GetWidth() - 2 * P.INSET) * f + 0.5)
        self.fill:SetWidth(math.max(1, w))
        self.fill:SetShown(w >= 1)
    end
    bar:SetValue(0)
    return bar
end

-- The empty state of a page: the addon's emblem faint, a title and a line of help, centred in
-- the place the list would fill. e:Set(title, text) fills it (e:SetText and e:GetText: the line of
-- help alone); Show/Hide as any frame. Pages place it with p:Empty (W.Page).
W.EMBLEM = "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia"
-- a white disc with soft edges (the client's round portrait mask), tinted for a round ground
W.DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
function W.EmptyState(parent, width)
    local e = CreateFrame("Frame", nil, parent)
    local E = T.EMPTY
    width = width or E.W
    e.isEmptyState = true
    e:SetSize(width, E.H)
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(E.ICON, E.ICON)
    e.icon:SetPoint("TOP", 0, 0)
    e.icon:SetTexture(W.EMBLEM)
    if e.icon.SetDesaturated then e.icon:SetDesaturated(true) end
    e.icon:SetAlpha(E.ALPHA)
    e.title = W.Text(e, T.FONT.big, width)
    e.title:SetPoint("TOP", e.icon, "BOTTOM", 0, -E.TITLE_GAP)
    e.title:SetJustifyH("CENTER")
    e.title:SetTextColor(0.75, 0.65, 0.45)
    e.text = W.Text(e, T.FONT.dim, width, true)
    e.text:SetPoint("TOP", e.title, "BOTTOM", 0, -E.TEXT_GAP)
    e.text:SetJustifyH("CENTER")
    function e:Set(title, text)
        self.title:SetText(title or "")
        self.text:SetText(text or "")
    end
    function e:SetText(text) self.text:SetText(text or "") end
    function e:GetText() return self.text:GetText() end
    e:Hide()
    return e
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
local TURN = { down = 0, right = math.pi / 2, up = math.pi, left = -math.pi / 2 }
-- Without Forever's dropdown atlases (TBC, Era: D-57) the client's page and scroll arrows, one texture
-- per direction and state (-Up, -Down, -Disabled), never turned.
local CLASSIC_ARROW = {
    left = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage", right = "Interface\\Buttons\\UI-SpellbookIcon-NextPage",
    up = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp", down = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown",
}
local function classicArrows(base)
    return { texture = true, normal = base .. "-Up", hover = base .. "-Up", pressed = base .. "-Down",
             pressedhover = base .. "-Down", open = base .. "-Down", disabled = base .. "-Disabled" }
end

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
    size = size or T.ARROW
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
    if not hasAtlas(b.arrowSet.normal) then
        b.arrowSet = classicArrows(CLASSIC_ARROW[dir or "down"] or CLASSIC_ARROW.down)
        if b.arrow.SetRotation then b.arrow:SetRotation(0) end
        b.glow = b:CreateTexture(nil, "HIGHLIGHT")
        b.glow:SetAllPoints()
        b.glow:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        b.glow:SetBlendMode("ADD")
    end
    -- the shadowed atlas carries its drop shadow below and to the right of the square: the client
    -- draws it at its own size, its right edge one over the box and 3 px down (WowStyle1Dropdown,
    -- a 25 px box). Here the same, scaled to the button; the flat atlases fill the button.
    local fit
    if b.arrowSet == ARROW.shadow and C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, ARROW.shadow.normal)
        if ok and type(info) == "table" and type(info.width) == "number" and info.width > 0 and type(info.height) == "number" then
            local s = size / 25
            fit = { w = info.width * s, h = info.height * s, x = 1 * s, y = -3 * s }
        end
    end
    if fit then
        b.arrow:ClearAllPoints()
        b.arrow:SetSize(fit.w, fit.h)
        b.arrow:SetPoint("RIGHT", b, "RIGHT", fit.x, fit.y)
        b.arrowFit = fit
    end
    function b:UpdateArrow()
        if self.arrowSet.texture then
            self.arrow:SetTexture(arrowState(self))
        else
            self.arrow:SetAtlas(arrowState(self), false)
        end
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

-- On a template button the tooltip is hooked, so the template's own hover look stays.
-- The round class icon on a texture: the client's class circles, the class's part of them; hidden
-- for no class.
function W.SetClassIcon(tex, class)
    local tc = class and (type(_G.CLASS_ICON_TCOORDS) == "table" and _G.CLASS_ICON_TCOORDS[class] or T.CLASS_ICON.COORDS[class])
    if tc then
        tex:SetTexture(T.CLASS_ICON.TEXTURE)
        tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        tex:Show()
    else
        tex:Hide()
    end
end

-- text may be a function(frame) that returns the text when the tooltip shows. A chip of the
-- template and a picker keep their own hover scripts (hooked, never replaced).
function W.Tooltip(frame, title, text)
    local set = (frame.styled or frame.arrow) and frame.HookScript and frame.HookScript or frame.SetScript
    set(frame, "OnEnter", function(self)
        if self.SetOver then self:SetOver(true) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 0.82, 0)
        local tip = text
        if type(tip) == "function" then tip = tip(self) end
        if tip and tip ~= "" then GameTooltip:AddLine(tip, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    set(frame, "OnLeave", function(self)
        if self.SetOver then self:SetOver(false) end
        GameTooltip:Hide()
    end)
end

-- A page's rebuild after changes while it shows (shown()), at most once per gap seconds: the function
-- the page's listeners call.
function W.RefreshWhileShown(shown, gap)
    local due, lastAt = false, nil
    return function()
        if due or not shown() then return end
        due = true
        local now = GetTime and GetTime() or 0
        local wait = lastAt and math.max(0, gap - (now - lastAt)) or 0
        C_Timer.After(wait, function()
            due = false
            if not shown() then return end
            lastAt = GetTime and GetTime() or 0
            ns.Refresh()
        end)
    end
end

-- Item names the client did not have at a page's last fill (missing()): the shown page again once
-- the answers are in, once for a burst of them.
function W.RefreshOnItemNames(missing, shown)
    local due = false
    ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
        if not missing() or due or not shown() then return end
        due = true
        C_Timer.After(0.3, function()
            due = false
            if not missing() or not shown() then return end
            ns.Refresh()
        end)
    end)
end

-- The recorded raid of an id (the pages Raid-Log and Vergaben).
function W.RaidById(id)
    for _, s in ipairs(ns.Sessions()) do
        if s.id == id then return s end
    end
    return nil
end

-- The raids newest first, the running recording in front.
function W.RaidsNewestFirst()
    local src, out, act = ns.Sessions(), {}, ns.Active()
    if act then out[1] = act end
    for i = #src, 1, -1 do
        if src[i] ~= act then out[#out + 1] = src[i] end
    end
    return out
end

local GetItemInfo = C_Item.GetItemInfo
-- An item's name in its quality colour (the saved names' quality, else the client's; white without).
function W.ItemText(id)
    local known = AmisiaDB and AmisiaDB.itemNames and AmisiaDB.itemNames[id]
    local q = known and known.q
    if not q or q == 0 then
        local _, _, iq = GetItemInfo(id)
        q = iq or q
    end
    return ("|c%s%s|r"):format(T.QUALITY_HEX[q or 0] or "ffffffff", ns.ItemName(id))
end

-- An item's link, else its plain "item:<id>".
function W.ItemLink(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. tostring(id))
end

-- Puts a link into the chat the way the client does (ChatFrameUtil.InsertLink).
function W.InsertLink(link)
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        return ChatFrameUtil.InsertLink(link)
    end
end

-- The client's minimal check box (MinimalCheckboxTemplate, as the add-on list's force-load box).
-- A CheckButton turns itself over before OnClick runs; OnClick only reads the state. The field
-- checked mirrors it. The template's textures keep the atlas size (30 x 29), so they are pinned
-- to the 18 x 18 button. Without the template the gold square of before.
function W.Toggle(parent, onChange)
    local b = inherit("CheckButton", nil, parent, "MinimalCheckboxTemplate", function(f) return f.SetChecked and f.GetChecked end)
    if b then
        b:SetSize(T.TOGGLE, T.TOGGLE)
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
    b:SetSize(T.TOGGLE, T.TOGGLE)
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
    f:SetSize(width or T.STEPPER_W, T.FIELD_H)
    f.min, f.max, f.step = 0, 100, 1
    f.minus = W.ArrowButton(f, "left", T.ARROW_SMALL)
    f.minus:SetPoint("LEFT")
    f.plus = W.ArrowButton(f, "right", T.ARROW_SMALL)
    f.plus:SetPoint("RIGHT")
    f.field = CreateFrame("Frame", nil, f)
    f.field:SetHeight(T.FIELD_H)
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
        e:SetTextInsets(T.TEXT_INSET, 4, 0, 0)
    else
        e = CreateFrame("EditBox", nil, parent)
        W.Flat(e, 0, 0, 0, 0.5)
        W.Border(e, 1, 1, 1, 0.2)
        e:SetTextInsets(4, 4, 0, 0)
    end
    e:SetSize(width or T.EDIT_W, T.FIELD_H)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetJustifyH(justify)
    wireCommit(e, onCommit, restore, false)
    return e
end

-- A centred box for a time of day.
function W.TimeBox(parent, width, onCommit)
    return editBox(parent, width or T.EDIT_W, "CENTER", onCommit, false)
end

-- A left-aligned box for a name or a note; Escape restores the text.
function W.LineEdit(parent, width, onCommit)
    return editBox(parent, width or T.LINE_W, "LEFT", onCommit, true)
end

-- The client's search box (SearchBoxTemplate: magnifying glass, clear button, a grey hint while
-- empty; hint defaults to the client's word for search). It commits like W.LineEdit: Enter or
-- leaving the box once, Escape restores. The template's focus and text scripts stay (hooked); its
-- Enter and Escape only drop the focus, so the box's own take their place (a hook would come too
-- late for Escape to restore without a commit). The clear button commits the empty text when the
-- box did not have the focus. Without the template a line edit with the hint.
function W.SearchBox(parent, width, onCommit, hint)
    hint = hint or SEARCH or L["Suchen"]
    local e = inherit("EditBox", nil, parent, "SearchBoxTemplate", function(f) return f.Left and f.Instructions and f.clearButton end)
    if not e then
        e = W.LineEdit(parent, width, onCommit)
        e.Instructions = W.Text(e, "GameFontDisableSmall")
        e.Instructions:SetPoint("LEFT", T.TEXT_INSET, 0)
        e.Instructions:SetPoint("RIGHT", -4, 0)
        e.Instructions:SetText(hint)
        e:HookScript("OnTextChanged", function(self) self.Instructions:SetShown(self:GetText() == "") end)
        return e
    end
    e:SetSize(width or T.LINE_W, T.FIELD_H)
    e:SetAutoFocus(false)
    e.Left:ClearAllPoints()
    e.Left:SetPoint("LEFT", 0, 0)
    -- the cap moved 5 px in from the template's -5: the magnifier moves with it (template: x 1)
    if e.searchIcon then
        e.searchIcon:ClearAllPoints()
        e.searchIcon:SetPoint("LEFT", T.TEXT_INSET, -1)
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

-- A bar of the auction house's category list (AuctionCategoryButtonTemplate as the client's
-- AuctionHouseFilterButton_SetUp dresses it): the dark bar with the thin bronze rim
-- (auctionhouse-nav-button) and the bright gold rim when chosen (-select, added light); no blue glow
-- on hover (the client's -highlight, user 2026-10-17: "dieses blaue weglassen"), the name turns white
-- instead; sub: the indented bar of a sub-category (-secondary). The template itself is not used: it
-- lives in the auction house's addon, loaded only at the auction house. Returns nil when the client
-- lacks one of the two atlases (the caller keeps its own look), else the art:
-- bar:Fit(h) sizes it to a row h high (T.NAVBAR: the art hangs from the bar's top, TEX_H / BAR_H of
-- its height), bar:SetSelected(on) shows the chosen rim; bar.normal, bar.sel, bar.hover (an empty
-- texture, kept so callers may show or hide it).
function W.NavBar(b, sub)
    local N = T.NAVBAR
    local base = sub and "auctionhouse-nav-button-secondary" or "auctionhouse-nav-button"
    for _, name in ipairs({ base, base .. "-select" }) do
        if not hasAtlas(name) then return nil end
    end
    local g = sub and N.SUB or N.TOP
    local bar = {}
    bar.normal = b:CreateTexture(nil, "BACKGROUND")
    bar.normal:SetAtlas(base, false)
    bar.normal:SetPoint("TOPLEFT", g.X, 0)
    bar.normal:SetPoint("TOPRIGHT", g.R, 0)
    bar.hover = b:CreateTexture(nil, "HIGHLIGHT")
    bar.hover:SetPoint("TOPLEFT", g.HL_X, 0)
    bar.hover:SetPoint("BOTTOMRIGHT", 0, 0)
    bar.sel = b:CreateTexture(nil, "ARTWORK")
    bar.sel:SetAtlas(base .. "-select", false)
    bar.sel:SetBlendMode("ADD")
    bar.sel:SetPoint("TOPLEFT", g.HL_X, 0)
    bar.sel:SetPoint("BOTTOMRIGHT", 0, 0)
    bar.sel:Hide()
    function bar:Fit(h)
        self.normal:SetHeight(math.floor((h or N.BAR_H) * N.TEX_H / N.BAR_H + 0.5))
    end
    function bar:SetSelected(on) self.sel:SetShown(on and true or false) end
    bar:Fit(b:GetHeight() ~= 0 and b:GetHeight() or nil)
    return bar
end

-- A thin gold line fading to both ends (the page head, D-69): two halves with the client's gradient,
-- alpha at the middle; without SetGradient (an old client) one even line at half that. A frame 1 high:
-- the caller anchors its left and right.
function W.GoldRule(parent, alpha)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(1)
    local g = GOLD
    local function half(fromA, toA)
        local t = r:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetHeight(1)
        local ok = t.SetGradient and CreateColor and pcall(t.SetGradient, t, "HORIZONTAL",
            CreateColor(g[1], g[2], g[3], fromA), CreateColor(g[1], g[2], g[3], toA))
        if not ok then t:SetColorTexture(g[1], g[2], g[3], alpha / 2) end
        return t
    end
    r.left, r.right = half(0, alpha), half(alpha, 0)
    r.left:SetPoint("LEFT")
    r.left:SetPoint("RIGHT", r, "CENTER")
    r.right:SetPoint("LEFT", r, "CENTER")
    r.right:SetPoint("RIGHT")
    return r
end

-- Gives the portrait's model the creature npc: the model frame is shown FIRST. A creature given to a
-- hidden model frame is lost on the Forever client (seen 2026-11-11: the round portraits stayed black
-- while the header image, which shows its model first, drew the same boss). True when the client took it.
local function loadPortrait(p, npc)
    local m = p.model
    p.loading = true
    if not m:IsShown() then m:Show() end
    local ok = pcall(m.SetCreature, m, npc)
    if ok and m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, T.DBOSS.ZOOM) end
    p.loading = nil
    return ok
end

-- A creature's round portrait size px square on parent (the bosses of the pages Dungeons and Raids,
-- F-154, and the window "Lauf-Zeiten", F-180; tokens T.DBOSS): a black disc, the creature's model over
-- it (the client's skull while it has none), on a frame above the model the gold ring (a model draws
-- over its parent's textures; W.DimPortrait turns the ring grey).
function W.Portrait(parent, size)
    local BV = T.DBOSS
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(size, size)
    p.disc = p:CreateTexture(nil, "BORDER")
    p.disc:SetAllPoints()
    p.disc:SetTexture(W.DISC)
    p.disc:SetVertexColor(0, 0, 0, 1)
    p.skull = p:CreateTexture(nil, "ARTWORK")
    p.skull:SetSize(math.floor(size / 2), math.floor(size / 2))
    p.skull:SetPoint("CENTER")
    p.skull:SetTexture(BV.NO_MODEL)
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, p)
    if ok and m then
        m:SetPoint("TOPLEFT", 2, -2)
        m:SetPoint("BOTTOMRIGHT", -2, 2)
        m:Hide()
        p.model = m
        -- the client forgets a model's creature and camera while the frame is hidden: when the portrait
        -- comes back on screen (the page opens again, the list scrolls) it is given again, and the
        -- portrait camera is set again once the model's data has arrived (a creature never seen loads late)
        m:SetScript("OnShow", function() if p.npc and not p.loading then loadPortrait(p, p.npc) end end)
        m:SetScript("OnModelLoaded", function(self)
            if p.npc and self.SetPortraitZoom then pcall(self.SetPortraitZoom, self, BV.ZOOM) end
        end)
    end
    p.top = CreateFrame("Frame", nil, p)
    p.top:SetAllPoints()
    if p.top.SetFrameLevel and p.GetFrameLevel then p.top:SetFrameLevel(p:GetFrameLevel() + 2) end
    p.ring = p.top:CreateTexture(nil, "OVERLAY")
    p.ring:SetAllPoints()
    p.ring:SetTexture(BV.RING)
    p.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    return p
end

-- The portrait p shows NPC npc (its model, zoomed to head and shoulders), else the skull.
function W.SetPortrait(p, npc)
    local m = p.model
    if npc and m and type(m.SetCreature) == "function" then
        if p.npc ~= npc then
            p.npc = loadPortrait(p, npc) and npc or nil
        end
        if p.npc then
            if not m:IsShown() then m:Show() end
            p.skull:Hide()
            return
        end
    end
    p.npc = nil
    if m then m:Hide() end
    p.skull:Show()
end

-- Steps portrait p back (on: a grey ring, the skull grey, the model at DIM_ALPHA over the black disc) or
-- shows it in full (off: the gold ring). The model is dimmed by the frame's alpha only: a veil over it
-- and the model's own SetDesaturation left the circles black on the Forever client (seen 2026-11-11 in
-- the window "Lauf-Zeiten", while the same portraits drew on the page Dungeons); a client that ignores
-- the alpha just shows the model in full. p.dim keeps the state.
function W.DimPortrait(p, on)
    on = on and true or false
    if p.model and p.model.SetAlpha then pcall(p.model.SetAlpha, p.model, on and T.DBOSS.DIM_ALPHA or 1) end
    if p.skull.SetDesaturated then p.skull:SetDesaturated(on) end
    if p.skull.SetAlpha then p.skull:SetAlpha(on and T.DBOSS.DIM_ALPHA or 1) end
    local c = on and T.DBOSS.RING_DIM or GOLD
    p.ring:SetVertexColor(c[1], c[2], c[3], 1)
    p.dim = on
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
        h:SetHeight(T.HEADER_H)
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
    h:SetHeight(T.HEADER_H)
    W.Flat(h, GOLD[1], GOLD[2], GOLD[3], 0.12)
    h.ButtonText = W.Text(h, T.FONT.title)
    h.ButtonText:SetPoint("LEFT", T.HEADER_TEXT_X, 0)
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
        bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", T.SCROLLBAR_GAP, 0)
        bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", T.SCROLLBAR_GAP, 0)
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

-- A window f at its saved place st ({ point, x, y } on UIParent), else at the place ... (SetPoint's
-- arguments).
function W.PlaceWindow(f, st, ...)
    f:ClearAllPoints()
    if st and type(st.point) == "string" and tonumber(st.x) and tonumber(st.y) then
        f:SetPoint(st.point, UIParent, st.point, tonumber(st.x), tonumber(st.y))
    else
        f:SetPoint(...)
    end
end

-- Keeps the place of the window f (after a drag) in st, in whole pixels.
function W.SaveWindowPlace(f, st)
    if not st then return end
    local point, _, _, x, y = f:GetPoint(1)
    if type(point) == "string" and tonumber(x) and tonumber(y) then
        st.point, st.x, st.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

-- A StaticPopup d over the main window: the dialog strata is below the main window's, so it is lifted
-- (not hidden behind).
function W.LiftDialog(d)
    if d and d.SetFrameStrata then
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        if d.Raise then d:Raise() end
    end
end

-- W.EditArea for a text to copy: typing puts text() back and marks it.
function W.ReadOnlyArea(parent, text)
    local area = W.EditArea(parent)
    area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(text())
            self:HighlightText()
        end
    end)
    return area
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
    -- More rows can be added later (Grow); Fit sets how many show (the main window's height, D-68):
    -- rows past it stay built but hidden.
    function f:Grow(n)
        for i = #self.rows + 1, n do
            local r = CreateFrame("Button", nil, self)
            r:SetHeight(rowHeight - 1)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
            r:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
            r.bg = W.Flat(r, 1, 1, 1, T.ROW_SHADE[(i % 2 == 0) and 2 or 1])
            r.hover = r:CreateTexture(nil, "HIGHLIGHT")
            r.hover:SetAllPoints()
            if hover then
                r.hover:SetAtlas("Professions_Recipe_Hover")
                r.hover:SetAlpha(T.HOVER_ALPHA)
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
    function f:Fit(n)
        n = math.max(1, n)
        if n == self.rowCount then return end
        self:Grow(n)
        self.rowCount = n
        self:SetHeight(n * rowHeight)
        self.offset = math.max(0, math.min(self.offset, #self.items - n))
        if self.Redraw then self:Redraw() end
        syncBar(self)
    end
    if not (opts and opts.bar == false) then
        local bar = inherit("EventFrame", nil, f, "MinimalScrollBar", function(b) return b.SetScrollPercentage and b.RegisterCallback end)
        if bar then
            bar:SetPoint("TOPLEFT", f, "TOPRIGHT", T.SCROLLBAR_GAP, 0)
            bar:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", T.SCROLLBAR_GAP, 0)
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
            local item = i <= self.rowCount and self.items[i + self.offset] or nil
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

-- The lists that fill their page down to its lower end (Scaffold:List with fill, the dungeon page's
-- detail): owner the page part they sit on (its Bottom() and offsetY), top where the list starts on
-- it, at least min rows of rowH. W.FitLists fits them all again after
-- the main window's height changed (T.PAGE_H, D-68); weak, a list gone with its page drops out.
local fillers = setmetatable({}, { __mode = "k" })

local function fitRows(e)
    local o = e.owner
    local room = T.PAGE_H + (o.offsetY or 0) + e.top - o:Bottom()
    return math.max(e.min, math.floor(room / e.rowH))
end

function W.FillTo(list, owner, top, minRows, rowH)
    local e = { owner = owner, top = top or 0, min = minRows or 1, rowH = rowH }
    fillers[list] = e
    list:Fit(fitRows(e))
    return list
end

function W.FitLists()
    for list, e in pairs(fillers) do list:Fit(fitRows(e)) end
end

-- What follows the main window's width (D-71): the pages' bands (placed again, their filling item
-- takes the new room) and the parts that asked with W.FollowWidth(owner, fn) (fn() after the change).
-- Weak keys, but the values reach their keys (no ephemerons in Lua 5.1): pages live as long as the
-- window does, so they stay; each band holds only its latest items.
local widthFollowers = setmetatable({}, { __mode = "k" })
-- The bands of the main window's pages (placed with width nil: the page's width now, T.PAGE_W_NOW)
-- with how to place them again (placeIn below)
local placedBands = setmetatable({}, { __mode = "k" })

function W.FollowWidth(owner, fn)
    widthFollowers[owner] = fn
end

function W.FitWidths()
    for _, again in pairs(placedBands) do again() end
    for _, fn in pairs(widthFollowers) do fn() end
end

-- An overview card: an inset with a gold title, two lines and at most two actions as quiet links (the
-- second right of the first, c:SetAction2; c:SetAction(nil) hides both); a click on the card runs the
-- first (D-67).
function W.Card(parent, width, height)
    local C = T.CARD
    local c = W.Inset(parent)
    c:SetSize(width, height)
    c.title = W.Text(c, T.FONT.title, width - 2 * C.PAD)
    c.title:SetPoint("TOPLEFT", C.PAD, -C.TITLE_Y)
    c.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    c.line1 = W.Text(c, T.FONT.body, width - 2 * C.PAD)
    c.line1:SetPoint("TOPLEFT", C.PAD, -C.LINE1_Y)
    c.line2 = W.Text(c, T.FONT.hint, width - 2 * C.PAD, true)
    c.line2:SetPoint("TOPLEFT", C.PAD, -C.LINE2_Y)
    -- the actions as quiet links (D-67); a click anywhere on the card runs the first one
    c.button = W.Link(c, "")
    c.button:SetPoint("BOTTOMLEFT", C.PAD - T.TAB_PAD, C.BUTTON_Y)
    c.button2 = W.Link(c, "")
    c.button2:SetPoint("LEFT", c.button, "RIGHT", T.TAB_GAP, 0)
    c.button2:Hide()
    c.glow = c:CreateTexture(nil, "ARTWORK")
    c.glow:SetPoint("TOPLEFT", 3, -3)
    c.glow:SetPoint("BOTTOMRIGHT", -3, 3)
    c.glow:SetColorTexture(1, 1, 1, C.HOVER_ALPHA)
    c.glow:Hide()
    if c.EnableMouse then c:EnableMouse(true) end
    c:SetScript("OnEnter", function(self) if self.button:IsShown() then self.glow:Show() end end)
    -- the glow stays while the mouse moves onto the card's own links
    c:SetScript("OnLeave", function(self) if not self:IsMouseOver() then self.glow:Hide() end end)
    for _, link in ipairs({ c.button, c.button2 }) do
        link:HookScript("OnLeave", function() if not c:IsMouseOver() then c.glow:Hide() end end)
    end
    -- a press that leaves the card before the release runs nothing
    c:SetScript("OnMouseUp", function(self, mouse)
        if mouse == "LeftButton" and self.button:IsShown() and self:IsMouseOver() then self.button:Click() end
    end)
    function c:SetAction(label, fn)
        if label then
            self.button:SetText(label)
            self.button:SetScript("OnClick", fn)
            self.button:Show()
        else
            self.button:Hide()
            self.button2:Hide()
            self.glow:Hide()
        end
    end
    function c:SetAction2(label, fn)
        if label then
            self.button2:SetText(label)
            self.button2:SetScript("OnClick", fn)
            self.button2:Show()
        else
            self.button2:Hide()
        end
    end
    return c
end

-- The ground of the client's menus (MenuStyle1Mixin: common-dropdown-bg 10 px wider and 3 px
-- higher than the menu, alpha 0.925) on frame f; the dark field with a gold frame without it.
local function menuGround(f)
    if hasAtlas("common-dropdown-bg") then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        local M = T.MENU
        f.bg:SetAtlas("common-dropdown-bg")
        f.bg:SetPoint("TOPLEFT", -M.GROUND_X, M.GROUND_Y)
        f.bg:SetPoint("BOTTOMRIGHT", M.GROUND_X, -M.GROUND_Y)
        f.bg:SetAlpha(M.ALPHA)
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
-- or Escape closes it too. entries: { text, fn, tip = "...", tipTitle = "..." }; without fn a line
-- only (grey, no click), with head = true a gold head line. opts.width: wider than T.MENU.W.
local menu
function W.Menu(owner, entries, opts)
    local M = T.MENU
    local width = math.max(M.W, opts and tonumber(opts.width) or 0)
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
        menu:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate Menu", function(self, elapsed)
            local anchor = self.owner ~= UIParent and self.owner or nil
            if self:IsMouseOver() or (anchor and anchor:IsMouseOver()) then
                self.away = 0
            else
                self.away = (self.away or 0) + (elapsed or 0)
                if self.away > 2 then self:Hide() end
            end
        end))
    end
    menu.owner = owner
    menu.away = 0
    for i, e in ipairs(entries) do
        local b = menu.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetPoint("TOPLEFT", M.PAD, -M.PAD - (i - 1) * M.ROW_H)
            b.label = W.Text(b, T.FONT.text, M.LABEL_W)
            b.label:SetPoint("LEFT", M.PAD, 0)
            -- the client menu's hover (MenuVariants.CreateHighlight)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetAllPoints()
            b.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b.hl:SetBlendMode("ADD")
            menu.buttons[i] = b
        end
        b:SetSize(width - (M.W - M.ROW_W), M.ROW_H)
        b.label:SetWidth(width - (M.W - M.LABEL_W))
        local fn = e[2]
        b.label:SetText(e.head and (T.LABEL .. e[1] .. "|r") or (fn and e[1]) or (T.GREY .. e[1] .. "|r"))
        b.hl:SetShown(fn ~= nil)
        b:SetScript("OnClick", fn and function()
            menu:Hide()
            fn()
        end or nil)
        -- e.tip: a line of explanation on hover
        b:SetScript("OnEnter", e.tip and function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.tipTitle or e[1])
            GameTooltip:AddLine(e.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end or nil)
        b:SetScript("OnLeave", e.tip and function() GameTooltip:Hide() end or nil)
        b:Show()
    end
    for i = #entries + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:SetSize(width, 2 * M.PAD + #entries * M.ROW_H)
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
local PICK_ROWS, PICK_ROW_H = T.PICKER.ROWS, T.PICKER.ROW_H

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
    local filter = W.SearchBox(picker, nil, nil, SEARCH or L["Suchen"])
    filter:ClearAllPoints()
    local P, pad = T.PICKER, T.MENU.PAD
    filter:SetHeight(T.FIELD_H)
    filter:SetPoint("TOPLEFT", pad, -P.FILTER_Y)
    filter:SetPoint("TOPRIGHT", -pad, -P.FILTER_Y)
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
        r.text = W.Text(r, T.FONT.text)
        r.text:SetPoint("LEFT", pad, 0)
        r.text:SetPoint("RIGHT", -pad, 0)
        r:SetScript("OnClick", function(self) pickerChoose(self.item) end)
    end, function(r, e)
        r.text:SetText(e.text or "")
        local owner = picker.owner
        if e.free then
            r.text:SetTextColor(T.TEXT_FREE[1], T.TEXT_FREE[2], T.TEXT_FREE[3])
        elseif owner and e.value == owner.current then
            r.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            r.text:SetTextColor(1, 1, 1)
        end
    end)
    -- the rows end before the bar (4 px gap, 8 wide, 6 to the edge)
    picker.list:SetPoint("TOPLEFT", pad, -P.LIST_Y)
    picker.list:SetPoint("TOPRIGHT", -(pad + T.SCROLL_ROOM), -P.LIST_Y)

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
    picker:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate Picker", function(self, elapsed)
        local owner = self.owner
        if owner and not owner:IsVisible() then self:Hide() return end
        if self:IsMouseOver() or (owner and owner:IsMouseOver()) or self.filter:HasFocus() then
            self.away = 0
        else
            self.away = (self.away or 0) + (elapsed or 0)
            if self.away > 2 then self:Hide() end
        end
    end))
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
    p:SetSize(width or T.LINE_W, T.FIELD_H)
    -- the field looks like every edit box: the client's input border
    fieldBorder(p)
    local hl = p:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    p.label = W.Text(p, T.FONT.text)
    p.label:SetPoint("LEFT", T.TEXT_INSET, 0)
    p.label:SetPoint("RIGHT", -T.PICKER.ARROW_ROOM, 0)
    -- the client's dropdown button at the right end (22 px, inside the field's right border); a click on it opens like a click on the field, hovering the field lights it too
    p.arrow = W.ArrowButton(p, "down", T.ARROW, function() p:Click() end)
    p.arrow:SetPoint("RIGHT", -1, 0)
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
        panel:SetSize(math.max(T.PICKER.MIN_W, self:GetWidth() or 0), T.PICKER.LIST_Y + T.MENU.PAD + PICK_ROWS * PICK_ROW_H + T.MENU.PAD)
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
    -- opts.flat: the flat window on every client (the main window's hub, D-73), its ground opts.bg and its
    -- edge opts.edge ({ r, g, b, a })
    local F = not opts.flat and inherit("Frame", name, UIParent, "PortraitFrameTemplate",
        function(f) return f.TitleContainer and f.TitleContainer.TitleText and f.CloseButton and f.SetTitle end)
    if F then
        if opts.portrait then
            F:SetPortraitToAsset(opts.portrait)
            -- a black disc under the portrait: an icon with a see-through ground sits on black, not on
            -- the window behind it
            local p = F.PortraitContainer and F.PortraitContainer.portrait or F.portrait
            if p then
                F.portraitBack = (F.PortraitContainer or F):CreateTexture(nil, "OVERLAY", nil, -8)
                F.portraitBack:SetTexture(W.DISC)
                F.portraitBack:SetVertexColor(0, 0, 0, 1)
                F.portraitBack:SetAllPoints(p)
            end
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
        local bg, edge = opts.bg or W.BG, opts.edge or { GOLD[1], GOLD[2], GOLD[3], 0.6 }
        F.ground = W.Flat(F, bg[1], bg[2], bg[3], bg[4])
        F.edges = W.Border(F, edge[1], edge[2], edge[3], edge[4])
        F.TitleContainer = CreateFrame("Frame", nil, F)
        F.TitleContainer:SetHeight(20)
        F.TitleContainer:SetPoint("TOPLEFT", 12, -1)
        F.TitleContainer:SetPoint("TOPRIGHT", -28, -1)
        local title = W.Text(F.TitleContainer, T.FONT.title)
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

---------------------------------------------------------------------------
-- A question before something that cannot be taken back (the calendar write probe): a small window
-- in the look of the others with the text and two red buttons, "okLabel" and "Abbrechen". onOk runs
-- inside the click on the first; Abbrechen, the close button and Escape run onCancel. One at a time:
-- a new question replaces an open one (its onCancel runs).
---------------------------------------------------------------------------
local confirm
function W.Confirm(title, text, okLabel, onOk, onCancel)
    local C = T.CONFIRM
    if not confirm then
        confirm = W.Window("AmisiaConfirmFrame", C.W, C.H, { strata = "FULLSCREEN_DIALOG" })
        confirm:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        confirm.text = W.Text(confirm, T.FONT.body, C.W - 2 * T.WINDOW_PAD, true)
        confirm.text:SetPoint("TOPLEFT", T.WINDOW_PAD, -C.TEXT_Y)
        confirm.text:SetJustifyV("TOP")
        confirm.cancel = W.Button(confirm, L["Abbrechen"], C.BUTTON_W, function() confirm:Hide() end)
        confirm.ok = W.Button(confirm, "", C.BUTTON_W, function()
            local fn = confirm.onOk
            confirm.onOk, confirm.onCancel = nil, nil
            confirm:Hide()
            if fn then fn() end
        end)
        -- closed without "ok" (Abbrechen, the X, Escape, another question): onCancel
        confirm:SetScript("OnHide", function(self)
            local fn = self.onCancel
            self.onOk, self.onCancel = nil, nil
            if fn then fn() end
        end)
    end
    if confirm:IsShown() then confirm:Hide() end
    confirm:SetTitle(title or "")
    confirm.ok:SetText(okLabel or "")
    W.FitChip(confirm.ok, C.BUTTON_W)
    W.FitChip(confirm.cancel, C.BUTTON_W)
    W.Row(confirm, { confirm.ok, confirm.cancel }, T.LAYOUT.ITEM_GAP, T.WINDOW_PAD, C.BOTTOM, { point = "BOTTOMRIGHT", right = true })
    confirm.text:SetText(text or "")
    -- the lines the text wraps to (one more for the word breaks)
    local lines = math.ceil((confirm.text:GetStringWidth() or 0) / (C.W - 2 * T.WINDOW_PAD)) + 1
    local h = lines * C.LINE_H
    confirm.text:SetHeight(h)
    confirm:SetHeight(C.TEXT_Y + h + C.GAP + T.BUTTON_H + C.BOTTOM)
    confirm.onOk, confirm.onCancel = onOk, onCancel
    confirm:Show()
    if confirm.Raise then confirm:Raise() end
    return confirm
end

---------------------------------------------------------------------------
-- A link to copy (D-108): the client opens no browser, so the link stands in a field, marked for
-- Ctrl+C; typing puts it back. Enter and Escape close the window. One at a time.
---------------------------------------------------------------------------
local linkWin
function W.ShowLink(title, url)
    local C = T.LINKWIN
    if not linkWin then
        linkWin = W.Window("AmisiaLinkFrame", C.W, C.H, { strata = "FULLSCREEN_DIALOG" })
        linkWin:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        linkWin.text = W.Text(linkWin, T.FONT.body, C.W - 2 * T.WINDOW_PAD)
        linkWin.text:SetPoint("TOPLEFT", T.WINDOW_PAD, -C.TEXT_Y)
        linkWin.text:SetText(L["Kopiere den Link mit Strg+C:"])
        local box = W.LineEdit(linkWin, C.W - 2 * T.WINDOW_PAD)
        box:SetPoint("TOPLEFT", T.WINDOW_PAD, -C.BOX_Y)
        box:HookScript("OnTextChanged", function(self, user)
            if user and self:GetText() ~= (linkWin.url or "") then
                self:SetText(linkWin.url or "")
                self:HighlightText()
            end
        end)
        box:HookScript("OnEnterPressed", function() linkWin:Hide() end)
        box:HookScript("OnEscapePressed", function() linkWin:Hide() end)
        linkWin.box = box
    end
    linkWin.url = type(url) == "string" and url or ""
    linkWin:SetTitle(title or "")
    linkWin.box:SetText(linkWin.url)
    linkWin:Show()
    if linkWin.Raise then linkWin:Raise() end
    linkWin.box:SetFocus()
    linkWin.box:HighlightText()
    return linkWin
end

---------------------------------------------------------------------------
-- The page scaffold
---------------------------------------------------------------------------
-- W.Page(parent) makes a page (it fills the content inset, 602 x 478) whose shared parts are all
-- placed by ns.Theme.LAYOUT, so every page has its head row, column heads, empty state and footer
-- in the same places. Its methods, each usable once or again on a refresh:
--   p:Bands(spec)            the bands at the top, top to bottom: "row" (controls, ROW_H), "line"
--                            (text, LINE_H; { "line", lines = 2 } for two) or "header" (a section
--                            header, W.SectionHeader, T.HEADER_H). The first band of a page
--                            is its head row. p.bands[i]; returns the content top (p.top, a y offset).
--   p:Place(i, left, right, opts)  controls and texts in band i, each centred on it: left from the
--                            left edge, right up to the right edge (both listed left to right). The
--                            gap: T.CHIP_GAP between two chips, ITEM_GAP else, { frame, gap = n } its
--                            own before it; a text keeps TEXT_X from the page's edge; { fs, fill = true }
--                            takes the room the others leave. opts.shown passes over hidden items.
--   p:Line(i, fs)            a hint line filling band i (a new font string without fs); returns it.
--   p:Columns(cols, opts)    the column heads at the content top (opts.top), as wide as the list
--                            (opts.width, else the page less the scroll bar's room). cols: { { key,
--                            x, w, label, justify = "RIGHT" } }; opts.sort(key) makes them buttons.
--                            Returns the frame and { key = head }. W.Cells(row, cols) makes a list
--                            row's cells at the same places.
--   p:List(rows, rowH, build, fill, opts)  a W.List under the column heads (or at opts.top), as
--                            wide as they are (opts.width).
--   p:Detail(opts)           the inset beside a split list (SPLIT_X, opts.top, opts.height): icon,
--                            title (on d.head, which takes the mouse), sub line (opts.sub), scrolling
--                            body; d:Buttons(list) puts red buttons at its bottom right.
--   p:Empty(width, anchor)   the empty state, centred over anchor (the last list, else the content).
--   p:Footer(spec)           the lines at the bottom, listed top to bottom: { "hint", "data" } makes
--                            p.hint over p.data; { "hint", lines = 2 } a hint of two lines;
--                            { "hint", help = true } an explanation the window's "?" shows instead
--                            (D-67; not on a page of its own width, a side window has no "?").
--   p:BottomRow(left, right) a row of controls right above the footer (at the bottom without one).
--   p:Bottom()               the content's lower end, as a BOTTOM offset (above the bottom row and
--                            the footer, GAP apart).
-- W.Page(parent, { view = true }) is a view inside a page (its views switch with chips): it starts
-- at the page's content top (opts.top) and has the same methods; its bands are not the head row,
-- unless opts.head (a view filling the page, as the officer and raider halves of a page).
-- W.Page(parent, { width = n }) is a page n wide (a side window built with the scaffold, as the big
-- talent window); without it a page is T.PAGE_W wide.
-- Every part carries layoutRole (and the band it sits in, layoutBand); tools/ui_layout.py checks
-- the pages by them (rule "grid").
local LAY = T.LAYOUT
local Scaffold = {}

local function isText(f) return f.CreateTexture == nil and f.GetStringWidth ~= nil end
local function isChip(f) return f.UpdateChip ~= nil end
local function scaffoldEntry(e)
    if type(e) == "table" and type(e[1]) == "table" then return e[1], e end
    return e, nil
end

-- The items of one side of a band, without the hidden ones when only shown ones count.
local function bandItems(list, onlyShown)
    local out = {}
    for _, e in ipairs(list or {}) do
        local f, opt = scaffoldEntry(e)
        if f and not (onlyShown and not f:IsShown()) then
            out[#out + 1] = { f = f, gap = opt and opt.gap, fill = opt and opt.fill }
        end
    end
    return out
end

local function gapOf(a, b)
    if b.gap then return b.gap end
    if a.f.isTab and b.f.isTab then return T.TAB_GAP end
    if isChip(a.f) and isChip(b.f) then return T.CHIP_GAP end
    return LAY.ITEM_GAP
end

local function placeIn(band, width, left, right, opts, role)
    local onlyShown = opts and opts.shown
    local fixed = width
    width = width or T.PAGE_W_NOW or T.PAGE_W
    local R, Lf = bandItems(right, onlyShown), bandItems(left, onlyShown)
    -- the right side, from the edge leftwards
    local at = 0
    for k = #R, 1, -1 do
        local it = R[k]
        if k == #R and isText(it.f) then at = LAY.TEXT_X end
        it.f:ClearAllPoints()
        it.f:SetPoint("RIGHT", band, "RIGHT", -at, 0)
        at = at + (it.f:GetWidth() or 0)
        if k > 1 then at = at + gapOf(R[k - 1], it) end
    end
    local rightUsed = #R > 0 and (at + LAY.ITEM_GAP) or 0
    -- the left side; a filling item takes what the others leave
    local used, fillItem = 0, nil
    for k, it in ipairs(Lf) do
        if k == 1 and isText(it.f) then used = LAY.TEXT_X end
        if k > 1 then used = used + gapOf(Lf[k - 1], it) end
        if it.fill then fillItem = it else used = used + (it.f:GetWidth() or 0) end
    end
    if fillItem then
        local edge = rightUsed > 0 and rightUsed or (isText(fillItem.f) and LAY.TEXT_X or 0)
        fillItem.f:SetWidth(math.max(10, width - used - edge))
    end
    local x = 0
    for k, it in ipairs(Lf) do
        if k == 1 and isText(it.f) then x = LAY.TEXT_X end
        if k > 1 then x = x + gapOf(Lf[k - 1], it) end
        it.f:ClearAllPoints()
        it.f:SetPoint("LEFT", band, "LEFT", x, 0)
        x = x + (it.f:GetWidth() or 0)
    end
    for _, it in ipairs(R) do it.f.layoutRole, it.f.layoutBand = role, band end
    for _, it in ipairs(Lf) do it.f.layoutRole, it.f.layoutBand = role, band end
    -- a text tab that changes its width later (W.Tab:Fit) places this band again, and so does a new
    -- width of the main window's page
    local function again() placeIn(band, fixed, left, right, opts, role) end
    if not fixed then placedBands[band] = again end
    for _, it in ipairs(R) do if it.f.isTab then it.f.replace = again end end
    for _, it in ipairs(Lf) do if it.f.isTab then it.f.replace = again end end
end

function Scaffold:Bands(spec)
    self.bands = self.bands or {}
    local y = 0
    for i, s in ipairs(spec) do
        local kind, lines = s, 1
        if type(s) == "table" then kind, lines = s[1], s.lines or 1 end
        local h = kind == "row" and LAY.ROW_H or kind == "header" and T.HEADER_H or LAY.LINE_H * lines
        local b = self.bands[i] or CreateFrame("Frame", nil, self)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, y)
        b:SetPoint("TOPRIGHT", 0, y)
        b:SetHeight(h)
        b.bandKind, b.bandLines = kind, lines
        b.layoutRole = (i == 1 and not self.isView) and "headband" or "band"
        self.bands[i] = b
        y = y - h - LAY.GAP
    end
    self.top = #spec > 0 and y or 0
    self.listTop = nil
    return self.top
end

function Scaffold:Place(i, left, right, opts)
    local band = assert(self.bands and self.bands[i], "no band " .. tostring(i))
    placeIn(band, self.pageW, left, right, opts, (i == 1 and not self.isView) and "head" or "band")
end

function Scaffold:Line(i, fs)
    local band = assert(self.bands and self.bands[i], "no band " .. tostring(i))
    fs = fs or W.Text(self, T.FONT.hint)
    fs:ClearAllPoints()
    local lines = band.bandLines or 1
    if lines > 1 then
        fs:SetWordWrap(true)
        fs:SetMaxLines(lines)
        fs:SetJustifyV("TOP")
        fs:SetPoint("TOPLEFT", band, "TOPLEFT", LAY.TEXT_X, 0)
        fs:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -LAY.TEXT_X, 0)
    else
        fs:SetPoint("LEFT", band, "LEFT", LAY.TEXT_X, 0)
        fs:SetPoint("RIGHT", band, "RIGHT", -LAY.TEXT_X, 0)
    end
    fs:SetWidth((self.pageW or T.PAGE_W) - 2 * LAY.TEXT_X)
    fs.layoutRole, fs.layoutBand = "line", band
    return fs
end

-- A list row's cells (font strings, T.FONT.text unless a column says font) at the columns' places;
-- a column with cell = false gets none. row[key] is the cell.
function W.Cells(row, cols)
    for _, c in ipairs(cols) do
        if c.cell ~= false then
            local fs = W.Text(row, c.font or T.FONT.text, c.cw or c[3])
            fs:SetPoint("LEFT", c.cx or c[2], 0)
            if c.justify then fs:SetJustifyH(c.justify) end
            row[c[1]] = fs
        end
    end
    return row
end

-- The sortable heads of Scaffold:Columns (opts.sort): the sorted column's head white, the others gold.
function W.MarkSortHead(heads, sortKey)
    for key, b in pairs(heads) do
        local on = key == sortKey
        if b.label then b.label:SetTextColor(on and 1 or T.GOLD[1], on and 1 or T.GOLD[2], on and 1 or T.GOLD[3]) end
    end
end

function Scaffold:Columns(cols, opts)
    opts = opts or {}
    local top = opts.top or self.top or 0
    local h = CreateFrame("Frame", nil, self)
    h:SetHeight(LAY.COLHEAD_H)
    h:SetPoint("TOPLEFT", opts.x or 0, top)
    if opts.width then h:SetWidth(opts.width) else h:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, top) end
    h.layoutRole = "colhead"
    local cells = {}
    for _, c in ipairs(cols) do
        local key, x, w = c[1], c[2], c[3]
        local fs
        if opts.sort then
            local b = CreateFrame("Button", nil, h)
            b:SetSize(w, LAY.COLHEAD_H)
            b:SetPoint("LEFT", x, 0)
            b.label = W.Text(b, T.FONT.head, w)
            b.label:SetPoint("LEFT")
            b:SetScript("OnClick", function() opts.sort(key) end)
            fs = b.label
            cells[key] = b
        else
            fs = W.Text(h, T.FONT.head, w)
            fs:SetPoint("LEFT", x, 0)
            cells[key] = fs
        end
        if c.justify then fs:SetJustifyH(c.justify) end
        fs:SetText(c[4] or "")
    end
    h.cells = cells
    self.listTop = top - LAY.COLHEAD_H
    return h, cells
end

function Scaffold:List(rows, rowH, build, fill, opts)
    opts = opts or {}
    local top = opts.top or self.listTop or self.top or 0
    -- opts.fill: as many rows as fit down to the content's lower end (p:Bottom()), at least rows; the
    -- room the footer's explanations left when they moved behind the "i" (D-67) goes to the list, and
    -- it follows the main window's height (W.FillTo, D-68)
    local fillTo = opts.fill and not self.pageW
    local list = W.List(self, rows, rowH, build, fill, opts)
    if fillTo then W.FillTo(list, self, top, rows, rowH) end
    list:SetPoint("TOPLEFT", opts.x or 0, top)
    if opts.width then list:SetWidth(opts.width) else list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, top) end
    list.layoutRole = "list"
    self.lastList = list
    return list
end

function Scaffold:Empty(width, anchor)
    local e = W.EmptyState(self, width)
    anchor = anchor or self.lastList
    if anchor then
        e:SetPoint("TOP", anchor, "TOP", 0, -LAY.EMPTY_Y)
    else
        e:SetPoint("TOP", self, "TOP", 0, (self.top or 0) - LAY.EMPTY_Y)
    end
    e.layoutRole = "empty"
    return e
end

-- The scaffolds with help lines, in the order they were built (W.HelpLines walks them).
local helpOwners, helpOrder = setmetatable({}, { __mode = "k" }), {}

-- The texts of the help lines of the visible scaffolds under root, in build order (the window's "?").
function W.HelpLines(root)
    local out = {}
    for _, p in ipairs(helpOrder) do
        if p:IsVisible() then
            local up, inside = p, false
            while up do
                if up == root then inside = true break end
                up = up:GetParent()
            end
            if inside then
                for _, fs in ipairs(p.helpLines) do
                    local t = not fs.helpOff and fs:GetText()
                    if t and t ~= "" then out[#out + 1] = t end
                end
            end
        end
    end
    return out
end

function Scaffold:Footer(spec)
    local foot = self.footFrame or CreateFrame("Frame", nil, self)
    foot:ClearAllPoints()
    foot.layoutRole = "footer"
    local y = 0
    for k = #spec, 1, -1 do
        local s = spec[k]
        local name, lines, help = s, 1, false
        if type(s) == "table" then name, lines, help = s[1], s.lines or 1, s.help and not self.pageW end
        local h = LAY.LINE_H * lines
        local fs = self[name] or W.Text(foot, T.FONT.hint, nil, lines > 1)
        if help then
            -- an explanation (D-67): not drawn; the window's "?" shows it (W.HelpLines). The page
            -- keeps writing it as before.
            fs:ClearAllPoints()
            fs:Hide()
            if not fs.isHelp then
                -- a page that shows or hides the line (a view without it) now switches it in the "i"
                -- only: the line itself stays hidden and unanchored
                fs.isHelp = true
                fs.Show = function(line) line.helpOff = nil end
                fs.Hide = function(line) line.helpOff = true end
                fs.SetShown = function(line, on) line.helpOff = not on or nil end
            end
            self.helpLines = self.helpLines or {}
            local known = false
            for _, f in ipairs(self.helpLines) do known = known or f == fs end
            if not known then self.helpLines[#self.helpLines + 1] = fs end
            if not helpOwners[self] then
                helpOwners[self] = true
                helpOrder[#helpOrder + 1] = self
            end
            self[name] = fs
            h = nil
        end
        if h then
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOMLEFT", foot, "BOTTOMLEFT", LAY.TEXT_X, y)
            fs:SetPoint("TOPRIGHT", foot, "BOTTOMRIGHT", -LAY.TEXT_X, y + h)
            if lines > 1 then fs:SetMaxLines(lines) end
            -- the width the anchors give, also set (a refresh may measure the text against it)
            fs:SetWidth((self.pageW or T.PAGE_W) - 2 * LAY.TEXT_X)
            fs.layoutRole = "foot"
            self[name] = fs
            y = y + h
        end
    end
    foot:SetPoint("BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", 0, 0)
    foot:SetHeight(y)
    self.footFrame, self.footH = foot, y
    if self.bottomRow then self:BottomRow() end
    return foot
end

function Scaffold:BottomRow(left, right, opts)
    local b = self.bottomRow or CreateFrame("Frame", nil, self)
    b:ClearAllPoints()
    local y = (self.footH or 0) > 0 and (self.footH + LAY.GAP) or 0
    b:SetPoint("BOTTOMLEFT", 0, y)
    b:SetPoint("BOTTOMRIGHT", 0, y)
    b:SetHeight(LAY.ROW_H)
    b.layoutRole = "band"
    self.bottomRow = b
    if left or right then self.bottomItems = { left, right, opts } end
    local items = self.bottomItems
    if items then placeIn(b, self.pageW, items[1], items[2], items[3], "band") end
    return b
end

function Scaffold:Bottom()
    local y = (self.footH or 0) > 0 and (self.footH + LAY.GAP) or 0
    if self.bottomRow then y = y + LAY.ROW_H + LAY.GAP end
    return y
end

function Scaffold:Detail(opts)
    local D = LAY.DETAIL
    opts = opts or {}
    local d = W.Inset(self)
    local top = opts.top or self.top or 0
    d:SetPoint("TOPLEFT", LAY.SPLIT_X, top)
    d:SetPoint("TOPRIGHT", 0, top)
    d:SetHeight(opts.height or 200)
    -- opts.follow: a list beside it whose height it keeps, also when the list fits the main window's
    -- height again (W.FitLists, D-68)
    if opts.follow then
        local list, fit = opts.follow, opts.follow.Fit
        d:SetHeight(list:GetHeight())
        list.Fit = function(l, n)
            fit(l, n)
            d:SetHeight(l:GetHeight())
        end
    end
    d.layoutRole = "detail"
    local inner = T.PAGE_W - LAY.SPLIT_X - D.TITLE_X - D.PAD
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(D.ICON, D.ICON)
    d.icon:SetPoint("TOPLEFT", D.PAD, -D.PAD)
    d.head = CreateFrame("Button", nil, d)
    d.head:SetPoint("TOPLEFT", D.TITLE_X, -D.PAD)
    d.head:SetPoint("TOPRIGHT", -D.PAD, -D.PAD)
    d.head:SetHeight(D.TITLE_H)
    d.title = W.Text(d.head, T.FONT.title, inner)
    d.title:SetPoint("LEFT", 0, 0)
    if opts.sub then
        d.sub = W.Text(d, T.FONT.text, inner)
        d.sub:SetPoint("TOPLEFT", D.TITLE_X, -D.SUB_Y)
    end
    d.body = W.ScrollText(d)
    d.body:SetPoint("TOPLEFT", D.PAD, -D.BODY_Y)
    d.body:SetPoint("BOTTOMRIGHT", -(D.PAD + T.SCROLL_ROOM - T.SCROLLBAR_GAP), D.BUTTONS)
    d.Buttons = function(_, list)
        W.Row(d, list, LAY.ITEM_GAP, D.PAD, D.PAD, { right = true, point = "BOTTOMRIGHT" })
    end
    return d
end

function W.Page(parent, opts)
    local view = opts and opts.view
    local p = CreateFrame("Frame", nil, parent)
    for k, fn in pairs(Scaffold) do p[k] = fn end
    -- opts.width: a page of another width than the main window's (a side window drawn with the scaffold)
    p.pageW = opts and opts.width
    if view then
        -- opts.head: a view that fills the page (one per mode) and has the head row itself
        p.isView = not opts.head
        p.offsetY = (parent.offsetY or 0) + (opts.top or parent.top or 0)
        p:SetPoint("TOPLEFT", 0, opts.top or parent.top or 0)
        p:SetPoint("BOTTOMRIGHT", 0, 0)
        p.layoutRole = "view"
    else
        p.layoutRole = "page"
    end
    return p
end
end)
