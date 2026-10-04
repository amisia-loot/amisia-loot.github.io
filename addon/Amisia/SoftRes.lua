-- Amisia soft-reserves: a pasted list (softres.it CSV or "Name [item]" lines), shown in item
-- tooltips and on the loot window, and ranked first in roll rounds.
local ADDON, ns = ...

local F, editBox, resultText, dateText
local marks = {}   -- loot button -> "SR" font string

local function shortName(name)
    name = ns.FullName(name)
    if not name then return nil end
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- Splits one CSV line on delim, honouring double quotes.
local function splitCsv(line, delim)
    local out, cur, q, i = {}, "", false, 1
    while i <= #line do
        local ch = line:sub(i, i)
        if q then
            if ch == '"' then
                if line:sub(i + 1, i + 1) == '"' then cur = cur .. '"'; i = i + 1 else q = false end
            else
                cur = cur .. ch
            end
        elseif ch == '"' then
            q = true
        elseif ch == delim then
            out[#out + 1] = cur; cur = ""
        else
            cur = cur .. ch
        end
        i = i + 1
    end
    out[#out + 1] = cur
    return out
end

local function lines(text)
    local out = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

-- A cleaned-up list name after the remembered fixes (AmisiaDB.srAliases, keys in lower case).
-- renamed collects fixed name -> name as written in the list.
local function aliased(name, renamed)
    if not name then return nil end
    local aliases = AmisiaDB and AmisiaDB.srAliases
    local to = type(aliases) == "table" and aliases[name:lower()]
    if type(to) == "string" and to ~= "" and to ~= name then
        if renamed then renamed[to] = renamed[to] or name end
        return to
    end
    return name
end

-- Returns byItem { [itemID] = { names } }, the number of distinct reservations (name and item),
-- the unrecognised lines, times { [itemID] = { [name] = n } } for names that reserved an item more
-- than once, the number of all reservations (doubles included) and renamed { [fixed] = listName }
-- for names a remembered fix changed.
function ns.ParseSoftRes(text)
    local byItem, sets, bad, count, times, total, renamed = {}, {}, {}, 0, {}, 0, {}
    local function add(item, name)
        if not item or not name then return false end
        name = aliased(name, renamed)
        sets[item] = sets[item] or {}
        total = total + 1
        if not sets[item][name] then
            sets[item][name] = 1
            byItem[item] = byItem[item] or {}
            byItem[item][#byItem[item] + 1] = name
            count = count + 1
        else
            sets[item][name] = sets[item][name] + 1
            times[item] = times[item] or {}
            times[item][name] = sets[item][name]
        end
        return true
    end
    local all = lines(text)
    if #all > 0 and all[1]:lower():gsub("%s", ""):find("itemid", 1, true) then
        local head = all[1]
        local delim = (select(2, head:gsub(";", "")) > select(2, head:gsub(",", ""))) and ";" or ","
        local cols = {}
        for i, h in ipairs(splitCsv(head, delim)) do cols[(h:lower():gsub("%s", ""))] = i end
        local cItem = cols["itemid"]
        local cName = cols["name"] or cols["character"] or cols["player"]
        for i = 2, #all do
            local f = splitCsv(all[i], delim)
            local item = cItem and tonumber((f[cItem] or ""):match("(%d+)"))
            local name = cName and shortName(f[cName])
            if not add(item, name) then bad[#bad + 1] = all[i] end
        end
    else
        for _, line in ipairs(all) do
            -- "Name [Item-Link]" or "Name 32235"; the name may hold a space (Forever surnames)
            local item = ns.ItemID(line)
            local name
            if item then
                name = line:match("^(.-)%s*|c") or line:match("^(.-)%s*|H")
            else
                local n, num = line:match("^(.-)[%s,;:\t]+(%d+)%s*$")
                name, item = n, tonumber(num)
            end
            name = name and name:gsub("[%s,;:\t]+$", "")
            -- "Amy 32235 32236" or "Bob: 1, 2" is no name with one item: names hold no digits or separators
            if name and name:find("[%d,;:\t]") then name = nil end
            if not add(item, shortName(name)) then bad[#bad + 1] = line end
        end
    end
    for _, names in pairs(byItem) do table.sort(names) end
    return byItem, count, bad, times, total, renamed
end

-- Stores a pasted list. Returns the number of reservations (doubles included) and the bad lines.
function ns.SetSoftRes(text)
    local byItem, _, bad, times, total, renamed = ns.ParseSoftRes(text)
    AmisiaDB.softres = { version = 2, date = date("%Y-%m-%d"), byItem = byItem, raw = text or "", count = total,
                         times = times, renamed = renamed, reminded = {} }
    ns.MarkLootButtons()
    if ns.Refresh then ns.Refresh() end
    return total, bad
end

-- The list of 1.5 gets the fields of data model 2; called by Core on ADDON_LOADED. Its doubles
-- were merged already and count once. Running it again changes nothing.
function ns.MigrateSoftRes(DB)
    if type(DB) ~= "table" then return end
    DB.srAliases = type(DB.srAliases) == "table" and DB.srAliases or {}
    local sr = DB.softres
    if type(sr) ~= "table" then return end
    sr.byItem = type(sr.byItem) == "table" and sr.byItem or {}
    if not sr.version then
        sr.times, sr.renamed, sr.reminded = {}, {}, {}
        sr.version = 2
    end
    sr.times = type(sr.times) == "table" and sr.times or {}
    sr.renamed = type(sr.renamed) == "table" and sr.renamed or {}
    sr.reminded = type(sr.reminded) == "table" and sr.reminded or {}
end

-- How often name (as in the list) reserved item.
local function timesOf(sr, item, name)
    local t = sr and sr.times and sr.times[item]
    return (t and tonumber(t[name])) or 1
end
ns.SoftResTimes = timesOf

---------------------------------------------------------------------------
-- Check against the raid
---------------------------------------------------------------------------
local function sortedKeys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Who to check against: the raid, else the running recording or the newest raid. Returns the
-- names and a label ("Raid (25)", "letzter Raid, 02.10."), or {} and nil.
function ns.SoftResRoster()
    if IsInRaid() then
        local set, n = {}, GetNumGroupMembers() or 0
        for i = 1, n do
            local name = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
            if name then set[name] = true end
        end
        return sortedKeys(set), ("Raid (%d)"):format(n)
    end
    local s = ns.Active and ns.Active()
    if not s then
        for _, o in ipairs(ns.Sessions and ns.Sessions() or {}) do
            if not s or (o.start or 0) > (s.start or 0) then s = o end
        end
    end
    if not s then return {}, nil end
    return sortedKeys(s.members or {}), "letzter Raid, " .. date("%d.%m.", s.start or time())
end

-- Edit distance of two strings (bytes).
local function distance(a, b)
    if a == b then return 0 end
    local la, lb = #a, #b
    local prev = {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        local cur = { [0] = i }
        local ca = a:byte(i)
        for j = 1, lb do
            local cost = (ca == b:byte(j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        end
        prev = cur
    end
    return prev[lb]
end

local function firstName(name) return (name:match("^(%S+)") or name):lower() end

-- The loaded list (or sr, e.g. a preview from ns.ParseSoftRes) against roster (default
-- ns.SoftResRoster()). Pure: no frames, no chat. nil without a list.
function ns.SoftResCheck(sr, roster)
    sr = sr or (AmisiaDB and AmisiaDB.softres)
    if type(sr) ~= "table" then return nil end
    roster = roster or ns.SoftResRoster()
    local out = { roster = #roster, reservers = 0, ok = {}, missing = {}, absent = {}, unclear = {}, over = {}, multi = {} }
    -- every list name with its sum of reservations
    local sums, multi = {}, {}
    for item, names in pairs(sr.byItem or {}) do
        for _, name in ipairs(names) do
            local n = timesOf(sr, item, name)
            sums[name] = (sums[name] or 0) + n
            if n > 1 then multi[#multi + 1] = { name = name, item = item, n = n } end
        end
    end
    local listNames = sortedKeys(sums)
    out.reservers = #listNames
    local exact = {}
    for _, r in ipairs(roster) do exact[r:lower()] = r end
    local found, lost = {}, {}   -- roster name -> true; list names not in the raid
    for _, name in ipairs(listNames) do
        local hit = exact[name:lower()]
        if hit then
            found[hit] = true
        else
            local cands = {}
            for _, r in ipairs(roster) do
                if ns.SameName(name, r) then cands[#cands + 1] = r end
            end
            table.sort(cands)
            if #cands == 1 then
                found[cands[1]] = true
                if not name:find(" ", 1, true) and cands[1]:find(" ", 1, true) then
                    out.unclear[#out.unclear + 1] = { name = name, kind = "surname", suggest = cands }
                end
            elseif #cands > 1 then
                -- several raiders share this first name: no guess, the officer picks
                lost[#lost + 1] = name
                out.unclear[#out.unclear + 1] = { name = name, kind = "surname", suggest = { cands[1], cands[2], cands[3] } }
            else
                lost[#lost + 1] = name
            end
        end
    end
    for _, r in ipairs(roster) do
        if found[r] then out.ok[#out.ok + 1] = r else out.missing[#out.missing + 1] = r end
    end
    table.sort(out.ok); table.sort(out.missing)
    -- names not in the raid: suggestions among the raiders without a reservation
    local done = {}
    for _, u in ipairs(out.unclear) do done[u.name] = true end
    for _, name in ipairs(lost) do
        out.absent[#out.absent + 1] = name
        if not done[name] then
            local low, sug = name:lower(), {}
            for _, r in ipairs(out.missing) do
                local d = (#name >= 4 and #r >= 4) and distance(low, r:lower()) or 99
                if d <= 2 or firstName(name) == firstName(r) then
                    sug[#sug + 1] = { r = r, d = d }
                end
            end
            if #sug > 0 then
                table.sort(sug, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.r < b.r end)
                local list = {}
                for i = 1, math.min(3, #sug) do list[i] = sug[i].r end
                out.unclear[#out.unclear + 1] = { name = name, kind = "typo", suggest = list }
            end
        end
    end
    table.sort(out.absent)
    table.sort(out.unclear, function(a, b) return a.name < b.name end)
    local limit = tonumber(ns.Get("softres.limit")) or 0
    if limit > 0 then
        for _, name in ipairs(listNames) do
            if sums[name] > limit then out.over[#out.over + 1] = { name = name, n = sums[name] } end
        end
    end
    table.sort(multi, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.item < b.item end)
    out.multi = multi
    return out
end

-- The reservations of a name (over ns.SameName): { { item, n } }, by item name.
function ns.ReservesOf(name)
    local sr = AmisiaDB and AmisiaDB.softres
    local out, at = {}, {}
    for item, names in pairs(sr and sr.byItem or {}) do
        for _, n in ipairs(names) do
            if ns.SameName(n, name) then
                if at[item] then
                    at[item].n = at[item].n + timesOf(sr, item, n)
                else
                    at[item] = { item = item, n = timesOf(sr, item, n) }
                    out[#out + 1] = at[item]
                end
            end
        end
    end
    for _, e in ipairs(out) do e.sort = ns.ItemName(e.item) end
    table.sort(out, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    for _, e in ipairs(out) do e.sort = nil end
    return out
end

-- Renames a name of the loaded list everywhere (a typo, a missing surname). remember: the fix also
-- holds for every later list. Returns the number of items changed; 0 when from is not in the list.
function ns.RenameReserve(from, to, remember)
    local sr = AmisiaDB and AmisiaDB.softres
    to = ns.FullName(to)
    if not sr or type(from) ~= "string" or not to or from == to then return 0 end
    local n = 0
    for item, names in pairs(sr.byItem or {}) do
        local at, has
        for i, name in ipairs(names) do
            if name == from then at = i elseif name == to then has = true end
        end
        if at then
            n = n + 1
            local count = timesOf(sr, item, from)
            table.remove(names, at)
            if has then
                count = count + timesOf(sr, item, to)
            else
                names[#names + 1] = to
                table.sort(names)
            end
            sr.times = sr.times or {}
            local t = sr.times[item]
            if t then t[from] = nil end
            if count > 1 then
                sr.times[item] = t or {}
                sr.times[item][to] = count
            elseif t and next(t) == nil then
                sr.times[item] = nil
            end
        end
    end
    if n == 0 then return 0 end
    sr.renamed = sr.renamed or {}
    sr.renamed[to] = sr.renamed[to] or sr.renamed[from] or from
    sr.renamed[from] = nil
    if remember and AmisiaDB then
        AmisiaDB.srAliases = AmisiaDB.srAliases or {}
        AmisiaDB.srAliases[from:lower()] = to
    end
    ns.MarkLootButtons()
    if ns.Refresh then ns.Refresh() end
    return n
end

function ns.ClearSoftRes()
    AmisiaDB.softres = nil
    ns.MarkLootButtons()
    if ns.Refresh then ns.Refresh() end
end

function ns.ReservedBy(item)
    local sr = AmisiaDB and AmisiaDB.softres
    local names = sr and sr.byItem and sr.byItem[tonumber(item) or 0]
    return names or {}
end

function ns.SoftResInfo()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return nil end
    return sr.date, sr.count or 0
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function tooltipLink(tip)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tip)
        return link
    end
    if tip.GetItem then
        local _, link = tip:GetItem()
        return link
    end
end

-- The group as plain names (secret ones left out), or nil when alone.
local function groupNames()
    if not IsInGroup() then return nil end
    local out = {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then out[#out + 1] = n end
    end
    return out
end

-- "Reserviert: Fraktur, du x2 (+1 außerhalb)": in a group (softres.tooltipGroup) only reservers
-- from it, the others counted.
function ns.SoftResTooltipText(id)
    local sr = AmisiaDB and AmisiaDB.softres
    local names = ns.ReservedBy(id)
    if #names == 0 then return nil end
    local group = ns.Get("softres.tooltipGroup") and groupNames() or nil
    local me = ns.UnitFullName("player")
    local shown, outside = {}, 0
    for _, name in ipairs(names) do
        local inGroup = not group
        if group then
            for _, g in ipairs(group) do
                if ns.SameName(g, name) then inGroup = true break end
            end
        end
        if inGroup then
            local label = ns.SameName(name, me) and "du" or name
            local n = timesOf(sr, id, name)
            shown[#shown + 1] = n > 1 and ("%s x%d"):format(label, n) or label
        else
            outside = outside + 1
        end
    end
    local text = "Reserviert: " .. (#shown > 0 and table.concat(shown, ", ") or "niemand aus der Gruppe")
    if outside > 0 then text = text .. (" (+%d außerhalb)"):format(outside) end
    return text
end

-- One line per tooltip build: a tooltip can be handed to the hook twice for the same item.
-- The mark goes when the tooltip is cleared.
local marked = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })

local function addLineBody(tip)
    if not tip or not tip.AddLine then return end
    if not ns.Get("softres.tooltip") then return end
    local link = tooltipLink(tip)
    local id = ns.ItemID(link)
    if not id then return end
    if not watched[tip] and tip.HookScript then
        watched[tip] = true
        tip:HookScript("OnTooltipCleared", function(self) marked[self] = nil end)
    end
    if marked[tip] == link then return end
    local text = ns.SoftResTooltipText(id)
    if not text then return end
    marked[tip] = link
    tip:AddLine(text, 0.89, 0.72, 0.34)
end

-- Protected: an error here must never break the tooltip or other addons' lines.
local function addLine(tip)
    local ok, err = pcall(addLineBody, tip)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

-- Both clients have the tooltip data processor (it also serves SetLootRollItem and SetHyperlink);
-- the item script is the fallback for a client without it.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLine)
else
    GameTooltip:HookScript("OnTooltipSetItem", addLine)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", addLine) end
end

---------------------------------------------------------------------------
-- Loot window marks
---------------------------------------------------------------------------
local function markButton(btn, slot)
    if not ns.Get("softres.lootMark") then
        if marks[btn] then marks[btn]:Hide() end
        return
    end
    local link = slot and GetLootSlotLink and GetLootSlotLink(slot)
    local reserved = link and #ns.ReservedBy(ns.ItemID(link)) > 0
    local mark = marks[btn]
    if reserved and not mark then
        mark = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        mark:SetText("SR")
        mark:SetTextColor(0.89, 0.72, 0.34)
        marks[btn] = mark
    end
    if mark then
        if reserved then mark:Show() else mark:Hide() end
    end
end

-- For tests and the window: whether a loot button carries a visible mark.
function ns.SoftResMarkShown(btn)
    local m = marks[btn]
    return (m and m:IsShown()) and true or false
end

function ns.MarkLootButtons()
    local n = LOOTFRAME_NUMBUTTONS or 4
    for i = 1, n do
        local btn = _G["LootButton" .. i]
        if btn and btn.slot and btn.IsShown and btn:IsShown() then
            markButton(btn, btn.slot)
        elseif btn and marks[btn] then
            marks[btn]:Hide()
        end
    end
    local box = LootFrame and LootFrame.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(function(frame)
            if frame.GetSlotIndex then markButton(frame, frame:GetSlotIndex()) end
        end)
    end
end

ns.OnEvent("LOOT_OPENED", function() C_Timer.After(0, ns.MarkLootButtons) end)
ns.OnEvent("LOOT_SLOT_CLEARED", function() C_Timer.After(0, ns.MarkLootButtons) end)
if type(LootFrame_Update) == "function" then
    hooksecurefunc("LootFrame_Update", ns.MarkLootButtons)
end

---------------------------------------------------------------------------
-- Import window
---------------------------------------------------------------------------
local function refresh()
    if not F or not F:IsShown() then return end
    local sr = AmisiaDB.softres
    if sr then
        local today = date("%Y-%m-%d")
        dateText:SetText(sr.date == today
            and ("|cff4fbf7aListe von heute:|r %d Reservierungen"):format(sr.count or 0)
            or ("|cffe0a344Liste vom %s:|r %d Reservierungen. Fuer einen neuen Raid neu einfuegen."):format(sr.date, sr.count or 0))
        if editBox:GetText() == "" then editBox:SetText(sr.raw or "") end
    else
        dateText:SetText("|cff8f86a3Keine Soft-Reserves.|r softres.it-CSV oder Zeilen wie 'Name [Item-Link]' einfuegen.")
    end
end

local function build()
    F = CreateFrame("Frame", "AmisiaSoftResFrame", UIParent)
    F:SetSize(440, 340)
    F:SetPoint("CENTER", 0, 40)
    F:SetFrameStrata("FULLSCREEN_DIALOG")
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    F:SetScript("OnShow", refresh)
    F:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaSoftResFrame") end

    local bg = F:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.04, 0.08, 0.96)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = F:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.89, 0.72, 0.34, 0.6)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) end
        if e[4] then t:SetHeight(e[4]) end
    end

    local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Soft-Reserves")
    title:SetTextColor(0.89, 0.72, 0.34)

    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    dateText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dateText:SetPoint("TOPLEFT", 12, -32)
    dateText:SetWidth(410)
    dateText:SetJustifyH("LEFT")

    local boxBg = CreateFrame("Frame", nil, F)
    boxBg:SetPoint("TOPLEFT", 12, -50)
    boxBg:SetPoint("BOTTOMRIGHT", -12, 64)
    local bb = boxBg:CreateTexture(nil, "BACKGROUND")
    bb:SetAllPoints()
    bb:SetColorTexture(0, 0, 0, 0.45)

    local scroll = CreateFrame("ScrollFrame", "AmisiaSoftResScroll", boxBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(380)
    editBox:SetHeight(200)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(editBox)
    boxBg:EnableMouse(true)
    boxBg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    resultText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultText:SetPoint("BOTTOMLEFT", 12, 40)
    resultText:SetWidth(410)
    resultText:SetJustifyH("LEFT")

    local apply = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    apply:SetSize(110, 22)
    apply:SetPoint("BOTTOMLEFT", 12, 10)
    apply:SetText("Uebernehmen")
    apply:SetScript("OnClick", function()
        local count, bad = ns.SetSoftRes(editBox:GetText())
        resultText:SetText(("%d Reservierungen uebernommen, %d Zeilen nicht erkannt."):format(count, #bad)
            .. (#bad > 0 and (" Erste: " .. bad[1]:sub(1, 40)) or ""))
        refresh()
    end)

    local clear = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    clear:SetSize(90, 22)
    clear:SetPoint("LEFT", apply, "RIGHT", 6, 0)
    clear:SetText("Leeren")
    clear:SetScript("OnClick", function()
        ns.ClearSoftRes()
        editBox:SetText("")
        resultText:SetText("Liste geleert.")
        refresh()
    end)
    F.editBox, F.resultText, F.dateText, F.applyBtn, F.clearBtn = editBox, resultText, dateText, apply, clear
    ns.SoftResFrame = F
end

function ns.ToggleSoftResFrame()
    if not F then build() end
    if F:IsShown() then F:Hide() else F:Show() end
end

ns.RegisterSettings{ key = "softres", label = "Soft-Reserves", order = 30, items = {
    { key = "softres.tooltip", type = "toggle", label = "Tooltip-Zeile \"Reserviert: ...\"", default = true },
    { key = "softres.lootMark", type = "toggle", label = "SR-Markierung im Lootfenster", default = true,
      onChange = function() ns.MarkLootButtons() end },
    { key = "softres.warnDays", type = "slider", label = "Warnen, wenn die Liste älter ist als (Tage)", default = 7, min = 1, max = 30, step = 1 },
    { key = "softres.tooltipGroup", type = "toggle", label = "Im Tooltip nur Reservierungen aus der Gruppe", default = true },
    { key = "softres.limit", type = "slider", label = "Reservierungen pro Raider (0 = keine Prüfung)", default = 0, min = 0, max = 6, step = 1,
      officer = true },
}}
ns.RegisterSlash("sr", { desc = "Soft-Reserves anzeigen", run = function()
    if ns.ShowPage then ns.ShowPage("softres") else ns.ToggleSoftResFrame() end
end })
