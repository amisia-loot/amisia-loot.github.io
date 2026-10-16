-- Mitglieder (tab Gilde, F-104, spec docs/specs/2026-10-16-gilde-mitglieder.md): one row per guild
-- member from the guild roster (Core/Trust.lua, ns.GuildRoster: rebuilt at most every 10 s, never in
-- the lockdown): the round class icon, the name in class colour over level, class and rank, the zone
-- over "online" or the time since the member was last online, the professions with their skill from
-- the recipe exchange (Gear/Crafters.lua, Cr.Professions: members with Amisia and the own characters).
-- Dropdowns Klasse and Beruf, "nur online", a name search; a click on a column head sorts. The row's
-- tooltip: rank, notes (the officer note only when the client shows it), main and alts (the alt list);
-- a profession's tooltip: skill, recipes, how old. A click on a row: Flüstern, Einladen. Everyone sees
-- it; without a guild it says so. The filters stay in settings.window.members.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local M = T.MEMBERS

local page
local query = ""                -- the name search (not kept)
local last                      -- the rows of the last build (shown again in the lockdown)
local askedAt                   -- when the page last asked the client for the roster

function ns.MembersPageFrame() return page end

local SORTS = { name = true, level = true, zone = true, last = true, prof = true }

-- settings.window.members: { class = class token or "all", prof = skill line or "all", online = bool,
-- sort = a column key (nil: online first, then the name), desc = bool }
local function state()
    local s = AmisiaDB and AmisiaDB.settings
    if type(s) ~= "table" then return { class = "all", prof = "all" } end
    s.window = type(s.window) == "table" and s.window or {}
    local m = type(s.window.members) == "table" and s.window.members or {}
    s.window.members = m
    if type(m.class) ~= "string" then m.class = "all" end
    if m.prof ~= "all" and type(m.prof) ~= "number" then m.prof = "all" end
    m.online = m.online == true or nil
    if not SORTS[m.sort] then m.sort = nil end
    m.desc = m.desc == true or nil
    return m
end

---------------------------------------------------------------------------
-- What a row shows
---------------------------------------------------------------------------
local function classColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, name) or name
end

-- The class's name (Amisia's for the classes it knows, else the client's), nil when unknown.
local function className(e)
    local names = ns.Gear and ns.Gear.CLASS_NAMES
    return names and names[e.class] or e.className or (e.class ~= "" and e.class) or nil
end

-- the guild master types the rank names: shown as plain text (a bar would start a code)
local function rankName(e) return e.rankName and (tostring(e.rankName):gsub("|", "||")) or L["Rang %d"]:format(e.rank or 0) end

-- "60 Priester · Offizier" (the level as the number only: the line holds the rank too)
local function infoText(e)
    local cls = className(e)
    return (e.level and tostring(e.level) or "?") .. (cls and (" " .. cls) or "")
        .. " · " .. rankName(e)
end

-- The round class icon: the client's class circles, the class's part of them.
local function setClassIcon(tex, class)
    local tc = type(_G.CLASS_ICON_TCOORDS) == "table" and _G.CLASS_ICON_TCOORDS[class] or M.CLASS_COORDS[class]
    if tc then
        tex:SetTexture(M.CLASS_TEXTURE)
        tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        tex:Show()
    else
        tex:Hide()
    end
end

-- Hours since a member was online (0 online, a big number when the client does not say).
local function hoursAway(e)
    if e.online then return 0 end
    local a = e.last
    if not a then return 1e9 end
    return a.y * 8760 + a.mo * 730 + a.d * 24 + a.h
end

-- "zuletzt vor 2 Tagen 19 Stunden" as the client's guild window counts (the two largest units; short:
-- the largest only, for the row; the tooltip has both).
local UNITS = {
    { "y", L["%d Jahr##vor"], L["%d Jahren##vor"] }, { "mo", L["%d Monat##vor"], L["%d Monaten##vor"] },
    { "d", L["%d Tag##vor"], L["%d Tagen##vor"] }, { "h", L["%d Stunde##vor"], L["%d Stunden##vor"] },
}
local function awayText(a, short)
    if not a then return L["offline"] end
    local parts = {}
    for i, u in ipairs(UNITS) do
        local n = a[u[1]] or 0
        if n > 0 then
            parts[1] = (n == 1 and u[2] or u[3]):format(n)
            local nx = UNITS[i + 1]
            local m = nx and a[nx[1]] or 0
            if m > 0 and not short then parts[2] = (m == 1 and nx[2] or nx[3]):format(m) end
            break
        end
    end
    if #parts == 0 then return short and L["gerade offline"] or L["zuletzt vor weniger als 1 Stunde"] end
    return L["zuletzt vor %s"]:format(table.concat(parts, " "))
