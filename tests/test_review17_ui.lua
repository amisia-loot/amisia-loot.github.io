-- Review of 1.7, the raid log page: a kill entered by hand into an old raid shows its raiders as
-- unknown, the "Boss eintragen" line stays with its raid, the Discord box keeps its selection while
-- focused, bench suggestions from a long guild roster are quick, the words for tonight before the
-- raid, Enter in the bench note.
local failed = {}
local function check(label, fn)
    local ok, err = pcall(fn)
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(err) end
end
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function leave()
    STUB.roster = {}
    STUB.instance = { name = "Shattrath", type = "none", id = 0 }
    STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(3)
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(3)
end
local function enter(name, id)
    STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
    STUB.instance = { name = name, type = "raid", id = id }
    STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(3)
    return assert(NS.Active())
end

---------------------------------------------------------------------------
-- 9. the Discord box keeps its text and selection while it has the focus
---------------------------------------------------------------------------
local live = enter("Black Temple", 564)
check("9 discord focus", function()
    STUB.fire("ENCOUNTER_START", 601, "Boss", 4, 25); STUB.tick(100)
    STUB.fire("ENCOUNTER_END", 601, "Boss", 4, 25, 1); STUB.tick(1)
    NS.ShowRaidLog("discord")
    local f = NS.RaidLogPageFrame()
    local box = f.discord.area.box
    local sets, orig = 0, box.SetText
    box.SetText = function(self, t) sets = sets + 1; return orig(self, t) end
    box:SetFocus()
    for _ = 1, 5 do STUB.tick(60); STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(3) end
    assert(sets == 0, "rebuilt while focused: " .. sets)
    assert(box:HasFocus(), "the focus stays")
    -- leaving the box brings it up to date
    box:ClearFocus()
    assert(sets >= 1 and box:GetText() == NS.RaidSummary(live)[1], "rebuilt on focus loss")
    -- another raid while focused: rebuilt
    box:SetFocus()
    sets = 0
    leave()
    local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Gruuls Unterschlupf", instanceID = 565, start = 1000,
        last = 5000, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    table.insert(AmisiaDB.sessions, 1, old)
    sets = 0
    f.raid.onPick(old.id)
    assert(sets >= 1 and has(box:GetText(), "Gruuls Unterschlupf"), "another raid is shown at once")
    box:ClearFocus()
    table.remove(AmisiaDB.sessions, 1)
end)
if NS.Active() then leave() end

