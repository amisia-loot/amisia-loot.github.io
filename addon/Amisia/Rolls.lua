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
--          rolls = { [name] = { name, value, low, high, kind, t, class } }, order = { names },
--          ignored = { { name, value, low, high, why } }, reserved = { names }, reservedSet = {},
--          plus = { [name] = n }   -- plus-one of every roller, frozen when the round starts
--          done, winner, tie = { names }|nil }

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

-- Whether name reserved the item of round r: exactly, else over SameName ("Vulo" on the list,
-- the roll from "Vulo Sturmwind").
local function reservedIn(r, name)
    if r.reservedSet[name] then return true end
    for _, n in ipairs(r.reserved or {}) do
        if ns.SameName(n, name) then return true end
    end
    return false
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

local function finish()
    if not current or current.done then return end
    if ticker then ticker:Cancel(); ticker = nil end
    current.done = true
    current.leftAt = 0
    local list = ns.RollRanking(current)
    if #list == 0 then
        ns.Announce("Stopp! Niemand hat gewürfelt.")
    else
        local top = list[1]
        local tie = { top.name }
        for i = 2, #list do
            local e = list[i]
            if sameStanding(current, e, top) then
                tie[#tie + 1] = e.name
            else
                break
            end
        end
        local plus = ns.PlusLabel(current, top.name)
        local standing = plus and ("%d, %s, %s"):format(top.value, top.rank, plus) or ("%d, %s"):format(top.value, top.rank)
        if #tie > 1 then
            current.tie = tie
            ns.Announce(("Stopp! Gleichstand: %s (%s). Bitte nochmal würfeln."):format(table.concat(tie, " und "), standing))
        else
            current.winner = top.name
            ns.Announce(("Stopp! Gewinner: %s (%s)."):format(top.name, standing))
        end
    end
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
    seconds = tonumber(seconds) or ns.Get("rolls.seconds") or 20
    seconds = math.max(5, math.min(120, math.floor(seconds)))
    local reserved = ns.ReservedBy and ns.ReservedBy(id) or {}
    current = {
        item = id, link = link, name = link:match("|h%[(.-)%]|h") or ("Item " .. id),
        started = time(), seconds = seconds, leftAt = seconds,
        rolls = {}, order = {}, ignored = {}, reserved = reserved, reservedSet = {}, plus = {},
    }
    for _, n in ipairs(reserved) do current.reservedSet[n] = true end
    -- the plus-one of everyone in the group as of now; whoever is missing here is counted on the roll
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then plusOf(current, n) end
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
            ns.Announce(("%d Sekunden."):format(left))
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

local function onSystem(text)
    if not current or current.done or not matcher then return end
    -- a secret line (boss fight on the Forever client) cannot be read and is left alone
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local a = matcher(text)
    if not a then return end
    local name = shortName(a[1])
    local value, low, high = tonumber(a[2]), tonumber(a[3]), tonumber(a[4])
    if not name or not value then return end
    local ok, class = inGroup(name)
    local why
    if not ok then
        why = "nicht in der Gruppe"
    elseif current.only and not current.only[name] then
        why = "nicht am Stechen beteiligt"
    elseif current.rolls[name] then
        why = "schon gewürfelt"
    elseif not kindOf(low, high) then
        why = ("Bereich %d-%d"):format(low or 0, high or 0)
    end
    if why then
        current.ignored[#current.ignored + 1] = { name = name, value = value, low = low, high = high, why = why }
    else
        current.rolls[name] = { name = name, value = value, low = low, high = high, kind = kindOf(low, high), t = #current.order + 1, class = class }
        current.order[#current.order + 1] = name
        plusOf(current, name)
    end
    changed()
end
ns.OnEvent("CHAT_MSG_SYSTEM", onSystem)

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
ns.RegisterSlash("rollzeit", { officer = true, args = "<5-120>", desc = "Standard-Dauer einer Roll-Runde", run = function(rest)
    local ok = ns.Set("rolls.seconds", tonumber(rest))
    ns.msg(ok and ("Roll-Dauer: %d Sekunden."):format(ns.Get("rolls.seconds")) or "Aufruf: /amisia rollzeit <5-120>")
end })
