--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug Mara_Stein]]
-- Wishes and conflicts of the raid sync (Sync.lua): officers that do not keep the raid send every
-- change as a wish (OP) to the keeper, who checks it against the award's revision and answers OK
-- or NO. Vulo Sturmwind is master looter and keeper, Fraktur and Mara Stein are officers, Kim
-- Eisherz a raider (with a forced officer view later), Pug a guest outside the guild.
local VULO, FRAK, KIM, PUG, MARA = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug", "Mara Stein"
local OFFICERS = { VULO, FRAK, MARA }

local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function count(name, text)
    return C(name, ("local n = 0; for _, m in ipairs(STUB.messages) do if m:find(%q, 1, true) then n = n + 1 end end; return n"):format(text))
end
local function award(name, id)
    return S(name, ([[local a, _, gone = NS.FindAward(s, %q)
        if not a then return nil end
        return { name = a.name, kind = a.kind, to = a.to, note = a.note, v = a.v, gone = gone, item = a.item, manual = a.manual }]]):format(id))
end
local function awards(name)
    return S(name, [[local out = {}
        for _, a in ipairs(s.awards) do out[a.id] = { name = a.name, kind = a.kind, to = a.to, note = a.note } end
        return out]])
end
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function pending(name) return S(name, "s.sync and s.sync.pending and #s.sync.pending or 0") end
local function conflicts(name) return S(name, "s.sync and s.sync.conflicts and #s.sync.conflicts or 0") end
local function settle() BUS.tick(8) end
local function ops(from, t) return BUS.count(function(m) return m.kind == "BL" and m.sender == from and m.text:find("^1BL\tOP\t") and (not t or m.t >= t) end) end
-- every officer holds the keeper's awards: same ids, names, kinds, targets and notes
local function same(names, why)
    local want = awards(VULO)
    for _, name in ipairs(names) do
        local got = awards(name)
        assert(size(got) == size(want), ("%s: %d awards, the keeper %d (%s)"):format(name, size(got), size(want), why))
        for id, a in pairs(want) do
            local g = got[id]
            assert(g and g.name == a.name and g.kind == a.kind and g.to == a.to, ("%s: award %s differs (%s)"):format(name, id, why))
            if name ~= KIM then assert(g.note == a.note, ("%s: note of %s (%s)"):format(name, id, why)) end
        end
    end
end
local function setMaster(i)
    for _, name in ipairs(CLIENTS) do
        C(name, ([[STUB.lootMethod = %d; STUB.mlRaidID = %s; STUB.fire("PARTY_LOOT_METHOD_CHANGED")]]):format(i and 2 or 0, tostring(i)))
    end
end

---------------------------------------------------------------------------
-- the raid
---------------------------------------------------------------------------
BUS.setRaid({ VULO, FRAK, KIM, PUG, MARA })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = MARA, rank = 2 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur" or STUB.player == "Mara Stein"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.item(32235, "Fluchsicht des Sargeras", 4)
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true)
for _, name in ipairs({ FRAK, KIM, MARA }) do assert(C(name, "NS.SyncKeeperName()") == VULO, name) end
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 32235, kind = 'MS', src = 'Ragnaros', note = 'Tausch', t = time() }).id")
local a2 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 30000, kind = 'OS', src = 'Ragnaros', t = time() }).id")
settle()
same({ FRAK, MARA, KIM }, "start")

