-- The play style (F-124, D-56): five switches over the source chips of the own targets, saved in
-- settings.bis.style (known keys only); each rule (no dungeons, solo, buyable with the auction-house
-- source of an item that does not bind on pickup, the reputation and the own craft of "Jetzt holbar",
-- the zone with dungeon entrances), several at once; the targets, the hidden count, the own pick
-- outside the style, the dungeon pages without it; /amisia spielstil; quest types learned from the
-- quest log (AmisiaDB.questtags); the reputation groups of the catalog; the card of the character
-- window's slots (F-125): right-click, a use effect, Alt, the setting.
local Gear = NS.Gear
local PS = NS.PlayStyle
assert(PS and PS.RecOk and PS.Context, "the play style module loads")
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 20
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.place.map = 1429
STUB.instance = { type = "none" }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(3)
NS.GEAR = { game = "forever", cap = 60, built = "test-play-style", I = {}, Z = {}, RP = {}, QT = {}, S = {
    { "Q", "Quest A", 0, 5, "A", 1429, 100, 0 },                    -- 1
    { "Q", "Quest D", 0, 5, "A", 1429, 101, 0, "The Deadmines" },   -- 2 leads into a dungeon
    { "Q", "Quest G", 0, 5, "A", 1429, 102, 0 },                    -- 3 a group quest (learned)
    { "D", "The Deadmines", "Edwin", nil, 36, 1581 },               -- 4
    { "V", "Händlerin", 1429, "A" },                                -- 5
    { "W", nil, 10, 20, 1436 },                                     -- 6 a world drop in Westfall
    { "R", "Hoher Rarer", 30, 1436, 5 },                            -- 7 above level + 1
    { "C", "tailoring", 100 },                                      -- 8
    { "Q", "Quest R", 0, 5, "A", 1429, 103, 0 },                    -- 9 its type comes with the data
    { "W", "Trash (The Deadmines)", 0, 0 },                         -- 10 dungeon trash
    { "V", "Hordenhändler", 1429, "H" },                            -- 11 the other faction's vendor
} }
NS.MAP = { P = { ["I:36"] = "1436:4200:7100" } }
Gear._reset()
local LINKS = {}
local function gear(id, name, bind, sources, str)
    LINKS[id] = STUB.item(id, name, 2)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_HEAD", 4, 0
    it.stats, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = str }, 10
    NS.GEAR.I[id] = { "HEAD", 4, 0, 10, 2, bind, 20, 0, 0, 0 }
    for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
end
gear(701, "Questhelm", 1, { 1 }, 10)
gear(702, "Dungeonquesthelm", 1, { 2 }, 11)
gear(703, "Gruppenhelm", 1, { 3 }, 12)
gear(704, "Bossmaske", 1, { 4 }, 20)
gear(705, "Gebundene Kapuze", 2, { 4 }, 14)   -- binds when equipped: bought from others
gear(706, "Händlerhelm", 0, { 5 }, 9)
gear(707, "Westfallkappe", 2, { 6 }, 8)
gear(708, "Rarenhelm", 1, { 7 }, 15)
gear(709, "Schneiderhut", 1, { 8 }, 16)
gear(710, "Rufhelm", 0, { 5 }, 17)
gear(711, "Raidquesthelm", 1, { 9 }, 7)
gear(712, "Trashhelm", 1, { 10 }, 6)
gear(713, "Bosshelm mit Hordenhändler", 1, { 4, 11 }, 5)
NS.GEAR.RP[710] = 72 * 10 + 5           -- Stormwind, honored
NS.GEAR.QT[103] = "R"
STUB.factions[72] = "Sturmwind"
local standing = { [72] = 5 }           -- 1..8 as the client: friendly
_G.GetFactionInfoByID = function(id) return STUB.factions[id], "", standing[id] end
_G.FACTION_STANDING_LABEL5, _G.FACTION_STANDING_LABEL6 = "Freundlich", "Wohlwollend"
assert(Gear.Available())
NS.BisSetSpec("dps")

