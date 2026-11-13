-- The window "Raid-Notiz" (F-196, D-126, AmisiaRaidNote, tokens T.RAIDNOTE): a flat window with the
-- current raid note (Raid/RaidNote.lua's RN.Render), "von <Name>, <Uhrzeit>" under the title and the own
-- note under a line. Drag moves it, the grip at the bottom right sizes it, the lock at the top right fixes
-- both (locked, clicks go through it, only the lock and the close button take the mouse). No protected
-- frame: it opens, closes and scrolls in a fight; moving and sizing wait until after it. Escape does not
-- close it. Place and size in settings.raidNoteWindow = { point, x, y, w, h, locked }.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.RAIDNOTE
local RN = ns.RaidNote

local RW = {}
RN.Window = RW
local F

local LOCK_TEX = "Interface\\Buttons\\LockButton-Locked-Up"
local OPEN_TEX = "Interface\\Buttons\\LockButton-Unlocked-Up"

local function state()
    AmisiaDB.settings = AmisiaDB.settings or {}
    local st = AmisiaDB.settings.raidNoteWindow
    if type(st) ~= "table" then
        st = {}
        AmisiaDB.settings.raidNoteWindow = st
    end
    local w, h = tonumber(st.w), tonumber(st.h)
    st.w = (w and w >= S.MIN_W and w <= S.MAX_W) and math.floor(w) or nil
    st.h = (h and h >= S.MIN_H and h <= S.MAX_H) and math.floor(h) or nil
    st.locked = st.locked == true or nil
    return st
end

local function restyle()
    if not F then return end
    local a = (tonumber(ns.Get("raidnote.alpha")) or 70) / 100
    F.ground:SetColorTexture(0, 0, 0, a)
    local size = tonumber(ns.Get("raidnote.font")) or 12
    local base = _G.GameFontHighlight
    local font, _, flags
    if base and base.GetFont then font, _, flags = base:GetFont() end
    if font and F.note.fs.SetFont then F.note.fs:SetFont(font, size, flags) end
end
RW.Restyle = restyle

local function applyLock()
    local locked = state().locked
    F:EnableMouse(not locked)
    F.grip:SetShown(not locked)
    F.lock.icon:SetTexture(locked and LOCK_TEX or OPEN_TEX)
end

local function text()
    local c = RN.Current()
    local parts = {}
    if c then
        parts[1] = RN.Render(c.text)
    else
        parts[1] = "|cff8f86a3" .. L["Keine Raid-Notiz. Die Raidleitung schickt sie vor dem Pull."] .. "|r"
    end
    local own = RN.Own()
    if own ~= "" then
        parts[#parts + 1] = "\n|cff8f86a3" .. L["Eigene Notiz"] .. "|r\n" .. RN.Render(own)
    end
    return table.concat(parts, "\n")
end

local function refresh()
    if not F or not F:IsShown() then return end
    local c = RN.Current()
    F.from:SetText(c and L["von %s, %s"]:format(c.by, date("%H:%M", c.at)) or "")
    F.note:SetText(text())
end
RW.Refresh = refresh

local function place()
    local st = state()
    F:SetSize(st.w or S.W, st.h or S.H)
    W.PlaceWindow(F, st, "RIGHT", UIParent, "RIGHT", -S.EDGE_X, 0)
end

local function buildGrip()
    local g = CreateFrame("Button", nil, F)
    g:SetSize(S.GRIP, S.GRIP)
    g:SetPoint("BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(F:GetFrameLevel() + 10)
    g:SetNormalTexture(T.RUNTIMER.GRIP_TEX .. "Up")
    g:SetPushedTexture(T.RUNTIMER.GRIP_TEX .. "Down")
    g:SetHighlightTexture(T.RUNTIMER.GRIP_TEX .. "Highlight")
    local sx, sy, sw, sh
    local function cursor()
        local x, y = GetCursorPosition()
        local scale = F:GetEffectiveScale()
        scale = scale > 0 and scale or 1
        return (x or 0) / scale, (y or 0) / scale
    end
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() or state().locked then return end
        local left, top = F:GetLeft(), F:GetTop()
        if left and top then
            F:ClearAllPoints()
            F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        sx, sy = cursor()
        sw, sh = F:GetWidth(), F:GetHeight()
        self:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate RaidNote resize", function()
            local x, y = cursor()
            local w = math.max(S.MIN_W, math.min(S.MAX_W, sw + (x - sx)))
            local h = math.max(S.MIN_H, math.min(S.MAX_H, sh + (sy - y)))
            F:SetSize(w, h)
        end))
    end)
    local function stop(self)
        if not sx then return end
        self:SetScript("OnUpdate", nil)
        sx, sy = nil, nil
        local st = state()
        st.w, st.h = math.floor(F:GetWidth() + 0.5), math.floor(F:GetHeight() + 0.5)
        -- saved as TOPLEFT on UIParent's TOPLEFT (W.PlaceWindow puts point on the same point)
        local left, top = F:GetLeft(), F:GetTop()
        if left and top then
            F:ClearAllPoints()
            F:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - (UIParent:GetHeight() or 0))
        end
        W.SaveWindowPlace(F, st)
        refresh()
    end
    g:SetScript("OnMouseUp", stop)
    -- hidden in the middle of a drag (Alt+Z, /amisia notiz): the drag ends there
    g:SetScript("OnHide", stop)
    W.Tooltip(g, L["Größe ändern"], L["Ziehen ändert die Größe des Fensters."])
    return g
