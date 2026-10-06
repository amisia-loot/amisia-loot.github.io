-- The view "Dungeons" of the gear page: the next dungeon with its reason on top, the list with
-- level range, fit, upgrades, gain per run, quests and value, the chosen dungeon's bosses with their
-- upgrades (gain, rate with kills, owned, wished) and its quests with the best reward, the waypoint
-- to the entrance; the view chip, the command, the overview card, no facts; the layout at the main
-- window's size (602 x 478) for officers and raiders.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- the hand facts of DungeonData.lua (the build's ns.BIS.DG: test_bis_data.lua)
NS.BIS = nil
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
STUB.questsDone[96397] = true
NS.GEAR = { built = "test-dungeons-page", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },                                  -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                                            -- 2
    { "Q", "An Ancient Grudge", 18, 15, "A", 1437, 96395, 0, "Hall of Thanes" },           -- 3
    { "Q", "Done Already", 18, 15, nil, 1437, 96397, 0, "Hall of Thanes" },                -- 4
    { "D", "Ruins of Lordaeron", "The Baron", nil },                                       -- 5
    { "D", "The Deadmines", "Cookie", nil },                                               -- 6
} }
local function gear(id, name, loc, strength, level, sources)
    STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, 2, level, 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
gear(501, "Ambosshelm", "HEAD", 20, 16, { 1 })
gear(502, "Magmabrust", "CHEST", 10, 17, { 2 })
gear(503, "Magmabeine", "LEGS", 8, 18, { 2 })
gear(505, "Grollhandschuhe", "HAND", 12, 15, { 3 })
gear(507, "Alter Gürtel", "WAIST", 9, 15, { 4 })
gear(509, "Baronsschultern", "SHOULDER", 10, 17, { 5 })
gear(511, "Kekshut", "HEAD", 25, 18, { 6 })
gear(510, "Alter Helm", "HEAD", 10, 10)
STUB.worn[1] = STUB.items[510].link
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
assert(NS.WishAdd(503))

NS.ShowGear("dungeons")
local f = NS.GearPageFrame()
assert(NS.CurrentPage() == "gear" and f.views.dungeons.on and not f.views.goals.on, "the view chip")
local D = f.dungeons
assert(D:IsShown() and not f.goals:IsShown(), "the dungeons body")
for _, k in ipairs({ "Q", "D", "C", "V", "W", "A", "P" }) do assert(not f.src[k]:IsShown(), "no source chips here: " .. k) end
local nextE = NS.DungeonNext()
assert(nextE and nextE.key == "thanes")
assert(D.next:GetText() == "Nächster Dungeon: Hall of Thanes · Level 13-18", D.next:GetText())
assert(D.why:GetText() == nextE.why, D.why:GetText())

