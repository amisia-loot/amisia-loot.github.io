--[[clients Vulo_Sturmwind Lia_Weide Kim_Eisherz]]
--[[without raid for Kim_Eisherz]]
-- A raid member whose Amisia runs without the raid module (F-202, D-130): his hello names the modules he
-- has ("g"), and the officer's raid check, version list and need list show him as "ohne Raid" (not
-- outdated, no answer expected); the raid's traffic (sync snapshots, awards, a roll, the raid check, the
-- raid note) reaches his client without a Lua error and is simply dropped, as by a client without Amisia.
-- An old hello without the field counts as every module.
local VULO, LIA, KIM = "Vulo Sturmwind", "Lia Weide", "Kim Eisherz"

BUS.setRaid({ VULO, LIA, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = LIA, rank = 4 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind"
        STUB.leader = STUB.player == "Vulo Sturmwind"
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(KIM, "NS.HasModule('raid')") == false and C(KIM, "NS.HasModule('gear')") == true)
assert(C(KIM, "NS.Active == nil and NS.StartRoll == nil"), "no raid code on Kim's client")

-- the hellos name the modules
local function lastHello(sender)
    local text
    for _, m in ipairs(BUS.sent) do if m.sender == sender and m.kind == "HI" then text = m.text end end
    return text
end
assert(lastHello(KIM):match("\tg$"), lastHello(KIM))
assert(lastHello(LIA):match("\trg$"), lastHello(LIA))
local seen = C(VULO, "local out = {} for _, e in ipairs(NS.VersionSeen()) do out[e.name] = e.m or false end return out")
assert(seen[KIM] == "g" and seen[LIA] == "rg", tostring(seen[KIM]))

-- the version list: Kim "ohne Raid", neither outdated nor too old
local rows = C(VULO, [[local out = {}
    for _, r in ipairs(NS.VersionRows()) do out[r.name] = { noRaid = r.noRaid or false, outdated = r.outdated or false,
        tooOld = r.tooOld or false, view = NS.VersionView(r) } end
    return out]])
assert(rows[KIM].noRaid and not rows[KIM].outdated and not rows[KIM].tooOld and rows[KIM].view == "ohne Raid", rows[KIM].view)
assert(not rows[LIA].noRaid and rows[LIA].view == "Raider")
-- the page "Über und Befehle": the summary counts him apart
C(VULO, "NS.ToggleMain(); NS.ShowPage('about')")
local summary = C(VULO, "NS.Refresh(); return NS.PageFrame('about').summary:GetText()")
assert(summary:find("1 ohne Raid", 1, true) and not summary:find("veraltet", 1, true), summary)

-- the need list expects no answer from him
local expected = C(VULO, "return table.concat(NS.AmisiaInGroup(), ',')")
assert(expected == LIA, expected)

-- the raid's traffic reaches Kim and is dropped without an error
local before = C(KIM, "NS.CommStats().received")
local s = C(VULO, "return NS.Active() and true or false")
assert(s, "Vulo records the raid")
C(VULO, "NS.AddAwardTo(NS.Active(), { name = 'Lia Weide', item = 32235, kind = 'MS', src = 'Ragnaros', t = time() })")
BUS.tick(8)
assert(C(LIA, "#NS.Active().awards") == 1, "Lia follows the keeper")
C(VULO, "NS.Set('ui.view', 'officer')")
assert(C(VULO, "return (NS.StartRoll(STUB.item(32235, 'Cursed Vision of Sargeras', 4), 10))"))
BUS.tick(12)
assert(C(VULO, "return (NS.RaidCheck.Ask())") == true)
BUS.tick(6)
if C(VULO, "NS.RaidNote ~= nil") then
    C(VULO, "NS.RaidNote.Send('Kim: {stern}')")
    BUS.tick(6)
end
assert(C(KIM, "NS.CommStats().received") > before, "Kim's client got the raid's messages")
assert(BUS.count({ kind = "XA", sender = KIM }) == 0, "without the raid module: no raid check answer")
assert(BUS.count({ kind = "XA", sender = LIA }) == 1, "Lia answers")
assert(C(KIM, "AmisiaDB.sessions == nil or next(AmisiaDB.sessions) == nil"), "Kim records nothing")

-- the raid check page's row: "ohne Raid"
local row = C(VULO, [[for _, r in ipairs(NS.RaidCheck.Rows().list) do
    if r.name == "Kim Eisherz" then return { noRaid = r.noRaid or false, ver = r.ver } end end]])
assert(row and row.noRaid and row.ver, "Kim: Amisia without raid")
C(VULO, "NS.ShowPage('raidcheck')")

-- an old hello without the field: every module
C(VULO, ([[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t%s\t1\t-\t-", "RAID", "Lia Weide", "", 0, 0, "", 0)]]):format(C(VULO, "NS.VERSION")))
BUS.tick(1)
local lia = C(VULO, "for _, e in ipairs(NS.VersionSeen()) do if e.name == 'Lia Weide' then return { m = e.m or false, no = NS.VersionWithoutRaid(e) } end end")
assert(lia.m == false and lia.no == false, "an older Amisia counts as all")
-- a broken field is dropped, not stored
C(VULO, ([[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t%s\t1\t-\t-\tR!x", "RAID", "Kim Eisherz", "", 0, 0, "", 0)]]):format(C(VULO, "NS.VERSION")))
BUS.tick(1)
assert(C(VULO, "for _, e in ipairs(NS.VersionSeen()) do if e.name == 'Kim Eisherz' then return e.m or false end end") == false)
