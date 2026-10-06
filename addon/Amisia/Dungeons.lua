-- Amisia dungeon planner: what every dungeon and raid is worth to the own character right now - the
-- number and size of the upgrades among its bosses' drops, the expected gain of one run (gain times
-- drop chance, summed over bosses and items, without rivals in the group), the open dungeon quests
-- with their best reward, the level fit - and from that the next dungeon to run, with its reason;
-- the waypoint to an entrance. Only item stats the client shows in every tooltip and the loot
-- windows the guild counted go in, nothing from combat.
--
-- The inputs sit behind small functions on ns.Dungeons, so the build's data can take over without
-- touching the rest: Facts (ns.BIS.DG once tools/build_bis.py writes it, else the hand facts of
-- DungeonData.lua), Opts (the own character), Gain (ns.BisGain), Rate (ns.DropRate with the
-- source's chance), BossNpc (the NPC id of a dungeon source, once the item data carries one).
local ADDON, ns = ...
local Gear = ns.Gear

local D = {}
ns.Dungeons = D

local SOON = 2            -- levels below a range that still count as "bald"
local RUNS = 2            -- runs of the usual plan: value = quests + RUNS x gain per run
-- The expected chance of an item whose source names none: one of the boss's known items of its
-- quality, but never more than one of a typical loot table's. A dungeon boss's table holds about six
-- rare items of which one drops per kill (1/6), somewhat more uncommon ones and a dozen or more epics
-- where it has any; the item data and the guild's records often know only one or two of them, and
-- "the only known item" is no 100 % chance. Never above PRIOR_MAX; the rate reads "Chance unbekannt".
local PRIOR_TABLE = { [2] = 8, [3] = 6, [4] = 12 }
local PRIOR_DEFAULT = 6
local PRIOR_MAX = 0.5
-- An NPC known only from the guild's records (neither the facts, the item data nor the base stock
-- name it as a boss) is listed but counts for the value and the recommendation from this many kills:
-- one trash corpse with a world drop is no boss.
local MIN_KILLS = 3
local NO_DATA = "Keine Dungeon-Daten."
local NO_HIT = "Für dein Level hat kein Dungeon noch Upgrades für dich."
local NO_ENTRANCE = "Für diesen Dungeon kennt Amisia keinen Eingang."
local NO_MAP = "Keine Kartendaten für diesen Client."
D.NO_DATA, D.NO_HIT = NO_DATA, NO_HIT

local FIT_TEXT = { fit = "passt", soon = "bald", easy = "leicht", high = "zu hoch" }
local FIT_ORDER = { fit = 1, soon = 2 }

local function lower(s) return type(s) == "string" and s:lower() or nil end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

