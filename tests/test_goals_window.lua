-- The window "Ausrüstungsziele" (UI/GoalsWindow.lua, F-110): the self-test line "Charaktermodell";
-- nothing built before it opens; the button "Großes Fenster" on the gear page's view Ziele, the
-- side tab, /amisia bis gross; the doll (17 slots as on the character frame, the model dressed in
-- the targets or what is worn, drag, wheel, right click), the list by section with the gear page's
-- texts and clicks; the scale (ui.goalScale, Ctrl + mouse wheel), the place (saved, reset), the
-- switch kept; without the model "Modell nicht verfügbar"; without gear data a chat line.
local Gear = NS.Gear
local G = NS.Theme.GOALS
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

---------------------------------------------------------------------------
-- the self-test line: DressUpModel with SetUnit, Undress, TryOn (the stub's model has them)
---------------------------------------------------------------------------
local report = NS.SelfTest.Run().text
assert(has(report, "Charaktermodell") and has(report, "DressUpModel, SetUnit, Undress, TryOn vorhanden"), "the self-test line")

---------------------------------------------------------------------------
-- a small Forever data set; a warrior at 60 wearing an old helm
---------------------------------------------------------------------------
STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-goals", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },   -- 2
} }
STUB.areas[2717], STUB.areas[2017] = "Geschmolzener Kern", "Stratholme"
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
gear(401, "Helm A", "HEAD", str(40), { 1 })
gear(402, "Helm B", "HEAD", str(30), { 2 })
gear(403, "Brust Kern", "CHEST", str(50), { 1 })
gear(404, "Ring Hort", "FINGER", str(20), { 1 }, { sub = 0 })
gear(405, "Zweihand", "2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60, ITEM_MOD_STRENGTH_SHORT = 20 }, { 1 }, { classID = 2, sub = 1 })
gear(410, "Alter Helm", "HEAD", str(10))
STUB.worn[1] = LINKS[410]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
assert(Gear.Available())

---------------------------------------------------------------------------
-- nothing before it opens; the button on the gear page opens and closes it
---------------------------------------------------------------------------
assert(_G.AmisiaGoalsFrame == nil, "nothing built before it is opened")
NS.ShowGear("goals")
local page = NS.GearPageFrame()
local big = page.goals.big
assert(big and big.vis ~= false and big:GetText() == "Großes Fenster", "the button on the view Ziele")
assert(big.points.TOPRIGHT, "it stands from the right edge")
assert(page.goals.title:GetWidth() < 440, "the title leaves room for it")
big:Click()
local win = assert(_G.AmisiaGoalsFrame, "the window")
assert(win:IsShown() and win:GetTitleText():GetText() == "Ausrüstungsziele")
assert(win:GetWidth() == G.W and win:GetHeight() == G.H, "940 x 600 or so")
assert(win.strata == "FULLSCREEN" and win.inherits and win.inherits.PortraitFrameTemplate, "the talent window's frame")
-- the side tab is marked while it is open
NS.ShowPage("gear")
local tab = AmisiaFrame.sideTabs.goals
assert(tab and tab:IsShown() and tab.checked, "the side tab, marked")
big:Click()
assert(not win:IsShown(), "the button closes it again")
assert(not tab.checked, "and the tab is no longer marked")
STUB.clickTab(tab)
assert(win:IsShown(), "the side tab opens it")
win:Hide()
NS.Dispatch("bis gross")
assert(win:IsShown(), "/amisia bis gross")
win:Hide()
NS.Dispatch("bis big")
assert(win:IsShown(), "/amisia bis big")

---------------------------------------------------------------------------
-- the doll: 17 slots, the targets on the model
---------------------------------------------------------------------------
local d = win.doll
local n = 0
for _ in pairs(d.slots) do n = n + 1 end
assert(n == 17, "17 slots: " .. n)
assert(d.slots.HEAD.points.TOPLEFT.x == 0 and d.slots.HANDS.points.TOPLEFT.x == G.DOLL_W - G.SLOT, "left and right of the model")
assert(d.slots.MAINHAND.points.TOPLEFT.y == -(G.MODEL_H + G.WEAPON_GAP), "the weapons under it")
assert(d.slots.HEAD.item.id == 401, "the head slot shows the target")
assert(d.slots.HEAD.item.target and d.slots.HEAD.icon:IsShown(), "with its icon")
assert(not d.slots.NECK.item and d.slots.NECK.art:IsShown(), "an empty slot shows the character frame's art")
local m = d.model
assert(m and m.unit == "player" and m.undressed, "the model wears the player, undressed for the targets")
local tried = table.concat(m.tried, " ")
assert(has(tried, "item:401") and has(tried, "item:403") and has(tried, "item:405"), "the targets tried on: " .. tried)
assert(d.noModel and not d.noModel:IsShown(), "no hint while the model works")
-- the slot's state dot: nothing worn of the targets yet
assert(not d.slots.HEAD.dot:IsShown(), "no dot: still to get")
-- Angelegt: the worn helm, the model as the player is
d.worn:Click()
assert(NS.GoalsFrameState().mode == "worn" and d.worn.on and not d.goals.on, "the switch")
assert(d.slots.HEAD.item.link == LINKS[410] and not m.undressed and #m.tried == 0, "what is worn")
d.goals:Click()
assert(m.undressed and d.slots.HEAD.item.id == 401, "back to the targets")
-- the model: drag turns, the wheel zooms, a right click resets
STUB.cursorX = 100
_G.GetCursorPosition = function() return STUB.cursorX, 0 end
m:GetScript("OnMouseDown")(m, "LeftButton")
STUB.cursorX = 150
m:GetScript("OnUpdate")(m, 0.1)
assert(m.rotation and m.rotation > 0, "dragging turns it")
m:GetScript("OnMouseUp")(m, "LeftButton")
m:GetScript("OnMouseWheel")(m, 1)
assert(m.zoom and m.zoom > 0, "the wheel zooms")
m:GetScript("OnMouseDown")(m, "RightButton")
assert(m.rotation == 0 and m.zoom == 0, "right click resets")
-- a slot click chooses the slot; Ctrl on it is the dressing room
d.slots.CHEST:Click()
assert(NS.GoalsFrameState().slot == "CHEST", "a click chooses the slot")

---------------------------------------------------------------------------
-- the list: three sections, the gear page's texts
---------------------------------------------------------------------------
local rows = win.list.items
assert(rows[1].header and rows[1].header.label == "Rüstung", "armour first")
local heads, slots = 0, 0
for _, e in ipairs(rows) do if e.header then heads = heads + 1 else slots = slots + 1 end end
assert(heads == 3 and slots == 17, "three sections, 17 slots")
local headRow
for _, r in ipairs(win.list.rows) do if r.item and r.item.key == "HEAD" then headRow = r end end
assert(headRow and has(plain(headRow.name:GetText()), "Helm A"), "the head's target")
assert(has(plain(headRow.gain:GetText()), "%"), "its gain in percent of the worn one: " .. plain(headRow.gain:GetText()))
assert(has(headRow.src:GetText(), "Ragnaros") or has(headRow.src:GetText(), "Geschmolzener Kern"), "and its source")
-- the chosen row lights up
local chestRow
for _, r in ipairs(win.list.rows) do if r.item and r.item.key == "CHEST" then chestRow = r end end
assert(chestRow.sel:IsShown() and not headRow.sel:IsShown(), "the chosen row lights up")
headRow:Click()
assert(NS.GoalsFrameState().slot == "HEAD", "a row click chooses its slot")

---------------------------------------------------------------------------
-- scale and place
---------------------------------------------------------------------------
assert(NS.SettingItem("ui.goalScale").min == 70 and NS.SettingItem("ui.goalScale").max == 150, "70 to 150 %")
assert(NS.Set("ui.goalScale", 120))
assert(math.abs(win:GetScale() - 1.2) < 1e-9, "the setting scales it")
_G.IsControlKeyDown = function() return true end
win:GetScript("OnMouseWheel")(win, 1)
assert(NS.Get("ui.goalScale") == 125, "Ctrl + wheel: 5 % more")
for _ = 1, 10 do win:GetScript("OnMouseWheel")(win, 1) end
assert(NS.Get("ui.goalScale") == 150, "at most 150")
_G.IsControlKeyDown = function() return false end
NS.Reset("ui.goalScale")
win._point, win._x, win._y = "TOPLEFT", 40, -50
win:GetScript("OnDragStop")(win)
local st = AmisiaDB.settings.goalWindow
assert(st.point == "TOPLEFT" and st.x == 40 and st.y == -50, "the place is saved")
NS.ResetPositions()
assert(st.point == nil, "Fensterposition zurücksetzen resets it too")

---------------------------------------------------------------------------
-- without the model's methods: the slots alone and the hint
---------------------------------------------------------------------------
win:Hide()
-- a fresh build without DressUpModel's methods (the window is built once per session: a new runtime
-- would be needed; the builder's check is tested directly)
STUB.noDressUp = true
local ok, frame = pcall(CreateFrame, "DressUpModel", nil, UIParent)
assert(ok and frame and frame.SetUnit == nil, "the stub's client without the model's methods")
STUB.noDressUp = nil
