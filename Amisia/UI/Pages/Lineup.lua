-- Aufstellung (officers only, D-41): the sign-up list of a raid night in two views, the match
-- against the guild ("Abgleich": found, likely, ambiguous, unknown, guest, with one click to fix)
-- and the planner ("Planer": the groups of the raid size, not placed, bench; click a name, then
-- another or a free place to swap or move, or drag; right click for role, bench, hold, remove), the
-- paste field and the calendar view ("Kalender": the guild events of the next 14 days, the next of
-- the raid type chosen, "Übernehmen" reads its invite list into the event's night, D-42). Each row
-- carries the marks of its sources (L list, K calendar, A Amisia) and the valid status; while the
-- page is open a change in the calendar reads the night's event again (at most every 5 s). The
-- logic lives in Raid/Lineup.lua and Raid/Calendar.lua; this page only shows it.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local GREY, ORANGE, RED, GREEN = T.GREY, T.ORANGE, T.RED, T.GREEN
local YELLOW = "|cffffd100"

-- the planner: four group boxes across, two rows; slots of 17 under an 18 px head
local GROUP_W, GROUP_GAP, HEAD_H, SLOT_H = 146, 6, 18, 17
local GROUP_H = HEAD_H + 5 * SLOT_H + 1
local SLOT_INSET = 3
-- the two lists under the groups: not placed (left) and bench (right)
local LIST_ROWS, LIST_ROW_H = 6, 18
local LEFT_W, RIGHT_X, RIGHT_W = 285, 303, 287
local SIDE_COLS = { { "r", 4, 18 }, { "name", 24, 170 }, { "info", 198, 84 } }
-- the match view: rows of 22 from the column heads to the footer (15)
local MATCH_ROWS, MATCH_ROW_H = 15, 22
local MATCH_COLS = { { "r", 6, 26 }, { "src", 34, 30 }, { "name", 66, 148 }, { "state", 216, 100 }, { "level", 318, 30 },
                     { "online", 352, 48 }, { "act", 402, 188 } }
local ACT_X, MAX_CHIPS, CHIP_MAX_W = 402, 3, 90
-- the calendar view: one row per guild event
local CAL_ROWS, CAL_ROW_H = 15, 22
local CAL_COLS = { { "when", 6, 120 }, { "title", 130, 230 }, { "kind", 364, 90 }, { "own", 458, 130 } }
local RELOAD_GAP = 5       -- the calendar is read again at most this often while the page is open
local POLL = 30            -- and every this many seconds (the client does not tell every change)

local page
local view = "match"      -- "match", "planner", "paste" or "calendar"
local night               -- the night shown (nil: tonight)
local selected            -- the index of the entry a click chose (swap and move)
local calList             -- the guild events of the calendar view (ns.Cal.Events()), nil while read
local calPick             -- the id (else the index) of the event chosen in the calendar view

function ns.LineupPageFrame() return page end

local function curNight() return night or ns.LineupTonight() end

local ROLE_SHORT = { T = L["T##Rolle"], H = L["H##Rolle"], M = L["N##Rolle"], R = L["F##Rolle"] }
local ROLE_NAME = { T = L["Tank"], H = L["Heiler"], M = L["Nahkampf"], R = L["Fernkampf"] }
local ROLE_COLOR = { T = "|cff8fb3ff", H = "|cff6fe08a", M = "|cffff9a5c", R = "|cffd9a8ff" }

local function roleText(e)
    if not e.r then return GREY .. "?|r" end
    if e.q then return GREY .. ROLE_SHORT[e.r] .. "?|r" end
    return ROLE_COLOR[e.r] .. ROLE_SHORT[e.r] .. "|r"
end

local STATE_COLOR = { a = ORANGE, u = RED, g = GREY }
local function classColored(name, class, dim, x)
    if STATE_COLOR[x] then return STATE_COLOR[x] .. name .. "|r" end
    if dim then return GREY .. name .. "|r" end
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local STATE = {
    l = YELLOW .. L["vermutlich"] .. "|r",
    a = ORANGE .. L["nicht eindeutig"] .. "|r",
    u = RED .. L["unbekannt"] .. "|r",
    g = GREY .. L["Gast"] .. "|r",
}
-- the valid status of parts G and H (st)
local STATUS = {
    A = GREEN .. L["angemeldet"] .. "|r", B = GREEN .. L["bestätigt"] .. "|r", V = ORANGE .. L["vorläufig"] .. "|r",
    E = YELLOW .. L["Ersatz"] .. "|r", X = GREY .. L["abgemeldet"] .. "|r", I = GREY .. L["eingeladen"] .. "|r",
    O = GREY .. L["ohne Antwort"] .. "|r", G = GREY .. L["nicht mehr im Kalender"] .. "|r",
}
local STATUS_PLAIN = { A = L["angemeldet"], B = L["bestätigt"], V = L["vorläufig"], E = L["Ersatz"], X = L["abgemeldet"],
                       I = L["eingeladen"], O = L["ohne Antwort"], G = L["nicht mehr im Kalender"] }
-- a row only from a pasted list shows the match as before; one with the calendar or Amisia its status
local function fromList(e) return not ns.LineupHasSource(e, "K") and not ns.LineupHasSource(e, "A") end
local function stateText(e)
    if fromList(e) or not e.st then
        if e.a then return GREY .. L["abgemeldet"] .. "|r" end
        return STATE[e.x] or (GREEN .. L["gefunden"] .. "|r")
    end
    -- an unclear name first: it needs a click
    if e.x and e.x ~= "g" then return STATE[e.x] end
    -- a held player who signed off stays in the group: red
    if e.st == "X" and e.k and e.g then return RED .. L["abgemeldet"] .. "|r" end
    return STATUS[e.st] or ""
end

-- the source marks: L list, K calendar (grey when its event is gone), A Amisia
local SRC_COLOR = { L = "|cffd8d8d8", K = "|cff8fb3ff", A = T.GOLD_TEXT }
local SRC_WORD = { L = L["L##Quelle"], K = L["K##Quelle"], A = L["A##Quelle"] }
local SRC_NAME = { L = L["Liste"], K = L["Kalender"], A = L["Amisia"] }
local function sourceText(e, lost)
    local out = {}
    for _, x in ipairs({ "L", "K", "A" }) do
        if ns.LineupHasSource(e, x) then
            local c = (x == "K" and lost) and GREY or SRC_COLOR[x]
            out[#out + 1] = c .. SRC_WORD[x] .. "|r"
        end
    end
    return table.concat(out, " ")
end

-- "Discord: angemeldet" when the pasted list says something else than the valid status
local SAME = { B = "A" }   -- "bestätigt" is "angemeldet" for the list
local function listHint(e)
    if not e.d or not e.st or e.d == (SAME[e.st] or e.st) or fromList(e) then return nil end
    return GREY .. L["Discord: %s"]:format(STATUS_PLAIN[e.d] or "?") .. "|r"
end

-- "Heute, 05.10. (38)" for the night picker
local function nightLabel(key, n)
    local y, m, d = tostring(key):match("^(%d+)-(%d+)-(%d+)$")
    local day = d and ns.FmtDay(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })) or key
    local count = n and #n.list or 0
    if key == ns.LineupTonight() then return L["Heute, %s (%d)"]:format(day, count) end
    return ("%s (%d)"):format(day, count)
