-- Best items per slot for the player (Bis.lua): three options per slot, ownership (worn, bags,
-- bank, also without a bank visit), exclusions by item, boss and place, phase, faction, crafted
-- items with "only my professions", tier pieces for their class, rings and trinkets, two-hand
-- against main hand plus off hand and the weapon switch, the gain against the weaker ring, the
-- guessed and the chosen spec, rows filled from the client, "here" in an instance and in a zone
-- with its parents, the place picker, the cache and the throttled bag scan, settings and commands.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function ids(list)
    local out = {}
    for i, e in ipairs(list or {}) do out[i] = e.id end
    return table.concat(out, ",")
end

-- the spec comes from the Forever planner's choice when the character is first used
AmisiaDB.settings.gear = { specs = { WARRIOR = "tank" } }
STUB.class, STUB.level = "WARRIOR", 70
local spec, guessed = NS.BisSpec()
assert(spec == "tank" and not guessed, "the planner's spec is taken over: " .. tostring(spec))
local me = NS.BisChar()
assert(me and me.class == "WARRIOR" and me.spec == "tank" and AmisiaDB.bis.chars["Vuloo"] == me, "the character entry")
-- back to guessing: the tree with the most points
NS.BisSetSpec(nil)
STUB.talents = { 31, 30, 0 }
spec, guessed = NS.BisSpec()
assert(spec == "dps" and guessed, "arms or fury is the dps spec: " .. tostring(spec))
STUB.talents = { 0, 5, 41 }
NS.Fire("BIS_CHANGED")   -- talent changes arrive as events; the guess is cached until one
STUB.fire("CHARACTER_POINTS_CHANGED")
assert(NS.BisSpec() == "tank", "protection is the tank spec")
STUB.talents = nil
STUB.fire("PLAYER_TALENT_UPDATE")
assert(NS.BisSpec() == "dps", "without talents the first spec of the weights")
STUB.talents = { 31, 30, 0 }
STUB.fire("ACTIVE_TALENT_GROUP_CHANGED")
NS.BisSetSpec("dps")
assert(select(2, NS.BisSpec()) == false, "a chosen spec is no guess")