---------------------------------------------------------------------------
-- an officer's change: a wish, applied by the keeper, confirmed, the snapshot comes back
---------------------------------------------------------------------------
local undoLabel = C(VULO, "NS.UndoLabel()")
local v0 = award(VULO, a1).v
local t0 = C(FRAK, "STUB.clock")
assert(S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { kind = 'OS' }) ~= nil"))
assert(award(FRAK, a1).kind == "OS", "the change works at once")
assert(pending(FRAK) == 1 and S(FRAK, "NS.SyncWaiting(s, '" .. a1 .. "')") == true, "a wish waits")
local p = S(FRAK, "s.sync.pending[1]")
assert(type(p.opid) == "string" and #p.opid == 12 and p.opid:match("^%x+$") and p.base == v0 and p.op.op == "edit" and p.op.id == a1, "the wish")
assert(p.op.fields.kind == "OS" and p.op.fields.name == nil, "only the changed field")
settle()
assert(ops(FRAK, t0) == 1, "one wish went")
assert(BUS.count({ kind = "BL", sender = FRAK, chan = "RAID", from = t0 }) == 0, "a wish goes by whisper only")
assert(BUS.count({ kind = "OK", sender = VULO, target = FRAK, from = t0 }) == 1, "the keeper confirms")
assert(award(VULO, a1).kind == "OS" and award(VULO, a1).v == v0 + 1, "applied, the award's revision rises")
assert(S(VULO, "s.sync.by['" .. a1 .. "']") == FRAK, "the keeper remembers who changed it")
assert(C(VULO, "NS.UndoLabel()") == undoLabel, "no undo step at the keeper for someone else's change")
assert(pending(FRAK) == 0 and S(FRAK, "NS.SyncWaiting(s, '" .. a1 .. "')") == false, "the wish is gone")
assert(award(KIM, a1).kind == "OS" and award(MARA, a1).kind == "OS", "the snapshot reached everyone")
assert(award(FRAK, a1).v == v0 + 1)
same({ FRAK, MARA, KIM }, "after the first wish")

---------------------------------------------------------------------------
-- the same field at the same time: the keeper was first, Fraktur gets a conflict
---------------------------------------------------------------------------
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { name = 'Kim Eisherz' })")
S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { name = 'Mara Stein' })")
settle()
assert(BUS.count({ kind = "NO", sender = VULO, target = FRAK }) == 1, "refused")
assert(award(VULO, a1).name == "Kim Eisherz", "the keeper's change stays")
assert(pending(FRAK) == 0 and conflicts(FRAK) == 1, "a conflict instead of the wish")
local c = S(FRAK, "s.sync.conflicts[1]")
assert(c.id == a1 and c.op == "edit" and c.mine.name == "Mara Stein" and c.by == VULO and c.why == "CONFLICT", "the conflict")
assert(award(FRAK, a1).name == "Kim Eisherz", "Fraktur's state is the keeper's again")
assert(count(FRAK, "Konflikt bei Fluchsicht des Sargeras: Vulo Sturmwind hat die Vergabe zuerst geändert. Siehe Seite Vergaben.") == 1, "said once")
same({ FRAK, MARA, KIM }, "after the conflict")
-- "Meine übernehmen": the wish goes again on the current revision and wins
assert(S(FRAK, "NS.SyncResolve(s, s.sync.conflicts[1].opid, true)") == true)
settle()
assert(conflicts(FRAK) == 0 and pending(FRAK) == 0)
assert(award(VULO, a1).name == "Mara Stein" and award(FRAK, a1).name == "Mara Stein" and award(KIM, a1).name == "Mara Stein", "mine won")
-- a second conflict, thrown away
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { kind = 'SR' })")
S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { kind = 'MS' })")
settle()
assert(conflicts(FRAK) == 1)
assert(S(FRAK, "NS.SyncResolve(s, s.sync.conflicts[1].opid, false)") == true)
settle()
assert(conflicts(FRAK) == 0 and award(FRAK, a1).kind == "SR" and award(VULO, a1).kind == "SR", "Verwerfen keeps the keeper's")
assert(count(FRAK, "Konflikt bei") == 2, "every conflict said once")
same({ FRAK, MARA, KIM }, "after resolving")

---------------------------------------------------------------------------
-- different fields at the same time: both changes hold
---------------------------------------------------------------------------
S(VULO, "NS.EditAward(s, '" .. a2 .. "', { note = 'zweiter Wurf' })")
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { kind = 'MS' })")
S(MARA, "NS.EditAward(s, '" .. a1 .. "', { note = 'von Mara' })")
settle()
assert(conflicts(FRAK) == 0 and pending(FRAK) == 0 and pending(MARA) == 0, "no conflict")
local v2 = award(VULO, a2)
assert(v2.note == "zweiter Wurf" and v2.kind == "MS", "both changes")
assert(award(VULO, a1).note == "von Mara")
same({ FRAK, MARA, KIM }, "different fields")

---------------------------------------------------------------------------
-- a change of an award the keeper deleted meanwhile: GONE, then "restore and change"
---------------------------------------------------------------------------
S(VULO, "NS.DeleteAward(s, '" .. a2 .. "')")
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { kind = 'SR' })")
settle()
assert(conflicts(FRAK) == 1 and S(FRAK, "s.sync.conflicts[1].why") == "GONE", "GONE")
assert(award(FRAK, a2).gone == true, "deleted at Fraktur too")
assert(S(FRAK, "NS.SyncResolve(s, s.sync.conflicts[1].opid, true)") == true)
settle()
local back = award(VULO, a2)
assert(back and not back.gone and back.kind == "SR", "restored with Fraktur's change")
assert(conflicts(FRAK) == 0)
same({ FRAK, MARA, KIM }, "restored")
-- a deletion of an award the keeper changed meanwhile is a conflict too (no change lost)
S(VULO, "NS.EditAward(s, '" .. a2 .. "', { note = 'bleibt' })")
S(FRAK, "NS.DeleteAward(s, '" .. a2 .. "')")
settle()
assert(conflicts(FRAK) == 1 and S(FRAK, "s.sync.conflicts[1].op") == "delete")
assert(award(VULO, a2).gone == false and award(FRAK, a2).gone == false, "the award lives")
assert(S(FRAK, "NS.SyncResolve(s, s.sync.conflicts[1].opid, false)") == true)

