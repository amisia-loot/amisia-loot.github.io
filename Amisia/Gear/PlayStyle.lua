-- Amisia play styles (F-124, D-56): which sources of the own targets fit the way a player plays.
-- Five switches on top of the source chips, any number at once (a source must pass all of them):
--   nodungeon  no dungeon or raid loot, no quest that leads into a dungeon
--   solo       as nodungeon; rare mobs up to the own level + 1; no quest the data or the quest log
--              knows as a group quest
--   buy        vendors and the auction house, plus every item that does not bind on pickup (it can be
--              bought from other players: the source "Auktionshaus (bindet beim Anlegen)")
--   now        the reputation an item asks for is reached; a crafted item that binds on pickup only
--              with the own profession and skill
--   zone       only sources of the current zone or instance; a dungeon whose entrance lies in the zone
--              counts
-- The switches are window state (settings.bis.style, account-wide, like settings.bis.sources), not
-- registered settings (D-49). They change which sources count, never a score, and are never sent.
-- They apply to the own options only (ns.BisOpts: targets, goals window, map pins, "Hier", the slot
-- card); the gear table's other columns, the simulation and the dungeon pages plan without them.
local ADDON, ns = ...
local L = ns.L
local Gear = ns.Gear

local PS = {}
ns.PlayStyle = PS

PS.KEYS = { "nodungeon", "solo", "buy", "now", "zone" }
PS.LABEL = {
    nodungeon = L["Keine Dungeons"], solo = L["Solo machbar"], buy = L["Kaufbar"],
    now = L["Jetzt holbar"], zone = L["Fokus-Zone"],
}
PS.TIP = {
    nodungeon = L["Keine Beute aus Dungeons und Raids, keine Quests, die in einen Dungeon führen."],
    solo = L["Wie Keine Dungeons; seltene Gegner nur bis zu deiner Stufe + 1; keine Gruppenquests (soweit Amisia sie kennt)."],
    buy = L["Händler, Auktionshaus und alles, was nicht beim Aufheben bindet."],
    now = L["Nur mit dem Ruf, den das Item verlangt; Hergestelltes, das beim Aufheben bindet, nur mit deinem Beruf und Skill."],
    zone = L["Nur Quellen in deiner jetzigen Zone oder Instanz; Dungeons mit Eingang in der Zone zählen dazu."],
}
-- the words of /amisia spielstil, German and English
PS.WORDS = {
    ["keine-dungeons"] = "nodungeon", keinedungeons = "nodungeon", nodungeons = "nodungeon", ["no-dungeons"] = "nodungeon",   -- l10n-ok: command word / internal key
    solo = "solo", kaufbar = "buy", buyable = "buy", buy = "buy", jetzt = "now", now = "now",
    zone = "zone", ["fokus-zone"] = "zone", fokus = "zone", focus = "zone",
}

local KNOWN = {}
for _, k in ipairs(PS.KEYS) do KNOWN[k] = true end

local stamp = 0   -- counts reputation changes, learned quest types and zone changes while they matter
local zoneKey     -- the place key the zone switch last followed (set below, reset by every change)

-- The switches as saved: { [key] = true } with known keys only (others dropped).
function PS.State()
    local s = AmisiaDB and AmisiaDB.settings
    if not s then return {} end
    s.bis = type(s.bis) == "table" and s.bis or {}
    local st = s.bis.style
    if type(st) ~= "table" then
        st = {}
        s.bis.style = st
    end
    for k, v in pairs(st) do
        if not KNOWN[k] or v ~= true then st[k] = nil end
    end
    return st
end

function PS.On(key) return PS.State()[key] == true end

function PS.Count()
    local n = 0
    for _ in pairs(PS.State()) do n = n + 1 end
    return n
end

local function changed()
    stamp = stamp + 1
    ns.Fire("BIS_CHANGED", "style")
end

-- the zone the switch follows from now on: the current one while it is on
local function zoneNow()
    local p = PS.On("zone") and ns.BisCurrentPlace and ns.BisCurrentPlace() or nil
    zoneKey = PS.On("zone") and (p and p.key or "-") or nil
end

function PS.Set(key, on)
    if not KNOWN[key] then return false end
    local st = PS.State()
    on = on and true or nil
    if st[key] == on then return false end
    st[key] = on
    zoneNow()
    changed()
    return true
end

function PS.Toggle(key) return PS.Set(key, not PS.On(key)) end

