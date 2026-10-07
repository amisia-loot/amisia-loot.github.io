-- The guild's drop data in the game (Drops.lua, Pages/Tools.lua): the section "Drop-Daten" on the
-- tools page (kills own and heard, bosses, newest day, last exchange, the sharing switch, the list per
-- instance and boss with the rates, the text "Drops für die Website" in place of the list),
-- /amisia drops export, and the drop rate line on item tooltips (drops.tooltip; cheap: the index of
-- observed items is built once per change, not per hover).
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function msgs(text)
    local n = 0
    for _, m in ipairs(STUB.messages) do if m:find(text, 1, true) then n = n + 1 end end
    return n
end
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

local today = NS.DropsToday()
local d = NS.DropsDB()
d.me = "11111111"
local HEARD = "22222222"

---------------------------------------------------------------------------
-- records: three kills of Faldrim (dungeon), two of Kurgor (raid), one fallback record (E)
---------------------------------------------------------------------------
local ring = STUB.item(219004, "Ring der Thane", 3)
local cloak = STUB.item(219005, "Umhang der Thane", 3)
local belt = STUB.item(219006, "Gürtel der Thane", 2)
local other = STUB.item(219007, "Nie gesehen", 3)
local function rec(h, npc, inst, day, o, it, src, enc)
    local r = { h = h, npc = npc, inst = inst, diff = 1, day = day, o = o, src = src or "G", enc = enc, it = it }
    assert(NS.DropsMerge(r) == "new", h)
end
rec("a0000001", 213450, 2834, today, d.me, { [219004] = 1 })
rec("a0000002", 213450, 2834, today - 1, d.me, { [219005] = 1 })
rec("a0000003", 213450, 2834, today - 2, HEARD, { [219004] = 1, [219006] = 2 })
rec("a0000004", 213470, 409, today, HEARD, { [219005] = 1 })
rec("a0000005", 213470, 409, today - 1, HEARD, { [219005] = 1 })
rec("a0000006", 0, 2834, today, HEARD, { [219006] = 1 }, "E", 3020)
-- the own records are those this client recorded
d.k.a0000001.mine, d.k.a0000002.mine = true, true
NS.DropsLearnNames({ [213450] = "Faldrim Ambossmahl", [213470] = "Kurgor der Wächter" },
    { [2834] = { "party", "Halle der Thane" }, [409] = { "raid", "Geschmolzener Kern" } }, { [3020] = "Geheimer Boss" })
d.heard = STUB.now - 3600

