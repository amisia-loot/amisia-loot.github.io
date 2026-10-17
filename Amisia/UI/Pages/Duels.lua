-- Duelle (tab PvP, F-106, spec docs/specs/2026-10-16-duelle.md): the duels Core/Duels.lua recorded.
-- Three views: Verlauf (time, winner, loser with class icon, class colour, class and specialisation,
-- Sieg/Flucht, place), Rangliste (rank, class icon and player, class and specialisation, games,
-- wins-losses, win rate; a click on a head sorts) and Klassen (per class games, players, wins-losses,
-- win rate and the share of known classes, the tooltip per specialisation; "Nach Spezialisierung"
-- counts class and tree apart; with a class chosen: that class against each). A name's tooltip: the
-- lines of UI/DuelInfo.lua (class, specialisation, record, you against him, streak, rivals). The
-- head: the views, "Nach Spezialisierung", "Turnier starten/beenden", "Nur Turnier", the class and
-- time pickers, the name search and "Klassen suchen (N)" (one /who per click). A click on a name
-- filters on that player (the footer: his record and streak), a right click whispers; a click on a
-- class row chooses the class. View, class, time, sort, spec and "Nur Turnier" stay in
-- settings.window.duels.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.DUELS
local GREY, ORANGE = T.GREY, T.ORANGE

local page
local query = ""        -- the name search (not kept)
local player            -- the player a click chose (exactly that name; the search shows it)

function ns.DuelsPageFrame() return page end

local VIEWS = { hist = true, board = true, classes = true }
local SORTS = { name = true, games = true, wins = true, rate = true }
local RANGES = { all = true, day = true, week = true, month = true }

-- settings.window.duels: { view, class = class token or "all", range = all/day/week/month, sort, desc,
-- tour = only the last tournament, spec = the classes view by specialisation }
local function state()
    local s = AmisiaDB and AmisiaDB.settings
    if type(s) ~= "table" then return { view = "hist", class = "all" } end
    s.window = type(s.window) == "table" and s.window or {}
    local d = type(s.window.duels) == "table" and s.window.duels or {}
    s.window.duels = d
    if not VIEWS[d.view] then d.view = "hist" end
    if d.class ~= "all" and not ns.Duels.CLASSES[d.class] then d.class = "all" end
    if not SORTS[d.sort] then d.sort = nil end
    d.desc = d.desc == true or nil
    d.tour = d.tour == true or nil
    d.spec = d.spec == true or nil
    if not RANGES[d.range] then d.range = "all" end
    return d
end

local function show(frame, on) if on then frame:Show() else frame:Hide() end end

local function className(c)
    local names = ns.Gear and ns.Gear.CLASS_NAMES
    return c and names and names[c] or c
end

local function classLine(c, tree) return ns.DuelInfo.ClassLine(c, tree) end

local function colored(text, c)
    local col = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    return col and col.colorStr and ("|c%s%s|r"):format(col.colorStr, text) or text
end

local function pct(r, g)
    if not g or g == 0 then return GREY .. "-|r" end
    return ns.Num(r * 100, 1) .. " %"
end

local function wl(w, l) return ("%d - %d"):format(w, l) end

-- the zone column shows the zone, the tooltip "Zone · Subzone"
local function zoneOnly(z) return z and (z:match("^(.-) · ") or z) or nil end

-- Filters on one player (a click on a name).
local function choosePlayer(name)
    query, player = name or "", name
    if page and page.search then
        page.search:SetText(query)
        -- the clear button commits only a text other than the last one
        page.search.lastCommit = query
    end
    ns.Refresh()
end

local function whisperMenu(owner, name)
    if not name or ns.SameName(name, ns.UnitFullName("player")) then return end
    W.Menu(owner, { { L["Flüstern"], function() if ns.Whisper then ns.Whisper(name) end end },
                    { L["Nur seine Duelle"], function() choosePlayer(name) end } })
end

