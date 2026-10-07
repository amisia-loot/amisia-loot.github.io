-- Export: the text block for the ledger's Import tab, of the new and changed raids or the selected ones.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local area, page
local exportText = ""

function ns.ExportPageFrame() return page end

local function setExport(txt)
    exportText = txt or ""
    if not area then return end
    area.box:SetText(exportText)
    area.box:SetCursorPosition(0)
end

-- Fills the export box. latestOnly: the newest session. Otherwise the selected sessions, or without
-- a selection every session that is new or changed since its last export. What the box shows counts
-- as exported from then on.
function ns.ShowExport(latestOnly)
    ns.ShowPage("export")
    -- hidden from raiders: nothing is shown, so nothing counts as exported
    if ns.CurrentPage() ~= "export" then return end
    local src, list = ns.Sessions(), {}
    local onlyNew = false
    if latestOnly then
        if src[#src] then list[1] = src[#src] end
    elseif next(ns.RaidSelection or {}) then
        for _, s in ipairs(src) do if ns.RaidSelection[s.id] then list[#list + 1] = s end end
    else
        list = ns.PendingExport()
        onlyNew = true
    end
    if #list == 0 then
        local bankOnly = onlyNew and ns.BankPending() or (not onlyNew and ns.Bank())
        if not bankOnly then
            setExport("")
            if #src == 0 and not ns.Bank() then
                ns.msg(L["Noch keine Raids und keine Gildenbank-Zählung zum Exportieren."])
            else
                ns.msg(L["Nichts Neues seit dem letzten Export. Raids auf der Seite Raids ankreuzen, um sie noch einmal zu exportieren."])
            end
            return
        end
    end
    setExport(ns.ExportText(list))
    ns.MarkExported(list)
    if onlyNew then
        ns.msg(L["Export: %d neue oder geänderte Raid(s)%s."]:format(#list, ns.Bank() and L[" und die Gildenbank"] or ""))
    end
    if area then
        area.box:SetFocus()
        area.box:HighlightText()
    end
    ns.Refresh()
end

ns.RegisterPanel{ key = "export", label = "Export", icon = "Interface\\Icons\\INV_Scroll_05", order = 60, group = "guild", officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        local intro = W.Text(f, T.FONT.body, 590, true)
        intro:SetPoint("TOPLEFT", 0, -2)
        intro:SetText(L["Text für den Import-Tab der Amisia-Loot-Seite."])
        local newBtn = W.Button(f, L["Neue und geänderte"], 150, function()
            wipe(ns.RaidSelection)
            ns.ShowExport(false)
        end)
        newBtn:SetPoint("TOPLEFT", 0, -26)
        local selBtn = W.Button(f, L["Angekreuzte"], 120, function()
            if not next(ns.RaidSelection) then
                ns.msg(L["Zuerst Raids auf der Seite Raids ankreuzen."])
                return
            end
            ns.ShowExport(false)
        end)
        selBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)
        f.state = W.Text(f, T.FONT.hint, 300)
        f.state:SetPoint("LEFT", selBtn, "RIGHT", 10, 0)
        area = W.EditArea(f)
        area:SetPoint("TOPLEFT", 0, -56)
        area:SetPoint("BOTTOMRIGHT", 0, 24)
        area.box:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(exportText)
                self:HighlightText()
            end
        end)
        local hint = W.Text(f, T.FONT.hint, 590)
        hint:SetPoint("BOTTOMLEFT", 0, 4)
        hint:SetText(L["Strg+A, Strg+C, im Import-Tab einfügen."])
        -- the parts the layout tests read
        f.intro, f.newBtn, f.selBtn, f.area, f.hint = intro, newBtn, selBtn, area, hint
        page = f
        return f
    end,
    refresh = function(f)
        local pending = #ns.PendingExport()
        f.state:SetText(pending > 0 and L["%d Raid(s) neu oder geändert"]:format(pending) or L["alles exportiert"])
    end }

ns.RegisterCard{ key = "export", order = 60, officer = true, fill = function(c)
    local pending = #ns.PendingExport()
    c.title:SetText("Export")
    c.line1:SetText(pending > 0 and L["%d Raid(s) neu oder geändert"]:format(pending) or L["Alles exportiert"])
    c.line2:SetText(ns.BankPending() and L["Die Gildenbank-Zählung ist auch neu."] or "")
    if pending > 0 or ns.BankPending() then c:SetAction(L["Exportieren"], function() wipe(ns.RaidSelection); ns.ShowExport(false) end) end
end }
