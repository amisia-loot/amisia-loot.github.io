--[[without raid]]
-- The modules with the raid module switched off (F-202, D-130): installed but off is a choice, so no
-- note at login; its row stays usable and unchecked, a click switches it on and asks to reload; the
-- hello names only the gear module.
local function msgsWith(text)
    local n = 0
    for _, m in ipairs(STUB.messages) do if m:find(text, 1, true) then n = n + 1 end end
    return n
end
local raid = NS.ModuleInfo("raid")
assert(raid.installed and not raid.enabled and not raid.loaded and raid.here)
assert(NS.ModuleStateText(raid) == "aus")
assert(#NS.ModuleProblems() == 0, "switched off: no note")
assert(NS.VersionModules() == "g")
NS.ToggleMain()
NS.ShowSettingsSection("modules")
local rr = NS.SettingsRows()["modules.raid"]
assert(rr and not rr.control:GetChecked() and rr.hint:GetText() == "", rr.hint:GetText())
rr.control:SetChecked(true)
rr.control:GetScript("OnClick")(rr.control)
assert(STUB.addons.Amisia_Raid.enabled == true)
assert(_G.AmisiaConfirmFrame:IsShown() and _G.AmisiaConfirmFrame.text:GetText() == "Raid ist nach dem Neuladen an. Jetzt neu laden?")
STUB.messages = {}
STUB.fire("PLAYER_LOGIN")
STUB.tick(10)
assert(msgsWith("Es fehlen") == 0 and msgsWith("hat Version") == 0, "no note")
