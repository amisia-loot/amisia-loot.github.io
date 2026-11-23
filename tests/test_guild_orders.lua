-- Guild orders (F-231, D-164, Gear/GuildOrders.lua): placing an own order (every bound, the cap of 5, the note
-- cleaned, OA to the guild, the guild chat line only from the click), withdrawing and receiving it (X); the OA a
-- member sends (every field's bound drops the whole message, only members, only the sender's own orders, a
-- revision not newer only "seen", 5 open per sender, 100 in all, a recipe the data lacks dropped); a crafter's
-- step (OT only by whisper, only for an own open order, the first T wins, the second gets the state back, R and D
-- only from that crafter, D only after T); the requester's chat lines; the crafter's line once per order and 6 an
-- hour; offline greys the step; OQ answered by whisper; instance, lockdown and setting; 14 days; the load check.
local GO = NS.GuildOrders
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.guild = { { name = "Vulo Sturmwind", rank = 1, online = true }, { name = "Anna Amboss", rank = 3, online = true, class = "MAGE" },
    { name = "Bob Hammer", rank = 3, online = true }, { name = "Cleo Kessel", rank = 3, online = false } }
for i = 1, 9 do STUB.guild[#STUB.guild + 1] = { name = "Member " .. string.char(96 + i), rank = 4, online = true } end
STUB.fire("GUILD_ROSTER_UPDATE")
local D = NS.DropsToday()
-- the own character knows the healing potion (2330, item 118) and the copper vest (3321, item 3471)
AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [171] = { rank = 300, max = 300, day = D, known = { [2330] = true } },
    [164] = { rank = 100, max = 150, day = D, known = { [3321] = true } } } } }

