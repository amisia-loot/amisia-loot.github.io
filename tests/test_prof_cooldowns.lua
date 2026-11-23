-- Profession cooldowns (F-232, D-163, Gear/ProfCooldowns.lua): the data's "category:hours" read without the
-- profession data; a reading of the client becomes a ready-from epoch; recipes of one category are one line,
-- under 20 hours none; the own characters of this realm and faction; the login line; the message PC (its
-- fields, every bound on both sides, a bad field drops the whole message, names outside the roster dropped, a
-- character's own report first); the load check (7 days, 300 names, only spells of the data); the item tooltip.
local PC = NS.ProfCooldowns
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.guild = { { name = "Vulo Sturmwind", rank = 1, online = true }, { name = "Vulo Zweit", rank = 4 },
    { name = "Anna Amboss", rank = 3, online = true, class = "MAGE" }, { name = "Bob Hammer", rank = 3, online = false },
    { name = "Cleo Kessel", rank = 3, online = true } }
STUB.fire("GUILD_ROSTER_UPDATE")
_G.GetRealmName = function() return "Kargath" end
STUB.instance = { name = "Durotar", type = "none", id = 0 }

-- the fixture's recipes as cooldown recipes: 3321 and 1252229 share category 310 (47 and 23 hours), 2330 a
-- recipe of its own (95 hours), 2663 one hour (never shown)
NS.PROF_COOLDOWNS = { [3321] = "310:47", [1252229] = "310:23", [2330] = "0:95", [2663] = "0:1", [9999] = "310:0" }
local CD = {}          -- [spell] = { startTime, duration }
local playerSpells = {}
_G.C_Spell.GetSpellCooldown = function(id)
    local c = CD[id]
    if not c then return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end
    return { startTime = c[1], duration = c[2], isEnabled = true, modRate = 1 }
end
_G.IsPlayerSpell = function(id) return playerSpells[id] == true end

---------------------------------------------------------------------------
-- the data: category and hours, the 20 hour threshold, one line per category
---------------------------------------------------------------------------
local c, h = PC.Info(3321)
assert(c == 310 and h == 47)
assert(PC.Info(4242) == nil, "no cooldown")
assert(PC.Group(3321) == "c310" and PC.Group(1252229) == "c310", "the transmutes are one line")
assert(PC.Group(2330) == "s2330", "a recipe without a category is a line of its own")
assert(PC.Group(2663) == nil and PC.Group(9999) == nil, "one hour, ten minutes: under 20 hours")
assert(PC.Label(3321) == "Transmutation", "category 310 from the locale")
assert(PC.Label(2330) == "Schwacher Heiltrank", "else the recipe's name from the client")
assert(not NS.DataLoaded("PROFESSIONS") or true)

---------------------------------------------------------------------------
-- reading: the client's remaining time -> epoch; one spell per line; nothing unknown
---------------------------------------------------------------------------
STUB.tick(5000)   -- GetTime as a running client has it (a start of 0 means no cooldown)
local D = NS.DropsToday()
AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [171] = { rank = 300, max = 300, day = D, known = { [2330] = true } } } } }
playerSpells[3321], playerSpells[1252229], playerSpells[2663] = true, true, true
CD[3321] = { STUB.clock - 3600, 47 * 3600 }       -- crafted an hour ago: 46 hours left
CD[1252229] = { STUB.clock - 3600, 47 * 3600 }    -- the category's cooldown on every transmute
local t0 = time()
assert(PC.ReadOwn() == true, "the first reading changes")
local e = AmisiaDB.prof.cd["Vulo Sturmwind"]
assert(e.realm == "Kargath" and e.faction == "A")
assert(e[1252229] == nil and e[3321] == t0 + 46 * 3600, "the first known of the line, the epoch from the remaining time")
assert(e[2330] == t0, "ready: now")
assert(e[2663] == nil, "under 20 hours: not kept")
assert(PC.ReadOwn() == false, "the same again: no change")
-- the craft of another transmute: that recipe becomes the line's recipe
CD[3321] = { STUB.clock, 23 * 3600 }
CD[1252229] = { STUB.clock, 23 * 3600 }
assert(PC.ReadOwn(1252229) == true)
assert(e[1252229] == t0 + 23 * 3600 and e[3321] == nil, "the crafted recipe names the line")
assert(PC.ReadOwn() == false, "the next reading keeps the crafted one")
-- a client without any answer: the data's hours after crafting, the last state otherwise
local keep = _G.C_Spell.GetSpellCooldown
_G.C_Spell.GetSpellCooldown = nil
local keepOld = _G.GetSpellCooldown
_G.GetSpellCooldown = nil
assert(PC.Remaining(2330) == nil, "nothing to say")
STUB.tick(600)
PC.ReadOwn(2330)
assert(e[2330] == time() + 95 * 3600, "crafted without an answer: 95 hours from the data")
local before = e[1252229]
PC.ReadOwn()
assert(e[1252229] == before, "no answer keeps the last reading")
_G.C_Spell.GetSpellCooldown, _G.GetSpellCooldown = keep, keepOld
-- a cast of the player (never another unit) reads half a second later and names the line
CD[3321] = { STUB.clock, 47 * 3600 }
CD[1252229] = { STUB.clock, 47 * 3600 }
STUB.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-1", 3321)
STUB.tick(1)
assert(e[3321] == nil, "another unit's cast")
STUB.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 3321)
STUB.tick(1)
assert(e[3321] and e[3321] > time() + 46 * 3600, "the cast names the line")
assert(e[1252229] == nil)
-- the global cooldown is no cooldown
CD[2330] = { STUB.clock, 1.5 }
assert(PC.Remaining(2330) == 0)
CD[2330] = nil
-- unlearned: the client says no and no reading lists it
playerSpells[3321], playerSpells[1252229] = false, false
PC.ReadOwn()
assert(e[3321] == nil and e[1252229] == nil, "the transmute line went")
assert(e[2330] ~= nil, "a recipe of the window's reading stays")
playerSpells[3321], playerSpells[1252229] = true, true
CD[3321] = { STUB.clock - 3600, 47 * 3600 }
PC.ReadOwn()
assert(e[3321] ~= nil or e[1252229] ~= nil)

