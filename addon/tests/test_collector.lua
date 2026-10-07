-- The source collector (Collector.lua): quests with giver, turn-in NPC, positions, rewards, level
-- and pre-quest; vendors with their gear, recipes and limited goods; world drops of non-boss NPCs.
-- Secret values are skipped, the switches hold, records merge the same in any order, broken saved
-- records go on load, and the caps and the byte budget hold.
local C = NS.Collect
assert(C, "the collector loads")
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.place.map = 1411
STUB.map.pos = { x = 0.5234, y = 0.4011 }
STUB.level, STUB.faction = 30, "Horde"
local TODAY = NS.DropsToday()

local function record(kind, id) return AmisiaDB.collect[kind][id] end
local function parsed(kind, id) return NS.CollectParse(kind, record(kind, id)) end

---------------------------------------------------------------------------
-- quests: offer, turn-in, follow-up
---------------------------------------------------------------------------
local reward = STUB.item(280604, "Wut des Sturms", 3)
local choice1, choice2 = STUB.item(5001, "Helm A", 2), STUB.item(5002, "Helm B", 2)
local quest = { id = 2001, title = "Die Waffen des Sturms" }
_G.GetQuestID = function() return quest.id end
_G.GetTitleText = function() return quest.title end
_G.GetNumQuestRewards = function() return #STUB.questItems.reward end
_G.GetNumQuestChoices = function() return #STUB.questItems.choice end
STUB.questItems = { reward = { reward }, choice = { choice2, choice1 } }
STUB.npc, STUB.npcGUID = "Sturmrufer Thrall", "Creature-0-3110-1-47-3344-00002E7CF2"
STUB.fire("QUEST_DETAIL")
local q = parsed("q", 2001)
assert(q, "the quest is recorded: " .. tostring(record("q", 2001)))
assert(q.title == "Die Waffen des Sturms" and q.giver == 3344 and q.gname == "Sturmrufer Thrall", "title and giver")
assert(q.gpos == "1411:5234:4011", "giver position " .. q.gpos)
assert(q.rewards[1] == 280604 and q.choices[1] == 5001 and q.choices[2] == 5002, "rewards, choices sorted")
assert(q.minlvl == 30 and q.fac == "H" and q.day == TODAY and q.ender == 0 and q.pre == 0)
assert(AmisiaDB.scan == nil or true)
-- the turn-in NPC elsewhere, then a follow-up quest of the same NPC
STUB.map.pos = { x = 0.1, y = 0.2 }
STUB.npc, STUB.npcGUID = "Grisgrind", "Creature-0-3110-1-47-4455-00002E7CF3"
STUB.fire("QUEST_PROGRESS")
STUB.fire("QUEST_COMPLETE")
STUB.fire("QUEST_TURNED_IN", 2001, 100, 0)
q = parsed("q", 2001)
assert(q.ender == 4455 and q.epos == "1411:1000:2000" and q.giver == 3344, "the turn-in NPC")
quest = { id = 2002, title = "Weiter zum Sturm" }
STUB.questItems = { reward = {}, choice = {} }
STUB.tick(5)
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2002).pre == 2001, "offered by the same NPC right after the turn-in: pre-quest")
-- another NPC, or too late: no pre-quest
quest = { id = 2003, title = "Andere Sache" }
STUB.npcGUID = "Creature-0-3110-1-47-9999-00002E7CF3"
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2003).pre == 0, "another NPC gives no pre-quest")
quest = { id = 2004, title = "Spaeter" }
STUB.npcGUID = "Creature-0-3110-1-47-4455-00002E7CF3"
STUB.tick(60)
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2004).pre == 0, "too late after the turn-in")
-- a quest from an object: negative id, no name; from an item (no npc unit): no giver
quest = { id = 2005, title = "Steckbrief" }
STUB.npc, STUB.npcGUID = "Steckbrief", "GameObject-0-3110-1-47-178000-00002E7CF3"
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2005).giver == -178000 and parsed("q", 2005).gname == "", "object giver")
quest = { id = 2006, title = "Ein seltsames Buch" }
STUB.npc, STUB.npcGUID = "Vuloo", "Player-1-1"
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2006).giver == 0 and parsed("q", 2006).gname == "", "no player name as giver")
-- the quest level from the quest log on accept (classic arguments: index, id)
_G.C_QuestLog.GetLogIndexForQuestID = function(id) return id == 2001 and 3 or nil end
_G.C_QuestLog.GetInfo = function(i) return i == 3 and { level = 34, questID = 2001 } or nil end
STUB.fire("QUEST_ACCEPTED", 3, 2001)
assert(parsed("q", 2001).qlevel == 34, "the quest level")
-- retail arguments (id only), and a fallback through the old quest log functions
_G.C_QuestLog.GetLogIndexForQuestID, _G.C_QuestLog.GetInfo = nil, nil
_G.GetQuestLogIndexByID = function(id) return id == 2002 and 5 or 0 end
_G.GetQuestLogTitle = function(i) if i == 5 then return "Weiter zum Sturm", 35 end end
STUB.fire("QUEST_ACCEPTED", 2002)
assert(parsed("q", 2002).qlevel == 35, "the quest level through GetQuestLogTitle")
-- a lower player level offered the same quest later: the lowest one stays; the faction joins
STUB.level, STUB.faction = 28, "Alliance"
quest = { id = 2001, title = "Die Waffen des Sturms" }
STUB.npc, STUB.npcGUID = "Sturmrufer Thrall", "Creature-0-3110-1-47-3344-00002E7CF2"
STUB.questItems = { reward = { reward }, choice = {} }
STUB.fire("QUEST_DETAIL")
q = parsed("q", 2001)
assert(q.minlvl == 28 and q.fac == "AH" and q.choices[2] == 5002, "lowest level, both factions, choices kept")
STUB.level, STUB.faction = 30, "Horde"