---------------------------------------------------------------------------
-- a small TBC data set; the client describes every item
---------------------------------------------------------------------------
STUB.areas[3457], STUB.areas[3714] = "Karazhan", "Die Zerschmetterten Hallen"
local S = {
    { "X", "Karazhan", "Prinz Malchezaar", 532, 3457, 1, 0 },            -- 1
    { "X", "Karazhan", "Moroes", 532, 3457, 1, 0 },                      -- 2
    { "X", "Gruul's Lair", "Gruul", 565, 3923, 1, 0 },                   -- 3
    { "X", "Black Temple", "Illidan", 564, 3959, 3, 0 },                 -- 4
    { "D", "Shattered Halls", "Kargath", nil, 540, 3714, 0 },            -- 5
    { "D", "Shattered Halls", "Kargath", nil, 540, 3714, 1 },            -- 6
    { "F", "The Sha'tar", 7, 935, "" },                                  -- 7
    { "V", "G'eras", 111, "", "Abzeichen", 1 },                          -- 8
    { "C", "tailoring", 375 },                                           -- 9
    { "C", "blacksmithing", 375 },                                       -- 10
    { "X", "Black Temple", "Mutter Shahraz", 564, 3959, 1, 31101 },      -- 11 (a token)
    { "V", "Horde Quartermaster", 111, "H", "Quartiermeister", 1 },      -- 12
    { "W", nil, 70, 73, 1945 },                                          -- 13
}
local I = {}
local LINKS = {}
local function gear(id, name, loc, stats, sources, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.bind, it.minLevel = stats, o.bind or 1, 70
    if sources then
        I[id] = { "", 0, 0, 0, 0, 0, 0, o.mask or 0, 0, 0 }
        for _, n in ipairs(sources) do I[id][#I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
-- head: warriors score 2 per strength
gear(105, "Helm BT", "HEAD", str(45), { 4 })
gear(101, "Helm Prinz", "HEAD", str(40), { 1 })
gear(102, "Helm Gruul", "HEAD", str(35), { 3 })
gear(103, "Helm Heroisch", "HEAD", str(30), { 6 })
gear(104, "Helm Moroes", "HEAD", str(25), { 2, 8 })
gear(106, "Helm Horde", "HEAD", str(50), { 12 })
gear(117, "Helm Welt", "HEAD", str(38), { 13 })
gear(118, "Helm Normal", "HEAD", str(22), { 5 })
-- chest: crafted bind on pickup and bind on equip, a raid drop, a tier piece of the warrior
gear(107, "Brust BoP", "CHEST", str(60), { 10 }, { bind = 1 })
gear(108, "Brust BoE", "CHEST", str(55), { 10 }, { bind = 2 })
gear(109, "Brust Kara", "CHEST", str(30), { 1 })
gear(110, "Brust T6", "CHEST", str(70), { 11 }, { mask = Gear.CLASS_BIT.WARRIOR })
-- rings and trinkets
gear(111, "Ring A", "FINGER", str(40), { 1 }, { sub = 0 })
gear(112, "Ring B", "FINGER", str(30), { 2 }, { sub = 0 })
gear(113, "Ring C", "FINGER", str(20), { 3 }, { sub = 0 })
gear(114, "Ring alt", "FINGER", str(10), nil, { sub = 0 })
gear(115, "Schmuck A", "TRINKET", { ITEM_MOD_ATTACK_POWER_SHORT = 50 }, { 1 }, { sub = 0 })
gear(116, "Schmuck B", "TRINKET", { ITEM_MOD_ATTACK_POWER_SHORT = 30 }, { 3 }, { sub = 0 })
-- weapons: a two-hander beats main hand plus off hand
local function wpn(dps, s) return { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = dps, ITEM_MOD_STRENGTH_SHORT = s } end
gear(120, "Zweihand", "2HWEAPON", wpn(130, 50), { 4 }, { classID = 2, sub = 1 })
gear(121, "Axt", "WEAPON", wpn(80, 20), { 1 }, { classID = 2, sub = 0 })
gear(122, "Schwert", "WEAPON", wpn(70, 0), { 3 }, { classID = 2, sub = 7 })
gear(123, "Alte Zweihand", "2HWEAPON", wpn(50, 0), nil, { classID = 2, sub = 1 })
gear(124, "Stoffkappe", "HEAD", { ITEM_MOD_INTELLECT_SHORT = 30 }, { 1 }, { sub = 1 })

NS.GEAR = { game = "tbc", cap = 70, built = "test-bis", S = S, I = I, Z = {} }
Gear._reset()
assert(Gear.Available() and Gear.Game() == "tbc")

-- options
local o = NS.BisOpts()
assert(o.class == "WARRIOR" and o.spec == "dps" and o.level == 70 and o.faction == "A", "class, spec, level, faction")
assert(o.sources.X and o.sources.H and o.sources.D and o.sources.F and o.sources.V and o.sources.C and o.sources.W, "sources on")
assert(not o.sources.A and not o.sources.P, "auction house and PvP off by default")
assert(o.phase == 0 and o.prof == "all" and o.exclude == me.ex, "phase all, all professions, the character's exclusions")
STUB.level = 73
assert(NS.BisOpts().level == 70, "capped at the data's level")
STUB.level = 70

---------------------------------------------------------------------------
-- three options per slot
---------------------------------------------------------------------------
local r = NS.BisTargets()
assert(ids(r.HEAD) == "105,101,117", "three heads, best first: " .. ids(r.HEAD))
assert(r.HEAD[1].score == 90 and r.HEAD[1].gain == 90 and r.HEAD[1].upgrade, "nothing worn: all gain")
assert(NS.GEAR.I[101][1] == "HEAD" and NS.GEAR.I[101][2] == 4, "rows filled from the client")
assert(ids(r.CHEST) == "110,107,108", "the tier piece for its class, then crafted: " .. ids(r.CHEST))
assert(r.upgrades > 0)
-- cached until something changes
assert(NS.BisTargets() == r, "the same result while nothing changed")

-- the tier piece is the warrior's alone; a paladin sees the crafted ones first
local po = NS.BisOpts()
po.class, po.spec = "PALADIN", "ret"
assert(ids(NS.BisTargets(po).CHEST) == "107,108,109", "no warrior tier for a paladin: " .. ids(NS.BisTargets(po).CHEST))

-- phase: Black Temple is phase 3
assert(NS.Set("bis.phase", 1))
r = NS.BisTargets()
assert(ids(r.HEAD) == "101,117,102", "phase 1 drops Black Temple: " .. ids(r.HEAD))
NS.Reset("bis.phase")
-- faction: the Horde quartermaster only for the Horde
STUB.faction = "Horde"
assert(ids(NS.BisTargets().HEAD) == "106,105,101", "horde sees its vendor")
STUB.faction = "Alliance"
assert(ids(NS.BisTargets().HEAD) == "105,101,117", "and the alliance does not")

-- professions: "only mine" keeps bind on equip, drops bind on pickup without the skill
assert(NS.Set("bis.prof", "mine"))
STUB.skills = { { name = "Berufe", header = true }, { name = "Schneiderei", rank = 375 } }
STUB.fire("SKILL_LINES_CHANGED")
local sk = NS.BisSkills()
assert(sk and sk.tailoring == 375 and not sk.blacksmithing, "own professions read")
r = NS.BisTargets()
assert(ids(r.CHEST) == "110,108,109", "bind on pickup needs the profession: " .. ids(r.CHEST))
STUB.skills = { { name = "Schmiedekunst", rank = 300 } }
STUB.fire("SKILL_LINES_CHANGED")
assert(ids(NS.BisTargets().CHEST) == "110,108,109", "and its skill")
STUB.skills = { { name = "Blacksmithing", rank = 375 } }
STUB.fire("SKILL_LINES_CHANGED")
assert(ids(NS.BisTargets().CHEST) == "110,107,108", "the English name counts too")
NS.Reset("bis.prof")

---------------------------------------------------------------------------
-- exclusions: the next option moves up; another valid source keeps an item
---------------------------------------------------------------------------
assert(NS.BisExclude("item", LINKS[105]))
assert(me.ex.item[105], "excluded by link")
r = NS.BisTargets()
assert(ids(r.HEAD) == "101,117,102", "item excluded: " .. ids(r.HEAD))
assert(NS.BisExclude("boss", "Gruul"))
assert(ids(NS.BisTargets().HEAD) == "101,117,103", "boss excluded: " .. ids(NS.BisTargets().HEAD))
assert(NS.BisExclude("place", "I:540"))
assert(ids(NS.BisTargets().HEAD) == "101,117,104", "place excluded, normal and heroic: " .. ids(NS.BisTargets().HEAD))
assert(NS.BisExclude("boss", "Prinz Malchezaar"))
assert(NS.BisExclude("boss", "Moroes"))
assert(ids(NS.BisTargets().HEAD) == "117,104", "Moroes excluded, the vendor keeps his helm: " .. ids(NS.BisTargets().HEAD))
local okBad, why = NS.BisExclude("item", "kein link")
assert(not okBad and why == "Kein Item.", "a reason for a bad item")
assert(not NS.BisExclude("thing", "x"), "unknown kind")
assert(NS.BisExclude("boss", "Moroes", false) and not me.ex.boss.Moroes, "an exclusion goes again")
assert(NS.BisClearExcludes() == 4, "four left to clear")
assert(not next(me.ex.item) and not next(me.ex.boss) and not next(me.ex.place))
assert(ids(NS.BisTargets().HEAD) == "105,101,117", "all back")

---------------------------------------------------------------------------
-- ownership: worn, bags, bank (counted at the bank or known to the client)
---------------------------------------------------------------------------
STUB.worn[1] = LINKS[105]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1)
r = NS.BisTargets()
assert(r.HEAD[1].owned == "worn" and r.HEAD[1].worn and r.state.HEAD == "done", "option 1 worn: the slot is done")
assert(r.mine.HEAD == 90 and r.HEAD[2].gain == -10 and not r.HEAD[2].upgrade, "gain against the worn helm")
assert(NS.BisOwned(105) == "worn")
-- bags, scanned once per burst of bag events
local calls = 0
local numSlots = C_Container.GetContainerNumSlots
C_Container.GetContainerNumSlots = function(bag) calls = calls + 1; return numSlots(bag) end
STUB.bags[0] = { 110 }
for _ = 1, 10 do STUB.fire("BAG_UPDATE_DELAYED") end
STUB.tick(1.1)
assert(calls == 5, "one scan of bags 0-4 for ten events: " .. calls)
assert(me.bag[110] and NS.BisOwned(110) == "bag", "seen in the bags")
r = NS.BisTargets()
assert(r.CHEST[1].owned == "bag" and r.state.CHEST == "bag" and r.CHEST[1].gain == 140, "in the bag, not worn: gain stays")
-- the bank, counted while it is open
STUB.bags[-1] = { 107 }
STUB.bags[5] = { LINKS[108] }
STUB.fire("BANKFRAME_OPENED")
assert(me.bank[107] and me.bank[108] and me.bankAt == STUB.now, "bank and bank bags counted")
assert(NS.BisOwned(107) == "bank" and NS.BisTargets().CHEST[2].owned == "bank")
STUB.bags[-1] = {}
STUB.fire("PLAYERBANKSLOTS_CHANGED"); STUB.fire("PLAYERBANKSLOTS_CHANGED")
STUB.tick(0.3)
assert(not me.bank[107] and me.bank[108], "taken out of the bank")
STUB.fire("BANKFRAME_CLOSED")
STUB.bags[5] = {}
STUB.fire("PLAYERBANKSLOTS_CHANGED"); STUB.tick(0.3)
assert(me.bank[108], "a closed bank is not read")
-- without a bank visit: the client's own count with the bank
STUB.bank[109] = 1
assert(NS.BisOwned(109) == "bank", "the client counts it in the bank")
STUB.bank[109] = nil
-- an item that left the bags falls away at the next scan
STUB.bags[0] = {}
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
assert(not me.bag[110] and NS.BisOwned(110) == nil, "gone from the bags")

-- Forever: the character bank is a set of tabs, there is no container -1
STUB.toc = 16001
_G.Enum.BankType = { Character = 0, Account = 2 }
_G.C_Bank = { FetchPurchasedBankTabIDs = function(kind) return kind == 0 and { 6, 7 } or {} end }
STUB.bags[-1] = { 113 }
STUB.bags[6] = { 112 }
STUB.bags[7] = { 111 }
STUB.fire("BANKFRAME_OPENED")
assert(me.bank[112] and me.bank[111] and not me.bank[113], "Forever reads the bank tabs, not -1")
STUB.fire("BANKFRAME_CLOSED")
STUB.toc = 20506
_G.C_Bank = nil
STUB.bags[-1], STUB.bags[6], STUB.bags[7] = nil, nil, nil
STUB.fire("BANKFRAME_OPENED"); STUB.fire("BANKFRAME_CLOSED")

---------------------------------------------------------------------------
-- rings, trinkets, weapons
---------------------------------------------------------------------------
STUB.worn[11], STUB.worn[12] = LINKS[112], LINKS[114]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 11)
r = NS.BisTargets()
assert(ids(r.FINGER1) == "111,112,113" and ids(r.FINGER2) == "112,113", "rings: the second row starts after the first pick")
assert(r.FINGER1[1].gain == 60, "a ring against the weaker worn ring: " .. tostring(r.FINGER1[1].gain))
assert(r.FINGER1[2].owned == "worn" and r.FINGER2[1].owned == "worn" and r.state.FINGER2 == "done")
assert(ids(r.TRINKET1) == "115,116" and ids(r.TRINKET2) == "116", "trinkets the same way")

