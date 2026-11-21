-- The world layer (F-185, D-117): a creature's GUID split into its zone id; an id becomes the current
-- layer when 2 of the last 5 creatures agree, a known one changes on 3 of them (F-221); pets,
-- guardians, players and other GUID kinds are not counted; nothing is read in an instance, a boss fight,
-- the chat lockdown or from a secret GUID; a zone change makes the layer unknown; old ids fall out;
-- letters by ascending id per map; the throttle of mouseover and name plates; the window, the chip and the
-- slash command; the self-test row.
local LY = NS.Layer
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function guid(zone, npc, spawn, kind) return ("%s-0-%d-0-5250-%d-%s"):format(kind or "Creature", zone, npc, spawn) end

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
local kind, zone, npc, spawn = LY.Parse("Creature-0-4012-0-5250-299-0000ABCDEF")
assert(kind == "Creature" and zone == 4012 and npc == 299 and spawn == "0000ABCDEF", tostring(zone))
assert(LY.Parse("Vehicle-0-77-0-5250-12-00AA") == "Vehicle")
assert(LY.Parse("Player-5250-0ABCDEF") == nil and LY.Parse("Pet-0-4012-0-5250-299-0100ABCD") == nil, "players and pets")
assert(LY.Parse("GameObject-0-4012-0-5250-299-0000AB") == nil and LY.Parse("Creature-0-0-0-5250-299-00AB") == nil, "objects, id 0")
assert(LY.Parse(nil) == nil and LY.Parse(42) == nil and LY.Parse("Creature-0-x-0-5250-299-00AB") == nil, "broken values")
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
assert(fired[#fired] == "current" and LY.Known())

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
assert(LY.Current() == 4012, "F-221: two creatures do not change a known layer")
STUB.tick(0.3)
STUB.mouseoverGUID = guid(3999, 42, "E3")
STUB.fire("UPDATE_MOUSEOVER_UNIT")
uid, map, name = LY.Current()
assert(uid == 3999 and name == "Layer A", "three of the last five: the lower id is A: " .. tostring(name))
assert(LY.Name(1429, 4012) == "Layer B", "the letters follow the ids")
local list = LY.List()
assert(#list == 2 and list[1].uid == 3999 and list[1].current and list[2].letter == "B" and not list[2].current)
-- back on a known layer: again three of the last five; the same creature votes once
STUB.unitGUIDs.nameplate1 = guid(4012, 305, "F1")
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
STUB.tick(0.2)
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(LY.Current() == 3999, "one creature of a known id, read twice: no change")
-- the name plates are throttled too (0.1 s)
STUB.unitGUIDs.nameplate2 = guid(4012, 306, "F2")
STUB.unitGUIDs.nameplate3 = guid(4012, 307, "F3")
STUB.tick(0.2)
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(LY.Current() == 3999, "plate throttled")
STUB.tick(0.2)
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(LY.Current() == 4012)
-- the rescan reads every plate at once (F-221): three creatures of 3999 in view
STUB.unitGUIDs.nameplate1 = guid(3999, 308, "F4")
STUB.unitGUIDs.nameplate2 = guid(3999, 309, "F5")
STUB.unitGUIDs.nameplate3 = guid(3999, 310, "F6")
assert(LY.Scan() >= 3 and LY.Current() == 3999, "the scan reads the plates in view")
STUB.unitGUIDs.nameplate1, STUB.unitGUIDs.nameplate2, STUB.unitGUIDs.nameplate3 = nil, nil, nil

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
assert(LY.Current() == nil and LY.Rescan() == false, "back in Elwynn: one creature is not enough, no rescan at the border")
STUB.targetGUID = guid(3999, 317, "0B2"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 3999, "two creatures")

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
assert(LY.Current() == nil, "one creature of a heard id: not yet (F-221)")
STUB.targetGUID = guid(3000, 10, "0E2"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 3000 and LY.Seen(1429, 3000))

-- the age; F-221: a known layer stays known (no five minutes); after six hours the old ids fall out
STUB.tick(301)
assert(LY.Known() and select(4, LY.Current()) >= 301)
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
assert(F.value:GetText() == "Layer A" and F.sub:GetText() == "Kennung 4012 · Wald von Elwynn", F.sub:GetText())
assert(F.seen[1].text:GetText() == "Layer A · hier · gerade eben", F.seen[1].text:GetText())
assert(F.seen[1].uid == nil, "the own layer's row is no button")
assert(NS.LayerWindow.SubText(4012, "") == "Kennung 4012")
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
-- F-221: the bar stands by itself from the start (layer.bar): "Layer A" over the state; a click opens and closes
-- the window; the "-" folds the window to it (F-204)
local LW = NS.LayerWindow
local bar = AmisiaLayerMiniBar
assert(NS.Get("layer.bar") == true and NS.Get("layer.barShade") == 55, "the bar on, 55 % by default")
assert(bar and bar:IsShown() and F:IsShown(), "the bar beside the window")
assert(bar.name:GetText() == "Layer A" and bar.sub:GetText() == "|cff4fbf7aHelfen|r", tostring(bar.sub:GetText()))
bar:Click()
assert(not F:IsShown() and bar:IsShown(), "a click closes the window")
bar:Click()
assert(F:IsShown(), "and opens it")
F.minBtn:Click()
assert(not F:IsShown() and bar:IsShown() and AmisiaDB.settings.layerWindow.mini == true, "folded, kept for the reload")
bar:Click()
assert(F:IsShown() and bar:IsShown() and AmisiaDB.settings.layerWindow.mini == nil, "a click opens the window again")
NS.Dispatch("layer")
assert(not F:IsShown(), "the command closes it")
-- the bar's second line: the state
local sub = LW.MiniSub(true, 1429, { step = "stop", req = { at = GetTime() }, answers = { {}, {} } })
assert(has(sub, "Antworten: 2"), sub)
assert(LW.MiniSub(true, 1429, { step = "stop", answers = {}, zone = { heardN = 3 } }) == "Frage, 3 gehört")
assert(LW.MiniSub(true, 1429, { swap = { host = "X" } }) == "In der Gruppe des Helfers", "the swap's stage")
assert(has(LW.MiniSub(true, 1429, { swap = { changed = 1, leaveAt = GetTime() + 4 } }), "Verlasse in 4 s"))
assert(has(LW.MiniSub(true, 1429, { swap = { changed = 1 } }), "Gewechselt"))
assert(LW.MiniSub(true, 1429, { pending = { name = "X" } }) == "Einladung erbeten")
assert(LW.MiniSub(true, 1429, { chat = true }) == "Gefragt ...")
assert(LW.MiniSub(true, 1429, { answers = {} }) == "Helfen aus", "helping off")
assert(LW.MiniSub(true, 1429, { hosting = true, why = "im Kampf" }) == "Pausiert")
assert(LW.MiniSub(true, 1429, { hosting = true, refresh = "Neustart in 4:12" }) == "Neustart in 4:12")
assert(LW.MiniSub(false, 1429, { answers = {} }) == "Ziele einen NPC an.")
-- the symbol's right click menu: swap, the other layers, helping, the window
local menu = LW.MiniMenu()
assert(menu[1][1] == "Layer wechseln" and menu[2][1] == "Helfen ausschalten" and menu[3][1] == "Fenster öffnen", menu[2][1])
menu[2][2]()
assert(not NS.LayerChange.Hosting() and LW.MiniMenu()[2][1] == "Helfen anschalten")
assert(bar.sub:GetText() == "Helfen aus" and bar.state == "off")
NS.LayerChange.SetHosting(true)
-- an instance: the window says so (F-221), the chip goes, the bar names the place
NS.Dispatch("layer")
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(F:IsShown() and F.value:GetText() == "Keine Layer in Die Todesminen", tostring(F.value:GetText()))
assert(not F.swap:IsEnabled() and not F.seen[1]:IsShown(), "nothing to swap there")
assert(not AmisiaLayerChip:IsShown(), "no chip in an instance")
assert(bar:IsShown() and bar.name:GetText() == "Die Todesminen" and bar.sub:GetText() == "In Instanzen gibt es keine Layer.",
    "the bar names the place (F-216): " .. tostring(bar.name:GetText()))
assert(LY.TooltipLine() == nil)
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(AmisiaLayerChip:IsShown() and AmisiaLayerChip.text:GetText() == "Layer ?", "the chip again, layer unknown")
assert(bar:IsShown() and bar.name:GetText() == "Layer ?" and bar.sub:GetText() == "Ziele einen NPC an.", "the bar again")
-- a right click on the bar hides it for good (layer.bar off), its x too
bar:GetScript("OnClick")(bar, "RightButton")
assert(not bar:IsShown() and NS.Get("layer.bar") == false, "a right click hides the bar")
STUB.fire("PLAYER_ENTERING_WORLD")
assert(not bar:IsShown(), "hidden stays hidden")
NS.Set("layer.bar", true)
assert(bar:IsShown(), "the setting brings it back")
bar.close:Click()
assert(not bar:IsShown() and NS.Get("layer.bar") == false, "its x hides it too")

-- F-221: the layers seen stay through /reload (AmisiaDB.layerSeen, an hour)
LY.SaveSeen()
local seen = AmisiaDB.layerSeen
assert(type(seen) == "table" and seen[1429] and next(seen[1429]), "saved")
LY._reset()
assert(#LY.List(1429) == 0)
LY._loadSeen()
assert(#LY.List(1429) > 0, "back from the saved list")
local bad = { layerSeen = { [1429] = { [3999] = { f = time() - 7200, l = time() - 7200 }, [4012] = { f = time(), l = time(), o = 1 },
    [-1] = {}, [7] = "x" }, ["x"] = {}, [1430] = "x" } }
LY.LoadedSeen(bad)
assert(bad.layerSeen[1429][4012] and not bad.layerSeen[1429][3999] and not bad.layerSeen[1429][-1] and not bad.layerSeen.x
    and not bad.layerSeen[1430], "old and bad entries go")
local broken = { layerSeen = "x" }
LY.LoadedSeen(broken)
assert(broken.layerSeen == nil)

-- F-221: the creatures in view at SHARD_TRANSFER count ten seconds not; a rescan reads again
LY._reset()
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.targetGUID = guid(4012, 600, "2A1"); STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = guid(4012, 601, "2A2"); STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 4012)
STUB.unitGUIDs.nameplate1 = guid(4012, 602, "2A3")
STUB.fire("SHARD_TRANSFER")
assert(LY.Current() == nil)
LY.Scan()
STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == nil, "the old layer's creatures in view do not count")
STUB.tick(11)
LY.Scan()
assert(LY.Current() == 4012, "after ten seconds they do (a restart that kept the layer)")
STUB.unitGUIDs.nameplate1 = nil

-- the self-test row reads the target's GUID
STUB.targetGUID = guid(4012, 299, "1A1")
local st, text = LY.Probe()
assert(st == "OK" and has(text, "Server-Teil 4012 (der Layer), Zonen-Kennung 5250") and has(text, "NPC 299"), text)
STUB.targetGUID = "Player-5250-0ABC"
st, text = LY.Probe()
assert(st == "WERT" and has(text, "nicht zerlegbar (Player)"), text)
STUB.targetGUID = nil
STUB.mouseoverGUID = nil
st, text = LY.Probe()
assert(st == "WERT" and has(text, "kein Ziel"), text)
