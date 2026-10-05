-- Amisia guild wishes: the website's wishlist pasted in as text ("Copy for the addon" on the
-- Wishlist tab), so officers see at the loot who wished for an item: a tooltip line, a "W" on the
-- loot window and the group loot roll frames, wishers first in the award dialog. Wishes change no
-- rule: the roll order (SR, MS, OS, +1) stays as it is. Stored in AmisiaDB.bis.guild.
--
-- The pasted text is untrusted: escape codes and bars are stripped, every field is checked and
-- capped, and no link is ever built from it.
local ADDON, ns = ...

local HEAD_FAIL = "Das ist keine Wunschliste der Amisia-Seite."
local MAX_LINES = 2000      -- lines read, the head included
local MAX_LINE = 200        -- bytes of one line that are looked at
local NAME_MAX = 48
local NOTE_MAX = 40
local MAX_ID = 9999999
local OLD_DAYS = 14
local TIP_NAMES = 8         -- names in the tooltip line, the rest counted
local GAME_NAMES = { tbc = "TBC Anniversary", forever = "WoW Forever", classic = "Classic Era", hardcore = "Classic Hardcore",
    sod = "Season of Discovery", mop = "Mists of Pandaria Classic" }
local PRIO_TIP = { [3] = " (hoch)", [1] = " (niedrig)" }
local PRIO_TEXT = { [3] = "hoch", [2] = "mittel", [1] = "niedrig" }
local BLUE = { 0.55, 0.75, 1 }

---------------------------------------------------------------------------
-- Parser and storage
---------------------------------------------------------------------------

-- Pasted text without escape codes (colours, links, textures, atlases) and without any bar left.
local function stripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|", "")
    return s
end

local function clientGame() return ns.IsForever() and "forever" or "tbc" end

local function gameName(key)
    return GAME_NAMES[key] or stripCodes(tostring(key)):sub(1, 24)
end

-- A list name: "_" is the space of the site's text; no digits, no control characters, not too long.
local function cleanName(raw)
    local name = ns.FullName((raw:gsub("_", " ")))
    if not name or #name > NAME_MAX or name:find("[%d%c]") then return nil end
    return name
end

