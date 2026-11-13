-- Amisia quest scan (/amisia scan quests, spec 2026-11-10-quest-und-npc-scan, D-104): asks the client
-- for every quest id of its own quest table (QuestV2, the list in Data/ScanLists.lua) and keeps the
-- title in the client's language, the difficulty level, the quest level where the client has one, the
-- type (Collect/QuestTags.lua's codes) and the suggested group; the objective lines of the quest
-- tooltip only where the probe (/amisia selbsttest daten) found that tooltip readable. Throttled
-- (tools.questRate per second, slower when answers time out), resumable (scan.quests.next), never in
-- combat or in an instance. It ends with one line when the first 50 ids all time out.
--
-- Where the probe found the quest log's reward functions answering by quest id (verdicts questReward,
-- questXP; spec addition 2026-11-10 "Belohnungen"), a line also holds the reward items with their
-- count, the choice items, the money and the XP (layout 2); without such a verdict the scan stays as it
-- was. A quest's XP fills AmisiaDB.questxp where it has none (Collect/QuestXP.lua). Five quests in a
-- row with the same items mean the client ignores the quest id: the run stops keeping rewards and takes
-- them out of those five lines.
--
-- AmisiaDB.scan.quests = { loc, next (index into the list), n, at, done, v (layout), list = { [questID] =
-- "title\tdifficulty level\tquest level\ttype\tgroup\tobjectives\trewards\tchoices\tmoney\txp" },
-- none = ranges of ids without an answer }; rewards "id" or "id*count" apart by ",", choices "id,id",
-- money in copper; empty fields at the end left out. tools/build_scan_archive.py keeps it in
-- tools/scan_archive.json (per language); Collect/ScanTrim.lua takes out what the archive holds.
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
QS.LAYOUT = 2         -- the layout of a saved line with rewards (see QS.DB, QS.Start)
QS.MAX_REWARDS = 10   -- reward and choice items read at most per quest
QS.SAME_MAX = 5       -- quests in a row with the same reward items: the client ignores the quest id

local running = false
local ticker
local pending, pendingCount = {}, 0
local credit = 0      -- fractional sends carried to the next tick
local rate            -- the rate now (the setting, lower after timeouts)
local first           -- { asked, answered } of the first QS.FIRST ids of this run
local timeouts = 0    -- in a row
local nextReport
local rewardsOn, xpOn -- the parts this run reads (the probe's verdicts at the start)
local same            -- { sig, ids } of the quests in a row with the same reward items
local pausedIn        -- the last run ended because the character entered an instance

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

-- A function of the quest log in either form: the global one, else C_QuestLog's (the client of
-- 2026-11-10 has some only in one of them), else C_QuestInfoSystem's.
function QS.Fn(name)
    local f = rawget(_G, name)
    if type(f) == "function" then return f end
    f = api(name)
    if f then return f end
    local Q = _G.C_QuestInfoSystem
    f = type(Q) == "table" and Q[name] or nil
    return type(f) == "function" and f or nil
end

local function count(v)
    v = tonumber(v)
    return v and v >= 1 and v % 1 == 0 and v or nil
end

-- The item of reward i of kind ("reward", "choice"): its id (the info's sixth value, else the link's)
-- and count; nil without an id.
local function rewardItem(kind, i, qid)
    local info = QS.Fn(kind == "choice" and "GetQuestLogChoiceInfo" or "GetQuestLogRewardInfo")
    local id, n
    if info then
        local ok, _, _, c, _, _, itemID = pcall(info, i, qid)
        if ok then id, n = count(ns.Plain(itemID)), count(ns.Plain(c)) end
    end
    if not id then
        local link = call(QS.Fn("GetQuestLogItemLink"), kind, i, qid)
        id = type(link) == "string" and count(ns.ItemID(link)) or nil
    end
    if id and id > 9999999 then id = nil end
    return id, n or 1
end

