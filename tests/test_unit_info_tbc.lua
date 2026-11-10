--[[game tbc]]
-- The player tooltip's gear line on TBC Anniversary (F-169, D-99): UI/UnitInfo.lua and Core/Inspect.lua
-- load without the Forever parts; the own character's line comes, no profession icons (nothing known
-- there), the setting "Berufe im Spieler-Tooltip" hidden.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
assert(NS.GAME == "tbc" and NS.Prof == nil and NS.UnitInfo and NS.Inspect, "the modules without the Forever parts")
_G.UnitIsPlayer = function(u) return u == "player" end
STUB.items[201] = { name = "Helm", link = "|cffa335ee|Hitem:201::::::::|h[Helm]|h|r", quality = 4, ilvl = 115, equipLoc = "INVTYPE_HEAD" }
STUB.worn = { [1] = "|cffa335ee|Hitem:201::::::::|h[Helm]|h|r" }
_G.GetAverageItemLevel = nil
local tip = GameTooltip
local lines = {}
tip.AddLine = function(_, text) lines[#lines + 1] = text end
tip.GetUnit = function() return "Vuloo", "player" end
for _, e in ipairs(STUB.tdp) do if e.kind == Enum.TooltipDataType.Unit then e.fn(tip) end end
local t = table.concat(lines, "\n")
-- 115 * 1 (head), item level 115 / 17 = 6
assert(#lines == 1 and has(t, "|cffa335ee115|r") and has(t, "|cffffffff6|r"), t)
assert(not NS.Visible(NS.SettingItem("ui.unitProfs")) and NS.Visible(NS.SettingItem("ui.unitGear")), "the profession setting only on Forever")
print("unit info tbc ok")
