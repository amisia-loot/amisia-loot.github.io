-- Raid-Notiz (F-196, D-126, Raid/RaidNote.lua): the raid note to write and send, its templates and the
-- own note. Officers, the raid leader and assistants (guild members in the own raid) edit and send it;
-- everyone else sees the note received there, read only. The own note below is everyone's and never
-- travels. The head row: the template picker, the name field, "Speichern", "Löschen"; at the right
-- "Fenster zeigen". Under the note's field the counter and the red "An Raid senden".
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.RAIDNOTE
local LAY = T.LAYOUT
local RN = ns.RaidNote

local GREY, ORANGE = "|cff8f86a3", "|cffe0a344"
local chosen          -- the template picked in this session

local function mayEdit() return (RN.CanSend()) end

-- a received note in an edit box: its codes as text (the box would show colours, textures and links)
local function plainText(c) return c and (c.text:gsub("|", "||")) or "" end

local function setBox(box, text)
    box.setting = true
    box:SetText(text or "")
    box.setting = false
end

local function saveSet(f)
    local name = f.name:GetText()
    if (name or ""):match("^%s*$") then name = chosen or "" end
    local ok, why = RN.SaveSet(name, f.note.box:GetText())
    if ok then
        chosen = why
        f.name:SetText("")
        ns.msg(L["Vorlage \"%s\" gespeichert."]:format(chosen))
    else
        ns.msg(why)
    end
    ns.Refresh()
end

local function deleteSet()
    if not chosen then return end
    local name = chosen
    W.Confirm(L["Vorlage löschen"], L["Die Vorlage \"%s\" löschen?"]:format(name), L["Löschen"], function()
        RN.DeleteSet(name)
        chosen = nil
        ns.Refresh()
    end)
end

local function send(f)
    local ok, why = RN.Send(f.note.box:GetText())
    if ok then
        ns.msg(L["Raid-Notiz an den Raid geschickt."])
    else
        ns.msg(why)
    end
    ns.Refresh()
end

