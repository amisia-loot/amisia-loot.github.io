-- Amisia soft-reserves: a pasted list (softres.it CSV or "Name [item]" lines), shown in item
-- tooltips and on the loot window, and ranked first in roll rounds.
local ADDON, ns = ...

-- Forever has no GetItemInfo global; both clients have C_Item.
local GetItemInfo = _G.GetItemInfo or (C_Item and C_Item.GetItemInfo)

local F, editBox, resultText, dateText, previewText
local previewGen = 0   -- the newest pending preview; older timers do nothing
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

-- The reservations of a name (over ns.SameNameIn with roster, default the group): { { item, n } },
-- by item name. A bare first name on the list counts only while one raider carries it.
function ns.ReservesOf(name, roster)
    local sr = AmisiaDB and AmisiaDB.softres
    roster = roster or ns.GroupRoster()
    local out, at = {}, {}
    for item, names in pairs(sr and sr.byItem or {}) do
        for _, n in ipairs(names) do
            if ns.SameNameIn(n, name, roster) then
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
    local lowFrom, lowTo = from:lower(), to:lower()
    local n, listName = 0, nil
    for item, names in pairs(sr.byItem or {}) do
        local at, has
        for i, name in ipairs(names) do
            local low = name:lower()
            if not at and low == lowFrom then at = i elseif low == lowTo then has = name end
        end
        if at then
            n = n + 1
            -- the spellings as the list holds them; "vulo" finds "Vulo"
            local old = names[at]
            listName = listName or old
            local count = timesOf(sr, item, old)
            table.remove(names, at)
            if has then
                count = count + timesOf(sr, item, has)
                if has ~= to then
                    for i, name in ipairs(names) do
                        if name == has then names[i] = to end
                    end
                    table.sort(names)
                end
            else
                names[#names + 1] = to
                table.sort(names)
            end
            sr.times = sr.times or {}
            local t = sr.times[item]
            if t then
                t[old] = nil
                if has then t[has] = nil end
            end
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
    for k, v in pairs(sr.renamed) do
        if k:lower() == lowFrom and k ~= to then
            sr.renamed[to] = sr.renamed[to] or v
            sr.renamed[k] = nil
        end
    end
    if listName ~= to then sr.renamed[to] = sr.renamed[to] or listName end
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

-- "05.10." from the list's "2026-10-05".
function ns.SoftResShortDate(iso)
    local m, d = tostring(iso or ""):match("^%d+%-(%d+)%-(%d+)$")
    return d and (d .. "." .. m .. ".") or tostring(iso or "?")
end

-- Whole days since the list was loaded, or nil without a list or date.
function ns.SoftResAge(sr)
    sr = sr or (AmisiaDB and AmisiaDB.softres)
    local y, m, d = tostring(sr and sr.date or ""):match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return t and math.max(0, math.floor((time() - t) / 86400)) or nil
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
    -- "du" for a bare first name only while no one else in the group carries it
    local roster = group or groupNames() or {}
    local shown, outside = {}, 0
    for _, name in ipairs(names) do
        local inGroup = not group
        if group then
            for _, g in ipairs(group) do
                if ns.SameName(g, name) then inGroup = true break end
            end
        end
        if inGroup then
            local label = ns.SameNameIn(name, me, roster) and "du" or name
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
-- Chat: reminders, the raid summary and !sr for raiders without the addon
---------------------------------------------------------------------------
local REPLY_GAP = 15       -- seconds between two answers to one sender
local REPLY_PER_MIN = 20   -- answers a minute in all
local REPLY_LINES = 3      -- lines of one answer
local SUMMARY_LINES = 2
local REMIND_TEXT = "Amisia: Du hast für heute noch nichts reserviert."

-- Lines of head and parts (ns.ChatLines) within maxLines: the parts that do not fit become
-- "und n weitere" at the end of the last part kept. suffix goes after the last part.
local function cappedLines(head, parts, maxLines, sep, suffix)
    suffix = suffix or ""
    local function build(list)
        if #list == 0 then return ns.ChatLines(head .. suffix, {}, sep) end
        local copy = {}
        for i, p in ipairs(list) do copy[i] = p end
        copy[#copy] = copy[#copy] .. suffix
        return ns.ChatLines(head, copy, sep)
    end
    local lines = build(parts)
    if #lines <= maxLines then return lines end
    for k = #parts - 1, 0, -1 do
        local cut = {}
        for i = 1, k do cut[i] = parts[i] end
        local more = ("und %d weitere"):format(#parts - k)
        if k > 0 then cut[k] = cut[k] .. " " .. more else cut[1] = more end
        lines = build(cut)
        if #lines <= maxLines then return lines end
    end
    return { lines[1] }
end

-- The raw name of a raid member as the roster gives it (Anniversary may add a realm), for whispers.
local function rawRosterName(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local raw = ns.Plain((GetRaidRosterInfo(i)))
        if type(raw) == "string" and ns.FullName(raw) == name then return raw end
    end
    return name
end

-- Raid members without a reservation who were not reminded for this list yet; never oneself.
-- check: a ns.SoftResCheck of the list against the raid, when the caller has one already.
function ns.SoftResReminders(check)
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or not IsInRaid() then return {} end
    local c = check or ns.SoftResCheck(sr)
    local me = ns.UnitFullName("player")
    local out = {}
    for _, name in ipairs(c and c.missing or {}) do
        if not (sr.reminded and sr.reminded[name]) and not ns.SameName(name, me) then out[#out + 1] = name end
    end
    return out
end

local LOCKED = "Chat ist gerade gesperrt (Bosskampf). Nach dem Kampf erneut."

-- Whispers everyone of ns.SoftResReminders() once (ttl 120) and marks them. Returns the number,
-- and the reason when nothing could be sent. Never in the chat lockdown: a whisper queued there
-- may run out unsent, and the raider would count as reminded.
function ns.SendSoftResReminders()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return 0 end
    if ns.ChatLocked and ns.ChatLocked() then return 0, LOCKED end
    local extra = ns.Get("softres.remindText")
    local text = REMIND_TEXT .. ((type(extra) == "string" and extra ~= "") and (" " .. extra) or "")
    local n = 0
    sr.reminded = sr.reminded or {}
    for _, name in ipairs(ns.SoftResReminders()) do
        if ns.Say(text, "WHISPER", rawRosterName(name), { ttl = 120 }) then
            sr.reminded[name] = time()
            n = n + 1
        end
    end
    if ns.Refresh then ns.Refresh() end
    return n
end

-- Asks before whispering (officers, in a raid). The dialog is lifted above the main window.
function ns.ConfirmSoftResReminders()
    if not ns.IsOfficerView() then ns.msg("Erinnern nur in der Offiziersansicht.") return end
    if not (AmisiaDB and AmisiaDB.softres) then ns.msg("Keine Soft-Reserves geladen.") return end
    if not IsInRaid() then ns.msg("Erinnern geht nur im Raid.") return end
    if ns.ChatLocked and ns.ChatLocked() then ns.msg(LOCKED) return end
    local n = #ns.SoftResReminders()
    if n == 0 then ns.msg("Alle ohne Reserve wurden schon erinnert.") return end
    local d = StaticPopup_Show("AMISIA_SR_REMIND", n)
    if d and d.SetFrameStrata then d:SetFrameStrata("FULLSCREEN_DIALOG"); if d.Raise then d:Raise() end end
end

StaticPopupDialogs["AMISIA_SR_REMIND"] = {
    text = "%d Raidern ohne Reserve flüstern?",
    button1 = "Flüstern",
    button2 = "Abbrechen",
    OnAccept = function()
        local n, why = ns.SendSoftResReminders()
        ns.msg(why or ("%d Raider erinnert."):format(n))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- "Soft-Reserves: 22 von 25 haben reserviert. Ohne Reserve: ..." in the raid chat, two lines at
-- most. Returns the number of lines, or nil and the reason.
function ns.PostSoftResSummary()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return nil, "Keine Soft-Reserves geladen." end
    if not IsInRaid() then return nil, "Posten geht nur im Raid." end
    local c = ns.SoftResCheck(sr)
    local lines
    if #c.missing == 0 then
        lines = { ("Soft-Reserves: alle %d haben reserviert."):format(c.roster) }
    else
        lines = cappedLines(("Soft-Reserves: %d von %d haben reserviert. Ohne Reserve: "):format(#c.ok, c.roster),
            c.missing, SUMMARY_LINES, ", ", ".")
    end
    for _, line in ipairs(lines) do ns.Say(line, "RAID") end
    return #lines
end

-- The check as lines for one's own chat (/amisia sr pruefen).
function ns.SoftResCheckLines()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return { "Keine Soft-Reserves geladen." } end
    local roster, label = ns.SoftResRoster()
    if not label then return { "Kein Raid zum Abgleichen." } end
    local c = ns.SoftResCheck(sr, roster)
    local out = { ("Abgleich mit %s: %d reserviert, %d ohne Reserve, %d nicht im Raid, %d unklar%s."):format(
        (label:gsub("^letzter ", "letztem ")), #c.ok, #c.missing, #c.absent, #c.unclear,
        #c.over > 0 and (", " .. #c.over .. " zu viel") or "") }
    if #c.missing > 0 then out[#out + 1] = "Ohne Reserve: " .. table.concat(c.missing, ", ") end
    if #c.absent > 0 then out[#out + 1] = "Nicht im Raid: " .. table.concat(c.absent, ", ") end
    for _, u in ipairs(c.unclear) do
        out[#out + 1] = ("Unklar: %s (%s?)"):format(u.name, table.concat(u.suggest, ", "))
    end
    for _, o in ipairs(c.over) do out[#out + 1] = ("Zu viele: %s (%d)"):format(o.name, o.n) end
    for _, m in ipairs(c.multi) do out[#out + 1] = ("Mehrfach: %s, %s x%d"):format(m.name, ns.ItemName(m.item), m.n) end
    return out
end

-- !sr answers ------------------------------------------------------------
local lastReply = {}   -- lower-case sender -> GetTime() of the last answer
local replies = {}     -- GetTime() of every answer in the last minute
local warnedBusy

-- A link to put into the chat: the client's link when it knows the item, else the name in brackets.
local function chatLink(id)
    local _, link = GetItemInfo(id)
    if type(link) == "string" and link:find("|Hitem:", 1, true) then return link end
    return "[" .. ns.ItemName(id) .. "]"
end

local function reserversText(sr, item)
    local names = ns.ReservedBy(item)
    if #names == 0 then return "niemand" end
    local parts = {}
    for _, name in ipairs(names) do
        local n = timesOf(sr, item, name)
        parts[#parts + 1] = n > 1 and ("%s x%d"):format(name, n) or name
    end
    return table.concat(parts, ", ")
end

-- The answer to "!sr" (rest empty) or "!sr <link or part of a name>" as chat lines.
local function answer(sr, sender, rest)
    local age = ns.SoftResAge(sr) or 0
    local suffix = age > (tonumber(ns.Get("softres.warnDays")) or 7) and (" (Liste ist %d Tage alt)"):format(age) or ""
    local when = ns.SoftResShortDate(sr.date)
    if rest == "" then
        local mine = ns.ReservesOf(sender)
        if #mine == 0 then
            return { ("Amisia: Du hast nichts reserviert (Liste vom %s).%s"):format(when, suffix) }
        end
        local parts = {}
        for _, e in ipairs(mine) do
            parts[#parts + 1] = chatLink(e.item) .. (e.n > 1 and (" x" .. e.n) or "")
        end
        return cappedLines(("Amisia: Deine Reservierungen (Liste vom %s): "):format(when), parts, REPLY_LINES, ", ", suffix)
    end
    local id = ns.ItemID(rest)
    if id then
        local link = rest:match("(|c%x+|Hitem:.-|h|r)") or chatLink(id)
        local who = reserversText(sr, id)
        return { ("Amisia: %s reserviert von %s%s%s"):format(link, who, who == "niemand" and "." or "", suffix) }
    end
    local q = rest:gsub("|", ""):lower():sub(1, 40)
    local hits = {}
    for item in pairs(sr.byItem or {}) do
        local name = ns.ItemName(item)
        if name:lower():find(q, 1, true) then hits[#hits + 1] = { item = item, sort = name } end
    end
    if #hits == 0 then
        return { ("Amisia: Kein reserviertes Item passt zu \"%s\".%s"):format(q, suffix) }
    end
    table.sort(hits, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    local parts = {}
    for i = 1, math.min(3, #hits) do
        parts[i] = ("%s reserviert von %s"):format(chatLink(hits[i].item), reserversText(sr, hits[i].item))
    end
    if #hits > 3 then suffix = (" (%d weitere Treffer)"):format(#hits - 3) .. suffix end
    return cappedLines("Amisia: ", parts, REPLY_LINES, "; ", suffix)
end

local function inGroup(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local member = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if member and ns.SameName(member, name) then return true end
    end
    return false
end

-- sender is the raw text the client gave (already plain); the answer goes back to it by whisper.
local function onSoftResCommand(sender, rest)
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or not ns.Get("softres.chat") or not ns.IsLootLead() then return end
    local name = ns.FullName(sender)
    if not name or not inGroup(name) then return end
    local t = GetTime()
    local key = name:lower()
    if lastReply[key] and t - lastReply[key] < REPLY_GAP then return end
    local keep = {}
    for _, at in ipairs(replies) do
        if t - at < 60 then keep[#keep + 1] = at end
    end
    replies = keep
    if #replies >= REPLY_PER_MIN then
        if not warnedBusy or t - warnedBusy >= 60 then
            warnedBusy = t
            ns.msg("Viele !sr-Anfragen: weitere bleiben bis zu einer Minute unbeantwortet.")
        end
        return
    end
    lastReply[key] = t
    replies[#replies + 1] = t
    for _, line in ipairs(answer(sr, name, rest or "")) do
        ns.Say(line, "WHISPER", sender, { ttl = 120 })
    end
end

ns.RegisterChatCommand("sr", onSoftResCommand)
ns.RegisterChatCommand("softres", onSoftResCommand)

---------------------------------------------------------------------------
-- Import window
---------------------------------------------------------------------------
local function plural(n, one, many) return n == 1 and one or many end

-- The preview line for a pasted text: parsed with the remembered fixes and checked against
-- ns.SoftResRoster(); nothing is stored. "" for an empty text.
function ns.SoftResPreviewText(text)
    if not (text or ""):find("%S") then return "" end
    local byItem, _, bad, times, total = ns.ParseSoftRes(text)
    local roster, label = ns.SoftResRoster()
    local c = ns.SoftResCheck({ byItem = byItem, times = times }, roster)
    local head = ("%d Raider, %d %s"):format(c.reservers, total, plural(total, "Reservierung", "Reservierungen"))
    local parts = {}
    if label then
        head = ("Vorschau gegen %s: %s"):format(label:gsub("^letzter ", "letzten "), head)
        if #c.missing > 0 then parts[#parts + 1] = ("%d ohne Reserve"):format(#c.missing) end
        if #c.absent > 0 then parts[#parts + 1] = ("%d nicht im Raid"):format(#c.absent) end
        if #c.unclear > 0 then parts[#parts + 1] = ("%d %s unklar"):format(#c.unclear, plural(#c.unclear, "Name", "Namen")) end
        if #c.over > 0 then parts[#parts + 1] = ("%d zu viel"):format(#c.over) end
    else
        head = "Vorschau: " .. head
        parts[#parts + 1] = "kein Raid zum Abgleichen"
    end
    if #bad > 0 then parts[#parts + 1] = ("%d %s nicht erkannt"):format(#bad, plural(#bad, "Zeile", "Zeilen")) end
    if #parts == 0 then return head end
    return head .. " · " .. table.concat(parts, " · ")
end

local function updatePreview()
    if not F or not previewText then return end
    local ok, text = pcall(ns.SoftResPreviewText, editBox:GetText())
    previewText:SetText(ok and text or "")
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(text) end
    end
end

-- Recomputes the preview 0.3 s after the last change of the text.
local function schedulePreview()
    previewGen = previewGen + 1
    local gen = previewGen
    C_Timer.After(0.3, function()
        if gen == previewGen then updatePreview() end
    end)
end

local function refresh()
    if not F or not F:IsShown() then return end
    local sr = AmisiaDB.softres
    if sr then
        local today = date("%Y-%m-%d")
        dateText:SetText(sr.date == today
            and ("|cff4fbf7aListe von heute:|r %d Reservierungen"):format(sr.count or 0)
            or ("|cffe0a344Liste vom %s:|r %d Reservierungen. Für einen neuen Raid neu einfügen."):format(ns.SoftResShortDate(sr.date), sr.count or 0))
        if editBox:GetText() == "" then editBox:SetText(sr.raw or "") end
    else
        dateText:SetText("|cff8f86a3Keine Soft-Reserves.|r softres.it-CSV oder Zeilen wie 'Name [Item-Link]' einfügen.")
    end
end

-- The bottom of the import window, from below: buttons (10-32), result, preview, the text box.
local TEXT_H = 26                       -- two lines of GameFontHighlightSmall
local RESULT_Y = 38
local PREVIEW_Y = RESULT_Y + TEXT_H + 4
local BOX_BOTTOM = PREVIEW_Y + TEXT_H + 4

local function build()
    F = CreateFrame("Frame", "AmisiaSoftResFrame", UIParent)
    F:SetSize(440, 380)
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
    boxBg:SetPoint("BOTTOMRIGHT", -12, BOX_BOTTOM)
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
    editBox:SetScript("OnTextChanged", schedulePreview)
    scroll:SetScrollChild(editBox)
    boxBg:EnableMouse(true)
    boxBg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- the preview sits above the result of the last import; each has a fixed room of two lines,
    -- so a long text is cut instead of growing into the other
    previewText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewText:SetPoint("BOTTOMLEFT", 12, PREVIEW_Y)
    previewText:SetSize(416, TEXT_H)
    previewText:SetJustifyH("LEFT")
    previewText:SetJustifyV("TOP")
    previewText:SetWordWrap(true)
    previewText:SetMaxLines(2)
    previewText:SetTextColor(0.89, 0.72, 0.34)
    previewText:SetText("")

    resultText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultText:SetPoint("BOTTOMLEFT", 12, RESULT_Y)
    resultText:SetSize(416, TEXT_H)
    resultText:SetJustifyH("LEFT")
    resultText:SetJustifyV("TOP")
    resultText:SetWordWrap(true)
    resultText:SetMaxLines(2)

    local apply = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    apply:SetSize(110, 22)
    apply:SetPoint("BOTTOMLEFT", 12, 10)
    apply:SetText("Übernehmen")
    apply:SetScript("OnClick", function()
        local count, bad = ns.SetSoftRes(editBox:GetText())
        resultText:SetText(("%d Reservierungen übernommen, %d Zeilen nicht erkannt."):format(count, #bad)
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
        previewText:SetText("")
        resultText:SetText("Liste geleert.")
        refresh()
    end)
    F.editBox, F.resultText, F.dateText, F.applyBtn, F.clearBtn, F.previewText, F.box = editBox, resultText, dateText, apply, clear, previewText, boxBg
    ns.SoftResFrame = F
end

function ns.ToggleSoftResFrame()
    if not F then build() end
    if F:IsShown() then F:Hide() else F:Show() end
end

-- softres.remindText: no escape codes or line breaks, at most 120 characters (UTF-8 kept whole).
local function cleanRemindText(v)
    v = tostring(v or ""):gsub("|", ""):gsub("[\r\n]+", " ")
    v = v:match("^%s*(.-)%s*$")
    local out, n = {}, 0
    for ch in v:gmatch("[%z\1-\127\192-\253][\128-\191]*") do
        n = n + 1
        if n > 120 then break end
        out[n] = ch
    end
    return table.concat(out)
end

ns.RegisterSettings{ key = "softres", label = "Soft-Reserves", order = 30, items = {
    { key = "softres.tooltip", type = "toggle", label = "Tooltip-Zeile \"Reserviert: ...\"", default = true },
    { key = "softres.lootMark", type = "toggle", label = "SR-Markierung im Lootfenster und an den Würfelfenstern", default = true,
      onChange = function() ns.MarkLootButtons() end },
    { key = "softres.warnDays", type = "slider", label = "Warnen, wenn die Liste älter ist als (Tage)", default = 7, min = 1, max = 30, step = 1 },
    { key = "softres.tooltipGroup", type = "toggle", label = "Im Tooltip nur Reservierungen aus der Gruppe", default = true },
    { key = "softres.limit", type = "slider", label = "Reservierungen pro Raider (0 = keine Prüfung)", default = 0, min = 0, max = 6, step = 1,
      officer = true },
    { key = "softres.chat", type = "toggle", label = "Auf !sr antworten", default = true, officer = true,
      tip = "Nur als Lootleitung, per Flüsterung." },
    { key = "softres.remindText", type = "text", label = "Zusatz in der Erinnerung", default = "", officer = true,
      tip = "Z. B. Link zur Liste.", validate = cleanRemindText },
}}
-- Forgets the remembered name fixes (AmisiaDB.srAliases): all of them, or the ones of name (as
-- written in a list or as fixed). The loaded list stays as it is. Returns the number forgotten.
function ns.ForgetSoftResAliases(name)
    local aliases = AmisiaDB and AmisiaDB.srAliases
    if type(aliases) ~= "table" then return 0 end
    local low = type(name) == "string" and name:match("^%s*(.-)%s*$"):lower() or ""
    local n = 0
    for from, to in pairs(aliases) do
        if low == "" or from:lower() == low or (type(to) == "string" and to:lower() == low) then
            aliases[from] = nil
            n = n + 1
        end
    end
    if n > 0 and ns.Refresh then ns.Refresh() end
    return n
end

-- The remembered fix for a list name, or nil.
function ns.SoftResAlias(listName)
    local aliases = AmisiaDB and AmisiaDB.srAliases
    local to = type(aliases) == "table" and type(listName) == "string" and aliases[listName:lower()]
    return type(to) == "string" and to or nil
end

local function forgetCommand(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    local n = ns.ForgetSoftResAliases(name)
    if name == "" then
        ns.msg(n > 0 and ("%d gemerkte Namenskorrekturen vergessen. Die geladene Liste bleibt, wie sie ist."):format(n)
            or "Keine gemerkten Namenskorrekturen.")
    else
        ns.msg(n > 0 and ("Gemerkte Namenskorrektur für %s vergessen. Die geladene Liste bleibt, wie sie ist."):format(name)
            or ("Keine gemerkte Namenskorrektur für %s."):format(name))
    end
end

local SUBWORDS = { pruefen = "check", ["prüfen"] = "check", check = "check", erinnern = "remind", remind = "remind",
                   posten = "post", post = "post", vergessen = "forget", forget = "forget" }
ns.RegisterSlash("sr", { args = "[pruefen|erinnern|posten|vergessen [Name]]", desc = "Soft-Reserves anzeigen", run = function(rest)
    local word, tail = (rest or ""):match("^(%S+)%s*(.-)$")
    local sub = word and SUBWORDS[word:lower()]
    if word and not sub then
        ns.msg("Aufruf: /amisia sr [pruefen|erinnern|posten|vergessen [Name]]")
        return
    end
    if sub == "forget" then
        forgetCommand(tail)
    elseif sub == "check" then
        for _, line in ipairs(ns.SoftResCheckLines()) do ns.msg(line) end
    elseif sub == "remind" then
        ns.ConfirmSoftResReminders()
    elseif sub == "post" then
        if not ns.IsOfficerView() then ns.msg("Posten nur in der Offiziersansicht.") return end
        local n, why = ns.PostSoftResSummary()
        if not n then ns.msg(why) end
    elseif ns.ShowPage then
        ns.ShowPage("softres")
    else
        ns.ToggleSoftResFrame()
    end
end })
