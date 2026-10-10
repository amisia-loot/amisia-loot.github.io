-- The raid calendar window (part I, D-43; logic in Raid/RaidCalendar.lua): "Raid-Kalender"
-- (AmisiaRaidCalendarFrame) for everyone in the guild. Left the guild's dates of the next 14 days
-- (date, time, title, the own state); right the chosen date's participants grouped "Angemeldet /
-- Bestätigt", "Vorläufig", "Ersatz", "Abgemeldet", "Ohne Antwort" (the count in each head), each row
-- the role (T/H/N/F, grey "?" when guessed), the name in its class colour, the level, the source
-- marks (K calendar, A Amisia) and the note (whole in the tooltip); over them the role summary of
-- those signed up. At the bottom the state of the calendar read, "Anmelden ..." / "Ändern ..." (the
-- sign-up window at that date) and, for officers, "Zur Aufstellung". Opened by the card's
-- "Kalender", the sign-up window's "Kalender" and /amisia kalender (en calendar). Draggable, the
-- place is kept (AmisiaDB.settings.calendarWindow), Escape closes it. While it is open the chosen
-- date is read again after a change in the calendar (at most every 5 s) and every 30 s.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local R = T.RAIDCAL
local PAD = T.WINDOW_PAD
local GREY, GREEN, ORANGE = T.GREY, T.GREEN, T.ORANGE
local YELLOW = "|cffffd100"
local RC = ns.RaidCal

local F            -- the window, built on first use
local cur          -- the night shown
local ticker       -- the poll while the window is open

local ROLE_SHORT = { T = L["T##Rolle"], H = L["H##Rolle"], M = L["N##Rolle"], R = L["F##Rolle"] }
local ROLE_NAME = { T = L["Tank"], H = L["Heiler"], M = L["Nahkampf"], R = L["Fernkampf"] }
local ROLE_COLOR = { T = "|cff8fb3ff", H = "|cff6fe08a", M = "|cffff9a5c", R = "|cffd9a8ff" }
local STATUS = {
    A = GREEN .. L["angemeldet"] .. "|r", B = GREEN .. L["bestätigt"] .. "|r", V = ORANGE .. L["vorläufig"] .. "|r",
    E = YELLOW .. L["Ersatz"] .. "|r", X = GREY .. L["abgemeldet"] .. "|r", I = GREY .. L["eingeladen"] .. "|r",
    O = GREY .. L["ohne Antwort"] .. "|r", G = GREY .. L["nicht mehr im Kalender"] .. "|r",
}
local SRC_COLOR = { K = "|cff8fb3ff", A = T.GOLD_TEXT }
local SRC_WORD = { K = L["K##Quelle"], A = L["A##Quelle"] }
local SRC_NAME = { K = L["Kalender"], A = L["Amisia"] }

local function roleText(e)
    if not e.r then return GREY .. "?|r" end
    if e.q then return GREY .. ROLE_SHORT[e.r] .. "?|r" end
    return ROLE_COLOR[e.r] .. ROLE_SHORT[e.r] .. "|r"
end

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
-- Reading the chosen date
---------------------------------------------------------------------------
local refresh
local lastRead, pending = 0, false

-- Reads the chosen date's event now (force) or when its last read is older than RELOAD_GAP; the
-- calendar busy with another reader (the lineup page, the probe): once more a moment later.
local function readNow(force)
    if not F or not F:IsShown() then return end
    local t = termNow()
    if not t or not t.id then return end
    local s = RC.State(t.night)
    if not force and s and s.read and s.id == t.id and time() - s.read < RC.RELOAD_GAP then return end
    lastRead = GetTime()
    RC.Read(t, function(_, why)
        if why == "busy" then
            C_Timer.After(RC.BUSY_RETRY, function() readNow(true) end)
        end
    end)
end

-- A change in the calendar while the window is open: read again, at most every RELOAD_GAP seconds.
local function onChange()
    if not F or not F:IsShown() or pending then return end
    pending = true
    C_Timer.After(math.max(0, RC.RELOAD_GAP - (GetTime() - lastRead)), function()
        pending = false
        readNow(true)
    end)
end
ns.Listen("CALENDAR_CHANGED", onChange)

local function choose(night)
    cur = night
    refresh()
    readNow(false)
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function buildDate(r)
    r.sel = W.SelectBar(r)
    r.when = W.Text(r, T.FONT.text, R.DATES_W - 2 * R.DATE_TEXT_X)
    r.when:SetPoint("TOPLEFT", R.DATE_TEXT_X, -3)
    r.own = W.Text(r, T.FONT.text, R.DATES_W / 2)
    r.own:SetJustifyH("RIGHT")
    r.own:SetPoint("TOPRIGHT", -R.DATE_TEXT_X, -3)
    r.title = W.Text(r, T.FONT.hint, R.DATES_W - 2 * R.DATE_TEXT_X)
    r.title:SetPoint("TOPLEFT", R.DATE_TEXT_X, -18)
    r:SetScript("OnClick", function(self) if self.item then choose(self.item.night) end end)
end

local function ownState(t)
    local rec = ns.SignupOf()[t.night]
    if rec then return (rec.s == "X" and GREY or rec.s == "V" and ORANGE or GREEN) .. ns.SignupStateText(rec) .. "|r" end
    return t.own and STATUS[t.own] or (GREY .. L["noch offen"] .. "|r")
end

-- "Do 10.09. 20:00"
local function whenText(at)
    local wd, hm = ns.Cal.When(at):match("^(%S+) (%S+)$")
    return wd and ("%s %s %s"):format(wd, ns.FmtDay(at), hm) or ns.FmtDayTime(at)
end

