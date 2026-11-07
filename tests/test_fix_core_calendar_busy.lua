-- The raid calendar window while the calendar stays busy with another reader: one retry after
-- RC.BUSY_RETRY at a time, however many reads (the poll, the calendar's changes) answered "busy";
-- the reads per retry gap do not grow (audit 2026-11-07).
local RC, Cal = NS.RaidCal, NS.Cal
STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = { { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 } }
STUB.calendar({ silent = true, events = { { title = "test123", days = 1, eventType = 4, id = 18866, inviteStatus = 6 } },
    invites = { [18866] = { { name = "Vulo Pala", classFilename = "PALADIN", level = 58, inviteStatus = 6 } } } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local t = NS.SignupTerms()[1]
local reads = 0
local read = Cal.Read
Cal.Read = function(...) reads = reads + 1; return read(...) end

Cal.Hold(true)
NS.ShowRaidCalendar(t.night)
-- the calendar changes now and then, the poll reads every RC.POLL seconds
for _ = 1, 8 do
    STUB.fire("CALENDAR_CHANGED")
    STUB.tick(RC.POLL / 2)
end
local before = reads
local span = 10 * RC.BUSY_RETRY
STUB.tick(span)
local n = reads - before
-- one retry chain (span / BUSY_RETRY reads) and at most the poll's own read in between
assert(n <= span / RC.BUSY_RETRY + 2, "reads while busy stay at one retry per gap: " .. n)
Cal.Hold(false)
STUB.tick(RC.BUSY_RETRY + 0.1)
