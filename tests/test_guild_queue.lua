--[[clients Vulo_Sturmwind Kim_Eisherz Lia_Weide Ann_Smith Pug]]
-- Gilden-Warteschlange between clients (F-227, D-155, Raid/GuildQueue.lua): the own queue opens the window and
-- its wait counts; the state goes to the guild as QW 2 s after a change, at once on a pop, a join (the hook on
-- AcceptBattlefieldPort) and a decline, every 75 s while queued (with the window closed too); a member's state
-- stands under its battleground (popped first), "Aufgegangen", "Beigetreten" 10 s, "Abgelehnt" 5 s; leaving the
-- queue closes the window and sends the empty QW; with bgqueue.share off one empty QW and nothing more; a sender
-- outside the guild, a bad field and the gaps; combat holds nothing back, a boss fight's restriction does; nothing
-- inside a battleground (the waiting QW dropped); a German and an English client mean the same battleground by its
-- number; 180 s without a QW and the offline line drop a member; the class from the roster; the sound.
local V, K, Li, A, P = "Vulo Sturmwind", "Kim Eisherz", "Lia Weide", "Ann Smith", "Pug"
BUS.setGuild({ { name = V, rank = 1 }, { name = K, rank = 4 }, { name = Li, rank = 4 }, { name = A, rank = 4 },
               { name = P, rank = 4 }, { name = "Anna Berg", rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[if STUB.player ~= "Pug" then
            for i = #STUB.guild, 1, -1 do if STUB.guild[i].name == "Pug" then table.remove(STUB.guild, i) end end
        end
        for _, m in ipairs(STUB.guild) do if m.name == "Kim Eisherz" then m.class = "WARRIOR" end end
        ERR_FRIEND_OFFLINE_S = "%s ist jetzt offline."
        STUB.fire("GUILD_ROSTER_UPDATE")]])
end
-- Ann plays an English client: the same battlegrounds under English names
C(A, [[STUB.bgTypes = { { name = "Alterac Valley", id = 1 }, { name = "Warsong Gulch", id = 2 }, { name = "Arathi Basin", id = 3 } }
       NS.GuildQueue.Rebuild()]])
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function qw(filter) filter.kind = "QW"; return BUS.count(filter) end
local function lastQW(sender)
    local text
    for _, m in ipairs(BUS.sent) do if m.kind == "QW" and m.sender == sender then text = m.text end end
    return text
end
local function rows(name) return C(name, "NS.GuildQueue.Rows()") end
local function rowOf(name, who)
    for _, r in ipairs(rows(name)) do if r.kind == "mate" and r.name == who then return r end end
    return nil
end
local function queue(name, slot, status, map, extra)
    C(name, ("STUB.queues[%d] = { status = %q, map = %q, since = STUB.clock, est = %d, expire = %d }; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
        :format(slot, status, map, extra and extra.est or 0, extra and extra.expire or 0))
end
local function leave(name, slot)
    C(name, ("STUB.queues[%d] = nil; STUB.fire('UPDATE_BATTLEFIELD_STATUS')"):format(slot))
end

assert(C(V, "NS.GuildQueue.IdOf('Kriegshymnenschlucht')") == 2 and C(A, "NS.GuildQueue.IdOf('Warsong Gulch')") == 2,
    "both clients give the same number")
assert(C(V, "NS.GuildQueue.IdOf('Warsong Gulch')") == nil, "a name this client does not give")
assert(C(V, "NS.GuildQueue.Shown()") == false)

---------------------------------------------------------------------------
-- Vulo queues for Warsong Gulch: the window opens, the wait counts, the state goes 2 s later
---------------------------------------------------------------------------
queue(V, 1, "queued", "Kriegshymnenschlucht", { est = 330000 })
assert(C(V, "NS.GuildQueue.Shown()") == true, "the own queue opens the window")
assert(qw({ sender = V }) == 0, "not at once")
BUS.tick(1)
local r = rows(V)
assert(r[1].kind == "bar" and r[1].left == "Kriegshymnenschlucht" and r[1].mine, "the own bar")
assert(r[1].right == "0:01 / ~6 min", tostring(r[1].right))
assert(r[2].kind == "foot" and r[2].left == "Niemand aus der Gilde wartet", "nobody else yet")
assert(C(V, "NS.GuildQueue.Title()") == "Gilden-Warteschlange (0)")
BUS.tick(2)
assert(qw({ sender = V, chan = "GUILD" }) == 1, "2 s after the change")
assert(lastQW(V):match("^1QW\t1\t2:W:%d+$"), lastQW(V))
BUS.tick(3)
assert(rows(V)[1].right == "0:06 / ~6 min", "counts every second: " .. tostring(rows(V)[1].right))
for _, name in ipairs({ K, Li, A }) do
    local m = C(name, "NS.GuildQueue.Get('" .. V .. "')")
    assert(m and m.entries[2] and m.entries[2].s == "W", name .. " has Vulo waiting")
end
assert(C(V, "NS.GuildQueue.Get('" .. V .. "')") == nil, "not the own echo")
assert(C(K, "NS.GuildQueue.Shown()") == false, "Kim waits for nothing: no window")

---------------------------------------------------------------------------
-- Ann (English) queues for the same battleground; Vulo sees her under his bar
---------------------------------------------------------------------------
queue(A, 1, "queued", "Warsong Gulch")
BUS.tick(3)
assert(qw({ sender = A }) == 1 and lastQW(A):match("^1QW\t1\t2:W:%d+$"), tostring(lastQW(A)))
local ann = rowOf(V, A)
assert(ann and ann.id == 2 and ann.right:match("^0:0%d$"), "Ann under Warsong Gulch with her wait")
assert(has(ann.left, "|c") and has(ann.left, A), "in her class colour")
assert(C(V, "NS.GuildQueue.Title()") == "Gilden-Warteschlange (1)")
local vulo = rowOf(A, V)
assert(vulo and vulo.id == 2, "Ann sees Vulo under her bar")
assert(rows(A)[1].left == "Warsong Gulch", "the name in the own client's language")

-- Kim queues for Arathi Basin: a bar of its own under Vulo's, his class from the roster
queue(K, 1, "queued", "Arathibecken")
BUS.tick(3)
r = rows(V)
assert(r[1].id == 2 and r[1].mine and r[3].kind == "bar" and r[3].id == 3 and not r[3].mine and r[3].right == "",
    "the own bar first, then Kim's battleground")
assert(C(V, "NS.GuildQueue.Get('" .. K .. "').class") == "WARRIOR", "the class from the roster")

---------------------------------------------------------------------------
-- combat holds nothing back; a boss fight's restriction does (the state goes once it ends)
---------------------------------------------------------------------------
BUS.tick(11)
local kb = qw({ sender = K })
C(K, "STUB.combat = true")
queue(K, 2, "queued", "Kriegshymnenschlucht")
BUS.tick(3)
assert(qw({ sender = K }) == kb + 1 and has(lastQW(K), "\t2:W:"), "a change in combat goes 2 s later: " .. tostring(lastQW(K)))
assert(C(V, "NS.GuildQueue.Get('" .. K .. "').entries[2] ~= nil"), "Vulo sees Kim waiting in his fight")
C(K, "STUB.restricted = true; STUB.fire('ADDON_RESTRICTION_STATE_CHANGED')")
leave(K, 2)
BUS.tick(15)
assert(qw({ sender = K }) == kb + 1, "the boss fight's restriction holds the change back")
C(K, "STUB.restricted = false; STUB.fire('ADDON_RESTRICTION_STATE_CHANGED')")
BUS.tick(1)
assert(qw({ sender = K }) == kb + 2 and not has(lastQW(K), "\t2:W:"), "it goes once the restriction ends, still in combat: "
    .. tostring(lastQW(K)))
C(K, "STUB.combat = false")

---------------------------------------------------------------------------
-- the resend every 75 s, with the window closed too
---------------------------------------------------------------------------
C(V, "AmisiaGuildQueue:Hide()")
assert(C(V, "NS.GuildQueue.Shown()") == false)
BUS.tick(2)
assert(C(V, "NS.GuildQueue.Shown()") == false, "closed by the player: stays closed for this queue")
local before = qw({ sender = V })
BUS.tick(75)
assert(qw({ sender = V }) == before + 1, "the resend every 75 s with the window closed")
assert(C(Li, "NS.GuildQueue.Get('" .. V .. "')") ~= nil, "kept by the resend")

---------------------------------------------------------------------------
-- Ann's queue pops (at once), she enters (at once, from the hook): Aufgegangen, then Beigetreten 10 s
---------------------------------------------------------------------------
C(V, "NS.Set('bgqueue.sound', true); STUB.sounds = {}")
before = qw({ sender = A })
C(A, "STUB.queues[1].status = 'confirm'; STUB.queues[1].expire = 80; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
BUS.deliver()
assert(qw({ sender = A }) == before + 1 and lastQW(A) == "1QW\t1\t2:P:80", "the pop at once: " .. tostring(lastQW(A)))
ann = rowOf(V, A)
assert(ann.right == "|cff4fbf7aAufgegangen|r", tostring(ann.right))
BUS.tick(4)
C(A, "AcceptBattlefieldPort(1, true)")
BUS.deliver()
assert(qw({ sender = A }) == before + 2 and lastQW(A) == "1QW\t1\t2:J:0", "the join at once: " .. tostring(lastQW(A)))
assert(C(A, "STUB.ports[1][1]") == 1 and C(A, "STUB.ports[1][2]") == true, "the client's own function ran")
assert(rowOf(V, A).right == "Beigetreten")
-- Ann is inside now: nothing more from her
C(A, [[STUB.queues[1].status = "active"; STUB.instance = { name = "Warsong Gulch", type = "pvp", id = 489 }; STUB.battlefield = true
       STUB.fire("PLAYER_ENTERING_WORLD"); STUB.fire("UPDATE_BATTLEFIELD_STATUS")]])
BUS.tick(6)
assert(rowOf(V, A).right == "Beigetreten", "still within 10 s")
BUS.tick(5)
assert(rowOf(V, A) == nil, "gone 10 s after the join")
assert(qw({ sender = A }) == before + 2, "nothing from inside the battleground")
before = qw({ sender = A })
BUS.tick(80)
assert(qw({ sender = A }) == before, "no resend inside the battleground")
assert(C(A, "NS.GuildQueue.Shown()") == false, "the window is closed inside")
C(A, "NS.GuildQueue.Toggle()")
assert(C(A, "NS.GuildQueue.Shown()") == false, "not even by the command")
-- a QW waiting in Comm's queue goes on entering a battleground
C(A, [[STUB.instance = { name = "Black Temple", type = "raid", id = 564 }; STUB.battlefield = false; STUB.queues = {}
       STUB.fire("PLAYER_ENTERING_WORLD")]])
BUS.tick(3)
assert(lastQW(A) == "1QW\t1", "back outside, the empty state once: " .. tostring(lastQW(A)))
before = qw({ sender = A })
BUS.lock(true)
queue(A, 2, "queued", "Arathi Basin")
BUS.tick(3)
assert(C(A, "NS.CommQueueSize()") == 0 and qw({ sender = A }) == before, "the lockdown: nothing goes, nothing waits")
C(A, [[STUB.instance = { name = "Arathi Basin", type = "pvp", id = 529 }; STUB.fire("PLAYER_ENTERING_WORLD")]])
BUS.lock(false)
BUS.tick(15)
assert(qw({ sender = A }) == before, "nothing after the lockdown inside a battleground")
C(A, [[assert(NS.CommSend("QW", { "1", "3:W:5" }, "GUILD", nil, { key = "QW", ttl = 60 }))]])
assert(C(A, "NS.CommQueueSize()") == 1)
C(A, [[STUB.fire("PLAYER_ENTERING_WORLD")]])
assert(C(A, "NS.CommQueueSize()") == 0, "a waiting QW is dropped on entering a battleground")
C(A, [[STUB.instance = { name = "Black Temple", type = "raid", id = 564 }; STUB.queues = {}; STUB.fire("PLAYER_ENTERING_WORLD")]])
BUS.tick(12)

---------------------------------------------------------------------------
-- a decline: Abgelehnt for 5 s; the sound when a member starts waiting for the own battleground
---------------------------------------------------------------------------
queue(Li, 1, "queued", "Kriegshymnenschlucht")
BUS.tick(3)
assert(C(V, "#STUB.sounds") == 1, "Lia starts waiting for Vulo's battleground: one sound")
C(Li, "STUB.queues[1].status = 'confirm'; STUB.queues[1].expire = 0; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
BUS.tick(2)
assert(lastQW(Li) == "1QW\t1\t2:P:0" and rowOf(V, Li).right == "|cff4fbf7aAufgegangen|r")
-- popped first, before Ann's join would be (gone) and nobody waits longer
assert(rows(V)[2].name == Li, "popped first")
C(Li, "AcceptBattlefieldPort(1, false); STUB.queues[1] = nil; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
BUS.deliver()
assert(lastQW(Li) == "1QW\t1\t2:L:0", tostring(lastQW(Li)))
assert(rowOf(V, Li).right == "|cff8f86a3Abgelehnt|r")
BUS.tick(6)
assert(rowOf(V, Li) == nil, "gone 5 s after the decline")
-- a popped queue that runs out without a click counts as declined too
queue(Li, 1, "queued", "Kriegshymnenschlucht")
BUS.tick(12)
C(Li, "STUB.queues[1].status = 'confirm'; STUB.queues[1].expire = 20; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
BUS.tick(2)
C(Li, "STUB.queues[1] = nil; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
BUS.tick(2)
assert(lastQW(Li) == "1QW\t1\t2:L:0", "run out: declined " .. tostring(lastQW(Li)))

---------------------------------------------------------------------------
-- share off: one empty QW, the others drop Vulo, Vulo still sees them
---------------------------------------------------------------------------
queue(Li, 1, "queued", "Kriegshymnenschlucht")
BUS.tick(12)
assert(rowOf(V, Li) ~= nil)
before = qw({ sender = V })
C(V, "NS.Set('bgqueue.share', false)")
BUS.tick(12)
assert(qw({ sender = V }) == before + 1 and lastQW(V) == "1QW\t1", "one empty QW: " .. tostring(lastQW(V)))
assert(C(Li, "NS.GuildQueue.Get('" .. V .. "')") == nil and C(K, "NS.GuildQueue.Get('" .. V .. "')") == nil, "the others drop Vulo")
BUS.tick(160)
assert(qw({ sender = V }) == before + 1, "nothing more while share is off")
assert(rowOf(V, Li) ~= nil, "Vulo still sees Lia")
C(V, "NS.Set('bgqueue.share', true)")
BUS.tick(12)
assert(C(Li, "NS.GuildQueue.Get('" .. V .. "')") ~= nil, "back on: Vulo is seen again")

---------------------------------------------------------------------------
-- leaving the queue: the empty QW, the window closes, the others drop Vulo
---------------------------------------------------------------------------
C(V, "NS.GuildQueue.Toggle()")
assert(C(V, "NS.GuildQueue.Shown()") == true, "the command opens it")
leave(V, 1)
assert(C(V, "NS.GuildQueue.Shown()") == true, "opened by the command: stays")
C(V, "NS.GuildQueue.Toggle()")
assert(C(V, "NS.GuildQueue.Shown()") == false)
queue(V, 1, "queued", "Kriegshymnenschlucht")
assert(C(V, "NS.GuildQueue.Shown()") == true, "a new queue opens it again")
BUS.tick(12)
leave(V, 1)
assert(C(V, "NS.GuildQueue.Shown()") == false, "leaving the queue closes the window")
BUS.tick(12)
assert(lastQW(V) == "1QW\t1", "the empty state: " .. tostring(lastQW(V)))
assert(C(K, "NS.GuildQueue.Get('" .. V .. "')") == nil, "Kim drops Vulo")
-- view only without an own queue
C(V, "NS.GuildQueue.Toggle()")
assert(C(V, "NS.GuildQueue.Shown()") == true)
r = rows(V)
assert(r[1].kind == "bar" and not r[1].mine, "no own bar")
C(V, "NS.GuildQueue.Toggle()")

---------------------------------------------------------------------------
-- trust: Pug (outside the guild), the whisper channel, bad fields, the gaps
---------------------------------------------------------------------------
queue(P, 1, "queued", "Kriegshymnenschlucht")
BUS.tick(3)
assert(qw({ sender = P }) >= 1, "Pug sends")
assert(C(K, "NS.GuildQueue.Get('Pug')") == nil, "a sender outside the guild is ignored")
local bad = {
    "1QW",                                   -- no version
    "1QW\t2\t2:W:5",                         -- another version
    "1QW\t1\t0:W:5",                         -- id 0
    "1QW\t1\t100000:W:5",                    -- id too large
    "1QW\t1\t2:X:5",                         -- state
    "1QW\t1\t2:W:86401",                     -- waited too long
    "1QW\t1\t2:P:601",                       -- port too long
    "1QW\t1\t2:J:3",                         -- joined with seconds
    "1QW\t1\t2:W:5\t2:P:3",                  -- the same battleground twice
    "1QW\t1\t2:W",                           -- no seconds
    "1QW\t1\t1:W:1\t2:W:1\t3:W:1\t4:W:1\t5:W:1\t6:W:1\t7:W:1", -- 7 entries
}
for _, text in ipairs(bad) do
    C(K, ("STUB.fire('CHAT_MSG_ADDON', 'Amisia', %q, 'GUILD', 'Anna Berg')"):format(text))
end
BUS.tick(1)
assert(C(K, "NS.GuildQueue.Get('Anna Berg')") == nil, "every bad field drops the message")
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:W:30", "WHISPER", "Anna Berg")]])
BUS.tick(1)
assert(C(K, "NS.GuildQueue.Get('Anna Berg')") == nil, "only by GUILD")
BUS.tick(11)
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:W:30\t3:W:20", "GUILD", "Anna Berg")
       STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:W:31", "GUILD", "Anna Berg")]])
BUS.tick(1)
local anna = C(K, "NS.GuildQueue.Get('Anna Berg')")
assert(anna and anna.entries[2].sec == 30 and anna.entries[3], "a second plain QW within 10 s is dropped")
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:P:40\t3:W:21", "GUILD", "Anna Berg")]])
BUS.tick(0.5)
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:J:0\t3:W:22", "GUILD", "Anna Berg")]])
assert(C(K, "NS.GuildQueue.Get('Anna Berg').entries[2].s") == "P", "a pop goes at once, a join within 1 s of it is dropped")
BUS.tick(1)
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:J:0\t3:W:22", "GUILD", "Anna Berg")]])
assert(C(K, "NS.GuildQueue.Get('Anna Berg').entries[2].s") == "J", "a join 1 s after the pop")
-- at most 3 waiting and 2 popped per player
BUS.tick(11)
C(K, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t1:W:1\t2:W:1\t3:W:1\t4:W:1\t5:P:9\t6:P:9", "GUILD", "Anna Berg")]])
BUS.tick(0.1)
local n = C(K, "local n = 0; for _ in pairs(NS.GuildQueue.Get('Anna Berg').entries) do n = n + 1 end; return n")
assert(n == 5, "three waiting and two popped: " .. tostring(n))

---------------------------------------------------------------------------
-- 180 s without a QW, the offline line
---------------------------------------------------------------------------
assert(C(V, "NS.GuildQueue.Get('" .. K .. "')") ~= nil and C(V, "NS.GuildQueue.Get('" .. Li .. "')") ~= nil)
C(V, [[STUB.fire("CHAT_MSG_SYSTEM", "|Hplayer:Kim Eisherz|h[Kim Eisherz]|h ist jetzt offline.")]])
assert(C(V, "NS.GuildQueue.Get('" .. K .. "')") == nil, "the offline line drops Kim")
C(K, "STUB.queues = {}; STUB.fire('UPDATE_BATTLEFIELD_STATUS')")
BUS.drop(function(m) return m.kind == "QW" and m.sender == "Lia Weide" end)
BUS.tick(181)
assert(C(V, "NS.GuildQueue.Get('" .. Li .. "')") == nil, "Lia without a QW for 180 s is gone")
BUS.drop(nil)

-- at most 60 members in memory
C(V, [[for i = 1, 70 do
        local n = "Mitglied" .. string.char(64 + math.floor((i - 1) / 26) + 1) .. string.char(96 + (i - 1) % 26 + 1)
        STUB.guild[#STUB.guild + 1] = { name = n, rank = 4, online = true, class = "MAGE" }
    end
    STUB.fire("GUILD_ROSTER_UPDATE")
    for i = 1, 70 do
        local n = "Mitglied" .. string.char(64 + math.floor((i - 1) / 26) + 1) .. string.char(96 + (i - 1) % 26 + 1)
        STUB.fire("CHAT_MSG_ADDON", "Amisia", "1QW\t1\t2:W:" .. i, "GUILD", n)
    end]])
BUS.tick(2)
local count = C(V, "NS.GuildQueue.Count()")
assert(count == 60, "at most 60: " .. tostring(count))
print("guild queue ok")
