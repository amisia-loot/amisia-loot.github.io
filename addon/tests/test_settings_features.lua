-- Every feature reads its settings through the registry, and the old commands still work.
local function has(path) return NS.SettingItem(path) ~= nil end
for _, p in ipairs({ "record.enabled", "record.lateAt", "record.keepSessions", "record.resumeHours", "record.nightStart",
                     "bank.count", "rolls.seconds", "rolls.countdown", "rolls.channel", "rolls.altClick",
                     "softres.tooltip", "softres.lootMark", "softres.warnDays", "tools.collect", "tools.scanRate" }) do
    assert(has(p), "registered: " .. p)
end

-- the commands are registered words now, with help text
local help = table.concat(NS.SlashHelpLines(true), "\n")
for _, w in ipairs({ "pause", "status", "spaet", "export", "award", "unaward", "roll", "rollzeit", "rolls", "sr",
                     "scan", "sammeln", "minimap", "namen", "hilfe" }) do
    assert(help:find("/amisia " .. w, 1, true), "help lists " .. w)
end

-- pause through the setting
assert(NS.IsEnabled())
SlashCmdList.AMISIA("pause"); assert(not NS.IsEnabled() and NS.Get("record.enabled") == false)
SlashCmdList.AMISIA("pause"); assert(NS.IsEnabled())

-- late time through the setting
SlashCmdList.AMISIA("spaet 19:45"); assert(NS.Get("record.lateAt") == 19 * 60 + 45 and NS.LateTime() == "19:45")
SlashCmdList.AMISIA("spaet aus"); assert(NS.Get("record.lateAt") == false and NS.LateTime() == nil)
NS.Reset("record.lateAt")

-- roll time through the setting
SlashCmdList.AMISIA("rollzeit 45"); assert(NS.Get("rolls.seconds") == 45)
NS.Reset("rolls.seconds")

-- countdown off: no "10 Sekunden." announcement
STUB.roster = { { name = "Vuloo", class = "PRIEST" } }
NS.Set("rolls.countdown", false)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.StartRoll(link, 12))
STUB.chat = {}
STUB.tick(3)
for _, c in ipairs(STUB.chat) do assert(not c.text:find("Sekunden.", 1, true), c.text) end
NS.StopRoll()
NS.Reset("rolls.countdown")

-- announce channel: raid instead of raid warning
STUB.leader = true
NS.Set("rolls.channel", "RAID")
STUB.chat = {}
NS.Announce("x")
assert(STUB.chat[1].chan == "RAID")
NS.Reset("rolls.channel")
STUB.chat = {}
NS.Announce("y")
assert(STUB.chat[1].chan == "RAID_WARNING")

-- keep sessions
assert(NS.Get("record.keepSessions") == 60)
