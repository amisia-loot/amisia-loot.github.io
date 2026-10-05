-- Soft-reserves: the loaded list in three views (items, raiders, the check against the raid),
-- name fixes with one click, importing and clearing for officers, and the overview card.
local ADDON, ns = ...
local W = ns.W
local GOLD = W.GOLD
local ROWS, ROW_H = 14, 22
local GREY, ORANGE, RED = "|cff8f86a3", "|cffe0a344", "|cffff5050"
local MAX_CHIPS, CHIP_MAX_W = 3, 104
-- the columns of a row; the content is 602 px wide
local COL_A, COL_A_W, COL_B, COL_B_W, COL_C, COL_C_W = 6, 228, 238, 30, 272, 324

local GetItemInfo = C_Item.GetItemInfo

local page
local view = "items"   -- the chosen view, kept until logout

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function plural(n, one, many) return n == 1 and one or many end

local QCOLOR = { [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80" }
local function quality(id)
    local known = AmisiaDB and AmisiaDB.itemNames and AmisiaDB.itemNames[id]
    local q = known and known.q
    if not q or q == 0 then
        local _, _, iq = GetItemInfo(id)
        q = iq or q
    end
    return q or 0
end

local function itemText(id)
    return ("|cff%s%s|r"):format(QCOLOR[quality(id)] or "ffffff", ns.ItemName(id))
end

local function itemLink(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. tostring(id))
end

-- Puts a link into the chat the way the client does (ChatFrameUtil.InsertLink).
local function insertLink(link)
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        return ChatFrameUtil.InsertLink(link)
    end
end

local function times(sr, item, name) return ns.SoftResTimes(sr, item, name) end

local function withTimes(text, n) return n > 1 and ("%s x%d"):format(text, n) or text end

local function set(list)
    local out = {}
    for _, v in ipairs(list or {}) do out[v] = true end
    return out
end

-- What a refresh works with: the list, the roster, the check, the class of every raid member and
-- the list names outside the raid.
local function context()
    local sr = AmisiaDB and AmisiaDB.softres
    local roster, label = ns.SoftResRoster()
    local ctx = { sr = sr, roster = roster, label = label, classes = {}, absent = {} }
    ctx.check = sr and ns.SoftResCheck(sr, roster) or nil
    if ctx.check then ctx.absent = set(ctx.check.absent) end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            name = ns.FullName(ns.Plain(name))
            if name then ctx.classes[name:lower()] = ns.Plain(class) end
        end
    end
    return ctx
end

-- The class of a list name: the raid member it means, by spelling, else by ns.SameName.
local function classOf(ctx, name)
    local class = ctx.classes[name:lower()]
    if class then return class end
    for _, r in ipairs(ctx.roster) do
        if ns.SameName(r, name) then return ctx.classes[r:lower()] end
    end
    return nil
end

local function coloured(ctx, name)
    if ctx.absent[name] then return GREY .. name .. " (nicht im Raid)|r" end
    local class = classOf(ctx, name)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and ("|c%s%s|r"):format(c.colorStr, name) or name
end

-- Every list name with its items { item, n } and the sum of its reservations.
local function byName(sr)
    local out = {}
    for item, names in pairs(sr and sr.byItem or {}) do
        for _, name in ipairs(names) do
            local e = out[name]
            if not e then
                e = { name = name, items = {}, n = 0 }
                out[name] = e
            end
            local n = times(sr, item, name)
            e.items[#e.items + 1] = { item = item, n = n, sort = ns.ItemName(item) }
            e.n = e.n + n
        end
    end
    for _, e in pairs(out) do
        table.sort(e.items, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    end
    return out
end

local function itemsText(items)
    local parts = {}
    for _, it in ipairs(items) do parts[#parts + 1] = withTimes(ns.ItemName(it.item), it.n) end
    return table.concat(parts, ", ")
end

-- "Abgleich mit Raid (25): 22 reserviert · 3 ohne · ..." from the check.
local function checkLine(ctx)
    local c = ctx.check
    if not c then return "" end
    if not ctx.label then return "Kein Raid zum Abgleichen." end
    local parts = { ("Abgleich mit %s: %d reserviert"):format((ctx.label:gsub("^letzter ", "letztem ")), #c.ok) }
    if #c.missing > 0 then parts[#parts + 1] = ("%d ohne"):format(#c.missing) end
    if #c.absent > 0 then parts[#parts + 1] = ("%d nicht im Raid"):format(#c.absent) end
    if #c.unclear > 0 then parts[#parts + 1] = ("%d unklar"):format(#c.unclear) end
    if #c.over > 0 then parts[#parts + 1] = ("%d zu viel"):format(#c.over) end
    return table.concat(parts, " · ")
end

---------------------------------------------------------------------------
-- The rows of the three views
---------------------------------------------------------------------------
local function itemRows(ctx, me)
    local out = {}
    for item, names in pairs(ctx.sr and ctx.sr.byItem or {}) do
        local parts, mine = {}, false
        for _, name in ipairs(names) do
            local label = withTimes(name, times(ctx.sr, item, name))
            parts[#parts + 1] = ctx.absent[name] and (GREY .. label .. " (nicht im Raid)|r") or label
            if me and ns.SameName(name, me) then mine = true end
        end
        out[#out + 1] = { kind = "item", item = item, sort = ns.ItemName(item), text = table.concat(parts, ", "), mine = mine }
    end
    table.sort(out, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    return out
end

local function raiderRows(ctx, me)
    local limit = tonumber(ns.Get("softres.limit")) or 0
    local out = {}
    for name, e in pairs(byName(ctx.sr)) do
        out[#out + 1] = { kind = "raider", name = name, n = e.n, over = limit > 0 and e.n > limit,
                          text = itemsText(e.items), mine = me and ns.SameName(name, me) or false,
                          was = ctx.sr and ctx.sr.renamed and ctx.sr.renamed[name] or nil }
    end
    for _, name in ipairs(ctx.check and ctx.check.missing or {}) do
        out[#out + 1] = { kind = "raider", name = name, n = 0, text = "keine", mine = me and ns.SameName(name, me) or false }
    end
    table.sort(out, function(a, b)
        local la, lb = a.name:lower(), b.name:lower()
        if la ~= lb then return la < lb end
        return a.n > b.n
    end)
    return out
end

-- One row per finding: unclear, too many, without a reservation, not in the raid, doubles.
local function checkRows(ctx)
    local c, sr = ctx.check, ctx.sr
    local out = {}
    if not c then return out end
    local names = byName(sr)
    local unclear = {}
    for _, u in ipairs(c.unclear) do
        unclear[u.name] = true
        out[#out + 1] = { kind = "unclear", name = u.name, suggest = u.suggest,
                          label = ORANGE .. "Unklar:|r " .. u.name .. (u.kind == "surname" and " (ohne Nachnamen)" or " (Schreibweise?)") }
    end
    local limit = tonumber(ns.Get("softres.limit")) or 0
    for _, o in ipairs(c.over) do
        out[#out + 1] = { kind = "over", name = o.name, label = RED .. "Zu viel:|r " .. o.name,
                          text = ("%d Reservierungen, erlaubt %d"):format(o.n, limit) }
    end
    local reminded = sr and sr.reminded or {}
    for _, name in ipairs(c.missing) do
        local at = tonumber(reminded[name])
        out[#out + 1] = { kind = "missing", name = name, label = "Ohne Reserve: " .. name,
                          text = at and ("erinnert " .. date("%H:%M", at)) or "" }
    end
    for _, name in ipairs(c.absent) do
        if not unclear[name] then
            out[#out + 1] = { kind = "absent", name = name, label = GREY .. "Nicht im Raid:|r " .. name,
                              text = names[name] and itemsText(names[name].items) or "" }
        end
    end
    for _, m in ipairs(c.multi) do
        out[#out + 1] = { kind = "multi", name = m.name, label = GREY .. "Mehrfach:|r " .. m.name,
                          text = withTimes(ns.ItemName(m.item), m.n) }
    end
    return out
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
function ns.SoftResPageFrame() return page end

-- Opens the page on one view ("items", "raider", "check").
function ns.ShowSoftRes(v)
    if v == "items" or v == "raider" or v == "check" then view = v end
    ns.ShowPage("softres")
end

local function chooseView(v)
    view = v
    ns.Refresh()
end

local function col(parent, x, w, template)
    local fs = W.Text(parent, template or "GameFontHighlightSmall", w)
    fs:SetPoint("LEFT", x, 0)
    return fs
end

local HEADS = {
    items = { "Item", "", "Reserviert von" },
    raider = { "Raider", "SR", "Items" },
    check = { "Befund", "", "Vorschläge und Details" },
}

local function buildRow(r)
    r.sel = W.Flat(r, GOLD[1], GOLD[2], GOLD[3], 0.18, "BORDER")
    r.sel:Hide()
    r.a = col(r, COL_A, COL_A_W)
    r.b = col(r, COL_B, COL_B_W)
    r.c = col(r, COL_C, COL_C_W)
    r.chips = {}
    for i = 1, MAX_CHIPS do
        local chip = W.Chip(r, "", 60, function(self)
            if not self.from or not self.to then return end
            local from, to = self.from, self.to
            if ns.RenameReserve(from, to, true) > 0 then
                ns.msg(("Soft-Reserves: %s heißt jetzt %s, auch in kommenden Listen."):format(from, to))
            end
        end)
        if i == 1 then
            chip:SetPoint("LEFT", COL_C, 0)
        else
            chip:SetPoint("LEFT", r.chips[i - 1], "RIGHT", 4, 0)
        end
        chip:SetOn(false)
        chip:Hide()
        r.chips[i] = chip
    end
    r:SetScript("OnClick", function(self)
        local e = self.item
        if e and e.kind == "item" and IsShiftKeyDown and IsShiftKeyDown() then insertLink(itemLink(e.item)) end
    end)
    r:SetScript("OnEnter", function(self)
        local e = self.item
        if not e then return end
        if e.kind == "item" and GameTooltip.SetHyperlink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(e.item))
            GameTooltip:Show()
        elseif e.kind == "unclear" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(e.name, 1, 0.82, 0)
            GameTooltip:AddLine("Ein Klick auf einen Vorschlag korrigiert den Namen in der Liste und merkt die Korrektur für kommende Listen.",
                0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        elseif e.kind == "raider" and e.was then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(e.name, 1, 0.82, 0)
            GameTooltip:AddLine(("In der Liste als %s, korrigiert."):format(e.was), 0.85, 0.85, 0.85, true)
            if ns.SoftResAlias(e.was) then
                GameTooltip:AddLine(("Die Korrektur gilt auch für kommende Listen. \"/amisia sr vergessen %s\" nimmt sie zurück, ohne Namen vergisst es alle gemerkten Korrekturen."):format(e.was),
                    0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Every field of a pooled row is set here, so nothing of an earlier entry stays.
local function fillRow(r, e)
    local ctx = page and page.ctx
    local raiderView = not ns.IsOfficerView()
    r.b:SetText("")
    r.c:SetText("")
    local shownChips = 0
    if e.kind == "item" then
        r.a:SetText(itemText(e.item))
        r.c:SetText(e.text)
    elseif e.kind == "raider" then
        local was = e.was
        r.a:SetText((ctx and coloured(ctx, e.name) or e.name) .. (was and (GREY .. " (Liste: " .. was .. ")|r") or ""))
        r.b:SetText(e.over and (RED .. e.n .. "|r") or tostring(e.n))
        r.c:SetText(e.text)
    else
        r.a:SetText(e.label)
        if e.kind == "unclear" then
            for i, name in ipairs(e.suggest or {}) do
                if i > MAX_CHIPS then break end
                local chip = r.chips[i]
                chip.label:SetText(name)
                chip:SetWidth(math.min(CHIP_MAX_W, (chip.label:GetStringWidth() or 60) + 16))
                chip.from, chip.to = e.name, name
                chip:SetOn(false)
                chip:Show()
                shownChips = i
            end
        else
            r.c:SetText(e.text or "")
        end
    end
    for i = shownChips + 1, MAX_CHIPS do
        local chip = r.chips[i]
        chip.from, chip.to = nil, nil
        chip:Hide()
    end
    if raiderView and e.mine then r.sel:Show() else r.sel:Hide() end
end

ns.RegisterPanel{ key = "softres", label = "Soft-Reserves", icon = "Interface\\Icons\\INV_Scroll_03", order = 40,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        page = f
        -- line 1: the list, import and clear on the right
        f.state = W.Text(f, "GameFontHighlight", 390)
        f.state:SetPoint("TOPLEFT", 0, -2)
        f.clear = W.Button(f, "Löschen", 90, function() ns.ClearSoftRes() end)
        f.clear:SetPoint("TOPRIGHT", 0, 0)
        f.import = W.Button(f, "Importieren", 110, function() ns.ToggleSoftResFrame() end)
        f.import:SetPoint("RIGHT", f.clear, "LEFT", -6, 0)
        -- line 2: the check
        f.check = W.Text(f, "GameFontHighlightSmall", 590)
        f.check:SetPoint("TOPLEFT", 0, -28)
        -- line 3: the views
        f.views = {}
        f.views.items = W.Chip(f, "Items", 60, function() chooseView("items") end)
        f.views.items:SetPoint("TOPLEFT", 0, -50)
        f.views.raider = W.Chip(f, "Raider", 60, function() chooseView("raider") end)
        f.views.raider:SetPoint("LEFT", f.views.items, "RIGHT", 4, 0)
        f.views.check = W.Chip(f, "Abgleich", 70, function() chooseView("check") end)
        f.views.check:SetPoint("LEFT", f.views.raider, "RIGHT", 4, 0)
        -- officers: remind and post on the right of the views
        f.post = W.Button(f, "Im Raid posten", 120, function()
            local n, why = ns.PostSoftResSummary()
            if not n and why then ns.msg(why) end
        end)
        f.post:SetPoint("TOPRIGHT", 0, -49)
        f.remind = W.Button(f, "Erinnern", 110, function() ns.ConfirmSoftResReminders() end)
        f.remind:SetPoint("RIGHT", f.post, "LEFT", -6, 0)
        W.Tooltip(f.remind, "Erinnern", "Flüstert jedem im Raid ohne Reservierung einmal pro Liste, nach einer Rückfrage.")
        W.Tooltip(f.post, "Im Raid posten", "Wie viele reserviert haben und wer noch nicht, in den Schlachtzugschat.")
        -- column heads
        local head = CreateFrame("Frame", nil, f)
        head:SetHeight(18)
        head:SetPoint("TOPLEFT", 0, -76)
        head:SetPoint("TOPRIGHT", 0, -76)
        f.heads = { col(head, COL_A, COL_A_W, "GameFontNormalSmall"), col(head, COL_B, COL_B_W, "GameFontNormalSmall"),
                    col(head, COL_C, COL_C_W, "GameFontNormalSmall") }
        f.list = W.List(f, ROWS, ROW_H, buildRow, fillRow)
        f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
        f.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
        f.hint = W.Text(f, "GameFontDisableSmall", 590, true)
        f.hint:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 6, -8)
        return f
    end,
    refresh = function(f)
        local officer = ns.IsOfficerView()
        local ctx = context()
        f.ctx = ctx
        local sr = ctx.sr
        if sr then
            local old = ns.SoftResAge(sr) or 0
            local warn = old > (ns.Get("softres.warnDays") or 7)
            local reservers = ctx.check and ctx.check.reservers or 0
            f.state:SetText(("%sListe vom %s:|r %d Reservierungen von %d %s%s"):format(warn and ORANGE or "|cff4fbf7a",
                ns.SoftResShortDate(sr.date), sr.count or 0, reservers, plural(reservers, "Raider", "Raidern"),
                warn and (", " .. old .. " Tage alt") or ""))
        else
            f.state:SetText(GREY .. "Keine Soft-Reserves geladen.|r")
        end
        f.check:SetText(checkLine(ctx))
        f.views.items:Show(); f.views.raider:Show()
        if officer then
            f.import:Show(); f.clear:Show()
            f.clear:SetEnabled(sr ~= nil)
            f.views.check:Show()
            local raid = IsInRaid() and sr ~= nil
            local open = raid and #ns.SoftResReminders(ctx.check) or 0
            f.remind:SetText(("Erinnern (%d)"):format(open))
            f.remind:SetEnabled(raid and open > 0)
            f.post:SetEnabled(raid)
            f.remind:Show(); f.post:Show()
        else
            f.import:Hide(); f.clear:Hide()
            f.views.check:Hide()
            f.remind:Hide(); f.post:Hide()
        end
        local shown = view
        if shown == "check" and not officer then shown = "items" end
        for key, chip in pairs(f.views) do chip:SetOn(key == shown) end
        for i, text in ipairs(HEADS[shown]) do f.heads[i]:SetText(text) end
        local me = ns.UnitFullName("player")
        local list
        if shown == "raider" then
            list = raiderRows(ctx, me)
        elseif shown == "check" then
            list = checkRows(ctx)
        else
            list = itemRows(ctx, me)
        end
        f.list:SetItems(list)
        if not sr then
            f.hint:SetText(officer and "Importieren nimmt eine softres.it-CSV oder Zeilen wie 'Name [Item-Link]'." or "")
        elseif shown == "check" then
            f.hint:SetText(#list == 0 and "Nichts zu prüfen." or "Vorschläge korrigieren den Namen und gelten auch für kommende Listen.")
        elseif shown == "items" then
            f.hint:SetText("Shift-Klick auf ein Item fügt den Link in den Chat ein.")
        else
            f.hint:SetText("")
        end
    end }

-- The roster changed: the check may have changed with it. A burst of updates (a 40-man raid
-- forming) makes one refresh half a second later.
local rosterPending = false
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    if rosterPending then return end
    rosterPending = true
    C_Timer.After(0.5, function()
        rosterPending = false
        local cur = ns.CurrentPage and ns.CurrentPage()
        if cur == "softres" or cur == "overview" then ns.Refresh() end
    end)
end)

ns.RegisterCard{ key = "softres", order = 20, fill = function(c)
    local sr = AmisiaDB and AmisiaDB.softres
    c.title:SetText("Soft-Reserves")
    if not sr then
        c.line1:SetText("Keine Liste geladen")
        if ns.IsOfficerView() then c:SetAction("Importieren", function() ns.ToggleSoftResFrame() end) end
        return
    end
    c.line1:SetText(("%d Reservierungen, vom %s"):format(sr.count or 0, sr.date))
    local roster, label = ns.SoftResRoster()
    local chk = ns.SoftResCheck(sr, roster)
    local unclear = chk and #chk.unclear or 0
    local tail = unclear > 0 and (" · %d %s unklar"):format(unclear, plural(unclear, "Name", "Namen")) or ""
    if not label or not chk then
        c.line2:SetText("")
    elseif IsInRaid() then
        c.line2:SetText(("%d von %d im Raid reserviert"):format(#chk.ok, chk.roster) .. tail)
    else
        c.line2:SetText("Abgleich mit letztem Raid: "
            .. (#chk.missing > 0 and ("%d ohne Reserve"):format(#chk.missing) or "alle reserviert") .. tail)
    end
    if ns.IsOfficerView() and unclear > 0 then
        c:SetAction("Prüfen", function() ns.ShowSoftRes("check") end)
    else
        c:SetAction("Ansehen", function() ns.ShowPage("softres") end)
    end
end }
