-- Profession trainers read in the game (F-155, D-86, spec docs/specs/2026-11-08-lehrer-lesen.md): when
-- the player opens a trainer (of a profession or a class), Amisia reads quietly every offer that is a
-- recipe of the profession data: the skill it needs, its price and the level, with the trainer (NPC id,
-- the client's name, where the player stood). The trainer window's filters are set to show everything
-- for the read and set back at once. Nothing is learned, bought or sent.
--
-- AmisiaDB.trainers = { [npc] = { t = time(), n = "Name", p = "map:x:y", s = { [spell] = "rank:copper:level" } } }
-- tools/build_professions.py joins it into tools/trainer_archive.json and the profession data (learn
-- rank, the trainer token N<npc>, L the learning costs, TD the readings it holds); a reading the data
-- holds is dropped here once the data is in use (no load at login, D-28).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local Pr = ns.Prof

local Tr = {}
ns.ProfTrainers = Tr

Tr.MAX_TRAINERS = 300
Tr.MAX_OFFERS = 400
local FILTERS = { "available", "unavailable", "used" }
local READ_DELAY, RETRY_DELAY = 0.2, 1.0

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end
local function int(v, lo, hi)
    v = tonumber(ns.Plain(v))
    if not v or v ~= math.floor(v) or v < lo or v > hi then return nil end
    return v
end
local function cleanText(v, max)
    v = ns.Plain(v)
    return type(v) == "string" and v ~= "" and #v <= max and not v:find("|", 1, true) and v or nil
end

local function store(create)
    if type(AmisiaDB) ~= "table" then return nil end
    if create and type(AmisiaDB.trainers) ~= "table" then AmisiaDB.trainers = {} end
    return type(AmisiaDB.trainers) == "table" and AmisiaDB.trainers or nil
end

---------------------------------------------------------------------------
-- The readings by recipe
---------------------------------------------------------------------------
local index          -- [spell] = { rank, cost, level, npc, name, pos, t } the newest reading
local indexData      -- the data the index was trimmed against

-- Drops the readings the profession data already holds (TD: [npc] = the reading's time it took).
local function trimArchived(d)
    local s = store(false)
    local done = type(d) == "table" and d.TD
    if not s or type(done) ~= "table" then return end
    for npc, e in pairs(s) do
        local t = tonumber(done[npc])
        if t and type(e) == "table" and (tonumber(e.t) or 0) <= t then s[npc] = nil end
    end
end

local function build()
    local d = ns.DataLoaded("PROFESSIONS") and ns.Data("PROFESSIONS") or nil
    if d ~= indexData then
        trimArchived(d)
        indexData = d
    end
    index = {}
    for npc, e in pairs(store(false) or {}) do
        if type(e) == "table" and type(e.s) == "table" then
            local t = tonumber(e.t) or 0
            for spell, v in pairs(e.s) do
                local rank, cost, level = tostring(v):match("^(%d+):(%d+):(%d+)$")
                local have = index[spell]
                if rank and (not have or t > have.t) then
                    index[spell] = { rank = tonumber(rank), cost = tonumber(cost), level = tonumber(level), npc = npc,
                        name = e.n, pos = e.p, t = t }
                end
            end
        end
    end
end

-- The newest own reading of a recipe: { rank, cost, level, npc, name, pos, t }, or nil.
function Tr.Of(spell)
    if not index or (ns.DataLoaded("PROFESSIONS") and ns.Data("PROFESSIONS") ~= indexData) then build() end
    return index[tonumber(spell)]
end

-- How many trainers and offers the own readings hold (those not yet in the data).
function Tr.Counts()
    local t, o = 0, 0
    for _, e in pairs(store(false) or {}) do
        if type(e) == "table" then
            t = t + 1
            for _ in pairs(type(e.s) == "table" and e.s or {}) do o = o + 1 end
        end
    end
    return t, o
end

function Tr._reset() index, indexData = nil, nil end

---------------------------------------------------------------------------
-- Reading a trainer
---------------------------------------------------------------------------
-- The recipes of the data by the item they make and by the client's spell name, built when a trainer
-- is read (never at login).
local byItem, byName, matchData
local function matchIndex()
    local d = ns.Data("PROFESSIONS")
    if byItem and matchData == d then return end
    byItem, byName, matchData = {}, {}, d
    for _, skill in ipairs(Pr.Skills()) do
        for _, r in ipairs(Pr.Recipes(skill)) do
            if r.item > 0 then
                byItem[r.item] = byItem[r.item] or {}
                table.insert(byItem[r.item], r)
            end
            local name = Pr.SpellName(r.spell)
            if name then
                byName[name] = byName[name] or {}
                table.insert(byName[name], r)
            end
        end
    end
end

-- The recipe of offer i: by the item it makes (one recipe, else the one of that name), else by name
-- when exactly one recipe has it; nil otherwise.
local function recipeOf(i, name)
    local item = ns.ItemID(ns.Plain(call(GetTrainerServiceItemLink, i)) or "")
    local list = item and byItem[item]
    if list and #list == 1 then return list[1] end
    local named = name and byName[name]
    if list and named then
        for _, r in ipairs(list) do
            for _, x in ipairs(named) do if x == r then return r end end
        end
        return nil
    end
    if named and #named == 1 then return named[1] end
    return nil
end

-- Where the player stands (the trainer's place, near enough): "map:x:y", or nil.
local function here()
    local map = int((call(C_Map and C_Map.GetBestMapForUnit, "player")), 1, 999999)
    if not map then return nil end
    local pos = call(C_Map.GetPlayerMapPosition, map, "player")
    if type(pos) ~= "table" then return nil end
    local x, y
    if type(pos.GetXY) == "function" then x, y = call(pos.GetXY, pos) else x, y = pos.x, pos.y end
    x, y = tonumber(ns.Plain(x)), tonumber(ns.Plain(y))
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return nil end
    return ("%d:%d:%d"):format(map, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5))
end

-- Keeps the newest MAX_TRAINERS trainers.
local function cap(s)
    local list = {}
    for npc, e in pairs(s) do list[#list + 1] = { npc = npc, t = type(e) == "table" and tonumber(e.t) or 0 } end
    if #list <= Tr.MAX_TRAINERS then return end
    table.sort(list, function(a, b) return a.t > b.t end)
    for i = Tr.MAX_TRAINERS + 1, #list do s[list[i].npc] = nil end
end

-- Reads the open trainer; returns how many offers it took (nil when it read nothing at all).
function Tr.Read()
    if InCombatLockdown and InCombatLockdown() then return nil end
    if not Pr.Available() or type(GetNumTrainerServices) ~= "function" then return nil end
    local npc = ns.NpcID(ns.Plain(UnitGUID and UnitGUID("npc")))
    if not npc then return nil end
    -- every offer: the filters on for the read, then as they were
    local changed = {}
    if type(GetTrainerServiceTypeFilter) == "function" and type(SetTrainerServiceTypeFilter) == "function" then
        for _, k in ipairs(FILTERS) do
            local on = call(GetTrainerServiceTypeFilter, k)
            if not on or on == 0 then
                call(SetTrainerServiceTypeFilter, k, 1)
                changed[#changed + 1] = k
            end
        end
    end
    local count = int(call(GetNumTrainerServices), 0, 2000) or 0
    local offers, n = {}, 0
    if count > 0 then matchIndex() end
    for i = 1, count do
        local name, _, category = call(GetTrainerServiceInfo, i)
        name = cleanText(name, 120)
        if name and ns.Plain(category) ~= "header" and n < Tr.MAX_OFFERS then
            local r = recipeOf(i, name)
            if r then
                local _, rank = call(GetTrainerServiceSkillReq, i)
                offers[r.spell] = ("%d:%d:%d"):format(int(rank, 0, 1000) or 0, int((call(GetTrainerServiceCost, i)), 0, 1e9) or 0,
                    int((call(GetTrainerServiceLevelReq, i)), 0, 200) or 0)
                n = n + 1
            end
        end
    end
    for _, k in ipairs(changed) do call(SetTrainerServiceTypeFilter, k, 0) end
    if count == 0 then return nil end
    if n == 0 then return 0 end
    local s = store(true)
    if not s then return 0 end
    -- an earlier reading's offers this one did not see stay (a read without the filter functions sees less)
    local old = type(s[npc]) == "table" and type(s[npc].s) == "table" and s[npc].s or {}
    for spell, v in pairs(old) do
        if offers[spell] == nil and n < Tr.MAX_OFFERS then
            offers[spell] = v
            n = n + 1
        end
    end
    s[npc] = { t = math.floor(time()), n = cleanText(UnitName and UnitName("npc"), 60), p = here(), s = offers }
    cap(s)
    index = nil
    ns.Fire("PROF_CHANGED")
    return n
end

local pending
local function readLater()
    if pending then return end
    pending = true
    C_Timer.After(READ_DELAY, function()
        pending = false
        -- the offers may come a moment after the window: once more after a second
        if Tr.Read() == nil then C_Timer.After(RETRY_DELAY, function() Tr.Read() end) end
    end)
end
ns.OnEvent("TRAINER_SHOW", readLater)

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
-- Called on ADDON_LOADED: AmisiaDB.trainers checked field by field (NPC ids, time, name and place
-- without codes, offers "rank:copper:level" of positive spell ids, at most MAX_OFFERS each, the newest
-- MAX_TRAINERS trainers).
function ns.TrainersLoaded(root)
    if type(root) ~= "table" or root.trainers == nil then return end
    if type(root.trainers) ~= "table" then
        root.trainers = nil
        return
    end
    local out = {}
    for npc, e in pairs(root.trainers) do
        if int(npc, 1, 9999999) and type(e) == "table" and int(e.t, 1, 4e9) and type(e.s) == "table" then
            local offers, n = {}, 0
            for spell, v in pairs(e.s) do
                if n < Tr.MAX_OFFERS and int(spell, 1, 99999999) and type(v) == "string" and #v <= 30
                    and v:match("^%d+:%d+:%d+$") then
                    offers[spell] = v
                    n = n + 1
                end
            end
            local p = type(e.p) == "string" and e.p:match("^%d+:%d+:%d+$") and e.p or nil
            if n > 0 then out[npc] = { t = e.t, n = cleanText(e.n, 60), p = p, s = offers } end
        end
    end
    root.trainers = out
    cap(out)
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then ns.TrainersLoaded(AmisiaDB) end
end)

ns.RegisterSlash("lehrer", { en = "trainers", desc = L["Stand der gelesenen Berufslehrer"], run = function()
    local t, o = Tr.Counts()
    ns.msg(L["Lehrer: %d gelesen, %d Angebote (noch nicht in den Daten)."]:format(t, o))
end })
end)
