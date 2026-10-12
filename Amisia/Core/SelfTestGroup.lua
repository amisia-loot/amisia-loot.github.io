-- /amisia selbsttest gruppe: what the raid check (spec 2026-10-12) and the invite and sort parts
-- of the raid lineup (spec 2026-10-10, parts C and D, checks 10, 11 and 13) need from the client,
-- checked alone. It looks up the group functions (invite, convert, sort, assistant, ready check),
-- the system message templates and the saved instance functions; invites a name that does not
-- exist (GT.NAME) once inside the key press of the command and once from a C_Timer, and watches
-- the client's answer (system message, error line) and whether it blocks Amisia; asks for the own
-- raid IDs (RequestRaidInfo, UPDATE_INSTANCE_INFO) and lists them; reads the own buffs and whether
-- aura data is secret now (and a player target's buffs); the durability of every worn item, the
-- average item level, the enchant of every worn item (item link and tooltip data line types) and
-- the free talent points. Read-mostly: the two invites go to a name nobody has (the server says
-- "player not found"); nothing else changes, nothing goes to chat or other players. Every call is
-- protected; a missing function is FEHLT, never an error. The report goes into the self-test window.
local ADDON, ns = ...
local L = ns.L

local ST = ns.SelfTest
local K = ST.Kit
local add, check, show, fn, call, isSecret, cut = K.add, K.check, K.show, K.fn, K.call, K.isSecret, K.cut
local FEHLT = K.FEHLT

local GT = {}
ST.Group = GT

GT.NAME = "Niemand Nirgends" -- l10n-ok: a character name nobody has (first name and surname, as Forever names are)
GT.DELAY = 2         -- seconds between the invite from the key press and the one from a timer
GT.WAIT = 4          -- seconds to wait for the server's answer to the second invite
local STALE = 60     -- a probe older than this counts as gone (a new one may start)
local MAX_AURAS = 40
local SHOW_AURAS = 12
local LONG_AURA = 600     -- seconds: a buff at least this long is listed as a flask, elixir or food candidate
local MAX_SAVED = 30
local MAX_MESSAGES = 6    -- system messages kept per phase

-- The functions the later parts need, per use; only looked up.
GT.FUNCTIONS = {
    { L["Einladen, Umwandeln, Sortieren, Assistent"], { "C_PartyInfo.InviteUnit", "C_PartyInfo.ConvertToRaid", "C_PartyInfo.CanInvite",
        "C_PartyInfo.AllowedToDoPartyConversion", "C_PartyInfo.PromoteToAssistant", "PromoteToAssistant", "SetRaidSubgroup",
        "SwapRaidSubgroup", "UnitIsGroupLeader", "UnitIsGroupAssistant" } },
    { L["Bereitschaftscheck"], { "DoReadyCheck", "GetReadyCheckStatus", "ConfirmReadyCheck" } },
    { L["Raid-IDs"], { "RequestRaidInfo", "GetNumSavedInstances", "GetSavedInstanceInfo", "GetNumSavedWorldBosses" } },
    { L["Auren"], { "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetBuffDataByIndex", "C_UnitAuras.GetPlayerAuraBySpellID",
        "C_Secrets.ShouldAurasBeSecret", "C_Secrets.ShouldUnitAuraIndexBeSecret" } },
    { L["Ausrüstung"], { "GetInventoryItemLink", "GetInventoryItemDurability", "GetAverageItemLevel", "C_TooltipInfo.GetInventoryItem" } },
}
-- The system message templates the invite status would read (check 10).
GT.TEMPLATES = { "ERR_INVITE_PLAYER_S", "ERR_DECLINE_GROUP_S", "ERR_ALREADY_IN_GROUP_S", "ERR_BAD_PLAYER_NAME_S", "ERR_GROUP_FULL",
    "ERR_JOINED_GROUP_S", "ERR_RAID_MEMBER_ADDED_S" }
local WATCH = { "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UPDATE_INSTANCE_INFO" }
-- worn slots without durability or enchant interest are left out (shirt 4, tabard 19)
local FALLBACK_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local ENCHANT_LINE = 15   -- Enum.TooltipDataLineType.ItemEnchantmentPermanent in 1.60.1

-- The worn slots in the gear planner's order with their names: { inv, name }.
local function slots()
    local list = {}
    local G = ns.Gear
    if G and type(G.SLOTS) == "table" then
        for _, s in ipairs(G.SLOTS) do list[#list + 1] = { inv = s.inv, name = s.name } end
    else
        for _, inv in ipairs(FALLBACK_SLOTS) do list[#list + 1] = { inv = inv, name = L["Platz %d"]:format(inv) } end
    end
    return list
end

-- A message template ("Spieler '%s' nicht gefunden.") as a Lua pattern, or nil.
local function templatePattern(t)
    if type(t) ~= "string" or isSecret(t) or t == "" then return nil end
    local p = t:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p .. "$"
end

-- The name of the template a system message fits, or nil.
local function whichTemplate(text)
    if type(text) ~= "string" then return nil end
    for _, name in ipairs(GT.TEMPLATES) do
        local p = templatePattern(rawget(_G, name))
        if p and text:find(p) then return name end
    end
    return nil
end

-- The tooltip line type names of the client (number -> name).
local function lineTypeNames()
    local out = {}
    local enum = _G.Enum and Enum.TooltipDataLineType
    if type(enum) == "table" then
        for name, v in pairs(enum) do if type(v) == "number" then out[v] = name end end
    end
    if not out[ENCHANT_LINE] then out[ENCHANT_LINE] = "ItemEnchantmentPermanent" end
    return out
end

local function enchantLine()
    local enum = _G.Enum and Enum.TooltipDataLineType
    local v = type(enum) == "table" and enum.ItemEnchantmentPermanent
    return type(v) == "number" and v or ENCHANT_LINE
end

-- The restriction now, as one text (auras are secret in combat and in encounters).
local function restrictionNow()
    local parts = {}
    local okC, combat = pcall(call, "InCombatLockdown")
    parts[#parts + 1] = ("InCombatLockdown %s"):format(okC and show(combat) or "?")
    if fn("C_RestrictedActions.IsAddOnRestrictionActive") then
        for _, k in ipairs({ { 0, "Combat" }, { 1, "Encounter" } }) do
            local ok, v = pcall(C_RestrictedActions.IsAddOnRestrictionActive, k[1])
            parts[#parts + 1] = ("%s %s"):format(k[2], ok and show(v) or "?")
        end
    end
    return table.concat(parts, ", ")
end

-- Whether an invite now could do anything but the probe (combat, lockdown): the reason or nil.
local function inviteBlockedNow()
    local ok, combat = pcall(call, "InCombatLockdown")
    if ok and combat == true then return L["im Kampf"] end
    local okL, lock = pcall(call, "C_ChatInfo.InChatMessagingLockdown")
    if okL and lock == true then return L["Kampfsperre"] end
    return nil
end

---------------------------------------------------------------------------
-- The probe: one at a time, its own event frame only while it runs
---------------------------------------------------------------------------
local run
local watcher

local function onEvent(_, event, ...)
    local P = run
    if not P then return end
    if event == "UPDATE_INSTANCE_INFO" then
        P.instanceInfo = P.instanceInfo + 1
        return
    end
    local r = P.inv[P.phase]
    if not r then return end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local who, what = ...
        if not isSecret(who) and who == ADDON then
            r.blocked[#r.blocked + 1] = ("%s %s"):format(event, isSecret(what) and L["<geheim>"] or tostring(what))
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
        r.messages[#r.messages + 1] = { event = event, secret = true }
    elseif type(text) == "string" then
        r.messages[#r.messages + 1] = { event = event, text = text, template = whichTemplate(text) }
    end
end

local function listen(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", onEvent)
    end
    for _, e in ipairs(WATCH) do
        -- pcall: a client without the event must not stop the probe
        if on then pcall(watcher.RegisterEvent, watcher, e) else pcall(watcher.UnregisterEvent, watcher, e) end
    end
end

local finishProbe

---------------------------------------------------------------------------
-- Functions, group state, templates
---------------------------------------------------------------------------
local function sectionFunctions(P)
    local R = P.R
    K.section(R, L["Gruppe: Funktionen"])
    for _, group in ipairs(GT.FUNCTIONS) do
        local lack = {}
        for _, path in ipairs(group[2]) do
            if not fn(path) then lack[#lack + 1] = path end
        end
        if #lack == 0 then
            add(R, "OK", group[1], L["alle %d vorhanden"]:format(#group[2]))
        else
            add(R, FEHLT, group[1], L["%d von %d fehlen: %s"]:format(#lack, #group[2], table.concat(lack, ", ")))
        end
    end
    check(R, L["Gruppe jetzt"], function()
        local function v(path, ...)
            local f = fn(path)
            if not f then return L["fehlt"] end
            local ok, x = pcall(f, ...)
            return ok and show(x) or "?"
        end
        return "WERT", ("IsInGroup %s, IsInRaid %s, UnitIsGroupLeader %s, UnitIsGroupAssistant %s, CanInvite %s, AllowedToDoPartyConversion(true) %s"):format(
            v("IsInGroup"), v("IsInRaid"), v("UnitIsGroupLeader", "player"), v("UnitIsGroupAssistant", "player"),
            v("C_PartyInfo.CanInvite"), v("C_PartyInfo.AllowedToDoPartyConversion", true))
    end)
    for _, name in ipairs(GT.TEMPLATES) do
        local t = rawget(_G, name)
        if type(t) == "string" and not isSecret(t) then
            add(R, "WERT", name, show(t))
        else
            add(R, FEHLT, name, show(t))
        end
    end
end

---------------------------------------------------------------------------
-- Own buffs (and a player target's): readable, secret, long ones
---------------------------------------------------------------------------
local function auraText(a)
    if isSecret(a) or type(a) ~= "table" then return L["<geheim>"] end
    local left
    local exp, dur = a.expirationTime, a.duration
    if not isSecret(exp) and type(exp) == "number" and exp > 0 then left = math.floor(exp - GetTime() + 0.5) end
    return L["%s, Zauber %s, Symbol %s, Dauer %s, Rest %s, Quelle %s, Stapel %s"]:format(show(a.name), show(a.spellId), show(a.icon),
        show(dur), left and ("%d s"):format(left) or "-", show(a.sourceUnit), show(a.applications))
end

-- Reads the helpful auras of unit: { n, secret, list, long }.
local function readAuras(unit)
    local out = { n = 0, secret = 0, list = {}, long = {} }
    for i = 1, MAX_AURAS do
        local a = call("C_UnitAuras.GetAuraDataByIndex", unit, i, "HELPFUL")
        if a == nil then break end
        out.n = out.n + 1
        local secret = isSecret(a) or type(a) ~= "table" or isSecret(a.spellId)
        if secret then out.secret = out.secret + 1 end
        if #out.list < SHOW_AURAS then out.list[#out.list + 1] = a end
        local dur = not secret and a.duration
        if not isSecret(dur) and type(dur) == "number" and dur >= LONG_AURA then out.long[#out.long + 1] = a end
    end
    return out
end

local function sectionAuras(P)
    local R = P.R
    K.section(R, L["Auren"])
    check(R, "C_Secrets", function()
        if not fn("C_Secrets.ShouldAurasBeSecret") then return "WERT", L["%s fehlt"]:format("C_Secrets") end
        local okH, has = pcall(call, "C_Secrets.HasSecretRestrictions")
        local okA, auras = pcall(call, "C_Secrets.ShouldAurasBeSecret")
        local okI, index = pcall(call, "C_Secrets.ShouldUnitAuraIndexBeSecret", "player", 1, "HELPFUL")
        return "WERT", ("HasSecretRestrictions %s, ShouldAurasBeSecret %s, ShouldUnitAuraIndexBeSecret(player, 1) %s"):format(
            okH and show(has) or "?", okA and show(auras) or "?", okI and show(index) or "?")
    end)
    add(R, "WERT", L["Sperren jetzt"], restrictionNow())
    check(R, L["Eigene Buffs"], function()
        local a = readAuras("player")
        P.auras = a
        local mark = a.n > 0 and a.secret == 0 and "OK" or "WERT"
        return mark, L["%d gelesen, %d davon geheim"]:format(a.n, a.secret)
    end)
    local a = P.auras
    if a then
        for i, aura in ipairs(a.list) do add(R, "WERT", L["Buff %d"]:format(i), auraText(aura)) end
        if a.n > #a.list then add(R, "WERT", L["Weitere"], L["%d weitere nicht gezeigt"]:format(a.n - #a.list)) end
        if #a.long > 0 then
            local names = {}
            for _, aura in ipairs(a.long) do names[#names + 1] = ("%s (%s)"):format(show(aura.name), show(aura.spellId)) end
            add(R, "WERT", L["Lange Buffs (Fläschchen, Elixier, Essen?)"], table.concat(names, ", "))
        else
            add(R, "WERT", L["Lange Buffs (Fläschchen, Elixier, Essen?)"], L["keine ab %d Minuten: ein Fläschchen oder Essen nehmen und neu prüfen"]:format(LONG_AURA / 60))
        end
    end
    -- a player in the target: are other players' buffs readable (raiders without Amisia)?
    check(R, L["Ziel##Selbsttest"], function()
        local okE, exists = pcall(call, "UnitExists", "target")
        local okP, player = pcall(call, "UnitIsPlayer", "target")
        local okU, me = pcall(call, "UnitIsUnit", "target", "player")
        if not (okE and exists == true and okP and player == true) or (okU and me == true) then
            return "WERT", L["kein Spieler im Ziel (für die Buffs anderer: einen Spieler anwählen und neu prüfen)"]
        end
        local okV, visible = pcall(call, "UnitIsVisible", "target")
        local t = readAuras("target")
        local names = {}
        for i = 1, math.min(3, #t.list) do names[#names + 1] = show(t.list[i].name) end
        return t.n > 0 and t.secret == 0 and "OK" or "WERT", L["sichtbar %s, %d Buffs gelesen, %d geheim%s"]:format(okV and show(visible) or "?",
            t.n, t.secret, #names > 0 and (": " .. table.concat(names, ", ")) or "")
    end)
end

---------------------------------------------------------------------------
-- Durability, item level, enchants
---------------------------------------------------------------------------
local function sectionDurability(P)
    local R = P.R
    K.section(R, L["Haltbarkeit"])
    local low, lowName, empty, without = nil, nil, {}, 0
    for _, s in ipairs(slots()) do
        local okL, link = pcall(call, "GetInventoryItemLink", "player", s.inv)
        local label = ("%s (%d)"):format(s.name, s.inv)
        if okL and link == nil then
            empty[#empty + 1] = s.name
        else
            check(R, label, function()
                local cur, max = call("GetInventoryItemDurability", s.inv)
                if isSecret(cur) or isSecret(max) then return "WERT", L["<geheim>"] end
                if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
                    without = without + 1
                    return "WERT", L["ohne Haltbarkeit"]
                end
                local pct = math.floor(cur / max * 100 + 0.5)
                if not low or pct < low then low, lowName = pct, s.name end
                return "WERT", ("%d/%d (%d %%)"):format(cur, max, pct)
            end)
        end
    end
    P.durability = low
    if low then
        add(R, "OK", L["Niedrigste"], ("%d %% (%s)"):format(low, lowName))
    else
        add(R, "WERT", L["Niedrigste"], L["keine Haltbarkeit gelesen"])
    end
    P.empty = empty
    add(R, "WERT", L["Leere Plätze"], #empty > 0 and table.concat(empty, ", ") or L["keine"])
end

local function sectionGear(P)
    local R = P.R
    K.section(R, L["Ausrüstung"])
    check(R, "GetAverageItemLevel", function()
        local avg, equipped, pvp = call("GetAverageItemLevel")
        if not isSecret(equipped) and type(equipped) == "number" then P.ilvl = equipped end
        return type(equipped) == "number" and "OK" or "WERT", L["Schnitt %s, angelegt %s, PvP %s"]:format(show(avg), show(equipped), show(pvp))
    end)
    if not fn("C_TooltipInfo.GetInventoryItem") then
        add(R, FEHLT, "C_TooltipInfo.GetInventoryItem", L["fehlt"])
    end
    local names, wanted = lineTypeNames(), enchantLine()
    local seen, inLink, asLine, both, read = {}, 0, 0, 0, 0
    for _, s in ipairs(slots()) do
        local okL, link = pcall(call, "GetInventoryItemLink", "player", s.inv)
        if okL and type(link) == "string" and not isSecret(link) then
            check(R, ("%s (%d)"):format(s.name, s.inv), function()
                local id = tonumber(link:match("item:%-?%d+:(%-?%d*)") or "") or 0
                if id ~= 0 then inLink = inLink + 1 end
                local lineText, lineCount = nil, 0
                if fn("C_TooltipInfo.GetInventoryItem") then
                    local data = call("C_TooltipInfo.GetInventoryItem", "player", s.inv)
                    if isSecret(data) then return "WERT", L["Tooltipdaten geheim"] end
                    local lines = type(data) == "table" and type(data.lines) == "table" and data.lines or {}
                    if #lines > 0 then read = read + 1 end
                    for _, line in ipairs(lines) do
                        local kind = type(line) == "table" and line.type
                        if not isSecret(kind) and type(kind) == "number" then
                            seen[kind] = (seen[kind] or 0) + 1
                            if kind == wanted then
                                lineCount = lineCount + 1
                                if not lineText and not isSecret(line.leftText) then lineText = line.leftText end
                            end
                        end
                    end
                end
                if lineCount > 0 then asLine = asLine + 1 end
                if lineCount > 0 and id ~= 0 then both = both + 1 end
                return "WERT", L["Verzauberung im Link %s, Zeile Typ %d: %s"]:format(id ~= 0 and tostring(id) or L["keine"], wanted,
                    lineCount > 0 and show(lineText) or L["keine"])
            end)
        end
    end
    local kinds = {}
    for kind in pairs(seen) do kinds[#kinds + 1] = kind end
    table.sort(kinds)
    local parts = {}
    for _, kind in ipairs(kinds) do parts[#parts + 1] = ("%d %s x%d"):format(kind, names[kind] or "?", seen[kind]) end
    add(R, "WERT", L["Zeilenarten gesehen"], #parts > 0 and table.concat(parts, ", ") or L["keine"])
    P.enchants = { link = inLink, line = asLine, both = both, read = read }
    add(R, (inLink == asLine and inLink == both) and "OK" or "WERT", L["Verzauberungen"],
        L["%d im Itemlink, %d als Zeile Typ %d, %d beides; Tooltipdaten von %d Items"]:format(inLink, asLine, wanted, both, read))
end

---------------------------------------------------------------------------
-- Talent points
---------------------------------------------------------------------------
local function sectionTalents(P)
    local R = P.R
    K.section(R, L["Talentpunkte"])
    local T = ns.Talents
    if not T or not T.Available or not T.Available() then
        add(R, "WERT", L["Freie Punkte"], L["keine Talentdaten"])
        return
    end
    check(R, L["Freie Punkte"], function()
        local plan, info = T.Live()
        if not plan then return "WERT", show(info) end
        if type(info.free) == "number" then
            P.free = info.free
            return "OK", L["frei %s, ausgegeben %s, gesamt %s"]:format(show(info.free), show(info.spent), show(info.total))
        end
        return "WERT", L["frei unbekannt, ausgegeben %s (GetTreeCurrencyInfo ohne Angabe)"]:format(show(info.spent))
    end)
    add(R, "WERT", "UnitCharacterPoints", fn("UnitCharacterPoints") and L["da"] or L["fehlt"])
end

---------------------------------------------------------------------------
-- The two invites (check 11) and the raid IDs, written at the end
---------------------------------------------------------------------------
local function invite(P, phase)
    local r = { messages = {}, blocked = {} }
    P.inv[phase] = r
    P.phase = phase
    local why = inviteBlockedNow()
    if why then
        r.skipped = why
        return
    end
    if not fn("C_PartyInfo.InviteUnit") then
        r.missing = true
        return
    end
    local ok, result = pcall(C_PartyInfo.InviteUnit, GT.NAME)
    r.called, r.ok, r.result = true, ok, result
end

-- The word for one invite in the chat summary.
local function inviteWord(r)
    if not r then return L["nicht geprüft"] end
    if r.skipped then return L["übersprungen (%s)"]:format(r.skipped) end
    if r.missing then return L["fehlt"] end
    if #r.blocked > 0 then return L["blockiert"] end
    if not r.ok then return L["Fehler"] end
    for _, m in ipairs(r.messages) do
        if m.template == "ERR_BAD_PLAYER_NAME_S" then return L["Spieler nicht gefunden"] end
    end
    if #r.messages > 0 then return L["andere Meldung"] end
    return L["keine Antwort"]
end

local function writeInvite(P, phase, title, how)
    local R, r = P.R, P.inv[phase]
    K.section(R, title)
    add(R, "WERT", L["Aufruf"], how)
    if not r then
        add(R, "WERT", L["Einladen"], L["nicht geprüft"])
        return
    end
    if r.skipped then
        add(R, "WERT", L["Einladen"], L["übersprungen (%s): außerhalb des Kampfes neu prüfen"]:format(r.skipped))
        return
    end
    if r.missing then
        add(R, FEHLT, "C_PartyInfo.InviteUnit", L["fehlt"])
        return
    end
    if r.ok then
        add(R, "OK", ('C_PartyInfo.InviteUnit("%s")'):format(GT.NAME), L["aufgerufen, Rückgabe %s"]:format(show(r.result)))
    else
        add(R, "FEHLER", ('C_PartyInfo.InviteUnit("%s")'):format(GT.NAME), cut(tostring(r.result)))
    end
    if #r.messages == 0 then
        add(R, "WERT", L["Antwort"], L["keine Systemmeldung"])
    end
    for _, m in ipairs(r.messages) do
        if m.secret then
            add(R, "WERT", m.event, L["<geheim>"])
        else
            local fits = m.template and L[" (passt zu %s)"]:format(m.template) or L[" (keine bekannte Vorlage)"]
            add(R, m.template == "ERR_BAD_PLAYER_NAME_S" and "OK" or "WERT", m.event, show(m.text) .. fits)
        end
    end
    if #r.blocked > 0 then
        add(R, "FEHLER", L["Blockiert"], table.concat(r.blocked, "; "))
    else
        add(R, "OK", L["Blockiert"], L["nichts (ADDON_ACTION_BLOCKED / _FORBIDDEN für Amisia)"])
    end
end

local function sectionSaved(P)
    local R = P.R
    K.section(R, L["Raid-IDs"])
    if P.asked == nil then
        add(R, FEHLT, "RequestRaidInfo", L["fehlt"])
    elseif P.asked ~= true then
        add(R, "FEHLER", "RequestRaidInfo", cut(tostring(P.asked)))
    else
        add(R, P.instanceInfo > 0 and "OK" or "WERT", "UPDATE_INSTANCE_INFO", P.instanceInfo > 0
            and L["%d-mal nach RequestRaidInfo"]:format(P.instanceInfo) or L["nicht gekommen (nach %d s)"]:format(GT.DELAY + GT.WAIT))
    end
    local n = 0
    check(R, "GetNumSavedInstances", function()
        local v = call("GetNumSavedInstances")
        n = not isSecret(v) and tonumber(v) or 0
        return "WERT", show(v)
    end)
    P.saved = n
    local now = time()
    for i = 1, math.min(n, MAX_SAVED) do
        check(R, ("GetSavedInstanceInfo(%d)"):format(i), function()
            local name, id, reset, difficulty, locked, extended, _, isRaid, maxPlayers, diffName, numEncounters, progress, _, mapID = call("GetSavedInstanceInfo", i)
            local when = "-"
            if not isSecret(reset) and type(reset) == "number" and reset > 0 then
                when = L["%s (in %.1f Stunden)"]:format(date("%Y-%m-%d %H:%M", now + reset), reset / 3600)
            end
            return "WERT", L["%s, ID %s, Instanz %s, Schwierigkeit %s %s, %s Spieler, Raid %s, gesperrt %s, verlängert %s, Bosse %s/%s, Reset %s"]:format(
                show(name), show(id), show(mapID), show(difficulty), show(diffName), show(maxPlayers), show(isRaid), show(locked), show(extended),
                show(progress), show(numEncounters), when)
        end)
    end
    if n > MAX_SAVED then add(R, "WERT", L["Weitere"], L["%d weitere nicht gezeigt"]:format(n - MAX_SAVED)) end
    if n == 0 then add(R, "WERT", L["Raid-IDs"], L["keine (in einem Dungeon oder Raid einen Boss töten, dann neu prüfen)"]) end
    if fn("GetNumSavedWorldBosses") then
        check(R, "GetNumSavedWorldBosses", function() return "WERT", show(call("GetNumSavedWorldBosses")) end)
    end
end

---------------------------------------------------------------------------
-- The end
---------------------------------------------------------------------------
local function summary(P)
    local a = P.auras
    local buffs = a and L["%d (%d geheim)"]:format(a.n, a.secret) or L["nicht gelesen"]
    local e = P.enchants
    local enchants = e and L["%d im Link, %d als Zeile"]:format(e.link, e.line) or L["nicht gelesen"]
    return L["Gruppen-Prüfung: Einladen aus dem Tastendruck %s, aus einem Timer %s; %d Raid-IDs; Buffs %s; Haltbarkeit %s; Itemstufe %s; Verzauberungen %s; freie Talentpunkte %s; %d Problem(e). Bericht im Fenster."]:format(
        inviteWord(P.inv.key), inviteWord(P.inv.timer), P.saved or 0, buffs, P.durability and ("%d %%"):format(P.durability) or "?",
        P.ilvl and ("%.1f"):format(P.ilvl) or "?", enchants, P.free and tostring(P.free) or "?", #P.R.problems)
end

finishProbe = function(P)
    if P.finished then return end
    P.finished = true
    P.phase = nil
    local R = P.R
    local ok, err = pcall(writeInvite, P, "key", L["11 Einladen aus dem Tastendruck"], L["im Tastendruck des Befehls"])
    if not ok then add(R, "FEHLER", L["Ablauf"], cut(tostring(err))) end
    ok, err = pcall(writeInvite, P, "timer", L["11 Einladen ohne Tastendruck"], L["aus einem C_Timer.After (kein Tastendruck)"])
    if not ok then add(R, "FEHLER", L["Ablauf"], cut(tostring(err))) end
    ok, err = pcall(sectionSaved, P)
    if not ok then add(R, "FEHLER", L["Ablauf"], cut(tostring(err))) end
    listen(false)
    if run == P then run = nil end
    R = K.finish(R, L["Amisia-Gruppen-Prüfung %s | Client %s | %s"])
    GT.last = R
    ST.ShowText(R.text, function() GT.Start() end)
    ns.msg(summary(P))
end

---------------------------------------------------------------------------
-- The start (the slash command, or "Erneut prüfen")
---------------------------------------------------------------------------
function GT.Start()
    if run and not run.finished and GetTime() - run.at < STALE then
        ns.msg(L["Gruppen-Prüfung läuft schon."])
        return
    end
    local P = { R = K.newReport(), inv = {}, at = GetTime(), instanceInfo = 0 }
    run = P
    listen(true)
    -- inside the key press: the first invite, then the question for the raid IDs
    invite(P, "key")
    if fn("RequestRaidInfo") then
        local ok, err = pcall(call, "RequestRaidInfo")
        P.asked = ok or err
    end
    -- what needs no answer is read now
    for _, body in ipairs({ sectionFunctions, sectionAuras, sectionDurability, sectionGear, sectionTalents }) do
        local ok, err = pcall(body, P)
        if not ok then add(P.R, "FEHLER", L["Abschnitt"], cut(tostring(err))) end
    end
    ns.msg(L["Gruppen-Prüfung läuft (etwa %d s) ..."]:format(GT.DELAY + GT.WAIT))
    C_Timer.After(GT.DELAY, function()
        if P.finished then return end
        local ok, err = pcall(invite, P, "timer")
        if not ok then add(P.R, "FEHLER", L["Ablauf"], cut(tostring(err))) end
        C_Timer.After(GT.WAIT, function() finishProbe(P) end)
    end)
end
