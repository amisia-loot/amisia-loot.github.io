-- An item that starts a quest (F-181, D-113, spec docs/specs/2026-11-11-quest-start-item.md; window
-- AmisiaQuestStart, tokens T.QUESTSTART): when such an item lands in the bags (looted, traded, mailed,
-- bought: the bags 0 to 4 count) and its quest is neither in the log nor completed, a small window shows
-- the item's name as its title, its icon in Amisia's rounded ring with the quest giver's "!" at the corner
-- and one line: a click on the icon starts the quest.
--
-- Which item starts a quest: the client's quest mark of the bag slot (C_Container.GetContainerItemQuestInfo;
-- Forever has no global bag functions, none is looked up): its questID, and isActive for "in the log". When the
-- client answers for a slot, its answer counts (no quest id: no start item). Only when the client gives
-- nothing (no function, an error, no answer) Amisia's own data decides: kind S of Data/QuestItemData.lua
-- (the client table ItemSparse) and the start items of Data/DungeonQuestData.lua (field 15: quests without
-- a giver). Never the item's name or its tooltip. The quest's state is Gear/QuestItems.lua's
-- (QI.QuestState: in the log, completed by the client's flag once it answered the quest log, not for this
-- character by the quest data); only "away" (neither) shows.
--
-- The click: a SecureActionButtonTemplate button (type "item", item "item:<id>": the client uses the item
-- wherever it lies, never a bag slot that may hold something else by now) lies over the icon. Using an item
-- is protected, and a window holding a protected button is protected itself: in combat it can be neither
-- shown, hidden nor moved, and the button's attributes cannot change. So Amisia never shows, hides, moves
-- or fills the window in combat (InCombatLockdown): a new item waits in the queue until PLAYER_REGEN_ENABLED;
-- a window already open stays as it is (its click still works), and what would close or change it (the X,
-- the quest accepted, the item gone) only changes its line ("Schließt nach dem Kampf.") until combat ends.
-- Escape does not close it (UISpecialFrames would hide a protected frame from a tainted path); the X does.
-- Without the template, or once the client refused the use for Amisia (ADDON_ACTION_FORBIDDEN/_BLOCKED),
-- the window only informs: "Rechtsklick auf den Gegenstand in der Tasche ..." with bag and slot.
--
-- When: never while the chat lockdown or a boss encounter is on (also not opened then; it waits). After a
-- login or /reload, LOGIN_DELAY seconds later and once the client answered the quest log, the start items
-- already in the bags show once, at most LOGIN_MAX of them; every later arrival shows. One window, a queue
-- (the title counts "1 von 2"); an item shown or closed is not shown again this session, however often the
-- bags change; it comes back after the next login or /reload while the quest is still open. The window
-- closes by itself when the quest is accepted (QUEST_ACCEPTED, the log) or the item leaves the bags (not
-- while it is only on the cursor). The bags are read after BAG_UPDATE_DELAYED, at most every THROTTLE
-- seconds, never per frame. Setting quests.startPopup (on); its place in settings.questStartWindow.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.QUESTSTART
local QI = ns.QuestItems

local QS = {}
ns.QuestStart = QS

local MAX_ID = 9999999
local LOGIN_DELAY = 5    -- seconds after a login or /reload before the bags are read the first time
local LOGIN_MAX = 3      -- start items already in the bags at login shown at most
local MAX_QUEUE = 10     -- items waiting at most
local THROTTLE = 0.5     -- seconds between two reads of the bags
local LATE = 1           -- a refusal this many seconds after a click on the icon counts for it
QS.LOGIN_DELAY, QS.LOGIN_MAX, QS.MAX_QUEUE, QS.THROTTLE = LOGIN_DELAY, LOGIN_MAX, MAX_QUEUE, THROTTLE

local int = ns.Int
local report = ns.ReportError
local function plain(v) return ns.Plain(v) end

local TEXT = {
    click = L["Klick auf das Symbol startet die Quest."],
    inform = L["Rechtsklick auf den Gegenstand in der Tasche startet die Quest (Tasche %d, Platz %d)."],
    later = L["Schließt nach dem Kampf."],
    count = L["%s (%d von %d)"],
    starts = L["Startet die Quest: %s"],
    tipClick = L["Klick: Gegenstand benutzen, die Quest öffnet sich."],
    refused = L["Das Spiel lässt Amisia den Gegenstand nicht benutzen: Rechtsklick auf ihn in der Tasche startet die Quest."],
}

