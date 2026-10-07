-- Guild crafters (Crafters.lua), one client: the own crafters are the characters of this account
-- marked for the current guild; their digest; the bitset over a profession's recipe index; the store
-- of heard crafters is checked and pruned at load (malformed, not heard of for 45 days, above 500);
-- who knows a recipe or makes an item (online first, then rank, the own characters marked, members
-- who left left out); the tooltip line, cached and light; the filter of the page; the whisper text.
local Cr, Pr = NS.Crafters, NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.guild = { { name = "Vulo Sturmwind", rank = 1 }, { name = "Vulo Zweit", rank = 4 }, { name = "Anna Amboss", rank = 3 },
    { name = "Bob Hammer", rank = 3, online = false }, { name = "Cleo Kessel", rank = 3 } }
STUB.fire("GUILD_ROSTER_UPDATE")
local D = NS.DropsToday()

---------------------------------------------------------------------------
-- the own crafters: the current character, alts marked for this guild
---------------------------------------------------------------------------
assert(#Cr.Own() == 0, "nothing read yet")
AmisiaDB.prof = { chars = {
    ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = D, known = { [2663] = true, [1252229] = true } } },
    ["Vulo Zweit"] = { [171] = { rank = 60, max = 75, day = D, known = { [2330] = true } }, [185] = { rank = 5, max = 75, day = D } },
    ["Vulo Fremd"] = { [164] = { rank = 300, max = 300, day = D, known = { [2663] = true, [3321] = true } } },
    ["Vulo Alt"] = { [164] = { rank = 100, max = 150, day = D, known = { [3321] = true } } },
}, guild = { ["Vulo Zweit"] = "Amisia", ["Vulo Fremd"] = "Andere Gilde" } }
NS.Fire("PROF_CHANGED")
local own = Cr.Own()
assert(#own == 2 and own[1].name == "Vulo Sturmwind" and own[2].name == "Vulo Zweit", "the current one first, the marked alt")
assert(#own[2].profs == 1 and own[2].profs[1].skill == 171, "a profession never read from the window stays out")
assert(AmisiaDB.prof.guild["Vulo Sturmwind"] == "Amisia", "the current character is marked for its guild")
-- outside a guild nothing is own, and the mark stays
STUB.inGuild = false
assert(#Cr.Own() == 0, "no guild, nothing to share")
assert(AmisiaDB.prof.guild["Vulo Sturmwind"] == nil, "out of the guild: unmarked")
STUB.inGuild = nil
assert(#Cr.Own() == 2)

-- the digest: the same for the same recipes, another after a new one
local d1, n = Cr.Digest()
assert(#d1 == 8 and d1:match("^%x+$") and n == 2, d1)
assert(Cr.Digest() == d1, "stable")
AmisiaDB.prof.chars["Vulo Sturmwind"][164].known[3321] = true
NS.Fire("PROF_CHANGED", 164)
local d2 = Cr.Digest()
assert(d2 ~= d1, "a new recipe changes it")

---------------------------------------------------------------------------
-- the bitset over the recipe index (spells sorted by id)
---------------------------------------------------------------------------
local ix = Cr._index(164)
assert(table.concat(ix.list, ",") == "2663,3321,9999,1252229,1301421", table.concat(ix.list, ","))
local bits = Cr._toBits(ix, { [2663] = true, [1252229] = true, [77] = true })
assert(bits == "09", bits)   -- bits 0 and 3
local back = Cr._fromBits(ix, bits)
assert(#back == 2 and back[1] == 2663 and back[2] == 1252229)
assert(Cr._fromBits(ix, "0900") == nil, "another length does not fit the index")
assert(Cr._fromBits(ix, "e0") == nil, "bits beyond the index do not fit")
assert(#ix.hash == 8)

---------------------------------------------------------------------------
-- the heard crafters: who knows what
---------------------------------------------------------------------------
local h164 = ix.hash
AmisiaDB.crafters = { v = 1, src = { ["anna amboss"] = { d = "0badf00d", at = D } }, c = {
    ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D, p = { [164] = { r = 250, m = 300, h = h164, b = Cr._toBits(ix, { [2663] = true, [3321] = true }) } } },
    ["Bob Hammer"] = { via = "Bob Hammer", seen = D - 3, p = { [164] = { r = 275, m = 300, h = h164, b = Cr._toBits(ix, { [2663] = true }) } } },
    ["Cleo Kessel"] = { via = "Cleo Kessel", seen = D, p = { [171] = { r = 80, m = 150, l = "1234001,2330" } } },
    ["Dora Weg"] = { via = "Dora Weg", seen = D, p = { [164] = { r = 300, m = 300, h = h164, b = "01" } } },
} }
Cr.Changed()
STUB.fire("ADDON_LOADED", "Amisia")   -- the load checks the store
local list = Cr.ForSpell(2663)
local names = {}
for i, c in ipairs(list) do names[i] = c.name .. ":" .. c.rank .. (c.online and "+" or "") .. (c.own and "*" or "") end
-- online first (Anna 250, Vulo 45 own), then Bob (offline, 275); Dora left the guild
assert(table.concat(names, ",") == "Anna Amboss:250+,Vulo Sturmwind:45+*,Bob Hammer:275", table.concat(names, ","))
assert(Cr.Text(list) == "Anna Amboss (250), Vulo Sturmwind (45), Bob Hammer (275)", Cr.Text(list))
assert(Cr.Text(list, 2) == "Anna Amboss (250), Vulo Sturmwind (45), +1 weitere", Cr.Text(list, 2))
assert(has(Cr.Text(list, nil, true), NS.Theme.GREEN .. "Anna Amboss (250)|r"), "online in green")
assert(#Cr.ForSpell(2330) == 2, "a list of spells (other data) and the own alt")
assert(Cr.Has(1234001) and not Cr.Has(1301421), "the filter's question")
assert(Cr.AskWhom(2663).name == "Anna Amboss", "an online crafter that is no own character")
assert(Cr.AskWhom(1252229) == nil, "only own characters know it")
-- who makes an item: every recipe of it, the highest rank per name
local made = Cr.ForItem(2853)
assert(#made == 3 and made[1].name == "Anna Amboss", "Kupferarmschienen")
assert(#Cr.ForItem(118) == 2 and #Cr.ForItem(12345) == 0)

-- Bob comes online: he goes up
STUB.guild[4].online = true
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)   -- the roster is built again at most every 10 s
assert(Cr.ForSpell(2663)[1].name == "Bob Hammer", "online and the highest rank")

-- a bitset of other data: not shown, and that sender is asked for lists next time
AmisiaDB.crafters.c["Bob Hammer"].p[164].h = "00000000"
Cr.Changed()
AmisiaDB.crafters.src["bob hammer"] = { d = "12345678", at = D }
assert(#Cr.ForSpell(2663) == 2, "Bob's bitset does not fit")
assert(AmisiaDB.crafters.src["bob hammer"].d == nil and AmisiaDB.crafters.src["bob hammer"].f == "L", "asked for lists next time")

---------------------------------------------------------------------------
-- the tooltip line: light, cached, with its switch
---------------------------------------------------------------------------
STUB.item(2853, "Kupferarmschienen", 1)
local tip = CreateFrame("GameTooltip", "CraftTip")
local lines = {}
tip.AddLine = function(_, t) lines[#lines + 1] = t end
local function show(id)
    wipe(lines)
    if tip.scripts.OnTooltipCleared then tip.scripts.OnTooltipCleared(tip) end
    tip.shownLink = STUB.items[id] and STUB.items[id].link or STUB.link(id, "X", 2)
    for _, h in ipairs(STUB.tdp) do h.fn(tip) end
    for _, l in ipairs(lines) do if has(l, "Kann herstellen") then return l end end
    return nil
end
local line = show(2853)
assert(line == "Kann herstellen: Anna Amboss (250), Vulo Sturmwind (45)", tostring(line))
assert(show(12345) == nil, "no line for an item nobody makes")
-- cached: a change of the roster alone does not rebuild it within 30 s
STUB.guild[3].online = false
STUB.fire("GUILD_ROSTER_UPDATE")
assert(show(2853) == line, "cached")
STUB.tick(11)
assert(show(2853) == line, "still cached")
STUB.tick(20)
assert(show(2853) == "Kann herstellen: Vulo Sturmwind (45), Anna Amboss (250)", show(2853))
NS.Set("crafters.tooltip", false)
assert(show(2853) == nil, "switched off")
NS.Set("crafters.tooltip", true)

---------------------------------------------------------------------------
-- the store at load: malformed, old and too many go
---------------------------------------------------------------------------
local c = AmisiaDB.crafters.c
c["Alt Lang"] = { via = "Alt Lang", seen = D - 46, p = { [164] = { r = 1, m = 1, h = h164, b = "01" } } }
c["Kaputt Eins"] = { via = "x", seen = D, p = { [164] = { r = 1000, m = 1, h = h164, b = "01" } } }
c["Kaputt Zwei"] = { via = "x", seen = D, p = { [164] = { r = 1, m = 1, h = h164, b = "zz" } } }
c["|cffff0000Rot"] = { via = "x", seen = D, p = { [164] = { r = 1, m = 1, h = h164, b = "01" } } }
c["Kaputt Drei"] = "nein"
c["Fast Alt"] = { via = "Fast Alt", seen = D - 45, p = { [164] = { r = 1, m = 1, h = h164, b = "01" } } }
AmisiaDB.crafters.src["weg"] = { d = "12345678", at = D - 50 }
assert(Cr.Prune() == 5, "five went")
assert(c["Fast Alt"] and c["Anna Amboss"] and not c["Alt Lang"] and not c["Kaputt Eins"] and not c["Kaputt Zwei"])
assert(AmisiaDB.crafters.src["weg"] == nil and AmisiaDB.crafters.src["anna amboss"], "old senders go too")
-- above the cap the oldest go
NS.CRAFTERS_LIMITS.storeMax = 3
assert(Cr.Prune() == 2 and c["Anna Amboss"] and c["Cleo Kessel"] and not c["Fast Alt"], "the oldest went")
NS.CRAFTERS_LIMITS.storeMax = 500
-- a store of another shape is replaced
AmisiaDB.crafters = { v = 9 }
Cr.Prune()
assert(AmisiaDB.crafters == nil, "not kept")

---------------------------------------------------------------------------
-- the whisper: the client's own function with a prefilled text
---------------------------------------------------------------------------
local said
ChatFrameUtil.SendTellWithMessage = function(name, text) said = { name, text } end
assert(Cr.Whisper("Anna Amboss", "[Kupferarmschienen]"))
assert(said[1] == "Anna Amboss" and said[2] == "Hallo! Kannst du mir [Kupferarmschienen] herstellen? Die Materialien bringe ich mit.", said[2])
ChatFrameUtil.SendTellWithMessage = nil
local opened
ChatFrame_OpenChat = function(text) opened = text end
assert(Cr.Whisper("Anna Amboss", "X") and opened == "/w Anna Amboss Hallo! Kannst du mir X herstellen? Die Materialien bringe ich mit.")
ChatFrame_OpenChat = nil
assert(Cr.Whisper("Anna Amboss", "X") == false, "no way to whisper: nothing breaks")
assert(Cr.Whisper(nil, "X") == false)

-- the settings
assert(NS.Get("crafters.share") == true and NS.Get("crafters.tooltip") == true)
NS.Dispatch("hersteller")
