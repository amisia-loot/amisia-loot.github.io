-- Amisia soft-reserves: a pasted list (softres.it CSV or "Name [item]" lines), shown in item
-- tooltips and on the loot window, and ranked first in roll rounds.
local ADDON, ns = ...

local F, editBox, resultText, dateText
local marks = {}   -- loot button -> "SR" font string

local function shortName(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    name = name:match("^([^%-]+)") or name
    if name == "" then return nil end
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- Splits one CSV line on delim, honouring double quotes.
local function splitCsv(line, delim)
    local out, cur, q, i = {}, "", false, 1
    while i <= #line do
        local ch = line:sub(i, i)
        if q then
            if ch == '"' then
                if line:sub(i + 1, i + 1) == '"' then cur = cur .. '"'; i = i + 1 else q = false end
            else
                cur = cur .. ch
            end
        elseif ch == '"' then
            q = true
        elseif ch == delim then
            out[#out + 1] = cur; cur = ""
        else
            cur = cur .. ch
        end
        i = i + 1
    end
    out[#out + 1] = cur
    return out
end

local function lines(text)
    local out = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

-- Returns byItem { [itemID] = { names } }, the number of reservations and the unrecognised lines.
function ns.ParseSoftRes(text)
    local byItem, sets, bad, count = {}, {}, {}, 0
    local function add(item, name)
        if not item or not name then return false end
        sets[item] = sets[item] or {}
        if not sets[item][name] then
            sets[item][name] = true
            byItem[item] = byItem[item] or {}
            byItem[item][#byItem[item] + 1] = name
            count = count + 1
        end
        return true
    end
    local all = lines(text)
    if #all > 0 and all[1]:lower():find("itemid", 1, true) then
        local head = all[1]
        local delim = (select(2, head:gsub(";", "")) > select(2, head:gsub(",", ""))) and ";" or ","
        local cols = {}
        for i, h in ipairs(splitCsv(head, delim)) do cols[h:match("^%s*(.-)%s*$"):lower()] = i end
        local cItem = cols["itemid"]
        local cName = cols["name"] or cols["character"] or cols["player"]
        for i = 2, #all do
            local f = splitCsv(all[i], delim)
            local item = cItem and tonumber((f[cItem] or ""):match("(%d+)"))
            local name = cName and shortName(f[cName])
            if not add(item, name) then bad[#bad + 1] = all[i] end
        end
    else
        for _, line in ipairs(all) do
            local name, rest = line:match("^([^%s,;:\t]+)[%s,;:\t]*(.*)$")
            local item = rest and (ns.ItemID(rest) or tonumber(rest:match("^%s*(%d+)%s*$")))
            if not add(item, shortName(name)) then bad[#bad + 1] = line end
        end
    end
    for _, names in pairs(byItem) do table.sort(names) end
    return byItem, count, bad
end

function ns.SetSoftRes(text)
    local byItem, count, bad = ns.ParseSoftRes(text)
    AmisiaDB.softres = { date = date("%Y-%m-%d"), byItem = byItem, raw = text or "", count = count }
    ns.MarkLootButtons()
    return count, bad
end

function ns.ClearSoftRes()
    AmisiaDB.softres = nil
    ns.MarkLootButtons()
end

function ns.ReservedBy(item)
    local sr = AmisiaDB and AmisiaDB.softres
    local names = sr and sr.byItem and sr.byItem[tonumber(item) or 0]
    return names or {}
end

function ns.SoftResInfo()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return nil end
    return sr.date, sr.count or 0
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function tooltipLink(tip)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tip)
        return link
    end
    if tip.GetItem then
        local _, link = tip:GetItem()
        return link
    end
end

local function addLine(tip)
    if not tip or not tip.AddLine then return end
    local id = ns.ItemID(tooltipLink(tip))
    if not id then return end
    local names = ns.ReservedBy(id)
    if #names == 0 then return end
    tip:AddLine("Reserviert: " .. table.concat(names, ", "), 0.89, 0.72, 0.34)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLine)
else
    GameTooltip:HookScript("OnTooltipSetItem", addLine)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", addLine) end
end

---------------------------------------------------------------------------
-- Loot window marks
---------------------------------------------------------------------------
local function markButton(btn, slot)
    local link = slot and GetLootSlotLink and GetLootSlotLink(slot)
    local reserved = link and #ns.ReservedBy(ns.ItemID(link)) > 0
    local mark = marks[btn]
    if reserved and not mark then
        mark = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        mark:SetText("SR")
        mark:SetTextColor(0.89, 0.72, 0.34)
        marks[btn] = mark
    end
    if mark then
        if reserved then mark:Show() else mark:Hide() end
    end
end

-- For tests and the window: whether a loot button carries a visible mark.
function ns.SoftResMarkShown(btn)
    local m = marks[btn]
    return (m and m:IsShown()) and true or false
end

function ns.MarkLootButtons()
    local n = LOOTFRAME_NUMBUTTONS or 4
    for i = 1, n do
        local btn = _G["LootButton" .. i]
        if btn and btn.slot and btn.IsShown and btn:IsShown() then
            markButton(btn, btn.slot)
        elseif btn and marks[btn] then
            marks[btn]:Hide()
        end
    end
    local box = LootFrame and LootFrame.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(function(frame)
            if frame.GetSlotIndex then markButton(frame, frame:GetSlotIndex()) end
        end)
    end
end

ns.OnEvent("LOOT_OPENED", function() C_Timer.After(0, ns.MarkLootButtons) end)
ns.OnEvent("LOOT_SLOT_CLEARED", function() C_Timer.After(0, ns.MarkLootButtons) end)
if type(LootFrame_Update) == "function" then
    hooksecurefunc("LootFrame_Update", ns.MarkLootButtons)
end

---------------------------------------------------------------------------
-- Import window
---------------------------------------------------------------------------
local function refresh()
    if not F or not F:IsShown() then return end
    local sr = AmisiaDB.softres
    if sr then
        local today = date("%Y-%m-%d")
        dateText:SetText(sr.date == today
            and ("|cff4fbf7aListe von heute:|r %d Reservierungen"):format(sr.count or 0)
            or ("|cffe0a344Liste vom %s:|r %d Reservierungen. Fuer einen neuen Raid neu einfuegen."):format(sr.date, sr.count or 0))
        if editBox:GetText() == "" then editBox:SetText(sr.raw or "") end
    else
        dateText:SetText("|cff8f86a3Keine Soft-Reserves.|r softres.it-CSV oder Zeilen wie 'Name [Item-Link]' einfuegen.")
    end
end

local function build()
    F = CreateFrame("Frame", "AmisiaSoftResFrame", UIParent)
    F:SetSize(440, 340)
    F:SetPoint("CENTER", 0, 40)
    F:SetFrameStrata("DIALOG")
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    F:SetScript("OnShow", refresh)
    F:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaSoftResFrame") end

    local bg = F:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.04, 0.08, 0.96)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = F:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.89, 0.72, 0.34, 0.6)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) end
        if e[4] then t:SetHeight(e[4]) end
    end

    local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Soft-Reserves")
    title:SetTextColor(0.89, 0.72, 0.34)

    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    dateText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dateText:SetPoint("TOPLEFT", 12, -32)
    dateText:SetWidth(410)
    dateText:SetJustifyH("LEFT")

    local boxBg = CreateFrame("Frame", nil, F)
    boxBg:SetPoint("TOPLEFT", 12, -50)
    boxBg:SetPoint("BOTTOMRIGHT", -12, 64)
    local bb = boxBg:CreateTexture(nil, "BACKGROUND")
    bb:SetAllPoints()
    bb:SetColorTexture(0, 0, 0, 0.45)

    local scroll = CreateFrame("ScrollFrame", "AmisiaSoftResScroll", boxBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(380)
    editBox:SetHeight(200)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(editBox)
    boxBg:EnableMouse(true)
    boxBg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    resultText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultText:SetPoint("BOTTOMLEFT", 12, 40)
    resultText:SetWidth(410)
    resultText:SetJustifyH("LEFT")

    local apply = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    apply:SetSize(110, 22)
    apply:SetPoint("BOTTOMLEFT", 12, 10)
    apply:SetText("Uebernehmen")
    apply:SetScript("OnClick", function()
        local count, bad = ns.SetSoftRes(editBox:GetText())
        resultText:SetText(("%d Reservierungen uebernommen, %d Zeilen nicht erkannt."):format(count, #bad)
            .. (#bad > 0 and (" Erste: " .. bad[1]:sub(1, 40)) or ""))
        refresh()
    end)

    local clear = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    clear:SetSize(90, 22)
    clear:SetPoint("LEFT", apply, "RIGHT", 6, 0)
    clear:SetText("Leeren")
    clear:SetScript("OnClick", function()
        ns.ClearSoftRes()
        editBox:SetText("")
        resultText:SetText("Liste geleert.")
        refresh()
    end)
    F.editBox, F.resultText, F.dateText, F.applyBtn, F.clearBtn = editBox, resultText, dateText, apply, clear
    ns.SoftResFrame = F
end

function ns.ToggleSoftResFrame()
    if not F then build() end
    if F:IsShown() then F:Hide() else F:Show() end
end
