-- Rolls: the running round and the last rounds of this session; the floating roll window stays.
local ADDON, ns = ...
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

local page
-- For tests: the page frame once built.
function ns.RollsPageFrame() return page end

-- the last rounds: one column of 578 px (the list is 590 wide, its scroll bar beside it)
local COLS = { { "text", 6, 578, L["Letzte Runden"] } }

ns.RegisterPanel{ key = "rolls", label = "Rolls", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", order = 30, group = "raid", officer = true,
    create = function(parent)
        local f = W.Page(parent)
        -- the head row: the running round, the roll window at the right
        f:Bands({ "row" })
        f.current = W.Text(f, T.FONT.body)
        f.open = W.Button(f, L["Roll-Fenster"], 120, function() ns.ShowRollFrame() end)
        W.FitChip(f.open, 120)
        f:Place(1, { { f.current, fill = true } }, { f.open })
        f:Footer({ { "hint", lines = 2 } })
        f.headFrame, f.heads = f:Columns(COLS)
        f.list = f:List(ROWS, ROW_H, function(r) W.Cells(r, COLS) end, function(r, round) r.text:SetText(roundLine(round)) end)
        f.empty = f:Empty()
        page = f
        return f
    end,
    refresh = function(f)
        local cur = ns.CurrentRoll()
        f.current:SetText(cur and not cur.done and L["Laufende Runde: %s"]:format(roundLine(cur)) or L["Keine laufende Runde."])
        f.hint:SetText((ns.Get("rolls.altClick") and L["Alt-Klick auf ein Item im Lootfenster startet eine Runde."]
            or L["Alt-Klick ist ausgeschaltet. /amisia roll <Item-Link> startet eine Runde."])
            .. L[" Im Bosskampf Würfe im Roll-Fenster von Hand eintragen."])
        local list = ns.RollHistory()
        f.list:SetItems(list)
        f.empty:Set(L["Noch keine Runde"], L["Die Runden dieser Sitzung stehen hier, sobald eine gewürfelt wurde."])
        f.empty:SetShown(#list == 0)
    end }
