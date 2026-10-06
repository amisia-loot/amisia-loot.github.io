-- /amisia selbsttest: the report has every section and a mark on every line; names, ranks, the
-- packing round trip, the waypoint only on request; a failing check says FEHLER with its text, a
-- missing function FEHLT; the box is read-only; the short variant prints only problems; nothing
-- goes to chat or other players; Latin-1 only.
local ST = NS.SelfTest
assert(ST and ST.Run and ST.Show and ST.Short, "the self-test module loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

local function latin1(text, what)
    for lead in text:gmatch("[\192-\255]") do assert(lead:byte() <= 195, "beyond Latin-1 in " .. what) end
end

-- the stub leaves out client functions no other test needs; here the client has them all
local function fill(path, value)
    local t, parts = _G, {}
    for p in path:gmatch("[^%.]+") do parts[#parts + 1] = p end
    for i = 1, #parts - 1 do
        t[parts[i]] = t[parts[i]] or {}
        t = t[parts[i]]
    end
    if t[parts[#parts]] == nil then t[parts[#parts]] = value end
end
for _, path in ipairs(ST.REQUIRED) do fill(path, function() end) end
for _, name in ipairs(ST.OBJECTS) do fill(name, {}) end
-- the professions functions answer as a client with a recipe, a description and the favor currency
fill("C_TradeSkillUI.GetRecipeSchematic", function() return { name = "Kupferarmschienen",
    reagentSlotSchematics = { { reagents = { { itemID = 2840 } }, quantityRequired = 2 } } } end)
fill("C_Spell.GetSpellName", function() return "Kupferarmschienen" end)
fill("C_Spell.GetSpellDescription", function() return "Errichtet ein Schleifrad." end)
fill("C_CurrencyInfo.GetCurrencyInfo", function() return { name = "Händlergunst", quantity = 0 } end)
for _, path in ipairs(ST.PROF_FUNCTIONS) do fill(path, function() end) end
Enum.ItemClass = { Tradegoods = 7, Reagent = 5, Recipe = 9 }

-- a world to look at: a raid, a guild with ranks, a map, a worn item, a weekly reset
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur Eisherz", class = "SHAMAN", rank = 1 } }
STUB.guild = { { name = "Vuloo", rank = 2 }, { name = "Fraktur Eisherz", rank = 1 } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.weekReset = 3 * 86400 + 3600
STUB.maps[1411] = { name = "Durotar", world = { 1, 0, 0, 1000, 1000 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.25, y = 0.5 }
STUB.facing = 1.25
local link = STUB.item(100, "Lederhose der Wildnis", 2)
STUB.items[100].stats = { ITEM_MOD_STAMINA_SHORT = 10, ITEM_MOD_NEW_THING_SHORT = 3 }
STUB.worn[7] = link
_G.LOOT_ITEM_PUSHED = "%s bekommt: %s."
_G.ITEM_MIN_SKILL = "Benötigt %s (%d)"

-- what the client shows passively: an own echo, a foreign sender, a whisper and its echo
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t2.3.0", "RAID", "Vuloo-Realm", "", 0, 0, "", 0)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t2.3.0", "RAID", "Fraktur Eisherz", "", 0, 0, "", 0)
STUB.fire("CHAT_MSG_ADDON", "Fremd", "x", "RAID", "Jemand", "", 0, 0, "", 0)
STUB.fire("CHAT_MSG_WHISPER", "!sr", "Fraktur Eisherz-Realm")
STUB.fire("CHAT_MSG_WHISPER_INFORM", "hallo", "Fraktur Eisherz")

-- the character's values (section "Werte"): a level 60 human warrior with every stat function
STUB.level = 60
_G.UnitRace = function() return "Mensch", "Human", 1 end
_G.UnitHealthMax = function() return 4321 end
_G.UnitPowerMax = function(_, kind) return kind == 0 and 0 or 100 end
local STATS = { { 120, 150, 30, 0 }, { 80, 95, 15, 0 }, { 110, 260, 150, 0 }, { 30, 31, 1, 0 }, { 45, 50, 5, 0 } }
_G.UnitStat = function(_, i) local s = STATS[i]; return s[1], s[2], s[3], s[4] end
_G.GetAttackPowerForStat = function(i, v) return i == 1 and v * 2 or 0 end
_G.GetCritChanceFromAgility = function() return 4.75 end
_G.GetCritChance = function() return 12.3456789 end
_G.GetRangedCritChance = function() return 5 end
_G.GetSpellCritChance = function(school) return school / 10 end
_G.GetDodgeChance = function() return 7.5 end
_G.GetParryChance = function() return 5 end
_G.GetBlockChance = function() return 5 end
_G.UnitAttackPower = function() return 500, 40, 0 end
_G.UnitRangedAttackPower = function() return 100, 0, 0 end
_G.GetManaRegen = function() return 0, 0 end
_G.UnitArmor = function() return 3000, 3200, 3200, 200, 0 end
_G.CR_HIT_MELEE, _G.CR_CRIT_MELEE, _G.CR_DEFENSE_SKILL, _G.CR_EXPERTISE = 6, 9, 2, 24
_G.GetCombatRating = function(id) return ({ [6] = 20, [9] = 28, [2] = 15, [24] = 0 })[id] end
_G.GetCombatRatingBonus = function(id) if id == 24 then error("keine Waffenkunde") end return ({ [6] = 2, [9] = 2, [2] = 10 })[id] end

local chatBefore, triesBefore = #STUB.chat, #STUB.addonTries
local setsBefore = STUB.waypoint.sets

NS.Dispatch("selbsttest")
local D = ST.Frame()
assert(D and D:IsShown(), "the dialog shows")
local text = D.area.box:GetText()
assert(type(text) == "string" and #text > 2000, "a full report: " .. #tostring(text))

-- every section, the head and the result line
for _, title in ipairs({ "Client", "Sperren jetzt", "Namen", "Addon-Nachrichten und Packen", "Gilde", "Woche, Karte, Wegpunkt", "Loot",
                         "Atlanten", "Vorlagen", "Client-Funktionen", "Ereignisse", "Item-Konstanten", "Werte", "Berufe", "Gespeicherte Daten" }) do
    assert(has(text, "== " .. title .. " =="), "section " .. title)
end
assert(text:find("^Amisia%-Selbsttest " .. NS.VERSION:gsub("%.", "%%.") .. " | Client 1%.60%.1 %(70205%)"), "head line")
assert(text:find("\nErgebnis: %d+ OK, %d+ FEHLT, %d+ FEHLER, %d+ WERT"), "result line")

-- every line under a section carries a mark
local inSection = false
for line in (text .. "\n"):gmatch("(.-)\n") do
    if line:find("^== ") then
        inSection = true
    elseif inSection and line ~= "" then
        local mark = line:match("^(%u+)%s")
        assert(mark == "OK" or mark == "FEHLT" or mark == "WERT" or mark == "FEHLER", "marked line: " .. line)
    end
end

-- names: both values of UnitName, the roster, the senders as they came
assert(has(text, 'WERT   UnitName("player"): "Vuloo", nil'), "UnitName")
assert(has(text, 'GetRaidRosterInfo(2): "Fraktur Eisherz"'), "roster name")
assert(has(text, 'CHAT_MSG_ADDON eigenes Echo: "Vuloo-Realm" (RAID)'), "own echo")
assert(has(text, 'CHAT_MSG_ADDON fremder Absender: "Fraktur Eisherz" (RAID)'), "foreign sender, the foreign prefix ignored")
assert(has(text, 'CHAT_MSG_WHISPER Absender: "Fraktur Eisherz-Realm"'), "whisper sender")
assert(has(text, 'CHAT_MSG_WHISPER_INFORM Ziel: "Fraktur Eisherz"'), "whisper echo")
-- lockdowns at the time of the test
assert(has(text, "WERT   C_ChatInfo.InChatMessagingLockdown: false"))
assert(has(text, "IsAddOnRestrictionActive(1 Encounter): false") and has(text, "IsAddOnRestrictionActive(5 Chat): false"))
-- addon messages: the registration results, the packing round trip with sizes
assert(has(text, 'OK     Präfixe: Amisia = 0, AmisiaD = 0'), "prefix results")
assert(has(text, "OK     C_EncodingUtil: alle sechs Funktionen"))
assert(text:find("OK     SerializeCBOR: %d+ Bytes"), "CBOR size")
assert(text:find("OK     EncodeBase64: %d+ Zeichen, %d+ Teile zu 200"), "Base64 size")
assert(has(text, "OK     Zurück (Base64, Deflate, CBOR): gleich"), "round trip")
-- guild: club roster, rank flags per rank, officer rights
assert(has(text, "OK     C_Club Gildenliste: Club 77, 2 Mitglieder; du: \"Vuloo\", Rang 2"), "club roster")
assert(has(text, 'WERT   Rang 1: "Gildenmeister": 24 Rechte, [22] Offiziersrang = true'), "rank 1 flags")
assert(has(text, 'WERT   Rang 3: "Veteran": 24 Rechte, [22] Offiziersrang = false'), "rank 3 flags")
assert(has(text, "WERT   C_GuildInfo.CanEditOfficerNote: true"))
-- week, map, facing; no waypoint without the word
assert(has(text, "C_DateAndTime.GetSecondsUntilWeeklyReset: 262800 s"), "weekly reset")
assert(has(text, "WERT   C_Map.CanSetUserWaypointOnMap: Karte 1411: true"))
assert(has(text, "WERT   C_Map.GetPlayerMapPosition: 0.250, 0.500"))
assert(has(text, "WERT   GetPlayerFacing: 1.250"))
assert(has(text, "WERT   Wegpunkt setzen: nicht versucht"))
assert(STUB.waypoint.sets == setsBefore, "no waypoint set")
-- loot
assert(has(text, "WERT   C_PartyInfo.GetLootMethod: 0 Freeforall"), "loot method")
assert(has(text, "WERT   C_PartyInfo.GetAvailableLootMethods: fehlt"))
-- atlases and templates of the stub client are all there
assert(text:find("OK     Atlanten: (%d+) von %1 vorhanden"), "atlases")
assert(has(text, "OK     PortraitFrameTemplate: mit TitleContainer"), "portrait frame")
assert(has(text, "OK     SharedButtonSmallTemplate"), "red button")
-- client functions: ChatEdit_InsertLink is the alias the stub client lacks
assert(has(text, "WERT   Chat-Link-Alias: ChatEdit_InsertLink fehlt, ChatFrameUtil.InsertLink da"))
assert(has(text, "WERT   Ereignisse: nicht prüfbar"), "no event check without C_EventUtils")
assert(text:find("OK     Funktionen: alle %d+ vorhanden"), "every client function")
assert(text:find("OK     Objekte: alle %d+ vorhanden"), "every client object")
assert(not text:find("\nFEHLT ") and not text:find("\nFEHLER "), "a complete client has no problem:\n" .. text)
-- item constants and the stat keys of a worn item
assert(has(text, "OK     Enum.ItemClass: Tradegoods 7, Reagent 5"), "item classes")
assert(has(text, 'WERT   ITEM_MIN_SKILL: "Benötigt %s (%d)"'))
assert(has(text, "WERT   ITEM_REQ_SKILL: fehlt"))
assert(has(text, "ITEM_MOD_NEW_THING_SHORT ITEM_MOD_STAMINA_SHORT; unbekannt: ITEM_MOD_NEW_THING_SHORT"), "stat keys")
-- the values: one WERT line each, a missing function without a problem, and the machine line on top
assert(has(text, 'WERT   UnitRace: "Mensch", "Human"'), "race")
assert(has(text, "WERT   UnitStat(1 Stärke): Basis, Wert, plus, minus: 120, 150, 30, 0"), "strength")
assert(has(text, "WERT   GetAttackPowerForStat(1, 150): 300"), "attack power from strength")
assert(has(text, "WERT   GetSpellCritChanceFromIntellect: nicht vorhanden"), "missing: a WERT line")
assert(has(text, "WERT   GetCritChance: 12.346") and has(text, "WERT   GetSpellCritChance(7): 0.700"))
assert(has(text, "WERT   UnitArmor: Basis, wirksam, Rüstung, plus, minus: 3000, 3200, 3200, 200, 0"))
assert(has(text, "WERT   CR_HIT_MELEE (6): Wertung, Prozent: 20, 2"), "hit rating")
assert(has(text, "WERT   CR_EXPERTISE (24): Wertung, Prozent: 0, Fehler: ") and has(text, "keine Waffenkunde"), "an error stays a WERT line")
assert(text:find("WERT   CR%-Konstanten nicht vorhanden: CR_HIT_RANGED, [^\n]*CR_BLOCK\n"), "the constants the client lacks")
local values = text:match("\n(AMISIA%-WERTE [^\n]*)\n")
assert(values, "the machine line in the head:\n" .. text:sub(1, 400))
assert(values:find("^AMISIA%-WERTE 1 WARRIOR 60 race=Human hp=4321 mana=0 str=120,150,30,0 agi=80,95,15,0 sta=110,260,150,0 "
    .. "int=30,31,1,0 spi=45,50,5,0 apstr=300 apagi=0 apsta=0 apint=0 apspi=0 critagi=4.75 crit=12.3457 rcrit=5 "
    .. "sc2=0.2 sc3=0.3 sc4=0.4 sc5=0.5 sc6=0.6 sc7=0.7 dodge=7.5 parry=5 block=5 ap=500,40,0 rap=100,0,0 regen=0,0 "
    .. "armor=3000,3200,3200,200,0 hm=20,2 cm=28,2 def=15,10 exp=0,$"), values)
assert(not values:find("critint") and not values:find("  "), "nothing for a missing function")
assert(text:find("^[^\n]*\nErgebnis:[^\n]*\nAMISIA%-WERTE "), "right under the result line")
-- saved data
assert(text:find("WERT   Größe %(geschätzt%): etwa [%d%.]+ KB in %d+ Einträgen; größte: "), "saved data size")
assert(has(text, "WERT   Raids: 0 Raids"))
assert(text:find("WERT   Quellen%-Sammler: %d+ Quests, %d+ Händler, %d+ Weltdrop%-NPCs, [%d%.]+ KB; gelernt 0"), "collector line")
for _, path in ipairs({ "GetTitleText", "GetMerchantItemInfo" }) do local found = false; for _, p in ipairs(ST.REQUIRED) do found = found or p == path end; assert(found, path) end
local hasProgress = false; for _, e in ipairs(ST.EVENTS) do hasProgress = hasProgress or e == "QUEST_PROGRESS" end; assert(hasProgress, "QUEST_PROGRESS listed")

-- nothing went to chat or to other players
assert(#STUB.chat == chatBefore, "no chat message")
assert(#STUB.addonTries == triesBefore, "no addon message")

-- the box is read-only: typing puts the report back
D.area.box:SetText("kaputt")
D.area.box.scripts.OnTextChanged(D.area.box, true)
assert(D.area.box:GetText() == text, "the report stays")

-- Latin-1 only, in the report and in the files
latin1(text, "the report")
for _, file in ipairs({ "SelfTest.lua", "Pages/About.lua", "Comm.lua" }) do
    local fh = assert(io.open(ADDON_DIR .. "/" .. file, "rb"))
    local src = fh:read("*a")
    fh:close()
    latin1(src, file)
end

-- a check that raises reports its text; a missing function is FEHLT; the rest goes on
_G.GetRealZoneText = function() error("Zone kaputt") end
_G.GetPlayerFacing = nil
_G.C_EventUtils = { IsEventValid = function(e) return e ~= "BOSS_KILL" end }
local R = ST.Run()
assert(has(R.text, "FEHLER GetRealZoneText: ") and has(R.text, "Zone kaputt"), "error text")
assert(has(R.text, "FEHLT  GetPlayerFacing: GetPlayerFacing fehlt"), "missing in a check")
assert(R.text:find("FEHLT  Funktionen: 1 von %d+ fehlen: GetPlayerFacing\n"), "missing in the function list")
assert(R.text:find("FEHLT  Ereignisse: 1 von %d+ fehlen: BOSS_KILL\n"), "unknown event")
assert(has(R.text, "== Gespeicherte Daten =="), "later sections still run")
assert(#R.problems >= 3, "problems listed")
assert(has(R.text, "\nProbleme:\n  [Client] FEHLER GetRealZoneText"), "problems at the top")

-- the short variant: only problems, in the own chat frame
local before = #STUB.messages
NS.Dispatch("selbsttest kurz")
local said = {}
for i = before + 1, #STUB.messages do said[#said + 1] = STUB.messages[i] end
assert(#said == 1 + #R.problems, "headline and one line per problem: " .. #said)
assert(has(said[1], "Selbsttest: " .. #R.problems .. " Problem(e)"), said[1])
for i = 2, #said do
    assert(said[i]:find("^  %[") and (has(said[i], "FEHLT") or has(said[i], "FEHLER")), "only problems: " .. said[i])
    latin1(said[i], "the chat lines")
end
assert(#STUB.chat == chatBefore and #STUB.addonTries == triesBefore, "still nothing sent")

-- with the word the waypoint is set at the own position (the only change the test makes)
NS.Dispatch("selbsttest wegpunkt")
assert(STUB.waypoint.sets == setsBefore + 1, "waypoint set once")
assert(STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1411, "on the current map")
assert(STUB.waypoint.superTracked, "guide arrow on")
assert(has(D.area.box:GetText(), "OK     Wegpunkt setzen: Ergebnis true, gesetzt true, Wegweiser true"))

-- a second run does not make the template frames again
local made = 0
local create = _G.CreateFrame
_G.CreateFrame = function(...) made = made + 1; return create(...) end
ST.Run()
_G.CreateFrame = create
assert(made == 0, "template frames are made once: " .. made)

-- the About page has the button; the help lists the command
D:Hide()
NS.ShowPage("about")
local about = NS.AboutPageFrame()
assert(about.selfTest, "button on the About page")
about.selfTest:Click()
assert(ST.Frame():IsShown(), "the button opens the report")
local listed = false
for _, line in ipairs(NS.SlashHelpLines(false)) do
    if has(line, "/amisia selbsttest [kurz] [wegpunkt]") then listed = true end
end
assert(listed, "help lists the command")
