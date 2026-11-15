-- The light over the map pin (Gear/MapBeacon.lua; F-206, D-132): it shows while the client follows its
-- map pin and has a navigation frame, its foot on that frame; the name (the client's pin or Amisia's
-- target) and the distance; hidden while the place is off the screen or held at its edge; gone when the
-- pin goes or the following ends; the setting map.beacon; it sets nothing and takes no mouse.
local B, Map = NS.MapBeacon, NS.Map
local T = NS.Theme
local function near(a, b) return math.abs(a - b) < 1e-9 end

STUB.instance = { type = "none" }
STUB.maps[1411] = { name = "Durotar", world = { 1, 0, 0, 1000, 1000 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = {} }
Map._reset()
local wp, nav = STUB.waypoint, STUB.nav

-- nothing followed: nothing built
assert(NS.Get("map.beacon") == true, "on by default")
B.Update()
assert(_G.AmisiaBeacon == nil and not B.Shown(), "no pin: not built")

-- the player's own pin, followed; the client makes its navigation frame
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.5, 0.5))
C_SuperTrack.SetSuperTrackedUserWaypoint(true)
assert(not B.Shown(), "no navigation frame yet")
nav.frame = CreateFrame("Frame", nil, UIParent)
nav.distance = 86.4
STUB.fire("NAVIGATION_FRAME_CREATED")
local f = _G.AmisiaBeacon
assert(f and f:IsShown() and B.Shown(), "shown with the frame")
assert(f.strata == "BACKGROUND" and f.mouseEnabled == false, "at the back, no mouse")
local p = f.points and f.points.BOTTOM
assert(p and p.rel == nav.frame and p.relPoint == "CENTER", "its foot on the navigation frame")
assert(f.name:GetText() == "Kartenmarkierung" and f.dist:GetText() == "86 m", tostring(f.dist:GetText()))
assert(f.beam.blend == "ADD" and f.ring.blend == "ADD" and f.glow.blend == "ADD", "light added")
assert(f.beam.texture:find("beacon_beam", 1, true) and f.ring.texture:find("beacon_ring", 1, true))
assert(f.ring:GetWidth() == T.BEACON.RING_W and f.ring:GetHeight() == T.BEACON.RING_H, "the ring an ellipse")
assert(wp.sets == 1, "sets no waypoint itself")

-- the distance follows a few times a second
nav.distance = 40
f.scripts.OnUpdate(f, T.BEACON.TICK)
assert(f.dist:GetText() == "40 m", f.dist:GetText())
nav.distance = nil
f.scripts.OnUpdate(f, T.BEACON.TICK)
assert(f.dist:GetText() == "", "no distance: empty")
nav.distance = 1500
f.scripts.OnUpdate(f, T.BEACON.TICK)
assert(f.dist:GetText() == "1,5k m", f.dist:GetText())

-- off the screen or held at its edge: hidden at once, back when it is in view
nav.clamped = true
f.scripts.OnUpdate(f, 0.01)
assert(f:IsShown() and f:GetAlpha() == 0 and not B.Shown(), "held at the edge: not drawn")
nav.clamped = false
nav.valid = false
f.scripts.OnUpdate(f, 0.01)
assert(f:GetAlpha() == 0, "no screen position: not drawn")
nav.valid = true
f.scripts.OnUpdate(f, 0.01)
assert(f:GetAlpha() == 1 and B.Shown(), "in view again")

-- Amisia's own target: its name
NS.GEAR = { game = "forever", cap = 60, built = "t-bc", Z = {}, S = { { "V", "Gorn One Eye", 1411 } },
    I = { [100] = { "LEGS", 4, 2, 10, 2, 1, 20, 0, 0, 0, 1 } } }
STUB.item(100, "Lederhose der Wildnis", 2)
NS.MAP.P = { ["V:Gorn One Eye"] = "1411:4720:3310" }
assert(NS.MapSetTarget(100))
assert(wp.superTracked and NS.MapTarget().ours, "Amisia's target is the client's pin")
STUB.fire("SUPER_TRACKING_CHANGED")
assert(B.Shown() and f.name:GetText() == "Gorn One Eye", tostring(f.name:GetText()))

