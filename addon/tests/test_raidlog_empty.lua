-- The raid log page without any raid: the history shows the empty state in its middle (emblem,
-- title, help) instead of an empty table head, and the counts line stays empty.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
assert(#NS.Sessions() == 0, "no raid saved")
NS.Dispatch("log")
assert(NS.CurrentPage() == "raidlog")
local f = NS.RaidLogPageFrame()
assert(f.views.verlauf.on and f.log:IsShown())
local E = f.log.empty
assert(E and E:IsShown() and not f.log.head:IsShown(), "the empty state instead of the table head")
assert(E.title:GetText() == "Noch kein Raid aufgezeichnet", E.title:GetText())
assert(has(E.text:GetText(), "Schlachtzug"), E.text:GetText())
assert(E.icon.texture == NS.W.EMBLEM or E.icon:GetTexture() == NS.W.EMBLEM, "the emblem")
assert(f.counts:GetText() == "", "the counts line stays empty: " .. tostring(f.counts:GetText()))
-- the bench view keeps its own text
f.views.bench:Click()
assert(not f.log:IsShown())
