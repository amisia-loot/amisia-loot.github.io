-- Amisia trust: who a sender of an addon message is, from the group and the guild roster, never
-- from what a message claims. The server sets the sender; Amisia checks that the name stands in
-- the own guild and that its rank is an officer rank (the rank permission "officer rank", with a
-- fallback and a setting). The guild roster comes from C_Club (secret in the chat lockdown, so it
-- is only read outside of it), else from the classic guild roster functions.
local ADDON, ns = ...

local REBUILD_GAP = 10    -- seconds between two builds of the roster
local WAIT_FOR = 60       -- seconds data of an unchecked sender waits for the roster
local WAIT_MAX = 20       -- waiting entries at most
local OFFICER_FLAG = 22   -- "officer rank" in the rank permissions (Blizzard_GuildControlUI)

local roster              -- { { name, rank, guid, online } } or nil before the first build
local builtAt, dirty = nil, true

local function now() return GetTime() end

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
                                  online = presence == 1 or presence == 4 or presence == 5, self = ns.Plain(info.isSelf) == true }
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
        local okRow, name, _, rankIndex, _, _, _, _, _, online = pcall(GetGuildRosterInfo, i)
        if okRow then
            name, rankIndex, online = ns.FullName(ns.Plain(name)), tonumber(ns.Plain(rankIndex)), ns.Plain(online)
            if name and rankIndex then
                out[#out + 1] = { name = name, rank = rankIndex + 1, online = online and true or false }
            end
        end
    end
    if #out == 0 then return nil end
    return out
end

local function inGuild()
    return type(_G.IsInGuild) == "function" and ns.Plain(IsInGuild()) == true
end

-- Builds the roster when it is due: never in the lockdown (C_Club answers secret values there),
-- at most every 10 s, sooner when it is empty and something changed.
local function refresh()
    if ns.ChatLocked() then return end
    local t = now()
    local empty = not roster or #roster == 0
    local due = not builtAt or ((dirty or empty) and t - builtAt >= REBUILD_GAP) or (dirty and empty)
    if not due then return end
    builtAt, dirty = t, false
    if not inGuild() then
        roster = {}
        return
    end
    roster = clubMembers() or rosterMembers() or {}
    if #roster == 0 and ns.RequestGuildRoster then ns.RequestGuildRoster() end
end

-- The roster to read now, or nil when it cannot be read (empty, or the lockdown without cache
-- permission).
local function readable(allowLocked)
    if ns.ChatLocked() then
        if not allowLocked then return nil end
    else
        refresh()
    end
    if not inGuild() then return {} end
    if not roster or #roster == 0 then return nil end
    return roster
end

local function names(list)
    local out = {}
    for i, m in ipairs(list) do out[i] = m.name end
    return out
end

local function find(list, name)
    name = ns.FullName(name)
    if not name then return nil end
    local all = names(list)
    for _, m in ipairs(list) do
        if m.name:lower() == name:lower() then return m end
    end
    for _, m in ipairs(list) do
        if ns.SameNameIn(name, m.name, all) then return m end
    end
    return nil
end

-- A guild member: { name, rank, guid, online }; nil when not in the guild; nil, "unknown" when the
-- roster cannot be read (empty or the lockdown).
function ns.GuildMember(name)
    local list = readable(false)
    if not list then return nil, "unknown" end
    local m = find(list, name)
    if not m then return nil end
    return { name = m.name, rank = m.rank, guid = m.guid, online = m.online }
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

local function ownRank()
    local list = readable(true)
    if not list then return nil end
    for _, m in ipairs(list) do
        if m.self then return m.rank end
    end
    local me = find(list, ns.UnitFullName("player"))
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
-- roster built before a lockdown, without a new query.
function ns.SelfIsOfficer()
    local own = ownRank()
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
        out[r] = { rank = r, name = type(name) == "string" and name ~= "" and name or ("Rang " .. r),
                   officer = ns.IsOfficerRank(r), members = count[r] or 0 }
    end
    local rule = officerRule()
    return out, rule == "flags" and "Rangrechte" or rule == "setting" and "Einstellung" or "Rückfall"
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
-- A raw sender as the name it has in the group or the guild: the same spelling (any case), else a
-- first name alone that only one of them carries; then the text before a realm ending. nil when
-- nobody fits.
function ns.TrustName(raw)
    raw = ns.Plain(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local all, seen = {}, {}
    local function add(n)
        n = ns.FullName(n)
        if n and not seen[n:lower()] then
            seen[n:lower()] = true
            all[#all + 1] = n
        end
    end
    for _, n in ipairs(ns.GroupRoster()) do add(n) end
    local list = readable(false)
    for _, m in ipairs(list or {}) do add(m.name) end
    local function match(cand)
        cand = ns.FullName(cand)
        if not cand then return nil end
        for _, n in ipairs(all) do
            if n:lower() == cand:lower() then return n end
        end
        for _, n in ipairs(all) do
            if ns.SameNameIn(cand, n, all) then return n end
        end
        return nil
    end
    local hit = match(raw)
    if hit then return hit end
    local base = raw:match("^(.+)%-[^%-]*$")
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
    local values = { { "auto", "Automatisch" }, { 1, "Rang 1" } }
    for n = 2, 10 do values[#values + 1] = { n, "Rang 1 bis " .. n } end
    table.insert(ns.SYNC_SETTINGS.items, { key = "sync.officerRanks", type = "choice", label = "Offiziersränge", default = "auto",
        values = values, expert = true,
        tip = "Automatisch: Ränge mit dem Recht Offiziersrang in der Rangverwaltung." })
    ns.RegisterSettings(ns.SYNC_SETTINGS)
end

ns.RegisterSyncCommand("raenge", function()
    if not inGuild() then
        ns.msg("Du bist in keiner Gilde.")
        return
    end
    local list, source = ns.RankList()
    if not list then
        ns.msg("Die Gildenliste ist gerade nicht lesbar (Kampfsperre oder noch nicht geladen). Versuch es gleich noch einmal.")
        return
    end
    ns.msg(("Gildenränge (Quelle: %s):"):format(source))
    for _, r in ipairs(list) do
        DEFAULT_CHAT_FRAME:AddMessage(("  Rang %d · %s · %d %s · %s"):format(r.rank, r.name, r.members,
            r.members == 1 and "Mitglied" or "Mitglieder", r.officer and "Offiziersrang" or "kein Offiziersrang"))
    end
end)
