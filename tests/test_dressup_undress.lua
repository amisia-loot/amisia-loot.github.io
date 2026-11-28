-- F-245: "Ausziehen" in the client's dressing room: a button above "Zurücksetzen" that undresses the player actor
-- of the ModelScene (Forever's mainline frame), else an older client's DressUpModel; made once; nothing without the
-- frame.
local K = NS.ItemKit
assert(K.DressUpButton() == nil, "no dressing room: no button")
assert(K.UndressModel() == false)

local f = CreateFrame("Frame", "DressUpFrame", UIParent)
f.ResetButton = CreateFrame("Button", "DressUpFrameResetButton", f, "UIPanelButtonTemplate")
f.ResetButton:SetSize(80, 22)
local undressed = 0
local actor = { Undress = function() undressed = undressed + 1 end }
f.ModelScene = CreateFrame("Frame", nil, f)
f.ModelScene.GetPlayerActor = function() return actor end

STUB.fire("PLAYER_LOGIN")
local b = K.undressButton
assert(b and b:GetParent() == f and b:GetText() == "Ausziehen", "the button on the dressing room")
local p, rel, rp = b:GetPoint(1)
assert(p == "BOTTOM" and rel == f.ResetButton and rp == "TOP", "above Zurücksetzen")
b:Click()
assert(undressed == 1, "the actor undressed")
assert(K.DressUpButton() == b, "made once")

-- a pet or mount in the scene: no player actor, an older client's model instead
actor = nil
local old = 0
_G.DressUpModel = { Undress = function() old = old + 1 end }
b:Click()
assert(old == 1, "the older model")
_G.DressUpModel = nil
assert(K.UndressModel() == false)
print("dressup undress ok")
