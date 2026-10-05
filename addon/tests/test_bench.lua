-- The bench: entries per raid (s.bench) or for tonight before the raid (AmisiaDB.benchNext), taken
-- over by the night's first recording; never late when subbed in; suggestions from the group
-- outside, the guild and friends; !bench for raiders without the addon; ns.ReplyGate; /amisia ersatz.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local function last() return STUB.chat[#STUB.chat] end
local function lastMsg() return STUB.messages[#STUB.messages] end
local function ask(text, sender, event) STUB.fire(event or "CHAT_MSG_WHISPER", text, sender) end
local function later() STUB.tick(20) end
local function short(night) local y, m, d = night:match("^(%d+)-(%d+)-(%d+)$"); return d .. "." .. m .. "." end

STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil, "no recording in the city")

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
for _, key in ipairs({ "raidlog.benchChat", "raidlog.benchGuildOnly", "raidlog.benchNotify" }) do
    local it = NS.SettingItem(key)
    assert(it and it.type == "toggle" and it.default == true and it.officer and it.section.key == "raidlog", key)
end
assert(NS.SettingItem("raidlog.track"), "the section keeps its first items")
assert(NS.SettingItem("raidlog.benchChat").label == "Auf !bench antworten")

---------------------------------------------------------------------------
-- before the raid: AmisiaDB.benchNext for tonight
---------------------------------------------------------------------------
local night = NS.NightOf(time())
local b, label = NS.BenchTarget()
assert(b and b == AmisiaDB.benchNext and b.date == night and label == "heute, " .. short(night), tostring(label))
local e, why = NS.BenchAdd(b, "", {})
assert(e == nil and why == "Name fehlt.", tostring(why))
assert(NS.BenchAdd(b, nil) == nil)
assert(select(2, NS.BenchAdd(b, "Gast2")) == "Name fehlt.", "no digits in a character name")
e = NS.BenchAdd(b, "Kim Eisherz", { note = "ab 21 Uhr" })
assert(e and b.list["Kim Eisherz"] == e and e.by == "Vuloo" and not e.self and e.note == "ab 21 Uhr" and e.t == STUB.now and e.class == "")
-- an entry again is updated: the note changes, self stays, an officer is named
local e2 = NS.BenchAdd(b, "kim eisherz", { self = true, note = "später" })
assert(e2 == e and e.self and e.by == "Vuloo" and e.note == "später", "updated")
NS.BenchAdd(b, "Kim Eisherz", {})
assert(e.note == "später" and e.self, "no note keeps the note")
local long = NS.BenchAdd(b, "Lang", { note = ("x"):rep(70) .. "|\n" })
assert(#long.note == 40 and not has(long.note, "|"), #long.note)
assert(NS.BenchRemove(b, "lang") == true)
local ok, reason = NS.BenchRemove(b, "Lang")
assert(ok == nil and reason == "Lang steht nicht auf der Ersatzbank.", tostring(reason))
-- an old benchNext falls away on load and on the next write
AmisiaDB.benchNext = { date = "2020-01-01", list = { Alt = { t = 1, class = "" } } }
NS.BenchLoaded()
assert(AmisiaDB.benchNext == nil, "dropped on load")
local stale = { date = "2020-01-01", list = { Alt = { t = 1, class = "" } } }
AmisiaDB.benchNext = stale
local fresh = NS.BenchTarget()
assert(fresh ~= stale and fresh.date == night and next(fresh.list) == nil, "dropped on the next write")
NS.BenchAdd(fresh, "Kim Eisherz", { note = "ab 21 Uhr" })
NS.BenchAdd(fresh, "Vulo", {})

---------------------------------------------------------------------------
-- the first recording of the night takes benchNext over
---------------------------------------------------------------------------
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.bench["Kim Eisherz"] and s.bench["Kim Eisherz"].note == "ab 21 Uhr" and s.bench.Vulo, "taken over at the start")
assert(AmisiaDB.benchNext == nil, "and gone")
b, label = NS.BenchTarget()
assert(b == s and label == "Black Temple, " .. short(s.date), label)
-- resuming the recording takes it over as well
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil)
local nb = NS.BenchTarget()
NS.BenchAdd(nb, "Fred", { note = "Twink" })
assert(AmisiaDB.benchNext and AmisiaDB.benchNext.list.Fred)
STUB.tick(60)
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == s, "resumed")
assert(s.bench.Fred and s.bench.Fred.note == "Twink" and AmisiaDB.benchNext == nil, "taken over on resume")

