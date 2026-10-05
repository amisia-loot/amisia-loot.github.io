-- Tools (expert mode): the item scan and the collector that build the data files.
local ADDON, ns = ...
local W = ns.W
local page

function ns.ToolsPageFrame() return page end

ns.RegisterPanel{ key = "tools", label = "Werkzeuge", icon = "Interface\\Icons\\INV_Misc_Gear_01", order = 80, group = "guild", expert = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        local gear = W.Button(f, "Ausrüstungs-Scan", 140, function() ns.ScanCommand("gear"); ns.Refresh() end)
        gear:SetPoint("TOPLEFT", 0, -40)
        local resume = W.Button(f, "Scan fortsetzen", 130, function() ns.ScanCommand(""); ns.Refresh() end)
        resume:SetPoint("LEFT", gear, "RIGHT", 6, 0)
        local retry = W.Button(f, "Offene wiederholen", 140, function() ns.ScanCommand("retry"); ns.Refresh() end)
        retry:SetPoint("LEFT", resume, "RIGHT", 6, 0)
        local stop = W.Button(f, "Anhalten", 90, function() ns.ScanStop(); ns.Refresh() end)
        stop:SetPoint("LEFT", retry, "RIGHT", 6, 0)
        local hint = W.Text(f, "GameFontDisableSmall", 590, true)
        hint:SetPoint("TOPLEFT", 0, -76)
        hint:SetText("Der Scan läuft nur außerhalb von Instanzen. Danach ausloggen, damit die Datei geschrieben wird; "
            .. "tools/build_gear.py und tools/build_scan.py lesen sie. Sammler und Scan-Rate stehen in den Einstellungen.")
        -- the parts the layout tests read
        f.buttons, f.hint = { gear, resume, retry, stop }, hint
        page = f
        return f
    end,
    refresh = function(f)
        f.state:SetText(ns.ScanStatus() .. ("\nItem-Sammler: %s, %d Items mit Quelle."):format(ns.Get("tools.collect") and "an" or "aus", ns.CollectCount()))
    end }
