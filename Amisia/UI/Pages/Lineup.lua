-- Aufstellung (officers only, D-41): the sign-up list of a raid night in two views, the match
-- against the guild ("Abgleich": found, likely, ambiguous, unknown, guest, with one click to fix)
-- and the planner ("Planer": the groups of the raid size, not placed, bench; click a name, then
-- another or a free place to swap or move, or drag; right click for role, bench, hold, remove), the
-- paste field and the calendar view ("Kalender": the guild events of the next 14 days, the next of
-- the raid type chosen, "Übernehmen" reads its invite list into the event's night, D-42). Each row
-- carries the marks of its sources (L list, K calendar, A Amisia) and the valid status; while the
-- page is open a change in the calendar reads the night's event again (at most every 5 s). The
-- logic lives in Raid/Lineup.lua and Raid/Calendar.lua; this page only shows it. With raid IDs known
-- (Raid/RaidIDs.lua, F-099) the match view marks each name "ID" for the instance chosen beside the
-- views: green free, red locked, grey unknown; its tooltip names the bosses, the reset and the free
-- alts of the player's main. The view "Einladen" (F-084, Raid/LineupInvite.lua) lists the placed
-- players with their invite status and tries, "Alle einladen" and "Nochmal einladen (N)" (the
-- reason on the button when it may not: combat, no lead); the planner has "Gruppen sortieren"
-- (Raid/LineupSort.lua, "Sortieren fortsetzen" after a fight).
-- F-161 (D-91): the planner also opens on a night without a list; "Spieler" swaps the two lists under
-- the groups for the player list (the raid or the guild, online only, a class, a search; a click
-- chooses a name, the next click on a place puts it there; a name not on the list joins it then);
-- the view "Vorlagen" (the saved templates: load, save under a name, delete); "Mehr": the groups of
-- the raid, clear the groups, the night as the block to copy (the view "export").
-- F-165 (D-95): the view "Rollen" (the link "Rollen" in the head row; Raid/LineupRoles.lua): main tanks, assistants and master looters as
-- lists of names with their switches, the loot threshold, "Automatisch setzen"; "Rollen jetzt setzen".
local ADDON, ns = ...
ns.Load(function()
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
                     { "online", 352, 48 }, { "id", 402, 20 }, { "act", 424, 166 } }
local ACT_X, MAX_CHIPS, CHIP_MAX_W = 424, 3, 90
local ALT_TEXT_MAX = 90    -- the alt's text before its chip "tauschen"
-- the calendar view: one row per guild event
local CAL_ROWS, CAL_ROW_H = 15, 22
local CAL_COLS = { { "when", 6, 120 }, { "title", 130, 230 }, { "kind", 364, 90 }, { "own", 458, 130 } }
-- the invite view: one row per placed player, then the raiders who are not on the list
local INV_ROWS, INV_ROW_H = 15, 22
local INV_COLS = { { "g", 6, 20, justify = "RIGHT" }, { "r", 34, 32 }, { "name", 70, 162 }, { "st", 236, 138 },
                   { "tries", 378, 54, justify = "RIGHT" }, { "act", 440, 150 } }
local INV_ACT_X, INV_CHIP_MAX = 440, 140
-- the player list of the planner (F-161): a row of filters, then the names in four columns
local GRID_COLS, GRID_ROWS, GRID_ROW_H, GRID_GAP, GRID_BAR_H = 4, 5, 20, 6, 24
local GRID_W = RIGHT_X + RIGHT_W
local CELL_W = math.floor((GRID_W - (GRID_COLS - 1) * GRID_GAP) / GRID_COLS)
local GRID_INFO_W = 22
-- the view "Vorlagen": one row per template
local SET_ROWS, SET_ROW_H, SET_NAME_W = 15, 22, 170
-- the view "Rollen": the label before each field, the field, the threshold picker
local ROLE_LABEL_W, ROLE_EDIT_W, ROLE_PICK_W = 168, 250, 130
local SET_COLS = { { "name", 6, 220 }, { "size", 230, 50, justify = "RIGHT" }, { "count", 290, 60, justify = "RIGHT" },
                   { "at", 366, 80 }, { "by", 450, 140 } }
local RELOAD_GAP = 5       -- the calendar is read again at most this often while the page is open
local POLL = 30            -- and every this many seconds (the client does not tell every change)

local page
local view = "match"      -- "match", "planner", "invite", "roles", "paste", "calendar", "sets" or "export"
local night               -- the night shown (nil: tonight)
-- the entry a click chose (swap and move), by its lower-case name: a list index would point at
-- another player once the list changes between the two clicks (a sync, a sign-up, a removal)
local selName
local calList             -- the guild events of the calendar view (ns.Cal.Events()), nil while read
local calPick             -- the id (else the index) of the event chosen in the calendar view
-- a name of the player list that is chosen but not on the list yet: { n, c }; selName is its
-- lower-case name meanwhile
local pending
-- the player list: shown instead of the two lists, its source ("raid" or "guild") and filters
local grid = { on = false, src = "guild", online = true, class = "all", search = "", byClass = false }
local setPick             -- the template chosen in the view "Vorlagen" (its lower-case name)
local exportText          -- the block of the view "export"

local function curNight() return night or ns.LineupTonight() end

-- The lower-case name of entry i of the shown night, or nil.
local function nameAt(i)
    local n = ns.LineupNight(curNight(), false)
    local e = n and n.list[i]
    return e and e.n:lower() or nil
end

-- The current index of the chosen entry, or nil when it is gone.
local function selIndex()
    if not selName then return nil end
    local n = ns.LineupNight(curNight(), false)
    for i, e in ipairs(n and n.list or {}) do
        if e.n:lower() == selName then return i end
    end
    return nil
end

-- The chosen name as an entry: a name of the player list joins the list now. Its index, or nil.
local function selEntry()
    local cur = selIndex()
    if cur or not pending then return cur end
    local i, why = ns.LineupAdd(curNight(), pending.n, pending.c)
    pending = nil
    if not i then
        selName = nil
        if why then ns.msg(why) end
    end
    return i
end

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
    return ns.ClassColored(name, class)
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
-- the invite status of part C (Raid/LineupInvite.lua)
local INVITE = {
    P = "|cffd8d8d8" .. L["geplant"] .. "|r", I = YELLOW .. L["eingeladen"] .. "|r", R = GREEN .. L["im Raid"] .. "|r",
    D = RED .. L["abgelehnt"] .. "|r", N = ORANGE .. L["keine Antwort"] .. "|r", G = ORANGE .. L["schon in Gruppe"] .. "|r",
    O = GREY .. L["offline"] .. "|r", U = RED .. L["unbekannt"] .. "|r",
}
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

---------------------------------------------------------------------------
-- Clicks: choose, swap, move; the right-click menu
---------------------------------------------------------------------------
local function say(ok, why) if not ok and why then ns.msg(why) end end

-- target: { i = entry } or { g = group } (a free place) or { to = "open" / "bench" } (a list head)
local function act(from, target)
    selName, pending = nil, nil
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
    local cur = selIndex()
    if not cur and pending then
        -- a name of the player list: it joins the list with this click on a place
        cur = selEntry()
        if not cur then
            ns.Refresh()
            return
        end
    end
    if target.i then
        if not cur then
            selName = nameAt(target.i)
        elseif cur == target.i then
            selName = nil
        else
            act(cur, target)
            return
        end
        ns.Refresh()
    elseif cur then
        act(cur, target)
    elseif selName then
        -- the chosen entry left the list meanwhile
        selName = nil
        ns.Refresh()
    end
end

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
        selName = nil
        ns.LineupRemove(key, i)
    end }
    return W.Menu(owner, entries)
