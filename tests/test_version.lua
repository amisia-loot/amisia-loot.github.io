--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Lia_Weide Pug]]
-- The version check (Version.lua) between clients: the hello after the login once (not again after a
-- /reload within 30 minutes), the hello on entering a raid, questions to the raid and the guild with
-- whispered answers after a random delay, the 5 minutes of the guild question, the note on a newer
-- version once per version and only from an officer or two members, senders outside the guild
-- ignored, the cleaning of the seen list, the page "Über und Befehle" and the command.
local function count(name, text)
    return C(name, ("local n = 0; for _, m in ipairs(STUB.messages) do if m:find(%q, 1, true) then n = n + 1 end end; return n"):format(text))
end

BUS.setGuild({ { name = "Vulo Sturmwind", rank = 1 }, { name = "Fraktur", rank = 2 }, { name = "Kim Eisherz", rank = 4 },
               { name = "Lia Weide", rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.fire("GUILD_ROSTER_UPDATE")]])
end
assert(C("Fraktur", "NS.IsVerifiedOfficer('Vulo Sturmwind')") == true and C("Vulo Sturmwind", "NS.IsVerifiedMember('Pug')") == false)

---------------------------------------------------------------------------
-- versions compare by their three numbers
---------------------------------------------------------------------------
assert(C("Kim Eisherz", "NS.CompareVersion('2.1.0', '2.0.9')") == 1)
assert(C("Kim Eisherz", "NS.CompareVersion('2.1.0', '2.10.0')") == -1)
assert(C("Kim Eisherz", "NS.CompareVersion('2.1.0', '2.1.0')") == 0)
local own = C("Kim Eisherz", "NS.VERSION")

---------------------------------------------------------------------------
-- the hello after the login: once, 20 to 60 s later, only in a guild
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end
BUS.tick(19.9)
assert(BUS.count({ kind = "HI" }) == 0, "nothing before 20 s")
BUS.tick(40.2)
assert(BUS.count({ kind = "HI", chan = "GUILD" }) == 4, "one hello of every guild client: " .. BUS.count({ kind = "HI" }))
for _, name in ipairs({ "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Lia Weide" }) do
    assert(BUS.count({ kind = "HI", chan = "GUILD", sender = name, from = 20, to = 60.1 }) == 1, name)
