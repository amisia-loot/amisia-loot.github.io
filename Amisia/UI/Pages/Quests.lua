-- Quests page: every quest of the world for the own character (Quests.lua) by zone - in the log,
-- open to take, locked with the reason, done - with search, the zone pick and the filter chips, the
-- chain progress and the best reward's upgrade mark per row, a click opening the chain and the
-- rewards below the quest, and a button that sets the waypoint to the quest giver.
local ADDON, ns = ...
local L = ns.L
local W, Q, T = ns.W, ns.Quests, ns.Theme
local GOLD_TEXT = T.GOLD_TEXT
local GREY = T.GREY
local GREEN = "|cff4fd16b"
local RED = "|cffff6040"
local YELLOW = "|cffffd100"
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local ICON = "Interface\\Icons\\INV_Misc_Book_08"
-- rows of 24 from the column heads (90) to the footer (442): 14
local ROWS, ROW_H = 14, 24
local GAP = 1            -- seconds between two rebuilds after changes
local STATUS_COLOR = { active = YELLOW, open = GREEN, locked = RED, done = GREY }
local HINT = L["Klick auf eine Quest: Reihe und Belohnungen. Weg: Wegpunkt zum Questgeber."]

local page
local nameMissing = false

-- The window state in settings.questsPage (Quests.PageState): search, zone ("all", "here" or a
-- uiMapID), show (status chips), chains, upgrades, mine, collapsed and expanded.
local function state()
    local q = Q.PageState()
    if type(q.show) ~= "table" then q.show = { open = true, active = true, locked = false, done = false } end
    if type(q.collapsed) ~= "table" then q.collapsed = {} end
    if type(q.expanded) ~= "table" then q.expanded = {} end
    if q.mine == nil then q.mine = true end
    if type(q.search) ~= "string" then q.search = "" end
    if q.zone == nil then q.zone = "all" end
    return q
end

local function longDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    return y and ns.FmtDate(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })) or "?"
end

local function itemText(id)
    local f = C_Item and C_Item.GetItemInfo
    local name, q, _
    if f then name, _, q = f(id) end
    if not name then nameMissing = true end
    return ("|c%s%s|r"):format(QUALITY[q or 1] or QUALITY[1], name or ("Item " .. tostring(id)))
end

-- The level in the quest log's colours (simplified): red when it cannot be taken yet, yellow around
-- the own level, green below, grey far below.
local function levelText(r)
    if (r.min or 0) <= 0 then return "" end
    local my = ns.QuestOpts().level
    local c
    if r.min > my then c = RED
    elseif r.min >= my - 2 then c = YELLOW
    elseif r.min >= my - 8 then c = GREEN
    else c = GREY end
    return c .. r.min .. "|r"
end

local function markText(e)
    if not e or not e.mark then return "" end
    local c = e.later and "|cffff9933" or (e.up and GREEN or GREY)
    return c .. e.mark .. "|r"
end

---------------------------------------------------------------------------
-- Rows: the list with the opened quests' chains and rewards
---------------------------------------------------------------------------

local function filterOf(s)
    local zone = s.zone
    if zone == "here" then zone = Q.HereZone() or -1 elseif zone == "all" then zone = nil end
    return { zone = zone, search = s.search, show = s.show, chains = s.chains, upgrades = s.upgrades, mine = s.mine,
        collapsed = s.collapsed }
end

