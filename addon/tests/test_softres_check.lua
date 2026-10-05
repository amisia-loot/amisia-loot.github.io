--[[preload
-- a list saved by 1.5 (no version)
AmisiaDB = { softres = { date = "2026-09-30", byItem = { [32235] = { "Fraktur" } }, raw = "Fraktur 32235", count = 1 } }
]]
-- Soft-reserves, data model 2: the move from 1.5, double reservations, remembered name fixes, the
-- check against the raid, renaming, the roll ranking with surnames and the tooltip processor.

-- the move on load
local sr = AmisiaDB.softres
assert(sr.version == 2, "moved on ADDON_LOADED")
assert(type(sr.times) == "table" and type(sr.renamed) == "table" and type(sr.reminded) == "table")
assert(sr.byItem[32235][1] == "Fraktur" and sr.count == 1 and sr.raw == "Fraktur 32235" and sr.date == "2026-09-30", "nothing lost")
assert(type(AmisiaDB.srAliases) == "table")
-- a second load changes nothing
sr.times[32235] = { Fraktur = 2 }
AmisiaDB.srAliases["x"] = "Y"
NS.MigrateSoftRes(AmisiaDB)
assert(sr.times[32235].Fraktur == 2 and AmisiaDB.srAliases.x == "Y" and sr.version == 2)
AmisiaDB.srAliases.x = nil
-- no list: only the aliases appear
local db = {}
NS.MigrateSoftRes(db)
assert(db.softres == nil and type(db.srAliases) == "table")

