-- The roll window (RollWindow.lua, D-38) with names that share a first name, on one client (Vuloo):
-- another raider's roll line ("Vuloo Stern") never shows as the own number nor closes the own
-- buttons; an end message (WE) from a raider whose first name is the lead's ("Fraktur Stein") ends
-- nothing; a bid stands (Passen is off after it); a new round starts with an empty bid field.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function recv(text, chan, sender)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", text, chan or "RAID", sender or "Fraktur", "", 0, 0, "", 0)
end
local function ws(fields) return "1WS\t" .. table.concat(fields, "\t") end
RandomRoll = function() end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Vuloo Stern", class = "WARRIOR" }, { name = "Fraktur Stein", class = "MAGE" } }
STUB.playerRaidIndex = 1
STUB.guild = { { name = "Vuloo", rank = 4 }, { name = "Fraktur", rank = 1 }, { name = "Vuloo Stern", rank = 4 },
               { name = "Fraktur Stein", rank = 4 } }
STUB.rankFlags = { [1] = { [22] = true } }
STUB.officer = false
STUB.lootMethod, STUB.mlRaidID = 2, 2
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(30000, "Brustplatte", 4)

local function win() return AmisiaRollWindow end
local function row(i) return win().rows[i or 1] end

-- another raider's roll line: not the own number, the own buttons stay
recv(ws({ "a1b2", "item:32235", "20", "R", "-", "-", "-", "-", "-" }))
assert(win() and win():IsShown(), "the lead's round opens the window")
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo Stern", 55, 1, 100))
assert(row().r.rolled == nil and row().r.choice == nil, "Vuloo Stern's roll is not Vuloo's")
assert(row().ms:IsEnabled() and row().os:IsEnabled(), "the own buttons stay open")
assert(not has(row().status:GetText(), "55"), row().status:GetText())
-- the own line still counts
row().ms:Click()
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo", 64, 1, 100))
assert(has(row().status:GetText(), "Gewürfelt: Mainspec 64"), row().status:GetText())

-- an end from Fraktur Stein does not end Fraktur's round
recv("1WE\ta1b2\tD\tVuloo Stern\t99:MS", "RAID", "Fraktur Stein")
assert(not row().r.done, "a raider sharing the lead's first name ends nothing")
recv("1WE\ta1b2\tD\tVuloo\t64:MS")
assert(row().r.done and has(row().status:GetText(), "Gewinner: Vuloo (64, MS)"), row().status:GetText())
STUB.tick(6)

-- a bid round: after a bid Passen is off (the bid stands at the lead)
STUB.tick(1.1)
recv(ws({ "c3d4", "item:30000", "20", "B", "-", "-", "10", "-", "-" }))
assert(row().bidBtn:IsShown() and row().pass:IsEnabled())
row().bidEdit:SetText("25"); row().bidBtn:Click()
assert(has(row().status:GetText(), "Geboten: 25"), row().status:GetText())
assert(not row().pass:IsEnabled(), "a bid stands: no Passen after it")
assert(row().bidBtn:IsEnabled(), "a higher bid is still open")

-- a new round replaces it: the bid field starts empty
row().bidEdit:SetText("25")
STUB.tick(1.1)
recv(ws({ "e5f6", "item:32235", "20", "B", "-", "-", "10", "-", "-" }))
assert(row().r.rid == "e5f6", "the new round")
assert(row().bidEdit:GetText() == "", "no amount of the round before: " .. tostring(row().bidEdit:GetText()))
assert(row().pass:IsEnabled(), "Passen open in the new round")
win().CloseButton:Click()
print("roll window names ok")
