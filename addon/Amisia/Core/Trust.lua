-- Amisia trust: who a sender of an addon message is, from the group and the guild roster, never
-- from what a message claims. The server sets the sender; Amisia checks that the name stands in
-- the own guild and that its rank is an officer rank (the rank permission "officer rank", with a
-- fallback and a setting). The guild roster comes from C_Club (secret in the chat lockdown, so it
-- is only read outside of it), else from the classic guild roster functions.
local ADDON, ns = ...
local L = ns.L
local N_ = ns.N_

local REBUILD_GAP = 10    -- seconds between two builds of the roster
local WAIT_FOR = 60       -- seconds data of an unchecked sender waits for the roster
local WAIT_MAX = 20       -- waiting entries at most
local OFFICER_FLAG = 22   -- "officer rank" in the rank permissions (Blizzard_GuildControlUI)

local roster              -- { { name, rank, guid, online, class } } or nil before the first build
local rosterIdx           -- the index of roster (see index), built with it
local builtAt, dirty = nil, true

local function now() return GetTime() end

-- The class token of a class id ("" when the client cannot tell).
local function classFile(id)
    id = tonumber(id)
    if not id then return "" end
    local api = _G.C_CreatureInfo
    if type(api) == "table" and type(api.GetClassInfo) == "function" then
        local ok, info = pcall(api.GetClassInfo, id)
        info = ok and ns.Plain(info) or nil
        local file = type(info) == "table" and ns.Plain(info.classFile)
        if type(file) == "string" and file ~= "" then return file end
    end
    if type(_G.GetClassInfo) == "function" then
        local ok, _, file = pcall(GetClassInfo, id)
        file = ok and ns.Plain(file) or nil
        if type(file) == "string" and file ~= "" then return file end
    end
    return ""
end

-- The members C_Club knows, or nil when it cannot tell.
local function clubMembers()
    local club = _G.C_Club
    if type(club) ~= "table" or type(club.GetGuildClubId) ~= "function" or type(club.GetClubMembers) ~= "function"
        or type(club.GetMemberInfo) ~= "function" then
        return nil
    end
    local ok, clubId = pcall(club.GetGuildClubId)
    clubId = ok and ns.Plain(clubId) or nil
    if clubId == nil then return nil end
    local okIds, ids = pcall(club.GetClubMembers, clubId)
    if not okIds or type(ns.Plain(ids)) ~= "table" then return nil end
    local out = {}
    for _, id in ipairs(ids) do
        local okInfo, info = pcall(club.GetMemberInfo, clubId, id)
        info = okInfo and ns.Plain(info) or nil
        if type(info) == "table" then
            local name = ns.FullName(ns.Plain(info.name))
            local rank = tonumber(ns.Plain(info.guildRankOrder))
            local presence = ns.Plain(info.presence)
            if name and rank then
                -- presence: 0 unknown, 1 online, 2 mobile, 3 offline, 4 away, 5 busy
                out[#out + 1] = { name = name, rank = rank, guid = ns.Plain(info.guid),
                                  online = presence == 1 or presence == 4 or presence == 5, self = ns.Plain(info.isSelf) == true,
                                  class = classFile(ns.Plain(info.classID)) }
            end
        end
    end
    if #out == 0 then return nil end
    return out
end

-- The members of the classic roster functions (rank = rank index + 1), or nil.
local function rosterMembers()
    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then return nil end
    local ok, n = pcall(GetNumGuildMembers)
    n = ok and tonumber(ns.Plain(n)) or 0
    if n <= 0 then return nil end
    local out = {}
    for i = 1, n do
        local okRow, name, _, rankIndex, _, _, _, _, _, online, _, class = pcall(GetGuildRosterInfo, i)
        if okRow then
            name, rankIndex, online, class = ns.FullName(ns.Plain(name)), tonumber(ns.Plain(rankIndex)), ns.Plain(online), ns.Plain(class)
            if name and rankIndex then
                out[#out + 1] = { name = name, rank = rankIndex + 1, online = online and true or false,
                                  class = type(class) == "string" and class or "" }
            end
        end
    end
    if #out == 0 then return nil end
    return out
end

local function inGuild()
    return type(_G.IsInGuild) == "function" and ns.Plain(IsInGuild()) == true
end

local function firstOf(low) return low:match("^(%S+)") end

