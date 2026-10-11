-- Cost of the collector at its caps (review 26): filling full tables, the load check of every
-- record, one put that prunes, many puts, and merging a 40-item vendor again. The bounds are loose
-- (a slow machine passes); the times printed are for comparison between versions.
local L = NS.COLLECT_LIMITS
local TODAY = NS.DropsToday()
AmisiaDB.collect = nil
NS.CollectMigrate(AmisiaDB)
local t0 = os.clock()
for i = 1, L.q do
    NS.CollectPut("q", 30000 + i, ("%d;0;%d;1440:%d:%d;%d;1440:4512:3321;%d,%d;%d,%d,%d;%d;%d;H;%d;Questgeber Name;Eine typische Quest %d"):format(
        TODAY - (i % 50), 3000 + i, 1000 + i % 9000, 2000 + i % 7000, 4000 + i, 200000 + i, 200001 + i, 210000 + i, 210001 + i, 210002 + i,
        20 + i % 40, 18 + i % 40, i, i), "own")
end
for i = 1, L.s do
    local items = {}
    for j = 1, 40 do items[j] = ("%d:%d:L:5@Orgrimmar"):format(220000 + i * 100 + j, 1000 + j * 37) end
    NS.CollectPut("s", 40000 + i, ("%d;0;1440:2311:5512;%s;Händlerin Name %d"):format(TODAY, table.concat(items, ","), i), "own")
end
for i = 1, L.w do
    NS.CollectPut("w", 50000 + i, ("%d;0;n;1440:%d:%d;0;%d:1,%d:2;Ein Mob %d"):format(TODAY, 1000 + i % 9000, 3000 + i % 6000, 230000 + i, 230001 + i, i), "own")
end
local fill = os.clock() - t0
local c = NS.CollectCounts()
assert(NS.CollectBytes() <= L.bytes, "within the budget")
t0 = os.clock()
NS.CollectMigrate(AmisiaDB)
local migrate = os.clock() - t0
assert(NS.CollectCounts().q == c.q, "the load check keeps every valid record")
t0 = os.clock()
NS.CollectPut("w", 9999, ("%d;0;n;;0;1:1;x"):format(TODAY), "own")
for i = 1, 200 do NS.CollectPut("w", 60000 + i, ("%d;0;n;;0;1:1;x"):format(TODAY), "own") end
local puts = os.clock() - t0
t0 = os.clock()
local vendor = AmisiaDB.collect.s[40001] or AmisiaDB.collect.s[next(AmisiaDB.collect.s)]
for _ = 1, 100 do NS.CollectPut("s", 40001, vendor) end
local same = os.clock() - t0
print(("collector at the caps: %d/%d/%d records; fill %.2f s, load check %.3f s, 201 puts %.3f s, 100 vendor merges %.3f s"):format(
    c.q, c.s, c.w, fill, migrate, puts, same))
assert(migrate < 2 and puts < 2 and same < 2, "the collector stays cheap at its caps")
