-- Raids: the recorded sessions, a selection for the export, and the details of one session.
local ADDON, ns = ...
local W = ns.W
local ROWS, ROW_H = 8, 22

ns.RaidSelection = ns.RaidSelection or {}
local detailId
local page

local function ordered()
    local src, out = ns.Sessions(), {}
    for i = #src, 1, -1 do out[#out + 1] = src[i] end
    return out
end

local function detailText(s)
    local names = {}
    for name, m in pairs(s.members or {}) do names[#names + 1] = { name = name, m = m } end
    table.sort(names, function(a, b) return a.name < b.name end)
    local people = {}
    for _, e in ipairs(names) do
        people[#people + 1] = e.m.late and ("|cffe0a344%s (%s)|r"):format(e.name, date("%H:%M", e.m.first or 0)) or e.name
    end
    local loot = {}
    for _, l in ipairs(s.items or {}) do
        loot[#loot + 1] = ("%s: %s%s"):format(l.name, ns.ItemName(l.item), (l.count or 1) > 1 and (" x" .. l.count) or "")
    end
    local drops = {}
    for _, d in pairs(s.drops or {}) do
        for id, c in pairs(d.items or {}) do
            drops[#drops + 1] = ("%s (%s)%s"):format(ns.ItemName(id), d.src or "?", c > 1 and (" x" .. c) or "")
        end
    end
    table.sort(drops)
    local awards = {}
    for _, a in ipairs(s.awards or {}) do
        awards[#awards + 1] = ("%s an %s%s"):format(ns.ItemName(a.item), a.name, (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "")
    end
    return table.concat({
        ("|cffe2b857%s, %s|r"):format(s.zone or "?", s.date or "?"),
        ("|cffe2b857Raider (%d):|r %s"):format(#names, #people > 0 and table.concat(people, ", ") or "keine"),
        "|cffe2b857Loot:|r " .. (#loot > 0 and table.concat(loot, ", ") or "keiner"),
        "|cffe2b857In Lootfenstern:|r " .. (#drops > 0 and table.concat(drops, ", ") or "nichts"),
        "|cffe2b857Vergaben:|r " .. (#awards > 0 and table.concat(awards, ", ") or "keine"),
    }, "\n\n")
end

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or "GameFontNormalSmall", w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

ns.RegisterPanel{ key = "raids", label = "Raids", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 20, officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        page = f
        local head = CreateFrame("Frame", nil, f)
        head:SetHeight(18)
        head:SetPoint("TOPLEFT")
        head:SetPoint("TOPRIGHT")
        col(head, 30, 80, "Datum")
        col(head, 112, 200, "Raid")
        col(head, 316, 60, "Raider")
        col(head, 380, 50, "Mal")
        col(head, 432, 50, "Herz")
        col(head, 486, 90, "Edelsteine")
        f.list = W.List(f, ROWS, ROW_H, function(r)
            r.box = W.Toggle(r, function(on)
                if r.item then ns.RaidSelection[r.item.id] = on or nil end
            end)
            r.box:SetPoint("LEFT", 6, 0)
            r.sel = W.Flat(r, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.18, "BORDER")
            r.date = col(r, 30, 80, nil, "GameFontHighlightSmall")
            r.zone = col(r, 112, 200, nil, "GameFontHighlightSmall")
            r.raiders = col(r, 316, 60, nil, "GameFontHighlightSmall")
            r.mark = col(r, 380, 50, nil, "GameFontHighlightSmall")
            r.heart = col(r, 432, 50, nil, "GameFontHighlightSmall")
            r.gems = col(r, 486, 90, nil, "GameFontHighlightSmall")
            r:SetScript("OnClick", function(self)
                if self.item then
                    detailId = self.item.id
                    ns.Refresh()
                end
            end)
        end, function(r, s)
            local c = ns.MatCounts(s)
            r.box:SetChecked(ns.RaidSelection[s.id])
            r.date:SetText(ns.ExportState(s) == "done" and ("|cff8f86a3" .. s.date .. "|r") or s.date)
            r.zone:SetText((s == ns.Active() and "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:12:12:0:0|t " or "") .. (s.zone or "?"))
            local late = ns.LateCount(s)
            r.raiders:SetText(ns.MemberCount(s) .. (late > 0 and ("  |cffe0a344+" .. late .. "|r") or ""))
            r.mark:SetText(c[32897] or 0)
            r.heart:SetText(c[32428] or 0)
            r.gems:SetText(ns.GemCount(c))
            if s.id == detailId then r.sel:Show() else r.sel:Hide() end
        end)
        f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
        f.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -2)
        f.pageText = W.Text(f, "GameFontDisableSmall", 200)
        f.pageText:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 6, -8)
        f.del = W.Button(f, "Löschen", 100, function()
            if not next(ns.RaidSelection) then
                ns.msg("Zuerst Raids in der Liste ankreuzen.")
                return
            end
            -- the dialog strata is below the main window's; lift it so it is not hidden behind
            local d = StaticPopup_Show("AMISIA_DELETE")
            if d and d.SetFrameStrata then d:SetFrameStrata("FULLSCREEN_DIALOG"); if d.Raise then d:Raise() end end
        end)
        f.del:SetPoint("TOPRIGHT", f.list, "BOTTOMRIGHT", 0, -4)
        f.all = W.Button(f, "Alle wählen", 100, function()
            local all, allOn = ordered(), true
            for _, s in ipairs(all) do if not ns.RaidSelection[s.id] then allOn = false end end
            wipe(ns.RaidSelection)
            if not allOn then for _, s in ipairs(all) do ns.RaidSelection[s.id] = true end end
            ns.Refresh()
        end)
        f.all:SetPoint("RIGHT", f.del, "LEFT", -6, 0)
        f.detail = W.ScrollText(f)
        f.detail:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 0, -34)
        f.detail:SetPoint("BOTTOMRIGHT", -24, 0)
        return f
    end,
    refresh = function(f)
        local all = ordered()
        local exists = {}
        for _, s in ipairs(all) do exists[s.id] = s end
        for id in pairs(ns.RaidSelection) do if not exists[id] then ns.RaidSelection[id] = nil end end
        f.list:SetItems(all)
        f.pageText:SetText(#all == 0 and "Noch keine Raids aufgezeichnet." or ("%d Raids"):format(#all))
        local s = exists[detailId] or all[1]
        detailId = s and s.id or nil
        f.detail:SetText(s and detailText(s) or "")
    end }

StaticPopupDialogs["AMISIA_DELETE"] = {
    text = "Die angekreuzten Raids aus Amisia löschen?",
    button1 = "Löschen",
    button2 = "Abbrechen",
    OnAccept = function()
        local n = ns.DeleteSessions(ns.RaidSelection)
        wipe(ns.RaidSelection)
        ns.msg(("%d Raid(s) gelöscht."):format(n))
        ns.Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

ns.RegisterCard{ key = "raid", order = 10, fill = function(c)
    local all = ns.Sessions()
    local s = ns.Active() or all[#all]
    c.title:SetText(ns.Active() and "Aufnahme läuft" or "Letzter Raid")
    if not s then
        c.line1:SetText("Noch kein Raid aufgezeichnet")
        c.line2:SetText("Die Aufnahme startet in einer Raidinstanz mit Raidgruppe.")
        return
    end
    c.line1:SetText(("%s, %s"):format(s.zone or "?", s.date or "?"))
    local m = ns.MatCounts(s)
    local late = ns.LateCount(s)
    local parts = { ("%d Raider"):format(ns.MemberCount(s)) }
    if late > 0 then parts[#parts + 1] = late .. " zu spät" end
    local mats = (m[32897] or 0) + (m[32428] or 0) + ns.GemCount(m)
    if mats > 0 then parts[#parts + 1] = ("Mal %d · Herz %d · Edelsteine %d"):format(m[32897] or 0, m[32428] or 0, ns.GemCount(m)) end
    c.line2:SetText(table.concat(parts, " · "))
    if ns.IsOfficerView() then c:SetAction("Raids", function() ns.ShowPage("raids") end) end
end }

ns.RegisterCard{ key = "awards", order = 40, fill = function(c)
    local all = ns.Sessions()
    local last = all[#all]
    c.title:SetText("Vergaben letzte Nacht")
    if not last then
        c.line1:SetText("Keine")
        return
    end
    local n = 0
    for _, s in ipairs(all) do
        if s.date == last.date then n = n + ns.AwardCount(s) end
    end
    c.line1:SetText(("%d Items am %s"):format(n, last.date))
    c.line2:SetText(n > 0 and "Details auf der Seite Raids." or "Master Loot hat nichts vergeben.")
end }
