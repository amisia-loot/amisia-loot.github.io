--[[preload
C_TradeSkillUI, GetProfessions, GetProfessionInfo, C_CurrencyInfo, C_Spell, GetSpellInfo = nil, nil, nil, nil, nil, nil
]]
-- The professions page on a client without the profession functions (no C_TradeSkillUI, no
-- spell book professions, no currency or spell name functions): the page opens with numbered
-- recipe names, no rank, nothing known, the camp and favor views work, and the profession
-- window's events change nothing.
local Pr = NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
C_Spell = nil
assert(C_TradeSkillUI == nil and GetProfessions == nil)

STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
STUB.fire("NEW_RECIPE_LEARNED", 3321)
assert(AmisiaDB.prof == nil and Pr.Known(3321, 164) == nil, "nothing read, nothing stored")
assert(#Pr.Own() == 0 and Pr.Rank(164) == nil and Pr.Reagents(3321) == nil)

NS.ShowProfessions()
local f = NS.PageFrame("professions")
-- the overview (D-78): no own profession, every profession of the data with its recipe count
local ov = f.ovView
assert(ov:IsShown() and #ov.secs[1].cards == 0 and ov.none:IsShown() and #ov.secs[2].cards == 3, "the overview")
assert(ov.secs[2].cards[1].name == "Alchimie" and ov.secs[2].cards[1].sub == "2 Rezepte", ov.secs[2].cards[1].sub)
assert(ov.secs[3].cards[2].sub == "Rezepte für Gunst und wie du sie bekommst", "no currency: no amount")
NS.ShowProfessions("schmied")
assert(#f.list.items == 5 and has(f.list.rows[1].name:GetText(), "Rezept 2663"), f.list.rows[1].name:GetText())
assert(f.rank:GetText():find("Nicht erlernt"), f.rank:GetText())
f.list.rows[2]:Click()
local body = f.rd.info:GetText()
assert(has(f.rd.reag.note:GetText(), "Reagenzien: noch unbekannt") and not has(body, "Dein Rang"), body)
assert(f.rd.iconFrame.icon.texture == NS.Prof.ICON_UNKNOWN, "no icon from the client: the question mark")
NS.ShowProfessions("lager")
f.list.rows[3]:Click()
assert(has(f.detail.body.fs:GetText(), "Beschreibung lädt"), f.detail.body.fs:GetText())
NS.ShowProfessions("gunst")
assert(#f.list.items == 1 and not has(f.counts:GetText(), "Händlergunst:"), f.counts:GetText())
