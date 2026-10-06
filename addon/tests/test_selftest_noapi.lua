--[[preload
STUB.noEncoding = true
_G.C_Club = nil
_G.C_RestrictedActions = nil
_G.C_DateAndTime = nil
_G.GetPlayerFacing = nil
_G.UiMapPoint = nil
_G.issecretvalue = nil
_G.C_PartyInfo = nil
C_Map.CanSetUserWaypointOnMap = nil
C_GuildInfo.GuildControlGetRankFlags = nil
C_ChatInfo.InChatMessagingLockdown = nil
STUB.missingAtlases["common-insideframe"] = true
STUB.missingTemplates["SharedButtonSmallTemplate"] = true
]]
-- A client without many of the functions: the self-test still writes every section, names what
-- is missing as FEHLT and raises nothing, also when the saved data and further functions go away
-- while it runs; nothing is sent.
local ST = NS.SelfTest
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.guild = { { name = "Vuloo", rank = 2 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.5, y = 0.5 }

NS.Dispatch("selbsttest wegpunkt")
local text = ST.Frame().area.box:GetText()
for _, title in ipairs({ "Client", "Sperren jetzt", "Namen", "Addon-Nachrichten und Packen", "Gilde", "Woche, Karte, Wegpunkt", "Loot",
                         "Atlanten", "Vorlagen", "Client-Funktionen", "Ereignisse", "Item-Konstanten", "Werte", "Gespeicherte Daten" }) do
    assert(has(text, "== " .. title .. " =="), "section " .. title)
end
assert(not text:find("\nFEHLER "), "a missing function is no error:\n" .. text)
assert(text:find("FEHLT  Funktionen: %d+ von %d+ fehlen: [^\n]*GetPlayerFacing"), "named in the function list")
assert(has(text, "FEHLT  C_EncodingUtil: fehlt"), "no packing")
assert(has(text, "FEHLT  C_RestrictedActions.IsAddOnRestrictionActive: fehlt"))
assert(has(text, "FEHLT  C_ChatInfo.InChatMessagingLockdown: C_ChatInfo.InChatMessagingLockdown fehlt"))
assert(has(text, "FEHLT  C_GuildInfo.GuildControlGetRankFlags: fehlt"))
assert(has(text, "FEHLT  C_DateAndTime.GetSecondsUntilWeeklyReset: C_DateAndTime.GetSecondsUntilWeeklyReset fehlt"))
assert(has(text, "FEHLT  C_PartyInfo.GetLootMethod"))
assert(has(text, "FEHLT  Atlas common-insideframe: nicht im Client"))
assert(has(text, "FEHLT  SharedButtonSmallTemplate: "), "missing template")
assert(has(text, "FEHLT  Wegpunkt setzen: "), "no waypoint without the functions")
assert(STUB.waypoint.sets == 0)
assert(has(text, "C_Club Gildenliste: C_Club.GetGuildClubId fehlt"))
-- the values: a client without the stat functions writes WERT lines, no problem, and a short machine line
assert(has(text, "WERT   UnitStat(1 Stärke): Basis, Wert, plus, minus: nicht vorhanden"))
assert(has(text, "WERT   GetAttackPowerForStat(1): nicht vorhanden (kein Wert)"))
assert(has(text, "WERT   GetSpellCritChance: nicht vorhanden") and has(text, "WERT   UnitArmor: Basis, wirksam, Rüstung, plus, minus: nicht vorhanden"))
assert(has(text, "WERT   CR-Konstanten nicht vorhanden: CR_HIT_MELEE, "), "no rating constant")
local werte = text:match("== Werte ==\n(.-)\n\n")
assert(werte and not werte:find("FEHLT") and not werte:find("FEHLER"), "no problem from the values:\n" .. tostring(werte))
assert(text:find("\nAMISIA%-WERTE 1 WARRIOR %?\n"), "class and an unknown level, nothing else")

-- more goes away while the client runs: the saved data, the build, the group functions
_G.AmisiaDB = nil
_G.GetBuildInfo = nil
_G.GetRaidRosterInfo = function() error("Liste geheim") end
_G.C_Texture = nil
local R = ST.Run()
assert(has(R.text, "Amisia-Selbsttest " .. NS.VERSION .. " | Client ?"), "head without the build")
assert(has(R.text, "FEHLT  AmisiaDB: keine gespeicherten Daten"))
assert(has(R.text, "FEHLER GetRaidRosterInfo(1): ") and has(R.text, "Liste geheim"))
assert(has(R.text, "FEHLT  C_Texture.GetAtlasInfo: fehlt"))
-- a stat function that raises, the class gone: still WERT lines and a machine line
_G.UnitStat = function() error("Werte geheim") end
_G.UnitClass = nil
R = ST.Run()
assert(has(R.text, "WERT   UnitStat(2 Beweglichkeit): Basis, Wert, plus, minus: Fehler: ") and has(R.text, "Werte geheim"))
assert(has(R.text, "WERT   UnitClass: nicht vorhanden") and R.text:find("\nAMISIA%-WERTE 1 %? %?\n"), "class and level unknown")
assert(not R.text:find("%[Werte%]"), "no problem from the values")
ST.Short()
assert(#STUB.chat == 0 and #STUB.addonTries == 0, "nothing sent")
