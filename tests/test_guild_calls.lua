--[[clients Vulo_Sturmwind Kim_Eisherz Lia_Weide Pug]]
-- Aufrufe der Gilde between clients (F-211, D-136, Raid/GuildCalls.lua): a call goes to the guild (EA), every
-- member sees it and gets one chat line with [Anmelden] (not again for a new revision); a sign-up and a
-- withdrawal go by whisper (EJ) and only for the sender; only the creator changes or ends its call (EX); a
-- member outside the guild and a bad field are ignored; the gaps (EA 10 s, EJ 5 s per call, EQ 300 s); a late
-- login asks (EQ) and only creators answer, with their own call; the heartbeat and the drop after 10 minutes;
-- a /reload of the creator keeps the call; "Alle einladen" (order, roles, the raid, combat and leader); the
-- chat lockdown holds every message and the action says so once.
local V, K, Li, P = "Vulo Sturmwind", "Kim Eisherz", "Lia Weide", "Pug"
BUS.setGuild({ { name = V, rank = 1 }, { name = K, rank = 4 }, { name = Li, rank = 4 }, { name = P, rank = 4 },
               { name = "Anna Berg", rank = 4 }, { name = "Bert Stein", rank = 4 }, { name = "Carl Moor", rank = 4 },
               { name = "Dora Hain", rank = 4 }, { name = "Emil Feld", rank = 4, online = false } })
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.level = 40
        if STUB.player ~= "Pug" then
            for i = #STUB.guild, 1, -1 do if STUB.guild[i].name == "Pug" then table.remove(STUB.guild, i) end end
        end
        STUB.fire("GUILD_ROSTER_UPDATE")]])
end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lines(name, part)
    local n = 0
    for _, m in ipairs(C(name, "STUB.messages")) do if has(m, part) then n = n + 1 end end
    return n
end
local function lastLine(name) return C(name, "STUB.messages[#STUB.messages]") end

---------------------------------------------------------------------------
-- Vulo puts up a call: EA to the guild, the others see it, one chat line each
---------------------------------------------------------------------------
assert(C(V, [[NS.GuildCalls.Create({ art = "Q", title = "Quest |cffff0000Herod|r|Hitem:1|h", min = 35, at = 0,
    need = { T = 1, H = 1, S = 3 }, note = "Quest\tHerod" })]]) == true)
local ok, why = C(V, [[NS.GuildCalls.Create({ art = "Q", title = "Zwei", min = 1, at = 0, need = { T = 1, H = 1, S = 0 } })]])
assert(not ok and has(why, "schon einen Aufruf"), "one own call at a time")
local id = C(V, "AmisiaDB.guildCall.id")
assert(type(id) == "string" and id:match("^%x%x%x%x$"), tostring(id))
assert(C(V, "AmisiaDB.guildCall.title") == "Quest Herod" and C(V, "AmisiaDB.guildCall.note") == "Quest Herod", "codes, links and tabs stripped")
BUS.tick(1)
assert(BUS.count({ kind = "EA", chan = "GUILD", sender = V }) == 1)
local ea
for _, m in ipairs(BUS.sent) do if m.kind == "EA" then ea = m.text end end
assert(ea == "1EA\t" .. id .. "\t1\tQ\t-\tQuest Herod\t35\t0\t1/1/3\t0/0/0\t0/0/0\tO\tQuest Herod", ea)
for _, name in ipairs({ K, Li }) do
    local c = C(name, "NS.GuildCalls.Get('" .. V .. "')")
    assert(c and c.id == id and c.title == "Quest Herod" and c.min == 35 and c.need.S == 3 and c.state == "O", name)
    assert(lines(name, "sucht:") == 1, name .. ": one chat line")
end
local line = lastLine(K)
assert(has(line, "Vulo Sturmwind") and has(line, "sucht: Quest Herod (ab 35), Tank, Heiler, 3 Schaden"), line)
assert(has(line, "|Haddon:Amisia:call:" .. id .. "|h[Anmelden]|h"), "the link: " .. line)
assert(C(V, "NS.GuildCalls.Count()") == 0, "not the own echo")

