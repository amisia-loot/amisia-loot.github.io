-- Amisia version check: which Amisia version the guild and the raid run. One hello (HI) into the
-- guild per session after the login and one into the raid on entering it or starting a recording;
-- a question (VQ) on request, answered by whisper after a random delay. Only senders of the own
-- guild count. A newer version is pointed out once per version, and only when an officer or two
-- members run it.
local ADDON, ns = ...

local GUILD_HELLO_AFTER, GUILD_HELLO_SPREAD = 20, 40   -- seconds after the login: 20 to 60
local HELLO_KEEP = 1800      -- seconds a guild hello holds over a /reload
local RAID_HELLO_GAP = 120
local RAID_ASK_GAP, GUILD_ASK_GAP = 30, 300
local NO_ANSWER_AFTER = 10   -- seconds after a raid question that a silent member counts as "kein Amisia?"
local SEEN_DAYS, SEEN_MAX = 30, 300

local helloDone = false
local raidHelloAt, raidHelloKey
local wasInRaid = false
local askedAt = {}           -- "raid"|"guild" -> GetTime() of the last question
local warnedOld = {}         -- name -> true: "too old for the keeper" said once

local function now() return GetTime() end

local function homeRaid()
    if _G.LE_PARTY_CATEGORY_HOME then return IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false end
    return IsInRaid() and true or false
end

local function inGuild()
    return type(_G.IsInGuild) == "function" and IsInGuild() and true or false
end

-- AmisiaDB.sync, made when missing.
local function db()
    if type(AmisiaDB) ~= "table" then return nil end
    if type(AmisiaDB.sync) ~= "table" then AmisiaDB.sync = { v = 1 } end
    local d = AmisiaDB.sync
    if type(d.seen) ~= "table" then d.seen = {} end
    return d
end

local function versionOn()
    return ns.CommAvailable() and ns.Get("sync.versionCheck") ~= false
end

---------------------------------------------------------------------------
-- Versions
---------------------------------------------------------------------------
local function numbers(v)
    local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)$")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- -1, 0 or 1 as version a is older, the same or newer than b ("2.1.0"; anything else counts as 0.0.0).
function ns.CompareVersion(a, b)
    local x, y = { numbers(a) }, { numbers(b) }
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] < y[i] and -1 or 1 end
    end
    return 0
end

---------------------------------------------------------------------------
-- The hello
---------------------------------------------------------------------------
-- "O" officer view, "L" loot lead, "-" neither.
local function ownFlags()
    local f = ""
    if ns.IsOfficerView() then f = f .. "O" end
    if ns.IsLootLead and ns.IsLootLead() then f = f .. "L" end
    return f ~= "" and f or "-"
end

local function ownKey()
    local s = ns.Active and ns.Active()
    return (s and ns.RaidKey) and ns.RaidKey(s) or "-"
end

local function hello(chan, target, opts)
    if not versionOn() then return nil end
    return ns.CommSend("HI", { ns.VERSION, tostring(ns.SYNC_MIN_PROTO), ownFlags(), ownKey() }, chan, target, opts)
end

-- Once per session, 20 to 60 s after the login, not again after a /reload within 30 minutes.
ns.OnEvent("PLAYER_LOGIN", function()
    if helloDone then return end
    helloDone = true
    C_Timer.After(GUILD_HELLO_AFTER + math.random() * GUILD_HELLO_SPREAD, function()
        local d = db()
        if not d or not inGuild() then return end
        local t = time()
        if type(d.helloAt) == "number" and t >= d.helloAt and t - d.helloAt < HELLO_KEEP then return end
        if hello("GUILD", nil, { key = "HI:GUILD", ttl = 120 }) then d.helloAt = t end
    end)
end)

-- Into the own raid group, at most once in 2 minutes (sooner when the raid key changed).
local function raidHello()
    if not homeRaid() then return end
    local key, t = ownKey(), now()
    if raidHelloAt and t - raidHelloAt < RAID_HELLO_GAP and key == raidHelloKey then return end
    if hello("RAID", nil, { key = "HI:RAID" }) then raidHelloAt, raidHelloKey = t, key end
