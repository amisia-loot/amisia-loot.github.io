-- Amisia quest tracker: every quest of the world (QuestData.lua, built by tools/build_quests.py)
-- for the own character - done, in the log, open to take now or locked and why (faction, race,
-- class, level, a missing pre-quest, a profession, an alternative already done) - with its chain and
-- progress, its gear rewards with the upgrade mark (ns.UpgradeOf), grouped by zone, searchable, and
-- the quest giver's waypoint (the data's place, else what this client saw itself through the
-- collector; what was only heard from the guild sets no waypoint).
--
-- The data file holds one string per quest; it is parsed the first time anything asks
-- (ns.QuestIndex) into one small array per quest (lists stay strings) and kept until a /reload. The
-- list keeps one status letter per quest; the full state with its reasons is made only for the
-- quests shown. The switch quests.enabled turns the page off; off at login, the data is dropped at
-- once so its strings are collected.
local ADDON, ns = ...
local Gear = ns.Gear
local L, N_ = ns.L, ns.N_

local Q = {}
ns.Quests = Q

local MAX_CHAIN = 40          -- quests of one chain at most
local MAX_DEPTH = 30          -- pre-quest levels walked at most
local NO_START = L["Für diese Quest kennt Amisia keinen Startort."]
local ITEM_START = L["Diese Quest startet durch ein Item."]
local NO_MAP = L["Keine Kartendaten für diesen Client."]
local MICRO, ORPHAN = 5, 6    -- Enum.UIMapType of sub zones that count as the zone above them
Q.NO_START, Q.ITEM_START = NO_START, ITEM_START

-- the fields of a parsed record (an array, a third of the memory of named fields)
-- NEED: how many of PRE are needed (the flag N<n>), false for all of them
local ID, ZONE, NAME, MIN, FAC, CLASSES, RACES, SKILL, GIVER, POINTS, START, PRE, ALT, REWARDS, FLAGS, NEED =
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16

