-- The generated TBC data on the TBC client (the toc the tests run with): BisDataTBC.lua and
-- BisWeightsTBC.lua load after the Forever set and replace it, the rows and sources hang together,
-- tier tokens became class-limited set pieces, and the weights cover every class.
local Gear = NS.Gear
assert(Gear.Available() and Gear.Game() == "tbc" and Gear.Cap() == 70, "the TBC set loads on TBC: " .. tostring(Gear.Game()))
assert(not Gear.PlannerAvailable(), "no level-range planner on TBC")

local d = NS.GEAR
local n, kinds, phases = 0, {}, {}
for id, row in pairs(d.I) do
    n = n + 1
    assert(type(id) == "number" and type(row[1]) == "string", "row of " .. tostring(id))
    assert(row[1] == "" or Gear.GROUP[row[1]], "equip location empty or known on " .. id)
    for i = 2, 10 do assert(type(row[i]) == "number", "field " .. i .. " of " .. id) end
    assert(#row >= Gear.FIRST_SOURCE, "every item has a source: " .. id)
    for i = Gear.FIRST_SOURCE, #row do
        local rec = d.S[row[i]]
        assert(rec and Gear.KIND_ORDER[rec[1]], "source " .. row[i] .. " of " .. id)
        kinds[rec[1]] = true
        phases[Gear.PhaseOf(rec)] = true
        assert(type(Gear.SourceText(rec)) == "string")
    end
end
assert(n > 1500, "thousands of items: " .. n)
for _, k in ipairs({ "X", "D", "F", "V", "C", "W" }) do assert(kinds[k], "source kind " .. k) end
for p = 1, 5 do assert(phases[p], "phase " .. p) end

-- a raid drop, a heroic dungeon drop, a tier piece behind its token
local function sourcesOf(id)
    local out = {}
    for i = Gear.FIRST_SOURCE, #d.I[id] do out[#out + 1] = d.S[d.I[id][i]] end
    return out
end
local kara = sourcesOf(28770)[1]
assert(kara[1] == "X" and kara[4] == 532 and kara[6] == 1 and kara[3] == "Prinz Malchezaar", "Nathrezim Mindblade from Karazhan")
assert(Gear.PlaceOf(kara) == "I:532")
local t4 = d.I[29012]
assert(t4 and t4[8] == Gear.CLASS_BIT.WARRIOR, "the warrior's T4 chest is the warrior's")
local tok = sourcesOf(29012)[1]
assert(tok[1] == "X" and tok[7] == 29753 and Gear.SourceText(tok):find("(Token)", 1, true), "with the token's source")
assert(not d.I[29753], "the token itself is no gear")
local heroic = false
for _, rec in ipairs(sourcesOf(29255)) do if rec[1] == "D" and rec[7] == 1 then heroic = true end end
assert(heroic and Gear.FilterKey(sourcesOf(29255)[1]) == "H", "Bands of Rarefied Magic from a heroic")
assert(d.Z[111], "zone names for the vendors")

-- weights: every class, a unit worth 1 in every spec
local w = NS.GEAR_WEIGHTS
assert(#w.order == 9)
for _, token in ipairs(w.order) do
    local specs = Gear.Specs(token)
    assert(#specs >= 1, token .. " has specs")
    for _, sp in ipairs(specs) do
        local all = Gear.Weights(token, sp.key, nil, 70)
        assert(all and Gear.Unit(all) == all.unit, token .. " " .. sp.key .. " has a unit worth 1")
    end
end
assert(Gear.Weights("WARRIOR", "dps", nil, 70).OHDPS == 0.5 and Gear.Weights("SHAMAN", "enh", nil, 70).OHDPS == 0.5)

-- a best list comes out of it once the client describes the items
Gear._reset()
local o = { class = "WARRIOR", spec = "dps", level = 70, sources = { X = true, H = true, D = true, F = true, V = true, C = true, W = true } }
local r = Gear.Best(o)
assert(r.total > 0 and r.missing > 0, "the rows wait for the client")
