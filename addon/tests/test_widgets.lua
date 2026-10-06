-- Widgets build without errors and keep their state.
local W = NS.W
assert(W, "Widgets.lua loaded")
local root = CreateFrame("Frame", nil, UIParent)

local seen
local t = W.Toggle(root, function(v) seen = v end)
-- the client's check box: a CheckButton that turns itself over before OnClick
assert(t.kind == "CheckButton" and t.inherits.MinimalCheckboxTemplate, "the minimal check box")
assert(t._w == 18 and t._h == 18)
t:SetChecked(true); assert(t:GetChecked() and t.checked == true)
t:Click(); assert(seen == false and not t:GetChecked() and t.checked == false, "one click, one turn")
t:Click(); assert(seen == true and t:GetChecked() and t.checked == true)
t:SetChecked(nil); assert(t:GetChecked() == false and t.checked == false)

local st = W.Stepper(root, 120, function(v) seen = v end)
st:Configure(5, 120, 5)
st:SetValue(20)
st.plus:Click(); assert(seen == 25)
STUB.shift = true; st.minus:Click(); assert(seen == 5, "shift steps by ten steps, clamped"); STUB.shift = false
st.minus:Click(); assert(seen == 5, "no change below the minimum")
st.scripts.OnMouseWheel(st, 1); assert(seen == 10)
-- the look: arrow buttons left and right, the value in a field with the input border
assert(st.minus.arrow and st.plus.arrow, "the client's arrow buttons")
assert(st.minus.arrow:GetAtlas() == "common-dropdown-a-button-shadowless" and st.minus.arrow.rotation < 0 and st.plus.arrow.rotation > 0)
assert(st.minus._w == 20 and st.plus._w == 20)
assert(st.field.Left.atlas == "common-search-border-left" and st.field.Middle.atlas == "common-search-border-middle"
    and st.field.Right.atlas == "common-search-border-right", "the field's border")
assert(st.value:GetText() == "10")
local SL = dofile(ADDON_DIR .. "/../tests/layout.lua")(st, 120, 20)
SL.row("stepper", st.minus, st.field, st.plus)

