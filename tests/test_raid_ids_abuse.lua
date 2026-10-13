-- Raid IDs against abuse (Raid/RaidIDs.lua, F-099, D-46, review 2026-10-13): another spelling of a
-- character (case, a first name alone) is the roster's character, so a sender cannot put a second
-- record beside the character's own report (D-12) or slip past its keyed gap; a sender reports 12
-- characters at most, also when it takes over records other senders made.
local DAY = 86400

STUB.guild = { { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 }, { name = "Bob Eisherz", rank = 3, class = "WARRIOR", level = 60 },
               { name = "Kai Wind", rank = 4, class = "HUNTER", level = 60 }, { name = "Mia Stern", rank = 4, class = "MAGE", level = 60 } }
local letters = "ABCDEFGHIJKLMNOPQRSTUVWX"
for i = 1, 24 do STUB.guild[#STUB.guild + 1] = { name = "Twink " .. letters:sub(i, i) .. "bc", rank = 4, class = "ROGUE", level = 60 } end
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.player, STUB.class, STUB.level = "Vulo Hunt", "HUNTER", 60
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
NS.Set("ui.view", "officer")
assert(NS.RaidCheckAllowed())

local T = math.floor(STUB.now)
local id = ("409:9:%d:2/10"):format(T + 2 * DAY)
local function iv(char, ids) return { char, "WARRIOR", "60", ids or "-" } end
local function count()
    local n = 0
    for _ in pairs(AmisiaDB.raidcheck.heard) do n = n + 1 end
    return n
end

-- 1. Bob's own report: free. Kai's forged one in lower case must not stand beside it
assert(NS.RaidIDsTake("Bob Eisherz", iv("Bob Eisherz", "-")) == true)
assert(NS.RaidIDsTake("Kai Wind", iv("bob eisherz", id)) == false, "another spelling is still Bob: his own word stays")
assert(NS.RaidIDsTake("Kai Wind", iv("Bob", id)) == false, "a first name alone too")
assert(count() == 1, "one record per character: " .. count())
assert(AmisiaDB.raidcheck.heard["Bob Eisherz"] and AmisiaDB.raidcheck.heard["bob eisherz"] == nil)
for _ = 1, 20 do assert(NS.RaidIDOf("Bob Eisherz", 409) == "free", "Bob stays free") end

-- 2. a report of another character is kept under the roster's spelling
assert(NS.RaidIDsTake("Kai Wind", iv("mia stern", id)) == true)
assert(AmisiaDB.raidcheck.heard["Mia Stern"] and AmisiaDB.raidcheck.heard["mia stern"] == nil, "the roster's spelling")

-- 3. 12 per sender, also over records other senders made
for i = 1, 11 do assert(NS.RaidIDsTake("Bob Eisherz", iv("Twink " .. letters:sub(i, i) .. "bc")) == true) end
local taken = 0
for i = 12, 23 do
    if NS.RaidIDsTake("Kai Wind", iv("Twink " .. letters:sub(i, i) .. "bc")) then taken = taken + 1 end
end
assert(taken == 11, "Kai had Mia, eleven more: " .. taken)
local over = 0
for i = 1, 11 do
    if NS.RaidIDsTake("Kai Wind", iv("Twink " .. letters:sub(i, i) .. "bc", id)) then over = over + 1 end
end
assert(over == 0, "Kai cannot take over Bob's records past his 12: " .. over)
-- a sender's own records it may renew
assert(NS.RaidIDsTake("Kai Wind", iv("Mia Stern", "-")) == true, "renewing one of the own 12")

-- 4. a burst of reports (the answers to an IQ) tells the pages once
local fired = 0
NS.Listen("RAIDIDS", function() fired = fired + 1 end)
for i = 1, 11 do NS.RaidIDsTake("Bob Eisherz", iv("Twink " .. letters:sub(i, i) .. "bc", id)) end
STUB.tick(1)
assert(fired == 1, "one redraw for the burst: " .. fired)

-- 5. the view of a big guild: one lookup per name, not a pass over every record per name
for i = 1, 400 do
    STUB.guild[#STUB.guild + 1] = { name = ("Gast %s%s%s"):format(string.char(65 + i % 26), string.char(97 + math.floor(i / 26) % 26), "x"), rank = 5, class = "MAGE", level = 60 }
end
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
for i = 1, 250 do
    AmisiaDB.raidcheck.heard[("Gast %s%s%s"):format(string.char(65 + i % 26), string.char(97 + math.floor(i / 26) % 26), "x")] =
        { by = "Kai Wind", at = T, ids = {} }
end
local calls, same = 0, NS.SameName
NS.SameName = function(a, b) calls = calls + 1 return same(a, b) end
local rows = NS.RaidIDsRows(409)
NS.SameName = same
assert(#rows >= 400, "every name: " .. #rows)
assert(calls < 5000, "SameName calls for the view: " .. calls)
