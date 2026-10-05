-- Amisia sync: the running raid kept by one client, the keeper (the loot lead with officer rank),
-- who sends it after every change as one whole snapshot with a revision and a checksum. The public
-- part (awards without notes, tombstones, the keeper's plus-one) goes to the raid, the officer part
-- (notes, first winners, the bench, kill headers) by whisper to every verified officer. Followers
-- compare the keeper's state (ST) with their own and ask (RQ) when it differs. Only verified
-- officers of the own guild in the own group count as keepers; what a message says about its
-- sender is never trusted. Nothing is merged step by step: a snapshot is checked whole and then
-- replaces the raid's awards (officers: also the bench; kills are only added).
local ADDON, ns = ...

local CLAIM_KEEP = 360        -- seconds a claim of the keeper role holds
local ST_EVERY = 300          -- the keeper's only repetition in the raid
local TICK_EVERY = 5
local SEND_AFTER, SEND_LATEST = 3, 10
local RQ_SPREAD = 2.75        -- a request goes 0 to 3 s after the reason (the queue ticks every 0.25 s)
local SP_FRESH = 15           -- a snapshot of this revision arrived this recently: no request
local SO_WAIT = 20            -- seconds an officer waits for the officer part before asking
local TAKEOVER_WAIT = 10
local ANSWERS_MAX, ANSWER_WINDOW = 6, 60
local DATA_TTL = 1800         -- snapshots wait out a boss fight in the queue
local ZERO = "0000000000000000"
local MAX_AWARDS, MAX_GONE, MAX_BENCH, MAX_KILLS, MAX_PLUS = 400, 400, 40, 100, 80
local SAME_FIGHT = 120
local KINDS = { MS = true, OS = true, SR = true, ["-"] = true }
local TARGETS = { player = true, bank = true, de = true }
local KILL_SRC = { enc = true, kill = true, loot = true, hand = true }

local claims = {}         -- lower name -> { name, key, at, rev }: claims of verified officers
local maxRev = {}         -- key -> { rev, name }: the highest revision an officer announced
local officers = {}       -- lower name -> name: verified officers that spoke Amisia this session
local role, roleKey, keeperName   -- "keeper" | "follower" | nil for the raid key roleKey
local keptKey             -- the raid key this client last kept (for the hand-over note)
local claiming, claimKey = false, nil
local lastST
local takeover            -- { key, from, token }: a new keeper waits for the old keeper's snapshot
local sendFirst, sendToken
local lastSent = {}       -- key -> revision this client sent last
local pend = {}           -- key -> { sp, so, from, sender, token }: an officer waits for both parts
local lastSP = {}         -- key -> { r, at }: the last snapshot of the keeper that arrived
local badRev = {}         -- key -> revision of a refused snapshot (never asked for again)
local rqBusy = {}         -- key -> true while a request waits for its random delay
local lostAsked = {}      -- key -> own revision a lost set was asked for
local answers = {}        -- GetTime() of the answers to requests in the last minute
local warnedSize = false
local ticker
local stats = { applied = 0, refused = 0, wishes = 0, taken = 0, conflicts = 0 }

-- wishes: changes of officers that do not keep the raid
local OP_TTL = 1800           -- a wish waits out a boss fight in the queue
local RETRY_AFTER, MAX_TRIES = 30, 5
local MAX_PENDING, MAX_CONFLICTS = 200, 20
local FIELDS = { "name", "kind", "note", "to" }
local deferred = {}       -- wishes that came while this client took the keeper role over
local answered = {}       -- "sender:opid" -> { kind, fields }: the keeper's answers of this session
local answeredCount = 0
local deniedSaid = {}     -- key -> true: "takes no changes" was said for this raid
local fullSaid = {}       -- key -> true: "too many waiting changes" was said for this raid
local flush               -- forward: sends the waiting wishes of the running raid

local function now() return GetTime() end
local function me() return ns.UnitFullName("player") end

local noted = {}
local function debugOnce(reason, text)
    if not ns.Get("sync.debug") then return end
    local t = now()
    if noted[reason] and t - noted[reason] < 60 then return end
    noted[reason] = t
    DEFAULT_CHAT_FRAME:AddMessage("|cff999999Amisia Sync: " .. text .. "|r")
end

---------------------------------------------------------------------------
-- The raid key and the running raid
---------------------------------------------------------------------------
-- The key of a raid on every client: raid night and instance ("2026-10-05:409"), not s.id.
function ns.RaidKey(s)
    if type(s) ~= "table" or type(s.date) ~= "string" then return nil end
    return ("%s:%d"):format(s.date, tonumber(s.instanceID) or 0)
end

local function isKey(v) return type(v) == "string" and v:match("^%d%d%d%d%-%d%d%-%d%d:%d+$") ~= nil end
local function isHash(v) return type(v) == "string" and #v == 16 and v:match("^%x+$") ~= nil end

local function running()
    local s = ns.Active and ns.Active()
    if not s then return nil end
    return s, ns.RaidKey(s)
end

-- The raid a snapshot of key is for: the running recording, else the newest raid with that key
-- within record.resumeHours. Never a new raid.
local function sessionFor(key)
    local s, k = running()
    if s and k == key then return s end
    local list = ns.Sessions()
    for i = #list, 1, -1 do
        local o = list[i]
        if ns.RaidKey(o) == key then
            if time() - (o.last or o.start or 0) <= (ns.Get("record.resumeHours") or 2) * 3600 then return o end
            return nil
        end
    end
    return nil
end

local function ready() return ns.CommReady() and ns.CommPacking() end

-- Officer view and officer rank: this client takes the officer part.
local function officerSelf() return ns.IsOfficerView() and ns.SelfIsOfficer() end

---------------------------------------------------------------------------
-- Keeper choice: the same order on every client
---------------------------------------------------------------------------
local MASTER = (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2

-- The master looter as this client sees him, or nil.
local function masterLooter()
    local info = _G.C_PartyInfo
    if type(info) ~= "table" or type(info.GetLootMethod) ~= "function" then return nil end
    local ok, method, partyID, raidID = pcall(info.GetLootMethod)
    if not ok then return nil end
    method, partyID, raidID = ns.Plain(method), ns.Plain(partyID), ns.Plain(raidID)
    if method ~= MASTER then return nil end
    if raidID then
        local name = ns.Plain((GetRaidRosterInfo(raidID)))
        return type(name) == "string" and ns.FullName(name) or nil
    end
    if partyID == 0 then return me() end
    return nil
end

local function raidIndex(name)
    local roster = ns.GroupRoster()
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.Plain((GetRaidRosterInfo(i)))
        if type(n) == "string" and ns.SameNameIn(n, name, roster) then return i end
    end
    return nil
end

local function isLeader(name)
    if ns.SameName(name, me()) then return ns.Plain(UnitIsGroupLeader("player")) == true end
    local i = raidIndex(name)
    return i ~= nil and ns.Plain(UnitIsGroupLeader("raid" .. i)) == true
end

-- 1 master looter, 2 raid leader, 3 anyone else.
local function rankOf(name, ml)
    if ml and ns.SameName(ml, name) then return 1 end
    if isLeader(name) then return 2 end
    return 3
end

-- Whether this client claims the keeper role: sync on, packing, loot lead, officer rank, recording.
local function selfClaims()
    if not ready() or not running() then return false end
    -- polled every few seconds: an empty guild roster is not asked for from here
    return (ns.IsLootLead() and ns.SelfIsOfficer(true)) and true or false
end

local function candidates(key)
    local out, mine = {}, me()
    if claiming and claimKey == key then out[1] = mine end
    local t = now()
    for low, c in pairs(claims) do
        if t - c.at > CLAIM_KEEP or not ns.InMyGroup(c.name) then
            claims[low] = nil
        elseif c.key == key and not ns.SameName(c.name, mine) then
            out[#out + 1] = c.name
        end
    end
    return out
end

-- The keeper of key and his rank, or nil.
local function elect(key)
    local ml = masterLooter()
    local best, bestRank
    for _, name in ipairs(candidates(key)) do
        local r = rankOf(name, ml)
        if not best or r < bestRank or (r == bestRank and name:lower() < best:lower()) then best, bestRank = name, r end
    end
    return best, bestRank
end

local function noteRev(key, rev, name)
    if type(rev) ~= "number" then return end
    if not maxRev[key] or rev > maxRev[key].rev then maxRev[key] = { rev = rev, name = name } end
end

---------------------------------------------------------------------------
-- The snapshot
---------------------------------------------------------------------------
local function num(v) return tonumber(v) or 0 end
-- free text of the own data for a snapshot: no bars or control characters, at most max bytes
local function plainText(v, max)
    v = tostring(v or "?"):gsub("[%c|]", "")
    if #v > max then v = v:sub(1, max) end
    return v ~= "" and v or "?"
end

-- The snapshot of raid s: the public part sp and the officer part so (see the design for the
-- positional fields). sp.h is the checksum over both.
function ns.SyncBuild(s)
    local key = ns.RaidKey(s)
    local sync = type(s.sync) == "table" and s.sync or {}
    -- whole seconds, as the export writes them
    local function sec(v) return math.floor(num(v)) end
    local t0 = sec(s.start)
    local a, g, n = {}, {}, {}
    local function extra(x)
        if x.note or x.orig or x.manual then n[x.id] = { x.note or "", x.orig or "", x.manual and 1 or 0 } end
    end
    for _, x in ipairs(s.awards or {}) do
        a[#a + 1] = { x.id, x.name, x.item, sec(x.t) - t0, x.kind or "-", plainText(x.src, 80), x.to or "player", num(x.v),
                      x.edited and (sec(x.edited) - t0) or 0 }
        extra(x)
    end
    for _, x in ipairs(s.gone or {}) do
        g[#g + 1] = { x.id, x.item, sec(x.t) - t0, sec(x.deleted or x.t) - t0, x.name, x.kind or "-", plainText(x.src, 80),
                      x.to or "player", num(x.v) }
        extra(x)
    end
    local plus, count = { s = ns.PlusScope and ns.PlusScope() or "raid", n = {} }, 0
    for _, e in ipairs(ns.PlusList()) do
        if count >= MAX_PLUS then break end
        plus.n[e.name] = e.n
        count = count + 1
    end
    local b = {}
    for name, e in pairs(s.bench or {}) do
        b[name] = { sec(e.t ~= nil and e.t or s.start), e.class or "", e.self and 1 or 0, e.by or "-", e.note or "" }
    end
    local x = {}
    for _, k in ipairs(ns.Kills and ns.Kills(s) or {}) do
        x[#x + 1] = { num(k.enc), plainText(k.name, 80), sec(k.start or k.t), sec(k.t), k.ok and 1 or 0, num(k.size), num(k.diff),
                      KILL_SRC[k.src] and k.src or "hand", num(k.n) }
    end
    local sp = { k = key, r = num(sync.rev), by = me(), d = s.date, i = num(s.instanceID), z = plainText(s.zone, 80), t0 = t0,
                 a = a, g = g, p = plus }
    local so = { k = key, r = sp.r, n = n, b = b, x = x }
    sp.h = ns.SyncHashOf(sp, so)
    return sp, so
end

local function row(tag, r, last)
    local parts = { tag }
    for i = 1, last do
        local v = r[i]
        parts[#parts + 1] = v == nil and "" or tostring(v)
    end
    return table.concat(parts, "\t")
end

-- The checksum of a snapshot: a fixed text of the awards and tombstones (by id, with note, first
-- winner and "by hand" of the officer part), the bench (by name) and the kill headers.
function ns.SyncHashOf(sp, so)
    local n = so and so.n or {}
    local lines = {}
    local function extra(id)
        local e = type(n[id]) == "table" and n[id] or {}
        return "\t" .. tostring(e[1] or "") .. "\t" .. tostring(e[2] or "") .. "\t" .. tostring(e[3] or 0)
    end
    local function sorted(list)
        local c = {}
        for i, v in ipairs(list or {}) do c[i] = v end
        table.sort(c, function(x, y) return tostring(x[1]) < tostring(y[1]) end)
        return c
    end
    for _, r in ipairs(sorted(sp.a)) do lines[#lines + 1] = row("A", r, 9) .. extra(r[1]) end
    for _, r in ipairs(sorted(sp.g)) do lines[#lines + 1] = row("G", r, 9) .. extra(r[1]) end
    local b, names = so and so.b or {}, {}
    for name in pairs(b) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do lines[#lines + 1] = row("B\t" .. name, b[name], 5) end
    for _, r in ipairs(so and so.x or {}) do lines[#lines + 1] = row("X", r, 9) end
    return ns.Checksum(table.concat(lines, "\n"))
end

-- The checksum of raid s as its keeper would send it.
function ns.SyncHash(s)
    local sp = ns.SyncBuild(s)
    return sp.h
end

---------------------------------------------------------------------------
-- Checking a snapshot: whole or not at all
---------------------------------------------------------------------------
local function text(v, max) return type(v) == "string" and #v <= max and not v:find("[%c|]") end
local function nameOk(v) return text(v, 48) and ns.FullName(v) ~= nil end
local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function idOk(v) return type(v) == "string" and #v == 12 and v:match("^%x+$") ~= nil end
local function noteOk(v, max) return v == "" or (type(v) == "string" and ns.CleanNote(v, max) == v) end
local function flag(v) return v == 0 or v == 1 end

-- A list 1..n (n <= max) of a table, else nil.
local function list(v, max)
    if type(v) ~= "table" then return nil end
    local n = 0
    for k in pairs(v) do
        if type(k) ~= "number" then return nil end
        n = n + 1
    end
    if n > max or n ~= #v then return nil end
    return n
end

local function map(v, max)
    if type(v) ~= "table" then return nil end
    local n = 0
    for k in pairs(v) do
        if type(k) ~= "string" then return nil end
        n = n + 1
    end
    if n > max then return nil end
    return n
end

-- true, or nil and the reason. so may be nil (a raider checks the public part alone); with so the
-- checksum is checked too. s: the raid it is for (its key must match).
function ns.SyncCheck(sp, so, s)
    if type(sp) ~= "table" then return nil, "Daten" end
    local key = sp.k
    if not isKey(key) or (s and ns.RaidKey(s) ~= key) then return nil, "Schlüssel" end
    if not int(sp.r, 0, 999999) or not isHash(sp.h) or not nameOk(sp.by) then return nil, "Kopf" end
    if type(sp.d) ~= "string" or key:sub(1, 10) ~= sp.d or not int(sp.i, 0, 99999999) or not text(sp.z, 80) then return nil, "Raid" end
    local y, mo, d = sp.d:match("^(%d+)%-(%d+)%-(%d+)$")
    local day = time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 0, min = 0, sec = 0 })
    if type(day) ~= "number" then return nil, "Raid" end
    local lo, hi = day - 86400, day + 3 * 86400
    local span = hi - lo
    local function at(v) return int(v, lo, hi) end
    if not at(sp.t0) then return nil, "Zeit" end
    local t0 = sp.t0
    local function rel(v, zero) return int(v, -span, span) and ((zero and v == 0) or at(t0 + v)) end
    if not list(sp.a, MAX_AWARDS) or not list(sp.g, MAX_GONE) then return nil, "Anzahl" end
    local ids = {}
    for _, r in ipairs(sp.a) do
        if type(r) ~= "table" or not idOk(r[1]) or ids[r[1]] then return nil, "Kennung" end
        ids[r[1]] = true
        if not nameOk(r[2]) or not int(r[3], 1, 999999) or not rel(r[4]) or not KINDS[r[5]] or not text(r[6], 80) or r[6] == ""
            or not TARGETS[r[7]] or not int(r[8], 0, 999999) or not rel(r[9], true) then
            return nil, "Vergabe"
        end
    end
    for _, r in ipairs(sp.g) do
        if type(r) ~= "table" or not idOk(r[1]) or ids[r[1]] then return nil, "Kennung" end
        ids[r[1]] = true
        if not int(r[2], 1, 999999) or not rel(r[3]) or not rel(r[4]) or not nameOk(r[5]) then return nil, "Grabstein" end
        if (r[6] ~= nil and not KINDS[r[6]]) or (r[7] ~= nil and not (text(r[7], 80) and r[7] ~= ""))
            or (r[8] ~= nil and not TARGETS[r[8]]) or (r[9] ~= nil and not int(r[9], 0, 999999)) then
            return nil, "Grabstein"
        end
    end
    if type(sp.p) ~= "table" or (sp.p.s ~= "raid" and sp.p.s ~= "week") or not map(sp.p.n, MAX_PLUS) then return nil, "Plus-Eins" end
    for name, c in pairs(sp.p.n) do
        if not nameOk(name) or not int(c, 0, 999) then return nil, "Plus-Eins" end
    end
    if so == nil then return true end
    if type(so) ~= "table" or so.k ~= key or so.r ~= sp.r then return nil, "Offiziersteil" end
    if not map(so.n, MAX_AWARDS + MAX_GONE) or not map(so.b, MAX_BENCH) or not list(so.x, MAX_KILLS) then return nil, "Offiziersteil" end
    for id, e in pairs(so.n) do
        if not ids[id] or type(e) ~= "table" or not noteOk(e[1], 60) or not (e[2] == "" or nameOk(e[2])) or not flag(e[3]) then
            return nil, "Notiz"
        end
    end
    for name, e in pairs(so.b) do
        if not nameOk(name) or name:find("%d") or type(e) ~= "table" or not at(e[1])
            or not (type(e[2]) == "string" and #e[2] <= 20 and e[2]:match("^%u*$")) or not flag(e[3])
            or not (e[4] == "-" or nameOk(e[4])) or not noteOk(e[5], 40) then
            return nil, "Ersatzbank"
        end
    end
    for _, r in ipairs(so.x) do
        if type(r) ~= "table" or not int(r[1], 0, 99999999) or not text(r[2], 80) or r[2] == "" or not at(r[3]) or not at(r[4])
            or not flag(r[5]) or not int(r[6], 0, 100) or not int(r[7], 0, 1000) or not KILL_SRC[r[8]] or not int(r[9], 0, 100) then
            return nil, "Kill"
        end
    end
    if ns.SyncHashOf(sp, so) ~= sp.h then return nil, "Prüfsumme" end
    return true
end

---------------------------------------------------------------------------
-- Applying a snapshot: new tables first, then the swap; s and its lists keep their identity
---------------------------------------------------------------------------
local function sameKill(k, r)
    if (k.ok and 1 or 0) ~= r[5] then return false end
    if r[1] ~= 0 then
        if k.enc ~= r[1] then return false end
    elseif tostring(k.name or ""):lower() ~= r[2]:lower() then
        return false
    end
    return math.abs((k.t or 0) - r[4]) <= SAME_FIGHT
end

local function fill(list, items)
    for i = #list, 1, -1 do list[i] = nil end
    for i, v in ipairs(items) do list[i] = v end
end

-- Puts own entries the snapshot does not know into a list by their time, without moving the rest.
local function insertByTime(out, x)
    local pos = #out + 1
    for j, o in ipairs(out) do
        if (o.t or 0) > (x.t or 0) then pos = j break end
    end
    table.insert(out, pos, x)
end

local relayer, firstWishes   -- forward: the own waiting wishes on a new snapshot

local function apply(s, sp, so, from)
    local t0 = sp.t0
    local n = so and so.n or {}
    -- the first snapshot of this raid, or of a new keeper
    local first = type(s.sync) ~= "table" or not s.sync.keeper or not ns.SameName(s.sync.keeper, from)
    local known = {}
    for _, r in ipairs(sp.a) do known[r[1]] = true end
    for _, r in ipairs(sp.g) do known[r[1]] = true end
    local function extra(x)
        local e = so and n[x.id]
        if e then
            x.note = e[1] ~= "" and e[1] or nil
            x.orig = e[2] ~= "" and e[2] or nil
            x.manual = e[3] == 1 or nil
        end
    end
    local newA, newG = {}, {}
    for _, r in ipairs(sp.a) do
        local x = { id = r[1], name = r[2], item = r[3], t = t0 + r[4], kind = r[5], src = r[6], to = r[7],
                    v = r[8] > 0 and r[8] or nil, edited = r[9] ~= 0 and (t0 + r[9]) or nil }
        extra(x)
        newA[#newA + 1] = x
    end
    for _, r in ipairs(sp.g) do
        local x = { id = r[1], item = r[2], t = t0 + r[3], deleted = t0 + r[4], name = r[5], kind = r[6] or "-", src = r[7] or "?",
                    to = r[8] or "player", v = (r[9] or 0) > 0 and r[9] or nil }
        extra(x)
        newG[#newG + 1] = x
    end
    -- what only this client has stays (an award made by hand before a keeper was there)
    for _, x in ipairs(s.awards or {}) do
        if not known[x.id] then insertByTime(newA, x) end
    end
    for _, x in ipairs(s.gone or {}) do
        if not known[x.id] then newG[#newG + 1] = x end
    end
    -- the own entries the first snapshot does not have go to the keeper as wishes
    local ownA, ownB = {}, {}
    if first then
        for _, x in ipairs(s.awards or {}) do
            if not known[x.id] then ownA[#ownA + 1] = x end
        end
        if so then
            for name, e in pairs(s.bench or {}) do
                if not so.b[name] then ownB[name] = e end
            end
        end
    end
    local newB, addKills
    if so then
        newB = {}
        for name, e in pairs(so.b) do
            newB[name] = { t = e[1], class = e[2], self = e[3] == 1 or nil, by = e[4] ~= "-" and e[4] or nil, note = e[5] ~= "" and e[5] or nil }
        end
        -- the first snapshot of a keeper keeps the own entries it does not have
        if first then
            for name, e in pairs(s.bench or {}) do
                if not newB[name] then newB[name] = e end
            end
        end
        addKills = {}
        for _, r in ipairs(so.x) do
            local found = false
            for _, k in ipairs(s.kills or {}) do
                if sameKill(k, r) then found = true break end
            end
            if not found then
                -- without who was there: every recorder reads that itself, the site joins them
                addKills[#addKills + 1] = { enc = r[1], name = r[2], start = r[3], t = r[4], ok = r[5] == 1, size = r[6], diff = r[7],
                                            src = r[8], n = r[9], who = {} }
            end
        end
    end
    -- the swap: the award tables of the same id keep their identity
    local pool = {}
    for _, x in ipairs(s.awards or {}) do if x.id then pool[x.id] = x end end
    for _, x in ipairs(s.gone or {}) do if x.id then pool[x.id] = x end end
    local function keep(list)
        for i, x in ipairs(list) do
            local old = known[x.id] and pool[x.id]
            if old and old ~= x then
                for k in pairs(old) do old[k] = nil end
                for k, v in pairs(x) do old[k] = v end
                list[i] = old
            end
        end
    end
    keep(newA)
    keep(newG)
    s.awards = s.awards or {}
    s.gone = s.gone or {}
    fill(s.awards, newA)
    fill(s.gone, newG)
    if so then
        s.bench = type(s.bench) == "table" and s.bench or {}
        for k in pairs(s.bench) do s.bench[k] = nil end
        for k, v in pairs(newB) do s.bench[k] = v end
        s.kills = s.kills or {}
        for _, k in ipairs(addKills) do s.kills[#s.kills + 1] = k end
        table.sort(s.kills, function(x, y)
            if (x.t or 0) ~= (y.t or 0) then return (x.t or 0) < (y.t or 0) end
            return (x.start or x.t or 0) < (y.start or y.t or 0)
        end)
    end
    local plus = { s = sp.p.s, n = {} }
    for name, c in pairs(sp.p.n) do plus.n[name] = c end
    s.sync = type(s.sync) == "table" and s.sync or {}
    s.sync.key, s.sync.rev, s.sync.hash, s.sync.keeper, s.sync.at, s.sync.plus = sp.k, sp.r, sp.h, from, time(), plus
    stats.applied = stats.applied + 1
    -- what this officer did and the keeper has not confirmed yet stays visible on top
    relayer(s)
    if first then firstWishes(s, ownA, ownB) end
    ns.Fire("DATA_CHANGED")
    ns.Fire("SYNC_STATE")
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function stFields(s, key, claim)
    local sync = s and type(s.sync) == "table" and s.sync or nil
    local flags = "-"
    if claim then
        local ml = masterLooter()
        flags = (ml and ns.SameName(ml, me())) and "KM" or "K"
    end
    return { key, tostring(math.floor(num(sync and sync.rev))), (sync and isHash(sync.hash)) and sync.hash or ZERO, flags }
end

local function sendST(s, key, claim, target)
    if not ns.CommAvailable() or not key then return end
    if target then
        ns.CommSend("ST", stFields(s, key, claim), "WHISPER", target, { key = "STW:" .. target:lower(), ttl = 120 })
        return
    end
    ns.CommSend("ST", stFields(s, key, claim), "RAID", nil, { key = "ST:" .. key, ttl = 600 })
    if claim then lastST = now() end
end

-- The snapshot of s into the raid, the officer part to every officer client of the group, then
-- the keeper's state.
local function broadcast(s)
    local key = ns.RaidKey(s)
    if not key or not ready() then return end
    s.sync = type(s.sync) == "table" and s.sync or { rev = 0 }
    local sp, so = ns.SyncBuild(s)
    s.sync.key, s.sync.hash, s.sync.keeper, s.sync.at = key, sp.h, me(), time()
    local ok, why = ns.CommSendBlob("SP", key, sp, "RAID", nil, { key = "SP:" .. key, ttl = DATA_TTL })
    if not ok then
        if why == "Daten zu groß." and not warnedSize then
            warnedSize = true
            ns.msg("Der Raid-Stand ist zu groß für den Abgleich.")
        end
        return
    end
    for low, name in pairs(officers) do
        if not ns.SameName(name, me()) and ns.InMyGroup(name) and ns.IsVerifiedOfficer(name) ~= false then
            ns.CommSendBlob("SO", key, so, "WHISPER", name, { key = "SO:" .. key .. ":" .. low, ttl = DATA_TTL })
        end
    end
    lastSent[key] = s.sync.rev
    sendST(s, key, true)
end

-- Plans the snapshot: 3 s after the last change, at most 10 s after the first; soon: right away.
local function schedule(s, soon)
    local t = now()
    sendFirst = sendFirst or t
    local due = soon and t or math.min(t + SEND_AFTER, sendFirst + SEND_LATEST)
    local token = {}
    sendToken = token
    C_Timer.After(math.max(0, due - t), function()
        if sendToken ~= token then return end
        sendToken, sendFirst = nil, nil
        local cur, key = running()
        if role == "keeper" and cur and key == roleKey then broadcast(cur) end
    end)
end

---------------------------------------------------------------------------
-- Roles: keeper, follower; taking over and handing over
---------------------------------------------------------------------------
local update
local adopt, onOP   -- forward: the new keeper's own wishes; a wish at the keeper

local function finishTakeover()
    takeover = nil
    local s, key = running()
    if role ~= "keeper" or not s or key ~= roleKey then
        deferred = {}
        return
    end
    s.sync = type(s.sync) == "table" and s.sync or {}
    s.sync.key = key
    -- the revision carries on above everything seen, so no follower takes the new state for old
    s.sync.rev = math.max(num(s.sync.rev), maxRev[key] and maxRev[key].rev or 0) + 1
    s.sync.keeper = me()
    -- what this client changed as a follower holds now: its wishes are the keeper's own changes
    adopt(s)
    sendToken, sendFirst = nil, nil
    broadcast(s)
    -- wishes of other officers that came while taking over
    local list = deferred
    deferred = {}
    for _, d in ipairs(list) do onOP(d[1], d[2], d[3], d[4]) end
end

-- A new keeper asks the old one (else the officer with the highest revision seen) first and waits
-- up to 10 s for that snapshot, so nothing of the old keeper's raid is lost.
local function beginKeeper(s, key, old)
    keptKey = key
    local from = (old and not ns.SameName(old, me())) and old or nil
    local mine = num(type(s.sync) == "table" and s.sync.rev)
    if not from and maxRev[key] and maxRev[key].rev > mine and not ns.SameName(maxRev[key].name, me()) then from = maxRev[key].name end
    if from and ns.InMyGroup(from) then
        local token = {}
        takeover = { key = key, from = from, token = token }
        ns.CommSend("RQ", { key, tostring(mine), "PO" }, "WHISPER", from, { key = "RQ:" .. key })
        C_Timer.After(TAKEOVER_WAIT, function()
            if takeover and takeover.token == token then finishTakeover() end
        end)
    else
        finishTakeover()
    end
end

local function handOver(new)
    sendToken, sendFirst, takeover = nil, nil, nil
    if not new or ns.SameName(new, me()) then return end
    if ns.Get("sync.notify") == false then return end
    local r = rankOf(new, masterLooter())
    ns.msg(("%s hält jetzt den Raid-Stand%s. Deine Änderungen gehen an ihn."):format(new,
        r == 1 and " (Plündermeister)" or r == 2 and " (Schlachtzugsleiter)" or ""))
end

update = function()
    local s, key = running()
    local claimNow = selfClaims()
    if claimNow ~= claiming or (claimNow and key ~= claimKey) then
        local oldKey = claimKey
        claiming, claimKey = claimNow, claimNow and key or nil
        if claimNow then
            sendST(s, key, true)
        elseif oldKey then
            -- the claim ends: one state without K takes it back on every client
            sendST(sessionFor(oldKey), oldKey, false)
        end
    end
    local k = (key and ready()) and elect(key) or nil
    local newRole = k and (ns.SameName(k, me()) and "keeper" or "follower") or nil
    local same = (k == nil and keeperName == nil) or (k ~= nil and keeperName ~= nil and ns.SameName(k, keeperName))
    if newRole == role and key == roleKey and same then return end
    local oldRole, oldKeeper, oldKey = role, keeperName, roleKey
    role, roleKey, keeperName = newRole, key, k
    if oldRole == "keeper" and (newRole ~= "keeper" or key ~= oldKey) then
        sendToken, sendFirst, takeover = nil, nil, nil
    end
    if newRole == "follower" and keptKey and keptKey == key then
        keptKey = nil
        handOver(k)
    end
    if newRole == "keeper" and (oldRole ~= "keeper" or key ~= oldKey) then
        beginKeeper(s, key, oldKey == key and oldKeeper or nil)
    end
    -- a keeper now (or another one): the waiting wishes go to him
    if newRole == "follower" then flush() end
    ns.Fire("SYNC_STATE")
end

-- The keeper of the running raid (nil: none, or no recording).
function ns.SyncKeeperName()
    local _, key = running()
    if not key or key ~= roleKey then return nil end
    return keeperName
end

function ns.SyncIsKeeper() return role == "keeper" and ns.SyncKeeperName() ~= nil end

function ns.SyncStats()
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    return out
end

---------------------------------------------------------------------------
-- Changes of the keeper: Awards.lua, Bench.lua and RaidLog.lua report every change here
---------------------------------------------------------------------------
-- op: "add" (info.a), "edit" (info.id, info.fields, info.was), "delete", "restore" (info.id),
-- "rename" (info.from, info.to, info.ids), "bench+" (info.name, info.e), "bench-" (info.name),
-- "kill+" (info.k), "kill-" (info.k). On the keeper a change of the running raid counts the
-- award's revision (a.v) and the raid's (rev) and plans a snapshot; on an officer that does not
-- keep the raid (or takes it over right now) it becomes a wish to the keeper.
local wishFrom
function ns.SyncNote(op, s, info)
    if ns.AwardsIsQuiet and ns.AwardsIsQuiet() then return end
    local cur, key = running()
    if type(s) ~= "table" or s ~= cur or not ready() then return end
    update()
    info = type(info) == "table" and info or {}
    if role ~= "keeper" or roleKey ~= key or takeover then
        if ns.IsOfficerView() then wishFrom(s, key, op, info) end
        return
    end
    local function bump(id)
        local a = id and ns.FindAward(s, id)
        if a then a.v = num(a.v) + 1 end
    end
    if type(info.a) == "table" then info.a.v = num(info.a.v) + 1 end
    bump(info.id)
    for _, id in ipairs(info.ids or {}) do bump(id) end
    s.sync = type(s.sync) == "table" and s.sync or {}
    s.sync.key = key
    s.sync.rev = num(s.sync.rev) + 1
    s.sync.at = time()
    schedule(s)
end

---------------------------------------------------------------------------
-- Wishes: an officer's change goes to the keeper, who decides and sends the result
---------------------------------------------------------------------------
-- A wish waits in s.sync.pending as { opid, op, base, t, tries, at, to }: op is the change in the
-- own form ({ op = "add", id, a } | { op = "edit", id, fields, was } | { op = "delete", id, was } |
-- { op = "restore", id, fields } | { op = "bench+", name, e } | { op = "bench-", name } |
-- { op = "kill+" | "kill-", k }), base the award's revision it was made on, at and to when and to
-- whom it went last. fields and was hold name, kind, note and to (false: no value).
local function copy(t)
    local c = {}
    for k, v in pairs(type(t) == "table" and t or {}) do c[k] = v end
    return c
end

local function serverTime()
    local t = type(GetServerTime) == "function" and tonumber(ns.Plain(GetServerTime())) or nil
    return t or time()
end

-- A wish id: the time and a running number (no draw from math.random, whose sequence the award
-- ids use). Unique per client; the keeper keeps answers per sender and id.
local opSeq
local function newOpid(s)
    opSeq = (opSeq or math.floor(now() * 1000)) % 65536 + 1
    local id = ("%08x%04x"):format(serverTime() % 4294967296, opSeq % 65536)
    local list = type(s.sync) == "table" and type(s.sync.pending) == "table" and s.sync.pending or {}
    for _, p in ipairs(list) do
        if p.opid == id then return newOpid(s) end
    end
    return id
end

local function syncOf(s)
    if type(s.sync) ~= "table" then s.sync = {} end
    -- a table without its key is dropped on load
    s.sync.key = s.sync.key or ns.RaidKey(s)
    return s.sync
end

local function pendingOf(s)
    local sync = syncOf(s)
    if type(sync.pending) ~= "table" then sync.pending = {} end
    return sync.pending
end

local function awardCopy(a)
    return { id = a.id, name = a.name, item = a.item, t = math.floor(num(a.t)), kind = a.kind or "-", src = plainText(a.src, 80),
             to = a.to or "player", note = a.note, orig = a.orig, manual = a.manual and true or nil }
end

-- name, kind, note and to of an award (false: no value)
local function fieldsOf(a)
    local out = {}
    for _, k in ipairs(FIELDS) do
        if a[k] == nil then out[k] = false else out[k] = a[k] end
    end
    return out
end

local function norm(v)
    if v == nil or v == false then return "" end
    return tostring(v)
end

-- fields for ns.EditAward: no value means an empty note
local function editFields(f)
    local out = {}
    for k, v in pairs(type(f) == "table" and f or {}) do
        if v == false then
            if k == "note" then out[k] = "" end
        else
            out[k] = v
        end
    end
    return out
end

-- Whether a waiting wish touches award id.
local function waitingFor(s, id)
    local list = type(s) == "table" and type(s.sync) == "table" and type(s.sync.pending) == "table" and s.sync.pending or {}
    for _, p in ipairs(list) do
        if type(p.op) == "table" and p.op.id == id then return true end
    end
    return false
end

-- The wish as it goes over the wire (positional award, fields as strings).
local function wire(key, p)
    local o = p.op
    local t = { k = key, o = p.opid, b = num(p.base), op = o.op, id = o.id }
    local function strings(f)
        if type(f) ~= "table" then return nil end
        local out = {}
        for _, k in ipairs(FIELDS) do
            if f[k] ~= nil then out[k] = norm(f[k]) end
        end
        return out
    end
    if o.op == "add" then
        local a = o.a
        t.a = { a.id, a.name, a.item, a.t, a.kind, a.src, a.to, a.note or "", a.orig or "", a.manual and 1 or 0 }
    elseif o.op == "edit" or o.op == "restore" then
        t.f, t.w = strings(o.fields), strings(o.was)
    elseif o.op == "delete" then
        t.w = strings(o.was)
    elseif o.op == "bench+" then
        local e = o.e
        t.n, t.e = o.name, { math.floor(num(e.t)), e.class or "", e.self and 1 or 0, e.by or "-", e.note or "" }
    elseif o.op == "bench-" then
        t.n = o.name
    elseif o.op == "kill+" or o.op == "kill-" then
        local k = o.k
        t.x = { k.enc, k.name, k.start, k.t, k.ok and 1 or 0 }
    end
    return t
end

local function sendWish(key, p)
    if not keeperName then return end
    if ns.CommSendBlob("OP", key, wire(key, p), "WHISPER", keeperName, { key = "OP:" .. p.opid, ttl = OP_TTL }) then
        p.tries = num(p.tries) + 1
        p.at = now()
        p.to = keeperName
    end
end

-- Sends the waiting wishes of the running raid to the keeper: unsent ones and those of an earlier
-- keeper at once, others again 30 s after the last try (5 tries; force starts them anew). In the
-- lockdown the queue holds them and no tries are used up.
-- A waiting wish as this client wrote it (the saved file may have been edited by hand).
local NEEDS = { add = "a", ["bench+"] = "e", ["kill+"] = "k", ["kill-"] = "k" }
local function wellFormed(p)
    if type(p) ~= "table" or not idOk(p.opid) or type(p.op) ~= "table" or type(p.op.op) ~= "string" then return false end
    local need = NEEDS[p.op.op]
    return need == nil or type(p.op[need]) == "table"
end

flush = function(force)
    local s, key = running()
    if not s or role ~= "follower" or roleKey ~= key or not keeperName or not ready() then return end
    local list = type(s.sync) == "table" and s.sync.pending
    if type(list) ~= "table" or #list == 0 then return end
    local held, t = ns.CommHeld(), now()
    for _, p in ipairs(list) do
        if wellFormed(p) then
            if force or not p.to or not ns.SameName(p.to, keeperName) then p.tries = 0 end
            if num(p.tries) == 0 then
                sendWish(key, p)
            elseif held then
                p.at = t
            elseif num(p.tries) < MAX_TRIES and (type(p.at) ~= "number" or p.at > t or t - p.at >= RETRY_AFTER) then
                sendWish(key, p)
            end
        end
    end
end

-- An unsent wish of the same award or bench name takes a new change in (nothing went yet).
local function merge(list, s, w)
    for i = #list, 1, -1 do
        local p = list[i]
        local o = wellFormed(p) and p.op or {}
        if w.id and o.id == w.id then
            if num(p.tries) > 0 then return false end
            if o.op == "add" then
                local a, _, gone = ns.FindAward(s, w.id)
                -- the keeper never knew it: an addition taken back goes nowhere
                if w.op == "delete" or gone or not a then
                    table.remove(list, i)
                    return true
                end
                if w.op == "edit" then
                    o.a = awardCopy(a)
                    return true
                end
            elseif o.op == "edit" and w.op == "edit" and type(o.fields) == "table" and type(o.was) == "table" then
                for k, v in pairs(w.fields) do
                    if o.fields[k] == nil then o.was[k] = w.was[k] end
                    o.fields[k] = v
                end
                return true
            end
            return false
        elseif w.name and o.name == w.name and (w.op == "bench+" or w.op == "bench-") and (o.op == "bench+" or o.op == "bench-") then
            if num(p.tries) > 0 then return false end
            p.op = w
            return true
        end
    end
    return false
end

-- Puts a wish into the waiting list and sends it (base: the award's revision, unless given).
local function queueWish(s, key, w, base, noMerge)
    local list = pendingOf(s)
    stats.wishes = stats.wishes + 1
    if noMerge or not merge(list, s, w) then
        local a = w.id and ns.FindAward(s, w.id)
        list[#list + 1] = { opid = newOpid(s), op = w, base = base or num(a and a.v), t = serverTime(), tries = 0 }
        while #list > MAX_PENDING do
            local old = table.remove(list, 1)
            if role == "follower" and keeperName then
                -- the oldest goes once more, without waiting for an answer
                sendWish(key, old)
            elseif not fullSaid[key] then
                fullSaid[key] = true
                ns.msg("Zu viele wartende Änderungen für den Raid-Stand. Die älteste wird nicht abgeglichen.")
            end
        end
    end
    flush()
    ns.Fire("SYNC_STATE")
end

-- A change of this officer as a wish. A rename is one change of the name per award.
wishFrom = function(s, key, op, info)
    local w
    if op == "rename" then
        for _, id in ipairs(info.ids or {}) do
            local a = ns.FindAward(s, id)
            if a then wishFrom(s, key, "edit", { id = id, fields = { name = a.name }, was = { name = info.from } }) end
        end
        return
    elseif op == "add" and type(info.a) == "table" then
        w = { op = "add", id = info.a.id, a = awardCopy(info.a) }
    elseif op == "edit" and info.id then
        w = { op = "edit", id = info.id, fields = copy(info.fields), was = copy(info.was) }
    elseif op == "delete" and info.id then
        local a = ns.FindAward(s, info.id)
        w = { op = "delete", id = info.id, was = a and fieldsOf(a) or {} }
    elseif op == "restore" and info.id then
        w = { op = "restore", id = info.id }
    elseif op == "bench+" and type(info.name) == "string" and type(info.e) == "table" then
        local e = info.e
        w = { op = "bench+", name = info.name, e = { t = math.floor(num(e.t)), class = e.class or "", self = e.self and true or nil,
                                                    by = e.by, note = e.note } }
    elseif op == "bench-" and type(info.name) == "string" then
        w = { op = "bench-", name = info.name }
    elseif (op == "kill+" or op == "kill-") and type(info.k) == "table" then
        local k = info.k
        -- every recorder reads the boss fights itself: only kills entered by hand are wished
        if op == "kill+" and k.src ~= "hand" then return end
        w = { op = op, k = { enc = math.floor(num(k.enc)), name = plainText(k.name, 80), start = math.floor(num(k.start or k.t)),
                             t = math.floor(num(k.t)), ok = k.ok ~= false } }
    end
    if w then queueWish(s, key, w) end
end

-- One own wish on the own state (quietly: no undo step, no new wish).
local function localApply(s, o)
    if o.op == "add" then
        if not ns.FindAward(s, o.id) then
            local a = o.a
            local x = ns.AddAwardTo(s, { id = a.id, name = a.name, item = a.item, kind = a.kind, src = a.src, t = a.t, to = a.to,
                                         note = a.note, manual = a.manual })
            if x then x.orig = a.orig end
        end
    elseif o.op == "edit" then
        local _, _, gone = ns.FindAward(s, o.id)
        if gone == false then ns.EditAward(s, o.id, editFields(o.fields)) end
    elseif o.op == "delete" then
        ns.DeleteAward(s, o.id)
    elseif o.op == "restore" then
        ns.RestoreAward(s, o.id)
        if o.fields then ns.EditAward(s, o.id, editFields(o.fields)) end
    elseif o.op == "bench+" and type(s.bench) == "table" then
        s.bench[o.name] = copy(o.e)
    elseif o.op == "bench-" and type(s.bench) == "table" then
        s.bench[o.name] = nil
    end
end

-- The own waiting wishes on top of a new snapshot, so the page shows what this officer did until
-- the keeper confirms or refuses it.
relayer = function(s)
    local list = type(s.sync) == "table" and s.sync.pending
    if type(list) ~= "table" or #list == 0 then return end
    ns.AwardsQuiet(function()
        for _, p in ipairs(list) do
            if type(p.op) == "table" then
                local ok, err = pcall(localApply, s, p.op)
                if not ok then
                    local handler = geterrorhandler and geterrorhandler()
                    if handler then handler(err) end
                end
            end
        end
    end)
end

-- The first snapshot of a raid or of a new keeper: every own living award it knows neither as an
-- award nor as a tombstone, and every own bench entry it lacks, goes to the keeper as a wish
-- (unless one waits for it already). Nothing an officer entered before a keeper was there is lost.
firstWishes = function(s, ownA, ownB)
    if role ~= "follower" or not ns.IsOfficerView() or not ready() then return end
    local cur, key = running()
    if s ~= cur then return end
    local waiting = {}
    for _, p in ipairs(type(s.sync.pending) == "table" and s.sync.pending or {}) do
        local o = type(p.op) == "table" and p.op or {}
        if o.id then waiting[o.id] = true end
        if o.name then waiting["bench:" .. o.name] = true end
    end
    for _, x in ipairs(ownA) do
        local a, _, gone = ns.FindAward(s, x.id)
        if a and not gone and not waiting[x.id] then wishFrom(s, key, "add", { a = a }) end
    end
    for name, e in pairs(ownB) do
        if not waiting["bench:" .. name] and type(s.bench) == "table" and s.bench[name] then wishFrom(s, key, "bench+", { name = name, e = e }) end
    end
end

-- A new keeper's own wishes are the keeper's changes now: the awards count them, nothing waits.
adopt = function(s)
    local list = type(s.sync) == "table" and s.sync.pending
    if type(list) ~= "table" or #list == 0 then return end
    for _, p in ipairs(list) do
        local a = type(p.op) == "table" and p.op.id and ns.FindAward(s, p.op.id)
        if a then a.v = num(a.v) + 1 end
    end
    s.sync.pending = {}
end

---------------------------------------------------------------------------
-- The keeper takes a wish: checked whole, applied with the book's own functions, quietly
---------------------------------------------------------------------------
local function parseAward(r, s)
    if type(r) ~= "table" or not idOk(r[1]) or not nameOk(r[2]) or not int(r[3], 1, 999999) or type(r[4]) ~= "number"
        or not KINDS[r[5]] or not text(r[6], 80) or r[6] == "" or not TARGETS[r[7]] or not noteOk(r[8], 60)
        or not (r[9] == "" or nameOk(r[9])) or not flag(r[10]) then
        return nil
    end
    local t = math.floor(r[4])
    if t < num(s.start) - 86400 or t > time() + 86400 then return nil end
    return { id = r[1], name = r[2], item = r[3], t = t, kind = r[5], src = r[6], to = r[7], note = r[8] ~= "" and r[8] or nil,
             orig = r[9] ~= "" and r[9] or nil, manual = r[10] == 1 or nil }
end

-- fields of a wish: only name, kind, note and to, each checked; nil when anything does not fit
local function parseFields(f)
    if type(f) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(f) do
        if k == "name" then
            if not nameOk(v) then return nil end
        elseif k == "kind" then
            if not KINDS[v] then return nil end
        elseif k == "to" then
            if not TARGETS[v] then return nil end
        elseif k == "note" then
            if not noteOk(v, 60) then return nil end
        else
            return nil
        end
        out[k] = v
    end
    return out
end

-- what the officer saw: only compared, never stored
local function parseWas(w)
    local out = {}
    if type(w) ~= "table" then return out end
    for _, k in ipairs(FIELDS) do
        if type(w[k]) == "string" and #w[k] <= 80 then out[k] = w[k] end
    end
    return out
end

-- A conflict: the award changed since the officer's revision, and a field of the wish was changed
-- to something else than both what the officer saw and what he wants.
local function conflicting(a, base, fields, was)
    if base >= num(a.v) then return false end
    for k, mine in pairs(fields) do
        local cur = norm(a[k])
        if cur ~= norm(mine) and (was[k] == nil or cur ~= norm(was[k])) then return true end
    end
    return false
end

-- Whether the award differs from what the officer saw.
local function touched(a, was)
    for _, k in ipairs(FIELDS) do
        if was[k] ~= nil and norm(a[k]) ~= norm(was[k]) then return true end
    end
    return false
end

-- Applies the fields quietly: true when something changed, nil when the book refused them.
local function editQuiet(s, a, fields)
    local before = fieldsOf(a)
    local x = ns.AwardsQuiet(ns.EditAward, s, a.id, editFields(fields))
    if not x then return nil end
    for _, k in ipairs(FIELDS) do
        if norm(a[k]) ~= norm(before[k]) then return true end
    end
    return false
end

local function findKill(s, r)
    for _, k in ipairs(s.kills or {}) do
        if sameKill(k, r) then return k end
    end
    return nil
end

-- "OK" and the award's revision, or the reason of a refusal and the current revision.
local function take(s, name, w)
    local op, base = w.op, w.b
    if type(base) ~= "number" then return "BAD", 0 end
    local changed, id = false, nil
    if op == "add" then
        local x = parseAward(w.a, s)
        if not x then return "BAD", 0 end
        local a = ns.FindAward(s, x.id)
        -- a double (a retry, or an addition the keeper has already): confirmed
        if a then return "OK", num(a.v) end
        a = ns.AwardsQuiet(ns.AddAwardTo, s, { id = x.id, name = x.name, item = x.item, kind = x.kind, src = x.src, t = x.t, to = x.to,
                                               note = x.note, manual = x.manual })
        if not a or a.id ~= x.id then return "BAD", 0 end
        a.orig = x.orig
        a.v = 0
        id, changed = a.id, true
    elseif op == "edit" or op == "delete" or op == "restore" then
        if not idOk(w.id) then return "BAD", 0 end
        local fields
        if w.f ~= nil then
            fields = parseFields(w.f)
            if not fields then return "BAD", 0 end
        end
        local was = parseWas(w.w)
        local a, _, gone = ns.FindAward(s, w.id)
        if not a then return "GONE", 0 end
        id = a.id
        if op == "edit" then
            if gone then return "GONE", num(a.v) end
            if not fields then return "BAD", 0 end
            if conflicting(a, base, fields, was) then return "CONFLICT", num(a.v) end
            changed = editQuiet(s, a, fields)
            if changed == nil then return "BAD", num(a.v) end
        elseif op == "delete" then
            if gone then return "OK", num(a.v) end
            -- the keeper changed the award since: deleting it would lose that
            if base < num(a.v) and touched(a, was) then return "CONFLICT", num(a.v) end
            ns.AwardsQuiet(ns.DeleteAward, s, a.id)
            changed = true
        else
            if gone then
                ns.AwardsQuiet(ns.RestoreAward, s, a.id)
                changed = true
            end
            if fields then
                local c = editQuiet(s, a, fields)
                if c == nil then return "BAD", num(a.v) end
                changed = changed or c
            end
        end
    elseif op == "bench+" then
        local e = w.e
        if not nameOk(w.n) or w.n:find("%d") or type(e) ~= "table" or not (type(e[2]) == "string" and #e[2] <= 20 and e[2]:match("^%u*$"))
            or not flag(e[3]) or not (e[4] == "-" or nameOk(e[4])) or not noteOk(e[5], 40) then
            return "BAD", 0
        end
        local entry = ns.AwardsQuiet(ns.BenchAdd, s, w.n, { note = e[5] ~= "" and e[5] or nil, class = e[2] ~= "" and e[2] or nil,
                                                            self = e[3] == 1 })
        if not entry then return "BAD", 0 end
        -- who put him there: the officer's entry, not the keeper
        if e[3] ~= 1 then entry.by = e[4] ~= "-" and e[4] or name end
        changed = true
    elseif op == "bench-" then
        if not nameOk(w.n) then return "BAD", 0 end
        if ns.IsBenched(s, w.n) then
            ns.AwardsQuiet(ns.BenchRemove, s, w.n)
            changed = true
        end
    elseif op == "kill+" or op == "kill-" then
        local r = w.x
        if type(r) ~= "table" or not int(r[1], 0, 99999999) or not text(r[2], 80) or r[2] == "" or type(r[3]) ~= "number"
            or type(r[4]) ~= "number" or not flag(r[5]) then
            return "BAD", 0
        end
        local k = findKill(s, r)
        if op == "kill+" and not k then
            ns.AwardsQuiet(ns.AddKill, s, { name = r[2], enc = r[1], start = r[3], t = r[4], ok = r[5] == 1 })
            changed = true
        elseif op == "kill-" and k then
            ns.AwardsQuiet(ns.DeleteKill, s, k)
            changed = true
        end
    else
        return "BAD", 0
    end
    local a = id and ns.FindAward(s, id)
    if changed then
        if a then a.v = num(a.v) + 1 end
        local sync = syncOf(s)
        sync.rev = num(sync.rev) + 1
        sync.at = time()
        if id then
            sync.by = type(sync.by) == "table" and sync.by or {}
            sync.by[id] = name
        end
        stats.taken = stats.taken + 1
        schedule(s)
        ns.Fire("SYNC_STATE")
    end
    return "OK", num(a and a.v)
end

-- A wish at the keeper. Only from a verified officer of the guild in the group (checked by the
-- caller: guild member in the group; here: officer rank). Not keeping the running raid: no
-- answer, the officer tries again or sends it to the keeper he finds.
onOP = function(name, sender, w, key)
    local s, k = running()
    if role ~= "keeper" or not s or roleKey ~= k then return end
    if takeover then
        -- the old keeper's snapshot comes first; the wishes after it
        if #deferred < MAX_PENDING then deferred[#deferred + 1] = { name, sender, w, key } end
        return
    end
    local opid = w.o
    local memo = name:lower() .. ":" .. opid
    local function reply(kind, fields)
        answeredCount = answeredCount + 1
        if answeredCount > 1000 then answered, answeredCount = {}, 1 end
        answered[memo] = { kind, fields }
        ns.CommSend(kind, fields, "WHISPER", sender, { ttl = OP_TTL })
    end
    if ns.IsVerifiedOfficer(name) ~= true then return reply("NO", { key, opid, "DENIED", "0" }) end
    if key ~= k then return reply("NO", { key, opid, "NORAID", "0" }) end
    local done = answered[memo]
    if done then
        -- the answer got lost: the same answer again, the wish is not applied twice
        ns.CommSend(done[1], done[2], "WHISPER", sender, { ttl = OP_TTL })
        return
    end
    local ok, verdict, rev = pcall(take, s, name, w)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(verdict) end
        verdict, rev = "BAD", 0
    end
    rev = tostring(math.max(0, math.min(999999, math.floor(num(rev)))))
    if verdict == "OK" then
        reply("OK", { key, opid, rev })
    else
        reply("NO", { key, opid, verdict, rev })
    end
end

---------------------------------------------------------------------------
-- The officer's side: answers, conflicts and resolving them
---------------------------------------------------------------------------
local function findPending(s, opid)
    local list = type(s.sync) == "table" and s.sync.pending
    if type(list) ~= "table" then return nil end
    for i, p in ipairs(list) do
        if p.opid == opid then return p, i, list end
    end
    return nil
end

local function addConflict(s, p, by, why, rev)
    local sync = syncOf(s)
    sync.conflicts = type(sync.conflicts) == "table" and sync.conflicts or {}
    local o = p.op
    local mine
    if o.op == "delete" then
        mine = { deleted = true }
    elseif o.op == "add" then
        mine = fieldsOf(o.a)
    else
        mine = copy(o.fields)
    end
    table.insert(sync.conflicts, { opid = p.opid, id = o.id, op = o.op, mine = mine, by = by, at = serverTime(), why = why, rev = rev,
                                   wish = o })
    while #sync.conflicts > MAX_CONFLICTS do table.remove(sync.conflicts, 1) end
    stats.conflicts = stats.conflicts + 1
    if ns.Get("sync.notify") ~= false then
        local a = o.id and ns.FindAward(s, o.id)
        local item = (a and a.item) or (o.a and o.a.item)
        ns.msg(("Konflikt bei %s: %s hat die Vergabe %s. Siehe Seite Vergaben."):format(ns.ItemName(item or 0), by,
            why == "GONE" and "gelöscht" or "zuerst geändert"))
    end
end

-- Whether a waiting wish was sent to name (or name keeps the raid now).
local function wishKeeper(p, name)
    return (p.to and ns.SameName(p.to, name)) or (keeperName ~= nil and ns.SameName(keeperName, name))
end

-- The waiting wishes of raid s (nil: the running raid): count, and how many gave up (5 tries).
function ns.SyncPendingCount(s)
    s = s or ns.Active()
    local list = type(s) == "table" and type(s.sync) == "table" and type(s.sync.pending) == "table" and s.sync.pending or {}
    local stuck = 0
    for _, p in ipairs(list) do
        if num(p.tries) >= MAX_TRIES then stuck = stuck + 1 end
    end
    return #list, stuck
end

-- Whether a wish for award id of raid s waits for the keeper.
function ns.SyncWaiting(s, id) return waitingFor(s, id) end

-- The conflicts of raid s (oldest first).
function ns.SyncConflicts(s)
    return type(s) == "table" and type(s.sync) == "table" and type(s.sync.conflicts) == "table" and s.sync.conflicts or {}
end

-- Resolves a conflict: take sends the own change again on the keeper's current revision (it wins,
-- unless the keeper changed the award once more); otherwise the conflict is dropped and the
-- keeper's state stays. A change of an award the keeper deleted restores it with the change.
function ns.SyncResolve(s, opid, take)
    local list = ns.SyncConflicts(s)
    local c, idx
    for i, x in ipairs(list) do
        if x.opid == opid then c, idx = x, i break end
    end
    if not c then return nil, "Kein Konflikt." end
    if take then
        local cur, key = running()
        if s ~= cur then return nil, "Der Raid läuft nicht mehr; Änderungen bleiben lokal." end
        local o = type(c.wish) == "table" and c.wish or {}
        local a, _, gone = ns.FindAward(s, o.id)
        if not a then return nil, "Vergabe nicht mehr vorhanden." end
        local w
        if o.op == "edit" or o.op == "restore" then
            if gone then
                w = { op = "restore", id = o.id, fields = copy(o.fields) }
            elseif c.why == "GONE" then
                -- only this client has it: the whole award goes once more, with the change
                ns.AwardsQuiet(ns.EditAward, s, o.id, editFields(o.fields))
                w = { op = "add", id = o.id, a = awardCopy(a) }
            else
                w = { op = "edit", id = o.id, fields = copy(o.fields), was = {} }
            end
        elseif o.op == "delete" then
            w = { op = "delete", id = o.id, was = {} }
        else
            return nil, "Diese Änderung kann nicht erneut gesendet werden."
        end
        table.remove(list, idx)
        if w.op ~= "add" then ns.AwardsQuiet(localApply, s, w) end
        queueWish(s, key, w, math.max(num(c.rev), num(a.v)), true)
    else
        table.remove(list, idx)
    end
    ns.Fire("DATA_CHANGED")
    ns.Fire("SYNC_STATE")
    return true
end

---------------------------------------------------------------------------
-- Following
---------------------------------------------------------------------------
-- Asks the keeper for the snapshot after 0 to 3 s; want: the revision announced (no request when
-- a snapshot of it arrived in the last 15 s, or when it was refused).
local function request(key, part, target, want)
    if rqBusy[key] then return end
    rqBusy[key] = true
    C_Timer.After(math.random() * RQ_SPREAD, function()
        rqBusy[key] = nil
        if not ready() then return end
        if want and badRev[key] == want then return end
        local l = lastSP[key]
        if want and l and l.r >= want and now() - l.at < SP_FRESH then return end
        local s = sessionFor(key)
        ns.CommSend("RQ", { key, tostring(math.floor(num(s and type(s.sync) == "table" and s.sync.rev))), part }, "WHISPER", target,
            { key = "RQ:" .. key })
    end)
end

local function compare(s, key, rev, hash, sender)
    if badRev[key] == rev then return end
    local sync = type(s.sync) == "table" and s.sync or nil
    if officerSelf() then
        if not sync or sync.rev ~= rev or sync.hash ~= hash then request(key, "PO", sender, rev) end
    elseif ns.Get("sync.raiderAwards") ~= false then
        if not sync or rev > num(sync.rev) then request(key, "P", sender, rev) end
    end
end

-- Whether name may send the snapshot of key: the keeper by the choice, or the old keeper this
-- client asked while taking over.
local function fromKeeper(name, key)
    if takeover and takeover.key == key and ns.SameName(takeover.from, name) then return true end
    local k = elect(key)
    return k ~= nil and ns.SameName(k, name) and not ns.SameName(k, me())
end

local function newer(s, sp)
    local sync = type(s.sync) == "table" and s.sync or nil
    if not sync or type(sync.rev) ~= "number" then return true end
    return sp.r > sync.rev or (sp.r == sync.rev and sp.h ~= sync.hash)
end

local function refuse(key, r, why)
    badRev[key] = r
    stats.refused = stats.refused + 1
    debugOnce("refused", ("Ungültiges Abbild verworfen (%s)."):format(tostring(why)))
end

local function done(key, from)
    lostAsked[key] = nil
    if takeover and takeover.key == key and ns.SameName(takeover.from, from) then finishTakeover() end
end

local function combine(s, sp, so, from)
    local ok, why = ns.SyncCheck(sp, so, s)
    if not ok then return refuse(sp.k, sp.r, why) end
    if newer(s, sp) then apply(s, sp, so, from) end
    done(sp.k, from)
end

local function onSP(name, sender, sp)
    local key = sp.k
    local s = sessionFor(key)
    if not s or not fromKeeper(name, key) then return end
    lastSP[key] = { r = sp.r, at = now() }
    noteRev(key, sp.r, name)
    local ok, why = ns.SyncCheck(sp, nil, s)
    if not ok then return refuse(key, sp.r, why) end
    if not newer(s, sp) then return done(key, name) end
    if officerSelf() then
        local p = pend[key]
        if p and p.so and p.so.r == sp.r and ns.SameName(p.from, name) then
            pend[key] = nil
            return combine(s, sp, p.so, name)
        end
        local token = {}
        pend[key] = { sp = sp, from = name, token = token }
        -- the officer part did not come (the keeper did not know this client): ask for it
        C_Timer.After(SO_WAIT, function()
            local q = pend[key]
            if q and q.token == token and q.sp and not q.so and ready() then
                ns.CommSend("RQ", { key, tostring(math.floor(num(type(s.sync) == "table" and s.sync.rev))), "O" }, "WHISPER", sender,
                    { key = "RQ:" .. key })
            end
        end)
    elseif ns.Get("sync.raiderAwards") ~= false then
        apply(s, sp, nil, name)
        done(key, name)
    end
end

local function onSO(name, so, key)
    local s = sessionFor(key)
    if not s or type(so) ~= "table" or not officerSelf() or not fromKeeper(name, key) then return end
    local p = pend[key]
    if p and p.sp and p.sp.r == so.r and ns.SameName(p.from, name) then
        pend[key] = nil
        return combine(s, p.sp, so, name)
    end
    pend[key] = { so = so, from = name }
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
ns.CommOn("ST", function(sender, f)
    if not ready() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local key, rev, hash, flags = f[1], tonumber(f[2]), f[3], f[4]
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.InMyGroup(name) or not ready() then return end
        local low = name:lower()
        if flags:find("K", 1, true) then
            claims[low] = { name = name, key = key, at = now(), rev = rev }
        else
            claims[low] = nil
        end
        noteRev(key, rev, name)
        update()
        local s, k = running()
        if not s or k ~= key or role ~= "follower" or not keeperName or not ns.SameName(keeperName, name) then return end
        compare(s, key, rev, hash, sender)
    end)
end)

-- Every verified officer that says hello gets the officer part; a hello without "L" ends a claim;
-- the keeper tells a new raid member his state.
ns.CommOn("HI", function(sender, f, chan, raw)
    if not ns.CommAvailable() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok then return end
        if ns.IsVerifiedOfficer(name) == true and tostring(raw):sub(1, 1) == tostring(ns.SYNC_PROTO) then officers[name:lower()] = name end
        if not tostring(f[3]):find("L", 1, true) and claims[name:lower()] then
            claims[name:lower()] = nil
            update()
        end
        if role == "keeper" and ready() and ns.InMyGroup(name) then
            local s, key = running()
            if s and key == roleKey then sendST(s, key, true, sender) end
        end
    end)
end)

local function answer(name, sender, key, part)
    local s = sessionFor(key)
    if not s or type(s.sync) ~= "table" then return end
    local keeper = role == "keeper" and roleKey == key
    if not keeper then
        -- the new keeper asks the old one while taking over
        local k = elect(key)
        if not (k and ns.SameName(k, name)) then return end
    end
    local officer = ns.IsVerifiedOfficer(name) == true
    if officer then officers[name:lower()] = name end
    local t, recent = now(), {}
    for _, at in ipairs(answers) do
        if t - at < ANSWER_WINDOW then recent[#recent + 1] = at end
    end
    answers = recent
    if #answers >= ANSWERS_MAX then
        -- more requests than answers: one snapshot into the raid for everyone
        if keeper then schedule(s) end
        return
    end
    answers[#answers + 1] = t
    local sp, so = ns.SyncBuild(s)
    local low = name:lower()
    if part:find("P", 1, true) then
        ns.CommSendBlob("SP", key, sp, "WHISPER", sender, { key = "SPW:" .. key .. ":" .. low, ttl = DATA_TTL })
    end
    if part:find("O", 1, true) and officer then
        ns.CommSendBlob("SO", key, so, "WHISPER", sender, { key = "SO:" .. key .. ":" .. low, ttl = DATA_TTL })
    end
end

ns.CommOn("RQ", function(sender, f)
    if not ready() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local key, part = f[1], f[3]
    -- the public part also for raiders of the guild in the group; the officer part only for officers
    ns.TrustWait(name, part == "P" and "member" or "officer", function(ok)
        if ok and ns.InMyGroup(name) and ready() then answer(name, sender, key, part) end
    end)
end)

ns.CommOnBlob("SP", function(sender, tbl, chan, key)
    if not ready() then return end
    local name = ns.TrustName(sender)
    if not name or type(tbl) ~= "table" or tbl.k ~= key then return end
    ns.TrustWait(name, "officer", function(ok)
        if ok and ns.InMyGroup(name) and ready() then onSP(name, sender, tbl) end
    end)
end)

ns.CommOnBlob("SO", function(sender, tbl, chan, key)
    if not ready() or chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name or type(tbl) ~= "table" or tbl.k ~= key then return end
    ns.TrustWait(name, "officer", function(ok)
        if ok and ns.InMyGroup(name) and ready() then onSO(name, tbl, key) end
    end)
end)

-- A wish: by whisper, from a member of the guild in the group (the rank is checked by the keeper,
-- who answers DENIED without it). Guests outside the guild get no answer.
ns.CommOnBlob("OP", function(sender, tbl, chan, key)
    if not ready() or chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name or type(tbl) ~= "table" or tbl.k ~= key or not idOk(tbl.o) then return end
    ns.TrustWait(name, "member", function(ok)
        if ok and ns.InMyGroup(name) and ready() then onOP(name, sender, tbl, key) end
    end)
end)

ns.CommOn("OK", function(sender, f)
    if not ready() then return end
    local name = ns.TrustName(sender)
    local s = name and sessionFor(f[1])
    if not s then return end
    local p, i, list = findPending(s, f[2])
    if not p or not wishKeeper(p, name) then return end
    table.remove(list, i)
    ns.Fire("SYNC_STATE")
end)

ns.CommOn("NO", function(sender, f)
    if not ready() then return end
    local name = ns.TrustName(sender)
    local s = name and sessionFor(f[1])
    if not s then return end
    local p, i, list = findPending(s, f[2])
    if not p or not wishKeeper(p, name) then return end
    table.remove(list, i)
    local why = f[3]
    if why == "CONFLICT" or why == "GONE" then
        addConflict(s, p, name, why, tonumber(f[4]) or 0)
        -- the own state goes back to the keeper's: the next snapshot is taken even of the same revision
        s.sync.hash = nil
        request(f[1], officerSelf() and "PO" or "P", sender, nil)
    elseif why == "DENIED" then
        if not deniedSaid[f[1]] then
            deniedSaid[f[1]] = true
            ns.msg(("%s nimmt deine Änderungen nicht an (kein Offiziersrang laut Gildenliste)."):format(name))
        end
    else
        debugOnce("no:" .. why, ("Änderung abgelehnt (%s)."):format(why))
    end
    ns.Fire("DATA_CHANGED")
    ns.Fire("SYNC_STATE")
end)

-- A part set of the keeper expired: ask once more (once per own revision).
ns.Listen("COMM_BLOB_LOST", function(sender, art, key)
    if (art ~= "SP" and art ~= "SO") or not ready() then return end
    local name = ns.TrustName(sender)
    local s, k = running()
    if not name or not s or k ~= key or role ~= "follower" or not keeperName or not ns.SameName(keeperName, name) then return end
    local rev = num(type(s.sync) == "table" and s.sync.rev)
    if lostAsked[key] == rev then return end
    lostAsked[key] = rev
    request(key, officerSelf() and "PO" or "P", sender, nil)
end)

---------------------------------------------------------------------------
-- The recording, the ticker and the group
---------------------------------------------------------------------------
local function tick()
    update()
    local s, key = running()
    if claiming and s and key == claimKey and (not lastST or now() - lastST >= ST_EVERY) then sendST(s, key, true) end
    flush()
end

-- Start or resume (s): claim again; end (nil, old): a last snapshot when something changed.
ns.Listen("RECORDING", function(s, old)
    if s then
        if not ticker then ticker = C_Timer.NewTicker(TICK_EVERY, tick) end
        claiming, claimKey = false, nil
        update()
        return
    end
    local key = old and ns.RaidKey(old)
    if key and role == "keeper" and roleKey == key and type(old.sync) == "table" and lastSent[key] ~= old.sync.rev then
        sendToken, sendFirst = nil, nil
        broadcast(old)
    end
    update()
    if ticker then ticker:Cancel(); ticker = nil end
end)

for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LOOT_METHOD_CHANGED", "PARTY_LEADER_CHANGED" }) do
    ns.OnEvent(event, function() C_Timer.After(0.5, update) end)
end

ns.Listen("SETTING", function(path)
    if type(path) == "string" and (path:find("^sync%.") or path == "loot.lead" or path == "ui.view") then update() end
end)

---------------------------------------------------------------------------
-- State for the pages and the command
---------------------------------------------------------------------------
-- Verified officers of the group with Amisia (without this client).
local function officerCount()
    local n = 0
    for _, name in pairs(officers) do
        if not ns.SameName(name, me()) and ns.InMyGroup(name) then n = n + 1 end
    end
    return n
end

local function ago(t)
    local d = math.max(0, time() - num(t))
    if d < 60 then return ("%d s"):format(d) end
    if d < 3600 then return ("%d min"):format(math.floor(d / 60)) end
    return ("%d h"):format(math.floor(d / 3600))
end

local function plural(n, one, many) return ("%d %s"):format(n, n == 1 and one or many) end

-- The sync state of raid s (nil: the running raid) for a page: text, colour ("green", "gold",
-- "grey") and the lines of its tooltip.
function ns.SyncStatus(s)
    local cur, key = running()
    s = s or cur
    local tip = {}
    if not ns.CommAvailable() or ns.Get("sync.enabled") == false then
        tip[1] = ns.CommAvailable() and "Der Abgleich ist in den Einstellungen ausgeschaltet." or "Addon-Nachrichten sind nicht verfügbar."
        return "Sync: aus", "grey", tip
    end
    if not ns.CommPacking() then
        tip[1] = "Dem Client fehlen die Pack-Funktionen; der Raid-Abgleich ist aus. Versionsprüfung geht weiter."
        return "Sync: dieser Client kann nicht packen", "grey", tip
    end
    if not s or s ~= cur then
        tip[1] = "Abgeglichen wird nur der laufende Raid. Die Website gleicht ältere Raids über die Kennung der Vergaben ab."
        return "Sync: älterer Raid, Änderungen bleiben lokal", "grey", tip
    end
    local sync = type(s.sync) == "table" and s.sync or {}
    local n, stuck = ns.SyncPendingCount(s)
    local keeper = ns.SyncKeeperName()
    tip[#tip + 1] = "Hüter: " .. (keeper or "keiner")
    tip[#tip + 1] = ("Stand %d · Prüfsumme %s"):format(num(sync.rev), isHash(sync.hash) and sync.hash or "-")
    tip[#tip + 1] = "Wartende Änderungen: " .. n
    tip[#tip + 1] = "Konflikte: " .. #ns.SyncConflicts(s)
    tip[#tip + 1] = ("Schlange: %s%s"):format(plural(ns.CommQueueSize(), "Nachricht", "Nachrichten"), ns.CommHeld() and " (Kampfsperre)" or "")
    if ns.CommHeld() and ns.CommQueueSize() > 0 then
        return ("Sync: wartet auf Kampfende (%s)"):format(plural(ns.CommQueueSize(), "Nachricht", "Nachrichten")), "gold", tip
    end
    if stuck > 0 then
        return ("Sync: %s nicht abgeglichen"):format(plural(stuck, "Änderung", "Änderungen")), "gold", tip
    end
    if not keeper then
        table.insert(tip, 1, "Die Lootleitung hat kein Amisia 2.1 oder keinen Offiziersrang. Jeder Offizier arbeitet für sich; die Website gleicht über die Kennung ab.")
        return "Sync: kein Hüter im Raid", "grey", tip
    end
    if ns.SyncIsKeeper() then
        return ("Sync: du bist Hüter · %s"):format(plural(officerCount(), "Offizier", "Offiziere")), "green", tip
    end
    if n > 0 then
        return ("Sync: %s auf %s"):format(n == 1 and "1 Änderung wartet" or (n .. " Änderungen warten"), keeper), "gold", tip
    end
    return ("Sync: Hüter %s · Stand %d · vor %s"):format(keeper, num(sync.rev), ago(sync.at)), "grey", tip
end

-- "/amisia sync jetzt": the keeper sends the snapshot at once; a follower sends his waiting
-- wishes again and asks the keeper. Returns "keeper" | "follower", or nil and the reason.
function ns.SyncNow()
    if not ready() then return nil, "Der Raid-Abgleich ist aus." end
    local s, key = running()
    if not s then return nil, "Keine laufende Aufnahme." end
    update()
    if role == "keeper" and roleKey == key and not takeover then
        sendToken, sendFirst = nil, nil
        broadcast(s)
        return "keeper"
    end
    if role == "follower" and keeperName then
        flush(true)
        local sync = type(s.sync) == "table" and s.sync or {}
        ns.CommSend("RQ", { key, tostring(math.floor(num(sync.rev))), officerSelf() and "PO" or "P" }, "WHISPER", keeperName,
            { key = "RQ:" .. key })
        return "follower"
    end
    return nil, "Kein Hüter im Raid."
end

ns.RegisterSyncCommand("jetzt", function()
    if not ns.IsOfficerView() then
        ns.msg("Nur in der Offiziersansicht.")
        return
    end
    local done, why = ns.SyncNow()
    if done == "keeper" then
        ns.msg("Raid-Stand gesendet.")
    elseif done == "follower" then
        local n = ns.SyncPendingCount()
        ns.msg(("Beim Hüter nachgefragt%s."):format(n > 0 and (", " .. plural(n, "Änderung", "Änderungen") .. " erneut gesendet") or ""))
    else
        ns.msg(why)
    end
end)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
do
    local items = ns.SYNC_SETTINGS.items
    local at = 2
    for i, it in ipairs(items) do
        if it.key == "sync.enabled" then at = i + 1 end
    end
    table.insert(items, at, { key = "sync.raiderAwards", type = "toggle", label = "Vergaben des Raids von der Lootleitung empfangen", default = true })
    local before = #items + 1
    for i, it in ipairs(items) do
        if it.key == "sync.officerRanks" then before = i end
    end
    table.insert(items, before, { key = "sync.notify", type = "toggle", label = "Hüterwechsel und Konflikte im Chat melden", default = true,
        officer = true })
    -- the switches of "Wer braucht das?" belong to the section too
    local have = {}
    for _, it in ipairs(items) do have[it.key] = true end
    for _, it in ipairs({
        { key = "sync.shareUpgrades", type = "toggle", label = "Der Lootleitung sagen, für welche Items ich ein Upgrade habe", default = true },
        { key = "sync.askUpgrades", type = "toggle", label = "Beim Ansagen fragen, für wen ein Item ein Upgrade ist", default = true, officer = true },
        { key = "sync.needTooltip", type = "toggle", label = "Tooltip-Zeile Upgrade für", default = true, officer = true },
    }) do
        if not have[it.key] then items[#items + 1] = it end
    end
    -- the order of the section
    local ORDER = { "sync.enabled", "sync.raiderAwards", "sync.shareUpgrades", "sync.versionCheck", "sync.outdatedWarn", "sync.askUpgrades",
                    "sync.needTooltip", "sync.notify", "sync.officerRanks", "sync.debug" }
    local rank = {}
    for i, key in ipairs(ORDER) do rank[key] = i end
    for i, it in ipairs(items) do it.at = i end
    table.sort(items, function(x, y)
        local a, b = rank[x.key] or (100 + x.at), rank[y.key] or (100 + y.at)
        return a < b
    end)
    for _, it in ipairs(items) do it.at = nil end
    ns.RegisterSettings(ns.SYNC_SETTINGS)
end

---------------------------------------------------------------------------
-- The command
---------------------------------------------------------------------------
-- "/amisia sync": the state in the chat.
ns.RegisterSyncCommand("", function()
    local text, _, tip = ns.SyncStatus()
    ns.msg(text)
    for _, l in ipairs(tip or {}) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
end)

ns.RegisterSyncCommand("an", function()
    ns.Set("sync.enabled", true)
    ns.msg("Raid-Abgleich an.")
end)

ns.RegisterSyncCommand("aus", function()
    ns.Set("sync.enabled", false)
    ns.msg("Raid-Abgleich aus.")
end)

-- "/amisia sync selbsttest": packs the snapshot of the running or newest raid, unpacks it again
-- and compares; says the size and the parts (checks the client's pack functions in the game).
ns.RegisterSyncCommand("selbsttest", function()
    if not ns.Get("ui.expert") then
        ns.msg("Nur im Expertenmodus.")
        return
    end
    if not ns.CommPacking() then
        ns.msg("Selbsttest: dieser Client kann nicht packen (C_EncodingUtil fehlt). Der Raid-Abgleich ist aus.")
        return
    end
    local s = ns.Active()
    if not s then
        local list = ns.Sessions()
        s = list[#list]
    end
    if not s then
        ns.msg("Selbsttest: noch kein Raid aufgezeichnet.")
        return
    end
    local sp, so = ns.SyncBuild(s)
    local pp, err = ns.CommPack(sp)
    local po = pp and ns.CommPack(so)
    if not pp or not po then
        ns.msg("Selbsttest: Packen fehlgeschlagen" .. (err and (" (" .. err .. ")") or "") .. ".")
        return
    end
    local bp, bo = ns.CommUnpack(pp), ns.CommUnpack(po)
    local same = type(bp) == "table" and type(bo) == "table" and ns.SyncHashOf(bp, bo) == sp.h
    local valid, why = false, nil
    if same then valid, why = ns.SyncCheck(bp, bo, s) end
    local np, no = #ns.CommChunks(pp), #ns.CommChunks(po)
    ns.msg(("Selbsttest: Abbild gepackt und entpackt, %s. Öffentlicher Teil %d Zeichen in %d Teilen, Offiziersteil %d Zeichen in %d Teilen%s."):format(
        same and "gleich" or "NICHT gleich", #pp, np, #po, no,
        same and not valid and (", aber ungültig (" .. tostring(why) .. ")") or ""))
end)
