-- The window "Gewichte" (F-230, D-161, AmisiaWeightsFrame, tokens T.WEIGHTS), opened from the planner's menu
-- "Optionen" > "Gewichte ...": beside the planner, whose suggestions and targets follow every change. For the
-- own class and spec (ns.BisOpts; the sets hold for every character of the class): the line of the spec, the set
-- (its menu, "Neu", "Umbenennen", "Löschen"; the name box in its place while renaming), "Vorlage" (the
-- simulation's weights of the class, GEAR_WEIGHTS.SIM, as a set "<Name> (Sim)"), "Einfügen", "Kopieren",
-- "Amisias Zahlen übernehmen" (the weighting in force at the own level, per point), the weighting (a click goes
-- round: Speedrun, Hardcore, Raid, Eigene with a chosen set); the list of the weights per point: the role's first,
-- then the set's other weights, then "Weitere Werte" (folded). A typed number counts 0.3 s after the last key (or
-- on Enter); empty is 0. The window "Gewichte einfügen" (AmisiaWeightsPaste) reads a pasted text (OW.Parse) with
-- a preview before "Übernehmen", or shows the set's line to copy. Nothing is sent.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local WT = T.WEIGHTS
local Gear = ns.Gear
local OW = ns.OwnWeights
local ORANGE, RED, GREEN = T.ORANGE, "|cffff5050", "|cff4fd06a"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "

local F, P            -- the window, the paste window
local current         -- the name of the shown set
local renaming = false
local showMore = false

local function who()
    local o = ns.BisOpts()
    return o.class, o.spec, o
end