end

local function lastText(e)
    if e.online then return T.GREEN .. L["online"] .. "|r" end
    return T.GREY .. awayText(e.last, true) .. "|r"
end
ns.MembersInfoText, ns.MembersLastText = infoText, lastText

-- A note as plain text in a tooltip (a bar would start a code).
local function plain(s) return (tostring(s):gsub("|", "||")) end

---------------------------------------------------------------------------
-- Professions
---------------------------------------------------------------------------
local Pr = function() return ns.Prof end
local keyOf = {}                -- skill line -> profession key (from the data, read on the page)
local function profKey(skill)
    local k = keyOf[skill]
    if k == nil then
        k = Pr() and ns.HasData("PROFESSIONS") and Pr().Key(skill) or false
        keyOf[skill] = k
    end
    return k or nil
end
local function profName(skill)
    local k = profKey(skill)
    return k and Pr().NAMES[k] or L["Beruf %s"]:format(tostring(skill))
end
local function profIcon(skill)
    local k = profKey(skill)
    return (k and Pr().ICONS[k]) or (Pr() and Pr().ICON_UNKNOWN) or nil
end
local function secondary(skill)
    local k = profKey(skill)
    return k and Pr().SECONDARY[k] or nil
end

-- The professions of a member in its two lines: the main ones (the higher skill first, two at most),
-- then the secondary ones (cooking, first aid, fishing, poisons; three at most).
local function profLines(list)
    local main, other = {}, {}
    for _, p in ipairs(list or {}) do
        if secondary(p.skill) then other[#other + 1] = p else main[#main + 1] = p end
    end
    table.sort(main, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.skill < b.skill
    end)
    table.sort(other, function(a, b) return secondary(a.skill) < secondary(b.skill) end)
    for i = #main, M.MAIN_BOXES + 1, -1 do main[i] = nil end
    for i = #other, M.BOXES + 1, -1 do other[i] = nil end
    return main, other
end

local function ageText(p)
    if p.age == nil then return L["Stand unbekannt"] end
    if p.age == 0 then return L["Stand heute"] end
    if p.age == 1 then return L["Stand vor 1 Tag"] end
    return L["Stand vor %d Tagen"]:format(p.age)
end

-- "Alchimie 225/300, 84 Rezepte, Stand vor 3 Tagen"
function ns.MembersProfText(p)
    local skill = p.max and p.max > 0 and ("%d/%d"):format(p.rank, p.max) or tostring(p.rank)
    local recipes = p.known == 1 and L["1 Rezept"] or L["%d Rezepte"]:format(p.known or 0)
    return table.concat({ profName(p.skill) .. " " .. skill, recipes, ageText(p) }, ", ")
end

-- The skill a row sorts by on "Berufe": the chosen profession's, else the highest.
local function profRank(e, skill)
    local best = -1
    for _, p in ipairs(e.profs or {}) do
        if (skill == nil or p.skill == skill) and p.rank > best then best = p.rank end
    end
    return best
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------
local function inGuild() return type(_G.IsInGuild) == "function" and ns.Plain(IsInGuild()) == true end

-- Every member as a row: the roster's fields, the professions, whether Amisia is known to run there.
-- nil when the roster cannot be read yet.
local function build()
    local roster = ns.GuildRoster and ns.GuildRoster()
    if not roster then return nil end
    local profs = ns.Crafters and ns.Crafters.Professions() or {}
    local amisia = {}
    for _, v in ipairs(ns.VersionSeen and ns.VersionSeen() or {}) do amisia[v.name:lower()] = v.v or true end
    local me = ns.UnitFullName("player")
    local out = {}
    for _, m in ipairs(roster) do
        local low = m.name:lower()
        local own = m.self or (me ~= nil and low == me:lower())
        local e = { name = m.name, class = m.class or "", className = m.className, level = m.level, rank = m.rank,
                    rankName = m.rankName, zone = m.zone, online = m.online and true or false, note = m.note,
                    officerNote = m.officerNote, last = m.last, own = own, profs = profs[low],
                    version = type(amisia[low]) == "string" and amisia[low] or nil }
        e.amisia = own or profs[low] ~= nil or amisia[low] ~= nil
        e.away = hoursAway(e)
        e.fold = ns.Fold(m.name)
        out[#out + 1] = e
    end
    return out
end

local function compare(st)
    local key, desc, skill = st.sort, st.desc, st.prof ~= "all" and st.prof or nil
    local function byName(a, b) return a.fold < b.fold end
    return function(a, b)
        if not key then
            if a.online ~= b.online then return a.online end
            return byName(a, b)
        end
        local x, y
        if key == "level" then x, y = a.level or 0, b.level or 0
        elseif key == "zone" then x, y = ns.Fold(a.zone or "~"), ns.Fold(b.zone or "~")
        elseif key == "last" then x, y = a.away, b.away
        elseif key == "prof" then x, y = profRank(a, skill), profRank(b, skill)
        else x, y = a.fold, b.fold end
        if x ~= y then
            if desc then return x > y end
            return x < y
        end
        return byName(a, b)
    end
end

-- The rows the filters leave, sorted, and the counts { all, shown, online, amisia }.
local function filtered(rows, st)
    local q = ns.Fold((query or ""):match("^%s*(.-)%s*$"))
    local out, n = {}, { all = #rows, shown = 0, online = 0, amisia = 0 }
    for _, e in ipairs(rows) do
        local ok = (st.class == "all" or e.class == st.class) and (not st.online or e.online)
            and (q == "" or e.fold:find(q, 1, true) ~= nil)
        if ok and st.prof ~= "all" then ok = profRank(e, st.prof) >= 0 end
        if ok then
            out[#out + 1] = e
            n.shown = n.shown + 1
            if e.online then n.online = n.online + 1 end
            if e.amisia then n.amisia = n.amisia + 1 end
        end
    end
    table.sort(out, compare(st))
    return out, n
end

---------------------------------------------------------------------------
-- Tooltips and the row menu
---------------------------------------------------------------------------
-- The lines of a row's tooltip (also for the tests): { text, r, g, b }
function ns.MembersTooltipLines(e)
    local out = {}
    local function add(text, r, g, b) out[#out + 1] = { text, r or 0.85, g or 0.85, b or 0.85 } end
    add(infoText(e))
    if e.zone then add(L["Ort: %s"]:format(plain(e.zone))) end
    if e.online then add(L["online"], 0.31, 0.75, 0.48) else add(awayText(e.last), 0.6, 0.6, 0.6) end
    if e.note then add(L["Notiz: %s"]:format(plain(e.note))) end
    if e.officerNote then add(L["Offiziersnotiz: %s"]:format(plain(e.officerNote))) end
    local main = ns.AltMain and ns.AltMain(e.name)
    if main then
        add(L["Main: %s"]:format(main))
    else
        local alts = ns.AltsOf and ns.AltsOf(e.name) or {}
        if #alts > 0 then add(L["Twinks: %s"]:format(table.concat(alts, ", "))) end
    end
    if e.version then add(L["Amisia %s"]:format(plain(e.version)), 0.6, 0.6, 0.6) end
    if not e.own then add(L["Klick: Flüstern oder Einladen"], 0.6, 0.6, 0.6) end
    return out
end

local function rowTooltip(self)
    local e = self.item
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(classColored(e.name, e.class), 1, 0.82, 0)
    for _, l in ipairs(ns.MembersTooltipLines(e)) do GameTooltip:AddLine(l[1], l[2], l[3], l[4], true) end
    GameTooltip:Show()
end

local function boxTooltip(self)
    local p = self.prof
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.MembersProfText(p), 1, 0.82, 0)
    if not p.own then
        GameTooltip:AddLine(L["Aus dem Rezept-Austausch der Gilde; Einträge bleiben 45 Tage."], 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

-- Opens a whisper to name: "/w Name " in the chat line (a name with a space: the whisper itself,
-- "/w First Surname" would whisper "First").
local function whisper(name)
    local util = _G.ChatFrameUtil
    if not name:find(" ", 1, true) then
        local open = _G.ChatFrame_OpenChat or (type(util) == "table" and util.OpenChat) or nil
        if type(open) == "function" then return (pcall(open, ("/w %s "):format(name))) end
    end
    local tell = _G.ChatFrame_SendTell or (type(util) == "table" and util.SendTell) or nil
    if type(tell) == "function" then return (pcall(tell, name)) end
    return false
end

ns.Whisper = whisper

local function invite(name)
    local api = _G.C_PartyInfo
    local fn = type(api) == "table" and api.InviteUnit or _G.InviteUnit
    if type(fn) ~= "function" then return false end
    return (pcall(fn, name))
end

-- The menu of a row: Flüstern, and Einladen while the member is online; none for the own character.
function ns.MembersMenuEntries(e)
    if not e or e.own then return {} end
    local out = { { L["Flüstern"], function() whisper(e.name) end } }
    if e.online then out[#out + 1] = { L["Einladen"], function() invite(e.name) end } end
    return out
end

local function openMenu(row)
    local entries = ns.MembersMenuEntries(row and row.item)
    if #entries == 0 then return end
    local menu = W.Menu(row, entries)
    -- under the name, not beside the list
    if menu and menu:IsShown() then
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", row, "BOTTOMLEFT", M.NAME_X, 0)
    end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function buildBox(r, w)
    local b = CreateFrame("Button", nil, r)
    b:SetSize(w, M.BOX_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(M.BOX_ICON, M.BOX_ICON)
    b.icon:SetPoint("LEFT", 0, 0)
    b.num = W.Text(b, M.NUM_FONT)
    b.num:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, 0)
    b.num:SetJustifyH("RIGHT")
    b.num:SetDrawLayer("OVERLAY", 7)
    -- the profession window's skill bar, filled by rank / max, the name on it
    local barW = w - M.BOX_ICON - M.BAR_GAP
    b.bar = CreateFrame("Button", nil, b)
    b.bar:SetSize(barW, M.BAR_H)
    b.bar:SetPoint("LEFT", b.icon, "RIGHT", M.BAR_GAP, 0)
    b.bar:EnableMouse(false)
    if not W.SlicedAtlas(b.bar, "BACKGROUND", 0, "Professions-skillbar-bg", 6, M.BAR_H) then
        W.Flat(b.bar, 0, 0, 0, 0.5, "BACKGROUND")
    end
    b.fill = b.bar:CreateTexture(nil, "ARTWORK")
    b.fill:SetColorTexture(M.BAR_COLOR[1], M.BAR_COLOR[2], M.BAR_COLOR[3], 0.85)
    b.fill:SetPoint("LEFT", 2, 0)
    b.fill:SetHeight(M.BAR_H - 4)
    b.fillW = barW - 4
    W.SlicedAtlas(b.bar, "OVERLAY", 0, "Professions-skillbar-frame", 6, M.BAR_H)
    b.label = W.Text(b.bar, T.FONT.text, barW - 2 * M.BAR_PAD)
    b.label:SetPoint("LEFT", M.BAR_PAD, 0)
    b.label:SetDrawLayer("OVERLAY", 7)
    b:SetScript("OnEnter", boxTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self) openMenu(self:GetParent()) end)
    b:Hide()
    return b
end

local function fillBox(b, p)
    b.prof = p
    b.icon:SetTexture(profIcon(p.skill))
    b.num:SetText(tostring(p.rank))
    b.label:SetText(profName(p.skill))
    local frac = (p.max and p.max > 0) and math.min(1, p.rank / p.max) or 0
    if frac > 0 then
        b.fill:SetWidth(math.max(1, b.fillW * frac))
        b.fill:Show()
    else
        b.fill:Hide()
    end
    b:Show()
end

local function buildRow(r)
    r.classIcon = r:CreateTexture(nil, "ARTWORK")
    r.classIcon:SetSize(M.ICON, M.ICON)
    r.classIcon:SetPoint("LEFT", M.ICON_X, 0)
    r.name = W.Text(r, T.FONT.body, M.NAME_W)
    r.name:SetPoint("TOPLEFT", M.NAME_X, M.LINE1_Y)
    r.info = W.Text(r, T.FONT.text, M.NAME_W)
    r.info:SetPoint("TOPLEFT", M.NAME_X, M.LINE2_Y)
    local textX, textW = M.ZONE_X + M.SMALL_ICON + M.SMALL_GAP, M.ZONE_W - M.SMALL_ICON - M.SMALL_GAP
    r.zone = W.Text(r, T.FONT.text, textW)
    r.zone:SetPoint("TOPLEFT", textX, M.LINE1_Y)
    r.mapIcon = r:CreateTexture(nil, "ARTWORK")
    r.mapIcon:SetSize(M.SMALL_ICON, M.SMALL_ICON)
    r.mapIcon:SetPoint("RIGHT", r.zone, "LEFT", -M.SMALL_GAP, 0)
    r.mapIcon:SetTexture(M.MAP_ICON)
    r.last = W.Text(r, T.FONT.text, textW)
    r.last:SetPoint("TOPLEFT", textX, M.LINE2_Y)
    r.clockIcon = r:CreateTexture(nil, "ARTWORK")
    r.clockIcon:SetSize(M.SMALL_ICON, M.SMALL_ICON)
    r.clockIcon:SetPoint("RIGHT", r.last, "LEFT", -M.SMALL_GAP, 0)
    r.clockIcon:SetTexture(M.CLOCK_ICON)
    -- two lines of boxes: the main professions (two, wide: their names are long), under them the
    -- secondary ones (three)
    r.boxes = {}
    for line = 1, 2 do
        local n, w = line == 1 and M.MAIN_BOXES or M.BOXES, line == 1 and M.MAIN_BOX_W or M.BOX_W
        for i = 1, n do
            local b = buildBox(r, w)
            b:SetPoint("TOPLEFT", M.PROF_X + (i - 1) * (w + M.BOX_GAP), M.BOX_Y - (line - 1) * (M.BOX_H + M.BOX_ROW_GAP))
            r.boxes[#r.boxes + 1] = b
        end
    end
    r:SetScript("OnEnter", rowTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self) openMenu(self) end)
end

local function fillRow(r, e)
    setClassIcon(r.classIcon, e.class)
    r.name:SetText(classColored(e.name, e.class))
    r.info:SetText(T.GREY .. infoText(e) .. "|r")
    r.zone:SetText(e.zone and ((e.online and "" or T.GREY) .. e.zone .. (e.online and "" or "|r")) or (T.GREY .. "-|r"))
    r.last:SetText(lastText(e))
    for _, b in ipairs(r.boxes) do
        b.prof = nil
        b:Hide()
    end
    local main, other = profLines(e.profs)
    for i, p in ipairs(main) do fillBox(r.boxes[i], p) end
    for i, p in ipairs(other) do fillBox(r.boxes[M.MAIN_BOXES + i], p) end
end

local function buildPage(parent)
    local f = W.Page(parent)
    page = f
    f:Bands({ "row" })
    f.class = W.Picker(f, M.CLASS_W, function(v)
        state().class = v or "all"
        ns.Refresh()
    end)
    f.prof = W.Picker(f, M.PROF_W, function(v)
        state().prof = v or "all"
        ns.Refresh()
    end)
    f.online = W.Toggle(f, function(on)
        state().online = on or nil
        ns.Refresh()
    end)
    f.onlineLabel = W.Text(f, T.FONT.text)
    f.onlineLabel:SetText(L["nur online"])
    f.onlineLabel:SetWidth(f.onlineLabel:GetStringWidth() + 2)
    W.Tooltip(f.online, L["nur online"], L["Zeigt nur Mitglieder, die gerade online sind."])
    f.search = W.SearchBox(f, M.SEARCH_W, function(text)
        query = text or ""
        ns.Refresh()
    end, L["Name suchen"])
    f:Place(1, { f.class, f.prof, f.online, { f.onlineLabel, gap = 4 } }, { f.search })
    f:Footer({ "data" })

    local cols = {}
    local heads = { name = L["Name"], level = L["Stufe"], zone = L["Ort##Mitglieder"], last = L["Zuletzt online"], prof = L["Berufe"] }
    for _, c in ipairs(M.COLS) do cols[#cols + 1] = { c[1], c[2], c[3], heads[c[1]] } end
    f.headFrame, f.heads = f:Columns(cols, { sort = function(key)
        local st = state()
        if st.sort == key then
            st.desc = (not st.desc) or nil
        else
            st.sort, st.desc = key, (key == "level" or key == "prof") or nil
        end
        ns.Refresh()
    end })
    for _, c in ipairs(cols) do W.Tooltip(f.heads[c[1]], c[4], L["Klicken sortiert, ein zweiter Klick dreht die Reihenfolge um."]) end
    f.list = f:List(M.ROWS, M.ROW_H, buildRow, fillRow)
    f.empty = f:Empty()
    return f
end

local function classValues(rows)
    local out, seen = { { value = "all", text = L["Alle Klassen"] } }, {}
    for _, e in ipairs(rows or {}) do
        if e.class ~= "" and not seen[e.class] then
            seen[e.class] = true
            out[#out + 1] = { value = e.class, text = className(e) or e.class }
        end
    end
    table.sort(out, function(a, b)
        if a.value == "all" or b.value == "all" then return a.value == "all" end
        return a.text < b.text
    end)
    return out
end

-- Every profession of the data (main ones first), else those the members have.
local function profValues(rows)
    local out, seen = { { value = "all", text = L["Alle Berufe"] } }, {}
    local skills = {}
    if Pr() and ns.HasData("PROFESSIONS") then
        for _, skill in ipairs(Pr().Skills()) do skills[#skills + 1] = skill end
    end
    for _, e in ipairs(rows or {}) do
        for _, p in ipairs(e.profs or {}) do skills[#skills + 1] = p.skill end
    end
    local main, other = {}, {}
    for _, skill in ipairs(skills) do
        if not seen[skill] then
            seen[skill] = true
            local e = { value = skill, text = profName(skill) }
            if secondary(skill) then other[#other + 1] = e else main[#main + 1] = e end
        end
    end
    for _, e in ipairs(main) do out[#out + 1] = e end
    for _, e in ipairs(other) do out[#out + 1] = e end
    return out
end

local function hasValue(values, v)
    for _, e in ipairs(values) do if e.value == v then return true end end
    return false
end

local function refresh(f)
    local st = state()
    local locked = ns.ChatLocked and ns.ChatLocked()
    local rows
    if locked and last then
        rows = last
    elseif inGuild() then
        rows = build()
        if rows then last = rows end
        if not rows or not askedAt or GetTime() - askedAt > 60 then
            askedAt = GetTime()
            if ns.RequestGuildRoster then ns.RequestGuildRoster() end
        end
    else
        last = nil
    end

    -- a saved choice the guild no longer has (a class, a profession) goes back to "all"
    local classes, profs = classValues(rows), profValues(rows)
    if rows and #rows > 0 then
        if not hasValue(classes, st.class) then st.class = "all" end
        if not hasValue(profs, st.prof) then st.prof = "all" end
    end
    f.class:SetValues(classes)
    f.class:SetValue(st.class)
    f.prof:SetValues(profs)
    f.prof:SetValue(st.prof)
    f.online:SetChecked(st.online == true)
    for key, b in pairs(f.heads) do
        local on = key == st.sort
        b.label:SetTextColor(on and 1 or T.GOLD[1], on and 1 or T.GOLD[2], on and 1 or T.GOLD[3])
    end

    if not rows then
        f.list:SetItems({})
        if inGuild() or locked then
            f.empty:Set(L["Gildenliste wird geladen"], L["Das Spiel schickt die Gildenliste gleich; dann stehen hier die Mitglieder."])
        else
            f.empty:Set(L["Keine Gilde"], L["Du bist in keiner Gilde."])
        end
        f.empty:Show()
        f.data:SetText("")
        return
    end
    local shown, n = filtered(rows, st)
    f.list:SetItems(shown)
    if #shown == 0 then
        f.empty:Set(L["Nichts gefunden"], L["Kein Mitglied passt zu den Filtern."])
        f.empty:Show()
    else
        f.empty:Hide()
    end
    local counts = n.shown == n.all and L["%d Mitglieder, %d online, %d mit Amisia"]:format(n.shown, n.online, n.amisia)
        or L["%d von %d Mitgliedern, %d online, %d mit Amisia"]:format(n.shown, n.all, n.online, n.amisia)
    if locked then counts = counts .. " · " .. L["Stand vor der Kampfsperre"] end
    f.data:SetText(counts)
end

ns.RegisterPanel{ key = "members", label = L["Mitglieder"], icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", order = 65,
    group = "guild", create = buildPage, refresh = refresh }

-- Opens the page.
function ns.ShowMembers() ns.ShowPage("members") end

---------------------------------------------------------------------------
-- Following the roster and the crafters, only while the page is shown
---------------------------------------------------------------------------
local function shown() return page ~= nil and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "members" end

-- The roster is built again at most every 10 s (Trust.lua): a change right after a build shows
-- after that gap, so one more refresh follows then.
local again = false
local function onRoster()
    if not shown() then return end
    ns.RefreshSoon()
    if again then return end
    again = true
    C_Timer.After(11, function()
        again = false
        if shown() then ns.RefreshSoon() end
    end)
end
for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED",
                         "CLUB_MEMBER_UPDATED", "CLUB_MEMBERS_UPDATED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
    ns.OnEvent(event, onRoster)
end
ns.Listen("CRAFTERS_CHANGED", function() if shown() then ns.RefreshSoon() end end)
ns.Listen("ALTS", function() if shown() then ns.RefreshSoon() end end)