---------------------------------------------------------------------------
-- Verlauf
---------------------------------------------------------------------------
-- A player's tooltip: the lines of UI/DuelInfo.lua (over every duel).
local function playerTooltip(owner, name)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    ns.DuelInfo.AddLines(GameTooltip, name)
    GameTooltip:AddLine(L["Klick: nur seine Duelle · Rechtsklick: Flüstern"], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function nameTooltip(self)
    if self.name then playerTooltip(self, self.name) end
end

local function nameButton(row, col)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(col[3], S.HIST_ROW_H)
    b:SetPoint("LEFT", col[2], 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(S.HIST_ICON, S.HIST_ICON)
    b.icon:SetPoint("LEFT", 0, 0)
    local x = S.HIST_ICON + S.ICON_GAP
    b.top = W.Text(b, T.FONT.body, col[3] - x)
    b.top:SetPoint("TOPLEFT", x, S.LINE1_Y)
    b.sub = W.Text(b, T.FONT.text, col[3] - x)
    b.sub:SetPoint("TOPLEFT", x, S.LINE2_Y)
    b:SetScript("OnEnter", nameTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then whisperMenu(self, self.name) else choosePlayer(self.name) end
    end)
    return b
end

local function histTooltip(self)
    local r = self.item
    if not r then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.FmtDate(r.t) .. " " .. date("%H:%M", r.t), 1, 0.82, 0)
    if r.k == "F" then
        GameTooltip:AddLine(L["%s ist vor %s aus dem Duell geflohen."]:format(r.l, r.w), 0.85, 0.85, 0.85, true)
    else
        GameTooltip:AddLine(L["%s hat %s besiegt."]:format(r.w, r.l), 0.85, 0.85, 0.85, true)
    end
    if r.z then GameTooltip:AddLine(L["Ort: %s"]:format(r.z), 0.85, 0.85, 0.85, true) end
    if r.n then GameTooltip:AddLine(L["Turnier %d"]:format(r.n), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

local function buildHist(row)
    local C = S.HIST_COLS
    row.t = W.Text(row, T.FONT.text, C[1][3])
    row.t:SetPoint("LEFT", C[1][2], 0)
    row.w = nameButton(row, C[2])
    row.l = nameButton(row, C[3])
    row.k = W.Text(row, T.FONT.text, C[4][3])
    row.k:SetPoint("LEFT", C[4][2], 0)
    row.z = W.Text(row, T.FONT.text, C[5][3])
    row.z:SetPoint("LEFT", C[5][2], 0)
    row:SetScript("OnEnter", histTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fillName(b, name, c, tree)
    b.name = name
    W.SetClassIcon(b.icon, c)
    b.top:SetText(colored(name, c))
    b.sub:SetText(GREY .. classLine(c, tree) .. "|r")
end

local function fillHist(row, r)
    row.t:SetText(ns.FmtDayTime(r.t))
    fillName(row.w, r.w, r.wc, r.ws)
    fillName(row.l, r.l, r.lc, r.ls)
    row.k:SetText(r.k == "F" and (ORANGE .. L["Flucht"] .. "|r") or L["Sieg"])
    row.z:SetText(zoneOnly(r.z) or (GREY .. "-|r"))
end

---------------------------------------------------------------------------
-- Rangliste
---------------------------------------------------------------------------
local function boardTooltip(self)
    local e = self.item
    if not e then return end
    playerTooltip(self, e.name)
    if e.g < ns.Duels.MIN_GAMES then
        GameTooltip:AddLine(L["Nach Siegrate gereiht wird ab %d Duellen."]:format(ns.Duels.MIN_GAMES), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end
end

local function buildBoard(row)
    W.Cells(row, S.BOARD_COLS)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(S.BOARD_ICON, S.BOARD_ICON)
    row.icon:SetPoint("LEFT", S.BOARD_COLS[2][2], 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", boardTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        local e = self.item
        if not e then return end
        if button == "RightButton" then whisperMenu(self, e.name) else choosePlayer(e.name) end
    end)
end

local function fillBoard(row, e)
    local ranked = e.g >= ns.Duels.MIN_GAMES
    row.rank:SetText(ranked and (e.rank .. ".") or (GREY .. e.rank .. ".|r"))
    W.SetClassIcon(row.icon, e.c)
    row.name:SetText(colored(e.name, e.c))
    row.class:SetText(GREY .. classLine(e.c, e.s) .. "|r")
    row.games:SetText(tostring(e.g))
    row.wins:SetText(wl(e.w, e.l))
    row.rate:SetText(ranked and pct(e.r, e.g) or (GREY .. pct(e.r, e.g) .. "|r"))
end

---------------------------------------------------------------------------
-- Klassen
---------------------------------------------------------------------------
local function classTooltip(self)
    local e = self.item
    if not e then return end
    local chosen = state().class ~= "all" and state().class or nil
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if chosen then
        GameTooltip:AddLine(L["%s gegen %s"]:format(colored(className(chosen), chosen), colored(classLine(e.c, e.t), e.c)), 1, 0.82, 0)
        GameTooltip:AddLine(L["%d Duelle, %d Siege, %d Niederlagen"]:format(e.g, e.w, e.l), 0.85, 0.85, 0.85)
        if e.c == chosen then GameTooltip:AddLine(L["Gleiche Klasse: jedes Duell ein Sieg und eine Niederlage."], 0.6, 0.6, 0.6, true) end
    else
        GameTooltip:AddLine(colored(classLine(e.c, e.t), e.c), 1, 0.82, 0)
        GameTooltip:AddLine(L["%d Duelle von %d Spielern, %d Siege, %d Niederlagen"]:format(e.g, e.p, e.w, e.l), 0.85, 0.85, 0.85, true)
        -- per specialisation (the sides with a known tree)
        for t = 1, 3 do
            local sp, name = e.specs and e.specs[t], ns.Duels.TreeName(e.c, t)
            if sp and name then
                GameTooltip:AddDoubleLine(name, L["%d Duelle, %s, %s"]:format(sp.g, wl(sp.w, sp.l), pct(sp.w / sp.g, sp.g)),
                    0.85, 0.85, 0.85, 0.85, 0.85, 0.85)
            end
        end
        GameTooltip:AddLine(L["Klick: wie schlägt sich die Klasse gegen jede andere?"], 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function buildClass(row)
    W.Cells(row, S.CLASS_COLS)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(S.BOARD_ICON, S.BOARD_ICON)
    row.icon:SetPoint("LEFT", S.CLASS_COLS[1][2], 0)
    row:SetScript("OnEnter", classTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        local e = self.item
        if not e or state().class ~= "all" then return end
        state().class = e.c
        ns.Refresh()
    end)
end

local function fillClass(row, e)
    W.SetClassIcon(row.icon, e.c)
    row.class:SetText(colored(e.rank .. ". " .. (e.t and classLine(e.c, e.t) or className(e.c)), e.c))
    row.games:SetText(tostring(e.g))
    row.players:SetText(tostring(e.p))
    row.wins:SetText(wl(e.w, e.l))
    row.rate:SetText(pct(e.r, e.w + e.l))
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function classValues()
    local out = { { value = "all", text = L["Alle Klassen"] } }
    local list = {}
    for c in pairs(ns.Duels.CLASSES) do list[#list + 1] = { value = c, text = className(c) } end
    table.sort(list, function(a, b) return a.text < b.text end)
    for _, e in ipairs(list) do out[#out + 1] = e end
    return out
end

local function rangeValues()
    return { { value = "all", text = L["Alle Zeiten"] }, { value = "day", text = L["Heute"] },
             { value = "week", text = L["Letzte 7 Tage"] }, { value = "month", text = L["Letzte 30 Tage"] } }
end

local function build(parent)
    local f = W.Page(parent)
    page = f
    local top = f:Bands({ "row", "row" })
    f.views = {
        hist = W.Chip(f, L["Verlauf"], 70, function() state().view = "hist" ns.Refresh() end),
        board = W.Chip(f, L["Rangliste"], 70, function() state().view = "board" ns.Refresh() end),
        classes = W.Chip(f, L["Klassen"], 70, function() state().view = "classes" ns.Refresh() end),
    }
    for _, c in pairs(f.views) do W.FitChip(c, 70) end
    f.tourButton = W.Button(f, L["Turnier starten"], 110, function()
        if ns.Duels.Tour().on then ns.Duels.TourStop() else
            ns.Duels.TourStart()
            state().tour = true
        end
        ns.Refresh()
    end)
    W.FitChip(f.tourButton, 110)
    W.Tooltip(f.tourButton, L["Turnier"], L["Die Duelle zwischen \"Turnier starten\" und \"Turnier beenden\" gehören zum Turnier; \"Nur Turnier\" zeigt nur sie (das laufende oder das letzte)."])
    f.tourChip = W.Chip(f, L["Nur Turnier"], 80, function()
        state().tour = (not state().tour) or nil
        ns.Refresh()
    end)
    W.FitChip(f.tourChip, 80)
    W.Tooltip(f.tourChip, L["Nur Turnier"], L["Zeigt Verlauf, Rangliste und Klassen nur für das laufende oder letzte Turnier."])
    f.specChip = W.Chip(f, L["Nach Spezialisierung"], S.SPEC_CHIP_W, function()
        state().spec = (not state().spec) or nil
        ns.Refresh()
    end)
    W.FitChip(f.specChip, S.SPEC_CHIP_W)
    W.Tooltip(f.specChip, L["Nach Spezialisierung"], L["Zählt jede Klasse je Spezialisierung getrennt (z. B. Jäger · Treffsicherheit). Nur Duellanten mit bekannter Spezialisierung zählen."])
    f:Place(1, { f.views.hist, f.views.board, f.views.classes }, { f.tourChip, f.tourButton })
    f.class = W.Picker(f, S.CLASS_W, function(v)
        state().class = v or "all"
        ns.Refresh()
    end)
    f.range = W.Picker(f, S.RANGE_W, function(v)
        state().range = v or "all"
        ns.Refresh()
    end)
    f.range:SetValues(rangeValues())
    f.search = W.SearchBox(f, S.SEARCH_W, function(text)
        query = text or ""
        if query ~= player then player = nil end
        ns.Refresh()
    end, L["Spieler suchen"])
    f.who = W.Button(f, L["Klassen suchen (%d)"]:format(0), 130, function()
        local ok, why = ns.Duels.WhoAsk()
        if not ok and why then ns.msg(why) end
        ns.Refresh()
    end)
    W.Tooltip(f.who, L["Klassen suchen"], L["Fragt das Spiel per /who nach Spielern ohne Klasse: der erste Klick nach deiner Zone (bis zu 50 Spieler auf einmal), jeder weitere nach einem Namen. Ein Klick, eine Frage, höchstens alle 5 Sekunden."])
    f:Place(2, { f.class, f.range, f.search }, { f.who })
    f:Footer({ "data" })

    -- Verlauf
    f.histView = W.Page(f, { view = true, top = top })
    local _, hh = f.histView:Columns(S.HIST_COLS)
    hh.t:SetText(L["Zeit"])
    hh.w:SetText(L["Sieger"])
    hh.l:SetText(L["Verlierer"])
    hh.k:SetText(L["Ergebnis"])
    hh.z:SetText(L["Ort##Duell"])
    f.histList = f.histView:List(S.HIST_ROWS, S.HIST_ROW_H, buildHist, fillHist)
    -- Rangliste
    f.boardView = W.Page(f, { view = true, top = top })
    local heads = { rank = "#", name = L["Spieler"], class = L["Klasse"], games = L["Spiele"], wins = L["S - N"], rate = L["Siegrate"] }
    local cols = {}
    for i, c in ipairs(S.BOARD_COLS) do cols[i] = { c[1], c[2], c[3], heads[c[1]], justify = c.justify } end
    local _, bh = f.boardView:Columns(cols, { sort = function(key)
        if key == "rank" or key == "class" then return end
        local st = state()
        if st.sort == key then st.desc = (not st.desc) or nil else st.sort, st.desc = key, nil end
        ns.Refresh()
    end })
    f.boardHeads = bh
    for _, key in ipairs({ "name", "games", "wins", "rate" }) do
        W.Tooltip(bh[key], heads[key], L["Klicken sortiert, ein zweiter Klick dreht die Reihenfolge um."])
    end
    f.boardList = f.boardView:List(S.ROWS, S.ROW_H, buildBoard, fillBoard)
    -- Klassen
    f.classView = W.Page(f, { view = true, top = top })
    local _, ch = f.classView:Columns(S.CLASS_COLS)
    f.classHeads = ch
    ch.games:SetText(L["Spiele"])
    ch.players:SetText(L["Spieler"])
    ch.wins:SetText(L["S - N"])
    ch.rate:SetText(L["Siegrate"])
    f.classList = f.classView:List(S.ROWS, S.ROW_H, buildClass, fillClass)
    f.empty = f:Empty()
    return f
end

local function refresh(f)
    local st = state()
    local D = ns.Duels
    D.FillKnown()
    D.LearnOwnSpec()
    local tour = D.Tour()
    if tour.n == 0 then st.tour = nil end
    for k, c in pairs(f.views) do c:SetOn(k == st.view) end
    f.tourButton:SetText(tour.on and L["Turnier beenden"] or L["Turnier starten"])
    W.FitChip(f.tourButton, 110)
    f.tourChip:SetOn(st.tour == true)
    f.tourChip:SetEnabled(tour.n > 0)
    f.specChip:SetOn(st.spec == true)
    show(f.specChip, st.view == "classes")
    f:Place(1, { f.views.hist, f.views.board, f.views.classes, st.view == "classes" and f.specChip or nil },
        { f.tourChip, f.tourButton })
    f.class:SetValues(classValues())
    f.class:SetValue(st.class)
    f.range:SetValue(st.range)
    local n, wait = D.UnknownCount(), D.WhoWait()
    f.who:SetText(wait > 0 and L["Bitte warten"] or L["Klassen suchen (%d)"]:format(n))
    W.FitChip(f.who, 130)
    f.who:SetEnabled(n > 0 and wait == 0)
    f:Place(2, { f.class, f.range, f.search }, { f.who })
    if wait > 0 then
        C_Timer.After(wait + 0.1, function()
            if page and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "duels" then ns.RefreshSoon() end
        end)
    end

    show(f.histView, st.view == "hist")
    show(f.boardView, st.view == "board")
    show(f.classView, st.view == "classes")
    f.empty:Hide()
    local since = D.Since(st.range)
    local opts = { query = query, player = player, class = st.class, tour = st.tour, since = since }
    local total = D.Count()
    local tourText = st.tour and (" · " .. L["Turnier %d"]:format(tour.n) .. (tour.on and (" " .. L["(läuft)"]) or "")) or ""

    if total == 0 then
        f.histList:SetItems({})
        f.boardList:SetItems({})
        f.classList:SetItems({})
        f.empty:Set(L["Noch keine Duelle"], ns.Get("duels.record") and L["Duelle in deiner Nähe werden mitgeschrieben, sobald das Spiel sie im Chat meldet."]
            or L["Das Mitschreiben ist in den Einstellungen (Duelle) aus."])
        f.empty:Show()
        f.data:SetText("")
        return
    end

    if st.view == "hist" then
        local rows = D.Filter(opts)
        f.histList:SetItems(rows)
        local text = #rows == total and L["%d Duelle aufgezeichnet"]:format(total)
            or L["%d von %d Duellen"]:format(#rows, total)
        -- one player chosen: his record and streak in these duels
        local e = player and D.Stats(rows)[player:lower()]
        if e then
            text = L["%s: %d Duelle, %d - %d, %s"]:format(e.name, e.g, e.w, e.l, pct(e.r, e.g))
            local streak = ns.DuelInfo.StreakText(e)
            if streak then text = text .. " · " .. streak end
        end
        f.data:SetText(text .. tourText)
        if #rows == 0 then
            f.empty:Set(L["Nichts gefunden"], L["Kein Duell passt zu den Filtern."])
            f.empty:Show()
        end
    elseif st.view == "board" then
        local rows = D.Filter({ tour = st.tour, since = since })
        local list = D.Board(rows, { query = query, player = player, class = st.class, sort = st.sort, desc = st.desc })
        f.boardList:SetItems(list)
        for key, b in pairs(f.boardHeads) do
            local on = key == (st.sort or "rate")
            if b.label then b.label:SetTextColor(on and 1 or T.GOLD[1], on and 1 or T.GOLD[2], on and 1 or T.GOLD[3]) end
        end
        f.data:SetText(L["%d Spieler · nach Siegrate ab %d Duellen"]:format(#list, D.MIN_GAMES) .. tourText)
        if #list == 0 then
            f.empty:Set(L["Nichts gefunden"], L["Kein Spieler passt zu den Filtern."])
            f.empty:Show()
        end
    else
        local rows = D.Filter({ query = query, player = player, tour = st.tour, since = since })
        local chosen = st.class ~= "all" and st.class or nil
        local list, known, sides = D.ClassTable(rows, chosen, st.spec)
        f.classList:SetItems(list)
        f.classHeads.class:SetText(chosen and L["%s gegen##Klasse"]:format(className(chosen)) or L["Klasse"])
        local cover = sides > 0 and known / sides or 0
        f.data:SetText((st.spec and L["%d Duelle · %s Spezialisierungen bekannt"] or L["%d Duelle · %s Klassen bekannt"])
            :format(#rows, ns.Num(cover * 100, 1) .. " %") .. tourText)
        if #list == 0 and st.spec then
            f.empty:Set(L["Noch keine Spezialisierungen"], L["Amisia liest die Spezialisierung, wenn ein Duellant in deiner Nähe steht (Einstellungen, Duelle)."])
            f.empty:Show()
        elseif #list == 0 then
            f.empty:Set(L["Noch keine Klassen"], L["Für eine Klasse braucht es Duelle, deren Spieler eine bekannte Klasse haben. \"Klassen suchen\" fragt per /who nach."])
            f.empty:Show()
        end
    end
end

ns.RegisterPanel{ key = "duels", label = L["Duelle"], icon = "Interface\\Icons\\INV_Sword_04", order = 75,
    group = "pvp", create = build, refresh = refresh }

function ns.ShowDuels() ns.ShowPage("duels") end

local function shown() return page ~= nil and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "duels" end
ns.Listen("DUELS", function() if shown() then ns.RefreshSoon() end end)
