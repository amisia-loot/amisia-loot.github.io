-- Amisia: records who was in each raid, which guild materials and which blue or better items
-- were looted and what lay in opened loot windows, and exports it as text for the Import tab
-- of the Amisia loot ledger.
local ADDON, ns = ...

ns.VERSION = "1.1.0"

-- Tracked guild bank materials. Names are fallbacks until the client has the item cached.
ns.MATS = {
    [32897] = "Mal der Illidari",
    [32428] = "Herz der Dunkelheit",
    -- epic raw gems from Black Temple and Sunwell Plateau trash
    [32227] = "Crimson Spinel",
    [32228] = "Empyrean Sapphire",
    [32229] = "Lionseye",
    [32230] = "Shadowsong Amethyst",
    [32231] = "Pyrestone",
    [32249] = "Seaspray Emerald",
}
ns.MAT_ORDER = { 32897, 32428, 32227, 32228, 32229, 32230, 32231, 32249 }
ns.GEMS = { [32227] = true, [32228] = true, [32229] = true, [32230] = true, [32231] = true, [32249] = true }

function ns.GemCount(counts)
    local n = 0
    for id in pairs(ns.GEMS) do n = n + (counts[id] or 0) end
    return n
end

-- Loot of this quality or better is recorded besides the materials: 3 rare (blue), 4 epic, 5 legendary.
ns.MIN_QUALITY = 3
-- Blue or better items that are no raid loot worth listing: disenchanting results and Badges of Justice,
-- which every raider loots from every boss.
ns.IGNORE = {
    [29434] = true, -- Badge of Justice
    [22450] = true, -- Void Crystal
    [22449] = true, -- Large Prismatic Shard
    [22448] = true, -- Small Prismatic Shard
    [20725] = true, -- Nexus Crystal
    [14344] = true, -- Large Brilliant Shard
    [14343] = true, -- Small Brilliant Shard
}
local LINK_QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }

-- Quality from the colour of an item link, so items the client has not cached yet still count.
function ns.LinkQuality(link)
    if type(link) ~= "string" then return nil end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    local q = hex and LINK_QUALITY[hex:lower()]
    if q then return q end
    local _, _, itemQuality = GetItemInfo(link)
    return itemQuality
end

local REUSE_WINDOW  = 2 * 60 * 60  -- re-entering the same raid within 2 hours continues its session
local NIGHT_START   = 6 * 60 * 60  -- a session starting before 06:00 belongs to the previous raid night
local ROSTER_EVERY  = 60           -- seconds between roster snapshots while recording
local KEEP_SESSIONS = 60           -- oldest sessions beyond this are dropped

local DB            -- AmisiaDB, set on ADDON_LOADED
local active        -- the session currently being recorded, or nil
local ticker        -- roster snapshot ticker while recording
local rosterPending -- throttles bursts of GROUP_ROSTER_UPDATE

local function msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe2b857Amisia:|r " .. text)
end
ns.msg = msg

local function refresh()
    if ns.Refresh then ns.Refresh() end
end

function ns.ItemName(id)
    local name = GetItemInfo(id)
    return name or ns.MATS[id] or ("Item " .. tostring(id))
end

