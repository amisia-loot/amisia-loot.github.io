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
-- The overview (F-151, D-78), the view when none is chosen: the own professions, all professions,
-- camp and favor as cards; the side bar lists the same views as marks (Übersicht, each profession
-- with its icon, Lager, Händlergunst with the own favor).
local ADDON, ns = ...
local L = ns.L
local W, Pr, T, Cr, Route = ns.W, ns.Prof, ns.Theme, ns.Crafters, ns.ProfRoute
local P = T.PROFPAGE
local GREY = T.GREY
local GREEN = "|cff40bf40"
local ICON = "Interface\\Icons\\Trade_BlackSmithing"
local QUALITY = T.QUALITY_HEX
-- the dropdowns' entries (W.Picker); the field shows "<filter>: <entry>", SHORT where it differs
local SOURCES = { { value = "all", text = L["Alle Quellen"] }, { value = "T", text = L["Lehrer"] },
    { value = "V", text = L["Händler"] }, { value = "F", text = L["Händlergunst"] }, { value = "D", text = "Drop" },
    { value = "Q", text = "Quest" } }
local KNOWN = { { value = "all", text = L["Alle"] }, { value = "known", text = L["Bekannt"] },
    { value = "unknown", text = L["Unbekannt"] } }
local SHORT = { all = L["Alle"] }
local CAMP, FAVOR, OVERVIEW = "camp", "favor", "overview"
local MARKS = P.MARK_ICONS
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

-- The first open of a session shows the overview, whatever view is saved (D-78): opened by the tab or
-- the page's row; a mark, a card, the picker, a command with a view and ns.ShowRecipe choose a view
-- (chosen()) and end it. Only in memory.
local atStart = true
local function chosen() atStart = false end

-- The shown view: OVERVIEW, a skill line, CAMP or FAVOR (D-78). Default: the overview.
local function view()
    if atStart then return OVERVIEW end
    local v = state().view
    if v == CAMP or v == FAVOR or v == OVERVIEW then return v end
    v = tonumber(v)
    if v and Pr.Key(v) then return v end
    return OVERVIEW
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

-- r, g, b of a colour code "ffrrggbb"
local function rgb(hex)
    local r, g, b = tostring(hex):match("^%x%x(%x%x)(%x%x)(%x%x)$")
    if not r then return 1, 1, 1 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- The client's icon of what an entry makes (the item), else the recipe's spell, else the question mark.
local function entryIcon(item, spell)
    local icon = item and item > 0 and C_Item and C_Item.GetItemIconByID and ns.Plain(C_Item.GetItemIconByID(item)) or nil
    if not icon and spell and spell > 0 then
        local f = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture
        if type(f) == "function" then
            local ok, tex = pcall(f, spell)
            icon = ok and ns.Plain(tex) or nil
        end
    end
    return icon or Pr.ICON_UNKNOWN
end

-- An icon in Amisia's rounded ring (D-81) in its item's quality colour (gold when gold is given).
local function roundFrame(parent, size, x)
    local fr = CreateFrame("Frame", nil, parent)
    fr:SetSize(size, size)
    fr:SetPoint("LEFT", x, 0)
    fr.icon = fr:CreateTexture(nil, "ARTWORK")
    fr.icon:SetAllPoints()
    if ns.GoalsKit and T.PLANNER and T.PLANNER.DOLL then ns.GoalsKit.roundIcon(fr, T.PLANNER.DOLL, fr.icon) end
    return fr
end

local function ringColor(fr, item)
    if not fr.ring then return end
    local q
    if item and item > 0 then q = select(2, Pr.ItemInfo(item)) end
    local c = T.QUALITY_RGB[q or 1] or T.QUALITY_RGB[1]
    fr.ringColor = { c[1], c[2], c[3], 1 }
    fr.ring:SetVertexColor(c[1], c[2], c[3], 1)
end

-- The short source word of a row ("Lehrer", "Händler", ...), the first the recipe has.
local TAGS = { { "T", L["Lehrer"] }, { "F", L["Gunst"] }, { "V", L["Händler"] }, { "Q", "Quest" }, { "D", "Drop" } }
local function sourceTag(r)
    local kinds = Pr.SourceKinds(r) or {}
    for _, t in ipairs(TAGS) do
        if kinds[t[1]] then return t[2] end
    end
    return ""
end

-- Whether someone of the guild other than the own characters knows a recipe (the green dot).
local function guildKnows(spell)
    if not (Cr.Has and Cr.Has(spell)) then return false end
    for _, c in ipairs(Cr.ForSpell(spell)) do
        if not c.own then return true end
    end
    return false
end

local function fillRow(r, e)
    r.sel:SetShown(page and page.selected == e)
    local item, spell, col
    if e.camp then
        local c = e.camp
        local rank = c.skill > 0 and Pr.Rank(c.skill) or nil
        col = (rank and rank >= c.rank) and Pr.COLORS.green or (rank and Pr.COLORS.red) or Pr.COLORS.none
        r.name:SetText(color(col, campName(c)))
        r.mark:SetText(c.slots > 0 and (GREY .. L["%d Pl."]:format(c.slots) .. "|r") or "")
        r.rank:SetText(c.skill > 0 and (GREY .. c.rank .. "|r") or "")
        item, spell = c.item, c.recipe
        r.dotMe:Hide()
        r.dotGuild:Hide()
    else
        local rec = e.recipe
        col = Pr.COLORS[e.color] or Pr.COLORS.none
        local name = e.name
        if e.known == true then
            local now = Route.Craftable(rec.spell)
            if now and now > 0 then
                name = name .. " " .. GREEN .. ("(%d)"):format(now) .. "|r"
            else
                name = name .. " " .. GREY .. L["(bekannt)"] .. "|r"
            end
        end
        r.name:SetText(color(col, name))
        r.mark:SetText(upgradeMark(rec.item) or (GREY .. sourceTag(rec) .. "|r"))
        if e.price then
            r.rank:SetText(GREY .. e.price .. "|r")
        else
            r.rank:SetText(GREY .. Pr.LearnRank(rec) .. "|r")
        end
        item, spell = rec.item, rec.spell
        r.dotMe:SetShown(e.known == true)
        r.dotGuild:SetShown(guildKnows(rec.spell))
    end
    r.iconFrame.icon:SetTexture(entryIcon(item, spell))
    ringColor(r.iconFrame, item)
    r.bar:SetColorTexture(rgb(col))
end