---------------------------------------------------------------------------
-- in the raid: refused; subbed in: never late
---------------------------------------------------------------------------
e, why = NS.BenchAdd(s, "Fraktur", {})
assert(e == nil and why == "Fraktur ist im Raid.", tostring(why))
s.lateAt = s.start - 1   -- everyone new from here on would be late
STUB.tick(60)
STUB.roster[3] = { name = "Kim Eisherz", class = "MAGE" }
STUB.roster[4] = { name = "Neuling", class = "ROGUE" }
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)
local kim, neu = s.members["Kim Eisherz"], s.members.Neuling
assert(kim and kim.late == nil and kim.bench == true, "from the bench: not late")
assert(neu and neu.late == true and neu.bench == nil, "without a bench entry: late")
local list = NS.BenchList(s)
local names = {}
for i, x in ipairs(list) do names[i] = x.name end
assert(table.concat(names, ",") == "Fred,Kim Eisherz,Vulo", table.concat(names, ","))
assert(list[2].e == s.bench["Kim Eisherz"] and list[2].joined == kim.first and list[1].joined == nil, "joined when subbed in")
assert(s.bench["Kim Eisherz"], "a subbed-in raider stays on the bench")
STUB.roster[3], STUB.roster[4] = nil, nil

---------------------------------------------------------------------------
-- ns.IsBenched: a first name alone only when unique in the roster
---------------------------------------------------------------------------
assert(NS.IsBenched(s, "Kim Eisherz") == s.bench["Kim Eisherz"])
assert(NS.IsBenched(s, "kim eisherz"), "case aside")
assert(NS.IsBenched(s, "Kim") == s.bench["Kim Eisherz"], "a first name that is unique")
STUB.roster[3] = { name = "Vulo Sturmwind", class = "WARRIOR", zone = "Shattrath" }
assert(NS.IsBenched(s, "Vulo Sturmwind") == s.bench.Vulo, "bench 'Vulo' is the only Vulo in the group")
STUB.roster[4] = { name = "Vulo Eisherz", class = "WARRIOR", zone = "Shattrath" }
assert(NS.IsBenched(s, "Vulo Sturmwind") == nil, "two Vulos: no one")
STUB.roster[3], STUB.roster[4] = nil, nil
assert(NS.IsBenched(s, "Niemand") == nil and NS.IsBenched(s, nil) == nil)
assert(NS.BenchRemove(s, "Vulo") == true)

---------------------------------------------------------------------------
-- suggestions: group outside, guild online, friends online; no doubles, nobody benched or inside
---------------------------------------------------------------------------
STUB.roster[3] = { name = "Bob", class = "MAGE", zone = "Shattrath" }
STUB.roster[4] = { name = "Alt Draussen", class = "MAGE", zone = "Shattrath" }
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)
assert(s.outside.Bob and s.outside["Alt Draussen"])
s.outside["Alt Draussen"] = STUB.now - 700
STUB.guild = {
    { name = "Gildi-Realm", class = "ROGUE" }, { name = "Bob", class = "MAGE" }, { name = "Schlaefer", class = "DRUID", online = false },
    { name = "Fraktur", class = "SHAMAN" }, { name = "Fred", class = "HUNTER" }, { name = "Vulo Sturmwind", class = "WARRIOR" },
    { name = "Gast", class = "WARLOCK" }, { name = "Gastzwei", class = "WARLOCK" }, { name = "Gastdrei", class = "WARLOCK" },
}
STUB.friends = { { name = "Freundin", className = "Magier" }, { name = "Gildi", className = "Schurke" },
                 { name = "Weg", className = "Krieger", online = false } }
local sug = NS.BenchSuggestions(s)
local texts = {}
for i, x in ipairs(sug) do texts[i] = x.text; assert(x.value and x.text) end
local joined = table.concat(texts, ";")
assert(texts[1] == "Bob (in der Gruppe, draußen)", joined)
assert(has(joined, "Gildi (Gilde)") and has(joined, "Freundin (Freund)") and has(joined, "Gast (Gilde)"), joined)
assert(not has(joined, "Fraktur") and not has(joined, "Schlaefer") and not has(joined, "Fred") and not has(joined, "Weg")
    and not has(joined, "Alt Draussen"), joined)
local bobs, gildis = 0, 0
for _, x in ipairs(sug) do
    if x.value == "Bob" then bobs = bobs + 1 end
    if x.value == "Gildi" then gildis = gildis + 1 end
