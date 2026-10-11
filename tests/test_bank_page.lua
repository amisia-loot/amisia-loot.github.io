-- The guild bank page: the view chips (Bestand, Bedarf, Protokoll, Text), the needs with their
-- colours and the officers' editor, pledging from the page, the log with its filters, the copy
-- text, the raider view, the layout on the 602 x 478 page and /amisia bank.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.guild = { { name = "Vuloo", rank = 2 }, { name = "Fraktur", rank = 4 } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.item(61001, "Feuerkern", 3); STUB.item(61002, "Runenstoff", 1); STUB.item(61003, "Arkanitbarren", 2)
AmisiaDB.mats[61001] = { name = "Feuerkern", q = 3, first = 1 }
AmisiaDB.mats[61002] = { name = "Runenstoff", q = 1, first = 2 }
AmisiaDB.mats[61003] = { name = "Arkanitbarren", q = 2, first = 3 }
NS.RebuildMats()
AmisiaDB.bank = { at = STUB.now - 600, counts = { [61001] = 12, [61002] = 80, [61003] = 30 }, tabs = 2, filled = 2, total = 2, by = "Vuloo" }
assert(NS.SetBankNeed(61001, 40, 80) and NS.SetBankNeed(61002, 50, 100) and NS.SetBankNeed(61003, 10))
STUB.tick(3)

local panel = assert(NS.Panel("bank"))
assert(not panel.officer, "the page is for everyone (needs and pledges)")

---------------------------------------------------------------------------
-- officer: Bestand first, the chips switch
---------------------------------------------------------------------------
NS.ShowPage("bank")
local f = NS.BankPageFrame()
assert(f.list:IsShown() and f.add.box:IsShown() and not f.need:IsShown(), "officers start on the stock")
assert(f.views.bestand.on and not f.views.bedarf.on)
assert(f.views.bedarf.label:GetText() == "Bedarf (1)", "one material below its minimum: " .. f.views.bedarf.label:GetText())
f.views.bedarf:Click()
assert(f.need:IsShown() and not f.list:IsShown() and f.views.bedarf.on, "Bedarf")
local N = f.need
assert(#N.list.items == 3, #N.list.items)
local r1 = N.list.rows[1]
assert(r1.name:GetText() == "Feuerkern" and has(r1.cells.short:GetText(), "28") and has(r1.cells.short:GetText(), NS.Theme.RED),
    "below the minimum in red: " .. r1.cells.short:GetText())
assert(has(N.list.rows[2].cells.short:GetText(), "20") and has(N.list.rows[2].cells.short:GetText(), NS.Theme.ORANGE), "below the target in orange")
assert(has(N.list.rows[3].cells.short:GetText(), "ok") and has(N.list.rows[3].cells.short:GetText(), NS.Theme.GREEN), "enough in green")
assert(r1.remove:IsShown() and N.set:IsShown() and N.pick:IsShown(), "the officer's editor and remove buttons")
assert(has(N.state:GetText(), "3 Materialien mit Bedarf, 2 unter dem Soll"), N.state:GetText())

-- a click on a row fills the editor and the pledge
r1:Click()
assert(N.pick:GetValue() == 61001 and N.min.current == 40 and N.target.current == 80, "the editor shows the need")
assert(N.pPick:GetValue() == 61001 and N.pCount.current == 28, "the pledge proposes the shortfall")
-- the editor sets a need
N.min:SetValue(60)
N.set:Click()
assert(NS.BankNeeds().list[61001].min == 60, "set from the page")
-- pledge from the page
N.pCount:SetValue(25)
N.pledge:Click()
local p = NS.BankPledgeList()
assert(#p == 1 and p[1].count == 25 and p[1].item == 61001, "pledged from the page")
assert(#N.pledges.items == 1 and N.pledges.rows[1].count:GetText() == "25", "the pledge is listed")
assert(has(N.pledgeHead:GetText(), "Zusagen (1)"), N.pledgeHead:GetText())
assert(r1.cells.pledged:GetText() == "25")
N.withdraw:Click()
assert(#NS.BankPledgeList() == 0, "withdrawn from the page")
-- the remove button takes the need out
N.list.rows[3].remove:Click()
assert(NS.BankNeeds().list[61003] == nil and #N.list.items == 2, "removed from the page")

-- layout: rows left to right, the lists inside the page
do
    local root = f:GetParent()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("bank chips", f.views.bestand, f.views.bedarf, f.views.log, f.views.text)
    L.row("needs editor", N.pick, N.minLabel, N.min, N.targetLabel, N.target, N.set)
    L.row("pledge row", N.pPick, N.pCount, N.pledge, N.withdraw)
    L.column("needs page", f.views.bestand, N.state, N.pick, N.pPick, N.heads.name, N.list, N.pledgeHead, N.pledges)
    L.inside("needs list", N.list)
    L.inside("pledge list", N.pledges)
    L.inside("pledge list bar", N.pledges.bar)
    L.row("needs row", N.list.rows[1].name, N.list.rows[1].cells.have, N.list.rows[1].cells.min, N.list.rows[1].cells.target,
        N.list.rows[1].cells.short, N.list.rows[1].cells.pledged, N.list.rows[1].remove)
    L.row("needs heads", N.heads.name, N.heads.have, N.heads.min, N.heads.target, N.heads.short, N.heads.pledged)
    assert(root)
end

---------------------------------------------------------------------------
-- the log view: filters by tab, kind and search
---------------------------------------------------------------------------
AmisiaDB.bankLog.tabs = { [1] = "Mats", [2] = "Rüstung" }
NS.MergeBankLog({
    { k = 1, y = "deposit", n = "Fraktur", i = 61001, c = 20, ago = 1 },
    { k = 1, y = "withdraw", n = "Vuloo", i = 61002, c = 5, ago = 2 },
    { k = 2, y = "deposit", n = "Anna Bergmann", i = 61002, c = 40, ago = 3 },
    { k = 0, y = "repair", n = "Chorf", i = 0, c = 50000, ago = 4 },
}, STUB.now)
AmisiaDB.bankLog.at = STUB.now
f.views.log:Click()
local G = f.log
assert(G:IsShown() and not N:IsShown(), "Protokoll")
assert(#G.list.items == 4 and has(G.list.rows[1].text:GetText(), "Fraktur legt ein: Feuerkern x20"), G.list.rows[1].text:GetText())
assert(G.list.rows[1].tab:GetText() == "Mats" and G.list.rows[4].tab:GetText() == "Gold")
assert(has(G.list.rows[2].text:GetText(), NS.Theme.ORANGE), "a withdrawal stands out")
assert(has(G.state:GetText(), "4 von 4"), G.state:GetText())
G.tab:Click()   -- all -> Mats
assert(#G.list.items == 2, "tab Mats: " .. #G.list.items)
G.tab:Click(); G.tab:Click()   -- -> Rüstung -> Gold
assert(#G.list.items == 1 and G.list.items[1].y == "repair", "the money log")
G.tab:Click()   -- back to all
assert(#G.list.items == 4)
G.kind:Click()  -- deposits
assert(#G.list.items == 2, "deposits")
G.kind:Click()  -- withdrawals
assert(#G.list.items == 1 and G.list.items[1].n == "Vuloo", "withdrawals")
G.kind:Click(); G.kind:Click()   -- moves, money
assert(#G.list.items == 1 and G.list.items[1].k == 0, "money")
G.kind:Click()  -- back to all
assert(#G.list.items == 4)
G.search:SetText("anna"); G.search:GetScript("OnEnterPressed")(G.search)
assert(#G.list.items == 1 and G.list.items[1].n == "Anna Bergmann", "search by name: " .. #G.list.items)
G.search:SetText(""); G.search:GetScript("OnEnterPressed")(G.search)
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("log filters", G.tab, G.kind, G.search, G.state)
    L.column("log page", f.views.log, G.tab, G.list)
    L.inside("log list", G.list)
    L.row("log row", G.list.rows[1].when, G.list.rows[1].text, G.list.rows[1].tab)
end

---------------------------------------------------------------------------
-- the copy text
---------------------------------------------------------------------------
f.views.text:Click()
assert(f.text:IsShown() and f.text.area.box:GetText() == NS.BankNeedText(), "the text to copy")
assert(has(f.text.area.box:GetText(), "Feuerkern: 12 von 60"), f.text.area.box:GetText())

---------------------------------------------------------------------------
-- raider: Bedarf first, no editor, no remove buttons; stock without the editor
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
SlashCmdList.AMISIA("bank")
f = NS.BankPageFrame()
assert(NS.CurrentPage() == "bank", "raiders open the page")
-- the chosen view stays (text); the slash word picks one
SlashCmdList.AMISIA("bank bedarf")
assert(f.need:IsShown(), "/amisia bank bedarf")
assert(not f.need.set:IsShown() and not f.need.pick:IsShown() and not f.need.list.rows[1].remove:IsShown(), "no editor for raiders")
assert(f.need.pledge.vis ~= false and f.need.pledge:IsEnabled(), "raiders pledge (never hidden)")
SlashCmdList.AMISIA("bank bestand")
assert(f.list:IsShown() and not f.add.box:IsShown() and not f.list.rows[1].remove:IsShown(), "the stock without the editor")
SlashCmdList.AMISIA("bank protokoll")
assert(f.log:IsShown(), "/amisia bank protokoll")
NS.Reset("ui.view")

-- no needs at all: the empty state, the pledge row disabled
for id in pairs(NS.BankNeeds().list) do NS.SetBankNeed(id, 0, 0) end
NS.ShowBank("bedarf")
assert(f.need.empty:IsShown() and not f.need.pledge:IsEnabled(), "nothing to pledge for")
