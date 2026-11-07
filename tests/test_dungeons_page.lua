-- The dungeons page (the gear page's view "Dungeons" until it got a page of its own): the next
-- dungeon with its reason on top, the cards with level range, fit, upgrades, gain per run and value
-- (F-143), a click opens the chosen dungeon's bosses with their upgrades (gain, rate with kills, owned, wished) and
-- its quests with the best reward, the waypoint to the entrance; the page, the command, the overview
-- card, no facts; the layout at the main window's size (602 x 478) for officers and raiders.
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
local D = NS.PageFrame("dungeons")
assert(NS.CurrentPage() == "dungeons" and D:IsShown(), "the dungeons page")
local nextE = NS.DungeonNext()
assert(nextE and nextE.key == "thanes")
assert(D.next:GetText() == "Nächster Dungeon: Hall of Thanes · Level 13-18", D.next:GetText())
assert(D.why:GetText() == nextE.why, D.why:GetText())

-- the start view (F-143): one card per dungeon, the recommended one chosen and tagged at first
assert(D.grid:IsShown() and not D.art:IsShown() and not D.detail:IsShown() and not D.back:IsShown(), "the cards first")
local function cardsOf()
    local out = {}
    for _, c in ipairs(D.grid:Cards()) do out[c.item.key] = c end
    return out
end
local rows = cardsOf()
local r = rows.thanes
assert(r and plain(r.name:GetText()) == "Hall of Thanes" and plain(r.line1:GetText()) == "13-18 · passt", "the thanes card")
assert(r.chosen and r.tag:IsShown() and not r.dim, "chosen and recommended")
local runText = ("%+d"):format(math.floor(nextE.perRun + 0.5))
assert(plain(r.line2:GetText()) == ("3 Upgrades · %s je Lauf · Wert %d"):format(runText, math.floor(nextE.value + 0.5)), r.line2:GetText())
assert(nextE.once > 0, "the quests count into the value")
r:GetScript("OnEnter")(r)
r:GetScript("OnLeave")(r)
assert(rows.deadmines and plain(rows.deadmines.line1:GetText()) == "~16-18 · passt" and not rows.deadmines.chosen
    and not rows.deadmines.tag:IsShown(), "the client's level, the high end from the items")
-- a dungeon above the level (Blackfathom Deeps at the client's level 22, no items in this data set),
-- further down the grid: scrolled to, dim, no values
local bfd = D.grid:CardOf("bfd")
assert(bfd and plain(bfd.line1:GetText()) == "~22 · zu hoch" and bfd.line2:GetText() == "" and bfd.dim
    and bfd.tex.desaturated == true and bfd.name.textColor[1] < 0.6, "not computed, dim")
D.grid.offset = 0
D.grid:Redraw()
rows = cardsOf()
-- a click on a card opens its detail view
rows.thanes:Click()
assert(D.detail:IsShown() and D.art:IsShown() and D.back:IsShown() and not D.grid:IsShown() and not D.sorts.level:IsShown(), "the detail")

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
assert(has(qall, "quest:An Ancient Grudge") and has(qall, "quest:Done Already (erledigt)"), qall)
-- one row per quest (F-135): the rewards show in the quest path's head and the tooltip
assert(not has(qall, "reward:") and not has(qall, "pre:"), qall)
local grudgeRow
for _, e in ipairs(D.detail.items) do if e.text == "An Ancient Grudge" then grudgeRow = e end end
local hasHelm = false
for _, it in ipairs(grudgeRow.q.rewards) do if it.id == 505 then hasHelm = true end end
assert(hasHelm and grudgeRow.path, "the reward stays with the quest")
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
D.back:Click()
assert(D.grid:IsShown() and not D.detail:IsShown(), "back to the cards")
rows = cardsOf()
rows.deadmines:Click()
rows = cardsOf()
assert(AmisiaDB.settings.bis.dungeon == "deadmines" and rows.deadmines.chosen and not rows.thanes.chosen)
assert(D.header.ButtonText:GetText() == "The Deadmines · Bosse" and D.way:IsEnabled())
D.way:Click()
assert(STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1436, "the waypoint to the entrance")
NS.MapClearTarget()
D.back:Click()
rows.thanes:Click()

-- the overview card names the next dungeon
local card
for _, c in ipairs(NS.cards) do if c.key == "gear" then card = c end end
local c = NS.W.Card(UIParent, 296, 112)
card.fill(c)
assert(has(c.line2:GetText(), "Bestes: ") and has(c.line2:GetText(), "Nächster Dungeon: Hall of Thanes"), c.line2:GetText())

-- layout at the main window's size, officer and raider view
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(D, 602, 478)
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowGear("dungeons")
    -- the detail view: the back link before the spec, the image, the header, the bosses
    assert(D.detail:IsShown(), "the view stays")
    Lay.row(view .. " detail head row", D.back, D.spec)
    Lay.row(view .. " detail head", D.header, D.parts.bosses, D.parts.quests, D.foldAll, D.way)
    -- a boss's head (F-144): its sign, name and gain per run; an item row its four cells
    local dr = D.detail.rows[1]
    assert(dr.item.kind == "boss" and dr.item.open and dr.sign:IsShown(), "the thanes' first boss has an upgrade: unfolded")
    Lay.row(view .. " detail boss row", dr.sign, dr.name, dr.rate)
    local ir
    for _, row in ipairs(D.detail.rows) do if not ir and row.item and row.item.kind == "item" then ir = row end end
    Lay.row(view .. " detail row", ir.name, ir.slot, ir.gain, ir.rate)
    Lay.row(view .. " detail", D.detail, D.detail.bar)
    Lay.inside(view .. " detail bar", D.detail.bar)
    Lay.column(view .. " detail body", D.spec, D.art, D.header, D.detail)
    assert(D.hint.isHelp and not D.hint:IsShown(), "the hint is behind the window's ?")
    -- (item names carry the owned and wish marks as texture codes, which the stub measures as text)
    for _, row in ipairs(D.detail.rows) do
        if row.item and row.item.kind ~= "quest" then Lay.fits(row.rate) end
    end
    -- the start view: the order tabs, the recommendation, the cards
    D.back:Click()
    Lay.row(view .. " head", D.spec, D.sorts.level, D.sorts.value, D.sorts.chain)
    local gr = D.grid.rows[1]
    Lay.row(view .. " card row", gr.cards[1], gr.cards[2], gr.cards[3])
    Lay.row(view .. " grid", D.grid, D.grid.bar)
    Lay.inside(view .. " grid bar", D.grid.bar)
    Lay.column(view .. " body", D.spec, D.next, D.why, D.grid)
    local _, right = Lay.span(gr.cards[3])
    assert(right <= 590, "three cards in the list's width: " .. right)
    Lay.fits(D.next); Lay.fits(D.why)
    for _, c in ipairs(D.grid:Cards()) do Lay.fits(c.line1); Lay.fits(c.line2) end
    rows = cardsOf()
    rows.thanes:Click()
end
NS.Reset("ui.view")
-- the gear page keeps its chips
NS.ShowGear("goals")
local f = NS.PageFrame("gear")
assert(f.src.Q:IsShown() and not D:IsShown() and f.goals:IsShown())

-- without facts the view says so
local facts = NS.DUNGEON_FACTS
NS.DUNGEON_FACTS = nil
NS.ShowGear("dungeons")
assert(D.next:GetText() == "Keine Dungeon-Daten." and #D.grid.entries == 0 and #D.detail.items == 0 and not D.way:IsEnabled())
assert(D.grid:IsShown() and not D.detail:IsShown(), "no dungeon: the (empty) start")
NS.DUNGEON_FACTS = facts
NS.ShowGear("goals")
