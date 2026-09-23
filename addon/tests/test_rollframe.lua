-- The roll window: alt-click start, rows, hand-out through master loot.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.loot = { { link = STUB.item(30000, "Other", 4), name = "Other" }, { link = link, name = "Cursed Vision of Sargeras" } }

-- alt-click without a loot window does nothing
STUB.alt = true; HandleModifiedItemClick(link); STUB.alt = false
assert(NS.CurrentRoll() == nil, "no round without a loot window")

STUB.fire("LOOT_OPENED")
STUB.alt = true; HandleModifiedItemClick(STUB.item(777, "Bag Item", 4)); STUB.alt = false
assert(NS.CurrentRoll() == nil, "alt-click on an item outside the loot window does nothing")
HandleModifiedItemClick(link)
assert(NS.CurrentRoll() == nil, "plain modified click without alt does nothing")
STUB.alt = true; HandleModifiedItemClick(link); STUB.alt = false
local r = NS.CurrentRoll(); assert(r and r.item == 32235, "alt-click started the round")
assert(NS.RollFrame and NS.RollFrame:IsShown(), "window opened")

STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 77, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo", 80, 1, 50))
assert(NS.RollFrame.rows[1].name:GetText():find("Fraktur", 1, true))
assert(NS.RollFrame.rows[1].who == "Fraktur" and NS.RollFrame.rows[1].kind:GetText() == "MS")
assert(NS.RollFrame.rows[2].who == nil and NS.RollFrame.rows[2].why:GetText():find("Bereich 1-50", 1, true))
assert(not NS.RollFrame.rows[3]:IsShown())

-- no hand-out while the round runs: the rows still re-sort
assert(not NS.RollFrame.rows[1].award:IsEnabled(), "button disabled during the round")
NS.RollFrame.rows[1].award:Click()
assert(STUB.given == nil and STUB.popup == nil, "nothing given or asked during the round")
NS.StopRoll()
assert(r.done and NS.RollFrame.rows[1].award:IsEnabled(), "button enabled once the round is over")

-- the button asks first; cancelling gives nothing
NS.RollFrame.rows[1].award:Click()
assert(STUB.popup and STUB.popup.which == "AMISIA_GIVE" and STUB.popup.a2 == "Fraktur" and STUB.popup.a1 == link, "asks with item and name")
STUB.popup = nil
assert(STUB.given == nil, "no hand-out without accepting")

-- the question keeps its item even when a new round starts before it is answered
NS.RollFrame.rows[1].award:Click()
local asked = STUB.popup
local other = STUB.loot[1].link
STUB.alt = true; HandleModifiedItemClick(other); STUB.alt = false
assert(NS.CurrentRoll().item == 30000, "second round running")
STUB.popup = asked; STUB.acceptPopup()
assert(STUB.given and STUB.given.slot == 2 and STUB.given.i == 2, "GiveMasterLoot called with the asked item's slot and candidate")
NS.StopRoll()
STUB.fire("LOOT_SLOT_CLEARED", 2)
local s = NS.Active()
assert(#s.awards == 1 and s.awards[1].name == "Fraktur" and s.awards[1].item == 32235, "hand-out recorded for the asked item")

STUB.given = nil
STUB.loot = { STUB.loot[1] }
NS.AwardFromRoll("Fraktur", 32235)
assert(STUB.given == nil and STUB.messages[#STUB.messages]:find("nicht mehr im Lootfenster", 1, true))

STUB.fire("LOOT_CLOSED")
NS.AwardFromRoll("Fraktur")
assert(STUB.messages[#STUB.messages]:find("Lootfenster", 1, true), "hint without loot window")

-- the round ends by itself when the time is up
local r2 = NS.StartRoll(link, 5) and NS.CurrentRoll()
STUB.tick(5)
assert(r2.done)
NS.ToggleRollFrame(); assert(not NS.RollFrame:IsShown())
NS.ToggleRollFrame(); assert(NS.RollFrame:IsShown())
