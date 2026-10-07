-- Amisia "Wer braucht das?": the loot lead asks while announcing, every raider client answers from
-- its own gear (ns.UpgradeOf) and wishlist whether an item is an upgrade, a wish or nothing for its
-- character. One question per item batch into the raid (UQ), one whispered answer per client and
-- question (UA). Questions count only from the elected loot lead with a verified officer rank,
-- answers only from guild members in the group. Answers are kept in memory for the current loot
-- (30 minutes) and shown to officers: the award dialog, the winner picker and a tooltip line.
-- Nothing of it ever goes into the raid chat.
local ADDON, ns = ...
local L = ns.L

local KEEP = 1800             -- seconds a question and its answers are kept
local REPEAT_GAP = 120        -- the same item list is asked at most this often
local MAX_ITEMS = 8
local UA_TEXT = 250           -- bytes of one answer message (Comm.lua's limit)
local ASK_TTL = 600           -- a question waits out a boss fight in the queue
local ANSWER_TTL = 600
local ANSWER_SPREAD = 2       -- an answer goes 0 to 2 s after the question
local ANSWERS_MAX, ANSWER_WINDOW = 10, 60   -- answers of this client per minute
local WER_WAIT = 5
local TIP_NAMES = 8
local MAX_GAIN = 99999
local LEAD_HELLO_FOR = 12 * 3600   -- a hello with "loot lead" counts for one raid night
local GREEN = { 0.3, 0.9, 0.45 }
local MASTER = (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2

local questions = {}          -- qid -> { items = { [id] = true }, at }: the own open questions
local needs = {}              -- id -> { qid, at, t, answers = { [lower name] = answer } }
local askedLists = {}         -- item list -> GetTime() of the last question
local answeredQ = {}          -- "lead:qid" -> GetTime(): questions this client answered
local answerTimes = {}

local function now() return GetTime() end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- Drops questions, answers and remembered lists older than 30 minutes.
local function sweep()
    local t = now()
    for qid, q in pairs(questions) do
        if t - q.at >= KEEP then questions[qid] = nil end
    end
    for id, n in pairs(needs) do
        if t - n.at >= KEEP then needs[id] = nil end
    end
    for key, at in pairs(askedLists) do
        if t - at >= REPEAT_GAP then askedLists[key] = nil end
    end
    for key, at in pairs(answeredQ) do
        if t - at >= KEEP then answeredQ[key] = nil end
    end
end

local function homeRaid()
    if _G.LE_PARTY_CATEGORY_HOME then return IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false end
    return IsInRaid() and true or false
end

-- A name from the net for display: no bars, no control characters.
local function clean(name)
    return (tostring(name or "?"):gsub("[%c|]", ""))
end

---------------------------------------------------------------------------
-- Who leads the loot, as this client sees it
---------------------------------------------------------------------------
local function masterLooter()
    local info = _G.C_PartyInfo
    if type(info) ~= "table" or type(info.GetLootMethod) ~= "function" then return nil end
    local ok, method, _, raidID = pcall(info.GetLootMethod)
    if not ok then return nil end
    method, raidID = ns.Plain(method), ns.Plain(raidID)
    if method ~= MASTER or not raidID then return nil end
    local name = ns.Plain((GetRaidRosterInfo(raidID)))
    return type(name) == "string" and ns.FullName(name) or nil
end

local function isLeader(name)
    local roster = ns.GroupRoster()
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.Plain((GetRaidRosterInfo(i)))
        if type(n) == "string" and ns.SameNameIn(n, name, roster) then
            return ns.Plain(UnitIsGroupLeader("raid" .. i)) == true
        end
    end
    return false
end

-- Whether name leads the loot: the keeper of the running raid, the master looter (else, without
-- master loot, the raid leader), or a verified officer whose last hello said loot lead ("Immer ich").
local function isLead(name)
    local keeper = ns.SyncKeeperName and ns.SyncKeeperName()
    if keeper and ns.SameName(keeper, name) then return true end
    local ml = masterLooter()
    if ml then
        if ns.SameName(ml, name) then return true end
    elseif isLeader(name) then
        return true
    end
    local d = AmisiaDB and type(AmisiaDB.sync) == "table" and AmisiaDB.sync.seen
    if type(d) == "table" then
        for seenName, e in pairs(d) do
            if type(e) == "table" and ns.SameName(seenName, name) and type(e.flags) == "string" and e.flags:find("L", 1, true)
                and time() - (tonumber(e.at) or 0) < LEAD_HELLO_FOR then
                return true
            end
        end
    end
    return false
end

local function shareOn()
    return ns.CommReady() and ns.Get("sync.shareUpgrades") ~= false
end

---------------------------------------------------------------------------
-- Asking
---------------------------------------------------------------------------
local function newQid()
    for _ = 1, 20 do
        local qid = ("%04x"):format(math.random(0, 65535))
        if not questions[qid] then return qid end
    end
    return ("%04x"):format(math.random(0, 65535))
end

-- Whether this client may ask at all: true, or false, the reason (for the screen) and a code.
local function canAsk()
    if not ns.CommReady() then return false, L["Addon-Nachrichten sind aus oder nicht verfügbar."], "off" end
    if not ns.IsOfficerView() or not ns.IsLootLead() then return false, L["Fragen kann nur die Lootleitung."], "lead" end
    if not homeRaid() then return false, L["Fragen nur in einer eigenen Raidgruppe."], "raid" end
    if not ns.SelfIsOfficer() then return false, L["Fragen nur mit Offiziersrang: die Raider antworten sonst nicht."], "rank" end
    return true
end

-- The checks of ns.NeedAsk without asking (for a button that shows only when asking works):
-- true, or false and the reason and its code.
function ns.NeedCanAsk()
    return canAsk()
end

-- Asks the raid who needs the items (ids or links, at most 8). Returns the question's number, or
-- nil, the reason (for the screen) and a code ("recent" for a list asked within 2 minutes).
function ns.NeedAsk(items)
    local can, why, code = canAsk()
    if not can then return nil, why, code end
    local ids, set = {}, {}
    for _, x in ipairs(type(items) == "table" and items or { items }) do
        local id = tonumber(x) or ns.ItemID(ns.Plain(x))
        if id and id >= 1 and id <= 999999 and id % 1 == 0 and not set[id] and #ids < MAX_ITEMS then
            set[id] = true
            ids[#ids + 1] = id
        end
    end
    if #ids == 0 then return nil, L["Kein Item."], "noitem" end
    sweep()
    local sorted = {}
    for i, id in ipairs(ids) do sorted[i] = id end
    table.sort(sorted)
    local key = table.concat(sorted, ",")
    if askedLists[key] then return nil, L["Diese Items wurden gerade erst gefragt."], "recent" end
    local qid = newQid()
    local ok, err = ns.CommSend("UQ", { qid, table.concat(ids, ",") }, "RAID", nil, { ttl = ASK_TTL, key = "UQ:" .. qid })
    if not ok then return nil, err, "send" end
    local t = now()
    askedLists[key] = t
    questions[qid] = { items = set, at = t }
    -- the answers of this loot start anew
    for _, id in ipairs(ids) do needs[id] = { qid = qid, at = t, t = time(), answers = {} } end
    ns.Fire("NEED", ids)
    return qid
end

---------------------------------------------------------------------------
-- Answering
---------------------------------------------------------------------------
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- One item as "id:art:gain:pct:slot": U upgrade, W wish (prio in the gain field), - nothing.
local function answerFor(id)
    local nothing = id .. ":-:0:0:-"
    local okOwned, owned = pcall(ns.BisOwned, id)
    if not okOwned or owned then return nothing end
    -- the one comparison with the worn gear (Bis.lua); an item for a later level is no upgrade yet
    local ok, u = pcall(ns.UpgradeOf, id)
    local slot = ok and type(u) == "table" and u.slotKey
    if type(slot) == "string" and slot:match("^[%w_]+$") and u.up then
        return ("%d:U:%d:%d:%s"):format(id, clamp(math.floor(u.gain + 0.5), 0, MAX_GAIN), clamp(u.pct or 999, 0, 999), slot)
    end
    local c = ns.BisChar()
    local w = c and type(c.wish) == "table" and c.wish[id]
    if type(w) == "table" then
        return ("%d:W:%d:0:-"):format(id, clamp(math.floor(tonumber(w.prio) or 2), 1, 3))
    end
    return nothing
end

local function answer(sender, name, qid, list)
    if not ns.Gear or not ns.Gear.Available() then return end
    local mark = name:lower() .. ":" .. qid
    if answeredQ[mark] then return end
    local t = now()
    local recent = {}
    for _, at in ipairs(answerTimes) do
        if t - at < ANSWER_WINDOW then recent[#recent + 1] = at end
    end
    answerTimes = recent
    if #answerTimes >= ANSWERS_MAX then return end
    local entries = {}
    for id in (list .. ","):gmatch("([^,]*),") do
        id = tonumber(id)
        if id then
            local ok, e = pcall(answerFor, id)
            if ok then entries[#entries + 1] = e else report(e) entries[#entries + 1] = id .. ":-:0:0:-" end
        end
    end
    if #entries == 0 then return end
    -- one message holds 250 bytes: the entries go in as many answers as they need
    local room = UA_TEXT - #("1UA\t" .. qid .. "\t")
    local chunks, cur = {}, nil
    for _, e in ipairs(entries) do
        if #e <= room then
            if cur and #cur + 1 + #e <= room then
                cur = cur .. "," .. e
            else
                if cur then chunks[#chunks + 1] = cur end
                cur = e
            end
        end
    end
    if cur then chunks[#chunks + 1] = cur end
    local sent = false
    for i, chunk in ipairs(chunks) do
        local ok = ns.CommSend("UA", { qid, chunk }, "WHISPER", sender,
            { jitter = ANSWER_SPREAD, ttl = ANSWER_TTL, key = "UA:" .. qid .. ":" .. i })
        sent = sent or ok == true
    end
    -- a refused answer is not marked: the next question of the lead gets one
    if not sent then return end
    answeredQ[mark] = t
    answerTimes[#answerTimes + 1] = t
end

ns.CommOn("UQ", function(sender, f, chan)
    if chan ~= "RAID" or not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local qid, list = f[1], f[2]
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not shareOn() or not ns.InMyGroup(name) or not isLead(name) then return end
        sweep()
        answer(sender, name, qid, list)
    end)
end)

---------------------------------------------------------------------------
-- Collecting
---------------------------------------------------------------------------
local function record(name, qid, list)
    local q = questions[qid]
    if not q then return end
    local low = name:lower()
    local changed = {}
    for entry in (list .. ","):gmatch("([^,]*),") do
        local id, art, gain, pct, slot = entry:match("^(%d+):([UW%-]):(%-?%d+):(%d+):([%w_%-]+)$")
        id = tonumber(id)
        local n = id and needs[id]
        if n and q.items[id] and n.qid == qid then
            local a = { name = clean(name), art = art }
            if art == "U" then
                a.gain, a.pct = clamp(tonumber(gain) or 0, 0, MAX_GAIN), clamp(tonumber(pct) or 0, 0, 999)
                a.slot = (ns.BIS_SLOT_NAME and ns.BIS_SLOT_NAME[slot]) and slot or nil
            elseif art == "W" then
                a.prio = clamp(tonumber(gain) or 2, 1, 3)
            end
            n.answers[low] = a
            changed[#changed + 1] = id
        end
    end
    if #changed > 0 then ns.Fire("NEED", changed) end
end

ns.CommOn("UA", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    sweep()
    if not questions[f[1]] then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local qid, list = f[1], f[2]
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        sweep()
        record(name, qid, list)
    end)
end)

---------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------
local function byPct(a, b)
    if a.pct ~= b.pct then return a.pct > b.pct end
    return a.name:lower() < b.name:lower()
end
local function byPrio(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.name:lower() < b.name:lower()
end

-- Raid members with Amisia (a hello this client accepted) but this client.
local function expected()
    local out = {}
    local d = AmisiaDB and type(AmisiaDB.sync) == "table" and AmisiaDB.sync.seen
    if type(d) ~= "table" then return out end
    local me = ns.UnitFullName("player")
    for name, e in pairs(d) do
        if type(name) == "string" and type(e) == "table" and (tonumber(e.p) or 0) >= 1 and not ns.SameName(name, me) and ns.InMyGroup(name) then
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- Who needs an item of the current loot: { up = { { name, gain, pct, slot } } (best first),
-- wish = { { name, prio } }, none = n (answered nothing), asked = n (clients expected to answer),
-- missing = n, without = { names without an answer }, at }; nil when it was not asked in the last
-- 30 minutes.
function ns.NeedOf(item)
    sweep()
    local id = tonumber(item) or ns.ItemID(item)
    local n = id and needs[id]
    if not n then return nil end
    local out = { up = {}, wish = {}, none = 0, asked = 0, missing = 0, without = {}, at = n.t }
    local answered = {}
    for _, a in pairs(n.answers) do
        answered[#answered + 1] = a.name
        if a.art == "U" then
            out.up[#out.up + 1] = { name = a.name, gain = a.gain, pct = a.pct, slot = a.slot }
        elseif a.art == "W" then
            out.wish[#out.wish + 1] = { name = a.name, prio = a.prio }
        else
            out.none = out.none + 1
        end
    end
    table.sort(out.up, byPct)
    table.sort(out.wish, byPrio)
    local count = #answered
    for _, name in ipairs(expected()) do
        local hit = false
        for _, a in ipairs(answered) do
            if ns.SameName(a, name) then hit = true break end
        end
        if not hit then
            out.without[#out.without + 1] = name
            count = count + 1
        end
    end
    out.missing = #out.without
    out.asked = count
    return out
end

-- the wish priorities as words (BIS_PRIO_TEXT's, in the client's language)
local PRIO_WORD = { [3] = L["hoch##Prio"], [2] = L["mittel##Prio"], [1] = L["niedrig##Prio"] }

local function upText(e)
    local slot = e.slot and ns.BIS_SLOT_NAME and ns.BIS_SLOT_NAME[e.slot]
    return ("%s +%d %%%s"):format(e.name, e.pct, slot and (" (" .. L[slot] .. ")") or "")
end

local function wishText(e)
    return L["%s Wunsch (%s)"]:format(e.name, PRIO_WORD[e.prio] or PRIO_WORD[2])
end

-- "Anna +12 % (Brust), Bob Wunsch (hoch) · 2 ohne Upgrade · 5 ohne Antwort", or nil when the item
-- was not asked in the last 30 minutes.
function ns.NeedText(item)
    local need = ns.NeedOf(item)
    if not need then return nil end
    local parts = {}
    for _, e in ipairs(need.up) do parts[#parts + 1] = upText(e) end
    for _, e in ipairs(need.wish) do parts[#parts + 1] = wishText(e) end
    local text
    if #parts > 0 then
        text = table.concat(parts, ", ")
    elseif need.none > 0 then
        text = L["niemand"]
    else
        text = L["noch keine Antworten"]
    end
    if need.none > 0 then text = text .. L[" · %d ohne Upgrade"]:format(need.none) end
    if need.missing > 0 then text = text .. L[" · %d ohne Antwort"]:format(need.missing) end
    return text
end

-- Every line for a tooltip: one per upgrade and wish, then the counts and who did not answer.
function ns.NeedLines(item)
    local need = ns.NeedOf(item)
    if not need then return nil end
    local out = {}
    for _, e in ipairs(need.up) do out[#out + 1] = upText(e) end
    for _, e in ipairs(need.wish) do out[#out + 1] = wishText(e) end
    if need.none > 0 then out[#out + 1] = L["%d ohne Upgrade"]:format(need.none) end
    if need.missing > 0 then out[#out + 1] = L["ohne Antwort: %s"]:format(table.concat(need.without, ", ")) end
    if #out == 0 then out[1] = L["Noch keine Antworten."] end
    return out
end

-- The award dialog's picker values (guild wishers first, marked by a text other than the name)
-- with the clients that answered upgrade (best first) and wish right after the guild wishers;
-- values stay the names, the rest keeps its order.
function ns.NeedAwardValues(item, values)
    if not item or not ns.IsOfficerView() then return values end
    local need = ns.NeedOf(item)
    if not need or (#need.up == 0 and #need.wish == 0) then return values end
    local names = {}
    for i, v in ipairs(values) do names[i] = v.value end
    local function find(name)
        for i, v in ipairs(values) do
            if v.text == v.value and ns.SameNameIn(name, v.value, names) then return i end
        end
        return nil
    end
    local taken, mid = {}, {}
    for _, e in ipairs(need.up) do
        local i = find(e.name)
        if i and not taken[i] then
            taken[i] = true
            mid[#mid + 1] = { value = values[i].value, text = L["%s (Upgrade +%d %%)"]:format(values[i].value, e.pct) }
        end
    end
    for _, e in ipairs(need.wish) do
        local i = find(e.name)
        if i and not taken[i] then
            taken[i] = true
            mid[#mid + 1] = { value = values[i].value, text = L["%s (Wunsch %s)"]:format(values[i].value, PRIO_WORD[e.prio] or PRIO_WORD[2]) }
        end
    end
    if #mid == 0 then return values end
    local out, placed = {}, false
    for i, v in ipairs(values) do
        if not placed and v.text == v.value then
            for _, m in ipairs(mid) do out[#out + 1] = m end
            placed = true
        end
        if not taken[i] then out[#out + 1] = v end
    end
    if not placed then
        for _, m in ipairs(mid) do out[#out + 1] = m end
    end
    return out
end

---------------------------------------------------------------------------
-- Tooltip line (officers): "Upgrade für: Anna +12 %, Bob"
---------------------------------------------------------------------------
function ns.NeedTooltipText(item)
    local need = ns.NeedOf(item)
    if not need or (#need.up == 0 and #need.wish == 0) then return nil end
    local shown = {}
    for _, e in ipairs(need.up) do shown[#shown + 1] = ("%s +%d %%"):format(e.name, e.pct) end
    for _, e in ipairs(need.wish) do shown[#shown + 1] = e.name end
    if #shown > TIP_NAMES then
        return L["Upgrade für: %s und %d weitere"]:format(table.concat(shown, ", ", 1, TIP_NAMES), #shown - TIP_NAMES)
    end
    return L["Upgrade für: %s"]:format(table.concat(shown, ", "))
end

ns.OnItemTooltip("need", function(tip, _, id)
    if not ns.IsOfficerView() or ns.Get("sync.needTooltip") == false then return false end
    local text = ns.NeedTooltipText(id)
    if not text then return false end
    tip:AddLine(text, GREEN[1], GREEN[2], GREEN[3])
    return true
end)

---------------------------------------------------------------------------
-- /amisia wer <Item-Link>
---------------------------------------------------------------------------
ns.RegisterSlash("wer", { en = "upgrade", args = L["<Item-Link>"], officer = true,   -- l10n-ok: the German command word
    desc = L["Wer braucht das? Die Raider antworten aus ihrer Ausrüstung"],
    run = function(rest)
        rest = ns.Plain(rest)
        rest = type(rest) == "string" and rest:match("^%s*(.-)%s*$") or ""
        local id = ns.ItemID(rest) or tonumber(rest:match("^(%d+)$") or "")
        if not id then
            ns.msg(L["Aufruf: /amisia wer <Item-Link>"])
            return
        end
        if not ns.IsOfficerView() then
            ns.msg(L["Nur in der Offiziersansicht."])
            return
        end
        local label = rest:find("|H", 1, true) and rest or ("Item " .. id)
        local function tell()
            ns.msg(L["Upgrade für %s: %s"]:format(label, ns.NeedText(id) or L["keine Antworten"]))
        end
        local qid, why, code = ns.NeedAsk({ id })
        if not qid then
            if code == "recent" then return tell() end
            ns.msg(why)
            return
        end
        ns.msg(L["Gefragt, wer %s braucht. Antworten in %d s."]:format(label, WER_WAIT))
        C_Timer.After(WER_WAIT, tell)
    end })
