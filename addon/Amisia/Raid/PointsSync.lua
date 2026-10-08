-- Amisia points in the raid: the sync keeper (Sync.lua) shares its live DKP/EPGP standings, the way
-- the loot council's prio is shared (LootPrio.lua): "KV <raid key> <hash> <n>" into the raid, a
-- client with another state asks by whisper "KQ <raid key> <hash>", the keeper answers with blob
-- "KS" (system, the parameters of bids and need rounds, the standings of the group's mains, the
-- costs of the running raid's awards). An officer who sets the cost of an award says it at once:
-- "KC <raid key> <award id> <D|G> <amount> <epoch>"; the other officers take the newer cost.
--
-- Only a verified officer of the own guild in the own group is listened to; a list is checked
-- whole before it replaces the shared one. Raiders keep only the list (AmisiaDB.points.shared =
-- { key, from, at, hash, lv, sys, cfg, list = { [lower] = { name, a, b } } }); officers also take
-- the costs into their raid. Nothing goes out while the guild rolls or points.share is off.
local ADDON, ns = ...

local KV_EVERY = 240           -- the keeper repeats its state this often
local KV_GAP = 10              -- and not more often than this after a change
local ANSWER_AFTER = 2         -- requests within this go out together
local ANSWER_RAID = 3          -- this many requesters: one send into the raid
local MAX_LIST, MAX_COSTS = 60, 200
local MAX_POINTS, MAX_AMOUNT = 9999999, 999999
local ZERO = "0000000000000000"
local SYSTEMS = { dkp = true, epgp = true }
-- the parameters a raider needs: key -> { min, max } (mode: words)
local CFG = { min = { 0, 100000 }, step = { 1, 10000 }, seal = { 0, 1 }, base = { 1, 100000 }, minep = { 0, 1000000 },
              os = { 0, 100 }, pub = { 0, 1 } }
local MODES = { bid = true, fixed = true }

local lastKV                   -- { h, key, at }
local asks, askTimer = {}, false
local wanted = {}              -- raid key -> the announced state this client asked for
local stats = { sent = 0, taken = 0, refused = 0, costs = 0 }

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function now() return GetTime() end

local function shareOn()
    return ns.Get("points.share") ~= false and ns.CommReady and ns.CommReady() and ns.CommPacking()
end

local function running()
    local s = ns.Active and ns.Active()
    if not s or not ns.RaidKey then return nil end
    return s, ns.RaidKey(s)
end

local function store(make)
    if not AmisiaDB then return nil end
    local p = AmisiaDB.points
    if type(p) ~= "table" then
        if not make then return nil end
        p = { adj = {} }
        AmisiaDB.points = p
    end
    return p
end

-- The officers' list of the running raid, or nil: { sys, cfg, list, from }.
function ns.PointsSharedList()
    local p = store()
    local sh = p and p.shared
    if type(sh) ~= "table" or type(sh.list) ~= "table" then return nil end
    local _, key = running()
    if not key or key ~= sh.key then return nil end
    return sh
end

function ns.PointsSyncStats() return stats end

---------------------------------------------------------------------------
-- The keeper's state
---------------------------------------------------------------------------
-- What the keeper shares: { v, sys, cfg, s = { { name, a, b } } (the group's mains), c = { { id, p, n, at, by } } }.
local function build(s)
    local cfg = ns.PointsConfig()
    if not SYSTEMS[cfg.sys] then return nil end
    local out = { v = 1, sys = cfg.sys, cfg = {}, s = {}, c = {} }
    for k in pairs(CFG) do out.cfg[k] = tonumber(cfg[k]) or 0 end
    out.cfg.mode = MODES[cfg.mode] and cfg.mode or "bid"
    -- the standings once (a walk over every saved raid), then the group's mains out of them
    local all = {}
    for _, e in ipairs(ns.PointsStandings()) do all[e.name:lower()] = e end
    local seen = {}
    for _, name in ipairs(ns.GroupRoster()) do
        local main = ns.MainOf(name) or name
        local e = all[main:lower()]
        if not e then
            for _, x in pairs(all) do
                if ns.SameName(x.name, main) then e = x break end
            end
        end
        e = e or { name = main, a = 0, b = 0 }
        if not seen[e.name:lower()] and #out.s < MAX_LIST then
            seen[e.name:lower()] = true
            out.s[#out.s + 1] = { e.name, e.a, e.b }
        end
    end
    table.sort(out.s, function(x, y) return x[1] < y[1] end)
    local p = ns.PointsSession(s)
    local ids = {}
    for id, c in pairs(p and p.charges or {}) do
        if type(c) == "table" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if #out.c >= MAX_COSTS then break end
        local c = p.charges[id]
        out.c[#out.c + 1] = { id, c.p, c.n, c.at, c.by or "" }
    end
    return out
end

local function hashOf(t)
    local parts = { t.sys, tostring(t.cfg.mode) }
    local keys = {}
    for k in pairs(CFG) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(t.cfg[k]) end
    for _, r in ipairs(t.s) do parts[#parts + 1] = ("%s %d %d"):format(r[1], r[2], r[3]) end
    for _, r in ipairs(t.c) do parts[#parts + 1] = ("%s %s %d %d %s"):format(r[1], r[2], r[3], r[4], r[5]) end
    return ns.Checksum(table.concat(parts, "\n"))
end

-- The hash of what this client holds: an officer's own state, a raider's shared list.
local function ownHash()
    local s, key = running()
    if not s then return ZERO end
    if ns.IsOfficerView() then
        local t = build(s)
        return t and hashOf(t) or ZERO
    end
    local p = store()
    local sh = p and p.shared
    return (type(sh) == "table" and sh.key == key and sh.hash) or ZERO
end

local function sendKV()
    if not shareOn() then return end
    local s, key = running()
    if not key or not (ns.SyncIsKeeper and ns.SyncIsKeeper()) or not ns.IsOfficerView() then
        lastKV = nil
        return
    end
    local t = build(s)
    if not t then return end
    local h = hashOf(t)
    local at = now()
    if lastKV and lastKV.key == key then
        if lastKV.h == h and at - lastKV.at < KV_EVERY then return end
        if at - lastKV.at < KV_GAP then return end
    end
    if ns.CommSend("KV", { key, h, tostring(#t.s) }, "RAID", nil, { ttl = 60, key = "KV" }) then
        lastKV = { h = h, key = key, at = at }
    end
end

local function sendList()
    askTimer = false
    local s, key = running()
    if not key or not (ns.SyncIsKeeper and ns.SyncIsKeeper()) then asks = {} return end
    local t = build(s)
    if not t then asks = {} return end
    local who = {}
    for sender in pairs(asks) do who[#who + 1] = sender end
    asks = {}
    local function send(chan, target, opts)
        if ns.CommSendBlob("KS", key, t, chan, target, opts) then stats.sent = stats.sent + 1 end
    end
    if #who >= ANSWER_RAID then
        send("RAID", nil, { ttl = 600, low = true })
        return
    end
    for _, sender in ipairs(who) do send("WHISPER", sender, { ttl = 600, key = "KS:" .. sender, low = true }) end
end

ns.CommOn("KV", function(sender, f, chan)
    if chan ~= "RAID" or not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local key, h = f[1], f[2]
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not shareOn() or not ns.InMyGroup(name) then return end
        local _, own = running()
        if own ~= key then return end
        local p = store()
        local sh = p and type(p.shared) == "table" and p.shared or nil
        if (sh and sh.key == key and (sh.hash == h or sh.lv == h)) or ownHash() == h then return end
        wanted[key] = h
        ns.CommSend("KQ", { key, ownHash() }, "WHISPER", sender, { jitter = 2.75, ttl = 60, key = "KQ:" .. key })
    end)
end)

ns.CommOn("KQ", function(sender, f, chan)
    if chan ~= "WHISPER" or not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        local _, key = running()
        if key ~= f[1] or not (ns.SyncIsKeeper and ns.SyncIsKeeper()) then return end
        asks[sender] = true
        if not askTimer then
            askTimer = true
            C_Timer.After(ANSWER_AFTER, function()
                local okSend, err = pcall(sendList)
                if not okSend then askTimer = false; report(err) end
            end)
        end
    end)
end)

---------------------------------------------------------------------------
-- Checking what arrives
---------------------------------------------------------------------------
local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function idOk(v) return type(v) == "string" and #v == 12 and v:match("^%x+$") ~= nil end
local function byOk(v) return v == "" or (type(v) == "string" and ns.PointsCleanName(v) == v) end

-- A received list, checked whole: { sys, cfg, list, costs } or nil.
local function check(t)
    if type(t) ~= "table" or t.v ~= 1 or not SYSTEMS[t.sys] or type(t.cfg) ~= "table" or type(t.s) ~= "table" or type(t.c) ~= "table" then
        return nil
    end
    local cfg = {}
    for k, v in pairs(t.cfg) do
        if k == "mode" then
            if not MODES[v] then return nil end
            cfg.mode = v
        else
            local r = CFG[k]
            if not r or not int(v, r[1], r[2]) then return nil end
            cfg[k] = v
        end
    end
    local list, n = {}, 0
    for _, r in ipairs(t.s) do
        n = n + 1
        if n > MAX_LIST or type(r) ~= "table" then return nil end
        local name, a, b = r[1], r[2], r[3]
        if type(name) ~= "string" or ns.PointsCleanName(name) ~= name then return nil end
        if not int(a, -MAX_POINTS, MAX_POINTS) or not int(b, -MAX_POINTS, MAX_POINTS) or list[name:lower()] then return nil end
        list[name:lower()] = { name = name, a = a, b = b }
    end
    if n ~= #t.s then return nil end
    local costs, m = {}, 0
    for _, r in ipairs(t.c) do
        m = m + 1
        if m > MAX_COSTS or type(r) ~= "table" then return nil end
        local id, pool, amount, at, by = r[1], r[2], r[3], r[4], r[5]
        if not idOk(id) or (pool ~= "D" and pool ~= "G") or not int(amount, 0, MAX_AMOUNT) or not int(at, 0, time() + 86400) or not byOk(by) then
            return nil
        end
        costs[#costs + 1] = { id = id, p = pool, n = amount, at = at, by = by ~= "" and by or nil }
    end
    if m ~= #t.c then return nil end
    return { sys = t.sys, cfg = cfg, list = list, costs = costs }
end

ns.CommOnBlob("KS", function(sender, tbl, chan, key)
    if not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.InMyGroup(name) then
            stats.refused = stats.refused + 1
            return
        end
        local s, own = running()
        if own ~= key then return end
        local got = check(tbl)
        if not got then
            stats.refused = stats.refused + 1
            return
        end
        local p = store(true)
        if not p then return end
        p.shared = { key = key, from = name, at = time(), hash = hashOf(tbl), lv = wanted[key], sys = got.sys, cfg = got.cfg, list = got.list }
        wanted[key] = nil
        -- an officer takes the costs into the raid (the newer of each wins)
        if ns.IsOfficerView() and ns.PointsTakeCharge then
            for _, c in ipairs(got.costs) do ns.PointsTakeCharge(s, c.id, c.p, c.n, c.at, c.by) end
        end
        stats.taken = stats.taken + 1
        ns.Fire("POINTS")
    end)
end)

---------------------------------------------------------------------------
-- The cost of an award, said at once
---------------------------------------------------------------------------
-- Called by ns.SetAwardPoints for an own change in the running raid.
function ns.PointsShareCharge(s, id, c)
    if not shareOn() then return end
    local rs, key = running()
    if not key or rs ~= s or not ns.IsOfficerView() then return end
    ns.CommSend("KC", { key, id, c.p, tostring(c.n), tostring(c.at) }, "RAID", nil, { ttl = 600, key = "KC:" .. id })
end

ns.CommOn("KC", function(sender, f, chan)
    if chan ~= "RAID" or not shareOn() or not ns.IsOfficerView() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local key, id, pool, amount, at = f[1], f[2], f[3], tonumber(f[4]), tonumber(f[5])
    if at > time() + 86400 then return end
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.InMyGroup(name) then
            stats.refused = stats.refused + 1
            return
        end
        local s, own = running()
        if own ~= key then return end
        if ns.PointsTakeCharge(s, id:lower(), pool, amount, at, name) then stats.costs = stats.costs + 1 end
    end)
end)

C_Timer.NewTicker(5, function()
    local ok, err = pcall(sendKV)
    if not ok then report(err) end
end)
ns.Listen("POINTS", function()
    -- a change goes out with the next tick (at most every 10 s)
    if lastKV then lastKV.h = nil end
end)
ns.Listen("DATA_CHANGED", function()
    if lastKV then lastKV.h = nil end
end)
