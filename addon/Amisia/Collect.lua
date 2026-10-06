-- Amisia item collector: every item the player meets is stored like a scanned item, with where it
-- was seen: bags and equipment, merchants, quest rewards, auction house pages, loot windows,
-- tooltips and chat links. Items the client has not cached yet are requested and stored on arrival.
--
-- Source notes, read by tools/build_scan.py and tools/build_gear.py:
--   "Drop: <mob> [<npcID>] @<zone or instance> #<instance type>:<instanceID>"   (# part only inside instances)
--   "Haendler: <name> [<npcID>] @<zone>"
--   "Quest: <title> [<questID>] L<player level>"
--   "Auktionshaus"
-- Older notes have only the name; every part after it is optional.
local ADDON, ns = ...

local MAX_SOURCES = 6
local wanted = {}   -- itemID -> source text, waiting for the client's item data

local function enabled()
    return AmisiaDB ~= nil and ns.Get("tools.collect") and ns.StoreItem
end

local function sourcesOf(id)
    local s = ns.ScanDB()
    s.sources = s.sources or {}
    return s
end

local function addSource(id, source)
    if not source or source == "" then return end
    local s = sourcesOf(id)
    local list = s.sources[id]
    if not list then
        list = {}
        s.sources[id] = list
        s.sourceCount = (s.sourceCount or 0) + 1
    end
    for _, v in ipairs(list) do
        if v == source then return end
    end
    if #list < MAX_SOURCES then list[#list + 1] = source end
end

-- Random suffixes ("...des Adlers"): which an item can roll is not in the client tables, so the
-- collector keeps what it sees. scan.suffix[item][suffix id] = the item's stats with that suffix
-- as C_Item.GetItemStats gives them for the link ("STRENGTH=5;STAMINA=4", keys without ITEM_MOD_
-- and _SHORT, only those the planner scores); read by Gear.SuffixStats and tools/build_bis.py.
local MAX_SUFFIX_ITEMS, MAX_SUFFIXES = 1500, 12

-- The suffix id of an item link (item:id:enchant:gem1:gem2:gem3:gem4:suffix:...), or nil for none.
function ns.LinkSuffix(link)
    if type(link) ~= "string" then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local i = 0
    for field in (body .. ":"):gmatch("([^:]*):") do
        i = i + 1
        if i == 7 then
            local v = tonumber(field)
            return (v and v ~= 0) and v or nil
        end
    end
    return nil
end

local function noteSuffix(id, link)
    local suffix = ns.LinkSuffix(link)
    if not suffix or not (C_Item and C_Item.GetItemStats) then return end
    local s = ns.ScanDB()
    s.suffix = type(s.suffix) == "table" and s.suffix or {}
    local seen = s.suffix[id]
    if seen and seen[suffix] then return end
    if not seen then
        local n = 0
        for _ in pairs(s.suffix) do n = n + 1 end
        if n >= MAX_SUFFIX_ITEMS then return end
    else
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        if n >= MAX_SUFFIXES then return end
    end
    local ok, raw = pcall(C_Item.GetItemStats, link)
    if not ok or type(raw) ~= "table" then return end
    local parts = {}
    local STAT = ns.Gear and ns.Gear.STAT or {}
    for k, v in pairs(raw) do
        if type(k) == "string" and type(v) == "number" and v ~= 0 and STAT[k] then
            parts[#parts + 1] = (k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "")) .. "=" .. tostring(v)
        end
    end
    if #parts == 0 then return end
    table.sort(parts)
    seen = seen or {}
    s.suffix[id] = seen
    seen[suffix] = table.concat(parts, ";")
    if ns.Gear and ns.Gear.SuffixNoted then ns.Gear.SuffixNoted(id) end
end
ns.NoteSuffix = noteSuffix

-- Records an item by id or link. Returns true when it is stored now, false when requested.
function ns.NoteItem(idOrLink, source)
    if not enabled() then return nil end
    local id = tonumber(idOrLink) or ns.ItemID(idOrLink)
    if not id then return nil end
    addSource(id, source)
    if type(idOrLink) == "string" then pcall(noteSuffix, id, idOrLink) end
    if ns.StoreItem(id) then return true end
    wanted[id] = source or false
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return false
end

function ns.CollectCount()
    local s = AmisiaDB and AmisiaDB.scan
    return s and s.sourceCount or 0
end

local function onLoaded(id, success)
    id = tonumber(id)
    if not id or wanted[id] == nil then return end
    if success ~= false and ns.StoreItem(id) then wanted[id] = nil end
    if success == false then wanted[id] = nil end
end
ns.OnEvent("ITEM_DATA_LOAD_RESULT", onLoaded)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", onLoaded)

-- NPC id from a creature GUID ("Creature-0-3110-0-47-644-00002E7CF2" -> 644).
function ns.NpcID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

-- " @<zone>", plus " #<type>:<instanceID>" inside a dungeon or raid.
local function placeTag()
    local name, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
    if kind == "party" or kind == "raid" then
        return (" @%s #%s:%d"):format(name or "?", kind, tonumber(instanceID) or 0)
    end
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    return zone ~= "" and (" @" .. zone) or ""
end
ns.PlaceTag = placeTag

-- The name of a unit token whose GUID is the given one, if any.
local function nameOfGUID(guid)
    if not guid then return nil end
    for _, unit in ipairs({ "target", "mouseover", "focus" }) do
        if UnitGUID(unit) == guid then return UnitName(unit) end
    end
    return nil
end

---------------------------------------------------------------------------
-- Bags and equipment
---------------------------------------------------------------------------
local containerLink = C_Container and C_Container.GetContainerItemLink
local containerSlots = C_Container and C_Container.GetContainerNumSlots

local function scanBags(first, last)
    if not enabled() or not containerLink or not containerSlots then return end
    for bag = first, last do
        for slot = 1, containerSlots(bag) or 0 do
            local link = containerLink(bag, slot)
            if link then ns.NoteItem(link) end
        end
    end
end

local function scanEquipment()
    if not enabled() or not GetInventoryItemLink then return end
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then ns.NoteItem(link) end
    end
end

ns.OnEvent("BAG_UPDATE_DELAYED", function() scanBags(0, 4) end)
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", scanEquipment)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(3, function() scanBags(0, 4); scanEquipment() end)
end)
-- The bank tabs of the character bank (ns.BankTabs, Bis.lua); -1 is the keyring and 5 the reagent bag.
ns.OnEvent("BANKFRAME_OPENED", function()
    for _, bag in ipairs(ns.BankTabs and ns.BankTabs() or {}) do scanBags(bag, bag) end
end)

---------------------------------------------------------------------------
-- Merchants
---------------------------------------------------------------------------
ns.OnEvent("MERCHANT_SHOW", function()
    if not enabled() or not GetMerchantNumItems or not GetMerchantItemLink then return end
    local who = UnitName("npc") or UnitName("target") or "?"
    local npc = ns.NpcID(UnitGUID("npc"))
    local note = "Haendler: " .. who .. (npc and (" [" .. npc .. "]") or "") .. placeTag()
    for i = 1, GetMerchantNumItems() or 0 do
        local link = GetMerchantItemLink(i)
        if link then ns.NoteItem(link, note) end
    end
end)

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
local function questRewards()
    if not enabled() or not GetQuestItemLink then return end
    local title = (GetTitleText and GetTitleText()) or "?"
    local qid = GetQuestID and GetQuestID()
    local level = UnitLevel and UnitLevel("player")
    local note = "Quest: " .. title .. ((qid and qid > 0) and (" [" .. qid .. "]") or "") .. ((level and level > 0) and (" L" .. level) or "")
    for _, kind in ipairs({ "reward", "choice" }) do
        local n = kind == "reward" and (GetNumQuestRewards and GetNumQuestRewards() or 0) or (GetNumQuestChoices and GetNumQuestChoices() or 0)
        for i = 1, n do
            local link = GetQuestItemLink(kind, i)
            if link then ns.NoteItem(link, note) end
        end
    end
end
ns.OnEvent("QUEST_DETAIL", questRewards)
ns.OnEvent("QUEST_COMPLETE", questRewards)

---------------------------------------------------------------------------
-- Auction house: the browse results
---------------------------------------------------------------------------
local function browseResults()
    if not enabled() or not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then return end
    for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
        local id = r.itemKey and r.itemKey.itemID
        if id then ns.NoteItem(id, "Auktionshaus") end
    end
end
ns.OnEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", browseResults)
ns.OnEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", browseResults)
ns.OnEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(id) if id then ns.NoteItem(id, "Auktionshaus") end end)
ns.OnEvent("ITEM_SEARCH_RESULTS_UPDATED", function(key)
    local id = type(key) == "table" and key.itemID or tonumber(key)
    if id then ns.NoteItem(id, "Auktionshaus") end
end)

