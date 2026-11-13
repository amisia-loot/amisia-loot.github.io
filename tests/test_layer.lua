-- The world layer (F-185, D-117): a creature's GUID split into its zone id; a new id becomes the current
-- layer after two different creatures on the zone map (or one when already known for the map); pets,
-- guardians, players and other GUID kinds are not counted; nothing is read in an instance, a boss fight,
-- the chat lockdown or from a secret GUID; a zone change makes the layer unknown; old ids fall out;
-- letters by ascending id per map; the throttle of mouseover and name plates; the window, the chip and the
-- slash command; the self-test row.
local LY = NS.Layer
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function guid(zone, npc, spawn, kind) return ("%s-0-5250-0-%d-%d-%s"):format(kind or "Creature", zone, npc, spawn) end

-- the world: Elwynn Forest, a sub zone map under it
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3, parent = 1415 }
STUB.maps[1415] = { name = "Östliche Königreiche", mapType = 2 }
STUB.maps[9001] = { name = "Goldhain", mapType = 5, parent = 1429 }
STUB.maps[1426] = { name = "Dun Morogh", mapType = 3, parent = 1415 }
STUB.place.map = 9001
STUB.fire("PLAYER_ENTERING_WORLD")
local fired = {}
NS.Listen("LAYER", function(what) fired[#fired + 1] = what end)

-- the GUID
local kind, zone, npc, spawn = LY.Parse("Creature-0-5250-0-4012-299-0000ABCDEF")
assert(kind == "Creature" and zone == 4012 and npc == 299 and spawn == "0000ABCDEF", tostring(zone))
assert(LY.Parse("Vehicle-0-5250-0-77-12-00AA") == "Vehicle")
assert(LY.Parse("Player-5250-0ABCDEF") == nil and LY.Parse("Pet-0-5250-0-4012-299-0100ABCD") == nil, "players and pets")
assert(LY.Parse("GameObject-0-5250-0-4012-299-0000AB") == nil and LY.Parse("Creature-0-5250-0-0-299-00AB") == nil, "objects, id 0")
assert(LY.Parse(nil) == nil and LY.Parse(42) == nil and LY.Parse("Creature-0-5250-0-x-299-00AB") == nil, "broken values")
assert(LY.Map() == 1429, "a sub zone counts as its zone: " .. tostring(LY.Map()))

-- one creature is not enough, the same creature twice neither
STUB.targetGUID = guid(4012, 299, "A1")
STUB.fire("PLAYER_TARGET_CHANGED")
STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == nil and #LY.List() == 0, "one creature: still unknown")
-- a pet, a guardian, a player and another player's pet are never counted
STUB.targetGUID = guid(4012, 300, "B1")
STUB.controlled.target = true
STUB.fire("PLAYER_TARGET_CHANGED")
STUB.controlled.target = nil
STUB.otherPet.target = true
STUB.fire("PLAYER_TARGET_CHANGED")
STUB.otherPet.target = nil
assert(LY.Current() == nil, "what a player controls does not count")
-- a secret GUID is skipped
local secret = guid(4012, 301, "C1")
STUB.secret[secret] = true
STUB.targetGUID = secret
STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == nil, "a secret GUID")
-- a second creature makes it the current layer
STUB.targetGUID = guid(4012, 302, "D1")
STUB.fire("PLAYER_TARGET_CHANGED")
local uid, map, name, age = LY.Current()
assert(uid == 4012 and map == 1429 and name == "Layer A" and age == 0, tostring(uid) .. " " .. tostring(name))
assert(fired[#fired] == "current" and LY.Fresh())

-- a creature over the border (another id, once) changes nothing
STUB.mouseoverGUID = guid(3999, 40, "E1")
STUB.fire("UPDATE_MOUSEOVER_UNIT")
assert(LY.Current() == 4012, "one creature of another id: no change")
-- the mouseover is throttled: a second read within 0.25 s is skipped
STUB.mouseoverGUID = guid(3999, 41, "E2")
STUB.fire("UPDATE_MOUSEOVER_UNIT")
assert(LY.Current() == 4012, "throttled")
STUB.tick(0.3)
STUB.fire("UPDATE_MOUSEOVER_UNIT")
uid, map, name = LY.Current()
assert(uid == 3999 and name == "Layer A", "two creatures: the lower id is A: " .. tostring(name))
assert(LY.Name(1429, 4012) == "Layer B", "the letters follow the ids")
local list = LY.List()
assert(#list == 2 and list[1].uid == 3999 and list[1].current and list[2].letter == "B" and not list[2].current)
-- back on a known layer: one creature is enough
STUB.unitGUIDs.nameplate1 = guid(4012, 305, "F1")
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(LY.Current() == 4012, "a known id needs one creature")
-- the name plates are throttled too (0.1 s)
STUB.unitGUIDs.nameplate2 = guid(3999, 306, "F2")
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(LY.Current() == 4012, "plate throttled")
STUB.tick(0.2)
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(LY.Current() == 3999)

-- a zone change: unknown until a creature is read again; each map has its own letters
STUB.place.map = 1426
STUB.fire("ZONE_CHANGED_NEW_AREA")
assert(LY.Current() == nil and LY.Map() == 1426 and #LY.List() == 0, "a new zone")
assert(fired[#fired] == "current")
STUB.targetGUID = guid(8000, 1, "0A1"); STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = guid(8000, 2, "0A2"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 8000 and select(3, LY.Current()) == "Layer A")
STUB.place.map = 1429
STUB.fire("ZONE_CHANGED_NEW_AREA")
STUB.targetGUID = guid(3999, 307, "0B1"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 3999, "back in Elwynn: the known id with one creature")

-- an instance, a boss fight and the lockdown read nothing
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.targetGUID = guid(55, 1, "0C1"); STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = guid(55, 2, "0C2"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == nil and LY.Map() == nil, "nothing in an instance")
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.restricted = true
STUB.targetGUID = guid(4012, 310, "0D1"); STUB.fire("PLAYER_TARGET_CHANGED")
STUB.restricted = nil
STUB.chatLock = true
STUB.targetGUID = guid(4012, 311, "0D2"); STUB.fire("PLAYER_TARGET_CHANGED")
STUB.chatLock = false
assert(LY.Current() == nil, "boss fight and lockdown read nothing")

-- the guild's id: known, one own creature makes it current, its letter counts
LY.Heard(1429, 3000)
assert(LY.Name(1429, 3000) == "Layer A" and LY.Name(1429, 3999) == "Layer B", "a lower id shifts the letters")
assert(not LY.Seen(1429, 3000) and LY.Seen(1429, 3999))
STUB.targetGUID = guid(3000, 9, "0E1"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 3000 and LY.Seen(1429, 3000))

-- the age and freshness; after six hours the old ids fall out
STUB.tick(301)
assert(not LY.Fresh() and select(4, LY.Current()) >= 301)
assert(LY.Age(30) == "gerade eben" and LY.Age(185) == "vor 3 Min." and LY.Age(3 * 3600) == "vor 3 Std.")
STUB.tick(6 * 3600)
assert(LY.Current() == nil and #LY.List() == 0, "expired")

-- the window: unknown, then the layer with the list
STUB.fire("PLAYER_ENTERING_WORLD")
NS.Dispatch("layer")
local F = AmisiaLayerFrame
assert(F and F:IsShown() and F.value:GetText() == "unbekannt" and has(F.sub:GetText(), "Ziele oder überfahre"))
STUB.targetGUID = guid(4012, 400, "0F1"); STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = guid(4012, 401, "0F2"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(F.value:GetText() == "Layer A" and F.sub:GetText() == "Wald von Elwynn", F.value:GetText())
assert(F.seen[1]:GetText() == "Layer A · hier · gerade eben", F.seen[1]:GetText())
NS.Dispatch("layer")
assert(not F:IsShown(), "the command closes it again")
-- the minimap menu has it in its first level (no longer under the map), its tooltip names the layer
local found
for _, e in ipairs(NS.MinimapMenuEntries()) do if e[1] == "Layer" then found = e end end
assert(found and not found.sub and found.tip == "Layer: Layer A", "the quick menu has the window: " .. tostring(found and found.tip))
for _, e in ipairs(NS.MinimapMenuEntries("dungeons")) do assert(e[1] ~= "Layer", "not twice") end
found[2]()
assert(F:IsShown())
assert(LY.TooltipLine() == "Layer: Layer A")
-- the chip: off by default, on shows "Layer A", a click opens the window
assert(not (AmisiaLayerChip and AmisiaLayerChip:IsShown()), "no chip by default")
NS.Set("layer.chip", true)
assert(AmisiaLayerChip:IsShown() and AmisiaLayerChip.text:GetText() == "Layer A")
F:Hide()
AmisiaLayerChip:Click()
assert(F:IsShown(), "a click on the chip opens the window")
-- an instance hides both; the window will not open there
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(not F:IsShown() and not AmisiaLayerChip:IsShown(), "not in an instance")
NS.Dispatch("layer")
assert(not F:IsShown() and has(STUB.messages[#STUB.messages], "nicht in Instanzen"))
assert(LY.TooltipLine() == nil)
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(AmisiaLayerChip:IsShown() and AmisiaLayerChip.text:GetText() == "Layer ?", "the chip again, layer unknown")

-- the self-test row reads the target's GUID
STUB.targetGUID = guid(4012, 299, "1A1")
local st, text = LY.Probe()
assert(st == "OK" and has(text, "Zonen-Kennung 4012") and has(text, "NPC 299"), text)
STUB.targetGUID = "Player-5250-0ABC"
st, text = LY.Probe()
assert(st == "WERT" and has(text, "nicht zerlegbar (Player)"), text)
STUB.targetGUID = nil
STUB.mouseoverGUID = nil
st, text = LY.Probe()
assert(st == "WERT" and has(text, "kein Ziel"), text)
