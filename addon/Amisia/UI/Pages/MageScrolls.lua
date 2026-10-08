-- The page "Schriftrollen" (under Ausrüstung, for mages; others open it with /amisia schriftrollen):
-- WoW Forever's mage scrolls and the Comprehension skill ("Arkanes Verständnis"). Three views: the
-- untranslated scrolls per tier in the colour the own rank gives them (count in the bags), the
-- scrolls deciphering can give, and the library (the charm and the spells around it, the books a
-- librarian takes, the Friend of the Library quests). The chosen entry in the detail field, with a
-- waypoint where a place is known (the librarian, an own drop position). The rules live in
-- Gear/MageScrolls.lua.
local ADDON, ns = ...
local L = ns.L
local W, MS, T = ns.W, ns.MageScrolls, ns.Theme
local GREY, GREEN, LABEL = T.GREY, T.GREEN, T.LABEL
local ICON = "Interface\\Icons\\INV_Scroll_03"
-- rows of 22 from the head row to the footer (two hint lines and the data line): 26 + 18 x 22 = 422 of 426
local ROWS, ROW_H = 18, 22
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local COLORS = { orange = "ffff8040", yellow = "ffffff00", green = "ff40bf40", grey = "ff808080", red = "ffff2020", none = "ffffffff" }
local COLOR_WORD = { orange = ns.N_("orange"), yellow = ns.N_("gelb"), green = ns.N_("grün"), grey = ns.N_("grau"),
    red = ns.N_("noch nicht entzifferbar") }
local VIEWS = { { "scrolls", ns.N_("Schriftrollen") }, { "results", ns.N_("Ergebnisse") }, { "library", ns.N_("Bibliothek") } }

local page
local view = "scrolls"   -- kept until logout
local chosen = {}        -- view -> key of the chosen entry
local nameMissing = false

function ns.MageScrollsPageFrame() return page end

local function color(c, text) return ("|c%s%s|r"):format(c, text) end

-- "08.10.2026" (English "Oct 8, 2026") from the data's "2026-10-08".
local function longDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    return y and ns.FmtDate(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })) or "?"
end

local function itemText(id, fallback)
    local name, q, known = MS.ItemName(id, fallback)
    if not known then nameMissing = true end
    return color(QUALITY[tonumber(q) or 1] or QUALITY[1], name)
end

local function spellName(id, fallback)
    local f = C_Spell and C_Spell.GetSpellName
    local ok, name = false, nil
    if type(f) == "function" then ok, name = pcall(f, id) end
    name = ok and ns.Plain(name) or nil
    return type(name) == "string" and name ~= "" and name or fallback or ("Spell " .. tostring(id))
end

local function spellText(id, fallback)
    local text
    if ns.Prof and ns.Prof.SpellDescription then text = ns.Prof.SpellDescription(id) end
    if type(text) == "string" and text ~= "" then return text end
    return fallback ~= "" and fallback or nil
end

local function knownText(spell)
    local k = MS.Known(spell)
    if k == true then return GREEN .. L["bekannt"] .. "|r" end
    if k == false then return GREY .. L["nicht bekannt"] .. "|r" end
    return ""
end

