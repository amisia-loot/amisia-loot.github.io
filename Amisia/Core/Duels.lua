-- Duels (F-106, spec docs/specs/2026-10-16-duelle.md, D-52): every duel the game announces in the
-- system chat, the own ones and (duels.nearby) those of other players nearby: "X has defeated Y in a
-- duel" (K, knockout) and "Y has fled from X in a duel" (F, retreat), read through the client's
-- templates DUEL_WINNER_KNOCKOUT / DUEL_WINNER_RETREAT, with the time and the own zone. The classes of
-- the players come from what the client knows anyway (the own character, the group, target, mouseover,
-- name plates with duels.plates, the guild roster, the friend list) and from /who on the player's
-- click ("Klassen suchen": the zone first, then one unknown name per click, every 5 s at most).
-- The specialisation (the talent tree with the most points) of the own character from its talents,
-- of the others (duels.inspect) by inspecting them while they stand near: one NotifyInspect every
-- 2 s, out of combat, never while the inspect window is open, each name once a session.
-- A simple tournament mode marks the duels between "Turnier starten" and "beenden". Nothing is sent.
-- Saved: AmisiaDB.duels { v = 1, list = { "<epoch>\t<winner>\t<loser>\t<zone nr>\t<K/F>[\t<tournament>]" },
-- zones = { names }, cls = { [name] = class token }, spec = { [name] = tree 1-3 },
-- tour = { n = last tournament, on = its start } }.
local ADDON, ns = ...
local L = ns.L

local D = {}
ns.Duels = D

D.MAX = 5000        -- duels kept (the newest)
D.DAYS = 90         -- and none older
D.MIN_GAMES = 3     -- the leaderboard ranks by win rate from this many duels on
local DEDUP = 3     -- the same pairing with the same result within this many seconds counts once
local WHO_GAP = 5   -- seconds between two /who of "Klassen suchen"
local WHO_WAIT = 6  -- an answer later than this is no longer awaited
local ASK_AGAIN = 600   -- a name asked by /who is asked again after this many seconds
local FILL_GAP = 10     -- the guild, friend and group pass at most this often
local INSPECT_GAP = 2   -- seconds between two inspect requests of Amisia
local INSPECT_WAIT = 4  -- an inspect answer later than this is no longer awaited
local INSPECT_RETRY = 120   -- a name whose inspect brought nothing is tried again after this many seconds
local QUEUE_AGE = 30    -- a unit waiting in the inspect queue longer than this has likely walked off
local NAME_MAX, ZONE_MAX = 48, 80

local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true,
                  MAGE = true, WARLOCK = true, DRUID = true }
D.CLASSES = CLASSES

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function int(v, lo, hi)
    return type(v) == "number" and v == math.floor(v) and v >= (lo or -math.huge) and v <= (hi or math.huge)
end

-- A name or zone as plain text (no codes, no tab, no bar), nil when empty or too long.
local function clean(s, max)
    if type(s) ~= "string" then return nil end
    s = s:match("^%s*(.-)%s*$")
    if s == "" or #s > max or s:find("[%c|]") then return nil end
    return s
end

local LINE = "^(%d+)\t([^\t]+)\t([^\t]+)\t(%d+)\t([KF])\t?(%d*)$"

local function db() return AmisiaDB and type(AmisiaDB.duels) == "table" and AmisiaDB.duels or nil end

