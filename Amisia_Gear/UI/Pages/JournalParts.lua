-- The journal's detail parts (F-146, D-72) for the pages Dungeons and Raids: the tabs under the
-- image (Übersicht, Karte, Quests, Wunschliste, Zugang), the run in the bosses' header line (kills
-- "n/m" with a bar, "Lauf zurücksetzen"), a boss's kill mark and menu, the instance map (the client's
-- map art of the instance's floors, zoom and drag, the player's arrow inside) and the keys (each key
-- with its state and the quests that lead to it). The run comes from Gear/Runs.lua, the floors and
-- the keys from the facts (DungeonData.lua: maps, keys).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local K = ns.GearPageKit
local D = T.DPART
local GREY, GREEN = T.GREY, "|cff4fd06a"

local P = {}
ns.JournalParts = P

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------
local PART_TEXT = { bosses = L["Übersicht"], map = L["Karte"], quests = "Quests", wish = L["Wunschliste"], access = L["Zugang"], times = L["Zeiten"] }
local PART_TIP = {
    bosses = L["Die Bosse mit ihrer Beute und dein Lauf: welche Bosse du schon getötet hast."],
    map = L["Die Karte der Instanz aus dem Spiel, mit ihren Ebenen. Mausrad: zoomen, Ziehen: verschieben."],
    quests = L["Die Quests des Dungeons mit Stufe, Weg (erledigte Schritte der Vorquests) und Start. Klick auf eine Quest zeigt ihren Questweg: jeden Schritt mit Annehmen, Abgeben, Voraussetzung und Karte."],
    wish = L["Was du dir aus dieser Instanz wünschst und was deine Ausrüstungsplanung empfiehlt, nach Boss."],
    access = L["Die Schlüssel der Instanz: ob du sie hast und die Quests, die zu ihnen führen."],
    times = L["Deine Lauf-Zeiten in dieser Instanz: der beste Lauf mit seinen Zwischenzeiten, die beste Zeit je Boss und die letzten Läufe."],
}

-- The tabs of page B in band top (a SetPoint offset), one per key; field: the key in settings.bis
-- that keeps the chosen one. B.parts, B.partKeys.
function P.BuildTabs(B, top, keys, field)
    B.parts, B.partKeys, B.partTop, B.partField = {}, keys, top, field
    for _, k in ipairs(keys) do
        local tab = W.Tab(B, PART_TEXT[k], function()
            K.state()[field] = k
            ns.Refresh()
        end)
        W.Tooltip(tab, PART_TEXT[k], PART_TIP[k])
        B.parts[k] = tab
    end
end

