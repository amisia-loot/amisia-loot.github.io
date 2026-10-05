-- The material columns and card lines are generic: nothing material-specific shows while no
-- material is tracked, and a list set later brings them back without any item id in the pages.
local function card(key)
    for _, spec in ipairs(NS.cards) do
        if spec.key == key then return spec end
    end
end
local function fakeCard()
    local c = { text = {} }
    c.title = { SetText = function(_, t) c.text.title = t end }
    c.line1 = { SetText = function(_, t) c.text.line1 = t end }
    c.line2 = { SetText = function(_, t) c.text.line2 = t end }
    c.SetAction = function() end
    return c
end

assert(not NS.HasMats() and NS.MatLine({ [12345] = 3 }) == "", "no material, no line")
local bank = assert(card("bank"), "bank card")
if bank then
    assert(bank.available and not bank.available(), "the bank card stays away without a material")
end

NS.MATS[12345], NS.MAT_ORDER[1] = "Testerz", 12345
assert(NS.MatLine({}) == "", "nothing counted, nothing shown")
assert(NS.MatLine({ [12345] = 4 }) == "Testerz 4", NS.MatLine({ [12345] = 4 }))
if bank then
    assert(bank.available(), "the bank card appears with a material")
    AmisiaDB.bank = { at = 1789400000, counts = { [12345] = 7 }, tabs = 1, filled = 1, total = 1, by = "Vuloo" }
    local c = fakeCard()
    bank.fill(c)
    assert(c.text.line2 == "Testerz 7", tostring(c.text.line2))
    AmisiaDB.bank = nil
end

NS.GEMS[777] = true
assert(NS.MatLine({ [12345] = 1, [777] = 2 }) == "Testerz 1, Edelsteine 2", NS.MatLine({ [12345] = 1, [777] = 2 }))
assert(NS.MatLine({ [777] = 2 }) == "Testerz 0, Edelsteine 2")

NS.GEMS[777] = nil
NS.MATS[12345], NS.MAT_ORDER[1] = nil, nil
assert(NS.MatLine({ [12345] = 4 }) == "", "back to nothing")
