-- /amisia selbsttest layer (en selftest layer; F-192, D-124): what the layer display and the layer change
-- (Gear/Layer.lua, Gear/LayerChange.lua; F-185, F-191) need from THIS client, checked alone, because
-- nothing of it can be known without the game. It looks up the functions; reads the zone, the target's
-- GUID, the current layer and the zone's known ones; reads every name plate in sight and counts the
-- zone ids of the creatures (one id for all of them is what a per-copy id looks like, a different id on
-- nearly every creature is not); reports this session's reads per source, the layer changes without a
-- zone change (and how many came in a group: the proof that the id follows the layer), what Amisia's
-- invites, accepts and leaves did (Gear/LayerChange.lua, SW.Trace) and the request lines seen in chat;
-- lists the chat channels and the channel of "Im Kanal fragen". Then three calls from timers, as the
-- swap makes them without a key press: an invite to a name nobody has (LT.NAME; the server answers
-- "player not found"), and, only while the player is in no group and no invite is open (none came in the
-- last two minutes and the client's invite window is not shown), AcceptGroup and
-- LeaveParty, which then do nothing: what counts is whether the client blocks Amisia
-- (ADDON_ACTION_BLOCKED, ADDON_ACTION_FORBIDDEN). Nothing goes to chat or to another player; never in
-- combat, a chat lockdown or an instance. The report goes into the self-test window and ends with the
-- verdicts in plain words and how to check a real change.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local ST = ns.SelfTest
local K = ST.Kit
local add, check, show, fn, call, isSecret, cut = K.add, K.check, K.show, K.fn, K.call, K.isSecret, K.cut
local FEHLT = K.FEHLT
local LY, SW = ns.Layer, ns.LayerChange
-- the layer parts load on WoW Forever only (D-57): without them there is nothing to probe
if not LY or not SW then return end

local LT = {}
ST.Layer = LT

LT.NAME = "Niemand Nirgends" -- l10n-ok: a character name nobody has (first name and surname, as Forever names are)
LT.WAIT = 3          -- seconds to wait for the server's answer to the invite
LT.STEP = 1          -- seconds each of the two empty calls (accept, leave) is watched
LT.PLATES = 40       -- name plates read at most
LT.HISTORY = 10      -- layer changes listed at most
LT.FLIP = 60         -- seconds: back on the layer before within this is a "back and forth"
LT.FEW = 3           -- fewer creatures in sight say nothing about the id
LT.INVITE_LIFE = 120 -- seconds a group invite is taken to be open after it came
local STALE = 30
local MAX_MESSAGES = 4
local WATCH = { "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
local SOURCES = { { "target", L["Ziel"] }, { "mouseover", L["Maus"] }, { "plate", L["Plaketten"] } }

-- The functions the layer parts need, per use; only looked up ("a|b": either).
LT.FUNCTIONS = {
    { L["Layer lesen"], { "UnitGUID", "UnitPlayerControlled", "UnitIsOtherPlayersPet", "UnitIsPlayer", "C_NamePlate.GetNamePlates",
        "C_Map.GetBestMapForUnit", "C_Map.GetMapInfo", "IsInInstance" } },
    { L["Einladen, Annehmen, Verlassen"], { "C_PartyInfo.InviteUnit|InviteUnit", "AcceptGroup", "C_PartyInfo.LeaveParty|LeaveParty",
        "StaticPopup_Hide", "StaticPopup_Visible", "IsInGroup", "GetNumGroupMembers", "InCombatLockdown" } },
    { L["Chat und Kanäle"], { "ChatFrame_OpenChat|ChatFrameUtil.OpenChat", "GetChannelList", "GetChannelName",
        "C_ChatInfo.InChatMessagingLockdown" } },
}

local run
local inviteAt     -- the time of the newest group invite that may still be open

local function either(path)
    for one in path:gmatch("[^|]+") do
        local f = fn(one)
        if f then return f end
    end
    return nil
end

local function flag(name, ...)
    local f = fn(name)
    if not f then return false end
    local ok, v = pcall(f, ...)
    return ok and not isSecret(v) and v and true or false
end

local function notFound(text)
    local p = ns.TemplatePattern and ns.TemplatePattern(rawget(_G, "ERR_BAD_PLAYER_NAME_S"))
    return p ~= nil and text:find(p) ~= nil
end

local function onEvent(_, event, ...)
    local P = run
    local r = P and P.steps[P.phase or ""]
    if not r then return end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local who, what = ...
        if not isSecret(who) and who == ADDON then
            r.blocked = ("%s %s"):format(event, isSecret(what) and L["<geheim>"] or tostring(what))
        end
        return
    end
    if #r.messages >= MAX_MESSAGES then return end
    local text
    if event == "CHAT_MSG_SYSTEM" then
        text = ...
    else
        local _, message = ...
        text = message
    end
    if isSecret(text) then
        r.messages[#r.messages + 1] = L["<geheim>"]
    elseif type(text) == "string" then
        r.messages[#r.messages + 1] = '"' .. text .. '"'
        if notFound(text) then r.notFound = true end
    end
end

local listen = K.listener(onEvent, WATCH)

---------------------------------------------------------------------------
-- Functions, the layer now
---------------------------------------------------------------------------
local function sectionFunctions(P)
    local R = P.R
    K.section(R, L["Layer: Funktionen"])
    for _, group in ipairs(LT.FUNCTIONS) do
        local lack = {}
        for _, path in ipairs(group[2]) do
            if not either(path) then lack[#lack + 1] = path end
        end
        K.listLine(R, group[1], #group[2], lack, L["vorhanden"])
    end
end

local function sectionNow(P)
    local R = P.R
    K.section(R, L["Layer: jetzt"])
    check(R, L["Zone"], function()
        local map = LY.Map()
        local info = map and fn("C_Map.GetMapInfo") and C_Map.GetMapInfo(map)
        return "WERT", L["Karte %s (%s), in einer Instanz: %s"]:format(tostring(map or "-"),
            type(info) == "table" and show(info.name) or "?", show(LY.InInstance()))
    end)
    check(R, L["Layer: Kreatur-GUID"], function() return LY.Probe() end)
    check(R, L["Aktueller Layer"], function()
        local uid, _, name, age = LY.Current()
        if not uid then return "WERT", L["unbekannt: einen NPC ins Ziel nehmen oder die Namensplaketten einschalten"] end
        return "OK", L["%s, Zonen-Kennung %d, zuletzt gelesen vor %d s"]:format(name, uid, math.floor(age + 0.5))
    end)
    check(R, L["Bekannte Layer dieser Zone"], function()
        local parts = {}
        for _, e in ipairs(LY.List()) do
            parts[#parts + 1] = ("%s=%d%s%s"):format(e.letter, e.uid, e.current and (" " .. L["hier"]) or "",
                e.own and "" or (" " .. L["Gilde"]))
        end
        return "WERT", #parts > 0 and table.concat(parts, ", ") or L["keine"]
    end)
end

---------------------------------------------------------------------------
-- The name plates in sight
---------------------------------------------------------------------------
-- { n, creatures, secret, controlled, other, kinds, ids = { [zoneUID] = count } } of the plates shown now.
function LT.ReadPlates()
    local out = { n = 0, creatures = 0, secret = 0, controlled = 0, other = 0, kinds = 0, ids = {} }
    local list = call("C_NamePlate.GetNamePlates")
    for _, plate in ipairs(type(list) == "table" and list or {}) do
        if out.n >= LT.PLATES then break end
        local unit = plate.namePlateUnitToken
        if type(unit) ~= "string" and type(plate.UnitFrame) == "table" then unit = plate.UnitFrame.unit end
        if type(unit) == "string" then
            out.n = out.n + 1
            local ok, guid = pcall(call, "UnitGUID", unit)
            if not ok or guid == nil then
                out.other = out.other + 1
            elseif isSecret(guid) then
                out.secret = out.secret + 1
            else
                local kind, uid = LY.Parse(guid)
                if not kind then
                    out.other = out.other + 1
                elseif flag("UnitPlayerControlled", unit) or flag("UnitIsOtherPlayersPet", unit) then
                    out.controlled = out.controlled + 1
                else
                    out.creatures = out.creatures + 1
                    if not out.ids[uid] then out.kinds = out.kinds + 1 end
                    out.ids[uid] = (out.ids[uid] or 0) + 1
                end
            end
        end
    end
    return out
end

-- The ids of a plate count by number of creatures, the most frequent first: { { uid, n } }.
local function sortedIds(ids)
    local list = {}
    for uid, n in pairs(ids) do list[#list + 1] = { uid, n } end
    table.sort(list, function(a, b)
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    return list
end

-- What the creatures in sight say about the id: mark and text.
function LT.IdVerdict(pl)
    if pl.creatures < LT.FEW then
        return "WERT", L["zu wenige Kreaturen in Sicht (%d): mit Namensplaketten (Taste V) in einer belebten Gegend neu prüfen"]:format(pl.creatures)
    end
    local top = sortedIds(pl.ids)[1]
    if pl.kinds == 1 then
        return "OK", L["alle %d Kreaturen in Sicht tragen dieselbe Zonen-Kennung (%d)"]:format(pl.creatures, top[1])
    end
    if top[2] * 5 >= pl.creatures * 4 then
        return "OK", L["%d von %d Kreaturen tragen die Kennung %d, %d eine andere (wohl hinter der Zonengrenze)"]:format(top[2],
            pl.creatures, top[1], pl.creatures - top[2])
    end
    if pl.kinds * 2 > pl.creatures then
        return "FEHLER", L["%d Kreaturen, %d verschiedene Kennungen: an dieser Kennung ist kein Layer zu erkennen"]:format(pl.creatures, pl.kinds)
    end
    return "WERT", L["%d Kreaturen, %d Kennungen, keine überwiegt: an einer Zonengrenze? Mitten in der Zone neu prüfen"]:format(pl.creatures, pl.kinds)
end

local function sectionPlates(P)
    local R = P.R
    K.section(R, L["Layer: Namensplaketten"])
    check(R, L["In Sicht"], function()
        local pl = LT.ReadPlates()
        P.plates = pl
        return "WERT", L["%d Plaketten: %d Kreaturen, %d von Spielern gesteuert, %d geheim, %d anderes"]:format(pl.n, pl.creatures,
            pl.controlled, pl.secret, pl.other)
    end)
    local pl = P.plates
    if not pl then return end
    if pl.secret > 0 and pl.creatures == 0 then
        add(R, "FEHLER", L["GUID der Plaketten"], L["geheim: über Namensplaketten ist der Layer hier nicht zu lesen"])
    end
    local parts = {}
    for i, e in ipairs(sortedIds(pl.ids)) do
        if i > 6 then parts[#parts + 1] = "..." break end
        parts[#parts + 1] = ("%d x%d"):format(e[1], e[2])
    end
    add(R, "WERT", L["Zonen-Kennungen"], #parts > 0 and table.concat(parts, ", ") or L["keine"])
end

---------------------------------------------------------------------------
-- This session
---------------------------------------------------------------------------
-- The layer changes without a zone change in history (Layer.lua, LY.Stats): how many, how many of them
-- while in a group, how many went back to the layer before within LT.FLIP seconds.
function LT.Switches(history)
    local n, inGroup, flips = 0, 0, 0
    local prev, before
    for _, e in ipairs(history) do
        if e.zone then
            prev, before = nil, nil
        else
            if prev and prev.map == e.map and prev.uid ~= e.uid then
                n = n + 1
                if e.grouped then inGroup = inGroup + 1 end
                if before and before.map == e.map and before.uid == e.uid and e.at - before.at <= LT.FLIP then flips = flips + 1 end
            end
            before, prev = prev, e
        end
    end
    return n, inGroup, flips
end

local function clock(at)
    return date("%H:%M:%S", time() - math.floor(GetTime() - at + 0.5))
end

local function sectionSession(P)
    local R = P.R
    K.section(R, L["Layer: diese Sitzung"])
    local stats, history = LY.Stats()
    check(R, L["Gelesen"], function()
        local parts = {}
        for _, s in ipairs(SOURCES) do
            parts[#parts + 1] = L["%s %d von %d"]:format(s[2], stats.ok[s[1]] or 0, stats.read[s[1]] or 0)
        end
        parts[#parts + 1] = L["geheime GUIDs %d"]:format(stats.secret)
        return "WERT", table.concat(parts, ", ")
    end)
    local n, inGroup, flips = LT.Switches(history)
    P.switches, P.switchesGrouped, P.flips = n, inGroup, flips
    add(R, "WERT", L["Layer-Wechsel ohne Zonenwechsel"], L["%d, davon %d in einer Gruppe, %d Hin und Her"]:format(n, inGroup, flips))
    for i = math.max(1, #history - LT.HISTORY + 1), #history do
        local e = history[i]
        if e.zone then
            add(R, "WERT", clock(e.at), L["Zonenwechsel"])
        else
            add(R, "WERT", clock(e.at), L["Karte %d, Zonen-Kennung %d, %s"]:format(e.map, e.uid, e.grouped and L["in einer Gruppe"] or L["allein"]))
        end
    end
    local tr = SW.Trace()
    P.trace = tr
    add(R, "WERT", L["Einladungen von Amisia"], L["%d versucht, %d vom Spiel gesperrt, %d beigetreten"]:format(tr.invite.tried,
        tr.invite.blocked, tr.invite.joined))
    add(R, "WERT", L["Annahmen von Amisia"], L["%d versucht, %d vom Spiel gesperrt, %d beigetreten"]:format(tr.accept.tried,
        tr.accept.blocked, tr.accept.joined))
    add(R, "WERT", L["Verlassen durch Amisia"], L["%d versucht, %d vom Spiel gesperrt, %d verlassen"]:format(tr.leave.tried,
        tr.leave.blocked, tr.leave.left))
    for _, kind in ipairs({ "invite", "accept", "leave" }) do
        if tr[kind].blocked > 0 then
            add(R, "FEHLER", L["Gesperrt in dieser Sitzung"], ("%s: %s"):format(kind, tostring(tr[kind].what or "?")))
        end
    end
    add(R, "WERT", L["Wechsel über Amisia"], L["%d gelungen, %d ohne Wechsel, %d unklar"]:format(tr.changed, tr.failed, tr.unknown))
    local lines = {}
    for key, count in pairs(tr.lines) do lines[#lines + 1] = ("%s %d"):format(key, count) end
    table.sort(lines)
    add(R, "WERT", L["Bitten im Chat gesehen"], #lines > 0 and table.concat(lines, ", ") or L["keine"])
end

---------------------------------------------------------------------------
-- Channels and settings
---------------------------------------------------------------------------
local function sectionChannels(P)
    local R = P.R
    K.section(R, L["Layer: Kanäle und Einstellungen"])
    check(R, L["Kanäle"], function()
        local list = { call("GetChannelList") }
        local parts = {}
        for i = 1, #list - 1, 3 do
            if #parts >= 10 then break end
            parts[#parts + 1] = ("%s %s"):format(show(list[i]), show(list[i + 1]))
        end
        return "WERT", #parts > 0 and table.concat(parts, ", ") or L["keine"]
    end)
    check(R, L["Kanal für \"Im Kanal fragen\""], function()
        local n, name = SW.Channel()
        if not name then return "WERT", L["%d: in diesem Kanal bist du nicht"]:format(n) end
        return "OK", ("%d %s"):format(n, show(name))
    end)
    check(R, L["Einstellungen"], function()
        local parts = {}
        for _, key in ipairs({ "answer", "chat", "others", "othersAuto", "autoInvite", "autoAccept", "autoLeave" }) do
            parts[#parts + 1] = ("%s %s"):format(key, show(ns.Get("layer." .. key) and true or false))
        end
        return "WERT", table.concat(parts, ", ")
    end)
end

---------------------------------------------------------------------------
-- The three calls without a key press
---------------------------------------------------------------------------
-- Why no call can be tried now: the reason, or nil.
local function blockedNow()
    if flag("InCombatLockdown") then return L["im Kampf"] end
    if flag("C_ChatInfo.InChatMessagingLockdown") then return L["Kampfsperre"] end
    if LY.InInstance() then return L["in einer Instanz"] end
    return nil
end

-- Whether a group invite may be open: AcceptGroup would take it. An invite of the last INVITE_LIFE
-- seconds counts (another addon may have hidden its window), and so does a client that cannot say
-- whether the window shows.
local function inviteOpen()
    if inviteAt and GetTime() - inviteAt <= LT.INVITE_LIFE then return true end
    local f = fn("StaticPopup_Visible")
    if not f then return true end
    local ok, v = pcall(f, "PARTY_INVITE")
    return not ok or (v and true or false)
end
ns.OnEvent("PARTY_INVITE_REQUEST", function() inviteAt = GetTime() end)
ns.OnEvent("PARTY_INVITE_CANCEL", function() inviteAt = nil end)
ns.OnEvent("GROUP_ROSTER_UPDATE", function() inviteAt = nil end)

local CALLS = {
    invite = function(r)
        local f = either("C_PartyInfo.InviteUnit|InviteUnit")
        if not f then r.missing = true return end
        r.called, r.ok, r.err = true, pcall(f, LT.NAME)
    end,
    -- with no invite open and no group, both calls do nothing: only a block by the client shows
    accept = function(r)
        if flag("IsInGroup") then r.skipped = L["du bist in einer Gruppe"] return end
        if inviteOpen() then r.skipped = L["eine Einladung ist offen"] return end
        local f = fn("AcceptGroup")
        if not f then r.missing = true return end
        r.called, r.ok, r.err = true, pcall(f)
    end,
    leave = function(r)
        if flag("IsInGroup") then r.skipped = L["du bist in einer Gruppe"] return end
        local f = either("C_PartyInfo.LeaveParty|LeaveParty")
        if not f then r.missing = true return end
        r.called, r.ok, r.err = true, pcall(f)
    end,
}

local function step(P, kind)
    local r = { messages = {} }
    P.steps[kind] = r
    P.phase = kind
    local why = blockedNow()
    if why then
        r.skipped = why
        return
    end
    CALLS[kind](r)
end

-- One step's result: mark, text and the word for the chat line.
local function stepResult(r, kind)
    if not r then return "WERT", L["nicht geprüft"], L["nicht geprüft"] end
    if r.skipped then return "WERT", L["übersprungen (%s)"]:format(r.skipped), L["übersprungen (%s)"]:format(r.skipped) end
    if r.missing then return FEHLT, L["die Funktion fehlt"], L["fehlt"] end
    if r.blocked then return "FEHLER", L["vom Spiel gesperrt: %s"]:format(r.blocked), L["gesperrt"] end
    if not r.ok then return "FEHLER", cut(tostring(r.err)), L["Fehler"] end
    if kind ~= "invite" then
        return "OK", L["nicht gesperrt (der Aufruf selbst tat nichts: keine Einladung offen, keine Gruppe)"], L["erlaubt"]
    end
    if r.notFound then return "OK", L["erlaubt: der Server antwortet \"Spieler nicht gefunden\""], L["erlaubt"] end
    if #r.messages > 0 then return "WERT", L["andere Meldung: %s"]:format(table.concat(r.messages, " | ")), L["andere Meldung"] end
    return "WERT", L["keine Antwort in %d s"]:format(LT.WAIT), L["keine Antwort"]
end

---------------------------------------------------------------------------
-- The end: the calls' results, the verdicts, how to check a real change
---------------------------------------------------------------------------
local LABELS = { invite = L["Einladen"], accept = L["Annehmen"], leave = L["Verlassen"] }

local function finishProbe(P)
    if P.finished then return end
    P.finished = true
    P.phase = nil
    listen(false)
    if run == P then run = nil end
    local R = P.R
    local words = {}
    K.section(R, L["Layer: Aufrufe ohne Tastendruck"])
    for _, kind in ipairs({ "invite", "accept", "leave" }) do
        local mark, text, word = stepResult(P.steps[kind], kind)
        add(R, mark, LABELS[kind], text)
        words[kind] = word
    end
    K.section(R, L["Layer: Ergebnis"])
    if P.plates then
        local mark, text = LT.IdVerdict(P.plates)
        add(R, mark, L["Kennung je Zonenkopie"], text)
    end
    local tr = P.trace
    if (tr and tr.changed > 0) or (P.switchesGrouped or 0) > 0 then
        add(R, "OK", L["Kennung folgt dem Layer"], L["ja: in dieser Sitzung wechselte die Kennung in einer Gruppe, ohne Zonenwechsel"])
    elseif (P.flips or 0) > 1 then
        add(R, "WERT", L["Kennung folgt dem Layer"], L["unklar: die Kennung sprang %d-mal hin und her, ohne Gruppe"]:format(P.flips))
    else
        add(R, "WERT", L["Kennung folgt dem Layer"], L["noch nicht gesehen: dafür braucht es einen echten Wechsel (siehe unten)"])
    end
    R.lines[#R.lines + 1] = ""
    R.lines[#R.lines + 1] = L["So prüfst du einen echten Wechsel:"]
    R.lines[#R.lines + 1] = L["1. Namensplaketten an (Taste V), in einer Zone mit NPCs: /amisia layer zeigt einen Layer."]
    R.lines[#R.lines + 1] = L["2. Lass dich allein von einem Spieler einladen, der in derselben Zone auf einem anderen Layer ist (\"Gilde fragen\" oder \"Im Kanal fragen\")."]
    R.lines[#R.lines + 1] = L["3. Ziele in der Gruppe einen NPC an und starte /amisia selbsttest layer noch einmal: unter \"diese Sitzung\" steht dann ein Layer-Wechsel in einer Gruppe."]
    R = K.finish(R, L["Amisia-Layer-Prüfung %s | Client %s | %s"])
    LT.last = R
    ST.ShowText(R.text, function() LT.Start() end)
    ns.msg(L["Layer-Prüfung fertig: Einladen %s, Annehmen %s, Verlassen %s. Der Bericht steht im Fenster."]:format(words.invite,
        words.accept, words.leave))
end

local safe = K.safeWith(finishProbe)

---------------------------------------------------------------------------
-- The start (the slash command, or "Erneut prüfen")
---------------------------------------------------------------------------
function LT.Start()
    if run and not run.finished and GetTime() - run.at < STALE then
        ns.msg(L["Layer-Prüfung läuft schon."])
        return
    end
    local P = { R = K.newReport(), at = GetTime(), steps = {} }
    run = P
    listen(true)
    SW.ForgetCall()   -- a block of the probe's own calls is not counted for the swap's
    for _, body in ipairs({ sectionFunctions, sectionNow, sectionPlates, sectionSession, sectionChannels }) do
        local ok, err = pcall(body, P)
        if not ok then add(P.R, "FEHLER", L["Abschnitt"], cut(tostring(err))) end
    end
    ns.msg(L["Layer-Prüfung läuft (etwa %d s) ..."]:format(LT.WAIT + 2 * LT.STEP))
    -- from timers: the swap's calls come from messages and events, never from a key press
    C_Timer.After(0.1, safe(P, function() step(P, "invite") end))
    C_Timer.After(0.1 + LT.WAIT, safe(P, function() step(P, "accept") end))
    C_Timer.After(0.1 + LT.WAIT + LT.STEP, safe(P, function() step(P, "leave") end))
    C_Timer.After(0.1 + LT.WAIT + 2 * LT.STEP, function() finishProbe(P) end)
end

function LT.Running() return run ~= nil and not run.finished end
end)
