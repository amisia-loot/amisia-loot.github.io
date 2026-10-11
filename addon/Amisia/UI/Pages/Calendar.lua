-- Kalender (the tab "Kalender", for everyone; D-45): the raid dates as a month sheet in the look of
-- the client's calendar. The head row: the month in gold between two arrows, "Heute" on the right.
-- The grid: the weekdays on the client calendar's weekday bar (the week starts as the client's
-- calendar does: Monday on a German client, Sunday on an English one), 6 rows of 7 days on its
-- parchment, the days of other months darker, today framed in gold, the chosen day with the client's
-- day highlight. A day with a guild event shows its time and title and a dot in the colour of the own
-- state; a past day with a recorded raid its zone. A click on a day shows its dates on the right and
-- the participants of the chosen one (the raid calendar window's list: Raid/RaidCalendar.lua's data,
-- the row of UI/RaidCalendar.lua); a recorded raid opens its Raid-Log. "Anmelden ..." / "Ändern ..."
-- opens the sign-up window, officers have "Zur Aufstellung". The dates are those Amisia reads anyway
-- (tonight to 14 days, ns.SignupTerms); the participants are read through the same reader as the
-- window (ns.Cal.Read: never while the client's calendar window shows another event, not in combat,
-- always CloseEvent). Months go back to the first recorded raid and forward to the last day read.
-- Nothing here writes into the calendar.
local ADDON, ns = ...
local L, N_ = ns.L, ns.N_
local W, T = ns.W, ns.Theme
local C = T.CALPAGE
local GREY, WHITE = T.GREY, "|cffffffff"

local MONTHS = { N_("Januar"), N_("Februar"), N_("März"), N_("April"), N_("Mai"), N_("Juni"), N_("Juli"),
                 N_("August"), N_("September"), N_("Oktober"), N_("November"), N_("Dezember") }
-- the client's calendar (Blizzard_Calendar/Localization.lua) starts the week on Monday in these
-- locales, else on Sunday (Constants.lua); once it is loaded, its CALENDAR_FIRST_WEEKDAY counts
local MONDAY_FIRST = { deDE = true, enGB = true, esES = true, frFR = true, itIT = true, ruRU = true }
-- the client calendar's art (Interface\Calendar, Blizzard_Calendar): the parchment of a day (four
-- variants of 90 x 90 in CalendarBackground), the weekday bar (90 x 28 at 180/256), the day highlight
local ART = "Interface\\Calendar\\CalendarBackground"
local DAY_TEX = 90 / 256 - 0.001
local WEEKDAY_TOP, WEEKDAY_H = 180 / 256, 28 / 256 - 0.001
local HIGHLIGHT = "Interface\\Calendar\\Highlights"
local DOT = "Interface\\AddOns\\Amisia\\Media\\Icons\\dot"
local DAY = 86400