local function counter(f)
    local text = f.note.box:GetText() or ""
    f.count:SetText(L["%d/%d Zeichen · %d/%d Zeilen"]:format(#text, RN.MAX_CHARS, RN.LineCount(text), RN.MAX_LINES))
end

ns.RegisterPanel{ key = "raidnote", label = L["Raid-Notiz"], sub = L["Cooldowns und Einteilungen für den Raid, auch im Kampf zu sehen."], icon = "Interface\\Icons\\INV_Misc_Note_02", order = 18, group = "raid",
    create = function(parent)
        local f = W.Page(parent)
        f:Bands({ "row", "line" })
        f.sets = W.Picker(f, S.SET_W, function(v)
            local text = RN.SetText(v)
            if not text then return end
            chosen = v
            if mayEdit() then
                setBox(f.note.box, text)
                RN.SetDraft(text)
            end
            ns.Refresh()
        end)
        W.Tooltip(f.sets, L["Vorlagen"], L["Eine gespeicherte Notiz laden, z. B. eine je Boss. Laden ersetzt den Text im Feld."])
        f.name = W.LineEdit(f, S.NAME_W, function() end)
        W.Tooltip(f.name, L["Name der Vorlage"], L["Unter diesem Namen speichert \"Speichern\" den Text; leer: die gewählte Vorlage."])
        f.save = W.Link(f, L["Speichern"], function() saveSet(f) end)
        f.del = W.Link(f, L["Löschen"], deleteSet)
        W.Tooltip(f.del, L["Vorlage löschen"], L["Löscht die gewählte Vorlage, nach einer Frage."])
        f.show = W.Link(f, L["Fenster zeigen"], function() if RN.Window then RN.Window.Toggle() end end)
        W.Tooltip(f.show, L["Raid-Notiz"], L["Zeigt oder schließt das Fenster mit der Notiz. Auch /amisia notiz und im Minimap-Menü."])
        for _, b in ipairs({ f.save, f.del, f.show }) do W.FitChip(b) end
        f:Place(1, { f.sets, f.name, f.save, f.del }, { f.show })
        f.status = f:Line(2)
        local y = f.top
        f.note = W.EditArea(f)
        f.note:SetPoint("TOPLEFT", 0, y)
        f.note:SetPoint("TOPRIGHT", 0, y)
        f.note:SetHeight(S.EDIT_H)
        f.note.box:SetMaxLetters(RN.MAX_CHARS)
        if f.note.box.SetMaxBytes then f.note.box:SetMaxBytes(RN.MAX_CHARS + 1) end
        f.note.box:HookScript("OnTextChanged", function(self, userInput)
            if self.setting then return end
            if userInput then
                if f.readOnly then
                    setBox(self, plainText(RN.Current()))
                else
                    RN.SetDraft(self:GetText())
                end
            end
            counter(f)
        end)
        y = y - S.EDIT_H - S.GAP
        f.count = W.Text(f, T.FONT.hint, S.COUNT_W * 2)
        f.count:SetPoint("TOPLEFT", LAY.TEXT_X, y - 5)
        f.send = W.Button(f, L["An Raid senden"], 130, function() send(f) end)
        W.FitChip(f.send, 130)
        f.send:SetPoint("TOPRIGHT", 0, y)
        W.Tooltip(f.send, L["An Raid senden"], L["Schickt die Notiz an alle im Raid mit Amisia; sie ersetzt die vorige. Nicht im Kampf."])
        y = y - T.BUTTON_H - S.GAP
        f.ownTitle = W.Text(f, T.FONT.title, 300)
        f.ownTitle:SetPoint("TOPLEFT", LAY.TEXT_X, y)
        f.ownTitle:SetText(L["Eigene Notiz"])
        f.ownHint = W.Text(f, T.FONT.hint, 300)
        f.ownHint:SetPoint("TOPRIGHT", -LAY.TEXT_X, y)
        f.ownHint:SetJustifyH("RIGHT")
        f.ownHint:SetText(L["Nur für dich, wird nie gesendet."])
        y = y - S.FROM_H - S.GAP
        f.own = W.EditArea(f)
        f.own:SetPoint("TOPLEFT", 0, y)
        f.own:SetPoint("TOPRIGHT", 0, y)
        f.own:SetHeight(S.OWN_H)
        f.own.box:SetMaxLetters(RN.MAX_OWN)
        if f.own.box.SetMaxBytes then f.own.box:SetMaxBytes(RN.MAX_OWN + 1) end
        f.own.box:HookScript("OnTextChanged", function(self, userInput)
            if userInput and not self.setting then RN.SetOwn(self:GetText()) end
        end)
        f:Footer({ { "hint", lines = 2 } })
        f.hint:SetText(L["{stern} {kreis} {diamant} {dreieck} {mond} {quadrat} {kreuz} {totenkopf} (auch {star} ... {skull}, {rt1} ... {rt8}) werden Zielmarkierungen; Namen aus dem Raid stehen in Klassenfarbe, deine Zeilen gelb."])
        return f
    end,
    refresh = function(f)
        local may, why = RN.CanSend()
        local c = RN.Current()
        f.readOnly = not may
        -- the templates
        local values = {}
        for _, s in ipairs(RN.Sets()) do values[#values + 1] = { value = s.name, text = s.name } end
        if chosen and not RN.SetText(chosen) then chosen = nil end
        f.sets:SetValues(#values > 0 and values or { { value = "", text = L["Keine Vorlagen"] } })
        f.sets:SetValue(chosen or (#values > 0 and "" or ""))
        for _, w in ipairs({ f.sets, f.name, f.save, f.del }) do w:SetShown(may) end
        f.del:SetEnabled(chosen ~= nil)
        -- the note's field: the own draft, or the received note read only
        local box = f.note.box
        if not box:HasFocus() then
            if may then
                setBox(box, RN.Draft() ~= "" and RN.Draft() or plainText(c))
            else
                setBox(box, plainText(c))
            end
        end
        counter(f)
        local held = may and RN.SendHeld()
        f.send:SetShown(may)
        f.send:SetEnabled(may and not held)
        local from = c and L["Aktuelle Notiz von %s, %s."]:format(c.by, date("%H:%M", c.at)) or L["Noch keine Raid-Notiz."]
        if may then
            f.status:SetText(from .. (held and (" " .. ORANGE .. held .. "|r") or ""))
        else
            f.status:SetText(from .. " " .. GREY .. (why or "") .. "|r")
        end
        if not f.own.box:HasFocus() then setBox(f.own.box, RN.Own()) end
    end }

local function again()
    if ns.CurrentPage and ns.CurrentPage() == "raidnote" then ns.RefreshSoon() end
end
ns.Listen("RAIDNOTE", again)
-- the right to send follows the raid rank and the fight
ns.OnEvent("GROUP_ROSTER_UPDATE", again)
ns.OnEvent("PLAYER_REGEN_DISABLED", again)
ns.OnEvent("PLAYER_REGEN_ENABLED", again)