---------------------------------------------------------------------------
-- secret values: skipped, never compared
---------------------------------------------------------------------------
local before = record("q", 2001)
STUB.npcGUID = "Creature-0-3110-1-47-7777-00002E7CF2"
STUB.secret[STUB.npcGUID] = true
quest = { id = 2007, title = "Geheim" }
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2007).giver == 0, "a secret GUID gives no giver")
STUB.secret[STUB.npcGUID] = nil
STUB.secret["Geheimer Titel"] = true
quest = { id = 2008, title = "Geheimer Titel" }
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2008).title == "", "a secret title is left empty")
local secretId = 2009
STUB.secret[secretId] = true
quest = { id = secretId, title = "x" }
STUB.fire("QUEST_DETAIL")
assert(record("q", 2009) == nil, "a secret quest id: nothing")
STUB.secret[secretId] = nil
STUB.secret[0.5234] = true
STUB.map.pos = { x = 0.5234, y = 0.4 }
quest = { id = 2010, title = "Ort geheim" }
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2010).gpos == "1411", "a secret coordinate: the map only")
STUB.secret[0.5234] = nil
-- in an instance the client has no position: the map only
STUB.map.pos = nil
quest = { id = 2011, title = "Drinnen" }
STUB.fire("QUEST_DETAIL")
assert(parsed("q", 2011).gpos == "1411")
STUB.map.pos = { x = 0.5, y = 0.5 }
assert(record("q", 2001) == before, "nothing else changed")

