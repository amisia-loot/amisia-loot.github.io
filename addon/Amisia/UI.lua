-- Amisia window: session list, selection and the export box.
local ADDON, ns = ...

local ROWS = 8
local ROW_H = 21

local W, list, statusText, pauseBtn, exportBox, exportScroll, pageText
local rows = {}
local selected = {}   -- session id -> true
local offset = 0      -- rows scrolled away from the newest session
local exportText = ""

local GOLD = { 0.89, 0.72, 0.34 }

local function text(parent, template, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if size then fs:SetWidth(size) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function button(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 22)
    b:SetText(label)
    return b
end

local function border(frame, r, g, b, a)
    local function edge(p1, p2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

-- sessions newest first
local function ordered()
    local src, out = ns.Sessions(), {}
    for i = #src, 1, -1 do out[#out + 1] = src[i] end
    return out
end

local function anySelected()
    for _ in pairs(selected) do return true end
    return false
end

local function setExport(txt)
    exportText = txt or ""
    exportBox:SetText(exportText)
    exportBox:SetCursorPosition(0)
    exportScroll:SetVerticalScroll(0)
end

function ns.Refresh()
    if not W or not W:IsShown() then return end

    local act = ns.Active()
    if act then
        local c = ns.MatCounts(act)
        statusText:SetText(("|cff4fbf7aAufnahme läuft:|r %s · %d Raider · Mal %d · Herz %d · Edelsteine %d"):format(
            act.zone, ns.MemberCount(act), c[32897] or 0, c[32428] or 0, ns.GemCount(c)))
    elseif ns.IsEnabled() then
        statusText:SetText("|cff8f86a3Keine Aufnahme.|r Sie startet von selbst in einer Raidinstanz mit Raidgruppe.")
    else
        statusText:SetText("|cffe0a344Aufnahme pausiert.|r")
    end
    pauseBtn:SetText(ns.IsEnabled() and "Pausieren" or "Fortsetzen")

    local all = ordered()
    local maxOffset = math.max(0, #all - ROWS)
    if offset > maxOffset then offset = maxOffset end

    -- drop selections of sessions that no longer exist
    local exists = {}
    for _, s in ipairs(all) do exists[s.id] = true end
    for id in pairs(selected) do
        if not exists[id] then selected[id] = nil end
    end

    for i = 1, ROWS do
        local r = rows[i]
        local s = all[i + offset]
        if s then
            local c = ns.MatCounts(s)
            r.sessionId = s.id
            r.session = s
            r.date:SetText(s.date)
            r.zone:SetText((s == act and "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:12:12:0:0|t " or "") .. (s.zone or "?"))
            r.raiders:SetText(ns.MemberCount(s))
            r.mark:SetText(c[32897] or 0)
            r.heart:SetText(c[32428] or 0)
            r.gems:SetText(ns.GemCount(c))
            if selected[s.id] then r.sel:Show() else r.sel:Hide() end
            r:Show()
        else
            r.sessionId = nil
            r.session = nil
            r.sel:Hide()
            r:Hide()
        end
    end

    if #all == 0 then
        pageText:SetText("Noch keine Raids aufgezeichnet.")
    else
        pageText:SetText(("%d-%d von %d"):format(offset + 1, math.min(offset + ROWS, #all), #all))
    end
end

local function build()
    W = CreateFrame("Frame", "AmisiaFrame", UIParent)
    W:SetSize(600, 500)
    W:SetPoint("CENTER")
    W:SetFrameStrata("DIALOG")
    W:SetClampedToScreen(true)
    W:SetMovable(true)
    W:EnableMouse(true)
    W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", function(self) self:StartMoving() end)
    W:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    W:SetScript("OnShow", function() ns.Refresh() end)
    W:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaFrame") end

    local bg = W:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.04, 0.08, 0.96)
    border(W, GOLD[1], GOLD[2], GOLD[3], 0.6)

    local logo = W:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 12, -7)
    logo:SetTexture("Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia")

    local title = text(W, "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("Amisia")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local close = CreateFrame("Button", nil, W, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    pauseBtn = button(W, "Pausieren", 100)
    pauseBtn:SetPoint("TOPRIGHT", -34, -12)
    pauseBtn:SetScript("OnClick", function() ns.SetEnabled(not ns.IsEnabled()) end)

    statusText = text(W, "GameFontHighlightSmall", 560)
    statusText:SetPoint("TOPLEFT", 16, -40)

    -- list header
    local head = CreateFrame("Frame", nil, W)
    head:SetSize(568, 18)
    head:SetPoint("TOPLEFT", 16, -66)
    local function col(parent, x, w, label, template)
        local fs = text(parent, template or "GameFontNormalSmall", w)
        fs:SetPoint("LEFT", x, 0)
        if label then fs:SetText(label) end
        return fs
    end
    col(head, 6, 86, "Datum")
    col(head, 94, 196, "Raid")
    col(head, 294, 52, "Raider")
    col(head, 350, 56, "Mal")
    col(head, 410, 56, "Herz")
    col(head, 470, 92, "Edelsteine")

    list = CreateFrame("Frame", nil, W)
    list:SetSize(568, ROWS * ROW_H)
    list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        ns.Refresh()
    end)

    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetSize(568, ROW_H - 1)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        local rb = r:CreateTexture(nil, "BACKGROUND")
        rb:SetAllPoints()
        rb:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        r.sel = r:CreateTexture(nil, "BORDER")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
        r.sel:Hide()
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        r.date = col(r, 6, 86, nil, "GameFontHighlightSmall")
        r.zone = col(r, 94, 196, nil, "GameFontHighlightSmall")
        r.raiders = col(r, 294, 52, nil, "GameFontHighlightSmall")
        r.mark = col(r, 350, 56, nil, "GameFontHighlightSmall")
        r.heart = col(r, 410, 56, nil, "GameFontHighlightSmall")
        r.gems = col(r, 470, 92, nil, "GameFontHighlightSmall")
        r:SetScript("OnEnter", function(self)
            local s = self.session
            if not s then return end
            local c = ns.MatCounts(s)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(s.zone or "?", 1, 0.82, 0)
            GameTooltip:AddLine(s.date, 0.7, 0.7, 0.7)
            local any = false
            for _, id in ipairs(ns.MAT_ORDER) do
                if (c[id] or 0) > 0 then
                    any = true
                    GameTooltip:AddDoubleLine(ns.ItemName(id), tostring(c[id]), 1, 1, 1, 1, 1, 1)
                end
            end
            if not any then GameTooltip:AddLine("Keine Materialien gelootet.", 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self)
            local id = self.sessionId
            if not id then return end
            selected[id] = (not selected[id]) or nil
            ns.Refresh()
        end)
        rows[i] = r
    end

    pageText = text(W, "GameFontDisableSmall", 200)
    pageText:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 6, -6)

    local selAll = button(W, "Alle wählen", 110)
    selAll:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", -126, -2)
    selAll:SetScript("OnClick", function()
        local all, allOn = ordered(), true
        for _, s in ipairs(all) do if not selected[s.id] then allOn = false end end
        wipe(selected)
        if not allOn then
            for _, s in ipairs(all) do selected[s.id] = true end
        end
        ns.Refresh()
    end)

    local del = button(W, "Löschen", 110)
    del:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -2)
    del:SetScript("OnClick", function()
        if not anySelected() then
            ns.msg("Zuerst Raids in der Liste anklicken.")
            return
        end
        StaticPopup_Show("AMISIA_DELETE")
    end)

    -- export
    local exportLabel = text(W, "GameFontNormal", 400)
    exportLabel:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -36)
    exportLabel:SetText("Export für die Amisia-Loot-Seite")

    local makeBtn = button(W, "Export erstellen", 140)
    makeBtn:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -32)
    makeBtn:SetScript("OnClick", function() ns.ShowExport(false) end)

    local boxBg = CreateFrame("Frame", nil, W)
    boxBg:SetPoint("TOPLEFT", exportLabel, "BOTTOMLEFT", 0, -8)
    boxBg:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -16, 42)
    local bb = boxBg:CreateTexture(nil, "BACKGROUND")
    bb:SetAllPoints()
    bb:SetColorTexture(0, 0, 0, 0.45)
    border(boxBg, 1, 1, 1, 0.12)

    exportScroll = CreateFrame("ScrollFrame", "AmisiaExportScroll", boxBg, "UIPanelScrollFrameTemplate")
    exportScroll:SetPoint("TOPLEFT", 6, -6)
    exportScroll:SetPoint("BOTTOMRIGHT", -28, 6)

    exportBox = CreateFrame("EditBox", nil, exportScroll)
    exportBox:SetMultiLine(true)
    exportBox:SetMaxLetters(0)
    exportBox:SetAutoFocus(false)
    exportBox:SetFontObject(ChatFontNormal)
    exportBox:SetWidth(520)
    exportBox:SetHeight(200)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    exportBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(exportText)
            self:HighlightText()
        end
    end)
    exportScroll:SetScrollChild(exportBox)
    boxBg:EnableMouse(true)
    boxBg:SetScript("OnMouseDown", function() exportBox:SetFocus() end)

    local hint = text(W, "GameFontDisableSmall", 568)
    hint:SetPoint("BOTTOMLEFT", 16, 16)
    hint:SetText("Strg+A, dann Strg+C. Auf der Seite im Import-Tab einfügen, gerne zusammen mit dem Gargul-Export.")
