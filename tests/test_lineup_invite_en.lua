--[[locale enUS]]
-- Inviting and sorting the lineup on an English client (F-084, F-100): the invite view's buttons and
-- reasons, the statuses read from the English system message templates, the fixed whisper text, the
-- chat lines of "inv" and the sort, /amisia lineup invite and sort. No German text reaches the screen
-- or the chat.
local function german(text) return type(text) == "string" and text:find("[\195][\164\182\188\132\150\156\159]") ~= nil end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end

_G.ERR_DECLINE_GROUP_S = "%s declines your group invitation."
_G.ERR_JOINED_GROUP_S = "%s joins the party."
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
STUB.roster, STUB.leader = {}, true
_G.UnitIsGroupLeader = function() return STUB.leader end
local INV = {}
C_PartyInfo.InviteUnit = function(name) INV[#INV + 1] = name end

local night = NS.SetLineupText("Anna Bergmann Healer\nBob Eisherz Tank")
NS.LineupAutoAssign(night)
NS.ShowLineup("invite", night)
local f = NS.LineupPageFrame()
assert(f.inviteAll:GetText() == "Invite all (2)", f.inviteAll:GetText())
assert(f.again:GetText() == "Invite again (0)", f.again:GetText())
assert(has(f.calLine:GetText(), "still to invite 2") and not german(f.calLine:GetText()), f.calLine:GetText())
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
STUB.tick(0.1)
assert(f.inviteAll:GetText() == "Not in combat", f.inviteAll:GetText())
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(0.1)

-- the whisper text and the statuses from the English templates
NS.Set("lineup.whisper", true)
STUB.chat, STUB.messages = {}, {}
NS.Dispatch("lineup invite")
STUB.tick(2)
assert(#INV == 2 and said("Inviting: 2 players, one every 0.5 seconds."), STUB.messages[1])
assert(STUB.chat[1] and STUB.chat[1].text:match("^Amisia: Raid invite %(group %d%)%. Please accept%.$"), STUB.chat[1] and STUB.chat[1].text)
STUB.fire("CHAT_MSG_SYSTEM", ERR_DECLINE_GROUP_S:format("Bob Eisherz"))
NS.Refresh()
assert(f.again:GetText() == "Invite again (1)", f.again:GetText())
local row
for _, r in ipairs(f.invRows.rows) do
    if r:IsShown() and r.item and r.item.e and r.item.e.n == "Bob Eisherz" then row = r end
end
assert(row and has(row.st:GetText(), "declined") and row.tries:GetText() == "1/3", row and row.st:GetText())
NS.Set("lineup.whisper", false)

-- "inv" and the sort in the own chat
NS.Set("lineup.inv", true)
STUB.messages = {}
STUB.fire("CHAT_MSG_WHISPER", "inv", "Zora Fremd")
STUB.tick(1)
assert(said("Invite on whisper: Zora Fremd is not in the guild, not invited."), STUB.messages[1])
NS.Dispatch("lineup sort")
assert(said("Only in a raid"), STUB.messages[#STUB.messages])
for _, m in ipairs(STUB.messages) do assert(not german(m), m) end
NS.ShowLineup("planner", night)
assert(f.sortBtn:GetText() == "Sort groups" and has(f.calLine:GetText(), "Sorting: Only in a raid"), f.calLine:GetText())
NS.Set("lineup.inv", false)
