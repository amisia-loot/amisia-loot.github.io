-- Amisia roll window: the running round with its rolls in winning order, a hand-out button per
-- row, stop, tie-break and close. Alt-click on an item in the loot window starts a round.
-- A hand-out is only offered once the round is over, and always asks first: while rolls come in
-- the rows re-sort, so a click could land on the row that just moved up.
-- Below the list a row enters rolls by hand (the roll chat is secret in a boss fight on Forever);
-- a finished round changed that way is announced with "Ergebnis ansagen".
-- Under the item a line names everyone the item is an upgrade or a wish for (the answers to "Wer
-- braucht das?", asked by the window itself when a round starts, the guild wishes and the own
-- comparison, ns.UpgradeOf), and each row shows its roller's part of it. For green and blue items
-- bound on pickup a hint says the appearance is already granted (rolls.lookHint): a hint, no rule.
-- Above them the officers' loot prio of the item (LootPrio.lua: "Prio: 1. Anna (Tank), 2. Krieger
-- Furor" and the note, everything in its tooltip), "P1", "P2" in the rows of the listed rollers
-- (gold by name, grey by class) and, for officers, a "Prio" button that edits it.
-- In a DKP or EPGP guild the rows are bids (with the bidder's standing) or need/greed sorted by PR
-- (EP/GP beside it); the entry row then takes a bid, or need (MS) and greed (OS) without a number.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local ROWS = 12
local ROW_H = 18
local WIDTH = 440
local ROW_W = WIDTH - 24
local PRIO_Y = -48                               -- the officers' prio under the item
local UP_Y = -62                                 -- the upgrade line under it
local LOOK_Y = -76                               -- the appearance hint under that, two lines
local LIST_TOP = 106
local ENTRY_Y = -(LIST_TOP + ROWS * ROW_H + 4)   -- the entry row under the list
local HINT_Y = ENTRY_Y - 24                      -- the hint under it, two lines
local HEIGHT = -HINT_Y + 26 + 10 + 22 + 8        -- hint, gap, buttons, margin
local GREY = "|cff8f86a3"
local UP_GREEN, UP_ORANGE, UP_BLUE = "|cff4fe673", "|cffff9933", "|cff66b3ff"
local PRIO_GOLD = "|cffffb347"
local LINE_NAMES = 6
local QUALITY_GREEN, QUALITY_BLUE, BIND_PICKUP = 2, 3, 1
local LOOK_TEXT = L["Aussehen: bekommen laut Blizzard alle Berechtigten schon beim Plündern. Nicht nur fürs Aussehen würfeln."]

local F, header, timer, stopBtn, againBtn, hint
local rows = {}
local lootOpen = false
local entryKind = "MS"

local function text(parent, template, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or T.FONT.text)
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
        ns.msg(L["Lootfenster öffnen und Master Loot nutzen, oder /amisia award %s %s"]:format(name, link or tostring(item)))
        return
    end
    local slot
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        if ns.ItemID(GetLootSlotLink(i)) == item then slot = i break end
    end
    if not slot then
        ns.msg(L["Das Item liegt nicht mehr im Lootfenster."])
        return
    end
    for i = 1, 40 do
        local c = GetMasterLootCandidate(slot, i)
        if c and ns.SameName(c, name) then
            GiveMasterLoot(slot, i)
            return
        end
    end
    ns.msg(L["%s ist kein Kandidat für dieses Item (zu weit weg?)."]:format(name))
end

-- The row button: asks before handing out. The item travels with the question, so a round started
-- while the question is open cannot swap the item.
local function confirmGive(name)
    local r = ns.CurrentRoll() or ns.LastRoll()
    if not r or not name then return end
    if not r.done then
        ns.msg(L["Erst vergeben, wenn die Runde beendet ist (Stopp oder Zeit abgelaufen)."])
        return
    end
    StaticPopup_Show("AMISIA_GIVE", r.link or r.name, name, { name = name, item = r.item, link = r.link })
end

StaticPopupDialogs["AMISIA_GIVE"] = {
    text = L["%s an %s vergeben?"],
    button1 = L["Vergeben"],
    button2 = L["Abbrechen"],
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
        hint:SetText("|cffe0a344" .. L["Bosskampf: Würfe im Chat nicht lesbar (%d Zeilen). Würfe von Hand eintragen."]:format(r.hidden or 0) .. "|r")
    elseif r and r.mode and ns.PointsRoundHint then
        hint:SetText(GREY .. ns.PointsRoundHint(r) .. "|r")
    else
        hint:SetText(GREY .. L["Alt-Klick im Lootfenster startet eine Runde."] .. "|r")
    end
    hint:Show()
end

local function setKind(kind)
    entryKind = kind
    F.msChip:SetOn(kind == "MS")
    F.osChip:SetOn(kind == "OS")
end

local refresh

---------------------------------------------------------------------------
-- Upgrades and the appearance hint
---------------------------------------------------------------------------

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function compareOn()
    return (ns.Gear and ns.Gear.Available() and ns.Get("bis.compare") ~= false) and true or false  -- l10n-ok: setting key
end

-- Asks the raid once per round who needs the item, unless it was asked in the last 30 minutes
-- (the loot announcement asks too) or this client may not ask.
local function askFor(r)
    if not r or r.done or r.needAsked or not compareOn() then return end
    r.needAsked = true
    if ns.Get("sync.askUpgrades") == false or not ns.NeedAsk or not ns.NeedCanAsk or not ns.NeedCanAsk() then return end
    if ns.NeedOf and ns.NeedOf(r.item) then return end
    ns.NeedAsk({ r.item })
end

local function pctText(pct) return pct == 999 and L["neu"] or ("+%d %%"):format(pct) end

-- What the round's item is for whom: { up = { { name, pct, own } } (best first, 999 = empty slot),
-- wish = { names }, need = ns.NeedOf, own = ns.UpgradeOf of this client }.
local function upgradeInfo(r)
    local info = { up = {}, wish = {} }
    local need = ns.NeedOf and ns.NeedOf(r.item)
    info.need = need
    local me = ns.UnitFullName("player")
    local own = ns.UpgradeOf(r.link or r.item)
    info.own = own
    for _, e in ipairs(need and need.up or {}) do info.up[#info.up + 1] = { name = e.name, pct = e.pct } end
    if own and own.up and me then info.up[#info.up + 1] = { name = me, pct = own.pct or 999, own = true } end
    table.sort(info.up, function(a, b)
        if a.pct ~= b.pct then return a.pct > b.pct end
        return a.name:lower() < b.name:lower()
    end)
    local function wish(name)
        for _, n in ipairs(info.wish) do if ns.SameName(n, name) then return end end
        info.wish[#info.wish + 1] = name
    end
    for _, e in ipairs(need and need.wish or {}) do wish(e.name) end
    for _, e in ipairs(ns.WishersOf and ns.WishersOf(r.item, true) or {}) do wish(e.name) end
    return info
end

-- The roller's part: "+12%", "neu", "W", "ab 58" (the own row), coloured; "" when nothing is known.
local function rollerText(info, name)
    for _, e in ipairs(info.up) do
        if ns.SameName(e.name, name) then return UP_GREEN .. (e.pct == 999 and L["neu"] or ("+%d%%"):format(e.pct)) .. "|r" end
    end
    for _, n in ipairs(info.wish) do
        if ns.SameName(n, name) then return UP_BLUE .. "W|r" end
    end
    if info.own and ns.SameName(name, ns.UnitFullName("player")) then
        local short = ns.UpgradeShort(info.own)
        if short then return (info.own.later and UP_ORANGE or GREY) .. short .. "|r" end
    end
    return ""
end

-- "Upgrade für: Anna +25 %, du +12 % · Wunsch: Bob", "Für niemanden ein Upgrade (3 Antworten)",
-- "Upgrade für: warte auf Antworten" or, not asked, the own result alone.
local function upgradeLine(info)
    local parts = {}
    for i, e in ipairs(info.up) do
        if i > LINE_NAMES then
            parts[#parts + 1] = L["und %d weitere"]:format(#info.up - LINE_NAMES)
            break
        end
        parts[#parts + 1] = (e.own and L["du"] or e.name) .. " " .. pctText(e.pct)
    end
    local line
    if #parts > 0 then line = L["Upgrade für: %s"]:format(table.concat(parts, ", ")) end
    if #info.wish > 0 then
        local w = L["Wunsch: %s"]:format(table.concat(info.wish, ", ", 1, math.min(#info.wish, LINE_NAMES)))
        line = line and (line .. " · " .. w) or w
    end
    if line then return UP_GREEN .. line .. "|r" end
    local need = info.need
    if need and need.none > 0 then
        return GREY .. L["Für niemanden ein Upgrade (%d Antworten)"]:format(need.none) .. "|r"
    elseif need then
        return GREY .. L["Upgrade für: warte auf Antworten"] .. "|r"
    end
    return GREY .. L["Für dich kein Upgrade, die anderen wurden nicht gefragt."] .. "|r"
end

-- Whether the appearance hint shows for the round's item: green or blue, bound on pickup, and in a
-- dungeon (rolls.lookHint "dungeon") or anywhere ("all").
local function lookHint(r)
    local mode = ns.Get("rolls.lookHint") or "dungeon"
    if not r or mode == "off" then return false end
    local info = C_Item and C_Item.GetItemInfo
    if type(info) ~= "function" then return false end
    local ok, _, _, quality, _, _, _, _, _, _, _, _, _, _, bind = pcall(info, r.link or r.item)
    quality, bind = ok and ns.Plain(quality), ok and ns.Plain(bind)
    if (quality ~= QUALITY_GREEN and quality ~= QUALITY_BLUE) or bind ~= BIND_PICKUP then return false end
    if mode == "all" then return true end
    local _, kind = IsInInstance()
    return ns.Plain(kind) == "party"
end

-- The upgrade line and the appearance hint of a round (nil: none); returns the upgrade info for the
-- rows, nil when switched off.
local function showUpgrades(r)
    local info
    if r and compareOn() then
        local ok, res = pcall(upgradeInfo, r)
        if ok then info = res else report(res) end
    end
    if info then
        F.upLine:SetText(upgradeLine(info))
        F.upLine:Show()
    else
        F.upLine:SetText("")
        F.upLine:Hide()
    end
    local ok, look = pcall(lookHint, r)
    if not ok then report(look) end
    look = ok and look
    F.lookLine:SetText(look and LOOK_TEXT or "")
    if look then F.lookLine:Show() else F.lookLine:Hide() end
    return info
end

-- The prio line of a round and the officers' button; returns whether the item has a prio.
local function showPrio(r)
    local line = r and ns.LootPrioLine and ns.LootPrioLine(r.item)
    F.prioLine:SetText(line and (PRIO_GOLD .. line .. "|r") or "")
    F.prioLine:SetShown(line ~= nil)
    F.prioHit:SetShown(line ~= nil)
    F.prioBtn:SetShown((r ~= nil and ns.IsOfficerView() and ns.ShowPrioDialog ~= nil) and true or false)
    return line ~= nil
end

-- A roller's place in the prio: "P1" gold (by name), "P2" grey (by class), "" when not listed.
local function prioMark(r, e)
    if not ns.LootPrioRank then return "" end
    local rank, how = ns.LootPrioRank(r.item, e.name, e.class)
    if not rank then return "" end
    return (how == "name" and PRIO_GOLD or GREY) .. "P" .. rank .. "|r"
end

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
    F.namePick:SetValues(entryNames(), L["Anderer Name"])
    showHint(r)
    -- a bid needs the number only, need and greed the chips only
    local mode = r and r.mode
    F.valueEdit:SetShown(mode ~= "pr")
    F.valueEdit:SetMaxLetters(mode == "bid" and 6 or 3)
    F.msChip:SetShown(mode ~= "bid")
    F.osChip:SetShown(mode ~= "bid")
    if not r then
        header:SetText(L["Keine Roll-Runde. Alt-Klick auf ein Item im Lootfenster startet eine."])
        timer:SetText("")
        for i = 1, ROWS do rows[i]:Hide() end
        stopBtn:Disable()
        againBtn:Disable()
        F.resultBtn:Disable()
        showUpgrades(nil)
        showPrio(nil)
        return
    end
    header:SetText(r.link or r.name)
    local info = showUpgrades(r)
    local hasPrio = showPrio(r)
    if r.done then
        timer:SetText(r.winner and L["Gewinner: %s"]:format(r.winner) or (r.tie and L["Gleichstand"] or L["Beendet"]))
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
        if r.mode and ns.PointsRowText then
            local kind, value, up = ns.PointsRowText(r, e)
            row.kind:SetText(kind)
            row.value:SetText(value)
            row.up:SetText(up)
        else
            local plus = ns.PlusLabel(r, e.name)
            row.kind:SetText((e.rank or e.kind or "") .. (plus and (" " .. plus) or ""))
            row.value:SetText(tostring(e.value))
            row.up:SetText(info and rollerText(info, e.name) or "")
        end
        row.prio:SetText(hasPrio and prioMark(r, e) or "")
        row.hand:SetText(e.manual and L["Hand##Wurf"] or "")
        row.why:SetText(r.winner == e.name and ("|cff4fbf7a" .. L["Gewinner"] .. "|r") or "")
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
        row.up:SetText("")
        row.prio:SetText("")
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
    -- the top stays where it was before the upgrade lines made the window taller (toast above it)
    F:SetPoint("CENTER", 260, 52)

    -- the item on the left, the time (it sat under the close button) on the right of the same line
    header = text(F, T.FONT.body, 220)
    header:SetPoint("TOPLEFT", 12, -30)
    timer = text(F, T.FONT.big, 110)
    timer:SetPoint("TOPRIGHT", -12, -28)
    timer:SetJustifyH("RIGHT")
    -- officers: the item's loot prio in a small dialog
    F.prioBtn = W.Button(F, "Prio", 44, function()
        local r = ns.CurrentRoll() or ns.LastRoll()
        if r and ns.ShowPrioDialog then ns.ShowPrioDialog(r.link or r.item) end
    end, { height = 20 })
    W.FitChip(F.prioBtn, 44)
    F.prioBtn:SetPoint("TOPLEFT", 240, -28)
    F.prioBtn:Hide()
    -- the officers' prio, cut to the width; the tooltip holds all of it
    F.prioLine = text(F, T.FONT.text, ROW_W)
    F.prioLine:SetPoint("TOPLEFT", 12, PRIO_Y)
    F.prioHit = CreateFrame("Frame", nil, F)
    F.prioHit:SetSize(ROW_W, 14)
    F.prioHit:SetPoint("TOPLEFT", 12, PRIO_Y + 1)
    F.prioHit:EnableMouse(true)
    F.prioHit:SetScript("OnEnter", function(self)
        local r = ns.CurrentRoll() or ns.LastRoll()
        local p = r and ns.LootPrioOf and ns.LootPrioOf(r.item)
        if not p then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["Loot-Prio"], 1, 0.82, 0)
        for i, e in ipairs(p.prio) do GameTooltip:AddLine((ns.LootPrioText({ e }):gsub("^1%.", i .. ".")), 0.85, 0.85, 0.85, true) end
        if p.note ~= "" then GameTooltip:AddLine(L["Notiz: %s"]:format(p.note), 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    F.prioHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- who it is an upgrade for, then the appearance hint (two lines)
    F.upLine = text(F, T.FONT.text, ROW_W)
    F.upLine:SetPoint("TOPLEFT", 12, UP_Y)
    F.lookLine = text(F, T.FONT.hint, ROW_W)
    F.lookLine:SetPoint("TOPLEFT", 12, LOOK_Y)
    F.lookLine:SetWordWrap(true)
    F.lookLine:SetMaxLines(2)

    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, F)
        row:SetSize(ROW_W, ROW_H)
        row:SetPoint("TOPLEFT", 12, -LIST_TOP - (i - 1) * ROW_H)
        local rb = row:CreateTexture(nil, "BACKGROUND")
        rb:SetAllPoints()
        rb:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        row.name = text(row, T.FONT.text, 110)
        row.name:SetPoint("LEFT", 4, 0)
        row.kind = text(row, T.FONT.text, 44)
        row.kind:SetPoint("LEFT", 116, 0)
        row.value = text(row, T.FONT.text, 26)
        row.value:SetPoint("LEFT", 162, 0)
        -- the roller's upgrade ("+12%", "neu", "W"); in a points round the standing ("2200/1500")
        row.up = text(row, T.FONT.text, 52)
        row.up:SetPoint("LEFT", 190, 0)
        -- the roller's place in the officers' prio ("P1")
        row.prio = text(row, T.FONT.text, 26)
        row.prio:SetPoint("LEFT", 244, 0)
        row.hand = text(row, T.FONT.hint, 28)
        row.hand:SetPoint("LEFT", 270, 0)
        row.why = text(row, T.FONT.text, 44)
        row.why:SetPoint("LEFT", 300, 0)
        -- why a roll was not counted, on rows without a button
        row.reason = text(row, T.FONT.hint, ROW_W - 190 - 4)
        row.reason:SetPoint("LEFT", 190, 0)
        row.award = W.Button(row, L["Vergeben"], 64, function() if row.who then confirmGive(row.who) end end, { height = ROW_H })
        W.FitChip(row.award, 64)
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
    F.osChip = W.Chip(F, "OS", 30, function() setKind("OS") end)
    W.FitChip(F.msChip, 30)
    W.FitChip(F.osChip, 30)
    F.addBtn = W.Button(F, L["Eintragen"], 76, addEntry, { height = 20 })
    W.Row(F, { F.msChip, F.osChip, { F.addBtn, gap = 6 } }, 2, 180, ENTRY_Y)
    setKind("MS")

    hint = text(F, T.FONT.hint, WIDTH - 24)
    hint:SetPoint("TOPLEFT", 12, HINT_Y)
    hint:SetWordWrap(true)
    F.lockHint = hint
    F.note = hint

    stopBtn = W.Button(F, L["Stopp"], 80, function() ns.StopRoll() end)
    stopBtn:SetPoint("BOTTOMLEFT", 12, 10)

    againBtn = W.Button(F, L["Nochmal"], 80, function() ns.RerollTie() end)
    againBtn:SetPoint("LEFT", stopBtn, "RIGHT", 6, 0)

    F.resultBtn = W.Button(F, L["Ergebnis ansagen"], 120, function() ns.AnnounceRollResult(ns.CurrentRoll() or ns.LastRoll()) end)
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

ns.OnRollChanged = function(r)
    local ok, err = pcall(askFor, r or ns.CurrentRoll())
    if not ok then report(err) end
    refresh()
end
ns.Listen("NEED", function() refresh() end)
ns.Listen("LOOT_PRIO", function() refresh() end)
ns.Listen("SETTING", function(path)
    if path == "bis.compare" or path == "rolls.lookHint" or path == "bis.minGain" then refresh() end  -- l10n-ok: setting keys
end)

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

ns.RegisterSlash("rolls", { officer = true, desc = L["Roll-Fenster öffnen oder schließen"], run = function() ns.ToggleRollFrame() end })
