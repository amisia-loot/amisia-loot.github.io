--[[without raid]]
-- The button "Amisia" at the game's guild window without the raid module (F-210): no members page, so
-- a click opens the main window on its start page; the guild window already loaded when Amisia
-- starts gets its button at the next check.
assert(NS.Panel("members") == nil, "no members page without the raid module")
_G.CommunitiesFrame = CreateFrame("Frame", "CommunitiesFrame", UIParent)
STUB.fire("PLAYER_LOGIN")
local btn = assert(NS.GuildButtons.CommunitiesFrame, "a window there before: the button at the next check")
assert(not (AmisiaFrame and AmisiaFrame:IsShown()), "the main window closed")
btn:Click()
assert(AmisiaFrame and AmisiaFrame:IsShown(), "a click opens the main window")
assert(NS.CurrentPage() == "overview", tostring(NS.CurrentPage()))
-- a second click keeps it open
btn:Click()
assert(AmisiaFrame:IsShown())
-- the guild characters still work in the core: the hello's AC and the account
STUB.level = 60
NS.GuildCharsReadOwn()
assert(AmisiaDB.account.chars["Vuloo"] and AmisiaDB.account.chars["Vuloo"].level == 60)
print("guild button without raid ok")
