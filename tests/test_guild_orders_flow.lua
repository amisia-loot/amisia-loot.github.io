--[[clients Anna_Amboss Ben_Nadel Clara_Kessel Dora_Stein Pug]]
-- Guild orders between clients (F-231, D-164, Gear/GuildOrders.lua), the spec's flow and acceptance: Anna places an
-- order (OA to the guild); Ben and Clara, whose characters know the recipe, get the chat line and see it under
-- "für mich", Dora only under the others; Pug (outside the roster) is ignored both ways; Ben and Clara accept at
-- once: Anna's client takes the first (OT), Clara reads "schon angenommen von Ben"; Ben says done, Anna reads it
-- and closes it ("Erhalten"): gone at everyone; a late login asks (OQ) and has Anna's open order within a minute;
-- the chat lockdown holds every message.
local A, B, Cl, Do, P = "Anna Amboss", "Ben Nadel", "Clara Kessel", "Dora Stein", "Pug"
BUS.setGuild({ { name = A, rank = 3 }, { name = B, rank = 3 }, { name = Cl, rank = 3 }, { name = Do, rank = 3 }, { name = P, rank = 4 } })
BUS.guild = { A, B, Cl, Do, P }
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lines(name, part)
    local n = 0
    for _, m in ipairs(C(name, "STUB.messages")) do if has(m, part) then n = n + 1 end end
    return n
end
for _, name in ipairs(CLIENTS) do
    C(name, [[dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
        STUB.instance = { name = "Durotar", type = "none", id = 0 }
        if STUB.player ~= "Pug" then
            for i = #STUB.guild, 1, -1 do if STUB.guild[i].name == "Pug" then table.remove(STUB.guild, i) end end
        end
        STUB.fire("GUILD_ROSTER_UPDATE")]])
