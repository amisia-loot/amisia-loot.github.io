-- Amisia quest scan (/amisia scan quests, spec 2026-11-10-quest-und-npc-scan, D-104): asks the client
-- for every quest id of its own quest table (QuestV2, the list in Data/ScanLists.lua) and keeps the
-- title in the client's language, the difficulty level, the quest level where the client has one, the
-- type (Collect/QuestTags.lua's codes) and the suggested group; the objective lines of the quest
-- tooltip only where the probe (/amisia selbsttest daten) found that tooltip readable. Throttled
-- (tools.questRate per second, slower when answers time out), resumable (scan.quests.next), never in
-- combat or in an instance. It ends with one line when the first 50 ids all time out.
--
-- AmisiaDB.scan.quests = { loc, next (index into the list), n, at, done, list = { [questID] =
-- "title\tdifficulty level\tquest level\ttype\tgroup\tobjectives" }, none = ranges of ids without an
-- answer }. tools/build_scan_archive.py keeps it in tools/scan_archive.json (per language);
-- Collect/ScanTrim.lua takes out what the archive holds.
local ADDON, ns = ...
local L = ns.L
local SB = ns.ScanById

local QS = {}
ns.QuestScan = QS

QS.TIMEOUT = 4        -- seconds to wait for QUEST_DATA_LOAD_RESULT
QS.TRIES = 2          -- asks per id
QS.FIRST = 50         -- the first ids of a run: all of them timed out -> the client does not answer
QS.MAX_PENDING = 60
QS.REPORT_EVERY = 500
QS.MIN_RATE = 2
QS.MAX_OBJ = 200      -- bytes of objective text kept

local running = false
local ticker
local pending, pendingCount = {}, 0
local credit = 0      -- fractional sends carried to the next tick
local rate            -- the rate now (the setting, lower after timeouts)
local first           -- { asked, answered } of the first QS.FIRST ids of this run
local timeouts = 0    -- in a row
local nextReport

local function now() return GetTime() end

local function api(name)
    local Q = _G.C_QuestLog
    local f = type(Q) == "table" and Q[name] or nil
    return type(f) == "function" and f or nil
end

local function call(f, ...)
    if not f then return nil end
    local ok, a, b = pcall(f, ...)
    if not ok then return nil end
    return ns.Plain(a), ns.Plain(b)
end

-- AmisiaDB.scan.quests, made and checked.
function QS.DB()
    AmisiaDB.scan = AmisiaDB.scan or {}
    local s = AmisiaDB.scan
    local q = type(s.quests) == "table" and s.quests or {}
    if type(q.list) ~= "table" then q.list = {} end
    if type(q.none) ~= "string" then q.none = "" end
    if not ns.Int(q.next, 1) then q.next = 1 end
    if type(q.loc) ~= "string" then q.loc = nil end
    -- counted once; the scan keeps it up to date, the trim sets it again
    if not ns.Int(q.n, 0) then q.n = ns.Count(q.list) end
    s.quests = q
    return q
end

local function placeholder(title)
    return type(title) ~= "string" or title == "" or title:sub(1, 1) == "<"
end

-- The objective lines of the quest's tooltip (lines 2 on, joined), only when the probe found them.
local function objectives(qid)
    if SB.Verdict("questTip") ~= "ok" then return "" end
    local lines = SB.Lines(SB.QuestLink(qid))
    if type(lines) ~= "table" then return "" end
    local parts = {}
    for i = 2, #lines do
        if lines[i] ~= "" then parts[#parts + 1] = lines[i] end
    end
    local text = table.concat(parts, " / "):gsub("\t", " ")
    if #text > QS.MAX_OBJ then text = text:sub(1, QS.MAX_OBJ) end
    return text
end

-- The record of a quest the client has loaded, or nil (no title yet or a placeholder).
function QS.Read(qid)
    local title = SB.Clean(call(api("GetTitleForQuestID"), qid))
    if placeholder(title) then return nil end
    local diff = tonumber(call(api("GetQuestDifficultyLevel"), qid)) or 0
    local level = tonumber(call(api("GetQuestLevel"), qid)) or 0
    local tag
    local info = call(api("GetQuestTagInfo"), qid)
    if type(info) == "table" then tag = tonumber(ns.Plain(info.tagID)) end
    if not tag and type(_G.GetQuestTagInfo) == "function" then tag = tonumber((call(_G.GetQuestTagInfo, qid))) end
    local group = tonumber(call(api("GetSuggestedGroupSize"), qid)) or 0
    local code = ns.QuestTags and ns.QuestTags.Code(tag, group) or ""
    local fields = { title, tostring(math.floor(diff)), tostring(math.floor(level)), code or "", tostring(math.floor(group)), objectives(qid) }
    while fields[#fields] == "" or fields[#fields] == "0" do fields[#fields] = nil end
    return table.concat(fields, "\t")
end

local function report(fmt, ...)
    ns.msg(fmt:format(...))
    if ns.Refresh then ns.Refresh() end
end

local function finish(why)
    running = false
    if ticker then ticker:Cancel(); ticker = nil end
    local q = QS.DB()
    -- the ids still waiting are asked again on the next start
    for _, p in pairs(pending) do
        if p.index and p.index < q.next then q.next = p.index end
    end
    pending, pendingCount = {}, 0
    if SB.Busy() == "quests" then SB.SetBusy(nil) end
    q.at = time()
    if why then report(L["Quest-Scan %s: %d Quests gespeichert, %d von %d abgefragt."], why, q.n, q.next - 1, #(SB.List("Q") or {})) end
end

local function stored(qid, line)
    local q = QS.DB()
    if not q.list[qid] then q.n = q.n + 1 end
    q.list[qid] = line
end

local function settle(qid, line)
    local p = pending[qid]
    if not p then return end
    pending[qid] = nil
    pendingCount = pendingCount - 1
    if line then
        stored(qid, line)
        timeouts = 0
        if p.first then first.answered = first.answered + 1 end
        if rate < (ns.Get("tools.questRate") or 20) then rate = rate + 0.5 end
    else
        local q = QS.DB()
        q.none = SB.AddToRanges(q.none, qid)
    end
end

local function send(qid, tries, isFirst, index)
    pending[qid] = { at = now(), tries = tries, first = isFirst, index = index }
    local have = call(api("HaveQuestData"), qid)
    if have == true then
        local line = QS.Read(qid)
        if line then
            settle(qid, line)
            return true
        end
    end
    call(api("RequestLoadQuestByID"), qid)
    return false
end

local function tick()
    if not running then return end
    local why = SB.Blocked(false)
    if why then return end   -- combat or a lockdown: wait
    if SB.Blocked(true) then finish(L["pausiert in der Instanz"]) return end
    local list = SB.List("Q") or {}
    local q = QS.DB()
    local t = now()
    for qid, p in pairs(pending) do
        if t - p.at > QS.TIMEOUT then
            if p.tries < QS.TRIES then
                send(qid, p.tries + 1, p.first, p.index)
            else
                timeouts = timeouts + 1
                if timeouts >= 5 then
                    rate = math.max(QS.MIN_RATE, rate / 2)
                    timeouts = 0
                end
                settle(qid, nil)
            end
        end
    end
    -- the first ids of the run: none answered -> the client does not answer quest questions
    if first.asked >= QS.FIRST and first.answered == 0 and first.done == nil then
        local open = false
        for _, p in pairs(pending) do if p.first then open = true break end end
        if not open then
            first.done = true
            -- nothing of this run counts: the next start asks the same ids again
            q.next, q.none = first.start, first.none
            finish(nil)
            ns.msg(L["Der Client beantwortet Quest-Abfragen nicht: Quest-Scan beendet."])
            return
        end
    end
    credit = credit + rate / 10
    while credit >= 1 and pendingCount < QS.MAX_PENDING and q.next <= #list do
        local qid = list[q.next]
        q.next = q.next + 1
        credit = credit - 1
        local isFirst = first.asked < QS.FIRST
        if isFirst then first.asked = first.asked + 1 end
        if not pending[qid] then
            pendingCount = pendingCount + 1
            send(qid, 1, isFirst, q.next - 1)
        end
        if q.next > nextReport then
            nextReport = nextReport + QS.REPORT_EVERY
            ns.msg(QS.Status())
            if ns.Refresh then ns.Refresh() end
        end
    end
    if credit > 1 then credit = 1 end
    if q.next > #list and pendingCount == 0 then
        q.done = time()
        finish(L["fertig"])
    end
end

ns.OnEvent("QUEST_DATA_LOAD_RESULT", function(qid, success)
    qid = tonumber(ns.Plain(qid))
    if not running or not qid or not pending[qid] then return end
    if ns.Plain(success) == false then
        settle(qid, nil)
        return
    end
    local line = QS.Read(qid)
    if line then
        settle(qid, line)
    elseif pending[qid].tries >= QS.TRIES then
        settle(qid, nil)
    end
    -- else: a placeholder title; the timeout asks again
end)

function QS.Running() return running end

-- Starts or resumes the scan. Returns true, or nil and why.
function QS.Start()
    if running then return nil, L["Der Quest-Scan läuft schon. /amisia scan quests stop hält ihn an."] end
    if not api("RequestLoadQuestByID") or not api("GetTitleForQuestID") then return nil, L["Dieser Client kann keine Quests nachladen."] end
    local busy = SB.Busy() or (ns.ScanRunning and ns.ScanRunning() and "items")
    if busy then return nil, L["Erst den laufenden Scan anhalten (/amisia scan stop)."] end
    local why = SB.Blocked(true)
    if why then return nil, L["Der Quest-Scan läuft nicht %s."]:format(why) end
    local list = SB.List("Q")
    if not list or #list == 0 then return nil, L["Diese Version hat keine Liste der Quests (Data/ScanLists.lua)."] end
    local q = QS.DB()
    local loc = SB.Locale()
    if q.loc and q.loc ~= loc and next(q.list) then
        return nil, L["Es warten noch %d Quests in %s auf den nächsten Datenbau; erst danach in einer anderen Sprache scannen."]:format(q.n, q.loc)
    end
    if q.loc ~= loc then q.next, q.none, q.done = 1, "", nil end
    q.loc = loc
    if q.next > #list then q.next, q.done = 1, nil end
    pending, pendingCount, credit, timeouts = {}, 0, 0, 0
    rate = ns.Get("tools.questRate") or 20
    first = { asked = 0, answered = 0, start = q.next, none = q.none }
    nextReport = (math.floor(q.next / QS.REPORT_EVERY) + 1) * QS.REPORT_EVERY
    running = true
    SB.SetBusy("quests")
    ticker = C_Timer.NewTicker(0.1, tick)
    ns.msg(L["Quest-Scan gestartet: %d von %d Quests offen, %d pro Sekunde, etwa %s. /amisia scan quests stop hält an."]:format(
        #list - q.next + 1, #list, rate, SB.Duration((#list - q.next + 1) / rate)))
    if ns.Refresh then ns.Refresh() end
    return true
end

function QS.Stop()
    if running then finish(L["angehalten"]) end
end

-- One line of progress (chat, the tools page).
function QS.Status()
    local q = AmisiaDB and AmisiaDB.scan and type(AmisiaDB.scan.quests) == "table" and AmisiaDB.scan.quests or nil
    local list = SB.List("Q")
    local total = list and #list or 0
    if not q or not q.next then return L["Quest-Scan: noch nicht gelaufen (%d Quests im Client)."]:format(total) end
    local n = q.n or ns.Count(q.list or {})
    local left = math.max(0, total - q.next + 1)
    if running then
        return L["Quest-Scan läuft: %d von %d, %d Quests, noch etwa %s."]:format(q.next - 1, total, n, SB.Duration(left / math.max(rate or 1, 0.1)))
    end
    if q.done then return L["Quest-Scan fertig: %d Quests gespeichert."]:format(n) end
    return L["Quest-Scan angehalten: %d von %d, %d Quests gespeichert."]:format(q.next - 1, total, n)
end

-- /amisia scan quests [stop]
function QS.Command(rest)
    local word = (rest or ""):lower():match("^%s*(%S*)")
    if word == "stop" then
        QS.Stop()
    elseif word == "status" then
        ns.msg(QS.Status())
    else
        local ok, why = QS.Start()
        if not ok and why then ns.msg(why) end
    end
end
