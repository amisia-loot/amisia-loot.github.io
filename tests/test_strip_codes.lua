-- ns.StripCodes (Registry.lua): colours (|cffxxxxxx and the named |cnNAME: form of Forever item links),
-- |r, link codes (the name stays), textures and atlases leave a pasted text; a "|" left over becomes the given text. The
-- loot rules (ns.LootRuleItems) and a Gargul start line (ns.ParseForeignRollStart) read a link with
-- the named colour like one with the hex colour.
local HEX = "|cffa335ee|Hitem:32235::::::::70:::::|h[Cursed Vision of Sargeras]|h|r"
local NAMED = "|cnIQ4:|Hitem:32235::::::::70:::::|h[Cursed Vision of Sargeras]|h|r"

assert(NS.StripCodes("a " .. HEX .. " b") == "a [Cursed Vision of Sargeras] b", "hex colour and link codes go")
assert(NS.StripCodes("a " .. NAMED .. " b") == "a [Cursed Vision of Sargeras] b", "named colour and link codes go")
assert(NS.StripCodes("|cnNORMAL_FONT_COLOR:Tank|r") == "Tank", "named colour of a text")
assert(NS.StripCodes("x|TInterface\\Icons\\foo:0|ty|Afoo|az") == "xyz", "textures and atlases go")
assert(NS.StripCodes("a|b") == "ab" and NS.StripCodes("a|b", " ") == "a b", "a bar left over")
assert(select("#", NS.StripCodes("x")) == 1, "one value")

local ids = NS.LootRuleItems("Ring " .. NAMED .. " und 30000")
assert(#ids == 2 and tonumber(ids[1]) == 32235 and tonumber(ids[2]) == 30000, "named colour link in a loot rule")
ids = NS.LootRuleItems(HEX)
assert(#ids == 1 and tonumber(ids[1]) == 32235, "hex colour link in a loot rule")

local p = NS.ParseForeignRollStart("You have 20 seconds to roll on " .. NAMED)
assert(p and p.item == 32235 and p.link == NAMED and p.secs == 20, "named colour link in a Gargul line")
p = NS.ParseForeignRollStart("You have 20 seconds to roll on " .. HEX)
assert(p and p.item == 32235 and p.link == HEX, "hex colour link in a Gargul line")
