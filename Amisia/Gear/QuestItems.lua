-- Quest items to clear away (F-173, D-105, spec docs/specs/2026-11-10-questgegenstaende.md): which quest
-- items in the bags (item class Quest, or the client's quest mark on the bag slot; never equipment, keys
-- or another class) are no longer needed, in three groups of certainty:
--   safe ("sicher überflüssig"): the item starts a quest (the client's quest mark of the bag slot, or the
--     client table by Data/QuestItemData.lua kind S) that this character has completed, or Amisia saw on
--     this account that the item belongs to a quest (required at its turn-in, or an item objective of it
--     in the quest log matched to the bag item) that is completed; and no other known quest that is not
--     completed uses it. Only these can be deleted, one stack per click.
--   likely ("wahrscheinlich überflüssig"): every quest the data links (AllTheThings, or the author's own
--     links in the data file) is completed or not one the character can get (faction, class, race of
--     Data/QuestData.lua).
--   unclear ("unklar"): no quest known, or a linked quest neither completed nor in the log.
-- Not offered at all ("wird gebraucht"): a linked quest is in the log, or the item starts a quest the
-- character has not done. A repeatable quest never counts as completed; completion is only the client's
-- flag, read once the client has answered (the first QUEST_LOG_UPDATE of the session). Nothing is sent;
-- heard data cannot make a link sure (there is none: the links are this client's or the data's).
--
-- Deleting (QI.Delete) runs only inside a click: never in combat or the lockdown, never while the cursor
-- holds something or a bank, mail, merchant, trade or guild bank window is open; the bag slot that holds
-- the item now is picked up, the cursor must hold exactly that item (GetCursorInfo), then
-- DeleteCursorItem; anything unexpected clears the cursor and says one line. A refusal of the client
-- (ADDON_ACTION_FORBIDDEN / ADDON_ACTION_BLOCKED naming Amisia during the delete) turns deleting off for
-- the session. The bag update must show the stack gone (QI.pending), else the chat says so.
--
-- AmisiaDB.questItems = { v = 1, links = { [item] = "q1,q2" }, keep = { [item] = true } }: the own links
-- (tools/build_questitems.py joins them into tools/quest_item_archive.json and the data as kind O) and the
-- items marked "Behalten".
local ADDON, ns = ...
local L = ns.L

local QI = {}
ns.QuestItems = QI