---------------------------------------------------------------------------
-- 7. a kill entered by hand into a raid that is over: who was there is unknown
---------------------------------------------------------------------------
check("7 hand kill", function()
    assert(not NS.Active())
    NS.ShowRaidLog("verlauf", live.id)
    local f = NS.RaidLogPageFrame()
    f.addBoss:Click()
    local A = f.log.add
    A.pick:SetValue("Gruul"); A.pick.onPick("Gruul", true)
    A.ok:Click()
    local k = live.kills[#live.kills]
    assert(k and k.name == "Gruul" and k.src == "hand" and #k.who == 0, "the kill")
    local row
    for _, r in ipairs(f.log.list.rows) do if r:IsShown() and r.event:GetText() == "Gruul" then row = r end end
    assert(row and row.who:GetText() == "", "the who column stays empty: " .. tostring(row and row.who:GetText()))
    local detail = f.log.detail.fs:GetText()
    assert(has(detail, "Dabei:|r unbekannt (von Hand nachgetragen)"), detail)
    assert(not has(detail, "niemand") and not has(detail, "Nicht dabei"), detail)
    NS.DeleteKill(live, k)
end)

---------------------------------------------------------------------------
-- 8. the "Boss eintragen" line belongs to the raid it was opened for
---------------------------------------------------------------------------
check("8 add line", function()
    live.drops["Creature-0-1-1-1-1-1"] = { src = "Gruul", t = live.last, items = {} }
    STUB.tick(86400 * 7)
    NS.ShowRaidLog("verlauf")
    local f = NS.RaidLogPageFrame()
    f.addBoss:Click()
    local A = f.log.add
    A.pick:SetValue("Gruul"); A.pick.onPick("Gruul", false)
    assert(A:IsShown())
    local before = #live.kills
    local new = enter("Gruul's Lair", 565)
    assert(new ~= live, "a new recording")
    A.ok:Click()
    assert(#new.kills == 0 and #live.kills == before, ("no kill: new %d, old %d"):format(#new.kills, #live.kills - before))
    NS.Refresh()
    assert(not A:IsShown(), "the line is closed")
    -- opened again: empty, for the new raid
    f.addBoss:Click()
    assert(A:IsShown() and A.pick:GetValue() == nil, "fresh")
    A.pick:SetValue("Hochkönig Maulgar"); A.pick.onPick("Hochkönig Maulgar", true)
    A.ok:Click()
    assert(#new.kills == 1 and new.kills[1].name == "Hochkönig Maulgar" and new.kills[1].t >= new.start, "into the new raid")
end)
if NS.Active() then leave() end

---------------------------------------------------------------------------
-- 11. tonight before the raid with saved raids: the right words; Enter in the bench note
---------------------------------------------------------------------------
check("11 tonight", function()
    assert(not NS.Active() and #NS.Sessions() > 0)
    NS.ShowRaidLog("discord")
    local f = NS.RaidLogPageFrame()
    f.raid.onPick("next")
    assert(f.discord.hint:GetText() == "Für heute vor dem Raid gibt es noch keinen Raid-Log.", f.discord.hint:GetText())
    f.addBoss:Click()
    assert(has(lastMsg(), "Für heute vor dem Raid gibt es noch keinen Raid-Log."), lastMsg())
end)
check("11 enter in the note", function()
    NS.ShowRaidLog("bench")
    local f = NS.RaidLogPageFrame()
    f.raid.onPick("next")
    local B = f.bench
    B.pick:SetValue("Neuling"); B.pick.onPick("Neuling", true)
    B.note:SetText("ab 21 Uhr")
    B.note:SetFocus()
    B.note:GetScript("OnEnterPressed")(B.note)
    local b = AmisiaDB.benchNext
    assert(b and b.list.Neuling and b.list.Neuling.note == "ab 21 Uhr", "entered with Enter")
    assert(B.note:GetText() == "" and not B.note:HasFocus(), "the line is empty again")
end)

---------------------------------------------------------------------------
-- 10. suggestions from 1000 guild members, 500 online
---------------------------------------------------------------------------
check("10 suggestions quick", function()
    local s = enter("Black Temple", 564)
    local g = {}
    local function nm(i) local t = {} local n = i repeat t[#t + 1] = string.char(97 + n % 26); n = math.floor(n / 26) until n == 0 return "G" .. table.concat(t) .. "x" end
    for i = 1, 1000 do g[i] = { name = nm(i), class = "ROGUE", online = i <= 500 } end
    g[1001] = { name = "Chorf", class = "WARRIOR" }        -- in the raid
    g[1002] = { name = "Kim Eisherz", class = "MAGE" }     -- on the bench as "Kim"
    STUB.guild = g
    -- the client announces a new roster (the lineup's officer check reads the roster on every page refresh)
    STUB.fire("GUILD_ROSTER_UPDATE")
    s.bench.Kim = { t = STUB.now, class = "MAGE", by = "Vuloo" }
    local t0 = os.clock()
    local v = NS.BenchSuggestions(s)
    local spent = os.clock() - t0
    assert(#v == 500, #v)
    for _, x in ipairs(v) do assert(x.value ~= "Chorf" and x.value ~= "Kim Eisherz", x.value) end
    assert(spent < 0.05, ("%.3f s"):format(spent))
    STUB.guild = {}
end)

assert(#failed == 0, table.concat(failed, "\n"))
