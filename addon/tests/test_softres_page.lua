-- The soft-reserves page: the head with the check against the raid, the three views (items,
-- raiders, check), fix-name chips that remember the fix, the officer and raider views, the card,
-- the preview in the import window and the settings of the "softres" section.
STUB.instance = { name = "Dalaran", type = "none", id = 0 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
                { name = "Bobbington", class = "WARRIOR" }, { name = "Anna Bergmann", class = "PRIEST" } }
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
local LIST = "Vuloo 32235\nVuloo 32235\nFraktur 32235\nBobingtn 32837\nGustav 32837\nAnna 32837\n"
NS.SetSoftRes(LIST)

local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

NS.ShowPage("softres")
local f = NS.SoftResPageFrame()
assert(f, "the page frame is reachable")
assert(NS.CurrentPage() == "softres")

---------------------------------------------------------------------------
-- head: the list and the check
---------------------------------------------------------------------------
local today = date("%d.%m.")
assert(has(f.state:GetText(), "Liste vom " .. today) and has(f.state:GetText(), "6 Reservierungen von 5 Raidern"), f.state:GetText())
local check = f.check:GetText()
assert(has(check, "Abgleich mit Raid (5): 3 reserviert") and has(check, "2 ohne") and has(check, "2 nicht im Raid")
    and has(check, "2 unklar"), check)
assert(not has(check, "zu viel"), "no limit, no over part: " .. check)
assert(f.import:IsShown() and f.clear:IsShown(), "officers import and clear")
assert(f.views.items:IsShown() and f.views.raider:IsShown() and f.views.check:IsShown(), "three views for officers")

---------------------------------------------------------------------------
-- items view (the default)
---------------------------------------------------------------------------
assert(f.views.items.on and not f.views.raider.on, "items view first")
local rows = f.list.rows
assert(has(rows[1].a:GetText(), "Cursed Vision") and has(rows[1].a:GetText(), "a335ee"), "item in its quality colour: " .. rows[1].a:GetText())
assert(has(rows[1].c:GetText(), "Vuloo x2") and has(rows[1].c:GetText(), "Fraktur"), rows[1].c:GetText())
assert(has(rows[2].a:GetText(), "Warglaive") and has(rows[2].a:GetText(), "ff8000"), rows[2].a:GetText())
local names2 = rows[2].c:GetText()
assert(has(names2, "Gustav (nicht im Raid)") and has(names2, "Bobingtn (nicht im Raid)"), names2)
assert(has(names2, "Anna") and not has(names2, "Anna (nicht im Raid)"), "Anna is in the raid by first name: " .. names2)
assert(not rows[3]:IsShown(), "two items")
assert(rows[1].b:GetText() == "", "no count column in the items view")
-- shift-click puts the link into the chat, the mouse shows the item
STUB.shift = true
rows[1]:Click()
STUB.shift = false
assert(STUB.inserted == link, "link to the chat: " .. tostring(STUB.inserted))

---------------------------------------------------------------------------
-- raider view
---------------------------------------------------------------------------
f.views.raider:Click()
assert(f.views.raider.on and not f.views.items.on, "raider view chosen")
local byName = {}
for _, r in ipairs(rows) do
    if r:IsShown() then byName[(r.a:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(" %(nicht im Raid%)", ""))] = r end
end
assert(byName.Vuloo and byName.Vuloo.b:GetText() == "2" and has(byName.Vuloo.c:GetText(), "Cursed Vision of Sargeras x2"), "Vuloo reserved twice")
assert(byName.Fraktur and has(byName.Fraktur.a:GetText(), "ff0070de"), "class colour from the raid")
assert(byName.Chorf and byName.Chorf.b:GetText() == "0" and byName.Chorf.c:GetText() == "keine", "raiders without a reservation stand there too")
assert(byName.Gustav and has(byName.Gustav.a:GetText(), "(nicht im Raid)"), "a name outside the raid")
assert(byName.Bobbington and byName.Bobbington.c:GetText() == "keine")
-- over the limit: the count turns red
assert(NS.Set("softres.limit", 1))
local red
for _, r in ipairs(rows) do if r:IsShown() and has(r.a:GetText(), "Vuloo") then red = r end end
assert(red and has(red.b:GetText(), "ff5050"), "red over the limit: " .. tostring(red and red.b:GetText()))
assert(has(f.check:GetText(), "1 zu viel"), f.check:GetText())
NS.Reset("softres.limit")

