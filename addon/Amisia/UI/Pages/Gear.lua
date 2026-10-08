-- Gear page: the best items of the own character per slot ("Ziele") with the
-- three options of a slot, the buttons to wish or exclude and the explained score; what a place
-- still offers ("Hier"); the dungeon planner ("Dungeons": the next dungeon, every dungeon's value
-- sorted by level, by value or as the chain, the chosen one's bosses and upgrades or its quests with
-- pre-quests, start and rewards, the waypoints to its entrance and quest givers); the own wishlist with
-- its text for the website ("Wunschliste"); the guild wishes pasted from the website ("Gilde",
-- import for officers). Plus the overview card.
-- Everything shown comes from the caches of Bis.lua; a refresh never computes the targets again
-- unless something they depend on changed.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local Gear = ns.Gear
local GREY, GREEN = T.GREY, "|cff4fd06a"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t"
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local ROW_H = 24
local GOAL_ROWS, HERE_ROWS, WISH_ROWS, GUILD_ROWS = 11, 14, 12, 11
local DUNGEON_ROWS, DETAIL_ROWS = 6, 5
local PRIO_TEXT = { [3] = L["hoch"], [2] = L["mittel"], [1] = L["niedrig"] }
local PRIO_NEXT = { [3] = 2, [2] = 1, [1] = 3 }
local PRIO_TIP = { [3] = L[" (hoch)"], [1] = L[" (niedrig)"] }
local OWNED_TEXT = { worn = L["angelegt"], bag = L["in der Tasche, nicht angelegt"], bank = L["in der Bank, nicht angelegt"] }
local VIEWS = { goals = true, here = true, dungeons = true, wish = true, guild = true, sim = true }
-- the source chips: key, label, width
local CHIPS = { { "X", "Raids", 48 }, { "Q", "Quests", 50 }, { "D", "Dungeons", 64 }, { "C", L["Berufe: alle"], 86 },
                { "V", L["Händler"], 56 }, { "W", L["Welt"], 40 }, { "A", "AH", 32 }, { "P", "PvP", 36 } }

local page
local groupOnly          -- the guild view's "Nur Gruppe"; nil: on while in a raid
local exportOpen = false -- the wishlist shows the text for the website instead of the list
local exportText = ""
local guildResult        -- what the last import said
local scrolledTo         -- the slot the targets list was last scrolled to
local placeGone          -- the saved place of "Hier" was not in the data

local function itemInfo(x)
    local f = C_Item and C_Item.GetItemInfo
    if f then return f(x) end
    return nil
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- The window state of the page in settings.bis (view, slot, place, sources).
local function state()
    local s = AmisiaDB.settings
    s.bis = type(s.bis) == "table" and s.bis or {}
    return s.bis
end

-- What a refresh keeps until Bis.lua's state changes: source texts, explanations, the wishes.
local memo = { stamp = -1 }
local function cached()
    local st = ns.BisStamp()
    if memo.stamp ~= st then memo = { stamp = st, src = {}, explain = {} } end
    return memo
end

local nameMissing = false   -- a shown row had no item name yet ("Item 12345")

local function itemText(id)
    local name, _, q = itemInfo(id)
    local row = Gear.Item(id)
    q = q or (row and (row[5] or 0) > 0 and row[5]) or 1
    if not name then nameMissing = true end
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or (row and row.name) or ("Item " .. id))
end

-- A worn item's name in the colour of its link.
local function linkText(link)
    local color = link:match("^|c(%x%x%x%x%x%x%x%x)")
    local name = link:match("|h%[(.-)%]|h")
    if name then return color and ("|c%s%s|r"):format(color, name) or name end
    local id = ns.ItemID(link)
    return id and itemText(id) or "?"
end

local function linkOf(id)
    local _, link = itemInfo(id)
    return link or ("item:" .. id)
end

local function firstSource(id, o)
    return Gear.Sources(id, o)[1] or Gear.Sources(id)[1]
end

-- pick: the BiS pick of the option (its source text stands in when the data knows none)
local function sourceText(id, o, pick)
    local c = cached()
    local t = c.src[id]
    if t == nil then
        local rec = firstSource(id, o)
        t = rec and Gear.SourceText(rec, true) or ""
        c.src[id] = t
    end
    if t == "" and type(pick) == "table" and type(pick.src) == "string" then return pick.src end
    return t
end

local function marks(e)
    return (e.owned and (CHECK .. " ") or "") .. (e.wished and (STAR .. " ") or "")
end

