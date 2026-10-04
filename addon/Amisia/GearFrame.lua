-- Amisia gear window (/amisia gear): class, spec and source switches, an overview with the best item
-- per slot for every level range, and a list of one range with names, sources and alternatives.
local ADDON, ns = ...

local Gear = ns.Gear
local GOLD = { 0.89, 0.72, 0.34 }
local W_WIDTH, W_HEIGHT = 820, 640
local ROW_H = 26
local SLOT_W = 92
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local FILTERS = {
    { key = "Q", label = "Quests" }, { key = "D", label = "Dungeons" }, { key = "C", label = "Berufe" },
    { key = "V", label = "Händler" }, { key = "W", label = "Weltdrops" }, { key = "A", label = "AH" },
    { key = "P", label = "PvP" }, { key = "B", label = "Ingenieur" },
}
local CLASS_ICON = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local F, overview, listView, altPanel, statusText, titleText
local classButtons, specButtons, filterButtons = {}, {}, {}
local kindButton, factionButton, viewButtons, colLabel = nil, nil, {}, nil
local cells, colHeads, listRows, altRows = {}, {}, {}, {}
local results = {}          -- column index -> Gear.Best result
local selSlot = "HEAD"
local refreshPending = false

local function settings()
    AmisiaDB.settings.gear = AmisiaDB.settings.gear or {}
    local g = AmisiaDB.settings.gear
    local _, myClass = UnitClass("player")
    g.class = g.class or myClass or "WARRIOR"
    g.view = g.view or "overview"
    if g.sources == nil then g.sources = { Q = true, D = true, C = true, V = true, W = true, A = true, P = false, B = false } end
    if g.faction == nil then
        local fac = UnitFactionGroup and UnitFactionGroup("player")
        g.faction = fac == "Horde" and "H" or "A"
    end
    if not g.col then g.col = Gear.ColumnOf(UnitLevel and UnitLevel("player") or 1) end
    g.specs = g.specs or {}
    return g
end

function Gear.ColumnOf(level)
    for i, c in ipairs(Gear.COLUMNS) do
        if level <= c[2] then return i end
    end
    return #Gear.COLUMNS
end

local function opts(col)
    local g = settings()
    local spec = g.specs[g.class] or (Gear.Specs(g.class)[1] or {}).key
    return {
        class = g.class, spec = spec, kind = ns.Get("gear.kind"), faction = g.faction ~= "both" and g.faction or nil,
        sources = g.sources, level = Gear.COLUMNS[col][2],
    }
end

local function classColor(token)
    local c = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
    if c and c.r then return c.r, c.g, c.b end
    c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function itemInfo(id)
    local getInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local name, link, q, _, _, _, _, _, _, icon = getInfo(id)
    if not icon then
        local getInstant = C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
        if getInstant then icon = select(5, getInstant(id)) end
    end
    return name, link, q, icon
end

local function coloredName(id)
    local name, _, q = itemInfo(id)
    local row = Gear.Item(id)
    q = q or (row and row[5]) or 1
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or ("Item " .. id))
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local function text(parent, template, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

local function border(frame, r, g, b, a)
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

local function setBorderColor(edges, r, g, b, a)
    for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, a) end
end

-- A flat toggle chip: gold when on.
local function chip(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 20)
    b.bg = flat(b, 1, 1, 1, 0.06)
    b.edges = border(b, GOLD[1], GOLD[2], GOLD[3], 0.35)
    b.label = text(b, "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    function b:SetOn(on)
        self.on = on
        self.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.28 or 0.04)
        self.label:SetTextColor(on and 1 or 0.6, on and 0.92 or 0.6, on and 0.7 or 0.6)
        setBorderColor(self.edges, GOLD[1], GOLD[2], GOLD[3], on and 0.8 or 0.25)
    end
    b:SetScript("OnClick", onClick)
    return b
end

local function quality(id)
    local _, _, q = itemInfo(id)
    local row = Gear.Item(id)
    return q or (row and row[5]) or 1
end

