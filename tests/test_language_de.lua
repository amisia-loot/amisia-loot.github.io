--[[preload
AmisiaDB = { settings = { ui = { language = "deDE" } } }
]]
--[[locale enUS]]
-- An English client with "Deutsch" chosen (F-199): Amisia in German, the game's locale English.
assert(NS.LOCALE == "enUS" and NS.CLIENT_LANG == "enUS")
assert(NS.LANG == "deDE" and NS.GERMAN == true)
assert(NS.L["Gilde"] == "Gilde" and NS.L["Aus##Ansage"] == "Aus")
assert(NS.Num(2.5) == "2,5")
local it = NS.SettingItem("ui.language")
assert(it.values[1][2] == "Wie der Client (English)", it.values[1][2])
-- nothing asked in English is missing (German needs no table)
assert(next(NS.MissingTranslations()) == nil)
print("language de ok")
