-- Punkte: the DKP or EPGP standings (Raid/Points.lua). Officers see every main with the history of
-- the chosen one and book a correction with a reason; a raider sees the own row, the whole list only
-- when the website shows it (pub). The view "Einfügen" takes the website's text (the points block
-- with the wishes, alts and prio, Alts.lua ns.ImportSiteText). While the guild rolls, officers see a
-- hint how to switch and raiders do not see the page at all.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local ROWS, ROW_H = 8, 20
local HISTORY_MAX = 60

local page
local view = "list"            -- "list" or "paste"
local chosen                   -- lower name of the main in the detail
local pool = "E"               -- EPGP: a correction of EP or GP

-- Test hook: the page frame (addon/tests).
function ns.PointsPageFrame() return page end

-- The columns: key, x, width. They end at 576 of the 590 the list has.
local COLS = {
    { "rank", 6, 24 }, { "name", 34, 170 }, { "a", 210, 70 }, { "b", 284, 60 }, { "pr", 348, 60 }, { "alts", 412, 164 },
}

local function plusText(n)
    if n > 0 then return T.GREEN .. "+" .. n .. "|r" end
    if n < 0 then return T.RED .. n .. "|r" end
    return "0"
end

local function historyText(e, sys)
    local cfg = ns.PointsConfig()
    local lines = { T.LABEL .. ns.PointsStandingText(e, cfg) .. "|r" }
    local alts = ns.AltsOf(e.name)
    if #alts > 0 then lines[#lines + 1] = T.GREY .. L["Twinks: %s"]:format(table.concat(alts, ", ")) .. "|r" end
    local hist = ns.PointsHistory(e.name)
    if #hist == 0 then
        if ns.IsOfficerView() then lines[#lines + 1] = T.GREY .. L["Noch keine Einträge."] .. "|r" end
        return table.concat(lines, "\n")
    end
    lines[#lines + 1] = ""
    local from = math.max(1, #hist - HISTORY_MAX + 1)
    for i = #hist, from, -1 do
        local h = hist[i]
        local unit = h.pool == "G" and " GP" or (sys == "epgp" and " EP" or "")
        local when = h.t > 0 and ns.FmtDay(h.t) or "-"
        local amount = h.code == "S" and tostring(h.n) or plusText(h.n)
        lines[#lines + 1] = ("%s  %s%s  %s"):format(when, amount, unit, h.text)
    end
    if from > 1 then lines[#lines + 1] = T.GREY .. L["und %d ältere"]:format(from - 1) .. "|r" end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function book(f)
    local name = f.who:GetValue()
    local n = tonumber((tostring(f.amount:GetText() or ""):gsub("^%+", "")))
    local e, why = ns.PointsAdjust(name, n, f.reason:GetText(), pool == "G" and "gp" or "ep")
    if not e then
        f.status:SetText(T.RED .. tostring(why) .. "|r")
        return
    end
    f.amount:SetText("")
    f.reason:SetText("")
    chosen = e.name:lower()
    f.status:SetText(T.GREEN .. L["Gebucht: %s %s%d."]:format(e.name, e.n > 0 and "+" or "", e.n) .. "|r")
    ns.Refresh()
end

local function build_page(parent)
    local f = W.Page(parent)
    page = f

    -- the head row: the two views; under it the system and the site's state
    local top = f:Bands({ "row", "line" })
    f.view = {
        list = W.Chip(f, L["Stand##Punkte"], nil, function() view = "list" ns.Refresh() end),
        paste = W.Chip(f, L["Einfügen"], nil, function() view = "paste" ns.Refresh() end),
    }
    W.FitChip(f.view.list, 70)
    W.FitChip(f.view.paste, 70)
    f:Place(1, { f.view.list, f.view.paste })
    f.info = f:Line(2)
    -- the footer: what the last correction did
    f:Footer({ "status" })
    -- while the guild rolls: what to do instead of the list
    f.empty = f:Empty(520)

    f.headFrame, f.heads = f:Columns(COLS)
    f.list = f:List(ROWS, ROW_H, function(r)
        W.Cells(r, COLS)
        r:SetScript("OnClick", function(self)
            if self.item then
                chosen = self.item.name:lower()
                if f.who then f.who:SetValue(self.item.name) end
                ns.Refresh()
            end
        end)
    end, function(r, e)
        local sys = ns.PointsSystem()
        r.rank:SetText(tostring(e.place))
        r.name:SetText(e.name)
        r.a:SetText(tostring(e.a))
        r.b:SetText(sys == "epgp" and tostring(e.b) or "")
        r.pr:SetText(sys == "epgp" and ((e.low and T.RED or "") .. ns.PointsPRText(e.pr) .. (e.low and "|r" or "")) or "")
        local alts = ns.AltsOf(e.name)
        r.alts:SetText(#alts > 0 and (T.GREY .. table.concat(alts, ", ") .. "|r") or "")
        if r.sel then r.sel:SetShown(e.name:lower() == chosen) end
    end)
    for _, r in ipairs(f.list.rows) do r.sel = W.SelectBar(r) end

    -- officers: a correction with a reason in the bottom row (the paste view puts its import there)
    f.adjLabel = W.Text(f, T.FONT.text, 66)
    f.adjLabel:SetText(L["Korrektur"])
    f.who = W.Picker(f, 140, function(v) chosen = v and v:lower() or chosen ns.Refresh() end)
    f.amount = W.LineEdit(f, 56, function() end)
    f.amount:SetMaxLetters(8)
    f.pool = W.Choice(f, 44, function(v) pool = v end)
    f.pool:SetValues({ { "E", "EP" }, { "G", "GP" } })
    f.reason = W.LineEdit(f, 170, function() end)
    f.reason:SetMaxLetters(80)
    f.book = W.Button(f, L["Buchen"], 70, function() book(f) end)
    W.FitChip(f.book, 70)
    W.Tooltip(f.book, L["Buchen"], L["Name, Betrag (mit Minus zum Abziehen) und ein Grund. Die Korrektur geht mit dem nächsten Export auf die Website."])

    -- the website's text
    f.paste = W.EditArea(f)
    f.import = W.Button(f, L["Importieren"], 100, function()
        local text, ok = ns.ImportSiteText(f.paste.box:GetText() or "")
        f.result:SetText((ok and T.GREEN or T.RED) .. tostring(text or "") .. "|r")
        if ok then
            f.paste.box:SetText("")
            view = "list"
        end
        ns.Refresh()
    end)
    W.FitChip(f.import, 100)
    f.result = W.Text(f, T.FONT.hint)
    f.bottomList = { f.adjLabel, f.who, f.amount, f.pool, f.reason, f.book, f.import, { f.result, fill = true } }
    f:BottomRow(f.bottomList)
    f.paste:SetPoint("TOPLEFT", 0, top)
    f.paste:SetPoint("BOTTOMRIGHT", 0, f:Bottom())

    -- the chosen player's history under the list, down to the bottom row
    f.detail = W.ScrollText(f)
    f.detail:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", T.LAYOUT.TEXT_X, -2 * T.LAYOUT.GAP)
    f.detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -T.SCROLL_ROOM, f:Bottom())
    return f
end

local function setShown(list, on)
    for _, x in ipairs(list) do x:SetShown(on) end
end

local function refresh(f)
    local officer = ns.IsOfficerView()
    local cfg = ns.PointsConfig()
    local sys = cfg.sys
    f.view.list:SetOn(view == "list")
    f.view.paste:SetOn(view == "paste")

    local paste = view == "paste"
    setShown({ f.paste, f.import, f.result }, paste)
    local rolling = sys == "roll"
    local listOn = not paste and not rolling
    setShown({ f.headFrame, f.list, f.detail }, listOn)
    setShown({ f.adjLabel, f.who, f.amount, f.reason, f.book, f.status }, listOn and officer)
    f.pool:SetShown(listOn and officer and sys == "epgp")
    -- the bottom row holds what is shown: the correction (officers) or the import (paste)
    f:BottomRow(f.bottomList, nil, { shown = true })
    f.empty:SetShown(rolling and not paste)

    -- the line under the chips: system, the site's block and what is live
    local info = ns.PointsInfo()
    local parts = { ns.PointsSystemName(sys) }
    if sys == "dkp" then
        parts[#parts + 1] = cfg.mode == "fixed" and L["feste Preise"] or (cfg.seal == 1 and L["verdeckt bieten"] or L["offen bieten"])
    elseif sys == "epgp" then
        parts[#parts + 1] = L["Grund-GP %d"]:format(cfg.base or 0)
        if (cfg.minep or 0) > 0 then parts[#parts + 1] = L["Mindest-EP %d"]:format(cfg.minep) end
    end
    parts[#parts + 1] = info and L["Website vom %s"]:format(info.date) or L["noch kein Stand der Website"]
    local sh = ns.PointsSharedList and ns.PointsSharedList()
    if sh and not officer then parts[#parts + 1] = L["live von %s"]:format(sh.from or "?") end
    f.info:SetText(table.concat(parts, " · "))

    if paste then
        f.empty:Hide()
        return
    end
    if rolling then
        f.empty:Set(L["Die Gilde würfelt"], L["DKP oder EPGP stellt die Website ein: Punkte, Kopieren für das Addon, hier unter Einfügen einfügen. Oder Einstellungen, Punkte (DKP/EPGP)."])
        return
    end

    f.heads.rank:SetText("#")
    f.heads.name:SetText(L["Spieler"])
    f.heads.a:SetText(sys == "epgp" and "EP" or "DKP")
    f.heads.b:SetText(sys == "epgp" and "GP" or "")
    f.heads.pr:SetText(sys == "epgp" and "PR" or "")
    f.heads.alts:SetText(L["Twinks"])

    local rows = ns.PointsStandings()
    for i, e in ipairs(rows) do e.place = i end
    f.list:SetItems(rows)
    local pick
    for _, e in ipairs(rows) do
        if e.name:lower() == chosen then pick = e end
    end
    if not pick and not officer then
        local me = ns.UnitFullName("player")
        for _, e in ipairs(rows) do
            if me and ns.SameMain(e.name, me) then pick = e end
        end
    end
    pick = pick or rows[1]
    chosen = pick and pick.name:lower() or nil
    f.detail:SetText(pick and historyText(pick, sys) or "")

    if officer then
        local values = {}
        for _, e in ipairs(rows) do values[#values + 1] = { value = e.name, text = e.name } end
        f.who:SetValues(values, L["Anderer Name"])
        if pick and not f.who:GetValue() then f.who:SetValue(pick.name) end
        f.pool:SetValue(pool)
    end
end

-- Opens the page, in a view ("list" or "paste") when given.
function ns.ShowPoints(which)
    if which == "list" or which == "paste" then view = which end
    ns.ShowPage("points")
    ns.Refresh()
end

ns.RegisterPanel{ key = "points", label = L["Punkte"], icon = "Interface\\Icons\\INV_Misc_Coin_02", order = 37, group = "raid",
    available = function() return ns.IsOfficerView() or ns.PointsSystem() ~= "roll" end,
    create = function(parent) return build_page(parent) end,
    refresh = function(f) refresh(f) end }

ns.Listen("POINTS", function()
    if ns.CurrentPage and ns.CurrentPage() == "points" and ns.Refresh then ns.Refresh() end
end)
