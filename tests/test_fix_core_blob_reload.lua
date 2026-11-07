--[[clients Vulo_Sturmwind Fraktur]]
-- A blob sent soon after a /reload is taken: the receiver keeps finished sets (art:key:seq) for a
-- minute, so the sender's counter must not start at 1 again on every load (audit 2026-11-07).
local VULO, FRAK = "Vulo Sturmwind", "Fraktur"
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 } })
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('GUILD_ROSTER_UPDATE')") end
C(FRAK, [[_G.GOT = 0
    NS.CommOnBlob("DK", function(sender, tbl) if type(tbl) == "table" and tbl.probe then GOT = GOT + 1 end end)]])
local function send() return C(VULO, [[return (NS.CommSendBlob("DK", "2026-11-01:2834", { probe = 1 }, "WHISPER", "Fraktur"))]]) end
BUS.tick(5)
assert(send() == true)
BUS.tick(10)
assert(C(FRAK, "GOT") == 1, "the first blob arrived")
BUS.reload(VULO)
C(VULO, "STUB.fire('GUILD_ROSTER_UPDATE')")
BUS.tick(5)
assert(send() == true)
BUS.tick(10)
assert(C(FRAK, "GOT") == 2, "the first blob after the reload arrived")