-- The tabs shown, from the left (one gone, the next moves up).
function P.PlaceTabs(B)
    local row = {}
    for _, k in ipairs(B.partKeys) do row[#row + 1] = B.parts[k] end
    W.Row(B, row, T.TAB_GAP, 0, B.partTop - 1, { shown = true })
end

-- The chosen part of page B for entry e: the saved one when it is a tab of the page and possible
-- (Zugang only with a key, Zeiten only with the bosses' encounters), else Übersicht. Marks its tab (the page shows the tabs in its detail).
function P.PartOf(B, e)
    local p = K.state()[B.partField]
    local keys = e and P.Keys(e.key) or nil
    local ok = false
    for _, k in ipairs(B.partKeys) do
        if k == p then ok = true end
    end
    if not ok or (p == "access" and not keys) or (p == "times" and not (e and ns.Runs.Encounters(e.key))) then p = "bosses" end
    for k, tab in pairs(B.parts) do tab:SetOn(k == p) end
    return p
end

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------
local RTEXT = {
    title = L["Dein Lauf"],
    tip = L["Die Bosse, die du seit dem Betreten dieser Instanz getötet hast. Ein neuer Lauf beginnt, wenn die Instanz zurückgesetzt wird oder du nach einer halben Stunde draußen wiederkommst. Rechtsklick auf einen Boss: von Hand markieren."],
    reset = L["Lauf zurücksetzen"],
    resetTip = L["Vergisst die getöteten Bosse dieses Laufs."],
    mark = L["Als getötet markieren"], unmark = L["Nicht getötet"],
    noMark = L["Markieren geht nur in der Instanz oder für ihren laufenden Lauf."],
}

-- "1/4" and the bar (B.runBar), "Lauf zurücksetzen" (B.resetRun).
function P.BuildRun(B)
    local R = D.RUN
    local f = CreateFrame("Frame", nil, B)
    f:SetSize(R.W, R.H)
    f:EnableMouse(true)
    f.text = W.Text(f, T.FONT.text, R.TEXT_W)
    f.text:SetPoint("LEFT", 0, 0)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetColorTexture(0, 0, 0, 0.6)
    f.bg:SetSize(R.BAR_W, R.BAR_H)
    f.bg:SetPoint("RIGHT", 0, 0)
    f.fill = f:CreateTexture(nil, "ARTWORK")
    f.fill:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.9)
    f.fill:SetHeight(R.BAR_H)
    f.fill:SetPoint("LEFT", f.bg, "LEFT", 0, 0)
    W.Tooltip(f, RTEXT.title, RTEXT.tip)
    B.runBar = f
    B.resetRun = W.Link(B, RTEXT.reset, function()
        ns.Runs.Reset()
        ns.Refresh()
    end)
    W.Tooltip(B.resetRun, RTEXT.reset, RTEXT.resetTip)
end

-- The run of e on B: shown (on: the part Übersicht) while the character's run is of e's instance.
function P.FillRun(B, e, on)
    local n, m
    if e and on then n, m = select(2, ns.Runs.Of(e.key)) end
    local show = n ~= nil
    B.runBar:SetShown(show)
    B.resetRun:SetShown(show)
    if not show then return end
    B.runBar.text:SetText(("%d/%d"):format(n, m))
    local w = m > 0 and math.floor(D.RUN.BAR_W * n / m + 0.5) or 0
    B.runBar.fill:SetWidth(math.max(1, w))
    B.runBar.fill:SetShown(w > 0)
end

-- A boss of dungeon dkey by its name: its place in the game's order (the facts' order), or nil.
local function bossKey(s) return type(s) == "string" and (s:lower():gsub("[^%w]", "")) or "" end
function P.BossIndex(dkey, name)
    local order = ns.Dungeons.BossOrder(dkey)
    if not order then return nil end
    local k = bossKey(name)
    for i, n in ipairs(order) do
        if bossKey(n) == k then return i end
    end
    return nil
end

-- Whether boss name of dkey is killed in the run.
function P.BossKilled(dkey, name)
    local i = dkey and P.BossIndex(dkey, name)
    return i ~= nil and ns.Runs.Killed(dkey, i)
end

