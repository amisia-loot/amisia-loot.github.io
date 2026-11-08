-- The loot toast (F-152, D-79): what the character gets shows for a moment near the middle of the
-- screen, rises a little and fades out:
-- - an item (the own loot line of the chat: looted, or pushed into the bags by a quest reward, a
--   vendor, a trade window's close) as "+[icon] Name x3" in the colour of its quality (the quality's
--   colour of the client; Forever's links carry the named form |cnIQ2:, which is read too);
-- - money (PLAYER_MONEY: the purse grew, by loot, a quest, a sale, the mail) as "+1g 20s 5c" with the
--   coins' icons, the gold in gold, the silver in silver, the copper in copper.
-- Several stack under each other (at most T.LOOTTOAST.MAX at once). Switched in the settings
-- (Oberfläche: ui.lootToast, ui.lootToastMoney, ui.lootToastQuality the lowest quality shown,
-- ui.lootToastSize the font size). A secret chat line (Forever's encounter lockdown) shows nothing.
-- Nothing is sent, nothing is saved.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local LT = T.LOOTTOAST

local holder
local lines = {}   -- the lines shown now, the newest last

local function now() return GetTime and GetTime() or 0 end

-- The font size of the setting (LT.SIZE_MIN to SIZE_MAX), the icon and the line follow it.
local function size()
    local s = tonumber(ns.Get("ui.lootToastSize")) or LT.SIZE
    return math.max(LT.SIZE_MIN, math.min(LT.SIZE_MAX, math.floor(s + 0.5)))
end
local function lineH(s) return s + LT.LINE_PAD end
local function iconSize(s) return s + LT.ICON_PAD end

local function build()
    holder = CreateFrame("Frame", "AmisiaLootToast", UIParent)
    holder:SetSize(LT.W, LT.H)
    holder:SetPoint("CENTER", UIParent, "CENTER", LT.X, LT.Y)
    holder:SetFrameStrata("HIGH")
    holder:EnableMouse(false)
    holder.pool = {}
end

-- Sets line l's text and icon to the size s (the font of FONT at s points, its own outline).
local function sizeLine(l, s)
    l.size = s
    l:SetSize(LT.W, lineH(s))
    l.icon:SetSize(iconSize(s), iconSize(s))
    if l.text.GetFont and l.text.SetFont then
        local file, _, flags = l.text:GetFont()
        if file then l.text:SetFont(file, s, flags or "") end
    end
end

-- A free line (a frame with the icon and the text), reused.
local function takeLine()
    for _, l in ipairs(holder.pool) do
        if not l.busy then return l end
    end
    local l = CreateFrame("Frame", nil, holder)
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetPoint("LEFT", 0, 0)
    l.text = W.Text(l, LT.FONT)
    l.text:SetPoint("LEFT", l.icon, "RIGHT", LT.GAP, 0)
    if l.text.SetShadowOffset then l.text:SetShadowOffset(1, -1) end
    holder.pool[#holder.pool + 1] = l
    return l
end

-- Places the shown lines: the oldest at the top, each one its height + SPACE under the one before,
-- all risen by how far their time has gone (RISE px over SHOW seconds); alpha in over FADE_IN, out
-- over FADE_OUT at the end.
local function step()
    local t = now()
    local keep = {}
    for _, l in ipairs(lines) do
        if t - l.born >= LT.SHOW then
            l.busy = false
            l:Hide()
        else
            keep[#keep + 1] = l
        end
    end
    lines = keep
    local y = 0
    for _, l in ipairs(lines) do
        local age = t - l.born
        local a = 1
        if age < LT.FADE_IN then a = age / LT.FADE_IN end
        if age > LT.SHOW - LT.FADE_OUT then a = math.max(0, (LT.SHOW - age) / LT.FADE_OUT) end
        l:SetAlpha(a)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, y + math.floor(LT.RISE * age / LT.SHOW))
        y = y - (lineH(l.size or LT.SIZE) + LT.SPACE)
    end
    if #lines == 0 then holder:SetScript("OnUpdate", nil) end
end

-- Shows a line: icon (a texture), text (already coloured), id (an item, for the tests).
local function show(icon, text, id)
    if not holder then build() end
    -- at most MAX at once: the oldest goes
    while #lines >= LT.MAX do
        local old = table.remove(lines, 1)
        old.busy = false
        old:Hide()
    end
    local l = takeLine()
    l.busy, l.born, l.id = true, now(), id
    sizeLine(l, size())
    l.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    l.text:SetText(text)
    l:Show()
    lines[#lines + 1] = l
    holder:Show()
    step()
    holder:SetScript("OnUpdate", step)
    return true
end

-- The item's name from the link ("|c...|Hitem:...|h[Name]|h|r"), its colour code (the quality's of
-- the client, else the link's own, both forms), its quality (nil when unknown) and its icon.
local function itemParts(link, id)
    local name = type(link) == "string" and link:match("%[(.-)%]") or nil
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id) or nil
    -- Forever has the item functions in C_Item only (so do the classic clients of today)
    if not quality and C_Item and C_Item.GetItemInfo then quality = select(3, C_Item.GetItemInfo(id)) end
    local color
    local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qc and type(qc.hex) == "string" and qc.hex ~= "" then
        color = qc.hex
    elseif qc and qc.r then
        color = ("|cff%02x%02x%02x"):format(math.floor(qc.r * 255 + 0.5), math.floor(qc.g * 255 + 0.5), math.floor(qc.b * 255 + 0.5))
    elseif type(link) == "string" then
        color = link:match("^(|c%x%x%x%x%x%x%x%x)") or link:match("^(|cn[%w_]+:)")
    end
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return name or ("item:" .. id), color, quality, icon
end

-- Shows "+Name xN" for item id (link: the chat's link, for its name and colour).
function ns.LootToast(id, count, link)
    if not ns.Get("ui.lootToast") or not id then return false end
    local name, color, quality, icon = itemParts(link, id)
    local min = tonumber(ns.Get("ui.lootToastQuality")) or 0
    if quality and quality < min then return false end
    local text = "+" .. name .. ((count or 1) > 1 and (" x" .. count) or "")
    return show(icon, color and (color .. text .. "|r") or text, id)
end

-- "+1g 20s 5c" with the coins' icons, each in its metal's colour (only the parts there are).
local COINS = {
    { 10000, "|cffffd700", "Interface\\MoneyFrame\\UI-GoldIcon" },
    { 100, "|cffc7c7cf", "Interface\\MoneyFrame\\UI-SilverIcon" },
    { 1, "|cffeda55f", "Interface\\MoneyFrame\\UI-CopperIcon" },
}
function ns.LootToastMoneyText(copper)
    local parts, s = {}, size()
    for _, c in ipairs(COINS) do
        local n = math.floor(copper / c[1])
        copper = copper - n * c[1]
        if n > 0 then parts[#parts + 1] = ("%s%d|r|T%s:%d:%d:2:0|t"):format(c[2], n, c[3], s, s) end
    end
    return "+" .. table.concat(parts, " ")
end

-- Shows the money the purse gained (copper).
function ns.LootToastMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper <= 0 or not ns.Get("ui.lootToast") or not ns.Get("ui.lootToastMoney") then return false end
    local icon = copper >= 10000 and COINS[1][3] or copper >= 100 and COINS[2][3] or COINS[3][3]
    return show(icon, ns.LootToastMoneyText(copper))
end

-- The lines shown now (tests): { { id, text, frame } }
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

-- The purse: what it gained since the last look (the first look after the login only remembers).
local purse
local function money() return GetMoney and tonumber(GetMoney()) or nil end
ns.OnEvent("PLAYER_ENTERING_WORLD", function() purse = money() end)
ns.OnEvent("PLAYER_MONEY", function()
    local m = money()
    if not m then return end
    if purse and m > purse then ns.LootToastMoney(m - purse) end
    purse = m
end)

-- The size setting: the lines shown now take it at once.
function ns.ApplyLootToastSize()
    for _, l in ipairs(lines) do sizeLine(l, size()) end
    if holder and #lines > 0 then step() end
end

local function preview()
    ns.LootToast(2589, 3, "|cffffffff|Hitem:2589::::::::1:::::::|h[" .. L["Leinenstoff"] .. "]|h|r")
    if ns.Get("ui.lootToastMoney") then show(COINS[1][3], ns.LootToastMoneyText(12345)) end
end
ns.LootToastPreview = preview
