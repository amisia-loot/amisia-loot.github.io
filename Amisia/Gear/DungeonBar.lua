-- The dungeon bar (F-168, D-98, AmisiaDungeonBar, tokens T.DUNGEONBAR): a small movable bar that shows
-- itself inside a dungeon the facts know (ns.Runs.Here; in a raid only with dungeonbar.raids) and hides
-- again on leaving. One row: the instance's name (the drag handle) and up to four segments, each only
-- when it has something to show and its setting is on:
--   "Bosse 2/5"   the bosses of the game's order (Runs.lua: the kills of the own run), a list with a
--                 tick on the killed ones and the next one in gold; a click opens the page on that boss
--                 (ns.ShowDungeonBoss)
--   "Quests 3"    the dungeon's quests the character has or can still get (ns.DungeonQuests,
--                 D.QuestState), the ready ones counted in green; a click on one opens its quest path
--                 in the quest journal (ns.ShowDungeonQuest), as the journal's own click does
--   "Zeit 12:40"  while the run's clock runs (RunTimes.lua): shows or hides the window "Lauf-Zeiten"
--   "Route 3/7"   while an own route is followed (Routes.lua): the stops, "Weiter" and "Folgen beenden";
--                 a right click goes on to the next stop
-- In a map of several dungeons (the Scarlet Monastery's four wings, the halves of Blackrock Spire; F-174,
-- D-106) the bar names the client's instance and lists the bosses and quests of all of them until the
-- first kill tells which one the character is in; from then on that one, with its own name.
-- The lists are the bar's own small panel (AmisiaDungeonBarList) under it, closed by a second click,
-- Escape and leaving the instance. The close circle hides the bar until the next entry or
-- `/amisia leiste`. A view on other modules: no data of its own, nothing sent. A plain frame without
-- protected calls, built the first time it shows (also in a fight after a /reload). Its place in
-- settings.dungeonBar, reset by "Fensterposition zurücksetzen".
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.DUNGEONBAR
local R = ns.Runs

local DBar = {}
ns.DungeonBar = DBar

local GREEN, GREY, GOLD = T.GREEN, T.GREY, T.GOLD_TEXT
local TICK_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:13:13|t"
local SEGMENTS = { "bosses", "quests", "time", "route" }
DBar.SEGMENTS = SEGMENTS

local bar, list
local key            -- the dungeon or raid key the bar shows (nil: hidden)
local cands          -- the keys of the map while the dungeon stood in is not known yet (nil: known)
local open           -- the segment whose list shows
local override       -- { entry = R.entry, show = true/false }: the close circle or /amisia leiste for this entry
local dirty = false

---------------------------------------------------------------------------
-- What the bar shows (each a view on another module)
---------------------------------------------------------------------------
local function isRaid(k) return ns.Dungeons ~= nil and ns.Dungeons.IsRaid(k) and true or false end