---------------------------------------------------------------------------
-- vendors
---------------------------------------------------------------------------
local wares = {
    { link = STUB.item(6001, "Kettenhaube", 2), price = 1520, avail = -1 },
    { link = STUB.item(6002, "Brot", 1), price = 25, avail = -1 },
    { link = STUB.item(6003, "Rezept: Fisch", 2), price = 400, avail = 1 },
    { link = STUB.item(6004, "Seltenes Garn", 1), price = 1000, avail = 3 },
    { link = STUB.item(6005, "Ehrenschild", 3), price = 0, avail = -1, ext = true },
}
STUB.items[6002].equipLoc, STUB.items[6002].classID = "", 0
STUB.items[6003].equipLoc, STUB.items[6003].classID = "", 9
STUB.items[6004].equipLoc, STUB.items[6004].classID = "", 7
_G.GetMerchantNumItems = function() return #wares end
_G.GetMerchantItemLink = function(i) return wares[i] and wares[i].link end
_G.GetMerchantItemInfo = function(i)
    local w = wares[i]
    return "name", 1, w.price, 1, w.avail, true, true, w.ext and true or false
end
_G.ITEM_REQ_REPUTATION = "Benötigt %s - %s"
for i, label in ipairs({ "Hasserfüllt", "Feindselig", "Unfreundlich", "Neutral", "Freundlich", "Wohlwollend", "Respektvoll", "Ehrfürchtig" }) do
    _G["FACTION_STANDING_LABEL" .. i] = label
end
_G.C_TooltipInfo = _G.C_TooltipInfo or {}
C_TooltipInfo.GetMerchantItem = function(i)
    if i == 1 then return { lines = { { leftText = "Kettenhaube" }, { leftText = "Benötigt Orgrimmar - Wohlwollend" } } } end
    return { lines = { { leftText = "x" } } }
end
STUB.npc, STUB.npcGUID = "Grimm", "Creature-0-3110-1-47-904-00002E7CF2"
STUB.map.pos = { x = 0.25, y = 0.75 }
STUB.fire("MERCHANT_SHOW")
local v = parsed("s", 904)
assert(v and v.name == "Grimm" and v.pos == "1411:2500:7500", tostring(record("s", 904)))
assert(v.items[6001] and v.items[6001].price == 1520 and v.items[6001].flags == "" and v.items[6001].rep == "6@Orgrimmar", "gear with its reputation")
assert(v.items[6002] == nil, "bread stays out")
assert(v.items[6003] and v.items[6003].flags == "L", "a recipe in limited stock")
assert(v.items[6004] and v.items[6004].flags == "L", "limited goods are kept")
assert(v.items[6005] and v.items[6005].flags == "x", "another currency")
-- a female standing label (FACTION_STANDING_LABELn_FEMALE, where the client has them) reads the same
_G.FACTION_STANDING_LABEL7_FEMALE = "Respektvolle"
C_TooltipInfo.GetMerchantItem = function(i)
    if i == 1 then return { lines = { { leftText = "Benötigt Donnerfels - Respektvolle" } } } end
    return { lines = {} }
end
STUB.npcGUID = "Creature-0-3110-1-47-906-00002E7CF2"
STUB.fire("MERCHANT_SHOW")
assert(parsed("s", 906).items[6001].rep == "7@Donnerfels", "female label: " .. parsed("s", 906).items[6001].rep)
AmisiaDB.collect.s[906] = nil
NS.CollectMigrate(AmisiaDB)
-- Forever 1.60.1.70245 has no GetMerchantItemInfo any more: C_MerchantFrame.GetItemInfo (a table)
-- reads the same
local oldInfo = _G.GetMerchantItemInfo
_G.GetMerchantItemInfo = nil
_G.C_MerchantFrame = { GetItemInfo = function(i)
    local w = wares[i]
    return w and { name = "name", texture = 1, price = w.price, stackCount = 1, numAvailable = w.avail, isPurchasable = true,
        isUsable = true, hasExtendedCost = w.ext and true or false, isQuestStartItem = false } or nil
end }
STUB.npcGUID = "Creature-0-3110-1-47-907-00002E7CF2"
STUB.fire("MERCHANT_SHOW")
local v7 = parsed("s", 907)
assert(v7 and v7.items[6001] and v7.items[6001].price == 1520 and v7.items[6001].flags == "", "gear through C_MerchantFrame")
assert(v7.items[6002] == nil and v7.items[6003].flags == "L" and v7.items[6004].flags == "L" and v7.items[6005].flags == "x",
    "limited stock and another currency through C_MerchantFrame")