---------------------------------------------------------------------------
-- Loot windows and loot lines
---------------------------------------------------------------------------
ns.OnEvent("LOOT_OPENED", function()
    -- the boss kill records (Drops.lua) first; an error there loses only that window, not the notes
    if ns.DropsFromLoot then
        local ok, err = pcall(ns.DropsFromLoot)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
    -- then the drops of the other corpses (Collector.lua), outside the boss records
    if ns.CollectorFromLoot then
        local ok, err = pcall(ns.CollectorFromLoot)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
    if not enabled() or not GetNumLootItems or not GetLootSlotLink then return end
    local place = placeTag()
    for slot = 1, GetNumLootItems() or 0 do
        -- a secret link or source GUID (a boss fight on Forever) is skipped
        local link = ns.Plain(GetLootSlotLink(slot))
        local src = GetLootSourceInfo and ns.Plain((GetLootSourceInfo(slot))) or nil
        if link and not (type(src) == "string" and src:find("^Item%-")) then
            -- the corpse this slot came from: its NPC id always, its name when it is targeted
            local npc = ns.NpcID(src)
            local who = nameOfGUID(src) or (not npc and UnitName("target")) or nil
            if who or npc then
                ns.NoteItem(link, "Drop: " .. (who or "?") .. (npc and (" [" .. npc .. "]") or "") .. place)
            else
                ns.NoteItem(link)
            end
        end
    end
end)

ns.OnEvent("CHAT_MSG_LOOT", function(text)
    if not enabled() or type(text) ~= "string" then return end
    for id in text:gmatch("item:(%d+)") do ns.NoteItem(tonumber(id)) end
end)

---------------------------------------------------------------------------
-- Tooltips and chat links
---------------------------------------------------------------------------
-- through the shared item tooltip hook (Core.lua); it adds no line
ns.OnItemTooltip("collect", function(_, link)
    if enabled() then ns.NoteItem(link) end
end)

local function chatLinks(text)
    if not enabled() or type(text) ~= "string" then return end
    for id in text:gmatch("|Hitem:(%d+)") do ns.NoteItem(tonumber(id)) end
end
for _, ev in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                      "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM" }) do
    ns.OnEvent(ev, chatLinks)
end

ns.RegisterSlash("sammeln", { aliases = { "collect" }, desc = "Item-Sammler an oder aus", run = function()
    ns.Set("tools.collect", not ns.Get("tools.collect"))
    ns.msg(ns.Get("tools.collect") and "Item-Sammler an: Taschen, Händler, Quests, Auktionshaus, Tooltips und Loot werden aufgenommen."
        or "Item-Sammler aus.")
end })