-- the list: one row per dungeon, the recommended one chosen at first
local rows = {}
for i, r in ipairs(D.list.rows) do if r.item then rows[r.item.key] = r end end
local r = rows.thanes
assert(r and plain(r.name:GetText()) == "Hall of Thanes" and r.level:GetText() == "13-18" and r.fit:GetText() == "passt", "the thanes row")
assert(r.upgrades:GetText() == "3" and r.sel:IsShown(), "three upgrades, chosen: " .. r.upgrades:GetText())
assert(r.run:GetText() == ("%+d"):format(math.floor(nextE.perRun + 0.5)) and r.quests:GetText() == ("%+d"):format(math.floor(nextE.once + 0.5)))
assert(r.value:GetText() == tostring(math.floor(nextE.value + 0.5)), r.value:GetText())
assert(rows.deadmines and rows.deadmines.level:GetText() == "~16-18" and rows.deadmines.fit:GetText() == "passt", "the client's level, the high end from the items")
-- a dungeon above the level (Blackfathom Deeps at the client's level 22, no items in this data set)
assert(rows.bfd and rows.bfd.level:GetText() == "~22" and rows.bfd.fit:GetText() == "zu hoch" and rows.bfd.value:GetText() == "",
    "not computed")

-- the chosen dungeon: header, bosses with their items, quests
assert(D.header.ButtonText:GetText() == "Hall of Thanes · Bosse", D.header.ButtonText:GetText())
assert(D.parts.bosses.on and not D.parts.quests.on and D.sorts.level.on, "bosses, by level at first")
local texts = {}
for _, dr in ipairs(D.detail.rows) do
    if dr.item then texts[#texts + 1] = plain(dr.name:GetText()) .. "|" .. plain(dr.gain:GetText()) .. "|" .. plain(dr.rate:GetText()) end
end
D.detail.offset = 0
local all = {}
for _, e in ipairs(D.detail.items) do all[#all + 1] = e.kind .. ":" .. (e.text or e.id or "") end
all = table.concat(all, ",")
assert(has(all, "boss:Faldrim Anvilmar") and has(all, "item:501") and has(all, "boss:Magmatus") and has(all, "item:503"), all)
assert(not has(all, "quest:"), "the quests have their own part: " .. all)
assert(has(texts[2] or "", "Ambosshelm") and has(texts[2], "Chance 20 %"), texts[2])
-- the quests part: the item data's dungeon quests joined with the quest data's
D.parts.quests:Click()
assert(D.header.ButtonText:GetText() == "Hall of Thanes · Quests" and D.parts.quests.on)
local qall = {}
for _, e in ipairs(D.detail.items) do qall[#qall + 1] = e.kind .. ":" .. (e.text or e.id or "") end
qall = table.concat(qall, ",")
assert(has(qall, "quest:An Ancient Grudge") and has(qall, "quest:Done Already (erledigt)") and has(qall, "reward:505"), qall)
assert(not has(D.hint:GetText(), "fehlen"), "the quest data knows the thanes: " .. D.hint:GetText())
D.parts.bosses:Click()
-- the wished legs carry the star
local legs
for _, e in ipairs(D.detail.items) do if e.id == 503 then legs = e end end
assert(legs and legs.wished, "the wish is marked")

-- the waypoint: none for the thanes, the entrance of the deadmines
assert(not D.way:IsEnabled(), "no entrance known")
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
rows.deadmines:Click()
assert(AmisiaDB.settings.bis.dungeon == "deadmines" and rows.deadmines.sel:IsShown() and not rows.thanes.sel:IsShown())
assert(D.header.ButtonText:GetText() == "The Deadmines · Bosse" and D.way:IsEnabled())
D.way:Click()
assert(STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1436, "the waypoint to the entrance")
NS.MapClearTarget()
rows.thanes:Click()

-- the overview card names the next dungeon
local card
for _, c in ipairs(NS.cards) do if c.key == "gear" then card = c end end
local c = NS.W.Card(UIParent, 296, 112)
card.fill(c)
assert(has(c.line2:GetText(), "Bestes: ") and has(c.line2:GetText(), "Nächster Dungeon: Hall of Thanes"), c.line2:GetText())

-- layout at the main window's size, officer and raider view
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowGear("dungeons")
    if f.views.guild:IsShown() then
        Lay.row(view .. " head", f.spec, f.views.goals, f.views.here, f.views.dungeons, f.views.wish, f.views.guild, f.open)
    else
        Lay.row(view .. " head", f.spec, f.views.goals, f.views.here, f.views.dungeons, f.views.wish, f.open)
    end
    Lay.row(view .. " columns", D.head.name, D.head.level, D.head.fit, D.head.upgrades, D.head.run, D.head.quests, D.head.value)
    local lr = D.list.rows[1]
    Lay.row(view .. " list row", lr.name, lr.level, lr.fit, lr.upgrades, lr.run, lr.quests, lr.value)
    Lay.row(view .. " list", D.list, D.list.bar)
    Lay.inside(view .. " list bar", D.list.bar)
    Lay.row(view .. " detail head", D.header, D.parts.bosses, D.parts.quests, D.way)
    Lay.row(view .. " sorts", D.next, D.sorts.level, D.sorts.value, D.sorts.chain)
    local dr = D.detail.rows[1]
    Lay.row(view .. " detail row", dr.name, dr.slot, dr.gain, dr.rate)
    Lay.row(view .. " detail", D.detail, D.detail.bar)
    Lay.inside(view .. " detail bar", D.detail.bar)
    Lay.column(view .. " body", f.counts, D.next, D.why, D.head.name, D.list, D.header, D.detail, D.hint)
    local _, gr = Lay.span(lr.value)
    assert(gr <= 590, "the value ends in the row: " .. gr)
    Lay.fits(D.next); Lay.fits(D.why)
    for _, fs in pairs(D.head) do Lay.fits(fs) end
    for _, row in ipairs(D.list.rows) do
        if row.item then Lay.fits(row.name); Lay.fits(row.level); Lay.fits(row.fit) end
    end
    -- (item names carry the owned and wish marks as texture codes, which the stub measures as text)
    for _, row in ipairs(D.detail.rows) do
        if row.item and row.item.kind ~= "quest" then Lay.fits(row.rate) end
    end
end
NS.Reset("ui.view")
assert(plain(f.views.dungeons.label:GetText()) == "Dungeons")
-- the other views keep their chips
NS.ShowGear("goals")
assert(f.src.Q:IsShown() and not D:IsShown() and f.goals:IsShown())

-- without facts the view says so
local facts = NS.DUNGEON_FACTS
NS.DUNGEON_FACTS = nil
NS.ShowGear("dungeons")
assert(D.next:GetText() == "Keine Dungeon-Daten." and #D.list.items == 0 and #D.detail.items == 0 and not D.way:IsEnabled())
NS.DUNGEON_FACTS = facts
NS.ShowGear("goals")
