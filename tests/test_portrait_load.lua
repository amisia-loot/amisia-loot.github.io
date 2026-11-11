-- The round creature portrait (W.Portrait / W.SetPortrait, pages Dungeons and Raids, window Lauf-Zeiten):
-- the model frame is shown BEFORE it is given its creature (a hidden model frame loses it on the client:
-- the portraits stayed black, 2026-11-11), the creature is given again when the portrait comes back on
-- screen, and the portrait camera is set again once the model's data has arrived.
local W, T = NS.W, NS.Theme
local parent = CreateFrame("Frame", nil, UIParent)
local p = W.Portrait(parent, 36)
local m = p.model
assert(m and not m:IsShown() and p.skull:IsShown() or p.skull, "a model frame, hidden at first")

local calls = {}
m.SetCreature = function(self, id)
    calls[#calls + 1] = { id = id, shown = self:IsShown() }
    self.creature = id
end
m.SetPortraitZoom = function(self, z) self.zoom = z end

W.SetPortrait(p, 10184)
assert(#calls >= 1 and calls[1].id == 10184, "the creature is given")
for i, c in ipairs(calls) do assert(c.shown, "call " .. i .. ": the model frame is shown before SetCreature") end
assert(m:IsShown() and not p.skull:IsShown() and m.zoom == T.DBOSS.ZOOM and p.npc == 10184)

-- the same NPC again: nothing is loaded twice
local n = #calls
W.SetPortrait(p, 10184)
assert(#calls == n, "no second load for the same NPC")

-- the portrait comes back on screen: the creature and the camera are given again
m.creature, m.zoom = nil, nil
local onShow = m:GetScript("OnShow")
assert(type(onShow) == "function", "the model reloads on show")
onShow(m)
assert(m.creature == 10184 and m.zoom == T.DBOSS.ZOOM, "given again after the frame was hidden")

-- the model's data arrives late: the camera is set again
m.zoom = nil
local loaded = m:GetScript("OnModelLoaded")
assert(type(loaded) == "function")
loaded(m)
assert(m.zoom == T.DBOSS.ZOOM, "the portrait camera after the load")

-- no NPC: the skull, and showing the frame loads nothing
W.SetPortrait(p, nil)
assert(not m:IsShown() and p.skull:IsShown() and p.npc == nil)
n = #calls
onShow(m)
assert(#calls == n, "nothing to load without an NPC")

-- a client that refuses the creature: the skull stays
m.SetCreature = function() error("no such creature") end
W.SetPortrait(p, 4711)
assert(p.npc == nil and p.skull:IsShown() and not m:IsShown(), "refused: the skull")
print("portrait: shown before the creature, reload on show, camera after the load, skull without a model")
