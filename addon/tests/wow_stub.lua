-- Just enough of the WoW client API for the Amisia modules to run under plain Lua 5.1.
-- Everything a test may poke at hangs on STUB.
STUB = {
    chat = {}, messages = {}, roster = {}, items = {}, loot = {}, timers = {}, frames = {}, requested = {},
    now = 1789000000, clock = 0, player = "Vuloo", leader = true, alt = false,
    instance = { name = "Black Temple", type = "raid", id = 564 },
}

_G.Enum = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.tinsert = table.insert
_G.strmatch = string.match
_G.time = function(t) if type(t) == "table" then return os.time(t) end return STUB.now end
_G.date = function(fmt, t) return os.date(fmt, t or STUB.now) end
_G.GetServerTime = function() return STUB.now end
_G.GetTime = function() return STUB.clock end
_G.UnitName = function(u) if u == "target" then return STUB.target end if u == "npc" then return STUB.npc end return STUB.player end
_G.UnitGUID = function(u) if u == "target" then return STUB.targetGUID end return "Player-1-1" end
-- The own realm as the client writes it behind a sender ("Name-Realm"); STUB.realm changes it.
_G.GetNormalizedRealmName = function() return STUB.realm or "Realm" end
_G.GetNumGroupMembers = function() return #STUB.roster end
_G.GetRaidRosterInfo = function(i)
    local m = STUB.roster[i]
    if not m then return nil end
    return m.name, m.rank or 0, 1, 70, m.class, m.class, m.zone or "Black Temple", m.online ~= false
end
-- Group categories: STUB.instanceGroup makes the group an instance group (a battleground or a
-- finder group), so IsInRaid(LE_PARTY_CATEGORY_HOME) is false while IsInRaid() stays true.
_G.LE_PARTY_CATEGORY_HOME, _G.LE_PARTY_CATEGORY_INSTANCE = 1, 2
_G.IsInRaid = function(cat)
    if #STUB.roster == 0 then return false end
    if cat == LE_PARTY_CATEGORY_HOME then return not STUB.instanceGroup end
    if cat == LE_PARTY_CATEGORY_INSTANCE then return STUB.instanceGroup and true or false end
    return true
end
_G.IsInGroup = _G.IsInRaid
-- "player" is the leader with STUB.leader; a raid unit "raid<i>" with STUB.roster[i].leader (the
-- player's own raid unit, STUB.playerRaidIndex, follows STUB.leader when that is not set).
_G.UnitIsGroupLeader = function(u)
    local i = type(u) == "string" and tonumber(u:match("^raid(%d+)$"))
    if i then
        local m = STUB.roster[i]
        if m and m.leader ~= nil then return m.leader and true or false end
        if STUB.playerRaidIndex == i then return STUB.leader end
        return false
    end
    return STUB.leader
end
_G.UnitIsGroupAssistant = function() return false end
_G.GetInstanceInfo = function() local i = STUB.instance; return i.name, i.type, i.diff or 0, "", 0, 0, false, i.id end
_G.InCombatLockdown = function() return STUB.combat and true or false end
_G.IsAltKeyDown = function() return STUB.alt end
-- In a guild unless STUB.inGuild is false.
_G.GetGuildInfo = function() if STUB.inGuild == false then return nil end return "Amisia" end
_G.IsInGuild = function() return STUB.inGuild ~= false end
-- errors inside protected handlers still fail the test
_G.geterrorhandler = function() return function(e) error(e, 0) end end
-- The client is WoW Forever (1.60.1, interface 16001, game type camelot).
STUB.toc = 16001
_G.GetBuildInfo = function() return "1.60.1", "70205", "Oct 1 2026", STUB.toc end
STUB.officer = true
_G.C_GuildInfo = { CanEditOfficerNote = function() return STUB.officer end }
_G.MouseIsOver = function() return false end
_G.IsShiftKeyDown = function() return STUB.shift and true or false end
_G.IsControlKeyDown = function() return false end
-- Seconds until the weekly reset; nil means the client does not know (the fallback is tested).
STUB.weekReset = nil
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return STUB.weekReset end }
-- Values a test puts into STUB.secret count as secret, as in a boss fight on the Forever client.
STUB.secret = {}
_G.issecretvalue = function(v) return STUB.secret[v] == true end

-- math.random is fixed: a small generator with a known seed, so ids and draws repeat from run to
-- run. Values put into STUB.randomQueue come out first (to force a collision in a test).
STUB.seed, STUB.randomQueue = 12345, {}
math.random = function(lo, hi)
    local r
    if #STUB.randomQueue > 0 then
        r = table.remove(STUB.randomQueue, 1)
    else
        STUB.seed = (STUB.seed * 16807) % 2147483647
        r = STUB.seed
    end
    if not lo then return (r % 1000000) / 1000000 end
    if not hi then lo, hi = 1, lo end
    return lo + (r % (hi - lo + 1))
end

