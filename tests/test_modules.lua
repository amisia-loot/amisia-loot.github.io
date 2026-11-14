-- The modules in the core (F-202, D-130, Core/Modules.lua): the settings section "Module" under
-- "Allgemein" shows a check box per module from the client's AddOn list (not AmisiaDB), a click switches
-- the module's addon for this character and asks to reload (no question when it goes back to what runs);
-- /amisia module lists core and modules with version and state; the note once per login on a module of
-- another version or one that is not installed; a module switched off is no reason for a note.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function msgsWith(text)
    local n = 0
    for _, m in ipairs(STUB.messages) do if m:find(text, 1, true) then n = n + 1 end end
    return n
end
local V = NS.VERSION

-- what the client says
local raid, gear = NS.ModuleInfo("raid"), NS.ModuleInfo("gear")
assert(raid.installed and raid.enabled and raid.loaded and raid.here and raid.version == V and raid.addon == "Amisia_Raid")
assert(gear.installed and gear.enabled and gear.loaded and gear.here and gear.version == V)
assert(NS.ModuleStateText(raid) == "an")
assert(#NS.ModuleProblems() == 0, "a full install: nothing to say")
assert(NS.VersionModules() == "rg")

-- the section: in "Allgemein", one row per module, stores nothing
local found
for _, g in ipairs(NS.SettingsGroups()) do
    for _, sec in ipairs(g.sections) do
        if sec.key == "modules" then found = g.key end
    end
end
assert(found == "amisia", "the section lives under Allgemein: " .. tostring(found))
NS.ToggleMain()
NS.ShowSettingsSection("modules")
local rows = NS.SettingsRows()
local rr, gr = rows["modules.raid"], rows["modules.gear"]
assert(rr and gr and rr:IsShown() and gr:IsShown(), "both rows")
assert(rr.label:GetText() == "Raid" and gr.label:GetText() == "Ausrüstung & Dungeons")
assert(rr.control:GetChecked() and gr.control:GetChecked(), "checked: both on")
assert(rr.hint:GetText() == "", "nothing to add")
assert(AmisiaDB.settings.modules == nil, "no AmisiaDB key")

-- a click switches the addon for this character and asks to reload
local reloaded = 0
_G.ReloadUI = function() reloaded = reloaded + 1 end
rr.control:SetChecked(false)
rr.control:GetScript("OnClick")(rr.control)
local sw = STUB.addonSwitch[#STUB.addonSwitch]
assert(sw and sw.name == "Amisia_Raid" and sw.on == false and sw.character == STUB.player, "DisableAddOn for this character")
assert(STUB.addons.Amisia_Raid.enabled == false)
local C = _G.AmisiaConfirmFrame
assert(C and C:IsShown(), "asks to reload")
assert(C.text:GetText() == "Raid ist nach dem Neuladen aus. Jetzt neu laden?", C.text:GetText())
C.ok:Click()
assert(reloaded == 1)
NS.ShowSettingsSection("modules")
assert(not rr.control:GetChecked() and rr.hint:GetText():find("gilt nach dem Neuladen", 1, true), "off after the reload")
assert(NS.ModuleStateText(NS.ModuleInfo("raid")) == "aus nach /reload")
-- /amisia module
STUB.messages = {}
SlashCmdList.AMISIA("module")
assert(STUB.messages[1]:find("Module:", 1, true))
assert(msgsWith("Amisia (Kern) · " .. V .. " · an") == 1, table.concat(STUB.messages, "\n"))
assert(msgsWith("Raid (Amisia_Raid) · " .. V .. " · aus nach /reload") == 1, table.concat(STUB.messages, "\n"))
assert(msgsWith("Ausrüstung & Dungeons (Amisia_Gear) · " .. V .. " · an") == 1)
SlashCmdList.AMISIA("modules")
assert(msgsWith("Amisia (Kern)") == 2, "the English word works too")
-- back on: what runs now, no question
rr.control:SetChecked(true)
rr.control:GetScript("OnClick")(rr.control)
assert(STUB.addons.Amisia_Raid.enabled == true and not C:IsShown(), "back to what runs: no question")
-- switched off is a choice: no note
STUB.addons.Amisia_Gear.enabled = false
assert(#NS.ModuleProblems() == 0, "a module switched off is no half update")
STUB.addons.Amisia_Gear.enabled = nil

-- the note: once per login, some seconds after it
STUB.addons.Amisia_Raid.version = "2.0.0"
-- the gear module's folder is not there (it did not load either)
STUB.addons.Amisia_Gear = nil
NS.MODULES.gear = nil
local lines = NS.ModuleProblems()
assert(#lines == 2, #lines)
assert(lines[1]:find("Es fehlen Amisia-Module: Amisia_Gear.", 1, true), lines[1])
assert(lines[2]:find("Das Modul Raid hat Version 2.0.0, der Kern " .. V, 1, true), lines[2])
NS.ShowSettingsSection("modules")
assert(rr.hint:GetText():find("Version 2.0.0, Kern", 1, true), rr.hint:GetText())
assert(gr.hint:GetText():find("nicht installiert", 1, true) and not gr.control:GetChecked(), "greyed: not installed")
STUB.messages = {}
STUB.fire("PLAYER_LOGIN")
STUB.tick(5)
assert(msgsWith("Es fehlen Amisia-Module") == 0, "not at once")
STUB.tick(5)
assert(msgsWith("Es fehlen Amisia-Module") == 1 and msgsWith("hat Version 2.0.0") == 1, table.concat(STUB.messages, "\n"))
STUB.fire("PLAYER_LOGIN")
STUB.tick(10)
assert(msgsWith("Es fehlen Amisia-Module") == 1, "once per login")
-- a client that cannot switch addons: the reason, nothing else
local A = C_AddOns
local en, dis = A.EnableAddOn, A.DisableAddOn
A.EnableAddOn, A.DisableAddOn = nil, nil
local ok, why = NS.SetModuleEnabled("raid", false)
assert(ok == nil and why == "Dieser Client kann Addons nicht an- und abschalten.")
A.EnableAddOn, A.DisableAddOn = en, dis
assert(NS.SetModuleEnabled("nix", true) == nil)
NS.MODULES.gear = true
print("modules ok")
