-- The page "Ausrüstungsplaner" (F-149, D-77, spec docs/specs/2026-11-08-hub-reiter.md), the first page
-- of the tab Ausrüstung. Left a dark panel on the dressing room's background of the own race: at its
-- top the own name, level and the gear page's spec picker; the doll of the window "Ausrüstungsziele"
-- (one builder, ns.GoalsKit, in the size profile T.PLANNER.DOLL): the model between two columns of
-- eight slots as on the character frame, the weapons under it, each slot the target (the own pick
-- first, D-55) in its quality's frame (green: worn) and beside it a small square with the enchantment
-- on the worn item or a "+" (Gear/Enchants.lua: a click lists what fits); at the bottom
-- "Zurücksetzen" (the own picks of the spec, after a question). Right the tabs Vorschläge |
-- Wunschliste, a warning while an own pick is not used, the search over every item; under them the
-- chosen slot's name, the level boxes "[lo] - [hi]" and Meine Stufe | Alle; the list: icon, name, "Stufe N ·
-- source", the gain, the source's symbol and the wish star. A click on a row makes it the own pick of
-- its slot (again: lifts it). The side bar's marks are the catalog's set categories (Gear/Catalog.lua):
-- one shows that category's sets in the list instead, a set opens to its pieces; the tab Vorschläge
-- leads back. State in
-- settings.bis (planSlot, planTab, planLo, planHi); the set category, the open set and the search
-- text only in memory. Nothing is sent.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local PL = T.PLANNER
local LAY = T.LAYOUT
local Gear = ns.Gear
local K = ns.GearPageKit
local DK = ns.GoalsKit
local Cat = ns.Catalog
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

local TABS = { suggest = true, wish = true }
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