local MAX_ID = 9999999
local MAX_LINKS, MAX_KEEP, MAX_QUESTS = 2000, 500, 8
local QUEST_CLASS, KEY_CLASS = 12, 13
local NOT_CLASSES = { [2] = true, [4] = true, [KEY_CLASS] = true }   -- weapons, armour, keys
local LOG_GAP = 2        -- seconds between two reads of the quest log's objectives
local VERIFY = 3         -- seconds the bag update may take after a deletion
local LATE = 1           -- a refusal this many seconds after the delete counts for it
-- the windows during which nothing is deleted (bags may be part of another window's flow)
local BUSY_FRAMES = { "BankFrame", "MailFrame", "MerchantFrame", "TradeFrame", "GuildBankFrame" }
QI.MAX_LINKS, QI.MAX_KEEP, QI.MAX_QUESTS, QI.VERIFY = MAX_LINKS, MAX_KEEP, MAX_QUESTS, VERIFY
QI.GROUPS = { "safe", "likely", "unclear" }

local int = ns.Int
local report = ns.ReportError
local function plain(v) return ns.Plain(v) end

---------------------------------------------------------------------------
-- The saved key
---------------------------------------------------------------------------

local function cleanList(s)
    if type(s) ~= "string" or not s:match("^%d+[,%d]*$") or s:find(",,", 1, true) or s:sub(-1) == "," then return nil end
    local seen, out = {}, {}
    for d in s:gmatch("[^,]+") do
        local q = tonumber(d)
        if not int(q, 1, MAX_ID) then return nil end
        if not seen[q] then
            seen[q] = true
            out[#out + 1] = q
        end
    end
    if #out == 0 then return nil end
    table.sort(out)
    while #out > MAX_QUESTS do table.remove(out) end
    return table.concat(out, ",")
end

-- Called on ADDON_LOADED: only whole item and quest ids, at most MAX_QUESTS quests per item, the
-- MAX_LINKS highest items with links and MAX_KEEP marks "Behalten" (true only).
function QI.Loaded(root)
    local q = type(root.questItems) == "table" and root.questItems or {}
    local links = type(q.links) == "table" and q.links or {}
    local keep = type(q.keep) == "table" and q.keep or {}
    local ids = {}
    for k, v in pairs(links) do
        local s = int(k, 1, MAX_ID) and cleanList(v) or nil
        links[k] = s
        if s then ids[#ids + 1] = k end
    end
    if #ids > MAX_LINKS then
        table.sort(ids)
        for i = 1, #ids - MAX_LINKS do links[ids[i]] = nil end
    end
    local kept = {}
    for k, v in pairs(keep) do
        if int(k, 1, MAX_ID) and v == true then kept[#kept + 1] = k else keep[k] = nil end
    end
    if #kept > MAX_KEEP then
        table.sort(kept)
        for i = 1, #kept - MAX_KEEP do keep[kept[i]] = nil end
    end
    root.questItems = { v = 1, links = links, keep = keep }
    return root.questItems
end

local function db()
    if not AmisiaDB then return nil end
    local q = AmisiaDB.questItems
    if type(q) ~= "table" or type(q.links) ~= "table" or type(q.keep) ~= "table" then q = QI.Loaded(AmisiaDB) end
    return q
end

local gen = 0
local function changed()
    gen = gen + 1
    ns.Fire("QUEST_ITEMS")
end
QI.Changed = changed

-- Keeps that this account saw item belong to quest (an own link).
function QI.Learn(item, quest)
    local d = db()
    if not d or not int(item, 1, MAX_ID) or not int(quest, 1, MAX_ID) then return false end
    local have = d.links[item]
    for x in (have or ""):gmatch("%d+") do
        if tonumber(x) == quest then return false end
    end
    local s = cleanList(have and (have .. "," .. quest) or tostring(quest))
    if not s then return false end
    if not have then
        local n = 0
        for _ in pairs(d.links) do n = n + 1 end
        if n >= MAX_LINKS then return false end
    end
    d.links[item] = s
    changed()
    return true
end

function QI.Kept(item)
    local d = db()
    return d ~= nil and d.keep[item] == true
end

-- "Behalten" (on true) or "Nicht mehr behalten".
function QI.SetKeep(item, on)
    local d = db()
    if not d or not int(item, 1, MAX_ID) then return false end
    if on then
        local n = 0
        for _ in pairs(d.keep) do n = n + 1 end
        if not d.keep[item] and n >= MAX_KEEP then return false end
        d.keep[item] = true
    else
        d.keep[item] = nil
    end
    changed()
    return true
end

---------------------------------------------------------------------------
-- What the client says
---------------------------------------------------------------------------

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f
end

-- The item's class and equip location (C_Item.GetItemInfoInstant needs no cache).
local function classOf(id)
    local api = _G.C_Item
    local _, _, _, loc, _, class = call(api and api.GetItemInfoInstant, id)
    return tonumber(plain(class)), plain(loc)
end

local function wearable(loc) return type(loc) == "string" and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP" and loc ~= "INVTYPE_NON_EQUIP_IGNORE" end

-- Whether Amisia looks at an item at all: the item class Quest, or the bag slot's quest mark on an item
-- that is no weapon, armour, key or anything worn.
function QI.IsQuestItem(id, questMark)
    local class, loc = classOf(id)
    if class == QUEST_CLASS then return true end
    if not questMark or class == nil or NOT_CLASSES[class] or wearable(loc) then return false end
    return true
end

-- The quest mark of a bag slot (C_Container's table): isQuestItem, the quest the item starts (or nil),
-- whether that quest is in the log. Without the function: no mark.
local function questMarkAt(bag, slot)
    local api = _G.C_Container
    local info = call(api and api.GetContainerItemQuestInfo, bag, slot)
    if type(info) ~= "table" then return false, nil, false end
    local q = tonumber(plain(info.questID))
    return plain(info.isQuestItem) == true, int(q, 1, MAX_ID) and q or nil, plain(info.isActive) == true
end

local function slotInfo(bag, slot)
    local api = _G.C_Container
    local info = call(api and api.GetContainerItemInfo, bag, slot)
    return type(info) == "table" and info or nil
end

-- Every bag slot (0 to NUM_BAG_SLOTS: the bags, never the bank): bag, slot, item id or nil.
local function eachSlot()
    local api = _G.C_Container
    local last, bag, slot, n = tonumber(_G.NUM_BAG_SLOTS) or 4, 0, 0, nil
    return function()
        if not (api and api.GetContainerNumSlots and api.GetContainerItemID) then return nil end
        while bag <= last do
            n = n or tonumber(plain(call(api.GetContainerNumSlots, bag))) or 0
            slot = slot + 1
            if slot <= n then return bag, slot, tonumber(plain(call(api.GetContainerItemID, bag, slot))) end
            bag, slot, n = bag + 1, 0, nil
        end
    end
end
QI.EachSlot = eachSlot

-- The stack size of a bag slot: a positive whole number (an item with charges may tell a negative
-- count on old clients; nothing or a secret value counts 1).
local function countAt(bag, slot)
    local info = slotInfo(bag, slot)
    local n = info and tonumber(plain(info.stackCount)) or 1
    n = math.abs(math.floor(n))
    return n > 0 and n or 1
end

-- The quest items in the bags: a list (by item id) of { id, count, stacks = { { bag, slot, count,
-- locked } }, start = the quest the client says it starts, startActive, link }.
function QI.BagItems()
    local byId, list = {}, {}
    for bag, slot, id in eachSlot() do
        if int(id, 1, MAX_ID) then
            local mark, start, active = questMarkAt(bag, slot)
            if QI.IsQuestItem(id, mark) then
                local e = byId[id]
                if not e then
                    e = { id = id, count = 0, stacks = {} }
                    byId[id] = e
                    list[#list + 1] = e
                end
                local n = countAt(bag, slot)
                local info = slotInfo(bag, slot)
                e.count = e.count + n
                e.stacks[#e.stacks + 1] = { bag = bag, slot = slot, count = n, locked = info and plain(info.isLocked) == true or false }
                if start then e.start = start end
                if active then e.startActive = true end
                if not e.link then
                    local api = _G.C_Container
                    local link = plain(call(api and api.GetContainerItemLink, bag, slot))
                    if type(link) == "string" then e.link = link end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---------------------------------------------------------------------------
-- The quests
---------------------------------------------------------------------------

local ready = false     -- the client answered the quest log once this session (QUEST_LOG_UPDATE)
function QI.Ready() return ready end

local function isDone(q)
    local api = _G.C_QuestLog
    local done = call(api and api.IsQuestFlaggedCompleted, q)
    if done == nil and type(_G.IsQuestFlaggedCompleted) == "function" then done = call(_G.IsQuestFlaggedCompleted, q) end
    return plain(done) == true
end

local function inLog(q)
    local api = _G.C_QuestLog
    if api and type(api.IsOnQuest) == "function" then
        if plain(call(api.IsOnQuest, q)) == true then return true end
    end
    local i = api and tonumber(plain(call(api.GetLogIndexForQuestID, q)))
    if i and i > 0 then return true end
    i = tonumber(plain(call(_G.GetQuestLogIndexByID, q)))
    return i ~= nil and i > 0
end

-- The quest data's record (Gear/Quests.lua), when the quest page's data is on.
local function record(q)
    local Q = ns.Quests
    return Q and Q.Record and Q.Record(q) or nil
end

local function hasBit(mask, i) return math.floor(mask / 2 ^ (i - 1)) % 2 == 1 end

-- Whether the data says this character can never take quest q (faction, class, race).
local function notMine(q)
    local r = record(q)
    if not r then return false end
    local o = ns.QuestOpts and ns.QuestOpts() or {}
    if r.fac ~= "" and o.faction and r.fac ~= o.faction then return true end
    if (r.classes or 0) > 0 and o.class and ns.Gear and ns.Gear.HasClassBit and not ns.Gear.HasClassBit(r.classes, o.class) then return true end
    if (r.races or 0) > 0 and o.race and not hasBit(r.races, o.race) then return true end
    return false
end

-- The state of quest q for this character: "done", "log", "notmine" or "away" (neither done nor in the
-- log). A repeatable quest of the data is never done; before the client answered nothing is done.
function QI.QuestState(q)
    if inLog(q) then return "log" end
    local r = record(q)
    if ready and isDone(q) and not (r and r.repeatable) then return "done" end
    if notMine(q) then return "notmine" end
    return "away"
end

-- The name of a quest: the client's (its language, once it knows it), the quest scan's, the data's, else
-- "Quest <id>".
function QI.QuestName(q)
    local api = _G.C_QuestLog
    local t = plain(call(api and api.GetTitleForQuestID, q))
    if type(t) == "string" and t ~= "" then return t end
    t = ns.ScannedQuestTitle and ns.ScannedQuestTitle(q)
    if t then return t end
    local r = record(q)
    if r and r.name and r.name ~= "" then return r.name end
    return L["Quest %d"]:format(q)
end

---------------------------------------------------------------------------
-- The links of an item
---------------------------------------------------------------------------

-- { { q, kind = S/O/D, src = "client" (sure: the client's start quest), "own" (sure: this account
-- saw it), "data" } } of item id; start: the quest the bag slot's mark names.
function QI.Links(id, start)
    local out, seen = {}, {}
    local function add(q, kind, src)
        if not int(q, 1, MAX_ID) then return end
        local have = seen[q]
        if have then
            -- a sure source wins over the data
            if have.src == "data" and src ~= "data" then have.kind, have.src = kind, src end
            return
        end
        local e = { q = q, kind = kind, src = src }
        seen[q] = e
        out[#out + 1] = e
    end
    if start then add(start, "S", "client") end
    local d = db()
    for x in ((d and d.links[id]) or ""):gmatch("%d+") do add(tonumber(x), "O", "own") end
    local data = ns.Data("QUEST_ITEMS")
    local s = type(data) == "table" and type(data.I) == "table" and data.I[id]
    if type(s) == "string" then
        for kind, x in s:gmatch("([SOD])(%d+)") do
            -- S is the client table's start quest (sure); O of the file came from the author's
            -- account, not this one: it counts as data
            add(tonumber(x), kind, kind == "S" and "client" or "data")
        end
    end
    table.sort(out, function(a, b) return a.q < b.q end)
    return out
end

-- The group of a bag item e (QI.BagItems' entry, or { id } for the tooltip): group, reason key, the
-- quest the reason names, its state. Groups: "keep", "needed", "safe", "likely", "unclear". Reasons:
-- start, seen, data, notmine, away, none, wait, log, startopen.
function QI.Classify(e)
    local id = e.id
    if QI.Kept(id) then return "keep", "keep" end
    local links = QI.Links(id, e.start)
    for _, l in ipairs(links) do l.state = QI.QuestState(l.q) end
    for _, l in ipairs(links) do
        if l.state == "log" then return "needed", "log", l.q, l.state end
    end
    if e.startActive then return "needed", "log", e.start, "log" end
    if #links == 0 then return "unclear", "none" end
    -- before the client answered no quest counts as done: nothing is sure, a start item not needed yet
    if not ready then return "unclear", "wait", links[1].q, links[1].state end
    for _, l in ipairs(links) do
        if l.kind == "S" and l.src == "client" and l.state ~= "done" and l.state ~= "notmine" then
            return "needed", "startopen", l.q, l.state
        end
    end
    local sure, allDone, allSettled, open = nil, true, true, nil
    for _, l in ipairs(links) do
        if l.state == "done" then
            if l.src ~= "data" and (not sure or (l.kind == "S" and sure.kind ~= "S")) then sure = l end
        else
            allDone = false
            if l.state ~= "notmine" then
                allSettled = false
                open = open or l
            end
        end
    end
    if sure and allDone then return "safe", sure.kind == "S" and "start" or "seen", sure.q, "done" end
    if allSettled then
        local done
        for _, l in ipairs(links) do if l.state == "done" then done = done or l end end
        if done then return "likely", "data", done.q, "done" end
        return "likely", "notmine", links[1].q, "notmine"
    end
    return "unclear", "away", open.q, open.state
end

local STATE_TEXT = { done = L["abgeschlossen"], log = L["im Log"], away = L["nicht im Log"], notmine = L["nicht für dich"] }
QI.STATE_TEXT = STATE_TEXT

-- The reason in words.
function QI.ReasonText(reason, q)
    local name = q and QI.QuestName(q)
    if reason == "start" then return L["startet die Quest %s (abgeschlossen)"]:format(name) end
    if reason == "seen" then return L["war Ziel der Quest %s (abgeschlossen), von Amisia gesehen"]:format(name) end
    if reason == "data" then return L["laut Daten für %s (abgeschlossen)"]:format(name) end
    if reason == "notmine" then return L["laut Daten für %s (nicht für dich)"]:format(name) end
    if reason == "away" then return L["Quest %s nicht im Log"]:format(name) end
    if reason == "log" then return L["für %s (im Log)"]:format(name) end
    if reason == "startopen" then return L["startet die Quest %s (noch nicht gemacht)"]:format(name) end
    if reason == "wait" then return L["Das Spiel hat die abgeschlossenen Quests noch nicht gemeldet."] end
    if reason == "keep" then return L["Von dir behalten."] end
    return L["keine Quest bekannt"]
end

-- The bag's quest items by group: { safe = { e, ... }, likely, unclear, keep, needed = n }; each e with
-- group, reason, quest, state. nil and "combat" in combat or the lockdown (values may be secret).
function QI.Scan()
    if QI.Blocked() then return nil, "combat" end
    local out = { safe = {}, likely = {}, unclear = {}, keep = {}, needed = 0 }
    for _, e in ipairs(QI.BagItems()) do
        e.group, e.reason, e.quest, e.state = QI.Classify(e)
        if e.group == "needed" then
            out.needed = out.needed + 1
        else
            local g = out[e.group]
            g[#g + 1] = e
        end
    end
    return out
end

-- How many sure items wait (the page Quests' link): 0 in combat.
function QI.SafeCount()
    local s = QI.Scan()
    return s and #s.safe or 0
end

function QI.Blocked()
    if InCombatLockdown and InCombatLockdown() then return true end
    return ns.ChatLocked ~= nil and ns.ChatLocked()
end

---------------------------------------------------------------------------
-- Own links: the turn-in dialog and the quest log's item objectives
---------------------------------------------------------------------------

local function itemOf(link)
    link = plain(link)
    local id = type(link) == "string" and ns.ItemID(link) or nil
    return int(id, 1, MAX_ID) and id or nil
end

-- QUEST_PROGRESS: the items the quest asks for at its turn-in (only quest-class items).
function QI.OnProgress()
    local q = tonumber(plain(call(_G.GetQuestID)))
    if not int(q, 1, MAX_ID) then return end
    local n = tonumber(plain(call(_G.GetNumQuestItems))) or 0
    for i = 1, math.min(n, 12) do
        local id = itemOf(call(_G.GetQuestItemLink, "required", i))
        if not id then
            local api = _G.C_QuestOffer
            id = itemOf(call(api and api.GetQuestItemLink, "required", i))
        end
        if id and QI.IsQuestItem(id) then QI.Learn(id, q) end
    end
end

-- "Lurker Venom: 0/1", "0/1 Lurker Venom", "Lurker Venom: 1/1 (Complete)" -> "lurker venom"
local function objectiveName(text)
    text = plain(text)
    if type(text) ~= "string" then return nil end
    local s = text:gsub("%s*%(.-%)%s*$", "")
    s = s:match("^(.-)%s*:%s*%d+%s*/%s*%d+$") or s:match("^%d+%s*/%s*%d+%s+(.+)$") or s
    s = s:match("^%s*(.-)%s*$")
    return s ~= "" and s:lower() or nil
end
QI.ObjectiveName = objectiveName

-- The quests of the log with their item objectives: { { q, names = { lower name } } }.
local function logObjectives()
    local api = _G.C_QuestLog
    local out = {}
    if not (api and type(api.GetNumQuestLogEntries) == "function" and type(api.GetInfo) == "function"
        and type(api.GetQuestObjectives) == "function") then return out end
    local n = tonumber(plain(call(api.GetNumQuestLogEntries))) or 0
    for i = 1, math.min(n, 60) do
        local info = call(api.GetInfo, i)
        local q = type(info) == "table" and not plain(info.isHeader) and tonumber(plain(info.questID)) or nil
        if int(q, 1, MAX_ID) then
            local objs = call(api.GetQuestObjectives, q)
            local names = {}
            for _, o in ipairs(type(objs) == "table" and objs or {}) do
                if type(o) == "table" and plain(o.type) == "item" then
                    local nm = objectiveName(o.text)
                    if nm then names[#names + 1] = nm end
                end
            end
            if #names > 0 then out[#out + 1] = { q = q, names = names } end
        end
    end
    return out
end

-- Matches the log's item objectives to the quest items in the bags by name (one item of that name in
-- the bags, else none).
function QI.ReadLog()
    if QI.Blocked() then return 0 end
    local objs = logObjectives()
    if #objs == 0 then return 0 end
    local byName, twice = {}, {}
    for _, e in ipairs(QI.BagItems()) do
        local name = plain(call(_G.C_Item and C_Item.GetItemInfo, e.id))
        if type(name) ~= "string" and e.link then name = e.link:match("%[(.-)%]") end
        if type(name) == "string" and name ~= "" then
            local k = name:lower()
            if byName[k] and byName[k] ~= e.id then twice[k] = true end
            byName[k] = e.id
        end
    end
    local n = 0
    for _, o in ipairs(objs) do
        for _, nm in ipairs(o.names) do
            local id = not twice[nm] and byName[nm]
            if id and QI.Learn(id, o.q) then n = n + 1 end
        end
    end
    return n
end

local logDue = false
local function onLogUpdate()
    if not ready then
        ready = true
        changed()
    end
    if logDue then return end
    logDue = true
    C_Timer.After(LOG_GAP, function()
        logDue = false
        local ok, err = pcall(QI.ReadLog)
        if not ok then report(err) end
        changed()
    end)
end

---------------------------------------------------------------------------
-- Deleting
---------------------------------------------------------------------------

local refused = false        -- the client refused an addon's delete this session
local deleting               -- GetTime() of the last delete call
local during = false
QI.pending = nil             -- { id, bag, slot, count, at, name } the delete waiting for its bag update

function QI.Refused() return refused end

-- The client's delete functions as Amisia calls them (looked up when used).
local function pickupFn()
    local api = _G.C_Container
    if api and type(api.PickupContainerItem) == "function" then return api.PickupContainerItem end
    return type(_G.PickupContainerItem) == "function" and _G.PickupContainerItem or nil
end

function QI.CanDeleteAtAll()
    return not refused and pickupFn() ~= nil and type(_G.DeleteCursorItem) == "function" and type(_G.GetCursorInfo) == "function"
end

local function cursorBusy()
    if type(_G.GetCursorInfo) == "function" and call(_G.GetCursorInfo) ~= nil then return true end
    return type(_G.CursorHasItem) == "function" and plain(call(_G.CursorHasItem)) and true or false
end

local function busyWindow()
    for _, name in ipairs(BUSY_FRAMES) do
        local f = rawget(_G, name)
        if type(f) == "table" and f.IsShown and f:IsShown() then return true end
    end
    return false
end

local function clearCursor()
    if type(_G.ClearCursor) == "function" then pcall(_G.ClearCursor) end
end

local REFUSED_TEXT = L["Das Spiel lässt Addons keine Gegenstände löschen: zieh den Gegenstand selbst aus der Tasche und lass ihn fallen."]

local function setRefused()
    if refused then return end
    refused = true
    clearCursor()
    ns.msg(REFUSED_TEXT)
    changed()
end

-- Why nothing can be deleted now (a chat line), or nil.
function QI.WhyNot()
    if refused then return REFUSED_TEXT end
    if not QI.CanDeleteAtAll() then return L["Dieser Client bietet Addons kein Löschen an."] end
    if QI.Blocked() then return L["Im Kampf löscht Amisia nichts."] end
    if cursorBusy() then return L["Du hältst etwas mit der Maus: erst ablegen, dann noch einmal klicken."] end
    if busyWindow() then return L["Erst Bank, Briefkasten, Händler oder Handel schließen."] end
    if QI.pending then return L["Amisia wartet noch auf die Tasche."] end
    return nil
end

-- The bag entry of item id now (a fresh scan), classified.
local function fresh(id)
    for _, e in ipairs(QI.BagItems()) do
        if e.id == id then
            e.group, e.reason, e.quest, e.state = QI.Classify(e)
            return e
        end
    end
    return nil
end

local function itemName(id, e)
    local name = ns.ItemName(id)
    if name:match("^Item %d+$") and e and e.link then name = e.link:match("%[(.-)%]") or name end
    return name
end

-- Deletes one stack of item id: only a sure item, only inside a click. Returns true when the client was
-- asked to delete (the bag update says whether it did).
function QI.Delete(id)
    local why = QI.WhyNot()
    if why then
        ns.msg(why)
        return false
    end
    local e = fresh(id)
    if not e then
        ns.msg(L["Der Gegenstand liegt nicht mehr in den Taschen."])
        changed()
        return false
    end
    if e.group ~= "safe" then
        ns.msg(L["%s ist nicht mehr sicher überflüssig: nichts gelöscht."]:format(itemName(id, e)))
        changed()
        return false
    end
    local st
    for _, s in ipairs(e.stacks) do
        if not s.locked then st = s break end
    end
    if not st then
        ns.msg(L["Der Gegenstand ist gerade gesperrt: nichts gelöscht."])
        return false
    end
    during, deleting = true, GetTime()
    local ok = pcall(pickupFn(), st.bag, st.slot)
    local kind, cid = call(_G.GetCursorInfo)
    kind, cid = plain(kind), tonumber(plain(cid))
    if not ok or refused or kind ~= "item" or cid ~= id then
        during = false
        clearCursor()
        if not refused then ns.msg(L["Unerwartet: die Maus hält nicht %s. Nichts gelöscht."]:format(itemName(id, e))) end
        return false
    end
    ok = pcall(_G.DeleteCursorItem)
    during = false
    if not ok or refused then
        clearCursor()
        if not refused then ns.msg(L["Das Spiel hat %s nicht gelöscht."]:format(itemName(id, e))) end
        return false
    end
    if cursorBusy() then
        -- the client kept it on the cursor (a question of its own, a refusal without an event)
        clearCursor()
        ns.msg(L["Das Spiel hat %s nicht gelöscht."]:format(itemName(id, e)))
        return false
    end
    QI.pending = { id = id, bag = st.bag, slot = st.slot, count = st.count, at = GetTime(), name = itemName(id, e) }
    local p = QI.pending
    C_Timer.After(VERIFY, function() if QI.pending == p then QI.Verify(true) end end)
    changed()
    return true
end

-- The bag update after a delete: the stack gone -> one chat line; still there at the end of the wait ->
-- it says so. final: the wait is over.
function QI.Verify(final)
    local p = QI.pending
    if not p then return end
    local api = _G.C_Container
    local now = tonumber(plain(call(api and api.GetContainerItemID, p.bag, p.slot)))
    local gone = now ~= p.id or countAt(p.bag, p.slot) ~= p.count
    if gone then
        QI.pending = nil
        ns.msg(L["Gelöscht: %s x%d."]:format(p.name, p.count))
        changed()
    elseif final then
        QI.pending = nil
        ns.msg(L["%s liegt noch in der Tasche: das Spiel hat ihn nicht gelöscht."]:format(p.name))
        changed()
    end
end

-- The question before a delete (W.Confirm) unless quests.itemNoAsk; "Löschen" runs inside its click.
function QI.AskDelete(id)
    local why = QI.WhyNot()
    if why then
        ns.msg(why)
        return false
    end
    local e = fresh(id)
    if not e or e.group ~= "safe" then
        ns.msg(L["%s ist nicht mehr sicher überflüssig: nichts gelöscht."]:format(itemName(id, e)))
        changed()
        return false
    end
    if ns.Get("quests.itemNoAsk") then return QI.Delete(id) end
    local st = e.stacks[1]
    local text = L["%s x%d löschen?"]:format(itemName(id, e), st and st.count or e.count)
    if #e.stacks > 1 then text = text .. " " .. L["(1 von %d Stapeln)"]:format(#e.stacks) end
    text = text .. "\n" .. QI.ReasonText(e.reason, e.quest) .. "\n" .. L["Gelöschte Questgegenstände lassen sich nicht zurückholen."]
    ns.W.Confirm(L["Questgegenstand löschen"], text, L["Löschen##Questgegenstand"], function() QI.Delete(id) end)
    return true
end

-- The first sure item (the header button "Nächsten sicheren löschen").
function QI.NextSafe()
    local s = QI.Scan()
    local e = s and s.safe[1]
    return e and e.id or nil
end

function QI.DeleteNext()
    local id = QI.NextSafe()
    if not id then
        ns.msg(L["Kein sicher überflüssiger Questgegenstand in den Taschen."])
        return false
    end
    return QI.AskDelete(id)
end

-- The client refused a call of Amisia's while it deleted (or just after): no more deleting this session.
local function onRefused(who, what)
    if plain(who) ~= ADDON then return end
    what = plain(what)
    local named = type(what) == "string" and (what:find("DeleteCursorItem", 1, true) or what:find("PickupContainerItem", 1, true))
    if named or during or (deleting and GetTime() - deleting <= LATE) then setRefused() end
end
ns.OnEvent("ADDON_ACTION_FORBIDDEN", onRefused)
ns.OnEvent("ADDON_ACTION_BLOCKED", onRefused)

---------------------------------------------------------------------------
-- The item tooltip: one line for a quest item
---------------------------------------------------------------------------

local TIP_GREY = { 0.56, 0.53, 0.64 }
local TIP_GREEN, TIP_YELLOW = "|cff4fbf7a", "|cffffd100"

-- The tooltip line of item id, or nil: "Quest: Name (state)" and for the first two groups the hint.
function QI.TooltipLine(id)
    if not ns.Get("quests.itemTooltip") or not int(id, 1, MAX_ID) then return nil end
    local class = classOf(id)
    if class ~= QUEST_CLASS or QI.Blocked() then return nil end
    local links = QI.Links(id)
    if #links == 0 then return nil end
    local group, _, q, state = QI.Classify({ id = id })
    if group == "keep" then group, q = nil, nil end
    if not q then
        q = links[1].q
        state = QI.QuestState(q)
    end
    local line = L["Quest: %s (%s)"]:format(QI.QuestName(q), STATE_TEXT[state] or STATE_TEXT.away)
    if group == "safe" then
        line = line .. " · " .. TIP_GREEN .. L["wird nicht mehr gebraucht"] .. "|r"
    elseif group == "likely" then
        line = line .. " · " .. TIP_YELLOW .. L["wahrscheinlich nicht mehr gebraucht"] .. "|r"
    end
    return line
end

ns.OnItemTooltip("questitems", function(tip, _, id)
    local line = QI.TooltipLine(id)
    if not line then return false end
    tip:AddLine(line, TIP_GREY[1], TIP_GREY[2], TIP_GREY[3], true)
    return true
end)

---------------------------------------------------------------------------
-- Events and the command
---------------------------------------------------------------------------

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then report(err) end
    end
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then QI.Loaded(AmisiaDB) end
end)
ns.OnEvent("QUEST_PROGRESS", safe(QI.OnProgress))
ns.OnEvent("QUEST_LOG_UPDATE", safe(onLogUpdate))
ns.OnEvent("QUEST_TURNED_IN", safe(function()
    -- the client's flag can lag behind the event
    C_Timer.After(1, changed)
end))
ns.OnEvent("BAG_UPDATE_DELAYED", safe(function()
    if QI.pending then QI.Verify(false) end
    changed()
end))
ns.OnEvent("PLAYER_REGEN_DISABLED", safe(changed))
ns.OnEvent("PLAYER_REGEN_ENABLED", safe(changed))

ns.RegisterSlash("questgegenstaende", { en = "questitems", aliases = { "questitem" },
    desc = L["Questgegenstände aufräumen: welche du nicht mehr brauchst"], forever = true,
    run = function()
        if ns.QuestItemsWindow then ns.QuestItemsWindow.Toggle() end
    end })

-- The section "Questgegenstände" (D-123): the window's own entry in the settings, its two switches and the
-- window of an item that starts a quest. The keys stay under quests. (saved as before, nothing moves).
ns.RegisterSettings{ key = "questitems", label = L["Questgegenstände"], order = 54, group = "dungeons", pages = { "quests" }, items = {
    { key = "questitems.open", type = "button", label = L["Fenster \"Questgegenstände aufräumen\" öffnen"],
      tip = L["Welche Questgegenstände in deinen Taschen du nicht mehr brauchst. Auch mit /amisia questgegenstaende oder auf der Seite Quests oben rechts \"Aufräumen\"."],
      run = function() if ns.QuestItemsWindow then ns.QuestItemsWindow.Show() end end },
    -- F-173: the window and the tooltip line (this file, Gear/QuestItemsWindow.lua)
    { key = "quests.itemTooltip", type = "toggle", label = L["Questgegenstände im Tooltip"], default = true,
      tip = L["Im Tooltip eines Questgegenstands: zu welcher Quest er gehört, ob sie abgeschlossen ist und ob du ihn noch brauchst."] },
    { key = "quests.itemNoAsk", type = "toggle", label = L["Questgegenstände ohne Nachfrage löschen"], default = false,
      tip = L["Im Fenster \"Questgegenstände aufräumen\" löscht ein Klick auf \"Löschen\" einen sicher überflüssigen Stapel ohne Frage. Gelöschte Gegenstände lassen sich nicht zurückholen."] },
    -- F-181: the window of an item that starts a quest (Gear/QuestStart.lua, D-113)
    { key = "quests.startPopup", type = "toggle", label = L["Fenster bei Gegenständen, die eine Quest starten"], default = true,
      tip = L["Landet ein Gegenstand in deinen Taschen, der eine Quest startet, die du weder im Log noch abgeschlossen hast, zeigt ein kleines Fenster ihn; ein Klick auf sein Symbol startet die Quest. Nie im Kampf oder Bosskampf."],
      onChange = function(v) if ns.QuestStart then ns.QuestStart.SettingChanged(v) end end },
} }