---------------------------------------------------------------------------
-- Inputs (the switch points for the build's data)
---------------------------------------------------------------------------

-- The dungeon and raid facts: { { key, name, kind, min, max, size, inst, area, from, bosses,
-- aliases }, ... }; bosses are names (hand facts) or NPC ids (the build). nil without any.
function D.Facts()
    local B = ns.BIS
    if type(B) == "table" and type(B.DG) == "table" then return B.DG end
    local F = ns.DUNGEON_FACTS
    if type(F) == "table" and type(F.list) == "table" then return F.list end
    return nil
end

-- The character the values are for.
function D.Opts() return ns.BisOpts() end

-- gain, slotKey, mine of an item for the options; nil when it is no gear for them.
function D.Gain(id, o) return ns.BisGain(id, o) end

-- The NPC id of a dungeon source record; the item data has none yet.
function D.BossNpc(rec) return nil end

-- p, text, n, K for an item of a boss: with an NPC the guild's kills (base stock and records) with
-- p0 as the expected chance, else p0 alone. A raid's chance comes from observations only. est: p0 is
-- the planner's prior, not the source's chance - it goes into the value, the text says
-- "Chance unbekannt" until the guild has kills.
function D.Rate(boss, id, p0, raid, est)
    if boss.npc and ns.DropRate then
        local p, n, K = ns.DropRate(boss.npc, id, p0)
        if raid and (K or 0) == 0 then return nil, "Chance unbekannt", 0, 0 end
        if p and est and (K or 0) == 0 then return p, "Chance unbekannt", n, K end
        if p then return p, ns.DropRateText(boss.npc, id, p0), n, K end
        return nil, "Chance unbekannt", 0, 0
    end
    if raid or not p0 then return nil, "Chance unbekannt", 0, 0 end
    if est then return p0, "Chance unbekannt", 0, 0 end
    return p0, ("Chance %d %%"):format(math.floor(p0 * 100 + 0.5)), 0, 0
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function itemInfo(id)
    local f = C_Item and C_Item.GetItemInfo
    if type(f) ~= "function" then return nil end
    local ok, name, _, q, _, req = pcall(f, id)
    if not ok then return nil end
    return ns.Plain(name), tonumber(ns.Plain(q)), tonumber(ns.Plain(req))
end

local function quality(id)
    local row = Gear.Item(id)
    if row and (row[5] or 0) > 0 then return row[5] end
    local _, q = itemInfo(id)
    return q
end

local function reqLevel(id)
    local row = Gear.Item(id)
    if row then return row[4] or 0 end
    local _, _, req = itemInfo(id)
    return req or 0
end

-- The source's drop chance as 0-1: "13.9%", "13,9 %" or a number.
local function chanceOf(rec)
    local v = rec and rec[1] == "D" and rec[4]
    if type(v) == "number" then return v > 1 and v / 100 or v end
    if type(v) == "string" then
        local n = tonumber((v:gsub(",", ".")):match("%d+%.?%d*"))
        if n then return n / 100 end
    end
    return nil
end

local function questDone(qid)
    local Q = _G.C_QuestLog
    local f = type(Q) == "table" and Q.IsQuestFlaggedCompleted
    if type(f) ~= "function" or type(qid) ~= "number" or qid <= 0 then return false end
    local ok, done = pcall(f, qid)
    return ok and ns.Plain(done) == true
end

local function questTitle(rec)
    local Q = _G.C_QuestLog
    local f = type(Q) == "table" and Q.GetTitleForQuestID
    if type(f) == "function" and (rec[7] or 0) > 0 then
        local ok, title = pcall(f, rec[7])
        title = ok and ns.Plain(title) or nil
        if type(title) == "string" and title ~= "" then return title end
    end
    return rec[2] or "?"
end

-- The name a dungeon shows: the client's (by area id) where known, else the fact's.
function D.Name(e)
    if type(e.area) == "number" and e.area > 0 and C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, e.area)
        name = ok and ns.Plain(name) or nil
        if type(name) == "string" and name ~= "" then return name end
    end
    return e.name or e.key
end

-- "13-18", "60", "~22" (estimated from the items).
function D.RangeText(e)
    if not e.min then return "" end
    local t = e.min == e.max and tostring(e.min) or (e.min .. "-" .. e.max)
    return e.est and ("~" .. t) or t
end

-- "passt", "bald", "leicht", "zu hoch", "ab 09.12." for a raid not yet open.
function D.FitText(e)
    if e.fit == "later" then
        local y, m, d = tostring(e.from or ""):match("^(%d+)%-(%d+)%-(%d+)$")
        return y and ("ab %s.%s."):format(d, m) or "später"
    end
    return FIT_TEXT[e.fit] or ""
end

-- The fit of a level to a range: "fit" inside, "soon" up to two levels below, "easy" above,
-- "high" further below.
function D.Fit(level, min, max)
    if level > max then return "easy" end
    if level >= min then return "fit" end
    if min - level <= SOON then return "soon" end
    return "high"
end

---------------------------------------------------------------------------
-- The index: dungeon -> bosses -> items, dungeon -> quests -> items (built once per data set)
---------------------------------------------------------------------------

local index, indexGear, indexFacts

