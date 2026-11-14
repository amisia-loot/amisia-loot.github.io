-- The page "Ausrüstungsplaner" (F-149, D-77, D-80, spec docs/specs/2026-11-08-hub-reiter.md), the first
-- page of the tab Ausrüstung and the one place of the own targets (the window "Ausrüstungsziele" went
-- into it, D-80). Left a panel on the dressing room's background of the own race: at its top the own
-- name, level and the gear page's spec picker; the doll (UI/GearDoll.lua, ns.GoalsKit, T.PLANNER.DOLL):
-- the model between two columns of eight slots as on the character frame, the weapons under it, each
-- slot the target (the own pick first, D-55) or with "Angelegt" what is worn, in its quality's frame
-- (green: worn), beside it a square with the enchantment on the worn item or "+" (a click lists what
-- fits with its gain); under it the switch Ziele | Angelegt, the score ("Wertung 350 · +130" over its
-- bar, the tooltip: now, the best at the level, the six biggest stat changes) and "Zurücksetzen".
-- Right the tabs Vorschläge | Ziele | Wunschliste, a warning while an own pick is not used,
-- "Optionen" (weapon plan, sources, play style; its tooltip: why these weights) and the search box
-- (names, or an item link or id: that item as the own pick); under them the slot's name, "Stufe [lo]
-- - [hi]", Meine Stufe | Alle (Ziele: "N/17 Ziele" over its bar and the filters); the list: icon,
-- name, "Stufe N · source", the gain, the source's symbol and the wish star. Vorschläge starts with
-- "Deine Wahl" (the own pick with its X, "Überholt ... Übernehmen", "Passt nicht zum Waffenplan") and
-- ends with "+ N weitere ohne bekannte Quelle" when scanned gear of unknown source passes the list's
-- filters (Gear/NoSource.lua, F-175, D-107): a click (the setting bis.noSource, also under "Optionen")
-- puts them into the list by gain, each with "Quelle unbekannt" and a grey "?" for its source;
-- a click on a row makes it the own pick of its slot (again: lifts it). Ziele lists the slots by
-- section; a click shows that slot's suggestions. The side bar's marks are the catalog's set
-- categories (Gear/Catalog.lua): one shows that category's sets in the list instead. State in
-- settings.bis (planSlot, planTab, planLo, planHi, planFilter, planWorn); the set category, the open
-- set and the search text only in memory. Nothing is sent.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local PL = T.PLANNER
local LAY = T.LAYOUT
local Gear = ns.Gear
local K = ns.GearPageKit
local DK = ns.GoalsKit
local Cat = ns.Catalog
local NSR = ns.GearNoSource
local GREY, GREEN = T.GREY, "|cff4fd06a"
local NORM = { FINGER2 = "FINGER1", TRINKET2 = "TRINKET1" }
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "

-- The panel's width: LEFT_RATIO of the page's width now (D-71), LEFT_MIN to LEFT_MAX; the right half
-- starts GAP after it.
local function leftW()
    local w = math.floor((T.PAGE_W_NOW or T.PAGE_W) * PL.LEFT_RATIO)
    return math.max(PL.LEFT_MIN, math.min(PL.LEFT_MAX, w))
end

local setCat, openSet   -- the set category of a side bar mark (nil: the tabs) and its open set
local query = ""        -- the search text

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function state() return K.state() end
local function ownLevel() return math.max(1, math.min(tonumber(UnitLevel("player")) or 1, Gear.Cap())) end
local function levelOf(id)
    local row = Gear.Item(id)
    return row and tonumber(row[4]) or 0
end

local TABS = { suggest = true, goals = true, wish = true }
local FILTERS = { "all", "todo", "bag", "ench" }
local FILTER_OK = { all = true, todo = true, bag = true, ench = true }
local function filter()
    local v = state().planFilter
    return FILTER_OK[v] and v or "all"
end
-- the doll: the targets, or what is worn ("Angelegt")
local function dollMode() return state().planWorn and "worn" or "goals" end
local function shownTab()
    local t = state().planTab
    return TABS[t] and t or "suggest"
end

-- The level range of the list: saved, else 1 to the own level ("Meine Stufe", follows the level).
local function range()
    local st = state()
    local lo, hi = tonumber(st.planLo), tonumber(st.planHi)
    if not (lo and hi and lo >= 1 and hi <= Gear.Cap() and lo <= hi and lo % 1 == 0 and hi % 1 == 0) then
        st.planLo, st.planHi = nil, nil
        return 1, ownLevel()
    end
    return lo, hi
end

local function setRange(lo, hi)
    local st = state()
    if lo == 1 and hi == ownLevel() then lo, hi = nil, nil end
    st.planLo, st.planHi = lo, hi
    ns.Refresh()
end

-- The chosen slot: the saved one, else the first with an upgrade, else the first.
local function chosenSlot(res)
    local s = state().planSlot
    if ns.BIS_SLOT_NAME[s] then return s end
    for _, sl in ipairs(Gear.SLOTS) do
        if res and res.state[sl.key] == "upgrade" then return sl.key end
    end
    return Gear.SLOTS[1].key
end

local function wished(id)
    local c = ns.BisChar()
    return c ~= nil and type(c.wish) == "table" and c.wish[id] ~= nil
end

-- The slot a row's item becomes the own pick of: the chosen one when it fits there (both rings,
-- both trinkets), else the item's own.
local function pickSlot(slotKey, chosen)
    if slotKey and (NORM[slotKey] or slotKey) == (NORM[chosen] or chosen) then return chosen end
    return slotKey
end

local function hasPicks(o)
    local c = ns.BisChar()
    local t = c and type(c.pick) == "table" and o.spec and c.pick[o.spec]
    return type(t) == "table" and next(t) ~= nil
end

---------------------------------------------------------------------------
-- The rows: suggestions, wishes, search hits, sets
---------------------------------------------------------------------------

-- What an item brings the own character, as a row: { id, slotKey, level, owned, gain, mine, upgrade, why }.
local function measured(id, o, slotKey)
    local gain, sk, mine = ns.BisGain(id, o)
    local owned = ns.BisOwned(id)
    local e = { id = id, level = levelOf(id), owned = owned }
    if type(gain) == "number" then
        e.slotKey, e.gain, e.mine = slotKey or sk, gain, mine
        e.upgrade = owned ~= "worn" and ns.BisIsUpgrade(gain, mine) or false
    else
        e.slotKey, e.why = slotKey, sk
    end
    return e
end

