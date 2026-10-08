-- Amisia points: DKP and EPGP as the guild's loot system instead of rolling (the default, which this
-- file leaves alone). Design: docs/superpowers/specs/2026-10-08-amisia-dkp-epgp-design.md.
--
-- The website is the source of the standings: an officer pastes its "#AMISIA-PTS" block (with the
-- wishes, alts and prio in one paste, Alts.lua ns.ImportSiteText), which brings the system, its
-- settings and every main's standing. The addon adds what the site does not have yet: the earnings
-- of the raids it recorded (raid, boss kills, on time, bench), the cost of awards (DKP spent, GP
-- charged) and corrections made in game, and exports those as new lines (PS, PE, PA inside a raid,
-- PX outside). Points belong to the main (ns.MainOf).
--
-- Stored in AmisiaDB.points = { site = { date, at, by, asOf, sys, cfg, n, list = { [lower] = { name, a, b } },
-- raids = { [sid] = true }, ids = { [id] = true } }, adj = { { id, name, pool, n, t, by, reason } },
-- shared = (PointsSync.lua) }; a raid keeps s.points = { sys, cfg, off, charges = { [awardId] = { p, n, at, by } } }.
-- Pools: "D" DKP, "E" EP, "G" GP. Every pasted or typed text is untrusted.
local ADDON, ns = ...
local L = ns.L

local HEAD_FAIL = L["Das ist kein Punktestand der Amisia-Seite."]
local OWN_GAME = "forever"
local GAME_NAMES = { forever = "WoW Forever", tbc = "TBC Anniversary" }
local SYSTEMS = { roll = true, dkp = true, epgp = true }
local MAX_LINES, MAX_LINE = 3000, 2000
local NAME_MAX = 48
local MAX_POINTS = 9999999       -- a standing on the site
local MAX_AMOUNT = 999999        -- a bid, a cost, a correction
local REASON_MAX = 80
local MAX_ADJ = 1000
local GREY = "|cff8f86a3"

-- the settings a site block may set: key in the block -> { setting path, min, max } (words: values)
local CFG = {
    raid = { "points.raid", 0, 1000 }, boss = { "points.boss", 0, 1000 }, time = { "points.onTime", 0, 1000 },
    bench = { "points.bench", 0, 1000 }, min = { "points.minBid", 0, 100000 }, step = { "points.bidStep", 1, 10000 },
    price = { "points.price", 0, 100000 }, base = { "points.gpBase", 1, 100000 }, minep = { "points.minEp", 0, 1000000 },
    scale = { "points.gpScale", 1, 100000 }, ref = { "points.gpRef", 1, 1000 }, os = { "points.osPct", 0, 100 },
    seal = { "points.sealed", 0, 1, bool = true }, mode = { "points.dkpMode", words = { bid = true, fixed = true } },
    decay = { nil, 0, 100 }, pub = { nil, 0, 1 },
}

-- slot weights of the GP formula (the site uses the same numbers)
local SLOT_WEIGHT = {
    INVTYPE_HEAD = 1, INVTYPE_CHEST = 1, INVTYPE_ROBE = 1, INVTYPE_LEGS = 1,
    INVTYPE_SHOULDER = 0.75, INVTYPE_HAND = 0.75, INVTYPE_WAIST = 0.75, INVTYPE_FEET = 0.75, INVTYPE_TRINKET = 0.75,
    INVTYPE_NECK = 0.5, INVTYPE_CLOAK = 0.5, INVTYPE_WRIST = 0.5, INVTYPE_FINGER = 0.5,
    INVTYPE_WEAPON = 1.5, INVTYPE_WEAPONMAINHAND = 1.5, INVTYPE_WEAPONOFFHAND = 1.5, INVTYPE_2HWEAPON = 2,
    INVTYPE_SHIELD = 0.5, INVTYPE_HOLDABLE = 0.5, INVTYPE_RANGED = 0.5, INVTYPE_RANGEDRIGHT = 0.5,
    INVTYPE_THROWN = 0.5, INVTYPE_RELIC = 0.5,
}

local SYS_NAME = { roll = L["Würfeln##System"], dkp = "DKP", epgp = "EPGP" }
function ns.PointsSystemName(sys) return SYS_NAME[sys or ns.PointsSystem()] or "?" end

local function stripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|", "")
    return s
end

local function cleanName(raw)
    if type(raw) ~= "string" then return nil end
    local name = ns.FullName((raw:gsub("_", " ")))
    if not name or #name > NAME_MAX or name:find("[%d%c,:;()|]") then return nil end
    return name
end
ns.PointsCleanName = cleanName

local function int(v, lo, hi)
    return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function fire() ns.Fire("POINTS") end

---------------------------------------------------------------------------
-- The models
---------------------------------------------------------------------------
-- Rounds to the nearest whole number, .5 away from zero.
function ns.PointsRound(x)
    x = tonumber(x) or 0
    if x >= 0 then return math.floor(x + 0.5) end
    return -math.floor(-x + 0.5)
end

-- A standing after a decay of pct percent.
function ns.PointsDecayed(v, pct)
    return ns.PointsRound((tonumber(v) or 0) * (100 - (tonumber(pct) or 0)) / 100)
end

