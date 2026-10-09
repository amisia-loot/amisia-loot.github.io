-- Amisia trade helper (DECISIONS D-39, spec docs/specs/2026-10-08-loot-abend.md, Teil 1): only for
-- the exceptions of master loot (D-27): an item awarded to someone else (a player, the bank, the
-- disenchanter) that still lies in the own bags and can still be traded. The list "Noch zu
-- übergeben" (Vergaben page, /amisia uebergabe) shows each such copy with its time left, read from
-- the client's tooltip line TradeTimeRemaining (type 36; "Handelszeit unbekannt" without it). Own
-- chat warnings with a sound at 30 and 10 minutes left. When the receiver trades with this
-- character, a small window beside the trade window offers "Amisia: N Items einlegen": a click (a
-- hardware event, never in combat) puts the items into free trade slots; "Handeln" stays the
-- player's. After the trade the copies that left the bags are marked handed over (AmisiaDB.handover,
-- only on this client). Copies are followed by their item GUID (a move between bags keeps the entry),
-- else by item id. Nothing is sent, nothing is automatic, nothing replaces master loot.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local TRADE_SECS = 7200                    -- the client's trade time of a looted item
local AWARD_WINDOW = TRADE_SECS + 600      -- an older award has no tradeable copy any more
local KEEP_SECS = 3 * 86400                -- the "übergeben" marks are kept this long
local MAX_SAVED = 200
local WARN_EARLY, WARN_LATE = 1800, 600    -- the warnings: 30 and 10 minutes left
local LINE_TRADE = 36                      -- Enum.TooltipDataLineType.TradeTimeRemaining (Forever 1.60.1)
local MAX_SLOTS = 6                        -- MAX_TRADABLE_ITEMS: the seventh slot is not traded
local TICK = 30                            -- s between scans while something is open
local SCAN_DELAY = 0.3                     -- bag events come in bursts
local VERIFY_AFTER = 1                     -- s after the trade closed: the bags tell what left
local LOOT_SLACK = 300                     -- a loot line this long before the award still delivers it
local WIDTH = 280
local PAD = T.WINDOW_PAD
local ORANGE, RED = T.ORANGE, T.RED

local entries = {}     -- the open hand-overs, shortest time first: { key, s, a, item, to, by, copy, left }
local tracked = {}     -- award key -> GUID of the copy that belongs to it (until logout)
local warned = {}      -- award key -> { [WARN_EARLY] = true, [WARN_LATE] = true }
local expired = {}     -- award key -> true: its copy can no longer be traded (told once)
local trade            -- the open trade: { partner, inserted = { key = true }, slots = { id... }, counts, done, cancelled }
local helper           -- the small window beside the trade window
local scanQueued, ticker

local function now() return GetTime() end
local function me() return ns.UnitFullName("player") end
local function enabled() return ns.Get("trade.enabled") ~= false end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

---------------------------------------------------------------------------
-- The time left: the tooltip line TradeTimeRemaining
---------------------------------------------------------------------------
-- Seconds of one unit word of a duration ("Std.", "Min.", "Sek.", "hours", "min", "sec", "Tage"),
-- nil for any other word.
local function unitSeconds(u)
    u = (u or ""):lower():gsub("[%p]", "")
    if u == "" then return nil end
    if u:find("^st") or u:find("^h") then return 3600 end   -- Std., Stunden, h, hr, hours
    if u:find("^mi") or u == "m" then return 60 end         -- Min., Minuten, min, mins, minutes
    if u:find("^se") or u:find("^s") then return 1 end      -- Sek., Sekunden, sec, seconds, s
    if u:find("^ta") or u:find("^d") then return 86400 end  -- Tag, Tage, day, days, d
    return nil
end

