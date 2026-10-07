-- Statistik: loot and attendance per player from the saved raids (Raid/Stats.lua), every
-- character of a player together. Officers see every player; a raider sees the own row, as on the
-- page Vergaben. The hall of fame is for everyone. Sortable columns, the range (4 weeks, phase,
-- all), class and role, a row's tooltip with the split per character, the weeks of the chosen player.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local ROWS, ROW_H = 9, 22
local WEEK = 7 * 86400
local DOT = "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:10:10:0:0|t"
local MAX_DOTS = 12

local page
local view = "players"          -- "players" or "fame"
local range = "all"             -- "4w", "phase", "all"
local classPick, rolePick = "all", "all"
local sortCol, sortDesc = "items", true
local chosen                    -- key of the player in the detail

function ns.StatsPageFrame() return page end

-- The columns: key, x, width, head text. They end at 558 of the 590 the list has.
local COLS = {
    { "name", 6, 130, L["Spieler"] },
    { "items", 140, 36, "Items" },
    { "ms", 178, 28, "MS" },
    { "os", 208, 28, "OS" },
    { "sr", 238, 28, "SR" },
    { "perRaid", 268, 44, L["/Raid"] },
    { "rate", 314, 92, L["Teilnahme"] },
    { "bosses", 408, 46, L["Bosse"] },
    { "streak", 456, 40, L["Serie"] },
    { "last", 498, 60, L["Letztes"] },
}
local HEAD_TIP = {
    name = L["Ein Spieler mit allen Charakteren (Twinks zählen für ihren Main)."],
    items = L["Vergebene Items, ohne Bank und Entzaubern."],
    perRaid = L["Items pro Raid, bei dem der Spieler da war."],
    rate = L["Raids da (Ersatzbank zählt als da) von den Raids seit dem ersten Auftauchen."],
    bosses = L["Bosskills, bei denen der Spieler dabei war."],
    streak = L["Die längste Reihe von Raids ohne Fehlen."],
    last = L["Das Datum des letzten Items."],
}
local ROLE_TEXT = { dps = L["Schaden"], unknown = L["Rolle unbekannt"] }

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr or "ffffffff"
end

local function className(class)
    local names = ns.Gear and ns.Gear.CLASS_NAMES
    return names and names[class] or class or "?"
end

local function rateText(p)
    if p.total == 0 then return "-" end
    return ("%d %% (%d/%d)"):format(math.floor(p.rate * 100 + 0.5), p.raids, p.total)
end

local function plural(n, one, many) return n == 1 and one or many end