-- a two-hander against main hand plus off hand
STUB.worn[16] = LINKS[121]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 16)
r = NS.BisTargets()
assert(r.plan == "2H" and r.MAINHAND[1].id == 120 and #r.OFFHAND == 0, "two-hand plan")
assert(r.MAINHAND[1].gain == 1920 - 1160, "against the worn main hand plus nothing: " .. tostring(r.MAINHAND[1].gain))
-- wearing a two-hander, a one-hand option is a weapon switch
assert(NS.BisExclude("item", 120))
STUB.worn[16] = LINKS[123]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 16)
r = NS.BisTargets()
assert(r.plan == "1H" and r.MAINHAND[1].id == 121, "one-hand plan without the two-hander")
assert(r.MAINHAND[1].switch and r.MAINHAND[1].gain == nil and r.state.MAINHAND == "switch", "a weapon switch, no number")
assert(r.OFFHAND[1].switch, "the off hand as well")
local g, why2, code = NS.BisGain(121)
assert(g == nil and why2 == "Waffenwechsel" and code == "switch", "BisGain says switch")
NS.BisClearExcludes()
STUB.worn[16] = nil
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 16)

---------------------------------------------------------------------------
-- gain, minimum gain, explanation
---------------------------------------------------------------------------
local gain, slotKey, mine = NS.BisGain(101)
assert(gain == -10 and slotKey == "HEAD" and mine == 90, "BisGain against the worn helm")
gain, slotKey = NS.BisGain(LINKS[111])
assert(gain == 60 and slotKey == "FINGER1", "a ring by link against the weaker ring")
STUB.worn[1] = gear(125, "Helm 39", "HEAD", str(39))
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1)
gain, _, mine = NS.BisGain(101)
assert(gain == 2 and mine == 78 and NS.BisIsUpgrade(gain, mine), "2 more is an upgrade at 2 %")
assert(NS.Set("bis.minGain", 5))
assert(not NS.BisIsUpgrade(gain, mine), "but not at 5 %")
assert(not NS.BisTargets().HEAD[2].upgrade, "the targets follow the setting")
NS.Reset("bis.minGain")
STUB.class = "PRIEST"
local pg, pwhy, pcode = NS.BisGain(101)
assert(pg == nil and pcode == "class" and pwhy == "Das kann dein Charakter nicht tragen.", "plate for a priest")
STUB.class = "WARRIOR"
STUB.items[126] = { name = "Stoff", quality = 1, link = STUB.link(126, "Stoff", 1), equipLoc = "", classID = 7 }
assert(select(3, NS.BisGain(126)) == "notgear", "no gear")
local lines = NS.BisExplain(101)
local joined = table.concat(lines, "\n")
assert(has(joined, "40 Stärke x 2,0 = 80"), joined)
assert(has(lines[1], "Kopf") and has(lines[1], "+2 Punkte, so viel wie 2 Angriffskraft"), lines[1])
gear(127, "Treffer", "HEAD", { ITEM_MOD_HIT_RATING_SHORT = 20 }, { 1 })
assert(has(table.concat(NS.BisExplain(127), "\n"), "Trefferwertung zählt ohne Obergrenze."), "the hit note on TBC")