local function denom(gp, base) return math.max(1, (tonumber(gp) or 0) + (tonumber(base) or 0)) end

-- PR = EP / (GP + base GP); never a division by zero or below one.
function ns.PointsPR(ep, gp, base)
    return (tonumber(ep) or 0) / denom(gp, base)
end

-- The order of two EPGP standings { e, g } by PR, exact: > 0 when x stands higher, 0 when equal.
function ns.PointsCompare(x, y, cfg)
    local base = cfg and cfg.base or 100
    return (tonumber(x.e) or 0) * denom(y.g, base) - (tonumber(y.e) or 0) * denom(x.g, base)
end

function ns.PointsPRText(pr)
    pr = tonumber(pr) or 0
    return ns.Num(pr, math.abs(pr) >= 10 and 1 or 2)
end

function ns.PointsSlotWeight(equipLoc)
    return SLOT_WEIGHT[equipLoc] or 1
end

-- scale * 2^((ilvl - ref) / 26) * slot weight * 2^(quality - 4), rounded.
function ns.PointsFormula(ilvl, equipLoc, quality, scale, ref)
    ilvl, quality = tonumber(ilvl) or tonumber(ref) or 0, tonumber(quality) or 4
    local v = (tonumber(scale) or 0) * 2 ^ ((ilvl - (tonumber(ref) or 0)) / 26) * ns.PointsSlotWeight(equipLoc) * 2 ^ (quality - 4)
    return ns.PointsRound(v)
end

-- The cost of an item for a kind: GP in EPGP, the fixed price in DKP (MS and SR full, OS the
-- offspec share, "-" nothing); nil when the client does not know the item.
function ns.PointsItemCost(item, kind, cfg)
    cfg = cfg or ns.PointsConfig()
    if kind == "-" then return 0 end
    local id = tonumber(item) or ns.ItemID(item)
    local info = C_Item and C_Item.GetItemInfo
    if not id or type(info) ~= "function" then return nil end
    local ok, name, _, quality, ilvl, _, _, _, _, equipLoc = pcall(info, id)
    if not ok or not ns.Plain(name) then return nil end
    local scale = (cfg.sys == "dkp") and cfg.price or cfg.scale
    local full = ns.PointsFormula(ns.Plain(ilvl), ns.Plain(equipLoc), ns.Plain(quality), scale, cfg.ref)
    if kind == "OS" then return ns.PointsRound(full * (tonumber(cfg.os) or 0) / 100) end
    return full
end

-- A bid as typed after "!bid": whole digits, optionally "dkp"; nil and the reason otherwise.
local BID_FAIL = L["Gebot nicht erkannt: nur eine ganze Zahl, z. B. !bid 50."]
function ns.PointsParseBid(text)
    if type(text) ~= "string" or #text > 24 or text:find("[%c|]") then return nil, BID_FAIL end
    local s = text:lower():match("^%s*(.-)%s*$")
    local digits = s:match("^(%d+)%s*dkp$") or s:match("^(%d+)$")
    if not digits or #digits > 7 then return nil, BID_FAIL end
    local n = tonumber(digits)
    if not n or n < 1 or n > MAX_AMOUNT then return nil, BID_FAIL end
    return n
end

---------------------------------------------------------------------------
-- Settings and the system
---------------------------------------------------------------------------
local function store(make)
    if not AmisiaDB then return nil end
    local p = AmisiaDB.points
    if type(p) ~= "table" then
        if not make then return nil end
        p = {}
        AmisiaDB.points = p
    end
    if type(p.adj) ~= "table" then p.adj = {} end
    return p
end

local function siteRec()
    local p = store()
    local s = p and p.site
    if type(s) ~= "table" or type(s.list) ~= "table" then return nil end
    return s
end

-- The system of the settings (what a new raid freezes).
local function settingsSys()
    local v = ns.Get("points.system")
    return SYSTEMS[v] and v or "roll"
end

-- The system this client shows: the settings', for a raider without one the officers' of the
-- running raid (PointsSync.lua).
function ns.PointsSystem()
    local v = settingsSys()
    if v == "roll" and not ns.IsOfficerView() then
        local sh = ns.PointsSharedList and ns.PointsSharedList()
        if sh and SYSTEMS[sh.sys] then return sh.sys end
    end
    return v
end

-- The system and its parameters as they stand now: { sys, raid, boss, time, bench, mode, seal, min,
-- step, price, base, minep, scale, ref, os, decay, pub }.
function ns.PointsConfig()
    local c = { sys = ns.PointsSystem() }
    for key, def in pairs(CFG) do
        if def[1] then
            local v = ns.Get(def[1])
            if def.bool then v = v and 1 or 0 end
            c[key] = v
        end
    end
    local site = siteRec()
    local sc = site and type(site.cfg) == "table" and site.cfg or {}
    c.decay = tonumber(sc.decay) or 0
    c.pub = tonumber(sc.pub) or 0
    -- a raider following the officers' list of the running raid reads its parameters
    if not ns.IsOfficerView() then
        local sh = ns.PointsSharedList and ns.PointsSharedList()
        if sh and sh.sys == c.sys and type(sh.cfg) == "table" then
            for k, v in pairs(sh.cfg) do c[k] = v end
        end
    end
    return c
end

