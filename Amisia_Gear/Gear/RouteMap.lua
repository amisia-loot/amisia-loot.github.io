-- The own routes on the world map (F-167, D-97): the route of Gear/Routes.lua drawn on a layer of
-- Amisia's own, the click layer of the route mode and the route bar. Built the way of MapPins.lua
-- (D-64): the route layer is one frame of Amisia's, a child of the map canvas
-- (WorldMapFrame.ScrollContainer.Child), without mouse; its lines (the client's CreateLine on that
-- frame, else small dots) and Amisia's own buttons as the numbered stops stand on it by normalized
-- x/y; it reads the shown map and the canvas only in its own OnUpdate, which runs only while the map
-- shows. No data provider, pin pool, template, hook or script of the map, no write into it.
--
-- The click layer (overlay) is a second frame of Amisia's on the canvas, above the pins, shown only
-- while a tool ("Stopp", "Zeichnen") is on, never made or shown in combat (a fight turns the tools
-- off); while it hides the map takes its clicks as before. The stops take the mouse only in the
-- route mode. The bar (AmisiaRouteBar) is a frame of UIParent, placed at the map's lower left corner
-- by reading the scroll container's place each frame (no anchor on a frame of the map), shown while
-- the map shows and "Routen-Leiste auf der Weltkarte zeigen" is on.
local ADDON, ns = ...
ns.Load(function()
local W, T = ns.W, ns.Theme
local L = ns.L
local R = ns.Routes
local P = T.ROUTE

local DOT = "Interface\\AddOns\\Amisia\\Media\\Icons\\dot"
local report = ns.ReportError

local RM = {}
ns.RouteMap = RM

local layer, canvas, overlay, bar
local lines, dots, pins = {}, {}, {}
local seen = {}           -- what the last draw read: map, w, h, scale; the bar's place
local dirty = true
local draws = 0

local function inCombat() return InCombatLockdown ~= nil and ns.Plain(InCombatLockdown()) == true end

local function mapNow()
    local wm = _G.WorldMapFrame
    if type(wm) ~= "table" or type(wm.GetMapID) ~= "function" then return nil end
    local ok, id = pcall(wm.GetMapID, wm)
    return ok and tonumber(ns.Plain(id)) or nil
end

local function mapShown()
    local wm = _G.WorldMapFrame
    return type(wm) == "table" and wm:IsShown() and true or false
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function lineAt(i, x1, y1, x2, y2, color, thick, w, h)
    local l = lines[i]
    if not l then
        l = layer:CreateLine(nil, "ARTWORK")
        lines[i] = l
    end
    l:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    l:SetThickness(thick)
    l:SetStartPoint("TOPLEFT", layer, x1 * w, -y1 * h)
    l:SetEndPoint("TOPLEFT", layer, x2 * w, -y2 * h)
    l:Show()
end

local function dotAt(i, x, y, color, size)
    local d = dots[i]
    if not d then
        d = layer:CreateTexture(nil, "ARTWORK")
        d:SetTexture(DOT)
        dots[i] = d
    end
    d:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    d:SetSize(size, size)
    d:ClearAllPoints()
    d:SetPoint("CENTER", layer, "TOPLEFT", x, y)
    d:Show()
end

-- The menu of a stop: label, order, delete while the route mode makes it; the point to the group.
local function stopMenu(pin)
    local r, i = R.Shown(), pin.index
    local s = r and r.stops[i]
    if not s then return end
    local entries = {}
    if R.Mode() and r == R.Current() then
        entries[#entries + 1] = { L["Beschriften"], function() RM.LabelStop(i) end }
        if i > 1 then entries[#entries + 1] = { L["Früher"], function() R.MoveStop(i, -1) end } end
        if r.stops[i + 1] then entries[#entries + 1] = { L["Später"], function() R.MoveStop(i, 1) end } end
        entries[#entries + 1] = { L["Löschen##Knopf"], function() R.DeleteStop(i) end }
    end
    entries[#entries + 1] = { L["Punkt teilen"], function()
        local ok, why = R.SharePoint({ map = r.map, x = s.x, y = s.y }, s.l or L["Stopp %d"]:format(i))
        if not ok and why then ns.msg(why) end
    end, tip = L["Sagt Zone und Koordinaten im Gruppenchat; Amisia in der Gruppe kann den Punkt als Ziel nehmen."] }
    W.Menu(pin, entries)
end
RM.StopMenu = stopMenu

local function pinTooltip(pin)
    local r = R.Shown()
    local s = r and r.stops[pin.index]
    if not s then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Stopp %d/%d"]:format(pin.index, #r.stops) .. (s.l and (": " .. s.l) or ""), 1, 0.82, 0)
    GameTooltip:AddLine(("%s %.1f, %.1f"):format(R.ZoneName(r.map), s.x * 100, s.y * 100), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L["Klick: Beschriften, Reihenfolge, Löschen, Teilen."], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function pinOf(i)
    local b = pins[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer)
    b:SetSize(P.STOP, P.STOP)
    b.ring = b:CreateTexture(nil, "BACKGROUND")
    b.ring:SetAllPoints()
    b.ring:SetTexture(DOT)
    b.num = W.Text(b, T.FONT.text)
    b.num:SetPoint("CENTER", 0, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self) stopMenu(self) end)
    b:SetScript("OnEnter", function(self)
        local ok, err = pcall(pinTooltip, self)
        if not ok then report(err) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = b
    return b
end

-- Dots every DOT_STEP canvas pixels from one point to the next (a client without lines).
local function dotsAlong(n, x1, y1, x2, y2, color, size)
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local count = math.max(1, math.floor(len / P.DOT_STEP))
    for k = 0, count do
        if n >= P.MAX_DOTS then return n end
        n = n + 1
        local f = k / count
        dotAt(n, x1 + (x2 - x1) * f, -(y1 + (y2 - y1) * f), color, size)
    end
    return n
end

-- Puts the shown route of the shown map on the layer: the lines between the stops, the drawn lines,
-- the line being drawn, the numbered stops (the one followed green, the passed ones grey).
local function draw()
    draws = draws + 1
    local r = R.Shown()
    local w, h, cs = canvas:GetWidth(), canvas:GetHeight(), canvas:GetScale()
    seen.w, seen.h, seen.scale = w, h, cs
    local nl, nd, np = 0, 0, 0
    if r and r.map == seen.map and type(w) == "number" and type(h) == "number" and type(cs) == "number" and cs > 0 then
        local useLines = type(layer.CreateLine) == "function"
        local thick = P.LINE / cs
        local function seg(x1, y1, x2, y2, color)
            if useLines then
                nl = nl + 1
                lineAt(nl, x1, y1, x2, y2, color, thick, w, h)
            else
                nd = dotsAlong(nd, x1 * w, y1 * h, x2 * w, y2 * h, color, P.DOT / cs)
            end
        end
        local function path(k, color)
            for j = 3, #k - 1, 2 do seg(k[j - 2], k[j - 1], k[j], k[j + 1], color) end
        end
        for i = 2, #r.stops do seg(r.stops[i - 1].x, r.stops[i - 1].y, r.stops[i].x, r.stops[i].y, P.JOIN) end
        for _, k in ipairs(r.lines) do path(k, P.STROKE) end
        local live = R.Drawing()
        if live and r == R.Current() then path(live, P.LIVE) end
        local f = R.Following()
        local followed = f and f.route == r and f.i or nil
        local s = 1 / cs
        local mouse = R.Mode() and r == R.Current()
        for i, stop in ipairs(r.stops) do
            np = np + 1
            local pin = pinOf(np)
            pin.index = i
            pin.num:SetText(tostring(i))
            local c = (followed and i == followed and P.NOW) or (followed and i < followed and P.DONE) or P.STOP_COLOR
            pin.ring:SetVertexColor(c[1], c[2], c[3])
            pin:EnableMouse(mouse)
            pin:SetScale(s)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", layer, "TOPLEFT", stop.x * w / s, -stop.y * h / s)
            pin:SetFrameLevel(layer:GetFrameLevel() + 2)
            pin:Show()
        end
    end
    for i = nl + 1, #lines do lines[i]:Hide() end
    for i = nd + 1, #dots do dots[i]:Hide() end
    for i = np + 1, #pins do
        pins[i].index = nil
        pins[i]:Hide()
    end
end

local function safeDraw()
    local ok, err = pcall(draw)
    if not ok then
        for _, l in ipairs(lines) do l:Hide() end
        for _, d in ipairs(dots) do d:Hide() end
        for _, b in ipairs(pins) do b:Hide() end
        report(err)
    end
end

---------------------------------------------------------------------------
-- The click layer of the tools
---------------------------------------------------------------------------
-- Where the cursor stands on the canvas: x, y (0-1), or nil outside it (the canvas's place and scale
-- read, nothing of it changed; the click layer covers it exactly).
local function cursorAt()
    if not canvas or not GetCursorPosition then return nil end
    local cx, cy = GetCursorPosition()
    local s = canvas:GetEffectiveScale()
    local l, t, w, h = canvas:GetLeft(), canvas:GetTop(), canvas:GetWidth(), canvas:GetHeight()
    if not (cx and cy and s and s > 0 and l and t and w and h and w > 0 and h > 0) then return nil end
    local x, y = (cx / s - l) / w, (t - cy / s) / h
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end
RM.CursorAt = cursorAt

-- The shown stop nearest to x, y within HIT pixels on the screen, or nil.
local function stopNear(x, y)
    if not x or not seen.w or not seen.scale or seen.scale <= 0 then return nil end
    local best, bestD
    local reach = P.HIT / seen.scale
    for _, pin in ipairs(pins) do
        local r = pin.index and R.Shown()
        local s = r and r.stops[pin.index]
        if s then
            local d = math.sqrt(((x - s.x) * seen.w) ^ 2 + ((y - s.y) * seen.h) ^ 2)
            if d <= reach and (not bestD or d < bestD) then best, bestD = pin, d end
        end
    end
    return best
end

local function onDown(self, button)
    local x, y = cursorAt()
    if button == "RightButton" then
        local pin = stopNear(x, y)
        if pin then stopMenu(pin) end
        return
    end
    if button ~= "LeftButton" or not x then return end
    local ok, why
    if R.Tool() == "stop" then
        ok, why = R.AddStop(seen.map, x, y)
    elseif R.Tool() == "draw" then
        ok, why = R.StartLine(seen.map, x, y)
        self.drawing = ok and true or nil
    end
    if not ok and why then ns.msg(why) end
end

local function onUp(self, button)
    if button == "LeftButton" and self.drawing then
        self.drawing = nil
        R.EndLine()
    end
end

local function onOverlayUpdate(self)
    if not self.drawing then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        self.drawing = nil
        R.EndLine()
        return
    end
    local x, y = cursorAt()
    if x then R.LineTo(x, y) end
end
onOverlayUpdate = ns.Perf.Wrap("OnUpdate RouteMap draw", onOverlayUpdate)   -- /amisia leistung (F-184)

local function makeOverlay()
    if overlay or inCombat() then return overlay end
    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(canvas:GetFrameLevel() + P.OVERLAY_LEVEL)
    overlay:EnableMouse(true)
    overlay:SetScript("OnMouseDown", onDown)
    overlay:SetScript("OnMouseUp", onUp)
    overlay:SetScript("OnUpdate", onOverlayUpdate)
    overlay:SetScript("OnHide", function(self)
        if self.drawing then
            self.drawing = nil
            R.EndLine()
        end
    end)
    overlay:Hide()
    return overlay
end

-- The click layer shows while a tool is on, the bar shows and no fight runs.
local function syncOverlay()
    local want = R.Tool() ~= nil and bar ~= nil and bar:IsShown() and not inCombat()
    if want and not overlay then makeOverlay() end
    if overlay and overlay:IsShown() ~= want then overlay:SetShown(want) end
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------
local TIPS = {
    route = { L["Route"], L["Der Routen-Modus: die Route auf dieser Karte zeigen und bearbeiten. Aus: die Karte ist wie immer."] },
    stop = { L["Stopp"], L["An: ein Klick auf die Karte setzt einen nummerierten Stopp. Rechtsklick auf einen Stopp: Beschriften, Reihenfolge, Löschen."] },
    draw = { L["Zeichnen"], L["An: mit gedrückter linker Maustaste eine Linie auf die Karte zeichnen. Verschieben der Karte geht, solange es aus ist."] },
    undo = { L["Rückgängig"], L["Nimmt den letzten Stopp oder die letzte Linie zurück."] },
    clear = { L["Leeren"], L["Nimmt alle Stopps und Linien von der Karte. Eine gespeicherte Route bleibt gespeichert."] },
    name = { L["Name der Route"], L["Der Name, unter dem \"Speichern\" die Route ablegt. Ein neuer Name benennt eine geladene Route um."] },
    save = { L["Speichern"], L["Speichert die Route unter dem Namen im Feld, für alle deine Charaktere."] },
    load = { L["Laden##Route"], L["Gespeicherte Routen, die dieser Karte zuerst, und was dir deine Gruppe geschickt hat."] },
    share = { L["Teilen"], L["Schickt die Route an deine Gruppe. Wer Amisia hat, bekommt ein Angebot und sieht sie erst nach \"annehmen\"."] },
    more = { L["Mehr"], L["Folgen, weiter zum nächsten Stopp, das Ziel als Punkt teilen, die gespeicherte Route löschen."] },
}

local function loadEntries()
    local out = {}
    for _, o in ipairs(R.Offers()) do
        local head = L["Angebot von %s: %s"]:format(o.from, o.name)
        out[#out + 1] = { head .. " - " .. L["ansehen"], function() R.Accept(o) end }
        out[#out + 1] = { head .. " - " .. L["verwerfen"], function() R.Discard(o) end }
    end
    for _, p in ipairs(R.PointOffers()) do
        out[#out + 1] = { L["Punkt von %s als Ziel"]:format(p.from), function() R.TakePoint(p) end, tip = R.PointText(p, p.label) }
    end
    local here, other = R.SavedSplit(seen.map)
    if #here > 0 then
        out[#out + 1] = { R.ZoneName(seen.map), nil, head = true }
        for _, e in ipairs(here) do out[#out + 1] = { e.n, function() R.Load(e) end } end
    end
    if #other > 0 then
        out[#out + 1] = { L["Andere Karten"], nil, head = true }
        for i, e in ipairs(other) do
            if i > 20 then
                out[#out + 1] = { L["... und %d weitere"]:format(#other - 20) }
                break
            end
            out[#out + 1] = { ("%s (%s)"):format(e.n, R.ZoneName(e.m)), function()
                R.Load(e)
                ns.MapShowOnWorldMap({ map = e.m, x = 0.5, y = 0.5 })
            end }
        end
    end
    if #out == 0 then out[1] = { L["Keine gespeicherten Routen."] } end
    return out
end
RM.LoadEntries = loadEntries

local function say(ok, why) if not ok and why then ns.msg(why) end end

local function moreEntries()
    local out = {}
    local f, cur = R.Following(), R.Current()
    if f then
        out[#out + 1] = { L["Weiter zum nächsten Stopp"], function() say(R.Next()) end }
        out[#out + 1] = { L["Folgen beenden"], function() R.StopFollow() end }
    elseif cur and #cur.stops > 0 then
        out[#out + 1] = { L["Route folgen"], function() say(R.Follow()) end,
            tip = L["Setzt das Ziel auf Stopp 1; angekommen geht es zum nächsten. Wo das Spiel die Position nicht nennt (Dungeons): \"Weiter\"."] }
    end
    local t = ns.MapTarget()
    if t then
        out[#out + 1] = { L["Ziel als Punkt teilen"], function() say(R.SharePoint(t, t.label)) end }
    end
    local e = cur and cur.from and R.SavedEntry(cur.from, cur.map)
    if e then out[#out + 1] = { L["Gespeicherte Route löschen"], function() R.ConfirmDelete(e) end } end
    if #out == 0 then out[1] = { L["Erst Stopps setzen."] } end
    return out
end
RM.MoreEntries = moreEntries

-- the text at the bar's end: the counts, the stop being named, the offers
local function infoText()
    if bar.labelFor then return L["Name für Stopp %d, Enter:"]:format(bar.labelFor) end
    local n = #R.Offers() + #R.PointOffers()
    local offerText = n > 0 and (n == 1 and L["1 Angebot"] or L["%d Angebote"]:format(n)) or nil
    local cur = R.Current()
    if R.Mode() and cur and (#cur.stops > 0 or #cur.lines > 0) then
        local text = R.CountText(cur)
        if offerText then text = text .. " · " .. offerText end
        return text
    end
    return offerText or ""
end

local function layoutBar()
    local on = R.Mode()
    local items = { bar.route }
    for _, key in ipairs({ "stop", "draw", "undo", "clear", "name", "save", "load", "share", "more" }) do
        bar[key]:SetShown(on)
        if on then items[#items + 1] = bar[key] end
    end
    -- the menu of the offers also while the mode is off
    if not on and #R.Offers() + #R.PointOffers() > 0 then
        bar.load:Show()
        items[#items + 1] = bar.load
    end
    bar.info:SetText(infoText())
    bar.info:SetWidth(math.ceil(bar.info:GetStringWidth() or 0) + 2)
    items[#items + 1] = bar.info
    local width = W.Row(bar, items, T.CHIP_GAP, P.PAD, -(P.BAR_H - T.CHIP_H) / 2)
    bar:SetWidth(math.ceil(width) + P.PAD)
end

local function refreshBar()
    if not bar then return end
    local cur = R.Current()
    bar.route:SetOn(R.Mode())
    bar.stop:SetOn(R.Tool() == "stop")
    bar.draw:SetOn(R.Tool() == "draw")
    bar.undo:SetEnabled(cur ~= nil and (#cur.ops > 0 or R.Drawing() ~= nil))
    bar.clear:SetEnabled(cur ~= nil and (#cur.stops > 0 or #cur.lines > 0))
    bar.share:SetEnabled(cur ~= nil and (#cur.stops > 0 or #cur.lines > 0))
    bar.save:SetEnabled(cur ~= nil and (#cur.stops > 0 or #cur.lines > 0))
    if not bar.name:HasFocus() and not bar.labelFor then bar.name:SetText(cur and cur.name or "") end
    layoutBar()
end
RM.RefreshBar = refreshBar

local function commitName(text)
    local i = bar.labelFor
    if i then
        bar.labelFor = nil
        R.SetLabel(i, text)
        refreshBar()
        return
    end
    if R.Current() then R.SetName(text) end
end

-- The bar's field takes the label of stop i (Enter keeps it).
function RM.LabelStop(i)
    local cur = R.Current()
    local s = cur and cur.stops[i]
    if not (bar and s) then return end
    bar.labelFor = i
    bar.name:SetText(s.l or "")
    layoutBar()
    bar.name:SetFocus()
end

local function setTool(t)
    local ok, why = R.SetTool(R.Tool() ~= t and t or nil)
    say(ok, why)
end

local function makeBar()
    bar = CreateFrame("Frame", "AmisiaRouteBar", UIParent)
    bar:SetSize(200, P.BAR_H)
    bar:SetClampedToScreen(true)
    -- its ground takes the clicks, so none falls through to the map under it
    bar:EnableMouse(true)
    W.Flat(bar, 0, 0, 0, P.BAR_SHADE)
    W.Border(bar, T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.5)
    bar.route = W.TabCheck(bar, L["Route"], function()
        local on = not R.Mode()
        R.SetMode(on)
    end)
    bar.stop = W.TabCheck(bar, L["Stopp"], function() setTool("stop") end)
    bar.draw = W.TabCheck(bar, L["Zeichnen"], function() setTool("draw") end)
    bar.undo = W.Link(bar, L["Rückgängig"], function() R.Undo() end)
    bar.clear = W.Link(bar, L["Leeren"], function() R.Clear() end)
    bar.name = W.LineEdit(bar, P.NAME_W, commitName)
    bar.name:SetMaxLetters(R.NAME_MAX)
    bar.save = W.Link(bar, L["Speichern"], function()
        local ok, why = R.Save(bar.name:GetText())
        if ok then ns.msg(L["Route \"%s\" gespeichert."]:format(why)) else say(ok, why) end
    end)
    bar.load = W.Link(bar, L["Laden##Route"], function(self) W.Menu(self, loadEntries(), { width = P.MENU_W }) end)
    bar.share = W.Link(bar, L["Teilen"], function() say(R.Share()) end)
    bar.more = W.Link(bar, L["Mehr"], function(self) W.Menu(self, moreEntries(), { width = P.MENU_W }) end)
    bar.info = W.Text(bar, T.FONT.hint)
    for key, tip in pairs(TIPS) do
        W.Tooltip(bar[key], tip[1], tip[2])
        if key ~= "name" then W.FitChip(bar[key]) end
    end
    bar:Hide()
    refreshBar()
    return bar
end

-- The bar at the map's lower left corner: the scroll container's place read, the bar placed on
-- UIParent there (above the map's strata and level).
local function placeBar()
    local wm = _G.WorldMapFrame
    local sc = wm and wm.ScrollContainer
    if not sc then return end
    local l = sc.GetLeft and sc:GetLeft()
    local b = sc.GetBottom and sc:GetBottom()
    local es, us = sc:GetEffectiveScale(), bar:GetEffectiveScale()
    if type(l) ~= "number" or type(b) ~= "number" or not es or not us or us <= 0 then
        l, b, es, us = nil, nil, nil, nil
    end
    local key = tostring(l) .. ":" .. tostring(b) .. ":" .. tostring(es)
    if key == seen.barAt then return end
    seen.barAt = key
    bar:ClearAllPoints()
    if l then
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * es / us + P.BAR_X, b * es / us + P.BAR_Y)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    end
    bar:SetFrameStrata(wm:GetFrameStrata() or "HIGH")
    bar:SetFrameLevel(math.min(9000, (wm:GetFrameLevel() or 1) + 500))
end

local function syncBar()
    if not bar then return end
    local want = mapShown() and ns.Get("map.routeBar") ~= false
    if want then placeBar() end
    if bar:IsShown() ~= want then
        bar:SetShown(want)
        if want then refreshBar() end
    end
end

---------------------------------------------------------------------------
-- The layer
---------------------------------------------------------------------------
-- Every frame while the map shows: a new map, a change of the route or of the canvas's size or scale
-- draws again; the bar and the click layer follow.
local function onUpdate()
    local id = mapNow()
    if id ~= seen.map or dirty then
        seen.map, dirty = id, false
        safeDraw()
    elseif canvas:GetWidth() ~= seen.w or canvas:GetHeight() ~= seen.h or canvas:GetScale() ~= seen.scale then
        safeDraw()
    end
    syncBar()
    syncOverlay()
end
onUpdate = ns.Perf.Wrap("OnUpdate RouteMap", onUpdate)   -- /amisia leistung (F-184)

-- Makes the layer and the bar once the world map and its canvas exist; only frames of Amisia's own.
local function create()
    if layer then return true end
    local map = _G.WorldMapFrame
    local scroll = type(map) == "table" and map.ScrollContainer
    local child = type(scroll) == "table" and scroll.Child
    if type(child) ~= "table" or type(child.GetScale) ~= "function" or type(map.GetMapID) ~= "function" then return false end
    canvas = child
    layer = CreateFrame("Frame", nil, canvas)
    layer:SetAllPoints(canvas)
    layer:EnableMouse(false)
    layer:SetFrameLevel(canvas:GetFrameLevel() + P.LAYER_LEVEL)
    layer:SetScript("OnShow", function() dirty = true end)
    layer:SetScript("OnHide", function()
        if bar then bar:Hide() end
        if overlay then overlay:Hide() end
    end)
    layer:SetScript("OnUpdate", onUpdate)
    layer:Show()
    makeBar()
    dirty = true
    return true
end
ns.OnEvent("PLAYER_LOGIN", create)
ns.OnEvent("PLAYER_ENTERING_WORLD", create)

ns.Listen("ROUTES", function()
    dirty = true
    if bar then
        refreshBar()
        syncOverlay()
    end
end)

-- For the tests: the layer, the click layer, the bar, the shown stops and lines, the draws so far.
function RM.Layer() return layer end
function RM.Overlay() return overlay end
function RM.Bar() return bar end
function RM.Draws() return draws end
function RM.ShownPins()
    local out = {}
    for _, b in ipairs(pins) do
        if b.index and b:IsShown() then out[#out + 1] = b end
    end
    return out
end
function RM.ShownLines()
    local out = {}
    for _, l in ipairs(lines) do
        if l:IsShown() then out[#out + 1] = l end
    end
    for _, d in ipairs(dots) do
        if d:IsShown() then out[#out + 1] = d end
    end
    return out
end
end)