-- the following ends: gone; the frame destroyed: gone
C_SuperTrack.SetSuperTrackedUserWaypoint(false)
STUB.fire("SUPER_TRACKING_CHANGED")
assert(not f:IsShown(), "not followed: hidden")
C_SuperTrack.SetSuperTrackedUserWaypoint(true)
STUB.fire("SUPER_TRACKING_CHANGED")
assert(f:IsShown())
nav.frame = nil
STUB.fire("NAVIGATION_FRAME_DESTROYED")
assert(not f:IsShown(), "no navigation frame: hidden")
nav.frame = CreateFrame("Frame", nil, UIParent)
STUB.fire("NAVIGATION_FRAME_CREATED")
assert(f:IsShown() and f.points.BOTTOM.rel == nav.frame, "a new frame: hangs at the new one")

-- the setting
NS.Set("map.beacon", false)
NS.SettingItem("map.beacon").onChange(false)
assert(not f:IsShown(), "off: hidden")
STUB.fire("USER_WAYPOINT_UPDATED")
assert(not f:IsShown(), "off: stays hidden")
NS.Set("map.beacon", true)
NS.SettingItem("map.beacon").onChange(true)
assert(f:IsShown(), "on: back")

-- the pin removed: gone
assert(NS.MapClearTarget())
STUB.fire("SUPER_TRACKING_CHANGED")
assert(not f:IsShown(), "the pin gone: hidden")

-- Forever's Ctrl + click: the pin placed, not followed (the world map's own call right after); Amisia
-- follows it a moment later, and the light comes with the client's navigation frame (2026-11-15: the
-- light never showed for a plain map pin)
B._reset()
nav.frame = nil
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.4, 0.4))
C_SuperTrack.SetSuperTrackedUserWaypoint(false)
assert(not wp.superTracked)
STUB.tick(0.01)
assert(wp.superTracked, "Amisia follows the new pin")
nav.frame = CreateFrame("Frame", nil, UIParent)
STUB.fire("NAVIGATION_FRAME_CREATED")
assert(B.Shown(), "the light over the plain map pin")
-- the client's navigation frame stops all following at the screen's edge: followed again, at most
-- every REFOLLOW seconds
STUB.tick(T.BEACON.REFOLLOW)
C_SuperTrack.ClearAllSuperTracked()
assert(not wp.superTracked and not f:IsShown(), "stopped by the client")
STUB.tick(0.01)
assert(wp.superTracked, "followed again")
C_SuperTrack.ClearAllSuperTracked()
STUB.tick(0.01)
assert(not wp.superTracked, "not again at once")
STUB.tick(T.BEACON.REFOLLOW)
assert(wp.superTracked, "again after the pause")
-- the player clicks the pin to stop following it: it stays unfollowed
C_SuperTrack.SetSuperTrackedUserWaypoint(false)
STUB.fire("SUPER_TRACKING_CHANGED")
STUB.tick(1)
assert(not wp.superTracked and not f:IsShown(), "the player's choice stays")
-- reached: the client stops following, Amisia does not follow again until a new pin
C_SuperTrack.SetSuperTrackedUserWaypoint(true)
STUB.fire("NAVIGATION_DESTINATION_REACHED", true)
C_SuperTrack.ClearAllSuperTracked()
STUB.tick(1)
assert(not wp.superTracked, "reached: not followed again")
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.6, 0.6))
C_SuperTrack.SetSuperTrackedUserWaypoint(false)
STUB.tick(0.01)
assert(wp.superTracked, "a new pin: followed")
-- the setting off: no following
NS.Set("map.beacon", false)
C_SuperTrack.ClearAllSuperTracked()
STUB.tick(1)
assert(not wp.superTracked, "off: not followed")
NS.Set("map.beacon", true)
-- no pin: nothing to follow
C_Map.ClearUserWaypoint()
STUB.tick(1)
assert(not wp.superTracked, "no pin: nothing followed")

-- a client without navigation: nothing, no error
local keep = C_Navigation
C_Navigation = nil
C_SuperTrack.SetSuperTrackedUserWaypoint(true)
B.Update()
assert(not f:IsShown(), "no navigation: hidden")
C_Navigation = keep
B._reset()
nav.frame = nil
print("map beacon: shown with the followed pin, foot on the navigation frame, name and distance, off screen, setting, gone with the pin")
