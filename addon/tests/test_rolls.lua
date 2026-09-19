-- Roll rounds: parsing, ranking, countdown, ties, reserved names.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end
local function lastChat() return STUB.chat[#STUB.chat].text end

assert(NS.StartRoll("no link") == nil)
assert(NS.StartRoll(link, 20))
local r = NS.CurrentRoll(); assert(r and r.item == 32235 and r.seconds == 20)
assert(STUB.chat[1].text:find("/roll 99", 1, true) and STUB.chat[1].text:find("20 Sekunden", 1, true), STUB.chat[1].text)
roll("Fraktur", 57, 1, 100); roll("Chorf", 80, 1, 99); roll("Fraktur", 99, 1, 100); roll("Stranger", 100, 1, 100); roll("Vuloo", 12, 1, 50)
assert(r.rolls.Fraktur.value == 57 and r.rolls.Fraktur.kind == "MS" and r.rolls.Fraktur.class == "SHAMAN")
assert(r.rolls.Chorf.kind == "OS")
assert(not r.rolls.Stranger and not r.rolls.Vuloo)
assert(#r.ignored == 3, "duplicate, stranger and wrong range listed")
assert(r.ignored[1].why == "schon gewürfelt" and r.ignored[3].why == "Bereich 1-50")
local rank = NS.RollRanking(r)
assert(rank[1].name == "Fraktur" and rank[2].name == "Chorf", "MS beats a higher OS")
assert(rank[1].rank == "MS" and rank[2].rank == "OS")
-- countdown and end
STUB.tick(10); assert(lastChat():find("10 Sekunden", 1, true), lastChat())
STUB.tick(5); assert(lastChat():find("5 Sekunden", 1, true), lastChat())
STUB.tick(5); assert(r.done and r.winner == "Fraktur", "winner after the timer")
assert(lastChat():find("Gewinner: Fraktur (57, MS)", 1, true), lastChat())
assert(NS.RollKind(32235, "Fraktur") == "MS" and NS.RollKind(32235, "Chorf") == "OS" and NS.RollKind(32235, "Vuloo") == "-")
assert(NS.RollKind(1, "Fraktur") == "-")
roll("Vuloo", 100, 1, 100); assert(not r.rolls.Vuloo, "rolls after the end are ignored")

-- tie and re-roll restricted to the tied names
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Chorf", 90, 1, 100); roll("Vuloo", 90, 1, 99); STUB.tick(10)
assert(r.done and not r.winner and #r.tie == 2, "tie detected among the same rank only")
assert(lastChat():find("Gleichstand: Fraktur und Chorf (90, MS)", 1, true), lastChat())
assert(NS.RerollTie()); r = NS.CurrentRoll()
assert(lastChat():find("Stechen: Fraktur, Chorf", 1, true), lastChat())
roll("Vuloo", 100, 1, 100); roll("Chorf", 5, 1, 100); roll("Fraktur", 4, 1, 100); STUB.tick(10)
assert(r.winner == "Chorf", "only tied names count in the re-roll")
assert(r.ignored[1].name == "Vuloo")

-- stop early, nobody rolled
assert(NS.StartRoll(link, 20)); NS.StopRoll()
assert(NS.CurrentRoll().done and lastChat():find("Niemand", 1, true))
assert(NS.RerollTie() == nil)

-- starting a new round ends the running one
assert(NS.StartRoll(link, 20)); roll("Fraktur", 1, 1, 100)
assert(NS.StartRoll(link, 20)); assert(NS.LastRoll().done and NS.LastRoll().winner == "Fraktur")
NS.StopRoll()

-- reserved first, also with an OS roll
NS.ReservedBy = function(id) return id == 32235 and { "Chorf" } or {} end
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
assert(lastChat():find("Reserviert von Chorf", 1, true))
roll("Fraktur", 100, 1, 100); roll("Chorf", 3, 1, 99); STUB.tick(10)
assert(r.winner == "Chorf" and NS.RollKind(32235, "Chorf") == "SR")
assert(NS.RollRanking(r)[1].rank == "SR")

-- realm suffix in the roll line
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur-Thunderstrike", 42, 1, 100)
assert(r.rolls.Fraktur and r.rolls.Fraktur.value == 42)
NS.StopRoll()

-- default duration from the settings
AmisiaDB.settings.rollSeconds = 30
assert(NS.StartRoll(link)); assert(NS.CurrentRoll().seconds == 30); NS.StopRoll()

-- alone: no announcement, the round still runs
STUB.roster = {}
local n = #STUB.chat
assert(NS.StartRoll(link, 5)); STUB.tick(5)
assert(#STUB.chat == n and NS.CurrentRoll().done)
