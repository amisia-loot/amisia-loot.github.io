-- Amisia's modules (F-202, D-130): the settings section "Module" under "Allgemein" (one check box per
-- module: it switches the module's addon on or off for this character in the client's AddOn list and
-- asks to reload, as the language does, F-199), /amisia module (en modules: the core and every module
-- with version and state) and the note once per login when a loaded module's version is not the core's
-- or a module is not installed at all (a half update: only the folder Amisia replaced by hand). Whether
-- a module is on is the client's to keep (the AddOn list per character), never AmisiaDB's. Works with
-- any module missing: it reads the client, not the modules' code.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local NOTE_AFTER = 8   -- seconds after the login: the chat is there and the login's lines have passed

local MODULE_NAME = { raid = L["Raid##Modul"], gear = L["Ausrüstung & Dungeons"] }

-- The client's function: C_AddOns on every client of Amisia, the old global as fallback.
local function api(key)
    local A = _G.C_AddOns
    return (A and A[key]) or _G[key]
end

local function me() return UnitName and UnitName("player") or nil end

local function moduleOf(key)
    for _, m in ipairs(ns.MODULE_ADDONS) do
        if m.key == key then return m end
    end
    return nil
end

-- The shown name of a module ("Raid", "Ausrüstung & Dungeons").
function ns.ModuleName(key) return MODULE_NAME[key] or tostring(key) end

-- What the client says about a module's addon: { key, addon, here (it can load on this client: the
-- gear module on WoW Forever only), installed, enabled (for this character, as the AddOn list shows
-- it), loaded (its files ran this session), version (its TOC's ## Version) }.
function ns.ModuleInfo(key)
    local m = moduleOf(key)
    if not m then return nil end
    local info = { key = m.key, addon = m.addon, loaded = ns.HasModule(m.key), here = not m.forever or ns.FOREVER }
    -- installed: DoesAddOnExist where the client has it, else GetAddOnInfo ("MISSING" for a folder that is not there)
    local installed
    local exists = _G.C_AddOns and _G.C_AddOns.DoesAddOnExist
    if type(exists) == "function" then
        local ok, yes = pcall(exists, m.addon)
        if ok then installed = yes and true or false end
    end
    local getInfo = api("GetAddOnInfo")
    if installed == nil and type(getInfo) == "function" then
        local ok, name, _, _, _, reason = pcall(getInfo, m.addon)
        installed = ok and name ~= nil and reason ~= "MISSING"
    end
    info.installed = (installed or info.loaded) and true or false
    -- the state for this character: 0 off (C_AddOns: name first; the old global: character first)
    local state
    local A = _G.C_AddOns
    if A and type(A.GetAddOnEnableState) == "function" then
        local ok, v = pcall(A.GetAddOnEnableState, m.addon, me())
        if ok then state = v end
    elseif type(_G.GetAddOnEnableState) == "function" then
        local ok, v = pcall(_G.GetAddOnEnableState, me(), m.addon)
        if ok then state = v end
    end
    if state == nil then
        info.enabled = info.loaded
    else
        info.enabled = info.installed and (state == true or (tonumber(state) or 0) > 0)
    end
    local meta = api("GetAddOnMetadata")
    if info.installed and type(meta) == "function" then
        local ok, v = pcall(meta, m.addon, "Version")
        if ok and type(v) == "string" and v ~= "" then info.version = v end
    end
    return info
end

-- Switches a module's addon on or off for this character (the client's AddOn list; it loads or stays
-- away after the next /reload). Returns true, or nil and the reason.
function ns.SetModuleEnabled(key, on)
    local m = moduleOf(key)
    if not m then return nil, L["Unbekanntes Modul."] end
    local fn = api(on and "EnableAddOn" or "DisableAddOn")
    if type(fn) ~= "function" then return nil, L["Dieser Client kann Addons nicht an- und abschalten."] end
    local ok, err = pcall(fn, m.addon, me())
    if not ok then return nil, tostring(err) end
    return true
end

-- The state of a module in a word: "an", "aus", "fehlt", "nur WoW Forever"; "an nach /reload" when the
-- AddOn list says otherwise than what runs now.
function ns.ModuleStateText(info)
    if not info.here then return L["nur WoW Forever"] end
    if not info.installed then return L["fehlt##Modul"] end
    local word = info.enabled and L["an"] or L["aus"]
    if info.enabled ~= info.loaded then return L["%s nach /reload"]:format(word) end
    return word
end

