-- Amisia rolls: one round at a time. Results are read from the system chat through the client's
-- own RANDOM_ROLL_RESULT string, so the range of every roll is known: 1-100 is mainspec,
-- 1-99 offspec. Reserved names rank first, then MS, then OS, then the higher roll.
local ADDON, ns = ...

local KEEP = 10 * 60   -- a finished round answers ns.RollKind for this long
local current, last, ticker
local matcher

-- Round: { item, link, name, started, seconds, leftAt, only = {[name]=true}|nil,
--          rolls = { [name] = { name, value, low, high, kind, t, class } }, order = { names },
--          ignored = { { name, value, low, high, why } }, reserved = { names }, reservedSet = {},
--          done, winner, tie = { names }|nil }

local function shortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or nil
end

local function inGroup(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        if n and shortName(n) == name then return true, class end
    end
    return false
end

local function kindOf(low, high)
    if low == 1 and high == 100 then return "MS" end
    if low == 1 and high == 99 then return "OS" end
    return nil
end

local RANK = { MS = 2, OS = 1 }
local function rankOf(r, e)
    if r.reservedSet[e.name] then return 3 end
    return RANK[e.kind] or 0
end

-- Entries of a round in winning order; each gets .rank = "SR", "MS" or "OS".
function ns.RollRanking(r)
    local list = {}
    for _, name in ipairs(r.order) do list[#list + 1] = r.rolls[name] end
    table.sort(list, function(a, b)
        local ra, rb = rankOf(r, a), rankOf(r, b)
        if ra ~= rb then return ra > rb end
        if a.value ~= b.value then return a.value > b.value end
        return a.t < b.t
    end)
    for _, e in ipairs(list) do e.rank = rankOf(r, e) == 3 and "SR" or e.kind end
    return list
end

local function changed()
    if ns.OnRollChanged then ns.OnRollChanged(current) end
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
            if e.value == top.value and rankOf(current, e) == rankOf(current, top) then
                tie[#tie + 1] = e.name
            else
                break
            end
        end
        if #tie > 1 then
            current.tie = tie
            ns.Announce(("Stopp! Gleichstand: %s (%d, %s). Bitte nochmal würfeln."):format(table.concat(tie, " und "), top.value, top.rank))
        else
            current.winner = top.name
            ns.Announce(("Stopp! Gewinner: %s (%d, %s)."):format(top.name, top.value, top.rank))
        end
    end
    last = current
    changed()
end

-- Starts a round for an item link. onlyNames restricts who counts (the tie-break).
function ns.StartRoll(link, seconds, onlyNames)
    local id = ns.ItemID(link)
    if not id then return nil, "Kein Item-Link. Aufruf: /amisia roll <Item-Link> [Sekunden]" end
    if current and not current.done then finish() end
    seconds = tonumber(seconds) or (AmisiaDB and AmisiaDB.settings and tonumber(AmisiaDB.settings.rollSeconds)) or 20
    seconds = math.max(5, math.min(120, math.floor(seconds)))
    local reserved = ns.ReservedBy and ns.ReservedBy(id) or {}
    current = {
        item = id, link = link, name = link:match("|h%[(.-)%]|h") or ("Item " .. id),
        started = time(), seconds = seconds, leftAt = seconds,
        rolls = {}, order = {}, ignored = {}, reserved = reserved, reservedSet = {},
    }
    for _, n in ipairs(reserved) do current.reservedSet[n] = true end
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
        if (left == 10 and seconds > 10) or (left == 5 and seconds > 5) or (left == 3 and seconds > 3) then
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

-- Starts the tie-break of the current round, if it ended in a tie.
function ns.RerollTie()
    local r = current or last
    if not r or not r.tie then return nil, "Kein Gleichstand." end
    return ns.StartRoll(r.link, 10, r.tie)
end

local function onSystem(text)
    if not current or current.done or not matcher or type(text) ~= "string" then return end
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
    end
    changed()
end
ns.OnEvent("CHAT_MSG_SYSTEM", onSystem)

-- MS, OS or SR for an award: what the recipient reserved or rolled in the last round for this item.
function ns.RollKind(item, name)
    local r = (current and current.item == item) and current or ((last and last.item == item) and last or nil)
    if not r or (time() - r.started) > KEEP then return "-" end
    if r.reservedSet[name] then return "SR" end
    local e = r.rolls[name]
    return e and e.kind or "-"
end
