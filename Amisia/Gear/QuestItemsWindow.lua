-- The window "Questgegenstände aufräumen" (F-173, D-105, AmisiaQuestItems, tokens T.QUESTITEMS): the quest
-- items in the bags (Gear/QuestItems.lua) in the groups "Sicher überflüssig", "Wahrscheinlich
-- überflüssig", "Unklar" and "Behalten", each row with the item's icon, name and count over the reason in
-- words; the item's tooltip on hover (the bag slot's), a right click "Behalten" / "Nicht mehr behalten".
-- Only the rows of "sicher" have the link "Löschen" (QI.AskDelete: the question unless
-- quests.itemNoAsk); the red head button "Nächsten sicheren löschen (N)" walks them one per click. A
-- stack being deleted keeps its row ("wird gelöscht ...") until the bag update shows it gone. In combat
-- and the lockdown only "Im Kampf nicht verfügbar". Movable, its place in settings.questItemsWindow
-- (reset with the other windows); /amisia questgegenstaende (en questitems) and the page Quests open it.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.QUESTITEMS
local QI = ns.QuestItems

local QW = {}
ns.QuestItemsWindow = QW

local GREY, GOLD_TEXT, GREEN = T.GREY, T.GOLD_TEXT, T.GREEN
local YELLOW = "|cffffd100"
local LIST_W = S.W - 2 * S.PAD - S.SCROLL
local GROUP_TITLE = { safe = L["Sicher überflüssig"], likely = L["Wahrscheinlich überflüssig"], unclear = L["Unklar"],
    keep = L["Behalten##Questgegenstände"] }
local GROUP_COLOR = { safe = GREEN, likely = YELLOW, unclear = GREY, keep = GREY }
QW.GROUP_TITLE = GROUP_TITLE

local F

local function windowState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.questItemsWindow) ~= "table" then AmisiaDB.settings.questItemsWindow = {} end
    return AmisiaDB.settings.questItemsWindow
end

local function place()
    if F then W.PlaceWindow(F, windowState(), "CENTER", UIParent, "CENTER", 0, 60) end
end

function ns.ResetQuestItemsPosition()
    local st = windowState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

local function iconOf(id)
    local api = _G.C_Item
    local f = api and api.GetItemIconByID
    local ok, icon = false, nil
    if type(f) == "function" then ok, icon = pcall(f, id) end
    return ok and ns.Plain(icon) or 134400
end

local function nameOf(e)
    local name = ns.ItemName(e.id)
    if name:match("^Item %d+$") and e.link then name = e.link:match("%[(.-)%]") or name end
    return name
end

local function rowTip(r)
    local x = r.item
    if not x or x.kind ~= "item" then return end
    local e = x.e
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    local st = e.stacks and e.stacks[1]
    if st and GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(st.bag, st.slot)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(e.id)
    else
        GameTooltip:SetHyperlink("item:" .. e.id)
    end
    GameTooltip:AddLine(L["Rechtsklick: behalten oder nicht mehr behalten."], 0.31, 0.82, 0.42, true)
    GameTooltip:Show()
end

local function onRowClick(r, button)
    local x = r.item
    if not x or x.kind ~= "item" or button ~= "RightButton" or x.e.pending then return end
    local id = x.e.id
    if QI.Kept(id) then
        W.Menu(r, { { L["Nicht mehr behalten"], function() QI.SetKeep(id, false) end } })
    else
        W.Menu(r, { { L["Behalten"], function() QI.SetKeep(id, true) end,
            tip = L["Amisia bietet diesen Gegenstand nicht mehr zum Löschen an (für alle Charaktere des Accounts)."] } })
    end
end

