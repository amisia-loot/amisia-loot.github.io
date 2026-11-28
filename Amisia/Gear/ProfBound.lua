-- Amisia: who of the guild holds the reagents that bind when picked up (F-242, D-177, spec
-- docs/specs/2026-11-28-gebundene-materialien.md). Demonic Runes, Blood of Heroes, Ogre Tannin ... cannot be bought or
-- mailed: whoever holds them has to craft with them himself. Which reagents bind, the data says (ns.PROF_BOP, the
-- reagents of ProfessionData with ItemSparse.Bonding 1, outside the lazy table so nothing here builds the profession
-- data, D-28).
--
-- The own count: the current character live (Route.Have: bags, and the bank once it was seen), the other own
-- characters of this guild from AmisiaDB.prof.bags (F-159, saved on logout and at the bank). The message PB goes to
-- the guild 60 to 180 s after the login when there is something to say (or the last one said something), and after
-- an own change at most every 5 minutes: "1", then up to 10 entries "<character>:<item>=<count>[,...]" (no entry:
-- nothing held any more). Never in the lockdown or a battleground, nothing inside an instance (5 to 15 s after the
-- way out), sharing off (prof.bopShare) sends nothing. A receiver keeps only members' messages, only names of the
-- roster, never an own character; an item outside the data's list, a count out of 1-999, more than 7 items of one
-- character or 10 characters drop the whole message. Each message replaces what that sender said before; a
-- character's own report is not replaced by another sender's.
--
-- AmisiaDB.prof.bopHeard = { [name] = { by = sender, at = epoch heard, [item] = count } } (14 days, 300 names)
-- AmisiaDB.prof.bopSent = true while the last PB named something (the next login then says it again, or "nothing")
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local B = {}
ns.ProfBound = B