-- The key of the instance stood in (Runs.lua's), whether it is sure, and the keys of its map; nil
-- outside or in an instance the facts lack. While a map of several dungeons does not tell which one
-- (no kill since entering, D-106), a running clock's key of the same map stands in for the guess.
function DBar.Here()
    local k, sure, keys = R.Here()
    if not k then return nil end
    local l = ns.RunTimes and ns.RunTimes.Live()
    if not sure and l and l.k ~= k then
        local a, b = R.Fact(l.k), R.Fact(k)
        if a and b and a.inst == b.inst then k = l.k end
    end
    return k, sure ~= false, keys
end

-- The keys the bar lists for k: the candidates while the dungeon is not known, else k alone.
local function shownKeys(k)
    if k == key and cands then return cands end
    return { k }
end
DBar.ShownKeys = shownKeys

-- The bosses of k in the game's order: { { i, name, killed, next } }, killed count, total; nil
-- without an order. A boss counts as killed only when the facts know its encounter.
function DBar.Bosses(k)
    local f = R.Fact(k)
    local order = f and type(f.order) == "table" and #f.order > 0 and f.order or nil
    if not order then return nil end
    local out, n, nextSet = {}, 0, false
    for i, name in ipairs(order) do
        local killed = R.Killed(k, i)
        local b = { i = i, name = name, killed = killed }
        if killed then
            n = n + 1
        elseif not nextSet then
            b.next, nextSet = true, true
        end
        out[#out + 1] = b
    end
    return out, n, #order
end

-- The quests of dungeon k the character has or can still get (not done, not gone): { { q, state } },
-- ready ones first, then those in the log, open, locked; the count of ready ones. Raids: none (their
-- page has no quest journal).
local RANK = { ready = 1, active = 2, open = 3, locked = 4 }
function DBar.Quests(k)
    if not k or isRaid(k) or not ns.DungeonQuests then return {}, 0 end
    local D = ns.Dungeons
    local out, ready, seen, at = {}, 0, {}, 0
    -- the candidates' quests once each (a quest of several wings, D-106), each with its own key
    for _, sk in ipairs(shownKeys(k)) do
        for _, q in ipairs((ns.DungeonQuests(sk))) do
            local id = q.qid or q.title
            if not q.done and not q.gone and not seen[id] then
                seen[id] = true
                local st = D.QuestState(q)
                if RANK[st] then
                    at = at + 1
                    out[#out + 1] = { q = q, state = st, at = at, key = sk }
                    if st == "ready" then ready = ready + 1 end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if RANK[a.state] ~= RANK[b.state] then return RANK[a.state] < RANK[b.state] end
        return a.at < b.at
    end)
    return out, ready
end

-- The running clock in k's instance: the seconds so far and the clock's key, or nil.
function DBar.Clock(k)
    local RT = ns.RunTimes
    if not RT then return nil end
    local l, secs = RT.Live()
    if not l then return nil end
    local a, b = R.Fact(l.k), R.Fact(k)
    if l.k == k or (a and b and a.inst == b.inst) then return secs, l.k end
    return nil
end

-- The followed route: the current stop, the number of stops and the following record, or nil.
function DBar.Route()
    local f = ns.Routes and ns.Routes.Following()
    if not f or type(f.stops) ~= "table" or #f.stops == 0 then return nil end
    return f.i, #f.stops, f
end

---------------------------------------------------------------------------
-- The place
---------------------------------------------------------------------------
local function windowState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.dungeonBar) ~= "table" then AmisiaDB.settings.dungeonBar = {} end
    return AmisiaDB.settings.dungeonBar
end

local function place()
    if bar then W.PlaceWindow(bar, windowState(), "TOP", UIParent, "TOP", 0, -40) end
end

function ns.ResetDungeonBarPosition()
    local st = windowState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

---------------------------------------------------------------------------
-- The list under the bar
---------------------------------------------------------------------------
local function listRow(i)
    local r = CreateFrame("Button", nil, list)
    r:SetHeight(S.ROW_H)
    local y = -(S.PAD + (i - 1) * S.ROW_H)
    r:SetPoint("TOPLEFT", S.PAD, y)
    r:SetPoint("TOPRIGHT", -S.PAD, y)
    r.text = W.Text(r, T.FONT.text, S.ROW_NAME_W)
    r.text:SetPoint("LEFT", 2, 0)
    r.note = W.Text(r, T.FONT.hint, S.ROW_NOTE_W)
    r.note:SetPoint("RIGHT", -2, 0)
    r.note:SetJustifyH("RIGHT")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
        if self.run then self.run(button) end
    end)
    return r
end

local function buildList()
    if list then return list end
    list = CreateFrame("Frame", "AmisiaDungeonBarList", UIParent)
    list:SetFrameStrata("MEDIUM")
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list:SetWidth(S.LIST_W)
    W.Flat(list, 0, 0, 0, S.SHADE)
    W.Border(list, T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.5)
    list.rows = {}
    list:Hide()
    list:SetScript("OnHide", function() open = nil end)
    -- Escape closes the list (not the bar)
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaDungeonBarList") end
    return list
