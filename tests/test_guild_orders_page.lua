-- The tab Aufträge and the window "Auftrag stellen" (F-231, UI/Pages/Professions.lua): /amisia auftraege opens the
-- tab after Herstellliste; "Meine Aufträge" with "Zurückziehen" (and "Erhalten" when done), "Für mich herstellbar"
-- with "Annehmen" (grey while the requester is offline, "Angefragt" after the click), "Alle offenen"; the recipe's
-- guild box has "Auftrag stellen", whose window places the order with count, material and note; off: a note only.
local GO = NS.GuildOrders
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.guild = { { name = "Vulo Sturmwind", rank = 1, online = true }, { name = "Anna Amboss", rank = 3, online = true, class = "MAGE" },
    { name = "Bob Hammer", rank = 3, online = true }, { name = "Cleo Kessel", rank = 3, online = false } }
STUB.fire("GUILD_ROSTER_UPDATE")
local D = NS.DropsToday()
AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [171] = { rank = 300, max = 300, day = D, known = { [2330] = true } } } } }
local function recv(sender, ...)
    STUB.tick(4)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1OA\t" .. table.concat({ ... }, "\t"), "GUILD", sender, "", 0, 0, "", 0)
    STUB.tick(0.1)
end
local mine = GO.Create(3321, 2, "B", "zahle 5g")
recv("Anna Amboss", "a001", "1", "2330", "4", "H", "O", "-", "3600", "Stoff hab ich", "118")
recv("Cleo Kessel", "c001", "1", "2330", "1", "B", "O", "-", "0", "-", "118")
recv("Bob Hammer", "b001", "1", "1234001", "1", "A", "T", "Anna Amboss", "0", "-")

NS.Dispatch("auftraege")
local f = NS.PageFrame("professions")
assert(f and f:IsShown(), "the page opened")
assert(f.orView:IsShown() and f.tabOrders.on and not f.tabQueue.on and not f.cdView:IsShown(), "the tab Aufträge")
assert(not f.list:IsShown() and not f.headBlock:IsShown(), "nothing of a profession's view")
-- the tab stands after Herstellliste
local idx = {}
for i, t in ipairs(f.tabs) do idx[t] = i end
assert(idx[f.tabOrders] == idx[f.tabQueue] + 1, "after Herstellliste")
local function text(e) return e.head or e.note or (e.order.sender or "me") .. "|" .. e.order.id end
local got = {}
for i, e in ipairs(f.orList.items) do got[i] = text(e) end
local want = { "Meine Aufträge", "me|" .. mine, "Für mich herstellbar", "Anna Amboss|a001", "Cleo Kessel|c001", "Alle offenen",
    "Bob Hammer|b001" }
