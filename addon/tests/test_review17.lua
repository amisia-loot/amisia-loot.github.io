-- Review of 1.7 (raid log, bench, Discord text): mentions in the Discord text, no loot window kill
-- after encounter events, long list lines wrapped instead of cut, no part of headings only, secret
-- values never compared, a kill kept when the roster read fails, the bench capped at 40, !bench aus
-- with the guild check and the exact name.
local failed = {}
local function check(label, fn)
    local ok, err = pcall(fn)
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(err) end
end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function chars(text) local n = 0; for _ in text:gmatch("[^\128-\191]") do n = n + 1 end return n end
local function lines(text)
    local out = {}
    for l in (text .. "\n"):gmatch("(.-)\n") do out[#out + 1] = l end
    return out
end
local function last() return STUB.chat[#STUB.chat] end
local ZWSP = "\226\128\139"

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.guild = { { name = "Vuloo", class = "PRIEST" }, { name = "Chorf", class = "WARRIOR" }, { name = "Kim", class = "MAGE" },
    { name = "Kim Eisherz", class = "MAGE" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = assert(NS.Active())

---------------------------------------------------------------------------
-- 1. mentions never reach the Discord text from what raiders type
---------------------------------------------------------------------------
check("1 mentions", function()
    STUB.fire("CHAT_MSG_WHISPER", "!bench @everyone <@&123456>", "Chorf")
    STUB.tick(20)
    assert(s.bench.Chorf and s.bench.Chorf.note == "@everyone <@&123456>", tostring(s.bench.Chorf and s.bench.Chorf.note))
    local parts = NS.RaidSummary(s)
    local text = table.concat(parts, "\n")
    assert(not has(text, "@everyone") and not text:find("[^\\]<"), text)
    assert(has(text, "**Ersatzbank:** Chorf (@" .. ZWSP .. "everyone \\<@" .. ZWSP .. "&123456\\>)"), text)
    local esc = NS.DiscordEscape
    assert(esc("@here") == "@" .. ZWSP .. "here", esc("@here"))
    assert(esc("<#42>") == "\\<\\#42\\>", esc("<#42>"))
    assert(esc("<@!7>") == "\\<@" .. ZWSP .. "!7\\>", esc("<@!7>"))
    assert(esc("Naj'entus - (1)") == "Naj'entus - (1)", "other characters stay")
    -- names, zone, items: all through the same escape
    STUB.item(39001, "Klinge @here", 4)
    local x = { id = "x1", date = "2026-10-02", zone = "@everyone Zone", start = time(), last = time(),
        members = { ["@here"] = { class = "MAGE", first = time(), last = time(), late = true } }, loot = {}, items = {},
        drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    NS.AddAwardTo(x, { name = "@here", item = 39001, kind = "MS", src = "@everyone", t = time() })
    NS.Set("raidlog.discordNames", true)
    text = table.concat(NS.RaidSummary(x), "\n")
    NS.Reset("raidlog.discordNames")
    assert(not has(text, "@everyone") and not has(text, "@here"), text)
    -- the officer's own head line stays as typed
    NS.Set("raidlog.discordHead", "Raid <@&99> @here")
    text = NS.RaidSummary(x)[1]
    NS.Reset("raidlog.discordHead")
    assert(lines(text)[1] == "Raid <@&99> @here", lines(text)[1])
    NS.BenchRemove(s, "Chorf")
end)

---------------------------------------------------------------------------
-- 4. no loot window kill in a recording that saw encounter events
---------------------------------------------------------------------------
check("4 loot window after encounter events", function()
    STUB.fire("ENCOUNTER_START", 618, "Eredar Twins", 4, 25)
    STUB.tick(200)
    STUB.fire("ENCOUNTER_END", 618, "Eredar Twins", 4, 25, 1)
    STUB.tick(660)
    local boss = "Creature-0-1-1-1-25165-9"
    STUB.target, STUB.targetGUID, STUB.targetDead, STUB.targetClass = "Lady Sacrolash", boss, true, "worldboss"
    STUB.loot = { { link = STUB.item(34000, "Robe", 4), src = boss } }
    STUB.fire("LOOT_OPENED")
    local kills = NS.Kills(s)
    assert(#kills == 1 and kills[1].name == "Eredar Twins", "one kill: " .. #kills)
    -- even a start alone (a wipe without its end) is enough
    STUB.instance = { name = "Shattrath", type = "none", id = 0 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    STUB.instance = { name = "Sunwell Plateau", type = "raid", id = 580 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    local s2 = assert(NS.Active())
    assert(s2 ~= s, "a new recording")
    STUB.fire("ENCOUNTER_START", 724, "Kalecgos", 4, 25)
    STUB.tick(900)
    local boss2 = "Creature-0-1-1-1-24850-1"
    STUB.targetGUID = boss2
    STUB.target = "Sathrovarr"
    STUB.loot = { { link = STUB.item(34001, "Ring", 4), src = boss2 } }
    STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED")
    assert(#NS.Kills(s2) == 0, "no loot window kill after a start")
    -- a recording without any encounter event still takes the loot window
    STUB.instance = { name = "Shattrath", type = "none", id = 0 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    STUB.instance = { name = "Hyjal", type = "raid", id = 534 }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
    local s3 = assert(NS.Active())
    assert(s3 ~= s and s3 ~= s2 and not s3.encSeen, "a fresh recording")
    local boss3 = "Creature-0-1-1-1-22947-1"
    STUB.targetGUID, STUB.target = boss3, "Mutter Shahraz"
    STUB.loot = { { link = STUB.item(34002, "Kette", 4), src = boss3 } }
    STUB.tick(5)
    STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED")
    assert(#NS.Kills(s3) == 1 and NS.Kills(s3)[1].src == "loot", "the fallback without events")
    STUB.target, STUB.targetGUID, STUB.targetDead, STUB.targetClass, STUB.loot = nil, nil, nil, nil, {}
    STUB.fire("LOOT_CLOSED")
    s = s3
end)

check("4 a recording from before the mark", function()
    local o = { id = "20260901200000-564", date = "2026-09-01", zone = "Black Temple", instanceID = 564, start = 1000, last = 5000,
        members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, bench = {}, outside = {},
        kills = { { enc = 601, name = "Naj'entus", start = 1000, t = 1200, ok = true, src = "enc", who = {}, n = 0 } } }
    local h = { id = "20260902200000-564", date = "2026-09-02", zone = "Black Temple", instanceID = 564, start = 1000, last = 5000,
        members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, bench = {}, outside = {},
        kills = { { enc = 0, name = "Gruul", start = 1000, t = 1200, ok = true, src = "hand", who = {}, n = 0 } } }
    table.insert(AmisiaDB.sessions, 1, o)
    table.insert(AmisiaDB.sessions, 2, h)
    NS.RaidLogLoaded()
    assert(o.encSeen == true and not h.encSeen, "marked from its encounter kills on load")
    table.remove(AmisiaDB.sessions, 2)
    table.remove(AmisiaDB.sessions, 1)
end)

---------------------------------------------------------------------------
-- 5. a line longer than a part is wrapped at items; no part of headings only
---------------------------------------------------------------------------
local function heading(l)
    return l == "" or l:match("^%*%*[^*]+%*%*$") ~= nil or l:match("^__.*__") ~= nil and not l:find("^%- ")
end
local function checkParts(parts, label)
    for i, p in ipairs(parts) do
        assert(chars(p) <= 1900, ("%s: part %d has %d characters"):format(label, i, chars(p)))
        local body = false
        for _, l in ipairs(lines(p)) do if not heading(l) then body = true end end
        assert(body, ("%s: part %d holds headings only:\n%s"):format(label, i, p))
    end
end
check("5 wrapped lines", function()
    local r = { id = "x5", date = "2026-10-02", zone = "Schwarzer Tempel", start = time(), last = time(),
        members = { Vuloo = { class = "PRIEST", first = time(), last = time() } }, loot = {}, items = {},
        drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    for i = 1, 70 do
        STUB.item(40000 + i, "Umhang der Hochgeborenen Nummer " .. i, 4)
        r.awards[#r.awards + 1] = { id = "x" .. i, name = "-", item = 40000 + i, t = time() + i, kind = "-", to = "de", src = "?" }
    end
    local parts = NS.RaidSummary(r)
    checkParts(parts, "disenchant")
    local all = table.concat(parts, "\n")
    for i = 1, 70 do
        local n = 0
        for _ in all:gmatch("Nummer " .. i .. "%f[^%d]") do n = n + 1 end
        assert(n == 1, ("Nummer %d %d times"):format(i, n))
    end
    for _, l in ipairs(lines(all)) do
        if has(l, "Nummer") then assert(l:find("^Entzaubert: "), "every wrapped line keeps its head: " .. l) end
    end
    -- the bench and every name
    r.awards = {}
    for i = 1, 40 do
        local name = "Bankdrücker" .. string.char(96 + ((i - 1) % 26) + 1) .. string.char(96 + math.ceil(i / 26))
        r.bench[name] = { t = time(), class = "MAGE", by = "Vuloo", note = ("Notiz %02d "):format(i) .. ("x"):rep(31) }
        r.members["Raider" .. name] = { class = "MAGE", first = time(), last = time() }
    end
    NS.Set("raidlog.discordNames", true)
    parts = NS.RaidSummary(r)
    NS.Reset("raidlog.discordNames")
    checkParts(parts, "bench")
    all = table.concat(parts, "\n")
    for name in pairs(r.bench) do
        local n = 0
        for _ in all:gmatch("%f[%w]" .. name .. " %(") do n = n + 1 end
        assert(n == 1, name .. " on the bench " .. n .. " times")
        n = 0
        for _ in all:gmatch("Raider" .. name .. "%f[^%w]") do n = n + 1 end
        assert(n == 1, "Raider" .. name .. " " .. n .. " times")
    end
    local benchLines = 0
    for _, l in ipairs(lines(all)) do if l:find("^%*%*Ersatzbank:%*%* ") then benchLines = benchLines + 1 end end
    assert(benchLines >= 2, "the bench wrapped: " .. benchLines)
end)

---------------------------------------------------------------------------
-- 6. secret values: never compared; a failing roster read keeps the kill
---------------------------------------------------------------------------
check("6 no comparison of raw values", function()
    for _, file in ipairs({ "Raid/RaidLog.lua", "Core/Core.lua", "Raid/Bench.lua" }) do
        local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
        for _, v in ipairs({ "name", "zone", "online", "class" }) do
            assert(not src:find("%f[%w_]" .. v .. " [~=]= nil"), file .. ": " .. v .. " compared with nil")
        end
    end
end)
check("6 kill kept when the roster read fails", function()
    STUB.tick(700)   -- no loot window kill for the event to take over
    local before = #NS.Kills(s)
    STUB.fire("ENCOUNTER_START", 601, "Naj'entus", 4, 25)
    STUB.tick(100)
    local orig = _G.GetRaidRosterInfo
    _G.GetRaidRosterInfo = function() error("roster unreadable") end
    local ok = pcall(STUB.fire, "ENCOUNTER_END", 601, "Naj'entus", 4, 25, 1)
    _G.GetRaidRosterInfo = orig
    assert(ok, "no error out of the handler")
    local k = NS.Kills(s)[#NS.Kills(s)]
    assert(#NS.Kills(s) == before + 1 and k.enc == 601 and k.ok and k.src == "enc", "the kill is there")
    STUB.tick(70)
    assert(not k.wait and type(k.who) == "table", "names from the snapshots")
end)

---------------------------------------------------------------------------
-- 6. the bench: at most 40; !bench aus with the guild check and the exact name
---------------------------------------------------------------------------
check("6 bench cap", function()
    for k in pairs(s.bench) do s.bench[k] = nil end
    local b = {}
    for i = 1, 40 do
        local name = "Platz" .. string.char(96 + ((i - 1) % 26) + 1) .. string.char(96 + math.ceil(i / 26))
        b[#b + 1] = name
        assert(NS.BenchAdd(s, name, {}), name)
    end
    local e, why = NS.BenchAdd(s, "Einerzuviel", {})
    assert(e == nil and why == "Die Ersatzbank ist voll (40).", tostring(why))
    assert(NS.BenchAdd(s, b[1], { note = "neu" }), "an entry on the bench is still updated")
    STUB.tick(20)
    STUB.chat = {}
    STUB.fire("CHAT_MSG_WHISPER", "!bench", "Chorf")
    assert(last() and last().text == "Amisia: Die Ersatzbank ist voll." and not s.bench.Chorf, last() and last().text)
    for _, name in ipairs(b) do NS.BenchRemove(s, name) end
end)
check("6 !bench aus: guild", function()
    NS.Set("raidlog.benchGuildOnly", false)
    STUB.tick(20)
    STUB.fire("CHAT_MSG_WHISPER", "!bench", "Fremder")
    NS.Reset("raidlog.benchGuildOnly")
    assert(s.bench.Fremder and s.bench.Fremder.self, "entered while the setting was off")
    STUB.tick(20)
    STUB.chat = {}
    STUB.fire("CHAT_MSG_WHISPER", "!bench aus", "Fremder")
    assert(last() and last().text == "Amisia: Die Ersatzbank ist nur für Gildenmitglieder." and s.bench.Fremder, last() and last().text)
    NS.BenchRemove(s, "Fremder")
end)
check("6 !bench aus: exact name", function()
    STUB.tick(20)
    STUB.fire("CHAT_MSG_WHISPER", "!bench", "Kim Eisherz")
    assert(s.bench["Kim Eisherz"] and s.bench["Kim Eisherz"].self)
    STUB.tick(20)
    STUB.chat = {}
    STUB.fire("CHAT_MSG_WHISPER", "!bench aus", "Kim")
    assert(s.bench["Kim Eisherz"], "a first name does not remove a full name")
    assert(last() and last().text == "Amisia: Du stehst nicht auf der Ersatzbank.", last() and last().text)
    STUB.tick(20)
    STUB.fire("CHAT_MSG_WHISPER", "!bench aus", "kim eisherz")
    assert(not s.bench["Kim Eisherz"], "the full name, case aside")
end)

assert(#failed == 0, table.concat(failed, "\n"))