end
assert(BUS.count({ sender = "Pug" }) == 0, "Pug is in no guild")
local vuloHello
for _, m in ipairs(BUS.sent) do if m.sender == "Vulo Sturmwind" and m.kind == "HI" then vuloHello = m.text end end
assert(vuloHello == "1HI\t" .. own .. "\t1\tO\t-", vuloHello)
local kimHello
for _, m in ipairs(BUS.sent) do if m.sender == "Kim Eisherz" and m.kind == "HI" then kimHello = m.text end end
assert(kimHello == "1HI\t" .. own .. "\t1\t-\t-", "a raider: " .. kimHello)
-- what Vulo saw: the guild, by the time seen
local seen = C("Vulo Sturmwind", "NS.VersionSeen()")
assert(#seen == 3, #seen)
for _, e in ipairs(seen) do assert(e.where == "guild" and e.v == own and e.p == 1 and e.mp == 1) end
local byName = {}
for _, e in ipairs(seen) do byName[e.name] = e end
assert(byName["Fraktur"].flags == "O" and byName["Kim Eisherz"].flags == "-" and byName["Lia Weide"])
assert(C("Vulo Sturmwind", "type(AmisiaDB.sync.helloAt)") == "number")
assert(C("Vulo Sturmwind", "NS.VersionNewer()") == nil)
-- no second hello in this session
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end
BUS.tick(61)
assert(BUS.count({ kind = "HI", chan = "GUILD" }) == 4)

---------------------------------------------------------------------------
-- a /reload within 30 minutes: no hello; after 30 minutes: one
---------------------------------------------------------------------------
BUS.reload("Fraktur")
assert(C("Fraktur", "AmisiaDB.sync.seen['Vulo Sturmwind'].v") == own, "the seen list survives the reload")
C("Fraktur", "STUB.fire('PLAYER_LOGIN')")
BUS.tick(61)
assert(BUS.count({ kind = "HI", sender = "Fraktur" }) == 1, "no hello after the reload")
BUS.tick(1800)
BUS.reload("Fraktur")
C("Fraktur", "STUB.fire('PLAYER_LOGIN')")
BUS.tick(61)
assert(BUS.count({ kind = "HI", sender = "Fraktur", chan = "GUILD" }) == 2, "after 30 minutes the hello goes again")

---------------------------------------------------------------------------
-- entering a raid: a hello into the raid 1 to 5 s later, at most once in 2 minutes
---------------------------------------------------------------------------
BUS.setRaid({ "Vulo Sturmwind", "Fraktur", "Pug" })
local t0 = C("Fraktur", "STUB.clock")
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.tick(0.9)
assert(BUS.count({ kind = "HI", chan = "RAID" }) == 0, "not before 1 s")
BUS.tick(5)
assert(BUS.count({ kind = "HI", chan = "RAID" }) == 3, "Vulo, Fraktur and Pug: " .. BUS.count({ kind = "HI", chan = "RAID" }))
assert(BUS.count({ kind = "HI", chan = "RAID", from = t0 + 1, to = t0 + 5 }) == 3, "1 to 5 s after entering")
assert(BUS.count({ kind = "HI", chan = "RAID", sender = "Kim Eisherz" }) == 0)
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.tick(6)
assert(BUS.count({ kind = "HI", chan = "RAID" }) == 3, "the next roster update is no entry")
-- the raid hello reached Vulo as "raid"; Pug is ignored (outside the guild)
seen = C("Vulo Sturmwind", "NS.VersionSeen()")
assert(seen[1].name == "Fraktur" and seen[1].where == "raid", seen[1].name)
for _, e in ipairs(seen) do assert(e.name ~= "Pug", "a sender outside the guild is ignored") end
assert(C("Vulo Sturmwind", "AmisiaDB.sync.seen['Pug']") == nil)

---------------------------------------------------------------------------
-- asking the raid: answers by whisper 0 to 3 s later, the same asker once in 5 minutes
---------------------------------------------------------------------------
local before = BUS.count({ kind = "HI", chan = "WHISPER" })
local askAt = C("Vulo Sturmwind", "STUB.clock")
assert(C("Vulo Sturmwind", "NS.VersionAsk('raid')") == true)
assert(BUS.count({ kind = "VQ", chan = "RAID", sender = "Vulo Sturmwind" }) == 1)
local ok, why = C("Vulo Sturmwind", "NS.VersionAsk('raid')")
assert(ok == nil and why == "Der Raid wurde gerade gefragt.", tostring(why))
BUS.tick(3.2)
assert(BUS.count({ kind = "HI", chan = "WHISPER", target = "Vulo Sturmwind" }) == before + 1, "Fraktur answers, Pug not")
assert(BUS.count({ kind = "HI", chan = "WHISPER", sender = "Fraktur", from = askAt, to = askAt + 3.05 }) == 1)
assert(BUS.count({ kind = "HI", chan = "WHISPER", sender = "Pug" }) == 0, "Pug does not answer an asker it cannot check")
BUS.tick(30)
assert(C("Vulo Sturmwind", "NS.VersionAsk('raid')") == true, "again after 30 s")
BUS.tick(4)
assert(BUS.count({ kind = "HI", chan = "WHISPER", sender = "Fraktur" }) == 1, "the same asker once in 5 minutes")
assert(C("Kim Eisherz", "select(2, NS.VersionAsk('raid'))") == "Du bist in keiner Raidgruppe.")

---------------------------------------------------------------------------
-- asking the guild: answers by whisper 1 to 15 s later; the next guild question after 5 minutes
---------------------------------------------------------------------------
askAt = C("Kim Eisherz", "STUB.clock")
assert(C("Kim Eisherz", "NS.VersionAsk('guild')") == true)
assert(BUS.count({ kind = "VQ", chan = "GUILD", sender = "Kim Eisherz" }) == 1)
ok, why = C("Kim Eisherz", "NS.VersionAsk('guild')")
assert(ok == nil and why == "Die Gilde wurde gerade gefragt. Noch 5 Minuten.", tostring(why))
BUS.tick(0.9)
assert(BUS.count({ kind = "HI", chan = "WHISPER", target = "Kim Eisherz" }) == 0, "not before 1 s")
BUS.tick(15)
for _, name in ipairs({ "Vulo Sturmwind", "Fraktur", "Lia Weide" }) do
    assert(BUS.count({ kind = "HI", chan = "WHISPER", target = "Kim Eisherz", sender = name, from = askAt + 1, to = askAt + 15.05 }) == 1, name)
end
BUS.tick(120)
ok, why = C("Kim Eisherz", "NS.VersionAsk('guild')")
assert(why == "Die Gilde wurde gerade gefragt. Noch 3 Minuten.", tostring(why))
BUS.tick(150)
ok, why = C("Kim Eisherz", "NS.VersionAsk('guild')")
assert(why == "Die Gilde wurde gerade gefragt. Noch 1 Minute.", tostring(why))
BUS.tick(30)
-- versionCheck off: no answer, no question, no hello
C("Lia Weide", "NS.Set('sync.versionCheck', false)")
assert(C("Kim Eisherz", "NS.VersionAsk('guild')") == true)
BUS.tick(16)
assert(BUS.count({ kind = "HI", chan = "WHISPER", target = "Kim Eisherz", sender = "Lia Weide" }) == 1, "Lia stays quiet")
ok, why = C("Lia Weide", "NS.VersionAsk('guild')")
assert(ok == nil and why == "Versionsprüfung ist ausgeschaltet.")
C("Lia Weide", "NS.Reset('sync.versionCheck')")

---------------------------------------------------------------------------
-- the page "Über und Befehle": rows, colours, "kein Amisia?", buttons
---------------------------------------------------------------------------
BUS.tick(300)
C("Vulo Sturmwind", [[_G.UnitClass = function() return "Priester", "PRIEST" end
    _G.UnitLevel = function() return 24 end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.GetInventoryItemLink = function() return nil end
    NS.ShowPage("about")]])
assert(C("Vulo Sturmwind", "NS.CurrentPage()") == "about")
-- code with the page frame as f; an expression gives its value back
local function page(name, code)
    return C(name, "local f = NS.AboutPageFrame(); " .. (code:find("^local ") and "" or "return ") .. code)
end
assert(page("Vulo Sturmwind", "f.head:GetText()") == ("Amisia %s · Sync-Protokoll 1"):format(own))
assert(page("Vulo Sturmwind", "f.title:GetText()") == "Amisia in Raid und Gilde")
assert(page("Vulo Sturmwind", "f.askRaid:GetText()") == "Raid fragen" and page("Vulo Sturmwind", "f.askGuild:GetText()") == "Gilde fragen")
assert(page("Vulo Sturmwind", "f.askRaid:IsEnabled() and f.askGuild:IsEnabled()") == true)
-- asking from the page; 10 s later the raid member without an answer shows
page("Vulo Sturmwind", "f.askRaid:Click()")
assert(BUS.count({ kind = "VQ", sender = "Vulo Sturmwind" }) == 3)
BUS.tick(10.5)
page("Vulo Sturmwind", "NS.Refresh()")
local rows = page("Vulo Sturmwind", [[local out = {}
    for i, r in ipairs(f.list.rows) do
        if r:IsShown() then out[i] = { r.name:GetText(), r.ver:GetText(), r.view:GetText(), r.where:GetText(), r.last:GetText() } end
    end
    return out]])
-- raid first by name (Vulo himself among them), then the guild by the time seen
assert(rows[1][1]:find("Fraktur", 1, true) and rows[1][2] == own and rows[1][3] == "Offizier" and rows[1][4] == "Raid", rows[1][1])
assert(rows[2][1]:find("Pug", 1, true) and rows[2][2] == "-" and rows[2][3] == "-" and rows[2][5]:find("kein Amisia?", 1, true), rows[2][5])
assert(rows[2][5]:find("|cff", 1, true) == 1, "grey")
assert(rows[3][1]:find("Vulo Sturmwind", 1, true) and rows[3][2] == own and rows[3][3] == "Offizier" and rows[3][4] == "Raid")
assert(rows[4][4] == "Gilde" and rows[5][4] == "Gilde" and rows[6] == nil, "two guild rows")
assert(rows[4][5]:match("^%d%d:%d%d$"), "seen today: the time " .. rows[4][5])
assert(page("Vulo Sturmwind", "f.summary:GetText()") == "Raid: 2 von 3 mit Amisia · Gilde: 2 gesehen", page("Vulo Sturmwind", "f.summary:GetText()"))
assert(page("Vulo Sturmwind", "f.newer:IsShown()") == false)
-- a newer version from an officer in the raid: the note, the own row orange
C("Fraktur", "NS.CommSend('HI', { '9.0.1', '1', 'O', '-' }, 'RAID')")
BUS.tick(1.1)
page("Vulo Sturmwind", "NS.Refresh()")
assert(page("Vulo Sturmwind", "f.newer:IsShown()") == true)
assert(page("Vulo Sturmwind", "f.newer:GetText()"):find("Es gibt eine neuere Version: 9.0.1 (gesehen bei Fraktur). Bitte aktualisieren.", 1, true))
assert(page("Vulo Sturmwind", "f.summary:GetText()") == "Raid: 2 von 3 mit Amisia · 1 veraltet · Gilde: 2 gesehen")
local ver = page("Vulo Sturmwind", "f.list.rows[3].ver:GetText()")
assert(ver:find(own, 1, true) and ver:find("|cffff9933", 1, true), "the own old version is orange: " .. ver)
assert(page("Vulo Sturmwind", "f.list.rows[1].ver:GetText()") == "9.0.1")
-- the guild question from the page locks its button for 5 minutes
page("Vulo Sturmwind", "f.askGuild:Click()")
assert(BUS.count({ kind = "VQ", chan = "GUILD", sender = "Vulo Sturmwind" }) == 1)
page("Vulo Sturmwind", "NS.Refresh()")
assert(page("Vulo Sturmwind", "f.askGuild:IsEnabled()") == false and page("Vulo Sturmwind", "f.askGuild.tip") == "Wieder in 5 Minuten.")
BUS.tick(120)
page("Vulo Sturmwind", "NS.Refresh()")
assert(page("Vulo Sturmwind", "f.askGuild.tip") == "Wieder in 3 Minuten.")
-- the version check switched off: both buttons locked
C("Vulo Sturmwind", "NS.Set('sync.versionCheck', false)")
page("Vulo Sturmwind", "NS.Refresh()")
assert(page("Vulo Sturmwind", "f.askRaid:IsEnabled() or f.askGuild:IsEnabled()") == false)
assert(page("Vulo Sturmwind", "f.askRaid.tip") == "Versionsprüfung ist ausgeschaltet." and page("Vulo Sturmwind", "f.askGuild.tip") == "Versionsprüfung ist ausgeschaltet.")
C("Vulo Sturmwind", "NS.Reset('sync.versionCheck')")
-- the page refreshes itself on new versions, at most once a second, only while shown
C("Vulo Sturmwind", "NS.Refresh()")
C("Kim Eisherz", "NS.CommSend('HI', { '2.0.0', '1', '-', '-' }, 'GUILD')")
BUS.tick(0.1)
BUS.tick(1.2)
assert(page("Vulo Sturmwind", "f.summary:GetText()"):find("Gilde: 2 gesehen", 1, true))
-- the commands under the list
assert(page("Vulo Sturmwind", "f.cmdTitle:GetText()") == "Befehle")
assert(page("Vulo Sturmwind", "f.text.fs:GetText()"):find("/amisia version", 1, true))
-- a client outside the guild sees nobody: the empty text
C("Pug", [[_G.UnitClass = function() return "Priester", "PRIEST" end
    _G.UnitLevel = function() return 24 end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.GetInventoryItemLink = function() return nil end
    NS.ShowPage("about")]])
assert(page("Pug", "f.empty:IsShown()") == true and page("Pug", "f.empty:GetText()") == "Noch keine anderen Amisia-Clients gesehen.")
assert(page("Pug", "f.list.rows[1]:IsShown()") == false)
-- outside a raid the raid button is locked
C("Lia Weide", [[_G.UnitClass = function() return "Priester", "PRIEST" end
    _G.UnitLevel = function() return 24 end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.GetInventoryItemLink = function() return nil end
    NS.ShowPage("about")]])
assert(page("Lia Weide", "f.askRaid:IsEnabled()") == false and page("Lia Weide", "f.askGuild:IsEnabled()") == true)
assert(page("Lia Weide", "f.summary:GetText()"):find("^Gilde: %d+ gesehen$"))

---------------------------------------------------------------------------
-- the note on a newer version: once per version, only from an officer or two members
---------------------------------------------------------------------------
local note = "Es gibt eine neuere Version"
assert(count("Vulo Sturmwind", note) == 1, "the 9.0.1 of Fraktur, once")
assert(count("Lia Weide", note) == 0, "Lia was not in the raid")
C("Kim Eisherz", "NS.CommSend('HI', { '9.1.0', '1', '-', '-' }, 'GUILD')")
BUS.tick(1.1)
assert(count("Lia Weide", note) == 0, "one member alone is not enough")
assert(C("Lia Weide", "NS.VersionNewer()") == nil)
C("Vulo Sturmwind", "NS.CommSend('HI', { '9.1.0', '1', 'O', '-' }, 'GUILD')")
BUS.tick(1.1)
assert(count("Lia Weide", "Es gibt eine neuere Version (9.1.0, gesehen bei Vulo Sturmwind). Du hast " .. own .. ".") == 1)
assert(C("Lia Weide", "AmisiaDB.sync.warned") == "9.1.0")
C("Vulo Sturmwind", "NS.CommSend('HI', { '9.1.0', '1', 'O', '-' }, 'GUILD')")
BUS.tick(1.1)
assert(count("Lia Weide", note) == 1, "once per version")
-- two members without officer rank are enough
C("Fraktur", "NS.Set('sync.outdatedWarn', false)")
BUS.tick(300)
C("Kim Eisherz", "NS.CommSend('HI', { '9.2.0', '1', '-', '-' }, 'GUILD')")
BUS.tick(1.1)
assert(count("Vulo Sturmwind", "9.2.0") == 0)
C("Lia Weide", "NS.CommSend('HI', { '9.2.0', '1', '-', '-' }, 'GUILD')")
BUS.tick(1.1)
assert(count("Vulo Sturmwind", "Es gibt eine neuere Version (9.2.0, gesehen bei Lia Weide).") == 1)
assert(C("Vulo Sturmwind", "NS.VersionNewer()") == "9.2.0")
assert(count("Fraktur", "9.2.0") == 0, "sync.outdatedWarn off")
-- a keeper's minimum protocol above the own one
C("Fraktur", "NS.CommSend('HI', { '9.3.0', '2', 'OL', '-' }, 'RAID')")
BUS.tick(1.1)
assert(count("Vulo Sturmwind", "Deine Version ist zu alt für den Abgleich mit Fraktur. Bitte aktualisieren.") == 1)
C("Fraktur", "NS.CommSend('HI', { '9.3.0', '2', 'OL', '-' }, 'RAID')")
BUS.tick(1.1)
assert(count("Vulo Sturmwind", "Deine Version ist zu alt") == 1, "once")

---------------------------------------------------------------------------
-- the command: asks the raid (or the guild), the list in the chat 10 s later
---------------------------------------------------------------------------
BUS.tick(31)
C("Vulo Sturmwind", "STUB.messages = {}; NS.Dispatch('version')")
assert(BUS.count({ kind = "VQ", chan = "RAID", sender = "Vulo Sturmwind" }) == 4)
BUS.tick(10.5)
assert(count("Vulo Sturmwind", "Amisia-Versionen:") == 1)
assert(count("Vulo Sturmwind", "Fraktur · " .. own .. " · Offizier · Raid") == 1, "Fraktur answered with its own version")
assert(count("Vulo Sturmwind", "Pug · kein Amisia? · - · Raid") == 1)
C("Lia Weide", "STUB.messages = {}; NS.Dispatch('versionen')")
assert(BUS.count({ kind = "VQ", chan = "GUILD", sender = "Lia Weide" }) == 1, "outside a raid: the guild")

---------------------------------------------------------------------------
-- the seen list is cleaned on load: 30 days, 300 entries; twice changes nothing
---------------------------------------------------------------------------
local kept = C("Vulo Sturmwind", [[local now = time()
    local seen = AmisiaDB.sync.seen
    for k in pairs(seen) do seen[k] = nil end
    for i = 1, 310 do seen["Spieler " .. i] = { v = "2.0.0", p = 1, mp = 1, flags = "-", where = "guild", at = now - i * 60 } end
    seen["Alt"] = { v = "2.0.0", p = 1, mp = 1, flags = "-", where = "guild", at = now - 31 * 86400 }
    seen["Kaputt"] = "x"
    NS.VersionLoaded(AmisiaDB)
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    local first = n
    NS.VersionLoaded(AmisiaDB)
    n = 0
    for _ in pairs(seen) do n = n + 1 end
    return { first = first, second = n, old = seen["Alt"] == nil, broken = seen["Kaputt"] == nil,
             newest = seen["Spieler 1"] ~= nil, oldest = seen["Spieler 310"] == nil, last = seen["Spieler 300"] ~= nil }]])
assert(kept.first == 300 and kept.second == 300, kept.first)
assert(kept.old and kept.broken and kept.newest and kept.oldest and kept.last)

---------------------------------------------------------------------------
-- settings and texts
---------------------------------------------------------------------------
assert(C("Kim Eisherz", "NS.SettingItem('sync.versionCheck').label") == "Versionsprüfung")
assert(C("Kim Eisherz", "NS.SettingItem('sync.versionCheck').tip") == "Meldet die eigene Version einmal nach dem Login an die Gilde und beim Betreten eines Raids.")
assert(C("Kim Eisherz", "NS.SettingItem('sync.outdatedWarn').label") == "Hinweis auf eine neuere Amisia-Version")
assert(C("Kim Eisherz", "NS.SettingItem('sync.versionCheck').default") == true and C("Kim Eisherz", "NS.SettingItem('sync.outdatedWarn').default") == true)
local keys = C("Kim Eisherz", "local out = {}; for i, it in ipairs(NS.SYNC_SETTINGS.items) do out[i] = it.key end; return out")
local at = {}
for i, k in ipairs(keys) do at[k] = i end
assert(at["sync.enabled"] < at["sync.versionCheck"] and at["sync.versionCheck"] < at["sync.outdatedWarn"] and at["sync.outdatedWarn"] < at["sync.debug"])
for _, file in ipairs({ "Core/Version.lua", "UI/Pages/About.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for c in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. c) end
end