---------------------------------------------------------------------------
-- Loot messages
-- The patterns come from the client's own format strings, so a German,
-- English or any other client parses its own chat lines correctly. Numbered
-- specifiers such as %2$s are mapped back to their argument position.
---------------------------------------------------------------------------
local function buildMatcher(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local pat = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local order, n = {}, 0
    -- numbered specifiers read %%1%$s after escaping
    pat = pat:gsub("%%%%(%d+)%%%$([sd])", function(idx, kind)
        n = n + 1
        order[n] = tonumber(idx)
        return kind == "d" and "(%d+)" or "(.-)"
    end)
    -- plain specifiers read %%s after escaping
    pat = pat:gsub("%%%%([sd])", function(kind)
        n = n + 1
        order[n] = n
        return kind == "d" and "(%d+)" or "(.-)"
    end)
    if n == 0 then return nil end
    pat = "^" .. pat .. "$"
    return function(text)
        local caps = { text:match(pat) }
        if #caps < n then return nil end
        local args = {}
        for i = 1, n do args[order[i]] = caps[i] end
        return args
    end
end

local matchers -- built on first use, when the global strings are certainly loaded

local function getMatchers()
    if matchers then return matchers end
    matchers = {}
    local function add(key, mine, hasCount)
        local m = buildMatcher(_G[key])
        if m then matchers[#matchers + 1] = { match = m, mine = mine, hasCount = hasCount } end
    end
    -- Most specific first: a single-item pattern would also accept a line ending in "x3".
    add("LOOT_ITEM_SELF_MULTIPLE", true, true)
    add("LOOT_ITEM_SELF", true, false)
    add("LOOT_ITEM_PUSHED_SELF_MULTIPLE", true, true)
    add("LOOT_ITEM_PUSHED_SELF", true, false)
    add("LOOT_ITEM_MULTIPLE", false, true)
    add("LOOT_ITEM", false, false)
    add("LOOT_ITEM_PUSHED_MULTIPLE", false, true)
    add("LOOT_ITEM_PUSHED", false, false)
    return matchers
end

-- Returns name, itemID, count and the item link for a loot chat line, or nil.
local function parseLoot(text)
    if type(text) ~= "string" then return nil end
    for _, entry in ipairs(getMatchers()) do
        local a = entry.match(text)
        if a then
            local who, link, count
            if entry.mine then
                who = UnitName("player")
                link = a[1]
                count = entry.hasCount and a[2] or 1
            else
                who = a[1]
                link = a[2]
                count = entry.hasCount and a[3] or 1
            end
            local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if who and who ~= "" and id then
                return who, id, tonumber(count) or 1, link
            end
        end
    end
    return nil
end

-- Returns name, itemID, count for a loot chat line, or nil.
function ns.ParseLoot(text)
    local who, id, count = parseLoot(text)
    if not who then return nil end
    return who, id, count
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------
local function raidInstance()
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    return instanceType == "raid", name, instanceID
end

local function newSession(zone, instanceID)
    local t = time()
    local s = {
        id = date("%Y%m%d%H%M%S", t) .. "-" .. tostring(instanceID or 0),
        start = t,
        last = t,
        date = date("%Y-%m-%d", t - NIGHT_START),
        zone = zone or "?",
        instanceID = instanceID or 0,
        members = {},
        loot = {},
        items = {},   -- blue or better loot: { name, item, count, t }
        drops = {},   -- opened loot windows by source GUID: { src, t, items = { [itemID] = count } }
    }
    DB.sessions[#DB.sessions + 1] = s
    while #DB.sessions > KEEP_SESSIONS do
        table.remove(DB.sessions, 1)
    end
    return s
end

local function findReusable(instanceID)
    local t = time()
    for i = #DB.sessions, 1, -1 do
        local s = DB.sessions[i]
        if s.instanceID == instanceID and (t - (s.last or s.start or 0)) <= REUSE_WINDOW then
            return s
        end
    end
    return nil
end

local function noteMember(s, name, class, t)
    local m = s.members[name]
    if m then
        m.last = t
        if class and class ~= "" then m.class = class end
    else
        s.members[name] = { class = class or "", first = t, last = t }
    end
end

local function snapshotRoster()
    if not active then return end
    local t = time()
    local n = GetNumGroupMembers() or 0
    -- The recorder's own roster line gives the zone string that means "inside the raid".
    local me, here = UnitName("player"), nil
    for i = 1, n do
        local name, _, _, _, _, _, zone = GetRaidRosterInfo(i)
        if name == me then
            here = zone
            break
        end
    end
    for i = 1, n do
        local name, _, _, _, _, class, zone, online = GetRaidRosterInfo(i)
        -- Offline members and members waiting outside (bench, city) are not in the raid.
        if name and name ~= "" and online and (not here or zone == here) then
            noteMember(active, name, class, t)
        end
    end
    active.last = t
    refresh()
end

local function startTicker()
    if ticker then return end
    ticker = C_Timer.NewTicker(ROSTER_EVERY, function() snapshotRoster() end)
end

local function stopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function stopRecording()
    if not active then return end
    snapshotRoster()
    msg(("Aufnahme beendet: %s, %d Raider."):format(active.zone, ns.MemberCount(active)))
    active = nil
    stopTicker()
    refresh()
end

local function evaluate()
    if not DB then return end
    if not DB.settings.enabled then
        stopRecording()
        return
    end
    local isRaid, zone, instanceID = raidInstance()
    if isRaid and IsInRaid() then
        if not active or active.instanceID ~= instanceID then
            if active then stopRecording() end
            local s = findReusable(instanceID)
            if s then
                active = s
                msg(("Aufnahme fortgesetzt: %s (%s)."):format(s.zone, s.date))
            else
                active = newSession(zone, instanceID)
                msg(("Aufnahme gestartet: %s. /amisia zeigt die Liste."):format(active.zone))
            end
        end
        startTicker()
        snapshotRoster()
    elseif active then
        stopRecording()
    end
    refresh()
end

-- Remembers an item's name and quality from its link for the export.
local function rememberItem(id, link, q)
    if not DB then return end
    local name = type(link) == "string" and link:match("|h%[(.-)%]|h")
    local known = DB.itemNames[id]
    DB.itemNames[id] = { n = name or (known and known.n) or ("Item " .. id), q = q or (known and known.q) or 0 }
end

local function onLoot(text)
    if not active then return end
    local who, id, count, link = parseLoot(text)
    if not who then return end
    local t = time()
    if ns.MATS[id] then
        active.loot[#active.loot + 1] = { name = who, item = id, count = count, t = t }
    else
        local q = ns.LinkQuality(link)
        if not q or q < ns.MIN_QUALITY or ns.IGNORE[id] then return end
        rememberItem(id, link, q)
        active.items[#active.items + 1] = { name = who, item = id, count = count, t = t }
    end
    noteMember(active, who, nil, t)
    refresh()
end

-- What lies in a loot window the recorder opens: a boss or trash corpse, or a chest in the raid.
-- The slots of one window are added up (a boss can drop the same token twice); reopening the
-- same corpse keeps the larger total instead of adding it again.
local function onLootOpened()
    if not active or not GetNumLootItems or not GetLootSlotLink then return end
    local targetGUID = UnitGUID and UnitGUID("target")
    local targetName = UnitName("target")
    local seen = {}   -- source -> { [itemID] = count in this window }
    for slot = 1, GetNumLootItems() or 0 do
        local link = GetLootSlotLink(slot)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        local q = id and ns.LinkQuality(link)
        if id and q and q >= ns.MIN_QUALITY and not ns.MATS[id] and not ns.IGNORE[id] then
            local source = (GetLootSourceInfo and GetLootSourceInfo(slot)) or targetGUID or ("?" .. (targetName or ""))
            -- a container opened from the bags is not a drop
            if type(source) == "string" and not source:find("^Item%-") then
                local _, _, qty = GetLootSlotInfo(slot)
                seen[source] = seen[source] or {}
                seen[source][id] = (seen[source][id] or 0) + (tonumber(qty) or 1)
                rememberItem(id, link, q)
            end
        end
    end
    local t, any = time(), false
    for source, items in pairs(seen) do
        local d = active.drops[source]
        if not d then
            d = { src = "?", t = t, items = {} }
            active.drops[source] = d
        end
        if d.src == "?" and targetName and source == targetGUID then d.src = targetName end
        for id, n in pairs(items) do
            d.items[id] = math.max(d.items[id] or 0, n)
        end
        any = true
    end
    if any then refresh() end
end

---------------------------------------------------------------------------
-- Guild bank count
-- Counts the tracked materials in every guild bank tab the player may view.
-- A tab's items only arrive after QueryGuildBankTab, announced by
-- GUILDBANKBAGSLOTS_CHANGED, so every such event triggers a fresh count.
---------------------------------------------------------------------------
local BANK_SLOTS = 98
local HAS_BANK_API = GetGuildBankItemInfo and GetGuildBankItemLink and QueryGuildBankTab
    and GetNumGuildBankTabs and GetGuildBankTabInfo
local bankOpen, bankCounted, bankPending, bankNeedTabs = false, false, false, false

-- minFilled: when counting while the bank closes, a result with fewer tabs holding items than
-- the last count means the client already dropped tab data, so it is thrown away.
local function countBank(minFilled)
    bankPending = false
    if not bankOpen or not DB then return end
    local tabs = GetNumGuildBankTabs() or 0
    if tabs == 0 then return end -- tab list not here yet, GUILDBANK_UPDATE_TABS retries
    local counts, viewable, filled = {}, 0, 0
    for id in pairs(ns.MATS) do counts[id] = 0 end
    for tab = 1, tabs do
        local _, _, isViewable = GetGuildBankTabInfo(tab)
        if isViewable then
            viewable = viewable + 1
            local any = false
            for slot = 1, BANK_SLOTS do
                local link = GetGuildBankItemLink(tab, slot)
                if link then
                    any = true
                    local id = tonumber(link:match("item:(%d+)"))
                    if id and counts[id] then
                        local _, count = GetGuildBankItemInfo(tab, slot)
                        counts[id] = counts[id] + (tonumber(count) or 1)
                    end
                end
            end
            if any then filled = filled + 1 end
        end
    end
    -- No tab has delivered items yet: keep the last good count instead of storing zeros.
    if filled == 0 then return end
    if minFilled and filled < minFilled then return end
    DB.bank = {
        at = time(),
        by = UnitName("player") or "?",
        guild = (GetGuildInfo("player")) or "",
        counts = counts,
        tabs = viewable,
        filled = filled,
        total = tabs,
    }
    bankCounted = true
    refresh()
end

local function scheduleBankCount()
    if bankPending then return end
    bankPending = true
    C_Timer.After(0.5, countBank)
end

local function queryBankTabs()
    local tabs = GetNumGuildBankTabs() or 0
    if tabs == 0 then
        bankNeedTabs = true
        return
    end
    bankNeedTabs = false
    local current = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
    for tab = 1, tabs do
        local _, _, isViewable = GetGuildBankTabInfo(tab)
        if isViewable and tab ~= current then QueryGuildBankTab(tab) end
    end
    if current and current >= 1 and current <= tabs then QueryGuildBankTab(current) end
    scheduleBankCount()
end

local function bankOpened(frame)
    if not HAS_BANK_API then return end
    if not bankOpen then bankCounted = false end
    bankOpen = true
    frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    frame:RegisterEvent("GUILDBANK_UPDATE_TABS")
    queryBankTabs()
end

local function bankClosed(frame, quiet)
    if not bankOpen then return end
    -- a change from the last moments is still waiting for the debounce: count it before closing
    if bankPending and not quiet then
        countBank((bankCounted and DB and DB.bank and DB.bank.filled) or 1)
    end
    bankOpen, bankNeedTabs = false, false
    frame:UnregisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    frame:UnregisterEvent("GUILDBANK_UPDATE_TABS")
    if not quiet and bankCounted and DB and DB.bank then
        local c = DB.bank.counts
        msg(("Gildenbank gezählt: Mal %d, Herz %d, Edelsteine %d (%d Tabs)."):format(
            c[32897] or 0, c[32428] or 0, ns.GemCount(c), DB.bank.tabs or 0))
        if (DB.bank.total or 0) > (DB.bank.tabs or 0) then
            msg(("%d von %d Tabs sind für dich nicht sichtbar. Ihr Inhalt fehlt in dieser Zählung."):format(
                (DB.bank.total or 0) - (DB.bank.tabs or 0), DB.bank.total or 0))
        end
        if (DB.bank.filled or 0) < (DB.bank.tabs or 0) then
            msg(("Nur %d von %d Tabs haben Gegenstände geliefert. Sind die übrigen nicht leer, die Bank beim nächsten Mal länger offen lassen."):format(
                DB.bank.filled or 0, DB.bank.tabs or 0))
        end
    end
end

function ns.Bank() return DB and DB.bank end

---------------------------------------------------------------------------
-- Public helpers for the window
---------------------------------------------------------------------------
function ns.Sessions() return DB and DB.sessions or {} end
function ns.Active() return active end
function ns.IsEnabled() return DB and DB.settings.enabled end

function ns.SetEnabled(on)
    if not DB then return end
    DB.settings.enabled = on and true or false
    msg(on and "Aufnahme aktiv." or "Aufnahme pausiert.")
    evaluate()
end

function ns.MemberCount(s)
    local n = 0
    for _ in pairs(s.members) do n = n + 1 end
    return n
end

function ns.ItemCount(s)
    local n = 0
    for _, l in ipairs(s.items or {}) do n = n + (l.count or 1) end
    return n
end

function ns.DropCount(s)
    local n = 0
    for _, d in pairs(s.drops or {}) do
        for _, c in pairs(d.items or {}) do n = n + c end
    end
    return n
end

function ns.MatCounts(s)
    local c = {}
    for _, l in ipairs(s.loot) do
        c[l.item] = (c[l.item] or 0) + (l.count or 1)
    end
    return c
end

function ns.DeleteSessions(ids)
    if not DB then return 0 end
    local keep, removed = {}, 0
    for _, s in ipairs(DB.sessions) do
        if ids[s.id] and s ~= active then
            removed = removed + 1
        else
            keep[#keep + 1] = s
        end
    end
    DB.sessions = keep
    refresh()
    return removed
end

-- Text block for the ledger's Import tab. One S..E block per session.
function ns.ExportText(list)
    local lines = { "#AMISIA 1 " .. (UnitName("player") or "?") }
    local used = {}   -- item ids of I and D lines, named in N lines at the end
    local bank = DB and DB.bank
    if bank and bank.counts then
        -- K <epoch seconds> <date> <HH:MM> <tabs with items> <tabs visible> <tabs total> <counted by>
        lines[#lines + 1] = ("K %d %s %s %d %d %d %s"):format(bank.at or 0, date("%Y-%m-%d", bank.at), date("%H:%M", bank.at),
            bank.filled or 0, bank.tabs or 0, bank.total or bank.tabs or 0, bank.by or "?")
        for _, id in ipairs(ns.MAT_ORDER) do
            lines[#lines + 1] = ("B %d %d"):format(id, bank.counts[id] or 0)
        end
    end
    for _, s in ipairs(list) do
        lines[#lines + 1] = ("S %s %s %d %s"):format(s.id, s.date, tonumber(s.instanceID) or 0, s.zone or "?")
        local names = {}
        for name in pairs(s.members) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local class = s.members[name].class
            lines[#lines + 1] = ("M %s %s"):format(name, (class and class ~= "") and class or "UNKNOWN")
        end
        local sum, keys = {}, {}
        for _, l in ipairs(s.loot) do
            local key = l.name .. "\t" .. l.item
            if not sum[key] then
                sum[key] = { name = l.name, item = l.item, count = 0 }
                keys[#keys + 1] = key
            end
            sum[key].count = sum[key].count + (l.count or 1)
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local e = sum[key]
            lines[#lines + 1] = ("L %s %d %d"):format(e.name, e.item, e.count)
        end
        -- I <name> <itemID> <count>: blue or better loot
        local isum, ikeys = {}, {}
        for _, l in ipairs(s.items or {}) do
            local key = l.name .. "\t" .. l.item
            if not isum[key] then
                isum[key] = { name = l.name, item = l.item, count = 0 }
                ikeys[#ikeys + 1] = key
            end
            isum[key].count = isum[key].count + (l.count or 1)
        end
        table.sort(ikeys)
        for _, key in ipairs(ikeys) do
            local e = isum[key]
            lines[#lines + 1] = ("I %s %d %d"):format(e.name, e.item, e.count)
            used[e.item] = true
        end
        -- D <itemID> <count> <source name>: blue or better items seen in loot windows
        local dsum, dkeys = {}, {}
        for _, d in pairs(s.drops or {}) do
            for id, c in pairs(d.items or {}) do
                local key = (d.src or "?") .. "\t" .. id
                if not dsum[key] then
                    dsum[key] = { item = id, src = d.src or "?", count = 0 }
                    dkeys[#dkeys + 1] = key
                end
                dsum[key].count = dsum[key].count + c
            end
        end
        table.sort(dkeys)
        for _, key in ipairs(dkeys) do
            local e = dsum[key]
            lines[#lines + 1] = ("D %d %d %s"):format(e.item, e.count, e.src)
            used[e.item] = true
        end
        lines[#lines + 1] = "E"
    end
    -- N <itemID> <quality> <item name>
    local ids = {}
    for id in pairs(used) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local known = DB and DB.itemNames[id]
        lines[#lines + 1] = ("N %d %d %s"):format(id, (known and known.q) or 0, GetItemInfo(id) or (known and known.n) or ("Item " .. id))
    end
    lines[#lines + 1] = "#END"
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        AmisiaDB = AmisiaDB or {}
        DB = AmisiaDB
        DB.sessions = DB.sessions or {}
        DB.settings = DB.settings or {}
        DB.itemNames = DB.itemNames or {}
        if DB.settings.enabled == nil then DB.settings.enabled = true end
        for _, s in ipairs(DB.sessions) do
            s.members = s.members or {}
            s.loot = s.loot or {}
            s.items = s.items or {}
            s.drops = s.drops or {}
        end
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("CHAT_MSG_LOOT")
        self:RegisterEvent("LOOT_OPENED")
        if HAS_BANK_API then
            -- pcall: a client without one of these events must not break loading
            for _, ev in ipairs({ "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
                                  "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED" }) do
                pcall(self.RegisterEvent, self, ev)
            end
        end
    elseif event == "CHAT_MSG_LOOT" then
        if active and type(arg1) == "string" then
            onLoot(arg1)
        end
    elseif event == "LOOT_OPENED" then
        onLootOpened()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not rosterPending then
            rosterPending = true
            C_Timer.After(2, function()
                rosterPending = false
                evaluate()
            end)
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if Enum and Enum.PlayerInteractionType and arg1 == Enum.PlayerInteractionType.GuildBanker then
            if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then bankOpened(self) else bankClosed(self) end
        end
    elseif event == "GUILDBANKFRAME_OPENED" then
        bankOpened(self)
    elseif event == "GUILDBANKFRAME_CLOSED" then
        bankClosed(self)
    elseif event == "GUILDBANK_UPDATE_TABS" then
        if bankOpen then
            if bankNeedTabs then queryBankTabs() else scheduleBankCount() end
        end
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        if bankOpen then scheduleBankCount() end
    else
        -- a loading screen always leaves the bank
        if event == "PLAYER_ENTERING_WORLD" then bankClosed(self, true) end
        -- instance information settles a moment after the loading screen
        C_Timer.After(1, evaluate)
    end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_AMISIA1 = "/amisia"
SlashCmdList.AMISIA = function(input)
    local cmd = ((input or ""):match("^%s*(.-)%s*$") or ""):lower()
    if cmd == "pause" then
        ns.SetEnabled(not ns.IsEnabled())
    elseif cmd == "status" then
        if active then
            local c = ns.MatCounts(active)
            msg(("Aufnahme: %s, %d Raider, Mal %d, Herz %d, Edelsteine %d."):format(active.zone, ns.MemberCount(active),
                c[32897] or 0, c[32428] or 0, ns.GemCount(c)))
        else
            msg(ns.IsEnabled() and "Keine Aufnahme. Sie startet in einer Raidinstanz mit Raidgruppe." or "Aufnahme pausiert. /amisia pause setzt sie fort.")
        end
        local bank = ns.Bank()
        if bank and bank.counts then
            local c = bank.counts
            msg(("Gildenbank vom %s: Mal %d, Herz %d, Edelsteine %d."):format(date("%d.%m. %H:%M", bank.at),
                c[32897] or 0, c[32428] or 0, ns.GemCount(c)))
        else
            msg("Gildenbank noch nicht gezählt. Öffne sie einmal.")
        end
    elseif ns.Toggle then
        ns.Toggle(cmd == "export")
    end
end
