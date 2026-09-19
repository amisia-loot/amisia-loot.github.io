-- Amisia item collector: every item the player meets is stored like a scanned item, with where it
-- was seen: bags and equipment, merchants, quest rewards, auction house pages, loot windows,
-- tooltips and chat links. Items the client has not cached yet are requested and stored on arrival.
local ADDON, ns = ...

local MAX_SOURCES = 6
local wanted = {}   -- itemID -> source text, waiting for the client's item data

local function enabled()
    return AmisiaDB and AmisiaDB.settings and AmisiaDB.settings.collect and ns.StoreItem
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

-- Records an item by id or link. Returns true when it is stored now, false when requested.
function ns.NoteItem(idOrLink, source)
    if not enabled() then return nil end
    local id = tonumber(idOrLink) or ns.ItemID(idOrLink)
    if not id then return nil end
    addSource(id, source)
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

---------------------------------------------------------------------------
-- Bags and equipment
---------------------------------------------------------------------------
local containerLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
local containerSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots

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
ns.OnEvent("BANKFRAME_OPENED", function() scanBags(-1, -1); scanBags(5, 11) end)

---------------------------------------------------------------------------
-- Merchants
---------------------------------------------------------------------------
ns.OnEvent("MERCHANT_SHOW", function()
    if not enabled() or not GetMerchantNumItems or not GetMerchantItemLink then return end
    local who = UnitName("npc") or UnitName("target") or "?"
    for i = 1, GetMerchantNumItems() or 0 do
        local link = GetMerchantItemLink(i)
        if link then ns.NoteItem(link, "Haendler: " .. who) end
    end
end)

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
local function questRewards()
    if not enabled() or not GetQuestItemLink then return end
    local title = (GetTitleText and GetTitleText()) or "?"
    for _, kind in ipairs({ "reward", "choice" }) do
        local n = kind == "reward" and (GetNumQuestRewards and GetNumQuestRewards() or 0) or (GetNumQuestChoices and GetNumQuestChoices() or 0)
        for i = 1, n do
            local link = GetQuestItemLink(kind, i)
            if link then ns.NoteItem(link, "Quest: " .. title) end
        end
    end
end
ns.OnEvent("QUEST_DETAIL", questRewards)
ns.OnEvent("QUEST_COMPLETE", questRewards)

---------------------------------------------------------------------------
-- Auction house: the classic list and the retail browse results
---------------------------------------------------------------------------
ns.OnEvent("AUCTION_ITEM_LIST_UPDATE", function()
    if not enabled() or not GetNumAuctionItems or not GetAuctionItemLink then return end
    local n = GetNumAuctionItems("list") or 0
    for i = 1, n do
        local link = GetAuctionItemLink("list", i)
        if link then ns.NoteItem(link, "Auktionshaus") end
    end
end)

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
    if not enabled() or not GetNumLootItems or not GetLootSlotLink then return end
    local who = UnitName("target")
    for slot = 1, GetNumLootItems() or 0 do
        local link = GetLootSlotLink(slot)
        local src = GetLootSourceInfo and GetLootSourceInfo(slot)
        if link and not (type(src) == "string" and src:find("^Item%-")) then
            ns.NoteItem(link, who and ("Drop: " .. who) or nil)
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
local function tooltipItem(tip)
    if not enabled() or not tip then return end
    local link
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, l = TooltipUtil.GetDisplayedItem(tip)
        link = l
    elseif tip.GetItem then
        local _, l = tip:GetItem()
        link = l
    end
    if link then ns.NoteItem(link) end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, tooltipItem)
else
    GameTooltip:HookScript("OnTooltipSetItem", tooltipItem)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", tooltipItem) end
end

local function chatLinks(text)
    if not enabled() or type(text) ~= "string" then return end
    for id in text:gmatch("|Hitem:(%d+)") do ns.NoteItem(tonumber(id)) end
end
for _, ev in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                      "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM" }) do
    ns.OnEvent(ev, chatLinks)
end
