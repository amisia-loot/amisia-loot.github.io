-- Tools (expert mode): the item scan and the collector that build the data files, and the guild's
-- drop data: kills own and heard, the list per instance and boss with the rates, the sharing switch
-- and the text "Drops für die Website" (in place of the list).
local ADDON, ns = ...
local W, T = ns.W, ns.Theme
local page
local exportOpen = false
local exportText = ""

local DROP_ROWS, DROP_ROW_H = 15, 18
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.56, 0.53, 0.64 }
local WHITE = { 1, 1, 1 }
local INDENT = { boss = "   ", item = "      " }

function ns.ToolsPageFrame() return page end

local function setExport(D, text)
    exportText = text or ""
    D.area.box:SetText(exportText)
    D.area.box:SetCursorPosition(0)
end

local function itemTooltip(owner, id)
    if not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local _, link = C_Item.GetItemInfo(id)
    if link then
        GameTooltip:SetHyperlink(link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(id)
    end
    GameTooltip:Show()
end

local function buildDrops(f)
    local D = {}
    D.head = W.SectionHeader(f, "Drop-Daten", false)
    D.head:SetPoint("TOPLEFT", 0, -110)
    D.head:SetPoint("TOPRIGHT", 0, -110)
    D.state = W.Text(f, T.FONT.text, 590, true)
    D.state:SetPoint("TOPLEFT", 4, -140)
    D.state:SetHeight(28)
    D.state:SetJustifyV("TOP")

    D.share = W.Toggle(f, function(on) ns.Set("drops.share", on) end)
    D.share:SetPoint("TOPLEFT", 0, -174)
    D.shareLabel = W.Text(f, T.FONT.text, 180)
    D.shareLabel:SetPoint("LEFT", D.share, "RIGHT", 6, 0)
    D.shareLabel:SetText("Mit der Gilde teilen")
    W.Tooltip(D.share, "Drop-Daten mit der Gilde teilen", "Ohne Namen, nur außerhalb von Instanzen, nur unter geprüften Gildenmitgliedern.")

    D.web = W.Button(f, "Drops für die Website", 160, function()
        exportOpen = not exportOpen
        if exportOpen then
            setExport(D, ns.DropsExportText())
            D.area.box:SetFocus()
            D.area.box:HighlightText()
        else
            D.area.box:ClearFocus()
        end
        ns.Refresh()
    end)
    D.web:SetPoint("TOPRIGHT", 0, -172)

    -- 15 rows of 18 under the controls (202 + 270 = 472 of 478 px); the list is 590 wide, its thin
    -- bar beside it
    D.list = W.List(f, DROP_ROWS, DROP_ROW_H, function(r)
        r.name = W.Text(r, T.FONT.text, 330)
        r.name:SetPoint("LEFT", 6, 0)
        r.rate = W.Text(r, T.FONT.text, 240)
        r.rate:SetPoint("RIGHT", -6, 0)
        r.rate:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(self)
            if self.item and self.item.kind == "item" then itemTooltip(self, self.item.id) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        -- instances gold, the rates of items grey
        local nameColor = e.kind == "inst" and GOLD or WHITE
        local rateColor = e.kind == "inst" and GOLD or e.kind == "item" and GREY or WHITE
        r.name:SetText((INDENT[e.kind] or "") .. e.text)
        r.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
        r.rate:SetText(e.rate)
        r.rate:SetTextColor(rateColor[1], rateColor[2], rateColor[3])
    end)
    D.list:SetPoint("TOPLEFT", 0, -202)
    D.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -202)

    D.area = W.EditArea(f)
    D.area:SetPoint("TOPLEFT", 0, -202)
    D.area:SetPoint("BOTTOMRIGHT", 0, 24)
    -- read-only like the export box: typing puts the text back and marks it
    D.area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(exportText)
            self:HighlightText()
        end
    end)
    D.area:Hide()
    D.areaHint = W.Text(f, T.FONT.hint, 590)
    D.areaHint:SetPoint("BOTTOMLEFT", 0, 4)
    D.areaHint:SetText("Strg+A, Strg+C, auf der Website im Reiter Import einfügen.")
    D.areaHint:Hide()
    return D
end