-- A row of the recipe list (D-82): a thin frame (gold when chosen), the difficulty bar, the icon in its
-- ring, the name, the tag, the two dots and the skill.
local function buildRow(r)
    local e = P.ROW_EDGE
    r.edges = W.Border(r, e[1], e[2], e[3], e[4])
    r.sel = CreateFrame("Frame", nil, r)
    r.sel:SetAllPoints()
    W.Border(r.sel, W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
    W.Flat(r.sel, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.08, "BORDER")
    r.sel:Hide()
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", 1, -1)
    r.bar:SetPoint("BOTTOMLEFT", 1, 1)
    r.bar:SetWidth(P.ROW_BAR_W)
    r.iconFrame = roundFrame(r, P.ROW_ICON, P.ROW_ICON_X)
    r.name = W.Text(r, T.FONT.text, P.LIST_W - P.ROW_TEXT_X - P.ROW_MARK_R - P.ROW_MARK_W - 4)
    r.name:SetPoint("LEFT", P.ROW_TEXT_X, 0)
    r.mark = W.Text(r, T.FONT.hint, P.ROW_MARK_W)
    r.mark:SetJustifyH("RIGHT")
    r.mark:SetPoint("RIGHT", -P.ROW_MARK_R, 0)
    r.dotMe = r:CreateTexture(nil, "ARTWORK")
    r.dotMe:SetSize(P.DOT, P.DOT)
    r.dotMe:SetTexture(P.DOT_ME)
    r.dotMe:SetPoint("RIGHT", -P.DOT_ME_R, 0)
    r.dotGuild = r:CreateTexture(nil, "ARTWORK")
    r.dotGuild:SetSize(P.DOT, P.DOT)
    r.dotGuild:SetTexture(P.DOT_GUILD)
    r.dotGuild:SetPoint("RIGHT", -P.DOT_GUILD_R, 0)
    r.rank = W.Text(r, T.FONT.text, P.ROW_RANK_W)
    r.rank:SetJustifyH("RIGHT")
    r.rank:SetPoint("RIGHT", -T.LAYOUT.TEXT_X, 0)
end

---------------------------------------------------------------------------
-- The detail field
---------------------------------------------------------------------------
-- the colour of a recipe for a rank (Pr.Difficulty) in words
local COLOR_WORDS = { orange = L["orange"], yellow = L["gelb"], green = L["grün"], grey = L["grau"],
    red = L["noch nicht lernbar"] }

---------------------------------------------------------------------------
-- The recipe's detail (D-82): icon, name and star, a quiet line, the boxes Details, Reagenzien and
-- the guild's crafters
---------------------------------------------------------------------------
-- The text of the box Details: the four colour steps, the own rank, known, the count, where it is
-- learned (with the recipe item and what it needs), the crafting order note. Second value: the sources.
local function detailsText(r)
    local lines = {}
    -- the learn rank: the game's own, an estimate with "?" (F-155), "(vom Lehrer)" when a trainer said it
    local learn = tostring(Pr.LearnRank(r)) .. (Pr.LearnExact(r) and "" or "?")
    lines[#lines + 1] = L["Skill: lernbar ab %s"]:format(("%s  %s  %s  %s"):format(color(Pr.COLORS.orange, learn),
        color(Pr.COLORS.yellow, r.yellow), color(Pr.COLORS.green, r.green), color(Pr.COLORS.grey, r.grey)))
        .. (Pr.LearnFromTrainer(r) and (GREY .. " " .. L["(vom Lehrer)"] .. "|r") or "")
    local rank = Pr.Rank(r.skill)
    local known = Pr.Known(r.spell, r.skill)
    if rank then
        local d = Pr.Difficulty(r, rank, known)
        local word = COLOR_WORDS[d]
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
    if r.count > 1 then lines[#lines + 1] = L["Stellt %d Stück her."]:format(r.count) end
    lines[#lines + 1] = L["Gelernt bei:"]
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
    if Pr.HasWrit(r) then lines[#lines + 1] = L["Handwerksauftrag für dieses Item möglich (Händlergunst)."] end
    return table.concat(lines, "\n"), src
end

-- The recipe of an entry: a recipe's own, a camp object's when the data has it, else nil.
local function entryRecipe(e)
    if not e then return nil end
    if e.recipe then return e.recipe end
    local c = e.camp
    return c and c.recipe > 0 and Pr.Recipe(c.recipe) or nil
end

-- The camp lines over a camp object's Details: the profession and rank it needs, the slots, what it
-- replaces, the client's description of its use.
local function campText(c)
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
    local desc, loading = Pr.SpellDescription(c.use)
    -- the text comes when the client has loaded the spell (PROF_SPELL_LOADED redraws the page)
    lines[#lines + 1] = desc or (GREY .. (loading and L["Beschreibung lädt ..."] or L["Keine Beschreibung vom Client."]) .. "|r")
    return table.concat(lines, "\n")
end

-- The guild's crafters of a recipe as text (online first and green; the offline ones only when
-- shown, else their count) and whether anyone knows it.
local function guildText(spell, offline)
    local makers = Cr.ForSpell(spell)
    if #makers == 0 then return GREY .. L["Hergestellt von: niemand aus der Gilde bekannt"] .. "|r", false end
    local shown, hidden = {}, 0
    for _, c in ipairs(makers) do
        if c.online or c.own or offline then shown[#shown + 1] = c else hidden = hidden + 1 end
    end
    local text = #shown > 0 and Cr.Text(shown, 12, true) or (GREY .. L["Gerade niemand online."] .. "|r")
    if hidden > 0 then text = text .. "\n" .. GREY .. L["%d offline"]:format(hidden) .. "|r" end
    return text, true
end

local function rdWidth()
    return (T.PAGE_W_NOW or T.PAGE_W) - P.DETAIL_X - 2 * P.RD_PAD - (T.SCROLL_ROOM - T.SCROLLBAR_GAP)
end

local function newBox(parent, title)
    local b = CreateFrame("Frame", nil, parent)
    local bg = P.RD_BOX_BG
    b.ground = W.Flat(b, bg[1], bg[2], bg[3], bg[4])
    local e = P.ROW_EDGE
    W.Border(b, e[1], e[2], e[3], e[4])
    b.head = W.Text(b, T.FONT.head)
    b.head:SetPoint("TOPLEFT", P.RD_BOX_PAD, -P.RD_BOX_PAD)
    b.head:SetPoint("RIGHT", -P.RD_BOX_PAD, 0)
    b.head:SetText(title)
    return b
end

local function itemName(id)
    local name = Pr.ItemInfo(id)
    if not name then nameMissing = true end
    return name or ("Item " .. tostring(id))
end

-- "have / need" in green (enough in the bags and bank), orange (enough with the alts) or red (F-159).
local function haveText(have, twinks, need)
    local c = have >= need and GREEN or (have + twinks >= need and T.ORANGE) or T.RED
    local own = tostring(have)
    if twinks > 0 and have < need then own = own .. "+" .. twinks end
    return c .. ("%s / %d"):format(own, need) .. "|r"
end

-- The tooltip lines of the own characters holding an item (F-159).
local function addHolders(item)
    local list = Route.TwinksBy(item)
    if #list == 0 then return end
    GameTooltip:AddLine(L["Bei deinen Twinks:"], 1, 0.82, 0)
    for i, c in ipairs(list) do
        if i > 6 then
            GameTooltip:AddLine(L["... und %d weitere"]:format(#list - 6), 0.6, 0.6, 0.6)
            break
        end
        local name = c.name
        GameTooltip:AddDoubleLine(name, c.bank > 0 and L["%d (Bank %d)"]:format(c.n, c.bank) or tostring(c.n), 1, 1, 1, 1, 1, 1)
    end
end

-- The menu "Woher?" of a reagent (F-160): vendors, recipes, gathering zones, mobs; a click on a line
-- sets the waypoint, opens the zone's world map or the recipe.
local function whereMenu(owner, item)
    if not item then return end
    if GameTooltip then GameTooltip:Hide() end
    local entries = { { L["Woher kommt %s?"]:format(itemName(item)), nil, head = true } }
    for _, src in ipairs(Route.ReagentSources(item)) do
        local fn
        if src.point then
            fn = function()
                local ok, why = ns.MapSetPoint(src.point, src.name or itemName(item), nil, item)
                if not ok and why then ns.msg(why) end
            end
        elseif src.map then
            fn = function() ns.MapShowOnWorldMap({ map = src.map }) end
        elseif src.recipe then
            fn = function() if ns.ShowRecipe then ns.ShowRecipe(src.recipe.skill, src.recipe.spell) end end
        end
        entries[#entries + 1] = { src.text, fn, tip = fn and src.tip or nil }
    end
    W.Menu(owner, entries, { width = P.WHERE_W })
end

local function reagentRow(box, i)
    local row = box.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, box)
    row:SetHeight(P.RD_REAG_H)
    row:RegisterForClicks("LeftButtonUp")
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, P.CARD_HOVER)
    row:SetScript("OnClick", function(self) whereMenu(self, self.item) end)
    row:SetScript("OnEnter", function(self)
        if not (self.item and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) else GameTooltip:SetText(itemName(self.item)) end
        addHolders(self.item)
        GameTooltip:AddLine(L["Klick: woher es kommt (Händler, Sammeln, Drop, Rezept)."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(P.RD_REAG_ICON, P.RD_REAG_ICON)
    row.icon:SetPoint("LEFT", 0, 0)
    row.have = W.Text(row, T.FONT.text, P.RD_HAVE_W)
    row.have:SetJustifyH("RIGHT")
    row.have:SetPoint("RIGHT", 0, 0)
    row.name = W.Text(row, T.FONT.text)
    row.name:SetPoint("LEFT", P.RD_REAG_ICON + 4, 0)
    row.name:SetPoint("RIGHT", row.have, "LEFT", -4, 0)
    box.rows[i] = row
    return row
end

-- Places the boxes one under the other at the width the window gives (the texts' heights as the
-- client measures them).
-- A text's height: what the client measures, at least its own lines.
local function textHeight(fs)
    local _, breaks = (fs:GetText() or ""):gsub("\n", "")
    return math.max(math.ceil(fs:GetStringHeight() or 0), (breaks + 1) * P.RD_LINE_H)
end

local function layoutRecipe(rd)
    local w = rdWidth()
    rd.child:SetWidth(w)
    local inner = w - 2 * P.RD_BOX_PAD
    local y = 0
    local function place(box, h)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", rd.child, "TOPLEFT", 0, y)
        box:SetWidth(w)
        box:SetHeight(h)
        y = y - h - P.RD_BOX_GAP
    end
    rd.info:SetWidth(inner)
    local infoH = textHeight(rd.info)
    -- the controls' line only when it holds something (a camp object without recipe and place has none)
    local ctrl = (rd.count:IsShown() or rd.go:IsShown()) and (4 + P.RD_CTRL_H) or 0
    place(rd.details, P.RD_BOX_PAD + P.RD_HEAD_H + infoH + ctrl + P.RD_BOX_PAD)
    if rd.reag:IsShown() then
        local n = 0
        for _, row in ipairs(rd.reag.rows) do if row:IsShown() then n = n + 1 end end
        rd.reag.note:SetWidth(inner)
        local noteH = rd.reag.note:IsShown() and textHeight(rd.reag.note) or 0
        for i, row in ipairs(rd.reag.rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rd.reag, "TOPLEFT", P.RD_BOX_PAD, -(P.RD_BOX_PAD + P.RD_HEAD_H + (i - 1) * P.RD_REAG_H))
            row:SetWidth(inner)
        end
        place(rd.reag, P.RD_BOX_PAD + P.RD_HEAD_H + n * P.RD_REAG_H + noteH + P.RD_BOX_PAD)
    end
    if rd.guild:IsShown() then
        rd.who:SetWidth(inner)
        local whoH = textHeight(rd.who)
        place(rd.guild, P.RD_BOX_PAD + P.RD_HEAD_H + P.RD_CTRL_H + whoH + 4 + P.RD_CTRL_H + P.RD_BOX_PAD)
    end
    rd.child:SetHeight(math.max(1, -y))
end

-- An entry in the detail (D-82): a recipe (also from the favourites and the favor view) or a camp
-- object, whose recipe, when the data has it, fills the same boxes.
local function showRecipe(f, e)
    local rd = f.rd
    rd.entry = e
    local r = entryRecipe(e)
    local camp = e and e.camp
    if not r and not camp then
        rd.iconFrame.icon:SetTexture(Pr.ICON_UNKNOWN)
        rd.title:SetText("")
        rd.sub:SetText(GREY .. L["Ein Rezept wählen."] .. "|r")
        rd.scroll:Hide()
        rd.star:Hide()
        return
    end
    rd.scroll:Show()
    rd.star:SetShown(r ~= nil)
    local item = camp and camp.item or r.item
    rd.iconFrame.icon:SetTexture(entryIcon(item, r and r.spell))
    ringColor(rd.iconFrame, item)
    if camp then
        rd.title:SetText(itemText(item, campName(camp)))
    else
        rd.title:SetText(r.item > 0 and itemText(r.item, e.name) or color(Pr.COLORS.none, e.name))
    end
    if r then rd.star.icon:SetAlpha(Pr.IsFav(r.spell) and 1 or P.STAR_OFF) end
    -- the quiet line: the upgrade, the profession (camp: Lager), the guild
    local parts = {}
    local mark = upgradeMark(item)
    if mark then parts[#parts + 1] = L["Upgrade: %s"]:format(mark) end
    if camp then parts[#parts + 1] = L["Lager"] end
    if r then parts[#parts + 1] = Pr.Name(r.skill) end
    if r and guildKnows(r.spell) then parts[#parts + 1] = GREEN .. L["In der Gilde bekannt"] .. "|r" end
    rd.sub:SetText(table.concat(parts, " · "))
    local text, src = "", {}
    if r then text, src = detailsText(r) end
    if camp then text = campText(camp) .. (r and ("\n\n" .. text) or "") end
    rd.info:SetText(text)
    rd.point = nil
    for _, s in ipairs(src or {}) do
        if s.point then
            rd.point, rd.pointLabel = s.point, s.text
            break
        end
    end
    rd.go:SetShown(rd.point ~= nil)
    rd.count:SetShown(r ~= nil)
    rd.add:SetShown(r ~= nil)
    rd.reag:SetShown(r ~= nil)
    rd.guild:SetShown(r ~= nil)
    if not r then
        layoutRecipe(rd)
        return
    end
    -- the reagents with the own count (bags and bank) and the alts' (F-159); the head with how often
    -- a known recipe can be crafted now
    local list = Pr.Reagents(r.spell)
    for i, g in ipairs(list or {}) do
        local row = reagentRow(rd.reag, i)
        row.item = g[1]
        row.icon:SetTexture(entryIcon(g[1]))
        row.name:SetText(itemText(g[1]))
        row.have:SetText(haveText(Route.Have(g[1]), Route.Twinks(g[1]), g[2]))
        row:Show()
    end
    local head = L["Reagenzien"]
    if Pr.Known(r.spell, r.skill) == true then
        local now, bank = Route.Craftable(r.spell)
        if now then
            head = head .. " " .. GREY .. L["· herstellbar: %d"]:format(now)
                .. (bank > now and (" " .. L["(%d mit Bank)"]:format(bank)) or "") .. "|r"
        end
    end
    rd.reag.head:SetText(head)
    for i = #(list or {}) + 1, #rd.reag.rows do rd.reag.rows[i]:Hide() end
    rd.reag.note:SetShown(list == nil or #list == 0)
    rd.reag.note:SetText(GREY .. (list and L["Keine Reagenzien."] or L["Reagenzien: noch unbekannt (Client antwortet nicht)"]) .. "|r")
    -- the guild
    local offline = state().offline and true or false
    rd.offline:SetChecked(offline)
    local who, any = guildText(r.spell, offline)
    rd.who:SetText(who)
    rd.guild.ground:SetColorTexture(unpack(any and P.RD_GUILD_BG or P.RD_BOX_BG))
    rd.askWho = Cr.AskWhom(r.spell)
    rd.ask:SetShown(rd.askWho ~= nil)
    layoutRecipe(rd)
end

local function buildRecipeDetail(f, top)
    local rd = W.Inset(f)
    rd:SetPoint("TOPLEFT", P.DETAIL_X, top)
    rd:SetPoint("TOPRIGHT", 0, top)
    rd:SetHeight(f.list:GetHeight())
    rd.layoutRole = "detail"
    local fit = f.list.Fit
    f.list.Fit = function(l, n)
        fit(l, n)
        rd:SetHeight(l:GetHeight())
    end
    rd.iconFrame = roundFrame(rd, P.RD_ICON, P.RD_PAD)
    rd.iconFrame:ClearAllPoints()
    rd.iconFrame:SetPoint("TOPLEFT", P.RD_PAD, -P.RD_PAD)
    rd.star = W.IconButton(rd, P.STAR, { file = P.STAR_ICON }, function()
        local r = entryRecipe(rd.entry)
        if not r then return end
        Pr.SetFav(r.spell, not Pr.IsFav(r.spell))
        ns.Refresh()
    end, "*")
    rd.star:SetPoint("TOPRIGHT", -P.RD_PAD, -P.RD_PAD)
    W.Tooltip(rd.star, L["Favorit"], L["Merkt das Rezept unter Favoriten (für diesen Charakter)."])
    rd.title = W.Text(rd, T.FONT.title)
    rd.title:SetPoint("TOPLEFT", P.RD_TITLE_X, P.RD_TITLE_Y)
    rd.title:SetPoint("RIGHT", rd.star, "LEFT", -4, 0)
    rd.head = CreateFrame("Button", nil, rd)
    rd.head:SetPoint("TOPLEFT", rd.iconFrame, "TOPLEFT")
    rd.head:SetPoint("BOTTOMRIGHT", rd.iconFrame, "BOTTOMRIGHT")
    rd.sub = W.Text(rd, T.FONT.hint)
    rd.sub:SetPoint("TOPLEFT", P.RD_TITLE_X, P.RD_SUB_Y)
    rd.sub:SetPoint("RIGHT", -P.RD_PAD, 0)
    rd.scroll = CreateFrame("ScrollFrame", nil, rd)
    rd.scroll:SetPoint("TOPLEFT", P.RD_PAD, -P.RD_BODY_Y)
    rd.scroll:SetPoint("BOTTOMRIGHT", -(P.RD_PAD + T.SCROLL_ROOM - T.SCROLLBAR_GAP), P.RD_PAD)
    rd.child = CreateFrame("Frame", nil, rd.scroll)
    rd.child:SetSize(rdWidth(), 10)
    rd.scroll:SetScrollChild(rd.child)
    W.Scroll(rd.scroll, rd)
    -- Details: the text, then the count with "+ Liste" and the waypoint
    rd.details = newBox(rd.child, L["Details"])
    rd.info = W.Text(rd.details, T.FONT.text, rdWidth() - 2 * P.RD_BOX_PAD, true)
    rd.info:SetJustifyV("TOP")
    rd.info:SetPoint("TOPLEFT", P.RD_BOX_PAD, -(P.RD_BOX_PAD + P.RD_HEAD_H))
    rd.count = W.Stepper(rd.details, P.RD_COUNT_W)
    rd.count:Configure(1, 99, 1)
    rd.count:SetValue(1)
    rd.count:SetPoint("BOTTOMLEFT", P.RD_BOX_PAD, P.RD_BOX_PAD)
    W.Tooltip(rd.count, L["Anzahl"], L["Wie oft du es herstellen willst (Shift: zehn auf einmal)."])
    rd.add = W.Link(rd.details, L["+ Liste"], function()
        local r = entryRecipe(rd.entry)
        if not r then return end
        if Pr.QueueAdd(r.spell, rd.count.current or 1) then
            ns.msg(L["%dx %s auf der Herstellliste."]:format(rd.count.current or 1, rd.entry.name or Pr.RecipeName(r)))
        else
            ns.msg(L["Die Herstellliste ist voll."])
        end
        ns.Refresh()
    end)
    W.FitChip(rd.add)
    rd.add:SetPoint("LEFT", rd.count, "RIGHT", T.LAYOUT.ITEM_GAP, 0)
    W.Tooltip(rd.add, L["+ Liste"], L["Setzt das Rezept so oft auf die Herstellliste; dort stehen alle Reagenzien zusammen."])
    rd.go = W.Link(rd.details, L["Wegpunkt"], function()
        if rd.point and ns.MapSetPoint then
            local ok, why = ns.MapSetPoint(rd.point, rd.pointLabel)
            if not ok and why then ns.msg(why) end
        end
    end)
    W.FitChip(rd.go)
    rd.go:SetPoint("BOTTOMRIGHT", -P.RD_BOX_PAD + T.TAB_PAD, P.RD_BOX_PAD)
    W.Tooltip(rd.go, L["Wegpunkt"], L["Setzt den Wegpunkt auf die erste Quelle mit Ort."])
    -- Reagenzien
    rd.reag = newBox(rd.child, L["Reagenzien"])
    rd.reag.rows = {}
    rd.reag.note = W.Text(rd.reag, T.FONT.text, rdWidth() - 2 * P.RD_BOX_PAD, true)
    rd.reag.note:SetPoint("TOPLEFT", P.RD_BOX_PAD, -(P.RD_BOX_PAD + P.RD_HEAD_H))
    -- the guild's crafters: "Offline zeigen", the names, "Fragen"
    rd.guild = newBox(rd.child, L["Gildenmitglieder, die es können"])
    rd.offline = W.Toggle(rd.guild, function(on)
        state().offline = on or nil
        ns.Refresh()
    end)
    rd.offline:SetPoint("TOPLEFT", P.RD_BOX_PAD, -(P.RD_BOX_PAD + P.RD_HEAD_H + 2))
    rd.offlineLabel = W.Text(rd.guild, T.FONT.text)
    rd.offlineLabel:SetPoint("LEFT", rd.offline, "RIGHT", 4, 0)
    rd.offlineLabel:SetText(L["Offline zeigen"])
    rd.who = W.Text(rd.guild, T.FONT.text, rdWidth() - 2 * P.RD_BOX_PAD, true)
    rd.who:SetJustifyV("TOP")
    rd.who:SetPoint("TOPLEFT", P.RD_BOX_PAD, -(P.RD_BOX_PAD + P.RD_HEAD_H + P.RD_CTRL_H))
    rd.ask = W.Link(rd.guild, L["Fragen"], function()
        local r, who = entryRecipe(rd.entry), rd.askWho
        if not r or not who then return end
        local link
        if r.item > 0 then link = select(3, Pr.ItemInfo(r.item)) end
        Cr.Whisper(who.name, link or rd.entry.name or Pr.RecipeName(r))
    end)
    W.FitChip(rd.ask)
    rd.ask:SetPoint("BOTTOMLEFT", P.RD_BOX_PAD - T.TAB_PAD, P.RD_BOX_PAD)
    W.Tooltip(rd.ask, L["Fragen"], L["Öffnet ein Flüstern an jemanden aus der Gilde, der das Rezept kennt (online zuerst)."])
    W.FollowWidth(rd, function() if rd:IsShown() and rd.entry then layoutRecipe(rd) end end)
    rd:Hide()
    return rd
end

---------------------------------------------------------------------------
-- The route (F-137): steps and shopping list
---------------------------------------------------------------------------
local FAV, QUEUE = "fav", "queue"   -- settings.professions.mode besides RECIPES and ROUTE (D-82)
local function mode()
    local m = state().mode
    if m == ROUTE or m == FAV or m == QUEUE then return m end
    return RECIPES
end
local function routeShown(v) return mode() == ROUTE and type(v) == "number" and Route.Has(v) end
local function money(c) return Pr.Money(math.floor((c or 0) + 0.5)) end
local function times(n) return math.max(0, math.ceil((n or 0) - 1e-6)) end
local function colorWord(c) return color(Pr.COLORS[c] or Pr.COLORS.none, COLOR_WORDS[c] or "?") end

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
    mine = L["sammeln: Bergbau"], drop = "Drop", world = L["Weltdrop"], quest = L["Questbelohnung"],
    disenchant = L["entzaubern"], farm = L["farmen oder Auktionshaus"] }
local function sourceText(e)
    if e.kind == "craft" then return L["herstellen: %s"]:format(Pr.Name(e.from)) end
    if e.kind == "gather" then return L["sammeln: %s"]:format(Pr.Name(e.from)) end
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
    addHolders(e.item)
    GameTooltip:AddLine(L["Klick: woher es kommt (Händler, Sammeln, Drop, Rezept)."], 0.6, 0.6, 0.6, true)
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
-- The overview (F-151, D-78): the own professions, all professions, camp and favor as cards in
-- sections; the side bar's marks name the same views
---------------------------------------------------------------------------
local function profIcon(skill)
    return { file = Pr.ICONS[Pr.Key(skill) or ""] or Pr.ICON_UNKNOWN, coords = P.ICON_COORDS }
end

local function hasCamp() return #Pr.Camp() > 0 end
local function hasFavor()
    local d = ns.Data("PROFESSIONS")
    return type(d) == "table" and type(d.FAVOR) == "table"
end

-- Shows a view of the page: OVERVIEW, a skill line, CAMP or FAVOR; recipes: the recipe list, not
-- the route (a card of the overview).
local function openView(v, recipes)
    local s = state()
    s.view = v
    chosen()
    if recipes then s.mode = RECIPES end
    ns.Refresh()
end

-- The marks of the side bar (D-75): Übersicht, each profession of the data with its icon, then a
-- block with Lager and Händlergunst (the own favor at the right); the shown view is chosen.
local function marks()
    if not Pr.Available() then return {} end
    local v = view()
    local out = { { key = OVERVIEW, label = L["Übersicht"], icon = MARKS.overview, on = v == OVERVIEW } }
    for i, skill in ipairs(Pr.Skills()) do
        out[#out + 1] = { key = skill, label = Pr.Name(skill), icon = profIcon(skill), on = v == skill, rule = i == 1 }
    end
    local camp = hasCamp()
    if camp then out[#out + 1] = { key = CAMP, label = L["Lager"], icon = MARKS.camp, on = v == CAMP, rule = true } end
    if hasFavor() then
        out[#out + 1] = { key = FAVOR, label = L["Händlergunst"], icon = MARKS.favor, on = v == FAVOR, rule = not camp,
            count = Pr.FavorAmount() }
    end
    return out
end

local function setArt(tex, art)
    if art.atlas and tex.SetAtlas then
        tex:SetAtlas(art.atlas)
    else
        tex:SetTexture(art.file)
        if art.coords then tex:SetTexCoord(unpack(art.coords)) else tex:SetTexCoord(0, 1, 0, 1) end
    end
end

-- The sections: { title, cards = { { icon, name, sub, open, tip } }, wide, none }.
local function overviewSections()
    local own = {}
    for _, p in ipairs(Pr.Own()) do
        if Pr.Key(p.skill) then
            local skill, known = p.skill, Pr.KnownCount(p.skill)
            own[#own + 1] = { icon = profIcon(skill), name = Pr.Name(skill),
                sub = known and L["Rang %d/%d · %d bekannt"]:format(p.rank, p.max, known) or L["Rang %d/%d"]:format(p.rank, p.max),
                short = known and L["%d/%d · %d bekannt"]:format(p.rank, p.max, known) or nil,
                open = function() openView(skill, true) end,
                tip = known and L["Klick: die Rezepte des Berufs."]
                    or (L["Klick: die Rezepte des Berufs."] .. " " .. L["Für \"Bekannt\" das Berufsfenster einmal öffnen."]) }
        end
    end
    local all = {}
    for _, skill in ipairs(Pr.Skills()) do
        local n, known = #Pr.Recipes(skill), Pr.KnownCount(skill)
        all[#all + 1] = { icon = profIcon(skill), name = Pr.Name(skill),
            sub = known and L["%s · %d bekannt"]:format(recipesText(n), known) or recipesText(n),
            short = known and L["%d/%d bekannt"]:format(known, n) or nil,
            open = function() openView(skill, true) end, tip = L["Klick: die Rezepte des Berufs."] }
    end
    local more = {}
    if hasCamp() then
        more[#more + 1] = { icon = MARKS.camp, name = L["Lager"], sub = L["Lagerobjekte aller Berufe"],
            open = function() openView(CAMP) end, tip = hintText(CAMP) }
    end
    if hasFavor() then
        local amount = Pr.FavorAmount()
        more[#more + 1] = { icon = MARKS.favor, name = L["Händlergunst"],
            sub = amount and L["Du hast %d Gunst · wie du sie bekommst"]:format(amount) or L["Rezepte für Gunst und wie du sie bekommst"],
            open = function() openView(FAVOR) end,
            tip = L["Klick: die Rezepte für Händlergunst, ihre Händler und wie du Gunst bekommst."] }
    end
    local secs = { { title = L["Deine Berufe"], cards = own, none = L["Noch kein Beruf erlernt."] },
        { title = L["Alle Berufe"], cards = all } }
    if #more > 0 then secs[#secs + 1] = { title = L["Weiteres"], cards = more, wide = true } end
    -- the nearest trainer of each profession the own faction may use (the data's order: crafting,
    -- cooking, first aid, fishing, then gathering); a profession without one is left out
    local trainers = {}
    for _, skill in ipairs(Pr.Skills()) do
        local t = Pr.NearestTrainer(skill)
        if t then trainers[#trainers + 1] = { skill = skill, npc = t } end
    end
    if #trainers > 0 then secs[#secs + 1] = { title = L["Nächste Lehrer"], cards = {}, trainers = trainers } end
    return secs
end

local trainerTable   -- the table of "Nächste Lehrer" (built below)
local function cardTooltip(self)
    if not GameTooltip or not self.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.entry.name, 1, 0.82, 0)
    -- the whole line when the card shows its short form
    if self.entry.short then GameTooltip:AddLine(self.entry.sub, 1, 1, 1) end
    if self.entry.tip then GameTooltip:AddLine(self.entry.tip, 0.85, 0.85, 0.85, true) end
    GameTooltip:Show()
end

local function newCard(ov)
    local c = CreateFrame("Button", nil, ov.child)
    c:SetHeight(P.CARD_H)
    local bg, e = P.CARD_BG, P.CARD_EDGE
    W.Flat(c, bg[1], bg[2], bg[3], bg[4])
    W.Border(c, e[1], e[2], e[3], e[4])
    c.hover = c:CreateTexture(nil, "HIGHLIGHT")
    c.hover:SetAllPoints()
    c.hover:SetColorTexture(1, 1, 1, P.CARD_HOVER)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(P.CARD_ICON, P.CARD_ICON)
    c.icon:SetPoint("LEFT", P.CARD_PAD, 0)
    c.name = W.Text(c, P.CARD_NAME_FONT, 10)
    c.name:SetPoint("TOPLEFT", P.CARD_TEXT_X, P.CARD_NAME_Y)
    c.sub = W.Text(c, P.CARD_SUB_FONT, 10)
    c.sub:SetPoint("TOPLEFT", P.CARD_TEXT_X, P.CARD_SUB_Y)
    c:RegisterForClicks("LeftButtonUp")
    c:SetScript("OnClick", function(self) if self.entry and self.entry.open then self.entry.open() end end)
    c:SetScript("OnEnter", cardTooltip)
    c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    ov.cards[#ov.cards + 1] = c
    return c
end

-- A section head: gold text and a thin gold line after it that fades out to the right.
local function newHead(ov)
    local h = CreateFrame("Frame", nil, ov.child)
    h:SetHeight(P.SEC_H)
    h.text = W.Text(h, T.FONT.title)
    h.text:SetPoint("LEFT", T.LAYOUT.TEXT_X, 0)
    local t = h:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(1, 1, 1, 1)
    local g, a = W.GOLD, P.SEC_LINE_A
    local ok = t.SetGradient and CreateColor and pcall(t.SetGradient, t, "HORIZONTAL",
        CreateColor(g[1], g[2], g[3], a), CreateColor(g[1], g[2], g[3], 0))
    if not ok then t:SetColorTexture(g[1], g[2], g[3], a / 2) end
    t:SetPoint("LEFT", h.text, "RIGHT", P.SEC_LINE_GAP, 0)
    t:SetPoint("RIGHT", h, "RIGHT", 0, 0)
    h.line = t
    ov.heads[#ov.heads + 1] = h
    return h
end

-- Places the sections in the scroll child at the page's width now (D-71): the cards in as many
-- columns of at least CARD_MIN_W as fit (CARD_COLS_MIN to CARD_COLS_MAX), the wide ones WIDE_COLS.
local function layoutOverview(ov)
    local width = (T.PAGE_W_NOW or T.PAGE_W) - T.SCROLL_ROOM
    ov.child:SetWidth(width)
    local y, nCards, nHeads = 0, 0, 0
    local shownTrainers = false
    ov.none:Hide()
    for si, sec in ipairs(ov.secs or {}) do
        if si > 1 then y = y - P.SEC_GAP end
        nHeads = nHeads + 1
        local h = ov.heads[nHeads] or newHead(ov)
        h.text:SetText(sec.title)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", ov.child, "TOPLEFT", 0, y)
        h:SetPoint("TOPRIGHT", ov.child, "TOPRIGHT", 0, y)
        h:Show()
        y = y - P.SEC_H
        if #sec.cards == 0 and sec.none then
            ov.none:SetText(sec.none)
            ov.none:ClearAllPoints()
            ov.none:SetPoint("TOPLEFT", ov.child, "TOPLEFT", T.LAYOUT.TEXT_X, y)
            ov.none:Show()
            y = y - T.LAYOUT.LINE_H
        end
        local cols = sec.wide and P.WIDE_COLS or math.max(P.CARD_COLS_MIN,
            math.min(P.CARD_COLS_MAX, math.floor((width + P.CARD_GAP) / (P.CARD_MIN_W + P.CARD_GAP))))
        local cw = math.floor((width - (cols - 1) * P.CARD_GAP) / cols)
        local items = {}
        for _, e in ipairs(sec.cards) do
            nCards = nCards + 1
            local c = ov.cards[nCards] or newCard(ov)
            c.entry = e
            c:SetWidth(cw)
            setArt(c.icon, e.icon)
            local tw = cw - P.CARD_TEXT_X - P.CARD_PAD
            c.name:SetWidth(tw)
            c.sub:SetWidth(tw)
            c.name:SetText(e.name)
            c.sub:SetText(e.sub)
            -- a narrow card: the short form ("12/564 bekannt"), the whole line in the tooltip
            if e.short and (c.sub:GetStringWidth() or 0) > tw then c.sub:SetText(e.short) end
            c:Show()
            items[#items + 1] = c
        end
        if #items > 0 then y = W.Grid(ov.child, items, cols, P.CARD_GAP, P.CARD_GAP, 0, y) end
        if sec.trainers then
            local tl, nCols = ov.trainers, P.TRAINER_COLS
            local rows = {}
            for i, e in ipairs(sec.trainers) do
                local r = math.floor((i - 1) / nCols) + 1
                rows[r] = rows[r] or {}
                rows[r][#rows[r] + 1] = e
            end
            ov.trainerW = math.floor(width / nCols)
            tl:ClearAllPoints()
            tl:SetPoint("TOPLEFT", ov.child, "TOPLEFT", 0, y)
            tl:SetWidth(width)
            tl:Fit(#rows)
            tl:SetItems(rows)
            tl:Show()
            shownTrainers = true
            y = y - #rows * P.TRAINER_H
        end
    end
    if not shownTrainers then ov.trainers:Hide() end
    for i = nCards + 1, #ov.cards do ov.cards[i]:Hide() end
    for i = nHeads + 1, #ov.heads do ov.heads[i]:Hide() end
    ov.child:SetHeight(math.max(1, -y))
end

-- "Nächste Lehrer": a framed table of TRAINER_COLS cells a row (a list without its bar, so the cells
-- may end in the client's ellipsis): the profession's icon and name, "Name, Zone" of its nearest
-- trainer and the map button that sets the waypoint (ns.MapSetPoint: the client's only where D-62
-- allows it).
local function hasFile(path) return not (GetFileIDFromPath and GetFileIDFromPath(path) == nil) end

local function trainerWhere(t)
    return ("%s, %s"):format(t.name or ("NPC " .. tostring(t.id)), Pr.ZoneName(t.point.map) or "?")
end

local function fillTrainers(r, cells)
    local cw = r.ov.trainerW or 190
    local tw = cw - P.TRAINER_TEXT_X - P.TRAINER_BTN - 2 * P.TRAINER_PAD
    for k, c in ipairs(r.cells) do
        local e = cells[k]
        c.entry = e
        if e then
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", r, "TOPLEFT", (k - 1) * cw, 0)
            c:SetSize(cw, P.TRAINER_H - 1)
            setArt(c.icon, profIcon(e.skill))
            c.name:SetWidth(tw)
            c.who:SetWidth(tw)
            c.name:SetText(Pr.Name(e.skill))
            c.who:SetText(trainerWhere(e.npc))
            c:Show()
        else
            c:Hide()
        end
    end
end

trainerTable = function(ov)
    local tl = W.List(ov.child, 1, P.TRAINER_H, function(r)
        r.ov = ov
        r.cells = {}
        for k = 1, P.TRAINER_COLS do
            local c = CreateFrame("Frame", nil, r)
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetSize(P.TRAINER_ICON, P.TRAINER_ICON)
            c.icon:SetPoint("LEFT", P.TRAINER_PAD, 0)
            c.name = W.Text(c, T.FONT.head, 10)
            c.name:SetPoint("TOPLEFT", P.TRAINER_TEXT_X, P.TRAINER_NAME_Y)
            c.who = W.Text(c, T.FONT.hint, 10)
            c.who:SetPoint("TOPLEFT", P.TRAINER_TEXT_X, P.TRAINER_LINE_Y)
            c.go = W.IconButton(c, P.TRAINER_BTN, hasFile(P.MAP_ART) and { file = P.MAP_ART } or {}, function(self)
                local e = self:GetParent().entry
                if not e or not ns.MapSetPoint then return end
                local ok, why = ns.MapSetPoint(e.npc.point, e.npc.name or Pr.Name(e.skill))
                if not ok and why then ns.msg(why) end
            end, "»")
            c.go:SetPoint("RIGHT", -P.TRAINER_PAD, 0)
            W.Tooltip(c.go, L["Wegpunkt"], function(self)
                local e = self:GetParent().entry
                if not e then return "" end
                local p = e.npc.point
                return L["Setzt den Wegpunkt zu %s (%d, %d)."]:format(trainerWhere(e.npc), math.floor(p.x * 100 + 0.5),
                    math.floor(p.y * 100 + 0.5))
            end)
            r.cells[k] = c
        end
    end, fillTrainers, { bar = false })
    -- the overview's scroll frame takes the wheel; a thin frame round the table
    tl:EnableMouseWheel(false)
    local e = P.TRAINER_EDGE
    W.Border(tl, e[1], e[2], e[3], e[4])
    tl:Hide()
    return tl
end

local function buildOverview(f)
    -- under the page's top: the line of explanation, then the sections in a scroll frame with the
    -- client's thin bar
    local ov = W.Page(f, { view = true, top = 0 })
    ov:Bands({ "line" })
    ov.intro = ov:Line(1)
    ov.intro:SetText(L["Wähle einen Beruf: seine Rezepte, wo du sie lernst, Reagenzien und wer in der Gilde sie kann."])
    ov.scroll = CreateFrame("ScrollFrame", nil, ov)
    ov.scroll:SetPoint("TOPLEFT", 0, ov.top)
    ov.scroll:SetPoint("BOTTOMRIGHT", -T.SCROLL_ROOM, 0)
    ov.child = CreateFrame("Frame", nil, ov.scroll)
    ov.child:SetSize(T.PAGE_W - T.SCROLL_ROOM, 10)
    ov.scroll:SetScrollChild(ov.child)
    W.Scroll(ov.scroll, ov)
    ov.cards, ov.heads = {}, {}
    ov.trainers = trainerTable(ov)
    ov.none = W.Text(ov.child, T.FONT.hint)
    ov.none:Hide()
    W.FollowWidth(ov, function() if ov:IsShown() then layoutOverview(ov) end end)
    ov:Hide()
    return ov
end

---------------------------------------------------------------------------
-- Refresh and build
---------------------------------------------------------------------------
-- The line under the page: the profession data's date and client.
local function dataLine(f)
    local d = ns.Data("PROFESSIONS")
    f.data:SetText(L["Berufsdaten vom %s (Client %s) · Namen aus dem Client."]:format(d and d.built or "?", d and d.client or "?"))
end

local function choose(e)
    if not e or not page then return end
    local k = e.camp and e.camp.item or e.recipe.spell
    state().sel[page.shownKey or tostring(page.shownView)] = k
    page.selected = e
    page.list:Redraw()
    showRecipe(page, e)
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

---------------------------------------------------------------------------
-- The crafting list (D-82): the queued recipes with their count, the reagents of all of them
---------------------------------------------------------------------------
local function fillQueue(r, e)
    r.iconFrame.icon:SetTexture(entryIcon(e.recipe.item, e.recipe.spell))
    ringColor(r.iconFrame, e.recipe.item)
    local name = e.recipe.item > 0 and itemText(e.recipe.item, Pr.RecipeName(e.recipe)) or Pr.RecipeName(e.recipe)
    local now = Pr.Known(e.recipe.spell, e.recipe.skill) == true and Route.Craftable(e.recipe.spell) or nil
    if now then name = name .. " " .. (now >= e.n and GREEN or GREY) .. ("(%d)"):format(now) .. "|r" end
    r.name:SetText(name)
    r.n:SetText(("%dx"):format(e.n))
end

local function fillNeed(r, e)
    r.icon:SetTexture(entryIcon(e.item))
    r.name:SetText(itemText(e.item))
    r.have:SetText(haveText(e.have, e.twinks, e.need))
    local where = sourceText(e)
    if e.kind == "vendor" then
        local npc = nearestVendor(e.vendors)
        if npc and npc.name then where = L["Händler: %s"]:format(npc.name) end
        if e.price then where = where .. " · " .. money(e.price) end
    end
    if e.twinks > 0 then where = where .. " · " .. L["Twinks: %d"]:format(e.twinks) end
    r.src:SetText(GREY .. where .. "|r")
end

local function refreshQueue(f)
    local q = Pr.Queue()
    f.qlist:SetItems(q)
    local need, unknown = Pr.QueueNeeds()
    local shop = Route.ShoppingFor(need, nil)
    f.qneed:SetItems(shop)
    local crafts = 0
    for _, e in ipairs(q) do crafts = crafts + e.n end
    f.counts:SetText(L["%d Rezepte, %d Herstellungen"]:format(#q, crafts)
        .. (unknown and (" · " .. L["Reagenzien teils unbekannt"]) or ""))
    f.qempty:SetShown(#q == 0)
    f.clearQueue:SetShown(#q > 0)
end

local function buildQueue(f, top)
    local qv = W.Page(f, { view = true, top = top })
    f.queueView = qv
    f.qlist = qv:List(P.ROWS, P.ROW_H, function(r)
        local e = P.ROW_EDGE
        W.Border(r, e[1], e[2], e[3], e[4])
        r.iconFrame = roundFrame(r, P.ROW_ICON, P.ROW_ICON_X)
        r.del = W.Link(r, L["Entfernen"], function(self)
            local it = self:GetParent().item
            if it then
                Pr.QueueRemove(it.recipe.spell)
                ns.Refresh()
            end
        end)
        W.FitChip(r.del)
        r.del:SetPoint("RIGHT", -T.LAYOUT.TEXT_X + T.TAB_PAD, 0)
        r.n = W.Text(r, T.FONT.text, P.QUEUE_N_W)
        r.n:SetJustifyH("RIGHT")
        r.n:SetPoint("RIGHT", r.del, "LEFT", -T.LAYOUT.ITEM_GAP, 0)
        r.name = W.Text(r, T.FONT.text)
        r.name:SetPoint("LEFT", P.ROW_TEXT_X, 0)
        r.name:SetPoint("RIGHT", r.n, "LEFT", -T.LAYOUT.ITEM_GAP, 0)
        r:RegisterForClicks("LeftButtonUp")
        r:SetScript("OnClick", function(self)
            local it = self.item
            if it and ns.ShowRecipe then ns.ShowRecipe(it.recipe.skill, it.recipe.spell) end
        end)
        r:SetScript("OnEnter", function(self) if self.item then entryTooltip(self, self.item) end end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillQueue, { fill = true, width = P.LIST_W })
    f.qempty = qv:Empty(P.LIST_W - 10, f.qlist)
    f.qempty:Set(L["Die Herstellliste ist leer"], L["Im Rezept die Anzahl wählen, dann \"+ Liste\"."])
    f.qneed = qv:List(P.ROWS, P.NEED_H, function(r)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(P.RD_REAG_ICON, P.RD_REAG_ICON)
        r.icon:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X, P.LINE1_Y)
        r.have = W.Text(r, T.FONT.text, P.NEED_HAVE_W)
        r.have:SetJustifyH("RIGHT")
        r.have:SetPoint("TOPRIGHT", -T.LAYOUT.TEXT_X, P.LINE1_Y)
        r.name = W.Text(r, T.FONT.text)
        r.name:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X + P.RD_REAG_ICON + 4, P.LINE1_Y)
        r.name:SetPoint("RIGHT", r.have, "LEFT", -4, 0)
        r.src = W.Text(r, T.FONT.hint)
        r.src:SetPoint("TOPLEFT", T.LAYOUT.TEXT_X + P.RD_REAG_ICON + 4, P.LINE2_Y)
        r.src:SetPoint("RIGHT", -T.LAYOUT.TEXT_X, 0)
        r:RegisterForClicks("LeftButtonUp")
        r:SetScript("OnClick", function(self) if self.item then whereMenu(self, self.item.item) end end)
        r:SetScript("OnEnter", function(self) shopTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillNeed, { fill = true, x = P.DETAIL_X })
    qv:Hide()
    return qv
end

-- The favourites as list entries (all professions, D-82).
local function favList()
    local ranks = {}
    for _, p in ipairs(Pr.Own()) do ranks[p.skill] = p.rank end
    local out = {}
    for _, r in ipairs(Pr.Favs()) do
        local known = Pr.Known(r.spell, r.skill)
        out[#out + 1] = { recipe = r, name = Pr.RecipeName(r), known = known, color = Pr.Difficulty(r, ranks[r.skill], known) }
    end
    return out
end

-- The head band (D-82): the icon, "Schneiderei - Alle Rezepte", the skill and the recipes, the
-- legend, and the hint while the profession window was never read.
local function fillHead(f, v, m, n)
    local icon, title, line, note, legend = nil, "", "", "", false
    if type(v) == "number" then
        local name = Pr.Name(v)
        local rank, max = Pr.Rank(v)
        local all = #Pr.Recipes(v)
        local known = Pr.KnownCount(v)
        local skill = rank and L["Dein Skill: %d/%d"]:format(rank, max or 0) or L["Nicht erlernt"]
        local recipes = known and L["%d Rezepte, %d bekannt"]:format(all, known) or recipesText(all)
        if m == FAV then
            icon, title = { file = P.STAR_ICON }, L["Favoriten"]
            line = L["%d Favoriten aus allen Berufen · der Stern im Rezept merkt eins vor"]:format(n)
        elseif m == QUEUE then
            icon, title = T.NAV_ICONS.professions, L["Herstellliste"]
            line = L["Was du herstellen willst und alle Reagenzien dafür"]
        else
            icon, title = profIcon(v), L["%s - Alle Rezepte"]:format(name)
            line = skill .. " · " .. recipes
            if rank and not Pr.HasSnapshot(v) then
                note = L["Öffne einmal dein %s-Fenster, um bekannte Rezepte zu markieren."]:format(name)
            else
                -- the estimated learn ranks (F-155): a trainer of the profession tells the real ones
                local guessed = 0
                for _, r in ipairs(Pr.Recipes(v)) do if not Pr.LearnExact(r) then guessed = guessed + 1 end end
                if guessed > 0 then note = L["%d Lernstufen geschätzt (?) - sprich einmal einen Lehrer an, Amisia liest sie dort."]:format(guessed) end
            end
        end
        legend = m ~= QUEUE
    elseif v == CAMP then
        icon, title, line = MARKS.camp, L["Lager"], L["Lagerobjekte aller Berufe"]
    elseif v == FAVOR then
        icon, title, line = MARKS.favor, L["Händlergunst"], L["Rezepte für Gunst und wie du sie bekommst"]
    end
    if icon then setArt(f.headIcon.icon, icon) end
    f.title:SetText(title)
    f.rank:SetText(line)
    f.note:SetText(note)
    f.legend:SetShown(legend)
end

-- The tabs of the head row (D-82): which is on, the route only where the profession has one.
local function fillTabs(f, v, m, onRoute)
    f.tabAll:SetOn(type(v) == "number" and m == RECIPES)
    f.tabFav:SetOn(type(v) == "number" and m == FAV)
    f.tabFavor:SetOn(v == FAVOR)
    f.tabQueue:SetOn(type(v) == "number" and m == QUEUE)
    f.tabRoute:SetOn(onRoute)
    if (type(v) == "number" and Route.Has(v)) or onRoute then f.tabRoute:Enable() else f.tabRoute:Disable() end
end

local function refresh(f)
    local s = state()
    local v = view()
    -- the overview (D-78): its cards instead of the head row, the filters, the list and the route
    local over = v == OVERVIEW
    f.ovView:SetShown(over)
    if over then
        for _, w in ipairs(f.chrome) do w:Hide() end
        f.filters:Hide()
        f.shownView = v
        f.ovView.secs = overviewSections()
        layoutOverview(f.ovView)
        f.hint:SetText(L["Klick auf eine Kachel: die Rezepte des Berufs, das Lager oder die Händlergunst; links in der Leiste dasselbe."])
        dataLine(f)
        return
    end
    if type(v) == "number" then s.skill = v end
    local m = type(v) == "number" and mode() or nil
    local onRoute = routeShown(v)
    for _, t in ipairs(f.tabs) do t:Show() end
    fillTabs(f, v, m, onRoute)
    f:Place(1, f.tabs)
    f.routeView:SetShown(onRoute)
    f.queueView:SetShown(m == QUEUE and not onRoute)
    local listed = not onRoute and m ~= QUEUE
    f.list:SetShown(listed)
    f.headBlock:SetShown(not onRoute)
    if onRoute then
        for _, w in ipairs({ f.search, f.filterBtn, f.counts, f.empty, f.reset, f.rd, f.clearQueue }) do w:Hide() end
        f.filters:Hide()
        local rank, max = Pr.Rank(v)
        f.routeRank:SetText(rank and L["Dein Rang: %d / %d"]:format(rank, max or 0) or (GREY .. L["Beruf nicht erlernt"] .. "|r"))
        f.routeRank:Show()
        f:Place(1, f.tabs, { f.routeRank })
        f.shownView = v
        refreshRoute(f, v)
        f.hint:SetText(L["Klick auf einen Schritt: die Rezept-Details oder der Wegpunkt zum Händler. Kosten nur aus Händlerpreisen."])
        dataLine(f)
        return
    end
    f.routeRank:Hide()
    f.counts:Show()
    if m == QUEUE then
        for _, w in ipairs({ f.search, f.filterBtn, f.empty, f.reset, f.rd }) do w:Hide() end
        f.filters:Hide()
        fillHead(f, v, m, 0)
        f:Place(3, { { f.counts, fill = true } }, { f.clearQueue }, { shown = true })
        refreshQueue(f)
        f.shownView = v
        f.hint:SetText(L["Klick auf ein Rezept: seine Details. Klick auf ein Material vom Händler: der Wegpunkt zum nächsten."])
        dataLine(f)
        return
    end
    f.clearQueue:Hide()
    local isRecipes = type(v) == "number" and m == RECIPES
    local isFav = type(v) == "number" and m == FAV
    f.known:SetValue(s.known or "all")
    f.source:SetValue(s.source or "all")
    f.learn:SetOn(s.learnable and true or false)
    -- Gilde with its count; greyed at 0, then it can only be turned off
    local guildN = isRecipes and guildCount(v) or 0
    f.guildCount = guildN
    f.guild.label:SetText(L["Gilde (%d)"]:format(guildN))
    W.FitChip(f.guild)
    f.guild.dim = guildN == 0
    if guildN > 0 or s.guild then f.guild:Enable() else f.guild:Disable() end
    f.guild:SetOn(s.guild and true or false)
    f.filterBtn.dot:SetShown(#activeFilters() > 0)
    local text = s.search or ""
    if not f.search:HasFocus() and f.search:GetText() ~= text then f.search:SetText(text) end
    for _, w in ipairs({ f.known, f.source, f.learn, f.guild, f.search, f.filterBtn }) do
        if isRecipes then w:Show() else w:Hide() end
    end
    if not isRecipes then f.filters:Hide() end
    -- without the search and the filters (favourites, camp, favor) the counts take the whole band
    f:Place(3, { f.search, f.filterBtn, { f.counts, fill = true } }, nil, { shown = true })
    local key = isFav and FAV or tostring(v)
    if f.shownView ~= v or f.shownKey ~= key then f.list.offset = 0 end
    f.shownView, f.shownKey = v, key
    nameMissing = false
    local list = isFav and favList() or listOf(v)
    fillHead(f, v, m, #list)
    -- the chosen entry: kept by its spell (or camp item) per view
    local chosenKey = s.sel[key]
    f.selected = nil
    for _, e in ipairs(list) do
        local k = e.camp and e.camp.item or e.recipe.spell
        if k == chosenKey then f.selected = e end
    end
    f.selected = f.selected or list[1]
    f.list:SetItems(list)
    local canReset = false
    if #list == 0 then
        if isFav then
            f.empty:Set(L["Noch keine Favoriten"], L["Der Stern oben rechts im Rezept merkt es hier vor."])
        else
            local help = L["Für diesen Client gibt es keine Berufsdaten."]
            if Pr.Available() then help, canReset = emptyHelp(v) end
            f.empty:Set(L["Keine Rezepte"], help)
        end
        f.empty:Show()
    else
        f.empty:Hide()
    end
    f.reset:SetShown(canReset and isRecipes)
    -- every view's entry in the detail with the boxes (D-82): recipes, favourites, favor, camp
    f.rd:Show()
    showRecipe(f, f.selected)
    f.counts:SetText(isFav and L["%d Favoriten"]:format(#list) or statusText(v, #list))
    f.hint:SetText(hintText(v))
    dataLine(f)
end

local function create(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: the tabs (D-82); the head band: icon, title, skill, legend and hint; then the
    -- search with the filter menu and the counts
    local top = f:Bands({ "row", { "line", lines = P.HEAD_LINES }, "row" })
    local function newTab(label, tip, tabKey)
        local t = W.Tab(f, label, function()
            local s = state()
            local v = view()
            local skill = type(v) == "number" and v or (tonumber(s.skill) and Pr.Key(tonumber(s.skill)) and tonumber(s.skill))
                or Pr.Ordered()[1]
            chosen()
            if tabKey == "favor" then
                s.skill, s.view = skill, FAVOR
            else
                s.view, s.mode = skill, tabKey
            end
            ns.Refresh()
        end)
        W.FitChip(t)
        W.Tooltip(t, label, tip)
        return t
    end
    f.tabAll = newTab(L["Alle Rezepte"], L["Die Rezepte des Berufs mit Suche, Filtern und Details."], RECIPES)
    f.tabFav = newTab(L["Favoriten"], L["Die Rezepte, die du mit dem Stern gemerkt hast, aus allen Berufen."], FAV)
    f.tabFavor = newTab(L["Händlergunst"], L["Die Rezepte für Händlergunst, ihre Händler und wie du Gunst bekommst."], "favor")
    f.tabQueue = newTab(L["Herstellliste"], L["Was du herstellen willst, mit allen Reagenzien zusammen: was du hast und wo du den Rest kaufst."], QUEUE)
    f.tabRoute = newTab(L["Route"], L["Der günstigste Weg von deinem Rang bis zum Höchstrang: Schritte, Lehrer und Einkaufsliste. Nicht für Sammelberufe, Angeln, Lager und Händlergunst."], ROUTE)
    f.tabs = { f.tabAll, f.tabFav, f.tabFavor, f.tabQueue, f.tabRoute }
    f.modeRecipes, f.modeRoute = f.tabAll, f.tabRoute
    f.routeRank = W.Text(f, T.FONT.head, P.RANK_W)
    f.routeRank:SetJustifyH("RIGHT")
    f.routeRank:Hide()
    f:Place(1, f.tabs)

    -- the head band
    local hb = CreateFrame("Frame", nil, f)
    hb:SetHeight(P.HEAD_LINES * T.LAYOUT.LINE_H)
    f.headBlock = hb
    f.headIcon = roundFrame(hb, P.HEAD_ICON, 0)
    if f.headIcon.ring then f.headIcon.ringColor = { W.GOLD[1], W.GOLD[2], W.GOLD[3], 1 } f.headIcon.ring:SetVertexColor(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1) end
    f.legend = CreateFrame("Frame", nil, hb)
    f.legend:SetSize(P.LEGEND_W, T.LAYOUT.LINE_H)
    f.legend:SetPoint("TOPRIGHT", -T.LAYOUT.TEXT_X, 0)
    local function legendItem(tex, label, anchor)
        local d = f.legend:CreateTexture(nil, "ARTWORK")
        d:SetSize(P.DOT, P.DOT)
        d:SetTexture(tex)
        local fs = W.Text(f.legend, T.FONT.text)
        fs:SetText(label)
        if anchor then d:SetPoint("LEFT", anchor, "RIGHT", P.LEGEND_GAP, 0) else d:SetPoint("LEFT", 0, 0) end
        fs:SetPoint("LEFT", d, "RIGHT", P.DOT_GAP, 0)
        return fs
    end
    local me = legendItem(P.DOT_ME, L["Kann ich"])
    legendItem(P.DOT_GUILD, L["Gilde"], me)
    f.title = W.Text(hb, T.FONT.big)
    f.title:SetPoint("TOPLEFT", P.HEAD_TEXT_X, 0)
    f.title:SetPoint("RIGHT", f.legend, "LEFT", -T.LAYOUT.ITEM_GAP, 0)
    f.rank = W.Text(hb, T.FONT.text)
    f.rank:SetPoint("TOPLEFT", P.HEAD_TEXT_X, -T.LAYOUT.LINE_H - 2)
    f.rank:SetPoint("RIGHT", -T.LAYOUT.TEXT_X, 0)
    f.note = W.Text(hb, T.FONT.head)
    f.note:SetPoint("TOPLEFT", P.HEAD_TEXT_X, -2 * T.LAYOUT.LINE_H - 2)
    f.note:SetPoint("RIGHT", -T.LAYOUT.TEXT_X, 0)
    f:Place(2, { { hb, fill = true } })

    f.search = W.SearchBox(f, P.SEARCH_W, function(text)
        state().search = text ~= "" and text or nil
        ns.Refresh()
    end, L["Rezept suchen"])
    -- the filter menu: Amisia's funnel opens a small panel with the filters under it
    f.filterBtn = W.IconButton(f, P.FILTER_BTN, { file = P.FILTER_ICON }, function()
        f.filters:SetShown(not f.filters:IsShown())
    end, "F")
    W.Tooltip(f.filterBtn, L["Filter"], L["Bekannt, Quelle, Lernbar und Gilde. Der Punkt zeigt, dass ein Filter an ist."])
    f.filterBtn.dot = f.filterBtn:CreateTexture(nil, "OVERLAY")
    f.filterBtn.dot:SetSize(P.DOT, P.DOT)
    f.filterBtn.dot:SetTexture(P.DOT_ME)
    f.filterBtn.dot:SetPoint("TOPRIGHT", 2, 2)
    f.filterBtn.dot:Hide()
    f.filters = W.Inset(f)
    f.filters.fill(0.05, 0.04, 0.03, 0.97)
    f.filters:SetPoint("TOPLEFT", f.search, "BOTTOMLEFT", 0, -P.FLY_GAP)
    if f.filters.SetFrameLevel and f.GetFrameLevel then f.filters:SetFrameLevel((f:GetFrameLevel() or 0) + 30) end
    f.filters:Hide()
    f:HookScript("OnHide", function() f.filters:Hide() end)
    -- the two dropdowns name their filter in the field, so they don't read as on/off chips
    f.known = filterPicker(f.filters, L["Bekannt: %s"], KNOWN, function(v)
        state().known = v
        ns.Refresh()
    end)
    W.Tooltip(f.known, L["Bekannt"], L["Alle, nur bekannte oder nur unbekannte Rezepte. Was du kennst, liest Amisia aus dem offenen Berufsfenster."])
    f.source = filterPicker(f.filters, L["Quelle: %s"], SOURCES, function(v)
        state().source = v
        ns.Refresh()
    end)
    W.Tooltip(f.source, L["Quelle"], L["Woher das Rezept kommt: Lehrer, Händler, Händlergunst, Drop oder Quest."])
    f.learn = W.TabCheck(f.filters, L["Lernbar"], function()
        local s = state()
        s.learnable = not s.learnable or nil
        ns.Refresh()
    end)
    W.Tooltip(f.learn, L["Lernbar"], L["Nur unbekannte Rezepte, die dein Rang schon erlaubt."])
    f.guild = W.TabCheck(f.filters, L["Gilde (%d)"]:format(0), function()
        local s = state()
        s.guild = not s.guild or nil
        ns.Refresh()
    end)
    W.FitChip(f.guild)
    W.Tooltip(f.guild, L["Gilde"], function()
        if (f.guildCount or 0) == 0 then
            return L["Noch teilt niemand aus der Gilde Rezepte. Die Liste füllt sich, sobald Gildenmitglieder mit Amisia ihr Berufsfenster öffnen."]
        end
        return L["Nur Rezepte, die jemand aus der Gilde kennt (von Amisia-Nutzern geteilt)."]
    end)
    local flyW = W.Row(f.filters, { f.known, f.source, f.learn, f.guild }, T.LAYOUT.ITEM_GAP, P.FLY_PAD, -P.FLY_PAD)
    f.filters:SetSize(flyW + P.FLY_PAD, T.LAYOUT.ROW_H + 2 * P.FLY_PAD)
    f.counts = W.Text(f, T.FONT.hint)
    f.clearQueue = W.Link(f, L["Liste leeren"], function()
        Pr.QueueRemove(nil)
        ns.Refresh()
    end)
    W.FitChip(f.clearQueue)
    W.Tooltip(f.clearQueue, L["Liste leeren"], L["Nimmt alle Rezepte von der Herstellliste."])
    f.clearQueue:Hide()
    f:Place(3, { f.search, f.filterBtn, { f.counts, fill = true } })
    -- the hint takes two lines when it needs them (the favor vendors), the data line under it
    f:Footer({ { "hint", lines = 2, help = true }, { "data", help = true } })

    f.list = f:List(P.ROWS, P.ROW_H, function(r)
        buildRow(r)
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
    end, fillRow, { fill = true, top = top, width = P.LIST_W })
    f.empty = f:Empty(P.LIST_W - 10)
    -- under the empty state's help; a child of the list it stands over (the list holds it)
    f.reset = W.Link(f.list, L["Filter zurücksetzen"], resetFilters)
    W.FitChip(f.reset)
    f.reset:SetPoint("TOP", f.empty.text, "BOTTOM", 0, -T.EMPTY.BUTTON_GAP)
    f.reset:Hide()
    W.Tooltip(f.reset, L["Filter zurücksetzen"], L["Stellt Bekannt und Quelle auf Alle, schaltet Lernbar und Gilde aus und leert die Suche."])

    -- every entry in the detail with the boxes (D-82)
    f.rd = buildRecipeDetail(f, top)
    f.rd.head:SetScript("OnEnter", function(self) entryTooltip(self, f.rd.entry) end)
    f.rd.head:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    buildQueue(f, top)

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
    f.vendorT = W.Tab(rv, L["nur Lehrer"], function() setVendor(false) end)
    W.FitChip(f.vendorT)
    W.Tooltip(f.vendorT, L["nur Lehrer"], L["Die Route nimmt bekannte Rezepte und was der Lehrer bis zum nächsten Limit lehrt."])
    f.vendorV = W.Tab(rv, L["auch Händler"], function() setVendor(true) end)
    W.FitChip(f.vendorV)
    W.Tooltip(f.vendorV, L["auch Händler"], L["Dazu Rezepte, die ein Händler deiner Fraktion verkauft, mit dem Kaufpreis in den Kosten und einem Schritt \"Rezept kaufen\". Drop-Rezepte nie."])
    local function setTab(tab)
        state().routeTab = tab
        ns.Refresh()
    end
    f.tabSteps = W.Tab(rv, L["Schritte"], function() setTab("steps") end)
    W.FitChip(f.tabSteps)
    W.Tooltip(f.tabSteps, L["Schritte"], L["Die Route Schritt für Schritt; der aktuelle Schritt ist markiert, erledigte sind abgehakt."])
    f.tabShop = W.Tab(rv, L["Einkauf"], function() setTab("shop") end)
    W.FitChip(f.tabShop)
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
    end, fillStep, { fill = true })

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
        r:SetScript("OnClick", function(self) if self.item then whereMenu(self, self.item.item) end end)
        r:SetScript("OnEnter", function(self) shopTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillShop, { fill = true })
    rv:Hide()
    f.ovView = buildOverview(f)
    f.chrome = { f.tabAll, f.tabFav, f.tabFavor, f.tabQueue, f.tabRoute, f.routeRank, f.headBlock, f.search, f.filterBtn,
        f.counts, f.clearQueue, f.list, f.rd, f.empty, f.reset, f.routeView, f.queueView }
    return f
end

ns.RegisterPanel{ key = "professions", label = L["Berufe"], sub = L["Rezepte, der Weg zum nächsten Skill und die Hersteller der Gilde."], icon = ICON, order = 57, group = "prof",
    available = function() return Pr.Available() end, create = create, refresh = refresh,
    -- the side bar (D-78): Übersicht, the professions, Lager and Händlergunst; a click shows that view
    jumps = function() return marks() end, jump = function(_, key) openView(key) end }

-- Opens the page; what: a profession (German name or key, a prefix is enough), "übersicht", "lager"
-- or "gunst".
function ns.ShowProfessions(what)
    if AmisiaDB and AmisiaDB.settings and type(what) == "string" and what ~= "" then
        local w = ns.Fold(what)
        chosen()
        if w == "route" then
            state().mode = ROUTE
        elseif w:find("^übersicht") or w:find("^ubersicht") or w:find("^overview") then   -- l10n-ok: command words
            state().view = OVERVIEW
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
        chosen()
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
ns.Listen("PROF_LISTS_CHANGED", schedule)
ns.OnEvent("BAG_UPDATE_DELAYED", schedule)
-- the route waits in combat and the lockdown (ProfRoute.lua): computed again after them
ns.OnEvent("PLAYER_REGEN_ENABLED", schedule)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", schedule)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if nameMissing then schedule() end
end)
