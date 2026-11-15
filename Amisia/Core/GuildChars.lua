-- Amisia guild characters (F-210, D-135): which characters of the guild belong to one player and their
-- item levels, for the members page only. Sources: the own characters of this account (AmisiaDB.account,
-- read at login and after an equipment change), the message AC that every member's Amisia sends to the
-- guild once per session with its hello (Core/Version.lua: the main and up to 10 "Name:Itemlevel"),
-- the item level the player tooltip read (UI/UnitInfo.lua) and the guild notes ("Twink von X", "X Twink",
-- "Twink: X", "Main: X", "alt of X", "X's alt", or exactly another member's name). For the display
-- the website's alt list (Raid/Alts.lua) comes first, then a character's own report, then another's,
-- then the notes. ns.MainOf, ns.AltMain and ns.AltsOf stay with the website's list: points, loot prio,
-- lineup and soft-reserves never read this file.
local ADDON, ns = ...
ns.Load(function()

local ACCOUNT_MAX = 50       -- own characters kept
local LIST_MAX, LIST_DAYS = 1000, 60
local ENTRIES_MAX = 10       -- characters of one AC
local EQUIP_GAP = 10         -- seconds between two readings after equipment changes
local NAME_MAX = 48

local rev = 0                -- grows with every change of account or guildChars (the members page's cache)
function ns.GuildCharsRev() return rev end
local function changed()
    rev = rev + 1
    ns.FireSoon("GUILD_CHARS")
end

-- A character's name as the message and the saved data allow it: no digits, commas, colons, bars or
-- control characters, at most 48 bytes.
local function validName(v)
    return type(v) == "string" and v ~= "" and #v <= NAME_MAX and not v:find("[%c,:|%d]") and ns.FullName(v) == v
end
ns.GuildCharName = validName

local function validIl(v) return type(v) == "number" and v >= 1 and v <= 999 and v == math.floor(v) end

---------------------------------------------------------------------------
-- The saved tables
---------------------------------------------------------------------------
local function account()
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.account) ~= "table" then AmisiaDB.account = { v = 1, chars = {} } end
    local a = AmisiaDB.account
    if type(a.chars) ~= "table" then a.chars = {} end
    return a
end

local function guildList()
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.guildChars) ~= "table" then AmisiaDB.guildChars = { v = 1, list = {} } end
    local g = AmisiaDB.guildChars
    if type(g.list) ~= "table" then g.list = {} end
    return g.list
end

-- The newest max entries of a name -> { at } table stay.
local function trimTo(t, max)
    local list = {}
    for name, e in pairs(t) do list[#list + 1] = { name = name, at = e.at } end
    if #list <= max then return end
    table.sort(list, function(a, b)
        if a.at ~= b.at then return a.at > b.at end
        return a.name < b.name
    end)
    for i = max + 1, #list do t[list[i].name] = nil end
end

local function plainNum(v)
    v = tonumber(ns.Plain(v))
    return v
end

---------------------------------------------------------------------------
-- The own characters of this account
---------------------------------------------------------------------------
local function ownGuild()
    if not ns.InGuild() then return nil end
    local g = ns.Plain((GetGuildInfo("player")))
    return type(g) == "string" and g ~= "" and #g <= 64 and not g:find("[%c|]") and g or nil
end
ns.GuildCharsOwnGuild = ownGuild

-- The own item level: the client's equipped average, else the player tooltip's reading.
local function ownIl()
    local il
    local fn = _G.GetAverageItemLevel
    if type(fn) == "function" then
        local ok, avg, equipped = pcall(fn)
        if ok then il = plainNum(equipped) or plainNum(avg) end
    end
    if (not il or il <= 0) and ns.UnitInfo and ns.UnitInfo.Own then
        local ok, e = pcall(ns.UnitInfo.Own)
        il = ok and e and e.ilvl or nil
    end
    il = il and math.floor(il) or nil
    return validIl(il) and il or nil
end

-- Reads the own character into AmisiaDB.account (class, level, item level, guild, now).
function ns.GuildCharsReadOwn()
    local a = account()
    local name = ns.UnitFullName("player")
    if not a or not validName(name) then return nil end
    local _, class = UnitClass("player")
    class = ns.Plain(class)
    local level = plainNum(UnitLevel("player"))
    local e = a.chars[name] or {}
    e.class = type(class) == "string" and class:match("^%u+$") and class or e.class
    e.level = (level and level >= 1 and level <= 99) and math.floor(level) or e.level
    e.il = ownIl() or e.il
    -- right after the login the client may not name the guild yet: the old name stays while in a guild
    local guild = ownGuild()
    if guild or not ns.InGuild() then e.guild = guild end
    e.at = time()
    a.chars[name] = e
    trimTo(a.chars, ACCOUNT_MAX)
    changed()
    return e
end

-- The main of a list of { name, level, il }: the highest level, then the higher item level, then the name.
local function better(x, y)
    if (x.level or 0) ~= (y.level or 0) then return (x.level or 0) > (y.level or 0) end
    if (x.il or 0) ~= (y.il or 0) then return (x.il or 0) > (y.il or 0) end
    return x.name < y.name
end

-- The own characters of a guild (the own guild by default), the main first, then by level, then by
-- name: { { name, class, level, il, at } }, and the main's name.
function ns.GuildCharsOwn(guild)
    guild = guild or ownGuild()
    local a = account()
    local out = {}
    if not a or not guild then return out, nil end
    for name, e in pairs(a.chars) do
        if type(e) == "table" and e.guild == guild then
            out[#out + 1] = { name = name, class = e.class, level = e.level, il = e.il, at = e.at }
        end
    end
    if #out == 0 then return out, nil end
    local main = out[1]
    for _, c in ipairs(out) do if better(c, main) then main = c end end
    table.sort(out, function(x, y)
        if (x == main) ~= (y == main) then return x == main end
        if (x.level or 0) ~= (y.level or 0) then return (x.level or 0) > (y.level or 0) end
        return x.name < y.name
    end)
    return out, main.name
end

-- At login and entering the world, after a level up and a guild change; after equipment changes at
-- most every 10 s.
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_GUILD_UPDATE" }) do
    ns.OnEvent(event, function() ns.GuildCharsReadOwn() end)
end
local equipAt, equipDue
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", function()
    if equipDue then return end
    local wait = equipAt and math.max(0, EQUIP_GAP - (GetTime() - equipAt)) or 0
    equipDue = true
    C_Timer.After(wait, function()
        equipDue = false
        equipAt = GetTime()
        ns.GuildCharsReadOwn()
    end)
end)

---------------------------------------------------------------------------
-- The message AC
---------------------------------------------------------------------------
-- The fields of the own AC: the main, then "Name:Itemlevel" ("-" without one) of the own characters of
-- this guild (the main first, then by level), at most 10, those that do not fit the message's bytes
-- left out. nil without a guild or characters.
function ns.GuildCharsFields()
    local list, main = ns.GuildCharsOwn()
    if not main then return nil end
    local fields = { main }
    local size = #tostring(ns.SYNC_PROTO) + 2 + 1 + #main
    local max = ns.COMM_MAX_TEXT or 250
    for _, c in ipairs(list) do
        if #fields - 1 >= ENTRIES_MAX then break end
        local s = c.name .. ":" .. (validIl(c.il) and tostring(c.il) or "-")
        if size + 1 + #s <= max then
            fields[#fields + 1] = s
            size = size + 1 + #s
        end
    end
    if #fields < 2 then return nil end
    return fields
end

-- Right after the guild hello went (Core/Version.lua: once per session, not after a /reload within 30
-- minutes): the own characters to the guild.
function ns.GuildCharsHello()
    if not ns.CommAvailable() then return nil end
    ns.GuildCharsReadOwn()
    local fields = ns.GuildCharsFields()
    if not fields then return nil end
    return ns.CommSend("AC", fields, "GUILD", nil, { key = "AC:GUILD", ttl = 120 })
end

-- A name as the guild roster spells it, nil when it is not in the roster.
local function rosterName(n)
    local m = ns.GuildMember(n)
    return m and m.name or nil
end

local function take(sender, f)
    local list = guildList()
    if not list then return end
    local main = rosterName(f[1]) or ns.FullName(f[1])
    local t, any = time(), false
    for i = 2, #f do
        local raw, il = f[i]:match("^(.+):([%d%-]+)$")
        local name = raw and rosterName(raw)
        if name then
            local own = ns.SameName(name, sender)
            local e = list[name]
            -- a character's own report wins over another's (as long as it is kept)
            if own or type(e) ~= "table" or not e.self then
                e = type(e) == "table" and e or {}
                e.main = main
                local n = tonumber(il)
                if validIl(n) then e.il = n end
                e.at, e.by, e.self = t, sender, own or nil
                list[name] = e
                any = true
            end
        end
    end
    if any then
        trimTo(list, LIST_MAX)
        changed()
    end
end

-- Only from a member of the own guild, only names of the guild roster.
ns.CommOn("AC", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok then take(name, f) end
    end)
end)

-- The item level the player tooltip read for a member of the guild (UI/UnitInfo.lua); its main stays.
function ns.GuildCharsInspected(name, il)
    if not validIl(il) then return end
    name = rosterName(name)
    local list = name and guildList()
    if not list then return end
    local e = type(list[name]) == "table" and list[name] or {}
    e.il, e.at = il, time()
    list[name] = e
    trimTo(list, LIST_MAX)
    changed()
end

---------------------------------------------------------------------------
-- On load: both tables made and checked
---------------------------------------------------------------------------
function ns.GuildCharsLoaded(DB)
    if type(DB.account) ~= "table" then DB.account = {} end
    local a = DB.account
    a.v = 1
    if type(a.chars) ~= "table" then a.chars = {} end
    for name, e in pairs(a.chars) do
        if not validName(name) or type(e) ~= "table" or type(e.at) ~= "number" then
            a.chars[name] = nil
        else
            if type(e.class) ~= "string" or not e.class:match("^%u+$") or #e.class > 20 then e.class = nil end
            if type(e.level) ~= "number" or e.level < 1 or e.level > 99 or e.level ~= math.floor(e.level) then e.level = nil end
            if not validIl(e.il) then e.il = nil end
            if type(e.guild) ~= "string" or e.guild == "" or #e.guild > 64 or e.guild:find("[%c|]") then e.guild = nil end
        end
    end
    trimTo(a.chars, ACCOUNT_MAX)

    if type(DB.guildChars) ~= "table" then DB.guildChars = {} end
    local g = DB.guildChars
    g.v = 1
    if type(g.list) ~= "table" then g.list = {} end
    local t = time()
    for name, e in pairs(g.list) do
        if not validName(name) or type(e) ~= "table" or type(e.at) ~= "number" or t - e.at > LIST_DAYS * 86400 then
            g.list[name] = nil
        else
            if e.main ~= nil and not validName(e.main) then e.main = nil end
            if not validIl(e.il) then e.il = nil end
            if e.by ~= nil and not validName(e.by) then e.by = nil end
            e.self = e.self == true or nil
            if not e.main and not e.il then g.list[name] = nil end
        end
    end
    trimTo(g.list, LIST_MAX)
    rev = rev + 1
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.GuildCharsLoaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Guild notes
---------------------------------------------------------------------------
-- the words a note uses, German and English alike (matched lower-case; never shown)
local NOTE_PATTERNS = {
    "^twink von (.+)$", "^twink:%s*(.+)$", "^main:%s*(.+)$", "^alt of (.+)$", "^(.+)'s alt$", "^(.+) twink$", -- l10n-ok: note words
}

-- A roster index: low = lower name -> member, first = lower first name -> { n = members, m = member }.
local function rosterIndex(roster)
    local idx = { low = {}, first = {} }
    for _, m in ipairs(roster) do
        if type(m.name) == "string" then
            local low = m.name:lower()
            idx.low[low] = m
            local f = low:match("^(%S+)")
            local e = idx.first[f]
            if e then e.n = e.n + 1 else idx.first[f] = { n = 1, m = m } end
        end
    end
    return idx
end

-- The member a text names: a full name (any case), or a first name only one member carries.
local function named(idx, text)
    text = ns.FullName(text)
    if not text then return nil end
    local low = text:lower()
    if idx.low[low] then return idx.low[low] end
    if low:find(" ", 1, true) then return nil end
    local e = idx.first[low]
    return e and e.n == 1 and e.m or nil
end

-- The main a note names for member m (the public note first, then the officer note), nil for none.
local function noteMain(idx, m)
    for i = 1, 2 do
        local note = i == 1 and m.note or m.officerNote
        if type(note) == "string" then
            local text = ns.StripCodes(note):match("^%s*(.-)[%s%.!]*$"):lower()
            if text ~= "" then
                local cands = { text }
                for _, p in ipairs(NOTE_PATTERNS) do
                    local x = text:match(p)
                    if x then cands[#cands + 1] = x:match("^%s*(.-)%s*$") end
                end
                for _, c in ipairs(cands) do
                    local hit = named(idx, c)
                    if hit and hit.name:lower() ~= m.name:lower() then return hit.name end
                end
            end
        end
    end
    return nil
end

-- The main a note of a member names (for the tests and the tooltip): roster is ns.GuildRoster's list.
function ns.GuildCharsNoteMain(roster, m)
    return noteMain(rosterIndex(roster), m)
end

---------------------------------------------------------------------------
-- The members page's view
---------------------------------------------------------------------------
local built = {}

-- For every member of the roster: { main = name or nil, src = "site"/"amisia"/"note", il, ilAt }
-- by lower name. main is nil for a main or a character without a known main. The website's list
-- first, then the character's own report (or the own account), then another's report, then the
-- notes. A main of a main is followed (one player, one group); a loop ends without a main.
function ns.GuildCharsView(roster)
    roster = roster or (ns.GuildRoster and ns.GuildRoster())
    if not roster then return {} end
    local alts = type(AmisiaDB) == "table" and AmisiaDB.alts or nil
    local b = built
    if b.view and b.roster == roster and b.rev == rev and b.alts == alts and b.db == AmisiaDB then return b.view end
    local idx = rosterIndex(roster)
    local list = guildList() or {}
    local own, ownMain = ns.GuildCharsOwn()
    local ownSet = {}
    for _, c in ipairs(own) do ownSet[c.name:lower()] = c end
    local function inRoster(n) return n and (idx.low[n:lower()] or named(idx, n)) end
    local function spelled(n)
        local m = inRoster(n)
        return m and m.name or n
    end
    local direct = {}
    local view = {}
    for _, m in ipairs(roster) do
        if type(m.name) == "string" then
            local low = m.name:lower()
            local v = {}
            local site = ns.AltMain and ns.AltMain(m.name)
            if site then
                v.main, v.src = spelled(site), "site"
            elseif ns.AltsOf and #ns.AltsOf(m.name) > 0 then
                v.isMain = true
            elseif ownSet[low] and ownMain then
                v.main, v.src = ownMain, "amisia"
            else
                -- stored under the roster's spelling (take, ns.GuildCharsInspected)
                local e = list[m.name]
                if type(e) == "table" and e.main then
                    v.main, v.src = spelled(e.main), "amisia"
                else
                    local nm = noteMain(idx, m)
                    if nm then v.main, v.src = nm, "note" end
                end
                if type(e) == "table" and e.il then v.il, v.ilAt = e.il, e.at end
            end
            local o = ownSet[low]
            if o and o.il and (not v.ilAt or (o.at or 0) >= v.ilAt) then v.il, v.ilAt = o.il, o.at end
            if not v.il then
                local e = list[m.name]
                if type(e) == "table" and e.il then v.il, v.ilAt = e.il, e.at end
            end
            if v.main and v.main:lower() == low then v.main, v.src = nil, nil end
            direct[low] = v.main
            view[low] = v
        end
    end
    -- a main of a main: the top one (at most 5 steps; a loop leaves the character without one)
    for low, v in pairs(view) do
        if v.main then
            local top, seen, steps = v.main, { [low] = true }, 0
            while direct[top:lower()] and steps < 5 do
                if seen[top:lower()] then top = nil break end
                seen[top:lower()] = true
                top, steps = direct[top:lower()], steps + 1
            end
            if not top or top:lower() == low or direct[top:lower()] then v.main, v.src = nil, nil else v.main = top end
        end
    end
    built = { view = view, roster = roster, rev = rev, alts = alts, db = AmisiaDB }
    return view
end
end)
