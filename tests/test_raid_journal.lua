-- The page Raids (F-122, group Welt right after Dungeons): every raid at any level as a card
-- (F-143) with size, fit (opening day, level), values and the own raid ID; a click opens the chosen
-- raid's detail: the image, bosses with their loot from the guild's records, the waypoint; the command; the page Dungeons without raids; a
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

-- the cards of the start view by key
local function rowsOf(P)
    local out = {}
    for _, c in ipairs(P.grid:Cards()) do out[c.item.key] = c end
    return out
end
-- a raid chosen on the start view (from the detail view through its link back)
local function pick(P, key)
    if P.back:IsShown() then P.back:Click() end
    P.grid:CardOf(key):Click()
end

---------------------------------------------------------------------------
-- below the level cap: every raid, out of reach
---------------------------------------------------------------------------
assert(NS.ShowPage("raidjournal") ~= false)
local P = NS.PageFrame("raidjournal")
assert(P and P:IsShown() and NS.CurrentPage() == "raidjournal", "the page Raids")
assert(P.grid:IsShown() and not P.detail:IsShown() and not P.art:IsShown() and not P.back:IsShown(), "the cards first")
local rows = rowsOf(P)
assert(rows.barrow and rows.hyjal and rows.onyxia and #P.grid.entries == 3, "three raids at level 16")
assert(has(plain(rows.onyxia.line1:GetText()), "Raid 40 · ") and has(plain(rows.barrow.line1:GetText()), "Raid 10 · ")
    and has(plain(rows.hyjal.line1:GetText()), "Raid 20 · "), plain(rows.onyxia.line1:GetText()))
assert(has(plain(rows.onyxia.line1:GetText()), " · ab ") and has(P.next:GetText(), "Raids öffnen ab"), P.next:GetText())
assert(rows.onyxia.dim and rows.onyxia.tex.desaturated == true, "out of reach: dim")
assert(rows.barrow.chosen and not rows.barrow.tag:IsShown(), "the first raid chosen without a recommendation")
-- the three cards in one row of the grid
assert(P.grid.rows[1].item and #P.grid.rows[1].item == 3 and not P.grid.rows[2]:IsShown(), "three per row")

---------------------------------------------------------------------------
-- at 60: a kill of Onyxia with its item, the boss list, the waypoint
---------------------------------------------------------------------------
STUB.level = 60
STUB.fire("PLAYER_LEVEL_UP")
NS.DropsLearnNames({ [10184] = "Onyxia" }, { [249] = { "raid", "Onyxias Hort" } })
assert(NS.DropsMerge({ h = "0e000001", npc = 10184, inst = 249, diff = 9, day = NS.DropsToday(), o = "aaaaaaaa", src = "G", it = { [520] = 1 } }) == "new")
NS.Refresh()
rows = rowsOf(P)
assert(NS.RaidNext() == nil and not rows.onyxia.tag:IsShown() and rows.onyxia.dim == (rows.onyxia.item.fit ~= "fit"),
    "no recommendation while the raids open later; dim unless it fits now")
assert(plain(rows.onyxia.line2:GetText()):find("^%d+ Upgrades · .- je Lauf · Wert %d+$"), plain(rows.onyxia.line2:GetText()))
pick(P, "onyxia")
assert(P.detail:IsShown() and P.back:IsShown() and P.art:IsShown() and not P.grid:IsShown() and not P.next:IsShown(), "the detail view")
assert(AmisiaDB.settings.bis.raid == "onyxia")
P.back:Click()
rows = rowsOf(P)
assert(rows.onyxia.chosen and not rows.barrow.chosen, "the chosen card")
pick(P, "onyxia")
assert(P.header.ButtonText:GetText() == "Bosse", P.header.ButtonText:GetText())
assert(P.art.title:GetText() == "Onyxia's Lair" and has(P.art.info:GetText(), "Raid 40"), P.art.info:GetText())
local names = {}
for _, x in ipairs(P.detail.items) do names[#names + 1] = x.kind == "boss" and x.text or (x.id and tostring(x.id)) or "" end
assert(names[1] == "Onyxia" and names[2] == "520", table.concat(names, ","))
assert(not has(P.hint:GetText(), "noch keine Beute"), P.hint:GetText())
pick(P, "barrow")
assert(#P.detail.items == 0 and has(P.hint:GetText(), "Für diesen Raid kennt Amisia noch keine Beute."), P.hint:GetText())
assert(not P.way:IsEnabled(), "no entrance known for the Barrow Deeps")

-- the page Dungeons holds no raid, even at 60
NS.ShowPage("dungeons")
for _, x in ipairs(NS.PageFrame("dungeons").grid.entries) do assert(x.kind ~= "raid", "a raid on the page Dungeons: " .. x.key) end

---------------------------------------------------------------------------
-- the own raid ID
---------------------------------------------------------------------------
local me = NS.UnitFullName("player")
AmisiaDB.raidcheck.own[me] = { at = time(), ids = { { m = 249, d = 9, r = time() + 86400, k = 1, t = 1 } } }
NS.Fire("RAIDIDS")
NS.ShowPage("raidjournal")
P.back:Click()
rows = rowsOf(P)
assert(has(plain(rows.onyxia.line1:GetText()), " · ID bis ") and not has(rows.barrow.line1:GetText(), "ID bis"), tostring(rows.onyxia.line1:GetText()))

---------------------------------------------------------------------------
-- the command, the search's and the map's way in
---------------------------------------------------------------------------
NS.ShowPage("dungeons")
NS.Dispatch("raids")
assert(NS.CurrentPage() == "raidjournal")
NS.ShowPage("dungeons")
assert(NS.ShowDungeon("hyjal") ~= nil and NS.CurrentPage() == "raidjournal" and AmisiaDB.settings.bis.raid == "hyjal")
assert(P.detail:IsShown() and P.header.ButtonText:GetText() == "Bosse" and not P.grid:IsShown(), "the map's way in opens the detail")
P.back:Click()
assert(rowsOf(P).hyjal.chosen)

---------------------------------------------------------------------------
-- layout at the main window's size, officer and raider view
---------------------------------------------------------------------------
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(P, 602, 478)
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowPage("raidjournal")
    -- the start: the cards in one row of the list's width
    local gr = P.grid.rows[1]
    Lay.row(view .. " card row", gr.cards[1], gr.cards[2], gr.cards[3])
    Lay.column(view .. " body", P.spec, P.next, P.why, P.grid)
    local _, right = Lay.span(gr.cards[3])
    assert(right <= 590, "the cards end in the list: " .. right)
    assert(P.hint.isHelp)
    Lay.fits(P.next)
    -- the detail: the back link before the spec, the image, the header, the bosses
    pick(P, "onyxia")
    Lay.row(view .. " detail head row", P.back, P.spec)
    Lay.row(view .. " detail head", P.header, P.way)
    Lay.row(view .. " detail", P.detail, P.detail.bar)
    Lay.column(view .. " detail body", P.spec, P.art, P.header, P.detail)
    P.back:Click()
end
NS.Reset("ui.view")
print("test_raid_journal ok")