-- What the planner did with an option, as short grey notes: a BiS pick, the set it belongs to,
-- computed stats, an effect the scoring does not count, the best seen random suffix, moved ahead
-- for its effort.
local function noteParts(e)
    local out = {}
    if e.pick then out[#out + 1] = L["BiS-Empfehlung"] end
    if e.set then out[#out + 1] = L["Set %d/%d, %+d Bonus"]:format(e.set.have, e.set.total, math.floor(e.set.bonus + 0.5)) end
    if e.sc then out[#out + 1] = L["berechnet"] end
    if Gear.EffectText(e.id or e[1]) then out[#out + 1] = L["Effekt nicht gewertet"] end
    if e.suffix then out[#out + 1] = L["bester gesehener Bonus"] end
    if e.easier then out[#out + 1] = L["leichter zu bekommen"] end
    return out
end
local function noteText(e)
    local parts = noteParts(e)
    if #parts == 0 then return "" end
    return " " .. GREY .. "(" .. table.concat(parts, ", ") .. ")|r"
end

local function gainText(e)
    if e.worn or e.owned == "worn" then return CHECK end
    if e.switch then return L["Wechsel"] end
    if type(e.gain) ~= "number" then return "" end
    return (e.upgrade and GREEN or GREY) .. ("%+d"):format(math.floor(e.gain + 0.5)) .. "|r"
end

local function upgradesText(n) return n == 1 and "1 Upgrade" or (n .. " Upgrades") end

local function wishCount()
    local c = ns.BisChar()
    local n = 0
    for _ in pairs(c and c.wish or {}) do n = n + 1 end
    return n
end

-- Puts a link into the chat the way the client does (ChatFrameUtil.InsertLink).
local function insertLink(link)
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        return ChatFrameUtil.InsertLink(link)
    end
end

-- Shift or Ctrl on an item: the client's modified click (link into the chat, dressing room, as the
-- player's key bindings say); Ctrl the client does not take opens the dressing room itself.
local function modifiedClick(id)
    if not id then return false end
    local ctrl = IsControlKeyDown and IsControlKeyDown() or false
    if not ((IsShiftKeyDown and IsShiftKeyDown()) or ctrl) then return false end
    local link = linkOf(id)
    local handled = HandleModifiedItemClick and HandleModifiedItemClick(link)
    if not handled and ctrl and type(DressUpLink) == "function" then pcall(DressUpLink, link) end
    return true
end

local function itemTooltip(owner, id)
    if not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local _, link = itemInfo(id)
    if link then
        GameTooltip:SetHyperlink(link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(id)
    end
    GameTooltip:Show()
end
local function hideTip() GameTooltip:Hide() end

local function say(ok, why)
    if not ok and why then ns.msg(why) end
end

---------------------------------------------------------------------------
-- Map: the button before a source and the menu entries, only for items with a place
---------------------------------------------------------------------------

local MAP_ICON = "Interface\\Icons\\INV_Misc_Map_01"

-- Whether an item has a place on the map (with the page's filters), kept until the state changes.
local function hasPlace(id)
    if not id or not ns.HasData("MAP") or not ns.MapItemPlaces then return false end
    local c = cached()
    c.places = c.places or {}
    local v = c.places[id]
    if v == nil then
        v = #ns.MapItemPlaces(id) > 0
        c.places[id] = v
    end
    return v
end

-- The source key of a record, when it has a place (else the nearest of all sources is taken).
local function placeKey(rec)
    local key = rec and ns.MapKeyOf and ns.MapKeyOf(rec)
    if key and #ns.MapPoints(key) > 0 then return key end
    return nil
end

local function showOnMap(id, key)
    local point = ns.Map.ItemNearest(id, key)
    if not point and key then point = ns.Map.ItemNearest(id) end
    if point then ns.MapShowOnWorldMap(point) end
end

local function setTarget(id, key)
    local ok, why = ns.MapSetTarget(id, key)
    if not ok and key then ok, why = ns.MapSetTarget(id) end
    say(ok, why)
end

-- Click: the target to the source (the nearest place); Shift: the place on the world map.
local function mapClick(self)
    if not self.id then return end
    if IsShiftKeyDown and IsShiftKeyDown() then showOnMap(self.id, self.key) else setTarget(self.id, self.key) end
end

local function mapTip(self)
    if not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Wegpunkt zur Quelle"], 1, 0.82, 0)
    local where = ns.Map.Where(self.id, self.key)
    if where then GameTooltip:AddLine(L["Fundort: %s"]:format(where), 0.85, 0.85, 0.85) end
    GameTooltip:AddLine(L["Klick: Ziel setzen. Shift-Klick: auf der Weltkarte zeigen."], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- A 16 px map button at x in its row.
local function mapButton(parent, x)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b:SetPoint("LEFT", x, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(MAP_ICON)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.25)
    b:SetScript("OnClick", mapClick)
    b:SetScript("OnEnter", mapTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    return b
end

-- Shows the button for an item with a place (rows are pooled: every field is set again).
local function setMapButton(b, id, rec, hide)
    if id and not hide and hasPlace(id) then
        b.id, b.key = id, placeKey(rec)
        b:Show()
    else
        b.id, b.key = nil, nil
        b:Hide()
    end
end

-- "Wegpunkt setzen" and "Auf der Karte zeigen", for an item with a place.
local function mapEntries(out, id, key)
    if not hasPlace(id) then return end
    out[#out + 1] = { L["Wegpunkt setzen"], function() setTarget(id, key) end }
    out[#out + 1] = { L["Auf der Karte zeigen"], function() showOnMap(id, key) end }
end

local function inInstance()
    return IsInInstance and ns.Plain(IsInInstance()) and true or false
end

local function lift(d)
    -- the dialog strata is below the main window's; lift it so it is not hidden behind
    if d and d.SetFrameStrata then
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        if d.Raise then d:Raise() end
    end
end

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or T.FONT.head, w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

local function head(parent, y)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(14)
    h:SetPoint("TOPLEFT", 0, y)
    h:SetPoint("TOPRIGHT", 0, y)
    return h
end

-- Every place key the data knows (raids, dungeons, zones), per data set.
local knownFor, known
local function placeKnown(place)
    local d = ns.Data("GEAR")
    if not place or not d then return false end
    if knownFor ~= d then
        known, knownFor = {}, d
        for _, rec in ipairs(d.S) do
            local p = Gear.PlaceOf(rec)
            if p then known[p] = true end
        end
    end
    for k in pairs(place.keys or {}) do
        if known[k] then return true end
    end
    return false
end

local function guildVisible() return ns.IsOfficerView() or ns.GuildWishesInfo() ~= nil end

local function shownView()
    local v = state().view
    if not VIEWS[v] or (v == "guild" and not guildVisible()) then return "goals" end
    return v
end

local function setView(v)
    state().view = v
    guildResult = nil
    if v ~= "wish" then exportOpen = false end
    ns.Refresh()
end

local function longDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    return y and ns.FmtDate(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })) or "?"
end

---------------------------------------------------------------------------
-- Head: spec, views, counts, source chips
---------------------------------------------------------------------------

local function counts(o, res)
    local parts = { L["Level %d"]:format(o.level), upgradesText(res.upgrades or 0) }
    local c = ns.BisChar()
    parts[#parts + 1] = (c and c.bankAt) and L["Bank %s"]:format(ns.FmtDay(c.bankAt)) or L["Bank noch nicht geöffnet"]
    local ex = ns.BisExcludeCount()
    if ex > 0 then parts[#parts + 1] = L["%d ausgeschlossen"]:format(ex) end
    local loading = Gear.Loading()
    if loading > 0 then parts[#parts + 1] = "|cffe0a344" .. L["lädt noch %d Items"]:format(loading) .. "|r" end
    return table.concat(parts, " · ")
end

local chipsFor, chipsCache
local function chipSet()
    local set = CHIPS
    -- the raids chip shows once the data has raids; looked up once per data set
    local d = ns.Data("GEAR")
    if chipsFor == d then return chipsCache end
    local raids = false
    for _, rec in ipairs(d and d.S or {}) do
        if rec[1] == "X" then raids = true break end
    end
    local out = set
    if not raids then
        out = {}
        for i = 2, #set do out[#out + 1] = set[i] end
    end
    chipsFor, chipsCache = d, out
    return out
end

local function profClick()
    local src = ns.BisOpts().sources
    if not src.C then
        src.C = true
        ns.Set("bis.prof", "all")   -- l10n-ok: setting key
    elseif ns.Get("bis.prof") ~= "mine" and ns.BisSkills() then   -- l10n-ok: setting key
        ns.Set("bis.prof", "mine")   -- l10n-ok: setting key
    else
        src.C = false
        ns.Set("bis.prof", "all")   -- l10n-ok: setting key
    end
    ns.Fire("BIS_CHANGED")
end

local function fillHead(f, o, res, v)
    -- the spec: chosen, or guessed from the talents
    local values = {}
    for _, sp in ipairs(Gear.Specs(o.class)) do values[#values + 1] = { value = sp.key, text = L[sp.name] } end
    values[#values + 1] = { value = "", text = L["aus den Talenten"] }
    f.spec:SetValues(values)
    f.spec:SetValue(o.spec)
    if o.guessed then f.spec.label:SetText(f.spec.label:GetText() .. " " .. GREY .. L["(geraten)"] .. "|r") end
    for k, chip in pairs(f.views) do chip:SetOn(k == v) end
    if guildVisible() then f.views.guild:Show() else f.views.guild:Hide() end
    f.views.wish.label:SetText(L["Wunschliste (%d)"]:format(wishCount()))
    if Gear.Available() then f.open:Show() else f.open:Hide() end
    f.counts:SetText(counts(o, res))
    if ns.BisExcludeCount() > 0 then f.reset:Show() else f.reset:Hide() end
    -- the source chips, in a row; the dungeon planner does not use them, its body takes their room
    local shown, row = {}, {}
    for _, def in ipairs(v == "dungeons" and {} or chipSet()) do
        local chip = f.src[def[1]]
        shown[def[1]] = true
        row[#row + 1] = chip
        local on = o.sources[def[1]] and true or false
        chip:SetOn(on)
        if def[1] == "C" then
            chip.label:SetText(not on and L["Berufe"] or (o.prof == "mine" and L["Berufe: meine"] or L["Berufe: alle"]))
        end
        chip:Show()
    end
    W.Row(f, row, T.CHIP_GAP, 0, -48)
    for k, chip in pairs(f.src) do if not shown[k] then chip:Hide() end end
    if v == "goals" then
        local plans = {}
        for _, k in ipairs(ns.BIS_PLAN_ORDER) do plans[#plans + 1] = { value = k, text = L["Waffen: %s"]:format(ns.BIS_PLANS[k]) } end
        f.plan:SetValues(plans)
        f.plan:SetValue(o.plan or "auto")
        f.plan:Show()
    else
        f.plan:Hide()
    end
end

---------------------------------------------------------------------------
-- Ziele: the slots, the details of one, the explanation
---------------------------------------------------------------------------

local function selectedSlot()
    local slot = state().slot
    if ns.BIS_SLOT_NAME[slot] then return slot end
    return "HEAD"
end

local function selectSlot(key)
    state().slot = key
    scrolledTo = key
    ns.Refresh()
end

local function menuEntries(e, o)
    local id = e.id
    local out = { { L["Item ausschließen"], function() say(ns.BisExclude("item", id)) end } }
    local rec = firstSource(id, o)
    if rec and (rec[1] == "X" or rec[1] == "D") and rec[3] and rec[3] ~= "Trash" then
        out[#out + 1] = { L["Boss ausschließen"], function() say(ns.BisExclude("boss", rec[3])) end }
    end
    local place = rec and Gear.PlaceOf(rec)
    if place then out[#out + 1] = { L["Ort ausschließen"], function() say(ns.BisExclude("place", place)) end } end
    if e.wished then
        out[#out + 1] = { L["Von der Wunschliste nehmen"], function() ns.WishRemove(id) end }
    else
        out[#out + 1] = { L["Auf die Wunschliste"], function() say(ns.WishAdd(id)) end }
    end
    -- a row of its own place (Hier) keeps the menu on that place
    mapEntries(out, id, placeKey(e.rec))
    out[#out + 1] = { L["Link in den Chat"], function() insertLink(linkOf(id)) end }
    return out
end

local function toggleWish(id, wished)
    if wished then ns.WishRemove(id) else say(ns.WishAdd(id)) end
end

local function fillGoalRow(r, e)
    r.slot:SetText(e.name)
    local up = e.opt and e.opt.upgrade
    if up then r.slot:SetTextColor(1, 0.82, 0) else r.slot:SetTextColor(0.56, 0.53, 0.64) end
    r.worn:SetText(e.wornLink and linkText(e.wornLink) or (GREY .. L["nichts"] .. "|r"))
    if e.opt then
        r.best:SetText(marks(e.opt) .. itemText(e.opt.id))
        r.src:SetText(sourceText(e.opt.id, e.o, e.opt.pick))
        r.gain:SetText(gainText(e.opt))
    else
        r.best:SetText(GREY .. ((e.key == "OFFHAND" and e.plan == "2H") and L["Zweihandwaffe geplant"] or L["keine Option"]) .. "|r")
        r.src:SetText("")
        r.gain:SetText("")
    end
    if e.key == selectedSlot() then r.sel:Show() else r.sel:Hide() end
end

local function buildGoals(f)
    local G = CreateFrame("Frame", nil, f)
    G:SetPoint("TOPLEFT", 0, -72)
    G:SetPoint("BOTTOMRIGHT", 0, 0)
    local h = head(G, 0)
    -- the list is 590 wide (12 px for its scroll bar): the source gives them, the gain moves left
    G.head = { slot = col(h, 4, 66, "Slot"), worn = col(h, 74, 156, L["Angelegt"]), best = col(h, 234, 186, L["Bestes"]),
        src = col(h, 424, 114, L["Quelle"]), gain = col(h, 542, 44, L["Zuwachs"]) }
    G.head.gain:SetJustifyH("RIGHT")
    G.list = W.List(G, GOAL_ROWS, ROW_H, function(r)
        r.sel = W.SelectBar(r)
        r.slot = col(r, 4, 66)
        r.worn = col(r, 74, 156, nil, T.FONT.text)
        r.best = col(r, 234, 186, nil, T.FONT.text)
        r.src = col(r, 424, 114, nil, T.FONT.text)
        r.gain = col(r, 542, 44, nil, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if not e then return end
            if e.opt and modifiedClick(e.opt.id) then return end
            selectSlot(e.key)
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.opt then itemTooltip(self, e.opt.id) end
        end)
        r:SetScript("OnLeave", hideTip)
    end, fillGoalRow)
    -- 11 of 17 slots: 12 px short of the right edge, room for the list's scroll bar
    G.list:SetPoint("TOPLEFT", 0, -16)
    G.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -16)

    G.title = W.Text(G, T.FONT.title, 440)
    G.title:SetPoint("TOPLEFT", 4, -284)
    -- why the weights are as they are (tooltip), and the simulation of another class or level
    -- 20 high, between the list (it ends at -280) and the first option (-300)
    G.why = W.Button(G, L["Warum?"], 64, nil, { height = T.ROW_BUTTON_H })
    G.why:SetPoint("TOPRIGHT", -92, -280)
    G.why:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Warum diese Gewichte"])
        for _, line in ipairs(ns.BisWhy()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    G.why:SetScript("OnLeave", hideTip)
    G.sim = W.Button(G, L["Simulation"], 88, function() setView("sim") end, { height = T.ROW_BUTTON_H })
    G.sim:SetPoint("TOPRIGHT", 0, -280)
    W.Tooltip(G.sim, L["Simulation"], L["Beste Items für eine andere Klasse, Spezialisierung oder Stufe, ohne deinen Besitz."])
    G.opts = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, G)
        b:SetHeight(25)
        b:SetPoint("TOPLEFT", 0, -300 - (i - 1) * 26)
        b:SetPoint("TOPRIGHT", 0, -300 - (i - 1) * 26)
        W.Flat(b, 1, 1, 1, 0.04)
        -- lights up as the recipe list's rows do
        b.hover = b:CreateTexture(nil, "HIGHLIGHT")
        b.hover:SetAllPoints()
        if W.HasAtlas("Professions_Recipe_Hover") then
            b.hover:SetAtlas("Professions_Recipe_Hover")
            b.hover:SetAlpha(0.5)
        else
            b.hover:SetColorTexture(1, 1, 1, 0.08)
        end
        b.rank = col(b, 4, 12, nil, T.FONT.head)
        b.name = col(b, 20, 212, nil, T.FONT.text)
        -- the map button sits in the 18 px before the source
        b.map = mapButton(b, 236)
        b.src = col(b, 254, 174, nil, T.FONT.text)
        b.gain = col(b, 432, 46, nil, T.FONT.text)
        b.gain:SetJustifyH("RIGHT")
        b.wish = W.Button(b, L["Wunsch##Knopf"], 78, function(self)
            local e = self:GetParent().opt
            if e then toggleWish(e.id, e.wished) end
        end)
        b.ex = W.Button(b, L["Aus##ausschließen"], 36, function(self)
            local e = self:GetParent().opt
            if e then say(ns.BisExclude("item", e.id)) end
        end)
        W.FitChip(b.ex, 36)
        W.Row(b, { b.wish, b.ex }, T.CHIP_GAP, 0, 0, { right = true, point = "RIGHT" })
        W.Tooltip(b.ex, L["Ausschließen"], L["Das Item nicht mehr vorschlagen; die nächste Option rückt auf. Rechtsklick auf die Zeile: Boss oder Ort ausschließen."])
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            local e = self.opt
            if not e then return end
            if button == "RightButton" then
                W.Menu(self, menuEntries(e, ns.BisOpts()))
                return
            end
            modifiedClick(e.id)
        end)
        b:SetScript("OnEnter", function(self) if self.opt then itemTooltip(self, self.opt.id) end end)
        b:SetScript("OnLeave", hideTip)
        G.opts[i] = b
    end
    G.explain = W.Text(G, T.FONT.text, 598, true)
    G.explain:SetPoint("TOPLEFT", 4, -380)
    G.explain:SetHeight(26)
    G.explain:SetJustifyV("TOP")
    G.explain:SetMaxLines(2)
    -- the explanation in full on hover: option 1 against 2 and against what is worn
    G.explainHit = CreateFrame("Frame", nil, G)
    G.explainHit:SetPoint("TOPLEFT", G.explain, "TOPLEFT")
    G.explainHit:SetPoint("BOTTOMRIGHT", G.explain, "BOTTOMRIGHT")
    G.explainHit:EnableMouse(true)
    G.explainHit:SetScript("OnEnter", function(self)
        if not self.lines or #self.lines == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.title or L["Vergleich"])
        for _, line in ipairs(self.lines) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    G.explainHit:SetScript("OnLeave", hideTip)
    return G
end

-- The comparison lines of a slot: option 1 against option 2 and against the worn item.
local function compareLines(o, list, wornLink)
    local c = cached()
    local first = list[1]
    if not first then return {} end
    local key = "cmp|" .. first.id .. "|" .. (list[2] and list[2].id or 0) .. "|" .. tostring(wornLink)
    if c.explain[key] then return c.explain[key] end
    local lines = {}
    for _, n in ipairs(noteParts(first)) do lines[#lines + 1] = GREY .. n .. "|r" end
    local second = list[2]
    if second then
        -- the options themselves: their random suffix and set bonus share count as in the ranking
        local cmp = ns.BisCompare(first, second, o, { L["Option 1"], L["Option 2"] })
        if cmp then
            lines[#lines + 1] = cmp.text
            for i = 1, math.min(4, #cmp.lines) do lines[#lines + 1] = "  " .. cmp.lines[i] end
        end
    end
    if wornLink and not first.worn then
        local cmp = ns.BisCompare(first, wornLink, o, { L["Option 1"], L["das Angelegte"] })
        if cmp then
            lines[#lines + 1] = cmp.text
            for i = 1, math.min(4, #cmp.lines) do lines[#lines + 1] = "  " .. cmp.lines[i] end
        end
    end
    c.explain[key] = lines
    return lines
end

-- The explanation of an option as one text, kept until the state changes.
local function explainText(o, res, slotKey, e)
    local c = cached()
    local key = slotKey .. "|" .. (e and e.id or 0)
    if c.explain[key] then return c.explain[key] end
    local out = {}
    if (slotKey == "MAINHAND" or slotKey == "OFFHAND") and res.twoHandScore and res.oneHandScore then
        local more = {}
        if res.dwScore then more[#more + 1] = L["zwei Waffen %s"]:format(Gear.Num(res.dwScore)) end
        if res.shieldScore then more[#more + 1] = L["mit Schild %s"]:format(Gear.Num(res.shieldScore)) end
        out[#out + 1] = L["Zweihand %s gegen Waffenhand plus Schildhand %s%s."]:format(Gear.Num(res.twoHandScore),
            Gear.Num(res.oneHandScore), #more > 0 and (" (" .. table.concat(more, ", ") .. ")") or "")
    end
    if not e then
        out[#out + 1] = (slotKey == "OFFHAND" and res.plan == "2H") and L["Die Zweihandwaffe belegt beide Hände."]
            or L["Für diesen Slot gibt es keine Option in den Daten."]
    else
        local lines = ns.BisExplain(e.id, o)
        if #lines <= 1 then
            out[#out + 1] = lines[1] or ""
        else
            local lead
            if e.worn then
                lead = L["angelegt"]
            elseif e.switch then
                lead = L["Waffenwechsel"]
            else
                lead = Gear.UnitText(e.gain or 0, Gear.Weights(o.class, o.spec, o.kind, o.level))
            end
            local parts = {}
            for i = 2, #lines do
                -- the pick's note is a sentence of its own (BisExplain's last line)
                if not (e.pick and lines[i] == ns.BisPickText(e.pick)) then parts[#parts + 1] = lines[i] end
            end
            out[#out + 1] = lead .. ": " .. table.concat(parts, ", ") .. "."
        end
        if e.pick then out[#out + 1] = ns.BisPickText(e.pick) end
    end
    local text = table.concat(out, " ")
    c.explain[key] = text
    return text
end

local function goalItems(res, o)
    local c = cached()
    if c.goalsRes == res then return c.goals end
    local items = {}
    for _, sl in ipairs(Gear.SLOTS) do
        local link = GetInventoryItemLink and ns.Plain(GetInventoryItemLink("player", sl.inv))
        items[#items + 1] = { key = sl.key, name = sl.name, wornLink = type(link) == "string" and link or nil,
            opt = res[sl.key] and res[sl.key][1], plan = res.plan, o = o }
    end
    c.goalsRes, c.goals = res, items
    return items
end

local function fillGoals(G, o, res)
    local items = goalItems(res, o)
    local slot = selectedSlot()
    -- a slot chosen from outside (the toast) is scrolled into view once
    if scrolledTo ~= slot then
        scrolledTo = slot
        for i, e in ipairs(items) do
            if e.key == slot and (i <= G.list.offset or i > G.list.offset + GOAL_ROWS) then
                G.list.offset = math.max(0, math.min(i - 1, #items - GOAL_ROWS))
            end
        end
    end
    G.list:SetItems(items)
    local sp = Gear.SpecInfo(o.class, o.spec)
    G.title:SetText(L["%s · Bestes für %s%s"]:format(ns.BIS_SLOT_NAME[slot] or slot, sp and L[sp.name] or "?", o.guessed and L[" (geraten)"] or ""))
    local list = res[slot] or {}
    for i, b in ipairs(G.opts) do
        local e = list[i]
        b.opt = e
        if e then
            b.rank:SetText(tostring(i))
            b.name:SetText(marks(e) .. itemText(e.id) .. noteText(e))
            b.src:SetText(e.owned and OWNED_TEXT[e.owned] or sourceText(e.id, o, e.pick))
            setMapButton(b.map, e.id, nil, e.owned)
            b.gain:SetText(gainText(e))
            if e.worn then
                b.wish:Hide()
                b.ex:Hide()
            else
                b.wish:SetText(e.wished and L["Wunsch weg"] or L["Wunsch##Knopf"])
                b.wish:Show()
                b.ex:Show()
            end
            b:Show()
        else
            setMapButton(b.map, nil)
            b:Hide()
        end
    end
    G.explain:SetText(explainText(o, res, slot, list[1]))
    local wornLink
    for _, e in ipairs(goalItems(res, o)) do if e.key == slot then wornLink = e.wornLink end end
    G.explainHit.title = ns.BIS_SLOT_NAME[slot] or slot
    G.explainHit.lines = compareLines(o, list, wornLink)
end

---------------------------------------------------------------------------
-- Hier: a place and what it still offers
---------------------------------------------------------------------------

local function bossText(rec)
    if not rec then return "" end
    if (rec[1] == "X" or rec[1] == "D") and rec[3] then return rec[3] end
    return Gear.SourceText(rec, true)
end

local function fillHereRow(r, e)
    r.boss:SetText(bossText(e.rec))
    -- an entrance means nothing inside the instance
    setMapButton(r.map, e.id, e.rec, inInstance())
    r.name:SetText(marks(e) .. itemText(e.id))
    r.slot:SetText(ns.BIS_SLOT_NAME[e.slotKey] or "")
    r.gain:SetText(gainText(e))
    if e.owned then
        r.wishBtn:Hide()
    else
        r.wishBtn:SetText(e.wished and L["Wunsch weg"] or L["Wunsch##Knopf"])
        r.wishBtn:Show()
    end
end

local function buildHere(f)
    local Hh = CreateFrame("Frame", nil, f)
    Hh:SetPoint("TOPLEFT", 0, -72)
    Hh:SetPoint("BOTTOMRIGHT", 0, 0)
    Hh.pick = W.Picker(Hh, 240, function(v)
        placeGone = false
        state().place = (v ~= "here") and v or nil
        ns.Refresh()
    end)
    Hh.pick:SetPoint("TOPLEFT", 0, -2)
    local h = head(Hh, -26)
    -- the list is 590 wide (12 px for its scroll bar): the gain gives 6, the button moves left
    Hh.head = { boss = col(h, 4, 146, "Boss"), name = col(h, 154, 216, "Item"), slot = col(h, 374, 76, "Slot"),
        gain = col(h, 454, 50, L["Zuwachs"]) }
    Hh.head.gain:SetJustifyH("RIGHT")
    Hh.list = W.List(Hh, HERE_ROWS, ROW_H, function(r)
        r.map = mapButton(r, 4)
        r.boss = col(r, 22, 128, nil, T.FONT.text)
        r.name = col(r, 154, 216, nil, T.FONT.text)
        r.slot = col(r, 374, 76, nil, T.FONT.text)
        r.gain = col(r, 454, 50, nil, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r.wishBtn = W.Button(r, L["Wunsch##Knopf"], 82, function(self)
            local e = self:GetParent().item
            if e then toggleWish(e.id, e.wished) end
        end, { height = T.ROW_BUTTON_H })
        r.wishBtn:SetPoint("LEFT", 508, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if button == "RightButton" then
                W.Menu(self, menuEntries(e, ns.BisOpts()))
                return
            end
            modifiedClick(e.id)
        end)
        r:SetScript("OnEnter", function(self) if self.item then itemTooltip(self, self.item.id) end end)
        r:SetScript("OnLeave", hideTip)
    end, fillHereRow)
    Hh.list:SetPoint("TOPLEFT", 0, -42)
    Hh.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -42)
    Hh.hint = W.Text(Hh, T.FONT.hint, 598)
    Hh.hint:SetPoint("TOPLEFT", 4, -384)
    return Hh
end

local function fillHere(Hh, o)
    local chosen = state().place
    local cur = ns.BisCurrentPlace()
    local values = { { value = "here", text = L["Hier: %s"]:format((cur and cur.text) or L["unbekannt"]) } }
    local found = false
    for _, p in ipairs(ns.BisPlaces()) do
        values[#values + 1] = { value = p.key, text = p.text }
        if p.key == chosen then found = true end
    end
    -- a saved place the data no longer has (another data set, a rebuilt one): the own place again,
    -- said until another place is picked
    if chosen ~= nil and not found then
        chosen = nil
        state().place = nil
        placeGone = true
    end
    local gone = placeGone
    Hh.pick:SetValues(values)
    Hh.pick:SetValue(chosen or "here")
    local place, list = ns.BisHere(chosen, o)
    Hh.list:SetItems(list)
    local hint
    if not place or not placeKnown(place) then
        hint = L["Diesen Ort kennen die Daten nicht."]
    elseif #list == 0 then
        hint = L["Hier gibt es nichts mehr für dich."]
    else
        hint = L["Was du an diesem Ort noch holen kannst: Upgrades und Wünsche, Besitz unten."]
    end
    if place and (place.loading or 0) > 0 then hint = hint .. " · " .. L["lädt noch %d Items"]:format(place.loading) end
    if gone then hint = L["Der gewählte Ort fehlt in den Daten, gezeigt wird der aktuelle."] .. " " .. hint end
    Hh.hint:SetText(hint)
end

---------------------------------------------------------------------------
-- Dungeons: the next dungeon, the list, the chosen one's bosses and quests
---------------------------------------------------------------------------

local GOLD_TEXT = "|cffe3b857"
-- the texts of the journal parts (image, XP, marks, dressing room), in one place for the translation
local DTEXT = {
    level = "Level %s · %s",
    mark = L["Alle auf Karte"],
    unmark = L["Karte leeren"],
    markTitle = L["Alle Questgeber auf der Karte"],
    markTip = L["Markiert die Questgeber aller offenen Quests dieses Dungeons auf der Weltkarte (bei einer Questreihe den Geber der ersten offenen Vorquest). Noch einmal klicken: Markierung entfernen."],
    marked = L["%d Questgeber auf der Weltkarte markiert."],
    unmarked = L["Markierung der Questgeber entfernt."],
    itemHint = L["Strg-Klick: Anprobe. Shift-Klick: in den Chat."],
    xpLine = L["EP: %s"],
    xpLog = L["laut Questlog"],
    xpSeen = L["gesehen bei Level %d"],
    xpScaled = L["geschätzt, gesehen bei Level %d"],
    xpOther = L["gesehen bei Level %d, Questlevel unbekannt"],
    xpNone = L["EP: noch nicht gesehen"],
}
local ART_W, ART_H = 590, 48

local function signed(x) return ("%+d"):format(math.floor(x + 0.5)) end

-- The dungeon list in the chosen order: "level" as the planner gives it, "value" the ranking first
-- (then the rest by level), "chain" the chain's dungeons in its order (then the rest). Rows of the
-- ranking and the chain carry their place (e.rank) and, for the chain, the chain's value.
local function orderedDungeons(list, sort)
    if sort ~= "value" and sort ~= "chain" then return list, nil end
    local c = cached()
    c.dorder = c.dorder or {}
    local key = sort .. tostring(list)
    if c.dorder[key] then return c.dorder[key][1], c.dorder[key][2] end
    local top, chain, why = {}, nil, nil
    if sort == "value" then
        for i, e in ipairs(ns.DungeonRanking()) do top[#top + 1] = { e = e, rank = i, value = e.value } end
    else
        chain, why = ns.DungeonChain()
        for i, st in ipairs(chain) do top[#top + 1] = { e = st.entry, rank = i, value = st.value } end
    end
    local out, seen = {}, {}
    for _, t in ipairs(top) do
        out[#out + 1] = setmetatable({ rank = t.rank, chainValue = sort == "chain" and t.value or nil }, { __index = t.e })
        seen[t.e] = true
    end
    for _, e in ipairs(list) do
        if not seen[e] then out[#out + 1] = e end
    end
    c.dorder[key] = { out, { chain = chain, why = why } }
    return out, c.dorder[key][2]
end

-- The chosen dungeon: the saved one while the list has it, else the recommended, else the first.
local function chosenDungeon(list, nextE)
    local key = state().dungeon
    for _, e in ipairs(list) do
        if e.key == key then return e end
    end
    return nextE or list[1]
end

local function fillDungeonRow(r, e)
    local raid = e.kind == "raid" and (" (Raid%s)"):format(e.size and (" " .. e.size) or "") or ""
    local dim = e.fit == "high" or e.fit == "easy" or e.fit == "later"
    r.name:SetText((e.rank and (e.rank .. ". ") or "") .. e.name .. raid)
    if dim then r.name:SetTextColor(0.56, 0.53, 0.64) else r.name:SetTextColor(1, 1, 1) end
    r.level:SetText(ns.Dungeons.RangeText(e))
    r.fit:SetText(ns.Dungeons.FitText(e))
    if e.fit == "fit" then r.fit:SetTextColor(0.31, 0.82, 0.42)
    elseif e.fit == "soon" then r.fit:SetTextColor(1, 0.82, 0)
    else r.fit:SetTextColor(0.56, 0.53, 0.64) end
    if e.computed then
        r.upgrades:SetText(tostring(e.upgrades))
        r.run:SetText(e.perRun > 0 and signed(e.perRun) or "0")
        r.quests:SetText(e.once > 0 and signed(e.once) or "0")
        r.value:SetText(tostring(math.floor((e.chainValue or e.value) + 0.5)))
    else
        r.upgrades:SetText(""); r.run:SetText(""); r.quests:SetText(""); r.value:SetText("")
    end
    if r.owner and r.owner.chosen == e.key then r.sel:Show() else r.sel:Hide() end
end

local function dungeonTip(self)
    local e = self.item
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.name, 1, 0.82, 0)
    local range = ns.Dungeons.RangeText(e)
    if range ~= "" then
        GameTooltip:AddLine(("Level %s%s"):format(range, e.est and L[", geschätzt aus den Items"] or ""), 0.85, 0.85, 0.85)
    end
    if e.kind == "raid" then
        GameTooltip:AddLine(("Raid%s%s"):format(e.size and L[" für %s"]:format(e.size) or "", e.fit == "later" and (", " .. ns.Dungeons.FitText(e)) or ""),
            0.85, 0.85, 0.85)
    end
    if e.computed then
        GameTooltip:AddLine(L["%d Upgrades, je Lauf %s, Quests %s, Wert %d"]:format(e.upgrades, signed(e.perRun), signed(e.once),
            math.floor(e.value + 0.5)), 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- The rows of the chosen dungeon: a row per boss with its items below it.
local function detailItems(e)
    local c = cached()
    c.detail = c.detail or {}
    local out = c.detail[e]
    if out then return out end
    out = {}
    for _, b in ipairs(e.bosses or {}) do
        out[#out + 1] = { kind = "boss", text = b.name, b = b }
        for _, it in ipairs(b.items) do
            out[#out + 1] = { kind = "item", id = it.id, it = it, rec = it.rec, wished = it.wished, owned = it.owned }
        end
    end
    c.detail[e] = out
    return out
end

-- The quest rows of a dungeon: per quest a row, its pre-quests and its gear rewards below it.
-- list, status as ns.DungeonQuests gives them.
local function questItems(key)
    local c = cached()
    c.qdetail = c.qdetail or {}
    local list, status = ns.DungeonQuests(key)
    local kept = c.qdetail[key]
    if kept and kept.list == list then return kept.out, status end
    local out = {}
    for _, q in ipairs(list) do
        out[#out + 1] = { kind = "quest", text = q.title .. (q.done and L[" (erledigt)"] or q.gone and L[" (nicht mehr möglich)"] or ""),
            q = q, qid = q.qid }
        for _, n in ipairs(q.chain) do
            out[#out + 1] = { kind = "pre", q = n, qid = n.qid }
        end
        for _, r in ipairs(q.rewards) do
            out[#out + 1] = { kind = "reward", id = r.id, it = r, owned = r.owned }
        end
    end
    c.qdetail[key] = { list = list, out = out }
    return out, status
end

local STATE_TEXT = { done = L["erledigt"], active = L["im Log"], gone = L["nicht mehr möglich"] }
local function questState(n) return n.done and "done" or n.active and "active" or n.gone and "gone" or nil end

-- The level text of a quest in the quest log's colours (simplified): red when it cannot be taken yet
-- or is five levels above, orange three above, yellow around the own level, green below, grey far below.
local function questLevelText(q)
    local text = ns.Dungeons.QuestLevelText(q)
    if text == "" then return "" end
    local my = tonumber(UnitLevel("player")) or 1
    local lv = (q.level or 0) > 0 and q.level or (q.minLevel or 0)
    local c
    if (q.minLevel or 0) > my or lv - my >= 5 then c = "|cffff2020"
    elseif lv - my >= 3 then c = "|cffff8040"
    elseif lv - my >= -2 then c = "|cffffff00"
    elseif lv - my >= -5 then c = "|cff40c040"
    else c = GREY end
    return c .. text .. "|r"
end

local function fillDetailRow(r, e)
    r.xp:SetText("")
    if e.kind == "boss" then
        r.name:SetText(GOLD_TEXT .. e.text .. "|r")
        r.slot:SetText("")
        r.gain:SetText("")
        if e.b.tentative then
            -- an NPC only the guild's records know: listed, counted from its third kill
            local k = e.b.kills or 0
            r.rate:SetText(GREY .. L["%d %s, zählt ab 3"]:format(k, k == 1 and "Kill" or "Kills") .. "|r")
        else
            r.rate:SetText(e.b.perRun > 0 and L["je Lauf %s"]:format(signed(e.b.perRun)) or "")
        end
    elseif e.kind == "item" then
        local it = e.it
        r.name:SetText(marks(it) .. itemText(it.id))
        r.slot:SetText(ns.BIS_SLOT_NAME[it.slotKey] or "")
        r.gain:SetText(gainText(it))
        r.rate:SetText(it.rate or "")
    elseif e.kind == "reward" then
        local it = e.it
        r.name:SetText("      " .. marks(it) .. itemText(it.id))
        r.slot:SetText(ns.BIS_SLOT_NAME[it.slotKey] or "")
        r.gain:SetText(gainText(it))
        r.rate:SetText(it.upgrade and (GREEN .. "Upgrade|r") or "")
    else
        -- a quest or one of its pre-quests: state, title, level, where it starts
        local q, pre = e.q, e.kind == "pre"
        local st = questState(q)
        local title = pre and ("   " .. L["Vorquest: %s"]:format(q.title) .. (q.one and L[" (oder eine andere)"] or "")) or (GOLD_TEXT .. e.text .. "|r")
        local over = q.done or q.gone
        r.name:SetText((over and (GREY .. title .. "|r")) or title)
        r.slot:SetText(questLevelText(q))
        r.gain:SetText(not pre and q.best and ((over and GREY or GREEN) .. signed(q.best.gain) .. "|r") or "")
        local where = ns.Dungeons.QuestStartText(q)
        r.rate:SetText((st and (GREY .. STATE_TEXT[st] .. "|r" .. (where ~= "" and " · " or "")) or "") .. where)
        local xp = ns.Dungeons.XPText(ns.Dungeons.QuestXP(q))
        r.xp:SetText(over and xp ~= "" and (GREY .. xp .. "|r") or xp)
    end
end

-- The tooltip of a quest row: title, level, state, where it starts, the chain, a hint on the click.
local function questTip(self)
    local e = self.item
    if not e or not e.q then return end
    local q = e.q
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.title, 1, 0.82, 0)
    local lv = ns.Dungeons.QuestLevelText(q)
    if lv ~= "" then GameTooltip:AddLine(L["Level %s"]:format(lv), 0.85, 0.85, 0.85) end
    local st = questState(q)
    GameTooltip:AddLine(st and STATE_TEXT[st] or L["offen"], 0.85, 0.85, 0.85)
    local where = ns.Dungeons.QuestStartText(q)
    if where ~= "" then GameTooltip:AddLine(L["Start: %s"]:format(where), 0.85, 0.85, 0.85, true) end
    local value, how, seen = ns.Dungeons.QuestXP(q)
    if value then
        local from = how == "log" and DTEXT.xpLog or how == "scaled" and DTEXT.xpScaled:format(seen)
            or how == "other" and DTEXT.xpOther:format(seen) or DTEXT.xpSeen:format(seen or 0)
        GameTooltip:AddDoubleLine(DTEXT.xpLine:format(ns.Dungeons.XPText(value, how, seen)), from, 0.85, 0.85, 0.85, 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine(DTEXT.xpNone, 0.6, 0.6, 0.6)
    end
    for _, n in ipairs(q.chain or {}) do
        GameTooltip:AddLine(L["Vorquest: %s"]:format(n.title) .. (n.done and L[" (erledigt)"] or ""), 0.6, 0.6, 0.6, true)
    end
    if q.start ~= "X" then GameTooltip:AddLine(L["Klick: Wegpunkt zum Start"], 0.31, 0.82, 0.42) end
    GameTooltip:Show()
end

-- The boss model of the image: the NPC's creature where the client has a model frame for it.
local function setModelNpc(a, npc)
    local m = a.model
    if not npc or not m or type(m.SetCreature) ~= "function" then
        a.npc = nil
        if m then m:Hide() end
        return
    end
    m:Show()
    if a.npc ~= npc then
        if not pcall(m.SetCreature, m, npc) then
            a.npc = nil
            m:Hide()
            return
        end
        if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0.7) end
        a.npc = npc
    end
end

-- The header image of the chosen dungeon: the middle of the client's loading screen, darkened to the
-- left, the name and level on it, the boss model and the mark button to the right.
local function buildArt(B)
    local a = CreateFrame("Frame", nil, B)
    a:SetPoint("TOPLEFT", 0, -199)
    a:SetPoint("TOPRIGHT", -12, -199)
    a:SetHeight(ART_H)
    a.tex = a:CreateTexture(nil, "BACKGROUND")
    a.tex:SetAllPoints()
    a.shade = a:CreateTexture(nil, "BORDER")
    a.shade:SetAllPoints()
    a.shade:SetColorTexture(0, 0, 0, 1)
    if a.shade.SetGradient and CreateColor then
        a.shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.1))
    else
        a.shade:SetAlpha(0.45)
    end
    a.edges = W.Border(a, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.7)
    a.title = W.Text(a, T.FONT.big, 330)
    a.title:SetPoint("TOPLEFT", 10, -7)
    a.info = W.Text(a, T.FONT.text, 330)
    a.info:SetPoint("BOTTOMLEFT", 10, 7)
    a.model = CreateFrame("PlayerModel", nil, a)
    a.model:SetSize(ART_H - 4, ART_H - 4)
    a.model:SetPoint("RIGHT", -2, 0)
    a.model:Hide()
    a.SetModelNpc = setModelNpc
    return a
end

local function buildDungeons(f)
    -- the source chips are hidden here, so the body starts below the counts
    local B = CreateFrame("Frame", nil, f)
    B:SetPoint("TOPLEFT", 0, -48)
    B:SetPoint("BOTTOMRIGHT", 0, 0)
    B.next = W.Text(B, T.FONT.title, 412)
    B.next:SetPoint("TOPLEFT", 4, -2)
    B.why = W.Text(B, T.FONT.text, 598)
    B.why:SetPoint("TOPLEFT", 4, -18)
    -- the order of the list: by level, by value (the ranking), the chain
    B.sorts = {}
    local sortDefs = { { "level", "Level", 50, L["Nach Level"], L["Die Dungeons nach ihrem Levelbereich."] },
        { "value", L["Wert"], 46, L["Rangliste"], L["Die lohnendsten Dungeons für dich zuerst: offene Quests plus zwei Läufe."] },
        { "chain", L["Kette"], 50, L["Kette"], L["Der beste Dungeon, seine Upgrades gedanklich angelegt (je Boss das größte, alle Quest-Upgrades), dann der beste danach, bis zu fünf."] } }
    local sortRow = {}
    for i, d in ipairs(sortDefs) do
        local chip = W.Chip(B, d[2], d[3], function()
            state().dsort = d[1]
            ns.Refresh()
        end)
        W.Tooltip(chip, d[4], d[5])
        B.sorts[d[1]] = chip
        sortRow[i] = chip
    end
    -- at the right edge, in the order of sortDefs
    W.Row(B, sortRow, T.CHIP_GAP, 0, 0, { right = true })
    local h = head(B, -36)
    -- the list is 590 wide (12 px for its scroll bar)
    B.head = { name = col(h, 4, 170, "Dungeon"), level = col(h, 178, 46, "Level"), fit = col(h, 228, 56, L["Passung"]),
        upgrades = col(h, 288, 56, "Upgrades"), run = col(h, 348, 66, L["Je Lauf"]), quests = col(h, 418, 66, "Quests"),
        value = col(h, 488, 60, L["Wert"]) }
    for _, k in ipairs({ "upgrades", "run", "quests", "value" }) do B.head[k]:SetJustifyH("RIGHT") end
    B.list = W.List(B, DUNGEON_ROWS, ROW_H, function(r)
        r.owner = B
        r.sel = W.SelectBar(r)
        r.name = col(r, 4, 170, nil, T.FONT.text)
        r.level = col(r, 178, 46, nil, T.FONT.text)
        r.fit = col(r, 228, 56, nil, T.FONT.text)
        r.upgrades = col(r, 288, 56, nil, T.FONT.text)
        r.run = col(r, 348, 66, nil, T.FONT.text)
        r.quests = col(r, 418, 66, nil, T.FONT.text)
        r.value = col(r, 488, 60, nil, T.FONT.text)
        for _, k in ipairs({ "upgrades", "run", "quests", "value" }) do r[k]:SetJustifyH("RIGHT") end
        r:SetScript("OnClick", function(self)
            if not self.item then return end
            state().dungeon = self.item.key
            ns.Refresh()
        end)
        r:SetScript("OnEnter", dungeonTip)
        r:SetScript("OnLeave", hideTip)
    end, fillDungeonRow)
    B.list:SetPoint("TOPLEFT", 0, -52)
    B.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -52)
    B.art = buildArt(B)
    B.mark = W.Button(B.art, DTEXT.mark, 110, function()
        if not B.chosen then return end
        if ns.DungeonMarked() == B.chosen then
            ns.DungeonClearMarks()
            ns.msg(DTEXT.unmarked)
        else
            local n, why = ns.DungeonMarkQuests(B.chosen)
            if n then ns.msg(DTEXT.marked:format(n)) else say(nil, why) end
        end
        B.mark:SetText(ns.DungeonMarked() == B.chosen and DTEXT.unmark or DTEXT.mark)
    end)
    B.mark:SetPoint("RIGHT", -(ART_H + 4), 0)
    W.Tooltip(B.mark, DTEXT.markTitle, DTEXT.markTip)

    B.header = W.SectionHeader(B, "", false)
    B.header:SetPoint("TOPLEFT", 0, -250)
    B.header:SetPoint("TOPRIGHT", -244, -250)
    -- the lower part: the bosses or the quests of the chosen dungeon
    B.parts = {}
    B.parts.bosses = W.Chip(B, L["Bosse"], 54, function() state().dpart = "bosses"; ns.Refresh() end)
    B.parts.quests = W.Chip(B, "Quests", 54, function() state().dpart = "quests"; ns.Refresh() end)
    W.Tooltip(B.parts.quests, "Quests", L["Die Quests des Dungeons mit Vorquests, Start und Belohnungen. Klick auf eine Quest setzt den Wegpunkt zum Questgeber."])
    B.way = W.Button(B, L["Wegpunkt"], 120, function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    -- the two chips and the waypoint button at the right end of the header's line
    W.Row(B, { B.parts.bosses, B.parts.quests, { B.way, gap = 6 } }, T.CHIP_GAP, 0, -251, { right = true })
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Dungeons."])
    B.detail = W.List(B, DETAIL_ROWS, ROW_H, function(r)
        r.name = col(r, 4, 220, nil, T.FONT.text)
        r.slot = col(r, 228, 62, nil, T.FONT.text)
        r.gain = col(r, 292, 40, nil, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r.xp = col(r, 336, 56, nil, T.FONT.text)
        r.xp:SetJustifyH("RIGHT")
        r.rate = col(r, 398, 188, nil, T.FONT.text)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if (e.kind == "quest" or e.kind == "pre") and e.qid and button ~= "RightButton" then
                say(ns.DungeonQuestWaypoint(e.qid))
                return
            end
            if not e.id then return end
            if button == "RightButton" then
                if e.kind == "item" then W.Menu(self, menuEntries(e, ns.BisOpts())) end
                return
            end
            modifiedClick(e.id)
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.q then
                questTip(self)
            elseif e and e.id then
                itemTooltip(self, e.id)
                GameTooltip:AddLine(DTEXT.itemHint, 0.6, 0.6, 0.6)
                GameTooltip:Show()
            elseif e and e.kind == "boss" then
                -- the hovered boss in the image
                B.art:SetModelNpc(ns.Dungeons.ModelNpc(B.entry, e.b))
            end
        end)
        r:SetScript("OnLeave", function(self)
            hideTip()
            local e = self.item
            if e and e.kind == "boss" then B.art:SetModelNpc(ns.Dungeons.ModelNpc(B.entry)) end
        end)
    end, fillDetailRow)
    B.detail:SetPoint("TOPLEFT", 0, -280)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -280)
    B.hint = W.Text(B, T.FONT.hint, 598, true)
    B.hint:SetPoint("TOPLEFT", 4, -404)
    B.hint:SetHeight(24)
    B.hint:SetJustifyV("TOP")
    return B
end

-- The image, its texts, the boss model and the mark button of the chosen dungeon e.
local function fillArt(B, e)
    local a = B.art
    if not e then
        a:Hide()
        return
    end
    a:Show()
    local Dn = ns.Dungeons
    local fid, kind = Dn.Art(e.key)
    if fid then
        a.tex:SetTexture(fid)
        a.tex:SetTexCoord(Dn.ArtCoords(kind, ART_W, ART_H))
        a.tex:Show()
    else
        a.tex:Hide()
    end
    a.title:SetText(e.name)
    local range = Dn.RangeText(e)
    a.info:SetText(range ~= "" and DTEXT.level:format(range, Dn.FitText(e)) or Dn.FitText(e))
    a:SetModelNpc(Dn.ModelNpc(e))
    B.mark:SetText(ns.DungeonMarked() == e.key and DTEXT.unmark or DTEXT.mark)
end

local function fillDungeons(B)
    local list = ns.DungeonList()
    local nextE, why = ns.DungeonNext()
    local Dn = ns.Dungeons
    local sort = state().dsort
    if sort ~= "value" and sort ~= "chain" then sort = "level" end
    for k, chip in pairs(B.sorts) do chip:SetOn(k == sort) end
    local shown, extra = orderedDungeons(list, sort)
    if sort == "chain" then
        B.next:SetText(Dn.ChainText(extra.chain, extra.why))
        B.why:SetText(#extra.chain > 0 and (L["Annahme: je Boss das größte Upgrade und alle Quest-Upgrades bekommen."] ..
            (extra.why and (" " .. extra.why) or "")) or "")
    elseif nextE then
        B.next:SetText(L["Nächster Dungeon: %s · Level %s"]:format(nextE.name, Dn.RangeText(nextE)))
        B.why:SetText(nextE.why or "")
    else
        B.next:SetText(why or Dn.NO_DATA)
        B.why:SetText("")
    end
    local e = chosenDungeon(list, nextE)
    B.chosen = e and e.key or nil
    B.list:SetItems(shown)
    if e and not e.computed then e = ns.DungeonInfo(e.key) or e end
    B.entry = e
    fillArt(B, e)
    local part = state().dpart == "quests" and "quests" or "bosses"
    for k, chip in pairs(B.parts) do chip:SetOn(k == part) end
    -- another dungeon or part starts at the top
    local detailKey = e and (e.key .. part) or nil
    if detailKey ~= B.detailKey then B.detail.offset = 0 end
    B.detailKey = detailKey
    local status
    if e and part == "quests" then
        local rows
        rows, status = questItems(e.key)
        B.header:SetHeaderText(e.name .. " · Quests")
        B.detail:SetItems(rows)
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e then
        B.header:SetHeaderText(e.name .. " · " .. L["Bosse"])
        B.detail:SetItems(detailItems(e))
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    else
        B.header:SetHeaderText("")
        B.detail:SetItems({})
        B.way:SetEnabled(false)
    end
    local hint
    if part == "quests" then
        hint = Dn.QuestStatusText(status) or ""
        if e and #B.detail.items == 0 and hint == "" then hint = L["Für diesen Dungeon kennt Amisia keine Quests."] end
        local xp = e and Dn.XPSumText(Dn.XPSum((ns.DungeonQuests(e.key)))) or ""
        local parts = {}
        for _, t in ipairs({ xp, hint, L["Klick auf eine Quest: Wegpunkt zum Questgeber. Grün: Upgrade für dich."], DTEXT.itemHint }) do
            if t ~= "" then parts[#parts + 1] = t end
        end
        hint = table.concat(parts, " ")
    else
        hint = L["Je Lauf: Zuwachs der Upgrades mal Dropchance, ohne Mitbewerber in der Gruppe. Wert: offene Dungeon-Quests plus zwei Läufe."]
        if e and e.computed and #B.detail.items == 0 then hint = L["In diesem Dungeon gibt es nichts mehr für dich."] .. " " .. hint end
        hint = hint .. " " .. DTEXT.itemHint
    end
    B.hint:SetText(hint)
end

---------------------------------------------------------------------------
-- Wunschliste: the own wishes and their text for the website
---------------------------------------------------------------------------

local function fillWishRow(r, e)
    r.name:SetText(itemText(e.id))
    r.slot:SetText(e.slot or "")
    r.src:SetText(e.src or "")
    setMapButton(r.map, e.id, nil, e.owned)
    r.prio.label:SetText(PRIO_TEXT[e.e.prio] or PRIO_TEXT[2])
    r.prio:SetOn(e.e.prio == 3)
    if e.owned then
        r.state:SetText(L["hast du"])
        r.state:SetTextColor(0.31, 0.82, 0.42)
    elseif e.excluded then
        r.state:SetText(L["aus##ausgeschlossen"])
        r.state:SetTextColor(0.56, 0.53, 0.64)
    else
        r.state:SetText("")
    end
end

local function setExport(V, text)
    exportText = text or ""
    V.area.box:SetText(exportText)
end

local function buildWish(f)
    local V = CreateFrame("Frame", nil, f)
    V:SetPoint("TOPLEFT", 0, -72)
    V:SetPoint("BOTTOMRIGHT", 0, 0)
    local h = head(V, 0)
    -- the list is 590 wide (12 px for its scroll bar): the source gives them, what follows moves left
    V.head = { name = col(h, 4, 216, "Item"), slot = col(h, 224, 76, "Slot"), src = col(h, 304, 154, L["Quelle"]),
        prio = col(h, 462, 58, L["Priorität"]), state = col(h, 524, 44, "") }
    V.list = W.List(V, WISH_ROWS, ROW_H, function(r)
        r.name = col(r, 4, 216, nil, T.FONT.text)
        r.slot = col(r, 224, 76, nil, T.FONT.text)
        r.map = mapButton(r, 304)
        r.src = col(r, 322, 136, nil, T.FONT.text)
        r.prio = W.Chip(r, "", 58, function(self)
            local e = self:GetParent().item
            if e then ns.WishSetPrio(e.id, PRIO_NEXT[e.e.prio] or 2) end
        end)
        r.prio:SetPoint("LEFT", 462, 0)
        r.state = col(r, 524, 44, nil, T.FONT.text)
        r.del = W.ResetButton(r, 18, function(self)
            local e = self:GetParent().item
            if e then ns.WishRemove(e.id) end
        end)
        r.del:SetPoint("LEFT", 572, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if button == "RightButton" then
                W.Menu(self, menuEntries({ id = e.id, wished = true }, ns.BisOpts()))
                return
            end
            modifiedClick(e.id)
        end)
        r:SetScript("OnEnter", function(self) if self.item then itemTooltip(self, self.item.id) end end)
        r:SetScript("OnLeave", hideTip)
    end, fillWishRow)
    V.list:SetPoint("TOPLEFT", 0, -16)
    V.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -16)

    V.area = W.EditArea(V)
    V.area:SetPoint("TOPLEFT", 0, -16)
    V.area:SetPoint("TOPRIGHT", 0, -16)
    V.area:SetHeight(120)
    -- read-only like the export box: typing puts the text back and marks it
    V.area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(exportText or "")
            self:HighlightText()
        end
    end)
    V.area:Hide()
    V.areaHint = W.Text(V, T.FONT.hint, 598, true)
    V.areaHint:SetPoint("TOPLEFT", 4, -142)
    V.areaHint:SetHeight(28)
    V.areaHint:SetText(L["Strg+A, Strg+C, auf der Website im Reiter Wishlist bei Paste from the addon einfügen."])
    V.areaHint:Hide()

    V.web = W.Button(V, L["Für die Website"], 120, function()
        exportOpen = not exportOpen
        if exportOpen then
            setExport(V, ns.WishExportText())
            V.area.box:SetFocus()
            V.area.box:HighlightText()
        else
            V.area.box:ClearFocus()
        end
        ns.Refresh()
    end)
    V.web:SetPoint("TOPLEFT", 0, -310)
    V.clean = W.Button(V, L["Erhaltene entfernen"], 140, function()
        for _, e in ipairs(ns.Wishes()) do
            if e.owned then ns.WishRemove(e.id) end
        end
    end)
    V.clean:SetPoint("LEFT", V.web, "RIGHT", 6, 0)
    V.hint = W.Text(V, T.FONT.hint, 598, true)
    V.hint:SetPoint("TOPLEFT", 4, -338)
    V.hint:SetHeight(28)
    return V
end

local function fillWish(V)
    local c = cached()
    if not c.wishes then c.wishes = ns.Wishes() end
    local list = c.wishes
    V.list:SetItems(list)
    if exportOpen then
        V.list:Hide()
        V.area:Show()
        V.areaHint:Show()
        V.web:SetText(L["Zur Liste"])
        -- the text follows the list unless the box is in use
        if not V.area.box:HasFocus() then
            local text = ns.WishExportText()
            if text ~= exportText then setExport(V, text) end
        end
    else
        V.area:Hide()
        V.areaHint:Hide()
        V.list:Show()
        V.web:SetText(L["Für die Website"])
    end
    local owned = false
    for _, e in ipairs(list) do if e.owned then owned = true break end end
    if ns.Get("bis.wishAutoRemove") then   -- l10n-ok: setting key
        V.clean:Hide()
    else
        V.clean:Show()
        V.clean:SetEnabled(owned)
    end
    if #list == 0 then
        V.hint:SetText(L["Noch keine Wünsche. Wunsch-Knopf in Ziele oder Hier, oder /amisia wunsch <Item-Link>."])
    else
        V.hint:SetText(L["%d von %d Wünschen. Ein Klick auf die Priorität ändert sie."]:format(#list, ns.BIS_MAX_WISH or 50))
    end
end

---------------------------------------------------------------------------
-- Gilde: the website's wishlist in the game
---------------------------------------------------------------------------

local function onlyGroup()
    if groupOnly ~= nil then return groupOnly end
    return IsInRaid() and true or false
end

local function classColored(text, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return (c and c.colorStr) and ("|c%s%s|r"):format(c.colorStr, text) or text
end

local guildKey, guildList
local function guildItems(only)
    local g = AmisiaDB.bis and AmisiaDB.bis.guild
    if type(g) ~= "table" or type(g.list) ~= "table" then return {} end
    local roster = ns.GroupRoster()
    local key = table.concat({ tostring(g.list), tostring(g.at), tostring(only), table.concat(roster, ",") }, "|")
    if key == guildKey then return guildList end
    -- the class of everyone in the raid, for the colours
    local classes = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            name, class = ns.FullName(ns.Plain(name)), ns.Plain(class)
            if name then classes[name:lower()] = class end
        end
    end
    local out = {}
    for id in pairs(g.list) do
        local ws = ns.WishersOf(id, only)
        if #ws > 0 then
            local names = {}
            for _, w in ipairs(ws) do
                local text = w.name .. (PRIO_TIP[w.prio] or "")
                if w.inGroup then
                    local class = classes[w.name:lower()]
                    if not class then
                        for _, r in ipairs(roster) do
                            if ns.SameNameIn(w.name, r, roster) then class = classes[r:lower()] break end
                        end
                    end
                    names[#names + 1] = classColored(text, class)
                else
                    names[#names + 1] = GREY .. text .. "|r"
                end
            end
            out[#out + 1] = { id = id, n = #ws, who = table.concat(names, ", ") }
        end
    end
    table.sort(out, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.id < b.id
    end)
    guildKey, guildList = key, out
    return out
end

local function buildGuild(f)
    local U = CreateFrame("Frame", nil, f)
    U:SetPoint("TOPLEFT", 0, -72)
    U:SetPoint("BOTTOMRIGHT", 0, 0)
    U.info = W.Text(U, T.FONT.text, 470)
    U.info:SetPoint("TOPLEFT", 4, -4)
    U.group = W.Chip(U, L["Nur Gruppe"], 100, function()
        groupOnly = not onlyGroup()
        ns.Refresh()
    end)
    U.group:SetPoint("TOPRIGHT", 0, -2)
    local h = head(U, -26)
    -- the list is 590 wide (12 px for its scroll bar), the wishers give them
    U.head = { name = col(h, 4, 256, "Item"), who = col(h, 264, 322, L["Wünschende"]) }
    U.list = W.List(U, GUILD_ROWS, ROW_H, function(r)
        r.name = col(r, 4, 256, nil, T.FONT.text)
        r.who = col(r, 264, 322, nil, T.FONT.text)
        r:SetScript("OnClick", function(self) if self.item then modifiedClick(self.item.id) end end)
        r:SetScript("OnEnter", function(self) if self.item then itemTooltip(self, self.item.id) end end)
        r:SetScript("OnLeave", hideTip)
    end, function(r, e)
        r.name:SetText(itemText(e.id))
        r.who:SetText(e.who)
    end)
    U.list:SetPoint("TOPLEFT", 0, -40)
    U.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -40)
    U.area = W.EditArea(U)
    U.area:SetPoint("TOPLEFT", 0, -308)
    U.area:SetPoint("TOPRIGHT", 0, -308)
    U.area:SetHeight(70)
    U.importBtn = W.Button(U, L["Importieren"], 100, function()
        -- the website's text: the wishes, the alts and the loot prio (any of them)
        local text, ok = ns.ImportSiteText(U.area.box:GetText())
        if ok then
            U.area.box:SetText("")
            U.area.box:ClearFocus()
        end
        guildResult = text
        ns.Refresh()
    end)
    U.importBtn:SetPoint("TOPLEFT", 0, -382)
    U.clearBtn = W.Button(U, L["Löschen##Gildenwünsche"], 80, function()
        lift(StaticPopup_Show("AMISIA_GUILDWISH_CLEAR"))
    end)
    U.clearBtn:SetPoint("LEFT", U.importBtn, "RIGHT", 6, 0)
    U.hint = W.Text(U, T.FONT.hint, 410)
    U.hint:SetPoint("TOPLEFT", 192, -386)
    return U
end

local function fillGuild(U)
    local officer = ns.IsOfficerView()
    local info = ns.GuildWishesInfo()
    local age = ns.GuildWishesAgeText()
    if info then
        U.info:SetText((info.n == 1 and L["Liste vom %s, 1 Wunsch"] or L["Liste vom %s, %d Wünsche"]):format(longDate(info.date), info.n)
            .. (age and (" " .. GREY .. age .. "|r") or ""))
    else
        U.info:SetText(GREY .. L["Keine Gildenwünsche geladen."] .. "|r")
    end
    local alts = ns.AltsInfo()
    if alts then
        U.info:SetText(U.info:GetText() .. " · " .. (alts.n == 1 and L["1 Twink"] or L["%d Twinks"]:format(alts.n)))
    end
    local only = onlyGroup()
    U.group:SetOn(only)
    U.list:SetItems(guildItems(only))
    if officer then
        U.area:Show(); U.importBtn:Show(); U.clearBtn:Show()
        U.clearBtn:SetEnabled(info ~= nil)
        U.hint:SetText(guildResult or L["Auf der Website im Reiter Wishlist: Copy for the addon."])
    else
        U.area:Hide(); U.importBtn:Hide(); U.clearBtn:Hide()
        U.hint:SetText(age or "")
    end
end

---------------------------------------------------------------------------
-- Simulation: the best items of any class, spec and level (ns.BisFor), without ownership
---------------------------------------------------------------------------

local SIM_ROWS = 11

-- The simulated character in settings.bis.sim: class, spec, level, weapon plan; starts as the own.
local function simState()
    local st = state()
    st.sim = type(st.sim) == "table" and st.sim or {}
    local sim = st.sim
    local _, myClass = UnitClass("player")
    if not (type(sim.class) == "string" and #Gear.Specs(sim.class) > 0) then sim.class = myClass or "WARRIOR" end
    local ok = false
    for _, sp in ipairs(Gear.Specs(sim.class)) do if sp.key == sim.spec then ok = true end end
    if not ok then sim.spec = (Gear.Specs(sim.class)[1] or {}).key end
    sim.level = math.max(1, math.min(tonumber(sim.level) or tonumber(UnitLevel("player")) or 1, Gear.Cap()))
    if not ns.BIS_PLANS[sim.plan] then sim.plan = "auto" end
    return sim
end
ns.BisSimState = simState

local function simChanged()
    ns.Refresh()
end

local function fillSimRow(r, e)
    r.slot:SetText(e.name)
    if e.opt then
        r.best:SetText(itemText(e.opt[1]) .. noteText(e.opt))
        r.src:SetText(sourceText(e.opt[1], nil, e.opt.pick))
        r.score:SetText(Gear.Num(e.opt[2]))
    else
        r.best:SetText(GREY .. ((e.key == "OFFHAND" and e.plan == "2H") and L["Zweihandwaffe geplant"] or L["keine Option"]) .. "|r")
        r.src:SetText("")
        r.score:SetText("")
    end
end

local function buildSim(f)
    local S = CreateFrame("Frame", nil, f)
    S:SetPoint("TOPLEFT", 0, -72)
    S:SetPoint("BOTTOMRIGHT", 0, 0)
    S.class = W.Picker(S, 118, function(v)
        local sim = simState()
        sim.class, sim.spec = v, nil
        simChanged()
    end)
    S.spec = W.Picker(S, 140, function(v)
        simState().spec = v
        simChanged()
    end)
    S.level = W.Stepper(S, 104, function(v)
        simState().level = v
        simChanged()
    end)
    S.plan = W.Picker(S, 132, function(v)
        simState().plan = v
        simChanged()
    end)
    W.Row(S, { S.class, S.spec, S.level, S.plan }, 6, 0, 0)
    S.back = W.Button(S, L["Zurück"], 84, function() setView("goals") end)
    S.back:SetPoint("TOPRIGHT", 0, 1)
    local h = head(S, -28)
    S.head = { slot = col(h, 4, 66, "Slot"), best = col(h, 74, 250, L["Bestes"]), src = col(h, 328, 200, L["Quelle"]),
        score = col(h, 532, 54, L["Wertung"]) }
    S.head.score:SetJustifyH("RIGHT")
    S.list = W.List(S, SIM_ROWS, ROW_H, function(r)
        r.slot = col(r, 4, 66)
        r.best = col(r, 74, 250, nil, T.FONT.text)
        r.src = col(r, 328, 200, nil, T.FONT.text)
        r.score = col(r, 532, 54, nil, T.FONT.text)
        r.score:SetJustifyH("RIGHT")
        r:SetScript("OnClick", function(self)
            local e = self.item
            if e and e.opt then modifiedClick(e.opt[1]) end
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.opt then itemTooltip(self, e.opt[1]) end
        end)
        r:SetScript("OnLeave", hideTip)
    end, fillSimRow)
    S.list:SetPoint("TOPLEFT", 0, -44)
    S.list:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, -44)
    S.info = W.Text(S, T.FONT.text, 598, true)
    S.info:SetPoint("TOPLEFT", 4, -44 - SIM_ROWS * ROW_H - 6)
    S.info:SetHeight(40)
    S.info:SetJustifyV("TOP")
    S.info:SetMaxLines(3)
    return S
end

local function fillSim(S)
    local sim = simState()
    local classes = {}
    for _, token in ipairs(ns.GEAR_WEIGHTS and ns.GEAR_WEIGHTS.order or {}) do
        classes[#classes + 1] = { value = token, text = Gear.CLASS_NAMES[token] or token }
    end
    S.class:SetValues(classes)
    S.class:SetValue(sim.class)
    local specs = {}
    for _, sp in ipairs(Gear.Specs(sim.class)) do specs[#specs + 1] = { value = sp.key, text = L[sp.name] } end
    S.spec:SetValues(specs)
    S.spec:SetValue(sim.spec)
    S.level:Configure(1, Gear.Cap(), 1, function(v) return "Level " .. v end)
    S.level:SetValue(sim.level)
    local plans = {}
    for _, k in ipairs(ns.BIS_PLAN_ORDER) do plans[#plans + 1] = { value = k, text = L["Waffen: %s"]:format(ns.BIS_PLANS[k]) } end
    S.plan:SetValues(plans)
    S.plan:SetValue(sim.plan)
    -- the result, kept until anything the gear page depends on changes
    local c = cached()
    local key = table.concat({ sim.class, tostring(sim.spec), sim.level, sim.plan }, "|")
    if c.simKey ~= key then
        c.simKey = key
        c.sim = ns.BisFor(sim.class, sim.spec, sim.level, { plan = sim.plan })
    end
    local res = c.sim
    local items = {}
    for _, sl in ipairs(Gear.SLOTS) do
        items[#items + 1] = { key = sl.key, name = sl.name, opt = res[sl.key] and res[sl.key][1], plan = res.plan }
    end
    S.list:SetItems(items)
    local o = { class = sim.class, spec = sim.spec, kind = ns.Get("gear.kind") or "Speedrun", level = sim.level }
    local lines = ns.BisWhy(o)
    S.info:SetText(GREY .. L["Ohne Besitz und Zuwachs, mit deinen Quellen."] .. " " .. table.concat(lines, " ") .. "|r")
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function ns.GearPageFrame() return page end

StaticPopupDialogs["AMISIA_BIS_CLEAR_EX"] = {
    text = L["Alle Ausschlüsse aufheben?"],
    button1 = L["Aufheben"],
    button2 = L["Abbrechen"],
    OnAccept = function() ns.BisClearExcludes() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

ns.RegisterPanel{ key = "gear", label = L["Ausrüstung"], icon = "Interface\\Icons\\INV_Chest_Chain_05", order = 50, group = "gear",
    available = function() return Gear.Available() end,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        page = f
        f.spec = W.Picker(f, 180, function(v) ns.BisSetSpec(v ~= "" and v or nil) end)
        f.views = {}
        f.views.goals = W.Chip(f, L["Ziele"], 52, function() setView("goals") end)
        f.views.here = W.Chip(f, L["Hier"], 46, function() state().place = nil; setView("here") end)
        f.views.dungeons = W.Chip(f, "Dungeons", 74, function() setView("dungeons") end)
        f.views.wish = W.Chip(f, L["Wunschliste"], 104, function() setView("wish") end)
        f.views.guild = W.Chip(f, L["Gilde"], 56, function() setView("guild") end)
        -- the spec, then the views
        W.Row(f, { f.spec, { f.views.goals, gap = 6 }, f.views.here, f.views.dungeons, f.views.wish, f.views.guild },
            T.CHIP_GAP, 0, -1)
        -- 64 wide since the dungeons chip came: the tooltip says what the table is
        f.open = W.Button(f, L["Tabelle"], 64, function() ns.ToggleGearFrame() end)
        f.open:SetPoint("TOPRIGHT", 0, 0)
        W.Tooltip(f.open, L["Ausrüstungstabelle"], L["Die besten Items aller Levelbereiche für jede Spezialisierung."])
        f.counts = W.Text(f, T.FONT.hint, 488)
        f.counts:SetPoint("TOPLEFT", 4, -28)
        f.reset = W.Button(f, L["zurücksetzen"], 104, function() lift(StaticPopup_Show("AMISIA_BIS_CLEAR_EX")) end)
        f.reset:SetPoint("TOPRIGHT", 0, -24)
        -- the weapon plan of the own character, beside the source chips of the targets
        f.plan = W.Picker(f, 132, function(v) say(ns.BisSetPlan(v)) end)
        f.plan:SetPoint("TOPLEFT", 466, -48)
        f.src = {}
        for _, def in ipairs(CHIPS) do
            local key = def[1]
            f.src[key] = W.Chip(f, def[2], def[3], function()
                if key == "C" then
                    profClick()
                else
                    local src = ns.BisOpts().sources
                    src[key] = not src[key]
                    ns.Fire("BIS_CHANGED")
                end
            end)
            -- as wide as given, wider where the text (English) needs it
            W.FitChip(f.src[key], def[3])
            f.src[key]:SetPoint("TOPLEFT", 0, -48)
        end
        f.goals = buildGoals(f)
        f.here = buildHere(f)
        f.dungeons = buildDungeons(f)
        f.wish = buildWish(f)
        f.guild = buildGuild(f)
        f.sim = buildSim(f)
        f.bodies = { goals = f.goals, here = f.here, dungeons = f.dungeons, wish = f.wish, guild = f.guild, sim = f.sim }
        for _, b in pairs(f.bodies) do b:Hide() end
        return f
    end,
    refresh = function(f)
        nameMissing = false
        local o = ns.BisOpts()
        local res = ns.BisTargets()
        local v = shownView()
        fillHead(f, o, res, v)
        for k, body in pairs(f.bodies) do
            if k ~= v then body:Hide() end
        end
        f.bodies[v]:Show()
        if v == "goals" then
            fillGoals(f.goals, o, res)
        elseif v == "here" then
            fillHere(f.here, o)
        elseif v == "dungeons" then
            fillDungeons(f.dungeons)
        elseif v == "wish" then
            fillWish(f.wish)
        elseif v == "sim" then
            fillSim(f.sim)
        else
            fillGuild(f.guild)
        end
    end }

-- A wish, an exclusion, the spec, the own items or the guild list changed: show it at once.
local function refreshShown()
    local cur = ns.CurrentPage and ns.CurrentPage()
    if cur == "gear" or cur == "overview" then ns.Refresh() end
end
ns.Listen("BIS_CHANGED", refreshShown)
-- a new or cleared list: what the last import said is over (an import sets its result afterwards)
ns.Listen("GUILD_WISHES", function()
    guildResult = nil
    refreshShown()
end)
ns.Listen("ALTS", refreshShown)
ns.BisOnOwned(refreshShown)

-- Item names the client did not have at the last refresh: once item data arrives the shown rows
-- are filled again, once for a burst of answers, and the wishlist (sorted by name) and the guild
-- list are built again.
local namesDue = false
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if not nameMissing or namesDue then return end
    namesDue = true
    C_Timer.After(0.3, function()
        namesDue = false
        if not nameMissing or not (ns.CurrentPage and ns.CurrentPage() == "gear") then return end
        memo.wishes = nil
        guildKey = nil
        ns.Refresh()
    end)
end)

---------------------------------------------------------------------------
-- The overview card
---------------------------------------------------------------------------

local function bestUpgrade(res)
    local best
    for _, sl in ipairs(Gear.SLOTS) do
        local e = res[sl.key] and res[sl.key][1]
        if e and e.upgrade and (not best or e.gain > best.gain) then best = e end
    end
    return best
end

ns.RegisterCard{ key = "gear", order = 30, available = function() return Gear.Available() end, fill = function(c)
    local o = ns.BisOpts()
    local res = ns.BisTargets()
    local n = wishCount()
    c.title:SetText(L["Deine Ausrüstung"])
    c.line1:SetText((n == 1 and L["Level %d · %s · 1 Wunsch"] or L["Level %d · %s · %d Wünsche"]):format(o.level, upgradesText(res.upgrades or 0), n))
    local cur = ns.BisCurrentPlace()
    if cur and cur.key:find("^I:") and placeKnown(cur) then
        local _, list = ns.BisHere(nil, o)
        local up = 0
        for _, e in ipairs(list) do
            if e.upgrade and not e.owned then up = up + 1 end
        end
        c.line2:SetText(L["Hier: %s (%s)"]:format(upgradesText(up), cur.text or "?"))
    else
        local best = bestUpgrade(res)
        local text = best and L["Bestes: %s (+%d)"]:format(itemText(best.id), math.floor(best.gain + 0.5)) or L["Kein Upgrade in den Daten."]
        -- the dungeon planner's recommendation, from its cache when nothing changed
        local nextE = ns.DungeonNext and ns.DungeonNext()
        if nextE then text = text .. "\n" .. L["Nächster Dungeon: %s"]:format(nextE.name) end
        -- two lines at most: a long item name would wrap the text into the button
        c.line2:SetMaxLines(2)
        c.line2:SetText(text)
    end
    c:SetAction(L["Ansehen"], function() ns.ShowGear("goals") end)
end }