AmisiaDB.collect.s[907] = nil
NS.CollectMigrate(AmisiaDB)
_G.C_MerchantFrame, _G.GetMerchantItemInfo = nil, oldInfo
-- a merchant without an NPC id is not recorded
STUB.npcGUID = nil
STUB.fire("MERCHANT_SHOW")
local n = 0
for _ in pairs(AmisiaDB.collect.s) do n = n + 1 end
assert(n == 1)

---------------------------------------------------------------------------
-- world drops: non-boss corpses, gear and recipes of green or better
---------------------------------------------------------------------------
local green = STUB.item(7001, "Grüne Hose", 2)
local grey = STUB.item(7002, "Graues Zeug", 0)
local white = STUB.item(7003, "Weißer Stoff", 1)
local recipe = STUB.item(7004, "Rezept: Trank", 2)
STUB.items[7004].equipLoc, STUB.items[7004].classID = "", 9
local cloth = STUB.item(7005, "Seidenstoff", 2)
STUB.items[7005].equipLoc, STUB.items[7005].classID = "", 7
local wolf = "Creature-0-3110-1-47-299-00000000AA"
STUB.target, STUB.targetGUID, STUB.targetClass = "Wolf", wolf, "rare"
STUB.loot = { { link = green, src = wolf }, { link = grey, src = wolf }, { link = white, src = wolf }, { link = recipe, src = wolf },
              { link = cloth, src = wolf } }
STUB.fire("LOOT_OPENED")
local w = parsed("w", 299)
assert(w and w.name == "Wolf" and w.class == "r" and w.pos == "1411:2500:7500" and w.inst == 0, tostring(record("w", 299)))
assert(w.items[7001] == 1 and w.items[7004] == 1 and not w.items[7002] and not w.items[7003] and not w.items[7005], "only gear and recipes")
-- the same corpse again counts once; another corpse adds
STUB.fire("LOOT_OPENED")
assert(parsed("w", 299).items[7001] == 1, "one corpse once")
local wolf2 = "Creature-0-3110-1-47-299-00000000AB"
STUB.loot = { { link = green, src = wolf2 } }
STUB.fire("LOOT_OPENED")
assert(parsed("w", 299).items[7001] == 2, "a second corpse")
-- a corpse that is neither target nor mouseover: NPC id and place, no name or class
STUB.loot = { { link = green, src = "Creature-0-3110-1-47-300-00000000AC" } }
STUB.fire("LOOT_OPENED")
assert(parsed("w", 300).name == "" and parsed("w", 300).class == "")
-- by mouseover
STUB.mouseover, STUB.mouseoverGUID, STUB.mouseoverClass = "Eber", "Creature-0-3110-1-47-301-00000000AD", "elite"
STUB.loot = { { link = green, src = STUB.mouseoverGUID } }
STUB.fire("LOOT_OPENED")
assert(parsed("w", 301).name == "Eber" and parsed("w", 301).class == "e")
-- a boss stays with Drops.lua, a raid too, a secret source and chests are skipped
local isBoss = NS.DropsIsBoss
NS.DropsIsBoss = function(npc) return npc == 302 end
STUB.loot = { { link = green, src = "Creature-0-3110-1-47-302-00000000AE" } }
STUB.fire("LOOT_OPENED")
assert(record("w", 302) == nil, "a boss is not a world drop")
NS.DropsIsBoss = isBoss
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
STUB.loot = { { link = green, src = "Creature-0-3110-409-47-303-00000000AF" } }
STUB.fire("LOOT_OPENED")
assert(record("w", 303) == nil, "nothing from raids")
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.loot = { { link = green, src = "Creature-0-3110-36-47-304-00000000B0" } }
STUB.map.pos = nil
STUB.fire("LOOT_OPENED")
assert(parsed("w", 304).inst == 36 and parsed("w", 304).pos == "1411", "dungeon trash with its instance")
STUB.map.pos = { x = 0.5, y = 0.5 }
STUB.instance = { name = "Durotar", type = "none", id = 0 }
local secretSrc = "Creature-0-3110-1-47-305-00000000B1"
STUB.secret[secretSrc] = true
STUB.loot = { { link = green, src = secretSrc }, { link = green, src = "Item-0-0-0-0" }, { link = green, src = "GameObject-0-3110-1-47-306-0" } }
STUB.fire("LOOT_OPENED")
assert(record("w", 305) == nil and record("w", 306) == nil, "secret and non-creature sources skipped")
STUB.secret[secretSrc] = nil
-- a secret link in a slot: skipped
STUB.secret[green] = true
STUB.loot = { { link = green, src = "Creature-0-3110-1-47-307-00000000B2" } }
STUB.fire("LOOT_OPENED")
assert(record("w", 307) == nil)
STUB.secret[green] = nil

