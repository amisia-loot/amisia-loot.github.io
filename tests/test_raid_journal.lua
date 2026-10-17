-- The page Raids (F-122, tab Ausrüstung right after Dungeons): every raid at any level with size,
-- fit (opening day, level), values and the own raid ID; the chosen raid's image, bosses with their
-- loot from the guild's records, the waypoint; the command; the page Dungeons without raids; a
-- click on a raid entrance opens it here; the layout at the main window's size.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- the hand facts of DungeonData.lua: Barrow Deeps (10), Hyjal Summit (20), Onyxia's Lair (40)
NS.BIS = nil
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-raid-journal", Z = {}, I = {}, S = {} }
STUB.item(520, "Onyxias Zahn", 4)
local it = STUB.items[520]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_NECK", 4, 0, 60
it.stats = { ITEM_MOD_STRENGTH_SHORT = 30 }
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

local function rowsOf(P)
    local out = {}
    for _, r in ipairs(P.list.rows) do if r.item then out[r.item.key] = r end end
    return out
end

---------------------------------------------------------------------------
-- below the level cap: every raid, out of reach
---------------------------------------------------------------------------
assert(NS.ShowPage("raidjournal") ~= false)
local P = NS.RaidJournalPageFrame()
assert(P and P:IsShown() and NS.CurrentPage() == "raidjournal", "the page Raids")
local rows = rowsOf(P)
assert(rows.barrow and rows.hyjal and rows.onyxia and #P.list.items == 3, "three raids at level 16")
assert(rows.onyxia.size:GetText() == "40" and rows.barrow.size:GetText() == "10" and rows.hyjal.size:GetText() == "20")
assert(has(rows.onyxia.fit:GetText(), "ab ") and has(P.next:GetText(), "Raids öffnen ab"), P.next:GetText())
assert(rows.barrow.sel:IsShown(), "the first raid chosen without a recommendation")

---------------------------------------------------------------------------
-- at 60: a kill of Onyxia with its item, the boss list, the waypoint
---------------------------------------------------------------------------
STUB.level = 60
STUB.fire("PLAYER_LEVEL_UP")
NS.DropsLearnNames({ [10184] = "Onyxia" }, { [249] = { "raid", "Onyxias Hort" } })
assert(NS.DropsMerge({ h = "0e000001", npc = 10184, inst = 249, diff = 9, day = NS.DropsToday(), o = "aaaaaaaa", src = "G", it = { [520] = 1 } }) == "new")
NS.Refresh()
rows = rowsOf(P)
rows.onyxia:Click()
assert(AmisiaDB.settings.bis.raid == "onyxia" and rows.onyxia.sel:IsShown() and not rows.barrow.sel:IsShown())
assert(P.header.ButtonText:GetText() == "Onyxia's Lair · Bosse", P.header.ButtonText:GetText())
assert(P.art.title:GetText() == "Onyxia's Lair" and has(P.art.info:GetText(), "Raid 40"), P.art.info:GetText())
local names = {}
for _, x in ipairs(P.detail.items) do names[#names + 1] = x.kind == "boss" and x.text or (x.id and tostring(x.id)) or "" end
assert(names[1] == "Onyxia" and names[2] == "520", table.concat(names, ","))
assert(not has(P.hint:GetText(), "noch keine Beute"), P.hint:GetText())
rows.barrow:Click()
assert(#P.detail.items == 0 and has(P.hint:GetText(), "Für diesen Raid kennt Amisia noch keine Beute."), P.hint:GetText())
assert(not P.way:IsEnabled(), "no entrance known for the Barrow Deeps")

-- the page Dungeons holds no raid, even at 60
NS.ShowPage("dungeons")
for _, x in ipairs(NS.DungeonsPageFrame().list.items) do assert(x.kind ~= "raid", "a raid on the page Dungeons: " .. x.key) end

---------------------------------------------------------------------------
-- the own raid ID
---------------------------------------------------------------------------
local me = NS.UnitFullName("player")
AmisiaDB.raidcheck.own[me] = { at = time(), ids = { { m = 249, d = 9, r = time() + 86400, k = 1, t = 1 } } }
NS.Fire("RAIDIDS")
NS.ShowPage("raidjournal")
rows = rowsOf(P)
assert(has(rows.onyxia.id:GetText(), "bis ") and rows.barrow.id:GetText() == "", tostring(rows.onyxia.id:GetText()))

---------------------------------------------------------------------------
-- the command, the search's and the map's way in
---------------------------------------------------------------------------
NS.ShowPage("dungeons")
NS.Dispatch("raids")
assert(NS.CurrentPage() == "raidjournal")
NS.ShowPage("dungeons")
assert(NS.ShowDungeon("hyjal") ~= nil and NS.CurrentPage() == "raidjournal" and AmisiaDB.settings.bis.raid == "hyjal")
assert(rowsOf(P).hyjal.sel:IsShown())

---------------------------------------------------------------------------
-- layout at the main window's size, officer and raider view
---------------------------------------------------------------------------
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(P, 602, 478)
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowPage("raidjournal")
    Lay.row(view .. " columns", P.head.name, P.head.size, P.head.fit, P.head.upgrades, P.head.run, P.head.value, P.head.id)
    local lr = P.list.rows[1]
    Lay.row(view .. " list row", lr.name, lr.size, lr.fit, lr.upgrades, lr.run, lr.value, lr.id)
    Lay.row(view .. " detail head", P.header, P.way)
    Lay.row(view .. " detail", P.detail, P.detail.bar)
    Lay.column(view .. " body", P.spec, P.next, P.why, P.head.name, P.list, P.header, P.detail, P.hint)
    local _, gr = Lay.span(lr.id)
    assert(gr <= 590, "the ID ends in the row: " .. gr)
    Lay.fits(P.next)
    for _, fs in pairs(P.head) do Lay.fits(fs) end
    for _, row in ipairs(P.list.rows) do
        if row.item then Lay.fits(row.name); Lay.fits(row.fit); Lay.fits(row.id) end
    end
end
NS.Reset("ui.view")
print("test_raid_journal ok")
