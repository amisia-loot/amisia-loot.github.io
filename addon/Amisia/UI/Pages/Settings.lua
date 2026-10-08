-- Settings: built from the registered sections; changed rows carry a dot and a reset button.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local GOLD = W.GOLD
local ROW_H, LABEL_W = 26, 300

local rows = {}   -- path -> row
local scroll, child, page
local touched     -- the path of the row the player changed last: it keeps its place on screen
local placeAgain  -- while set: put that row back in place when the client takes the new scroll range

function ns.SettingsRows() return rows end
function ns.SettingsPageFrame() return page end

local function valueText(it, v)
    if it.type == "time" then return ns.FormatTime(v) end
    if it.type == "toggle" then return v and L["an"] or L["aus"] end
    if it.type == "text" then return (v == nil or v == "") and L["leer"] or tostring(v) end
    if it.type == "choice" then
        for _, c in ipairs(it.values) do if c[1] == v then return c[2] end end
    end
    return tostring(v)
end

local function makeRow(it)
    local r = CreateFrame("Frame", nil, child)
    r:SetSize(560, ROW_H)
    r:EnableMouse(true)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 0, 0)
    r.dot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    r.label = W.Text(r, T.FONT.text, LABEL_W)
    r.label:SetPoint("LEFT", 12, 0)
    r.label:SetText(it.label or it.key)
    local path = it.key
    if it.type == "toggle" then
        r.control = W.Toggle(r, function(v) touched = path; ns.Set(path, v) end)
    elseif it.type == "slider" then
        r.control = W.Stepper(r, 130, function(v) touched = path; ns.Set(path, v) end)
        r.control:Configure(it.min, it.max, it.step)
    elseif it.type == "time" then
        r.control = W.TimeBox(r, 70, function(text)
            touched = path
            local ok, why = ns.Set(path, text)
            if not ok then ns.msg((it.allowOff and L["%s Beispiel: 20:00 oder aus"] or L["%s Beispiel: 20:00"]):format(why)) end
            ns.Refresh()
        end)
    elseif it.type == "text" then
        r.control = W.LineEdit(r, 150, function(text)
            touched = path
            local ok, why = ns.Set(path, text)
            if not ok then ns.msg(why) end
            ns.Refresh()
        end)
    elseif it.type == "choice" then
        r.control = W.Choice(r, 150, function(v) touched = path; ns.Set(path, v) end)
        r.control:SetValues(it.values)
    elseif it.type == "button" then
        r.control = W.Button(r, it.label, 230, function() touched = path; it.run() end)
        r.label:SetText("")
    end
    if r.control then r.control:SetPoint("LEFT", LABEL_W + 20, 0) end
    if it.type ~= "button" and it.type ~= "desc" then
        -- the client's reset button (a chip's atlas carries a dropdown arrow, at 20 px it read "x >")
        r.reset = W.ResetButton(r, T.RESET, function() touched = path; ns.Reset(path) end)
        r.reset:SetPoint("LEFT", LABEL_W + 20 + 160, 0)
        W.Tooltip(r.reset, L["Zurücksetzen"], L["Auf den Standard zurück."])
    end
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(it.label or it.key, 1, 0.82, 0)
        if it.tip then GameTooltip:AddLine(it.tip, 0.85, 0.85, 0.85, true) end
        if it.default ~= nil then GameTooltip:AddLine(L["Standard: %s"]:format(valueText(it, it.default)), 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.it = it
    rows[path] = r
    return r
end

local function fillRow(r)
    local it, v = r.it, ns.Get(r.it.key)
    if it.type == "toggle" then r.control:SetChecked(v)
    elseif it.type == "slider" then r.control:SetValue(v)
    elseif it.type == "time" then if not r.control:HasFocus() then r.control:SetText(ns.FormatTime(v)) end
    elseif it.type == "text" then if not r.control:HasFocus() then r.control:SetText(v ~= nil and tostring(v) or "") end
    elseif it.type == "choice" then r.control:SetValue(v) end
    local changed = it.type ~= "button" and not ns.IsDefault(it.key)
    if changed then r.dot:Show() else r.dot:Hide() end
    if r.reset then if changed then r.reset:Show() else r.reset:Hide() end end
end

local headers = {}

-- The offset of a placed row or header from the top of the list (W.Column anchors TOPLEFT).
local function topOf(f)
    for i = 1, f.GetNumPoints and f:GetNumPoints() or 1 do
        local point, _, _, _, y = f:GetPoint(i)
        if point == "TOPLEFT" then return y and -y end
    end
end

-- A setting can show or hide whole sections above it (the view, the expert mode): before the new
-- layout, remember the row the player just changed (else the topmost row in view) and how far below
-- the top of the view it sits; the returned function scrolls so that it sits there again.
local function holdPlace()
    local top, h = scroll:GetVerticalScroll() or 0, scroll:GetHeight() or 0
    local anchor = touched and rows[touched]
    local at = anchor and anchor:IsShown() and topOf(anchor)
    if not (at and at >= top and at < top + h) then
        anchor, at = nil, nil
        local function consider(f)
            local y = f:IsShown() and topOf(f)
            if y and y >= top and (not at or y < at) then anchor, at = f, y end
        end
        for _, f in pairs(rows) do consider(f) end
        for _, f in pairs(headers) do consider(f) end
    end
    if not anchor then return function() end end
    local screen = at - top
    local function apply()
        local now = anchor:IsShown() and topOf(anchor)
        if not now then return end
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        local max = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
        scroll:SetVerticalScroll(math.max(0, math.min(max, now - screen)))
    end
    return function()
        apply()
        -- the client takes the new scroll range later (and its scroll bar then keeps the old share
        -- of the range, which moved the row when sections came in): place again on the range change
        -- and on the next frame, for a moment
        placeAgain = apply
        if C_Timer and C_Timer.After then
            C_Timer.After(0, apply)
            C_Timer.After(0.3, function() if placeAgain == apply then placeAgain = nil end end)
        end
    end
end

ns.RegisterPanel{ key = "settings", label = L["Einstellungen"], icon = "Interface\\Icons\\Trade_Engineering", order = 900, group = "amisia",
    create = function(parent)
        local f = W.Page(parent)
        -- a plain scroll frame with the client's thin bar 4 px to its right (inside the page)
        scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT")
        scroll:SetPoint("BOTTOMRIGHT", -16, 0)
        child = CreateFrame("Frame", nil, scroll)
        child:SetSize(560, 10)
        scroll:SetScrollChild(child)
        f.scroll, f.child = scroll, child
        f.bar = W.Scroll(scroll, f)
        -- after the scroll bar's own handler (HookScript runs after it)
        scroll:HookScript("OnScrollRangeChanged", function() if placeAgain then placeAgain() end end)
        f.headers = headers
        page = f
        return f
    end,
    refresh = function()
        -- hide only what this pass leaves out: hiding a row would take the focus from its edit box
        local restore = holdPlace()
        local column, placed = {}, {}
        for _, section in ipairs(ns.schema) do
            if ns.Visible(section) then
                local shown = {}
                for _, it in ipairs(section.items) do
                    if it.key and ns.Visible(it) then shown[#shown + 1] = it end
                end
                if #shown > 0 then
                    local h = headers[section.key]
                    if not h then
                        -- the client's list header as the section's bar, without collapsing
                        h = W.SectionHeader(child, section.label, false)
                        headers[section.key] = h
                    end
                    h:Show()
                    placed[h] = true
                    -- a section after the first starts a section gap lower
                    column[#column + 1] = { h, gap = #column > 0 and T.SECTION_GAP or 0, right = 0 }
                    for _, it in ipairs(shown) do
                        local r = rows[it.key] or makeRow(it)
                        fillRow(r)
                        r:Show()
                        placed[r] = true
                        column[#column + 1] = r
                    end
                end
            end
        end
        for _, h in pairs(headers) do if not placed[h] then h:Hide() end end
        for _, r in pairs(rows) do if not placed[r] then r:Hide() end end
        -- the headers span the width, the rows keep theirs; the last section's gap ends the list
        local bottom = W.Column(child, column, 0, 0, 0)
        child:SetHeight(math.max(10, -bottom + (#column > 0 and T.SECTION_GAP or 0)))
        restore()
    end }
