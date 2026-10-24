-- The card "Upgrades: <Slot>" beside the character window (F-125, D-56): a right-click on a slot of
-- the game's character window shows the best items of that slot for the own character, with the own
-- source chips and play style (ns.BisRanking). A click on a row sets the map target, Ctrl the try-on,
-- Shift the chat link, the right button the menu of the targets; "Im Fenster Ausrüstungsziele" opens
-- the goals window on the slot. Escape or a second right-click closes it.
--
-- Amisia only hooks the game's slot buttons (HookScript after the game's own click, which uses an
-- item with a use effect): on such an item a plain right-click is left to the game, Alt + right-click
-- opens the card on every slot. Nothing is equipped, nothing is sent. Setting bis.slotClick.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local Gear = ns.Gear

local C = T.SLOTCARD
local GREY, GREEN = T.GREY, "|cff4fd06a"
local QUESTION = 134400
-- the game's slot buttons by inventory slot (PaperDollItemSlotButton)
local BUTTONS = {
    [1] = "CharacterHeadSlot", [2] = "CharacterNeckSlot", [3] = "CharacterShoulderSlot", [15] = "CharacterBackSlot",
    [5] = "CharacterChestSlot", [9] = "CharacterWristSlot", [10] = "CharacterHandsSlot", [6] = "CharacterWaistSlot",
    [7] = "CharacterLegsSlot", [8] = "CharacterFeetSlot", [11] = "CharacterFinger0Slot", [12] = "CharacterFinger1Slot",
    [13] = "CharacterTrinket0Slot", [14] = "CharacterTrinket1Slot", [16] = "CharacterMainHandSlot",
    [17] = "CharacterSecondaryHandSlot", [18] = "CharacterRangedSlot",
}
local SLOT_OF_INV = {}
for _, sl in ipairs(Gear.SLOTS) do SLOT_OF_INV[sl.inv] = sl end

local card
local hooked = {}   -- [button] = true

local function K() return ns.GearPageKit end