-- the link opens the page at that call
C(K, "NS.GuildCalls.OnLink(nil, 'addon:Amisia:call:" .. id .. "')")
assert(C(K, "NS.CurrentPage()") == "calls" and C(K, "NS.GuildCalls.Focus()") == "vulo sturmwind")
C(K, "NS.GuildCalls.SetFocus(nil); AmisiaFrame:Hide()")

---------------------------------------------------------------------------
-- sign-ups by whisper; a new revision at most every 10 s, no second chat line
---------------------------------------------------------------------------
assert(C(K, "NS.GuildCalls.SignUp('" .. V .. "', 'H')") == true)
BUS.tick(1)
assert(BUS.count({ kind = "EJ", chan = "WHISPER", sender = K, target = V }) == 1)
local s = C(V, "AmisiaDB.guildCall.signups")
assert(#s == 1 and s[1].n == K and s[1].r == "H" and s[1].l == 40, "Kim as healer")
assert(C(K, "NS.GuildCalls.MySignup('" .. V .. "')") == "H")
BUS.tick(4)
assert(BUS.count({ kind = "EA", sender = V }) == 1, "not before 10 s after the last")
BUS.tick(7)
assert(BUS.count({ kind = "EA", chan = "GUILD", sender = V }) == 2, "the new revision")
assert(C(Li, "NS.GuildCalls.Get('" .. V .. "').signed.H") == 1 and C(Li, "NS.GuildCalls.Get('" .. V .. "').rev") == 2)
assert(lines(Li, "sucht:") == 1, "no chat line for a revision")
-- a withdrawal right after the sign-up waits for the gap of 5 s per call; then a sign-up again
C(K, "NS.GuildCalls.SignUp('" .. V .. "', 'S')")
BUS.tick(1)
assert(BUS.count({ kind = "EJ", sender = K }) == 2 and C(V, "AmisiaDB.guildCall.signups[1].r") == "S", "the role changed")
C(K, "NS.GuildCalls.Withdraw('" .. V .. "')")
BUS.tick(1)
assert(BUS.count({ kind = "EJ", sender = K }) == 2, "within 5 s of the last EJ: waits")
BUS.tick(5)
assert(BUS.count({ kind = "EJ", sender = K }) == 3 and #C(V, "AmisiaDB.guildCall.signups") == 0, "withdrawn")
BUS.tick(6)
C(K, "NS.GuildCalls.SignUp('" .. V .. "', 'H')")
C(Li, "NS.GuildCalls.SignUp('" .. V .. "', 'S')")
BUS.tick(12)
s = C(V, "AmisiaDB.guildCall.signups")
assert(#s == 2 and s[1].n == K and s[2].n == Li, "in sign-up order")

---------------------------------------------------------------------------
-- trust: a sign-up only for the sender, only by whisper, only members; only the creator ends or changes
---------------------------------------------------------------------------
C(V, ([[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EJ\t%s\tT\t40", "WHISPER", "Pug")
        STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EJ\t%s\tT\t40", "GUILD", "Anna Berg")
        STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EJ\tbeef\tT\t40", "WHISPER", "Bert Stein")
        STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EJ\t%s\tX\t40", "WHISPER", "Carl Moor")
        STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EJ\t%s\tT\t0", "WHISPER", "Dora Hain")]]):format(id, id, id, id))
BUS.tick(1)
assert(#C(V, "AmisiaDB.guildCall.signups") == 2, "a stranger, the guild channel, another id, a bad role or level: nothing")
-- Lia's EX with Vulo's id and Lia's EA with Vulo's id change nothing of Vulo's call
C(K, ([[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EX\t%s", "GUILD", "Lia Weide")
        STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\t%s\t9\tH\t-\tFalsch\t1\t0\t0/0/2\t0/0/0\t0/0/0\tO\t-", "GUILD", "Lia Weide")]]):format(id, id))
BUS.tick(1)
local c = C(K, "NS.GuildCalls.Get('" .. V .. "')")
assert(c and c.title == "Quest Herod" and c.art == "Q", "only the creator changes or ends its call")
assert(C(K, "NS.GuildCalls.Get('" .. Li .. "').title") == "Falsch", "Lia's own call under her name")
-- Pug (no member) puts up a call: nobody keeps it
assert(C(P, [[NS.GuildCalls.Create({ art = "S", title = "Pug", min = 1, at = 0, need = { T = 0, H = 0, S = 2 } })]]) == true)
BUS.tick(1)
assert(C(K, "NS.GuildCalls.Get('Pug')") == nil and lines(K, "Pug sucht") == 0, "a sender outside the guild is ignored")

---------------------------------------------------------------------------
-- a bad field drops the message; the gap of 10 s per sender
---------------------------------------------------------------------------
local bad = {
    "1EA\tzzzz\t1\tD\t-\tT\t1\t0\t1/1/1\t0/0/0\t0/0/0\tO\t-",     -- id
    "1EA\tabcd\t1\tX\t-\tT\t1\t0\t1/1/1\t0/0/0\t0/0/0\tO\t-",     -- art
    "1EA\tabcd\t1\tD\tsm-cath\tT\t1\t0\t1/1/1\t0/0/0\t0/0/0\tO\t-", -- key
    "1EA\tabcd\t1\tD\t-\tT|r\t1\t0\t1/1/1\t0/0/0\t0/0/0\tO\t-",    -- title with a bar
    "1EA\tabcd\t1\tD\t-\tT\t0\t0\t1/1/1\t0/0/0\t0/0/0\tO\t-",     -- level 0
    "1EA\tabcd\t1\tD\t-\tT\t1\t0\t0/0/0\t0/0/0\t0/0/0\tO\t-",     -- nobody wanted (one is enough since F-215)
    "1EA\tabcd\t1\tD\t-\tT\t1\t0\t41/0/0\t0/0/0\t0/0/0\tO\t-",    -- 41
    "1EA\tabcd\t1\tD\t-\tT\t1\t0\t1/1/1\t20/11/0\t0/0/0\tO\t-",   -- 31 signed
    "1EA\tabcd\t1\tD\t-\tT\t1\t0\t1/1/1\t0/0/0\t0/0/0\tX\t-",     -- state
    "1EA\tabcd\t1\tD\t-\tT\t1\t0\t1/1/1\t0/0/0\t0/0/0\tO",        -- the note missing
}
for _, text in ipairs(bad) do
    C(K, ("STUB.fire('CHAT_MSG_ADDON', 'Amisia', %q, 'GUILD', 'Anna Berg')"):format(text))
end
BUS.tick(1)
assert(C(K, "NS.GuildCalls.Get('Anna Berg')") == nil, "every bad field drops the message")
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tabcd\t1\tD\tsmcath\tKathedrale\t38\t0\t1/1/3\t0/0/0\t0/0/0\tO\t-", "GUILD", "Anna Berg")
       STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tabcd\t2\tD\tsmcath\tKathedrale\t38\t0\t1/1/3\t0/1/0\t0/0/0\tO\t-", "GUILD", "Anna Berg")]])
BUS.tick(1)
assert(C(K, "NS.GuildCalls.Get('Anna Berg').rev") == 1, "a second EA within 10 s is dropped")
BUS.tick(10)
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1EA\tabcd\t2\tD\tsmcath\tKathedrale\t38\t0\t1/1/3\t0/1/0\t0/0/0\tO\t-", "GUILD", "Anna Berg")]])
BUS.tick(1)
assert(C(K, "NS.GuildCalls.Get('Anna Berg').rev") == 2 and C(K, "NS.GuildCalls.Get('Anna Berg').signed.H") == 1, "after 10 s")

---------------------------------------------------------------------------
-- a late login asks the guild; only creators answer, each with its own call only
---------------------------------------------------------------------------
BUS.reload(Li)
assert(C(Li, "NS.GuildCalls.Get('" .. V .. "')") == nil, "nothing in memory after the reload")
assert(C(Li, "AmisiaDB.guildCall") == nil, "Lia has no own call")
C(Li, "STUB.fire('PLAYER_LOGIN')")
BUS.tick(45)
assert(BUS.count({ kind = "EQ", chan = "GUILD", sender = Li }) == 1, "one question")
assert(BUS.count({ kind = "EA", chan = "WHISPER", sender = V, target = Li }) == 1, "Vulo answers by whisper")
assert(BUS.count({ kind = "EA", sender = K }) == 0, "Kim has no own call and passes on nobody's")
assert(C(Li, "NS.GuildCalls.Get('" .. V .. "').signed.S") == 1, "the call is back")
assert(C(Li, "NS.GuildCalls.Get('Anna Berg')") == nil, "Anna's call came by a test line, nobody answers for her")

---------------------------------------------------------------------------
-- the heartbeat every 5 minutes; a call without an EA for 10 minutes is dropped
---------------------------------------------------------------------------
local before = BUS.count({ kind = "EA", chan = "GUILD", sender = V })
BUS.tick(301)
assert(BUS.count({ kind = "EA", chan = "GUILD", sender = V }) == before + 1, "the heartbeat")
assert(C(K, "NS.GuildCalls.Get('Anna Berg')") ~= nil, "Anna's call within 10 minutes of her last EA")
BUS.tick(300)
assert(C(K, "NS.GuildCalls.Get('" .. V .. "')") ~= nil, "kept by the heartbeat")
assert(C(K, "NS.GuildCalls.Get('Anna Berg')") == nil, "Anna's call without a heartbeat is gone after 10 minutes")

---------------------------------------------------------------------------
-- a /reload of the creator keeps the call and its sign-ups and announces it again
---------------------------------------------------------------------------
before = BUS.count({ kind = "EA", chan = "GUILD", sender = V })
BUS.reload(V)
assert(C(V, "AmisiaDB.guildCall.id") == id and #C(V, "AmisiaDB.guildCall.signups") == 2, "kept over the reload")
C(V, "STUB.fire('PLAYER_LOGIN')")
BUS.tick(11)
assert(BUS.count({ kind = "EA", chan = "GUILD", sender = V }) == before + 1, "announced again")
assert(lines(K, "sucht: Quest Herod") == 1, "no second chat line")

---------------------------------------------------------------------------
-- inviting: order, the roles' limit, the raid; combat and leader
---------------------------------------------------------------------------
C(V, [[INV, CONV = {}, 0
    C_PartyInfo.InviteUnit = function(n) INV[#INV + 1] = n end
    C_PartyInfo.ConvertToRaid = function() CONV = CONV + 1 end
    local list = AmisiaDB.guildCall.signups
    for _, e in ipairs({ { "Anna Berg", "S" }, { "Bert Stein", "T" }, { "Carl Moor", "S" }, { "Dora Hain", "S" }, { "Emil Feld", "H" } }) do
        list[#list + 1] = { n = e[1], r = e[2], l = 40, t = time() }
    end]])
assert(table.concat(C(V, "NS.GuildCalls.InviteList()"), ",") == "Kim Eisherz,Lia Weide,Anna Berg,Bert Stein,Carl Moor",
    "sign-up order, three damage, Emil offline")
C(V, "STUB.combat = true")
ok, why = C(V, "NS.GuildCalls.InviteAll()")
assert(not ok and why == "Nicht im Kampf", tostring(why))
C(V, "STUB.combat = false; STUB.roster = { { name = 'Vulo Sturmwind' }, { name = 'Anna Berg' } }; STUB.party = true; STUB.leader = false")
ok, why = C(V, "NS.GuildCalls.InviteAll()")
assert(not ok and why == "Nur als Gruppenleiter", tostring(why))
C(V, "STUB.roster = {}; STUB.party = nil; STUB.leader = true; STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(V, "NS.GuildCalls.InviteAll()") == true)
BUS.tick(3)
assert(table.concat(C(V, "INV"), ",") == "Kim Eisherz,Lia Weide,Anna Berg,Bert Stein", "four fill the party: " .. table.concat(C(V, "INV"), ","))
assert(C(V, "CONV") == 0, "no raid before someone joined")
C(V, "STUB.roster = { { name = 'Vulo Sturmwind' }, { name = 'Kim Eisherz' } }; STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')")
BUS.tick(1)
assert(C(V, "CONV") == 1, "more than five: the group becomes a raid")
C(V, "STUB.party = nil; STUB.fire('GROUP_ROSTER_UPDATE')")
BUS.tick(3)
assert(table.concat(C(V, "INV"), ",") == "Kim Eisherz,Lia Weide,Anna Berg,Bert Stein,Carl Moor", "then the fifth")
assert(not C(V, "NS.GuildCalls.Running()"), "the run ended")
-- in the group counts as "dabei": a new revision with Kim's healer in the group
BUS.tick(11)
assert(C(Li, "NS.GuildCalls.Get('" .. V .. "').inGroup.H") == 1, "Kim in the group as healer")
-- everyone in: the call is full
C(V, [[STUB.roster = { { name = "Vulo Sturmwind" }, { name = "Kim Eisherz" }, { name = "Lia Weide" }, { name = "Anna Berg" },
    { name = "Bert Stein" }, { name = "Carl Moor" } }; STUB.fire("GROUP_ROSTER_UPDATE")]])
BUS.tick(11)
assert(C(Li, "NS.GuildCalls.Get('" .. V .. "').state") == "F", "full")
-- a single invite: offline and declined
ok, why = C(V, "NS.GuildCalls.Invite('Emil Feld')")
assert(not ok and has(why, "offline"), tostring(why))
C(V, "NS.GuildCalls.Decline('Dora Hain')")
assert(C(V, "NS.GuildCalls.SignupOf('Dora Hain')") == nil and C(V, "AmisiaDB.guildCall.declined['dora hain']") == true)

---------------------------------------------------------------------------
-- the chat lockdown: nothing goes, the action waits with one chat line
---------------------------------------------------------------------------
BUS.lock(true)
local ej = BUS.count({ kind = "EJ", sender = K })
C(K, "NS.GuildCalls.Withdraw('" .. V .. "')")
assert(has(lastLine(K), "Kampfsperre: Deine Abmeldung"), lastLine(K))
local ex = BUS.count({ kind = "EX" })
C(V, "NS.GuildCalls.End()")
assert(has(lastLine(V), "Kampfsperre: Das Ende deines Aufrufs"), lastLine(V))
BUS.tick(5)
assert(BUS.count({ kind = "EJ", sender = K }) == ej and BUS.count({ kind = "EX" }) == ex, "nothing in the lockdown")
BUS.lock(false)
BUS.tick(3)
assert(BUS.count({ kind = "EJ", sender = K }) == ej + 1, "the withdrawal after the lockdown")
assert(BUS.count({ kind = "EX", chan = "GUILD", sender = V }) == ex + 1, "the end after the lockdown")
assert(C(K, "NS.GuildCalls.Get('" .. V .. "')") == nil and C(Li, "NS.GuildCalls.Get('" .. V .. "')") == nil, "gone for everyone")
assert(C(V, "AmisiaDB.guildCall") == nil)

-- the chat line can be switched off
C(K, "NS.Set('guildCalls.chat', false)")
local n = lines(K, "sucht:")
assert(C(V, [[NS.GuildCalls.Create({ art = "H", title = "Hilfe bei Elite", min = 30, at = 0, need = { T = 0, H = 1, S = 1 } })]]) == true)
BUS.tick(11)
assert(C(K, "NS.GuildCalls.Get('" .. V .. "').art") == "H" and lines(K, "sucht:") == n, "no line with guildCalls.chat off")
assert(lines(Li, "sucht: Hilfe bei Elite") == 1)
print("guild calls ok")
