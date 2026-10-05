-- Amisia rolls: one round at a time. Results are read from the system chat through the client's
-- own RANDOM_ROLL_RESULT string, so the range of every roll is known: 1-100 is mainspec,
-- 1-99 offspec. Reserved names rank first, then MS, then OS, then the higher roll. With the
-- plus-one in the order (awards.plusOrder), fewer mainspec wins rank first among the MS rolls.
local ADDON, ns = ...

local KEEP = 10 * 60   -- a finished round answers ns.RollKind for this long
local current, last, ticker
local history = {}   -- finished rounds, newest first (this session only)
local matcher

-- Round: { item, link, name, started, seconds, leftAt, only = {[name]=true}|nil,
--          rolls = { [name] = { name, value, low, high, kind, t, class, manual } }, order = { names },
--          ignored = { { name, value, low, high, why } }, reserved = { names }, reservedSet = {},
--          roster = { names }   -- the group when the round starts (who a bare first name means)
--          plus = { [name] = n }   -- plus-one of every roller, frozen when the round starts
--          done, ended, winner, tie = { names }|nil,
--          lockdown = true   -- ran wholly or partly in the chat lockdown of a boss fight
--          hidden = n        -- secret system lines during the round (not all of them rolls)
--          dirty = true      -- changed by hand after the end, result not announced yet
--          seq = n }         -- running number for the order of equal rolls

local function shortName(name)
    return ns.FullName(name)
end