-- The pool earnings and costs go into: DKP "D", EPGP earns "E" and pays "G".
local function earnPool(sys) return sys == "epgp" and "E" or "D" end
local function payPool(sys) return sys == "epgp" and "G" or "D" end

---------------------------------------------------------------------------
-- The website's block
---------------------------------------------------------------------------
local function gameName(key) return GAME_NAMES[key] or stripCodes(tostring(key)):sub(1, 24) end

-- Reads:
--   #AMISIA-PTS 1 <game> <yyyy-mm-dd> <roll|dkp|epgp> <as-of epoch>
--   CFG <key>=<value> ...
--   P <main with _> <DKP> | P <main> <EP> <GP>
--   R <session id> ...      raids whose earnings the site has
--   I <12 hex> ...          awards with a cost and corrections the site has
--   #END
-- Returns { game, date, sys, asOf, cfg, list = { [lower] = { name, a, b } }, raids, ids, n, skipped } or nil and why.
function ns.ParsePointsSite(text)
    if type(text) ~= "string" then return nil, HEAD_FAIL end
    local res = { cfg = {}, list = {}, raids = {}, ids = {}, n = 0, skipped = 0 }
    local read, head = 0, false
    for raw in text:gmatch("[^\r\n]+") do
        local line = stripCodes(raw:sub(1, MAX_LINE)):match("^%s*(.-)%s*$")
        if line ~= "" then
            if not head then
                line = line:gsub("^\239\187\191", "")
                local ver, game, day, sys, asOf = line:match("^#AMISIA%-PTS%s+(%d+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%d*)")
                if ver ~= "1" or not day or not day:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil, HEAD_FAIL end
                game = game:lower()
                if game ~= OWN_GAME then
                    return nil, L["Dieser Punktestand ist für %s, du bist in %s."]:format(gameName(game), gameName(OWN_GAME))
                end
                sys = sys:lower()
                if not SYSTEMS[sys] then return nil, HEAD_FAIL end
                res.game, res.date, res.sys, res.asOf, head, read = game, day, sys, tonumber(asOf) or 0, true, 1
            elseif line == "#END" then
                break
            elseif read >= MAX_LINES then
                res.skipped = res.skipped + 1
            else
                read = read + 1
                local kind, rest = line:match("^(%u+)%s*(.-)$")
                if kind == "CFG" then
                    for k, v in rest:gmatch("(%w+)=(%w+)") do
                        local def = CFG[k]
                        if def then
                            if def.words then
                                if def.words[v] then res.cfg[k] = v end
                            else
                                local n = v:match("^%d+$") and tonumber(v)
                                if n and n >= def[2] and n <= def[3] then res.cfg[k] = n end
                            end
                        end
                    end
                elseif kind == "P" then
                    local words = {}
                    for w in rest:gmatch("%S+") do words[#words + 1] = w end
                    local name = cleanName(words[1])
                    local want = res.sys == "epgp" and 3 or 2
                    local a, b = words[2], words[3]
                    a = a and a:match("^%-?%d+$") and tonumber(a)
                    b = b and b:match("^%-?%d+$") and tonumber(b)
                    if not name or #words ~= want or not a or math.abs(a) > MAX_POINTS
                        or (want == 3 and (not b or math.abs(b) > MAX_POINTS)) then
                        res.skipped = res.skipped + 1
                    else
                        local key = name:lower()
                        if not res.list[key] then res.n = res.n + 1 end
                        res.list[key] = { name = name, a = a, b = want == 3 and b or 0 }
                    end
                elseif kind == "R" then
                    for sid in rest:gmatch("%S+") do
                        if sid:match("^%d+%-%d+$") and #sid <= 40 then res.raids[sid] = true else res.skipped = res.skipped + 1 end
                    end
                elseif kind == "I" then
                    for id in rest:gmatch("%S+") do
                        if #id == 12 and id:match("^%x+$") then res.ids[id:lower()] = true else res.skipped = res.skipped + 1 end
                    end
                else
                    res.skipped = res.skipped + 1
                end
            end
        end
    end
    if not head then return nil, HEAD_FAIL end
    return res
end

-- The setting value of a block value.
local function settingValue(def, v)
    if def.bool then return v == 1 end
    return v
end

-- Stores a pasted site block, takes its system and settings over and drops the own corrections
-- the site has. Returns the parse result or nil and why (the old block stays).
function ns.SetPointsSite(text)
    local res, why = ns.ParsePointsSite(text)
    if not res then return nil, why end
    local p = store(true)
    if not p then return nil, L["Amisia ist noch nicht geladen."] end
    p.site = { date = res.date, at = time(), by = ns.UnitFullName("player"), asOf = res.asOf, sys = res.sys, cfg = res.cfg,
               n = res.n, list = res.list, raids = res.raids, ids = res.ids }
    -- the values first: a change of the system freezes them into the running raid
    for key, v in pairs(res.cfg) do
        local def = CFG[key]
        if def and def[1] then ns.Set(def[1], settingValue(def, v)) end
    end
    ns.Set("points.system", res.sys)
    local keep = {}
    for _, e in ipairs(p.adj) do
        if not res.ids[e.id] then keep[#keep + 1] = e end
    end
    p.adj = keep
    fire()
    return res
end

function ns.ClearPoints()
    if AmisiaDB then AmisiaDB.points = nil end
    fire()
end

-- { date, n, sys, asOf, by } of the pasted block, or nil.
function ns.PointsInfo()
    local s = siteRec()
    if not s then return nil end
    return { date = s.date, n = tonumber(s.n) or 0, sys = s.sys, asOf = s.asOf, by = s.by }
end

---------------------------------------------------------------------------
-- A raid's points
---------------------------------------------------------------------------
local function copyCfg(c)
    local out = {}
    for k, v in pairs(c) do out[k] = v end
    return out
end

-- The points of raid s; make: create them with the system of now (not for "roll").
function ns.PointsSession(s, make)
    if type(s) ~= "table" then return nil end
    local p = s.points
    if type(p) == "table" then
        if type(p.charges) ~= "table" then p.charges = {} end
        return p
    end
    if not make then return nil end
    if settingsSys() == "roll" then return nil end
    local cfg = ns.PointsConfig()
    cfg.sys = settingsSys()
    p = { sys = cfg.sys, cfg = copyCfg(cfg), charges = {} }
    s.points = p
    return p
end

-- Called by Core for every new recording: it freezes the system and its parameters.
function ns.PointsNewSession(s)
    ns.PointsSession(s, true)
end

function ns.PointsRaidOff(s, off)
    local p = ns.PointsSession(s, true)
    if not p then return nil end
    p.off = off and true or nil
    ns.Fire("DATA_CHANGED")
    fire()
    return true
end

local function hexId(text)
    return ns.Checksum(text):sub(1, 12)
end

local function memberKey(s, name)
    for m in pairs(s.members or {}) do
        if ns.SameName(m, name) then return m end
    end
    return nil
end

-- The earnings of raid s: { { id, char, name (main), n, code R|B|T|N, t, boss } }, the same ids on
-- every call. Nothing for a raid without a system or taken out of the count.
function ns.PointsRaidEarnings(s)
    local out = {}
    local p = ns.PointsSession(s)
    if not p or p.off or p.sys == "roll" then return out end
    local cfg = p.cfg or {}
    local function add(char, n, code, t, boss, key)
        n = tonumber(n) or 0
        if n == 0 then return end
        out[#out + 1] = { id = hexId(table.concat({ tostring(s.id), char:lower(), code, key or "" }, "\t")), char = char,
                          name = ns.MainOf(char) or char, n = n, code = code, t = math.floor(tonumber(t) or 0), boss = boss }
    end
    local names = {}
    for name in pairs(s.members or {}) do names[#names + 1] = name end
    table.sort(names)
    local start = s.start or 0
    for _, name in ipairs(names) do
        add(name, cfg.raid, "R", start)
        if not s.members[name].late then add(name, cfg.time, "T", start) end
    end
    local kills = {}
    for _, k in ipairs(s.kills or {}) do kills[#kills + 1] = k end
    table.sort(kills, function(a, b) return (a.t or 0) < (b.t or 0) end)
    for _, k in ipairs(kills) do
        if k.ok and not k.wait and type(k.who) == "table" then
            local seen = {}
            for _, who in ipairs(k.who) do
                local char = ns.FullName(who)
                if char and not seen[char:lower()] then
                    seen[char:lower()] = true
                    add(char, cfg.boss, "B", k.t, k.name, ("%d:%d"):format(tonumber(k.enc) or 0, tonumber(k.t) or 0))
                end
            end
        end
    end
    local bench = {}
    for name in pairs(type(s.bench) == "table" and s.bench or {}) do bench[#bench + 1] = name end
    table.sort(bench)
    for _, name in ipairs(bench) do
        if not memberKey(s, name) then
            local e = s.bench[name]
            add(name, cfg.bench, "N", type(e) == "table" and e.t or start)
        end
    end
    return out
end

---------------------------------------------------------------------------
-- The cost of awards
---------------------------------------------------------------------------
local function living(s, id)
    local a, _, gone = ns.FindAward(s, id)
    if a and not gone then return a end
    return nil
end

function ns.AwardPoints(s, id)
    local p = ns.PointsSession(s)
    local c = p and p.charges[id]
    return type(c) == "table" and c or nil
end

-- Takes a charge another officer set (newer time wins): true when it changed something.
function ns.PointsTakeCharge(s, id, pool, n, at, by)
    local p = ns.PointsSession(s, true)
    if not p or not int(n, 0, MAX_AMOUNT) or (pool ~= "D" and pool ~= "G") then return false end
    local old = p.charges[id]
    if type(old) == "table" and (tonumber(old.at) or 0) >= at then return false end
    p.charges[id] = { p = pool, n = n, at = at, by = by }
    ns.Fire("DATA_CHANGED")
    fire()
    return true
end

-- Sets the cost of a living award to a player (an officer's change): DKP spent or GP charged.
-- Returns the charge or nil and why.
function ns.SetAwardPoints(s, id, n)
    if not ns.IsOfficerView() then return nil, L["Punkte ändern nur Offiziere."] end
    local a = living(s, id)
    if not a then return nil, L["Vergabe nicht mehr vorhanden."] end
    if a.to ~= nil and a.to ~= "player" then return nil, L["Bank und Entzaubern kosten keine Punkte."] end
    n = tonumber(n)
    if not int(n, 0, MAX_AMOUNT) then return nil, L["Ungültiger Betrag."] end
    local p = ns.PointsSession(s, true)
    if not p then return nil, L["Kein Punktesystem gewählt."] end
    local c = { p = payPool(p.sys), n = n, at = math.floor(time()), by = ns.UnitFullName("player") }
    local old = p.charges[id]
    -- two changes in one second: the later one still wins on the other clients
    if type(old) == "table" and (tonumber(old.at) or 0) >= c.at then c.at = old.at + 1 end
    p.charges[id] = c
    ns.Fire("DATA_CHANGED")
    fire()
    if ns.PointsShareCharge then ns.PointsShareCharge(s, id, c) end
    return c
end

---------------------------------------------------------------------------
-- Corrections
---------------------------------------------------------------------------
local POOL_WORD = { ep = "E", gp = "G", dkp = "D" }

-- An officer's correction with a reason: name (an alt counts for its main), a whole number not 0,
-- the reason, optionally "ep"/"gp" (EPGP; default EP). Returns the entry or nil and why.
function ns.PointsAdjust(name, n, reason, poolWord)
    if not ns.IsOfficerView() then return nil, L["Punkte ändern nur Offiziere."] end
    local sys = ns.PointsSystem()
    if sys == "roll" then return nil, L["Kein Punktesystem gewählt."] end
    local char = cleanName(name)
    if not char then return nil, L["Kein gültiger Name."] end
    n = tonumber(n)
    if not n or n == 0 or n ~= math.floor(n) or math.abs(n) > MAX_AMOUNT then return nil, L["Ungültiger Betrag."] end
    reason = ns.CleanNote(stripCodes(tostring(reason or "")), REASON_MAX)
    if not reason then return nil, L["Ein Grund fehlt."] end
    local pool = POOL_WORD[tostring(poolWord or ""):lower()] or earnPool(sys)
    if sys == "dkp" then pool = "D" elseif pool == "D" then pool = "E" end
    local p = store(true)
    if not p then return nil, L["Amisia ist noch nicht geladen."] end
    local t = math.floor(time())
    local e = { id = hexId(table.concat({ "adj", tostring(t), char, tostring(n), reason, tostring(math.random(0, 65535)) }, "\t")),
                name = ns.MainOf(char) or char, n = n, pool = pool, t = t, by = ns.UnitFullName("player") or "?", reason = reason }
    p.adj[#p.adj + 1] = e
    while #p.adj > MAX_ADJ do table.remove(p.adj, 1) end
    fire()
    return e
end

---------------------------------------------------------------------------
-- Standings
---------------------------------------------------------------------------
-- The entry of a name in map (lower main -> { name, a, b }): the same main, else a spelling ns.SameName takes.
local function slot(map, name, make)
    local key = name:lower()
    local e = map[key]
    if e then return e end
    for _, x in pairs(map) do
        if ns.SameName(x.name, name) then return x end
    end
    if not make then return nil end
    e = { name = name, a = 0, b = 0 }
    map[key] = e
    return e
end

-- Walks everything that makes the standings of system sys: fn(main, pool, n, entry) where entry
-- is { code, t, reason, src }.
local function walk(sys, fn)
    local site = siteRec()
    local hasSite = site and site.sys == sys
    if hasSite then
        for _, e in pairs(site.list) do
            if sys == "epgp" then
                fn(e.name, "E", e.a, { code = "S", t = site.asOf or 0, src = "site" })
                if (tonumber(e.b) or 0) ~= 0 then fn(e.name, "G", e.b, { code = "S", t = site.asOf or 0, src = "site" }) end
            else
                fn(e.name, "D", e.a, { code = "S", t = site.asOf or 0, src = "site" })
            end
        end
    end
    local raids, ids = hasSite and site.raids or {}, site and site.ids or {}
    local pay = payPool(sys)
    for _, s in ipairs(ns.Sessions()) do
        local p = ns.PointsSession(s)
        if p then
            if p.sys == sys and not raids[s.id] then
                for _, e in ipairs(ns.PointsRaidEarnings(s)) do
                    fn(e.name, earnPool(sys), e.n, { code = e.code, t = e.t, boss = e.boss, src = "raid", s = s, char = e.char })
                end
            end
            for id, c in pairs(p.charges) do
                local a = type(c) == "table" and c.p == pay and not ids[id] and living(s, id)
                if a and (a.to == nil or a.to == "player") then
                    local main = ns.MainOf(a.name) or a.name
                    fn(main, pay, sys == "dkp" and -c.n or c.n, { code = "A", t = a.t or c.at, item = a.item, src = "award", s = s, char = a.name })
                end
            end
        end
    end
    local p = store()
    for _, e in ipairs(p and p.adj or {}) do
        if not ids[e.id] then
            local ok = (sys == "dkp" and e.pool == "D") or (sys == "epgp" and (e.pool == "E" or e.pool == "G"))
            if ok then fn(e.name, e.pool, e.n, { code = "X", t = e.t, reason = e.reason, by = e.by, src = "adj", id = e.id }) end
        end
    end
end

local function officerView() return ns.IsOfficerView() end

-- The list an officer computes: lower main -> { name, a, b }.
local function computed(sys)
    local map = {}
    walk(sys, function(name, pool, n)
        local e = slot(map, name, true)
        if pool == "G" then e.b = e.b + n else e.a = e.a + n end
    end)
    return map
end

-- What a raider sees: the officers' list of the running raid (PointsSync.lua), else the site's.
local function raiderList(sys)
    local sh = ns.PointsSharedList and ns.PointsSharedList()
    if sh and sh.sys == sys then return sh.list, sh.cfg end
    local site = siteRec()
    if site and site.sys == sys then return site.list, site.cfg end
    return {}, nil
end

local function finish(e, cfg)
    local out = { name = e.name, a = e.a or 0, b = e.b or 0 }
    if cfg.sys == "epgp" then
        out.pr = ns.PointsPR(out.a, out.b, cfg.base)
        out.low = (tonumber(cfg.minep) or 0) > 0 and out.a < cfg.minep or nil
    end
    return out
end

local function sortList(list, cfg)
    table.sort(list, function(x, y)
        if cfg.sys == "epgp" then
            if (x.low and true) ~= (y.low and true) then return not x.low end
            local c = ns.PointsCompare({ e = x.a, g = x.b }, { e = y.a, g = y.b }, cfg)
            if c ~= 0 then return c > 0 end
            if x.a ~= y.a then return x.a > y.a end
        elseif x.a ~= y.a then
            return x.a > y.a
        end
        return x.name:lower() < y.name:lower()
    end)
    return list
end

-- The standings this client shows, best first: { { name, a, b, pr, low } } (a: DKP or EP, b: GP).
-- An officer sees everyone; a raider the officers' list when the site shows it (pub), else the own row.
function ns.PointsStandings()
    local cfg = ns.PointsConfig()
    if cfg.sys == "roll" then return {} end
    local list = {}
    if officerView() then
        for _, e in pairs(computed(cfg.sys)) do list[#list + 1] = finish(e, cfg) end
        return sortList(list, cfg)
    end
    local map, mcfg = raiderList(cfg.sys)
    local pub = (mcfg and tonumber(mcfg.pub) == 1)
    local me = ns.UnitFullName("player")
    for _, e in pairs(map) do
        if pub or (me and ns.SameMain(e.name, me)) then list[#list + 1] = finish(e, cfg) end
    end
    if #list == 0 and me then list[1] = finish({ name = ns.MainOf(me) or me }, cfg) end
    return sortList(list, cfg)
end

-- The standing of one player (its main): { name, a, b, pr, low }; 0 for someone without points.
function ns.PointsOf(name)
    local cfg = ns.PointsConfig()
    local char = ns.FullName(name)
    if not char then return nil end
    local main = ns.MainOf(char) or char
    local map
    if officerView() then map = computed(cfg.sys) else map = raiderList(cfg.sys) end
    local e = slot(map, main, false) or { name = main }
    return finish(e, cfg)
end

-- The history of one player (its main), oldest first: { t, n, pool, code, text, src }.
-- code: S the site's standing, R raid, B boss, T on time, N bench, A award, X correction.
local CODE_TEXT = { R = L["Raid"], B = L["Boss"], T = L["pünktlich"], N = L["Ersatzbank"], S = L["Stand der Website"] }
function ns.PointsHistory(name)
    local out = {}
    local char = ns.FullName(name)
    if not char or not officerView() then return out end
    local sys = ns.PointsSystem()
    if sys == "roll" then return out end
    local main = ns.MainOf(char) or char
    walk(sys, function(who, pool, n, e)
        if not ns.SameName(who, main) then return end
        local text
        if e.code == "A" then
            text = L["Vergabe: %s"]:format(ns.ItemName(e.item))
        elseif e.code == "X" then
            text = L["Korrektur: %s (%s)"]:format(e.reason or "?", e.by or "?")
        elseif e.code == "B" then
            text = L["Boss: %s"]:format(e.boss or "?")
        else
            text = CODE_TEXT[e.code] or e.code
        end
        if e.s and e.code ~= "X" and e.code ~= "S" then text = text .. GREY .. " · " .. tostring(e.s.zone or "?") .. "|r" end
        if e.char and not ns.SameName(e.char, main) then text = text .. GREY .. " (" .. e.char .. ")|r" end
        out[#out + 1] = { t = tonumber(e.t) or 0, n = n, pool = pool, code = e.code, text = text, src = e.src }
    end)
    table.sort(out, function(x, y)
        if x.t ~= y.t then return x.t < y.t end
        return x.code < y.code
    end)
    return out
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------
local function oneLine(text) return (tostring(text or ""):gsub("[%c|]", " ")) end

-- PS, PE and PA lines of raid s, appended to lines (Core's sessionLines): nothing for a raid without a system.
function ns.PointsSessionLines(s, lines)
    local p = ns.PointsSession(s)
    if not p or not SYSTEMS[p.sys] or p.sys == "roll" then return end
    -- PS <D|E> <dkp|epgp> <on|off>
    lines[#lines + 1] = ("PS %s %s %s"):format(earnPool(p.sys), p.sys, p.off and "off" or "on")
    -- PE <id> <name> <amount> <R|B|T|N> <epoch> [<boss>]
    for _, e in ipairs(ns.PointsRaidEarnings(s)) do
        lines[#lines + 1] = ("PE %s %s %d %s %d%s"):format(e.id, ns.ExportName(e.char), e.n, e.code, e.t, e.boss and (" " .. oneLine(e.boss)) or "")
    end
    -- PA <award id> <D|G> <amount> <set epoch> <officer>
    local ids = {}
    for id in pairs(p.charges) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local c, a = p.charges[id], living(s, id)
        if type(c) == "table" and a and (a.to == nil or a.to == "player") then
            lines[#lines + 1] = ("PA %s %s %d %d %s"):format(id, c.p, c.n, tonumber(c.at) or 0, ns.ExportName(c.by or "?"))
        end
    end
end

-- PX <id> <name> <D|E|G> <amount> <epoch> <officer> <reason>: the corrections the site does not have.
function ns.PointsExportLines()
    local p, site = store(), siteRec()
    local ids = site and site.ids or {}
    local lines = {}
    for _, e in ipairs(p and p.adj or {}) do
        if not ids[e.id] then
            lines[#lines + 1] = ("PX %s %s %s %d %d %s %s"):format(e.id, ns.ExportName(e.name), e.pool, e.n, e.t, ns.ExportName(e.by), oneLine(e.reason))
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Chat: "!dkp" answers the own standing (the loot lead, by whisper)
---------------------------------------------------------------------------
local function standingText(e, cfg)
    if not e then return "-" end
    if cfg.sys == "epgp" then
        return L["%s: EP %d, GP %d, PR %s%s"]:format(e.name, e.a, e.b, ns.PointsPRText(e.pr),
            e.low and L[" (unter Mindest-EP %d)"]:format(cfg.minep) or "")
    end
    return L["%s: %d DKP"]:format(e.name, e.a)
end
ns.PointsStandingText = standingText

local function inGroup(name)
    for _, n in ipairs(ns.GroupRoster()) do
        if ns.SameName(n, name) then return true end
    end
    return false
end

local function onAsk(sender)
    local cfg = ns.PointsConfig()
    if cfg.sys == "roll" or ns.Get("points.chat") == false or not ns.IsOfficerView() then return end
    if not (ns.IsLootLead and ns.IsLootLead()) then return end
    local name = ns.FullName(sender)
    if not name or not inGroup(name) then return end
    if not ns.ReplyGate("dkp", name:lower()) then return end
    ns.Say("Amisia: " .. standingText(ns.PointsOf(name), cfg), "WHISPER", sender, { ttl = 120 })
end
for _, word in ipairs({ "dkp", "ep", "epgp", "punkte", "points" }) do ns.RegisterChatCommand(word, onAsk) end -- l10n-ok: chat words

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function isDkp() return ns.PointsSystem() == "dkp" end
local function isEpgp() return ns.PointsSystem() == "epgp" end
local function hasSys() return ns.PointsSystem() ~= "roll" end

ns.RegisterSettings{ key = "points", label = L["Punkte (DKP/EPGP)"], order = 21, officer = true, items = {
    { key = "points.system", type = "choice", label = L["Lootsystem"], default = "roll",
      values = { { "roll", L["Würfeln##System"] }, { "dkp", "DKP" }, { "epgp", "EPGP" } },
      tip = L["Die Website ist die Quelle: ihr Punkteblock (Kopieren für das Addon) setzt System und Werte. Ein laufender Raid behält sein System."],
      onChange = function(v)
          local s = ns.Active and ns.Active()
          if s and v ~= "roll" then ns.PointsSession(s, true) end
          fire()
      end },
    { key = "points.raid", type = "slider", label = L["Punkte pro Raid"], default = 10, min = 0, max = 1000, step = 1, available = hasSys },
    { key = "points.boss", type = "slider", label = L["Punkte pro Bosskill"], default = 5, min = 0, max = 1000, step = 1, available = hasSys },
    { key = "points.onTime", type = "slider", label = L["Bonus pünktlich"], default = 5, min = 0, max = 1000, step = 1, available = hasSys },
    { key = "points.bench", type = "slider", label = L["Punkte Ersatzbank"], default = 10, min = 0, max = 1000, step = 1, available = hasSys },
    { key = "points.dkpMode", type = "choice", label = L["DKP ausgeben"], default = "bid", available = isDkp,
      values = { { "bid", L["Bieten"] }, { "fixed", L["Feste Preise"] } } },
    { key = "points.sealed", type = "toggle", label = L["Verdeckt bieten (nur Flüstern)"], default = false, available = isDkp },
    { key = "points.minBid", type = "slider", label = L["Mindestgebot"], default = 10, min = 0, max = 100000, step = 1, available = isDkp },
    { key = "points.bidStep", type = "slider", label = L["Schritt beim Überbieten"], default = 5, min = 1, max = 10000, step = 1, available = isDkp },
    { key = "points.price", type = "slider", label = L["Grundpreis (feste Preise)"], default = 50, min = 0, max = 100000, step = 1, available = isDkp },
    { key = "points.gpScale", type = "slider", label = L["GP-Grundwert"], default = 100, min = 1, max = 100000, step = 1, available = isEpgp,
      tip = L["GP = Grundwert × 2^((Itemlevel − Bezug)/26) × Slotgewicht × 2^(Qualität − 4)."] },
    { key = "points.gpRef", type = "slider", label = L["Bezugs-Itemlevel"], default = 66, min = 1, max = 1000, step = 1, available = isEpgp },
    { key = "points.gpBase", type = "slider", label = L["Grund-GP"], default = 100, min = 1, max = 100000, step = 1, available = isEpgp,
      tip = L["PR = EP / (GP + Grund-GP)."] },
    { key = "points.minEp", type = "slider", label = L["Mindest-EP"], default = 0, min = 0, max = 1000000, step = 1, available = isEpgp },
    { key = "points.osPct", type = "slider", label = L["Offspec zahlt (%)"], default = 50, min = 0, max = 100, step = 1, available = hasSys },
    { key = "points.share", type = "toggle", label = L["Punktestand im Raid teilen"], default = true, available = hasSys,
      tip = L["Die Lootleitung schickt den Live-Stand an alle Amisia-Clients im Raid. Angenommen wird er nur von Offizieren der eigenen Gilde."] },
    { key = "points.chat", type = "toggle", label = L["Auf !dkp antworten"], default = true, available = hasSys },
}}

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
local function pointsCommand(rest)
    rest = type(rest) == "string" and rest:match("^%s*(.-)%s*$") or ""
    local cfg = ns.PointsConfig()
    if cfg.sys == "roll" then
        ns.msg(L["Kein Punktesystem gewählt: die Gilde würfelt. Einstellungen, Punkte (DKP/EPGP)."])
        return
    end
    if rest == "" then
        if ns.ShowPage then ns.ShowPage("points") end
        return
    end
    local name = ns.FullName(rest)
    if not name or not cleanName(name) then
        ns.msg(L["Aufruf: /amisia punkte [Name]"])
        return
    end
    if not officerView() and cfg.pub ~= 1 and not ns.SameMain(name, ns.UnitFullName("player")) then
        ns.msg(L["Die Stände anderer sehen nur Offiziere."])
        return
    end
    ns.msg(standingText(ns.PointsOf(name), cfg))
end

local USAGE_ADJ = L["Aufruf: /amisia korrektur <Name> <±Zahl> [ep|gp] <Grund>"]
-- "/amisia korrektur <Name> <±Zahl> [ep|gp] <Grund>": the number is the first word of digits with a
-- sign or none, the name all before it (Forever names hold a space).
local function adjustCommand(rest)
    local words = {}
    for w in (rest or ""):gmatch("%S+") do words[#words + 1] = w end
    local at
    for i, w in ipairs(words) do
        if w:match("^[%+%-]?%d+$") then at = i break end
    end
    if not at or at == 1 then ns.msg(USAGE_ADJ) return end
    local name = table.concat(words, " ", 1, at - 1)
    local n = tonumber((words[at]:gsub("^%+", "")))
    local pool
    local from = at + 1
    local w = words[from] and words[from]:lower()
    if w == "ep" or w == "gp" or w == "dkp" then pool, from = w, from + 1 end
    local reason = table.concat(words, " ", from)
    if reason == "" then ns.msg(USAGE_ADJ) return end
    local e, why = ns.PointsAdjust(name, n, reason, pool)
    if not e then ns.msg(why) return end
    ns.msg(L["Korrektur: %s %s%d %s (%s). Neuer Stand: %s"]:format(e.name, e.n > 0 and "+" or "", e.n, e.pool == "G" and "GP" or (e.pool == "E" and "EP" or "DKP"),
        e.reason, standingText(ns.PointsOf(e.name), ns.PointsConfig())))
end

local ON = { an = true, on = true, ein = true }   -- l10n-ok: typed sub-words
local OFF = { aus = true, off = true }            -- l10n-ok: typed sub-words
local function raidCommand(rest)
    local s = ns.Active and ns.Active()
    if not s then ns.msg(L["Keine laufende Aufzeichnung."]) return end
    local w = tostring(rest or ""):lower():match("^%s*(%S*)")
    if not ON[w] and not OFF[w] then
        local p = ns.PointsSession(s)
        ns.msg(p and (p.off and L["Dieser Raid zählt nicht für Punkte."] or L["Dieser Raid zählt für Punkte (%s)."]:format(SYS_NAME[p.sys] or "?"))
            or L["Dieser Raid hat kein Punktesystem."])
        return
    end
    if not ns.PointsRaidOff(s, OFF[w]) then ns.msg(L["Kein Punktesystem gewählt."]) return end
    ns.msg(OFF[w] and L["Dieser Raid zählt nicht für Punkte."] or L["Dieser Raid zählt für Punkte (%s)."]:format(SYS_NAME[s.points.sys] or "?"))
end

ns.RegisterSlash("punkte", { en = "points", args = L["[Name]"], desc = L["Punktestand (DKP/EPGP)"], run = pointsCommand })
ns.RegisterSlash("korrektur", { en = "adjust", officer = true, args = L["<Name> <±Zahl> [ep|gp] <Grund>"], desc = L["Punkte korrigieren, mit Grund"],
    run = adjustCommand })
ns.RegisterSlash("punkteraid", { en = "raidpoints", officer = true, args = L["an|aus"], desc = L["Laufenden Raid für Punkte zählen oder nicht"],
    run = raidCommand })
