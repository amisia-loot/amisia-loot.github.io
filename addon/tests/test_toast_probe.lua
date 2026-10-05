-- The Bis toast probes its template: a TooltipBackdropTemplate without a NineSlice (a client whose
-- template changed) falls back to the flat ground, and leaves no half-built frame under the name.
STUB.class, STUB.level = "WARRIOR", 60
local base = STUB.templates.TooltipBackdropTemplate
STUB.templates.TooltipBackdropTemplate = function() end
NS.BisToast(32235, "wish", STUB.item(32235, "Krone", 4), "Test")
local toast = AmisiaBisToast
assert(toast and toast:IsShown() and toast.NineSlice == nil and toast.inherits == nil,
    "a flat toast of its own, not the template's frame without a NineSlice")
assert(toast._w == 320 and toast._h == 58 and toast.title and toast.source:GetText() == "Test")
STUB.templates.TooltipBackdropTemplate = base
