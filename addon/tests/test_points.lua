-- DKP and EPGP (Raid/Points.lua): the models (rounding, decay, PR, the GP formula and the slot
-- weights), the hostile "!bid" text, the website's "#AMISIA-PTS" block (with the wishes, alts and
-- prio in one paste), the earnings of a raid (raid, boss, on time, bench; alts for their main), the
-- cost of an award (undo, delete, rename follow it), corrections with a reason, the live standings
-- (site + what the site does not have yet) and the export lines PS, PE, PA and PX.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

STUB.now = 1791400000
STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
                { name = "Kim Eisherz", class = "MAGE" } }

---------------------------------------------------------------------------
-- the system and its settings
---------------------------------------------------------------------------
assert(NS.PointsSystem() == "roll", "rolling stays the default")
local it = NS.SettingItem("points.system")
assert(it and it.type == "choice" and it.default == "roll" and it.section.officer, "an officers' setting")
local cfg = NS.PointsConfig()
assert(cfg.sys == "roll" and cfg.raid == 10 and cfg.min == 10 and cfg.step == 5 and cfg.base == 100 and cfg.os == 50 and cfg.mode == "bid")

---------------------------------------------------------------------------
-- the models
---------------------------------------------------------------------------
assert(NS.PointsRound(2.5) == 3 and NS.PointsRound(-2.5) == -3 and NS.PointsRound(2.49) == 2 and NS.PointsRound(-0.4) == 0, "half away from zero")
assert(NS.PointsDecayed(100, 10) == 90 and NS.PointsDecayed(-55, 10) == -50 and NS.PointsDecayed(15, 10) == 14, "decay rounds")
assert(NS.PointsDecayed(5, 0) == 5 and NS.PointsDecayed(5, 100) == 0)
assert(NS.PointsPR(200, 0, 100) == 2 and NS.PointsPR(0, 50, 100) == 0, "PR = EP / (GP + base)")
assert(NS.PointsPR(10, -200, 100) > 0, "a GP below zero never divides by zero or turns PR round")
assert(NS.PointsCompare({ e = 300, g = 50 }, { e = 200, g = 0 }, { base = 100 }) == 0, "2 against 2: equal (cross product)")
assert(NS.PointsCompare({ e = 301, g = 50 }, { e = 200, g = 0 }, { base = 100 }) > 0)
assert(NS.PointsPRText(1.2345) == NS.Num(1.23, 2) and NS.PointsPRText(12.345) == NS.Num(12.3, 1), NS.PointsPRText(1.2345))
assert(NS.PointsSlotWeight("INVTYPE_HEAD") == 1 and NS.PointsSlotWeight("INVTYPE_2HWEAPON") == 2 and NS.PointsSlotWeight("INVTYPE_FINGER") == 0.5)
assert(NS.PointsSlotWeight("INVTYPE_WEAPONMAINHAND") == 1.5 and NS.PointsSlotWeight("INVTYPE_SHIELD") == 0.5 and NS.PointsSlotWeight("INVTYPE_ROBE") == 1)
assert(NS.PointsSlotWeight(nil) == 1 and NS.PointsSlotWeight("") == 1 and NS.PointsSlotWeight("INVTYPE_NON_EQUIP_IGNORE") == 1, "a token weighs 1")
-- GP = scale * 2^((ilvl - ref)/26) * weight * 2^(quality - 4)
local E = { scale = 100, ref = 66, os = 50, price = 50 }
assert(NS.PointsFormula(66, "INVTYPE_CHEST", 4, 100, 66) == 100)
assert(NS.PointsFormula(92, "INVTYPE_CHEST", 4, 100, 66) == 200, "26 levels double it")
assert(NS.PointsFormula(92, "INVTYPE_2HWEAPON", 4, 100, 66) == 400)
assert(NS.PointsFormula(66, "INVTYPE_HEAD", 3, 100, 66) == 50, "a blue item half")
assert(NS.PointsFormula(66, "INVTYPE_FINGER", 5, 100, 66) == 100, "a legendary ring")
local link = STUB.item(30000, "Brustplatte", 4)
STUB.items[30000].ilvl, STUB.items[30000].equipLoc = 92, "INVTYPE_CHEST"
assert(NS.PointsItemCost(30000, "MS", E) == 200 and NS.PointsItemCost(link, "OS", E) == 100 and NS.PointsItemCost(30000, "SR", E) == 200)
assert(NS.PointsItemCost(30000, "-", E) == 0, "bank and disenchant cost nothing")
assert(NS.PointsItemCost(99999, "MS", E) == nil, "an item the client does not know: no cost")

