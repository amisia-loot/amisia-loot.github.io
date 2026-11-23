-- Amisia profession cooldowns (F-232, D-163, spec docs/specs/2026-11-23-berufs-abklingzeiten.md): which own
-- characters and which guild members can use a recipe with a long cooldown (transmutes, Mooncloth) right now.
--
-- The recipes with a cooldown come from the data (ns.PROF_COOLDOWNS, CD of ProfessionData outside its lazy table:
-- "category:hours", so nothing here builds the profession data, D-28). A cooldown is shown from 20 hours on;
-- recipes of one category (310: all transmutes) form one line. The remaining time is the client's
-- (C_Spell.GetSpellCooldown, else GetSpellCooldown, else with the profession window open
-- C_TradeSkillUI.GetRecipeCooldown), read at the login, on opening the profession window and after crafting one;
-- it is kept as an epoch "ready from" per character. After crafting without any answer of the client the data's
-- hours count. What the client cannot say keeps the last reading.
--
-- The message PC goes to the guild 60 to 180 s after the login and after an own change (at most once a minute):
-- "1", then up to 10 entries "<character>:<spell>=<seconds>[,...]" of the own characters of this guild (as AC),
-- the seconds left, never a time of day (the receiver counts with its own clock). Never in the lockdown or a
-- battleground, nothing inside an instance: it waits and goes 5 to 15 s after the way out (as the crafter
-- exchange). A receiver keeps only members' messages, only characters of the roster, a character's own report
-- over another sender's; a spell outside the data, a time out of 0-400000 s, more than 4 cooldowns of one
-- character or 10 characters drop the whole message.
--
-- AmisiaDB.prof.cd = { [own character] = { realm, faction = "A"/"H", [spell] = ready-from epoch } }
-- AmisiaDB.prof.cdHeard = { [name] = { by = sender, at = epoch heard, [spell] = ready-from epoch } } (7 days, 300 names)
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local PC = {}
ns.ProfCooldowns = PC

-- the caps and times; a table so a test can lower one
local LIM = {
    minHours = 20,                      -- shown (and sent) from this cooldown on
    secMax = 400000,                    -- seconds a message may name
    charsMax = 10, perChar = 4,         -- characters of one PC, cooldowns of one character
    heardMax = 300, heardDays = 7,      -- names heard, days a name is kept without a new message
    ownMax = 50,                        -- own characters kept
    firstMin = 60, firstSpread = 120,   -- the first PC 60 to 180 s after the login
    changeGap = 60,                     -- after an own change at most once a minute
    outWait = 5, outSpread = 10,        -- seconds after leaving an instance before PC goes
    tick = 5,
    readDelay = 0.5,                    -- after a cast or the profession window
    loginRead = 3, loginLine = 10,      -- seconds after entering the world: the first reading, the chat line
    gcd = 2,                            -- a cooldown this short is the global one: ready
    tipKeep = 10,
}
PC.LIM = LIM

-- the line names of categories the locale knows; any other line is named after its recipe
local CATEGORY_NAME = { [310] = L["Transmutation"] }

local function now() return math.floor(time()) end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end
local function whole(v) return type(v) == "number" and v >= 0 and v == math.floor(v) and v < 1e10 end
local function validName(v) return ns.GuildCharName and ns.GuildCharName(v) or false end
local function cleanText(v, max)
    return type(v) == "string" and v ~= "" and #v <= max and not v:find("[%c|]") and v or nil
end

local rev = 0
function PC.Rev() return rev end
local function changed()
    rev = rev + 1
    ns.FireSoon("PROF_COOLDOWNS")
end

---------------------------------------------------------------------------
-- The data: which recipes have a cooldown, its category and length
---------------------------------------------------------------------------
local function cdData() return type(ns.PROF_COOLDOWNS) == "table" and ns.PROF_COOLDOWNS or nil end

-- The category (0 none) and the hours of a recipe's cooldown, nil for a recipe without one.
function PC.Info(spell)
    local d = cdData()
    local v = d and type(spell) == "number" and d[spell]
    if type(v) ~= "string" then return nil end
    local c, h = v:match("^(%d+):(%d+)$")
    if not c then return nil end
    return tonumber(c), tonumber(h)
end

