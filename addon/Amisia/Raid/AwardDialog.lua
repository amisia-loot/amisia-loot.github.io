-- Amisia award dialog: one item, one raid, a winner from a list of names, the kind and a note.
-- Opened by Alt+Shift-click on an item link, by the awards page and by /amisia award without an
-- item. Nothing is ever awarded without it. With the item in the open loot window and master loot
-- possible, "Vergeben" hands it out through master loot and the confirmation writes the award;
-- otherwise "Eintragen" writes it directly as a manual award into the chosen raid.
--
-- On the Forever client names can be secret during a boss fight; every name goes through
-- ns.Plain and a secret one is left out of the list.
--
-- In a DKP or EPGP guild a row under the note takes the award's cost (DKP spent or GP charged),
-- filled with the bid or the cost of the item's points round, else the GP formula (PointsRounds.lua);
-- the rows below move down by PTS_DY. Rolling guilds see the dialog as before.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local KINDS = { "MS", "OS", "SR", "-" }
local PREFILL = 10 * 60      -- a finished round this recent fills the winner in
local WIDTH, HEIGHT = 380, 268
local ASK_W = 60
local PTS_Y, PTS_DY = -120, 26          -- the cost row and how far it moves the rows under it

local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemIconByID = C_Item.GetItemIconByID