end
-- Ben and Clara know the healing potion, Pug too (but nobody's roster names him)
for _, name in ipairs({ B, Cl, P }) do
    C(name, [[AmisiaDB.prof = { chars = { [STUB.player] = { [171] = { rank = 300, max = 300, day = NS.DropsToday(), known = { [2330] = true } } } } }]])
end
local function heard(name, from, id) return C(name, ("local o = AmisiaDB.orders; return o and o.heard[%q] and o.heard[%q][%q]"):format(from, from, id)) end
local function forMe(name)
    return C(name, [[local a, b = NS.GuildOrders.Others(); return #a .. "/" .. #b]])
end

---------------------------------------------------------------------------
-- Anna places an order: everyone with Amisia hears it; the crafters get the line
---------------------------------------------------------------------------
local id = C(A, [[return NS.GuildOrders.Create(2330, 4, "B", "Stoff hab ich")]])
assert(type(id) == "string" and #id == 4, tostring(id))
assert(C(A, "NS.GuildOrders.StateText(NS.GuildOrders.Mine()[1])") == "offen", "Meine Aufträge: offen")
BUS.tick(2)
assert(BUS.count({ kind = "OA", chan = "GUILD", sender = A }) == 1)
for _, name in ipairs({ B, Cl, Do }) do assert(heard(name, A, id), name .. " heard it") end
assert(lines(B, "Gildenauftrag von") == 1 and lines(Cl, "Gildenauftrag von") == 1 and lines(Do, "Gildenauftrag von") == 0,
    "the line only for those who can craft it")
assert(forMe(B) == "1/0" and forMe(Do) == "0/1", "für mich / alle offenen")

---------------------------------------------------------------------------
-- Ben and Clara accept at once: the first wins
---------------------------------------------------------------------------
assert(C(B, ("return NS.GuildOrders.Accept(%q, %q)"):format(A, id)) == true)
assert(C(Cl, ("return NS.GuildOrders.Accept(%q, %q)"):format(A, id)) == true)
BUS.tick(15)
assert(BUS.count({ kind = "OT", chan = "WHISPER", target = A }) == 2, "two OT to Anna")
assert(C(A, ("AmisiaDB.orders.own[%q].by"):format(id)) == B and C(A, ("AmisiaDB.orders.own[%q].state"):format(id)) == "T", "Ben first")
assert(lines(A, "Ben Nadel hat deinen Gildenauftrag angenommen") == 1)
assert(C(A, "NS.GuildOrders.StateText(NS.GuildOrders.Mine()[1])") == "angenommen von Ben Nadel")
assert(heard(B, A, id).by == B and heard(Cl, A, id).by == B and heard(Do, A, id).state == "T", "everyone has the new state")
assert(lines(Cl, "Schon angenommen von Ben Nadel") == 1, "Clara reads it")
-- a second crafter cannot take it now
local ok, why = C(Cl, ("return NS.GuildOrders.Accept(%q, %q)"):format(A, id))
assert(not ok and has(why, "Schon angenommen von Ben Nadel"), why)

---------------------------------------------------------------------------
-- done, received: gone at everyone
---------------------------------------------------------------------------
assert(C(B, ("return NS.GuildOrders.Done(%q, %q)"):format(A, id)) == true)
BUS.tick(5)
assert(C(A, ("AmisiaDB.orders.own[%q].state"):format(id)) == "D" and lines(A, "Ben Nadel: 4x") == 1, "Anna reads: done")
assert(C(A, ("return NS.GuildOrders.Received(%q)"):format(id)) == true)
BUS.tick(5)
for _, name in ipairs({ B, Cl, Do }) do assert(heard(name, A, id) == nil, name .. ": gone") end
assert(C(A, "#NS.GuildOrders.Mine()") == 0)

---------------------------------------------------------------------------
-- a late login asks the guild and has the open orders within a minute
---------------------------------------------------------------------------
local id2 = C(A, [[return NS.GuildOrders.Create(2330, 1, "H")]])
BUS.tick(3)
C(Do, "AmisiaDB.orders = nil")
BUS.reload(Do)
C(Do, [[STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD", true, false)]])
BUS.tick(29)
assert(BUS.count({ kind = "OQ", sender = Do }) == 0, "not before 30 s")
BUS.tick(45)
assert(BUS.count({ kind = "OQ", sender = Do, chan = "GUILD" }) == 1, "the question")
assert(heard(Do, A, id2) and heard(Do, A, id2).state == "O", "Anna's open order within about a minute")
assert(BUS.count({ kind = "OA", chan = "WHISPER", target = Do, sender = B }) == 0, "only requesters answer")

---------------------------------------------------------------------------
-- Pug outside the roster: his order is taken by nobody, his step changes nothing
---------------------------------------------------------------------------
C(P, [[NS.GuildOrders.Create(2330, 1, "B")]])
BUS.tick(3)
for _, name in ipairs({ A, B, Cl, Do }) do assert(C(name, ("AmisiaDB.orders and AmisiaDB.orders.heard[%q]"):format(P)) == nil) end
C(P, ("NS.GuildOrders._store(true).heard[%q] = { [%q] = { rev = 1, spell = 2330, n = 1, mats = 'H', state = 'O', at = 1, changed = 1, seen = time() } }"):format(A, id2))
C(P, ("NS.GuildOrders.Accept(%q, %q)"):format(A, id2))
BUS.tick(5)
assert(C(A, ("AmisiaDB.orders.own[%q].state"):format(id2)) == "O", "Pug cannot accept")

---------------------------------------------------------------------------
-- the chat lockdown holds every message; after it, the step goes
---------------------------------------------------------------------------
BUS.lock(true)
assert(C(B, ("return NS.GuildOrders.Accept(%q, %q)"):format(A, id2)) == true)
BUS.tick(10)
assert(C(A, ("AmisiaDB.orders.own[%q].state"):format(id2)) == "O", "nothing in the lockdown")
BUS.lock(false)
BUS.tick(10)
assert(C(A, ("AmisiaDB.orders.own[%q].by"):format(id2)) == B, "after it")