-- The right-click menu of a boss row (e: the row's head) on B: mark it killed or not.
function P.BossMenu(B, owner, e)
    local dkey = B.entry and B.entry.key
    local i = dkey and P.BossIndex(dkey, e.text)
    if not i or not ns.Runs.Encounters(dkey) then return end
    local killed = ns.Runs.Killed(dkey, i)
    W.Menu(owner, { { killed and RTEXT.unmark or RTEXT.mark, function()
        if not ns.Runs.Mark(dkey, i, not killed) then ns.msg(RTEXT.noMark) end
        ns.Refresh()
    end, tip = RTEXT.tip } })
end

---------------------------------------------------------------------------
-- The instance map
---------------------------------------------------------------------------
local MTEXT = {
    none = L["Für diese Instanz hat das Spiel keine Karte."],
    unknown = L["Amisia kennt die Karte dieser Instanz noch nicht. Betritt sie einmal, dann merkt sich Amisia ihre Ebenen."],
    floor = L["Ebene %d von %d"],
    hint = L["Mausrad: zoomen · Ziehen: verschieben"],
    prev = L["Ebene darüber"], next = L["Ebene darunter"],
}
local MAP_ARROW = "Interface\\Minimap\\MinimapArrow"

-- The art of a floor (uiMapID): { w, h, tileW, tileH, files }, or nil when the client has none.
local function floorArt(uiMap)
    local M = C_Map
    if not (M and M.GetMapArtLayers and M.GetMapArtLayerTextures) then return nil end
    local ok, layers = pcall(M.GetMapArtLayers, uiMap)
    local info = ok and type(layers) == "table" and layers[1] or nil
    if type(info) ~= "table" then return nil end
    local ok2, files = pcall(M.GetMapArtLayerTextures, uiMap, 1)
    if not ok2 or type(files) ~= "table" or #files == 0 then return nil end
    local w, h = tonumber(info.layerWidth), tonumber(info.layerHeight)
    local tw, th = tonumber(info.tileWidth), tonumber(info.tileHeight)
    if not (w and h and tw and th) or w <= 0 or h <= 0 or tw <= 0 or th <= 0 then return nil end
    return { w = w, h = h, tileW = tw, tileH = th, files = files }
end

-- The room the map has (its clip's size; before the first layout the page's).
local function roomOf(v)
    local w, h = v.clip:GetWidth() or 0, v.clip:GetHeight() or 0
    if w <= 0 then w = T.PAGE_W_NOW or T.PAGE_W end
    if h <= 0 then h = 300 end
    return w, h
end

-- Places the tiles at the zoom and the offset (kept inside the map's edges).
local function layoutMap(v)
    local art = v.art
    if not art then return end
    local rw, rh = roomOf(v)
    local fit = math.min(rw / art.w, rh / art.h)
    local s = fit * v.zoom
    local mw, mh = art.w * s, art.h * s
    -- the offset keeps the map in the room; smaller than the room it is centred
    local function clamp(o, size, room)
        if size <= room then return (room - size) / 2 end
        return math.max(room - size, math.min(0, o))
    end
    v.ox, v.oy = clamp(v.ox, mw, rw), clamp(v.oy, mh, rh)
    v.canvas:ClearAllPoints()
    v.canvas:SetPoint("TOPLEFT", v.clip, "TOPLEFT", v.ox, -v.oy)
    v.canvas:SetSize(mw, mh)
    local cols = math.ceil(art.w / art.tileW)
    for i, t in ipairs(v.tiles) do
        if i <= #art.files then
            local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", v.canvas, "TOPLEFT", c * art.tileW * s, -r * art.tileH * s)
            t:SetSize(art.tileW * s, art.tileH * s)
        end
    end
    v.scale = s
    if v.pin.x then
        v.pin:ClearAllPoints()
        v.pin:SetPoint("CENTER", v.canvas, "TOPLEFT", v.pin.x * mw, -v.pin.y * mh)
    end
end

-- The map view on B from top (a SetPoint offset) to the page's bottom: the floor row (arrows, the
-- floor's name and "Ebene 1 von 2", the hint), the map clipped under it.
function P.BuildMap(B, top)
    local M = D.MAP
    local v = CreateFrame("Frame", nil, B)
    v:SetPoint("TOPLEFT", 0, top)
    v:SetPoint("BOTTOMRIGHT", 0, B:Bottom())
    v.prev = W.ArrowButton(v, "left", M.ARROW, function() v.floor = v.floor - 1 P.FillMap(B, B.entry) end)
    v.prev:SetPoint("TOPLEFT", 0, -(M.BAR_H - M.ARROW) / 2)
    W.Tooltip(v.prev, MTEXT.prev)
    v.label = W.Text(v, T.FONT.title, M.LABEL_W)
    v.label:SetPoint("LEFT", v.prev, "RIGHT", M.GAP, 0)
    v.next = W.ArrowButton(v, "right", M.ARROW, function() v.floor = v.floor + 1 P.FillMap(B, B.entry) end)
    v.next:SetPoint("LEFT", v.label, "RIGHT", M.GAP, 0)
    W.Tooltip(v.next, MTEXT.next)
    v.hint = W.Text(v, T.FONT.hint, M.HINT_W)
    v.hint:SetPoint("TOPRIGHT", -T.LAYOUT.TEXT_X, -(M.BAR_H - 12) / 2)
    v.hint:SetJustifyH("RIGHT")
    v.hint:SetText(MTEXT.hint)
    v.inset = W.Inset(v)
    v.inset:SetPoint("TOPLEFT", 0, -(M.BAR_H + M.GAP))
    v.inset:SetPoint("BOTTOMRIGHT", 0, 0)
    v.clip = CreateFrame("Frame", nil, v.inset)
    v.clip:SetPoint("TOPLEFT", 3, -3)
    v.clip:SetPoint("BOTTOMRIGHT", -3, 3)
    if v.clip.SetClipsChildren then v.clip:SetClipsChildren(true) end
    v.canvas = CreateFrame("Frame", nil, v.clip)
    -- the last column and row of tiles reach past the map's edge
    if v.canvas.SetClipsChildren then v.canvas:SetClipsChildren(true) end
    v.tiles = {}
    v.pin = v.canvas:CreateTexture(nil, "OVERLAY")
    v.pin:SetTexture(MAP_ARROW)
    v.pin:SetSize(M.PIN, M.PIN)
    v.pin:Hide()
    v.none = W.Text(v.clip, T.FONT.dim, 400, true)
    v.none:SetPoint("CENTER")
    v.none:SetJustifyH("CENTER")
    v.none:SetText(MTEXT.none)
    v.floor, v.zoom, v.ox, v.oy = 1, 1, 0, 0
    -- the wheel zooms at the cursor, a drag moves the map
    v.clip:EnableMouse(true)
    v.clip:EnableMouseWheel(true)
    local function cursor()
        local x, y = GetCursorPosition()
        local sc = v.clip:GetEffectiveScale()
        sc = sc > 0 and sc or 1
        local left, top2 = v.clip:GetLeft() or 0, v.clip:GetTop() or 0
        return (x or 0) / sc - left, top2 - (y or 0) / sc
    end
    v.clip:SetScript("OnMouseWheel", function(_, delta)
        if not v.art then return end
        local old = v.zoom
        v.zoom = math.max(1, math.min(M.ZOOM_MAX, v.zoom * (delta > 0 and M.WHEEL or 1 / M.WHEEL)))
        local cx, cy = cursor()
        local k = v.zoom / old
        v.ox, v.oy = cx - (cx - v.ox) * k, cy - (cy - v.oy) * k
        layoutMap(v)
    end)
    v.clip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not v.art then return end
        local sx, sy = cursor()
        local ox, oy = v.ox, v.oy
        self:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate Journal map drag", function()
            local x, y = cursor()
            v.ox, v.oy = ox + (x - sx), oy + (y - sy)
            layoutMap(v)
        end))
    end)
    local function stop(self) self:SetScript("OnUpdate", nil) end
    v.clip:SetScript("OnMouseUp", stop)
    v.clip:SetScript("OnHide", stop)
    v.clip:SetScript("OnSizeChanged", function() layoutMap(v) end)
    v:Hide()
    B.mapView = v
    return v