-- The line a recipe belongs to ("c310" a category, "s18560" a recipe of its own), nil when its cooldown is
-- shorter than 20 hours or it has none.
function PC.Group(spell)
    local c, h = PC.Info(spell)
    if not c or h < LIM.minHours then return nil end
    return c > 0 and ("c" .. c) or ("s" .. spell)
end

-- Every recipe of the data shown here, by line: { [group] = { spell, ... } } (spells sorted).
local groupsCache, groupsOf
local function groups()
    local d = cdData()
    if groupsCache and groupsOf == d then return groupsCache end
    local out = {}
    for spell in pairs(d or {}) do
        local g = PC.Group(spell)
        if g then
            out[g] = out[g] or {}
            out[g][#out[g] + 1] = spell
        end
    end
    for _, list in pairs(out) do table.sort(list) end
    groupsCache, groupsOf = out, d
    return out
end
PC._groups = groups

local function spellName(spell)
    local api = _G.C_Spell
    local name = type(api) == "table" and ns.Plain(call(api.GetSpellName, spell)) or nil
    if type(name) ~= "string" or name == "" then name = ns.Plain(call(_G.GetSpellInfo, spell)) end
    return type(name) == "string" and name ~= "" and name or ("#" .. tostring(spell))
end
PC.SpellName = spellName

-- The name of a line: "Transmutation" for the transmutes, else the recipe's name from the client.
function PC.Label(spell)
    local c = PC.Info(spell)
    return c and CATEGORY_NAME[c] or spellName(spell)
end

---------------------------------------------------------------------------
-- The saved tables
---------------------------------------------------------------------------
local function profRoot(create)
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.prof) ~= "table" then
        if not create then return nil end
        AmisiaDB.prof = {}
    end
    return AmisiaDB.prof
end
local function ownStore(create)
    local p = profRoot(create)
    if not p then return nil end
    if type(p.cd) ~= "table" then
        if not create then return nil end
        p.cd = {}
    end
    return p.cd
end
local function heardStore(create)
    local p = profRoot(create)
    if not p then return nil end
    if type(p.cdHeard) ~= "table" then
        if not create then return nil end
        p.cdHeard = {}
    end
    return p.cdHeard
end

local function myName()
    local n = ns.UnitFullName and ns.UnitFullName("player")
    return validName(n) and n or nil
end
local function myRealm()
    return cleanText(ns.Plain(call(_G.GetRealmName)), 64)
end
local function myFaction()
    local f = ns.Plain(call(_G.UnitFactionGroup, "player"))
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

-- The spells of an entry ({ [spell] = epoch, ... } beside its other keys), by line: { [group] = spell }.
local function entryGroups(e)
    local out = {}
    for spell, at in pairs(e) do
        local g = type(spell) == "number" and whole(at) and PC.Group(spell)
        if g and (not out[g] or spell < out[g]) then out[g] = spell end
    end
    return out
end
PC._entryGroups = entryGroups

---------------------------------------------------------------------------
-- Reading the own cooldowns
---------------------------------------------------------------------------
-- Whether the profession window shows the own profession.
local function windowOwn()
    local T = _G.C_TradeSkillUI
    if type(T) ~= "table" or type(T.GetRecipeCooldown) ~= "function" then return false end
    if type(T.IsTradeSkillReady) == "function" and ns.Plain(call(T.IsTradeSkillReady)) ~= true then return false end
    for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        if ns.Plain(call(T[f])) == true then return false end
    end
    local frame = _G.TradeSkillFrame or _G.ProfessionsFrame
    return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() and true or false
end
PC._windowOwn = windowOwn

local function fromStartDuration(start, duration)
    start, duration = tonumber(ns.Plain(start)), tonumber(ns.Plain(duration))
    if not start or not duration then return nil end
    if duration <= LIM.gcd or start == 0 then return 0 end
    -- a start before the computer's uptime can come out odd: never more than the whole cooldown
    local left = math.min(start + duration - GetTime(), duration)
    return left > 0 and math.ceil(left) or 0
end