-- The suggestions of a slot in the level range: up to the own level the slot's ranking (the own
-- sources, exclusions and play style, ns.BisRanking), above it the same calculation at the range's
-- top (ns.BisFor); kept until the targets or the choice change.
local memo = {}
local function suggestions(res, o, slot, lo, hi)
    local key = table.concat({ tostring(res), slot, lo, hi }, "|")
    if memo.key == key then return memo.rows end
    local rows = {}
    if hi <= o.level then
        for _, r in ipairs((ns.BisRanking(slot, PL.RANK_N))) do
            local lv = levelOf(r.id)
            if lv >= lo and lv <= hi then
                rows[#rows + 1] = { id = r.id, slotKey = slot, level = lv, owned = r.owned, gain = r.gain, mine = r.mine,
                    upgrade = r.upgrade, switch = r.switch }
            end
        end
    else
        local b = ns.BisFor(o.class, o.spec, hi, { sources = o.sources, plan = o.plan, kind = o.kind, exclude = o.exclude,
            faction = o.faction, style = o.style })
        local list = b[NORM[slot] or slot] or {}
        for i = 1, math.min(PL.RANK_N, #list) do
            local id = list[i][1]
            local lv = levelOf(id)
            if lv >= lo and lv <= hi then rows[#rows + 1] = measured(id, o, slot) end
        end
    end
    memo.key, memo.rows = key, rows
    return rows
end

local function noSuggestion(res, slot, lo, hi)
    if slot == "OFFHAND" and res.plan == "2H" then return L["Die Zweihandwaffe belegt beide Hände."] end
    if lo > 1 or hi < Gear.Cap() then return L["Keine Vorschläge auf Stufe %d-%d."]:format(lo, hi) end
    return L["Für diesen Slot gibt es keine Option in den Daten."]
end

-- An item link or an item id typed or pasted into the search box, else nil.
local function linkedItem(text)
    if not text:find("%S") then return nil end
    local id = ns.ItemID(text)
    if not id then id = tonumber(text:match("^%s*(%d+)%s*$")) end
    return id and id > 0 and id or nil
end

-- The line "Deine Wahl" over the suggestions (F-112): the own pick of the slot (also one kept but not
-- used) with the hint under it: not with the weapon plan, the character cannot wear it, or overtaken
-- by the ranking's best ("Übernehmen").
local function pickRow(res, chosen)
    local stored = ns.BisPick(chosen)
    local e = { pickRow = true, slot = chosen, stored = stored }
    if not stored then return e end
    local unused = res.ownUnused and res.ownUnused[chosen]
    if unused == "plan" then
        e.hint = T.ORANGE .. L["Passt nicht zum Waffenplan"] .. "|r"
    elseif unused then
        e.hint = T.ORANGE .. L["Das kann dein Charakter nicht tragen."] .. "|r"
    else
        local over = ns.BisOvertaken(chosen)
        if over then
            e.hint = L["Überholt: %s ist %s besser"]:format(K.itemText(over.id),
                over.pct and ("+%d %%"):format(over.pct) or ("+%d"):format(math.floor(over.gain + 0.5)))
            e.take = over.id
        end
    end
    local first = res[chosen] and res[chosen][1]
    e.unknown = first and first.own and first.unknown or nil
    return e
end

-- The rows the list shows now and the line over it.
local function listRows(res, o, chosen, lo, hi)
    local rows, title = {}, nil
    local linked = linkedItem(query)
    if linked then
        -- an item link or id: that item, a click makes it the own pick (the field "Item-Link oder ID")
        local e = measured(linked, o)
        e.linkRow = true
        rows[1] = e
        title = L["Item-Link oder ID"]
    elseif query:find("%S") then
        local hits, n = Cat.Search(query, lo, hi, o)
        for _, e in ipairs(hits) do rows[#rows + 1] = e end
        if n == 0 then rows[1] = { note = L["Kein Item gefunden."] } end
        title = L["Suche: %d Treffer"]:format(n)
    elseif setCat then
        for _, c in ipairs(Cat.CATS) do if c.key == setCat then title = c.label end end
        for _, s in ipairs(Cat.Sets(setCat, lo, hi)) do
            local open = s.id == openSet
            rows[#rows + 1] = { set = s, open = open }
            if open then
                for _, e in ipairs(Cat.Pieces(s.id, o)) do
                    e.piece = true
                    rows[#rows + 1] = e
                end
            end
        end
        if #rows == 0 then rows[1] = { note = L["Keine Sets dieser Art auf Stufe %d-%d."]:format(lo, hi) } end
    elseif shownTab() == "wish" then
        for _, w in ipairs(ns.Wishes()) do
            local e = measured(w.id, o, w.slotKey)
            e.slotName = w.slot
            rows[#rows + 1] = e
        end
        title = L["Wunschliste (%d)"]:format(#rows)
        if #rows == 0 then rows[1] = { note = L["Noch keine Wünsche: der Stern einer Zeile merkt ein Item."] } end
    elseif shownTab() == "goals" then
        local p = ns.BisProgress(res)
        for _, e in ipairs(DK.goalItems(res, p, filter(), DK.unenchanted())) do
            if e.header then
                rows[#rows + 1] = e
            else
                e.goal, e.chosen = true, e.key == chosen
                rows[#rows + 1] = e
            end
        end
        if #rows == 0 then rows[1] = { note = L["Kein Platz mit diesem Filter."] } end
    else
        rows[1] = pickRow(res, chosen)
        -- the scanned gear of unknown source that passes the same filters: by gain among the others
        -- while the setting is on, else only counted in the last line (D-107)
        local extra = NSR and NSR.For(chosen, o, res, lo, hi, tostring(res)) or {}
        local shown = suggestions(res, o, chosen, lo, hi)
        if #extra > 0 and NSR.On() then shown = NSR.Merge(shown, extra) end
        for _, e in ipairs(shown) do rows[#rows + 1] = e end
        title = ns.BIS_SLOT_NAME[chosen] or chosen
        if #rows == 1 then rows[2] = { note = noSuggestion(res, chosen, lo, hi) } end
        if #extra > 0 then rows[#rows + 1] = { more = #extra, on = NSR.On() } end
    end
    for _, e in ipairs(rows) do
        -- a link or id becomes the chosen slot's pick (refused with the reason when it does not fit)
        if e.id then e.pickSlot = e.linkRow and chosen or pickSlot(e.slotKey, chosen) end
    end
    return rows, title
end

---------------------------------------------------------------------------
-- A row of the list
---------------------------------------------------------------------------

-- A symbol of the client (def: { atlas } or { file }) on tex, shown; hidden when the client lacks it.
local function setArt(tex, def)
    if def and def.atlas and W.HasAtlas(def.atlas) then
        tex:SetAtlas(def.atlas, false)
        tex:Show()
        return true
    elseif def and def.file and not (GetFileIDFromPath and GetFileIDFromPath(def.file) == nil) then
        tex:SetTexture(def.file)
        if def.coords then tex:SetTexCoord(unpack(def.coords)) else tex:SetTexCoord(0, 1, 0, 1) end
        tex:Show()
        return true
    end
    tex:Hide()
    return false
end

local function firstSource(id, o)
    return Gear.Sources(id, o)[1] or Gear.Sources(id)[1]
end

local function setStar(b, on) W.WishStar(b, on) end

-- The gain in percent of the worn item's score; with nothing worn in the slot "neu".
local function gainOf(e)
    if e.owned == "worn" then return GREEN .. L["angelegt"] .. "|r" end
    if e.switch then return L["Wechsel"] end
    if type(e.gain) == "number" and e.gain > 0 and not (type(e.mine) == "number" and e.mine > 0) then
        return GREEN .. L["neu"] .. "|r"
    end
    return DK.pctText(e.gain, e.mine, e.upgrade)
end

-- A source as the row's line names it: "<Dungeon> - <Boss>", "<Beruf> <Rang>", "Quest: <Titel>"
-- (without its level and zone), else the gear page's short text.
local function sourceLine(rec, e, o)
    local k = rec and rec[1]
    if k == "D" or k == "X" then
        return ("%s - %s"):format(Gear.PlaceName(rec) or "?", rec[3] or "?")
    elseif k == "C" then
        return ("%s %d"):format(Gear.PROFESSIONS[rec[2]] or tostring(rec[2]), rec[3] or 0)
    elseif k == "Q" then
        local t = (Gear.SourceText(rec, true) or ""):gsub(" %(%d+%)", "", 1)
        return t:match("^(.-), ") or t
    end
    return K.sourceText(e.id, o)
end

-- The grey line under the name: "Stufe 25 · Kral der Klingenhauer - Roogug", "Stufe 32 · Schneiderei
-- 150", "Quest: Endlich frei" (a quest without the level); a wish its slot first.
local function subOf(e, o, rec)
    local parts = {}
    if e.slotName then parts[#parts + 1] = e.slotName end
    local quest = rec and rec[1] == "Q" and not e.owned and e.gain
    if (e.level or 0) > 0 and not quest then parts[#parts + 1] = L["Stufe %d"]:format(e.level) end
    local src
    if e.owned then
        src = K.OWNED_TEXT[e.owned]
    elseif not e.gain and e.why then
        src = e.why
    else
        src = sourceLine(rec, e, o)
        -- no source at all (D-107): said instead of one
        if not rec and (src == nil or src == "") then src = L["Quelle unbekannt"] end
    end
    if src and src ~= "" then parts[#parts + 1] = src end
    return GREY .. table.concat(parts, " · ") .. "|r"
end

-- The symbol of a source's kind; a crafted item the profession's own icon.
local function srcArt(rec)
    if not rec then return nil end
    if rec[1] == "C" and ns.Prof and ns.Prof.ICONS and ns.Prof.ICONS[rec[2]] then
        return { file = ns.Prof.ICONS[rec[2]], coords = PL.ICON_COORDS }
    end
    return PL.SRC_ICONS[rec[1]]
end

-- What a click on a row's source symbol opens (F-157): a dungeon or raid at the boss that drops the
-- item, a crafted item's recipe on the page Berufe. Returns the action and its tooltip line, or nil.
local function srcAction(rec, id)
    if not (rec and id) then return nil end
    if rec[1] == "D" or rec[1] == "X" then
        local key = ns.Dungeons and ns.Dungeons.SourceKey(rec)
        if key and ns.ShowDungeonItem then
            return function() ns.ShowDungeonItem(key, id) end,
                L["Klick: %s öffnen, beim Boss mit diesem Item."]:format(Gear.PlaceName(rec) or key)
        end
    elseif rec[1] == "C" and ns.Prof and ns.Prof.RecipeForItem and ns.ShowRecipe then
        local r, skill = ns.Prof.RecipeForItem(id, rec[2])
        if r then
            return function() ns.ShowRecipe(skill, r.spell) end, L["Klick: das Rezept unter Berufe öffnen."]
        end
    end
    return nil
end

local function hideItemParts(r)
    r.frame:Hide()
    r.src:Hide()
    r.srcQ:Hide()
    r.star:Hide()
    r.gain:SetText("")
end

local function setIcon(r, id, link)
    r.frame:Show()
    r.icon:SetTexture(DK.iconOf(id) or DK.QUESTION)
    local q = DK.qualityOf(id, link)
    local c = T.QUALITY_RGB[q or 1] or T.QUALITY_RGB[1]
    DK.setRing(r.frame, c[1], c[2], c[3])
end

-- "Deine Wahl: <item>" with its source, or the line without a pick; the red X, "Übernehmen".
local function fillPickRow(r, e, o)
    hideItemParts(r)
    if e.stored then
        setIcon(r, e.stored)
        r.name:SetText(DK.ownMark() .. L["Deine Wahl: %s"]:format(K.itemText(e.stored)))
        local src = e.unknown and L["unbekannt"] or K.sourceText(e.stored, nil, nil)
        r.sub:SetText(e.hint or (GREY .. (src ~= "" and src or L["unbekannt"]) .. "|r"))
        r.del:Show()
    else
        r.name:SetText(GREY .. L["Keine eigene Wahl: Amisia nimmt das Beste."] .. "|r")
        r.sub:SetText(GREY .. L["Klick auf eine Zeile: deine Wahl für diesen Platz."] .. "|r")
    end
    r.take.id = e.take
    r.take:SetShown(e.take ~= nil)
    r.sel:Show()
end

-- A slot of the goals list: its target (or the worn item where the slot has none), "Kopf · source".
local function fillGoalRow(r, e, o)
    local opt = e.opt
    if not opt then
        hideItemParts(r)
        r.name:SetText(T.GOLD_TEXT .. e.name .. "|r")
        r.sub:SetText(GREY .. K.noOptionText(e) .. "|r")
        if e.chosen then r.sel:Show() end
        return
    end
    setIcon(r, opt.id)
    local mark = opt.own and DK.ownMark() or (opt.pick and (T.GOLD_TEXT .. "BiS|r ") or "")
    r.name:SetText(mark .. K.itemText(opt.id))
    local src = opt.owned and K.OWNED_TEXT[opt.owned] or (opt.unknown and L["unbekannt"]) or K.sourceText(opt.id, o, opt.pick)
    r.sub:SetText(T.GOLD_TEXT .. e.name .. "|r" .. GREY .. (src ~= "" and (" · " .. src) or "") .. "|r")
    r.gain:SetText(gainOf(opt))
    local rec = firstSource(opt.id, o)
    setArt(r.src, srcArt(rec))
    setStar(r.star, wished(opt.id))
    r.star:Show()
    if e.chosen then r.sel:Show() end
end

-- The right end of the name and its line: before the gain (an item), before the X and "Übernehmen"
-- ("Deine Wahl") or the row's end (a head, a note).
local function textRight(r, right)
    if r.textAt == right then return end
    r.textAt = right
    r.name:SetPoint("TOPRIGHT", -right, PL.NAME_Y)
    r.sub:SetPoint("TOPRIGHT", -right, PL.SUB_Y)
end

local function fillRow(r, e)
    r.sel:Hide()
    r.del:Hide()
    r.take:Hide()
    if e.pickRow then
        local right = PL.END
        if e.stored then right = right + T.RESET + PL.END end
        if e.take then right = right + r.take:GetWidth() + PL.END end
        textRight(r, right)
    elseif e.header or e.note or e.more then
        textRight(r, PL.END)
    else
        textRight(r, r.textR)
    end
    local o = r:GetParent().opts
    if e.pickRow then return fillPickRow(r, e, o) end
    if e.header then
        hideItemParts(r)
        r.name:SetText(T.GOLD_TEXT .. e.header.label .. "|r")
        r.sub:SetText(GREY .. L["%d von %d hast du"]:format(e.have, e.total) .. "|r")
        return
    end
    if e.goal then
        hideItemParts(r)
        return fillGoalRow(r, e, o)
    end
    if e.note then
        hideItemParts(r)
        r.name:SetText(GREY .. e.note .. "|r")
        r.sub:SetText("")
        return
    end
    if e.more then
        hideItemParts(r)
        r.name:SetText(GREY .. (e.on and L["ohne bekannte Quelle ausblenden"] or L["+ %d weitere ohne bekannte Quelle"]:format(e.more)) .. "|r")
        r.sub:SetText("")
        return
    end
    if e.set then
        local s = e.set
        hideItemParts(r)
        r.name:SetText(T.GOLD_TEXT .. (e.open and "- " or "+ ") .. s.name .. "|r")
        local lv = s.level > 0 and (L["Stufe %d"]:format(s.level) .. " · ") or ""
        r.sub:SetText(GREY .. lv .. L["%d von %d Teilen hast du"]:format(s.have, s.total) .. "|r")
        if e.open then r.sel:Show() end
        return
    end
    setIcon(r, e.id)
    local own = e.pickSlot ~= nil and ns.BisPick(e.pickSlot) == e.id
    local rec = firstSource(e.id, o)
    local mark = rec and rec[1] == "Q" and (" " .. PL.QUEST_MARK) or ""
    r.name:SetText((own and DK.ownMark() or "") .. (e.piece and "  " or "") .. K.itemText(e.id) .. mark)
    r.sub:SetText(subOf(e, o, rec))
    r.gain:SetText(gainOf(e))
    setArt(r.src, srcArt(rec))
    -- no source at all: a grey "?" where the symbol sits, nothing to click (D-107)
    r.srcQ:SetShown(rec == nil)
    setStar(r.star, wished(e.id))
    r.star:Show()
    if own then r.sel:Show() end
end

local function rowTip(self)
    local e = self.item
    if not e or e.note or e.header then return end
    if e.more then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(e.on and L["ohne bekannte Quelle ausblenden"] or L["Items ohne bekannte Quelle"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Amisia kennt die Werte aus dem Item-Scan, aber nicht, woher es kommt. Tötet jemand mit Amisia den Boss oder gibt eine Quest es als Belohnung, lernt Amisia die Quelle."], 1, 1, 1, true)
        GameTooltip:AddLine(e.on and L["Klick: wieder nur Items mit bekannter Quelle."] or L["Klick: sie in der Liste zeigen, nach Zuwachs einsortiert."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
        return
    end
    if e.set then return DK.setTip(self, e.set) end
    if e.pickRow then
        if e.stored then K.itemTooltip(self, e.stored) end
        return
    end
    if e.goal then
        if e.opt then K.itemTooltip(self, e.opt.id) end
        return
    end
    K.itemTooltip(self, e.id)
    local rec = firstSource(e.id, self:GetParent().opts)
    if rec then
        GameTooltip:AddLine(L["Quelle: %s"]:format(Gear.SourceText(rec, true) or ""), 0.85, 0.85, 0.85, true)
    else
        GameTooltip:AddLine(L["Amisia kennt die Werte aus dem Item-Scan, aber nicht, woher es kommt. Tötet jemand mit Amisia den Boss oder gibt eine Quest es als Belohnung, lernt Amisia die Quelle."], 0.85, 0.85, 0.85, true)
    end
    if e.pickSlot then
        GameTooltip:AddLine(L["Klick: deine Wahl für %s. Rechtsklick: Menü."]:format(ns.BIS_SLOT_NAME[e.pickSlot] or e.pickSlot),
            0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function rowClick(self, button)
    local e = self.item
    if not e or e.note or e.header then return end
    if e.more then
        NSR.SetOn(not e.on)
        return
    end
    if e.pickRow then
        if e.stored then K.modifiedClick(e.stored) end
        return
    end
    if e.goal then
        if button == "RightButton" then
            if e.opt then W.Menu(self, K.menuEntries(e.opt, ns.BisOpts())) end
            return
        end
        if e.opt and K.modifiedClick(e.opt.id) then return end
        -- a slot of the goals list: its suggestions
        local st = state()
        st.planSlot, st.planTab = e.key, "suggest"
        ns.Refresh()
        return
    end
    if e.set then
        openSet = (not e.open) and e.set.id or nil
        ns.Refresh()
        return
    end
    if button == "RightButton" then
        W.Menu(self, K.menuEntries({ id = e.id, wished = wished(e.id) }, ns.BisOpts()))
        return
    end
    if K.modifiedClick(e.id) then return end
    local slot = e.pickSlot
    if not slot then
        ns.msg(e.why or L["Das kann dein Charakter nicht tragen."])
        return
    end
    -- a click makes it the own pick of its slot, a second lifts it
    local ok, why = ns.BisSetPick(slot, (ns.BisPick(slot) ~= e.id) and e.id or nil)
    if not ok and why then ns.msg(why) end
    -- a link or id taken: the box is free again
    if ok and e.linkRow then query = "" ns.Refresh() end
end

local function buildRow(r)
    r.sel = W.SelectBar(r)
    -- the icon in its quality's frame
    r.frame = CreateFrame("Frame", nil, r)
    r.frame:SetSize(PL.ROW_ICON, PL.ROW_ICON)
    r.frame:SetPoint("LEFT", PL.ICON_X, 0)
    r.icon = r.frame:CreateTexture(nil, "ARTWORK")
    r.icon:SetPoint("TOPLEFT", PL.ROW_EDGE, -PL.ROW_EDGE)
    r.icon:SetPoint("BOTTOMRIGHT", -PL.ROW_EDGE, PL.ROW_EDGE)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    DK.roundIcon(r.frame, PL.DOLL, r.icon)   -- the thin rounded ring of the slots (D-81 Nachtrag)
    -- the right end: the gain, the source's symbol, the star
    local starX = PL.END
    local srcX = starX + PL.STAR + PL.END
    local gainX = srcX + PL.SRC + PL.END
    local textR = gainX + PL.GAIN_W + PL.END
    r.name = W.Text(r, T.FONT.body)
    r.textR = textR
    r.name:SetPoint("TOPLEFT", PL.TEXT_X, PL.NAME_Y)
    r.name:SetPoint("TOPRIGHT", -textR, PL.NAME_Y)
    r.sub = W.Text(r, T.FONT.hint)
    r.sub:SetPoint("TOPLEFT", PL.TEXT_X, PL.SUB_Y)
    r.sub:SetPoint("TOPRIGHT", -textR, PL.SUB_Y)
    r.gain = W.Text(r, T.FONT.body, PL.GAIN_W)
    r.gain:SetPoint("RIGHT", -gainX, 0)
    r.gain:SetJustifyH("RIGHT")
    -- the source's symbol: a click opens the dungeon at its boss or the recipe (F-157)
    r.srcBtn = CreateFrame("Button", nil, r)
    r.srcBtn:SetSize(PL.SRC, PL.SRC)
    r.srcBtn:SetPoint("RIGHT", -srcX, 0)
    r.src = r.srcBtn:CreateTexture(nil, "ARTWORK")
    r.src:SetAllPoints()
    r.srcQ = W.Text(r.srcBtn, T.FONT.body)
    r.srcQ:SetPoint("CENTER", 0, 0)
    r.srcQ:SetText(GREY .. "?|r")
    r.srcQ:Hide()
    r.srcBtn:SetScript("OnClick", function(self)
        local row = self:GetParent()
        local e = row.item
        if not (e and e.id and row.src:IsShown()) then return end
        local run = srcAction(firstSource(e.id, row:GetParent().opts), e.id)
        if run then run() end
    end)
    r.srcBtn:SetScript("OnEnter", function(self)
        local row = self:GetParent()
        local e = row.item
        local rec = e and e.id and row.src:IsShown() and firstSource(e.id, row:GetParent().opts)
        local _, line = srcAction(rec, e and e.id)
        if not line then return rowTip(row) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(Gear.SourceText(rec, true) or "", 1, 0.82, 0)
        GameTooltip:AddLine(line, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    r.srcBtn:SetScript("OnLeave", K.hideTip)
    r.star = CreateFrame("Button", nil, r)
    r.star:SetSize(PL.STAR, PL.STAR)
    r.star:SetPoint("RIGHT", -starX, 0)
    r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
    r.star.tex:SetAllPoints()
    r.star:SetScript("OnClick", function(self)
        local e = self:GetParent().item
        if not (e and e.id) then return end
        if wished(e.id) then ns.WishRemove(e.id) else K.say(ns.WishAdd(e.id)) end
    end)
    r.star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.on and L["Von der Wunschliste nehmen"] or L["Auf die Wunschliste"])
        GameTooltip:Show()
    end)
    r.star:SetScript("OnLeave", K.hideTip)
    -- "Deine Wahl": the red X lifts the own pick, "Übernehmen" takes the overtaking item
    r.del = W.ResetButton(r, T.RESET, function(self)
        local e = self:GetParent().item
        if e and e.pickRow then ns.BisSetPick(e.slot, nil) end
    end)
    r.del:SetPoint("RIGHT", -starX, 0)
    W.Tooltip(r.del, L["Wahl entfernen"], L["Amisia nimmt wieder das Beste für diesen Slot."])
    r.del:Hide()
    r.take = W.Link(r, L["Übernehmen"], function(self)
        local e = self:GetParent().item
        if e and e.pickRow and self.id then ns.BisSetPick(e.slot, self.id) end
    end)
    W.FitChip(r.take)
    r.take:SetPoint("RIGHT", -(starX + T.RESET + PL.END), 0)
    r.take:Hide()
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", rowClick)
    r:SetScript("OnEnter", rowTip)
    r:SetScript("OnLeave", K.hideTip)
end

---------------------------------------------------------------------------
-- The doll's enchant squares (Gear/Enchants.lua: the worn item's enchantment and what fits it)
---------------------------------------------------------------------------

local enchKey, enchBy
-- The enchantment data of every slot (ns.Enchants.ForSlot, false: none), read again only when what
-- is worn or the scores change.
local function enchAll()
    local E = ns.Enchants
    local links = { tostring(ns.BisStamp()) }
    for _, sl in ipairs(Gear.SLOTS) do links[#links + 1] = tostring(DK.wornLink(sl.key)) end
    local k = table.concat(links, "|")
    if k == enchKey and enchBy then return enchBy end
    enchKey, enchBy = k, {}
    for _, sl in ipairs(Gear.SLOTS) do
        local ok, v = pcall(E and E.ForSlot or function() end, sl.key)
        enchBy[sl.key] = ok and v or false
    end
    return enchBy
end

local function enchTip(self)
    local ench = self.data
    if not ench then return end
    local E = ns.Enchants
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Verzauberung: %s"]:format(ench.current and ench.current.name or (T.RED .. L["Keine"] .. "|r")), 1, 0.82, 0)
    if ench.current and ench.current.text ~= "" then GameTooltip:AddLine(ench.current.text, 1, 1, 1, true) end
    local best = ench.list[1]
    if best and best.scored and not best.later then
        GameTooltip:AddLine(L["Besser: %s (%s)"]:format(best.name, E.GainText(best)), 0.31, 0.82, 0.42, true)
    end
    GameTooltip:AddLine(L["Klick: passende Verzauberungen."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- The menu of a square: the enchantments that fit, the best first (a click sets the map target to
-- the recipe's trainer or vendor, Shift links it).
local function enchMenu(self)
    local ench = self.data
    if not ench then return end
    local E = ns.Enchants
    local out = {}
    for i = 1, math.min(PL.ENCH_ROWS, #ench.list) do
        local row = ench.list[i]
        local gain = row.later and L["ab %d"]:format(row.later) or E.GainText(row)
        out[#out + 1] = { gain ~= "" and ("%s  %s"):format(row.name, gain) or row.name, function() E.Click(row) end }
    end
    if #out == 0 then
        ns.msg(ench.current and L["Du hast schon die beste."] or L["Keine passende Verzauberung bringt dir etwas."])
        return
    end
    W.Menu(self, out)
end

-- A square beside a slot of the doll (towards the model; above a weapon); not for the shirt and
-- the tabard.
local function decorate(b, side)
    if not ns.BIS_SLOT_NAME[b.key] then return end
    local q = CreateFrame("Button", nil, b:GetParent())
    q:SetSize(PL.ENCH, PL.ENCH)
    if side == "right" then
        q:SetPoint("TOPRIGHT", b, "TOPLEFT", -PL.ENCH_GAP, 0)
    elseif side == "bottom" then
        q:SetPoint("BOTTOM", b, "TOP", 0, PL.ENCH_GAP)
    else
        q:SetPoint("TOPLEFT", b, "TOPRIGHT", PL.ENCH_GAP, 0)
    end
    q.bg = W.Flat(q, 0, 0, 0, 0.7)
    q.icon = q:CreateTexture(nil, "ARTWORK")
    q.icon:SetPoint("TOPLEFT", 1, -1)
    q.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    q.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    q.edges = W.Border(q, 0.45, 0.38, 0.25, 1)
    q.plus = W.Text(q, T.FONT.head)
    q.plus:SetPoint("CENTER", 0, 0)
    q.plus:SetText("+")
    q.slot = b.key
    q:SetScript("OnClick", enchMenu)
    q:SetScript("OnEnter", enchTip)
    q:SetScript("OnLeave", K.hideTip)
    q:Hide()
    b.ench = q
end

local function fillEnch(q, ench)
    q.data = ench or nil
    if not ench then
        q:Hide()
        return
    end
    if ench.current then
        q.icon:SetTexture(ns.Enchants.Icon(ench.current.id) or DK.QUESTION)
        q.icon:Show()
        q.plus:Hide()
    else
        q.icon:Hide()
        q.plus:Show()
    end
    q:Show()
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local function choose(key)
    local st = state()
    st.planSlot = key
    setCat, openSet, query = nil, nil, ""
    ns.Refresh()
end

-- The dressing room's background of the own race in four parts over the panel (FrameXML
-- DressUpFrame), the shade over it; without the client's file only the dark ground.
local function buildPanel(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 0, 0)
    p:SetPoint("BOTTOMLEFT", 0, 0)
    p.ground = W.Flat(p, PL.GROUND[1], PL.GROUND[2], PL.GROUND[3], PL.GROUND[4], "BACKGROUND")
    local B = PL.BG
    local lw = math.floor(leftW() * B.W[1] / (B.W[1] + B.W[2]) + 0.5)
    local th = math.floor(T.PAGE_H * B.H[1] / (B.H[1] + B.H[2]) + 0.5)
    p.parts = {}
    for i = 1, 4 do
        local t = p:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexCoord(unpack(B.COORDS[i]))
        p.parts[i] = t
    end
    local tl, tr, bl, br = p.parts[1], p.parts[2], p.parts[3], p.parts[4]
    tl:SetPoint("TOPLEFT", 0, 0)
    tl:SetSize(lw, th)
    tr:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
    tr:SetPoint("TOPRIGHT", 0, 0)
    tr:SetHeight(th)
    bl:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
    bl:SetPoint("BOTTOMLEFT", 0, 0)
    bl:SetWidth(lw)
    br:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT", 0, 0)
    br:SetPoint("BOTTOMRIGHT", 0, 0)
    p.shade = p:CreateTexture(nil, "BACKGROUND", nil, 2)
    p.shade:SetAllPoints()
    p.shade:SetColorTexture(PL.SHADE[1], PL.SHADE[2], PL.SHADE[3], PL.SHADE[4])
    p.edges = W.Border(p, T.HUB.LINE[1], T.HUB.LINE[2], T.HUB.LINE[3], T.HUB.LINE[4])
    -- the width: the parts keep their share
    function p.SetPanelWidth(w)
        p:SetWidth(w)
        local x = math.floor(w * B.W[1] / (B.W[1] + B.W[2]) + 0.5)
        tl:SetWidth(x)
        bl:SetWidth(x)
    end
    p.SetPanelWidth(leftW())
    return p
end

-- The race's background: its file, else another race's (RACES in turn), else none (the ground stays).
local function fillPanel(p)
    local race = UnitRace and select(2, UnitRace("player"))
    race = type(race) == "string" and race ~= "" and race or PL.BG.RACES[1]
    if p.race == race then return end
    p.race = race
    local base
    local order = { race }
    for _, r in ipairs(PL.BG.RACES) do order[#order + 1] = r end
    for _, r in ipairs(order) do
        local path = PL.BG.PATH .. r
        if not (GetFileIDFromPath and GetFileIDFromPath(path .. 1) == nil) then
            base = path
            break
        end
    end
    for i, t in ipairs(p.parts) do
        if base then
            t:SetTexture(base .. i)
            t:Show()
        else
            t:Hide()
        end
    end
end

-- The score under the doll (F-111): "Wertung 350 · +130" over a bar up to "Bestes auf Stufe N"
-- with a line at "jetzt"; the tooltip: now, the best, the six biggest stat changes.
local function scoreTip(self)
    local s = self.summary
    if not s then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Wertung %s"]:format(Gear.Num(s.score, 1)), 1, 0.82, 0)
    GameTooltip:AddLine(L["jetzt %s"]:format(Gear.Num(s.now, 1)), 1, 1, 1)
    GameTooltip:AddLine(L["Bestes auf Stufe %d: %s"]:format(s.level, Gear.Num(s.best, 1)), 1, 1, 1)
    GameTooltip:AddLine(L["Wertänderungen: Ziele gegen Angelegt"], 1, 0.82, 0)
    for i, d in ipairs(s.stats) do
        if i > 6 then break end
        local c = d.up and PL.STATE_COLOR.done or PL.DOWN_COLOR
        GameTooltip:AddLine(d.text, c[1], c[2], c[3])
    end
    if #s.stats == 0 then GameTooltip:AddLine(L["Keine Änderung."], 0.6, 0.6, 0.6) end
    if s.fx > 0 then GameTooltip:AddLine(L["Effekt nicht gewertet: %d Ziele"]:format(s.fx), 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

local function buildScore(f)
    local B = CreateFrame("Frame", nil, f.panel)
    B:SetHeight(LAY.ROW_H)
    B.text = W.Text(B, T.FONT.text)
    B.text:SetPoint("TOPLEFT", 0, -2)
    B.text:SetPoint("TOPRIGHT", 0, -2)
    B.bar = CreateFrame("Frame", nil, B)
    B.bar:SetHeight(PL.SCORE_BAR_H)
    B.bar:SetPoint("BOTTOMLEFT", 0, 2)
    B.bar:SetPoint("BOTTOMRIGHT", 0, 2)
    B.bar.bg = W.Flat(B.bar, PL.SCORE_BAR_BG[1], PL.SCORE_BAR_BG[2], PL.SCORE_BAR_BG[3], PL.SCORE_BAR_BG[4])
    B.bar.fill = B.bar:CreateTexture(nil, "ARTWORK")
    B.bar.fill:SetPoint("TOPLEFT")
    B.bar.fill:SetPoint("BOTTOMLEFT")
    B.bar.fill:SetColorTexture(PL.SCORE_BAR[1], PL.SCORE_BAR[2], PL.SCORE_BAR[3], PL.SCORE_BAR[4])
    B.bar.mark = B.bar:CreateTexture(nil, "OVERLAY")
    B.bar.mark:SetSize(PL.MARK_W, PL.SCORE_BAR_H + 2)
    B.bar.mark:SetColorTexture(1, 1, 1, 0.9)
    B:EnableMouse(true)
    B:SetScript("OnEnter", scoreTip)
    B:SetScript("OnLeave", K.hideTip)
    f.score = B
end

local function fillScore(f, res, o)
    local B = f.score
    local s = ns.BisSummary(res, o)
    B.summary = s
    local g = s.gain
    B.text:SetText(L["Wertung %s"]:format(Gear.Num(s.score, 0)) .. " · " .. (g >= 0 and GREEN or T.RED) .. (g >= 0 and "+" or "-")
        .. Gear.Num(math.abs(g), 0) .. "|r")
    local w = B:GetWidth() or 1
    local max = math.max(s.best, s.score, s.now, 1)
    local fw = math.max(0, math.min(1, s.score / max)) * w
    B.bar.fill:SetWidth(math.max(1, fw))
    B.bar.fill:SetShown(fw >= 1)
    B.bar.mark:ClearAllPoints()
    B.bar.mark:SetPoint("CENTER", B.bar, "LEFT", math.max(0, math.min(1, s.now / max)) * w, 0)
end

local function resetPicks()
    local o = ns.BisOpts()
    local sp = Gear.SpecInfo(o.class, o.spec)
    W.Confirm(L["Eigene Wahlen zurücksetzen"],
        L["Alle eigenen Wahlen für %s entfernen? Amisia nimmt dann wieder das Beste je Platz."]:format(sp and L[sp.name] or "?"),
        L["Zurücksetzen"], function()
            for _, sl in ipairs(Gear.SLOTS) do
                if ns.BisPick(sl.key) then ns.BisSetPick(sl.key, nil) end
            end
        end)
end

local function warnTip(self)
    local unused = self.unused
    if not unused then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Eine eigene Wahl wird nicht genutzt"], 1, 0.82, 0)
    for _, sl in ipairs(Gear.SLOTS) do
        local code = unused[sl.key]
        if code then
            GameTooltip:AddLine(("%s: %s"):format(sl.name, code == "plan" and L["Passt nicht zum Waffenplan"] or L["Das kann dein Charakter nicht tragen."]),
                1, 1, 1, true)
        end
    end
    GameTooltip:AddLine(L["Klick: den ersten dieser Plätze wählen."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- The menu "Optionen": the weapon plan (ns.BisSetPlan), the gear page's source switches
-- (ns.BisOpts().sources, saved; a click turns one on or off for every target) and the play style's
-- menu (F-124).
local SRC_LABEL = { X = "Raids", D = "Dungeons", Q = "Quests", C = L["Berufe"], V = L["Händler"], P = "PvP", W = L["Welt"], A = "AH" }
local function optionsMenu(self)
    local o = ns.BisOpts()
    local out = {}
    for _, k in ipairs(ns.BIS_PLAN_ORDER) do
        out[#out + 1] = { ((o.plan or "auto") == k and CHECK or "") .. L["Waffen: %s"]:format(ns.BIS_PLANS[k]), function()
            K.say(ns.BisSetPlan(k))
        end }
    end
    for _, k in ipairs(PL.SOURCES) do
        out[#out + 1] = { (o.sources[k] and CHECK or "") .. L["Quelle: %s"]:format(SRC_LABEL[k] or k), function()
            local src = ns.BisOpts().sources
            src[k] = not src[k]
            ns.Fire("BIS_CHANGED")
        end }
    end
    if NSR then
        out[#out + 1] = { (NSR.On() and CHECK or "") .. L["Items ohne bekannte Quelle"], function() NSR.SetOn(not NSR.On()) end }
    end
    local n = ns.PlayStyle.Count()
    out[#out + 1] = { n > 0 and L["Spielstil (%d) ..."]:format(n) or L["Spielstil ..."], function() W.Menu(self, K.styleEntries(self)) end }
    W.Menu(self, out)
end

-- Its tooltip: the weapon plan as the targets show it, the play style, why these weights (ns.BisWhy).
local function optionsTip(self)
    local f = self:GetParent()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Optionen"], 1, 0.82, 0)
    if f.planText then GameTooltip:AddLine(f.planText, 1, 1, 1) end
    local names = ns.PlayStyle.Names()
    GameTooltip:AddLine(L["Spielstil: %s"]:format(names or L["aus"]), 1, 1, 1, true)
    GameTooltip:AddLine(L["Warum diese Gewichte"], 1, 0.82, 0)
    for _, line in ipairs(ns.BisWhy()) do GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
    GameTooltip:AddLine(L["Klick: Waffenplan, Quellen und Spielstil."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function fillHead(f, o, res)
    local name = ns.Plain(UnitName("player")) or "?"
    f.who:SetText(T.GOLD_TEXT .. name .. "|r  |cffffffff" .. L["Stufe %d"]:format(o.level) .. " ·|r")
    K.fillSpec(f.spec, o)
    -- name and picker centred in the panel's head
    local lw = leftW()
    local maxW = lw - 2 * PL.PAD - PL.SPEC_W - PL.WHO_GAP
    local w = math.min(maxW, math.ceil((f.who:GetStringWidth() or 0) + 2))
    f.who:SetWidth(w)
    f.who:ClearAllPoints()
    f.who:SetPoint("LEFT", f.headLeft, "LEFT", math.floor((lw - w - PL.WHO_GAP - PL.SPEC_W) / 2), 0)
    f.spec:ClearAllPoints()
    f.spec:SetPoint("LEFT", f.who, "RIGHT", PL.WHO_GAP, 0)
    local searching = query:find("%S") ~= nil
    local tab = shownTab()
    f.tabSuggest:SetOn(tab == "suggest" and not setCat and not searching)
    f.tabGoals:SetOn(tab == "goals" and not setCat and not searching)
    f.tabWish:SetOn(tab == "wish" and not setCat and not searching)
    f.planText = DK.planText(o, res)
    f.warn.unused = res.ownUnused
    local warn = res.ownUnused ~= nil and next(res.ownUnused) ~= nil
    f.warn:SetShown(warn)
    local row = { f.headLeft, { f.tabSuggest, gap = PL.GAP }, f.tabGoals, f.tabWish }
    if warn then row[#row + 1] = f.warn end
    row[#row + 1] = f.optLink
    row[#row + 1] = { f.search, fill = true }
    f:Place(1, row)
    if not f.search:HasFocus() and (f.search:GetText() or "") ~= query then f.search:SetText(query) end
end

local RANGE_PARTS = { "title", "lvl", "lo", "dash", "hi", "mine", "all" }
local GOAL_PARTS = { "prog", "fall", "ftodo", "fbag", "fench" }
local FILTER_LABEL = { all = L["Alle"], todo = L["Zu holen %d"], bag = L["Tasche %d"], ench = L["Ohne Verz. %d"] }

local function showParts(f, list, on)
    for _, k in ipairs(list) do f[k]:SetShown(on) end
end

-- The second row: the slot's name and the level range; on the tab Ziele "N/17 Ziele" over its bar
-- and the filters Alle / Zu holen / Tasche / Ohne Verz.
local function fillRange(f, lo, hi, title, res)
    local goals = shownTab() == "goals" and not setCat and not query:find("%S")
    showParts(f, RANGE_PARTS, not goals)
    showParts(f, GOAL_PARTS, goals)
    if goals then
        local p = ns.BisProgress(res)
        f.prog.text:SetText(L["%d/%d Ziele"]:format(p.done, p.total))
        f.prog.bar.progress = p
        for i, sl in ipairs(Gear.SLOTS) do
            local c = PL.STATE_COLOR[p.slot[sl.key]] or PL.STATE_COLOR.none
            f.prog.parts[i]:SetColorTexture(c[1], c[2], c[3], 1)
        end
        local ench = 0
        for _ in pairs(DK.unenchanted()) do ench = ench + 1 end
        local counts = { todo = p.todo, bag = p.bag, ench = ench }
        local cur, row = filter(), {}
        for _, key in ipairs(FILTERS) do
            local chip = f["f" .. key]
            chip.label:SetText(key == "all" and FILTER_LABEL.all or FILTER_LABEL[key]:format(counts[key] or 0))
            W.FitChip(chip)
            chip:SetOn(key == cur)
            row[#row + 1] = chip
        end
        f:Place(2, { f.room, { f.prog, gap = PL.GAP } }, row)
        return
    end
    if not f.lo:HasFocus() then f.lo:SetText(tostring(lo)) end
    if not f.hi:HasFocus() then f.hi:SetText(tostring(hi)) end
    f.mine:SetOn(lo == 1 and hi == ownLevel())
    f.all:SetOn(lo == 1 and hi == Gear.Cap())
    f.title:SetText(title or "")
    f:Place(2, { f.room, { f.title, gap = PL.GAP, fill = true } }, { f.lvl, f.lo, f.dash, f.hi, f.mine, f.all })
end

-- a level box: a whole number from 1 to the data's cap, the other end follows
local function levelBox(f, isLo)
    return W.TimeBox(f, PL.LEVEL_W, function(text)
        local v = tonumber(text)
        local lo, hi = range()
        if not v or v % 1 ~= 0 then
            ns.Refresh()
            return
        end
        v = math.max(1, math.min(Gear.Cap(), v))
        if isLo then setRange(v, math.max(v, hi)) else setRange(math.min(lo, v), v) end
    end)
end

local MARK_LABEL = {}
for _, c in ipairs(Cat.CATS) do MARK_LABEL[c.key] = c.label end

ns.RegisterPanel{ key = "planner", label = L["Ausrüstungsplaner"], sub = L["Dein Modell mit allen Plätzen, Vorschläge je Platz, deine Wahl per Klick."],
    order = 49, group = "gear",
    available = function() return Gear.Available() end,
    create = function(parent)
        local f = W.Page(parent)
        -- the panel first: the head row's name and picker and the doll draw over it
        f.panel = buildPanel(f)
        f:Bands({ "row", "row" })
        f.headLeft = CreateFrame("Frame", nil, f.panel)
        f.headLeft:SetSize(leftW(), LAY.ROW_H)
        f.headLeft:Show()
        f.who = W.Text(f.headLeft, T.FONT.title, 100)
        f.spec = K.specPicker(f.headLeft)
        f.spec:SetWidth(PL.SPEC_W)
        f.tabSuggest = W.Tab(f, L["Vorschläge"], function()
            state().planTab = "suggest"
            setCat, openSet, query = nil, nil, ""
            ns.Refresh()
        end)
        f.tabGoals = W.Tab(f, L["Ziele"], function()
            state().planTab = "goals"
            setCat, openSet, query = nil, nil, ""
            ns.Refresh()
        end)
        W.Tooltip(f.tabGoals, L["Ziele"], L["Alle Plätze mit deinem Ziel, wie viele du hast und was noch fehlt. Klick auf einen Platz: seine Vorschläge."])
        f.tabWish = W.Tab(f, L["Wunschliste"], function()
            state().planTab = "wish"
            setCat, openSet, query = nil, nil, ""
            ns.Refresh()
        end)
        W.Tooltip(f.tabSuggest, L["Vorschläge"], L["Die besten Items für den gewählten Platz auf deiner Stufenauswahl."])
        W.Tooltip(f.tabWish, L["Wunschliste"], L["Die Items, die du dir gemerkt hast (der Stern einer Zeile)."])
        f.warn = CreateFrame("Button", nil, f)
        f.warn:SetSize(PL.WARN_SIZE, PL.WARN_SIZE)
        f.warn.tex = f.warn:CreateTexture(nil, "ARTWORK")
        f.warn.tex:SetAllPoints()
        setArt(f.warn.tex, PL.WARN)
        f.warn:SetScript("OnEnter", warnTip)
        f.warn:SetScript("OnLeave", K.hideTip)
        f.warn:SetScript("OnClick", function(self)
            for _, sl in ipairs(Gear.SLOTS) do
                if self.unused and self.unused[sl.key] then return choose(sl.key) end
            end
        end)
        f.warn:Hide()
        f.optLink = W.Link(f, L["Optionen"], optionsMenu)
        W.FitChip(f.optLink)
        f.optLink:HookScript("OnEnter", optionsTip)
        f.optLink:HookScript("OnLeave", K.hideTip)
        f.search = W.SearchBox(f, T.LINE_W, function(text)
            query = text or ""
            ns.Refresh()
        end, L["Item suchen ..."])
        W.Tooltip(f.search, L["Item suchen ..."], L["Ein Name sucht alle Items; ein Item-Link (Shift-Klick) oder eine ID: ein Klick macht es zu deiner Wahl für den gewählten Platz."])
        -- typing searches after a short pause
        f.search:HookScript("OnTextChanged", function(self, user)
            if not user then return end
            local text = self:GetText()
            C_Timer.After(0.3, function()
                if self:GetText() == text and query ~= text then
                    query = text
                    ns.Refresh()
                end
            end)
        end)
        -- a link Shift-clicked while the box has the focus goes into it (the field "Item-Link oder ID")
        local function takeLink(link)
            if type(link) == "string" and f.search:HasFocus() then
                f.search:SetText(link)
                query = link
                ns.Refresh()
                return true
            end
        end
        if type(hooksecurefunc) == "function" then
            if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
                hooksecurefunc(ChatFrameUtil, "InsertLink", ns.Perf.Wrap("Hook InsertLink Planner", takeLink))
            elseif type(ChatEdit_InsertLink) == "function" then
                hooksecurefunc("ChatEdit_InsertLink", ns.Perf.Wrap("Hook ChatEdit_InsertLink Planner", takeLink))
            end
        end
        f.takeLink = takeLink
        -- the second row: the slot's name (or the set category) and the level range
        f.room = CreateFrame("Frame", nil, f)
        f.room:SetSize(leftW(), 1)
        f.room:Show()
        f.title = W.Text(f, T.FONT.title)
        f.lvl = W.Text(f, T.FONT.text)
        f.lvl:SetText(L["Stufe"])
        f.lo = levelBox(f, true)
        f.dash = W.Text(f, T.FONT.text)
        f.dash:SetText("-")
        f.hi = levelBox(f, false)
        W.Tooltip(f.lo, L["Stufe von"], L["Die kleinste Mindeststufe der Items in der Liste."])
        W.Tooltip(f.hi, L["Stufe bis"], L["Die größte Mindeststufe der Items in der Liste; über deiner Stufe rechnet Amisia auf dieser Stufe."])
        f.mine = W.Tab(f, L["Meine Stufe"], function() setRange(1, ownLevel()) end)
        W.Tooltip(f.mine, L["Meine Stufe"], L["Stufe 1 bis deine Stufe: alles, was du jetzt tragen kannst."])
        f.all = W.Tab(f, L["Alle"], function() setRange(1, Gear.Cap()) end)
        -- the tab Ziele: the progress over its bar of 17 parts, the filters
        f.prog = CreateFrame("Frame", nil, f)
        f.prog:SetSize(PL.PROG_W, LAY.ROW_H)
        f.prog.text = W.Text(f.prog, T.FONT.title, PL.PROG_W)
        f.prog.text:SetPoint("TOPLEFT", 0, -1)
        f.prog.bar = CreateFrame("Frame", nil, f.prog)
        f.prog.bar:SetSize(PL.PROG_W, PL.BAR_H)
        f.prog.bar:SetPoint("BOTTOMLEFT", 0, 1)
        f.prog.parts = {}
        local n = #Gear.SLOTS
        local pw = (PL.PROG_W - (n - 1) * PL.BAR_PART_GAP) / n
        for i = 1, n do
            local t = f.prog.bar:CreateTexture(nil, "ARTWORK")
            t:SetSize(pw, PL.BAR_H)
            t:SetPoint("TOPLEFT", (i - 1) * (pw + PL.BAR_PART_GAP), 0)
            f.prog.parts[i] = t
        end
        f.prog:EnableMouse(true)
        f.prog:SetScript("OnEnter", function(self)
            local p = self.bar.progress
            if not p then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["%d/%d Ziele hast du"]:format(p.done, p.total), 1, 0.82, 0)
            GameTooltip:AddLine(L["%d angelegt, %d in Tasche oder Bank, %d zu holen, %d ohne Ziel"]:format(p.done, p.bag, p.todo, p.none),
                1, 1, 1, true)
            GameTooltip:Show()
        end)
        f.prog:SetScript("OnLeave", K.hideTip)
        for _, key in ipairs(FILTERS) do
            f["f" .. key] = W.Tab(f, FILTER_LABEL.all, function()
                state().planFilter = key ~= "all" and key or nil
                ns.Refresh()
            end)
        end
        W.Tooltip(f.ftodo, L["Zu holen"], L["Plätze, deren Ziel du noch nicht hast."])
        W.Tooltip(f.fbag, L["In der Tasche"], L["Plätze, deren Ziel in Tasche oder Bank liegt, aber nicht angelegt ist."])
        W.Tooltip(f.fench, L["Ohne Verzauberung"], L["Angelegte Items in verzauberbaren Slots ohne Verzauberung (dieselbe Prüfung wie der Raid-Check). Nur ein Hinweis, keine Empfehlung."])
        for _, b in ipairs({ f.tabSuggest, f.tabGoals, f.tabWish, f.mine, f.all }) do W.FitChip(b) end
        for _, fs in ipairs({ f.lvl, f.dash }) do fs:SetWidth(math.ceil((fs:GetStringWidth() or 0) + 2)) end
        -- the doll in the panel
        f.doll = DK.buildDoll(f.panel, PL.DOLL, { onChoose = choose, decorate = decorate })
        f.doll:SetPoint("TOPLEFT", PL.PAD, -PL.DOLL_Y)
        f.doll.SetDollWidth(leftW() - 2 * PL.PAD)
        f.doll.doneEdge = true
        f.reset = W.Button(f.panel, L["Zurücksetzen"], PL.RESET_W, resetPicks)
        W.FitChip(f.reset, PL.RESET_W)
        f.reset:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -PL.PAD, PL.PAD)
        -- under the weapons the switch Ziele | Angelegt, at the bottom left the score
        f.showGoals = W.Tab(f.panel, L["Ziele"], function() state().planWorn = nil; ns.Refresh() end)
        f.showWorn = W.Tab(f.panel, L["Angelegt"], function() state().planWorn = true; ns.Refresh() end)
        W.Tooltip(f.showGoals, L["Ziele"], L["Das Modell trägt deine Ziele."])
        W.Tooltip(f.showWorn, L["Angelegt"], L["Das Modell trägt, was du angelegt hast."])
        W.FitChip(f.showGoals)
        W.FitChip(f.showWorn)
        buildScore(f)
        f.score:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", PL.PAD, PL.PAD)
        W.Tooltip(f.reset, L["Zurücksetzen"], L["Deine eigenen Wahlen dieser Spezialisierung entfernen."])
        -- the list in the right half, down to the page's bottom
        f:Footer({ { "help", help = true } })
        f.help:SetText(L["Klick auf einen Platz: seine Vorschläge. Klick auf eine Zeile: deine Wahl für den Platz, nochmal: aufheben. Stern: Wunschliste. Das Quadrat neben einem Platz: die Verzauberung."])
        f.list = W.List(f, PL.MIN_ROWS, PL.ROW_H, buildRow, fillRow)
        -- the split follows the page's width (D-71): the panel, the doll, the right half and its list
        local function layout()
            local lw = leftW()
            f.panel.SetPanelWidth(lw)
            f.headLeft:SetWidth(lw)
            f.room:SetWidth(lw)
            f.doll.SetDollWidth(lw - 2 * PL.PAD)
            local sw = f.showGoals:GetWidth() + T.TAB_GAP + f.showWorn:GetWidth()
            W.Row(f.panel, { f.showGoals, f.showWorn }, T.TAB_GAP, math.floor((lw - sw) / 2),
                -(PL.DOLL_Y + PL.DOLL.MODEL_H + PL.DOLL.WEAPON_GAP + PL.DOLL.SLOT + PL.SWITCH_GAP))
            f.score:SetWidth(lw - 2 * PL.PAD - f.reset:GetWidth() - LAY.ITEM_GAP)
            f.list:ClearAllPoints()
            f.list:SetPoint("TOPLEFT", lw + PL.GAP, f.top)
            f.list:SetWidth((T.PAGE_W_NOW or T.PAGE_W) - lw - PL.GAP - T.SCROLL_ROOM)
        end
        layout()
        W.FollowWidth(f, function()
            layout()
            if f:IsShown() and ns.RefreshSoon then ns.RefreshSoon() end
        end)
        W.FillTo(f.list, f, f.top, PL.MIN_ROWS, PL.ROW_H)
        return f
    end,
    refresh = function(f)
        K.namesFresh()
        local o = ns.BisOpts()
        local res = ns.BisTargets()
        local chosen = chosenSlot(res)
        local lo, hi = range()
        fillPanel(f.panel)
        fillHead(f, o, res)
        local m = dollMode()
        DK.fillDoll(f.doll, res, m, chosen)
        DK.dress(f.doll, res, m)
        f.showGoals:SetOn(m == "goals")
        f.showWorn:SetOn(m == "worn")
        fillScore(f, res, o)
        local ench = enchAll()
        for key, b in pairs(f.doll.slots) do
            if b.ench then fillEnch(b.ench, ench[key]) end
        end
        f.reset:SetEnabled(hasPicks(o))
        local rows, title = listRows(res, o, chosen, lo, hi)
        fillRange(f, lo, hi, title, res)
        f.list.opts = o
        f.list:SetItems(rows)
    end,
    -- the side bar's marks: the set categories with their counts on the level range, Ruf in a block of its own
    jumps = function()
        local lo, hi = range()
        local out = {}
        for _, key in ipairs(PL.MARKS) do
            out[#out + 1] = { key = key, label = MARK_LABEL[key] or key, icon = PL.MARK_ICONS[key], on = setCat == key,
                rule = key == "rep", count = Cat.Count(key, lo, hi) }
        end
        return out
    end,
    jump = function(f, key)
        if not Cat.ValidCat(key) then return end
        setCat, openSet, query = key, nil, ""
        if f.search then f.search:SetText("") end
        ns.Refresh()
    end }

-- Opens the page: view "suggest" or "wish" (the tab), "sets" with a category of the catalog, "search"
-- with a text; slotKey: the chosen slot.
function ns.ShowPlanner(view, arg, slotKey)
    local st = state()
    if view == "suggest" or view == "wish" or view == "goals" then
        st.planTab, setCat, openSet, query = view, nil, nil, ""
    elseif view == "sets" and Cat.ValidCat(arg) then
        setCat, openSet, query = arg, nil, ""
    elseif view == "search" then
        setCat, openSet, query = nil, nil, tostring(arg or "")
    end
    if ns.BIS_SLOT_NAME[slotKey] then st.planSlot = slotKey end
    if ns.ShowPage then ns.ShowPage("planner") end
end

-- What changes the targets, the wishes or the own items: shown at once while the page is open (the
-- own items with the next frame); item names that arrive fill the rows again (and the search's hits).
local function onPage() return ns.CurrentPage and ns.CurrentPage() == "planner" end
ns.Listen("BIS_CHANGED", function() if onPage() then ns.Refresh() end end)
ns.BisOnOwned(function() if onPage() then ns.RefreshSoon() end end)
local namesDue = false
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if namesDue or not onPage() or not (K.nameMissing() or query:find("%S")) then return end
    namesDue = true
    C_Timer.After(0.3, function()
        namesDue = false
        memo.key = nil
        if onPage() then ns.Refresh() end
    end)
end)
end)