local function passes(id) return (PS.ItemPasses(id, NS.BisOpts())) end
local function targets()
    local out = {}
    for _, e in ipairs(NS.BisTargets().HEAD) do out[#out + 1] = e.id end
    return table.concat(out, ",")
end

---------------------------------------------------------------------------
-- the saved switches
---------------------------------------------------------------------------
AmisiaDB.settings.bis.style = { buy = true, bogus = true, solo = "ja" }
assert(PS.On("buy") and not PS.On("solo") and AmisiaDB.settings.bis.style.bogus == nil, "known keys with true only")
assert(PS.Clear() and PS.Count() == 0)
assert(NS.BisOpts().style == nil, "no switch: no context")
assert(targets() == "704,710,709", "without a style the best three: " .. targets())
local fired = 0
NS.Listen("BIS_CHANGED", function(kind) if kind == "style" then fired = fired + 1 end end)

---------------------------------------------------------------------------
-- Keine Dungeons
---------------------------------------------------------------------------
assert(PS.Toggle("nodungeon") and fired == 1, "a switch fires BIS_CHANGED style")
assert(not passes(702) and not passes(704) and not passes(705) and not passes(711), "dungeon loot and dungeon quests out")
assert(passes(701) and passes(706) and passes(708), "quests, vendors, rares stay")
assert(targets() == "710,709,708", "the targets follow: " .. targets())
local h = NS.BisStyleHidden()
assert(h.n == 1 and h.list[1].id == 704 and PS.WhyText(704, h.list[1].why) == "Keine Dungeons", "the hidden boss mask")

---------------------------------------------------------------------------
-- Solo machbar: as no dungeons, rares up to level + 1, learned group quests
---------------------------------------------------------------------------
PS.Clear(); PS.Toggle("solo")
assert(not passes(704) and not passes(708), "the rare mob of level 30 is too high at 20")
assert(passes(703), "a group quest nobody has learned yet stays")
STUB.questsActive[102] = true
_G.C_QuestLog.GetNumQuestLogEntries = function() return 2 end
_G.C_QuestLog.GetInfo = function(i)
    if i == 1 then return { isHeader = true, title = "Wald von Elwynn" } end
    return { questID = 102, isHeader = false, suggestedGroup = 3 }
end
_G.C_QuestLog.GetQuestTagInfo = function() return nil end
local before = fired
STUB.fire("QUEST_LOG_UPDATE"); STUB.tick(4)
assert(AmisiaDB.questtags.list[102] == "G", "a suggested group of 3 is a group quest")
assert(fired == before + 1, "a learned type refreshes the targets with solo on")
assert(not passes(703), "now the group quest is out")
_G.C_QuestLog.GetQuestTagInfo = function() return { tagID = 81 } end
NS.QuestTags.Scan()
assert(AmisiaDB.questtags.list[102] == "D", "the dungeon tag wins over the group size")
AmisiaDB.questtags = { list = { [5] = "G", [6] = "X", bad = "G", [7] = "R" } }
NS.QuestTags.Loaded(AmisiaDB)
assert(AmisiaDB.questtags.v == 1 and AmisiaDB.questtags.list[5] == "G" and AmisiaDB.questtags.list[7] == "R"
    and AmisiaDB.questtags.list[6] == nil and AmisiaDB.questtags.list.bad == nil, "the saved types are checked")

---------------------------------------------------------------------------
-- Kaufbar: vendors, the auction house, every item that does not bind on pickup
---------------------------------------------------------------------------
PS.Clear(); PS.Toggle("buy")
assert(passes(705) and passes(706) and passes(707), "the bind-on-equip hood and cap, the vendor's helm")
assert(not passes(701) and not passes(704) and not passes(709), "bound quest, boss and crafted items are out")
local src = Gear.Sources(705, NS.BisOpts())
assert(#src == 1 and Gear.SourceText(src[1]) == "Auktionshaus (bindet beim Anlegen)", "the source of a bought item")
assert(targets() == "710,705,706", "buyable targets: " .. targets())

---------------------------------------------------------------------------
-- Jetzt holbar: the reputation, the own craft
---------------------------------------------------------------------------
PS.Clear(); PS.Toggle("now")
local text, low = PS.RepText(710)
assert(text == "Ruf: Sturmwind, Wohlwollend (du: Freundlich)" and low, "the reputation line: " .. tostring(text))
assert(not passes(710), "friendly is below honored")
assert(PS.WhyText(710, select(2, PS.ItemPasses(710, NS.BisOpts()))) == text, "the reason names the reputation")
standing[72] = 6
before = fired
STUB.fire("UPDATE_FACTION"); STUB.tick(2)
assert(fired == before + 1 and passes(710), "honored now: the helm counts")
STUB.skills = { { name = "Schneiderei", rank = 50, id = 197 } }
STUB.fire("SKILL_LINES_CHANGED")
assert(not passes(709), "a bound hat needs tailoring 100")
STUB.skills = { { name = "Schneiderei", rank = 120, id = 197 } }
STUB.fire("SKILL_LINES_CHANGED")
assert(passes(709), "tailoring 120: the hat counts")

---------------------------------------------------------------------------
-- Fokus-Zone, and two switches at once
---------------------------------------------------------------------------
PS.Clear(); PS.Toggle("zone")
assert(passes(701) and passes(706) and not passes(707) and not passes(704), "Elwynn: its quest and vendor only")
STUB.place.map = 1436
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(3)
assert(passes(707) and passes(704) and not passes(701), "Westfall: its world drop and the Deadmines by the entrance")
assert(NS.BisCurrentPlace().key == "Z:1436")
PS.Toggle("buy")
assert(not passes(707) and not passes(704) and not passes(705), "buyable here: vendors of the zone only (the auction house has none)")
STUB.place.map = 1429
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(3)
assert(passes(706) and passes(710) and not passes(701), "Elwynn: its vendor's helms")
assert(PS.Names() == "Kaufbar, Fokus-Zone")

---------------------------------------------------------------------------
-- the own pick outside the style, the dungeon pages without it
---------------------------------------------------------------------------
PS.Clear(); PS.Toggle("nodungeon")
assert(NS.BisSetPick("HEAD", 704))
local first = NS.BisTargets().HEAD[1]
assert(first.id == 704 and first.own and first.outside, "the own pick stays first, marked outside")
NS.BisSetPick("HEAD", nil)
assert(not NS.BisTargets().HEAD[1].outside)

---------------------------------------------------------------------------
-- review 2026-10-24: trash, other faction, BiS picks, zone after off/on, "Hier", source texts
---------------------------------------------------------------------------
PS.Clear(); PS.Toggle("nodungeon")
assert(not passes(712), "dungeon trash counts as dungeon")
assert(not passes(713), "a boss item whose other source is the Horde's vendor is out for the Alliance")
assert(not PS.Blocks(706, NS.BisOpts()) and PS.Blocks(704, NS.BisOpts()), "Blocks: only what the switches keep out")
-- a BiS pick follows the style; one without known source never passes it
NS.BIS = NS.BIS or {}
local oldPicks = NS.BIS.PICK
NS.BIS.PICK = { { class = "WARRIOR", spec = "dps", from = 1, to = 60, slot = "HEAD", item = 701, note = "", src = "" } }
NS.Fire("BIS_CHANGED")
assert(NS.BisTargets().HEAD[1].id == 701 and NS.BisTargets().HEAD[1].pick, "a pick that passes stays first")
NS.BIS.PICK[1].item = 704
NS.Fire("BIS_CHANGED")
assert(NS.BisTargets().HEAD[1].id == 710, "a dungeon pick is dropped with Keine Dungeons: " .. NS.BisTargets().HEAD[1].id)
PS.Clear()
assert(NS.BisTargets().HEAD[1].id == 704 and NS.BisTargets().HEAD[1].pick, "without a style the pick is back")
NS.BIS.PICK = oldPicks
NS.Fire("BIS_CHANGED")
-- the own pick: outside only when the switches (not the chips) keep it out
PS.Toggle("now")
AmisiaDB.settings.bis.sources.V = false
NS.Fire("BIS_CHANGED")
assert(NS.BisSetPick("HEAD", 706))
assert(not NS.BisTargets().HEAD[1].outside, "the vendor chip, not the style, keeps it out: no mark")
NS.BisSetPick("HEAD", nil)
AmisiaDB.settings.bis.sources.V = true
NS.Fire("BIS_CHANGED")
-- the zone switch off and on again elsewhere, then back: the list follows
PS.Clear(); STUB.place.map = 1429; PS.Toggle("zone")
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(3)
PS.Toggle("zone")
STUB.place.map = 1436
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(3)
PS.Toggle("zone")
before = fired
STUB.place.map = 1429
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(3)
assert(fired == before + 1, "back in Elwynn after off and on: the targets follow")
-- "Hier": the reputation of Jetzt holbar; a picked place without the zone switch
PS.Clear(); PS.Toggle("now")
standing[72] = 5
STUB.fire("UPDATE_FACTION"); STUB.tick(2)
local function hereIds(key)
    local _, list = NS.BisHere(key)
    local out = {}
    for _, e in ipairs(list) do out[e.id] = true end
    return out
end
assert(not hereIds()[710] and hereIds()[706], "Hier: the vendor's helm without the reputation is out")
PS.Clear(); PS.Toggle("zone")
assert(hereIds("I:36")[704], "a picked dungeon on Hier with the zone switch on")
PS.Clear()

---------------------------------------------------------------------------
-- /amisia spielstil
---------------------------------------------------------------------------
PS.Clear()
SlashCmdList.AMISIA("spielstil kaufbar")
assert(PS.On("buy"), "the command switches")
SlashCmdList.AMISIA("spielstil solo")
STUB.messages = {}
SlashCmdList.AMISIA("spielstil")
assert(has(plain(table.concat(STUB.messages, "\n")), "Spielstil: Solo machbar, Kaufbar."), "the state in chat")
SlashCmdList.AMISIA("spielstil aus")
assert(PS.Count() == 0, "aus clears")
STUB.messages = {}
SlashCmdList.AMISIA("spielstil quatsch")
assert(PS.Count() == 0 and has(plain(table.concat(STUB.messages, "\n")), "Aufruf: /amisia spielstil"), "an unknown word changes nothing")

---------------------------------------------------------------------------
-- the catalog: one group per faction
---------------------------------------------------------------------------
NS.Catalog._reset()
assert(NS.Catalog.ValidCat("rep") and NS.Catalog.Count("rep", 1, 60) == 1, "the reputation group")
local g = NS.Catalog.Sets("rep", 1, 60)[1]
assert(g.name == "Sturmwind" and g.id == -72 and g.total == 1 and g.level == 10, "the group of Stormwind")

---------------------------------------------------------------------------
-- the card of the character window (F-125)
---------------------------------------------------------------------------
local slots = {}
for inv, name in pairs({ [1] = "Head", [13] = "Trinket0" }) do
    local b = CreateFrame("Button", "Character" .. name .. "Slot", UIParent)
    b.GetID = function() return inv end
    slots[inv] = b
end
assert(NS.SlotCardHook() == 2, "the slot buttons found")
local function click(b, button) local f = b:GetScript("OnClick"); if f then f(b, button) end end
click(slots[1], "RightButton")
local card = _G.AmisiaSlotCard
assert(card and card:IsShown(), "a right-click on the head opens the card")
assert(plain(card.title:GetText()) == "Upgrades: Kopf", plain(card.title:GetText()))
assert(card.rows[1]:IsShown() and card.rows[1].e.id == 704, "the best head first")
click(slots[1], "RightButton")
assert(not card:IsShown(), "the same slot again closes it")
click(slots[1], "LeftButton")
assert(not card:IsShown(), "a left-click is the game's")
STUB.worn[13] = STUB.item(801, "Schmuck mit Benutzen", 3)
_G.GetItemSpell = function(link) return has(link, "item:801:") and "Benutzen" or nil end
click(slots[13], "RightButton")
assert(not card:IsShown(), "a trinket with a use effect: the game uses it, no card")
STUB.alt = true
click(slots[13], "RightButton")
assert(card:IsShown(), "Alt + right-click opens the card on every slot")
STUB.alt = nil
card:Hide()
NS.Set("bis.slotClick", false)
click(slots[1], "RightButton")
assert(not card:IsShown(), "switched off: no card")
NS.Set("bis.slotClick", true)

print("play style ok")
