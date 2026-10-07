-- Professions page: the recipes of one profession in the colours of the client's recipe list (the
-- own rank decides), filtered by name, known/unknown, learnable and source; the chosen recipe in
-- the detail field (what it makes with the upgrade mark, the four difficulty steps, reagents with
-- the own count, where it comes from, Merchant's Favor and crafting orders). Two more views in the
-- profession picker: the camp objects ("Lager") and the Merchant's Favor ("Händlergunst").
local ADDON, ns = ...
local W, Pr, T = ns.W, ns.Prof, ns.Theme
local GREY = T.GREY
local GREEN = "|cff40bf40"
local ICON = "Interface\\Icons\\Trade_BlackSmithing"
local ROWS, ROW_H = 17, 22
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local SOURCES = { { "all", "Alle Quellen" }, { "T", "Lehrer" }, { "V", "Händler" }, { "F", "Händlergunst" },
    { "D", "Drop" }, { "Q", "Quest" } }
local KNOWN = { { "all", "Alle" }, { "known", "Bekannt" }, { "unknown", "Unbekannt" } }
local CAMP, FAVOR = "camp", "favor"
local ROW_HINT = "Klick: Details. Shift-Klick: Link in den Chat."

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
ns.ProfUpgradeMark = upgradeMark

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
        source = s.source ~= "all" and s.source or nil })
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
        r.mark:SetText(c.slots > 0 and (GREY .. c.slots .. " Pl.|r") or "")
        r.rank:SetText(c.skill > 0 and (GREY .. c.rank .. "|r") or "")
        return
    end
    local rec = e.recipe
    local col = Pr.COLORS[e.color] or Pr.COLORS.none
    local name = e.name
    if e.known == true then name = name .. " " .. GREY .. "(bekannt)|r" end
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
    if not list then return { GREY .. "Reagenzien: noch unbekannt (Client antwortet nicht)|r" } end
    local out = { "Reagenzien:" }
    for _, e in ipairs(list) do
        local have = Pr.Count(e[1])
        local mark = have >= e[2] and GREEN or "|cffff6060"
        out[#out + 1] = ("  %dx %s %s(%d)|r"):format(e[2], itemText(e[1]), mark, have)
    end
    if from == "client" then out[#out + 1] = GREY .. "  (aus dem Client)|r" end
    return out
end

local function recipeDetail(r)
    local lines = {}
    local rank = Pr.Rank(r.skill)
    local known = Pr.Known(r.spell, r.skill)
    lines[#lines + 1] = ("%s · Fertigkeit %s"):format(Pr.Name(r.skill), steps(r))
    if rank then
        local d = Pr.Difficulty(r, rank, known)
        local word = ({ orange = "orange", yellow = "gelb", green = "grün", grey = "grau", red = "noch nicht lernbar" })[d]
        lines[#lines + 1] = ("Dein Rang %d%s"):format(rank, word and (": " .. color(Pr.COLORS[d], word)) or "")
    end
    if known == true then
        lines[#lines + 1] = GREEN .. "Bekannt|r"
    elseif known == false then
        lines[#lines + 1] = "Nicht bekannt" .. (r.learn > 1 and (" (lernbar ab %d)"):format(r.learn) or "")
    elseif rank then
        lines[#lines + 1] = GREY .. "Ob bekannt: Berufsfenster einmal öffnen.|r"
    end
    if r.count > 1 then lines[#lines + 1] = ("Stellt %d Stück her."):format(r.count) end
    lines[#lines + 1] = ""
    for _, l in ipairs(reagentLines(r)) do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Quelle:"
    local src = Pr.Sources(r)
    for _, s in ipairs(src) do lines[#lines + 1] = "  " .. s.text end
    for _, itemId in ipairs(r.items) do
        local ri = Pr.RecipeItem(itemId)
        if ri then
            local need = {}
            if ri.rank > 0 then need[#need + 1] = ("Rang %d"):format(ri.rank) end
            if ri.faction > 0 then need[#need + 1] = ("Ruf %s"):format(Pr.STANDING[ri.standing] or "?") end
            lines[#lines + 1] = ("  Rezept: %s%s"):format(itemText(itemId), #need > 0 and (GREY .. " (" .. table.concat(need, ", ") .. ")|r") or "")
        end
    end
    if Pr.HasWrit(r) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Handwerksauftrag für dieses Item möglich (Händlergunst)."
    end
    return table.concat(lines, "\n"), src
end

local function campDetail(c)
    local lines = {}
    if c.skill > 0 then
        local rank = Pr.Rank(c.skill)
        lines[#lines + 1] = ("%s · ab Rang %d%s"):format(Pr.Name(c.skill), c.rank, rank and (" (dein Rang %d)"):format(rank) or "")
    end
    if c.slots > 0 then lines[#lines + 1] = ("Lagerfeuer mit %d Plätzen für weitere Lagerobjekte."):format(c.slots) end
    if c.over > 0 then
        local other
        for _, o in ipairs(Pr.Camp()) do if o.item == c.over then other = o end end
        lines[#lines + 1] = ("Ersetzt %s und behält dessen Wirkung."):format(other and campName(other) or ("Item " .. c.over))
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = Pr.SpellDescription(c.use) or (GREY .. "Beschreibung lädt ...|r")
    local r = c.recipe > 0 and Pr.Recipe(c.recipe)
    local src = {}
    if r then
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("Herstellen: %s"):format(steps(r))
        for _, l in ipairs(reagentLines(r)) do lines[#lines + 1] = l end
        lines[#lines + 1] = "Quelle:"
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
        d.body:SetText(GREY .. "Ein Rezept wählen.|r")
        d.go:Disable()
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
        sub = mark and ("Upgrade: " .. mark .. (u and u.slotKey and (GREY .. " (" .. tostring(u.slotKey) .. ")|r") or "")) or ""
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
    values[#values + 1] = { value = CAMP, text = "Lager (Camping)" }
    values[#values + 1] = { value = FAVOR, text = "Händlergunst" }
    return values
end

local function statusText(v, n)
    if v == CAMP then return ("%d Lagerobjekte"):format(n) end
    if v == FAVOR then
        local fav = Pr.Favor() or {}
        local parts = { ("%d Rezepte"):format(n) }
        if fav.amount then parts[#parts + 1] = ("%s: %d"):format(fav.name or "Händlergunst", fav.amount) end
        local certs = 0
        for _ in pairs(fav.cert or {}) do certs = certs + 1 end
        if certs > 0 then parts[#parts + 1] = ("%d Zertifizierungen (1000 Gunst, Rang 300)"):format(certs) end
        return table.concat(parts, " · ")
    end
    local text = ("%d Rezepte"):format(n)
    if Pr.Rank(v) and not Pr.HasSnapshot(v) then text = text .. " · Berufsfenster öffnen für Bekannt" end
    return text
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
        return ("Händler: %s. Gunst gibt es für volle Kisten und Handwerksaufträge (%d Items haben einen)."):format(
            #names > 0 and table.concat(names, ", ") or "unbekannt", writs)
    elseif v == CAMP then
        return "Lagerobjekte brauchen ein Lagerfeuer in der Nähe und teilen eine Abklingzeit. Wirkung nach Sitzen am Feuer."
    end
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
    local isRecipes = type(v) == "number"
    f.known:SetValue(s.known or "all")
    f.source:SetValue(s.source or "all")
    f.learn:SetOn(s.learnable and true or false)
    local text = s.search or ""
    if not f.search:HasFocus() and f.search:GetText() ~= text then f.search:SetText(text) end
    for _, w in ipairs({ f.known, f.source, f.learn, f.search }) do
        if isRecipes then w:Show() else w:Hide() end
    end
    local rank, max = nil, nil
    if isRecipes then rank, max = Pr.Rank(v) end
    f.rank:SetText(rank and ("Dein Rang: %d / %d"):format(rank, max or 0) or (isRecipes and (GREY .. "Beruf nicht erlernt|r") or ""))
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
    if #list == 0 then
        f.empty:SetText(Pr.Available() and "Keine Rezepte zu diesen Filtern." or "Für diesen Client gibt es keine Berufsdaten.")
        f.empty:Show()
    else
        f.empty:Hide()
    end
    showDetail(f, f.selected)
    f.counts:SetText(statusText(v, #list))
    f.hint:SetText(hintText(v))
    local d = ns.PROFESSIONS
    f.data:SetText(("Berufsdaten vom %s (Client %s) · Namen aus dem Client."):format(d and d.built or "?", d and d.client or "?"))
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

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)
    page = f
    f.prof = W.Picker(f, 200, function(v)
        state().view = (v == CAMP or v == FAVOR) and v or tonumber(v)
        ns.Refresh()
    end)
    f.search = W.SearchBox(f, 170, function(text)
        state().search = text ~= "" and text or nil
        ns.Refresh()
    end, "Rezept suchen")
    W.Row(f, { f.prof, f.search }, 10, 0, -1)
    f.rank = W.Text(f, T.FONT.head, 210)
    f.rank:SetPoint("TOPRIGHT", -2, -5)
    f.rank:SetJustifyH("RIGHT")

    f.known = W.Choice(f, 100, function(v)
        state().known = v
        ns.Refresh()
    end)
    f.known:SetValues(KNOWN)
    W.Tooltip(f.known, "Bekannt", "Alle, nur bekannte oder nur unbekannte Rezepte. Was du kennst, liest Amisia aus dem offenen Berufsfenster.")
    f.source = W.Choice(f, 120, function(v)
        state().source = v
        ns.Refresh()
    end)
    f.source:SetValues(SOURCES)
    W.Tooltip(f.source, "Quelle", "Woher das Rezept kommt: Lehrer, Händler, Händlergunst, Drop oder Quest.")
    f.learn = W.Chip(f, "Lernbar", 80, function()
        local s = state()
        s.learnable = not s.learnable or nil
        ns.Refresh()
    end)
    W.Tooltip(f.learn, "Lernbar", "Nur unbekannte Rezepte, die dein Rang schon erlaubt.")
    f.counts = W.Text(f, T.FONT.hint, 286)
    -- the filters, then the counts on the text line beside them
    W.Row(f, { f.known, f.source, f.learn, { f.counts, gap = 8, y = -31 } }, T.CHIP_GAP, 0, -27)

    f.list = W.List(f, ROWS, ROW_H, function(r)
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
    end, fillRow)
    f.list:SetPoint("TOPLEFT", 0, -54)
    f.list:SetWidth(290)
    f.empty = W.Text(f, T.FONT.hint, 280, true)
    f.empty:SetPoint("TOPLEFT", 6, -62)
    f.empty:Hide()

    local d = W.Inset(f)
    d:SetPoint("TOPLEFT", 306, -54)
    d:SetPoint("TOPRIGHT", 0, -54)
    d:SetHeight(ROWS * ROW_H)
    f.detail = d
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(32, 32)
    d.icon:SetPoint("TOPLEFT", 8, -8)
    d.head = CreateFrame("Button", nil, d)
    d.head:SetPoint("TOPLEFT", 44, -8)
    d.head:SetPoint("TOPRIGHT", -8, -8)
    d.head:SetHeight(18)
    d.title = W.Text(d.head, T.FONT.title, 236)
    d.title:SetPoint("LEFT", 0, 0)
    d.head:SetScript("OnEnter", function(self) entryTooltip(self, d.entry) end)
    d.head:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    d.sub = W.Text(d, T.FONT.text, 236)
    d.sub:SetPoint("TOPLEFT", 44, -28)
    d.body = W.ScrollText(d)
    d.body:SetPoint("TOPLEFT", 8, -46)
    d.body:SetPoint("BOTTOMRIGHT", -16, 32)
    d.go = W.Button(d, "Weg", 70, function()
        if d.point and ns.MapSetPoint then
            local ok, why = ns.MapSetPoint(d.point, d.pointLabel)
            if not ok and why then ns.msg(why) end
        end
    end, { height = 20 })
    d.go:SetPoint("BOTTOMRIGHT", -8, 8)
    W.Tooltip(d.go, "Weg", "Setzt den Wegpunkt auf die erste Quelle mit Ort.")

    -- the hint takes two lines when it needs them (the favor vendors), the data line moves down
    f.hint = W.Text(f, T.FONT.hint, 598, true)
    f.hint:SetPoint("TOPLEFT", 4, -436)
    f.hint:SetMaxLines(2)
    f.data = W.Text(f, T.FONT.hint, 598)
    f.data:SetPoint("TOPLEFT", f.hint, "BOTTOMLEFT", 0, -8)
    return f
end

ns.RegisterPanel{ key = "professions", label = "Berufe", icon = ICON, order = 57, group = "gear",
    available = function() return Pr.Available() end, create = create, refresh = refresh }

function ns.ProfessionsPageFrame() return page end

-- Opens the page; what: a profession (German name or key, a prefix is enough), "lager" or "gunst".
function ns.ShowProfessions(what)
    if AmisiaDB and AmisiaDB.settings and type(what) == "string" and what ~= "" then
        local w = ns.Fold(what)
        if w:find("^lager") or w:find("^camp") then
            state().view = CAMP
        elseif w:find("^gunst") or w:find("^händler") or w:find("^favor") then
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

ns.RegisterSlash("berufe", { aliases = { "professions", "beruf" }, args = "[Beruf|lager|gunst]",
    desc = "Rezepte, Lager und Händlergunst", run = function(rest) ns.ShowProfessions(rest) end })

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
ns.Listen("BIS_CHANGED", schedule)
ns.OnEvent("BAG_UPDATE_DELAYED", schedule)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if nameMissing then schedule() end
end)
