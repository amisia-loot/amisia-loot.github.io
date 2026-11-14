-- Amisia core: the version, item helpers, one item tooltip hook for every part, the loot line
-- parser, the chat announcement, the event frame every part registers its events with, and the
-- load of AmisiaDB (migration, settings). The raid recording is Raid/Record.lua.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

-- The version stands only in the TOC (## Version), read once at load.
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
ns.VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "0.0.0"

-- The item functions live in C_Item (WoW Forever has no GetItemInfo global).
local GetItemInfo = C_Item.GetItemInfo

-- Item id from a link or an "item:1234" string, or nil.
function ns.ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- C_Item.GetItemInfo(x) as the client has it at the call (nothing without C_Item).
function ns.ItemInfo(x)
    local f = C_Item and C_Item.GetItemInfo
    if f then return f(x) end
    return nil
end

---------------------------------------------------------------------------
-- Item tooltips: one hook for every part of Amisia
---------------------------------------------------------------------------
-- fn(tip, link, id) runs for every item tooltip and returns true when it added a line; it then
-- runs no more for that tooltip until the tooltip is cleared (a tooltip can be handed to the hook
-- twice for one item). Every part runs protected: an error goes to the error handler, the tooltip
-- and the other parts' lines stay. Parts only ever add lines, never set, clear or show a tooltip.
local tipParts = {}
function ns.OnItemTooltip(key, fn)
    tipParts[#tipParts + 1] = { key = key, fn = fn, label = "Tooltip Item " .. tostring(key) }
end

local tipDone = setmetatable({}, { __mode = "k" })     -- tooltip -> { link, [key] = true }
local tipWatched = setmetatable({}, { __mode = "k" })
local tipBusy = false

local function tipLink(tip)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local ok, _, link = pcall(TooltipUtil.GetDisplayedItem, tip)
        if not ok then link = nil end
        -- TBC and Era: a tooltip built the old way carries no tooltip data, its GetItem knows the item
        if link or ns.FOREVER then return link end
    end
    if tip.GetItem then
        local _, link = tip:GetItem()
        return link
    end
end

local tipReport = ns.ReportError

-- /amisia leistung times the whole as "Tooltip Item" and each part under its key (F-184)
local onItemTooltip = ns.Perf.Wrap("Tooltip Item", function(tip)
    -- a part that builds another item tooltip comes back here: nothing then
    if tipBusy or type(tip) ~= "table" or not tip.AddLine then return end
    local ok, link = pcall(tipLink, tip)
    link = ok and ns.Plain(link) or nil
    local id = ns.ItemID(link)
    if not id then return end
    if not tipWatched[tip] and tip.HookScript then
        tipWatched[tip] = true
        tip:HookScript("OnTooltipCleared", ns.Perf.Wrap("Tooltip Item cleared", function(self) tipDone[self] = nil end))
    end
    local done = tipDone[tip]
    if not done or done.link ~= link then
        done = { link = link }
        tipDone[tip] = done
    end
    local errors
    tipBusy = true
    for _, part in ipairs(tipParts) do
        if not done[part.key] then
            local ok2, added
            if ns.Perf.on then ok2, added = ns.Perf.PCall(part.label, part.fn, tip, link, id) else ok2, added = pcall(part.fn, tip, link, id) end
            if not ok2 then
                errors = errors or {}
                errors[#errors + 1] = added
            elseif added then
                done[part.key] = true
            end
        end
    end
    tipBusy = false
    for _, err in ipairs(errors or {}) do tipReport(err) end
end)

-- The tooltip data processor serves every item tooltip (also SetLootRollItem and SetHyperlink).
-- Without it (a client that lacks it) there are no Amisia lines, and no error.
if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
end
-- TBC and Era (D-57) still build item tooltips the old way: the tooltip's OnTooltipSetItem, not the
-- data processor. Both may fire for one item; tipDone keeps every part to one line per item.
if not ns.FOREVER then
    for _, tip in ipairs({ _G.GameTooltip, _G.ItemRefTooltip }) do
        if type(tip) == "table" and tip.HookScript and (not tip.HasScript or tip:HasScript("OnTooltipSetItem")) then
            pcall(tip.HookScript, tip, "OnTooltipSetItem", onItemTooltip)
        end
    end
end

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

-- Upgrades as every part shows them: the raid's need answers and roll window (Raid/Need.lua) and the
-- gear module's comparisons (Gear/Bis.lua). (Were Gear/Bis.lua's; F-202.)
-- "+1,6 %", "-0,4 %", "+12 %" (whole numbers from 10 on).
function ns.UpgradePct(x)
    local a = math.abs(x)
    return (x < 0 and "-" or "+") .. ns.Num(a, a < 10 and 1 or 0) .. " %"
end

-- The percent of an upgrade as shown everywhere: { total } (the whole output), else { pct } (the
-- slot's score, an answer of an older Amisia: alt), 999 or nothing: "neu".
function ns.UpgradePctText(e)
    if type(e) ~= "table" then return L["neu"] end
    if type(e.total) == "number" then return ns.UpgradePct(e.total) end
    if type(e.pct) ~= "number" or e.pct == 999 then return L["neu"] end
    return ("%+d %%"):format(e.pct) .. (e.alt and L[" (alt)"] or "")
end
-- The order of such entries: whole-output percents first, then old slot percents.
function ns.UpgradeSortValue(e)
    if type(e.total) == "number" then return e.total end
    if e.pct == 999 then return 1e6 end
    return -1e6 + (tonumber(e.pct) or 0)
end

-- Seconds after midnight before which a raid counts for the night before (record.nightStart).
local function nightStart()
    return (ns.Get("record.nightStart") or 360) * 60
end
ns.NightStart = nightStart

local DB            -- AmisiaDB, set on ADDON_LOADED

local function msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe2b857Amisia:|r " .. text)
end
ns.msg = msg

function ns.ItemName(id)
    local name = GetItemInfo(id)
    return name or (ns.MATS and ns.MATS[id]) or ("Item " .. tostring(id))
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

ns.BuildMatcher = buildMatcher

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
                who = ns.UnitFullName("player")
                link = a[1]
                count = entry.hasCount and a[2] or 1
            else
                who = a[1]
                link = a[2]
                count = entry.hasCount and a[3] or 1
            end
            local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if who and who ~= "" and id then
                who = ns.FullName(who)
                return who, id, tonumber(count) or 1, link
            end
        end
    end
    return nil
end

-- Returns name, itemID, count and the item link for a loot chat line, or nil (the loot toast, D-79).
function ns.ParseLootLink(text) return parseLoot(text) end

-- Returns name, itemID, count for a loot chat line, or nil.
function ns.ParseLoot(text)
    local who, id, count = parseLoot(text)
    if not who then return nil end
    return who, id, count
end

-- The raid night ("YYYY-MM-DD") a moment belongs to (record.nightStart).
function ns.NightOf(t)
    return date("%Y-%m-%d", (t or time()) - nightStart())
end

-- Chat announcement for the group: raid warning for leader or assistant (unless rolls.channel says
-- raid), else raid, else party. Goes through the chat queue (Chat.lua); ttl: seconds the line may
-- wait there (a countdown is worthless later).
function ns.Announce(text, ttl)
    if not IsInGroup() then return end
    local chan = "PARTY"
    if IsInRaid() then
        local warn = ns.Get("rolls.channel") ~= "RAID" and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
        chan = warn and "RAID_WARNING" or "RAID"
    end
    return ns.Say(text, chan, nil, ttl and { ttl = ttl } or nil)
end

-- Modules add handlers for events; the core frame registers them. extraLabel[event][i] is the label
-- /amisia leistung times handler i under: "Event NAME File:line" of its registration (F-184).
local extra, extraLabel = {}, {}
local events -- the event frame, created below
local perf = ns.Perf

function ns.OnEvent(event, fn)
    extra[event] = extra[event] or {}
    extra[event][#extra[event] + 1] = fn
    extraLabel[event] = extraLabel[event] or {}
    extraLabel[event][#extra[event]] = perf.HandlerLabel("Event", event, perf.Where(2))
    -- pcall: an event one client does not know must not stop the addon
    if events then pcall(events.RegisterEvent, events, event) end
end

-- A short fingerprint of a string: two running sums, each kept below 2^32.
local function checksum(str)
    local h1, h2 = 5381, 0
    for i = 1, #str do
        h1 = (h1 * 33 + str:byte(i)) % 4294967296
        h2 = (h2 + h1) % 4294967296
    end
    return ("%08x%08x"):format(h1, h2)
end
ns.Checksum = checksum

-- A delay from 0 to n seconds (in tenths) that is the same for name on every call, so that many
-- clients answering one question do not all answer at once.
function ns.Spread(n, name)
    local h = tonumber(checksum(name or "?"):sub(1, 6), 16) or 0
    return (h % (n * 10)) / 10
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
for ev in pairs(extra) do pcall(events.RegisterEvent, events, ev) end
local loginHandedOn = false   -- ns.LoginLoaded ran the PLAYER_LOGIN the client may still deliver
local function onEvent(self, event, arg1, ...)
    if event == "PLAYER_LOGIN" and loginHandedOn and self == events then
        loginHandedOn = false
        return
    end
    -- /amisia leistung: the core's own part of an event is timed as "Core EVENT" (F-184)
    local p0, p1, p2, p3
    if (perf.on or perf.boot) and (event ~= "ADDON_LOADED" or arg1 == ADDON) then p0, p1, p2, p3 = perf.Begin() end
    if event == "ADDON_LOADED" then
        -- once: Locales/Locale.lua hands the event on (ns.CoreLoaded) and the client may deliver it
        -- too; the first run unregisters it
        if arg1 ~= ADDON or (self.IsEventRegistered and not self:IsEventRegistered("ADDON_LOADED")) then return end
        AmisiaDB = AmisiaDB or {}
        DB = AmisiaDB
        DB.settings = DB.settings or {}
        -- the saved measurements, and a measurement of this login if one was asked for (Core/PerfReport.lua)
        if ns.PerfLoaded then ns.PerfLoaded(DB) end
        -- the steps of the saved data's version first: they may move a setting before it is checked
        if ns.Migrate then ns.Migrate(DB) end
        ns.ApplySettings(DB)
        -- AmisiaDB.sync, and the versions seen cleaned (30 days, 300 entries)
        if ns.VersionLoaded then ns.VersionLoaded(DB) end
        -- the modules' own cleanup follows as their ADDON_LOADED handlers (ns.OnEvent): the raid
        -- recording's first (Raid/Record.lua, right after this file)
        self:UnregisterEvent("ADDON_LOADED")
    end
    if p0 then perf.End(perf.Label("Core ", event), p0, p1, p2, p3) end
    local list = extra[event]
    if list then
        -- one failing handler must not keep the others from their event: each runs protected and
        -- its error goes to the client's error handler once all have run; while /amisia leistung
        -- measures (or the login's steps are timed) each is timed under its label
        local failed
        local labels = (perf.on or perf.boot) and extraLabel[event]
        for i, fn in ipairs(list) do
            local ok, err
            if labels then ok, err = perf.PCall(labels[i], fn, arg1, ...) else ok, err = pcall(fn, arg1, ...) end
            if not ok then
                failed = failed or {}
                failed[#failed + 1] = err
            end
        end
        if failed then
            for _, err in ipairs(failed) do ns.ReportError(err) end
        end
    end
    -- the login's steps end with the first PLAYER_ENTERING_WORLD after loading
    if perf.boot and event == "PLAYER_ENTERING_WORLD" then perf.BootDone() end
end
events:SetScript("OnEvent", onEvent)
-- the files' bodies run on ADDON_LOADED (D-128, D-130): this frame registers during that event, so
-- Locales/Locale.lua hands it on once every body of the core and the modules ran
local replayed = 0   -- the ADDON_LOADED handlers that had their event
function ns.CoreLoaded()
    onEvent(events, "ADDON_LOADED", ADDON)
    replayed = extra.ADDON_LOADED and #extra.ADDON_LOADED or 0
end

-- A module the client loaded after the core started (Locales/Locale.lua): the ADDON_LOADED handlers
-- its bodies added since get the core's event now, each protected.
function ns.LateLoaded()
    local list = extra.ADDON_LOADED
    if not list then return end
    for i = replayed + 1, #list do
        local ok, err = pcall(list[i], ADDON)
        if not ok then ns.ReportError(err) end
    end
    replayed = #list
end

-- The bodies ran at PLAYER_LOGIN (a module the core waited for did not come): the handlers registered
-- during that event get it now, once (the client may deliver it to the new frame as well: dropped).
function ns.LoginLoaded()
    onEvent(nil, "PLAYER_LOGIN")
    loginHandedOn = true
    if C_Timer and C_Timer.After then C_Timer.After(0, function() loginHandedOn = false end) end
end

end)