end
ns.LineupNightLabel = nightLabel

local function show(frame, on) if on then frame:Show() else frame:Hide() end end

---------------------------------------------------------------------------
-- Clicks: choose, swap, move; the right-click menu
---------------------------------------------------------------------------
local function say(ok, why) if not ok and why then ns.msg(why) end end

-- target: { i = entry } or { g = group } (a free place) or { to = "open" / "bench" } (a list head)
local function act(from, target)
    selected = nil
    if target.i then
        say(ns.LineupSwap(curNight(), from, target.i))
    elseif target.g then
        say(ns.LineupMove(curNight(), from, target.g))
    elseif target.to == "bench" then
        say(ns.LineupMove(curNight(), from, "bench"))
    elseif target.to == "open" then
        say(ns.LineupMove(curNight(), from, nil))
    end
    ns.Refresh()
end

local function click(target)
    if target.i then
        if not selected then
            selected = target.i
        elseif selected == target.i then
            selected = nil
        else
            act(selected, target)
            return
        end
        ns.Refresh()
    elseif selected then
        act(selected, target)
    end
end
ns._lineupClick = click

local function menuFor(owner, i)
    local n = ns.LineupNight(curNight(), false)
    local e = n and n.list[i]
    if not e then return end
    local key = curNight()
    local entries = {}
    for _, r in ipairs(ns.LINEUP_ROLES) do
        local mark = (e.r == r and not e.q) and (T.GOLD_TEXT .. "%s|r") or "%s"
        entries[#entries + 1] = { mark:format(L["Rolle: %s"]:format(ROLE_NAME[r])), function() ns.LineupSetRole(key, i, r) end }
    end
    if not e.a then
        if e.b or e.v then
            entries[#entries + 1] = { L["Nicht mehr Ersatz"], function() ns.LineupMove(key, i, nil) end }
        else
            entries[#entries + 1] = { L["Ersatz"], function() ns.LineupMove(key, i, "bench") end }
        end
        entries[#entries + 1] = { e.k and L["Nicht mehr festhalten"] or L["Festhalten"], function() ns.LineupHold(key, i, not e.k) end }
        if e.g then entries[#entries + 1] = { L["Aus der Gruppe nehmen"], function() ns.LineupMove(key, i, nil) end } end
    end
    entries[#entries + 1] = { L["Entfernen"], function()
        selected = nil
        ns.LineupRemove(key, i)
    end }
    return W.Menu(owner, entries)
end
ns._lineupMenu = menuFor

local function tooltip(owner, e)
    if not e then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.n, 1, 0.82, 0)
    if e.s then GameTooltip:AddLine(L["In der Liste: %s"]:format(e.s), 0.85, 0.85, 0.85) end
    local people = page and page.people or {}
    local p = people[e.n:lower()]
    local bits = { stateText(e) }
    if e.r then bits[#bits + 1] = ROLE_NAME[e.r] .. (e.q and L[" (geraten)"] or "") end
    if p then bits[#bits + 1] = p.online and (GREEN .. L["online"] .. "|r") or (GREY .. L["offline"] .. "|r") end
    GameTooltip:AddLine(table.concat(bits, " · "), 0.85, 0.85, 0.85)
    local src = {}
    for _, x in ipairs({ "L", "K", "A" }) do
        if ns.LineupHasSource(e, x) then src[#src + 1] = SRC_NAME[x] end
    end
    if not fromList(e) then GameTooltip:AddLine(L["Quellen: %s"]:format(table.concat(src, ", ")), 0.85, 0.85, 0.85) end
    if e.st and e.t and not fromList(e) then
        GameTooltip:AddLine(L["%s seit %s"]:format(STATUS_PLAIN[e.st] or "?", ns.FmtDayTime(e.t)), 0.85, 0.85, 0.85)
    end
    if e.w then GameTooltip:AddLine(L["Notiz: %s"]:format(e.w), 1, 1, 1, true) end
    local hint = listHint(e)
    if hint then GameTooltip:AddLine(hint, 0.85, 0.85, 0.85) end
    if e.k then GameTooltip:AddLine(L["Festgehalten: \"Automatisch einteilen\" bewegt diesen Spieler nicht."], 0.85, 0.85, 0.85, true) end
    if e.m then GameTooltip:AddLine(L["Vielleicht"], 0.85, 0.85, 0.85) end
    if e.v then GameTooltip:AddLine(L["Überzählig: kein Platz mehr frei."], 0.85, 0.85, 0.85, true) end
    if view == "planner" then GameTooltip:AddLine(L["Klick: wählen. Rechtsklick: Rolle, Ersatz, Festhalten, Entfernen."], 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

-- Every frame a drag may end on, with its target.
local dropTargets = {}
local function dragStop()
    local from = page and page.drag
    if page then page.drag = nil end
    if not from then return end
    for _, d in ipairs(dropTargets) do
        local f = d.frame
        if f:IsVisible() and f:IsMouseOver() then
            local target = d.target(f)
            if target and target.i ~= from then act(from, target) end
            return
        end
    end
end
ns._lineupDrop = function(from, frame)
    if page then page.drag = from end
    for _, d in ipairs(dropTargets) do
        if d.frame == frame then
            local target = d.target(frame)
            if target and target.i ~= from then act(from, target) end
            return
        end
    end
end

-- A frame that takes clicks (left: choose/act, right: menu) and drags; target(frame) says what it is.
-- menuOnly: a row of the match view (no choosing there, only the menu).
local function wire(f, target, menuOnly)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if not menuOnly then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnClick", function(self, button)
        local t = target(self)
        if not t then return end
        if button == "RightButton" then
            if t.i then menuFor(self, t.i) end
            return
        end
        if not menuOnly then click(t) end
    end)
    f:SetScript("OnDragStart", function(self)
        local t = target(self)
        if t and t.i and page then page.drag = t.i end
    end)
    f:SetScript("OnDragStop", dragStop)
    f:SetScript("OnEnter", function(self)
        local t = target(self)
        if t and t.i and page then tooltip(self, page.list and page.list[t.i]) end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if not menuOnly then dropTargets[#dropTargets + 1] = { frame = f, target = target } end
end

---------------------------------------------------------------------------
-- The planner
---------------------------------------------------------------------------
local function buildGroups(f, top)
    f.groups = {}
    for g = 1, 8 do
        local box = W.Inset(f)
        box:SetSize(GROUP_W, GROUP_H)
        box:SetPoint("TOPLEFT", ((g - 1) % 4) * (GROUP_W + GROUP_GAP), top - math.floor((g - 1) / 4) * (GROUP_H + GROUP_GAP))
        box.title = W.Text(box, T.FONT.head, 90)
        box.title:SetPoint("TOPLEFT", 6, -3)
        box.title:SetText(L["Gruppe %d"]:format(g))
        box.count = W.Text(box, T.FONT.hint, 40)
        box.count:SetPoint("TOPRIGHT", -6, -3)
        box.count:SetJustifyH("RIGHT")
        box.alarm = W.Border(box, 0.88, 0.34, 0.29, 1)
        box.slots = {}
        for s = 1, 5 do
            local b = CreateFrame("Button", nil, box)
            b:SetHeight(SLOT_H - 1)
            b:SetPoint("TOPLEFT", SLOT_INSET, -HEAD_H - (s - 1) * SLOT_H)
            b:SetPoint("TOPRIGHT", -SLOT_INSET, -HEAD_H - (s - 1) * SLOT_H)
            b.bg = W.Flat(b, 1, 1, 1, T.ROW_SHADE[(s % 2 == 0) and 2 or 1])
            b.hover = b:CreateTexture(nil, "HIGHLIGHT")
            b.hover:SetAllPoints()
            b.hover:SetColorTexture(1, 1, 1, 0.08)
            b.sel = W.SelectBar(b)
            b.role = W.Text(b, T.FONT.text, 16)
            b.role:SetPoint("LEFT", 3, 0)
            b.name = W.Text(b, T.FONT.text, GROUP_W - 2 * SLOT_INSET - 38)
            b.name:SetPoint("LEFT", 20, 0)
            b.lock = b:CreateTexture(nil, "ARTWORK")
            b.lock:SetSize(12, 12)
            b.lock:SetPoint("RIGHT", -3, 0)
            b.lock:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
            b.group = g
            wire(b, function(self) return self.entry and { i = self.entry } or { g = self.group } end)
            box.slots[s] = b
        end
        f.groups[g] = box
    end
end

local function fillGroups(f, n, counts)
    local G = n and ns.LineupGroups(n) or 0
    local members = {}
    for g = 1, 8 do members[g] = {} end
    for i, e in ipairs(n and n.list or {}) do
        if e.g and members[e.g] then table.insert(members[e.g], i) end
    end
    local noHeal = {}
    for _, g in ipairs(counts.noHealer) do noHeal[g] = true end
    for g, box in ipairs(f.groups) do
        show(box, g <= G)
        box.count:SetText(("%d/5"):format(#members[g]))
        for _, edge in ipairs(box.alarm) do show(edge, noHeal[g] == true) end
        for s, b in ipairs(box.slots) do
            local i = members[g][s]
            local e = i and n.list[i]
            b.entry = i
            if e then
                local p = f.people[e.n:lower()]
                b.role:SetText(roleText(e))
                b.name:SetText(classColored(e.n, e.c, p ~= nil and not p.online, e.x))
                show(b.lock, e.k == true)
            else
                b.role:SetText("")
                b.name:SetText(GREY .. L["frei##Platz"] .. "|r")
                b.lock:Hide()
            end
            show(b.sel, i ~= nil and i == selected)
        end
    end
end

local function buildSide(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.Cells(row, SIDE_COLS)
    row.info:SetJustifyH("RIGHT")
    row.sel = W.SelectBar(row)
    wire(row, function(self) return self.item and { i = self.item.i } or nil end)
end

local function fillSide(row, it)
    local e = it.e
    local p = page.people[e.n:lower()]
    row.r:SetText(roleText(e))
    row.name:SetText(classColored(e.n, e.c, p ~= nil and not p.online, e.x) .. (e.k and (GREY .. L[" (fest)"] .. "|r") or ""))
    row.info:SetText(it.info or "")
    show(row.sel, it.i == selected)
end

-- the heads of the two lists take a chosen name: "Nicht eingeteilt" and "Ersatz"
local function sideHeads(f, top)
    local _, a = f:Columns({ { "a", 6, LEFT_W - 12, "" } }, { top = top, x = 0, width = LEFT_W, sort = function()
        if selected then act(selected, { to = "open" }) end
    end })
    local _, b = f:Columns({ { "b", 6, RIGHT_W - 12, "" } }, { top = top, x = RIGHT_X, width = RIGHT_W, sort = function()
        if selected then act(selected, { to = "bench" }) end
    end })
    -- with sort the heads are buttons; their labels carry the text
    f.openHead, f.benchHead = a.a.label, b.b.label
    f.openBtn, f.benchBtn = a.a, b.b
    for _, h in ipairs({ { a.a, "open" }, { b.b, "bench" } }) do
        dropTargets[#dropTargets + 1] = { frame = h[1], target = function() return { to = h[2] } end }
    end
    return top - T.LAYOUT.COLHEAD_H
end

---------------------------------------------------------------------------
-- The match view
---------------------------------------------------------------------------
local function buildMatch(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.Cells(row, MATCH_COLS)
    row.level:SetJustifyH("RIGHT")
    row.chips = {}
    for c = 1, MAX_CHIPS do
        local chip = W.Chip(row, "", 60, function(self)
            local it = self:GetParent().item
            if it and self.pick then
                say(ns.LineupConfirm(curNight(), it.i, self.pick ~= true and self.pick or nil))
            elseif it and self.alt then
                say(ns.LineupSwapAlt(curNight(), it.i, self.alt))
            end
        end)
        chip:SetOn(false)
        chip:Hide()
        row.chips[c] = chip
    end
    row.edit = W.LineEdit(row, 130, function(text)
        local it = row.item
        text = (text or ""):match("^%s*(.-)%s*$")
        if it and text ~= "" then say(ns.LineupConfirm(curNight(), it.i, text)) end
    end)
    row.edit:SetPoint("LEFT", ACT_X, 0)
    row.edit:Hide()
    wire(row, function(self) return self.item and { i = self.item.i } or nil end, true)
end

local function placeChips(row, from)
    local x = from or ACT_X
    for _, chip in ipairs(row.chips) do
        if chip:IsShown() then
            chip:ClearAllPoints()
            chip:SetPoint("LEFT", x, 0)
            x = x + chip:GetWidth() + T.CHIP_GAP
        end
    end
end

local function chip(row, c, label, maxW)
    local b = row.chips[c]
    b.label:SetText(label)
    W.FitChip(b, nil, maxW or CHIP_MAX_W)
    b.pick, b.alt = nil, nil
    b:SetOn(false)
    b:Show()
    return b
end

local function fillMatch(row, it)
    local e = it.e
    local p = page.people[e.n:lower()]
    for _, c in ipairs(row.chips) do c:Hide() end
    row.edit:Hide()
    row.r:SetText(roleText(e))
    row.src:SetText(sourceText(e, page.calLost))
    local name = classColored(e.n, e.c, e.a or (e.x ~= nil and e.x ~= "l"))
    -- a note (Amisia): a small gold mark, the note itself in the tooltip
    if e.w then name = name .. T.GOLD_TEXT .. " *|r" end
    if e.s then name = name .. GREY .. L[" (Liste: %s)"]:format(e.s) .. "|r" end
    row.name:SetText(name)
    row.state:SetText(stateText(e) .. ((e.m and fromList(e)) and (GREY .. L[", vielleicht"] .. "|r") or ""))
    -- below the highest level: orange (invited anyway when placed)
    local top = type(GetMaxPlayerLevel) == "function" and tonumber(GetMaxPlayerLevel()) or nil
    row.level:SetText(p and p.level and ((top and p.level < top) and (ORANGE .. p.level .. "|r") or tostring(p.level)) or "")
    row.online:SetText(p and (p.online and (GREEN .. L["online"] .. "|r") or (GREY .. L["offline"] .. "|r")) or "")
    row.act:SetText("")
    if e.a then
        -- nothing to do but the list's other word
        row.act:SetText(listHint(e) or "")
    elseif e.x == "l" then
        chip(row, 1, L["Bestätigen"]).pick = true
        placeChips(row)
    elseif e.x == "a" then
        for c, o in ipairs(e.o or {}) do
            if c > MAX_CHIPS then break end
            chip(row, c, o).pick = o
        end
        placeChips(row)
    elseif e.x == "u" then
        row.edit:SetText("")
        row.edit:Show()
    elseif e.x == "g" and not ns.Get("lineup.guests") then
        row.act:SetText(GREY .. L["nur mit \"Gäste einladen\""] .. "|r")
    elseif it.alt then
        row.act:SetText(L["Twink online: %s"]:format(it.alt))
        local b = chip(row, 1, L["tauschen"], 70)
        b.alt = it.alt
        placeChips(row, ACT_X + math.min(110, row.act:GetStringWidth() + 6))
    elseif listHint(e) then
        row.act:SetText(listHint(e))
    end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
-- Opens the page (the officers only), in a view when given ("match", "planner", "paste").
function ns.ShowLineup(which, key)
    if which == "match" or which == "planner" or which == "paste" then view = which end
    if which == "calendar" then return ns.LineupShowCalendar() end
    if key then night = key end
    ns.ShowPage("lineup")
end

---------------------------------------------------------------------------
-- The calendar view: the guild events of the next 14 days, "Übernehmen"
---------------------------------------------------------------------------
local function calChosen()
    for _, ev in ipairs(calList or {}) do
        if (ev.id or ev.index) == calPick then return ev end
    end
    return nil
end

-- Opens the calendar view and reads the guild events (the next of the raid type chosen).
function ns.LineupShowCalendar()
    view, calList = "calendar", nil
    ns.ShowPage("lineup")
    ns.Cal.Load(function(list)
        calList = list or {}
        if not calChosen() then
            local nxt = ns.Cal.Next(calList)
            calPick = nxt and (nxt.id or nxt.index) or nil
        end
        if ns.CurrentPage and ns.CurrentPage() == "lineup" then ns.Refresh() end
    end)
end

local function takeCalendar()
    local ev = calChosen()
    if not ev then return end
    ns.LineupReadCalendar(ev, function(key, line)
        if key then
            night, selected, view = key, nil, "match"
        end
        if line then ns.msg(line) end
        ns.Refresh()
    end)
end

local function buildCal(row)
    W.Cells(row, CAL_COLS)
    row.sel = W.SelectBar(row)
    row:SetScript("OnClick", function(self)
        if self.item then
            calPick = self.item.id or self.item.index
            ns.Refresh()
        end
    end)
    row:SetScript("OnDoubleClick", function(self)
        if self.item then
            calPick = self.item.id or self.item.index
            takeCalendar()
        end
    end)
end

local function fillCal(row, ev)
    row.when:SetText(("%s %s"):format(ns.FmtDay(ev.at), ns.Cal.When(ev.at)))
    row.title:SetText(ev.raid and (T.GOLD_TEXT .. ev.title .. "|r") or ev.title)
    local word = ev.type and ns.Cal.TYPE_WORD[ev.type]
    row.kind:SetText(word and L[word] or "")
    local own = ev.own and STATUS[ev.own]
    row.own:SetText(own and L["du: %s"]:format(own) or "")
    show(row.sel, (ev.id or ev.index) == calPick)
end

-- Reads the shown night's event again while the page is open: after a change in the calendar (at
-- most every RELOAD_GAP seconds) and every POLL seconds.
local lastReload = 0
local reloadPending = false
local function pageOpen()
    local main = _G.AmisiaFrame
    return page ~= nil and page:IsVisible() and (not main or main:IsShown()) and ns.CurrentPage and ns.CurrentPage() == "lineup"
end
local function reloadCalendar()
    if not pageOpen() or view == "paste" then return end
    local n = ns.LineupNight(curNight(), false)
    if not n or not n.cal or InCombatLockdown() then return end
    if reloadPending then return end
    local wait = RELOAD_GAP - (GetTime() - lastReload)
    reloadPending = true
    C_Timer.After(math.max(0, wait), function()
        reloadPending = false
        if not pageOpen() then return end
        lastReload = GetTime()
        ns.LineupCalendarAgain(curNight())
    end)
end
ns.Listen("CALENDAR_CHANGED", reloadCalendar)
ns.LineupReloadCalendar = reloadCalendar

local function apply(f)
    local key, line = ns.SetLineupText(f.paste.box:GetText() or "", curNight())
    if not key then
        ns.msg(line)
        return
    end
    night, selected, view = key, nil, "match"
    f.paste.box:SetText("")
    f.paste.box:ClearFocus()
    ns.msg(line)
    ns.Refresh()
end

-- The newest saved night before the shown one with a list, for "Von ... übernehmen".
local function previousNight()
    local cur = curNight()
    for _, key in ipairs(ns.LineupNights()) do
        local n = ns.LineupNight(key, false)
        if key < cur and n and #n.list > 0 then return key end
    end
    return nil
end

ns.RegisterPanel{ key = "lineup", label = L["Aufstellung"], icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", order = 22, group = "raid",
    officer = true, available = function() return ns.LineupAllowed() end,
    create = function(parent)
        local f = W.Page(parent)
        page = f
        dropTargets = {}
        f.people = {}
        -- head row: the night on the left, paste and auto-assign on the right; the counts; the
        -- views with the view's action on the right
        local top = f:Bands({ "row", "line", "line", "row" })
        f.night = W.Picker(f, 150, function(v)
            night, selected = v, nil
            ns.Refresh()
        end)
        f.pasteBtn = W.Button(f, L["Einfügen"], 90, function()
            view = view == "paste" and "match" or "paste"
            ns.Refresh()
            if view == "paste" then f.paste.box:SetFocus() else f.paste.box:ClearFocus() end
        end)
        f.calBtn = W.Button(f, L["Kalender"], 80, function()
            if view == "calendar" then
                view = "match"
                ns.Refresh()
            else
                ns.LineupShowCalendar()
            end
        end)
        W.FitChip(f.calBtn, 80)
        W.Tooltip(f.calBtn, L["Kalender"], L["Die Gildenereignisse der nächsten 14 Tage aus dem Spielkalender. \"Übernehmen\" liest die Teilnehmerliste in die Aufstellung der Nacht (Amisia schreibt nichts in den Kalender)."])
        f.auto = W.Button(f, L["Automatisch einteilen"], 160, function()
            local placed, over = ns.LineupAutoAssign(curNight())
            selected, view = nil, "planner"
            local n = ns.LineupNight(curNight(), false)
            ns.msg(L["Eingeteilt: %d in %d Gruppen, %d auf Ersatz (überzählig)."]:format(placed, n and ns.LineupGroups(n) or 0, over))
            ns.Refresh()
        end)
        W.FitChip(f.pasteBtn, 90)
        W.FitChip(f.auto, 160)
        W.Tooltip(f.auto, L["Automatisch einteilen"], L["Tanks ab Gruppe 1, ein Heiler pro Gruppe, Nahkampf zusammen mit einem Schamanen oder Krieger, Fernkampf zusammen. Festgehaltene bleiben stehen."])
        f:Place(1, { f.night }, { f.calBtn, f.pasteBtn, f.auto })
        f.counts = f:Line(2)
        f.calLine = f:Line(3)
        f.views = {
            match = W.Chip(f, L["Abgleich"], 70, function() view, selected = "match", nil ns.Refresh() end),
            planner = W.Chip(f, L["Planer"], 70, function() view = "planner" ns.Refresh() end),
        }
        for _, c in pairs(f.views) do W.FitChip(c, 70) end
        f.rematch = W.Button(f, L["Neu abgleichen"], 120, function()
            local line = ns.LineupRematch(curNight())
            if line then ns.msg(line) end
        end)
        f.bench = W.Button(f, L["Ersatz auf die Ersatzbank"], 180, function()
            ns.msg(ns.LineupBenchMessage(ns.LineupBench(curNight())))
        end)
        W.Tooltip(f.bench, L["Ersatz auf die Ersatzbank"], L["Trägt \"Ersatz\" und Überzählige, die online sind, mit der Notiz \"Aufstellung\" auf die Ersatzbank des Abends ein (wie /amisia ersatz)."])
        f.copy = W.Button(f, L["Übernehmen"], 160, function()
            local from = previousNight()
            if not from then return end
            local count, why = ns.LineupCopy(from, curNight())
            ns.msg(count and L["%d Namen von %s übernommen."]:format(count, nightLabel(from):match("^(.-) %(") or from) or why)
        end)
        f.take = W.Button(f, L["Übernehmen"], 110, function() apply(f) end)
        f.cancel = W.Button(f, L["Abbrechen"], 100, function()
            view = "match"
            f.paste.box:ClearFocus()
            ns.Refresh()
        end)
        f.calTake = W.Button(f, L["Übernehmen"], 110, takeCalendar)
        W.Tooltip(f.calTake, L["Übernehmen"], L["Liest die Teilnehmerliste des gewählten Ereignisses in die Aufstellung seiner Nacht. Bleibt die Seite offen, liest Amisia sie bei Änderungen neu."])
        for _, b in ipairs({ f.rematch, f.bench, f.take, f.cancel, f.calTake }) do W.FitChip(b, 100) end
        f:Footer({ { "hint", lines = 2 } })
        -- the paste field
        f.paste = W.EditArea(f)
        f.paste:SetPoint("TOPLEFT", 0, top)
        f.paste:SetPoint("BOTTOMRIGHT", 0, f:Bottom())
        -- the match view
        f.match = W.Page(f, { view = true, top = top })
        local _, mheads = f.match:Columns(MATCH_COLS)
        mheads.r:SetText(L["Rolle"])
        mheads.name:SetText(L["Name##Spalte"])
        mheads.state:SetText(L["Abgleich"])
        mheads.level:SetText(L["Stufe"])
        mheads.level:SetJustifyH("RIGHT")
        mheads.online:SetText(L["Status"])
        f.mlist = f.match:List(MATCH_ROWS, MATCH_ROW_H, buildMatch, fillMatch)
        -- the planner
        f.plan = W.Page(f, { view = true, top = top })
        buildGroups(f.plan, 0)
        local sideTop = sideHeads(f.plan, -(2 * GROUP_H + GROUP_GAP + GROUP_GAP))
        f.openList = f.plan:List(LIST_ROWS, LIST_ROW_H, buildSide, fillSide, { top = sideTop, x = 0, width = LEFT_W })
        f.benchList = f.plan:List(LIST_ROWS, LIST_ROW_H, buildSide, fillSide, { top = sideTop, x = RIGHT_X, width = RIGHT_W })
        f.plan.people = f.people
        f.openHead, f.benchHead = f.plan.openHead, f.plan.benchHead
        -- the calendar view
        f.cal = W.Page(f, { view = true, top = top })
        local _, cheads = f.cal:Columns(CAL_COLS)
        cheads.when:SetText(L["Wann"])
        cheads.title:SetText(L["Gildenereignis"])
        cheads.kind:SetText(L["Art"])
        cheads.own:SetText(L["Status"])
        f.calRows = f.cal:List(CAL_ROWS, CAL_ROW_H, buildCal, fillCal)
        f.empty = f:Empty()
        -- the calendar of the shown night is read again now and then while the page is open
        C_Timer.NewTicker(POLL, function()
            local n = pageOpen() and ns.LineupNight(curNight(), false)
            -- asks the client for the newest state: a change comes back as CALENDAR_CHANGED
            if n and n.cal and not InCombatLockdown() and ns.Cal.Available() then pcall(C_Calendar.OpenCalendar) end
        end)
        return f
    end,
    refresh = function(f)
        -- the officer takes the sign-ups of the own characters of this account (no message);
        -- a change fires LINEUP and so one more refresh
        if ns.SignupTakeOwn then ns.SignupTakeOwn() end
        local key = curNight()
        local n = ns.LineupNight(key, false)
        f.people = ns.LineupPeople()
        f.plan.people = f.people
        f.list = n and n.list or {}
        f.calLost = n and n.cal and n.cal.lost or false
        if selected and not f.list[selected] then selected = nil end
        -- the night picker: tonight, then the saved nights
        local values, seen = {}, {}
        local function add(k)
            if seen[k] then return end
            seen[k] = true
            values[#values + 1] = { value = k, text = nightLabel(k, ns.LineupNight(k, false)) }
        end
        add(ns.LineupTonight())
        for _, k in ipairs(ns.LineupNights()) do add(k) end
        add(key)
        f.night:SetValues(values)
        f.night:SetValue(key)
        local has = #f.list > 0
        local paste, calendar = view == "paste", view == "calendar"
        local other = paste or calendar
        local shown = view
        f.views.match:SetOn(shown == "match")
        f.views.planner:SetOn(shown == "planner")
        f.pasteBtn:SetText(paste and L["Zurück"] or L["Einfügen"])
        W.FitChip(f.pasteBtn, 90)
        f.calBtn:SetText(calendar and L["Zurück"] or L["Kalender"])
        W.FitChip(f.calBtn, 80)
        f.calBtn:SetEnabled(calendar or ns.Cal.CanReadInvites())
        f.auto:SetEnabled(has and not other)
        -- the counts
        local c = ns.LineupCounts(key)
        if has then
            local text = L["Tanks %d · Heiler %d · Nahkampf %d · Fernkampf %d · Ersatz %d"]:format(c.T, c.H, c.M, c.R, c.bench)
            if c.absent > 0 then text = text .. L[" · abgemeldet %d"]:format(c.absent) end
            if #c.noHealer > 0 then
                local gs = {}
                for i, g in ipairs(c.noHealer) do gs[i] = tostring(g) end
                text = text .. " · " .. RED .. L["ohne Heiler: Gruppe %s"]:format(table.concat(gs, ", ")) .. "|r"
            end
            f.counts:SetText(text)
        else
            f.counts:SetText(n and n.title or "")
        end
        -- the calendar of the night and the sources: "Kalender: Molten Core · Fr 20:00 · gelesen 19:42 · Liste 9 · ..."
        local parts = {}
        if not ns.Cal.CanReadInvites() then
            parts[1] = GREY .. L["Kalender nicht verfügbar."] .. "|r"
        elseif n and n.cal then
            parts[1] = L["Kalender: %s · %s"]:format(n.cal.title or "?", ns.Cal.When(n.cal.at))
            if n.cal.lost then
                parts[#parts + 1] = GREY .. L["Ereignis nicht mehr im Kalender"] .. "|r"
            elseif n.cal.read then
                parts[#parts + 1] = L["gelesen %s"]:format(date("%H:%M", n.cal.read))
            end
        end
        if has then
            local src = ns.LineupSources(key)
            if src.K + src.A > 0 then
                parts[#parts + 1] = L["Liste %d · Kalender %d · Amisia %d"]:format(src.L, src.K, src.A)
            end
        end
        f.calLine:SetText(table.concat(parts, " · "))
        -- the view's buttons on the right of the last band
        local prev = not has and not other and previousNight() or nil
        if prev then
            f.copy:SetText(L["Von %s übernehmen"]:format(nightLabel(prev):match("^(.-) %(") or prev))
            W.FitChip(f.copy, 120)
        end
        show(f.copy, prev ~= nil)
        show(f.rematch, has and shown == "match")
        show(f.bench, has and shown == "planner")
        f.bench:SetEnabled(key == ns.LineupTonight() and (c.bench > 0))
        show(f.take, paste)
        show(f.cancel, other)
        show(f.calTake, calendar)
        f.calTake:SetEnabled(calendar and calChosen() ~= nil)
        show(f.views.match, not other)
        show(f.views.planner, not other)
        f:Place(4, { f.views.match, f.views.planner }, { f.copy, f.rematch, f.bench, f.cancel, f.take, f.calTake }, { shown = true })
        show(f.paste, paste)
        show(f.match, shown == "match" and has)
        show(f.plan, shown == "planner" and has)
        show(f.cal, calendar and calList ~= nil and #calList > 0)
        if calendar then
            if not calList then
                f.empty:Set(L["Kalender wird gelesen ..."], L["Amisia fragt den Spielkalender nach den Gildenereignissen."])
            elseif #calList == 0 then
                f.empty:Set(L["Keine Gildenereignisse"], L["In den nächsten 14 Tagen steht kein Gildenereignis im Spielkalender. Ein Offizier legt es dort an (Gilden-Ereignis)."])
            else
                f.calRows:SetItems(calList)
            end
        elseif not has and not paste then
            f.empty:Set(L["Noch keine Anmeldungen"], prev and L["\"Einfügen\" nimmt die Anmeldeliste, oder übernimm die Aufstellung einer früheren Nacht."]
                or L["\"Einfügen\" nimmt den Text eines Anmelde-Bots aus Discord, Zeilen wie \"Anna Tank\" oder den Block #AMISIA-RAID."])
        end
        show(f.empty, (calendar and (not calList or #calList == 0)) or (not has and not other))
        if paste then
            f.hint:SetText(L["Discord-Text eines Anmelde-Bots (Überschriften wie \"Tanks\", \"Heiler\", \"Ersatz\", \"Abgemeldet\"), Zeilen wie \"Anna Tank\" oder \"Bob, Nahkampf\", oder der Block #AMISIA-RAID. Dann \"Übernehmen\"."])
        elseif calendar then
            f.hint:SetText(L["Gildenereignisse der nächsten 14 Tage, Schlachtzug zuerst gewählt. \"Übernehmen\" liest die Teilnehmerliste in die Aufstellung der Nacht des Ereignisses; im Kalender ändert Amisia nichts."])
        elseif shown == "planner" then
            f.hint:SetText(L["Klick auf einen Namen, dann auf einen anderen oder einen freien Platz: tauschen oder verschieben (Ziehen geht auch). Rot umrandet: Gruppe ohne Heiler. Rechtsklick: Rolle, Ersatz, Festhalten."])
        else
            f.hint:SetText(has and L["Gelb: ein Klick bestätigt. Orange: den Richtigen wählen. Rot: den Namen eintippen (Amisia merkt ihn sich). Rechtsklick: Rolle, Ersatz, Festhalten, Entfernen."] or "")
        end
        if not has or calendar then return end
        -- the rows of both views
        local matchItems, open, bench, absent = {}, {}, {}, {}
        for i, e in ipairs(f.list) do
            local it = { i = i, e = e }
            if e.a then
                absent[#absent + 1] = it
            else
                it.alt = e.x == nil and ns.LineupAltOnline(e, f.people, f.list) or nil
                matchItems[#matchItems + 1] = it
                if e.b or e.v then
                    bench[#bench + 1] = { i = i, e = e, info = e.v and (GREY .. L["überzählig"] .. "|r") or (e.m and (GREY .. L["vielleicht"] .. "|r")) or "" }
                elseif not e.g then
                    open[#open + 1] = { i = i, e = e, info = (e.x and stateText(e)) or (e.m and (GREY .. L["vielleicht"] .. "|r")) or "" }
                end
            end
        end
        for _, it in ipairs(absent) do matchItems[#matchItems + 1] = it end
        if shown == "match" then
            f.mlist:SetItems(matchItems)
        elseif shown == "planner" then
            fillGroups(f.plan, n, c)
            f.openHead:SetText(L["Nicht eingeteilt (%d)"]:format(#open))
            f.benchHead:SetText(L["Ersatz (%d)"]:format(#bench))
            f.openList:SetItems(open)
            f.benchList:SetItems(bench)
        end
    end }

ns.Listen("LINEUP", function()
    if ns.CurrentPage and ns.CurrentPage() == "lineup" then ns.Refresh() end
end)

-- the roster changed (someone came online): the online marks may have changed
local rosterPending = false
local function later()
    if rosterPending then return end
    rosterPending = true
    C_Timer.After(1, function()
        rosterPending = false
        if ns.CurrentPage and ns.CurrentPage() == "lineup" then ns.Refresh() end
    end)
end
ns.OnEvent("GUILD_ROSTER_UPDATE", later)
ns.OnEvent("GROUP_ROSTER_UPDATE", later)
