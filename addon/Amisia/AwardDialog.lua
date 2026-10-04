-- Amisia award dialog: one item, one raid, a winner from a list of names, the kind and a note.
-- Opened by Alt+Shift-click on an item link, by the awards page and by /amisia award without an
-- item. Nothing is ever awarded without it. With the item in the open loot window and master loot
-- possible, "Vergeben" hands it out through master loot and the confirmation writes the award;
-- otherwise "Eintragen" writes it directly as a manual award into the chosen raid.
--
-- On the Forever client names can be secret during a boss fight; every name goes through
-- ns.Plain and a secret one is left out of the list.
local ADDON, ns = ...
local W = ns.W
local GOLD = W.GOLD

local KINDS = { "MS", "OS", "SR", "-" }
local PREFILL = 10 * 60      -- a finished round this recent fills the winner in
local WIDTH, HEIGHT = 380, 230

local D
local st = {}                -- s, item, link, winner, kind, note
local lootOpen = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function shortDate(iso)
    local m, d = tostring(iso or ""):match("^%d+%-(%d+)%-(%d+)$")
    return d and (d .. "." .. m .. ".") or tostring(iso or "?")
end

local function newest()
    local act = ns.Active()
    if act then return act end
    local all = ns.Sessions()
    return all[#all]
end

-- The loot slot of the item in the open loot window, when master loot has candidates for it.
local function lootSlot(item)
    if not item or not lootOpen or type(GiveMasterLoot) ~= "function" or type(GetMasterLootCandidate) ~= "function" then return nil end
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        if ns.ItemID(GetLootSlotLink(i)) == item then
            return GetMasterLootCandidate(i, 1) and i or nil
        end
    end
    return nil
end

-- The candidate index of a name for a loot slot, or nil.
local function candidate(slot, name)
    if not slot or not ns.FullName(name) then return nil end
    for i = 1, 40 do
        local c = ns.Plain(GetMasterLootCandidate(slot, i))
        if c and ns.SameName(c, name) then return i end
    end
    return nil
end

-- The names to pick from: the raid's members, in the recording the group too, and the master
-- loot candidates of the slot; secret values skipped, spellings of one character merged.
local function names(s, slot)
    local out = {}
    local function add(name)
        name = ns.FullName(ns.Plain(name))
        if not name then return end
        for i, o in ipairs(out) do
            if ns.SameName(o, name) then
                if #name > #o then out[i] = name end
                return
            end
        end
        out[#out + 1] = name
    end
    for name in pairs(s.members or {}) do add(name) end
    if s == ns.Active() then
        for i = 1, GetNumGroupMembers() or 0 do add((GetRaidRosterInfo(i))) end
    end
    if slot then
        for i = 1, 40 do
            local c = GetMasterLootCandidate(slot, i)
            if c == nil then break end
            add(c)
        end
    end
    table.sort(out)
    local values = {}
    for _, n in ipairs(out) do values[#values + 1] = { value = n, text = n } end
    return values
end

-- The source of an item in raid s: the loot window it was seen in, in the running recording else
-- the current target (as /amisia award does), else unknown.
local function sourceOf(s, item)
    for _, d in pairs(s.drops or {}) do
        if d.items and d.items[item] and d.src and d.src ~= "?" then return d.src end
    end
    if s == ns.Active() then return ns.LootSourceName(0) end
    return "?"
end

-- A finished round for the item with a winner, no older than PREFILL.
local function roundFor(item)
    local cur, last = ns.CurrentRoll(), ns.LastRoll()
    for _, r in ipairs({ cur or false, last or false }) do
        if r and r.item == item and r.done and r.winner and (time() - (r.started or 0)) <= PREFILL then return r end
    end
    return nil
end

local function itemLabel()
    if not st.item then return "" end
    return st.link or ("Item " .. tostring(st.item))
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------
-- Hands the item to a name through master loot and gives the kind and the note to the waiting
-- hand-out; true when the hand-out is on its way.
local function giveML(slot, name, kind, note)
    local before = ns.PendingAward(slot)
    ns.AwardFromRoll(name, st.item, st.link)
    local p = ns.PendingAward(slot)
    if p and p ~= before and p.item == st.item and ns.SameName(p.name, name) then
        p.kind, p.note = kind, note
        return true
    end
    return false
end

-- Writes the award directly into the chosen raid, as a manual entry.
local function direct(name, to, hint)
    local a, why = ns.AddAwardTo(st.s, {
        name = name, item = st.item, kind = to == "player" and st.kind or "-", src = sourceOf(st.s, st.item),
        t = time(), to = to, note = st.note, manual = true,
    })
    if not a then
        if why then ns.msg(why) end
        return false
    end
    local item = itemLabel()
    if to == "player" then
        ns.msg(("Vergabe gespeichert: %s an %s (%s), von Hand eingetragen.%s"):format(item, name, a.kind, hint and (" " .. hint) or ""))
    else
        local where = (lootOpen and ns.InLootWindow(st.item)) and "im Lootfenster" or "in den Taschen"
        ns.msg(("Vergabe gespeichert: %s %s. Das Item liegt noch %s.%s"):format(item, to == "bank" and "an die Bank" or "zum Entzaubern",
            where, hint and (" " .. hint) or ""))
    end
    return true
end

local function give()
    if not st.item then return end
    if not ns.FullName(st.winner) then
        ns.msg("Zuerst einen Gewinner wählen.")
        return
    end
    local slot = lootSlot(st.item)
    local done
    if slot then
        if candidate(slot, st.winner) then
            done = giveML(slot, st.winner, st.kind, st.note)
        else
            done = direct(st.winner, "player", ("%s ist kein Kandidat für dieses Item (zu weit weg?), das Item liegt noch im Lootfenster."):format(st.winner))
        end
    else
        done = direct(st.winner, "player")
    end
    if done then D:Hide() end
end

-- Bank or disenchant: master loot to the configured character when it is a candidate, else a
-- direct entry with the receiver "-".
local function giveTo(to)
    if not st.item then return end
    local who = ns.Get(to == "bank" and "awards.bankName" or "awards.deName")
    local slot = lootSlot(st.item)
    local done
    if slot and type(who) == "string" and who ~= "" and candidate(slot, who) then
        done = giveML(slot, who, "-", st.note)
    else
        local hint
        if slot and type(who) == "string" and who ~= "" then hint = ("%s ist kein Kandidat für dieses Item."):format(who) end
        done = direct("-", to, hint)
    end
    if done then D:Hide() end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local refresh

local function setItem(x)
    local id = ns.ItemID(x) or tonumber(x)
    if not id then return false end
    local link = (type(x) == "string" and x:find("|H", 1, true)) and x or nil
    if not link then
        local _, l = GetItemInfo(id)
        link = l
    end
    st.item, st.link = id, link
    -- the round's winner and his kind, when a finished round for this item is recent
    local r = roundFor(id)
    if r then
        st.winner = r.winner
        st.kind = ns.RollKind(id, r.winner)
        if st.kind == "-" then st.kind = "MS" end
    end
    return true
end

local function build()
    D = CreateFrame("Frame", "AmisiaAwardDialog", UIParent)
    D:SetSize(WIDTH, HEIGHT)
    D:SetPoint("CENTER", 0, 120)
    D:SetFrameStrata("FULLSCREEN_DIALOG")
    D:SetToplevel(true)
    D:SetClampedToScreen(true)
    D:SetMovable(true)
    D:EnableMouse(true)
    D:RegisterForDrag("LeftButton")
    D:SetScript("OnDragStart", function(self) self:StartMoving() end)
    D:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    D:SetScript("OnHide", function() st = {} end)
    D:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaAwardDialog") end
    W.Flat(D, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
    W.Border(D, GOLD[1], GOLD[2], GOLD[3], 0.6)

    local title = W.Text(D, "GameFontNormal", 200)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Vergabe")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local close = CreateFrame("Button", nil, D, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    D.icon = D:CreateTexture(nil, "ARTWORK")
    D.icon:SetSize(22, 22)
    D.icon:SetPoint("TOPLEFT", 12, -32)
    D.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    D.itemText = W.Text(D, "GameFontHighlight", 190)
    D.itemText:SetPoint("LEFT", D.icon, "RIGHT", 6, 0)
    -- without an item: a box for a link (shift-click in the chat) or an item id
    D.itemEdit = W.LineEdit(D, 190, function(text)
        if setItem((text or ""):match("^%s*(.-)%s*$")) then
            refresh()
        elseif (text or "") ~= "" then
            ns.msg("Kein Item: Link per Shift-Klick einfügen oder Item-ID eingeben.")
        end
    end)
    D.itemEdit:SetPoint("LEFT", D.icon, "RIGHT", 6, 0)
    D.raidText = W.Text(D, "GameFontHighlightSmall", 140)
    D.raidText:SetPoint("TOPRIGHT", -12, -36)
    D.raidText:SetJustifyH("RIGHT")

    local lab = W.Text(D, "GameFontHighlightSmall", 56)
    lab:SetPoint("TOPLEFT", 12, -66)
    lab:SetText("Gewinner")
    D.winner = W.Picker(D, 150, function(v)
        st.winner = v
        refresh()
    end)
    D.winner:SetPoint("LEFT", lab, "RIGHT", 4, 0)
    local artLab = W.Text(D, "GameFontHighlightSmall", 22)
    artLab:SetPoint("LEFT", D.winner, "RIGHT", 10, 0)
    artLab:SetText("Art")
    D.kinds = {}
    local prev = artLab
    for i, k in ipairs(KINDS) do
        local chip = W.Chip(D, k, 30, function()
            st.kind = k
            refresh()
        end)
        chip:SetPoint("LEFT", prev, "RIGHT", i == 1 and 2 or 3, 0)
        D.kinds[k] = chip
        prev = chip
    end

    local noteLab = W.Text(D, "GameFontHighlightSmall", 56)
    noteLab:SetPoint("TOPLEFT", 12, -92)
    noteLab:SetText("Notiz")
    D.note = W.LineEdit(D, 296, function(text)
        st.note = ns.CleanNote(text)
        refresh()
    end)
    D.note:SetPoint("LEFT", noteLab, "RIGHT", 4, 0)

    D.roll = W.Text(D, "GameFontHighlightSmall", 356)
    D.roll:SetPoint("TOPLEFT", 12, -120)
    D.hint = W.Text(D, "GameFontDisableSmall", 356, true)
    D.hint:SetPoint("TOPLEFT", 12, -140)
    D.hint:SetHeight(40)
    D.hint:SetJustifyV("TOP")

    D.give = W.Button(D, "Vergeben", 96, give)
    D.give:SetPoint("BOTTOMLEFT", 12, 12)
    D.bank = W.Button(D, "Bank", 70, function() giveTo("bank") end)
    D.bank:SetPoint("LEFT", D.give, "RIGHT", 6, 0)
    D.de = W.Button(D, "Entzaubern", 90, function() giveTo("de") end)
    D.de:SetPoint("LEFT", D.bank, "RIGHT", 6, 0)
    D.cancel = W.Button(D, "Abbrechen", 90, function() D:Hide() end)
    D.cancel:SetPoint("BOTTOMRIGHT", -12, 12)
end

refresh = function()
    if not D or not D:IsShown() then return end
    local s = st.s
    local slot = lootSlot(st.item)
    if st.item then
        D.itemEdit:Hide()
        D.itemText:Show()
        D.itemText:SetText(itemLabel())
        local icon = GetItemInfoInstant and select(5, GetItemInfoInstant(st.item))
        D.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        D.itemText:Hide()
        D.itemEdit:Show()
        if not D.itemEdit:HasFocus() then D.itemEdit:SetText("") end
        D.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    D.raidText:SetText(("Raid: %s, %s"):format(s.zone or "?", shortDate(s.date)))
    D.winner:SetValues(names(s, slot), "Anderer Name")
    D.winner:SetValue(st.winner)
    for _, k in ipairs(KINDS) do D.kinds[k]:SetOn(st.kind == k) end
    if not D.note:HasFocus() then D.note:SetText(st.note or "") end
    -- the round's result
    local r = st.item and roundFor(st.item)
    if r then
        local e = r.rolls[r.winner]
        local list = ns.RollRanking(r)
        D.roll:SetText(("Roll: %s %d (%s) · +1: %d"):format(r.winner, e and e.value or 0, (list[1] and list[1].rank) or "?", ns.PlusCount(r.winner)))
    else
        D.roll:SetText(st.item and "Kein Roll-Ergebnis für dieses Item." or "")
    end
    -- the way the hand-out goes
    if not st.item then
        D.hint:SetText("Item-Link per Shift-Klick einfügen oder Item-ID eingeben.")
    elseif slot then
        D.hint:SetText("Das Item liegt im Lootfenster: Vergeben geht über Master Loot, die Vergabe wird nach der Übergabe gespeichert.")
    else
        D.hint:SetText(("Kein Lootfenster mit Master Loot: die Vergabe wird in den Raid eingetragen, die Übergabe machst du selbst."))
    end
    D.give:SetText(slot and "Vergeben" or "Eintragen")
    D.give:SetEnabled(st.item ~= nil and ns.FullName(st.winner) ~= nil)
    D.bank:SetEnabled(st.item ~= nil)
    D.de:SetEnabled(st.item ~= nil)
end

-- Opens the dialog for an item link or id (nil: the item is entered in the dialog) in raid s
-- (nil: the running recording, else the newest raid).
function ns.ShowAwardDialog(item, s)
    s = s or newest()
    if not s then
        ns.msg("Noch kein Raid aufgezeichnet: Vergaben brauchen einen Raid.")
        return nil
    end
    if not D then build() end
    if D:IsShown() then D:Hide() end
    st = { s = s, kind = "-" }
    if item ~= nil then setItem(item) end
    D:Show()
    refresh()
    return D
end

ns.OnEvent("LOOT_OPENED", function()
    lootOpen = true
    refresh()
end)
ns.OnEvent("LOOT_CLOSED", function()
    lootOpen = false
    refresh()
end)

-- A link shift-clicked into the chat lands in the item box of an open dialog without an item.
if type(ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if D and D:IsShown() and not st.item and ns.ItemID(link) and setItem(link) then refresh() end
    end)
end

-- Alt+Shift-click on an item link opens the dialog, in the officer view and with awards.modClick.
if type(HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not (IsAltKeyDown() and IsShiftKeyDown()) then return end
        if not ns.Get("awards.modClick") or not ns.IsOfficerView() then return end
        if ns.ItemID(link) then ns.ShowAwardDialog(link) end
    end)
end
