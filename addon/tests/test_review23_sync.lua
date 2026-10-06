--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Review of the 2.3 drop exchange (DropSync.lua): a request takes exactly its one answer (records
-- the request named as known are dropped, an answer may not bring more records than the sender
-- counted, a second blob is unasked); DQ spam of one member uses at most its share of the session
-- bytes and a few answers, and another member is still served; items differing on the same kill
-- converge.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 3 } })
local function setup(name)
    C(name, [[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }; STUB.combat = false; STUB.fire("GUILD_ROSTER_UPDATE")]])
end
for _, n in ipairs(CLIENTS) do setup(n) end
local function kills(name) return C(name, "NS.DropsStatus().kills") end
local function stat(name, f) return C(name, ("NS.DropSyncStats().%s"):format(f)) end

---------------------------------------------------------------------------
-- 2. one request, one answer; nothing beyond what the sender counted; known records dropped
---------------------------------------------------------------------------
C(VULO, [[NS.DropsMerge({ h = "aaaaaaaa", npc = 213450, inst = 2834, diff = 1, day = NS.DropsToday(), o = AmisiaDB.drops.me, src = "G", it = { [219004] = 1 } })
    AmisiaDB.drops.k.aaaaaaaa.mine = true]])
C(FRAK, [[NS.DropsMerge({ h = "bbbbbbbb", npc = 213450, inst = 2834, diff = 1, day = NS.DropsToday(), o = AmisiaDB.drops.me, src = "G", it = {} })]])
C(FRAK, "STUB.fire('PLAYER_LOGIN')")
-- Fraktur's honest answer is lost
BUS.drop(function(m) return m.sender == FRAK and m.prefix == "AmisiaD" end)
local key
for _ = 1, 400 do
    BUS.tick(1)
    for _, m in ipairs(BUS.sent) do if m.kind == "DR" and m.sender == VULO then key = m.text:match("^1DR\t([^\t]+)\t") end end
    if key then break end
end
assert(key, "Vulo asked Fraktur for the bucket")
BUS.tick(40)
assert(BUS.count(function(m) return m.sender == FRAK and m.dropped end) >= 1, "the honest answer went and was lost")
BUS.drop(nil)
local VME = C(VULO, "AmisiaDB.drops.me")
local function forge(rows)
    C(FRAK, ("assert(NS.CommSendBlob('DK', %q, { v = 1, r = { %s } }, 'WHISPER', %q, {}))"):format(key, rows, VULO))
    BUS.tick(15)
end
local today = C(VULO, "NS.DropsToday()")
-- twenty kills in a bucket where Fraktur counted one: refused whole
local rows = {}
for i = 1, 20 do rows[i] = ("{ 'f%07x', 213450, 2834, 1, %d, '00000000', 0, { 219999, 1 }, 'G' }"):format(i, today) end
local bad0 = stat(VULO, "bad")
forge(table.concat(rows, ", "))
assert(stat(VULO, "bad") == bad0 + 1 and kills(VULO) == 1, "more records than the sender counted: " .. kills(VULO))
-- the record Vulo named as known, with the same items: the answer, and nothing taken from it
local listed0 = stat(VULO, "listed")
forge(("{ 'aaaaaaaa', 213450, 2834, 1, %d, '00000000', 0, { 219004, 1 }, 'G' }"):format(today))
assert(stat(VULO, "listed") == listed0 + 1, "a known record is dropped")
assert(C(VULO, "AmisiaDB.drops.k.aaaaaaaa.o") == VME, "the own origin stays")
-- the request is answered: a further blob for it is unasked
local unasked0 = stat(VULO, "unasked")
forge(("{ 'aaaaaaaa', 213450, 2834, 1, %d, '00000000', 0, { 219004, 20, 219005, 20 }, 'G' }"):format(today))
forge(("{ 'cccccccc', 213450, 2834, 1, %d, '00000000', 0, { 219999, 1 }, 'G' }"):format(today))
assert(stat(VULO, "unasked") == unasked0 + 2, "one request, one answer")
assert(kills(VULO) == 1 and C(VULO, "AmisiaDB.drops.k.aaaaaaaa.it[219005]") == nil, "nothing pushed after the answer")

---------------------------------------------------------------------------
-- 3. DQ spam: a few answers within the spammer's share; another member is still served
---------------------------------------------------------------------------
for _, n in ipairs(CLIENTS) do BUS.reload(n); setup(n); C(n, "AmisiaDB.drops.k = {}; NS.DropsPrune()") end
C(VULO, [[local today = NS.DropsToday()
    local i = 0
    for day = 0, 6 do for inst = 1, 12 do
        i = i + 1
        NS.DropsMerge({ h = ("%08x"):format(i), npc = 1000 + inst, inst = 2000 + inst, diff = 1, day = today - day, o = AmisiaDB.drops.me, src = "G", it = {} })
    end end]])
local t0 = C(VULO, "STUB.clock")
for _ = 1, 120 do
    C(FRAK, [[for i = 1, 3 do NS.CommSend("DQ", { "0" }, "WHISPER", "Vulo Sturmwind") end]])
    BUS.tick(1)
end
local di = BUS.count({ kind = "DI", sender = VULO, from = t0 })
assert(di <= 3 * 7, "one answer per week per minute: " .. di)
assert(C(VULO, "NS.DropSyncAskerBytes('Fraktur')") <= 61440 / 3, "within the asker's share")
assert(C(VULO, "NS.DropSyncStats().bytes") < 61440 / 3, "the spam used little of the session: " .. C(VULO, "NS.DropSyncStats().bytes"))
C(KIM, "STUB.fire('PLAYER_LOGIN')")
C(VULO, "STUB.fire('PLAYER_LOGIN')")
BUS.tick(1800)
assert(kills(KIM) == 84, "the other member got everything: " .. kills(KIM))
assert(C(VULO, "NS.DropSyncStats().bytes") <= 61440)

---------------------------------------------------------------------------
-- 7. the same kill with other items: the items converge
---------------------------------------------------------------------------
for _, n in ipairs(CLIENTS) do BUS.reload(n); setup(n); C(n, "AmisiaDB.drops.k = {}; NS.DropsPrune()") end
C(VULO, [[NS.DropsMerge({ h = "dddddddd", npc = 213450, inst = 2834, diff = 1, day = NS.DropsToday() - 1, o = AmisiaDB.drops.me, src = "G", it = { [219004] = 1, [219005] = 1 } })]])
C(FRAK, [[NS.DropsMerge({ h = "dddddddd", npc = 213450, inst = 2834, diff = 1, day = NS.DropsToday() - 1, o = AmisiaDB.drops.me, src = "G", it = {} })]])
C(VULO, "STUB.fire('PLAYER_LOGIN')"); C(FRAK, "STUB.fire('PLAYER_LOGIN')")
BUS.tick(1200)
assert(C(FRAK, "AmisiaDB.drops.k.dddddddd.it[219004]") == 1 and C(FRAK, "AmisiaDB.drops.k.dddddddd.it[219005]") == 1,
    "Fraktur has the items Vulo saw")
assert(C(FRAK, "NS.DropRateText(213450, 219004)") == C(VULO, "NS.DropRateText(213450, 219004)"))
