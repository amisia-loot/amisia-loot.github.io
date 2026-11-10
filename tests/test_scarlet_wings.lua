-- The Scarlet Monastery as four dungeons (F-174, D-106): the page's four cards with their level ranges,
-- names in the client's language, bosses, keys, loot and quests per wing; inside the one map (189) the run,
-- the clock and the dungeon bar before and after the first kill (the kill tells the wing; a wing's run ends
-- with its last boss, the next wing's clock starts with the next entry's first fight; a kill in another
-- wing while a clock runs moves the clock there); the migration of the old key "sm" and an old saved best
-- time that was never migrated.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local Dn, R, RT, DBar = NS.Dungeons, NS.Runs, NS.RunTimes, NS.DungeonBar
local WINGS = { "smgy", "smlib", "smarm", "smcath" }

STUB.class, STUB.level, STUB.faction = "WARRIOR", 34, "Alliance"
STUB.roster = {}
STUB.areas[796] = "Scharlachrotes Kloster"
local SM = { name = "Scharlachrotes Kloster", type = "party", id = 189 }
local OUT = { name = "Tirisfal", type = "none", id = 0 }
local function enter(i)
    STUB.instance = i
    STUB.fire("PLAYER_LEAVING_WORLD")
    STUB.fire("PLAYER_ENTERING_WORLD")
end
local function kill(enc) STUB.fire("ENCOUNTER_END", enc, "Boss", 1, 5, 1) end
local function fight() STUB.fire("PLAYER_REGEN_DISABLED"); STUB.fire("PLAYER_REGEN_ENABLED") end
-- seconds of the stub's clock (it steps in tenths)
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 0.01 end

---------------------------------------------------------------------------
-- the data: four dungeons, one map, each its own bosses, range, loot, quests; the key on two
---------------------------------------------------------------------------
assert(R.Fact("sm") == nil, "the old key is gone")
local want = {
    smgy = { 30, 38, "Friedhof", "Interrogator Vishas,Bloodmage Thalnos" },
    smlib = { 33, 41, "Bibliothek", "Houndmaster Loksey,Arcanist Doan" },
    smarm = { 36, 44, "Waffenkammer", "Herod" },
    smcath = { 38, 46, "Kathedrale", "High Inquisitor Fairbanks,High Inquisitor Whitemane" },
}
for _, key in ipairs(WINGS) do
    local w, f = want[key], R.Fact(key)
    assert(f and f.inst == 189 and f.part == "Scarlet Monastery", key)
    assert(table.concat(f.order, ",") == w[4], key .. ": " .. table.concat(f.order, ","))
    local e = NS.DungeonInfo(key)
    assert(e and e.min == w[1] and e.max == w[2] and not e.est, key .. " " .. tostring(e and e.min))
    assert(e.name == "Scharlachrotes Kloster: " .. w[3], e.name)
    assert(Dn.RangeText(e) == w[1] .. "-" .. w[2])
