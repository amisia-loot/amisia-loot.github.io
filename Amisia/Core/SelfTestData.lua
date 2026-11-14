-- /amisia selbsttest daten (en selftest data; spec 2026-11-10-quest-und-npc-scan, D-104): what THIS
-- client answers when Amisia asks for game data by id, before the quest and NPC scans rely on it.
-- NPC names by id through C_TooltipInfo.GetHyperlink and through a hidden tooltip of our own (never
-- GameTooltip) on "unit:Creature-0-0-0-0-<id>-0000000000", for NPCs this client has seen, classic
-- bosses of our data and new Forever bosses: at once, after 1 s, after 3 s or never, with the first
-- lines; ten asks in a row (refused or not). Quests by id: HaveQuestData, RequestLoadQuestByID with
-- QUEST_DATA_LOAD_RESULT, title, difficulty level, quest level, tag, the quest tooltip's lines. Quest
-- rewards by id: after the load result every reward function of the quest log in both forms (global,
-- C_QuestLog, C_QuestInfoSystem) with its values, every line of the quest tooltip and the tooltip data's
-- line types and ids, for a quest in the log, a completed one, dungeon quests, a new Forever one and one
-- whose reward item our data knows (the verdicts questReward, questXP). A model
-- frame of our own with SetCreature for a seen and an unseen creature (shown nowhere). Whether
-- vignettes, quests on the map, the dungeon journal and the flight map give anything. The report goes
-- into the self-test window and ends with a verdict per technique; the verdicts are kept in
-- AmisiaDB.probe (Collect/ScanById.lua) for the scans and the N100. Only reads, every call protected,
-- never in combat or an encounter lockdown; nothing goes to chat or other players.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local ST = ns.SelfTest
local K = ST.Kit
local add, show, fn, cut = K.add, K.show, K.fn, K.cut
local FEHLT = K.FEHLT

local DT = {}
ST.Data = DT

DT.NEW = { 258905, 258924, 260042 }   -- bosses of the Drowned City (new in Forever)
DT.QUEST_NEW = 95775                   -- "The Drowned City"
DT.QUEST_NONE = 9999990                -- no quest has this id
DT.TIMES = { 1, 3 }                    -- seconds of the second and third ask
DT.BURST = 10
DT.QUEST_WAIT = 4
DT.MODEL_WAIT = 2
DT.ALL_LINES = 30                      -- quest tooltip lines read for the rewards section
DT.REWARD_ROWS = 6                     -- reward and choice items listed per quest
-- the reward functions of the quest log, looked up global, in C_QuestLog and in C_QuestInfoSystem
DT.REWARD_FNS = { "GetNumQuestLogRewards", "GetQuestLogRewardInfo", "GetNumQuestLogChoices", "GetQuestLogChoiceInfo",
    "GetQuestLogItemLink", "GetQuestLogRewardMoney", "GetQuestLogRewardXP", "GetNumQuestLogRewardSpells",
    "GetQuestLogRewardSpell", "GetQuestRewardSpells", "GetQuestRewardCurrencies", "GetQuestRewardCurrencyInfo",
    "GetNumQuestLogRewardCurrencies", "GetQuestLogRewardCurrencyInfo" }
DT.FN_PLACES = { { "_G", "global" }, { "C_QuestLog", "C_QuestLog" }, { "C_QuestInfoSystem", "C_QuestInfoSystem" } }
local STALE = 30

local run

local function SB() return ns.ScanById end