---------------------------------------------------------------------------
-- here: the instance, a zone with its parents, a chosen place, the picker
---------------------------------------------------------------------------
STUB.worn[1] = nil
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1)
STUB.bags[0] = { 109 }
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
STUB.instance = { name = "Karazhan", type = "raid", id = 532 }
local place, list = NS.BisHere()
assert(place and place.key == "I:532" and place.text == "Karazhan", "here is Karazhan")
local got = ids(list)
assert(has(got, "101") and has(got, "121") and has(got, "111") and has(got, "109"), "Karazhan's upgrades: " .. got)
assert(list[#list].id == 109 and list[#list].owned == "bag", "owned at the bottom")
assert(not has(got, "102") and not has(got, "124"), "nothing from elsewhere, nothing a warrior would not take")
for i = 2, #list - 1 do assert(list[i - 1].gain >= list[i].gain, "by gain") end
-- a wish shows even without an upgrade
STUB.worn[1] = LINKS[105]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1)
_, list = NS.BisHere()
assert(not has(ids(list), "104"), "no upgrade, no wish: not listed")
me.wish[104] = { t = STUB.now, prio = 2, note = "" }
NS.Fire("BIS_CHANGED")
_, list = NS.BisHere()
local wishEntry
for _, e in ipairs(list) do if e.id == 104 then wishEntry = e end end
assert(wishEntry and wishEntry.wished, "a wish is listed")
me.wish[104] = nil
NS.Fire("BIS_CHANGED")
STUB.worn[1] = nil
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1)
-- heroic in the instance: heroic sources only
STUB.instance = { name = "Die Zerschmetterten Hallen", type = "party", id = 540, diff = 2 }
place, list = NS.BisHere()
assert(place.key == "I:540/H" and has(place.text, "heroisch") and ids(list) == "103", "heroic: " .. place.key .. " " .. ids(list))
place, list = NS.BisHere("I:540")
assert(ids(list) == "118", "normal by choice: " .. ids(list))
-- in a zone: the map and its parents up to the continent
STUB.instance = { name = "Terokkar", type = "none", id = 530 }
STUB.place.map = 1955
STUB.maps[1955] = { name = "Shattrath", parent = 1945, mapType = 3 }
STUB.maps[1945] = { name = "Wälder von Terokkar", parent = 1467, mapType = 3 }
STUB.maps[1467] = { name = "Scherbenwelt", parent = 946, mapType = 2 }
place, list = NS.BisHere()
assert(place.key == "Z:1955" and place.text == "Shattrath" and ids(list) == "117", "the world drop of the parent zone: " .. ids(list))
place, list = NS.BisHere("I:999")
assert(place.key == "I:999" and #list == 0, "an unknown place")
-- the picker: raids and dungeons, heroic as its own entry
local seen = {}
for _, p in ipairs(NS.BisPlaces()) do seen[p.key] = p.text end
assert(seen["I:532"] == "Karazhan" and seen["I:565"] == "Gruul's Lair" and seen["I:540"] == "Die Zerschmetterten Hallen", "places")
assert(seen["I:540/H"] == "Die Zerschmetterten Hallen (heroisch)", "heroic entry")
assert(not seen["Z:1945"], "zones are no picker entries")

---------------------------------------------------------------------------
-- the cache follows the exclusions
---------------------------------------------------------------------------
local r1 = NS.BisTargets()
assert(NS.BisTargets() == r1)
NS.BisExclude("item", 105)
local r2 = NS.BisTargets()
assert(r2 ~= r1 and r2.HEAD[1].id == 101, "recomputed with the new exclusion")
NS.BisClearExcludes()
assert(NS.BisTargets().HEAD[1].id == 105)

---------------------------------------------------------------------------
-- settings and commands
---------------------------------------------------------------------------
for path, want in pairs({ ["bis.tooltip"] = { "toggle", true }, ["bis.tooltipNone"] = { "toggle", false },
                          ["bis.minGain"] = { "slider", 2 }, ["bis.toast"] = { "toggle", true },
                          ["bis.toastUpgrade"] = { "toggle", true }, ["bis.toastSound"] = { "toggle", true },
                          ["bis.wishAutoRemove"] = { "toggle", true }, ["bis.phase"] = { "choice", 0 },
                          ["bis.prof"] = { "choice", "all" } }) do
    local it = NS.SettingItem(path)
    assert(it and it.type == want[1] and it.default == want[2] and it.section.key == "bis", path)
end
assert(NS.SettingItem("bis.minGain").expert, "minimum gain for experts")
assert(NS.SettingItem("bis.phase").available(), "phase on TBC")
NS.Dispatch("bis aus " .. LINKS[101])
assert(me.ex.item[101], "/amisia bis aus")
NS.Dispatch("bis zurueck")
assert(not me.ex.item[101], "/amisia bis zurueck")
STUB.messages = {}
NS.Dispatch("bis item " .. LINKS[101])
local out = table.concat(STUB.messages, "\n")
assert(has(out, "Stärke") and has(out, "Kopf") and has(out, "ITEM_MOD_STRENGTH_SHORT"), out)
NS.Dispatch("bis")
assert(AmisiaDB.settings.bis.view == "goals" and NS.CurrentPage() == "gear", "/amisia bis opens the targets")
NS.Dispatch("bis hier")
assert(AmisiaDB.settings.bis.view == "here", "/amisia bis hier")
NS.Dispatch("ziele")
assert(AmisiaDB.settings.bis.view == "goals", "alias ziele")

-- no data: no targets, no error
NS.GEAR = nil
local empty = NS.BisTargets()
assert(empty and #empty.HEAD == 0 and empty.upgrades == 0, "empty without data")
assert(select(3, NS.BisGain(101)) == "nodata")