---------------------------------------------------------------------------
-- the switches
---------------------------------------------------------------------------
for _, k in ipairs({ "collect.quests", "collect.vendors", "collect.world", "collect.share" }) do
    assert(NS.Get(k) == true, k .. " defaults on")
end
NS.Set("collect.quests", false); NS.Set("collect.vendors", false); NS.Set("collect.world", false)
quest = { id = 2100, title = "Aus" }
STUB.npcGUID = "Creature-0-3110-1-47-3344-00002E7CF2"
STUB.fire("QUEST_DETAIL")
STUB.npcGUID = "Creature-0-3110-1-47-905-00002E7CF2"
STUB.fire("MERCHANT_SHOW")
STUB.loot = { { link = green, src = "Creature-0-3110-1-47-308-00000000B3" } }
STUB.fire("LOOT_OPENED")
assert(record("q", 2100) == nil and record("s", 905) == nil and record("w", 308) == nil, "switched off")
NS.Set("collect.quests", true); NS.Set("collect.vendors", true); NS.Set("collect.world", true)

---------------------------------------------------------------------------
-- no player names anywhere in the saved table
---------------------------------------------------------------------------
local function walk(t)
    for k, x in pairs(t) do
        if type(x) == "table" then walk(x)
        elseif type(x) == "string" then assert(not x:find("Vuloo", 1, true), "a player name stored: " .. x) end
    end
end
walk(AmisiaDB.collect)

---------------------------------------------------------------------------
-- merging: the same in any order, idempotent; strict parsing
---------------------------------------------------------------------------
local M = NS.CollectMergeRecords
local a = "100;0;10;1411:100:200;0;;5,7;;20;18;A;0;Alpha;Titel A"
local b = "101;0;12;1411:100:300;20;1411:1:1;6;8;22;16;H;55;Beta;Titel B"
local c = "99;0;0;;0;;9;;0;0;;54;;"
for _, s in ipairs({ a, b, c }) do assert(NS.CollectParse("q", s), "valid: " .. s) end
assert(M("q", a, b) == M("q", b, a), "commutative")
assert(M("q", M("q", a, b), c) == M("q", a, M("q", b, c)), "associative")
assert(M("q", a, a) == a, "idempotent")
local ab = NS.CollectParse("q", M("q", a, b))
assert(ab.day == 101 and ab.giver == 10 and ab.ender == 20 and ab.qlevel == 22 and ab.minlvl == 16 and ab.fac == "AH" and ab.pre == 55)
assert(table.concat(ab.rewards, ",") == "5,6,7" and ab.title == "Titel A")
local va, vb = "50;0;1411:1:1;10:100::,11:200:L:;", "51;0;;10:90:x:4@Ratschlag,12:5::;Händler"
assert(M("s", va, vb) == M("s", vb, va))
local vab = NS.CollectParse("s", M("s", va, vb))
assert(vab.items[10].price == 90 and vab.items[10].flags == "x" and vab.items[10].rep == "4@Ratschlag" and vab.name == "Händler")
local wa, wb = "5;0;r;1411:1:1;0;1:2,3:1;Wolf", "6;0;;;0;1:5,4:1;"
assert(M("w", wa, wb) == M("w", wb, wa) and NS.CollectParse("w", M("w", wa, wb)).items[1] == 5)
-- broken records: refused
for _, s in ipairs({ "x;0;10;;0;;;;0;0;;0;;T", "1;0;10;1411:100:200:5;0;;;;0;0;;0;;T", "1;0;10;;0;;7,5;;0;0;;0;;T",
                     "1;0;10;;0;;;;0;0;X;0;;T", "1;0;10;;0;;;;0;0;;0;Na|me;T", "1;0;10;;0;;1,2,3,4,5,6,7,8,9;;0;0;;0;;T",
                     "1;0;10;;0;;;;0;0;;0;;Ti\1tel", "-1;0;10;;0;;;;0;0;;0;;T", "1;0;10;;0;;;;0;0;;0;;" .. ("x"):rep(60),
                     "1;2;10;;0;;;;0;0;;0;;T", "1;4096;10;;0;;;;0;0;;0;;T", "1;01;10;;0;;;;0;0;;0;;T", "1;10;;0;;;;0;0;;0;;T" }) do
    assert(NS.CollectParse("q", s) == nil, "refused: " .. s)