end

-- Fills the export box. Uses the selected sessions, or every session when none is selected.
function ns.ShowExport(latestOnly)
    if not W then build() end
    W:Show()
    local src, list = ns.Sessions(), {}
    if latestOnly then
        if src[#src] then list[1] = src[#src] end
    elseif anySelected() then
        for _, s in ipairs(src) do if selected[s.id] then list[#list + 1] = s end end
    else
        for _, s in ipairs(src) do list[#list + 1] = s end
    end
    if #list == 0 then
        setExport("")
        ns.msg("Noch keine Raids zum Exportieren.")
        return
    end
    setExport(ns.ExportText(list))
    exportBox:SetFocus()
    exportBox:HighlightText()
end

function ns.Toggle(exportLatest)
    if not W then build() end
    if exportLatest then
        ns.ShowExport(true)
    elseif W:IsShown() then
        W:Hide()
    else
        W:Show()
    end
end

StaticPopupDialogs["AMISIA_DELETE"] = {
    text = "Die markierten Raids aus Amisia löschen?",
    button1 = "Löschen",
    button2 = "Abbrechen",
    OnAccept = function()
        local n = ns.DeleteSessions(selected)
        wipe(selected)
        ns.Refresh()
        ns.msg(("%d Raid(s) gelöscht."):format(n))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
