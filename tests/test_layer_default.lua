-- D-172: Layer is off by default: no bar, no answering, Helfen off after a login; the switch "Helfen" on turns
-- answering on for good, so the next login helps again; answering off in the settings leaves a login without it.
local SW = NS.LayerChange
assert(NS.Get("layer.answer") == false and NS.Get("layer.bar") == false and NS.Get("layer.chip") == false, "off by default")
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD", true, false); STUB.tick(15)
assert(not SW.Hosting(), "Helfen off after a login")
assert(not (AmisiaLayerMiniBar and AmisiaLayerMiniBar:IsShown()), "no bar")
SW.SetHosting(true)
assert(SW.Hosting() and NS.Get("layer.answer") == true, "Helfen on turns answering on")
SW.SetHosting(false)
STUB.fire("PLAYER_ENTERING_WORLD", true, false)
assert(SW.Hosting(), "the next login helps")
NS.Set("layer.answer", false)
STUB.fire("PLAYER_ENTERING_WORLD", true, false)
assert(not SW.Hosting(), "answering off: a login leaves Helfen off")
-- the setting switches Helfen at once (no /reload)
NS.Set("layer.answer", true)
assert(SW.Hosting(), "the setting on: Helfen on at once")
NS.Set("layer.answer", false)
assert(not SW.Hosting(), "the setting off: Helfen off at once")
print("layer off by default")