local queue = {}         -- { { id, q, link } }: the items waiting, the first is shown
local seen = {}          -- [item id] = true: queued or shown this session (not shown again)
local due = false        -- something waits for the end of combat, the lockdown or the client's answer
local loginReady = false -- LOGIN_DELAY passed since the login or /reload
local loginDone = false  -- the first read of the bags (the login's, at most LOGIN_MAX) happened
local scheduled = false
local encounter = false
local refused = false    -- the client refused the use for Amisia this session
local clickedAt          -- GetTime() of the last click on the icon
local F, B               -- the window and its secure button (B nil: the window only informs)

QS.queue, QS.seen = queue, seen

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function enabled() return ns.Get("quests.startPopup") ~= false end

local function inCombat() return type(InCombatLockdown) == "function" and plain(InCombatLockdown()) == true end

-- Whether a new window may open: not in combat, the chat lockdown or a boss encounter.
local function quiet()
    if inCombat() then return false end
    if ns.ChatLocked and ns.ChatLocked() then return false end
    if encounter or (ns.AddOnRestricted and ns.AddOnRestricted(1)) then return false end
    return true
end
QS.Quiet = quiet

---------------------------------------------------------------------------
-- Which item starts which quest
---------------------------------------------------------------------------

-- The client's quest mark of a bag slot: answered (true when the client said anything for the slot), the
-- quest the item starts (or nil), whether that quest is in the log.
local function clientMark(bag, slot)
    local api = _G.C_Container
    local fn = api and api.GetContainerItemQuestInfo
    if type(fn) == "function" then
        local info = call(fn, bag, slot)
        if type(info) == "table" then
            local q = tonumber(plain(info.questID))
            return true, int(q, 1, MAX_ID) and q or nil, plain(info.isActive) == true
        end
    end
    return false, nil, false
end

-- The start items of the dungeon quest data (field 15 of a quest without a giver): [item] = quest, built
-- once when first asked.
local dqIndex, dqOf
local function dungeonStarts()
    local dq = ns.Data and ns.Data("DUNGEON_QUESTS") or ns.DUNGEON_QUESTS
    if dqIndex and dqOf == dq then return dqIndex end
    dqIndex, dqOf = {}, dq
    for q, r in pairs(type(dq) == "table" and type(dq.Q) == "table" and dq.Q or {}) do
        if type(r) == "table" and type(r[15]) == "table" then
            for _, e in ipairs(r[15]) do
                local id = type(e) == "table" and e[1]
                if int(id, 1, MAX_ID) and not dqIndex[id] then dqIndex[id] = q end
            end
        end
    end
    return dqIndex
end

-- The quest item id starts by Amisia's own data, or nil: kind S of QuestItemData, else the dungeon data.
function QS.DataStart(id)
    local data = ns.Data and ns.Data("QUEST_ITEMS")
    local s = type(data) == "table" and type(data.I) == "table" and data.I[id]
    if type(s) == "string" then
        local q = tonumber(s:match("S(%d+)"))
        if int(q, 1, MAX_ID) then return q end
    end
    local q = dungeonStarts()[id]
    return int(q, 1, MAX_ID) and q or nil
end

-- The start items in the bags: a list of { id, q, bag, slot, link, active, src = "client"/"data" }, one per
-- item id (its first stack).
function QS.BagStarts()
    local out, have = {}, {}
    local api = _G.C_Container
    for bag, slot, id in QI.EachSlot() do
        if int(id, 1, MAX_ID) and not have[id] then
            local answered, q, active = clientMark(bag, slot)
            local src = "client"
            if not answered then q, active, src = QS.DataStart(id), false, "data" end
            if q then
                have[id] = true
                local link = plain(call(api and api.GetContainerItemLink, bag, slot))
                out[#out + 1] = { id = id, q = q, bag = bag, slot = slot, active = active, src = src,
                    link = type(link) == "string" and link or nil }
            end
        end
    end
    return out
end

-- Whether start item e (QS.BagStarts' entry) shows: its quest neither in the log nor completed nor
-- one the data says is not for this character.
local function open(e)
    if e.active then return false end
    return QI.QuestState(e.q) == "away"
end
QS.Open = open

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function windowState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.questStartWindow) ~= "table" then AmisiaDB.settings.questStartWindow = {} end
    return AmisiaDB.settings.questStartWindow
end

local function place()
    -- a protected window cannot move in combat: the reset waits for the next showing
    if F and not inCombat() then W.PlaceWindow(F, windowState(), "CENTER", UIParent, "CENTER", 0, 160) end
end

function ns.ResetQuestStartPosition()
    local st = windowState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

local function nameOf(e)
    local name = ns.ItemName(e.id)
    if name:match("^Item %d+$") and e.link then name = e.link:match("%[(.-)%]") or name end
    return name
end

local function iconOf(id)
    local api = _G.C_Item
    local icon = plain(call(api and api.GetItemIconByID, id))
    if not icon then icon = plain(call(_G.GetItemIcon, id)) end
    return icon or 134400
end

local function qualityOf(e)
    local api = _G.C_Item
    local q = tonumber(plain(call(api and api.GetItemQualityByID, e.id)))
    if not q then q = tonumber(plain(select(3, call(api and api.GetItemInfo, e.link or e.id)))) end
    return T.QUALITY_RGB[q or 1] or T.QUALITY_RGB[1]
end

-- Where item id lies now (its first stack), for the tooltip and the informing line.
local function whereNow(id)
    for bag, slot, x in QI.EachSlot() do
        if x == id then return bag, slot end
    end
    return nil
end

local function showTip(owner)
    local e = F and F.entry
    if not e then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local bag, slot = whereNow(e.id)
    if bag and GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(bag, slot)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(e.id)
    else
        GameTooltip:SetHyperlink("item:" .. e.id)
    end
    GameTooltip:AddLine(TEXT.starts:format(QI.QuestName(e.q)), 1, 0.82, 0, true)
    if B and not refused then GameTooltip:AddLine(TEXT.tipClick, 0.31, 0.82, 0.42, true) end
    GameTooltip:Show()
end

local function hideTip() GameTooltip:Hide() end

-- The secure button over the icon (nil when the client has no SecureActionButtonTemplate). Only its
-- PreClick, OnEnter and OnLeave are Amisia's: its OnClick stays the template's.
local function buildButton(parent)
    local ok, b = pcall(CreateFrame, "Button", "AmisiaQuestStartButton", parent, "SecureActionButtonTemplate")
    if not ok or not b or type(b.SetAttribute) ~= "function" then return nil end
    b:SetAllPoints(parent.slot)
    if b.SetFrameLevel and parent.slot.GetFrameLevel then b:SetFrameLevel(parent.slot:GetFrameLevel() + 3) end
    -- the client's action buttons act on the key's down press when the setting says so; the template does
    -- the same for a click registered both ways, an older one acts on what is registered
    local cvar = _G.C_CVar
    local down = plain(call(cvar and cvar.GetCVarBool, "ActionButtonUseKeyDown"))
    if down == nil then down = plain(call(_G.GetCVarBool, "ActionButtonUseKeyDown")) end
    b:RegisterForClicks(down == true and "LeftButtonDown" or "LeftButtonUp")
    b:SetAttribute("type", "item")
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetTexture(T.PLANNER.DOLL.SLOT_MASK)
    b.hl:SetVertexColor(1, 1, 1, 0.15)
    b:SetScript("PreClick", function() clickedAt = GetTime() end)
    b:SetScript("OnEnter", showTip)
    b:SetScript("OnLeave", hideTip)
    return b
end

local function build()
    if F then return F end
    F = W.Window("AmisiaQuestStart", S.W, S.TOP + S.ICON + S.GAP + S.LINE_H + S.BOTTOM, { title = "", strata = "MEDIUM",
        escape = false, onDragStop = function(f) W.SaveWindowPlace(f, windowState()) end })
    -- a protected window cannot be moved in combat
    F:SetScript("OnDragStart", function(self) if not inCombat() then self:StartMoving() end end)
    F.CloseButton:SetScript("OnClick", function() QS.Dismiss() end)
    local slot = CreateFrame("Frame", nil, F)
    slot:SetSize(S.ICON, S.ICON)
    slot:SetPoint("TOP", F, "TOP", 0, -S.TOP)
    slot.bg = slot:CreateTexture(nil, "BACKGROUND")
    slot.bg:SetAllPoints()
    slot.bg:SetTexture(T.PLANNER.DOLL.SLOT_MASK)
    slot.bg:SetVertexColor(0, 0, 0, 0.6)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if ns.GoalsKit and ns.GoalsKit.roundIcon then ns.GoalsKit.roundIcon(slot, T.PLANNER.DOLL, slot.icon) end
    slot:EnableMouse(true)
    slot:SetScript("OnEnter", showTip)
    slot:SetScript("OnLeave", hideTip)
    F.slot = slot
    -- the quest giver's "!" at the icon's lower right corner, on a frame above the ring
    F.markFrame = CreateFrame("Frame", nil, F)
    F.markFrame:SetSize(S.MARK, S.MARK)
    F.markFrame:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", S.MARK_X - S.MARK, -S.MARK_Y)
    if F.markFrame.SetFrameLevel and slot.GetFrameLevel then F.markFrame:SetFrameLevel(slot:GetFrameLevel() + 2) end
    F.mark = F.markFrame:CreateTexture(nil, "OVERLAY")
    F.mark:SetAllPoints()
    F.mark:SetTexture(S.MARK_ART)
    F.hint = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD, true)
    F.hint:SetPoint("TOP", slot, "BOTTOM", 0, -S.GAP)
    F.hint:SetJustifyH("CENTER")
    B = buildButton(F)
    F.button = B
    place()
    return F
