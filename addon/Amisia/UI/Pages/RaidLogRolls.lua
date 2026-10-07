-- The raid log page's view "Würfe": the group loot rolls (GroupRolls.lua) of the chosen raid, or of
-- the dungeon runs, newest first: time, item, result (winner with choice and number, everyone
-- passed, open) and the number of choices; below, every choice of the chosen roll, the winner
-- first. Built and filled by UI/Pages/RaidLog.lua (ns.RaidLogRolls.Build / Refresh).
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local GR = ns.GroupRolls
local ROWS, ROW_H = 10, 22
local GREY, GREEN, LABEL = T.GREY, T.GREEN, T.LABEL
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local ORDER = { N = 1, O = 2, T = 3, G = 4, D = 5, P = 6 }

local V
local source = "raid"   -- "raid" (the chosen raid) or "runs" (the dungeon runs); kept until logout
local chosenEntry       -- the roll in the detail area
local nameMissing = false

local R = {}
ns.RaidLogRolls = R

local function hm(t) return date("%H:%M", t or 0) end

local function itemText(id)
    local f = C_Item and C_Item.GetItemInfo
    local name, q
    if type(f) == "function" then
        local ok, n, _, quality = pcall(f, id)
        if ok then name, q = ns.Plain(n), ns.Plain(quality) end
    end
    if type(name) ~= "string" then
        nameMissing = true
        name = ns.ItemName and ns.ItemName(id) or nil
    end
    return ("|c%s%s|r"):format(QUALITY[tonumber(q) or 1] or QUALITY[1], name or ("Item " .. tostring(id)))
end

local function classColored(name, cls)
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    return (c and c.colorStr) and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local function choiceText(p)
    local text = GR.ChoiceText(p.c)
    if p.r then text = text .. " " .. p.r end
    return text
end

local function resultText(e)
    if e.win then
        local p = e.by and e.by[e.win]
        return GREEN .. e.win .. "|r" .. (p and p.c and (GREY .. " (" .. choiceText(p) .. ")|r") or "")
    end
    if e.all then return GREY .. L["alle gepasst"] .. "|r" end
    if e.wait then return LABEL .. L["wartet (geheim)"] .. "|r" end
    return LABEL .. L["offen"] .. "|r"
end

local function choices(e)
    local n = 0
    for _ in pairs(e.by or {}) do n = n + 1 end
    return n
end