-- German keys, shown through L
local RACE_NAMES = { N_("Mensch"), N_("Orc"), N_("Zwerg"), N_("Nachtelf"), N_("Untoter"), N_("Tauren"), N_("Gnom"), N_("Troll") }
local RACE_IDS = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Undead = 5, Tauren = 6, Gnome = 7, Troll = 8 }
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
-- skill lines the data names (requireSkill) and their German names (the German client's skill line
-- names match them; shown through L, the English client's names match the English text)
local SKILL_NAMES = {
    [171] = N_("Alchimie"), [164] = N_("Schmiedekunst"), [185] = N_("Kochkunst"), [333] = N_("Verzauberkunst"),
    [202] = N_("Ingenieurskunst"), [129] = N_("Erste Hilfe"), [356] = N_("Angeln"), [182] = N_("Kräuterkunde"),
    [165] = N_("Lederverarbeitung"), [186] = N_("Bergbau"), [393] = N_("Kürschnerei"), [197] = N_("Schneiderei"),
    [755] = N_("Juwelierskunst"), [633] = N_("Schlossknacken"), [40] = N_("Gifte"),
}
local SKILL_BY_NAME = {}
for id, name in pairs(SKILL_NAMES) do
    SKILL_BY_NAME[name:lower()] = id
    SKILL_BY_NAME[L[name]:lower()] = id
end
Q.SKILL_NAMES = SKILL_NAMES
local STATUS_RANK = { active = 1, open = 2, locked = 3, done = 4 }
local STATUS_OF = { a = "active", o = "open", l = "locked", d = "done" }
Q.STATUS_TEXT = { active = L["im Log"], open = L["annehmbar"], locked = L["gesperrt"], done = L["erledigt"] }

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function plain(v) return ns.Plain and ns.Plain(v) or v end

---------------------------------------------------------------------------
-- The data, parsed on demand
---------------------------------------------------------------------------

local index, indexData
local dropped = false   -- the data went at login (switch off)
local gen = 0           -- bumped by everything that changes a state (quest events, level, skills)

-- "a;b;c" into its fields, empty ones kept
local function fields(s)
    local out, pos = {}, 1
    while true do
        local a = s:find(";", pos, true)
        if not a then
            out[#out + 1] = s:sub(pos)
            return out
        end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = a + 1
    end
end

-- a list field ("5", "5,7" or "") as it is kept: the string, false when empty; nil when broken
local function listField(s)
    if s == "" then return false end
    if not s:match("^%d+[%d,]*$") or s:find(",,", 1, true) or s:sub(-1) == "," then return nil end
    return s
end

-- the ids of a kept list field, as an iterator
local function eachId(v)
    if not v then return function() return nil end end
    local it = v:gmatch("%d+")
    return function()
        local s = it()
        return s and tonumber(s) or nil
    end
end
Q.EachId = eachId

-- One record of the data as an array (see ID..FLAGS), or nil when it does not parse.
local function parse(qid, s)
    if type(s) ~= "string" then return nil end
    local f = fields(s)
    if #f ~= 14 then return nil end
    local zone, min, classes, races, skill, giver = tonumber(f[1]), tonumber(f[3]), tonumber(f[5]), tonumber(f[6]),
        tonumber(f[7]), tonumber(f[8])
    if not (zone and min and classes and races and skill and giver) then return nil end
    if f[4] ~= "" and f[4] ~= "A" and f[4] ~= "H" then return nil end
    local pre, alt, rewards = listField(f[11]), listField(f[12]), listField(f[13])
    if pre == nil or alt == nil or rewards == nil then return nil end
    return { qid, zone, f[2] ~= "" and f[2] or ("Quest " .. qid), min, f[4], classes, races, skill, giver,
        f[9] ~= "" and f[9] or false, f[10], pre, alt, rewards, f[14], tonumber(f[14]:match("N(%d+)")) or false }
end

local function enabled() return ns.Get("quests.enabled") ~= false end

-- The parsed data: { byId, list (by id), next = { [qid] = follow-up id or { ids } }, count }, or nil
-- and why: "off" (the switch), "reload" (switched on again after the data went at login), "nodata".
function ns.QuestIndex()
    if not enabled() then return nil, "off" end
    local d = ns.Data("QUEST_DATA")
    if d == nil then return nil, dropped and "reload" or "nodata" end
    if type(d) ~= "table" or type(d.Q) ~= "table" then return nil, "nodata" end
    if index and indexData == d then return index end
    local byId, list, nxt = {}, {}, {}
    for qid, s in pairs(d.Q) do
        local r = type(qid) == "number" and parse(qid, s) or nil
        if r then
            byId[qid] = r
            list[#list + 1] = r
        end
    end
    table.sort(list, function(a, b) return a[ID] < b[ID] end)
    for _, r in ipairs(list) do
        for p in eachId(r[PRE]) do
            -- a quest listing itself is no follow-up of itself
            if byId[p] and p ~= r[ID] then
                local have = nxt[p]
                if have == nil then
                    nxt[p] = r[ID]
                elseif type(have) == "number" then
                    nxt[p] = { have, r[ID] }
                else
                    have[#have + 1] = r[ID]
                end
            end
        end
    end
    index, indexData = { byId = byId, list = list, next = nxt, count = #list, npcName = {}, npcPts = {}, data = d }, d
    return index
end

-- The follow-up quests of a quest as a list.
local function nextOf(idx, qid)
    local v = idx.next[qid]
    if v == nil then return {} end
    if type(v) == "number" then return { v } end
    return v
end
function Q.Next(qid)
    local idx = ns.QuestIndex()
    return idx and nextOf(idx, qid) or {}
end

-- A record with named fields (for the tooltip and the tests): id, zone, name, min, fac, classes,
-- races, skill, giver, points, start, pre, alt, rewards (lists), need (how many of pre, nil for all),
-- breadcrumb, repeatable, classic.
function Q.Record(qid)
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    if not r then return nil end
    local function list(v)
        local out = {}
        for id in eachId(v) do out[#out + 1] = id end
        return #out > 0 and out or nil
    end
    local flags = r[FLAGS]
    return { id = r[ID], zone = r[ZONE], name = r[NAME], min = r[MIN], fac = r[FAC], classes = r[CLASSES], races = r[RACES],
        skill = r[SKILL], giver = r[GIVER], points = r[POINTS] or nil, start = r[START], pre = list(r[PRE]), alt = list(r[ALT]),
        rewards = list(r[REWARDS]), need = r[NEED] or nil, breadcrumb = flags:find("B", 1, true) ~= nil,
        repeatable = flags:find("R", 1, true) ~= nil, classic = flags:find("C", 1, true) ~= nil }
end

-- The quest giver of the data: name (English) and points text, each or nil.
local function npc(idx, id)
    if not id or id == 0 then return nil, nil end
    local name = idx.npcName[id]
    if name == nil then
        local s = type(idx.data.N) == "table" and idx.data.N[id]
        local n, pts = nil, nil
        if type(s) == "string" then n, pts = s:match("^(.-);(.*)$") end
        name = n or false
        idx.npcName[id], idx.npcPts[id] = name, (pts and pts ~= "") and pts or false
    end
    return name or nil, idx.npcPts[id] or nil
end
function Q.Giver(qid)
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    return r and (npc(idx, r[GIVER])) or nil
end

---------------------------------------------------------------------------
-- The character
---------------------------------------------------------------------------

local optsCache, optsGen
-- The own character: { level, faction ("A"/"H"), class, race (id 1-8 or nil), skills ({ [skill line] = rank }
-- or nil when the client tells none) }; made once per state.
function ns.QuestOpts()
    if optsCache and optsGen == gen then return optsCache end
    local o = {}
    o.level = math.max(1, tonumber(plain(UnitLevel and UnitLevel("player"))) or 1)
    local fac = UnitFactionGroup and plain(UnitFactionGroup("player"))
    o.faction = fac == "Horde" and "H" or fac == "Alliance" and "A" or nil
    if UnitClass then o.class = plain(select(2, UnitClass("player"))) end
    if UnitRace then
        local _, file, id = UnitRace("player")
        id = tonumber(plain(id))
        o.race = (id and id >= 1 and id <= 8) and id or RACE_IDS[plain(file) or ""]
    end
    local info = _G.C_SkillInfo
    if type(info) == "table" and type(info.GetNumSkillLines) == "function" and type(info.GetSkillLineInfo) == "function" then
        o.skills = {}
        local ok, n = pcall(info.GetNumSkillLines)
        for i = 1, (ok and tonumber(n)) or 0 do
            local ok2, s = pcall(info.GetSkillLineInfo, i)
            if ok2 and type(s) == "table" and not s.isHeader then
                local id = tonumber(s.skillID)
                if not id or id == 0 then id = type(s.name) == "string" and SKILL_BY_NAME[s.name:lower()] or nil end
                if id then o.skills[id] = math.max(o.skills[id] or 0, tonumber(s.rank) or 0) end
            end
        end
    end
    optsCache, optsGen = o, gen
    return o
end

---------------------------------------------------------------------------
-- Done and in the log
---------------------------------------------------------------------------

local doneSet, doneGen, doneMemo = nil, nil, {}
local activeMemo = {}
local turnedIn = {}     -- quests turned in this session (the flag can lag behind the event)

local function syncMemos()
    if doneGen == gen then return end
    doneGen, doneMemo, activeMemo, doneSet = gen, {}, {}, nil
    local Ql = _G.C_QuestLog
    local all = type(Ql) == "table" and Ql.GetAllCompletedQuestIDs
    if type(all) == "function" then
        local ok, ids = pcall(all)
        if ok and type(ids) == "table" then
            doneSet = {}
            for _, id in ipairs(ids) do
                id = tonumber(plain(id))
                if id then doneSet[id] = true end
            end
        end
    end
end

local function isDone(qid)
    syncMemos()
    if turnedIn[qid] then return true end
    if doneSet then return doneSet[qid] == true end
    local v = doneMemo[qid]
    if v == nil then
        local Ql = _G.C_QuestLog
        local f = type(Ql) == "table" and Ql.IsQuestFlaggedCompleted
        v = false
        if type(f) == "function" then
            local ok, done = pcall(f, qid)
            v = ok and plain(done) == true
        end
        doneMemo[qid] = v
    end
    return v
end

local function isActive(qid)
    syncMemos()
    local v = activeMemo[qid]
    if v == nil then
        local Ql = _G.C_QuestLog
        local f = type(Ql) == "table" and Ql.IsOnQuest
        v = false
        if type(f) == "function" then
            local ok, on = pcall(f, qid)
            v = ok and plain(on) == true
        end
        activeMemo[qid] = v
    end
    return v
end
Q.IsDone, Q.IsActive = isDone, isActive

-- A quest counts as done for the quests after it when it or one of its alternatives is done.
local function satisfied(idx, qid)
    if isDone(qid) then return true end
    local r = idx.byId[qid]
    for a in eachId(r and r[ALT]) do
        if isDone(a) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Titles and names
---------------------------------------------------------------------------

local titles = {}
-- The client's title (German where it has the quest loaded), else the data's English name.
function Q.Title(qid)
    local t = titles[qid]
    if t then return t end
    local Ql = _G.C_QuestLog
    local f = type(Ql) == "table" and Ql.GetTitleForQuestID
    if type(f) == "function" then
        local ok, title = pcall(f, qid)
        title = ok and plain(title) or nil
        if type(title) == "string" and title ~= "" then
            titles[qid] = title
            return title
        end
    end
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    return r and r[NAME] or ("Quest " .. tostring(qid))
end

local zoneNames, displayZones = {}, {}

local function mapInfo(z)
    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, z)
    return ok and type(info) == "table" and info or nil
end

-- The zone a quest is listed under: a sub zone (Northshire) counts as the zone above it.
function Q.DisplayZone(z)
    if not z or z == 0 then return 0 end
    local d = displayZones[z]
    if d then return d end
    d = z
    for _ = 1, 5 do
        local info = mapInfo(d)
        local kind = info and tonumber(plain(info.mapType))
        local parent = info and tonumber(plain(info.parentMapID))
        if not (kind == MICRO or kind == ORPHAN) or not parent or parent <= 0 then break end
        d = parent
    end
    displayZones[z] = d
    return d
end

-- The zone's name: the client's, else the data's English one; "Ohne Zone" for 0.
function Q.ZoneName(z)
    if not z or z == 0 then return L["Ohne Zone"] end
    local n = zoneNames[z]
    if n then return n end
    local info = mapInfo(z)
    n = info and plain(info.name)
    if type(n) ~= "string" or n == "" then
        local d = ns.Data("QUEST_DATA")
        n = type(d) == "table" and type(d.Z) == "table" and d.Z[z] or ("Zone " .. z)
    end
    zoneNames[z] = n
    return n
end

---------------------------------------------------------------------------
-- State of a quest
---------------------------------------------------------------------------

local function hasBit(mask, i) return math.floor(mask / 2 ^ (i - 1)) % 2 == 1 end

local function raceText(mask)
    local out = {}
    for i, name in ipairs(RACE_NAMES) do
        if hasBit(mask, i) then out[#out + 1] = L[name] end
    end
    return table.concat(out, "/")
end

local function classText(mask)
    local out = {}
    for _, c in ipairs(CLASS_ORDER) do
        if Gear.HasClassBit(mask, c) then out[#out + 1] = Gear.CLASS_NAMES[c] or c end
    end
    return table.concat(out, "/")
end

-- Whether the own character can take a quest at all (faction, race, class).
local function forMe(r, o)
    if r[FAC] ~= "" and o.faction and r[FAC] ~= o.faction then return false end
    if r[RACES] > 0 and o.race and not hasBit(r[RACES], o.race) then return false end
    if r[CLASSES] > 0 and o.class and not Gear.HasClassBit(r[CLASSES], o.class) then return false end
    return true
end

local function isBreadcrumb(r) return r[FLAGS]:find("B", 1, true) ~= nil end

-- The limits of a quest for the options: the number of reasons, whether it is another faction's,
-- race's or class's, the note on a profession the client cannot check. With add, every reason goes
-- to add(kind, text); without, nothing is made (the list asks this for every quest).
local function limits(idx, r, o, add)
    local n, foreign, note = 0, false, nil
    if r[FAC] ~= "" and o.faction and r[FAC] ~= o.faction then
        n, foreign = n + 1, true
        if add then add("faction", r[FAC] == "H" and L["nur Horde"] or L["nur Allianz"]) end
    end
    if r[RACES] > 0 and o.race and not hasBit(r[RACES], o.race) then
        n, foreign = n + 1, true
        if add then add("race", L["nur %s"]:format(raceText(r[RACES]))) end
    end
    if r[CLASSES] > 0 and o.class and not Gear.HasClassBit(r[CLASSES], o.class) then
        n, foreign = n + 1, true
        if add then add("class", L["nur %s"]:format(classText(r[CLASSES]))) end
    end
    for a in eachId(r[ALT]) do
        if isDone(a) then
            n = n + 1
            if add then add("alt", L["Alternative erledigt: %s"]:format(Q.Title(a))) end
            break
        end
    end
    -- the pre-quests: those the own character can take (another faction's, race's or class's variant
    -- of a step does not count), not the quest itself, a breadcrumb only where any one of the list
    -- will do (a breadcrumb is a way to the quest, never a must); all of them, or NEED of them
    local need = r[NEED]
    local first, more, have, cand = nil, 0, 0, 0
    for p in eachId(r[PRE]) do
        local pr = idx.byId[p]
        if pr and p ~= r[ID] and forMe(pr, o) and (need or not isBreadcrumb(pr)) then
            cand = cand + 1
            if satisfied(idx, p) then
                have = have + 1
            elseif first then
                more = more + 1
            else
                first = p
            end
        end
    end
    if first and (not need or have < math.min(need, cand)) then
        n = n + 1
        if add then
            local rest = ""
            if more > 0 then
                rest = need == 1 and (L[" (oder %d weitere)"]):format(more) or not need and (" (+%d)"):format(more)
                    or (L[" (%d von %d nötig)"]):format(need - have, more + 1)
            end
            add("pre", L["Vorquest fehlt: %s"]:format(Q.Title(first)) .. rest)
        end
    end
    -- a breadcrumb leads to a quest: taken or done, the way there is gone
    if isBreadcrumb(r) and not isDone(r[ID]) then
        for _, nq in ipairs(nextOf(idx, r[ID])) do
            local d = isDone(nq)
            if d or isActive(nq) then
                n = n + 1
                if add then add("follow", (d and L["Folgequest schon erledigt: %s"] or L["Folgequest schon angenommen: %s"]):format(Q.Title(nq))) end
                break
            end
        end
    end
    if r[MIN] > o.level then
        n = n + 1
        if add then add("level", L["ab Level %s"]:format(r[MIN])) end
    end
    if r[SKILL] > 0 then
        local name = SKILL_NAMES[r[SKILL]] and L[SKILL_NAMES[r[SKILL]]] or L["Beruf %s"]:format(r[SKILL])
        if o.skills then
            if not o.skills[r[SKILL]] then
                n = n + 1
                if add then add("skill", L["Beruf fehlt: %s"]:format(name)) end
            end
        else
            note = L["Beruf: %s"]:format(name)
        end
    end
    return n, foreign, note
end

local codeCache, codeGen = {}, nil   -- qid -> status letter (a, o, l, d), "F" appended for foreign

-- The status of a quest without making anything: "done", "active", "open" or "locked", and foreign.
local function statusOf(idx, r)
    if codeGen ~= gen then codeCache, codeGen = {}, gen end
    local qid = r[ID]
    local c = codeCache[qid]
    if not c then
        local n, foreign = limits(idx, r, ns.QuestOpts())
        if isDone(qid) then c = "d" elseif isActive(qid) then c = "a" elseif n > 0 then c = "l" else c = "o" end
        if foreign then c = c .. "F" end
        codeCache[qid] = c
    end
    return STATUS_OF[c:sub(1, 1)], #c > 1
end

local stateCache, stateGen = {}, nil

-- The state of a quest for the own character: { qid, title, status ("done", "active", "open",
-- "locked"), reasons = { { kind, text } } (kind faction, race, class, alt, pre, follow (a breadcrumb
-- whose follow-up is taken or done), level, skill),
-- foreign (another faction's, race's or class's: never for this character), note (a profession the
-- client cannot check), rec (Q.Record) }. nil for a quest the data does not know. Kept per state;
-- made only for the quests asked for (the shown rows, a tooltip).
function ns.QuestState(qid)
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    if not r then return nil end
    if stateGen ~= gen then stateCache, stateGen = {}, gen end
    local kept = stateCache[qid]
    if kept then return kept end
    local info = { qid = qid, rec = Q.Record(qid), title = Q.Title(qid), reasons = {} }
    local _, foreign, note = limits(idx, r, ns.QuestOpts(), function(kind, text)
        info.reasons[#info.reasons + 1] = { kind = kind, text = text }
    end)
    info.foreign, info.note = foreign, note
    info.status = statusOf(idx, r)
    stateCache[qid] = info
    return info
end

-- The text of a state: "im Log", "annehmbar", "erledigt" or the first reason (+n).
function Q.StatusText(info)
    if info.status ~= "locked" then return Q.STATUS_TEXT[info.status] end
    local first = info.reasons[1] and info.reasons[1].text or L["gesperrt"]
    if #info.reasons > 1 then first = first .. (" (+%d)"):format(#info.reasons - 1) end
    return first
end

---------------------------------------------------------------------------
-- Chains
---------------------------------------------------------------------------

local chainCache, chainGen = {}, nil

-- The chain of a quest: its pre-quests (all levels, root first), the quest, the quests after it the
-- own character can take (breadth first), at most MAX_CHAIN: { ids, pos (of the quest), done, total };
-- nil for a quest without pre-quests and follow-ups. An alternative already done stands for its pair.
function ns.QuestChain(qid)
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    if not r then return nil end
    if chainGen ~= gen then chainCache, chainGen = {}, gen end
    local kept = chainCache[qid]
    if kept ~= nil then return kept or nil end
    local o = ns.QuestOpts()
    local before, seen = {}, { [qid] = true }
    local function walk(id, depth)
        local x = idx.byId[id]
        if not x or depth > MAX_DEPTH then return end
        for p in eachId(x[PRE]) do
            local pr = idx.byId[p]
            if pr and not seen[p] and forMe(pr, o) and #before < MAX_CHAIN then
                seen[p] = true
                walk(p, depth + 1)
                before[#before + 1] = p
            end
        end
    end
    walk(qid, 1)
    local ids = {}
    for _, p in ipairs(before) do ids[#ids + 1] = p end
    ids[#ids + 1] = qid
    local pos = #ids
    local todo, head = { qid }, 1
    while head <= #todo and #ids < MAX_CHAIN do
        local id = todo[head]
        head = head + 1
        for _, n in ipairs(nextOf(idx, id)) do
            local nr = idx.byId[n]
            if not seen[n] and nr and forMe(nr, o) then
                seen[n] = true
                ids[#ids + 1] = n
                todo[#todo + 1] = n
                if #ids >= MAX_CHAIN then break end
            end
        end
    end
    if #ids < 2 then
        chainCache[qid] = false
        return nil
    end
    local done = 0
    for _, id in ipairs(ids) do
        if satisfied(idx, id) then done = done + 1 end
    end
    local c = { ids = ids, pos = pos, done = done, total = #ids }
    chainCache[qid] = c
    return c
end

-- "3/7"
function Q.ChainText(c)
    if not c then return "" end
    return ("%d/%d"):format(c.done, c.total)
end

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------

local rewardCache, rewardStamp = {}, nil
local NO_REWARDS = { list = {} }

-- The gear rewards of a quest with the comparison with the worn gear: { list = { { id, gain, up,
-- later, mark } } (upgrades first, then by gain), best (the largest upgrade or nil) }. Kept until
-- Bis.lua's stamp changes; an item whose stats are not loaded yet is asked again next time.
function ns.QuestRewards(qid)
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    if not (r and r[REWARDS]) then return NO_REWARDS end
    local stamp = ns.BisStamp and ns.BisStamp() or 0
    if rewardStamp ~= stamp then rewardCache, rewardStamp = {}, stamp end
    local kept = rewardCache[qid]
    if kept then return kept end
    local out = { list = {} }
    local complete = true
    for id in eachId(r[REWARDS]) do
        local e = { id = id }
        if ns.UpgradeOf then
            local ok, u, _, code = pcall(ns.UpgradeOf, id)
            if ok and type(u) == "table" then
                e.gain, e.up, e.later = u.gain, u.up and true or false, u.later
                e.mark = ns.UpgradeShort and ns.UpgradeShort(u) or nil
            elseif not ok then
                report(u)
            elseif code == "loading" then
                complete = false
            end
        end
        out.list[#out.list + 1] = e
        if e.up and (not out.best or (e.gain or 0) > (out.best.gain or 0)) then out.best = e end
    end
    table.sort(out.list, function(a, b)
        if (a.up or false) ~= (b.up or false) then return a.up or false end
        if (a.gain or -1e9) ~= (b.gain or -1e9) then return (a.gain or -1e9) > (b.gain or -1e9) end
        return a.id < b.id
    end)
    if complete then rewardCache[qid] = out end
    return out
end

---------------------------------------------------------------------------
-- Where a quest starts
---------------------------------------------------------------------------

-- The start of a quest: the record, the points text (the data's: the quest's own, else its giver's;
-- else what this client saw itself), the giver's name (data, else the own observation).
local function startOf(qid)
    local idx = ns.QuestIndex()
    local r = idx and idx.byId[qid]
    if not r then return nil end
    local giver, gpts = npc(idx, r[GIVER])
    local points = r[POINTS] or gpts
    if not points and ns.CollectQuestOwnStart then
        local name, point = ns.CollectQuestOwnStart(qid)
        points = point
        giver = giver or name
    end
    return r, points, giver
end

-- Where a quest starts as text: "durch ein Item", "<giver>, <zone> 48, 42" (" (im Dungeon)"),
-- "<giver> (Ort unbekannt)" or "".
function ns.QuestStartText(qid)
    local r, points, giver = startOf(qid)
    if not r then return "" end
    if r[START] == "X" then return L["durch ein Item"] end
    local Map = ns.Map
    local list = Map and Map.ParsePoints and Map.ParsePoints(points) or {}
    if #list > 0 then
        local p = ns.MapNearest and ns.MapNearest(list) or list[1]
        return ("%s, %s %s%s"):format(giver or L["Startort"], Q.ZoneName(p.map), Map.Coords(p), r[START] == "I" and L[" (im Dungeon)"] or "")
    end
    return giver and L["%s (Ort unbekannt)"]:format(giver) or ""
end

-- Sets the map target to where a quest starts (the nearest point). true, or nil and why.
function ns.QuestWaypoint(qid)
    qid = tonumber(qid)
    local r, points, giver = startOf(qid)
    if not r then return nil, NO_START end
    if r[START] == "X" then return nil, ITEM_START end
    local Map = ns.Map
    if not (Map and Map.ParsePoints and ns.MapSetPoint) then return nil, NO_MAP end
    local list = Map.ParsePoints(points)
    if #list == 0 then return nil, NO_START end
    local label = giver and L["Questgeber %s"]:format(giver) or Q.Title(qid)
    if r[START] == "I" then label = label .. L[" (im Dungeon)"] end
    return ns.MapSetPoint(ns.MapNearest(list), label, "Q:" .. qid)
end

-- Whether a quest has a place a waypoint can go to (for the page's button).
function Q.HasPlace(qid)
    local r, points = startOf(qid)
    if not r or r[START] == "X" then return false end
    local Map = ns.Map
    return Map and Map.ParsePoints and #Map.ParsePoints(points) > 0 or false
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

local lower = ns.Fold

local function matches(idx, r, needle)
    if needle == "" then return true end
    if lower(Q.Title(r[ID])):find(needle, 1, true) or lower(r[NAME]):find(needle, 1, true) then return true end
    local giver = npc(idx, r[GIVER])
    if giver and lower(giver):find(needle, 1, true) then return true end
    return lower(Q.ZoneName(Q.DisplayZone(r[ZONE]))):find(needle, 1, true) ~= nil
end

local listKey, listRows, listCounts

-- The quests for a filter: { zone (uiMapID or nil for all), search, show = { open, active, locked,
-- done }, chains, upgrades, mine (default true: leave out what the own character can never take),
-- collapsed = { [zone] = true } }. Returns rows and counts. Rows: { kind = "zone", zone, name, n,
-- collapsed } and { kind = "quest", qid, zone }; zones by name ("Ohne Zone" last), in a zone
-- in the log first, then open, locked, done, each by level and title. counts: { open, active,
-- locked, done, total } of the quests that pass everything but the status (with upgrades on, only
-- the statuses shown), zones = { { zone, name,
-- n } } (the zones with quests for the own character, for the picker). Kept until anything changes.
function ns.QuestList(filter)
    filter = filter or {}
    local idx, why = ns.QuestIndex()
    if not idx then return {}, { open = 0, active = 0, locked = 0, done = 0, total = 0, zones = {} }, why end
    local show = filter.show or { open = true, active = true }
    local needle = lower(filter.search):match("^%s*(.-)%s*$") or ""
    local mine = filter.mine ~= false
    local collapsed = filter.collapsed or {}
    local cparts = {}
    for z, on in pairs(collapsed) do if on then cparts[#cparts + 1] = tostring(z) end end
    table.sort(cparts)
    local key = table.concat({ gen, tostring(idx), filter.zone or "all", needle, show.open and 1 or 0, show.active and 1 or 0,
        show.locked and 1 or 0, show.done and 1 or 0, filter.chains and 1 or 0, filter.upgrades and 1 or 0, mine and 1 or 0,
        table.concat(cparts, ","), filter.upgrades and tostring(ns.BisStamp and ns.BisStamp()) or "" }, "|")
    if key == listKey then return listRows, listCounts end
    local counts = { open = 0, active = 0, locked = 0, done = 0, total = 0, zones = {} }
    local byZone, zoneCount = {}, {}
    for _, r in ipairs(idx.list) do
        local status, foreign = statusOf(idx, r)
        if not (mine and foreign) then
            local qid = r[ID]
            local dz = Q.DisplayZone(r[ZONE])
            zoneCount[dz] = (zoneCount[dz] or 0) + 1
            local pass = (not filter.zone or dz == filter.zone) and matches(idx, r, needle)
            if pass and filter.chains then pass = (r[PRE] ~= false) or (idx.next[qid] ~= nil) end
            -- the rewards are compared only for the statuses shown (a done quest's rewards would ask
            -- the client for items nobody looks at)
            if pass and filter.upgrades then pass = show[status] and ns.QuestRewards(qid).best ~= nil end
            if pass then
                counts[status] = counts[status] + 1
                counts.total = counts.total + 1
                if show[status] then
                    byZone[dz] = byZone[dz] or {}
                    local list = byZone[dz]
                    list[#list + 1] = { kind = "quest", qid = qid, zone = dz }
                end
            end
        end
    end
    local zoneList = {}
    for z, n in pairs(zoneCount) do counts.zones[#counts.zones + 1] = { zone = z, name = Q.ZoneName(z), n = n } end
    for z in pairs(byZone) do zoneList[#zoneList + 1] = { zone = z, name = Q.ZoneName(z) } end
    local function zoneOrder(a, b)
        if (a.zone == 0) ~= (b.zone == 0) then return b.zone == 0 end
        if a.name ~= b.name then return a.name < b.name end
        return a.zone < b.zone
    end
    table.sort(zoneList, zoneOrder)
    table.sort(counts.zones, zoneOrder)
    local rows = {}
    for _, z in ipairs(zoneList) do
        local list = byZone[z.zone]
        -- the sort keys once per quest, not per comparison
        local rank, min, title = {}, {}, {}
        for _, e in ipairs(list) do
            local r = idx.byId[e.qid]
            rank[e.qid], min[e.qid], title[e.qid] = STATUS_RANK[(statusOf(idx, r))], r[MIN], Q.Title(e.qid)
        end
        table.sort(list, function(a, b)
            local x, y = a.qid, b.qid
            if rank[x] ~= rank[y] then return rank[x] < rank[y] end
            if min[x] ~= min[y] then return min[x] < min[y] end
            if title[x] ~= title[y] then return title[x] < title[y] end
            return x < y
        end)
        local isCollapsed = collapsed[z.zone] and true or false
        rows[#rows + 1] = { kind = "zone", zone = z.zone, name = z.name, n = #list, collapsed = isCollapsed }
        if not isCollapsed then
            for _, e in ipairs(list) do rows[#rows + 1] = e end
        end
    end
    listKey, listRows, listCounts = key, rows, counts
    return rows, counts
end

-- The zone of the player for the picker ("Hier"): uiMapID or nil.
function Q.HereZone()
    if IsInInstance and plain(IsInInstance()) then return nil end
    local map = C_Map and C_Map.GetBestMapForUnit and tonumber(plain(C_Map.GetBestMapForUnit("player")))
    if not map or map <= 0 then return nil end
    -- up to the zone (a sub zone counts as its zone, as in the list)
    for _ = 1, 5 do
        local info = mapInfo(map)
        local kind = info and tonumber(plain(info.mapType))
        local parent = info and tonumber(plain(info.parentMapID))
        if not kind or kind <= 3 or not parent or parent <= 0 then break end
        map = parent
    end
    return Q.DisplayZone(map)
end

---------------------------------------------------------------------------
-- Changes, switch, command
---------------------------------------------------------------------------

local function bump()
    gen = gen + 1
    ns.Fire("QUESTS_CHANGED")
end
Q.Bump = bump

-- Test hook: forget everything parsed and kept.
function Q._reset()
    index, indexData = nil, nil
    zoneNames, displayZones, titles, turnedIn = {}, {}, {}, {}
    listKey, rewardCache, rewardStamp = nil, {}, nil
    bump()
end

ns.OnEvent("QUEST_TURNED_IN", function(qid)
    qid = tonumber(plain(qid))
    -- a repeatable quest stays open after it was turned in
    local r = qid and index and index.byId[qid]
    if qid and not (r and r[FLAGS]:find("R", 1, true)) then turnedIn[qid] = true end
    bump()
end)
ns.OnEvent("QUEST_ACCEPTED", bump)
ns.OnEvent("QUEST_REMOVED", bump)
ns.OnEvent("PLAYER_LEVEL_UP", bump)
ns.OnEvent("SKILL_LINES_CHANGED", bump)
ns.OnEvent("PLAYER_ENTERING_WORLD", bump)

-- At login (and a /reload): with the switch off the strings go, nothing refers to them any more.
function Q.OnLoaded(name)
    if name ~= ADDON then return end
    if not enabled() and ns.HasData("QUEST_DATA") then
        ns.DropData("QUEST_DATA")
        index, indexData, dropped = nil, nil, true
    end
end
ns.OnEvent("ADDON_LOADED", Q.OnLoaded)

ns.RegisterSettings{ key = "quests", label = "Quests", order = 48, items = {
    { key = "quests.enabled", type = "toggle", label = L["Quest-Seite"], default = true,
      tip = L["Alle Quests der Welt mit Status, Reihen, Belohnungen und Wegpunkt. Aus: die Questdaten werden beim nächsten Einloggen oder /reload nicht mehr geladen und belegen keinen Speicher."],
      onChange = function(v)
          if not v then index, indexData, listKey = nil, nil, nil end
          bump()
      end },
} }

-- The page's window state: settings.questsPage (search, zone, show, chains, upgrades, mine,
-- collapsed, expanded). Until 2.5 it shared settings.quests with the switch quests.enabled; the
-- first call moves it out once, the switch stays.
function Q.PageState()
    local s = AmisiaDB.settings
    if type(s.questsPage) ~= "table" then
        local p = {}
        local old = s.quests
        if type(old) == "table" then
            for k, v in pairs(old) do
                if k ~= "enabled" then
                    p[k] = v
                    old[k] = nil
                end
            end
        end
        s.questsPage = p
    end
    return s.questsPage
end

-- A text for why there is no list: nil when there is one.
function Q.WhyText(why)
    if why == "off" then return L["Die Quest-Seite ist aus (Einstellungen, Quests)."] end
    if why == "reload" then return L["Die Questdaten werden nach /reload geladen."] end
    if why == "nodata" then return L["Für diesen Client gibt es keine Questdaten."] end
    return nil
end

ns.RegisterSlash("quests", { aliases = { "quest" }, args = L["[suche]"], desc = L["Quest-Tracker: alle Quests mit Status und Wegpunkt"],
    run = function(rest)
        if not enabled() then
            ns.msg(L["Die Quest-Seite ist aus. Einschalten: Einstellungen, Quests, Quest-Seite."])
            return
        end
        if AmisiaDB and AmisiaDB.settings then
            Q.PageState().search = (rest or ""):match("^%s*(.-)%s*$") or ""
        end
        if ns.ShowPage then ns.ShowPage("quests") end
    end })
