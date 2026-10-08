-- Awards: every hand-out of a raid for officers, to look through, change, delete and take back;
-- raiders see their own items. Changes apply on the click and land on the undo stack.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local GOLD = W.GOLD
local ROWS, ROW_H = 12, 22
local GREY = T.GREY
local KINDS = { "MS", "OS", "SR", "-" }
local MAX_SUGGEST = 3
local TO_TEXT = { bank = "Bank", de = L["Entzaubern"] }

local GetItemInfo = C_Item.GetItemInfo

local page
local chosenRaid        -- session id, "all", or nil for the default
local chosenId          -- id of the award in the edit panel
local query = ""

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- The raids newest first, the running recording in front.
local function ordered()
    local src, out, act = ns.Sessions(), {}, ns.Active()
    if act then out[1] = act end
    for i = #src, 1, -1 do
        if src[i] ~= act then out[#out + 1] = src[i] end
    end
    return out
end

local function byId(id)
    for _, s in ipairs(ns.Sessions()) do
        if s.id == id then return s end
    end
    return nil
end

-- "02.10." (English "Oct 2") from a raid's "2026-10-02".
local function shortDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    if not d then return tostring(iso or "?") end
    return ns.FmtDay(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
end

local function raidText(s)
    return ("%s%s, %s"):format(s == ns.Active() and "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:12:12:0:0|t " or "",
        s.zone or "?", shortDate(s.date))
end

-- The raid the page works on: the chosen one, else the recording, else the newest.
local function chosen()
    if chosenRaid == "all" then return nil, true end
    local s = chosenRaid and byId(chosenRaid)
    if not s then
        s = ordered()[1]
        chosenRaid = s and s.id or nil
    end
    return s, false
end

local function quality(id)
    local known = AmisiaDB and AmisiaDB.itemNames and AmisiaDB.itemNames[id]
    local q = known and known.q
    if not q or q == 0 then
        local _, _, iq = GetItemInfo(id)
        q = iq or q
    end
    return q or 0
end

local QCOLOR = { [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80" }
local function itemText(id)
    return ("|cff%s%s|r"):format(QCOLOR[quality(id)] or "ffffff", ns.ItemName(id))
end

local function itemLink(id)
    local _, link = GetItemInfo(id)
    return link or ("item:" .. tostring(id))
end

-- Puts a link into the chat the way the client does (ChatFrameUtil.InsertLink).
local function insertLink(link)
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        return ChatFrameUtil.InsertLink(link)
    end
end

-- The member record of a name: the exact spelling, else the same character by ns.SameName.
-- known is true only for the exact (case-insensitive) spelling.
local function memberOf(s, name)
    local lower = tostring(name or ""):lower()
    for key, m in pairs(s.members or {}) do
        if key:lower() == lower then return m, true end
    end
    for key, m in pairs(s.members or {}) do
        if ns.SameName(key, name) then return m, false end
    end
    return nil, false
end

local function classColor(m)
    local c = m and m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    return c and c.colorStr or "ffffffff"
end

local function winnerText(s, a)
    if a.to == "bank" or a.to == "de" then
        local who = (a.name and a.name ~= "-") and (" (" .. a.name .. ")") or ""
        return GREY .. TO_TEXT[a.to] .. who .. "|r"
    end
    local m, known = memberOf(s, a.name)
    return ("|c%s%s|r%s"):format(classColor(m), a.name, known and "" or " |cffe2b857?|r")
end

local function matches(s, a, q)
    if q == "" then return true end
    local parts = { a.name, ns.ItemName(a.item), a.src, a.note }
    for _, p in ipairs(parts) do
        if type(p) == "string" and p:lower():find(q, 1, true) then return true end
    end
    return false
end

-- The rows of the list: { s, a } for every living award of the chosen raid, or of all raids
-- newest first, that the search leaves.
local function entries()
    local s, all = chosen()
    local raids = all and ordered() or { s }
    local out, q = {}, query:lower()
    for _, r in ipairs(raids) do
        if r then
            for _, a in ipairs(r.awards or {}) do
                if matches(r, a, q) then out[#out + 1] = { s = r, a = a } end
            end
        end
    end
    return out, all
end

-- Names to pick a winner from: the raid's members, in the recording also the group, merged by
-- ns.SameName and sorted.
local function winnerNames(s)
    local out = {}
    local function add(name)
        name = ns.FullName(ns.Plain(name))
        if not name then return end
        for i, o in ipairs(out) do
            if ns.SameName(o, name) then
                if #name > #o then out[i] = name end
                return
            end
        end
        out[#out + 1] = name
    end
    for name in pairs(s.members or {}) do add(name) end
    if s == ns.Active() then
        for i = 1, GetNumGroupMembers() or 0 do add((GetRaidRosterInfo(i))) end
    end
    table.sort(out)
    local values = {}
    for _, n in ipairs(out) do values[#values + 1] = { value = n, text = n } end
    return values
end

-- The raid an addition goes to: the chosen one, with "Alle Raids" the recording or the newest.
local function targetRaid()
    local s = chosen()
    return s or ordered()[1]
end

local function editTarget()
    local s, all = chosen()
    if not chosenId then return nil end
    if all then
        for _, r in ipairs(ordered()) do
            local a, _, inGone = ns.FindAward(r, chosenId)
            if a and not inGone then return r, a end
        end
        return nil
    end
    if not s then return nil end
    local a, _, inGone = ns.FindAward(s, chosenId)
    if a and not inGone then return s, a end
    return nil
end

local function edit(fields)
    local s, a = editTarget()
    if not s then return end
    local ok, why = ns.EditAward(s, a.id, fields)
    if not ok and why then ns.msg(why) end
end

-- A note typed into the edit panel but not committed yet belongs to the award it was typed for:
-- before another award is chosen it is committed (keep) or, before a deletion, thrown away.
local function settleNote(O, keep)
    local box = O and O.edit and O.edit.note
    if not box or not box:HasFocus() then return end
    if keep then
        box:ClearFocus()
    else
        local escape = box:GetScript("OnEscapePressed")
        if escape then escape(box) else box:ClearFocus() end
    end
end

---------------------------------------------------------------------------
-- Officer view
---------------------------------------------------------------------------
-- the columns of the officer's list (590 wide, its bar beside it)
local OFFICER_COLS = { { "time", 6, 44, L["Zeit"] }, { "itemText", 52, 200, "Item" }, { "name", 256, 140, L["Gewinner"] },
    { "kind", 400, 30, L["Art"] }, { "plus", 434, 24, "+1" }, { "src", 462, 124, L["Quelle"] } }

local function buildOfficer(parent)
    local O = W.Page(parent, { view = true, top = 0, head = true })
    -- the head row: raid and search, add and undo at the right; under it the counts and the sync state
    O:Bands({ "row", "line" })
    O.raid = W.Picker(O, 210, function(v)
        settleNote(O, true)
        chosenRaid = v
        chosenId = nil
        ns.Refresh()
    end)
    -- the search box shows its hint while empty
    O.search = W.SearchBox(O, 172, function(text)
        query = (text or ""):match("^%s*(.-)%s*$")
        ns.Refresh()
    end, L["Name oder Item"])
    O.undo = W.Button(O, L["Rückgängig"], 100, function()
        local text = ns.UndoAward()
        ns.msg(text and L["Rückgängig: %s."]:format(text) or L["Nichts rückgängig zu machen."])
        ns.Refresh()
    end)
    O.undo:SetScript("OnEnter", function(self)
        local label = ns.UndoLabel()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Rückgängig"], 1, 0.82, 0)
        GameTooltip:AddLine(label or L["Nichts rückgängig zu machen."], 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    O.undo:SetScript("OnLeave", function() GameTooltip:Hide() end)
    O.add = W.Button(O, L["Hinzufügen##Knopf"], 100, function()
        local s = targetRaid()
        if not s then
            ns.msg(L["Noch kein Raid aufgezeichnet."])
        elseif ns.ShowAwardDialog then
            ns.ShowAwardDialog(nil, s)
        else
            ns.msg(L["Vergaben von Hand: /amisia award <Name> <Item-Link oder ID> [ms|os|sr]"])
        end
    end)
    W.FitChip(O.add, 100)
    W.FitChip(O.undo, 100)
    O:Place(1, { O.raid, O.search }, { O.add, O.undo })

    -- the counts on the left (up to 330 px), the sync state right-aligned in the space the counts
    -- leave (fillSync sizes it), with its details as tooltip
    O.head = W.Text(O, T.FONT.hint, 330)
    O.sync = W.Text(O, T.FONT.hint, 260)
    O.sync:SetJustifyH("RIGHT")
    O:Place(2, { O.head }, { O.sync })
    O.syncHit = CreateFrame("Frame", nil, O)
    O.syncHit:SetSize(260, T.LAYOUT.LINE_H)
    O.syncHit:SetPoint("RIGHT", O.sync, "RIGHT", 0, 0)
    O.syncHit:EnableMouse(true)
    O.syncHit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["Abgleich des Raid-Stands"], 1, 0.82, 0)
        for _, l in ipairs(self.tip or {}) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    O.syncHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local _, heads = O:Columns(OFFICER_COLS)
    -- the plus-one, or in a DKP or EPGP raid the award's cost
    O.plusHead = heads.plus

    O.list = O:List(ROWS, ROW_H, function(r)
        r.sel = W.SelectBar(r)
        W.Cells(r, OFFICER_COLS)
        r:SetScript("OnClick", function(self)
            local e = self.item
            if not e then return end
            if IsShiftKeyDown and IsShiftKeyDown() then
                insertLink(itemLink(e.a.item))
                return
            end
            if e.a.id ~= chosenId then settleNote(O, true) end
            chosenId = e.a.id
            ns.Refresh()
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not e or not GameTooltip.SetHyperlink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(e.a.item))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        local a = e.a
        r.time:SetText(O.list.all and ns.FmtDay(a.t or 0) or date("%H:%M", a.t or 0))
        r.itemText:SetText(itemText(a.item))
        -- a change of this officer the keeper has not confirmed yet
        local waiting = ns.SyncWaiting and ns.SyncWaiting(e.s, a.id)
        r.name:SetText(winnerText(e.s, a) .. (waiting and (GREY .. L[" · wartet|r"]) or ""))
        r.kind:SetText(a.kind or "-")
        local pts = ns.PointsSession and ns.PointsSession(e.s)
        if pts then
            local c = ns.AwardPoints(e.s, a.id)
            r.plus:SetText(c and tostring(c.n) or "")
        else
            r.plus:SetText((a.kind == "MS" and (a.to == nil or a.to == "player")) and tostring(ns.PlusCount(a.name)) or "")
        end
        r.src:SetText(a.src or "?")
        if a.id == chosenId then r.sel:Show() else r.sel:Hide() end
    end)
    O.empty = O:Empty()

    -- the edit panel under the list, over the full width again (past the list's bar)
    local E = CreateFrame("Frame", nil, O)
    E:SetPoint("TOPLEFT", O.list, "BOTTOMLEFT", 0, -6)
    E:SetPoint("TOPRIGHT", O.list, "BOTTOMRIGHT", 12, -6)
    E:SetHeight(120)
    E.title = W.Text(E, T.FONT.title, 590)
    E.title:SetPoint("TOPLEFT", 6, -2)
    local lab = W.Text(E, T.FONT.text, 60)
    lab:SetPoint("TOPLEFT", 6, -26)
    lab:SetText(L["Gewinner"])
    E.winner = W.Picker(E, 150, function(v)
        edit({ name = v, to = "player" })
    end)
    E.winner:SetPoint("LEFT", lab, "RIGHT", 4, 0)
    local artLab = W.Text(E, T.FONT.text, 24)
    artLab:SetPoint("LEFT", E.winner, "RIGHT", 12, 0)
    artLab:SetText(L["Art"])
    E.kinds = {}
    local prev = artLab
    for i, k in ipairs(KINDS) do
        local chip = W.Chip(E, k, 32, function() edit({ kind = k }) end)
        chip:SetPoint("LEFT", prev, "RIGHT", i == 1 and 4 or 3, 0)
        E.kinds[k] = chip
        prev = chip
    end
    local noteLab = W.Text(E, T.FONT.text, 32)
    noteLab:SetPoint("LEFT", prev, "RIGHT", 12, 0)
    noteLab:SetText(L["Notiz"])
    -- up to 6 px before the panel's right edge (602 px of content)
    E.note = W.LineEdit(E, 150, function(text) edit({ note = text }) end)
    E.note:SetPoint("LEFT", noteLab, "RIGHT", 4, 0)

    E.bank = W.Button(E, "Bank", 90, function()
        local _, a = editTarget()
        if not a then return end
        if a.to == "bank" then E.winner:Open() else edit({ to = "bank" }) end
    end)
    E.bank:SetPoint("TOPLEFT", 6, -52)
    E.de = W.Button(E, L["Entzaubern"], 90, function()
        local _, a = editTarget()
        if not a then return end
        if a.to == "de" then E.winner:Open() else edit({ to = "de" }) end
    end)
    E.de:SetPoint("LEFT", E.bank, "RIGHT", 6, 0)
    E.del = W.Button(E, L["Löschen##Knopf"], 90, function()
        local s, a = editTarget()
        if not s then return end
        settleNote(O, false)
        local ok, why = ns.DeleteAward(s, a.id)
        if not ok and why then ns.msg(why) end
        chosenId = nil
        ns.Refresh()
    end)
    E.del:SetPoint("LEFT", E.de, "RIGHT", 6, 0)
    -- DKP or EPGP: the award's cost
    E.ptsLabel = W.Text(E, T.FONT.text, 30)
    E.ptsLabel:SetPoint("LEFT", E.del, "RIGHT", 12, 0)
    E.pts = W.LineEdit(E, 50, function(text)
        local s, a = editTarget()
        if not s then return end
        local c = ns.AwardPoints(s, a.id)
        local n = tonumber(text)
        if text == "" or (c and n == c.n) or (not c and not n) then return end
        local ok, why = ns.SetAwardPoints(s, a.id, n)
        if not ok and why then ns.msg(why) end
        ns.Refresh()
    end)
    E.pts:SetPoint("LEFT", E.ptsLabel, "RIGHT", 4, 0)
    E.pts:SetNumeric(true)
    E.pts:SetMaxLetters(6)
    E.status = W.Text(E, T.FONT.hint)
    E.status:SetPoint("LEFT", E.del, "RIGHT", 12, 0)
    E.status:SetJustifyH("RIGHT")
    E.status:SetPoint("RIGHT", -6, 0)

    E.hint = W.Text(E, T.FONT.text, 590)
    E.hint:SetPoint("TOPLEFT", 6, -80)
    E.chips = {}
    for i = 1, MAX_SUGGEST * 2 do
        local chip = W.Chip(E, "", 60)
        if i == 1 then chip:SetPoint("TOPLEFT", 6, -98) else chip:SetPoint("LEFT", E.chips[i - 1], "RIGHT", 4, 0) end
        chip:SetScript("OnClick", function(self)
            local s, a = editTarget()
            if not s or not self.target then return end
            if self.all then
                ns.RenameAwards(s, a.name, self.target)
            else
                edit({ name = self.target })
            end
        end)
        chip:Hide()
        E.chips[i] = chip
    end
    E:Hide()
    O.edit = E

    -- the conflict bar: in place of the name hint, also while no award is chosen; an inset with a
    -- gold ground that takes the click
    local B = W.Inset(O, "Button")
    B.fill(GOLD[1], GOLD[2], GOLD[3], 0.16)
    B:SetSize(602, 40)
    B:SetPoint("TOPLEFT", E, "TOPLEFT", 0, -80)
    B.text = W.Text(B, T.FONT.text, 590)
    B.text:SetPoint("TOPLEFT", 6, -5)
    B.mine = W.Text(B, T.FONT.text, 318)
    B.mine:SetPoint("BOTTOMLEFT", 6, 7)
    B.drop = W.Button(B, L["Verwerfen"], 90, function(self)
        local c = B.conflict
        if c then ns.SyncResolve(c.s, c.opid, false) end
        ns.Refresh()
    end)
    B.drop:SetPoint("BOTTOMRIGHT", -6, 2)
    B.take = W.Button(B, L["Meine übernehmen"], 130, function(self)
        local c = B.conflict
        if not c then return end
        local ok, why = ns.SyncResolve(c.s, c.opid, true)
        if not ok and why then ns.msg(why) end
        ns.Refresh()
    end)
    B.take:SetPoint("RIGHT", B.drop, "LEFT", -6, 0)
    B:SetScript("OnClick", function(self)
        local c = self.conflict
        if not c or not c.id then return end
        if c.id ~= chosenId then settleNote(O, true) end
        chosenId = c.id
        ns.Refresh()
    end)
    B:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["Konflikt"], 1, 0.82, 0)
        for _, l in ipairs(self.tip) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    B:SetScript("OnLeave", function() GameTooltip:Hide() end)
    B:Hide()
    O.conflict = B
    return O
end

-- The first n characters of a UTF-8 text, with three dots when it was longer.
local function cutText(t, n)
    local out, count = {}, 0
    for ch in tostring(t):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then return table.concat(out) .. "..." end
        out[count] = ch
    end
    return table.concat(out)
end

-- What a change does, in words: "an Vulo (OS)", "an die Bank", "Notiz ..." (f: the fields, a: the
-- award for what f leaves out). With short, a note is cut to 20 characters.
local function changeText(a, f, short)
    local parts = {}
    if f.name ~= nil or f.kind ~= nil or f.to ~= nil then
        local to = f.to or a.to
        if to == "bank" then
            parts[1] = L["an die Bank"]
        elseif to == "de" then
            parts[1] = L["zum Entzaubern"]
        else
            parts[1] = L["an %s (%s)"]:format(tostring(f.name or a.name or "?"), tostring(f.kind or a.kind or "-"))
        end
    end
    if f.note ~= nil then
        parts[#parts + 1] = (f.note and f.note ~= "") and L["Notiz \"%s\""]:format(short and cutText(f.note, 20) or f.note)
            or L["Notiz gelöscht"]
    end
    return #parts > 0 and table.concat(parts, ", ") or L["geändert"]
end

-- The bar of the first conflict of raid s, or hidden.
local function fillConflict(O, s)
    local B = O.conflict
    local list = (s and ns.SyncConflicts) and ns.SyncConflicts(s) or {}
    local c = list[1]
    if not c then
        B.conflict, B.tip = nil, nil
        B:Hide()
        return
    end
    B.conflict = { s = s, opid = c.opid, id = c.id }
    local a = c.id and ns.FindAward(s, c.id) or {}
    local mine = type(c.mine) == "table" and c.mine or {}
    local n = #list > 1 and L[" (1 von %d)"]:format(#list) or ""
    local by = tostring(c.by or "?")
    -- the bar shows notes cut short; the tooltip (B.tip) has both sentences in full
    local function sentences(short)
        local keeper
        if c.why == "GONE" then
            keeper = L["Konflikt%s: %s hat diese Vergabe gelöscht."]:format(n, by)
        else
            -- the keeper's state of what the own change touched
            local theirs = {}
            for _, k in ipairs({ "name", "kind", "note", "to" }) do
                if mine[k] ~= nil or mine.deleted then theirs[k] = a[k] == nil and false or a[k] end
            end
            if mine.deleted then theirs.note = nil end
            keeper = L["Konflikt%s: %s hat diese Vergabe zuerst geändert: %s."]:format(n, by, changeText(a, theirs, short))
        end
        return keeper, L["Deine Änderung: %s."]:format(mine.deleted and L["gelöscht"] or changeText(a, mine, short))
    end
    local keeper, own = sentences(true)
    B.text:SetText(keeper)
    B.mine:SetText(own)
    B.tip = { sentences(false) }
    if c.why == "GONE" then
        B.take:SetText(L["Wiederherstellen und ändern"])
        B.take:SetWidth(170)
    else
        B.take:SetText(L["Meine übernehmen"])
        B.take:SetWidth(130)
    end
    B:Show()
end

local SYNC_COLOR = { green = { 0.31, 0.82, 0.42 }, gold = { GOLD[1], GOLD[2], GOLD[3] }, grey = { 0.56, 0.53, 0.64 } }

-- The sync line of the head: the state of the chosen raid ("Alle Raids": none).
local function fillSync(O, s, all)
    -- the counts keep what they need (at most 330 px, measured at full width); the sync line and
    -- its hit frame take the rest of the 590 px line after a 12 px gap
    O.head:SetWidth(330)
    -- rounded up, so the counts never lose their last letter
    local hw = math.min(330, math.ceil(O.head:GetStringWidth() or 0))
    O.head:SetWidth(hw)
    local w = 590 - hw - 12
    if all or not s or not ns.SyncStatus then
        O.sync:SetText("")
        O.sync.color = nil
        O.syncHit.tip = nil
        return
    end
    local text, color, tip = ns.SyncStatus(s)
    O.sync:SetWidth(w)
    O.syncHit:SetWidth(w)
    O.sync:SetText(text)
    O.sync.color = color
    local c = SYNC_COLOR[color] or SYNC_COLOR.grey
    O.sync:SetTextColor(c[1], c[2], c[3])
    O.syncHit.tip = tip
end

local function fillEdit(E)
    local s, a = editTarget()
    if not s then
        chosenId = nil
        E:Hide()
        return
    end
    E:Show()
    E.title:SetText(("%s · %s · %s"):format(itemText(a.item), date("%H:%M", a.t or 0), a.src or "?"))
    E.winner:SetValues(winnerNames(s), L["Anderer Name"])
    E.winner:SetValue(a.to == "player" and a.name or ((a.name and a.name ~= "-") and a.name or nil))
    for _, k in ipairs(KINDS) do E.kinds[k]:SetOn(a.kind == k) end
    if not E.note:HasFocus() then E.note:SetText(a.note or "") end
    -- the cost of a player's award in a DKP or EPGP raid; the status moves behind it
    local p = ns.PointsSession and ns.PointsSession(s)
    local ptsOn = p ~= nil and a.to == "player"
    E.ptsLabel:SetShown(ptsOn)
    E.pts:SetShown(ptsOn)
    if ptsOn then
        E.ptsLabel:SetText(p.sys == "epgp" and "GP" or "DKP")
        local c = ns.AwardPoints(s, a.id)
        if not E.pts:HasFocus() then E.pts:SetText(c and tostring(c.n) or "") end
    end
    E.status:SetPoint("LEFT", ptsOn and E.pts or E.del, "RIGHT", 12, 0)
    E.bank:SetText(a.to == "bank" and L["An Spieler"] or "Bank")
    E.de:SetText(a.to == "de" and L["An Spieler"] or L["Entzaubern"])
    local parts = {}
    if a.edited then
        parts[#parts + 1] = L["geändert %s%s"]:format(date("%H:%M", a.edited), a.orig and L[", zuerst an %s"]:format(a.orig) or "")
    elseif a.orig then
        parts[#parts + 1] = L["zuerst an %s"]:format(a.orig)
    end
    -- the keeper took this change from an officer's wish
    local by = type(s.sync) == "table" and type(s.sync.by) == "table" and s.sync.by[a.id]
    if type(by) == "string" then parts[#parts + 1] = L["geändert von %s"]:format(by) end
    if a.manual then parts[#parts + 1] = L["von Hand eingetragen"] end
    if a.note then parts[#parts + 1] = L["Notiz %d/60"]:format(#a.note) end
    E.status:SetText(table.concat(parts, " · "))
    -- the name hint: a player's name outside the members, with the members it may mean
    local _, known = memberOf(s, a.name)
    local chips = E.chips
    if a.to ~= "player" or known then
        E.hint:Hide()
        for _, c in ipairs(chips) do c:Hide() end
        return
    end
    local sug = ns.NameSuggestions(s, a.name)
    local same = 0
    for _, o in ipairs(s.awards or {}) do
        if o.name == a.name then same = same + 1 end
    end
    E.hint:Show()
    E.hint:SetText(L["Hinweis: \"%s\" steht nicht in der Anwesenheit.%s"]:format(a.name, #sug > 0 and L[" Gemeint:"] or ""))
    local i = 0
    for _, name in ipairs(sug) do
        if i >= #chips then break end
        i = i + 1
        local c = chips[i]
        c.label:SetText(name)
        W.FitChip(c)
        c.target, c.all = name, false
        c:SetOn(false)
        c:Show()
        if same > 1 and i < #chips then
            i = i + 1
            local all = chips[i]
            all.label:SetText(L["alle %d"]:format(same))
            W.FitChip(all)
            all.target, all.all = name, true
            all:SetOn(false)
            all:Show()
        end
    end
    for j = i + 1, #chips do chips[j]:Hide() end
end

local EXPORT_TEXT = { new = L["Raid nicht exportiert"], changed = L["Raid geändert seit dem Export"], done = L["Raid exportiert"] }

local function refreshOfficer(O)
    local values = {}
    for _, s in ipairs(ordered()) do values[#values + 1] = { value = s.id, text = raidText(s) } end
    values[#values + 1] = { value = "all", text = L["Alle Raids"] }
    O.raid:SetValues(values)
    local s, all = chosen()
    O.raid:SetValue(all and "all" or (s and s.id) or nil)
    if not O.search:HasFocus() then O.search:SetText(query) end
    local list = entries()
    O.list.all = all
    -- the column of the plus-one shows the cost in a DKP or EPGP raid
    local pts = s and ns.PointsSession and ns.PointsSession(s)
    O.plusHead:SetText(pts and (pts.sys == "epgp" and "GP" or "DKP") or "+1")
    O.list:SetItems(list)
    if #list == 0 then
        O.empty:Set(L["Keine Vergaben"], query ~= "" and L["Kein Eintrag passt zu den Filtern."]
            or ((s or all) and L["Master Loot hat nichts vergeben."] or L["Noch kein Raid aufgezeichnet."]))
    end
    O.empty:SetShown(#list == 0)
    -- the head line: counts and the export state
    local n, bank, de, raids = 0, 0, 0, {}
    for _, e in ipairs(list) do
        n = n + 1
        if e.a.to == "bank" then bank = bank + 1 elseif e.a.to == "de" then de = de + 1 end
        raids[e.s] = true
    end
    local parts = { L["%d Vergaben"]:format(n) }
    if bank > 0 then parts[#parts + 1] = L["%d Bank"]:format(bank) end
    if de > 0 then parts[#parts + 1] = L["%d Entzaubern"]:format(de) end
    if all then
        local count = 0
        for _ in pairs(raids) do count = count + 1 end
        parts[#parts + 1] = L["in %d Raids"]:format(count)
    elseif s then
        parts[#parts + 1] = EXPORT_TEXT[ns.ExportState(s)] or ""
    else
        parts = { L["Noch kein Raid aufgezeichnet."] }
    end
    -- conflicts of the running raid while another raid (or all) is shown: a gold mark right after
    -- the count, so it is not cut off
    local act = ns.Active()
    local actConflicts = (act and act ~= s and ns.SyncConflicts) and #ns.SyncConflicts(act) or 0
    if actConflicts > 0 then
        table.insert(parts, 2, L["|cffe2b857%d %s im laufenden Raid|r"]:format(actConflicts,
            actConflicts == 1 and L["Konflikt"] or L["Konflikte"]))
    end
    O.head:SetText(table.concat(parts, " · "))
    O.undo:SetEnabled(ns.UndoLabel() ~= nil)
    fillSync(O, s, all)
    fillEdit(O.edit)
    fillConflict(O, not all and s or nil)
    -- the bar takes the place of the name hint
    if O.conflict:IsShown() then
        O.edit.hint:Hide()
        for _, c in ipairs(O.edit.chips) do c:Hide() end
    end
end

---------------------------------------------------------------------------
-- Raider view
---------------------------------------------------------------------------
-- My items of every saved raid: the loot lines with my name and my own awards, one row per
-- item and raid, newest raid first.
local function myItems()
    local me = ns.UnitFullName("player")
    local out = {}
    if not me then return out end
    for _, s in ipairs(ordered()) do
        local seen = {}
        local function add(item, kind)
            local row = seen[item]
            if row then
                if kind and kind ~= "-" then row.kind = kind end
                return
            end
            row = { s = s, item = item, kind = kind }
            seen[item] = row
            out[#out + 1] = row
        end
        for _, l in ipairs(s.items or {}) do
            if ns.SameName(l.name, me) then add(l.item, nil) end
        end
        for _, a in ipairs(s.awards or {}) do
            if (a.to == nil or a.to == "player") and ns.SameName(a.name, me) then add(a.item, a.kind) end
        end
    end
    return out
end

-- The raider's view of the page (window state settings.awards.raiderView): "mine" or "all".
local function raiderView()
    local st = AmisiaDB and AmisiaDB.settings
    local v = st and type(st.awards) == "table" and st.awards.raiderView
    return v == "all" and "all" or "mine"
end

local function setRaiderView(v)
    local st = AmisiaDB and AmisiaDB.settings
    if not st then return end
    st.awards = type(st.awards) == "table" and st.awards or {}
    st.awards.raiderView = v
    ns.Refresh()
end

-- The raids with a snapshot of the loot lead, newest first.
local function syncedRaids()
    local out = {}
    for _, s in ipairs(ordered()) do
        if type(s.sync) == "table" and type(s.sync.keeper) == "string" then out[#out + 1] = s end
    end
    return out
end

-- The keeper's plus-one of a name in raid s, or nil.
local function keeperPlus(s, name)
    local p = type(s.sync) == "table" and type(s.sync.plus) == "table" and type(s.sync.plus.n) == "table" and s.sync.plus.n
    if not p then return nil end
    for who, n in pairs(p) do
        if ns.SameName(who, name) then return tonumber(n) or 0 end
    end
    return 0
end

-- A winner for raiders: bank and disenchant grey, the own name gold, others in their class colour.
local function raiderWinner(s, a)
    if a.to == "bank" or a.to == "de" then
        local who = (a.name and a.name ~= "-") and (" (" .. a.name .. ")") or ""
        return GREY .. TO_TEXT[a.to] .. who .. "|r"
    end
    local name = tostring(a.name or "?")
    if ns.SameName(name, ns.UnitFullName("player")) then return "|cffe2b857" .. name .. "|r" end
    return ("|c%s%s|r"):format(classColor((memberOf(s, name))), name)
end

local chosenAll   -- session id of the raid in "Alle Vergaben"

local ALL_COLS = { { "time", 6, 54, L["Zeit"] }, { "itemText", 64, 226, "Item" }, { "name", 294, 176, L["Gewinner"] },
    { "kind", 474, 46, L["Art"] }, { "plus", 524, 36, "+1" } }
local MINE_COLS = { { "date", 6, 60, L["Datum"] }, { "itemText", 70, 230, "Item" }, { "zone", 306, 200, "Raid" },
    { "kind", 510, 40, L["Art"] } }

local function buildAll(R)
    -- "Alle Vergaben": the raid, its awards, the loot lead's state in the footer
    local A = W.Page(R, { view = true, top = R.top })
    A:Bands({ "row" })
    A.raid = W.Picker(A, 240, function(v)
        chosenAll = v
        ns.Refresh()
    end)
    A:Place(1, { A.raid })
    A:Footer({ "foot" })
    local _, cols = A:Columns(ALL_COLS)
    A.cols = { time = cols.time, item = cols.itemText, name = cols.name, kind = cols.kind, plus = cols.plus }
    A.list = A:List(ROWS, ROW_H, function(r)
        W.Cells(r, ALL_COLS)
        r:SetScript("OnClick", function(self)
            local e = self.item
            if e and IsShiftKeyDown and IsShiftKeyDown() then insertLink(itemLink(e.a.item)) end
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not e or not GameTooltip.SetHyperlink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(e.a.item))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        -- read-only, never a note: raiders get the awards without them
        local a = e.a
        r.time:SetText(date("%H:%M", a.t or 0))
        r.itemText:SetText(itemText(a.item))
        r.name:SetText(raiderWinner(e.s, a))
        r.kind:SetText((a.kind and a.kind ~= "-") and a.kind or "")
        local plus = (a.kind == "MS" and (a.to == nil or a.to == "player")) and keeperPlus(e.s, a.name) or nil
        r.plus:SetText(plus and tostring(plus) or "")
    end)
    A.empty = A:Empty()
    A.empty:Set(L["Keine Vergaben"], L["Für diesen Raid hat Amisia noch keine Vergaben von der Lootleitung bekommen."])
    A:Hide()
    return A
end

local function fillAll(A, raids)
    local values, s = {}, nil
    for _, r in ipairs(raids) do
        values[#values + 1] = { value = r.id, text = raidText(r) }
        if r.id == chosenAll then s = r end
    end
    s = s or raids[1]
    chosenAll = s and s.id or nil
    A.raid:SetValues(values)
    A.raid:SetValue(chosenAll)
    local rows = {}
    for _, a in ipairs(s and s.awards or {}) do rows[#rows + 1] = { s = s, a = a } end
    A.list:SetItems(rows)
    if #rows == 0 then A.empty:Show() else A.empty:Hide() end
    local sync = s and s.sync
    A.foot:SetText(sync and L["Stand von %s, %s · Notizen sehen nur Offiziere."]:format(tostring(sync.keeper), date("%H:%M", tonumber(sync.at) or 0)) or "")
end

local function buildRaider(parent)
    local R = W.Page(parent, { view = true, top = 0, head = true })
    -- the head row: what is shown, and the chips to switch (once the loot lead sent a raid)
    R:Bands({ "row" })
    R.title = W.Text(R, T.FONT.title, 160)
    R.title:SetText(L["Deine Items"])
    R.mineChip = W.Chip(R, L["Deine Items"], 100, function() setRaiderView("mine") end)
    R.allChip = W.Chip(R, L["Alle Vergaben"], 110, function() setRaiderView("all") end)
    W.FitChip(R.mineChip, 100)
    W.FitChip(R.allChip, 110)
    R:Place(1, { R.title, R.mineChip, R.allChip })
    -- "Deine Items": the own loot of every saved raid
    local M = W.Page(R, { view = true, top = R.top })
    R.mine = M
    M:Footer({ "note" })
    R.text = M.note
    M:Columns(MINE_COLS)
    R.list = M:List(ROWS, ROW_H, function(r)
        W.Cells(r, MINE_COLS)
        r:SetScript("OnClick", function(self)
            local e = self.item
            if e and IsShiftKeyDown and IsShiftKeyDown() then insertLink(itemLink(e.item)) end
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if not e or not GameTooltip.SetHyperlink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(e.item))
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        r.date:SetText(shortDate(e.s.date))
        r.itemText:SetText(itemText(e.item))
        r.zone:SetText(e.s.zone or "?")
        r.kind:SetText((e.kind and e.kind ~= "-") and e.kind or "")
    end)
    R.empty = M:Empty()
    R.empty:Set(L["Noch keine Items"], L["Was du in aufgezeichneten Raids bekommst, steht hier."])
    R.text:SetText(L["Vergaben anderer siehst du auf der Amisia-Loot-Seite."])
    -- "Alle Vergaben": every award of a raid as the loot lead sent it
    R.all = buildAll(R)
    return R
end

local function refreshRaider(R)
    local raids = syncedRaids()
    local any = #raids > 0
    local view = (any and raiderView() == "all") and "all" or "mine"
    R.mineChip:SetShown(any)
    R.allChip:SetShown(any)
    R.mineChip:SetOn(view == "mine")
    R.allChip:SetOn(view == "all")
    R.title:SetText(view == "all" and L["Alle Vergaben"] or L["Deine Items"])
    if view == "all" then
        R.mine:Hide()
        R.all:Show()
        fillAll(R.all, raids)
        return
    end
    R.all:Hide()
    R.mine:Show()
    local mine = myItems()
    R.list:SetItems(mine)
    R.empty:SetShown(#mine == 0)
    R.text:SetText(any and L["Alle Vergaben deines Raids siehst du unter Alle Vergaben, ältere auf der Amisia-Loot-Seite."]
        or L["Vergaben anderer siehst du auf der Amisia-Loot-Seite."])
end

---------------------------------------------------------------------------
-- The page, the card and the commands
---------------------------------------------------------------------------
function ns.AwardsPageFrame() return page end

-- Opens the page on one raid.
function ns.ShowAwards(sessionId)
    if sessionId then
        settleNote(page and page.officer, true)
        chosenRaid = sessionId
        chosenId = nil
    end
    ns.ShowPage("awards")
end

ns.RegisterPanel{ key = "awards", label = L["Vergaben"], icon = "Interface\\Icons\\INV_Misc_Bag_08", order = 35, group = "raid",
    create = function(parent)
        local f = W.Page(parent)
        page = f
        f.officer = buildOfficer(f)
        f.raider = buildRaider(f)
        f.officer:Hide()
        f.raider:Hide()
        return f
    end,
    refresh = function(f)
        if ns.IsOfficerView() then
            f.raider:Hide()
            f.officer:Show()
            refreshOfficer(f.officer)
        else
            f.officer:Hide()
            f.raider:Show()
            refreshRaider(f.raider)
        end
    end }

-- A new sync state: the page (or the overview with its card) builds again, at most once a second,
-- only while shown. Snapshots fire DATA_CHANGED themselves.
local syncPending, syncAt
ns.Listen("SYNC_STATE", function()
    if syncPending then return end
    local cur = ns.CurrentPage and ns.CurrentPage()
    if cur ~= "awards" and cur ~= "overview" then return end
    syncPending = true
    C_Timer.After(syncAt and math.max(0, 1 - (GetTime() - syncAt)) or 0, function()
        syncPending = false
        syncAt = GetTime()
        local now = ns.CurrentPage and ns.CurrentPage()
        if now == "awards" or now == "overview" then ns.Refresh() end
    end)
end)

ns.RegisterCard{ key = "awards", order = 40, fill = function(c)
    local all = ns.Sessions()
    local last = all[#all]
    local officer = ns.IsOfficerView()
    c.title:SetText(officer and L["Vergaben letzte Nacht"] or L["Deine Items letzte Nacht"])
    if not last then
        c.line1:SetText(L["Keine"])
        return
    end
    local night = {}
    for _, s in ipairs(all) do
        if s.date == last.date then night[#night + 1] = s end
    end
    if not officer then
        local n = 0
        for _, e in ipairs(myItems()) do
            if e.s.date == last.date then n = n + 1 end
        end
        c.line1:SetText(L["%d Items am %s"]:format(n, last.date))
        -- with a snapshot of the loot lead: the own plus-one as he counts it
        local me = ns.UnitFullName("player")
        for i = #night, 1, -1 do
            local plus = me and keeperPlus(night[i], me)
            if plus then
                c.line2:SetText(L["Dein Plus-Eins: %d"]:format(plus))
                break
            end
        end
        c:SetAction(L["Öffnen"], function() ns.ShowPage("awards") end)
        return
    end
    local n, bank, de, pending = 0, 0, 0, false
    for _, s in ipairs(night) do
        for _, a in ipairs(s.awards or {}) do
            n = n + 1
            if a.to == "bank" then bank = bank + 1 elseif a.to == "de" then de = de + 1 end
        end
        if ns.ExportState(s) ~= "done" then pending = true end
    end
    c.line1:SetText(L["%d Items am %s"]:format(n, last.date))
    local parts = {}
    if bank > 0 then parts[#parts + 1] = L["%d Bank"]:format(bank) end
    if de > 0 then parts[#parts + 1] = L["%d Entzaubern"]:format(de) end
    if pending then parts[#parts + 1] = L["noch nicht exportiert"] end
    if #parts > 0 then
        local text = table.concat(parts, " · ")
        c.line2:SetText(bank + de > 0 and L["davon %s"]:format(text) or text)
    else
        c.line2:SetText(n == 0 and L["Master Loot hat nichts vergeben."] or "")
    end
    c:SetAction(L["Öffnen"], function() ns.ShowAwards(last.id) end)
end }

ns.RegisterSlash("vergaben", { en = "awards", desc = L["Seite Vergaben öffnen"], run = function() ns.ShowPage("awards") end })

