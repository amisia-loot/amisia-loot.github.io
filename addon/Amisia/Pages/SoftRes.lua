-- Soft-reserves: who reserved what in the loaded list; importing and clearing for officers.
local ADDON, ns = ...
local W = ns.W

local function daysOld(isoDate)
    local y, m, d = tostring(isoDate or ""):match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return t and math.floor((time() - t) / 86400) or nil
end

local function rows()
    local sr = AmisiaDB and AmisiaDB.softres
    local out = {}
    for item, names in pairs(sr and sr.byItem or {}) do
        out[#out + 1] = { item = item, name = ns.ItemName(item), names = names }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Raid members without a reservation, when in a raid and a list is loaded.
local function missing()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or not IsInRaid() then return nil end
    local reserved = {}
    for _, names in pairs(sr.byItem or {}) do
        for _, n in ipairs(names) do reserved[n:lower()] = true end
    end
    local out = {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName((GetRaidRosterInfo(i)))
        if n and not reserved[n:lower()] then out[#out + 1] = n end
    end
    return out
end

ns.RegisterPanel{ key = "softres", label = "Soft-Reserves", icon = "Interface\\Icons\\INV_Scroll_03", order = 40,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        f.import = W.Button(f, "Importieren", 110, function() ns.ToggleSoftResFrame() end)
        f.import:SetPoint("TOPLEFT", 0, -26)
        f.clear = W.Button(f, "Löschen", 90, function() ns.ClearSoftRes(); ns.Refresh() end)
        f.clear:SetPoint("LEFT", f.import, "RIGHT", 6, 0)
        f.missing = W.Text(f, "GameFontDisableSmall", 380, true)
        f.missing:SetPoint("LEFT", f.clear, "RIGHT", 10, 0)
        f.list = W.List(f, 16, 22, function(r)
            r.item = W.Text(r, "GameFontHighlightSmall", 230)
            r.item:SetPoint("LEFT", 6, 0)
            r.names = W.Text(r, "GameFontHighlightSmall", 350)
            r.names:SetPoint("LEFT", 240, 0)
        end, function(r, e)
            r.item:SetText(e.name)
            r.names:SetText(table.concat(e.names, ", "))
        end)
        f.list:SetPoint("TOPLEFT", 0, -58)
        f.list:SetPoint("TOPRIGHT", 0, -58)
        return f
    end,
    refresh = function(f)
        local sr = AmisiaDB and AmisiaDB.softres
        if sr then
            local old = daysOld(sr.date) or 0
            local warn = old > (ns.Get("softres.warnDays") or 7)
            f.state:SetText(("%sListe vom %s:|r %d Reservierungen%s"):format(warn and "|cffe0a344" or "|cff4fbf7a", sr.date, sr.count or 0,
                warn and (", " .. old .. " Tage alt") or ""))
        else
            f.state:SetText("|cff8f86a3Keine Soft-Reserves geladen.|r")
        end
        local officer = ns.IsOfficerView()
        if officer then f.import:Show(); f.clear:Show() else f.import:Hide(); f.clear:Hide() end
        local miss = missing()
        f.missing:SetText(miss and (#miss == 0 and "Alle im Raid haben reserviert." or (#miss .. " im Raid ohne Reserve: " .. table.concat(miss, ", "))) or "")
        f.list:SetItems(rows())
    end }

ns.RegisterCard{ key = "softres", order = 20, fill = function(c)
    local sr = AmisiaDB and AmisiaDB.softres
    c.title:SetText("Soft-Reserves")
    if not sr then
        c.line1:SetText("Keine Liste geladen")
        if ns.IsOfficerView() then c:SetAction("Importieren", function() ns.ToggleSoftResFrame() end) end
        return
    end
    c.line1:SetText(("%d Reservierungen, vom %s"):format(sr.count or 0, sr.date))
    local miss = missing()
    c.line2:SetText(miss and (#miss .. " im Raid ohne Reserve") or "")
    c:SetAction("Ansehen", function() ns.ShowPage("softres") end)
end }
