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
-- always CloseEvent). Months go back to the first recorded raid and forward to the last day read or
-- the last day the game takes an event on (C_Calendar.GetMaxCreateDate).
-- F-217 (D-142): the shown month also lists every guild event, guild announcement and own event or
-- invite of the game calendar (ns.Cal.Month), the latter two in their own colour and without a
-- participant list. "Termin anlegen ..." turns the right inset into a form whose "Anlegen" makes a guild
-- event or announcement in the game calendar with the same click (ns.CalCreate); "Für Discord" shows the
-- chosen date as Discord text to copy. Nothing else here writes into the calendar.
local ADDON, ns = ...
ns.Load(function()
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
local mode                -- the right inset: nil the day, "form" a new event, "discord" the text to copy
local months = {}         -- [y * 12 + m - 1] = { list (ns.Cal.Month), at = GetTime(), dirty, far }
local monthAsking         -- the month being read
local form = {}           -- the form's values (kind, type, tex, texTitle, time, title, desc)
local formError, formWait -- the form's last reason; an entry runs
local KIND_COLOR = { GUILD_ANNOUNCEMENT = { 0.55, 0.78, 1 }, PLAYER = { 0.62, 0.86, 0.62 } }
local CC = function() return ns.CalCreate end

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

-- The guild events by night (ns.SignupTerms: tonight to 14 days; they carry the sign-up and the
-- participants), the other events of the months read (ns.Cal.Month: marked extra) and the recorded
-- raids by night.
local function byNight()
    local terms, raids = {}, {}
    local seen = {}
    for _, t in ipairs(ns.SignupTerms() or {}) do
        terms[t.night] = terms[t.night] or {}
        table.insert(terms[t.night], t)
        if t.id then seen[t.id] = true end
        seen[t.at .. "\t" .. tostring(t.title)] = true
    end
    for _, mo in pairs(months) do
        for _, e in ipairs(mo.list or {}) do
            if not (e.id and seen[e.id]) and not seen[e.at .. "\t" .. tostring(e.title)] then
                if e.id then seen[e.id] = true end
                e.extra = true
                terms[e.night] = terms[e.night] or {}
                table.insert(terms[e.night], e)
            end
        end
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
    local hi = monthIndex(last.year, last.month)
    local max = CC() and CC().MaxDay()
    if max then
        local t2 = date("*t", max)
        hi = math.max(hi, monthIndex(t2.year, t2.month))
    end
    return lo, hi
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

-- The chosen date (any event of the day) and the chosen sign-up date (the reader's: never an extra).
local function currentItem()
    local terms = byNight()
    return termOf(terms)
end
local function currentTerm()
    local t = currentItem()
    return t and not t.extra and t or nil
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
    if t.extra and t.kind ~= "GUILD_EVENT" then return KIND_COLOR[t.kind] or V.RGB.grey end
    local _, color = V.OwnState(t)
    return V.RGB[color] or V.RGB.grey
end

-- The colour of a date's title: a raid gold, an announcement or own event in its kind's colour, else grey.
local function titleColor(t)
    if t.extra and KIND_COLOR[t.kind] then return KIND_COLOR[t.kind] end
    return t.raid and { 1, 0.82, 0 } or { 0.8, 0.8, 0.8 }
end

---------------------------------------------------------------------------
-- Choosing
---------------------------------------------------------------------------
local function choose(night, index)
    chosen, chosenTerm, chosenAuto = night, index, false
    -- the Discord text belongs to one date; the form follows the chosen day
    if mode == "discord" then mode = nil end
    formError = nil
    if reader then reader.Reset() end
    ns.Refresh()
    if reader then reader.Read(false) end
end

---------------------------------------------------------------------------
-- The months of the game calendar (ns.Cal.Month)
---------------------------------------------------------------------------
local MONTH_AGAIN = 120   -- seconds: a month is read again after this long
local MONTH_DIRTY = 2     -- after a change in the calendar: the set month and its neighbours this soon
local MONTH_FAR = 30      -- a month the client has to set (SetAbsMonth) at most this often

local function setIndex()
    local info = ns.Cal.call("GetMonthInfo", 0)
    local y, m = type(info) == "table" and ns.Plain(info.year), type(info) == "table" and ns.Plain(info.month)
    return type(y) == "number" and type(m) == "number" and monthIndex(y, m) or nil
end

-- Reads the shown month when it was never read, is old, or the calendar changed since.
local function askMonth()
    if not view.y or monthAsking or not IsInGuild() or not ns.Cal.CanReadMonth() then return end
    local i = monthIndex(view.y, view.m)
    local mo = months[i]
    local now = GetTime()
    if mo then
        local age = now - mo.at
        local soon = mo.far and MONTH_FAR or MONTH_DIRTY
        if not (age > MONTH_AGAIN or (mo.dirty and age >= soon)) then return end
    end
    local set = setIndex()
    local far = not set or math.abs(i - set) > 1
    local y, m = view.y, view.m
    monthAsking = i
    ns.Cal.Month(y, m, function(list, partial)
        monthAsking = nil
        local old = months[i]
        -- not read now (busy, combat, the client's window) or not whole: the old list stays or the
        -- new one counts until it is read again
        months[i] = { list = list or (old and old.list), at = GetTime(), far = far, dirty = (list == nil or partial == true) or nil }
        if page and page:IsVisible() and ns.CurrentPage() == "calendar" then ns.Refresh() end
    end)
end

-- A change in the calendar: every month read is read again when shown.
ns.Listen("CALENDAR_CHANGED", function()
    for _, mo in pairs(months) do mo.dirty = true end
    if page and page:IsVisible() and ns.CurrentPage() == "calendar" then
        C_Timer.After(MONTH_DIRTY, function()
            if page and page:IsVisible() and ns.CurrentPage() == "calendar" then ns.Refresh() end
        end)
    end
end)

---------------------------------------------------------------------------
-- The new event's form (F-217)
---------------------------------------------------------------------------
local TYPE_ORDER = { 0, 1, 2, 3, 4 }

local function chosenNoon()
    if not chosen then return nil end
    return noon(tonumber(chosen:sub(1, 4)) or 2000, tonumber(chosen:sub(6, 7)) or 1, tonumber(chosen:sub(9, 10)) or 1)
end

-- Whether a day can take a new event (today up to the client's last day), and why not.
local function dayOpen()
    local day = chosenNoon()
    if not day then return false end
    local today = CC().Today()
    if day < today - 3600 then return false, "past" end
    local max = CC().MaxDay()
    if max and day > max + 3600 then return false, "late" end
    return true
end

local function openForm()
    local last = CC().Form()
    form = { kind = last.kind, type = last.type, time = last.time, texTitle = last.tex }
    if form.kind == "announce" and not CC().CanAnnounce() then form.kind = "signup" end
    form.tex = nil
    for _, x in ipairs(CC().Textures(form.type)) do
        if x.title == form.texTitle then form.tex = x.index end
    end
    if not form.tex then form.texTitle = nil end
    formError, formWait = nil, nil
    mode = "form"
    if page then
        page.titleBox:SetText(form.texTitle or "")
        page.descBox.box:SetText("")
        page.timeBox:SetText(ns.FormatTime(form.time))
    end
    ns.Refresh()
end

-- The typed time, held; nil when it cannot be read.
local function typedTime()
    local v = ns.ParseTime(page.timeBox:GetText())
    if v then form.time = v end
    return v
end

local function stepTime(dir)
    local v = typedTime() or form.time or CC().DEFAULT_TIME
    v = (math.floor(v / CC().STEP) + dir) * CC().STEP
    form.time = v % (24 * 60)
    page.timeBox:SetText(ns.FormatTime(form.time))
end

-- "Anlegen": the whole entry inside this click (AddEvent needs a hardware event).
local function create()
    if formWait then return end
    formError = nil
    if not typedTime() then
        formError = CC().Why("time")
        return ns.Refresh()
    end
    local f = {
        kind = form.kind, type = form.type, tex = form.tex, texTitle = form.texTitle, time = form.time,
        day = chosenNoon(), title = page.titleBox:GetText(), desc = page.descBox.box:GetText(),
    }
    local started, why = CC().Create(f, function(ok, reason, detail)
        formWait = nil
        if ok then
            ns.msg(L["Termin im Spielkalender angelegt: %s"]:format(("%s %s %s"):format(ns.RaidCalView.DayText(f.at),
                date("%H:%M", f.at), f.cleanTitle or "")))
            mode = nil
            for _, mo in pairs(months) do mo.dirty = true end
        else
            local text = CC().Why(reason)
            if detail and reason == "error" then text = text .. " " .. tostring(detail) end
            if reason ~= "blocked" and reason ~= "refused" then text = text .. " " .. L["Lege ihn bitte im Spielkalender an."] end
            formError = text
        end
        ns.Refresh()
    end)
    if not started then
        formError = CC().Why(why)
    elseif formWait == nil and mode == "form" and not formError then
        -- still waiting for the client's answer (an answer at once has cleared it already)
        formWait = CC().Busy() or nil
    end
    ns.Refresh()
end

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
    cell.today = W.Border(cell, T.GOLD[1], T.GOLD[2], T.GOLD[3], 1, C.TODAY)
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
        -- one line each: "19:30" wrapped to "19:3" + "0" over the title in the game
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
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
        lines[2] = { t.title or "?", titleColor(t) }
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
    f.today = W.Link(f, L["Heute"], function()
        local t = date("*t")
        showMonth(t.year, t.month)
        choose(ns.NightOf and ns.NightOf(time()) or key(time()), nil)
    end)
    W.FitChip(f.today)
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
    f.right:SetPoint("TOPLEFT", C.RIGHT_X, -(C.GRID_Y + C.RIGHT_TOP))
    f.right:SetSize(C.RIGHT_W, C.HEAD_H + 6 * C.CELL_H - C.RIGHT_TOP)
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
    -- an event that is no guild event with sign-up (or one after the 14 days): its kind, type, creator
    f.info = W.Text(f.right, T.FONT.text, C.RIGHT_W - 2 * C.INNER, true)
    f.info:SetPoint("TOPLEFT", C.INNER, -C.TOTALS_Y)

    -- the new event's form (F-217) in the right inset, over the day's view
    local FW = C.RIGHT_W - 2 * C.INNER
    f.form = CreateFrame("Frame", nil, f.right)
    f.form:SetPoint("TOPLEFT", 0, -C.TERM_Y)
    f.form:SetPoint("BOTTOMRIGHT", 0, 0)
    f.form:Hide()
    local F = f.form
    local y = 0
    local function label(text)
        local fs = W.Text(F, T.FONT.dim, FW)
        fs:SetPoint("TOPLEFT", C.INNER, -y)
        fs:SetText(text)
        y = y + C.FORM_LABEL_H
        return fs
    end
    local function field(w, h)
        w:SetPoint("TOPLEFT", C.INNER, -y)
        y = y + (h or T.FIELD_H) + C.FORM_GAP
        return w
    end
    f.kindLabel = label(L["Art"])
    f.kind = field(W.Picker(F, FW, function(v)
        form.kind = v or "signup"
        ns.Refresh()
    end))
    f.typeLabel = label(L["Typ"])
    f.typePick = field(W.Picker(F, FW, function(v)
        local before = form.texTitle
        form.type = v or 4
        form.tex, form.texTitle = nil, nil
        if f.titleBox:GetText() == (before or "") then f.titleBox:SetText("") end
        ns.Refresh()
    end))
    f.texY = y
    f.texLabel = label(L["Instanz##Termin"])
    f.texPick = field(W.Picker(F, FW, function(v)
        local before = form.texTitle
        form.tex, form.texTitle = v, nil
        for _, x in ipairs(CC().Textures(form.type)) do
            if x.index == v then form.texTitle = x.title end
        end
        -- the title follows the instance until the player typed one of his own
        local text = f.titleBox:GetText()
        if text == "" or text == before then f.titleBox:SetText(CC().Clean(form.texTitle, CC().TITLE_CHARS) or "") end
        ns.Refresh()
    end))
    f.restY = y
    f.timeLabel = W.Text(F, T.FONT.dim, FW)
    f.timeLabel:SetText(L["Uhrzeit"])
    f.timeMinus = W.ArrowButton(F, "left", T.ARROW_SMALL, function() stepTime(-1) end)
    f.timeBox = W.TimeBox(F, C.TIME_W, function() if not typedTime() then page.timeBox:SetText(ns.FormatTime(form.time)) end end)
    if f.timeBox.SetMaxLetters then f.timeBox:SetMaxLetters(5) end
    f.timePlus = W.ArrowButton(F, "right", T.ARROW_SMALL, function() stepTime(1) end)
    W.Tooltip(f.timeMinus, L["15 Minuten früher"])
    W.Tooltip(f.timePlus, L["15 Minuten später"])
    f.titleLabel = W.Text(F, T.FONT.dim, FW)
    f.titleLabel:SetText(L["Titel"])
    f.titleBox = W.LineEdit(F, FW)
    if f.titleBox.SetMaxLetters then f.titleBox:SetMaxLetters(CC().TITLE_CHARS) end
    f.descLabel = W.Text(F, T.FONT.dim, FW)
    f.descLabel:SetText(L["Beschreibung"])
    f.descBox = W.EditArea(F)
    f.descBox:SetSize(FW, C.DESC_H)
    f.descBox.box:SetMaxLetters(CC().DESC_CHARS)
    f.formHint = W.Text(F, T.FONT.hint, FW, true)
    f.formAdd = W.Button(F, L["Anlegen##Termin"], C.FORM_BUTTON_W, create)
    f.formCancel = W.Link(F, L["Abbrechen"], function()
        mode, formError = nil, nil
        ns.Refresh()
    end)
    W.FitChip(f.formCancel)
    f.formAdd:SetPoint("BOTTOMRIGHT", -C.INNER, C.INNER)
    f.formCancel:SetPoint("RIGHT", f.formAdd, "LEFT", -T.LAYOUT.ITEM_GAP, 0)

    -- the chosen date as Discord text (part C)
    f.discordBox = W.EditArea(f.right)
    f.discordBox:SetPoint("TOPLEFT", C.INNER, -C.TERM_Y)
    f.discordBox:SetPoint("TOPRIGHT", -C.INNER, -C.TERM_Y)
    f.discordBox:SetHeight(C.DISCORD_H)
    f.discordBox:Hide()
    f.discordHint = W.Text(f.right, T.FONT.hint, FW, true)
    f.discordHint:SetPoint("TOPLEFT", f.discordBox, "BOTTOMLEFT", 0, -C.FORM_GAP)
    f.discordHint:SetText(L["Strg+A, Strg+C, dann in Discord einfügen. Discord zeigt jedem die Zeit in seiner Zeitzone."])
    f.discordHint:Hide()
    f.discordClose = W.Link(f.right, L["Schließen"], function()
        mode = nil
        ns.Refresh()
    end)
    W.FitChip(f.discordClose)
    f.discordClose:SetPoint("BOTTOMRIGHT", -C.INNER, C.INNER)
    f.discordClose:Hide()

    -- the bottom row: the read's state, the buttons; the hint under it
    f:Footer({ { "hint", help = true } })
    f.status = W.Text(f, T.FONT.hint)
    f.signup = W.Button(f, L["Anmelden ..."], C.BUTTON_W, function()
        local t = currentTerm()
        if t and ns.ShowSignup then ns.ShowSignup(t.night) end
    end)
    f.lineup = W.Link(f, L["Zur Aufstellung"], function()
        local t = currentTerm()
        if t and ns.ShowLineup then ns.ShowLineup("match", t.night) end
    end)
    W.FitChip(f.lineup)
    W.Tooltip(f.lineup, L["Zur Aufstellung"], L["Öffnet die Seite Aufstellung mit der Nacht dieses Termins (nur Offiziere)."])
    f.discord = W.Link(f, L["Für Discord"], function()
        mode = mode ~= "discord" and "discord" or nil
        ns.Refresh()
    end)
    W.FitChip(f.discord)
    W.Tooltip(f.discord, L["Für Discord"], L["Der gewählte Termin als Text für Discord, zum Kopieren."])
    f.create = W.Button(f, L["Termin anlegen ..."], C.BUTTON_W, openForm)
    W.FitChip(f.create, C.BUTTON_W)
    W.Tooltip(f.create, L["Termin anlegen"], L["Legt an diesem Tag einen Gildentermin im Spielkalender an. Die ganze Gilde sieht ihn dort, auch ohne Amisia."])
    f:BottomRow({ { f.status, fill = true } }, { f.discord, f.lineup, f.signup, f.create }, { shown = true })
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

-- The form's fields as the values stand (the instance row only for a raid or a dungeon).
local function fillForm(f)
    local FL, G = C.FORM_LABEL_H, C.FORM_GAP
    local kinds = { { value = "signup", text = L["Gildenereignis (mit Anmeldung)"] } }
    if CC().CanAnnounce() then kinds[2] = { value = "announce", text = L["Gildenankündigung"] } end
    f.kind:SetValues(kinds)
    f.kind:SetValue(form.kind)
    local types = {}
    for _, t in ipairs(TYPE_ORDER) do types[#types + 1] = { value = t, text = L[ns.Cal.TYPE_WORD[t]] } end
    f.typePick:SetValues(types)
    f.typePick:SetValue(form.type)
    local texs = CC().Textures(form.type)
    local withTex = form.type == 0 or form.type == 1
    f.texLabel:SetShown(withTex)
    f.texPick:SetShown(withTex)
    if withTex then
        local vals = {}
        for _, x in ipairs(texs) do vals[#vals + 1] = { value = x.index, text = x.title } end
        f.texPick:SetValues(vals)
        f.texPick:SetValue(form.tex)
        if not form.tex then f.texPick.label:SetText(T.GREY .. (#vals > 0 and L["Instanz wählen"] or L["Das Spiel nennt keine Instanzen."]) .. "|r") end
    end
    local y = withTex and f.restY or f.texY
    local function at(w, dy, x) w:ClearAllPoints() w:SetPoint("TOPLEFT", x or C.INNER, -(y + (dy or 0))) end
    at(f.timeLabel)
    at(f.timeMinus, FL)
    f.timeBox:ClearAllPoints()
    f.timeBox:SetPoint("LEFT", f.timeMinus, "RIGHT", 2, 0)
    f.timePlus:ClearAllPoints()
    f.timePlus:SetPoint("LEFT", f.timeBox, "RIGHT", 2, 0)
    y = y + FL + T.FIELD_H + G
    at(f.titleLabel)
    at(f.titleBox, FL)
    y = y + FL + T.FIELD_H + G
    at(f.descLabel)
    at(f.descBox, FL)
    y = y + FL + C.DESC_H + G
    at(f.formHint)
    local blocker = CC().Blocker()
    if formWait then
        f.formHint:SetText(L["Wird im Spielkalender angelegt ..."])
    elseif formError then
        f.formHint:SetText(T.RED .. formError .. "|r")
    elseif blocker then
        f.formHint:SetText(T.RED .. CC().Why(blocker) .. "|r")
    else
        f.formHint:SetText(GREY .. L["Die ganze Gilde sieht den Termin im Spielkalender und kann sich anmelden."] .. "|r")
    end
    f.formAdd:SetEnabled(not formWait and blocker == nil)
end

local function fillRight(f, terms, raids)
    local V = ns.RaidCalView
    local day = chosen and terms[chosen]
    local recorded = chosen and raids[chosen]
    local at = chosenNoon()
    local t = termOf(terms)
    -- the form needs a day it can take; the Discord text a date
    if mode == "form" and not (dayOpen() or formWait) then mode = nil end
    if mode == "discord" and not t then mode = nil end
    f.dayTitle:SetText(at and (mode == "form" and L["Neuer Termin: %s"]:format(V.DayText(at)) or V.DayText(at)) or "")
    local inDay = mode == nil
    f.form:SetShown(mode == "form")
    if mode == "form" then fillForm(f) end
    f.discordBox:SetShown(mode == "discord")
    f.discordHint:SetShown(mode == "discord")
    f.discordClose:SetShown(mode == "discord")
    if mode == "discord" then
        local text = CC().DiscordText(t)
        if f.discordBox.box:GetText() ~= text then f.discordBox.box:SetText(text) end
        f.discordBox.box:HighlightText()
    end
    -- the dates of the day, else its recorded raids
    local rows = {}
    for i, e in ipairs(day or {}) do rows[#rows + 1] = { term = e, index = i } end
    if #rows == 0 then
        for _, s in ipairs(recorded or {}) do rows[#rows + 1] = { raid = s } end
    end
    for i, b in ipairs(f.terms) do
        local r = inDay and rows[i]
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
            fit(b.text, GREY .. L["Aufgezeichnet: %s"]:format(r.raid.zone or "?") .. "|r", C.RIGHT_W - 2 * C.INNER - C.DOT - 8)
            b.sel:Hide()
            b:Show()
        else
            b:Hide()
        end
    end
    local sign = t and not t.extra and t or nil
    local list, n, groups = {}, 0, {}
    if sign and inDay then
        local rows2, _, count, byGroup = ns.RaidCal.Rows(sign.night, sign)
        list, n, groups = rows2, count, byGroup
    end
    f.list:SetItems(list)
    f.list:SetShown(inDay)
    -- the totals of the chosen date: signed up and tentative (the bench when someone is on it)
    if sign and inDay then
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
    -- an event of the month read (no sign-up list here): its kind, type and creator
    local info
    if inDay and t and t.extra then
        local lines = {}
        local kind = t.kind == "PLAYER" and not t.creator and t.by and L["Einladung von %s"]:format(t.by)
            or CC().KIND_WORD[t.kind] and L[CC().KIND_WORD[t.kind]] or "?"
        lines[1] = ("%s%s:|r %s"):format(GREY, L["Art"], kind)
        if t.type and ns.Cal.TYPE_WORD[t.type] then lines[#lines + 1] = ("%s%s:|r %s"):format(GREY, L["Typ"], L[ns.Cal.TYPE_WORD[t.type]]) end
        if t.by and t.kind ~= "PLAYER" then lines[#lines + 1] = ("%s%s:|r %s"):format(GREY, L["Angelegt von"], t.by) end
        if t.kind == "GUILD_EVENT" then
            lines[#lines + 1] = GREY .. L["Anmelden in Amisia geht ab 14 Tage vorher, im Spielkalender jederzeit."] .. "|r"
        end
        info = table.concat(lines, "\n")
    end
    f.info:SetText(info or "")
    f.info:SetShown(info ~= nil)
    local empty
    if not inDay then
        empty = nil
    elseif not chosen then
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
    elseif sign and n == 0 then
        empty = L["Noch niemand angemeldet."]
    end
    f.empty:SetText(empty or "")
    f.empty:SetShown(empty ~= nil)
    -- the bottom row
    local rec = sign and ns.SignupOf()[sign.night]
    f.signup:SetText(rec and L["Ändern ..."] or L["Anmelden ..."])
    W.FitChip(f.signup, C.BUTTON_W)
    f.signup:SetShown(sign ~= nil and mode == nil)
    f.lineup:SetShown(sign ~= nil and mode == nil and ns.LineupAllowed ~= nil and ns.LineupAllowed() or false)
    f.discord:SetShown(t ~= nil and mode ~= "form")
    local open = dayOpen()
    f.create:SetShown(mode ~= "form" and IsInGuild() and CC().Available() and open and true or false)
    f.create:SetEnabled(CC().Refused() == nil)
    f.status:SetText(sign and inDay and reader.Status(sign) or "")
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
    askMonth()
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

ns.RegisterPanel{ key = "calendar", label = L["Kalender"], sub = L["Die Termine der Gilde und die aufgezeichneten Raids."], icon = "Interface\\Icons\\INV_Misc_Note_02", order = 66, group = "guild",
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
end)