---------------------------------------------------------------------------
-- undo at Fraktur becomes the matching wish
---------------------------------------------------------------------------
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { kind = 'OS' })")
settle()
assert(award(VULO, a2).kind == "OS")
assert(C(FRAK, "NS.UndoAward()"):find("Ändern", 1, true))
assert(pending(FRAK) == 1 and S(FRAK, "s.sync.pending[1].op.op") == "edit")
settle()
assert(award(VULO, a2).kind == "SR" and pending(FRAK) == 0, "the undo reached the keeper")
local a3 = S(FRAK, "NS.AddAwardTo(s, { name = 'Mara Stein', item = 30003, kind = 'MS', src = 'Golemagg', t = time() }).id")
settle()
assert(award(VULO, a3) and award(VULO, a3).name == "Mara Stein", "an added award reaches the keeper with its id")
assert(C(FRAK, "NS.UndoAward()"):find("Hinzufügen", 1, true))
settle()
assert(award(VULO, a3).gone == true and award(KIM, a3).gone == true, "the undone addition is deleted")
same({ FRAK, MARA, KIM }, "after the undo")

---------------------------------------------------------------------------
-- the keeper's plus-one counts for raiders
---------------------------------------------------------------------------
C(VULO, [[STUB.weekReset = 3 * 86400
    table.insert(AmisiaDB.sessions, 1, { id = "w1", date = "2026-01-01", instanceID = 409, zone = "Alt", start = time() - 86400,
        last = time() - 80000, members = {}, loot = {}, items = {}, drops = {}, awards = {
        { id = "0123456789ab", name = "Mara Stein", item = 1, kind = "MS", src = "X", t = time() - 86000, to = "player" } }, gone = {} })
    NS.Set("awards.plusScope", "week")]])
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { kind = 'MS' })")
settle()
assert(S(VULO, "NS.PlusCount('Mara Stein')") == 2 and S(KIM, "s.sync.plus.n['Mara Stein']") == 2)
assert(C(KIM, "NS.PlusCount('Mara Stein')") == 2, "Kim counts with the keeper's number")
assert(C(KIM, "NS.PlusCount('Fraktur')") == 0)
C(VULO, "NS.Reset('awards.plusScope'); table.remove(AmisiaDB.sessions, 1); STUB.weekReset = nil")
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { kind = 'SR' })")
settle()
assert(C(KIM, "NS.PlusCount('Mara Stein')") == 0)

---------------------------------------------------------------------------
-- without a keeper: Fraktur works for himself, the wishes wait and go when one is there
---------------------------------------------------------------------------
C(VULO, "NS.Set('sync.enabled', false)")
BUS.tick(15)
assert(C(FRAK, "NS.SyncKeeperName()") == nil, "no keeper")
local tn = C(FRAK, "STUB.clock")
local a4 = S(FRAK, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 30004, kind = 'MS', src = 'Sulfuron', t = time(), manual = true }).id")
S(FRAK, "NS.EditAward(s, '" .. a4 .. "', { note = 'von Hand' })")
S(FRAK, "NS.BenchAdd(s, 'Bob', { note = 'ab 21 Uhr', class = 'MAGE' })")
BUS.tick(40)
assert(ops(FRAK, tn) == 0, "nothing to send to")
assert(pending(FRAK) == 2, "an unsent change joins its addition: " .. pending(FRAK))
assert(S(FRAK, "s.sync.pending[1].op.a.note") == "von Hand")
C(VULO, "NS.Reset('sync.enabled')")
BUS.tick(20)
assert(C(FRAK, "NS.SyncKeeperName()") == VULO)
settle()
local got = award(VULO, a4)
assert(got and got.name == "Kim Eisherz" and got.note == "von Hand" and got.manual == true, "added with Fraktur's id")
assert(S(VULO, "s.bench.Bob and s.bench.Bob.note") == "ab 21 Uhr" and S(VULO, "s.bench.Bob.by") == FRAK, "the bench entry too")
assert(pending(FRAK) == 0)
local n4 = S(VULO, "local n = 0; for _, a in ipairs(s.awards) do if a.id == '" .. a4 .. "' then n = n + 1 end end; return n")
assert(n4 == 1, "no double")
same({ FRAK, MARA, KIM }, "after the keeper came back")
-- the same addition once more (a late retry): confirmed, no double
local okBefore = BUS.count({ kind = "OK", sender = VULO, target = FRAK })
S(FRAK, [[local a = NS.FindAward(s, ']] .. a4 .. [[')
    NS.CommSendBlob("OP", NS.RaidKey(s), { k = NS.RaidKey(s), o = "abcdefabcdef", b = 0, op = "add",
        a = { a.id, a.name, a.item, a.t, a.kind, a.src, a.to, "", "", 1 } }, "WHISPER", "Vulo Sturmwind")]])
