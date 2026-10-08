-- Amisia points rounds: in a DKP guild a round of the roll window takes bids ("!bid 50"), in an EPGP
-- guild (and for DKP with fixed prices) the raiders say need or greed and the window sorts them by
-- PR (or the DKP standing). Rolls.lua keeps the round, its timer, its announcements and the hand-out;
-- this file adds what differs: the round's mode and costs, the chat words, checking a bid, the order
-- and its ties, and the cost an award takes over. A round started for a tie-break is always a roll.
--
-- Round fields: mode "bid"|"pr", sys, seal, min, step, cost (MS), costOS, st (the standings when the
-- round starts, lower main -> entry); entries: bid { name, value, kind = "BID", bal, t, class, manual },
-- need/greed { name, kind = "MS"|"OS", value, a, b, pr, low, t, class, manual }.
-- Only the client that runs the round reads the chat; every chat text is untrusted.
local ADDON, ns = ...
local L = ns.L

local KEEP = 10 * 60          -- a finished round names the cost of an award for this long
local MAX_IGNORED = 40
local GREY = "|cff8f86a3"
local lastRound               -- the newest points round (a tie-break roll after it keeps its costs)

-- "bid", "pr" or nil (rolling) for a new round.
function ns.PointsRoundMode()
    local cfg = ns.PointsConfig()
    if cfg.sys == "dkp" then return cfg.mode == "fixed" and "pr" or "bid" end
    if cfg.sys == "epgp" then return "pr" end
    return nil
end

local function changed(r)
    if ns.OnRollChanged then ns.OnRollChanged(r) end
    if ns.CurrentPage and ns.CurrentPage() == "rolls" and ns.Refresh then ns.Refresh() end
end

-- The standing of a name as the round froze it: { name, a, b, pr, low }.
local function standing(r, name)
    local main = ns.MainOf(name) or name
    local e = r.st[main:lower()]
    if not e then
        for _, x in pairs(r.st) do
            if ns.SameName(x.name, main) then e = x break end
        end
    end
    if not e then
        e = ns.PointsOf(main) or { name = main, a = 0, b = 0 }
        r.st[main:lower()] = e
    end
    return e
end

-- Fills a new round of mode in (Rolls.lua calls it before the first announcement).
function ns.PointsRoundStart(r, mode)
    local cfg = ns.PointsConfig()
    r.mode, r.sys = mode, cfg.sys
    r.seal = (mode == "bid" and cfg.seal == 1) or nil
    r.min, r.step, r.base = tonumber(cfg.min) or 0, math.max(1, tonumber(cfg.step) or 1), tonumber(cfg.base) or 100
    r.minep = tonumber(cfg.minep) or 0
    if mode == "pr" then
        r.cost = ns.PointsItemCost(r.item, "MS", cfg)
        r.costOS = ns.PointsItemCost(r.item, "OS", cfg)
    end
    r.st = {}
    for _, e in ipairs(ns.PointsStandings()) do r.st[e.name:lower()] = e end
    lastRound = r
end

local function costText(n) return n and tostring(n) or "?" end

-- The first line of a round.
function ns.PointsRoundAnnounce(r, seconds)
    local me = ns.UnitFullName("player") or "?"
    if r.mode == "bid" then
        if r.seal then
            return L["Verdeckte Gebote auf %s: !bid <Zahl> nur per Flüstern an %s, mindestens %d. %d Sekunden."]:format(r.link, me, r.min, seconds)
        end
        return L["Gebote auf %s: !bid <Zahl> im Raidchat oder per Flüstern an %s, mindestens %d, Schritt %d. %d Sekunden."]:format(r.link, me, r.min, r.step, seconds)
    end
    if r.sys == "epgp" then
        return L["Bedarf auf %s: !need (Mainspec) oder !greed (Offspec), Raidchat oder Flüstern. GP %s, Offspec %s. %d Sekunden."]:format(r.link,
            costText(r.cost), costText(r.costOS), seconds)
    end
    return L["Bedarf auf %s: !need oder !greed, Raidchat oder Flüstern. Preis %s DKP, Offspec %s. %d Sekunden."]:format(r.link,
        costText(r.cost), costText(r.costOS), seconds)
