-- The light over the map pin (F-206, D-132, AmisiaBeacon, tokens T.BEACON): while the client follows its
-- map pin (C_SuperTrack.IsSuperTrackingUserWaypoint: Amisia's target with the client's waypoint or the
-- player's own Ctrl + click), a golden column of light stands on the screen over the place, a glowing
-- ring at its foot and over it a small box with the name ("Kartenmarkierung" or the target's) and the
-- distance. It hangs at the client's navigation frame (C_Navigation.GetFrame), which the client keeps
-- over the place in the world, and hides while that place is not on the screen
-- (C_Navigation.HasValidScreenPosition) or the frame is held at the screen's edge
-- (C_Navigation.WasClampedToScreen). The client gives that place only as a point on the screen, with no
-- height over the ground (a pin from Ctrl + click carries no z), so the column is sized like a thing in
-- the world: shorter and thinner the farther the place (B.Layout, by C_Navigation.GetDistance), its
-- lowest part fading towards the ground, and the setting map.beaconDrop lowers its foot by so many yards
-- (more on the screen near than far) for where the client's point floats over the ground. A plain frame at the back (strata BACKGROUND), no mouse, no
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
local laid         -- the last layout ("height:drop"), so a frame without a change sets nothing

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

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Units on the screen one yard high at distance d (nil or not a number: T.BEACON.FAR; at least NEAR).
function B.PerYard(d)
    local S = T.BEACON
    if type(d) ~= "number" or d <= 0 then d = S.FAR end
    d = math.max(d, S.NEAR)
    local h = UIParent and UIParent:GetHeight() or 768
    return (h / 2) / math.tan(math.rad(S.FOV) / 2) / d
end

-- The column's height and how far its foot goes down under the client's point, at distance d.
function B.Size(d)
    local S = T.BEACON
    local px = B.PerYard(d)
    local drop = tonumber(ns.Get("map.beaconDrop")) or 0
    return clamp(S.BEAM_YD * px, S.BEAM_MIN, S.BEAM_MAX), math.max(0, drop) * px
end

-- Sizes and places the column for distance d: the foot drop under the client's point, the lowest part
-- fading towards the ground, widths and ring in proportion to the height.
function B.Layout(d)
    if not (f and nav) then return end
    local S = T.BEACON
    local h, drop = B.Size(d)
    local key = string.format("%.1f:%.1f", h, drop)
    if key == laid then return end
    laid = key
    local r = clamp(h / S.BEAM_H, S.THIN, S.WIDE)
    local foot = math.floor(h * S.FOOT + 0.5)
    f:SetSize(S.GLOW_W * r, h)
    f.glow:SetSize(S.GLOW_W * r, h - foot)
    f.glow:SetPoint("BOTTOM", f, "BOTTOM", 0, foot)
    f.glowFoot:SetSize(S.GLOW_W * r, foot)
    f.beam:SetSize(S.BEAM_W * r, h - foot)
    f.beam:SetPoint("BOTTOM", f, "BOTTOM", 0, foot)
    f.beamFoot:SetSize(S.BEAM_W * r, foot)
    f.ring:SetSize(S.RING_W * r, S.RING_H * r)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", nav, "CENTER", 0, -drop)
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
    -- the wide soft glow and the bright core of the column, both added to what is behind; each with a
    -- foot under it: the same texture upside down over part of its height (its light rising from
    -- FOOT_LOW at the ground to full where the column starts), sized by B.Layout
    local function part(layer, w, a, foot)
        local t = f:CreateTexture(nil, layer)
        t:SetTexture(BEAM_TEX)
        t:SetSize(w, S.BEAM_H)
        t:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
        t:SetBlendMode("ADD")
        t:SetVertexColor(S.COLOR[1], S.COLOR[2], S.COLOR[3], a)
        if foot then t:SetTexCoord(0, 1, 1, S.FOOT_LOW) end
        return t
    end
    f.glow = part("BACKGROUND", S.GLOW_W, S.GLOW_ALPHA)
    f.glowFoot = part("BACKGROUND", S.GLOW_W, S.GLOW_ALPHA, true)
    f.beam = part("ARTWORK", S.BEAM_W, 1)
    f.beamFoot = part("ARTWORK", S.BEAM_W, 1, true)
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
    -- every frame while shown: hidden at once when the place leaves the screen, the size with the
    -- distance; the text a few times a second
    f:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate MapBeacon", function(_, elapsed)
        local on = B.OnScreen()
        f:SetAlpha(on and 1 or 0)
        if on then B.Layout(ask(api("GetDistance"))) end
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
    -- the column's foot on the place (lowered by map.beaconDrop), sized by the distance
    laid = nil
    B.Layout(ask(api("GetDistance")))
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
    nav, acc, laid = nil, 0, nil
    reached, lastFollow, waiting = false, nil, false
    if f then f:Hide() end
end
end)
