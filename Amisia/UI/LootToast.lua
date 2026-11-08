-- The loot toast (F-152, D-79): what the character gets (the own loot line of the chat: looted, or
-- pushed into the bags by a quest reward, a vendor, a trade window's close) shows for a moment as
-- "+[icon] Name x3" in the item's quality colour near the middle of the screen, rises a little and
-- fades out. Several stack under each other (at most T.LOOTTOAST.MAX at once). Switched in the
-- settings (Oberfläche: ui.lootToast, ui.lootToastQuality the lowest quality shown). A secret chat
-- line (Forever's encounter lockdown) shows nothing. Nothing is sent, nothing is saved.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local LT = T.LOOTTOAST

local holder
local lines = {}   -- the lines shown now, the newest last

local function now() return GetTime and GetTime() or 0 end

local function build()
    holder = CreateFrame("Frame", "AmisiaLootToast", UIParent)
    holder:SetSize(LT.W, LT.H)
    holder:SetPoint("CENTER", UIParent, "CENTER", LT.X, LT.Y)
    holder:SetFrameStrata("HIGH")
    holder:EnableMouse(false)
    holder.pool = {}
end

-- A free line (a frame with the icon and the text), reused.
local function takeLine()
    for _, l in ipairs(holder.pool) do
        if not l.busy then return l end
    end
    local l = CreateFrame("Frame", nil, holder)
    l:SetSize(LT.W, LT.LINE_H)
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(LT.ICON, LT.ICON)
    l.icon:SetPoint("LEFT", 0, 0)
    l.text = W.Text(l, LT.FONT)
    l.text:SetPoint("LEFT", l.icon, "RIGHT", LT.GAP, 0)
    if l.text.SetShadowOffset then l.text:SetShadowOffset(1, -1) end
    holder.pool[#holder.pool + 1] = l
    return l
end

-- Places the shown lines: the oldest at the top, each one LINE_H + SPACE under the one before, all
-- risen by how far their time has gone (RISE px over SHOW seconds); alpha in over FADE_IN, out over
-- FADE_OUT at the end.
local function step()
    local t = now()
    local keep = {}
    for _, l in ipairs(lines) do
        local age = t - l.born
        if age >= LT.SHOW then
            l.busy = false
            l:Hide()
        else
            keep[#keep + 1] = l
        end
    end
    lines = keep
    for i, l in ipairs(lines) do
        local age = t - l.born
        local a = 1
        if age < LT.FADE_IN then a = age / LT.FADE_IN end
        if age > LT.SHOW - LT.FADE_OUT then a = math.max(0, (LT.SHOW - age) / LT.FADE_OUT) end
        l:SetAlpha(a)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * (LT.LINE_H + LT.SPACE) + math.floor(LT.RISE * age / LT.SHOW))
    end
    if #lines == 0 then holder:SetScript("OnUpdate", nil) end
end

-- The item's name in its quality's colour from the link ("|cff1eff00|Hitem:...|h[Name]|h|r"), its
-- quality (nil when unknown) and its icon.
local function itemParts(link, id)
    local name = type(link) == "string" and link:match("%[(.-)%]") or nil
    local color = type(link) == "string" and link:match("^|c(%x%x%x%x%x%x%x%x)") or nil
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id) or nil
    -- Forever has the item functions in C_Item only (so do the classic clients of today)
    if not quality and C_Item and C_Item.GetItemInfo then quality = select(3, C_Item.GetItemInfo(id)) end
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return name or ("item:" .. id), color, quality, icon
end

-- Shows "+Name xN" for item id (link: the chat's link, for its name and colour).
function ns.LootToast(id, count, link)
    if not ns.Get("ui.lootToast") or not id then return false end
    local name, color, quality, icon = itemParts(link, id)
    local min = tonumber(ns.Get("ui.lootToastQuality")) or 0
    if quality and quality < min then return false end
    if not holder then build() end
    -- at most MAX at once: the oldest goes
    while #lines >= LT.MAX do
        local old = table.remove(lines, 1)
        old.busy = false
        old:Hide()
    end
    local l = takeLine()
    l.busy, l.born, l.id = true, now(), id
    l.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local text = "+" .. name .. ((count or 1) > 1 and (" x" .. count) or "")
    l.text:SetText(color and ("|c" .. color .. text .. "|r") or text)
    l:Show()
    lines[#lines + 1] = l
    holder:Show()
    step()
    holder:SetScript("OnUpdate", step)
    return true
end

-- The lines shown now (tests): { { id, text } }
function ns.LootToastLines()
    local out = {}
    for _, l in ipairs(lines) do out[#out + 1] = { id = l.id, text = l.text:GetText(), frame = l } end
    return out
end

-- The own loot line of the chat: looted or pushed (a quest's reward). A secret line is skipped.
ns.OnEvent("CHAT_MSG_LOOT", function(text)
    text = ns.Plain(text)
    if type(text) ~= "string" or not ns.Get("ui.lootToast") then return end
    local who, id, count, link = ns.ParseLootLink(text)
    if not who or not ns.SameName(who, ns.UnitFullName("player")) then return end
    ns.LootToast(id, count, link)
end)

local function preview()
    ns.LootToast(2589, 3, "|cffffffff|Hitem:2589::::::::1:::::::|h[" .. L["Leinenstoff"] .. "]|h|r")
end
ns.LootToastPreview = preview