---------------------------------------------------------------------------
-- The entries of a view
---------------------------------------------------------------------------
local function entries(v)
    local out = {}
    if v == "scrolls" then
        local byTier = {}
        for _, s in ipairs(MS.Scrolls()) do
            byTier[s.tier] = byTier[s.tier] or {}
            table.insert(byTier[s.tier], s)
        end
        for _, t in ipairs(MS.Tiers()) do
            out[#out + 1] = { head = t, key = "t" .. t.index }
            for _, s in ipairs(byTier[t.index] or {}) do out[#out + 1] = { scroll = s, key = s.item } end
        end
    elseif v == "results" then
        for _, r in ipairs(MS.Results()) do out[#out + 1] = { result = r, key = r.item } end
    else
        local d = MS.Data() or {}
        if (d.charm or 0) > 0 then out[#out + 1] = { charm = true, key = "charm" } end
        if (d.boost or 0) > 0 then out[#out + 1] = { boost = true, key = "boost" } end
        for _, a in ipairs(MS.Abilities()) do out[#out + 1] = { ability = a, key = "a" .. a.spell } end
        local books = MS.Books()
        if #books > 0 then out[#out + 1] = { label = L["Bücher für die Bibliothek"], key = "books" } end
        for _, b in ipairs(books) do out[#out + 1] = { book = b, key = "b" .. b.quest } end
        for _, f in ipairs(MS.Friends()) do out[#out + 1] = { friend = f, key = "f" .. f.quest } end
    end
    return out
end

local function fillRow(r, e)
    r.sel:SetShown(page and page.selected == e)
    r.mark:SetText("")
    r.rank:SetText("")
    if e.head then
        local t = e.head
        r.name:SetText(LABEL .. L["Stufe %d · ab Rang %d"]:format(t.index, t.rank) .. "|r")
        if (t.grey or 0) > 0 then r.mark:SetText(GREY .. ("%d/%d"):format(t.yellow, t.grey) .. "|r") end
    elseif e.label then
        r.name:SetText(LABEL .. e.label .. "|r")
    elseif e.scroll then
        local s = e.scroll
        local name = MS.ItemName(s.item, s.name)
        r.name:SetText(color(COLORS[MS.Color(s, (MS.Rank()))] or COLORS.none, name))
        local n = MS.Count(s.item)
        if n > 0 then r.mark:SetText(GREEN .. "x" .. n .. "|r") end
        r.rank:SetText(GREY .. s.rank .. "|r")
    elseif e.result then
        local x = e.result
        r.name:SetText(itemText(x.item, x.name))
        local n = MS.Count(x.item)
        if n > 0 then r.mark:SetText(GREEN .. "x" .. n .. "|r") end
        r.rank:SetText(GREY .. (x.level > 0 and x.level or "") .. "|r")
    elseif e.charm or e.boost then
        local d = MS.Data()
        local id = e.charm and d.charm or d.boost
        r.name:SetText(itemText(id, (d.names or {})[e.charm and "charm" or "boost"]))
        local n = MS.Count(id)
        if n > 0 then r.mark:SetText(GREEN .. "x" .. n .. "|r") end
    elseif e.ability then
        r.name:SetText(spellName(e.ability.spell, e.ability.name))
        r.mark:SetText(knownText(e.ability.spell))
    elseif e.book then
        local b = e.book
        r.name:SetText(itemText(b.item, b.name))
        if b.done then r.mark:SetText(GREEN .. L["abgegeben"] .. "|r") end
    elseif e.friend then
        local f = e.friend
        r.name:SetText(MS.QuestName(f.quest, f.name))
        r.mark:SetText(f.done and (GREEN .. L["abgegeben"] .. "|r") or (GREY .. ("%d/%d"):format(math.min(f.have, f.need), f.need) .. "|r"))
    end
end

---------------------------------------------------------------------------
-- The detail field
---------------------------------------------------------------------------
local function scrollDetail(s)
    local lines, rank = {}, MS.Rank()
    local t = MS.Tier(s.tier)
    lines[#lines + 1] = L["Benötigt Arkanes Verständnis %d (Stufe %d)."]:format(s.rank, s.tier)
    if t and (t.grey or 0) > 0 then
        lines[#lines + 1] = L["Entziffern steigert die Fertigkeit: gelb ab %d, grau ab %d."]:format(t.yellow, t.grey)
    end
    if rank then
        local c = MS.Color(s, rank)
        local word = COLOR_WORD[c]
        lines[#lines + 1] = L["Dein Rang %d%s"]:format(rank, word and (": " .. color(COLORS[c], L[word])) or "")
    else
        lines[#lines + 1] = GREY .. L["Arkanes Verständnis ist nicht erlernt (oder der Client nennt den Rang nicht)."] .. "|r"
    end
    lines[#lines + 1] = L["Im Inventar: %d"]:format(MS.Count(s.item))
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Quelle:"]
    local src = MS.Sources(s)
    for _, e in ipairs(src) do lines[#lines + 1] = "  " .. e.text end
    lines[#lines + 1] = ""
    lines[#lines + 1] = GREY .. L["Was beim Entziffern entsteht, entscheidet der Server (siehe Ergebnisse)."] .. "|r"
    return lines, src
end

local function detailOf(e)
    local d = MS.Data() or {}
    local lines, src, title, item = {}, {}, "", nil
    if e.scroll then
        item = e.scroll.item
        title = itemText(item, e.scroll.name)
        lines, src = scrollDetail(e.scroll)
    elseif e.result then
        local x = e.result
        item = x.item
        title = itemText(item, x.name)
        local text = x.spell > 0 and spellText(x.spell, x.text) or (x.text ~= "" and x.text or nil)
        lines[#lines + 1] = text or (GREY .. L["Keine Beschreibung vom Client."] .. "|r")
        lines[#lines + 1] = ""
        if x.level > 0 then lines[#lines + 1] = L["Benötigt Stufe %d."]:format(x.level) end
        lines[#lines + 1] = L["Im Inventar: %d"]:format(MS.Count(item))
        lines[#lines + 1] = GREY .. L["Eine mögliche Schriftrolle aus dem Entziffern (aus den Client-Tabellen)."] .. "|r"
    elseif e.charm then
        item = d.charm
        title = itemText(item, (d.names or {}).charm)
        lines[#lines + 1] = L["Hilft beim Übersetzen von Schriftrollen und Zaubernotizen."]
        lines[#lines + 1] = L["Im Inventar: %d"]:format(MS.Count(item))
        if (d.conjure or 0) > 0 then
            lines[#lines + 1] = L["Zauber %s: %s"]:format(spellName(d.conjure, (d.names or {}).conjure),
                knownText(d.conjure) ~= "" and knownText(d.conjure) or "?")
        end
        lines[#lines + 1] = L["Bücher, die ein Bibliothekar annimmt, bringen je einen Talisman."]
    elseif e.boost then
        item = d.boost
        title = itemText(item, (d.names or {}).boost)
        lines[#lines + 1] = spellText(d.boostSpell, "") or L["Erhöht Arkanes Verständnis für eine Weile."]
        lines[#lines + 1] = L["Im Inventar: %d"]:format(MS.Count(item))
    elseif e.ability then
        local a = e.ability
        title = spellName(a.spell, a.name)
        lines[#lines + 1] = spellText(a.spell, a.text) or ""
        local k = knownText(a.spell)
        if k ~= "" then lines[#lines + 1] = k end
        if (d.bundle or 0) > 0 and a.spell == d.study then
            lines[#lines + 1] = L["Ergibt: %s"]:format(itemText(d.bundle, (d.names or {}).bundle))
        end
    elseif e.book then
        local b = e.book
        item = b.item
        title = itemText(item, b.name)
        local lib = MS.Librarian()
        local zones = MS.BookZones(b)
        if #zones > 0 then lines[#lines + 1] = L["Fundort: %s"]:format(table.concat(zones, ", ")) end
        if lib then
            local where = ns.Prof and ns.Prof.ZoneName(lib.point.map) or "?"
            lines[#lines + 1] = L["Abgeben bei %s, %s %d, %d."]:format(lib.name, where, math.floor(lib.point.x * 100 + 0.5),
                math.floor(lib.point.y * 100 + 0.5))
            src = { { point = lib.point, text = lib.name } }
        end
        if b.charm then lines[#lines + 1] = L["Belohnung: %s"]:format(itemText(d.charm, (d.names or {}).charm)) end
        if b.done == true then lines[#lines + 1] = GREEN .. L["Abgegeben."] .. "|r"
        elseif b.done == false then lines[#lines + 1] = L["Noch nicht abgegeben."] end
    elseif e.friend then
        local f = e.friend
        title = MS.QuestName(f.quest, f.name)
        lines[#lines + 1] = L["Für %d abgegebene Bücher; du hast %d."]:format(f.need, f.have)
        if f.level > 0 then lines[#lines + 1] = L["Ab Stufe %d."]:format(f.level) end
        local rewards = {}
        for _, id in ipairs(f.rewards) do rewards[#rewards + 1] = itemText(id) end
        if #rewards > 0 then lines[#lines + 1] = L["Belohnung (eine davon): %s"]:format(table.concat(rewards, ", ")) end
        if f.done then lines[#lines + 1] = GREEN .. L["Abgegeben."] .. "|r" end
        local lib = MS.Librarian()
        if lib then src = { { point = lib.point, text = lib.name } } end
    elseif e.head then
        local t = e.head
        title = LABEL .. L["Stufe %d"]:format(t.index) .. "|r"
        lines[#lines + 1] = L["Schriftrollen ab Arkanes Verständnis %d."]:format(t.rank)
        if (t.grey or 0) > 0 then
            lines[#lines + 1] = L["Entziffern steigert die Fertigkeit: gelb ab %d, grau ab %d."]:format(t.yellow, t.grey)
        end
    end
    return title, table.concat(lines, "\n"), src, item
end

local function showDetail(f, e)
    local d = f.detail
    d.point = nil
    if not e or e.label then
        d.icon:Hide()
        d.title:SetText("")
        d.body:SetText(GREY .. L["Einen Eintrag wählen."] .. "|r")
        d.go:Disable()
        return
    end
    local title, body, src, item = detailOf(e)
    d.title:SetText(title)
    d.body:SetText(body)
    local icon = item and C_Item and C_Item.GetItemIconByID and ns.Plain(C_Item.GetItemIconByID(item)) or nil
    if icon then d.icon:SetTexture(icon); d.icon:Show() else d.icon:Hide() end
    for _, s in ipairs(src or {}) do
        if s.point then d.point, d.pointLabel = s.point, s.text break end
    end
    if d.point then d.go:Enable() else d.go:Disable() end
end

---------------------------------------------------------------------------
-- Build and refresh
---------------------------------------------------------------------------
local function refresh(f)
    f.view:SetValue(view)
    local rank, max = MS.Rank()
    f.rank:SetText(rank and L["Arkanes Verständnis: %d / %d"]:format(rank, max or 0) or (GREY .. L["Arkanes Verständnis: nicht erlernt"] .. "|r"))
    nameMissing = false
    if f.shownView ~= view then f.list.offset = 0 end
    f.shownView = view
    local list = entries(view)
    f.selected = nil
    for _, e in ipairs(list) do
        if e.key == chosen[view] then f.selected = e end
    end
    if not f.selected then
        for _, e in ipairs(list) do
            if not e.head and not e.label then f.selected = e break end
        end
    end
    f.list:SetItems(list)
    showDetail(f, f.selected)
    local d = MS.Data() or {}
    if view == "scrolls" then
        f.counts:SetText(L["%d Schriftrollen in %d Stufen"]:format(#MS.Scrolls(), #MS.Tiers()))
    elseif view == "results" then
        f.counts:SetText(L["%d mögliche Ergebnisse"]:format(#MS.Results()))
    else
        local books, done = MS.Books(), 0
        for _, b in ipairs(books) do if b.done then done = done + 1 end end
        f.counts:SetText(L["%d von %d Büchern abgegeben"]:format(done, #books))
    end
    f.data:SetText(L["Daten: Client %s, Stand %s · Namen aus dem Client."]:format(d.build or "?", longDate(d.built)))
end

local function choose(e)
    if not e or not page or e.label then return end
    chosen[view] = e.key
    page.selected = e
    page.list:Redraw()
    showDetail(page, e)
end

local function entryTooltip(owner, e)
    if not e or not GameTooltip then return end
    local d = MS.Data() or {}
    local item = (e.scroll and e.scroll.item) or (e.result and e.result.item) or (e.book and e.book.item)
        or (e.charm and d.charm) or (e.boost and d.boost)
    if not item and not e.ability then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if item and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(item)
    elseif item then
        GameTooltip:SetHyperlink("item:" .. item)
    elseif GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(e.ability.spell)
    end
    GameTooltip:Show()
end

local function col(parent, x, w)
    local fs = W.Text(parent, T.FONT.text, w)
    fs:SetPoint("LEFT", x, 0)
    return fs
end

local function create(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: the view and its counts, the own rank at the right
    local top = f:Bands({ "row" })
    f.view = W.Choice(f, 120, function(v)
        view = v
        ns.Refresh()
    end)
    local values = {}
    for i, v in ipairs(VIEWS) do values[i] = { v[1], L[v[2]] } end
    f.view:SetValues(values)
    W.Tooltip(f.view, L["Ansicht"], L["Schriftrollen, mögliche Ergebnisse oder die Bibliothek."])
    f.counts = W.Text(f, T.FONT.hint)
    f.rank = W.Text(f, T.FONT.head, 230)
    f.rank:SetJustifyH("RIGHT")
    f:Place(1, { f.view, { f.counts, fill = true } }, { f.rank })
    -- the hint takes two lines when it needs them, the data line under it
    f:Footer({ { "hint", lines = 2 }, "data" })

    f.list = f:List(ROWS, ROW_H, function(r)
        r.sel = W.SelectBar(r)
        r.name = col(r, 4, 190)
        r.mark = col(r, 198, 62)
        r.rank = col(r, 262, 24)
        r.rank:SetJustifyH("RIGHT")
        r:RegisterForClicks("LeftButtonUp")
        r:SetScript("OnClick", function(self) choose(self.item) end)
        r:SetScript("OnEnter", function(self) entryTooltip(self, self.item) end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end, fillRow, { top = top, width = T.LAYOUT.SPLIT_LIST_W })

    -- the chosen entry in the inset beside the list, as high as the list
    local d = f:Detail({ top = top, height = ROWS * ROW_H })
    f.detail = d
    d.go = W.Button(d, L["Weg"], 70, function()
        if d.point and ns.MapSetPoint then
            local ok, why = ns.MapSetPoint(d.point, d.pointLabel)
            if not ok and why then ns.msg(why) end
        end
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(d.go, 70)
    d:Buttons({ d.go })
    W.Tooltip(d.go, L["Weg"], L["Setzt den Wegpunkt auf den Ort des Eintrags."])

    f.hint:SetText(L["Magier entziffern Schriftrollen mit Arkanem Verständnis; höhere Stufen brauchen einen höheren Rang. Farben wie im Berufsfenster."])
    return f
end

ns.RegisterPanel{ key = "scrolls", label = L["Schriftrollen"], icon = ICON, order = 57.5, group = "gear",
    available = function() return MS.Shown() end, create = create, refresh = refresh }

-- Opens the page (any class); what: a view ("ergebnisse", "bibliothek", ...).
function ns.ShowMageScrolls(what)
    MS.opened = true
    local w = ns.Fold and ns.Fold(what or "") or ""
    if w:find("^erg") or w:find("^res") then view = "results"                          -- l10n-ok: typed sub-words
    elseif w:find("^bib") or w:find("^lib") then view = "library"                      -- l10n-ok: typed sub-words
    elseif w ~= "" then view = "scrolls" end
    if ns.ShowPage then ns.ShowPage("scrolls") end
end

ns.RegisterSlash("schriftrollen", { en = "scrolls", aliases = { "verständnis", "comprehension" }, args = L["[ergebnisse|bibliothek]"],   -- l10n-ok: typed words
    desc = L["Magier-Schriftrollen und Arkanes Verständnis"], run = function(rest) ns.ShowMageScrolls(rest) end })

-- the bags, item names, quest turn-ins and the skill change what the page shows
local due = false
local function schedule()
    if due or not page or not page:IsShown() or not ns.CurrentPage or ns.CurrentPage() ~= "scrolls" then return end
    due = true
    C_Timer.After(0.3, function()
        due = false
        if page and page:IsShown() then ns.Refresh() end
    end)
end
ns.OnEvent("BAG_UPDATE_DELAYED", schedule)
ns.OnEvent("SKILL_LINES_CHANGED", schedule)
ns.OnEvent("QUEST_TURNED_IN", schedule)
ns.Listen("PROF_SPELL_LOADED", schedule)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function() if nameMissing then schedule() end end)