-- The rows the list shows now and the line over it.
local function listRows(res, o, chosen, lo, hi)
    local rows, title = {}, nil
    if query:find("%S") then
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
    else
        for _, e in ipairs(suggestions(res, o, chosen, lo, hi)) do rows[#rows + 1] = e end
        title = ns.BIS_SLOT_NAME[chosen] or chosen
        if #rows == 0 then rows[1] = { note = noSuggestion(res, chosen, lo, hi) } end
    end
    for _, e in ipairs(rows) do
        if e.id then e.pickSlot = pickSlot(e.slotKey, chosen) end
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

local function setStar(b, on)
    local tex = b.tex
    if W.HasAtlas(PL.STAR_ATLAS) then tex:SetAtlas(PL.STAR_ATLAS, false) else tex:SetTexture(PL.STAR_FILE) end
    if tex.SetDesaturated then tex:SetDesaturated(not on) end
    local c = on and { 1, 1, 1 } or PL.STAR_OFF
    tex:SetVertexColor(c[1], c[2], c[3])
    b.on = on
end

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

local function hideItemParts(r)
    r.frame:Hide()
    r.src:Hide()
    r.star:Hide()
    r.gain:SetText("")
end

local function fillRow(r, e)
    r.sel:Hide()
    if e.note then
        hideItemParts(r)
        r.name:SetText(GREY .. e.note .. "|r")
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
    local o = r:GetParent().opts
    r.frame:Show()
    r.icon:SetTexture(DK.iconOf(e.id) or DK.QUESTION)
    local q = DK.qualityOf(e.id)
    local c = T.QUALITY_RGB[q or 1] or T.QUALITY_RGB[1]
    W.SetBorderColor(r.edges, c[1], c[2], c[3], 1)
    local own = e.pickSlot ~= nil and ns.BisPick(e.pickSlot) == e.id
    local rec = firstSource(e.id, o)
    local mark = rec and rec[1] == "Q" and (" " .. PL.QUEST_MARK) or ""
    r.name:SetText((own and DK.ownMark() or "") .. (e.piece and "  " or "") .. K.itemText(e.id) .. mark)
    r.sub:SetText(subOf(e, o, rec))
    r.gain:SetText(gainOf(e))
    setArt(r.src, srcArt(rec))
    setStar(r.star, wished(e.id))
    r.star:Show()
    if own then r.sel:Show() end
end

local function rowTip(self)
    local e = self.item
    if not e or e.note then return end
    if e.set then return DK.setTip(self, e.set) end
    K.itemTooltip(self, e.id)
    local rec = firstSource(e.id, self:GetParent().opts)
    if rec then GameTooltip:AddLine(L["Quelle: %s"]:format(Gear.SourceText(rec, true) or ""), 0.85, 0.85, 0.85, true) end
    if e.pickSlot then
        GameTooltip:AddLine(L["Klick: deine Wahl für %s. Rechtsklick: Menü."]:format(ns.BIS_SLOT_NAME[e.pickSlot] or e.pickSlot),
            0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function rowClick(self, button)
    local e = self.item
    if not e or e.note then return end
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
    r.edges = W.Border(r.frame, 1, 1, 1, 1, PL.ROW_EDGE)
    -- the right end: the gain, the source's symbol, the star
    local starX = PL.END
    local srcX = starX + PL.STAR + PL.END
    local gainX = srcX + PL.SRC + PL.END
    local textR = gainX + PL.GAIN_W + PL.END
    r.name = W.Text(r, T.FONT.body)
    r.name:SetPoint("TOPLEFT", PL.TEXT_X, PL.NAME_Y)
    r.name:SetPoint("TOPRIGHT", -textR, PL.NAME_Y)
    r.sub = W.Text(r, T.FONT.hint)
    r.sub:SetPoint("TOPLEFT", PL.TEXT_X, PL.SUB_Y)
    r.sub:SetPoint("TOPRIGHT", -textR, PL.SUB_Y)
    r.gain = W.Text(r, T.FONT.body, PL.GAIN_W)
    r.gain:SetPoint("RIGHT", -gainX, 0)
    r.gain:SetJustifyH("RIGHT")
    r.src = r:CreateTexture(nil, "ARTWORK")
    r.src:SetSize(PL.SRC, PL.SRC)
    r.src:SetPoint("RIGHT", -srcX, 0)
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

-- The menu "Quellen": the gear page's source switches (ns.BisOpts().sources, saved), a click turns
-- one on or off for every target.
local SRC_LABEL = { X = "Raids", D = "Dungeons", Q = "Quests", C = L["Berufe"], V = L["Händler"], P = "PvP", W = L["Welt"], A = "AH" }
local function srcMenu(self)
    local src = ns.BisOpts().sources
    local out = {}
    for _, k in ipairs(PL.SOURCES) do
        out[#out + 1] = { (src[k] and CHECK or "") .. (SRC_LABEL[k] or k), function()
            local s = ns.BisOpts().sources
            s[k] = not s[k]
            ns.Fire("BIS_CHANGED")
        end }
    end
    W.Menu(self, out)
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
    f.tabWish:SetOn(tab == "wish" and not setCat and not searching)
    f.warn.unused = res.ownUnused
    local warn = res.ownUnused ~= nil and next(res.ownUnused) ~= nil
    f.warn:SetShown(warn)
    local row = { f.headLeft, { f.tabSuggest, gap = PL.GAP }, f.tabWish }
    if warn then row[#row + 1] = f.warn end
    row[#row + 1] = f.srcLink
    row[#row + 1] = { f.search, fill = true }
    f:Place(1, row)
    if not f.search:HasFocus() and (f.search:GetText() or "") ~= query then f.search:SetText(query) end
end

local function fillRange(f, lo, hi, title)
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
        f.srcLink = W.Link(f, L["Quellen"], srcMenu)
        W.FitChip(f.srcLink)
        W.Tooltip(f.srcLink, L["Quellen"], L["Woher die Vorschläge kommen dürfen: dieselben Schalter wie auf der Seite Ausrüstung."])
        f.search = W.SearchBox(f, T.LINE_W, function(text)
            query = text or ""
            ns.Refresh()
        end, L["Alle Items suchen ..."])
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
        for _, b in ipairs({ f.tabSuggest, f.tabWish, f.mine, f.all }) do W.FitChip(b) end
        for _, fs in ipairs({ f.lvl, f.dash }) do fs:SetWidth(math.ceil((fs:GetStringWidth() or 0) + 2)) end
        -- the doll in the panel
        f.doll = DK.buildDoll(f.panel, PL.DOLL, { onChoose = choose, decorate = decorate })
        f.doll:SetPoint("TOPLEFT", PL.PAD, -PL.DOLL_Y)
        f.doll.SetDollWidth(leftW() - 2 * PL.PAD)
        f.doll.doneEdge = true
        f.reset = W.Button(f.panel, L["Zurücksetzen"], PL.RESET_W, resetPicks)
        W.FitChip(f.reset, PL.RESET_W)
        f.reset:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -PL.PAD, PL.PAD)
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
        DK.fillDoll(f.doll, res, "goals", chosen)
        DK.dress(f.doll, res, "goals")
        local ench = enchAll()
        for key, b in pairs(f.doll.slots) do
            if b.ench then fillEnch(b.ench, ench[key]) end
        end
        f.reset:SetEnabled(hasPicks(o))
        local rows, title = listRows(res, o, chosen, lo, hi)
        fillRange(f, lo, hi, title)
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
    if view == "suggest" or view == "wish" then
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