-- Whether the worn item of an inventory slot has a use effect (the game's right-click uses it).
local function hasUse(inv)
    local link = GetInventoryItemLink and ns.Plain(GetInventoryItemLink("player", inv))
    if type(link) ~= "string" then return false end
    local f = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
    if type(f) ~= "function" then return false end
    local ok, name = pcall(f, link)
    return ok and ns.Plain(name) ~= nil
end

local function gainOf(e)
    if e.worn then return GREEN .. L["angelegt"] .. "|r" end
    if e.switch then return L["Wechsel"] end
    local u = ns.UpgradeOf(e.id)
    if not u then return "" end
    return ((u.up and GREEN) or GREY) .. ns.UpgradePctText(u) .. "|r"
end

local function fillRow(r, e, o)
    r.e = e
    if not e then
        r:Hide()
        return
    end
    local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(e.id)
    r.icon:SetTexture(icon or QUESTION)
    r.name:SetText((e.own and (T.GOLD_TEXT .. "* |r") or "") .. K().itemText(e.id))
    r.src:SetText(e.owned and K().OWNED_TEXT[e.owned] or K().sourceText(e.id, o, e.pick))
    r.gain:SetText(gainOf(e))
    r:Show()
end

local function rowClick(self, button)
    local e = self.e
    if not e then return end
    if button == "RightButton" then
        local c = ns.BisChar()
        e.wished = c and type(c.wish) == "table" and c.wish[e.id] ~= nil or false
        W.Menu(self, K().menuEntries(e, ns.BisOpts()))
        return
    end
    if K().modifiedClick(e.id) then return end
    local ok, why = ns.MapSetTarget(e.id)
    if not ok and why then ns.msg(why) end
end

local function build()
    card = W.Inset(UIParent)
    _G.AmisiaSlotCard = card
    card:SetFrameStrata("DIALOG")
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card.fill(W.BG[1], W.BG[2], W.BG[3], W.BG[4])
    card:SetWidth(C.W)
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaSlotCard") end
    card.title = W.Text(card, T.FONT.title, C.W - 2 * C.PAD - C.CLOSE)
    card.title:SetPoint("TOPLEFT", C.PAD, -C.PAD)
    card.close = W.ResetButton(card, C.CLOSE, function() card:Hide() end)
    card.close:SetPoint("TOPRIGHT", -C.PAD / 2, -C.PAD / 2)
    card.rows = {}
    for i = 1, C.ROWS do
        local r = CreateFrame("Button", nil, card)
        r:SetSize(C.W - 2 * C.PAD, C.ROW_H)
        r:SetPoint("TOPLEFT", C.PAD, -(C.PAD + C.TITLE_H + (i - 1) * C.ROW_H))
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(C.ICON, C.ICON)
        r.icon:SetPoint("LEFT", 0, 0)
        r.name = W.Text(r, T.FONT.text, C.W - 2 * C.PAD - C.TEXT_X - C.GAIN_W)
        r.name:SetPoint("TOPLEFT", C.TEXT_X, -3)
        r.src = W.Text(r, T.FONT.hint, C.W - 2 * C.PAD - C.TEXT_X - C.GAIN_W)
        r.src:SetPoint("BOTTOMLEFT", C.TEXT_X, 4)
        r.gain = W.Text(r, T.FONT.text, C.GAIN_W)
        r.gain:SetPoint("RIGHT", 0, 0)
        r.gain:SetJustifyH("RIGHT")
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        r.hl:SetBlendMode("ADD")
        r:SetScript("OnClick", rowClick)
        r:SetScript("OnEnter", function(self) if self.e then K().itemTooltip(self, self.e.id) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        card.rows[i] = r
    end
    card.empty = W.Text(card, T.FONT.hint, C.W - 2 * C.PAD, true)
    card.empty:SetPoint("TOPLEFT", C.PAD, -(C.PAD + C.TITLE_H))
    card.open = W.Button(card, L["Im Fenster Ausrüstungsziele"], C.BUTTON_W, function()
        local st = ns.GoalsFrameState and ns.GoalsFrameState()
        if st and card.slot then st.slot = card.slot end
        if ns.ShowGoalsFrame then ns.ShowGoalsFrame() end
        card:Hide()
    end)
    W.FitChip(card.open, C.BUTTON_W)
    card.open:SetPoint("BOTTOMLEFT", C.PAD, C.PAD)
    card:Hide()
end

local function fill()
    if not card or not card:IsShown() or not card.slot then return end
    local sl
    for _, s in ipairs(Gear.SLOTS) do if s.key == card.slot then sl = s end end
    card.title:SetText(L["Upgrades: %s"]:format(sl and sl.name or card.slot))
    local o = ns.BisOpts()
    local list = ns.BisRanking(card.slot, C.ROWS)
    local n = 0
    for i = 1, C.ROWS do
        fillRow(card.rows[i], list[i], o)
        if list[i] then n = i end
    end
    if n == 0 then
        card.empty:SetText(ns.PlayStyle.Count() > 0 and L["Nichts mit diesem Spielstil"] or L["Für diesen Slot gibt es keine Option in den Daten."])
        card.empty:Show()
        n = 1
    else
        card.empty:Hide()
    end
    card:SetHeight(C.PAD + C.TITLE_H + n * C.ROW_H + C.GAP + T.BUTTON_H + C.PAD)
end

-- Shows the card for a slot (a key of Gear.SLOTS) beside anchor; the same slot again closes it.
function ns.ShowSlotCard(slotKey, anchor)
    if not Gear.Available() then
        ns.msg(L["Für diesen Client gibt es keine Ausrüstungsdaten."])
        return nil
    end
    if not card then build() end
    if card:IsShown() and card.slot == slotKey then
        card:Hide()
        return nil
    end
    card.slot = slotKey
    card:ClearAllPoints()
    local frame = _G.CharacterFrame
    if frame and frame.IsShown and frame:IsShown() then
        card:SetPoint("TOPLEFT", frame, "TOPRIGHT", C.OFFSET_X, 0)
    elseif anchor then
        card:SetPoint("TOPLEFT", anchor, "TOPRIGHT", C.OFFSET_X, 0)
    else
        card:SetPoint("CENTER")
    end
    card:Show()
    fill()
    return card
end

local function onSlotClick(self, button)
    if button ~= "RightButton" or not ns.Get("bis.slotClick") then return end   -- l10n-ok: setting key
    if CursorHasItem and CursorHasItem() then return end
    -- Shift + right-click socketing and Ctrl + right-click stay the game's
    if (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then return end
    local inv = self.GetID and self:GetID()
    local sl = SLOT_OF_INV[inv]
    if not sl then return end
    local alt = IsAltKeyDown and IsAltKeyDown()
    -- the game used an item with a use effect: only Alt opens the card there
    if not alt and hasUse(inv) then return end
    ns.ShowSlotCard(sl.key, self)
end

local function tipLine(self)
    if not ns.Get("bis.slotClick") or not Gear.Available() then return end   -- l10n-ok: setting key
    local inv = self.GetID and self:GetID()
    if not SLOT_OF_INV[inv] or not GameTooltip:IsOwned(self) then return end
    local text = hasUse(inv) and L["Alt+Rechtsklick: Upgrades (Amisia)"] or L["Rechtsklick: Upgrades (Amisia)"]
    -- the slot's OnEnter and the game's direct call on a modifier change (Alt) both come here: once
    local n = GameTooltip:NumLines() or 0
    local last = n > 0 and _G["GameTooltipTextLeft" .. n]
    if last and last.GetText and last:GetText() == text then return end
    GameTooltip:AddLine(text, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- Hooks the game's slot buttons once they exist; the count of those found (the self-test reads it).
function ns.SlotCardHook()
    local n = 0
    for _, name in pairs(BUTTONS) do
        local b = _G[name]
        if b and b.HookScript then
            n = n + 1
            if not hooked[b] then
                hooked[b] = true
                b:HookScript("OnClick", onSlotClick)
                b:HookScript("OnEnter", tipLine)
            end
        end
    end
    -- the game calls the slot's OnEnter directly when a modifier changes (Alt: the item flyout); the
    -- tooltip it builds then has no line of the hook above
    if not hooked.onEnter and type(_G.PaperDollItemSlotButton_OnEnter) == "function" and hooksecurefunc then
        hooked.onEnter = true
        hooksecurefunc("PaperDollItemSlotButton_OnEnter", tipLine)
    end
    return n
end

ns.OnEvent("PLAYER_LOGIN", function() ns.SlotCardHook() end)
ns.Listen("BIS_CHANGED", function() fill() end)
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", function() fill() end)