assert(table.concat(got, ", ") == table.concat(want, ", "), table.concat(got, ", "))
assert(has(f.orCounts:GetText(), "1 eigene · 2 für dich · 1 weitere"), f.orCounts:GetText())
local rows = f.orList.rows
-- the own order: offen, its note, "Zurückziehen"
assert(has(rows[2].line:GetText(), "offen") and has(rows[2].line:GetText(), "zahle 5g") and has(rows[2].line:GetText(), "bringe ich mit"))
assert(rows[2].a2:IsShown() and rows[2].a2:GetText() == "Zurückziehen" and not rows[2].a1:IsShown())
-- Anna's: online, "Annehmen" on; Cleo's: offline, grey
assert(has(rows[4].what:GetText(), "4x") and has(rows[4].line:GetText(), "Anna Amboss") and has(rows[4].line:GetText(), "Stoff hab ich"))
assert(rows[4].a2:GetText() == "Annehmen" and rows[4].a2:IsEnabled(), "Annehmen")
assert(rows[5].a2:GetText() == "Annehmen" and not rows[5].a2:IsEnabled(), "grey while Cleo is offline")
assert(has(rows[5].line:GetText(), "offline, zuletzt gehört"), rows[5].line:GetText())
-- Bob's: accepted by Anna, no button
assert(has(rows[7].line:GetText(), "angenommen von Anna Amboss") and not rows[7].a2:IsShown())
-- the heads have no button
assert(not rows[1].a2:IsShown() and not rows[3].a1:IsShown())
-- "Annehmen": the whisper to Anna, then "Angefragt" (grey)
STUB.addon = {}
rows[4].a2:Click()
STUB.tick(1.1)
local ot = 0
for _, m in ipairs(STUB.addon) do if m.text == "1OT\ta001\tT" and m.target == "Anna Amboss" then ot = ot + 1 end end
assert(ot == 1, "the OT")
assert(rows[4].a2:GetText() == "Angefragt" and not rows[4].a2:IsEnabled())
-- Anna's answer: at the own character, "Fertig" and "Abgeben"
recv("Anna Amboss", "a001", "2", "2330", "4", "H", "T", "Vulo Sturmwind", "3600", "Stoff hab ich", "118")
NS.Refresh()
assert(rows[4].item.order.id == "a001" and rows[4].a1:GetText() == "Fertig" and rows[4].a2:GetText() == "Abgeben", "Fertig, Abgeben")
-- the own order done: "Erhalten" and "Zurückziehen"; Erhalten closes it
AmisiaDB.orders.own[mine].state, AmisiaDB.orders.own[mine].by = "D", "Bob Hammer"
NS.Refresh()
assert(rows[2].a1:GetText() == "Erhalten" and rows[2].a2:GetText() == "Zurückziehen" and has(rows[2].line:GetText(), "fertig: Bob Hammer"))
rows[2].a1:Click()
assert(AmisiaDB.orders.own[mine].state == "X" and f.orList.items[2].note ~= nil, "closed, the note under Meine Aufträge")

---------------------------------------------------------------------------
-- "Auftrag stellen" in the recipe's guild box and its window
---------------------------------------------------------------------------
NS.ShowRecipe(164, 3321)
local rd = f.rd
assert(rd:IsShown() and rd.order:IsShown(), "Auftrag stellen in the guild box")
rd.order:Click()
local d = _G.AmisiaOrderDialog
assert(d and d:IsShown() and d.count.current == 1 and d.mats.current == "B" and d.note:GetText() == "", "the window")
assert(d.announce:GetChecked() == false, "the guild chat off by default")
d.count:SetValue(20)
d.mats:SetValue("A")
d.note:SetText("bis Freitag")
STUB.chat = {}
d.ok:Click()
assert(not d:IsShown(), "placed: the window closes")
local found
for _, o in ipairs(GO.Mine()) do if o.spell == 3321 and o.n == 20 then found = o end end
assert(found and found.mats == "A" and found.note == "bis Freitag", "the order with the window's values")
assert(#STUB.chat == 0, "no guild chat line")
-- the switch on: the guild chat line; a refused order says why and stays open
NS.Set("orders.announce", true)
rd.order:Click()
assert(d.announce:GetChecked() == true, "the setting is the default")
d.ok:Click()
assert(#STUB.chat == 1 and STUB.chat[1].chan == "GUILD" and has(STUB.chat[1].text, "Suche Hersteller: 1x"), "the guild chat line")
for _ = 1, 3 do GO.Create(3321, 1, "B") end
rd.order:Click()
d.ok:Click()
assert(d:IsShown() and has(d.hint:GetText(), "schon 5 offene"), d.hint:GetText())
d:Hide()

---------------------------------------------------------------------------
-- off: the tab says so, no button
---------------------------------------------------------------------------
NS.Set("orders.on", false)
NS.ShowRecipe(164, 3321)
assert(not rd.order:IsShown(), "no button while off")
NS.ShowProfessions("auftraege")
assert(#f.orList.items == 1 and has(f.orList.items[1].note, "Gildenaufträge sind aus"))
NS.Set("orders.on", true)
-- another tab leaves it
f.tabAll:Click()
assert(not f.orView:IsShown() and not f.tabOrders.on)
