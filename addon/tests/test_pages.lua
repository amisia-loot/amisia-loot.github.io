-- Every page builds and refreshes; officer pages hide for raiders; the settings page writes settings.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
_G.UnitClass = function() return "Priester", "PRIEST" end
_G.UnitLevel = function() return 24 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function() return nil end

for _, key in ipairs({ "overview", "raids", "export", "rolls", "softres", "bank", "settings", "about" }) do
    NS.ShowPage(key)
    assert(NS.CurrentPage() == key, "opens " .. key)
end
-- gear only where the gear data is (the tests load it)
NS.ShowPage("gear"); assert(NS.CurrentPage() == "gear")
-- tools only in expert mode
NS.ShowPage("tools"); assert(NS.CurrentPage() ~= "tools")
NS.Set("ui.expert", true); NS.ShowPage("tools"); assert(NS.CurrentPage() == "tools")
NS.Reset("ui.expert")

-- raider view: officer pages and cards stay hidden
NS.Set("ui.view", "raider")
NS.ShowPage("raids"); assert(NS.CurrentPage() == "overview")
NS.ShowPage("export"); assert(NS.CurrentPage() == "overview")
NS.Reset("ui.view")

-- the overview shows cards
NS.ShowPage("overview")
local panelFrame = AmisiaFrame and true
assert(panelFrame)

-- export page keeps the old behaviour
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
NS.ShowExport(false)
assert(lastMsg():find("Export: 1 neue oder geänderte Raid", 1, true), lastMsg())
assert(NS.CurrentPage() == "export")

-- raids page: selection drives "Ausgewählte" export
local s = NS.Active()
NS.RaidSelection[s.id] = true
NS.ShowExport(false)
assert(lastMsg():find("Nichts Neues", 1, true) == nil, "a selected session exports again")
NS.RaidSelection[s.id] = nil

-- settings page: toggling a row writes the setting
NS.ShowPage("settings")
local rows = NS.SettingsRows()
assert(rows["record.enabled"] and rows["record.enabled"].control:GetChecked() == true)
rows["record.enabled"].control:Click()
assert(NS.Get("record.enabled") == false)
NS.Reset("record.enabled")
NS.Refresh()
assert(rows["record.enabled"].control:GetChecked() == true)

-- roll history feeds the rolls page
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.StartRoll(link, 5)); NS.StopRoll()
assert(#NS.RollHistory() >= 1)
NS.ShowPage("rolls")

-- the soft-reserves page fills its list without losing the row text
local errs = {}
local oldHandler = geterrorhandler
_G.geterrorhandler = function() return function(e) errs[#errs + 1] = e end end
NS.SetSoftRes("Vuloo " .. link .. "\nFraktur 32235\n")
NS.ShowPage("softres"); NS.Refresh(); NS.Refresh()
assert(#errs == 0, "softres page: " .. tostring(errs[1]))
_G.geterrorhandler = oldHandler
NS.ClearSoftRes()

-- a raider's /amisia export shows nothing, so nothing is marked as exported
NS.Set("ui.view", "raider")
AmisiaDB.exported = {}
local before = NS.ExportState(NS.Active())
assert(before == "new")
NS.ShowExport(true)
assert(NS.ExportState(NS.Active()) == before, "raider export marks nothing")
NS.Reset("ui.view")

-- the quick menu closes on a second click from the same owner
local m = NS.W.Menu(UIParent, { { "Eins", function() end } })
assert(m:IsShown())
NS.W.Menu(UIParent, { { "Eins", function() end } })
assert(not m:IsShown(), "second click closes the menu")
