--[[game tbc]]
-- The modules on TBC Anniversary (F-202, D-130): the gear module cannot load here, so its row in
-- "Module" stays grey with "nur auf WoW Forever", it is no missing module (no note), the hello names
-- the raid module only, and /amisia module says so.
local function msgsWith(text)
    local n = 0
    for _, m in ipairs(STUB.messages) do if m:find(text, 1, true) then n = n + 1 end end
    return n
end
local gear = NS.ModuleInfo("gear")
assert(not gear.here and not gear.loaded, "gear: Forever only")
assert(NS.ModuleInfo("raid").loaded and NS.ModuleInfo("raid").here)
assert(#NS.ModuleProblems() == 0, "nothing missing on TBC: " .. table.concat(NS.ModuleProblems(), " | "))
assert(NS.VersionModules() == "r")
NS.ToggleMain()
NS.ShowSettingsSection("modules")
local gr = NS.SettingsRows()["modules.gear"]
assert(gr and gr:IsShown() and not gr.control:GetChecked(), "the gear row: shown, not checked")
assert(gr.hint:GetText():find("nur auf WoW Forever", 1, true), gr.hint:GetText())
STUB.messages = {}
SlashCmdList.AMISIA("module")
assert(msgsWith("Ausrüstung & Dungeons (Amisia_Gear) · - · nur WoW Forever") == 1, table.concat(STUB.messages, "\n"))
STUB.fire("PLAYER_LOGIN")
STUB.tick(10)
assert(msgsWith("Es fehlen") == 0, "no note")