settle()
assert(BUS.count({ kind = "OK", sender = VULO, target = FRAK }) == okBefore + 1, "a double add is confirmed")
assert(S(VULO, "local n = 0; for _, a in ipairs(s.awards) do if a.id == '" .. a4 .. "' then n = n + 1 end end; return n") == 1)

---------------------------------------------------------------------------
-- the first snapshot of a new keeper: own awards it does not know go as wishes "add"
---------------------------------------------------------------------------
local own = "fedcba987654"
S(MARA, [[table.insert(s.awards, { id = "]] .. own .. [[", name = "Fraktur", item = 30005, kind = "OS", src = "Garr", t = time(), to = "player",
    manual = true }); s.sync.keeper = nil; NS.BenchAdd(s, 'Zed', { class = 'ROGUE' }); s.sync.pending = {}]])
assert(S(MARA, "s.bench.Zed ~= nil"))
S(VULO, "NS.EditAward(s, '" .. a4 .. "', { kind = 'OS' })")
settle()
settle()
local mine = award(VULO, own)
assert(mine and mine.name == "Fraktur" and mine.kind == "OS", "the award only Mara had is at the keeper")
assert(S(VULO, "s.bench.Zed ~= nil"), "and her bench entry")
assert(pending(MARA) == 0)
same({ FRAK, MARA, KIM }, "the first snapshot")

---------------------------------------------------------------------------
-- a raider with a forced officer view: DENIED, said once; a guest gets no answer
---------------------------------------------------------------------------
C(KIM, "NS.Set('ui.view', 'officer')")
S(KIM, "NS.EditAward(s, '" .. a1 .. "', { note = 'Kim war hier' })")
assert(pending(KIM) == 1)
settle()
assert(BUS.count(function(m) return m.kind == "NO" and m.sender == VULO and m.target == KIM and m.text:find("\tDENIED\t", 1, true) end) == 1)
assert(pending(KIM) == 0 and conflicts(KIM) == 0 and award(VULO, a1).note == "von Mara", "nothing taken from Kim")
assert(count(KIM, "Vulo Sturmwind nimmt deine Änderungen nicht an (kein Offiziersrang laut Gildenliste).") == 1)
S(KIM, "NS.EditAward(s, '" .. a1 .. "', { note = 'noch mal' })")
settle()
assert(count(KIM, "nimmt deine Änderungen nicht an") == 1, "once per raid")
C(KIM, "NS.Reset('ui.view')")
local tp = C(VULO, "STUB.clock")
S(PUG, [[NS.CommSendBlob("OP", NS.RaidKey(s), { k = NS.RaidKey(s), o = "aaaaaaaaaaaa", b = 99, op = "edit", id = "]] .. a1 .. [[",
    f = { name = "Pug" }, w = {} }, "WHISPER", "Vulo Sturmwind")]])
settle()
assert(BUS.count({ sender = VULO, target = PUG, from = tp }) == 0 and award(VULO, a1).name ~= "Pug", "the guest is ignored")

---------------------------------------------------------------------------
-- the lockdown: a wish waits for the end of the fight
---------------------------------------------------------------------------
BUS.lock(true)
local tl = C(FRAK, "STUB.clock")
S(FRAK, "NS.EditAward(s, '" .. a4 .. "', { note = 'im Kampf' })")
BUS.tick(40)
assert(ops(FRAK, tl) == 0 and award(VULO, a4).note == "von Hand", "nothing in the lockdown")
assert(pending(FRAK) == 1 and S(FRAK, "s.sync.pending[1].tries") <= 1, "no tries used up in the lockdown")
BUS.lock(false)
settle()
assert(award(VULO, a4).note == "im Kampf" and pending(FRAK) == 0, "after the fight")
same({ FRAK, MARA, KIM }, "after the lockdown")