end
assert(bobs == 1 and gildis == 1, "no doubles")
-- the guild roster is requested at most every 10 s
local req = STUB.guildRequests
assert(NS.RequestGuildRoster() == true and STUB.guildRequests == req + 1)
assert(NS.RequestGuildRoster() == false and STUB.guildRequests == req + 1)
STUB.tick(10)
assert(NS.RequestGuildRoster() == true and STUB.guildRequests == req + 2)
-- a class from the guild
e = NS.BenchAdd(s, "Gildi", {})
assert(e.class == "ROGUE", e.class)
NS.BenchRemove(s, "Gildi")

---------------------------------------------------------------------------
-- ns.ReplyGate: 15 s per key, 20 a minute per word, one note a minute
---------------------------------------------------------------------------
later()
assert(NS.ReplyGate("probe", "Anna") == true)
assert(NS.ReplyGate("probe", "anna") == false, "the same key within 15 s")
assert(NS.ReplyGate("andere", "Anna") == true, "each word has its own gate")
STUB.tick(15)
assert(NS.ReplyGate("probe", "Anna") == true, "after 15 s")
STUB.tick(60)
local msgs = #STUB.messages
for i = 1, 20 do assert(NS.ReplyGate("probe", "k" .. i) == true, i) end
assert(NS.ReplyGate("probe", "k21") == false, "21st in a minute")
assert(#STUB.messages == msgs + 1 and lastMsg():find("Viele !probe-Anfragen: weitere bleiben bis zu einer Minute unbeantwortet.", 1, true), lastMsg())
assert(NS.ReplyGate("probe", "k22") == false and #STUB.messages == msgs + 1, "one note only")
STUB.tick(60)
assert(NS.ReplyGate("probe", "k23") == true, "the next minute")

---------------------------------------------------------------------------
-- !bench as the loot lead, by whisper to the raw sender
---------------------------------------------------------------------------
later()
STUB.chat = {}
ask("!bench", "Gast-Realm")
assert(#STUB.chat == 1 and last().chan == "WHISPER" and last().target == "Gast-Realm", "a whisper to the sender as given")
assert(last().text == ("Amisia: Du stehst auf der Ersatzbank (Black Temple, %s). Mit !bench aus trägst du dich aus."):format(short(s.date)), last().text)
assert(s.bench.Gast and s.bench.Gast.self and not s.bench.Gast.by and s.bench.Gast.class == "WARLOCK")
assert(has(lastMsg(), "Gast steht auf der Ersatzbank (selbst eingetragen)."), lastMsg())
ask("!bench nochmal", "Gast-Realm")
assert(#STUB.chat == 1, "one answer per sender every 15 s")
later()
ask("!bench ab 21 Uhr", "Gast-Realm")
assert(last().text == ("Amisia: Du stehst auf der Ersatzbank (Black Temple, %s). Mit !bench aus trägst du dich aus. Notiz: ab 21 Uhr."):format(short(s.date)), last().text)
assert(s.bench.Gast.note == "ab 21 Uhr")
later()
ask("!bench ?", "Gast")
assert(last().text == ("Amisia: Du stehst auf der Ersatzbank (seit %s)."):format(date("%H:%M", s.bench.Gast.t)), last().text)
later()
ask("!bench aus", "Gast")
assert(last().text == "Amisia: Du stehst nicht mehr auf der Ersatzbank." and s.bench.Gast == nil, last().text)
later()
ask("!bench ?", "Gast")
assert(last().text == "Amisia: Du stehst nicht auf der Ersatzbank.", last().text)
-- an entry by an officer is not removed by !bench aus
NS.BenchAdd(s, "Gastzwei", {})
later()
ask("!bench off", "Gastzwei")
assert(last().text == "Amisia: Ein Offizier hat dich eingetragen. Frag bitte ihn." and s.bench.Gastzwei, last().text)
-- in the raid, outside the guild
later()
ask("!bench", "Fraktur")
assert(last().target == "Fraktur" and last().text == "Amisia: Du bist schon im Raid.", last().text)
ask("!bench", "Fremder")
assert(last().target == "Fremder" and last().text == "Amisia: Die Ersatzbank ist nur für Gildenmitglieder." and not s.bench.Fremder, last().text)
later()
NS.Set("raidlog.benchGuildOnly", false)
ask("!bench", "Fremder")
assert(s.bench.Fremder and s.bench.Fremder.note == nil, "anyone when the setting is off")
NS.Reset("raidlog.benchGuildOnly")
NS.BenchRemove(s, "Fremder")
-- the guild list cannot be read: accepted with a note
later()
local guild = STUB.guild
STUB.guild = {}
ask("!bench", "Unbekannt")
assert(s.bench.Unbekannt and s.bench.Unbekannt.note == "Gilde nicht geprüft", "accepted with a note")
later()
ask("!bench komme spaeter", "Unbekanntzwei")
assert(s.bench.Unbekanntzwei.note == "komme spaeter", "an own note wins")
STUB.guild = guild
-- from the guild chat, the alias !ersatz
later()
ask("!bench", "Gastdrei", "CHAT_MSG_GUILD")
assert(last().chan == "WHISPER" and last().target == "Gastdrei" and s.bench.Gastdrei, "from the guild chat")
later()
NS.BenchRemove(s, "Gastdrei")
ask("!Ersatz", "Gastdrei", "CHAT_MSG_RAID")
assert(last().target == "Gastdrei" and s.bench.Gastdrei, "the alias from the raid chat")
-- benchNotify off: nothing in the own chat
later()
NS.Set("raidlog.benchNotify", false)
msgs = #STUB.messages
NS.BenchRemove(s, "Gastdrei")
ask("!bench", "Gastdrei")
assert(s.bench.Gastdrei and #STUB.messages == msgs, "quiet")
NS.Reset("raidlog.benchNotify")

---------------------------------------------------------------------------
-- no answer
---------------------------------------------------------------------------
local function silent(why, fn, undo)
    later()
    NS.BenchRemove(s, "Gast")
    local n = #STUB.chat
    fn()
    ask("!bench", "Gast")
    assert(#STUB.chat == n and not s.bench.Gast, why)
    undo()
end
silent("benchChat off", function() NS.Set("raidlog.benchChat", false) end, function() NS.Reset("raidlog.benchChat") end)
silent("not the loot lead", function() STUB.leader = false end, function() STUB.leader = true end)
silent("raider view", function() NS.Set("ui.view", "raider") end, function() NS.Reset("ui.view") end)
silent("secret sender", function() STUB.secret.Gast = true end, function() STUB.secret.Gast = nil end)
silent("battleground", function() STUB.instance.type = "pvp" end, function() STUB.instance.type = "raid" end)
later()
ask("!bench", "Gast")
assert(s.bench.Gast, "answers again")

---------------------------------------------------------------------------
-- /amisia ersatz
---------------------------------------------------------------------------
NS.Dispatch("ersatz Vulo Sturmwind ab 21 Uhr")
assert(s.bench["Vulo Sturmwind"] and s.bench["Vulo Sturmwind"].note == "ab 21 Uhr" and s.bench["Vulo Sturmwind"].by == "Vuloo",
    "a Forever name of two words")
assert(has(lastMsg(), "Vulo Sturmwind steht auf der Ersatzbank"), lastMsg())
NS.Dispatch("bench Anna komme spaeter")
assert(s.bench.Anna and s.bench.Anna.note == "komme spaeter", "the first word when the two are no known name")
NS.Dispatch("ersatz weg Anna")
assert(s.bench.Anna == nil and has(lastMsg(), "Anna"), lastMsg())
NS.Dispatch("bench remove Anna")
assert(has(lastMsg(), "Anna steht nicht auf der Ersatzbank."), lastMsg())
NS.Dispatch("ersatz Fraktur")
assert(has(lastMsg(), "Fraktur ist im Raid."), lastMsg())
if not NS.ShowRaidLog then
    msgs = #STUB.messages
    NS.Dispatch("ersatz")
    assert(#STUB.messages > msgs and has(table.concat(STUB.messages, "\n", msgs + 1), "Vulo Sturmwind"), "the list in the chat")
end
NS.Set("ui.view", "raider")
NS.Dispatch("ersatz Kein Offizier")
assert(not s.bench.Kein and has(lastMsg(), "Offiziersansicht"), lastMsg())
NS.Reset("ui.view")
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(has(help, "/amisia ersatz"), help)
assert(not has(table.concat(NS.SlashHelpLines(false), "\n"), "/amisia ersatz"), "for officers")

-- without a recording !bench goes to tonight's benchNext
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil)
later()
STUB.chat = {}
ask("!bench", "Gastzwei")
assert(last().text == ("Amisia: Du stehst auf der Ersatzbank (heute, %s). Mit !bench aus trägst du dich aus."):format(short(night)), last().text)
assert(AmisiaDB.benchNext.list.Gastzwei.self, "into benchNext")

---------------------------------------------------------------------------
-- texts stay within Latin-1
---------------------------------------------------------------------------
for _, file in ipairs({ "Bench.lua", "Chat.lua", "SoftRes.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for c in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. c) end
end
