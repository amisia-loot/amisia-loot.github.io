-- Amisia roll window: the running round with its rolls in winning order, a hand-out button per
-- row, stop, tie-break and close. Alt-click on an item in the loot window starts a round.
-- A hand-out is only offered once the round is over, and always asks first: while rolls come in
-- the rows re-sort, so a click could land on the row that just moved up.
local ADDON, ns = ...

local ROWS = 12
local ROW_H = 18
local GOLD = { 0.89, 0.72, 0.34 }

local F, header, timer, stopBtn, againBtn, hint
local rows = {}
local lootOpen = false

local function text(parent, template, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr or "ffffffff"
end

-- Whether an item currently lies in the open loot window.
function ns.InLootWindow(id)
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        if ns.ItemID(GetLootSlotLink(i)) == id then return true end
    end
    return false
end

-- Hands an item (by default the current round's) to a name through master loot, when the loot
-- window still holds it.
function ns.AwardFromRoll(name, item, link)
    local r = ns.CurrentRoll() or ns.LastRoll()
    item = item or (r and r.item)
    link = link or (r and r.item == item and r.link) or nil
    if not item or not name then return end
    if not lootOpen or type(GiveMasterLoot) ~= "function" or not GetMasterLootCandidate then
        ns.msg(("Lootfenster öffnen und Master Loot nutzen, oder /amisia award %s %s"):format(name, link or tostring(item)))
        return
    end
    local slot
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        if ns.ItemID(GetLootSlotLink(i)) == item then slot = i break end
    end
    if not slot then
        ns.msg("Das Item liegt nicht mehr im Lootfenster.")
        return
    end
    for i = 1, 40 do
        local c = GetMasterLootCandidate(slot, i)
        if c and (c == name or c:match("^([^%-]+)") == name) then
            GiveMasterLoot(slot, i)
            return
        end
    end
    ns.msg(name .. " ist kein Kandidat für dieses Item (zu weit weg?).")
end

-- The row button: asks before handing out. The item travels with the question, so a round started
-- while the question is open cannot swap the item.
local function confirmGive(name)
    local r = ns.CurrentRoll() or ns.LastRoll()
    if not r or not name then return end
    if not r.done then
        ns.msg("Erst vergeben, wenn die Runde beendet ist (Stopp oder Zeit abgelaufen).")
        return
    end
    StaticPopup_Show("AMISIA_GIVE", r.link or r.name, name, { name = name, item = r.item, link = r.link })
end

StaticPopupDialogs["AMISIA_GIVE"] = {
    text = "%s an %s vergeben?",
    button1 = "Vergeben",
    button2 = "Abbrechen",
    OnAccept = function(_, data)
        if data then ns.AwardFromRoll(data.name, data.item, data.link) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function refresh()
    if not F or not F:IsShown() then return end
    local r = ns.CurrentRoll() or ns.LastRoll()
    if not r then
        header:SetText("Keine Roll-Runde. Alt-Klick auf ein Item im Lootfenster startet eine.")
        timer:SetText("")
        for i = 1, ROWS do rows[i]:Hide() end
        stopBtn:Disable()
        againBtn:Disable()
        return
    end
    header:SetText(r.link or r.name)
    if r.done then
        timer:SetText(r.winner and ("Gewinner: " .. r.winner) or (r.tie and "Gleichstand" or "Beendet"))
    else
        timer:SetText(("%d s"):format(r.leftAt or 0))
    end
    if r.done then stopBtn:Disable() else stopBtn:Enable() end
    if r.done and r.tie then againBtn:Enable() else againBtn:Disable() end
    local list = ns.RollRanking(r)
    local i = 0
    for _, e in ipairs(list) do
        i = i + 1
        if i > ROWS then break end
        local row = rows[i]
        row.who = e.name
        row.name:SetText(("|c%s%s|r"):format(classColor(e.class), e.name))
        row.kind:SetText(e.rank or e.kind or "")
        row.value:SetText(tostring(e.value))
        row.why:SetText(r.winner == e.name and "|cff4fbf7aGewinner|r" or "")
        row.award:SetEnabled(r.done and true or false)
        row.award:Show()
        row:Show()
    end
    for _, e in ipairs(r.ignored) do
        i = i + 1
        if i > ROWS then break end
        local row = rows[i]
        row.who = nil
        row.name:SetText(("|cff8f86a3%s|r"):format(e.name))
        row.kind:SetText("")
        row.value:SetText(("|cff8f86a3%d|r"):format(e.value or 0))
        row.why:SetText(("|cff8f86a3%s|r"):format(e.why or ""))
        row.award:Hide()
        row:Show()
    end
    for j = i + 1, ROWS do rows[j]:Hide() end
end

local function build()
    F = CreateFrame("Frame", "AmisiaRollFrame", UIParent)
    F:SetSize(360, 60 + ROWS * ROW_H + 40)
    F:SetPoint("CENTER", 260, 80)
    F:SetFrameStrata("FULLSCREEN_DIALOG")
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    F:SetScript("OnShow", refresh)
    F:Hide()

    local bg = F:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.04, 0.08, 0.96)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = F:CreateTexture(nil, "BORDER")
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.6)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) end
        if e[4] then t:SetHeight(e[4]) end
    end

    local title = text(F, "GameFontNormal", 200)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Amisia Rolls")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    header = text(F, "GameFontHighlight", 330)
    header:SetPoint("TOPLEFT", 12, -30)
    timer = text(F, "GameFontNormalLarge", 120)
    timer:SetPoint("TOPRIGHT", -40, -8)
    timer:SetJustifyH("RIGHT")

    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, F)
        row:SetSize(336, ROW_H)
        row:SetPoint("TOPLEFT", 12, -50 - (i - 1) * ROW_H)
        local rb = row:CreateTexture(nil, "BACKGROUND")
        rb:SetAllPoints()
        rb:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        row.name = text(row, "GameFontHighlightSmall", 120)
        row.name:SetPoint("LEFT", 4, 0)
        row.kind = text(row, "GameFontHighlightSmall", 30)
        row.kind:SetPoint("LEFT", 128, 0)
        row.value = text(row, "GameFontHighlightSmall", 34)
        row.value:SetPoint("LEFT", 160, 0)
        row.why = text(row, "GameFontHighlightSmall", 80)
        row.why:SetPoint("LEFT", 196, 0)
        row.award = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.award:SetSize(64, ROW_H - 2)
        row.award:SetPoint("RIGHT", -2, 0)
        row.award:SetText("Vergeben")
        row.award:SetScript("OnClick", function() if row.who then confirmGive(row.who) end end)
        row:Hide()
        rows[i] = row
    end

    stopBtn = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    stopBtn:SetSize(90, 22)
    stopBtn:SetPoint("BOTTOMLEFT", 12, 10)
    stopBtn:SetText("Stopp")
    stopBtn:SetScript("OnClick", function() ns.StopRoll() end)

    againBtn = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    againBtn:SetSize(90, 22)
    againBtn:SetPoint("LEFT", stopBtn, "RIGHT", 6, 0)
    againBtn:SetText("Nochmal")
    againBtn:SetScript("OnClick", function() ns.RerollTie() end)

    hint = text(F, "GameFontDisableSmall", 150)
    hint:SetPoint("BOTTOMRIGHT", -12, 14)
    hint:SetJustifyH("RIGHT")
    hint:SetText("Alt-Klick im Lootfenster")
    F.rows = rows
    ns.RollFrame = F
end

function ns.ShowRollFrame()
    if not F then build() end
    F:Show()
    refresh()
end

function ns.ToggleRollFrame()
    if not F then build() end
    if F:IsShown() then F:Hide() else ns.ShowRollFrame() end
end

ns.OnRollChanged = function() refresh() end

ns.OnEvent("LOOT_OPENED", function() lootOpen = true end)
ns.OnEvent("LOOT_CLOSED", function() lootOpen = false end)

-- Alt-click on an item in the open loot window starts a round for it.
if type(HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        local id = ns.ItemID(link)
        if lootOpen and IsAltKeyDown() and id and ns.InLootWindow(id) then
            local ok, why = ns.StartRoll(link)
            if ok then ns.ShowRollFrame() elseif why then ns.msg(why) end
        end
    end)
end
