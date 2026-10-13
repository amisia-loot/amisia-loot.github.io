-- Every setting explains itself (a tip in its tooltip and for the search), and /amisia einstellungen
-- <word> opens the section the word names (its key, its name or the start of it), else searches it.
local missing = {}
for _, sec in ipairs(NS.schema) do
    for _, it in ipairs(sec.items or {}) do
        if it.type ~= "custom" and it.type ~= "desc" and (type(it.tip) ~= "string" or it.tip == "") then
            missing[#missing + 1] = it.key
        end
    end
end
assert(#missing == 0, "settings without a tip: " .. table.concat(missing, ", "))

STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
assert(NS.SettingsSection("map").key == "map", "by its key")
local MAP = NS.L["Karte und Wegpunkt"]
local first = MAP:match("^%S+")
assert(NS.SettingsSection(first).key == "map" and NS.SettingsSection(MAP:upper()).key == "map", "by its name")
if NS.GERMAN then assert(NS.SettingsSection("OBERFL").key == "ui", "folded umlauts") end
assert(NS.SettingsSection("qqq") == nil and NS.SettingsSection("") == nil)
assert(NS.SettingsSection("rolls").key == "rolls")
NS.Set("ui.view", "raider")
assert(NS.SettingsSection("rolls") == nil, "an officers' section is not named in the raider view")
NS.Set("ui.view", "officer")

NS.Dispatch("einstellungen " .. first:lower())
local page = NS.SettingsPageFrame()
assert(page and page:IsVisible(), "the settings page")
assert(page.search:GetText() == MAP, page.search:GetText())
assert(NS.SettingsRows()["map.pins"]:IsShown(), "the section's rows")
NS.Dispatch("settings wegpunkt")
assert(page.search:GetText() == "wegpunkt", "no section starts with it: a search")
NS.Dispatch("einstellungen")
assert(page:IsVisible())
