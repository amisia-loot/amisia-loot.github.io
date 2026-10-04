-- Saved data of 1.4: awards without ids and no tombstone lists. Loading gives every award a fixed
-- id and to = "player", keeps an exported raid "done" and a changed one "changed", and a second load
-- changes nothing.
assert(AmisiaDB.awardsVersion == 1, "an empty saved table is marked on load")

local function raid(id, dateStr, awards)
    return { id = id, date = dateStr, zone = "Der Schwarze Tempel", instanceID = 564, start = 1756757000, last = 1756760000,
             members = { Vuloo = { class = "PRIEST", first = 1756757000, last = 1756760000 }, Fraktur = { class = "SHAMAN", first = 1756757000, last = 1756760000 } },
             loot = {}, items = {}, drops = {}, awards = awards }
end
local done = raid("20260901200000-564", "2026-09-01", {
    { name = "Fraktur", item = 32235, t = 1756757600, kind = "MS", src = "Illidan Sturmgrimm" },
    -- two copies of one token to the same player in the same second
    { name = "Fraktur", item = 32235, t = 1756757600, kind = "MS", src = "Illidan Sturmgrimm" },
    { name = "Vuloo", item = 32837, t = 1756758000, kind = "OS", src = "Illidan Sturmgrimm" },
})
local changed = raid("20260902200000-564", "2026-09-02", {
    { name = "Vuloo", item = 32235, t = 1756844000, kind = "SR", src = "Mutter Shahraz" },
})
local fresh = raid("20260903200000-564", "2026-09-03", {
    { name = "Fraktur", item = 32837, t = 1756930400, kind = "-", src = "?" },
})
AmisiaDB.sessions = { done, changed, fresh }
-- the marks 1.4 stored: the fingerprint of the old export form
local oldMark = NS.SessionHash(done, true)
assert(oldMark == NS.SessionHash(done), "before the move both forms agree")
AmisiaDB.exported = { [done.id] = { h = oldMark, at = 1756761000 }, [changed.id] = { h = "0000000000000000", at = 1756848000 } }
AmisiaDB.awardsVersion = nil

-- load again: the core frame runs the move on ADDON_LOADED
local core
for f in pairs(STUB.frames) do
    if f.events.PLAYER_ENTERING_WORLD and f.events.CHAT_MSG_LOOT then core = f end
end
assert(core, "core event frame found")
core:RegisterEvent("ADDON_LOADED")
STUB.fire("ADDON_LOADED", "Amisia")

assert(AmisiaDB.awardsVersion == 1, "version written")
for _, s in ipairs(AmisiaDB.sessions) do
    assert(type(s.gone) == "table" and #s.gone == 0, "tombstone list added")
    for _, a in ipairs(s.awards) do
        assert(type(a.id) == "string" and a.id:match("^%x%x%x%x%x%x%x%x%x%x%x%x$"), "12 hex id: " .. tostring(a.id))
        assert(a.to == "player", "old awards went to players")
        assert(a.edited == nil and a.orig == nil and a.note == nil and a.manual == nil, "no invented history")
    end
end
assert(done.awards[1].id == NS.Checksum(done.id .. "\tFraktur\t32235\t1756757600"):sub(1, 12), "the id comes from raid, name, item and time")
assert(done.awards[1].id ~= done.awards[2].id, "two identical hand-outs still get two ids")
assert(done.awards[1].id ~= done.awards[3].id and changed.awards[1].id ~= fresh.awards[1].id)
assert(NS.ExportState(done) == "done", "an exported raid stays done")
assert(AmisiaDB.exported[done.id].h == NS.SessionHash(done) and AmisiaDB.exported[done.id].at == 1756761000, "its mark is the new fingerprint, the time stays")
assert(NS.ExportState(changed) == "changed", "a changed raid stays changed")
assert(AmisiaDB.exported[changed.id].h == "0000000000000000", "a mark that did not match is left alone")
assert(NS.ExportState(fresh) == "new")
assert(NS.SessionHash(done, true) == oldMark, "the old form of the fingerprint is unchanged by the move")

-- the fingerprint of the old form ignores what 1.5 adds
done.awards[1].note = "Tausch"
done.awards[1].edited = 1756760000
done.gone[1] = { id = "abcdefabcdef", name = "Vuloo", item = 1, t = 1756757000, kind = "-", src = "?", to = "player", deleted = 1756760000 }
assert(NS.SessionHash(done, true) == oldMark, "the old form has no AX, AS or AD")
done.awards[1].note, done.awards[1].edited, done.gone[1] = nil, nil, nil

-- a second load changes nothing
local ids, marks = {}, {}
for _, s in ipairs(AmisiaDB.sessions) do
    for i, a in ipairs(s.awards) do ids[s.id .. i] = a.id end
    marks[s.id] = AmisiaDB.exported[s.id] and AmisiaDB.exported[s.id].h
end
core:RegisterEvent("ADDON_LOADED")
STUB.fire("ADDON_LOADED", "Amisia")
for _, s in ipairs(AmisiaDB.sessions) do
    for i, a in ipairs(s.awards) do assert(a.id == ids[s.id .. i], "id kept on the second load") end
    assert((AmisiaDB.exported[s.id] and AmisiaDB.exported[s.id].h) == marks[s.id], "mark kept on the second load")
end
assert(NS.ExportState(done) == "done" and NS.ExportState(changed) == "changed" and NS.ExportState(fresh) == "new")
NS.MigrateAwards(AmisiaDB)
assert(done.awards[1].id == ids[done.id .. 1], "the move with the version in place does nothing")

-- the same 1.4 data loaded elsewhere gives the same ids
for _, s in ipairs(AmisiaDB.sessions) do
    for _, a in ipairs(s.awards) do a.id = nil end
    s.gone = nil
end
AmisiaDB.awardsVersion = nil
NS.MigrateAwards(AmisiaDB)
for _, s in ipairs(AmisiaDB.sessions) do
    for i, a in ipairs(s.awards) do assert(a.id == ids[s.id .. i], "deterministic id") end
end

-- an award written after the move already carries its id and is never touched by it
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local a = NS.AddAward("Fraktur", 32235, "MS", "Illidan Sturmgrimm")
local id = a.id
AmisiaDB.awardsVersion = nil
NS.MigrateAwards(AmisiaDB)
assert(a.id == id and a.to == "player")
