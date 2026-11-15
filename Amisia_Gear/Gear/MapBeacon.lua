-- The light over the map pin (F-206, D-132, AmisiaBeacon, tokens T.BEACON): while the client follows its
-- map pin (C_SuperTrack.IsSuperTrackingUserWaypoint: Amisia's target with the client's waypoint or the
-- player's own Ctrl + click), a golden column of light stands on the screen over the place, a glowing
-- ring at its foot and over it a small box with the name ("Kartenmarkierung" or the target's) and the
-- distance. It hangs at the client's navigation frame (C_Navigation.GetFrame), which the client keeps
-- over the place in the world, and hides while that place is not on the screen
-- (C_Navigation.HasValidScreenPosition) or the frame is held at the screen's edge
-- (C_Navigation.WasClampedToScreen). A plain frame at the back (strata BACKGROUND), no mouse, no
-- protected call; built the first time it shows. The setting map.beacon (Karte, on) switches it.
-- The client only has a navigation frame while it follows the pin, and Forever's world map places a pin
-- with Ctrl + click without following it (SetSuperTrackedUserWaypoint(false)); its own navigation
-- frame also stops all following (ClearAllSuperTracked) whenever the place goes to or comes from the
-- screen's edge. So while map.beacon is on and a pin exists, Amisia follows it itself (B.Follow): a
-- new pin a moment after it is placed, and again after the client's ClearAllSuperTracked (at most every
-- T.BEACON.REFOLLOW seconds). It sets no waypoint; it leaves the pin unfollowed when the player clicks
-- the pin to stop following it, and once the client says the place is reached
-- (NAVIGATION_DESTINATION_REACHED) until a new pin is placed (D-132, Nachtrag 2026-11-15).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme

local B = {}
ns.MapBeacon = B

local BEAM_TEX = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\beacon_beam"
local RING_TEX = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\beacon_ring"

local f            -- the frame, made the first time it shows
local nav          -- the client's navigation frame while there is one
local acc = 0      -- time since the last distance text

local function api(name)
    local N = _G.C_Navigation
    return N and type(N[name]) == "function" and N[name] or nil
end

-- The client's call fn as a plain value (nil when it fails or answers a secret one).
local function ask(fn)
    if not fn then return nil end
    local ok, v = pcall(fn)
    if not ok then return nil end
    return ns.Plain(v)
end

-- Whether the client follows its map pin now.
local function tracking()
    local S = _G.C_SuperTrack
    if not (S and type(S.IsSuperTrackingUserWaypoint) == "function") then return false end
    return ask(S.IsSuperTrackingUserWaypoint) == true
end

-- Whether the light should show at all: the setting, the client's pin followed, a navigation frame.
function B.Wanted()
    if not ns.Get("map.beacon") then return false end
    if not tracking() then return false end
    local get = api("GetFrame")
    local fr = get and select(2, pcall(get)) or nil
    nav = type(fr) == "table" and fr or nil
    return nav ~= nil
end

-- Whether the place stands on the screen: a valid position, not held at the edge.
function B.OnScreen()
    if ask(api("HasValidScreenPosition")) == false then return false end
    if ask(api("WasClampedToScreen")) == true then return false end
    return true
end

-- The name over the light: Amisia's target while the client's pin is its own, else "Kartenmarkierung".
function B.Label()
    local t = ns.MapTarget and ns.MapTarget()
    if t and t.ours and type(t.label) == "string" and t.label ~= "" then return t.label end
    return L["Kartenmarkierung"]
end

-- The distance as text ("86 m", in English yards), or "" when the client gives none.
function B.DistanceText()
    local d = ask(api("GetDistance"))
    if type(d) ~= "number" or d < 0 then return "" end
    return ns.Map.DistText(d)
end

local function fill()
    f.name:SetText(B.Label())
    f.dist:SetText(B.DistanceText())
    local S = T.BEACON
    local w = math.max(f.name:GetStringWidth() or 0, f.dist:GetStringWidth() or 0)
    f.box:SetWidth(math.min(S.BOX_MAX, math.max(S.BOX_MIN, w + 2 * S.PAD)))
end

local function build()
    if f then return f end
    local S = T.BEACON
    f = CreateFrame("Frame", "AmisiaBeacon", UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:SetSize(S.GLOW_W, S.BEAM_H)
    f:EnableMouse(false)
    -- the wide soft glow and the bright core of the column, both added to what is behind
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetTexture(BEAM_TEX)
    f.glow:SetSize(S.GLOW_W, S.BEAM_H)
    f.glow:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.glow:SetBlendMode("ADD")
    f.glow:SetVertexColor(S.COLOR[1], S.COLOR[2], S.COLOR[3], S.GLOW_ALPHA)
    f.beam = f:CreateTexture(nil, "ARTWORK")
    f.beam:SetTexture(BEAM_TEX)
    f.beam:SetSize(S.BEAM_W, S.BEAM_H)
    f.beam:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.beam:SetBlendMode("ADD")
    f.beam:SetVertexColor(S.COLOR[1], S.COLOR[2], S.COLOR[3], 1)
    -- the ring on the ground, squashed into an ellipse, its middle at the foot
    f.ring = f:CreateTexture(nil, "ARTWORK")
    f.ring:SetTexture(RING_TEX)
    f.ring:SetSize(S.RING_W, S.RING_H)
    f.ring:SetPoint("CENTER", f, "BOTTOM", 0, 0)
    f.ring:SetBlendMode("ADD")
    f.ring:SetVertexColor(S.COLOR[1], S.COLOR[2], S.COLOR[3], 1)
    -- the box over the column: the name, the distance in gold under it
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(S.BOX_MIN, S.BOX_H)
    box:SetPoint("BOTTOM", f, "TOP", 0, S.BOX_GAP)
    box:EnableMouse(false)
    W.Flat(box, 0, 0, 0, S.SHADE)
    W.Border(box, T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.6)
    f.box = box
    f.name = W.Text(box, T.FONT.body, S.BOX_MAX - 2 * S.PAD)
    f.name:SetPoint("TOP", box, "TOP", 0, -S.PAD_Y)
    f.name:SetJustifyH("CENTER")
    f.dist = W.Text(box, T.FONT.title, S.BOX_MAX - 2 * S.PAD)
    f.dist:SetPoint("BOTTOM", box, "BOTTOM", 0, S.PAD_Y)
    f.dist:SetJustifyH("CENTER")
    f:SetAlpha(0)
    -- every frame while shown: hidden at once when the place leaves the screen; the text a few
    -- times a second
    f:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate MapBeacon", function(_, elapsed)
        f:SetAlpha(B.OnScreen() and 1 or 0)
        acc = acc + (elapsed or 0)
        if acc >= S.TICK then
            acc = 0
            fill()
        end
    end))
    f:Hide()
    return f