local function inGroup(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        if n and ns.SameName(n, name) then return true, class end
    end
    return false
end

local function kindOf(low, high)
    if low == 1 and high == 100 then return "MS" end
    if low == 1 and high == 99 then return "OS" end
    return nil
end

-- The names a bare first name is checked against in round r: its roster, else the group now.
local function rosterOf(r)
    return r.roster or ns.GroupRoster()
end

-- Whether name reserved the item of round r: exactly, else over ns.SameNameIn ("Vulo" on the
-- list, the roll from "Vulo Sturmwind", only while one raider of the round is called Vulo).
local function reservedIn(r, name)
    if r.reservedSet[name] then return true end
    local roster = rosterOf(r)
    for _, n in ipairs(r.reserved or {}) do
        if ns.SameNameIn(n, name, roster) then return true end
    end
    return false
end

-- The key of set (a round's rolls or tie-break names) that means name: the same spelling, else
-- one that ns.SameNameIn takes for it ("Vulo" from the chat, "Vulo Sturmwind" from the roster).
local function keyIn(r, set, name)
    if set[name] then return name end
    local roster = rosterOf(r)
    for k in pairs(set) do
        if ns.SameNameIn(k, name, roster) then return k end
    end
    return nil
end

local RANK = { MS = 2, OS = 1 }
local function rankOf(r, e)
    if reservedIn(r, e.name) then return 3 end
    return RANK[e.kind] or 0
end

-- The plus-one of a name in round r, frozen the first time it is asked for: an award during the
-- round must not move the order.
local function plusOf(r, name)
    r.plus = r.plus or {}
    local n = r.plus[name]
    if n == nil then
        n = ns.PlusCount and ns.PlusCount(name) or 0
        r.plus[name] = n
    end
    return n
end

-- Whether the plus-one decides between mainspec rolls (setting awards.plusOrder).
local function plusOrder()
    return ns.Get("awards.plusOrder") and true or false
end

-- Two entries of the same rank are equal when their rolls match and, among mainspec rolls with
-- the plus-one in the order, their plus-one too.
local function sameStanding(r, a, b)
    if a.value ~= b.value or rankOf(r, a) ~= rankOf(r, b) then return false end
    if rankOf(r, a) == RANK.MS and plusOrder() then return plusOf(r, a.name) == plusOf(r, b.name) end
    return true
end

-- Entries of a round in winning order; each gets .rank = "SR", "MS" or "OS". With awards.plusOrder
-- fewer plus-one ranks first among the mainspec rolls; reservations stay first, offspec untouched.
function ns.RollRanking(r)
    local list = {}
    for _, name in ipairs(r.order) do list[#list + 1] = r.rolls[name] end
    local byPlus = plusOrder()
    table.sort(list, function(a, b)
        local ra, rb = rankOf(r, a), rankOf(r, b)
        if ra ~= rb then return ra > rb end
        if byPlus and ra == RANK.MS then
            local pa, pb = plusOf(r, a.name), plusOf(r, b.name)
            if pa ~= pb then return pa < pb end
        end
        if a.value ~= b.value then return a.value > b.value end
        return a.t < b.t
    end)
    for _, e in ipairs(list) do e.rank = rankOf(r, e) == 3 and "SR" or e.kind end
    return list
end

-- "+n" for a mainspec roller of round r: when the count is above zero, or always while the
-- plus-one is in the order. Nothing for a reservation or an offspec roll.
function ns.PlusLabel(r, name)
    local e = r and r.rolls and r.rolls[name]
    if not e or rankOf(r, e) ~= RANK.MS then return nil end
    local n = plusOf(r, name)
    if n > 0 or plusOrder() then return ("+%d"):format(n) end
    return nil
end

local function changed()
    if ns.OnRollChanged then ns.OnRollChanged(current) end
    if ns.CurrentPage and ns.CurrentPage() == "rolls" then ns.Refresh() end
end

-- Winner or tie of round r from its ranking, without announcing (finish and hand rolls use it).
-- Returns the ranking, its top entry and the standing text ("95, MS" or "95, MS, +1").
function ns.RollDecide(r)
    r.winner, r.tie = nil, nil
    local list = ns.RollRanking(r)
    local top = list[1]
    if not top then return list end
    local tie = { top.name }
    for i = 2, #list do
        local e = list[i]
        if sameStanding(r, e, top) then
            tie[#tie + 1] = e.name
        else
            break
        end
    end
    if #tie > 1 then r.tie = tie else r.winner = top.name end
    local plus = ns.PlusLabel(r, top.name)
    local standing = plus and ("%d, %s, %s"):format(top.value, top.rank, plus) or ("%d, %s"):format(top.value, top.rank)
    return list, top, standing
end

-- Announces the result of round r (default the newest); prefix starts the line ("Stopp! " when
-- the round ends, else the item). Clears r.dirty.
function ns.AnnounceRollResult(r, prefix)
    r = r or current or last
    if not r then return nil, "Keine Runde." end
    if not r.done then return nil, "Die Runde läuft noch." end
    local list, _, standing = ns.RollDecide(r)
    prefix = prefix or ("Ergebnis %s: "):format(r.link or r.name or "?")
    if #list == 0 then
        ns.Announce(prefix .. "Niemand hat gewürfelt.")
    elseif r.tie then
        ns.Announce(("%sGleichstand: %s (%s). Bitte nochmal würfeln."):format(prefix, table.concat(r.tie, " und "), standing))
    else
        ns.Announce(("%sGewinner: %s (%s)."):format(prefix, r.winner, standing))
    end
    r.dirty = nil
    changed()
    return true
end

local function finish()
    if not current or current.done then return end
    if ticker then ticker:Cancel(); ticker = nil end
    current.done = true
    current.ended = time()
    current.leftAt = 0
    ns.AnnounceRollResult(current, "Stopp! ")
    last = current
    table.insert(history, 1, current)
    while #history > 10 do table.remove(history) end
    changed()
end

-- Starts a round for an item link. onlyNames restricts who counts (the tie-break).
function ns.StartRoll(link, seconds, onlyNames)
    local id = ns.ItemID(link)
    if not id then return nil, "Kein Item-Link. Aufruf: /amisia roll <Item-Link> [Sekunden]" end
    if current and not current.done then finish() end
    -- a round changed by hand and not announced cannot be announced any more once a newer one runs
    for _, old in ipairs(history) do
        if old.dirty then
            old.dirty = nil
            ns.msg(("Das geänderte Ergebnis für %s wurde nicht angesagt; die neue Runde ersetzt es."):format(old.link or old.name or "?"))
        end
    end
    seconds = tonumber(seconds) or ns.Get("rolls.seconds") or 20
    seconds = math.max(5, math.min(120, math.floor(seconds)))
    local reserved = ns.ReservedBy and ns.ReservedBy(id) or {}
    current = {
        item = id, link = link, name = link:match("|h%[(.-)%]|h") or ("Item " .. id),
        started = time(), seconds = seconds, leftAt = seconds,
        rolls = {}, order = {}, ignored = {}, reserved = reserved, reservedSet = {}, plus = {}, roster = {},
        lockdown = ns.ChatLocked and ns.ChatLocked() or nil, hidden = 0, seq = 0,
    }
    for _, n in ipairs(reserved) do current.reservedSet[n] = true end
    -- the plus-one of everyone in the group as of now; whoever is missing here is counted on the roll
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then
            plusOf(current, n)
            current.roster[#current.roster + 1] = n
        end
    end
    if onlyNames then
        current.only = {}
        for _, n in ipairs(onlyNames) do current.only[n] = true end
    end
    if not matcher then matcher = ns.BuildMatcher(RANDOM_ROLL_RESULT) end
    if onlyNames then
        ns.Announce(("Stechen: %s. /roll. %d Sekunden."):format(table.concat(onlyNames, ", "), seconds))
    else
        ns.Announce(("Roll auf %s: /roll für Mainspec, /roll 99 für Offspec. %d Sekunden."):format(link, seconds))
        if #reserved > 0 then ns.Announce("Reserviert von " .. table.concat(reserved, ", ") .. ".") end
    end
    local left = seconds
    ticker = C_Timer.NewTicker(1, function()
        left = left - 1
        if current then current.leftAt = left end
        if ns.Get("rolls.countdown") and ((left == 10 and seconds > 10) or (left == 5 and seconds > 5) or (left == 3 and seconds > 3)) then
            -- a countdown is worthless after a few seconds (it waits during the chat lockdown)
            ns.Announce(("%d Sekunden."):format(left), 3)
        end
        if left <= 0 then finish() else changed() end
    end)
    changed()
    return true
end

function ns.StopRoll() finish() end
function ns.CurrentRoll() return current end
function ns.LastRoll() return last end
function ns.RollHistory() return history end

-- Starts the tie-break of the current round, if it ended in a tie.
function ns.RerollTie()
    local r = current or last
    if not r or not r.tie then return nil, "Kein Gleichstand." end
    return ns.StartRoll(r.link, 10, r.tie)
end

local function nextSeq(r)
    r.seq = (r.seq or #r.order) + 1
    return r.seq
end

local function onSystem(text)
    if not current or current.done or not matcher then return end
    -- a secret line (boss fight on the Forever client) cannot be read: counted, so the window can
    -- say that rolls may be missing and are to be entered by hand
    text = ns.Plain(text)
    if type(text) ~= "string" then
        current.hidden = (current.hidden or 0) + 1
        current.lockdown = true
        changed()
        return
    end
    local a = matcher(text)
    if not a then return end
    local name = shortName(a[1])
    local value, low, high = tonumber(a[2]), tonumber(a[3]), tonumber(a[4])
    if not name or not value then return end
    local ok, class = inGroup(name)
    local why
    if not ok then
        why = "nicht in der Gruppe"
    elseif current.only and not keyIn(current, current.only, name) then
        why = "nicht im Stechen"
    elseif keyIn(current, current.rolls, name) then
        why = "schon gewürfelt"
    elseif not kindOf(low, high) then
        why = ("Bereich %d-%d"):format(low or 0, high or 0)
    end
    if why then
        current.ignored[#current.ignored + 1] = { name = name, value = value, low = low, high = high, why = why }
    else
        current.rolls[name] = { name = name, value = value, low = low, high = high, kind = kindOf(low, high), t = nextSeq(current), class = class }
        current.order[#current.order + 1] = name
        plusOf(current, name)
    end
    changed()
end
ns.OnEvent("CHAT_MSG_SYSTEM", onSystem)

-- The lockdown began during the round: the state is final only after the dispatch.
local function noteLockdown()
    if current and not current.done and ns.ChatLocked and ns.ChatLocked() and not current.lockdown then
        current.lockdown = true
        changed()
    end
end
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    noteLockdown()
    C_Timer.After(0, noteLockdown)
end)

---------------------------------------------------------------------------
-- Rolls by hand: when the roll chat is secret (boss fight on Forever), the loot master enters them
---------------------------------------------------------------------------
local RANGE = "Wurf 1-100 (MS) oder 1-99 (OS)."
local HIGH = { MS = 100, OS = 99 }

-- The round a hand roll goes to: the running one, else the last one up to 10 minutes after its end.
local function handRound()
    if current and not current.done then return current end
    if last and last.done and time() - (last.ended or last.started or 0) <= KEEP then return last end
    return nil
end

-- A name of the group (its spelling, with class) or of the running recording, or nil. A first
-- name that several of them carry is refused: nil and "Name nicht eindeutig: A, B".
local function knownName(name)
    local cands, seen = {}, {}
    local function add(n, class)
        if not n or seen[n:lower()] then return end
        seen[n:lower()] = true
        if n:lower() == name:lower() then
            cands.exact = cands.exact or { n, class }
        elseif ns.SameName(n, name) then
            cands[#cands + 1] = { n, class }
        end
    end
    for i = 1, GetNumGroupMembers() or 0 do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        add(ns.FullName(ns.Plain(n)), ns.Plain(class))
    end
    local s = ns.Active and ns.Active()
    for n, m in pairs(s and s.members or {}) do
        add(ns.FullName(ns.Plain(n)), (m.class ~= "" and m.class) or nil)
    end
    if cands.exact then return cands.exact[1], cands.exact[2] end
    if #cands == 1 then return cands[1][1], cands[1][2] end
    if #cands > 1 then
        local list = {}
        for i, c in ipairs(cands) do list[i] = c[1] end
        table.sort(list)
        return nil, nil, ("Name nicht eindeutig: %s"):format(table.concat(list, ", "))
    end
    return nil
end

-- Whether the item of finished round r was handed out in the running recording after the round.
local function awardedAfter(r)
    local s = ns.Active and ns.Active()
    if not (r.done and s and type(s.awards) == "table") then return false end
    for _, a in ipairs(s.awards) do
        if a.item == r.item and (a.t or 0) >= (r.ended or r.started or 0) then return true end
    end
    return false
end

-- Enters a roll by hand into the running round or the last finished one (up to 10 minutes):
-- kind "MS" (1-100) or "OS" (1-99), replacing a roll of the same name. A finished round is decided
-- anew and marked dirty; its result is announced only through ns.AnnounceRollResult.
function ns.AddManualRoll(name, value, kind)
    local r = handRound()
    if not r then return nil, "Keine Runde." end
    kind = tostring(kind or "MS"):upper()
    local high = HIGH[kind]
    value = tonumber(value)
    if not high or not value or value % 1 ~= 0 or value < 1 or value > high then return nil, RANGE end
    local typed = ns.FullName(ns.Plain(name))
    if not typed then return nil, "Kein Name." end
    local full, class, ambiguous = knownName(typed)
    if not full then return nil, ambiguous or ("%s ist nicht in der Gruppe."):format(typed) end
    -- one player, one entry: a roll from the chat or a tie-break name in another spelling keeps its key
    local key = keyIn(r, r.rolls, full)
    if r.only then
        local tied = keyIn(r, r.only, full)
        if not tied then return nil, ("%s ist nicht am Stechen beteiligt."):format(full) end
        key = key or tied
    end
    key = key or full
    if awardedAfter(r) then return nil, "Das Item ist schon vergeben; erst die Vergabe ändern." end
    local e = { name = key, value = value, low = 1, high = high, kind = kind, t = nextSeq(r), class = class, manual = true }
    if not r.rolls[key] then r.order[#r.order + 1] = key end
    r.rolls[key] = e
    plusOf(r, key)
    if r.done then
        ns.RollDecide(r)
        r.dirty = true
    end
    changed()
    return e
end

-- Hand rolls of a round.
function ns.ManualRollCount(r)
    local n = 0
    for _, e in pairs(r and r.rolls or {}) do
        if e.manual then n = n + 1 end
    end
    return n
end

-- /amisia wurf <Name> <Zahl> [os]: the number is the first purely numeric word, the name all
-- before it (Forever names hold a space).
local function rollCommand(rest)
    if not ns.IsOfficerView() then ns.msg("Würfe von Hand nur in der Offiziersansicht.") return end
    local words = {}
    for w in (rest or ""):gmatch("%S+") do words[#words + 1] = w end
    local at
    for i, w in ipairs(words) do
        if w:match("^%d+$") then at = i break end
    end
    if not at or at == 1 then ns.msg("Aufruf: /amisia wurf <Name> <Zahl> [os]") return end
    local name = table.concat(words, " ", 1, at - 1)
    local kind = (words[at + 1] or "ms"):upper()
    local e, why = ns.AddManualRoll(name, words[at], kind)
    if not e then ns.msg(why) return end
    ns.msg(("Wurf eingetragen: %s %d (%s)."):format(e.name, e.value, e.kind))
    local r = handRound()
    if r and r.done and r.dirty then ns.msg("Die Runde ist beendet: \"Ergebnis ansagen\" im Roll-Fenster sagt das neue Ergebnis an.") end
end

-- MS, OS or SR for an award: what the recipient reserved or rolled in the last round for this item.
function ns.RollKind(item, name)
    local r = (current and current.item == item) and current or ((last and last.item == item) and last or nil)
    if not r or (time() - r.started) > KEEP then return "-" end
    if reservedIn(r, name) then return "SR" end
    local e = r.rolls[name]
    return e and e.kind or "-"
end

ns.RegisterSettings{ key = "rolls", label = "Rolls und Vergabe", order = 20, officer = true, items = {
    { key = "rolls.seconds", type = "slider", label = "Roll-Dauer (Sekunden)", default = 20, min = 5, max = 120, step = 1 },
    { key = "rolls.countdown", type = "toggle", label = "Countdown ansagen", default = true,
      tip = "Sagt bei 10, 5 und 3 Sekunden die Restzeit an." },
    { key = "rolls.channel", type = "choice", label = "Ansagekanal", default = "RAID_WARNING",
      values = { { "RAID_WARNING", "Schlachtzugswarnung" }, { "RAID", "Schlachtzug" } },
      tip = "Schlachtzugswarnung nur als Leiter oder Assistent, sonst Schlachtzug." },
    { key = "rolls.altClick", type = "toggle", label = "Alt-Klick im Lootfenster startet einen Roll", default = true,
      tip = "Ausschalten, wenn ein anderes Loot-Addon Alt-Klick selbst benutzt." },
}}
ns.RegisterSlash("roll", { officer = true, args = "<Item-Link> [Sekunden]", desc = "Roll-Runde starten", run = function(rest)
    local link, secs = rest:match("^(.-)%s*(%d*)$")
    local ok, why = ns.StartRoll(link, tonumber(secs))
    if not ok then ns.msg(why or "Aufruf: /amisia roll <Item-Link> [Sekunden]") elseif ns.ShowRollFrame then ns.ShowRollFrame() end
end })
ns.RegisterSlash("wurf", { aliases = { "addroll" }, officer = true, args = "<Name> <Zahl> [os]", desc = "Wurf von Hand in die Runde eintragen",
    run = rollCommand })
ns.RegisterSlash("rollzeit", { officer = true, args = "<5-120>", desc = "Standard-Dauer einer Roll-Runde", run = function(rest)
    local ok = ns.Set("rolls.seconds", tonumber(rest))
    ns.msg(ok and ("Roll-Dauer: %d Sekunden."):format(ns.Get("rolls.seconds")) or "Aufruf: /amisia rollzeit <5-120>")
end })
