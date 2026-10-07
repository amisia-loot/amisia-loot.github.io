-- Loot announcement: once per corpse from the loot window and from group loot rolls, reservers from
-- the raid, the raid warning, the SR mark on the roll frames and /amisia ansage.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Vulo Sturmwind", class = "WARRIOR" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")

local l1 = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local l2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
local l3 = STUB.item(32373, "Helm of the Illidari Shatterer", 4)
local blue = STUB.item(30000, "Blue Thing", 3)
-- a tracked guild material (the list is empty until the guild names its materials) and an ignored
-- disenchanting result
local mat = STUB.item(32897, "Mark of the Illidari", 4)
NS.MATS[32897], NS.MAT_ORDER[1] = "Mark of the Illidari", 32897
local badge = STUB.item(20725, "Nexus Crystal", 4)
NS.SetSoftRes("Fraktur 32235\nVulo Sturmwind 32235\nVulo Sturmwind 32235\nGustav 32235\nChorf 32373\nAnna 32373\nVuloo 32373\n")

local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
-- a full chat bucket and an empty chat for every step
local function fresh() STUB.tick(10); STUB.chat = {} end
local function corpse(guid, links)
    STUB.loot = {}
    for i, l in ipairs(links) do STUB.loot[i] = { link = l, name = "x", src = guid } end
end
local function open(...) STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED", ...) end

-- settings
for path, want in pairs({ ["loot.announce"] = { "toggle", true }, ["loot.quality"] = { "choice", 4 },
                          ["loot.groupLoot"] = { "toggle", true }, ["loot.warning"] = { "toggle", false } }) do
    local it = NS.SettingItem(path)
    assert(it and it.type == want[1] and it.default == want[2] and it.section.key == "loot", path)
end

