-- Raids: the recorded sessions, a selection for the export, and the details of one session.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
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
        local alt = main and L[" (Twink von %s)"]:format(main) or ""
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
            text = ("%s: %s%s"):format(ns.ItemName(a.item), a.to == "bank" and "Bank" or L["entzaubert"], who)
        else
            text = L["%s an %s%s"]:format(ns.ItemName(a.item), a.name, (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "")
        end
        awards[#awards + 1] = text .. (a.note and (" (" .. a.note .. ")") or "")
    end
    -- the bosses in order, wipes before a kill counted with it, bosses only wiped on at their last wipe
    local bosses = {}
    for _, r in ipairs(ns.BossRuns and ns.BossRuns(s, true) or {}) do
        if r.kill then
            bosses[#bosses + 1] = ("%s %s%s"):format(r.name, date("%H:%M", r.t), r.wipes > 0 and (" (" .. ns.WipeText(r.wipes) .. ")") or "")
        else
            bosses[#bosses + 1] = L["%s (%s, kein Kill)"]:format(r.name, ns.WipeText(r.wipes))
        end
    end
    local bench = {}
    for _, x in ipairs(ns.BenchList and ns.BenchList(s) or {}) do bench[#bench + 1] = x.name end
    return table.concat({
        ("|cffe2b857%s, %s|r"):format(s.zone or "?", s.date or "?"),
        L["|cffe2b857Raider (%d):|r %s"]:format(#names, #people > 0 and table.concat(people, ", ") or L["keine"]),
        L["|cffe2b857Bosse:|r %s"]:format(#bosses > 0 and table.concat(bosses, ", ") or L["keine"]),
        L["|cffe2b857Ersatzbank:|r %s"]:format(#bench > 0 and table.concat(bench, ", ") or L["keine"]),
        L["|cffe2b857Loot:|r %s"]:format(#loot > 0 and table.concat(loot, ", ") or L["keiner##Loot"]),
        L["|cffe2b857In Lootfenstern:|r %s"]:format(#drops > 0 and table.concat(drops, ", ") or L["nichts"]),
        L["|cffe2b857Vergaben:|r %s"]:format(#awards > 0 and table.concat(awards, ", ") or L["keine"]),
    }, "\n\n")
end
ns.RaidDetailText = detailText

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or T.FONT.head, w)
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

-- the columns; the material and gem columns move with the materials there are (refresh)
local COLS = { { "date", 30, 80, L["Datum"] }, { "zone", 112, 200, "Raid" }, { "raiders", 316, 60, L["Raider##Spalte"] },
    { "mat1", MAT_X, MAT_W }, { "mat2", MAT_X + MAT_STEP, MAT_W }, { "mat3", MAT_X + 2 * MAT_STEP, MAT_W },
    { "gems", MAT_X + 2 * MAT_STEP, 90 } }

ns.RegisterPanel{ key = "raids", label = "Raids", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 20, group = "raid", officer = true,
    create = function(parent)
        local f = W.Page(parent)
        page = f
        -- the head row: how many raids, select all and delete at the right
        f:Bands({ "row" })
        f.pageText = W.Text(f, T.FONT.hint)
        f.del = W.Button(f, L["Löschen##Knopf"], 100, function()
            if not next(ns.RaidSelection) then
                ns.msg(L["Zuerst Raids in der Liste ankreuzen."])
                return
            end
            -- the dialog strata is below the main window's; lift it so it is not hidden behind
            local d = StaticPopup_Show("AMISIA_DELETE")
            if d and d.SetFrameStrata then d:SetFrameStrata("FULLSCREEN_DIALOG"); if d.Raise then d:Raise() end end
        end)
        f.all = W.Button(f, L["Alle wählen"], 100, function()
            local all, allOn = ordered(), true
            for _, s in ipairs(all) do if not ns.RaidSelection[s.id] then allOn = false end end
            wipe(ns.RaidSelection)
            if not allOn then for _, s in ipairs(all) do ns.RaidSelection[s.id] = true end end
            ns.Refresh()
        end)
        W.FitChip(f.del, 100)
        W.FitChip(f.all, 100)
        f:Place(1, { { f.pageText, fill = true } }, { f.all, f.del })
        local _, heads = f:Columns(COLS)
        f.matHead = { heads.mat1, heads.mat2, heads.mat3 }
        f.gemHead = heads.gems
        f.list = f:List(ROWS, ROW_H, function(r)
            r.box = W.Toggle(r, function(on)
                if r.item then ns.RaidSelection[r.item.id] = on or nil end
            end)
            r.box:SetPoint("LEFT", 6, 0)
            r.sel = W.SelectBar(r)
            r.date = col(r, 30, 80, nil, T.FONT.text)
            r.zone = col(r, 112, 200, nil, T.FONT.text)
            r.raiders = col(r, 316, 60, nil, T.FONT.text)
            r.mats = {}
            for i = 1, 3 do r.mats[i] = col(r, MAT_X + (i - 1) * MAT_STEP, MAT_W, nil, T.FONT.text) end
            r.gems = col(r, MAT_X + 2 * MAT_STEP, 90, nil, T.FONT.text)
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
        f.empty = f:Empty()
        f.empty:Set(L["Noch kein Raid aufgezeichnet"], L["Die Aufnahme startet in einer Raidinstanz mit Raidgruppe."])
        -- the chosen raid under the list; the text ends with the list, its bar lies under the list's
        f.detail = W.ScrollText(f)
        f.detail:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", T.LAYOUT.TEXT_X, -T.LAYOUT.GAP * 2)
        f.detail:SetPoint("BOTTOMRIGHT", -T.SCROLL_ROOM, f:Bottom())
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
        if hasGems then f.gemHead:SetText(L["Edelsteine"]); f.gemHead:Show() else f.gemHead:Hide() end
        f.list:SetItems(all)
        f.pageText:SetText(#all == 1 and L["1 Raid"] or L["%d Raids"]:format(#all))
        f.empty:SetShown(#all == 0)
        local s = exists[detailId] or all[1]
        detailId = s and s.id or nil
        f.detail:SetText(s and detailText(s) or "")
    end }

StaticPopupDialogs["AMISIA_DELETE"] = {
    text = L["Die angekreuzten Raids aus Amisia löschen?"],
    button1 = L["Löschen##Knopf"],
    button2 = L["Abbrechen"],
    OnAccept = function()
        local n = ns.DeleteSessions(ns.RaidSelection)
        wipe(ns.RaidSelection)
        ns.msg(L["%d Raid(s) gelöscht."]:format(n))
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
    c.title:SetText(ns.Active() and L["Aufnahme läuft"] or L["Letzter Raid"])
    if not s then
        c.line1:SetText(L["Noch kein Raid aufgezeichnet"])
        c.line2:SetText(L["Die Aufnahme startet in einer Raidinstanz mit Raidgruppe."])
        return
    end
    c.line1:SetText(("%s, %s"):format(s.zone or "?", s.date or "?"))
    local m = ns.MatCounts(s)
    local late = ns.LateCount(s)
    local parts = { L["%d Raider"]:format(ns.MemberCount(s)) }
    local _, _, bosses = ns.KillCount(s)
    if bosses > 0 then parts[#parts + 1] = bosses == 1 and L["1 Boss"] or L["%d Bosse"]:format(bosses) end
    if late > 0 then parts[#parts + 1] = L["%d zu spät"]:format(late) end

    local mats = ns.MatLine(m)
    if mats ~= "" then parts[#parts + 1] = mats end
    c.line2:SetText(table.concat(parts, " · "))
    if ns.IsOfficerView() then c:SetAction("Raids", function() ns.ShowPage("raids") end) end
end }