end

local function build()
    if F then return F end
    F = W.Window("AmisiaRaidNote", S.W, S.H, { flat = true, title = L["Raid-Notiz"], strata = "MEDIUM", escape = false,
        bg = { 0, 0, 0, 0.7 }, onShow = refresh,
        onDragStop = function(f) W.SaveWindowPlace(f, state()) end })
    F:SetResizable(true)
    -- moving waits until after a fight (the window is no protected frame, but a drag in a fight is
    -- a click too many)
    F:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or state().locked then return end
        self:StartMoving()
    end)
    F.from = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.from:SetPoint("TOPLEFT", S.PAD, -S.TOP)
    F.from:SetPoint("TOPRIGHT", -S.PAD, -S.TOP)
    F.note = W.ScrollText(F)
    F.note:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.FROM_H))
    F.note:SetPoint("BOTTOMRIGHT", -(S.PAD + S.BAR), S.PAD + S.GRIP / 2)
    -- the text wraps anew once the size is final (not on every step of a drag)
    F.note:HookScript("OnSizeChanged", function() if not F.grip or not F.grip:GetScript("OnUpdate") then refresh() end end)
    F.lock = W.IconButton(F, S.LOCK, { file = OPEN_TEX }, function()
        if InCombatLockdown() then return end
        local st = state()
        st.locked = not st.locked or nil
        applyLock()
    end, "L")
    F.lock:SetPoint("RIGHT", F.CloseButton, "LEFT", -S.LOCK_GAP, 0)
    W.Tooltip(F.lock, L["Sperren"], L["Sperrt Stelle und Größe; gesperrt gehen Mausklicks durch das Fenster. Nicht im Kampf."])
    F.grip = buildGrip()
    restyle()
    place()
    applyLock()
    return F
end

function RW.Show()
    build()
    F:Show()
    refresh()
end

function RW.Hide() if F then F:Hide() end end
function RW.Shown() return F ~= nil and F:IsShown() end
function RW.Toggle()
    if RW.Shown() then RW.Hide() else RW.Show() end
end

-- "Fensterposition zurücksetzen" and the settings' own button: place, size and lock back.
function ns.ResetRaidNotePosition()
    if AmisiaDB and AmisiaDB.settings then AmisiaDB.settings.raidNoteWindow = nil end
    if F and not InCombatLockdown() then
        place()
        applyLock()
        refresh()
    end
end

ns.Listen("RAIDNOTE", refresh)
ns.OnEvent("GROUP_ROSTER_UPDATE", function() if RW.Shown() then refresh() end end)
