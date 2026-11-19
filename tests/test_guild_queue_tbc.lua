--[[preload
C_PvP.GetBattlegroundInfo = nil
C_PvP.IsActiveBattlefield = nil
STUB.bgTypes = { { name = "Alterac Valley", id = 1 }, { name = "Warsong Gulch", id = 2 }, { name = "Arathi Basin", id = 3 },
                 { name = "Eye of the Storm", id = 7 } }
]]
--[[game tbc]]
-- Gilden-Warteschlange on TBC Anniversary (F-227, D-155, D-57): without C_PvP.GetBattlegroundInfo the numbers come
-- from the returns of the global GetBattlegroundInfo; the own queue opens the window and goes to the guild, a
-- member's state stands under its battleground, a battleground (instance type "pvp") sends nothing.
local GQ = NS.GuildQueue
assert(GQ, "the guild queue loads on TBC")
STUB.guild = { { name = "Vuloo", rank = 1, class = "MAGE" }, { name = "Kim", rank = 4, class = "WARRIOR" } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.instance = { name = "Shattrath", type = "none", id = 530 }
assert(GQ.IdOf("Eye of the Storm") == 7 and GQ.IdOf("warsong gulch") == 2, "the global's fifth return")
assert(GQ.Name(7) == "Eye of the Storm" and GQ.Name(99) == "Schlachtfeld 99")

-- an arena queue (a team size) is no battleground
STUB.queues[1] = { status = "queued", map = "Arathi Basin", waited = 1000, teamSize = 2 }
STUB.queues[2] = { status = "queued", map = "Eye of the Storm", waited = 125000, est = 0 }
STUB.fire("UPDATE_BATTLEFIELD_STATUS")
assert(GQ.Shown(), "the window opens")
local rows = GQ.Rows()
assert(#GQ.ReadOwn() == 1, "the arena is passed over")
assert(rows[1].left == "Eye of the Storm" and rows[1].right == "2:05", "no estimate: the wait alone: " .. tostring(rows[1].right))
STUB.tick(3)
local sent
for _, m in ipairs(STUB.addon) do if m.text:find("^1QW") then sent = m end end
assert(sent and sent.chan == "GUILD" and sent.text == "1QW\t1\t7:W:125", sent and sent.text)

STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t7:W:300", "GUILD", "Kim")
STUB.tick(1)
rows = GQ.Rows()
assert(rows[2].kind == "mate" and rows[2].name == "Kim" and rows[2].right == "5:01", tostring(rows[2].right))
assert(rows[2].left == "|cffc79c6eKim|r", "the warrior's colour: " .. tostring(rows[2].left))

-- inside: the window closes, nothing goes
STUB.queues[2].status = "active"
STUB.instance = { name = "Eye of the Storm", type = "pvp", id = 566 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("UPDATE_BATTLEFIELD_STATUS")
assert(not GQ.Shown(), "closed inside a battleground")
local n = #STUB.addon
STUB.tick(90)
for i = n + 1, #STUB.addon do assert(not STUB.addon[i].text:find("^1QW"), "nothing inside") end
print("guild queue tbc ok")
