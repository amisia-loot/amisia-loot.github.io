-- Amisia award history: who got an item and what a player got, read from the living awards of the
-- saved raids (s.awards; a deleted or undone award lies in s.gone and never counts).
--
-- One index, built on the first question and dropped on every change of the book (DATA_CHANGED,
-- which every award change fires, the sync's snapshots too), of the alts (ALTS) and of the raid
-- list itself (a deleted raid gives a new list): item id -> awards newest first, and player (lower
-- main) -> awards to a player newest first. A tooltip never walks the raids.
--
-- The item tooltip (awards.tooltip): "Vergeben: Fraktur (MS), 09.09.", at most three, newest first,
-- "+N weitere" for the rest; bank and disenchant as such. Shown to everyone: who got an item is said
-- in the raid chat and a raider sees every award of the synced raid on the page Vergaben. The
-- per-player numbers (the roll window) stay with the officers, as on the page Statistik.
local ADDON, ns = ...
local L = ns.L

local DAY = 86400
local TIP_MAX = 3
local TO_TEXT = { bank = "Bank", de = L["Entzaubern"] }

local index   -- { src = the raid list it was built from, n = its length, items = {}, players = {} }

local function playerAward(a)
    return (a.to == nil or a.to == "player") and type(a.name) == "string" and a.name ~= "-" and ns.FullName(a.name) ~= nil
end

local function newestFirst(x, y)
    if x.t ~= y.t then return x.t > y.t end
    return x.n > y.n
end

local function build()
    local src = ns.Sessions()
    local idx = { src = src, n = #src, items = {}, players = {} }
    local n = 0
    for _, s in ipairs(src) do
        for _, a in ipairs(type(s) == "table" and type(s.awards) == "table" and s.awards or {}) do
            local item = type(a) == "table" and tonumber(a.item)
            if item then
                n = n + 1
                local e = { item = item, name = a.name, kind = a.kind, to = a.to or "player", t = tonumber(a.t) or s.start or 0, n = n }
                local list = idx.items[item]
                if not list then
                    list = {}
                    idx.items[item] = list
                end
                list[#list + 1] = e
                if playerAward(a) then
                    local key = tostring(ns.MainOf(a.name) or a.name):lower()
                    local pl = idx.players[key]
                    if not pl then
                        pl = { name = a.name, list = {} }
                        idx.players[key] = pl
                    end
                    pl.list[#pl.list + 1] = e
                end
            end
        end
    end
    for _, list in pairs(idx.items) do table.sort(list, newestFirst) end
    for _, pl in pairs(idx.players) do table.sort(pl.list, newestFirst) end
    return idx
end

local function current()
    local src = ns.Sessions()
    if not index or index.src ~= src or index.n ~= #src then index = build() end
    return index
end

local function drop() index = nil end
ns.Listen("DATA_CHANGED", drop)
ns.Listen("ALTS", drop)
ns.Listen("RECORDING", drop)

-- For tests: whether the index is built right now.
function ns.AwardHistoryBuilt() return index ~= nil end

-- The living awards of an item, newest first: { { item, name, kind, to, t } } (a shared list:
-- read only).
function ns.AwardsOfItem(id)
    id = tonumber(id)
    return id and current().items[id] or {}
end

-- Who an award went to: the bank, disenchant, or the name (an alt with its main) and the kind.
local function who(e)
    if TO_TEXT[e.to] then return TO_TEXT[e.to] end
    local parts = {}
    local main = ns.AltMain(e.name)
    if main then parts[#parts + 1] = L["Twink von %s"]:format(main) end
    if e.kind == "MS" or e.kind == "OS" or e.kind == "SR" then parts[#parts + 1] = e.kind end
    if #parts == 0 then return e.name end
    return ("%s (%s)"):format(e.name, table.concat(parts, ", "))
end

-- The tooltip lines of an item: "Vergeben: Fraktur (MS), 09.09." then the next two, and
-- "+N weitere"; an empty list when it was never given out.
function ns.AwardTooltipLines(id)
    local list, out = ns.AwardsOfItem(id), {}
    for i = 1, math.min(#list, TIP_MAX) do
        local e = list[i]
        out[#out + 1] = L["Vergeben: %s, %s"]:format(who(e), ns.FmtDay(e.t))
    end
    if #list > TIP_MAX then out[#out + 1] = L["+%d weitere"]:format(#list - TIP_MAX) end
    return out
end

ns.OnItemTooltip("awards", function(tip, _, id)
    if not ns.Get("awards.tooltip") then return false end
    local lines = ns.AwardTooltipLines(id)
    if #lines == 0 then return false end
    for i, text in ipairs(lines) do
        if i > TIP_MAX then
            tip:AddLine(text, 0.56, 0.53, 0.64)
        else
            tip:AddLine(text, 0.6, 0.8, 1)
        end
    end
    return true
end)

-- What a player got (every character of the player, as on the page Statistik): { n, ms, os, sr,
-- days, last = newest award ever or nil }; n and the split count the last days (default the range
-- "letzte 4 Wochen" of the statistics).
function ns.AwardHistoryOf(name, days, now)
    days = days or ns.STATS_RANGE_DAYS or 28
    now = now or time()
    local res = { n = 0, ms = 0, os = 0, sr = 0, days = days }
    name = ns.FullName(ns.Plain(name))
    if not name then return res end
    local players = current().players
    local pl = players[tostring(ns.MainOf(name) or name):lower()]
    if not pl then
        -- another spelling of the same character (with or without the surname)
        for _, o in pairs(players) do
            if ns.SameMain(o.name, name) then pl = o break end
        end
    end
    if not pl then return res end
    res.last = pl.list[1]
    local from = now - days * DAY
    for _, e in ipairs(pl.list) do
        if e.t < from then break end
        res.n = res.n + 1
        if e.kind == "MS" then res.ms = res.ms + 1 elseif e.kind == "OS" then res.os = res.os + 1 elseif e.kind == "SR" then res.sr = res.sr + 1 end
    end
    return res
end

-- The lines for a roller in the roll window: "Letzte 4 Wochen: 3 Items (2 MS, 1 OS)" or
-- "Letzte 4 Wochen: nichts bekommen", then "Zuletzt: <Item>, 09.09." when there is a last item.
function ns.AwardHistoryLines(name, now)
    local h = ns.AwardHistoryOf(name, nil, now)
    local out = {}
    if h.n == 0 then
        out[1] = L["Letzte 4 Wochen: nichts bekommen"]
    else
        local split = {}
        if h.ms > 0 then split[#split + 1] = h.ms .. " MS" end
        if h.os > 0 then split[#split + 1] = h.os .. " OS" end
        if h.sr > 0 then split[#split + 1] = h.sr .. " SR" end
        local count = h.n == 1 and L["1 Item"] or L["%d Items"]:format(h.n)
        if #split > 0 then count = ("%s (%s)"):format(count, table.concat(split, ", ")) end
        out[1] = L["Letzte 4 Wochen: %s"]:format(count)
    end
    if h.last then
        out[#out + 1] = L["Zuletzt: %s, %s"]:format(ns.ItemName(h.last.item), ns.FmtDay(h.last.t))
    end
    return out
end
