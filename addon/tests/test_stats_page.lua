-- The page "Statistik" (UI/Pages/Stats.lua): officers see every player, a raider only the own row
-- (the hall of fame for both), sorting by a click on a column head, the range chips, the class and
-- role pickers, the row tooltip with the split per character, the detail with items per week, the
-- hall of fame view, the empty page, and the layout at the main window's size.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local DAY = 86400
local now = STUB.now
RAID_CLASS_COLORS.MAGE = RAID_CLASS_COLORS.MAGE or { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" }

STUB.player = "Vuloo"
local function raid(id, ago, zone, inst)
    local start = now - ago * DAY
    local s = { id = id, date = date("%Y-%m-%d", start), zone = zone, instanceID = inst, start = start, last = start + 3600,
                members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    AmisiaDB.sessions[#AmisiaDB.sessions + 1] = s
    return s
end

-- the empty page first
NS.ShowPage("stats")
assert(NS.CurrentPage() == "stats", "the page opens")
local f = NS.StatsPageFrame()
assert(f and f.list, "the page builds")
assert(f.empty:IsShown() and has(f.empty:GetText(), "Noch keine Raids"), "an empty page says so")

local s1 = raid("s1", 12, "Der Schwarze Tempel", 564)
s1.members = { Vuloo = { class = "PRIEST", first = s1.start }, Bob = { class = "MAGE", first = s1.start },
               Chorf = { class = "WARRIOR", first = s1.start, late = true } }
NS.AddAwardTo(s1, { name = "Bob", item = 32235, kind = "MS", src = "?", t = s1.start + 60 })
local s2 = raid("s2", 2, "Hyjal", 534)
s2.members = { Vuloo = { class = "PRIEST", first = s2.start }, Bobalt = { class = "MAGE", first = s2.start } }
NS.AddAwardTo(s2, { name = "Bobalt", item = 32837, kind = "OS", src = "?", t = s2.start + 60 })
NS.AddAwardTo(s2, { name = "Vuloo", item = 30000, kind = "SR", src = "?", t = s2.start + 90 })
s2.kills = { { enc = 618, name = "Winterchill", start = s2.start + 10, t = s2.start + 20, ok = true, who = { "Vuloo", "Bobalt" } } }
STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)
STUB.item(30000, "Gürtel der unendlichen Weiten", 4)
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-01\nA Bobalt Bob\n#END"))

---------------------------------------------------------------------------
-- officer: every player
---------------------------------------------------------------------------
NS.Set("ui.view", "officer")
NS.ShowStats("players")
local function rows()
    local out = {}
    for i, r in ipairs(f.list.rows) do
        if r:IsShown() then out[#out + 1] = r end
    end
    return out
end
local function names()
    local out = {}
    for _, r in ipairs(rows()) do out[#out + 1] = r.item.name end
    return table.concat(out, ",")
end
assert(not f.empty:IsShown())
assert(names() == "Bob,Vuloo,Chorf", "most items first: " .. names())
local r1 = rows()[1]
assert(has(r1.name:GetText(), "Bob") and r1.items:GetText() == "2", "Bob with his alt: two items")
assert(r1.ms:GetText() == "1" and r1.os:GetText() == "1" and r1.sr:GetText() == "0")
assert(has(r1.rate:GetText(), "100 %") and has(r1.rate:GetText(), "2/2"), "attendance: " .. r1.rate:GetText())

-- sorting: a click on a head sorts by it, a second click turns it round
f.heads.rate:Click()
assert(names() == "Bob,Vuloo,Chorf", "by attendance, ties by name: " .. names())
f.heads.name:Click()
assert(names() == "Bob,Chorf,Vuloo", "by name: " .. names())
f.heads.name:Click()
assert(names() == "Vuloo,Chorf,Bob", "turned round: " .. names())
f.heads.items:Click()

-- the tooltip of a row: the split per character
r1 = rows()[1]
local tipLines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
r1:GetScript("OnEnter")(r1)
GameTooltip.AddLine = addLine
local tip = table.concat(tipLines, "\n")
assert(has(tip, "Bobalt") and has(tip, "Bob"), "both characters in the tooltip: " .. tip)
r1:GetScript("OnLeave")(r1)

-- a click shows the player's weeks
r1:Click()
local detail = f.detail.fs:GetText()
assert(has(detail, "Bob") and has(detail, "Bobalt"), "the detail names the characters")
assert(has(detail, "Woche"), "items per week: " .. detail)

-- the range: the phase began with Hyjal
f.range.phase:Click()
assert(names() == "Bob,Vuloo", "Chorf was not there in this phase: " .. names())
assert(has(f.info:GetText(), "Hyjal"), "the phase is named: " .. f.info:GetText())
f.range.all:Click()

-- class and role
f.class.onPick("MAGE")
assert(names() == "Bob", "mages only")
f.class.onPick("all")
f.role.onPick("unknown")
assert(names() == "Vuloo,Chorf", "priest and warrior: role unknown")
f.role.onPick("all")

-- the hall of fame
NS.ShowStats("fame")
assert(f.fame:IsShown() and not f.list:IsShown(), "the fame view")
local fame = f.fame.fs:GetText()
assert(has(fame, "Meiste Items") and has(fame, "Bob"), fame)
assert(has(fame, "Längste Serie"), fame)

---------------------------------------------------------------------------
-- raider: the own row only, the hall of fame as well
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
NS.ShowStats("players")
assert(names() == "Vuloo", "a raider sees the own numbers: " .. names())
assert(not f.class:IsShown() and not f.role:IsShown(), "no filters for one row")
assert(has(f.hint:GetText(), "Offiziere"), "the hint says why")
NS.ShowStats("fame")
assert(has(f.fame.fs:GetText(), "Bob"), "the hall of fame names everyone")
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- layout at the main window's size
---------------------------------------------------------------------------
NS.Set("ui.view", "officer")
NS.ShowStats("players")
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("stats chips", f.view.players, f.view.fame)
    L.row("stats range", f.range.w4, f.range.phase, f.range.all)
    L.row("stats filters", f.class, f.role, f.info)
    local h = f.heads
    L.row("stats heads", h.name, h.items, h.ms, h.os, h.sr, h.perRaid, h.rate, h.bosses, h.streak, h.last)
    local r = f.list.rows[1]
    L.row("stats row", r.name, r.items, r.ms, r.os, r.sr, r.perRaid, r.rate, r.bosses, r.streak, r.last)
    L.row("stats list", f.list, f.list.bar)
    local _, right = L.span(f.list)
    assert(right == 590, "the list leaves room for its bar: " .. right)
    L.column("stats page", f.list, f.detail)
    L.inside("stats detail", f.detail)
end
NS.Reset("ui.view")