end
QS.Build = build

local function setHint(text)
    F.hint:SetText(text)
    local h = math.max(S.LINE_H, math.ceil(tonumber(F.hint:GetStringHeight()) or S.LINE_H))
    return h
end

-- Fills the window with entry e: only out of combat (the button's attribute).
local function fill(e)
    F.entry, F.count, F.informs = e, #queue, refused or not B
    local n = #queue
    local name = nameOf(e)
    F:SetTitle(n > 1 and TEXT.count:format(name, 1, n) or name)
    F.slot.icon:SetTexture(iconOf(e.id))
    local c = qualityOf(e)
    if F.slot.ring then
        F.slot.ringColor = { c[1], c[2], c[3], 1 }
        F.slot.ring:SetVertexColor(c[1], c[2], c[3], 1)
    end
    local h
    if B and not refused then
        B:SetAttribute("item", "item:" .. e.id)
        B:Show()
        h = setHint(TEXT.click)
    else
        if B then B:Hide() end
        local bag, slot = whereNow(e.id)
        h = setHint(TEXT.inform:format((bag or e.bag or 0) + 1, slot or e.slot or 0))
    end
    F:SetHeight(S.TOP + S.ICON + S.GAP + h + S.BOTTOM)
end

-- Shows the first entry of the queue, or hides the window when none waits. In combat nothing of the window
-- changes but its line: what is due happens at PLAYER_REGEN_ENABLED.
local function update()
    local cur = queue[1]
    local shown = F and F:IsShown()
    if inCombat() then
        if shown and F.entry ~= cur then F.hint:SetText(TEXT.later) end
        if cur or shown then due = true end
        return
    end
    if not cur then
        if shown then F:Hide() end
        if F then F.entry = nil end
        return
    end
    if shown then
        if F.entry ~= cur or F.count ~= #queue or F.informs ~= (refused or not B) then fill(cur) end
        return
    end
    if not quiet() then
        due = true
        return
    end
    build()
    fill(cur)
    F:Show()
    if F.Raise then F:Raise() end
end
QS.Update = update

-- The X: the item shown is done for this session (it stays seen), the next one shows.
function QS.Dismiss()
    local e = F and F.entry
    if e then
        for i, x in ipairs(queue) do
            if x == e then table.remove(queue, i) break end
        end
    end
    update()
end

function QS.Shown() return F ~= nil and F:IsShown() end
function QS.Current() return F and F:IsShown() and F.entry or nil end
function QS.Refused() return refused end

---------------------------------------------------------------------------
-- Reading the bags
---------------------------------------------------------------------------

-- The item on the cursor (a stack being moved still counts as in the bags).
local function cursorItem()
    local kind, id = call(_G.GetCursorInfo)
    if plain(kind) ~= "item" then return nil end
    return tonumber(plain(id))
end

-- One read of the bags: drops queued items that left the bags or whose quest is in the log or completed,
-- queues new start items of open quests (the first read after a login at most LOGIN_MAX). Returns the
-- number queued.
function QS.Pass()
    if not enabled() or not loginReady then return 0 end
    -- in combat, the lockdown or an encounter the bags are not read (values may be secret: an item would
    -- look gone); what arrived meanwhile is read at the end
    if not quiet() or not QI.Ready() then
        due = true
        return 0
    end
    due = false
    local list = QS.BagStarts()
    local byId = {}
    for _, e in ipairs(list) do byId[e.id] = e end
    local held = cursorItem()
    for i = #queue, 1, -1 do
        local x = queue[i]
        local now = byId[x.id]
        if (not now and x.id ~= held) or (now and not open(now)) or (not now and QI.QuestState(x.q) ~= "away") then
            table.remove(queue, i)
        end
    end
    local added = 0
    for _, e in ipairs(list) do
        if not seen[e.id] and open(e) then
            seen[e.id] = true
            if #queue < MAX_QUEUE and (loginDone or added < LOGIN_MAX) then
                queue[#queue + 1] = { id = e.id, q = e.q, link = e.link, bag = e.bag, slot = e.slot }
                added = added + 1
            end
        end
    end
    loginDone = true
    update()
    return added
end

local function soon()
    if scheduled then return end
    scheduled = true
    C_Timer.After(THROTTLE, function()
        scheduled = false
        local ok, err = pcall(QS.Pass)
        if not ok then report(err) end
    end)
end
QS.Soon = soon

-- The quest of a queued item was accepted: it leaves the queue (the window follows, after combat).
-- The quest id is the event's last value (the classic clients send the log index first).
local function accepted(...)
    local n = select("#", ...)
    local q = n > 0 and tonumber(plain((select(n, ...)))) or nil
    if not q then return end
    local hit = false
    for i = #queue, 1, -1 do
        if queue[i].q == q then
            table.remove(queue, i)
            hit = true
        end
    end
    if hit then update() end
end

-- The setting: off closes the window and empties the queue; on reads the bags as after a login.
function QS.SettingChanged(on)
    if on then
        loginDone = false
        soon()
    else
        for i = #queue, 1, -1 do queue[i] = nil end
        update()
    end
end

-- A refusal of the client for Amisia just after a click on the icon: the window only informs this session.
local function onRefused(who, what)
    if plain(who) ~= ADDON or refused then return end
    what = plain(what)
    local named = type(what) == "string" and (what:find("UseItemByName", 1, true) or what:find("UseContainerItem", 1, true)
        or what:find("SecureCmdUseItem", 1, true))
    if named or (clickedAt and GetTime() - clickedAt <= LATE) then
        refused = true
        ns.msg(TEXT.refused)
        update()
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then report(err) end
    end
end

local entered = false
ns.OnEvent("PLAYER_ENTERING_WORLD", safe(function()
    encounter = false
    if entered then return end
    -- the first world of this session (a login or a /reload): the bags once, a few seconds later
    entered = true
    C_Timer.After(LOGIN_DELAY, function()
        loginReady = true
        soon()
    end)
end))
ns.OnEvent("BAG_UPDATE_DELAYED", safe(function() if enabled() then soon() end end))
ns.OnEvent("QUEST_ACCEPTED", safe(accepted))
ns.OnEvent("QUEST_LOG_UPDATE", safe(function()
    if enabled() and (due or #queue > 0 or (loginReady and not loginDone)) then soon() end
end))
ns.OnEvent("ENCOUNTER_START", safe(function() encounter = true end))
local function resume()
    if due or #queue > 0 then soon() end
end
ns.OnEvent("ENCOUNTER_END", safe(function()
    encounter = false
    resume()
end))
ns.OnEvent("PLAYER_REGEN_ENABLED", safe(resume))
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", safe(resume))
ns.OnEvent("ADDON_ACTION_FORBIDDEN", onRefused)
ns.OnEvent("ADDON_ACTION_BLOCKED", onRefused)
