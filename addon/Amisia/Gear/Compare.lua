-- Amisia comparison marks: where the client offers an item, a short text on its icon says what it
-- brings against the worn gear ("+12%", "neu", "ab 58", "-8%"), from ns.UpgradeOf (Bis.lua), the one
-- scoring every display uses. Group loot roll frames (GroupLootFrame1-4, rollID, IconFrame) and
-- quest rewards (QuestInfo_Display fills QuestInfoFrame.rewardsFrame.RewardButtons: quest giver,
-- quest log, map details). Only hooks (HookScript, hooksecurefunc), nothing of the client's code is
-- replaced; an error goes to the error handler. Switch: bis.compare.
local ADDON, ns = ...

local RETRY_WAIT = 0.5          -- seconds between two tries while the item's stats load
local RETRIES = 5
local GREEN = { 0.3, 0.9, 0.45 }
local ORANGE = { 1, 0.6, 0.2 }
local GREY = { 0.6, 0.58, 0.66 }

local marks = setmetatable({}, { __mode = "k" })     -- owner (roll frame, reward button) -> font string
local hooked = setmetatable({}, { __mode = "k" })

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function on()
    return ns.Gear and ns.Gear.Available() and ns.Get("bis.compare") ~= false -- l10n-ok: setting key
end

local function hide(owner)
    local m = marks[owner]
    if m then m:Hide() end
end

-- Puts the text on the icon (bottom, centred), coloured by what it says. parent is the frame that
-- holds the font string, icon the region it sits on.
local function show(owner, parent, icon, u, text)
    local m = marks[owner]
    if not m then
        m = parent:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        m:SetPoint("BOTTOM", icon, "BOTTOM", 0, 2)
        marks[owner] = m
    end
    local c = u.later and ORANGE or (u.up and GREEN or GREY)
    m:SetTextColor(c[1], c[2], c[3])
    m:SetText(text)
    m:Show()
end

-- Marks owner for link. getLink is asked again on a retry (the frame may show another item by
-- then); tries counts the retries while stats load.
local function mark(owner, parent, icon, getLink, tries)
    if not on() then return hide(owner) end
    local link = ns.Plain(getLink())
    if type(link) ~= "string" or not ns.ItemID(link) then return hide(owner) end
    local u, _, code = ns.UpgradeOf(link)
    local text = u and ns.UpgradeShort(u)
    if text then return show(owner, parent, icon, u, text) end
    hide(owner)
    if code == "loading" and (tries or 0) < RETRIES then
        local want = link
        C_Timer.After(RETRY_WAIT, function()
            -- only while the owner still shows the same item
            local ok, err = pcall(function()
                if owner.IsShown and not owner:IsShown() then return end
                if ns.Plain(getLink()) ~= want then return end
                mark(owner, parent, icon, getLink, (tries or 0) + 1)
            end)
            if not ok then report(err) end
        end)
    end
end

local function guarded(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then report(err) end
end

---------------------------------------------------------------------------
-- Group loot roll frames
---------------------------------------------------------------------------

local function rollLink(frame)
    local fn = _G.GetLootRollItemLink
    if type(fn) ~= "function" then return nil end
    local ok, link = pcall(fn, ns.Plain(frame.rollID))
    return ok and link or nil
end

local function onRollFrameShow(frame)
    guarded(function()
        local parent = type(frame.IconFrame) == "table" and frame.IconFrame or frame
        mark(frame, parent, parent, function() return rollLink(frame) end)
    end)
end

local function hookRollFrames()
    for i = 1, tonumber(_G.NUM_GROUP_LOOT_FRAMES) or 4 do
        local f = _G["GroupLootFrame" .. i]
        if type(f) == "table" and type(f.HookScript) == "function" and not hooked[f] then
            hooked[f] = true
            f:HookScript("OnShow", onRollFrameShow)
        end
    end
end
hookRollFrames()
ns.OnEvent("PLAYER_ENTERING_WORLD", hookRollFrames)

---------------------------------------------------------------------------
-- Quest rewards
---------------------------------------------------------------------------

local function rewardLink(button)
    local info = _G.QuestInfoFrame
    local fn = (type(info) == "table" and info.questLog) and _G.GetQuestLogItemLink or _G.GetQuestItemLink
    if type(fn) ~= "function" or type(button.GetID) ~= "function" then return nil end
    local ok, link = pcall(fn, button.type, button:GetID())
    return ok and link or nil
end

local function markRewards()
    local info = _G.QuestInfoFrame
    local frame = type(info) == "table" and info.rewardsFrame
    local buttons = type(frame) == "table" and frame.RewardButtons
    if type(buttons) ~= "table" then return end
    for _, b in ipairs(buttons) do
        if type(b) == "table" then
            local item = b.objectType == "item" and (b.type == "choice" or b.type == "reward")
            if item and b:IsShown() then
                local icon = type(b.Icon) == "table" and b.Icon or b
                mark(b, b, icon, function() return rewardLink(b) end)
            else
                hide(b)
            end
        end
    end
end

if type(_G.QuestInfo_Display) == "function" and type(hooksecurefunc) == "function" then
    hooksecurefunc("QuestInfo_Display", function() guarded(markRewards) end)
end

---------------------------------------------------------------------------
-- Again after a change of the gear or the setting; for tests
---------------------------------------------------------------------------

local function refresh()
    guarded(function()
        for i = 1, tonumber(_G.NUM_GROUP_LOOT_FRAMES) or 4 do
            local f = _G["GroupLootFrame" .. i]
            if type(f) == "table" and marks[f] and f.IsShown and f:IsShown() then onRollFrameShow(f) end
        end
        local info = _G.QuestInfoFrame
        if type(info) == "table" and info.IsShown and info:IsShown() then markRewards() end
    end)
end
ns.Listen("SETTING", function(path) if path == "bis.compare" then refresh() end end) -- l10n-ok: setting key
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(0, refresh) end)

-- The mark's text on a roll frame or reward button while it shows, else nil.
function ns.UpgradeMarkText(owner)
    local m = marks[owner]
    return (m and m:IsShown()) and m:GetText() or nil
end
