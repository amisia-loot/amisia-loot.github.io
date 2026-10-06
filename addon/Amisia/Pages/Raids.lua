-- Raids: the recorded sessions, a selection for the export, and the details of one session.
local ADDON, ns = ...
local W = ns.W
local ROWS, ROW_H = 8, 22

ns.RaidSelection = ns.RaidSelection or {}
local detailId
local page
-- For tests: the page frame once built.
function ns.RaidsPageFrame() return page end

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
        local main = ns.AltMain(e.name)
        local alt = main and (" (Twink von %s)"):format(main) or ""
        people[#people + 1] = e.m.late and ("|cffe0a344%s (%s)%s|r"):format(e.name, date("%H:%M", e.m.first or 0), alt) or (e.name .. alt)
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
    -- living awards only: "Item an Name (MS)", bank and disenchant with their receiver, notes in brackets
    local awards = {}
    for _, a in ipairs(s.awards or {}) do
        local text
        if a.to == "bank" or a.to == "de" then
            local who = (a.name and a.name ~= "-") and (" (" .. a.name .. ")") or ""
            text = ("%s: %s%s"):format(ns.ItemName(a.item), a.to == "bank" and "Bank" or "entzaubert", who)
        else
            text = ("%s an %s%s"):format(ns.ItemName(a.item), a.name, (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "")
        end
        awards[#awards + 1] = text .. (a.note and (" (" .. a.note .. ")") or "")
    end
    -- the bosses in order, wipes before a kill counted with it, bosses only wiped on at their last wipe
    local bosses = {}
    for _, r in ipairs(ns.BossRuns and ns.BossRuns(s, true) or {}) do
        if r.kill then
            bosses[#bosses + 1] = ("%s %s%s"):format(r.name, date("%H:%M", r.t), r.wipes > 0 and (" (" .. ns.WipeText(r.wipes) .. ")") or "")
        else
            bosses[#bosses + 1] = ("%s (%s, kein Kill)"):format(r.name, ns.WipeText(r.wipes))
        end
    end
    local bench = {}
    for _, x in ipairs(ns.BenchList and ns.BenchList(s) or {}) do bench[#bench + 1] = x.name end
    return table.concat({
        ("|cffe2b857%s, %s|r"):format(s.zone or "?", s.date or "?"),
        ("|cffe2b857Raider (%d):|r %s"):format(#names, #people > 0 and table.concat(people, ", ") or "keine"),
        "|cffe2b857Bosse:|r " .. (#bosses > 0 and table.concat(bosses, ", ") or "keine"),
        "|cffe2b857Ersatzbank:|r " .. (#bench > 0 and table.concat(bench, ", ") or "keine"),
        "|cffe2b857Loot:|r " .. (#loot > 0 and table.concat(loot, ", ") or "keiner"),
        "|cffe2b857In Lootfenstern:|r " .. (#drops > 0 and table.concat(drops, ", ") or "nichts"),
        "|cffe2b857Vergaben:|r " .. (#awards > 0 and table.concat(awards, ", ") or "keine"),
    }, "\n\n")
end
ns.RaidDetailText = detailText

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or "GameFontNormalSmall", w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

-- One column per tracked material (ns.MAT_ORDER, learned in raids, first seen first) and one for
-- the summed gems (ns.GEMS). Without a tracked material no column is shown. Three material
-- columns at most, two when a gem column shares the width.
local MAT_X, MAT_STEP, MAT_W = 380, 56, 54
local function matColumns()
    local n = #ns.MAT_ORDER
    local maxCols = next(ns.GEMS) and 2 or 3
    return n > maxCols and maxCols or n, next(ns.GEMS) ~= nil
end

-- First word of an item name: the short column title.
local function shortName(id)
    return (ns.ItemName(id):match("%S+")) or "?"
end

ns.RegisterPanel{ key = "raids", label = "Raids", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 20, group = "raid", officer = true,
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
        f.matHead = {}
        for i = 1, 3 do f.matHead[i] = col(head, MAT_X + (i - 1) * MAT_STEP, MAT_W) end
        f.gemHead = col(head, MAT_X + 2 * MAT_STEP, 90)
        f.list = W.List(f, ROWS, ROW_H, function(r)
            r.box = W.Toggle(r, function(on)
                if r.item then ns.RaidSelection[r.item.id] = on or nil end
            end)
            r.box:SetPoint("LEFT", 6, 0)
            r.sel = W.SelectBar(r)
            r.date = col(r, 30, 80, nil, "GameFontHighlightSmall")
            r.zone = col(r, 112, 200, nil, "GameFontHighlightSmall")
            r.raiders = col(r, 316, 60, nil, "GameFontHighlightSmall")
            r.mats = {}
            for i = 1, 3 do r.mats[i] = col(r, MAT_X + (i - 1) * MAT_STEP, MAT_W, nil, "GameFontHighlightSmall") end
            r.gems = col(r, MAT_X + 2 * MAT_STEP, 90, nil, "GameFontHighlightSmall")
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
            local nMat, hasGems = matColumns()
            for i = 1, 3 do
                local id = ns.MAT_ORDER[i]
                if i <= nMat and id then
                    r.mats[i]:SetText(c[id] or 0)
                    r.mats[i]:Show()
                else
                    r.mats[i]:Hide()
                end
            end
            r.gems:ClearAllPoints()
            r.gems:SetPoint("LEFT", MAT_X + nMat * MAT_STEP, 0)
            if hasGems then r.gems:SetText(ns.GemCount(c)); r.gems:Show() else r.gems:Hide() end
            if s.id == detailId then r.sel:Show() else r.sel:Hide() end
        end)
        -- 12 px short of the right edge: room for the list's scroll bar
        f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
        f.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -12, -2)
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
        -- the text ends with the list; its bar lies under the list's
        f.detail:SetPoint("BOTTOMRIGHT", -12, 0)
        return f
    end,
    refresh = function(f)
        local all = ordered()
        local exists = {}
        for _, s in ipairs(all) do exists[s.id] = s end
        for id in pairs(ns.RaidSelection) do if not exists[id] then ns.RaidSelection[id] = nil end end
        local nMat, hasGems = matColumns()
        for i = 1, 3 do
            local id = ns.MAT_ORDER[i]
            if i <= nMat and id then f.matHead[i]:SetText(shortName(id)); f.matHead[i]:Show() else f.matHead[i]:Hide() end
        end
        f.gemHead:ClearAllPoints()
        f.gemHead:SetPoint("LEFT", MAT_X + nMat * MAT_STEP, 0)
        if hasGems then f.gemHead:SetText("Edelsteine"); f.gemHead:Show() else f.gemHead:Hide() end
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
    local _, _, bosses = ns.KillCount(s)
    if bosses > 0 then parts[#parts + 1] = bosses == 1 and "1 Boss" or (bosses .. " Bosse") end
    if late > 0 then parts[#parts + 1] = late .. " zu spät" end
    local mats = ns.MatLine(m)
    if mats ~= "" then parts[#parts + 1] = mats end
    c.line2:SetText(table.concat(parts, " · "))
    if ns.IsOfficerView() then c:SetAction("Raids", function() ns.ShowPage("raids") end) end
end }