end

local function say(ok, why) if not ok and why then ns.msg(why) end end

-- The entries of a segment's list: { text, note, run = fn(button) }.
local entriesOf = {}
function entriesOf.bosses(k)
    local out = {}
    local keys = shownKeys(k)
    for _, sk in ipairs(keys) do
        if #keys > 1 then
            -- a candidate of a map of several (D-106): its name as a head
            local f = R.Fact(sk)
            out[#out + 1] = { text = GOLD .. (f and ns.Dungeons.Name(f) or sk) .. "|r", note = "", head = sk }
        end
        for _, b in ipairs((DBar.Bosses(sk)) or {}) do
            out[#out + 1] = b
            b.key = sk
        end
    end
    for n, b in ipairs(out) do
        if not b.head then out[n] = DBar.BossEntry(b.key, b) end
    end
    return out
end

-- The list entry of boss b (DBar.Bosses) of key k.
function DBar.BossEntry(k, b)
    local i = b.i
    local name = ("%d. %s"):format(i, b.name)
    local text, note
    if b.killed then
        text, note = TICK_ICON .. " " .. GREY .. name .. "|r", L["besiegt"]
    elseif b.next then
        text, note = GOLD .. name .. "|r", L["als Nächstes"]
    else
        text, note = name, ""
    end
    return { text = text, note = note, boss = i, key = k,
        run = function() if ns.ShowDungeonBoss then ns.ShowDungeonBoss(k, i) end end }
end
function entriesOf.quests(k)
    local out, D = {}, ns.Dungeons
    for _, e in ipairs((DBar.Quests(k))) do
        local q = e.q
        local qk = e.key or k
        -- a quest of the own log a member lacks: "fehlt 2" instead of the level (F-178)
        local GQ = ns.GroupQuests
        local lack = GQ and q.qid and GQ.CanShare(qk, q.qid) and #GQ.Lacking(qk, q.qid) or 0
        out[#out + 1] = { text = D.QuestStateIcon(e.state) .. " " .. (e.state == "ready" and GREEN .. q.title .. "|r" or q.title),
            note = lack > 0 and (GOLD .. L["fehlt %d##Gruppe"]:format(lack) .. "|r") or D.QuestLevelText(q), state = e.state, qid = q.qid, lack = lack,
            run = function() if ns.ShowDungeonQuest then ns.ShowDungeonQuest(qk, q.qid or q.title) end end }
    end
    return out
end
function entriesOf.route()
    local cur, n, f = DBar.Route()
    local out = {}
    if not cur then return out end
    for i = 1, n do
        local s = f.stops[i]
        local name = ("%d. %s"):format(i, s.l or L["Stopp %d"]:format(i))
        local text, note
        if i < cur then
            text, note = TICK_ICON .. " " .. GREY .. name .. "|r", ""
        elseif i == cur then
            text, note = GOLD .. name .. "|r", L["Ziel"]
        else
            text, note = name, ""
        end
        out[#out + 1] = { text = text, note = note }
    end
    out[#out + 1] = { text = GOLD .. L["Weiter zum nächsten Stopp"] .. "|r", note = "", run = function() say(ns.Routes.Next()) end }
    out[#out + 1] = { text = GOLD .. L["Folgen beenden"] .. "|r", note = "", run = function() ns.Routes.StopFollow() end }
    return out
end

local function fillList()
    if not (list and open and key) then return end
    local entries = entriesOf[open](key)
    if #entries == 0 then
        list:Hide()
        return
    end
    local n = math.min(#entries, S.MAX_ROWS)
    for i = 1, n do
        list.rows[i] = list.rows[i] or listRow(i)
        local r, e = list.rows[i], entries[i]
        r.text:SetText(e.text)
        r.note:SetText(e.note or "")
        r.run = e.run
        r.entry = e
        r:Show()
    end
    for i = n + 1, #list.rows do
        list.rows[i]:Hide()
        list.rows[i].run = nil
    end
    list:SetHeight(2 * S.PAD + n * S.ROW_H)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -S.LIST_GAP)
end

-- Opens the list of segment which, or closes it when it shows already (a second click).
function DBar.Toggle(which)
    if not (bar and bar:IsShown() and entriesOf[which]) then return false end
    buildList()
    if open == which and list:IsShown() then
        list:Hide()
        return false
    end
    open = which
    fillList()
    if #entriesOf[which](key) == 0 then
        open = nil
        return false
    end
    list:Show()
    return true
end

function DBar.ListShown() return list ~= nil and list:IsShown() and open or nil end

local function closeList()
    if list then list:Hide() end
    open = nil
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------
local TIPS = {
    bosses = { L["Bosse##Leiste"], L["Die Bosse dieses Dungeons in der Reihenfolge des Spiels; ein Klick auf einen öffnet ihn auf der Seite."] },
    quests = { L["Quests##Leiste"], L["Die Quests dieses Dungeons, die du hast oder noch bekommen kannst; grün: fertig zum Abgeben. Ein Klick auf eine öffnet ihren Weg im Quest-Journal."] ..
        " " .. L["In einer Gruppe: \"2 teilen\" sind Quests aus deinem Log, die anderen mit Amisia fehlen (\"fehlt 2\" in der Liste)."] },
    time = { L["Zeit##Leiste"], L["Die Uhr dieses Laufs; ein Klick zeigt oder verbirgt das Fenster \"Lauf-Zeiten\"."] },
    route = { L["Route##Leiste"], L["Die Route, der du folgst: Stopp und Anzahl. Rechtsklick: weiter zum nächsten Stopp."] },
}

local function clicked(which, button)
    if which == "time" then
        local _, ck = DBar.Clock(key)
        local TW = ns.RunTimer
        if not (ck and TW) then return end
        if TW.Shown() then TW.Hide() else TW.Show(ck) end
        return
    end
    if which == "route" and button == "RightButton" then
        say(ns.Routes.Next())
        return
    end
    DBar.Toggle(which)
end

local function layout()
    if not bar then return end
    local items = { bar.handle }
    for _, s in ipairs(SEGMENTS) do items[#items + 1] = bar.seg[s] end
    local at = W.Row(bar, items, S.GAP, S.PAD, -(S.H - T.CHIP_H) / 2, { shown = true })
    bar:SetWidth(at + S.GAP + S.CLOSE + S.PAD)
end

local function build()
    if bar then return bar end
    bar = CreateFrame("Frame", "AmisiaDungeonBar", UIParent)
    bar:SetSize(200, S.H)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    -- its ground takes the clicks, so none falls through to the world under it
    bar:EnableMouse(true)
    W.Flat(bar, 0, 0, 0, S.SHADE)
    W.Border(bar, T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.5)
    -- the name: the drag handle
    local h = CreateFrame("Frame", nil, bar)
    h:SetHeight(T.CHIP_H)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h.text = W.Text(h, T.FONT.head)
    h.text:SetPoint("LEFT", 0, 0)
    h:SetScript("OnDragStart", function() bar:StartMoving() end)
    h:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        W.SaveWindowPlace(bar, windowState())
    end)
    W.Tooltip(h, L["Dungeon-Leiste"], L["Ziehen: verschieben. Das x verbirgt die Leiste bis zum nächsten Dungeon oder \"/amisia leiste\"."])
    h:Show()
    bar.handle = h
    bar.seg = {}
    for _, s in ipairs(SEGMENTS) do
        local b = W.Link(bar, "", function(self, button) clicked(s, button) end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        W.Tooltip(b, TIPS[s][1], TIPS[s][2])
        b:Hide()
        bar.seg[s] = b
    end
    bar.close = W.ResetButton(bar, S.CLOSE, function() DBar.Close() end)
    bar.close:SetPoint("RIGHT", -S.PAD, 0)
    bar.close:Show()
    W.Tooltip(bar.close, L["Leiste schließen"], L["Bis zum nächsten Dungeon oder \"/amisia leiste\"."])
    -- the clock and the quest log, a few times a second while the bar shows
    local acc = 0
    bar:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < S.TICK then return end
        acc = 0
        if dirty then
            DBar.Refresh()
        elseif bar.seg.time:IsShown() then
            local secs = DBar.Clock(key)
            if secs then
                bar.seg.time:SetText(L["Zeit %s"]:format(ns.RunTimes.Fmt(secs)))
                layout()
            else
                DBar.Refresh()
            end
        end
    end)
    bar:Hide()
    place()
    return bar
end
DBar.Build = build

local function on(s) return ns.Get("dungeonbar." .. s) ~= false end

-- The segments' words for key k: { bosses = text or nil, ... }.
function DBar.Texts(k)
    local out = {}
    if on("bosses") then
        local keys = shownKeys(k)
        if #keys > 1 then
            -- not known yet which dungeon of the map (D-106): how many bosses the candidates have
            local m = 0
            for _, sk in ipairs(keys) do
                local _, _, mm = DBar.Bosses(sk)
                m = m + (mm or 0)
            end
            if m > 0 then out.bosses = L["Bosse %d"]:format(m) end
        else
            local bosses, n, m = DBar.Bosses(k)
            if bosses then
                out.bosses = R.Encounters(k) and L["Bosse %d/%d"]:format(n, m) or L["Bosse %d"]:format(m)
            end
        end
    end
    if on("quests") then
        local qs, ready = DBar.Quests(k)
        if #qs > 0 then
            out.quests = L["Quests %d"]:format(#qs) .. (ready > 0 and " " .. GREEN .. L["(%d fertig)"]:format(ready) .. "|r" or "")
            -- in a party: how many of the own quests in the log a member lacks (F-178, D-110)
            local share = ns.GroupQuests and ns.GroupQuests.ShareCount(shownKeys(k)) or 0
            if share > 0 then out.quests = out.quests .. " " .. GOLD .. L["· %d teilen"]:format(share) .. "|r" end
        end
    end
    if on("time") then
        local secs = DBar.Clock(k)
        if secs then out.time = L["Zeit %s"]:format(ns.RunTimes.Fmt(secs)) end
    end
    if on("route") then
        local i, n = DBar.Route()
        if i then out.route = L["Route %d/%d"]:format(i, n) end
    end
    return out
end

function DBar.Refresh()
    dirty = false
    if not (bar and key) then return end
    local f = R.Fact(key)
    -- a dungeon of a map of several once known (D-106): its own name, else the client's instance name
    local name = (not cands and f and f.part and ns.Dungeons.Name(f)) or (select(3, ns.RunTimes.InstanceNow()))
        or (f and f.name) or key
    local h = bar.handle
    h.text:SetText(name)
    h.text:SetWidth(math.min(S.NAME_W, math.max(1, h.text:GetStringWidth() or 0)))
    h:SetWidth(h.text:GetWidth())
    local texts = DBar.Texts(key)
    for _, s in ipairs(SEGMENTS) do
        local b = bar.seg[s]
        if texts[s] then
            b:SetText(texts[s])
            b:Show()
        else
            b:Hide()
        end
    end
    layout()
    -- an open list follows; one whose segment went closes
    if open then
        if texts[open] then fillList() else closeList() end
    end
end

---------------------------------------------------------------------------
-- Showing and hiding
---------------------------------------------------------------------------
-- Whether the bar shows in k now: the close circle or /amisia leiste for this entry, else the settings.
local function wanted(k)
    if not k then return false end
    if override and override.entry == R.entry then return override.show end
    if not ns.Get("dungeonbar.on") then return false end
    if isRaid(k) and not ns.Get("dungeonbar.raids") then return false end
    return true
end

function DBar.Update()
    local k, sure, keys = DBar.Here()
    if not wanted(k) then
        key, cands = nil, nil
        closeList()
        if bar then bar:Hide() end
        return
    end
    build()
    local c = (not sure and keys and #keys > 1) and keys or nil
    if k ~= key or (c == nil) ~= (cands == nil) then closeList() end
    key, cands = k, c
    DBar.Refresh()
    if not bar:IsShown() then
        -- at its saved place (a frame moved within the session stands there already)
        place()
        bar:Show()
    end
end

function DBar.Shown() return bar ~= nil and bar:IsShown() and key or nil end

-- The close circle: hidden until the next entry or /amisia leiste.
function DBar.Close()
    override = { entry = R.entry, show = false }
    DBar.Update()
end

-- `/amisia leiste`: shows or hides the bar now; outside an instance the facts know it says so.
function DBar.Slash()
    if not DBar.Here() then
        ns.msg(L["Die Dungeon-Leiste zeigt sich in einem Dungeon."])
        return false
    end
    override = { entry = R.entry, show = not DBar.Shown() }
    DBar.Update()
    return DBar.Shown() ~= nil
end

local function soon() dirty = true end

ns.OnEvent("PLAYER_ENTERING_WORLD", function() DBar.Update() end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() DBar.Update() end)
ns.Listen("RUN", function() if bar then DBar.Update() end end)
ns.Listen("RUNTIMES", function() if key then DBar.Refresh() end end)
ns.Listen("ROUTES", function(what) if key and what == "follow" then DBar.Refresh() end end)
ns.Listen("GROUP_QUESTS", function() if key then dirty = true end end)
for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
    ns.OnEvent(e, soon)
end

ns.RegisterSlash("leiste", { en = "bar", desc = L["Dungeon-Leiste: Bosse, Quests, Zeit und Route des Dungeons zeigen oder verbergen"],
    run = function() DBar.Slash() end })

local function apply() DBar.Update() end
ns.RegisterSettings{ key = "dungeonbar", label = L["Dungeon-Leiste"], order = 53, group = "dungeons", pages = { "dungeons" }, items = {
    { key = "dungeonbar.on", type = "toggle", label = L["Dungeon-Leiste zeigen"], default = true, onChange = apply,
      tip = L["Eine kleine Leiste mit Bossen, Quests, Zeit und Route, sobald du einen Dungeon betrittst; beim Verlassen verschwindet sie. Verschieben am Namen."] },
    { key = "dungeonbar.raids", type = "toggle", label = L["Auch in Raids"], default = false, onChange = apply,
      tip = L["Die Leiste zeigt sich auch in einem Raid (die Raid-Werkzeuge haben eigene Fenster)."] },
    { key = "dungeonbar.bosses", type = "toggle", label = L["Bosse in der Leiste"], default = true, onChange = apply,
      tip = L["\"Bosse 2/5\": die getöteten Bosse dieses Laufs, ein Klick zeigt die Liste."] },
    { key = "dungeonbar.quests", type = "toggle", label = L["Quests in der Leiste"], default = true, onChange = apply,
      tip = L["\"Quests 3\": die Quests dieses Dungeons, die du hast oder noch bekommen kannst, grün die fertigen."] },
    { key = "dungeonbar.time", type = "toggle", label = L["Zeit in der Leiste"], default = true, onChange = apply,
      tip = L["\"Zeit 12:40\": die Uhr des Laufs (Lauf-Zeiten), solange sie läuft."] },
    { key = "dungeonbar.route", type = "toggle", label = L["Route in der Leiste"], default = true, onChange = apply,
      tip = L["\"Route 3/7\": der Stopp der Route, der du folgst; Rechtsklick geht weiter."] },
} }

-- for the tests
function DBar._reset()
    override, open, dirty, cands = nil, nil, false, nil
    if list then list:Hide() end
end
