-- The raid check on one client (Raid/RaidCheck.lua, F-098, D-46): the buffs of the raid read from
-- the auras (flask, elixirs, food by the generated lists, class buffs only when their class is in
-- the raid, secret auras skipped and never compared), "supplied" = a flask or an elixir, the own
-- report (durability with its colours 30/50, item level, empty slots without the off hand of a
-- two-hand weapon or a relic class's ranged slot, unenchanted slots by the item link and the tooltip
-- line type 15, a shield only, free talent points), the XA fields, combat (nothing read, nothing
-- sent, the last rows with their time), the ready check's answer outside the lockdown only, the
-- optional chat line (setting, officer, never in the lockdown, raid names only, two lines) and the
-- raider view (no page data, the own line by command).
local RC = NS.RaidCheck
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] end

STUB.player, STUB.class, STUB.level = "Vuloo", "PRIEST", 60
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" }, { name = "Fraktur", rank = 3, class = "SHAMAN" },
               { name = "Chorf", rank = 3, class = "WARRIOR" }, { name = "Anna Bergmann", rank = 4, class = "MAGE" } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
NS.Set("ui.view", "officer")
assert(NS.RaidCheckAllowed() == true, "an officer with the officer rank")

-- the auras of every unit: STUB-like table per unit
local AURAS = {}
_G.C_UnitAuras = { GetAuraDataByIndex = function(unit, i, filter)
    assert(filter == "HELPFUL")
    local l = AURAS[unit]
    return l and l[i]
end }
local function aura(id, dur, left) return { name = "Buff " .. id, spellId = id, duration = dur or 3600, expirationTime = GetTime() + (left or dur or 3600) } end
local FLASK, ELIXIR, FOOD, INT, STA, WILD, KINGS, SPIRIT = 17626, 17538, 19705, 10157, 10938, 9885, 20217, 27841

