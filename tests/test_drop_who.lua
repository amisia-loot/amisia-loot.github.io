--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- Who shares and "Jetzt abgleichen" (F-189, D-121): the drop exchange remembers, for the session only,
-- the guild members it heard announce (DV) or that asked it, with what they announced and the state of
-- the comparison; "Jetzt abgleichen" (and /amisia drops sync) announces now within its own minute and
-- the exchange's limits, pulls the members waiting, and says after a short while who answered and how
-- many kills came. Pug reaches the guild channel but no roster names him: he never shows up. Nothing
-- of the list is sent or saved; the protocol is unchanged.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local ME = { [VULO] = "a0000001", [FRAK] = "b0000002", [KIM] = "c0000003", [PUG] = "d0000004" }
local DROP_KINDS = { DV = true, DQ = true, DI = true, DR = true, DW = true }

local function setup(name)
    C(name, ([[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
-- records given as Lua source: { id, npc, inst, days ago, items }, as recorded by the client itself
local function add(name, list)
    return C(name, [[local today, n = NS.DropsToday(), 0
        for _, x in ipairs({ ]] .. list .. [[ }) do
            local r = { h = x[1], npc = x[2], inst = x[3], diff = 1, day = today - x[4], o = AmisiaDB.drops.me, src = "G", it = x[5] or {} }
            if NS.DropsMerge(r) == "new" then n = n + 1; AmisiaDB.drops.k[r.h].mine = true end
        end
        return n]])
end
local function kills(name) return C(name, "NS.DropsStatus().kills") end
-- the list "Wer teilt" of a client as "name=state:total:got:gave;..." (the last seen first)
local function who(name)
    return C(name, [[local out = {}
        for _, m in ipairs(NS.DropSyncMembers()) do
            out[#out + 1] = ("%s=%s:%s:%d:%d"):format(m.name, m.state, tostring(m.total), m.got, m.gave)
        end
        return table.concat(out, ";")]])
end
local function stateOf(name, member)
    return C(name, ([[for _, m in ipairs(NS.DropSyncMembers()) do if m.name == %q then return m.state end end
        return nil]]):format(member))
end
local function sync(name) return C(name, "return NS.DropSyncNow()") end
local function canSync(name) return C(name, "return NS.DropSyncCanSync()") end
local function result(name) return C(name, "NS.DropSyncResultText()") end
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
BUS.guild = { VULO, FRAK, KIM, PUG }
for _, name in ipairs(CLIENTS) do setup(name) end
-- no automatic announcement after records learned (the test drives every announcement itself)
for _, name in ipairs(CLIENTS) do C(name, "NS.DROPSYNC_LIMITS.firstMin = 100000") end
-- Vulo and Kim hold the same two kills; Fraktur one of them and one more; Pug one of his own
assert(add(VULO, [[{ "11111111", 213450, 2834, 1 }, { "22222222", 213451, 2834, 3 }]]) == 2)
assert(add(KIM, [[{ "11111111", 213450, 2834, 1 }, { "22222222", 213451, 2834, 3 }]]) == 2)
assert(add(FRAK, [[{ "11111111", 213450, 2834, 1 }, { "33333333", 213460, 409, 9 }]]) == 2)
assert(add(PUG, [[{ "99999999", 213450, 2834, 0 }]]) == 1)

---------------------------------------------------------------------------
-- nobody heard yet: an empty list; the link may start (records to announce)
---------------------------------------------------------------------------
assert(who(VULO) == "" and C(VULO, "NS.DropSyncInfo().members") == 0)
assert(C(VULO, "NS.DropSyncInfo().announced") == nil, "not announced yet")
assert(C(VULO, "NS.DropSyncInfo().manual") == nil)
assert(canSync(VULO) == true)

---------------------------------------------------------------------------
-- Kim announces: Vulo lists Kim as the same, Fraktur as one with other kills waiting to be pulled
---------------------------------------------------------------------------
local t0 = C(KIM, "STUB.clock")
assert(sync(KIM) == true)
assert(result(KIM) == "Abgleich läuft ...", tostring(result(KIM)))
BUS.tick(1)
assert(BUS.count({ kind = "DV", sender = KIM, chan = "GUILD", from = t0 }) == 1, "one announcement")
assert(stateOf(VULO, KIM) == "equal", who(VULO))
assert(who(VULO) == KIM .. "=equal:2:0:0", who(VULO))
local s = stateOf(FRAK, KIM)
assert(s == "other" or s == "pulling", who(FRAK))
-- the running run blocks a second click
local ok, why = canSync(KIM)
assert(ok == false and why == "running", tostring(why))
-- Fraktur pulls Kim's second kill; Kim served him (he never announced: "gave")
BUS.tick(200)
assert(kills(FRAK) == 3)
assert(who(FRAK) == KIM .. "=got:2:1:0", who(FRAK))
assert(who(KIM) == FRAK .. "=gave:nil:0:1", who(KIM))
assert(result(KIM) == "Abgleich: 1 Mitglied hat geantwortet, 0 neue Kills.", tostring(result(KIM)))
assert(stateOf(VULO, KIM) == "equal", "Vulo had nothing to pull")

---------------------------------------------------------------------------
-- Fraktur announces, then Vulo syncs: Vulo pulls Fraktur at once (no spread to wait for), Fraktur
-- has nothing new at Vulo; the result counts who answered and what came
---------------------------------------------------------------------------
local t1 = C(VULO, "STUB.clock")
assert(sync(FRAK) == true)
BUS.tick(1)
s = stateOf(VULO, FRAK)
assert(s == "more" or s == "pulling", who(VULO))
assert(sync(VULO) == true)
BUS.tick(2)
assert(stateOf(VULO, FRAK) == "pulling", "the manual run skips the spread: " .. who(VULO))
assert(C(VULO, "NS.DropSyncResultText()") == "Abgleich läuft ...")
BUS.tick(200)
assert(kills(VULO) == 3, "Fraktur's kill came")
assert(stateOf(VULO, FRAK) == "equal" or stateOf(VULO, FRAK) == "got", who(VULO))
local r = result(VULO)
assert(has(r, "neuer Kill") and has(r, "Abgleich: "), tostring(r))
assert(r == "Abgleich: 1 Mitglied hat geantwortet, 1 neuer Kill." or r == "Abgleich: 2 Mitglieder haben geantwortet, 1 neuer Kill.", r)
assert(BUS.count({ kind = "DV", sender = VULO, from = t1 }) == 1, "one announcement of the run")
assert(C(VULO, "NS.DropSyncInfo().announced") ~= nil)
-- the result stays five minutes, then the line is gone
BUS.tick(301)
assert(result(VULO) == nil)

---------------------------------------------------------------------------
-- the manual minute: a second run within a minute of the last announcement waits; then it goes
---------------------------------------------------------------------------
C(VULO, "NS.DROPSYNC_LIMITS.manualGap = 600")
ok, why = canSync(VULO)
local _, _, wait = C(VULO, "return NS.DropSyncCanSync()")
assert(ok == false and why == "wait" and wait > 0 and wait <= 600, tostring(why) .. " " .. tostring(wait))
assert(C(VULO, ("NS.DropSyncWhyText('wait', %d)"):format(wait)) == ("Wieder in %d s."):format(wait))
local n0 = BUS.count({ kind = "DV", sender = VULO })
assert(sync(VULO) == false)
BUS.tick(5)
assert(BUS.count({ kind = "DV", sender = VULO }) == n0, "no announcement while it waits")
C(VULO, "NS.DROPSYNC_LIMITS.manualGap = 60")
assert(canSync(VULO) == true)

---------------------------------------------------------------------------
-- the reasons: sharing off, no guild, an instance, combat, the lockdown
---------------------------------------------------------------------------
local function reason(name, setup_, undo)
    C(name, setup_)
    local okR, whyR = canSync(name)
    C(name, undo)
    assert(okR == false, setup_)
    return whyR
end
assert(reason(VULO, "NS.Set('drops.share', false)", "NS.Set('drops.share', true)") == "off")
assert(reason(VULO, "STUB.inGuild = false", "STUB.inGuild = nil") == "guild")
assert(reason(VULO, [[STUB.instance = { name = "Halle der Thane", type = "party", id = 2834, diff = 1 }]],
    [[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }]]) == "instance")
assert(reason(VULO, "STUB.combat = true", "STUB.combat = false") == "combat")
assert(C(VULO, "NS.DropSyncWhyText('instance')") == "In Instanzen tauscht Amisia keine Drop-Daten.")
assert(canSync(VULO) == true)
-- nothing to announce and nobody waiting: nothing to do
C(PUG, "AmisiaDB.drops.k = {}; NS.DropsPrune()")
ok, why = canSync(PUG)
assert(ok == false and why == "nothing", tostring(why))
C(PUG, [[NS.DropsMerge({ h = "99999999", npc = 213450, inst = 2834, diff = 1, day = NS.DropsToday(), o = AmisiaDB.drops.me, src = "G", it = {} })]])

---------------------------------------------------------------------------
-- a stranger never shows up: Pug announces to the guild channel, nobody lists him
---------------------------------------------------------------------------
assert(sync(PUG) == true)
BUS.tick(120)
for _, name in ipairs({ VULO, FRAK, KIM }) do assert(not has(who(name), PUG), name .. ": " .. who(name)) end

---------------------------------------------------------------------------
-- /amisia drops sync (and the German word): the start and the result in the chat
---------------------------------------------------------------------------
BUS.tick(60)
C(KIM, "STUB.messages = {}; SlashCmdList.AMISIA('drops sync')")
assert(has(C(KIM, "table.concat(STUB.messages, ' / ')"), "Abgleich gestartet"), C(KIM, "table.concat(STUB.messages, ' / ')"))
C(KIM, "STUB.messages = {}; SlashCmdList.AMISIA('drops abgleichen')")
assert(has(C(KIM, "table.concat(STUB.messages, ' / ')"), "Abgleich geht gerade nicht: Der Abgleich läuft schon."), C(KIM, "table.concat(STUB.messages, ' / ')"))
BUS.tick(200)
assert(has(C(KIM, "table.concat(STUB.messages, ' / ')"), "Abgleich: "), C(KIM, "table.concat(STUB.messages, ' / ')"))
C(KIM, "STUB.messages = {}; SlashCmdList.AMISIA('drops')")
local line = C(KIM, "STUB.messages[1]")
assert(has(line, "zuletzt Kills empfangen") and has(line, "Wer teilt: ") and not has(line, "letzter Austausch"), line)

---------------------------------------------------------------------------
-- nothing of the list goes anywhere: no drop message names a member in its fields; nothing saved
---------------------------------------------------------------------------
for _, m in ipairs(BUS.sent) do
    if DROP_KINDS[m.kind] then
        for _, n in ipairs({ VULO, FRAK, KIM, PUG, "Vulo", "Kim" }) do assert(not has(m.text, n), m.text) end
    end
end
for _, name in ipairs(CLIENTS) do
    assert(C(name, "AmisiaDB.drops.who == nil and AmisiaDB.drops.members == nil"), name)
    local saved = C(name, [[local out = {}
        local function walk(t, depth)
            if depth > 4 then return end
            for k, v in pairs(t) do
                if type(v) == "string" then out[#out + 1] = v end
                if type(k) == "string" then out[#out + 1] = k end
                if type(v) == "table" then walk(v, depth + 1) end
            end
        end
        walk(AmisiaDB.drops, 0)
        return table.concat(out, "\n")]])
    for _, n in ipairs({ VULO, FRAK, KIM, PUG }) do assert(not has(saved, n), name .. " saved " .. n) end
end

---------------------------------------------------------------------------
-- the cap: 40 members at most, the one seen longest ago goes; the numbers of a DV are checked
---------------------------------------------------------------------------
local rows = { { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } }
for i = 1, 45 do rows[#rows + 1] = { name = ("Gast%02d"):format(i), rank = 4 } end
BUS.setGuild(rows)
C(VULO, "STUB.fire('GUILD_ROSTER_UPDATE')")
local today = C(VULO, "NS.DropsToday()")
for i = 1, 45 do
    C(VULO, ("STUB.fire('CHAT_MSG_ADDON', 'Amisia', %q, 'GUILD', %q, %q, 0, 0, '', 0)"):format(
        ("1DV\t2\t%d\t%d\t0:abcd:1"):format(i, i == 45 and 99999 or today), ("Gast%02d"):format(i), VULO))
    BUS.tick(1)
end
assert(C(VULO, "NS.DropSyncInfo().members") == 40, C(VULO, "NS.DropSyncInfo().members"))
local list = who(VULO)
assert(has(list, "Gast45=") and not has(list, "Gast01="), list)
local g45 = C(VULO, [[for _, m in ipairs(NS.DropSyncMembers()) do if m.name == "Gast45" then return m.newest end end return "none"]])
assert(g45 == nil, "a newest day far in the future is not taken: " .. tostring(g45))
