-- /amisia selbsttest: checks in the real client every point the specs leave to an in-game check
-- (names, lockdowns, addon messages, packing, guild ranks, weekly reset, waypoints, loot method,
-- atlases, templates, client functions, events, item constants, the character's stat values with a
-- machine-readable line, saved data) and writes a compact report into a read-only box to copy.
-- Read-only: it sends nothing to chat or other players, and only "/amisia selbsttest wegpunkt" sets
-- a map waypoint. Every check runs protected; a failing check reports its error text instead of
-- raising.
local ADDON, ns = ...
local L, N_ = ns.L, ns.N_

local ST = {}
ns.SelfTest = ST

local MAX_VALUE = 600     -- characters of one value in the report at most
local MAX_SHORT = 30      -- problem lines the short variant prints at most
local SV_BUDGET = 400000  -- table entries the saved-data estimate walks at most

---------------------------------------------------------------------------
-- What the client shows passively (nothing is ever sent for it): the raw sender of the last own
-- addon message echo and of a foreign one, the last whisper and the echo of an own whisper.
---------------------------------------------------------------------------
local seen = {}
local loginAt

local function isSecret(v)
    local fn = _G.issecretvalue
    if type(fn) ~= "function" then return false end
    local ok, s = pcall(fn, v)
    return ok and s and true or false
end

-- A raw name as it came, or a marker for a secret one.
local function rawName(v)
    if isSecret(v) then return { secret = true } end
    if type(v) ~= "string" then return { text = tostring(v) } end
    return { text = v }
end

local PREFIXES = { Amisia = true, AmisiaD = true }

ns.OnEvent("PLAYER_LOGIN", function() loginAt = GetTime() end)

ns.OnEvent("CHAT_MSG_ADDON", function(prefix, _, chan, sender)
    if isSecret(prefix) or not PREFIXES[prefix] then return end
    local entry = rawName(sender)
    entry.chan = not isSecret(chan) and tostring(chan) or "?"
    entry.at = GetTime()
    -- own: the name as it is, or without a "-Realm" ending
    local me = ns.UnitFullName and ns.UnitFullName("player")
    local text = entry.text
    local own = text and me and (ns.SameName(text, me) or (text:find("-", 1, true) and ns.SameName(text:match("^(.*)%-[^%-]*$"), me)))
    if own then seen.addonOwn = entry else seen.addonOther = entry end
end)

ns.OnEvent("CHAT_MSG_WHISPER", function(_, sender)
    local entry = rawName(sender)
    entry.at = GetTime()
    seen.whisper = entry
end)

ns.OnEvent("CHAT_MSG_WHISPER_INFORM", function(_, target)
    local entry = rawName(target)
    entry.at = GetTime()
    seen.inform = entry
end)

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local function cut(text)
    text = tostring(text or ""):gsub("[\r\n]+", " ")
    if #text > MAX_VALUE then text = text:sub(1, MAX_VALUE) .. "..." end
    return text
end

