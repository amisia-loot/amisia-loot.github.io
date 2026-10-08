-- Amisia loot statistics: per player from the saved raids and their awards, every character of a
-- player counted together (Alts.lua: an alt counts for its main, the split per character is kept).
-- Items won (MS/OS/SR), items per raid there, attendance (raids there over the raids since the
-- player was first seen; the bench counts as there, late is counted but still there), the last
-- item, bosses seen, the longest streak and items per week; the hall of fame picks the best of each.
-- Only numbers the recordings hold: no upgrade sizes, the addon does not know them for the past.
local ADDON, ns = ...
local L = ns.L

local DAY = 86400
local WEEK = 7 * DAY
local WEEKS = 8           -- items per week: this many weeks back
local RANGE_DAYS = 28     -- "letzte 4 Wochen"
ns.STATS_RANGE_DAYS = RANGE_DAYS   -- the roll window's award history counts the same days
local FAME_MIN_RAIDS = 3  -- best attendance needs this many raids since first seen
-- classes that only deal damage; every other class may tank or heal, so its role is unknown
local DPS = { MAGE = true, WARLOCK = true, ROGUE = true, HUNTER = true }

function ns.StatsRole(class)
    return DPS[class or ""] and "dps" or "unknown"
end

local function isPlayerAward(a)
    return (a.to == nil or a.to == "player") and type(a.name) == "string" and a.name ~= "" and a.name ~= "-"
        and ns.FullName(a.name) ~= nil
end

