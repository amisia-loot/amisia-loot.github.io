-- The dungeon bar (Gear/DungeonBar.lua; F-168, D-98): it shows by itself on entering a dungeon the
-- facts know and hides on leaving, first built in a fight (the /reload-in-combat path); the segments
-- Bosse, Quests, Zeit, Route each only with something to show; the lists under the bar (ticks, the
-- next boss, the quests' marks, the ready ones in green, the route's stops) and their clicks, closed by
-- a second click, Escape and leaving; moving and the saved place, the common reset; the close circle
-- until the next entry; the settings (raids off by default, the four segments); /amisia leiste.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local DBar, R, Rt = NS.DungeonBar, NS.Runs, NS.Routes
local T = NS.Theme

STUB.class, STUB.level, STUB.faction = "WARRIOR", 18, "Alliance"
STUB.roster = {}
-- the Hall of Thanes: Faldrim Anvilmar, Infurnus, Plunder, Durgen Dirgehammer
local THANES = { name = "Halle der Thane", type = "party", id = 3065 }
local E1, E2 = 3493, 3495
local ONYXIA = { name = "Onyxias Hort", type = "raid", id = 249 }
local OUT = { name = "Dun Morogh", type = "none", id = 0 }
local function enter(i)
    STUB.instance = i
    STUB.fire("PLAYER_LEAVING_WORLD")
    STUB.fire("PLAYER_ENTERING_WORLD")
