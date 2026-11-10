-- The scanned names (Data/ScanNames.lua, F-172): tests see none by default (tests/run.py), a table
-- set as STUB.scanNames, or the shipped file with STUB.shippedScanNames.
local loc = NS.ScanById.Locale()
assert(NS.ScannedQuestTitle(2) == nil and NS.ScannedNpcName(11517) == nil, "no shipped names in a test")
STUB.scanNames = { L = { [loc] = { Q = { [501] = "Ein Testtitel" }, N = { [7] = "Ein Testname" } } } }
assert(NS.ScannedQuestTitle(501) == "Ein Testtitel" and NS.ScannedNpcName(7) == "Ein Testname")
assert(NS.ScannedQuestTitle(502) == nil and NS.ScannedNpcName(8) == nil)
STUB.scanNames = nil
-- the shipped file loads and is well formed: every language part holds titles by quest id
STUB.shippedScanNames = true
local d = NS.Data("SCAN_NAMES")
assert(type(d) == "table" and type(d.L) == "table", "the shipped names")
for lang, part in pairs(d.L) do
    assert(type(lang) == "string" and type(part) == "table")
    for id, title in pairs(part.Q or {}) do
        assert(type(id) == "number" and type(title) == "string" and title ~= "", tostring(id))
    end
end
STUB.shippedScanNames = nil
print("scan names ok")