-- Seconds of a duration as the client writes it in German or English ("1 Std. 59 Min.", "59 Min.",
-- "1 hour 12 minutes", "45 sec", "1:12"); nil when it holds none.
function ns.HandoverParseDuration(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local h, m = text:match("(%d+):(%d%d)")
    if h then return tonumber(h) * 3600 + tonumber(m) * 60 end
    local total, any = 0, false
    for num, unit in text:gmatch("(%d+)%s*([^%d%s]*)") do
        local s = unitSeconds(unit)
        if s then
            total = total + tonumber(num) * s
            any = true
        end
    end
    return any and total or nil
end

-- The duration part of the tooltip line: the %s of the client's BIND_TRADE_TIME_REMAINING; the
-- whole line when the template does not fit (another client, a changed text).
local template = { src = nil, pat = nil }
local function durationText(line)
    local tpl = ns.Plain(_G.BIND_TRADE_TIME_REMAINING)
    if type(tpl) == "string" and tpl ~= template.src then
        template.src, template.pat = tpl, nil
        local before, after = tpl:match("^(.-)%%%d*%$?s(.*)$")
        if before then
            local function esc(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
            template.pat = "^" .. esc(before) .. "(.-)" .. esc(after) .. "$"
        end
    end
    return template.pat and line:match(template.pat) or line
end

function ns.HandoverParseLine(line)
    line = ns.Plain(line)
    if type(line) ~= "string" then return nil end
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return ns.HandoverParseDuration(durationText(line))
end

local function lineType()
    local e = _G.Enum and Enum.TooltipDataLineType
    return (type(e) == "table" and tonumber(e.TradeTimeRemaining)) or LINE_TRADE
end

-- The trade time of the item in bag, slot: seconds (nil when unknown) and whether the tooltip has
-- the line at all.
local function tradeLeft(bag, slot)
    local api = _G.C_TooltipInfo
    if type(api) ~= "table" or type(api.GetBagItem) ~= "function" then return nil, false end
    local ok, data = pcall(api.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil, false end
    local want = lineType()
    for _, line in ipairs(data.lines) do
        if type(line) == "table" and ns.Plain(line.type) == want then
            return ns.HandoverParseLine(line.leftText), true
        end
    end
    return nil, false
end

---------------------------------------------------------------------------
-- The bags
---------------------------------------------------------------------------
local function location(bag, slot)
    local IL = _G.ItemLocation
    if type(IL) ~= "table" or type(IL.CreateFromBagAndSlot) ~= "function" then return nil end
    local ok, loc = pcall(IL.CreateFromBagAndSlot, IL, bag, slot)
    return ok and loc or nil
end

-- The item GUID in bag, slot (nil without the API, for a secret value or an empty slot) and whether
-- the client says it is bound (nil when it cannot tell).
local function guidAt(bag, slot)
    local loc = location(bag, slot)
    local api = _G.C_Item
    if not loc or type(api) ~= "table" then return nil, nil end
    if type(api.DoesItemExist) == "function" then
        local ok, there = pcall(api.DoesItemExist, loc)
        if ok and ns.Plain(there) == false then return nil, nil end
    end
    local guid, bound
    if type(api.GetItemGUID) == "function" then
        local ok, g = pcall(api.GetItemGUID, loc)
        g = ok and ns.Plain(g) or nil
        if type(g) == "string" and g ~= "" then guid = g end
    end
    if type(api.IsBound) == "function" then
        local ok, b = pcall(api.IsBound, loc)
        b = ok and ns.Plain(b)
        if type(b) == "boolean" then bound = b end
    end
    return guid, bound
end

local function lockedAt(bag, slot)
    local api = C_Container and C_Container.GetContainerItemInfo
    if type(api) ~= "function" then return false end
    local ok, info = pcall(api, bag, slot)
    return ok and type(info) == "table" and ns.Plain(info.isLocked) == true
end

-- Every copy in the bags (0 to NUM_BAG_SLOTS) of the item ids in want: { bag, slot, id, link, guid,
-- left, line, tradeable, readAt }. A copy is tradeable with the trade time line (and time left), or
-- without it unless the client says it is bound (then the time is unknown); a bound copy without the
-- line is not.
local function bagCopies(want)
    local out = {}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return out end
    for bag = 0, tonumber(_G.NUM_BAG_SLOTS) or 4 do
        local n = tonumber(ns.Plain(C_Container.GetContainerNumSlots(bag))) or 0
        for slot = 1, n do
            local id = tonumber(ns.Plain(C_Container.GetContainerItemID(bag, slot)))
            if id and want[id] then
                local guid, bound = guidAt(bag, slot)
                local left, line = tradeLeft(bag, slot)
                local link = C_Container.GetContainerItemLink and ns.Plain(C_Container.GetContainerItemLink(bag, slot))
                local tradeable = (line and not (left and left <= 0)) or (not line and bound ~= true)
                out[#out + 1] = { bag = bag, slot = slot, id = id, link = type(link) == "string" and link or nil, guid = guid,
                                  left = left, line = line, tradeable = tradeable and true or false, bound = bound, readAt = now() }
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- The awards: which copies belong to whom
---------------------------------------------------------------------------
local function saved()
    if not AmisiaDB then return nil end
    if type(AmisiaDB.handover) ~= "table" then AmisiaDB.handover = {} end
    return AmisiaDB.handover
end

-- On ADDON_LOADED (and in tests): the marks checked field by field, older than 3 days dropped, at
-- most 200 (the newest kept).
function ns.HandoverLoaded(root)
    if type(root) ~= "table" then return end
    local src = type(root.handover) == "table" and root.handover or {}
    local t = time()
    local keep = {}
    for k, v in pairs(src) do
        if type(k) == "string" and k:match("^%d%d%d%d%-%d%d%-%d%d:%d+/%x+$") and type(v) == "table"
            and tonumber(v.t) and v.t > t - KEEP_SECS and v.t <= t + 86400 then
            keep[#keep + 1] = { k = k, v = { t = math.floor(v.t), to = type(v.to) == "string" and v.to:sub(1, 48) or nil,
                                             g = type(v.g) == "string" and v.g:sub(1, 64) or nil } }
        end
    end
    table.sort(keep, function(a, b) return a.v.t > b.v.t end)
    local out = {}
    for i = 1, math.min(#keep, MAX_SAVED) do out[keep[i].k] = keep[i].v end
    root.handover = out
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.HandoverLoaded(AmisiaDB) end
end)

-- The receiver of an award: the player, or the bank or disenchant character (the award's name, else
-- the one of the settings); nil when nobody is named.
local function receiverOf(a)
    if a.to == "bank" or a.to == "de" then
        local n = (type(a.name) == "string" and a.name ~= "-") and a.name
            or ns.Get(a.to == "bank" and "awards.bankName" or "awards.deName")
        return ns.FullName(n)
    end
    return ns.FullName(a.name)
end

-- Who made the award, as far as this client knows: the loot lead whose raid state it has, else itself.
local function byOf(s)
    local k = type(s.sync) == "table" and ns.Plain(s.sync.keeper)
    if type(k) == "string" and k ~= "" then return k end
    return me()
end

local function keyOf(s, a)
    local rk = ns.RaidKey and ns.RaidKey(s)
    if not rk or type(a.id) ~= "string" then return nil end
    return rk .. "/" .. a.id
end

-- Whether the award of key is marked handed over on this client.
local function handed(key)
    local db = AmisiaDB and type(AmisiaDB.handover) == "table" and AmisiaDB.handover
    return db and db[key] ~= nil or false
end

function ns.HandedOver(s, a)
    local key = s and a and keyOf(s, a)
    return key and handed(key) or false
end

-- The living awards of the last two hours (and a bit): { key, s, a, item, to, by }.
local function recentAwards(t)
    local out = {}
    local act = ns.Active and ns.Active()
    for _, s in ipairs(ns.Sessions and ns.Sessions() or {}) do
        if s == act or (tonumber(s.last) or tonumber(s.start) or 0) >= t - AWARD_WINDOW then
            local by
            for _, a in ipairs(s.awards or {}) do
                local at, item = tonumber(a.t), tonumber(a.item)
                local key = item and at and at >= t - AWARD_WINDOW and keyOf(s, a)
                if key then
                    by = by or byOf(s)
                    out[#out + 1] = { key = key, s = s, a = a, item = item, to = receiverOf(a), by = by, t = at }
                end
            end
        end
    end
    table.sort(out, function(x, y) if x.t ~= y.t then return x.t < y.t end return x.key < y.key end)
    return out
end

-- How many loot lines of the raid show name receiving item from time from on (master loot straight
-- to the receiver: that copy never was in these bags).
local function lootLines(s, name, item, from)
    local n = 0
    for _, list in ipairs({ s.items or {}, s.loot or {} }) do
        for _, l in ipairs(list) do
            if tonumber(l.item) == item and (tonumber(l.t) or 0) >= from and ns.SameName(l.name, name) then n = n + 1 end
        end
    end
    return n
end

-- The open awards: to someone else, not marked, not run out, not delivered by a loot line; and per
-- item how many recent awards are this character's own (their copies are not handed over).
local function openAwards(t)
    local my = me()
    local open, mine = {}, {}
    local groups = {}
    for _, c in ipairs(recentAwards(t)) do
        if c.to and my and ns.SameName(c.to, my) then
            mine[c.item] = (mine[c.item] or 0) + 1
        elseif c.to and not handed(c.key) and not expired[c.key] then
            local g = c.s.id .. "\t" .. c.item .. "\t" .. c.to:lower()
            groups[g] = groups[g] or {}
            table.insert(groups[g], c)
        end
    end
    for _, list in pairs(groups) do
        -- the first n awards of a receiver and item came by master loot (n loot lines)
        local first = list[1]
        local n = lootLines(first.s, first.to, first.item, first.t - LOOT_SLACK)
        for i, c in ipairs(list) do
            if i > n then open[#open + 1] = c end
        end
    end
    table.sort(open, function(x, y) if x.t ~= y.t then return x.t < y.t end return x.key < y.key end)
    return open, mine
end

-- The seconds a copy has left now (nil: unknown).
local function leftOf(copy)
    if not copy or not copy.left then return nil end
    return copy.left - (now() - copy.readAt)
end

-- Gives every open award a tradeable copy: the one its GUID was given before, else (oldest award
-- first) a free copy with the least time left. The copies of the own awards stay out (as many as
-- the own awards of that item).
local function assign(open, mine, copies)
    local byItem = {}
    for _, c in ipairs(copies) do
        byItem[c.id] = byItem[c.id] or {}
        table.insert(byItem[c.id], c)
    end
    local out = {}
    local function take(pool, guid)
        for i, c in ipairs(pool) do
            if c.guid == guid then return table.remove(pool, i) end
        end
        return nil
    end
    local items = {}
    for _, o in ipairs(open) do
        if not items[o.item] then items[o.item] = {}; items[#items + 1] = o.item end
        table.insert(items[o.item], o)
    end
    for _, item in ipairs(items) do
        local pool, list = byItem[item] or {}, items[item]
        -- a copy that cannot be traded any more ends its award (told once, below)
        local budget = 0
        for _, c in ipairs(pool) do if c.tradeable then budget = budget + 1 end end
        budget = budget - (mine[item] or 0)
        local done = {}
        for _, o in ipairs(list) do
            local g = tracked[o.key]
            local c = g and take(pool, g)
            if c then
                done[o] = c
                if c.tradeable then budget = budget - 1 end
            end
        end
        table.sort(pool, function(x, y)
            local lx, ly = x.left or math.huge, y.left or math.huge
            if lx ~= ly then return lx < ly end
            if x.bag ~= y.bag then return x.bag < y.bag end
            return x.slot < y.slot
        end)
        for _, o in ipairs(list) do
            if not done[o] and budget > 0 then
                for i, c in ipairs(pool) do
                    if c.tradeable then
                        done[o] = table.remove(pool, i)
                        budget = budget - 1
                        break
                    end
                end
            end
        end
        for _, o in ipairs(list) do
            local c = done[o]
            if c then
                if c.guid then tracked[o.key] = c.guid end
                o.copy = c
                out[#out + 1] = o
            end
        end
    end
    return out
end

local function itemLink(e)
    if e.copy and e.copy.link then return e.copy.link end
    local _, link = C_Item.GetItemInfo(e.item)
    return link or ns.ItemName(e.item)
end

local function toText(e)
    if e.a.to == "bank" then return L["die Bank (%s)"]:format(e.to) end
    if e.a.to == "de" then return L["den Entzauberer (%s)"]:format(e.to) end
    return e.to
end

---------------------------------------------------------------------------
-- The scan: the list, the warnings, the end of the trade time
---------------------------------------------------------------------------
local refreshHelper

local function warn(e)
    local mode = ns.Get("trade.warn")
    local left = e.left
    if mode == "off" or not left or left <= 0 then return end
    local at = (left <= WARN_LATE and WARN_LATE) or (left <= WARN_EARLY and WARN_EARLY) or nil
    local w = warned[e.key] or {}
    warned[e.key] = w
    if not at or w[at] then return end
    w[at] = true
    if at == WARN_LATE then w[WARN_EARLY] = true end
    if mode == "ten" and at ~= WARN_LATE then return end
    ns.msg(ORANGE .. L["Noch %d Minuten: %s an %s übergeben."]:format(math.max(1, math.ceil(left / 60)), itemLink(e), toText(e)) .. "|r")
    if ns.Get("trade.sound") and type(PlaySound) == "function" and SOUNDKIT then
        local kit = SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_3
        if kit then pcall(PlaySound, kit) end
    end
end

local function changed()
    ns.Fire("HANDOVER")
    if ns.CurrentPage and ns.CurrentPage() == "awards" and ns.Refresh then ns.Refresh() end
end

-- The trade time of e's copy is over: told once, the entry leaves the list for good.
local function runOut(e)
    expired[e.key] = true
    tracked[e.key] = nil
    ns.msg(RED .. L["Nicht mehr handelbar: %s (vergeben an %s)."]:format(itemLink(e), toText(e)) .. "|r")
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i].key ~= b[i].key or a[i].copy ~= b[i].copy then return false end
    end
    return true
end

local function scan()
    scanQueued = false
    local before = entries
    local out = {}
    if enabled() then
        local t = time()
        local open, mine = openAwards(t)
        if #open > 0 then
            local want = {}
            for _, o in ipairs(open) do want[o.item] = true end
            local copies = bagCopies(want)
            local listed = {}
            for _, e in ipairs(assign(open, mine, copies)) do
                e.left = leftOf(e.copy)
                if not e.copy.tradeable then
                    runOut(e)
                else
                    out[#out + 1] = e
                    listed[e.key] = true
                end
            end
            -- an entry of the last scan whose copy is still here but can no longer be traded ran out
            -- (a copy that left the bags just leaves the list)
            for _, b in ipairs(before) do
                if not listed[b.key] and not expired[b.key] and not handed(b.key) then
                    for _, c in ipairs(copies) do
                        local same = (b.copy.guid and c.guid == b.copy.guid)
                            or (not b.copy.guid and c.id == b.item and c.bag == b.copy.bag and c.slot == b.copy.slot)
                        if same and not c.tradeable then
                            runOut(b)
                            break
                        end
                    end
                end
            end
        end
    end
    -- shortest time first; an unknown time after the known ones, oldest award first
    table.sort(out, function(x, y)
        local lx, ly = x.left or math.huge, y.left or math.huge
        if lx ~= ly then return lx < ly end
        if x.t ~= y.t then return x.t < y.t end
        return x.key < y.key
    end)
    entries = out
    for _, e in ipairs(out) do warn(e) end
    if #out > 0 and not ticker then
        ticker = C_Timer.NewTicker(TICK, function() scan() end)
    elseif #out == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
    if refreshHelper then refreshHelper() end
    if not sameList(before, out) then changed() end
end

local function queueScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(SCAN_DELAY, function()
        local ok, err = pcall(scan)
        if not ok then scanQueued = false report(err) end
    end)
end

-- The open hand-overs (a fresh scan), shortest time first. Tests and the page.
function ns.HandoverList()
    scan()
    return entries
end

-- The open hand-overs of the last scan (the page; the bags and the clock scan again).
function ns.HandoverEntries() return entries end

-- The seconds entry e has left now; nil when the time is unknown.
function ns.HandoverLeft(e)
    if not e then return nil end
    if e.copy and e.copy.left then return leftOf(e.copy) end
    return e.left
end

-- The time left as the list shows it: "noch 1:12 h", "noch 25 min", "Handelszeit unbekannt".
function ns.HandoverLeftText(e)
    local left = ns.HandoverLeft(e)
    if not left then return L["Handelszeit unbekannt"] end
    left = math.max(0, left)
    if left >= 3600 then
        local m = math.floor(left / 60)
        return L["noch %d:%02d h"]:format(math.floor(m / 60), m % 60)
    end
    return L["noch %d min"]:format(math.max(1, math.ceil(left / 60)))
end

function ns.HandoverItemText(e) return itemLink(e) end
function ns.HandoverToText(e) return toText(e) end

ns.OnEvent("BAG_UPDATE_DELAYED", function() queueScan() end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function() queueScan() end)
ns.Listen("DATA_CHANGED", function() queueScan() end)
ns.Listen("SETTING", function(path)
    if type(path) == "string" and path:find("^trade%.") then queueScan() end
end)

---------------------------------------------------------------------------
-- The trade window
---------------------------------------------------------------------------
local function partnerName()
    if type(UnitName) ~= "function" then return nil end
    local n, second = UnitName("NPC")
    n, second = ns.Plain(n), ns.Plain(second)
    if type(n) ~= "string" then return nil end
    return ns.FullName(n, type(second) == "string" and second or nil)
end

local function forPartner(partner)
    local out = {}
    if not partner then return out end
    local roster = ns.GroupRoster()
    for _, e in ipairs(entries) do
        if ns.SameNameIn(e.to, partner, roster) then out[#out + 1] = e end
    end
    return out
end

-- The entries for the partner whose copy is not in the trade yet.
local function waiting(partner)
    local out = {}
    for _, e in ipairs(forPartner(partner)) do
        if not (trade and trade.inserted[e.key]) and not lockedAt(e.copy.bag, e.copy.slot) then out[#out + 1] = e end
    end
    return out
end

local function tradeLink(i)
    if type(GetTradePlayerItemLink) ~= "function" then return nil end
    local link = ns.Plain(GetTradePlayerItemLink(i))
    return type(link) == "string" and link or nil
end

local function freeTradeSlot()
    for i = 1, MAX_SLOTS do
        if not tradeLink(i) then return i end
    end
    return nil
end

local function cursorHolds()
    return type(CursorHasItem) == "function" and ns.Plain(CursorHasItem()) and true or false
end

-- Where the copy of e lies now: its GUID's place (the bags may have changed since the scan), else
-- the scanned place when the item there is still that item.
local function locate(e)
    local c = e.copy
    if c.guid then
        local g = guidAt(c.bag, c.slot)
        if g == c.guid then return c.bag, c.slot end
        for bag = 0, tonumber(_G.NUM_BAG_SLOTS) or 4 do
            for slot = 1, tonumber(ns.Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
                if tonumber(ns.Plain(C_Container.GetContainerItemID(bag, slot))) == e.item and guidAt(bag, slot) == c.guid then
                    return bag, slot
                end
            end
        end
        return nil
    end
    if tonumber(ns.Plain(C_Container.GetContainerItemID(c.bag, c.slot))) == e.item then return c.bag, c.slot end
    return nil
end

-- The click on "Amisia: N Items einlegen": the partner's items one after another into free trade
-- slots. Never in combat; nothing while the cursor holds something.
local function insert()
    if not trade or not trade.partner then return end
    if InCombatLockdown and InCombatLockdown() then
        ns.msg(L["Im Kampf legt Amisia nichts ein. Nach dem Kampf noch einmal klicken."])
        return
    end
    if cursorHolds() then
        ns.msg(L["Du hältst etwas mit der Maus: erst ablegen, dann noch einmal klicken."])
        return
    end
    if not (C_Container and C_Container.PickupContainerItem) or type(ClickTradeButton) ~= "function" then return end
    scan()
    local n, full = 0, false
    for _, e in ipairs(waiting(trade.partner)) do
        local slot = freeTradeSlot()
        if not slot then full = true break end
        local bag, bslot = locate(e)
        if bag then
            C_Container.PickupContainerItem(bag, bslot)
            if cursorHolds() then ClickTradeButton(slot) end
            if cursorHolds() then
                -- the trade window did not take it: back into the bag, stop
                if type(ClearCursor) == "function" then ClearCursor() end
                break
            end
            trade.inserted[e.key] = true
            n = n + 1
        end
    end
    if n == 1 then
        ns.msg(L["1 Item eingelegt. \"Handeln\" drückst du selbst."])
    elseif n > 1 then
        ns.msg(L["%d Items eingelegt. \"Handeln\" drückst du selbst."]:format(n))
    end
    if full then ns.msg(L["Das Handelsfenster ist voll (6 Plätze). Den Rest im nächsten Handel."]) end
    refreshHelper()
end

local function buildHelper()
    local f = W.Window("AmisiaTradeHelper", WIDTH, 118, { title = L["Handel-Helfer"], escape = false, strata = "HIGH" })
    f.text = W.Text(f, T.FONT.text, WIDTH - 2 * PAD, true)
    f.text:SetPoint("TOPLEFT", PAD, -(T.TITLE_H + 8))
    f.text:SetHeight(28)
    f.text:SetMaxLines(2)
    f.text:SetJustifyV("TOP")
    f.by = W.Text(f, T.FONT.hint, WIDTH - 2 * PAD)
    f.by:SetPoint("TOPLEFT", PAD, -(T.TITLE_H + 38))
    f.button = W.Button(f, L["Amisia: %d Items einlegen"]:format(6), nil, function() insert() end, { height = T.BUTTON_H })
    f.button:SetPoint("BOTTOMLEFT", PAD, 12)
    f.button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Handel-Helfer"], 1, 0.82, 0)
        for _, e in ipairs(forPartner(trade and trade.partner)) do
            GameTooltip:AddLine(L["%s an %s, %s"]:format(itemLink(e), toText(e), ns.HandoverLeftText(e)), 0.85, 0.85, 0.85, true)
        end
        GameTooltip:AddLine(L["Ein Klick legt die Items in freie Plätze. \"Handeln\" drückst du selbst."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local tf = _G.TradeFrame
    f:ClearAllPoints()
    if type(tf) == "table" and type(tf.GetObjectType) == "function" then
        f:SetPoint("TOPLEFT", tf, "TOPRIGHT", 4, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 260, 80)
    end
    return f
end

refreshHelper = function()
    local list = trade and enabled() and forPartner(trade.partner) or {}
    if #list == 0 then
        if helper then helper:Hide() end
        return
    end
    helper = helper or buildHelper()
    local names = {}
    for _, e in ipairs(list) do names[#names + 1] = itemLink(e) end
    helper.text:SetText(L["Für %s: %s"]:format(trade.partner, table.concat(names, ", ")))
    local by = {}
    for _, e in ipairs(list) do
        if e.by and not by[e.by] then by[e.by] = true; by[#by + 1] = e.by end
    end
    helper.by:SetText(#by > 0 and L["laut Vergabe von %s"]:format(table.concat(by, ", ")) or "")
    local n = #waiting(trade.partner)
    if n == 0 then
        helper.button:SetText(L["Amisia: alles eingelegt"])
    elseif n == 1 then
        helper.button:SetText(L["Amisia: 1 Item einlegen"])
    else
        helper.button:SetText(L["Amisia: %d Items einlegen"]:format(n))
    end
    W.FitChip(helper.button, 120)
    helper.button:SetEnabled(n > 0)
    helper:Show()
end

-- The item ids in the own trade slots now (for the check after the trade).
local function snapshotSlots()
    if not trade then return end
    local ids = {}
    for i = 1, MAX_SLOTS do
        local id = ns.ItemID(tradeLink(i))
        if id then ids[#ids + 1] = id end
    end
    if #ids > 0 or not trade.slots then trade.slots = ids end
end

ns.OnEvent("TRADE_SHOW", function()
    trade = { partner = partnerName(), inserted = {}, slots = {}, at = now() }
    if not enabled() then return end
    local ok, err = pcall(scan)
    if not ok then report(err) end
    -- the copies in the bags now: what is missing after the trade left with it
    trade.copies = {}
    for _, e in ipairs(entries) do trade.copies[e.key] = { guid = e.copy.guid, item = e.item, bag = e.copy.bag, slot = e.copy.slot } end
    refreshHelper()
end)

ns.OnEvent("TRADE_PLAYER_ITEM_CHANGED", function()
    snapshotSlots()
    if refreshHelper then refreshHelper() end
end)

ns.OnEvent("TRADE_ACCEPT_UPDATE", function()
    snapshotSlots()
end)

-- "Handel abgeschlossen" or "Handel abgebrochen": the message type's name where the client gives it,
-- else the text; a secret value tells nothing (the bags decide after the trade).
ns.OnEvent("UI_INFO_MESSAGE", function(kind, text)
    if not trade then return end
    local name
    if type(GetGameMessageInfo) == "function" and ns.Plain(kind) ~= nil then
        local ok, n = pcall(GetGameMessageInfo, kind)
        if ok then name = ns.Plain(n) end
    end
    text = ns.Plain(text)
    if name == "ERR_TRADE_COMPLETE" or (text and text == ns.Plain(_G.ERR_TRADE_COMPLETE)) then
        trade.done = true
    elseif name == "ERR_TRADE_CANCELLED" or (text and text == ns.Plain(_G.ERR_TRADE_CANCELLED)) then
        trade.cancelled = true
    end
end)

-- After the trade: an entry whose copy left the bags went with it. With the receiver: marked handed
-- over; with someone else: a hint (the award stays as it is).
local function verify(tr)
    if not tr.copies or not tr.partner then return end
    local roster = ns.GroupRoster()
    -- the entries the trade held: those Amisia put in, and per item id of the trade's slots
    local held, count = {}, {}
    for _, id in ipairs(tr.slots or {}) do count[id] = (count[id] or 0) + 1 end
    local list = {}
    for key, c in pairs(tr.copies) do list[#list + 1] = { key = key, c = c } end
    table.sort(list, function(x, y) return x.key < y.key end)
    for _, x in ipairs(list) do
        if tr.inserted[x.key] then
            held[x.key] = x.c
            count[x.c.item] = (count[x.c.item] or 1) - 1
        end
    end
    for _, x in ipairs(list) do
        if not held[x.key] and (count[x.c.item] or 0) > 0 then
            held[x.key] = x.c
            count[x.c.item] = count[x.c.item] - 1
        end
    end
    local present = {}
    for bag = 0, tonumber(_G.NUM_BAG_SLOTS) or 4 do
        for slot = 1, tonumber(ns.Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
            local id = tonumber(ns.Plain(C_Container.GetContainerItemID(bag, slot)))
            if id then
                local g = guidAt(bag, slot)
                present[g or (bag .. ":" .. slot .. ":" .. id)] = true
            end
        end
    end
    local db = saved()
    local any = false
    for _, x in ipairs(list) do
        local key, c = x.key, held[x.key]
        local stays = not c or (c.guid and present[c.guid]) or (not c.guid and present[c.bag .. ":" .. c.slot .. ":" .. c.item])
        if not stays then
            -- the award (its entry may have left the list already: the bags changed before this check)
            local a
            for _, o in ipairs(entries) do if o.key == key then a = o.a end end
            if not a then
                for _, sess in ipairs(ns.Sessions()) do
                    for _, aw in ipairs(sess.awards or {}) do
                        if keyOf(sess, aw) == key then a = aw end
                    end
                end
            end
            local to = a and receiverOf(a)
            local view = { item = c.item, a = a or { to = "player" }, to = to or "?", copy = { link = nil } }
            if to and ns.SameNameIn(to, tr.partner, roster) then
                if db then db[key] = { t = time(), to = tr.partner, g = c.guid } end
                tracked[key] = nil
                ns.msg(L["Übergeben: %s an %s."]:format(itemLink(view), tr.partner))
                any = true
            elseif to then
                ns.msg(ORANGE .. L["%s ging an %s, vergeben ist es an %s. Vergabe ändern? Seite Vergaben (/amisia vergaben)."]:format(
                    itemLink(view), tr.partner, toText(view)) .. "|r")
            end
        end
    end
    if any and db then ns.HandoverLoaded(AmisiaDB) end
    scan()
    changed()
end

ns.OnEvent("TRADE_CLOSED", function()
    local tr = trade
    trade = nil
    if helper then helper:Hide() end
    if not tr or tr.closed then return end
    tr.closed = true
    if tr.cancelled and not tr.done then return end
    C_Timer.After(VERIFY_AFTER, function()
        local ok, err = pcall(verify, tr)
        if not ok then report(err) end
    end)
end)

-- For tests and the snapshot scene: the helper window after a refresh, the open trade.
function ns.HandoverHelper()
    if refreshHelper then refreshHelper() end
    return helper
end

---------------------------------------------------------------------------
-- Settings and the command
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "trade", label = L["Handel-Helfer"], order = 26, items = {
    { key = "trade.enabled", type = "toggle", label = L["Vergebene Items in deinen Taschen verfolgen"], default = true,
      tip = L["Liegt ein Item, das an jemand anderen vergeben ist, noch handelbar in deinen Taschen, steht es auf der Seite Vergaben unter \"Noch zu übergeben\". Eingelegt wird nur per Knopf am Handelsfenster, nie im Kampf; \"Handeln\" drückst du selbst."] },
    { key = "trade.warn", type = "choice", label = L["Warnungen"], default = "both",
      values = { { "both", L["bei 30 und 10 Minuten"] }, { "ten", L["nur bei 10 Minuten"] }, { "off", L["aus##Warnungen"] } },
      tip = L["Nur in deinem Chat. Ohne Handelszeit im Tooltip des Items gibt es keine Warnung."] },
    { key = "trade.sound", type = "toggle", label = L["Ton bei einer Warnung"], default = true },
}}

local function say(e)
    ns.msg(L["%s an %s, %s"]:format(itemLink(e), toText(e), ns.HandoverLeftText(e)))
end

ns.RegisterSlash("uebergabe", { en = "handover", desc = L["Items, die du noch übergeben musst"], run = function()   -- l10n-ok: the German command word
    if not enabled() then
        ns.msg(L["Der Handel-Helfer ist aus (Einstellungen, Handel-Helfer)."])
        return
    end
    local list = ns.HandoverList()
    if #list == 0 then
        ns.msg(L["Nichts zu übergeben."])
        return
    end
    ns.msg(L["Noch zu übergeben: %d"]:format(#list))
    for _, e in ipairs(list) do say(e) end
    if ns.ShowHandover then ns.ShowHandover() end
end })
