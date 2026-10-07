--[[locale enUS]]
-- An English client (every locale but deDE): L gives the English text, numbers and dates the English way.
assert(NS.LOCALE == "enUS" and not NS.GERMAN and NS.LANG == "enUS")
local L = NS.L
assert(L["kein Schlüssel, nur für den Test"] == "kein Schlüssel, nur für den Test", "a key without entry shows as it is")
assert(NS.MissingTranslations()["kein Schlüssel, nur für den Test"], "and is listed as missing")
NS.MissingTranslations()["kein Schlüssel, nur für den Test"] = nil
assert(NS.Num(2.5) == "2.5" and NS.Num(3) == "3" and NS.Num(3, 2) == "3.00")
local t = time({ year = 2026, month = 10, day = 7, hour = 20, min = 15 })
assert(NS.FmtDay(t) == "Oct 7" and NS.FmtDate(t) == "Oct 7, 2026" and NS.FmtDayTime(t) == "Oct 7 20:15")
-- the help shows the English words
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(help:find("/amisia help", 1, true) and not help:find("/amisia hilfe", 1, true))
STUB.messages = {}
SlashCmdList.AMISIA("hilfe")
assert(STUB.messages[1], "the German word works in English")