end
assert(NS.CollectParse("s", "1;0;;10:100:Q:;N") == nil and NS.CollectParse("s", "1;0;;10:100::9@X;N") == nil)
assert(NS.CollectParse("w", "1;0;z;;0;;N") == nil and NS.CollectParse("w", "1;0;n;;0;1:0;N") == nil and NS.CollectParse("w", "1;0;n;;0;1:100;N") == nil)

---------------------------------------------------------------------------
-- load: broken saved records go, the shape is fixed
---------------------------------------------------------------------------
AmisiaDB.collect.q[3000] = "kaputt"
AmisiaDB.collect.q["3001"] = a
AmisiaDB.collect.s[0] = va
AmisiaDB.collect.w[9] = { "nope" }
AmisiaDB.collect.x = { 1 }
NS.CollectMigrate(AmisiaDB)
assert(AmisiaDB.collect.q[3000] == nil and AmisiaDB.collect.q["3001"] == nil and AmisiaDB.collect.s[0] == nil and AmisiaDB.collect.w[9] == nil)
assert(AmisiaDB.collect.q[2001] and AmisiaDB.collect.ver == 2)
-- a table of version 1 (no own mask): its records are kept as heard; a day far ahead is pulled back
AmisiaDB.collect = { ver = 1, q = { [7] = "100;10;1411:100:200;0;;5,7;;20;18;A;0;Alpha;Titel A",
    [8] = (TODAY + 30) .. ";10;;0;;;;0;0;;0;;Zukunft" }, s = {}, w = {} }
NS.CollectMigrate(AmisiaDB)
assert(AmisiaDB.collect.ver == 2 and AmisiaDB.collect.q[7] == "100;0;10;1411:100:200;0;;5,7;;20;18;A;0;Alpha;Titel A", "version 1 as heard")
assert(NS.CollectQuest(8).day == TODAY + 1, "a day far ahead becomes tomorrow")
AmisiaDB.collect = "garbage"
NS.CollectMigrate(AmisiaDB)
assert(type(AmisiaDB.collect.q) == "table" and next(AmisiaDB.collect.q) == nil, "a broken table starts empty")

---------------------------------------------------------------------------
-- caps and the byte budget: the oldest records go first
---------------------------------------------------------------------------
local L = NS.COLLECT_LIMITS
local old = { q = L.q, s = L.s, w = L.w, bytes = L.bytes }
L.q = 50
for i = 1, 60 do
    assert(NS.CollectPut("q", 10000 + i, ("%d;0;10;1411:100:200;0;;5;;20;18;A;0;Geber;Quest %d"):format(TODAY - 60 + i, i)) == "new")
