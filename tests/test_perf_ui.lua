-- Work the window saves without changing what it shows: the Statistik page keeps its statistics until
-- the raids change (a sort, a row, the class or the role builds nothing; an award builds again, the
-- same rows as without the cache); data changes and settings redraw the window once at the next frame
-- (ns.RefreshSoon), a click at once; "Zurücksetzen" of a section is one redraw; the Raid-Check page
-- reads the raid once after a burst of roster events; the gear window computes nothing on a reopen.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local DAY = 86400
local now = STUB.now

STUB.player, STUB.class, STUB.level = "Vuloo", "PRIEST", 60
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" }, { name = "Fraktur", rank = 3, class = "SHAMAN" },
               { name = "Chorf", rank = 3, class = "WARRIOR" } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.playerRaidIndex = 1
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
NS.Set("ui.view", "officer")

local function raid(id, ago)
    local start = now - ago * DAY
    local s = { id = id, date = date("%Y-%m-%d", start), zone = "Der Schwarze Tempel", instanceID = 564, start = start, last = start + 3600,
                members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    AmisiaDB.sessions[#AmisiaDB.sessions + 1] = s
    return s
end
local s1 = raid("s1", 12)
s1.members = { Vuloo = { class = "PRIEST", first = s1.start }, Fraktur = { class = "SHAMAN", first = s1.start },
               Chorf = { class = "WARRIOR", first = s1.start, late = true }, Zappo = { class = "MAGE", first = s1.start } }
local s2 = raid("s2", 2)
s2.members = { Vuloo = { class = "PRIEST", first = s2.start }, Zappo = { class = "MAGE", first = s2.start } }
STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)
NS.AddAwardTo(s1, { name = "Fraktur", item = 32235, kind = "MS", src = "?", t = s1.start + 60 })
NS.AddAwardTo(s2, { name = "Zappo", item = 32837, kind = "OS", src = "?", t = s2.start + 60 })
NS.AddAwardTo(s2, { name = "Zappo", item = 32235, kind = "MS", src = "?", t = s2.start + 90 })

---------------------------------------------------------------------------
-- 1. Statistik: built once, sort/row/class/role build nothing, an award builds again
---------------------------------------------------------------------------
local builds = 0
local build = NS.StatsBuild
NS.StatsBuild = function(...) builds = builds + 1; return build(...) end
NS.ShowStats("players")
STUB.tick(0)
local f = NS.StatsPageFrame()
local function shown()
    local out = {}
    for _, r in ipairs(f.list.rows) do
        if r:IsShown() then out[#out + 1] = r.item.name .. "=" .. r.items:GetText() end
    end
    return table.concat(out, ",")
end
-- the rows without the cache: StatsBuild with the filters, sorted as the page sorts
local function uncached(opts, col, desc)
    local res = build(opts)
    NS.StatsSort(res.players, col, desc)
    local out = {}
    for i, p in ipairs(res.players) do
        if i <= #f.list.rows then out[#out + 1] = p.name .. "=" .. p.items end
    end
    return table.concat(out, ",")
end
assert(builds == 1, "one build when the page opens: " .. builds)
assert(shown() == uncached({ range = "all" }, "items", true), shown())
assert(has(shown(), "Zappo=2") and has(shown(), "Fraktur=1"), shown())
NS.Refresh(); NS.Refresh()
assert(builds == 1, "a refresh without a change builds nothing: " .. builds)
f.heads.name:Click()
assert(builds == 1, "a sort builds nothing")
assert(shown() == uncached({ range = "all" }, "name", false), "sorted by name as without the cache: " .. shown())
f.heads.name:Click()
assert(shown() == uncached({ range = "all" }, "name", true), "the other way round: " .. shown())
f.list.rows[2]:Click()
assert(builds == 1, "a row builds nothing")
f.class.onPick("MAGE")
assert(builds == 1, "the class builds nothing")
assert(shown() == uncached({ range = "all", class = "MAGE" }, "name", true), "the class as StatsBuild filters it: " .. shown())
f.class.onPick("all")
f.role.onPick("dps")
assert(shown() == uncached({ range = "all", role = "dps" }, "name", true), "the role as StatsBuild filters it: " .. shown())
f.role.onPick("all")
assert(builds == 1)
f.range.w4:Click()
assert(builds == 2, "another range builds once")
f.range.all:Click()
assert(builds == 2, "the range before is kept")
-- an award: DATA_CHANGED drops what was kept, the next frame shows it
NS.AddAwardTo(s2, { name = "Fraktur", item = 32837, kind = "MS", src = "?", t = s2.start + 120 })
assert(builds == 2, "nothing until the next frame")
STUB.tick(0)
assert(builds == 3, "the award builds again: " .. builds)
assert(has(shown(), "Fraktur=2"), shown())
assert(shown() == uncached({ range = "all" }, "name", true), shown())
-- the alt list and a raid more drop it too
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-01\nA Zappo Fraktur\n#END"))
NS.Refresh()
assert(builds == 4, "the alt list builds again: " .. builds)
assert(has(shown(), "Fraktur=4") and not has(shown(), "Zappo"), "an alt counts for its main: " .. shown())
NS.ClearAlts()
NS.Refresh()
local s3 = raid("s3", 1)
s3.members = { Chorf = { class = "WARRIOR", first = s3.start } }
NS.Refresh()
assert(builds == 6, "a new raid builds again: " .. builds)
NS.StatsBuild = build

---------------------------------------------------------------------------
-- 2. ns.RefreshSoon: many data changes, one redraw at the next frame; a click redraws at once
---------------------------------------------------------------------------
local refreshes = 0
local panel = NS.Panel("stats")
local pageRefresh = panel.refresh
panel.refresh = function(...) refreshes = refreshes + 1; return pageRefresh(...) end
for _ = 1, 10 do NS.Fire("DATA_CHANGED") end
NS.Set("record.lateAt", "20:15")
NS.Set("record.resumeHours", 3)
assert(refreshes == 0, "nothing in the same frame: " .. refreshes)
STUB.tick(0)
assert(refreshes == 1, "one redraw for twelve changes: " .. refreshes)
STUB.tick(0)
assert(refreshes == 1, "and no second one")
-- a click (a synchronous refresh) after a data change takes the place of the waiting redraw
NS.Fire("DATA_CHANGED")
f.heads.items:Click()
assert(refreshes == 2, "the click redraws at once")
STUB.tick(0)
assert(refreshes == 2, "the waiting redraw is not needed any more: " .. refreshes)
-- back to the defaults
NS.Reset("record.lateAt"); NS.Reset("record.resumeHours")
STUB.tick(0)
refreshes = 0
-- closed window: nothing waits
AmisiaFrame:Hide()
NS.Fire("DATA_CHANGED")
STUB.tick(0)
assert(refreshes == 0, "a closed window redraws nothing")
NS.ShowPage("stats")
assert(refreshes == 1, "its show redraws it")
panel.refresh = pageRefresh

---------------------------------------------------------------------------
-- 3. "Zurücksetzen" of a section: one redraw however many settings it resets
---------------------------------------------------------------------------
NS.ShowSettingsSection("record")
local sp = NS.Panel("settings")
local spRefresh = sp.refresh
local n = 0
sp.refresh = function(...) n = n + 1; return spRefresh(...) end
NS.Set("record.lateAt", "20:15")
NS.Set("record.keepSessions", 70)
NS.Set("record.exportWarn", not NS.Get("record.exportWarn"))
STUB.tick(0)
n = 0
local sec
for _, s in ipairs(NS.schema) do if s.key == "record" then sec = s end end
assert(NS.ResetSections({ sec }) == 3)
STUB.tick(0)
assert(n == 1, "three settings reset, one redraw: " .. n)
sp.refresh = spRefresh
-- the kept settings groups are the same as built anew, and follow the view
local function groupKeys()
    local out = {}
    for _, g in ipairs(NS.SettingsGroups()) do
        local secs = {}
        for _, s in ipairs(g.sections) do secs[#secs + 1] = s.key end
        out[#out + 1] = g.key .. ":" .. table.concat(secs, ",")
    end
    return table.concat(out, " ")
end
local officerGroups = groupKeys()
assert(NS.SettingsGroups() == NS.SettingsGroups(), "kept while nothing changes")
assert(has(officerGroups, "bank"), officerGroups)
NS.Set("ui.view", "raider")
assert(not has(groupKeys(), "bank"), "the raider view has no officer section: " .. groupKeys())
NS.Set("ui.view", "officer")
assert(groupKeys() == officerGroups, "back as before")
STUB.tick(0)

---------------------------------------------------------------------------
-- 4. Raid-Check: a burst of roster events reads the raid once, 0.5 s later, only while the page is open
---------------------------------------------------------------------------
local reads = 0
_G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
NS.Dispatch("raidcheck")
STUB.tick(0)
assert(NS.CurrentPage() == "raidcheck", "the officer's page: " .. tostring(NS.CurrentPage()))
local rp = NS.Panel("raidcheck")
local rcRefresh = rp.refresh
rp.refresh = function(...) reads = reads + 1; return rcRefresh(...) end
for _ = 1, 30 do STUB.fire("GROUP_ROSTER_UPDATE") end
assert(reads == 0, "nothing during the burst: " .. reads)
STUB.tick(0.4)
assert(reads == 0, "not before 0.5 s")
STUB.tick(0.2)
assert(reads == 1, "one read after the burst: " .. reads)
-- its own messages stay immediate
NS.Fire("RAIDCHECK")
assert(reads == 2, "an answer shows at once")
-- another page: the roster reads nothing
NS.ShowPage("stats")
reads = 0
for _ = 1, 5 do STUB.fire("GROUP_ROSTER_UPDATE") end
STUB.tick(1)
assert(reads == 0, "another page open: nothing read")
rp.refresh = rcRefresh

---------------------------------------------------------------------------
-- 5. the gear window: a reopen with nothing changed computes nothing
---------------------------------------------------------------------------
if NS.ToggleGearFrame and NS.Gear.Available() then
    local calls = 0
    local bisFor = NS.BisFor
    NS.BisFor = function(...) calls = calls + 1; return bisFor(...) end
    NS.ToggleGearFrame()
    assert(AmisiaGearFrame:IsShown())
    assert(calls > 0, "the first open computes")
    calls = 0
    AmisiaGearFrame:Hide()
    NS.ToggleGearFrame()
    assert(calls == 0, "a reopen computes nothing: " .. calls)
    NS.GearRefresh(true)
    assert(calls == 0, "nor a refresh with the same choices")
    AmisiaDB.settings.gear.class = AmisiaDB.settings.gear.class == "MAGE" and "WARRIOR" or "MAGE"
    NS.GearRefresh(true)
    assert(calls > 0, "another class computes")
    calls = 0
    NS.BisBump()
    NS.GearRefresh(true)
    assert(calls > 0, "a new BiS stamp computes")
    calls = 0
    NS.GearRefresh(true, true)
    assert(calls > 0, "item data arriving computes with the same key")
    NS.BisFor = bisFor
    AmisiaGearFrame:Hide()
    print("gear window checked")
end
print("perf ui ok")