---------------------------------------------------------------------------
-- no answer: five tries 30 s apart, then the wish stays and the status says so
---------------------------------------------------------------------------
BUS.drop(function(m) return m.sender == FRAK and m.kind == "BL" and m.text:find("^1BL\tOP\t") ~= nil end)
local tt = C(FRAK, "STUB.clock")
S(FRAK, "NS.EditAward(s, '" .. a4 .. "', { kind = 'SR' })")
BUS.tick(200)
assert(ops(FRAK, tt) == 5, "five tries: " .. ops(FRAK, tt))
assert(pending(FRAK) == 1 and S(FRAK, "s.sync.pending[1].tries") == 5)
assert(S(FRAK, "(NS.SyncStatus(s))"):find("1 Änderung nicht abgeglichen", 1, true), S(FRAK, "(NS.SyncStatus(s))"))
-- the wish survives a /reload
BUS.drop(nil)
BUS.reload(FRAK)
C(FRAK, "STUB.item(32235, 'Fluchsicht des Sargeras', 4); STUB.fire('PLAYER_ENTERING_WORLD')")
BUS.tick(20)
assert(pending(FRAK) == 1, "kept over the reload")
assert(C(FRAK, "NS.SyncKeeperName()") == VULO)
C(FRAK, "NS.Dispatch('sync jetzt')")
-- the answer to the request, the confirmation and the new snapshot share the byte budget
BUS.tick(20)
assert(award(VULO, a4).kind == "SR" and pending(FRAK) == 0, "sync jetzt sends it again")
same({ FRAK, MARA, KIM }, "after the reload")

---------------------------------------------------------------------------
-- a keeper change while wishes wait: they go to the new keeper; a new keeper keeps its own
---------------------------------------------------------------------------
BUS.drop(function(m) return (m.sender == FRAK or m.sender == MARA) and m.kind == "BL" and m.text:find("^1BL\tOP\t") ~= nil end)
S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { note = 'Fraktur wartet' })")
S(MARA, "NS.EditAward(s, '" .. a4 .. "', { name = 'Mara Stein' })")
local a6 = S(MARA, "NS.AddAwardTo(s, { name = 'Vulo Sturmwind', item = 30006, kind = 'OS', src = 'Ragnaros', t = time() }).id")
BUS.tick(5)
assert(pending(FRAK) == 1 and pending(MARA) == 2)
assert(award(VULO, a1).note ~= "Fraktur wartet")
BUS.drop(nil)
local tc = C(VULO, "STUB.clock")
setMaster(2)
BUS.tick(20)
for _, name in ipairs({ VULO, FRAK, KIM, MARA }) do assert(C(name, "NS.SyncKeeperName()") == FRAK, name) end
settle()
settle()
assert(pending(FRAK) == 0, "the new keeper took its own wish over")
assert(award(FRAK, a1).note == "Fraktur wartet", "and kept it")
assert(pending(MARA) == 0, "Mara's wishes went to the new keeper")
assert(award(FRAK, a4).name == "Mara Stein" and award(FRAK, a6) and award(FRAK, a6).name == "Vulo Sturmwind")
assert(award(VULO, a1).note == "Fraktur wartet" and award(VULO, a6), "the old keeper follows")
assert(BUS.count({ kind = "OK", sender = FRAK, target = MARA, from = tc }) == 2)
same({ FRAK, MARA, KIM }, "after the keeper change")
-- the old keeper's changes go as wishes now
S(VULO, "NS.EditAward(s, '" .. a6 .. "', { kind = 'MS' })")
assert(pending(VULO) == 1)
settle()
assert(award(FRAK, a6).kind == "MS" and pending(VULO) == 0)
same({ FRAK, MARA, KIM }, "the old keeper's wish")

---------------------------------------------------------------------------
-- at most 200 waiting wishes; without a keeper the oldest is dropped with a note
---------------------------------------------------------------------------
setMaster(nil)
C(FRAK, "NS.Set('sync.enabled', false)")
C(VULO, "NS.Set('sync.enabled', false)")
BUS.tick(15)
assert(C(MARA, "NS.SyncKeeperName()") == nil)
S(MARA, "for i = 1, 201 do NS.AddAwardTo(s, { name = 'Fraktur', item = 40000 + i, kind = 'OS', src = 'Boss', t = time() }) end")
assert(pending(MARA) == 200, "200 at most")
assert(S(MARA, "s.sync.pending[1].op.a.item") == 40002, "the oldest went")
assert(count(MARA, "Zu viele wartende Änderungen") == 1, "said once")

for _, file in ipairs({ "Sync.lua", "Awards.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for ch in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. ch) end
end