end

local function scheduleRaidHello()
    C_Timer.After(1 + math.random() * 4, raidHello)
end

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local inRaid = homeRaid()
    if inRaid and not wasInRaid then scheduleRaidHello() end
    wasInRaid = inRaid
end)

ns.Listen("RECORDING", function(s)
    if s then scheduleRaidHello() end
end)

---------------------------------------------------------------------------
-- The question
---------------------------------------------------------------------------
-- "1 Minute" or "n Minuten", rounded up (whole seconds first: clock steps leave fractions).
local function minutes(seconds)
    local n = math.max(1, math.ceil(math.floor(seconds + 0.5) / 60))
    return n == 1 and "1 Minute" or (n .. " Minuten")
end
ns.VersionMinutes = minutes

-- Seconds until the guild may be asked again (0: now).
function ns.VersionGuildWait()
    local at = askedAt.guild
    if not at then return 0 end
    return math.max(0, GUILD_ASK_GAP - (now() - at))
end

-- Asks "raid" or "guild" for their versions: true, or nil and the reason.
function ns.VersionAsk(where)
    if not ns.CommAvailable() then return nil, "Addon-Nachrichten sind nicht verfügbar." end
    if ns.Get("sync.versionCheck") == false then return nil, "Versionsprüfung ist ausgeschaltet." end
    local t = now()
    local chan
    if where == "raid" then
        if not homeRaid() then return nil, "Du bist in keiner Raidgruppe." end
        if askedAt.raid and t - askedAt.raid < RAID_ASK_GAP then return nil, "Der Raid wurde gerade gefragt." end
        chan = "RAID"
    elseif where == "guild" then
        if not inGuild() then return nil, "Du bist in keiner Gilde." end
        local wait = ns.VersionGuildWait()
        if wait > 0 then return nil, ("Die Gilde wurde gerade gefragt. Noch %s."):format(minutes(wait)) end
        chan = "GUILD"
    else
        return nil, "Unbekanntes Ziel."
    end
    local ok, why = ns.CommSend("VQ", { ("%04x"):format(math.random(0, 65535)) }, chan)
    if not ok then return nil, why end
    askedAt[where] = t
    ns.Fire("SYNC_VERSIONS")
    -- the silent members show once the answers had their time
    if where == "raid" then C_Timer.After(NO_ANSWER_AFTER + 0.1, function() ns.Fire("SYNC_VERSIONS") end) end
    return true
end

-- Every guild member answers by whisper: in the raid after 0 to 3 s, in the guild after 1 to 15 s.
-- The message layer handles one question per asker in 5 minutes.
ns.CommOn("VQ", function(sender, fields, chan)
    if not versionOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not versionOn() then return end
        -- the queue ticks every 0.25 s: the spread leaves room for one tick
        if chan == "GUILD" then
            C_Timer.After(1, function() hello("WHISPER", sender, { jitter = 13.75, ttl = 120 }) end)
        else
            hello("WHISPER", sender, { jitter = 2.75 })
        end
    end)
end)

