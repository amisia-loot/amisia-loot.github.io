--[[preload
GetGuildRosterInfo = nil
GetNumGuildMembers = nil
]]
-- A client without the classic guild roster functions (Forever): the bench reads the guild through
-- Trust's roster (C_Club). !bench checks the guild, suggestions and classes come from it.
local function last() return STUB.chat[#STUB.chat] end
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.guild = { { name = "Vuloo", class = "PRIEST", rank = 2 }, { name = "Gildi", class = "ROGUE" },
               { name = "Kim Eisherz", class = "WARRIOR" }, { name = "Schlaefer", class = "DRUID", online = false } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "a recording")
assert(GetGuildRosterInfo == nil and NS.GuildRoster() and #NS.GuildRoster() == 4, "the roster through C_Club")

-- suggestions: the guild online, with the class from the club
local texts = {}
for _, x in ipairs(NS.BenchSuggestions(s)) do texts[#texts + 1] = x.text end
local joined = table.concat(texts, ";")
assert(joined:find("Gildi (Gilde)", 1, true) and joined:find("Kim Eisherz (Gilde)", 1, true), joined)
assert(not joined:find("Schlaefer", 1, true) and not joined:find("Vuloo", 1, true), joined)

-- !bench: a guild member is taken without a note, with the class; someone else is refused
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Gildi")
assert(s.bench.Gildi and s.bench.Gildi.self and s.bench.Gildi.note == nil and s.bench.Gildi.class == "ROGUE", "checked against the club")
assert(last().target == "Gildi")
STUB.tick(20)
STUB.fire("CHAT_MSG_WHISPER", "!bench", "kim eisherz")
assert(s.bench["kim eisherz"] or s.bench["Kim Eisherz"], "any case")
STUB.tick(20)
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Fremder")
assert(not s.bench.Fremder and last().target == "Fremder" and last().text == "Amisia: Die Ersatzbank ist nur für Gildenmitglieder.",
    last().text)

-- the lockdown: the roster built before it still answers
STUB.chatLock = true
STUB.tick(20)
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Fremdzwei")
assert(not s.bench.Fremdzwei, "refused in the lockdown too")
STUB.chatLock = false

-- no club roster either: accepted with a note
STUB.guild = {}
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(20)
assert(NS.GuildRoster() == nil)
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Unbekannt")
assert(s.bench.Unbekannt and s.bench.Unbekannt.note == "Gilde nicht geprüft", "not checked")