local function addBoss(x, name, npc)
    name = name or "?"
    local l = lower(name)
    local b = x.byL[l]
    if not b then
        b = { name = name, lname = l, items = {}, ids = {} }
        x.byL[l] = b
        x.order[#x.order + 1] = b
    end
    if npc and not b.npc then b.npc = npc end
    return b
end

-- Adds key to the list at t[k] once.
local function addKey(t, k, key)
    local list = t[k]
    if not list then list = {}; t[k] = list end
    for _, v in ipairs(list) do
        if v == key then return end
    end
    list[#list + 1] = key
end

-- idx.byName: dungeon name or alias (lower case) -> key; idx.parts: the client's name of an instance
-- that hosts several dungeons (the facts' "part", lower case) -> their keys; idx.instKeys: instance
-- id -> the keys the facts give it (more than one where an instance hosts several dungeons).
local function buildIndex(facts)
    local idx = { byKey = {}, byName = {}, itemTo = {}, parts = {}, instKeys = {} }
    local instKeys = idx.instKeys
    for _, e in ipairs(facts) do
        if type(e) == "table" and type(e.key) == "string" then
            local x = { byL = {}, order = {}, quests = {} }
            idx.byKey[e.key] = x
            if e.name then idx.byName[lower(e.name)] = e.key end
            for _, a in ipairs(type(e.aliases) == "table" and e.aliases or {}) do
                local l = lower(a)
                if l and not idx.byName[l] then idx.byName[l] = e.key end
            end
            if type(e.part) == "string" then addKey(idx.parts, lower(e.part), e.key) end
            if type(e.inst) == "number" then addKey(instKeys, e.inst, e.key) end
            for _, b in ipairs(type(e.bosses) == "table" and e.bosses or {}) do
                if type(b) == "string" then addBoss(x, b) end
            end
        end
    end
    local d = ns.GEAR
    if not d then return idx end
    local srcTo = {}
    for n, rec in ipairs(d.S) do
        if rec[1] == "D" then
            local key = idx.byName[lower(rec[2])]
            local place = Gear.PlaceOf(rec)
            local inst = place and tonumber(place:match("^I:(%d+)$"))
            -- the instance decides only where it hosts one dungeon; else the source's own name
            if inst and instKeys[inst] and #instKeys[inst] == 1 then key = instKeys[inst][1] end
            if key then srcTo[n] = { key = key, boss = addBoss(idx.byKey[key], rec[3], D.BossNpc(rec)), rec = rec } end
        elseif rec[1] == "Q" and type(rec[9]) == "string" then
            local key = idx.byName[lower(rec[9])]
            if key then
                local q = { rec = rec, items = {} }
                local list = idx.byKey[key].quests
                list[#list + 1] = q
                srcTo[n] = { key = key, quest = q }
            end
        end
    end
    for id, row in pairs(d.I) do
        for i = Gear.FIRST_SOURCE, #row do
            local s = srcTo[row[i]]
            if s and s.boss then
                local b = s.boss
                if not b.items[id] then
                    b.items[id] = s.rec
                    b.ids[#b.ids + 1] = id
                end
                local x = idx.byKey[s.key]
                local lv = row[4] or 0
                if lv > 0 then
                    x.lo = math.min(x.lo or lv, lv)
                    x.hi = math.max(x.hi or lv, lv)
                end
                local to = idx.itemTo[id]
                if not to then to = {}; idx.itemTo[id] = to end
                to[s.key] = true
            elseif s and s.quest then
                local items = s.quest.items
                if items[#items] ~= id then items[#items + 1] = id end
            end
        end
    end
    for _, x in pairs(idx.byKey) do
        for _, b in ipairs(x.order) do table.sort(b.ids) end
        for _, q in ipairs(x.quests) do table.sort(q.items) end
    end
    return idx
end

local function getIndex(facts)
    if not index or indexGear ~= ns.GEAR or indexFacts ~= facts then
        index, indexGear, indexFacts = buildIndex(facts), ns.GEAR, facts
    end
    return index
end

---------------------------------------------------------------------------
-- Observations: which boss of which dungeon an NPC of the guild's records is
---------------------------------------------------------------------------

local dropsGen, questGen, namesGen = 0, 0, 0
ns.Listen("DROPS_CHANGED", function() dropsGen = dropsGen + 1 end)

local obs, obsGen, obsIndex, obsBase, obsNameless

-- Names arrive from other clients without a change of the records (and without DROPS_CHANGED), and
-- a name is only ever added where none was: the observations note the NPCs and instances they found
-- nameless, and a name among them since then makes them stale (namesGen goes up, which the result
-- caches key on). Cheap: only the nameless ones are looked at.
local function checkNames()
    if not obs or not obsNameless then return end
    local dd = ns.DropsDB and ns.DropsDB() or nil
    if not dd then return end
    for npc in pairs(obsNameless.npc) do
        if dd.npc[npc] ~= nil then
            obs, namesGen = nil, namesGen + 1
            return
        end
    end
    for inst in pairs(obsNameless.inst) do
        if dd.inst[inst] ~= nil then
            obs, namesGen = nil, namesGen + 1
            return
        end
    end
end

-- The key with the most votes (the smaller key on a tie).
local function winner(votes)
    local best, most
    for k, n in pairs(votes) do
        if not most or n > most or (n == most and k < best) then best, most = k, n end
    end
    return best
end

-- The one key with the most votes; nil on a tie at the top or without votes.
local function sole(votes)
    local best, most, tie
    for k, n in pairs(votes) do
        if not most or n > most then
            best, most, tie = k, n, false
        elseif n == most then
            tie = true
        end
    end
    if tie or not most or most <= 0 then return nil end
    return best
end

-- The dungeon among cands (the keys of one instance that hosts several) an NPC belongs to: the one
-- whose bosses carry its name, else the one whose items it dropped most; nil when that is not clear
-- - such an NPC stays unassigned rather than going to the first half.
local function pickPart(cands, name, items, idx)
    local l = lower(name)
    local hit, hits = nil, 0
    if l then
        for _, k in ipairs(cands) do
            local x = idx.byKey[k]
            if x and x.byL[l] then hit, hits = k, hits + 1 end
        end
    end
    if hits == 1 then return hit end
    local inCands, v = {}, {}
    for _, k in ipairs(cands) do inCands[k] = true end
    for id in pairs(items) do
        for k in pairs(idx.itemTo[id] or {}) do
            if inCands[k] then v[k] = (v[k] or 0) + 1 end
        end
    end
    return sole(v)
end

-- dungeon key -> list of { npc, name, items = set, lname of the boss it is (or nil: a boss of its
-- own), kills (records), known (a boss of the facts or the base stock) }: the NPCs of the build's
-- facts, of the base stock (ns.BIS.O) and of the records. An NPC belongs to the dungeon the facts give
-- it, else to the instance most of its records are from, else to the dungeon whose items it dropped.
-- The dungeons of an instance: the facts' (several where one instance hosts several, as the two
-- halves of Blackrock Spire), else those whose client name is the instance's "part", else the one
-- whose name it is, else the one whose records hold the dungeon's items. In an instance of several
-- dungeons an NPC goes to the one whose data lists it (pickPart), else nowhere.
local function observations(facts, idx)
    local B = ns.BIS
    local base = type(B) == "table" and type(B.O) == "table" and B.O or nil
    if obs and obsGen == dropsGen and obsIndex == idx and obsBase == base then return obs end
    local dd = ns.DropsDB and ns.DropsDB() or nil
    local records = dd and dd.k or {}
    local nameless = { npc = {}, inst = {} }
    local npcs = {}
    local function npcOf(npc)
        local o = npcs[npc]
        if not o then o = { npc = npc, items = {}, insts = {}, kills = 0 }; npcs[npc] = o end
        return o
    end
    local npcKey = {}
    for _, e in ipairs(facts) do
        for _, b in ipairs(type(e.bosses) == "table" and e.bosses or {}) do
            if type(b) == "number" then npcKey[b] = e.key; npcOf(b) end
        end
    end
    for npc, e in pairs(base or {}) do
        if type(npc) == "number" and type(e) == "table" and type(e.it) == "table" then
            local o = npcOf(npc)
            o.known = true
            for id in pairs(e.it) do o.items[id] = true end
        end
    end
    local instKeys, votes = {}, {}
    for inst, list in pairs(idx.instKeys) do instKeys[inst] = list end
    for _, r in pairs(records) do
        if r.npc > 0 then
            local o = npcOf(r.npc)
            for id in pairs(r.it) do o.items[id] = true end
            o.insts[r.inst] = (o.insts[r.inst] or 0) + 1
            o.kills = o.kills + 1
        end
        if not instKeys[r.inst] then
            local z = dd.inst[r.inst]
            local zl = z and lower(z[2])
            if zl and idx.parts[zl] then
                instKeys[r.inst] = idx.parts[zl]
            elseif zl and idx.byName[zl] then
                instKeys[r.inst] = { idx.byName[zl] }
            else
                if not z then nameless.inst[r.inst] = true end
                local v = votes[r.inst]
                if not v then v = {}; votes[r.inst] = v end
                for id in pairs(r.it) do
                    for key in pairs(idx.itemTo[id] or {}) do v[key] = (v[key] or 0) + 1 end
                end
            end
        end
    end
    for inst, v in pairs(votes) do
        local w = not instKeys[inst] and winner(v)
        if w then instKeys[inst] = { w } end
    end
    local out = {}
    for npc, o in pairs(npcs) do
        local name = dd and dd.npc[npc]
        if dd and name == nil then nameless.npc[npc] = true end
        local key, cands = npcKey[npc], nil
        if not key then
            local inst = winner(o.insts)
            cands = inst and instKeys[inst]
            if cands and #cands == 1 then
                key = cands[1]
            elseif cands then
                key = pickPart(cands, name, o.items, idx)
            end
        end
        if not key and not cands then
            local v = {}
            for id in pairs(o.items) do
                for k in pairs(idx.itemTo[id] or {}) do v[k] = (v[k] or 0) + 1 end
            end
            key = winner(v)
        end
        local x = key and idx.byKey[key]
        if x then
            -- the boss of the item data: the same NPC, the same name, else the most shared items
            local lname
            for _, b in ipairs(x.order) do
                if b.npc == npc then lname = b.lname break end
            end
            if not lname and name and x.byL[lower(name)] then lname = lower(name) end
            if not lname then
                local most = 0
                for _, b in ipairs(x.order) do
                    local n = 0
                    for id in pairs(o.items) do if b.items[id] then n = n + 1 end end
                    if n > most then lname, most = b.lname, n end
                end
            end
            local list = out[key]
            if not list then list = {}; out[key] = list end
            list[#list + 1] = { npc = npc, name = name or ("Boss " .. npc), items = o.items, lname = lname, kills = o.kills,
                known = npcKey[npc] ~= nil or o.known or false }
        end
    end
    for _, list in pairs(out) do
        table.sort(list, function(a, b) return a.npc < b.npc end)
    end
    obs, obsGen, obsIndex, obsBase, obsNameless = out, dropsGen, idx, base, nameless
    return out
end

---------------------------------------------------------------------------
-- The value of one dungeon
---------------------------------------------------------------------------

-- The bosses of a dungeon: the item data's (with their source records), the observed NPCs joined
-- to them or standing on their own, each with the items seen only by the guild. One standing on its
-- own that no facts or base stock name as a boss is tentative below MIN_KILLS kills: listed, not
-- counted.
local function bossesOf(key, x, seen)
    local out, byL = {}, {}
    for _, b in ipairs(x.order) do
        local nb = { name = b.name, lname = b.lname, npc = b.npc, src = b, extra = {} }
        out[#out + 1] = nb
        byL[b.lname] = nb
    end
    for _, link in ipairs(seen[key] or {}) do
        local nb = link.lname and byL[link.lname]
        if not nb then
            nb = { name = link.name, lname = lower(link.name), src = { items = {}, ids = {} }, extra = {}, kills = link.kills,
                tentative = not link.known and (link.kills or 0) < MIN_KILLS }
            out[#out + 1] = nb
        end
        nb.npc = nb.npc or link.npc
        for id in pairs(link.items) do
            if not nb.src.items[id] then nb.extra[id] = true end
        end
    end
    return out
end

local ALL_SOURCES = { X = true, D = true, Q = true }

-- Fills an entry's value: bosses with their upgrades and wishes, quests, upgrades, perRun, once,
-- value. limit is the highest required level that counts.
local function compute(entry, e, x, seen, o, gains, limit)
    local raid = e.kind == "raid"
    local c = ns.BisChar()
    local ex = o.exclude or {}
    local exItem, exBoss, exPlace = ex.item or {}, ex.boss or {}, ex.place or {}
    local placeOff = exPlace["N:" .. tostring(e.name)] or (e.inst and exPlace["I:" .. e.inst]) or false
    local po = {}
    for k, v in pairs(o) do po[k] = v end
    po.sources = ALL_SOURCES

    local function gainOf(id)
        local g = gains[id]
        if g == nil then
            local gain, slotKey, mine = D.Gain(id, o)
            g = type(gain) == "number" and { gain, slotKey, mine } or false
            gains[id] = g
        end
        return g or nil
    end

    local upgrades, perRun, once, questUps = 0, 0, 0, 0
    local counted = {}
    local bosses = {}
    for _, b in ipairs(bossesOf(e.key, x, seen)) do
        if not exBoss[b.name] then
            local all = {}
            for _, id in ipairs(b.src.ids) do all[#all + 1] = { id, b.src.items[id] } end
            local extra = {}
            for id in pairs(b.extra) do extra[#extra + 1] = id end
            table.sort(extra)
            for _, id in ipairs(extra) do all[#all + 1] = { id } end
            -- every known item of the boss counts for the share of its quality
            local byQ = {}
            for _, a in ipairs(all) do
                local q = quality(a[1]) or 0
                byQ[q] = (byQ[q] or 0) + 1
            end
            local ob = { name = b.name, npc = b.npc, items = {}, perRun = 0, kills = b.kills, tentative = b.tentative or nil }
            for _, a in ipairs(all) do
                local id, rec = a[1], a[2]
                local ok = not exItem[id] and reqLevel(id) <= limit
                if ok and rec then ok = Gear.SourceOk(rec, po, Gear.Item(id)) elseif ok then ok = not placeOff end
                local g = ok and gainOf(id)
                if g then
                    local gain, slotKey, mine = g[1], g[2], g[3]
                    local owned = ns.BisOwned(id)
                    local wished = c and c.wish[id] ~= nil or false
                    -- an owned upgrade is listed (with its mark) but not counted
                    local better = ns.BisIsUpgrade(gain, mine)
                    local up = better and not owned or false
                    if better or wished then
                        local p0, est = chanceOf(rec), false
                        if not p0 then
                            local q = quality(id) or 0
                            p0 = math.min(PRIOR_MAX, 1 / math.max(byQ[q] or 1, PRIOR_TABLE[q] or PRIOR_DEFAULT))
                            est = true
                        end
                        local p, rate, n, K = D.Rate(ob, id, p0, raid, est)
                        ob.items[#ob.items + 1] = { id = id, gain = gain, slotKey = slotKey, mine = mine, p = p, rate = rate, n = n, K = K,
                            owned = owned, wished = wished, upgrade = up, rec = rec }
                        if up and not ob.tentative then
                            ob.perRun = ob.perRun + gain * (p or 0)
                            if not counted[id] then counted[id] = true; upgrades = upgrades + 1 end
                        end
                    end
                end
            end
            if #ob.items > 0 then
                table.sort(ob.items, function(p, q)
                    if p.upgrade ~= q.upgrade then return p.upgrade end
                    if p.gain ~= q.gain then return p.gain > q.gain end
                    return p.id < q.id
                end)
                perRun = perRun + ob.perRun
                bosses[#bosses + 1] = ob
            end
        end
    end

    local quests = {}
    for _, q in ipairs(x.quests) do
        local rec = q.rec
        if Gear.SourceOk(rec, po) then
            local best
            for _, id in ipairs(q.items) do
                if not exItem[id] and reqLevel(id) <= limit then
                    local g = gainOf(id)
                    if g and not ns.BisOwned(id) and ns.BisIsUpgrade(g[1], g[3]) and (not best or g[1] > best.gain) then
                        best = { id = id, gain = g[1], slotKey = g[2] }
                    end
                end
            end
            local done = questDone(rec[7])
            quests[#quests + 1] = { qid = rec[7], title = questTitle(rec), level = rec[4], best = best, done = done, rec = rec }
            if best and not done then
                once = once + best.gain
                questUps = questUps + 1
            end
        end
    end
    table.sort(quests, function(a, b)
        if a.done ~= b.done then return not a.done end
        local ga, gb = a.best and a.best.gain or -1, b.best and b.best.gain or -1
        if ga ~= gb then return ga > gb end
        if a.title ~= b.title then return a.title < b.title end
        return (a.qid or 0) < (b.qid or 0)
    end)

    entry.bosses, entry.quests = bosses, quests
    entry.upgrades, entry.perRun, entry.once, entry.questUps = upgrades, perRun, once, questUps
    entry.value = once + RUNS * perRun
    entry.computed = true
end

---------------------------------------------------------------------------
-- The list, the next dungeon, one dungeon
---------------------------------------------------------------------------

local function today()
    return ns.DropsToday and ns.DropsToday() or nil
end

-- The entry of a fact without values: nil when it has no level range (neither a fact nor items),
-- unless anyRange (then min and max stay nil and the fit is "unknown").
local function baseEntry(e, x, o, anyRange)
    local raid = e.kind == "raid"
    local min, max, est = e.min, e.max, false
    if raid then
        local cap = Gear.Cap()
        min, max = min or cap, max or cap
    elseif not (min and max) then
        if x and x.lo then
            min, max, est = x.lo, x.hi, true
        elseif anyRange then
            min, max = nil, nil
        else
            return nil
        end
    end
    local entry = { key = e.key, name = D.Name(e), kind = raid and "raid" or "party", size = e.size, min = min, max = max,
        est = est, from = e.from, inst = e.inst, fact = e, bosses = {}, quests = {} }
    entry.fit = min and D.Fit(o.level, min, max) or "unknown"
    if raid and type(e.from) == "string" and ns.DropsDay then
        local open, now = ns.DropsDay(e.from), today()
        if open and now and now < open then entry.fit = "later" end
    end
    return entry
end

local function stateKey(o, facts, opts)
    checkNames()
    return table.concat({ tostring(ns.GEAR), tostring(facts), ns.BisStamp(), dropsGen, questGen, namesGen, tostring(o.class), tostring(o.spec),
        tostring(o.kind), tostring(o.level), tostring(o.faction), opts and tostring(opts) or "" }, "|")
end

local listKey, listRes, nextKey, nextRes, nextWhy
local infoKey, infoRes = nil, {}

-- Every dungeon (and from the level cap every raid) with a level range, by level:
-- { key, name, kind, size, min, max, est, from, fit, value, once, perRun, upgrades, questUps,
--   bosses = { { npc, name, perRun, items = { { id, gain, slotKey, p, rate, n, K, owned, wished,
--   upgrade, rec } } } }, quests = { { qid, title, level, best = { id, gain, slotKey }, done } },
--   computed }. Dungeons further than two levels away keep their values nil (ns.DungeonInfo gives
-- them). Kept until anything it depends on changes; callers must not change it.
function ns.DungeonList(opts)
    local facts = D.Facts()
    if not facts or not Gear.Available() then return {} end
    local o = opts or D.Opts()
    if not o or not o.class then return {} end
    local key = stateKey(o, facts, opts)
    if key == listKey then return listRes end
    local idx = getIndex(facts)
    local seen = observations(facts, idx)
    local gains = {}
    local cap = Gear.Cap()
    local list = {}
    for _, e in ipairs(facts) do
        if type(e) == "table" and type(e.key) == "string" and (e.kind ~= "raid" or o.level >= cap) then
            local x = idx.byKey[e.key]
            local entry = baseEntry(e, x, o)
            if entry then
                if entry.fit ~= "high" then compute(entry, e, x, seen, o, gains, o.level + SOON) end
                list[#list + 1] = entry
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.kind == "raid") ~= (b.kind == "raid") then return b.kind == "raid" end
        if a.min ~= b.min then return a.min < b.min end
        if a.max ~= b.max then return a.max < b.max end
        return a.name < b.name
    end)
    listKey, listRes = key, list
    return list
end

-- The reason of a recommendation without the name: "4 Upgrades, 2 Quests mit Upgrades,
-- Schwerpunkt <boss>".
local function whyOf(e)
    local parts = {}
    if e.upgrades > 0 then parts[#parts + 1] = e.upgrades == 1 and "1 Upgrade" or (e.upgrades .. " Upgrades") end
    if e.questUps > 0 then
        parts[#parts + 1] = e.questUps == 1 and "1 Quest mit Upgrade" or (e.questUps .. " Quests mit Upgrades")
    end
    -- the focus is a boss: the item data's trash group of a dungeon is none
    local focus
    for _, b in ipairs(e.bosses) do
        if b.perRun > 0 and b.name ~= "Trash" and (not focus or b.perRun > focus.perRun) then focus = b end
    end
    if focus then parts[#parts + 1] = "Schwerpunkt " .. focus.name end
    return table.concat(parts, ", ")
end

-- The next dungeon: the highest value among the fitting ones and those two levels ahead; entry and
-- reason ("Hall of Thanes: 4 Upgrades, 2 Quests mit Upgrades, Schwerpunkt <boss>"), or nil and
-- why not. The entry carries the reason without its name as entry.why.
function ns.DungeonNext(opts)
    if not D.Facts() then return nil, NO_DATA end
    local list = ns.DungeonList(opts)
    if list == nextKey then return nextRes, nextWhy end
    local best
    for _, e in ipairs(list) do
        if FIT_ORDER[e.fit] and e.computed and e.value > 0 and (e.upgrades > 0 or e.questUps > 0) then
            if not best or e.value > best.value or (e.value == best.value and e.min < best.min) then best = e end
        end
    end
    if best then
        best.why = whyOf(best)
        nextRes, nextWhy = best, best.name .. ": " .. best.why
    else
        nextRes, nextWhy = nil, NO_HIT
    end
    nextKey = list
    return nextRes, nextWhy
end

-- One dungeon or raid by key, with its values even out of reach (items up to its upper end); one
-- without a level range has min and max nil and the fit "unknown". nil for an unknown key.
function ns.DungeonInfo(dkey, opts)
    local facts = D.Facts()
    if not facts or not Gear.Available() then return nil end
    for _, e in ipairs(ns.DungeonList(opts)) do
        if e.key == dkey and e.computed then return e end
    end
    local o = opts or D.Opts()
    if not o or not o.class then return nil end
    local key = stateKey(o, facts, opts)
    if key ~= infoKey then infoKey, infoRes = key, {} end
    if infoRes[dkey] ~= nil then return infoRes[dkey] or nil end
    local idx = getIndex(facts)
    local found
    for _, e in ipairs(facts) do
        if type(e) == "table" and e.key == dkey then
            local x = idx.byKey[e.key]
            found = baseEntry(e, x, o, true)
            compute(found, e, x, observations(facts, idx), o, {}, math.max(o.level + SOON, found.max or 0))
            break
        end
    end
    infoRes[dkey] = found or false
    return found
end

---------------------------------------------------------------------------
-- The entrance
---------------------------------------------------------------------------

local function factOf(key)
    for _, e in ipairs(D.Facts() or {}) do
        if type(e) == "table" and e.key == key then return e end
    end
    return nil
end

-- The nearest entrance of a dungeon as the map data knows it: point, map key; nil without one.
function ns.DungeonEntrance(key)
    local e = factOf(key)
    if not e or not ns.MAP or not ns.MapPoints then return nil end
    local keys = {}
    if type(e.inst) == "number" then keys[#keys + 1] = "I:" .. e.inst end
    if e.name then keys[#keys + 1] = "N:" .. e.name end
    for _, a in ipairs(type(e.aliases) == "table" and e.aliases or {}) do keys[#keys + 1] = "N:" .. a end
    for _, k in ipairs(keys) do
        local points = ns.MapPoints(k)
        if #points > 0 then return ns.MapNearest(points), k end
    end
    return nil
end

-- Sets the map target (and the client's waypoint) to a dungeon's entrance; true, or nil and why.
function ns.DungeonWaypoint(key)
    if not ns.MAP then return nil, NO_MAP end
    local e = factOf(key)
    if not e then return nil, NO_DATA end
    local point, mapKey = ns.DungeonEntrance(key)
    if not point then return nil, NO_ENTRANCE end
    return ns.MapSetPoint(point, D.Name(e) .. " (Eingang)", mapKey)
end

---------------------------------------------------------------------------
-- What changes a result, the command
---------------------------------------------------------------------------

ns.OnEvent("QUEST_TURNED_IN", function() questGen = questGen + 1 end)

ns.RegisterSlash("dungeon", { aliases = { "dungeons" }, args = "[naechster]", desc = "Dungeon-Planer: welcher Dungeon sich für dich lohnt",
    run = function(rest)
        local word = ((rest or ""):match("^(%S*)") or ""):lower()
        if word == "naechster" or word == "nächster" or word == "next" then
            local ok, e, why = pcall(ns.DungeonNext)
            if not ok then
                report(e)
                return
            end
            if e then ns.msg(("Nächster Dungeon (%s): %s"):format(D.RangeText(e), why)) else ns.msg(why) end
            return
        elseif word ~= "" then
            ns.msg("Aufruf: /amisia dungeon [naechster]")
            return
        end
        if not Gear.Available() then
            ns.msg("Für diesen Client gibt es keine Ausrüstungsdaten.")
            return
        end
        ns.ShowGear("dungeons")
    end })
