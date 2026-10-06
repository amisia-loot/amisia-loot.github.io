-- Amisia roll window: the running round with its rolls in winning order, a hand-out button per
-- row, stop, tie-break and close. Alt-click on an item in the loot window starts a round.
-- A hand-out is only offered once the round is over, and always asks first: while rolls come in
-- the rows re-sort, so a click could land on the row that just moved up.
-- Below the list a row enters rolls by hand (the roll chat is secret in a boss fight on Forever);
-- a finished round changed that way is announced with "Ergebnis ansagen".
local ADDON, ns = ...
local W = ns.W

local ROWS = 12
local ROW_H = 18
local WIDTH = 360
local LIST_TOP = 50
local ENTRY_Y = -(LIST_TOP + ROWS * ROW_H + 4)   -- the entry row under the list
local HINT_Y = ENTRY_Y - 24                      -- the hint under it, two lines
local HEIGHT = -HINT_Y + 26 + 10 + 22 + 8        -- hint, gap, buttons, margin
local GREY = "|cff8f86a3"

local F, header, timer, stopBtn, againBtn, hint
local rows = {}
local lootOpen = false
local entryKind = "MS"

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
        if c and ns.SameName(c, name) then
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

-- The names to pick from: the group and the running recording, plain, sorted.
local function entryNames()
    local set, out = {}, {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then set[n] = true end
    end
    local s = ns.Active and ns.Active()
    for n in pairs(s and s.members or {}) do
        n = ns.FullName(ns.Plain(n))
        if n then set[n] = true end
    end
    for n in pairs(set) do out[#out + 1] = { value = n, text = n } end
    table.sort(out, function(a, b) return a.text < b.text end)
    return out
end

-- The hint line: a reason from the last entry (red), the lockdown, else the alt-click hint.
local function showHint(r)
    if F.reason and F.reasonRound ~= r then F.reason = nil end
    if F.reason then
        hint:SetText("|cffe05050" .. F.reason .. "|r")
    elseif r and r.lockdown then
        hint:SetText(("|cffe0a344Bosskampf: Würfe im Chat nicht lesbar (%d Zeilen). Würfe von Hand eintragen.|r"):format(r.hidden or 0))
    else
        hint:SetText(GREY .. "Alt-Klick im Lootfenster startet eine Runde.|r")
    end
    hint:Show()
end

local function setKind(kind)
    entryKind = kind
    F.msChip:SetOn(kind == "MS")
    F.osChip:SetOn(kind == "OS")
end

local refresh

-- Enters the roll of the entry row; a reason stays in the hint line until the next try.
local function addEntry()
    local e, why = ns.AddManualRoll(F.namePick:GetValue(), F.valueEdit:GetText(), entryKind)
    if e then
        F.reason = nil
        F.valueEdit:SetText("")
    else
        F.reason, F.reasonRound = why, ns.CurrentRoll() or ns.LastRoll()
    end
    refresh()
end

refresh = function()
    if not F or not F:IsShown() then return end
    local r = ns.CurrentRoll() or ns.LastRoll()
    F.namePick:SetValues(entryNames(), "Anderer Name")
    showHint(r)
    if not r then
        header:SetText("Keine Roll-Runde. Alt-Klick auf ein Item im Lootfenster startet eine.")
        timer:SetText("")
        for i = 1, ROWS do rows[i]:Hide() end
        stopBtn:Disable()
        againBtn:Disable()
        F.resultBtn:Disable()
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
    F.resultBtn:SetEnabled((r.done and r.dirty) and true or false)
    local list = ns.RollRanking(r)
    local i = 0
    for _, e in ipairs(list) do
        i = i + 1
        if i > ROWS then break end
        local row = rows[i]
        row.who = e.name
        -- an alt names its main in grey: its plus-one is the main's
        local main = ns.AltMain(e.name)
        row.name:SetText(("|c%s%s|r"):format(classColor(e.class), e.name) .. (main and (" |cff9d9d9d(" .. main .. ")|r") or ""))
        local plus = ns.PlusLabel(r, e.name)
        row.kind:SetText((e.rank or e.kind or "") .. (plus and (" " .. plus) or ""))
        row.value:SetText(tostring(e.value))
        row.hand:SetText(e.manual and "Hand" or "")
        row.why:SetText(r.winner == e.name and "|cff4fbf7aGewinner|r" or "")
        row.reason:SetText("")
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
        row.hand:SetText("")
        row.why:SetText("")
        -- the reason takes the room of the hand mark, the winner mark and the hidden button
        row.reason:SetText(e.why or "")
        row.award:Hide()
        row:Show()
    end
    for j = i + 1, ROWS do rows[j]:Hide() end
end

local function build()
    -- a dialog in the client's frame without a portrait, the title in its bar; Escape leaves it open
    -- as before (it stays through the loot), the side tab of the main window follows it
    F = W.Window("AmisiaRollFrame", WIDTH, HEIGHT, { title = "Amisia Rolls", strata = "FULLSCREEN_DIALOG",
        onShow = refresh, escape = false,
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end })
    F:SetPoint("CENTER", 260, 80)

    -- the item on the left, the time (it sat under the close button) on the right of the same line
    header = text(F, "GameFontHighlight", 220)
    header:SetPoint("TOPLEFT", 12, -30)
    timer = text(F, "GameFontNormalLarge", 110)
    timer:SetPoint("TOPRIGHT", -12, -28)
    timer:SetJustifyH("RIGHT")

    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, F)
        row:SetSize(336, ROW_H)
        row:SetPoint("TOPLEFT", 12, -LIST_TOP - (i - 1) * ROW_H)
        local rb = row:CreateTexture(nil, "BACKGROUND")
        rb:SetAllPoints()
        rb:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        row.name = text(row, "GameFontHighlightSmall", 110)
        row.name:SetPoint("LEFT", 4, 0)
        row.kind = text(row, "GameFontHighlightSmall", 44)
        row.kind:SetPoint("LEFT", 116, 0)
        row.value = text(row, "GameFontHighlightSmall", 26)
        row.value:SetPoint("LEFT", 162, 0)
        row.hand = text(row, "GameFontDisableSmall", 28)
        row.hand:SetPoint("LEFT", 190, 0)
        row.why = text(row, "GameFontHighlightSmall", 48)
        row.why:SetPoint("LEFT", 220, 0)
        -- why a roll was not counted, on rows without a button
        row.reason = text(row, "GameFontDisableSmall", 336 - 190 - 4)
        row.reason:SetPoint("LEFT", 190, 0)
        row.award = W.Button(row, "Vergeben", 64, function() if row.who then confirmGive(row.who) end end, { height = ROW_H })
        row.award:SetPoint("RIGHT", -2, 0)
        row:Hide()
        rows[i] = row
    end

    -- entry row: [Name v] [87] [MS] [OS] [Eintragen]; Enter in the number box enters too
    F.namePick = W.Picker(F, 120, function() F.valueEdit:SetFocus() end)
    F.namePick:SetPoint("TOPLEFT", 12, ENTRY_Y)
    F.valueEdit = W.LineEdit(F, 40)
    F.valueEdit:SetPoint("TOPLEFT", 136, ENTRY_Y)
    F.valueEdit:SetNumeric(true)
    F.valueEdit:SetMaxLetters(3)
    F.valueEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addEntry()
    end)
    F.msChip = W.Chip(F, "MS", 30, function() setKind("MS") end)
    F.msChip:SetPoint("TOPLEFT", 180, ENTRY_Y)
    F.osChip = W.Chip(F, "OS", 30, function() setKind("OS") end)
    F.osChip:SetPoint("TOPLEFT", 212, ENTRY_Y)
    F.addBtn = W.Button(F, "Eintragen", 76, addEntry, { height = 20 })
    F.addBtn:SetPoint("TOPLEFT", 248, ENTRY_Y)
    setKind("MS")

    hint = text(F, "GameFontDisableSmall", WIDTH - 24)
    hint:SetPoint("TOPLEFT", 12, HINT_Y)
    hint:SetWordWrap(true)
    F.lockHint = hint
    F.note = hint

    stopBtn = W.Button(F, "Stopp", 80, function() ns.StopRoll() end)
    stopBtn:SetPoint("BOTTOMLEFT", 12, 10)

    againBtn = W.Button(F, "Nochmal", 80, function() ns.RerollTie() end)
    againBtn:SetPoint("LEFT", stopBtn, "RIGHT", 6, 0)

    F.resultBtn = W.Button(F, "Ergebnis ansagen", 120, function() ns.AnnounceRollResult(ns.CurrentRoll() or ns.LastRoll()) end)
    F.resultBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    F.rows = rows
    -- the parts the layout tests read
    F.header, F.timer, F.stopBtn, F.againBtn = header, timer, stopBtn, againBtn
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

-- Alt-click on an item in the open loot window starts a round for it; Alt+Shift belongs to the
-- award dialog.
if type(HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        local id = ns.ItemID(link)
        if ns.Get("rolls.altClick") and lootOpen and IsAltKeyDown() and not IsShiftKeyDown() and id and ns.InLootWindow(id) then
            local ok, why = ns.StartRoll(link)
            if ok then ns.ShowRollFrame() elseif why then ns.msg(why) end
        end
    end)
end

ns.RegisterSlash("rolls", { officer = true, desc = "Roll-Fenster öffnen oder schließen", run = function() ns.ToggleRollFrame() end })