-- The sessions oldest first (the saved list is in that order already; sorted to be sure).
local function sessions()
    local out = {}
    for _, s in ipairs(ns.Sessions()) do
        if type(s) == "table" then out[#out + 1] = s end
    end
    table.sort(out, function(a, b) return (a.start or 0) < (b.start or 0) end)
    return out
end

-- The phase: the raids since the newest raid instance first showed up. Returns { zone, from } or nil.
local function phaseOf(all)
    local first = {}
    for _, s in ipairs(all) do
        local k = tonumber(s.instanceID) or s.zone or "?"
        if not first[k] then first[k] = s end
    end
    local best
    for _, s in pairs(first) do
        if not best or (s.start or 0) > (best.start or 0) then best = s end
    end
    return best and { zone = best.zone or "?", from = best.start or 0 } or nil
end

-- Builds the statistics. opts: range ("4w", "phase", "all"), class (a class token), role ("dps",
-- "unknown"), now (epoch). Returns { raids, from, phase, players, all, awards }: players filtered,
-- all unfiltered; a player is { key, name, class, role, chars, items, ms, os, sr, raids, total,
-- rate, perRaid, late, bench, last, bosses, streak, weeks }.
function ns.StatsBuild(opts)
    opts = opts or {}
    local now = opts.now or time()
    local all = sessions()
    local phase = phaseOf(all)
    local from = 0
    if opts.range == "4w" then
        from = now - RANGE_DAYS * DAY
    elseif opts.range == "phase" then
        from = phase and phase.from or math.huge
    end
    local players, byKey = {}, {}

    -- the player of a character name: by its main first, then by ns.SameMain
    local function playerOf(name)
        name = ns.FullName(ns.Plain(name))
        if not name then return nil end
        local key = tostring(ns.MainOf(name) or name):lower()
        local p = byKey[key]
        if not p then
            for _, o in ipairs(players) do
                if ns.SameMain(o.name, name) then p = o break end
            end
        end
        if not p then
            p = { key = key, name = ns.AltMain(name) or name, chars = {}, items = 0, ms = 0, os = 0, sr = 0, raids = 0, total = 0,
                  late = 0, bench = 0, bosses = 0, streak = 0, weeks = {}, seen = {}, active = false }
            for i = 1, WEEKS do p.weeks[i] = 0 end
            players[#players + 1] = p
        end
        byKey[key] = p
        return p, name
    end
    -- the record of one character of p: spellings of the same character merge (the longer stays)
    local function charOf(p, name)
        for _, c in ipairs(p.chars) do
            if ns.SameName(c.name, name) then
                if #name > #c.name then c.name = name end
                return c
            end
        end
        local c = { name = name, items = 0, raids = 0 }
        p.chars[#p.chars + 1] = c
        return c
    end
    local function noteClass(p, name, class)
        if type(class) ~= "string" or class == "" or class == "UNKNOWN" then return end
        -- the main's class wins, else the first one known
        if not p.class or ns.SameName(name, p.name) then p.class = class end
    end

    -- who was there in each raid: per session, player -> "here" | "late" | "bench"
    local marks = {}
    for i, s in ipairs(all) do
        local m = {}
        for name, mem in pairs(type(s.members) == "table" and s.members or {}) do
            local p, full = playerOf(name)
            if p then
                noteClass(p, full, mem.class)
                -- late only when every character of the player that was there came in late
                local was = m[p]
                if was == "here" then
                    -- stays punctual
                elseif mem.late and (was == nil or was == "late") then
                    m[p] = "late"
                else
                    m[p] = "here"
                end
                if s.start >= from then charOf(p, full).raids = charOf(p, full).raids + 1 end
            end
        end
        for name, e in pairs(type(s.bench) == "table" and s.bench or {}) do
            local p, full = playerOf(name)
            if p then
                noteClass(p, full, type(e) == "table" and e.class or nil)
                if not m[p] then m[p] = "bench" end
            end
        end
        marks[i] = m
        for p in pairs(m) do
            if not p.first then p.first = s.start or 0 end
        end
    end

    local res = { from = from, phase = phase, awards = {}, raids = 0 }
    -- attendance, streak and bosses over the raids in the range
    for i, s in ipairs(all) do
        local m = marks[i]
        local inRange = (s.start or 0) >= from
        if inRange then
            res.raids = res.raids + 1
            for _, p in ipairs(players) do
                if p.first and (s.start or 0) >= p.first then
                    p.total = p.total + 1
                    local mk = m[p]
                    if mk then
                        p.raids = p.raids + 1
                        p.active = true
                        if mk == "late" then p.late = p.late + 1 elseif mk == "bench" then p.bench = p.bench + 1 end
                        p.run = (p.run or 0) + 1
                        if p.run > p.streak then p.streak = p.run end
                    else
                        p.run = 0
                    end
                end
            end
            for _, k in ipairs(type(s.kills) == "table" and s.kills or {}) do
                if type(k) == "table" and k.ok and not k.wait then
                    local seen = {}
                    local who = {}
                    for _, name in ipairs(type(k.who) == "table" and k.who or {}) do who[#who + 1] = name end
                    if #who == 0 then
                        -- no list of who was there: the members seen before the kill
                        for name, mem in pairs(type(s.members) == "table" and s.members or {}) do
                            if (mem.first or 0) <= (k.t or 0) then who[#who + 1] = name end
                        end
                    end
                    for _, name in ipairs(who) do
                        local p = playerOf(name)
                        if p and not seen[p] then
                            seen[p] = true
                            p.bosses = p.bosses + 1
                        end
                    end
                end
            end
        end
        -- awards: items in the range, weeks over the last eight weeks whatever the range
        for _, a in ipairs(type(s.awards) == "table" and s.awards or {}) do
            if type(a) == "table" and isPlayerAward(a) then
                local p, full = playerOf(a.name)
                if p then
                    local t = tonumber(a.t) or s.start or 0
                    local w = math.floor((now - t) / WEEK) + 1
                    if w >= 1 and w <= WEEKS then p.weeks[w] = p.weeks[w] + 1 end
                    if inRange then
                        p.active = true
                        p.items = p.items + 1
                        if a.kind == "MS" then p.ms = p.ms + 1 elseif a.kind == "OS" then p.os = p.os + 1 elseif a.kind == "SR" then p.sr = p.sr + 1 end
                        local c = charOf(p, full)
                        c.items = c.items + 1
                        if not p.last or t > p.last then p.last = t end
                        res.awards[#res.awards + 1] = { player = p, item = a.item, t = t }
                    end
                end
            end
        end
    end

    local shown, everyone = {}, {}
    for _, p in ipairs(players) do
        p.run, p.seen = nil, nil
        p.rate = p.total > 0 and p.raids / p.total or 0
        p.perRaid = p.raids > 0 and p.items / p.raids or 0
        p.role = ns.StatsRole(p.class)
        -- the main first, then the alts by name
        table.sort(p.chars, function(x, y)
            local mx, my = ns.SameName(x.name, p.name), ns.SameName(y.name, p.name)
            if mx ~= my then return mx end
            return x.name < y.name
        end)
        if p.active then
            everyone[#everyone + 1] = p
            if (not opts.class or p.class == opts.class) and (not opts.role or p.role == opts.role) then shown[#shown + 1] = p end
        end
        p.active = nil
    end
    res.players, res.all = shown, everyone
    ns.StatsSort(res.players, "items", true)
    return res
end

local NUMERIC = { items = true, ms = true, os = true, sr = true, perRaid = true, rate = true, last = true, bosses = true,
                  streak = true, raids = true }

-- Sorts players by a column (name or one of NUMERIC), desc for the largest first; ties by name. A
-- player without a last item sorts after every date.
function ns.StatsSort(list, col, desc)
    if not NUMERIC[col] then col = "name" end
    table.sort(list, function(a, b)
        if col ~= "name" then
            local x, y = a[col] or -1, b[col] or -1
            if x ~= y then
                if desc then return x > y end
                return x < y
            end
            return a.name < b.name
        end
        if desc then return a.name > b.name end
        return a.name < b.name
    end)
    return list
end

local function best(list, value, ok)
    local top
    for _, p in ipairs(list) do
        local v = value(p)
        if v and v > 0 and (not ok or ok(p)) then
            if not top or v > top.v or (v == top.v and p.raids > top.p.raids) or (v == top.v and p.raids == top.p.raids and p.name < top.p.name) then
                top = { p = p, v = v }
            end
        end
    end
    return top
end

-- The hall of fame of a result: { { key, title, name, n, text, item } }, an entry only where
-- someone has a number above zero. Keys: items, rate, bosses, streak, wanted.
function ns.StatsFame(res)
    local out, list = {}, res and res.players or {}
    local function add(key, title, top, text)
        if top then out[#out + 1] = { key = key, title = title, name = top.p.name, n = top.v, text = text } end
    end
    local top = best(list, function(p) return p.items end)
    add("items", L["Meiste Items"], top, top and (top.v == 1 and L["1 Item"] or L["%d Items"]:format(top.v)))
    top = best(list, function(p) return p.rate end, function(p) return p.total >= FAME_MIN_RAIDS end)
    add("rate", L["Beste Teilnahme"], top, top and ("%d %% (%d/%d)"):format(math.floor(top.v * 100 + 0.5), top.p.raids, top.p.total))
    top = best(list, function(p) return p.bosses end)
    add("bosses", L["Meiste Bosse gesehen"], top, top and (top.v == 1 and L["1 Bosskill"] or L["%d Bosskills"]:format(top.v)))
    top = best(list, function(p) return p.streak end)
    add("streak", L["Längste Serie"], top, top and (top.v == 1 and L["1 Raid am Stück"] or L["%d Raids am Stück"]:format(top.v)))
    -- the item won that the most raiders on the guild wishlist want
    if ns.WishersOf then
        local w, shown, wished = nil, {}, {}
        for _, p in ipairs(list) do shown[p] = true end
        for _, a in ipairs(res and res.awards or {}) do
            if shown[a.player] then
                local n = wished[a.item]
                if not n then
                    n = #ns.WishersOf(a.item)
                    wished[a.item] = n
                end
                if n > 0 and (not w or n > w.v or (n == w.v and a.t > w.t)) then w = { p = a.player, v = n, item = a.item, t = a.t } end
            end
        end
        if w then
            add("wanted", L["Begehrtestes Item"], w, L["%s, %d auf der Wunschliste"]:format(ns.ItemName(w.item), w.v))
            out[#out].item = w.item
        end
    end
    return out
end
