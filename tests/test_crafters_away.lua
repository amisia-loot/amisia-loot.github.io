-- F-244: the crafters of a recipe say who is away or busy (the roster's status 1 AFK, 2 DND, an old client's
-- "<AFK>"): online first, the away ones after the others online, offline last; the text marks them orange with
-- "abwesend"; asking picks an online crafter who is not away first.
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.guild = { { name = "Vulo Sturmwind", rank = 1, online = true },
    { name = "Anna", rank = 3, online = true, status = 1 }, { name = "Bert", rank = 3, online = true },
    { name = "Cleo", rank = 3, online = false }, { name = "Dora", rank = 3, online = true, status = "<DND>" },
    { name = "Emil", rank = 3, online = false, status = 1 } }
STUB.fire("GUILD_ROSTER_UPDATE")
local D = NS.DropsToday()
local function entry(r) return { via = "x", self = true, seen = D, p = { [185] = { r = r, m = 75, h = "00000000", l = "1229737" } } } end
AmisiaDB.crafters = { v = 1, src = {}, c = { ["Anna"] = entry(70), ["Bert"] = entry(20), ["Cleo"] = entry(60),
    ["Dora"] = entry(10), ["Emil"] = entry(50) } }
for _, n in pairs({ "Anna", "Bert", "Cleo", "Dora", "Emil" }) do AmisiaDB.crafters.c[n].via = n end
NS.Fire("PROF_CHANGED")

local roster = NS.GuildRoster()
local by = {}
for _, m in ipairs(roster) do by[m.name] = m end
assert(by.Anna.away == true and by.Dora.away == true and not by.Bert.away, "AFK and DND are away")
assert(not by.Emil.away, "offline is never away")

local list = NS.Crafters.ForSpell(1229737)
local names = {}
for i, c in ipairs(list) do names[i] = c.name end
assert(table.concat(names, ",") == "Bert,Anna,Dora,Cleo,Emil", table.concat(names, ","))
assert(list[2].away == true and list[1].away == false)

local text = NS.Crafters.Text(list, 5, true)
assert(text:find("Anna (70, abwesend)", 1, true) and text:find(NS.Theme.ORANGE, 1, true), text)
assert(text:find(NS.Theme.GREEN .. "Bert (20)", 1, true), text)
assert(NS.Crafters.Text(list, 5):find("Dora (10, abwesend)", 1, true), "without colour the word stays")

assert(NS.Crafters.AskWhom(1229737).name == "Bert", "the one not away first")
STUB.guild[3].online = false
STUB.tick(11)
STUB.fire("GUILD_ROSTER_UPDATE")
assert(NS.Crafters.AskWhom(1229737).name == "Anna", "then an away one before the offline")
print("crafters away ok")
