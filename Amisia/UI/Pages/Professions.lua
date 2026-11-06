-- Professions page: the recipes of one profession in the colours of the client's recipe list (the
-- own rank decides), filtered by name, known/unknown, learnable and source; the chosen recipe in
-- the detail field (what it makes with the upgrade mark, the four difficulty steps, reagents with
-- the own count, where it comes from, Merchant's Favor and crafting orders, who of the guild makes it
-- (Crafters.lua) with a button that asks one of them by whisper). Two more views in the profession
-- picker: the camp objects ("Lager") and the Merchant's Favor ("Händlergunst"). The filters: two
-- dropdowns that name themselves ("Bekannt: Alle", "Quelle: Händler"), the chips Lernbar and
-- Gilde (with the guild's count), "N von M Rezepten"; an empty result names what each filter holds
-- back and offers "Filter zurücksetzen". Beside the profession the switch "Rezepte | Route" (F-137):
-- the route of Gear/ProfRoute.lua as step cards (the current one marked, done ones ticked and
-- short) or its shopping list ("Schritte | Einkauf"), recipes "nur Lehrer | auch Händler".
local ADDON, ns = ...
local L = ns.L
local W, Pr, T, Cr, Route = ns.W, ns.Prof, ns.Theme, ns.Crafters, ns.ProfRoute
local P = T.PROFPAGE
local GREY = T.GREY
local GREEN = "|cff40bf40"
local ICON = "Interface\\Icons\\Trade_BlackSmithing"
local ROWS, ROW_H = 17, 22
local GUILD_W = T.CHIP_W   -- the chip Gilde at least (it carries its count)
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
-- the dropdowns' entries (W.Picker); the field shows "<filter>: <entry>", SHORT where it differs
local SOURCES = { { value = "all", text = L["Alle Quellen"] }, { value = "T", text = L["Lehrer"] },
    { value = "V", text = L["Händler"] }, { value = "F", text = L["Händlergunst"] }, { value = "D", text = "Drop" },
    { value = "Q", text = "Quest" } }
local KNOWN = { { value = "all", text = L["Alle"] }, { value = "known", text = L["Bekannt"] },
    { value = "unknown", text = L["Unbekannt"] } }
local SHORT = { all = L["Alle"] }
local CAMP, FAVOR = "camp", "favor"
local RECIPES, ROUTE = "recipes", "route"   -- settings.professions.mode
local ROW_HINT = L["Klick: Details. Shift-Klick: Link in den Chat."]

local page
local nameMissing = false

local function state()
    local s = AmisiaDB.settings
    s.professions = type(s.professions) == "table" and s.professions or {}
    local t = s.professions
    t.sel = type(t.sel) == "table" and t.sel or {}
    return t
end

local function color(c, text) return ("|c%s%s|r"):format(c, text) end

local function itemText(id, fallback)
    local name, q = Pr.ItemInfo(id)
    if not name then nameMissing = true end
    return color(QUALITY[q or 1] or QUALITY[1], name or fallback or ("Item " .. tostring(id)))
end

-- The shown view: a skill line, CAMP or FAVOR. Default: the first own profession, else the first.
local function view()
    local v = state().view
    if v == CAMP or v == FAVOR then return v end
    v = tonumber(v)
    if v and Pr.Key(v) then return v end
    return Pr.Ordered()[1]
end

local function wearable(id)
    local f = C_Item and C_Item.GetItemInfoInstant
    if type(f) ~= "function" then return false end
    local ok, _, _, _, loc = pcall(f, id)
    loc = ok and ns.Plain(loc) or nil
    return type(loc) == "string" and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP_IGNORE" and loc ~= "INVTYPE_NON_EQUIP"
        and loc ~= "INVTYPE_BAG"
end

-- The upgrade mark of what a recipe makes, as on the other pages ("+12%", "neu", "ab 30").
local function upgradeMark(item)
    if not item or item <= 0 or not wearable(item) or not ns.UpgradeOf then return nil end
    local ok, u = pcall(ns.UpgradeOf, item)
    if not ok or type(u) ~= "table" then return nil end
    local short = ns.UpgradeShort and ns.UpgradeShort(u)
    if not short then return nil end
    return u.up and (GREEN .. short .. "|r") or (GREY .. short .. "|r"), u
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local function listOf(v)
    local s = state()
    if v == CAMP then
        local out = {}
        for _, c in ipairs(Pr.Camp()) do out[#out + 1] = { camp = c } end
        return out
    elseif v == FAVOR then
        local fav = Pr.Favor()
        local out, ranks = {}, {}
        for _, p in ipairs(Pr.Own()) do ranks[p.skill] = p.rank end
        for _, e in ipairs(fav and fav.recipes or {}) do
            local r = e.recipe
            local known = Pr.Known(r.spell, r.skill)
            out[#out + 1] = { recipe = r, name = Pr.RecipeName(r), known = known, price = e.price, standing = e.standing,
                color = Pr.Difficulty(r, ranks[r.skill], known) }
        end
        return out
    end
    return Pr.List(v, { search = s.search, known = s.known ~= "all" and s.known or nil, learnable = s.learnable,
        source = s.source ~= "all" and s.source or nil, guild = s.guild })
end

-- The filters that are on, each with its name as the head row shows it and the field it clears.
local function entryText(values, v)
    for _, e in ipairs(values) do if e.value == v then return e.text end end
    return tostring(v)
end

local function activeFilters()
    local s, out = state(), {}
    if s.search and s.search ~= "" then out[#out + 1] = { key = "search", name = L["Suche: %s"]:format(s.search) } end
    if s.known and s.known ~= "all" then out[#out + 1] = { key = "known", name = entryText(KNOWN, s.known) } end
    if s.source and s.source ~= "all" then
        out[#out + 1] = { key = "source", name = L["Quelle: %s"]:format(entryText(SOURCES, s.source)) }
    end
    if s.learnable then out[#out + 1] = { key = "learnable", name = L["Lernbar"] } end
    if s.guild then out[#out + 1] = { key = "guild", name = L["Gilde"] } end
    return out
end

local function recipesText(n)
    return n == 1 and L["1 Rezept"] or L["%d Rezepte"]:format(n)
end

-- The help of an empty recipe list: for each filter that is on and whose removal alone brings
-- recipes back, how many; when no single filter does, how many the list shows without all of them.
-- The second value: a filter is on (the reset button shows).
local function emptyHelp(v)
    local filters = activeFilters()
    if #filters == 0 then return L["Keine Rezepte zu diesen Filtern."], false end
    local s = state()
    local parts = {}
    for _, flt in ipairs(filters) do
        local keep = s[flt.key]
        s[flt.key] = nil
        local n = #listOf(v)
        s[flt.key] = keep
        if n > 0 then parts[#parts + 1] = L["Ohne \"%s\": %s"]:format(flt.name, recipesText(n)) end
    end
    if #parts == 0 then
        local keep = {}
        for _, flt in ipairs(filters) do keep[flt.key], s[flt.key] = s[flt.key], nil end
        local n = #listOf(v)
        for k, val in pairs(keep) do s[k] = val end
        parts[1] = L["Erst ohne alle Filter: %s"]:format(recipesText(n))
    end
    return L["Keine Rezepte zu diesen Filtern."] .. "\n" .. table.concat(parts, "\n"), true
end

-- How many recipes of the profession someone of the guild shares (what the chip Gilde alone shows).
local function guildCount(v)
    local has = ns.Crafters and ns.Crafters.Has
    if not has then return 0 end
    local n = 0
    for _, r in ipairs(Pr.Recipes(v)) do
        if has(r.spell) then n = n + 1 end
    end
    return n
end

local function resetFilters()
    local s = state()
    s.known, s.source, s.learnable, s.guild, s.search = nil, nil, nil, nil, nil
    if page and page.search then
        page.search:SetText("")
        page.search:ClearFocus()
    end
    ns.Refresh()
end

local function campName(c)
    local name = Pr.ItemInfo(c.item)
    if not name then
        nameMissing = true
        name = Pr.SpellName(c.recipe) or ("Item " .. c.item)
    end
    return name
end

local function fillRow(r, e)
    r.sel:SetShown(page and page.selected == e)
    if e.camp then
        local c = e.camp
        local rank = c.skill > 0 and Pr.Rank(c.skill) or nil
        local col = (rank and rank >= c.rank) and Pr.COLORS.green or (rank and Pr.COLORS.red) or Pr.COLORS.none
        r.name:SetText(color(col, campName(c)))
        r.mark:SetText(c.slots > 0 and (GREY .. L["%d Pl."]:format(c.slots) .. "|r") or "")
        r.rank:SetText(c.skill > 0 and (GREY .. c.rank .. "|r") or "")
        return
    end
    local rec = e.recipe
    local col = Pr.COLORS[e.color] or Pr.COLORS.none
    local name = e.name
    if e.known == true then name = name .. " " .. GREY .. L["(bekannt)"] .. "|r" end
    r.name:SetText(color(col, name))
    r.mark:SetText(upgradeMark(rec.item) or "")
    if e.price then
        r.rank:SetText(GREY .. e.price .. "|r")
    else
        r.rank:SetText(GREY .. (rec.learn > 1 and rec.learn or rec.yellow) .. "|r")
    end
end

---------------------------------------------------------------------------
-- The detail field
---------------------------------------------------------------------------
local function steps(r)
    return ("%s / %s / %s / %s"):format(color(Pr.COLORS.orange, r.learn > 1 and r.learn or 1), color(Pr.COLORS.yellow, r.yellow),
        color(Pr.COLORS.green, r.green), color(Pr.COLORS.grey, r.grey))
end

local function reagentLines(r)
    local list, from = Pr.Reagents(r.spell)
    if not list then return { GREY .. L["Reagenzien: noch unbekannt (Client antwortet nicht)"] .. "|r" } end
    local out = { L["Reagenzien:"] }
    for _, e in ipairs(list) do
        local have = Pr.Count(e[1])
        local mark = have >= e[2] and GREEN or "|cffff6060"
        out[#out + 1] = ("  %dx %s %s(%d)|r"):format(e[2], itemText(e[1]), mark, have)
    end
    if from == "client" then out[#out + 1] = GREY .. "  " .. L["(aus dem Client)"] .. "|r" end
    return out
end

local function recipeDetail(r)
    local lines = {}
    local rank = Pr.Rank(r.skill)
    local known = Pr.Known(r.spell, r.skill)
    lines[#lines + 1] = L["%s · Fertigkeit %s"]:format(Pr.Name(r.skill), steps(r))
    if rank then
        local d = Pr.Difficulty(r, rank, known)
        local word = ({ orange = L["orange"], yellow = L["gelb"], green = L["grün"], grey = L["grau"], red = L["noch nicht lernbar"] })[d]
        lines[#lines + 1] = L["Dein Rang %d%s"]:format(rank, word and (": " .. color(Pr.COLORS[d], word)) or "")
    end
    if known == true then
        lines[#lines + 1] = GREEN .. L["Bekannt"] .. "|r"
    elseif known == false then
        local from = Pr.LearnRank(r)
        lines[#lines + 1] = L["Nicht bekannt"] .. (from > 1 and L[" (lernbar ab %d)"]:format(from) or "")
    elseif rank then
        lines[#lines + 1] = GREY .. L["Ob bekannt: Berufsfenster einmal öffnen."] .. "|r"
    end
    local makers = Cr.ForSpell(r.spell)
    lines[#lines + 1] = #makers > 0 and L["Hergestellt von: %s"]:format(Cr.Text(makers, 6, true))
        or (GREY .. L["Hergestellt von: niemand aus der Gilde bekannt"] .. "|r")
    if r.count > 1 then lines[#lines + 1] = L["Stellt %d Stück her."]:format(r.count) end
    lines[#lines + 1] = ""
    for _, l in ipairs(reagentLines(r)) do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Quelle:"]
    local src = Pr.Sources(r)
    for _, s in ipairs(src) do lines[#lines + 1] = "  " .. s.text end
    for _, itemId in ipairs(r.items) do
        local ri = Pr.RecipeItem(itemId)
        if ri then
            local need = {}
            if ri.rank > 0 then need[#need + 1] = L["Rang %d"]:format(ri.rank) end
            if ri.faction > 0 then need[#need + 1] = L["Ruf %s"]:format(Pr.STANDING[ri.standing] or "?") end
            lines[#lines + 1] = L["  Rezept: %s%s"]:format(itemText(itemId), #need > 0 and (GREY .. " (" .. table.concat(need, ", ") .. ")|r") or "")
        end
    end
    if Pr.HasWrit(r) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = L["Handwerksauftrag für dieses Item möglich (Händlergunst)."]
    end
    return table.concat(lines, "\n"), src
end

local function campDetail(c)
    local lines = {}
    if c.skill > 0 then
        local rank = Pr.Rank(c.skill)
        lines[#lines + 1] = L["%s · ab Rang %d%s"]:format(Pr.Name(c.skill), c.rank, rank and L[" (dein Rang %d)"]:format(rank) or "")
    end
    if c.slots > 0 then lines[#lines + 1] = L["Lagerfeuer mit %d Plätzen für weitere Lagerobjekte."]:format(c.slots) end
    if c.over > 0 then
        local other
        for _, o in ipairs(Pr.Camp()) do if o.item == c.over then other = o end end
        lines[#lines + 1] = L["Ersetzt %s und behält dessen Wirkung."]:format(other and campName(other) or ("Item " .. c.over))
    end
    lines[#lines + 1] = ""
    local desc, loading = Pr.SpellDescription(c.use)
    -- the text comes when the client has loaded the spell (PROF_SPELL_LOADED redraws the page)
    lines[#lines + 1] = desc or (GREY .. (loading and L["Beschreibung lädt ..."] or L["Keine Beschreibung vom Client."]) .. "|r")
    local r = c.recipe > 0 and Pr.Recipe(c.recipe)
    local src = {}
    if r then
        lines[#lines + 1] = ""
        lines[#lines + 1] = L["Herstellen: %s"]:format(steps(r))
        for _, l in ipairs(reagentLines(r)) do lines[#lines + 1] = l end
        lines[#lines + 1] = L["Quelle:"]
        src = Pr.Sources(r)
        for _, s in ipairs(src) do lines[#lines + 1] = "  " .. s.text end
    end
    return table.concat(lines, "\n"), src
end

local function showDetail(f, e)
    local d = f.detail
    d.entry = e
    if not e then
        d.icon:Hide()
        d.title:SetText("")
        d.sub:SetText("")
        d.body:SetText(GREY .. L["Ein Rezept wählen."] .. "|r")
        d.go:Disable()
        d.ask:Disable()
        return
    end
    local item, body, src, sub
    if e.camp then
        item = e.camp.item
        d.title:SetText(itemText(item, campName(e.camp)))
        body, src = campDetail(e.camp)
        sub = ""
    else
        local r = e.recipe
        item = r.item
        if item > 0 then
            d.title:SetText(itemText(item, e.name))
        else
            d.title:SetText(color(Pr.COLORS.none, e.name))
        end
        local mark, u = upgradeMark(item)
        sub = mark and (L["Upgrade: %s"]:format(mark) .. (u and u.slotKey and (GREY .. " (" .. tostring(u.slotKey) .. ")|r") or "")) or ""
        body, src = recipeDetail(r)
    end
    local icon = item and item > 0 and C_Item and C_Item.GetItemIconByID and ns.Plain(C_Item.GetItemIconByID(item)) or nil
    if icon then
        d.icon:SetTexture(icon)
        d.icon:Show()
    else
        d.icon:Hide()
    end
    d.sub:SetText(sub)
    d.body:SetText(body)
    d.point = nil
    for _, s in ipairs(src or {}) do
        if s.point then
            d.point, d.pointLabel = s.point, s.text
            break
        end
    end
    if d.point then d.go:Enable() else d.go:Disable() end
    -- the crafter to ask: online first, never an own character
    d.askWho = (not e.camp) and Cr.AskWhom(e.recipe.spell) or nil
    if d.askWho then d.ask:Enable() else d.ask:Disable() end
end

---------------------------------------------------------------------------
-- The route (F-137): steps and shopping list
---------------------------------------------------------------------------
local COLOR_WORDS = { orange = L["orange"], yellow = L["gelb"], green = L["grün"], grey = L["grau"],
    red = L["noch nicht lernbar"] }

local function mode() return state().mode == ROUTE and ROUTE or RECIPES end
local function routeShown(v) return mode() == ROUTE and type(v) == "number" and Route.Has(v) end
local function money(c) return Pr.Money(math.floor((c or 0) + 0.5)) end
local function times(n) return math.max(0, math.ceil((n or 0) - 1e-6)) end
local function colorWord(c) return color(Pr.COLORS[c] or Pr.COLORS.none, COLOR_WORDS[c] or "?") end

local function itemName(id)
    local name = Pr.ItemInfo(id)
    if not name then nameMissing = true end
    return name or ("Item " .. tostring(id))
end

-- The vendor of a list nearest to the player with a known place (and that place), else the first.
local function nearestVendor(vendors)
    local points, owner = {}, {}
    for _, npc in ipairs(vendors or {}) do
        if npc.point then
            points[#points + 1] = npc.point
            owner[npc.point] = npc
        end
    end
    local point = ns.MapNearest and ns.MapNearest(points) or points[1]
    return point and owner[point] or (vendors and vendors[1]), point
end

-- The waypoint to the nearest vendor (Map: the client's waypoint only where D-62 allows it).
local function goToVendor(vendors, what)
    local npc, point = nearestVendor(vendors)
    if not point then
        ns.msg(L["Kein Händler mit bekanntem Ort für %s."]:format(what))
        return
    end
    if ns.MapSetPoint then
        local ok, why = ns.MapSetPoint(point, npc and npc.name or what)
        if not ok and why then ns.msg(why) end
    end
end

-- The reagents of one craft as "2 Leinenstoff, 1 Grobes Garn".
local function perPiece(r)
    local parts = {}
    for _, g in ipairs(Pr.Reagents(r.spell) or {}) do parts[#parts + 1] = ("%d %s"):format(g[2], itemName(g[1])) end
    return table.concat(parts, ", ")
end

local function stepCost(s)
    if s.kind == "trainer" then return s.cost and money(s.cost) or "" end
    if s.kind == "buy" then return money(s.price) end
    if s.kind ~= "recipe" then return "" end
    if s.unpriced > 0 then return s.cost >= 1 and (money(s.cost) .. " + ?") or "?" end
    return money(s.cost)
end

-- A step's two lines: what to do, and the expected crafts with the reagents (the third value: the
-- second line without the reagents, when they do not fit).
local function stepLines(s)
    if s.kind == "trainer" then
        return L["Bei %d: zum Lehrer, %s lernen (bis %d)"]:format(s.at, s.name or L["nächste Stufe"], s.cap), ""
    elseif s.kind == "buy" then
        local npc = nearestVendor(s.vendors)
        local text = L["Rezept kaufen: %s"]:format(itemName(s.item))
        if npc and npc.name then text = text .. L[" bei %s"]:format(npc.name) end
        return text, (npc and npc.point) and L["Klick: Wegpunkt zum Händler"] or L["Ort des Händlers unbekannt"]
    elseif s.kind == "gap" then
        return ("%d-%d: %s"):format(s.from, s.to, s.why == "noreagents" and L["kein Rezept mit bekannten Reagenzien"]
            or s.why == "low" and L["nur Rezepte, die kaum noch Punkte geben"] or L["kein Rezept, das noch Punkte gibt"]), ""
    end
    local line1 = L["%d-%d: %dx %s"]:format(s.from, s.to, s.points, Pr.RecipeName(s.recipe))
    if not s.done then line1 = line1 .. " (" .. colorWord(s.colorFrom) .. L[" bis "] .. colorWord(s.colorTo) .. ")" end
    local head = { L["etwa %dx"]:format(times(s.crafts)) }
    if s.pre then
        local pre = L["davor %dx %s"]:format(times(s.preCrafts), Pr.RecipeName(s.pre))
        if not s.preKnown then pre = pre .. " (" .. L["noch lernen"] .. ")" end
        head[#head + 1] = pre
    end
    if not s.known then head[#head + 1] = s.learnCost > 0 and L["lernen: %s"]:format(money(s.learnCost)) or L["noch lernen"] end
    local short = table.concat(head, " · ")
    return line1, short .. " · " .. L["je Stück: %s"]:format(perPiece(s.recipe)), short
end

local function fillStep(r, s, i)
    r.sel:SetShown(page ~= nil and page.routeCur == i)
    r.tick:SetShown(s.done == true)
    local line1, line2, short = stepLines(s)
    if s.done then
        r.line1:SetText(GREY .. line1 .. "|r")
        r.line2:SetText("")
        r.cost:SetText("")
        return
    end
    r.line1:SetText(line1)
    r.line2:SetText(line2)
    if short and (r.line2:GetStringWidth() or 0) > (r.line2:GetWidth() or 0) then r.line2:SetText(short) end
    r.cost:SetText(stepCost(s))
end

local function stepTooltip(owner, s)
    if not s or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if s.kind == "recipe" then
        local rc = s.recipe
        GameTooltip:SetText(Pr.RecipeName(rc))
        GameTooltip:AddLine(L["orange bis %d, gelb bis %d, grün bis %d, danach grau"]:format(rc.yellow, rc.green, rc.grey), 1, 1, 1, true)
        GameTooltip:AddLine(s.unpriced > 0 and L["Gewählt: die geringsten Kosten je Punkt bei Rang %d, Materialien ohne Händlerpreis geschätzt."]:format(s.chosenAt)
            or L["Gewählt: der billigste Punkt bei Rang %d."]:format(s.chosenAt), 1, 1, 1, true)
        GameTooltip:AddLine(L["Je Stück: %s"]:format(perPiece(rc)), 1, 1, 1, true)
        if rc.count > 1 then GameTooltip:AddLine(L["Stellt %d Stück her."]:format(rc.count), 1, 1, 1) end
        if s.pre then
            GameTooltip:AddLine(L["Davor etwa %dx %s (je Stück: %s), zählt mit, solange es Punkte gibt."]:format(times(s.preCrafts),
                Pr.RecipeName(s.pre), perPiece(s.pre)), 1, 1, 1, true)
            if not s.preKnown then GameTooltip:AddLine(L["%s noch lernen."]:format(Pr.RecipeName(s.pre)), 1, 1, 1, true) end
        end
        if s.known then
            GameTooltip:AddLine(L["Bekannt"], 0.25, 0.75, 0.25)
        elseif s.learnCost > 0 then
            GameTooltip:AddLine(L["Beim Lehrer lernen: %s"]:format(money(s.learnCost)), 1, 1, 1)
        else
            GameTooltip:AddLine(L["Noch nicht bekannt: beim Lehrer oder Händler lernen."], 1, 1, 1, true)
        end
        if s.unpriced > 0 then GameTooltip:AddLine(L["Materialien ohne Händlerpreis zählen nicht zu den Kosten."], 0.6, 0.6, 0.6, true) end
        GameTooltip:AddLine(L["Klick: die Rezept-Details."], 0.6, 0.6, 0.6)
    elseif s.kind == "trainer" then
        GameTooltip:SetText(L["Zum Lehrer"])
        GameTooltip:AddLine(s.cost and L["Lernkosten: %s"]:format(money(s.cost)) or L["Lernkosten: unbekannt"], 1, 1, 1)
    elseif s.kind == "buy" then
        GameTooltip:SetText(L["Rezept kaufen: %s"]:format(itemName(s.item)))
        GameTooltip:AddLine(L["Preis: %s"]:format(money(s.price)), 1, 1, 1)
        for _, npc in ipairs(s.vendors or {}) do
            local where = npc.point and ("%s %d, %d"):format(Pr.ZoneName(npc.point.map) or "?", math.floor(npc.point.x * 100 + 0.5),
                math.floor(npc.point.y * 100 + 0.5)) or (npc.zone and Pr.ZoneName(npc.zone)) or L["unbekannt"]
            GameTooltip:AddLine(("%s: %s"):format(npc.name or ("NPC " .. tostring(npc.id)), where), 1, 1, 1)
        end
    else
        GameTooltip:SetText(L["Keine Punkte"])
        GameTooltip:AddLine(s.why == "noreagents" and L["Die Rezepte für diese Ränge haben keine bekannten Reagenzien."]
            or s.why == "low" and L["Die erlaubten Rezepte sind hier fast grau: seltener als jedes vierte Mal ein Punkt. Mit \"auch Händler\" kommen Händlerrezepte dazu."]
            or L["Kein erlaubtes Rezept gibt hier noch Punkte. Mit \"auch Händler\" kommen Händlerrezepte dazu."], 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function clickStep(s)
    if not s or s.done then return end
    if s.kind == "recipe" then
        state().mode = RECIPES
        if ns.ShowRecipe then ns.ShowRecipe(s.recipe.skill, s.recipe.spell) end
    elseif s.kind == "buy" then
        goToVendor(s.vendors, itemName(s.item))
    end
end

local SOURCE_TEXT = { vendor = L["Händler"], vendorx = L["Händler (Ort unbekannt)"], smelt = L["Bergbau: verhütten"],
    mine = L["sammeln: Bergbau"],
    disenchant = L["entzaubern"], farm = L["farmen oder Auktionshaus"] }
local function sourceText(e)
    if e.kind == "craft" then return L["herstellen: %s"]:format(Pr.Name(e.from)) end
    return SOURCE_TEXT[e.kind] or SOURCE_TEXT.farm
end

local function fillShop(r, e)
    local c, e2 = "", ""
    if e.enough then c, e2 = GREEN, "|r" end
    r.name:SetText(c .. itemName(e.item) .. e2)
    r.need:SetText(c .. e.need .. e2)
    r.have:SetText(c .. e.have .. e2)
    r.twinks:SetText(e.twinks > 0 and tostring(e.twinks) or (GREY .. "0|r"))
    r.miss:SetText(e.missing > 0 and (T.RED .. e.missing .. "|r") or (GREY .. "0|r"))
    r.price:SetText(e.price and money(e.price) or (GREY .. "-|r"))
    r.src:SetText(sourceText(e))
end

local function shopTooltip(owner, e)
    if not e or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.item) else GameTooltip:SetText(itemName(e.item)) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Bedarf %d, hast %d, bei Twinks %d, fehlt %d"]:format(e.need, e.have, e.twinks, e.missing), 1, 1, 1)
    GameTooltip:AddLine(sourceText(e), 1, 1, 1)
    if e.kind == "vendor" then GameTooltip:AddLine(L["Klick: Wegpunkt zum nächsten Händler."], 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

-- The head, the note under it and the lists of the route view.
local function refreshRoute(f, v)
    local s = state()
    local vendor = s.routeVendor and true or false
    f.vendorT:SetOn(not vendor)
    f.vendorV:SetOn(vendor)
    local tab = s.routeTab == "shop" and "shop" or "steps"
    f.tabSteps:SetOn(tab == "steps")
    f.tabShop:SetOn(tab == "shop")
    nameMissing = false
    local route, stale = Route.Get(v, vendor)
    f.route = route
    local notes = {}
    if stale then notes[#notes + 1] = L["Im Kampf und in der Sperre rechnet Amisia die Route erst danach neu."] end
    if not route then
        f.routeHead:SetText(L["Route: noch nicht berechnet."])
        f.steps:SetItems({})
        f.shop:SetItems({})
    else
        local open = 0
        for _, st in ipairs(route.steps) do if not st.done then open = open + 1 end end
        -- without a single price (no vendor sells the materials) the cost is unknown, not 0
        local cost = route.total > 0 and L["etwa %s"]:format(money(route.total)) or L["Kosten unbekannt"]
        if route.learned then
            f.routeHead:SetText(L["Rang %d bis %d · %s · %d Schritte"]:format(route.start, route.top, cost, open))
        else
            f.routeHead:SetText(L["Nicht erlernt, Vorschau ab Rang 1 bis %d · %s · %d Schritte"]:format(route.top, cost, open))
        end
        if route.overTop then
            notes[#notes + 1] = L["Rang %d liegt über dem bekannten Höchstrang: Berufsfenster öffnen, dann rechnet die Route weiter."]
                :format(route.start)
        elseif route.levelCap then
            notes[#notes + 1] = L["Höchstwert für deine Stufe: %d."]:format(route.levelCap)
        elseif route.learned and route.start >= route.top then
            notes[#notes + 1] = L["Höchstrang erreicht."]
        end
        if route.learned and not route.maxKnown then
            notes[#notes + 1] = L["Lehrer-Limit unbekannt, Berufsfenster öffnen."]
        elseif route.learned and not Pr.HasSnapshot(v) then
            notes[#notes + 1] = L["Berufsfenster einmal öffnen, dann stimmt der Rang."]
        end
        if route.unknown then
            notes[#notes + 1] = L["Materialien ohne Händlerpreis wählt die Route nach einem Schätzwert, zu den Kosten zählen sie nicht."]
        end
        local cur = Route.Current(route)
        if cur ~= f.routeCur or f.routeSkill ~= v then f.steps.offset = math.max(0, (cur or 1) - 2) end
        f.routeCur, f.routeSkill = cur, v
        f.steps:SetItems(route.steps)
        f.shop:SetItems(tab == "shop" and Route.Shopping(route) or {})
    end
    f.routeNote:SetText(table.concat(notes, " "))
    f.stepsView:SetShown(tab == "steps")
    f.shopView:SetShown(tab == "shop")
end

---------------------------------------------------------------------------
-- Head texts
---------------------------------------------------------------------------
local function pickerValues()
    local values = {}
    local own = {}
    for _, p in ipairs(Pr.Own()) do own[p.skill] = p end
    for _, skill in ipairs(Pr.Ordered()) do
        local p = own[skill]
        values[#values + 1] = { value = skill, text = p and ("%s (%d/%d)"):format(Pr.Name(skill), p.rank, p.max) or Pr.Name(skill) }
    end
    values[#values + 1] = { value = CAMP, text = L["Lager (Camping)"] }
    values[#values + 1] = { value = FAVOR, text = L["Händlergunst"] }
    return values
end

local function statusText(v, n)
    if v == CAMP then return L["%d Lagerobjekte"]:format(n) end
    if v == FAVOR then
        local fav = Pr.Favor() or {}
        local parts = { L["%d Rezepte"]:format(n) }
        if fav.amount then parts[#parts + 1] = ("%s: %d"):format(fav.name or L["Händlergunst"], fav.amount) end
        local certs = 0
        for _ in pairs(fav.cert or {}) do certs = certs + 1 end
        if certs > 0 then parts[#parts + 1] = L["%d Zertifizierungen (1000 Gunst, Rang 300)"]:format(certs) end
        return table.concat(parts, " · ")
    end
    return L["%d von %d Rezepten"]:format(n, #Pr.Recipes(v))
end

local function hintText(v)
    if v == FAVOR then
        local fav = Pr.Favor() or {}
        local names = {}
        for _, npc in ipairs(fav.vendors or {}) do
            local n = Pr.Npc(npc)
            if n and n.name then names[#names + 1] = n.name end
        end
        local writs = 0
        for _, c in pairs(fav.writs or {}) do writs = writs + c end
        return L["Händler: %s. Gunst gibt es für volle Kisten und Handwerksaufträge (%d Items haben einen)."]:format(
            #names > 0 and table.concat(names, ", ") or L["unbekannt"], writs)
    elseif v == CAMP then
        return L["Lagerobjekte brauchen ein Lagerfeuer in der Nähe und teilen eine Abklingzeit. Wirkung nach Sitzen am Feuer."]
    end
    -- what the own character knows comes from its profession window
    if Pr.Rank(v) and not Pr.HasSnapshot(v) then return L["Für \"Bekannt\" das Berufsfenster einmal öffnen."] .. " " .. ROW_HINT end
    return ROW_HINT
end

---------------------------------------------------------------------------
-- Refresh and build
---------------------------------------------------------------------------
local function refresh(f)
    local s = state()
    local v = view()
    f.prof:SetValues(pickerValues())
    f.prof:SetValue(v)
    -- the switch "Rezepte | Route": the route only for the professions that have one
    local onRoute = routeShown(v)
    local canRoute = type(v) == "number" and Route.Has(v)
    f.modeRecipes:SetOn(not onRoute)
    f.modeRoute:SetOn(onRoute)
    if canRoute or onRoute then f.modeRoute:Enable() else f.modeRoute:Disable() end
    f.routeView:SetShown(onRoute)
    for _, w in ipairs({ f.list, f.detail }) do w:SetShown(not onRoute) end
    if onRoute then
        for _, w in ipairs({ f.known, f.source, f.learn, f.guild, f.search, f.counts, f.empty, f.reset }) do w:Hide() end
        f:Place(1, { f.prof, f.modeRecipes, f.modeRoute }, { f.rank })
        local rank, max = Pr.Rank(v)
        f.rank:SetText(rank and L["Dein Rang: %d / %d"]:format(rank, max or 0) or (GREY .. L["Beruf nicht erlernt"] .. "|r"))
        f.shownView = v
        refreshRoute(f, v)
        f.hint:SetText(L["Klick auf einen Schritt: die Rezept-Details oder der Wegpunkt zum Händler. Kosten nur aus Händlerpreisen."])
        local d = ns.Data("PROFESSIONS")
        f.data:SetText(L["Berufsdaten vom %s (Client %s) · Namen aus dem Client."]:format(d and d.built or "?", d and d.client or "?"))
        return
    end
    f.counts:Show()
    local isRecipes = type(v) == "number"
    f.known:SetValue(s.known or "all")
    f.source:SetValue(s.source or "all")
    f.learn:SetOn(s.learnable and true or false)
    -- Gilde with its count; greyed at 0, then it can only be turned off
    local guildN = isRecipes and guildCount(v) or 0
    f.guildCount = guildN
    f.guild.label:SetText(L["Gilde (%d)"]:format(guildN))
    W.FitChip(f.guild, GUILD_W)
    f.guild.dim = guildN == 0
    if guildN > 0 or s.guild then f.guild:Enable() else f.guild:Disable() end
    f.guild:SetOn(s.guild and true or false)
    local text = s.search or ""
    if not f.search:HasFocus() and f.search:GetText() ~= text then f.search:SetText(text) end
    for _, w in ipairs({ f.known, f.source, f.learn, f.guild, f.search }) do
        if isRecipes then w:Show() else w:Hide() end
    end
    -- without the filters (camp, favor) the counts take the whole band
    f:Place(1, f.headRow, { f.rank })
    f:Place(2, f.filterRow, nil, { shown = true })
    local rank, max = nil, nil
    if isRecipes then rank, max = Pr.Rank(v) end
    f.rank:SetText(rank and L["Dein Rang: %d / %d"]:format(rank, max or 0) or (isRecipes and (GREY .. L["Beruf nicht erlernt"] .. "|r") or ""))
    if f.shownView ~= v then f.list.offset = 0 end
    f.shownView = v
    nameMissing = false
    local list = listOf(v)
    -- the chosen entry: kept by its spell (or camp item) per view
    local key = s.sel[tostring(v)]
    f.selected = nil
    for _, e in ipairs(list) do
        local k = e.camp and e.camp.item or e.recipe.spell
        if k == key then f.selected = e end
    end
    f.selected = f.selected or list[1]
    f.list:SetItems(list)
    local canReset = false
    if #list == 0 then
        local help = L["Für diesen Client gibt es keine Berufsdaten."]
        if Pr.Available() then help, canReset = emptyHelp(v) end
        f.empty:Set(L["Keine Rezepte"], help)
        f.empty:Show()
    else
        f.empty:Hide()
    end
    f.reset:SetShown(canReset and isRecipes)
    showDetail(f, f.selected)
    f.counts:SetText(statusText(v, #list))
    f.hint:SetText(hintText(v))
    local d = ns.Data("PROFESSIONS")
    f.data:SetText(L["Berufsdaten vom %s (Client %s) · Namen aus dem Client."]:format(d and d.built or "?", d and d.client or "?"))
end

local function choose(e)
    if not e or not page then return end
    local k = e.camp and e.camp.item or e.recipe.spell
    state().sel[tostring(page.shownView)] = k
    page.selected = e
    page.list:Redraw()
    showDetail(page, e)
end

local function linkOf(e)
    if e.camp then
        local _, _, link = Pr.ItemInfo(e.camp.item)
        return link
    end
    local r = e.recipe
    if r.item > 0 then
        local _, _, link = Pr.ItemInfo(r.item)
        if link then return link end
    end
    return C_Spell and C_Spell.GetSpellLink and ns.Plain(C_Spell.GetSpellLink(r.spell)) or nil
end

-- The tooltip of an entry: the item it makes (or the camp object), else the recipe spell.
local function entryTooltip(owner, e)
    if not e or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local item = e.camp and e.camp.item or (e.recipe.item > 0 and e.recipe.item) or nil
    if item and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(item)
    elseif item then
        GameTooltip:SetHyperlink("item:" .. item)
    elseif GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(e.recipe.spell)
    else
        GameTooltip:SetText(e.name or "")
    end
    GameTooltip:Show()
end

local function insertLink(link)
    if not link then return end
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        ChatFrameUtil.InsertLink(link)
    elseif type(ChatEdit_InsertLink) == "function" then
        ChatEdit_InsertLink(link)
    end
end

local function col(parent, x, w, template)
    local fs = W.Text(parent, template or T.FONT.text, w)
    fs:SetPoint("LEFT", x, 0)
    return fs
end

-- A filter as a dropdown (W.Picker) whose field reads "<filter>: <entry>", as wide as its widest
-- entry needs.
local function filterPicker(parent, fmt, values, onPick)
    local p = W.Picker(parent, nil, onPick)
    p:SetValues(values)
    local set = p.SetValue
    function p:SetValue(v)
        set(self, v)
        self.label:SetText(fmt:format(SHORT[v] or entryText(values, v)))
    end
    local widest = 0
    for _, e in ipairs(values) do
        p.label:SetText(fmt:format(SHORT[e.value] or e.text))
        widest = math.max(widest, p.label:GetStringWidth() or 0)
    end
    p:SetWidth(math.ceil(widest) + T.TEXT_INSET + T.PICKER.ARROW_ROOM)
    p:SetValue(values[1].value)
    return p
end

local function create(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: the profession and the search, the own rank at the right; under it the filters
    local top = f:Bands({ "row", "row" })
    f.prof = W.Picker(f, P.PICKER_W, function(v)
        state().view = (v == CAMP or v == FAVOR) and v or tonumber(v)
        ns.Refresh()
    end)
    -- the switch "Rezepte | Route" (F-137)
    f.modeRecipes = W.Chip(f, L["Rezepte"], P.MODE_W, function()
        state().mode = RECIPES
        ns.Refresh()
    end)
    W.FitChip(f.modeRecipes, P.MODE_W)
    W.Tooltip(f.modeRecipes, L["Rezepte"], L["Die Rezepte des Berufs mit Filtern und Details."])
    f.modeRoute = W.Chip(f, L["Route"], P.MODE_W, function()
        state().mode = ROUTE
        ns.Refresh()
    end)
    W.FitChip(f.modeRoute, P.MODE_W)
    W.Tooltip(f.modeRoute, L["Route"], L["Der günstigste Weg von deinem Rang bis zum Höchstrang: Schritte, Lehrer und Einkaufsliste. Nicht für Sammelberufe, Angeln, Lager und Händlergunst."])
    f.search = W.SearchBox(f, P.SEARCH_W, function(text)
        state().search = text ~= "" and text or nil
        ns.Refresh()
    end, L["Rezept suchen"])
    f.rank = W.Text(f, T.FONT.head, P.RANK_W)
    f.rank:SetJustifyH("RIGHT")
    f.headRow = { f.prof, f.modeRecipes, f.modeRoute, f.search }
    f:Place(1, f.headRow, { f.rank })

    -- the two dropdowns name their filter in the field, so they don't read as on/off chips
    f.known = filterPicker(f, L["Bekannt: %s"], KNOWN, function(v)
        state().known = v
        ns.Refresh()
    end)
    W.Tooltip(f.known, L["Bekannt"], L["Alle, nur bekannte oder nur unbekannte Rezepte. Was du kennst, liest Amisia aus dem offenen Berufsfenster."])
    f.source = filterPicker(f, L["Quelle: %s"], SOURCES, function(v)
        state().source = v
        ns.Refresh()
    end)
    W.Tooltip(f.source, L["Quelle"], L["Woher das Rezept kommt: Lehrer, Händler, Händlergunst, Drop oder Quest."])
    f.learn = W.Chip(f, L["Lernbar"], 80, function()
        local s = state()
        s.learnable = not s.learnable or nil
        ns.Refresh()
    end)
    W.Tooltip(f.learn, L["Lernbar"], L["Nur unbekannte Rezepte, die dein Rang schon erlaubt."])
    f.guild = W.Chip(f, L["Gilde (%d)"]:format(0), GUILD_W, function()
        local s = state()
        s.guild = not s.guild or nil
        ns.Refresh()
    end)
    W.FitChip(f.guild, GUILD_W)
    W.Tooltip(f.guild, L["Gilde"], function()
        if (f.guildCount or 0) == 0 then
            return L["Noch teilt niemand aus der Gilde Rezepte. Die Liste füllt sich, sobald Gildenmitglieder mit Amisia ihr Berufsfenster öffnen."]
        end
        return L["Nur Rezepte, die jemand aus der Gilde kennt (von Amisia-Nutzern geteilt)."]
    end)
    f.counts = W.Text(f, T.FONT.hint)
    -- the filters, then the counts beside them (the whole band in the camp and favor views)
    f.filterRow = { f.known, f.source, f.learn, f.guild, { f.counts, fill = true } }
    f:Place(2, f.filterRow)
    -- the hint takes two lines when it needs them (the favor vendors), the data line under it
    f:Footer({ { "hint", lines = 2 }, "data" })

    f.list = f:List(ROWS, ROW_H, function(r)
        r.sel = W.SelectBar(r)
        r.name = col(r, 4, 196)
        r.mark = col(r, 204, 44)
        r.rank = col(r, 250, 36)
        r.rank:SetJustifyH("RIGHT")
        r:RegisterForClicks("LeftButtonUp")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if not e then return end
            if IsShiftKeyDown and IsShiftKeyDown() then
                insertLink(linkOf(e))
                return
            end
            choose(e)
        end)
        r:SetScript("OnEnter", function(self) entryTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillRow, { top = top, width = T.LAYOUT.SPLIT_LIST_W })
    f.empty = f:Empty(T.LAYOUT.SPLIT_LIST_W - 10)
    -- under the empty state's help; a child of the list it stands over (the list holds it)
    f.reset = W.Button(f.list, L["Filter zurücksetzen"], nil, resetFilters, { height = T.ROW_BUTTON_H })
    W.FitChip(f.reset)
    f.reset:SetPoint("TOP", f.empty.text, "BOTTOM", 0, -T.EMPTY.BUTTON_GAP)
    f.reset:Hide()
    W.Tooltip(f.reset, L["Filter zurücksetzen"], L["Stellt Bekannt und Quelle auf Alle, schaltet Lernbar und Gilde aus und leert die Suche."])

    -- the chosen recipe in the inset beside the list, as high as the list
    local d = f:Detail({ top = top, height = ROWS * ROW_H, sub = true })
    f.detail = d
    d.head:SetScript("OnEnter", function(self) entryTooltip(self, d.entry) end)
    d.head:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    d.go = W.Button(d, L["Wegpunkt"], 70, function()
        if d.point and ns.MapSetPoint then
            local ok, why = ns.MapSetPoint(d.point, d.pointLabel)
            if not ok and why then ns.msg(why) end
        end
    end, { height = T.ROW_BUTTON_H })
    W.Tooltip(d.go, L["Wegpunkt"], L["Setzt den Wegpunkt auf die erste Quelle mit Ort."])
    d.ask = W.Button(d, L["Fragen"], 70, function()
        local e, who = d.entry, d.askWho
        if not e or not who or e.camp then return end
        local r = e.recipe
        local link
        if r.item > 0 then link = select(3, Pr.ItemInfo(r.item)) end
        Cr.Whisper(who.name, link or e.name)
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(d.go, 70)
    W.FitChip(d.ask, 70)
    d:Buttons({ d.ask, d.go })
    W.Tooltip(d.ask, L["Fragen"], L["Öffnet ein Flüstern an jemanden aus der Gilde, der das Rezept kennt (online zuerst)."])

    -- the route view under the head row: the switches, the head, a note; the steps or the shopping list
    local rv = W.Page(f, { view = true, top = -(T.LAYOUT.ROW_H + T.LAYOUT.GAP) })
    f.routeView = rv
    rv:Bands({ "row", "row", "line" })
    rv.vendorLabel = W.Text(rv, T.FONT.text)
    rv.vendorLabel:SetText(L["Rezepte:"])
    local function setVendor(on)
        state().routeVendor = on or nil
        ns.Refresh()
    end
    f.vendorT = W.Chip(rv, L["nur Lehrer"], P.VENDOR_W, function() setVendor(false) end)
    W.FitChip(f.vendorT, P.VENDOR_W)
    W.Tooltip(f.vendorT, L["nur Lehrer"], L["Die Route nimmt bekannte Rezepte und was der Lehrer bis zum nächsten Limit lehrt."])
    f.vendorV = W.Chip(rv, L["auch Händler"], P.VENDOR_W, function() setVendor(true) end)
    W.FitChip(f.vendorV, P.VENDOR_W)
    W.Tooltip(f.vendorV, L["auch Händler"], L["Dazu Rezepte, die ein Händler deiner Fraktion verkauft, mit dem Kaufpreis in den Kosten und einem Schritt \"Rezept kaufen\". Drop-Rezepte nie."])
    local function setTab(tab)
        state().routeTab = tab
        ns.Refresh()
    end
    f.tabSteps = W.Chip(rv, L["Schritte"], P.TAB_W, function() setTab("steps") end)
    W.FitChip(f.tabSteps, P.TAB_W)
    W.Tooltip(f.tabSteps, L["Schritte"], L["Die Route Schritt für Schritt; der aktuelle Schritt ist markiert, erledigte sind abgehakt."])
    f.tabShop = W.Chip(rv, L["Einkauf"], P.TAB_W, function() setTab("shop") end)
    W.FitChip(f.tabShop, P.TAB_W)
    W.Tooltip(f.tabShop, L["Einkauf"], L["Die Materialien der offenen Schritte: Bedarf, was du hast (Taschen und Bank), was deine Twinks haben, was fehlt."])
    rv:Place(1, { rv.vendorLabel, f.vendorT, f.vendorV }, { f.tabSteps, f.tabShop })
    f.routeHead = W.Text(rv, T.FONT.body)
    rv:Place(2, { { f.routeHead, fill = true } })
    f.routeNote = rv:Line(3)

    -- the steps: two lines per card, the cost at the right, a tick on the done ones
    f.stepsView = W.Page(rv, { view = true, top = rv.top })
    f.steps = f.stepsView:List(P.STEP_ROWS, P.STEP_H, function(r)
        r.sel = W.SelectBar(r)
        r.tick = r:CreateTexture(nil, "ARTWORK")
        r.tick:SetSize(P.TICK, P.TICK)
        r.tick:SetPoint("TOPLEFT", P.MARK_X, P.LINE1_Y)
        r.tick:SetTexture(P.TICK_TEX)
        local w = T.PAGE_W - T.SCROLL_ROOM - P.TEXT_X - T.LAYOUT.TEXT_X
        r.line1 = W.Text(r, T.FONT.text, w - P.COST_W)
        r.line1:SetPoint("TOPLEFT", P.TEXT_X, P.LINE1_Y)
        r.cost = W.Text(r, T.FONT.text, P.COST_W)
        r.cost:SetJustifyH("RIGHT")
        r.cost:SetPoint("TOPRIGHT", -T.LAYOUT.TEXT_X, P.LINE1_Y)
        r.line2 = W.Text(r, T.FONT.hint, w)
        r.line2:SetPoint("TOPLEFT", P.TEXT_X, P.LINE2_Y)
        r:RegisterForClicks("LeftButtonUp")
        r:SetScript("OnClick", function(self) clickStep(self.item) end)
        r:SetScript("OnEnter", function(self) stepTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillStep)

    -- the shopping list
    f.shopView = W.Page(rv, { view = true, top = rv.top })
    local _, sh = f.shopView:Columns(P.SHOP_COLS)
    sh.name:SetText(L["Material"])
    sh.need:SetText(L["Bedarf"])
    sh.have:SetText(L["hast"])
    sh.twinks:SetText(L["Twinks##Einkauf"])
    sh.miss:SetText(L["fehlt"])
    sh.price:SetText(L["Preis"])
    sh.src:SetText(L["Quelle"])
    f.shop = f.shopView:List(P.SHOP_ROWS, P.SHOP_H, function(r)
        W.Cells(r, P.SHOP_COLS)
        r:RegisterForClicks("LeftButtonUp")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if e and e.kind == "vendor" then goToVendor(e.vendors, itemName(e.item)) end
        end)
        r:SetScript("OnEnter", function(self) shopTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillShop)
    rv:Hide()
    return f
end

ns.RegisterPanel{ key = "professions", label = L["Berufe"], icon = ICON, order = 57, group = "gear",
    available = function() return Pr.Available() end, create = create, refresh = refresh }

function ns.ProfessionsPageFrame() return page end

-- Opens the page; what: a profession (German name or key, a prefix is enough), "lager" or "gunst".
function ns.ShowProfessions(what)
    if AmisiaDB and AmisiaDB.settings and type(what) == "string" and what ~= "" then
        local w = ns.Fold(what)
        if w == "route" then
            state().mode = ROUTE
        elseif w:find("^lager") or w:find("^camp") then
            state().view = CAMP
        elseif w:find("^gunst") or w:find("^händler") or w:find("^favor") then   -- l10n-ok: German command words
            state().view = FAVOR
        else
            for _, skill in ipairs(Pr.Skills()) do
                local name, key = ns.Fold(Pr.Name(skill)), Pr.Key(skill)
                if name:sub(1, #w) == w or key:sub(1, #w) == w then
                    state().view = skill
                    break
                end
            end
        end
    end
    if ns.ShowPage then ns.ShowPage("professions") end
end

-- Opens the page at one recipe (a hit of the main window's search): its profession, the recipe's
-- name in the search, the filters off so it shows, the recipe chosen.
function ns.ShowRecipe(skill, spell, name)
    if AmisiaDB and AmisiaDB.settings and type(skill) == "number" then
        local s = state()
        s.view = skill
        s.search = type(name) == "string" and name ~= "" and name or nil
        s.known, s.learnable, s.source, s.guild, s.mode = nil, nil, nil, nil, nil
        if type(spell) == "number" then s.sel[tostring(skill)] = spell end
    end
    if ns.ShowPage then ns.ShowPage("professions") end
end

ns.RegisterSlash("berufe", { en = "professions", aliases = { "beruf", "profession" }, args = L["[Beruf|lager|gunst|route]"],
    desc = L["Rezepte, Lager und Händlergunst"], run = function(rest) ns.ShowProfessions(rest) end })

---------------------------------------------------------------------------
-- Changes: the shown page follows the profession window, the collector and item names
---------------------------------------------------------------------------
local function shown()
    return page ~= nil and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "professions"
end

local due = false
local function schedule()
    if due or not shown() then return end
    due = true
    C_Timer.After(0.3, function()
        due = false
        if shown() then ns.Refresh() end
    end)
end
ns.Listen("PROF_CHANGED", schedule)
ns.Listen("PROF_SPELL_LOADED", schedule)
ns.Listen("BIS_CHANGED", schedule)
ns.Listen("CRAFTERS_CHANGED", schedule)
ns.OnEvent("BAG_UPDATE_DELAYED", schedule)
-- the route waits in combat and the lockdown (ProfRoute.lua): computed again after them
ns.OnEvent("PLAYER_REGEN_ENABLED", schedule)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", schedule)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if nameMissing then schedule() end
end)