end

-- The floors of a dungeon or raid key: the facts' maps, else the ones learned inside (Runs.lua), or
-- an empty list.
function P.Floors(dkey)
    local f = dkey and ns.Runs.Fact(dkey)
    if f and type(f.maps) == "table" and #f.maps > 0 then return f.maps end
    return f and ns.Runs.Floors(f.inst) or {}
end

-- Fills the map view with e's floor v.floor (another instance starts on its first floor, zoomed out).
function P.FillMap(B, e)
    local v = B.mapView
    local key = e and e.key
    if v.key ~= key then v.key, v.floor, v.zoom, v.ox, v.oy = key, 1, 1, 0, 0 end
    local floors = P.Floors(key)
    v.floor = math.max(1, math.min(#floors, v.floor))
    local uiMap = floors[v.floor]
    if v.uiMap ~= uiMap then v.zoom, v.ox, v.oy = 1, 0, 0 end
    v.uiMap = uiMap
    local art = uiMap and floorArt(uiMap) or nil
    v.art = art
    local name = ""
    if uiMap and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, uiMap)
        name = ok and type(info) == "table" and ns.Plain(info.name) or ""
    end
    v.label:SetText(#floors > 1 and ("%s  " .. GREY .. MTEXT.floor .. "|r"):format(name or "", v.floor, #floors) or (name or ""))
    v.prev:SetShown(#floors > 1)
    v.next:SetShown(#floors > 1)
    v.prev:SetEnabled(v.floor > 1)
    v.next:SetEnabled(v.floor < #floors)
    v.none:SetText(#floors == 0 and MTEXT.unknown or MTEXT.none)
    v.none:SetShown(art == nil)
    v.hint:SetShown(art ~= nil)
    for i = #v.tiles + 1, art and #art.files or 0 do v.tiles[i] = v.canvas:CreateTexture(nil, "ARTWORK") end
    for i, t in ipairs(v.tiles) do
        if art and art.files[i] then
            t:SetTexture(art.files[i])
            t:Show()
        else
            t:Hide()
        end
    end
    -- the player on this floor (inside the instance; the client may keep the place to itself)
    v.pin.x, v.pin.y = nil, nil
    if art and uiMap and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, uiMap, "player")
        if ok and pos and pos.GetXY then
            local x, y = pos:GetXY()
            x, y = tonumber(ns.Plain(x)), tonumber(ns.Plain(y))
            if x and y and x > 0 and y > 0 then v.pin.x, v.pin.y = x, y end
        end
    end
    v.pin:SetShown(v.pin.x ~= nil)
    layoutMap(v)
end

---------------------------------------------------------------------------
-- The keys
---------------------------------------------------------------------------
local ATEXT = {
    need = { required = L["nötig"], optional = L["optional"] },
    why = { door = L["öffnet die Instanz"], part = L["öffnet einen Teil"], summon = L["ruft einen Boss"],
        attune = L["Einstimmung"], boss = L["für einen Boss"] },
    have = L["vorhanden"], missing = L["fehlt"],
    step = L["%d. %s"], unknown = L["Quest %d"],
    stepTip = L["Klick: Wegpunkt zum Annehmen dieser Quest."],
    none = L["Für diese Instanz kennt Amisia keinen Schlüssel."],
}

-- The keys of a dungeon or raid key (the facts' keys), or nil without any.
function P.Keys(dkey)
    local f = dkey and ns.Runs.Fact(dkey)
    return f and type(f.keys) == "table" and #f.keys > 0 and f.keys or nil
end

-- Whether the character has item id (bags, bank, key ring).
local function hasItem(id)
    local f = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
    if type(f) ~= "function" then return false end
    local ok, n = pcall(f, id, true, false, true)
    return ok and (tonumber(ns.Plain(n)) or 0) > 0
end

P.HasItem = hasItem

-- The quests that lead to key k for the character's faction.
local function keyQuests(k)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local list = (faction == "Alliance" and k.questsA) or (faction == "Horde" and k.questsH) or k.quests
    return type(list) == "table" and list or {}
end

-- The rows of the keys: each key, then its steps; a step after an undone one is not to take yet.
local function accessRows(dkey)
    local out = {}
    for _, k in ipairs(P.Keys(dkey) or {}) do
        if type(k) == "table" and tonumber(k.item) then
            out[#out + 1] = { kind = "key", k = k, have = hasItem(k.item) }
            local before = false   -- an earlier step not done
            for i, qid in ipairs(keyQuests(k)) do
                local n = ns.Dungeons.QuestNode(qid)
                local st = n and ns.Dungeons.QuestState(n) or "open"
                if st == "open" and before then st = "locked" end
                if st ~= "done" then before = true end
                out[#out + 1] = { kind = "step", n = i, qid = qid, node = n, state = st }
            end
        end
    end
    return out
end

-- The keys view on B from top: a list of the keys (icon, name, why, have or not) and their steps
-- (state mark, title; a click sets the waypoint to where the quest is taken).
function P.BuildAccess(B, top)
    local A = D.ACCESS
    local list = W.List(B, 5, A.ROW_H, function(r)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(A.ICON, A.ICON)
        r.icon:SetPoint("LEFT", 4, 0)
        r.name = W.Text(r, T.FONT.text, 400)
        r.state = W.Text(r, T.FONT.text, A.STATE_W)
        r.state:SetPoint("RIGHT", -6, 0)
        r.state:SetJustifyH("RIGHT")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if e and e.kind == "step" then K.say(ns.DungeonQuestWaypoint(e.qid, true, "accept", B.entry and B.entry.key)) end
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if e.kind == "key" and GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(e.k.item)
            else
                GameTooltip:AddLine(ATEXT.stepTip, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        r.name:ClearAllPoints()
        if e.kind == "key" then
            local k = e.k
            local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(k.item)
            r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.icon:Show()
            r.name:SetPoint("LEFT", A.TEXT_X, 0)
            local why = ATEXT.why[k.why] or ""
            local need = ATEXT.need[k.need] or ""
            local tail = table.concat({ need, why }, " · "):gsub("^ · ", ""):gsub(" · $", "")
            r.name:SetText(K.itemText(k.item) .. (tail ~= "" and (GREY .. "  " .. tail .. "|r") or ""))
            r.state:SetText(e.have and (GREEN .. ATEXT.have .. "|r") or ("|cffff6060" .. ATEXT.missing .. "|r"))
        else
            r.icon:Hide()
            r.name:SetPoint("LEFT", A.TEXT_X + A.STEP_X, 0)
            local n, st = e.node, e.state
            local title = n and n.title or ATEXT.unknown:format(e.qid)
            r.name:SetText(ns.Dungeons.QuestStateIcon(st) .. " " .. ATEXT.step:format(e.n, (st == "done" or st == "gone") and (GREY .. title .. "|r") or title))
            r.state:SetText("")
        end
    end)
    list:SetPoint("TOPLEFT", 0, top)
    list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, top)
    W.FillTo(list, B, top, 5, A.ROW_H)
    list.empty = W.Text(list, T.FONT.dim, 400, true)
    list.empty:SetPoint("TOP", 0, -T.LAYOUT.EMPTY_Y)
    list.empty:SetText(ATEXT.none)
    list:Hide()
    B.accessView = list
    return list
end

function P.FillAccess(B, e)
    local rows = e and accessRows(e.key) or {}
    B.accessView:SetItems(rows)
    B.accessView.empty:SetShown(#rows == 0)
end

---------------------------------------------------------------------------
-- The times (F-166, Gear/RunTimes.lua)
---------------------------------------------------------------------------
P.TIMES_HINT = L["Die Uhr läuft ab dem ersten Kampf nach dem Betreten und hält beim letzten Boss; draußen und ausgeloggt läuft sie weiter. Zwischenzeit: seit dem Start. Nicht beendete Läufe zählen nie als Bestzeit. /amisia zeiten zeigt das Fenster."]
local TTEXT = {
    best = L["Bester Lauf"], bosses = L["Bestzeit je Boss"], runs = L["Letzte Läufe"],
    boss = L["Boss"], split = L["Im besten Lauf"], seg = L["Schnellste Strecke"],
    when = L["Wann"], total = L["Zeit"], size = L["Gruppe"], who = L["Charakter"],
    players = L["%d Spieler"], open = L["nicht beendet"], kills = L["%d/%d Bosse"],
    none = L["Noch keine Zeiten für diese Instanz. Die Uhr läuft ab dem ersten Kampf nach dem Betreten und hält beim letzten Boss."],
    clear = L["Zeiten löschen"],
    clearTip = L["Löscht nach einer Rückfrage Bestzeit, Zeiten je Boss und Verlauf dieser Instanz."],
    segTip = L["Schnellste Strecke: die kürzeste Zeit vom Boss davor (oder vom Start) bis zu diesem Boss, aus allen beendeten Läufen."],
}

-- The rows of the times of dkey: the best run, the bosses with the best run's split and the fastest
-- segment, the last runs (date, time or "nicht beendet", group size, character).
local function timesRows(dkey)
    local RT = ns.RunTimes
    local times = RT.Of(dkey)
    if not times then return {} end
    local out = {}
    local encs = ns.Runs.Encounters(dkey) or {}
    local best = times.best
    if best then
        out[#out + 1] = { kind = "head", cells = { TTEXT.best, TTEXT.total, TTEXT.size, TTEXT.who } }
        out[#out + 1] = { kind = "row", cells = { ns.FmtDayTime(best.at), RT.Fmt(best.t), TTEXT.players:format(best.n), best.c } }
    end
    out[#out + 1] = { kind = "head", cells = { TTEXT.bosses, TTEXT.split, TTEXT.seg, "" }, tip = TTEXT.segTip }
    for i, x in ipairs(RT.Lines(dkey, nil)) do
        out[#out + 1] = { kind = "row", cells = { ("%d. %s"):format(i, x.name), x.best and RT.Fmt(x.best) or (GREY .. "-|r"),
            x.seg and RT.Fmt(x.seg) or (GREY .. "-|r"), "" } }
    end
    if #times.runs > 0 then
        out[#out + 1] = { kind = "head", cells = { TTEXT.runs, TTEXT.total, TTEXT.size, TTEXT.who } }
        for _, r in ipairs(times.runs) do
            local kills = 0
            for _ in pairs(r.s) do kills = kills + 1 end
            local t = r.d and RT.Fmt(r.t) or (GREY .. TTEXT.open .. " · " .. TTEXT.kills:format(kills, #encs) .. "|r")
            out[#out + 1] = { kind = "row", cells = { ns.FmtDayTime(r.at), t, TTEXT.players:format(r.n), r.c } }
        end
    end
    return out
end
P.TimesRows = timesRows

-- The times view on B from top: a list of four cells per row (gold heads), and the link "Zeiten
-- löschen" (B.clearTimes, in the header's line beside the run).
function P.BuildTimes(B, top)
    local X = D.TIMES
    local list = W.List(B, 5, X.ROW_H, function(r)
        r.cells = {}
        for i = 1, 4 do
            local fs = W.Text(r, T.FONT.text, X.W[i])
            fs:SetPoint("LEFT", X.X[i], 0)
            r.cells[i] = fs
        end
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not (e and e.tip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(e.tip, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        for i = 1, 4 do
            r.cells[i]:SetFontObject(e.kind == "head" and T.FONT.head or T.FONT.text)
            r.cells[i]:SetText(e.cells[i] or "")
        end
    end)
    list:SetPoint("TOPLEFT", 0, top)
    list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, top)
    W.FillTo(list, B, top, 5, X.ROW_H)
    list.empty = W.Text(list, T.FONT.dim, 400, true)
    list.empty:SetPoint("TOP", 0, -T.LAYOUT.EMPTY_Y)
    list.empty:SetText(TTEXT.none)
    list:Hide()
    B.timesView = list
    B.clearTimes = W.Link(B, TTEXT.clear, function()
        if B.entry then ns.RunTimes.ConfirmClear(B.entry.key) end
    end)
    W.Tooltip(B.clearTimes, TTEXT.clear, TTEXT.clearTip)
    B.clearTimes:Hide()
    return list
end

-- The times of e on B; on: the part Zeiten shows (the link only then, and only with times).
function P.FillTimes(B, e, on)
    local rows = (e and on) and timesRows(e.key) or {}
    if on then
        B.timesView:SetItems(rows)
        B.timesView.empty:SetShown(#rows == 0)
    end
    B.clearTimes:SetShown(on and #rows > 0 or false)
end
end)
