-- Duels (F-106, spec docs/specs/2026-10-16-duelle.md, D-52): every duel the game announces in the
-- system chat, the own ones and (duels.nearby) those of other players nearby: "X has defeated Y in a
-- duel" (K, knockout) and "Y has fled from X in a duel" (F, retreat), read through the client's
-- templates DUEL_WINNER_KNOCKOUT / DUEL_WINNER_RETREAT, with the time and the own zone. The classes of
-- the players come from what the client knows anyway (the own character, the group, target, mouseover,
-- name plates with duels.plates, the guild roster, the friend list) and from /who on the player's
-- click ("Klassen suchen": the zone first, then one unknown name per click, every 5 s at most).
-- A simple tournament mode marks the duels between "Turnier starten" and "beenden". Nothing is sent.
-- Saved: AmisiaDB.duels { v = 1, list = { "<epoch>\t<winner>\t<loser>\t<zone nr>\t<K/F>[\t<tournament>]" },
-- zones = { names }, cls = { [name] = class token }, tour = { n = last tournament, on = its start } }.
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
    local cls = {}
    for name, token in pairs(type(d.cls) == "table" and d.cls or {}) do
        if names[name] and CLASSES[token] then cls[name] = token end
    end
    local tour = type(d.tour) == "table" and d.tour or {}
    tour = { n = int(tour.n, 0, 99999) and tour.n or 0, on = int(tour.on, 1) and tour.on <= now + 86400 and tour.on or nil }
    if tour.on and tour.n == 0 then tour.on = nil end
    for k in pairs(d) do d[k] = nil end
    d.v, d.list, d.zones, d.cls, d.tour = 1, list, packed, cls, tour
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

local function index()
    if players then return end
    players, unknown, nUnknown, zoneNr = {}, {}, 0, {}
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
function D.Changed(classOnly)
    rowsCache = nil
    if not classOnly then players = nil end
    ns.Fire("DUELS")
end

-- Every duel, newest first: { t, w, l, z = zone text or nil, k = "K"/"F", n = tournament or nil, wc, lc }.
function D.All()
    if rowsCache then return rowsCache end
    local d = db()
    local out = {}
    if d then
        for i = #d.list, 1, -1 do
            local t, w, l, z, k, n = d.list[i]:match(LINE)
            if t then
                out[#out + 1] = { t = tonumber(t), w = w, l = l, z = d.zones[tonumber(z)], k = k,
                                  n = tonumber(n ~= "" and n or nil), wc = d.cls[w], lc = d.cls[l] }
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

---------------------------------------------------------------------------
-- Classes
---------------------------------------------------------------------------
-- A name of the duels learns its class (a valid token, only when it has none). True when it did.
function D.Learn(name, token)
    token = ns.Plain(token)
    name = ns.Plain(name)
    if type(name) ~= "string" or not CLASSES[token] then return false end
    index()
    local low = name:lower()
    -- a duel message without the surname: the first name of a full name
    if not unknown[low] then low = low:match("^(%S+) ") or low end
    if not unknown[low] then return false end
    local d = db()
    if not d then return false end
    d.cls[players[low]] = token
    unknown[low] = nil
    nUnknown = nUnknown - 1
    D.Changed(true)
    return true
end

