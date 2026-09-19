-- Awards in the session model, the A export line and the announcement channel.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.ItemID(link) == 32235)
assert(NS.ItemID("item:32235") == 32235 and NS.ItemID(nil) == nil)
local a = NS.AddAward("Fraktur", 32235, "MS", "Illidan Stormrage")
assert(a and s.awards[1] == a and a.kind == "MS" and a.src == "Illidan Stormrage")
assert(s.members.Fraktur, "award recipient counted as present")
local txt = NS.ExportText({ s })
assert(txt:find("\nA Fraktur 32235 " .. a.t .. " MS Illidan Stormrage\n", 1, true), txt)
assert(txt:find("\nN 32235 4 Cursed Vision of Sargeras\n", 1, true), "awarded item named")
assert(NS.RemoveLastAward() == a and #s.awards == 0)
assert(NS.AddAward("Fraktur", 32235, "MS", "?") and s.awards[1].src == "?")
assert(NS.AddAward("Fraktur", "32235", "bogus") and s.awards[2].kind == "-" and s.awards[2].item == 32235)
assert(NS.AwardCount(s) == 2)
-- no session: refused
NS.SetEnabled(false)
local ok, why = NS.AddAward("Fraktur", 32235, "-", "?")
assert(ok == nil and why, "refused without session")
NS.SetEnabled(true)
-- announce channel
NS.Announce("hi"); assert(STUB.chat[1].chan == "RAID_WARNING")
STUB.leader = false; NS.Announce("hi"); assert(STUB.chat[2].chan == "RAID")
STUB.roster = {}; NS.Announce("hi"); assert(#STUB.chat == 2, "no announce when alone")
-- extra event handlers registered by modules
local got
NS.OnEvent("CHAT_MSG_SYSTEM", function(text) got = text end)
STUB.fire("CHAT_MSG_SYSTEM", "hello")
assert(got == "hello", "module handler called")
-- exported matcher builder handles %d
local m = NS.BuildMatcher("%s rolls %d (%d-%d)")
local r = m("Fraktur rolls 57 (1-100)")
assert(r and r[1] == "Fraktur" and r[2] == "57" and r[4] == "100")
