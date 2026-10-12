-- Small fixes of the 2026-10-12 audit: the overview card slot starts without a line limit; a
-- material id must be a whole positive number.

-- 1. a card that limits its second line does not pass the limit on to the next card in its slot
NS.ShowPage("overview")
local f = NS.OverviewPageFrame and NS.OverviewPageFrame()
assert(f and f.cards and f.cards[1], "the overview cards")
for _, c in ipairs(f.cards) do c.line2:SetMaxLines(2) end
NS.Refresh()
for i, c in ipairs(f.cards) do
    -- only the gear card sets two lines itself
    if c:IsShown() and (c.title:GetText() or "") ~= "" and c.title:GetText() ~= "Deine Ausrüstung" then
        assert(c.line2.maxLines ~= 2, "slot " .. i .. " keeps an old line limit: " .. tostring(c.title:GetText()))
    end
end

-- 2. /amisia mats add 0 or -5 is refused
local ok = NS.AddMat("0")
assert(not ok, "0 is no item")
ok = NS.AddMat("-5")
assert(not ok, "-5 is no item")
ok = NS.AddMat("1.5")
assert(not ok, "1.5 is no item")
