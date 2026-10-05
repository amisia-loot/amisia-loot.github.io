-- Rolls: the running round and the last rounds of this session; the floating roll window stays.
local ADDON, ns = ...
local W = ns.W

-- One line for a round: time, item, and the winner with kind and plus-one, the tie, or the state;
-- then the boss fight lockdown and the rolls entered by hand.
local function roundLine(r)
    local list = ns.RollRanking(r)
    local who
    if r.winner then
        local plus = ns.PlusLabel(r, r.winner)
        who = ("|cff4fbf7a%s|r (%s%s)"):format(r.winner, list[1] and list[1].rank or "?", plus and (", " .. plus) or "")
    elseif r.tie then
        who = "|cffe0a344Gleichstand: " .. table.concat(r.tie, ", ") .. "|r"
    elseif r.done then
        who = "|cff8f86a3niemand gewürfelt|r"
    else
        who = ("läuft, noch %d s, %d Würfe"):format(r.leftAt or 0, #list)
    end
    local extra = ""
    if r.lockdown then extra = extra .. ("  |cffe0a344Bosskampf, %d Zeilen nicht lesbar|r"):format(r.hidden or 0) end
    local hand = ns.ManualRollCount and ns.ManualRollCount(r) or 0
    if hand > 0 then extra = extra .. ("  %d von Hand"):format(hand) end
    if r.dirty then extra = extra .. "  |cffe0a344Ergebnis nicht angesagt|r" end
    return ("%s  %s  %s%s"):format(date("%H:%M", r.started or 0), r.name or "?", who, extra)
end
ns.RoundLine = roundLine

local page
-- For tests: the page frame once built.
function ns.RollsPageFrame() return page end

ns.RegisterPanel{ key = "rolls", label = "Rolls", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", order = 30, group = "raid", officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.current = W.Text(f, "GameFontHighlight", 590, true)
        f.current:SetPoint("TOPLEFT", 0, -2)
        local open = W.Button(f, "Roll-Fenster", 120, function() ns.ShowRollFrame() end)
        open:SetPoint("TOPLEFT", 0, -26)
        f.hint = W.Text(f, "GameFontDisableSmall", 440, true)
        f.hint:SetPoint("LEFT", open, "RIGHT", 10, 0)
        local head = W.Text(f, "GameFontNormal", 300)
        head:SetPoint("TOPLEFT", 0, -60)
        head:SetText("Letzte Runden")
        f.list = W.List(f, 12, 22, function(r)
            r.text = W.Text(r, "GameFontHighlightSmall", 580)
            r.text:SetPoint("LEFT", 6, 0)
        end, function(r, round) r.text:SetText(roundLine(round)) end)
        f.list:SetPoint("TOPLEFT", 0, -80)
        -- 12 px short of the right edge: room for the list's scroll bar
        f.list:SetPoint("TOPRIGHT", -12, -80)
        page = f
        return f
    end,
    refresh = function(f)
        local cur = ns.CurrentRoll()
        f.current:SetText(cur and not cur.done and ("Laufende Runde: " .. roundLine(cur)) or "Keine laufende Runde.")
        f.hint:SetText((ns.Get("rolls.altClick") and "Alt-Klick auf ein Item im Lootfenster startet eine Runde."
            or "Alt-Klick ist ausgeschaltet. /amisia roll <Item-Link> startet eine Runde.")
            .. " Im Bosskampf Würfe im Roll-Fenster von Hand eintragen.")
        f.list:SetItems(ns.RollHistory())
    end }