local page
local view = {}           -- the month shown: { y, m }
local chosen              -- the chosen day (a night, "yyyy-mm-dd")
local chosenAuto          -- chosen by the page (the next date), not by a click: follows the dates
local chosenTerm          -- the chosen date of that day (its index in the day's dates)
local asked               -- the dates were asked for once (ns.SignupLoadTerms)
local reader

function ns.CalendarPageFrame() return page end

---------------------------------------------------------------------------
-- Dates and months
---------------------------------------------------------------------------
local function firstWeekday()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Calendar")
    if loaded and type(CALENDAR_FIRST_WEEKDAY) == "number" and CALENDAR_FIRST_WEEKDAY >= 1 and CALENDAR_FIRST_WEEKDAY <= 7 then
        return CALENDAR_FIRST_WEEKDAY
    end
    return MONDAY_FIRST[GetLocale and GetLocale() or ""] and 2 or 1
end

local function noon(y, m, d) return time({ year = y, month = m, day = d, hour = 12 }) end
local function key(at) return date("%Y-%m-%d", at) end
local function monthIndex(y, m) return y * 12 + (m - 1) end

local function addMonths(y, m, n)
    local i = monthIndex(y, m) + n
    return math.floor(i / 12), i % 12 + 1
end

-- The 42 days of the sheet of month y, m: { { y, m, d, key, inMonth } }, starting on the first
-- weekday of the client's calendar.
local function sheet(y, m)
    local first = date("*t", noon(y, m, 1))
    local lead = (first.wday - firstWeekday() + 7) % 7
    local start = noon(y, m, 1) - lead * DAY
    local out = {}
    for i = 1, 42 do
        -- noon plus whole days, rounded to the day again (a summer time change moves an hour)
        local t = date("*t", start + (i - 1) * DAY)
        local at = noon(t.year, t.month, t.day)
        out[i] = { y = t.year, m = t.month, d = t.day, key = key(at), at = at, inMonth = t.month == m and t.year == y }
    end
    return out
end
ns.CalendarSheet = sheet

-- The guild events by night (ns.SignupTerms: tonight to 14 days) and the recorded raids by night.
local function byNight()
    local terms, raids = {}, {}
    for _, t in ipairs(ns.SignupTerms() or {}) do
        terms[t.night] = terms[t.night] or {}
        table.insert(terms[t.night], t)
    end
    for _, list in pairs(terms) do
        table.sort(list, function(a, b) return a.at < b.at end)
    end
    for _, s in ipairs(ns.Sessions and ns.Sessions() or {}) do
        if type(s.date) == "string" then
            raids[s.date] = raids[s.date] or {}
            table.insert(raids[s.date], s)
        end
    end
    return terms, raids
end

-- The months the sheet may show: back to the first recorded raid, forward to the last day read.
local function range()
    local now = time()
    local t = date("*t", now)
    local lo = monthIndex(t.year, t.month)
    for _, s in ipairs(ns.Sessions and ns.Sessions() or {}) do
        local y, m = tostring(s.date or ""):match("^(%d+)%-(%d+)")
        if y then lo = math.min(lo, monthIndex(tonumber(y), tonumber(m))) end
    end
    local last = date("*t", now + ns.Cal.DAYS * DAY)
    return lo, monthIndex(last.year, last.month)
end

local function showMonth(y, m)
    local lo, hi = range()
    local i = math.max(lo, math.min(hi, monthIndex(y, m)))
    view.y, view.m = math.floor(i / 12), i % 12 + 1
end

-- The chosen date of the chosen day (the chosen one of its dates, else its first raid, else its first).
local function termOf(terms)
    local list = chosen and terms[chosen]
    if not list or #list == 0 then return nil end
    if chosenTerm and list[chosenTerm] then return list[chosenTerm] end
    for i, t in ipairs(list) do
        if t.raid then chosenTerm = i return t end
    end
    chosenTerm = 1
    return list[1]
end

-- The day chosen when none is: the next date's, else tonight's.
local function ensureChosen()
    if chosen and not chosenAuto then return end
    local nxt = ns.SignupNextTerm and ns.SignupNextTerm()
    if nxt and nxt.night ~= chosen then chosenTerm = nil end
    chosen = nxt and nxt.night or (ns.NightOf and ns.NightOf(time()) or key(time()))
    chosenAuto = true
end

local function currentTerm()
    local terms = byNight()
    return termOf(terms)
end

-- A text cut to width px with "..." (the game font has no ellipsis character, D-07).
local function fit(fs, text, width)
    fs:SetText(text)
    if (fs:GetStringWidth() or 0) <= width then return end
    local cut = text
    while #cut > 1 do
        cut = cut:sub(1, -2):gsub("[\192-\255][\128-\191]*$", "")
        fs:SetText(cut .. "...")
        if (fs:GetStringWidth() or 0) <= width then return end
    end
end

-- The colour of the own state of a date (its dot): the sign-up from Amisia, else the calendar's.
local function ownColor(t)
    local V = ns.RaidCalView
    local _, color = V.OwnState(t)
    return V.RGB[color] or V.RGB.grey
end

---------------------------------------------------------------------------
-- Choosing
---------------------------------------------------------------------------
local function choose(night, index)
    chosen, chosenTerm, chosenAuto = night, index, false
    if reader then reader.Reset() end
    ns.Refresh()
    if reader then reader.Read(false) end
end
ns.CalendarChoose = choose

-- Opens the page at a night (default: the next date, else today).
function ns.ShowCalendar(night)
    if night then
        local y, m = night:match("^(%d+)%-(%d+)")
        if y then showMonth(tonumber(y), tonumber(m)) end
        chosen, chosenTerm, chosenAuto = night, nil, false
    end
    ns.ShowPage("calendar")
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function buildCell(f, i)
    local cell = CreateFrame("Button", nil, f.grid)
    cell:SetSize(C.CELL_W, C.CELL_H)
    local row, col = math.floor((i - 1) / 7), (i - 1) % 7
    cell:SetPoint("TOPLEFT", col * C.CELL_W, -(C.HEAD_H + row * C.CELL_H))
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints()
    cell.bg:SetTexture(ART)
    -- one of the four parchment variants, by place (the client picks them at random)
    local qx, qy = (col + row) % 2, row % 2
    cell.bg:SetTexCoord(qx * DAY_TEX, qx * DAY_TEX + DAY_TEX, qy * DAY_TEX, qy * DAY_TEX + DAY_TEX)
    cell.sel = cell:CreateTexture(nil, "ARTWORK")
    cell.sel:SetAllPoints()
    cell.sel:SetTexture(HIGHLIGHT)
    cell.sel:SetTexCoord(0, 0.34375, 0, 0.6875)
    cell.sel:SetBlendMode("ADD")
    cell.sel:Hide()
    cell.hover = cell:CreateTexture(nil, "HIGHLIGHT")
    cell.hover:SetAllPoints()
    cell.hover:SetTexture(HIGHLIGHT)
    cell.hover:SetTexCoord(0, 0.34375, 0, 0.6875)
    cell.hover:SetBlendMode("ADD")
    cell.hover:SetAlpha(0.5)
    cell.today = W.Border(cell, T.GOLD[1], T.GOLD[2], T.GOLD[3], 1)
    for _, e in ipairs(cell.today) do e:SetDrawLayer("OVERLAY") end
    local inner = C.CELL_W - 2 * C.PAD
    cell.day = W.Text(cell, T.FONT.body, inner - C.DOT - 2)
    cell.day:SetPoint("TOPLEFT", C.PAD, -C.DAY_Y)
    cell.dot = cell:CreateTexture(nil, "OVERLAY")
    cell.dot:SetSize(C.DOT, C.DOT)
    cell.dot:SetPoint("TOPRIGHT", -C.PAD, -(C.DAY_Y + 3))
    cell.dot:SetTexture(DOT)
    cell.lines = {}
    for k = 1, 3 do
        local fs = W.Text(cell, T.FONT.text, inner)
        fs:SetPoint("TOPLEFT", C.PAD, -(C.EVENT_Y + (k - 1) * C.LINE_H))
        cell.lines[k] = fs
    end
    cell:SetScript("OnClick", function(self) if self.info then choose(self.info.key, nil) end end)
    cell:SetScript("OnEnter", function(self)
        local info = self.info
        if not info or (not info.terms and not info.raids) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.RaidCalView.DayText(info.at), 1, 0.82, 0)
        for _, t in ipairs(info.terms or {}) do
            GameTooltip:AddLine(("%s %s"):format(date("%H:%M", t.at), t.title or "?"), 1, 1, 1)
        end
        for _, s in ipairs(info.raids or {}) do
            GameTooltip:AddLine(L["Aufgezeichnet: %s"]:format(s.zone or "?"), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return cell
end

local function fillCell(cell, d, terms, raids, today)
    cell.info = { key = d.key, at = d.at, terms = terms[d.key], raids = raids[d.key] }
    local shade = d.inMonth and 1 or C.DARK
    cell.bg:SetVertexColor(shade, shade, shade)
    cell.day:SetText(tostring(d.d))
    cell.day:SetTextColor(d.inMonth and 1 or 0.55, d.inMonth and 1 or 0.55, d.inMonth and 1 or 0.55)
    for _, e in ipairs(cell.today) do e:SetShown(d.key == today) end
    cell.sel:SetShown(d.key == chosen)
    local inner = C.CELL_W - 2 * C.PAD
    local lines, k = {}, 0
    local list = terms[d.key]
    if list then
        -- the day's raid first (the date the inset chooses), else its first date
        local t = list[1]
        for _, e in ipairs(list) do
            if e.raid then t = e break end
        end
        lines[1] = { WHITE .. date("%H:%M", t.at) .. "|r" }
        lines[2] = { t.title or "?", t.raid and { 1, 0.82, 0 } or { 0.8, 0.8, 0.8 } }
        if #list > 1 then lines[3] = { GREY .. L["+%d weitere"]:format(#list - 1) .. "|r" } end
        local c = ownColor(t)
        cell.dot:SetVertexColor(c[1], c[2], c[3])
        cell.dot:Show()
    else
        cell.dot:Hide()
        for _, s in ipairs(raids[d.key] or {}) do
            if #lines < 3 then lines[#lines + 1] = { s.zone or "?", { 0.6, 0.6, 0.6 } } end
        end
    end
    for i, fs in ipairs(cell.lines) do
        local l = lines[i]
        if l then
            k = k + 1
            fs:SetTextColor((l[2] or { 1, 1, 1 })[1], (l[2] or { 1, 1, 1 })[2], (l[2] or { 1, 1, 1 })[3])
            if l[2] then fit(fs, l[1], inner) else fs:SetText(l[1]) end
            fs:Show()
        else
            fs:SetText("")
            fs:Hide()
        end
    end
end

-- A date of the chosen day on the right: its time and title, the own state's dot; recorded raids
-- the same with the zone (a click opens their Raid-Log).
local function buildTerm(f, i)
    local b = CreateFrame("Button", nil, f.right)
    b:SetHeight(C.TERM_H)
    b:SetPoint("TOPLEFT", C.INNER, -(C.TERM_Y + (i - 1) * C.TERM_H))
    b:SetPoint("TOPRIGHT", -C.INNER, -(C.TERM_Y + (i - 1) * C.TERM_H))
    b.sel = W.SelectBar(b)
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(C.DOT, C.DOT)
    b.dot:SetPoint("LEFT", 2, 0)
    b.dot:SetTexture(DOT)
    b.text = W.Text(b, T.FONT.text, C.RIGHT_W - 2 * C.INNER - C.DOT - 8)
    b.text:SetPoint("LEFT", C.DOT + 6, 0)
    b:SetScript("OnClick", function(self)
        if self.term then
            choose(chosen, self.index)
        elseif self.raid and ns.ShowRaidLog then
            ns.ShowRaidLog(nil, self.raid.id)
        end
    end)
    b:Hide()
    return b
end

local function build(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: the month between its arrows, "Heute" on the right
    f:Bands({ "row" })
    f.prev = W.ArrowButton(f, "left", T.ARROW, function() local y, m = addMonths(view.y, view.m, -1) showMonth(y, m) ns.Refresh() end)
    f.next = W.ArrowButton(f, "right", T.ARROW, function() local y, m = addMonths(view.y, view.m, 1) showMonth(y, m) ns.Refresh() end)
    W.Tooltip(f.prev, L["Voriger Monat"])
    W.Tooltip(f.next, L["Nächster Monat"])
    f.title = W.Text(f, T.FONT.big, C.TITLE_W)
    f.title:SetJustifyH("CENTER")
    f.today = W.Button(f, L["Heute"], C.TODAY_W, function()
        local t = date("*t")
        showMonth(t.year, t.month)
        choose(ns.NightOf and ns.NightOf(time()) or key(time()), nil)
    end)
    W.FitChip(f.today, C.TODAY_W)
    f:Place(1, { f.prev, f.title, f.next }, { f.today })

    -- the grid: the weekday bar, then 6 rows of 7 days
    f.grid = CreateFrame("Frame", nil, f)
    f.grid:SetSize(7 * C.CELL_W, C.HEAD_H + 6 * C.CELL_H)
    f.grid:SetPoint("TOPLEFT", 0, -C.GRID_Y)
    f.heads = {}
    for i = 1, 7 do
        local bar = f.grid:CreateTexture(nil, "BACKGROUND")
        bar:SetSize(C.CELL_W, C.HEAD_H)
        bar:SetPoint("TOPLEFT", (i - 1) * C.CELL_W, 0)
        bar:SetTexture(ART)
        local left = (i % 2) * DAY_TEX
        bar:SetTexCoord(left, left + DAY_TEX, WEEKDAY_TOP, WEEKDAY_TOP + WEEKDAY_H)
        local fs = W.Text(f.grid, T.FONT.title, C.CELL_W)
        fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(1, 1, 0.6)
        f.heads[i] = fs
    end
    f.cells = {}
    for i = 1, 42 do f.cells[i] = buildCell(f, i) end

    -- the chosen day on the right
    f.right = W.Inset(f)
    f.right:SetPoint("TOPLEFT", C.RIGHT_X, -C.GRID_Y)
    f.right:SetSize(C.RIGHT_W, C.HEAD_H + 6 * C.CELL_H)
    f.right.fill(0, 0, 0, 0.25)
    f.dayTitle = W.Text(f.right, T.FONT.title, C.RIGHT_W - 2 * C.INNER)
    f.dayTitle:SetPoint("TOPLEFT", C.INNER, -C.INNER)
    f.terms = {}
    for i = 1, C.TERMS do f.terms[i] = buildTerm(f, i) end
    f.totals = W.Text(f.right, T.FONT.text, C.RIGHT_W - 2 * C.INNER)
    f.totals:SetPoint("TOPLEFT", C.INNER, -C.TOTALS_Y)
    local V = ns.RaidCalView
    f.list = W.List(f.right, C.ROWS, C.ROW_H, function(r) V.BuildRow(r, C) end, V.FillRow)
    f.list:SetWidth(C.LIST_W)
    f.list:SetPoint("TOPLEFT", C.INNER, -C.LIST_Y)
    f.empty = W.Text(f.right, T.FONT.dim, C.RIGHT_W - 4 * C.INNER, true)
    f.empty:SetJustifyH("CENTER")
    f.empty:SetPoint("TOP", f.right, "TOP", 0, -C.LIST_Y - 10)

    -- the bottom row: the read's state, the buttons; the hint under it
    f:Footer({ "hint" })
    f.status = W.Text(f, T.FONT.hint)
    f.signup = W.Button(f, L["Anmelden ..."], C.BUTTON_W, function()
        local t = currentTerm()
        if t and ns.ShowSignup then ns.ShowSignup(t.night) end
    end)
    f.lineup = W.Button(f, L["Zur Aufstellung"], C.BUTTON_W, function()
        local t = currentTerm()
        if t and ns.ShowLineup then ns.ShowLineup("match", t.night) end
    end)
    W.FitChip(f.lineup, C.BUTTON_W)
    W.Tooltip(f.lineup, L["Zur Aufstellung"], L["Öffnet die Seite Aufstellung mit der Nacht dieses Termins (nur Offiziere)."])
    f:BottomRow({ { f.status, fill = true } }, { f.lineup, f.signup }, { shown = true })
    f.hint:SetText(L["Klick auf einen Tag: seine Termine und wer kommt. Der Punkt zeigt deinen Stand."])

    -- shown: on the screen, not only the open page of a closed window (that read the calendar on every
    -- change in the background; the lineup page asks the same)
    reader = V.Reader({ shown = function()
            local main = _G.AmisiaFrame
            return page ~= nil and page:IsVisible() and (not main or main:IsShown()) and ns.CurrentPage() == "calendar"
        end,
        term = currentTerm, refresh = function() if ns.CurrentPage() == "calendar" then ns.Refresh() end end })
    -- the chosen date is read when the page shows (and on a click on a day), never from a refresh:
    -- a read that fails at once would refresh and read again without end
    -- (on the next frame: the main window shows after its page on the first open)
    f:SetScript("OnShow", function()
        ensureChosen()
        C_Timer.After(0, function() reader.Read(false) end)
    end)
    return f
end

local function fillRight(f, terms, raids)
    local V = ns.RaidCalView
    local day = chosen and terms[chosen]
    local recorded = chosen and raids[chosen]
    local at = chosen and noon(tonumber(chosen:sub(1, 4)) or 2000, tonumber(chosen:sub(6, 7)) or 1, tonumber(chosen:sub(9, 10)) or 1)
    f.dayTitle:SetText(at and V.DayText(at) or "")
    local t = termOf(terms)
    -- the dates of the day, else its recorded raids
    local rows = {}
    for i, e in ipairs(day or {}) do rows[#rows + 1] = { term = e, index = i } end
    if #rows == 0 then
        for _, s in ipairs(recorded or {}) do rows[#rows + 1] = { raid = s } end
    end
    for i, b in ipairs(f.terms) do
        local r = rows[i]
        b.term, b.raid, b.index = r and r.term, r and r.raid, r and r.index
        if r and r.term then
            local c = ownColor(r.term)
            b.dot:SetVertexColor(c[1], c[2], c[3])
            b.dot:Show()
            fit(b.text, ("%s %s"):format(date("%H:%M", r.term.at), r.term.title or "?"), C.RIGHT_W - 2 * C.INNER - C.DOT - 8)
            b.sel:SetShown(r.term == t)
            b:Show()
        elseif r and r.raid then
            b.dot:Hide()
            local n = 0
            for _ in pairs(type(r.raid.members) == "table" and r.raid.members or {}) do n = n + 1 end
            fit(b.text, GREY .. L["Aufgezeichnet: %s"]:format(r.raid.zone or "?") .. "|r", C.RIGHT_W - 2 * C.INNER - C.DOT - 8)
            b.sel:Hide()
            b:Show()
        else
            b:Hide()
        end
    end
    local list, n, groups = {}, 0, {}
    if t then
        local rows2, _, count, byGroup = ns.RaidCal.Rows(t.night, t)
        list, n, groups = rows2, count, byGroup
    end
    f.list:SetItems(list)
    -- the totals of the chosen date: signed up and tentative (the bench when someone is on it)
    if t then
        local parts = {}
        for _, g in ipairs(ns.RaidCal.GROUPS) do
            local k = groups[g.key] or 0
            if g.key == "in" or g.key == "maybe" or (g.key == "bench" and k > 0) then
                parts[#parts + 1] = ("%s%s|r %s%d|r"):format(V.GROUP_COLOR[g.key], V.GROUP_WORD[g.key], WHITE, k)
            end
        end
        f.totals:SetText(table.concat(parts, GREY .. " · |r"))
    else
        f.totals:SetText("")
    end
    local empty
    if not chosen then
        empty = L["Klick auf einen Tag."]
    elseif not t then
        if #rows > 0 then
            empty = nil
        elseif not IsInGuild() then
            empty = L["Nur in einer Gilde"]
        elseif not ns.Cal.Available() then
            empty = L["Kalender nicht verfügbar."]
        elseif not ns.SignupTerms() then
            empty = L["Termine werden gelesen ..."]
        else
            empty = L["Kein Termin an diesem Tag."]
        end
    elseif n == 0 then
        empty = L["Noch niemand angemeldet."]
    end
    f.empty:SetText(empty or "")
    f.empty:SetShown(empty ~= nil)
    -- the bottom row
    local rec = t and ns.SignupOf()[t.night]
    f.signup:SetText(rec and L["Ändern ..."] or L["Anmelden ..."])
    W.FitChip(f.signup, C.BUTTON_W)
    f.signup:SetShown(t ~= nil)
    f.lineup:SetShown(t ~= nil and ns.LineupAllowed ~= nil and ns.LineupAllowed() or false)
    f.status:SetText(t and reader.Status(t) or "")
    f:BottomRow()
end

local function refresh(f)
    if not ns.SignupTerms() and not asked and IsInGuild() then
        asked = true
        ns.SignupLoadTerms(function()
            if ns.CurrentPage() == "calendar" then ns.Refresh() end
            if reader then reader.Read(false) end
        end)
    end
    local now = time()
    local today = key(now)
    if not view.y then
        local t = date("*t", now)
        showMonth(t.year, t.month)
    end
    local terms, raids = byNight()
    ensureChosen()
    f.title:SetText(("%s %d"):format(L[MONTHS[view.m]], view.y))
    local lo, hi = range()
    local i = monthIndex(view.y, view.m)
    f.prev:SetEnabled(i > lo)
    f.next:SetEnabled(i < hi)
    f.prev:UpdateArrow()
    f.next:UpdateArrow()
    local fw = firstWeekday()
    for k = 1, 7 do f.heads[k]:SetText(ns.Cal.WeekdayShort((fw + k - 2) % 7 + 1)) end
    for k, d in ipairs(sheet(view.y, view.m)) do fillCell(f.cells[k], d, terms, raids, today) end
    fillRight(f, terms, raids)
end

ns.RegisterPanel{ key = "calendar", label = L["Kalender"], icon = "Interface\\Icons\\INV_Misc_Note_02", order = 5, group = "calendar",
    create = function(parent)
        local f = build(parent)
        return f
    end,
    refresh = function(f) refresh(f) end }

for _, msg in ipairs({ "RAIDCAL", "SIGNUP", "SIGNUP_SEEN" }) do
    ns.Listen(msg, function()
        if page and page:IsShown() and ns.CurrentPage() == "calendar" then ns.Refresh() end
    end)
end
