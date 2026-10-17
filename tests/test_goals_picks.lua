-- The own pick of a slot (F-112, D-54): ns.BisSetPick checks the item (a link or a number; the
-- slot, the class), stores it per character, spec and slot (AmisiaDB.bis.chars[name].pick) and
-- cleans it on load; it takes option 1 of its slot in ns.BisTargets (an upgrade until worn, then
-- nothing else is), beats a BiS pick, follows the weapon plan (kept but unused when it does not fit),
-- an item the data lacks counts with the client's stats ("unbekannt"); "Hier" and the dungeon gains
-- follow it, the tooltip's "Upgrade für dich" does not; ns.BisRanking (the ten best, the own pick
-- starred, not moved ahead), the hint "Überholt"; the slot panel of the window: ranking clicks, the
-- red X, the field.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function ids(list)
    local out = {}
    for i, e in ipairs(list or {}) do out[i] = e.id end
    return table.concat(out, ",")
end

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-goals-picks", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },   -- 2
} }
STUB.areas[2717], STUB.areas[2017] = "Geschmolzener Kern", "Stratholme"
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, stats, sources, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel = stats, 60
    if sources then
        NS.GEAR.I[id] = { loc, o.classID or 4, o.sub or 4, 60, 4, 1, 141, o.mask or 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
local function wpn(dps, s) return { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = dps, ITEM_MOD_STRENGTH_SHORT = s } end
gear(601, "Helm Eins", "HEAD", str(40), { 1 })
gear(602, "Helm Zwei", "HEAD", str(30), { 1 })
gear(603, "Helm Drei", "HEAD", str(20), { 2 })
for i = 0, 11 do gear(620 + i, "Helm " .. i, "HEAD", str(5 + i), { 2 }) end
gear(604, "Ring Eins", "FINGER", str(30), { 1 }, { sub = 0 })
gear(605, "Ring Zwei", "FINGER", str(20), { 1 }, { sub = 0 })
gear(606, "Ring Drei", "FINGER", str(10), { 2 }, { sub = 0 })
gear(607, "Zweihand", "2HWEAPON", wpn(80, 30), { 1 }, { classID = 2, sub = 1 })
gear(608, "Axt", "WEAPON", wpn(50, 10), { 1 }, { classID = 2, sub = 0 })
gear(609, "Schild", "SHIELD", str(10), { 1 }, { sub = 6 })
gear(610, "Stoffkappe", "HEAD", str(50), { 1 }, { mask = Gear.CLASS_BIT.MAGE })
gear(611, "Fremder Helm", "HEAD", str(25))              -- the data does not list it
gear(612, "Brust", "CHEST", str(10), { 1 })
assert(Gear.Available())
NS.BisSetSpec("dps")
local spec = NS.BisSpec()
assert(spec == "dps", "the warrior's dps spec")

---------------------------------------------------------------------------
-- setting a pick: checked, stored per spec and slot
---------------------------------------------------------------------------
local ok, why = NS.BisSetPick("HEAD", LINKS[604])
assert(not ok and why == "Passt nicht in Kopf.", "a ring is no helm: " .. tostring(why))
ok, why = NS.BisSetPick("HEAD", "kein Item")
assert(not ok and why == "Kein Item.", "text that is no link or number")
ok, why = NS.BisSetPick("HEAD", 610)
assert(not ok and why == "Das kann dein Charakter nicht tragen.", "a mage's cap: " .. tostring(why))
ok, why = NS.BisSetPick("NOSLOT", 601)
assert(not ok and why == "Unbekannter Slot.")
assert(NS.BisSetPick("HEAD", " 603 "), "a number as text")
local me = NS.BisChar()
assert(me.pick and me.pick.dps and me.pick.dps.HEAD == 603, "stored under pick[spec][slot]")
assert(AmisiaDB.bis.chars.Vuloo.pick.dps.HEAD == 603, "in the saved variables")
assert(NS.BisPick("HEAD") == 603 and NS.BisPick("HEAD", "tank") == nil, "per spec")

---------------------------------------------------------------------------
-- the targets: the pick is option 1, an upgrade until worn
---------------------------------------------------------------------------
local r = NS.BisTargets()
assert(ids(r.HEAD) == "603,601,602", "the pick first, the best behind it: " .. ids(r.HEAD))
assert(r.HEAD[1].own and r.HEAD[1].upgrade, "starred and an upgrade until worn")
assert(r.own.HEAD == 603, "the picks in use")
-- the ranking keeps the order of the score, the pick starred in its place
local rank, total = NS.BisRanking("HEAD", 10)
assert(#rank == 10 and total >= 15, "ten of " .. total)
assert(rank[1].id == 601 and rank[2].id == 602 and rank[3].id == 603 and rank[3].own and not rank[1].own, "by score: " .. ids(rank))
-- worn: the slot is done, nothing else is an upgrade there
STUB.worn[1] = LINKS[603]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
r = NS.BisTargets()
assert(r.state.HEAD == "done" and not r.HEAD[2].upgrade, "the worn pick is the target")
-- the dungeons' gain follows it (D-54), the tooltip's comparison does not
local g = NS.BisGain(601)
assert(g == 0, "nothing else gains in the row of a worn pick: " .. tostring(g))
local u = NS.UpgradeOf(LINKS[601])
assert(u and u.up and u.gain > 0, "Upgrade für dich still compares the score with what is worn")
-- "Hier" in the raid: the better helm is no upgrade while the pick is worn
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
local _, here = NS.BisHere()
for _, e in ipairs(here) do assert(not (e.id == 601 and e.upgrade), "Hier follows the pick") end
-- overtaken: Helm Eins scores 80 against the pick's 40
local over = NS.BisOvertaken("HEAD")
assert(over and over.id == 601 and over.pct == 100, "Überholt: +100 %")
-- the pick off: Helm Eins is the target again
assert(NS.BisSetPick("HEAD", nil))
assert(me.pick == nil, "an empty pick table falls away")
r = NS.BisTargets()
assert(r.HEAD[1].id == 601 and not r.HEAD[1].own, "the best again")
assert(NS.BisOvertaken("HEAD") == nil)
_, here = NS.BisHere()
local found = false
for _, e in ipairs(here) do if e.id == 601 and e.upgrade then found = true end end
assert(found, "and Hier lists it")
STUB.worn[1] = nil
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.instance = nil

---------------------------------------------------------------------------
-- a BiS pick: the own pick beats it
---------------------------------------------------------------------------
local keepBis = NS.BIS
NS.BIS = { PICK = { { class = "WARRIOR", spec = "dps", from = 1, to = 60, slot = "HEAD", item = 602, note = "Proc" } } }
NS.BisBump()
r = NS.BisTargets()
assert(r.HEAD[1].id == 602 and r.HEAD[1].pick, "the BiS pick first")
assert(NS.BisSetPick("HEAD", 603))
r = NS.BisTargets()
assert(r.HEAD[1].id == 603 and r.HEAD[1].own and r.HEAD[2].id == 602 and r.HEAD[2].pick, "the own pick beats the BiS pick")
assert(NS.BisSetPick("HEAD", nil))
NS.BIS = keepBis
NS.BisBump()

---------------------------------------------------------------------------
-- an item the data lacks: the client's stats, source "unbekannt", no place
---------------------------------------------------------------------------
assert(NS.BisSetPick("HEAD", LINKS[611]), "an item outside the data that fits")
r = NS.BisTargets()
assert(r.HEAD[1].id == 611 and r.HEAD[1].own and r.HEAD[1].unknown and r.HEAD[1].score == 50, "scored with the client's stats: " .. tostring(r.HEAD[1].score))
assert(NS.BisSetPick("HEAD", nil))

---------------------------------------------------------------------------
-- rings: one list; the second ring's pick is not the first's target
---------------------------------------------------------------------------
assert(NS.BisSetPick("FINGER2", 604))
r = NS.BisTargets()
assert(r.FINGER2[1].id == 604 and r.FINGER2[1].own, "the second ring's pick")
assert(r.FINGER1[1].id == 605, "the first ring takes the next: " .. ids(r.FINGER1))
assert(NS.BisSetPick("FINGER1", 604))
assert(me.pick.dps.FINGER1 == 604 and me.pick.dps.FINGER2 == nil, "a ring is the pick of one row only")
assert(NS.BisSetPick("FINGER1", nil))

---------------------------------------------------------------------------
-- the weapon plan: a two-hand pick makes the plan two-hand; a pick the plan rules out is kept, unused
---------------------------------------------------------------------------
r = NS.BisTargets()
local plan0 = r.plan
assert(NS.BisSetPick("OFFHAND", 609))
r = NS.BisTargets()
assert(r.plan == "1H" and r.OFFHAND[1].id == 609 and r.OFFHAND[1].own, "a shield pick: weapon and shield")
assert(NS.BisSetPick("MAINHAND", 607))
r = NS.BisTargets()
assert(r.plan == "2H" and r.MAINHAND[1].id == 607 and #r.OFFHAND == 0, "the two-hand pick wins the hands")
assert(r.ownUnused and r.ownUnused.OFFHAND == "plan", "the shield pick kept, unused")
assert(NS.BisSetPlan("SHIELD"))
r = NS.BisTargets()
assert(r.ownUnused.MAINHAND == "plan" and r.OFFHAND[1].id == 609 and r.MAINHAND[1].id ~= 607, "the plan rules the two-hander out")
assert(me.pick.dps.MAINHAND == 607, "but it stays saved")
assert(NS.BisSetPlan("auto"))
assert(NS.BisSetPick("MAINHAND", nil) and NS.BisSetPick("OFFHAND", nil))
assert(NS.BisTargets().plan == plan0)

---------------------------------------------------------------------------
-- the saved shape is checked on load; twice changes nothing
---------------------------------------------------------------------------
me.pick = { dps = { HEAD = 601, NOSLOT = 602, CHEST = "x", FEET = -3 }, ["bad key"] = { HEAD = 1 }, tank = {}, holy = "x" }
NS.BisMigrate(AmisiaDB)
assert(me.pick.dps.HEAD == 601 and me.pick.dps.NOSLOT == nil and me.pick.dps.CHEST == nil and me.pick.dps.FEET == nil, "slots and ids checked")
assert(me.pick["bad key"] == nil and me.pick.tank == nil and me.pick.holy == nil, "bad specs and empty tables dropped")
NS.BisMigrate(AmisiaDB)
assert(me.pick.dps.HEAD == 601, "a second run changes nothing")
me.pick = { dps = { CHEST = 0 } }
NS.BisMigrate(AmisiaDB)
assert(me.pick == nil, "nothing left: no table")
NS.BisSetPick("HEAD", nil)

---------------------------------------------------------------------------
-- the slot panel of the window
---------------------------------------------------------------------------
local win = assert(NS.ShowGoalsFrame())
NS.GoalsFrameState().slot = "HEAD"
NS.GoalsRefresh()
local S = win.side
assert(S.slot == "HEAD" and has(S.title:GetText(), "Kopf"), "the chosen slot's panel: " .. tostring(S.title:GetText()))
assert(S.none:GetText() == "Keine eigene Wahl: Amisia nimmt das Beste." and S.none.vis ~= false, "no pick yet")
assert(has(S.rankHead:GetText(), "Rangliste für") and has(S.rankHead:GetText(), "60"), S.rankHead:GetText())
local row3 = S.rank.rows[3]
assert(row3.item and row3.item.id == 603, "the third of the ranking")
row3:Click()
assert(NS.BisPick("HEAD") == 603, "a click makes it the own pick")
assert(S.pick.vis ~= false and has(plain(S.pick.name:GetText()), "Helm Drei") and S.pick.id == 603, "Deine Wahl shows it")
assert(win.list.items[2].opt.id == 603 and win.list.items[2].opt.own, "the list shows it as the head's target")
row3 = S.rank.rows[3]
assert(row3.item.own and has(row3.name:GetText(), "|A:") or has(row3.name:GetText(), "|T"), "starred in the ranking")
row3:Click()
assert(NS.BisPick("HEAD") == nil, "a second click lifts it")
S.rank.rows[2]:Click()
assert(NS.BisPick("HEAD") == 602)
S.pick.del:Click()
assert(NS.BisPick("HEAD") == nil, "the red X lifts it")
-- the field: a ring for the head is refused and changes nothing
S.field:SetText(LINKS[604])
S.add:Click()
assert(S.msg:GetText() == "Passt nicht in Kopf." and NS.BisPick("HEAD") == nil, "refused: " .. tostring(S.msg:GetText()))
S.field:SetText("602")
S.add:Click()
assert(NS.BisPick("HEAD") == 602 and S.field:GetText() == "" and S.msg:GetText() == "", "an id takes")
-- a Shift-clicked link goes into the field while it has the focus
S.field:SetFocus()
assert(S.takeLink(LINKS[601]) and S.field:GetText() == LINKS[601], "the link in the field")
S.field:ClearFocus()
-- overtaken: the pick worn, the hint with "Übernehmen"
STUB.worn[1] = LINKS[602]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
NS.GoalsRefresh()
assert(has(plain(S.note:GetText()), "Überholt: Helm Eins ist +33 % besser"), plain(S.note:GetText()))
assert(S.take.vis ~= false and S.take.id == 601, "Übernehmen")
S.take:Click()
assert(NS.BisPick("HEAD") == 601, "taken over on the click, never by itself")
-- a pick the plan rules out says so
NS.GoalsFrameState().slot = "MAINHAND"
assert(NS.BisSetPick("MAINHAND", 607))
assert(NS.BisSetPlan("SHIELD"))
assert(has(plain(S.note:GetText()), "Passt nicht zum Waffenplan"), plain(S.note:GetText()))
assert(NS.BisSetPlan("auto"))
-- the drops near the level: none in this data set, the line says so
assert(#S.drops.items == 0 and has(S.dropEmpty:GetText(), "Kein Dungeon"), "no drops")
S.all:Click()
assert(NS.CurrentPage() == "dungeons", "Alle zeigen opens the page Dungeons")