-- A unit's player and class, learned when the name is one of the duels without a class.
local function learnUnit(unit)
    if nUnknown == 0 and players then return false end
    if type(UnitExists) == "function" and not ns.Plain(UnitExists(unit)) then return false end
    if type(UnitIsPlayer) == "function" and not ns.Plain(UnitIsPlayer(unit)) then return false end
    local n, s = UnitName(unit)
    n, s = ns.Plain(n), ns.Plain(s)
    local name = ns.FullName(n, s)
    if not name then return false end
    local _, token = UnitClass(unit)
    return D.Learn(name, token)
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
    if nUnknown == 0 or not ns.Get("duels.plates") then return end
    local np = _G.C_NamePlate
    if type(np) ~= "table" or type(np.GetNamePlates) ~= "function" then return end
    for _, plate in ipairs(np.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if type(unit) == "string" then learnUnit(unit) end
    end
end

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

-- The duels the filters leave, newest first. opts: { query (part of a name), player (exactly this
-- name, instead of query), class, tour = true (the last tournament) }
function D.Filter(opts)
    opts = opts or {}
    local q = ns.Fold((opts.query or ""):match("^%s*(.-)%s*$"))
    local one = type(opts.player) == "string" and opts.player:lower() or nil
    local cls = opts.class ~= "all" and opts.class or nil
    local tourNr = opts.tour and D.Tour().n or nil
    local out = {}
    for _, r in ipairs(D.All()) do
        local who
        if one then who = r.w:lower() == one or r.l:lower() == one else who = matches(r.w, q) or matches(r.l, q) end
        if (not tourNr or r.n == tourNr) and who
            and (not cls or r.wc == cls or r.lc == cls) then
            out[#out + 1] = r
        end
    end
    return out
end

local function rate(w, g) return g > 0 and w / g or 0 end

-- The leaderboard of rows: { name, c, g, w, l, r }, those matching query and class; sorted by
-- sort ("rate": the win rate of the players with D.MIN_GAMES duels first, then the rest by games;
-- "games", "wins", "name"), desc turns it round.
function D.Board(rows, opts)
    opts = opts or {}
    local q = ns.Fold((opts.query or ""):match("^%s*(.-)%s*$"))
    local one = type(opts.player) == "string" and opts.player:lower() or nil
    local cls = opts.class ~= "all" and opts.class or nil
    local by = {}
    local out = {}
    local function side(name, c, won)
        local e = by[name]
        if not e then
            e = { name = name, c = c, g = 0, w = 0, l = 0, fold = ns.Fold(name) }
            by[name] = e
            out[#out + 1] = e
        end
        e.g = e.g + 1
        if won then e.w = e.w + 1 else e.l = e.l + 1 end
    end
    for _, r in ipairs(rows) do
        side(r.w, r.wc, true)
        side(r.l, r.lc, false)
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

-- The classes of rows. Without a class: per class the sides it played { c, g, p = players, w, l, r },
-- by win rate; with one: how that class did against each class (a mirror duel counts once, won and
-- lost). Also { known sides, all sides } for the coverage.
function D.ClassTable(rows, class)
    class = class ~= "all" and class or nil
    local by, out = {}, {}
    local known, sides = 0, 0
    local function entry(c)
        local e = by[c]
        if not e then
            e = { c = c, g = 0, w = 0, l = 0, p = 0, seen = {} }
            by[c] = e
            out[#out + 1] = e
        end
        return e
    end
    local function player(e, name)
        if not e.seen[name] then
            e.seen[name] = true
            e.p = e.p + 1
        end
    end
    for _, r in ipairs(rows) do
        sides = sides + 2
        if r.wc then known = known + 1 end
        if r.lc then known = known + 1 end
        if not class then
            if r.wc then
                local e = entry(r.wc)
                e.g, e.w = e.g + 1, e.w + 1
                player(e, r.w)
            end
            if r.lc then
                local e = entry(r.lc)
                e.g, e.l = e.g + 1, e.l + 1
                player(e, r.l)
            end
        elseif r.wc and r.lc and (r.wc == class or r.lc == class) then
            local other = r.wc == class and r.lc or r.wc
            local e = entry(other)
            e.g = e.g + 1
            if r.wc == class then e.w = e.w + 1 end
            if r.lc == class then e.l = e.l + 1 end
            player(e, r.wc == class and r.l or r.w)
        end
    end
    for _, e in ipairs(out) do
        e.r = e.c == class and 0.5 or rate(e.w, e.w + e.l)
        e.seen = nil
    end
    table.sort(out, function(a, b)
        if a.r ~= b.r then return a.r > b.r end
        if a.g ~= b.g then return a.g > b.g end
        return a.c < b.c
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
} }

ns.RegisterSlash("duelle", { en = "duels", desc = L["Duelle: Verlauf, Rangliste, Klassen"], run = function()
    if ns.ShowDuels then ns.ShowDuels() end
end })