-- The rows of the view: the raid's entries, or per run a header and its entries (newest first).
local function items(s)
    local out = {}
    if source == "runs" then
        local runs = GR.Runs()
        for i = #runs, 1, -1 do
            local run = runs[i]
            if GR.Count(run) > 0 then
                out[#out + 1] = { run = run }
                for _, e in ipairs(GR.Entries(run)) do out[#out + 1] = { e = e, c = run } end
            end
        end
    elseif type(s) == "table" then
        for _, e in ipairs(GR.Entries(s)) do out[#out + 1] = { e = e, c = s } end
    end
    return out
end

local function fill(r, x)
    if x.run then
        r.time:SetText("")
        r.what:SetText(LABEL .. ("%s, %s"):format(x.run.zone or "?", ns.FmtDay and ns.FmtDay(x.run.start or 0) or "") .. "|r")
        r.result:SetText("")
        r.n:SetText("")
        r.sel:Hide()
        return
    end
    local e = x.e
    r.time:SetText(hm(e.t))
    r.what:SetText(itemText(e.item))
    r.result:SetText(resultText(e))
    r.n:SetText(tostring(choices(e)))
    if e == chosenEntry then r.sel:Show() else r.sel:Hide() end
end

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or T.FONT.head, w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

-- The choices of a roll, the winner first, then by choice and number.
local function detail(x)
    if not x or not x.e then return GREY .. L["Einen Wurf wählen."] .. "|r" end
    local e = x.e
    local list = {}
    for name, p in pairs(e.by or {}) do list[#list + 1] = { name = name, p = p } end
    table.sort(list, function(a, b)
        if (a.name == e.win) ~= (b.name == e.win) then return a.name == e.win end
        local oa, ob = ORDER[a.p.c] or 9, ORDER[b.p.c] or 9
        if oa ~= ob then return oa < ob end
        if (a.p.r or -1) ~= (b.p.r or -1) then return (a.p.r or -1) > (b.p.r or -1) end
        return a.name < b.name
    end)
    local lines = {}
    for _, it in ipairs(list) do
        lines[#lines + 1] = ("%s: %s%s"):format(classColored(it.name, it.p.cls), choiceText(it.p),
            it.name == e.win and (" " .. GREEN .. L["Gewinner"] .. "|r") or "")
    end
    if #lines == 0 then lines[1] = GREY .. L["Noch keine Wahl gesehen."] .. "|r" end
    if e.wait then lines[#lines + 1] = GREY .. L["Ein Teil ist noch geheim (Bosskampf); Amisia liest ihn, sobald es geht."] .. "|r" end
    return table.concat(lines, "\n")
end

function R.Build(f)
    V = CreateFrame("Frame", nil, f)
    V:SetPoint("TOPLEFT", 0, -72)
    V:SetPoint("BOTTOMRIGHT", 0, 0)
    V.source = W.Choice(V, 110, function(v)
        source = v
        chosenEntry = nil
        ns.Refresh()
    end)
    V.source:SetValues({ { "raid", L["Dieser Raid"] }, { "runs", L["Dungeons"] } })
    V.source:SetValue(source)
    W.Tooltip(V.source, L["Würfe"], L["Die Würfe des gewählten Raids oder der Dungeon-Läufe."])
    V.counts = W.Text(V, T.FONT.hint, 470)
    W.Row(V, { V.source, { V.counts, gap = 10, y = -4 } }, T.CHIP_GAP, 0, 0)
    local head = CreateFrame("Frame", nil, V)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, -24)
    head:SetPoint("TOPRIGHT", 0, -24)
    head.time = col(head, 2, 48, L["Zeit"])
    head.what = col(head, 54, 250, L["Gegenstand"])
    head.result = col(head, 308, 226, L["Ergebnis"])
    head.n = col(head, 538, 52, L["Wahl"])
    V.head = head
    V.list = W.List(V, ROWS, ROW_H, function(r)
        r.sel = W.SelectBar(r)
        r.time = col(r, 2, 48, nil, T.FONT.text)
        r.what = col(r, 54, 250, nil, T.FONT.text)
        r.result = col(r, 308, 226, nil, T.FONT.text)
        r.n = col(r, 538, 40, nil, T.FONT.text)
        r:SetScript("OnClick", function(self)
            local x = self.item
            if not x or not x.e then return end
            chosenEntry = x.e
            ns.Refresh()
        end)
    end, fill)
    V.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    V.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -12, 0)
    V.empty = W.EmptyState(V, 440)
    V.empty:SetPoint("TOP", V, "TOP", 0, -100)
    V.title = W.Text(V, T.FONT.title, 590)
    V.title:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", 6, -6)
    V.detail = W.ScrollText(V)
    V.detail:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", 0, -28)
    V.detail:SetPoint("BOTTOMRIGHT", -12, 0)
    V:Hide()
    return V
end

-- The number of rolls of a raid (the chip's label).
function R.Count(s)
    return type(s) == "table" and GR.Count(s) or 0
end

function R.Refresh(view, s)
    V = view
    V.source:SetValue(source)
    nameMissing = false
    local list = items(s)
    local found
    for _, x in ipairs(list) do
        if x.e and x.e == chosenEntry then found = x end
    end
    if not found then
        chosenEntry = nil
        for _, x in ipairs(list) do
            if x.e then found = x chosenEntry = x.e break end
        end
    end
    V.list:SetItems(list)
    local n = 0
    for _, x in ipairs(list) do if x.e then n = n + 1 end end
    if n == 0 then
        V.empty:Set(L["Keine Würfe"], source == "runs" and L["In Dungeons wurde noch nicht um Gruppenloot gewürfelt."]
            or L["In diesem Raid wurde noch nicht um Gruppenloot gewürfelt."])
        V.empty:Show()
        V.head:Hide()
    else
        V.empty:Hide()
        V.head:Show()
    end
    if source == "runs" then
        V.counts:SetText(L["%d Würfe in %d Dungeon-Läufen"]:format(n, #GR.Runs()))
    else
        V.counts:SetText(ns.Get("raidlog.groupRolls") and L["%d Würfe"]:format(n) or L["%d Würfe · Aufzeichnung aus (Einstellungen)"]:format(n))
    end
    V.title:SetText(found and (itemText(found.e.item) .. GREY .. "  " .. hm(found.e.t) .. "|r") or "")
    V.detail:SetText(n > 0 and detail(found) or "")
end

function R.NameMissing() return nameMissing end
