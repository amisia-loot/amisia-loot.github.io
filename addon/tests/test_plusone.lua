-- Plus-one: counting mainspec wins per raid or ID week, the roll order with and without it, the
-- frozen count of a round, the display and the command.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function lastChat() return STUB.chat[#STUB.chat].text end
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)

---------------------------------------------------------------------------
-- counting: only living MS awards to players
---------------------------------------------------------------------------
assert(NS.PlusCount("Fraktur") == 0)
local m1 = NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Stormrage" })
local m2 = NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "MS", src = "Illidan Stormrage" })
NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "OS", src = "?" })
NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "SR", src = "?" })
NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "MS", src = "?", to = "bank" })
NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "MS", src = "?", to = "de" })
NS.AddAwardTo(s, { name = "Vuloo", item = 32235, kind = "MS", src = "?" })
assert(NS.PlusCount("Fraktur") == 2, "two MS wins: " .. NS.PlusCount("Fraktur"))
assert(NS.PlusCount("Vuloo") == 1 and NS.PlusCount("Chorf") == 0)
NS.DeleteAward(s, m2.id)
assert(NS.PlusCount("Fraktur") == 1, "a tombstone does not count")
assert(NS.PlusCount("fraktur") == 1 and NS.PlusCount("Fraktur-Thunderstrike") == 1, "the same character by SameName")
assert(NS.PlusCount(nil) == 0 and NS.PlusCount("") == 0)
-- editing the kind moves the count
NS.EditAward(s, m1.id, { kind = "OS" }); assert(NS.PlusCount("Fraktur") == 0)
NS.EditAward(s, m1.id, { kind = "MS" }); assert(NS.PlusCount("Fraktur") == 1)

