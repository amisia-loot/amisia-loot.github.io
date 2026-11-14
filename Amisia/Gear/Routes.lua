-- The own routes (F-167, D-97): numbered stops and lines drawn by hand on one map (the map shown
-- when the route was made; dungeon maps as world maps), made on the world map with the route bar of
-- Gear/RouteMap.lua, saved per account, followed stop by stop through the one target of Gear/Map.lua,
-- and shared with the own group. Here: the route being made (cur, with its undo list), the saved
-- routes (AmisiaDB.routes = { v = 1, list = { { n = name, m = map id, at = epoch, s = { { x, y, l } },
-- k = { { x1, y1, x2, y2, ... } } } } }, cleaned on load), following, sharing and the offers of others.
--
-- Sharing (D-97): RO heads a route (id, parts, bytes, map, stops, lines, name), RD carries its text in
-- pieces of 220 bytes (stops 4 characters each, labels split by "^", lines of 3 characters a point
-- split by "."); RX is one point. Only to the own group (RAID, in a party PARTY), one route per 30 s,
-- one point per 10 s, never in combat, the lockdown or a battleground. A receiver takes them only
-- from a member of its own group (the server's sender name against the roster), with "Geteilte
-- Routen annehmen dürfen" on, outside the lockdown, every field checked; one route per sender per
-- 30 s (Comm's gap), 3 offers waiting, 10 minutes, nothing saved: nothing shows before "annehmen".
-- Fires "ROUTES" (what changed) for the map layer and the bar.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local Map = ns.Map

local R = {}
ns.Routes = R

local MAX_STOPS, MAX_LINES, MAX_POINTS = 30, 20, 60   -- a route: stops, lines, points of a line
local MIN_STEP = 0.006        -- map fraction between two points of a line (simplified while drawing)
local MAX_ROUTES, NAME_MAX, LABEL_MAX = 40, 30, 24
local SHARE_GAP, POINT_GAP = 30, 10
local OFFER_TTL, MAX_OFFERS = 600, 3
local PENDING_TTL, MAX_PENDING = 150, 6
local CHUNK, MAX_PARTS, MAX_BODY = 220, 24, 6000
local ARRIVE, NEAR = 15, 40   -- yards: arrived at a stop; near enough when the target went by itself
local TICK = 0.5
R.MAX_STOPS, R.MAX_LINES, R.MAX_POINTS, R.MAX_ROUTES = MAX_STOPS, MAX_LINES, MAX_POINTS, MAX_ROUTES
R.NAME_MAX, R.LABEL_MAX, R.SHARE_GAP, R.OFFER_TTL, R.MAX_OFFERS = NAME_MAX, LABEL_MAX, SHARE_GAP, OFFER_TTL, MAX_OFFERS

local function changed(what) ns.Fire("ROUTES", what) end

---------------------------------------------------------------------------
-- Values and texts
---------------------------------------------------------------------------
local function unit(v) return type(v) == "number" and v == v and v >= 0 and v <= 1 end
local function round4(v) return math.floor(v * 10000 + 0.5) / 10000 end
local function mapId(v) return type(v) == "number" and v >= 1 and v <= 999999 and v == math.floor(v) end
local function inCombat() return InCombatLockdown ~= nil and ns.Plain(InCombatLockdown()) == true end

-- text cut to max bytes without splitting a character
local function cut(text, max)
    if #text <= max then return text end
    local c = max
    while c > 0 do
        local b = text:byte(c + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        c = c - 1
    end
    return text:sub(1, c)
end

-- A name or label as a route keeps it: no codes, bars, control characters, "~" or "^" (the share
-- text's separators), spaces folded, cut to max bytes; nil when nothing (or only "-") is left.
local function cleanText(s, max)
    if type(s) ~= "string" then return nil end
    s = ns.StripCodes(s):gsub("[%c~%^]", " "):gsub("%s+", " ")
    s = cut(s:match("^%s*(.-)%s*$"), max):match("^(.-)%s*$")
    if s == "" or s == "-" then return nil end
    return s
end
R.CleanText = cleanText

-- The client's name of a map, else "Karte <id>".
local function zone(map)
    local api = _G.C_Map
    if type(api) == "table" and type(api.GetMapInfo) == "function" then
        local ok, info = pcall(api.GetMapInfo, map)
        local name = ok and type(info) == "table" and ns.Plain(info.name) or nil
        if type(name) == "string" and name ~= "" then return name end
    end
    return L["Karte %d"]:format(tonumber(map) or 0)
end
R.ZoneName = zone

-- Whether the client knows the map (a shared map id must be one).
local function knownMap(map)
    if not mapId(map) then return false end
    local api = _G.C_Map
    if type(api) ~= "table" or type(api.GetMapInfo) ~= "function" then return true end
    local ok, info = pcall(api.GetMapInfo, map)
    return ok and type(info) == "table"
end

local function plural(n, one, many) return (n == 1 and one or many):format(n) end

-- "7 Stopps", "3 Linien" or "7 Stopps, 3 Linien".
function R.CountText(r)
    local parts = {}
    if #r.stops > 0 then parts[#parts + 1] = plural(#r.stops, L["%d Stopp"], L["%d Stopps"]) end
    if #r.lines > 0 then parts[#parts + 1] = plural(#r.lines, L["%d Linie"], L["%d Linien"]) end
    return table.concat(parts, ", ")
end

-- "Dun Morogh 45.2, 63.1"
local function whereText(p)
    return ("%s %.1f, %.1f"):format(zone(p.map), p.x * 100, p.y * 100)
end

---------------------------------------------------------------------------
-- Copies and the saved routes
---------------------------------------------------------------------------
local function copyStops(list, max)
    local out = {}
    for _, s in ipairs(type(list) == "table" and list or {}) do
        if #out >= (max or MAX_STOPS) then break end
        if type(s) == "table" and unit(s.x) and unit(s.y) then
            out[#out + 1] = { x = round4(s.x), y = round4(s.y), l = cleanText(s.l, LABEL_MAX) }
        end
    end
    return out
end

local function copyLine(k)
    if type(k) ~= "table" or #k < 4 or #k % 2 ~= 0 or #k > MAX_POINTS * 2 then return nil end
    local out = {}
    for i, v in ipairs(k) do
        if not unit(v) then return nil end
        out[i] = round4(v)
    end
    return out
end

local function copyLines(list)
    local out = {}
    for _, k in ipairs(type(list) == "table" and list or {}) do
        if #out >= MAX_LINES then break end
        local c = copyLine(k)
        if c then out[#out + 1] = c end
    end
    return out
end

-- the undo list of a route made from a copy: its stops, then its lines
local function opsOf(r)
    local ops = {}
    for _ in ipairs(r.stops) do ops[#ops + 1] = "s" end
    for _ in ipairs(r.lines) do ops[#ops + 1] = "k" end
    return ops
end

-- A saved route checked field by field, or nil.
local function cleanSaved(e)
    if type(e) ~= "table" then return nil end
    local n, m = cleanText(e.n, NAME_MAX), tonumber(e.m)
    if not n or not mapId(m) then return nil end
    local s, k = copyStops(e.s), copyLines(e.k)
    if #s == 0 and #k == 0 then return nil end
    local at = tonumber(e.at)
    at = (at and at >= 0 and at <= 4e9) and math.floor(at) or 0
    return { n = n, m = m, at = at, s = s, k = k }
end

-- Shapes AmisiaDB.routes (ADDON_LOADED): every route checked, one per name and map (the newest), the
-- 40 newest.
function R.Loaded()
    if not AmisiaDB then return nil end
    local src = AmisiaDB.routes
    local list = type(src) == "table" and type(src.list) == "table" and src.list or {}
    local all = {}
    for _, e in ipairs(list) do
        local c = cleanSaved(e)
        if c then all[#all + 1] = c end
    end
    table.sort(all, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.n < b.n
    end)
    local out, seen = {}, {}
    for _, e in ipairs(all) do
        local key = e.n:lower() .. "@" .. e.m
        if not seen[key] and #out < MAX_ROUTES then
            seen[key] = true
            out[#out + 1] = e
        end
    end
    AmisiaDB.routes = { v = 1, list = out }
    return AmisiaDB.routes
end

local function store()
    if not AmisiaDB then return nil end
    local t = AmisiaDB.routes
    if type(t) ~= "table" or type(t.list) ~= "table" then t = R.Loaded() end
    return t
end

function R.Saved()
    local t = store()
    return t and t.list or {}
end

-- The saved route of that name on that map, or nil.
function R.SavedEntry(name, map)
    if type(name) ~= "string" then return nil end
    for _, e in ipairs(R.Saved()) do
        if e.m == map and e.n:lower() == name:lower() then return e end
    end
    return nil
end

-- The saved routes of a map and the others, each by name.
function R.SavedSplit(map)
    local here, other = {}, {}
    for _, e in ipairs(R.Saved()) do
        if e.m == map then here[#here + 1] = e else other[#other + 1] = e end
    end
    local function byName(a, b) return a.n:lower() < b.n:lower() end
    table.sort(here, byName)
    table.sort(other, byName)
    return here, other
end

---------------------------------------------------------------------------
-- The route being made
---------------------------------------------------------------------------
local cur              -- { map, name, from (its saved name), by (who shared it), stops, lines, ops }
local mode, tool = false, nil
local stroke           -- the line being drawn: { x1, y1, x2, y2, ... }
local following        -- { name, map, stops, lines, i, lastD, route }

local function newRoute(map) return { map = map, stops = {}, lines = {}, ops = {} } end

function R.Current() return cur end
function R.Mode() return mode end
function R.Tool() return tool end
function R.Drawing() return stroke end
function R.Following() return following end

-- What the map shows: the route being made while the route mode is on, else the route followed.
function R.Shown()
    if mode and cur then return cur end
    return following and following.route or nil
end

local function isEmpty(r) return not r or (#r.stops == 0 and #r.lines == 0) end

-- The route to change on map: the current one (a new one when there is none, or an empty one moved to
-- that map), or nil and why (it belongs to another map).
local function editable(map)
    if not mapId(map) then return nil, L["Keine Karte gezeigt."] end
    if not cur then
        cur = newRoute(map)
    elseif cur.map ~= map then
        if not isEmpty(cur) then
            return nil, L["Diese Route gehört zur Karte %s. Erst \"Leeren\" oder dorthin wechseln."]:format(zone(cur.map))
        end
        cur.map = map
    end
    return cur
end

function R.SetMode(on)
    on = on and true or false
    if mode == on then return true end
    mode = on
    if not on then tool, stroke = nil, nil end
    changed("mode")
    return true
end

-- tool "stop", "draw" or nil; never in combat (the click layer over the map stays hidden there)
function R.SetTool(t)
    if t ~= nil and t ~= "stop" and t ~= "draw" then return nil end
    if t and inCombat() then return nil, L["Nicht im Kampf."] end
    if t then mode = true end
    tool, stroke = t, nil
    changed("tool")
    return true
end

function R.AddStop(map, x, y)
    if not (unit(x) and unit(y)) then return nil, L["Außerhalb der Karte."] end
    local r, why = editable(map)
    if not r then return nil, why end
    if #r.stops >= MAX_STOPS then return nil, L["Höchstens %d Stopps."]:format(MAX_STOPS) end
    r.stops[#r.stops + 1] = { x = round4(x), y = round4(y) }
    r.ops[#r.ops + 1] = "s"
    changed("stop")
    return #r.stops
end

function R.StartLine(map, x, y)
    if not (unit(x) and unit(y)) then return nil, L["Außerhalb der Karte."] end
    local r, why = editable(map)
    if not r then return nil, why end
    if #r.lines >= MAX_LINES then return nil, L["Höchstens %d Linien."]:format(MAX_LINES) end
    stroke = { round4(x), round4(y) }
    changed("draw")
    return true
end

-- The next point of the line being drawn: only MIN_STEP away from the last one, 60 points at most.
function R.LineTo(x, y)
    local s = stroke
    if not s or not unit(x) or not unit(y) or #s >= MAX_POINTS * 2 then return false end
    local dx, dy = x - s[#s - 1], y - s[#s]
    if dx * dx + dy * dy < MIN_STEP * MIN_STEP then return false end
    s[#s + 1], s[#s + 2] = round4(x), round4(y)
    changed("draw")
    return true
end

-- Ends the line being drawn: kept with two points or more.
function R.EndLine()
    local s = stroke
    stroke = nil
    if not s then return false end
    if not cur or #s < 4 or #cur.lines >= MAX_LINES then
        changed("draw")
        return false
    end
    cur.lines[#cur.lines + 1] = s
    cur.ops[#cur.ops + 1] = "k"
    changed("line")
    return true
end

-- Takes back the last stop or line (or the line being drawn).
function R.Undo()
    if stroke then
        stroke = nil
        changed("undo")
        return true
    end
    local r = cur
    if not r or #r.ops == 0 then return false end
    local op = table.remove(r.ops)
    if op == "s" then table.remove(r.stops) else table.remove(r.lines) end
    changed("undo")
    return true
end

-- Empties the route (on its map); it is no longer a saved one.
function R.Clear()
    if not cur then return false end
    cur = newRoute(cur.map)
    stroke = nil
    changed("clear")
    return true
end

function R.SetName(text)
    if not cur then return false end
    cur.name = cleanText(text, NAME_MAX)
    changed("name")
    return true
end

function R.SetLabel(i, text)
    local s = cur and cur.stops[i]
    if not s then return false end
    s.l = cleanText(text, LABEL_MAX)
    changed("label")
    return true
end

function R.DeleteStop(i)
    if not (cur and cur.stops[i]) then return false end
    table.remove(cur.stops, i)
    for j = #cur.ops, 1, -1 do
        if cur.ops[j] == "s" then table.remove(cur.ops, j) break end
    end
    changed("stop")
    return true
end

-- Moves stop i one place earlier (d = -1) or later (d = 1).
function R.MoveStop(i, d)
    local list = cur and cur.stops
    local j = i + d
    if not (list and list[i] and list[j]) then return false end
    list[i], list[j] = list[j], list[i]
    changed("stop")
    return true
end

-- Saves the route under name; the saved route it was loaded as goes (a new name renames it), the
-- same name on this map is replaced.
function R.Save(name)
    local r = cur
    if isEmpty(r) then return nil, L["Die Route ist leer."] end
    name = cleanText(name, NAME_MAX) or r.name
    if not name then return nil, L["Gib der Route erst einen Namen."] end
    local t = store()
    if not t then return nil, L["Amisia ist noch nicht geladen."] end
    local list = t.list
    local function replaced(e)
        return e.m == r.map and (e.n:lower() == name:lower() or (r.from ~= nil and e.n:lower() == r.from:lower()))
    end
    local stay = 0
    for _, e in ipairs(list) do
        if not replaced(e) then stay = stay + 1 end
    end
    if stay >= MAX_ROUTES then return nil, L["Höchstens %d Routen. Lösche erst eine."]:format(MAX_ROUTES) end
    for i = #list, 1, -1 do
        if replaced(list[i]) then table.remove(list, i) end
    end
    table.insert(list, 1, { n = name, m = r.map, at = time(), s = copyStops(r.stops), k = copyLines(r.lines) })
    r.name, r.from = name, name
    changed("saved")
    return true, name
end

-- Shows a saved route (the route mode on).
function R.Load(e)
    if type(e) ~= "table" or not mapId(e.m) then return nil end
    cur = { map = e.m, name = e.n, from = e.n, stops = copyStops(e.s), lines = copyLines(e.k) }
    cur.ops = opsOf(cur)
    mode, tool, stroke = true, nil, nil
    changed("load")
    return cur
end

function R.Delete(e)
    local t = store()
    if not t or type(e) ~= "table" then return false end
    for i, x in ipairs(t.list) do
        if x == e then
            table.remove(t.list, i)
            if cur and cur.from and cur.map == e.m and cur.from:lower() == e.n:lower() then cur.from = nil end
            changed("saved")
            return true
        end
    end
    return false
end

function R.ConfirmDelete(e)
    if type(e) ~= "table" then return end
    ns.W.Confirm(L["Route löschen"], L["Die gespeicherte Route \"%s\" (%s) löschen?"]:format(e.n, zone(e.m)), L["Löschen##Knopf"], function()
        if R.Delete(e) then ns.msg(L["Route \"%s\" gelöscht."]:format(e.n)) end
    end)
end

---------------------------------------------------------------------------
-- Following: the one target of Map.lua goes from stop to stop
---------------------------------------------------------------------------
local ticker
local own = false      -- Amisia sets or clears the target for the route itself

local function stopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function keyOf(i) return "RT:" .. i end
R.KeyOf = keyOf

local function stopPoint(f, i)
    local s = f.stops[i]
    return { map = f.map, x = s.x, y = s.y }
end

local function aim(f)
    local s = f.stops[f.i]
    local label = L["Stopp %d/%d"]:format(f.i, #f.stops)
    if s.l then label = label .. ": " .. s.l end
    own = true
    local ok, why = ns.MapSetPoint(stopPoint(f, f.i), label, keyOf(f.i))
    own = false
    f.lastD = nil
    return ok, why
end

-- Clears the target when it is still the route's stop.
local function clearOwnTarget(f)
    local t = ns.MapTarget()
    if t and t.key == keyOf(f.i) then
        own = true
        ns.MapClearTarget()
        own = false
    end
end

local function check()
    local f = following
    if not f then
        stopTicker()
        return
    end
    local d = Map.Distance(stopPoint(f, f.i))
    f.lastD = d
    if d and d < ARRIVE then R.Next() end
end

-- Follows the stops of the current route from stop 1.
function R.Follow()
    local r = cur
    if not r or #r.stops == 0 then return nil, L["Die Route hat keine Stopps."] end
    local stops, lines = copyStops(r.stops), copyLines(r.lines)
    local name = r.name or L["Route"]
    following = { name = name, map = r.map, stops = stops, lines = lines, i = 1,
                  route = { map = r.map, name = name, stops = stops, lines = lines } }
    local ok, why = aim(following)
    if not ok then
        following = nil
        return nil, why
    end
    stopTicker()
    if C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(TICK, ns.Perf.Wrap("Ticker Routes", check)) end
    if not Map.PlayerPosition() then
        ns.msg(L["Hier kennt Amisia deine Position nicht: am Stopp \"/amisia route weiter\" oder \"Mehr\" > \"Weiter zum nächsten Stopp\"."])
    end
    changed("follow")
    return true
end

-- The next stop; after the last one the route is done (one chat line).
function R.Next()
    local f = following
    if not f then return nil, L["Du folgst keiner Route."] end
    if f.i >= #f.stops then
        following = nil
        stopTicker()
        clearOwnTarget(f)
        ns.msg(L["Route \"%s\" zu Ende: alle %d Stopps erreicht."]:format(f.name, #f.stops))
        changed("follow")
        return true, "done"
    end
    f.i = f.i + 1
    aim(f)
    changed("follow")
    return true
end

function R.StopFollow(quiet)
    local f = following
    if not f then return false end
    following = nil
    stopTicker()
    clearOwnTarget(f)
    if not quiet then ns.msg(L["Route folgen beendet."]) end
    changed("follow")
    return true
end

-- The target changed outside the route: gone at the stop (arrived, "Ziel beim Ankommen löschen")
-- moves on, anything else ends the following.
ns.Listen("MAP_TARGET", function()
    local f = following
    if not f or own then return end
    local t = ns.MapTarget()
    if t and t.key == keyOf(f.i) then return end
    if not t then
        local d = Map.Distance(stopPoint(f, f.i)) or f.lastD
        if d and d < NEAR then
            R.Next()
            return
        end
    end
    following = nil
    stopTicker()
    ns.msg(L["Route folgen beendet: ein anderes Ziel ist gesetzt."])
    changed("follow")
end)

---------------------------------------------------------------------------
-- The text of a shared route
---------------------------------------------------------------------------
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VAL = {}
for i = 1, #ALPHA do VAL[ALPHA:sub(i, i)] = i - 1 end

local function enc(n, digits)
    local out = {}
    for i = digits, 1, -1 do
        local d = n % 64
        out[i] = ALPHA:sub(d + 1, d + 1)
        n = math.floor(n / 64)
    end
    return table.concat(out)
end

local function dec(s)
    local n = 0
    for i = 1, #s do
        local v = VAL[s:sub(i, i)]
        if not v then return nil end
        n = n * 64 + v
    end
    return n
end

local function steps(v, n) return math.floor(math.max(0, math.min(1, v)) * n + 0.5) end

-- One piece separated by sep (a plain character), empty pieces kept.
local function split(s, sep)
    local out, from = {}, 1
    while true do
        local at = s:find(sep, from, true)
        if not at then
            out[#out + 1] = s:sub(from)
            return out
        end
        out[#out + 1] = s:sub(from, at - 1)
        from = at + 1
    end
end

-- The route as text: stops (x, y in 4096 steps, two characters each), "~", the labels split by "^",
-- "~", the lines split by "." (a point x * 512 + y in 512 steps, three characters).
function R.Encode(r)
    local stops, labels, lines = {}, {}, {}
    for i, s in ipairs(r.stops) do
        stops[i] = enc(steps(s.x, 4095), 2) .. enc(steps(s.y, 4095), 2)
        labels[i] = s.l or ""
    end
    for i, k in ipairs(r.lines) do
        local pts = {}
        for j = 1, #k - 1, 2 do pts[#pts + 1] = enc(steps(k[j], 511) * 512 + steps(k[j + 1], 511), 3) end
        lines[i] = table.concat(pts)
    end
    return table.concat(stops) .. "~" .. table.concat(labels, "^") .. "~" .. table.concat(lines, ".")
end

-- A route { map, stops, lines } from its text with the counts its head announced, or nil and what
-- was wrong.
function R.Decode(body, map, nStops, nLines)
    if type(body) ~= "string" or #body > MAX_BODY then return nil, "size" end
    if not mapId(map) or not ns.Int(nStops, 0, MAX_STOPS) or not ns.Int(nLines, 0, MAX_LINES) then return nil, "head" end
    local parts = split(body, "~")
    if #parts ~= 3 then return nil, "shape" end
    local sPart, lPart, kPart = parts[1], parts[2], parts[3]
    if #sPart ~= nStops * 4 then return nil, "stops" end
    local stops = {}
    for i = 1, nStops do
        local x, y = dec(sPart:sub(i * 4 - 3, i * 4 - 2)), dec(sPart:sub(i * 4 - 1, i * 4))
        if not x or not y then return nil, "stops" end
        stops[i] = { x = round4(x / 4095), y = round4(y / 4095) }
    end
    if nStops == 0 then
        if lPart ~= "" then return nil, "labels" end
    else
        local labels = split(lPart, "^")
        if #labels ~= nStops then return nil, "labels" end
        for i, l in ipairs(labels) do
            if #l > LABEL_MAX or l:find("[%c|]") then return nil, "labels" end
            stops[i].l = cleanText(l, LABEL_MAX)
        end
    end
    local lines = {}
    if kPart ~= "" then
        local list = split(kPart, ".")
        if #list ~= nLines then return nil, "lines" end
        for i, k in ipairs(list) do
            if #k % 3 ~= 0 or #k < 6 or #k > MAX_POINTS * 3 then return nil, "lines" end
            local pts = {}
            for j = 1, #k, 3 do
                local n = dec(k:sub(j, j + 2))
                if not n then return nil, "lines" end
                pts[#pts + 1] = round4(math.floor(n / 512) / 511)
                pts[#pts + 1] = round4((n % 512) / 511)
            end
            lines[i] = pts
        end
    elseif nLines ~= 0 then
        return nil, "lines"
    end
    if nStops == 0 and #lines == 0 then return nil, "empty" end
    return { map = map, stops = stops, lines = lines }
end

---------------------------------------------------------------------------
-- Sharing
---------------------------------------------------------------------------
local lastShare, lastPoint = nil, nil

local function groupChannel()
    if ns.HomeRaid() then return "RAID" end
    if ns.HomeGroup() then return "PARTY" end
    return nil
end

-- Why nothing may be sent now, or nil.
local function blocked(needComm)
    if needComm and not ns.CommAvailable() then return L["Addon-Nachrichten sind nicht verfügbar."] end
    if inCombat() then return L["Nicht im Kampf."] end
    if ns.CommHeld() or ns.ChatLocked() then return L["Gerade gesperrt (Bosskampf). Später noch einmal."] end
    if ns.InPvPInstance() then return L["Nicht im Schlachtfeld oder in der Arena."] end
    return nil
end

local function wait(last, gap)
    if not last then return nil end
    local left = gap - (GetTime() - last)
    if left > 0 then return math.ceil(left) end
    return nil
end

-- Sends the current route to the group: RO, then its RD pieces. Returns true and the pieces, or nil
-- and why.
function R.Share()
    local r = cur
    if isEmpty(r) then return nil, L["Die Route ist leer."] end
    local chan = groupChannel()
    if not chan then return nil, L["Du bist in keiner Gruppe."] end
    local why = blocked(true)
    if why then return nil, why end
    local left = wait(lastShare, SHARE_GAP)
    if left then return nil, L["Eine Route alle %d Sekunden: noch %d Sekunden."]:format(SHARE_GAP, left) end
    local body = R.Encode(r)
    local n = math.ceil(#body / CHUNK)
    if n > MAX_PARTS or #body > MAX_BODY then return nil, L["Die Route ist zu groß zum Teilen."] end
    local id = ("%04x"):format(math.random(0, 65535))
    local name = cleanText(r.name, NAME_MAX) or L["Route"]
    local ok, err = ns.CommSend("RO", { id, n, #body, r.map, #r.stops, #r.lines, name }, chan, nil, { ttl = 120 })
    if not ok then return nil, err end
    for i = 1, n do
        ns.CommSend("RD", { id, i, body:sub((i - 1) * CHUNK + 1, i * CHUNK) }, chan, nil, { ttl = 120 })
    end
    lastShare = GetTime()
    ns.msg(L["Route \"%s\" an die Gruppe geschickt (%s)."]:format(name, R.CountText(r)))
    return true, n
end

-- "Amisia-Punkt: Dun Morogh 45.2, 63.1 (Label)"
function R.PointText(p, label)
    local text = L["Amisia-Punkt: %s"]:format(whereText(p))
    if label then text = text .. " (" .. label .. ")" end
    return text
end

-- The client's link of its user waypoint, only when that stands on the point (Amisia never sets the
-- waypoint for a link); nil without one.
local function waypointLink(p)
    local api = _G.C_Map
    if type(api) ~= "table" or type(api.GetUserWaypointHyperlink) ~= "function" or type(api.GetUserWaypoint) ~= "function" then return nil end
    local ok, wp = pcall(api.GetUserWaypoint)
    if not ok or type(wp) ~= "table" or type(wp.position) ~= "table" or ns.Plain(wp.uiMapID) ~= p.map then return nil end
    local x, y = ns.Plain(wp.position.x), ns.Plain(wp.position.y)
    if type(x) ~= "number" or type(y) ~= "number" or math.abs(x - p.x) > 0.001 or math.abs(y - p.y) > 0.001 then return nil end
    local ok2, link = pcall(api.GetUserWaypointHyperlink)
    link = ok2 and ns.Plain(link) or nil
    if type(link) ~= "string" or not link:find("|H", 1, true) then return nil end
    return link
end

-- One point to the group: a chat line with zone and coordinates (and the client's waypoint link when
-- its waypoint stands there) for everyone, an RX for the Amisia clients.
function R.SharePoint(p, label)
    if type(p) ~= "table" or not mapId(p.map) or not unit(p.x) or not unit(p.y) then return nil, L["Kein Punkt."] end
    local chan = groupChannel()
    if not chan then return nil, L["Du bist in keiner Gruppe."] end
    local why = blocked(false)
    if why then return nil, why end
    local left = wait(lastPoint, POINT_GAP)
    if left then return nil, L["Ein Punkt alle %d Sekunden: noch %d Sekunden."]:format(POINT_GAP, left) end
    label = cleanText(label, LABEL_MAX)
    local text = R.PointText(p, label)
    local link = waypointLink(p)
    if link then text = text .. " " .. link end
    local said, err = ns.Say(text, chan)
    if not said then return nil, err end
    if ns.CommAvailable() then
        ns.CommSend("RX", { p.map, steps(p.x, 10000), steps(p.y, 10000), label or "-" }, chan, nil, { ttl = 30 })
    end
    lastPoint = GetTime()
    return true, link ~= nil
end

---------------------------------------------------------------------------
-- What others share: offers, never shown or saved by themselves
---------------------------------------------------------------------------
local offers, points, pending = {}, {}, {}

local function sweep(list)
    local t = GetTime()
    for i = #list, 1, -1 do
        if t - list[i].at >= OFFER_TTL then table.remove(list, i) end
    end
end

function R.Offers()
    sweep(offers)
    return offers
end

function R.PointOffers()
    sweep(points)
    return points
end

-- Whether a message from name on chan may become an offer at all.
local function takes(name, chan)
    if ns.Get("map.routeShare") == false then return false end
    if chan ~= "RAID" and chan ~= "PARTY" then return false end
    if not ns.InMyGroup(name) then return false end
    if ns.CommHeld() or ns.ChatLocked() then return false end
    return true
end

-- An offer into list (the sender's older one replaced); false when 3 wait already.
local function offer(list, o)
    sweep(list)
    for i, x in ipairs(list) do
        if x.from:lower() == o.from:lower() then
            table.remove(list, i)
            break
        end
    end
    if #list >= MAX_OFFERS then return false end
    list[#list + 1] = o
    changed("offer")
    return true
end

ns.CommOn("RO", function(sender, f, chan)
    local name = ns.TrustName(sender)
    if not name or not takes(name, chan) then return end
    local parts, bytes, map = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
    -- the pieces must fit the announced size: all full but the last
    if (parts - 1) * CHUNK >= bytes or parts * CHUNK < bytes or not knownMap(map) then return end
    local t = GetTime()
    local n = 0
    for k, p in pairs(pending) do
        if t - p.at >= PENDING_TTL then pending[k] = nil else n = n + 1 end
    end
    local key = name:lower()
    if not pending[key] and n >= MAX_PENDING then return end
    pending[key] = { id = f[1], parts = parts, bytes = bytes, map = map, stops = tonumber(f[5]), lines = tonumber(f[6]),
                     name = cleanText(f[7], NAME_MAX) or L["Route"], chunks = {}, got = 0, size = 0, at = t, from = name }
end)

ns.CommOn("RD", function(sender, f, chan)
    local name = ns.TrustName(sender)
    local key = name and name:lower()
    local p = key and pending[key]
    if not p or p.id ~= f[1] or (chan ~= "RAID" and chan ~= "PARTY") then return end
    local i = tonumber(f[2])
    if i > p.parts or p.chunks[i] then return end
    p.chunks[i], p.got, p.size = f[3], p.got + 1, p.size + #f[3]
    if p.size > p.bytes then
        pending[key] = nil
        return
    end
    if p.got < p.parts then return end
    pending[key] = nil
    local body = table.concat(p.chunks, "", 1, p.parts)
    if #body ~= p.bytes or not takes(name, chan) then return end
    local r = R.Decode(body, p.map, p.stops, p.lines)
    if not r then return end
    r.name = p.name
    local o = { from = name, name = p.name, route = r, at = GetTime() }
    if not offer(offers, o) then return end
    ns.msg(L["%s teilt die Route \"%s\" (%s, %s). /amisia route annehmen"]:format(name, p.name, R.CountText(r), zone(r.map)))
end)

ns.CommOn("RX", function(sender, f, chan)
    local name = ns.TrustName(sender)
    if not name or not takes(name, chan) then return end
    local map = tonumber(f[1])
    if not knownMap(map) then return end
    local p = { map = map, x = tonumber(f[2]) / 10000, y = tonumber(f[3]) / 10000, label = cleanText(f[4], LABEL_MAX),
                from = name, at = GetTime() }
    if not offer(points, p) then return end
    local where = whereText(p) .. (p.label and (" (" .. p.label .. ")") or "")
    ns.msg(L["%s teilt einen Punkt: %s. Als Ziel: /amisia route punkt"]:format(name, where))
end)

local function remove(list, o)
    for i, x in ipairs(list) do
        if x == o then
            table.remove(list, i)
            return true
        end
    end
    return false
end

-- Takes an offer (the newest without one): the route shows on the map, to be saved with "Speichern".
function R.Accept(o)
    sweep(offers)
    o = o or offers[#offers]
    if not o or not remove(offers, o) then return nil, L["Kein Angebot offen."] end
    local r = o.route
    cur = { map = r.map, name = o.name, by = o.from, stops = copyStops(r.stops), lines = copyLines(r.lines) }
    cur.ops = opsOf(cur)
    mode, tool, stroke = true, nil, nil
    changed("accept")
    ns.msg(L["Route \"%s\" von %s auf der Karte %s. Behalten: \"Speichern\" auf der Routen-Leiste."]:format(o.name, o.from, zone(r.map)))
    local wm = _G.WorldMapFrame
    local shownMap = wm and wm:IsShown() and tonumber(ns.Plain(wm:GetMapID())) or nil
    if shownMap ~= r.map then ns.MapShowOnWorldMap({ map = r.map, x = 0.5, y = 0.5 }) end
    return cur
end

-- Drops one offer, or every route offer without one; returns how many.
function R.Discard(o)
    if o then
        local n = (remove(offers, o) and 1 or 0) + (remove(points, o) and 1 or 0)
        if n > 0 then changed("offer") end
        return n
    end
    local n = #offers
    offers = {}
    if n > 0 then changed("offer") end
    return n
end

-- Takes a shared point (the newest without one) as the target.
function R.TakePoint(p)
    sweep(points)
    p = p or points[#points]
    if not p or not remove(points, p) then return nil, L["Kein Punkt offen."] end
    changed("offer")
    return ns.MapSetPoint({ map = p.map, x = p.x, y = p.y }, p.label or L["Punkt von %s"]:format(p.from), "RP:" .. p.from:lower())
end

---------------------------------------------------------------------------
-- Events, the command
---------------------------------------------------------------------------
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then R.Loaded() end
end)

-- combat: the tools go off (the click layer hides), a line being drawn ends
ns.OnEvent("PLAYER_REGEN_DISABLED", function()
    if not tool and not stroke then return end
    if stroke then R.EndLine() end
    tool = nil
    changed("tool")
end)

local function playerMap()
    local api = _G.C_Map
    if type(api) ~= "table" or type(api.GetBestMapForUnit) ~= "function" then return nil end
    local ok, map = pcall(api.GetBestMapForUnit, "player")
    map = ok and tonumber(ns.Plain(map)) or nil
    return mapId(map) and map or nil
end

-- `/amisia route`: the route mode on or off; on, the world map opens (on the route's map, else the own).
function R.Toggle()
    if mode then
        R.SetMode(false)
        ns.msg(L["Routen-Modus aus."])
        return false
    end
    R.SetMode(true)
    if ns.Get("map.routeBar") == false then
        ns.msg(L["Routen-Modus an, aber die Routen-Leiste ist aus (Einstellungen, Karte und Wegpunkt)."])
        return true
    end
    ns.msg(L["Routen-Modus an: \"Stopp\" und ein Klick auf die Karte setzt einen Stopp, \"Zeichnen\" zeichnet mit gedrückter Maustaste."])
    local wm = _G.WorldMapFrame
    if not (wm and wm:IsShown()) then
        local map = (cur and cur.map) or playerMap()
        if map then ns.MapShowOnWorldMap({ map = map, x = 0.5, y = 0.5 }) else ns.msg(L["Öffne die Weltkarte mit M."]) end
    end
    return true
end

-- the English sub-words (they work in every language)
local WORDS = { follow = "folgen", next = "weiter", accept = "annehmen", decline = "verwerfen", discard = "verwerfen",
                point = "punkt", aus = "stop" }   -- l10n-ok: typed words

local function say(ok, why) if not ok and why then ns.msg(why) end end

local function slash(rest)
    local word = (type(rest) == "string" and rest:match("^%s*(%S*)") or ""):lower()
    word = WORDS[word] or word
    if word == "" then
        R.Toggle()
    elseif word == "folgen" then
        say(R.Follow())
    elseif word == "weiter" then
        say(R.Next())
    elseif word == "stop" then
        if not R.StopFollow() then ns.msg(L["Du folgst keiner Route."]) end
    elseif word == "annehmen" then
        say(R.Accept())
    elseif word == "verwerfen" then
        local n = R.Discard()
        ns.msg(n > 0 and L["%d Angebote verworfen."]:format(n) or L["Kein Angebot offen."])
    elseif word == "punkt" then
        say(R.TakePoint())
    else
        ns.msg(L["Aufruf: /amisia route [folgen | weiter | stop | annehmen | verwerfen | punkt]"])
    end
end
R.Slash = slash

ns.RegisterSlash("route", { en = "route", args = L["[folgen | weiter | stop | annehmen | verwerfen | punkt]"],
    desc = L["Eigene Routen auf der Weltkarte: zeichnen, folgen, teilen"], run = function(rest) slash(rest) end })

-- for the tests
function R._reset()
    cur, mode, tool, stroke = nil, false, nil, nil
    following = nil
    stopTicker()
    offers, points, pending = {}, {}, {}
    lastShare, lastPoint = nil, nil
end
end)