local function fillDrops(D)
    local s = ns.DropsStatus()
    if s.kills == 0 then
        D.state:SetText("Noch keine Kills. Amisia zeichnet geöffnete Lootfenster von Bossen in Dungeons und Raids auf"
            .. (ns.Get("drops.record") and "." or " (Aufzeichnen ist in den Einstellungen aus)."))
    else
        D.state:SetText(("%d Kills (%d eigene, %d gehörte), %d Bosse, neuester Tag %s, letzter Austausch %s."):format(
            s.kills, s.own, s.heard, s.bosses, s.newest and ns.DropsDate(s.newest) or "keiner",
            s.heardAt and date("%d.%m. %H:%M", s.heardAt) or "noch keiner"))
    end
    D.share:SetChecked(ns.Get("drops.share") and true or false)
    D.list:SetItems(ns.DropsBossList())
    if exportOpen then
        D.list:Hide()
        D.area:Show()
        D.areaHint:Show()
        D.web:SetText("Zur Liste")
        -- the text follows the records unless the box is in use
        if not D.area.box:HasFocus() then
            local text = ns.DropsExportText()
            if text ~= exportText then setExport(D, text) end
        end
    else
        D.area:Hide()
        D.areaHint:Hide()
        D.list:Show()
        D.web:SetText("Drops für die Website")
    end
end

ns.RegisterPanel{ key = "tools", label = "Werkzeuge", icon = "Interface\\Icons\\INV_Misc_Gear_01", order = 80, group = "guild", expert = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, T.FONT.body, 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        local gear = W.Button(f, "Ausrüstungs-Scan", 140, function() ns.ScanCommand("gear"); ns.Refresh() end)
        gear:SetPoint("TOPLEFT", 0, -40)
        local resume = W.Button(f, "Scan fortsetzen", 130, function() ns.ScanCommand(""); ns.Refresh() end)
        resume:SetPoint("LEFT", gear, "RIGHT", 6, 0)
        local retry = W.Button(f, "Offene wiederholen", 140, function() ns.ScanCommand("retry"); ns.Refresh() end)
        retry:SetPoint("LEFT", resume, "RIGHT", 6, 0)
        local stop = W.Button(f, "Anhalten", 90, function() ns.ScanStop(); ns.Refresh() end)
        stop:SetPoint("LEFT", retry, "RIGHT", 6, 0)
        local hint = W.Text(f, T.FONT.hint, 590, true)
        hint:SetPoint("TOPLEFT", 0, -76)
        hint:SetHeight(28)
        hint:SetJustifyV("TOP")
        hint:SetText("Der Scan läuft nur außerhalb von Instanzen. Danach ausloggen, damit die Datei geschrieben wird; "
            .. "tools/build_gear.py und tools/build_scan.py lesen sie. Sammler und Scan-Rate stehen in den Einstellungen.")
        f.drops = buildDrops(f)
        -- the parts the layout tests read
        f.buttons, f.hint = { gear, resume, retry, stop }, hint
        page = f
        return f
    end,
    refresh = function(f)
        f.state:SetText(ns.ScanStatus() .. ("\nItem-Sammler: %s, %d Items mit Quelle."):format(ns.Get("tools.collect") and "an" or "aus", ns.CollectCount()))
        fillDrops(f.drops)
    end }

-- The text "Drops für die Website" (/amisia drops export): the tools page with the text marked.
-- The page is part of expert mode; without it the command says where the text is.
function ns.ShowDropsExport()
    ns.ShowPage("tools")
    if ns.CurrentPage() ~= "tools" or not page then
        ns.msg("Der Text \"Drops für die Website\" steht auf der Seite Werkzeuge; sie zeigt Amisia im Expertenmodus (Einstellungen).")
        return
    end
    exportOpen = true
    ns.Refresh()
    setExport(page.drops, ns.DropsExportText())
    page.drops.area.box:SetFocus()
    page.drops.area.box:HighlightText()
end

-- New or merged records: the page shows them, at most once a second and only while shown.
local refreshPending, refreshAt = false, nil
ns.Listen("DROPS_CHANGED", function()
    if not page or not page:IsShown() or ns.CurrentPage() ~= "tools" or refreshPending then return end
    refreshPending = true
    local wait = refreshAt and math.max(0, 1 - (GetTime() - refreshAt)) or 0
    C_Timer.After(wait, function()
        refreshPending = false
        refreshAt = GetTime()
        if page and page:IsShown() and ns.CurrentPage() == "tools" then ns.Refresh() end
    end)
end)