end
local function kill(enc) STUB.fire("ENCOUNTER_END", enc, "Boss", 1, 5, 1) end
local function tick() STUB.tick(T.DUNGEONBAR.TICK); _G.AmisiaDungeonBar.scripts.OnUpdate(_G.AmisiaDungeonBar, T.DUNGEONBAR.TICK) end
local function rows()
    local out = {}
    for _, r in ipairs(_G.AmisiaDungeonBarList.rows) do
        if r:IsShown() then out[#out + 1] = r end
    end
    return out
end

---------------------------------------------------------------------------
-- the settings' defaults; outside nothing is built and the command says why
---------------------------------------------------------------------------
assert(NS.Get("dungeonbar.on") == true and NS.Get("dungeonbar.raids") == false, "on, raids off")
for _, s in ipairs(DBar.SEGMENTS) do assert(NS.Get("dungeonbar." .. s) == true, s) end
enter(OUT)
assert(_G.AmisiaDungeonBar == nil and DBar.Shown() == nil, "outside: not built")
NS.Dispatch("leiste")
assert(said("Die Dungeon-Leiste zeigt sich in einem Dungeon."), STUB.messages[#STUB.messages])
assert(_G.AmisiaDungeonBar == nil, "still not built")

---------------------------------------------------------------------------
-- a /reload in a fight inside the dungeon: built and shown in combat, a plain frame
---------------------------------------------------------------------------
STUB.combat = true
enter(THANES)
local bar = _G.AmisiaDungeonBar
assert(bar and bar:IsShown() and DBar.Shown() == "thanes", "shown by itself, in combat too")
STUB.combat = false
assert(bar.handle.text:GetText() == "Halle der Thane", "the client's name")
local seg = bar.seg
assert(seg.bosses:IsShown() and plain(seg.bosses:GetText()) == "Bosse 0/4", seg.bosses:GetText())
assert(seg.quests:IsShown() and has(seg.quests:GetText(), "Quests "), "the quests: " .. tostring(seg.quests:GetText()))
assert(not has(seg.quests:GetText(), "fertig"), "none ready")
assert(not seg.time:IsShown() and not seg.route:IsShown(), "no clock, no route: hidden")
-- the row: name, segments left to right, the bar as wide as they are with the close circle
local nameR = bar.handle:GetWidth()
assert(bar:GetWidth() > nameR + seg.bosses:GetWidth() + seg.quests:GetWidth(), "the bar holds its parts")

---------------------------------------------------------------------------
-- Bosse: a kill counts; the list with the tick, the next boss, the jump to the page
---------------------------------------------------------------------------
kill(E1)
assert(plain(seg.bosses:GetText()) == "Bosse 1/4", seg.bosses:GetText())
seg.bosses:Click()
local list = _G.AmisiaDungeonBarList
assert(list and list:IsShown() and DBar.ListShown() == "bosses", "the boss list")
local rs = rows()
assert(#rs == 4, "four bosses")
assert(has(rs[1].text:GetText(), "ReadyCheck-Ready") and plain(rs[1].text:GetText()) == " 1. Faldrim Anvilmar" and rs[1].note:GetText() == "besiegt",
    rs[1].text:GetText())
assert(has(rs[2].text:GetText(), T.GOLD_TEXT) and rs[2].note:GetText() == "als Nächstes", "the next one in gold")
assert(rs[3].note:GetText() == "" and not has(rs[3].text:GetText(), "ReadyCheck"), "a later one plain")
local asked
local show = NS.ShowDungeonBoss
NS.ShowDungeonBoss = function(k, i) asked = k .. ":" .. i; return show(k, i) end
rs[3]:Click()
assert(asked == "thanes:3" and NS.CurrentPage() == "dungeons", "Plunder on the page: " .. tostring(asked))
NS.ShowDungeonBoss = show
_G.AmisiaFrame:Hide()
-- a second click closes it; Escape (the special frames) closes it
seg.bosses:Click()
assert(not list:IsShown() and DBar.ListShown() == nil, "a second click")
seg.bosses:Click()
local special = false
for _, n in ipairs(UISpecialFrames) do if n == "AmisiaDungeonBarList" then special = true end end
assert(special and list:IsShown(), "Escape closes the list")
list:Hide()
assert(bar:IsShown(), "Escape leaves the bar")
-- a kill while the list shows refreshes it
seg.bosses:Click()
kill(E2)
assert(has(rows()[2].text:GetText(), "ReadyCheck-Ready") and rows()[3].note:GetText() == "als Nächstes", "refreshed")
assert(plain(seg.bosses:GetText()) == "Bosse 2/4")

---------------------------------------------------------------------------
-- Quests: the marks, the ready ones green and counted, the click opens the quest path
---------------------------------------------------------------------------
local qs = DBar.Quests("thanes")
assert(#qs >= 2, "the hall has quests")
local q1 = qs[1].q
STUB.questsActive[q1.qid] = true
STUB.questsReady = { [q1.qid] = true }
C_QuestLog.IsComplete = function(id) return STUB.questsReady[id] == true end
STUB.fire("QUEST_ACCEPTED", q1.qid)
STUB.fire("QUEST_LOG_UPDATE")
tick()
local ready
qs, ready = DBar.Quests("thanes")
assert(ready == 1 and qs[1].q.qid == q1.qid and qs[1].state == "ready", "the ready one first")
assert(has(seg.quests:GetText(), T.GREEN) and plain(seg.quests:GetText()) == ("Quests %d (1 fertig)"):format(#qs), seg.quests:GetText())
seg.quests:Click()
assert(DBar.ListShown() == "quests", "the boss list gave way to the quest list")
rs = rows()
assert(#rs == #qs, "every quest")
assert(has(rs[1].text:GetText(), "ActiveQuestIcon:14:14|t") and has(rs[1].text:GetText(), T.GREEN) and has(rs[1].text:GetText(), q1.title), "ready: the yellow ? in green")
for i = 2, #rs do
    assert(has(rs[i].text:GetText(), NS.Dungeons.QuestStateIcon(qs[i].state)), "the journal's mark")
end
assert(rs[1].note:GetText() == NS.Dungeons.QuestLevelText(q1), "the level")
rs[1]:Click()
local D = NS.PageFrame("dungeons")
assert(NS.CurrentPage() == "dungeons" and D.pathFor and D.pathFor.key == q1.qid and D.pathFor.dungeon == "thanes", "the quest path in the journal")
_G.AmisiaFrame:Hide()
list:Hide()
-- done ones leave the list
STUB.questsActive[q1.qid] = nil
STUB.questsDone = STUB.questsDone or {}
STUB.questsDone[q1.qid] = true
STUB.fire("QUEST_TURNED_IN", q1.qid)
tick()
local after = DBar.Quests("thanes")
for _, e in ipairs(after) do assert(e.q.qid ~= q1.qid, "the handed-in quest is gone") end
assert(not has(seg.quests:GetText(), "fertig"), seg.quests:GetText())

---------------------------------------------------------------------------
-- Zeit: only while the clock runs; a click shows and hides the window "Lauf-Zeiten"
---------------------------------------------------------------------------
enter(OUT)
assert(not bar:IsShown() and DBar.Shown() == nil, "leaving hides it")
NS.RunTimes.Stop()
STUB.fire("CHAT_MSG_SYSTEM", "Halle der Thane has been reset.")
_G.INSTANCE_RESET_SUCCESS = "%s has been reset."
STUB.tick(31 * 60)
enter(THANES)
assert(bar:IsShown() and plain(seg.bosses:GetText()) == "Bosse 0/4", "a fresh run: " .. seg.bosses:GetText())
assert(not seg.time:IsShown(), "no clock before the first fight")
STUB.fire("PLAYER_REGEN_DISABLED"); STUB.fire("PLAYER_REGEN_ENABLED")
assert(seg.time:IsShown() and seg.time:GetText() == "Zeit 0:00", tostring(seg.time:GetText()))
STUB.tick(75)
bar.scripts.OnUpdate(bar, T.DUNGEONBAR.TICK)
assert(seg.time:GetText() == "Zeit 1:15", seg.time:GetText())
local TW = NS.RunTimer
assert(TW.Shown() == "thanes", "the clock opened its window")
seg.time:Click()
assert(not TW.Shown(), "a click hides the window")
seg.time:Click()
assert(TW.Shown() == "thanes", "and shows it again")
assert(not DBar.ListShown(), "the time has no list")
NS.Dispatch("zeiten stop")
assert(not seg.time:IsShown(), "the clock stopped: hidden")

---------------------------------------------------------------------------
-- Route: while a route is followed; the stops, "Weiter", a right click, "Folgen beenden"
---------------------------------------------------------------------------
STUB.maps[1426] = { name = "Dun Morogh", mapType = 3, world = { 0, 0, 0, 1000, 800 } }
Rt._reset()
Rt.AddStop(1426, 0.2, 0.3)
Rt.AddStop(1426, 0.4, 0.3)
Rt.AddStop(1426, 0.6, 0.3)
Rt.SetLabel(2, "Brücke")
assert(not seg.route:IsShown(), "no route followed")
assert(Rt.Follow())
assert(seg.route:IsShown() and seg.route:GetText() == "Route 1/3", tostring(seg.route:GetText()))
seg.route.scripts.OnClick(seg.route, "RightButton")
assert(Rt.Following().i == 2 and seg.route:GetText() == "Route 2/3", "a right click: the next stop")
seg.route:Click()
rs = rows()
assert(DBar.ListShown() == "route" and #rs == 5, "three stops and two actions")
assert(has(rs[1].text:GetText(), "ReadyCheck-Ready") and plain(rs[1].text:GetText()) == " 1. Stopp 1", rs[1].text:GetText())
assert(has(rs[2].text:GetText(), T.GOLD_TEXT) and plain(rs[2].text:GetText()) == "2. Brücke" and rs[2].note:GetText() == "Ziel", rs[2].text:GetText())
assert(plain(rs[4].text:GetText()) == "Weiter zum nächsten Stopp" and plain(rs[5].text:GetText()) == "Folgen beenden")
rs[4]:Click()
assert(Rt.Following().i == 3 and seg.route:GetText() == "Route 3/3", "Weiter")
assert(has(rows()[3].text:GetText(), T.GOLD_TEXT), "the list follows")
rows()[5]:Click()
assert(Rt.Following() == nil and not seg.route:IsShown() and not list:IsShown(), "Folgen beenden: segment and list gone")

---------------------------------------------------------------------------
-- leaving closes an open list; moving, the saved place, the common reset
---------------------------------------------------------------------------
seg.bosses:Click()
assert(list:IsShown())
enter(OUT)
assert(not bar:IsShown() and not list:IsShown(), "leaving closes the list too")
enter(THANES)
assert(bar:IsShown() and not list:IsShown(), "back in: the bar, no list")
bar._point, bar._x, bar._y = "TOPLEFT", 300, -200
bar.handle.scripts.OnDragStop(bar.handle)
local st = AmisiaDB.settings.dungeonBar
assert(st.point == "TOPLEFT" and st.x == 300 and st.y == -200, "the place saved")
bar._point = nil
enter(OUT); enter(THANES)
assert(bar.points.TOPLEFT and bar.points.TOPLEFT.x == 300 and bar.points.TOPLEFT.y == -200, "kept")
NS.ResetPositions()
assert(st.point == nil and bar.points.TOP and bar.points.TOP.y == -40, "Fensterposition zurücksetzen")

---------------------------------------------------------------------------
-- the close circle: until the next entry or /amisia leiste
---------------------------------------------------------------------------
bar.close:Click()
assert(not bar:IsShown(), "closed")
STUB.fire("ZONE_CHANGED_NEW_AREA")
kill(E1)
assert(not bar:IsShown(), "stays closed in this entry")
NS.Dispatch("leiste")
assert(bar:IsShown(), "/amisia leiste shows it")
NS.Dispatch("leiste")
assert(not bar:IsShown(), "and hides it again")
enter(OUT); enter(THANES)
assert(bar:IsShown(), "the next entry shows it")

---------------------------------------------------------------------------
-- the settings: the segments, the bar itself, raids
---------------------------------------------------------------------------
NS.Set("dungeonbar.bosses", false)
NS.SettingItem("dungeonbar.bosses").onChange(false)
assert(not seg.bosses:IsShown() and seg.quests:IsShown(), "Bosse off")
NS.Set("dungeonbar.quests", false)
NS.SettingItem("dungeonbar.quests").onChange(false)
assert(not seg.quests:IsShown() and bar:IsShown(), "Quests off: the name alone")
NS.Set("dungeonbar.bosses", true); NS.Set("dungeonbar.quests", true)
NS.Set("dungeonbar.on", false)
NS.SettingItem("dungeonbar.on").onChange(false)
assert(not bar:IsShown(), "off: hidden")
enter(OUT); enter(THANES)
assert(not bar:IsShown(), "off: not on entering")
NS.Dispatch("leiste")
assert(bar:IsShown(), "the command shows it anyway")
NS.Set("dungeonbar.on", true)
-- a raid: off by default, on with the setting; no quest segment there
enter(ONYXIA)
assert(DBar.Here() == "onyxia" and not bar:IsShown(), "raids off by default")
NS.Set("dungeonbar.raids", true)
NS.SettingItem("dungeonbar.raids").onChange(true)
assert(bar:IsShown() and DBar.Shown() == "onyxia" and plain(seg.bosses:GetText()) == "Bosse 0/1" and not seg.quests:IsShown(), "a raid with the setting")
seg.bosses:Click()
rows()[1]:Click()
assert(NS.CurrentPage() == "raidjournal", "a raid's boss opens the page Raids")
enter(OUT)
assert(not bar:IsShown(), "gone outside")

---------------------------------------------------------------------------
-- another addon that shows bosses and time (F-205, D-131): "Bosse" and "Zeit" give way, the window
-- "Lauf-Zeiten" does not open by itself, quests stay; the setting dungeonbar.others brings them back
---------------------------------------------------------------------------
NS.Set("dungeonbar.raids", false)
assert(NS.Get("dungeonbar.others") == true, "on by default")
local A = C_AddOns
local keep = { A.GetNumAddOns, A.GetAddOnInfo, A.IsAddOnLoaded }
local LIST = { { "Amisia", true }, { "Some_Other", true }, { "ForeverDungeonJournal", false } }
A.GetNumAddOns = function() return #LIST end
A.GetAddOnInfo = function(i) if type(i) == "number" then return LIST[i][1], LIST[i][1], "", true end return keep[2](i) end
A.IsAddOnLoaded = function(i) return type(i) == "number" and LIST[i][2] or false end
enter(OUT)
assert(DBar.OtherAddon() == nil and not DBar.Yield(), "installed but not loaded: no matter")
LIST[3][2] = true
assert(DBar.OtherAddon() == nil, "looked for once per loading screen")
enter(OUT)
assert(DBar.OtherAddon() == "ForeverDungeonJournal" and DBar.Yield(), "loaded: found")
TW.Hide()
STUB.tick(31 * 60)
enter(OUT); enter(THANES)
assert(bar:IsShown() and not seg.bosses:IsShown() and seg.quests:IsShown(), "Bosse gives way, quests stay")
STUB.fire("PLAYER_REGEN_DISABLED"); STUB.fire("PLAYER_REGEN_ENABLED")
assert(NS.RunTimes.Live() ~= nil, "the clock still measures")
assert(not seg.time:IsShown() and not TW.Shown(), "Zeit gives way, the window stays shut")
NS.Set("dungeonbar.others", false)
NS.SettingItem("dungeonbar.others").onChange(false)
assert(seg.bosses:IsShown() and seg.time:IsShown(), "the setting off: both back")
NS.Set("dungeonbar.others", true)
NS.SettingItem("dungeonbar.others").onChange(true)
assert(not seg.bosses:IsShown() and not seg.time:IsShown(), "and gone again")
-- a folder that only starts with the name counts too
LIST[3][1] = "FojjiCore_Forever"
enter(THANES)
assert(DBar.OtherAddon() == "FojjiCore_Forever", "a part of it")
A.GetNumAddOns, A.GetAddOnInfo, A.IsAddOnLoaded = keep[1], keep[2], keep[3]
enter(THANES)
assert(DBar.OtherAddon() == nil, "a client without the calls: none")
NS.Dispatch("zeiten stop")
enter(OUT)
print("dungeon bar: entering and leaving, combat build, bosses, quests, time, route, lists, place, close, settings, raids, slash, other addons")