-- Any value as short text: strings quoted (spaces show), secret values marked, tables counted.
local function show(v)
    if isSecret(v) then return L["<geheim>"] end
    local t = type(v)
    if t == "nil" then return "nil" end
    if t == "string" then return '"' .. v .. '"' end
    if t == "number" then
        if v == math.floor(v) then return ("%d"):format(v) end
        return ("%.3f"):format(v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return L["Tabelle(%d)"]:format(n)
    end
    return t
end

-- Several values separated by commas.
local function showAll(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = show((select(i, ...))) end
    if #out == 0 then return L["(nichts)"] end
    return table.concat(out, ", ")
end

local function seenText(e, withChan)
    if not e then return L["noch keins gesehen"] end
    local name = e.secret and L["<geheim>"] or ('"' .. tostring(e.text) .. '"')
    local ago = math.floor((GetTime() - (e.at or 0)) + 0.5)
    return name .. (withChan and e.chan and (" (" .. e.chan .. ")") or "") .. L[" vor %d s"]:format(ago)
end

-- A value of the client by its path ("C_Map.GetBestMapForUnit"), or nil.
local function lookup(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local function fn(path)
    local f = lookup(path)
    return type(f) == "function" and f or nil
end

-- Calls the client function at path; raises when it is missing (the check then says FEHLT).
local function call(path, ...)
    local f = fn(path)
    if not f then error({ missing = path }) end
    return f(...)
end

---------------------------------------------------------------------------
-- The report
---------------------------------------------------------------------------
-- The marks of the report lines (OK, FEHLT, FEHLER, WERT) are the report's internal codes (the
-- counts use them); the lines show them in the client's language.
local FEHLT = "FEHLT" -- l10n-ok: the internal mark, shown through MARKS
local MARKS = { FEHLT = L["FEHLT"], FEHLER = L["FEHLER"], WERT = L["WERT"] }

local function newReport()
    return { lines = {}, problems = {}, counts = { OK = 0, FEHLT = 0, WERT = 0, FEHLER = 0 }, section = "" }
end

local function add(R, mark, label, value)
    R.counts[mark] = (R.counts[mark] or 0) + 1
    local line = ("%-6s %s: %s"):format(MARKS[mark] or mark, label, cut(value))
    R.lines[#R.lines + 1] = line
    if mark == FEHLT or mark == "FEHLER" then R.problems[#R.problems + 1] = "[" .. R.section .. "] " .. line end
end

local function section(R, title)
    R.section = title
    R.lines[#R.lines + 1] = ""
    R.lines[#R.lines + 1] = "== " .. title .. " =="
end

local function errorText(err)
    if type(err) == "table" and err.missing then return nil, err.missing end
    return cut(tostring(err))
end

-- One check: f() returns mark and value (mark nil: the check wrote its own lines). A missing client
-- function becomes FEHLT, any other error FEHLER with its text.
local function check(R, label, f)
    local ok, mark, value = pcall(f)
    if ok then
        if mark then add(R, mark, label, value) end
        return
    end
    local text, missing = errorText(mark)
    if missing then
        add(R, FEHLT, label, L["%s fehlt"]:format(missing))
    else
        add(R, "FEHLER", label, text)
    end
end

-- A whole section runs protected too, so an error between its checks stops only that section.
local function runSection(R, title, body, ...)
    section(R, title)
    local ok, err = pcall(body, R, ...)
    if not ok then add(R, "FEHLER", L["Abschnitt"], errorText(err) or tostring(err)) end
end

---------------------------------------------------------------------------
-- Client and place
---------------------------------------------------------------------------
local function currentMap()
    local f = fn("C_Map.GetBestMapForUnit")
    if not f then return nil end
    local ok, id = pcall(f, "player")
    if not ok or isSecret(id) then return nil end
    return tonumber(id)
end

local function sectionClient(R)
    check(R, "Amisia", function() return "WERT", tostring(ns.VERSION) end)
    check(R, "GetBuildInfo", function() return "WERT", showAll(call("GetBuildInfo")) end)
    check(R, L["Zeit"], function()
        return "WERT", ("%s, Server %s"):format(date("%Y-%m-%d %H:%M:%S"), show(call("GetServerTime")))
    end)
    check(R, L["Seit dem Login"], function()
        if not loginAt then return "WERT", L["unbekannt (nach /reload)"] end
        return "WERT", ("%d s"):format(math.floor(GetTime() - loginAt + 0.5))
    end)
    check(R, "C_Map.GetBestMapForUnit", function()
        local id = call("C_Map.GetBestMapForUnit", "player")
        local info = id and not isSecret(id) and fn("C_Map.GetMapInfo") and C_Map.GetMapInfo(id)
        local extra = type(info) == "table" and L[" %s, Typ %s, oben %s"]:format(show(info.name), show(info.mapType), show(info.parentMapID)) or ""
        return "WERT", show(id) .. extra
    end)
    check(R, "GetInstanceInfo", function()
        local name, kind, diff, diffName, _, _, _, id = call("GetInstanceInfo")
        return "WERT", showAll(name, kind, diff, diffName, id)
    end)
    check(R, "GetRealZoneText", function() return "WERT", show(call("GetRealZoneText")) end)
end

---------------------------------------------------------------------------
-- Lockdowns at the time of the test
---------------------------------------------------------------------------
local function sectionLock(R)
    check(R, "InCombatLockdown", function() return "WERT", show(call("InCombatLockdown")) end)
    check(R, "C_ChatInfo.InChatMessagingLockdown", function() return "WERT", show(call("C_ChatInfo.InChatMessagingLockdown")) end)
    local kinds = {}
    local enum = _G.Enum and Enum.AddOnRestrictionType
    if type(enum) == "table" then
        for name, v in pairs(enum) do if type(v) == "number" then kinds[#kinds + 1] = { v, name } end end
    end
    if #kinds == 0 then kinds = { { 1, "Encounter" }, { 5, "Chat" } } end
    table.sort(kinds, function(a, b) return a[1] < b[1] end)
    if not fn("C_RestrictedActions.IsAddOnRestrictionActive") then
        add(R, FEHLT, "C_RestrictedActions.IsAddOnRestrictionActive", L["fehlt"])
    else
        for _, k in ipairs(kinds) do
            check(R, ("IsAddOnRestrictionActive(%d %s)"):format(k[1], k[2]), function()
                return "WERT", show(C_RestrictedActions.IsAddOnRestrictionActive(k[1]))
            end)
        end
    end
    check(R, "C_InstanceEncounter.IsEncounterInProgress", function() return "WERT", show(call("C_InstanceEncounter.IsEncounterInProgress")) end)
    check(R, L["Amisia-Warteschlangen"], function()
        return "WERT", L["Chat %s, Addon %s, angehalten %s"]:format(show(ns.ChatQueueSize and ns.ChatQueueSize()),
            show(ns.CommQueueSize and ns.CommQueueSize()), show(ns.CommHeld and ns.CommHeld()))
    end)
end

---------------------------------------------------------------------------
-- Names: what the client hands out where
---------------------------------------------------------------------------
local function sectionNames(R)
    -- both values always: the question is what the second one holds (surname, realm or nil)
    check(R, "UnitName(\"player\")", function()
        local name, second = call("UnitName", "player")
        return "WERT", showAll(name, second)
    end)
    check(R, "UnitFullName(\"player\")", function()
        if not fn("UnitFullName") then return "WERT", L["fehlt"] end
        local name, second = UnitFullName("player")
        return "WERT", showAll(name, second)
    end)
    check(R, "GetNormalizedRealmName", function() return "WERT", show(call("GetNormalizedRealmName")) end)
    check(R, L["Amisia liest dich als"], function() return "WERT", show(ns.UnitFullName("player")) end)
    local n = 0
    check(R, "GetNumGroupMembers", function()
        n = tonumber(call("GetNumGroupMembers")) or 0
        return "WERT", show(n)
    end)
    local raid = fn("IsInRaid") and IsInRaid() or false
    for i = 1, math.min(n, 5) do
        check(R, ("GetRaidRosterInfo(%d)"):format(i), function()
            local name, rank, sub = call("GetRaidRosterInfo", i)
            local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
            return "WERT", L["%s, Rang %s, Gruppe %s; UnitName(%s) = %s"]:format(show(name), show(rank), show(sub), unit,
                showAll(UnitName(unit), (select(2, UnitName(unit)))))
        end)
    end
    if n == 0 then add(R, "WERT", L["Raidliste"], L["nicht in einer Gruppe, nicht prüfbar"]) end
    check(R, L["Ziel##Selbsttest"], function()
        local exists = fn("UnitExists") and UnitExists("target")
        if exists == nil then exists = UnitName("target") ~= nil end
        if not isSecret(exists) and not exists then return "WERT", L["kein Ziel"] end
        local cls = fn("UnitClassification") and UnitClassification("target")
        return "WERT", L["UnitName %s, Art %s, GUID %s"]:format(showAll(UnitName("target")), show(cls), show(UnitGUID("target")))
    end)
    check(R, L["CHAT_MSG_ADDON eigenes Echo"], function() return "WERT", seenText(seen.addonOwn, true) end)
    check(R, L["CHAT_MSG_ADDON fremder Absender"], function() return "WERT", seenText(seen.addonOther, true) end)
    check(R, L["CHAT_MSG_WHISPER Absender"], function() return "WERT", seenText(seen.whisper) end)
    check(R, L["CHAT_MSG_WHISPER_INFORM Ziel"], function() return "WERT", seenText(seen.inform) end)
    check(R, "GetGuildRosterInfo(1)", function()
        if not (fn("IsInGuild") and IsInGuild()) then return "WERT", L["keine Gilde"] end
        local name, rankName, rankIndex = call("GetGuildRosterInfo", 1)
        return "WERT", showAll(name, rankName, rankIndex)
    end)
end

---------------------------------------------------------------------------
-- Addon messages and packing
---------------------------------------------------------------------------
local ENCODING = { "SerializeCBOR", "DeserializeCBOR", "CompressString", "DecompressString", "EncodeBase64", "DecodeBase64" }

local function same(a, b, depth)
    depth = depth or 0
    if depth > 20 then return false end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then
        if type(a) == "number" then return math.abs(a - b) < 1e-9 end
        return a == b
    end
    for k, v in pairs(a) do if not same(v, b[k], depth + 1) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local SAMPLE = {
    name = "Vulo Sturmwind", text = "Grüße aus Sturmwind", n = 123456, f = 1.5, yes = true, -- l10n-ok: test data for the round trip, never shown
    list = { 1, 2, 3, 5, 8, 13 }, nested = { a = { b = { c = "tief" } }, filler = string.rep("Amisia ", 40) },
}

local function roundTrip(R)
    local api = _G.C_EncodingUtil
    local method = _G.Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    check(R, "Enum.CompressionMethod.Deflate", function()
        if method == nil then return FEHLT, L["fehlt (Rückfall 0)"] end
        return "OK", show(method)
    end)
    method = method or 0
    local raw, packed, text, back
    check(R, "SerializeCBOR", function()
        raw = api.SerializeCBOR(SAMPLE)
        if type(raw) ~= "string" then return FEHLT, L["kein Text: %s"]:format(show(raw)) end
        return "OK", L["%d Bytes"]:format(#raw)
    end)
    if not raw then return end
    check(R, "CompressString(Deflate)", function()
        packed = api.CompressString(raw, method)
        if type(packed) ~= "string" then return FEHLT, L["kein Text: %s"]:format(show(packed)) end
        return "OK", L["%d Bytes"]:format(#packed)
    end)
    if not packed then return end
    check(R, "EncodeBase64", function()
        text = api.EncodeBase64(packed)
        if type(text) ~= "string" then return FEHLT, L["kein Text: %s"]:format(show(text)) end
        return "OK", L["%d Zeichen, %d Teile zu 200"]:format(#text, math.ceil(#text / 200))
    end)
    if not text then return end
    check(R, L["Zurück (Base64, Deflate, CBOR)"], function()
        local p = api.DecodeBase64(text)
        local r = type(p) == "string" and api.DecompressString(p, method)
        back = type(r) == "string" and api.DeserializeCBOR(r)
        if type(back) ~= "table" then return FEHLT, L["kein Ergebnis"] end
        if not same(SAMPLE, back) then return FEHLT, L["Ergebnis anders als das Original"] end
        return "OK", L["gleich"]
    end)
end

local function sectionComm(R)
    check(R, L["Präfixe"], function()
        local list = ns.CommPrefixResults and ns.CommPrefixResults() or {}
        if #list == 0 then return FEHLT, L["keine Anmeldung (Funktion fehlt)"] end
        local parts, bad = {}, false
        for _, r in ipairs(list) do
            local good = r.ok and (r.result == 0 or r.result == 1 or r.result == true)
            if not good then bad = true end
            parts[#parts + 1] = ("%s = %s"):format(r.prefix, r.ok and show(r.result) or L["Fehler %s"]:format(cut(r.result)))
        end
        return bad and FEHLT or "OK", table.concat(parts, ", ") .. L[" (0 neu, 1 schon angemeldet)"]
    end)
    if fn("C_ChatInfo.IsAddonMessagePrefixRegistered") then
        for _, p in ipairs({ "Amisia", "AmisiaD" }) do
            check(R, ("IsAddonMessagePrefixRegistered(%s)"):format(p), function()
                local on = C_ChatInfo.IsAddonMessagePrefixRegistered(p)
                return on and "OK" or FEHLT, show(on)
            end)
        end
    else
        add(R, "WERT", "C_ChatInfo.IsAddonMessagePrefixRegistered", L["fehlt"])
    end
    check(R, L["Addon-Nachrichten"], function()
        return "WERT", L["verfügbar %s, Abgleich an %s"]:format(show(ns.CommAvailable and ns.CommAvailable()), show(ns.CommReady and ns.CommReady()))
    end)
    check(R, L["Zähler"], function()
        local stats = ns.CommStats and ns.CommStats() or {}
        local keys = {}
        for k in pairs(stats) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. show(stats[k]) end
        return "WERT", #parts > 0 and table.concat(parts, " ") or L["keine"]
    end)
    local api = _G.C_EncodingUtil
    if type(api) ~= "table" then
        add(R, FEHLT, "C_EncodingUtil", L["fehlt (kein Raid-Abgleich)"])
        return
    end
    local missing = {}
    for _, f in ipairs(ENCODING) do
        if type(api[f]) ~= "function" then missing[#missing + 1] = f end
    end
    if #missing > 0 then
        add(R, FEHLT, "C_EncodingUtil", L["%s fehlt"]:format(table.concat(missing, ", ")))
        return
    end
    add(R, "OK", "C_EncodingUtil", L["alle sechs Funktionen"])
    roundTrip(R)
    check(R, L["Abbild des neuesten Raids"], function()
        local s = ns.Active and ns.Active()
        if not s then
            local list = ns.Sessions and ns.Sessions() or {}
            s = list[#list]
        end
        if not s then return "WERT", L["noch kein Raid aufgezeichnet"] end
        local sp, so = ns.SyncBuild(s)
        local pp, err = ns.CommPack(sp)
        local po = pp and ns.CommPack(so)
        if not pp or not po then return FEHLT, L["Packen fehlgeschlagen"] .. (err and (" (" .. err .. ")") or "") end
        local back = ns.CommUnpack(pp)
        return "OK", L["öffentlich %d Zeichen in %d Teilen, Offiziere %d Zeichen in %d Teilen, zurück %s"]:format(
            #pp, #ns.CommChunks(pp), #po, #ns.CommChunks(po), type(back) == "table" and L["lesbar"] or L["NICHT lesbar"])
    end)
end

---------------------------------------------------------------------------
-- Guild: roster readiness, rank flags, officer rights
---------------------------------------------------------------------------
local OFFICER_FLAG = 22

local function sectionGuild(R)
    local inGuild = false
    check(R, "IsInGuild", function()
        inGuild = call("IsInGuild") and true or false
        return "WERT", show(inGuild)
    end)
    if not inGuild then
        add(R, "WERT", L["Gilde"], L["nicht in einer Gilde, Gildenprüfungen entfallen"])
        return
    end
    check(R, "GetGuildInfo", function() return "WERT", showAll(call("GetGuildInfo", "player")) end)
    check(R, L["C_Club Gildenliste"], function()
        local id = call("C_Club.GetGuildClubId")
        if id == nil then return "WERT", L["keine Club-ID (noch nicht bereit?)"] end
        if isSecret(id) then return "WERT", L["Club-ID geheim"] end
        local members = call("C_Club.GetClubMembers", id)
        local count = type(members) == "table" and #members or 0
        local me
        if type(members) == "table" and fn("C_Club.GetMemberInfo") then
            for _, m in ipairs(members) do
                local info = C_Club.GetMemberInfo(id, m)
                if type(info) == "table" and not isSecret(info.isSelf) and info.isSelf then me = info break end
            end
        end
        local mine = me and L["; du: %s, Rang %s"]:format(show(me.name), show(me.guildRankOrder)) or L["; dich nicht gefunden"]
        return count > 0 and "OK" or "WERT", L["Club %s, %d Mitglieder%s"]:format(show(id), count, mine)
    end)
    check(R, "GetNumGuildMembers", function() return "WERT", showAll(call("GetNumGuildMembers")) end)
    local ranks = 0
    check(R, "GuildControlGetNumRanks", function()
        ranks = tonumber(call("GuildControlGetNumRanks")) or 0
        return "WERT", show(ranks)
    end)
    if not fn("C_GuildInfo.GuildControlGetRankFlags") then
        add(R, FEHLT, "C_GuildInfo.GuildControlGetRankFlags", L["fehlt (Rückfall über Rangzahl)"])
    else
        for r = 1, math.min(ranks, 10) do
            check(R, L["Rang %d"]:format(r), function()
                local name = fn("GuildControlGetRankName") and GuildControlGetRankName(r)
                local flags = C_GuildInfo.GuildControlGetRankFlags(r)
                if type(flags) ~= "table" then return "WERT", L["%s: keine Tabelle (%s)"]:format(show(name), show(flags)) end
                return "WERT", L["%s: %d Rechte, [%d] Offiziersrang = %s"]:format(show(name), #flags, OFFICER_FLAG, show(flags[OFFICER_FLAG]))
            end)
        end
    end
    check(R, "C_GuildInfo.IsGuildOfficer", function() return "WERT", show(call("C_GuildInfo.IsGuildOfficer")) end)
    check(R, "C_GuildInfo.CanEditOfficerNote", function() return "WERT", show(call("C_GuildInfo.CanEditOfficerNote")) end)
    check(R, L["Amisia hält dich für"], function()
        local verified = ns.IsVerifiedOfficer and ns.IsVerifiedOfficer(ns.UnitFullName("player"))
        return "WERT", L["Offiziersansicht %s, geprüfter Offizier %s"]:format(show(ns.IsOfficerView and ns.IsOfficerView()), show(verified))
    end)
end

---------------------------------------------------------------------------
-- Weekly reset, map and waypoint
---------------------------------------------------------------------------
local function sectionMap(R, opts)
    check(R, "C_DateAndTime.GetSecondsUntilWeeklyReset", function()
        local s = call("C_DateAndTime.GetSecondsUntilWeeklyReset")
        if type(s) ~= "number" or isSecret(s) then return "WERT", show(s) end
        return "WERT", L["%d s, also %s"]:format(s, date("%Y-%m-%d %H:%M", time() + s))
    end)
    local map = currentMap()
    check(R, "C_Map.CanSetUserWaypointOnMap", function()
        if not map then return "WERT", L["keine Karte"] end
        return "WERT", L["Karte %d: %s"]:format(map, show(call("C_Map.CanSetUserWaypointOnMap", map)))
    end)
    local pos
    check(R, "C_Map.GetPlayerMapPosition", function()
        if not map then return "WERT", L["keine Karte"] end
        pos = call("C_Map.GetPlayerMapPosition", map, "player")
        if type(pos) ~= "table" then return "WERT", show(pos) end
        local x, y = pos.x, pos.y
        if pos.GetXY then x, y = pos:GetXY() end
        pos = { x = x, y = y }
        return "WERT", showAll(x, y)
    end)
    check(R, "C_Map.HasUserWaypoint", function() return "WERT", show(call("C_Map.HasUserWaypoint")) end)
    check(R, "C_SuperTrack.IsSuperTrackingUserWaypoint", function() return "WERT", show(call("C_SuperTrack.IsSuperTrackingUserWaypoint")) end)
    check(R, "GetPlayerFacing", function() return "WERT", show(call("GetPlayerFacing")) end)
    if not opts.waypoint then
        add(R, "WERT", L["Wegpunkt setzen"], L["nicht versucht (/amisia selbsttest wegpunkt)"])
        return
    end
    check(R, L["Wegpunkt setzen"], function()
        if not map or not pos or type(pos.x) ~= "number" or isSecret(pos.x) then return FEHLT, L["keine Position auf der Karte"] end
        local point = call("UiMapPoint.CreateFromCoordinates", map, pos.x, pos.y)
        local ok = call("C_Map.SetUserWaypoint", point)
        if fn("C_SuperTrack.SetSuperTrackedUserWaypoint") then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        local has = fn("C_Map.HasUserWaypoint") and C_Map.HasUserWaypoint()
        local tracked = fn("C_SuperTrack.IsSuperTrackingUserWaypoint") and C_SuperTrack.IsSuperTrackingUserWaypoint()
        return has and "OK" or FEHLT, L["Ergebnis %s, gesetzt %s, Wegweiser %s"]:format(show(ok), show(has), show(tracked))
    end)
end

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------
local function lootMethodName(v)
    local enum = _G.Enum and Enum.LootMethod
    if type(enum) == "table" then
        for name, n in pairs(enum) do if n == v then return name end end
    end
    return nil
end

local function sectionLoot(R)
    check(R, L["Gruppe"], function()
        return "WERT", ("IsInGroup %s, IsInRaid %s"):format(show(fn("IsInGroup") and IsInGroup()), show(fn("IsInRaid") and IsInRaid()))
    end)
    check(R, "C_PartyInfo.GetLootMethod", function()
        local method, partyID, raidID = call("C_PartyInfo.GetLootMethod")
        local name = not isSecret(method) and lootMethodName(method)
        return "WERT", L["%s%s, Plündermeister Gruppe %s, Raid %s"]:format(show(method), name and (" " .. name) or "", show(partyID), show(raidID))
    end)
    check(R, "C_PartyInfo.GetAvailableLootMethods", function()
        if not fn("C_PartyInfo.GetAvailableLootMethods") then return "WERT", L["fehlt"] end
        if not (fn("IsInGroup") and IsInGroup()) then return "WERT", L["vorhanden, nur in einer Gruppe aussagekräftig"] end
        local r = { C_PartyInfo.GetAvailableLootMethods() }
        local list = {}
        local function addOne(v)
            local name = not isSecret(v) and lootMethodName(v)
            list[#list + 1] = show(v) .. (name and (" " .. name) or "")
        end
        if #r == 1 and type(r[1]) == "table" then
            for _, v in pairs(r[1]) do addOne(type(v) == "table" and (v.method or v.lootMethod) or v) end
        else
            for _, v in ipairs(r) do addOne(v) end
        end
        return "WERT", #list > 0 and table.concat(list, ", ") or L["(nichts)"]
    end)
    check(R, L["Lootfenster"], function()
        local n = fn("GetNumLootItems") and tonumber(GetNumLootItems()) or 0
        if n == 0 then return "WERT", L["keins offen (GetLootSourceInfo nicht prüfbar)"] end
        return "WERT", L["%d Plätze, GetLootSourceInfo(1) = %s"]:format(n, showAll(call("GetLootSourceInfo", 1)))
    end)
end

---------------------------------------------------------------------------
-- Atlases, templates, client functions, events
---------------------------------------------------------------------------
local ATLASES = {
    "Profession-Background-Overview", "Professions-background-summarylist", "Professions_Recipe_Active",
    "Professions_Recipe_Hover", "Professions-skillbar-bg", "Professions-skillbar-frame", "common-insideframe",
    "common-dropdown-bg", "common-search-border-left", "common-search-border-middle", "common-search-border-right",
    -- the quest giver marks on the world map
    "QuestNormal",
}
for _, base in ipairs({ "common-dropdown-a-button", "common-dropdown-b-button" }) do
    ATLASES[#ATLASES + 1] = base
    for _, state in ipairs({ "hover", "pressed", "pressedhover", "open", "disabled" }) do
        ATLASES[#ATLASES + 1] = base .. "-" .. state
    end
end
for _, name in ipairs({ "common-dropdown-a-button-shadowless", "common-dropdown-a-button-hover-shadowless",
                        "common-dropdown-a-button-pressed-shadowless", "common-dropdown-a-button-pressedhover-shadowless",
                        "common-dropdown-a-button-open-shadowless", "common-dropdown-a-button-disabled-shadowless" }) do
    ATLASES[#ATLASES + 1] = name
end
-- the talent page (Pages/Talents.lua): the node frames and arrow heads of the client's talent
-- window and its class backgrounds
for _, name in ipairs({ "talents-node-square-yellow", "talents-node-square-green", "talents-node-square-gray",
                        "talents-arrow-head-yellow", "talents-arrow-head-gray", "talent-background-mage" }) do
    ATLASES[#ATLASES + 1] = name
end
ST.ATLASES = ATLASES

local function sectionAtlases(R)
    if not fn("C_Texture.GetAtlasInfo") then
        add(R, FEHLT, "C_Texture.GetAtlasInfo", L["fehlt (alle Atlanten im Rückfall)"])
        return
    end
    local okCount = 0
    for _, a in ipairs(ATLASES) do
        local ok, info = pcall(C_Texture.GetAtlasInfo, a)
        if not ok then
            add(R, "FEHLER", "Atlas " .. a, cut(info))
        elseif type(info) == "table" then
            okCount = okCount + 1
        else
            add(R, FEHLT, "Atlas " .. a, L["nicht im Client"])
        end
    end
    add(R, okCount == #ATLASES and "OK" or "WERT", L["Atlanten"], L["%d von %d vorhanden"]:format(okCount, #ATLASES))
    -- the sizes the layout scales from (dropdown arrow, head bar)
    local sizes = {}
    for _, name in ipairs({ "common-dropdown-a-button", "Professions-skillbar-bg", "Professions-skillbar-frame" }) do
        local info = C_Texture.GetAtlasInfo(name)
        sizes[#sizes + 1] = ("%s %sx%s"):format(name, info and tostring(info.width) or "?", info and tostring(info.height) or "?")
    end
    add(R, "WERT", L["Atlasgrößen"], table.concat(sizes, ", "))
end

-- The dungeon images (DungeonArt.lua): every file id of the client's loading screens, drawn once on
-- a hidden texture; SetTexture answers whether the client has the file. And the boss model's frame.
local artTexture, artModel
local function sectionArt(R)
    local A = ns.DUNGEON_ART
    if type(A) ~= "table" or type(A.D) ~= "table" then
        add(R, FEHLT, L["Dungeonbilder"], L["keine Bilddaten"])
        return
    end
    local ids, have = {}, {}
    local function take(a)
        if type(a) == "table" and type(a[1]) == "number" and not have[a[1]] then
            have[a[1]] = true
            ids[#ids + 1] = a[1]
        end
    end
    for _, a in pairs(A.D) do take(a) end
    take(A.party)
    take(A.raid)
    table.sort(ids)
    if not artTexture then
        local f = CreateFrame("Frame", nil, UIParent)
        f:Hide()
        artTexture = f:CreateTexture()
    end
    local found, missing, silent = 0, {}, 0
    for _, id in ipairs(ids) do
        local good, res = pcall(artTexture.SetTexture, artTexture, id)
        if not good or res == false then
            missing[#missing + 1] = tostring(id)
        elseif res == true then
            found = found + 1
        else
            silent = silent + 1
        end
    end
    if #missing > 0 then
        add(R, FEHLT, L["Dungeonbilder"], L["%d von %d fehlen: %s"]:format(#missing, #ids, table.concat(missing, ", ")))
    elseif silent > 0 then
        add(R, "WERT", L["Dungeonbilder"], L["%d Dateien, SetTexture ohne Antwort"]:format(#ids))
    else
        add(R, "OK", L["Dungeonbilder"], L["%d von %d vorhanden"]:format(found, #ids))
    end
    check(R, L["Bossmodell"], function()
        -- made once per session, as the template frames
        if not artModel then
            local good, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
            artModel = good and m or false
        end
        local good, m = artModel ~= false, artModel
        if not good or not m then return "WERT", L["kein PlayerModel (kein Bossmodell)"] end
        m:Hide()
        if type(m.SetCreature) == "function" then return "OK", L["SetCreature vorhanden"] end
        return "WERT", L["SetCreature fehlt (kein Bossmodell)"]
    end)
end

-- kind, template, the parts Amisia needs from it (as the widgets probe them)
local TEMPLATES = {
    { "Frame", "PortraitFrameTemplate", { "TitleContainer", "CloseButton", "SetTitle", "SetPortraitToAsset" } },
    { "Button", "UIPanelCloseButton", {} },
    { "Button", "SharedButtonSmallTemplate", { "Left", "Right", "Center" } },
    { "Button", "UIPanelButtonTemplate", {} },
    { "CheckButton", "MinimalCheckboxTemplate", { "SetChecked", "GetChecked" } },
    { "EditBox", "InputBoxTemplate", { "Left" } },
    { "EditBox", "SearchBoxTemplate", { "Left", "Instructions", "clearButton" } },
    { "Button", "ListHeaderVisualTemplate, ListHeaderCodeTemplate", { "ButtonText", "SetClickHandler", "SetHeaderText" } },
    { "EventFrame", "MinimalScrollBar", { "SetScrollPercentage", "RegisterCallback" } },
    { "Frame", "LargeSideTabButtonTemplate", { "SetCustomOnMouseUpHandler", "Icon", "SetChecked" } },
    { "Button", "TooltipBackdropTemplate", { "NineSlice" } },
}
ST.TEMPLATES = TEMPLATES

-- Test frames are made once per session and kept hidden under one hidden holder (a frame cannot be
-- destroyed); a second run reuses the answers.
local holder
local templateAnswers = {}

local function tryTemplate(t)
    local key = t[2]
    if templateAnswers[key] then return templateAnswers[key] end
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
    end
    local ok, f = pcall(CreateFrame, t[1], nil, holder, t[2])
    local answer
    if not ok then
        answer = { FEHLT, cut(f) }
    elseif not f then
        answer = { FEHLT, L["kein Rahmen"] }
    else
        if f.Hide then pcall(f.Hide, f) end
        local lacking = {}
        for _, part in ipairs(t[3]) do
            if f[part] == nil then lacking[#lacking + 1] = part end
        end
        if #lacking > 0 then
            answer = { FEHLT, L["Teile fehlen: %s"]:format(table.concat(lacking, ", ")) }
        else
            answer = { "OK", #t[3] > 0 and L["mit %s"]:format(table.concat(t[3], ", ")) or L["vorhanden"] }
        end
    end
    templateAnswers[key] = answer
    return answer
end

local function sectionTemplates(R)
    for _, t in ipairs(TEMPLATES) do
        check(R, t[2], function()
            local a = tryTemplate(t)
            return a[1], a[2]
        end)
    end
    check(R, "AmisiaMapPinTemplate", function()
        return type(_G.AmisiaMapPinMixin) == "table" and "OK" or FEHLT,
            type(_G.AmisiaMapPinMixin) == "table" and L["Mixin geladen (Vorlage aus MapPin.xml)"] or L["Mixin fehlt"]
    end)
end

-- Client functions Amisia calls; a missing one is a problem.
local REQUIRED = {
    "CreateFrame", "GetBuildInfo", "GetTime", "GetServerTime", "UnitName", "UnitGUID", "UnitClass", "UnitLevel",
    "UnitFactionGroup", "UnitIsUnit", "UnitIsDead", "UnitClassification", "UnitIsGroupLeader", "UnitIsGroupAssistant", "UnitPosition",
    "GetNormalizedRealmName", "GetNumGroupMembers", "GetRaidRosterInfo", "IsInGroup", "IsInRaid", "IsInInstance", "GetInstanceInfo",
    "GetRealZoneText", "GetZoneText", "InCombatLockdown", "IsAltKeyDown", "IsShiftKeyDown", "IsControlKeyDown",
    "GetCursorPosition", "IsInGuild", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo", "GuildControlGetNumRanks",
    "GuildControlGetRankName", "GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemInfo", "GetGuildBankItemLink",
    "GetCurrentGuildBankTab", "QueryGuildBankTab", "QueryGuildBankLog", "GetNumGuildBankTransactions", "GetGuildBankTransaction",
    "GetNumGuildBankMoneyTransactions", "GetGuildBankMoneyTransaction", "GetNumLootItems", "GetLootSlotInfo", "GetLootSlotLink", "GetLootSourceInfo",
    "GetMasterLootCandidate", "GiveMasterLoot", "GetLootRollItemLink", "HandleModifiedItemClick", "GetInventoryItemLink",
    "GetMerchantNumItems", "GetMerchantItemLink", "GetQuestID", "GetNumQuestRewards", "GetNumQuestChoices", "GetQuestItemLink",
    "GetQuestLogItemLink", "QuestInfo_Display", "GetTitleText", "C_MerchantFrame.GetItemInfo",
    "GetPlayerFacing", "OpenWorldMap", "ToggleWorldMap", "StaticPopup_Show", "hooksecurefunc", "CreateVector2D", "CreateFromMixins",
    "Mixin", "issecretvalue",
    "C_ChatInfo.SendChatMessage", "C_ChatInfo.SendAddonMessage", "C_ChatInfo.RegisterAddonMessagePrefix",
    "C_ChatInfo.InChatMessagingLockdown", "C_RestrictedActions.IsAddOnRestrictionActive", "C_InstanceEncounter.IsEncounterInProgress",
    "C_PvP.IsActiveBattlefield", "C_Club.GetGuildClubId", "C_Club.GetClubMembers", "C_Club.GetMemberInfo",
    "C_GuildInfo.GuildControlGetRankFlags", "C_GuildInfo.IsGuildOfficer", "C_GuildInfo.CanEditOfficerNote", "C_GuildInfo.GuildRoster",
    "C_FriendList.GetNumFriends", "C_FriendList.GetFriendInfoByIndex", "C_PartyInfo.GetLootMethod",
    "C_DateAndTime.GetSecondsUntilWeeklyReset", "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemStats",
    "C_Item.GetItemCount", "C_Item.GetItemIconByID", "C_Item.RequestLoadItemDataByID", "C_Item.IsItemDataCachedByID",
    "C_Item.DoesItemExistByID", "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemID",
    "C_Container.GetContainerItemLink", "C_Bank.FetchPurchasedBankTabIDs", "C_TooltipInfo.GetItemByID",
    "TooltipDataProcessor.AddTooltipPostCall", "C_QuestLog.IsQuestFlaggedCompleted", "C_QuestLog.GetTitleForQuestID",
    "C_SpecializationInfo.GetSpecializationInfo", "C_SkillInfo.GetNumSkillLines", "C_SkillInfo.GetSkillLineInfo",
    "C_ClassColor.GetClassColor", "C_AuctionHouse.GetBrowseResults", "C_Texture.GetAtlasInfo", "C_Timer.After", "C_Timer.NewTicker",
    "C_Map.GetBestMapForUnit", "C_Map.GetMapInfo", "C_Map.GetAreaInfo", "C_Map.GetPlayerMapPosition", "C_Map.GetMapRectOnMap",
    "C_Map.GetWorldPosFromMapPos", "C_Map.CanSetUserWaypointOnMap", "C_Map.SetUserWaypoint", "C_Map.ClearUserWaypoint",
    "C_Map.GetUserWaypoint", "C_Map.GetUserWaypointHyperlink", "C_Map.GetUserWaypointPositionForMap",
    "C_SuperTrack.SetSuperTrackedUserWaypoint", "UiMapPoint.CreateFromCoordinates", "ScrollUtil.InitScrollFrameWithScrollBar",
    "ChatFrameUtil.InsertLink",
}
ST.REQUIRED = REQUIRED

-- Functions only some clients have; Amisia copes without them, the report says which exist.
local OPTIONAL = {
    "ChatEdit_InsertLink", "UnitFullName", "GetItemStats", "GetItemInfo", "GetTalentTabInfo", "GetSkillLineInfo", "GetNumSkillLines",
    "GetCritChanceFromAgility", "GetSpellCritChanceFromIntellect", "GetAttackPowerForStat", "GetCombatRatingBonus",
    "C_PartyInfo.GetAvailableLootMethods", "C_ChatInfo.IsAddonMessagePrefixRegistered",
    "C_EventUtils.IsEventValid", "C_Map.HasUserWaypoint", "C_SuperTrack.IsSuperTrackingUserWaypoint", "C_QuestLog.IsOnQuest",
    -- the source collector: the quest level from either generation of the quest log, the reputation
    -- line of a merchant's item
    "C_QuestLog.GetLogIndexForQuestID", "C_QuestLog.GetInfo", "GetQuestLogIndexByID", "GetQuestLogTitle",
    "C_TooltipInfo.GetMerchantItem",
    -- the merchant's prices before Forever 1.60.1.70245 (C_MerchantFrame.GetItemInfo since)
    "GetMerchantItemInfo",
    -- the quest tracker: all done quests in one call (else one call per quest), the race for race
    -- quests
    "C_QuestLog.GetAllCompletedQuestIDs", "UnitRace",
    -- the talent calculator: the live talents and the client's own texts
    "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetNodeInfo", "C_Traits.GetTreeCurrencyInfo",
    "C_Traits.GetTraitDescription", "C_Traits.GetGroupDisplayInfoByTreeID", "C_Spell.GetSpellName", "C_Spell.GetSpellTexture",
    -- the dungeon view: the dressing room on Ctrl-click, the quest XP
    "DressUpLink", "IsModifiedClick", "GetRewardXP", "GetQuestLogRewardXP",
    -- the professions page: a spell's description once the client has loaded it
    "C_Spell.RequestLoadSpellData", "C_Spell.IsSpellDataCached",
    -- the guild crafters: a whisper with a prefilled question (else the chat line opened by hand)
    "ChatFrameUtil.SendTellWithMessage", "ChatFrame_OpenChat",
}
ST.OPTIONAL = OPTIONAL

-- Objects of the client Amisia builds on.
local OBJECTS = {
    "UIParent", "GameTooltip", "ItemRefTooltip", "DEFAULT_CHAT_FRAME", "Minimap", "WorldMapFrame", "UISpecialFrames",
    "StaticPopupDialogs", "RAID_CLASS_COLORS", "MapCanvasDataProviderMixin", "MapCanvasPinMixin", "ChatFontNormal",
    "LOCALIZED_CLASS_NAMES_MALE", "GroupLootFrame1", "QuestInfoFrame", "QuestInfoRewardsFrame",
}
ST.OBJECTS = OBJECTS

-- One line for a list: OK with the count when all are there, else FEHLT naming the missing ones.
local function listLine(R, label, total, missing, what)
    if #missing == 0 then
        add(R, "OK", label, L["alle %d %s"]:format(total, what))
    else
        add(R, FEHLT, label, L["%d von %d fehlen: %s"]:format(#missing, total, table.concat(missing, ", ")))
    end
end

local function sectionFunctions(R)
    local missing = {}
    for _, path in ipairs(REQUIRED) do
        if not fn(path) then missing[#missing + 1] = path end
    end
    listLine(R, L["Funktionen"], #REQUIRED, missing, L["vorhanden"])
    local have, lack = {}, {}
    for _, path in ipairs(OPTIONAL) do
        if fn(path) then have[#have + 1] = path else lack[#lack + 1] = path end
    end
    add(R, "WERT", L["Wahlweise vorhanden"], #have > 0 and table.concat(have, ", ") or L["keine"])
    add(R, "WERT", L["Wahlweise fehlend"], #lack > 0 and table.concat(lack, ", ") or L["keine"])
    check(R, L["Chat-Link-Alias"], function()
        return "WERT", ("ChatEdit_InsertLink %s, ChatFrameUtil.InsertLink %s"):format(fn("ChatEdit_InsertLink") and L["da"] or L["fehlt"],
            fn("ChatFrameUtil.InsertLink") and L["da"] or L["fehlt"])
    end)
    check(R, "WorldMapFrame:AddDataProvider", function()
        local w = _G.WorldMapFrame
        return (type(w) == "table" and type(w.AddDataProvider) == "function") and "OK" or FEHLT,
            (type(w) == "table" and type(w.AddDataProvider) == "function") and L["vorhanden"] or L["fehlt (keine Pins auf der Karte)"]
    end)
    check(R, "MapCanvasPinMixin.UseFrameLevelType", function()
        local m = _G.MapCanvasPinMixin
        return "WERT", (type(m) == "table" and type(m.UseFrameLevelType) == "function") and L["vorhanden"] or L["fehlt"]
    end)
    local lackObjects = {}
    for _, name in ipairs(OBJECTS) do
        if _G[name] == nil then lackObjects[#lackObjects + 1] = name end
    end
    listLine(R, L["Objekte"], #OBJECTS, lackObjects, L["vorhanden"])
end

local EVENTS = {
    "ACTIVE_TALENT_GROUP_CHANGED", "ADDON_LOADED", "ADDON_RESTRICTION_STATE_CHANGED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "BAG_UPDATE_DELAYED", "BANKFRAME_CLOSED", "BANKFRAME_OPENED",
    "BOSS_KILL", "CHARACTER_POINTS_CHANGED", "CHAT_MSG_ADDON", "CHAT_MSG_LOOT", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_SYSTEM", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ENCOUNTER_END", "ENCOUNTER_START", "GET_ITEM_INFO_RECEIVED", "GROUP_ROSTER_UPDATE",
    "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE_TABS", "GUILDBANKLOG_UPDATE", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED",
    "ITEM_DATA_LOAD_RESULT", "ITEM_SEARCH_RESULTS_UPDATED", "LOOT_CLOSED",
    "LOOT_OPENED", "LOOT_SLOT_CLEARED", "MERCHANT_SHOW", "PLAYERBANKSLOTS_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_LOGIN", "PLAYER_TALENT_UPDATE", "PLAYER_TARGET_CHANGED",
    "QUEST_ACCEPTED", "QUEST_COMPLETE", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_REMOVED", "QUEST_TURNED_IN", "SKILL_LINES_CHANGED", "START_LOOT_ROLL", "TRAIT_CONFIG_UPDATED", "USER_WAYPOINT_UPDATED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_RECIPE_LEARNED",
    "SPELL_DATA_LOAD_RESULT", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "GUILD_ROSTER_UPDATE",
}
ST.EVENTS = EVENTS

local function sectionEvents(R)
    local valid = fn("C_EventUtils.IsEventValid")
    if not valid then
        add(R, "WERT", L["Ereignisse"], L["nicht prüfbar (C_EventUtils.IsEventValid fehlt)"])
        return
    end
    local missing = {}
    for _, e in ipairs(EVENTS) do
        local ok, on = pcall(valid, e)
        if not ok then
            add(R, "FEHLER", e, cut(on))
        elseif not on then
            missing[#missing + 1] = e
        end
    end
    listLine(R, L["Ereignisse"], #EVENTS, missing, L["bekannt"])
end

---------------------------------------------------------------------------
-- Item constants and the stat keys the scoring reads
---------------------------------------------------------------------------
local LOOT_STRINGS = { "LOOT_ITEM", "LOOT_ITEM_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED",
                       "LOOT_ITEM_PUSHED_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }

local function sectionItems(R)
    check(R, "Enum.ItemClass", function()
        local c = _G.Enum and Enum.ItemClass
        if type(c) ~= "table" then return FEHLT, L["fehlt (Rückfall Handwerkswaren 7, Reagenzien 5)"] end
        local bad = c.Tradegoods == nil or c.Reagent == nil
        return bad and FEHLT or "OK", ("Tradegoods %s, Reagent %s, Recipe %s"):format(show(c.Tradegoods), show(c.Reagent), show(c.Recipe))
    end)
    for _, key in ipairs({ "ITEM_MIN_SKILL", "ITEM_REQ_SKILL", "ITEM_CLASSES_ALLOWED", "RESISTANCE0_NAME" }) do
        check(R, key, function()
            local v = _G[key]
            if v == nil then return "WERT", L["fehlt"] end
            return "WERT", show(v)
        end)
    end
    local lootMissing = {}
    for _, key in ipairs(LOOT_STRINGS) do
        if type(_G[key]) ~= "string" then lootMissing[#lootMissing + 1] = key end
    end
    if #lootMissing > 0 then
        add(R, FEHLT, L["Loot-Texte"], L["%s fehlt"]:format(table.concat(lootMissing, ", ")))
    else
        add(R, "OK", L["Loot-Texte"], L["alle %d (LOOT_ITEM ...)"]:format(#LOOT_STRINGS))
    end
    local stat = ns.Gear and ns.Gear.STAT
    check(R, L["ITEM_MOD-Texte"], function()
        if type(stat) ~= "table" then return "WERT", L["keine Wertungstabelle"] end
        local total, missing = 0, {}
        for key in pairs(stat) do
            if key:find("^ITEM_MOD_.*_SHORT$") or key:find("^EMPTY_SOCKET_") then
                total = total + 1
                if type(_G[key]) ~= "string" then missing[#missing + 1] = key end
            end
        end
        table.sort(missing)
        if #missing == 0 then return "OK", L["alle %d vorhanden"]:format(total) end
        return "WERT", L["%d von %d fehlen: %s"]:format(#missing, total, table.concat(missing, ", "))
    end)
    check(R, L["C_Item.GetItemStats (getragenes Item)"], function()
        local link
        for slot = 1, 18 do
            local l = fn("GetInventoryItemLink") and GetInventoryItemLink("player", slot)
            if type(l) == "string" and not isSecret(l) then link = l break end
        end
        if not link then return "WERT", L["nichts angelegt"] end
        local raw = call("C_Item.GetItemStats", link)
        if type(raw) ~= "table" then return "WERT", ("%s: %s"):format(link, show(raw)) end
        local keys, unknown = {}, {}
        for k in pairs(raw) do
            keys[#keys + 1] = tostring(k)
            if type(stat) == "table" and not stat[k] then unknown[#unknown + 1] = tostring(k) end
        end
        table.sort(keys)
        table.sort(unknown)
        return "WERT", ("%s: %s%s"):format(link, table.concat(keys, " "), #unknown > 0 and L["; unbekannt: %s"]:format(table.concat(unknown, " ")) or "")
    end)
end

---------------------------------------------------------------------------
-- Values: the character's stats and what the client derives from them. WoW Forever has no gt
-- tables for the conversions (agility to crit, rating to percent ...), so they are measured: one WERT
-- line per value and one machine-readable line for tools/bis_measured.json,
--   AMISIA-WERTE 1 <class> <level> race=<race> str=base,effective,pos,neg ... crm=rating,percent ...
-- A missing function is a WERT line "nicht vorhanden" (no FEHLT: some clients lack some of them),
-- a function that raises one "Fehler: ..."; neither goes into the machine line.
---------------------------------------------------------------------------
local VALUES_FORMAT = 1
local STATS = { { 1, "str", N_("Stärke") }, { 2, "agi", N_("Beweglichkeit") }, { 3, "sta", N_("Ausdauer") }, { 4, "int", N_("Intelligenz") },
                { 5, "spi", N_("Willenskraft") } }
-- the rating constants, where the client defines them, with their key in the machine line
local RATINGS = {
    { "CR_HIT_MELEE", "hm" }, { "CR_HIT_RANGED", "hr" }, { "CR_HIT_SPELL", "hs" },
    { "CR_CRIT_MELEE", "cm" }, { "CR_CRIT_RANGED", "cr" }, { "CR_CRIT_SPELL", "cs" },
    { "CR_HASTE_MELEE", "am" }, { "CR_HASTE_RANGED", "ar" }, { "CR_HASTE_SPELL", "as" },  -- l10n-ok: keys of the machine line
    { "CR_DEFENSE_SKILL", "def" }, { "CR_DODGE", "dr" }, { "CR_PARRY", "pr" }, { "CR_BLOCK", "br" }, { "CR_EXPERTISE", "exp" },
}
ST.RATINGS = RATINGS

-- A number for the machine line: integers plain, else up to four decimals; nil for anything else.
local function num(v)
    if isSecret(v) or type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    if v == math.floor(v) and math.abs(v) < 1e15 then return ("%d"):format(v) end
    local t = ("%.4f"):format(v):gsub("0+$", ""):gsub("%.$", "")
    return t
end

-- Numbers joined by commas, nil unless every one is a number.
local function nums(list, n)
    local out = {}
    for i = 1, n do
        local t = num(list[i])
        if not t then return nil end
        out[i] = t
    end
    return table.concat(out, ",")
end

local function sectionValues(R)
    local pairsOut = {}
    -- one value: the client function at path called with args; label for the WERT line, key for the
    -- machine line (nil: none), n how many results count
    local function value(label, key, n, path, ...)
        local f = fn(path)
        if not f then
            add(R, "WERT", label, L["nicht vorhanden"])
            return nil
        end
        local res = { pcall(f, ...) }
        if not res[1] then
            add(R, "WERT", label, L["Fehler: %s"]:format(cut(res[2])))
            return nil
        end
        table.remove(res, 1)
        local shown = {}
        for i = 1, n do shown[i] = show(res[i]) end
        add(R, "WERT", label, table.concat(shown, ", "))
        local text = key and nums(res, n)
        if text then pairsOut[#pairsOut + 1] = key .. "=" .. text end
        return res
    end

    local level = value("UnitLevel", nil, 1, "UnitLevel", "player")
    local cls = value("UnitClass", nil, 2, "UnitClass", "player")
    local race = value("UnitRace", nil, 2, "UnitRace", "player")
    local classFile = cls and not isSecret(cls[2]) and type(cls[2]) == "string" and cls[2] or "?"
    local raceFile = race and not isSecret(race[2]) and type(race[2]) == "string" and race[2] or nil
    if raceFile then pairsOut[#pairsOut + 1] = "race=" .. raceFile:gsub("[^%w_]", "") end
    value("UnitHealthMax", "hp", 1, "UnitHealthMax", "player")
    value("UnitPowerMax (Mana)", "mana", 1, "UnitPowerMax", "player", 0)

    local effective = {}
    for _, s in ipairs(STATS) do
        local res = value(L["UnitStat(%d %s): Basis, Wert, plus, minus"]:format(s[1], L[s[3]]), s[2], 4, "UnitStat", "player", s[1])
        effective[s[1]] = res and not isSecret(res[2]) and tonumber(res[2]) or nil
    end
    for _, s in ipairs(STATS) do
        if effective[s[1]] then
            value(("GetAttackPowerForStat(%d, %s)"):format(s[1], num(effective[s[1]]) or "?"), "ap" .. s[2], 1, "GetAttackPowerForStat",
                s[1], effective[s[1]])
        else
            add(R, "WERT", ("GetAttackPowerForStat(%d)"):format(s[1]), L["nicht vorhanden (kein Wert)"])
        end
    end
    value("GetCritChanceFromAgility", "critagi", 1, "GetCritChanceFromAgility", "player")
    value("GetSpellCritChanceFromIntellect", "critint", 1, "GetSpellCritChanceFromIntellect", "player")

    value("GetCritChance", "crit", 1, "GetCritChance")
    value("GetRangedCritChance", "rcrit", 1, "GetRangedCritChance")
    if fn("GetSpellCritChance") then
        for school = 2, 7 do value(("GetSpellCritChance(%d)"):format(school), "sc" .. school, 1, "GetSpellCritChance", school) end
    else
        add(R, "WERT", "GetSpellCritChance", L["nicht vorhanden"])
    end
    value("GetDodgeChance", "dodge", 1, "GetDodgeChance")
    value("GetParryChance", "parry", 1, "GetParryChance")
    value("GetBlockChance", "block", 1, "GetBlockChance")
    value(L["UnitAttackPower: Basis, plus, minus"], "ap", 3, "UnitAttackPower", "player")
    value(L["UnitRangedAttackPower: Basis, plus, minus"], "rap", 3, "UnitRangedAttackPower", "player")
    value(L["GetManaRegen: Grund, beim Zaubern"], "regen", 2, "GetManaRegen")
    value(L["UnitArmor: Basis, wirksam, Rüstung, plus, minus"], "armor", 5, "UnitArmor", "player")

    local haveRating, haveBonus = fn("GetCombatRating"), fn("GetCombatRatingBonus")
    local lacking = {}
    for _, r in ipairs(RATINGS) do
        local id = _G[r[1]]
        if type(id) ~= "number" then
            lacking[#lacking + 1] = r[1]
        else
            local label = L["%s (%d): Wertung, Prozent"]:format(r[1], id)
            if not haveRating and not haveBonus then
                add(R, "WERT", label, L["nicht vorhanden"])
            else
                local okR, rating = true, nil
                if haveRating then okR, rating = pcall(haveRating, id) end
                local okB, bonus = true, nil
                if haveBonus then okB, bonus = pcall(haveBonus, id) end
                local a = okR and (haveRating and show(rating) or L["nicht vorhanden"]) or L["Fehler: %s"]:format(cut(rating))
                local b = okB and (haveBonus and show(bonus) or L["nicht vorhanden"]) or L["Fehler: %s"]:format(cut(bonus))
                add(R, "WERT", label, a .. ", " .. b)
                local ta, tb = okR and num(rating), okB and num(bonus)
                if ta or tb then pairsOut[#pairsOut + 1] = r[2] .. "=" .. (ta or "") .. "," .. (tb or "") end
            end
        end
    end
    if #lacking > 0 then add(R, "WERT", L["CR-Konstanten nicht vorhanden"], table.concat(lacking, ", ")) end

    local lv = level and num(level[1]) or "?"
    R.values = ("AMISIA-WERTE %d %s %s"):format(VALUES_FORMAT, classFile, lv)
        .. (#pairsOut > 0 and (" " .. table.concat(pairsOut, " ")) or "")
    add(R, "WERT", L["Maschinenzeile"], L["steht oben im Bericht (AMISIA-WERTE)"])
end

---------------------------------------------------------------------------
-- Saved data: size estimate and counts
---------------------------------------------------------------------------
-- Bytes the client would about write for v at depth (indent, key, " = ", value, ",\n"); stops after
-- the budget of entries (state.cut).
---------------------------------------------------------------------------
-- Professions: the functions the professions page reads, the own professions, a recipe's reagents
-- without the profession window, names and descriptions from the client, the Merchant's Favor
---------------------------------------------------------------------------
local PROF_FUNCTIONS = {
    "GetProfessions", "GetProfessionInfo", "C_TradeSkillUI.GetRecipeSchematic", "C_TradeSkillUI.GetRecipeInfo",
    "C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.IsTradeSkillGuild",
    "C_TradeSkillUI.IsNPCCrafting", "C_Spell.GetSpellName", "C_Spell.GetSpellDescription", "C_CurrencyInfo.GetCurrencyInfo",
}
ST.PROF_FUNCTIONS = PROF_FUNCTIONS
local PROF_RECIPE = 2663      -- Copper Bracers, a trainer recipe of blacksmithing
local PROF_CAMP = 1307392     -- the placement spell of the Sharpening Wheel
local PROF_CURRENCY = 3402    -- Merchant's Favor

local function sectionProfessions(R)
    local missing = {}
    for _, path in ipairs(PROF_FUNCTIONS) do
        if not fn(path) then missing[#missing + 1] = path end
    end
    listLine(R, L["Funktionen"], #PROF_FUNCTIONS, missing, L["vorhanden"])
    add(R, "WERT", L["Rezeptliste"], ("GetAllRecipeIDs %s, GetFilteredRecipeIDs %s, IsPlayerSpell %s"):format(
        fn("C_TradeSkillUI.GetAllRecipeIDs") and L["da"] or L["fehlt"], fn("C_TradeSkillUI.GetFilteredRecipeIDs") and L["da"] or L["fehlt"],
        fn("IsPlayerSpell") and L["da"] or L["fehlt"]))
    local Pr = ns.Prof
    check(R, L["Eigene Berufe"], function()
        local idx = { call("GetProfessions") }
        local parts, unknown = {}, {}
        for i = 1, 7 do
            if type(idx[i]) == "number" then
                local name, _, rank, max, _, _, skill = call("GetProfessionInfo", idx[i])
                parts[#parts + 1] = ("%s (%s) %s/%s"):format(show(name), show(skill), show(rank), show(max))
                if Pr and type(skill) == "number" and not Pr.Key(skill) then unknown[#unknown + 1] = tostring(skill) end
            end
        end
        if #parts == 0 then return "WERT", L["keine"] end
        if #unknown > 0 then return FEHLT, table.concat(parts, ", ") .. L["; nicht in den Daten: %s"]:format(table.concat(unknown, ", ")) end
        return "OK", table.concat(parts, ", ")
    end)
    check(R, L["Reagenzien ohne Fenster"], function()
        local sch = call("C_TradeSkillUI.GetRecipeSchematic", PROF_RECIPE, false)
        if type(sch) ~= "table" or type(sch.reagentSlotSchematics) ~= "table" then return FEHLT, L["keine Antwort für %d"]:format(PROF_RECIPE) end
        local parts = {}
        for _, slot in ipairs(sch.reagentSlotSchematics) do
            local first = type(slot.reagents) == "table" and slot.reagents[1]
            parts[#parts + 1] = ("%sx %s"):format(show(slot.quantityRequired), show(type(first) == "table" and first.itemID or nil))
        end
        return #parts > 0 and "OK" or FEHLT, ("%s: %s"):format(show(sch.name), #parts > 0 and table.concat(parts, ", ") or L["keine Plätze"])
    end)
    check(R, L["Rezeptname"], function()
        local name = call("C_Spell.GetSpellName", PROF_RECIPE)
        return type(name) == "string" and name ~= "" and "OK" or FEHLT, show(name)
    end)
    check(R, L["Lagerbeschreibung"], function()
        local text = call("C_Spell.GetSpellDescription", PROF_CAMP)
        if type(text) == "string" and text ~= "" then return "OK", show(text:sub(1, 120)) end
        -- the first ask after the login often finds the spell not loaded: a value, not a problem
        -- (the load is requested; the next run shows the text)
        if ns.Prof and ns.Prof.LoadSpell and ns.Prof.LoadSpell(PROF_CAMP) then return "WERT", L["noch nicht geladen"] end
        return FEHLT, show(text)
    end)
    check(R, L["Händlergunst"], function()
        local info = call("C_CurrencyInfo.GetCurrencyInfo", PROF_CURRENCY)
        if type(info) ~= "table" then return FEHLT, L["Währung %d unbekannt"]:format(PROF_CURRENCY) end
        return "OK", ("%s: %s"):format(show(info.name), show(info.quantity))
    end)
    check(R, L["Gespeicherter Stand"], function()
        local db = _G.AmisiaDB
        local c = type(db) == "table" and type(db.prof) == "table" and type(db.prof.chars) == "table"
            and db.prof.chars[ns.UnitFullName and ns.UnitFullName("player") or "?"]
        if type(c) ~= "table" then return "WERT", L["keiner (Berufsfenster einmal öffnen)"] end
        local parts, sample = {}, nil
        for skill, st in pairs(c) do
            local n = 0
            for spell in pairs(type(st) == "table" and type(st.known) == "table" and st.known or {}) do
                n = n + 1
                sample = sample or spell
            end
            parts[#parts + 1] = L["%s: Rang %s, %d bekannt"]:format(Pr and Pr.Name(skill) or tostring(skill),
                show(type(st) == "table" and st.rank or nil), n)
        end
        table.sort(parts)
        local spellText = ""
        if sample and fn("IsPlayerSpell") then
            spellText = ("; IsPlayerSpell(%d) = %s"):format(sample, show(call("IsPlayerSpell", sample)))
        end
        return "WERT", table.concat(parts, ", ") .. spellText
    end)
    if Pr and Pr.Available() then
        local d = ns.Data("PROFESSIONS")
        add(R, "WERT", L["Daten"], L["%d Berufe, Client %s, gebaut %s"]:format(#d.P, show(d.client), show(d.built)))
    else
        add(R, "WERT", L["Daten"], L["keine Berufsdaten"])
    end
end

local function svSize(v, depth, state)
    local t = type(v)
    if t == "string" then return #v + 2 end
    if t == "number" then return #tostring(v) end
    if t == "boolean" then return v and 4 or 5 end
    if t ~= "table" then return 3 end
    if depth > 30 then return 2 end
    local size = 2 + depth
    for k, item in pairs(v) do
        state.n = state.n + 1
        if state.n > SV_BUDGET then
            state.cut = true
            return size
        end
        local key = type(k) == "string" and (#k + 4) or (#tostring(k) + 2)
        size = size + depth + 1 + key + 3 + svSize(item, depth + 1, state) + 2
    end
    return size
end

local function kb(bytes) return ("%.1f KB"):format(bytes / 1024) end

local function sectionData(R)
    local db = _G.AmisiaDB
    if type(db) ~= "table" then
        add(R, FEHLT, "AmisiaDB", L["keine gespeicherten Daten"])
        return
    end
    check(R, L["Größe (geschätzt)"], function()
        local state = { n = 0 }
        local parts, total = {}, 0
        for k, v in pairs(db) do
            local s = svSize(v, 1, state) + #tostring(k) + 8
            total = total + s
            parts[#parts + 1] = { tostring(k), s }
        end
        table.sort(parts, function(a, b) return a[2] > b[2] end)
        local top = {}
        for i = 1, math.min(6, #parts) do top[i] = ("%s %s"):format(parts[i][1], kb(parts[i][2])) end
        return "WERT", (state.cut and L["mindestens %s in %d Einträgen; größte: %s"] or L["etwa %s in %d Einträgen; größte: %s"]):format(
            kb(total), state.n, table.concat(top, ", "))
    end)
    check(R, "Raids", function()
        local list = ns.Sessions and ns.Sessions() or {}
        local awards, items, kills = 0, 0, 0
        for _, s in ipairs(list) do
            awards = awards + (type(s.awards) == "table" and #s.awards or 0)
            items = items + (ns.ItemCount and ns.ItemCount(s) or 0)
            kills = kills + (type(s.kills) == "table" and #s.kills or 0)
        end
        return "WERT", L["%d Raids, %d Vergaben, %d Items, %d Bosskills%s"]:format(#list, awards, items, kills,
            ns.Active and ns.Active() and L[", Aufnahme läuft"] or "")
    end)
    check(R, L["Drop-Daten"], function()
        local d = ns.DropsStatus and ns.DropsStatus()
        if type(d) ~= "table" then return "WERT", L["keine"] end
        return "WERT", L["%d Kills (%d eigene, %d gehört), %d Bosse, neuester Tag %s"]:format(d.kills or 0, d.own or 0, d.heard or 0,
            d.bosses or 0, show(d.newest))
    end)
    check(R, L["Quellen-Sammler"], function()
        if not ns.CollectCounts then return "WERT", L["nicht geladen"] end
        if ns.CollectDB then ns.CollectDB() end
        local c, sy = ns.CollectCounts(), ns.CollectSyncStats and ns.CollectSyncStats() or {}
        return "WERT", L["%d Quests, %d Händler, %d Weltdrop-NPCs, %s; gelernt %d, gesendet %s"]:format(c.q, c.s, c.w,
            kb(ns.CollectBytes()), (sy.new or 0) + (sy.merged or 0), kb(sy.bytes or 0))
    end)
    check(R, L["Hersteller der Gilde"], function()
        if not ns.Crafters then return "WERT", L["nicht geladen"] end
        local n = 0
        for _ in pairs(type(db.crafters) == "table" and type(db.crafters.c) == "table" and db.crafters.c or {}) do n = n + 1 end
        local st = ns.CraftersStats()
        return "WERT", L["%d eigene, %d aus der Gilde; gelernt %d, gesendet %s"]:format(#ns.Crafters.Own(), n, st.crafters or 0,
            kb(st.bytes or 0))
    end)
    check(R, L["Materialien"], function()
        local list = ns.MatEntries and ns.MatEntries() or {}
        local hidden = 0
        for _, e in pairs(type(db.mats) == "table" and db.mats or {}) do
            if type(e) == "table" and e.hide then hidden = hidden + 1 end
        end
        return "WERT", L["%d in der Liste, %d ausgeblendet"]:format(#list, hidden)
    end)
    check(R, L["Itemnamen"], function()
        local n = 0
        for _ in pairs(type(db.itemNames) == "table" and db.itemNames or {}) do n = n + 1 end
        return "WERT", L["%d gemerkt"]:format(n)
    end)
end

---------------------------------------------------------------------------
-- Talents: what the calculator reads from the client (all optional: without it the page works
-- from its data)
---------------------------------------------------------------------------
local function sectionTalents(R)
    local T, d = ns.Talents, ns.Data("TALENTS")
    if not T or not T.Available() then
        add(R, "WERT", L["Talentdaten"], L["keine (TalentData.lua nicht geladen)"])
        return
    end
    local classes, nodes = T.Classes(), 0
    for _, cls in ipairs(classes) do nodes = nodes + #(T.Class(cls).data.nodes or {}) end
    add(R, "WERT", L["Talentdaten"], L["Build %s, %d Klassen, %d Talente, %d Punkte"]:format(tostring(d.build), #classes, nodes, T.Max()))
    local _, mine = UnitClass("player")
    local own = T.Class(mine)
    local config
    if fn("C_ClassTalents.GetActiveConfigID") then
        check(R, L["Aktive Konfiguration"], function()
            config = call("C_ClassTalents.GetActiveConfigID")
            if isSecret(config) then
                config = nil
                return "WERT", L["<geheim>"]
            end
            return "WERT", config and tostring(config) or L["keine"]
        end)
    else
        add(R, "WERT", L["Aktive Konfiguration"], L["%s fehlt"]:format("C_ClassTalents.GetActiveConfigID"))
    end
    if config and own then
        check(R, L["Talentbaum"], function()
            local info = call("C_Traits.GetConfigInfo", config)
            local ids = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs or {}
            local found = false
            for _, id in ipairs(ids) do found = found or id == own.tree end
            return found and "OK" or "WERT", L["Client %s, Daten %d"]:format(#ids > 0 and table.concat(ids, ",") or L["keiner"], own.tree)
        end)
        check(R, L["Knoten im Client"], function()
            local known, total, other = 0, 0, 0
            for id, n in pairs(own.byId) do
                total = total + 1
                local info = call("C_Traits.GetNodeInfo", config, id)
                if type(info) == "table" and info.ID == id then
                    known = known + 1
                    if type(info.maxRanks) == "number" and info.maxRanks ~= n[ns.Talents.F.MAX] then other = other + 1 end
                end
            end
            local live = T.Live()
            return known == total and other == 0 and "OK" or "WERT",
                L["%d von %d bekannt, %d mit anderem Höchstrang; gesetzt %d Punkte"]:format(known, total, other,
                    live and T.Spent(live) or 0)
        end)
        check(R, L["Talentpunkte"], function()
            local list = call("C_Traits.GetTreeCurrencyInfo", config, own.tree, false)
            local c = type(list) == "table" and list[1]
            if type(c) ~= "table" then return "WERT", L["keine Angabe"] end
            return "WERT", L["frei %s, ausgegeben %s, höchstens %s"]:format(show(c.quantity), show(c.spent), show(c.maxQuantity))
        end)
    end
    -- another class: do its texts and tree names come without a configuration of that class?
    local other
    for _, cls in ipairs(classes) do
        if cls ~= mine then other = cls break end
    end
    local oc = other and T.Class(other)
    local n = oc and oc.order[1][1]
    if not n then return end
    local F = T.F
    if fn("C_Traits.GetTraitDescription") then
        check(R, L["Text fremde Klasse"], function()
            local text = call("C_Traits.GetTraitDescription", n[F.ENTRY], 1)
            return type(text) == "string" and text ~= "" and "OK" or "WERT", ("%s %s: %s"):format(other, show(n[F.NAME]), show(text))
        end)
    end
    if fn("C_Traits.GetGroupDisplayInfoByTreeID") then
        check(R, L["Baumnamen fremde Klasse"], function()
            local infos = call("C_Traits.GetGroupDisplayInfoByTreeID", oc.tree)
            local names = {}
            for _, info in ipairs(type(infos) == "table" and infos or {}) do names[#names + 1] = show(info.displayName) end
            return #names == 3 and "OK" or "WERT", #names > 0 and table.concat(names, ", ") or L["keine"]
        end)
    end
    if fn("C_Spell.GetSpellName") then
        check(R, "Spell-Name", function() return "WERT", show(call("C_Spell.GetSpellName", n[F.SPELL])) end)
    end
end

---------------------------------------------------------------------------
-- Running it
---------------------------------------------------------------------------
-- The whole test: { lines, problems, counts, text }. opts.waypoint sets a waypoint at the own
-- position (the only change the test makes).
function ST.Run(opts)
    opts = opts or {}
    local R = newReport()
    runSection(R, "Client", sectionClient)
    runSection(R, L["Sperren jetzt"], sectionLock)
    runSection(R, L["Namen"], sectionNames)
    runSection(R, L["Addon-Nachrichten und Packen"], sectionComm)
    runSection(R, L["Gilde"], sectionGuild)
    runSection(R, L["Woche, Karte, Wegpunkt"], sectionMap, opts)
    runSection(R, "Loot", sectionLoot)
    runSection(R, L["Atlanten"], sectionAtlases)
    runSection(R, L["Dungeonbilder"], sectionArt)
    runSection(R, L["Vorlagen"], sectionTemplates)
    runSection(R, L["Client-Funktionen"], sectionFunctions)
    runSection(R, L["Ereignisse"], sectionEvents)
    runSection(R, L["Item-Konstanten"], sectionItems)
    runSection(R, L["Werte"], sectionValues)
    runSection(R, L["Berufe"], sectionProfessions)
    runSection(R, L["Talente"], sectionTalents)
    runSection(R, L["Gespeicherte Daten"], sectionData)
    local c = R.counts
    local build = "?"
    local okBuild, version, number = pcall(GetBuildInfo)
    if okBuild then build = ("%s (%s)"):format(tostring(version), tostring(number)) end
    local head = {
        L["Amisia-Selbsttest %s | Client %s | %s"]:format(tostring(ns.VERSION), build, date("%Y-%m-%d %H:%M")),
        L["Ergebnis: %d OK, %d FEHLT, %d FEHLER, %d WERT"]:format(c.OK, c.FEHLT, c.FEHLER, c.WERT),
    }
    -- the values in one line to paste (section "Werte")
    if R.values then head[#head + 1] = R.values end
    if #R.problems > 0 then
        head[#head + 1] = L["Probleme:"]
        for _, p in ipairs(R.problems) do head[#head + 1] = "  " .. p end
    end
    for i = #head, 1, -1 do table.insert(R.lines, 1, head[i]) end
    R.text = table.concat(R.lines, "\n")
    return R
end

---------------------------------------------------------------------------
-- The dialog: the report in a read-only box to copy
---------------------------------------------------------------------------
local D, reportText

local function build()
    local W = ns.W
    D = W.Window("AmisiaSelfTestFrame", 640, 500, { title = L["Amisia-Selbsttest"], strata = "FULLSCREEN_DIALOG" })
    D:SetPoint("CENTER", 0, 20)
    D.intro = W.Text(D, "GameFontHighlightSmall", 612, true)
    D.intro:SetPoint("TOPLEFT", 14, -32)
    D.intro:SetText(L["Prüft im Client alles, was die Pläne offen lassen. Nichts wird gesendet."])
    D.area = W.EditArea(D)
    D.area:SetPoint("TOPLEFT", 12, -52)
    D.area:SetPoint("BOTTOMRIGHT", -12, 44)
    -- read-only like the export box: typing puts the text back and marks it
    D.area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(reportText or "")
            self:HighlightText()
        end
    end)
    D.hint = W.Text(D, "GameFontDisableSmall", 330)
    D.hint:SetPoint("BOTTOMLEFT", 14, 18)
    D.hint:SetText(L["Strg+A, Strg+C und im Chat an uns einfügen."])
    D.mark = W.Button(D, L["Alles markieren"], 120, function()
        D.area.box:SetFocus()
        D.area.box:HighlightText()
    end)
    D.mark:SetPoint("BOTTOMRIGHT", -12, 12)
    D.again = W.Button(D, L["Erneut prüfen"], 120, function() ST.Show() end)
    D.again:SetPoint("RIGHT", D.mark, "LEFT", -6, 0)
end

-- Runs the test and shows the report; returns it.
function ST.Show(opts)
    local R = ST.Run(opts)
    reportText = R.text
    if not D then build() end
    D.area.box:SetText(reportText)
    D:Show()
    D.area.box:SetFocus()
    D.area.box:HighlightText()
    return R
end

function ST.Frame() return D end

-- The short variant: only the problems, in the own chat frame.
function ST.Short(opts)
    local R = ST.Run(opts)
    local c = R.counts
    if #R.problems == 0 then
        ns.msg(L["Selbsttest: keine Probleme (%d OK, %d Werte). Ganzer Bericht: /amisia selbsttest"]:format(c.OK, c.WERT))
        return R
    end
    ns.msg(L["Selbsttest: %d Problem(e). Ganzer Bericht: /amisia selbsttest"]:format(#R.problems))
    local chat = DEFAULT_CHAT_FRAME
    for i = 1, math.min(#R.problems, MAX_SHORT) do chat:AddMessage("  " .. R.problems[i]) end
    if #R.problems > MAX_SHORT then chat:AddMessage(L["  ... und %d weitere"]:format(#R.problems - MAX_SHORT)) end
    return R
end

ns.ShowSelfTest = function() return ST.Show() end

ns.RegisterSlash("selbsttest", { en = "selftest", args = L["[kurz] [wegpunkt]"],
    desc = L["prüft den Client, Bericht zum Kopieren (kurz: nur Probleme im Chat)"], run = function(rest)
    local opts = {}
    local short = false
    for word in tostring(rest or ""):lower():gmatch("%S+") do
        if word == "kurz" or word == "short" then -- l10n-ok: the German and English sub-words
            short = true
        elseif word == "wegpunkt" or word == "waypoint" then -- l10n-ok: the German and English sub-words
            opts.waypoint = true
        end
    end
    if short then ST.Short(opts) else ST.Show(opts) end
end })