end
assert(R.KeysOf(189)[1] == "smgy" and #R.KeysOf(189) == 4, "one map, four dungeons in the facts' order")
-- the name without the client's area name: the facts' part and the wing
STUB.areas[796] = nil
assert(Dn.Name(R.Fact("smcath")) == "Scarlet Monastery: Kathedrale", Dn.Name(R.Fact("smcath")))
STUB.areas[796] = "Scharlachrotes Kloster"
-- the key: the Armory and the Cathedral need The Scarlet Key, the Graveyard and the Library none
local JP = NS.JournalParts
for key, need in pairs({ smgy = false, smlib = false, smarm = true, smcath = true }) do
    local keys = JP.Keys(key)
    assert((keys ~= nil) == need, key)
    if need then assert(keys[1].item == 7146 and keys[1].need == "required", key) end
end
-- a boss's loot in its wing only; Mograine (no encounter) and the rares where their wing is
assert(Dn.KnownLoot("smarm", "Herod") == 3 and Dn.KnownLoot("smgy", "Herod") == 0 and Dn.KnownLoot("smcath", "Herod") == 0)
assert(Dn.KnownLoot("smcath", "Scarlet Commander Mograine") == 3 and Dn.KnownLoot("smgy", "Ironspine") == 3)
assert(Dn.KnownLoot("smlib", "Arcanist Doan") == 6)
local function bossNames(key)
    local out = {}
    for _, b in ipairs(Dn.JournalBosses(key, NS.DungeonInfo(key).bosses)) do out[#out + 1] = b.name end
    return table.concat(out, ",")
end
assert(has(bossNames("smcath"), "Scarlet Commander Mograine") and not has(bossNames("smcath"), "Herod"), bossNames("smcath"))
-- the wish list's drop hints and the gear page name a source's dungeon by D.SourceKey: each wing its own
local seen = {}
for _, rec in ipairs(NS.Data("GEAR").S) do
    if rec[1] == "D" and type(rec[2]) == "string" and rec[2]:find("^Scarlet Monastery") then
        local key = Dn.SourceKey(rec)
        assert(key and want[key] and rec[2] == "Scarlet Monastery: " .. ({ smgy = "Graveyard", smlib = "Library",
            smarm = "Armory", smcath = "Cathedral" })[key], rec[2] .. " " .. tostring(key))
        seen[key] = true
    end
end
assert(seen.smgy and seen.smlib and seen.smarm and seen.smcath, "sources in all four wings")
-- the monastery's quests in their wings: an Alliance quest of the Library, one of three wings
local function qids(key)
    local set = {}
    for _, q in ipairs((NS.DungeonQuests(key))) do if q.qid then set[q.qid] = true end end
    return set
end
assert(qids("smlib")[1050] and not qids("smgy")[1050] and not qids("smarm")[1050], "Mythology of the Titans: the Library")
for _, key in ipairs({ "smlib", "smarm", "smcath" }) do assert(qids(key)[1053], "In the Name of the Light: " .. key) end
assert(not qids("smgy")[1053], "not in the Graveyard")

---------------------------------------------------------------------------
-- the page: four cards with their ranges and the key
---------------------------------------------------------------------------
enter(OUT)
NS.ShowPage("dungeons")
local B = NS.PageFrame("dungeons")
if not B.table:IsShown() and B.back then B.back:Click() end
for _, key in ipairs(WINGS) do
    local card = B.table:RowOf(key)
    assert(card and has(card.name:GetText(), "Scharlachrotes Kloster: " .. want[key][3]), key .. " " .. tostring(card and card.name:GetText()))
    assert(plain(card.cells.level:GetText()) == want[key][1] .. "-" .. want[key][2], plain(card.cells.level:GetText()))
end
assert(B.table:RowOf("sm") == nil, "no card of the old key")

---------------------------------------------------------------------------
-- inside: before the first kill all four are candidates, the kill tells the wing
---------------------------------------------------------------------------
enter(SM)
local k, sure, keys = R.Here()
assert(k == "smgy" and sure == false and #keys == 4, "a guess before the first kill")
-- the dungeon bar: the client's name of the map and the bosses of all four
local bar = _G.AmisiaDungeonBar
assert(bar and bar:IsShown() and bar.handle.text:GetText() == "Scharlachrotes Kloster", tostring(bar and bar.handle.text:GetText()))
assert(plain(bar.seg.bosses:GetText()) == "Bosse 7", bar.seg.bosses:GetText())
assert(DBar.Toggle("bosses"))
local rows = {}
for _, r in ipairs(_G.AmisiaDungeonBarList.rows) do if r:IsShown() then rows[#rows + 1] = plain(r.text:GetText()) end end
assert(rows[1] == "Scharlachrotes Kloster: Friedhof" and rows[2] == "1. Interrogator Vishas" and #rows == 11, table.concat(rows, "|"))
DBar.Toggle("bosses")
-- the page: every wing "Hier bist du" until the kill
NS.Refresh()
if not B.table:IsShown() and B.back then B.back:Click() end
for _, key in ipairs(WINGS) do
    assert(has(B.table:RowOf(key).sub:GetText(), "Hier bist du"), key)
end
-- the first fight: the clock of the guess
fight()
assert(RT.Live() and RT.Live().k == "smgy" and RT.Live().nm == nil, "the clock starts on the guess")
STUB.tick(60)
kill(446)   -- Houndmaster Loksey: the Library
k, sure = R.Here()
assert(k == "smlib" and sure == true, "the kill tells the wing")
assert(RT.Live().k == "smlib" and near(RT.Live().s[446], 60), "the clock is the Library's")
assert(select(2, R.Of("smlib")) == 1 and select(2, R.Of("smgy")) == 0, "each wing its own kills")
assert(bar.handle.text:GetText() == "Scharlachrotes Kloster: Bibliothek", bar.handle.text:GetText())
assert(plain(bar.seg.bosses:GetText()) == "Bosse 1/2", bar.seg.bosses:GetText())
NS.Refresh()
assert(has(B.table:RowOf("smlib").sub:GetText(), "Hier bist du") and not has(B.table:RowOf("smgy").sub:GetText(), "Hier bist du"))
-- a /reload inside keeps the wing
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
assert(select(2, R.Here()) == true and R.Here() == "smlib", "a reload keeps it")
STUB.tick(60)
kill(447)   -- Arcanist Doan: the Library's last boss ends its run
assert(RT.Live() == nil and near(RT.Of("smlib").best.t, 120), "the Library finished in 2:00")
assert(said("Scharlachrotes Kloster: Bibliothek in 2:00"), STUB.messages[#STUB.messages])
assert(R.Done("smlib") and not R.Done("smgy"))
-- the trash after the last boss starts nothing
fight()
assert(RT.Live() == nil, "no clock from the trash after the last boss")

---------------------------------------------------------------------------
-- the next door: a fresh entry, the next wing's clock from its first fight
---------------------------------------------------------------------------
enter(OUT)
STUB.tick(120)
enter(SM)
k, sure = R.Here()
assert(k == "smgy" and sure == false, "a new entry forgets the wing: the first without a kill")
assert(select(2, R.Of("smlib")) == 2, "the run of the map goes on")
fight()
assert(RT.Live() and RT.Live().k == "smgy", "a new clock")
STUB.tick(30)
kill(448)   -- Herod: the Armory, its only boss
assert(RT.Live() == nil and near(RT.Of("smarm").best.t, 30), "the Armory in 0:30")
assert(R.Here() == "smarm" and RT.Of("smgy") == nil, "no time of the guess")

-- a kill of another wing while a clock with kills runs: that one ends unfinished, the other's starts with
-- the entry's first fight
enter(OUT)
enter(SM)
STUB.tick(5)
fight()
local start = RT.Live().at
STUB.tick(10)
kill(444)   -- Interrogator Vishas: the Graveyard
assert(RT.Live().k == "smgy" and near(RT.Live().s[444], 10))
STUB.tick(10)
kill(449)   -- High Inquisitor Fairbanks: the Cathedral
local l = RT.Live()
assert(l and l.k == "smcath" and l.at == start and near(l.s[449], 20) and l.s[444] == nil, "the Cathedral's clock from the first fight")
assert(RT.Of("smgy").runs[1] and not RT.Of("smgy").runs[1].d and RT.Of("smgy").best == nil, "the Graveyard's run unfinished")
kill(99999)   -- an encounter of no wing changes nothing
assert(RT.Live().k == "smcath" and RT.Live().s[99999] == nil and R.Here() == "smcath")
RT.Stop()

---------------------------------------------------------------------------
-- the migration of the old key (Core/Migrate.lua step 6)
---------------------------------------------------------------------------
local db = { schema = 5, settings = { bis = { dungeon = "sm" } }, map = { quests = "sm" }, runTimes = { v = 1,
    inst = { sm = { nm = "Scharlachrotes Kloster",
        best = { at = 1789000000, t = 600, s = { [449] = 200, [450] = 600 }, n = 5, c = "Vulo", d = true },
        seg = { [444] = { t = 50, at = 1789000000, c = "Vulo" }, [450] = { t = 400, at = 1789000000, c = "Vulo" } },
        runs = { { at = 1789000000, t = 600, s = { [449] = 200, [450] = 600 }, n = 5, c = "Vulo", d = true },
                 { at = 1788000000, t = 90, s = { [444] = 40, [2779] = 90 }, n = 3, c = "Vulo" },
                 { at = 1787000000, t = 0, s = {}, n = 1, c = "Vulo" } } },
        smcath = { best = { at = 1780000000, t = 900, s = { [450] = 900 }, n = 5, c = "Kim", d = true }, seg = {}, runs = {} } },
    live = { Vulo = { k = "sm", i = 189, at = 1789100000, r = 1789100000, s = { [446] = 30 }, n = 2 },
             Kim = { k = "sm", i = 189, at = 1789100000, r = 1789100000, s = {}, n = 1 } },
    last = {} } }
NS.MIGRATIONS[6](db)
local t = db.runTimes.inst
assert(t.sm == nil, "the old key goes")
assert(t.smcath.best.t == 600 and t.smcath.best.d and t.smcath.best.s[450] == 600, "the better best of the Cathedral")
assert(t.smcath.runs[1].d and t.smcath.runs[1].s[449] == 200, "the run to the wing of its last kill")
assert(t.smgy.runs[1].t == 90 and t.smgy.runs[1].s[2779] == 90 and not t.smgy.runs[1].d, "the Graveyard's run, not finished")
assert(#t.smgy.runs == 1 and t.smgy.best == nil, "a run without a kill goes; no best for the Graveyard")
assert(t.smgy.seg[444].t == 50 and t.smcath.seg[450].t == 400, "the best per boss to its wing")
assert(db.runTimes.live.Vulo.k == "smlib" and db.runTimes.live.Kim.k == "smgy", "a running clock to its wing, else the first")
assert(db.settings.bis.dungeon == "smgy" and db.map.quests == "smgy", "the page's dungeon and the marked givers")
NS.MIGRATIONS[6](db)
assert(t.smcath.best.t == 600 and #t.smgy.runs == 1, "a second run changes nothing")
-- the migrated data loads
AmisiaDB.runTimes = db.runTimes
RT.Loaded()
assert(RT.Of("smcath").best.t == 600 and #RT.Lines("smcath", RT.Of("smcath").best) == 2)
assert(AmisiaDB.schema >= 6, "a new file has had the step")

---------------------------------------------------------------------------
-- an old saved best of "sm" that no migration moved: kept, readable, no error
---------------------------------------------------------------------------
AmisiaDB.runTimes = { v = 1, inst = { sm = { nm = "Scharlachrotes Kloster",
    best = { at = 1789000000, t = 600, s = { [450] = 600 }, n = 5, c = "Vulo", d = true }, seg = {}, runs = {} } },
    live = { [NS.UnitFullName("player")] = { k = "sm", i = 189, at = 1789100000, r = 1789100000, s = {}, n = 1 } }, last = {} }
RT.Loaded()
assert(RT.Of("sm").best.t == 600 and RT.Name("sm") == "Scharlachrotes Kloster", "kept under its old name")
assert(#RT.Lines("sm", RT.Of("sm").best) == 0, "no lines without facts")
-- the page with the old key as its chosen dungeon, and asked for it: another dungeon, no error
AmisiaDB.settings.bis.dungeon = "sm"
NS.ShowPage("dungeons")
NS.Refresh()
NS.ShowDungeon("sm")
NS.Refresh()
assert(B:IsShown() and B.chosen ~= "sm", tostring(B.chosen))
-- the old running clock is of another run: it ends unfinished with the next check
RT.Check()
assert(RT.Live() == nil and #RT.Of("sm").runs == 1 and not RT.Of("sm").runs[1].d)

print("scarlet wings: data, names, keys, loot, quests, cards, here, clock, bar, migration, old best")
