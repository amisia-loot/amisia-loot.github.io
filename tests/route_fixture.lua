-- The profession route data the route tests share (dofile from a test): a small hand-made
-- tailoring with an intermediate (bolt), trainer tiers with costs (T), learning costs (L), vendor
-- prices of reagents and recipe items (V), a vendor recipe, one of the other faction and a drop
-- recipe. Not real data.
STUB.faction = "Alliance"
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3 }
STUB.maps[1453] = { name = "Sturmwind", parent = 1415, mapType = 3 }
local SPELLS = { [2963] = "Leinenstoffballen", [2393] = "Leinenhemd", [3914] = "Leinentasche", [3915] = "Leinenkappe",
    [3916] = "Garnband", [3917] = "Garnkordel", [3918] = "Garnschleife", [3919] = "Wollweste", [3920] = "Wollhose",
    [3921] = "Seidenrobe", [3922] = "Seidenkapuze", [3923] = "Rotes Leinenhemd", [3924] = "Dropmantel", [3925] = "Hordenhemd" }
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] end,
    GetSpellDescription = function() return "" end,
}
NS.PROFESSIONS = {
    built = "2026-11-06", client = "1.60.1.1", source = "abc",
    P = { { 197, "tailoring" }, { 171, "alchemy" }, { 182, "herbalism" }, { 186, "mining" } },
    R = {
        [197] = {
            "2963:2996:1:1:25:40:A",            -- bolt of linen: 2 linen (the intermediate)
            "2393:2576:1:1:30:50:A",            -- linen shirt: 1 bolt + 1 thread (learned with the profession)
            "3914:4343:1:45:60:90:T1",          -- 1 linen, learned from 45 (costs 1s to learn)
            "3915:4344:1:45:60:90:T1",          -- the same as 3914
            "3916:4345:1:1:100:160:T2",         -- 2 thread (20c)
            "3917:4346:1:1:100:160:T2",         -- 1 thread + 1 dye (20c, two reagents)
            "3918:4347:1:1:100:160:T2",         -- 2 dye (20c)
            "3919:4348:1:1:170:210:T3",         -- 3 linen
            "3920:4349:1:1:210:250:T3",         -- 3 linen
            "3921:4350:1:1:260:300:T4",         -- 4 linen
            "3922:4351:1:1:300:340:T4",         -- 4 linen
            "3923:4352:1:1:120:200:I9001",      -- vendor recipe (50s), 1 linen
            "3924:4353:1:1:1:300:I9002",        -- drop recipe, never planned unless known
            "3925:4354:1:1:150:250:I9003",      -- the Horde vendor's recipe
        },
        [171] = { "2330:118:3:1:25:55:A" },
        [186] = { "2657:2840:1:1:25:47:A" },   -- smelting copper: copper ore -> copper bar
    },
    I = { [9001] = "3923:115:0:0:V80100", [9002] = "3924:0:0:0:D80300", [9003] = "3925:0:0:0:V80200" },
    G = { [2963] = "2589:2", [2393] = "2996:1,2320:1", [3914] = "2589:1", [3915] = "2589:1", [3916] = "2320:2",
        [3917] = "2320:1,2324:1", [3918] = "2324:2", [3919] = "2589:3", [3920] = "2589:3", [3921] = "2589:4",
        [3922] = "2589:4", [3923] = "2589:1", [3924] = "2589:1", [3925] = "2589:1", [2330] = "2447:1,765:1",
        [2657] = "2770:1" },
    N = { [80100] = "Suppla Smith|1429:1250:3300|", [80101] = "Far Vendor|1453:5000:5000|",
          [80300] = "Skyforged Golem|1429:7000:7000|", [80200] = "Gor'mak|1429:4980:2960|H" },
    Q = {},
    V = { [2320] = "10:80101,80100", [2324] = "10:80100", [9001] = "5000:80100", [9003] = "100:80200" },
    S = { [2589] = 10 },             -- linen: no vendor, sells for 10 copper (the estimate: 40)
    L = { [3914] = 100, [3915] = 100 },
    T = { [197] = { "1:75:10", "2:150:500", "3:225:5000", "4:300:50000" } },
}
NS.Prof._reset()
if NS.ProfRoute then NS.ProfRoute._reset() end