local function buildRow(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(S.ICON, S.ICON)
    r.icon:SetPoint("LEFT", S.ICON_X, 0)
    r.name = W.Text(r, T.FONT.body, LIST_W - S.TEXT_X - S.LINK_W - 8)
    r.name:SetPoint("TOPLEFT", S.TEXT_X, -3)
    r.sub = W.Text(r, T.FONT.hint, LIST_W - S.TEXT_X - S.LINK_W - 8)
    r.sub:SetPoint("TOPLEFT", S.TEXT_X, -18)
    r.head = W.Text(r, T.FONT.title, LIST_W - 2 * S.ICON_X)
    r.head:SetPoint("LEFT", S.ICON_X, -4)
    r.del = W.Link(r, L["Löschen##Questgegenstand"], function(self)
        local x = self:GetParent().item
        if x and x.kind == "item" then QI.AskDelete(x.e.id) end
    end)
    W.FitChip(r.del, nil, S.LINK_W)
    r.del:SetPoint("RIGHT", -4, 0)
    W.Tooltip(r.del, L["Löschen##Questgegenstand"], L["Löscht einen Stapel dieses Gegenstands, nach einer Frage. Gelöschte Questgegenstände lassen sich nicht zurückholen."])
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", onRowClick)
    r:SetScript("OnEnter", rowTip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fillRow(r, x)
    if x.kind == "head" then
        r.icon:Hide(); r.name:Hide(); r.sub:Hide(); r.del:Hide()
        r.head:SetText(GOLD_TEXT .. GROUP_TITLE[x.group] .. (" (%d)"):format(x.n) .. "|r")
        r.head:Show()
        return
    end
    local e = x.e
    r.head:Hide()
    r.icon:SetTexture(iconOf(e.id))
    r.icon:Show()
    local count = e.count > 1 and (" x%d"):format(e.count) or ""
    r.name:SetText(nameOf(e) .. GREY .. count .. "|r")
    r.name:Show()
    local sub
    if e.pending then
        sub = L["wird gelöscht ..."]
    else
        sub = (GROUP_COLOR[x.group] or GREY) .. QI.ReasonText(e.reason, e.quest) .. "|r"
        if #e.stacks > 1 then sub = sub .. GREY .. " · " .. L["%d Stapel"]:format(#e.stacks) .. "|r" end
    end
    r.sub:SetText(sub)
    r.sub:Show()
    r.del:SetShown(x.group == "safe" and not e.pending and QI.CanDeleteAtAll())
end

local function build()
    if F then return F end
    local h = S.TOP + S.HEAD_H + S.LIST_GAP + S.ROWS * S.ROW_H + S.BOTTOM_H
    F = W.Window("AmisiaQuestItems", S.W, h, { title = L["Questgegenstände aufräumen"], strata = "HIGH",
        onDragStop = function(f) W.SaveWindowPlace(f, windowState()) end })
    F.next = W.Button(F, "", 120, function() QI.DeleteNext() end)
    F.next:SetPoint("TOPRIGHT", -S.PAD, -S.TOP)
    W.Tooltip(F.next, L["Nächsten sicheren löschen"], L["Löscht den ersten sicher überflüssigen Stapel, nach einer Frage; jeder Klick einen."])
    F.status = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.status:SetPoint("LEFT", F, "TOPLEFT", S.PAD, -(S.TOP + S.HEAD_H / 2))
    F.list = W.List(F, S.ROWS, S.ROW_H, buildRow, fillRow)
    F.list:SetWidth(LIST_W)
    F.list:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.HEAD_H + S.LIST_GAP))
    F.empty = W.Text(F, T.FONT.dim, S.W - 4 * S.PAD, true)
    F.empty:SetPoint("TOP", F, "TOP", 0, -(S.TOP + S.HEAD_H + S.LIST_GAP + 40))
    F.empty:SetJustifyH("CENTER")
    F.hint = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD - S.SET_W)
    F.hint:SetPoint("BOTTOMLEFT", S.PAD, S.BOTTOM_H / 2 - 4)
    F.hint:SetText(L["Nur die Taschen. Löschen nur bei \"sicher\". Rechtsklick: behalten."])
    -- the way to its switches (D-123): the section "Questgegenstände"
    F.settings = W.Link(F, L["Einstellungen"], function()
        if ns.ShowSettingsSection then ns.ShowSettingsSection("questitems") end
    end)
    F.settings:SetPoint("RIGHT", F, "BOTTOMRIGHT", -S.PAD, S.BOTTOM_H / 2 + 2)
    W.Tooltip(F.settings, L["Einstellungen"], L["Questgegenstände im Tooltip, ohne Nachfrage löschen, Fenster bei Gegenständen, die eine Quest starten."])
    place()
    return F
end
QW.Build = build

-- The rows: per group its head and its items; the stack being deleted stays in "sicher" until its bag
-- update came.
local function rowsOf(s)
    local out = {}
    local p = QI.pending
    if p then
        local found = false
        for _, e in ipairs(s.safe) do
            if e.id == p.id then
                e.pending, found = true, true
            end
        end
        if not found then
            table.insert(s.safe, 1, { id = p.id, count = p.count, stacks = {}, pending = true, group = "safe",
                link = nil, reason = "seen" })
        end
    end
    for _, g in ipairs({ "safe", "likely", "unclear", "keep" }) do
        local list = s[g]
        if #list > 0 then
            out[#out + 1] = { kind = "head", group = g, n = #list }
            for _, e in ipairs(list) do out[#out + 1] = { kind = "item", group = g, e = e } end
        end
    end
    return out
end

local function refresh()
    if not F then return end
    local s, why = QI.Scan()
    if why == "combat" then
        F.list:SetItems({})
        F.list:Hide()
        F.next:Hide()
        F.status:SetText("")
        F.empty:SetText(L["Im Kampf nicht verfügbar."])
        F.empty:Show()
        QW.rows = {}
        return
    end
    local rows = rowsOf(s)
    QW.rows = rows
    F.list:Show()
    F.list:SetItems(rows)
    local n = #s.safe
    if not QI.Ready() then
        F.status:SetText(L["Warte, bis das Spiel die abgeschlossenen Quests meldet ..."])
    else
        local parts = { L["%d sicher"]:format(#s.safe), L["%d wahrscheinlich"]:format(#s.likely), L["%d unklar"]:format(#s.unclear) }
        if s.needed > 0 then parts[#parts + 1] = L["%d noch gebraucht"]:format(s.needed) end
        F.status:SetText(table.concat(parts, " · "))
    end
    local can = n > 0 and QI.CanDeleteAtAll()
    F.next:SetText(L["Nächsten sicheren löschen (%d)"]:format(n))
    W.FitChip(F.next)
    F.next:SetShown(can)
    F.status:SetWidth(S.W - 2 * S.PAD - (can and (F.next:GetWidth() + 8) or 0))
    if #rows == 0 then
        F.empty:SetText(s.needed > 0 and L["Alle Questgegenstände in den Taschen werden noch gebraucht."]
            or L["Keine Questgegenstände in den Taschen."])
        F.empty:Show()
    else
        F.empty:Hide()
    end
end
QW.Refresh = refresh

function QW.Show()
    build()
    F:Show()
    if F.Raise then F:Raise() end
    refresh()
end

function QW.Hide()
    if F then F:Hide() end
end

function QW.Shown() return F ~= nil and F:IsShown() end

function QW.Toggle()
    if QW.Shown() then QW.Hide() else QW.Show() end
end

ns.Listen("QUEST_ITEMS", function()
    if QW.Shown() then refresh() end
end)