---------------------------------------------------------------------------
-- master loot: one announcement per corpse
---------------------------------------------------------------------------
local BOSS = "Creature-0-1-1-1-22917-1"
STUB.target, STUB.targetGUID = "Illidan Stormrage", BOSS
corpse(BOSS, { l1, l2, l3, blue, mat, badge })
fresh()
open(false)
assert(#STUB.chat == 4, "head and three items: " .. #STUB.chat)
for _, c in ipairs(STUB.chat) do assert(c.chan == "RAID", c.chan) end
assert(STUB.chat[1].text == "Amisia Loot (Illidan Stormrage): 3 Items", STUB.chat[1].text)
assert(STUB.chat[2].text == "1. " .. l1 .. " SR: Fraktur, Vulo Sturmwind x2 (+1 nicht im Raid)", STUB.chat[2].text)
assert(STUB.chat[3].text == "2. " .. l2 .. " frei", STUB.chat[3].text)
assert(STUB.chat[4].text == "3. " .. l3 .. " SR: Chorf, Vuloo (+1 nicht im Raid)", STUB.chat[4].text)
assert(s.announced and s.announced["g:" .. BOSS], "remembered in the recording")
assert(not NS.ExportText({ s }):find("announced", 1, true), "not in the export")

-- the same corpse again: nothing
fresh(); open(false)
assert(#STUB.chat == 0, "once per corpse")

-- a /reload: the file runs again with the same recording, and still says nothing
local chunk = assert(loadfile(ADDON_DIR .. "/Raid/LootAnnounce.lua"))
chunk("Amisia", NS)
fresh(); open(false)
assert(#STUB.chat == 0, "no second announcement after a reload")

-- /amisia ansage repeats the open window without the key check
fresh(); NS.Dispatch("ansage")
assert(#STUB.chat == 4 and STUB.chat[1].text == "Amisia Loot (Illidan Stormrage): 3 Items", "ansage repeats")
fresh(); NS.Dispatch("announce")
assert(#STUB.chat == 4, "the alias")
STUB.fire("LOOT_CLOSED")
fresh(); NS.Dispatch("ansage")
assert(#STUB.chat == 0 and has(STUB.messages[#STUB.messages], "Kein Lootfenster"), STUB.messages[#STUB.messages])

-- quality threshold
NS.Set("loot.quality", 3)
corpse("Creature-0-1-1-1-22917-2", { l1, blue, mat })
fresh(); open(false)
assert(#STUB.chat == 3 and STUB.chat[1].text:find(": 2 Items", 1, true) and has(STUB.chat[3].text, blue), "blue counts at quality 3")
NS.Reset("loot.quality")
corpse("Creature-0-1-1-1-22917-3", { blue, mat, badge })
fresh(); open(false)
assert(#STUB.chat == 0, "nothing worth announcing")

-- a container from the bags is no corpse
corpse("Item-0-0-0-123", { l1 })
fresh(); open(false)
assert(#STUB.chat == 0, "bag container")

-- Forever: loot from an item is skipped
corpse("Creature-0-1-1-1-22917-4", { l1 })
fresh(); open(false, true)
assert(#STUB.chat == 0, "isFromItem")
open(false)
assert(#STUB.chat == 2 and STUB.chat[1].text:find(": 1 Item", 1, true), "the same corpse opened normally")

-- not the loot lead, raider view, switched off, or no raid: nothing
STUB.leader = false
corpse("Creature-0-1-1-1-22917-5", { l1 })
fresh(); open(false)
assert(#STUB.chat == 0, "not the lead")
STUB.leader = true
NS.Set("ui.view", "raider")
fresh(); open(false)
assert(#STUB.chat == 0, "raider view")
NS.Reset("ui.view")
NS.Set("loot.announce", false)
fresh(); open(false)
assert(#STUB.chat == 0, "switched off")
NS.Reset("loot.announce")
local inRaid = IsInRaid
_G.IsInRaid = function() return false end
fresh(); open(false)
assert(#STUB.chat == 0, "a five-player group")
_G.IsInRaid = inRaid
fresh(); open(false)
assert(#STUB.chat == 2, "announced once all is well")

-- master loot by someone else: nothing, by me: announced
STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 2, 1
corpse("Creature-0-1-1-1-22917-6", { l2 })
fresh(); open(false)
assert(#STUB.chat == 0, "another master looter")
STUB.mlRaidID = 1
fresh(); open(false)
assert(#STUB.chat == 2, "master looter myself")
STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = nil, nil, nil

-- a secret source: the sorted items are the key, for 10 minutes; no source name
local SECRET = "Creature-secret"
STUB.secret[SECRET] = true
STUB.targetGUID = nil
corpse(SECRET, { l2, l1 })
fresh(); open(false)
assert(#STUB.chat == 3 and STUB.chat[1].text == "Amisia Loot: 2 Items", STUB.chat[1] and STUB.chat[1].text)
assert(s.announced["i:32235,32837"], "item key")
fresh(); open(false)
assert(#STUB.chat == 0, "the item key holds")
STUB.tick(600)
fresh(); open(false)
assert(#STUB.chat == 3, "the item key runs out after 10 minutes")
STUB.secret[SECRET] = nil
STUB.targetGUID = BOSS

-- at most 8 item lines
local many = {}
for i = 1, 10 do many[i] = STUB.item(40000 + i, "Epic " .. i, 4) end
corpse("Creature-0-1-1-1-22917-7", many)
fresh(); open(false)
assert(#STUB.chat == 10, #STUB.chat)
assert(STUB.chat[1].text:find(": 10 Items", 1, true) and STUB.chat[9].text:find("^8%. ") and STUB.chat[10].text == "und 2 weitere", STUB.chat[10].text)

-- the raid warning: only with the right to give one
NS.Set("loot.warning", true)
corpse("Creature-0-1-1-1-22917-8", { l1, l2, l3 })
fresh(); open(false)
local warn
for _, c in ipairs(STUB.chat) do if c.chan == "RAID_WARNING" then warn = c end end
assert(warn and warn.text == "Loot: 3 Items, 2 reserviert. Liste im Schlachtzugschat.", warn and warn.text)
assert(#STUB.chat == 5)
STUB.leader = false
NS.Set("loot.lead", "me")
corpse("Creature-0-1-1-1-22917-9", { l1 })
fresh(); open(false)
assert(#STUB.chat == 2, "no warning without the right, and no raid line instead: " .. #STUB.chat)
for _, c in ipairs(STUB.chat) do assert(c.chan == "RAID") end
NS.Reset("loot.lead"); STUB.leader = true
NS.Reset("loot.warning")

-- without a recording the keys live in memory
NS.SetEnabled(false)
assert(NS.Active() == nil)
corpse("Creature-0-1-1-1-22917-10", { l1 })
fresh(); open(false)
assert(#STUB.chat == 2, "announced without a recording")
fresh(); open(false)
assert(#STUB.chat == 0, "and only once")
NS.SetEnabled(true)
assert(NS.Active() == s)

-- old keys fall out after 12 hours
STUB.tick(13 * 3600)
corpse("Creature-0-1-1-1-22917-11", { l2 })
fresh(); open(false)
assert(#STUB.chat == 2)
assert(s.announced["g:Creature-0-1-1-1-22917-11"] and not s.announced["g:" .. BOSS], "the boss key is gone after 12 hours")

---------------------------------------------------------------------------
-- group loot: rolls within 1.5 s make one announcement
---------------------------------------------------------------------------
STUB.fire("LOOT_CLOSED")
STUB.rolls[11], STUB.rolls[12], STUB.rolls[13] = l1, l2, blue
fresh()
STUB.fire("START_LOOT_ROLL", 11, 60000)
STUB.tick(0.5)
STUB.fire("START_LOOT_ROLL", 12, 60000)
STUB.fire("START_LOOT_ROLL", 13, 60000)
assert(#STUB.chat == 0, "collected first")
STUB.tick(1.5)
assert(#STUB.chat == 3, #STUB.chat)
assert(STUB.chat[1].text == "Amisia Würfeln: 2 Items", STUB.chat[1].text)
assert(STUB.chat[2].text == "1. " .. l1 .. " SR: Fraktur, Vulo Sturmwind x2 (+1 nicht im Raid)", STUB.chat[2].text)
assert(STUB.chat[3].text == "2. " .. l2 .. " frei")
-- the same roll again says nothing
fresh(); STUB.fire("START_LOOT_ROLL", 11, 60000); STUB.tick(2)
assert(#STUB.chat == 0, "one announcement per roll")
-- switched off for group loot
NS.Set("loot.groupLoot", false)
STUB.rolls[14] = l3
fresh(); STUB.fire("START_LOOT_ROLL", 14, 60000); STUB.tick(2)
assert(#STUB.chat == 0, "loot.groupLoot off")
NS.Reset("loot.groupLoot")
-- not the lead
STUB.leader = false
fresh(); STUB.fire("START_LOOT_ROLL", 14, 60000); STUB.tick(2)
assert(#STUB.chat == 0, "not the lead")
STUB.leader = true
-- a client without GetLootRollItemLink: nothing, no error
local getLink = GetLootRollItemLink
_G.GetLootRollItemLink = nil
fresh(); STUB.fire("START_LOOT_ROLL", 14, 60000); STUB.tick(2)
assert(#STUB.chat == 0, "no link function")
_G.GetLootRollItemLink = getLink
fresh(); STUB.fire("START_LOOT_ROLL", 14, 60000); STUB.tick(2)
assert(#STUB.chat == 2 and STUB.chat[1].text == "Amisia Würfeln: 1 Item", "announced with the link")

---------------------------------------------------------------------------
-- SR mark on the roll frames, for everyone
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
local frame = GroupLootFrame1
STUB.rolls[21], STUB.rolls[22], STUB.rolls[23] = l1, l2, l3
frame.rollID = 21; frame:Show()
assert(NS.RollMarkText(frame) == "SR", tostring(NS.RollMarkText(frame)))
-- the frame is used again for an item nobody reserved
frame:Hide(); frame.rollID = 22; frame:Show()
assert(NS.RollMarkText(frame) == nil, "the mark goes with the reused frame")
frame:Hide(); frame.rollID = 23; frame:Show()
assert(NS.RollMarkText(frame) == "SR (du)", tostring(NS.RollMarkText(frame)))
GroupLootFrame4.rollID = 21; GroupLootFrame4:Show()
assert(NS.RollMarkText(GroupLootFrame4) == "SR", "every roll frame")
NS.Set("softres.lootMark", false)
frame:Hide(); frame:Show()
assert(NS.RollMarkText(frame) == nil, "switched off")
NS.Reset("softres.lootMark")
_G.GetLootRollItemLink = nil
frame:Hide(); frame:Show()
assert(NS.RollMarkText(frame) == nil, "no link, no mark, no error")
_G.GetLootRollItemLink = getLink
NS.Reset("ui.view")

-- every UI and chat string stays Latin-1
local src = assert(io.open(ADDON_DIR .. "/Raid/LootAnnounce.lua", "rb")):read("*a")
for c in src:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1: " .. c) end
