-- The soft-reserve import window (F-108, spec 2026-10-17 part B): the pasted text (a softres.it
-- CSV, its code or "Name [item]" lines), the preview line, the raid members without a reservation
-- with "Erinnern" and "Im Raid posten", and the preview list: the hard reserves on top (with
-- "Ansagen"), then one row per raider with the name in class colour, the finding under it (name
-- unclear with the suggestions, wrong class, too many, fixed name, not in the raid) and the items as
-- icons in their quality colour. Nothing is stored before "Übernehmen". With an empty text the
-- loaded list is shown (a list shared by another officer has no text).
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.SRIMPORT
local GREY, ORANGE, RED, GREEN, GOLD = T.GREY, T.ORANGE, "|cffff5050", T.GREEN, T.GOLD_TEXT

local GetItemInfo = C_Item.GetItemInfo

local F, editBox, resultText, dateText, previewText
local previewGen = 0   -- the newest pending preview; older timers do nothing
local model            -- the shown preview (ns.SoftResPreview)

local TONE = { unclear = ORANGE, class = ORANGE, over = RED, renamed = GOLD, absent = GREY }
local QCOLOR = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 },
                 { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 } }

local function classColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local function quality(id)
    local known = AmisiaDB and AmisiaDB.itemNames and AmisiaDB.itemNames[id]
    local q = known and known.q
    if not q or q == 0 then
        local _, _, iq = GetItemInfo(id)
        q = iq or q
    end
    return q or 1
end

local function itemIcon(id)
    local icon = C_Item and C_Item.GetItemIconByID and ns.Plain(C_Item.GetItemIconByID(id)) or nil
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function itemLink(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. tostring(id))
end

-- The text in the box is the loaded list (or empty, which shows the loaded list): the reminders and
-- the post act on the loaded list only.
local function onLoaded() return model ~= nil and model.same end

---------------------------------------------------------------------------
-- The rows of the preview
---------------------------------------------------------------------------
local function buildRow(r)
    r.edges = W.Border(r, S.HARD[1], S.HARD[2], S.HARD[3], S.HARD[4])
    r.name = W.Text(r, T.FONT.body, S.STATUS_W)
    r.name:SetPoint("TOPLEFT", S.NAME_X, S.NAME_Y)
    r.status = W.Text(r, T.FONT.text, S.STATUS_W)
    r.status:SetPoint("TOPLEFT", S.NAME_X, S.STATUS_Y)
    r.chips = {}
    for i = 1, 2 do
        local chip = W.Chip(r, "", T.CHIP_W, function(self)
            if not self.from or not self.to then return end
            ns.RememberSoftResName(self.from, self.to)
            ns.msg(L["Soft-Reserves: %s heißt jetzt %s, auch in kommenden Listen."]:format(self.from, self.to))
        end)
        chip:SetOn(false)
        chip:Hide()
        r.chips[i] = chip
    end
    r.announce = W.Chip(r, L["Ansagen"], T.CHIP_W, function()
        local ok, why = ns.AnnounceSoftRes()
        resultText:SetText(ok and L["Ansage geht in den Raidchat."] or why or "")
    end)
    W.FitChip(r.announce, T.CHIP_W)
    r.announce:SetPoint("TOPLEFT", S.ANNOUNCE_X, S.ANNOUNCE_Y)
    r.announce:SetOn(false)
    W.Tooltip(r.announce, L["Ansagen"], L["Sagt im Raidchat, wie viele reserviert haben und wie man fragt, und die Hard-Reserves mit ihren Items."])
    r.icons = {}
    for i = 1, S.ICONS do
        local b = CreateFrame("Button", nil, r)
        b:SetSize(S.ICON, S.ICON)
        b:SetPoint("TOPLEFT", S.ICON_X + (i - 1) * (S.ICON + S.ICON_GAP), S.ICON_Y)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.edges = W.Border(b, 1, 1, 1, 1)
        b.count = W.Text(b, T.FONT.text)
        b.count:SetPoint("BOTTOMRIGHT", -1, 1)
        b.count:SetJustifyH("RIGHT")
        b:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(self.item))
            if self.extra then GameTooltip:AddLine(self.extra, 0.89, 0.72, 0.34, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if self.item and IsShiftKeyDown and IsShiftKeyDown() and ChatFrameUtil and ChatFrameUtil.InsertLink then
                ChatFrameUtil.InsertLink(itemLink(self.item))
            end
        end)
        r.icons[i] = b
    end