-- The lookup index of a member list, built once per roster build (a sender is looked up for every
-- addon message): low[name:lower()] = the first member of that spelling; first[first name] =
-- { n = members, d = different spellings, m = the first member } (lowercase keys).
local function index(list)
    local idx = { low = {}, first = {} }
    for _, m in ipairs(list) do
        local low = m.name:lower()
        local f = firstOf(low)
        local e = idx.first[f]
        if not e then
            e = { n = 0, d = 0, m = m }
            idx.first[f] = e
        end
        e.n = e.n + 1
        if not idx.low[low] then
            idx.low[low] = m
            e.d = e.d + 1
        end
    end
    return idx
end

local function setRoster(list)
    roster, rosterIdx = list, index(list)
end

-- Builds the roster when it is due: never in the lockdown (C_Club answers secret values there),
-- at most every 10 s, sooner when it is empty and something changed.
local function refresh(noAsk)
    if ns.ChatLocked() then return end
    local t = now()
    local empty = not roster or #roster == 0
    local due = not builtAt or ((dirty or empty) and t - builtAt >= REBUILD_GAP) or (dirty and empty)
    if not due then return end
    builtAt, dirty = t, false
    if not inGuild() then
        setRoster({})
        return
    end
    setRoster(clubMembers() or rosterMembers() or {})
    if #roster == 0 and not noAsk and ns.RequestGuildRoster then ns.RequestGuildRoster() end
end

-- The roster to read now, or nil when it cannot be read (empty, or the lockdown without cache
-- permission). noAsk: an empty roster is not asked for (a reader that polls).
local function readable(allowLocked, noAsk)
    if ns.ChatLocked() then
        if not allowLocked then return nil end
    else
        refresh(noAsk)
    end
    if not inGuild() then return {} end
    if not roster or #roster == 0 then return nil end
    return roster
end

-- A member of the roster: the same spelling (any case), else the one member whose first name
-- matches when one side has no surname (ns.SameNameIn over the roster, through the index).
local function find(name)
    name = ns.FullName(name)
    if not name or not rosterIdx then return nil end
    local low = name:lower()
    local m = rosterIdx.low[low]
    if m then return m end
    local e = rosterIdx.first[firstOf(low)]
    if e and e.n == 1 and (not low:find(" ", 1, true) or not e.m.name:find(" ", 1, true)) then return e.m end
    return nil
end

-- A guild member: { name, rank, guid, online }; nil when not in the guild; nil, "unknown" when the
-- roster cannot be read (empty or the lockdown).
function ns.GuildMember(name)
    local list = readable(false)
    if not list then return nil, "unknown" end
    local m = find(name)
    if not m then return nil end
    return { name = m.name, rank = m.rank, guid = m.guid, online = m.online }
end

-- The guild roster for reading only: { { name, rank, guid, online, class } }, the roster built
-- before a lockdown in it; nil when it cannot be read (no guild, empty, nothing built yet). Never
-- asks the client for it.
function ns.GuildRoster()
    local list = readable(true, true)
    if not list or #list == 0 then return nil end
    return list
end

---------------------------------------------------------------------------
-- Officer ranks
---------------------------------------------------------------------------
local function rankFlags(rank)
    local api = _G.C_GuildInfo
    local fn = type(api) == "table" and api.GuildControlGetRankFlags
    if type(fn) ~= "function" then return nil end
    local ok, flags = pcall(fn, rank)
    flags = ok and ns.Plain(flags) or nil
    return type(flags) == "table" and flags or nil
end

local function selfOfficerFlag()
    local api = _G.C_GuildInfo
    for _, f in ipairs({ "IsGuildOfficer", "CanEditOfficerNote" }) do
        local fn = type(api) == "table" and api[f]
        if type(fn) == "function" then
            local ok, on = pcall(fn)
            if ok and ns.Plain(on) == true then return true end
        end
    end
    return false
end

local function ownRank(noAsk)
    local list = readable(true, noAsk)
    if not list then return nil end
    for _, m in ipairs(list) do
        if m.self then return m.rank end
    end
    local me = find(ns.UnitFullName("player"))
    return me and me.rank or nil
end

-- How officer ranks are decided now: "setting" with N, "flags", or "fallback" with the highest
-- officer rank.
local function officerRule()
    local setting = ns.Get("sync.officerRanks")
    if type(setting) == "number" then return "setting", setting end
    local gm = rankFlags(1)
    if gm and gm[OFFICER_FLAG] == true then return "flags" end
    if selfOfficerFlag() then
        local own = ownRank()
        if own and own >= 1 then return "fallback", math.max(own, 1) end
    end
    return "fallback", 2
