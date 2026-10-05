-- Amisia bench: raiders waiting outside on call, per raid (s.bench). Before the first recording of
-- a night the entries gather in AmisiaDB.benchNext and move into that night's recording when it
-- starts or resumes. A raider who comes from the bench is never late (Core's noteMember). Officers
-- enter names (suggested from the group outside, the guild and friends); raiders without the addon
-- sign up with !bench, which only the loot lead answers, by whisper.
local ADDON, ns = ...

local NOTE_MAX = 40
local IN_RAID_FOR = 600     -- seconds: a raider seen this recently counts as in the raid
local OUTSIDE_FOR = 600     -- seconds: the group outside suggested from s.outside
local GUILD_EVERY = 10      -- seconds between two guild roster requests
local MAX_NAME = 40
local MAX_BENCH = 40        -- entries per raid

-- "2026-10-05" -> "05.10."
local function shortDate(night)
    local _, m, d = tostring(night or ""):match("^(%d+)-(%d+)-(%d+)$")
    return d and (d .. "." .. m .. ".") or "?"
end

local function tonight() return ns.NightOf(time()) end

-- AmisiaDB.benchNext of the current night; one of an earlier night falls away.
local function benchNext(create)
    local DB = AmisiaDB
    if type(DB) ~= "table" then return nil end
    local b = DB.benchNext
    if b ~= nil and (type(b) ~= "table" or b.date ~= tonight()) then
        DB.benchNext = nil
        b = nil
    end
    if not b and create then
        b = { date = tonight(), list = {} }
        DB.benchNext = b
    end
    if b and type(b.list) ~= "table" then b.list = {} end
    return b
end

function ns.BenchLoaded() benchNext(false) end

-- The entries of a raid or of benchNext.
local function entries(s)
    if s.members then
        s.bench = type(s.bench) == "table" and s.bench or {}
        return s.bench
    end
    s.list = type(s.list) == "table" and s.list or {}
    return s.list
end

local function size(list)
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    return n
end

-- The words for a target in answers: "Schwarzer Tempel, 05.10." or "heute, 05.10.".
function ns.BenchLabel(s)
    if type(s) ~= "table" then return "?" end
    if s.members then return ("%s, %s"):format(s.zone or "?", shortDate(s.date)) end
    return "heute, " .. shortDate(s.date)
end

-- The running recording, else tonight's benchNext (created when missing).
function ns.BenchTarget()
    local s = ns.Active and ns.Active()
    if not s then s = benchNext(true) end
    if not s then return nil end
    return s, ns.BenchLabel(s)
end

-- Core: a recording of the night of benchNext takes its entries over.
function ns.TakeBenchNext(s)
    local b = benchNext(false)
    if not b or type(s) ~= "table" or b.date ~= s.date then return end
    local list = entries(s)
    local n = size(list)
    for name, e in pairs(b.list) do
        if not list[name] and n < MAX_BENCH then
            list[name] = e
            n = n + 1
        end
    end
    AmisiaDB.benchNext = nil
end

---------------------------------------------------------------------------
-- Rosters: group, guild, friends (every value through ns.Plain)
---------------------------------------------------------------------------
-- The group roster: { name, class, zone, online } of readable lines, and the own zone.
local function groupRows()
    local rows, me, here = {}, ns.UnitFullName("player"), nil
    for i = 1, GetNumGroupMembers() or 0 do
        local name, _, _, _, _, class, zone, online = GetRaidRosterInfo(i)
        name, class, zone, online = ns.Plain(name), ns.Plain(class), ns.Plain(zone), ns.Plain(online)
        local full = type(name) == "string" and ns.FullName(name)
        if full then
            rows[#rows + 1] = { name = full, class = type(class) == "string" and class or "", zone = zone, online = online and true or false }
            if here == nil and ns.SameName(full, me) then here = zone end
        end
    end
    return rows, here
end

-- The guild roster as { name, class, online }, or nil when it cannot be read (no function, nobody).
local function guildList()
    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then return nil end
    local ok, n = pcall(GetNumGuildMembers)
    n = ok and tonumber(ns.Plain(n)) or 0
    if n <= 0 then return nil end
    local out = {}
    for i = 1, n do
        local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        name, online, class = ns.Plain(name), ns.Plain(online), ns.Plain(class)
        local full = type(name) == "string" and ns.FullName(name)
        if full then
            out[#out + 1] = { name = full, class = type(class) == "string" and class or "", online = online and true or false }
        end
    end
    return out
end

-- Class tokens from localized class names, for the friend list.
local function classToken(localized)
    if type(localized) ~= "string" or localized == "" then return "" end
    for _, map in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(map) == "table" then
            for token, text in pairs(map) do
                if text == localized then return token end
            end
        end
    end
    return ""
end

local function friendList()
    local api = _G.C_FriendList
    if type(api) ~= "table" or type(api.GetNumFriends) ~= "function" or type(api.GetFriendInfoByIndex) ~= "function" then return {} end
    local ok, n = pcall(api.GetNumFriends)
    n = ok and tonumber(ns.Plain(n)) or 0
    local out = {}
    for i = 1, n do
        local okInfo, info = pcall(api.GetFriendInfoByIndex, i)
        if okInfo and type(info) == "table" then
            local name, connected = ns.Plain(info.name), ns.Plain(info.connected)
            local full = type(name) == "string" and ns.FullName(name)
            if full then
                out[#out + 1] = { name = full, class = classToken(ns.Plain(info.className)), online = connected and true or false }
            end
        end
    end
    return out
end

local requestedAt
-- Asks the client for a fresh guild roster, at most every 10 s; true when asked.
function ns.RequestGuildRoster()
    local api = _G.C_GuildInfo
    local fn = (type(api) == "table" and api.GuildRoster) or _G.GuildRoster
    if type(fn) ~= "function" then return false end
    local t = GetTime()
    if requestedAt and t - requestedAt < GUILD_EVERY then return false end
    requestedAt = t
    pcall(fn)
    return true
end

-- true, false, or nil when the guild roster cannot be read.
local function inGuild(name)
    local list = guildList()
    if not list then return nil end
    for _, m in ipairs(list) do
        if ns.SameName(m.name, name) then return true end
    end
    return false
end

local function classOf(name)
    for _, r in ipairs((groupRows())) do
        if ns.SameName(r.name, name) and r.class ~= "" then return r.class end
    end
    for _, m in ipairs(guildList() or {}) do
        if ns.SameName(m.name, name) and m.class ~= "" then return m.class end
    end
    for _, f in ipairs(friendList()) do
        if ns.SameName(f.name, name) and f.class ~= "" then return f.class end
    end
    return ""
end

---------------------------------------------------------------------------
-- The bench
---------------------------------------------------------------------------
-- Who stands in the raid of s: raiders seen in the last 10 minutes and, for the running recording,
-- whoever is online in the own zone right now; with the group as roster for ns.SameNameIn.
local function raidNow(s)
    local ctx = { names = {}, roster = {} }
    if not s.members then return ctx end
    local rows, here = groupRows()
    for i, r in ipairs(rows) do ctx.roster[i] = r.name end
    local t = time()
    for key, m in pairs(s.members) do
        if t - (m.last or 0) <= IN_RAID_FOR then ctx.names[#ctx.names + 1] = key end
    end
    if ns.Active and s == ns.Active() then
        for _, r in ipairs(rows) do
            if r.online and (here == nil or r.zone == here) then ctx.names[#ctx.names + 1] = r.name end
        end
    end
    return ctx
end

local function inRaid(s, name, ctx)
    ctx = ctx or raidNow(s)
    for _, key in ipairs(ctx.names) do
        if ns.SameNameIn(key, name, ctx.roster) then return true end
    end
    return false
end

-- The entry of name on the bench of s, and its key: the same spelling, else ns.SameNameIn with the
-- group and the full bench names as roster (a first name alone only when unique).
function ns.IsBenched(s, name)
    name = ns.FullName(ns.Plain(name))
    if not name or type(s) ~= "table" then return nil end
    local list = entries(s)
    if next(list) == nil then return nil end
    if list[name] then return list[name], name end
    local low = name:lower()
    for key, e in pairs(list) do
        if key:lower() == low then return e, key end
    end
    local roster, seen = {}, {}
    local function add(n)
        if not seen[n:lower()] then
            seen[n:lower()] = true
            roster[#roster + 1] = n
        end
    end
    for _, n in ipairs(ns.GroupRoster()) do add(n) end
    for key in pairs(list) do
        if key:find(" ", 1, true) then add(key) end
    end
    if name:find(" ", 1, true) then add(name) end
    local hit, hitKey
    for key, e in pairs(list) do
        if ns.SameNameIn(key, name, roster) then
            if hit then return nil end
            hit, hitKey = e, key
        end
    end
    return hit, hitKey
end

-- Adds or updates name on the bench of s (a raid or benchNext; nil: ns.BenchTarget()).
-- opts: { self = true for !bench, note, class }. Returns the entry and its key, or nil and the reason.
function ns.BenchAdd(s, name, opts)
    opts = type(opts) == "table" and opts or {}
    if s == nil then s = ns.BenchTarget() end
    if type(s) ~= "table" then return nil, "Kein Raid." end
    -- a benchNext held on to that is no longer tonight's (an earlier night, or taken over by a
    -- recording): the write goes to the current target
    if not s.members and (type(AmisiaDB) ~= "table" or s ~= AmisiaDB.benchNext or s.date ~= tonight()) then
        s = ns.BenchTarget()
        if type(s) ~= "table" then return nil, "Kein Raid." end
    end
    name = ns.FullName(ns.Plain(name))
    if not name or #name > MAX_NAME or name:find("[|%d]") then return nil, "Name fehlt." end
    if inRaid(s, name) then return nil, ("%s ist im Raid."):format(name) end
    local list = entries(s)
    local note = ns.CleanNote(opts.note, NOTE_MAX)
    local class = (type(opts.class) == "string" and opts.class ~= "") and opts.class or classOf(name)
    local e, key = ns.IsBenched(s, name)
    if not e and size(list) >= MAX_BENCH then return nil, ("Die Ersatzbank ist voll (%d)."):format(MAX_BENCH) end
    if e then
        if opts.self then e.self = true else e.by = ns.UnitFullName("player") end
        if note then e.note = note end
        if class ~= "" then e.class = class end
    else
        key = name
        e = { t = time(), class = class, note = note }
        if opts.self then e.self = true else e.by = ns.UnitFullName("player") end
        list[key] = e
    end
    ns.Fire("DATA_CHANGED")
    return e, key
end

function ns.BenchRemove(s, name)
    if type(s) ~= "table" then return nil, "Kein Raid." end
    local e, key = ns.IsBenched(s, name)
    if not e then
        return nil, ("%s steht nicht auf der Ersatzbank."):format(ns.FullName(ns.Plain(name)) or "?")
    end
    entries(s)[key] = nil
    ns.Fire("DATA_CHANGED")
    return true, key
end

-- { { name, e, joined } } sorted by name; joined: when a raider came from the bench into the raid.
function ns.BenchList(s)
    local out = {}
    if type(s) ~= "table" then return out end
    for name, e in pairs(entries(s)) do
        local joined
        local m = s.members and s.members[name]
        if not m and s.members then
            for key, x in pairs(s.members) do
                if ns.SameName(key, name) and (x.bench or (x.first or 0) >= (e.t or 0)) then m = x break end
            end
        end
        if m and (m.bench or (m.first or 0) >= (e.t or 0)) then joined = m.first end
        out[#out + 1] = { name = name, e = e, joined = joined }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Names to put on the bench of s for a picker: the group outside, the guild online, friends
-- online; without doubles, without whoever is benched or in the raid.
function ns.BenchSuggestions(s)
    local out, taken = {}, {}
    if type(s) ~= "table" then return out end
    local t = time()
    local ctx = raidNow(s)
    local function offer(list, suffix)
        table.sort(list, function(a, b) return a < b end)
        for _, name in ipairs(list) do
            local dup = false
            for _, x in ipairs(taken) do
                if ns.SameName(x, name) then dup = true break end
            end
            if not dup and not ns.IsBenched(s, name) and not inRaid(s, name, ctx) then
                taken[#taken + 1] = name
                out[#out + 1] = { value = name, text = ("%s (%s)"):format(name, suffix) }
            end
        end
    end
    local outside = {}
    for name, seen in pairs(s.outside or {}) do
        if type(seen) == "number" and t - seen <= OUTSIDE_FOR then outside[#outside + 1] = name end
    end
    offer(outside, "in der Gruppe, draußen")
    local guild = {}
    for _, m in ipairs(guildList() or {}) do
        if m.online then guild[#guild + 1] = m.name end
    end
    offer(guild, "Gilde")
    local friends = {}
    for _, f in ipairs(friendList()) do
        if f.online then friends[#friends + 1] = f.name end
    end
    offer(friends, "Freund")
    return out
end

---------------------------------------------------------------------------
-- !bench for raiders without the addon
---------------------------------------------------------------------------
local function notify(text)
    if ns.Get("raidlog.benchNotify") then ns.msg(text) end
end

-- No answers from a battleground or an arena.
local function inBattleground()
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    return kind == "pvp" or kind == "arena"
end

-- sender is the raw (plain) text the client gave; the answer goes back to it by whisper.
local function onBench(sender, rest)
    if not ns.Get("raidlog.benchChat") or not ns.IsLootLead() or inBattleground() then return end
    local name = ns.FullName(sender)
    if not name then return end
    if not ns.ReplyGate("bench", name:lower()) then return end
    local function reply(text) ns.Say(text, "WHISPER", sender, { ttl = 120 }) end
    local s, label = ns.BenchTarget()
    if not s then return end
    rest = rest or ""
    local word = rest:lower()
    local e, key = ns.IsBenched(s, name)
    if word == "?" then
        reply(e and ("Amisia: Du stehst auf der Ersatzbank (seit %s)."):format(date("%H:%M", e.t or time()))
            or "Amisia: Du stehst nicht auf der Ersatzbank.")
        return
    end
    local off = word == "aus" or word == "off" or word == "weg"
    local note = not off and ns.CleanNote(rest, NOTE_MAX) or nil
    local extra
    if ns.Get("raidlog.benchGuildOnly") then
        ns.RequestGuildRoster()
        local member = inGuild(name)
        if member == false then
            reply("Amisia: Die Ersatzbank ist nur für Gildenmitglieder.")
            return
        end
        if member == nil and not off and not note and not (e and e.note) then extra = "Gilde nicht geprüft" end
    end
    if off then
        -- only the sender's own entry: the same name, case aside, never a first name alone
        local own, ownKey
        local low = name:lower()
        for k, x in pairs(entries(s)) do
            if k:lower() == low then own, ownKey = x, k break end
        end
        if not own then
            reply("Amisia: Du stehst nicht auf der Ersatzbank.")
        elseif not own.self then
            reply("Amisia: Ein Offizier hat dich eingetragen. Frag bitte ihn.")
        else
            ns.BenchRemove(s, ownKey)
            reply("Amisia: Du stehst nicht mehr auf der Ersatzbank.")
            notify(("%s hat sich von der Ersatzbank ausgetragen."):format(ownKey))
        end
        return
    end
    local added, res = ns.BenchAdd(s, name, { self = true, note = note or extra })
    if not added then
        if type(res) == "string" and res:find("ist im Raid", 1, true) then reply("Amisia: Du bist schon im Raid.") end
        if type(res) == "string" and res:find("ist voll", 1, true) then reply("Amisia: Die Ersatzbank ist voll.") end
        return
    end
    reply(("Amisia: Du stehst auf der Ersatzbank (%s). Mit !bench aus trägst du dich aus.%s"):format(label,
        note and (" Notiz: %s."):format((note:gsub("[%.!?]+$", ""))) or ""))
    notify(("%s steht auf der Ersatzbank (selbst eingetragen)."):format(res))
end

ns.RegisterChatCommand("bench", onBench)
ns.RegisterChatCommand("ersatz", onBench)

---------------------------------------------------------------------------
-- Settings and /amisia ersatz
---------------------------------------------------------------------------
if ns.RaidLogSettings then
    for _, it in ipairs({
        { key = "raidlog.benchChat", type = "toggle", label = "Auf !bench antworten", default = true, officer = true,
          tip = "Nur als Lootleitung, per Flüsterung." },
        { key = "raidlog.benchGuildOnly", type = "toggle", label = "!bench nur für Gildenmitglieder", default = true, officer = true },
        { key = "raidlog.benchNotify", type = "toggle", label = "Neue Einträge der Ersatzbank im Chat melden", default = true, officer = true },
    }) do
        table.insert(ns.RaidLogSettings.items, it)
    end
    ns.RegisterSettings(ns.RaidLogSettings)
end

-- "Vulo Sturmwind ab 21 Uhr": the name is the first word, or the first two when exactly those
-- two make a known name (suggestions, bench, group, guild); the rest is the note.
local function splitNameNote(rest, s)
    local w1, w2, more = rest:match("^(%S+)%s+(%S+)%s*(.*)$")
    if w1 then
        local two = (w1 .. " " .. w2):lower()
        local known = {}
        for _, x in ipairs(ns.BenchSuggestions(s)) do known[#known + 1] = x.value end
        for name in pairs(entries(s)) do known[#known + 1] = name end
        for _, r in ipairs((groupRows())) do known[#known + 1] = r.name end
        for _, m in ipairs(guildList() or {}) do known[#known + 1] = m.name end
        for _, n in ipairs(known) do
            if n:lower() == two then return n, more ~= "" and more or nil end
        end
    end
    local name, note = rest:match("^(%S+)%s*(.*)$")
    return name, note ~= "" and note or nil
end

local function printBench(s, label)
    local names = {}
    for _, x in ipairs(ns.BenchList(s)) do
        names[#names + 1] = x.name .. (x.e.note and (" (" .. x.e.note .. ")") or "")
    end
    ns.msg(("Ersatzbank (%s): %s."):format(label, #names > 0 and table.concat(names, ", ") or "niemand"))
end

ns.RegisterSlash("ersatz", { aliases = { "bench" }, officer = true, args = "[Name] [Notiz] | weg <Name>",
    desc = "Ersatzbank: eintragen, austragen oder anzeigen", run = function(rest)
        if not ns.IsOfficerView() then
            ns.msg("Ersatzbank nur in der Offiziersansicht.")
            return
        end
        rest = (rest or ""):match("^%s*(.-)%s*$")
        local s, label = ns.BenchTarget()
        if not s then return end
        if rest == "" then
            if ns.ShowRaidLog then ns.ShowRaidLog("bench") else printBench(s, label) end
            return
        end
        local first, after = rest:match("^(%S+)%s*(.*)$")
        local fl = first:lower()
        if fl == "weg" or fl == "remove" then
            if after == "" then
                ns.msg("Aufruf: /amisia ersatz weg <Name>")
                return
            end
            local ok, res = ns.BenchRemove(s, after)
            ns.msg(ok and ("%s steht nicht mehr auf der Ersatzbank."):format(res) or res)
            return
        end
        local name, note = splitNameNote(rest, s)
        local e, key = ns.BenchAdd(s, name, { note = note })
        if not e then
            ns.msg(key)
            return
        end
        ns.msg(("%s steht auf der Ersatzbank (%s)%s."):format(key, label, e.note and (", Notiz: " .. e.note) or ""))
    end })