---------------------------------------------------------------------------
-- "!bid 50": hostile text
---------------------------------------------------------------------------
local good = { ["50"] = 50, [" 50 "] = 50, ["50 dkp"] = 50, ["50DKP"] = 50, ["0050"] = 50, ["1"] = 1, ["999999"] = 999999 }
for text, n in pairs(good) do assert(NS.PointsParseBid(text) == n, text) end
local bad = { "", "-5", "+5", "5.5", "5,5", "1e3", "0x10", "1000000", "12345678901234567890", "fifty", "50 60", "50 os",
              "|cffff0000|Hitem:1|h[x]|h|r 50", "50|r", "\0" .. "50", "５０", "inf", "nan", "50" .. ("a"):rep(40), "0" }
for _, text in ipairs(bad) do
    local n, why = NS.PointsParseBid(text)
    assert(n == nil and type(why) == "string", "refused: " .. text)
end
assert(NS.PointsParseBid(nil) == nil and NS.PointsParseBid(50) == nil)

---------------------------------------------------------------------------
-- the website's block
---------------------------------------------------------------------------
local SITE = table.concat({
    "#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000",
    "CFG raid=20 boss=5 time=5 bench=10 mode=bid seal=1 min=20 step=10 decay=10 price=50 base=100 minep=0 scale=100 ref=66 os=50 pub=1 x=7",
    "P Vuloo 120",
    "P Fraktur 80",
    "P Kim_Eisherz 300",
    "P Chorf -15",
    "P Kaputt1 5",
    "P Leer",
    "P Doppelt 1 2 3",
    "R 20261001200000-533 20261002200000-533",
    "I 0123456789ab 0123456789ac zz",
    "kaputt",
    "#END",
    "P Danach 1",
}, "\n")
local res, why = NS.ParsePointsSite(SITE)
assert(res, tostring(why))
assert(res.sys == "dkp" and res.date == "2026-10-08" and res.asOf == 1791300000)
assert(res.cfg.raid == 20 and res.cfg.seal == 1 and res.cfg.min == 20 and res.cfg.pub == 1 and res.cfg.x == nil, "known keys only")
assert(res.n == 4 and res.list["vuloo"].a == 120 and res.list["kim eisherz"].name == "Kim Eisherz" and res.list["chorf"].a == -15)
assert(res.list["danach"] == nil and res.skipped == 5, "a digit, no number, too many numbers, a broken I id, a stray line: " .. res.skipped)
assert(res.raids["20261001200000-533"] and res.ids["0123456789ab"] and res.ids["0123456789ac"])
assert(NS.ParsePointsSite("#AMISIA-PTS 1 tbc 2026-10-08 dkp 1") == nil, "another game")
assert(NS.ParsePointsSite("#AMISIA-PTS 1 forever 2026-10-08 golf 1\n#END") == nil, "an unknown system")
assert(NS.ParsePointsSite("#AMISIA-PTS 2 forever 2026-10-08 dkp 1\n#END") == nil, "another version")
assert(NS.ParsePointsSite("hallo") == nil and NS.ParsePointsSite(nil) == nil)
do
    local r2 = NS.ParsePointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1\nCFG raid=99999999 min=-5 seal=7 mode=golf decay=101\n#END")
    assert(r2 and r2.cfg.raid == nil and r2.cfg.min == nil and r2.cfg.seal == nil and r2.cfg.mode == nil and r2.cfg.decay == nil, "out of range values are left out")
end
-- EPGP: two numbers
do
    local r3 = NS.ParsePointsSite("#AMISIA-PTS 1 forever 2026-10-08 epgp 1\nP Vuloo 500 120\nP Fraktur 50\n#END")
    assert(r3.list["vuloo"].a == 500 and r3.list["vuloo"].b == 120 and r3.list["fraktur"] == nil and r3.skipped == 1, "EPGP needs EP and GP")
end