---------------------------------------------------------------------------
-- scope: raid and ID week
---------------------------------------------------------------------------
local DAY = 86400
local function raid(id, start, name)
    local o = { id = id, date = date("%Y-%m-%d", start), zone = "Der Schwarze Tempel", instanceID = 564,
                start = start, last = start + 3600, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
    table.insert(AmisiaDB.sessions, 1, o)
    NS.AddAwardTo(o, { name = name, item = 32235, kind = "MS", src = "?" })
    return o
end
-- the reset is in three days, so the week began four days ago
STUB.weekReset = 3 * DAY
raid("20260930200000-564", STUB.now - 5 * DAY, "Fraktur")   -- before the week began
raid("20261003200000-564", STUB.now - 1 * DAY, "Fraktur")   -- this week
raid("20261004200000-564", STUB.now - 4 * DAY, "Chorf")     -- exactly at the start of the week
assert(NS.PlusCount("Fraktur", "raid") == 1, "raid: the running recording only")
assert(NS.PlusCount("Fraktur", "week") == 2, "week: the raid before the week does not count")
assert(NS.PlusCount("Chorf", "week") == 1 and NS.PlusCount("Chorf", "raid") == 0)
assert(NS.PlusCount("Fraktur") == 1, "the default scope is the raid")
NS.Set("awards.plusScope", "week")
assert(NS.PlusCount("Fraktur") == 2, "the setting picks the scope")
-- without the reset time the week falls back to the raid
STUB.weekReset = nil
assert(NS.PlusCount("Fraktur", "week") == 1 and NS.PlusCount("Fraktur") == 1, "no reset time: raid")
local api = C_DateAndTime
_G.C_DateAndTime = nil
assert(NS.PlusCount("Fraktur", "week") == 1, "no C_DateAndTime: raid")
_G.C_DateAndTime = api
STUB.weekReset = 3 * DAY
assert(NS.PlusCount("Fraktur", "week") == 2)
NS.Reset("awards.plusScope")
local tip = NS.SettingItem("awards.plusScope").tip
assert(tip and tip:find("Raid", 1, true) and tip:lower():find("reset", 1, true), "the tooltip tells about the fallback: " .. tostring(tip))

-- the list of everyone with a plus-one, most first
local list = NS.PlusList("week")
assert(#list == 3 and list[1].name == "Fraktur" and list[1].n == 2 and list[2].n == 1 and list[3].n == 1, "sorted by count")
assert(list[2].name == "Chorf" and list[3].name == "Vuloo", "then by name")
assert(#NS.PlusList("raid") == 2)

---------------------------------------------------------------------------
-- roll order: off by default, SR first, plus-one among MS only
---------------------------------------------------------------------------
-- state now: raid scope, Fraktur +1, Vuloo +1, Chorf +0
assert(NS.Get("awards.plusOrder") == false)
assert(NS.StartRoll(link, 10)); local r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Chorf", 50, 1, 100); roll("Vuloo", 99, 1, 99)
local rank = NS.RollRanking(r)
assert(rank[1].name == "Fraktur" and rank[2].name == "Chorf" and rank[3].name == "Vuloo", "without plusOrder the higher roll wins")
assert(r.plus.Fraktur == 1 and r.plus.Chorf == 0 and r.plus.Vuloo == 1, "the count is kept per name")
assert(NS.PlusLabel(r, "Fraktur") == "+1" and NS.PlusLabel(r, "Chorf") == nil, "without plusOrder only a count above zero shows")
NS.StopRoll()
assert(lastChat():find("Gewinner: Fraktur (90, MS, +1)", 1, true), lastChat())

NS.Set("awards.plusOrder", true)
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Chorf", 50, 1, 100); roll("Vuloo", 99, 1, 99)
rank = NS.RollRanking(r)
assert(rank[1].name == "Chorf" and rank[2].name == "Fraktur" and rank[3].name == "Vuloo", "fewer plus-one first among MS, OS untouched")
assert(NS.PlusLabel(r, "Chorf") == "+0" and NS.PlusLabel(r, "Vuloo") == nil, "with plusOrder MS shows the count, OS does not")
NS.StopRoll()
assert(r.winner == "Chorf" and lastChat():find("Gewinner: Chorf (50, MS, +0)", 1, true), lastChat())
assert(NS.ShowRollFrame and (NS.ShowRollFrame() or true))
assert(NS.RollFrame.rows[1].kind:GetText() == "MS +0" and NS.RollFrame.rows[2].kind:GetText() == "MS +1", NS.RollFrame.rows[2].kind:GetText())
assert(NS.RollFrame.rows[3].kind:GetText() == "OS")
assert(NS.RoundLine(r):find("Chorf|r (MS, +0)", 1, true), NS.RoundLine(r))

-- SR stays first whatever the count
NS.ReservedBy = function(id) return id == 32235 and { "Fraktur" } or {} end
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 3, 1, 99); roll("Chorf", 100, 1, 100)
rank = NS.RollRanking(r)
assert(rank[1].name == "Fraktur" and rank[1].rank == "SR", "SR first")
assert(NS.PlusLabel(r, "Fraktur") == nil, "no count on a reservation")
NS.StopRoll()
assert(lastChat():find("Gewinner: Fraktur (3, SR).", 1, true), lastChat())
assert(NS.RoundLine(r):find("Fraktur|r (SR)", 1, true), NS.RoundLine(r))
NS.ReservedBy = function() return {} end

-- unequal plus-one is no tie; equal plus-one still is
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Chorf", 90, 1, 100)
NS.StopRoll()
assert(r.winner == "Chorf" and not r.tie, "the lower plus-one wins the same roll")
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Vuloo", 90, 1, 100)
NS.StopRoll()
assert(r.tie and #r.tie == 2, "equal plus-one and equal roll is a tie")
assert(lastChat():find("Gleichstand: Fraktur und Vuloo (90, MS, +1)", 1, true), "the tie names the shared count: " .. lastChat())
-- with plusOrder off the same rolls tie regardless of plus-one
NS.Set("awards.plusOrder", false)
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Chorf", 90, 1, 100)
NS.StopRoll()
assert(r.tie and #r.tie == 2, "without plusOrder the count does not break a tie")
NS.Set("awards.plusOrder", true)

---------------------------------------------------------------------------
-- frozen count: an award during the round does not move the order
---------------------------------------------------------------------------
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Chorf", 50, 1, 100)
NS.AddAwardTo(s, { name = "Chorf", item = 32837, kind = "MS", src = "?" })
NS.AddAwardTo(s, { name = "Chorf", item = 32837, kind = "MS", src = "?" })
assert(NS.PlusCount("Chorf") == 2)
roll("Fraktur", 90, 1, 100)
rank = NS.RollRanking(r)
assert(rank[1].name == "Chorf" and r.plus.Chorf == 0, "the count of the round start stays")
NS.StopRoll()
assert(lastChat():find("Gewinner: Chorf (50, MS, +0)", 1, true), lastChat())
-- the next round sees the new count
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Chorf", 50, 1, 100); roll("Fraktur", 40, 1, 100)
assert(NS.RollRanking(r)[1].name == "Fraktur" and r.plus.Chorf == 2)
NS.StopRoll()
NS.Reset("awards.plusOrder")

---------------------------------------------------------------------------
-- /amisia plus
---------------------------------------------------------------------------
NS.Dispatch("plus")
assert(lastMsg():find("Chorf 2", 1, true) and lastMsg():find("Fraktur 1", 1, true) and lastMsg():find("Vuloo 1", 1, true), lastMsg())
assert(lastMsg():find("Raid", 1, true), lastMsg())
NS.Dispatch("plus Fraktur")
assert(lastMsg():find("Fraktur", 1, true) and lastMsg():find("1", 1, true), lastMsg())
NS.Dispatch("plus Niemand")
assert(lastMsg():find("Niemand", 1, true) and lastMsg():find("0", 1, true), lastMsg())
NS.Set("awards.plusScope", "week")
NS.Dispatch("plus")
assert(lastMsg():find("Woche", 1, true) and lastMsg():find("Fraktur 2", 1, true), lastMsg())
NS.Reset("awards.plusScope")
assert(NS.SlashHelpLines(true)[1] and (function()
    for _, l in ipairs(NS.SlashHelpLines(true)) do if l:find("/amisia plus", 1, true) then return true end end
end)(), "the command is in the officer help")
