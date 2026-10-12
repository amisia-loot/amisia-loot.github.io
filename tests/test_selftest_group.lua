-- /amisia selbsttest gruppe: the group probe (raid check spec 2026-10-12, lineup checks 10, 11, 13)
-- with a stubbed client. It looks up the group, raid ID, aura and gear functions, invites the name
-- nobody has once inside the key press and once from a timer (the server answers "player not
-- found"), reports a blocked invite, asks for the raid IDs and lists them, reads the own buffs (and
-- secret ones), the durability, the item level, the enchants (link and tooltip line type 15) and the
-- free talent points; it skips the invites in combat, copes with a client that lacks the functions,
-- invites nobody else and sends nothing to chat or other players.
local ST = NS.SelfTest
local GT = ST.Group
assert(GT and GT.Start, "the group probe loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function report() return ST.Frame().area.box:GetText() end
local function lastMsg() return STUB.messages[#STUB.messages] end
local function sectionOf(text, title) return text:match("== " .. title:gsub("%p", "%%%0") .. " ==\n(.-)\n\n") or text:match("== " .. title:gsub("%p", "%%%0") .. " ==\n(.*)$") end

_G.ERR_BAD_PLAYER_NAME_S = "Spieler '%s' nicht gefunden."
_G.ERR_INVITE_PLAYER_S = "Ihr habt %s eingeladen, Eurer Gruppe beizutreten."
_G.ERR_DECLINE_GROUP_S = "%s lehnt Eure Gruppeneinladung ab."
_G.ERR_ALREADY_IN_GROUP_S = "%s ist bereits in einer Gruppe."
_G.ERR_GROUP_FULL = "Eure Gruppe ist voll."
_G.ERR_JOINED_GROUP_S = "%s schließt sich der Gruppe an."
_G.ERR_RAID_MEMBER_ADDED_S = "%s ist dem Schlachtzug beigetreten."
Enum.TooltipDataLineType.ItemEnchantmentPermanent = 15
Enum.TooltipDataLineType.ItemName = 22
Enum.TooltipDataLineType.None = 0

-- The stub client: every call is counted; an invite answers with the system message of the name.
local W
local function makeClient(opts)
    opts = opts or {}
    W = { invites = {}, inSlash = false, requested = 0 }
    C_PartyInfo.InviteUnit = function(name)
        W.invites[#W.invites + 1] = { name = name, inSlash = W.inSlash }
        if opts.blockTimer and not W.inSlash then
            STUB.fire("ADDON_ACTION_BLOCKED", "Amisia", "C_PartyInfo.InviteUnit()")
            STUB.fire("ADDON_ACTION_BLOCKED", "AnderesAddon", "C_PartyInfo.InviteUnit()")
            return
        end
        C_Timer.After(0.3, function() STUB.fire("CHAT_MSG_SYSTEM", ERR_BAD_PLAYER_NAME_S:format(name)) end)
    end
    C_PartyInfo.ConvertToRaid = function() error("ConvertToRaid called") end
    C_PartyInfo.CanInvite = function() return true end
    C_PartyInfo.AllowedToDoPartyConversion = function() return false end
    C_PartyInfo.PromoteToAssistant = function() error("PromoteToAssistant called") end
    _G.PromoteToAssistant = C_PartyInfo.PromoteToAssistant
    _G.SetRaidSubgroup = function() error("SetRaidSubgroup called") end
    _G.SwapRaidSubgroup = function() error("SwapRaidSubgroup called") end
    _G.UnitIsGroupLeader = function() return false end
    _G.UnitIsGroupAssistant = function() return false end
    _G.DoReadyCheck = function() error("DoReadyCheck called") end
    _G.GetReadyCheckStatus = function() return nil end
    _G.ConfirmReadyCheck = function() error("ConfirmReadyCheck called") end
    _G.RequestRaidInfo = function()
        W.requested = W.requested + 1
        C_Timer.After(0.5, function() STUB.fire("UPDATE_INSTANCE_INFO") end)
    end
    local saved = opts.saved or {
        { "Molten Core", 123456789012, 3 * 86400 + 3600, 9, true, false, 0, true, 40, "40 Spieler", 10, 4, false, 409 },
        { "Onyxias Hort", 98765, 86400, 9, false, false, 0, true, 40, "40 Spieler", 1, 1 },
    }
    _G.GetNumSavedInstances = function() return #saved end
    _G.GetSavedInstanceInfo = function(i) return unpack(saved[i]) end
    _G.GetNumSavedWorldBosses = function() return 0 end
    local auras = opts.auras or {
        { name = "Fläschchen der Titanen", spellId = 17626, icon = 134842, duration = 7200, expirationTime = GetTime() + 5000, sourceUnit = "player", applications = 0 },
        { name = "Satt", spellId = 18192, icon = 136000, duration = 900, expirationTime = GetTime() + 600, sourceUnit = "player", applications = 0 },
        { name = "Arkane Intelligenz", spellId = 10157, icon = 135932, duration = 1800, expirationTime = GetTime() + 100, sourceUnit = "party1", applications = 0 },
    }
    _G.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, i, filter)
            assert(filter == "HELPFUL", "helpful auras only")
            if unit == "player" then return auras[i] end
            if unit == "target" then return (opts.targetAuras or {})[i] end
        end,
        GetBuffDataByIndex = function() end,
        GetPlayerAuraBySpellID = function() end,
    }
    _G.C_Secrets = {
        HasSecretRestrictions = function() return true end,
        ShouldAurasBeSecret = function() return opts.secretAuras and true or false end,
        ShouldUnitAuraIndexBeSecret = function() return opts.secretAuras and true or false end,
    }
    local dur = opts.durability or { [1] = { 55, 60 }, [5] = { 30, 100 }, [16] = { 90, 90 } }
    STUB.worn = opts.worn or {
        [1] = "|cffa335ee|Hitem:16921:2545::::::::60:::::|h[Halo of Transcendence]|h|r",
        [5] = "|cffa335ee|Hitem:16923:1891::::::::60:::::|h[Robes of Transcendence]|h|r",
        [11] = STUB.link(19140, "Cauterizing Band"),
        [16] = "|cffa335ee|Hitem:18608:0::::::::60:::::|h[Benediction]|h|r",
    }
    _G.GetInventoryItemDurability = function(slot)
        local d = dur[slot]
        if d then return d[1], d[2] end
        return nil, nil
    end
    _G.GetAverageItemLevel = function() return 61.25, 58.5, 58.5 end
    C_TooltipInfo.GetInventoryItem = function(unit, slot)
        assert(unit == "player")
        local link = STUB.worn[slot]
        if not link then return nil end
        local lines = { { type = 22, leftText = link:match("%[(.-)%]") }, { type = 0, leftText = "Seelengebunden" } }
        local enchant = tonumber(link:match("item:%-?%d+:(%-?%d*)") or "")
        if enchant and enchant ~= 0 then lines[#lines + 1] = { type = 15, leftText = "Verzaubert: +8 Willenskraft" } end
        return { lines = lines }
    end
    W.dispatch = function(text)
        W.inSlash = true
        NS.Dispatch(text)
        W.inSlash = false
    end
    return W
end

-- 1. alone, out of combat: both invites answered "player not found", nothing blocked
STUB.messages = {}
makeClient()
W.dispatch("selbsttest gruppe")
assert(has(lastMsg(), "Gruppen-Prüfung läuft"), "started: " .. tostring(lastMsg()))
assert(#W.invites == 1 and W.invites[1].inSlash and W.invites[1].name == "Niemand Nirgends", "the first invite runs inside the key press")
assert(W.requested == 1, "RequestRaidInfo asked once")
STUB.tick(10)
assert(#W.invites == 2 and not W.invites[2].inSlash and W.invites[2].name == "Niemand Nirgends", "the second invite runs from a timer")
local text = report()
assert(ST.Frame():IsShown(), "the report window shows")
assert(has(text, "Amisia-Gruppen-Prüfung " .. NS.VERSION .. " | Client "), text)
for _, title in ipairs({ "Gruppe: Funktionen", "Auren", "Haltbarkeit", "Ausrüstung", "Talentpunkte", "11 Einladen aus dem Tastendruck",
                         "11 Einladen ohne Tastendruck", "Raid-IDs" }) do
    assert(has(text, "== " .. title .. " =="), "section " .. title .. "\n" .. text)
end
assert(has(text, "OK     Einladen, Umwandeln, Sortieren, Assistent: alle 10 vorhanden"), text)
assert(has(text, "OK     Bereitschaftscheck: alle 3 vorhanden"), text)
assert(has(text, "OK     Raid-IDs: alle 4 vorhanden"), text)
assert(has(text, "OK     Auren: alle 5 vorhanden"), text)
assert(has(text, "OK     Ausrüstung: alle 4 vorhanden"), text)
assert(has(text, "CanInvite true, AllowedToDoPartyConversion(true) false"), text)
assert(has(text, [[WERT   ERR_BAD_PLAYER_NAME_S: "Spieler '%s' nicht gefunden."]]), text)
-- auras
assert(has(text, "HasSecretRestrictions true, ShouldAurasBeSecret false"), text)
assert(has(text, "OK     Eigene Buffs: 3 gelesen, 0 davon geheim"), text)
assert(has(text, 'WERT   Buff 1: "Fläschchen der Titanen", Zauber 17626, Symbol 134842, Dauer 7200, Rest 5000 s, Quelle "player", Stapel 0'), text)
assert(has(text, 'Lange Buffs (Fläschchen, Elixier, Essen?): "Fläschchen der Titanen" (17626), "Satt" (18192), "Arkane Intelligenz" (10157)'), text)
assert(has(text, "kein Spieler im Ziel"), text)
-- durability: per worn item, the lowest, the empty slots
local dura = sectionOf(text, "Haltbarkeit")
assert(dura and has(dura, "WERT   Kopf (1): 55/60 (92 %)") and has(dura, "WERT   Brust (5): 30/100 (30 %)")
    and has(dura, "WERT   Finger (11): ohne Haltbarkeit") and has(dura, "OK     Niedrigste: 30 % (Brust)"), tostring(dura))
assert(has(dura, "Leere Plätze: Hals, Schultern, Rücken"), dura)
-- gear: item level, enchants from the link and the tooltip line type 15
assert(has(text, "OK     GetAverageItemLevel: Schnitt 61.250, angelegt 58.500, PvP 58.500"), text)
assert(has(text, 'WERT   Kopf (1): Verzauberung im Link 2545, Zeile Typ 15: "Verzaubert: +8 Willenskraft"'), text)
assert(has(text, "WERT   Waffenhand (16): Verzauberung im Link keine, Zeile Typ 15: keine"), text)
assert(has(text, "Zeilenarten gesehen: 0 None x4, 15 ItemEnchantmentPermanent x2, 22 ItemName x4"), text)
assert(has(text, "OK     Verzauberungen: 2 im Itemlink, 2 als Zeile Typ 15, 2 beides; Tooltipdaten von 4 Items"), text)
-- the invites
local key = sectionOf(text, "11 Einladen aus dem Tastendruck")
assert(key and has(key, 'OK     C_PartyInfo.InviteUnit("Niemand Nirgends"): aufgerufen')
    and has(key, [[OK     CHAT_MSG_SYSTEM: "Spieler 'Niemand Nirgends' nicht gefunden." (passt zu ERR_BAD_PLAYER_NAME_S)]])
    and has(key, "OK     Blockiert: nichts"), tostring(key))
local timer = sectionOf(text, "11 Einladen ohne Tastendruck")
assert(timer and has(timer, "aus einem C_Timer.After (kein Tastendruck)") and has(timer, "(passt zu ERR_BAD_PLAYER_NAME_S)")
    and has(timer, "OK     Blockiert: nichts"), tostring(timer))
-- raid IDs
local ids = sectionOf(text, "Raid-IDs")
assert(ids and has(ids, "OK     UPDATE_INSTANCE_INFO: 1-mal nach RequestRaidInfo") and has(ids, "WERT   GetNumSavedInstances: 2"), tostring(ids))
assert(has(ids, 'WERT   GetSavedInstanceInfo(1): "Molten Core", ID 123456789012, Instanz 409, Schwierigkeit 9 "40 Spieler", 40 Spieler, Raid true, gesperrt true, verlängert false, Bosse 4/10, Reset '), ids)
assert(has(ids, "(in 73.0 Stunden)"), ids)
assert(not has(text, "Probleme:"), text)
local sum = lastMsg()
assert(has(sum, "Gruppen-Prüfung: Einladen aus dem Tastendruck Spieler nicht gefunden, aus einem Timer Spieler nicht gefunden; 2 Raid-IDs; Buffs 3 (0 geheim); Haltbarkeit 30 %; Itemstufe 58.5; Verzauberungen 2 im Link, 2 als Zeile;"), sum)
assert(has(sum, "0 Problem(e). Bericht im Fenster."), sum)

-- 2. a second start while one runs is refused
STUB.messages = {}
makeClient()
W.dispatch("selbsttest gruppe")
W.dispatch("selftest group")
assert(has(lastMsg(), "Gruppen-Prüfung läuft schon."), tostring(lastMsg()))
assert(#W.invites == 1, "the refused start invites nobody")
STUB.tick(10)

-- 3. the client blocks the invite from the timer: FEHLER for Amisia only, the summary says so
STUB.messages = {}
makeClient({ blockTimer = true })
W.dispatch("selftest group")
STUB.tick(10)
text = report()
timer = sectionOf(text, "11 Einladen ohne Tastendruck")
assert(timer and has(timer, "FEHLER Blockiert: ADDON_ACTION_BLOCKED C_PartyInfo.InviteUnit()") and not has(timer, "AnderesAddon")
    and has(timer, "keine Systemmeldung"), tostring(timer))
assert(has(lastMsg(), "aus einem Timer blockiert"), lastMsg())

-- 4. in combat: no invite at all, secret auras counted, the target's buffs read
STUB.messages = {}
local secretAura = { name = "x", spellId = 1 }
STUB.secret[secretAura] = true
makeClient({ secretAuras = true, auras = { secretAura }, targetAuras = { { name = "Segen der Macht", spellId = 19838, duration = 300 } } })
STUB.combat = true
STUB.target = { name = "Vulo Pala", player = true }
_G.UnitExists = function(u) return u == "player" or (u == "target" and STUB.target ~= nil) end
_G.UnitIsPlayer = function(u) return u == "player" or (u == "target" and STUB.target and STUB.target.player) or false end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitIsVisible = function() return true end
W.dispatch("selbsttest gruppe")
STUB.tick(10)
STUB.combat = false
assert(#W.invites == 0, "no invite in combat")
text = report()
assert(has(text, "übersprungen (im Kampf): außerhalb des Kampfes neu prüfen"), text)
assert(has(text, "WERT   Eigene Buffs: 1 gelesen, 1 davon geheim") and has(text, "WERT   Buff 1: <geheim>"), text)
assert(has(text, 'OK     Ziel: sichtbar true, 1 Buffs gelesen, 0 geheim: "Segen der Macht"'), text)
assert(has(lastMsg(), "Einladen aus dem Tastendruck übersprungen (im Kampf)"), lastMsg())

-- 5. a client without the functions: FEHLT lines, no error, still a report
STUB.messages = {}
makeClient()
C_PartyInfo.InviteUnit, _G.SetRaidSubgroup, _G.RequestRaidInfo, _G.C_UnitAuras = nil, nil, nil, nil
_G.GetInventoryItemDurability, _G.GetAverageItemLevel, C_TooltipInfo.GetInventoryItem = nil, nil, nil
W.dispatch("selbsttest gruppe")
STUB.tick(10)
text = report()
assert(has(text, "FEHLT  Einladen, Umwandeln, Sortieren, Assistent: 2 von 10 fehlen: C_PartyInfo.InviteUnit, SetRaidSubgroup"), text)
assert(has(text, "FEHLT  RequestRaidInfo: fehlt") and has(text, "FEHLT  C_PartyInfo.InviteUnit: fehlt"), text)
assert(has(text, "FEHLT  Eigene Buffs: C_UnitAuras.GetAuraDataByIndex fehlt"), text)
assert(has(text, "FEHLT  GetAverageItemLevel: GetAverageItemLevel fehlt"), text)
assert(not has(text, "\nFEHLER "), text)
assert(has(lastMsg(), "Problem(e). Bericht im Fenster."), lastMsg())

-- nothing went to other players
for _, m in ipairs(STUB.addon or {}) do error("an addon message went out: " .. tostring(m.text)) end
