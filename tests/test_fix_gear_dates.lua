-- The overview cards "Vergaben letzte Nacht" (Pages/Awards.lua) and "Soft-Reserves" (Pages/SoftRes.lua)
-- show the day as the pages do ("02.10."), never the raw saved "2026-10-02".
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local function cardOf(key)
    for _, c in ipairs(NS.cards) do if c.key == key then return c end end
end
local function fakeCard()
    local fake = { title = CreateFrame("Frame"), line1 = CreateFrame("Frame"), line2 = CreateFrame("Frame") }
    function fake:SetAction(label, fn) self.label, self.fn = label, fn end
    return fake
end
local day = NS.FmtDay(time({ year = 2026, month = 10, day = 2, hour = 12 }))
assert(day ~= "2026-10-02", "the short day")

-- the awards card, as raider and as officer
local realSessions = NS.Sessions
NS.Sessions = function() return { { date = "2026-10-02", zone = "Karazhan", awards = {} } } end
for _, view in ipairs({ "raider", "officer" }) do
    NS.Set("ui.view", view)
    local fake = fakeCard()
    cardOf("awards").fill(fake)
    local t = fake.line1:GetText()
    assert((fake.title:GetText() == "Vergaben letzte Nacht") == (view == "officer"), view .. " card: " .. tostring(fake.title:GetText()))
    assert(has(t, "Items am " .. day) and not has(t, "2026-10-02"), view .. ": " .. tostring(t))
end
NS.Sessions = realSessions
NS.Reset("ui.view")

-- the soft-reserve card
NS.SetSoftRes("Vuloo 32235\n")
AmisiaDB.softres.date = "2026-10-02"
local fake = fakeCard()
cardOf("softres").fill(fake)
local t = fake.line1:GetText()
assert(has(t, "vom " .. day) and not has(t, "2026-10-02"), tostring(t))
