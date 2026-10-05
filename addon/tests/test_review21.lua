--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Review of 2.1, the raid sync between clients: claims through a long boss fight (the lockdown
-- holds every state), claims kept fresh by any keeper traffic, a long night with more than 100 kill
-- headers and a full bench (the snapshot passes its own check), and malformed wishes (times
-- outside the raid's days, not a number) refused with NO instead of stopping the sync.
-- Vulo Sturmwind is master looter and keeper, Fraktur an officer with "loot lead: me", Kim a raider.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local ALL = { VULO, FRAK, KIM }

local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function award(name, id)
    return S(name, ([[local a, _, gone = NS.FindAward(s, %q)
        if not a then return nil end
        return { name = a.name, kind = a.kind, note = a.note, gone = gone }]]):format(id))
end
local function add(name, who, item)
    return S(name, ("NS.AddAwardTo(s, { name = %q, item = %d, kind = 'OS', src = 'Boss', t = time() }).id"):format(who, item))
end
local function keepers()
    local out = {}
    for _, name in ipairs(ALL) do out[#out + 1] = tostring(C(name, "NS.SyncKeeperName()")) end
    return table.concat(out, "/")
end
local VVV = ("%s/%s/%s"):format(VULO, VULO, VULO)

BUS.setRaid(ALL)
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.item(32235, "Fluchsicht des Sargeras", 4)
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
C(FRAK, "NS.Set('loot.lead', 'me')")
BUS.tick(30)
assert(keepers() == VVV, keepers())
local a1 = add(VULO, FRAK, 32235)
BUS.tick(10)

---------------------------------------------------------------------------
-- A2. a boss fight longer than any claim: the lockdown holds the keeper's state in his queue, the
-- claims do not run out, Fraktur's change waits as a wish and reaches the keeper after the fight
---------------------------------------------------------------------------
BUS.tick(230)
BUS.lock(true)
for _ = 1, 100 do
    BUS.tick(10)
    assert(keepers() == VVV, "the keeper holds through the fight: " .. keepers())
end
assert(C(FRAK, "NS.SyncIsKeeper()") == false)
S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { kind = 'MS', note = 'Tausch' })")
local a9 = add(FRAK, KIM, 30009)
BUS.tick(5)
assert(S(FRAK, "#s.sync.pending") == 2, "Fraktur's changes wait as wishes")
BUS.lock(false)
BUS.tick(30)
for _, name in ipairs(ALL) do
    local a = award(name, a1)
    assert(a.kind == "MS" and (name == KIM or a.note == "Tausch"), name .. ": Fraktur's change reached everyone")
    assert(award(name, a9) ~= nil, name .. ": Fraktur's award too")
end
assert(S(FRAK, "#s.sync.pending") == 0)
assert(S(KIM, "s.sync.rev") == S(VULO, "s.sync.rev") and S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash"))

-- any keeper traffic keeps a claim fresh: without a single state (ST) for 20 minutes, the
-- snapshots alone keep Vulo the keeper everywhere
BUS.drop(function(m) return m.sender == VULO and m.kind == "ST" end)
for i = 1, 12 do
    add(VULO, KIM, 31000 + i)
    BUS.tick(100)
    assert(keepers() == VVV, "snapshots keep the claim: " .. keepers())
end
BUS.drop(nil)
BUS.tick(10)
assert(S(KIM, "#s.awards") == S(VULO, "#s.awards"))

---------------------------------------------------------------------------
-- A4. malformed wishes: a kill far outside the raid's days, an award time that is not a number
-- or far away; the keeper answers NO BAD, takes nothing, and the sync goes on
---------------------------------------------------------------------------
local key = S(VULO, "NS.RaidKey(s)")
local kills0 = S(VULO, "#s.kills")
local bad0 = BUS.count(function(m) return m.kind == "NO" and m.sender == VULO and m.text:find("\tBAD\t", 1, true) end)
local function op(opid, body)
    C(FRAK, ([[return NS.CommSendBlob("OP", %q, { k = %q, o = %q, b = 0, %s }, "WHISPER", "Vulo Sturmwind")]]):format(key, key, opid, body))
    BUS.tick(4)
end
op("aaaaaaaaaaa1", [[op = "kill+", x = { 0, "X", 1e15, 1e15, 1 }]])
op("aaaaaaaaaaa2", [[op = "kill+", x = { 0, "X", math.floor(time()) + 5 * 86400, math.floor(time()) + 5 * 86400, 1 }]])
op("aaaaaaaaaaa3", [[op = "kill+", x = { 0, "X", 0/0, math.floor(time()), 1 }]])
op("aaaaaaaaaaa4", [[op = "add", a = { "0123456789ab", "Fraktur", 1234, 0/0, "MS", "X", "player", "", "", 0 }]])
op("aaaaaaaaaaa5", [[op = "add", a = { "0123456789ac", "Fraktur", 1234, 1e15, "MS", "X", "player", "", "", 0 }]])
op("aaaaaaaaaaa6", [[op = "add", a = { "0123456789ad", "Fraktur", 1234, math.floor(time()) + 0.5, "MS", "X", "player", "", "", 0 }]])
assert(BUS.count(function(m) return m.kind == "NO" and m.sender == VULO and m.text:find("\tBAD\t", 1, true) end) == bad0 + 6,
    "six times NO BAD")
assert(S(VULO, "#s.kills") == kills0, "no kill taken")
for _, id in ipairs({ "0123456789ab", "0123456789ac", "0123456789ad" }) do assert(award(VULO, id) == nil, "no award " .. id) end
-- a wish with a good time is still taken
op("aaaaaaaaaaa7", [[op = "kill+", x = { 0, "Hand", math.floor(time()) - 60, math.floor(time()) - 30, 1 }]])
assert(S(VULO, "#s.kills") == kills0 + 1, "a kill by hand inside the raid's days is taken")
local aL = add(VULO, FRAK, 30102)
BUS.tick(30)
assert(award(FRAK, aL) ~= nil and award(KIM, aL) ~= nil, "the sync goes on")
assert(S(FRAK, "s.sync.rev") == S(VULO, "s.sync.rev") and S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash"))
assert(S(VULO, "local sp, so = NS.SyncBuild(s); return (NS.SyncCheck(sp, so, s))") == true)

---------------------------------------------------------------------------
-- A3. a long progression night: 101 wipes are more kill headers than 2.1 allowed; the snapshot
-- still passes its own check and reaches the officers
---------------------------------------------------------------------------
S(VULO, [[for i = 1, 101 do NS.AddKill(s, { name = "Muru", enc = 0, ok = false, t = time() - 7200 + i * 30, start = time() - 7200 + i * 30 - 20 }) end]])
BUS.tick(15)
local aK = add(VULO, FRAK, 30101)
assert(S(VULO, "local sp, so = NS.SyncBuild(s); return (NS.SyncCheck(sp, so, s))") == true, "the keeper's snapshot passes its check")
BUS.tick(120)
assert(award(FRAK, aK) ~= nil and award(KIM, aK) ~= nil, "the award reached the officer and the raider")
assert(S(FRAK, "s.sync.rev") == S(VULO, "s.sync.rev") and S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash"), "the officer took it whole")
assert(S(FRAK, "#s.kills") >= 101, "the kill headers came along")
assert(C(FRAK, "NS.SyncStats().refused") == 0, "nothing refused")
-- more than 400 kill headers: the oldest wipes stay out of the snapshot, every kill stays in
local capped = S(VULO, [[local saved = s.kills
    local list = {}
    for i = 1, 450 do list[i] = { name = "Muru", enc = 0, ok = false, t = time() - 80000 + i * 60, start = time() - 80000 + i * 60 - 20, src = "enc", n = 25 } end
    for i = 1, 5 do list[#list + 1] = { name = "Kil'jaeden", enc = 729, ok = true, t = time() - 90000 + i * 60, start = time() - 90000 + i * 60 - 30, src = "enc", n = 25 } end
    s.kills = list
    local sp, so = NS.SyncBuild(s)
    local ok, why = NS.SyncCheck(sp, so, s)
    s.kills = saved
    local kills = 0
    for _, r in ipairs(so.x) do if r[5] == 1 then kills = kills + 1 end end
    return { ok = ok, why = why, n = #so.x, kills = kills, first = so.x[1][4] }]])
assert(capped.ok == true, "400 at most: " .. tostring(capped.why))
assert(capped.n == 400 and capped.kills == 5, ("%d headers, %d kills"):format(capped.n, capped.kills))
-- a kill header outside the raid's days (a broken saved file) stays out instead of breaking it
assert(S(VULO, [[local saved = s.kills
    s.kills = { { name = "X", enc = 0, ok = true, t = 1e12, start = 1e12 } }
    local sp, so = NS.SyncBuild(s)
    local ok = NS.SyncCheck(sp, so, s)
    s.kills = saved
    return ok == true and #so.x == 0]]), "a header outside the raid's days stays out")
-- a bench above 40 (merged from two keepers): the earliest 40 go, the snapshot passes
local bench = S(VULO, [[local saved = s.bench
    s.bench = {}
    for i = 1, 45 do s.bench[("Bank%s"):format(string.char(64 + i % 26) .. string.char(97 + math.floor(i / 26)))] = { t = s.start + i, class = "MAGE" } end
    local sp, so = NS.SyncBuild(s)
    local ok, why = NS.SyncCheck(sp, so, s)
    local n = 0
    for _ in pairs(so.b) do n = n + 1 end
    s.bench = saved
    return { ok = ok, why = why, n = n }]])
assert(bench.ok == true and bench.n == 40, ("bench %d, %s"):format(bench.n, tostring(bench.why)))
