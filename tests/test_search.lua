-- The search over the main window's page list (UI/Search.lua, UI/MainFrame.lua; D-45): from two
-- characters the list turns into the hits, grouped "Seiten", "Einstellungen", "Items", "Spieler";
-- pages by name (visible ones), settings by name, tip and choices (a click opens the settings with
-- that text), items by the names the client holds (Amisia's item names, the cached gear items; a
-- click puts the link into the chat line), players from the raids, awards and lineup (officer view;
-- a click opens Statistik with the player). Nothing under two characters; the gear data is built
-- only from three characters on. Escape and the clear button empty the box.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function keys(groups)
    local out = {}
    for _, g in ipairs(groups) do out[#out + 1] = g.key end
    return table.concat(out, " ")
end
local function texts(group)
    local out = {}
    for _, h in ipairs(group and group.hits or {}) do out[#out + 1] = h.text end
    return table.concat(out, ",")
end
local function group(groups, key)
    for _, g in ipairs(groups) do if g.key == key then return g end end
end

-- a recorded raid with members and an award, item names Amisia knows
STUB.officer = true
local LINK = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Kimtaro", class = "ROGUE" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
AmisiaDB.itemNames[32235] = { n = "Cursed Vision of Sargeras", q = 4 }
AmisiaDB.itemNames[555] = { n = "Item 555", q = 1 }          -- a placeholder name is no name
local s = { id = "s1", date = "2026-09-01", zone = "Black Temple", start = time() - 86400 * 9, members = {
    Fraktur = { class = "SHAMAN" }, Kimtaro = { class = "ROGUE" }, ["Anna Bergmann"] = { class = "PRIEST" } },
    awards = { { name = "Bobbington", item = 32235, to = "player" }, { name = "-", to = "bank" } } }
table.insert(AmisiaDB.sessions, s)
NS.SearchIndex._reset()

-- under two characters: nothing; no data built
assert(#NS.Search("") == 0 and #NS.Search("r") == 0 and #NS.Search(" c ") == 0, "nothing under two characters")
assert(NS.DataBuilt().GEAR == nil and rawget(NS, "GEAR") == nil, "one character builds nothing")
-- two characters: pages, settings, dungeons, players; items only from the names Amisia knows once the gear is built
local g = NS.Search("ra")
assert(keys(g) == "pages settings dungeons players", keys(g))
assert(has(texts(group(g, "pages")), "Raids") and has(texts(group(g, "pages")), "Raid-Log"), texts(group(g, "pages")))
assert(NS.DataBuilt().GEAR == nil and rawget(NS, "GEAR") == nil, "two characters build no gear data")
-- at most 8 per group
assert(#group(g, "settings").hits <= 8)
-- settings by label, tip and choice: "Expertenmodus" by its name, the view's choice "Raider" by its value
g = NS.Search("experten")
assert(texts(group(g, "settings")) == "Expertenmodus", texts(group(g, "settings")))
g = NS.Search("automatisch")
assert(has(texts(group(g, "settings")), "Ansicht"), "by a choice's name: " .. texts(group(g, "settings")))
-- hidden pages are not found: the raider view has no officers' Raids page (only the one in
-- Ausrüstung, F-122) and no players
local tips = {}
for _, h in ipairs(group(NS.Search("raids"), "pages").hits) do if h.text == "Raids" then tips[#tips + 1] = h.tip end end
table.sort(tips)
assert(table.concat(tips, "|") == "Seite im Reiter Ausrüstung.|Seite im Reiter Raid.", table.concat(tips, "|"))
NS.Set("ui.view", "raider")
g = NS.Search("raids")
tips = {}
for _, h in ipairs(group(g, "pages").hits) do if h.text == "Raids" then tips[#tips + 1] = h.tip end end
assert(table.concat(tips, "|") == "Seite im Reiter Ausrüstung.", table.concat(tips, "|"))
assert(group(NS.Search("frak"), "players") == nil, "players only in the officer view")
NS.Set("ui.view", "officer")
-- players from members and awards (not the bank), sorted, class kept for the icon
g = NS.Search("bo")
assert(texts(group(g, "players")) == "Bobbington", texts(group(g, "players")))
g = NS.Search("an")
local pl = group(g, "players")
assert(has(texts(pl), "Anna Bergmann") and pl.hits[1].atlas == "groupfinder-icon-class-priest", texts(pl))
assert(group(NS.Search("bank"), "players") == nil, "the bank of an award is no player")
-- items: from three characters (the gear data may be built then), never the placeholder
g = NS.Search("cursed")
assert(texts(group(g, "items")) == "Cursed Vision of Sargeras", texts(group(g, "items")))
assert(group(NS.Search("item 5"), "items") == nil, "a placeholder name is not found")
if NS.HasData("GEAR") then
    assert(rawget(NS, "GEAR") ~= nil, "three characters may build the gear data")
    -- a cached gear item the raids never saw
    local id
    for k in pairs(NS.Data("GEAR").I) do if not AmisiaDB.itemNames[k] then id = k break end end
    STUB.item(id, "Zzyzx Klinge der Probe", 3)
    NS.SearchIndex._reset()
    g = NS.Search("zzyzx")
    assert(texts(group(g, "items")) == "Zzyzx Klinge der Probe" and group(g, "items").hits[1].item == id, texts(group(g, "items")))
    -- once built, two characters find items too
    assert(group(NS.Search("zz"), "items") ~= nil, "two characters once the gear data is built")
end

-- the window: typing turns the list into the results, a click runs the hit and clears the box
NS.ShowPage("overview")
local F = AmisiaFrame
local box = F.search
local function type_(text)
    box:SetText(text)
    box.scripts.OnTextChanged(box, true)
end
type_("r")
assert(F.nav:IsShown() and not F.results:IsShown(), "one character: the page list stays")
type_("experten")
assert(not F.nav:IsShown() and F.results:IsShown(), "the results in place of the list")
local items = F.results.items
assert(items[1].head == "Einstellungen" and items[1].count == 1 and items[2].text == "Expertenmodus", tostring(items[1].head))
-- a group as the auction house's category bar (gold, the count white), a hit as its indented
-- sub-category bar (white); no icons, no list shade
local row, hitRow = F.results.rows[1], F.results.rows[2]
assert(row.headArt.normal.atlas == "auctionhouse-nav-button" and row.headArt.normal:IsShown()
    and not row.hitArt.normal:IsShown() and not row.headArt.hover:IsShown(), "a group's bar")
assert(has(row.label:GetText(), "Einstellungen") and row.label.font == "GameFontNormal" and row.label.points.LEFT.x == 8)
assert(hitRow.hitArt.normal.atlas == "auctionhouse-nav-button-secondary" and hitRow.hitArt.normal:IsShown()
    and not hitRow.headArt.normal:IsShown() and hitRow.hitArt.hover:IsShown(), "a hit's bar")
assert(hitRow.hitArt.hover.atlas == nil and hitRow.hitArt.hover.texture == nil, "no blue glow on hover")
assert(hitRow.label:GetText() == "Expertenmodus" and hitRow.label.font == "GameFontHighlightSmall" and hitRow.label.points.LEFT.x == 18)
assert(hitRow.icon == nil and not row.bg:IsShown() and row.hover.alpha == 0, "no icon, no shade, the bars' own glow")
assert(F.results.rowCount == 21 and F.results._h == 21 * 21 and hitRow._h == 20, "21 rows of 21")
F.results.rows[2]:Click()
assert(NS.CurrentPage() == "settings" and box:GetText() == "" and F.nav:IsShown() and not F.results:IsShown(),
    "a click opens the settings and empties the box")
assert(NS.SettingsPageFrame().search:GetText() == "Expertenmodus", "the settings search holds the setting")
-- nothing found: the hint
type_("qqqxx")
assert(F.results:IsShown() and #F.results.items == 0 and F.noHits:IsShown() and F.noHits:GetText() == "Nichts gefunden.")
-- Escape empties the box
box.scripts.OnEscapePressed(box)
assert(box:GetText() == "" and F.nav:IsShown() and not F.noHits:IsShown(), "Escape clears")
-- a page hit opens the page; its tab follows
type_("talent")
for i, it in ipairs(F.results.items) do
    if it.text == "Talente" then F.results.rows[i]:Click() break end
end
assert(NS.CurrentPage() == "talents" and F.tabs.gear.selected, NS.CurrentPage())
-- a player hit opens Statistik with the player chosen
type_("kimt")
for i, it in ipairs(F.results.items) do
    if it.text == "Kimtaro" then F.results.rows[i]:Click() break end
end
assert(NS.CurrentPage() == "stats", NS.CurrentPage())
local sp = NS.StatsPageFrame()
local first = sp.detail.fs:GetText():match("^[^\n]*")
assert(has(first, "Kimtaro"), "Statistik with Kimtaro chosen: " .. tostring(first))
-- an item hit puts its link into the chat line
type_("cursed")
for i, it in ipairs(F.results.items) do
    if it.item == 32235 then F.results.rows[i]:Click() break end
end
assert(STUB.inserted == LINK, "the link into the chat line")
-- the clear button empties the box too
type_("raid")
box.clearButton:Click()
assert(box:GetText() == "" and F.nav:IsShown())
print("search ok")
