-- Alts from the website (Alts.lua): the parser (head, wrong game, empty, broken lines, chains, an
-- alt of itself, escape codes), storing, ns.MainOf / ns.AltMain / ns.AltsOf / ns.SameMain with
-- spellings without surname, the import of wishes and alts in one text on the gear page, the
-- plus-one of a player over all characters (count, list, roll order, the keeper's number under
-- every linked name, a raider looking up an alt), the roll window and raid details naming the
-- main, and /amisia twinks.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end

---------------------------------------------------------------------------
-- the parser
---------------------------------------------------------------------------
local TEXT = table.concat({
    "",
    "#AMISIA-ALTS 1 forever 2026-10-06",
    "A Bob Anna",
    "A Kim_Eisherz Vulo_Sturmwind",
    "A Zed |cffff0000Anna|r",
    "A Anna Bob",            -- Anna is a main: no chains
    "A Bob Carla",           -- Bob twice: the first line stays
    "A Selbst selbst",       -- an alt of itself
    "A Nur",                 -- no main
    "A X1 Anna",             -- a digit
    "kaputt",
    "#END",
    "A Danach Anna",
}, "\r\n")
local res, why = NS.ParseAlts(TEXT)
assert(res, tostring(why))
assert(res.game == "forever" and res.date == "2026-10-06", "head read")
assert(res.n == 3, "three alts: " .. tostring(res.n))
assert(res.skipped == 6, "six lines skipped: " .. tostring(res.skipped))
assert(res.list[1].alt == "Bob" and res.list[1].main == "Anna")
assert(res.list[2].alt == "Kim Eisherz" and res.list[2].main == "Vulo Sturmwind", "an underscore is a space")
assert(res.list[3].alt == "Zed" and res.list[3].main == "Anna", "no escape codes from a paste: " .. res.list[3].main)

local function reason(text)
    local r, w = NS.ParseAlts(text)
    assert(r == nil, "refused")
    return w
end
assert(reason("hallo\nA Bob Anna") == "Das ist keine Twink-Liste der Amisia-Seite.")
assert(reason("#AMISIA-WL 1 forever 2026-10-06\nW 1 2 Anna\n#END") == "Das ist keine Twink-Liste der Amisia-Seite.")
assert(reason("#AMISIA-ALTS 1 tbc 2026-10-06\nA Bob Anna\n#END") == "Diese Twink-Liste ist für TBC Anniversary, du bist in WoW Forever.")
assert(reason("#AMISIA-ALTS 2 forever 2026-10-06\nA Bob Anna\n#END") == "Das ist keine Twink-Liste der Amisia-Seite.", "an unknown version")
assert(reason("#AMISIA-ALTS 1 forever 2026-10-06\n#END") == "Die Twink-Liste ist leer.")
assert(reason(nil) == "Das ist keine Twink-Liste der Amisia-Seite.")