local D
local pointsOn             -- forward
local st = {}                -- s, item, link, winner, kind, note, pts, ptsTyped
local lootOpen = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function shortDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    if not d then return tostring(iso or "?") end
    return ns.FmtDay(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
end

local function newest()
    local act = ns.Active()
    if act then return act end
    local all = ns.Sessions()
    return all[#all]
end

-- The loot slot of the item in the open loot window, when master loot has candidates for it. Only
-- for the running recording: the confirmed hand-out is written there, so for another raid (or with
-- the recording stopped) the dialog enters the award directly instead.
local function lootSlot(item)
    if not item or not st.s or st.s ~= ns.Active() or not lootOpen or type(GiveMasterLoot) ~= "function" or type(GetMasterLootCandidate) ~= "function" then return nil end
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
-- loot candidates of the slot; secret values skipped, spellings of one character merged. Who wished
-- for the item on the website's list comes first (GuildWishes.lua, bis.guildAward), then who
-- answered upgrade or wish to "Wer braucht das?" (Need.lua).
local function names(s, slot, item)
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
    local values = ns.GuildWishAwardValues and ns.GuildWishAwardValues(item, out)
    if not values then
        values = {}
        for _, n in ipairs(out) do values[#values + 1] = { value = n, text = n } end
    end
    -- who answered "Wer braucht das?" with an upgrade or a wish comes right after the wishers
    if ns.NeedAwardValues then values = ns.NeedAwardValues(item, values) end
    -- the players of the officers' prio list (LootPrio.lua) before everyone, in their order
    if ns.LootPrioAwardValues then values = ns.LootPrioAwardValues(item, values) end
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

-- The newest finished round for the item with a winner, no older than PREFILL (ns.RoundsOf: also
-- one that ended before rounds of other items).
local function roundFor(item)
    for _, r in ipairs(ns.RoundsOf and ns.RoundsOf(item) or {}) do
        if r.done and r.winner and (time() - (r.started or 0)) <= PREFILL then return r end
    end
    return nil
end

local function itemIcon(id)
    local icon = GetItemInfoInstant and select(5, GetItemInfoInstant(id))
    if not icon and GetItemIconByID then icon = GetItemIconByID(id) end
    return icon
end

local function itemLabel()
    if not st.item then return "" end
    return st.link or ("Item " .. tostring(st.item))
end

-- Whether the dialog's raid was recorded with DKP or EPGP (the cost row shows): a raid that rolled
-- takes no cost afterwards.
pointsOn = function()
    return ns.PointsSession ~= nil and ns.PointsSession(st.s) ~= nil
end

-- The default cost of the dialog's item for its winner and kind (nil: none known).
local function defaultCost()
    if not st.item or not ns.PointsDefaultCost then return nil end
    if st.kind == "-" then
        local r = ns.PointsRoundOf and ns.PointsRoundOf(st.item)
        if not (r and r.mode == "bid" and st.winner) then return 0 end
    end
    return ns.PointsDefaultCost(st.item, st.winner, st.kind ~= "-" and st.kind or "MS", st.s)
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
        if kind ~= "-" and pointsOn() then p.pts = st.pts end
        return true
    end
    return false
end

-- Whether raid s still exists: the recording or a saved raid (it may be deleted while the dialog is open).
local function alive(s)
    if not s then return false end
    if s == ns.Active() then return true end
    for _, x in ipairs(ns.Sessions()) do
        if x == s then return true end
    end
    return false
end

-- Writes the award directly into the chosen raid, as a manual entry.
local function direct(name, to, hint)
    if not alive(st.s) then
        ns.msg(L["Der Raid wurde inzwischen gelöscht."])
        return false
    end
    local a, why = ns.AddAwardTo(st.s, {
        name = name, item = st.item, kind = to == "player" and st.kind or "-", src = sourceOf(st.s, st.item),
        t = time(), to = to, note = st.note, manual = true,
    })
    if not a then
        if why then ns.msg(why) end
        return false
    end
    if to == "player" and st.pts ~= nil and pointsOn() and ns.AwardCostOrSay then ns.AwardCostOrSay(st.s, a.id, st.pts) end
    local item = itemLabel()
    if to == "player" then
        ns.msg(L["Vergabe gespeichert: %s an %s (%s), von Hand eingetragen.%s"]:format(item, name, a.kind, hint and (" " .. hint) or ""))
    else
        local where = (lootOpen and ns.InLootWindow(st.item)) and L["im Lootfenster"] or L["in den Taschen"]
        ns.msg(L["Vergabe gespeichert: %s %s. Das Item liegt noch %s.%s"]:format(item, to == "bank" and L["an die Bank"] or L["zum Entzaubern"],
            where, hint and (" " .. hint) or ""))
    end
    return true
end

-- The note and the cost as they stand in the boxes, also when typed without Enter.
local function takeNote()
    st.note = ns.CleanNote(D.note:GetText())
    if D.pts:IsShown() then
        local n = tonumber(D.pts:GetText())
        st.pts = n and n >= 0 and n == math.floor(n) and n or nil
    end
end

local function give()
    if not st.item then return end
    takeNote()
    if not ns.FullName(st.winner) then
        ns.msg(L["Zuerst einen Gewinner wählen."])
        return
    end
    local slot = lootSlot(st.item)
    local done
    if slot then
        if candidate(slot, st.winner) then
            done = giveML(slot, st.winner, st.kind, st.note)
        else
            done = direct(st.winner, "player", L["%s ist kein Kandidat für dieses Item (zu weit weg?), das Item liegt noch im Lootfenster."]:format(st.winner))
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
    takeNote()
    local who = ns.Get(to == "bank" and "awards.bankName" or "awards.deName")
    local slot = lootSlot(st.item)
    local done
    if slot and type(who) == "string" and who ~= "" and candidate(slot, who) then
        done = giveML(slot, who, "-", st.note)
    else
        local hint
        if slot and type(who) == "string" and who ~= "" then hint = L["%s ist kein Kandidat für dieses Item."]:format(who) end
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
    if not link and GetItemInfo then
        local _, l = GetItemInfo(id)
        link = l
    end
    st.item, st.link = id, link
    st.ptsTyped = nil
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
    -- a dialog in the client's frame without a portrait, the title in its bar; everything below
    -- starts at y -32, under the bar
    D = W.Window("AmisiaAwardDialog", WIDTH, HEIGHT, { title = L["Vergabe"], strata = "FULLSCREEN_DIALOG" })
    D:SetPoint("CENTER", 0, 120)
    D:SetScript("OnHide", function() st = {} end)

    D.icon = D:CreateTexture(nil, "ARTWORK")
    D.icon:SetSize(22, 22)
    D.icon:SetPoint("TOPLEFT", 12, -32)
    D.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    D.itemText = W.Text(D, T.FONT.body, 180)
    D.itemText:SetPoint("LEFT", D.icon, "RIGHT", 6, 0)
    -- without an item: a box for a link (shift-click in the chat) or an item id
    D.itemEdit = W.LineEdit(D, 180, function(text)
        if setItem((text or ""):match("^%s*(.-)%s*$")) then
            refresh()
        elseif (text or "") ~= "" then
            ns.msg(L["Kein Item: Link per Shift-Klick einfügen oder Item-ID eingeben."])
        end
    end)
    D.itemEdit:SetPoint("LEFT", D.icon, "RIGHT", 6, 0)
    D.raidText = W.Text(D, T.FONT.text, 140)
    D.raidText:SetPoint("TOPRIGHT", -12, -36)
    D.raidText:SetJustifyH("RIGHT")

    local lab = W.Text(D, T.FONT.text, 56)
    lab:SetPoint("TOPLEFT", 12, -66)
    lab:SetText(L["Gewinner"])
    D.winner = W.Picker(D, 136, function(v)
        -- a typed name is cleaned like an edit on the page does it
        st.winner = ns.FullName(v)
        refresh()
    end)
    D.winner:SetPoint("LEFT", lab, "RIGHT", 4, 0)
    local artLab = W.Text(D, T.FONT.text, 24)
    artLab:SetPoint("LEFT", D.winner, "RIGHT", 8, 0)
    artLab:SetText(L["Art"])
    D.kinds = {}
    local prev = artLab
    for _, k in ipairs(KINDS) do
        local chip = W.Chip(D, k, 28, function()
            st.kind = k
            refresh()
        end)
        W.FitChip(chip, 28)
        chip:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        D.kinds[k] = chip
        prev = chip
    end

    local noteLab = W.Text(D, T.FONT.text, 56)
    noteLab:SetPoint("TOPLEFT", 12, -92)
    noteLab:SetText(L["Notiz"])
    D.note = W.LineEdit(D, 296, function(text)
        st.note = ns.CleanNote(text)
        refresh()
    end)
    D.note:SetPoint("LEFT", noteLab, "RIGHT", 4, 0)

    -- DKP or EPGP: the cost of the award
    D.ptsLabel = W.Text(D, T.FONT.text, 56)
    D.ptsLabel:SetPoint("TOPLEFT", 12, PTS_Y - 4)
    D.pts = W.LineEdit(D, 80, function(text)
        local n = tonumber(text)
        st.pts = n and n >= 0 and n == math.floor(n) and n or nil
        st.ptsTyped = true
        refresh()
    end)
    D.pts:SetPoint("LEFT", D.ptsLabel, "RIGHT", 4, 0)
    D.pts:SetNumeric(true)
    D.pts:SetMaxLetters(6)
    D.ptsHint = W.Text(D, T.FONT.hint, 208)
    D.ptsHint:SetPoint("LEFT", D.pts, "RIGHT", 8, 0)

    D.roll = W.Text(D, T.FONT.text, 356)
    D.roll:SetPoint("TOPLEFT", 12, -120)
    -- the officers' prio and note (LootPrio.lua), cut to the width
    D.prio = W.Text(D, T.FONT.text, 356)
    D.prio:SetPoint("TOPLEFT", 12, -140)
    -- "Upgrade für:" from the raiders' answers (Need.lua), cut to the width, every answer as tooltip
    D.need = W.Text(D, T.FONT.text, 356)
    D.need:SetPoint("TOPLEFT", 12, -160)
    D.needHit = CreateFrame("Frame", nil, D)
    D.needHit:SetSize(356, 16)
    D.needHit:SetPoint("TOPLEFT", 12, -159)
    D.needHit:EnableMouse(true)
    D.needHit:SetScript("OnEnter", function(self)
        local lines = st.item and ns.NeedLines and ns.NeedLines(st.item)
        if not lines then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["Upgrade für"], 1, 0.82, 0)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    D.needHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    D.ask = W.Button(D, L["Fragen"], ASK_W, function()
        if not st.item or not ns.NeedAsk then return end
        local qid, why = ns.NeedAsk({ st.item })
        if not qid and why then ns.msg(why) end
        refresh()
    end)
    D.ask:SetPoint("TOPRIGHT", -12, -156)
    D.hint = W.Text(D, T.FONT.hint, 356, true)
    D.hint:SetPoint("TOPLEFT", 12, -180)
    D.hint:SetHeight(40)
    D.hint:SetJustifyV("TOP")

    -- 90 + 60 + 90 + 86 and the gaps fit the 356 px between the margins
    D.give = W.Button(D, L["Vergeben"], 90, give)
    D.give:SetPoint("BOTTOMLEFT", 12, 12)
    D.bank = W.Button(D, "Bank", 60, function() giveTo("bank") end)
    D.bank:SetPoint("LEFT", D.give, "RIGHT", 6, 0)
    D.de = W.Button(D, L["Entzaubern"], 90, function() giveTo("de") end)
    D.de:SetPoint("LEFT", D.bank, "RIGHT", 6, 0)
    D.cancel = W.Button(D, L["Abbrechen"], 86, function() D:Hide() end)
    D.cancel:SetPoint("BOTTOMRIGHT", -12, 12)
end

-- Moves the rows under the note down by dy (the cost row) and the window with them.
local function place(dy)
    if D.dy == dy then return end
    D.dy = dy
    D:SetHeight(HEIGHT + dy)
    local function at(f, point, x, y)
        f:ClearAllPoints()
        f:SetPoint(point, x, y - dy)
    end
    at(D.roll, "TOPLEFT", 12, -120)
    at(D.prio, "TOPLEFT", 12, -140)
    at(D.need, "TOPLEFT", 12, -160)
    at(D.needHit, "TOPLEFT", 12, -159)
    at(D.ask, "TOPRIGHT", -12, -156)
    at(D.hint, "TOPLEFT", 12, -180)
end

-- The cost row: shown for DKP and EPGP, filled with the default until an officer types a number.
local function showPoints()
    local on = pointsOn()
    place(on and PTS_DY or 0)
    D.ptsLabel:SetShown(on)
    D.pts:SetShown(on)
    D.ptsHint:SetShown(on)
    if not on then return end
    local sys = ns.PointsSession(st.s).sys
    D.ptsLabel:SetText(sys == "epgp" and "GP" or "DKP")
    if not st.ptsTyped then st.pts = defaultCost() end
    if not D.pts:HasFocus() then D.pts:SetText(st.pts and tostring(st.pts) or "") end
    local e = st.winner and ns.PointsOf(st.winner, { sys = sys })
    if not e then
        D.ptsHint:SetText("")
    elseif sys == "epgp" then
        D.ptsHint:SetText(L["EP %d · GP %d · PR %s"]:format(e.a, e.b, ns.PointsPRText(e.pr)))
    else
        D.ptsHint:SetText(L["Stand: %d DKP"]:format(e.a))
    end
end

refresh = function()
    if not D or not D:IsShown() then return end
    local s = st.s
    showPoints()
    local slot = lootSlot(st.item)
    if st.item then
        D.itemEdit:Hide()
        D.itemText:Show()
        D.itemText:SetText(itemLabel())
        D.icon:SetTexture(itemIcon(st.item) or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        D.itemText:Hide()
        D.itemEdit:Show()
        if not D.itemEdit:HasFocus() then D.itemEdit:SetText("") end
        D.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    D.raidText:SetText(("Raid: %s, %s"):format(s.zone or "?", shortDate(s.date)))
    D.winner:SetValues(names(s, slot, st.item), L["Anderer Name"])
    D.winner:SetValue(st.winner)
    for _, k in ipairs(KINDS) do D.kinds[k]:SetOn(st.kind == k) end
    if not D.note:HasFocus() then D.note:SetText(st.note or "") end
    -- the round's result
    local r = st.item and roundFor(st.item)
    if r and r.mode and ns.PointsResultText then
        local e = r.rolls[r.winner]
        D.roll:SetText(e and L["Runde: %s (%s)"]:format(r.winner, ns.PointsResultText(r, e)) or "")
    elseif r then
        local e = r.rolls[r.winner]
        local list = ns.RollRanking(r)
        D.roll:SetText(("Roll: %s %d (%s) · +1: %d"):format(r.winner, e and e.value or 0, (list[1] and list[1].rank) or "?", ns.PlusCount(r.winner)))
    else
        D.roll:SetText(st.item and L["Kein Roll-Ergebnis für dieses Item."] or "")
    end
    D.prio:SetText(st.item and ns.LootPrioLine and ns.LootPrioLine(st.item) or "")
    -- who needs it: the answers, else "Fragen" while nothing was asked
    local needText = st.item and ns.NeedText and ns.NeedText(st.item)
    -- the button only where asking works (loot lead, own raid, officer rank, messages on)
    local canAsk = st.item ~= nil and ns.NeedCanAsk ~= nil and needText == nil and ns.NeedCanAsk() and true or false
    if needText then
        D.need:SetText(L["Upgrade für: %s"]:format(needText))
    else
        D.need:SetText(canAsk and L["Upgrade für: noch nicht gefragt"] or "")
    end
    D.need:SetWidth(canAsk and (356 - ASK_W - 6) or 356)
    D.needHit:SetWidth(canAsk and (356 - ASK_W - 6) or 356)
    if canAsk then D.ask:Show() else D.ask:Hide() end
    -- the way the hand-out goes
    if not st.item then
        D.hint:SetText(L["Item-Link per Shift-Klick einfügen oder Item-ID eingeben."])
    elseif slot then
        D.hint:SetText(L["Das Item liegt im Lootfenster: Vergeben geht über Master Loot, die Vergabe wird nach der Übergabe gespeichert."])
    else
        D.hint:SetText(L["Kein Lootfenster mit Master Loot: die Vergabe wird in den Raid eingetragen, die Übergabe machst du selbst."])
    end
    D.give:SetText(slot and L["Vergeben"] or L["Eintragen"])
    D.give:SetEnabled(st.item ~= nil and ns.FullName(st.winner) ~= nil)
    D.bank:SetEnabled(st.item ~= nil)
    D.de:SetEnabled(st.item ~= nil)
end

-- Opens the dialog for an item link or id (nil: the item is entered in the dialog) in raid s
-- (nil: the running recording, else the newest raid).
function ns.ShowAwardDialog(item, s)
    s = s or newest()
    if not s then
        ns.msg(L["Noch kein Raid aufgezeichnet: Vergaben brauchen einen Raid."])
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
-- answers to "Wer braucht das?" arrive
ns.Listen("NEED", function() if refresh then refresh() end end)
ns.Listen("LOOT_PRIO", function() if refresh then refresh() end end)

-- A link shift-clicked into the chat lands in the item box of an open dialog without an item. The
-- client calls ChatFrameUtil.InsertLink. ChatEdit_InsertLink is its deprecated alias, defined only
-- with the client's deprecation fallbacks switched on and bound to the unhooked function, so it
-- gets a hook of its own for callers that still use it.
local function onInsertLink(link)
    if D and D:IsShown() and not st.item and ns.ItemID(link) and setItem(link) then refresh() end
end
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
end
if type(ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
end

-- Alt+Shift-click on an item link opens the dialog, in the officer view and with awards.modClick.
if type(HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not (IsAltKeyDown() and IsShiftKeyDown()) then return end
        if not ns.Get("awards.modClick") or not ns.IsOfficerView() then return end
        if ns.ItemID(link) then ns.ShowAwardDialog(link) end
    end)
end