end

-- The hint line of the roll window for a points round.
function ns.PointsRoundHint(r)
    if r.mode == "bid" then
        return L["Gebote: !bid <Zahl> · mindestens %d · %s · höchstens der eigene Stand"]:format(r.min,
            r.seal and L["verdeckt, nur Flüstern"] or L["offen, Schritt %d"]:format(r.step))
    end
    if r.sys == "epgp" then
        return L["!need oder !greed · GP %s, Offspec %s · sortiert nach PR"]:format(costText(r.cost), costText(r.costOS))
    end
    return L["!need oder !greed · Preis %s DKP, Offspec %s · sortiert nach Stand"]:format(costText(r.cost), costText(r.costOS))
end

---------------------------------------------------------------------------
-- Bids
---------------------------------------------------------------------------
local function keyIn(r, name)
    if r.rolls[name] then return name end
    local roster = r.roster or ns.GroupRoster()
    for k in pairs(r.rolls) do
        if ns.SameNameIn(k, name, roster) then return k end
    end
    return nil
end

local function nextSeq(r)
    r.seq = (r.seq or #r.order) + 1
    return r.seq
end

local function highest(r)
    local best
    for _, e in pairs(r.rolls) do
        if not best or e.value > best then best = e.value end
    end
    return best
end

-- Checks and takes a bid: chan "WHISPER", "RAID", "PARTY" (nil and manual for one entered by hand,
-- which skips the channel and the step: the order of bids typed later is not known).
-- Returns the entry or nil and why.
function ns.PointsTakeBid(r, name, class, amount, chan, manual)
    if not r or r.mode ~= "bid" then return nil, L["Keine Gebotsrunde."] end
    if r.done and not manual then return nil, L["Die Runde ist vorbei."] end
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount < 1 then return nil, L["Gebot nicht erkannt: nur eine ganze Zahl, z. B. !bid 50."] end
    if r.only and not keyIn(r, name) then return nil, L["nicht im Stechen"] end
    local st = standing(r, name)
    if amount < r.min then return nil, L["Unter dem Mindestgebot (%d)."]:format(r.min) end
    if amount > (tonumber(st.a) or 0) then return nil, L["Mehr als der eigene Stand (%d)."]:format(tonumber(st.a) or 0) end
    local key = keyIn(r, name) or name
    local own = r.rolls[key]
    if r.seal then
        if not manual and chan ~= "WHISPER" then return nil, L["Verdeckt: Gebote nur per Flüstern."] end
        if own and not manual and amount <= own.value then return nil, L["Nur erhöhen: dein Gebot ist %d."]:format(own.value) end
    elseif not manual then
        local high = highest(r)
        if high and amount < high + r.step then return nil, L["Zu niedrig: mindestens %d."]:format(high + r.step) end
    end
    local e = { name = key, value = amount, kind = "BID", bal = tonumber(st.a) or 0, t = nextSeq(r), class = class or (own and own.class),
                manual = manual and true or nil }
    if not own then r.order[#r.order + 1] = key end
    r.rolls[key] = e
    if r.done then
        ns.RollDecide(r)
        r.dirty = true
    end
    return e
end

-- Need ("MS") or greed ("OS") of a name; kind nil takes the entry out (pass).
function ns.PointsTakeNeed(r, name, class, kind, manual)
    if not r or r.mode ~= "pr" then return nil, L["Keine Bedarfsrunde."] end
    if r.done and not manual then return nil, L["Die Runde ist vorbei."] end
    if r.only and not keyIn(r, name) then return nil, L["nicht im Stechen"] end
    local key = keyIn(r, name) or name
    local own = r.rolls[key]
    if not kind then
        if own then
            r.rolls[key] = nil
            for i, n in ipairs(r.order) do
                if n == key then table.remove(r.order, i) break end
            end
        end
        return true
    end
    if kind ~= "MS" and kind ~= "OS" then return nil, L["Bedarf oder Gier?"] end
    local st = standing(r, name)
    local e = { name = key, kind = kind, a = tonumber(st.a) or 0, b = tonumber(st.b) or 0, t = nextSeq(r),
                class = class or (own and own.class), manual = manual and true or nil }
    if r.sys == "epgp" then
        e.pr = ns.PointsPR(e.a, e.b, r.base)
        e.low = r.minep > 0 and e.a < r.minep or nil
    end
    e.value = e.a
    if not own then r.order[#r.order + 1] = key end
    r.rolls[key] = e
    if r.done then
        ns.RollDecide(r)
        r.dirty = true
    end
    return e
end

-- Rolls.lua's entry row: a bid or need/greed typed by the loot master.
function ns.PointsManualEntry(r, key, class, value, kind)
    if r.mode == "bid" then return ns.PointsTakeBid(r, key, class, tonumber(value), nil, true) end
    return ns.PointsTakeNeed(r, key, class, kind == "OS" and "OS" or "MS", true)
end

---------------------------------------------------------------------------
-- The order
---------------------------------------------------------------------------
local function before(r, x, y)
    if r.mode == "bid" then
        if x.value ~= y.value then return x.value > y.value end
        if x.bal ~= y.bal then return x.bal > y.bal end
        return x.t < y.t
    end
    if x.kind ~= y.kind then return x.kind == "MS" end
    if r.sys == "epgp" then
        if (x.low and true) ~= (y.low and true) then return not x.low end
        local c = ns.PointsCompare({ e = x.a, g = x.b }, { e = y.a, g = y.b }, { base = r.base })
        if c ~= 0 then return c > 0 end
    end
    if x.a ~= y.a then return x.a > y.a end
    return x.t < y.t
end

-- Entries in winning order; each gets .rank (MS/OS) and .tieKey (equal keys: a tie).
function ns.PointsRanking(r)
    local list = {}
    for _, name in ipairs(r.order) do
        if r.rolls[name] then list[#list + 1] = r.rolls[name] end
    end
    table.sort(list, function(x, y) return before(r, x, y) end)
    for _, e in ipairs(list) do
        if r.mode == "bid" then
            e.rank, e.tieKey = "MS", ("%d:%d"):format(e.value, e.bal)
        else
            e.rank = e.kind
            e.tieKey = ("%s:%s:%d:%d"):format(e.kind, e.low and 1 or 0, e.a, r.sys == "epgp" and e.b or 0)
        end
    end
    return list
end

-- The standing text of the result line: "60 DKP", "PR 2,50, Bedarf", "300 DKP, Bedarf".
function ns.PointsResultText(r, top)
    if r.mode == "bid" then return L["%d DKP"]:format(top.value) end
    local word = top.kind == "MS" and L["Bedarf"] or L["Gier"]
    if r.sys == "epgp" then return L["PR %s, %s"]:format(ns.PointsPRText(top.pr), word) end
    return L["Stand %d, %s"]:format(top.a, word)
end

-- A standing as short as the roll window's cell needs it: from 10000 on in thousands ("12k").
local function short(n)
    n = tonumber(n) or 0
    if math.abs(n) >= 10000 then return ("%dk"):format(n >= 0 and math.floor(n / 1000) or -math.floor(-n / 1000)) end
    return tostring(n)
end

-- The roll window's cells of an entry: kind, value, the grey standing.
function ns.PointsRowText(r, e)
    if r.mode == "bid" then
        return L["Gebot"], tostring(e.value), GREY .. short(e.bal) .. "|r"
    end
    local word = e.kind == "MS" and L["Bedarf"] or L["Gier"]
    if r.sys == "epgp" then
        return word, ns.PointsPRText(e.pr), (e.low and "|cffe0574a" or GREY) .. short(e.a) .. "/" .. short(e.b) .. "|r"
    end
    return word, short(e.a), ""
end

-- The newest points round of an item, finished up to KEEP ago or running.
local function roundOf(item)
    local cands = { ns.CurrentRoll and ns.CurrentRoll() or false, ns.LastRoll and ns.LastRoll() or false, lastRound or false }
    for _, r in ipairs(cands) do
        if r and r.mode and r.item == item and (not r.done or time() - (r.ended or r.started or 0) <= KEEP) then return r end
    end
    return nil
end
ns.PointsRoundOf = roundOf

-- The cost an award to name takes over from the item's points round: the bid, or the round's cost
-- of the said kind; nil without such a round or entry.
function ns.PointsCostFor(item, name, kind)
    local r = roundOf(tonumber(item) or ns.ItemID(item))
    if not r or not name then return nil end
    local key = keyIn(r, name)
    local e = key and r.rolls[key]
    if not e then return nil end
    if r.mode == "bid" then return e.value end
    if (kind or e.kind) == "OS" then return r.costOS end
    return r.cost
end

-- The award dialog's amount for an item, a winner and a kind: the round's, else the formula's
-- (DKP bids: the round's only); nil when nothing is known.
function ns.PointsDefaultCost(item, name, kind)
    local r = roundOf(tonumber(item) or ns.ItemID(item))
    if r and name and keyIn(r, name) then
        if r.mode == "bid" then return ns.PointsCostFor(item, name) end
        return ns.PointsCostFor(item, name, kind)
    end
    local cfg = ns.PointsConfig()
    if cfg.sys == "dkp" and cfg.mode ~= "fixed" then return nil end
    return ns.PointsItemCost(item, kind or "MS", cfg)
end

---------------------------------------------------------------------------
-- The chat
---------------------------------------------------------------------------
local function groupClass(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        n = ns.FullName(ns.Plain(n))
        if n and ns.SameName(n, name) then return true, ns.Plain(class), n end
    end
    return false
end

local function ignore(r, name, value, why, sender)
    if #r.ignored < MAX_IGNORED then
        r.ignored[#r.ignored + 1] = { name = name, value = tonumber(value) or 0, why = why }
    end
    if sender and ns.ReplyGate("bid", name:lower()) then
        ns.Say(L["Amisia: Gebot abgelehnt: %s"]:format(why), "WHISPER", sender, { ttl = 30 })
    end
end

local CHANNELS = { WHISPER = true, RAID = true, PARTY = true }

local function onBid(sender, rest, chan)
    local r = ns.CurrentRoll and ns.CurrentRoll()
    if not r or r.done or r.mode ~= "bid" or not CHANNELS[chan] then return end
    local name = ns.FullName(sender)
    if not name then return end
    local ok, class, full = groupClass(name)
    if not ok then return end
    local n, why = ns.PointsParseBid(rest)
    local e
    if n then e, why = ns.PointsTakeBid(r, full, class, n, chan) end
    if not e then
        ignore(r, full, n, why, sender)
    elseif r.seal then
        -- a quiet confirmation, at most one per bidder every few seconds (Chat.lua)
        if ns.ReplyGate("bidok", full:lower()) then
            ns.Say(L["Amisia: Gebot %d angenommen."]:format(e.value), "WHISPER", sender, { ttl = 30 })
        end
    else
        ns.Say(L["Höchstgebot: %d (%s)."]:format(e.value, e.name), "RAID", nil, { ttl = 10 })
    end
    changed(r)
end

local function needWord(kind)
    return function(sender, rest, chan)
        local r = ns.CurrentRoll and ns.CurrentRoll()
        if not r or r.done or r.mode ~= "pr" or not CHANNELS[chan] then return end
        local name = ns.FullName(sender)
        if not name then return end
        local ok, class, full = groupClass(name)
        if not ok then return end
        local e, why = ns.PointsTakeNeed(r, full, class, kind)
        if not e then ignore(r, full, 0, why) end
        changed(r)
    end
end

for _, w in ipairs({ "bid", "gebot" }) do ns.RegisterChatCommand(w, onBid) end -- l10n-ok: chat words
for _, w in ipairs({ "need", "bedarf", "ms" }) do ns.RegisterChatCommand(w, needWord("MS")) end -- l10n-ok: chat words
for _, w in ipairs({ "greed", "gier", "os" }) do ns.RegisterChatCommand(w, needWord("OS")) end -- l10n-ok: chat words
for _, w in ipairs({ "pass", "passe" }) do ns.RegisterChatCommand(w, needWord(nil)) end -- l10n-ok: chat words
