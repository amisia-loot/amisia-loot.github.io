-- The raid calendar window (part I, D-43; logic in Raid/RaidCalendar.lua): "Raid-Kalender"
-- (AmisiaRaidCalendarFrame) for everyone in the guild, in the profession window's look (2.25.1).
-- Left, in an inset with the recipe list's ground, the guild's dates of the next 14 days: the day
-- large, the time, the title and the own state as a coloured badge; the chosen date has the recipe
-- list's selection glow. Right, in an inset, the chosen date: its head (the event's icon, the title
-- large and gold, the date line, a badge per role with the group finder's role icon counting those
-- signed up, the totals per status), the column heads (Rolle, Name, Stufe, Quelle, Notiz) and the
-- participants under a section bar per group ("Angemeldet / Bestätigt", "Vorläufig", "Ersatz",
-- "Abgemeldet", "Ohne Antwort", the count in each), each row the role icon (desaturated and "?" when
-- guessed), the class icon, the name in its class colour, the level, the source marks (K calendar,
-- A Amisia) and the note (cut; whole in the tooltip). At the bottom the state of the calendar read
-- ("Kalender gelesen 21:37" or why not), "Anmelden ..." / "Ändern ..." (the sign-up window at that
-- date) and, for officers, "Zur Aufstellung". Opened by the card's "Kalender", the sign-up window's
-- "Kalender" and /amisia kalender (en calendar). It stands in the main window's strata (FULLSCREEN,
-- over the world map like it) and comes to the front when shown or clicked (D-43). Draggable, the
-- place is kept (AmisiaDB.settings.calendarWindow), Escape closes it. While it is open the chosen
-- date is read again after a change in the calendar (at most every 5 s) and every 30 s. Nothing
-- here writes into the calendar.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local R = T.RAIDCAL
local PAD = T.WINDOW_PAD
local GREY, GREEN, ORANGE, RED = T.GREY, T.GREEN, T.ORANGE, T.RED
local YELLOW = "|cffffd100"
local WHITE = "|cffffffff"
local RC = ns.RaidCal

local F            -- the window, built on first use
local cur          -- the night shown
local ticker       -- the poll while the window is open

local ROLES = { "T", "H", "M", "R" }
local ROLE_SHORT = { T = L["T##Rolle"], H = L["H##Rolle"], M = L["N##Rolle"], R = L["F##Rolle"] }
local ROLE_NAME = { T = L["Tank"], H = L["Heiler"], M = L["Nahkampf"], R = L["Fernkampf"] }
local ROLE_COLOR = { T = "|cff8fb3ff", H = "|cff6fe08a", M = "|cffff9a5c", R = "|cffd9a8ff" }
-- the group finder's role icons (melee and ranged share the damage icon; the letter tells them apart)
local ROLE_ATLAS = { T = "groupfinder-icon-role-large-tank", H = "groupfinder-icon-role-large-heal",
                     M = "groupfinder-icon-role-large-dps", R = "groupfinder-icon-role-large-dps" }
