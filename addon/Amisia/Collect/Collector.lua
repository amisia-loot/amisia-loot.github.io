-- Amisia source collector: what no client table says, where an item comes from, as the player
-- meets it. Quests (giver and turn-in NPC with their places, rewards and choices, quest level, the
-- lowest player level that was offered the quest, the player's faction, a pre-quest best effort),
-- vendors (their gear, recipes and limited goods with price, stock and reputation) and the drops of
-- non-boss NPCs (gear and recipes of green or better, with the NPC's classification and place).
-- Boss loot stays with Drops.lua; the item notes (scan.sources) stay with Collect.lua.
--
-- AmisiaDB.collect = { ver = 2, q = { [questID] = record }, s = { [npcID] = record },
-- w = { [npcID] = record } }. A record is one string, the fields split by ";" and the free text last
-- (a third of the room a table takes in the saved file; the exchange sends the same string):
--   q: day;own;giver;giverPos;ender;enderPos;rewards;choices;questLevel;minPlayerLevel;faction;pre;giverName;title
--   s: day;own;pos;items;name                 items "id:price:flags:rep,..." (flags L limited, x other
--                                             currency; rep "<standing 1-8>@<faction>")
--   w: day;own;class;pos;instance;items;name  items "id:count,..."; class n e r R b or empty
-- Positions "uiMapID:x:y" (x and y in hundredths of a percent, 0-10000), "uiMapID" alone, or empty.
-- NPC ids are negative for game objects (a quest from a wanted poster), 0 unknown. day: days since
-- 2026-01-01 (ns.DropsToday), the last day the record was seen or changed. own: a bit mask of the
-- fields after it (bit 0 the first) that this client saw itself; the others, if they hold anything,
-- were heard from the guild (0: all heard, as every record of an exchange blob). No player name is
-- read into a record: names come from the quest/merchant NPC unit or a looted corpse, never from
-- players.
--
-- Every record, own, saved or heard, passes the same strict check: it must parse and read back to
-- exactly the same string (one canonical form, so two clients' checksums agree). Records merge as a
-- join that gives the same result in any order (see merge): own values beat heard ones, so a guild
-- member cannot overwrite what a client saw itself.
local ADDON, ns = ...

local Co = {}
ns.Collect = Co

-- caps; a table so a test can lower one
local L = {
    q = 2500, s = 500, w = 2000,     -- records per kind
    bytes = 480 * 1024,              -- the sum of record lengths plus 16 each (close to the file text)
    rewards = 8, vItems = 48, wItems = 16, wCount = 99,
    maxLen = 2000,                   -- one record string
    preWindow = 30,                  -- seconds after a turn-in in which the same NPC's offer is its follow-up
}
ns.COLLECT_LIMITS = L
local KINDS = { "q", "s", "w" }
local KIND_ORDER = { w = 1, s = 2, q = 3 }   -- among records of the same day, world drops go first
local MAX_ID = 9999999

local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

---------------------------------------------------------------------------
-- Fields
---------------------------------------------------------------------------
-- A decimal integer field: "-12" or "34"; "" is not a number.
local function num(s, lo, hi)
    if type(s) ~= "string" or not s:match("^%-?%d+$") or #s > 10 then return nil end
    local v = tonumber(s)
    if v and v == 0 and s ~= "0" then return nil end   -- "-0", "00"
    if v and tostring(v) ~= s then return nil end
    return int(v, lo, hi) and v or nil
end

local function posOk(s)
    if s == "" then return true end
    local m, x, y = s:match("^(%d+):(%d+):(%d+)$")
    if m then return num(m, 1, 999999) ~= nil and num(x, 0, 10000) ~= nil and num(y, 0, 10000) ~= nil end
    return num(s, 1, 999999) ~= nil
end

-- A text as it may be stored: a clean name (Drops.lua: plain, UTF-8, no control characters or
-- bars, 48 bytes at most), without the separators of its field (sep: a Lua pattern class body).
local function clean(v, sep)
    v = ns.DropsCleanName and ns.DropsCleanName(v) or nil
    if not v then return "" end
    if sep then v = v:gsub("[" .. sep .. "]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") end
    return v
end
local function textOk(s, sep) return s == "" or clean(s, sep) == s end

-- "a;b;c" into exactly n fields, the last one taking the rest (separators included).
local function split(s, n)
    local out, pos = {}, 1
    for i = 1, n - 1 do
        local e = s:find(";", pos, true)
        if not e then return nil end
        out[i] = s:sub(pos, e - 1)
        pos = e + 1
    end
    out[n] = s:sub(pos)
    return out
end

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- "5,7" as { 5, 7 }; ascending, unique, max entries.
local function idList(s, max)
    local out = {}
    if s == "" then return out end
    for e in (s .. ","):gmatch("([^,]*),") do
        local id = num(e, 1, MAX_ID)
        if not id or #out >= max or (out[#out] and out[#out] >= id) then return nil end
        out[#out + 1] = id
    end
    return out
end

-- the smallest ids of a set, at most max, as a sorted list
local function capList(set, max)
    local ids = sortedKeys(set)
    local out = {}
    for i = 1, math.min(#ids, max) do out[i] = ids[i] end
    return out
end

---------------------------------------------------------------------------
-- Records: parse and format (one canonical form)
---------------------------------------------------------------------------
-- The fields of each kind after "day;own;", in record order. Bit i-1 of own stands for field i.
local FIELDS = {
    q = { "giver", "gpos", "ender", "epos", "rewards", "choices", "qlevel", "minlvl", "fac", "pre", "gname", "title" },
    s = { "pos", "items", "name" },
    w = { "class", "pos", "inst", "items", "name" },
}
ns.COLLECT_FIELDS = FIELDS
local function bitOf(i) return 2 ^ (i - 1) end
local function hasBit(mask, i) return math.floor(mask / bitOf(i)) % 2 == 1 end
local function empty(v) return v == "" or v == 0 or (type(v) == "table" and next(v) == nil) end

-- the own mask of r: only bits of fields that hold something (an empty field has no provenance)
local function ownOk(kind, r)
    local n = #FIELDS[kind]
    if not int(r.own, 0, 2 ^ n - 1) then return false end
    for i, f in ipairs(FIELDS[kind]) do
        if hasBit(r.own, i) and empty(r[f]) then return false end
    end
    return true
end
-- the mask that marks every field that holds something as own
local function allOwn(kind, r)
    local m = 0
    for i, f in ipairs(FIELDS[kind]) do
        if not empty(r[f]) then m = m + bitOf(i) end
    end
    return m
end

local P, F = {}, {}

-- "day;own;..." into its two numbers and the n fields after them
local function head(s, n)
    local f = split(s, n + 2)
    if not f then return nil end
    local day, own = num(f[1], 0, 99999), num(f[2], 0, 2 ^ n - 1)
    if not day or not own then return nil end
    return f, day, own
end

function P.q(s)
    local f, day, own = head(s, 12)
    if not f then return nil end
    local r = { day = day, own = own, giver = num(f[3], -MAX_ID, MAX_ID), gpos = f[4], ender = num(f[5], -MAX_ID, MAX_ID),
                epos = f[6], rewards = idList(f[7], L.rewards), choices = idList(f[8], L.rewards), qlevel = num(f[9], 0, 99),
                minlvl = num(f[10], 0, 99), fac = f[11], pre = num(f[12], 0, MAX_ID), gname = f[13], title = f[14] }
    if not (r.giver and r.ender and r.rewards and r.choices and r.qlevel and r.minlvl and r.pre) then return nil end
    if not posOk(r.gpos) or not posOk(r.epos) then return nil end
    if r.fac ~= "" and r.fac ~= "A" and r.fac ~= "H" and r.fac ~= "AH" then return nil end
    if not textOk(r.gname, ";") or not textOk(r.title) then return nil end
    return r
end

function F.q(r)
    return table.concat({ r.day, r.own or 0, r.giver, r.gpos, r.ender, r.epos, table.concat(r.rewards, ","), table.concat(r.choices, ","),
        r.qlevel, r.minlvl, r.fac, r.pre, r.gname, r.title }, ";")
end

local FLAGS = { [""] = true, L = true, x = true, Lx = true }

function P.s(s)
    local f, day, own = head(s, 3)
    if not f then return nil end
    local r = { day = day, own = own, pos = f[3], items = {}, name = f[5] }
    if not posOk(r.pos) or not textOk(r.name) then return nil end
    if f[4] ~= "" then
        local n, last = 0, 0
        for e in (f[4] .. ","):gmatch("([^,]*),") do
            local id, price, flags, rep = e:match("^(%d+):(%d+):(%a*):(.*)$")
            id, price = num(id, 1, MAX_ID), num(price, 0, 2147483647)
            if not id or not price or not FLAGS[flags] or id <= last then return nil end
            if rep ~= "" then
                local standing, faction = rep:match("^(%d)@(.+)$")
                if not num(standing, 1, 8) or clean(faction, ",;:@") ~= faction then return nil end
            end
            n, last = n + 1, id
            if n > L.vItems then return nil end
            r.items[id] = { price = price, flags = flags, rep = rep }
        end
    end
    return r
end

function F.s(r)
    local items = {}
    for _, id in ipairs(sortedKeys(r.items)) do
        local it = r.items[id]
        items[#items + 1] = ("%d:%d:%s:%s"):format(id, it.price, it.flags, it.rep)
    end
    return table.concat({ r.day, r.own or 0, r.pos, table.concat(items, ","), r.name }, ";")
end

local CLASSES = { [""] = true, n = true, e = true, r = true, R = true, b = true }
local CLASS_RANK = { [""] = 0, n = 1, e = 2, r = 3, R = 4, b = 5 }

function P.w(s)
    local f, day, own = head(s, 5)
    if not f then return nil end
    local r = { day = day, own = own, class = f[3], pos = f[4], inst = num(f[5], 0, 99999), items = {}, name = f[7] }
    if not CLASSES[r.class] or not posOk(r.pos) or not r.inst or not textOk(r.name) then return nil end
    if f[6] ~= "" then
        local n, last = 0, 0
        for e in (f[6] .. ","):gmatch("([^,]*),") do
            local id, c = e:match("^(%d+):(%d+)$")
            id, c = num(id, 1, MAX_ID), num(c, 1, L.wCount)
            if not id or not c or id <= last then return nil end
            n, last = n + 1, id
            if n > L.wItems then return nil end
            r.items[id] = c
        end
    end
    return r
end

function F.w(r)
    local items = {}
    for _, id in ipairs(sortedKeys(r.items)) do items[#items + 1] = id .. ":" .. r.items[id] end
    return table.concat({ r.day, r.own or 0, r.class, r.pos, r.inst, table.concat(items, ","), r.name }, ";")
end

-- The record as a table, or nil when it is not a valid record in its one canonical form.
function ns.CollectParse(kind, s)
    if type(s) ~= "string" or #s > L.maxLen or not P[kind] then return nil end
    local ok, r = pcall(P[kind], s)
    if not ok or not r or not ownOk(kind, r) then return nil end
    if F[kind](r) ~= s then return nil end
    return r
end

-- A record table as its string (own defaults to 0, all heard).
function ns.CollectFormat(kind, r) return F[kind](r) end

-- Whether field f of the parsed record r is the client's own observation.
function ns.CollectOwn(kind, r, f)
    for i, name in ipairs(FIELDS[kind] or {}) do
        if name == f then return type(r) == "table" and int(r.own, 0, 2 ^ 12) and hasBit(r.own, i) or false end
    end
    return false
end

-- The record string s with its own mask set: every field that holds something (how "own") or none
-- (how "heard"); nil when s is not valid.
function ns.CollectMark(kind, s, how)
    local r = ns.CollectParse(kind, s)
    if not r then return nil end
    r.own = how == "own" and allOwn(kind, r) or 0
    return F[kind](r)
end

-- The record string without its day and own mask: what two clients compare (a record seen again on
-- another day, or held as heard by one and as own by the other, is the same record).
function ns.CollectBody(s) return type(s) == "string" and s:match("^%d+;%d+;(.*)$") or s end

---------------------------------------------------------------------------
-- Merging: a join (the same result in any order, twice the same as once)
---------------------------------------------------------------------------
-- Per field the pair (own?, value): an own value beats a heard one; two own values, or two heard
-- ones, join as below. Heard data so only fills what the own observations left empty and never
-- replaces an own value, and an own observation replaces heard values (a lexicographic join, still
-- the same in any order). Lists are capped after the union (the smallest ids); an own list never
-- takes heard entries, so its cap keeps only own ones.
--
-- text, id or position: the one there; of two different ones the smaller (byte order)
local function pickText(a, b)
    if a == "" then return b end
    if b == "" or a <= b then return a end
    return b
end
local function pickId(a, b)
    if a == 0 then return b end
    if b == 0 then return a end
    return math.min(a, b)
end
local function unionList(a, b, max)
    local set = {}
    for _, id in ipairs(a) do set[id] = true end
    for _, id in ipairs(b) do set[id] = true end
    return capList(set, max)
end
local function unionFlags(a, b)
    local l = (a:find("L", 1, true) or b:find("L", 1, true)) and "L" or ""
    local x = (a:find("x", 1, true) or b:find("x", 1, true)) and "x" or ""
    return l .. x
end
local function unionFaction(a, b)
    local hasA = a:find("A", 1, true) or b:find("A", 1, true)
    local hasH = a:find("H", 1, true) or b:find("H", 1, true)
    return (hasA and "A" or "") .. (hasH and "H" or "")
end
local function vendorItems(a, b)
    local set = {}
    for id, it in pairs(a) do set[id] = { price = it.price, flags = it.flags, rep = it.rep } end
    for id, it in pairs(b) do
        local x = set[id]
        if x then
            x.price, x.flags, x.rep = math.min(x.price, it.price), unionFlags(x.flags, it.flags), pickText(x.rep, it.rep)
        else
            set[id] = { price = it.price, flags = it.flags, rep = it.rep }
        end
    end
    local items = {}
    for _, id in ipairs(capList(set, L.vItems)) do items[id] = set[id] end
    return items
end
local function worldItems(a, b)
    local set = {}
    for id, c in pairs(a) do set[id] = c end
    for id, c in pairs(b) do set[id] = math.max(set[id] or 0, c) end
    local items = {}
    for _, id in ipairs(capList(set, L.wItems)) do items[id] = set[id] end
    return items
end
local function rewardList(a, b) return unionList(a, b, L.rewards) end
local function rank(a, b) return CLASS_RANK[a] >= CLASS_RANK[b] and a or b end

local JOIN = {
    q = { giver = pickId, gpos = pickText, ender = pickId, epos = pickText, rewards = rewardList, choices = rewardList, qlevel = math.max,
          minlvl = pickId, fac = unionFaction, pre = pickId, gname = pickText, title = pickText },
    s = { pos = pickText, items = vendorItems, name = pickText },
    w = { class = rank, pos = pickText, inst = math.max, items = worldItems, name = pickText },
}

local function merge(kind, a, b)
    local out = { day = math.max(a.day, b.day), own = 0 }
    for i, f in ipairs(FIELDS[kind]) do
        local oa, ob = hasBit(a.own, i), hasBit(b.own, i)
        local v
        if oa == ob then v = JOIN[kind][f](a[f], b[f]) elseif oa then v = a[f] else v = b[f] end
        out[f] = v
        if (oa or ob) and not empty(v) then out.own = out.own + bitOf(i) end
    end
    return out
end

-- Two valid records of a kind as one; nil when either is not valid.
function ns.CollectMergeRecords(kind, a, b)
    local ra, rb = ns.CollectParse(kind, a), ns.CollectParse(kind, b)
    if not ra or not rb then return nil end
    return F[kind](merge(kind, ra, rb))
end

---------------------------------------------------------------------------
-- The saved table, its counts and the caps
---------------------------------------------------------------------------
local counts, bytes = { q = 0, s = 0, w = 0 }, 0
local gen = 0   -- raised on every change (the exchange's index keys on it)

local function weight(s) return #s + 16 end
local function today() return ns.DropsToday and ns.DropsToday() or 0 end
ns.COLLECT_VER = 2

-- A saved record of an older table version as one of this version: version 1 had no own mask, so
-- its records count as heard (nothing tells which of them the client saw itself).
local function upgrade(s, ver)
    if ver == 1 and type(s) == "string" then return (s:gsub("^(%d+;)", "%10;", 1)) end
    return s
end

-- A saved record whose day lies more than a day ahead (a clock that was wrong) gets tomorrow, the
-- most a put takes: a day far in the future would keep it from ever being pruned.
local function clampDay(kind, s)
    local r = ns.CollectParse(kind, s)
    if not r then return nil end
    if r.day > today() + 1 then
        r.day = today() + 1
        return F[kind](r)
    end
    return s
end

-- Checks every saved record (broken ones and ids that are not whole numbers go) and counts again.
function ns.CollectMigrate(root)
    if type(root) ~= "table" then return nil end
    local c = root.collect
    if type(c) ~= "table" then
        c = {}
        root.collect = c
    end
    for k in pairs(c) do
        if k ~= "ver" and k ~= "q" and k ~= "s" and k ~= "w" then c[k] = nil end
    end
    local ver = c.ver
    c.ver = ns.COLLECT_VER
    counts, bytes = { q = 0, s = 0, w = 0 }, 0
    for _, kind in ipairs(KINDS) do
        if type(c[kind]) ~= "table" then c[kind] = {} end
        local t = c[kind]
        local ids = {}
        for id in pairs(t) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
            local s = int(id, 1, MAX_ID) and clampDay(kind, upgrade(t[id], ver)) or nil
            t[id] = s
            if s then
                counts[kind] = counts[kind] + 1
                bytes = bytes + weight(s)
            end
        end
    end
    gen = gen + 1
    return c
end

function ns.CollectDB()
    if not AmisiaDB then return nil end
    local c = AmisiaDB.collect
    if type(c) ~= "table" or type(c.q) ~= "table" or type(c.s) ~= "table" or type(c.w) ~= "table" then
        c = ns.CollectMigrate(AmisiaDB)
    end
    return c
end

-- The oldest records go (smallest day; of one day the ones only heard of before the client's own,
-- then world drops, then vendors, then quests; the highest id first) until every kind is within its cap and the bytes within the budget; a prune
-- goes down to 95 % so a full table is not sorted on every new record.
local function prune(c)
    local over = bytes > L.bytes
    for _, kind in ipairs(KINDS) do
        if counts[kind] > L[kind] then over = true end
    end
    if not over then return 0 end
    local list = {}
    for _, kind in ipairs(KINDS) do
        for id, s in pairs(c[kind]) do
            local day, own = s:match("^(%d+);(%d+);")
            list[#list + 1] = { kind = kind, id = id, day = tonumber(day) or 0, own = own ~= "0" }
        end
    end
    table.sort(list, function(a, b)
        if a.day ~= b.day then return a.day < b.day end
        if a.own ~= b.own then return b.own end
        if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        return a.id > b.id
    end)
    local goal = math.floor(L.bytes * 0.95)
    local cap = {}
    for _, kind in ipairs(KINDS) do cap[kind] = math.floor(L[kind] * 0.95) end
    local removed = 0
    -- per kind first (only its own records), then the bytes (any record)
    for _, e in ipairs(list) do
        if counts[e.kind] > cap[e.kind] and c[e.kind][e.id] then
            bytes = bytes - weight(c[e.kind][e.id])
            c[e.kind][e.id] = nil
            counts[e.kind] = counts[e.kind] - 1
            removed = removed + 1
        end
    end
    if bytes > L.bytes then
        for _, e in ipairs(list) do
            if bytes <= goal then break end
            local s = c[e.kind][e.id]
            if s then
                bytes = bytes - weight(s)
                c[e.kind][e.id] = nil
                counts[e.kind] = counts[e.kind] - 1
                removed = removed + 1
            end
        end
    end
    gen = gen + 1
    return removed
end

function ns.CollectPrune()
    local c = ns.CollectDB()
    return c and prune(c) or 0
end

local function put(c, kind, id, s, quiet)
    local r = int(id, 1, MAX_ID) and ns.CollectParse(kind, s)
    if not r then return nil, "invalid" end
    -- a day ahead is a clock a day ahead; more would pin the record against pruning
    if r.day > today() + 1 then return nil, "future" end
    local t = c[kind]
    local cur = t[id]
    local out, res = s, "new"
    if cur then
        out = ns.CollectMergeRecords(kind, cur, s)
        if not out then
            -- the saved one broke after load: replaced
            out = s
        end
        if out == cur then return "same" end
        res = "merged"
        bytes = bytes - weight(cur)
    else
        counts[kind] = counts[kind] + 1
    end
    t[id] = out
    bytes = bytes + weight(out)
    gen = gen + 1
    if not quiet then prune(c) end
    return res
end

-- Merges a record string into the saved table: "new", "merged", "same", or nil and the reason.
-- how: "own" marks every field that holds something as the client's own, "heard" none of them,
-- nil takes the record's own mask as it is.
function ns.CollectPut(kind, id, s, how)
    local c = ns.CollectDB()
    if not c or not P[kind] then return nil, "no table" end
    if how then
        s = ns.CollectMark(kind, s, how)
        if not s then return nil, "invalid" end
    end
    local res, why = put(c, kind, id, s)
    if res == "new" or res == "merged" then ns.Fire("COLLECT_CHANGED", kind, id) end
    return res, why
end

-- A list of { kind, id, s } with one prune and one change event at the end; the counts
-- { new, merged, same, refused } and the ids that changed ({ [id] = true }).
function ns.CollectPutAll(list)
    local c = ns.CollectDB()
    local n = { new = 0, merged = 0, same = 0, refused = 0, changed = {} }
    if not c then return n end
    for _, e in ipairs(list) do
        local res = put(c, e[1], e[2], e[3], true)
        n[res or "refused"] = n[res or "refused"] + 1
        if res == "new" or res == "merged" then n.changed[e[2]] = true end
    end
    prune(c)
    if n.new + n.merged > 0 then ns.Fire("COLLECT_CHANGED") end
    return n
end

function ns.CollectCounts() return { q = counts.q, s = counts.s, w = counts.w } end
function ns.CollectBytes() return bytes end
function ns.CollectGen() return gen end

-- Own new or changed records this session (the exchange announces again after them).
local ownChanges = 0
function ns.CollectOwnChanges() return ownChanges end

-- An own observation: every field it holds is the client's own.
local function observe(kind, id, r)
    r.own = allOwn(kind, r)
    local res = ns.CollectPut(kind, id, F[kind](r))
    if res == "new" or res == "merged" then ownChanges = ownChanges + 1 end
    return res
end

---------------------------------------------------------------------------
-- Reading the client (every value through ns.Plain: a secret one is skipped)
---------------------------------------------------------------------------
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

-- The NPC id of a GUID: Creature/Vehicle positive, GameObject negative; nil for anything else
-- (players, items, pets) or a secret value.
local function unitId(guid)
    guid = ns.Plain(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    id = tonumber(id)
    if not id or id < 1 or id > MAX_ID then return nil end
    if kind == "Creature" or kind == "Vehicle" then return id end
    if kind == "GameObject" then return -id end
    return nil
end
Co.UnitId = unitId

-- Where the player stands: "map:x:y", "map" (no coordinates, as in an instance) or "".
local function here()
    local mapFn = C_Map and C_Map.GetBestMapForUnit
    local map = tonumber(ns.Plain((call(mapFn, "player"))))
    if not int(map, 1, 999999) then return "" end
    local pos = call(C_Map.GetPlayerMapPosition, map, "player")
    if type(pos) == "table" then
        local x, y
        if type(pos.GetXY) == "function" then x, y = call(pos.GetXY, pos) else x, y = pos.x, pos.y end
        x, y = ns.Plain(x), ns.Plain(y)
        if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x > 0 or y > 0) then
            return ("%d:%d:%d"):format(map, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5))
        end
    end
    return tostring(map)
end
Co.Here = here

local function itemOf(link)
    link = ns.Plain(link)
    local id = type(link) == "string" and ns.ItemID(link) or nil
    return int(id, 1, MAX_ID) and id or nil
end

-- equipLoc and class of an item (C_Item.GetItemInfoInstant needs no cache)
local function itemKind(id)
    local _, _, _, loc, _, class = call(C_Item and C_Item.GetItemInfoInstant, id)
    return ns.Plain(loc), tonumber(ns.Plain(class))
end
local CLASS_RECIPE = 9
local function wearable(loc) return type(loc) == "string" and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP_IGNORE" and loc ~= "INVTYPE_NON_EQUIP" end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
local lastTurnIn   -- { qid, npc, at }: the quest the player just handed in, and to whom
local lastEnder    -- { qid, npc }: who showed the completion of a quest

local function questOn() return AmisiaDB ~= nil and ns.Get("collect.quests") end

local function npcNow()
    local id = unitId(UnitGUID and UnitGUID("npc"))
    local name = ""
    if id and id > 0 then name = clean(ns.Plain((UnitName("npc"))), ";") end
    return id, name
end

local function questId()
    local id = tonumber(ns.Plain((call(GetQuestID))))
    return int(id, 1, MAX_ID) and id or nil
end

local function emptyQuest()
    return { day = today(), giver = 0, gpos = "", ender = 0, epos = "", rewards = {}, choices = {}, qlevel = 0, minlvl = 0,
             fac = "", pre = 0, gname = "", title = "" }
end

local function rewardsInto(r)
    local set = { reward = {}, choice = {} }
    for _, kind in ipairs({ "reward", "choice" }) do
        local fn = kind == "reward" and GetNumQuestRewards or GetNumQuestChoices
        local n = tonumber(ns.Plain((call(fn)))) or 0
        for i = 1, math.min(n, 16) do
            local id = itemOf(call(GetQuestItemLink, kind, i))
            if id then set[kind][id] = true end
        end
    end
    r.rewards, r.choices = capList(set.reward, L.rewards), capList(set.choice, L.rewards)
end

local function faction()
    local f = ns.Plain((call(UnitFactionGroup, "player")))
    return f == "Alliance" and "A" or f == "Horde" and "H" or ""
end

-- QUEST_DETAIL: the giver and what the quest offers.
local function onDetail()
    if not questOn() then return end
    local qid = questId()
    if not qid then return end
    local r = emptyQuest()
    r.title = clean(ns.Plain((call(GetTitleText))))
    local npc, name = npcNow()
    if npc then
        r.giver, r.gname, r.gpos = npc, name, here()
    end
    rewardsInto(r)
    local level = tonumber(ns.Plain((call(UnitLevel, "player"))))
    if int(level, 1, 99) then r.minlvl = level end
    r.fac = faction()
    -- best effort: the same NPC offers this right after taking another quest of the player
    if npc and lastTurnIn and lastTurnIn.npc == npc and lastTurnIn.qid ~= qid and GetTime() - lastTurnIn.at <= L.preWindow then
        r.pre = lastTurnIn.qid
    end
    observe("q", qid, r)
end

-- QUEST_PROGRESS and QUEST_COMPLETE: the NPC that takes the quest back (and on completion the rewards).
local function onEnder(withRewards)
    if not questOn() then return end
    local qid = questId()
    if not qid then return end
    local r = emptyQuest()
    local npc = npcNow()
    if npc then
        r.ender, r.epos = npc, here()
        lastEnder = { qid = qid, npc = npc }
    end
    local title = clean(ns.Plain((call(GetTitleText))))
    r.title = title
    if withRewards then rewardsInto(r) end
    observe("q", qid, r)
end

-- The quest level from the quest log, by either generation of the log functions.
local function logLevel(qid)
    local Q = C_QuestLog
    if Q and Q.GetLogIndexForQuestID and Q.GetInfo then
        local i = tonumber(ns.Plain((call(Q.GetLogIndexForQuestID, qid))))
        local info = i and call(Q.GetInfo, i)
        local lv = type(info) == "table" and tonumber(ns.Plain(info.level)) or nil
        if int(lv, 1, 99) then return lv end
    end
    if GetQuestLogIndexByID and GetQuestLogTitle then
        local i = tonumber(ns.Plain((call(GetQuestLogIndexByID, qid))))
        if i and i > 0 then
            local _, lv = call(GetQuestLogTitle, i)
            lv = tonumber(ns.Plain(lv))
            if int(lv, 1, 99) then return lv end
        end
    end
    return nil
end

-- QUEST_ACCEPTED: (questLogIndex, questID) on the classic clients, (questID) on others.
local function onAccepted(a, b)
    if not questOn() then return end
    local qid = tonumber(ns.Plain(b)) or tonumber(ns.Plain(a))
    if not int(qid, 1, MAX_ID) then return end
    local lv = logLevel(qid)
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and clean(ns.Plain((call(C_QuestLog.GetTitleForQuestID, qid)))) or ""
    if not lv and title == "" then return end
    local r = emptyQuest()
    r.qlevel, r.title = lv or 0, title
    -- an accept never makes a quest on its own: the offer or the log entry did
    local c = ns.CollectDB()
    if c and not c.q[qid] and not lv then return end
    observe("q", qid, r)
end

local function onTurnedIn(qid)
    qid = tonumber(ns.Plain(qid))
    if not int(qid, 1, MAX_ID) then return end
    local npc = (lastEnder and lastEnder.qid == qid) and lastEnder.npc or npcNow()
    lastTurnIn = npc and { qid = qid, npc = npc, at = GetTime() } or nil
end

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then report(err) end
    end
end
ns.OnEvent("QUEST_DETAIL", safe(onDetail))
ns.OnEvent("QUEST_PROGRESS", safe(function() onEnder(false) end))
ns.OnEvent("QUEST_COMPLETE", safe(function() onEnder(true) end))
ns.OnEvent("QUEST_ACCEPTED", safe(onAccepted))
ns.OnEvent("QUEST_TURNED_IN", safe(onTurnedIn))

---------------------------------------------------------------------------
-- Vendors
---------------------------------------------------------------------------
local repPattern
-- "Benötigt %s - %s" as a pattern with two captures; nil when the client has no such string.
local function reputationPattern()
    if repPattern ~= nil then return repPattern or nil end
    local f = _G.ITEM_REQ_REPUTATION
    if type(f) ~= "string" or not f:find("%s", 1, true) then
        repPattern = false
        return nil
    end
    local p = f:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)")
    repPattern = "^" .. p .. "$"
    return repPattern
end

-- the standing 1-8 of a label; a client with gendered labels (FACTION_STANDING_LABELn_FEMALE) may
-- show either
local function standingIndex(label)
    for i = 1, 8 do
        local f = _G["FACTION_STANDING_LABEL" .. i .. "_FEMALE"]
        if _G["FACTION_STANDING_LABEL" .. i] == label or (type(f) == "string" and f == label) then return i end
    end
    return nil
end

-- "<standing>@<faction>" from the merchant tooltip of slot i, or "".
local function merchantRep(i)
    local tip = C_TooltipInfo and C_TooltipInfo.GetMerchantItem
    local pattern = reputationPattern()
    if not tip or not pattern then return "" end
    local data = call(tip, i)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return "" end
    for _, line in ipairs(data.lines) do
        local text = type(line) == "table" and ns.Plain(line.leftText)
        if type(text) == "string" then
            local fac, standing = text:match(pattern)
            local idx = standing and standingIndex(standing)
            fac = fac and clean(fac, ",;:@")
            if idx and fac and fac ~= "" then return idx .. "@" .. fac end
        end
    end
    return ""
end

local function onMerchant()
    if not AmisiaDB or not ns.Get("collect.vendors") then return end
    local npc, name = npcNow()
    if not npc or npc < 1 then return end
    local r = { day = today(), pos = here(), items = {}, name = clean(name) }
    local n = tonumber(ns.Plain((call(GetMerchantNumItems)))) or 0
    local kept = 0
    for i = 1, math.min(n, 200) do
        local id = itemOf(call(GetMerchantItemLink, i))
        if id and not r.items[id] then
            local _, _, price, _, avail, _, _, ext = call(GetMerchantItemInfo, i)
            price, avail, ext = tonumber(ns.Plain(price)) or 0, tonumber(ns.Plain(avail)), ns.Plain(ext)
            local loc, class = itemKind(id)
            local limited = avail ~= nil and avail >= 0
            if wearable(loc) or class == CLASS_RECIPE or limited then
                price = int(math.floor(price), 0, 2147483647) and math.floor(price) or 0
                r.items[id] = { price = price, flags = (limited and "L" or "") .. (ext and "x" or ""), rep = merchantRep(i) }
                kept = kept + 1
                if kept >= L.vItems then break end
            end
        end
    end
    observe("s", npc, r)
end
ns.OnEvent("MERCHANT_SHOW", safe(onMerchant))

---------------------------------------------------------------------------
-- World drops: the non-boss corpses of a loot window (called by Collect.lua on LOOT_OPENED)
---------------------------------------------------------------------------
local looted = {}       -- corpse GUIDs opened this session (a corpse counts once)
local lootedN = 0
local CLASS_LETTER = { normal = "n", trivial = "n", minus = "n", elite = "e", rare = "r", rareelite = "R", worldboss = "b" }

-- name and class letter of the unit (target or mouseover) whose GUID this is
local function unitOfGUID(guid)
    for _, unit in ipairs({ "target", "mouseover" }) do
        local g = ns.Plain(UnitGUID and UnitGUID(unit))
        if g ~= nil and g == guid then
            local class = CLASS_LETTER[ns.Plain((call(UnitClassification, unit)))] or ""
            return clean(ns.Plain((UnitName(unit)))), class
        end
    end
    return "", ""
end

function ns.CollectorFromLoot()
    if not AmisiaDB or not ns.Get("collect.world") then return end
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return end
    local _, kind, _, _, _, _, _, instId = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind == "raid" or kind == "pvp" or kind == "arena" then return end
    local inst = 0
    if kind == "party" then
        inst = tonumber(ns.Plain(instId)) or 0
        if not int(inst, 0, 99999) then inst = 0 end
    end
    local d = ns.DropsDB and ns.DropsDB()
    local groups, order = {}, {}
    local n = tonumber(ns.Plain((GetNumLootItems()))) or 0
    for slot = 1, math.min(n, 32) do
        local src = GetLootSourceInfo and ns.Plain((GetLootSourceInfo(slot))) or nil
        local npc = type(src) == "string" and src:match("^Creature%-") and unitId(src) or nil
        local killId = npc and ns.DropsKillID and ns.DropsKillID(src)
        if npc and npc > 0 and not looted[src] and not (ns.DropsIsBoss and ns.DropsIsBoss(npc))
            and not (killId and d and d.k and d.k[killId]) then
            local id = itemOf(GetLootSlotLink(slot))
            if id then
                local _, _, qty, _, q = GetLootSlotInfo(slot)
                q = tonumber(ns.Plain(q)) or ns.LinkQuality(ns.Plain(GetLootSlotLink(slot)))
                local loc, class = itemKind(id)
                if q and q >= 2 and (wearable(loc) or class == CLASS_RECIPE) then
                    local g = groups[src]
                    if not g then
                        g = { npc = npc, items = {} }
                        groups[src] = g
                        order[#order + 1] = src
                    end
                    qty = math.max(1, math.floor(tonumber(ns.Plain(qty)) or 1))
                    g.items[id] = math.min(L.wCount, (g.items[id] or 0) + qty)
                end
            end
        end
    end
    if #order == 0 then return end
    local pos = here()
    for _, src in ipairs(order) do
        local g = groups[src]
        local name, class = unitOfGUID(src)
        local items = {}
        for _, id in ipairs(capList(g.items, L.wItems)) do items[id] = g.items[id] end
        -- a corpse looted before adds its items once: the count is the sum over corpses
        local c = ns.CollectDB()
        local cur = c and c.w[g.npc] and ns.CollectParse("w", c.w[g.npc])
        -- only own counts add up: heard counts are someone else's corpses
        if cur and ns.CollectOwn("w", cur, "items") then
            for id, k in pairs(items) do items[id] = math.min(L.wCount, k + (cur.items[id] or 0)) end
        end
        observe("w", g.npc, { day = today(), class = class, pos = pos, inst = inst, items = items, name = name })
        if lootedN >= 2000 then looted, lootedN = {}, 0 end
        looted[src] = true
        lootedN = lootedN + 1
    end
end

---------------------------------------------------------------------------
-- Reading the records
---------------------------------------------------------------------------
local function get(kind, id)
    local c = AmisiaDB and type(AmisiaDB.collect) == "table" and AmisiaDB.collect
    local t = c and type(c[kind]) == "table" and c[kind]
    return t and ns.CollectParse(kind, t[tonumber(id)]) or nil
end
function ns.CollectQuest(id) return get("q", id) end
function ns.CollectVendor(npc) return get("s", npc) end
function ns.CollectWorld(npc) return get("w", npc) end

-- Where an observed quest starts: the giver's name (nil when unknown) and its point "map:x:y"
-- (nil without coordinates).
function ns.CollectQuestStart(id)
    local r = get("q", id)
    if not r then return nil, nil end
    local point = r.gpos:match("^%d+:%d+:%d+$") and r.gpos or nil
    return r.gname ~= "" and r.gname or nil, point
end

-- The same from this client's own observation only (fields only heard from the guild left out):
-- the giver's name, the point "uiMapID:x:y"; for places a waypoint may go to.
function ns.CollectQuestOwnStart(id)
    local r = get("q", id)
    if not r then return nil, nil end
    local name = ns.CollectOwn("q", r, "gname") and r.gname ~= "" and r.gname or nil
    local point = ns.CollectOwn("q", r, "gpos") and r.gpos:match("^%d+:%d+:%d+$") and r.gpos or nil
    return name, point
end

---------------------------------------------------------------------------
-- Load, settings, command
---------------------------------------------------------------------------
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ADDON or not AmisiaDB then return end
    ns.CollectMigrate(AmisiaDB)
    prune(AmisiaDB.collect)
end)

ns.COLLECT_SETTINGS = { key = "collect", label = ns.L["Quellen-Sammler"], order = 47, items = {
    { key = "collect.quests", type = "toggle", label = ns.L["Quests aufzeichnen"], default = true,
      tip = ns.L["Questgeber, Abgabe, Orte, Belohnungen und Level, wenn ein Questfenster offen ist."] },
    { key = "collect.vendors", type = "toggle", label = ns.L["Händler aufzeichnen"], default = true,
      tip = ns.L["Ausrüstung, Rezepte und begrenzte Waren eines Händlers mit Preis und Ort."] },
    { key = "collect.world", type = "toggle", label = ns.L["Weltdrops aufzeichnen"], default = true,
      tip = ns.L["Ausrüstung und Rezepte ab grün aus Leichen, die kein Boss sind, mit dem Ort."] },
    { key = "collect.share", type = "toggle", label = ns.L["Mit der Gilde teilen"], default = true,
      tip = ns.L["ohne Namen von Spielern, nur außerhalb von Instanzen und Kämpfen"] },
} }
ns.RegisterSettings(ns.COLLECT_SETTINGS)

ns.RegisterSlash("quellen", { en = "sources", desc = ns.L["Stand des Quellen-Sammlers"], run = function()
    ns.CollectDB()
    local s = ns.CollectSyncStats and ns.CollectSyncStats() or {}
    ns.msg(ns.L["Quellen: %d Quests, %d Händler, %d Weltdrop-NPCs, etwa %d KB. Gelernt %d, gesendet %d Bytes. Teilen %s."]:format(
        counts.q, counts.s, counts.w, math.floor(bytes / 1024 + 0.5), s.new or 0, s.bytes or 0,
        ns.Get("collect.share") and ns.L["an"] or ns.L["aus"]))
end })