---------------------------------------------------------------------------
-- the list per instance and boss
---------------------------------------------------------------------------
NS.BIS = nil
local rows = NS.DropsBossList()
local function show(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.kind .. ":" .. tostring(e.text) .. "|" .. tostring(e.rate) end
    return table.concat(out, "\n")
end
assert(#rows == 10, show(rows))
-- instances by name, their bosses by name, the items of a boss by how often they were seen
assert(rows[1].kind == "inst" and rows[1].inst == 409 and has(rows[1].text, "Geschmolzener Kern") and has(rows[1].text, "Raid"), show(rows))
assert(rows[1].rate == "2 Kills", show(rows))
assert(rows[2].kind == "boss" and rows[2].npc == 213470 and rows[2].text == "Kurgor der Wächter" and rows[2].K == 2 and rows[2].rate == "2 Kills")
assert(rows[3].kind == "item" and rows[3].id == 219005 and rows[3].n == 2 and rows[3].rate == "gesehen 2-mal in 2 Kills", show(rows))
assert(rows[4].kind == "inst" and rows[4].inst == 2834 and has(rows[4].text, "Halle der Thane") and has(rows[4].text, "Dungeon") and rows[4].rate == "4 Kills")
assert(rows[5].kind == "boss" and rows[5].npc == 213450 and rows[5].K == 3 and rows[5].rate == "3 Kills")
assert(rows[6].id == 219004 and rows[6].n == 2 and rows[6].rate == "gesehen 2-mal in 3 Kills", show(rows))
assert(rows[7].id == 219005 and rows[7].n == 1 and rows[8].id == 219006 and rows[8].n == 1, "equal counts by item id")
-- a fallback record (no NPC id) stands under its encounter's name, with its own count
assert(rows[9].kind == "boss" and rows[9].npc == 0 and rows[9].enc == 3020 and rows[9].text == "Geheimer Boss" and rows[9].K == 1)
assert(rows[10].kind == "item" and rows[10].id == 219006 and rows[10].rate == "gesehen 1-mal in 1 Kills")
for _, e in ipairs(rows) do
    if e.kind == "item" then assert(not has(e.text, "Item "), "the item's name: " .. e.text) end
end

-- with the base stock: its kills count, and records up to its day are in it already; a boss of the
-- base stock is placed by the dungeon facts, one without facts stands under "Ohne Instanz"
NS.BIS = { O = { [213450] = { k = 10, it = { [219004] = 4 } }, [999001] = { k = 6, it = { [219007] = 3 } },
                 [999002] = { k = 2, it = {} } },
           OT = today - 1,
           DG = { { key = "mc", name = "Molten Core", kind = "raid", inst = 409, bosses = { 999001 } } } }
rows = NS.DropsBossList()
local faldrim, mc, none
for i, e in ipairs(rows) do
    if e.kind == "boss" and e.npc == 213450 then faldrim = i end
    if e.kind == "boss" and e.npc == 999001 then mc = i end
    if e.kind == "inst" and e.inst == 0 then none = i end
end
assert(faldrim and rows[faldrim].K == 11, "10 of the base stock and the one record after its day")
assert(rows[faldrim + 1].id == 219004 and rows[faldrim + 1].rate == "5 von 11 Kills der Gilde (45 %)", show(rows))
assert(mc and rows[mc].K == 6 and rows[mc].text == "Boss 999001", "an unnamed boss keeps its id")
local mcInst
for i = mc, 1, -1 do if rows[i].kind == "inst" then mcInst = rows[i] break end end
assert(mcInst.inst == 409, "the base boss under the instance of the dungeon facts")
assert(none and has(rows[none].text, "Ohne Instanz") and rows[none + 1].npc == 999002, show(rows))
NS.BIS = nil

---------------------------------------------------------------------------
-- the tooltip line
---------------------------------------------------------------------------
assert(NS.Get("drops.tooltip") == true, "on by default")
local found
for _, it in ipairs(NS.DROPS_SETTINGS.items) do if it.key == "drops.tooltip" then found = it end end
assert(found and found.type == "toggle" and found.label == "Dropraten der Gilde im Tooltip")

local tip = CreateFrame("GameTooltip", "DropTestTooltip")
local lines = {}
tip.AddLine = function(_, t, r, g, b) lines[#lines + 1] = { t = t, r = r, g = g, b = b } end
local function hover(link)
    wipe(lines)
    if tip.scripts.OnTooltipCleared then tip.scripts.OnTooltipCleared(tip) end
    tip.shownLink = link
    for _, h in ipairs(STUB.tdp) do h.fn(tip) end
    for _, l in ipairs(lines) do
        if has(l.t, "Drop bei ") then return l end
    end
    return nil
end
local l = hover(ring)
assert(l and l.t == "Drop bei Faldrim Ambossmahl: gesehen 2-mal in 3 Kills", l and l.t)
assert(l.r < 0.7 and l.g < 0.7, "a grey line")
-- an item seen at two bosses names the one that drops it most often
l = hover(cloak)
assert(l and l.t == "Drop bei Kurgor der Wächter: gesehen 2-mal in 2 Kills", l and l.t)
-- a fallback record has no NPC: only the NPC kills count
l = hover(belt)
assert(l and l.t == "Drop bei Faldrim Ambossmahl: gesehen 1-mal in 3 Kills", l and l.t)
assert(hover(other) == nil, "nothing for an item nobody saw drop")
assert(NS.DropsTooltipLine(219007) == nil and NS.DropsTooltipLine(nil) == nil)
-- from five kills on the share
NS.BIS = { O = { [213450] = { k = 10, it = { [219004] = 4 } } }, OT = today - 1 }
l = hover(ring)
assert(l and l.t == "Drop bei Faldrim Ambossmahl: 5 von 11 Kills der Gilde (45 %)", l and l.t)
NS.BIS = nil
-- cheap: hovering does not rebuild the index; a change does, once (the base stock just went, so the
-- first hover builds it again)
hover(ring)
local builds = NS.DropsTooltipStats().builds
for _ = 1, 5 do hover(ring); hover(cloak); hover(other) end
assert(NS.DropsTooltipStats().builds == builds, "no rebuild per hover")
rec("a0000007", 213450, 2834, today, HEARD, { [219007] = 1 })
l = hover(other)
assert(l and l.t == "Drop bei Faldrim Ambossmahl: gesehen 1-mal in 4 Kills", l and l.t)
hover(ring)
assert(NS.DropsTooltipStats().builds == builds + 1, "one rebuild after the change")
-- a boss without a name
rec("a0000008", 213499, 2834, today, HEARD, { [219008] = 1 })
assert(NS.DropsTooltipLine(219008) == "Drop bei Boss 213499: gesehen 1-mal in 1 Kills", NS.DropsTooltipLine(219008))
-- the switch
NS.Set("drops.tooltip", false)
assert(hover(ring) == nil, "no line with the switch off")
NS.Reset("drops.tooltip")
assert(hover(ring) ~= nil)
-- an error inside never breaks the tooltip
local real = NS.DropRateText
NS.DropRateText = function() error("kaputt") end
local errs = 0
local oldHandler = geterrorhandler
_G.geterrorhandler = function() return function() errs = errs + 1 end end
assert(hover(ring) == nil)
_G.geterrorhandler = oldHandler
NS.DropRateText = real
assert(errs == 1, "the error goes to the error handler: " .. errs)
assert(hover(ring) ~= nil)

---------------------------------------------------------------------------
-- the section on the tools page
---------------------------------------------------------------------------
-- remove the two extra records again: the list below is the one from the top
d.k.a0000007, d.k.a0000008 = nil, nil
NS.DropsPrune()
NS.Set("ui.expert", true)
NS.ShowPage("tools")
assert(NS.CurrentPage() == "tools")
local tf = NS.ToolsPageFrame()
local D = tf.drops
assert(D and D.head and D.state and D.share and D.list and D.web and D.area and D.areaHint, "the parts of the section")
assert(D.head.inherits.ListHeaderVisualTemplate, "a section header of the client")
local st = D.state:GetText()
assert(has(st, "6 Kills (2 eigene, 4 gehörte)") and has(st, "3 Bosse"), st)
assert(has(st, "neuester Tag " .. NS.DropsDate(today)) and has(st, "letzter Austausch"), st)
assert(#D.list.items == 10, "the list per instance and boss: " .. #D.list.items)
assert(has(D.list.rows[1].name:GetText(), "Geschmolzener Kern"))
assert(D.list.rows[3].rate:GetText() == "gesehen 2-mal in 2 Kills")
assert(D.list:IsShown() and not D.area:IsShown())

-- the sharing switch is the setting
assert(D.share:GetChecked() == true)
D.share:Click()
assert(NS.Get("drops.share") == false, "off")
NS.Refresh()
assert(D.share:GetChecked() == false)
D.share:Click()
assert(NS.Get("drops.share") == true, "on again")

-- layout at the main window's size
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(tf, 602, 478)
    L.column("tools page with drops", tf.state, tf.buttons[1], tf.hint, D.head, D.state, D.share, D.list)
    L.row("drop controls", D.share, D.shareLabel, D.web)
    L.row("drop list", D.list, D.list.bar)
    L.inside("drop list bar", D.list.bar)
    local _, lr = L.span(D.list)
    assert(lr == 590, "the list is 590 wide, its bar beside it: " .. lr)
    local hl, hr = L.span(D.head)
    assert(hl == 0 and hr == 602, "the header over the page width")
    local r1 = D.list.rows[1]
    L.row("drop row", r1.name, r1.rate)
    L.column("drop area", D.share, D.area, D.areaHint)
    L.inside("drop area", D.area)
    L.inside("drop area bar", D.area.bar)
    assert(D.web.inherits.SharedButtonSmallTemplate and D.web._h == 22)
    L.fits(D.shareLabel)
end

-- a new record shows on the page (at most once a second)
rec("a0000009", 213470, 409, today, HEARD, { [219004] = 1 })
STUB.tick(2)
assert(#D.list.items == 11, "the new item at Kurgor: " .. #D.list.items)
assert(has(D.state:GetText(), "7 Kills"), D.state:GetText())

-- the text for the website in place of the list
D.web:Click()
assert(D.area:IsShown() and D.areaHint:IsShown() and not D.list:IsShown())
assert(D.area.box:GetText() == NS.DropsExportText(), "the text Drops für die Website")
assert(has(D.area.box:GetText(), "\nDK a0000009 213470 409 1 "), D.area.box:GetText())
assert(D.web:GetText() == "Zur Liste")
assert(has(D.areaHint:GetText(), "Import"), D.areaHint:GetText())
-- read-only: typing puts the text back
D.area.box:SetText("kaputt")
D.area.box.scripts.OnTextChanged(D.area.box, true)
assert(D.area.box:GetText() == NS.DropsExportText())
D.web:Click()
assert(D.list:IsShown() and not D.area:IsShown() and D.web:GetText() == "Drops für die Website")

-- ns.ShowDropsExport (and /amisia drops export) open the page with the text
NS.ShowPage("overview")
NS.ShowDropsExport()
assert(NS.CurrentPage() == "tools" and D.area:IsShown() and D.area.box:GetText() == NS.DropsExportText())
D.web:Click()
NS.ShowPage("overview")
SlashCmdList.AMISIA("drops export")
assert(NS.CurrentPage() == "tools" and D.area:IsShown(), "the command opens the text")
D.web:Click()
-- without expert mode the page is not there: the command says where it is
NS.Reset("ui.expert")
NS.ShowPage("overview")
STUB.messages = {}
SlashCmdList.AMISIA("drops export")
assert(NS.CurrentPage() ~= "tools")
assert(msgs("Expertenmodus") == 1, table.concat(STUB.messages, " / "))

-- no records: the list says so
local saved = AmisiaDB.drops
AmisiaDB.drops = { v = 1, me = "12345678", k = {}, npc = {}, inst = {}, enc = {}, peers = {} }
assert(#NS.DropsBossList() == 0)
NS.Set("ui.expert", true)
NS.ShowPage("tools")
assert(#D.list.items == 0 and has(D.state:GetText(), "Noch keine Kills"), D.state:GetText())
AmisiaDB.drops = saved
NS.Reset("ui.expert")

-- Latin-1 only, in the files and in what the page showed
for _, file in ipairs({ "Collect/Drops.lua", "UI/Pages/Tools.lua" }) do
    local fh = assert(io.open(ADDON_DIR .. "/" .. file, "rb"))
    local src = fh:read("*a")
    fh:close()
    for lead in src:gmatch("[\192-\255]") do assert(lead:byte() <= 195, "beyond Latin-1 in " .. file) end
end