end

function ns.IsOfficerRank(rank)
    rank = tonumber(rank)
    if not rank or rank < 1 then return false end
    local rule, top = officerRule()
    if rule == "flags" then
        local flags = rankFlags(rank)
        return flags ~= nil and flags[OFFICER_FLAG] == true
    end
    return rank <= top
end

-- true: a guild member with an officer rank; false: not; nil: the roster cannot be read now.
function ns.IsVerifiedOfficer(name)
    local m, why = ns.GuildMember(name)
    if why == "unknown" then return nil end
    if not m then return false end
    return ns.IsOfficerRank(m.rank)
end

-- true: a guild member; false: not; nil: the roster cannot be read now.
function ns.IsVerifiedMember(name)
    local m, why = ns.GuildMember(name)
    if why == "unknown" then return nil end
    return m ~= nil
end

-- Whether the own character has an officer rank (a forced officer view does not count). Reads the
-- roster built before a lockdown, without a new query. noAsk: an empty roster is not asked for (the
-- sync polls this every few seconds).
function ns.SelfIsOfficer(noAsk)
    local own = ownRank(noAsk)
    return own ~= nil and ns.IsOfficerRank(own) or false
end

-- Every guild rank: { rank, name, officer, members }, and the source of the officer ranks
-- ("Rangrechte", "Rückfall", "Einstellung"); nil when the roster cannot be read.
function ns.RankList()
    local list = readable(false)
    if not list then return nil end
    local count, top = {}, 0
    for _, m in ipairs(list) do
        count[m.rank] = (count[m.rank] or 0) + 1
        if m.rank > top then top = m.rank end
    end
    local n = type(GuildControlGetNumRanks) == "function" and tonumber(ns.Plain(GuildControlGetNumRanks())) or nil
    n = math.max(n or 0, top)
    local out = {}
    for r = 1, n do
        local name = type(GuildControlGetRankName) == "function" and ns.Plain(GuildControlGetRankName(r)) or nil
        out[r] = { rank = r, name = type(name) == "string" and name ~= "" and name or L["Rang %d"]:format(r),
                   officer = ns.IsOfficerRank(r), members = count[r] or 0 }
    end
    local rule = officerRule()
    return out, rule == "flags" and N_("Rangrechte") or rule == "setting" and N_("Einstellung") or N_("Rückfall")
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
-- The own realm as the client writes it behind a sender ("Name-Realm"), or nil.
local function ownRealm()
    for _, read in ipairs({
        function() return _G.GetNormalizedRealmName and GetNormalizedRealmName() end,
        function() return _G.UnitFullName and select(2, UnitFullName("player")) end,
    }) do
        local ok, realm = pcall(read)
        realm = ok and ns.Plain(realm) or nil
        if type(realm) == "string" and realm ~= "" then return realm end
    end
    return nil
end

local function realmKey(r) return (r:gsub("[%s%-']", "")):lower() end

-- A raw sender without the realm ending, but only when that ending is the own realm (a player of
-- another realm is never taken for a guild member of the same name); nil otherwise.
function ns.StripOwnRealm(raw)
    if type(raw) ~= "string" then return nil end
    local base, realm = raw:match("^(.+)%-([^%-]+)$")
    if not base then return nil end
    local own = ownRealm()
    if not own or realmKey(realm) ~= realmKey(own) then return nil end
    return base
end