-- The seconds left of a recipe's cooldown as the client tells them (0 ready), nil when it says nothing.
-- Which way answered: "spell", "old" or "window".
function PC.Remaining(spell)
    local api = _G.C_Spell
    if type(api) == "table" and type(api.GetSpellCooldown) == "function" then
        local info = call(api.GetSpellCooldown, spell)
        if type(info) == "table" then
            local left = fromStartDuration(info.startTime, info.duration)
            if left then return left, "spell" end
        end
    end
    if type(_G.GetSpellCooldown) == "function" then
        local start, duration = call(_G.GetSpellCooldown, spell)
        local left = fromStartDuration(start, duration)
        if left then return left, "old" end
    end
    if windowOwn() then
        local ok, cd = pcall(_G.C_TradeSkillUI.GetRecipeCooldown, spell)
        cd = ok and tonumber(ns.Plain(cd)) or (ok and 0) or nil
        if cd then return math.max(0, math.ceil(cd)), "window" end
    end
    return nil
end

-- Whether the own character knows a recipe: true (a profession window read lists it, or the client says so),
-- false (the client says no and no reading lists it), nil (nothing to say).
local function knows(spell)
    local p = profRoot(false)
    local c = p and type(p.chars) == "table" and p.chars[myName() or "?"]
    if type(c) == "table" then
        for _, s in pairs(c) do
            if type(s) == "table" and type(s.known) == "table" and s.known[spell] then return true end
        end
    end
    if type(_G.IsPlayerSpell) ~= "function" then return nil end
    local ok, on = pcall(_G.IsPlayerSpell, spell)
    if not ok then return nil end
    return ns.Plain(on) == true
end
PC._knows = knows

