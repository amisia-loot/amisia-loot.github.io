--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- The raid sync (Raid/Sync.lua, audit 2026-11-07): an officer in the raider view takes only the
-- public part. It keeps the officer fields it holds (note, first winner, "by hand"), marks its
-- state as public only, asks for the officer part once back in the officer view, and as the next
-- keeper gathers the whole state first: the notes are never lost raid-wide.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function award(name, id)
    return S(name, ([[for _, a in ipairs(s.awards) do if a.id == %q then return { note = a.note, orig = a.orig, manual = a.manual, kind = a.kind } end end
        return false]]):format(id))
end
local function setMaster(i)
    for _, name in ipairs(CLIENTS) do
        C(name, ([[STUB.lootMethod = %d; STUB.mlRaidID = %s; STUB.fire("PARTY_LOOT_METHOD_CHANGED")]]):format(i and 2 or 0, tostring(i)))
    end
end

BUS.setRaid({ VULO, FRAK, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true)
C(FRAK, "NS.Set('ui.view', 'raider')")
BUS.tick(5)

-- 1. Fraktur in the raider view gets the award without its note; his state is public only
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 32235, kind = 'MS', src = 'Ragnaros', note = 'Tausch mit Vuloo', t = time() }).id")
BUS.tick(8)
assert(award(FRAK, a1) and award(FRAK, a1).note == nil, "the raider view takes no note")
assert(S(FRAK, "s.sync.pub") == true, "the state is marked public only")
assert(S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash"))

-- 2. back in the officer view he asks for the officer part (the checksum is the same) and takes it
C(FRAK, "NS.Set('ui.view', 'officer')")
BUS.tick(60)
assert(award(FRAK, a1).note == "Tausch mit Vuloo", "the officer view brings the note: " .. tostring(award(FRAK, a1).note))
assert(S(FRAK, "s.sync.pub") == nil, "the state is whole again")

-- 3. in the raider view again: a public snapshot keeps the note he holds
C(FRAK, "NS.Set('ui.view', 'raider')")
BUS.tick(5)
S(VULO, ("NS.EditAward(s, %q, { kind = 'OS' })"):format(a1))
BUS.tick(8)
assert(award(FRAK, a1).kind == "OS", "the change came")
assert(award(FRAK, a1).note == "Tausch mit Vuloo", "the public part does not clear the note")

-- 4. a second award he never saw whole; the master loot goes to him as he turns to the officer
-- view: as the new keeper he gathers the whole state first, nobody loses the note
local a2 = S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30000, kind = 'MS', src = 'Ragnaros', note = 'Erster: Kim', t = time() }).id")
BUS.tick(8)
assert(award(FRAK, a2).note == nil and S(FRAK, "s.sync.pub") == true)
-- his plain request for the officer part gets lost: only the gathering can bring the note
BUS.drop(function(m) return m.kind == "RQ" and m.sender == FRAK and m.chan == "WHISPER" and not m.text:find("G%s*$") end)
C(FRAK, "NS.Set('ui.view', 'officer')")
setMaster(2)
BUS.tick(30)
BUS.drop(nil)
local plain, gathered = 0, 0
for _, m in ipairs(BUS.sent) do
    if m.kind == "RQ" and m.sender == FRAK then
        if m.dropped then plain = plain + 1 elseif m.text:find("G%s*$") then gathered = gathered + 1 end
    end
end
assert(plain >= 1 and gathered >= 1, "the plain request was dropped, the gathering went: " .. plain .. " " .. gathered)
assert(C(FRAK, "NS.SyncIsKeeper()") == true, "Fraktur keeps the raid")
assert(award(VULO, a1).note == "Tausch mit Vuloo" and award(VULO, a2).note == "Erster: Kim",
    "the old keeper keeps the notes: " .. tostring(award(VULO, a2).note))
assert(award(FRAK, a2).note == "Erster: Kim", "the new keeper has them")
assert(award(KIM, a2).note == nil, "the raider still gets none")
