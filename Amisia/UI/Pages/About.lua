-- About: the version, how many run Amisia (the page Amisia-Versionen has the list, F-237), and every command,
-- generated from the registry.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme

local page            -- the built frame
local refreshAt, refreshPending

local function colored(color, text) return color .. text .. "|r" end

local function tipButton(b)
    b:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self:GetText(), 1, 0.82, 0)
        GameTooltip:AddLine(self.tip, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

ns.RegisterPanel{ key = "about", label = L["Über und Befehle"], sub = L["Version, Befehle und Selbsttest."], icon = "Interface\\Icons\\INV_Misc_QuestionMark", order = 910, group = "amisia",
    create = function(parent)
        local f = W.Page(parent)
        -- the head row: the version and the self-test; the line under it, a newer version; then how many
        -- run Amisia with the link to the page Amisia-Versionen; the commands down to the page's end
        f:Bands({ "row", "line", "line", "row" })
        f.head = W.Text(f, T.FONT.title)
        -- the in-game self-test: a report of the client to copy into a chat with the developers
        f.selfTest = W.Button(f, L["Selbsttest"], 110, function() if ns.ShowSelfTest then ns.ShowSelfTest() end end)
        W.FitChip(f.selfTest, 110)
        f.selfTest.tip = L["Prüft Namen, Sperren, Gildenränge, Atlanten, Vorlagen und Client-Funktionen und zeigt einen Bericht zum Kopieren. Sendet nichts."]
        tipButton(f.selfTest)
        -- F-236: the news of the last versions (UI/WhatsNew.lua), any time (D-167)
        f.news = W.Link(f, L["Neuigkeiten"], function() if ns.ShowWhatsNew then ns.ShowWhatsNew(nil) end end)
        W.FitChip(f.news)
        W.Tooltip(f.news, L["Neuigkeiten"], L["Was die letzten Versionen von Amisia Neues bringen."])
        f:Place(1, { { f.head, fill = true } }, { f.news, f.selfTest })
        f.sub = f:Line(2)
        f.newer = f:Line(3)
        -- F-237: who runs which version is a page of its own (tab Gilde)
        f.seen = W.Text(f, T.FONT.title)
        f.versions = W.Link(f, L["Alle Versionen"], function() ns.ShowPage("versions") end)
        W.FitChip(f.versions)
        W.Tooltip(f.versions, L["Amisia-Versionen"], L["Wer in Gilde und Raid Amisia hat, mit Version, Modulen und Sprache (Reiter Gilde)."])
        f:Place(4, { { f.seen, fill = true } }, { f.versions })
        -- the commands, down to the page's end
        f.cmdTitle = W.Text(f, T.FONT.title, 300)
        f.cmdTitle:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X, f.top - 2)
        f.cmdTitle:SetText(L["Befehle"])
        f.text = W.ScrollText(f)
        f.text:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X, f.top - 20)
        f.text:SetPoint("BOTTOMRIGHT", -T.SCROLL_ROOM, 0)
        page = f
        return f
    end,
    refresh = function(f)
        refreshAt = GetTime()
        f.head:SetText(L["Amisia %s · Sync-Protokoll %d"]:format(ns.VERSION or "", ns.SYNC_PROTO or 1))
        f.sub:SetText("|cff8f86a3" .. L["Raid-Aufnahme, Loot, Rolls, Soft-Reserves und Export für die Amisia-Loot-Seite."] .. "|r")
        local newer, by = ns.VersionNewer()
        if newer then
            f.newer:SetText(colored(T.ORANGE, L["Es gibt eine neuere Version: %s (gesehen bei %s). Bitte aktualisieren."]:format(newer, by)))
            f.newer:Show()
        else
            f.newer:SetText("")
            f.newer:Hide()
        end
        -- the others seen with Amisia (the own client not counted)
        local me, n = ns.UnitFullName("player"), 0
        for _, e in ipairs(ns.VersionSeen()) do
            if not (me and ns.SameName(e.name, me)) then n = n + 1 end
        end
        f.seen:SetText(n == 1 and L["1 mit Amisia gesehen"] or L["%d mit Amisia gesehen"]:format(n))
        f.text:SetText(table.concat(ns.SlashHelpLines(ns.IsOfficerView()), "\n"))
    end }

-- New versions or a new sync state: the page builds again, at most once a second, only while shown.
local function soon()
    if not page or not page:IsShown() or ns.CurrentPage() ~= "about" or refreshPending then return end
    refreshPending = true
    local wait = refreshAt and math.max(0, 1 - (GetTime() - refreshAt)) or 0
    C_Timer.After(wait, function()
        refreshPending = false
        if page and page:IsShown() and ns.CurrentPage() == "about" then ns.Refresh() end
    end)
end
ns.Listen("SYNC_VERSIONS", soon)
ns.Listen("SYNC_STATE", soon)
end)
