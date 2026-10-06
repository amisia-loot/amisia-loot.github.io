-- The professions data the professions tests share (dofile from a test): a small hand-made
-- ProfessionData, the client's German spell names and a zone. Not real data.
STUB.faction = "Alliance"
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3 }
local SPELLS = { [2663] = "Kupferarmschienen", [3321] = "Kupferkettenweste", [1252229] = "Edelsteinbesetzte Kupferstiefel",
    [1301421] = "Wolkiges Himmelsgeschmiedetes Kettenhemd", [2330] = "Schwacher Heiltrank", [1234001] = "Elixier des schwachen Intellekts",
    [1229737] = "Einfaches Lagerfeuer", [1307175] = "Amboss" }
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] end,
    GetSpellDescription = function(id) if id == 1307175 then return "Stellt einen Amboss auf." end return "" end,
}
NS.PROFESSIONS = {
    built = "2026-10-06", client = "1.60.1.1", source = "abc",
    P = { { 171, "alchemy" }, { 164, "blacksmithing" }, { 185, "cooking" } },
    R = {
        [171] = { "2330:118:3:1:25:55:A", "1234001:250001:1:50:60:90:I250388" },
        [164] = { "2663:2853:1:1:20:60:A", "3321:3471:1:10:35:75:I3609", "1252229:251001:1:1:50:80:T1",
                  "1301421:276992:1:60:60:100:I276928", "9999:0:0:1:40:70:" },
        [185] = { "1229737:279981:1:1:1:5:A" },
    },
    I = { [3609] = "3321:10:0:0:V80100", [276928] = "1301421:60:2758:5:D80300",
          [250388] = "1234001:50:0:0:F45@4A,F50@4H,D80400" },
    G = { [2663] = "2840:2" },
    N = { [80100] = "Suppla Smith|1429:1250:3300|", [80300] = "Skyforged Golem|1429:7000:7000|", [80400] = "Vale Ooze|1429|",
          [80200] = "Gor'mak|1429:4980:2960|H", [80201] = "Hilda|1429:5000:3000|A" },
    Q = {},
    CAMP = { "279981:185:1:1307227:1229737:3:0", "279944:164:20:1307392:1230171:0:0", "279988:164:140:1307175:1263041:0:279944" },
    FAVOR = { currency = 3402, vendor = { A = { 80201 }, H = { 80200 } }, cert = { [164] = 271622 }, writ = { [3471] = 264020 } },
}
NS.Prof._reset()
