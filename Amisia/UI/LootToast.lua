-- The loot toast (F-152, D-79): what the character gets shows for a moment near the middle of the
-- screen, rises a little and fades out:
-- - an item the character loots (a mob, a chest: "You receive loot") or gets from a quest ("You receive
--   item" while no vendor, trade, mail, bank or auction window is open: those are purchases and
--   handovers, not rewards) as "+[icon] Name x3" in the colour of its quality (the quality's colour of
--   the client; Forever's links carry the named form |cnIQ2:, which is read too);
-- - money the character loots (CHAT_MSG_MONEY: "You loot 2 Silver, 51 Copper", also a group's share)
--   or gets for a quest (QUEST_TURNED_IN's reward) as "+1g 20s 5c" with the coins' icons, the gold in
--   gold, the silver in silver, the copper in copper. Sales, the mail and trades show nothing.
-- Several stack under each other. The section "Item-Anzeige" (toast.*, F-158, D-89) switches it and
-- sets the lowest quality, the font, its size, outline and shadow, the icon, the alignment, how long a
-- line stays and how it moves, where new lines come, how many at once and the opacity; "Verschieben"
-- unlocks the holder to drag it (its place in settings.toast.point). A secret chat line (Forever's
-- encounter lockdown) shows nothing. Nothing is sent.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local LT = T.LOOTTOAST

local holder
local lines = {}   -- the lines shown now, the newest last

local function now() return GetTime and GetTime() or 0 end

-- The font size of the setting (LT.SIZE_MIN to SIZE_MAX), the icon and the line follow it.
local function size()
    local s = tonumber(ns.Get("toast.size")) or LT.SIZE
    return math.max(LT.SIZE_MIN, math.min(LT.SIZE_MAX, math.floor(s + 0.5)))
end
local function lineH(s) return s + LT.LINE_PAD end
local function iconSize(s) return s + LT.ICON_PAD end
local function num(key, lo, hi, def)
    local v = tonumber(ns.Get(key)) or def
    return math.max(lo, math.min(hi, v))
end
local function showTime() return num("toast.duration", LT.SHOW_MIN, LT.SHOW_MAX, LT.SHOW) end
local function maxLines() return math.floor(num("toast.lines", LT.MAX_MIN, LT.MAX_MAX, LT.MAX)) end

-- The saved place of the holder: { point, x, y } (from UIParent's same point), or nil.
local function placeState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.toast) ~= "table" then AmisiaDB.settings.toast = {} end
    return AmisiaDB.settings.toast
end
local function place()
    holder:ClearAllPoints()
    local st = placeState()
    local p = st and st.point
    if type(p) == "table" and type(p[1]) == "string" and tonumber(p[2]) and tonumber(p[3]) then
        holder:SetPoint(p[1], UIParent, p[1], tonumber(p[2]), tonumber(p[3]))
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", LT.X, LT.Y)
    end
end

local unlocked = false
local step
local function build()
    holder = CreateFrame("Frame", "AmisiaLootToast", UIParent)
    holder:SetSize(LT.W, LT.H)
    holder:SetFrameStrata("HIGH")
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    holder:SetMovable(true)
    holder.pool = {}
    place()
    -- the move mode (F-158): a dark ground with a gold edge, the hint and "Fertig"
    local box = CreateFrame("Frame", nil, holder)
    box:SetAllPoints()
    box:SetFrameLevel(math.max(0, (holder:GetFrameLevel() or 1) - 1))
    holder.box = box
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    box.bg:SetColorTexture(LT.MOVE_BG[1], LT.MOVE_BG[2], LT.MOVE_BG[3], LT.MOVE_BG[4])
    W.Border(box, LT.MOVE_EDGE[1], LT.MOVE_EDGE[2], LT.MOVE_EDGE[3], LT.MOVE_EDGE[4])
    box.hint = W.Text(box, T.FONT.title, LT.W - 16, true)
    box.hint:SetPoint("BOTTOM", 0, 36)
    box.hint:SetJustifyH("CENTER")
    box.hint:SetText(L["Item-Anzeige: ziehen zum Verschieben, dann \"Fertig\"."])
    box.done = W.Button(box, L["Fertig"], LT.DONE_W, function() ns.LootToastUnlock(false) end)
    box.done:SetPoint("BOTTOM", 0, 8)
    holder:RegisterForDrag("LeftButton")
    holder:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
    holder:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint(1)
        local st = placeState()
        if st and p then st.point = { p, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) } end
    end)
    box:Hide()
end

-- The font file of the setting toast.font ("default": the font object's own), its outline flags
-- (toast.outline: "default" the font object's, "none", "OUTLINE", "THICKOUTLINE").
local function fontOf(l)
    local base, _, baseFlags
    local obj = _G[LT.FONT]
    if obj and obj.GetFont then base, _, baseFlags = obj:GetFont() end
    if not base and l.text.GetFont then base, _, baseFlags = l.text:GetFont() end
    local file = LT.FONTS[ns.Get("toast.font") or ""] or base
    local o = ns.Get("toast.outline") or "default"
    local flags = o == "default" and (baseFlags or "") or o == "none" and "" or o
    return file, flags
end

-- Sets line l's text and icon to the size s, the font, outline and shadow of the settings.
local function sizeLine(l, s)
    l.size = s
    l:SetSize(LT.W, lineH(s))
    local icon = ns.Get("toast.icon") ~= false
    l.icon:SetSize(icon and iconSize(s) or 1, iconSize(s))
    l.icon:SetShown(icon)
    l.text:ClearAllPoints()
    if icon then l.text:SetPoint("LEFT", l.icon, "RIGHT", LT.GAP, 0) else l.text:SetPoint("LEFT", l, "LEFT", 0, 0) end
    if l.text.SetFont then
        local file, flags = fontOf(l)
        if file then l.text:SetFont(file, s, flags) end
    end
    if l.text.SetShadowOffset then
        if ns.Get("toast.shadow") == false then l.text:SetShadowOffset(0, 0) else l.text:SetShadowOffset(1, -1) end
    end
end

-- The x of line l in the holder: its icon and text left, in the middle or right (toast.align).
local function lineX(l)
    local a = ns.Get("toast.align") or "left"
    if a == "left" then return 0 end
    local w = (l.icon:IsShown() and (iconSize(l.size or LT.SIZE) + LT.GAP) or 0)
        + (l.text.GetStringWidth and l.text:GetStringWidth() or 0)
    local free = math.max(0, LT.W - w)
    return math.floor(a == "center" and free / 2 or free)
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
    holder.pool[#holder.pool + 1] = l
    return l
end

-- Places the shown lines: by toast.order the oldest at the top and each new one its height + SPACE
-- under the one before ("down"), or the newest at the top ("up"); all moved by how far their time
-- has gone (toast.motion: up or down RISE px over the time shown, or still); alpha in over FADE_IN,
-- out over FADE_OUT at the end, times the opacity (toast.alpha). While moved, nothing goes.
function step()
    local t = now()
    local show = showTime()
    local keep = {}
    for _, l in ipairs(lines) do
        if not unlocked and t - l.born >= show then
            l.busy = false
            l:Hide()
        else
            keep[#keep + 1] = l
        end
    end
    lines = keep
    local motion = ns.Get("toast.motion") or "up"
    local dir = motion == "up" and 1 or motion == "down" and -1 or 0
    local opacity = num("toast.alpha", LT.ALPHA_MIN, 100, 100) / 100
    local order = {}
    if ns.Get("toast.order") == "up" then
        for i = #lines, 1, -1 do order[#order + 1] = lines[i] end
    else
        order = lines
    end
    local y = 0
    for _, l in ipairs(order) do
        local age = unlocked and 0 or t - l.born
        local a = 1
        if not unlocked then
            if age < LT.FADE_IN then a = age / LT.FADE_IN end
            if age > show - LT.FADE_OUT then a = math.max(0, (show - age) / LT.FADE_OUT) end
        end
        l:SetAlpha(a * opacity)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", holder, "TOPLEFT", lineX(l), y + dir * math.floor(LT.RISE * age / show))
        y = y - (lineH(l.size or LT.SIZE) + LT.SPACE)
    end
    if #lines == 0 and not unlocked then holder:SetScript("OnUpdate", nil) end
end
step = ns.Perf.Wrap("OnUpdate LootToast", step)   -- /amisia leistung (F-184)

-- Shows a line: icon (a texture), text (already coloured), id (an item, for the tests).
local function show(icon, text, id)
    if not holder then build() end
    -- at most toast.lines at once: the oldest goes
    while #lines >= maxLines() do
        local old = table.remove(lines, 1)
        old.busy = false
        old:Hide()
    end
    local l = takeLine()
    l.busy, l.born, l.id = true, now(), id
    l.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    l.text:SetText(text)
    sizeLine(l, size())
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
    if not ns.Get("toast.show") or not id then return false end
    local name, color, quality, icon = itemParts(link, id)
    local min = tonumber(ns.Get("toast.quality")) or 0
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
    if copper <= 0 or not ns.Get("toast.show") or not ns.Get("toast.money") then return false end
    local icon = copper >= 10000 and COINS[1][3] or copper >= 100 and COINS[2][3] or COINS[3][3]
    return show(icon, ns.LootToastMoneyText(copper))
end

-- The lines shown now (tests): { { id, text, frame } }
function ns.LootToastLines()
    local out = {}
    for _, l in ipairs(lines) do out[#out + 1] = { id = l.id, text = l.text:GetText(), frame = l } end
    return out
end

-- The windows in which a pushed item is no reward (a purchase, a trade, the mail, the bank, the auction
-- house): open while their show event came and their close event not yet.
local busy = {}
for show_, close in pairs({ MERCHANT_SHOW = "MERCHANT_CLOSED", TRADE_SHOW = "TRADE_CLOSED", MAIL_SHOW = "MAIL_CLOSED",
                           BANKFRAME_OPENED = "BANKFRAME_CLOSED", AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED",
                           GUILDBANKFRAME_OPENED = "GUILDBANKFRAME_CLOSED" }) do
    local opened = show_
    ns.OnEvent(opened, function() busy[opened] = true end)
    ns.OnEvent(close, function() busy[opened] = nil end)
end
local function windowOpen() return next(busy) ~= nil end

-- "You receive loot: ..." (looted) against "You receive item: ..." (pushed).
local looted
local function isLooted(text)
    if not looted then
        looted = {}
        for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }) do
            local m = ns.BuildMatcher(_G[key])
            if m then looted[#looted + 1] = m end
        end
    end
    for _, m in ipairs(looted) do if m(text) then return true end end
    return false
end

-- The own loot line of the chat: looted, or pushed outside the windows above (a quest's reward). A
-- secret line is skipped.
ns.OnEvent("CHAT_MSG_LOOT", function(text)
    text = ns.Plain(text)
    if type(text) ~= "string" or not ns.Get("toast.show") then return end
    local who, id, count, link = ns.ParseLootLink(text)
    if not who or not ns.SameName(who, ns.UnitFullName("player")) then return end
    if not isLooted(text) and windowOpen() then return end
    ns.LootToast(id, count, link)
end)

-- The copper of a money line ("2 Silber, 51 Kupfer"; the client's GOLD_AMOUNT, SILVER_AMOUNT and
-- COPPER_AMOUNT words), or nil.
local function copperOf(text)
    local total, found = 0, false
    for _, part in ipairs({ { "GOLD_AMOUNT", 10000 }, { "SILVER_AMOUNT", 100 }, { "COPPER_AMOUNT", 1 } }) do
        local fmt = _G[part[1]]
        if type(fmt) == "string" then
            local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "(%%d+)")
            local n = tonumber(text:match(pat))
            if n then total, found = total + n * part[2], true end
        end
    end
    return found and total or nil
end
ns.LootToastCopperOf = copperOf

-- Looted money (also a group's share of it); a secret line is skipped.
ns.OnEvent("CHAT_MSG_MONEY", function(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local c = copperOf(text)
    if c then ns.LootToastMoney(c) end
end)
-- A quest's money.
ns.OnEvent("QUEST_TURNED_IN", function(_, _, money) ns.LootToastMoney(money) end)

-- A look setting changed: the lines shown now take it at once.
function ns.ApplyLootToastSize()
    for _, l in ipairs(lines) do sizeLine(l, size()) end
    if holder and #lines > 0 then step() end
end

local function preview()
    ns.LootToast(2589, 3, "|cffffffff|Hitem:2589::::::::1:::::::|h[" .. L["Leinenstoff"] .. "]|h|r")
    if ns.Get("toast.money") then show(COINS[1][3], ns.LootToastMoneyText(12345)) end
end
ns.LootToastPreview = preview

-- The move mode (F-158): on, the holder shows its ground, the hint and "Fertig", takes the mouse,
-- keeps the example lines still until it ends; off, it is fixed again and the lines run out.
function ns.LootToastUnlock(on)
    if not holder then build() end
    unlocked = on and true or false
    holder:EnableMouse(unlocked)
    holder.box:SetShown(unlocked)
    if unlocked then
        if #lines == 0 then preview() end
        holder:Show()
        holder:SetScript("OnUpdate", step)
    else
        -- the example lines start their time now
        for _, l in ipairs(lines) do l.born = now() end
        if #lines > 0 then holder:SetScript("OnUpdate", step) end
    end
    step()
end
function ns.LootToastUnlocked() return unlocked end

-- Back to the place of the start (also "Fensterposition zurücksetzen").
function ns.ResetLootToastPosition()
    local st = placeState()
    if st then st.point = nil end
    if holder then place() end
end

local function apply() if ns.ApplyLootToastSize then ns.ApplyLootToastSize() end end
local FONT_VALUES = { { "default", L["Standard"] }, { "friz", "Friz Quadrata" }, { "arial", "Arial Narrow" },
    { "skurri", "Skurri" }, { "morpheus", "Morpheus" } }

ns.RegisterSettings{ key = "toast", label = L["Item-Anzeige"], order = 88, group = "amisia", pages = { "about" }, items = {
    { key = "toast.show", type = "toggle", label = L["Erhaltene Items anzeigen"], default = true,
      tip = L["Zeigt kurz \"+Item\" mit Symbol in der Mitte des Bildschirms, wenn du etwas lootest oder als Questbelohnung bekommst; Käufe, Handel und Post nicht."] },
    { key = "toast.money", type = "toggle", label = L["Erhaltenes Gold anzeigen"], default = true,
      tip = L["Zeigt auch Gold, Silber und Kupfer, das du lootest oder für Quests bekommst, mit den Münzen in ihrer Farbe."] },
    { key = "toast.quality", type = "choice", label = L["Ab Qualität"], default = "0",
      values = { { "0", L["Alle"] }, { "1", L["Gewöhnlich (weiß)"] }, { "2", L["Selten (grün)"] }, { "3", L["Rar (blau)"] }, { "4", L["Episch (lila)"] } },
      tip = L["Items unter dieser Qualität zeigt die Anzeige nicht."] },
    { key = "toast.move", type = "button", label = L["Anzeige verschieben"],
      run = function() ns.LootToastUnlock(not unlocked) end,
      tip = L["Zeigt die Anzeige mit Rahmen und Beispielzeilen. Zieh sie mit der Maus an ihren Platz und klick auf \"Fertig\"."] },
    { key = "toast.resetPos", type = "button", label = L["Position zurücksetzen"],
      run = function() ns.ResetLootToastPosition() end,
      tip = L["Stellt die Anzeige wieder links über die Mitte des Bildschirms."] },
    { key = "toast.size", type = "slider", label = L["Schriftgröße der Anzeige"], default = LT.SIZE, min = LT.SIZE_MIN, max = LT.SIZE_MAX, step = 1,
      tip = L["Die Größe von Text und Symbol der Anzeige erhaltener Items und Gold."], onChange = apply },
    { key = "toast.font", type = "choice", label = L["Schriftart"], default = "default", values = FONT_VALUES,
      tip = L["Die Schriftart der Anzeige; Standard ist die große Schrift des Spiels."], onChange = apply },
    { key = "toast.outline", type = "choice", label = L["Umriss"], default = "default",
      values = { { "default", L["Standard"] }, { "none", L["Keiner"] }, { "OUTLINE", L["Dünn"] }, { "THICKOUTLINE", L["Dick"] } },
      tip = L["Ein Rand um die Buchstaben, damit sie vor hellem Hintergrund lesbar bleiben."], onChange = apply },
    { key = "toast.shadow", type = "toggle", label = L["Schatten"], default = true,
      tip = L["Ein Schatten unter dem Text."], onChange = apply },
    { key = "toast.icon", type = "toggle", label = L["Symbol zeigen"], default = true,
      tip = L["Das Symbol des Items oder der Münze vor dem Text."], onChange = apply },
    { key = "toast.align", type = "choice", label = L["Ausrichtung"], default = "left",
      values = { { "left", L["Links"] }, { "center", L["Mitte"] }, { "right", L["Rechts"] } },
      tip = L["Wo die Zeilen in der Anzeige stehen."], onChange = apply },
    { key = "toast.duration", type = "slider", label = L["Anzeigedauer (s)"], default = LT.SHOW, min = LT.SHOW_MIN, max = LT.SHOW_MAX, step = 0.5,
      tip = L["So lange bleibt eine Zeile stehen, bevor sie ausgeblendet ist."] },
    { key = "toast.motion", type = "choice", label = L["Bewegung"], default = "up",
      values = { { "up", L["Steigt nach oben"] }, { "down", L["Sinkt nach unten"] }, { "still", L["Steht still"] } },
      tip = L["Wie sich eine Zeile bewegt, während sie ausblendet."] },
    { key = "toast.order", type = "choice", label = L["Neue Zeilen"], default = "down",
      values = { { "down", L["Unten anfügen"] }, { "up", L["Oben anfügen"] } },
      tip = L["Ob eine neue Zeile unter oder über den anderen erscheint."] },
    { key = "toast.lines", type = "slider", label = L["Zeilen gleichzeitig"], default = LT.MAX, min = LT.MAX_MIN, max = LT.MAX_MAX, step = 1,
      tip = L["So viele Zeilen stehen höchstens gleichzeitig da; die älteste geht zuerst."] },
    { key = "toast.alpha", type = "slider", label = L["Deckkraft (%)"], default = 100, min = LT.ALPHA_MIN, max = 100, step = 5,
      tip = L["Wie durchsichtig die Anzeige ist."], onChange = apply },
    { key = "toast.test", type = "button", label = L["Anzeige ausprobieren"],
      run = function() preview() end,
      tip = L["Zeigt ein Beispiel, so wie es beim Looten erscheint."] },
} }
end)
