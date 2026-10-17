--[[locale enUS]]
-- The window "Ausrüstungsziele" on an English client (F-110 to F-113): its title, the switch, the
-- filter chips, the panel and the score head in English; /amisia bis big.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Dispatch("bis big")
local win = assert(_G.AmisiaGoalsFrame, "the window")
assert(win:IsShown() and win:GetTitleText():GetText() == "Gear Goals", win:GetTitleText():GetText())
assert(win.doll.goals.label:GetText() == "Goals" and win.doll.worn.label:GetText() == "Worn", "the switch")
local P = win.progress
assert(has(P.text:GetText(), "You have ") and has(P.text:GetText(), "/17 goals"), P.text:GetText())
assert(P.chips.all.label:GetText() == "All" and has(P.chips.todo.label:GetText(), "To get ")
    and has(P.chips.bag.label:GetText(), "In bags ") and has(P.chips.ench.label:GetText(), "Not enchanted "), "the filters")
local S = win.side
assert(S.pickHead:GetText() == "Your pick" and S.fieldHead:GetText() == "Item link or ID" and S.add:GetText() == "Add", "the panel")
assert(has(S.rankHead:GetText(), "Ranking for "), S.rankHead:GetText())
assert(has(win.score.score:GetText(), "Score ") and has(plain(win.score.now:GetText()), "now "), "the score head")
assert(has(win.score.best:GetText(), "Best at level 60: "), win.score.best:GetText())
-- a ring refused for the head, in English
S.slot = "HEAD"
local ok, why = NS.BisSetPick("HEAD", "no item")
assert(not ok and why == "No item.", tostring(why))
