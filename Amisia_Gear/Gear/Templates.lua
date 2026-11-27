-- The planner's templates (F-239, spec docs/specs/2026-11-27-vorlagen.md, ns.GearTemplates): a whole set of own
-- picks (D-55, the spec in use) in one go, from the menu "Vorlagen" of the page "Ausrüstungsplaner":
-- "Leere Plätze füllen" (the targets of the rows without a pick), a plan per level (the best reachable item per row
-- up to that level: ns.BisFor with the own sources, weapon plan, faction, exclusions and weighting; "Pre-Raid (BiS)"
-- the same at the level cap without raids), the known sets of the simulation (GEAR_WEIGHTS.SETS, WoWSims Forever,
-- MIT) and a pasted list (TP.Parse: item links, ids, addresses with "item=12345", whole item names; at most
-- MAX_TEXT characters and MAX_LINES lines). Everything goes through ns.BisSetPicks (one BIS_CHANGED, each item
-- checked as a click on a row checks it); replacing own picks asks first. The window "Liste einfügen"
-- (AmisiaTemplatePaste, tokens T.TEMPLATES) shows a preview before "Übernehmen". Only what the character can wear
-- now and what fits the weapon plan is set (an item above the own level would go unused); the chat line names the
-- rest. Nothing is sent or fetched.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local TT = T.TEMPLATES
local Gear = ns.Gear
local ORANGE, GREY = T.ORANGE, T.GREY

local TP = {}
ns.GearTemplates = TP

TP.LEVELS = { 20, 30, 40, 50, 55 }
TP.MAX_TEXT, TP.MAX_LINES = 8000, 200

local function ownLevel() return math.max(1, math.min(tonumber(UnitLevel("player")) or 1, Gear.Cap())) end