-- The statistics as the page shows them: the range and the filters (officers), sorted.
local function build()
    local officer = ns.IsOfficerView()
    local res = ns.StatsBuild({ range = range, class = officer and classPick ~= "all" and classPick or nil,
                                role = officer and rolePick ~= "all" and rolePick or nil })
    ns.StatsSort(res.players, sortCol, sortDesc)
    local rows = res.players
    if not officer then
        local me = ns.UnitFullName("player")
        rows = {}
        for _, p in ipairs(res.players) do
            if me and ns.SameMain(p.name, me) then rows[#rows + 1] = p end
        end
    end
    return res, rows
end

-- "Bob: 1 Item, 2 Raids" per character.
local function charLines(p)
    local out = {}
    for _, c in ipairs(p.chars) do
        out[#out + 1] = L["%s: %d %s, %d %s"]:format(c.name, c.items, plural(c.items, L["Item"], L["Items"]), c.raids,
            plural(c.raids, L["Raid"], L["Raids"]))
    end
    return out
end

local function detailText(p)
    if not p then return "" end
    local lines = { ("|c%s%s|r  %s"):format(classColor(p.class), p.name, T.GREY .. className(p.class) .. " · " .. ROLE_TEXT[p.role] .. "|r") }
    local chars = charLines(p)
    if #p.chars > 1 then lines[#lines + 1] = T.LABEL .. L["Charaktere:"] .. "|r " .. table.concat(chars, " · ") end
    lines[#lines + 1] = L["Zu spät: %d · Ersatzbank: %d · Bosse gesehen: %d"]:format(p.late, p.bench, p.bosses)
    lines[#lines + 1] = ""
    lines[#lines + 1] = T.LABEL .. L["Items pro Woche (die letzten 8 Wochen):"] .. "|r"
    local now = time()
    for i = 1, #p.weeks do
        local n = p.weeks[i]
        local bar = n > 0 and DOT:rep(math.min(n, MAX_DOTS)) .. (n > MAX_DOTS and "+" or "") or T.GREY .. "-|r"
        lines[#lines + 1] = L["Woche ab %s:"]:format(ns.FmtDay(now - i * WEEK)) .. "  " .. bar .. (n > 0 and ("  " .. n) or "")
    end
    return table.concat(lines, "\n")
end

local function fameText(res)
    local fame = ns.StatsFame(res)
    if #fame == 0 then return T.GREY .. L["Noch nichts für die Ruhmeshalle: es fehlen aufgezeichnete Raids mit Vergaben."] .. "|r" end
    local lines = {}
    for _, e in ipairs(fame) do
        lines[#lines + 1] = T.LABEL .. e.title .. "|r"
        lines[#lines + 1] = "   " .. e.name .. " - " .. e.text
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = T.GREY .. L["Beste Teilnahme ab 3 Raids. Nur was die Aufzeichnungen hergeben: wie groß ein Upgrade war, weiß Amisia im Nachhinein nicht."] .. "|r"
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

local function build_page(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    page = f

    -- view chips left, range chips right
    f.view = {
        players = W.Chip(f, L["Spieler"], nil, function() view = "players" ns.Refresh() end),
        fame = W.Chip(f, L["Ruhmeshalle"], nil, function() view = "fame" ns.Refresh() end),
    }
    W.FitChip(f.view.players, 70)
    W.FitChip(f.view.fame, 70)
    W.Row(f, { f.view.players, f.view.fame }, T.CHIP_GAP, 0, -2)
    f.range = {
        w4 = W.Chip(f, L["4 Wochen"], nil, function() range = "4w" ns.Refresh() end),
        phase = W.Chip(f, L["Phase"], nil, function() range = "phase" ns.Refresh() end),
        all = W.Chip(f, L["Alle Raids"], nil, function() range = "all" ns.Refresh() end),
    }
    for _, c in pairs(f.range) do W.FitChip(c, 60) end
    W.Row(f, { f.range.w4, f.range.phase, f.range.all }, T.CHIP_GAP, 0, -2, { right = true })
    W.Tooltip(f.range.phase, L["Phase"], L["Die Raids, seit der neueste Raid zum ersten Mal aufgezeichnet wurde."])

    -- class and role (officers), the status line
    f.class = W.Picker(f, 130, function(v) classPick = v or "all" ns.Refresh() end)
    f.role = W.Picker(f, 130, function(v) rolePick = v or "all" ns.Refresh() end)
    f.role:SetValues({ { value = "all", text = L["Alle Rollen"] }, { value = "dps", text = ROLE_TEXT.dps },
                       { value = "unknown", text = ROLE_TEXT.unknown } })
    f.info = W.Text(f, T.FONT.hint, 314)
    W.Row(f, { f.class, f.role, f.info }, 8, 0, -27)

    -- column heads: a click sorts, a second click turns the order round
    local head = CreateFrame("Frame", nil, f)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, -52)
    head:SetPoint("TOPRIGHT", 0, -52)
    f.heads = {}
    for _, c in ipairs(COLS) do
        local key, x, w, label = c[1], c[2], c[3], c[4]
        local b = CreateFrame("Button", nil, head)
        b:SetSize(w, 18)
        b:SetPoint("LEFT", x, 0)
        b.label = W.Text(b, T.FONT.head, w)
        b.label:SetPoint("LEFT")
        b.label:SetText(label)
        b:SetScript("OnClick", function()
            if sortCol == key then
                sortDesc = not sortDesc
            else
                sortCol, sortDesc = key, key ~= "name"
            end
            ns.Refresh()
        end)
        W.Tooltip(b, label, (HEAD_TIP[key] and (HEAD_TIP[key] .. " ") or "") .. L["Klicken sortiert."])
        f.heads[key] = b
    end
    f.headFrame = head

    f.list = W.List(f, ROWS, ROW_H, function(r)
        for _, c in ipairs(COLS) do r[c[1]] = col(r, c[2], c[3]) end
        r:SetScript("OnClick", function(self)
            if self.item then
                chosen = self.item.key
                ns.Refresh()
            end
        end)
        r:SetScript("OnEnter", function(self)
            local p = self.item
            if not p then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name, 1, 0.82, 0)
            for _, line in ipairs(charLines(p)) do GameTooltip:AddLine(line, 0.85, 0.85, 0.85) end
            GameTooltip:AddLine(L["Zu spät: %d · Ersatzbank: %d"]:format(p.late, p.bench), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, p)
        r.name:SetText(("|c%s%s|r"):format(classColor(p.class), p.name) .. (#p.chars > 1 and (T.GREY .. " +" .. (#p.chars - 1) .. "|r") or ""))
        r.items:SetText(tostring(p.items))
        r.ms:SetText(tostring(p.ms))
        r.os:SetText(tostring(p.os))
        r.sr:SetText(tostring(p.sr))
        r.perRaid:SetText(p.raids > 0 and ns.Num(p.perRaid, 2) or "-")
        r.rate:SetText(rateText(p))
        r.bosses:SetText(tostring(p.bosses))
        r.streak:SetText(tostring(p.streak))
        r.last:SetText(p.last and ns.FmtDay(p.last) or "-")
        if r.sel then r.sel:SetShown(p.key == chosen) end
    end)
    f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    -- room for the list's scroll bar at the right
    f.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -T.SCROLL_ROOM, 0)
    for _, r in ipairs(f.list.rows) do r.sel = W.SelectBar(r) end
    f.empty = W.Text(f, T.FONT.dim, 580, true)
    f.empty:SetPoint("TOPLEFT", f.list, "TOPLEFT", 6, -6)
    f.empty:SetText(L["Noch keine Raids aufgezeichnet. Die Statistik füllt sich mit jedem Raid, den Amisia aufzeichnet."])
    f.hint = W.Text(f, T.FONT.hint, 580)
    f.hint:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 6, -4)

    -- the chosen player: characters and items per week
    f.detail = W.ScrollText(f)
    f.detail:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 6, -22)
    f.detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -T.SCROLL_ROOM, 0)

    -- the hall of fame
    f.fame = W.ScrollText(f)
    f.fame:SetPoint("TOPLEFT", 6, -56)
    f.fame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -T.SCROLL_ROOM, 0)
    f.fame:Hide()
    return f
end

local function refresh(f)
    local officer = ns.IsOfficerView()
    local res, rows = build()
    f.view.players:SetOn(view == "players")
    f.view.fame:SetOn(view == "fame")
    f.range.w4:SetOn(range == "4w")
    f.range.phase:SetOn(range == "phase")
    f.range.all:SetOn(range == "all")

    -- the classes there are, for the picker
    local classes, seen = { { value = "all", text = L["Alle Klassen"] } }, {}
    for _, p in ipairs(res.all) do
        if p.class and not seen[p.class] then
            seen[p.class] = true
            classes[#classes + 1] = { value = p.class, text = className(p.class) }
        end
    end
    table.sort(classes, function(a, b)
        if a.value == "all" or b.value == "all" then return a.value == "all" end
        return a.text < b.text
    end)
    f.class:SetValues(classes)
    f.class:SetValue(classPick)
    f.role:SetValue(rolePick)
    f.class:SetShown(officer and view == "players")
    f.role:SetShown(officer and view == "players")
    W.Row(f, { f.class, f.role, f.info }, 8, 0, -27, { shown = true })

    local info = L["%d %s"]:format(res.raids, plural(res.raids, L["Raid"], L["Raids"]))
    if range == "phase" and res.phase then
        info = info .. " · " .. L["Phase seit %s (%s)"]:format(ns.FmtDay(res.phase.from), res.phase.zone)
    end
    f.info:SetText(info)

    local fame = view == "fame"
    f.fame:SetShown(fame)
    f.headFrame:SetShown(not fame)
    f.list:SetShown(not fame)
    f.detail:SetShown(not fame)
    f.hint:SetShown(not fame)
    if fame then
        f.empty:Hide()
        f.fame:SetText(fameText(res))
        return
    end
    for key, b in pairs(f.heads) do
        local on = key == sortCol
        b.label:SetTextColor(on and 1 or T.GOLD[1], on and 1 or T.GOLD[2], on and 1 or T.GOLD[3])
    end
    -- the chosen player, else the first row
    local pick
    for _, p in ipairs(rows) do
        if p.key == chosen then pick = p end
    end
    pick = pick or rows[1]
    chosen = pick and pick.key or nil
    f.list:SetItems(rows)
    f.empty:SetShown(#ns.Sessions() == 0)
    f.hint:SetText(officer and L["Klick auf eine Zeile: Wochen des Spielers. Maus über eine Zeile: seine Charaktere."]
        or L["Deine Zahlen. Die Zahlen anderer Spieler sehen nur Offiziere; die Ruhmeshalle sehen alle."])
    f.detail:SetText(detailText(pick))
end

-- Opens the page, in a view ("players" or "fame") when given.
function ns.ShowStats(which)
    if which == "players" or which == "fame" then view = which end
    ns.ShowPage("stats")
    ns.Refresh()
end

ns.RegisterPanel{ key = "stats", label = L["Statistik"], icon = "Interface\\Icons\\INV_Misc_Note_05", order = 36, group = "raid",
    create = function(parent) return build_page(parent) end,
    refresh = function(f) refresh(f) end }

ns.RegisterSlash("statistik", { en = "stats", desc = L["Seite Statistik öffnen"], run = function() ns.ShowStats() end })