-- a chip in the client's filter-button look: open when on, the state follows the mouse
local chip = W.Chip(root, "MS", 30)
local B = "common-dropdown-b-button"
assert(chip.bg.atlas == B .. "-open" and chip.on and chip.edges == nil, "on: open, no gold frame: " .. tostring(chip.bg.atlas))
assert(chip.label.textColor[1] == W.GOLD[1] and chip.label.textColor[2] == W.GOLD[2], "gold text when on")
chip:SetOn(false)
assert(chip.bg.atlas == B and chip.label.textColor[1] == 0.6 and chip.label.textColor[2] == 0.6, "off: normal and grey")
chip:GetScript("OnEnter")(chip); assert(chip.bg.atlas == B .. "-hover", chip.bg.atlas)
chip:GetScript("OnMouseDown")(chip); assert(chip.bg.atlas == B .. "-pressedhover", chip.bg.atlas)
chip:GetScript("OnMouseUp")(chip); chip:GetScript("OnLeave")(chip); assert(chip.bg.atlas == B, chip.bg.atlas)
chip:Disable(); assert(chip.bg.atlas == B .. "-disabled")
chip:Enable(); chip:SetOn(true); assert(chip.bg.atlas == B .. "-open")
-- the atlas on the chip itself, not outside, in three pieces without the arrow: the left end, a
-- stretch of the middle, the left end turned round on the right
local P = chip.pieces
assert(P and #P == 3 and P[1] == chip.bg, "three pieces")
assert(P[1].points.TOPLEFT.x == 0 and P[1].points.BOTTOMLEFT and P[3].points.TOPRIGHT.x == 0 and P[3].points.BOTTOMRIGHT)
assert(P[1]._w == 8 and P[3]._w == 8 and P[2].points.TOPLEFT and P[2].points.BOTTOMRIGHT)
for _, p in ipairs(P) do assert(p.atlas == B .. "-open", p.atlas) end
local c1, c2, c3 = P[1].texCoord, P[2].texCoord, P[3].texCoord
assert(c1 and c2 and c3, "each piece cut")
assert(c1[1] == 0 and math.abs(c1[2] - 8 / 143) < 1e-9, "the left end")
assert(math.abs(c3[1] - 8 / 143) < 1e-9 and c3[2] == 0, "the left end turned round")
assert(c2[2] <= 0.45 + 1e-9, "the middle clear of the arrow")
-- a choice keeps the whole atlas with its arrow (a click goes on to the next value)
local choice = W.Choice(root, 120)
assert(choice.pieces == nil and choice.bg.points.TOPLEFT and choice.bg.points.BOTTOMRIGHT)
-- the reset button: the client's red x
local rb = W.ResetButton(root, 18, function() end)
assert(rb._w == 18 and rb._h == 18 and rb.icon.atlas == "auctionhouse-ui-filter-redx")
-- a tooltip keeps the hover look
W.Tooltip(chip, "Titel")
chip:GetScript("OnEnter")(chip); assert(chip.bg.atlas == B .. "-hover", "hover with a tooltip")
chip:GetScript("OnLeave")(chip); assert(chip.bg.atlas == B .. "-open")

local c = W.Choice(root, 120, function(v) seen = v end)
c:SetValues({ { "a", "Eins" }, { "b", "Zwei" } })
c:SetValue("a"); assert(c.label:GetText() == "Eins")
c:Click(); assert(seen == "b" and c.label:GetText() == "Zwei")
c:Click(); assert(seen == "a", "cycles")

local committed
local tb = W.TimeBox(root, 60, function(text) committed = text end)
tb:SetText("19:30"); tb.scripts.OnEnterPressed(tb); assert(committed == "19:30")

-- line edit: commits once on Enter or on leaving, Escape restores what was there
local got, commits = nil, 0
local le = W.LineEdit(root, 150, function(text) got = text; commits = commits + 1 end)
assert(le:GetText() == "")
le:SetFocus(); le:SetText("Vulobank"); le.scripts.OnEnterPressed(le)
assert(got == "Vulobank" and commits == 1, "Enter commits once, the lost focus not again: " .. commits)
assert(not le:HasFocus(), "Enter leaves the box")
le:SetFocus(); le:SetText("Tipp"); le:ClearFocus()
assert(got == "Tipp" and commits == 2, "leaving commits")
le:SetFocus(); le:SetText("Quatsch"); le.scripts.OnEscapePressed(le)
assert(le:GetText() == "Tipp" and commits == 2 and not le:HasFocus(), "Escape restores without a commit")
le:SetText("Von aussen"); le:SetFocus(); le:ClearFocus()
assert(got == "Von aussen" and commits == 3)

-- picker: a list with a filter, an optional free-text entry at the end
local picked, free
local p = W.Picker(root, 150, function(v, isFree) picked, free = v, isFree end)
p:SetValues({ { value = "a", text = "Anton" }, { value = "b", text = "Berta" }, { value = "c", text = "Carla" } }, "Anderer Name")
p:SetValue("b"); assert(p.label:GetText() == "Berta" and p:GetValue() == "b")
p:Click()
assert(AmisiaPicker and AmisiaPicker:IsShown() and AmisiaPicker.owner == p, "a click opens the shared panel")
local prow = AmisiaPicker.list.rows
assert(prow[1].text:GetText() == "Anton" and prow[3].text:GetText() == "Carla" and prow[4].text:GetText() == "Anderer Name", prow[4].text:GetText())
assert(not prow[5]:IsShown())
prow[3]:Click()
assert(picked == "c" and not free and p:GetValue() == "c" and p.label:GetText() == "Carla", "a click picks and closes")
assert(not AmisiaPicker:IsShown())
p:Click(); assert(AmisiaPicker:IsShown())
p:Click(); assert(not AmisiaPicker:IsShown(), "a second click closes")
-- the filter narrows the list, the free entry stays
p:Click()
local filter = AmisiaPicker.filter
assert(filter:GetText() == "", "the filter starts empty")
filter:SetText("ER"); filter.scripts.OnTextChanged(filter, true)
assert(prow[1].text:GetText() == "Berta" and prow[2].text:GetText() == "Anderer Name" and not prow[3]:IsShown(), "case-insensitive part match")
-- Enter with one match picks it
filter.scripts.OnEnterPressed(filter)
assert(picked == "b" and not free and not AmisiaPicker:IsShown())
-- free text: the typed text is the value
p:Click(); filter:SetText("Dora"); filter.scripts.OnTextChanged(filter, true)
assert(prow[1].text:GetText() == "Anderer Name" and not prow[2]:IsShown(), "no match leaves only the free entry")
prow[1]:Click()
assert(picked == "Dora" and free == true and p:GetValue() == "Dora" and p.label:GetText() == "Dora", "the free entry takes the filter text")
-- Enter with no match and a free entry picks the text as well
p:Click(); filter:SetText("Emil"); filter.scripts.OnTextChanged(filter, true); filter.scripts.OnEnterPressed(filter)
assert(picked == "Emil" and free == true)
-- the free entry without text keeps the panel open and puts the cursor into the filter
p:Click(); assert(filter:GetText() == "" and filter:HasFocus(), "opening empties and focuses the filter")
filter:ClearFocus()
prow[4]:Click()
assert(AmisiaPicker:IsShown() and filter:HasFocus() and picked == "Emil", "nothing to pick yet")
-- Escape closes without picking
filter.scripts.OnEscapePressed(filter)
assert(not AmisiaPicker:IsShown() and picked == "Emil")
-- without a free-text label there is no such entry, and Enter without a single match does nothing
local p2 = W.Picker(root, 150, function(v) picked = v end)
p2:SetValues({ { value = 1, text = "Eins" }, { value = 2, text = "Zwei" } })
p2:SetValue(99); assert(p2.label:GetText() == "99", "an unknown value shows as text")
p2:Click(); assert(AmisiaPicker.owner == p2 and prow[2].text:GetText() == "Zwei" and not prow[3]:IsShown())
filter:SetText("zzz"); filter.scripts.OnTextChanged(filter, true)
assert(not prow[1]:IsShown())
filter.scripts.OnEnterPressed(filter)
assert(picked == "Emil" and AmisiaPicker:IsShown(), "no pick without a match")
filter:SetText(""); filter.scripts.OnTextChanged(filter, true)
prow[1]:Click(); assert(picked == 1 and p2:GetValue() == 1)
-- many values scroll
local many = {}
for i = 1, 20 do many[i] = { value = i, text = "Name " .. i } end
p2:SetValues(many); p2:Click()
assert(prow[1].text:GetText() == "Name 1" and prow[#prow].text:GetText() == "Name " .. #prow)
AmisiaPicker.list.scripts.OnMouseWheel(AmisiaPicker.list, -1)
assert(prow[1].text:GetText() == "Name 2", "the wheel scrolls the list")
prow[1]:Click(); assert(picked == 2)

-- a refresh of the owner keeps the scroll position and the filter of the open panel
local same = {}
for i = 1, 20 do same[i] = { value = i, text = "Name " .. i } end
p2:Click()
AmisiaPicker.list.scripts.OnMouseWheel(AmisiaPicker.list, -1)
AmisiaPicker.list.scripts.OnMouseWheel(AmisiaPicker.list, -1)
assert(prow[1].text:GetText() == "Name 3")
p2:SetValues(same)
assert(AmisiaPicker:IsShown() and prow[1].text:GetText() == "Name 3", "same values: the scroll stays, got " .. tostring(prow[1].text:GetText()))
filter:SetText("Name 1"); filter.scripts.OnTextChanged(filter, true)
assert(prow[1].text:GetText() == "Name 1" and prow[2].text:GetText() == "Name 10", "a new filter starts at the top")
AmisiaPicker.list.scripts.OnMouseWheel(AmisiaPicker.list, -1)
p2:SetValues(same)
assert(filter:GetText() == "Name 1" and prow[1].text:GetText() == "Name 10", "the filter and the scroll stay")
-- changed values while open: the list follows, the position is kept as far as it goes
local fewer = {}
for i = 1, 19 do fewer[i] = { value = i, text = "Name " .. i } end
p2:SetValues(fewer)
assert(prow[1].text:GetText() == "Name 10" and prow[#prow].text:GetText() == "Name 17", "the list follows, the position kept")
filter:SetText(""); filter.scripts.OnTextChanged(filter, true)
assert(prow[1].text:GetText() == "Name 1")
p2:Click()
assert(not AmisiaPicker:IsShown())

-- the panel opens above the window its widget lives in, even above a top-level dialog
local dlg = CreateFrame("Frame", "AmisiaTestDialog", UIParent)
dlg:SetFrameStrata("FULLSCREEN_DIALOG")
dlg:SetToplevel(true)
dlg:SetFrameLevel(40)
local inner = CreateFrame("Frame", nil, dlg)
local p3 = W.Picker(inner, 150, function() end)
p3:SetValues({ { value = 1, text = "Eins" } })
AmisiaPicker.raised = 0
p3:Click()
assert(AmisiaPicker:IsShown() and AmisiaPicker.owner == p3)
assert(AmisiaPicker.strata == "FULLSCREEN_DIALOG", tostring(AmisiaPicker.strata))
assert(AmisiaPicker.toplevel == true, "the panel is top-level")
assert((AmisiaPicker.raised or 0) > 0, "the panel is raised on open")
assert(AmisiaPicker:GetFrameLevel() > p3:GetFrameLevel() and AmisiaPicker:GetFrameLevel() > dlg:GetFrameLevel(),
    ("the panel's level %d is above the dialog %d and the widget %d"):format(AmisiaPicker:GetFrameLevel(), dlg:GetFrameLevel(), p3:GetFrameLevel()))
p3:Click()

local filled = {}
local list = W.List(root, 3, 20, function(r) r.text = W.Text(r) end, function(r, item) r.text:SetText(item); filled[#filled + 1] = item end)
list:SetItems({ "a", "b", "c", "d", "e" })
assert(list.rows[1].text:GetText() == "a" and list.rows[3].text:GetText() == "c")
list.scripts.OnMouseWheel(list, -1); assert(list.rows[1].text:GetText() == "b")
list.scripts.OnMouseWheel(list, -5); assert(list.rows[1].text:GetText() == "c", "stops at the end")
list:SetItems({ "x" }); assert(list.rows[1].text:GetText() == "x" and not list.rows[2]:IsShown())

-- rows: a faint change of shade, the recipe list's hover
assert(list.rows[1].bg.color[4] == 0.025 and list.rows[2].bg.color[4] == 0.045, "a faint change of shade")
assert(list.rows[1].hover.atlas == "Professions_Recipe_Hover" and list.rows[1].hover.alpha == 0.5)

local card = W.Card(root, 296, 112)
local clicked
card:SetAction("Los", function() clicked = true end)
card.button:Click(); assert(clicked)
card:SetAction(nil); assert(not card.button:IsShown())
assert(card.border.atlas == "common-insideframe" and card.edges == nil, "the card is an inset")
assert(card.button.inherits.SharedButtonSmallTemplate, "a red button")

local area = W.EditArea(root); area.box:SetText("abc"); assert(area.box:GetText() == "abc")
assert(area.border.atlas == "common-insideframe" and area.ground.color[4] == 0.35, "an inset with a dark ground")
assert(area.scroll.inherits == nil, "a plain scroll frame, no UIPanelScrollFrameTemplate")
assert(area.scroll.points.BOTTOMRIGHT.x == -16 and area.scroll.points.TOPLEFT.x == 6, "room for the bar")
assert(area.bar and area.bar.inherits.MinimalScrollBar and area.scroll.bar == area.bar, "the minimal bar")
local pair = STUB.scrollPairs[#STUB.scrollPairs]
assert(pair[1] == area.scroll and pair[2] == area.bar)
local AL = dofile(ADDON_DIR .. "/../tests/layout.lua")(area, 300, 120)
AL.row("edit area", area.scroll, area.bar)
AL.inside("bar", area.bar)
area.box:SetFocus(); area.box.scripts.OnEscapePressed(area.box); assert(not area.box:HasFocus(), "Escape leaves the box")
area.scripts.OnMouseDown(area); assert(area.box:HasFocus(), "a click on the field focuses the box")
area.box:ClearFocus()
local st2 = W.ScrollText(root); st2:SetText("hallo"); assert(st2.fs:GetText() == "hallo")
assert(st2.inherits == nil and st2.bar and st2.bar.inherits.MinimalScrollBar, "a plain scroll frame with the minimal bar")

local hit
W.Menu(root, { { "Eins", function() hit = 1 end }, { "Zwei", function() hit = 2 end } })
assert(AmisiaMenu:IsShown())
assert(AmisiaMenu.bg.atlas == "common-dropdown-bg" and AmisiaMenu.bg.alpha == 0.925 and AmisiaMenu.edges == nil, "the client's menu ground")
assert(AmisiaMenu.bg.points.TOPLEFT.x == -10 and AmisiaMenu.bg.points.TOPLEFT.y == 3)
assert(AmisiaMenu.buttons[1].hl.texture == "Interface\\QuestFrame\\UI-QuestTitleHighlight", "the menu's hover")
AmisiaMenu.buttons[2]:Click(); assert(hit == 2 and not AmisiaMenu:IsShown(), "a click runs the entry and closes")