-- Reads the own character's cooldowns into AmisiaDB.prof.cd. trigger: the recipe just crafted (it becomes its
-- line's recipe; without an answer of the client the data's hours count). Returns whether anything changed
-- by more than a minute (a line came, went or moved).
function PC.ReadOwn(trigger)
    local me = myName()
    if not me or type(AmisiaDB) ~= "table" then return false end
    -- the store is made only for a line to keep (a client without the functions stores nothing)
    local store = ownStore(false)
    local e = store and type(store[me]) == "table" and store[me] or {}
    e.realm = myRealm() or e.realm
    e.faction = myFaction() or e.faction
    local t, any = now(), false
    local stored = entryGroups(e)
    local tg = trigger and PC.Group(trigger)
    for g, spells in pairs(groups()) do
        -- the line's recipes the character knows; the crafted one always
        local known, no = {}, true
        for _, spell in ipairs(spells) do
            local k = spell == trigger or knows(spell)
            if k then known[#known + 1] = spell end
            if k ~= false then no = false end
        end
        local old = stored[g]
        if #known > 0 then
            local spell = (tg == g and trigger) or (old and (old == trigger or knows(old)) and old) or known[1]
            local left = PC.Remaining(spell)
            for _, other in ipairs(known) do
                if left ~= nil then break end
                left = PC.Remaining(other)
            end
            if left == nil and tg == g then
                local _, h = PC.Info(trigger)
                left = (h or 0) * 3600
            end
            if left ~= nil then
                left = math.min(left, LIM.secMax)
                local was = old and e[old]
                local at = left > 0 and (t + left) or ((was and was <= t) and was or t)
                if old ~= spell or not was or math.abs(at - was) > 60 then any = true end
                if old and old ~= spell then e[old] = nil end
                e[spell] = at
            end
        elseif no and old then
            -- verlernt: no reading lists it and the client says no
            e[old] = nil
            any = true
        end
    end
    if store and store[me] or next(entryGroups(e)) ~= nil then
        store = store or ownStore(true)
        store[me] = e
    end
    if any then
        changed()
        PC.Changed()
    end
    return any
end

---------------------------------------------------------------------------
-- The views: own characters, the guild, the item tooltip
---------------------------------------------------------------------------
-- The state of one line: seconds left (0 ready) from a ready-from epoch.
local function leftOf(at) return math.max(0, (at or 0) - now()) end
PC.LeftOf = leftOf

-- "bereit" (green) or "in 14 Std. 20 Min.".
function PC.TimeText(at)
    local left = leftOf(at)
    if left <= 0 then return "|cff4fbf7a" .. L["bereit"] .. "|r" end
    local m = math.ceil(left / 60)
    local h = math.floor(m / 60)
    m = m - h * 60
    if h > 0 then return L["in %d Std. %d Min."]:format(h, m) end
    return L["in %d Min."]:format(m)
end

local function sameRealm(e)
    local realm, fac = myRealm(), myFaction()
    if realm and e.realm and e.realm ~= realm then return false end
    if fac and e.faction and e.faction ~= fac then return false end
    return true
end

local function lineSort(a, b)
    if a.label ~= b.label then return a.label < b.label end
    return a.spell < b.spell
end

-- The own characters of this realm and faction with their lines: { { name, current, lines = { { group, spell,
-- label, at } } } }, the current character first, then by name; characters without a line left out.
function PC.Own()
    local store = ownStore(false)
    local out = {}
    if not store then return out end
    local me = myName()
    for name, e in pairs(store) do
        if type(e) == "table" and sameRealm(e) then
            local lines = {}
            for g, spell in pairs(entryGroups(e)) do
                lines[#lines + 1] = { group = g, spell = spell, label = PC.Label(spell), at = e[spell] }
            end
            if #lines > 0 then
                table.sort(lines, lineSort)
                out[#out + 1] = { name = name, current = name == me, lines = lines }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.name < b.name
    end)
    return out
end

-- The ready lines of the own characters: { { label, name } } (the login line and the chat's answer).
function PC.OwnReady()
    local out = {}
    for _, c in ipairs(PC.Own()) do
        for _, l in ipairs(c.lines) do
            if leftOf(l.at) <= 0 then out[#out + 1] = { label = l.label, name = c.name } end
        end
    end
    return out
end

local function isOwn(name)
    local store = ownStore(false)
    if not store then return false end
    for own in pairs(store) do
        if ns.SameName(own, name) then return true end
    end
    return false
end

-- The guild's lines: { { group, label, rows = { { name, class, online, spell, at } } } } by label; per line
-- the ready ones first, then online first, then by time left and name. Only names of the roster, never an own
-- character, nothing older than 7 days.
function PC.Guild()
    local heard = heardStore(false)
    local out, byGroup = {}, {}
    if not heard then return out end
    local t = now()
    for name, e in pairs(heard) do
        local m = type(e) == "table" and type(e.at) == "number" and t - e.at <= LIM.heardDays * 86400
            and ns.GuildMember and ns.GuildMember(name)
        if m and not isOwn(name) then
            for g, spell in pairs(entryGroups(e)) do
                local line = byGroup[g]
                if not line then
                    line = { group = g, label = PC.Label(spell), spell = spell, rows = {} }
                    byGroup[g] = line
                    out[#out + 1] = line
                end
                line.rows[#line.rows + 1] = { name = m.name, class = m.class, online = m.online and true or false,
                    spell = spell, at = e[spell] }
            end
        end
    end
    for _, line in ipairs(out) do
        table.sort(line.rows, function(a, b)
            local ra, rb = leftOf(a.at) <= 0, leftOf(b.at) <= 0
            if ra ~= rb then return ra end
            if a.online ~= b.online then return a.online end
            if not ra and a.at ~= b.at then return a.at < b.at end
            return a.name < b.name
        end)
    end
    table.sort(out, lineSort)
    return out
end

-- The item -> line map of the recipes with a cooldown (what they make). Builds the profession data only out of
-- combat (as the crafters' line); kept while the data stays.
local itemMap, itemMapOf
local function itemsOf()
    local d = ns.Data and ns.DataLoaded and ns.HasData("PROFESSIONS") and ns.Data("PROFESSIONS") or nil
    if not d then return nil end
    if itemMap and itemMapOf == d then return itemMap end
    local Pr, out = ns.Prof, {}
    for g, spells in pairs(groups()) do
        for _, spell in ipairs(spells) do
            local r = Pr and Pr.Recipe and Pr.Recipe(spell)
            if r and (r.item or 0) > 0 then out[r.item] = g end
        end
    end
    itemMap, itemMapOf = out, d
    return out
end

-- The item tooltip's line "Bereit in der Gilde: Ben, Clara" for an item a recipe with a cooldown makes, when
-- someone of the guild is ready (nil else).
local tipCache, tipRev = {}, -1
function PC.TooltipLine(item)
    item = tonumber(item)
    if not item or not cdData() then return nil end
    if tipRev ~= rev then tipCache, tipRev = {}, rev end
    local hit = tipCache[item]
    if hit and GetTime() - hit.at < LIM.tipKeep then return hit.line or nil end
    if not ns.DataLoaded("PROFESSIONS") and type(InCombatLockdown) == "function" and InCombatLockdown() then return nil end
    local map = itemsOf()
    local g = map and map[item]
    local line = false
    if g then
        for _, l in ipairs(PC.Guild()) do
            if l.group == g then
                local names = {}
                for _, r in ipairs(l.rows) do
                    if leftOf(r.at) <= 0 then names[#names + 1] = r.name end
                end
                if #names > 0 then
                    local shown = {}
                    for i = 1, math.min(4, #names) do shown[i] = names[i] end
                    local text = table.concat(shown, ", ")
                    if #names > 4 then text = text .. (" +%d"):format(#names - 4) end
                    line = L["Bereit in der Gilde: %s"]:format(text)
                end
            end
        end
    end
    tipCache[item] = { at = GetTime(), line = line }
    return line or nil
end

local TIP_GREY = { 0.56, 0.53, 0.64 }
local tipHooked = false
ns.OnEvent("ADDON_LOADED", function(name)
    if name ~= ns.ADDON or tipHooked or not ns.OnItemTooltip then return end
    tipHooked = true
    ns.OnItemTooltip("cooldowns", function(tip, _, id)
        if not ns.Get("prof.cdTooltip") then return false end
        local line = PC.TooltipLine(id)
        if not line then return false end
        tip:AddLine(line, TIP_GREY[1], TIP_GREY[2], TIP_GREY[3])
        return true
    end)
end)

---------------------------------------------------------------------------
-- The message PC
---------------------------------------------------------------------------
-- The fields of the own PC: "1", then "<character>:<spell>=<seconds>,..." of the own characters of this guild
-- (as AC: the main first), at most 10, each with at most 4 lines; what does not fit 250 bytes is left out. nil
-- without a line.
function PC.Fields()
    local store = ownStore(false)
    if not store or not ns.GuildCharsOwn then return nil end
    local list = ns.GuildCharsOwn()
    local me = myName()
    -- the current character even before its account entry names the guild
    local names, seen = {}, {}
    for _, c in ipairs(list) do
        names[#names + 1] = c.name
        seen[c.name] = true
    end
    if me and not seen[me] and ns.InGuild() then table.insert(names, 1, me) end
    local fields = { "1" }
    local size = #tostring(ns.SYNC_PROTO) + 2 + 1 + 1
    local max = ns.COMM_MAX_TEXT or 250
    for _, name in ipairs(names) do
        if #fields - 1 >= LIM.charsMax then break end
        local e = store[name]
        if type(e) == "table" and validName(name) then
            local parts = {}
            local lines = {}
            for _, spell in pairs(entryGroups(e)) do lines[#lines + 1] = spell end
            table.sort(lines)
            for i = 1, math.min(#lines, LIM.perChar) do
                parts[#parts + 1] = ("%d=%d"):format(lines[i], math.min(leftOf(e[lines[i]]), LIM.secMax))
            end
            if #parts > 0 then
                local s = name .. ":" .. table.concat(parts, ",")
                if size + 1 + #s <= max then
                    fields[#fields + 1] = s
                    size = size + 1 + #s
                end
            end
        end
    end
    if #fields < 2 then return nil end
    return fields
end

-- When PC may go: sharing on, messages, a guild, no lockdown; never inside an instance or a battleground, and
-- 5 to 15 s after leaving one (as the crafter exchange).
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
        outAt = GetTime() + LIM.outWait + math.random() * LIM.outSpread
    end
    if outAt and GetTime() >= outAt then outAt = nil end
    return outAt ~= nil
end
ns.OnEvent("PLAYER_ENTERING_WORLD", function() away() end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() away() end)

function PC.CanTalk()
    local out = away()
    if not AmisiaDB or not ns.Get("prof.cdShare") then return false end
    if not ns.CommAvailable() or not ns.InGuild() then return false end
    if ns.CommHeld() then return false end
    return not out
end
local canTalk = function() return PC.CanTalk() end

local dueAt, sentAt = nil, nil
-- An own change: PC goes once the first one went, at most once a minute.
function PC.Changed()
    if not sentAt then return end
    local at = math.max(GetTime(), sentAt + LIM.changeGap)
    if not dueAt or dueAt > at then dueAt = at end
end

local function trySend()
    if not dueAt or GetTime() < dueAt or not canTalk() then return false end
    dueAt = nil
    local fields = PC.Fields()
    sentAt = GetTime()
    if not fields then return false end
    return ns.CommSend("PC", fields, "GUILD", nil, { low = true, when = canTalk, key = "PC:GUILD" }) and true or false
end
PC._trySend = trySend

-- A name as the guild roster spells it, nil when it is not in the roster.
local function rosterName(n)
    local m = ns.GuildMember and ns.GuildMember(n)
    return m and m.name or nil
end

local function trimHeard(list)
    local all = {}
    for name, e in pairs(list) do all[#all + 1] = { name = name, at = type(e) == "table" and e.at or 0 } end
    if #all <= LIM.heardMax then return end
    table.sort(all, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.name < b.name
    end)
    for i = LIM.heardMax + 1, #all do list[all[i].name] = nil end
end

-- A member's PC: every field checked first (a spell outside the data, a time out of bounds, more than 4 lines
-- of a character, a line twice: the whole message goes); then each character the roster names, never an own
-- one, a character's own report over another sender's. Returns how many characters were taken.
function PC.Take(sender, f)
    if type(f) ~= "table" or f[1] ~= "1" or #f < 2 or #f > LIM.charsMax + 1 then return 0 end
    local parsed = {}
    for i = 2, #f do
        local raw, rest = f[i]:match("^([^:]+):(.+)$")
        if not raw or not validName(raw) then return 0 end
        local e, n, lines = {}, 0, {}
        for part in (rest .. ","):gmatch("([^,]*),") do
            local spell, sec = part:match("^(%d+)=(%d+)$")
            spell, sec = tonumber(spell), tonumber(sec)
            local g = spell and PC.Group(spell)
            if not g or not sec or sec > LIM.secMax or lines[g] then return 0 end
            lines[g] = true
            n = n + 1
            if n > LIM.perChar then return 0 end
            e[spell] = sec
        end
        parsed[#parsed + 1] = { raw = raw, lines = e }
    end
    local list = heardStore(true)
    if not list then return 0 end
    local t, took = now(), 0
    for _, p in ipairs(parsed) do
        local name = rosterName(p.raw)
        if name and not isOwn(name) then
            local old = list[name]
            local own = ns.SameName(name, sender)
            local oldOwn = type(old) == "table" and type(old.by) == "string" and ns.SameName(old.by, name)
            if own or not oldOwn then
                local e = { by = sender, at = t }
                for spell, sec in pairs(p.lines) do e[spell] = t + sec end
                list[name] = e
                took = took + 1
            end
        end
    end
    if took > 0 then
        trimHeard(list)
        changed()
    end
    return took
end

-- Only by GUILD, only from a member of the own guild.
ns.CommOn("PC", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok then PC.Take(name, f) end
    end)
end)

---------------------------------------------------------------------------
-- Events: the readings, the first PC, the login line
---------------------------------------------------------------------------
local readDue = false
local function readSoon(trigger)
    if readDue and not trigger then return end
    readDue = true
    C_Timer.After(LIM.readDelay, function()
        readDue = false
        PC.ReadOwn(trigger)
    end)
end

ns.OnEvent("TRADE_SKILL_SHOW", function() readSoon() end)
ns.OnEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spell)
    if ns.Plain(unit) ~= "player" then return end
    spell = tonumber(ns.Plain(spell))
    if spell and PC.Group(spell) then readSoon(spell) end
end)
-- a new reading of the profession window may drop an unlearned recipe's line
ns.Listen("PROF_CHANGED", function() readSoon() end)

-- The chat line of the login: the own ready lines, once per session.
function PC.LoginLine()
    local ready = PC.OwnReady()
    if #ready == 0 then return nil end
    local parts = {}
    for _, r in ipairs(ready) do parts[#parts + 1] = ("%s (%s)"):format(r.label, r.name) end
    return L["bereit: %s."]:format(table.concat(parts, ", "))
end

local entered = false
ns.OnEvent("PLAYER_ENTERING_WORLD", function(_, isReload)
    if entered then return end
    entered = true
    C_Timer.After(LIM.loginRead, function() PC.ReadOwn() end)
    -- the line once per login: a /reload says nothing again
    if ns.Plain(isReload) == true then return end
    C_Timer.After(LIM.loginLine, function()
        if not ns.Get("prof.cdLogin") then return end
        local line = PC.LoginLine()
        if line then ns.msg(line) end
    end)
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    if dueAt or sentAt then return end
    dueAt = GetTime() + LIM.firstMin + math.random() * LIM.firstSpread
end)

-- the first PC and every one after a change go from here, once they may (PC.CanTalk)
C_Timer.NewTicker(LIM.tick, ns.Perf.Wrap("Ticker ProfCooldowns", function() trySend() end))

-- /amisia abklingzeiten: the tab Abklingzeiten; without the page the own lines in the chat.
function PC.PrintOwn()
    local own = PC.Own()
    if #own == 0 then
        ns.msg(L["Keine Abklingzeiten bekannt. Öffne einmal dein Berufsfenster."])
        return
    end
    for _, c in ipairs(own) do
        local parts = {}
        for _, l in ipairs(c.lines) do parts[#parts + 1] = ("%s %s"):format(l.label, PC.TimeText(l.at)) end
        ns.msg(("%s: %s"):format(c.name, table.concat(parts, ", ")))
    end
end

ns.RegisterSlash("abklingzeiten", { en = "cooldowns", aliases = { "abklingzeit", "cd" }, desc = L["Berufs-Abklingzeiten deiner Charaktere und der Gilde"],
    run = function()
        if ns.ShowProfessions and ns.Prof and ns.Prof.Available() then
            ns.ShowProfessions("abklingzeiten")
        else
            PC.PrintOwn()
        end
    end })

---------------------------------------------------------------------------
-- On load: both tables checked
---------------------------------------------------------------------------
local function checkSpells(e)
    local seen = {}
    for k, v in pairs(e) do
        if type(k) == "number" then
            local g = PC.Group(k)
            if not g or not whole(v) or seen[g] then e[k] = nil else seen[g] = true end
        end
    end
    local n = 0
    for k in pairs(e) do if type(k) == "number" then n = n + 1 end end
    return n
end

function ns.ProfCooldownsLoaded(root)
    local p = type(root) == "table" and root.prof
    if type(p) ~= "table" then return end
    if p.cd ~= nil then
        if type(p.cd) ~= "table" then p.cd = nil else
            local keep = {}
            for name, e in pairs(p.cd) do
                if validName(name) and type(e) == "table" then
                    e.realm = cleanText(e.realm, 64)
                    e.faction = (e.faction == "A" or e.faction == "H") and e.faction or nil
                    for k in pairs(e) do
                        if type(k) ~= "number" and k ~= "realm" and k ~= "faction" then e[k] = nil end
                    end
                    if checkSpells(e) > 0 then keep[#keep + 1] = name else p.cd[name] = nil end
                else
                    p.cd[name] = nil
                end
            end
            if #keep > LIM.ownMax then
                table.sort(keep)
                for i = LIM.ownMax + 1, #keep do p.cd[keep[i]] = nil end
            end
        end
    end
    if p.cdHeard ~= nil then
        if type(p.cdHeard) ~= "table" then p.cdHeard = nil else
            local t = now()
            for name, e in pairs(p.cdHeard) do
                local ok = validName(name) and type(e) == "table" and whole(e.at) and t - e.at <= LIM.heardDays * 86400
                    and validName(e.by)
                if ok then
                    for k in pairs(e) do
                        if type(k) ~= "number" and k ~= "by" and k ~= "at" then e[k] = nil end
                    end
                    local n = checkSpells(e)
                    ok = n > 0 and n <= LIM.perChar
                end
                if not ok then p.cdHeard[name] = nil end
            end
            trimHeard(p.cdHeard)
        end
    end
    rev = rev + 1
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then ns.ProfCooldownsLoaded(AmisiaDB) end
end)
end)