end
local counts = NS.CollectCounts()
assert(counts.q <= 50 and counts.q >= 45, "the quest cap: " .. counts.q)
assert(AmisiaDB.collect.q[10001] == nil and AmisiaDB.collect.q[10060] ~= nil, "the oldest went")
L.q = old.q
-- the byte budget
L.bytes = 3000
for i = 1, 60 do NS.CollectPut("w", 20000 + i, ("%d;0;n;1411:1:1;0;7001:1;Mob %d"):format(TODAY - 60 + i, i)) end
assert(NS.CollectBytes() <= 3000, "within the byte budget: " .. NS.CollectBytes())
assert(AmisiaDB.collect.w[20060] ~= nil and AmisiaDB.collect.w[20001] == nil)
L.bytes = old.bytes
-- the counter matches a recount
local function recount()
    local bytes, n = 0, 0
    for _, k in ipairs({ "q", "s", "w" }) do
        for _, s in pairs(AmisiaDB.collect[k]) do bytes, n = bytes + #s + 16, n + 1 end
    end
    return bytes
end
assert(NS.CollectBytes() == recount(), "bytes counted right")

---------------------------------------------------------------------------
-- size at the caps: full tables of typical records stay within the budget
---------------------------------------------------------------------------
AmisiaDB.collect = nil
NS.CollectMigrate(AmisiaDB)
for i = 1, L.q do
    NS.CollectPut("q", 30000 + i, ("%d;0;%d;1440:%d:%d;%d;1440:4512:3321;%d,%d;%d,%d,%d;%d;%d;H;%d;Questgeber Name;Eine typische Quest %d"):format(
        TODAY, 3000 + i, 1000 + i % 9000, 2000 + i % 7000, 4000 + i, 200000 + i, 200001 + i, 210000 + i, 210001 + i, 210002 + i, 20 + i % 40, 18 + i % 40, i, i), "own")
end
for i = 1, L.s do
    local items = {}
    for j = 1, 6 do items[j] = ("%d:%d::"):format(220000 + i * 10 + j, 1000 + j * 37) end
    NS.CollectPut("s", 40000 + i, ("%d;0;1440:2311:5512;%s;Händlerin Name %d"):format(TODAY, table.concat(items, ","), i), "own")
end
for i = 1, L.w do
    NS.CollectPut("w", 50000 + i, ("%d;0;n;1440:%d:%d;0;%d:1,%d:2;Ein Mob %d"):format(TODAY, 1000 + i % 9000, 3000 + i % 6000, 230000 + i, 230001 + i, i), "own")
end
counts = NS.CollectCounts()
-- the file text of the table: '[id] = "record",' per line with two tabs, as the client writes it
local text = 0
for _, k in ipairs({ "q", "s", "w" }) do
    for id, s in pairs(AmisiaDB.collect[k]) do text = text + #("\t\t[" .. id .. "] = \"" .. s .. "\",\n") end
end
print(("collector size at the caps: %d quests, %d vendors, %d mobs, budget count %d bytes, file text %d bytes"):format(
    counts.q, counts.s, counts.w, NS.CollectBytes(), text))
assert(NS.CollectBytes() <= L.bytes and text <= L.bytes * 1.1, "the whole collector within its budget")

-- a price of 0 (recorded by a client without the merchant API) is "unknown": the real price wins
do
    local a = "279;7;1454:6285:4514;7005:0::;Tamar"
    local b = "280;7;1454:6285:4514;7005:82::;Tamar"
    local ab, ba = NS.CollectMergeRecords("s", a, b), NS.CollectMergeRecords("s", b, a)
    assert(ab and ab == ba and ab:find("7005:82::", 1, true), "the real price wins over 0 in both orders: " .. tostring(ab))
    local abc = NS.CollectMergeRecords("s", ab, "281;7;1454:6285:4514;7005:60::;Tamar")
    assert(abc and abc:find("7005:60::", 1, true), "between real prices the lower one: " .. tostring(abc))
end