---------------------------------------------------------------------------
-- The note on a half update
---------------------------------------------------------------------------
-- The lines of the note (empty: nothing to say): a loaded module of another version than the core, a
-- module that can load here but is not installed. A module switched off is no reason (a choice).
function ns.ModuleProblems()
    local out, missing = {}, {}
    for _, m in ipairs(ns.MODULE_ADDONS) do
        local info = ns.ModuleInfo(m.key)
        if info.here and not info.installed then
            missing[#missing + 1] = m.addon
        elseif info.loaded and info.version and info.version ~= ns.VERSION then
            out[#out + 1] = L["Das Modul %s hat Version %s, der Kern %s. Bitte alle Amisia-Ordner aus demselben Download installieren."]:format(
                ns.ModuleName(m.key), info.version, ns.VERSION)
        end
    end
    if #missing > 0 then
        table.insert(out, 1, L["Es fehlen Amisia-Module: %s. Amisia besteht aus den Ordnern Amisia, Amisia_Raid und Amisia_Gear; bitte alle aus demselben Download installieren (/amisia module)."]:format(
            table.concat(missing, ", ")))
    end
    return out
end

local noted = false
ns.OnEvent("PLAYER_LOGIN", function()
    if noted then return end
    noted = true
    C_Timer.After(NOTE_AFTER, function()
        for _, line in ipairs(ns.ModuleProblems()) do ns.msg(line) end
    end)
end)

---------------------------------------------------------------------------
-- /amisia module
---------------------------------------------------------------------------
ns.RegisterSlash("module", { en = "modules", desc = L["Kern und Module mit Version und Zustand (an, aus, fehlt)"], run = function()
    ns.msg(L["Module:"])
    local chat = DEFAULT_CHAT_FRAME
    chat:AddMessage(("  Amisia (%s) · %s · %s"):format(L["Kern"], ns.VERSION or "?", L["an"]))
    for _, m in ipairs(ns.MODULE_ADDONS) do
        local info = ns.ModuleInfo(m.key)
        local version = info.version or "-"
        if info.version and info.version ~= ns.VERSION then version = "|cffff9933" .. version .. "|r" end
        chat:AddMessage(("  %s (%s) · %s · %s"):format(ns.ModuleName(m.key), m.addon, version, ns.ModuleStateText(info)))
    end
end })

---------------------------------------------------------------------------
-- The settings section "Module" (Allgemein)
---------------------------------------------------------------------------
local ROW_H, LABEL_W = 26, 300   -- as the settings page's rows (UI/Pages/Settings.lua)

local function reloadAsk(key, on)
    local text = on and L["%s ist nach dem Neuladen an. Jetzt neu laden?"] or L["%s ist nach dem Neuladen aus. Jetzt neu laden?"]
    ns.W.Confirm(L["Module"], text:format(ns.ModuleName(key)), L["Neu laden"], function()
        if type(ReloadUI) == "function" then ReloadUI() end
    end)
end

local function clicked(key, on)
    local ok, why = ns.SetModuleEnabled(key, on)
    if not ok then ns.msg(why) end
    ns.Refresh()
    local info = ok and ns.ModuleInfo(key)
    -- back to what runs now: nothing to reload
    if info and info.enabled ~= info.loaded then reloadAsk(key, on) end
end

-- A row as the settings page's: the module's name, the client's check box, a grey hint after it.
local function buildRow(key)
    return function(parent)
        local W, T = ns.W, ns.Theme
        local r = CreateFrame("Frame", nil, parent)
        r:SetSize(560, ROW_H)
        r:EnableMouse(true)
        r.label = W.Text(r, T.FONT.text, LABEL_W)
        r.label:SetPoint("LEFT", 12, 0)
        r.label:SetText(ns.ModuleName(key))
        r.control = W.Toggle(r, function(v) clicked(key, v) end)
        r.control:SetPoint("LEFT", LABEL_W + 20, 0)
        r.hint = W.Text(r, T.FONT.hint, 200)
        r.hint:SetPoint("LEFT", r.control, "RIGHT", 8, 0)
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.ModuleName(key), 1, 0.82, 0)
            if self.it and self.it.tip then GameTooltip:AddLine(self.it.tip, 0.85, 0.85, 0.85, true) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end
end

local function fillRow(key)
    return function(r)
        local info = ns.ModuleInfo(key)
        local usable = info.here and info.installed
        r.control:SetChecked(usable and info.enabled)
        if r.control.SetEnabled then r.control:SetEnabled(usable) end
        local hint = ""
        if not info.here then
            hint = L["nur auf WoW Forever"]
        elseif not info.installed then
            hint = L["nicht installiert"]
        elseif info.enabled ~= info.loaded then
            hint = L["gilt nach dem Neuladen"]
        elseif info.version and info.version ~= ns.VERSION then
            hint = L["Version %s, Kern %s"]:format(info.version, ns.VERSION)
        end
        r.hint:SetText(hint ~= "" and ("|cff8f8f8f" .. hint .. "|r") or "")
        r.label:SetAlpha(usable and 1 or 0.5)
        r:SetHeight(ROW_H)
    end
end

ns.RegisterSettings{ key = "modules", label = L["Module"], order = 86, group = "amisia", items = {
    { key = "modules.raid", type = "custom", label = ns.ModuleName("raid"),
      tip = L["Das Modul Amisia: Raid (Ordner Amisia_Raid): Aufnahme, Vergaben, Rolls, Soft-Reserves, Punkte, Aufstellung, Kalender, Raid-Check. Schaltet das Addon für diesen Charakter an oder aus; gilt nach dem Neuladen."],
      build = buildRow("raid"), fill = fillRow("raid") },
    { key = "modules.gear", type = "custom", label = ns.ModuleName("gear"),
      tip = L["Das Modul Amisia: Ausrüstung & Dungeons (Ordner Amisia_Gear, nur WoW Forever): Ausrüstung, Planer, Dungeons, Quests, Karte, Berufe, Talente. Schaltet das Addon für diesen Charakter an oder aus; gilt nach dem Neuladen."],
      build = buildRow("gear"), fill = fillRow("gear") },
}}
end)
