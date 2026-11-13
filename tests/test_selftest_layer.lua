-- /amisia selbsttest layer (F-192, D-124) with a stubbed client: it looks up the functions, reads the
-- zone, the target's GUID, the current layer and the name plates in sight (creatures, players' pets,
-- secret GUIDs, the zone ids and what they say), reports this session's reads, the layer changes without
-- a zone change (in a group or not, back and forth), the trace of Amisia's calls and the chat channels;
-- then it invites the name nobody has from a timer (the server answers "player not found"), calls
-- AcceptGroup and LeaveParty once each while alone (they do nothing) and says whether the client
-- blocked Amisia. In a group the two empty calls are skipped, in combat all three; nothing goes to chat
-- or to another player.
local ST = NS.SelfTest
local LT, LY, SW = ST.Layer, NS.Layer, NS.LayerChange
assert(LT and LT.Start, "the layer probe loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function report() return ST.Frame().area.box:GetText() end
local function lastMsg() return STUB.messages[#STUB.messages] end
local function line(text, label)
    for l in (text .. "\n"):gmatch("(.-)\n") do
        -- the label right behind the mark ("OK     Einladen: ..."), not inside another line's text
        local rest = l:match("^%S+%s+(.*)$")
        if rest and rest:sub(1, #label + 2) == label .. ": " then return l end
    end
    return nil
end

_G.ERR_BAD_PLAYER_NAME_S = "Spieler '%s' nicht gefunden."
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.place.map = 1429
STUB.guild = { { name = "Vuloo", rank = 2 }, { name = "Anna Bergmann", rank = 3 } }
STUB.roster = {}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(15)

-- the stub client: units with GUIDs, name plates, channels, the three calls
local GUIDS, PETS, PLATES = {}, {}, {}
local stubGUID = UnitGUID
_G.UnitGUID = function(u) if GUIDS[u] ~= nil then return GUIDS[u] end return stubGUID(u) end
_G.UnitPlayerControlled = function(u) return PETS[u] == true end
_G.UnitIsOtherPlayersPet = function() return false end
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlates = function() return PLATES end
local function plates(list)
    GUIDS, PETS, PLATES = {}, {}, {}
    for i, e in ipairs(list) do
        local unit = "nameplate" .. i
        GUIDS[unit] = e[1]
        PETS[unit] = e[2] or nil
        -- one plate in the other spelling the clients know
        PLATES[i] = i == 2 and { UnitFrame = { unit = unit } } or { namePlateUnitToken = unit }
    end
end
local CALLS = { invite = {}, accept = 0, leave = 0, chat = 0, addon = 0 }
local blockInvite, blockAccept = false, false
C_PartyInfo.InviteUnit = function(name)
    CALLS.invite[#CALLS.invite + 1] = name
    if blockInvite then return STUB.fire("ADDON_ACTION_FORBIDDEN", "Amisia", "C_PartyInfo.InviteUnit()") end
    C_Timer.After(0.3, function() STUB.fire("CHAT_MSG_SYSTEM", ERR_BAD_PLAYER_NAME_S:format(name)) end)
end
_G.AcceptGroup = function()
    CALLS.accept = CALLS.accept + 1
    if blockAccept then STUB.fire("ADDON_ACTION_BLOCKED", "Amisia", "AcceptGroup()") end
end
C_PartyInfo.LeaveParty = function() CALLS.leave = CALLS.leave + 1 end
_G.StaticPopup_Hide = function() end
_G.StaticPopup_Visible = function() return nil end
_G.GetChannelList = function() return 1, "Allgemein - Wald von Elwynn", false, 2, "Handel", false end
_G.GetChannelName = function(n) if n == 1 then return 1, "Allgemein - Wald von Elwynn" end return 0, nil end
local sentBefore = #STUB.addon
local sendChat = SendChatMessage
_G.SendChatMessage = function(...) CALLS.chat = CALLS.chat + 1; if sendChat then return sendChat(...) end end

-- the rules alone
local function pl(ids, creatures)
    local kinds = 0
    for _ in pairs(ids) do kinds = kinds + 1 end
    return { creatures = creatures, kinds = kinds, ids = ids }
end
local mark, text = LT.IdVerdict(pl({ [4711] = 2 }, 2))
assert(mark == "WERT" and has(text, "zu wenige Kreaturen"), text)
mark, text = LT.IdVerdict(pl({ [4711] = 9 }, 9))
assert(mark == "OK" and has(text, "alle 9 Kreaturen") and has(text, "4711"), text)
mark, text = LT.IdVerdict(pl({ [4711] = 9, [4802] = 1 }, 10))
assert(mark == "OK" and has(text, "9 von 10") and has(text, "Zonengrenze"), text)
mark, text = LT.IdVerdict(pl({ [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 2 }, 6))
assert(mark == "FEHLER" and has(text, "kein Layer zu erkennen"), text)
mark, text = LT.IdVerdict(pl({ [1] = 5, [2] = 5 }, 10))
assert(mark == "WERT" and has(text, "keine überwiegt"), text)
local n, grouped, flips = LT.Switches({
    { at = 10, map = 1429, uid = 1 }, { at = 50, map = 1429, uid = 2, grouped = true },   -- a change in a group
    { at = 60, map = 1429, uid = 1 },                                                      -- back within a minute
    { at = 70, zone = true }, { at = 80, map = 1430, uid = 9 },                            -- another zone: no change
    { at = 500, map = 1430, uid = 8 } })
assert(n == 3 and grouped == 1 and flips == 1, ("%d %d %d"):format(n, grouped, flips))

-- a quiet client: nothing targeted, no plates; alone, so all three calls go from timers
local msgs = #STUB.messages
SlashCmdList.AMISIA("selbsttest layer")
assert(LT.Running() and #CALLS.invite == 0, "the calls come from timers, not from the key press")
assert(has(lastMsg(), "Layer-Prüfung läuft"))
SlashCmdList.AMISIA("selbsttest layer")
assert(has(lastMsg(), "läuft schon"))
STUB.tick(6)
assert(not LT.Running())
local r = report()
assert(has(r, "Amisia-Layer-Prüfung") and has(r, "== Layer: Funktionen ==") and has(r, "== Layer: Ergebnis =="))
assert(#CALLS.invite == 1 and CALLS.invite[1] == LT.NAME and CALLS.accept == 1 and CALLS.leave == 1)
assert(has(line(r, "Einladen"), "Spieler nicht gefunden") and has(line(r, "Einladen"), "OK"), line(r, "Einladen"))
assert(has(line(r, "Annehmen"), "nicht gesperrt") and has(line(r, "Verlassen"), "nicht gesperrt"))
assert(has(line(r, "Aktueller Layer"), "unbekannt"))
assert(has(line(r, "In Sicht"), "0 Plaketten"))
assert(has(line(r, "Kennung je Zonenkopie"), "zu wenige Kreaturen"))
assert(has(line(r, "Kennung folgt dem Layer"), "noch nicht gesehen"))
assert(has(line(r, "Kanäle"), "Allgemein - Wald von Elwynn") and has(line(r, "Kanäle"), "Handel"))
assert(has(line(r, 'Kanal für "Im Kanal fragen"'), "1 "))
assert(has(line(r, "Einstellungen"), "others false") and has(line(r, "Einstellungen"), "chat true"))
assert(has(r, "So prüfst du einen echten Wechsel:"))
assert(has(lastMsg(), "Einladen erlaubt, Annehmen erlaubt, Verlassen erlaubt"), lastMsg())
assert(#STUB.messages > msgs)

-- a lively place: eight creatures of one layer, one over the border, a hunter's pet, a secret GUID, a player
local secretGuid = "Creature-0-5250-0-4711-99-0FF"
STUB.secret[secretGuid] = true
local list = {}
for i = 1, 8 do list[i] = { ("Creature-0-5250-0-4711-%d-0A%d"):format(100 + i, i) } end
list[9] = { "Creature-0-5250-0-4802-300-0C1" }
list[10] = { "Creature-0-5250-0-4711-400-0D1", true }
list[11] = { secretGuid }
list[12] = { "Player-5250-00ABCDEF" }
plates(list)
for i = 1, 12 do STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i); STUB.tick(0.2) end
assert(LY.Current() == 4711, "the plates gave the layer")
STUB.targetGUID = "Creature-0-5250-0-4711-101-0A1"; STUB.fire("PLAYER_TARGET_CHANGED")
-- a change in a group without a zone change: the id follows the layer
STUB.party = true
STUB.roster = { { name = "Vuloo" }, { name = "Anna Bergmann" } }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(1)
STUB.targetGUID = "Creature-0-5250-0-5555-501-0E1"; STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = "Creature-0-5250-0-5555-502-0E2"; STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 5555)
local calls = { #CALLS.invite, CALLS.accept, CALLS.leave }
LT.Start()
STUB.tick(6)
r = report()
assert(has(line(r, "Layer: Kreatur-GUID"), "Zonen-Kennung 5555"), line(r, "Layer: Kreatur-GUID"))
assert(has(line(r, "Aktueller Layer"), "Zonen-Kennung 5555") and has(line(r, "Aktueller Layer"), "OK"))
assert(has(line(r, "Bekannte Layer dieser Zone"), "A=4711") and has(line(r, "Bekannte Layer dieser Zone"), "B=5555 hier"))
assert(has(line(r, "In Sicht"), "12 Plaketten: 9 Kreaturen, 1 von Spielern gesteuert, 1 geheim, 1 anderes"), line(r, "In Sicht"))
assert(has(line(r, "Zonen-Kennungen"), "4711 x8, 4802 x1"), line(r, "Zonen-Kennungen"))
assert(has(line(r, "Kennung je Zonenkopie"), "8 von 9 Kreaturen tragen die Kennung 4711"))
assert(has(line(r, "Gelesen"), "Ziel 3 von 3") and has(line(r, "Gelesen"), "geheime GUIDs 1"), line(r, "Gelesen"))
assert(has(line(r, "Layer-Wechsel ohne Zonenwechsel"), "1, davon 1 in einer Gruppe, 0 Hin und Her"))
assert(has(r, "Karte 1429, Zonen-Kennung 5555, in einer Gruppe") and has(r, "Karte 1429, Zonen-Kennung 4711, allein"))
assert(has(line(r, "Kennung folgt dem Layer"), "ja:") and has(line(r, "Kennung folgt dem Layer"), "OK"))
-- in a group the two empty calls are skipped: they would act on the real group
assert(#CALLS.invite == calls[1] + 1 and CALLS.accept == calls[2] and CALLS.leave == calls[3], "no accept or leave in a group")
assert(has(line(r, "Annehmen"), "übersprungen (du bist in einer Gruppe)") and has(line(r, "Verlassen"), "übersprungen"))
STUB.party, STUB.roster = nil, {}
STUB.fire("GROUP_ROSTER_UPDATE")

-- the client blocks Amisia: problems in the report and the chat line
blockInvite, blockAccept = true, true
LT.Start()
STUB.tick(6)
r = report()
assert(has(line(r, "Einladen"), "FEHLER") and has(line(r, "Einladen"), "vom Spiel gesperrt: ADDON_ACTION_FORBIDDEN C_PartyInfo.InviteUnit()"), line(r, "Einladen"))
assert(has(line(r, "Annehmen"), "vom Spiel gesperrt: ADDON_ACTION_BLOCKED AcceptGroup()"))
assert(has(line(r, "Verlassen"), "nicht gesperrt"))
assert(has(r, "Probleme:") and has(lastMsg(), "Einladen gesperrt, Annehmen gesperrt, Verlassen erlaubt"), lastMsg())
blockInvite, blockAccept = false, false

-- an open invite: AcceptGroup would take it, so it is not called
_G.StaticPopup_Visible = function(which) return which == "PARTY_INVITE" and "StaticPopup1" or nil end
calls = { #CALLS.invite, CALLS.accept, CALLS.leave }
LT.Start()
STUB.tick(6)
assert(CALLS.accept == calls[2] and CALLS.leave == calls[3] + 1 and has(line(report(), "Annehmen"), "eine Einladung ist offen"))
_G.StaticPopup_Visible = function() return nil end

-- an invite came a moment ago (another addon may have hidden its window): AcceptGroup is not called; the
-- same on a client that cannot say whether the window shows
STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd")
calls = { #CALLS.invite, CALLS.accept, CALLS.leave }
LT.Start()
STUB.tick(6)
assert(CALLS.accept == calls[2] and has(line(report(), "Annehmen"), "eine Einladung ist offen"), "an invite of the last minutes")
STUB.fire("PARTY_INVITE_CANCEL")
_G.StaticPopup_Visible = nil
LT.Start()
STUB.tick(6)
assert(CALLS.accept == calls[2] and has(line(report(), "Annehmen"), "eine Einladung ist offen"), "no way to see the window")
_G.StaticPopup_Visible = function() return nil end
-- a block of the probe's own call is not counted for the swap's calls
blockInvite = true
local blockedBefore = SW.Trace().invite.blocked
LT.Start()
STUB.tick(6)
assert(SW.Trace().invite.blocked == blockedBefore, "the probe's block is not the swap's")
blockInvite = false

-- in combat and in an instance nothing is called
STUB.combat = true
calls = { #CALLS.invite, CALLS.accept, CALLS.leave }
LT.Start()
STUB.tick(6)
r = report()
assert(#CALLS.invite == calls[1] and CALLS.accept == calls[2] and CALLS.leave == calls[3], "nothing in combat")
assert(has(line(r, "Einladen"), "übersprungen (im Kampf)") and has(lastMsg(), "übersprungen (im Kampf)"))
STUB.combat = false
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
LT.Start()
STUB.tick(6)
assert(#CALLS.invite == calls[1] and has(line(report(), "Einladen"), "übersprungen (in einer Instanz)"))
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }

-- a client without the functions: FEHLT, no error
local keepInvite, keepPlates = C_PartyInfo.InviteUnit, C_NamePlate.GetNamePlates
C_PartyInfo.InviteUnit, _G.InviteUnit, _G.AcceptGroup, C_NamePlate.GetNamePlates = nil, nil, nil, nil
LT.Start()
STUB.tick(6)
r = report()
assert(has(line(r, "Einladen"), "die Funktion fehlt") and has(line(r, "Annehmen"), "die Funktion fehlt"), line(r, "Einladen"))
assert(has(line(r, "In Sicht"), "C_NamePlate.GetNamePlates fehlt"), tostring(line(r, "In Sicht")))
assert(not has(r, "attempt to"), "no Lua error in the report")
C_PartyInfo.InviteUnit, C_NamePlate.GetNamePlates = keepInvite, keepPlates

-- nothing went to chat or to another player
assert(CALLS.chat == 0 and #STUB.addon == sentBefore, "nothing sent")
for _, name in ipairs(CALLS.invite) do assert(name == LT.NAME, "only the name nobody has is invited") end
print("layer probe: functions, plates, id verdicts, session, trace, three calls, blocked, group, combat, no functions")