function PS.Clear()
    local st = PS.State()
    if not next(st) then return false end
    for k in pairs(st) do st[k] = nil end
    zoneNow()
    changed()
    return true
end

-- The active switches by name in PS.KEYS order, joined ("Kaufbar, Fokus-Zone"), or nil.
function PS.Names(st)
    st = st or PS.State()
    local out = {}
    for _, k in ipairs(PS.KEYS) do if st[k] then out[#out + 1] = PS.LABEL[k] end end
    return #out > 0 and table.concat(out, ", ") or nil
end

---------------------------------------------------------------------------
-- Data: quest types, reputation
---------------------------------------------------------------------------

-- The quest type of a quest: G group or elite, D dungeon, R raid, P PvP; from the data (QT, learned
-- by earlier builds) or what this client learned from its quest log (Collect/QuestTags.lua).
function PS.QuestTag(qid)
    if type(qid) ~= "number" then return nil end
    local d = ns.Data("GEAR")
    local t = d and type(d.QT) == "table" and d.QT[qid]
    if t then return t end
    return ns.QuestTags and ns.QuestTags.Get(qid) or nil
end

-- The reputation an item asks for: faction id, standing 0 (hated) .. 7 (exalted); nil for none.
function Gear.ItemRep(id)
    local d = ns.Data("GEAR")
    local v = d and type(d.RP) == "table" and d.RP[id]
    if type(v) ~= "number" or v < 10 then return nil end
    return math.floor(v / 10), v % 10
end

-- The client's name of a standing 0..7 (FACTION_STANDING_LABEL1..8).
function PS.StandingName(n)
    local s = type(n) == "number" and _G["FACTION_STANDING_LABEL" .. (n + 1)]
    return type(s) == "string" and s or tostring(n)
end

-- The own standing with a faction: standing 0..7 and the faction's name; nil when the client does not
-- say (an unknown faction counts as reached: better shown than hidden).
function PS.Standing(fac)
    local R = _G.C_Reputation
    if type(R) == "table" and type(R.GetFactionDataByID) == "function" then
        local ok, info = pcall(R.GetFactionDataByID, fac)
        if ok and type(info) == "table" then
            local r = tonumber(ns.Plain(info.reaction))
            local name = ns.Plain(info.name)
            if r and r >= 1 and r <= 8 then return r - 1, type(name) == "string" and name or nil end
        end
    end
    if type(_G.GetFactionInfoByID) == "function" then
        local ok, name, _, standing = pcall(_G.GetFactionInfoByID, fac)
        standing = ok and tonumber(ns.Plain(standing)) or nil
        name = ok and ns.Plain(name) or nil
        if standing and standing >= 1 and standing <= 8 then return standing - 1, type(name) == "string" and name or nil end
    end
    return nil
end

-- "Ruf: Sturmwind, Wohlwollend (du: Freundlich)" for an item that asks for a reputation, else nil;
-- the second value is true when the own standing is too low.
function PS.RepText(id)
    local fac, need = Gear.ItemRep(id)
    if not fac then return nil end
    local have, name = PS.Standing(fac)
    local text = L["Ruf: %s, %s"]:format(name or ("#" .. fac), PS.StandingName(need))
    if have then text = text .. L[" (du: %s)"]:format(PS.StandingName(have)) end
    return text, have ~= nil and have < need
end

---------------------------------------------------------------------------
-- The rules
---------------------------------------------------------------------------

-- The source an item that does not bind on pickup has under "Kaufbar" (Gear.SourceText).
PS.AH_REC = { "A", "B" }

-- Whether an item can be bought from other players: it does not bind on pickup, and it is no quest item.
function PS.Buyable(row)
    local b = row and row[6]
    return b ~= 1 and b ~= 4
end

-- The context of the own options, or nil when no switch is on: { on = switches, level, skills,
-- place = { key, keys } (zone), rep = { [faction] = standing or false }, entr = { [place key] = bool } }.
function PS.Context(o)
    local st = PS.State()
    if not next(st) then return nil end
    local c = { on = {}, level = o.level or 1, skills = o.skills, rep = {}, entr = {} }
    for k in pairs(st) do c.on[k] = true end
    if c.on.zone then c.place = ns.BisCurrentPlace and ns.BisCurrentPlace() or nil end
    return c
end

-- The part of the options' key the switches make: switches, the place (zone) and the stamp.
function PS.Key(c)
    if not c then return "" end
    local out = {}
    for _, k in ipairs(PS.KEYS) do if c.on[k] then out[#out + 1] = k end end
    return table.concat(out, ",") .. "@" .. (c.place and c.place.key or "-") .. "#" .. stamp
end

local function standingOf(c, fac)
    local v = c.rep[fac]
    if v == nil then
        v = PS.Standing(fac) or false
        c.rep[fac] = v
    end
    return v or nil
end

-- The dungeon of a trash drop ("Trash (Gnomeregan)", a world drop record), or nil.
local function trashOf(rec)
    local name = rec[1] == "W" and rec[2]
    return type(name) == "string" and name:match("^Trash %((.+)%)$") or nil
end

local function questInDungeon(rec)
    if rec[9] ~= nil then return true end
    local t = PS.QuestTag(rec[7])
    return t == "D" or t == "R"
end

local function inZone(rec, c)
    local p = c.place
    if not p then return false end
    local trash = trashOf(rec)
    local key = trash and ("N:" .. trash) or Gear.PlaceOf(rec)
    if not key then return false end
    if p.keys[key] then return true end
    if rec[1] ~= "D" and rec[1] ~= "X" and not trash then return false end
    local hit = c.entr[key]
    if hit == nil then
        hit = false
        for _, pt in ipairs(ns.MapPoints and ns.MapPoints(key) or {}) do
            if p.keys["Z:" .. pt.map] then hit = true break end
        end
        c.entr[key] = hit
    end
    return hit
end

-- Whether a source passes every switch that is on; false and the key of the first that fails.
function PS.RecOk(rec, row, c)
    local k, on = rec[1], c.on
    if on.nodungeon or on.solo then
        if k == "D" or k == "X" or (k == "Q" and questInDungeon(rec)) or trashOf(rec) then
            return false, on.nodungeon and "nodungeon" or "solo"
        end
    end
    if on.solo then
        if k == "Q" and PS.QuestTag(rec[7]) == "G" then return false, "solo" end
        if k == "R" and (rec[3] or 0) > c.level + 1 then return false, "solo" end
    end
    -- an item that does not bind on pickup comes in through PS.AH_REC (Gear.Best, Gear.Sources)
    if on.buy and k ~= "V" and k ~= "A" and k ~= "P" then return false, "buy" end
    if on.now and k == "C" and row and row[6] == 1 and type(c.skills) == "table" then
        if (c.skills[rec[2]] or 0) < (rec[3] or 0) then return false, "now" end
    end
    if on.zone and not inZone(rec, c) then return false, "zone" end
    return true
end

-- Whether the item itself passes (the reputation of "Jetzt holbar"); false and "now" when not.
function PS.ItemOk(id, c)
    if c.on.now then
        local fac, need = Gear.ItemRep(id)
        if fac then
            local have = standingOf(c, fac)
            if have and have < need then return false, "now" end
        end
    end
    return true
end

-- Whether an item that failed by its sources still comes in by being bought ("Kaufbar").
function PS.BuyOk(row, c)
    return c.on.buy and PS.Buyable(row) and (PS.RecOk(PS.AH_REC, row, c))
end

-- Whether an item counts for the options as Gear.Best counts it: a source that passes Gear.SourceOk
-- (chips, faction, class, exclusions and, with o.style, the switches), or with "Kaufbar" bought from
-- other players; and with "Jetzt holbar" its reputation. An item without sources (a BiS pick the data
-- does not list) passes no switch: nothing is known of where it comes from.
function PS.Passes(id, o)
    local row = Gear.Item(id)
    if not row then return false end
    local ok = false
    for i = Gear.FIRST_SOURCE, #row do
        if Gear.SourceOk(Gear.Source(row[i]), o, row) then ok = true break end
    end
    local c = o.style
    if c then
        if not ok and PS.BuyOk(row, c) then ok = true end
        if ok and not PS.ItemOk(id, c) then ok = false end
    end
    return ok
end

local function withoutStyle(o, fn)
    local st = o.style
    o.style = nil
    local ok, res = pcall(fn, o)
    o.style = st
    if not ok then error(res, 0) end
    return res
end

-- Whether the switches (and not the chips or the faction) keep an item out of the options.
function PS.Blocks(id, o)
    if not (o and o.style) then return false end
    if PS.Passes(id, o) then return false end
    return withoutStyle(o, function(x) return PS.Passes(id, x) end)
end

-- Whether an item passes the options with their switches, and if not the keys of the switches that
-- keep it out (empty: no source is known, "unknown" stands for it).
function PS.ItemPasses(id, o)
    local c = o and o.style
    if not c then return true, {} end
    if PS.Passes(id, o) then return true, {} end
    local why, seen = {}, {}
    local function note(k)
        if k and not seen[k] then seen[k] = true; why[#why + 1] = k end
    end
    local ok, k = PS.ItemOk(id, c)
    if not ok then note(k) end
    local row = Gear.Item(id)
    for i = Gear.FIRST_SOURCE, #(row or {}) do
        local rec = Gear.Source(row[i])
        -- the sources the chips and the faction let through: which switch stops them
        if rec and withoutStyle(o, function(x) return Gear.SourceOk(rec, x, row) end) then
            local _, why1 = PS.RecOk(rec, row, c)
            note(why1)
        end
    end
    if #why == 0 then note("unknown") end
    return false, why
end

-- The switches without one of them (a place picked on "Hier" needs no zone switch), or c itself.
function PS.Without(c, key)
    if not (c and c.on[key]) then return c end
    local out = {}
    for k, v in pairs(c) do out[k] = v end
    out.on = {}
    for k in pairs(c.on) do if k ~= key then out.on[k] = true end end
    if not next(out.on) then return nil end
    return out
end

-- The reasons as text: "Keine Dungeons" or, for the reputation, the reputation line.
function PS.WhyText(id, why)
    local out = {}
    for _, k in ipairs(why or {}) do
        if k == "now" and Gear.ItemRep(id) then out[#out + 1] = (PS.RepText(id))
        elseif k == "unknown" then out[#out + 1] = L["Quelle unbekannt"]
        else out[#out + 1] = PS.LABEL[k] end
    end
    return table.concat(out, "; ")
end

---------------------------------------------------------------------------
-- What changes the result: reputation, the zone, learned quest types
---------------------------------------------------------------------------

local zonePending = false
local function zoneCheck()
    zonePending = false
    if not PS.On("zone") then zoneKey = nil return end
    local p = ns.BisCurrentPlace and ns.BisCurrentPlace()
    local key = p and p.key or "-"
    if key ~= zoneKey then
        zoneKey = key
        changed()
    end
end
local function zoneSoon()
    if zonePending or not PS.On("zone") then return end
    zonePending = true
    if C_Timer and C_Timer.After then C_Timer.After(2, zoneCheck) else zoneCheck() end
end
ns.OnEvent("ZONE_CHANGED_NEW_AREA", zoneSoon)
ns.OnEvent("ZONE_CHANGED_INDOORS", zoneSoon)
ns.OnEvent("ZONE_CHANGED", zoneSoon)
ns.OnEvent("PLAYER_ENTERING_WORLD", zoneSoon)

local repPending = false
ns.OnEvent("UPDATE_FACTION", function()
    if repPending or not PS.On("now") then return end
    repPending = true
    local function go() repPending = false; changed() end
    if C_Timer and C_Timer.After then C_Timer.After(1, go) else go() end
end)

-- a quest type learned from the quest log (Collect/QuestTags.lua)
function PS.QuestTagLearned()
    if PS.On("solo") or PS.On("nodungeon") then changed() end
end

---------------------------------------------------------------------------
-- /amisia spielstil
---------------------------------------------------------------------------

function PS.Command(rest)
    local word = type(rest) == "string" and rest:lower():match("^%s*(%S+)") or nil
    if word == "aus" or word == "off" then   -- l10n-ok: command word / internal key
        PS.Clear()
    elseif word then
        local key = PS.WORDS[word]
        if not key then
            ns.msg(L["Aufruf: /amisia spielstil [keine-dungeons|solo|kaufbar|jetzt|zone|aus]"])
            return
        end
        PS.Toggle(key)
    end
    local names = PS.Names()
    ns.msg(names and L["Spielstil: %s."]:format(names) or L["Spielstil: aus (alle Quellen der Chips zählen)."])
end

ns.RegisterSlash("spielstil", { en = "playstyle", args = L["[keine-dungeons|solo|kaufbar|jetzt|zone|aus]"],
    desc = L["Spielstil der Ausrüstungsziele zeigen oder umschalten"],
    run = function(rest) PS.Command(rest) end })
