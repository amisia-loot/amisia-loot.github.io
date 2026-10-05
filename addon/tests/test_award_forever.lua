-- The award dialog and the awards page on a client without the GetItemInfo and GetItemInfoInstant
-- globals and without the deprecated ChatEdit_InsertLink alias (the Forever client): item data
-- comes from C_Item, links go to the chat through ChatFrameUtil.InsertLink.
assert(GetItemInfo == nil and GetItemInfoInstant == nil and ChatEdit_InsertLink == nil, "the Forever client has none of the globals")

STUB.roster = { { name = "Vuloo Stein", class = "PRIEST" }, { name = "Fraktur Berg", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.items[32235].icon = 4242

---------------------------------------------------------------------------
-- the page: an item of unknown quality, the tooltip and the shift-click into the chat
---------------------------------------------------------------------------
NS.AddAwardTo(s, { name = "Fraktur Berg", item = 99999, kind = "MS", src = "X" })
NS.AddAwardTo(s, { name = "Fraktur Berg", item = 32235, kind = "MS", src = "X" })
NS.ShowPage("awards")
local O = NS.AwardsPageFrame().officer
local rows = O.list.rows
assert(rows[1]:IsShown() and rows[2]:IsShown(), "both awards listed")
assert(rows[2].itemText:GetText():find("a335ee", 1, true), "the quality comes from C_Item: " .. rows[2].itemText:GetText())
rows[2].scripts.OnEnter(rows[2])
rows[2].scripts.OnLeave(rows[2])
STUB.inserted = nil
STUB.shift = true
rows[2]:Click()
STUB.shift = false
assert(STUB.inserted == link, "the link went to the chat through ChatFrameUtil: " .. tostring(STUB.inserted))

---------------------------------------------------------------------------
-- the dialog: a typed item id, its icon, and a link shift-clicked from the bags
---------------------------------------------------------------------------
NS.ShowAwardDialog(nil, s)
local D = AmisiaAwardDialog
D.itemEdit:SetFocus(); D.itemEdit:SetText("32235"); D.itemEdit.scripts.OnEnterPressed(D.itemEdit)
assert(D.itemText:IsShown() and D.itemText:GetText() == link, "the typed id becomes the item link: " .. tostring(D.itemText:GetText()))
assert(D.icon.texture == 4242, "the item's icon: " .. tostring(D.icon.texture))
D.cancel:Click()

NS.ShowAwardDialog(nil, s)
assert(D.itemEdit:IsShown())
STUB.shift = true
HandleModifiedItemClick(link)
STUB.shift = false
assert(D.itemText:IsShown() and D.itemText:GetText() == link, "a shift-click in the bags fills the item through ChatFrameUtil.InsertLink")
D.cancel:Click()

---------------------------------------------------------------------------
-- the raider view: shift-click puts the link into the chat
---------------------------------------------------------------------------
s.items[#s.items + 1] = { name = "Vuloo Stein", item = 32235, count = 1, t = STUB.now }
STUB.player = "Vuloo"
_G.UnitName = function(u) if u == "player" then return "Vuloo", "Stein" end return nil end
NS.Set("ui.view", "raider")
NS.ShowPage("overview")
NS.ShowPage("awards")
local R = NS.AwardsPageFrame().raider
assert(R:IsShown() and R.list.rows[1]:IsShown(), "own item listed")
STUB.inserted = nil
STUB.shift = true
R.list.rows[1]:Click()
STUB.shift = false
assert(STUB.inserted == link, "raider shift-click: " .. tostring(STUB.inserted))
R.list.rows[1].scripts.OnEnter(R.list.rows[1])
NS.Reset("ui.view")
