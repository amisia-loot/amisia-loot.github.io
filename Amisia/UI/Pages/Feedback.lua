-- Feedback (tab Amisia, F-130, spec docs/specs/2026-11-05-feedback.md, D-61): a bug report or a wish
-- to the author. "Neue Meldung": the chips Bug/Wunsch, "Abschicken" (off without text and where the
-- author cannot be reached), the text field with the counter "0/500", what goes along (version, game,
-- language, class, level, the page open before; a bug the last Amisia error with "Fehler anhängen") and
-- "Deine Meldungen" (wartet, unterwegs, angekommen, nicht zugestellt with "Nochmal"). On the author's
-- characters the head row switches to "Eingang": the reports newest first (filter Offen/Erledigt/Alle),
-- a click shows the whole text and its details beside the list with "Erledigt" and "Löschen", a right
-- click also "Absender blockieren". The logic is Core/Feedback.lua; nothing here is saved but there.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.FEEDBACK
local LAY = T.LAYOUT
local GREY, ORANGE, GREEN, RED = T.GREY, T.ORANGE, T.GREEN, T.RED

local page
local view           -- "inbox" or "write" (the author's head row); others only write
local kind = "B"     -- the chosen kind of a new report
local withErr = true -- "Fehler anhängen"
local filter = "open"
local chosen         -- the inbox entry shown in the detail

function ns.FeedbackPageFrame() return page end

local Fb = function() return ns.Feedback end

local KIND_NAMES = { B = "Bug", W = L["Wunsch"] }
local STATE_TEXT = {
    wait = function() return ORANGE .. L["wartet"] .. "|r" end,
    sent = function() return L["unterwegs"] end,
    done = function() return GREEN .. L["angekommen"] .. "|r" end,
    lost = function() return RED .. L["nicht zugestellt"] .. "|r" end,
}

local function when(at)
    if date("%Y-%m-%d", at) == date("%Y-%m-%d", time()) then return date("%H:%M", at) end
    return ns.FmtDay(at)
end

-- The first line of a text, for a list cell.
local function firstLine(text) return (text:gsub("\n.*$", "")) end

local function show(frame, on) if on then frame:Show() else frame:Hide() end end

---------------------------------------------------------------------------
-- "Neue Meldung"
---------------------------------------------------------------------------
local function currentText(f)
    return f.edit and f.edit.box:GetText() or ""
end

-- Counter and "Abschicken" follow the text without a whole refresh.
local function updateCount(f)
    local text = currentText(f)
    local n = Fb().Chars(text)
    f.count:SetText(("%d/%d"):format(n, Fb().MAX_CHARS))
    local ok = Fb().Reachable() and Fb().Clean(text) ~= ""
    f.send:SetEnabled(ok)
end

local function submit(f)
    local ok, why = Fb().Submit(kind, currentText(f), withErr)
    if not ok then
        if why then ns.msg(why) end
    else
        f.edit.box:SetText("")
        f.edit.box:ClearFocus()
    end
    ns.Refresh()
end

local function buildOut(r)
    W.Cells(r, S.OUT_COLS)
    r.retry = W.Button(r, L["Nochmal"], S.RETRY_W, function(self)
        if self.id then Fb().Retry(self.id) end
        ns.Refresh()
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(r.retry, S.RETRY_W)
    r.retry:SetPoint("LEFT", S.RETRY_X, 0)
    W.Tooltip(r.retry, L["Nochmal"], L["Versucht die Meldung noch einmal zuzustellen, sobald der Autor online ist."])
end

local function fillOut(r, e)
    r.at:SetText(when(e.at))
    r.kind:SetText(KIND_NAMES[e.kind] or "?")
    r.text:SetText(firstLine(e.text))
    r.state:SetText(STATE_TEXT[e.state] and STATE_TEXT[e.state]() or "")
    r.retry.id = e.id
    show(r.retry, e.state == "lost")
end

local function buildWrite(c)
    c:Bands({ "row", "line" })
    c.kinds = {}
    for _, k in ipairs({ "B", "W" }) do
        c.kinds[k] = W.Chip(c, KIND_NAMES[k], S.KIND_W, function()
            kind = k
            ns.Refresh()
        end)
        W.FitChip(c.kinds[k], S.KIND_W)
    end
    W.Tooltip(c.kinds.B, "Bug", L["Etwas funktioniert nicht oder zeigt Falsches."])
    W.Tooltip(c.kinds.W, L["Wunsch"], L["Eine Idee oder Verbesserung für Amisia."])
    c.send = W.Button(c, L["Abschicken"], S.SEND_W, function() submit(c) end)
    W.FitChip(c.send, S.SEND_W)
    c:Place(1, { c.kinds.B, c.kinds.W }, { c.send })
    c.hint = c:Line(2)
    local y = c.top
    c.edit = W.EditArea(c)
    c.edit:SetPoint("TOPLEFT", 0, y)
    c.edit:SetPoint("TOPRIGHT", 0, y)
    c.edit:SetHeight(S.EDIT_H)
    c.edit.box:SetMaxLetters(Fb().MAX_CHARS)
    c.edit.box:HookScript("OnTextChanged", function() updateCount(c) end)
    y = y - S.EDIT_H - S.GAP
    c.meta = W.Text(c, T.FONT.hint, T.PAGE_W - 2 * LAY.TEXT_X - S.COUNT_W, true)
    c.meta:SetPoint("TOPLEFT", LAY.TEXT_X, y)
    c.meta:SetPoint("TOPRIGHT", -(LAY.TEXT_X + S.COUNT_W), y)
    c.meta:SetHeight(S.META_H)
    c.meta:SetJustifyV("TOP")
    c.meta:SetMaxLines(2)
    c.count = W.Text(c, T.FONT.hint, S.COUNT_W)
    c.count:SetPoint("TOPRIGHT", -LAY.TEXT_X, y)
    c.count:SetJustifyH("RIGHT")
    y = y - S.META_H - S.GAP
    c.errBox = W.Toggle(c, function(on)
        withErr = on
        ns.Refresh()
    end)
    c.errBox:SetPoint("TOPLEFT", LAY.TEXT_X, y - 1)
    c.errLabel = W.Text(c, T.FONT.text, S.ERR_W)
    c.errLabel:SetPoint("LEFT", c.errBox, "RIGHT", S.GAP, 0)
    c.errLabel:SetText(L["Fehler anhängen"])
    c.errText = W.Text(c, T.FONT.hint, T.PAGE_W - 2 * LAY.TEXT_X - T.TOGGLE - S.ERR_W - 2 * S.GAP)
    c.errText:SetPoint("LEFT", c.errLabel, "RIGHT", S.GAP, 0)
    y = y - T.TOGGLE - 2 * S.GAP
    c.outTitle = W.Text(c, T.FONT.title, 300)
    c.outTitle:SetPoint("TOPLEFT", LAY.TEXT_X, y)
    c.outTitle:SetText(L["Deine Meldungen"])
    y = y - S.TITLE_H - S.GAP
    local _, heads = c:Columns(S.OUT_COLS, { top = y })
    heads.at:SetText(L["Datum"])
    heads.kind:SetText(L["Art"])
    heads.text:SetText(L["Text"])
    heads.state:SetText(L["Stand"])
    c.out = c:List(S.OUT_ROWS, S.ROW_H, buildOut, fillOut)
    c.none = W.Text(c, T.FONT.hint, 400)
    c.none:SetPoint("TOPLEFT", c.out, "TOPLEFT", LAY.TEXT_X, -4)
    c.none:SetText(L["Noch keine Meldungen geschickt."])
end

local function refreshWrite(c)
    local F = Fb()
    for k, chip in pairs(c.kinds) do chip:SetOn(k == kind) end
    local reach = F.Reachable()
    if not reach then
        c.hint:SetText(ORANGE .. L["Auf diesem Server kann Amisia den Autor nicht erreichen."] .. "|r")
    elseif F.IsAuthor() then
        c.hint:SetText(L["Du bist der Autor: eine Meldung landet direkt in deinem Eingang (zum Testen)."])
    else
        c.hint:SetText(L["Geht unsichtbar an den Autor, auch wenn er gerade offline ist. Heute noch %d von %d."]
            :format(F.LeftToday(), F.PER_DAY))
    end
    local meta = F.Meta(kind, false)
    c.meta:SetText(L["Geht mit: %s"]:format(F.MetaText(meta)))
    local err = F.LastError()
    local bug = kind == "B"
    show(c.errBox, bug)
    show(c.errLabel, bug)
    show(c.errText, bug)
    c.errBox:SetChecked(withErr)
    c.errBox:SetEnabled(err ~= nil)
    c.errText:SetText(err and (GREY .. Fb().Clean(err, 80) .. "|r") or L["Kein Amisia-Fehler aufgezeichnet."])
    local list = F.Out()
    c.out:SetItems(list)
    show(c.none, #list == 0)
    updateCount(c)
end

---------------------------------------------------------------------------
-- "Eingang" (the author's characters)
---------------------------------------------------------------------------
local function detailText(e)
    local F = Fb()
    local lines = { e.text, "", GREY .. F.MetaText(e.meta) .. "|r" }
    if e.meta.err then lines[#lines + 1] = GREY .. L["Fehler: %s"]:format(e.meta.err) .. "|r" end
    if F.IsBlocked(e.from) then lines[#lines + 1] = ORANGE .. L["Absender blockiert"] .. "|r" end
    return table.concat(lines, "\n")
end

local function toggleDone(e)
    Fb().SetDone(e, not e.done)
    ns.Refresh()
end

local function askDelete(e)
    W.Confirm(L["Meldung löschen"], L["Die Meldung von %s löschen?"]:format(e.from), L["Löschen"], function()
        if chosen == e then chosen = nil end
        Fb().Delete(e)
        ns.Refresh()
    end)
end

local function rowMenu(r, e)
    local F = Fb()
    local blocked = F.IsBlocked(e.from)
    W.Menu(r, {
        { e.done and L["Wieder offen"] or L["Erledigt"], function() toggleDone(e) end },
        { L["Löschen"], function() askDelete(e) end },
        { blocked and L["Absender freigeben"] or L["Absender blockieren"], function()
            F.Block(e.from, not blocked)
            ns.Refresh()
        end, tip = L["Meldungen dieses Absenders werden still verworfen."] },
    })
end

local function buildIn(r)
    W.Cells(r, S.IN_COLS)
    r.sel = W.SelectBar(r)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
        if not self.item then return end
        chosen = self.item
        if button == "RightButton" then rowMenu(self, self.item) end
        ns.Refresh()
    end)
end

local function fillIn(r, e)
    local grey = e.done and GREY or ""
    local close = e.done and "|r" or ""
    r.kind:SetText(grey .. (KIND_NAMES[e.kind] or "?") .. close)
    r.from:SetText(grey .. e.from .. close)
    r.at:SetText(grey .. when(e.at) .. close)
    r.text:SetText(grey .. firstLine(e.text) .. close)
    r.sel:SetShown(e == chosen)
end

local FILTERS = { "open", "done", "all" }
local FILTER_NAMES = { open = L["Offen"], done = L["Erledigt"], all = L["Alle"] }

local function buildInbox(v)
    v:Bands({ "row" })
    v.filters = {}
    for _, k in ipairs(FILTERS) do
        v.filters[k] = W.Chip(v, FILTER_NAMES[k], S.FILTER_W, function()
            filter = k
            ns.Refresh()
        end)
        W.FitChip(v.filters[k], S.FILTER_W)
    end
    v.sum = W.Text(v, T.FONT.hint, 200)
    v.sum:SetJustifyH("RIGHT")
    v:Place(1, { v.filters.open, v.filters.done, v.filters.all }, { v.sum })
    local _, heads = v:Columns(S.IN_COLS, { width = LAY.SPLIT_LIST_W })
    heads.kind:SetText(L["Art"])
    heads.from:SetText(L["Absender"])
    heads.at:SetText(L["Datum"])
    heads.text:SetText(L["Text"])
    v.list = v:List(S.IN_ROWS, S.ROW_H, buildIn, fillIn, { width = LAY.SPLIT_LIST_W })
    v.detail = v:Detail({ sub = true, top = v.top, height = LAY.COLHEAD_H + S.IN_ROWS * S.ROW_H })
    v.detail.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    v.done = W.Button(v.detail, L["Erledigt"], S.ACTION_W, function() if chosen then toggleDone(chosen) end end)
    W.FitChip(v.done, S.ACTION_W)
    v.delete = W.Button(v.detail, L["Löschen"], S.ACTION_W, function() if chosen then askDelete(chosen) end end)
    W.FitChip(v.delete, S.ACTION_W)
    v.detail:Buttons({ v.done, v.delete })
    v.empty = v:Empty(LAY.SPLIT_LIST_W, v.list)
end

local function refreshInbox(v)
    local F = Fb()
    for k, chip in pairs(v.filters) do chip:SetOn(k == filter) end
    local list = F.Inbox(filter)
    local found = false
    for _, e in ipairs(list) do if e == chosen then found = true end end
    if not found then chosen = list[1] end
    v.list:SetItems(list)
    local all = #F.Inbox("all")
    v.sum:SetText(L["%d offen · %d gesamt"]:format(F.OpenCount(), all))
    if #list == 0 then
        v.empty:Set(L["Keine Meldungen"], filter == "open" and all > 0 and L["Alles erledigt."] or L["Meldungen anderer Spieler erscheinen hier."])
        v.empty:Show()
    else
        v.empty:Hide()
    end
    local d = v.detail
    if chosen then
        d.title:SetText(L["%s von %s"]:format(KIND_NAMES[chosen.kind] or "?", chosen.from))
        d.sub:SetText(ns.FmtDayTime(chosen.at) .. " · Amisia " .. (chosen.meta.v or "?") .. (chosen.done and (" · " .. L["erledigt"]) or ""))
        d.body:SetText(detailText(chosen))
        v.done:SetText(chosen.done and L["Wieder offen"] or L["Erledigt"])
        W.FitChip(v.done, S.ACTION_W)
        v.detail:Buttons({ v.done, v.delete })
        v.done:Show()
        v.delete:Show()
    else
        d.title:SetText(L["Keine Meldung gewählt"])
        d.sub:SetText("")
        d.body:SetText("")
        v.done:Hide()
        v.delete:Hide()
    end
    F.MarkSeen()
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
-- The author's head row (Eingang / Neue Meldung) or, for everyone else, "Neue Meldung" alone at the
-- page's top with its chips in the head row. Decided on each refresh (the character's name decides).
local function layout(f, author)
    if f.author == author then return end
    f.author = author
    for _, chip in pairs(f.views) do show(chip, author) end
    local c = f.write
    c.isView = author
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 0, author and f.top or 0)
    c:SetPoint("BOTTOMRIGHT", 0, 0)
    c:Bands({ "row", "line" })
    c:Place(1, { c.kinds.B, c.kinds.W }, { c.send })
    c:Line(2, c.hint)
    if author then view = view or "inbox" else view = "write" end
end

local function build(parent)
    local f = W.Page(parent)
    page = f
    f:Bands({ "row" })
    f.views = {
        inbox = W.Chip(f, L["Eingang"], S.VIEW_W, function() view = "inbox" ns.Refresh() end),
        write = W.Chip(f, L["Neue Meldung"], S.VIEW_W, function() view = "write" ns.Refresh() end),
    }
    W.FitChip(f.views.inbox, S.VIEW_W)
    W.FitChip(f.views.write, S.VIEW_W)
    f:Place(1, { f.views.inbox, f.views.write })
    f.inbox = W.Page(f, { view = true, top = f.top })
    buildInbox(f.inbox)
    f.write = W.Page(f, { view = true, top = f.top })
    buildWrite(f.write)
    return f
end

local function refresh(f)
    local author = Fb().IsAuthor()
    layout(f, author)
    if author then
        local n = Fb().OpenCount()
        f.views.inbox.label:SetText(n > 0 and ("%s (%d)"):format(L["Eingang"], n) or L["Eingang"])
        W.FitChip(f.views.inbox, S.VIEW_W)
        f:Place(1, { f.views.inbox, f.views.write })
        for k, chip in pairs(f.views) do chip:SetOn(k == view) end
    end
    show(f.inbox, author and view == "inbox")
    show(f.write, view == "write")
    if view == "inbox" then refreshInbox(f.inbox) else refreshWrite(f.write) end
end

ns.RegisterPanel{ key = "feedback", label = L["Feedback"], icon = "Interface\\Icons\\INV_Letter_15", order = 920, group = "amisia",
    create = build, refresh = refresh }

-- Opens the page (/amisia feedback); view "write" or "inbox" (the author) when given.
function ns.ShowFeedback(which)
    if which == "write" or (which == "inbox" and ns.Feedback.IsAuthor()) then view = which end
    ns.ShowPage("feedback")
end

local function shown() return page ~= nil and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "feedback" end
ns.Listen("FEEDBACK", function()
    if ns.Feedback then ns.Feedback.UpdateLabel() end
    if shown() then ns.RefreshSoon() end
end)