-- A raw sender as the name it has in the group or the guild: the same spelling (any case), else a
-- first name alone that only one of them carries; then the text before the own realm's ending.
-- nil when nobody fits.
function ns.TrustName(raw)
    raw = ns.Plain(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    -- the group (40 at most) first, then the guild through its index: the names of both, each
    -- spelling once, the group's spelling first
    local group, groupFirst = {}, {}
    for _, n in ipairs(ns.GroupRoster()) do
        local low = n:lower()
        if not group[low] then
            group[low] = n
            local f = firstOf(low)
            local e = groupFirst[f]
            if not e then
                e = { d = 0, n = n, lows = {} }
                groupFirst[f] = e
            end
            e.d = e.d + 1
            e.lows[#e.lows + 1] = low
        end
    end
    local idx = readable(false) and rosterIdx or nil
    local function match(cand)
        cand = ns.FullName(cand)
        if not cand then return nil end
        local low = cand:lower()
        if group[low] then return group[low] end
        local m = idx and idx.low[low]
        if m then return m.name end
        -- a first name alone: only when exactly one name of group and guild carries it
        local f = firstOf(low)
        local g, e = groupFirst[f], idx and idx.first[f]
        local d = (g and g.d or 0) + (e and e.d or 0)
        if g and e then
            for _, l in ipairs(g.lows) do
                if idx.low[l] then d = d - 1 end
            end
        end
        if d ~= 1 then return nil end
        local n = g and g.n or e.m.name
        if low:find(" ", 1, true) and n:find(" ", 1, true) then return nil end
        return n
    end
    local hit = match(raw)
    if hit then return hit end
    local base = ns.StripOwnRealm(raw)
    return base and match(base) or nil
end

-- Whether a name is in the own group (ns.SameNameIn over the group).
function ns.InMyGroup(name)
    local group = ns.GroupRoster()
    for _, n in ipairs(group) do
        if ns.SameNameIn(name, n, group) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Waiting for the roster
---------------------------------------------------------------------------
local waiting = {}        -- { name, need = "officer"|"member", fn, since }
local waitTicker

local function verdict(name, need)
    if need == "member" then return ns.IsVerifiedMember(name) end
    return ns.IsVerifiedOfficer(name)
end

local function settle()
    local t = now()
    local keep, done = {}, {}
    for _, w in ipairs(waiting) do
        local v = verdict(w.name, w.need)
        if v ~= nil then
            done[#done + 1] = { w.fn, v }
        elseif t - w.since >= WAIT_FOR then
            done[#done + 1] = { w.fn, false }
        else
            keep[#keep + 1] = w
        end
    end
    waiting = keep
    if #waiting == 0 and waitTicker then waitTicker:Cancel(); waitTicker = nil end
    for _, d in ipairs(done) do
        local ok, err = pcall(d[1], d[2])
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
end

-- Calls fn(true|false) once the sender can be checked: need "officer" (a verified officer) or
-- "member" (in the guild). Right away when the roster can be read; otherwise it waits up to 60 s
-- (at most 20 waiting in all, more get false at once) while the roster is asked for.
function ns.TrustWait(name, need, fn)
    local v = verdict(name, need)
    if v ~= nil then return fn(v) end
    if #waiting >= WAIT_MAX then return fn(false) end
    waiting[#waiting + 1] = { name = name, need = need, fn = fn, since = now() }
    if ns.RequestGuildRoster then ns.RequestGuildRoster() end
    if not waitTicker then waitTicker = C_Timer.NewTicker(1, settle) end
end

for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED",
                         "CLUB_MEMBER_UPDATED", "CLUB_MEMBERS_UPDATED" }) do
    ns.OnEvent(event, function() dirty = true end)
end

---------------------------------------------------------------------------
-- Setting and command
---------------------------------------------------------------------------
do
    local values = { { "auto", L["Automatisch"] }, { 1, L["Rang %d"]:format(1) } }
    for n = 2, 10 do values[#values + 1] = { n, L["Rang 1 bis %d"]:format(n) } end
    table.insert(ns.SYNC_SETTINGS.items, { key = "sync.officerRanks", type = "choice", label = L["Offiziersränge"], default = "auto",
        values = values, expert = true,
        tip = L["Automatisch: Ränge mit dem Recht Offiziersrang in der Rangverwaltung."] })
    ns.RegisterSettings(ns.SYNC_SETTINGS)
end

ns.RegisterSyncCommand("raenge", function()
    if not inGuild() then
        ns.msg(L["Du bist in keiner Gilde."])
        return
    end
    local list, source = ns.RankList()
    if not list then
        ns.msg(L["Die Gildenliste ist gerade nicht lesbar (Kampfsperre oder noch nicht geladen). Versuch es gleich noch einmal."])
        return
    end
    ns.msg(L["Gildenränge (Quelle: %s):"]:format(L[source]))
    for _, r in ipairs(list) do
        DEFAULT_CHAT_FRAME:AddMessage(L["  Rang %d · %s · %d %s · %s"]:format(r.rank, r.name, r.members,
            r.members == 1 and L["Mitglied"] or L["Mitglieder"], r.officer and L["Offiziersrang"] or L["kein Offiziersrang"]))
    end
end)