local function linesText(lines)
    if type(lines) ~= "table" then return L["keine"] end
    local parts = {}
    for i = 1, math.min(#lines, 4) do parts[#parts + 1] = lines[i] end
    return #parts > 0 and ('"' .. table.concat(parts, '" | "') .. '"') or L["keine Zeilen"]
end

---------------------------------------------------------------------------
-- The NPCs to ask
---------------------------------------------------------------------------
-- Seen by this client: the trainers it opened (the newest first), then the vendors and mobs the collector
-- saw itself.
local function seenNpcs(max)
    local out, have = {}, {}
    local tr = AmisiaDB and type(AmisiaDB.trainers) == "table" and AmisiaDB.trainers or {}
    local list = {}
    for id, r in pairs(tr) do
        if type(id) == "number" and type(r) == "table" then list[#list + 1] = { id, tonumber(r.t) or 0 } end
    end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for _, e in ipairs(list) do
        if #out < max and not have[e[1]] then have[e[1]] = true; out[#out + 1] = e[1] end
    end
    local c = AmisiaDB and type(AmisiaDB.collect) == "table" and AmisiaDB.collect or {}
    for _, kind in ipairs({ "s", "w" }) do
        local ids = {}
        for id in pairs(type(c[kind]) == "table" and c[kind] or {}) do
            if type(id) == "number" then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            if #out < max and not have[id] and ns.CollectOwnName and ns.CollectOwnName(id) then have[id] = true; out[#out + 1] = id end
        end
    end
    return out
end

-- Classic bosses of our own data (the dungeon facts), the first boss of each dungeon below 100000.
local function classicNpcs(max, skip)
    local out = {}
    local F = ns.DUNGEON_FACTS
    for _, e in ipairs(type(F) == "table" and type(F.list) == "table" and F.list or {}) do
        for _, npc in ipairs(type(e.npcs) == "table" and e.npcs or {}) do
            if #out >= max then return out end
            if type(npc) == "number" and npc > 0 and npc < 100000 and not skip[npc] then
                skip[npc] = true
                out[#out + 1] = npc
                break
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Asking NPCs
---------------------------------------------------------------------------
local ROUTES = { "info", "tip" }

local function askNpc(P, e, when)
    for _, route in ipairs(ROUTES) do
        local r = e[route]
        if r.at == nil then
            local lines, why, secret = SB().Lines(SB().NpcLink(e.id), route)
            if why then r.why = why end
            if (tonumber(secret) or 0) > 0 then r.why = "secret" end
            local name = SB().NpcFrom(lines)
            if name then
                r.at, r.lines = when, lines
            elseif lines and #lines > 0 then
                r.first = r.first or lines
            end
        end
    end
end

local function npcSamples(P)
    local skip = {}
    for _, id in ipairs(DT.NEW) do skip[id] = true end
    local seen = seenNpcs(3)
    for _, id in ipairs(seen) do skip[id] = true end
    local classic = classicNpcs(4, skip)
    local out = {}
    for _, id in ipairs(seen) do out[#out + 1] = { id = id, kind = "seen", info = {}, tip = {} } end
    for _, id in ipairs(classic) do out[#out + 1] = { id = id, kind = "classic", info = {}, tip = {} } end
    for _, id in ipairs(DT.NEW) do out[#out + 1] = { id = id, kind = "new", info = {}, tip = {} } end
    P.npcs = out
    -- the burst: more classic bosses not asked yet
    P.burst = { ids = classicNpcs(DT.BURST, skip), now = 0, later = 0 }
end

-- When a sample got its name first (either route): 0, 1, 3 or nil.
local function firstAt(e)
    local a, b = e.info.at, e.tip.at
    if a and b then return math.min(a, b) end
    return a or b
end

local function verdictOf(list)
    local best
    for _, e in ipairs(list) do
        local at = firstAt(e)
        if at and (not best or at < best) then best = at end
    end
    if best == nil then return "none" end
    return best == 0 and "ok" or "retry"
end

local KIND = { seen = L["gesehen"], classic = L["Classic aus unseren Daten"], new = L["neu in Forever"] }

local function whenText(at)
    if at == nil then return L["nie"] end
    if at == 0 then return L["sofort"] end
    return L["nach %d s"]:format(at)
end

local function sectionNpcs(P)
    local R = P.R
    K.section(R, L["NPC-Namen per Nummer"])
    if #P.npcs == 0 then add(R, "WERT", L["NPCs"], L["keine zum Fragen"]) end
    for _, e in ipairs(P.npcs) do
        local own = ns.CollectOwnName and ns.CollectOwnName(e.id)
        for _, route in ipairs(ROUTES) do
            local r = e[route]
            local label = ("%d %s (%s)"):format(e.id, KIND[e.kind], route == "info" and "C_TooltipInfo" or L["eigener Tooltip"])
            if r.why == "missing" then
                add(R, "WERT", label, L["nicht vorhanden"])
            elseif r.why == "secret" and not r.at then
                add(R, "WERT", label, L["<geheim>"])
            else
                add(R, r.at and "OK" or "WERT", label, L["%s: %s"]:format(whenText(r.at), linesText(r.lines or r.first)))
            end
        end
        if own then add(R, "WERT", L["%d gesehen als"]:format(e.id), show(own)) end
    end
    local b = P.burst
    add(R, "WERT", L["%d hintereinander"]:format(#b.ids), L["%d sofort mit Namen, %d nach 1 s, %d ohne Namen"]:format(b.now, b.later, #b.ids - b.later))
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
local function questApi(name)
    local Q = _G.C_QuestLog
    local f = type(Q) == "table" and Q[name] or nil
    return type(f) == "function" and f or nil
end

local function pcallPlain(f, ...)
    if not f then return nil, "missing" end
    local ok, a, b, c = pcall(f, ...)
    if not ok then return nil, "error" end
    return ns.Plain(a), ns.Plain(b), ns.Plain(c)
end

local function logQuest()
    local n = pcallPlain(questApi("GetNumQuestLogEntries"))
    local getInfo = questApi("GetInfo")
    for i = 1, tonumber(n) or 0 do
        local info = pcallPlain(getInfo, i)
        if type(info) == "table" and not ns.Plain(info.isHeader) and tonumber(ns.Plain(info.questID)) then
            return tonumber(ns.Plain(info.questID))
        end
    end
    if type(_G.GetQuestLogTitle) == "function" then
        for i = 1, 40 do
            local ok, _, _, _, isHeader, _, _, _, qid = pcall(_G.GetQuestLogTitle, i)
            if not ok then break end
            if not ns.Plain(isHeader) and tonumber(ns.Plain(qid)) then return tonumber(ns.Plain(qid)) end
        end
    end
    return nil
end

local function questSamples(P)
    local out = {}
    local function addQ(id, kind) if id then out[#out + 1] = { id = id, kind = kind } end end
    addQ(logQuest(), L["im Questlog"])
    local d = ns.Data("DUNGEON_QUESTS")
    local ids = {}
    for qid in pairs(type(d) == "table" and type(d.Q) == "table" and d.Q or {}) do
        if type(qid) == "number" then ids[#ids + 1] = qid end
    end
    table.sort(ids)
    local done = questApi("IsQuestFlaggedCompleted")
    for _, qid in ipairs(ids) do
        local v = pcallPlain(done, qid)
        if v == true then addQ(qid, L["erledigt"]) break end
    end
    for i = 1, math.min(2, #ids) do addQ(ids[i], L["Dungeonquest aus unseren Daten"]) end
    addQ(DT.QUEST_NEW, L["neu in Forever"])
    -- a quest whose reward items our data knows, so the answer can be compared
    for _, qid in ipairs(ids) do
        local row = d.Q[qid]
        local gear = type(row) == "table" and row[12]
        if type(gear) == "table" and #gear > 0 and qid ~= ids[1] and qid ~= ids[2] then
            addQ(qid, L["mit bekannter Belohnung"])
            out[#out].known = gear
            break
        end
    end
    addQ(DT.QUEST_NONE, L["gibt es nicht"])
    P.quests = out
    P.questById = {}
    for _, q in ipairs(out) do
        P.questById[q.id] = q
        q.have = pcallPlain(questApi("HaveQuestData"), q.id)
        q.asked = P.clock()
        local _, why = pcallPlain(questApi("RequestLoadQuestByID"), q.id)
        q.askWhy = why
    end
end

local function readQuest(q)
    q.title = SB().Clean((pcallPlain(questApi("GetTitleForQuestID"), q.id)))
    q.diff = pcallPlain(questApi("GetQuestDifficultyLevel"), q.id)
    q.level = questApi("GetQuestLevel") and pcallPlain(questApi("GetQuestLevel"), q.id) or nil
    local info = pcallPlain(questApi("GetQuestTagInfo"), q.id)
    q.tag = type(info) == "table" and ns.Plain(info.tagID) or nil
    q.tagName = type(info) == "table" and ns.Plain(info.tagName) or nil
    q.group = questApi("GetSuggestedGroupSize") and pcallPlain(questApi("GetSuggestedGroupSize"), q.id) or nil
    q.haveNow = pcallPlain(questApi("HaveQuestData"), q.id)
    q.tips = {}
    for _, route in ipairs(ROUTES) do
        local lines, why, _, raw = SB().Lines(SB().QuestLink(q.id), route, DT.ALL_LINES)
        q.tips[route] = { lines = lines, why = why, raw = raw }
    end
    DT.ReadRewards(q)
end

local function sectionQuests(P)
    local R = P.R
    K.section(R, L["Quests per Nummer"])
    local fns = { "HaveQuestData", "RequestLoadQuestByID", "GetTitleForQuestID", "GetQuestDifficultyLevel", "GetQuestLevel",
                  "GetQuestTagInfo", "GetSuggestedGroupSize" }
    local lack = {}
    for _, name in ipairs(fns) do if not questApi(name) then lack[#lack + 1] = "C_QuestLog." .. name end end
    add(R, #lack == 0 and "OK" or "WERT", L["Funktionen"], #lack == 0 and L["alle vorhanden"] or L["fehlt: %s"]:format(table.concat(lack, ", ")))
    for _, q in ipairs(P.quests) do
        local label = ("%d %s"):format(q.id, q.kind)
        local result = q.result and L["QUEST_DATA_LOAD_RESULT %s nach %.1f s"]:format(show(q.result.success), q.result.after)
            or L["kein QUEST_DATA_LOAD_RESULT"]
        add(R, q.title and "OK" or "WERT", label, L["vorher geladen %s; %s; Titel %s, Schwierigkeit %s, Stufe %s, Tag %s %s, Gruppe %s"]:format(
            show(q.have), result, show(q.title), show(q.diff), show(q.level), show(q.tag), show(q.tagName), show(q.group)))
        for _, route in ipairs(ROUTES) do
            local t = q.tips and q.tips[route] or {}
            add(R, "WERT", L["%d Tooltip (%s)"]:format(q.id, route == "info" and "C_TooltipInfo" or L["eigener Tooltip"]),
                t.why == "missing" and L["nicht vorhanden"] or t.why == "secret" and L["<geheim>"]
                or L["%d Zeilen: %s"]:format(type(t.lines) == "table" and #t.lines or 0, linesText(t.lines)))
        end
    end
end

---------------------------------------------------------------------------
-- Models
---------------------------------------------------------------------------
local function modelStart(P)
    P.models = {}
    local seen = P.npcs[1] and P.npcs[1].kind ~= "new" and P.npcs[1].id or nil
    for _, e in ipairs({ { id = seen, kind = "seen" }, { id = DT.NEW[#DT.NEW], kind = "new" } }) do
        if e.id then
            local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
            if ok and m then
                if m.Hide then pcall(m.Hide, m) end
                e.frame = m
                e.set = type(m.SetCreature) == "function" and pcall(m.SetCreature, m, e.id) or false
            end
            P.models[#P.models + 1] = e
        end
    end
end

local function modelRead(P)
    for _, e in ipairs(P.models) do
        local m = e.frame
        if m then
            for _, getter in ipairs({ "GetModelFileID", "GetDisplayInfo" }) do
                if type(m[getter]) == "function" then
                    local ok, v = pcall(m[getter], m)
                    e[getter] = ok and ns.Plain(v) or nil
                end
            end
            if m.ClearModel then pcall(m.ClearModel, m) end
        end
    end
end

local function sectionModels(P)
    local R = P.R
    K.section(R, L["Modell per Nummer"])
    if #P.models == 0 then add(R, "WERT", "SetCreature", L["keine NPCs zum Prüfen"]) end
    for _, e in ipairs(P.models) do
        local label = ("SetCreature(%d) %s"):format(e.id, e.kind == "new" and L["neu in Forever"] or L["gesehen"])
        if not e.frame then
            add(R, FEHLT, label, L["kein PlayerModel"])
        elseif not e.set then
            add(R, "WERT", label, L["SetCreature fehlt oder wirft einen Fehler"])
        else
            add(R, ((tonumber(e.GetModelFileID) or 0) > 0 or (tonumber(e.GetDisplayInfo) or 0) > 0) and "OK" or "WERT", label,
                L["nach %d s: GetModelFileID %s, GetDisplayInfo %s"]:format(DT.MODEL_WAIT, show(e.GetModelFileID), show(e.GetDisplayInfo)))
        end
    end
end

---------------------------------------------------------------------------
-- Vignettes, quests on the map, the journal, the flight map
---------------------------------------------------------------------------
local function currentMap()
    local f = fn("C_Map.GetBestMapForUnit")
    if not f then return nil end
    local ok, id = pcall(f, "player")
    return ok and tonumber(ns.Plain(id)) or nil
end

local function sample(list)
    if type(list) ~= "table" then return show(list) end
    local first = list[1]
    if type(first) == "table" then
        local parts = {}
        for k, v in pairs(first) do
            if #parts < 6 and type(v) ~= "table" then parts[#parts + 1] = ("%s=%s"):format(tostring(k), show(v)) end
        end
        table.sort(parts)
        return L["%d Einträge, der erste: %s"]:format(#list, table.concat(parts, ", "))
    end
    return L["%d Einträge, der erste: %s"]:format(#list, show(first))
end

local function showTwo(v, w)
    return w ~= nil and (show(v) .. ", " .. show(ns.Plain(w))) or show(v)
end

-- One presence line: the verdict "ok" (data), "none" (there, but nothing), or nil (missing).
local function presence(R, label, path, ...)
    local f = fn(path)
    if not f then
        add(R, "WERT", label, L["%s fehlt"]:format(path))
        return nil
    end
    local ok, v, w = pcall(f, ...)
    if not ok then
        add(R, "WERT", label, L["Fehler: %s"]:format(cut(tostring(v))))
        return "none"
    end
    v = ns.Plain(v)
    local has = (type(v) == "table" and #v > 0) or (type(v) == "number" and v > 0)
    add(R, has and "OK" or "WERT", label, type(v) == "table" and sample(v) or showTwo(v, w))
    return has and "ok" or "none"
end

local function taxiOpen()
    for _, name in ipairs({ "FlightMapFrame", "TaxiFrame" }) do
        local f = rawget(_G, name)
        if type(f) == "table" and type(f.IsShown) == "function" then
            local ok, shown = pcall(f.IsShown, f)
            if ok and shown then return true end
        end
    end
    return false
end

local function sectionPresence(P)
    local R = P.R
    K.section(R, L["Weitere Quellen"])
    local map = currentMap()
    add(R, "WERT", L["Karte jetzt"], show(map))
    P.v.vignette = presence(R, "C_VignetteInfo.GetVignettes", "C_VignetteInfo.GetVignettes")
    P.v.questMap = map and presence(R, ("C_QuestLog.GetQuestsOnMap(%d)"):format(map), "C_QuestLog.GetQuestsOnMap", map) or nil
    if map then presence(R, ("C_EncounterJournal.GetDungeonEntrancesForMap(%d)"):format(map), "C_EncounterJournal.GetDungeonEntrancesForMap", map) end
    local tiers = presence(R, "EJ_GetNumTiers", "EJ_GetNumTiers")
    local inst = presence(R, "EJ_GetInstanceByIndex(1, false)", "EJ_GetInstanceByIndex", 1, false)
    if tiers or inst then P.v.journal = (tiers == "ok" or inst == "ok") and "ok" or "none" end
    if taxiOpen() then
        P.v.taxi = presence(R, "C_TaxiMap.GetAllTaxiNodes", "C_TaxiMap.GetAllTaxiNodes", map or 0)
    else
        add(R, "WERT", "C_TaxiMap.GetAllTaxiNodes", fn("C_TaxiMap.GetAllTaxiNodes") and L["nicht offen (beim Flugmeister die Karte öffnen und neu prüfen)"] or L["fehlt"])
    end
end

---------------------------------------------------------------------------
-- Quest rewards by id
---------------------------------------------------------------------------
-- A reward function in one place ("global", "C_QuestLog", "C_QuestInfoSystem"), or nil.
local function fnAt(place, name)
    local t = place == "_G" and _G or rawget(_G, place)
    local f = type(t) == "table" and rawget(t, name) or nil
    return type(f) == "function" and f or nil
end

-- Where a reward function exists: "global, C_QuestLog" or nil.
local function fnPlaces(name)
    local out = {}
    for _, pl in ipairs(DT.FN_PLACES) do
        if fnAt(pl[1], name) then out[#out + 1] = pl[2] end
    end
    return #out > 0 and table.concat(out, ", ") or nil
end

-- Every value of a protected call as text ("nil" for none; an error as "Fehler: ...").
local function allValues(f, ...)
    if not f then return nil end
    local res = { pcall(f, ...) }
    if not res[1] then return L["Fehler: %s"]:format(cut(tostring(res[2]))), {} end
    local parts, vals = {}, {}
    for i = 2, math.max(2, #res) do
        local v = ns.Plain(res[i])
        vals[#vals + 1] = v
        parts[#parts + 1] = type(v) == "table" and sample(v) or show(v)
    end
    return table.concat(parts, ", "), vals
end

-- The first place's form of a function (the one the scan would use: QS.Fn).
local function firstFn(name)
    local QS = ns.QuestScan
    return QS and QS.Fn and QS.Fn(name) or fnAt("_G", name)
end

-- The number fields and argument fields of a tooltip data line as "type=0, id=1234, ..." (no texts).
local function lineFields(line)
    if type(line) ~= "table" then return show(line) end
    local parts = {}
    for k, v in pairs(line) do
        v = ns.Plain(v)
        if type(v) == "number" or type(v) == "boolean" then parts[#parts + 1] = ("%s=%s"):format(tostring(k), show(v)) end
    end
    local args = ns.Plain(line.args)
    if type(args) == "table" then
        for _, a in ipairs(args) do
            a = ns.Plain(a)
            if type(a) == "table" and a.field then
                local v = a.intVal or a.guidVal or a.boolVal or a.colorVal or a.stringVal
                parts[#parts + 1] = ("%s=%s"):format(tostring(a.field), type(v) == "string" and cut(v) or show(ns.Plain(v)))
            end
        end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or L["keine Zahlen"]
end

-- The item id of a value list of GetQuestLogRewardInfo/GetQuestLogChoiceInfo (the sixth) or of a link.
local function idOf(vals, link)
    local id = vals and tonumber(vals[6])
    if id and id > 0 then return id, "info" end
    id = type(link) == "string" and ns.ItemID(link) or nil
    if id then return id, "link" end
    return nil
end

-- Reads everything the reward functions say about q (after its load result) into q.rw.
function DT.ReadRewards(q)
    local rw = { rows = {}, ids = {}, via = {} }
    q.rw = rw
    local id = q.id
    rw.numR = { allValues(firstFn("GetNumQuestLogRewards"), id) }
    rw.numCt = { allValues(firstFn("GetNumQuestLogChoices"), id, true) }
    rw.numCf = { allValues(firstFn("GetNumQuestLogChoices"), id, false) }
    local function items(kind, num, infoName)
        local n = tonumber(num and num[2] and num[2][1]) or 0
        for i = 1, math.min(n, DT.REWARD_ROWS) do
            local text, vals = allValues(firstFn(infoName), i, id)
            local link = select(2, allValues(firstFn("GetQuestLogItemLink"), kind, i, id))
            link = link and link[1]
            local item, via = idOf(vals, link)
            if item then
                rw.ids[#rw.ids + 1] = item
                rw.via[via] = true
            end
            rw.rows[#rw.rows + 1] = { kind = kind, i = i, info = text, link = link, id = item }
        end
    end
    items("reward", rw.numR, "GetQuestLogRewardInfo")
    items("choice", rw.numCf[2] and tonumber(rw.numCf[2][1]) and rw.numCf or rw.numCt, "GetQuestLogChoiceInfo")
    rw.money = { allValues(firstFn("GetQuestLogRewardMoney"), id) }
    rw.xp = { allValues(firstFn("GetQuestLogRewardXP"), id) }
    rw.spells = { allValues(firstFn("GetNumQuestLogRewardSpells"), id) }
    rw.extra = {}
    for _, path in ipairs({ "C_QuestInfoSystem.GetQuestRewardSpells", "C_QuestInfoSystem.GetQuestRewardCurrencies",
                            "C_QuestLog.GetQuestRewardCurrencies", "C_QuestLog.GetQuestRewardCurrencyInfo" }) do
        local f = fn(path)
        if f then rw.extra[#rw.extra + 1] = { path, (allValues(f, id)) } end
    end
    table.sort(rw.ids)
    rw.sig = table.concat(rw.ids, ",")
    rw.xpValue = tonumber(rw.xp[2] and rw.xp[2][1]) or 0
end

local function sectionRewards(P)
    local R = P.R
    K.section(R, L["Questbelohnungen per Nummer"])
    for _, name in ipairs(DT.REWARD_FNS) do
        local at = fnPlaces(name)
        add(R, at and "OK" or "WERT", name, at or L["fehlt"])
    end
    for _, q in ipairs(P.quests) do
        local rw = q.rw
        if q.id ~= DT.QUEST_NONE and rw then
            local label = ("%d %s"):format(q.id, q.kind)
            add(R, "WERT", label, L["Belohnungen %s; Auswahl (mit Währungen) %s, (ohne) %s; Geld %s; EP %s; Zauber %s"]:format(
                rw.numR[1] or L["fehlt"], rw.numCt[1] or L["fehlt"], rw.numCf[1] or L["fehlt"], rw.money[1] or L["fehlt"],
                rw.xp[1] or L["fehlt"], rw.spells[1] or L["fehlt"]))
            for _, row in ipairs(rw.rows) do
                add(R, row.id and "OK" or "WERT", ("%d %s %d"):format(q.id, row.kind == "choice" and L["Auswahl"] or L["Belohnung"], row.i),
                    L["Info: %s; Link: %s; Item %s"]:format(row.info or L["fehlt"], show(row.link), show(row.id)))
            end
            for _, e in ipairs(rw.extra) do add(R, "WERT", ("%d %s"):format(q.id, e[1]), e[2] or "nil") end
            if q.known then
                local parts = {}
                for _, item in ipairs(q.known) do parts[#parts + 1] = tostring(item) end
                add(R, "WERT", L["%d laut unseren Daten"]:format(q.id), table.concat(parts, ", "))
            end
            for _, route in ipairs(ROUTES) do
                local t = q.tips and q.tips[route] or {}
                local name = route == "info" and "C_TooltipInfo" or L["eigener Tooltip"]
                for i, line in ipairs(type(t.lines) == "table" and t.lines or {}) do
                    add(R, "WERT", L["%d Zeile %d (%s)"]:format(q.id, i, name), line ~= "" and line or L["leer"])
                end
                for i, line in ipairs(type(t.raw) == "table" and t.raw or {}) do
                    if i > DT.ALL_LINES then break end
                    add(R, "WERT", L["%d Zeilendaten %d"]:format(q.id, i), lineFields(ns.Plain(line)))
                end
            end
        end
    end
end

-- The verdicts of the rewards: "ok" when the quest with a known reward names one of its items and no
-- other quest gave the same non-empty answer (the client then ignores the quest id); the XP "ok" when
-- a quest not in the log has XP different from the log quest's.
local function rewardVerdicts(P)
    local v = P.v
    local known, other, inLog
    for _, q in ipairs(P.quests) do
        if q.rw and q.id ~= DT.QUEST_NONE then
            if q.known then known = q end
            if q.kind == L["im Questlog"] then inLog = q end
        end
    end
    local sigs = {}
    for _, q in ipairs(P.quests) do
        local rw = q.rw
        if rw and rw.sig ~= "" then
            if sigs[rw.sig] and sigs[rw.sig] ~= q.id then other = true end
            sigs[rw.sig] = q.id
        end
    end
    if known and known.rw then
        local hit = false
        for _, item in ipairs(known.rw.ids) do
            for _, want in ipairs(known.known) do if item == want then hit = true end end
        end
        v.questReward = (hit and not other) and "ok" or "none"
        P.rewardVia = known.rw.via.info and "GetQuestLogRewardInfo" or (known.rw.via.link and "GetQuestLogItemLink") or nil
    end
    local xpSeen = false
    for _, q in ipairs(P.quests) do
        local rw = q.rw
        if rw and q ~= inLog and q.id ~= DT.QUEST_NONE and rw.xpValue > 0 and (not inLog or rw.xpValue ~= inLog.rw.xpValue) then
            xpSeen = true
        end
    end
    v.questXP = (xpSeen and firstFn("GetQuestLogRewardXP")) and "ok" or "none"
end

---------------------------------------------------------------------------
-- The verdicts
---------------------------------------------------------------------------
local VERDICT_TEXT = { ok = L["geht (sofort)"], retry = L["geht (nach einer Wartezeit)"], none = L["geht nicht"] }

local function verdicts(P)
    local old, new = {}, {}
    for _, e in ipairs(P.npcs) do
        if e.kind == "new" then new[#new + 1] = e else old[#old + 1] = e end
    end
    local v = P.v
    v.npc = #old > 0 and verdictOf(old) or nil
    v.npcNew = verdictOf(new)
    local info, tip = 0, 0
    for _, e in ipairs(P.npcs) do
        if e.info.at then info = info + 1 end
        if e.tip.at then tip = tip + 1 end
    end
    if info + tip > 0 then v.route = info >= tip and "info" or "tip" end
    v.burst = #P.burst.ids > 0 and (#P.burst.ids - P.burst.later) or nil
    local title, tipLines = false, false
    for _, q in ipairs(P.quests) do
        if q.id ~= DT.QUEST_NONE and q.title then title = true end
        for _, route in ipairs(ROUTES) do
            local t = q.tips and q.tips[route]
            if q.id ~= DT.QUEST_NONE and t and type(t.lines) == "table" and #t.lines >= 2 then tipLines = true end
        end
    end
    v.quest = title and "ok" or "none"
    v.questTip = tipLines and "ok" or "none"
    rewardVerdicts(P)
    local seenModel, newModel
    for _, e in ipairs(P.models) do
        -- the client of 2026-11-10 gives no file id but the display id, also for a creature never seen
        local okModel = (tonumber(e.GetModelFileID) or 0) > 0 or (tonumber(e.GetDisplayInfo) or 0) > 0
        if e.kind == "new" then newModel = okModel else seenModel = okModel end
    end
    if newModel ~= nil then v.model = newModel and "ok" or (seenModel and "retry" or "none") end
end

local function sectionVerdicts(P)
    local R, v = P.R, P.v
    K.section(R, L["Urteil"])
    local function line(label, key, extra)
        add(R, v[key] == "none" and "WERT" or "OK", label, (v[key] and VERDICT_TEXT[v[key]] or L["nicht geprüft"]) .. (extra or ""))
    end
    line(L["NPC per Nummer"], "npc", v.route and L[" (Weg: %s)"]:format(v.route == "info" and "C_TooltipInfo" or L["eigener Tooltip"]) or "")
    line(L["Neue Forever-NPCs per Nummer"], "npcNew")
    if v.burst then add(R, "WERT", L["Zehn hintereinander"], L["%d ohne Namen"]:format(v.burst)) end
    line(L["Quest per Nummer"], "quest")
    line(L["Quest-Tooltip (Ziele)"], "questTip")
    add(R, v.questReward == "ok" and "OK" or "WERT", L["Questbelohnungen per Nummer"], v.questReward == "ok"
        and L["geht (Funktion %s)"]:format(P.rewardVia or "?") or (v.questReward and L["geht nicht"] or L["nicht geprüft"]))
    line(L["Quest-EP per Nummer"], "questXP")
    if v.model then add(R, "WERT", L["Modell per Nummer"], v.model == "ok" and L["auch ungesehene"] or v.model == "retry" and L["nur gesehene"] or L["geht nicht"]) end
    for _, k in ipairs({ { "vignette", L["Vignetten"] }, { "questMap", L["Quests auf der Karte"] }, { "journal", L["Dungeonjournal"] }, { "taxi", L["Flugkarte"] } }) do
        if v[k[1]] then add(R, "WERT", k[2], v[k[1]] == "ok" and L["liefert Daten"] or L["leer"]) end
    end
end

local function summary(P)
    local v = P.v
    local function t(k) return v[k] and VERDICT_TEXT[v[k]] or L["nicht geprüft"] end
    return L["Datenprüfung: NPC per Nummer %s, neue Forever-NPCs %s, Quest per Nummer %s, Quest-Tooltip %s, Questbelohnungen %s. Bericht im Fenster; das Ergebnis ist gespeichert."]:format(
        t("npc"), t("npcNew"), t("quest"), t("questTip"), t("questReward"))
end

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------
local listen = K.listener(function(_, event, qid, success)
    local P = run
    if not P or event ~= "QUEST_DATA_LOAD_RESULT" then return end
    qid = tonumber(ns.Plain(qid))
    local q = qid and P.questById and P.questById[qid]
    if q and not q.result then q.result = { success = ns.Plain(success), after = P.clock() - q.asked } end
end, { "QUEST_DATA_LOAD_RESULT" })

local function stopped(P)
    local why = SB().Blocked(false)
    if why then
        P.aborted = why
        return true
    end
    return false
end

local function finish(P)
    if P.finished then return end
    P.finished = true
    listen(false)
    if run == P then run = nil end
    local R = P.R
    if P.aborted then
        add(R, "WERT", L["Abgebrochen"], L["%s: außerhalb des Kampfes neu prüfen"]:format(P.aborted))
    end
    for _, body in ipairs({ sectionNpcs, sectionQuests, sectionRewards, sectionModels, sectionPresence }) do
        local ok, err = pcall(body, P)
        if not ok then add(R, "FEHLER", L["Abschnitt"], cut(tostring(err))) end
    end
    local ok, err = pcall(verdicts, P)
    if not ok then add(R, "FEHLER", L["Urteil"], cut(tostring(err))) end
    ok, err = pcall(sectionVerdicts, P)
    if not ok then add(R, "FEHLER", L["Urteil"], cut(tostring(err))) end
    if not P.aborted then
        local fields = {}
        for k, val in pairs(P.v) do fields[k] = val end
        SB().SaveProbe(fields, "probe")
    end
    R = K.finish(R, L["Amisia-Datenprüfung %s | Client %s | %s"])
    DT.last = R
    ST.ShowText(R.text, function() DT.Start() end)
    ns.msg(P.aborted and L["Datenprüfung abgebrochen (%s); nichts gespeichert."]:format(P.aborted) or summary(P))
end

-- The steps after the start, each with its delay from the start.
local function plan(P)
    local start = P.clock()
    local function at(seconds, f)
        C_Timer.After(math.max(0, seconds - (P.clock() - start)), function()
            if P.finished then return end
            if stopped(P) then finish(P) return end
            local ok, err = pcall(f)
            if not ok then
                add(P.R, "FEHLER", L["Ablauf"], cut(tostring(err)))
                finish(P)
            end
        end)
    end
    for _, t in ipairs(DT.TIMES) do
        at(t, function() for _, e in ipairs(P.npcs) do askNpc(P, e, t) end end)
    end
    at(DT.MODEL_WAIT, function() modelRead(P) end)
    -- ten in a row after the samples: names at once, then after 1 s
    local b = P.burst
    local route = SB().Route()
    at(DT.TIMES[#DT.TIMES] + 0.2, function()
        for _, id in ipairs(b.ids) do
            if SB().NpcFrom((SB().Lines(SB().NpcLink(id), route))) then b.now = b.now + 1 end
        end
    end)
    at(DT.TIMES[#DT.TIMES] + 1.2, function()
        for _, id in ipairs(b.ids) do
            if SB().NpcFrom((SB().Lines(SB().NpcLink(id), route))) then b.later = b.later + 1 end
        end
    end)
    at(math.max(DT.QUEST_WAIT, DT.TIMES[#DT.TIMES] + 1.3), function()
        for _, q in ipairs(P.quests) do readQuest(q) end
        finish(P)
    end)
end

function DT.Start()
    if not SB() then
        ns.msg(L["Die Datenprüfung gibt es nur in WoW Forever."])
        return
    end
    if run and not run.finished and GetTime() - run.at < STALE then
        ns.msg(L["Datenprüfung läuft schon."])
        return
    end
    local why = SB().Blocked(false)
    if why then
        ns.msg(L["Die Datenprüfung läuft nicht %s: danach neu starten."]:format(why))
        return
    end
    local P = { R = K.newReport(), at = GetTime(), v = {}, clock = GetTime }
    run = P
    listen(true)
    local R = P.R
    K.section(R, "Client")
    add(R, "WERT", L["Sprache, Build"], ("%s, %s"):format(SB().Locale(), SB().Build()))
    add(R, "WERT", "C_TooltipInfo.GetHyperlink", fn("C_TooltipInfo.GetHyperlink") and L["da"] or L["fehlt"])
    local steps = {
        function() npcSamples(P); for _, e in ipairs(P.npcs) do askNpc(P, e, 0) end end,
        function() questSamples(P) end,
        function() modelStart(P) end,
    }
    for _, f in ipairs(steps) do
        local ok, err = pcall(f)
        if not ok then add(R, "FEHLER", L["Ablauf"], cut(tostring(err))) end
    end
    P.npcs, P.quests, P.models = P.npcs or {}, P.quests or {}, P.models or {}
    P.burst = P.burst or { ids = {}, now = 0, later = 0 }
    ns.msg(L["Datenprüfung läuft (etwa %d s) ..."]:format(math.ceil(math.max(DT.QUEST_WAIT, DT.TIMES[#DT.TIMES] + 1.3))))
    plan(P)
end
end)
