-- The window "Ausrüstungsziele" (AmisiaGoalsFrame, spec docs/specs/2026-10-17-ziele-fenster.md):
-- the own character's targets at a glance. Left the doll: the character model (a DressUpModel)
-- between the slot columns as on the character frame, the weapons under it, the switch "Ziele"
-- (the model undressed, then the targets tried on, the worn item where a slot has none) or
-- "Angelegt" (what is worn). In the middle the slots by section with item, gain and source, as the
-- gear page's view Ziele shows them (its item texts, sources, map button, menu and clicks come from
-- ns.GearPageKit). Everything comes from ns.BisTargets: the window and the page show the same
-- targets. The window is moved and scaled on its own (settings.goalWindow, ui.goalScale, Ctrl +
-- mouse wheel), as the talent window. Nothing is built before it opens; nothing is sent.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local G = T.GOALS
local Gear = ns.Gear
local K = ns.GearPageKit
local GREY, GREEN = T.GREY, "|cff4fd06a"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local DOT = "Interface\\AddOns\\Amisia\\Media\\Icons\\dot"
local GOLD = T.GOLD
-- the list's sections: armour, jewellery, weapons (the 17 rows of Gear.SLOTS)
local SECTIONS = {
    { key = "armor", label = L["Rüstung"], slots = { "HEAD", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET" } },
    { key = "jewel", label = L["Schmuck##Abschnitt"], slots = { "NECK", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2" } },
    { key = "weapon", label = L["Waffen"], slots = { "MAINHAND", "OFFHAND", "RANGED" } },
}
local INV = {}
for _, sl in ipairs(Gear.SLOTS) do INV[sl.key] = sl.inv end

local win, built

---------------------------------------------------------------------------
-- State: settings.goalWindow = { point, x, y, mode = goals/worn, slot }
---------------------------------------------------------------------------

local function winState()
    local st = type(AmisiaDB) == "table" and AmisiaDB.settings
    if type(st) ~= "table" then return {} end
    if type(st.goalWindow) ~= "table" then st.goalWindow = {} end
    return st.goalWindow
end

local function mode()
    return winState().mode == "worn" and "worn" or "goals"
end

-- The chosen slot: the saved one, else the first with an upgrade, else the first.
local function chosenSlot(res)
    local s = winState().slot
    if ns.BIS_SLOT_NAME[s] then return s end
    for _, sl in ipairs(Gear.SLOTS) do
        if res and res.state[sl.key] == "upgrade" then return sl.key end
    end
    return Gear.SLOTS[1].key
end

local refresh

local function choose(key)
    winState().slot = key
    refresh()
end

---------------------------------------------------------------------------
-- Items: what a slot shows (its target or what is worn), icons, quality colours, tooltips
---------------------------------------------------------------------------

local function wornLink(key)
    local link = GetInventoryItemLink and ns.Plain(GetInventoryItemLink("player", INV[key]))
    return type(link) == "string" and link or nil
end

local function iconOf(id)
    local f = C_Item and C_Item.GetItemIconByID
    local icon = id and type(f) == "function" and ns.Plain(f(id)) or nil
    return icon
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
        local ok, _, tex = pcall(f, G.SLOT_NAME[key])
        if ok and type(tex) == "string" and tex ~= "" then return tex end
    end
    return G.SLOT_ART[key]
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
-- The doll: slot buttons, the model, the switch
---------------------------------------------------------------------------

local function slotButton(parent, key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(G.SLOT, G.SLOT)
    b.key = key
    b.bg = W.Flat(b, 0, 0, 0, 0.6)
    b.art = b:CreateTexture(nil, "BORDER")
    b.art:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", G.SLOT_INSET, -G.SLOT_INSET)
    b.icon:SetPoint("BOTTOMRIGHT", -G.SLOT_INSET, G.SLOT_INSET)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.edges = W.Border(b, 0.3, 0.3, 0.3, 1, G.SLOT_EDGE)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.15)
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetSize(G.DOT, G.DOT)
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
        choose(self.key)
    end)
    b:SetScript("OnEnter", function(self) tooltipFor(self, self.item, self.key) end)
    b:SetScript("OnLeave", K.hideTip)
    return b
end

local function fillSlot(b, item, chosen, stateColor)
    b.item = item
    if item and item.id then
        b.icon:SetTexture(iconOf(item.id) or QUESTION)
        b.icon:Show()
        b.art:Hide()
        local q = qualityOf(item.id, item.link)
        local c = q and G.QUALITY[q] or G.QUALITY[1]
        W.SetBorderColor(b.edges, c[1], c[2], c[3], 1)
    else
        b.icon:Hide()
        b.art:SetTexture(slotArt(b.key))
        b.art:Show()
        W.SetBorderColor(b.edges, 0.3, 0.3, 0.3, 1)
    end
    if chosen then W.SetBorderColor(b.edges, GOLD[1], GOLD[2], GOLD[3], 1) end
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

local wheel   -- the window's Ctrl + mouse wheel (below)

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
    self.rot = (self.dragRot or 0) + (x - self.dragX) / (scale ~= 0 and scale or 1) * G.ROTATE
    call(self, "SetRotation", self.rot)
end

local function wireModel(m)
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
        if IsControlKeyDown and IsControlKeyDown() then return wheel(self, delta) end
        self.zoom = math.max(0, math.min(G.ZOOM_MAX, (self.zoom or 0) + (tonumber(delta) or 0) * G.ZOOM_STEP))
        call(self, "SetPortraitZoom", self.zoom)
    end)
    resetView(m)
end

local function buildDoll(parent)
    local d = CreateFrame("Frame", nil, parent)
    d:SetPoint("TOPLEFT", G.DOLL_X, -G.COL_Y)
    d:SetSize(G.DOLL_W, G.MODEL_H + G.WEAPON_GAP + G.SLOT + G.SWITCH_GAP + T.CHIP_H + G.HINT_H)
    d.slots = {}
    local pitch = G.SLOT + G.SLOT_GAP
    local left, right, bottom = {}, {}, {}
    for _, key in ipairs(G.LEFT) do left[#left + 1] = slotButton(d, key) end
    for _, key in ipairs(G.RIGHT) do right[#right + 1] = slotButton(d, key) end
    for _, key in ipairs(G.BOTTOM_ROW) do bottom[#bottom + 1] = slotButton(d, key) end
    -- the left column centred on the right one (6 slots beside 8)
    W.Column(d, left, G.SLOT_GAP, 0, -math.floor((#right - #left) * pitch / 2))
    W.Column(d, right, G.SLOT_GAP, G.DOLL_W - G.SLOT, 0)
    local rowW = #bottom * G.SLOT + (#bottom - 1) * G.SLOT_GAP
    W.Row(d, bottom, G.SLOT_GAP, math.floor((G.DOLL_W - rowW) / 2), -(G.MODEL_H + G.WEAPON_GAP))
    for _, list in ipairs({ left, right, bottom }) do
        for _, b in ipairs(list) do d.slots[b.key] = b end
    end
    -- the model between the columns, on an inset
    local mx = G.SLOT + G.MODEL_GAP
    d.inset = W.Inset(d)
    d.inset:SetPoint("TOPLEFT", mx, 0)
    d.inset:SetSize(G.DOLL_W - 2 * mx, G.MODEL_H)
    d.inset.fill(0, 0, 0, 0.35)
    d.model = makeModel(d.inset)
    if d.model then
        d.model:SetPoint("TOPLEFT", 2, -2)
        d.model:SetPoint("BOTTOMRIGHT", -2, 2)
        wireModel(d.model)
    end
    d.noModel = W.Text(d.inset, T.FONT.hint, G.DOLL_W - 2 * mx - 16, true)
    d.noModel:SetPoint("CENTER")
    d.noModel:SetJustifyH("CENTER")
    d.noModel:SetText(L["Modell nicht verfügbar"])
    if d.model then d.noModel:Hide() end
    -- the switch Ziele / Angelegt and what the mouse does with the model
    d.goals = W.Chip(d, L["Ziele"], G.SWITCH_W, function() winState().mode = "goals"; refresh() end)
    d.worn = W.Chip(d, L["Angelegt"], G.SWITCH_W, function() winState().mode = "worn"; refresh() end)
    local w1, w2 = W.FitChip(d.goals, G.SWITCH_W), W.FitChip(d.worn, G.SWITCH_W)
    local sy = -(G.MODEL_H + G.WEAPON_GAP + G.SLOT + G.SWITCH_GAP)
    W.Row(d, { d.goals, d.worn }, T.CHIP_GAP, math.floor((G.DOLL_W - w1 - w2 - T.CHIP_GAP) / 2), sy)
    d.hint = W.Text(d, T.FONT.hint, G.DOLL_W, true)
    d.hint:SetPoint("TOPLEFT", 0, sy - T.CHIP_H - 2)
    d.hint:SetHeight(G.HINT_H)
    d.hint:SetJustifyH("CENTER")
    d.hint:SetJustifyV("TOP")
    d.hint:SetText(d.model and L["Ziehen dreht · Mausrad zoomt · Rechtsklick: zurück"] or "")
    return d
end

-- Dresses the model for the mode: what is worn, or undressed with the targets (the worn item where
-- a slot has none). Only when what it wears changes.
local function dress(d, res, m)
    local model = d.model
    if not model then return end
    local links, key = {}, { m }
    for _, sl in ipairs(Gear.SLOTS) do
        local item = shownItem(res, sl.key, m)
        if item then
            local link = item.link or (item.id and K.linkOf(item.id))
            links[#links + 1] = link
            key[#key + 1] = tostring(link)
        end
    end
    local k = table.concat(key, "|")
    if d.dressed == k then return end
    d.dressed = k
    call(model, "SetUnit", "player")
    if m == "goals" then
        call(model, "Undress")
        for _, link in ipairs(links) do call(model, "TryOn", link) end
    end
end

---------------------------------------------------------------------------
-- The list in the middle: the slots by section
---------------------------------------------------------------------------

local function listItems(res)
    local out = {}
    for _, sec in ipairs(SECTIONS) do
        out[#out + 1] = { header = sec }
        for _, key in ipairs(sec.slots) do
            out[#out + 1] = { key = key, name = ns.BIS_SLOT_NAME[key], opt = res[key] and res[key][1], plan = res.plan,
                wornLink = wornLink(key) }
        end
    end
    return out
end

local function gainText(e)
    if e.worn or e.owned == "worn" then return GREEN .. L["angelegt"] .. "|r" end
    if e.switch then return L["Wechsel"] end
    if type(e.gain) ~= "number" then return "" end
    if type(e.mine) == "number" and e.mine > 0 then
        local pct = math.floor(e.gain / e.mine * 100 + 0.5)
        return (e.upgrade and GREEN or GREY) .. ("%+d %%"):format(pct) .. "|r"
    end
    return (e.upgrade and GREEN or GREY) .. ("%+d"):format(math.floor(e.gain + 0.5)) .. "|r"
end

local function badge(e)
    if e.own then return "|A:auctionhouse-icon-favorite:12:12|a " end
    if e.pick then return T.GOLD_TEXT .. "BiS|r " end
    return ""
end

local function fillRow(r, e)
    if e.header then
        r.head:SetText(e.header.label .. (e.count or ""))
        r.head:Show()
        for _, k in ipairs({ "slot", "name", "gain", "src" }) do r[k]:SetText("") end
        r.icon:Hide()
        K.setMapButton(r.map, nil)
        r.sel:Hide()
        r.bg:Hide()
        return
    end
    r.head:Hide()
    r.bg:Show()
    r.slot:SetText(e.name or "")
    local opt = e.opt
    if opt and opt.upgrade then r.slot:SetTextColor(1, 0.82, 0) else r.slot:SetTextColor(T.TEXT_FREE[1], T.TEXT_FREE[2], T.TEXT_FREE[3]) end
    if opt then
        r.icon:SetTexture(iconOf(opt.id) or QUESTION)
        r.icon:Show()
        r.name:SetText(badge(opt) .. K.itemText(opt.id))
        r.gain:SetText(gainText(opt))
        r.src:SetText(opt.owned and K.OWNED_TEXT[opt.owned] or (opt.unknown and L["unbekannt"]) or K.sourceText(opt.id, nil, opt.pick))
        K.setMapButton(r.map, opt.id, nil, opt.owned or opt.unknown)
    else
        r.icon:Hide()
        r.name:SetText(GREY .. ((e.key == "OFFHAND" and e.plan == "2H") and L["Zweihandwaffe geplant"] or L["keine Option"]) .. "|r")
        r.gain:SetText("")
        r.src:SetText("")
        K.setMapButton(r.map, nil)
    end
    if e.key == e.chosen then r.sel:Show() else r.sel:Hide() end
end

local function buildList(parent)
    local cols = {}
    for _, c in ipairs(G.COLS) do cols[c[1]] = c end
    local list = W.List(parent, G.ROWS, G.ROW_H, function(r)
        r.sel = W.SelectBar(r)
        r.slot = W.Text(r, T.FONT.head, cols.slot[3])
        r.slot:SetPoint("LEFT", cols.slot[2], 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(G.ICON, G.ICON)
        r.icon:SetPoint("LEFT", cols.icon[2], 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = W.Text(r, T.FONT.text, cols.name[3])
        r.name:SetPoint("LEFT", cols.name[2], 0)
        r.gain = W.Text(r, T.FONT.text, cols.gain[3])
        r.gain:SetPoint("LEFT", cols.gain[2], 0)
        r.gain:SetJustifyH("RIGHT")
        r.map = K.mapButton(r, cols.map[2])
        r.src = W.Text(r, T.FONT.text, cols.src[3])
        r.src:SetPoint("LEFT", cols.src[2], 0)
        -- a section's head: gold over the whole row
        r.head = W.Text(r, T.FONT.title, G.LIST_W - T.SCROLL_ROOM - 8)
        r.head:SetPoint("LEFT", 4, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e or e.header then return end
            if button == "RightButton" then
                if e.opt then W.Menu(self, K.menuEntries(e.opt, ns.BisOpts())) end
                return
            end
            if e.opt and K.modifiedClick(e.opt.id) then return end
            choose(e.key)
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.opt then K.itemTooltip(self, e.opt.id) end
        end)
        r:SetScript("OnLeave", K.hideTip)
    end, fillRow)
    list:SetPoint("TOPLEFT", G.LIST_X, -G.LIST_Y)
    list:SetWidth(G.LIST_W - T.SCROLL_ROOM)
    return list
end

---------------------------------------------------------------------------
-- The head row: the spec (one choice for page, window and dungeons), the weapon plan, Warum?
---------------------------------------------------------------------------

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

local function buildHead(f)
    f.spec = K.specPicker(f)
    f.plan = W.Text(f, T.FONT.text, 200)
    f.why = W.Button(f, L["Warum?"], 64, nil)
    W.FitChip(f.why, 64)
    f.why:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Warum diese Gewichte"])
        for _, line in ipairs(ns.BisWhy()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    f.why:SetScript("OnLeave", K.hideTip)
    W.Row(f, { f.spec, { f.plan, gap = T.LAYOUT.ITEM_GAP * 2, y = -(G.TOP + 4) } }, T.LAYOUT.ITEM_GAP, G.DOLL_X, -G.TOP)
    W.Row(f, { f.why }, 0, G.DOLL_X, -G.TOP, { right = true })
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local STATE_DOT = { done = "done", bag = "bag", bank = "bag" }

refresh = function()
    if not win or not win:IsShown() then return end
    local f = win
    local o = ns.BisOpts()
    local res = ns.BisTargets()
    local m = mode()
    local chosen = chosenSlot(res)
    K.fillSpec(f.spec, o)
    f.plan:SetText(planText(o, res))
    local d = f.doll
    for key, b in pairs(d.slots) do
        local st = STATE_DOT[res.state[key]]
        fillSlot(b, shownItem(res, key, m), key == chosen, st and G.STATE_COLOR[st])
    end
    d.goals:SetOn(m == "goals")
    d.worn:SetOn(m == "worn")
    dress(d, res, m)
    local items = listItems(res)
    for _, e in ipairs(items) do e.chosen = chosen end
    f.list:SetItems(items)
    if f.side and f.fillSide then f.fillSide(f, o, res, chosen) end
    if f.score and f.fillScore then f.fillScore(f, o, res) end
    if f.progress and f.fillProgress then f.fillProgress(f, o, res, items) end
end

---------------------------------------------------------------------------
-- The window: place, scale, open
---------------------------------------------------------------------------

local function place()
    if not win then return end
    win:ClearAllPoints()
    local st = winState()
    if type(st.point) == "string" and tonumber(st.x) and tonumber(st.y) then
        win:SetPoint(st.point, UIParent, st.point, tonumber(st.x), tonumber(st.y))
    else
        win:SetPoint("CENTER")
    end
end

local function savePlace(f)
    local st = winState()
    local point, _, _, x, y = f:GetPoint(1)
    if type(point) == "string" and tonumber(x) and tonumber(y) then
        st.point, st.x, st.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

function ns.ResetGoalsWindowPosition()
    local st = winState()
    st.point, st.x, st.y = nil, nil, nil
    place()
end

function ns.ApplyGoalScale(v)
    if win then win:SetScale((tonumber(v) or tonumber(ns.Get("ui.goalScale")) or 100) / 100) end
end

-- Ctrl + mouse wheel over the window: SCALE_STEP percent bigger or smaller, within the setting's
-- bounds, saved as the setting.
wheel = function(_, delta)
    if not (IsControlKeyDown and IsControlKeyDown()) or not tonumber(delta) or delta == 0 then return end
    local it = ns.SettingItem("ui.goalScale")
    if not it then return end
    local cur = tonumber(ns.Get("ui.goalScale")) or it.default
    local v = math.max(it.min, math.min(it.max, cur + (delta > 0 and 1 or -1) * G.SCALE_STEP))
    if v ~= cur then ns.Set("ui.goalScale", v) end
end

local function build()
    -- the main window's strata (FULLSCREEN): it stays open with the world map as the main window does
    win = W.Window("AmisiaGoalsFrame", G.W, G.H, { title = L["Ausrüstungsziele"], strata = "FULLSCREEN",
        background = "Profession-Background-Overview",
        onShow = function(self)
            if self.Raise then self:Raise() end
            refresh()
        end,
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end,
        onDragStop = savePlace })
    buildHead(win)
    win.doll = buildDoll(win)
    win.list = buildList(win)
    if ns.GoalsBuildParts then ns.GoalsBuildParts(win) end
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", wheel)
    place()
    ns.ApplyGoalScale()
    built = true
end

local function available()
    if Gear.Available() then return true end
    ns.msg(L["Für diesen Client gibt es keine Ausrüstungsdaten."])
    return false
end

function ns.ShowGoalsFrame()
    if not available() then return nil end
    if not win then build() end
    if win:IsShown() then refresh() else win:Show() end
    return win
end

function ns.ToggleGoalsFrame()
    if win and win:IsShown() then
        win:Hide()
        return nil
    end
    return ns.ShowGoalsFrame()
end

-- for the parts of the window and the tests
function ns.GoalsFrameState() return winState() end
ns.GoalsRefresh = function() refresh() end
ns.GOALS_SECTIONS = SECTIONS

-- What changes the targets, the own items or an item's name: show it while the window is open
-- (once for a burst of item answers).
local function changed() if built then refresh() end end
ns.Listen("BIS_CHANGED", changed)
ns.Listen("SETTING", changed)
ns.BisOnOwned(changed)
local namesDue = false
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if not built or not win:IsShown() or namesDue then return end
    namesDue = true
    C_Timer.After(0.3, function()
        namesDue = false
        if win and win:IsShown() then
            win.doll.dressed = nil
            refresh()
        end
    end)
end)
