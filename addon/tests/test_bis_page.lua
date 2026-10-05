-- The gear page (Pages/Gear.lua) on a small Forever data set: the head with the spec, the views,
-- the counts, the source chips and the table button; the targets with the slot details, the buttons "Wunsch" and "Aus", the
-- right-click menu and the explanation; "Hier" with the place picker; the wishlist with priority,
-- removal, the self clean-up and the text for the website; the guild wishes with import and clear
-- for officers; the raider view; /amisia wuensche; the overview card; the quick menu; the layout
-- of every view at the main window's size (content 602 x 478); Latin-1 only.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
STUB.class, STUB.level = "WARRIOR", 60
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
STUB.areas[2717], STUB.areas[2677], STUB.areas[2017] = "Geschmolzener Kern", "Pechschwingenhort", "Stratholme"
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Anna", class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

---------------------------------------------------------------------------
-- a small Forever data set (as build_gear.py writes it now); the client describes every item
---------------------------------------------------------------------------
NS.GEAR = { game = "forever", cap = 60, built = "test-page", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "X", "Geschmolzener Kern", "Lucifron", 409, 2717, 1, 0 },   -- 2
    { "X", "Pechschwingenhort", "Nefarian", 469, 2677, 1, 0 },    -- 3
    { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },   -- 4
} }
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, stats, sources, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 4
    it.stats, it.minLevel = stats, 60
    if sources then
        NS.GEAR.I[id] = { loc, o.classID or 4, o.sub or 4, 60, 4, 1, 141, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
local function str(n) return { ITEM_MOD_STRENGTH_SHORT = n } end
gear(301, "Helm A", "HEAD", str(40), { 1 })
gear(302, "Helm B", "HEAD", str(30), { 2 })
gear(303, "Helm C", "HEAD", str(20), { 3 })
gear(304, "Brust Kern", "CHEST", str(50), { 2 })
gear(305, "Ring Hort", "FINGER", str(20), { 3 }, { sub = 0 })
gear(306, "Helm Dungeon", "HEAD", str(25), { 4 })
gear(310, "Alter Helm", "HEAD", str(10))
STUB.worn[1] = LINKS[310]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

---------------------------------------------------------------------------
-- head
---------------------------------------------------------------------------
NS.ShowPage("gear")
assert(NS.CurrentPage() == "gear")
local f = NS.GearPageFrame()
assert(f and f:IsShown(), "the page frame is reachable")
assert(plain(f.spec.label:GetText()) == "Waffen/Furor (geraten)", f.spec.label:GetText())
assert(f.open:IsShown(), "the button for the level-range table")
assert(f.views.goals.on and not f.views.here.on, "the targets first")
assert(f.views.guild:IsShown(), "officers see the guild view")
assert(f.views.wish.label:GetText() == "Wunschliste (0)", f.views.wish.label:GetText())
local counts = f.counts:GetText()
assert(has(counts, "Level 60") and has(counts, "3 Upgrades") and has(counts, "Bank noch nicht geöffnet"), counts)
assert(not has(counts, "ausgeschlossen") and not f.reset:IsShown(), "no exclusions: " .. counts)
for _, k in ipairs({ "X", "Q", "D", "C", "V", "W", "A", "P" }) do assert(f.src[k]:IsShown(), "chip " .. k) end
assert(f.src.X.on and f.src.Q.on and not f.src.A.on and not f.src.P.on, "auction house and PvP start off")
assert(f.src.C.label:GetText() == "Berufe: alle")

---------------------------------------------------------------------------
-- targets
---------------------------------------------------------------------------
local G = f.goals
local rows = G.list.rows
assert(G:IsShown() and #G.list.items == 17, "all 17 slots")
assert(plain(rows[1].slot:GetText()) == "Kopf")
assert(has(rows[1].worn:GetText(), "Alter Helm"), rows[1].worn:GetText())
assert(has(rows[1].best:GetText(), "Helm A") and has(rows[1].best:GetText(), "a335ee"), rows[1].best:GetText())
assert(rows[1].src:GetText() == "Geschmolzener Kern: Ragnaros", rows[1].src:GetText())
assert(has(rows[1].gain:GetText(), "+60"), rows[1].gain:GetText())
assert(has(rows[2].best:GetText(), "keine Option") and has(rows[2].worn:GetText(), "nichts"), "an empty neck")
assert(has(rows[5].best:GetText(), "Brust Kern") and has(rows[5].gain:GetText(), "+100"), rows[5].gain:GetText())
-- the details of the chosen slot (the head first)
assert(rows[1].sel:IsShown() and not rows[5].sel:IsShown(), "the head is chosen")
assert(G.title:GetText() == "Kopf · Bestes für Waffen/Furor (geraten)", G.title:GetText())
local O = G.opts
assert(has(O[1].name:GetText(), "Helm A") and has(O[1].gain:GetText(), "+60") and O[1].rank:GetText() == "1")
assert(has(O[2].name:GetText(), "Helm B") and has(O[3].name:GetText(), "Helm Dungeon"), "three options, best first")
assert(O[1].src:GetText() == "Geschmolzener Kern: Ragnaros")
assert(O[1].wish:GetText() == "Wunsch" and O[1].wish:IsShown() and O[1].ex:IsShown())
local ex = G.explain:GetText()
assert(has(ex, "+60 Punkte, so viel wie 60 Angriffskraft") and has(ex, "40 Stärke x 2,0 = 80"), ex)
-- the explanation is kept while nothing changes
local explains = 0
local realExplain = NS.BisExplain
NS.BisExplain = function(...) explains = explains + 1; return realExplain(...) end
NS.Refresh(); NS.Refresh()
assert(explains == 0, "a refresh does not explain again: " .. explains)
NS.BisExplain = realExplain

-- a wish from the details: the star, the button, the count on the view chip
O[2].wish:Click()
assert(NS.BisChar().wish[302], "on the wishlist")
assert(O[2].wish:GetText() == "Wunsch weg" and has(O[2].name:GetText(), "UI-RaidTargetingIcon_1"), "the star")
assert(f.views.wish.label:GetText() == "Wunschliste (1)")
O[2].wish:Click()
assert(not NS.BisChar().wish[302] and O[2].wish:GetText() == "Wunsch", "and off again")
O[2].wish:Click()

-- excluding the best one: the next moves up; the counts and the reset with a question
O[1].ex:Click()
assert(NS.BisChar().ex.item[301], "excluded")
assert(has(O[1].name:GetText(), "Helm B") and has(rows[1].best:GetText(), "Helm B"), "the next moves up")
assert(has(f.counts:GetText(), "1 ausgeschlossen") and f.reset:IsShown(), f.counts:GetText())
f.reset:Click()
assert(STUB.popup and STUB.popup.which == "AMISIA_BIS_CLEAR_EX", "asks first")
assert(StaticPopupDialogs.AMISIA_BIS_CLEAR_EX.text == "Alle Ausschlüsse aufheben?")
STUB.acceptPopup()
assert(NS.BisExcludeCount() == 0 and has(O[1].name:GetText(), "Helm A") and not f.reset:IsShown(), "all back")

-- the right-click menu of an option
local function menuLabels()
    local out = {}
    for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then out[#out + 1] = b.label:GetText() end end
    return table.concat(out, "|")
end
local function menuClick(label)
    for _, b in ipairs(AmisiaMenu.buttons) do
        if b:IsShown() and b.label:GetText() == label then b:Click() return end
    end
    error("no menu entry " .. label)
end
O[1].scripts.OnClick(O[1], "RightButton")
assert(AmisiaMenu:IsShown())
assert(menuLabels() == "Item ausschließen|Boss ausschließen|Ort ausschließen|Auf die Wunschliste|Link in den Chat", menuLabels())
menuClick("Boss ausschließen")
assert(NS.BisChar().ex.boss["Ragnaros"] and has(O[1].name:GetText(), "Helm B"), "the boss is out")
O[1].scripts.OnClick(O[1], "RightButton")
menuClick("Ort ausschließen")
assert(NS.BisChar().ex.place["I:409"] and has(O[1].name:GetText(), "Helm Dungeon"), "Geschmolzener Kern is out: " .. O[1].name:GetText())
O[1].scripts.OnClick(O[1], "RightButton")
menuClick("Link in den Chat")
assert(STUB.inserted == LINKS[306], "the link goes into the chat")
O[2].scripts.OnClick(O[2], "RightButton")
assert(has(menuLabels(), "Von der Wunschliste nehmen") == false and has(menuLabels(), "Auf die Wunschliste"), menuLabels())
AmisiaMenu:Hide()
NS.BisClearExcludes()
O[2].scripts.OnClick(O[2], "RightButton")
assert(has(menuLabels(), "Von der Wunschliste nehmen"), "a wish offers its removal: " .. menuLabels())
AmisiaMenu:Hide()

-- choosing a slot; shift-click puts the link into the chat and keeps the choice
rows[5]:Click()
assert(G.title:GetText() == "Brust · Bestes für Waffen/Furor (geraten)" and rows[5].sel:IsShown() and not rows[1].sel:IsShown())
assert(AmisiaDB.settings.bis.slot == "CHEST", "kept as window state")
STUB.shift = true
rows[1]:Click()
STUB.shift = false
assert(STUB.inserted == LINKS[301] and G.title:GetText():find("^Brust"), "shift-click: the link, the slot stays")
-- a worn option: no buttons, "angelegt", the slot done
NS.ShowGear("goals", "HEAD")
STUB.worn[1] = LINKS[301]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
NS.Refresh()
assert(has(rows[1].gain:GetText(), "ReadyCheck-Ready"), "done: the check mark " .. rows[1].gain:GetText())
assert(O[1].src:GetText() == "angelegt" and not O[1].wish:IsShown() and not O[1].ex:IsShown(), "worn: no buttons")
assert(has(O[1].name:GetText(), "ReadyCheck-Ready"), "the check at the name")
assert(has(G.explain:GetText(), "angelegt"), G.explain:GetText())
STUB.worn[1] = LINKS[310]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

-- the spec: chosen, then back to the guess
f.spec.onPick("tank")
assert(NS.BisSpec() == "tank" and plain(f.spec.label:GetText()) == "Schutz", f.spec.label:GetText())
assert(G.title:GetText() == "Kopf · Bestes für Schutz", G.title:GetText())
f.spec.onPick("")
assert(select(2, NS.BisSpec()) == true and plain(f.spec.label:GetText()) == "Waffen/Furor (geraten)", "the guess again")

-- source chips, the professions chip in three steps
f.src.X:Click()
assert(AmisiaDB.settings.bis.sources.X == false and not f.src.X.on)
assert(has(rows[1].best:GetText(), "Helm Dungeon"), "without raids the dungeon helm: " .. rows[1].best:GetText())
f.src.X:Click()
assert(AmisiaDB.settings.bis.sources.X == true and has(rows[1].best:GetText(), "Helm A"))
f.src.C:Click()
assert(f.src.C.label:GetText() == "Berufe: meine" and NS.Get("bis.prof") == "mine" and f.src.C.on)
f.src.C:Click()
assert(f.src.C.label:GetText() == "Berufe" and AmisiaDB.settings.bis.sources.C == false and not f.src.C.on)
f.src.C:Click()
assert(f.src.C.label:GetText() == "Berufe: alle" and AmisiaDB.settings.bis.sources.C == true and NS.Get("bis.prof") == "all")

---------------------------------------------------------------------------
-- here
---------------------------------------------------------------------------
f.views.here:Click()
local Hh = f.here
assert(f.views.here.on and Hh:IsShown() and not G:IsShown(), "the here view")
assert(Hh.pick.label:GetText() == "Hier: Geschmolzener Kern", Hh.pick.label:GetText())
local hr = Hh.list.rows
assert(#Hh.list.items == 3, "chest, helm A and the wished helm B: " .. #Hh.list.items)
assert(has(hr[1].name:GetText(), "Brust Kern") and hr[1].boss:GetText() == "Lucifron" and plain(hr[1].slot:GetText()) == "Brust")
assert(has(hr[1].gain:GetText(), "+100") and hr[1].wishBtn:GetText() == "Wunsch")
assert(has(hr[3].name:GetText(), "Helm B") and has(hr[3].name:GetText(), "UI-RaidTargetingIcon_1") and hr[3].wishBtn:GetText() == "Wunsch weg")
assert(has(Hh.hint:GetText(), "Was du an diesem Ort noch holen kannst"), Hh.hint:GetText())
hr[1].wishBtn:Click()
assert(NS.BisChar().wish[304] and hr[1].wishBtn:GetText() == "Wunsch weg", "a wish from here")
-- the picker: here first, then the raids and dungeons of the data
local vals = {}
for i, v in ipairs(Hh.pick.values) do vals[i] = v.value .. "=" .. plain(v.text) end
vals = table.concat(vals, ",")
assert(has(vals, "here=Hier: Geschmolzener Kern,") and has(vals, "I:469=Pechschwingenhort") and has(vals, "I:329=Stratholme"), vals)
Hh.pick.onPick("I:469")
assert(AmisiaDB.settings.bis.place == "I:469" and plain(Hh.pick.label:GetText()) == "Pechschwingenhort", Hh.pick.label:GetText())
assert(#Hh.list.items == 2 and has(hr[1].name:GetText(), "Ring Hort") and has(hr[2].name:GetText(), "Helm C"), "the chosen place")
Hh.pick.onPick("here")
assert(AmisiaDB.settings.bis.place == nil and #Hh.list.items == 3)
-- a place the data does not know
STUB.instance = { name = "Dalaran", type = "none", id = 0 }
NS.Refresh()
assert(Hh.pick.label:GetText() == "Hier: unbekannt" and #Hh.list.items == 0, Hh.pick.label:GetText())
assert(Hh.hint:GetText() == "Diesen Ort kennen die Daten nicht.", Hh.hint:GetText())
-- nothing left: the dungeon helm is worn
Hh.pick.onPick("I:329")
assert(#Hh.list.items == 1)
STUB.worn[1] = LINKS[306]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
NS.Refresh()
assert(#Hh.list.items == 0 and Hh.hint:GetText() == "Hier gibt es nichts mehr für dich.", Hh.hint:GetText())
STUB.worn[1] = LINKS[310]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
-- /amisia bis hier goes back to the current place
NS.Dispatch("bis hier")
assert(NS.CurrentPage() == "gear" and f.views.here.on and Hh.pick.label:GetText() == "Hier: Geschmolzener Kern")

---------------------------------------------------------------------------
-- wishlist
---------------------------------------------------------------------------
f.views.wish:Click()
local V = f.wish
local wr = V.list.rows
assert(V:IsShown() and not Hh:IsShown() and #V.list.items == 2, "two wishes")
assert(has(wr[1].name:GetText(), "Brust Kern") and plain(wr[1].slot:GetText()) == "Brust" and wr[1].src:GetText() == "Geschmolzener Kern: Lucifron")
assert(wr[1].prio.label:GetText() == "mittel" and wr[1].state:GetText() == "")
wr[1].prio:Click()
assert(NS.BisChar().wish[304].prio == 1, "medium to low")
assert(has(wr[1].name:GetText(), "Helm B") and wr[2].prio.label:GetText() == "niedrig", "sorted by priority again")
wr[2].prio:Click()
assert(NS.BisChar().wish[304].prio == 3 and has(wr[1].name:GetText(), "Brust Kern") and wr[1].prio.label:GetText() == "hoch")
-- an excluded wish says so
NS.BisExclude("item", 302)
assert(has(wr[2].state:GetText(), "aus"), wr[2].state:GetText())
NS.BisClearExcludes()
-- the self clean-up takes an owned wish off
STUB.bags[0] = { 302 }
NS.BisScanBags()
assert(not NS.BisChar().wish[302] and #V.list.items == 1, "the own helm left the list")
assert(not V.clean:IsShown(), "no clean-up button while the list cleans itself")
-- without the clean-up: "hast du" and the button
NS.Set("bis.wishAutoRemove", false)
assert(NS.WishAdd(302))
assert(#V.list.items == 2 and V.clean:IsShown())
local owned
for _, r in ipairs(wr) do if r:IsShown() and has(r.name:GetText(), "Helm B") then owned = r end end
assert(owned and has(owned.state:GetText(), "hast du"), "owned")
V.clean:Click()
assert(not NS.BisChar().wish[302] and #V.list.items == 1, "the owned wish is gone")
NS.Reset("bis.wishAutoRemove")
STUB.bags[0] = nil
NS.BisScanBags()
-- the text for the website: read-only, marked
V.web:Click()
assert(V.area:IsShown() and not V.list:IsShown() and V.web:GetText() == "Zur Liste")
local text = V.area.box:GetText()
assert(text == NS.WishExportText() and has(text, "#AMISIA 2 Vuloo\nWL 304 3 "), text)
assert(has(V.areaHint:GetText(), "Strg+A, Strg+C") and has(V.areaHint:GetText(), "Paste from the addon"), V.areaHint:GetText())
V.area.box:SetText("kaputt")
V.area.box.scripts.OnTextChanged(V.area.box, true)
assert(V.area.box:GetText() == text, "typing puts the text back")
V.web:Click()
assert(V.list:IsShown() and not V.area:IsShown() and V.web:GetText() == "Für die Website")
-- remove with the x
wr[1].del:Click()
assert(not NS.BisChar().wish[304] and #V.list.items == 0)
assert(has(V.hint:GetText(), "Noch keine Wünsche"), V.hint:GetText())
-- /amisia wunsch opens it
f.views.goals:Click()
NS.Dispatch("wunsch")
assert(f.views.wish.on, "the command opens the wishlist")

---------------------------------------------------------------------------
-- guild wishes
---------------------------------------------------------------------------
f.views.guild:Click()
local U = f.guild
assert(U:IsShown() and U.area:IsShown() and U.importBtn:IsShown() and U.clearBtn:IsShown(), "officers import")
assert(has(U.info:GetText(), "Keine Gildenwünsche geladen"), U.info:GetText())
assert(has(U.hint:GetText(), "Copy for the addon"))
U.area.box:SetText("#AMISIA-WL 1 forever 2026-10-05\nW 301 3 Anna nur MS\nW 301 2 Bob\nW 304 1 Vuloo\n#END")
U.importBtn:Click()
assert(AmisiaDB.bis.guild and AmisiaDB.bis.guild.n == 3, "imported")
assert(has(U.hint:GetText(), "3 Wünsche übernommen"), U.hint:GetText())
assert(U.area.box:GetText() == "", "the box is emptied")
assert(has(U.info:GetText(), "Liste vom 05.10.2026, 3 Wünsche"), U.info:GetText())
local gr = U.list.rows
assert(U.group.on, "only the group while in a raid")
assert(#U.list.items == 2 and has(gr[1].name:GetText(), "Helm A") and has(gr[1].who:GetText(), "Anna (hoch)"), gr[1].who:GetText())
assert(not has(gr[1].who:GetText(), "Bob"), "Bob is not in the group")
assert(has(gr[1].who:GetText(), "ffffffff"), "in the class colour of the raid")
U.group:Click()
assert(not U.group.on and has(gr[1].who:GetText(), "Bob"), gr[1].who:GetText())
U.group:Click()
-- the wrong game
U.area.box:SetText("#AMISIA-WL 1 tbc 2026-10-05\nW 1 2 Anna\n#END")
U.importBtn:Click()
assert(has(U.hint:GetText(), "TBC Anniversary") and AmisiaDB.bis.guild.n == 3, U.hint:GetText())
-- /amisia wuensche opens this view
f.views.goals:Click()
NS.Dispatch("wuensche")
assert(NS.CurrentPage() == "gear" and f.views.guild.on and U:IsShown(), "the command opens the guild view")

---------------------------------------------------------------------------
-- layout at the main window's size (content 602 x 478)
---------------------------------------------------------------------------
local Hx = { LEFT = "L", TOPLEFT = "L", BOTTOMLEFT = "L", RIGHT = "R", TOPRIGHT = "R", BOTTOMRIGHT = "R" }
local Vx = { TOP = "T", TOPLEFT = "T", TOPRIGHT = "T", BOTTOM = "B", BOTTOMLEFT = "B", BOTTOMRIGHT = "B" }
local root, rootW, rootH = f, 602, 478
local span, vspan
local function edge(rel, relPoint, owner)
    rel = rel or owner.parent
    local l, r = span(rel)
    local c = Hx[relPoint] or "C"
    if c == "L" then return l elseif c == "R" then return r end
    return (l + r) / 2
end
span = function(fr)
    if fr == root then return 0, rootW end
    assert(fr ~= UIParent and fr ~= nil, "laid out outside the root")
    local Lx, R, C
    for p, a in pairs(fr.points or {}) do
        local x = edge(a.rel, a.relPoint, fr) + a.x
        local c = Hx[p] or "C"
        if c == "L" then Lx = x elseif c == "R" then R = x else C = x end
    end
    local w = fr._w
    if Lx and R then return Lx, R end
    assert(w, "a width for " .. tostring(fr.name or fr.text))
    if Lx then return Lx, Lx + w end
    if R then return R - w, R end
    assert(C, "an anchor for " .. tostring(fr.name or fr.text))
    return C - w / 2, C + w / 2
end
local function vedge(rel, relPoint, owner)
    rel = rel or owner.parent
    local t, b = vspan(rel)
    local c = Vx[relPoint] or "C"
    if c == "T" then return t elseif c == "B" then return b end
    return (t + b) / 2
end
vspan = function(fr)
    if fr == root then return 0, -rootH end
    assert(fr ~= UIParent and fr ~= nil, "laid out outside the root")
    local T, Bt, C
    for p, a in pairs(fr.points or {}) do
        local y = vedge(a.rel, a.relPoint, fr) + a.y
        local c = Vx[p] or "C"
        if c == "T" then T = y elseif c == "B" then Bt = y else C = y end
    end
    local h = fr._h or 14
    if T and Bt then return T, Bt end
    if T then return T, T - h end
    if Bt then return Bt + h, Bt end
    assert(C, "an anchor for " .. tostring(fr.name or fr.text))
    return C + h / 2, C - h / 2
end
local function row(name, ...)
    local prevR
    for i, fr in ipairs({ ... }) do
        local l, r = span(fr)
        assert(l >= 0 and r <= rootW, ("%s #%d leaves its frame: %d..%d of %d"):format(name, i, l, r, rootW))
        if prevR then assert(l >= prevR, ("%s #%d overlaps #%d: %d < %d"):format(name, i, i - 1, l, prevR)) end
        prevR = r
    end
end
local function column(name, ...)
    local prevB
    for i, fr in ipairs({ ... }) do
        local t, b = vspan(fr)
        assert(t <= 0 and b >= -rootH, ("%s #%d leaves its frame: %d..%d of %d"):format(name, i, t, b, rootH))
        if prevB then assert(t <= prevB, ("%s #%d overlaps #%d: %d > %d"):format(name, i, i - 1, t, prevB)) end
        prevB = b
    end
end
local function fits(fs)
    assert(fs:GetStringWidth() <= fs._w, ("'%s' fits %s px"):format(tostring(fs:GetText()), tostring(fs._w)))
end

local function layoutAll(who)
    f.views.goals:Click()
    row(who .. " head", f.spec, f.views.goals, f.views.here, f.views.wish, f.views.guild, f.open)
    row(who .. " counts", f.counts, f.reset)
    row(who .. " sources", f.src.X, f.src.Q, f.src.D, f.src.C, f.src.V, f.src.W, f.src.A, f.src.P)
    row(who .. " goal columns", G.head.slot, G.head.worn, G.head.best, G.head.src, G.head.gain)
    row(who .. " goal row", rows[1].slot, rows[1].worn, rows[1].best, rows[1].src, rows[1].gain)
    row(who .. " option", O[1].rank, O[1].name, O[1].src, O[1].gain, O[1].wish, O[1].ex)
    column(who .. " goals", f.spec, f.counts, f.src.X, G.head.slot, G.list, G.title, O[1], O[2], O[3], G.explain)
    f.views.here:Click()
    row(who .. " here columns", Hh.head.boss, Hh.head.name, Hh.head.slot, Hh.head.gain)
    row(who .. " here row", hr[1].boss, hr[1].name, hr[1].slot, hr[1].gain, hr[1].wishBtn)
    column(who .. " here", f.src.X, Hh.pick, Hh.head.boss, Hh.list, Hh.hint)
    f.views.wish:Click()
    row(who .. " wish columns", V.head.name, V.head.slot, V.head.src, V.head.prio, V.head.state)
    row(who .. " wish row", wr[1].name, wr[1].slot, wr[1].src, wr[1].prio, wr[1].state, wr[1].del)
    row(who .. " wish buttons", V.web, V.clean)
    column(who .. " wish", f.src.X, V.head.name, V.list, V.web, V.hint)
    V.web:Click()
    column(who .. " wish box", V.head.name, V.area, V.areaHint, V.web)
    V.web:Click()
    if f.views.guild:IsShown() then
        f.views.guild:Click()
        row(who .. " guild top", U.info, U.group)
        row(who .. " guild columns", U.head.name, U.head.who)
        row(who .. " guild row", gr[1].name, gr[1].who)
        if U.area:IsShown() then
            row(who .. " guild buttons", U.importBtn, U.clearBtn, U.hint)
            column(who .. " guild", f.src.X, U.info, U.head.name, U.list, U.area, U.importBtn)
        else
            column(who .. " guild", f.src.X, U.info, U.head.name, U.list, U.hint)
        end
    end
    f.views.goals:Click()
end
assert(NS.WishAdd(304, 3, "eine lange Notiz für die Seite"))
STUB.bags[0] = { 302 }
NS.Set("bis.wishAutoRemove", false)
assert(NS.WishAdd(302))
NS.BisScanBags()
NS.BisExclude("item", 303)
f.views.wish:Click()
fits(wr[2].state)
layoutAll("officer")

---------------------------------------------------------------------------
-- raider view: the guild list without import; no list, no guild view
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
NS.ShowGear("guild")
assert(f.views.guild:IsShown() and f.views.guild.on and U:IsShown(), "a loaded list is shown to raiders")
assert(not U.area:IsShown() and not U.importBtn:IsShown() and not U.clearBtn:IsShown(), "no import for raiders")
layoutAll("raider")
NS.ClearGuildWishes()
NS.ShowGear("guild")
assert(not f.views.guild:IsShown() and f.views.goals.on and G:IsShown(), "no list: no guild view for raiders")
NS.Dispatch("wuensche")
assert(has(STUB.messages[#STUB.messages], "Offiziersansicht"), "the command stays for officers")
NS.Reset("ui.view")
-- officers clear with a question
assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-05\nW 301 3 Anna\n#END"))
NS.ShowGear("guild")
U.clearBtn:Click()
assert(STUB.popup and STUB.popup.which == "AMISIA_GUILDWISH_CLEAR", "asks first")
STUB.acceptPopup()
assert(AmisiaDB.bis.guild == nil and has(U.info:GetText(), "Keine Gildenwünsche geladen"), U.info:GetText())
NS.Reset("bis.wishAutoRemove")

---------------------------------------------------------------------------
-- the card, the toast's way in, the quick menu
---------------------------------------------------------------------------
local card
for _, c in ipairs(NS.cards) do if c.key == "gear" then card = c end end
assert(card and card.available(), "the card with the data")
local c = NS.W.Card(UIParent, 296, 112)
card.fill(c)
assert(c.title:GetText() == "Deine Ausrüstung")
assert(has(c.line1:GetText(), "Level 60") and has(c.line1:GetText(), "Upgrades") and has(c.line1:GetText(), "Wünsche"), c.line1:GetText())
assert(has(c.line2:GetText(), "Hier: ") and has(c.line2:GetText(), "(Geschmolzener Kern)"), "in a raid the place: " .. c.line2:GetText())
STUB.instance = { name = "Sturmwind", type = "none", id = 0 }
card.fill(c)
assert(has(c.line2:GetText(), "Bestes: ") and has(c.line2:GetText(), "Brust Kern") and has(c.line2:GetText(), "(+100)"), c.line2:GetText())
c.button:Click()
assert(NS.CurrentPage() == "gear" and f.views.goals.on, "Ansehen opens the targets")
NS.ShowGear("ziele", "CHEST")
assert(f.views.goals.on and G.title:GetText():find("^Brust"), "German view names, a slot from the toast")
local entries = {}
for _, e in ipairs(NS.MinimapMenuEntries()) do entries[#entries + 1] = e[1] end
entries = table.concat(entries, "|")
assert(has(entries, "Ausrüstung|Ausrüstungstabelle"), "the page, then the table: " .. entries)
NS.ShowPage("overview")
for _, e in ipairs(NS.MinimapMenuEntries()) do if e[1] == "Ausrüstung" then e[2]() end end
assert(NS.CurrentPage() == "gear", "the quick menu opens the page")
-- the planner's upgrades come from the targets
local list = NS.GearMyUpgrades()
assert(list[1] and list[1].id == 304 and math.floor(list[1].gain + 0.5) == 100 and list[1].slot.key == "CHEST", "the best upgrade first")

---------------------------------------------------------------------------
-- Latin-1 only, in the file and in what the page showed
---------------------------------------------------------------------------
local fh = assert(io.open(ADDON_DIR .. "/Pages/Gear.lua", "rb"))
local src = fh:read("*a")
fh:close()
for lead in src:gmatch("[\192-\255]") do assert(lead:byte() <= 195, "beyond Latin-1 in Pages/Gear.lua") end
