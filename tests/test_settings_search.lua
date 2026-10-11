-- The settings search, the view switch in the head and /amisia ansicht.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function shownRows()
    local n, keys = 0, {}
    for key, r in pairs(NS.SettingsRows()) do if r:IsShown() then n = n + 1; keys[key] = true end end
    return n, keys
end

NS.Set("ui.view", "raider")
NS.ShowPage("settings")
NS.Refresh()
local page = NS.SettingsPageFrame()
local all = shownRows()
assert(all > 10 and page.found:GetText() == "", "everything without a search: " .. all)

-- typing filters at once: by label, by the name of a choice, by the section's name
local function search(text)
    page.search:SetText(text)
    page.search:GetScript("OnTextChanged")(page.search, true)
end
search("ansicht")
local n, keys = shownRows()
assert(keys["ui.view"] and n < all, "the view row: " .. n)
assert(has(page.found:GetText(), "Einstellungen gefunden"), page.found:GetText())
search("OFFIZIER")
_, keys = shownRows()
assert(keys["ui.view"], "found by its choice Offizier, any case")
search("oberfläche")
_, keys = shownRows()
assert(keys["ui.view"] and keys["ui.minimap"] and keys["ui.expert"], "the whole section by its name")
search("gibtesnicht")
assert(shownRows() == 0 and has(page.found:GetText(), "Nichts gefunden"), page.found:GetText())
-- a new search starts at the top
page.scroll:SetVerticalScroll(200)
search("minimap")
assert(page.scroll:GetVerticalScroll() == 0, "back to the top")
search("")
assert(shownRows() == all and page.found:GetText() == "", "cleared: all again")

-- the view switch in the head
local F = NS.MainFrame and NS.MainFrame() or AmisiaFrame
local btn = F.viewBtn
assert(btn and btn:GetText() == "Raider-Ansicht", tostring(btn and btn:GetText()))
btn:Click()
assert(NS.Get("ui.view") == "officer" and NS.IsOfficerView() and btn:GetText() == "Offiziersansicht", btn:GetText())
btn:Click()
assert(NS.Get("ui.view") == "raider" and btn:GetText() == "Raider-Ansicht")

-- /amisia ansicht
STUB.messages = {}
SlashCmdList.AMISIA("ansicht offizier")
assert(NS.Get("ui.view") == "officer" and has(STUB.messages[#STUB.messages], "Ansicht: Offizier."), STUB.messages[#STUB.messages])
SlashCmdList.AMISIA("ansicht auto")
assert(NS.Get("ui.view") == "auto" and has(STUB.messages[#STUB.messages], "(Automatisch)"), STUB.messages[#STUB.messages])
SlashCmdList.AMISIA("ansicht quatsch")
assert(has(STUB.messages[#STUB.messages], "Aufruf: /amisia ansicht"), STUB.messages[#STUB.messages])
SlashCmdList.AMISIA("ansicht")
assert(has(STUB.messages[#STUB.messages], "Ansicht: "), "the current view")
NS.Reset("ui.view")
