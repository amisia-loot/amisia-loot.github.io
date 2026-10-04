-- Awards: every hand-out of a raid for officers, to look through, change, delete and take back;
-- raiders see their own items. Changes apply on the click and land on the undo stack.
local ADDON, ns = ...
local W = ns.W
local GOLD = W.GOLD
local ROWS, ROW_H = 12, 22
local GREY = "|cff8f86a3"
local KINDS = { "MS", "OS", "SR", "-" }
local MAX_SUGGEST = 3
local TO_TEXT = { bank = "Bank", de = "Entzaubern" }

local page
local chosenRaid        -- session id, "all", or nil for the default
local chosenId          -- id of the award in the edit panel
local query = ""

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- The raids newest first, the running recording in front.
local function ordered()
    local src, out, act = ns.Sessions(), {}, ns.Active()
    if act then out[1] = act end
    for i = #src, 1, -1 do
        if src[i] ~= act then out[#out + 1] = src[i] end
    end
    return out
end

local function byId(id)
    for _, s in ipairs(ns.Sessions()) do
        if s.id == id then return s end
    end
    return nil
end

-- "02.10." from a raid's "2026-10-02".
local function shortDate(iso)
    local m, d = tostring(iso or ""):match("^%d+%-(%d+)%-(%d+)$")
    return d and (d .. "." .. m .. ".") or tostring(iso or "?")
end

local function raidText(s)
    return ("%s%s, %s"):format(s == ns.Active() and "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:12:12:0:0|t " or "",
        s.zone or "?", shortDate(s.date))
end

-- The raid the page works on: the chosen one, else the recording, else the newest.
local function chosen()
    if chosenRaid == "all" then return nil, true end
    local s = chosenRaid and byId(chosenRaid)
    if not s then
        s = ordered()[1]
        chosenRaid = s and s.id or nil
    end
    return s, false
end

local function quality(id)
    local known = AmisiaDB and AmisiaDB.itemNames and AmisiaDB.itemNames[id]
    local q = known and known.q
    if not q or q == 0 then
        local _, _, iq = GetItemInfo(id)
        q = iq or q
    end
    return q or 0
end

local QCOLOR = { [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80" }
local function itemText(id)
    return ("|cff%s%s|r"):format(QCOLOR[quality(id)] or "ffffff", ns.ItemName(id))
end

local function itemLink(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. tostring(id))
end

-- The member record of a name: the exact spelling, else the same character by ns.SameName.
-- known is true only for the exact (case-insensitive) spelling.
local function memberOf(s, name)
    local lower = tostring(name or ""):lower()
    for key, m in pairs(s.members or {}) do
        if key:lower() == lower then return m, true end
    end
    for key, m in pairs(s.members or {}) do
        if ns.SameName(key, name) then return m, false end
    end
    return nil, false
end

local function classColor(m)
    local c = m and m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    return c and c.colorStr or "ffffffff"
end

local function winnerText(s, a)
    if a.to == "bank" or a.to == "de" then
        local who = (a.name and a.name ~= "-") and (" (" .. a.name .. ")") or ""
        return GREY .. TO_TEXT[a.to] .. who .. "|r"
    end
    local m, known = memberOf(s, a.name)
    return ("|c%s%s|r%s"):format(classColor(m), a.name, known and "" or " |cffe2b857?|r")
end

local function matches(s, a, q)
    if q == "" then return true end
    local parts = { a.name, ns.ItemName(a.item), a.src, a.note }
    for _, p in ipairs(parts) do
        if type(p) == "string" and p:lower():find(q, 1, true) then return true end
    end
    return false
end

-- The rows of the list: { s, a } for every living award of the chosen raid, or of all raids
-- newest first, that the search leaves.
local function entries()
    local s, all = chosen()
    local raids = all and ordered() or { s }
    local out, q = {}, query:lower()
    for _, r in ipairs(raids) do
        if r then
            for _, a in ipairs(r.awards or {}) do
                if matches(r, a, q) then out[#out + 1] = { s = r, a = a } end
            end
        end
    end
    return out, all
end

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or "GameFontNormalSmall", w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

-- Names to pick a winner from: the raid's members, in the recording also the group, merged by
-- ns.SameName and sorted.
local function winnerNames(s)
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
    table.sort(out)
    local values = {}
    for _, n in ipairs(out) do values[#values + 1] = { value = n, text = n } end
    return values
end

-- The raid an addition goes to: the chosen one, with "Alle Raids" the recording or the newest.
local function targetRaid()
    local s = chosen()
    return s or ordered()[1]
end

local function editTarget()
    local s, all = chosen()
    if not chosenId then return nil end
    if all then
        for _, r in ipairs(ordered()) do
            local a, _, inGone = ns.FindAward(r, chosenId)
            if a and not inGone then return r, a end
        end
        return nil
    end
    if not s then return nil end
    local a, _, inGone = ns.FindAward(s, chosenId)
    if a and not inGone then return s, a end
    return nil
end

local function edit(fields)
    local s, a = editTarget()
    if not s then return end
    local ok, why = ns.EditAward(s, a.id, fields)
    if not ok and why then ns.msg(why) end
end

---------------------------------------------------------------------------
-- Officer view
---------------------------------------------------------------------------
local function buildOfficer(parent)
    local O = CreateFrame("Frame", nil, parent)
    O:SetAllPoints(parent)

    O.raid = W.Picker(O, 210, function(v)
        chosenRaid = v
        chosenId = nil
        ns.Refresh()
    end)
    O.raid:SetPoint("TOPLEFT", 0, -2)
    O.search = W.LineEdit(O, 200, function(text)
        query = (text or ""):match("^%s*(.-)%s*$")
        ns.Refresh()
    end)
    O.search:SetPoint("LEFT", O.raid, "RIGHT", 8, 0)
    O.searchHint = W.Text(O, "GameFontDisableSmall", 190)
    O.searchHint:SetPoint("LEFT", O.search, "LEFT", 6, 0)
    O.searchHint:SetText("Suche: Name oder Item")
    O.search:HookScript("OnEditFocusGained", function() O.searchHint:Hide() end)
    O.search:HookScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" and not self:HasFocus() then O.searchHint:Show() else O.searchHint:Hide() end
    end)
    O.undo = W.Button(O, "Rückgängig", 100, function()
        local text = ns.UndoAward()
        ns.msg(text and ("Rückgängig: %s."):format(text) or "Nichts rückgängig zu machen.")
        ns.Refresh()
    end)
    O.undo:SetPoint("TOPRIGHT", 0, -1)
    O.undo:SetScript("OnEnter", function(self)
        local label = ns.UndoLabel()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Rückgängig", 1, 0.82, 0)
        GameTooltip:AddLine(label or "Nichts rückgängig zu machen.", 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    O.undo:SetScript("OnLeave", function() GameTooltip:Hide() end)
    O.add = W.Button(O, "Hinzufügen", 100, function()
        local s = targetRaid()
        if not s then
            ns.msg("Noch kein Raid aufgezeichnet.")
        elseif ns.ShowAwardDialog then
            ns.ShowAwardDialog(nil, s)
        else
            ns.msg("Vergaben von Hand: /amisia award <Name> <Item-Link oder ID> [ms|os|sr]")
        end
    end)
    O.add:SetPoint("RIGHT", O.undo, "LEFT", -6, 0)

    O.head = W.Text(O, "GameFontDisableSmall", 590)
    O.head:SetPoint("TOPLEFT", 6, -28)

    local head = CreateFrame("Frame", nil, O)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, -44)
    head:SetPoint("TOPRIGHT", 0, -44)
    col(head, 6, 44, "Zeit")
    col(head, 52, 200, "Item")
    col(head, 256, 140, "Gewinner")
    col(head, 400, 30, "Art")
    col(head, 434, 24, "+1")
    col(head, 462, 136, "Quelle")

    O.list = W.List(O, ROWS, ROW_H, function(r)
        r.sel = W.Flat(r, GOLD[1], GOLD[2], GOLD[3], 0.18, "BORDER")
        r.time = col(r, 6, 44, nil, "GameFontHighlightSmall")
        r.itemText = col(r, 52, 200, nil, "GameFontHighlightSmall")
        r.name = col(r, 256, 140, nil, "GameFontHighlightSmall")
        r.kind = col(r, 400, 30, nil, "GameFontHighlightSmall")
        r.plus = col(r, 434, 24, nil, "GameFontHighlightSmall")
        r.src = col(r, 462, 136, nil, "GameFontHighlightSmall")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if not e then return end
            if IsShiftKeyDown and IsShiftKeyDown() then
                if type(ChatEdit_InsertLink) == "function" then ChatEdit_InsertLink(itemLink(e.a.item)) end
                return
            end
            chosenId = e.a.id
            ns.Refresh()
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not e or not GameTooltip.SetHyperlink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(e.a.item))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        local a = e.a
        r.time:SetText(date(O.list.all and "%d.%m." or "%H:%M", a.t or 0))
        r.itemText:SetText(itemText(a.item))
        r.name:SetText(winnerText(e.s, a))
        r.kind:SetText(a.kind or "-")
        r.plus:SetText((a.kind == "MS" and (a.to == nil or a.to == "player")) and tostring(ns.PlusCount(a.name)) or "")
        r.src:SetText(a.src or "?")
        if a.id == chosenId then r.sel:Show() else r.sel:Hide() end
    end)
    O.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    O.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)

    -- the edit panel under the list
    local E = CreateFrame("Frame", nil, O)
    E:SetPoint("TOPLEFT", O.list, "BOTTOMLEFT", 0, -6)
    E:SetPoint("TOPRIGHT", O.list, "BOTTOMRIGHT", 0, -6)
    E:SetHeight(120)
    E.title = W.Text(E, "GameFontNormal", 590)
    E.title:SetPoint("TOPLEFT", 6, -2)
    local lab = W.Text(E, "GameFontHighlightSmall", 60)
    lab:SetPoint("TOPLEFT", 6, -26)
    lab:SetText("Gewinner")
    E.winner = W.Picker(E, 150, function(v)
        edit({ name = v, to = "player" })
    end)
    E.winner:SetPoint("LEFT", lab, "RIGHT", 4, 0)
    local artLab = W.Text(E, "GameFontHighlightSmall", 24)
    artLab:SetPoint("LEFT", E.winner, "RIGHT", 12, 0)
    artLab:SetText("Art")
    E.kinds = {}
    local prev = artLab
    for i, k in ipairs(KINDS) do
        local chip = W.Chip(E, k, 32, function() edit({ kind = k }) end)
        chip:SetPoint("LEFT", prev, "RIGHT", i == 1 and 4 or 3, 0)
        E.kinds[k] = chip
        prev = chip
    end
    local noteLab = W.Text(E, "GameFontHighlightSmall", 32)
    noteLab:SetPoint("LEFT", prev, "RIGHT", 12, 0)
    noteLab:SetText("Notiz")
    E.note = W.LineEdit(E, 180, function(text) edit({ note = text }) end)
    E.note:SetPoint("LEFT", noteLab, "RIGHT", 4, 0)

    E.bank = W.Button(E, "Bank", 90, function()
        local _, a = editTarget()
        if not a then return end
        if a.to == "bank" then E.winner:Open() else edit({ to = "bank" }) end
    end)
    E.bank:SetPoint("TOPLEFT", 6, -52)
    E.de = W.Button(E, "Entzaubern", 90, function()
        local _, a = editTarget()
        if not a then return end
        if a.to == "de" then E.winner:Open() else edit({ to = "de" }) end
    end)
    E.de:SetPoint("LEFT", E.bank, "RIGHT", 6, 0)
    E.del = W.Button(E, "Löschen", 90, function()
        local s, a = editTarget()
        if not s then return end
        local ok, why = ns.DeleteAward(s, a.id)
        if not ok and why then ns.msg(why) end
        chosenId = nil
        ns.Refresh()
    end)
    E.del:SetPoint("LEFT", E.de, "RIGHT", 6, 0)
    E.status = W.Text(E, "GameFontDisableSmall")
    E.status:SetPoint("LEFT", E.del, "RIGHT", 12, 0)
    E.status:SetJustifyH("RIGHT")
    E.status:SetPoint("RIGHT", -6, 0)

    E.hint = W.Text(E, "GameFontHighlightSmall", 590)
    E.hint:SetPoint("TOPLEFT", 6, -80)
    E.chips = {}
    for i = 1, MAX_SUGGEST * 2 do
        local chip = W.Chip(E, "", 60)
        if i == 1 then chip:SetPoint("TOPLEFT", 6, -98) else chip:SetPoint("LEFT", E.chips[i - 1], "RIGHT", 4, 0) end
        chip:SetScript("OnClick", function(self)
            local s, a = editTarget()
            if not s or not self.target then return end
            if self.all then
                ns.RenameAwards(s, a.name, self.target)
            else
                edit({ name = self.target })
            end
        end)
        chip:Hide()
        E.chips[i] = chip
    end
    E:Hide()
    O.edit = E
    return O
end

local function fillEdit(E)
    local s, a = editTarget()
    if not s then
        chosenId = nil
        E:Hide()
        return
    end
    E:Show()
    E.title:SetText(("%s · %s · %s"):format(itemText(a.item), date("%H:%M", a.t or 0), a.src or "?"))
    E.winner:SetValues(winnerNames(s), "Anderer Name")
    E.winner:SetValue(a.to == "player" and a.name or ((a.name and a.name ~= "-") and a.name or nil))
    for _, k in ipairs(KINDS) do E.kinds[k]:SetOn(a.kind == k) end
    if not E.note:HasFocus() then E.note:SetText(a.note or "") end
    E.bank:SetText(a.to == "bank" and "An Spieler" or "Bank")
    E.de:SetText(a.to == "de" and "An Spieler" or "Entzaubern")
    local parts = {}
    if a.edited then
        parts[#parts + 1] = ("geändert %s%s"):format(date("%H:%M", a.edited), a.orig and (", zuerst an " .. a.orig) or "")
    elseif a.orig then
        parts[#parts + 1] = "zuerst an " .. a.orig
    end
    if a.manual then parts[#parts + 1] = "von Hand eingetragen" end
    if a.note then parts[#parts + 1] = ("Notiz %d/60"):format(#a.note) end
    E.status:SetText(table.concat(parts, " · "))
    -- the name hint: a player's name outside the members, with the members it may mean
    local _, known = memberOf(s, a.name)
    local chips = E.chips
    if a.to ~= "player" or known then
        E.hint:Hide()
        for _, c in ipairs(chips) do c:Hide() end
        return
    end
    local sug = ns.NameSuggestions(s, a.name)
    local same = 0
    for _, o in ipairs(s.awards or {}) do
        if o.name == a.name then same = same + 1 end
    end
    E.hint:Show()
    E.hint:SetText(("Hinweis: \"%s\" steht nicht in der Anwesenheit.%s"):format(a.name, #sug > 0 and " Gemeint:" or ""))
    local i = 0
    for _, name in ipairs(sug) do
        if i >= #chips then break end
        i = i + 1
        local c = chips[i]
        c.label:SetText(name)
        c:SetWidth(c.label:GetStringWidth() + 16)
        c.target, c.all = name, false
        c:SetOn(false)
        c:Show()
        if same > 1 and i < #chips then
            i = i + 1
            local all = chips[i]
            all.label:SetText(("alle %d"):format(same))
            all:SetWidth(all.label:GetStringWidth() + 16)
            all.target, all.all = name, true
            all:SetOn(false)
            all:Show()
        end
    end
    for j = i + 1, #chips do chips[j]:Hide() end
end

local EXPORT_TEXT = { new = "Raid nicht exportiert", changed = "Raid geändert seit dem Export", done = "Raid exportiert" }

local function refreshOfficer(O)
    local values = {}
    for _, s in ipairs(ordered()) do values[#values + 1] = { value = s.id, text = raidText(s) } end
    values[#values + 1] = { value = "all", text = "Alle Raids" }
    O.raid:SetValues(values)
    local s, all = chosen()
    O.raid:SetValue(all and "all" or (s and s.id) or nil)
    if not O.search:HasFocus() then O.search:SetText(query) end
    if query == "" and not O.search:HasFocus() then O.searchHint:Show() else O.searchHint:Hide() end
    local list = entries()
    O.list.all = all
    O.list:SetItems(list)
    -- the head line: counts and the export state
    local n, bank, de, raids = 0, 0, 0, {}
    for _, e in ipairs(list) do
        n = n + 1
        if e.a.to == "bank" then bank = bank + 1 elseif e.a.to == "de" then de = de + 1 end
        raids[e.s] = true
    end
    local parts = { ("%d Vergaben"):format(n) }
    if bank > 0 then parts[#parts + 1] = ("%d Bank"):format(bank) end
    if de > 0 then parts[#parts + 1] = ("%d Entzaubern"):format(de) end
    if all then
        local count = 0
        for _ in pairs(raids) do count = count + 1 end
        parts[#parts + 1] = ("in %d Raids"):format(count)
    elseif s then
        parts[#parts + 1] = EXPORT_TEXT[ns.ExportState(s)] or ""
    else
        parts = { "Noch kein Raid aufgezeichnet." }
    end
    O.head:SetText(table.concat(parts, " · "))
    O.undo:SetEnabled(ns.UndoLabel() ~= nil)
    fillEdit(O.edit)
end

---------------------------------------------------------------------------
-- Raider view
---------------------------------------------------------------------------
-- My items of every saved raid: the loot lines with my name and my own awards, one row per
-- item and raid, newest raid first.
local function myItems()
    local me = ns.UnitFullName("player")
    local out = {}
    if not me then return out end
    for _, s in ipairs(ordered()) do
        local seen = {}
        local function add(item, kind)
            local row = seen[item]
            if row then
                if kind and kind ~= "-" then row.kind = kind end
                return
            end
            row = { s = s, item = item, kind = kind }
            seen[item] = row
            out[#out + 1] = row
        end
        for _, l in ipairs(s.items or {}) do
            if ns.SameName(l.name, me) then add(l.item, nil) end
        end
        for _, a in ipairs(s.awards or {}) do
            if (a.to == nil or a.to == "player") and ns.SameName(a.name, me) then add(a.item, a.kind) end
        end
    end
    return out
end

local function buildRaider(parent)
    local R = CreateFrame("Frame", nil, parent)
    R:SetAllPoints(parent)
    R.title = W.Text(R, "GameFontNormal", 300)
    R.title:SetPoint("TOPLEFT", 0, -2)
    R.title:SetText("Deine Items")
    local head = CreateFrame("Frame", nil, R)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, -24)
    head:SetPoint("TOPRIGHT", 0, -24)
    col(head, 6, 60, "Datum")
    col(head, 70, 230, "Item")
    col(head, 306, 200, "Raid")
    col(head, 510, 40, "Art")
    R.list = W.List(R, ROWS, ROW_H, function(r)
        r.date = col(r, 6, 60, nil, "GameFontHighlightSmall")
        r.itemText = col(r, 70, 230, nil, "GameFontHighlightSmall")
        r.zone = col(r, 306, 200, nil, "GameFontHighlightSmall")
        r.kind = col(r, 510, 40, nil, "GameFontHighlightSmall")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if e and IsShiftKeyDown and IsShiftKeyDown() and type(ChatEdit_InsertLink) == "function" then
                ChatEdit_InsertLink(itemLink(e.item))
            end
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not e or not GameTooltip.SetHyperlink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(e.item))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        r.date:SetText(shortDate(e.s.date))
        r.itemText:SetText(itemText(e.item))
        r.zone:SetText(e.s.zone or "?")
        r.kind:SetText((e.kind and e.kind ~= "-") and e.kind or "")
    end)
    R.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    R.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
    R.text = W.Text(R, "GameFontDisableSmall", 590, true)
    R.text:SetPoint("TOPLEFT", R.list, "BOTTOMLEFT", 6, -10)
    R.text:SetText("Vergaben anderer siehst du auf der Amisia-Loot-Seite.")
    return R
end

---------------------------------------------------------------------------
-- The page, the card and the commands
---------------------------------------------------------------------------
function ns.AwardsPageFrame() return page end

-- Opens the page on one raid.
function ns.ShowAwards(sessionId)
    if sessionId then
        chosenRaid = sessionId
        chosenId = nil
    end
    ns.ShowPage("awards")
end

ns.RegisterPanel{ key = "awards", label = "Vergaben", icon = "Interface\\Icons\\INV_Misc_Bag_08", order = 35,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        page = f
        f.officer = buildOfficer(f)
        f.raider = buildRaider(f)
        f.officer:Hide()
        f.raider:Hide()
        return f
    end,
    refresh = function(f)
        if ns.IsOfficerView() then
            f.raider:Hide()
            f.officer:Show()
            refreshOfficer(f.officer)
        else
            f.officer:Hide()
            f.raider:Show()
            f.raider.list:SetItems(myItems())
        end
    end }

ns.RegisterCard{ key = "awards", order = 40, fill = function(c)
    local all = ns.Sessions()
    local last = all[#all]
    local officer = ns.IsOfficerView()
    c.title:SetText(officer and "Vergaben letzte Nacht" or "Deine Items letzte Nacht")
    if not last then
        c.line1:SetText("Keine")
        return
    end
    local night = {}
    for _, s in ipairs(all) do
        if s.date == last.date then night[#night + 1] = s end
    end
    if not officer then
        local n = 0
        for _, e in ipairs(myItems()) do
            if e.s.date == last.date then n = n + 1 end
        end
        c.line1:SetText(("%d Items am %s"):format(n, last.date))
        c:SetAction("Öffnen", function() ns.ShowPage("awards") end)
        return
    end
    local n, bank, de, pending = 0, 0, 0, false
    for _, s in ipairs(night) do
        for _, a in ipairs(s.awards or {}) do
            n = n + 1
            if a.to == "bank" then bank = bank + 1 elseif a.to == "de" then de = de + 1 end
        end
        if ns.ExportState(s) ~= "done" then pending = true end
    end
    c.line1:SetText(("%d Items am %s"):format(n, last.date))
    local parts = {}
    if bank > 0 then parts[#parts + 1] = ("%d Bank"):format(bank) end
    if de > 0 then parts[#parts + 1] = ("%d Entzaubern"):format(de) end
    if pending then parts[#parts + 1] = "noch nicht exportiert" end
    if #parts > 0 then
        c.line2:SetText((bank + de > 0 and "davon " or "") .. table.concat(parts, " · "))
    else
        c.line2:SetText(n == 0 and "Master Loot hat nichts vergeben." or "")
    end
    c:SetAction("Öffnen", function() ns.ShowAwards(last.id) end)
end }

ns.RegisterSlash("vergaben", { aliases = { "awards" }, desc = "Seite Vergaben öffnen", run = function() ns.ShowPage("awards") end })