end

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
    -- the raid ID of the chosen instance (F-099)
    local m = page and page.raidId
    if m and ns.RaidIDOf then
        local state, x = ns.RaidIDOf(e.n, m)
        local where = ns.RaidIDsName(m)
        if state == "locked" then
            GameTooltip:AddLine(L["Raid-ID %s: gesperrt (%s)"]:format(where, ns.RaidIDText(x)), 0.88, 0.34, 0.29, true)
        elseif state == "free" then
            GameTooltip:AddLine(L["Raid-ID %s: frei"]:format(where), 0.4, 0.85, 0.5, true)
        else
            GameTooltip:AddLine(L["Raid-ID %s: unbekannt"]:format(where), 0.6, 0.6, 0.6, true)
        end
        local alts = ns.RaidIDFreeAlts(e.n, m)
        if #alts > 0 then GameTooltip:AddLine(L["Freie Twinks: %s"]:format(table.concat(alts, ", ")), 1, 1, 1, true) end
    end
    if e.m then GameTooltip:AddLine(L["Vielleicht"], 0.85, 0.85, 0.85) end
    if e.v then GameTooltip:AddLine(L["Überzählig: kein Platz mehr frei."], 0.85, 0.85, 0.85, true) end
    if view == "planner" then GameTooltip:AddLine(L["Klick: wählen. Rechtsklick: Rolle, Ersatz, Festhalten, Entfernen."], 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

-- Every frame a drag may end on, with its target.
local dropTargets = {}
local function dragStop()
    local from, new = page and page.drag, page and page.dragNew
    if page then page.drag, page.dragNew = nil, nil end
    if not from and not new then return end
    for _, d in ipairs(dropTargets) do
        local f = d.frame
        if f:IsVisible() and f:IsMouseOver() then
            local target = d.target(f)
            if target and not from then
                -- a name of the player list joins the list where it is dropped
                local why
                from, why = ns.LineupAdd(curNight(), new.n, new.c)
                if not from and why then ns.msg(why) end
            end
            if target and from and target.i ~= from then act(from, target) end
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
    -- a night without a list: the groups of the raid size set
    local G = n and ns.LineupGroups(n) or math.floor((tonumber(ns.Get("lineup.size")) or 40) / 5)
    local members = {}
    for g = 1, 8 do members[g] = {} end
    for i, e in ipairs(n and n.list or {}) do
        if e.g and members[e.g] then table.insert(members[e.g], i) end
    end
    local noHeal = {}
    for _, g in ipairs(counts.noHealer) do noHeal[g] = true end
    local sel = selIndex()
    for g, box in ipairs(f.groups) do
        box:SetShown(g <= G)
        box.count:SetText(("%d/5"):format(#members[g]))
        for _, edge in ipairs(box.alarm) do edge:SetShown(noHeal[g] == true) end
        for s, b in ipairs(box.slots) do
            local i = members[g][s]
            local e = i and n and n.list[i]
            b.entry = i
            if e then
                local p = f.people[e.n:lower()]
                b.role:SetText(roleText(e))
                b.name:SetText(classColored(e.n, e.c, p ~= nil and not p.online, e.x))
                b.lock:SetShown(e.k == true)
            else
                b.role:SetText("")
                b.name:SetText(GREY .. L["frei##Platz"] .. "|r")
                b.lock:Hide()
            end
            b.sel:SetShown(i ~= nil and i == sel)
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
    row.sel:SetShown(selName ~= nil and it.i == selIndex())
end

-- the heads of the two lists take a chosen name: "Nicht eingeteilt" and "Ersatz"
local function sideHeads(f, top)
    local fa, a = f:Columns({ { "a", 6, LEFT_W - 12, "" } }, { top = top, x = 0, width = LEFT_W, sort = function()
        local cur = selEntry()
        if cur then act(cur, { to = "open" }) end
    end })
    local fb, b = f:Columns({ { "b", 6, RIGHT_W - 12, "" } }, { top = top, x = RIGHT_X, width = RIGHT_W, sort = function()
        local cur = selEntry()
        if cur then act(cur, { to = "bench" }) end
    end })
    f.sideHeads = { fa, fb }
    -- with sort the heads are buttons; their labels carry the text
    f.openHead, f.benchHead = a.a.label, b.b.label
    f.openBtn, f.benchBtn = a.a, b.b
    for _, h in ipairs({ { a.a, "open" }, { b.b, "bench" } }) do
        dropTargets[#dropTargets + 1] = { frame = h[1], target = function() return { to = h[2] } end }
    end
    return top - T.LAYOUT.COLHEAD_H
end

---------------------------------------------------------------------------
-- The player list of the planner (F-161)
---------------------------------------------------------------------------
local function className(token)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return type(names) == "table" and type(names[token]) == "string" and names[token] or token
end

-- The players of the chosen source that pass the filters, by name (with "nach Klasse", F-194: by the
-- class's name first, players without a known class last): { name, low, class, online,
-- i = the index on the night's list (nil: not on it) }.
local function gridPlayers(list)
    local index = {}
    for i, e in ipairs(list or {}) do index[e.n:lower()] = i end
    local rows = {}
    if grid.src == "raid" then
        for _, r in ipairs(ns.LineupRaidRows()) do rows[#rows + 1] = { name = r.name, class = r.class, online = r.online } end
    else
        for _, m in ipairs(ns.GuildRoster and ns.GuildRoster() or {}) do
            local name = ns.FullName(m.name)
            if name then rows[#rows + 1] = { name = name, class = m.class ~= "" and m.class or nil, online = m.online and true or false } end
        end
    end
    local want = ns.Fold(grid.search or "")
    local out, classes = {}, {}
    for _, p in ipairs(rows) do
        if p.class then classes[p.class] = true end
        if (not grid.online or p.online) and (grid.class == "all" or p.class == grid.class)
            and (want == "" or ns.Fold(p.name):find(want, 1, true)) then
            p.low = p.name:lower()
            p.i = index[p.low]
            out[#out + 1] = p
        end
    end
    for _, p in ipairs(out) do
        p.key = ns.Fold(p.name)
        p.classKey = p.class and ns.Fold(className(p.class)) or nil
    end
    table.sort(out, function(a, b)
        if grid.byClass and a.classKey ~= b.classKey then
            if not a.classKey or not b.classKey then return b.classKey == nil end
            return a.classKey < b.classKey
        end
        return a.key < b.key
    end)
    return out, classes
end

local function gridClick(self, button)
    local p = self.p
    if not p then return end
    if button == "RightButton" then
        if p.i then menuFor(self, p.i) end
        return
    end
    if p.i then
        -- on the list: as a name of the planner (choose, or swap with the chosen one)
        if pending then selName, pending = nil, nil end
        click({ i = p.i })
        return
    end
    if pending and selName == p.low then
        selName, pending = nil, nil
    else
        selName, pending = p.low, { n = p.name, c = p.class }
    end
    ns.Refresh()
end

local function gridTooltip(self)
    local p = self.p
    if not p or not page then return end
    if p.i then return tooltip(self, page.list and page.list[p.i]) end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(p.name, 1, 0.82, 0)
    local bits = {}
    if p.class then bits[#bits + 1] = className(p.class) end
    bits[#bits + 1] = p.online and (GREEN .. L["online"] .. "|r") or (GREY .. L["offline"] .. "|r")
    GameTooltip:AddLine(table.concat(bits, " · "), 0.85, 0.85, 0.85)
    GameTooltip:AddLine(L["Klick: wählen, dann auf einen Platz klicken (Ziehen geht auch)."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function buildGridRow(row)
    -- the cells take the mouse, not the row
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.cells = {}
    for c = 1, GRID_COLS do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(CELL_W, GRID_ROW_H - 1)
        b:SetPoint("LEFT", (c - 1) * (CELL_W + GRID_GAP), 0)
        b.hover = b:CreateTexture(nil, "HIGHLIGHT")
        b.hover:SetAllPoints()
        b.hover:SetColorTexture(1, 1, 1, 0.08)
        b.sel = W.SelectBar(b)
        b.name = W.Text(b, T.FONT.text, CELL_W - GRID_INFO_W - 8)
        b.name:SetPoint("LEFT", 4, 0)
        b.info = W.Text(b, T.FONT.hint, GRID_INFO_W)
        b.info:SetPoint("RIGHT", -3, 0)
        b.info:SetJustifyH("RIGHT")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick", gridClick)
        b:SetScript("OnDragStart", function(self)
            local p = self.p
            if not p or not page then return end
            if p.i then page.drag = p.i else page.dragNew = { n = p.name, c = p.class } end
        end)
        b:SetScript("OnDragStop", dragStop)
        b:SetScript("OnEnter", gridTooltip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.cells[c] = b
    end
end

-- item: up to four players of one row
local function fillGridRow(row, item)
    for c, b in ipairs(row.cells) do
        local p = item[c]
        b.p = p
        if p then
            local e = p.i and page.list and page.list[p.i]
            local where = e and (e.g and tostring(e.g) or ((e.b or e.v) and L["E##Ersatz"]) or nil)
            -- grey: placed already (its group beside it), or offline
            b.name:SetText(classColored(p.name, p.class, where ~= nil or not p.online))
            b.info:SetText(where or (e and (GREY .. "+|r")) or "")
            b.sel:SetShown(selName ~= nil and selName == p.low)
            b:Show()
        else
            b:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- The view "Vorlagen" (F-161)
---------------------------------------------------------------------------
local function setChosen()
    for _, s in ipairs(ns.LineupSets()) do
        if s.name:lower() == setPick then return s end
    end
    return nil
end

-- "Stamm: 38 eingeteilt, 2 neu in der Liste." and what was left out
local function planLine(head, placed, added, over, absent)
    local parts = { L["%d eingeteilt"]:format(placed) }
    if added > 0 then parts[#parts + 1] = L["%d neu in der Liste"]:format(added) end
    if absent > 0 then parts[#parts + 1] = L["%d abgemeldet (nicht eingeteilt)"]:format(absent) end
    if over > 0 then parts[#parts + 1] = L["%d ohne Platz in der Liste"]:format(over) end
    return head .. ": " .. table.concat(parts, ", ") .. "."
end

-- Runs fn at once on a night without groups, else after a question: the groups are replaced.
local function overGroups(title, fn)
    if ns.LineupCounts(curNight()).placed == 0 then return fn() end
    W.Confirm(title, L["Die Gruppen dieser Nacht werden ersetzt. Die Liste, die Anmeldungen und der Ersatz bleiben."], L["Ersetzen"], fn)
end

local function loadSet()
    local s = setChosen()
    if not s then return end
    overGroups(L["Vorlage laden"], function()
        local placed, added, over, absent = ns.LineupLoadSet(s.name, curNight())
        if not placed then
            ns.msg(added)
            return
        end
        ns.msg(planLine(L["Vorlage %s"]:format(s.name), placed, added, over, absent))
        view, selName, pending = "planner", nil, nil
        ns.Refresh()
    end)
end

local function fromRaid()
    overGroups(L["Aus dem Raid übernehmen"], function()
        local placed, added, over, absent = ns.LineupFromRaid(curNight())
        if not placed then
            ns.msg(added)
            return
        end
        ns.msg(planLine(L["Aus dem Raid"], placed, added, over, absent))
        view, selName, pending = "planner", nil, nil
        ns.Refresh()
    end)
end

local function buildSet(row)
    W.Cells(row, SET_COLS)
    row.size:SetJustifyH("RIGHT")
    row.count:SetJustifyH("RIGHT")
    row.sel = W.SelectBar(row)
    row:SetScript("OnClick", function(self)
        if self.item then
            setPick = self.item.name:lower()
            -- the name in the field: "Speichern" replaces this template
            if page then page.setName:SetText(self.item.name) end
            ns.Refresh()
        end
    end)
    row:SetScript("OnDoubleClick", function(self)
        if self.item then
            setPick = self.item.name:lower()
            loadSet()
        end
    end)
end

local function fillSet(row, s)
    row.name:SetText(s.name)
    row.size:SetText(tostring(s.size))
    row.count:SetText(tostring(s.count))
    row.at:SetText(s.at and s.at > 0 and ns.FmtDay(s.at) or "")
    row.by:SetText(s.by or "")
    row.sel:SetShown(s.name:lower() == setPick)
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
        -- a decision of the row as a quiet link (D-67): "Bestätigen" or the right name
        local chip = W.Link(row, "", function(self)
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
            x = x + chip:GetWidth() + T.TAB_GAP
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
    local m = page.raidId
    if m and ns.RaidIDOf then
        local state = ns.RaidIDOf(e.n, m)
        row.id:SetText((state == "locked" and RED or state == "free" and GREEN or GREY) .. L["ID##Raid"] .. "|r")
    else
        row.id:SetText("")
    end
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
        placeChips(row, ACT_X + math.min(ALT_TEXT_MAX, row.act:GetStringWidth() + 6))
    elseif listHint(e) then
        row.act:SetText(listHint(e))
    end
end

---------------------------------------------------------------------------
-- The invite view
---------------------------------------------------------------------------
local function buildInv(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.Cells(row, INV_COLS)
    row.chip = W.Chip(row, L["Einladen"], 70, function(self)
        local it = self:GetParent().item
        if not it or not it.e then return end
        local ok, why = ns.LineupInviteOne(curNight(), it.e.n)
        say(ok, why)
        ns.Refresh()
    end)
    W.RowAction(row, row.chip)   -- shown while the mouse is on the row (D-67)
    row.chip:SetPoint("LEFT", INV_ACT_X, 0)
    row.chip:SetOn(false)
    W.FitChip(row.chip, 70, INV_CHIP_MAX)
    row.chip:Hide()
    wire(row, function(self) return self.item and self.item.i and { i = self.item.i } or nil end, true)
end

-- where an invite not placed on the lineup came from (F-163): "Gilde einladen" or a whisper
local BY_WORD = { guild = L["über Gilde einladen"], inv = L["auf Flüstern"] }

local function fillInv(row, it)
    local e = it.e
    if it.extra then
        -- invited through "Gilde einladen" or a whisper, not placed, not in the group yet (F-163)
        local r = it.extra
        local p = page.people[r.n:lower()]
        row.g:SetText("")
        row.r:SetText("")
        row.name:SetText(classColored(r.n, p and p.class, p ~= nil and not p.online))
        row.st:SetText(INVITE[r.st] or "")
        row.tries:SetText(r.tries > 0 and ("%d/%d"):format(r.tries, ns.LineupInv.MAX_TRIES) or "")
        row.act:SetText(GREY .. (BY_WORD[r.by] or "") .. "|r")
        row.chip:Hide()
        return
    end
    if not e then
        -- in the raid, not on the list: stays where it is; invited by Amisia: says how (F-163)
        local by = it.by and BY_WORD[it.by]
        row.g:SetText(it.sub and tostring(it.sub) or "")
        row.r:SetText("")
        row.name:SetText(GREY .. it.name .. "|r")
        row.st:SetText(by and INVITE.R or (GREY .. L["nicht angemeldet"] .. "|r"))
        row.tries:SetText("")
        row.act:SetText(by and (GREY .. by .. "|r") or "")
        row.chip:Hide()
        return
    end
    local p = page.people[e.n:lower()]
    local r = it.rec or { st = "P", tries = 0 }
    row.g:SetText(tostring(e.g or ""))
    row.r:SetText(roleText(e))
    row.name:SetText(classColored(e.n, e.c, p ~= nil and not p.online, e.x))
    local st = INVITE[r.st] or ""
    if r.back then st = st .. GREY .. L[", jetzt online"] .. "|r" end
    row.st:SetText(st)
    row.tries:SetText(r.tries > 0 and ("%d/%d"):format(r.tries, ns.LineupInv.MAX_TRIES) or "")
    row.act:SetText("")
    local can = not page.invBlocked and r.tries < ns.LineupInv.MAX_TRIES and (r.st == "P" or r.st == "D" or r.st == "N"
        or r.st == "G" or (r.st == "U" and not r.unclear)) and (e.x == nil or (e.x == "g" and ns.Get("lineup.guests")))
    row.chip:SetShown(can)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
-- the snapshots: the player list on or off
ns._lineupPlayers = function(on) grid.on = on and true or false end

-- Opens the page (the officers only), in a view when given ("match", "planner", "paste", "invite",
-- "sets", "export").
function ns.ShowLineup(which, key)
    if which == "match" or which == "planner" or which == "paste" or which == "invite" or which == "sets" or which == "roles" then view = which end
    if which == "export" then
        -- the block of the night to copy (nothing to show: the view stays)
        exportText = ns.LineupExport(key or curNight())
        if exportText then view = "export" end
    end
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
            night, selName, view = key, nil, "match"
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
    row.sel:SetShown((ev.id or ev.index) == calPick)
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

local function apply(f)
    local key, line = ns.SetLineupText(f.paste.box:GetText() or "", curNight())
    if not key then
        ns.msg(line)
        return
    end
    night, selName, view = key, nil, "match"
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

---------------------------------------------------------------------------
-- The parts of F-161 (functions of their own: the page's create holds 60 upvalues at most)
---------------------------------------------------------------------------
-- "Vorlagen" and "Mehr" of the head row.
local function buildTools(f)
    -- F-161: the templates, and what else fills or empties the groups
    f.setsBtn = W.Link(f, L["Vorlagen"], function()
        view = view == "sets" and "planner" or "sets"
        ns.Refresh()
    end)
    W.FitChip(f.setsBtn)
    -- F-165: the view "Rollen" (main tanks, assistants, master looter)
    f.rolesLink = W.Link(f, L["Rollen##Aufstellung"], function()
        view = view == "roles" and "match" or "roles"
        ns.Refresh()
    end)
    W.FitChip(f.rolesLink)
    W.Tooltip(f.rolesLink, L["Rollen##Aufstellung"], L["Haupttanks, Assistenten und Plündermeister nach Namenslisten im Raid setzen (als Raidleiter)."])
    W.Tooltip(f.setsBtn, L["Vorlagen"], L["Gespeicherte Aufstellungen: die Gruppen einer Nacht unter einem Namen ablegen und an einem anderen Abend wieder laden."])
    f.moreBtn = W.Link(f, L["Mehr"], function(self)
        local c = ns.LineupCounts(curNight())
        local inRaid = #ns.LineupRaidRows() > 0
        W.Menu(self, {
            { L["Aus dem Raid übernehmen"], inRaid and fromRaid or nil,
              tip = L["Setzt jeden Raider in die Gruppe, in der er im Raid steht. Wer in der Liste fehlt, kommt dazu. Im Spiel ändert das nichts."] },
            { L["Gruppen leeren"], (c.placed + c.bench > 0) and function()
                W.Confirm(L["Gruppen leeren"], L["Alle aus den Gruppen und vom Ersatz nehmen? Die Liste bleibt."], L["Leeren"], function()
                    local key = curNight()
                    ns.msg(L["Gruppen geleert: %d Spieler stehen jetzt unter \"Nicht eingeteilt\"."]:format(ns.LineupClear(key)))
                    selName, pending = nil, nil
                    ns.Refresh()
                end)
            end or nil },
            { L["Als Text exportieren"], (#(f.list or {}) > 0) and function()
                ns.ShowLineup("export")
                if view ~= "export" then return end
                f.export.box:SetFocus()
                f.export.box:HighlightText()
            end or nil,
              tip = L["Die Aufstellung dieser Nacht als Block zum Kopieren. Ein anderer Offizier fügt ihn unter \"Einfügen\" ein und hat dieselben Gruppen."] },
        }, { width = T.LINEUP_MORE_W })
    end)
    W.FitChip(f.moreBtn)
end

-- The planner's "Spieler"; the name field and the buttons of the view "Vorlagen".
local function buildSetTools(f)
    -- F-161: the planner's player list; the view "Vorlagen"
    f.gridBtn = W.TabCheck(f, L["Spieler"], function()
        grid.on = not grid.on
        if not grid.on and pending then selName, pending = nil, nil end
        ns.Refresh()
    end)
    W.FitChip(f.gridBtn)
    W.Tooltip(f.gridBtn, L["Spieler"], L["Zeigt statt \"Nicht eingeteilt\" und \"Ersatz\" die Spieler aus Raid oder Gilde. Ein Klick wählt einen Namen, der nächste Klick auf einen Platz setzt ihn dorthin."])
    f.setName = W.LineEdit(f, SET_NAME_W)
    f.setSave = W.Link(f, L["Speichern"], function()
        local name = f.setName:GetText() or ""
        local count, why = ns.LineupSaveSet(curNight(), name)
        if not count then
            ns.msg(why)
            return
        end
        name = name:match("^%s*(.-)%s*$")
        setPick = name:lower()
        f.setName:ClearFocus()
        ns.msg(L["Vorlage %s gespeichert: %d Spieler."]:format(name, count))
        ns.Refresh()
    end)
    W.Tooltip(f.setSave, L["Speichern"], L["Legt die Gruppen der gezeigten Nacht unter dem Namen im Feld ab. Derselbe Name ersetzt die alte Vorlage."])
    f.setLoad = W.Button(f, L["Laden##Vorlage"], 110, loadSet)
    W.Tooltip(f.setLoad, L["Laden##Vorlage"], L["Setzt die gewählte Vorlage in die gezeigte Nacht: wer darin steht, bekommt ihre Gruppe; wer in der Liste fehlt, kommt dazu. Anmeldungen und Ersatz bleiben."])
    f.setDelete = W.Link(f, L["Löschen##Vorlage"], function()
        local s = setChosen()
        if not s then return end
        W.Confirm(L["Vorlage löschen"], L["Die Vorlage \"%s\" löschen?"]:format(s.name), L["Löschen##Vorlage"], function()
            ns.LineupDeleteSet(s.name)
            setPick = nil
            ns.Refresh()
        end)
    end)
    for _, b in ipairs({ f.setSave, f.setLoad, f.setDelete }) do W.FitChip(b, 80) end
end

-- "Gilde einladen" (F-163, D-93): the rank picker and the link of the view "Einladen".
local function guildInviteAsk()
    local key = curNight()
    local rank = ns.Get("lineup.inviteRank")
    local items, why = ns.LineupGuildTargets(key, rank)
    if not items then return ns.msg(why) end
    if #items == 0 then return ns.msg(L["Gilde einladen: niemand bis %s ist online und nicht in der Gruppe."]:format(ns.LineupRankText(rank))) end
    W.Confirm(L["Gilde einladen"], L["%d Gildenmitglieder bis Rang %s einladen? Sie bekommen eine Einladung nach der anderen, wie bei \"Alle einladen\"."]:format(
        #items, ns.LineupRankText(rank)), L["Einladen"], function()
        local count, err = ns.LineupInviteGuild(key, rank)
        if count then ns.msg(L["Gilde einladen: %d Spieler, einer alle %s Sekunden."]:format(count, ns.Num(ns.LineupInv.GAP, 1))) else say(nil, err) end
        ns.Refresh()
    end)
end

local function buildGuildInvite(f)
    f.guildRank = W.Picker(f, 110, function(v)
        ns.Set("lineup.inviteRank", v)
        ns.Refresh()
    end)
    W.Tooltip(f.guildRank, L["Gilde einladen"], L["Bis zu welchem Rang \"Gilde einladen\" einlädt: dieser Rang und alle höheren."])
    f.guildInv = W.Link(f, L["Gilde einladen"], guildInviteAsk)
    W.FitChip(f.guildInv)
    W.Tooltip(f.guildInv, L["Gilde einladen"], L["Lädt alle Gildenmitglieder bis zum gewählten Rang ein, die online und noch nicht in der Gruppe sind, nach einer Nachfrage. Wie \"Alle einladen\": einer alle 0,5 Sekunden, nach dem ersten Beitritt wird es ein Raid, höchstens 3 Einladungen pro Name und Abend. Geht auch ohne Aufstellung."])
end

-- The rank picker's values and the link's state (refresh of the view "Einladen").
local function fillGuildInvite(f, shown, blocked)
    local ranks = shown and ns.RankList() or nil
    local values = {}
    for _, r in ipairs(ranks or {}) do
        values[#values + 1] = { value = r.rank, text = L["bis %s"]:format(r.name) }
    end
    f.guildRank:SetShown(#values > 0)
    f.guildInv:SetShown(shown)
    if #values > 0 then
        f.guildRank:SetValues(values)
        f.guildRank:SetValue(math.min(ns.Get("lineup.inviteRank"), #values))
    end
    f.guildInv:SetEnabled(shown and not blocked and not ns.LineupInviteRunning() and #values > 0)
end

-- The player list under the groups, the view "Vorlagen" and the block to copy.
local function buildGridAndSets(f, top, sideTop)
    -- the player list in the place of the two lists (F-161): its filters, then the names
    local P = f.plan
    P.srcRaid = W.Tab(P, L["Raid##Spielerliste"], function() grid.src = "raid" ns.Refresh() end)
    P.srcGuild = W.Tab(P, L["Gilde"], function() grid.src = "guild" ns.Refresh() end)
    P.online = W.TabCheck(P, L["nur online"], function() grid.online = not grid.online ns.Refresh() end)
    -- F-194: the names grouped by class, by name within a class
    P.byClass = W.TabCheck(P, L["nach Klasse"], function() grid.byClass = not grid.byClass ns.Refresh() end)
    W.Tooltip(P.byClass, L["nach Klasse"], L["Sortiert die Spieler nach Klasse, innerhalb einer Klasse nach Namen. Aus: nur nach Namen."])
    for _, b in ipairs({ P.srcRaid, P.srcGuild, P.online, P.byClass }) do W.FitChip(b) end
    P.classPick = W.Picker(P, 130, function(v)
        grid.class = v
        ns.Refresh()
    end)
    P.search = W.SearchBox(P, 140, function(text)
        grid.search = (text or ""):match("^%s*(.-)%s*$")
        ns.Refresh()
    end)
    W.Row(P, { P.srcRaid, P.srcGuild, P.online, P.byClass }, T.TAB_GAP, T.LAYOUT.TEXT_X, sideTop + T.LAYOUT.COLHEAD_H - 1)
    W.Row(P, { P.classPick, P.search }, T.LAYOUT.ITEM_GAP, GRID_W - 130 - 140 - T.LAYOUT.ITEM_GAP, sideTop + T.LAYOUT.COLHEAD_H)
    P.gridBar = { P.srcRaid, P.srcGuild, P.online, P.byClass, P.classPick, P.search }
    f.gridList = P:List(GRID_ROWS, GRID_ROW_H, buildGridRow, fillGridRow,
        { top = sideTop + T.LAYOUT.COLHEAD_H - GRID_BAR_H, x = 0, width = GRID_W })
    P.gridEmpty = W.Text(P, T.FONT.hint, GRID_W - 12)
    P.gridEmpty:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X, sideTop + T.LAYOUT.COLHEAD_H - GRID_BAR_H - 6)
    -- the view "Vorlagen"
    f.sets = W.Page(f, { view = true, top = top })
    local _, sheads = f.sets:Columns(SET_COLS)
    sheads.name:SetText(L["Vorlage"])
    sheads.size:SetText(L["Größe##Raid"])
    sheads.count:SetText(L["Spieler"])
    sheads.at:SetText(L["Gespeichert"])
    sheads.by:SetText(L["Von##Offizier"])
    f.setRows = f.sets:List(SET_ROWS, SET_ROW_H, buildSet, fillSet)
    -- the block to copy
    f.export = W.ReadOnlyArea(f, function() return exportText or "" end)
    f.export:SetPoint("TOPLEFT", 0, top)
    f.export:SetPoint("BOTTOMRIGHT", 0, f:Bottom())
end

-- The view "Rollen" (F-165, D-95, Raid/LineupRoles.lua): per list its switch, its name, the field
-- and its grey line; "Aus dem Planer" beside the main tanks, the threshold beside the master looters;
-- the automatic switch; the red "Rollen jetzt setzen" sits in the views' band.
local ROLE_BLOCKS = {
    { "tanks", L["Haupttanks, in Reihenfolge"], L["Die Haupttanks des Raids, in dieser Reihenfolge gesetzt. Namen mit Komma getrennt, höchstens 10."] },
    { "assist", L["Assistenten"], L["Wer im Raid Assistent wird. Namen mit Komma getrennt, höchstens 10."] },
    { "ml", L["Plündermeister"], L["Der Erste dieser Liste, der im Raid ist, wird Plündermeister (Plündermethode Plündermeister). Namen mit Komma getrennt, höchstens 10."] },
}

local function buildRoles(f, top)
    local RO = ns.LineupRoles
    local RV = W.Page(f, { view = true, top = top })
    f.roles = RV
    RV:Bands({ "line", "row", "line", "row", "line", "row", "line", "row" })
    RV.intro = RV:Line(1)
    RV.intro:SetText(L["Setzt die Rollen im Raid, solange du Raidleiter bist. Namen mit Komma getrennt."])
    RV.blocks = {}
    for k, def in ipairs(ROLE_BLOCKS) do
        local key, label = def[1], def[2]
        local b = {}
        b.on = W.Toggle(RV, function(on)
            RO.SetOn(key, on)
            ns.Refresh()
        end)
        W.Tooltip(b.on, label, L["An: \"Rollen jetzt setzen\" und das automatische Setzen nehmen diese Liste mit."])
        b.label = W.Text(RV, T.FONT.text, ROLE_LABEL_W)
        b.label:SetText(label)
        b.edit = W.LineEdit(RV, ROLE_EDIT_W, function(text)
            local count, dropped = RO.SetList(key, text)
            if dropped > 0 then
                ns.msg(L["%s: %d Namen, %d weggelassen (kein Name, doppelt oder mehr als %d)."]:format(label, count, dropped, RO.MAX))
            end
            ns.Refresh()
        end)
        W.Tooltip(b.edit, label, def[3])
        b.status = RV:Line(2 * k + 1)
        RV.blocks[key] = b
    end
    local tanks, assist, ml = RV.blocks.tanks, RV.blocks.assist, RV.blocks.ml
    tanks.planner = W.Link(RV, L["Aus dem Planer"], function()
        local count, why = RO.FromPlanner(curNight())
        ns.msg(count and L["Haupttanks aus dem Planer: %s."]:format(RO.ListText("tanks")) or why)
        ns.Refresh()
    end)
    W.FitChip(tanks.planner)
    W.Tooltip(tanks.planner, L["Aus dem Planer"], L["Füllt das Feld mit den Tanks der gezeigten Nacht, die im Planer in einer Gruppe stehen, nach Gruppe geordnet."])
    ml.quality = W.Picker(RV, ROLE_PICK_W, function(v)
        RO.SetQuality(v)
        ns.Refresh()
    end)
    W.Tooltip(ml.quality, L["Plündergrenze"], L["Ab dieser Qualität verteilt der Plündermeister; darunter würfelt die Gruppe wie gewohnt."])
    RV.auto = W.Toggle(RV, function(on)
        RO.SetAuto(on)
        ns.Refresh()
    end)
    RV.autoLabel = W.Text(RV, T.FONT.text, 360)
    RV.autoLabel:SetText(L["Automatisch setzen, wenn jemand beitritt"])
    W.Tooltip(RV.auto, L["Automatisch setzen, wenn jemand beitritt"], L["Als Raidleiter setzt Amisia die Rollen für jeden, der beitritt, 2 Sekunden nach der Änderung, einmal pro Name und Raid, nicht im Kampf. Eine Zeile im Chat nur, wenn es etwas gesetzt hat."])
    RV:Place(2, { tanks.on, tanks.label, tanks.edit, tanks.planner })
    RV:Place(4, { assist.on, assist.label, assist.edit })
    RV:Place(6, { ml.on, ml.label, ml.edit, ml.quality })
    RV:Place(8, { RV.auto, RV.autoLabel })
    f.rolesBtn = W.Button(f, L["Rollen jetzt setzen"], 160, function()
        -- a field still being typed in counts as it stands
        for key, b in pairs(RV.blocks) do
            if b.edit:HasFocus() then
                RO.SetList(key, b.edit:GetText())
                b.edit:ClearFocus()
            end
        end
        local ok, why = ns.LineupRolesSet()
        if not ok then say(nil, why) end
        ns.Refresh()
    end)
    W.Tooltip(f.rolesBtn, L["Rollen jetzt setzen"], L["Befördert die Assistenten, setzt die Haupttanks und den Plündermeister der Listen, die im Raid sind. Nimmt niemandem etwas weg. Nur als Raidleiter, nicht im Kampf."])
end

-- The view "Rollen" on a refresh: the switches, the fields (not while one is typed in), the grey
-- lines, the button with the reason when it may not.
local function fillRoles(f, shown)
    f.roles:SetShown(shown)
    f.rolesBtn:SetShown(shown)
    if not shown then return end
    local RO = ns.LineupRoles
    local cfg = RO.Get()
    for key, b in pairs(f.roles.blocks) do
        b.on:SetChecked(cfg[key].on)
        if not b.edit:HasFocus() then b.edit:SetText(RO.ListText(key)) end
        b.status:SetText(GREY .. RO.Status(key) .. "|r")
    end
    local values = {}
    for _, q in ipairs(RO.QUALITIES) do values[#values + 1] = { value = q, text = RO.QUALITY_NAME[q] } end
    f.roles.blocks.ml.quality:SetValues(values)
    f.roles.blocks.ml.quality:SetValue(cfg.q)
    f.roles.auto:SetChecked(cfg.auto)
    local _, why = RO.Blocked()
    f.rolesBtn:SetText(why or L["Rollen jetzt setzen"])
    f.rolesBtn:SetEnabled(not why and RO.HasWork())
    W.FitChip(f.rolesBtn, 100)
end

ns.RegisterPanel{ key = "lineup", label = L["Aufstellung"], sub = L["Wer zum Raid kommt, wer fehlt und wer eingeladen wird."], icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", order = 12, group = "raid",
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
            night, selName = v, nil
            ns.Refresh()
        end)
        f.pasteBtn = W.Link(f, L["Einfügen"], function()
            view = view == "paste" and "match" or "paste"
            ns.Refresh()
            if view == "paste" then f.paste.box:SetFocus() else f.paste.box:ClearFocus() end
        end)
        f.calBtn = W.Link(f, L["Aus Kalender"], function()
            if view == "calendar" then
                view = "match"
                ns.Refresh()
            else
                ns.LineupShowCalendar()
            end
        end)
        W.FitChip(f.calBtn)
        W.Tooltip(f.calBtn, L["Aus Kalender"], L["Die Gildenereignisse der nächsten 14 Tage aus dem Spielkalender. \"Übernehmen\" liest die Teilnehmerliste in die Aufstellung der Nacht (Amisia schreibt nichts in den Kalender)."])
        f.auto = W.Link(f, L["Automatisch einteilen"], function()
            local placed, over = ns.LineupAutoAssign(curNight())
            selName, view = nil, "planner"
            local n = ns.LineupNight(curNight(), false)
            ns.msg(L["Eingeteilt: %d in %d Gruppen, %d auf Ersatz (überzählig)."]:format(placed, n and ns.LineupGroups(n) or 0, over))
            ns.Refresh()
        end)
        W.FitChip(f.pasteBtn)
        W.FitChip(f.auto)
        W.Tooltip(f.auto, L["Automatisch einteilen"], L["Tanks ab Gruppe 1, ein Heiler pro Gruppe, Nahkampf zusammen mit einem Schamanen oder Krieger, Fernkampf zusammen. Festgehaltene bleiben stehen."])
        buildTools(f)
        f:Place(1, { f.night }, { f.rolesLink, f.setsBtn, f.calBtn, f.pasteBtn, f.moreBtn, f.auto })
        f.counts = f:Line(2)
        f.calLine = f:Line(3)
        f.views = {
            match = W.Tab(f, L["Abgleich"], function() view, selName = "match", nil ns.Refresh() end),
            planner = W.Tab(f, L["Planer"], function() view = "planner" ns.Refresh() end),
            invite = W.Tab(f, L["Einladen"], function() view, selName = "invite", nil ns.Refresh() end),
        }
        for _, c in pairs(f.views) do W.FitChip(c) end
        -- the instance of the "ID" marks (raid IDs, F-099); shown when any ID is known
        f.raidIdPick = W.Picker(f, 150, function(v)
            if ns.RaidIDsChoose then ns.RaidIDsChoose(v ~= 0 and v or nil) end
            f.raidIdOff = v == 0
            ns.Refresh()
        end)
        W.Tooltip(f.raidIdPick, L["Raid-ID"], L["Für diese Instanz trägt jeder Name ein \"ID\": grün frei, rot gesperrt, grau unbekannt. Der Tooltip nennt Bosse, Reset und die freien Twinks."])
        f.rematch = W.Link(f, L["Neu abgleichen"], function()
            local line = ns.LineupRematch(curNight())
            if line then ns.msg(line) end
        end)
        f.bench = W.Link(f, L["Ersatz auf die Ersatzbank"], function()
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
        f.cancel = W.Link(f, L["Abbrechen"], function()
            view = "match"
            f.paste.box:ClearFocus()
            ns.Refresh()
        end)
        -- part C: invite; part D: sort (the planner)
        f.inviteAll = W.Button(f, L["Alle einladen"], 120, function()
            local count, why = ns.LineupInviteAll(curNight())
            if count then ns.msg(L["Einladen: %d Spieler, einer alle %s Sekunden."]:format(count, ns.Num(ns.LineupInv.GAP, 1))) else say(nil, why) end
            ns.Refresh()
        end)
        W.Tooltip(f.inviteAll, L["Alle einladen"], L["Lädt alle eingeteilten Spieler ein, die online und noch nicht in der Gruppe sind (Gäste nur mit der Einstellung). Allein oder in einer Gruppe erst vier, nach dem ersten Beitritt wird es ein Raid. Nur außerhalb des Kampfes, als Leiter oder Assistent."])
        f.again = W.Link(f, L["Nochmal einladen"], function()
            local count, why = ns.LineupInvite(curNight(), "again")
            if count then ns.msg(L["Nochmal eingeladen: %d Spieler."]:format(count)) else say(nil, why) end
            ns.Refresh()
        end)
        W.Tooltip(f.again, L["Nochmal einladen"], L["Lädt alle mit \"abgelehnt\", \"keine Antwort\" oder \"schon in Gruppe\" noch einmal ein, einmal pro Klick; höchstens 3 Einladungen pro Name und Abend."])
        f.sortBtn = W.Link(f, L["Gruppen sortieren"], function()
            local ok, why = ns.LineupSort(curNight())
            if not ok then say(nil, why) end
            ns.Refresh()
        end)
        W.Tooltip(f.sortBtn, L["Gruppen sortieren"], L["Schiebt jeden Raider in die Gruppe aus dem Planer; wer nicht auf der Liste steht, bleibt. Nur im Raid als Leiter oder Assistent, nicht im Kampf. Sortiert gerade nur dein Client: sprecht euch ab, wer sortiert."])
        buildSetTools(f)
        buildGuildInvite(f)
        f.calTake = W.Button(f, L["Übernehmen"], 110, takeCalendar)
        W.Tooltip(f.calTake, L["Übernehmen"], L["Liest die Teilnehmerliste des gewählten Ereignisses in die Aufstellung seiner Nacht. Bleibt die Seite offen, liest Amisia sie bei Änderungen neu."])
        for _, b in ipairs({ f.rematch, f.bench, f.take, f.cancel, f.calTake, f.inviteAll, f.again, f.sortBtn }) do W.FitChip(b, 100) end
        f:Footer({ { "hint", lines = 2, help = true } })
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
        mheads.id:SetText(L["ID##Raid"])
        f.mlist = f.match:List(MATCH_ROWS, MATCH_ROW_H, buildMatch, fillMatch)
        -- the planner
        f.plan = W.Page(f, { view = true, top = top })
        buildGroups(f.plan, 0)
        local sideTop = sideHeads(f.plan, -(2 * GROUP_H + GROUP_GAP + GROUP_GAP))
        f.openList = f.plan:List(LIST_ROWS, LIST_ROW_H, buildSide, fillSide, { top = sideTop, x = 0, width = LEFT_W })
        f.benchList = f.plan:List(LIST_ROWS, LIST_ROW_H, buildSide, fillSide, { top = sideTop, x = RIGHT_X, width = RIGHT_W })
        f.plan.people = f.people
        f.openHead, f.benchHead = f.plan.openHead, f.plan.benchHead
        buildGridAndSets(f, top, sideTop)
        -- the calendar view
        f.cal = W.Page(f, { view = true, top = top })
        local _, cheads = f.cal:Columns(CAL_COLS)
        cheads.when:SetText(L["Wann"])
        cheads.title:SetText(L["Gildenereignis"])
        cheads.kind:SetText(L["Art"])
        cheads.own:SetText(L["Status"])
        f.calRows = f.cal:List(CAL_ROWS, CAL_ROW_H, buildCal, fillCal)
        -- the invite view
        f.inv = W.Page(f, { view = true, top = top })
        local _, iheads = f.inv:Columns(INV_COLS)
        iheads.g:SetText(L["Gr.##Gruppe"])
        iheads.g:SetJustifyH("RIGHT")
        iheads.r:SetText(L["Rolle"])
        iheads.name:SetText(L["Name##Spalte"])
        iheads.st:SetText(L["Einladung"])
        iheads.tries:SetText(L["Versuche"])
        iheads.tries:SetJustifyH("RIGHT")
        f.invRows = f.inv:List(INV_ROWS, INV_ROW_H, buildInv, fillInv)
        buildRoles(f, top)
        f.empty = f:Empty()
        -- the calendar of the shown night is read again now and then while the page is open
        C_Timer.NewTicker(POLL, ns.Perf.Wrap("Ticker Lineup page", function()
            local n = pageOpen() and ns.LineupNight(curNight(), false)
            -- asks the client for the newest state: a change comes back as CALENDAR_CHANGED
            if n and n.cal and not InCombatLockdown() and ns.Cal.Available() then pcall(C_Calendar.OpenCalendar) end
        end))
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
        if pending and (not selName or selName ~= pending.n:lower() or selIndex()) then pending = nil end
        if selName and not selIndex() and not pending then selName = nil end
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
        local setsView, export = view == "sets", view == "export"
        local other = paste or calendar or setsView or export or view == "roles"
        local shown = view
        -- the planner's player list: on a night without a list it opens by itself (there is nothing
        -- else to show) and stays until "Spieler" is clicked off
        if shown == "planner" and not has then grid.on = true end
        local gridOn = shown == "planner" and grid.on
        f.views.match:SetOn(shown == "match")
        f.views.planner:SetOn(shown == "planner")
        f.views.invite:SetOn(shown == "invite")
        f.pasteBtn:SetText(paste and L["Zurück"] or L["Einfügen"])
        W.FitChip(f.pasteBtn)
        f.calBtn:SetText(calendar and L["Zurück"] or L["Aus Kalender"])
        W.FitChip(f.calBtn)
        f.calBtn:SetEnabled(calendar or ns.Cal.CanReadInvites())
        f.auto:SetEnabled(has and not other)
        f.setsBtn:SetText(setsView and L["Zurück"] or L["Vorlagen"])
        W.FitChip(f.setsBtn)
        f.rolesLink:SetText(view == "roles" and L["Zurück"] or L["Rollen##Aufstellung"])
        W.FitChip(f.rolesLink)
        f.moreBtn:SetEnabled(not other)
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
        -- the invite view: its counts and why the buttons are off
        local ic = (shown == "invite") and ns.LineupInviteCounts(key) or nil
        local _, blocked = ns.LineupInviteBlocked(key)
        f.invBlocked = blocked
        if ic and has then
            parts = { L["Im Raid %d · eingeladen %d · abgelehnt %d · keine Antwort %d · offline %d · noch einzuladen %d"]:format(
                ic.R, ic.I, ic.D, ic.N, ic.O, ic.todo) }
            if blocked then parts[#parts + 1] = RED .. blocked .. "|r" end
        elseif ic then
            -- a night without a lineup: only "Gilde einladen" (F-163)
            parts = { L["Ohne Aufstellung: \"Gilde einladen\" lädt die Gilde bis zu einem Rang ein."] }
            if blocked then parts[#parts + 1] = RED .. blocked .. "|r" end
        end
        -- the planner: why "Gruppen sortieren" is off
        local sblock = (has and shown == "planner") and select(2, ns.LineupLeadBlocked(true)) or nil
        if sblock then parts[#parts + 1] = RED .. L["Sortieren: %s"]:format(sblock) .. "|r" end
        -- the view "Rollen" (F-165): why "Rollen jetzt setzen" is off
        local rblock = shown == "roles" and select(2, ns.LineupRoles.Blocked()) or nil
        if rblock then parts[#parts + 1] = RED .. L["Rollen: %s##Grund"]:format(rblock) .. "|r" end
        f.calLine:SetText(table.concat(parts, " · "))
        -- the view's buttons on the right of the last band
        local prev = not has and not other and previousNight() or nil
        if prev then
            f.copy:SetText(L["Von %s übernehmen"]:format(nightLabel(prev):match("^(.-) %(") or prev))
            W.FitChip(f.copy, 120)
        end
        f.copy:SetShown(prev ~= nil)
        f.rematch:SetShown(has and shown == "match")
        f.bench:SetShown(has and shown == "planner")
        f.bench:SetEnabled(key == ns.LineupTonight() and (c.bench > 0))
        f.take:SetShown(paste)
        -- the view "Rollen" leaves through its head link ("Zurück"): "Abbrechen" beside its button would read as undoing it
        f.cancel:SetShown(other and view ~= "roles")
        f.calTake:SetShown(calendar)
        -- the view "Vorlagen": the name and "Speichern" on the left, the chosen template on the right
        local sets = setsView and ns.LineupSets() or {}
        local picked = setsView and setChosen() or nil
        f.setName:SetShown(setsView)
        f.setSave:SetShown(setsView)
        f.setSave:SetEnabled(has)
        f.setLoad:SetShown(setsView)
        f.setLoad:SetEnabled(picked ~= nil)
        f.setDelete:SetShown(setsView)
        f.setDelete:SetEnabled(picked ~= nil)
        f.gridBtn:SetShown(shown == "planner")
        f.gridBtn:SetOn(gridOn)
        f.gridBtn:SetEnabled(has)
        -- invite and sort: the reason on the button when they may not
        local isInv, isPlan = has and shown == "invite", has and shown == "planner"
        f.inviteAll:SetShown(isInv)
        f.again:SetShown(isInv)
        fillGuildInvite(f, shown == "invite" and not other, blocked)
        f.sortBtn:SetShown(isPlan)
        if isInv then
            local running = ns.LineupInviteRunning()
            f.inviteAll:SetText(blocked or (running and L["Lädt ein ..."]) or L["Alle einladen (%d)"]:format(ic.todo))
            f.inviteAll:SetEnabled(not blocked and not running and ic.todo > 0)
            f.again:SetText(L["Nochmal einladen (%d)"]:format(ic.again))
            f.again:SetEnabled(not blocked and not running and ic.again > 0)
            W.FitChip(f.inviteAll, 100)
            W.FitChip(f.again)
        elseif isPlan then
            local paused = ns.LineupSortPaused(key)
            f.sortBtn:SetText(ns.LineupSorting() and L["Sortiert ..."] or paused and L["Sortieren fortsetzen"] or L["Gruppen sortieren"])
            f.sortBtn:SetEnabled(not sblock and not ns.LineupSorting() and key == ns.LineupTonight())
            W.FitChip(f.sortBtn)
        end
        f.calTake:SetEnabled(calendar and calChosen() ~= nil)
        f.views.match:SetShown(not other)
        f.views.planner:SetShown(not other)
        f.views.invite:SetShown(not other)
        fillRoles(f, shown == "roles")
        -- the raid ID marks: the instances somebody known holds an ID for
        local insts = ns.RaidIDsInstances and ns.RaidIDsInstances() or {}
        local idValues = { { value = 0, text = L["Raid-ID: aus"] } }
        for _, x in ipairs(insts) do idValues[#idValues + 1] = { value = x.m, text = L["ID: %s"]:format(x.name) } end
        f.raidIdPick:SetValues(idValues)
        f.raidId = (#insts > 0 and not f.raidIdOff) and ns.RaidIDsChosen() or nil
        f.raidIdPick:SetValue(f.raidId or 0)
        f.raidIdPick:SetShown(shown == "match" and has and #insts > 0)
        f:Place(4, { f.views.match, f.views.planner, f.views.invite, f.raidIdPick, f.guildRank, f.setName, f.setSave },
            { f.copy, f.rematch, f.gridBtn, f.sortBtn, f.bench, f.cancel, f.setDelete, f.setLoad, f.take, f.calTake, f.guildInv, f.again, f.inviteAll, f.rolesBtn }, { shown = true })
        f.paste:SetShown(paste)
        f.export:SetShown(export)
        if export then
            f.export.box:SetText(exportText or "")
            f.export.box:SetCursorPosition(0)
        end
        f.sets:SetShown(setsView and #sets > 0)
        if setsView then f.setRows:SetItems(sets) end
        f.match:SetShown(shown == "match" and has)
        f.plan:SetShown(shown == "planner")
        f.inv:SetShown(shown == "invite")
        f.cal:SetShown(calendar and calList ~= nil and #calList > 0)
        if calendar then
            if not calList then
                f.empty:Set(L["Kalender wird gelesen ..."], L["Amisia fragt den Spielkalender nach den Gildenereignissen."])
            elseif #calList == 0 then
                f.empty:Set(L["Keine Gildenereignisse"], L["In den nächsten 14 Tagen steht kein Gildenereignis im Spielkalender. Ein Offizier legt es dort an (Gilden-Ereignis)."])
            else
                f.calRows:SetItems(calList)
            end
        elseif setsView then
            f.empty:Set(L["Noch keine Vorlagen"], L["Tippe oben links einen Namen ein und klicke \"Speichern\": die Gruppen der gezeigten Nacht liegen dann als Vorlage hier."])
        elseif not has and not paste then
            f.empty:Set(L["Noch keine Anmeldungen"], prev and L["\"Einfügen\" nimmt die Anmeldeliste, oder übernimm die Aufstellung einer früheren Nacht. Ohne Liste: im \"Planer\" von Hand, aus einer Vorlage oder aus dem Raid (\"Mehr\")."]
                or L["\"Einfügen\" nimmt den Text eines Anmelde-Bots aus Discord, Zeilen wie \"Anna Tank\" oder den Block #AMISIA-RAID. Ohne Liste: im \"Planer\" von Hand, aus einer Vorlage oder aus dem Raid (\"Mehr\")."])
        end
        f.empty:SetShown((calendar and (not calList or #calList == 0)) or (setsView and #sets == 0)
            or (not has and not other and shown ~= "planner" and shown ~= "invite" and shown ~= "roles"))
        if paste then
            f.hint:SetText(L["Discord-Text eines Anmelde-Bots (Überschriften wie \"Tanks\", \"Heiler\", \"Ersatz\", \"Abgemeldet\"), Zeilen wie \"Anna Tank\" oder \"Bob, Nahkampf\", oder der Block #AMISIA-RAID. Dann \"Übernehmen\"."])
        elseif calendar then
            f.hint:SetText(L["Gildenereignisse der nächsten 14 Tage, Schlachtzug zuerst gewählt. \"Übernehmen\" liest die Teilnehmerliste in die Aufstellung der Nacht des Ereignisses; im Kalender ändert Amisia nichts."])
        elseif setsView then
            f.hint:SetText(L["Eine Vorlage merkt sich, wer in welcher Gruppe und auf Ersatz steht, mit Rolle und Festhalten. \"Laden\" setzt sie in die gezeigte Nacht; Doppelklick lädt auch. Höchstens %d Vorlagen."]:format(ns.LINEUP_MAX_SETS))
        elseif export then
            f.hint:SetText(L["Strg+C kopiert den Block. Ein anderer Offizier fügt ihn auf seiner Seite Aufstellung unter \"Einfügen\" ein."])
        elseif gridOn then
            f.hint:SetText(L["Klick auf einen Namen, dann auf einen Platz: der Spieler steht dort (Ziehen geht auch). Grau mit Zahl: schon in dieser Gruppe. Rechtsklick auf einen Namen der Liste: Rolle, Ersatz, Festhalten, Entfernen."])
        elseif shown == "roles" then
            f.hint:SetText(L["Vor- und Nachname wie im Spiel, höchstens 10 pro Liste. Amisia fügt nur hinzu: niemand wird herabgestuft, keine Markierung entfernt. Nur als Raidleiter in deinem Raid, nicht im Kampf."])
        elseif shown == "invite" then
            f.hint:SetText(L["Status aus den Meldungen des Spiels; ohne Antwort nach 90 Sekunden \"keine Antwort\". Offline wird nicht eingeladen, Gäste nur mit der Einstellung. Höchstens 3 Einladungen pro Name und Abend."])
        elseif shown == "planner" then
            f.hint:SetText(L["Klick auf einen Namen, dann auf einen anderen oder einen freien Platz: tauschen oder verschieben (Ziehen geht auch). Rot umrandet: Gruppe ohne Heiler. Rechtsklick: Rolle, Ersatz, Festhalten."])
        else
            f.hint:SetText(has and L["Gelb: ein Klick bestätigt. Orange: den Richtigen wählen. Rot: den Namen eintippen (Amisia merkt ihn sich). Rechtsklick: Rolle, Ersatz, Festhalten, Entfernen."] or "")
        end
        if calendar or setsView or export or shown == "roles" or (not has and shown ~= "planner" and shown ~= "invite") then return end
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
        if shown == "invite" then
            local states = ns.LineupInviteStates(key)
            local items = {}
            for i, e in ipairs(f.list) do
                if e.g and not e.a and not e.b and not e.v then items[#items + 1] = { i = i, e = e, rec = states[e.n:lower()] } end
            end
            table.sort(items, function(a, b)
                if a.e.g ~= b.e.g then return a.e.g < b.e.g end
                return a.i < b.i
            end)
            -- invited through "Gilde einladen" or a whisper, not placed and not in the group yet (F-163)
            for _, r in ipairs(ns.LineupInviteExtra(key)) do items[#items + 1] = { extra = r } end
            local _, unlisted = ns.LineupSortPlan(key)
            local subs = {}
            for _, r in ipairs(ns.LineupSortState.Rows()) do subs[r.name] = r.sub end
            for _, name in ipairs(unlisted) do
                local r = states[name:lower()]
                items[#items + 1] = { name = name, sub = subs[name], by = r and r.by }
            end
            f.invRows:SetItems(items)
            if #items == 0 and not has then
                f.empty:Set(L["Niemand eingeladen"], L["\"Gilde einladen\" lädt alle Gildenmitglieder bis zum gewählten Rang ein, die online und noch nicht in der Gruppe sind. Wer eingeladen ist, steht hier mit seinem Status."])
                f.empty:Show()
            end
        elseif shown == "match" then
            f.mlist:SetItems(matchItems)
        elseif shown == "planner" then
            fillGroups(f.plan, n, c)
            f.openHead:SetText(L["Nicht eingeteilt (%d)"]:format(#open))
            f.benchHead:SetText(L["Ersatz (%d)"]:format(#bench))
            f.openList:SetItems(open)
            f.benchList:SetItems(bench)
            -- the two lists, or the player list in their place
            local P = f.plan
            for _, h in ipairs(P.sideHeads) do h:SetShown(not gridOn) end
            f.openList:SetShown(not gridOn)
            f.benchList:SetShown(not gridOn)
            for _, w in ipairs(P.gridBar) do w:SetShown(gridOn) end
            f.gridList:SetShown(gridOn)
            P.gridEmpty:SetShown(false)
            if gridOn then
                local players, classes = gridPlayers(f.list)
                local classValues = { { value = "all", text = L["Alle Klassen"] } }
                for token in pairs(classes) do classValues[#classValues + 1] = { value = token, text = className(token) } end
                table.sort(classValues, function(a, b)
                    if a.value == "all" or b.value == "all" then return a.value == "all" end
                    return a.text < b.text
                end)
                P.classPick:SetValues(classValues)
                P.classPick:SetValue(grid.class)
                P.srcRaid:SetOn(grid.src == "raid")
                P.srcGuild:SetOn(grid.src == "guild")
                P.online:SetOn(grid.online)
                P.byClass:SetOn(grid.byClass)
                local items = {}
                for i, p in ipairs(players) do
                    local r = math.floor((i - 1) / GRID_COLS) + 1
                    items[r] = items[r] or {}
                    items[r][#items[r] + 1] = p
                end
                f.gridList:SetItems(items)
                if #players == 0 then
                    P.gridEmpty:SetText(GREY .. (grid.src == "raid" and #ns.LineupRaidRows() == 0 and L["Du bist in keinem Raid."]
                        or L["Niemand passt zu diesen Filtern."]) .. "|r")
                    P.gridEmpty:Show()
                end
            end
        end
    end }

ns.Listen("LINEUP", function()
    if ns.CurrentPage and ns.CurrentPage() == "lineup" then ns.Refresh() end
end)
-- invite statuses, a sort step, the restriction (F-084)
ns.Listen("LINEUP_INVITE", function()
    if ns.CurrentPage and ns.CurrentPage() == "lineup" then ns.Refresh() end
end)
-- raid IDs heard or read (F-099): the "ID" marks
ns.Listen("RAIDIDS", function()
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
end)