local LIM = {
    charsMax = 10, perChar = 7, countMax = 999,
    heardMax = 300, heardDays = 14,
    firstMin = 60, firstSpread = 120,   -- the first PB 60 to 180 s after the login
    changeGap = 310,                    -- after an own change at most every 5 minutes (the receivers' gap is 300 s)
    outWait = 5, outSpread = 10,
    tick = 5,
    tipKeep = 10,
}
B.LIM = LIM

local function now() return math.floor(time()) end
local function validName(v) return ns.GuildCharName and ns.GuildCharName(v) or false end
local function whole(v) return type(v) == "number" and v >= 0 and v == math.floor(v) and v < 1e10 end
local function list() return type(ns.PROF_BOP) == "table" and ns.PROF_BOP or nil end

local rev = 0
function B.Rev() return rev end
local function changed()
    rev = rev + 1
    ns.FireSoon("PROF_BOUND")
end

-- Whether a reagent binds when picked up.
function B.IsBound(item)
    local l = list()
    return l ~= nil and l[tonumber(item) or 0] == true
end

-- The bound reagents, sorted.
function B.Items()
    local out = {}
    for item in pairs(list() or {}) do out[#out + 1] = item end
    table.sort(out)
    return out
end

local function profRoot(create)
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.prof) ~= "table" then
        if not create then return nil end
        AmisiaDB.prof = { chars = {} }
    end
    return AmisiaDB.prof
end
local function heardStore(create)
    local p = profRoot(create)
    if not p then return nil end
    if type(p.bopHeard) ~= "table" then
        if not create then return nil end
        p.bopHeard = {}
    end
    return p.bopHeard
end

local function myName()
    local n = ns.UnitFullName and ns.UnitFullName("player")
    return validName(n) and n or nil
end

---------------------------------------------------------------------------
-- The own counts
---------------------------------------------------------------------------
-- The own characters of this guild with the bound reagents they hold: { { name, current, items = { [item] = n } } },
-- the current character first; characters holding none left out.
function B.Own()
    local out = {}
    local items = B.Items()
    if #items == 0 then return out end
    local me = myName()
    local names, seen = {}, {}
    if me and ns.InGuild and ns.InGuild() then
        names[1] = me
        seen[me] = true
    end
    for _, c in ipairs(ns.GuildCharsOwn and ns.GuildCharsOwn() or {}) do
        if not seen[c.name] then
            names[#names + 1] = c.name
            seen[c.name] = true
        end
    end
    local bags = profRoot(false)
    bags = bags and type(bags.bags) == "table" and bags.bags or {}
    local R = ns.ProfRoute
    for _, name in ipairs(names) do
        local held, any = {}, false
        local e = bags[name]
        for _, item in ipairs(items) do
            local n
            if name == me and R and R.Have then
                n = R.Have(item)
            else
                n = type(e) == "table" and type(e.items) == "table" and tonumber(e.items[item]) or 0
            end
            n = math.min(LIM.countMax, math.floor(tonumber(n) or 0))
            if n > 0 then
                held[item] = n
                any = true
            end
        end
        if any then out[#out + 1] = { name = name, current = name == me, items = held } end
    end
    return out
end

---------------------------------------------------------------------------
-- The message PB
---------------------------------------------------------------------------
-- The fields of the own PB: "1", then "<character>:<item>=<n>,..." (at most 10, 7 items each, what does not fit
-- 250 bytes left out); just "1" when nothing is held.
function B.Fields()
    local fields = { "1" }
    local size = #tostring(ns.SYNC_PROTO) + 2 + 1 + 1
    local max = ns.COMM_MAX_TEXT or 250
    for _, c in ipairs(B.Own()) do
        if #fields - 1 >= LIM.charsMax then break end
        local ids = {}
        for item in pairs(c.items) do ids[#ids + 1] = item end
        table.sort(ids)
        local parts = {}
        for i = 1, math.min(#ids, LIM.perChar) do parts[#parts + 1] = ("%d=%d"):format(ids[i], c.items[ids[i]]) end
        local s = c.name .. ":" .. table.concat(parts, ",")
        if size + 1 + #s <= max then
            fields[#fields + 1] = s
            size = size + 1 + #s
        end
    end
    return fields
end

local function rosterName(n)
    local m = ns.GuildMember and ns.GuildMember(n)
    return m and m.name or nil
end

local function isOwn(name)
    if ns.SameName(name, myName() or "") then return true end
    for _, c in ipairs(ns.GuildCharsOwn and ns.GuildCharsOwn() or {}) do
        if ns.SameName(c.name, name) then return true end
    end
    local a = AmisiaDB and type(AmisiaDB.account) == "table" and type(AmisiaDB.account.chars) == "table" and AmisiaDB.account.chars
    if a then
        for own in pairs(a) do if ns.SameName(own, name) then return true end end
    end
    return false
end

local function trimHeard(heard)
    local all = {}
    for name, e in pairs(heard) do all[#all + 1] = { name = name, at = type(e) == "table" and e.at or 0 } end
    if #all <= LIM.heardMax then return end
    table.sort(all, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.name < b.name
    end)
    for i = LIM.heardMax + 1, #all do heard[all[i].name] = nil end
end

-- A member's PB: the whole message checked first; then it replaces what that sender said before.
function B.Take(sender, f)
    if type(f) ~= "table" or f[1] ~= "1" or #f > LIM.charsMax + 1 then return -1 end
    local parsed, names = {}, {}
    for i = 2, #f do
        local raw, rest = tostring(f[i]):match("^([^:]+):(.+)$")
        if not raw or not validName(raw) or names[raw] then return -1 end
        names[raw] = true
        local e, n = {}, 0
        for part in (rest .. ","):gmatch("([^,]*),") do
            local item, count = part:match("^(%d+)=(%d+)$")
            item, count = tonumber(item), tonumber(count)
            if not item or not B.IsBound(item) or not count or count < 1 or count > LIM.countMax or e[item] then return -1 end
            n = n + 1
            if n > LIM.perChar then return -1 end
            e[item] = count
        end
        parsed[#parsed + 1] = { raw = raw, items = e }
    end
    local heard = heardStore(true)
    if not heard then return 0 end
    local t, took, kept = now(), 0, {}
    for _, p in ipairs(parsed) do
        local name = rosterName(p.raw)
        if name and not isOwn(name) then
            local old = heard[name]
            local oldOwn = type(old) == "table" and type(old.by) == "string" and ns.SameName(old.by, name)
            if ns.SameName(name, sender) or not oldOwn or ns.SameName(old.by, sender) then
                local e = { by = sender, at = t }
                for item, n in pairs(p.items) do e[item] = n end
                heard[name] = e
                kept[name] = true
                took = took + 1
            end
        end
    end
    -- what this sender said before and does not say any more: gone
    local dropped = false
    for name, e in pairs(heard) do
        if not kept[name] and type(e) == "table" and type(e.by) == "string" and ns.SameName(e.by, sender) then
            heard[name] = nil
            dropped = true
        end
    end
    if took > 0 or dropped then
        trimHeard(heard)
        changed()
    end
    return took
end

-- When PB may go (as PC: sharing on, a guild, no lockdown, not inside an instance or a battleground).
local function inside()
    if type(IsInInstance) == "function" and ns.Plain((IsInInstance())) == true then return true end
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind ~= nil and kind ~= "none" then return true end
    return ns.InBattlefield and ns.InBattlefield() or false
end
local wasInside, outAt = false, nil
local function away()
    if inside() then
        wasInside, outAt = true, nil
        return true
    end
    if wasInside then
        wasInside = false
        outAt = GetTime() + LIM.outWait + LIM.outSpread / 2
    end
    if outAt and GetTime() >= outAt then outAt = nil end
    return outAt ~= nil
end

function B.CanTalk()
    local out = away()
    if not AmisiaDB or not ns.Get("prof.bopShare") then return false end
    if not ns.CommAvailable() or not ns.InGuild() then return false end
    if ns.CommHeld() then return false end
    return not out
end
local canTalk = function() return B.CanTalk() end

local dueAt, sentAt, sentText = nil, nil, nil
-- An own change: PB goes again once the first one went, at most every 5 minutes, only when it says something new.
function B.Changed()
    if not sentAt then return end
    local at = math.max(GetTime(), sentAt + LIM.changeGap)
    if not dueAt or dueAt > at then dueAt = at end
end

local function trySend()
    if not dueAt or GetTime() < dueAt or not canTalk() then return false end
    dueAt = nil
    local fields = B.Fields()
    local text = table.concat(fields, "\t")
    local p = profRoot(false)
    -- nothing to say and nothing said last time: silent; the same as last time: silent
    if #fields < 2 and not (p and p.bopSent) then return false end
    if text == sentText then return false end
    sentAt, sentText = GetTime(), text
    local pr = profRoot(true)
    if pr then pr.bopSent = #fields >= 2 or nil end
    return ns.CommSend("PB", fields, "GUILD", nil, { low = true, when = canTalk, key = "PB:GUILD" }) and true or false
end
B._trySend = trySend

ns.CommOn("PB", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok then B.Take(name, f) end
    end)
end)

-- the first PB: 60 to 180 s after the login, the spread from the own drop key (no random draw at the login)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    away()
    if dueAt or sentAt then return end
    local key = AmisiaDB and type(AmisiaDB.drops) == "table" and type(AmisiaDB.drops.me) == "string" and AmisiaDB.drops.me or ""
    local spread = (tonumber(key:sub(1, 4), 16) or 0) % (LIM.firstSpread + 1)
    dueAt = GetTime() + LIM.firstMin + spread
end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() away() end)
ns.OnEvent("BAG_UPDATE_DELAYED", function() B.Changed() end)
ns.OnEvent("BANKFRAME_CLOSED", function() B.Changed() end)
C_Timer.NewTicker(LIM.tick, ns.Perf.Wrap("Ticker ProfBound", function() trySend() end))

---------------------------------------------------------------------------
-- The views
---------------------------------------------------------------------------
-- Who holds a bound reagent: { { name, n, own, online, away, class } }: the own other characters first, then the
-- guild (roster names only, 14 days), online first, then the larger count, then the name.
function B.Holders(item)
    item = tonumber(item)
    local out = {}
    if not item or not B.IsBound(item) then return out end
    for _, c in ipairs(B.Own()) do
        if not c.current and c.items[item] then out[#out + 1] = { name = c.name, n = c.items[item], own = true } end
    end
    local heard = heardStore(false)
    local t = now()
    local guild = {}
    for name, e in pairs(heard or {}) do
        local n = type(e) == "table" and tonumber(e[item])
        if n and n > 0 and whole(e.at) and t - e.at <= LIM.heardDays * 86400 and not isOwn(name) then
            local m = ns.GuildMember and ns.GuildMember(name)
            if m then
                guild[#guild + 1] = { name = m.name, n = n, online = m.online and true or false, away = m.online and m.away or false,
                    class = m.class }
            end
        end
    end
    local function state(c) return c.online and (c.away and 1 or 2) or 0 end
    table.sort(guild, function(a, b)
        if state(a) ~= state(b) then return state(a) > state(b) end
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    for _, c in ipairs(guild) do out[#out + 1] = c end
    return out
end

-- "Kim 2 (Twink), Anna 3, Bob 1": own characters grey, online green, away orange; at most max, then "+n".
function B.Text(item, max, color)
    local T = ns.Theme
    local parts = {}
    local holders = B.Holders(item)
    for i, c in ipairs(holders) do
        if max and i > max then
            parts[#parts + 1] = L["+%d weitere"]:format(#holders - max)
            break
        end
        local s = ("%s %d"):format(c.name, c.n)
        if c.own then
            s = ("%s %d (%s)"):format(c.name, c.n, L["Twink"])
            if color then s = T.GREY .. s .. "|r" end
        elseif c.away then
            s = ("%s %d (%s)"):format(c.name, c.n, L["abwesend"])
            if color then s = T.ORANGE .. s .. "|r" end
        elseif color and c.online then
            s = T.GREEN .. s .. "|r"
        end
        parts[#parts + 1] = s
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

-- The recipe's bound reagents with their holders: { { item, text } } (only those somebody holds).
function B.ForReagents(reagents)
    local out = {}
    for _, g in ipairs(reagents or {}) do
        local item = tonumber(g[1] or g.item)
        if item and B.IsBound(item) then
            local text = B.Text(item, 6, true)
            if text then out[#out + 1] = { item = item, text = text } end
        end
    end
    return out
end

-- The item tooltip's line: "Gebunden in der Gilde: Anna 3, Bob 1", kept 10 s per item.
local tipCache, tipRev = {}, -1
function B.TooltipLine(item)
    item = tonumber(item)
    if not item or not B.IsBound(item) then return nil end
    if tipRev ~= rev then tipCache, tipRev = {}, rev end
    local hit = tipCache[item]
    if hit and GetTime() - hit.at < LIM.tipKeep then return hit.line or nil end
    local text = B.Text(item, 4, false)
    local line = text and L["Gebunden in der Gilde: %s"]:format(text) or false
    tipCache[item] = { at = GetTime(), line = line }
    return line or nil
end

local tipHooked = false
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ns.ADDON or tipHooked or not ns.OnItemTooltip then return end
    tipHooked = true
    ns.OnItemTooltip("bound", function(tip, _, id)
        local line = B.TooltipLine(id)
        if not line then return false end
        tip:AddLine(line, 0.56, 0.53, 0.64)
        return true
    end)
end)

---------------------------------------------------------------------------
-- On load: the heard table checked
---------------------------------------------------------------------------
function ns.ProfBoundLoaded(root)
    local p = type(root) == "table" and root.prof
    if type(p) ~= "table" then return end
    if p.bopSent ~= nil and p.bopSent ~= true then p.bopSent = nil end
    if p.bopHeard == nil then return end
    if type(p.bopHeard) ~= "table" then
        p.bopHeard = nil
        return
    end
    local t = now()
    for name, e in pairs(p.bopHeard) do
        local ok = validName(name) and type(e) == "table" and whole(e.at) and t - e.at <= LIM.heardDays * 86400 and validName(e.by)
        if ok then
            local n = 0
            for k, v in pairs(e) do
                if type(k) == "number" then
                    if B.IsBound(k) and whole(v) and v >= 1 and v <= LIM.countMax then n = n + 1 else e[k] = nil end
                elseif k ~= "by" and k ~= "at" then
                    e[k] = nil
                end
            end
            ok = n > 0 and n <= LIM.perChar
        end
        if not ok then p.bopHeard[name] = nil end
    end
    trimHeard(p.bopHeard)
    rev = rev + 1
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then ns.ProfBoundLoaded(AmisiaDB) end
end)
end)
