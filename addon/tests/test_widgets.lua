-- Widgets build without errors and keep their state.
local W = NS.W
assert(W, "Widgets.lua loaded")
local root = CreateFrame("Frame", nil, UIParent)

local seen
local t = W.Toggle(root, function(v) seen = v end)
t:SetChecked(true); assert(t:GetChecked())
t:Click(); assert(seen == false and not t:GetChecked())

local st = W.Stepper(root, 120, function(v) seen = v end)
st:Configure(5, 120, 5)
st:SetValue(20)
st.plus:Click(); assert(seen == 25)
STUB.shift = true; st.minus:Click(); assert(seen == 5, "shift steps by ten steps, clamped"); STUB.shift = false
st.minus:Click(); assert(seen == 5, "no change below the minimum")
st.scripts.OnMouseWheel(st, 1); assert(seen == 10)

local c = W.Choice(root, 120, function(v) seen = v end)
c:SetValues({ { "a", "Eins" }, { "b", "Zwei" } })
c:SetValue("a"); assert(c.label:GetText() == "Eins")
c:Click(); assert(seen == "b" and c.label:GetText() == "Zwei")
c:Click(); assert(seen == "a", "cycles")

local committed
local tb = W.TimeBox(root, 60, function(text) committed = text end)
tb:SetText("19:30"); tb.scripts.OnEnterPressed(tb); assert(committed == "19:30")

local filled = {}
local list = W.List(root, 3, 20, function(r) r.text = W.Text(r) end, function(r, item) r.text:SetText(item); filled[#filled + 1] = item end)
list:SetItems({ "a", "b", "c", "d", "e" })
assert(list.rows[1].text:GetText() == "a" and list.rows[3].text:GetText() == "c")
list.scripts.OnMouseWheel(list, -1); assert(list.rows[1].text:GetText() == "b")
list.scripts.OnMouseWheel(list, -5); assert(list.rows[1].text:GetText() == "c", "stops at the end")
list:SetItems({ "x" }); assert(list.rows[1].text:GetText() == "x" and not list.rows[2]:IsShown())

local card = W.Card(root, 296, 112)
local clicked
card:SetAction("Los", function() clicked = true end)
card.button:Click(); assert(clicked)
card:SetAction(nil); assert(not card.button:IsShown())

local area = W.EditArea(root); area.box:SetText("abc"); assert(area.box:GetText() == "abc")
local st2 = W.ScrollText(root); st2:SetText("hallo"); assert(st2.fs:GetText() == "hallo")

local hit
W.Menu(root, { { "Eins", function() hit = 1 end }, { "Zwei", function() hit = 2 end } })
assert(AmisiaMenu:IsShown())
AmisiaMenu.buttons[2]:Click(); assert(hit == 2 and not AmisiaMenu:IsShown(), "a click runs the entry and closes")