local function sent(kind, chan)
    local out = {}
    for _, m in ipairs(STUB.addon) do
        if m.text:sub(1, 3) == "1" .. kind and (not chan or m.chan == chan) then
            local f = {}
            for x in (m.text:sub(5) .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = x end
            out[#out + 1] = { f = f, chan = m.chan, target = m.target }
        end
    end
    return out
end
local function msgs() return table.concat(STUB.messages, "\n") end
local function recv(kind, sender, chan, ...)
    STUB.tick(4)   -- the keyed gaps per order
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1" .. kind .. "\t" .. table.concat({ ... }, "\t"), chan, sender, "", 0, 0, "", 0)
    STUB.tick(0.1)
end
local function heard(sender, id)
    local o = AmisiaDB.orders
    return o and o.heard[sender] and o.heard[sender][id]
end

---------------------------------------------------------------------------
-- placing an own order: the bounds, the cap, OA to the guild
---------------------------------------------------------------------------
local ok, why = GO.Create(2330, 0, "B")
assert(not ok and has(why, "Anzahl 1 bis 20"), why)
ok, why = GO.Create(2330, 21, "B")
assert(not ok and has(why, "Anzahl"), why)
ok, why = GO.Create(2330, 1.5, "B")
assert(not ok, "a whole count")
ok, why = GO.Create(2330, 2, "Z")
assert(not ok and has(why, "Material"), why)
ok, why = GO.Create(4242, 1, "B")
assert(not ok and has(why, "Kein Rezept"), "a recipe of the profession data")
STUB.addon, STUB.chat = {}, {}
local long = "zahle |cffff0000rot|r 5g " .. string.rep("ä", 40)
local id = GO.Create(2330, 4, "H", long, false)
assert(id and #id == 4, "the order")
local own = AmisiaDB.orders.own[id]
assert(own.rev == 1 and own.spell == 2330 and own.item == 118 and own.n == 4 and own.mats == "H" and own.state == "O")
assert(#own.note <= 60 and not own.note:find("|", 1, true) and has(own.note, "zahle rot 5g"), own.note)
assert(#STUB.chat == 0, "no guild chat line without the switch")
STUB.tick(1.1)
local oa = sent("OA", "GUILD")
assert(#oa == 1, "the OA: " .. #oa)
local f = oa[1].f
assert(f[1] == id and f[2] == "1" and f[3] == "2330" and f[4] == "4" and f[5] == "H" and f[6] == "O" and f[7] == "-"
    and tonumber(f[8]) <= 2 and f[9] == own.note and f[10] == "118", table.concat(f, "|"))
assert(#GO.Mine() == 1 and GO.StateText(GO.Mine()[1]) == "offen")
-- the guild chat line only from the click's switch
local id2 = GO.Create(3321, 1, "B", nil, true)
assert(#STUB.chat == 1 and STUB.chat[1].chan == "GUILD" and has(STUB.chat[1].text, "Suche Hersteller: 1x "), STUB.chat[1] and STUB.chat[1].text)
for i = 3, 5 do assert(GO.Create(2330, i, "A")) end
ok, why = GO.Create(2330, 1, "A")
assert(not ok and has(why, "schon 5 offene"), "5 open at most: " .. tostring(why))
-- withdrawn: X to the guild, the slot free again
STUB.addon = {}
assert(GO.Withdraw(id2))
STUB.tick(2.2)
local x
for _, m in ipairs(sent("OA", "GUILD")) do if m.f[1] == id2 then x = m.f end end
assert(x and x[6] == "X" and x[2] == "2", "X with a new revision")
assert(#GO.Mine() == 4 and GO.OpenCount() == 4)
assert(GO.Create(2330, 1, "A"), "a slot again")

---------------------------------------------------------------------------
-- a crafter's step: OT only by whisper, only an own open order, the first T wins
---------------------------------------------------------------------------
STUB.addon, STUB.messages = {}, {}
recv("OT", "Bob Hammer", "GUILD", id, "T")
assert(AmisiaDB.orders.own[id].state == "O", "OT only by whisper")
recv("OT", "Fremder Mann", "WHISPER", id, "T")
assert(AmisiaDB.orders.own[id].state == "O", "not from outside the guild")
recv("OT", "Bob Hammer", "WHISPER", "beef", "T")
assert(AmisiaDB.orders.own[id].state == "O", "another id")
recv("OT", "Bob Hammer", "WHISPER", id, "D")
assert(AmisiaDB.orders.own[id].state == "O", "D only after T")
recv("OT", "Bob Hammer", "WHISPER", id, "Q")
assert(AmisiaDB.orders.own[id].state == "O", "a bad step")
recv("OT", "Bob Hammer", "WHISPER", id, "T")
own = AmisiaDB.orders.own[id]
assert(own.state == "T" and own.by == "Bob Hammer" and own.rev == 2, "Bob took it")
assert(has(msgs(), "Bob Hammer hat deinen Gildenauftrag angenommen: 4x "), msgs())
assert(GO.StateText(GO.Mine()[1]) == "angenommen von Bob Hammer")
recv("OT", "Anna Amboss", "WHISPER", id, "T")
assert(own.by == "Bob Hammer" and own.rev == 2, "the first one wins")
STUB.tick(GO.LIM.answerJitter + 1.1)
local back = sent("OA", "WHISPER")
local toAnna = false
for _, m in ipairs(back) do if m.target == "Anna Amboss" and m.f[1] == id and m.f[6] == "T" and m.f[7] == "Bob Hammer" then toAnna = true end end
assert(toAnna, "the second gets the state back")
recv("OT", "Anna Amboss", "WHISPER", id, "D")
recv("OT", "Anna Amboss", "WHISPER", id, "R")
assert(own.state == "T" and own.by == "Bob Hammer", "R and D only from the crafter")
recv("OT", "Bob Hammer", "WHISPER", id, "D")
assert(own.state == "D" and has(msgs(), "Bob Hammer: 4x "), "done")
assert(GO.StateText(GO.Mine()[1]) == "fertig: Bob Hammer")
recv("OT", "Bob Hammer", "WHISPER", id, "R")
assert(own.state == "O" and own.by == nil, "given back: open again")
recv("OT", "Bob Hammer", "WHISPER", id, "T")
recv("OT", "Bob Hammer", "WHISPER", id, "D")
assert(GO.Received(id) and own.state == "X", "received: closed")
assert(GO.Received(id) == nil, "once")
recv("OT", "Anna Amboss", "WHISPER", id, "T")
assert(own.state == "X", "a closed order takes no step")

---------------------------------------------------------------------------
-- others' orders: every bound of OA, members only, only the sender's own
---------------------------------------------------------------------------
STUB.messages = {}
recv("OA", "Anna Amboss", "GUILD", "a001", "1", "2330", "3", "B", "O", "-", "7200", "zahle 5g", "118")
local a = heard("Anna Amboss", "a001")
assert(a and a.n == 3 and a.mats == "B" and a.state == "O" and a.note == "zahle 5g" and a.item == 118 and a.at == math.floor(time()) - 7200)
assert(has(msgs(), "Gildenauftrag von ") and has(msgs(), "Anna Amboss") and has(msgs(), "3x ") and has(msgs(), "/amisia auftraege"),
    "the crafter's chat line: " .. msgs())
local function bad(what, ...)
    recv("OA", "Bob Hammer", "GUILD", ...)
    assert(heard("Bob Hammer", (...)) == nil, what)
end
bad("id not 4 hex", "b0g1", "1", "2330", "1", "B", "O", "-", "0", "-")
bad("id 5 hex", "b0011", "1", "2330", "1", "B", "O", "-", "0", "-")
bad("rev 0", "b002", "0", "2330", "1", "B", "O", "-", "0", "-")
bad("rev 1000000", "b003", "1000000", "2330", "1", "B", "O", "-", "0", "-")
bad("spell 0", "b004", "1", "0", "1", "B", "O", "-", "0", "-")
bad("count 0", "b005", "1", "2330", "0", "B", "O", "-", "0", "-")
bad("count 21", "b006", "1", "2330", "21", "B", "O", "-", "0", "-")
bad("material", "b007", "1", "2330", "1", "Z", "O", "-", "0", "-")
bad("state", "b008", "1", "2330", "1", "B", "Q", "-", "0", "-")
bad("O with a crafter", "b009", "1", "2330", "1", "B", "O", "Anna Amboss", "0", "-")
bad("T without one", "b00a", "1", "2330", "1", "B", "T", "-", "0", "-")
bad("a crafter with a digit", "b00b", "1", "2330", "1", "B", "T", "Anna2", "0", "-")
bad("age", "b00c", "1", "2330", "1", "B", "O", "-", "-5", "-")
bad("age too big", "b00d", "1", "2330", "1", "B", "O", "-", "100000000", "-")
bad("note 61 bytes", "b00e", "1", "2330", "1", "B", "O", "-", "0", string.rep("x", 61))
bad("note with a control character", "b00f", "1", "2330", "1", "B", "O", "-", "0", "a\1b")
bad("item", "b010", "1", "2330", "1", "B", "O", "-", "0", "-", "x")
bad("too few fields", "b011", "1", "2330", "1", "B", "O", "-", "0")
bad("a recipe the data lacks", "b012", "1", "4242", "1", "B", "O", "-", "0", "-")
-- the edges: 20, 60 bytes, age 99999999, without the item
recv("OA", "Bob Hammer", "GUILD", "b013", "999999", "3321", "20", "A", "T", "Anna Amboss", "99999999", string.rep("y", 60))
local b = heard("Bob Hammer", "b013")
assert(b and b.n == 20 and b.by == "Anna Amboss" and b.item == nil and #b.note == 60, "the edges")
-- not from outside the guild, not as another sender's order
recv("OA", "Fremder Mann", "GUILD", "c001", "1", "2330", "1", "B", "O", "-", "0", "-")
assert(heard("Fremder Mann", "c001") == nil, "an outsider")
recv("OA", "Bob Hammer", "GUILD", "a001", "5", "2330", "9", "B", "X", "-", "0", "-")
assert(heard("Anna Amboss", "a001") and heard("Anna Amboss", "a001").n == 3, "Bob cannot close Anna's order")
assert(heard("Bob Hammer", "a001") == nil, "an X of an order not heard keeps nothing")
-- a revision not newer is only seen; a newer one changes it
STUB.tick(100)
recv("OA", "Anna Amboss", "GUILD", "a001", "1", "2330", "9", "B", "O", "-", "7300", "-")
a = heard("Anna Amboss", "a001")
assert(a.n == 3 and a.seen == math.floor(time()), "the same revision: seen")
recv("OA", "Anna Amboss", "WHISPER", "a001", "2", "2330", "9", "H", "O", "-", "7300", "-")
assert(a.n == 9 and a.mats == "H" and a.note == nil, "a newer revision, also by whisper")
-- 5 open per sender
for i = 2, 6 do recv("OA", "Anna Amboss", "GUILD", "a00" .. i, "1", "2330", "1", "B", "O", "-", "0", "-") end
assert(heard("Anna Amboss", "a005") and heard("Anna Amboss", "a006") == nil, "5 open per requester")
-- X closes
recv("OA", "Anna Amboss", "GUILD", "a005", "2", "2330", "1", "B", "X", "-", "0", "-")
assert(heard("Anna Amboss", "a005") == nil, "closed")
-- the views: Anna's orders "für mich" (the own character knows 2330), Bob's taken one under the others
local forMe, rest = GO.Others()
assert(#forMe == 4 and #rest == 1 and rest[1].sender == "Bob Hammer", #forMe .. "/" .. #rest)
assert(forMe[1].crafter == "Vulo Sturmwind" and forMe[1].online and forMe[1].class == "MAGE")
assert(GO.ForMeCount() == 4 and GO.TooltipLine() == "Gildenaufträge für dich: 4" and GO.LoginLine() == "4 Gildenaufträge kannst du herstellen.")

---------------------------------------------------------------------------
-- the crafter's chat line: once per order, 6 an hour
---------------------------------------------------------------------------
STUB.tick(3601)   -- the lines of the orders above leave the hour
STUB.messages = {}
local senders = { "Member a", "Member b", "Member c", "Member d", "Member e", "Member f", "Member g", "Member h" }
for _, s in ipairs(senders) do recv("OA", s, "GUILD", "d001", "1", "2330", "1", "B", "O", "-", "0", "-") end
local lines = 0
for _, m in ipairs(STUB.messages) do if has(m, "Gildenauftrag von") then lines = lines + 1 end end
assert(lines == 6, "6 an hour: " .. lines)
STUB.messages = {}
recv("OA", "Member a", "GUILD", "d001", "2", "2330", "2", "B", "O", "-", "0", "-")
assert(not has(msgs(), "Gildenauftrag von"), "a new revision says nothing")
recv("OA", "Member b", "GUILD", "d002", "1", "1234001", "1", "B", "O", "-", "0", "-")
assert(not has(msgs(), "Gildenauftrag von"), "a recipe no own character knows")
NS.Set("orders.chat", false)
recv("OA", "Member a", "GUILD", "d003", "1", "2330", "1", "B", "O", "-", "0", "-")
NS.Set("orders.chat", true)

---------------------------------------------------------------------------
-- 100 heard in all: the oldest heard falls
---------------------------------------------------------------------------
GO.LIM.heardMax = 12
recv("OA", "Member i", "GUILD", "e001", "1", "2330", "1", "B", "O", "-", "0", "-")
local total = 0
for _, orders in pairs(AmisiaDB.orders.heard) do for _ in pairs(orders) do total = total + 1 end end
assert(total == 12, "the cap: " .. total)
assert(heard("Bob Hammer", "b013") == nil, "Bob's, heard first, fell")
GO.LIM.heardMax = 100
-- Anna's fell too: heard again
recv("OA", "Anna Amboss", "GUILD", "a001", "1", "2330", "3", "B", "O", "-", "7200", "-")
recv("OA", "Anna Amboss", "GUILD", "a003", "1", "2330", "1", "B", "O", "-", "0", "-")
assert(heard("Anna Amboss", "a001") and heard("Anna Amboss", "a003"))

---------------------------------------------------------------------------
-- a step on another's order: offline greys it, only open, only a recipe an own character knows
---------------------------------------------------------------------------
STUB.addon = {}
recv("OA", "Cleo Kessel", "GUILD", "f001", "1", "2330", "1", "B", "O", "-", "0", "-")
ok, why = GO.Accept("Cleo Kessel", "f001")
assert(not ok and why == "Cleo Kessel ist offline.", why)
assert(GO.StepBlocked("Cleo Kessel") == "Cleo Kessel ist offline.")
recv("OA", "Member b", "GUILD", "f002", "1", "1234001", "1", "B", "O", "-", "0", "-")
ok, why = GO.Accept("Member b", "f002")
assert(not ok and has(why, "Keiner deiner Charaktere"), why)
ok = GO.Accept("Anna Amboss", "a001")
assert(ok and GO.Asked("Anna Amboss", "a001") == "T")
STUB.tick(1.1)
local ot = sent("OT")
assert(#ot == 1 and ot[1].chan == "WHISPER" and ot[1].target == "Anna Amboss" and ot[1].f[1] == "a001" and ot[1].f[2] == "T")
ok, why = GO.Done("Anna Amboss", "a001")
assert(not ok and has(why, "nicht bei dir"), "Fertig only once it is at the own character")
-- Anna's answer: taken by another; the line "schon angenommen"
STUB.messages = {}
recv("OA", "Anna Amboss", "GUILD", "a001", "3", "2330", "9", "H", "T", "Bob Hammer", "7300", "-")
assert(has(msgs(), "Schon angenommen von Bob Hammer"), msgs())
forMe, rest = GO.Others()
local found
for _, o in ipairs(rest) do if o.id == "a001" then found = o end end
assert(found and found.by == "Bob Hammer", "under the others now")
-- at the own character: Fertig, Abgeben
recv("OA", "Anna Amboss", "GUILD", "a002", "2", "2330", "1", "B", "T", "Vulo Sturmwind", "0", "-")
forMe = GO.Others()
found = nil
for _, o in ipairs(forMe) do if o.id == "a002" then found = o end end
assert(found and GO.IsMine(found.by), "the own one under für mich")
assert(GO.Done("Anna Amboss", "a002"))
STUB.tick(1.1)
assert(GO.GiveBack("Anna Amboss", "a002"))
STUB.tick(1.1)
assert(#sent("OT") == 2, "the next step waits 3 s per order")
STUB.tick(3)
ot = sent("OT")
assert(#ot == 3 and ot[2].f[2] == "D" and ot[3].f[2] == "R", "D and R, 3 s apart: " .. #ot)

---------------------------------------------------------------------------
-- OQ: answered by whisper with the own orders; inside an instance it waits
---------------------------------------------------------------------------
STUB.addon = {}
assert(GO.Create(3321, 2, "B"))
recv("OQ", "Anna Amboss", "WHISPER", "1234")
STUB.tick(12)
assert(#sent("OA", "WHISPER") == 0, "OQ only from the guild channel")
recv("OQ", "Fremder Mann", "GUILD", "1234")
STUB.tick(12)
assert(#sent("OA", "WHISPER") == 0, "not from outside the guild")
STUB.addon = {}
STUB.instance = { name = "Höhlen", type = "party", id = 1 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(301)   -- one OQ per sender in 300 s (the whisper above counted)
recv("OQ", "Anna Amboss", "GUILD", "1234")
STUB.tick(30)
assert(#sent("OA") == 0, "nothing inside an instance")
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(GO.LIM.outWait - 1)
assert(#sent("OA") == 0, "not at once after the way out")
STUB.tick(GO.LIM.outSpread + GO.LIM.answerJitter + 3)
local answers = sent("OA", "WHISPER")
assert(#answers >= 5 and answers[1].target == "Anna Amboss", "the answer after the way out: " .. #answers)
-- the lockdown: nothing goes, then it does
assert(GO.Withdraw(GO.Mine()[1].id))
STUB.tick(3)
STUB.addon = {}
STUB.chatLock = true
local id3 = GO.Create(3321, 3, "B")
assert(id3)
STUB.tick(5)
assert(#sent("OA") == 0, "nothing in the lockdown")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.tick(5)
oa = sent("OA", "GUILD")
assert(#oa == 1 and oa[1].f[1] == id3, "after the lockdown")
-- the setting off: nothing taken, nothing sent
NS.Set("orders.on", false)
recv("OA", "Member c", "GUILD", "g001", "1", "2330", "1", "B", "O", "-", "0", "-")
assert(heard("Member c", "g001") == nil, "off: nothing taken")
ok, why = GO.Create(3321, 1, "B")
assert(not ok and has(why, "aus"), why)
NS.Set("orders.on", true)

---------------------------------------------------------------------------
-- 14 days: an own order unchanged closes, a heard one not heard again falls, a closed one goes after 3 days
---------------------------------------------------------------------------
STUB.addon = {}
local o = AmisiaDB.orders
o.own[id3].changed = time() - 15 * 86400
heard("Anna Amboss", "a003").seen = time() - 15 * 86400
GO.Sweep()
assert(o.own[id3].state == "X", "closed after 14 days")
assert(heard("Anna Amboss", "a003") == nil, "not heard for 14 days")
STUB.tick(3)
oa = sent("OA", "GUILD")
assert(#oa == 1 and oa[1].f[6] == "X", "the guild hears it")
o.own[id3].changed = time() - 4 * 86400
GO.Sweep()
assert(o.own[id3] == nil, "a closed one goes after 3 days")

---------------------------------------------------------------------------
-- the load check
---------------------------------------------------------------------------
local now = math.floor(time())
local function entry(x)
    local e = { rev = 1, spell = 2330, n = 1, mats = "B", state = "O", at = now, changed = now }
    for k, v in pairs(x or {}) do e[k] = v end
    return e
end
local root = { orders = { v = 1, own = {
        ["0001"] = entry({ note = "ok", junk = 1 }), ["0002"] = entry({ n = 21 }), ["0003"] = entry({ mats = "Z" }),
        ["xyz1"] = entry(), ["0004"] = entry({ state = "T" }), ["0005"] = entry({ state = "T", by = "Bob Hammer", note = "a|b" }),
        ["0006"] = entry({ state = "X", changed = now - 4 * 86400 }), ["0007"] = entry({ state = "X", by = "Bad1" }),
        ["0008"] = entry({ at = now - 10 }), ["0009"] = entry({ at = now - 20 }), ["000a"] = entry({ at = now - 30 }),
        ["000b"] = entry({ at = now - 40 }), ["000c"] = entry({ rev = 0 }) },
    heard = {
        ["Anna Amboss"] = { ["a001"] = entry({ seen = now }), ["a002"] = entry({ seen = now - 15 * 86400 }),
            ["a003"] = entry({ seen = now, state = "X" }), ["a004"] = entry({ seen = now, item = -3 }) },
        ["Bad|Name"] = { ["b001"] = entry({ seen = now }) },
        ["Bob Hammer"] = { ["b001"] = entry() },
    } } }
for i = 1, 8 do root.orders.heard["Anna Amboss"][("c%03d"):format(i)] = entry({ seen = now - i }) end
NS.GuildOrdersLoaded(root)
local ow, hd = root.orders.own, root.orders.heard
assert(ow["0001"] and ow["0001"].note == "ok" and ow["0001"].junk == nil)
assert(ow["0002"] == nil and ow["0003"] == nil and ow["xyz1"] == nil and ow["0004"] == nil and ow["000c"] == nil, "bad entries")
assert(ow["0005"] and ow["0005"].note == nil, "a note with a bar dropped alone")
assert(ow["0006"] == nil, "closed more than 3 days ago")
assert(ow["0007"] and ow["0007"].by == nil, "a closed one keeps no bad name")
local open = 0
for _, e in pairs(ow) do if e.state ~= "X" then open = open + 1 end end
assert(open == 5 and ow["000b"] == nil, "5 open, the newest: " .. open)
assert(hd["Bad|Name"] == nil and hd["Bob Hammer"] == nil, "a bad name, an entry without seen")
local anna = hd["Anna Amboss"]
assert(anna["a001"] and anna["a002"] == nil and anna["a003"] == nil and anna["a004"] and anna["a004"].item == nil)
local n = 0
for _ in pairs(anna) do n = n + 1 end
assert(n == 5, "5 per requester: " .. n)
local odd = { orders = "x" }
NS.GuildOrdersLoaded(odd)
assert(odd.orders == nil)
local empty = { orders = {} }
NS.GuildOrdersLoaded(empty)
assert(empty.orders.v == 1 and next(empty.orders.own) == nil and next(empty.orders.heard) == nil)

---------------------------------------------------------------------------
-- the question after the login: once, 30-60 s, to the guild; never before
---------------------------------------------------------------------------
STUB.addon = {}
STUB.fire("PLAYER_LOGIN")
STUB.tick(GO.LIM.askMin - 1)
assert(#sent("OQ") == 0, "not before 30 s")
STUB.tick(GO.LIM.askSpread + 2)
local q = sent("OQ", "GUILD")
assert(#q == 1 and q[1].f[1]:match("^%x%x%x%x$"), "one OQ")
STUB.tick(120)
assert(#sent("OQ") == 1, "once")