local function qualityRGB(q)
    local hex = (QUALITY[q] or QUALITY[1]):sub(3)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function showItemTooltip(owner, id, score, extra)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local _, link = itemInfo(id)
    if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(id) end
    GameTooltip:AddLine(" ")
    local o = opts(settings().col)
    local srcs = Gear.Sources(id, o)
    if #srcs == 0 then srcs = Gear.Sources(id) end
    GameTooltip:AddLine("Quelle", GOLD[1], GOLD[2], GOLD[3])
    for i, rec in ipairs(srcs) do
        if i > 6 then
            GameTooltip:AddLine(("... und %d weitere"):format(#srcs - 6), 0.6, 0.6, 0.6)
            break
        end
        GameTooltip:AddLine(Gear.SourceText(rec), 1, 1, 1, true)
    end
    local row = Gear.Item(id)
    if row and row[6] == 2 then GameTooltip:AddLine("Beim Anlegen gebunden: auch im Auktionshaus zu finden.", 0.6, 0.8, 1, true) end
    if score then GameTooltip:AddDoubleLine("Wertung", ("%.0f"):format(score), GOLD[1], GOLD[2], GOLD[3], 1, 1, 1) end
    if extra then GameTooltip:AddLine(extra, 0.6, 0.6, 0.6, true) end
    GameTooltip:AddLine("Shift-Klick: Link in den Chat", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function itemClick(id)
    if not id then return end
    local _, link = itemInfo(id)
    if link and HandleModifiedItemClick and ((IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())) then
        HandleModifiedItemClick(link)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Computing
---------------------------------------------------------------------------

local function compute()
    results = {}
    local g = settings()
    if g.view == "overview" then
        for c = 1, #Gear.COLUMNS do results[c] = Gear.Best(opts(c)) end
    else
        results[g.col] = Gear.Best(opts(g.col))
    end
end

-- The equipped item's score, when the window shows the player's own class.
local function equippedScore(slot, col)
    local g = settings()
    local _, myClass = UnitClass("player")
    if g.class ~= myClass or not GetInventoryItemLink then return nil, nil end
    local link = GetInventoryItemLink("player", slot.inv)
    if not link then return nil, nil end
    return Gear.ScoreLink(link, slot.key, opts(col)), link
end

---------------------------------------------------------------------------
-- Overview
---------------------------------------------------------------------------

local function buildOverview(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 14, -132)
    f:SetPoint("BOTTOMRIGHT", -14, 30)
    local cols = #Gear.COLUMNS
    local cellW = math.floor((W_WIDTH - 28 - SLOT_W) / cols)
    for c = 1, cols do
        local h = CreateFrame("Button", nil, f)
        h:SetSize(cellW, 18)
        h:SetPoint("TOPLEFT", SLOT_W + (c - 1) * cellW, 0)
        h.label = text(h, "GameFontNormalSmall")
        h.label:SetPoint("CENTER")
        h.label:SetJustifyH("CENTER")
        local lo, hi = Gear.COLUMNS[c][1], Gear.COLUMNS[c][2]
        h.label:SetText(lo == hi and tostring(lo) or (lo .. "-" .. hi))
        h.mark = flat(h, GOLD[1], GOLD[2], GOLD[3], 0.25, "ARTWORK")
        h.mark:Hide()
        local hl = h:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        h:SetScript("OnClick", function()
            settings().col = c
            settings().view = "list"
            ns.GearRefresh(true)
        end)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(("Level %s"):format(self.label:GetText()), 1, 0.82, 0)
            GameTooltip:AddLine("Klick: diesen Bereich als Liste mit Quellen und Alternativen", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        colHeads[c] = h
    end
    for r, slot in ipairs(Gear.SLOTS) do
        local y = -20 - (r - 1) * ROW_H
        local band = f:CreateTexture(nil, "BACKGROUND")
        band:SetPoint("TOPLEFT", 0, y)
        band:SetSize(W_WIDTH - 28, ROW_H - 1)
        band:SetColorTexture(1, 1, 1, (r % 2 == 0) and 0.03 or 0.055)
        local label = text(f, "GameFontNormalSmall", SLOT_W - 6)
        label:SetPoint("TOPLEFT", 6, y - 7)
        label:SetText(slot.name)
        cells[r] = {}
        for c = 1, cols do
            local b = CreateFrame("Button", nil, f)
            b:SetSize(ROW_H - 3, ROW_H - 3)
            b:SetPoint("TOPLEFT", SLOT_W + (c - 1) * cellW + math.floor((cellW - ROW_H + 3) / 2), y - 1)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 1, -1)
            b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.edges = border(b, 1, 1, 1, 0.5)
            b.up = b:CreateTexture(nil, "OVERLAY")
            b.up:SetSize(9, 9)
            b.up:SetPoint("TOPRIGHT", 2, 2)
            b.up:SetColorTexture(0.3, 0.9, 0.4, 1)
            b.up:Hide()
            b.lvl = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            b.lvl:SetPoint("BOTTOMRIGHT", 1, 0)
            b.empty = text(b, "GameFontDisableSmall")
            b.empty:SetPoint("CENTER")
            b.empty:SetText("-")
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.15)
            b:SetScript("OnEnter", function(self)
                if self.id then
                    local note
                    if self.slotKey == "MAINHAND" and self.plan == "2H" then note = "Zweihänder schlägt Waffenhand + Schildhand." end
                    showItemTooltip(self, self.id, self.score, note)
                elseif self.note then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(self.note, 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(self)
                if itemClick(self.id) then return end
                selSlot = slot.key
                settings().col = c
                settings().view = "list"
                ns.GearRefresh(true)
            end)
            b.slotKey = slot.key
            cells[r][c] = b
        end
    end
    return f
end

local function fillOverview()
    local g = settings()
    local myCol = Gear.ColumnOf(UnitLevel and UnitLevel("player") or 1)
    local _, myClass = UnitClass("player")
    for c, h in ipairs(colHeads) do
        if c == myCol and g.class == myClass then h.mark:Show() else h.mark:Hide() end
    end
    for r, slot in ipairs(Gear.SLOTS) do
        for c, b in ipairs(cells[r]) do
            local res = results[c]
            local list = res and res[slot.key]
            local e = list and list[1]
            b.plan = res and res.plan
            b.note = nil
            if e then
                local _, _, _, icon = itemInfo(e[1])
                b.id, b.score = e[1], e[2]
                b.icon:SetTexture(icon or 134400)
                b.icon:Show()
                local q = quality(e[1])
                local rr, gg, bb = qualityRGB(q)
                setBorderColor(b.edges, rr, gg, bb, 0.9)
                local row = Gear.Item(e[1])
                b.lvl:SetText(row and row[4] > 0 and row[4] or "")
                b.empty:Hide()
                -- only upgrades over what the player wears, in the player's own range
                local mine, link = nil, nil
                if c == myCol then mine, link = equippedScore(slot, c) end
                if ns.Get("gear.upgradeDot") and mine and e[2] - mine > math.abs(mine) * 0.02 and link and ns.ItemID(link) ~= e[1] then b.up:Show() else b.up:Hide() end
            else
                b.id, b.score = nil, nil
                b.icon:Hide()
                b.lvl:SetText("")
                b.up:Hide()
                setBorderColor(b.edges, 1, 1, 1, 0.08)
                b.empty:Show()
                if slot.key == "OFFHAND" and res and res.plan == "2H" then
                    b.note = "Zweihänder in der Waffenhand"
                    b.empty:SetText("2H")
                else
                    b.empty:SetText("-")
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- List of one range
---------------------------------------------------------------------------

local LIST_W = 540

local function buildList(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 14, -132)
    f:SetPoint("BOTTOMRIGHT", -14, 30)
    local head = CreateFrame("Frame", nil, f)
    head:SetSize(LIST_W, 18)
    head:SetPoint("TOPLEFT")
    local function col(p, x, w, label, template)
        local fs = text(p, template or "GameFontNormalSmall", w)
        fs:SetPoint("LEFT", x, 0)
        if label then fs:SetText(label) end
        return fs
    end
    col(head, 6, 80, "Slot")
    col(head, 90, 200, "Item")
    col(head, 294, 28, "Lvl")
    col(head, 326, 172, "Quelle")
    col(head, 498, 40, "Wert")
    for r, slot in ipairs(Gear.SLOTS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(LIST_W, ROW_H - 1)
        b:SetPoint("TOPLEFT", 0, -20 - (r - 1) * ROW_H)
        flat(b, 1, 1, 1, (r % 2 == 0) and 0.03 or 0.055)
        b.sel = flat(b, GOLD[1], GOLD[2], GOLD[3], 0.22, "BORDER")
        b.sel:Hide()
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.slot = col(b, 6, 80, slot.name)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 90, 0)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.name = col(b, 114, 176, nil, "GameFontHighlightSmall")
        b.lvl = col(b, 294, 28, nil, "GameFontHighlightSmall")
        b.src = col(b, 326, 170, nil, "GameFontHighlightSmall")
        b.score = col(b, 498, 40, nil, "GameFontHighlightSmall")
        b.slotKey = slot.key
        b:SetScript("OnEnter", function(self) if self.id then showItemTooltip(self, self.id, self.value, self.note) end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if itemClick(self.id) then return end
            selSlot = self.slotKey
            ns.GearRefresh(false)
        end)
        listRows[r] = b
    end

    altPanel = CreateFrame("Frame", nil, f)
    altPanel:SetPoint("TOPLEFT", LIST_W + 10, 0)
    altPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    flat(altPanel, 1, 1, 1, 0.03)
    border(altPanel, GOLD[1], GOLD[2], GOLD[3], 0.3)
    altPanel.title = text(altPanel, "GameFontNormal", 230)
    altPanel.title:SetPoint("TOPLEFT", 8, -6)
    altPanel.note = text(altPanel, "GameFontDisableSmall", 230)
    altPanel.note:SetPoint("TOPLEFT", 8, -24)
    altPanel.note:SetWordWrap(true)
    for i = 1, 13 do
        local b = CreateFrame("Button", nil, altPanel)
        b:SetSize(234, 30)
        b:SetPoint("TOPLEFT", 4, -50 - (i - 1) * 31)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(22, 22)
        b.icon:SetPoint("LEFT", 4, 0)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.name = text(b, "GameFontHighlightSmall", 160)
        b.name:SetPoint("TOPLEFT", 32, -2)
        b.src = text(b, "GameFontDisableSmall", 200)
        b.src:SetPoint("TOPLEFT", 32, -15)
        b.score = text(b, "GameFontHighlightSmall", 40)
        b.score:SetPoint("TOPRIGHT", -4, -2)
        b.score:SetJustifyH("RIGHT")
        b:SetScript("OnEnter", function(self) if self.id then showItemTooltip(self, self.id, self.value) end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self) itemClick(self.id) end)
        altRows[i] = b
    end
    return f
end

local function bestSourceText(id, o)
    local srcs = Gear.Sources(id, o)
    local rec = srcs[1]
    if not rec then return "" end
    local more = #srcs > 1 and (" |cff8f86a3+%d|r"):format(#srcs - 1) or ""
    return Gear.SourceText(rec, true) .. more
end

local function fillList()
    local g = settings()
    local res = results[g.col]
    local o = opts(g.col)
    local lo, hi = Gear.COLUMNS[g.col][1], Gear.COLUMNS[g.col][2]
    colLabel:SetText(lo == hi and ("Level " .. lo) or ("Level " .. lo .. "-" .. hi))
    for r, slot in ipairs(Gear.SLOTS) do
        local b = listRows[r]
        local list = res and res[slot.key]
        local e = list and list[1]
        if slot.key == selSlot then b.sel:Show() else b.sel:Hide() end
        b.note = nil
        if e then
            local _, _, _, icon = itemInfo(e[1])
            b.id, b.value = e[1], e[2]
            b.icon:SetTexture(icon or 134400)
            b.icon:Show()
            b.name:SetText(coloredName(e[1]))
            local row = Gear.Item(e[1])
            b.lvl:SetText(row and row[4] > 0 and row[4] or "-")
            b.src:SetText(bestSourceText(e[1], o))
            local mine, link = equippedScore(slot, g.col)
            if mine and mine > 0 and link and ns.ItemID(link) ~= e[1] then
                local gain = (e[2] - mine) / mine * 100
                b.score:SetText(gain >= 2 and ("|cff4fd06a+%d%%|r"):format(gain) or ("%.0f"):format(e[2]))
                b.note = ("Angelegt: %.0f, dieses Item: %.0f"):format(mine, e[2])
            else
                b.score:SetText(("%.0f"):format(e[2]))
            end
        else
            b.id, b.value = nil, nil
            b.icon:Hide()
            b.lvl:SetText("")
            b.score:SetText("")
            b.src:SetText("")
            if slot.key == "OFFHAND" and res and res.plan == "2H" then
                b.name:SetText("|cff8f86a3Zweihänder in der Waffenhand|r")
            else
                b.name:SetText("|cff8f86a3nichts gefunden|r")
            end
        end
    end

    -- alternatives for the selected slot
    local slotName
    for _, s in ipairs(Gear.SLOTS) do if s.key == selSlot then slotName = s.name end end
    altPanel.title:SetText("Alternativen: " .. (slotName or ""))
    local list = res and res[selSlot] or {}
    local note = ""
    if selSlot == "MAINHAND" and res then
        if res.plan == "2H" then
            note = ("Zweihänder %.0f gegen Waffenhand + Schildhand %.0f"):format(res.twoHandScore or 0, res.oneHandScore or 0)
        elseif res.twoHandScore then
            note = ("Waffenhand + Schildhand %.0f gegen Zweihänder %.0f"):format(res.oneHandScore or 0, res.twoHandScore or 0)
        end
    end
    altPanel.note:SetText(note)
    for i, b in ipairs(altRows) do
        local e = list[i]
        if e then
            local _, _, _, icon = itemInfo(e[1])
            b.id, b.value = e[1], e[2]
            b.icon:SetTexture(icon or 134400)
            b.name:SetText(coloredName(e[1]))
            local row = Gear.Item(e[1])
            b.src:SetText(((row and row[4] > 0) and ("L" .. row[4] .. "  ") or "") .. bestSourceText(e[1], o))
            b.score:SetText(("%.0f"):format(e[2]))
            b:Show()
        else
            b.id = nil
            b:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local function updateControls()
    local g = settings()
    for token, b in pairs(classButtons) do
        local on = token == g.class
        setBorderColor(b.edges, on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3, on and 1 or 0.6)
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.7)
    end
    local specs = Gear.Specs(g.class)
    local cur = g.specs[g.class] or (specs[1] and specs[1].key)
    local x = 0
    for i, b in ipairs(specButtons) do
        local sp = specs[i]
        if sp then
            b.key = sp.key
            b.label:SetText(sp.name)
            local w = math.max(60, b.label:GetStringWidth() + 16)
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", F, "TOPLEFT", 358 + x, -46)
            x = x + w + 4
            b:SetOn(sp.key == cur)
            b:Show()
        else
            b:Hide()
        end
    end
    local sp = Gear.SpecInfo(g.class, cur)
    kindButton.label:SetText(sp and sp.all and "Gewichtung: eigene" or ("Gewichtung: " .. ns.Get("gear.kind")))
    kindButton:SetOn(true)
    factionButton.label:SetText(g.faction == "A" and "Allianz" or g.faction == "H" and "Horde" or "Beide")
    factionButton:SetOn(true)
    for _, b in ipairs(filterButtons) do b:SetOn(g.sources[b.key] and true or false) end
    viewButtons.overview:SetOn(g.view == "overview")
    viewButtons.list:SetOn(g.view == "list")
    local r, gg, bb = classColor(g.class)
    titleText:SetText(("Ausrüstung |cff%02x%02x%02x%s|r"):format(r * 255, gg * 255, bb * 255, Gear.CLASS_NAMES[g.class] or g.class))
    colLabel:SetShown(g.view == "list")
    F.prevCol:SetShown(g.view == "list")
    F.nextCol:SetShown(g.view == "list")
end

local function updateStatus()
    local g = settings()
    local res = results[g.col] or results[1]
    local loading = Gear.Loading()
    local total, missing = 0, 0
    for _, r in pairs(results) do total, missing = math.max(total, r.total), math.max(missing, r.missing) end
    if loading > 0 or missing > 0 then
        statusText:SetText(("|cffe0a344Lade Itemdaten vom Server ...|r %d offen"):format(math.max(loading, missing)))
    else
        statusText:SetText(("%d passende Items bewertet. Shift-Klick verlinkt, Klick zeigt Quellen und Alternativen."):format(total))
    end
    if not res then statusText:SetText("") end
end

function ns.GearRefresh(recompute)
    if not F or not F:IsShown() then return end
    if recompute ~= false then compute() end
    updateControls()
    local g = settings()
    if g.view == "overview" then
        overview:Show(); listView:Hide()
        fillOverview()
    else
        overview:Hide(); listView:Show()
        fillList()
    end
    updateStatus()
end

-- While item data arrives, redraw at most once a second.
Gear.OnData(function()
    if not F or not F:IsShown() or refreshPending then return end
    refreshPending = true
    C_Timer.After(1, function()
        refreshPending = false
        ns.GearRefresh(true)
    end)
end)

local function build()
    F = CreateFrame("Frame", "AmisiaGearFrame", UIParent)
    F:SetSize(W_WIDTH, W_HEIGHT)
    F:SetPoint("CENTER")
    -- one layer above the main window (DIALOG), below roll and soft-reserve windows (FULLSCREEN_DIALOG)
    F:SetFrameStrata("FULLSCREEN")
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    F:SetScript("OnShow", function() ns.GearRefresh(true) end)
    F:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaGearFrame") end
    flat(F, 0.055, 0.04, 0.08, 0.96)
    border(F, GOLD[1], GOLD[2], GOLD[3], 0.6)

    local logo = F:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 12, -7)
    logo:SetTexture("Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia")
    titleText = text(F, "GameFontNormalLarge", 400)
    titleText:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    titleText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    -- class row
    for i, token in ipairs(ns.GEAR_WEIGHTS.order) do
        local b = CreateFrame("Button", nil, F)
        b:SetSize(30, 30)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 36, -42)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexture("Interface\\Icons\\ClassIcon_" .. CLASS_ICON[token])
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.edges = border(b, 0.3, 0.3, 0.3, 0.6)
        b:SetScript("OnClick", function()
            settings().class = token
            ns.GearRefresh(true)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(Gear.CLASS_NAMES[token], classColor(token))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        classButtons[token] = b
    end
    -- spec chips (placed in updateControls)
    for i = 1, 4 do
        local b = chip(F, "", 80, nil)
        b:SetScript("OnClick", function(self)
            settings().specs[settings().class] = self.key
            ns.GearRefresh(true)
        end)
        specButtons[i] = b
    end

    -- second row: weighting, faction, sources
    kindButton = chip(F, "", 140, function()
        ns.Set("gear.kind", ns.Get("gear.kind") == "Speedrun" and "Hardcore" or "Speedrun")
        ns.GearRefresh(true)
    end)
    kindButton:SetPoint("TOPLEFT", 14, -82)
    kindButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Gewichtung", 1, 0.82, 0)
        GameTooltip:AddLine("Speedrun bewertet Schaden höher, Hardcore Ausdauer und Rüstung. Heiler und Tanks haben eigene Gewichte.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    kindButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    factionButton = chip(F, "", 70, function()
        local g = settings()
        g.faction = g.faction == "A" and "H" or g.faction == "H" and "both" or "A"
        ns.GearRefresh(true)
    end)
    factionButton:SetPoint("LEFT", kindButton, "RIGHT", 6, 0)
    local prev = factionButton
    for i, fdef in ipairs(FILTERS) do
        local b = chip(F, fdef.label, 62, function(self)
            local g = settings()
            g.sources[self.key] = not g.sources[self.key]
            ns.GearRefresh(true)
        end)
        b.key = fdef.key
        b:SetPoint("LEFT", prev, "RIGHT", i == 1 and 14 or 4, 0)
        prev = b
        filterButtons[i] = b
    end

    -- third row: view, range, status
    viewButtons.overview = chip(F, "Übersicht", 80, function()
        settings().view = "overview"
        ns.GearRefresh(true)
    end)
    viewButtons.overview:SetPoint("TOPLEFT", 14, -108)
    viewButtons.list = chip(F, "Liste", 60, function()
        settings().view = "list"
        ns.GearRefresh(true)
    end)
    viewButtons.list:SetPoint("LEFT", viewButtons.overview, "RIGHT", 4, 0)
    F.prevCol = chip(F, "<", 22, function()
        local g = settings()
        g.col = math.max(1, g.col - 1)
        ns.GearRefresh(true)
    end)
    F.prevCol:SetPoint("LEFT", viewButtons.list, "RIGHT", 14, 0)
    colLabel = text(F, "GameFontNormal", 90)
    colLabel:SetPoint("LEFT", F.prevCol, "RIGHT", 6, 0)
    colLabel:SetJustifyH("CENTER")
    F.nextCol = chip(F, ">", 22, function()
        local g = settings()
        g.col = math.min(#Gear.COLUMNS, g.col + 1)
        ns.GearRefresh(true)
    end)
    F.nextCol:SetPoint("LEFT", colLabel, "RIGHT", 6, 0)
    local mine = chip(F, "Mein Charakter", 110, function()
        local g = settings()
        local _, myClass = UnitClass("player")
        g.class = myClass or g.class
        g.col = Gear.ColumnOf(UnitLevel("player") or 1)
        ns.GearRefresh(true)
    end)
    mine:SetPoint("TOPRIGHT", -14, -108)
    mine:SetOn(false)

    overview = buildOverview(F)
    listView = buildList(F)

    statusText = text(F, "GameFontDisableSmall", W_WIDTH - 28)
    statusText:SetPoint("BOTTOMLEFT", 14, 10)
end

-- The upgrades the player can get at their own level, against what they wear, best first.
function ns.GearMyUpgrades()
    if not Gear.Available() then return {}, nil, nil end
    local g = settings()
    local _, myClass = UnitClass("player")
    local o = {
        class = myClass, spec = g.specs[myClass] or (Gear.Specs(myClass)[1] or {}).key, kind = ns.Get("gear.kind"),
        faction = g.faction ~= "both" and g.faction or nil, sources = g.sources, level = UnitLevel("player") or 1,
    }
    local res = Gear.Best(o)
    local out = {}
    for _, slot in ipairs(Gear.SLOTS) do
        local e = res[slot.key] and res[slot.key][1]
        if e then
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slot.inv)
            local mine = link and Gear.ScoreLink(link, slot.key, o) or 0
            if (not link or ns.ItemID(link) ~= e[1]) and e[2] - mine > math.max(1, math.abs(mine) * 0.02) then
                out[#out + 1] = { slot = slot, id = e[1], score = e[2], gain = e[2] - mine, mine = mine }
            end
        end
    end
    table.sort(out, function(a, b) return a.gain > b.gain end)
    return out, res, o
end

function ns.ResetGearPosition()
    if F then F:ClearAllPoints(); F:SetPoint("CENTER") end
end

function ns.ToggleGearFrame()
    if not Gear.Available() then
        ns.msg("Die Ausrüstungstabelle gibt es nur in WoW Forever.")
        return
    end
    if not F then build() end
    if F:IsShown() then F:Hide() else F:Show() end
end

-- /amisia gear item <link>: what the planner reads from an item, to check the numbers.
function ns.GearDebug(arg)
    if not Gear.Available() then return end
    local id = ns.ItemID(arg) or tonumber(arg)
    if not id then
        ns.msg("Aufruf: /amisia gear item <Item-Link>")
        return
    end
    local s = Gear.ReadStats(arg:find("item:") and arg or id)
    if not s then
        ns.msg("Keine Daten für " .. id .. ", gleich nochmal versuchen.")
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return
    end
    local parts = {}
    for k, v in pairs(s) do
        if k ~= "CLASSES" then parts[#parts + 1] = k .. "=" .. v end
    end
    table.sort(parts)
    ns.msg(("%d: %s"):format(id, table.concat(parts, " ")))
    -- what the client itself answered, so a stat name the planner does not know shows up
    local getStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    local raw = getStats and getStats(arg:find("item:") and arg or ("item:" .. id))
    if raw then
        local rawParts = {}
        for k, v in pairs(raw) do rawParts[#rawParts + 1] = (Gear.STAT[k] and "" or "|cffe0a344?|r") .. k .. "=" .. tostring(v) end
        table.sort(rawParts)
        ns.msg("Client: " .. table.concat(rawParts, " "))
    end
    local g = settings()
    local o = opts(g.col)
    local row = Gear.Item(id)
    local kind = row and ({ ["2H"] = "2H", ["1H"] = "MH", MH = "MH", OHW = "OH", RANGED = "RANGED" })[Gear.GROUP[row[1]]]
    local w = Gear.Weights(o.class, o.spec, o.kind, o.level)
    ns.msg(("Wertung %s/%s bei Level %d: %.1f%s"):format(o.class, o.spec or "?", o.level, Gear.Score(s, w, o.level, kind, o.class),
        row and "" or " (nicht in der Tabelle)"))
end

ns.RegisterSettings{ key = "gear", label = "Ausrüstung", order = 50, available = function() return Gear.Available() end, items = {
    { key = "gear.kind", type = "choice", label = "Gewichtung", default = "Speedrun",
      values = { { "Speedrun", "Speedrun" }, { "Hardcore", "Hardcore" } },
      tip = "Speedrun bewertet Schaden höher, Hardcore Ausdauer und Rüstung." },
    { key = "gear.upgradeDot", type = "toggle", label = "Upgrade-Punkt in der Tabelle", default = true,
      tip = "Grüner Punkt an Items, die besser sind als das, was du trägst." },
}}
ns.RegisterSlash("gear", { aliases = { "ausruestung" }, args = "[item <Link>]", desc = "Ausrüstungstabelle (WoW Forever)",
    run = function(rest)
        local sub, arg = rest:match("^(%S+)%s*(.*)$")
        if sub and sub:lower() == "item" then ns.GearDebug(arg) else ns.ToggleGearFrame() end
    end })