---------------------------------------------------------------------------
-- storing and the lookups
---------------------------------------------------------------------------
assert(NS.AltsInfo() == nil and NS.MainOf("Bob") == "Bob" and NS.AltMain("Bob") == nil, "no list: everyone is their own main")
local fired = 0
NS.Listen("ALTS", function() fired = fired + 1 end)
assert(NS.SetAlts(TEXT))
assert(fired == 1 and AmisiaDB.alts and AmisiaDB.alts.n == 3 and AmisiaDB.alts.date == "2026-10-06")
assert(NS.AltsInfo().n == 3)
assert(NS.MainOf("Bob") == "Anna" and NS.MainOf("bob") == "Anna", "any case")
assert(NS.MainOf("Anna") == "Anna" and NS.MainOf("Niemand") == "Niemand")
assert(NS.MainOf("Kim") == "Vulo Sturmwind", "a spelling without surname, one entry fits")
assert(NS.MainOf("Kim Feuerherz") == "Kim Feuerherz", "another surname is another character")
assert(NS.AltMain("Kim Eisherz") == "Vulo Sturmwind" and NS.AltMain("Anna") == nil)
assert(NS.MainOf(nil) == nil and NS.MainOf("") == nil)
local alts = NS.AltsOf("Anna")
assert(#alts == 2 and alts[1] == "Bob" and alts[2] == "Zed", "sorted")
assert(#NS.AltsOf("Vulo") == 1, "the main by first name")
assert(NS.SameMain("Bob", "Anna") and NS.SameMain("Bob", "Zed") and NS.SameMain("Kim Eisherz", "Vulo Sturmwind"))
assert(not NS.SameMain("Bob", "Vulo Sturmwind") and not NS.SameMain("Niemand", "Anna"))
assert(NS.SameMain("Niemand", "niemand"), "the same character")
-- a refused text keeps the stored list
assert(NS.SetAlts("#AMISIA-ALTS 1 tbc 2026-10-06\nA Bob Anna\n#END") == nil and NS.AltsInfo().n == 3)

---------------------------------------------------------------------------
-- one paste, two blocks
---------------------------------------------------------------------------
local WL = "#AMISIA-WL 1 forever 2026-10-06\nW 28830 3 Anna\n#END"
local ALTS = "#AMISIA-ALTS 1 forever 2026-10-06\nA Bob Anna\nA Zed Anna\n#END"
local b = NS.SiteBlocks("vorher\n" .. WL .. "\n\n" .. ALTS .. "\nnachher")
assert(b.wl == WL and b.alts == ALTS, "both blocks cut out")
b = NS.SiteBlocks("#AMISIA-ALTS 1 forever 2026-10-06\nA Bob Anna")
assert(b.alts and not b.wl, "a block without its end")
NS.ClearAlts()
assert(NS.AltsInfo() == nil and NS.MainOf("Bob") == "Bob")
local text, ok = NS.ImportSiteText(WL .. "\n" .. ALTS)
assert(ok and has(text, "1 Wunsch übernommen") and has(text, "2 Twinks übernommen"), text)
assert(AmisiaDB.bis.guild.n == 1 and NS.AltsInfo().n == 2)
-- only alts: the wishes stay
text, ok = NS.ImportSiteText("#AMISIA-ALTS 1 forever 2026-10-07\nA Bob Anna\n#END")
assert(ok and text == "1 Twink übernommen." and AmisiaDB.bis.guild.n == 1 and NS.AltsInfo().n == 1, text)
-- only wishes: the alts stay
text, ok = NS.ImportSiteText(WL)
assert(ok and has(text, "1 Wunsch") and NS.AltsInfo().n == 1, text)
-- neither: the wishes' refusal
text, ok = NS.ImportSiteText("hallo")
assert(not ok and text == "Das ist keine Wunschliste der Amisia-Seite.", text)
-- one good block and one refused: the good one is taken, the refusal is said
text, ok = NS.ImportSiteText(WL .. "\n#AMISIA-ALTS 1 tbc 2026-10-06\nA Bob Anna\n#END")
assert(ok and has(text, "1 Wunsch") and has(text, "TBC Anniversary"), text)

---------------------------------------------------------------------------
-- plus-one over all characters of a player
---------------------------------------------------------------------------
assert(NS.SetAlts(ALTS))
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Bob", class = "MAGE" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)
NS.AddAwardTo(s, { name = "Anna", item = 32235, kind = "MS", src = "?" })
NS.AddAwardTo(s, { name = "Bob", item = 32837, kind = "MS", src = "?" })
NS.AddAwardTo(s, { name = "Zed", item = 32837, kind = "OS", src = "?" })
NS.AddAwardTo(s, { name = "Chorf", item = 32837, kind = "MS", src = "?" })
assert(NS.PlusCount("Bob") == 2, "Bob plays an alt of Anna: both wins count " .. NS.PlusCount("Bob"))
assert(NS.PlusCount("Anna") == 2 and NS.PlusCount("Zed") == 2, "every character of the player")
assert(NS.PlusCount("Chorf") == 1 and NS.PlusCount("Vuloo") == 0)
local list = NS.PlusList()
assert(#list == 2 and list[1].name == "Anna" and list[1].n == 2, "one entry per player, under the main")
assert(list[1].names.Anna and list[1].names.Bob and list[1].names.Zed, "the main and its alts")
assert(list[2].name == "Chorf" and list[2].n == 1)
-- the main's name even when only the alt won
NS.ClearAlts()
assert(NS.PlusCount("Bob") == 1, "without the list Bob counts alone")
assert(NS.SetAlts(ALTS))

-- the roll order with the plus-one: Bob carries Anna's wins
NS.Set("awards.plusOrder", true)
assert(NS.StartRoll(link, 10)); local r = NS.CurrentRoll()
roll("Bob", 90, 1, 100); roll("Vuloo", 50, 1, 100)
local rank = NS.RollRanking(r)
assert(rank[1].name == "Vuloo" and rank[2].name == "Bob", "fewer plus-one first")
assert(NS.PlusLabel(r, "Bob") == "+2", tostring(NS.PlusLabel(r, "Bob")))
assert(NS.ShowRollFrame and (NS.ShowRollFrame() or true))
local names = {}
for i = 1, 2 do names[i] = NS.RollFrame.rows[i].name:GetText() end
assert(has(names[2], "Bob") and has(names[2], "(Anna)"), "the alt names its main: " .. names[2])
assert(not has(names[1], "("), "a main names nobody: " .. names[1])
NS.StopRoll()
NS.Reset("awards.plusOrder")

-- the award page's plus-one column and /amisia plus
NS.Dispatch("plus")
assert(has(lastMsg(), "Anna 2") and has(lastMsg(), "Chorf 1"), lastMsg())
NS.Dispatch("plus Bob")
assert(has(lastMsg(), "Bob") and has(lastMsg(), ": 2."), lastMsg())

---------------------------------------------------------------------------
-- the keeper's snapshot: the number under the main and every linked name
---------------------------------------------------------------------------
local sp = NS.SyncBuild(s)
assert(sp.p.n.Anna == 2 and sp.p.n.Bob == 2 and sp.p.n.Zed == 2, "every name of the player")
assert(sp.p.n.Chorf == 1 and sp.p.n.Vuloo == nil)
-- a raider (not the keeper, no officer) counts with the keeper's number, found by the alt's name
-- even without an own alt list
s.sync = s.sync or {}
s.sync.plus = { s = "raid", n = { Anna = 3, Chorf = 1 } }
local keeper, officer = NS.SyncIsKeeper, NS.IsOfficerView
NS.SyncIsKeeper = function() return false end
NS.IsOfficerView = function() return false end
assert(NS.PlusCount("Bob") == 3, "by the main: " .. NS.PlusCount("Bob"))
assert(NS.PlusCount("Chorf") == 1)
s.sync.plus = { s = "raid", n = { Anna = 3, Bob = 3 } }
NS.ClearAlts()
assert(NS.PlusCount("Bob") == 3, "a raider without the list finds the alt's own line")
NS.SyncIsKeeper, NS.IsOfficerView = keeper, officer
s.sync.plus = nil
assert(NS.SetAlts(ALTS))

---------------------------------------------------------------------------
-- the raid details name the main of an alt
---------------------------------------------------------------------------
local detail = NS.RaidDetailText(s)
assert(has(detail, "Bob (Twink von Anna)"), detail)
assert(not has(detail, "Vuloo (Twink"), detail)

---------------------------------------------------------------------------
-- /amisia twinks
---------------------------------------------------------------------------
NS.Dispatch("twinks")
assert(has(lastMsg(), "Twink-Liste vom 2026-10-06: 2 Twinks"), lastMsg())
NS.Dispatch("twinks Bob")
assert(has(lastMsg(), "Bob ist ein Twink von Anna"), lastMsg())
NS.Dispatch("twinks Anna")
assert(has(lastMsg(), "Twinks von Anna: Bob, Zed"), lastMsg())
NS.Dispatch("twinks Chorf")
assert(has(lastMsg(), "Chorf hat keine Twinks"), lastMsg())
NS.Dispatch("alts löschen")
assert(NS.AltsInfo() == nil and has(lastMsg(), "gelöscht"), lastMsg())
NS.Dispatch("twinks")
assert(has(lastMsg(), "Keine Twink-Liste"), lastMsg())