---------------------------------------------------------------------------
-- What was seen
---------------------------------------------------------------------------
local function trim(d)
    local list = {}
    for name, e in pairs(d.seen) do list[#list + 1] = { name = name, at = e.at } end
    if #list <= SEEN_MAX then return end
    table.sort(list, function(a, b) return a.at < b.at end)
    for i = 1, #list - SEEN_MAX do d.seen[list[i].name] = nil end
end

-- Every version seen: { name, v, p, mp, flags, k, o, where = "raid"|"guild", at }, the raid first
-- (by name), then the guild (newest first).
function ns.VersionSeen()
    local out, d = {}, db()
    if not d then return out end
    for name, e in pairs(d.seen) do
        if type(name) == "string" and type(e) == "table" then
            out[#out + 1] = { name = name, v = e.v, p = e.p, mp = e.mp, flags = e.flags, k = e.k, o = e.o,
                              where = ns.InMyGroup(name) and "raid" or "guild", at = e.at }
        end
    end
    table.sort(out, function(a, b)
        if a.where ~= b.where then return a.where == "raid" end
        if a.where == "raid" or (a.at or 0) == (b.at or 0) then return a.name:lower() < b.name:lower() end
        return (a.at or 0) > (b.at or 0)
    end)
    return out
end

-- The highest version above the own one that counts (run by an officer, or by two members), and
-- who runs it; nil when there is none.
function ns.VersionNewer()
    local cands = {}
    for _, e in ipairs(ns.VersionSeen()) do
        if ns.CompareVersion(e.v, ns.VERSION) > 0 then cands[#cands + 1] = e end
    end
    table.sort(cands, function(a, b)
        local c = ns.CompareVersion(a.v, b.v)
        if c ~= 0 then return c > 0 end
        return (a.at or 0) > (b.at or 0)
    end)
    for _, c in ipairs(cands) do
        local members, officer = 0, nil
        for _, e in ipairs(cands) do
            if ns.CompareVersion(e.v, c.v) >= 0 then
                members = members + 1
                if e.o and not officer then officer = e.name end
            end
        end
        if officer or members >= 2 then return c.v, officer or c.name end
    end
    return nil
end

local function checkNewer()
    if ns.Get("sync.outdatedWarn") == false then return end
    local v, name = ns.VersionNewer()
    local d = db()
    if not v or not d then return end
    if type(d.warned) == "string" and ns.CompareVersion(v, d.warned) <= 0 then return end
    d.warned = v
    ns.msg(("Es gibt eine neuere Version (%s, gesehen bei %s). Du hast %s."):format(v, name, ns.VERSION))
end

local function record(name, e)
    local d = db()
    if not d then return end
    d.seen[name] = e
    trim(d)
    if (e.mp or 0) > ns.SYNC_PROTO and e.flags:find("L", 1, true) and not warnedOld[name] then
        warnedOld[name] = true
        ns.msg(("Deine Version ist zu alt für den Abgleich mit %s. Bitte aktualisieren."):format(name))
    end
    checkNewer()
    ns.Fire("SYNC_VERSIONS", name)
end

ns.CommOn("HI", function(sender, f, chan, raw)
    local name = ns.TrustName(sender)
    if not name then return end
    local proto = tonumber(tostring(raw):sub(1, 1)) or 0
    ns.TrustWait(name, "member", function(ok)
        if not ok then return end
        record(name, { v = f[1], p = proto, mp = tonumber(f[2]) or 0, flags = f[3], k = f[4] ~= "-" and f[4] or nil,
                       where = ns.InMyGroup(name) and "raid" or "guild", at = time(),
                       o = ns.IsVerifiedOfficer(name) == true or nil })
    end)
end)

-- On load: AmisiaDB.sync made, the seen list without entries older than 30 days or broken ones, at
-- most 300 (the oldest go). Loading twice changes nothing.
function ns.VersionLoaded(DB)
    if type(DB.sync) ~= "table" then DB.sync = {} end
    local d = DB.sync
    d.v = 1
    if type(d.seen) ~= "table" then d.seen = {} end
    local t = time()
    for name, e in pairs(d.seen) do
        if type(name) ~= "string" or type(e) ~= "table" or type(e.at) ~= "number" or type(e.v) ~= "string"
            or type(e.flags) ~= "string" or t - e.at > SEEN_DAYS * 86400 then
            d.seen[name] = nil
        end
    end
    trim(d)
    if d.warned ~= nil and type(d.warned) ~= "string" then d.warned = nil end
    if d.helloAt ~= nil and type(d.helloAt) ~= "number" then d.helloAt = nil end
end

---------------------------------------------------------------------------
-- The list of the page and the command
---------------------------------------------------------------------------
local function classOf(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        n, class = ns.Plain(n), ns.Plain(class)
        if type(n) == "string" and ns.SameName(n, name) and type(class) == "string" then return class end
    end
    return nil
end

-- The rows of the version list: the own client, every version seen and, 10 s after a raid
-- question, the raid members without an answer ({ missing = true }). Each row: name, v, p, flags,
-- where, at, class, self, outdated (older than the highest in the group), tooOld (protocol under
-- the keeper's minimum).
function ns.VersionRows()
    local rows, me = {}, ns.UnitFullName("player")
    local inRaid = homeRaid()
    rows[1] = { name = me or "?", v = ns.VERSION, p = ns.SYNC_PROTO, mp = ns.SYNC_MIN_PROTO, flags = ownFlags(),
                where = inRaid and "raid" or "guild", at = time(), self = true }
    for _, e in ipairs(ns.VersionSeen()) do
        if not ns.SameName(e.name, me) then rows[#rows + 1] = e end
    end
    if inRaid and askedAt.raid and now() - askedAt.raid >= NO_ANSWER_AFTER then
        for _, n in ipairs(ns.GroupRoster()) do
            local have = false
            for _, r in ipairs(rows) do
                if ns.SameName(r.name, n) then have = true break end
            end
            if not have then rows[#rows + 1] = { name = n, where = "raid", missing = true } end
        end
    end
    table.sort(rows, function(a, b)
        if a.where ~= b.where then return a.where == "raid" end
        if a.where == "raid" or (a.at or 0) == (b.at or 0) then return a.name:lower() < b.name:lower() end
        return (a.at or 0) > (b.at or 0)
    end)
    -- the highest version in the group (outside a raid: of everyone seen)
    local top
    for _, r in ipairs(rows) do
        if r.v and (r.where == "raid" or not inRaid) and (not top or ns.CompareVersion(r.v, top) > 0) then top = r.v end
    end
    local keeper = ns.SyncKeeperName and ns.SyncKeeperName() or nil
    local keeperMin
    for _, r in ipairs(rows) do
        if keeper and not r.self and ns.SameName(r.name, keeper) then keeperMin = r.mp end
    end
    for _, r in ipairs(rows) do
        r.class = r.class or classOf(r.name)
        r.keeper = keeper ~= nil and ns.SameName(r.name, keeper)
        if r.v then
            r.outdated = top ~= nil and ns.CompareVersion(r.v, top) < 0
            r.tooOld = keeperMin ~= nil and (r.p or 0) < keeperMin
        end
    end
    return rows
end

-- "Hüter", "Offizier", "Raider" or "-".
function ns.VersionView(r)
    if r.missing or not r.flags then return "-" end
    if r.keeper then return "Hüter" end
    if r.flags:find("O", 1, true) then return "Offizier" end
    return "Raider"
end

local function printList()
    ns.msg("Amisia-Versionen:")
    for _, r in ipairs(ns.VersionRows()) do
        DEFAULT_CHAT_FRAME:AddMessage(("  %s · %s · %s · %s"):format(r.name, r.missing and "kein Amisia?" or tostring(r.v),
            ns.VersionView(r), r.where == "raid" and "Raid" or "Gilde"))
    end
end

---------------------------------------------------------------------------
-- Settings and command
---------------------------------------------------------------------------
do
    local items = ns.SYNC_SETTINGS.items
    local at = 2
    for i, it in ipairs(items) do
        if it.key == "sync.enabled" then at = i + 1 end
    end
    table.insert(items, at, { key = "sync.versionCheck", type = "toggle", label = "Versionsprüfung", default = true,
        tip = "Meldet die eigene Version einmal nach dem Login an die Gilde und beim Betreten eines Raids." })
    table.insert(items, at + 1, { key = "sync.outdatedWarn", type = "toggle", label = "Hinweis auf eine neuere Amisia-Version", default = true })
    ns.RegisterSettings(ns.SYNC_SETTINGS)
end

ns.RegisterSlash("version", { aliases = { "versionen" }, desc = "Amisia-Versionen in Raid oder Gilde abfragen", run = function()
    local where = homeRaid() and "raid" or "guild"
    local ok, why = ns.VersionAsk(where)
    if not ok then
        ns.msg(why)
        printList()
        return
    end
    ns.msg(("Frage %s nach Amisia-Versionen. Die Liste folgt in 10 Sekunden."):format(where == "raid" and "den Raid" or "die Gilde"))
    C_Timer.After(NO_ANSWER_AFTER + 0.1, printList)
end })
