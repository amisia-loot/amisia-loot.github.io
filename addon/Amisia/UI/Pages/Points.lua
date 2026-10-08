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
local function col(parent, x, w, template)
    local fs = W.Text(parent, template or T.FONT.text, w)
    fs:SetPoint("LEFT", x, 0)
    return fs
end

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
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    page = f

    f.view = {
        list = W.Chip(f, L["Stand##Punkte"], nil, function() view = "list" ns.Refresh() end),
        paste = W.Chip(f, L["Einfügen"], nil, function() view = "paste" ns.Refresh() end),
    }
    W.FitChip(f.view.list, 70)
    W.FitChip(f.view.paste, 70)
    W.Row(f, { f.view.list, f.view.paste }, T.CHIP_GAP, 0, -2)
    f.info = W.Text(f, T.FONT.hint, 590)
    f.info:SetPoint("TOPLEFT", 6, -28)

    local head = CreateFrame("Frame", nil, f)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, -44)
    head:SetPoint("TOPRIGHT", 0, -44)
    f.heads = {}
    for _, c in ipairs(COLS) do f.heads[c[1]] = col(head, c[2], c[3], T.FONT.head) end
    f.headFrame = head

    f.list = W.List(f, ROWS, ROW_H, function(r)
        for _, c in ipairs(COLS) do r[c[1]] = col(r, c[2], c[3]) end
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
    f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    f.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -T.SCROLL_ROOM, 0)
    for _, r in ipairs(f.list.rows) do r.sel = W.SelectBar(r) end

    f.detail = W.ScrollText(f)
    f.detail:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 6, -8)
    f.detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -T.SCROLL_ROOM, 52)

    -- officers: a correction with a reason, at the bottom
    f.adjLabel = W.Text(f, T.FONT.text, 66)
    f.adjLabel:SetPoint("BOTTOMLEFT", 6, 32)
    f.adjLabel:SetText(L["Korrektur"])
    f.who = W.Picker(f, 140, function(v) chosen = v and v:lower() or chosen ns.Refresh() end)
    f.who:SetPoint("LEFT", f.adjLabel, "RIGHT", 4, 0)
    f.amount = W.LineEdit(f, 56, function() end)
    f.amount:SetPoint("LEFT", f.who, "RIGHT", 6, 0)
    f.amount:SetMaxLetters(8)
    f.pool = W.Choice(f, 44, function(v) pool = v end)
    f.pool:SetValues({ { "E", "EP" }, { "G", "GP" } })
    f.pool:SetPoint("LEFT", f.amount, "RIGHT", 6, 0)
    f.reason = W.LineEdit(f, 170, function() end)
    f.reason:SetPoint("LEFT", f.pool, "RIGHT", 6, 0)
    f.reason:SetMaxLetters(80)
    f.book = W.Button(f, L["Buchen"], 70, function() book(f) end, { height = T.ROW_BUTTON_H })
    W.FitChip(f.book, 70)
    f.book:SetPoint("LEFT", f.reason, "RIGHT", 6, 0)
    W.Tooltip(f.book, L["Buchen"], L["Name, Betrag (mit Minus zum Abziehen) und ein Grund. Die Korrektur geht mit dem nächsten Export auf die Website."])
    f.status = W.Text(f, T.FONT.hint, 590)
    f.status:SetPoint("BOTTOMLEFT", 6, 10)

    -- the website's text
    f.paste = W.EditArea(f)
    f.paste:SetPoint("TOPLEFT", 0, -44)
    f.paste:SetPoint("BOTTOMRIGHT", 0, 32)
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
    f.import:SetPoint("BOTTOMLEFT", 0, 4)
    f.result = W.Text(f, T.FONT.hint, 480)
    f.result:SetPoint("LEFT", f.import, "RIGHT", 8, 0)

    f.empty = W.EmptyState(f, 520)
    f.empty:SetPoint("TOP", 0, -90)
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
    f.reason:ClearAllPoints()
    f.reason:SetPoint("LEFT", sys == "epgp" and f.pool or f.amount, "RIGHT", 6, 0)
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
