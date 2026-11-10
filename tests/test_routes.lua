-- The own routes (Gear/Routes.lua, Gear/RouteMap.lua; F-167, D-97): the route mode with its bar on the
-- world map, stops by a click, lines drawn with the mouse (simplified, capped), undo, clear, labels,
-- the stop menu, saving, loading, renaming and deleting, the cleanup on load, following with arrival
-- and by hand, the tools off in combat; sharing a route and a point and every way a receiver turns an
-- offer down (outside the group, another channel, too big, bad values, the rate, the lockdown, the
-- setting, three waiting), the offer flow, nothing written into the world map.
local R, RM = NS.Routes, NS.RouteMap
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function lastMsg() return STUB.messages[#STUB.messages] end

STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
STUB.maps[1426] = { name = "Dun Morogh", mapType = 3, world = { 0, 0, 0, 1000, 800 } }
STUB.maps[1427] = { name = "Sengende Schlucht", mapType = 3, world = { 0, 2000, 0, 1000, 800 } }
STUB.place = { map = 1426 }
STUB.map.pos = { x = 0.9, y = 0.9 }
STUB.roster = {}
-- the canvas on the screen: 1000 x 700 from (100, 900), scale 1
local canvas = getmetatable(STUB.mapCanvas).real
canvas._left, canvas._top = 100, 900
local function cursor(x, y) STUB.cursorX, STUB.cursorY = 100 + x * 1000, 900 - y * 700 end

assert(NS.Get("map.routeBar") == true and NS.Get("map.routeShare") == true, "both settings on by default")
STUB.fire("PLAYER_LOGIN")
local bar = RM.Bar()
assert(bar and _G.AmisiaRouteBar == bar and not bar:IsShown(), "the bar is built, hidden while the map is closed")

---------------------------------------------------------------------------
-- /amisia route: the mode on, the map opens on the own map; the bar shows with the tools
---------------------------------------------------------------------------
WorldMapFrame:Hide()
local opens = STUB.mapOpens
NS.Dispatch("route")
assert(R.Mode() and STUB.mapOpens == opens + 1 and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1426, "the map opened")
assert(said("Routen-Modus an"), lastMsg())
STUB.tick(0)
assert(bar:IsShown() and bar.stop:IsShown() and bar.draw:IsShown() and bar.share:IsShown(), "the bar with its tools")
assert(bar:GetFrameStrata() == WorldMapFrame:GetFrameStrata(), "in the map's strata")
assert(RM.Overlay() == nil or not RM.Overlay():IsShown(), "no click layer without a tool")
assert(#STUB.mapWrites == 0, "nothing written into the map")

-- the stop tool: a click on the map sets a numbered stop
bar.stop:Click()
assert(R.Tool() == "stop")
STUB.tick(0)
local ov = RM.Overlay()
assert(ov and ov:IsShown() and ov.mouseEnabled, "the click layer shows with a tool")
cursor(0.25, 0.5)
ov.scripts.OnMouseDown(ov, "LeftButton")
cursor(0.30, 0.5)
ov.scripts.OnMouseDown(ov, "LeftButton")
cursor(2, 0.5)
ov.scripts.OnMouseDown(ov, "LeftButton")
local cur = R.Current()
assert(cur and cur.map == 1426 and #cur.stops == 2, "two stops, the click beside the canvas none")
assert(cur.stops[1].x == 0.25 and cur.stops[1].y == 0.5 and cur.stops[2].x == 0.3, "where clicked")
STUB.tick(0)
local pins = RM.ShownPins()
assert(#pins == 2 and pins[1].num:GetText() == "1" and pins[2].num:GetText() == "2" and pins[1].mouseEnabled, "two numbered stops")
assert(#RM.ShownLines() == 1, "one line joins them")
local l = RM.ShownLines()[1]
assert(l.from[3] == 250 and l.from[4] == -350 and l.to[3] == 300 and l.thickness == 3, "the line between them")
assert(has(bar.info:GetText(), "2 Stopps"), bar.info:GetText())

-- the draw tool: a line with the mouse, simplified and kept with two points or more
bar.draw:Click()
assert(R.Tool() == "draw" and not bar.stop.on and bar.draw.on, "one tool at a time")
cursor(0.1, 0.1)
STUB.mouseDown = { LeftButton = true }
ov.scripts.OnMouseDown(ov, "LeftButton")
for i = 1, 10 do
    cursor(0.1 + i * 0.001, 0.1)    -- too small a step: one point every 6 thousandths
    STUB.tick(0)
end
cursor(0.2, 0.15)
STUB.tick(0)
cursor(0.3, 0.2)
STUB.tick(0)
assert(R.Drawing() and #R.Drawing() == 8, "four points so far: " .. #R.Drawing())
ov.scripts.OnMouseUp(ov, "LeftButton")
STUB.mouseDown = nil
assert(#cur.lines == 1 and #cur.lines[1] == 8 and R.Drawing() == nil, "the line is kept")
STUB.tick(0)
assert(#RM.ShownLines() == 4, "the join and three pieces of the line")
-- a click without moving is no line; letting go outside the frame ends it too
ov.scripts.OnMouseDown(ov, "LeftButton")
ov.scripts.OnMouseUp(ov, "LeftButton")
assert(#cur.lines == 1, "a dot is no line")
STUB.mouseDown = { LeftButton = true }
ov.scripts.OnMouseDown(ov, "LeftButton")
cursor(0.5, 0.5)
STUB.tick(0)
STUB.mouseDown = nil
STUB.tick(0)
assert(#cur.lines == 2 and not ov.drawing, "the button let go elsewhere ends the line")
-- 60 points at most
STUB.mouseDown = { LeftButton = true }
cursor(0, 0.9)
ov.scripts.OnMouseDown(ov, "LeftButton")
for i = 1, 90 do
    cursor(i * 0.01, 0.9)
    STUB.tick(0)
end
ov.scripts.OnMouseUp(ov, "LeftButton")
STUB.mouseDown = nil
assert(#cur.lines == 3 and #cur.lines[3] == 120, "60 points: " .. #cur.lines[3])

-- undo: the last line, then the last but one; then a stop
assert(R.Undo() and #cur.lines == 2 and R.Undo() and #cur.lines == 1)
assert(#cur.ops == 3)
bar.undo:Click()
assert(#cur.lines == 0 and #cur.stops == 2, "the undo goes back in order")
bar.undo:Click()
assert(#cur.stops == 1)
cursor(0.3, 0.5)
R.SetTool("stop")
ov.scripts.OnMouseDown(ov, "LeftButton")
assert(#cur.stops == 2)

-- the caps: 30 stops, 20 lines
for i = 3, 30 do assert(R.AddStop(1426, i / 100, 0.6) == i) end
local ok, why = R.AddStop(1426, 0.5, 0.7)
assert(not ok and why == "Höchstens 30 Stopps.", tostring(why))
for i = 1, 20 do
    R.StartLine(1426, 0.1, i / 30)
    R.LineTo(0.2, i / 30)
    assert(R.EndLine())
end
ok, why = R.StartLine(1426, 0.1, 0.1)
assert(not ok and why == "Höchstens 20 Linien.", tostring(why))
STUB.tick(0)
assert(#RM.ShownPins() == 30 and #RM.ShownLines() == 29 + 20, "every stop and line drawn")
-- another map while the route has stops: refused
ok, why = R.AddStop(1427, 0.5, 0.5)
assert(not ok and has(why, "Diese Route gehört zur Karte Dun Morogh"), tostring(why))
-- only the route's map shows it
WorldMapFrame:SetMapID(1427)
STUB.tick(0)
assert(#RM.ShownPins() == 0 and #RM.ShownLines() == 0, "another map shows nothing")
WorldMapFrame:SetMapID(1426)
STUB.tick(0)

-- clear: an empty route; then it may move to another map
bar.clear:Click()
assert(#R.Current().stops == 0 and #R.Current().lines == 0)
assert(R.AddStop(1427, 0.5, 0.5) == 1 and R.Current().map == 1427, "an empty route moves to the shown map")
R.Clear()

---------------------------------------------------------------------------
-- the stop menu: label, order, delete; the label through the bar's field
---------------------------------------------------------------------------
R.AddStop(1426, 0.2, 0.2)
R.AddStop(1426, 0.4, 0.4)
R.AddStop(1426, 0.6, 0.6)
STUB.tick(0)
cursor(0.401, 0.401)
ov.scripts.OnMouseDown(ov, "RightButton")
local menu = _G.AmisiaMenu
assert(menu and menu:IsShown(), "a right click near a stop opens its menu")
local labels = {}
for i, b in ipairs(menu.buttons) do if b:IsShown() then labels[i] = b.label:GetText() end end
assert(labels[1] == "Beschriften" and labels[2] == "Früher" and labels[3] == "Später" and labels[4] == "Löschen"
    and labels[5] == "Punkt teilen", table.concat(labels, ", "))
menu.buttons[1]:Click()
assert(bar.name:HasFocus() and has(bar.info:GetText(), "Name für Stopp 2"), bar.info:GetText())
bar.name:SetText("Höhle |cffff0000rot|r mit einem sehr langen Namen dahinter")
bar.name.scripts.OnEnterPressed(bar.name)
-- the field keeps 30 letters (codes counted), the label 24 bytes without codes
assert(R.Current().stops[2].l == "Höhle rot mit eine", tostring(R.Current().stops[2].l))
assert(R.SetLabel(2, "Höhle |cffff0000rot|r mit einem sehr langen Namen") and R.Current().stops[2].l == "Höhle rot mit einem seh",
    tostring(R.Current().stops[2].l))
assert(R.MoveStop(2, -1) and R.Current().stops[1].l == "Höhle rot mit einem seh", "moved earlier")
assert(not R.MoveStop(1, -1), "the first stays first")
assert(R.DeleteStop(1) and #R.Current().stops == 2 and #R.Current().ops == 2, "deleted, the undo list too")
-- a right click away from every stop opens nothing
menu:Hide()
cursor(0.9, 0.1)
ov.scripts.OnMouseDown(ov, "RightButton")
assert(not menu:IsShown())
-- the pins outside the mode take no mouse; the mode off hides the route, the tools and the layer
bar.route:Click()
assert(not R.Mode() and R.Tool() == nil)
STUB.tick(0)
assert(not ov:IsShown() and #RM.ShownPins() == 0 and #RM.ShownLines() == 0, "mode off: the map is as before")
assert(not bar.stop:IsShown() and not bar.save:IsShown() and bar.route.vis ~= false, "the bar folds to its switch")
bar.route:Click()
STUB.tick(0)
assert(#RM.ShownPins() == 2)

---------------------------------------------------------------------------
-- save, load, rename, delete
---------------------------------------------------------------------------
ok, why = R.Save("")
assert(not ok and why == "Gib der Route erst einen Namen.", tostring(why))
bar.name:SetText("Zur Höhle")
bar.save:Click()
assert(said('Route "Zur Höhle" gespeichert.'), lastMsg())
local list = AmisiaDB.routes.list
assert(#list == 1 and list[1].n == "Zur Höhle" and list[1].m == 1426 and #list[1].s == 2 and #list[1].k == 0)
-- the same name again replaces it; a new name renames the loaded route
R.AddStop(1426, 0.7, 0.7)
assert(R.Save("zur höhle") and #list == 1 and #list[1].s == 3, "the same name on the map: replaced")
assert(R.Save("Höhle Nord") and #list == 1 and list[1].n == "Höhle Nord", "a new name renames it")
R.Clear()
R.AddStop(1427, 0.5, 0.5)
R.SetName("Schlucht")
assert(R.Save() and #list == 2)
-- the load menu: the shown map's first, the others with their zone
WorldMapFrame:SetMapID(1426)
STUB.tick(0)
bar.load:Click()
labels = {}
for i, b in ipairs(menu.buttons) do if b:IsShown() then labels[i] = b.label:GetText() end end
assert(has(labels[1], "Dun Morogh") and labels[2] == "Höhle Nord" and has(labels[3], "Andere Karten")
    and labels[4] == "Schlucht (Sengende Schlucht)", table.concat(labels, ", "))
menu.buttons[2]:Click()
assert(R.Current().from == "Höhle Nord" and #R.Current().stops == 3 and R.Mode(), "loaded")
assert(bar.name:GetText() == "Höhle Nord")
-- delete through "Mehr" with a question
bar.more:Click()
local del
for _, b in ipairs(menu.buttons) do if b:IsShown() and b.label:GetText() == "Gespeicherte Route löschen" then del = b end end
assert(del, "Mehr offers to delete the loaded route")
del:Click()
local ask = _G.AmisiaConfirmFrame
assert(ask and ask:IsShown() and has(ask.text:GetText(), '"Höhle Nord"'), "a question first")
ask.ok:Click()
assert(#list == 1 and list[1].n == "Schlucht" and R.Current().from == nil, "deleted")
-- 40 routes at most
for i = 1, 39 do
    R.Clear()
    R.AddStop(1426, 0.1, 0.1)
    assert(R.Save("R" .. i))
end
R.Clear()
R.AddStop(1426, 0.2, 0.2)
ok, why = R.Save("Zu viel")
assert(not ok and why == "Höchstens 40 Routen. Lösche erst eine.", tostring(why))
assert(R.Save("R5"), "replacing one still goes")

-- the cleanup on load
AmisiaDB.routes = { v = 1, list = {
    { n = "Gut", m = 1426, at = 100, s = { { x = 0.1, y = 0.2, l = "A|cffff0000B" }, { x = 2, y = 0 } }, k = { { 0.1, 0.1, 0.2, 0.2 }, { 0.1 } } },
    { n = "gut", m = 1426, at = 50, s = { { x = 0.5, y = 0.5 } } },
    { n = "", m = 1426, s = { { x = 0.5, y = 0.5 } } },
    { n = "Leer", m = 1426, s = {}, k = {} },
    { n = "Karte", m = -3, s = { { x = 0.5, y = 0.5 } } },
    "kaputt",
    { n = ("X"):rep(50), m = 1426, at = 10, s = { { x = 0.5, y = 0.5, l = 7 } }, k = { { 0.1, 0.1, 0.2, "y" } } },
} }
for i = 1, 45 do table.insert(AmisiaDB.routes.list, { n = "Viele " .. i, m = 1427, at = 1000 + i, s = { { x = 0.5, y = 0.5 } } }) end
R.Loaded()
list = AmisiaDB.routes.list
assert(#list == 40 and list[1].n == "Viele 45", "the 40 newest")
R.Loaded()
AmisiaDB.routes.list = { AmisiaDB.routes.list[1] }
table.insert(AmisiaDB.routes.list, { n = "Gut", m = 1426, at = 100, s = { { x = 0.1, y = 0.2, l = "A|cffff0000B" }, { x = 2, y = 0 } }, k = { { 0.1, 0.1, 0.2, 0.2 }, { 0.1 } } })
table.insert(AmisiaDB.routes.list, { n = "gut", m = 1426, at = 50, s = { { x = 0.5, y = 0.5 } } })
table.insert(AmisiaDB.routes.list, { n = ("X"):rep(50), m = 1426, at = 10, s = { { x = 0.5, y = 0.5, l = 7 } }, k = { { 0.1, 0.1, 0.2, "y" } } })
R.Loaded()
list = AmisiaDB.routes.list
assert(#list == 3, "one per name and map, bad ones gone: " .. #list)
local good = R.SavedEntry("Gut", 1426)
assert(good and #good.s == 1 and good.s[1].l == "AB" and #good.k == 1, "every field checked")
local long = R.SavedEntry(("X"):rep(30), 1426)
assert(long and long.s[1].l == nil and #long.k == 0, "the name cut to 30, a bad label and line dropped")

---------------------------------------------------------------------------
-- following: stop to stop by arriving, by hand, the end; inside an instance by hand
---------------------------------------------------------------------------
STUB.messages = {}
R.Load(good)
R.AddStop(1426, 0.3, 0.2)
R.AddStop(1426, 0.5, 0.2)
assert(R.Follow())
local t = NS.MapTarget()
assert(t and t.key == "RT:1" and t.label == "Stopp 1/3: AB" and t.x == 0.1, "stop 1 is the target")
STUB.map.pos = { x = 0.105, y = 0.2 }   -- 5 yards away
STUB.tick(0.6)
t = NS.MapTarget()
assert(t and t.key == "RT:2" and t.label == "Stopp 2/3" and R.Following().i == 2, "arrived: stop 2")
-- the target going by itself at the stop (map.autoClear) moves on too
STUB.map.pos = { x = 0.301, y = 0.2 }
NS.MapClearTarget()
assert(NS.MapTarget() and NS.MapTarget().key == "RT:3", "gone at the stop: the next one")
STUB.map.pos = { x = 0.9, y = 0.9 }
NS.Dispatch("route weiter")
assert(R.Following() == nil and NS.MapTarget() == nil and said('Route "Gut" zu Ende: alle 3 Stopps erreicht.'), lastMsg())
-- another target ends it
assert(R.Follow())
NS.MapSetPoint({ map = 1426, x = 0.8, y = 0.8 }, "Woanders")
assert(R.Following() == nil and said("Route folgen beendet: ein anderes Ziel ist gesetzt."), lastMsg())
-- stop by command
assert(R.Follow())
NS.Dispatch("route stop")
assert(R.Following() == nil and NS.MapTarget() == nil and said("Route folgen beendet."))
NS.Dispatch("route stop")
assert(lastMsg() == "Du folgst keiner Route." or has(lastMsg(), "Du folgst keiner Route."), lastMsg())
-- in a dungeon the position is unknown: by hand
STUB.instance = { name = "Gnomeregan", type = "party", id = 90 }
STUB.map.pos = nil
STUB.messages = {}
assert(R.Follow())
assert(said("Hier kennt Amisia deine Position nicht"), lastMsg())
STUB.tick(2)
assert(R.Following().i == 1, "no arrival without a position")
NS.Dispatch("route weiter")
assert(R.Following().i == 2 and NS.MapTarget().key == "RT:2")
R.StopFollow(true)
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
STUB.map.pos = { x = 0.9, y = 0.9 }
-- a route without stops cannot be followed
R.Clear()
ok, why = R.Follow()
assert(not ok and why == "Die Route hat keine Stopps.")

---------------------------------------------------------------------------
-- combat: the tools go off, the click layer hides and none comes back in it
---------------------------------------------------------------------------
R.SetTool("draw")
STUB.tick(0)
assert(ov:IsShown())
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
STUB.tick(0)
assert(R.Tool() == nil and not ov:IsShown(), "combat: no tool, no click layer")
ok, why = R.SetTool("stop")
assert(not ok and why == "Nicht im Kampf.")
STUB.combat = false

---------------------------------------------------------------------------
-- sharing: only in a group, not in combat or the lockdown, one route per 30 s
---------------------------------------------------------------------------
R.Load(good)
ok, why = R.Share()
assert(not ok and why == "Du bist in keiner Gruppe.", tostring(why))
STUB.roster = { { name = NS.UnitFullName("player"), class = "WARRIOR" }, { name = "Anna Bergmann", class = "MAGE" } }
STUB.party = true
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.combat = true
ok, why = R.Share()
assert(not ok and why == "Nicht im Kampf.")
STUB.combat = false
STUB.chatLock = true
ok, why = R.Share()
assert(not ok and has(why, "gesperrt"), tostring(why))
STUB.chatLock = false
STUB.addon = {}
local n
ok, n = R.Share()
assert(ok and n == 1, "one piece")
STUB.tick(1)
assert(#STUB.addon == 2 and STUB.addon[1].chan == "PARTY" and has(STUB.addon[1].text, "1RO\t"), "RO, then RD, to the party")
assert(has(STUB.addon[1].text, "\t1426\t1\t1\tGut"), STUB.addon[1].text)
ok, why = R.Share()
assert(not ok and has(why, "Eine Route alle 30 Sekunden"), tostring(why))
STUB.tick(30)
assert(R.Share())

-- a point: a line in the group chat for everyone, RX for Amisia; the waypoint's link when it stands there
STUB.chat = {}
STUB.addon = {}
assert(R.SharePoint({ map = 1426, x = 0.452, y = 0.631 }, "Treffpunkt"))
STUB.tick(1)
local line = STUB.chat[#STUB.chat]
assert(line and line.chan == "PARTY" and line.text == "Amisia-Punkt: Dun Morogh 45.2, 63.1 (Treffpunkt)", line and line.text)
assert(#STUB.addon == 1 and STUB.addon[1].text == "1RX\t1426\t4520\t6310\tTreffpunkt", STUB.addon[1] and STUB.addon[1].text)
ok, why = R.SharePoint({ map = 1426, x = 0.5, y = 0.5 })
assert(not ok and has(why, "Ein Punkt alle 10 Sekunden"), tostring(why))
STUB.tick(10)
NS.MapSetPoint({ map = 1426, x = 0.25, y = 0.75 }, "Ziel")
assert(R.SharePoint(NS.MapTarget(), NS.MapTarget().label))
line = STUB.chat[#STUB.chat]
assert(has(line.text, "Amisia-Punkt: Dun Morogh 25.0, 75.0 (Ziel) |cffffff00|Hworldmap:1426:2500:7500|h"), line.text)
NS.MapClearTarget()

---------------------------------------------------------------------------
-- receiving: offers only from the group, checked, never shown by themselves
---------------------------------------------------------------------------
local ANNA = "Anna Bergmann"
local function send(kind, fields, chan, from)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1" .. kind .. "\t" .. table.concat(fields, "\t"), chan or "PARTY", from or ANNA)
end
local seq = 0
local function offerRoute(route, name, chan, from, opts)
    opts = opts or {}
    seq = seq + 1
    local body = opts.body or R.Encode(route)
    local id = ("%04x"):format(seq)
    local parts = math.ceil(#body / 220)
    send("RO", { id, opts.parts or parts, opts.bytes or #body, route.map, opts.stops or #route.stops, opts.lines or #route.lines, name }, chan, from)
    for i = 1, parts do send("RD", { id, i, body:sub((i - 1) * 220 + 1, i * 220) }, chan, from) end
end
local ROUTE = { map = 1426, stops = { { x = 0.25, y = 0.5, l = "Eingang" }, { x = 0.5, y = 0.5 } }, lines = { { 0.1, 0.1, 0.2, 0.3, 0.4, 0.4 } } }
-- the text round trip
local back = R.Decode(R.Encode(ROUTE), 1426, 2, 1)
assert(back and back.stops[1].l == "Eingang" and math.abs(back.stops[1].x - 0.25) < 0.001 and #back.lines[1] == 6
    and math.abs(back.lines[1][4] - 0.3) < 0.002, "encode and decode")
assert(R.Decode("AAAA~~", 1426, 2, 0) == nil and R.Decode("AAAA~a^b~", 1426, 1, 0) == nil and R.Decode("~~", 1426, 0, 0) == nil
    and R.Decode("AA!A~~", 1426, 1, 0) == nil and R.Decode("AAAA~~AB", 1426, 1, 1) == nil, "bad texts")

local before = #R.Offers()
-- not in the group
STUB.messages = {}
offerRoute(ROUTE, "Fremd", "PARTY", "Kai Fremder")
assert(#R.Offers() == before and #STUB.messages == 0, "a stranger: nothing")
-- another channel
offerRoute(ROUTE, "Gilde", "GUILD")
offerRoute(ROUTE, "Flüstern", "WHISPER")
assert(#R.Offers() == before, "guild and whisper: nothing")
STUB.tick(31)
-- the lockdown
STUB.chatLock = true
offerRoute(ROUTE, "Sperre")
STUB.chatLock = false
assert(#R.Offers() == before, "in the lockdown: nothing")
STUB.tick(31)
-- bad values: an unknown map, a count that does not fit, too many parts
offerRoute({ map = 999, stops = ROUTE.stops, lines = ROUTE.lines }, "Karte")
STUB.tick(31)
offerRoute(ROUTE, "Zählung", nil, nil, { stops = 5 })
STUB.tick(31)
offerRoute(ROUTE, "Teile", nil, nil, { parts = 30 })
STUB.tick(31)
offerRoute(ROUTE, "Größe", nil, nil, { bytes = 5000 })
STUB.tick(31)
assert(#R.Offers() == before and #STUB.messages == 0, "bad values: nothing")
-- the setting off
NS.Set("map.routeShare", false)
offerRoute(ROUTE, "Aus")
assert(#R.Offers() == before, "receiving off")
NS.Set("map.routeShare", true)
STUB.tick(31)
-- a good one: one chat line, an offer, nothing on the map
local shownBefore = R.Current()
offerRoute(ROUTE, "Zum Eingang")
assert(#R.Offers() == before + 1, "an offer")
assert(said('Anna Bergmann teilt die Route "Zum Eingang" (2 Stopps, 1 Linie, Dun Morogh). /amisia route annehmen'), lastMsg())
assert(R.Current() == shownBefore, "nothing shown by itself")
-- the rate: a second route from Anna within 30 s is dropped
offerRoute(ROUTE, "Gleich nochmal")
assert(#R.Offers() == before + 1 and R.Offers()[#R.Offers()].name == "Zum Eingang", "one route per 30 s")
-- three waiting at most
STUB.roster[3] = { name = "Bo Bauer", class = "ROGUE" }
STUB.roster[4] = { name = "Cid Clever", class = "PRIEST" }
STUB.roster[5] = { name = "Dina Dorn", class = "MAGE" }
STUB.fire("GROUP_ROSTER_UPDATE")
offerRoute(ROUTE, "B", nil, "Bo Bauer")
offerRoute(ROUTE, "C", nil, "Cid Clever")
offerRoute(ROUTE, "D", nil, "Dina Dorn")
assert(#R.Offers() == 3 and R.Offers()[3].from == "Cid Clever", "three waiting, the fourth dropped")
-- the menu of the bar lists them; ansehen shows the route, verwerfen drops one
bar.load:Click()
labels = {}
for i, b in ipairs(menu.buttons) do if b:IsShown() then labels[i] = b.label:GetText() end end
assert(labels[1] == "Angebot von Anna Bergmann: Zum Eingang - ansehen" and labels[2] == "Angebot von Anna Bergmann: Zum Eingang - verwerfen", labels[1])
menu.buttons[2]:Click()
assert(#R.Offers() == 2)
NS.Dispatch("route verwerfen")
assert(#R.Offers() == 0 and said("2 Angebote verworfen."), lastMsg())
STUB.tick(31)
offerRoute(ROUTE, "Zum Eingang")
WorldMapFrame:SetMapID(1427)
NS.Dispatch("route annehmen")
cur = R.Current()
assert(cur and cur.name == "Zum Eingang" and cur.by == ANNA and cur.from == nil and #cur.stops == 2 and cur.stops[1].l == "Eingang", "accepted")
assert(R.Mode() and WorldMapFrame:GetMapID() == 1426, "shown on its map")
assert(said('Route "Zum Eingang" von Anna Bergmann auf der Karte Dun Morogh.'), lastMsg())
STUB.tick(0)
assert(#RM.ShownPins() == 2 and bar.name:GetText() == "Zum Eingang", "on the map, ready to save")
NS.Dispatch("route annehmen")
assert(lastMsg() == "Kein Angebot offen." or has(lastMsg(), "Kein Angebot offen."), lastMsg())
-- an offer is forgotten after 10 minutes
STUB.tick(31)
offerRoute(ROUTE, "Alt")
assert(#R.Offers() == 1)
STUB.tick(601)
assert(#R.Offers() == 0, "gone after 10 minutes")

-- a shared point: a chat line, taken as the target by command; checked like a route
STUB.messages = {}
send("RX", { 1426, 4520, 6310, "Treffpunkt" })
assert(said("Anna Bergmann teilt einen Punkt: Dun Morogh 45.2, 63.1 (Treffpunkt). Als Ziel: /amisia route punkt"), lastMsg())
send("RX", { 1426, 4520, 6310, "-" }, "PARTY", "Kai Fremder")
send("RX", { 999, 1, 1, "-" }, "PARTY", "Bo Bauer")
send("RX", { 1426, 20000, 1, "-" }, "PARTY", "Cid Clever")
assert(#R.PointOffers() == 1, "only the group, a known map, coordinates 0..1")
NS.Dispatch("route punkt")
t = NS.MapTarget()
assert(t and t.map == 1426 and t.x == 0.452 and t.label == "Treffpunkt" and #R.PointOffers() == 0, "the point is the target")
NS.MapClearTarget()

-- the bar shows only while the map shows and the setting is on
NS.Set("map.routeBar", false)
STUB.tick(0)
assert(not bar:IsShown() and not ov:IsShown(), "setting off: no bar, no click layer")
NS.Set("map.routeBar", true)
STUB.tick(0)
assert(bar:IsShown())
WorldMapFrame:Hide()
assert(not bar:IsShown(), "the map closed: the bar goes")

-- a client without lines: dots along the path instead, capped
local layerFrame = RM.Layer()
local makeLine = layerFrame.CreateLine
layerFrame.CreateLine = nil
for _, x in ipairs(RM.ShownLines()) do x:Hide() end
WorldMapFrame:Show()
R.Load(good)
R.AddStop(1426, 0.9, 0.9)
STUB.tick(0)
local shown = RM.ShownLines()
assert(#shown > 20 and #shown <= NS.Theme.ROUTE.MAX_DOTS and shown[1].kind == "Texture", "dots: " .. #shown)
layerFrame.CreateLine = makeLine
WorldMapFrame:Hide()

-- in the whole round nothing was written into the world map
assert(#STUB.mapWrites == 0, "nothing written into the map: " .. table.concat(STUB.mapWrites, ", "))
STUB.party = nil