local function fillDate(r, t)
    r.when:SetText(whenText(t.at))
    r.own:SetText(ownState(t))
    r.title:SetText(t.raid and (T.GOLD_TEXT .. t.title .. "|r") or t.title)
    if t.night == cur then r.sel:Show() else r.sel:Hide() end
end

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

local function buildRow(r)
    r.cells = {}
    for _, col in ipairs(R.COLS) do
        local fs = W.Text(r, T.FONT.text, col[3])
        fs:SetPoint("LEFT", col[2], 0)
        r.cells[col[1]] = fs
    end
    r.head = W.Text(r, T.FONT.head, R.RIGHT_W - 8)
    r.head:SetPoint("LEFT", 4, 0)
    r:SetScript("OnEnter", function(self)
        if self.item and self.item.e then tooltip(self, self.item.e) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fillRow(r, item)
    if item.head then
        r.head:SetText(("%s (%d)"):format(item.head, item.count))
        r.head:Show()
        for _, fs in pairs(r.cells) do fs:SetText("") end
        return
    end
    local e = item.e
    r.head:SetText("")
    r.head:Hide()
    r.cells.r:SetText(roleText(e))
    r.cells.name:SetText(classColored(e.n, e.c))
    r.cells.level:SetText(e.lvl and tostring(e.lvl) or "")
    r.cells.src:SetText(sourceText(e))
    r.cells.note:SetText(e.w and (GREY .. e.w .. "|r") or "")
end

local function build()
    F = W.Window("AmisiaRaidCalendarFrame", R.W, R.H, { title = L["Raid-Kalender"], strata = "HIGH", onDragStop = savePlace,
        onShow = function(self)
            if self.Raise then self:Raise() end
            refresh()
        end,
        onVisibility = function(self)
            if ticker then ticker:Cancel() ticker = nil end
            if self:IsShown() then ticker = C_Timer.NewTicker(RC.POLL, function() readNow(true) end) end
        end })
    F.dates = W.List(F, R.DATE_ROWS, R.DATE_ROW_H, buildDate, fillDate)
    F.dates:SetWidth(R.DATES_W)
    F.dates:SetPoint("TOPLEFT", PAD, -R.TOP)
    F.head = W.Text(F, T.FONT.title, R.RIGHT_W)
    F.head:SetHeight(R.HEAD_H)
    F.head:SetPoint("TOPLEFT", R.RIGHT_X, -R.TOP)
    F.sum = W.Text(F, T.FONT.hint, R.RIGHT_W)
    F.sum:SetPoint("TOPLEFT", R.RIGHT_X, -R.SUM_Y)
    F.list = W.List(F, R.ROWS, R.ROW_H, buildRow, fillRow)
    F.list:SetWidth(R.RIGHT_W)
    F.list:SetPoint("TOPLEFT", R.RIGHT_X, -R.LIST_Y)
    F.empty = W.Text(F, T.FONT.dim, R.RIGHT_W - 40, true)
    F.empty:SetJustifyH("CENTER")
    F.empty:SetPoint("TOP", F.list, "TOP", 0, -40)
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

-- "Kalender gelesen 19:42", the reason of a failed read, or that it is being read.
local function statusText(t)
    if not t then return "" end
    if not ns.Cal.CanReadInvites() then return L["Nur Anmeldungen aus Amisia (Teilnehmerliste des Kalenders nicht lesbar)."] end
    local s = RC.State(t.night)
    if s and s.why == "window" then return L["Kalenderfenster des Spiels schließen, dann liest Amisia die Liste."] end
    if s and s.why and s.why ~= "busy" then return ns.Cal.Why(s.why) end
    if s and s.read then return L["Kalender gelesen %s"]:format(date("%H:%M", s.read)) end
    return L["Kalender wird gelesen ..."]
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
    local rows, roles, n = {}, { T = 0, H = 0, M = 0, R = 0 }, 0
    if t then rows, roles, n = RC.Rows(t.night) end
    F.list:SetItems(rows)
    if t then
        F.head:SetText(("%s · %s"):format(whenText(t.at), t.title or "?"))
        F.sum:SetText(L["Tanks %d · Heiler %d · Nahkampf %d · Fernkampf %d"]:format(roles.T, roles.H, roles.M, roles.R))
    else
        F.head:SetText("")
        F.sum:SetText("")
    end
    local empty
    if not IsInGuild() then
        empty = L["Nur in einer Gilde"]
    elseif not ns.Cal.Available() then
        empty = L["Kalender nicht verfügbar."]
    elseif not terms then
        empty = L["Termine werden gelesen ..."]
    elseif #terms == 0 then
        empty = L["Keine Raidtermine in den nächsten 14 Tagen."]
    elseif n == 0 then
        empty = L["Noch niemand angemeldet."]
    end
    F.empty:SetText(empty or "")
    F.empty:SetShown(empty ~= nil)
    F.status:SetText(statusText(t))
    local rec = t and ns.SignupOf()[t.night]
    F.signup:SetText(rec and L["Ändern ..."] or L["Anmelden ..."])
    W.FitChip(F.signup, R.BUTTON_W)
    F.signup:SetEnabled(t ~= nil)
    bottomRow(t ~= nil and ns.LineupAllowed ~= nil and ns.LineupAllowed() or false)
end

-- Opens the window at night (default: the next date); the dates are read first when they are not.
function ns.ShowRaidCalendar(night)
    if not F then build() end
    if night then cur = night end
    if F:IsShown() then refresh() else F:Show() end
    if not ns.SignupTerms() then
        ns.SignupLoadTerms(function()
            refresh()
            readNow(false)
        end)
    else
        readNow(false)
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

-- for the tests
ns._raidCalUI = { frame = function() return F end }
