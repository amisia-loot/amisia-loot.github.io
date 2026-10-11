-- Guild bank: four views behind the chips at the top.
--   Bestand   the learned raid materials with their last count, and a small editor (officers: take
--             a material out per row, add one by link)
--   Bedarf    the needs the officers set (minimum and target) against the last count, coloured by
--             the shortfall, with the pledges; officers set needs, everybody pledges ("Spenden
--             zusagen") or takes a pledge back
--   Protokoll the saved guild bank log (BankLog.lua) with filters by tab, kind and a search
--   Text      the shortfalls as text for the guild chat or Discord, to copy
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local box   -- the link box of the editor, for the shift-click hook below
local page
local BANK_ROWS = 17      -- 26 (chips) + 62 (state, editor) + 17 * 22 = 462 of 478 px
-- the log: 18 rows of 22 under the filters and the column heads (44 + 396 of the view's 452)
local NEED_ROWS, PLEDGE_ROWS, LOG_ROWS = 8, 7, 18
local VIEWS = { bestand = true, bedarf = true, log = true, text = true }
local view                -- the chosen view; nil: by the officer view

function ns.BankPageFrame() return page end

local function shownView()
    if view then return view end
    return ns.IsOfficerView() and "bestand" or "bedarf"
end

-- Opens the page in a view ("bestand", "bedarf", "log", "text").
function ns.ShowBank(v)
    if VIEWS[v] then view = v end
    ns.ShowPage("bank")
end

local function setView(v)
    view = v
    ns.Refresh()
end

local LEVEL_COLOR = { low = T.RED, target = T.ORANGE, ok = T.GREEN, unknown = T.GREY }

---------------------------------------------------------------------------
-- Bestand: the counted materials and the editor
---------------------------------------------------------------------------
local function buildStock(f)
    -- the count's state (two lines), the editor (officers), the list
    local S = W.Page(f, { view = true })
    f.stock = S
    S:Bands({ { "line", lines = 2 }, "row" })
    f.state = S:Line(1)
    -- add by link: shift-click an item while the box has the focus, or type an item id
    f.add = {}
    f.add.box = W.LineEdit(S, 260)
    box = f.add.box
    local function add()
        local ok, text = ns.AddMat(f.add.box:GetText() or "")
        ns.msg(text)
        if ok then f.add.box:SetText("") end
        ns.Refresh()
    end
    f.add.box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        add()
    end)
    f.add.button = W.Button(S, L["Hinzufügen##Bank"], 110, add)
    W.FitChip(f.add.button, 110)
    f.add.hint = W.Text(S, T.FONT.hint)
    f.add.hint:SetText(L["Link mit Shift-Klick einfügen"])
    S:Place(2, { f.add.box, f.add.button, { f.add.hint, fill = true } })
    -- 17 rows fit the page under the chips, the state and the editor; the wheel scrolls the rest
    f.list = S:List(BANK_ROWS, 22, function(r)
        r.name = W.Text(r, T.FONT.text, 300)
        r.name:SetPoint("LEFT", 6, 0)
        r.count = W.Text(r, T.FONT.text, 80)
        r.count:SetJustifyH("RIGHT")
        r.remove = W.Button(r, L["Weg##Bank"], 46, function(self)
            local row = self:GetParent()
            if not (row and row.item) then return end
            local _, text = ns.RemoveMat(row.item.id)
            ns.msg(text)
            ns.Refresh()
        end, { height = T.ROW_BUTTON_H })
        r.remove:SetPoint("RIGHT", -4, 0)
        -- as wide as its word needs ("Weg", "Remove"); the count stays 10 px to its left
        W.FitChip(r.remove, 46)
        r.count:SetPoint("RIGHT", r.remove, "LEFT", -10, 0)
        W.Tooltip(r.remove, L["Herausnehmen"], L["Nimmt das Material aus der Liste. Amisia lernt es dann nicht wieder; /amisia mats add <Link> holt es zurück."])
    end, function(r, e)
        r.name:SetText(ns.ItemName(e.id) .. (e.manual and (" " .. T.GREY .. L["(von Hand)"] .. "|r") or ""))
        r.count:SetText(e.count and tostring(e.count) or "-")
        if ns.IsOfficerView() then r.remove:Show() else r.remove:Hide() end
    end)
    -- the count and the button hang on the row's right and move with it
end

local function refreshStock(f, on)
    for _, w in ipairs({ f.stock, f.state, f.list }) do w:SetShown(on) end
    local officer = ns.IsOfficerView()
    for _, w in ipairs({ f.add.box, f.add.button, f.add.hint }) do w:SetShown(on and officer) end
    if not on then return end
    local hidden = ns.HiddenMatCount()
    local n = #ns.MAT_ORDER
    local head = L["%d von %d Raidmaterialien%s%s. "]:format(n, ns.MAT_CAP,
        hidden > 0 and L[" · %d herausgenommen"]:format(hidden) or "",
        n > BANK_ROWS and L[" · %d von %d sichtbar, Mausrad"]:format(BANK_ROWS, n) or "")
    local bank = ns.Bank()
    if not ns.HasMats() then
        f.state:SetText(T.GREY .. L["Noch keine Raidmaterialien."] .. "|r " .. L["Amisia lernt sie in Raidaufnahmen von selbst: Handwerkswaren, die droppen, geplündert oder vergeben werden. Von Hand: Link unten einfügen."])
    elseif not (bank and bank.counts) then
        f.state:SetText(head .. T.GREY .. L["Noch nicht gezählt."] .. "|r " .. L["Öffne die Gildenbank einmal, dann zählt Amisia die Materialien."])
    else
        local hiddenTabs = (bank.total or 0) - (bank.tabs or 0)
        f.state:SetText(head .. L["Gezählt am %s von %s · %d von %d sichtbaren Tabs mit Gegenständen%s"]:format(
            ns.FmtDate(bank.at) .. " " .. date("%H:%M", bank.at), bank.by or "?", bank.filled or 0, bank.tabs or 0,
            hiddenTabs > 0 and (" · " .. T.ORANGE .. L["%d Tabs nicht sichtbar"]:format(hiddenTabs) .. "|r") or ""))
    end
    local counts = bank and bank.counts or {}
    local items = {}
    for _, id in ipairs(ns.MAT_ORDER) do
        local e = ns.MatInfo(id)
        items[#items + 1] = { id = id, count = counts[id], manual = e and e.manual }
    end
    f.list:SetItems(items)
end

---------------------------------------------------------------------------
-- Bedarf: needs, shortfalls, pledges
---------------------------------------------------------------------------
-- column x positions of the needs rows and their heads (right edges of the numbers)
local COL = { name = 6, have = 262, min = 322, target = 382, short = 442, pledged = 512 }
local NUM_W = 56

local function pickNeed(N, id)
    N.pick:SetValue(id)
    local e = ns.BankNeeds().list[id]
    N.min:SetValue(e and e.min or 0)
    N.target:SetValue(e and e.target or 0)
    N.pPick:SetValue(id)
    local short = 0
    for _, r in ipairs(ns.BankNeedList()) do if r.id == id then short = r.short or 0 end end
    N.pCount:SetValue(math.max(1, short))
end

local function buildNeeds(f)
    -- the state, the officers' editor, the pledge line, the needs, the pledges
    local N = W.Page(f, { view = true })
    N:Bands({ "line", "row", "row" })
    N.state = N:Line(1)
    -- the officers' editor: material, minimum, target
    N.pick = W.Picker(N, 190, function(v) pickNeed(N, v) end)
    N.minLabel = W.Text(N, T.FONT.text)
    N.minLabel:SetText(L["Min."])
    N.min = W.Stepper(N, 100)
    N.min:Configure(0, 9995, 5)
    N.min:SetValue(0)
    N.targetLabel = W.Text(N, T.FONT.text)
    N.targetLabel:SetText(L["Ziel"])
    N.target = W.Stepper(N, 100)
    N.target:Configure(0, 9995, 5)
    N.target:SetValue(0)
    N.set = W.Button(N, L["Setzen##Bedarf"], nil, function()
        local id = N.pick:GetValue()
        if not id then
            ns.msg(L["Zuerst ein Material wählen."])
            return
        end
        local ok, why = ns.SetBankNeed(id, N.min.current or 0, N.target.current or 0)
        if not ok then ns.msg(why) end
        ns.Refresh()
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(N.set, 60)
    W.Tooltip(N.set, L["Bedarf setzen"], L["Minimum und Ziel 0 nehmen den Bedarf heraus. Die Liste geht an alle Amisia-Nutzer der Gilde; es zählt nur die eines Offiziers."])
    N.minLabel:SetWidth(N.minLabel:GetStringWidth() + 2)
    N.targetLabel:SetWidth(N.targetLabel:GetStringWidth() + 2)
    N:Place(2, { N.pick, { N.minLabel, gap = 8 }, { N.min, gap = 4 }, { N.targetLabel, gap = 8 }, { N.target, gap = 4 }, { N.set, gap = 8 } })
    -- everybody: pledge a donation for a needed material
    N.pPick = W.Picker(N, 190, function(v) pickNeed(N, v) end)
    N.pCount = W.Stepper(N, 100)
    N.pCount:Configure(1, 9999, 1)
    N.pCount:SetValue(1)
    N.pledge = W.Button(N, L["Spenden zusagen"], nil, function()
        local id = N.pPick:GetValue()
        if not id then
            ns.msg(L["Zuerst ein Material wählen."])
            return
        end
        local ok, why = ns.PledgeBankNeed(id, N.pCount.current or 1)
        if ok then
            ns.msg(L["Zugesagt: %d %s. Die Offiziere sehen es in ihrer Liste."]:format(N.pCount.current or 1, ns.ItemName(id)))
        else
            ns.msg(why)
        end
        ns.Refresh()
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(N.pledge, 100)
    W.Tooltip(N.pledge, L["Spenden zusagen"], L["Sagt den Offizieren zu, so viel in die Gildenbank zu legen. Die Zusage gilt einige Tage."])
    N.withdraw = W.Button(N, L["Zurückziehen"], nil, function()
        local id = N.pPick:GetValue()
        if id then ns.PledgeBankNeed(id, 0) end
        ns.Refresh()
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(N.withdraw, 80)
    N:Place(3, { N.pPick, { N.pCount, gap = 8 }, { N.pledge, gap = 8 }, { N.withdraw, gap = 8 } })
    -- column heads: the numbers right-aligned on their right edges
    local cols = { { "name", COL.name, 180, L["Material"] } }
    for _, c in ipairs({ { "have", L["Bestand"] }, { "min", L["Minimum"] }, { "target", L["Ziel"] }, { "short", L["Fehlt"] },
        { "pledged", L["Zugesagt"] } }) do
        cols[#cols + 1] = { c[1], COL[c[1]] - NUM_W, NUM_W, c[2], justify = "RIGHT" }
    end
    N.headFrame, N.heads = N:Columns(cols)
    N.list = N:List(NEED_ROWS, 22, function(r)
        r.name = W.Text(r, T.FONT.text, 190)
        r.name:SetPoint("LEFT", COL.name, 0)
        r.cells = {}
        for _, key in ipairs({ "have", "min", "target", "short", "pledged" }) do
            local c = W.Text(r, T.FONT.text, NUM_W)
            c:SetJustifyH("RIGHT")
            c:SetPoint("LEFT", COL[key] - NUM_W, 0)
            r.cells[key] = c
        end
        r.remove = W.ResetButton(r, T.RESET, function(self)
            local row = self:GetParent()
            if not (row and row.item) then return end
            local ok, why = ns.SetBankNeed(row.item.id, 0, 0)
            if not ok then ns.msg(why) end
            ns.Refresh()
        end)
        r.remove:SetPoint("RIGHT", -4, 0)
        W.Tooltip(r.remove, L["Bedarf herausnehmen"], L["Nimmt den Bedarf dieses Materials aus der Liste der Gilde."])
        r:SetScript("OnClick", function(self) if self.item then pickNeed(N, self.item.id) end end)
    end, function(r, e)
        r.name:SetText(e.name)
        local color = LEVEL_COLOR[e.level] or ""
        r.cells.have:SetText(e.have and (color .. e.have .. "|r") or (T.GREY .. "?|r"))
        r.cells.min:SetText(e.min > 0 and tostring(e.min) or "-")
        r.cells.target:SetText(e.target and tostring(e.target) or "-")
        r.cells.short:SetText((e.short and e.short > 0) and (color .. e.short .. "|r") or (e.level == "ok" and (T.GREEN .. L["ok"] .. "|r") or "-"))
        r.cells.pledged:SetText(e.pledged > 0 and tostring(e.pledged) or "-")
        r.remove:SetShown(ns.IsOfficerView())
    end)
    N.empty = N:Empty(420)
    -- the pledges: their count and how long they last in the column head
    local pledgeTop = N.listTop - NEED_ROWS * 22 - 2 * T.LAYOUT.GAP
    local _, ph = N:Columns({ { "title", 6, 580 } }, { top = pledgeTop })
    N.pledgeHead = ph.title
    N.pledges = N:List(PLEDGE_ROWS, 20, function(r)
        r.name = W.Text(r, T.FONT.text, 180)
        r.name:SetPoint("LEFT", 6, 0)
        r.what = W.Text(r, T.FONT.text, 200)
        r.what:SetPoint("LEFT", 192, 0)
        r.count = W.Text(r, T.FONT.text, NUM_W)
        r.count:SetJustifyH("RIGHT")
        r.count:SetPoint("LEFT", 398, 0)
        r.till = W.Text(r, T.FONT.hint, 100)
        r.till:SetPoint("LEFT", 462, 0)
        r.remove = W.ResetButton(r, T.RESET, function(self)
            local row = self:GetParent()
            if not (row and row.item) then return end
            ns.RemovePledge(row.item.name, row.item.item)
            ns.Refresh()
        end)
        r.remove:SetPoint("RIGHT", -4, 0)
        W.Tooltip(r.remove, L["Zusage abhaken"], L["Die eigene Zusage zieht das zurück; die eines anderen verschwindet nur bei dir (die Spende kam an)."])
    end, function(r, p)
        r.name:SetText(p.name)
        r.what:SetText(ns.ItemName(p.item))
        r.count:SetText(tostring(p.count))
        r.till:SetText(L["bis %s"]:format(ns.FmtDate(p.expires)))
        r.remove:SetShown(ns.IsOfficerView() or ns.SameName(p.name, ns.UnitFullName("player")))
    end)
    f.need = N
end

local function refreshNeeds(f, on)
    local N = f.need
    N:SetShown(on)
    if not on then return end
    local officer = ns.IsOfficerView()
    for _, w in ipairs({ N.pick, N.minLabel, N.min, N.targetLabel, N.target, N.set }) do w:SetShown(officer) end
    local rows = ns.BankNeedList()
    local n, low = ns.BankNeeds(), 0
    for _, r in ipairs(rows) do if r.level == "low" or r.level == "target" then low = low + 1 end end
    if #rows == 0 then
        N.state:SetText(officer and L["Noch kein Bedarf. Material wählen, Minimum (und Ziel) einstellen, Setzen."]
            or L["Die Offiziere haben noch keinen Bedarf für die Gildenbank gesetzt."])
    else
        N.state:SetText(L["%d Materialien mit Bedarf, %d unter dem Soll · gesetzt von %s am %s"]:format(#rows, low,
            n.by or "?", ns.FmtDate(n.rev or 0)))
    end
    -- the editor picks from the learned materials, the pledge from the needed ones
    local mats = {}
    for _, e in ipairs(ns.MatEntries()) do mats[#mats + 1] = { value = e.id, text = ns.ItemName(e.id) } end
    for _, r in ipairs(rows) do
        local known = false
        for _, m in ipairs(mats) do if m.value == r.id then known = true end end
        if not known then mats[#mats + 1] = { value = r.id, text = r.name } end
    end
    N.pick:SetValues(mats)
    local needed = {}
    for _, r in ipairs(rows) do
        needed[#needed + 1] = { value = r.id, text = (r.short and r.short > 0) and L["%s (fehlen %d)"]:format(r.name, r.short) or r.name }
    end
    N.pPick:SetValues(needed)
    -- a grey hint while nothing is picked
    for _, p in ipairs({ N.pick, N.pPick }) do
        p:SetValue(p:GetValue())
        if p:GetValue() == nil then p.label:SetText(T.GREY .. L["Material wählen"] .. "|r") end
    end
    N.list:SetItems(rows)
    if #rows == 0 then
        N.empty:Set(L["Kein Bedarf"], officer and L["Wähle oben ein Material und setze Minimum und Ziel."]
            or L["Sobald ein Offizier Bedarf setzt, steht er hier, und du kannst Spenden zusagen."])
        N.empty:Show()
    else
        N.empty:Hide()
    end
    local pledges = ns.BankPledgeList()
    N.pledgeHead:SetText(L["Zusagen (%d) · gelten %d Tage"]:format(#pledges, tonumber(ns.Get("bank.pledgeDays")) or 7))
    N.pledges:SetItems(pledges)
    for _, w in ipairs({ N.pPick, N.pCount, N.pledge, N.withdraw }) do
        if w.SetEnabled then w:SetEnabled(#rows > 0) end
    end
end

---------------------------------------------------------------------------
-- Protokoll: the saved guild bank log
---------------------------------------------------------------------------
local logFilter = { tab = "all", kind = "all", q = "" }

local LOG_COLS = { { "when", 6, 84, L["Zeit"], font = T.FONT.hint }, { "text", 94, 384, L["Eintrag"] },
    { "tab", 482, 102, "Tab", justify = "RIGHT", font = T.FONT.hint } }

local function buildLog(f)
    -- the filters, the log
    local G = W.Page(f, { view = true })
    G:Bands({ "row" })
    G.tab = W.Choice(G, 120, function(v)
        logFilter.tab = v
        ns.Refresh()
    end)
    G.kind = W.Choice(G, 110, function(v)
        logFilter.kind = v
        ns.Refresh()
    end)
    G.kind:SetValues({ { "all", L["Alle Arten"] }, { "deposit", L["Einzahlungen"] }, { "withdraw", L["Abhebungen"] },
                       { "move", L["Verschoben"] }, { "money", L["Gold"] } })
    G.kind:SetValue("all")
    G.search = W.SearchBox(G, 160, function(text)
        logFilter.q = text or ""
        ns.Refresh()
    end, L["Name oder Gegenstand"])
    G.state = W.Text(G, T.FONT.hint)
    G:Place(1, { G.tab, G.kind, G.search, { G.state, fill = true } })
    G:Columns(LOG_COLS)
    G.list = G:List(LOG_ROWS, 22, function(r) W.Cells(r, LOG_COLS) end, function(r, e)
        -- the latest moment it can have happened; "~" when the window is wider than two hours
        r.when:SetText((e.hi - e.lo > 7200 and "~" or "") .. ns.FmtDayTime(e.hi))
        local text = ns.BankLogText(e)
        if e.y == "withdraw" or e.y == "repair" or e.y == "withdrawForTab" then text = T.ORANGE .. text .. "|r" end
        r.text:SetText(text)
        r.tab:SetText(ns.BankTabName(e.k))
    end)
    G.empty = G:Empty(420)
    f.log = G
end

local function refreshLog(f, on)
    local G = f.log
    G:SetShown(on)
    if not on then return end
    local log = ns.BankLog()
    local tabs = { { "all", L["Alle Tabs"] } }
    local ids = {}
    for tab in pairs(log.tabs or {}) do ids[#ids + 1] = tab end
    table.sort(ids)
    for _, tab in ipairs(ids) do tabs[#tabs + 1] = { tab, ns.BankTabName(tab) } end
    tabs[#tabs + 1] = { 0, L["Gold"] }
    G.tab:SetValues(tabs)
    local found = false
    for _, t in ipairs(tabs) do if t[1] == logFilter.tab then found = true end end
    if not found then logFilter.tab = "all" end
    G.tab:SetValue(logFilter.tab)
    G.kind:SetValue(logFilter.kind)
    local list = ns.BankLogEntries({ tab = logFilter.tab ~= "all" and logFilter.tab or nil,
        kind = logFilter.kind ~= "all" and logFilter.kind or nil, q = logFilter.q })
    G.list:SetItems(list)
    G.state:SetText(log.at and L["%d von %d · gelesen %s"]:format(#list, #log.list, ns.FmtDayTime(log.at))
        or L["%d Einträge"]:format(#log.list))
    if #log.list == 0 then
        G.empty:Set(L["Noch kein Protokoll"], L["Öffne die Gildenbank; Amisia liest dann das Protokoll jedes Tabs, das du sehen darfst, und das Goldprotokoll."])
        G.empty:Show()
    elseif #list == 0 then
        G.empty:Set(L["Nichts gefunden"], L["Kein Eintrag passt zu den Filtern."])
        G.empty:Show()
    else
        G.empty:Hide()
    end
end

---------------------------------------------------------------------------
-- Text: the shortfalls to copy
---------------------------------------------------------------------------
local copyText = ""

local function buildText(f)
    -- the text down to the footer with its hint
    local X = W.Page(f, { view = true })
    X:Footer({ "hint" })
    X.area = W.EditArea(X)
    X.area:SetPoint("TOPLEFT", 0, 0)
    X.area:SetPoint("BOTTOMRIGHT", 0, X:Bottom())
    -- read-only like the export box: typing puts the text back and marks it
    X.area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(copyText)
            self:HighlightText()
        end
    end)
    X.hint:SetText(L["Strg+A, Strg+C, dann in den Gildenchat oder in Discord einfügen."])
    f.text = X
end

local function refreshText(f, on)
    local X = f.text
    X:SetShown(on)
    if not on then return end
    if X.area.box:HasFocus() then return end
    copyText = ns.BankNeedText()
    X.area.box:SetText(copyText)
    X.area.box:SetCursorPosition(0)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
ns.RegisterPanel{ key = "bank", label = L["Gildenbank"], icon = "Interface\\Icons\\INV_Misc_Coin_02", order = 70, group = "guild",
    create = function(parent)
        local f = W.Page(parent)
        -- the head row: the four views; each view below is a view of the scaffold
        f:Bands({ "row" })
        f.views = {}
        f.views.bestand = W.Chip(f, L["Bestand"], nil, function() setView("bestand") end)
        f.views.bedarf = W.Chip(f, L["Bedarf##Bank"], nil, function() setView("bedarf") end)
        f.views.log = W.Chip(f, L["Protokoll"], nil, function() setView("log") end)
        f.views.text = W.Chip(f, L["Text für Chat##Bank"], nil, function() setView("text") end)
        buildStock(f)
        buildNeeds(f)
        buildLog(f)
        buildText(f)
        page = f
        return f
    end,
    refresh = function(f)
        local v = shownView()
        local rows = ns.BankNeedList()
        local low = 0
        for _, r in ipairs(rows) do if r.level == "low" then low = low + 1 end end
        f.views.bedarf.label:SetText(low > 0 and L["Bedarf (%d)"]:format(low) or L["Bedarf##Bank"])
        for key, c in pairs(f.views) do
            W.FitChip(c, 60)
            c:SetOn(key == v)
        end
        f:Place(1, { f.views.bestand, f.views.bedarf, f.views.log, f.views.text })
        refreshStock(f, v == "bestand")
        refreshNeeds(f, v == "bedarf")
        refreshLog(f, v == "log")
        refreshText(f, v == "text")
    end }

-- A link shift-clicked into the chat lands in the box while it has the focus. The client calls
-- ChatFrameUtil.InsertLink; ChatEdit_InsertLink is its deprecated alias with a hook of its own.
local function onInsertLink(link)
    if box and box:HasFocus() and ns.ItemID(link) then box:SetText(link) end
end
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
end
if type(ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
end

-- The card appears only while materials are tracked (ns.MAT_ORDER).
ns.RegisterCard{ key = "bank", order = 50, officer = true, available = ns.HasMats, fill = function(c)
    local bank = ns.Bank()
    c.title:SetText(L["Gildenbank"])
    if not (bank and bank.counts) then
        c.line1:SetText(L["Noch nicht gezählt"])
        return
    end
    local b = bank.counts
    c.line1:SetText(L["Gezählt am %s"]:format(ns.FmtDayTime(bank.at)))
    c.line2:SetText(ns.MatLine(b))
    c:SetAction(L["Ansehen"], function() ns.ShowPage("bank") end)
end }

-- /amisia bank [bedarf|protokoll|text]: the page in a view.
ns.RegisterSlash("bank", { aliases = { "gildenbank" }, args = L["[bedarf|protokoll|text]"],
    desc = L["Gildenbank: Bestand, Bedarf und Zusagen, Protokoll"], run = function(rest)
        local word = (rest or ""):lower():match("^(%S*)")
        local map = { bedarf = "bedarf", needs = "bedarf", protokoll = "log", log = "log", text = "text", bestand = "bestand", stock = "bestand" } -- l10n-ok: typed sub-words
        ns.ShowBank(map[word] or nil)
    end })