end

local function setIcons(r, items)
    local more = #items > S.ICONS and #items - S.ICONS + 1 or 0
    for i, b in ipairs(r.icons) do
        local it = items[i]
        if it then
            b.item, b.extra = it.item, it.extra
            b.tex:SetTexture(itemIcon(it.item))
            local c = QCOLOR[quality(it.item)] or QCOLOR[1]
            W.SetBorderColor(b.edges, c[1], c[2], c[3], 1)
            if more > 0 and i == S.ICONS then
                b.tex:SetVertexColor(0.35, 0.35, 0.35)
                b.count:SetText("+" .. more)
            else
                b.tex:SetVertexColor(1, 1, 1)
                b.count:SetText((it.n or 1) > 1 and (it.n .. "x") or "")
            end
            b:Show()
        else
            b.item, b.extra = nil, nil
            b:Hide()
        end
    end
end

-- Every field of a pooled row is set here, so nothing of an earlier entry stays.
local function fillRow(r, e)
    for _, edge in ipairs(r.edges) do edge:SetShown(e.kind == "hard") end
    for _, chip in ipairs(r.chips) do chip.from, chip.to = nil, nil; chip:Hide() end
    r.announce:Hide()
    r.status:SetWidth(S.STATUS_W)
    if e.kind == "hard" then
        r.name:SetText(RED .. L["Hard-Reserves"] .. "|r")
        r.announce:SetShown(ns.IsOfficerView() and onLoaded() and model.raid)
        local to, seen = {}, {}
        for _, h in ipairs(e.items) do
            if h.to ~= "" and not seen[h.to] then seen[h.to] = true; to[#to + 1] = h.to end
        end
        r.status:SetText(#to > 0 and (GREY .. L["für %s"]:format(table.concat(to, ", ")) .. "|r") or "")
        setIcons(r, e.items)
        return
    end
    r.name:SetText(classColored(e.name, e.class))
    local tone = e.tone and TONE[e.tone] or ""
    r.status:SetText(e.status and (tone .. e.status .. "|r") or "")
    if e.suggest and #e.suggest > 0 then
        local used = math.min(S.STATUS_W, r.status:GetStringWidth() + 4)
        r.status:SetWidth(used)
        local x = S.NAME_X + used + T.CHIP_GAP
        for i, name in ipairs(e.suggest) do
            local chip = r.chips[i]
            if not chip then break end
            chip.label:SetText(name)
            local w = W.FitChip(chip, nil, S.SUGGEST_MAX_W)
            if x + w > S.ICON_X - T.CHIP_GAP then break end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, S.SUGGEST_Y)
            chip.from, chip.to = e.name, name
            chip:Show()
            x = x + w + T.CHIP_GAP
        end
    end
    setIcons(r, e.items)
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function missingText(m)
    local parts = {}
    for _, p in ipairs(m.missing) do parts[#parts + 1] = classColored(p.name, p.class) end
    return table.concat(parts, ", ")
end

-- Fills everything below the text box from model (nil: nothing to show).
local function showModel()
    if not F then return end
    local m = model
    previewText:SetText(m and m.head or "")
    local miss = F.miss
    local officer = ns.IsOfficerView()
    if not m or m.err then
        miss:Hide()
        F.listHead:SetText("")
        F.listCount:SetText("")
        F.list:SetItems({})
        return
    end
    miss:Show()
    if not m.label then
        miss.title:SetText(L["Im Raid ohne Reserve"])
        miss.names:SetText(GREY .. L["Kein Raid zum Abgleichen."] .. "|r")
    elseif #m.missing == 0 then
        miss.title:SetText(L["Im Raid ohne Reserve"])
        miss.names:SetText(GREEN .. L["Alle im Raid haben reserviert."] .. "|r")
    else
        miss.title:SetText(L["Im Raid ohne Reserve · %d"]:format(#m.missing))
        miss.names:SetText(missingText(m))
    end
    -- reminders and the post: officers in a raid, on the loaded list
    local canAct = officer and m.raid and m.same
    local open = canAct and #ns.SoftResReminders() or 0
    miss.remind:SetText(L["Erinnern (%d)"]:format(open))
    W.FitChip(miss.remind, T.CHIP_W)
    miss.remind:SetEnabled(canAct and open > 0)
    miss.post:SetEnabled(canAct and true or false)
    miss.remind:SetShown(officer and m.raid)
    miss.post:SetShown(officer and m.raid)
    W.Row(miss, { miss.remind, miss.post }, T.CHIP_GAP, S.MISS_PAD, S.MISS_BUTTON_Y, { right = true, shown = true })
    F.listHead:SetText(L["Vorschau"])
    F.listCount:SetText(L["%d Raider##Anzahl"]:format(m.reservers))
    local items = {}
    if #m.hard > 0 then
        local hard = { kind = "hard", items = {} }
        for _, h in ipairs(m.hard) do
            hard.items[#hard.items + 1] = { item = h.item, n = 1, to = h.to,
                extra = h.to ~= "" and L["Hard-Reserve für %s"]:format(h.to) .. (h.note ~= "" and h.note ~= h.to and (" (" .. h.note .. ")") or "") or nil }
        end
        items[1] = hard
    end
    for _, r in ipairs(m.rows) do items[#items + 1] = r end
    F.list:SetItems(items)
end

local function updatePreview()
    if not F or not previewText then return end
    local text = editBox:GetText()
    local ok, m = pcall(ns.SoftResPreview, (text or ""):find("%S") and text or nil)
    model = ok and m or nil
    showModel()
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(m) end
    end
end
ns.SoftResImportPreview = updatePreview

-- Recomputes the preview 0.3 s after the last change of the text.
local function schedulePreview()
    previewGen = previewGen + 1
    local gen = previewGen
    C_Timer.After(0.3, function()
        if gen == previewGen then updatePreview() end
    end)
end

local function refresh()
    if not F or not F:IsShown() then return end
    local sr = AmisiaDB.softres
    if sr then
        local today = date("%Y-%m-%d")
        local from = sr.from and L[" von %s"]:format(sr.from) or ""
        dateText:SetText(sr.date == today
            and L["|cff4fbf7aListe von heute%s:|r %d Reservierungen"]:format(from, sr.count or 0)
            or L["|cffe0a344Liste vom %s%s:|r %d Reservierungen. Für einen neuen Raid neu einfügen."]:format(ns.SoftResShortDate(sr.date), from, sr.count or 0))
        if editBox:GetText() == "" then editBox:SetText(sr.raw or "") end
    else
        dateText:SetText(L["|cff8f86a3Keine Soft-Reserves.|r softres.it-CSV, Gargul-Code oder Zeilen wie 'Name [Item-Link]' einfügen."])
    end
    updatePreview()
end
ns.SoftResImportRefresh = refresh

local function build()
    -- a dialog in the client's frame without a portrait, the title in its bar; the side tab of the
    -- main window follows it
    F = W.Window("AmisiaSoftResFrame", S.W, S.H, { title = L["Soft-Reserves"], strata = "FULLSCREEN_DIALOG",
        onShow = refresh,
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end })
    F:SetPoint("CENTER", 0, 20)
    local pad, inner = T.WINDOW_PAD, S.W - 2 * T.WINDOW_PAD

    dateText = W.Text(F, T.FONT.text, inner)
    dateText:SetPoint("TOPLEFT", pad, S.DATE_Y)

    -- the pasted text: the shared edit area (an inset, the thin bar inside its right edge; a click
    -- anywhere in it focuses the text)
    local boxBg = W.EditArea(F)
    boxBg:SetPoint("TOPLEFT", pad, S.BOX_Y)
    boxBg:SetSize(inner, S.BOX_H)
    editBox = boxBg.box
    editBox:SetScript("OnTextChanged", schedulePreview)

    -- the preview line: what the text holds and the check against the raid, two lines at most
    previewText = W.Text(F, T.FONT.text, inner, true)
    previewText:SetPoint("TOPLEFT", pad, S.PREVIEW_Y)
    previewText:SetHeight(S.TEXT_H)
    previewText:SetJustifyV("TOP")
    previewText:SetMaxLines(2)
    previewText:SetTextColor(T.GOLD[1], T.GOLD[2], T.GOLD[3])

    -- the raid members without a reservation
    local miss = W.Inset(F)
    miss:SetPoint("TOPLEFT", pad, S.MISS_Y)
    miss:SetSize(inner, S.MISS_H)
    miss.title = W.Text(miss, T.FONT.head, 240)
    miss.title:SetPoint("TOPLEFT", S.MISS_PAD, S.MISS_TITLE_Y)
    miss.names = W.Text(miss, T.FONT.text, inner - 2 * S.MISS_PAD, true)
    miss.names:SetPoint("TOPLEFT", S.MISS_PAD, S.MISS_NAMES_Y)
    miss.names:SetHeight(S.TEXT_H)
    miss.names:SetJustifyV("TOP")
    miss.names:SetMaxLines(2)
    miss.remind = W.Button(miss, L["Erinnern"], 110, function() ns.ConfirmSoftResReminders() end)
    miss.post = W.Button(miss, L["Im Raid posten"], 120, function()
        local n, why = ns.PostSoftResSummary()
        if not n and why then ns.msg(why) end
    end)
    W.FitChip(miss.post, 120)
    W.Tooltip(miss.remind, L["Erinnern"], L["Flüstert jedem im Raid ohne Reservierung einmal pro Liste, nach einer Rückfrage. Gilt der übernommenen Liste: erst übernehmen."])
    W.Tooltip(miss.post, L["Im Raid posten"], L["Wie viele reserviert haben und wer noch nicht, in den Schlachtzugschat. Gilt der übernommenen Liste: erst übernehmen."])
    F.miss = miss

    -- the preview list
    F.listHead = W.Text(F, T.FONT.head, 200)
    F.listHead:SetPoint("TOPLEFT", pad, S.HEAD_Y)
    F.listCount = W.Text(F, T.FONT.head, 200)
    F.listCount:SetPoint("TOPRIGHT", -pad - T.SCROLL_ROOM, S.HEAD_Y)
    F.listCount:SetJustifyH("RIGHT")
    F.list = W.List(F, S.ROWS, S.ROW_H, buildRow, fillRow)
    F.list:SetPoint("TOPLEFT", pad, S.LIST_Y)
    F.list:SetWidth(inner - T.SCROLL_ROOM)

    resultText = W.Text(F, T.FONT.text, inner, true)
    resultText:SetPoint("BOTTOMLEFT", pad, S.RESULT_Y)
    resultText:SetHeight(S.TEXT_H)
    resultText:SetJustifyV("TOP")
    resultText:SetMaxLines(2)

    local apply = W.Button(F, L["Übernehmen"], 110, function()
        local count, bad, err, extra = ns.SetSoftRes(editBox:GetText())
        local text
        if err then
            text = err
        elseif extra and extra.src == "code" then
            text = L["%d Reservierungen übernommen, Hard-Reserves: %d."]:format(count, extra.hardCount)
        else
            text = L["%d Reservierungen übernommen, %d Zeilen nicht erkannt."]:format(count, #bad)
                .. (#bad > 0 and L[" Erste: %s"]:format(bad[1]:sub(1, 40)) or "")
        end
        if not err and ns.SoftResAfterImport() then text = text .. " " .. L["Mit der Gruppe geteilt."] end
        resultText:SetText(text)
        refresh()
    end)
    apply:SetPoint("BOTTOMLEFT", pad, S.BUTTON_Y)

    local clear = W.Button(F, L["Leeren"], 90, function()
        ns.ClearSoftRes()
        editBox:SetText("")
        previewText:SetText("")
        resultText:SetText(L["Liste geleert."])
        refresh()
    end)
    clear:SetPoint("LEFT", apply, "RIGHT", 6, 0)
    F.editBox, F.resultText, F.dateText, F.applyBtn, F.clearBtn, F.previewText, F.box = editBox, resultText, dateText, apply, clear, previewText, boxBg
    ns.SoftResFrame = F
end

function ns.ToggleSoftResFrame()
    if not F then build() end
    if F:IsShown() then F:Hide() else F:Show() end
end

-- the roster or the list changed: the open window shows it (a burst makes one update)
local pending = false
local function later()
    if pending or not (F and F:IsShown()) then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        if F and F:IsShown() then updatePreview() end
    end)
end
ns.OnEvent("GROUP_ROSTER_UPDATE", later)
ns.SoftResImportChanged = later
