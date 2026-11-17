-- The buffs of the lineup (F-224, D-149, Raid/LineupBuffs.lua) on the shipped Data/RaidBuffData.lua: who
-- counts (the placed; nobody placed: every sign-up neither absent nor on the bench), the three states
-- (have with the count, talent, missing), the role gates of the talent buffs (Leader of the Pack only a druid
-- tank or melee, Moonkin Aura only a ranged druid, Mana Tide only a healing shaman), the groups of group
-- buffs, entries without a class, a spell the client does not know, and no data: no feature.
local SPELLS = {}
C_Spell = {
    GetSpellName = function(id) if SPELLS[id] == false then return nil end return "Spell " .. tostring(id) end,
    GetSpellTexture = function(id) return 1000 + id end,
}

local function find(r, key)
    for _, e in ipairs(r.entries) do if e.key == key then return e end end
end
local function missing(r, key)
    for _, e in ipairs(r.missing) do if e.key == key then return true end end
    return false
end

assert(NS.LineupBuffsAvailable(), "the data of the gear module is there on Forever")
local night = "2026-11-20"
local n = NS.LineupNight(night, true)
n.size = 40

-- an empty night: nothing counted, everything missing, no "all sign-ups"
local r = NS.LineupBuffs(night)
assert(r and r.counted == 0 and not r.all and r.noClass == 0)
assert(#r.entries > 40 and #r.missing == #r.entries)
local blocks = {}
for _, e in ipairs(r.entries) do blocks[e.block] = (blocks[e.block] or 0) + 1 end
assert(blocks.buff and blocks.boss and blocks.util, "three blocks")
local int = find(r, "int")
assert(int.name == "Spell " .. int.spell and int.icon == 1000 + int.spell, "name and icon from the client")

-- sign-ups, nobody placed: every one counts but the absent and the bench
n.list = {
    { n = "Kleinfrak", c = "MAGE", r = "R" },
    { n = "Bob Eisherz", c = "WARRIOR", r = "T" },
    { n = "Vulo Hunt", c = "HUNTER", r = "R" },
    { n = "Druida", c = "DRUID", r = "H" },
    { n = "Fehlt", c = "PRIEST", r = "H", a = true },
    { n = "Bank", c = "PALADIN", r = "M", b = true },
    { n = "Zuviel", c = "SHAMAN", r = "H", v = true },
    { n = "Niemand Nirgends" },
}
r = NS.LineupBuffs(night)
assert(r.all and r.counted == 5 and r.noClass == 1, "all sign-ups, one without a class")
assert(find(r, "int").state == "have" and find(r, "int").count == 1 and not missing(r, "int"))
assert(find(r, "sta").state == "missing", "the absent priest does not count")
assert(find(r, "kings").state == "missing", "the bench does not count")
assert(find(r, "windfury").state == "missing", "the overflow bench does not count")
local ts = find(r, "trueshot")
assert(ts.state == "talent" and ts.count == 1 and #ts.groups == 0, "a talent; no groups without placed players")
assert(ts.who[1].n == "Vulo Hunt" and ts.who[1].talent)
-- the healing druid: no Leader of the Pack (tank or melee), no Moonkin Aura (ranged), but the mark
assert(find(r, "lotp").state == "missing" and find(r, "moonkin").state == "missing")
assert(find(r, "wild").state == "have")
-- one row, two classes: the druid removes curses
local curse = find(r, "curse")
assert(curse.state == "have" and curse.count == 2, "mage and druid: " .. curse.count)
-- the warrior's shout is a group buff
assert(find(r, "battle").scope == "group" and find(r, "battle").state == "have")

-- placed players count, the rest of the night not
n.list = {
    { n = "Kleinfrak", c = "MAGE", r = "R", g = 1 },
    { n = "Bob Eisherz", c = "WARRIOR", r = "T", g = 1 },
    { n = "Vulo Hunt", c = "HUNTER", r = "R", g = 3 },
    { n = "Bär", c = "DRUID", r = "T", g = 2 },
    { n = "Eule", c = "DRUID", r = "R", g = 4 },
    { n = "Schami", c = "SHAMAN", r = "H", g = 2 },
    { n = "Schami Zwei", c = "SHAMAN", r = "M", g = 5 },
    { n = "Priesterin", c = "PRIEST", r = "H" },
    { n = "Unklar", g = 3 },
    { n = "Weg", c = "PALADIN", r = "H", g = 6, a = true },
}
r = NS.LineupBuffs(night)
assert(not r.all and r.counted == 8 and r.noClass == 1, r.counted)
assert(find(r, "sta").state == "missing", "the priest is not placed")
assert(missing(r, "sta") and not missing(r, "int"))
ts = find(r, "trueshot")
assert(ts.state == "talent" and #ts.groups == 1 and ts.groups[1] == 3, "the hunter's group")
local lotp = find(r, "lotp")
assert(lotp.state == "talent" and lotp.count == 1 and lotp.groups[1] == 2 and lotp.who[1].n == "Bär", "only the tank druid")
local mk = find(r, "moonkin")
assert(mk.state == "talent" and mk.count == 1 and mk.groups[1] == 4 and mk.who[1].n == "Eule", "only the ranged druid")
local tide = find(r, "manatide")
assert(tide.state == "talent" and tide.count == 1 and tide.who[1].n == "Schami", "only the healing shaman")
local wf = find(r, "windfury")
assert(wf.state == "have" and wf.count == 2 and #wf.groups == 2 and wf.groups[1] == 2 and wf.groups[2] == 5, "Gr. 2, 5")
assert(find(r, "int").scope == "raid" and #find(r, "int").groups == 0, "a raid buff names no groups")
assert(find(r, "devotion").state == "missing", "the absent paladin does not count")
-- a twink swapped in: the class of the entry changes, the result follows
n.list[1].c = "PRIEST"
r = NS.LineupBuffs(night)
assert(find(r, "int").state == "missing" and find(r, "sta").state == "have")

-- a spell the client does not know: the row drops out (not in "missing" either)
local sta = find(r, "sta").spell
SPELLS[sta] = false
r = NS.LineupBuffs(night)
assert(find(r, "sta") == nil and find(r, "int") ~= nil)
SPELLS[sta] = nil

-- without the data (TBC, Era, the gear module off): no feature
local saved = NS.Data("RAIDBUFFS")
NS.RAIDBUFFS = nil
assert(not NS.LineupBuffsAvailable() and NS.LineupBuffs(night) == nil)
NS.RAIDBUFFS = saved
assert(NS.LineupBuffsAvailable())
-- a fixture in its place
NS.RAIDBUFFS = { entries = { { "x", "buff", "group", 5, 0, "TM", { "WARRIOR", 0, "DRUID", 1 } } } }
r = NS.LineupBuffs(night)
assert(#r.entries == 1 and r.entries[1].state == "have" and r.entries[1].count == 1 and r.entries[1].groups[1] == 1)
print("ok")