local function itemId(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
-- Forever has the item functions only in C_Item (no GetItemInfo, GetItemInfoInstant or GetItemStats
-- globals). GetItemStats answers STUB.items[id].stats ({ ITEM_MOD_..._SHORT = n }).
_G.C_Item = {
    GetItemInfo = function(x)
        local it = STUB.items[itemId(x)]
        if not it then return nil end
        return it.name, it.link, it.quality, it.ilvl or 141, it.minLevel or 70, "Armor", "Cloth", 1, it.equipLoc or "INVTYPE_HEAD", it.icon or 134, 0, it.classID or 4, it.subclassID or 1, it.bind or 1
    end,
    GetItemInfoInstant = function(x)
        local id = itemId(x)
        local it = STUB.items[id]
        return id, "Armor", "Cloth", it and it.equipLoc or "INVTYPE_HEAD", it and it.icon or 134, it and it.classID or 4, it and it.subclassID or 1
    end,
    GetItemStats = function(x)
        local it = STUB.items[itemId(x)]
        return it and it.stats
    end,
    RequestLoadItemDataByID = function(id) STUB.requested[#STUB.requested + 1] = id end,
    GetItemIconByID = function(x) local it = STUB.items[itemId(x)]; return it and it.icon or 134 end,
}
-- Area names (C_Map.GetAreaInfo) and faction names (GetFactionInfoByID) the client knows.
STUB.areas, STUB.factions = {}, {}
_G.C_Map = { GetAreaInfo = function(id) return STUB.areas[id] end }
_G.GetFactionInfoByID = function(id) return STUB.factions[id] end
_G.GetNumLootItems = function() return #STUB.loot end
_G.GetLootSlotLink = function(s) return STUB.loot[s] and STUB.loot[s].link end
_G.GetLootSlotInfo = function(s) local l = STUB.loot[s]; return "icon", l and l.name, l and l.qty or 1 end
_G.GetLootSourceInfo = function(s) local l = STUB.loot[s]; return l and l.src or "Creature-0-1-1-1-22917-1", l and l.qty or 1 end
_G.GetMasterLootCandidate = function(slot, i) return STUB.roster[i] and STUB.roster[i].name end
_G.GiveMasterLoot = function(slot, i) STUB.given = { slot = slot, i = i } end
-- The chat's link insertion: remembers the last link handed to it. The client calls
-- ChatFrameUtil.InsertLink; its deprecated alias ChatEdit_InsertLink exists only with the
-- deprecation fallbacks switched on, so the stub has none.
_G.ChatFrameUtil = { InsertLink = function(link) STUB.inserted = link; return true end }
-- A modified click on an item: shift puts the link into the chat, as the client does.
_G.HandleModifiedItemClick = function(link)
    STUB.modifiedClick = link
    if IsShiftKeyDown() then return ChatFrameUtil.InsertLink(link) end
    return false
end
-- Chat messages go through C_ChatInfo.SendChatMessage (no global SendChatMessage). The chat
-- lockdown of a boss fight: STUB.chatLock. The client announces a change with
-- ADDON_RESTRICTION_STATE_CHANGED (a test fires it through STUB.fire).
_G.C_ChatInfo = {
    SendChatMessage = function(text, chan, lang, target)
        if STUB.sendError then error(STUB.sendError) end
        STUB.chat[#STUB.chat + 1] = { text = text, chan = chan, target = target }
    end,
    InChatMessagingLockdown = function() return STUB.chatLock and true or false end,
}
-- "raid<STUB.playerRaidIndex>" is the player, as the raid unit of one's own character is.
_G.UnitIsUnit = function(a, b)
    if a == b then return true end
    local me = STUB.playerRaidIndex and ("raid" .. STUB.playerRaidIndex)
    return me ~= nil and ((a == me and b == "player") or (a == "player" and b == me))
end
-- The loot method: STUB.lootMethod (Enum.LootMethod.Masterlooter = 2) with the master looter's
-- party (STUB.mlPartyID) and raid index (STUB.mlRaidID).
_G.C_PartyInfo = { GetLootMethod = function() return STUB.lootMethod or 0, STUB.mlPartyID, STUB.mlRaidID end }
-- Group loot: the item link of a roll (STUB.rolls[rollID]).
STUB.rolls = {}
_G.GetLootRollItemLink = function(rollID) return STUB.rolls[rollID] end
-- The target's classification ("worldboss", "elite", ...) and death: STUB.targetClass, STUB.targetDead.
_G.UnitClassification = function(u) if u == "target" then return STUB.targetClass or "normal" end return "normal" end
_G.UnitIsDead = function(u) if u == "target" then return STUB.targetDead and true or false end return false end
-- A boss fight in progress (STUB.encounter) and the addon restriction of an encounter (STUB.restricted,
-- restriction type 1); the client announces a change with ADDON_RESTRICTION_STATE_CHANGED.
_G.C_InstanceEncounter = { IsEncounterInProgress = function() return STUB.encounter and true or false end }
-- Restriction type 5 (addon chat) follows the chat lockdown STUB.chatLock.
_G.C_RestrictedActions = { IsAddOnRestrictionActive = function(kind)
    if kind == 5 then return STUB.chatLock and true or false end
    return (STUB.restricted and kind == 1) and true or false
end }

-- Addon messages. RegisterAddonMessagePrefix remembers the prefixes (STUB.prefixes) and answers
-- STUB.prefixResult when set (0 success, 1 duplicate otherwise). SendAddonMessage notes every try in
-- STUB.addonTries ({ prefix, text, chan, target, t, result }) and what went out in STUB.addon; the
-- result is STUB.addonResult when set, else 11 during STUB.chatLock, 5 RAID without a home raid,
-- 10 GUILD outside a guild, 6 WHISPER without a target, 2 over 255 bytes, 3 when ten messages of this
-- prefix went out within the last second of stub time, else 0. A sent message goes to BUS_SEND too
-- (the multi-client bus of run.py).
STUB.prefixes, STUB.addon, STUB.addonTries = {}, {}, {}
C_ChatInfo.RegisterAddonMessagePrefix = function(prefix)
    if STUB.prefixResult then return STUB.prefixResult end
    if STUB.prefixes[prefix] then return 1 end
    STUB.prefixes[prefix] = true
    return 0
end
C_ChatInfo.SendAddonMessage = function(prefix, text, chan, target)
    local result = STUB.addonResult
    if not result then
        if STUB.chatLock then result = 11
        elseif chan == "RAID" and not IsInRaid(LE_PARTY_CATEGORY_HOME) then result = 5
        elseif chan == "GUILD" and not IsInGuild() then result = 10
        elseif chan == "WHISPER" and (type(target) ~= "string" or target == "") then result = 6
        elseif type(text) ~= "string" or #text > 255 then result = 2
        else
            local recent = 0
            for _, m in ipairs(STUB.addon) do
                if m.prefix == prefix and m.t > STUB.clock - 1 then recent = recent + 1 end
            end
            result = recent >= 10 and 3 or 0
        end
    end
    local m = { prefix = prefix, text = text, chan = chan, target = target, t = STUB.clock, result = result }
    STUB.addonTries[#STUB.addonTries + 1] = m
    if result == 0 then
        STUB.addon[#STUB.addon + 1] = m
        if BUS_SEND then BUS_SEND(STUB.player, prefix, text, chan, target) end
    end
    return result
end
-- Battlegrounds: STUB.battlefield (an instance of type "pvp" or "arena" comes from STUB.instance).
_G.C_PvP = { IsActiveBattlefield = function() return STUB.battlefield and true or false end }
Enum.SendAddonMessageResult = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4,
    NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10,
    AddOnMessageLockdown = 11, TargetOffline = 12 }
Enum.RegisterAddonMessagePrefixResult = { Success = 0, DuplicatePrefix = 1, InvalidPrefix = 2, MaxPrefixes = 3 }
Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
Enum.CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 }

-- C_EncodingUtil as a stand-in: SerializeCBOR is a deterministic Lua serializer (no real CBOR; a
-- round trip for numbers, strings, booleans and nested tables), CompressString only marks the text
-- (a round trip that checks the mark), EncodeBase64 and DecodeBase64 are real Base64. Bad input makes
-- the decoders return nothing (DeserializeCBOR raises). STUB.noEncoding (preload) takes it away.
do
    local function ser(v, out, depth)
        if depth > 100 then error("too deep") end
        local t = type(v)
        if t == "nil" then out[#out + 1] = "z"
        elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
        elseif t == "number" then out[#out + 1] = "n" .. ("%.17g"):format(v) .. ";"
        elseif t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
        elseif t == "table" then
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b)
                if type(a) ~= type(b) then return type(a) == "number" end
                return a < b
            end)
            out[#out + 1] = "t"
            for _, k in ipairs(keys) do ser(k, out, depth + 1); ser(v[k], out, depth + 1) end
            out[#out + 1] = "e"
        else
            error("cannot serialize a " .. t)
        end
    end
    local function deser(s, pos, depth)
        if depth > 100 then error("too deep") end
        local c = s:sub(pos, pos)
        if c == "z" then return nil, pos + 1
        elseif c == "T" then return true, pos + 1
        elseif c == "F" then return false, pos + 1
        elseif c == "n" then
            local e = s:find(";", pos, true)
            local n = e and tonumber(s:sub(pos + 1, e - 1))
            if not n then error("bad number") end
            return n, e + 1
        elseif c == "s" then
            local e = s:find(":", pos, true)
            local len = e and tonumber(s:sub(pos + 1, e - 1))
            if not len or e + len > #s then error("bad string") end
            return s:sub(e + 1, e + len), e + len + 1
        elseif c == "t" then
            local t = {}
            pos = pos + 1
            while s:sub(pos, pos) ~= "e" do
                if pos > #s then error("open table") end
                local k, v
                k, pos = deser(s, pos, depth + 1)
                v, pos = deser(s, pos, depth + 1)
                if k == nil then error("nil key") end
                t[k] = v
            end
            return t, pos + 1
        end
        error("bad value at " .. pos)
    end
    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local B64INV = {}
    for i = 1, 64 do B64INV[B64:sub(i, i)] = i - 1 end
    local function encode64(s)
        local out = {}
        for i = 1, #s, 3 do
            local a, b, c = s:byte(i, i + 2)
            local n = a * 65536 + (b or 0) * 256 + (c or 0)
            local q = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
            out[#out + 1] = B64:sub(q[1] + 1, q[1] + 1) .. B64:sub(q[2] + 1, q[2] + 1)
                .. (b and B64:sub(q[3] + 1, q[3] + 1) or "=") .. (c and B64:sub(q[4] + 1, q[4] + 1) or "=")
        end
        return table.concat(out)
    end
    local function decode64(s)
        if #s % 4 ~= 0 then return nil end
        local out = {}
        for i = 1, #s, 4 do
            local chunk = s:sub(i, i + 3)
            local pad = select(2, chunk:gsub("=", ""))
            if pad > 2 or (pad > 0 and i + 3 < #s) or chunk:find("=[^=]") then return nil end
            local n = 0
            for j = 1, 4 do
                local ch = chunk:sub(j, j)
                local v = ch == "=" and 0 or B64INV[ch]
                if not v then return nil end
                n = n * 64 + v
            end
            local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
            out[#out + 1] = bytes:sub(1, 3 - pad)
        end
        return table.concat(out)
    end
    STUB.encodingCalls = 0
    _G.C_EncodingUtil = {
        SerializeCBOR = function(v)
            STUB.encodingCalls = STUB.encodingCalls + 1
            local out = {}
            ser(v, out, 0)
            return "CB1" .. table.concat(out)
        end,
        DeserializeCBOR = function(s)
            if type(s) ~= "string" or s:sub(1, 3) ~= "CB1" then error("not CBOR") end
            local v, pos = deser(s, 4, 0)
            if pos ~= #s + 1 then error("trailing bytes") end
            return v
        end,
        CompressString = function(s, method) return "DF" .. tostring(method or 0) .. ":" .. s end,
        DecompressString = function(s, method)
            local mark = "DF" .. tostring(method or 0) .. ":"
            if type(s) ~= "string" or s:sub(1, #mark) ~= mark then return nil end
            return s:sub(#mark + 1)
        end,
        EncodeBase64 = function(s) return encode64(s) end,
        DecodeBase64 = function(s) return decode64(s) end,
    }
end

-- Any value as Lua source ("return " .. STUB.dump(v) gives it back): tables with sorted keys,
-- functions and cycles as nil. The multi-client runner hands tables between runtimes with it.
function STUB.dump(v, seen)
    local t = type(v)
    if t == "string" then return ("%q"):format(v):gsub("\r", "\\r"):gsub("\n", "\\n") end
    if t == "number" then
        if v ~= v then return "(0/0)" end
        if v == math.huge then return "math.huge" end
        if v == -math.huge then return "-math.huge" end
        return ("%.17g"):format(v)
    end
    if t == "boolean" then return tostring(v) end
    if t ~= "table" then return "nil" end
    seen = seen or {}
    if seen[v] then return "nil" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        if type(a) == "number" or type(a) == "string" then return a < b end
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    for _, k in ipairs(keys) do
        local kt = type(k)
        if kt == "string" or kt == "number" or kt == "boolean" then
            parts[#parts + 1] = "[" .. STUB.dump(k) .. "]=" .. STUB.dump(v[k], seen)
        end
    end
    seen[v] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

-- The guild roster: STUB.guild = { { name, class (token), online, rank } } (rank: rank order, 1 =
-- guild master, default 3); requests are counted.
STUB.guild, STUB.guildRequests = {}, 0
C_GuildInfo.GuildRoster = function() STUB.guildRequests = STUB.guildRequests + 1 end
C_GuildInfo.IsGuildOfficer = function() return STUB.officer and true or false end
-- Rank permissions: STUB.rankFlags[rank] = { [flag] = true } (22 is "officer rank"); every other
-- flag is false. Calls are counted.
STUB.rankFlags, STUB.rankFlagCalls = {}, 0
C_GuildInfo.GuildControlGetRankFlags = function(rank)
    STUB.rankFlagCalls = STUB.rankFlagCalls + 1
    local out = {}
    for i = 1, 24 do out[i] = false end
    for k, v in pairs(STUB.rankFlags[rank] or {}) do out[k] = v end
    return out
end
STUB.rankNames = { "Gildenmeister", "Offizier", "Veteran", "Mitglied", "Rekrut" }
_G.GuildControlGetNumRanks = function() return #STUB.rankNames end
_G.GuildControlGetRankName = function(i) return STUB.rankNames[i] end
-- The guild as a club (C_Club): one club id while in a guild, its members from STUB.guild. Calls of
-- GetClubMembers and GetMemberInfo are counted (STUB.clubCalls).
STUB.clubCalls = 0
_G.C_Club = {
    GetGuildClubId = function() if not IsInGuild() then return nil end return 77 end,
    GetClubMembers = function(club)
        STUB.clubCalls = STUB.clubCalls + 1
        local out = {}
        if club ~= 77 then return out end
        for i = 1, #STUB.guild do out[i] = 1000 + i end
        return out
    end,
    GetMemberInfo = function(club, id)
        STUB.clubCalls = STUB.clubCalls + 1
        local m = club == 77 and STUB.guild[id - 1000]
        if not m then return nil end
        return { isSelf = m.name == STUB.player, memberId = id, name = m.name, guildRankOrder = m.rank or 3,
                 guid = "Player-1-" .. id, presence = m.online == false and 3 or 1 }
    end,
}
_G.GetNumGuildMembers = function()
    local online = 0
    for _, m in ipairs(STUB.guild) do if m.online ~= false then online = online + 1 end end
    return #STUB.guild, online, online
end
_G.GetGuildRosterInfo = function(i)
    local m = STUB.guild[i]
    if not m then return nil end
    local rank = m.rank or 3
    return m.name, STUB.rankNames[rank] or "Mitglied", rank - 1, 70, m.class, "Shattrath", "", "", m.online ~= false, 0, m.class
end
-- Friends: STUB.friends = { { name, className (localized), online } }.
STUB.friends = {}
_G.C_FriendList = {
    GetNumFriends = function() return #STUB.friends end,
    GetFriendInfoByIndex = function(i)
        local f = STUB.friends[i]
        if not f then return nil end
        return { name = f.name, className = f.className, connected = f.online ~= false, level = 70 }
    end,
}

_G.hooksecurefunc = function(a, b, c)
    if type(a) == "string" then
        local orig = _G[a]
        _G[a] = function(...) local r = { orig(...) }; b(...); return unpack(r) end
    else
        local orig = a[b]
        a[b] = function(...) local r = { orig(...) }; c(...); return unpack(r) end
    end
end

_G.C_Timer = {
    After = function(s, fn) STUB.timers[#STUB.timers + 1] = { at = STUB.clock + s, fn = fn } end,
    NewTicker = function(s, fn)
        local t = { at = STUB.clock + s, fn = fn, every = s }
        t.Cancel = function() t.dead = true end
        STUB.timers[#STUB.timers + 1] = t
        return t
    end,
}
-- Advances the fake clock, firing timers in order. time() moves along with it.
function STUB.tick(seconds)
    local target = STUB.clock + seconds
    while true do
        local nextT
        for _, t in ipairs(STUB.timers) do
            if not t.dead and t.at <= target + 1e-9 and (not nextT or t.at < nextT.at) then nextT = t end
        end
        if not nextT then break end
        STUB.now = STUB.now + (nextT.at - STUB.clock)
        STUB.clock = nextT.at
        if nextT.every then nextT.at = nextT.at + nextT.every else nextT.dead = true end
        nextT.fn()
    end
    STUB.now = STUB.now + (target - STUB.clock)
    STUB.clock = target
end

local NOOP = function() end
-- Anchors are recorded (points[point] = { rel, relPoint, x, y }, rel nil for the parent), so a test
-- can lay out a row and check that nothing overlaps or leaves its frame.
local function setPoint(self, point, a, b, c, d)
    local rel, relPoint, x, y
    if type(a) == "table" then
        rel = a
        if type(b) == "string" then relPoint, x, y = b, c, d else relPoint, x, y = point, b, c end
    else
        relPoint, x, y = point, a, b
    end
    self.points = self.points or {}
    self.points[point] = { rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
end
local function setAllPoints(self, rel)
    self.points = { TOPLEFT = { rel = rel, relPoint = "TOPLEFT", x = 0, y = 0 },
                    BOTTOMRIGHT = { rel = rel, relPoint = "BOTTOMRIGHT", x = 0, y = 0 } }
end
local function region(parent)
    local f = { text = "", shown = true, parent = parent }
    for _, m in ipairs({ "SetPoint", "SetWidth", "SetHeight", "SetSize", "SetJustifyH", "SetWordWrap", "SetTextColor", "SetFontObject",
                          "SetAllPoints", "SetColorTexture", "SetTexture", "SetTexCoord", "SetAlpha", "SetDrawLayer", "SetFont", "SetShadowOffset",
                          "SetDesaturated", "SetVertexColor", "ClearAllPoints", "SetJustifyV", "SetNonSpaceWrap", "SetSpacing", "SetMaxLines",
                          "SetBlendMode", "SetHorizTile", "SetVertTile", "SetSnapToPixelGrid", "SetTexelSnappingBias", "SetScale" }) do
        f[m] = NOOP
    end
    -- colours are kept, so a test can tell gold from grey
    f.SetTextColor = function(self, r, g, b, a) self.textColor = { r, g, b, a } end
    f.SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a }; self.atlas = nil end
    f.SetAlpha = function(self, a) self.alpha = a end
    f.GetAlpha = function(self) return self.alpha or 1 end
    f.SetPoint = setPoint
    f.SetAllPoints = setAllPoints
    f.ClearAllPoints = function(self) self.points = {} end
    f.SetWidth = function(self, w) self._w = w end
    f.SetHeight = function(self, h) self._h = h end
    f.SetSize = function(self, w, h) self._w, self._h = w, h end
    f.SetTexture = function(self, t) self.texture = t end
    -- an atlas of the client's art by name; the test reads it back. Every call is counted
    -- (STUB.atlasCalls); an atlas the client lacks draws nothing and answers false, as in the client.
    f.SetAtlas = function(self, name, useAtlasSize)
        assert(type(name) == "string" and name ~= "", "SetAtlas needs an atlas name")
        STUB.atlasCalls[name] = (STUB.atlasCalls[name] or 0) + 1
        if not C_Texture.GetAtlasInfo(name) then
            self.atlas = nil
            return false
        end
        self.atlas, self.texture, self.color = name, nil, nil
        return true
    end
    f.GetAtlas = function(self) return self.atlas end
    f.SetText = function(self, t) self.text = t end
    f.GetText = function(self) return self.text end
    f.Show = function(self) self.shown = true end
    f.Hide = function(self) self.shown = false end
    f.IsShown = function(self) return self.shown end
    f.SetShown = function(self, on) self.shown = on and true or false end
    f.GetStringWidth = function(self) return #tostring(self.text or "") * 6 end
    f.GetStringHeight = function(self) return 14 end
    -- a texture turns (radians, counter-clockwise); STUB.noRotation makes regions without it
    if not STUB.noRotation then f.SetRotation = function(self, r) self.rotation = r end end
    return f
end
-- The client's atlases Amisia and the templates it inherits use, with their size (Forever 1.60.1;
-- the sizes are only plausible, the names are the client's). C_Texture.GetAtlasInfo answers them;
-- STUB.missingAtlases[name] makes one go missing (a patch renamed it).
STUB.missingAtlases, STUB.atlasCalls = {}, {}
STUB.atlases = {
    ["Profession-Background-Overview"] = { 750, 594 },
    ["Professions-background-summarylist"] = { 304, 480 },
    ["Professions_Recipe_Active"] = { 270, 20 },
    ["Professions_Recipe_Hover"] = { 270, 20 },
    ["common-insideframe"] = { 420, 420 },
    ["Professions-skillbar-bg"] = { 453, 18 },
    ["Professions-skillbar-frame"] = { 451, 29 },
    ["common-dropdown-bg"] = { 128, 128 },
    ["common-search-border-left"] = { 8, 20 },
    ["common-search-border-middle"] = { 10, 20 },
    ["common-search-border-right"] = { 8, 20 },
    ["common-search-magnifyingglass"] = { 10, 10 },
    ["common-search-clearbutton"] = { 10, 10 },
    ["common-sidetab"] = { 43, 50 },
    ["common-button-list-collapseExpand"] = { 300, 25 },
    ["common-button-list-minus"] = { 12, 12 },
    ["common-button-list-plus"] = { 12, 12 },
    ["checkbox-minimal"] = { 30, 29 },
    ["checkmark-minimal"] = { 30, 29 },
    ["checkmark-minimal-disabled"] = { 30, 29 },
    ["RedButton-Exit"] = { 24, 24 },
    ["RedButton-Highlight"] = { 24, 24 },
}
for _, base in ipairs({ "common-dropdown-a-button", "common-dropdown-b-button" }) do
    STUB.atlases[base] = { 26, 26 }
    for _, s in ipairs({ "hover", "pressed", "pressedhover", "open", "disabled" }) do
        STUB.atlases[base .. "-" .. s] = { 26, 26 }
        if base == "common-dropdown-a-button" then STUB.atlases[base .. "-" .. s .. "-shadowless"] = { 26, 26 } end
    end
end
STUB.atlases["common-dropdown-a-button-shadowless"] = { 26, 26 }
for _, part in ipairs({ "128-RedButton-Left", "128-RedButton-Right", "_128-RedButton-Center" }) do
    for _, s in ipairs({ "", "-Pressed", "-Disabled" }) do STUB.atlases[part .. s] = { part:find("Center") and 64 or 114, 128 } end
end
STUB.atlases["128-RedButton-Highlight"] = { 441, 128 }
_G.C_Texture = {
    GetAtlasInfo = function(name)
        local a = type(name) == "string" and not STUB.missingAtlases[name] and STUB.atlases[name]
        if not a then return nil end
        return { width = a[1], height = a[2], file = 1, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
    end,
}

-- Colours and strings of the client (the German one).
local function color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1, GetRGB = function(self) return self.r, self.g, self.b end,
             GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
end
_G.NORMAL_FONT_COLOR = color(1, 0.82, 0)
_G.HIGHLIGHT_FONT_COLOR = color(1, 1, 1)
_G.DISABLED_FONT_COLOR = color(0.5, 0.5, 0.5)
_G.SEARCH = "Suchen"
_G.BaseScrollBoxEvents = { OnScroll = "OnScroll" }
_G.ScrollBoxConstants = { NoScrollInterpolation = true }

-- HideUIPanel and ShowUIPanel are blocked for an addon's call in combat ("Aktion blockiert"):
-- the stub raises then.
_G.HideUIPanel = function(frame)
    if InCombatLockdown() then error("HideUIPanel: action blocked in combat") end
    if frame then frame:Hide() end
end
_G.ShowUIPanel = function(frame)
    if InCombatLockdown() then error("ShowUIPanel: action blocked in combat") end
    if frame then frame:Show() end
end
_G.UIPanelCloseButton_OnClick = function(self)
    local parent = self:GetParent()
    if parent then HideUIPanel(parent) end
end

-- The templates of the client Amisia inherits, by name: each builder makes the parts and methods
-- of the template Amisia touches (Blizzard_SharedXML of Forever 1.60.1). The template's own
-- scripts are set as in the client, so a test can tell whether the addon kept them (HookScript)
-- or threw them away (SetScript); they count their runs in tplRuns[script].
local TEMPLATES = {}
STUB.templates = TEMPLATES
STUB.missingTemplates = {}
local function tplScript(f, script, fn)
    f.scripts[script] = function(self, ...)
        self.tplRuns = self.tplRuns or {}
        self.tplRuns[script] = (self.tplRuns[script] or 0) + 1
        if fn then return fn(self, ...) end
    end
end
local function part(f, key, layer, globalSuffix)
    local t = f:CreateTexture(nil, layer)
    f[key] = t
    if globalSuffix and f.name then _G[f.name .. globalSuffix] = t end
    return t
end
local function closeButton(f, kind, name)
    f.tplW, f.tplH = 24, 24
    f:SetFrameLevel(510)
    tplScript(f, "OnClick", UIPanelCloseButton_OnClick)
end
TEMPLATES.UIPanelCloseButton = closeButton
TEMPLATES.UIPanelCloseButtonDefaultAnchors = function(f, kind, name)
    closeButton(f, kind, name)
    f:SetPoint("TOPRIGHT", -2, 1)
end
TEMPLATES.UIPanelButtonTemplate = function(f)
    f.Text = f:CreateFontString()
    f.Left, f.Middle, f.Right = f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
end
TEMPLATES.UIPanelScrollFrameTemplate = function(f)
    f.ScrollBar = CreateFrame("Slider", nil, f)
end
TEMPLATES.PortraitFrameTemplate = function(f, kind, name)
    f.tplW, f.tplH = 338, 424
    f.NineSlice = CreateFrame("Frame", nil, f)
    f.NineSlice:SetFrameLevel(500)
    f.NineSlice:SetAllPoints()
    local bg = part(f, "Bg", "BACKGROUND", "Bg")
    bg.texture = "Interface\\FrameGeneral\\UI-Background-Rock"
    bg:SetPoint("TOPLEFT", 2, -21)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    local streaks = part(f, "TopTileStreaks", "BORDER")
    streaks:SetPoint("TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", -2, -21)
    f.PortraitContainer = CreateFrame("Frame", nil, f)
    f.PortraitContainer:SetFrameLevel(400)
    f.PortraitContainer:SetSize(1, 1)
    f.PortraitContainer:SetPoint("TOPLEFT")
    local portrait = f.PortraitContainer:CreateTexture(nil, "OVERLAY")
    portrait:SetSize(62, 62)
    portrait:SetPoint("TOPLEFT", -5, 7)
    f.PortraitContainer.portrait = portrait
    if name then _G[name .. "Portrait"] = portrait end
    f.TitleContainer = CreateFrame("Frame", nil, f)
    f.TitleContainer:SetFrameLevel(510)
    f.TitleContainer:SetHeight(20)
    f.TitleContainer:SetPoint("TOPLEFT", 58, -1)
    f.TitleContainer:SetPoint("TOPRIGHT", -24, -1)
    local title = f.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetPoint("LEFT")
    title:SetPoint("RIGHT")
    f.TitleContainer.TitleText = title
    if name then _G[name .. "TitleText"] = title end
    f.CloseButton = CreateFrame("Button", name and (name .. "CloseButton") or nil, f, "UIPanelCloseButtonDefaultAnchors")
    -- a template's children are shown, as in the client
    f.NineSlice.shown, f.PortraitContainer.shown, f.TitleContainer.shown, f.CloseButton.shown = true, true, true, true
    f.SetPortraitToAsset = function(self, tex) self.portraitAsset = tex; self.PortraitContainer.portrait:SetTexture(tex) end
    f.SetPortraitShown = function(self, on) self.PortraitContainer.portrait:SetShown(on) end
    f.SetBorder = function(self, layout) self.border = layout end
    f.GetTitleText = function(self) return self.TitleContainer.TitleText end
    f.SetTitle = function(self, t) self.TitleContainer.TitleText:SetText(t) end
    f.SetTitleOffsets = function(self, l, r)
        self.TitleContainer:SetPoint("TOPLEFT", self, "TOPLEFT", l or 58, -1)
        self.TitleContainer:SetPoint("TOPRIGHT", self, "TOPRIGHT", r or -24, -1)
    end
end
-- the three-slice red button: its slices follow the state and the height (UpdateScale)
TEMPLATES.SharedButtonSmallTemplate = function(f)
    f.tplW, f.tplH = 138, 28
    f.Left, f.Right, f.Center = f:CreateTexture(nil, "BACKGROUND"), f:CreateTexture(nil, "BACKGROUND"), f:CreateTexture(nil, "BACKGROUND")
    f.Left:SetPoint("TOPLEFT")
    f.Right:SetPoint("TOPRIGHT")
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Text:SetPoint("CENTER")
    local setText = f.SetText
    f.SetText = function(self, t) setText(self, t); self.Text:SetText(t) end
    for _, s in ipairs({ "OnMouseDown", "OnMouseUp", "OnShow", "OnEnable", "OnDisable", "OnEnter", "OnLeave", "OnSizeChanged" }) do
        tplScript(f, s)
    end
    f.motionScriptsWhileDisabled = true
end
TEMPLATES.ListHeaderVisualTemplate = function(f)
    f.CollapseButton = CreateFrame("Button", nil, f)
    f.CollapseButton:SetSize(20, 20)
    f.CollapseButton.shown = true
    f.CollapseButton:SetPoint("RIGHT", -6, 0)
    f.CollapseButton.Icon = f.CollapseButton:CreateTexture(nil, "ARTWORK")
    f.ButtonText = f:CreateFontString(nil, "OVERLAY", "Game15Font_Shadow")
    f.ButtonText:SetPoint("LEFT", 8, 0)
    f.ButtonText:SetPoint("RIGHT", f.CollapseButton, "LEFT", -4, 0)
    f.SetHeaderText = function(self, t) self.ButtonText:SetText(t) end
    f.SetTitleColor = function(self, useHighlight, c)
        self.titleColors = self.titleColors or {}
        self.titleColors[useHighlight] = c
        if not useHighlight then self.ButtonText:SetTextColor(c:GetRGB()) end
    end
    f.GetCollapseButton = function(self) return self.CollapseButton end
end
TEMPLATES.ListHeaderCodeTemplate = function(f)
    f.SetClickHandler = function(self, fn) self.customClickHandler = fn end
    tplScript(f, "OnClick", function(self, button) if self.customClickHandler then self.customClickHandler(self, button) end end)
    for _, s in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do tplScript(f, s) end
    f.UpdateCollapsedState = function(self, collapsed)
        self.collapsed = collapsed
        if self.CollapseButton then
            self.CollapseButton.collapsed = collapsed
            self.CollapseButton.Icon.atlas = collapsed and "common-button-list-plus" or "common-button-list-minus"
        end
    end
end
-- the side tab: a Frame (no Button); a click comes through the custom mouse-up handler
TEMPLATES.LargeSideTabButtonTemplate = function(f)
    f.tplW, f.tplH = 43, 50
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.SelectedTexture = f:CreateTexture(nil, "OVERLAY")
    f.SelectedTexture:Hide()
    f.SetChecked = function(self, on) self.checked = on and true or false; self.SelectedTexture:SetShown(self.checked) end
    f.SetCustomOnMouseUpHandler = function(self, fn) self.customMouseUpHandler = fn end
    tplScript(f, "OnMouseUp", function(self, button, upInside)
        if self.customMouseUpHandler then self.customMouseUpHandler(self, button, upInside) end
    end)
end
function STUB.clickTab(tab) tab.scripts.OnMouseUp(tab, "LeftButton", true) end
local function inputVisual(f)
    f.tplH = 20
    f.Left = f:CreateTexture(nil, "BACKGROUND")
    f.Left:SetSize(8, 20)
    f.Left:SetPoint("LEFT", -5, 0)
    f.Right = f:CreateTexture(nil, "BACKGROUND")
    f.Right:SetSize(8, 20)
    f.Right:SetPoint("RIGHT", 0, 0)
    f.Middle = f:CreateTexture(nil, "BACKGROUND")
    f.Middle:SetHeight(20)
    f.Middle:SetPoint("LEFT", f.Left, "RIGHT")
    f.Middle:SetPoint("RIGHT", f.Right, "LEFT")
end
TEMPLATES.InputBoxTemplate = function(f)
    inputVisual(f)
    tplScript(f, "OnEscapePressed", function(self) self:ClearFocus() end)
    tplScript(f, "OnEditFocusLost")
    tplScript(f, "OnEditFocusGained")
    tplScript(f, "OnTabPressed")
end
TEMPLATES.SearchBoxTemplate = function(f)
    TEMPLATES.InputBoxTemplate(f)
    f.Instructions = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.Instructions:SetPoint("TOPLEFT", 16, 0)
    f.Instructions:SetPoint("BOTTOMRIGHT", -20, 0)
    f.Instructions:SetText(SEARCH)
    f.searchIcon = f:CreateTexture(nil, "OVERLAY")
    f.clearButton = CreateFrame("Button", nil, f)
    f.clearButton:SetSize(17, 17)
    f.clearButton:SetPoint("RIGHT", -3, 0)
    f.clearButton.shown = false
    tplScript(f.clearButton, "OnClick", function(self)
        local box = self:GetParent()
        box:SetText("")
        if box.scripts.OnTextChanged then box.scripts.OnTextChanged(box, false) end
        box:ClearFocus()
    end)
    tplScript(f, "OnEscapePressed", function(self) self:ClearFocus() end)
    tplScript(f, "OnEnterPressed", function(self) self:ClearFocus() end)
    tplScript(f, "OnEditFocusLost", function(self) if self:GetText() == "" then self.clearButton:Hide() end end)
    tplScript(f, "OnEditFocusGained", function(self) self.clearButton:Show() end)
    tplScript(f, "OnTextChanged", function(self)
        self.clearButton:SetShown(self:HasFocus() or self:GetText() ~= "")
        self.Instructions:SetShown(self:GetText() == "")
    end)
end
-- the minimal scroll bar: visible (extent), pan and scroll as percentages; a change of the scroll
-- runs the OnScroll callbacks (owner, percentage), as the client's does
local function clamp01(v) return math.max(0, math.min(1, v or 0)) end
TEMPLATES.MinimalScrollBar = function(f)
    f.tplW, f.tplH = 8, 560
    f.visible, f.pan, f.scroll, f.callbacks = 0, 0, 0, {}
    local function update(self)
        if self.hideIfUnscrollable then self:SetShown(self:HasScrollableExtent()) end
    end
    f.HasScrollableExtent = function(self) return self.visible > 1e-5 and self.visible < 1 - 1e-5 end
    f.SetVisibleExtentPercentage = function(self, p) self.visible = clamp01(p); update(self) end
    f.GetVisibleExtentPercentage = function(self) return self.visible end
    f.SetPanExtentPercentage = function(self, p) self.pan = clamp01(p) end
    f.GetPanExtentPercentage = function(self) return self.pan end
    f.GetScrollPercentage = function(self) return self.scroll end
    f.SetHideIfUnscrollable = function(self, on) self.hideIfUnscrollable = on; update(self) end
    f.RegisterCallback = function(self, event, fn, owner)
        self.callbacks[#self.callbacks + 1] = { event = event, fn = fn, owner = owner }
    end
    f.SetScrollPercentage = function(self, p)
        self.scroll = clamp01(p)
        update(self)
        for _, c in ipairs(self.callbacks) do
            if c.event == BaseScrollBoxEvents.OnScroll then c.fn(c.owner, self.scroll) end
        end
    end
    f.ScrollStepInDirection = function(self, dir) self:SetScrollPercentage(self.scroll + self.pan * dir) end
end
function STUB.scrollBar(bar, pct) bar:SetScrollPercentage(pct) end
TEMPLATES.MinimalCheckboxTemplate = function(f, kind)
    if kind ~= "CheckButton" then error("MinimalCheckboxTemplate needs a CheckButton", 3) end
    f.tplW, f.tplH = 30, 29
end
TEMPLATES.TooltipBackdropTemplate = function(f)
    f.NineSlice = CreateFrame("Frame", nil, f)
    f.NineSlice:SetAllPoints()
end
-- The addon's own template (MapPin.xml); the pins come from the map's pin pools.
TEMPLATES.AmisiaMapPinTemplate = function() end

local frameMethods = { "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "SetAllPoints", "SetScrollChild", "SetVerticalScroll", "SetMultiLine", "SetMaxLetters", "SetAutoFocus", "SetFontObject",
    "SetCursorPosition", "HighlightText", "SetFocus", "ClearFocus", "EnableMouseWheel", "SetFrameLevel", "SetToplevel", "StartMoving",
    "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetScale", "SetID",
    "SetEnabled", "Disable", "Enable", "SetTextColor", "ClearAllPoints", "SetResizable", "SetHitRectInsets", "RegisterForClicks",
    "Raise", "Lower", "SetUserPlaced", "SetJustifyH", "SetJustifyV", "SetTextInsets", "SetNumeric", "SetHighlightFontObject", "SetNormalFontObject",
    "SetHyperlink" }
function _G.CreateFrame(kind, name, parent, template)
    local f = { kind = kind, name = name, shown = false, scripts = {}, events = {}, text = "", parent = parent }
    for _, m in ipairs(frameMethods) do f[m] = NOOP end
    f.SetScript = function(self, k, fn) self.scripts[k] = fn end
    f.GetScript = function(self, k) return self.scripts[k] end
    f.HookScript = function(self, k, fn)
        local o = self.scripts[k]
        self.scripts[k] = function(...) if o then o(...) end fn(...) end
    end
    f.RegisterEvent = function(self, e) self.events[e] = true; STUB.frames[self] = true end
    f.UnregisterEvent = function(self, e) self.events[e] = nil end
    f.Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    f.Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    f.IsShown = function(self) return self.shown end
    f.SetShown = function(self, on) if on then self:Show() else self:Hide() end end
    f.IsVisible = f.IsShown
    f.SetText = function(self, t) self.text = t end
    f.GetText = function(self) return self.text end
    f.CreateFontString = function(self) return region(self) end
    f.CreateTexture = function(self) return region(self) end
    f.GetParent = function() return parent end
    f.GetName = function() return name end
    f.SetPoint = setPoint
    f.SetAllPoints = setAllPoints
    f.ClearAllPoints = function(self) self.points = {} end
    -- level, top-level flag and raises are recorded for the stacking tests
    f.SetFrameLevel = function(self, l) self._level = l end
    f.GetFrameLevel = function(self) return self._level or (parent and parent.GetFrameLevel and parent:GetFrameLevel() + 1) or 1 end
    f.SetToplevel = function(self, on) self.toplevel = on and true or false end
    f.Raise = function(self) self.raised = (self.raised or 0) + 1 end
    f.GetFrameStrata = function(self) return self.strata or (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or "MEDIUM" end
    f.GetPoint = function(self) return self._point or "CENTER", nil, self._point or "CENTER", self._x or 0, self._y or 0 end
    -- a template's own size (tplW, tplH) counts until the addon sets one
    f.GetWidth = function(self) return self._w or self.tplW or 400 end
    f.GetHeight = function(self) return self._h or self.tplH or 300 end
    f.GetScale = function(self) return self._scale or 1 end
    f.SetScale = function(self, s) self._scale = s end
    f.SetSize = function(self, w, h) self._w, self._h = w, h end
    f.SetWidth = function(self, w) self._w = w end
    f.SetHeight = function(self, h) self._h = h end
    f.GetChecked = function(self) return self.checked end
    f.SetFrameStrata = function(self, s) self.strata = s end
    -- one edit box holds the keyboard focus; gaining and losing it runs the scripts, as in the client
    f.SetFocus = function(self)
        local old = STUB.focus
        if old == self then return end
        STUB.focus = self
        if old and old.scripts.OnEditFocusLost then old.scripts.OnEditFocusLost(old) end
        if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
    end
    f.ClearFocus = function(self)
        if STUB.focus ~= self then return end
        STUB.focus = nil
        if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
    end
    f.HasFocus = function(self) return STUB.focus == self end
    f.IsMouseOver = function() return false end
    f.SetOwner = NOOP
    f.AddLine = NOOP
    f.AddDoubleLine = NOOP
    f.NumLines = function() return 0 end
    -- the item a tooltip shows: STUB.showTooltip sets shownLink, a test may set shownName too
    f.GetItem = function(self) return self.shownName, self.shownLink end
    -- a disabled button ignores clicks, as in the client
    -- a change of the state runs OnEnable or OnDisable, as in the client
    f.enabled = true
    f.SetEnabled = function(self, on)
        on = on and true or false
        if self.enabled == on then return end
        self.enabled = on
        local s = self.scripts[on and "OnEnable" or "OnDisable"]
        if s then s(self) end
    end
    f.Enable = function(self) self:SetEnabled(true) end
    f.Disable = function(self) self:SetEnabled(false) end
    f.IsEnabled = function(self) return self.enabled end
    f.Click = function(self) if self.enabled and self.scripts.OnClick then self.scripts.OnClick(self) end end
    f.SetTextInsets = function(self, l, r, t, b) self.insets = { l, r, t, b } end
    f.SetVerticalScroll = function(self, v) self.vscroll = v end
    f.GetVerticalScroll = function(self) return self.vscroll or 0 end
    f.GetVerticalScrollRange = function(self) return self.vrange or 0 end
    -- a check button turns itself over before OnClick runs, as in the client
    if kind == "CheckButton" then
        f.SetChecked = function(self, on) self.checked = on and true or false end
        f.checked = false
        f.Click = function(self)
            if not self.enabled then return end
            self.checked = not self.checked
            if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end
        end
    end
    if name then _G[name] = f end
    if template ~= nil then
        f.inherits, f.template = {}, template
        for t in tostring(template):gmatch("[^,]+") do
            t = t:match("^%s*(.-)%s*$")
            local build = not STUB.missingTemplates[t] and TEMPLATES[t]
            if not build then
                if name then _G[name] = nil end
                error(("CreateFrame: unknown template '%s'"):format(t), 2)
            end
            f.inherits[t] = true
            build(f, kind, name)
        end
    end
    return f
end
function STUB.fire(event, ...)
    for f in pairs(STUB.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) STUB.messages[#STUB.messages + 1] = t end }
_G.UIParent = CreateFrame("Frame", "UIParent")
_G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
_G.ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
_G.UISpecialFrames = {}
-- The client's four group loot roll frames, each with its item icon and the rollID it shows.
_G.NUM_GROUP_LOOT_FRAMES = 4
for i = 1, 4 do
    local f = CreateFrame("Frame", "GroupLootFrame" .. i, UIParent)
    f.IconFrame = CreateFrame("Button", nil, f)
end
_G.StaticPopupDialogs = {}
-- The last dialog shown; STUB.acceptPopup() presses its first button.
_G.StaticPopup_Show = function(which, a1, a2, data)
    STUB.popup = { which = which, a1 = a1, a2 = a2, data = data }
    return STUB.popup
end
function STUB.acceptPopup()
    local p = STUB.popup
    STUB.popup = nil
    local d = p and StaticPopupDialogs[p.which]
    if d and d.OnAccept then d.OnAccept(p, p.data) end
end
_G.SlashCmdList = {}
_G.ChatFontNormal = {}
_G.GameFontNormal = {}
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    SHAMAN = { r = 0, g = 0.44, b = 0.87, colorStr = "ff0070de" },
    PRIEST = { r = 1, g = 1, b = 1, colorStr = "ffffffff" },
}
_G.LOOT_ITEM = "%s receives loot: %s."
_G.LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED = "%s receives item: %s."
_G.LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
_G.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
Enum.TooltipDataType = { Item = 0 }
Enum.LootMethod = { Freeforall = 0, Masterlooter = 2 }
Enum.BankType = { Character = 0 }

-- The tooltip data processor: every registered post call is kept in STUB.tdp ({ kind, fn }); the
-- shown item comes from TooltipUtil.GetDisplayedItem (here the tooltip's GetItem).
-- STUB.showTooltip(tip, link) builds an item tooltip: it runs the item post calls, as the client
-- does after every SetHyperlink, SetBagItem, SetLootItem and the like.
STUB.tdp = {}
_G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) STUB.tdp[#STUB.tdp + 1] = { kind = kind, fn = fn } end }
_G.TooltipUtil = { GetDisplayedItem = function(tip) return tip:GetItem() end }
function STUB.showTooltip(tip, link)
    if link ~= nil then tip.shownLink = link end
    for _, e in ipairs(STUB.tdp) do
        if e.kind == Enum.TooltipDataType.Item then e.fn(tip, { hyperlink = tip.shownLink }) end
    end
end

-- The loot window: a scroll box with two element frames that show other slots as it scrolls (no
-- LootButton frames, no LootFrame_Update). Each element has its icon button (Item) and the quality
-- text at its own top right. LootFrame.ScrollBox:ShowFrom(first) runs the initialised-frame
-- callbacks, as the client does after its initializer.
ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } }
do
    local box = { frames = {}, callbacks = {} }
    function box:ForEachFrame(fn) for _, f in ipairs(self.frames) do fn(f, f.data) end end
    function box:RegisterCallback(event, fn, owner)
        for _, c in ipairs(self.callbacks) do
            if c.event == event and c.owner == owner then c.fn = fn return owner end
        end
        self.callbacks[#self.callbacks + 1] = { event = event, fn = fn, owner = owner }
        return owner
    end
    function box:ShowFrom(first)
        for i, f in ipairs(self.frames) do
            f.slotIndex = first + i - 1
            f.data = { slotIndex = f.slotIndex }
            for _, c in ipairs(self.callbacks) do
                if c.event == ScrollBoxListMixin.Event.OnInitializedFrame then c.fn(c.owner, f, f.data) end
            end
        end
    end
    ScrollUtil = {
        AddInitializedFrameCallback = function(scrollBox, callback, owner, iterateExisting)
            if iterateExisting then scrollBox:ForEachFrame(callback) end
            scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(o, frame, data) callback(o, frame, data) end, owner)
        end,
        -- a plain scroll frame with a minimal scroll bar: the pair is kept (STUB.scrollPairs), the
        -- wheel steps the bar and the bar scrolls the frame, as ScrollUtil.lua does
        InitScrollFrameWithScrollBar = function(sf, bar)
            STUB.scrollPairs[#STUB.scrollPairs + 1] = { sf, bar }
            sf:SetScript("OnMouseWheel", function(_, delta) bar:ScrollStepInDirection(-delta) end)
            sf:SetScript("OnScrollRangeChanged", function() end)
            sf:SetScript("OnVerticalScroll", function() end)
            bar:RegisterCallback(BaseScrollBoxEvents.OnScroll, function(o, pct) sf:SetVerticalScroll(pct * sf:GetVerticalScrollRange()) end, sf)
        end,
    }
    STUB.scrollPairs = {}
    for i = 1, 2 do
        local f = CreateFrame("Frame", nil, nil)
        f.Item = CreateFrame("Button", nil, f)
        f.QualityText = f:CreateFontString()
        f.QualityText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -2)
        f.GetSlotIndex = function(self) return self.slotIndex end
        f.slotIndex = i
        box.frames[i] = f
    end
    LootFrame = { ScrollBox = box }
end

-- The player's own character for the best-item targets: class, level, faction (STUB.class,
-- STUB.level, STUB.faction), what is worn (STUB.worn[inventory slot] = link), the bags and the
-- bank (STUB.bags[bag] = { link or item id, ... }), the counts the client knows without a bank
-- visit (STUB.bank[id] = count in the bank), the purchased tabs of the character bank
-- (STUB.bankTabs = { bag ids }, through C_Bank), the talent points per tree (STUB.talents =
-- { 0, 31, 30 }), the skill lines (STUB.skills = { { name, rank, header, id } }, through
-- C_SkillInfo) and where the player is (STUB.place = { map = uiMapID }, with
-- STUB.maps[uiMapID] = { name, parentMapID, mapType }). PlaySound counts in STUB.sounds.
-- STUB.level stays nil until a test sets it (a client that answers no level, as older tests expect)
STUB.class, STUB.level, STUB.faction = "WARRIOR", nil, "Alliance"
STUB.worn, STUB.bags, STUB.bank, STUB.talents, STUB.skills, STUB.place, STUB.maps, STUB.sounds = {}, {}, {}, nil, nil, {}, {}, {}
STUB.bankTabs = {}
local CLASS_LOCAL = { WARRIOR = "Krieger", PALADIN = "Paladin", HUNTER = "Jäger", ROGUE = "Schurke", PRIEST = "Priester",
    SHAMAN = "Schamane", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druide" }
_G.UnitClass = function() return CLASS_LOCAL[STUB.class] or STUB.class, STUB.class end
_G.UnitLevel = function() return STUB.level end
_G.UnitFactionGroup = function() return STUB.faction end
_G.GetInventoryItemLink = function(_, slot) return STUB.worn[slot] end
_G.NUM_BAG_SLOTS = 4
_G.C_Bank = {
    FetchPurchasedBankTabIDs = function(kind)
        if kind ~= Enum.BankType.Character then return {} end
        local out = {}
        for i, id in ipairs(STUB.bankTabs) do out[i] = id end
        return out
    end,
}
local function bagEntry(bag, slot)
    local b = STUB.bags[bag]
    local v = b and b[slot]
    if type(v) == "number" then return v, STUB.items[v] and STUB.items[v].link or ("item:" .. v) end
    if type(v) == "string" then return itemId(v), v end
    return nil
end
_G.C_Container = {
    GetContainerNumSlots = function(bag) return STUB.bags[bag] and #STUB.bags[bag] or 0 end,
    GetContainerItemID = function(bag, slot) return (bagEntry(bag, slot)) end,
    GetContainerItemLink = function(bag, slot) return select(2, bagEntry(bag, slot)) end,
}
-- counts over bags 0-4 and worn items; with includeBank also the bank bags and STUB.bank
C_Item.GetItemCount = function(item, includeBank)
    local id = itemId(item)
    local n = 0
    for bag, list in pairs(STUB.bags) do
        if (bag >= 0 and bag <= 4) or includeBank then
            for slot = 1, #list do if bagEntry(bag, slot) == id then n = n + 1 end end
        end
    end
    for _, link in pairs(STUB.worn) do if itemId(link) == id then n = n + 1 end end
    if includeBank then n = n + (STUB.bank[id] or 0) end
    return n
end
_G.C_SpecializationInfo = {
    GetSpecializationInfo = function(i)
        local pts = STUB.talents and STUB.talents[i]
        if not pts then return 0 end
        return 100 + i, "Baum " .. i, "", 0, "DAMAGER", 1, pts, "", 0, true
    end,
}
-- one table per skill line, with the fields of SkillLineAttributes (SkillInfoDocumentation.lua)
_G.C_SkillInfo = {
    GetNumSkillLines = function() return STUB.skills and #STUB.skills or 0 end,
    GetSkillLineInfo = function(i)
        local s = STUB.skills and STUB.skills[i]
        if not s then return nil end
        return { name = s.name, skillID = s.id or 0, isHeader = s.header and true or false, isCollapsed = false,
                 rank = s.rank or 0, tempPoints = 0, modifier = 0, maxRank = s.max or 300 }
    end,
}
C_Map.GetBestMapForUnit = function() return STUB.place.map end
C_Map.GetMapInfo = function(id)
    local m = STUB.maps[id]
    if not m then return nil end
    return { mapID = id, name = m.name, parentMapID = m.parent or 0, mapType = m.mapType or 3 }
end
_G.SOUNDKIT = { RAID_WARNING = 8959 }
_G.PlaySound = function(kit) STUB.sounds[#STUB.sounds + 1] = kit; return true end
_G.IsInInstance = function()
    local t = STUB.instance and STUB.instance.type or "none"
    return t ~= "none", t
end

local QCOLOR = { [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }
function STUB.link(id, name, q)
    return ("|c%s|Hitem:%d::::::::70:::::|h[%s]|h|r"):format(QCOLOR[q or 4] or "ffffffff", id, name)
end
-- Registers an item the fake client "knows" and returns its link.
function STUB.item(id, name, q)
    STUB.items[id] = { name = name, quality = q or 4, link = STUB.link(id, name, q) }
    return STUB.items[id].link
end

-- The map. Where the player stands on STUB.place.map: STUB.map.pos = { x, y } (0-1; nil = unknown,
-- as in an instance). Where a map lies in the world: STUB.maps[id].world = { continent, x0, y0, w, h }
-- (world x = x0 + x * w, world y = y0 + y * h, in yards). Zone rectangles on a continent:
-- STUB.map.rects["<zone>><continent>"] = { left, right, top, bottom }.
STUB.map = { pos = nil, rects = {} }
_G.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
C_Map.GetPlayerMapPosition = function(mapID, unit)
    local p = STUB.map.pos
    if unit ~= "player" or not p or mapID ~= STUB.place.map then return nil end
    return CreateVector2D(p.x, p.y)
end
C_Map.GetWorldPosFromMapPos = function(mapID, pos)
    local m = STUB.maps[mapID]
    local w = m and m.world
    if not w then return nil end
    return w[1], CreateVector2D(w[2] + pos.x * w[4], w[3] + pos.y * w[5])
end
C_Map.GetMapRectOnMap = function(mapID, top)
    local r = STUB.map.rects[tostring(mapID) .. ">" .. tostring(top)]
    if not r then return nil end
    return r[1], r[2], r[3], r[4]
end
-- The client's user waypoint (Forever): STUB.waypoint.point = { uiMapID, position } or nil;
-- STUB.waypoint.blocked[uiMapID] = true for a map that takes none; superTracked is the guide arrow.
-- Setting or clearing it fires USER_WAYPOINT_UPDATED, as the client does; sets and clears count the
-- calls. A test's preload takes these away for a client without them.
STUB.waypoint = { point = nil, blocked = {}, superTracked = false, sets = 0, clears = 0 }
C_Map.CanSetUserWaypointOnMap = function(id) return not STUB.waypoint.blocked[id] end
C_Map.SetUserWaypoint = function(point)
    if STUB.waypoint.blocked[point.uiMapID] then return false end
    STUB.waypoint.point = { uiMapID = point.uiMapID, position = CreateVector2D(point.position.x, point.position.y) }
    STUB.waypoint.sets = STUB.waypoint.sets + 1
    STUB.fire("USER_WAYPOINT_UPDATED")
    return true
end
C_Map.ClearUserWaypoint = function()
    STUB.waypoint.point, STUB.waypoint.superTracked = nil, false
    STUB.waypoint.clears = STUB.waypoint.clears + 1
    STUB.fire("USER_WAYPOINT_UPDATED")
end
C_Map.GetUserWaypoint = function() return STUB.waypoint.point end
C_Map.HasUserWaypoint = function() return STUB.waypoint.point ~= nil end
C_Map.GetUserWaypointPositionForMap = function(id)
    local p = STUB.waypoint.point
    if p and p.uiMapID == id then return CreateVector2D(p.position.x, p.position.y) end
    return nil
end
C_Map.GetUserWaypointHyperlink = function()
    local p = STUB.waypoint.point
    if not p then return nil end
    return ("|cffffff00|Hworldmap:%d:%d:%d|h[Kartenmarkierung]|h|r"):format(p.uiMapID,
        math.floor(p.position.x * 10000 + 0.5), math.floor(p.position.y * 10000 + 0.5))
end
_G.UiMapPoint = { CreateFromCoordinates = function(id, x, y, z) return { uiMapID = id, position = CreateVector2D(x, y), z = z } end }
_G.C_SuperTrack = {
    SetSuperTrackedUserWaypoint = function(on) STUB.waypoint.superTracked = on and true or false end,
    IsSuperTrackingUserWaypoint = function() return STUB.waypoint.superTracked end,
}
-- The player's facing in radians (STUB.facing; nil = unknown).
_G.GetPlayerFacing = function() return STUB.facing end
-- The world map: shown or not and the map it shows (mapID); OpenWorldMap opens it on a map.
_G.WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame.SetMapID = function(self, id) self.mapID = id end
WorldMapFrame.GetMapID = function(self) return self.mapID end
_G.OpenWorldMap = function(id)
    WorldMapFrame:Show()
    if id then WorldMapFrame:SetMapID(id) end
end
_G.ToggleWorldMap = function() WorldMapFrame:SetShown(not WorldMapFrame:IsShown()) end

-- Mixins and the map canvas as both clients' FrameXML has them (Blizzard_MapCanvas): data providers
-- added with AddDataProvider get OnAdded, RefreshAllData on show and OnMapChanged on a new map;
-- AcquirePin makes pins from a named template, applies its mixin (STUB.pinTemplates[template] names
-- the mixin global, as the XML file would; a test reads it from MapPin.xml), runs OnLoad once and
-- OnAcquired every time; RemoveAllPinsByTemplate releases them. STUB.mapPins(template) lists the
-- active pins. A Forever-style pin mixin (passthrough buttons, OnMouseClickAction) comes from a
-- test's preload.
_G.Mixin = function(object, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do object[k] = v end
    end
    return object
end
_G.CreateFromMixins = function(...) return Mixin({}, ...) end
_G.MapCanvasDataProviderMixin = {
    OnAdded = function(self, map) self.owningMap = map end,
    OnRemoved = function(self) self.owningMap = nil end,
    RemoveAllData = NOOP, RefreshAllData = NOOP, OnShow = NOOP, OnHide = NOOP, OnCanvasScaleChanged = NOOP,
    OnMapChanged = function(self) self:RefreshAllData() end,
    GetMap = function(self) return self.owningMap end,
}
_G.MapCanvasPinMixin = {
    OnLoad = NOOP, OnAcquired = NOOP, OnReleased = NOOP, OnClick = NOOP, OnMouseEnter = NOOP, OnMouseLeave = NOOP,
    OnMouseDown = NOOP, OnMouseUp = NOOP, ApplyCurrentScale = NOOP, ApplyFrameLevel = NOOP, OnCanvasScaleChanged = NOOP,
    SetPosition = function(self, x, y) self.normalizedX, self.normalizedY = x, y end,
    GetPosition = function(self) return self.normalizedX, self.normalizedY end,
    SetScalingLimits = function(self, f, s, e) self.scaleFactor, self.startScale, self.endScale = f, s, e end,
    UseFrameLevelType = function(self, t, i) self.pinFrameLevelType, self.pinFrameLevelIndex = t, i end,
    GetMap = function(self) return self.owningMap end,
}
STUB.pinTemplates = {}
WorldMapFrame.dataProviders, WorldMapFrame.pinPools = {}, {}
WorldMapFrame.AddDataProvider = function(self, p)
    self.dataProviders[p] = true
    p:OnAdded(self)
end
WorldMapFrame.RemoveDataProvider = function(self, p)
    p:RemoveAllData()
    self.dataProviders[p] = nil
    p:OnRemoved(self)
end
WorldMapFrame.AcquirePin = function(self, template, ...)
    local mixin = STUB.pinTemplates[template] and _G[STUB.pinTemplates[template]]
    assert(mixin, "unknown pin template " .. tostring(template))
    local pool = self.pinPools[template] or { active = {}, free = {} }
    self.pinPools[template] = pool
    local pin = table.remove(pool.free)
    local new = pin == nil
    if new then pin = Mixin(CreateFrame("Frame", nil, self), mixin) end
    pin.pinTemplate, pin.owningMap = template, self
    if new then pin:OnLoad() end
    pin:Show()
    pin:OnAcquired(...)
    if pin.CheckMouseButtonPassthrough then pin:CheckMouseButtonPassthrough("RightButton") end
    pool.active[#pool.active + 1] = pin
    return pin
end
WorldMapFrame.RemoveAllPinsByTemplate = function(self, template)
    local pool = self.pinPools[template]
    if not pool then return end
    for _, pin in ipairs(pool.active) do
        pin:Hide()
        pin:OnReleased()
        pin.pinTemplate, pin.owningMap = nil, nil
        pool.free[#pool.free + 1] = pin
    end
    pool.active = {}
end
WorldMapFrame.SetMapID = function(self, id)
    if self.mapID == id then return end
    self.mapID = id
    for p in pairs(self.dataProviders) do p:OnMapChanged() end
end
WorldMapFrame:SetScript("OnShow", function(self)
    for p in pairs(self.dataProviders) do p:RefreshAllData(true) end
    for p in pairs(self.dataProviders) do p:OnShow() end
end)
WorldMapFrame:SetScript("OnHide", function(self)
    for p in pairs(self.dataProviders) do p:OnHide() end
end)
function STUB.mapPins(template)
    local pool = WorldMapFrame.pinPools[template]
    return pool and pool.active or {}
end