-- Shapes AmisiaDB.duels: bad lines dropped, older than D.DAYS dropped, the newest D.MAX kept in time
-- order, the zones packed to those in use, classes only for names in the list. Twice changes nothing.
function ns.DuelsLoaded(root, now)
    now = now or time()
    local d = type(root.duels) == "table" and root.duels or {}
    root.duels = d
    local zones = type(d.zones) == "table" and d.zones or {}
    local rows = {}
    for _, s in ipairs(type(d.list) == "table" and d.list or {}) do
        local t, w, l, z, k, n
        if type(s) == "string" then t, w, l, z, k, n = s:match(LINE) end
        t, z, n = tonumber(t), tonumber(z), tonumber(n ~= "" and n or nil)
        if not int(n, 1, 99999) then n = nil end
        w, l = clean(w, NAME_MAX), clean(l, NAME_MAX)
        if t and w and l and w:lower() ~= l:lower() and t > now - D.DAYS * 86400 and t <= now + 86400 then
            rows[#rows + 1] = { t = t, w = w, l = l, z = clean(zones[z], ZONE_MAX), k = k, n = n }
        end
    end
    table.sort(rows, function(a, b) return a.t < b.t end)
    local from = math.max(1, #rows - D.MAX + 1)
    local list, packed, zoneNr, names = {}, {}, {}, {}
    for i = from, #rows do
        local r = rows[i]
        local nr = 0
        if r.z then
            nr = zoneNr[r.z]
            if not nr then
                packed[#packed + 1] = r.z
                nr = #packed
                zoneNr[r.z] = nr
            end
        end
        list[#list + 1] = ("%d\t%s\t%s\t%d\t%s"):format(r.t, r.w, r.l, nr, r.k) .. (r.n and ("\t" .. r.n) or "")
        names[r.w] = true
        names[r.l] = true
    end
    local cls, spec = {}, {}
    for name, token in pairs(type(d.cls) == "table" and d.cls or {}) do
        if names[name] and CLASSES[token] then cls[name] = token end
    end
    for name, tree in pairs(type(d.spec) == "table" and d.spec or {}) do
        if cls[name] and int(tree, 1, 3) then spec[name] = tree end
    end
    local tour = type(d.tour) == "table" and d.tour or {}
    tour = { n = int(tour.n, 0, 99999) and tour.n or 0, on = int(tour.on, 1) and tour.on <= now + 86400 and tour.on or nil }
    if tour.on and tour.n == 0 then tour.on = nil end
    for k in pairs(d) do d[k] = nil end
    d.v, d.list, d.zones, d.cls, d.spec, d.tour = 1, list, packed, cls, spec, tour
    return d
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then
        ns.DuelsLoaded(AmisiaDB)
        D.Changed()
    end
end)

---------------------------------------------------------------------------
-- The rows in memory (built on first use, dropped on a change)
---------------------------------------------------------------------------
local rowsCache     -- every duel, newest first: { t, w, l, z, k, n }
local players       -- lower name -> the name as recorded
local unknown       -- lower names without a class
local nUnknown = 0
local zoneNr        -- zone name -> its number in d.zones
local firsts        -- first name of a full name -> its lower name (false: two full names share it)

-- A new lower name of the duels: a full name is also found by its first name while that is unique.
local function addFirst(low)
    local first = low:match("^(%S+) ")
    if not first then return end
    if firsts[first] == nil then firsts[first] = low elseif firsts[first] ~= low then firsts[first] = false end
end

local function index()
    if players then return end
    players, unknown, nUnknown, zoneNr, firsts = {}, {}, 0, {}, {}
    local d = db()
    if not d then return end
    for i, z in ipairs(d.zones) do zoneNr[z] = i end
    for _, s in ipairs(d.list) do
        local _, w, l = s:match(LINE)
        for _, name in ipairs({ w, l }) do
            if name then
                local low = name:lower()
                if not players[low] then
                    players[low] = name
                    addFirst(low)
                    if not d.cls[name] then
                        unknown[low] = true
                        nUnknown = nUnknown + 1
                    end
                end
            end
        end
    end
end

-- Something changed (a duel, a class, a tournament): the rows are built again on the next read.
local statsCache   -- lower name -> the player's numbers over every duel (D.PlayerStats)

function D.Changed(classOnly)
    rowsCache, statsCache = nil, nil
    if not classOnly then players = nil end
    ns.Fire("DUELS")
end

-- Every duel, newest first: { t, w, l, z = zone text or nil, k = "K"/"F", n = tournament or nil, wc, lc,
-- ws, ls = the talent tree (1-3) or nil }.
function D.All()
    if rowsCache then return rowsCache end
    local d = db()
    local out = {}
    if d then
        for i = #d.list, 1, -1 do
            local t, w, l, z, k, n = d.list[i]:match(LINE)
            if t then
                out[#out + 1] = { t = tonumber(t), w = w, l = l, z = d.zones[tonumber(z)], k = k,
                                  n = tonumber(n ~= "" and n or nil), wc = d.cls[w], lc = d.cls[l],
                                  ws = d.spec[w], ls = d.spec[l] }
            end
        end
    end
    rowsCache = out
    return out
end

function D.Count() local d = db() return d and #d.list or 0 end

-- How many players of the duels have no class yet.
function D.UnknownCount()
    index()
    return nUnknown
end

function D.ClassOf(name)
    local d = db()
    return d and type(name) == "string" and d.cls[name] or nil
end

-- The talent tree (1-3) of a name of the duels, nil when not known.
function D.SpecOf(name)
    local d = db()
    return d and type(name) == "string" and d.spec[name] or nil
end

-- The name of a class's talent tree (the client's own text), nil without one.
function D.TreeName(class, tree)
    if not class or not tree or not ns.Talents or not ns.Talents.Class(class) then return nil end
    local name = ns.Talents.TreeName(class, tree)
    return name ~= "?" and name or nil
end

-- The players key (lower name) of a name: its own; for a first name alone the one full name of the
-- duels with it; for a full name the first name a duel message gave alone. nil for a name of no duel.
local function keyOf(name)
    if type(name) ~= "string" then return nil end
    local low = name:lower()
    if players[low] then return low end
    -- a first name alone (a client that gives no surname): the one full name with it
    if not low:find(" ", 1, true) and firsts[low] then return firsts[low] end
    low = low:match("^(%S+) ")
    return low and players[low] and low or nil
end

---------------------------------------------------------------------------
-- Classes
---------------------------------------------------------------------------
-- A name of the duels learns its class (a valid token, only when it has none). True when it did.
function D.Learn(name, token)
    token = ns.Plain(token)
    name = ns.Plain(name)
    if type(name) ~= "string" or not CLASSES[token] then return false end
    index()
    -- a duel message without the surname: the first name of a full name
    local low = keyOf(name)
    if not low or not unknown[low] then return false end
    local d = db()
    if not d then return false end
    d.cls[players[low]] = token
    unknown[low] = nil
    nUnknown = nUnknown - 1
    D.Changed(true)
    return true
end

local consider   -- puts a unit into the inspect queue (below)

-- A unit's player and class, learned when the name is one of the duels without a class; with
-- duels.inspect a duellist whose tree is not read yet goes into the inspect queue.
local function learnUnit(unit)
    local inspect = ns.Get("duels.inspect")
    if nUnknown == 0 and players and not inspect then return false end
    if type(UnitExists) == "function" and not ns.Plain(UnitExists(unit)) then return false end
    if type(UnitIsPlayer) == "function" and not ns.Plain(UnitIsPlayer(unit)) then return false end
    local n, s = UnitName(unit)
    n, s = ns.Plain(n), ns.Plain(s)
    local name = ns.FullName(n, s)
    if not name then return false end
    local _, token = UnitClass(unit)
    local learned = D.Learn(name, token)
    if inspect and consider then consider(unit, name) end
    return learned
end
D.LearnUnit = learnUnit

-- The client's class name (either gender) -> class token.
local byLocal
local function tokenOfName(text)
    if type(text) ~= "string" then return nil end
    if not byLocal then
        byLocal = {}
        local names = ns.Gear and ns.Gear.CLASS_NAMES or {}
        for token, n in pairs(names) do byLocal[n] = token end
        for _, list in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE or {}, _G.LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for token, n in pairs(list) do byLocal[n] = token end
        end
    end
    return byLocal[text] or (CLASSES[text] and text) or nil
end

local filledAt
-- The classes the client knows anyway: the group's units, the guild roster, the friend list, the
-- own character. At most every FILL_GAP seconds unless forced; nothing when every class is known.
function D.FillKnown(force)
    index()
    if nUnknown == 0 then return 0 end
    if not force and filledAt and GetTime() - filledAt < FILL_GAP then return 0 end
    filledAt = GetTime()
    local before = nUnknown
    learnUnit("player")
    local n = type(GetNumGroupMembers) == "function" and ns.Plain(GetNumGroupMembers()) or 0
    local raid = type(IsInRaid) == "function" and ns.Plain(IsInRaid())
    for i = 1, (type(n) == "number" and math.min(n, 40) or 0) do
        if nUnknown == 0 then break end
        learnUnit(raid and ("raid" .. i) or ("party" .. i))
    end
    if nUnknown > 0 and ns.GuildRoster then
        for _, m in ipairs(ns.GuildRoster() or {}) do
            D.Learn(m.name, m.class)
        end
    end
    local fl = _G.C_FriendList
    if nUnknown > 0 and type(fl) == "table" and type(fl.GetNumFriends) == "function" then
        for i = 1, (ns.Plain(fl.GetNumFriends()) or 0) do
            local f = fl.GetFriendInfoByIndex(i)
            local name = f and ns.FullName(ns.Plain(f.name))
            if name then D.Learn(name, tokenOfName(ns.Plain(f.className))) end
        end
    end
    return before - nUnknown
end

-- The name plates in sight (duels.plates).
local function learnPlates()
    if (nUnknown == 0 and not ns.Get("duels.inspect")) or not ns.Get("duels.plates") then return end
    local np = _G.C_NamePlate
    if type(np) ~= "table" or type(np.GetNamePlates) ~= "function" then return end
    for _, plate in ipairs(np.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if type(unit) == "string" then learnUnit(unit) end
    end
end

---------------------------------------------------------------------------
-- Specialisations: the talent tree with the most points
---------------------------------------------------------------------------
-- The tree with the most points (the first of equal ones), nil without points.
local function dominant(pts)
    if type(pts) ~= "table" then return nil end
    local best, most = nil, 0
    for i = 1, 3 do
        if type(pts[i]) == "number" and pts[i] > most then best, most = i, pts[i] end
    end
    return best
end
D.Dominant = dominant

-- A name of the duels with a known class learns its tree (1-3). True when it changed.
function D.LearnSpec(name, tree)
    local d = db()
    index()
    local low = keyOf(ns.Plain(name))
    if not d or not low or not int(tree, 1, 3) then return false end
    local rec = players[low]
    if not d.cls[rec] or d.spec[rec] == tree then return false end
    d.spec[rec] = tree
    D.Changed(true)
    return true
end

local ownAt
-- The own character's tree from its talents, when it is one of the duels (at most every FILL_GAP
-- seconds unless forced).
function D.LearnOwnSpec(force)
    if not force and ownAt and GetTime() - ownAt < FILL_GAP then return false end
    ownAt = GetTime()
    local me = ns.UnitFullName("player")
    index()
    if not ns.Talents or not keyOf(me) then return false end
    local _, token = UnitClass("player")
    D.Learn(me, token)
    return D.LearnSpec(me, dominant(ns.Talents.LiveTrees()))
end

-- The others by inspecting them (duels.inspect): a unit of a duellist (target, mouseover, a name
-- plate) whose tree was not read this session waits in the queue; one NotifyInspect every
-- INSPECT_GAP seconds, out of combat, outside the lockdown, never while the inspect window is
-- open; INSPECT_READY for that character reads the trees. Another inspect request in between (the
-- player's own, another addon's) makes Amisia drop its answer.
local queue = {}        -- { unit, low, at } oldest first
local pendingInspect    -- { guid, low, class, at } Amisia's request that waits for its answer
local inspectAt         -- GetTime() of Amisia's last request
local readAt = {}       -- lower name -> GetTime() its tree was read this session
local triedAt = {}      -- lower name -> GetTime() of the last request for it
local ownCall, hooked, pumpOn

local function wantsSpec(low)
    if not low or readAt[low] then return false end
    return not triedAt[low] or GetTime() - triedAt[low] > INSPECT_RETRY
end

local function inspectFrameShown()
    local f = _G.InspectFrame
    return type(f) == "table" and f.IsShown and f:IsShown() and true or false
end

-- Whether unit still is the player of key low.
local function unitIs(unit, low)
    if type(UnitExists) == "function" and not ns.Plain(UnitExists(unit)) then return false end
    local n, s = UnitName(unit)
    return keyOf(ns.FullName(ns.Plain(n), ns.Plain(s))) == low
end

local pump
local function schedule(sec)
    if pumpOn then return end
    pumpOn = true
    C_Timer.After(math.max(0.05, sec), function()
        pumpOn = nil
        pump()
    end)
end

pump = function()
    if not ns.Get("duels.inspect") or type(_G.NotifyInspect) ~= "function" then
        for i = #queue, 1, -1 do queue[i] = nil end
        return
    end
    local now = GetTime()
    if pendingInspect and now - pendingInspect.at < INSPECT_WAIT then return schedule(pendingInspect.at + INSPECT_WAIT - now) end
    pendingInspect = nil
    if inspectAt and now - inspectAt < INSPECT_GAP then return schedule(inspectAt + INSPECT_GAP - now) end
    local blocked = (type(UnitAffectingCombat) == "function" and ns.Plain(UnitAffectingCombat("player")))
        or inspectFrameShown() or (ns.ChatLocked and ns.ChatLocked())
    while #queue > 0 do
        local e = table.remove(queue, 1)
        if now - e.at <= QUEUE_AGE and wantsSpec(e.low) then
            if blocked then
                table.insert(queue, 1, e)
                break
            end
            local guid = unitIs(e.unit, e.low) and ns.Plain(UnitGUID(e.unit))
            local _, class = UnitClass(e.unit)
            class = ns.Plain(class)
            if type(guid) == "string" and CLASSES[class]
                and (type(CanInspect) ~= "function" or ns.Plain(CanInspect(e.unit))) then
                if not hooked and type(hooksecurefunc) == "function" then
                    hooked = true
                    hooksecurefunc("NotifyInspect", function() if not ownCall then pendingInspect = nil end end)
                end
                triedAt[e.low], inspectAt = now, now
                pendingInspect = { guid = guid, low = e.low, class = class, at = now }
                ownCall = true
                local ok = pcall(_G.NotifyInspect, e.unit)
                ownCall = nil
                if not ok then pendingInspect = nil end
                break
            end
        end
    end
    if pendingInspect then schedule(INSPECT_WAIT) elseif #queue > 0 then schedule(INSPECT_GAP) end
end

consider = function(unit, name)
    if unit == "player" or (type(UnitIsUnit) == "function" and ns.Plain(UnitIsUnit(unit, "player"))) then return end
    index()
    local low = keyOf(name)
    if not wantsSpec(low) or (pendingInspect and pendingInspect.low == low) then return end
    for _, e in ipairs(queue) do
        if e.low == low then
            e.unit, e.at = unit, GetTime()
            return
        end
    end
    if #queue >= 20 then return end
    queue[#queue + 1] = { unit = unit, low = low, at = GetTime() }
    schedule(0.2)
end

ns.OnEvent("INSPECT_READY", function(guid)
    local p = pendingInspect
    if not p or ns.Plain(guid) ~= p.guid then return end
    pendingInspect = nil
    local tree = dominant(ns.Talents and ns.Talents.InspectTrees(p.class))
    if tree then
        readAt[p.low] = GetTime()
        index()
        if players[p.low] then
            D.Learn(players[p.low], p.class)
            D.LearnSpec(players[p.low], tree)
        end
    end
    if type(ClearInspectPlayer) == "function" and not inspectFrameShown() then pcall(ClearInspectPlayer) end
end)

ns.OnEvent("PLAYER_TARGET_CHANGED", function() index() learnUnit("target") end)
ns.OnEvent("UPDATE_MOUSEOVER_UNIT", function() index() learnUnit("mouseover") end)
ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit)
    index()
    if ns.Get("duels.plates") and type(unit) == "string" then learnUnit(unit) end
end)

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------
local compiled = {}
-- A client template as a pattern and the order of its two names ("%2$s ... %1$s": the loser first).
local function compile(global)
    local t = ns.Plain(rawget(_G, global))
    if type(t) ~= "string" then return nil end
    local c = compiled[t]
    if c == nil then
        local order = {}
        for nr in t:gmatch("%%(%d+)%$s") do order[#order + 1] = tonumber(nr) end
        if #order ~= 2 then order = { 1, 2 } end
        local p = ns.TemplatePattern(t)
        c = p and { p = p, order = order } or false
        compiled[t] = c
    end
    return c or nil
end

local KINDS = { { "DUEL_WINNER_KNOCKOUT", "K" }, { "DUEL_WINNER_RETREAT", "F" } }

-- A system message as a duel: winner, loser, "K" or "F"; nil for any other message.
function D.Parse(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return nil end
    for _, m in ipairs(KINDS) do
        local c = compile(m[1])
        local a, b
        if c then a, b = text:match(c.p) end
        if a and b then
            local got = {}
            got[c.order[1]], got[c.order[2]] = a, b
            local w, l = clean(ns.TemplateName(got[1]), NAME_MAX), clean(ns.TemplateName(got[2]), NAME_MAX)
            if w and l and w:lower() ~= l:lower() then return w, l, m[2] end
        end
    end
    return nil
end

-- The own zone, "Zone · Subzone" when the subzone says more.
local function place()
    local z = clean(ns.Plain(type(GetRealZoneText) == "function" and GetRealZoneText() or nil), 40)
    local s = clean(ns.Plain(type(GetSubZoneText) == "function" and GetSubZoneText() or nil), 36)
    if z and s and s ~= z then return z .. " · " .. s end
    return z
end

local lastKey, lastAt

-- Keeps one duel (also for the tests). Returns true when it was kept.
function D.Record(w, l, k)
    local d = db()
    if not d or not ns.Get("duels.record") then return false end
    if k ~= "K" and k ~= "F" then return false end
    local me = ns.UnitFullName("player")
    local own = ns.SameName(w, me) or ns.SameName(l, me)
    if not own and not ns.Get("duels.nearby") then return false end
    local key = w:lower() .. "\t" .. l:lower() .. "\t" .. k
    if lastKey == key and GetTime() - lastAt < DEDUP then return false end
    lastKey, lastAt = key, GetTime()
    index()
    local z, nr = place(), 0
    if z then
        nr = zoneNr[z]
        if not nr then
            d.zones[#d.zones + 1] = z
            nr = #d.zones
            zoneNr[z] = nr
        end
    end
    -- a name keeps the spelling it was first recorded with
    w, l = players[w:lower()] or w, players[l:lower()] or l
    local tour = d.tour.on and d.tour.n or nil
    d.list[#d.list + 1] = ("%d\t%s\t%s\t%d\t%s"):format(time(), w, l, nr, k) .. (tour and ("\t" .. tour) or "")
    if #d.list > D.MAX + 100 then
        ns.DuelsLoaded(AmisiaDB)
        D.Changed()
    else
        for _, name in ipairs({ w, l }) do
            local low = name:lower()
            if not players[low] then
                players[low] = name
                addFirst(low)
                if not d.cls[name] then
                    unknown[low] = true
                    nUnknown = nUnknown + 1
                end
            end
        end
        D.Changed(true)
    end
    index()
    -- what the client knows now: the two are in sight
    learnUnit("target")
    learnUnit("mouseover")
    learnPlates()
    D.FillKnown(true)
    if own then D.LearnOwnSpec(true) end
    return true
end

ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    if not ns.Get("duels.record") then return end
    local w, l, k = D.Parse(text)
    if w then D.Record(w, l, k) end
end)

---------------------------------------------------------------------------
-- /who on the player's click
---------------------------------------------------------------------------
local whoAt         -- GetTime() of the last /who
local pending       -- { at, q, before } the /who that waits for its answer
local asked = {}    -- lower name or "z:<zone>" -> GetTime() when asked
local whoUiSet      -- Amisia turned SetWhoToUi on for its question

local function fl() local f = _G.C_FriendList return type(f) == "table" and f or nil end

-- The client's who list is shown (it keeps the answers itself then).
local function whoListShown()
    for _, name in ipairs({ "LFGParentFrame", "WhoFrame" }) do
        local f = _G[name]
        if type(f) == "table" and f.IsShown and f:IsShown() then return true end
    end
    return false
end

local function restoreWhoUi()
    if whoUiSet and fl() and type(fl().SetWhoToUi) == "function" and not whoListShown() then
        pcall(fl().SetWhoToUi, false)
    end
    whoUiSet = nil
end

-- Seconds until "Klassen suchen" may ask again (0: now).
function D.WhoWait()
    if pending and GetTime() - pending.at < WHO_WAIT then return math.ceil(WHO_WAIT - (GetTime() - pending.at)) end
    if not whoAt then return 0 end
    return math.max(0, math.ceil(WHO_GAP - (GetTime() - whoAt)))
end

-- The client's who tag ("z-", "n-"), as its own who window builds its question.
local function tag(global, default)
    local t = ns.Plain(rawget(_G, global))
    return type(t) == "string" and t:match("^%a+%-$") and t or default
end

-- The next question: the own zone once, then the unknown names, newest duel first.
local function nextQuery()
    local now = GetTime()
    local z = ns.Plain(type(GetRealZoneText) == "function" and GetRealZoneText() or nil)
    z = clean(z, 40)
    if z and not z:find('"', 1, true) and (not asked["z:" .. z] or now - asked["z:" .. z] > ASK_AGAIN) then
        return ('%s"%s"'):format(tag("WHO_TAG_ZONE", "z-"), z), "z:" .. z
    end
    for _, r in ipairs(D.All()) do
        for _, name in ipairs({ r.w, r.l }) do
            local low = name:lower()
            if unknown[low] and (not asked[low] or now - asked[low] > ASK_AGAIN) and not name:find('"', 1, true) then
                -- the first name only: the who list matches parts of names, a surname may not be searched
                return ('%s"%s"'):format(tag("WHO_TAG_NAME", "n-"), name:match("^(%S+)")), low
            end
        end
    end
    return nil
end

-- "Klassen suchen" (inside the click: the client allows /who only on a key press or click).
-- Returns true, or nil and the reason.
function D.WhoAsk()
    local f = fl()
    if not f or type(f.SendWho) ~= "function" then return nil, L["Das Spiel bietet hier keine /who-Abfrage."] end
    index()
    if nUnknown == 0 then return nil, L["Alle Klassen sind bekannt."] end
    if ns.ChatLocked and ns.ChatLocked() then return nil, L["Nicht in der Kampfsperre."] end
    if D.WhoWait() > 0 then return nil, L["Bitte warten (%d s)."]:format(D.WhoWait()) end
    local q, key = nextQuery()
    if not q then return nil, L["Alle unbekannten Namen sind gefragt; die übrigen sind offline oder anderswo. In 10 Minuten wieder."] end
    if type(f.SetWhoToUi) == "function" and not whoListShown() then
        whoUiSet = pcall(f.SetWhoToUi, true) or nil
    end
    local ok = pcall(f.SendWho, q)
    if not ok then
        restoreWhoUi()
        return nil, L["Die /who-Abfrage ging nicht."]
    end
    asked[key] = GetTime()
    whoAt = GetTime()
    pending = { at = whoAt, q = q, before = nUnknown, shown = whoListShown() }
    C_Timer.After(WHO_WAIT, function()
        if pending and GetTime() - pending.at >= WHO_WAIT - 0.01 then
            pending = nil
            restoreWhoUi()
            ns.Fire("DUELS")
        end
    end)
    ns.Fire("DUELS")
    return true
end

-- The answer of a /who (Amisia's or the player's own): every name of the duels learns its class.
ns.OnEvent("WHO_LIST_UPDATE", function()
    local f = fl()
    if not f or type(f.GetNumWhoResults) ~= "function" then return end
    index()
    local n = ns.Plain(f.GetNumWhoResults()) or 0
    for i = 1, math.min(type(n) == "number" and n or 0, 50) do
        local info = f.GetWhoInfo(i)
        if type(info) == "table" then
            local name = ns.FullName(ns.Plain(info.fullName))
            if name then D.Learn(name, info.filename) end
        end
    end
    if pending then
        local got = pending.before - nUnknown
        local q, shown = pending.q, pending.shown
        pending = nil
        -- the client's who list opens itself on every answer: closed before the question, it is
        -- closed again (after its own handler ran), then SetWhoToUi back
        if not shown then
            C_Timer.After(0, function()
                local fr = _G.LFGParentFrame
                if type(fr) == "table" and fr.IsShown and fr:IsShown() and type(HideUIPanel) == "function" then
                    pcall(HideUIPanel, fr)
                end
                restoreWhoUi()
            end)
        else
            restoreWhoUi()
        end
        ns.msg(L["Duelle: /who %s brachte %d Klassen, %d noch unbekannt."]:format(q, math.max(0, got), nUnknown))
        ns.Fire("DUELS")
    end
end)

---------------------------------------------------------------------------
-- Tournament
---------------------------------------------------------------------------
-- { n = the last tournament (0: none yet), on = its start while it runs }
function D.Tour()
    local d = db()
    return d and d.tour or { n = 0 }
end

function D.TourStart()
    local d = db()
    if not d or d.tour.on then return false end
    d.tour.n = d.tour.n + 1
    d.tour.on = time()
    D.Changed(true)
    return true
end

function D.TourStop()
    local d = db()
    if not d or not d.tour.on then return false end
    d.tour.on = nil
    D.Changed(true)
    return true
end

---------------------------------------------------------------------------
-- What the page shows
---------------------------------------------------------------------------
local function matches(name, q) return q == "" or ns.Fold(name):find(q, 1, true) ~= nil end

-- The epoch from which a time range counts: "day" since midnight, "week" the last 7 days, "month" the
-- last 30; nil for "all" (or anything else).
function D.Since(range, now)
    now = now or time()
    if range == "day" then
        local t = date("*t", now)
        return now - ((t.hour or 0) * 3600 + (t.min or 0) * 60 + (t.sec or 0))
    end
    if range == "week" then return now - 7 * 86400 end
    if range == "month" then return now - 30 * 86400 end
    return nil
end

-- The duels the filters leave, newest first. opts: { query (part of a name), player (exactly this
-- name, instead of query), class, tour = true (the last tournament), since = epoch }
function D.Filter(opts)
    opts = opts or {}
    local since = type(opts.since) == "number" and opts.since or nil
    local q = ns.Fold((opts.query or ""):match("^%s*(.-)%s*$"))
    local one = type(opts.player) == "string" and opts.player:lower() or nil
    local cls = opts.class ~= "all" and opts.class or nil
    local tourNr = opts.tour and D.Tour().n or nil
    local out = {}
    for _, r in ipairs(D.All()) do
        local who
        if one then who = r.w:lower() == one or r.l:lower() == one else who = matches(r.w, q) or matches(r.l, q) end
        if (not tourNr or r.n == tourNr) and who and (not since or r.t >= since)
            and (not cls or r.wc == cls or r.lc == cls) then
            out[#out + 1] = r
        end
    end
    return out
end

local function rate(w, g) return g > 0 and w / g or 0 end

-- The numbers of every player over rows (newest first): lower name -> { name, c, s, g, w, l, r,
-- streak = wins (> 0) or losses (< 0) in a row up to the newest duel, best = the longest run of
-- wins, foes = { [lower name] = { name, w, l } } }.
function D.Stats(rows)
    local by = {}
    local function entry(name, c, t)
        local low = name:lower()
        local e = by[low]
        if not e then
            e = { name = name, c = c, s = t, g = 0, w = 0, l = 0, streak = 0, open = true, best = 0, run = 0, foes = {} }
            by[low] = e
        end
        return e
    end
    local function side(e, won, other)
        e.g = e.g + 1
        if won then e.w = e.w + 1 else e.l = e.l + 1 end
        -- newest first: the streak grows while the results stay the same
        if e.open then
            if e.streak == 0 or (e.streak > 0) == won then
                e.streak = e.streak + (won and 1 or -1)
            else
                e.open = false
            end
        end
        local f = e.foes[other:lower()]
        if not f then
            f = { name = other, w = 0, l = 0 }
            e.foes[other:lower()] = f
        end
        if won then f.w = f.w + 1 else f.l = f.l + 1 end
    end
    for _, r in ipairs(rows) do
        side(entry(r.w, r.wc, r.ws), true, r.l)
        side(entry(r.l, r.lc, r.ls), false, r.w)
    end
    -- the longest run of wins, oldest first
    for i = #rows, 1, -1 do
        local r = rows[i]
        local w, l = by[r.w:lower()], by[r.l:lower()]
        w.run = w.run + 1
        if w.run > w.best then w.best = w.run end
        l.run = 0
    end
    for _, e in pairs(by) do
        e.r = rate(e.w, e.g)
        e.open, e.run = nil, nil
    end
    return by
end

-- A player's numbers over every duel (D.Stats of D.All, kept until the next change), found by his
-- name as recorded or as a unit gives it (a full name for a duel message's first name). nil for a
-- player of no duel.
function D.PlayerStats(name)
    if type(name) ~= "string" then return nil end
    index()
    local low = keyOf(name)
    if not low then return nil end
    if not statsCache then statsCache = D.Stats(D.All()) end
    return statsCache[players[low]:lower()]
end

-- The foe who beat e most often (more defeats than wins against him) and the one e beat most often
-- (more wins than defeats): { name, w, l } or nil each.
function D.Rivals(e)
    local nemesis, favourite
    for _, f in pairs(e and e.foes or {}) do
        if f.l > f.w and (not nemesis or f.l - f.w > nemesis.l - nemesis.w
            or (f.l - f.w == nemesis.l - nemesis.w and f.l > nemesis.l)) then nemesis = f end
        if f.w > f.l and (not favourite or f.w - f.l > favourite.w - favourite.l
            or (f.w - f.l == favourite.w - favourite.l and f.w > favourite.w)) then favourite = f end
    end
    return nemesis, favourite
end

-- The leaderboard of rows: { name, c, s = tree, g, w, l, r }, those matching query and class; sorted by
-- sort ("rate": the win rate of the players with D.MIN_GAMES duels first, then the rest by games;
-- "games", "wins", "name"), desc turns it round.
function D.Board(rows, opts)
    opts = opts or {}
    local q = ns.Fold((opts.query or ""):match("^%s*(.-)%s*$"))
    local one = type(opts.player) == "string" and opts.player:lower() or nil
    local cls = opts.class ~= "all" and opts.class or nil
    local by = {}
    local out = {}
    local function side(name, c, won, t)
        local e = by[name]
        if not e then
            e = { name = name, c = c, s = t, g = 0, w = 0, l = 0, fold = ns.Fold(name) }
            by[name] = e
            out[#out + 1] = e
        end
        e.g = e.g + 1
        if won then e.w = e.w + 1 else e.l = e.l + 1 end
    end
    for _, r in ipairs(rows) do
        side(r.w, r.wc, true, r.ws)
        side(r.l, r.lc, false, r.ls)
    end
    local keep = {}
    for _, e in ipairs(out) do
        e.r = rate(e.w, e.g)
        local who = one and e.name:lower() == one or (not one and (q == "" or e.fold:find(q, 1, true)))
        if who and (not cls or e.c == cls) then keep[#keep + 1] = e end
    end
    local sort, desc = opts.sort or "rate", opts.desc
    table.sort(keep, function(a, b)
        local x, y
        if sort == "games" then x, y = a.g, b.g
        elseif sort == "wins" then x, y = a.w, b.w
        elseif sort == "name" then x, y = b.fold, a.fold
        else
            local ra, rb = a.g >= D.MIN_GAMES, b.g >= D.MIN_GAMES
            if ra ~= rb then return ra end
            if ra then x, y = a.r, b.r else x, y = a.g, b.g end
        end
        if x ~= y then
            if desc then return x < y end
            return x > y
        end
        if a.g ~= b.g then return a.g > b.g end
        return a.fold < b.fold
    end)
    for i, e in ipairs(keep) do e.rank = i end
    return keep
end

-- The classes of rows (bySpec: per class and talent tree, t = the tree; sides without a known tree
-- left out). Without a class: per class the sides it played { c, g, p = players, w, l, r,
-- specs = { [tree] = { g, w, l } } for the sides with a known tree }, by win rate; with one: how
-- that class did against each class (a mirror duel counts once, won and lost). Also { known sides,
-- all sides } for the coverage.
function D.ClassTable(rows, class, bySpec)
    class = class ~= "all" and class or nil
    local by, out = {}, {}
    local known, sides = 0, 0
    -- a side counts with its class, by specialisation only with its tree too
    local function keyOfSide(c, t)
        if not c or (bySpec and not t) then return nil end
        return bySpec and (c .. t) or c
    end
    local function entry(c, t)
        local key = keyOfSide(c, t)
        local e = by[key]
        if not e then
            e = { key = key, c = c, t = bySpec and t or nil, g = 0, w = 0, l = 0, p = 0, seen = {}, specs = {} }
            by[key] = e
            out[#out + 1] = e
        end
        return e
    end
    local function tree(e, t, won)
        if not t or bySpec then return end
        local s = e.specs[t]
        if not s then
            s = { g = 0, w = 0, l = 0 }
            e.specs[t] = s
        end
        s.g = s.g + 1
        if won then s.w = s.w + 1 else s.l = s.l + 1 end
    end
    local function player(e, name)
        if not e.seen[name] then
            e.seen[name] = true
            e.p = e.p + 1
        end
    end
    for _, r in ipairs(rows) do
        sides = sides + 2
        local wk, lk = keyOfSide(r.wc, r.ws), keyOfSide(r.lc, r.ls)
        if wk then known = known + 1 end
        if lk then known = known + 1 end
        if not class then
            if wk then
                local e = entry(r.wc, r.ws)
                e.g, e.w = e.g + 1, e.w + 1
                player(e, r.w)
                tree(e, r.ws, true)
            end
            if lk then
                local e = entry(r.lc, r.ls)
                e.g, e.l = e.g + 1, e.l + 1
                player(e, r.l)
                tree(e, r.ls, false)
            end
        elseif r.wc and r.lc and (r.wc == class or r.lc == class) then
            local winnerIs = r.wc == class
            local oc, ot = r.lc, r.ls
            if not winnerIs then oc, ot = r.wc, r.ws end
            if keyOfSide(oc, ot) then
                local e = entry(oc, ot)
                e.g = e.g + 1
                if r.wc == class then e.w = e.w + 1 end
                if r.lc == class then e.l = e.l + 1 end
                player(e, winnerIs and r.l or r.w)
            end
        end
    end
    for _, e in ipairs(out) do
        e.r = e.c == class and 0.5 or rate(e.w, e.w + e.l)
        e.seen = nil
    end
    table.sort(out, function(a, b)
        if a.r ~= b.r then return a.r > b.r end
        if a.g ~= b.g then return a.g > b.g end
        return a.key < b.key
    end)
    for i, e in ipairs(out) do e.rank = i end
    return out, known, sides
end

---------------------------------------------------------------------------
-- Settings and the command
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "duels", label = L["Duelle"], order = 70, group = "pvp", pages = { "duels" }, items = {
    { key = "duels.record", type = "toggle", label = L["Duelle mitschreiben"], default = true,
      tip = L["Amisia schreibt jedes Duell mit, das das Spiel im Chat meldet: Sieger, Verlierer, Zeit und Ort."] },
    { key = "duels.nearby", type = "toggle", label = L["Auch fremde Duelle in der Nähe"], default = true,
      tip = L["Auch die Duelle anderer Spieler in deiner Nähe (das Spiel meldet sie allen im Umkreis). Aus: nur deine eigenen."] },
    { key = "duels.plates", type = "toggle", label = L["Klassen von Namensplaketten lesen"], default = true,
      tip = L["Die Klassen der Duellanten ohne Klasse werden auch von den Namensplaketten in deiner Nähe gelesen."] },
    { key = "duels.request", type = "toggle", label = L["Bilanz bei Duell-Anfragen zeigen"], default = true,
      tip = L["Fordert dich jemand zum Duell, zeigt Amisia unter der Anfrage seine Klasse, Spezialisierung, Bilanz, seine Serie und wie es gegen dich steht."] },
    { key = "duels.tooltip", type = "toggle", label = L["Duell-Bilanz im Spieler-Tooltip"], default = true,
      tip = L["Im Tooltip eines Spielers, gegen den Duelle aufgezeichnet sind, steht seine Bilanz und wie es gegen dich steht."] },
    { key = "duels.inspect", type = "toggle", label = L["Spezialisierung durch Betrachten lesen"], default = true,
      tip = L["Steht ein Duellant in deiner Nähe (Ziel, Maus, Namensplakette), betrachtet Amisia ihn einmal kurz ohne Fenster und merkt sich seine Spezialisierung: den Talentbaum mit den meisten Punkten. Nie im Kampf und nie, während dein Betrachten-Fenster offen ist."] },
} }

ns.RegisterSlash("duelle", { en = "duels", desc = L["Duelle: Verlauf, Rangliste, Klassen"], run = function()
    if ns.ShowDuels then ns.ShowDuels() end
end })
