--[[locale enUS]]
-- The three small actions of 2.27.4 on an English client: "Remove points" with its question and
-- /amisia points clear, the prio dialog's "Clear" and /amisia prio <item link> clear, "Show in
-- calendar" in the raid calendar window. No German text reaches the screen or the chat.
local function german(text) return type(text) == "string" and text:find("[\195][\164\182\188\132\150\156\159]") ~= nil end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
STUB.now = 1791400000

local SITE = "#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 pub=1\nP Vuloo 120\n#END"
NS.Set("ui.view", "officer")
assert(NS.SetPointsSite(SITE))
assert(NS.PointsAdjust("Vuloo", 5, "bonus"))
NS.ShowPoints("paste")
local f = NS.PointsPageFrame()
assert(f.clear:IsShown() and f.clear:GetText() == "Remove points", f.clear:GetText())
f.clear:Click()
local Q = AmisiaConfirmFrame
assert(Q:IsShown() and Q:GetTitleText():GetText() == "Remove the standings?", Q:GetTitleText():GetText())
assert(Q.ok:GetText() == "Remove" and not german(Q.text:GetText()), Q.text:GetText())
assert(has(Q.text:GetText(), "The website keeps its standings") and has(Q.text:GetText(), "Corrections not on the website yet: 1"), Q.text:GetText())
STUB.messages = {}
Q.ok:Click()
assert(NS.PointsInfo() == nil and has(lastMsg(), "Standings removed. Paste brings them back from the website."), lastMsg())
assert(NS.SetPointsSite(SITE))
NS.Dispatch("points clear")
assert(Q:IsShown(), "points clear asks")
Q.ok:Click()
NS.Dispatch("points clear")
assert(has(lastMsg(), "No standings stored."), lastMsg())

local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.EditLootPrio(link, "Anna", ""))
local D = NS.ShowPrioDialog(link)
assert(D.clear:GetText() == "Clear" and has(D.hint:GetText(), "\"Clear\" removes the prio at once"), D.hint:GetText())
STUB.messages = {}
D.clear:Click()
assert(not D:IsShown() and NS.LootPrioOf(32235) == nil)
assert(has(lastMsg(), "Loot prio of") and has(lastMsg(), "cleared") and not german(lastMsg()), lastMsg())
assert(NS.EditLootPrio(link, "Anna", ""))
NS.Dispatch("prio " .. link .. " clear")
assert(NS.LootPrioOf(32235) == nil and has(lastMsg(), "cleared"), lastMsg())

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
NS.Set("ui.view", "raider")
STUB.guild = { { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 } }
STUB.calendar({ events = { { title = "Molten Core", days = 1, eventType = 0, id = 12, inviteStatus = 7 } }, invites = {} })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
NS.ShowRaidCalendar(NS.SignupTerms()[1].night)
STUB.tick(1)
local F = NS._raidCalUI.frame()
assert(F.page:IsShown() and F.page:GetText() == "Show in calendar", F.page:GetText())
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(F, NS.Theme.RAIDCAL.W, NS.Theme.RAIDCAL.H)
    Lay.row("raid calendar bottom (en)", F.status, F.page, F.signup)
end
F.page:Click()
assert(NS.CurrentPage() == "calendar" and not F:IsShown())
print("quick actions en ok")