local function byPrio(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.name < b.name
end

-- Reads the website's text:
--   #AMISIA-WL 1 <game> <yyyy-mm-dd>
--   W <itemID> <prio 1-3> <name with _> [<note>]
--   #END
-- Returns { game, date, list = { [id] = { { name, prio, note }, ... } }, n, skipped } or nil and
-- the reason (German). Lines it does not know are skipped and counted; at most 2000 lines are read.
function ns.ParseGuildWishes(text)
    if type(text) ~= "string" then return nil, HEAD_FAIL end
    local res = { list = {}, n = 0, skipped = 0 }
    local read, head, ended = 0, false, false
    for raw in text:gmatch("[^\r\n]+") do
        local line = stripCodes(raw:sub(1, MAX_LINE)):match("^%s*(.-)%s*$")
        if line ~= "" then
            if not head then
                line = line:gsub("^\239\187\191", "")
                local ver, game, day = line:match("^#AMISIA%-WL%s+(%d+)%s+(%S+)%s+(%S+)")
                if ver ~= "1" or not day or not day:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil, HEAD_FAIL end
                game = game:lower()
                if game ~= clientGame() then
                    return nil, ("Diese Wunschliste ist für %s, du bist in %s."):format(gameName(game), gameName(clientGame()))
                end
                res.game, res.date, head = game, day, true
                read = 1
            elseif line == "#END" then
                ended = true
                break
            elseif read >= MAX_LINES then
                res.skipped = res.skipped + 1
            else
                read = read + 1
                local id, prio, name, note = line:match("^W%s+(%d+)%s+(%d+)%s+(%S+)%s*(.-)$")
                id, prio = tonumber(id), tonumber(prio)
                name = name and cleanName(name)
                if not id or id < 1 or id > MAX_ID or not prio or not name then
                    res.skipped = res.skipped + 1
                else
                    prio = math.max(1, math.min(3, math.floor(prio)))
                    note = ns.CleanNote(note, NOTE_MAX) or ""
                    local entries = res.list[id] or {}
                    res.list[id] = entries
                    local same
                    for _, e in ipairs(entries) do
                        if e.name:lower() == name:lower() then same = e break end
                    end
                    if not same then
                        entries[#entries + 1] = { name = name, prio = prio, note = note }
                        res.n = res.n + 1
                    elseif prio > same.prio then
                        same.prio, same.note = prio, note
                    end
                end
            end
        end
    end
    if not head then return nil, HEAD_FAIL end
    if res.n == 0 then return nil, "Die Liste ist leer." end
    for _, entries in pairs(res.list) do table.sort(entries, byPrio) end
    res.ended = ended
    return res
end

local function guild()
    local b = AmisiaDB and AmisiaDB.bis
    local g = type(b) == "table" and b.guild
    if type(g) ~= "table" or type(g.list) ~= "table" then return nil end
    return g
end

local refreshMarks

-- Stores a pasted list (the old one stays when the text is refused). Returns the parse result or
-- nil and the reason.
function ns.SetGuildWishes(text)
    local res, why = ns.ParseGuildWishes(text)
    if not res then return nil, why end
    if not AmisiaDB then return nil, "Amisia ist noch nicht geladen." end
    if type(AmisiaDB.bis) ~= "table" then ns.BisMigrate(AmisiaDB) end
    AmisiaDB.bis.guild = { game = res.game, date = res.date, at = time(), by = ns.UnitFullName("player"), n = res.n, list = res.list }
    refreshMarks()
    ns.Fire("GUILD_WISHES")
    return res
end

function ns.ClearGuildWishes()
    if AmisiaDB and type(AmisiaDB.bis) == "table" then AmisiaDB.bis.guild = nil end
    refreshMarks()
    ns.Fire("GUILD_WISHES")
end

-- { date, n, age (whole days since the list's date), game } or nil without a list.
function ns.GuildWishesInfo()
    local g = guild()
    if not g then return nil end
    return { date = g.date, n = tonumber(g.n) or 0, age = ns.SoftResAge({ date = g.date }), game = g.game }
end

-- "Die Wunschliste ist 16 Tage alt." for a list older than two weeks, else nil.
function ns.GuildWishesAgeText()
    local info = ns.GuildWishesInfo()
    if info and info.age and info.age > OLD_DAYS then return ("Die Wunschliste ist %d Tage alt."):format(info.age) end
    return nil
end

-- Who wished for an item: { { name, prio, note, inGroup } } by priority, then name; groupOnly
-- leaves out who is not in the group. A first name alone matches only while no other member of the
-- group carries it (ns.SameNameIn).
function ns.WishersOf(item, groupOnly)
    local g = guild()
    local id = tonumber(item) or ns.ItemID(item)
    local entries = g and id and g.list[id]
    local out = {}
    if type(entries) ~= "table" then return out end
    -- the group once per call: exact names in a set, the rest by first name, so ns.SameNameIn
    -- only runs for names that may match
    local roster = ns.GroupRoster()
    local exact, byFirst = {}, {}
    for _, r in ipairs(roster) do
        local low = r:lower()
        exact[low] = true
        local first = low:match("^(%S+)")
        byFirst[first] = byFirst[first] or {}
        table.insert(byFirst[first], r)
    end
    for _, e in ipairs(entries) do
        if type(e) == "table" and type(e.name) == "string" then
            local low = e.name:lower()
            local inGroup = exact[low] or false
            if not inGroup then
                for _, r in ipairs(byFirst[low:match("^(%S+)") or ""] or {}) do
                    if ns.SameNameIn(e.name, r, roster) then inGroup = true break end
                end
            end
            if inGroup or not groupOnly then
                out[#out + 1] = { name = e.name, prio = tonumber(e.prio) or 2, note = e.note, inGroup = inGroup }
            end
        end
    end
    table.sort(out, byPrio)
    return out
end

local function officerOn(path)
    return guild() ~= nil and ns.Get(path) and ns.IsOfficerView()
end

---------------------------------------------------------------------------
-- Tooltip line (officers), through the shared item tooltip hook
---------------------------------------------------------------------------

-- "Gewünscht: Anna (hoch), Bob (+2 außerhalb)": in a group only wishers from it, the others counted.
function ns.GuildWishTooltipText(item)
    local all = ns.WishersOf(item)
    if #all == 0 then return nil end
    local grouped = IsInGroup and IsInGroup() or false
    local shown, outside = {}, 0
    for _, e in ipairs(all) do
        if e.inGroup or not grouped then
            shown[#shown + 1] = e.name .. (PRIO_TIP[e.prio] or "")
        else
            outside = outside + 1
        end
    end
    local text
    if #shown == 0 then
        text = "Gewünscht: niemand aus der Gruppe"
    elseif #shown > TIP_NAMES then
        text = "Gewünscht: " .. table.concat(shown, ", ", 1, TIP_NAMES) .. (" und %d weitere"):format(#shown - TIP_NAMES)
    else
        text = "Gewünscht: " .. table.concat(shown, ", ")
    end
    if outside > 0 then text = text .. (" (+%d außerhalb)"):format(outside) end
    return text
end

ns.OnItemTooltip("guildwish", function(tip, _, id)
    if not officerOn("bis.guildTooltip") then return false end
    local text = ns.GuildWishTooltipText(id)
    if not text then return false end
    tip:AddLine(text, BLUE[1], BLUE[2], BLUE[3])
    return true
end)

---------------------------------------------------------------------------
-- "W" on the loot window and the group loot roll frames (SR sits top left, W top right)
---------------------------------------------------------------------------

local lootMarks = setmetatable({}, { __mode = "k" })   -- loot button -> font string
local rollMarks = setmetatable({}, { __mode = "k" })   -- roll frame -> font string
local hooked = setmetatable({}, { __mode = "k" })

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function wishedInGroup(link)
    local id = ns.ItemID(ns.Plain(link))
    return id ~= nil and #ns.WishersOf(id, true) > 0
end

local function setMark(store, owner, parent, on)
    local mark = store[owner]
    if on and not mark then
        mark = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
        mark:SetText("W")
        mark:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
        store[owner] = mark
    end
    if mark then
        if on then mark:Show() else mark:Hide() end
    end
end

local function markButton(btn, slot, on)
    local wished = on and slot and GetLootSlotLink and wishedInGroup(GetLootSlotLink(slot)) or false
    setMark(lootMarks, btn, btn, wished)
end

local function markLoot()
    local on = officerOn("bis.guildLootMark")
    for i = 1, tonumber(_G.LOOTFRAME_NUMBUTTONS) or 4 do
        local btn = _G["LootButton" .. i]
        if btn and btn.slot and btn.IsShown and btn:IsShown() then
            markButton(btn, btn.slot, on)
        elseif btn and lootMarks[btn] then
            lootMarks[btn]:Hide()
        end
    end
    local box = LootFrame and LootFrame.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(function(frame)
            if frame.GetSlotIndex then markButton(frame, frame:GetSlotIndex(), on) end
        end)
    end
end

-- Marks the open loot window again (protected).
function ns.MarkGuildWishLoot()
    local ok, err = pcall(markLoot)
    if not ok then report(err) end
end

local function markRoll(frame)
    local on = false
    local fn = _G.GetLootRollItemLink
    if officerOn("bis.guildLootMark") and type(fn) == "function" then
        local ok, link = pcall(fn, ns.Plain(frame.rollID))
        on = ok and wishedInGroup(link) or false
    end
    local parent = type(frame.IconFrame) == "table" and frame.IconFrame or frame
    setMark(rollMarks, frame, parent, on)
end

local function onRollFrameShow(frame)
    local ok, err = pcall(markRoll, frame)
    if not ok then report(err) end
end

local function hookRollFrames()
    for i = 1, tonumber(_G.NUM_GROUP_LOOT_FRAMES) or 4 do
        local f = _G["GroupLootFrame" .. i]
        if type(f) == "table" and type(f.HookScript) == "function" and not hooked[f] then
            hooked[f] = true
            f:HookScript("OnShow", onRollFrameShow)
        end
    end
end
hookRollFrames()
ns.OnEvent("PLAYER_ENTERING_WORLD", hookRollFrames)

refreshMarks = function()
    ns.MarkGuildWishLoot()
    for frame in pairs(rollMarks) do
        if frame.IsShown and frame:IsShown() then onRollFrameShow(frame) end
    end
end

ns.OnEvent("LOOT_OPENED", function() C_Timer.After(0, ns.MarkGuildWishLoot) end)
ns.OnEvent("LOOT_SLOT_CLEARED", function() C_Timer.After(0, ns.MarkGuildWishLoot) end)
if type(LootFrame_Update) == "function" then hooksecurefunc("LootFrame_Update", ns.MarkGuildWishLoot) end
ns.Listen("SETTING", function(path)
    if path == "bis.guildLootMark" or path == "ui.view" then refreshMarks() end
end)

-- For tests and the window: the W of a loot button and of a roll frame.
function ns.GuildWishMark(btn) return lootMarks[btn] end
function ns.GuildWishMarkShown(btn)
    local m = lootMarks[btn]
    return (m and m:IsShown()) and true or false
end
function ns.GuildWishRollMarkText(frame)
    local m = rollMarks[frame]
    return (m and m:IsShown()) and m:GetText() or nil
end

---------------------------------------------------------------------------
-- Award dialog: wishers first (bis.guildAward), the rest as before
---------------------------------------------------------------------------

-- names: the dialog's names, sorted. Returns the picker values with the wishers of the item first
-- (by priority, "Anna (Wunsch hoch)"), or nil when nothing changes.
function ns.GuildWishAwardValues(item, names)
    if not item or not officerOn("bis.guildAward") then return nil end
    local wishers = ns.WishersOf(item)
    if #wishers == 0 then return nil end
    local first, rest = {}, {}
    for _, n in ipairs(names) do
        local hit
        for _, e in ipairs(wishers) do
            if ns.SameNameIn(e.name, n, names) then hit = e break end
        end
        if hit then first[#first + 1] = { name = n, prio = hit.prio } else rest[#rest + 1] = n end
    end
    if #first == 0 then return nil end
    table.sort(first, byPrio)
    local values = {}
    for _, e in ipairs(first) do
        values[#values + 1] = { value = e.name, text = ("%s (Wunsch %s)"):format(e.name, PRIO_TEXT[e.prio] or "mittel") }
    end
    for _, n in ipairs(rest) do values[#values + 1] = { value = n, text = n } end
    return values
end

---------------------------------------------------------------------------
-- Import window
---------------------------------------------------------------------------

local F, editBox, infoText, previewText, resultText
local previewGen = 0

local function plural(n, one, many) return n == 1 and one or many end

local function longDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    return y and (d .. "." .. m .. "." .. y) or "?"
end

-- The preview line for a pasted text; nothing is stored. "" for an empty text.
function ns.GuildWishPreviewText(text)
    if not (text or ""):find("%S") then return "" end
    local res, why = ns.ParseGuildWishes(text)
    if not res then return why end
    local items = 0
    for _ in pairs(res.list) do items = items + 1 end
    local out = ("Vorschau: %d %s zu %d %s"):format(res.n, plural(res.n, "Wunsch", "Wünsche"), items, plural(items, "Item", "Items"))
    if res.skipped > 0 then
        out = out .. (", %d %s nicht erkannt"):format(res.skipped, plural(res.skipped, "Zeile", "Zeilen"))
    end
    return out
end

local function updatePreview()
    if not F or not previewText then return end
    local ok, text = pcall(ns.GuildWishPreviewText, editBox:GetText())
    previewText:SetText(ok and text or "")
    if not ok then report(text) end
end

local function schedulePreview()
    previewGen = previewGen + 1
    local gen = previewGen
    C_Timer.After(0.3, function()
        if gen == previewGen then updatePreview() end
    end)
end

local function refresh()
    if not F or not F:IsShown() then return end
    local info = ns.GuildWishesInfo()
    if info then
        local age = ns.GuildWishesAgeText()
        infoText:SetText(("Liste vom %s, %d %s"):format(longDate(info.date), info.n, plural(info.n, "Wunsch", "Wünsche"))
            .. (age and (" |cff8f86a3" .. age .. "|r") or ""))
    else
        infoText:SetText("|cff8f86a3Keine Gildenwünsche geladen. Auf der Website im Reiter Wishlist: Copy for the addon.|r")
    end
end
ns.Listen("GUILD_WISHES", refresh)

StaticPopupDialogs["AMISIA_GUILDWISH_CLEAR"] = {
    text = "Die Gildenwünsche löschen?",
    button1 = "Löschen",
    button2 = "Abbrechen",
    OnAccept = function()
        ns.ClearGuildWishes()
        if editBox then editBox:SetText("") end
        if previewText then previewText:SetText("") end
        if resultText then resultText:SetText("Liste gelöscht.") end
        refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- The bottom of the window, from below: buttons (10-32), result, preview, the text box.
local TEXT_H = 26
local RESULT_Y = 38
local PREVIEW_Y = RESULT_Y + TEXT_H + 4
local BOX_BOTTOM = PREVIEW_Y + TEXT_H + 4
local MAX_LETTERS = 150000

local function build()
    F = CreateFrame("Frame", "AmisiaGuildWishFrame", UIParent)
    F:SetSize(440, 380)
    F:SetPoint("CENTER", 0, 40)
    -- above the main window, like the soft-reserve import
    F:SetFrameStrata("FULLSCREEN_DIALOG")
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    F:SetScript("OnShow", refresh)
    F:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaGuildWishFrame") end

    local bg = F:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.04, 0.08, 0.96)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = F:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.89, 0.72, 0.34, 0.6)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) end
        if e[4] then t:SetHeight(e[4]) end
    end

    local title = F:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Gildenwünsche")
    title:SetTextColor(0.89, 0.72, 0.34)

    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    infoText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 12, -32)
    infoText:SetWidth(410)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(false)

    local boxBg = CreateFrame("Frame", nil, F)
    boxBg:SetPoint("TOPLEFT", 12, -50)
    boxBg:SetPoint("BOTTOMRIGHT", -12, BOX_BOTTOM)
    local bb = boxBg:CreateTexture(nil, "BACKGROUND")
    bb:SetAllPoints()
    bb:SetColorTexture(0, 0, 0, 0.45)

    local scroll = CreateFrame("ScrollFrame", "AmisiaGuildWishScroll", boxBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(MAX_LETTERS)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(380)
    editBox:SetHeight(200)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnTextChanged", schedulePreview)
    scroll:SetScrollChild(editBox)
    boxBg:EnableMouse(true)
    boxBg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- preview and result each have a fixed room of two lines
    previewText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewText:SetPoint("BOTTOMLEFT", 12, PREVIEW_Y)
    previewText:SetSize(416, TEXT_H)
    previewText:SetJustifyH("LEFT")
    previewText:SetJustifyV("TOP")
    previewText:SetWordWrap(true)
    previewText:SetMaxLines(2)
    previewText:SetTextColor(0.89, 0.72, 0.34)
    previewText:SetText("")

    resultText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultText:SetPoint("BOTTOMLEFT", 12, RESULT_Y)
    resultText:SetSize(416, TEXT_H)
    resultText:SetJustifyH("LEFT")
    resultText:SetJustifyV("TOP")
    resultText:SetWordWrap(true)
    resultText:SetMaxLines(2)
    resultText:SetText("")

    local apply = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    apply:SetSize(110, 22)
    apply:SetPoint("BOTTOMLEFT", 12, 10)
    apply:SetText("Übernehmen")
    apply:SetScript("OnClick", function()
        local res, why = ns.SetGuildWishes(editBox:GetText())
        if res then
            resultText:SetText(("%d %s übernommen, %d %s nicht erkannt."):format(res.n, plural(res.n, "Wunsch", "Wünsche"), res.skipped,
                plural(res.skipped, "Zeile", "Zeilen")))
        else
            resultText:SetText(why)
        end
        refresh()
    end)

    local clear = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
    clear:SetSize(90, 22)
    clear:SetPoint("LEFT", apply, "RIGHT", 6, 0)
    clear:SetText("Löschen")
    clear:SetScript("OnClick", function()
        local d = StaticPopup_Show("AMISIA_GUILDWISH_CLEAR")
        -- lifted above this window and the main window
        if d and d.SetFrameStrata then d:SetFrameStrata("FULLSCREEN_DIALOG"); if d.Raise then d:Raise() end end
    end)

    local hint = F:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", clear, "RIGHT", 8, 0)
    hint:SetWidth(200)   -- 12 + 110 + 6 + 90 + 8 + 200 fits the 428 px inside the margin
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(false)
    hint:SetText("Website, Reiter Wishlist: Copy for the addon")

    F.editBox, F.previewText, F.resultText, F.infoText, F.applyBtn, F.clearBtn = editBox, previewText, resultText, infoText, apply, clear
end

function ns.ShowGuildWishFrame()
    if not F then build() end
    F:Show()
    if F.Raise then F:Raise() end
    return F
end

ns.RegisterSlash("wuensche", { aliases = { "wishes" }, officer = true, desc = "Gildenwünsche von der Website einfügen",
    run = function()
        if not ns.IsOfficerView() then
            ns.msg("Gildenwünsche nur in der Offiziersansicht.")
            return
        end
        -- the gear page's guild view, with the import box
        ns.ShowGear("guild")
    end })