-- a status (Lineup's codes) in words, and coloured
local WORD = { A = L["angemeldet"], B = L["bestätigt"], V = L["vorläufig"], E = L["Ersatz"], X = L["abgemeldet"],
               I = L["eingeladen"], O = L["ohne Antwort"], G = L["nicht mehr im Kalender"] }
local CODE_TEXT = { A = GREEN, B = GREEN, V = ORANGE, E = YELLOW, X = RED, I = GREY, O = GREY, G = GREY }
local STATUS = {}
for code, word in pairs(WORD) do STATUS[code] = CODE_TEXT[code] .. word .. "|r" end
-- the colour of a status (the own state's badge) and of a group (its section bar and total)
local RGB = { green = { 0.31, 0.75, 0.48 }, orange = { 0.88, 0.64, 0.27 }, yellow = { 1, 0.82, 0 },
              red = { 0.88, 0.34, 0.29 }, grey = { 0.56, 0.53, 0.64 } }
local CODE_COLOR = { A = "green", B = "green", V = "orange", E = "yellow", X = "red", I = "grey", O = "grey", G = "grey" }
local GROUP_COLOR = { ["in"] = GREEN, maybe = ORANGE, bench = YELLOW, out = RED, none = GREY }
local GROUP_WORD = { ["in"] = L["angemeldet"], maybe = L["vorläufig"], bench = L["Ersatz"], out = L["abgemeldet"], none = L["ohne Antwort"] }
local SRC_COLOR = { K = "|cff8fb3ff", A = T.GOLD_TEXT }
local SRC_WORD = { K = L["K##Quelle"], A = L["A##Quelle"] }
local SRC_NAME = { K = L["Kalender"], A = L["Amisia"] }
-- the event type's picture, as the client's calendar shows it (Blizzard_Calendar's
-- CALENDAR_EVENTTYPE_TEXTURES) when the event carries no picture of its own
local TYPE_TEXTURE = { [0] = "Interface\\LFGFrame\\LFGIcon-Raid", [1] = "Interface\\LFGFrame\\LFGIcon-Dungeon",
                       [2] = "Interface\\Calendar\\UI-Calendar-Event-PVP", [3] = "Interface\\Calendar\\MeetingIcon",
                       [4] = "Interface\\Calendar\\UI-Calendar-Event-Other" }

local function classColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local function sourceText(e)
    local out = {}
    for _, x in ipairs({ "K", "A" }) do
        if e.f and e.f:find(x, 1, true) then out[#out + 1] = SRC_COLOR[x] .. SRC_WORD[x] .. "|r" end
    end
    return table.concat(out, " ")
end

-- A role in a row: the icon (desaturated and faint when guessed) and the letter ("?" when guessed).
local function setRole(icon, fs, role, guessed)
    local atlas = role and ROLE_ATLAS[role]
    if atlas and W.HasAtlas(atlas) then
        icon:SetAtlas(atlas)
        icon:SetDesaturated(guessed and true or false)
        icon:SetAlpha(guessed and 0.55 or 1)
        icon:Show()
    else
        icon:Hide()
    end
    icon.guessed = guessed and true or false
    if not role then
        fs:SetText(GREY .. "?|r")
    elseif guessed then
        fs:SetText(GREY .. ROLE_SHORT[role] .. "?|r")
    else
        fs:SetText(ROLE_COLOR[role] .. ROLE_SHORT[role] .. "|r")
    end
end

local function setClassIcon(icon, class)
    local atlas = type(class) == "string" and ("groupfinder-icon-class-" .. class:lower()) or nil
    if atlas and W.HasAtlas(atlas) then
        icon:SetAtlas(atlas)
        icon:Show()
    else
        icon:Hide()
    end
end

local function termNow()
    for _, t in ipairs(ns.SignupTerms() or {}) do
        if t.night == cur then return t end
    end
    return nil
end

---------------------------------------------------------------------------
-- The place (AmisiaDB.settings.calendarWindow)
---------------------------------------------------------------------------
local function windowState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.calendarWindow) ~= "table" then AmisiaDB.settings.calendarWindow = {} end
    return AmisiaDB.settings.calendarWindow
end

local function place()
    if not F then return end
    F:ClearAllPoints()
    local st = windowState()
    if st and type(st.point) == "string" and tonumber(st.x) and tonumber(st.y) then
        F:SetPoint(st.point, UIParent, st.point, tonumber(st.x), tonumber(st.y))
    else
        F:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

local function savePlace(f)
    local st = windowState()
    if not st then return end
    local point, _, _, x, y = f:GetPoint(1)
    if type(point) == "string" and tonumber(x) and tonumber(y) then
        st.point, st.x, st.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

function ns.ResetRaidCalendarPosition()
    local st = windowState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

---------------------------------------------------------------------------
-- Reading the chosen date (the window and the calendar page each have a reader)
---------------------------------------------------------------------------
-- A reader of the chosen date: opts.shown() whether its view is shown, opts.term() the chosen date
-- (an entry of ns.SignupTerms()) or nil, opts.refresh() draws the view again. reader.Read(force)
-- reads the chosen date's event now (force) or when its last read is older than RELOAD_GAP; the
-- calendar busy with another reader (the lineup page, the probe, a sign-up's calendar entry): once
-- more a moment later. A date without an event id is read too (Cal.Read finds it by its time and
-- title; until 2.25.1 it was never read and the line said "Kalender wird gelesen ..." for good).
-- reader.OnChange() reads again after a change in the calendar, at most every RELOAD_GAP seconds;
-- reader.Status(t) is the line about the read; reader.Reset() forgets a busy calendar (a new date).
local function Reader(opts)
    local rd = {}
    local lastRead, pending = 0, false
    local reading            -- { night, at }: a read of this view runs (its answer not yet back)
    local busySince          -- { night, at }: the calendar answered "busy" since then, without a break

    function rd.Read(force)
        if not opts.shown() then return end
        local t = opts.term()
        if not t then return end
        local s = RC.State(t.night, t)
        if not force and s and s.read and s.id == t.id and time() - s.read < RC.RELOAD_GAP then return end
        lastRead = GetTime()
        local night = t.night
        reading = { night = night, at = GetTime() }
        RC.Read(t, function(_, why)
            reading = nil
            if why == "busy" then
                if not (busySince and busySince.night == night) then busySince = { night = night, at = GetTime() } end
                C_Timer.After(RC.BUSY_RETRY, function() rd.Read(true) end)
            else
                busySince = nil
            end
            opts.refresh()
        end)
        -- the answer comes later: the line says that the read runs
        if reading then opts.refresh() end
    end

    function rd.OnChange()
        if not opts.shown() or pending then return end
        pending = true
        C_Timer.After(math.max(0, RC.RELOAD_GAP - (GetTime() - lastRead)), function()
            pending = false
            rd.Read(true)
        end)
    end

    function rd.Reset() busySince = nil end

    -- "Kalender gelesen 19:42", the reason of a failed read, or that it is being read. A calendar busy
    -- with another reader for longer than RC.BUSY_SHOW seconds says so (the read is tried again).
    function rd.Status(t)
        if not t then return "" end
        if not ns.Cal.CanReadInvites() then return L["Nur Anmeldungen aus Amisia (Teilnehmerliste des Kalenders nicht lesbar)."] end
        local s = RC.State(t.night, t)
        if s and s.why == "window" then return L["Kalenderfenster des Spiels schließen, dann liest Amisia die Liste."] end
        if s and s.why and s.why ~= "busy" then return ns.Cal.Why(s.why) end
        if s and s.read then return L["Kalender gelesen %s"]:format(date("%H:%M", s.read)) end
        if busySince and busySince.night == t.night and GetTime() - busySince.at >= RC.BUSY_SHOW then
            return L["Kalender belegt (Aufstellung, Anmeldung oder Prüfung liest), Amisia versucht es weiter ..."]
        end
        if (reading and reading.night == t.night) or (busySince and busySince.night == t.night) then
            return L["Kalender wird gelesen ..."]
        end
        return L["Kalender noch nicht gelesen."]
    end

    ns.Listen("CALENDAR_CHANGED", function() rd.OnChange() end)
    return rd
end

local refresh
local reader = Reader({ shown = function() return F ~= nil and F:IsShown() end, term = termNow,
    refresh = function() refresh() end })

local function choose(night)
    cur = night
    reader.Reset()
    refresh()
    reader.Read(false)
end

---------------------------------------------------------------------------
-- The dates (left)
---------------------------------------------------------------------------
-- A small badge: the text in a colour on a faint ground of the same colour.
local function badge(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(R.BADGE_H)
    b.ground = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.ground:SetAllPoints()
    b.text = W.Text(b, T.FONT.text)
    b.text:SetPoint("CENTER", 0, 0)
    function b:Set(text, color, maxW)
        local c = RGB[color] or RGB.grey
        self.ground:SetColorTexture(c[1], c[2], c[3], R.BADGE_ALPHA)
        self.text:SetText(text)
        self.text:SetTextColor(c[1], c[2], c[3])
        local w = math.min(maxW, (self.text:GetStringWidth() or 0) + 2 * R.BADGE_PAD)
        self.text:SetWidth(w - 2 * R.BADGE_PAD)
        self:SetWidth(w)
        self:Show()
    end
    return b
end

local DATE_LIST_W = R.DATES_W - 2 * R.INNER - T.SCROLL_ROOM
local DATE_TEXT_W = DATE_LIST_W - 2 * R.DATE_X

local function buildDate(r)
    r.sel = W.SelectBar(r)
    r.day = W.Text(r, T.FONT.title)
    r.day:SetPoint("TOPLEFT", R.DATE_X, -R.DAY_Y)
    r.time = W.Text(r, T.FONT.body)
    r.time:SetPoint("LEFT", r.day, "RIGHT", R.TIME_GAP, 0)
    r.own = badge(r)
    r.own:SetPoint("TOPRIGHT", -R.DATE_X, -(R.DAY_Y - 1))
    r.title = W.Text(r, T.FONT.text, DATE_TEXT_W)
    r.title:SetPoint("TOPLEFT", R.DATE_X, -R.TITLE_Y)
    r:SetScript("OnClick", function(self) if self.item then choose(self.item.night) end end)
end

-- The own state: the sign-up from Amisia, else the calendar's status, else "noch offen".
local function ownState(t)
    local rec = ns.SignupOf()[t.night]
    if rec then return ns.SignupStateText(rec), rec.s == "X" and "red" or rec.s == "V" and "orange" or "green" end
    if t.own and WORD[t.own] then return WORD[t.own], CODE_COLOR[t.own] or "grey" end
    return L["noch offen"], "grey"
end

-- "Do 10.09." and "20:00"
local function dayText(at)
    local wd = ns.Cal.When(at):match("^(%S+) ")
    return wd and ("%s %s"):format(wd, ns.FmtDay(at)) or ns.FmtDay(at)
end

local function fillDate(r, t)
    r.day:SetText(dayText(t.at))
    r.time:SetText(date("%H:%M", t.at))
    local text, color = ownState(t)
    -- the badge leaves the day and the time their room
    local used = (r.day:GetStringWidth() or 0) + R.TIME_GAP + (r.time:GetStringWidth() or 0) + T.LAYOUT.ITEM_GAP
    r.own:Set(text, color, math.max(40, DATE_TEXT_W - used))
    r.title:SetText(t.raid and (WHITE .. t.title .. "|r") or (GREY .. t.title .. "|r"))
    if t.night == cur then r.sel:Show() else r.sel:Hide() end
end

---------------------------------------------------------------------------
-- The participants (right)
---------------------------------------------------------------------------
local function tooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(classColored(e.n, e.c), 1, 0.82, 0)
    local bits = { STATUS[e.st or "O"] or "" }
    if e.r then bits[#bits + 1] = ROLE_NAME[e.r] .. (e.q and L[" (geraten)"] or "") end
    if e.lvl then bits[#bits + 1] = L["Stufe %d##Charakter"]:format(e.lvl) end
    GameTooltip:AddLine(table.concat(bits, " · "), 0.85, 0.85, 0.85)
    local src = {}
    for _, x in ipairs({ "K", "A" }) do
        if e.f and e.f:find(x, 1, true) then src[#src + 1] = SRC_NAME[x] end
    end
    GameTooltip:AddLine(L["Quellen: %s"]:format(table.concat(src, ", ")), 0.85, 0.85, 0.85)
    if e.w then GameTooltip:AddLine(L["Notiz: %s"]:format(e.w), 1, 1, 1, true) end
    GameTooltip:Show()
end

local COL = {}
for _, c in ipairs(R.COLS) do COL[c[1]] = c end

-- A participant row (the window's list and the calendar page's): spec = { COLS, CELL_ICON,
-- ROLE_LETTER_X } of the theme (T.RAIDCAL or T.CALPAGE); the columns r and class are needed, level,
-- src and note are shown when the spec has them.
local function buildRow(r, spec)
    spec = spec or R
    local col = {}
    for _, c in ipairs(spec.COLS) do col[c[1]] = c end
    r.cells = {}
    for _, c in ipairs(spec.COLS) do
        if c[1] ~= "class" then
            local fs = W.Text(r, T.FONT.text, c[3])
            fs:SetPoint("LEFT", c[2], 0)
            if c[4] then fs:SetJustifyH(c[4]) end
            r.cells[c[1]] = fs
        end
    end
    -- the role: the icon, the letter after it
    r.roleIcon = r:CreateTexture(nil, "ARTWORK")
    r.roleIcon:SetSize(spec.CELL_ICON, spec.CELL_ICON)
    r.roleIcon:SetPoint("LEFT", col.r[2], 0)
    r.cells.r:ClearAllPoints()
    r.cells.r:SetPoint("LEFT", col.r[2] + spec.ROLE_LETTER_X, 0)
    r.cells.r:SetWidth(col.r[3] - spec.ROLE_LETTER_X)
    r.classIcon = r:CreateTexture(nil, "ARTWORK")
    r.classIcon:SetSize(spec.CELL_ICON, spec.CELL_ICON)
    r.classIcon:SetPoint("LEFT", col.class[2], 0)
    -- a group's section bar fills the row
    r.bar = W.SectionHeader(r, "", false)
    r.bar:SetPoint("TOPLEFT", 0, 0)
    r.bar:SetPoint("BOTTOMRIGHT", 0, 0)
    r.bar:Hide()
    r:SetScript("OnEnter", function(self)
        if self.item and self.item.e then tooltip(self, self.item.e) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fillRow(r, item)
    if item.head then
        r.bar:SetHeaderText(("%s%s|r  %s%d|r"):format(GROUP_COLOR[item.key] or YELLOW, item.head, WHITE, item.count))
        r.bar:Show()
        r.bg:Hide()
        for _, fs in pairs(r.cells) do fs:SetText("") end
        r.roleIcon:Hide()
        r.classIcon:Hide()
        return
    end
    local e = item.e
    r.bar:Hide()
    r.bg:Show()
    setRole(r.roleIcon, r.cells.r, e.r, e.q)
    setClassIcon(r.classIcon, e.c)
    r.cells.name:SetText(classColored(e.n, e.c))
    if r.cells.level then r.cells.level:SetText(e.lvl and tostring(e.lvl) or "") end
    if r.cells.src then r.cells.src:SetText(sourceText(e)) end
    if r.cells.note then r.cells.note:SetText(e.w and (GREY .. e.w .. "|r") or "") end
end

-- A role badge of the head: the role icon, the word and the count of those signed up.
local function roleBadge(parent, role)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(R.ROLE_ICON)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(R.ROLE_ICON, R.ROLE_ICON)
    b.icon:SetPoint("LEFT", 0, 0)
    if W.HasAtlas(ROLE_ATLAS[role]) then b.icon:SetAtlas(ROLE_ATLAS[role]) else b.icon:Hide() end
    b.text = W.Text(b, T.FONT.text)
    b.text:SetPoint("LEFT", R.ROLE_ICON + R.ROLE_TEXT_GAP, 0)
    b.role = role
    function b:Set(n)
        self.count = n
        self.text:SetText(("%s%s|r %s%d|r"):format(ROLE_COLOR[role], ROLE_NAME[role], n > 0 and WHITE or GREY, n))
        self.text:SetWidth((self.text:GetStringWidth() or 0) + 1)
        self:SetWidth(R.ROLE_ICON + R.ROLE_TEXT_GAP + self.text:GetWidth())
    end
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(ROLE_NAME[role], 1, 0.82, 0)
        GameTooltip:AddLine(self.names and #self.names > 0 and table.concat(self.names, ", ") or L["Noch niemand angemeldet."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local RIGHT_INNER = R.RIGHT_W - R.TITLE_X - R.PAD

local function build()
    F = W.Window("AmisiaRaidCalendarFrame", R.W, R.H, { title = L["Raid-Kalender"], strata = "FULLSCREEN", onDragStop = savePlace,
        onShow = function(self)
            if self.Raise then self:Raise() end
            refresh()
        end,
        onVisibility = function(self)
            if ticker then ticker:Cancel() ticker = nil end
            if self:IsShown() then ticker = C_Timer.NewTicker(RC.POLL, function() reader.Read(true) end) end
        end })
    -- a click anywhere on it brings it to the front (the client raises a top-level frame on a click;
    -- this does it for frames that take the click themselves too)
    F:HookScript("OnMouseDown", function(self) if self.Raise then self:Raise() end end)

    -- left: the dates in an inset with the recipe list's ground
    F.datesInset = W.Inset(F)
    F.datesInset:SetPoint("TOPLEFT", PAD, -R.TOP)
    F.datesInset:SetPoint("BOTTOMLEFT", PAD, R.INSET_BOTTOM)
    F.datesInset:SetWidth(R.DATES_W)
    F.datesInset.fill("Professions-background-summarylist")
    F.dates = W.List(F.datesInset, R.DATE_ROWS, R.DATE_ROW_H, buildDate, fillDate)
    F.dates:SetWidth(DATE_LIST_W)
    F.dates:SetPoint("TOPLEFT", R.INNER, -R.INNER)
    F.datesEmpty = W.Text(F.datesInset, T.FONT.dim, R.DATES_W - 4 * R.INNER, true)
    F.datesEmpty:SetJustifyH("CENTER")
    F.datesEmpty:SetPoint("TOP", F.datesInset, "TOP", 0, -R.EMPTY_Y)

    -- right: the chosen date in an inset
    local P = W.Inset(F)
    F.right = P
    P:SetPoint("TOPLEFT", R.RIGHT_X, -R.TOP)
    P:SetPoint("BOTTOMLEFT", R.RIGHT_X, R.INSET_BOTTOM)
    P:SetWidth(R.RIGHT_W)
    P.fill(0, 0, 0, 0.25)
    F.icon = P:CreateTexture(nil, "ARTWORK")
    F.icon:SetSize(R.ICON, R.ICON)
    F.icon:SetPoint("TOPLEFT", R.PAD, -R.HEAD_Y)
    F.head = W.Text(P, T.FONT.big, RIGHT_INNER)
    F.head:SetPoint("TOPLEFT", R.TITLE_X, -R.HEAD_Y)
    F.when = W.Text(P, T.FONT.text, RIGHT_INNER)
    F.when:SetPoint("TOPLEFT", R.TITLE_X, -R.WHEN_Y)
    F.roles = {}
    for _, role in ipairs(ROLES) do F.roles[role] = roleBadge(P, role) end
    F.totals = W.Text(P, T.FONT.text, R.RIGHT_W - 2 * R.PAD)
    F.totals:SetPoint("TOPLEFT", R.PAD, -R.TOTALS_Y)
    -- the column heads over the list
    F.cols = CreateFrame("Frame", nil, P)
    F.cols:SetHeight(T.LAYOUT.COLHEAD_H)
    F.cols:SetWidth(R.LIST_W)
    F.cols:SetPoint("TOPLEFT", R.PAD, -R.COLHEAD_Y)
    local HEADS = { r = L["Rolle"], name = L["Name"], level = L["Stufe"], src = L["Quelle"], note = L["Notiz"] }
    F.colHeads = {}
    for _, c in ipairs(R.COLS) do
        local label = HEADS[c[1]]
        if label then
            -- the name's head stands over the class icon too
            local x = c[1] == "name" and COL.class[2] or c[2]
            local w = c[1] == "name" and (c[2] + c[3] - COL.class[2]) or c[3]
            local fs = W.Text(F.cols, T.FONT.head, w)
            fs:SetPoint("LEFT", x, 0)
            if c[4] then fs:SetJustifyH(c[4]) end
            fs:SetText(label)
            F.colHeads[c[1]] = fs
        end
    end
    F.list = W.List(P, R.ROWS, R.ROW_H, function(r) buildRow(r, R) end, fillRow)
    F.list:SetWidth(R.LIST_W)
    F.list:SetPoint("TOPLEFT", R.PAD, -R.LIST_Y)
    F.empty = W.Text(P, T.FONT.dim, R.LIST_W - 40, true)
    F.empty:SetJustifyH("CENTER")
    F.empty:SetPoint("TOP", F.list, "TOP", 0, -R.EMPTY_Y)

    -- the bottom: the read's state left, the red buttons right
    F.signup = W.Button(F, L["Anmelden ..."], R.BUTTON_W, function()
        if cur then ns.ShowSignup(cur) end
    end)
    F.lineup = W.Button(F, L["Zur Aufstellung"], R.BUTTON_W, function()
        if cur and ns.ShowLineup then ns.ShowLineup("match", cur) end
    end)
    W.FitChip(F.lineup, R.BUTTON_W)
    W.Tooltip(F.lineup, L["Zur Aufstellung"], L["Öffnet die Seite Aufstellung mit der Nacht dieses Termins (nur Offiziere)."])
    F.status = W.Text(F, T.FONT.hint, 200)
    F.status:SetHeight(T.BUTTON_H)
    F.status:SetJustifyV("MIDDLE")
    F.status:SetPoint("BOTTOMLEFT", PAD, R.BOTTOM)
    place()
end

-- The bottom row: the status left, the buttons right (Zur Aufstellung only for officers).
local function bottomRow(officer)
    F.signup:Show()
    F.lineup:SetShown(officer)
    local items = officer and { F.lineup, F.signup } or { F.signup }
    local used = W.Row(F, items, T.LAYOUT.ITEM_GAP, PAD, R.BOTTOM, { point = "BOTTOMRIGHT", right = true })
    F.status:SetWidth(math.max(40, R.W - PAD - used - T.LAYOUT.ITEM_GAP - PAD))
end

-- The head of the chosen date: icon, title, date line, role badges, totals.
local function fillHead(t, roles, groups, names)
    local shown = t ~= nil
    F.icon:SetShown(shown)
    for _, role in ipairs(ROLES) do F.roles[role]:SetShown(shown) end
    if not t then
        F.head:SetText("")
        F.when:SetText("")
        F.totals:SetText("")
        return
    end
    F.icon:SetTexture(t.tex or TYPE_TEXTURE[t.type or 4] or TYPE_TEXTURE[4])
    F.head:SetText(t.title or "?")
    local typeWord = t.type and ns.Cal.TYPE_WORD[t.type]
    F.when:SetText(("%s · %s%s"):format(dayText(t.at), date("%H:%M", t.at), typeWord and (" · " .. GREY .. L[typeWord] .. "|r") or ""))
    local items = {}
    for _, role in ipairs(ROLES) do
        local b = F.roles[role]
        b:Set(roles[role] or 0)
        b.names = names[role]
        items[#items + 1] = b
    end
    W.Row(F.right, items, R.ROLE_GAP, R.PAD, -R.ROLES_Y)
    local parts = {}
    for _, g in ipairs(RC.GROUPS) do
        local n = groups[g.key] or 0
        -- the bench only when someone is on it
        if g.key ~= "bench" or n > 0 then
            parts[#parts + 1] = ("%s%s|r %s%d|r"):format(GROUP_COLOR[g.key], GROUP_WORD[g.key], WHITE, n)
        end
    end
    F.totals:SetText(table.concat(parts, GREY .. "  ·  |r"))
end

refresh = function()
    if not F or not F:IsShown() then return end
    local terms = ns.SignupTerms()
    if terms and not termNow() then
        local t = ns.SignupNextTerm()
        cur = t and t.night or nil
    end
    F.dates:SetItems(terms or {})
    local t = termNow()
    local rows, roles, n, groups = {}, { T = 0, H = 0, M = 0, R = 0 }, 0, {}
    if t then rows, roles, n, groups = RC.Rows(t.night, t) end
    F.list:SetItems(rows)
    -- the names per role of those signed up (the badges' tooltips)
    local names = { T = {}, H = {}, M = {}, R = {} }
    for _, it in ipairs(rows) do
        if it.e and it.key == "in" and it.e.r then table.insert(names[it.e.r], it.e.n) end
    end
    fillHead(t, roles, groups or {}, names)
    local empty, datesEmpty
    if not IsInGuild() then
        empty = L["Nur in einer Gilde"]
    elseif not ns.Cal.Available() then
        empty = L["Kalender nicht verfügbar."]
    elseif not terms then
        datesEmpty = L["Termine werden gelesen ..."]
    elseif #terms == 0 then
        datesEmpty = L["Keine Raidtermine in den nächsten 14 Tagen."]
    elseif n == 0 then
        empty = L["Noch niemand angemeldet."]
    end
    F.empty:SetText(empty or "")
    F.empty:SetShown(empty ~= nil)
    F.datesEmpty:SetText(datesEmpty or "")
    F.datesEmpty:SetShown(datesEmpty ~= nil)
    F.cols:SetShown(t ~= nil and n > 0)
    F.status:SetText(reader.Status(t))
    local rec = t and ns.SignupOf()[t.night]
    F.signup:SetText(rec and L["Ändern ..."] or L["Anmelden ..."])
    W.FitChip(F.signup, R.BUTTON_W)
    F.signup:SetEnabled(t ~= nil)
    bottomRow(t ~= nil and ns.LineupAllowed ~= nil and ns.LineupAllowed() or false)
end

-- Opens the window at night (default: the next date) in front of the other windows; the dates are
-- read first when they are not.
function ns.ShowRaidCalendar(night)
    if not F then build() end
    if night and night ~= cur then
        cur = night
        reader.Reset()
    end
    if F:IsShown() then
        if F.Raise then F:Raise() end
        refresh()
    else
        F:Show()
    end
    if not ns.SignupTerms() then
        ns.SignupLoadTerms(function()
            refresh()
            reader.Read(false)
        end)
    else
        reader.Read(false)
    end
    return F
end

for _, msg in ipairs({ "RAIDCAL", "SIGNUP", "SIGNUP_SEEN" }) do ns.Listen(msg, function() refresh() end) end

ns.RegisterSlash("kalender", { en = "calendar", desc = L["Raid-Kalender: die Termine der Gilde und wer kommt"], run = function()
    if not IsInGuild() then
        ns.msg(L["Nur in einer Gilde."])
        return
    end
    ns.ShowRaidCalendar()
end })

-- What the calendar page (UI/Pages/Calendar.lua) shares with this window: the reader of a chosen
-- date, the participant row, the own state of a date and its day text, the role icons.
ns.RaidCalView = { Reader = Reader, BuildRow = buildRow, FillRow = fillRow, Tooltip = tooltip, OwnState = ownState,
    DayText = dayText, RGB = RGB, CODE_COLOR = CODE_COLOR, GROUP_COLOR = GROUP_COLOR, GROUP_WORD = GROUP_WORD,
    TYPE_TEXTURE = TYPE_TEXTURE }

-- for the tests
ns._raidCalUI = { frame = function() return F end }