end

-- Shows or hides the light after a change of the pin, the following or the setting.
function B.Update()
    if not B.Wanted() then
        nav = nil
        if f then f:Hide() end
        return
    end
    build()
    f:ClearAllPoints()
    -- the column's foot on the place
    f:SetPoint("BOTTOM", nav, "CENTER", 0, 0)
    acc = 0
    fill()
    f:SetAlpha(B.OnScreen() and 1 or 0)
    f:Show()
end

function B.Shown() return f ~= nil and f:IsShown() and f:GetAlpha() > 0 end

-- Following the pin (see the head): reached = the client said the place is reached (no following
-- until a new pin), lastFollow = when Amisia last followed it, waiting = a follow is planned.
local reached, lastFollow, waiting = false, nil, false

local function hasPin()
    local M = _G.C_Map
    return M and type(M.HasUserWaypoint) == "function" and ask(M.HasUserWaypoint) == true or false
end

-- Follows the client's pin when the light wants it and nothing else holds it back; true when it did.
function B.Follow()
    if not ns.Get("map.beacon") or reached then return false end
    local S = _G.C_SuperTrack
    if not (S and type(S.SetSuperTrackedUserWaypoint) == "function") then return false end
    if not hasPin() or tracking() then return false end
    local now = GetTime()
    if lastFollow and now - lastFollow < T.BEACON.REFOLLOW then
        -- just now: once more when the pause is over
        if not waiting then
            waiting = true
            C_Timer.After(T.BEACON.REFOLLOW - (now - lastFollow), function()
                waiting = false
                if B.Follow() then B.Update() end
            end)
        end
        return false
    end
    lastFollow = now
    pcall(S.SetSuperTrackedUserWaypoint, true)
    return true
end

-- A moment later: after the client's own call that placed the pin unfollowed or stopped following.
local function followSoon()
    C_Timer.After(0, function()
        B.Follow()
        B.Update()
    end)
end

for _, e in ipairs({ "NAVIGATION_FRAME_CREATED", "NAVIGATION_FRAME_DESTROYED", "SUPER_TRACKING_CHANGED" }) do
    ns.OnEvent(e, function() B.Update() end)
end
ns.OnEvent("USER_WAYPOINT_UPDATED", function()
    -- a new pin (or none): following it is allowed again
    reached = false
    B.Update()
    followSoon()
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    B.Update()
    followSoon()
end)
ns.OnEvent("NAVIGATION_DESTINATION_REACHED", function() reached = true end)
if _G.C_SuperTrack and type(_G.C_SuperTrack.ClearAllSuperTracked) == "function" and hooksecurefunc then
    hooksecurefunc(_G.C_SuperTrack, "ClearAllSuperTracked", function() followSoon() end)
end
ns.Listen("MAP_TARGET", function() if f and f:IsShown() then fill() end end)

-- for the tests
function B._reset()
    nav, acc = nil, 0
    reached, lastFollow, waiting = false, nil, false
    if f then f:Hide() end
end
end)
