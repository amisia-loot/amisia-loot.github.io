--[[clients Vulo_Sturmwind Anna_Bergmann Kai_Fremder]]
-- Sharing a route between two Amisia clients (F-167, D-97): Vulo draws a route with stops and lines,
-- shares it with his party (PARTY, RO and its RD pieces through the throttled queue), Anna gets one chat
-- line and an offer, nothing on her map until she accepts; the route arrives whole (labels, lines);
-- Kai outside the party gets nothing; a raid uses RAID; a point goes as a chat line and an RX.
BUS.setRaid({ "Vulo Sturmwind", "Anna Bergmann" })
for _, name in ipairs({ "Vulo Sturmwind", "Anna Bergmann" }) do
    C(name, [[STUB.party = true
        STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
        STUB.maps[1426] = { name = "Dun Morogh", mapType = 3 }
        STUB.fire("GROUP_ROSTER_UPDATE")]])
end
C("Kai Fremder", [[STUB.maps[1426] = { name = "Dun Morogh", mapType = 3 }]])

-- Vulo: 12 stops with labels and 6 long lines, more than one piece
C("Vulo Sturmwind", [[local R = NS.Routes
    for i = 1, 12 do R.AddStop(1426, i / 20, 0.5); R.SetLabel(i, "Halt Nr. " .. i) end
    for k = 1, 6 do
        R.StartLine(1426, 0.05, k / 10)
        for p = 1, 59 do R.LineTo(0.05 + p * 0.015, k / 10 + (p % 2) * 0.01) end
        R.EndLine()
    end
    R.SetName("Durch Dun Morogh")]])
local ok, parts = C("Vulo Sturmwind", "return NS.Routes.Share()")
assert(ok == true and parts > 1, "shared in several pieces: " .. tostring(parts))
-- a second share within 30 s is refused at the sender
local ok2, why = C("Vulo Sturmwind", "return NS.Routes.Share()")
assert(not ok2 and why:find("Eine Route alle 30 Sekunden", 1, true), tostring(why))
BUS.tick(40)
assert(BUS.count({ kind = "RO", chan = "PARTY", sender = "Vulo Sturmwind" }) == 1, "one head to the party")
assert(BUS.count({ kind = "RD", chan = "PARTY", sender = "Vulo Sturmwind" }) == parts, "every piece")
assert(BUS.count({ kind = "RD", chan = "RAID" }) == 0, "not to RAID in a party")

-- Anna: one line, one offer, nothing on the map yet
assert(C("Anna Bergmann", "#NS.Routes.Offers()") == 1)
local line = C("Anna Bergmann", "STUB.messages[#STUB.messages]")
assert(line:find('Vulo Sturmwind teilt die Route "Durch Dun Morogh" (12 Stopps, 6 Linien, Dun Morogh). /amisia route annehmen', 1, true), line)
assert(C("Anna Bergmann", "NS.Routes.Current() == nil and not NS.Routes.Mode()"), "nothing shown by itself")
assert(C("Kai Fremder", "#NS.Routes.Offers()") == 0, "outside the party nothing")

-- accepted: the route whole
C("Anna Bergmann", "NS.Dispatch('route annehmen')")
assert(C("Anna Bergmann", "#NS.Routes.Current().stops") == 12 and C("Anna Bergmann", "#NS.Routes.Current().lines") == 6)
assert(C("Anna Bergmann", "NS.Routes.Current().stops[12].l") == "Halt Nr. 12")
assert(C("Anna Bergmann", "#NS.Routes.Current().lines[1]") == 120, "every point of a line")
local dx = C("Anna Bergmann", "return math.abs(NS.Routes.Current().stops[7].x - 0.35)")
assert(dx < 0.001, "where it was: " .. dx)
assert(C("Anna Bergmann", "NS.Routes.Current().by") == "Vulo Sturmwind" and C("Anna Bergmann", "NS.Routes.Mode()"))
-- she saves it as her own
assert(C("Anna Bergmann", "return NS.Routes.Save()") == true)
assert(C("Anna Bergmann", "AmisiaDB.routes.list[1].n") == "Durch Dun Morogh")

-- a point: a chat line for everyone, an RX for Amisia, taken as the target by command
assert(C("Vulo Sturmwind", "return NS.Routes.SharePoint({ map = 1426, x = 0.452, y = 0.631 }, 'Treffpunkt')") == true)
BUS.tick(2)
assert(BUS.count({ kind = "RX", chan = "PARTY", sender = "Vulo Sturmwind" }) == 1)
assert(C("Vulo Sturmwind", "STUB.chat[#STUB.chat].text") == "Amisia-Punkt: Dun Morogh 45.2, 63.1 (Treffpunkt)")
C("Anna Bergmann", "NS.Dispatch('route punkt')")
assert(C("Anna Bergmann", "NS.MapTarget().label") == "Treffpunkt" and C("Anna Bergmann", "NS.MapTarget().x") == 0.452)

-- in a raid the route goes to RAID
for _, name in ipairs({ "Vulo Sturmwind", "Anna Bergmann" }) do C(name, "STUB.party = nil; STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.tick(31)
assert(C("Vulo Sturmwind", "return NS.Routes.Share()") == true)
BUS.tick(40)
assert(BUS.count({ kind = "RO", chan = "RAID", sender = "Vulo Sturmwind" }) == 1, "a raid: RAID")
assert(C("Anna Bergmann", "#NS.Routes.Offers()") == 1)
