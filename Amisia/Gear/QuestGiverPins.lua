-- Amisia's dungeon quest givers on the world map (F-179, D-111): a small quest giver "!" with the
-- quest log's dungeon or raid mark at every known giver of a dungeon or raid quest the own character
-- can take now or within two levels (the planner's "bald") and that is not grey yet, on zone maps only. One pin per giver and
-- place, however many quests it hands out; the tooltip names per quest its level tag ("[D35]",
-- "[R60]"), its title and its dungeon; a click opens that dungeon's quests on the page Dungeons (a
-- raid's part Zugang on the page Raids), the first quest by level where a giver has several.
--
-- The quests come from the dungeon quest data (Data/DungeonQuestData.lua, its D lists) through
-- ns.Dungeons: D.OwnQuestState (F-178) for done, in the log, never ("na": faction, class, race, a quest
-- that excludes it) and locked, D.QuestNode for the giver and its points (what the collector saw itself
-- first). No pin for a quest that starts inside its dungeon, by an item, or whose giver has no known
-- place (the scan-only quests of F-177).
--
-- The pins stand on Amisia's own layer of the world map (MapPins.lua, D-64): Amisia's own buttons,
-- nothing of the map canvas, no hook, no data provider; the layer redraws on its own frame half a
-- second after a change (Map.RedrawSoon), never per frame. The pin sits a little up and right of the
-- giver's point, so a quest mark of the client or of another addon at the same giver stays readable.
-- Setting map.questGivers ("Dungeonquest-Geber auf der Karte", on).
local ADDON, ns = ...
local Map, W, D = ns.Map, ns.W, ns.Dungeons
local L = ns.L
local T = ns.Theme.GIVER_PIN

local G = {}
ns.QuestGivers = G

-- a giver shows this many levels before the quest is open to the own level: the planner's "bald" (D.Fit)
G.SOON = 2
local MAX_PINS = 40       -- per map, the lowest quests first
local MAX_LINES = 6       -- quest lines in the tooltip; past that five and "... und N weitere"
-- the quest giver's "!" of the gossip window (the file the quest page and the other quest giver pins use),
-- the badge: the quest log's dungeon or raid mark, else the map legend's
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local BADGE = { party = { "questlog-questtypeicon-dungeon", "Dungeon" }, raid = { "questlog-questtypeicon-raid", "Raid" } }
local MAP_TYPE = Enum and Enum.UIMapType
local ZONE = MAP_TYPE and MAP_TYPE.Zone or 3
local TEXT = {
    hint = L["Klick: %s in Amisia öffnen. Shift-Klick: Ziel setzen."],
    more = L["Rechtsklick: ausblenden."],
    others = L["... und %d weitere"],
    soon = L["ab %d"],
    open = L["In Amisia öffnen"],
    target = L["Ziel setzen"],
    off = L["Dungeonquest-Geber ausblenden"],
    giver = L["Questgeber %s"],
}

local report = ns.ReportError

---------------------------------------------------------------------------
-- Which quests and givers
---------------------------------------------------------------------------

local function factsByKey()
    local out = {}
    for _, e in ipairs(D.Facts() or {}) do
        if type(e) == "table" and type(e.key) == "string" then out[e.key] = e end
    end
    return out
end

-- The quest's level for the tag: its own, else the level it can be taken from; nil when neither is known.
local function levelOf(r)
    local lv = type(r[3]) == "number" and r[3] > 0 and r[3] or (type(r[2]) == "number" and r[2] > 0 and r[2]) or nil
    return lv
end

-- Whether a quest of the data gets a pin for the character o (ns.QuestOpts with the own level):
-- "open" (it can be taken now), "soon" (only the own level holds it back, by at most G.SOON levels) or
-- nil (done, in the log, never for this character, a pre-quest open, too far ahead).
function G.PinState(qid, o)
    local s = D.OwnQuestState(qid, o)
    if s == "open" then return "open" end
    if s ~= "locked" then return nil end
    local ahead = {}
    for k, v in pairs(o) do ahead[k] = v end
    ahead.level = (o.level or 1) + G.SOON
    return D.OwnQuestState(qid, ahead) == "open" and "soon" or nil
end

local function pointKey(giver, p)
    return ("%s@%d:%d:%d"):format(giver, p.map, math.floor(p.x * 1000 + 0.5), math.floor(p.y * 1000 + 0.5))
end

local function byLevel(a, b)
    if (a.level or 999) ~= (b.level or 999) then return (a.level or 999) < (b.level or 999) end
    if a.title ~= b.title then return a.title < b.title end
    return a.qid < b.qid
end

-- Every giver with a place, for the quests G.PinState lets through that are not grey for the own level
-- (D.GreyAt): { key, giver, point, quests = { { qid, title, level, minLevel, dkey, raid,
-- dname, state } } (lowest level first), soon (every quest only "soon"), raid (every quest a raid's) }.
local function buildGivers()
    local out = {}
    local dq = ns.DUNGEON_QUESTS
    if type(dq) ~= "table" or type(dq.D) ~= "table" or type(dq.Q) ~= "table" or not (Map and Map.ParsePoints) then return out end
    local o = {}
    for k, v in pairs(ns.QuestOpts and ns.QuestOpts() or {}) do o[k] = v end
    -- the level read now: the options are made once per state, a level-up's may still be the old one
    o.level = math.max(1, tonumber(ns.Plain(UnitLevel("player"))) or o.level or 1)
    local facts = factsByKey()
    local keys = {}
    for k in pairs(dq.D) do if type(k) == "string" and facts[k] then keys[#keys + 1] = k end end
    table.sort(keys)
    local byKey, seen = {}, {}
    for _, dkey in ipairs(keys) do
        local fact = facts[dkey]
        local raid = fact.kind == "raid"
        for _, qid in ipairs(type(dq.D[dkey]) == "table" and dq.D[dkey] or {}) do
            local r = type(qid) == "number" and dq.Q[qid] or nil
            if r and not seen[qid] then
                seen[qid] = true
                local state = G.PinState(qid, o)
                -- a quest already grey in the quest log (no XP any more): the dungeon is long behind
                local grey = state and levelOf(r) and D.GreyAt(levelOf(r))
                if grey and o.level >= grey then state = nil end
                local n = state and D.QuestNode(qid)
                -- not inside the dungeon, not by an item
                if n and n.start ~= "I" and n.start ~= "X" and not n.items then
                    local points = Map.ParsePoints(n.points)
                    local giver = n.object or n.giver or "?"
                    for _, p in ipairs(points) do
                        local k = pointKey(giver, p)
                        local e = byKey[k]
                        if not e then
                            e = { key = "Q:" .. qid, giver = giver, point = p, quests = {}, soon = true, raid = true }
                            byKey[k] = e
                            out[#out + 1] = e
                        end
                        e.quests[#e.quests + 1] = { qid = qid, title = n.title or r[1] or "?", level = levelOf(r),
                            minLevel = type(r[2]) == "number" and r[2] or 0, dkey = dkey, raid = raid, dname = D.Name(fact),
                            state = state }
                        if state == "open" then e.soon = false end
                        if not raid then e.raid = false end
                    end
                end
            end
        end
    end
    for _, e in ipairs(out) do
        table.sort(e.quests, byLevel)
        e.key = "Q:" .. e.quests[1].qid
    end
    return out
end

local gen = 0
local giversRes, giversStamp
local cache, cacheStamp = {}, nil

local function stamp()
    return ("%d:%s:%s:%s:%s"):format(gen, tostring(ns.DUNGEON_QUESTS), tostring(ns.HasData("MAP") and ns.Data("MAP")),
        tostring(ns.Plain(UnitLevel("player"))), tostring(ns.OwnFaction()))
end

-- Every giver with a place (see buildGivers), kept until a quest, the level, the data or a setting changes.
function G.Givers()
    local s = stamp()
    if s ~= giversStamp then
        giversRes, giversStamp = buildGivers(), s
    end
    return giversRes
end

-- The pins of a map: zone maps only (on a continent the givers of a city or a camp would lie on one
-- another), the lowest quests first, at most MAX_PINS. Each the giver's entry with x, y and dx, dy (the
-- pin's offset from the point).
function G.Pins(mapID)
    mapID = tonumber(mapID)
    if not mapID or not ns.Get("map.questGivers") or not Map.MapKindOf or Map.MapKindOf(mapID) ~= ZONE then return {} end
    local s = stamp()
    if s ~= cacheStamp then cache, cacheStamp = {}, s end
    local list = cache[mapID]
    if list then return list end
    list = {}
    for _, g in ipairs(G.Givers()) do
        local x, y = Map.ProjectPoint(g.point, mapID, ZONE)
        if x then
            local e = { x = x, y = y, dx = T.OFFSET, dy = T.OFFSET, continent = false }
            for k, v in pairs(g) do e[k] = v end
            list[#list + 1] = e
        end
    end
    table.sort(list, function(a, b)
        local qa, qb = a.quests[1], b.quests[1]
        if (qa.level or 999) ~= (qb.level or 999) then return (qa.level or 999) < (qb.level or 999) end
        return a.key < b.key
    end)
    for i = #list, MAX_PINS + 1, -1 do list[i] = nil end
    cache[mapID] = list
    return list
end

local function changed()
    gen = gen + 1
    if Map.RedrawSoon then Map.RedrawSoon() end
end
-- a quest taken, handed in or dropped, a level-up (Quests.lua fires QUESTS_CHANGED for all four)
ns.Listen("QUESTS_CHANGED", changed)
-- a giver or its place the collector saw itself
ns.Listen("COLLECT_CHANGED", function(kind)
    if kind == nil or kind == "q" then changed() end
end)
ns.Listen("SETTING", function(path)
    if path == "map.questGivers" then changed() end
end)

-- Test hook: forget what was built.
function G._reset()
    giversRes, giversStamp, cache, cacheStamp = nil, nil, {}, nil
    gen = gen + 1
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

-- "[D35]", "[R60]", "[D?]" for a quest of unknown level.
function G.Tag(q)
    return ("[%s%s]"):format(q.raid and "R" or "D", q.level and tostring(q.level) or "?")
end

-- The colour of a quest's level as the quest log shows it: the client's GetQuestDifficultyColor where
-- it answers, else by the level's distance (T.LEVEL).
function G.LevelColor(level)
    if not level then return T.LEVEL.grey end
    local f = _G.GetQuestDifficultyColor
    if type(f) == "function" then
        local ok, c = pcall(f, level)
        if ok and type(c) == "table" and type(ns.Plain(c.r)) == "number" then
            return { ns.Plain(c.r), ns.Plain(c.g) or 1, ns.Plain(c.b) or 1 }
        end
    end
    local my = tonumber(ns.Plain(UnitLevel("player"))) or 1
    local diff = level - my
    if diff >= 5 then return T.LEVEL.red end
    if diff >= 3 then return T.LEVEL.orange end
    if diff >= -2 then return T.LEVEL.yellow end
    local grey = D.GreyAt(level)
    if grey and my >= grey then return T.LEVEL.grey end
    return T.LEVEL.green
end

-- The tooltip's lines of a giver: { left, right, colour } per quest ("[D35] <title>", "<dungeon>" or
-- "<dungeon> · ab 33"), at most MAX_LINES, past that five and "... und N weitere" (colour nil).
function G.QuestLines(e)
    local out, n = {}, #e.quests
    local shown = n > MAX_LINES and MAX_LINES - 1 or n
    for i = 1, shown do
        local q = e.quests[i]
        local right = q.dname
        if q.state == "soon" and q.minLevel > 0 then right = right .. " · " .. TEXT.soon:format(q.minLevel) end
        out[#out + 1] = { G.Tag(q) .. " " .. q.title, right, G.LevelColor(q.level) }
    end
    if shown < n then out[#out + 1] = { TEXT.others:format(n - shown) } end
    return out
end

local function tooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.giver, 1, 0.82, 0)
    GameTooltip:AddLine(("%s %s"):format(Map.ZoneName(e.point.map), Map.Coords(e.point)), 0.7, 0.7, 0.7)
    for _, line in ipairs(G.QuestLines(e)) do
        local c = line[3]
        if c then
            GameTooltip:AddDoubleLine(line[1], line[2], c[1], c[2], c[3], 1, 1, 1)
        else
            GameTooltip:AddLine(line[1], 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine(TEXT.hint:format(e.quests[1].dname), 0.6, 0.6, 0.6)
    GameTooltip:AddLine(TEXT.more, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Clicks
---------------------------------------------------------------------------

-- Opens a dungeon quest's dungeon on the page Dungeons at its quest (the part Quests with its quest
-- path), a raid's on the page Raids at its part Zugang; the world map stays in front (F-011). In
-- combat, when the window does not come up, a line in the chat. Returns true when the window shows.
function G.Open(q)
    local ok, shown = pcall(function()
        if q.raid then return ns.ShowRaid and ns.ShowRaid(q.dkey, "access") end
        return ns.ShowDungeonQuest and ns.ShowDungeonQuest(q.dkey, q.qid)
    end)
    if not ok then report(shown) end
    if ok and shown then return true end
    if InCombatLockdown and InCombatLockdown() then
        ns.msg(L["Im Kampf öffnet Amisia das Fenster nicht. Nach dem Kampf noch einmal klicken."])
    end
    return false
end

local function setTarget(e)
    return ns.MapSetPoint(e.point, TEXT.giver:format(e.giver), e.key)
end

-- The menu: one entry per dungeon of the giver's quests (the first quest of each), the target, off.
function G.Menu(e)
    local entries, done = {}, {}
    local many = false
    for _, q in ipairs(e.quests) do
        if q.dkey ~= e.quests[1].dkey then many = true end
    end
    for _, q in ipairs(e.quests) do
        if not done[q.dkey] then
            done[q.dkey] = true
            entries[#entries + 1] = { many and (TEXT.open .. ": " .. q.dname) or TEXT.open, function() G.Open(q) end }
        end
    end
    entries[#entries + 1] = { TEXT.target, function() setTarget(e) end }
    entries[#entries + 1] = { TEXT.off, function() ns.Set("map.questGivers", false) end }
    return entries
end

local function click(self, button)
    local e = self.entry
    if not e then return end
    if button == "RightButton" then
        W.Menu(self, G.Menu(e))
    elseif button == "LeftButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then setTarget(e) else G.Open(e.quests[1]) end
    end
end

---------------------------------------------------------------------------
-- The pin: one of Amisia's own buttons on its layer of the world map (MapPins.lua)
---------------------------------------------------------------------------

local function setupPin(pin)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("CENTER")
    pin.icon:SetTexture(QUEST_ICON)
    pin.badge = pin:CreateTexture(nil, "OVERLAY")
    pin.badge:SetPoint("CENTER", pin, "BOTTOMRIGHT", -2, 2)
end

-- The atlas of a giver's badge: the quest log's mark, else the map legend's; nil without either.
function G.BadgeAtlas(raid)
    for _, a in ipairs(BADGE[raid and "raid" or "party"]) do
        if W.HasAtlas(a) then return a end
    end
    return nil
end

local function showPin(pin, e)
    pin.icon:SetTexture(QUEST_ICON)
    pin.icon:SetSize(T.SIZE, T.SIZE)
    local shade = e.soon and T.SOON or 1
    pin.icon:SetVertexColor(shade, shade, shade)
    local atlas = G.BadgeAtlas(e.raid)
    if atlas then
        pin.badge:SetAtlas(atlas)
        pin.badge:SetSize(T.BADGE, T.BADGE)
        pin.badge:Show()
    else
        pin.badge:Hide()
    end
    return T.SIZE, T.SIZE
end

local function enter(pin)
    local e = pin.entry
    if not e then return end
    local ok, err = pcall(tooltip, pin, e)
    if not ok then report(err) end
end

if Map.RegisterPinKind then
    Map.RegisterPinKind("giver", { setup = setupPin, show = showPin, click = click, enter = enter, list = G.Pins })
end