-- What the client says a loaded quest gives: { items = { { id, count } }, choices = { id }, money, xp }
-- (money and xp nil when 0 or unknown); nil when it has none of the functions.
function QS.Rewards(qid)
    local numR, numC = QS.Fn("GetNumQuestLogRewards"), QS.Fn("GetNumQuestLogChoices")
    local money, xp = QS.Fn("GetQuestLogRewardMoney"), QS.Fn("GetQuestLogRewardXP")
    if not (numR or numC or money or xp) then return nil end
    local out = { items = {}, choices = {} }
    for i = 1, math.min(tonumber(call(numR, qid)) or 0, QS.MAX_REWARDS) do
        local id, n = rewardItem("reward", i, qid)
        if id then out.items[#out.items + 1] = { id, n } end
    end
    for i = 1, math.min(tonumber(call(numC, qid, false)) or 0, QS.MAX_REWARDS) do
        local id = rewardItem("choice", i, qid)
        if id then out.choices[#out.choices + 1] = id end
    end
    out.money = count(call(money, qid))
    out.xp = count(call(xp, qid))
    return out
end

-- The reward items of r as one text for the same-items check ("" for none).
local function signature(r)
    local ids = {}
    for _, it in ipairs(r.items) do ids[#ids + 1] = it[1] end
    for _, id in ipairs(r.choices) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

-- The four reward fields of a line: rewards, choices, money, xp (as the parts this run reads allow).
local function rewardFields(r)
    local items, choices = {}, {}
    if rewardsOn then
        for _, it in ipairs(r.items) do items[#items + 1] = it[2] > 1 and (it[1] .. "*" .. it[2]) or tostring(it[1]) end
        for _, id in ipairs(r.choices) do choices[#choices + 1] = tostring(id) end
    end
    return table.concat(items, ","), table.concat(choices, ","), tostring(rewardsOn and r.money or ""),
        tostring(xpOn and r.xp or "")
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
    if q.v ~= nil and not ns.Int(q.v, 1, 99) then q.v = nil end
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
    text = SB.Cut(text, QS.MAX_OBJ)
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
    local r = (rewardsOn or xpOn) and QS.Rewards(qid) or nil
    if r then
        local a, b, c, d = rewardFields(r)
        fields[7], fields[8], fields[9], fields[10] = a, b, c, d
    end
    while fields[#fields] == "" or fields[#fields] == "0" do fields[#fields] = nil end
    return table.concat(fields, "\t"), r
end

-- A line without its reward fields (the first six).
local function withoutRewards(line)
    local parts, n = {}, 0
    for part in (line .. "\t"):gmatch("([^\t]*)\t") do
        n = n + 1
        if n <= 6 then parts[n] = part end
    end
    while #parts > 1 and (parts[#parts] == "" or parts[#parts] == "0") do parts[#parts] = nil end
    return table.concat(parts, "\t")
end
QS.WithoutRewards = withoutRewards

-- The same-items check: five quests in a row with the same reward items stop the rewards of this run
-- and take them out of those lines. The quest's XP fills the quest XP store where it has none.
local function checkRewards(qid, r)
    if not r then return end
    if xpOn and r.xp and ns.QuestXP and not ns.QuestXP.Get(qid) and ns.Get("collect.quests") then
        ns.QuestXP.Record(qid, r.xp)
    end
    if not rewardsOn then return end
    local sig = signature(r)
    if sig == "" then same = nil return end
    if same and same.sig == sig then
        same.ids[#same.ids + 1] = qid
    else
        same = { sig = sig, ids = { qid } }
    end
    if #same.ids >= QS.SAME_MAX then
        rewardsOn = false
        local q = QS.DB()
        for _, id in ipairs(same.ids) do
            if q.list[id] then q.list[id] = withoutRewards(q.list[id]) end
        end
        same = nil
        ns.msg(L["Der Client nennt für jede Quest dieselbe Belohnung: der Quest-Scan speichert in diesem Lauf keine Belohnungen mehr."])
    end
end

local function report(fmt, ...)
    ns.msg(fmt:format(...))
    if ns.Refresh then ns.Refresh() end
end

local function finish(why, how)
    running = false
    pausedIn = how == "instance" or nil
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
    if not q.list[qid] then
        q.n = q.n + 1
        if ns.ScanAdded then ns.ScanAdded() end
    end
    q.list[qid] = line
end

local function settle(qid, line, r)
    local p = pending[qid]
    if not p then return end
    pending[qid] = nil
    pendingCount = pendingCount - 1
    if line then
        stored(qid, line)
        checkRewards(qid, r)
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
        local line, r = QS.Read(qid)
        if line then
            settle(qid, line, r)
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
    if SB.Blocked(true) then finish(L["pausiert in der Instanz"], "instance") return end
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
    local line, r = QS.Read(qid)
    if line then
        settle(qid, line, r)
    elseif pending[qid].tries >= QS.TRIES then
        settle(qid, nil)
    end
    -- else: a placeholder title; the timeout asks again
end)

function QS.Running() return running end
-- Whether this run keeps rewards and XP (tests, the status line).
function QS.Parts() return rewardsOn and true or false, xpOn and true or false end

-- Starts or resumes the scan. Returns true, or nil and why.
function QS.Start()
    if running then return nil, L["Der Quest-Scan läuft schon. /amisia scan quests stop hält ihn an."] end
    if not api("RequestLoadQuestByID") or not api("GetTitleForQuestID") then return nil, L["Dieser Client kann keine Quests nachladen."] end
    local busy = SB.Busy() or (ns.ScanRunning and ns.ScanRunning() and "items")
    if busy then return nil, L["Erst den laufenden Scan anhalten (/amisia scan stop)."] end
    local why = SB.Blocked(true)
    if why then return nil, L["Der Quest-Scan läuft nicht %s."]:format(why) end
    local list = SB.List("Q")
    if not list or #list == 0 then return nil, L["Diese Version hat keine Liste der Quests."] end
    local q = QS.DB()
    local loc = SB.Locale()
    if q.loc and q.loc ~= loc and next(q.list) then
        return nil, L["Es warten noch %d Quests in %s auf den nächsten Datenbau; erst danach in einer anderen Sprache scannen."]:format(q.n, q.loc)
    end
    if q.loc ~= loc then q.next, q.none, q.done = 1, "", nil end
    q.loc = loc
    rewardsOn, xpOn, same = SB.Verdict("questReward") == "ok", SB.Verdict("questXP") == "ok", nil
    -- layout 2 (2.74.1): with rewards to read, what an older scan left is asked again
    if (rewardsOn or xpOn) and q.v ~= QS.LAYOUT then
        q.list, q.none, q.next, q.done, q.n = {}, "", 1, nil, 0
        q.v = QS.LAYOUT
    end
    if q.next > #list then q.next, q.done = 1, nil end
    pending, pendingCount, credit, timeouts = {}, 0, 0, 0
    rate = ns.Get("tools.questRate") or 20
    first = { asked = 0, answered = 0, start = q.next, none = q.none }
    nextReport = (math.floor(q.next / QS.REPORT_EVERY) + 1) * QS.REPORT_EVERY
    running, pausedIn = true, nil
    SB.SetBusy("quests")
    ticker = C_Timer.NewTicker(0.1, ns.Perf.Wrap("Ticker Scan quests", tick))
    ns.msg(L["Quest-Scan gestartet: %d von %d Quests offen, %d pro Sekunde, etwa %s. /amisia scan quests stop hält an."]:format(
        #list - q.next + 1, #list, rate, SB.Duration((#list - q.next + 1) / rate)))
    if ns.Refresh then ns.Refresh() end
    return true
end

function QS.Stop()
    if running then finish(L["angehalten"]) end
end

-- The progress for the tools page (F-186): { running, done, total (the quests of the list; nil
-- without it), seconds (left at the rate now), started (a run began and is not through), finished, n
-- (quests waiting in the file), pausedIn }.
function QS.Progress()
    local q = AmisiaDB and AmisiaDB.scan and type(AmisiaDB.scan.quests) == "table" and AmisiaDB.scan.quests or nil
    local list = SB.List("Q")
    local total = list and #list > 0 and #list or nil
    local nxt = q and tonumber(q.next) or 1
    local p = { running = running, pausedIn = pausedIn, finished = q and q.done ~= nil or false,
                n = q and (tonumber(q.n) or ns.Count(q.list or {})) or 0 }
    -- a run began (it set its time on the way out) and is not through: it resumes where it was
    p.started = (nxt > 1 or (q ~= nil and q.at ~= nil)) and not p.finished
    if total then
        p.total = total
        p.done = math.max(0, math.min(total, nxt - 1))
        local r = running and rate or (ns.Get("tools.questRate") or 20)
        p.seconds = (total - p.done) / math.max(r or 1, 0.1)
    end
    return p
end

-- One line of progress (chat).
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
