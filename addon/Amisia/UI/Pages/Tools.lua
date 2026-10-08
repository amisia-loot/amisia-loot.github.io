-- Tools (expert mode): the item scan and the collector that build the data files, and the guild's
-- drop data: kills own and heard, the list per instance and boss with the rates, the sharing switch
-- and the text "Drops für die Website" (in place of the list).
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local page
local exportOpen = false
local exportText = ""

-- rows of 18 under the drop controls down to the footer (14 x 18 = 252 of 269)
local DROP_ROWS, DROP_ROW_H = 14, 18
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
    -- the guild's drop data under its section header: the state, sharing and the text for the website,
    -- the list (or the text) down to the footer
    local D = W.Page(f, { view = true })
    local top = D:Bands({ "header", { "line", lines = 2 }, "row" })
    D.head = W.SectionHeader(D, L["Drop-Daten"], false)
    D.head:SetAllPoints(D.bands[1])
    D.state = D:Line(2)

    D.share = W.Toggle(D, function(on) ns.Set("drops.share", on) end)
    D.shareLabel = W.Text(D, T.FONT.text, 180)
    D.shareLabel:SetText(L["Mit der Gilde teilen"])
    W.Tooltip(D.share, L["Drop-Daten mit der Gilde teilen"], L["Ohne Namen, nur außerhalb von Instanzen, nur unter geprüften Gildenmitgliedern."])

    D.web = W.Button(D, L["Drops für die Website"], 160, function()
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
    W.FitChip(D.web, 160)
    D:Place(3, { D.share, D.shareLabel }, { D.web })
    D:Footer({ "areaHint" })

    -- rows of 18 under the controls down to the footer; the list is 590 wide, its thin bar beside it
    D.list = D:List(DROP_ROWS, DROP_ROW_H, function(r)
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
    D.area = W.EditArea(D)
    D.area:SetPoint("TOPLEFT", 0, top)
    D.area:SetPoint("BOTTOMRIGHT", 0, D:Bottom())
    -- read-only like the export box: typing puts the text back and marks it
    D.area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(exportText)
            self:HighlightText()
        end
    end)
    D.area:Hide()
    D.areaHint:SetText(L["Strg+A, Strg+C, auf der Website im Reiter Import einfügen."])
    D.areaHint:Hide()
    return D
end

local function fillDrops(D)
    local s = ns.DropsStatus()
    if s.kills == 0 then
        D.state:SetText(ns.Get("drops.record")
            and L["Noch keine Kills. Amisia zeichnet geöffnete Lootfenster von Bossen in Dungeons und Raids auf."]
            or L["Noch keine Kills. Amisia zeichnet geöffnete Lootfenster von Bossen in Dungeons und Raids auf (Aufzeichnen ist in den Einstellungen aus)."])
    else
        D.state:SetText(L["%d Kills (%d eigene, %d gehörte), %d Bosse, neuester Tag %s, letzter Austausch %s."]:format(
            s.kills, s.own, s.heard, s.bosses, s.newest and ns.DropsDate(s.newest) or L["keiner"],
            s.heardAt and ns.FmtDayTime(s.heardAt) or L["noch keiner"]))
    end
    D.share:SetChecked(ns.Get("drops.share") and true or false)
    D.list:SetItems(ns.DropsBossList())
    if exportOpen then
        D.list:Hide()
        D.area:Show()
        D.areaHint:Show()
        D.web:SetText(L["Zur Liste"])
        -- the text follows the records unless the box is in use
        if not D.area.box:HasFocus() then
            local text = ns.DropsExportText()
            if text ~= exportText then setExport(D, text) end
        end
    else
        D.area:Hide()
        D.areaHint:Hide()
        D.list:Show()
        D.web:SetText(L["Drops für die Website"])
    end
end

ns.RegisterPanel{ key = "tools", label = L["Werkzeuge"], icon = "Interface\\Icons\\INV_Misc_Gear_01", order = 80, group = "guild", expert = true,
    create = function(parent)
        local f = W.Page(parent)
        -- the head row: the scan's buttons; under it its state and what to do with it (two lines each)
        f:Bands({ "row", { "line", lines = 2 }, { "line", lines = 2 } })
        local gear = W.Button(f, L["Ausrüstungs-Scan"], 140, function() ns.ScanCommand("gear"); ns.Refresh() end)
        local resume = W.Button(f, L["Scan fortsetzen"], 130, function() ns.ScanCommand(""); ns.Refresh() end)
        local retry = W.Button(f, L["Offene wiederholen"], 140, function() ns.ScanCommand("retry"); ns.Refresh() end)
        local stop = W.Button(f, L["Anhalten"], 90, function() ns.ScanStop(); ns.Refresh() end)
        W.FitChip(gear, 140)
        W.FitChip(resume, 130)
        W.FitChip(retry, 140)
        W.FitChip(stop, 90)
        f:Place(1, { gear, resume, retry, stop })
        f.state = f:Line(2)
        local hint = f:Line(3)
        hint:SetText(L["Der Scan läuft nur außerhalb von Instanzen. Danach ausloggen, damit die Datei geschrieben wird; tools/build_gear.py und tools/build_scan.py lesen sie. Sammler und Scan-Rate stehen in den Einstellungen."])
        f.drops = buildDrops(f)
        -- the parts the layout tests read
        f.buttons, f.hint = { gear, resume, retry, stop }, hint
        page = f
        return f
    end,
    refresh = function(f)
        f.state:SetText(ns.ScanStatus() .. "\n" .. (ns.Get("tools.collect") and L["Item-Sammler: an, %d Items mit Quelle."]
            or L["Item-Sammler: aus, %d Items mit Quelle."]):format(ns.CollectCount()))
        fillDrops(f.drops)
    end }

-- The text "Drops für die Website" (/amisia drops export): the tools page with the text marked.
-- The page is part of expert mode; without it the command says where the text is.
function ns.ShowDropsExport()
    ns.ShowPage("tools")
    if ns.CurrentPage() ~= "tools" or not page then
        ns.msg(L["Der Text \"Drops für die Website\" steht auf der Seite Werkzeuge; sie zeigt Amisia im Expertenmodus (Einstellungen)."])
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