-- 1. the lists: flask, elixirs, food, class buffs; a secret aura is skipped
local secret = { name = "x", spellId = 1 }
STUB.secret[secret] = true
local secretId = { name = "y", spellId = 777 }
STUB.secret[777] = true
local c = RC.Classify({ aura(FLASK, 7200), aura(ELIXIR), secret, secretId, aura(FOOD, 900), aura(INT, 1800), aura(123456) })
assert(c.flask and c.flask.id == FLASK and #c.elixirs == 1 and c.food and c.food.id == FOOD, "flask, one elixir, food")
assert(c.have.int and c.have.int.id == INT and not c.have.sta, "the intellect buff")
assert(RC.Supplied(c), "a flask supplies")
assert(RC.Supplied(RC.Classify({ aura(ELIXIR) })), "one elixir supplies too")
assert(not RC.Supplied(RC.Classify({ aura(FOOD, 900) })), "food alone does not")
assert(#RC.Classify({ secret, secretId }).elixirs == 0, "secret auras are never compared")

-- 2. durability colours: red under the setting (30), orange under 50
assert(RC.DurColor(29) == "red" and RC.DurColor(30) == "orange" and RC.DurColor(49) == "orange" and RC.DurColor(50) == nil)
NS.Set("raidcheck.durability", 40)
assert(RC.DurColor(35) == "red" and RC.DurColor(45) == "orange")
NS.Set("raidcheck.durability", 30)
assert(RC.DurColor(nil) == nil)

-- 3. the own report
local DUR = { [1] = { 55, 60 }, [5] = { 20, 100 }, [16] = { 90, 90 }, [10] = { 70, 100 }, [8] = { 40, 100 } }
_G.GetInventoryItemDurability = function(slot)
    local d = DUR[slot]
    if d then return d[1], d[2] end
end
_G.GetAverageItemLevel = function() return 61.25, 58.5, 58.5 end
STUB.item(18608, "Benediction", 4)
STUB.items[18608].equipLoc = "INVTYPE_2HWEAPON"
STUB.item(19140, "Cauterizing Band", 4)
STUB.item(16921, "Halo of Transcendence", 4)
STUB.item(16923, "Robes of Transcendence", 4)
STUB.item(16920, "Handguards of Transcendence", 4)
STUB.item(16919, "Boots of Transcendence", 4)
STUB.worn = {
    [1] = "|cffa335ee|Hitem:16921:2545::::::::60:::::|h[Halo of Transcendence]|h|r",
    [5] = "|cffa335ee|Hitem:16923:1891::::::::60:::::|h[Robes of Transcendence]|h|r",
    [10] = STUB.link(16920, "Handguards of Transcendence"),
    [8] = STUB.link(16919, "Boots of Transcendence"),
    [11] = STUB.link(19140, "Cauterizing Band"),
    [16] = "|cffa335ee|Hitem:18608:0::::::::60:::::|h[Benediction]|h|r",
}
-- the hands are enchanted only by the tooltip's line type 15 (not in the link)
Enum.TooltipDataLineType = Enum.TooltipDataLineType or {}
Enum.TooltipDataLineType.ItemEnchantmentPermanent = 15
C_TooltipInfo.GetInventoryItem = function(unit, slot)
    local lines = { { type = 22, leftText = "item" } }
    if slot == 10 then lines[#lines + 1] = { type = 15, leftText = "Verzaubert: +7 Heilung" } end
    return { lines = lines }
end
NS.Talents.Live = function() return {}, { free = 5, spent = 46, total = 51 } end
NS.Talents.Available = function() return true end
AURAS.player = { aura(FLASK, 7200), aura(FOOD, 900) }
local o = RC.Own()
assert(o.dur == 20 and o.below == 1, "lowest 20 %, one under 30: " .. tostring(o.dur) .. " " .. tostring(o.below))
assert(o.ilvl == 58.5 and o.free == 5 and o.level == 60)
local function set(list) local t = {} for _, v in ipairs(list) do t[v] = true end return t end
local empty = set(o.empty)
assert(empty[2] and empty[3] and empty[15] and empty[18] and not empty[17], "empty: neck, shoulders, back, ranged; not the off hand beside a two-hand weapon")
local unench = set(o.unench)
assert(unench[8] and unench[16] and not unench[10] and not unench[5] and not unench[15], "feet and weapon unenchanted; hands by the tooltip line; back is empty")
assert(o.cons.flask and o.cons.food and #o.cons.elixirs == 0)
local f = RC.AnswerFields("ab12", o)
assert(table.concat(f, " ") == "ab12 20 1 585 2,3,15,9,6,7,12,13,14,18 8,16 5 FW", table.concat(f, " "))
-- a shield is enchantable, a held-in-off-hand item is not; a paladin's empty relic slot is no gap
STUB.item(19312, "Lei of the Lifegiver", 4)
STUB.items[19312].equipLoc = "INVTYPE_HOLDABLE"
STUB.items[18608].equipLoc = "INVTYPE_WEAPONMAINHAND"
STUB.worn[17] = STUB.link(19312, "Lei of the Lifegiver")
STUB.class = "PALADIN"
o = RC.Own()
assert(not set(o.unench)[17] and not set(o.empty)[18], "a holdable is not counted, a paladin's ranged slot neither")
STUB.items[19312].equipLoc = "INVTYPE_SHIELD"
o = RC.Own()
assert(set(o.unench)[17], "a shield without enchant")
STUB.worn[17] = nil
STUB.class = "PRIEST"
o = RC.Own()
assert(set(o.empty)[17], "the off hand beside a one-hand weapon is empty")
STUB.items[18608].equipLoc = "INVTYPE_2HWEAPON"
-- unspent points: grey below 60 is the page's matter; the report says the number
NS.Talents.Live = function() return {}, { free = 0, spent = 51, total = 51 } end
assert(RC.Own().free == 0)

-- 4. alone: one row, read from the own auras; a priest alone needs Fortitude
local rows = RC.Rows()
assert(#rows.list == 1 and rows.list[1].me and rows.list[1].src == "read", "the own row")
assert(#rows.list[1].missing == 1 and rows.list[1].missing[1] == "sta", "only the priest's own buff counts")
assert(RC.MissingText(rows) == "Es fehlt: 1 Ausdauer", RC.MissingText(rows))
AURAS.player = { aura(FLASK, 7200), aura(FOOD, 900), aura(STA, 1800) }
assert(RC.MissingText(RC.Rows()) == "Es fehlt nichts.")
AURAS.player = { aura(STA, 1800) }
assert(RC.MissingText(RC.Rows()) == "Es fehlt: 1 Fläschchen, 1 Essen", RC.MissingText(RC.Rows()))

-- 5. a raid: buffs of the raiders in sight, out of sight, offline; a group is counted only when its
-- class is in the raid, a talent buff only when somebody carries it
STUB.roster = {
    { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
    { name = "Anna Bergmann", class = "MAGE" }, { name = "Kimtaro", class = "ROGUE", online = false },
}
STUB.playerRaidIndex = 1
local VISIBLE = { raid1 = true, raid2 = true, raid3 = true, raid4 = false }
_G.UnitIsVisible = function(u) return VISIBLE[u] ~= false end
AURAS.raid1 = { aura(FLASK, 7200), aura(FOOD, 900), aura(STA, 1800), aura(INT, 1800) }
AURAS.player = AURAS.raid1
AURAS.raid2 = { aura(STA, 1800) }
AURAS.raid3 = { aura(ELIXIR), aura(FOOD, 900), aura(STA, 1800), aura(INT, 1800), aura(SPIRIT, 1800) }
rows = RC.Rows()
local by = {}
for _, r in ipairs(rows.list) do by[r.name] = r end
assert(by["Kimtaro"].state == "offline" and by["Anna Bergmann"].state == "far" and not by["Anna Bergmann"].cons, "offline, out of sight")
assert(set(rows.need).int and set(rows.need).sta and set(rows.need).spirit and not set(rows.need).wild and not set(rows.need).bless,
    "a mage and a priest are here, the spirit carried; no druid, no paladin")
assert(#by["Fraktur"].missing == 2, "Fraktur lacks intellect and spirit")
assert(RC.MissingText(rows) == "Es fehlt: 1 Fläschchen, 1 Essen, 1 Intelligenz, 2 Willenskraft", RC.MissingText(rows))
-- out of sight with an own report of the last 10 minutes: the report's consumables
NS._raidcheck.answers()["anna bergmann"] = RC.ParseAnswer({ "-", "25", "2", "600", "-", "-", "0", "FE2W" })
NS._raidcheck.answers()["anna bergmann"].name = "Anna Bergmann"
rows = RC.Rows()
for _, r in ipairs(rows.list) do by[r.name] = r end
assert(by["Anna Bergmann"].src == "self" and by["Anna Bergmann"].cons.flask and #by["Anna Bergmann"].cons.elixirs == 2, "laut Amisia")
assert(by["Anna Bergmann"].rep.dur == 25 and by["Anna Bergmann"].rep.ilvl == 60)
STUB.tick(601)
rows = RC.Rows()
for _, r in ipairs(rows.list) do by[r.name] = r end
assert(not by["Anna Bergmann"].cons, "an own report older than 10 minutes does not stand for the buffs")
assert(by["Anna Bergmann"].rep ~= nil, "the gear report still shows (30 minutes)")

-- 6. combat: nothing read, the last rows shown, nothing sent
STUB.addon = {}
STUB.combat = true
local before = rows.at
AURAS.raid2 = { aura(FLASK, 7200) }
rows = RC.Rows()
assert(rows.combat == "combat" and rows.at == before, "the last read with its time")
for _, r in ipairs(rows.list) do by[r.name] = r end
assert(not by["Fraktur"].cons.flask, "nothing read again in combat")
local ok, why = RC.Ask()
assert(ok == nil and why == "Nicht im Kampf.", tostring(why))
STUB.tick(2)
assert(#STUB.addon == 0, "nothing sent in combat")
STUB.combat = false

-- 7. "Prüfen": XQ to the raid, at most every 10 s
ok, why = RC.Ask()
assert(ok and has(why, "gefragt"), tostring(why))
STUB.tick(1)
local xq = 0
for _, m in ipairs(STUB.addon) do if m.text:match("^1XQ\t%x%x%x%x$") and m.chan == "RAID" then xq = xq + 1 end end
assert(xq == 1, "one XQ")
RC.Ask()
STUB.tick(1)
xq = 0
for _, m in ipairs(STUB.addon) do if m.text:find("^1XQ") then xq = xq + 1 end end
assert(xq == 1, "not again within 10 s")

-- 8. the ready check: one XA by itself, outside the lockdown only; a secret initiator (boss fight): none
local function xas() local n = 0 for _, m in ipairs(STUB.addon) do if m.text:find("^1XA\t") then n = n + 1 end end return n end
STUB.addon = {}
STUB.tick(11)
STUB.fire("READY_CHECK", "Fraktur", 30)
STUB.tick(4)
assert(xas() == 1, "the ready check's answer")
assert(STUB.addon[#STUB.addon].text:match("^1XA\t%-\t"), "question id '-'")
STUB.tick(11)
STUB.chatLock = true
STUB.fire("READY_CHECK", "Fraktur", 30)
STUB.tick(4)
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.tick(12)
assert(xas() == 1, "no answer in the lockdown, none afterwards either (it fell)")
STUB.secret["Fraktur"] = true
STUB.fire("READY_CHECK", "Fraktur", 30)
STUB.tick(4)
STUB.secret["Fraktur"] = nil
assert(xas() == 1, "a secret ready check gets no answer")
STUB.combat = true
STUB.fire("READY_CHECK", "Fraktur", 30)
STUB.tick(4)
STUB.combat = false
assert(xas() == 1, "none in combat")
NS.Set("raidcheck.answer", false)
STUB.fire("READY_CHECK", "Fraktur", 30)
STUB.tick(4)
assert(xas() == 1, "none with raidcheck.answer off")
NS.Set("raidcheck.answer", true)

-- 9. the chat line: off by default; on: names of the raid list and fixed words, two lines at most,
-- never in the lockdown
STUB.chat = {}
ok, why = RC.Say()
assert(ok == nil and has(why, "Einstellungen aus"), tostring(why))
assert(not RC.CanSay())
NS.Set("raidcheck.chat", true)
assert(RC.CanSay())
AURAS.raid2 = { aura(STA, 1800) }
NS._raidcheck.answers()["chorf"] = { name = "Chorf", at = time(), dur = 12, heard = true, cons = { elixirs = {}, have = {} } }
local n = RC.Say()
assert(n == 1 and #STUB.chat == 1, "one line")
assert(STUB.chat[1].chan == "RAID" and STUB.chat[1].text == "Amisia Raid-Check: Es fehlt: Fläschchen: Fraktur · Essen: Fraktur · Haltbarkeit unter 30 %: Anna Bergmann, Chorf, Vuloo",
    STUB.chat[1].text)
STUB.chatLock = true
assert(not RC.CanSay())
ok, why = RC.Say()
assert(ok == nil and why == "Nicht im Kampf.", tostring(why))
STUB.chatLock = false
-- a long raid: two lines at most
STUB.chat = {}
for i = 1, 35 do
    local name = ("Raider %s"):format(string.char(64 + (i % 26) + 1) .. string.char(97 + math.floor(i / 26)) .. "lmanfred")
    STUB.roster[#STUB.roster + 1] = { name = name, class = "WARRIOR" }
end
n = RC.Say()
assert(n == 2 and #STUB.chat == 2, "two lines at most: " .. tostring(n))
for _, m in ipairs(STUB.chat) do assert(#m.text <= 255) end
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
-- a raider never offers it
NS.Set("ui.view", "raider")
assert(not RC.CanSay())
ok = RC.Say()
assert(ok == nil)

-- 10. the raider view: no page data, nothing asked; the own line by command
assert(NS.RaidCheckAllowed() == false)
ok, why = RC.Ask()
assert(ok == nil and has(why, "nur für Offiziere"), tostring(why))
STUB.messages = {}
AURAS.player = { aura(FLASK, 7200) }
NS.Dispatch("raidcheck")
local text = table.concat(STUB.messages, "\n")
assert(has(text, "Raid-Check: Fläschchen ja · Elixiere 0 · Essen fehlt · Haltbarkeit 20 % · Itemstufe 58.5 · leer: "), text)
assert(has(text, "unverzaubert: Füße, Waffenhand") and has(text, "freie Talentpunkte 0"), text)
assert(has(text, "Raid-IDs"), "the own raid IDs too: " .. text)
NS.Set("ui.view", "officer")

-- 11. the raid ends: the answers go
STUB.roster = {}
STUB.fire("GROUP_ROSTER_UPDATE")
assert(next(NS._raidcheck.answers()) == nil, "nothing kept after the raid")
