-- The enchantment line of a worn item (Bis.lua enchantOf): the client's ENCHANTED_TOOLTIP_LINE is
-- made a pattern with its magic characters escaped, so a template with "(", ")" or "-" matches its
-- own line and nothing else.
local enchantOf = NS._bis.enchantOf
local realLine, realTip = _G.ENCHANTED_TOOLTIP_LINE, _G.C_TooltipInfo
local lines = {}
_G.C_TooltipInfo = { GetHyperlink = function() return { lines = lines } end }

_G.ENCHANTED_TOOLTIP_LINE = "Verzaubert (Rang): %s"
lines = { { leftText = "Kettenhelm" }, { leftText = "Verzaubert (Rang): Rüstung +10" } }
assert(enchantOf("item:100:15") == "Rüstung +10", "the line with brackets matches: " .. tostring(enchantOf("item:100:15")))
-- a line the template does not make: no enchantment (unescaped, "(Rang)" was a capture of "Rang")
lines = { { leftText = "Verzaubert Rang: Feuer" } }
assert(enchantOf("item:101:15") == nil, "no false match: " .. tostring(enchantOf("item:101:15")))
-- the plain German template still matches
_G.ENCHANTED_TOOLTIP_LINE = "Verzaubert: %s"
lines = { { leftText = "Verzaubert: Beweglichkeit +3" } }
assert(enchantOf("item:102:15") == "Beweglichkeit +3")
-- a template with a hyphen
_G.ENCHANTED_TOOLTIP_LINE = "Ver-zaubert: %s"
lines = { { leftText = "Ver-zaubert: Stärke +5" } }
assert(enchantOf("item:103:15") == "Stärke +5", tostring(enchantOf("item:103:15")))
_G.ENCHANTED_TOOLTIP_LINE, _G.C_TooltipInfo = realLine, realTip
