-- luacheck configuration of the Amisia addon (WoW Forever, Lua 5.1).
-- Run: luacheck addon/Amisia   (python tools/build.py check runs it too)
std = "lua51"
max_line_length = false          -- long lines are the house style; not reflowed
codes = true
-- only the addon is linted; the tests run against a stub with globals of their own
exclude_files = { "addon/tests/**", "tools/**", ".claude/**" }
ignore = {
    "211/ADDON",   -- "local ADDON, ns = ..." heads every file; most never need the name
    "212",         -- unused arguments: client callbacks and handlers keep their full signature
    "542",         -- an empty if branch holding only a comment says "nothing to do here" on purpose
}

-- What the addon writes into the global table: the saved variables, the slash command, the map pin
-- mixin the XML template names, the addon compartment callbacks of the TOC, and the client's
-- registries it adds entries to.
globals = {
    "AmisiaDB", "SLASH_AMISIA1", "SlashCmdList", "StaticPopupDialogs", "AmisiaMapPinMixin",
    "Amisia_OnAddonCompartmentClick", "Amisia_OnAddonCompartmentEnter", "Amisia_OnAddonCompartmentLeave",
}

-- The client's API and FrameXML globals the addon reads (from a scan of every addon file; add a new
-- one here when the addon starts to use it).
read_globals = {
    "BaseScrollBoxEvents", "bit", "C_AddOns", "C_AuctionHouse", "C_Calendar", "ToggleCalendar", "C_ChatInfo", "C_ClassColor", "C_Club",
    "C_Container", "C_CurrencyInfo", "C_DateAndTime", "C_EncodingUtil", "C_GuildInfo", "C_Item", "C_Map", "C_MerchantFrame",
    "C_PartyInfo", "C_QuestLog", "C_RestrictedActions", "C_Spell", "C_SuperTrack", "C_Texture", "C_Timer",
    "C_TooltipInfo", "C_TradeSkillUI", "ChatEdit_InsertLink", "ChatFontNormal", "ChatFrameUtil",
    "CreateColor", "CreateFrame", "CreateFromMixins", "CreateVector2D", "date", "debugprofilestop",
    "DEFAULT_CHAT_FRAME", "DressUpLink", "Enum", "GameFontNormal", "GameTooltip", "GetAddOnMetadata",
    "GetBuildInfo", "GetClassInfo", "GetCombatRatingBonus", "GetCurrentGuildBankTab", "GetCursorPosition",
    "geterrorhandler", "GetGuildBankItemInfo", "GetGuildBankItemLink", "GetGuildBankTabInfo", "GetGuildInfo",
    "GetGuildRosterInfo", "GetHitModifier", "GetInstanceInfo", "GetLocale", "AMISIA_LOCALE", "GetInventoryItemLink", "GetLootSlotInfo",
    "GetLootSlotLink", "GetLootSourceInfo", "GetMasterLootCandidate", "GetMaxPlayerLevel", "GetMerchantItemInfo",
    "GetMerchantItemLink", "GetMerchantNumItems", "GetNormalizedRealmName", "GetNumGroupMembers",
    "GetNumGuildBankTabs", "GetNumGuildMembers", "GetNumLootItems", "GetNumQuestChoices",
    "GetNumQuestRewards", "GetPlayerFacing", "GetProfessionInfo", "GetProfessions", "GetQuestID",
    "GetQuestItemLink", "GetQuestLogIndexByID", "GetQuestLogTitle", "GetRaidRosterInfo", "GetRealZoneText",
    "GetServerTime", "GetSpellDescription", "GetSpellHitModifier", "GetSpellInfo", "GetTime", "GetTitleText",
    "GetZoneText", "GiveMasterLoot", "GuildControlGetNumRanks", "GuildControlGetRankName",
    "HandleModifiedItemClick", "hooksecurefunc", "InCombatLockdown", "UpdateAddOnMemoryUsage", "GetAddOnMemoryUsage", "IsAltKeyDown", "IsControlKeyDown",
    "IsInGroup", "IsInGuild", "IsInInstance", "IsInRaid", "IsModifiedClick", "IsShiftKeyDown",
    "ITEM_CLASSES_ALLOWED", "LE_PARTY_CATEGORY_HOME", "LootFrame", "MapCanvasDataProviderMixin",
    "MapCanvasPinMixin", "Minimap", "NORMAL_FONT_COLOR", "OpenWorldMap", "PlaySound", "QueryGuildBankTab",
    "QueryGuildBankLog", "GetNumGuildBankTransactions", "GetGuildBankTransaction", "GetNumGuildBankMoneyTransactions",
    "GetGuildBankMoneyTransaction", "MAX_GUILDBANK_TABS",
    "RAID_CLASS_COLORS", "RandomRoll", "RANDOM_ROLL_RESULT", "ITEM_QUALITY_COLORS", "ScrollUtil", "SEARCH", "SOUNDKIT", "StaticPopup_Show",
    "time", "tinsert", "ToggleWorldMap", "TooltipDataProcessor", "TooltipUtil", "UiMapPoint", "UIParent",
    "UISpecialFrames", "UnitClass", "UnitClassification", "UnitExists", "UnitFactionGroup", "UnitFullName",
    "UnitGUID", "UnitIsDead", "UnitIsGroupAssistant", "UnitIsGroupLeader", "UnitIsUnit", "UnitLevel",
    "UnitName", "UnitPosition", "UnitRace", "wipe",
    -- the trade helper (Handover.lua)
    "ClickTradeButton", "ClearCursor", "CursorHasItem", "GetGameMessageInfo", "GetTradePlayerItemLink",
}