---------------------------------------------------------------------------
-- own characters: same realm and faction; the login line
---------------------------------------------------------------------------
AmisiaDB.prof.cd["Vulo Zweit"] = { realm = "Kargath", faction = "A", [2330] = time() - 60 }
AmisiaDB.prof.cd["Vulo Fern"] = { realm = "Andere", faction = "A", [2330] = time() - 60 }
AmisiaDB.prof.cd["Vulo Horde"] = { realm = "Kargath", faction = "H", [2330] = time() - 60 }
local own = PC.Own()
assert(#own == 2 and own[1].name == "Vulo Sturmwind" and own[1].current and own[2].name == "Vulo Zweit", "other realm and faction left out")
assert(#own[1].lines == 2 and own[1].lines[1].label == "Schwacher Heiltrank" and own[1].lines[2].label == "Transmutation")
local line = PC.LoginLine()
assert(line == "bereit: Schwacher Heiltrank (Vulo Sturmwind), Schwacher Heiltrank (Vulo Zweit).", tostring(line))
assert(has(PC.TimeText(time() + 14 * 3600 + 20 * 60), "in 14 Std. 20 Min."))
assert(has(PC.TimeText(time() + 59), "in 1 Min."))
assert(has(PC.TimeText(time() - 5), "bereit"))
-- the login line: once, after the first entering of the world, not with the setting off
local said = 0
local msg = NS.msg
NS.msg = function(text) if has(text, "bereit:") then said = said + 1 end end
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(PC.LIM.loginLine + 1)
assert(said == 1, "the login line")
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(PC.LIM.loginLine + 1)
assert(said == 1, "once per session")
NS.msg = msg

---------------------------------------------------------------------------
-- the message PC: its fields from the own characters of this guild
---------------------------------------------------------------------------
AmisiaDB.account = { v = 1, chars = {
    ["Vulo Sturmwind"] = { class = "WARRIOR", level = 60, guild = "Amisia", at = time() },
    ["Vulo Zweit"] = { class = "PRIEST", level = 40, guild = "Amisia", at = time() },
    ["Vulo Fern"] = { class = "MAGE", level = 60, guild = "Andere", at = time() },
} }
local f = PC.Fields()
assert(f[1] == "1" and #f == 3, table.concat(f or {}, " | "))
assert(f[2]:match("^Vulo Sturmwind:2330=0,3321=%d+$"), f[2])
assert(f[3] == "Vulo Zweit:2330=0", f[3])
-- the first PC 60 to 180 s after entering the world, once, low and to the guild
STUB.addon = {}
STUB.tick(PC.LIM.firstMin + PC.LIM.firstSpread + PC.LIM.tick + 1)
local sent = {}
for _, m in ipairs(STUB.addon) do if m.text:sub(1, 3) == "1PC" then sent[#sent + 1] = m end end
assert(#sent == 1 and sent[1].chan == "GUILD", "one PC: " .. #sent)
-- a change: again, at most once a minute
CD[2330] = { STUB.clock, 95 * 3600 }
PC.ReadOwn(2330)
STUB.tick(PC.LIM.changeGap + PC.LIM.tick + 1)
sent = 0
for _, m in ipairs(STUB.addon) do if m.text:sub(1, 3) == "1PC" then sent = sent + 1 end end
assert(sent == 2, "after the change: " .. sent)
-- sharing off: nothing
NS.Set("prof.cdShare", false)
CD[2330] = nil
STUB.tick(61)
PC.ReadOwn()
STUB.tick(120)
sent = 0
for _, m in ipairs(STUB.addon) do if m.text:sub(1, 3) == "1PC" then sent = sent + 1 end end
assert(sent == 2, "sharing off: no PC")
NS.Set("prof.cdShare", true)
local function pcCount()
    local n = 0
    for _, m in ipairs(STUB.addon) do if m.text:sub(1, 3) == "1PC" then n = n + 1 end end
    return n
end
STUB.tick(PC.LIM.changeGap + PC.LIM.tick + 1)
assert(pcCount() == 3, "on again: the waiting change goes")
-- inside an instance nothing goes; 5 to 15 s after the way out it does
STUB.instance = { name = "Höhlen", type = "party", id = 1 }
STUB.fire("PLAYER_ENTERING_WORLD")
CD[2330] = { STUB.clock, 95 * 3600 }
PC.ReadOwn(2330)
STUB.tick(200)
assert(pcCount() == 3, "nothing inside")
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(PC.LIM.outWait - 1)
assert(pcCount() == 3, "not at once after the way out")
STUB.tick(PC.LIM.outSpread + PC.LIM.tick + 2)
assert(pcCount() == 4, "5 to 15 s after it")

---------------------------------------------------------------------------
-- receiving: every bound, the roster, the own report first
---------------------------------------------------------------------------
local function recv(sender, ...)
    STUB.tick(61)   -- the gap per sender
    local text = "1PC\t" .. table.concat({ ... }, "\t")
    STUB.fire("CHAT_MSG_ADDON", "Amisia", text, "GUILD", sender, "", 0, 0, "", 0)
    STUB.tick(1)
end
local function heard(name) return AmisiaDB.prof.cdHeard and AmisiaDB.prof.cdHeard[name] end
recv("Anna Amboss", "1", "Anna Amboss:3321=0,2330=3600", "Bob Hammer:1252229=7200")
local a = heard("Anna Amboss")
assert(a and a.by == "Anna Amboss" and a[3321] == a.at and a[2330] == a.at + 3600, "Anna's own report")
assert(heard("Bob Hammer")[1252229] == heard("Bob Hammer").at + 7200 and heard("Bob Hammer").by == "Anna Amboss")
-- the whole message goes for: a spell outside the data, one under 20 hours, 400001 s, 5 lines, a line twice,
-- 11 characters, a digit in a name, another first field
local function bad(...)
    local was = heard("Cleo Kessel")
    recv("Cleo Kessel", "1", "Cleo Kessel:2330=5", ...)
    assert(heard("Cleo Kessel") == was, table.concat({ ... }, " | "))
end
bad("Bob Hammer:4242=0")
bad("Bob Hammer:2663=0")
bad("Bob Hammer:2330=400001")
bad("Bob Hammer:2330=1,3321=1,2330=2")
bad("Bob Hammer:2330=1,2330=2,2330=3,2330=4,2330=5")
bad("Bob Hammer:3321=1,1252229=2")
bad("Bob Hammer:2330=-1")
bad("Bob2 Hammer:2330=1")
bad("Bob Hammer:")
local eleven = {}
for i = 1, 10 do eleven[i] = "Bob Hammer:2330=" .. i end
bad(unpack(eleven))
recv("Cleo Kessel", "2", "Cleo Kessel:2330=5")
assert(heard("Cleo Kessel") == nil, "another version field")
-- the edges: 0 and 400000 s are fine; a name outside the roster is dropped alone
recv("Cleo Kessel", "1", "Cleo Kessel:2330=400000", "Fremder Mann:2330=0")
assert(heard("Cleo Kessel")[2330] == heard("Cleo Kessel").at + 400000)
assert(heard("Fremder Mann") == nil, "not in the roster")
-- not from the guild, not by whisper
recv("Fremder Mann", "1", "Fremder Mann:2330=0")
assert(heard("Fremder Mann") == nil)
STUB.tick(61)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1PC\t1\tCleo Kessel:2330=7", "WHISPER", "Cleo Kessel", "", 0, 0, "", 0)
STUB.tick(1)
assert(heard("Cleo Kessel")[2330] == heard("Cleo Kessel").at + 400000, "whisper ignored")
-- Bob's own report replaces Anna's word; Anna's word does not replace Bob's own
recv("Bob Hammer", "1", "Bob Hammer:2330=100000")
assert(heard("Bob Hammer").by == "Bob Hammer" and heard("Bob Hammer")[1252229] == nil)
recv("Anna Amboss", "1", "Anna Amboss:3321=0", "Bob Hammer:2330=999")
assert(heard("Bob Hammer").by == "Bob Hammer" and heard("Bob Hammer")[2330] == heard("Bob Hammer").at + 100000, "the own report first")
-- an own character is never taken from another
recv("Anna Amboss", "1", "Vulo Zweit:2330=50")
assert(heard("Vulo Zweit") == nil, "own characters stay ours")
-- the gap: a second PC within 60 s is not handled
STUB.tick(61)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1PC\t1\tCleo Kessel:2330=50000", "GUILD", "Cleo Kessel", "", 0, 0, "", 0)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1PC\t1\tCleo Kessel:2330=60000", "GUILD", "Cleo Kessel", "", 0, 0, "", 0)
STUB.tick(1)
assert(heard("Cleo Kessel")[2330] == heard("Cleo Kessel").at + 50000, "one per 60 s")

---------------------------------------------------------------------------
-- the guild's lines: ready first, then online, then time left; the tooltip
---------------------------------------------------------------------------
recv("Anna Amboss", "1", "Anna Amboss:3321=0,2330=0")
local g = PC.Guild()
local heal
for _, l in ipairs(g) do if l.group == "s2330" then heal = l end end
assert(heal and #heal.rows == 3, "Anna, Bob, Cleo")
assert(heal.rows[1].name == "Anna Amboss" and heal.rows[1].online and heal.rows[1].class == "MAGE", "ready first")
assert(heal.rows[2].name == "Cleo Kessel" and heal.rows[3].name == "Bob Hammer", "then online first")
-- the tooltip: the item a ready recipe makes (the profession data built: out of combat)
local tip = PC.TooltipLine(118)
assert(tip == "Bereit in der Gilde: Anna Amboss", tostring(tip))
assert(PC.TooltipLine(3471) == "Bereit in der Gilde: Anna Amboss", "Arcanite's line: the transmute")
assert(PC.TooltipLine(2853) == nil, "a recipe under 20 hours")
assert(PC.TooltipLine(4242) == nil)
-- a member who left: out of the lines
for i = #STUB.guild, 1, -1 do if STUB.guild[i].name == "Anna Amboss" then table.remove(STUB.guild, i) end end
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(1)
for _, l in ipairs(PC.Guild()) do
    for _, r in ipairs(l.rows) do assert(r.name ~= "Anna Amboss", "left the guild") end
end

---------------------------------------------------------------------------
-- the load check: 7 days, 300 names, only spells of the data, bad values
---------------------------------------------------------------------------
local now = time()
local db = { prof = {
    cd = { ["Vulo Sturmwind"] = { realm = "Kargath", faction = "A", [2330] = now, [2663] = now, [4242] = now, x = 1 },
           ["Bad|Name"] = { [2330] = now }, ["Vulo Leer"] = { realm = "Kargath", [2663] = now },
           ["Vulo Komisch"] = { realm = "Ka\nrgath", faction = "X", [3321] = 1.5, [1252229] = now } },
    cdHeard = { ["Alt Name"] = { by = "Alt Name", at = now - 8 * 86400, [2330] = now },
                ["Neu Name"] = { by = "Neu Name", at = now - 86400, [2330] = now, [4242] = now, junk = true },
                ["Ohne Sender"] = { at = now, [2330] = now },
                ["Doppel Name"] = { by = "Doppel Name", at = now, [3321] = now, [1252229] = now } },
} }
for i = 1, 305 do db.prof.cdHeard["Viele Name" .. string.char(97 + i % 26) .. string.char(97 + math.floor(i / 26))] = { by = "Neu Name", at = now - 100000 - i, [2330] = now } end
NS.ProfCooldownsLoaded(db)
local cd, hd = db.prof.cd, db.prof.cdHeard
assert(cd["Vulo Sturmwind"][2330] == now and cd["Vulo Sturmwind"][2663] == nil and cd["Vulo Sturmwind"][4242] == nil
    and cd["Vulo Sturmwind"].x == nil, "only spells of the data from 20 hours on")
assert(cd["Bad|Name"] == nil and cd["Vulo Leer"] == nil, "a bad name, an entry without a line")
assert(cd["Vulo Komisch"].realm == nil and cd["Vulo Komisch"].faction == nil and cd["Vulo Komisch"][3321] == nil
    and cd["Vulo Komisch"][1252229] == now, "bad realm, faction and epoch dropped")
assert(hd["Alt Name"] == nil, "older than 7 days")
assert(hd["Neu Name"][2330] == now and hd["Neu Name"][4242] == nil and hd["Neu Name"].junk == nil)
assert(hd["Ohne Sender"] == nil, "without a sender")
local n, lines = 0, 0
for _, v in pairs(hd) do
    n = n + 1
end
assert(n == 300, "300 names at most: " .. n)
for k, v in pairs(hd["Doppel Name"] or {}) do if type(k) == "number" then lines = lines + 1 end end
assert(hd["Doppel Name"] == nil or lines == 1, "one spell per line")
local odd = { prof = { cd = "x", cdHeard = 5 } }
NS.ProfCooldownsLoaded(odd)
assert(odd.prof.cd == nil and odd.prof.cdHeard == nil)