local function rowsOf(s)
    local rows, counts, why = ns.QuestList(filterOf(s))
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = row
        if row.kind == "quest" and s.expanded[row.qid] then
            local c = ns.QuestChain(row.qid)
            for i, id in ipairs(c and c.ids or {}) do
                out[#out + 1] = { kind = "step", qid = id, n = i, total = c.total, self = id == row.qid, info = ns.QuestState(id) }
            end
            for _, e in ipairs(ns.QuestRewards(row.qid).list) do
                out[#out + 1] = { kind = "reward", qid = row.qid, id = e.id, e = e }
            end
        end
    end
    return out, counts, why
end

local function fillRow(r, e)
    r.go:Hide()
    r.title:SetTextColor(1, 1, 1)
    if e.kind == "zone" then
        r.title:SetText(GOLD_TEXT .. (e.collapsed and "+ " or "- ") .. e.name .. (" (%d)"):format(e.n) .. "|r")
        r.level:SetText("")
        r.status:SetText("")
        r.reward:SetText("")
        return
    end
    if e.kind == "reward" then
        r.title:SetText("        " .. itemText(e.id))
        r.level:SetText("")
        r.status:SetText("")
        r.reward:SetText(markText(e.e))
        return
    end
    local info = e.info or ns.QuestState(e.qid)
    local rec = info.rec
    local color = STATUS_COLOR[info.status] or ""
    if e.kind == "step" then
        local t = ("      %d. %s"):format(e.n, info.title)
        r.title:SetText(e.self and (GOLD_TEXT .. t .. "|r") or (info.status == "done" and (GREY .. t .. "|r") or t))
        r.level:SetText(levelText(rec))
        r.status:SetText(color .. Q.StatusText(info) .. "|r")
        r.reward:SetText("")
    else
        local c = ns.QuestChain(e.qid)
        local title = "  " .. info.title
        if info.status == "done" then title = GREY .. title .. "|r" end
        r.title:SetText(title .. (c and (GREY .. " [" .. Q.ChainText(c) .. "]|r") or ""))
        r.level:SetText(levelText(rec))
        r.status:SetText(color .. Q.StatusText(info) .. "|r")
        local rw = ns.QuestRewards(e.qid)
        if rw.best then
            r.reward:SetText(markText(rw.best))
        elseif #rw.list > 0 then
            r.reward:SetText(GREY .. (#rw.list == 1 and L["1 Item"] or L["%d Items"]:format(#rw.list)) .. "|r")
        else
            r.reward:SetText("")
        end
    end
    if Q.HasPlace(e.qid) then r.go:Show() end
end

local function questTip(self)
    local e = self.item
    if not e or not e.qid then return end
    if e.kind == "reward" then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.id) else GameTooltip:SetHyperlink("item:" .. e.id) end
        GameTooltip:Show()
        return
    end
    local info = ns.QuestState(e.qid)
    if not info then return end
    local r = info.rec
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(info.title, 1, 0.82, 0)
    if r.min > 0 then GameTooltip:AddLine(L["ab Level %s"]:format(r.min), 0.85, 0.85, 0.85) end
    GameTooltip:AddLine(Q.STATUS_TEXT[info.status], 0.85, 0.85, 0.85)
    for _, reason in ipairs(info.reasons) do GameTooltip:AddLine(reason.text, 1, 0.38, 0.25, true) end
    if info.note then GameTooltip:AddLine(L["%s (nicht prüfbar)"]:format(info.note), 0.85, 0.85, 0.85, true) end
    local where = ns.QuestStartText(e.qid)
    if where ~= "" then GameTooltip:AddLine(L["Start: %s"]:format(where), 0.85, 0.85, 0.85, true) end
    local c = ns.QuestChain(e.qid)
    if c then
        GameTooltip:AddLine(L["Reihe %s (Quest %d von %d)"]:format(Q.ChainText(c), c.pos, c.total), 0.89, 0.72, 0.34)
        for i, id in ipairs(c.ids) do
            if i > 12 then
                GameTooltip:AddLine(L["... und %d weitere"]:format(#c.ids - 12), 0.6, 0.6, 0.6)
                break
            end
            local s = ns.QuestState(id)
            GameTooltip:AddLine(("%d. %s%s"):format(i, s.title, s.status == "done" and L[" (erledigt)"] or ""), 0.6, 0.6, 0.6, true)
        end
    end
    for _, x in ipairs(ns.QuestRewards(e.qid).list) do
        GameTooltip:AddLine(L["Belohnung: %s"]:format(itemText(x.id) .. (x.mark and (" " .. markText(x)) or "")), 0.85, 0.85, 0.85, true)
    end
    if r.breadcrumb then GameTooltip:AddLine(L["Hinweis-Quest: führt zu einer anderen Quest."], 0.6, 0.6, 0.6, true) end
    if r.repeatable then GameTooltip:AddLine(L["Wiederholbar."], 0.6, 0.6, 0.6) end
    if r.classic then GameTooltip:AddLine(L["Aus den Classic-Daten, für Forever noch nicht bestätigt."], 0.6, 0.6, 0.6, true) end
    if e.kind == "quest" then GameTooltip:AddLine(L["Klick: Reihe und Belohnungen auf- oder zuklappen."], 0.31, 0.82, 0.42) end
    GameTooltip:Show()
end

local function say(ok, why)
    if not ok and why then ns.msg(why) end
end

local function onRowClick(self, button)
    local e = self.item
    if not e then return end
    local s = state()
    if e.kind == "zone" then
        s.collapsed[e.zone] = not s.collapsed[e.zone] or nil
    elseif e.kind == "quest" then
        s.expanded[e.qid] = not s.expanded[e.qid] or nil
    elseif e.kind == "reward" then
        if HandleModifiedItemClick and IsModifiedClick and IsModifiedClick() then
            local f = C_Item and C_Item.GetItemInfo
            local link = f and select(2, f(e.id))
            if link then HandleModifiedItemClick(link) end
        end
        return
    else
        return
    end
    ns.Refresh()
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function ns.QuestPageFrame() return page end

local function zoneValues(counts, s)
    local here = Q.HereZone()
    local values = { { value = "all", text = L["Alle Zonen"] },
        { value = "here", text = L["Hier: %s"]:format(here and Q.ZoneName(here) or L["unbekannt"]) } }
    local found = false
    for _, z in ipairs(counts.zones or {}) do
        values[#values + 1] = { value = z.zone, text = ("%s (%d)"):format(z.name, z.n) }
        if z.zone == s.zone then found = true end
    end
    if type(s.zone) == "number" and not found then values[#values + 1] = { value = s.zone, text = Q.ZoneName(s.zone) .. " (0)" } end
    return values
end

local function countsText(counts)
    return L["%d im Log · %d annehmbar · %d gesperrt · %d erledigt"]:format(counts.active, counts.open, counts.locked, counts.done)
end

local function refresh(f)
    local s = state()
    local rows, counts, why = rowsOf(s)
    f.zone:SetValues(zoneValues(counts, s))
    f.zone:SetValue(s.zone)
    if not f.search:HasFocus() and f.search:GetText() ~= s.search then f.search:SetText(s.search) end
    for k, chip in pairs(f.show) do chip:SetOn(s.show[k] and true or false) end
    f.chains:SetOn(s.chains and true or false)
    f.upgrades:SetOn(s.upgrades and true or false)
    f.mine:SetOn(s.mine and true or false)
    f.counts:SetText(countsText(counts))
    local key = table.concat({ tostring(s.zone), s.search, tostring(s.chains), tostring(s.upgrades), tostring(s.mine) }, "|")
    if key ~= f.listKey then f.list.offset = 0 end
    f.listKey = key
    nameMissing = false
    f.list:SetItems(rows)
    if #rows > 0 then
        f.empty:Hide()
    else
        f.empty:Set(L["Nichts gefunden"], Q.WhyText(why) or L["Keine Quests für diese Auswahl. Oben weitere Häkchen setzen oder die Suche leeren."])
        f.empty:Show()
    end
    local d = ns.Data("QUEST_DATA")
    if type(d) == "table" then
        f.data:SetText(L["Questdaten vom %s · %d Quests · Namen englisch, bis der Client die Quest kennt."]:format(longDate(d.built), d.count or 0))
    else
        f.data:SetText("")
    end
end

-- the columns of the list (590 wide, 12 px for its scroll bar); the waypoint button has no text cell
local COLS = { { "title", 4, 232, "Quest" }, { "level", 240, 40, "Level" }, { "status", 284, 150, "Status" },
    { "reward", 438, 92, L["Belohnung"] }, { "go", 540, 46, L["Weg"], cell = false } }

local function create(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: zone and search; under it the chips and the counts
    f:Bands({ "row", "row", "line" })
    f.zone = W.Picker(f, 200, function(v)
        state().zone = (v == "all" or v == "here") and v or tonumber(v) or "all"
        ns.Refresh()
    end)
    f.search = W.SearchBox(f, 190, function(text)
        state().search = (text or ""):match("^%s*(.-)%s*$") or ""
        ns.Refresh()
    end, L["Quest, Questgeber, Zone"])
    f:Place(1, { f.zone, f.search })

    -- the status chips, then the filters
    f.show = {}
    local defs = { { "open", L["Annehmbar"], 76, L["Quests, die du jetzt annehmen kannst."] },
        { "active", L["Im Log"], 58, L["Quests in deinem Questlog."] },
        { "locked", L["Gesperrt"], 68, L["Quests, die dir noch fehlen: Vorquest, Level, Beruf. Der Grund steht in der Zeile."] },
        { "done", L["Erledigt"], 64, L["Abgegebene Quests."] } }
    local row = {}
    for _, d in ipairs(defs) do
        local chip = W.Chip(f, d[2], d[3], function()
            local s = state()
            s.show[d[1]] = not s.show[d[1]]
            ns.Refresh()
        end)
        W.Tooltip(chip, d[2], d[4])
        f.show[d[1]] = chip
        row[#row + 1] = chip
    end
    local function toggle(field)
        return function()
            local s = state()
            s[field] = not s[field]
            ns.Refresh()
        end
    end
    f.chains = W.Chip(f, L["Reihen"], 58, toggle("chains"))
    W.Tooltip(f.chains, L["Nur Reihen"], L["Nur Quests mit Vorquest oder Folgequest."])
    f.upgrades = W.Chip(f, "Upgrades", 72, toggle("upgrades"))
    W.Tooltip(f.upgrades, L["Nur Upgrades"], L["Nur Quests, deren Belohnung ein Upgrade für dich ist."])
    f.mine = W.Chip(f, L["Nur für mich"], 92, toggle("mine"))
    W.Tooltip(f.mine, L["Nur für mich"], L["Quests anderer Fraktionen, Völker und Klassen ausblenden."])
    -- the status chips, then the filters after a wider gap
    row[#row + 1] = { f.chains, gap = 16 }
    row[#row + 1] = f.upgrades
    row[#row + 1] = f.mine
    f:Place(2, row)
    f.counts = f:Line(3)
    f:Footer({ "hint", "data" })
    f.hint:SetText(HINT)

    f.headFrame, f.head = f:Columns(COLS)
    f.list = f:List(ROWS, ROW_H, function(r)
        W.Cells(r, COLS)
        r.go = W.Button(r, L["Weg"], 54, function(self)
            local e = self:GetParent().item
            if e and e.qid then say(ns.QuestWaypoint(e.qid)) end
        end, { height = T.ROW_BUTTON_H })
        r.go:SetPoint("LEFT", 536, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", onRowClick)
        r:SetScript("OnEnter", questTip)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, fillRow)
    f.empty = f:Empty()
    return f
end

ns.RegisterPanel{ key = "quests", label = "Quests", icon = ICON, order = 56, group = "gear",
    available = function() return ns.Get("quests.enabled") ~= false end,
    create = create, refresh = refresh }

---------------------------------------------------------------------------
-- Changes: rebuilt while the page shows, at most once a second
---------------------------------------------------------------------------

local function shown()
    return page ~= nil and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "quests"
end

local due, lastAt = false, nil
local function schedule()
    if due or not shown() then return end
    due = true
    local now = GetTime and GetTime() or 0
    local wait = lastAt and math.max(0, GAP - (now - lastAt)) or 0
    C_Timer.After(wait, function()
        due = false
        if not shown() then return end
        lastAt = GetTime and GetTime() or 0
        ns.Refresh()
    end)
end

ns.Listen("QUESTS_CHANGED", schedule)
ns.Listen("BIS_CHANGED", schedule)
ns.Listen("COLLECT_CHANGED", function(kind) if kind == nil or kind == "q" then schedule() end end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function()
    if AmisiaDB and AmisiaDB.settings and Q.PageState().zone == "here" then
        schedule()
    end
end)

-- Item names the client did not have at the last fill: the rows again once the answers are in.
local namesDue = false
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if not nameMissing or namesDue or not shown() then return end
    namesDue = true
    C_Timer.After(0.3, function()
        namesDue = false
        if not nameMissing or not shown() then return end
        ns.Refresh()
    end)
end)