---------------------------------------------------------------------------
-- check view: findings in order, chips fix a name and remember it
---------------------------------------------------------------------------
AmisiaDB.softres.reminded.Chorf = STUB.now - 600
f.views.check:Click()
assert(f.views.check.on, "check view chosen")
local function rowTexts()
    local out = {}
    for _, r in ipairs(rows) do if r:IsShown() then out[#out + 1] = r.a:GetText() end end
    return out
end
local t = rowTexts()
assert(has(t[1], "Unklar") and has(t[1], "Anna"), tostring(t[1]))
assert(has(t[2], "Unklar") and has(t[2], "Bobingtn"), tostring(t[2]))
assert(has(t[3], "Ohne Reserve") and has(t[3], "Bobbington"), tostring(t[3]))
assert(has(t[4], "Ohne Reserve") and has(t[4], "Chorf"), tostring(t[4]))
assert(has(t[5], "Nicht im Raid") and has(t[5], "Gustav"), tostring(t[5]))
assert(has(t[6], "Mehrfach") and has(t[6], "Vuloo"), tostring(t[6]))
assert(#t == 6, "Bobingtn stands once, as unclear: " .. #t)
assert(rows[4].c:GetText() == "erinnert " .. date("%H:%M", STUB.now - 600), "reminded shows the time: " .. rows[4].c:GetText())
assert(rows[3].c:GetText() == "", "not reminded yet")
assert(has(rows[6].c:GetText(), "Cursed Vision of Sargeras x2"), rows[6].c:GetText())
-- suggestions as chips
assert(rows[1].chips[1]:IsShown() and rows[1].chips[1].label:GetText() == "Anna Bergmann", "the surname as a chip")
assert(not rows[1].chips[2]:IsShown())
assert(rows[2].chips[1]:IsShown() and rows[2].chips[1].label:GetText() == "Bobbington")
assert(not rows[3].chips[1]:IsShown() and not rows[5].chips[1]:IsShown(), "only unclear rows have chips")
rows[1].chips[1]:Click()
local res = NS.ReservedBy(32837)
local found = false
for _, n in ipairs(res) do if n == "Anna Bergmann" then found = true end end
assert(found, "renamed in the list")
assert(AmisiaDB.srAliases.anna == "Anna Bergmann", "the fix is remembered for later lists")
-- the rows were drawn again: the pooled row now holding another finding shows no stale chip
t = rowTexts()
assert(has(t[1], "Bobingtn") and rows[1].chips[1].label:GetText() == "Bobbington", tostring(t[1]))
assert(has(t[2], "Ohne Reserve") and not rows[2].chips[1]:IsShown(), "pooled row reset its chips")
assert(has(f.check:GetText(), "1 unklar"), f.check:GetText())
rows[1].chips[1]:Click()
assert(AmisiaDB.srAliases.bobingtn == "Bobbington")
assert(has(f.check:GetText(), "4 reserviert") and has(f.check:GetText(), "1 ohne") and not has(f.check:GetText(), "unklar"), f.check:GetText())
-- the raider view names the spelling of the list after a fix
f.views.raider:Click()
local fixed
for _, r in ipairs(rows) do if r:IsShown() and has(r.a:GetText(), "Anna Bergmann") then fixed = r end end
assert(fixed and has(fixed.a:GetText(), "(Liste: Anna)") and fixed.b:GetText() == "1", fixed and fixed.a:GetText())
f.views.check:Click()

---------------------------------------------------------------------------
-- layout at the main window's size (content 602 px)
---------------------------------------------------------------------------
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
local span, row = Lay.span, Lay.row
row("head", f.state, f.import, f.clear)
-- the list ends 12 px before the edge; its thin bar sits in that gap, inside the page
row("list", f.list, f.list.bar)
local _, lr = span(f.list)
assert(lr == 590, "the list is 590 wide: " .. lr)
Lay.inside("list bar", f.list.bar)
Lay.column("page", f.state, f.check, f.views.items, f.heads[1], f.list, f.hint)
Lay.inside("hint", f.hint)
assert(rows[1].sel.atlas == "Professions_Recipe_Active", "an own row glows like the recipe list's")
row("check line", f.check)
row("views", f.views.items, f.views.raider, f.views.check, f.remind, f.post)
-- a check row with the widest suggestions
AmisiaDB.srAliases = {}
NS.SetSoftRes("Kara Sehrlangernam 32235\n")
STUB.roster = { { name = "Kara Langernameee", class = "PRIEST" }, { name = "Kara Nochlaengerer", class = "PRIEST" }, { name = "Kara Sehrlangername", class = "PRIEST" } }
NS.Refresh()
local r1 = rows[1]
assert(r1.chips[1]:IsShown(), "a suggestion is shown")
row("check row", r1.a, r1.chips[1], r1.chips[2], r1.chips[3])
-- the widest chips end inside the 590 px row, before the bar
local _, cr = span(r1.chips[3])
assert(cr <= 590, "the chips end in the row: " .. cr)
for _, v in ipairs({ "items", "raider" }) do
    f.views[v]:Click()
    row(v .. " row", rows[1].a, rows[1].b, rows[1].c)
    local _, er = span(rows[1].c)
    assert(er <= 590, v .. " row ends in the list: " .. er)
end
f.views.check:Click()

---------------------------------------------------------------------------
-- raider view of the page: items and raiders, own rows golden, no buttons
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
NS.SetSoftRes("Vuloo 32235\nFraktur 32837\n")
NS.Set("ui.view", "raider")
NS.ShowPage("softres")
assert(not f.import:IsShown() and not f.clear:IsShown(), "no import or clear for raiders")
assert(not f.views.check:IsShown(), "no check view for raiders")
assert(f.views.items.on, "the check view falls back to items")
assert(has(f.check:GetText(), "Abgleich mit Raid (3): 2 reserviert") and has(f.check:GetText(), "1 ohne"), "the numbers stay: " .. f.check:GetText())
assert(rows[1].sel:IsShown() and not rows[2].sel:IsShown(), "my own row is golden")
f.views.raider:Click()
for _, r in ipairs(rows) do
    if r:IsShown() then
        assert((has(r.a:GetText(), "Vuloo")) == r.sel:IsShown(), "only my row golden: " .. r.a:GetText())
    end
end
f.views.items:Click()
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- the card
---------------------------------------------------------------------------
NS.SetSoftRes("Vuloo 32235\nFraktur 32837\nChorff 32837\n")
local card
for _, c in ipairs(NS.cards) do if c.key == "softres" then card = c end end
local fake = { title = CreateFrame("Frame"), line1 = CreateFrame("Frame"), line2 = CreateFrame("Frame") }
function fake:SetAction(label, fn) self.label, self.fn = label, fn end
card.fill(fake)
assert(fake.line1:GetText() == "3 Reservierungen, vom " .. date("%Y-%m-%d"), fake.line1:GetText())
assert(has(fake.line2:GetText(), "2 von 3 im Raid reserviert") and has(fake.line2:GetText(), "1 Name unklar"), fake.line2:GetText())
assert(fake.label == "Prüfen", "officers with unclear names check: " .. tostring(fake.label))
NS.ShowPage("overview")
fake.fn()
assert(NS.CurrentPage() == "softres" and f.views.check.on, "the card opens the check view")
NS.Set("ui.view", "raider")
card.fill(fake)
assert(fake.label == "Ansehen", "raiders look")
NS.Reset("ui.view")
NS.SetSoftRes("Vuloo 32235\nFraktur 32837\nChorf 32837\n")
card.fill(fake)
assert(fake.line2:GetText() == "3 von 3 im Raid reserviert" and fake.label == "Ansehen", fake.line2:GetText())
-- without a raid: the last raid, or nothing to check against
STUB.roster = {}
NS.Refresh()
assert(f.check:GetText() == "Kein Raid zum Abgleichen.", f.check:GetText())
card.fill(fake)
assert(fake.line2:GetText() == "", "no raid, no check line: " .. fake.line2:GetText())
AmisiaDB.sessions[#AmisiaDB.sessions + 1] = { id = "b", start = STUB.now - 3 * 86400, members = { Fraktur = {}, Chorf = {}, Anna = {} },
    loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
card.fill(fake)
assert(fake.line2:GetText() == "Abgleich mit letztem Raid: 1 ohne Reserve", fake.line2:GetText())
NS.Refresh()
assert(has(f.check:GetText(), "Abgleich mit letztem Raid, " .. date("%d.%m.", STUB.now - 3 * 86400) .. ": 2 reserviert"), f.check:GetText())
table.remove(AmisiaDB.sessions)

-- the roster changing refreshes the page (half a second later, once per burst)
STUB.roster = { { name = "Vuloo", class = "PRIEST" } }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(1)
assert(has(f.check:GetText(), "Abgleich mit Raid (1): 1 reserviert"), f.check:GetText())

---------------------------------------------------------------------------
-- import window: the preview before applying
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
                { name = "Bobbington", class = "WARRIOR" }, { name = "Anna Bergmann", class = "PRIEST" } }
AmisiaDB.srAliases = {}
NS.ClearSoftRes()
NS.ToggleSoftResFrame()
local F = NS.SoftResFrame
assert(F.applyBtn:GetText() == "Übernehmen" and F.clearBtn:GetText() == "Leeren", "the buttons with umlauts")
F.editBox:SetText(LIST .. "Junk\n")
F.editBox.scripts.OnTextChanged(F.editBox, true)
STUB.tick(0.1)
assert((F.previewText:GetText() or "") == "", "not before 0.3 s")
F.editBox.scripts.OnTextChanged(F.editBox, true)
STUB.tick(0.25)
assert((F.previewText:GetText() or "") == "", "a new change starts the wait again")
STUB.tick(0.1)
local p = F.previewText:GetText()
assert(has(p, "Vorschau gegen Raid (5): 5 Raider, 6 Reservierungen") and has(p, "2 ohne Reserve") and has(p, "2 nicht im Raid")
    and has(p, "2 Namen unklar") and has(p, "1 Zeile nicht erkannt"), p)
assert(AmisiaDB.softres == nil, "the preview stores nothing")
-- remembered fixes act in the preview
AmisiaDB.srAliases.bobingtn = "Bobbington"
F.editBox.scripts.OnTextChanged(F.editBox, true)
STUB.tick(0.3)
p = F.previewText:GetText()
assert(has(p, "1 ohne Reserve") and has(p, "1 nicht im Raid") and has(p, "1 Name unklar"), p)
-- an empty box: no preview
F.editBox:SetText("")
F.editBox.scripts.OnTextChanged(F.editBox, true)
STUB.tick(0.3)
assert(F.previewText:GetText() == "", F.previewText:GetText())
-- without anything to check against
STUB.roster = {}
assert(has(NS.SoftResPreviewText("Vuloo 32235"), "Vorschau: 1 Raider, 1 Reservierung") and has(NS.SoftResPreviewText("Vuloo 32235"), "kein Raid zum Abgleichen"),
    NS.SoftResPreviewText("Vuloo 32235"))
F.editBox:SetText("Chorf " .. link2)
F.applyBtn:Click()
assert(has(F.resultText:GetText(), "1 Reservierungen übernommen"), F.resultText:GetText())
NS.ToggleSoftResFrame()

---------------------------------------------------------------------------
-- settings of the section
---------------------------------------------------------------------------
local lm = NS.SettingItem("softres.lootMark")
assert(lm.label == "SR-Markierung im Lootfenster und an den Würfelfenstern", lm.label)
local chat = NS.SettingItem("softres.chat")
assert(chat and chat.type == "toggle" and chat.default == true and chat.officer and NS.Get("softres.chat") == true)
local rt = NS.SettingItem("softres.remindText")
assert(rt and rt.type == "text" and rt.default == "" and rt.officer and rt.tip)
assert(NS.Set("softres.remindText", "Liste: |cffffffffsoftres\nit/abc"))
assert(NS.Get("softres.remindText") == "Liste: cffffffffsoftres it/abc", NS.Get("softres.remindText"))
assert(NS.Set("softres.remindText", string.rep("ä", 130)))
assert(NS.Get("softres.remindText") == string.rep("ä", 120), "at most 120 characters, none cut in half: " .. #NS.Get("softres.remindText"))
NS.Reset("softres.remindText")
NS.Set("ui.view", "raider")
assert(not NS.Visible(chat) and not NS.Visible(rt) and NS.Visible(lm), "officer settings stay hidden for raiders")
NS.Reset("ui.view")