-- the weights of a role first (a caster's schools from its spec)
local ROLE_KEYS = {
    caster = { "SP", "SCHOOL", "INT", "SPI", "MP5", "HIT", "CRIT", "HASTE" },
    heal = { "HEAL", "SP", "INT", "SPI", "MP5", "CRIT", "HASTE" },
    phys = { "STR", "AGI", "AP", "DPS", "HIT", "CRIT", "HASTE", "EXP" },
    tank = { "STA", "ARMOR", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "STR", "AGI", "AP", "HIT", "EXP" },
    hunter = { "AGI", "RAP", "AP", "RDPS", "DPS", "INT", "MP5", "HIT", "CRIT", "HASTE" },
}

-- The rows of the list: { key } for a weight, { more = n } for the fold.
local function rowItems(class, spec, set)
    local sp = Gear.SpecInfo(class, spec)
    local model = class == "HUNTER" and "hunter" or (sp and sp.model) or "phys"
    local out, seen = {}, {}
    local function add(k)
        if Gear.OWN_KEY[k] and not seen[k] then
            seen[k] = true
            out[#out + 1] = { key = k }
        end
    end
    for _, k in ipairs(ROLE_KEYS[model] or ROLE_KEYS.phys) do
        if k == "SCHOOL" then
            local schools = {}
            for school in pairs(sp and type(sp.p) == "table" and type(sp.p.school) == "table" and sp.p.school or {}) do
                schools[#schools + 1] = school
            end
            table.sort(schools)
            for _, school in ipairs(schools) do add(school) end
        else
            add(k)
        end
    end
    -- the set's other weights stay in sight
    for _, k in ipairs(Gear.OWN_KEYS) do
        if set and type(set[k]) == "number" and set[k] ~= 0 then add(k) end
    end
    local rest = {}
    for _, k in ipairs(Gear.OWN_KEYS) do
        if not seen[k] then rest[#rest + 1] = k end
    end
    out[#out + 1] = { more = #rest }
    if showMore then
        for _, k in ipairs(rest) do out[#out + 1] = { key = k } end
    end
    return out
end

local function say(text)
    if F then F.result:SetText(text or "") end
end

-- The shown set: a newly chosen one (here or elsewhere), else the one shown before if it is still there, else
-- the chosen one, else the first.
local lastPick
local function shownSet(class, spec)
    local pick = OW.Pick(class, spec)
    if pick and pick ~= lastPick then current = pick end
    lastPick = pick
    if current and OW.Get(class, spec, current) then return current end
    current = pick or OW.Names(class, spec)[1]
    return current
end

local refresh

---------------------------------------------------------------------------
-- The list of the weights
---------------------------------------------------------------------------

-- A typed number: taken at once, or false with the reason (left for Enter to say).
local function take(box, text, loud)
    local class, spec = who()
    if not (current and box.key) then return end
    local v, why = OW.ReadNumber(text)
    if v == false then
        if loud then
            say(RED .. why .. "|r")
            box:SetText(OW.NumText((OW.Get(class, spec, current) or {})[box.key]))
        end
        return
    end
    local ok, err = OW.SetValue(class, spec, current, box.key, v)
    if not ok then say(RED .. tostring(err) .. "|r") elseif loud then say("") end
end

local function buildRow(r)
    r.label = W.Text(r, T.FONT.text, WT.LABEL_W)
    r.label:SetPoint("LEFT", WT.LABEL_X, 0)
    r.box = W.TimeBox(r, WT.BOX_W, function(text) take(r.box, text, true) end)
    r.box:SetPoint("RIGHT", -WT.BOX_X, 0)
    -- typing counts 0.3 s after the last key, not with every key
    r.box:HookScript("OnTextChanged", function(self, user)
        if not user then return end
        local text, key = self:GetText(), self.key
        C_Timer.After(0.3, function()
            if self:GetText() == text and self.key == key and self:HasFocus() then take(self, text, false) end
        end)
    end)
    r:SetScript("OnClick", function(self)
        if self.item and self.item.more then
            showMore = not showMore
            refresh()
        end
    end)
end

local function fillRow(r, item)
    r.item = item
    if item.more then
        r.label:SetText(T.GOLD_TEXT .. (showMore and L["Weitere Werte ausblenden"] or L["Weitere Werte (%d)"]:format(item.more)) .. "|r")
        r.box:Hide()
        r.box.key = nil
        return
    end
    local class, spec = who()
    local set = current and OW.Get(class, spec, current) or {}
    r.label:SetText(Gear.OWN_LABELS[item.key] or item.key)
    r.box.key = item.key
    r.box:Show()
    if not r.box:HasFocus() then r.box:SetText(OW.NumText(set[item.key])) end
end

---------------------------------------------------------------------------
-- The menus and actions
---------------------------------------------------------------------------

local function setMenu(self)
    local class, spec = who()
    local out = {}
    local pick = OW.Pick(class, spec)
    for _, name in ipairs(OW.Names(class, spec)) do
        out[#out + 1] = { (name == pick and CHECK or "") .. name, function()
            current = name
            OW.Choose(class, spec, name)
            refresh()
        end }
    end
    if #out == 0 then out[1] = { L["Noch kein Satz"] } end
    W.Menu(self, out)
end

local function templateMenu(self)
    local class, spec = who()
    local list = OW.Templates(class)
    if not list then
        say(L["Diese Datendatei hat keine Vorlagen."])
        return
    end
    local mine, other = {}, {}
    for _, t in ipairs(list) do
        local entry = { L["%s (Sim)"]:format(L[t.name]), function()
            local name, why = OW.FromTemplate(class, spec, t)
            if name then
                current = name
                say(L["Satz \"%s\" angelegt und gewählt."]:format(name))
            else
                say(RED .. tostring(why) .. "|r")
            end
            refresh()
        end, tipTitle = L["%s (Sim)"]:format(L[t.name]),
            tip = L["Aus der WoWSims-Simulation für Forever (MIT). Legt einen eigenen Satz an, den du danach ändern kannst; die Vorlage bleibt, wie sie ist."] }
        if t.spec == spec then mine[#mine + 1] = entry else other[#other + 1] = entry end
    end
    local out = {}
    for _, e in ipairs(mine) do out[#out + 1] = e end
    for _, e in ipairs(other) do out[#out + 1] = e end
    W.Menu(self, out, { width = WT.SET_MAX_W + 40 })
end

local function newSet()
    local class, spec = who()
    local name = OW.FreeName(class, spec, L["Neuer Satz"])
    local saved, why
    if name then saved, why = OW.Save(class, spec, name, {}, { pick = true }) end
    if not saved then
        say(RED .. tostring(why or L["Höchstens %d Sätze je Spezialisierung."]:format(OW.MAX_SETS)) .. "|r")
        return
    end
    current = saved
    renaming = true
    refresh()
    F.nameBox:SetFocus()
    F.nameBox:HighlightText()
end

local function startRename()
    if not current then return end
    renaming = true
    refresh()
    F.nameBox:SetFocus()
    F.nameBox:HighlightText()
end

local function commitName(text)
    if not renaming then return end
    renaming = false
    local class, spec = who()
    if current then
        local name, why = OW.Rename(class, spec, current, text)
        if name then current = name else say(RED .. tostring(why) .. "|r") end
    end
    refresh()
end

local function deleteSet()
    local class, spec = who()
    local name = current
    if not name then return end
    W.Confirm(L["Satz löschen"], L["Den Satz \"%s\" löschen? Das lässt sich nicht zurücknehmen."]:format(name), L["Löschen"], function()
        OW.Delete(class, spec, name)
        current = nil
        say(L["Satz \"%s\" gelöscht."]:format(name))
        refresh()
    end)
end

local function fromAmisia()
    local class, spec, o = who()
    local kind = o.kind == "Eigene" and "Speedrun" or o.kind   -- l10n-ok: setting key
    local name = current
    if not name then
        name = OW.FreeName(class, spec, L["Amisia %s"]:format(kind))
        local saved, why
        if name then saved, why = OW.Save(class, spec, name, {}, { pick = true }) end
        if not saved then
            say(RED .. tostring(why or L["Höchstens %d Sätze je Spezialisierung."]:format(OW.MAX_SETS)) .. "|r")
            return
        end
        name = saved
    end
    local saved, why = OW.FromAmisia(class, spec, name, kind, o.level)
    if saved then
        current = saved
        say(L["Amisias Zahlen (%s, Stufe %d) übernommen, je Punkt."]:format(kind, o.level))
    else
        say(RED .. tostring(why) .. "|r")
    end
    refresh()
end

---------------------------------------------------------------------------
-- The paste window
---------------------------------------------------------------------------

local function pastePreview()
    if not P or P.mode ~= "paste" then return end
    local class, spec = who()
    local res, err = OW.Parse(P.area.box:GetText() or "")
    P.res = nil
    if not res then
        P.preview:SetText((P.area.box:GetText() or ""):find("%S") and (RED .. err .. "|r") or "")
        P.apply:SetEnabled(false)
        return
    end
    local parts = {}
    for _, k in ipairs(res.known) do parts[#parts + 1] = ("%s %s"):format(Gear.OWN_LABELS[k], OW.NumText(res.values[k])) end
    local n = #res.known
    local lines = { n == 1 and L["Erkannt: 1 Wert (%s)"]:format(parts[1])
        or L["Erkannt: %d Werte (%s)"]:format(n, table.concat(parts, ", ")) }
    if #res.unknown > 0 then lines[#lines + 1] = ORANGE .. L["unbekannt: %s"]:format(table.concat(res.unknown, ", ")) .. "|r" end
    if #res.bad > 0 then lines[#lines + 1] = ORANGE .. L["nicht übernommen: %s"]:format(table.concat(res.bad, "; ")) .. "|r" end
    if res.cut then lines[#lines + 1] = ORANGE .. L["Nur die ersten %d Zeichen gelesen."]:format(OW.MAX_TEXT) .. "|r" end
    local name, replaces = OW.PasteName(class, spec, res)
    local ok = n > 0 and name ~= nil
    if not name then
        lines[#lines + 1] = RED .. L["Höchstens %d Sätze je Spezialisierung."]:format(OW.MAX_SETS) .. "|r"
    elseif replaces then
        lines[#lines + 1] = L["Ersetzt den Satz \"%s\"."]:format(name)
    elseif OW.Count(class, spec) >= OW.MAX_SETS then
        lines[#lines + 1] = RED .. L["Höchstens %d Sätze je Spezialisierung."]:format(OW.MAX_SETS) .. "|r"
        ok = false
    else
        lines[#lines + 1] = L["Neuer Satz \"%s\"."]:format(name)
    end
    P.preview:SetText(table.concat(lines, "\n"))
    P.res, P.name, P.replaces = ok and res or nil, name, replaces
    P.apply:SetEnabled(ok)
end

local function schedulePreview()
    P.gen = (P.gen or 0) + 1
    local gen = P.gen
    C_Timer.After(0.3, function() if P.gen == gen then pastePreview() end end)
end

local function applyPaste()
    if not (P and P.res) then return end
    local class, spec = who()
    local name, why = OW.Save(class, spec, P.name, P.res.values, { replace = P.replaces, pick = true })
    if not name then
        P.preview:SetText(RED .. tostring(why) .. "|r")
        return
    end
    current = name
    P:Hide()
    say(GREEN .. L["Satz \"%s\" übernommen."]:format(name) .. "|r")
    refresh()
end

local function buildPaste()
    P = W.Window("AmisiaWeightsPaste", WT.PASTE_W, WT.PASTE_H, { title = L["Gewichte einfügen"], strata = "FULLSCREEN_DIALOG" })
    P:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    local pad, inner = T.WINDOW_PAD, WT.PASTE_W - 2 * T.WINDOW_PAD
    P.hint = W.Text(P, T.FONT.text, inner, true)
    P.hint:SetPoint("TOPLEFT", pad, WT.HINT_Y)
    P.hint:SetHeight(WT.HINT_H)
    P.hint:SetJustifyV("TOP")
    P.area = W.EditArea(P)
    P.area:SetPoint("TOPLEFT", pad, WT.BOX_Y)
    P.area:SetSize(inner, WT.BOX_H)
    P.area.box:SetMaxLetters(OW.MAX_TEXT + 1000)
    P.area.box:SetScript("OnTextChanged", function(self, user)
        if P.mode == "copy" then
            if user then
                self:SetText(P.line or "")
                self:HighlightText()
            end
            return
        end
        schedulePreview()
    end)
    P.preview = W.Text(P, T.FONT.text, inner, true)
    P.preview:SetPoint("TOPLEFT", pad, WT.PREVIEW_Y)
    P.preview:SetHeight(WT.PREVIEW_H)
    P.preview:SetJustifyV("TOP")
    P.preview:SetMaxLines(6)
    P.apply = W.Button(P, L["Übernehmen"], WT.BUTTON_W, applyPaste)
    W.FitChip(P.apply, WT.BUTTON_W)
    P.apply:SetPoint("BOTTOMLEFT", pad, WT.BUTTON_Y)
    P.close = W.Link(P, L["Abbrechen"], function() P:Hide() end)
    P.close:SetPoint("LEFT", P.apply, "RIGHT", T.LAYOUT.ITEM_GAP, 0)
end

-- Opens the paste window: mode "paste" (an empty box, the preview) or "copy" (the set's line, marked).
local function openPaste(mode)
    if not P then buildPaste() end
    local class, spec = who()
    P.mode = mode
    P.res = nil
    if mode == "copy" then
        local set = current and OW.Get(class, spec, current)
        if not set then return end
        P.line = OW.Export(class, current, set)
        P:SetTitle(L["Gewichte kopieren"])
        P.hint:SetText(L["Mit Strg+C kopieren und in Discord oder mit der Gilde teilen; \"Einfügen\" liest die Zeile wieder."])
        P.area.box:SetText(P.line)
        P.preview:SetText("")
        P.apply:Hide()
        P.close:SetText(L["Schließen"])
        W.FitChip(P.close)
        P.close:ClearAllPoints()
        P.close:SetPoint("BOTTOMLEFT", T.WINDOW_PAD, WT.BUTTON_Y + 1)
    else
        P:SetTitle(L["Gewichte einfügen"])
        P.hint:SetText(L["Eine Liste Name=Zahl oder die Gewichte-Zeile, die Simulationen und Guides zum Kopieren anbieten."])
        P.area.box:SetText("")
        P.preview:SetText("")
        P.apply:Show()
        P.apply:SetEnabled(false)
        P.close:SetText(L["Abbrechen"])
        W.FitChip(P.close)
        P.close:ClearAllPoints()
        P.close:SetPoint("LEFT", P.apply, "RIGHT", T.LAYOUT.ITEM_GAP, 0)
    end
    P:Show()
    if P.Raise then P:Raise() end
    P.area.box:SetFocus()
    if mode == "copy" then P.area.box:HighlightText() end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

refresh = function()
    if not (F and F:IsShown()) then return end
    local class, spec, o = who()
    local sp = Gear.SpecInfo(class, spec)
    local specName = sp and L[sp.name] or "?"
    if o.guessed then specName = L["%s (geraten)"]:format(specName) end
    F.info:SetText(L["%s, %s: gilt für jeden Charakter dieser Klasse"]:format(specName, Gear.CLASS_NAMES[class] or tostring(class)))
    local name = shownSet(class, spec)
    local set = name and OW.Get(class, spec, name)
    local pick = OW.Pick(class, spec)
    F.setLink:SetText(name and L["Satz: %s"]:format(name) .. (name == pick and "" or (" " .. L["(nicht gewählt)"])) or L["Satz: keiner"])
    W.FitChip(F.setLink, nil, WT.SET_MAX_W)
    F.setLink:SetShown(not renaming)
    F.nameBox:SetShown(renaming)
    if renaming and not F.nameBox:HasFocus() then F.nameBox:SetText(name or "") end
    W.Row(F, { renaming and F.nameBox or F.setLink, F.newLink, F.renameLink, F.deleteLink }, T.TAB_GAP, T.WINDOW_PAD, WT.SET_Y)
    F.renameLink:SetEnabled(name ~= nil)
    F.deleteLink:SetEnabled(name ~= nil)
    F.copyLink:SetEnabled(set ~= nil)
    F.tplLink:SetEnabled(OW.Templates(class) ~= nil)
    F.kindLink:SetText(L["Gewichtung: %s"]:format(Gear.KindText(class, spec, o.kind)))
    W.FitChip(F.kindLink)
    if set then
        F.list:SetItems(rowItems(class, spec, set))
        F.list:Show()
        F.empty:Hide()
    else
        F.list:SetItems({})
        F.list:Hide()
        F.empty:Show()
    end
    F.zero:SetShown(set ~= nil and OW.AllZero(set))
end
ns.WeightsRefresh = function() refresh() end

local function build()
    F = W.Window("AmisiaWeightsFrame", WT.W, WT.H, { title = L["Gewichte"],
        onShow = function() refresh() end })
    F:SetPoint("CENTER", UIParent, "CENTER", 380, 20)
    local pad, inner = T.WINDOW_PAD, WT.W - 2 * T.WINDOW_PAD

    F.info = W.Text(F, T.FONT.hint, inner)
    F.info:SetPoint("TOPLEFT", pad, WT.INFO_Y)

    F.setLink = W.Link(F, "", setMenu)
    W.Tooltip(F.setLink, L["Satz"], L["Deine Sätze dieser Spezialisierung; ein Klick wählt einen. Die Gewichtung \"Eigene\" rechnet mit dem gewählten."])
    F.nameBox = W.LineEdit(F, WT.NAME_W, commitName)
    F.nameBox:SetMaxLetters(OW.MAX_NAME * 2)
    F.nameBox:Hide()
    F.newLink = W.Link(F, L["Neu"], newSet)
    W.Tooltip(F.newLink, L["Neu"], L["Ein leerer Satz; danach den Namen eintippen."])
    F.renameLink = W.Link(F, L["Umbenennen"], startRename)
    F.deleteLink = W.Link(F, L["Löschen"], deleteSet)
    for _, b in ipairs({ F.newLink, F.renameLink, F.deleteLink }) do W.FitChip(b) end

    F.tplLink = W.Link(F, L["Vorlage"], templateMenu)
    W.Tooltip(F.tplLink, L["Vorlage"], L["Die Gewichte der WoWSims-Simulation für Forever (MIT) für deine Klasse. Ein Klick legt einen Satz \"<Name> (Sim)\" an. Ohne Vorlagen in den Daten bleibt das grau."])
    F.pasteLink = W.Link(F, L["Einfügen"], function() openPaste("paste") end)
    W.Tooltip(F.pasteLink, L["Einfügen"], L["Eine Liste Name=Zahl (Deutsch oder Englisch) oder die Gewichte-Zeile, die Simulationen und Guides zum Kopieren anbieten; vor dem Übernehmen eine Vorschau."])
    F.copyLink = W.Link(F, L["Kopieren"], function() openPaste("copy") end)
    W.Tooltip(F.copyLink, L["Kopieren"], L["Der gewählte Satz als eine Zeile zum Teilen."])
    F.amisiaLink = W.Link(F, L["Amisias Zahlen übernehmen"], fromAmisia)
    W.Tooltip(F.amisiaLink, L["Amisias Zahlen übernehmen"], L["Füllt den Satz mit Amisias Gewichten der gerade gewählten Gewichtung auf deiner Stufe, je Punkt, als Startpunkt."])
    local acts = { F.tplLink, F.pasteLink, F.copyLink, F.amisiaLink }
    for _, b in ipairs(acts) do W.FitChip(b) end
    W.Row(F, acts, T.TAB_GAP, pad, WT.ACT_Y)

    F.kindLink = W.Link(F, "", function()
        local class, spec = who()
        ns.Set("bis.kind", ns.NextKind(ns.Get("bis.kind"), Gear.OwnPick(class, spec) ~= nil))   -- l10n-ok: setting key
        refresh()
    end)
    F.kindLink:SetPoint("TOPLEFT", pad, WT.KIND_Y)
    W.Tooltip(F.kindLink, L["Gewichtung"], L["Ein Klick geht reihum: Speedrun, Hardcore, Raid und Eigene (mit einem gewählten Satz)."])
    F.zero = W.Text(F, T.FONT.text, inner - 200)
    F.zero:SetPoint("TOPRIGHT", -pad, WT.KIND_Y - 4)
    F.zero:SetJustifyH("RIGHT")
    F.zero:SetText(ORANGE .. L["Alle Gewichte sind 0."] .. "|r")
    F.zero:Hide()

    F.list = W.List(F, WT.ROWS, WT.ROW_H, buildRow, fillRow)
    F.list:SetPoint("TOPLEFT", pad, WT.LIST_Y)
    F.list:SetWidth(inner - T.SCROLL_ROOM)
    F.empty = W.Text(F, T.FONT.hint, inner, true)
    F.empty:SetPoint("TOPLEFT", pad, WT.LIST_Y - 4)
    F.empty:SetHeight(WT.TEXT_H)
    F.empty:SetJustifyV("TOP")
    F.empty:SetText(L["Noch kein eigener Satz. \"Neu\", \"Vorlage\" oder \"Einfügen\" legt einen an."])

    F.help = W.Text(F, T.FONT.hint, inner, true)
    F.help:SetPoint("BOTTOMLEFT", pad, WT.HELP_Y)
    F.help:SetHeight(WT.TEXT_H)
    F.help:SetJustifyV("TOP")
    F.help:SetText(L["Die Zahl gilt je Punkt, wie er auf dem Item steht: +10 Trefferwertung zählt 10 mal. Leer heißt 0."])
    F.result = W.Text(F, T.FONT.text, inner)
    F.result:SetPoint("BOTTOMLEFT", pad, WT.RESULT_Y)
    F.paste = function() return P end
end

-- Opens the window (the planner's "Optionen" > "Gewichte ...").
function ns.ShowWeights()
    if not F then build() end
    F:Show()
    if F.Raise then F:Raise() end
    refresh()
    return F
end
ns.WeightsOpenPaste = function(mode) if not F then build() end openPaste(mode) return P end

ns.Listen("BIS_CHANGED", function() refresh() end)
ns.Listen("SETTING", function(path)
    if path == "bis.kind" then refresh() end   -- l10n-ok: setting key
end)
end)
