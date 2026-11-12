-- The doll and the goals' parts of the page "Ausrüstungsplaner" (Pages/Planner.lua, F-149, D-77, D-80;
-- until 2.64.0 the window "Ausrüstungsziele"): the own character as a DressUpModel between the slot
-- columns as on the character frame (drag turns, the wheel zooms, a right click resets; without the
-- model's methods the slots alone and "Modell nicht verfügbar"), the weapons under it, each slot the
-- target (ns.BisTargets: the own pick first, D-55) or what is worn in its quality's frame; the slots
-- of the goals list by section with the targets got, the raid check's enchant test, the weapon plan's
-- text. Everything comes from ns.BisTargets; nothing is sent or saved here.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local PL = T.PLANNER
local Gear = ns.Gear
local K = ns.GearPageKit
local GREY, GREEN = T.GREY, "|cff4fd06a"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local DOT = "Interface\\AddOns\\Amisia\\Media\\Icons\\dot"
local GOLD = T.GOLD
-- the goals list's sections: armour, jewellery, weapons (the 17 rows of Gear.SLOTS)
local SECTIONS = {
    { key = "armor", label = L["Rüstung"], slots = { "HEAD", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET" } },
    { key = "jewel", label = L["Schmuck##Abschnitt"], slots = { "NECK", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2" } },
    { key = "weapon", label = L["Waffen"], slots = { "MAINHAND", "OFFHAND", "RANGED" } },
}
local INV = {}
for _, sl in ipairs(Gear.SLOTS) do INV[sl.key] = sl.inv end
-- the shirt and the tabard: what is worn, no targets
INV.SHIRT, INV.TABARD = 4, 19

---------------------------------------------------------------------------
-- Items: what a slot shows (its target or what is worn), icons, quality colours, tooltips
---------------------------------------------------------------------------

local function wornLink(key)
    local link = GetInventoryItemLink and INV[key] and ns.Plain(GetInventoryItemLink("player", INV[key]))
    return type(link) == "string" and link or nil
end

local function iconOf(id)
    local f = C_Item and C_Item.GetItemIconByID
    local icon = id and type(f) == "function" and ns.Plain(f(id)) or nil
    return icon or (id and Gear.ScanIcon(id))
end

local function qualityOf(id, link)
    local f = C_Item and C_Item.GetItemInfo
    local q = (link or id) and type(f) == "function" and select(3, f(link or id)) or nil
    if not q and id then
        local row = Gear.Item(id)
        q = row and row[5]
    end
    return tonumber(q)
end

-- The empty slot's art of the character frame: the client's own (GetInventorySlotInfo), else ours.
local function slotArt(key)
    local f = _G.GetInventorySlotInfo
    if type(f) == "function" then
        local ok, _, tex = pcall(f, PL.SLOT_NAME[key])
        if ok and type(tex) == "string" and tex ~= "" then return tex end
    end
    return PL.SLOT_ART[key]
end

-- What a slot of the doll shows: { id, link (worn), target (an option of the targets) } or nil.
local function shownItem(res, key, m)
    local target = res[key] and res[key][1]
    local link = wornLink(key)
    if m == "goals" and target then return { id = target.id, target = target } end
    if m == "goals" and key == "OFFHAND" and res.plan == "2H" then return nil end
    if link then return { id = ns.ItemID(link), link = link } end
    return nil
end

local function tooltipFor(owner, item, key)
    if not item then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.BIS_SLOT_NAME[key] or key, 1, 0.82, 0)
        GameTooltip:AddLine(L["nichts"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    if item.link and GameTooltip.SetInventoryItem then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", INV[key])
        GameTooltip:Show()
        return
    end
    K.itemTooltip(owner, item.id)
end

---------------------------------------------------------------------------
-- The doll: slot buttons, the model
---------------------------------------------------------------------------

-- A slot of the doll d in the sizes of profile P: a click chooses it (d.onChoose; the shirt and the
-- tabard have no targets and are not chosen), right click the gear page's menu of its target.
local function slotButton(parent, key, P, d)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(P.SLOT, P.SLOT)
    b.key = key
    -- the slot (D-81 Nachtrag): a dark rounded ground, the icon with rounded corners (the client's
    -- mask texture over Amisia's own slot_mask), a thin rounded ring in the item's colour over it
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(P.SLOT_MASK)
    b.bg:SetVertexColor(0, 0, 0, 0.6)
    b.art = b:CreateTexture(nil, "BORDER")
    b.art:SetPoint("TOPLEFT", P.SLOT_INSET, -P.SLOT_INSET)
    b.art:SetPoint("BOTTOMRIGHT", -P.SLOT_INSET, P.SLOT_INSET)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", P.SLOT_INSET, -P.SLOT_INSET)
    b.icon:SetPoint("BOTTOMRIGHT", -P.SLOT_INSET, P.SLOT_INSET)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if b.CreateMaskTexture and b.icon.AddMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetAllPoints(b)
        mask:SetTexture(P.SLOT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        b.icon:AddMaskTexture(mask)
        b.art:AddMaskTexture(mask)
        b.mask = mask
    end
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAllPoints()
    b.ring:SetTexture(P.SLOT_RING)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetTexture(P.SLOT_MASK)
    b.hl:SetVertexColor(1, 1, 1, 0.15)
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetSize(P.DOT, P.DOT)
    b.dot:SetPoint("BOTTOMRIGHT", 1, -1)
    b.dot:SetTexture(DOT)
    b.dot:Hide()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        local item = self.item
        if button == "RightButton" then
            if item and item.target then W.Menu(self, K.menuEntries(item.target, ns.BisOpts())) end
            return
        end
        if item and item.id and K.modifiedClick(item.id) then return end
        if ns.BIS_SLOT_NAME[self.key] and d.onChoose then d.onChoose(self.key) end
    end)
    b:SetScript("OnEnter", function(self) tooltipFor(self, self.item, self.key) end)
    b:SetScript("OnLeave", K.hideTip)
    return b
end

-- Rounds an icon on frame f (D-81 Nachtrag): the icon (and the extra textures) under Amisia's
-- rounded mask, a thin rounded ring over them (f.ring; colour it with ringColor). P: SLOT_RING, SLOT_MASK.
local function roundIcon(f, P, ...)
    if f.CreateMaskTexture then
        local mask = f:CreateMaskTexture()
        mask:SetAllPoints(f)
        mask:SetTexture(P.SLOT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        for _, t in ipairs({ ... }) do if t.AddMaskTexture then t:AddMaskTexture(mask) end end
        f.mask = mask
    end
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetAllPoints()
    f.ring:SetTexture(P.SLOT_RING)
    return f.ring
end

-- The ring's colour (b.ringColor for the tests).
local function setRing(b, r, g, bl)
    b.ringColor = { r, g, bl, 1 }
    b.ring:SetVertexColor(r, g, bl, 1)
end

local function fillSlot(b, item, chosen, stateColor)
    b.item = item
    if item and item.id then
        b.icon:SetTexture(iconOf(item.id) or QUESTION)
        b.icon:Show()
        b.art:Hide()
        local q = qualityOf(item.id, item.link)
        local c = q and PL.QUALITY[q] or PL.QUALITY[1]
        setRing(b, c[1], c[2], c[3])
    else
        b.icon:Hide()
        b.art:SetTexture(slotArt(b.key))
        b.art:Show()
        setRing(b, 0.3, 0.3, 0.3)
    end
    if chosen then setRing(b, GOLD[1], GOLD[2], GOLD[3]) end
    if stateColor then
        b.dot:SetVertexColor(stateColor[1], stateColor[2], stateColor[3])
        b.dot:Show()
    else
        b.dot:Hide()
    end
end

-- The model: a DressUpModel with SetUnit, Undress and TryOn, or nil (the client has none).
local function makeModel(parent)
    local ok, m = pcall(CreateFrame, "DressUpModel", nil, parent)
    if not ok or not m then return nil end
    for _, fn in ipairs({ "SetUnit", "Undress", "TryOn" }) do
        if type(m[fn]) ~= "function" then
            m:Hide()
            return nil
        end
    end
    return m
end

local function call(m, fn, ...)
    if m and type(m[fn]) == "function" then pcall(m[fn], m, ...) end
end

local function resetView(m)
    m.rot, m.zoom = 0, 0
    call(m, "SetRotation", 0)
    call(m, "SetPortraitZoom", 0)
end

local function cursorX()
    local f = _G.GetCursorPosition
    if type(f) ~= "function" then return nil end
    local x = f()
    return tonumber(x)
end

local function rotate(self)
    local x = cursorX()
    if not x or not self.dragX then return end
    local scale = self.GetEffectiveScale and self:GetEffectiveScale() or 1
    self.rot = (self.dragRot or 0) + (x - self.dragX) / (scale ~= 0 and scale or 1) * self.P.ROTATE
    call(self, "SetRotation", self.rot)
end
rotate = ns.Perf.Wrap("OnUpdate GearDoll rotate", rotate)   -- /amisia leistung (F-184)

-- drag turns, the wheel zooms, a right click resets
local function wireModel(m, P)
    m.P = P
    m:EnableMouse(true)
    if m.EnableMouseWheel then m:EnableMouseWheel(true) end
    m:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            resetView(self)
            return
        end
        self.dragX, self.dragRot = cursorX(), self.rot or 0
        self:SetScript("OnUpdate", rotate)
    end)
    m:SetScript("OnMouseUp", function(self)
        self.dragX = nil
        self:SetScript("OnUpdate", nil)
    end)
    m:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.max(0, math.min(P.ZOOM_MAX, (self.zoom or 0) + (tonumber(delta) or 0) * P.ZOOM_STEP))
        call(self, "SetPortraitZoom", self.zoom)
    end)
    resetView(m)
end

-- The doll in the sizes of profile P (T.PLANNER.DOLL): the slot columns P.LEFT and P.RIGHT beside
-- the model, P.BOTTOM_ROW under it, the model on an inset between them; the caller places it.
-- opts.onChoose(key): a slot's click; opts.decorate(button, side): dresses each slot ("left", "right",
-- "bottom": the enchant squares). d.SetDollWidth(w): the width (it follows the page, D-71).
local function buildDoll(parent, P, opts)
    opts = opts or {}
    local d = CreateFrame("Frame", nil, parent)
    d.P, d.onChoose = P, opts.onChoose
    d:SetSize(P.DOLL_W, P.MODEL_H + P.WEAPON_GAP + P.SLOT)
    d.slots, d.extras = {}, {}
    local pitch = P.SLOT + P.SLOT_GAP
    local left, right, bottom = {}, {}, {}
    for _, key in ipairs(P.LEFT) do left[#left + 1] = slotButton(d, key, P, d) end
    for _, key in ipairs(P.RIGHT) do right[#right + 1] = slotButton(d, key, P, d) end
    for _, key in ipairs(P.BOTTOM_ROW) do bottom[#bottom + 1] = slotButton(d, key, P, d) end
    W.Column(d, left, P.SLOT_GAP, 0, -math.floor((#right - #left) * pitch / 2))
    local gap = P.BOTTOM_GAP or P.SLOT_GAP
    local rowW = #bottom * P.SLOT + (#bottom - 1) * gap
    for _, part in ipairs({ { "left", left }, { "right", right }, { "bottom", bottom } }) do
        for _, b in ipairs(part[2]) do
            d.slots[b.key] = b
            if not ns.BIS_SLOT_NAME[b.key] then d.extras[#d.extras + 1] = b.key end
            if opts.decorate then opts.decorate(b, part[1]) end
        end
    end
    -- the model between the columns, on an inset
    local mx = P.SLOT + P.MODEL_GAP
    d.inset = W.Inset(d)
    d.inset:SetPoint("TOPLEFT", mx, 0)
    d.inset.fill(0, 0, 0, P.MODEL_SHADE or 0.35)
    d.model = makeModel(d.inset)
    if d.model then
        d.model:SetPoint("TOPLEFT", 2, -2)
        d.model:SetPoint("BOTTOMRIGHT", -2, 2)
        wireModel(d.model, P)
    end
    d.noModel = W.Text(d.inset, T.FONT.hint, P.DOLL_W - 2 * mx - 16, true)
    d.noModel:SetPoint("CENTER")
    d.noModel:SetJustifyH("CENTER")
    d.noModel:SetText(L["Modell nicht verfügbar"])
    if d.model then d.noModel:Hide() end
    -- the right column at the edge, the weapons centred, the model between
    function d.SetDollWidth(w)
        d.dollW = w
        d:SetWidth(w)
        W.Column(d, right, P.SLOT_GAP, w - P.SLOT, 0)
        W.Row(d, bottom, gap, math.floor((w - rowW) / 2), -(P.MODEL_H + P.WEAPON_GAP))
        d.inset:SetSize(w - 2 * mx, P.MODEL_H)
        d.noModel:SetWidth(w - 2 * mx - 16)
    end
    d.SetDollWidth(P.DOLL_W)
    return d
end

-- the hand a weapon is tried on in (the client's dressing room passes it, so two weapons show in
-- both hands); the ranged slot first, then the hands
local HAND = { MAINHAND = "MAINHANDSLOT", OFFHAND = "SECONDARYHANDSLOT", RANGED = "RANGEDSLOT" }
local TRY_ORDER = {}
for _, sl in ipairs(Gear.SLOTS) do if sl.key == "RANGED" then table.insert(TRY_ORDER, 1, sl) end end
for _, sl in ipairs(Gear.SLOTS) do if sl.key ~= "RANGED" then TRY_ORDER[#TRY_ORDER + 1] = sl end end

-- TryOn with the hand; a client that refuses the second argument gets the link alone.
local function tryOn(model, link, hand)
    if type(model.TryOn) ~= "function" then return end
    if hand and pcall(model.TryOn, model, link, hand) then return end
    pcall(model.TryOn, model, link)
end

-- Dresses the model for the mode: what is worn ("worn"), or undressed with the targets, the worn
-- item where a slot has none ("goals"). Only when what it wears changes (every item answer dressing
-- it anew made it flicker).
local function dress(d, res, m)
    local model = d.model
    if not model then return end
    local links, key = {}, { m }
    for _, k in ipairs(d.extras or {}) do
        local link = wornLink(k)
        if link then
            links[#links + 1] = { link }
            key[#key + 1] = link
        end
    end
    for _, sl in ipairs(TRY_ORDER) do
        local item = shownItem(res, sl.key, m)
        if item then
            local link = item.link or (item.id and K.linkOf(item.id))
            links[#links + 1] = { link, HAND[sl.key] }
            key[#key + 1] = tostring(link)
        end
    end
    local k = table.concat(key, "|")
    if d.dressed == k then return end
    d.dressed = k
    call(model, "SetUnit", "player")
    if m == "goals" then
        call(model, "Undress")
        for _, e in ipairs(links) do tryOn(model, e[1], e[2]) end
    end
end

-- Fills the doll's slots for the mode (goals or worn): the chosen one gold, the state dot (green
-- worn, yellow in bag or bank); a slot whose target is worn a green frame. Returns the progress
-- (ns.BisProgress).
local function fillDoll(d, res, m, chosen)
    local p = ns.BisProgress(res)
    for key, b in pairs(d.slots) do
        local st = p.slot[key]
        local hasTarget = res[key] and res[key][1]
        fillSlot(b, shownItem(res, key, m), key == chosen, hasTarget and (st == "done" or st == "bag") and PL.STATE_COLOR[st] or nil)
        if m == "goals" and hasTarget and st == "done" and key ~= chosen then
            local c = PL.STATE_COLOR.done
            setRing(b, c[1], c[2], c[3])
        end
    end
    return p
end

---------------------------------------------------------------------------
-- The goals list: the slots by section (F-113)
---------------------------------------------------------------------------

-- The worn items without a permanent enchant in the raid check's enchanted slots, as a set of slot
-- keys; read again only when what is worn changes.
local enchKey, enchSet
local function unenchanted()
    local links = {}
    for _, sl in ipairs(Gear.SLOTS) do links[#links + 1] = tostring(wornLink(sl.key)) end
    local key = table.concat(links, "|")
    if key == enchKey and enchSet then return enchSet end
    local set = {}
    local RC = ns.RaidCheck
    if RC and RC.Unenchanted then
        local ok, list = pcall(RC.Unenchanted)
        local byInv = {}
        for k, inv in pairs(INV) do byInv[inv] = k end
        for _, inv in ipairs(ok and list or {}) do
            if byInv[inv] then set[byInv[inv]] = true end
        end
    end
    enchKey, enchSet = key, set
    return set
end

local function passes(f, key, p, ench)
    if f == "todo" then return p.slot[key] == "todo" end
    if f == "bag" then return p.slot[key] == "bag" end
    if f == "ench" then return ench[key] == true end
    return true
end

-- The rows of the goals list: a head per section with the targets got (over every slot of the
-- section), then the slots the filter lets through; a section without one is left out. A slot row:
-- { key, name, opt (the target), plan, wornLink, status }.
local function goalItems(res, p, f, ench)
    local out = {}
    for _, sec in ipairs(SECTIONS) do
        local have, rows = 0, {}
        for _, key in ipairs(sec.slots) do
            if p.slot[key] == "done" then have = have + 1 end
            if passes(f, key, p, ench) then
                rows[#rows + 1] = { key = key, name = ns.BIS_SLOT_NAME[key], opt = res[key] and res[key][1], plan = res.plan,
                    wornLink = wornLink(key), status = p.slot[key] }
            end
        end
        if #rows > 0 then
            out[#out + 1] = { header = sec, have = have, total = #sec.slots }
            for _, r in ipairs(rows) do out[#out + 1] = r end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function pctText(gain, mine, up)
    if type(gain) ~= "number" then return "" end
    local color = up and GREEN or GREY
    if type(mine) == "number" and mine > 0 then return color .. K.pctText(gain, mine) .. "|r" end
    return color .. ("%+d"):format(math.floor(gain + 0.5)) .. "|r"
end

local OWN_MARK, WISH_STAR = "|A:auctionhouse-icon-favorite:12:12|a ", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t "
local function ownMark()
    -- the auction house's favourite star; without that atlas the raid star
    if W.HasAtlas("auctionhouse-icon-favorite") then return OWN_MARK end
    return WISH_STAR
end

-- "Ausdauer +5, Stärke +4" of a set bonus (false: a bonus the score does not count).
local function bonusText(stats)
    if not stats then return L["nicht gewertet"] end
    local parts = {}
    for k, v in pairs(stats) do parts[#parts + 1] = ("%s %+d"):format(Gear.STAT_LABELS[k] or k, v) end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function setTip(owner, s)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(s.name, 1, 0.82, 0)
    GameTooltip:AddLine(L["%d von %d Teilen hast du"]:format(s.have, s.total), 1, 1, 1)
    if s.cat == "level" then
        GameTooltip:AddLine(L["Das Beste je Slot für deine Spezialisierung auf Stufe %d."]:format(s.to), 0.85, 0.85, 0.85, true)
    elseif s.level > 0 then
        GameTooltip:AddLine(L["Stufe %d"]:format(s.level), 0.85, 0.85, 0.85)
    end
    local b = Gear.SetBonusesOf(s.id)
    local thr = {}
    for n in pairs(b) do thr[#thr + 1] = n end
    table.sort(thr)
    for _, n in ipairs(thr) do GameTooltip:AddLine(("(%d) %s"):format(n, bonusText(b[n])), 0.31, 0.82, 0.42, true) end
    GameTooltip:AddLine(L["Klick: Teile zeigen oder verbergen."], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- "Waffen: Waffe und Schild": the weapon plan, "auto" as the targets show it.
local function planText(o, res)
    local plan = o.plan or "auto"
    if plan == "auto" then
        if res.plan == "2H" then
            plan = "2H"
        else
            local oh = res.OFFHAND and res.OFFHAND[1]
            local g = oh and ns.BisGroup(oh.id)
            plan = (g == "1H" or g == "OHW") and "DW" or "SHIELD"
        end
    end
    return L["Waffen: %s"]:format(ns.BIS_PLANS[plan] or plan)
end

ns.GoalsKit = {
    roundIcon = roundIcon, setRing = function(f, r, g, b) f.ringColor = { r, g, b, 1 } f.ring:SetVertexColor(r, g, b, 1) end,
    buildDoll = buildDoll, fillDoll = fillDoll, dress = dress, wornLink = wornLink,
    iconOf = iconOf, qualityOf = qualityOf, ownMark = ownMark, pctText = pctText, setTip = setTip,
    unenchanted = unenchanted, goalItems = goalItems, planText = planText, QUESTION = QUESTION,
}
