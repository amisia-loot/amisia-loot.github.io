--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- Review of rounds started with Gargul (RollWatch.lua, D-44) and the English announcement (B4):
-- a raider's start or stop line never waits in the queue of senders checked against the guild
-- roster (it is shared with WS and the other messages); a hand roll in a finished watched round does
-- not ask for an announcement that cannot happen; the English line never cuts reservers off.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local LINK = "|cffa335ee|Hitem:32235::::::::70:::::|h[Cursed Vision of Sargeras]|h|r"

local function chat(event, text, sender)
    for _, name in ipairs(CLIENTS) do
        C(name, ("STUB.fire(%q, %q, %q)"):format(event, text, sender))
    end
end

BUS.setRaid({ VULO, FRAK, KIM, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
        if STUB.player == "Pug" then STUB.inGuild = false end
        RandomRoll = function() end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.IsLootLead()") == true)

---------------------------------------------------------------------------
-- lines of senders who are not the master looter never reach the roster check
---------------------------------------------------------------------------
-- counted: the checks of the senders of these chat lines (other messages may be checked meanwhile)
C(KIM, "WAITS = {}; local real = NS.TrustWait; NS.TrustWait = function(n, ...) WAITS[n] = (WAITS[n] or 0) + 1 return real(n, ...) end")
chat("CHAT_MSG_RAID", "Stop your rolls!", PUG)
chat("CHAT_MSG_RAID", "Stop your rolls!", FRAK)
chat("CHAT_MSG_RAID", "You have 20 seconds to roll on " .. LINK, PUG)
BUS.tick(0.5)
assert(C(KIM, "return (WAITS.Pug or 0) + (WAITS.Fraktur or 0)") == 0, "raiders' lines wait for nothing")
chat("CHAT_MSG_RAID_WARNING", "You have 20 seconds to roll on " .. LINK, VULO)
BUS.tick(0.5)
assert(C(KIM, "return WAITS['Vulo Sturmwind'] or 0") >= 1, "the master looter's start is checked")
assert(C(KIM, "return AmisiaRollWindow ~= nil and AmisiaRollWindow:IsShown()") == true, "and opens the window")

---------------------------------------------------------------------------
-- a hand roll in the finished watched round: decided again, never "not announced yet"
---------------------------------------------------------------------------
chat("CHAT_MSG_RAID_WARNING", "Stop your rolls!", VULO)
BUS.tick(0.5)
assert(C(VULO, "return NS.CurrentRoll().done and NS.CurrentRoll().foreign") == VULO)
C(VULO, "STUB.messages = {}")
C(VULO, "NS.Dispatch('wurf Kim Eisherz 88')")
assert(C(VULO, "return NS.CurrentRoll().winner") == KIM, "the hand roll counts")
assert(C(VULO, "return NS.CurrentRoll().dirty") == nil, "a watched round is never dirty")
assert(C(VULO, "for _, m in ipairs(STUB.messages) do if m:find('Ergebnis ansagen', 1, true) then return true end end return false") == false,
    "no hint at a button that cannot announce")
C(VULO, "STUB.messages = {}")
C(VULO, ("NS.StartRoll(%q, 20)"):format(LINK))
assert(C(VULO, "for _, m in ipairs(STUB.messages) do if m:find('nicht angesagt', 1, true) then return true end end return false") == false,
    "the next round does not warn about the watched one")
C(VULO, "NS.StopRoll()")
BUS.tick(6)

---------------------------------------------------------------------------
-- B4: many reservers, every one of them in the English lines (255 bytes a line)
---------------------------------------------------------------------------
local names = { "Annabella", "Bernadette", "Christiane", "Dorothea", "Elisabeth", "Franziska", "Gwendolyn",
                "Henriette", "Isabella", "Josephine", "Katharina", "Leopoldine" }
local lines = {}
for _, n in ipairs(names) do lines[#lines + 1] = n .. " 32235" end
C(VULO, ("NS.Set('rolls.announceEnglish', true); NS.SetSoftRes(%q); STUB.chat = {}"):format(table.concat(lines, "\n")))
C(VULO, ("NS.StartRoll(%q, 20)"):format(LINK))
BUS.tick(3)
local english = C(VULO, [[local out = {}
    local on = false
    for _, m in ipairs(STUB.chat) do
        if m.text:find("^Roll on ") then on = true end
        if on and not m.text:find("^Roll auf ") and not m.text:find("^Reserviert von ") then out[#out + 1] = m.text end
    end
    return out]])
local all = table.concat(english, "\n")
assert(#english >= 2, "the reservers go on to a second line: " .. all)
for _, line in ipairs(english) do assert(#line <= 255, "a chat line holds 255 bytes: " .. #line) end
for _, n in ipairs(names) do assert(all:find(n, 1, true), n .. " is missing: " .. all) end
assert(all:find("%.$"), "the last line ends with a full stop")
C(VULO, "NS.StopRoll()")