-- The levels of the menu after "Aktuelle Stufe (N)": the fixed ones below the level cap, without the own.
function TP.Levels()
    local out, own = {}, ownLevel()
    for _, lv in ipairs(TP.LEVELS) do
        if lv < Gear.Cap() and lv ~= own then out[#out + 1] = lv end
    end
    return out
end

-- A result of Gear.Best ({ id, score } per option) or ns.BisTargets ({ id = ... }) as a map { [slotKey] = id }:
-- each row's first option; with "2H" no shield hand.
local function mapOf(res, skip)
    local map = {}
    if type(res) ~= "table" then return map end
    for _, sl in ipairs(Gear.SLOTS) do
        local opt = res[sl.key] and res[sl.key][1]
        local id = type(opt) == "table" and (opt.id or opt[1]) or nil
        if type(id) == "number" and not (skip and skip(sl.key)) then map[sl.key] = id end
    end
    if res.plan == "2H" then map.OFFHAND = nil end
    return map
end

-- The plan of a level: the best reachable item per row up to it (preraid: at the level cap, no raid drops), with the
-- own sources, professions, weapon plan, faction, exclusions, weighting and play style. Returns the map and the level.
function TP.Plan(level, preraid)
    local o = ns.BisOpts()
    local src = {}
    for k, v in pairs(o.sources or {}) do src[k] = v end
    if preraid then
        src.X = false
        level = Gear.Cap()
    end
    level = math.max(1, math.min(tonumber(level) or ownLevel(), Gear.Cap()))
    local res = ns.BisFor(o.class, o.spec, level, { sources = src, plan = o.plan, faction = o.faction,
        exclude = o.exclude, kind = o.kind, prof = o.prof, skills = o.skills, style = o.style })
    return mapOf(res), level
end

-- "Leere Plätze füllen": the target of every row without an own pick.
function TP.Fill()
    return mapOf(ns.BisTargets(), function(key) return ns.BisPick(key) ~= nil end)
end

-- The known sets of the own class (GEAR_WEIGHTS.SETS: { { name, spec, items = { [slotKey] = id } } }), the
-- spec in use first; empty without.
function TP.Sets()
    local o = ns.BisOpts()
    local G = ns.GEAR_WEIGHTS
    local list = type(G) == "table" and type(G.SETS) == "table" and G.SETS[o.class]
    if type(list) ~= "table" then return {} end
    local mine, other = {}, {}
    for _, s in ipairs(list) do
        if type(s) == "table" and type(s.items) == "table" and type(s.name) == "string" then
            if s.spec ~= nil and s.spec == o.spec then mine[#mine + 1] = s else other[#other + 1] = s end
        end
    end
    for _, s in ipairs(other) do mine[#mine + 1] = s end
    return mine
end

-- The number of own picks of the spec in use.
function TP.PickCount()
    local c = ns.BisChar()
    local t = c and type(c.pick) == "table" and c.pick[ns.BisSpec() or ""]
    local n = 0
    for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- A pasted list
---------------------------------------------------------------------------

-- the rows an item group fills in turn
local ROWS = { FINGER = { "FINGER1", "FINGER2" }, TRINKET = { "TRINKET1", "TRINKET2" }, ["1H"] = { "MAINHAND", "OFFHAND" } }

-- The item ids a line names by number: links, "item=12345" (or "item/12345"), else a line that is only numbers
-- (after a label "Kopf:").
local function idsOf(line)
    local ids = {}
    for id in line:gmatch("|Hitem:(%d+)") do ids[#ids + 1] = tonumber(id) end
    if #ids > 0 then return ids end
    for id in line:gmatch("item[=/](%d+)") do ids[#ids + 1] = tonumber(id) end
    if #ids > 0 then return ids end
    local rest = line:match("^[^:]*:%s*(.-)%s*$") or line
    if rest:match("^[%d%s,;]+$") then
        for id in rest:gmatch("%d+") do
            local n = tonumber(id)
            if n and n >= 1 and n <= 9999999 then ids[#ids + 1] = n end
        end
    end
    return ids
end

-- The names a line may hold, the likeliest first: in brackets "[Name]", after a label "Kopf:", the parts
-- around " - ", " | ", tabs and "(...)".
local function namesOf(line)
    local out, seen = {}, {}
    local function add(s)
        s = s and s:gsub("^[%s%-%*>#]+", ""):gsub("^\226\128\162%s*", ""):gsub("^%d+[%.%)]%s+", ""):gsub("[%s%.]+$", "")
        if s and #s >= 3 and not seen[s] then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    for s in line:gmatch("%[([^%]]+)%]") do add(s) end
    local rest = line:match("^[^:]+:%s*(.+)$")
    for _, part in ipairs({ rest or false, line }) do
        if part then
            add(part)
            local plain = part:gsub("%b()", "")
            add(plain)
            local cut = plain:gsub("%s+%-%s+", "\t"):gsub("%s+\226\128\147%s+", "\t"):gsub("%s+|%s+", "\t")
            for seg in (cut .. "\t"):gmatch("([^\t]+)\t") do add(seg) end
        end
    end
    return out
end

-- Reads a pasted list for the spec in use, each item checked as a pick (ns.BisCanPick: wearable now, the weapon
-- plan): { map = { [slotKey] = id }, n, unknown = { line }, refused = { { line, id, why } }, pending (names still
-- on their way), cut (more lines than MAX_LINES) }.
function TP.Parse(text)
    text = tostring(text or ""):sub(1, TP.MAX_TEXT)
    local res = { map = {}, n = 0, unknown = {}, refused = {}, pending = false }
    local blocked = {}   -- the shield hand beside a two-hander
    local function place(id, line)
        local group = ns.BisGroup(id)
        local key = group and Gear.CAP_ROW[group]
        if not key then
            res.refused[#res.refused + 1] = { line = line, id = id, why = L["Keine Ausrüstung."] }
            return
        end
        local rows = ROWS[group] or { key }
        local why
        -- the same ring or trinket twice: once
        if #rows == 2 and group ~= "1H" and (res.map[rows[1]] == id or res.map[rows[2]] == id) then
            res.refused[#res.refused + 1] = { line = line, id = id, why = L["Steht schon im anderen Platz."] }
            return
        end
        for _, row in ipairs(rows) do
            if res.map[row] == nil and not blocked[row] then
                local mh = row == "OFFHAND" and res.map.MAINHAND and ns.BisGroup(res.map.MAINHAND) or nil
                local ok, no = ns.BisCanPick(row, id, mh)
                if ok and group == "2H" and res.map.OFFHAND then
                    ok, no = nil, L["Die Schildhand ist schon belegt."]
                end
                if ok then
                    res.map[row] = id
                    res.n = res.n + 1
                    if group == "2H" then blocked.OFFHAND = true end
                    return
                end
                why = why or no
            end
        end
        res.refused[#res.refused + 1] = { line = line, id = id, why = why or L["Der Platz ist schon belegt."] }
    end
    local lines = 0
    for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        if line:find("%S") then
            lines = lines + 1
            if lines > TP.MAX_LINES then
                res.cut = true
                break
            end
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            local ids = idsOf(line)
            if #ids == 0 and ns.Catalog and ns.Catalog.FindName then
                for _, name in ipairs(namesOf(line)) do
                    local found, pending = ns.Catalog.FindName(name)
                    if pending then res.pending = true end
                    if #found == 1 then
                        ids[1] = found[1]
                        break
                    elseif #found > 1 then
                        -- the same name on several items: the first the character can wear in its row
                        for _, id in ipairs(found) do
                            local g = ns.BisGroup(id)
                            local row = g and ((ROWS[g] or {})[1] or Gear.CAP_ROW[g])
                            if row and ns.BisCanPick(row, id) then ids[1] = id break end
                        end
                        if ids[1] then break end
                    end
                end
            end
            if #ids == 0 then
                res.unknown[#res.unknown + 1] = line
            else
                for _, id in ipairs(ids) do place(id, line) end
            end
        end
    end
    return res
end

---------------------------------------------------------------------------
-- Applying
---------------------------------------------------------------------------

local function slotName(key) return ns.BIS_SLOT_NAME and ns.BIS_SLOT_NAME[key] or key end

local function itemText(id)
    local K = ns.GearPageKit
    return K and K.itemText(id) or ("Item " .. id)
end

-- Sets map as the own picks (replace: the others go too), asking first when own picks would be replaced; the chat
-- line says how many were set, then names up to three that did not fit with the reason. label: the template's name.
function TP.Apply(map, replace, label)
    if not next(map) then
        ns.msg(replace and L["Vorlage \"%s\": kein Item für deine Plätze."]:format(label) or L["Kein Platz ohne eigene Wahl."])
        return
    end
    local function go()
        local n, refused = ns.BisSetPicks(map, replace)
        if not n then
            ns.msg(tostring(refused))
            return
        end
        local text = n > 0 and L["Vorlage \"%s\": %d Plätze gesetzt."]:format(label, n)
            or L["Vorlage \"%s\": nichts gesetzt, deine Wahlen bleiben."]:format(label)
        if #refused > 0 then
            local names = {}
            for i = 1, math.min(3, #refused) do
                local r = refused[i]
                names[#names + 1] = ("%s %s (%s)"):format(slotName(r.slot), itemText(r.id), tostring(r.why))
            end
            if #refused > 3 then names[#names + 1] = L["%d weitere"]:format(#refused - 3) end
            text = text .. " " .. ORANGE .. L["Passt nicht: %s"]:format(table.concat(names, ", ")) .. "|r"
        end
        ns.msg(text)
    end
    local have = TP.PickCount()
    if replace and have > 0 then
        W.Confirm(L["Vorlage übernehmen"], L["%d eigene Wahlen durch \"%s\" ersetzen?"]:format(have, label), L["Ersetzen"], go)
    else
        go()
    end
end

---------------------------------------------------------------------------
-- The window "Liste einfügen"
---------------------------------------------------------------------------

local P, parsed

-- The preview: "14 erkannt" with the item per row, then what was not taken and why.
local function preview()
    if not P then return end
    local text = P.area.box:GetText() or ""
    if not text:find("%S") then
        parsed = nil
        P.preview:SetText(GREY .. L["Noch nichts eingefügt."] .. "|r")
        P.apply:SetEnabled(false)
        return
    end
    parsed = TP.Parse(text)
    local lines = { L["%d erkannt, %d nicht erkannt"]:format(parsed.n, #parsed.unknown + #parsed.refused) }
    for _, sl in ipairs(Gear.SLOTS) do
        local id = parsed.map[sl.key]
        if id then lines[#lines + 1] = GREY .. slotName(sl.key) .. ":|r " .. itemText(id) end
    end
    for _, r in ipairs(parsed.refused) do
        lines[#lines + 1] = ORANGE .. itemText(r.id) .. ": " .. tostring(r.why) .. "|r"
    end
    for _, line in ipairs(parsed.unknown) do
        lines[#lines + 1] = ORANGE .. L["unbekannt: %s"]:format(line:sub(1, 60)) .. "|r"
    end
    if parsed.cut then lines[#lines + 1] = ORANGE .. L["Nur die ersten %d Zeilen gelesen."]:format(TP.MAX_LINES) .. "|r" end
    if parsed.pending then lines[#lines + 1] = GREY .. L["Einige Itemnamen kommen noch vom Server ..."] .. "|r" end
    P.preview:SetText(table.concat(lines, "\n"))
    P.apply:SetEnabled(parsed.n > 0)
    -- names still on their way: read again once they are here, five times at most for one text
    if parsed.pending and not P.again and (P.tries or 0) < 5 then
        P.tries = (P.tries or 0) + 1
        P.again = true
        C_Timer.After(1, function()
            P.again = nil
            if P:IsShown() then preview() end
        end)
    end
end

local function schedulePreview()
    P.tries = 0
    P.typed = (P.typed or 0) + 1
    local mine = P.typed
    C_Timer.After(0.3, function() if P.typed == mine then preview() end end)
end

local function buildPaste()
    P = W.Window("AmisiaTemplatePaste", TT.PASTE_W, TT.PASTE_H, { title = L["Liste einfügen"], strata = "FULLSCREEN_DIALOG" })
    P:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    local pad, inner = T.WINDOW_PAD, TT.PASTE_W - 2 * T.WINDOW_PAD
    P.hint = W.Text(P, T.FONT.text, inner, true)
    P.hint:SetPoint("TOPLEFT", pad, TT.HINT_Y)
    P.hint:SetHeight(TT.HINT_H)
    P.hint:SetJustifyV("TOP")
    P.hint:SetText(L["Eine BiS-Liste aus Discord, Icy Veins oder Wowhead einfügen: Item-Links, Item-IDs, Adressen mit item=12345 oder Itemnamen, eine Zeile je Item."])
    P.area = W.EditArea(P)
    P.area:SetPoint("TOPLEFT", pad, TT.BOX_Y)
    P.area:SetSize(inner, TT.BOX_H)
    P.area.box:SetMaxLetters(TP.MAX_TEXT)
    P.area.box:SetScript("OnTextChanged", function(_, user) if user then schedulePreview() end end)
    P.preview = W.Text(P, T.FONT.text, inner, true)
    P.preview:SetPoint("TOPLEFT", pad, TT.PREVIEW_Y)
    P.preview:SetHeight(TT.PREVIEW_H)
    P.preview:SetJustifyV("TOP")
    P.preview:SetMaxLines(TT.PREVIEW_LINES)
    P.apply = W.Button(P, L["Übernehmen"], TT.BUTTON_W, function()
        preview()
        if not (parsed and parsed.n > 0) then return end
        P:Hide()
        TP.Apply(parsed.map, true, L["Eingefügte Liste"])
    end)
    W.FitChip(P.apply, TT.BUTTON_W)
    P.apply:SetPoint("BOTTOMLEFT", pad, TT.BUTTON_Y)
    P.close = W.Link(P, L["Abbrechen"], function() P:Hide() end)
    P.close:SetPoint("LEFT", P.apply, "RIGHT", T.LAYOUT.ITEM_GAP, 0)
end

-- Opens the window with an empty box.
function TP.OpenPaste()
    if not P then buildPaste() end
    P.area.box:SetText("")
    parsed, P.tries = nil, 0
    preview()
    P:Show()
    if P.Raise then P:Raise() end
    P.area.box:SetFocus()
end

-- Test hooks.
function TP._paste() return P end
function TP._preview() preview() end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

-- The entries of the menu "Vorlagen" for W.Menu.
function TP.MenuEntries()
    local out = {}
    out[#out + 1] = { L["Leere Plätze füllen"], function() TP.Apply(TP.Fill(), false, L["Leere Plätze füllen"]) end,
        tip = L["Jeder Platz ohne eigene Wahl bekommt, was Amisia dort gerade vorschlägt. Deine Wahlen bleiben."] }
    out[#out + 1] = { L["Plan erstellen"], head = true }
    local own = ownLevel()
    local function plan(label, level, preraid)
        out[#out + 1] = { label, function()
            TP.Apply((TP.Plan(level, preraid)), true, label)
        end, tip = preraid and L["Das beste erreichbare Item je Platz auf Stufe 60 ohne Raid-Drops, mit deinen Quellen und deinem Waffenplan."]
            or L["Das beste erreichbare Item je Platz bis zu dieser Stufe, mit deinen Quellen und deinem Waffenplan."] }
    end
    plan(L["Aktuelle Stufe (%d)"]:format(own), own)
    for _, lv in ipairs(TP.Levels()) do plan(L["Stufe %d##Vorlage"]:format(lv), lv) end
    plan(L["Pre-Raid (BiS)"], Gear.Cap(), true)
    local sets = TP.Sets()
    if #sets > 0 then
        out[#out + 1] = { L["Bekannte Sets"], head = true }
        for _, s in ipairs(sets) do
            local label = L["WoWSims Forever: %s"]:format(L[s.name])
            out[#out + 1] = { label, function() TP.Apply(s.items, true, label) end,
                tip = L["Ein Set aus der WoWSims-Simulation für Forever (MIT). Wird zu deinen Wahlen; du kannst danach jeden Platz ändern."] }
        end
    end
    out[#out + 1] = { L["Liste einfügen ..."], function() TP.OpenPaste() end,
        tip = L["Eine BiS-Liste aus Discord, Icy Veins oder Wowhead hineinkopieren; vor dem Übernehmen eine Vorschau."] }
    return out
end

end)
