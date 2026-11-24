-- Rolls: the running round and the last rounds of this session; the floating roll window stays.
-- The head row's links (D-167): "Wurf eintragen" while a round takes rolls by hand (a dialog, as
-- /amisia wurf), "Erneut ansagen" while the loot window has something to announce (as /amisia ansage).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
-- rows of 22 down to the footer (two hint lines): 44 + 18 x 22 = 440 of the 438 the content leaves
local ROWS, ROW_H = 18, 22

-- One line for a round: time, item, and the winner with kind and plus-one, the tie, or the state;
-- then the boss fight lockdown and the rolls entered by hand.
local function roundLine(r)
    local list = ns.RollRanking(r)
    local who
    if r.winner then
        local plus = ns.PlusLabel(r, r.winner)
        who = ("|cff4fbf7a%s|r (%s%s)"):format(r.winner, list[1] and list[1].rank or "?", plus and (", " .. plus) or "")
    elseif r.tie then
        who = L["|cffe0a344Gleichstand: %s|r"]:format(table.concat(r.tie, ", "))
    elseif r.done then
        who = L["|cff8f86a3niemand gewürfelt|r"]
    else
        who = L["läuft, noch %d s, %d Würfe"]:format(r.leftAt or 0, #list)
    end
    local extra = ""
    if r.lockdown then extra = extra .. L["  |cffe0a344Bosskampf, %d Zeilen nicht lesbar|r"]:format(r.hidden or 0) end
    local hand = ns.ManualRollCount and ns.ManualRollCount(r) or 0
    if hand > 0 then extra = extra .. L["  %d von Hand"]:format(hand) end
    if r.dirty then extra = extra .. L["  |cffe0a344Ergebnis nicht angesagt|r"] end
    return ("%s  %s  %s%s"):format(date("%H:%M", r.started or 0), r.name or "?", who, extra)
end
ns.RoundLine = roundLine

-- the last rounds: one column of 578 px (the list is 590 wide, its scroll bar beside it)
local COLS = { { "text", 6, 578, L["Letzte Runden"] } }

ns.RegisterPanel{ key = "rolls", label = "Rolls", sub = L["Die laufende Würfelrunde und wer gewürfelt hat."], icon = "Interface\\Icons\\INV_Misc_Dice_01", order = 20, group = "raid", officer = true,
    create = function(parent)
        local f = W.Page(parent)
        -- the head row: the running round, the roll window at the right
        f:Bands({ "row" })
        f.current = W.Text(f, T.FONT.body)
        f.open = W.Button(f, L["Roll-Fenster"], 120, function() ns.ShowRollFrame() end)
        W.FitChip(f.open, 120)
        f.addRoll = W.Link(f, L["Wurf eintragen"], function() W.LiftDialog(StaticPopup_Show("AMISIA_ADD_ROLL")) end)
        W.Tooltip(f.addRoll, L["Wurf eintragen"], L["Trägt einen Wurf von Hand in die Runde ein, etwa wenn der Chat im Bosskampf nicht lesbar ist."])
        f.again = W.Link(f, L["Erneut ansagen"], function() if ns.LootAnnounceAgain then ns.LootAnnounceAgain() end end)
        W.Tooltip(f.again, L["Erneut ansagen"], L["Sagt die Items des offenen Lootfensters noch einmal im Schlachtzugschat an."])
        f.addRoll:Hide()
        f.again:Hide()
        f.headRight = { f.addRoll, f.again, f.open }
        f:Place(1, { { f.current, fill = true } }, f.headRight, { shown = true })
        f:Footer({ { "hint", lines = 2, help = true } })
        f.headFrame, f.heads = f:Columns(COLS)
        f.list = f:List(ROWS, ROW_H, function(r) W.Cells(r, COLS) end, function(r, round) r.text:SetText(roundLine(round)) end, { fill = true })
        f.empty = f:Empty()
        return f
    end,
    refresh = function(f)
        local cur = ns.CurrentRoll()
        f.current:SetText(cur and not cur.done and L["Laufende Runde: %s"]:format(roundLine(cur)) or L["Keine laufende Runde."])
        f.addRoll:SetShown(ns.ManualRollRound and ns.ManualRollRound() ~= nil or false)
        f.again:SetShown(ns.LootAnnounceReady and ns.LootAnnounceReady() or false)
        f:Place(1, { { f.current, fill = true } }, f.headRight, { shown = true })
        f.hint:SetText((ns.Get("rolls.altClick") and L["Alt-Klick auf ein Item im Lootfenster startet eine Runde."]
            or L["Alt-Klick ist ausgeschaltet. Ein Item aus der Suche oben links: \"Roll-Runde starten\"."])
            .. L[" Im Bosskampf Würfe im Roll-Fenster von Hand eintragen."])
        local list = ns.RollHistory()
        f.list:SetItems(list)
        f.empty:Set(L["Noch keine Runde"], L["Die Runden dieser Sitzung stehen hier, sobald eine gewürfelt wurde."])
        f.empty:SetShown(#list == 0)
    end }

-- "Wurf eintragen": name and number in one box, read like /amisia wurf ("Vulo Sturmwind 87 os");
-- a wrong line keeps the dialog open with the reason in the chat.
local function rollBox(d) return (d.GetEditBox and d:GetEditBox()) or d.editBox or d.EditBox end
local USAGE = L["Name und Zahl, etwa: Vuloo 87 (Offspec: Vuloo 87 os)"]
local function addRoll(d)
    local box = rollBox(d)
    return box and ns.AddRollText(box:GetText() or "", USAGE) ~= nil
end
StaticPopupDialogs["AMISIA_ADD_ROLL"] = {
    text = L["Wurf eintragen: Name und Zahl, für Offspec \"os\" dahinter."],
    button1 = L["Eintragen"],
    button2 = L["Abbrechen"],
    hasEditBox = true,
    maxLetters = 60,
    OnShow = function(self)
        local box = rollBox(self)
        if box then
            box:SetText("")
            box:SetFocus()
        end
    end,
    -- true keeps the dialog open
    OnAccept = function(self) return not addRoll(self) end,
    EditBoxOnEnterPressed = function(box)
        local d = box:GetParent()
        if addRoll(d) then d:Hide() end
    end,
    EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- the links come and go with the loot window and the rounds
ns.Listen("LOOT_WINDOW", function()
    if ns.CurrentPage and ns.CurrentPage() == "rolls" and ns.Refresh then ns.Refresh() end
end)
end)