-- pasted with the other blocks in one text: an officer takes system and settings over
local all = "#AMISIA-WL 1 forever 2026-10-08\nW 32235 3 Anna\n#END\n" .. SITE
local text, ok = NS.ImportSiteText(all)
assert(ok and has(text, "4 Punktestände"), text)
assert(NS.PointsSystem() == "dkp" and NS.Get("points.raid") == 20 and NS.Get("points.sealed") == true and NS.Get("points.minBid") == 20)
assert(NS.PointsInfo().n == 4 and NS.PointsInfo().date == "2026-10-08")

---------------------------------------------------------------------------
-- standings from the site
---------------------------------------------------------------------------
assert(NS.PointsOf("Vuloo").a == 120 and NS.PointsOf("Kim Eisherz").a == 300 and NS.PointsOf("Chorf").a == -15)
assert(NS.PointsOf("Niemand").a == 0, "nobody has 0")
local st = NS.PointsStandings()
assert(st[1].name == "Kim Eisherz" and st[#st].name == "Chorf", "highest first")

-- alts count for their main
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-08\nA Kimtwink Kim_Eisherz\n#END"))
assert(NS.PointsOf("Kimtwink").a == 300 and NS.PointsOf("Kimtwink").name == "Kim Eisherz", "an alt bids with the main's points")

---------------------------------------------------------------------------
-- a raid: earnings
---------------------------------------------------------------------------
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.points and s.points.sys == "dkp" and s.points.cfg.raid == 20, "a new raid freezes the system")
-- Chorf came late, Kimtwink (an alt) was there, Gast sat on the bench, two kills
s.members["Chorf"].late = true
s.members["Kim Eisherz"] = nil
STUB.roster[4] = { name = "Kimtwink", class = "MAGE" }
NS.NoteMember(s, "Kimtwink", "MAGE", STUB.now)
s.members["Kimtwink"].late = nil
s.bench = { Gast = { t = STUB.now, class = "ROGUE", by = "Vuloo" }, Fraktur = { t = STUB.now } }
s.kills = {
    { enc = 1107, name = "Anub'Rekhan", start = STUB.now, t = STUB.now + 60, ok = true, who = { "Vuloo", "Fraktur", "Kimtwink" } },
    { enc = 1108, name = "Faerlina", start = STUB.now + 100, t = STUB.now + 160, ok = false, who = { "Vuloo" } },
    { enc = 1109, name = "Maexxna", start = STUB.now + 200, t = STUB.now + 260, ok = true, who = { "Vuloo", "Chorf" } },
    { enc = 1110, name = "Noth", start = STUB.now + 300, t = STUB.now + 360, ok = true, wait = true },
}
local earn = NS.PointsRaidEarnings(s)
local sum = {}
for _, e in ipairs(earn) do
    sum[e.char] = (sum[e.char] or 0) + e.n
    assert(type(e.id) == "string" and #e.id == 12 and e.id:match("^%x+$"), "a 12 hex id")
end
assert(sum.Vuloo == 20 + 5 + 5 + 5, "raid, two kills, on time: " .. tostring(sum.Vuloo))
assert(sum.Chorf == 20 + 5, "late: no bonus, one kill")
assert(sum.Kimtwink == 20 + 5 + 5)
assert(sum.Gast == 10, "the bench")
assert(sum.Fraktur == 20 + 5 + 5, "on the bench and in the raid: the raid counts")
local again = NS.PointsRaidEarnings(s)
assert(again[1].id == earn[1].id, "the same ids on every call")
assert(NS.PointsOf("Kim Eisherz").a == 300 + 30, "the alt's earnings for the main, live")
assert(NS.PointsOf("Vuloo").a == 120 + 35)

-- a raid out of the count, and back
assert(NS.PointsRaidOff(s, true))
assert(NS.PointsOf("Vuloo").a == 120 and #NS.PointsRaidEarnings(s) == 0)
NS.PointsRaidOff(s, false)
assert(NS.PointsOf("Vuloo").a == 155)

---------------------------------------------------------------------------
-- the cost of an award: undo, delete, rename and restore follow it
---------------------------------------------------------------------------
local a = NS.AddAwardTo(s, { name = "Kimtwink", item = 30000, kind = "MS", src = "Anub'Rekhan", t = STUB.now + 70 })
assert(NS.SetAwardPoints(s, a.id, 60))
assert(NS.AwardPoints(s, a.id).n == 60 and NS.AwardPoints(s, a.id).p == "D")
assert(NS.PointsOf("Kim Eisherz").a == 330 - 60, "the main pays")
assert(NS.SetAwardPoints(s, a.id, -1) == nil and NS.SetAwardPoints(s, a.id, 1e9) == nil and NS.SetAwardPoints(s, "nope", 5) == nil)
NS.EditAward(s, a.id, { name = "Fraktur" })
assert(NS.PointsOf("Kim Eisherz").a == 330 and NS.PointsOf("Fraktur").a == 80 + 30 - 60, "a new winner pays instead")
NS.UndoAward()
assert(NS.PointsOf("Kim Eisherz").a == 270)
NS.UndoAward()   -- the add itself
assert(NS.PointsOf("Kim Eisherz").a == 330, "an award taken back costs nothing")
NS.UndoAward()
assert(NS.PointsOf("Kim Eisherz").a == 330, "nothing left to undo")
a = NS.AddAwardTo(s, { name = "Kimtwink", item = 30000, kind = "MS", src = "Anub'Rekhan", t = STUB.now + 70 })
NS.SetAwardPoints(s, a.id, 60)
NS.DeleteAward(s, a.id)
assert(NS.PointsOf("Kim Eisherz").a == 330)
NS.RestoreAward(s, a.id)
assert(NS.PointsOf("Kim Eisherz").a == 270)
-- a bank award never costs
local bankA = NS.AddAwardTo(s, { name = "-", item = 30000, to = "bank", t = STUB.now + 80 })
assert(NS.SetAwardPoints(s, bankA.id, 10) == nil, "no cost for the bank")
-- the history names the item and the boss
local hist = NS.PointsHistory("Kim Eisherz")
local seen = {}
for _, h in ipairs(hist) do seen[h.code] = (seen[h.code] or 0) + h.n end
assert(seen.R == 20 and seen.B == 5 and seen.T == 5 and seen.A == -60, "history per kind")
assert(seen.S == 300, "the site's standing as the start")

---------------------------------------------------------------------------
-- corrections: an officer, a reason, a number
---------------------------------------------------------------------------
local c, cwhy = NS.PointsAdjust("Kim Eisherz", 25, "")
assert(c == nil and cwhy == "Ein Grund fehlt.", tostring(cwhy))
assert(NS.PointsAdjust("Kim Eisherz", 0, "nichts") == nil and NS.PointsAdjust("Kim Eisherz", 1e7, "zu viel") == nil)
assert(NS.PointsAdjust("X1", 5, "Ziffer") == nil)
c = NS.PointsAdjust("Kimtwink", -25, "Zu spät abgemeldet |cffff0000rot|r")
assert(c and c.name == "Kim Eisherz" and c.n == -25 and c.pool == "D" and c.reason == "Zu spät abgemeldet rot" and c.by == "Vuloo")
assert(NS.PointsOf("Kim Eisherz").a == 245)
NS.Set("ui.view", "raider")
assert(NS.PointsAdjust("Vuloo", 5, "Raider") == nil, "raiders correct nothing")
NS.Set("ui.view", "auto")

---------------------------------------------------------------------------
-- export
---------------------------------------------------------------------------
local exp = NS.ExportText({ s })
assert(has(exp, "\nPS D dkp on\n"), "the system of the raid")
assert(has(exp, ("\nPA %s D 60 "):format(a.id)), "the cost of the award")
local pe = 0
for line in exp:gmatch("[^\n]+") do
    if line:match("^PE ") then
        pe = pe + 1
        assert(line:match("^PE %x+ %S+ %d+ [RBTN] %d+"), line)
    end
end
assert(pe == #NS.PointsRaidEarnings(s), "every earning")
assert(has(exp, "PE ") and has(exp, " Kimtwink 20 R "), "the character name, the site finds the main")
assert(has(exp, " B ") and has(exp, " Anub'Rekhan"), "a kill with its boss")
assert(has(exp, ("\nPX %s Kim_Eisherz D -25 "):format(c.id)) and has(exp, " Vuloo Zu spät abgemeldet rot"), "the correction with its reason")
-- PS stands before the earnings, inside the raid block, before E
local ps, e = exp:find("\nPS "), exp:find("\nE\n") or exp:find("\nE$")
assert(ps and e and ps < e)
-- a raid without a system writes nothing new
local old = { id = "x", date = "2026-10-01", instanceID = 533, zone = "Naxx", members = {}, loot = {}, items = {}, drops = {},
              awards = {}, gone = {}, kills = {}, bench = {} }
do
    local t = NS.ExportText({ old })
    assert(not has(t, "\nPS ") and not has(t, "\nPE ") and not has(t, "\nPA "), "a raid from before writes no new raid line")
end

-- the site has the raid and the correction now: they leave the live part
local SITE2 = ("#AMISIA-PTS 1 forever 2026-10-09 dkp 1791500000\nP Kim_Eisherz 245\nP Vuloo 155\nR %s\nI %s %s\n#END"):format(s.id, a.id, c.id)
assert(NS.SetPointsSite(SITE2))
assert(NS.PointsOf("Kim Eisherz").a == 245, "nothing counted twice: " .. NS.PointsOf("Kim Eisherz").a)
assert(NS.PointsOf("Vuloo").a == 155)
assert(#NS.PointsExportLines() == 0, "a correction the site has goes no more")
-- a later correction still counts
NS.PointsAdjust("Vuloo", 5, "Bonus")
assert(NS.PointsOf("Vuloo").a == 160 and #NS.PointsExportLines() == 1)

---------------------------------------------------------------------------
-- EPGP
---------------------------------------------------------------------------
assert(NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-09 epgp 1791500000\nCFG raid=10 boss=10 time=5 bench=10 base=100 minep=50 scale=100 ref=66 os=50\nP Vuloo 500 100\nP Fraktur 300 50\nP Chorf 40 0\n#END"))
assert(NS.PointsSystem() == "epgp")
local v = NS.PointsOf("Vuloo")
assert(v.a == 500 and v.b == 100 and v.pr == 2.5, tostring(v.pr))
assert(NS.PointsOf("Fraktur").pr == 2)
assert(NS.PointsOf("Chorf").low, "under the minimum EP")
st = NS.PointsStandings()
assert(st[1].name == "Vuloo" and st[#st].name == "Chorf", "by PR, below the minimum last")
-- the running raid was DKP: its earnings do not count as EP
assert(NS.PointsOf("Vuloo").a == 500)
-- an award in an EPGP raid costs GP
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil)
STUB.now = STUB.now + 3 * 3600
STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s2 = NS.Active()
assert(s2 and s2 ~= s and s2.points.sys == "epgp")
local b = NS.AddAwardTo(s2, { name = "Fraktur", item = 30000, kind = "OS", src = "Noth", t = time() })
assert(NS.SetAwardPoints(s2, b.id, 100) and NS.AwardPoints(s2, b.id).p == "G")
assert(NS.PointsOf("Fraktur").b == 150 and NS.PointsOf("Fraktur").a >= 300 + 10, "GP up, the raid's EP in")
local corr = NS.PointsAdjust("Fraktur", 20, "Nachtrag", "gp")
assert(corr and corr.pool == "G" and NS.PointsOf("Fraktur").b == 170)
assert(has(NS.ExportText({ s2 }), "\nPS E epgp on\n"))

---------------------------------------------------------------------------
-- slash commands and the raider's view
---------------------------------------------------------------------------
NS.Dispatch("punkte Fraktur")
assert(has(lastMsg(), "Fraktur") and has(lastMsg(), "EP"), lastMsg())
NS.Dispatch("points Vuloo")
assert(has(lastMsg(), "Vuloo"), lastMsg())
NS.Dispatch("korrektur Chorf +15 Pünktlich nachgetragen")
assert(NS.PointsOf("Chorf").a == 40 + 15 + 0 or NS.PointsOf("Chorf").a >= 55, lastMsg())
NS.Dispatch("adjust Chorf 5 gp Fehler")
assert(has(lastMsg(), "Chorf"), lastMsg())
NS.Dispatch("korrektur Chorf 5")
assert(has(lastMsg(), "Aufruf"), lastMsg())
NS.Dispatch("punkteraid aus")
assert(s2.points.off == true)
NS.Dispatch("raidpoints on")
assert(not s2.points.off)

-- a raider sees the own row, the list only when the site shows it
NS.Set("ui.view", "raider")
STUB.player = "Chorf"
assert(#NS.PointsStandings() == 1 and NS.PointsStandings()[1].name == "Chorf", "own row only (pub off)")
NS.Set("ui.view", "auto")
STUB.player = "Vuloo"

-- clearing
NS.ClearPoints()
assert(NS.PointsInfo() == nil or NS.PointsInfo().n == 0)
