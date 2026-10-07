--[[locale deDE]]
-- The German client: L gives the key back (the part before "##"), numbers and dates the German way.
assert(NS.LOCALE == "deDE" and NS.GERMAN and NS.LANG == "deDE")
local L = NS.L
assert(L["Übersicht"] == "Übersicht")
assert(L["Aus##Ansage"] == "Aus", "a context after ## is not shown")
assert(next(NS.MissingTranslations()) == nil, "German keeps no list of missing texts")
assert(NS.Num(2.5) == "2,5" and NS.Num(3) == "3" and NS.Num(3, 2) == "3,00")
local t = time({ year = 2026, month = 10, day = 7, hour = 20, min = 15 })
assert(NS.FmtDay(t) == "07.10." and NS.FmtDate(t) == "07.10.2026" and NS.FmtDayTime(t) == "07.10. 20:15")
assert(NS.N_("Kopf") == "Kopf")
-- slash words: the German word in the help, the English one works too
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(help:find("/amisia hilfe", 1, true))
STUB.messages = {}
SlashCmdList.AMISIA("help")
assert(STUB.messages[1], "the English word works in German")
-- a word two commands claim is an error
assert(not pcall(NS.RegisterSlash, "zweitehilfe", { aliases = { "hilfe" }, run = function() end }))
assert(not pcall(NS.RegisterSlash, "zweitehilfe2", { en = "help", run = function() end }))