-- double lines count in times; byItem keeps one name
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 4)
local byItem, count, bad, times, total = NS.ParseSoftRes("Vulo 32235\nVulo 32235\nFraktur 32235\nvulo " .. link .. "\nFraktur 32837\n")
assert(#bad == 0)
assert(#byItem[32235] == 2 and byItem[32235][1] == "Fraktur" and byItem[32235][2] == "Vulo", table.concat(byItem[32235], ","))
assert(count == 3, "distinct reservations " .. count)
assert(times[32235].Vulo == 3 and times[32235].Fraktur == nil and times[32837] == nil, "times holds only doubles")
assert(total == 5, "all reservations " .. tostring(total))
NS.SetSoftRes("Vulo 32235\nVulo 32235\nFraktur 32235\n")
sr = AmisiaDB.softres
assert(sr.version == 2 and sr.count == 3 and sr.times[32235].Vulo == 2, "stored count holds doubles")
assert(next(sr.renamed) == nil and next(sr.reminded) == nil)
-- reminded is cleared by a new import
sr.reminded.Chorf = 1
NS.SetSoftRes("Fraktur 32235")
assert(next(AmisiaDB.softres.reminded) == nil)

-- remembered name fixes act while parsing (after the name is cleaned up)
AmisiaDB.srAliases["vulo sturmwnd"] = "Vulo Sturmwind"
local renamed
byItem, count, bad, times, total, renamed = NS.ParseSoftRes("vulo sturmwnd 32235\nvulo   sturmwnd 32837\n")
assert(byItem[32235][1] == "Vulo Sturmwind" and byItem[32837][1] == "Vulo Sturmwind", byItem[32235][1])
assert(renamed["Vulo Sturmwind"] == "Vulo sturmwnd", tostring(renamed["Vulo Sturmwind"]))
NS.SetSoftRes("vulo sturmwnd 32235")
assert(AmisiaDB.softres.renamed["Vulo Sturmwind"] == "Vulo sturmwnd")
AmisiaDB.srAliases["vulo sturmwnd"] = nil

-- the check against the raid
local roster = { "Fraktur", "Chorf", "Vulo Sturmwind", "Anna Bergmann", "Bobbington", "Zea" }
local b, _, _, t = NS.ParseSoftRes("Fraktur 32235\nFraktur 32235\nFraktur 32837\nVulo 32837\nBobingtn 32235\nZed 32235\nGustav 32235\nAnna Feldmann 32837\n")
local c = NS.SoftResCheck({ byItem = b, times = t }, roster)
local function names(l) return table.concat(l, ",") end
assert(c.roster == 6 and c.reservers == 6, c.roster .. " " .. c.reservers)
assert(names(c.ok) == "Fraktur,Vulo Sturmwind", names(c.ok))
assert(names(c.missing) == "Anna Bergmann,Bobbington,Chorf,Zea", names(c.missing))
assert(names(c.absent) == "Anna Feldmann,Bobingtn,Gustav,Zed", names(c.absent))
assert(#c.unclear == 3, #c.unclear)
assert(c.unclear[1].name == "Anna Feldmann" and c.unclear[1].kind == "typo" and c.unclear[1].suggest[1] == "Anna Bergmann", "same first name")
assert(c.unclear[2].name == "Bobingtn" and c.unclear[2].kind == "typo" and names(c.unclear[2].suggest) == "Bobbington", "two letters apart")
assert(c.unclear[3].name == "Vulo" and c.unclear[3].kind == "surname" and names(c.unclear[3].suggest) == "Vulo Sturmwind", "without surname")
assert(#c.over == 0, "no limit, no check")
assert(#c.multi == 1 and c.multi[1].name == "Fraktur" and c.multi[1].item == 32235 and c.multi[1].n == 2)
-- a short name gets no suggestion (Zed against Zea)
for _, u in ipairs(c.unclear) do assert(u.name ~= "Zed") end
-- with a limit the sum per name counts, doubles included
assert(NS.Set("softres.limit", 2))
c = NS.SoftResCheck({ byItem = b, times = t }, roster)
assert(#c.over == 1 and c.over[1].name == "Fraktur" and c.over[1].n == 3)
NS.Reset("softres.limit")
-- at most three suggestions, nearest first
b = NS.ParseSoftRes("Karaa 32235\n")
c = NS.SoftResCheck({ byItem = b, times = {} }, { "Karab", "Kxrxx", "Karbb", "Kara", "Karaaaa" })
assert(#c.unclear == 1 and #c.unclear[1].suggest == 3, #c.unclear[1].suggest)
assert(c.unclear[1].suggest[1] == "Kara" or c.unclear[1].suggest[1] == "Karab", c.unclear[1].suggest[1])
assert(c.unclear[1].suggest[3] ~= "Kxrxx")
-- secret or empty names in the roster are left out; no list: nil
c = NS.SoftResCheck({ byItem = {}, times = {} }, {})
assert(c.roster == 0 and c.reservers == 0)

-- roster: the raid, else the last raid
STUB.roster = { { name = "Fraktur Berg", class = "SHAMAN" }, { name = "Geheim", class = "PRIEST" }, { name = "Chorf", class = "WARRIOR" } }
STUB.secret.Geheim = true
local r, label = NS.SoftResRoster()
assert(names(r) == "Chorf,Fraktur Berg" and label == "Raid (3)", names(r) .. " " .. tostring(label))
STUB.secret.Geheim = nil
STUB.roster = {}
r, label = NS.SoftResRoster()
assert(#r == 0 and label == nil, "no raid, no recording")
AmisiaDB.sessions[#AmisiaDB.sessions + 1] = { id = "a", start = STUB.now - 7 * 86400, members = { Old = {} }, loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
AmisiaDB.sessions[#AmisiaDB.sessions + 1] = { id = "b", start = STUB.now - 3 * 86400, members = { Fraktur = {}, Chorf = {} }, loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
r, label = NS.SoftResRoster()
assert(names(r) == "Chorf,Fraktur", names(r))
assert(label == "letzter Raid, " .. date("%d.%m.", STUB.now - 3 * 86400), tostring(label))
-- the check falls back to the stored list and the roster
NS.SetSoftRes("Fraktur 32235\nNiemand 32235")
c = NS.SoftResCheck()
assert(names(c.ok) == "Fraktur" and names(c.missing) == "Chorf" and names(c.absent) == "Niemand")
NS.ClearSoftRes()
assert(NS.SoftResCheck() == nil, "no list, no check")

-- renaming a reservation
NS.SetSoftRes("Vulo 32837\nVulo 32235\nVulo Sturmwind 32235\n")
sr = AmisiaDB.softres
assert(NS.RenameReserve("Vulo", "Vulo Sturmwind", false) == 2)
assert(names(sr.byItem[32235]) == "Vulo Sturmwind" and sr.times[32235]["Vulo Sturmwind"] == 2, "merged with the existing name")
assert(names(sr.byItem[32837]) == "Vulo Sturmwind" and not (sr.times[32837] and sr.times[32837]["Vulo Sturmwind"]), "a single stays single")
assert(sr.renamed["Vulo Sturmwind"] == "Vulo" and sr.count == 3)
assert(AmisiaDB.srAliases["vulo"] == nil, "not remembered")
assert(NS.RenameReserve("Nobody", "X", true) == 0 and AmisiaDB.srAliases.nobody == nil, "unknown name: nothing happens")
NS.SetSoftRes("Bobingtn 32235")
assert(NS.RenameReserve("Bobingtn", "Bobbington", true) == 1)
assert(AmisiaDB.srAliases.bobingtn == "Bobbington" and NS.ReservedBy(32235)[1] == "Bobbington")
NS.SetSoftRes("Bobingtn 32837")
assert(NS.ReservedBy(32837)[1] == "Bobbington", "the fix holds for the next list")
AmisiaDB.srAliases.bobingtn = nil

-- reservations of one name, over SameName
NS.SetSoftRes("Vulo Sturmwind 32235\nVulo Sturmwind 32235\nVulo 32837\nFraktur 32837\n")
local mine = NS.ReservesOf("vulo sturmwind")
assert(#mine == 2 and mine[1].item == 32235 and mine[1].n == 2 and mine[2].item == 32837 and mine[2].n == 1, #mine)
assert(#NS.ReservesOf("Chorf") == 0)

-- the roll ranking: "Vulo" on the list keeps the lead when the roll comes from "Vulo Sturmwind"
STUB.roster = { { name = "Vulo Sturmwind", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
NS.SetSoftRes("Vulo 32235")
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end
assert(NS.StartRoll(link, 10))
local round = NS.CurrentRoll()
roll("Vulo Sturmwind", 5, 1, 99); roll("Fraktur", 100, 1, 100)
STUB.tick(10)
assert(round.winner == "Vulo Sturmwind", tostring(round.winner))
assert(NS.RollRanking(round)[1].rank == "SR")
assert(NS.RollKind(32235, "Vulo Sturmwind") == "SR" and NS.RollKind(32235, "Fraktur") == "MS")

-- the tooltip processor: registered once for items (the hook all of Amisia shares, in Core.lua),
-- one line per tooltip build
local tdp
for _, e in ipairs(STUB.tdp) do
    local info = debug.getinfo(e.fn, "S")
    if info.source:find("Core", 1, true) then tdp = e end
end
assert(tdp and tdp.kind == Enum.TooltipDataType.Item, "post call registered")
assert(#STUB.tdp == 1, "one post call for all of Amisia: " .. #STUB.tdp)
assert(GameTooltip.scripts.OnTooltipSetItem == nil, "no second path")
NS.SetSoftRes("Fraktur 32235")
local tip = CreateFrame("GameTooltip", "AmisiaTestTip")
local got = {}
tip.AddLine = function(_, s) got[#got + 1] = s end
tip.shownLink = link
tdp.fn(tip); tdp.fn(tip)
assert(#got == 1 and got[1]:find("Reserviert: Fraktur", 1, true), #got)
tip.scripts.OnTooltipCleared(tip)
tdp.fn(tip)
assert(#got == 2, "a new build gets the line again")
