-- Amisia roll window for raiders (DECISIONS D-38, spec docs/specs/2026-10-08-loot-abend.md, Teil 3).
-- When the loot lead starts a round (Rolls.lua), its client sends WS into the raid; every raider
-- client with Amisia shows a small window in the look of the client's group loot frame: the item
-- with its icon and tooltip, the hints Amisia already has (reserved, plus-one, upgrade, wishlist),
-- a timer bar and the buttons. "Mainspec" and "Offspec" roll through the client (RandomRoll 1-100,
-- 1-99): the number only ever comes from the server's system line, which the loot lead reads as
-- before. "Passen", a bid and need or greed go as an addon whisper (WA) to the loot lead only, where
-- they count exactly like the whispered !pass, !bid and !need (ns.PointsChatWord, PointsRounds.lua).
-- At the end (WE) the window shows the winner for 5 seconds; without WE it closes 3 seconds after
-- its own clock. A round counts only from the verified loot lead in the own group (officer rank, the
-- rule of "Wer braucht das?", Need.lua); a tie-break shows only to those tied; a new round replaces
-- the running one (never two windows, never two running rounds). In the chat lockdown the buttons
-- wait (the lead could not read a roll). Nothing is saved but the settings (section rollwin) and
-- the window's place (settings.rollWindow).
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local WIDTH = 320
local PAD = 8
local ICON = 36
local TEXT_X = PAD + ICON + 8            -- the item's name and the hints right of the icon
local TEXT_W = WIDTH - TEXT_X - PAD
local BAR_Y, BAR_H = -48, 12              -- the timer bar under icon and hints
local BUTTON_Y = -66                      -- the buttons under the bar
local STATUS_Y = -92                      -- what was done, the lockdown, the winner
local DONE_Y = -50                        -- a finished round: the result where the bar was
local ROW_H, DONE_H = 108, 68             -- a running round, a finished one
local TOP = T.TITLE_H + 6                 -- the first round under the title bar
local MAX_ROWS = 3                        -- the running round and the results of the ones before
local MAX_ITEM = 120                      -- characters of the item string in WS
local MAX_RESERVERS, MAX_TIE = 8, 10
local MSG_BYTES = 250                     -- one addon message (Comm.lua)
local WINNER_FOR = 5                      -- seconds the result stays
local GRACE = 3                           -- the window closes this long after its clock without WE
local END_TTL = 10
local START_TTL = 5                       -- a held WS (lockdown, throttle) falls after this: its seconds would lie
local ANSWER_TTL = 15
local ANSWER_GAP = 2.2                    -- the lead takes one answer per round every 2 s (KEYED_GAP)
local TICK = 0.1
local TEST_ITEM = 6948                    -- the hearthstone: every client knows it
local TEST_SECONDS = 30
local SINCE = "2.17.0"                    -- the first version with the window ("ohne Antwort")
local BAR_COLOR = { 0.89, 0.62, 0.18 }
local GREEN, ORANGE, GREY, GOLD = T.GREEN, T.ORANGE, T.GREY, T.GOLD_TEXT

-- Shown rounds, newest first: { rid, item, link, secs, art "R"|"B"|"N", sealed, tie = { names }|nil,
-- reservers = { names }, min, cost, costOS, lead, leadRaw, own, test, startAt, endsAt, choice
-- ("MS"/"OS"/"P"/"N"/"G"/"B"), amount, rolled, done, result, closeAt, hints = { text, mine } }
local rounds = {}
local F
local rows = {}
local ticker
local matcher
local nextAnswerAt = {}   -- round id -> GetTime() the next answer may go

local function now() return GetTime() end
local function me() return ns.UnitFullName("player") end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- The chat lockdown of a boss fight: rolls cannot be read, answers would wait.
local function locked()
    return (ns.CommHeld and ns.CommHeld()) or (ns.ChatLocked and ns.ChatLocked()) or false
end

local function inPvP()
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    return kind == "pvp" or kind == "arena"
end

-- A name a field may carry: no digits, commas, colons or bars (Comm.lua checks the same).
local function okName(n)
    return type(n) == "string" and n ~= "" and #n <= 48 and not n:find("[%c,:|%d]")
end

local function splitNames(v)
    local out = {}
    if type(v) ~= "string" or v == "-" or v == "" then return out end
    for n in (v .. ","):gmatch("([^,]*),") do
        if okName(n) then out[#out + 1] = n end
    end
    return out
end

-- Whether name is one of list (ns.SameNameIn over the group: a first name alone only while one
-- raider carries it).
local function among(list, name)
    if not name then return false end
    local roster = ns.GroupRoster()
    for _, n in ipairs(list or {}) do
        if ns.SameNameIn(n, name, roster) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The item
---------------------------------------------------------------------------
-- "item:..." of a link, without colours and the trailing empty fields; "item:<id>" when it is longer
-- than a field may be. nil without an item id.
local function itemString(link)
    link = ns.Plain(link)
    if type(link) ~= "string" then return nil end
    local id = ns.ItemID(link)
    if not id then return nil end
    local s = link:match("|H(item:[^|]+)|h") or link:match("^(item:[%-%d:]+)$")
    if s then s = (s:gsub(":+$", "")) end
    if not s or #s > MAX_ITEM or not s:match("^item:%d+[%-%d:]*$") then s = "item:" .. id end
    return s
end

-- Name, link, quality and icon of an item string; name and link nil while the client has not
-- loaded the item (asked for once; GET_ITEM_INFO_RECEIVED refreshes).
local function itemInfo(item, ask)
    local name, link, quality, icon
    local api = _G.C_Item
    if type(api) == "table" and type(api.GetItemInfo) == "function" then
        local ok, n, l, q = pcall(api.GetItemInfo, item)
        if ok then name, link, quality = ns.Plain(n), ns.Plain(l), ns.Plain(q) end
    end
    if type(api) == "table" and type(api.GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, ic = pcall(api.GetItemInfoInstant, item)
        if ok then icon = ns.Plain(ic) end
    end
    if not name and ask and type(api) == "table" and type(api.RequestLoadItemDataByID) == "function" then
        pcall(api.RequestLoadItemDataByID, ns.ItemID(item))
    end
    return name, link, quality, icon
end

---------------------------------------------------------------------------
-- The hints: what Amisia already knows about the item for this character
---------------------------------------------------------------------------
local function pctText(u)
    if u.pct then return ("+%d %%"):format(u.pct) end
    return L["neu"]
end

-- { text, mine }: the hints as one line, and whether the item is reserved by, an upgrade for or a
-- wish of this character (rollwin.onlyMine).
local function hintsOf(r)
    local out, mine = {}, false
    local my = me()
    local id = ns.ItemID(r.item)
    if r.tie then out[#out + 1] = ORANGE .. L["Stechen: %s"]:format(table.concat(r.tie, ", ")) .. "|r" end
    -- reservations as the loot lead sent them
    local others = 0
    local own = false
    for _, n in ipairs(r.reservers) do
        if my and among({ n }, my) then own = true else others = others + 1 end
    end
    if own then
        mine = true
        if others == 0 then
            out[#out + 1] = GREEN .. L["Reserviert von dir"] .. "|r"
        elseif others == 1 then
            out[#out + 1] = GREEN .. L["Reserviert von dir und einem anderen"] .. "|r"
        else
            out[#out + 1] = GREEN .. L["Reserviert von dir und %d anderen"]:format(others) .. "|r"
        end
    elseif others == 1 then
        out[#out + 1] = L["Reserviert von einem anderen"]
    elseif others > 1 then
        out[#out + 1] = L["Reserviert von %d anderen"]:format(others)
    end
    -- the plus-one (a rolling round only)
    if r.art == "R" and my and ns.PlusCount then
        local ok, n = pcall(ns.PlusCount, my)
        if ok and tonumber(n) and n > 0 then out[#out + 1] = L["Dein Plus-Eins: %d"]:format(n) end
    end
    -- the one comparison with the worn gear (Bis.lua)
    if ns.Gear and ns.Gear.Available() and ns.Get("bis.compare") ~= false and ns.UpgradeOf then   -- l10n-ok: setting key
        local ok, u = pcall(ns.UpgradeOf, r.link or r.item)
        if not ok then
            report(u)
        elseif type(u) == "table" and u.up then
            mine = true
            local slot = ns.BIS_SLOT_NAME and u.slotKey and ns.BIS_SLOT_NAME[u.slotKey]
            out[#out + 1] = GREEN .. (slot and L["Upgrade für dich: %s (%s)"]:format(pctText(u), slot)
                or L["Upgrade für dich: %s"]:format(pctText(u))) .. "|r"
        end
    end
    -- the own wishlist and the guild's (the site's) wish of this character
    local wished = false
    local c = id and ns.BisChar and ns.BisChar()
    if c and type(c.wish) == "table" and c.wish[id] then wished = true end
    if not wished and id and my and ns.WishersOf then
        local ok, list = pcall(ns.WishersOf, id)
        if ok then
            for _, e in ipairs(list) do
                if ns.SameName(e.name, my) then wished = true break end
            end
        end
    end
    if wished then
        mine = true
        out[#out + 1] = GREEN .. L["Auf deiner Wunschliste"] .. "|r"
    end
    -- a points round: the own standing
    if (r.art == "B" or r.art == "N") and my and ns.PointsOf and ns.PointsSystem then
        local sys = ns.PointsSystem()
        local ok, st = pcall(ns.PointsOf, my)
        if ok and type(st) == "table" and sys == "dkp" then
            out[#out + 1] = L["Dein Stand: %d DKP"]:format(tonumber(st.a) or 0)
        elseif ok and type(st) == "table" and sys == "epgp" and st.pr and ns.PointsPRText then
            out[#out + 1] = L["Dein PR: %s"]:format(ns.PointsPRText(st.pr))
        end
    end
    if r.art == "B" and r.min then out[#out + 1] = L["Mindestgebot: %d"]:format(r.min) end
    if r.sealed then out[#out + 1] = L["verdeckt"] end
    return { text = table.concat(out, " · "), mine = mine }
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local refresh

local function windowState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.rollWindow) ~= "table" then AmisiaDB.settings.rollWindow = {} end
    return AmisiaDB.settings.rollWindow
end

local function place()
    if not F then return end
    F:ClearAllPoints()
    local st = windowState()
    if st and type(st.point) == "string" and tonumber(st.x) and tonumber(st.y) then
        F:SetPoint(st.point, UIParent, st.point, tonumber(st.x), tonumber(st.y))
    else
        F:SetPoint("TOP", UIParent, "TOP", 0, -160)
    end
end

local function savePlace(f)
    local st = windowState()
    if not st then return end
    local point, _, _, x, y = f:GetPoint(1)
    if type(point) == "string" and tonumber(x) and tonumber(y) then
        st.point, st.x, st.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

function ns.ResetRollWindowPosition()
    local st = windowState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

local function applyScale()
    if F then F:SetScale((tonumber(ns.Get("rollwin.scale")) or 100) / 100) end
end

-- Whether the buttons of round r work now: running, the clock not over, no lockdown.
local function canAct(r)
    return r and not r.done and now() < r.endsAt and not locked()
end

-- The lead's own round: ns.CurrentRoll with this id, still running.
local function ownRound(r)
    local cur = ns.CurrentRoll and ns.CurrentRoll()
    if cur and not cur.done and cur.wid == r.rid then return cur end
    return nil
end

local takeAnswer   -- (the loot lead's side, below)

-- An answer of this client: to the loot lead as a whisper (WA), the lead's own round straight into
-- the round, a test round nowhere. The lead takes one answer per round every 2 s: a quicker second
-- answer waits and replaces a waiting first one, so the last one counts.
local function answer(r, what, amount)
    if not canAct(r) then return end
    r.choice, r.amount, r.note = what, amount, nil
    if r.test then
        r.note = L["Probe: nichts gesendet."]
    elseif r.own then
        local cur = ownRound(r)
        local my = me()
        if cur and my then takeAnswer(cur, my, my, what, amount) end
    else
        local wait = nextAnswerAt[r.rid] or 0
        nextAnswerAt[r.rid] = math.max(now(), wait) + ANSWER_GAP
        local fields = { r.rid, what }
        if what == "B" then fields[3] = tostring(amount) end
        local ok, why = ns.CommSend("WA", fields, "WHISPER", r.leadRaw, { ttl = ANSWER_TTL, key = "WA:" .. r.rid,
            when = function() return GetTime() >= wait end })
        if not ok then r.choice, r.note = nil, why end
    end
    refresh()
end

local function roll(r, kind)
    if not canAct(r) then return end
    if type(RandomRoll) ~= "function" then return end
    r.choice, r.rolled = kind, nil
    if kind == "MS" then RandomRoll(1, 100) else RandomRoll(1, 99) end
    refresh()
end

local function bid(row)
    local r = row.r
    local n = tonumber(row.bidEdit:GetText())
    row.bidEdit:ClearFocus()
    if not r or not n or n < 1 or n ~= math.floor(n) then
        if r then r.note = L["Gebot: nur eine ganze Zahl."] end
        refresh()
        return
    end
    answer(r, "B", n)
end

local function rowTooltip(btn)
    local r = btn:GetParent().r
    if not r then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(r.link or r.item)
    GameTooltip:Show()
end

local function button(row, label, onClick)
    local b = W.Button(row, label, 80, function() if row.r then onClick(row.r) end end, { height = T.BUTTON_H })
    W.FitChip(b, 60)
    return b
end

local function buildRow(i)
    local row = CreateFrame("Frame", nil, F)
    row:SetSize(WIDTH, ROW_H)
    row:SetPoint("TOPLEFT", 0, -TOP - (i - 1) * ROW_H)   -- refresh stacks the rows by their heights
    row.iconBtn = CreateFrame("Button", nil, row)
    row.iconBtn:SetSize(ICON, ICON)
    row.iconBtn:SetPoint("TOPLEFT", PAD, -4)
    row.icon = row.iconBtn:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.iconBtn:SetScript("OnEnter", rowTooltip)
    row.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = W.Text(row, T.FONT.body, TEXT_W)
    row.name:SetPoint("TOPLEFT", TEXT_X, -4)
    row.hint = W.Text(row, T.FONT.text, TEXT_W, true)
    row.hint:SetPoint("TOPLEFT", TEXT_X, -20)
    row.hint:SetHeight(26)
    row.hint:SetMaxLines(2)
    row.hint:SetJustifyV("TOP")
    -- the timer bar: the profession window's skill bar, filled in gold
    local barW = WIDTH - 2 * PAD
    row.bar = CreateFrame("Frame", nil, row)
    row.bar:SetSize(barW, BAR_H)
    row.bar:SetPoint("TOPLEFT", PAD, BAR_Y)
    if not W.SlicedAtlas(row.bar, "BACKGROUND", 0, "Professions-skillbar-bg", 6, BAR_H) then
        W.Flat(row.bar, 0, 0, 0, 0.5, "BACKGROUND")
    end
    row.fill = row.bar:CreateTexture(nil, "ARTWORK")
    row.fill:SetColorTexture(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], 0.85)
    row.fill:SetPoint("TOPLEFT", 2, -2)
    row.fill:SetHeight(BAR_H - 4)
    row.fill:SetWidth(barW - 4)
    row.fillW = barW - 4
    W.SlicedAtlas(row.bar, "OVERLAY", 0, "Professions-skillbar-frame", 6, BAR_H)
    row.time = W.Text(row.bar, T.FONT.text, 60)
    row.time:SetPoint("RIGHT", -4, 0)
    row.time:SetJustifyH("RIGHT")
    -- the buttons of every kind of round; refresh shows the ones of the round
    row.ms = button(row, L["Mainspec"], function(r) roll(r, "MS") end)
    row.os = button(row, L["Offspec"], function(r) roll(r, "OS") end)
    row.need = button(row, L["Bedarf"], function(r) answer(r, "N") end)
    row.greed = button(row, L["Gier"], function(r) answer(r, "G") end)
    row.bidEdit = W.LineEdit(row, 60)
    row.bidEdit:SetNumeric(true)
    row.bidEdit:SetMaxLetters(7)
    row.bidEdit:SetScript("OnEnterPressed", function() bid(row) end)
    row.bidBtn = button(row, L["Bieten##Knopf"], function() bid(row) end)
    row.pass = button(row, L["Passen"], function(r) answer(r, "P") end)
    row.status = W.Text(row, T.FONT.text, WIDTH - 2 * PAD)
    row.status:SetPoint("TOPLEFT", PAD, STATUS_Y)
    row:Hide()
    return row
end

local function build()
    F = W.Window("AmisiaRollWindow", WIDTH, TOP + ROW_H + 4, { title = L["Würfeln"], strata = "DIALOG", escape = false,
        onDragStop = savePlace })
    F:SetScript("OnHide", function()
        -- the X closes it at any time: the rounds go, a new round opens it again
        rounds = {}
        if ticker then ticker:Cancel(); ticker = nil end
    end)
    for i = 1, MAX_ROWS do rows[i] = buildRow(i) end
    F.rows = rows
    place()
    applyScale()
    ns.RollWindow = F
end

-- The status line of a round: the result, what this client did, the lockdown, the end of the clock.
local function statusOf(r)
    if r.done then return GOLD .. (r.result or L["Runde vorbei."]) .. "|r" end
    local parts = {}
    if r.choice == "MS" or r.choice == "OS" then
        local word = r.choice == "MS" and L["Mainspec"] or L["Offspec"]
        parts[#parts + 1] = r.rolled and L["Gewürfelt: %s %d"]:format(word, r.rolled) or L["Gewürfelt: %s"]:format(word)
    elseif r.choice == "P" then
        parts[#parts + 1] = L["Gepasst."]
    elseif r.choice == "N" then
        parts[#parts + 1] = L["Gesagt: Bedarf."]
    elseif r.choice == "G" then
        parts[#parts + 1] = L["Gesagt: Gier."]
    elseif r.choice == "B" then
        parts[#parts + 1] = L["Geboten: %d."]:format(r.amount or 0)
    end
    if r.note then parts[#parts + 1] = r.note end
    local text = table.concat(parts, " ")
    if now() >= r.endsAt then return GREY .. (text ~= "" and (text .. " ") or "") .. L["Zeit abgelaufen."] .. "|r" end
    if locked() then return ORANGE .. L["Würfeln erst nach dem Kampf."] .. "|r" .. (text ~= "" and (" " .. text) or "") end
    return text
end

local function priceText(word, n)
    if n then return L["%s (Preis %d)"]:format(word, n) end
    return word
end

local function fillRow(row, r)
    row.r = r
    -- a row taking another round starts with an empty bid field (no amount of the round before)
    if row.bidFor ~= r then
        row.bidFor = r
        row.bidEdit:SetText("")
    end
    if not r.name then
        -- read once the client has the item (asked for on the first try)
        local name, link, quality, icon = itemInfo(r.item, not r.asked)
        r.asked = true
        r.name, r.link, r.quality, r.icon = name, link or r.link, quality, icon or r.icon
    end
    local color = r.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[r.quality]
    local label = r.name or ("Item " .. tostring(ns.ItemID(r.item) or "?"))
    row.name:SetText(color and color.hex and (color.hex .. label .. "|r") or label)
    row.icon:SetTexture(r.icon or 134400)
    row.hint:SetText(r.hints and r.hints.text or "")
    local left = math.max(0, r.endsAt - now())
    local frac = r.done and 0 or math.min(1, left / math.max(1, r.secs))
    row.fill:SetWidth(math.max(1, row.fillW * frac))
    row.fill:SetShown(frac > 0)
    row.time:SetText(r.done and "" or ("%d s"):format(math.ceil(left)))
    -- the buttons of the round's kind
    local rolling = r.art == "R" or r.tie ~= nil
    local act = canAct(r)
    local rolled = r.choice == "MS" or r.choice == "OS"
    row.ms:SetShown(rolling and not r.done)
    row.os:SetShown(rolling and not r.done)
    row.need:SetShown(r.art == "N" and not r.tie and not r.done)
    row.greed:SetShown(r.art == "N" and not r.tie and not r.done)
    row.bidEdit:SetShown(r.art == "B" and not r.tie and not r.done)
    row.bidBtn:SetShown(r.art == "B" and not r.tie and not r.done)
    row.pass:SetShown(not r.done)
    if r.art == "N" and row.priced ~= r then
        row.priced = r
        row.need:SetText(priceText(L["Bedarf"], r.cost))
        row.greed:SetText(priceText(L["Gier"], r.costOS))
        W.FitChip(row.need, 60)
        W.FitChip(row.greed, 60)
    end
    -- a roll is final (a second one would not count); a pass can still be followed by a roll; a bid
    -- stands (a pass would not take it back at the loot lead, as !pass in a bid round)
    row.ms:SetEnabled(act and not rolled)
    row.os:SetEnabled(act and not rolled)
    row.pass:SetEnabled(act and not rolled and r.choice ~= "P" and r.choice ~= "B")
    row.need:SetEnabled(act)
    row.greed:SetEnabled(act)
    row.bidBtn:SetEnabled(act)
    W.Row(row, { row.ms, row.os, row.need, row.greed, row.bidEdit, row.bidBtn, row.pass }, 6, PAD, BUTTON_Y, { shown = true })
    -- a finished round: the result in the bar's place, the row shorter
    row.bar:SetShown(not r.done)
    row.status:ClearAllPoints()
    row.status:SetPoint("TOPLEFT", PAD, r.done and DONE_Y or STATUS_Y)
    row.status:SetText(statusOf(r))
    row:SetHeight(r.done and DONE_H or ROW_H)
    row:Show()
end

refresh = function()
    if not F then return end
    -- rounds whose time is over leave
    local t = now()
    local keep = {}
    for _, r in ipairs(rounds) do
        if not r.done and t >= r.endsAt and not r.closeAt then r.closeAt = r.endsAt + GRACE end
        if not (r.closeAt and t >= r.closeAt) then keep[#keep + 1] = r end
    end
    rounds = keep
    if #rounds == 0 then
        if F:IsShown() then F:Hide() end
        return
    end
    local y = TOP
    for i = 1, MAX_ROWS do
        local row = rows[i]
        if rounds[i] then
            fillRow(row, rounds[i])
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + row:GetHeight()
        else
            row.r = nil
            row:Hide()
        end
    end
    F:SetHeight(y + 4)
end

local function show()
    if not F then build() end
    applyScale()
    if not F:IsShown() then F:Show() end
    if not ticker then ticker = C_Timer.NewTicker(TICK, refresh) end
    refresh()
end

---------------------------------------------------------------------------
-- A round starts and ends (on every client with the window)
---------------------------------------------------------------------------
-- The running round leaves: a new round replaces it.
local function dropRunning()
    local keep = {}
    for _, r in ipairs(rounds) do
        if r.done then keep[#keep + 1] = r end
    end
    rounds = keep
end

-- A round from the fields of WS (checked by Comm.lua): lead is the trusted sender (its group
-- spelling), leadRaw the sender to whisper to; opts.own the lead's own round, opts.test a test round
-- (nothing sent). Returns the round when the window shows it.
local function startRound(f, lead, leadRaw, opts, arrived)
    opts = opts or {}
    local flags = f[5] or "-"
    local r = { rid = f[1], item = f[2], secs = tonumber(f[3]) or 20, art = f[4], reservers = splitNames(f[6]),
                min = tonumber(f[7]), cost = f[4] == "N" and tonumber(f[7]) or nil, costOS = tonumber(f[8]),
                sealed = flags:find("S", 1, true) and true or nil, lead = lead, leadRaw = leadRaw,
                own = opts.own, test = opts.test }
    if r.art ~= "B" then r.min = nil end
    if flags:find("T", 1, true) then r.tie = splitNames(f[9]) end
    r.startAt = arrived or now()
    r.endsAt = r.startAt + r.secs
    dropRunning()
    -- a tie-break shows only to those tied
    if r.tie and not among(r.tie, me()) then
        refresh()
        return nil
    end
    local ok, hints = pcall(hintsOf, r)
    if not ok then report(hints) hints = { text = "", mine = false } end
    r.hints = hints
    if not opts.own and not opts.test and not r.tie and ns.Get("rollwin.onlyMine") and not hints.mine then
        refresh()
        return nil
    end
    table.insert(rounds, 1, r)
    while #rounds > MAX_ROWS do table.remove(rounds) end
    if ns.Get("rollwin.sound") and type(PlaySound) == "function" and SOUNDKIT then
        local kit = SOUNDKIT.UI_BONUS_LOOT_ROLL_START or SOUNDKIT.RAID_WARNING
        if kit then pcall(PlaySound, kit) end
    end
    show()
    return r
end

-- "Gewinner: Anna (95, MS)", "Gewinner: Anna (60 DKP)", "Gewinner: Anna (Bedarf)", "Gleichstand.",
-- "Niemand hat gewürfelt."
local function resultText(winner, res, how)
    if how == "X" then return L["Runde abgebrochen."] end
    if res == "T" then return L["Gleichstand: es folgt ein Stechen."] end
    if not winner or winner == "-" then return L["Kein Gewinner."] end
    local value, kind = (res or ""):match("^(%d*):(%u+)$")
    local what
    if kind == "BID" then
        what = L["%d DKP"]:format(tonumber(value) or 0)
    elseif kind == "NEED" then
        what = L["Bedarf"]
    elseif kind == "GREED" then
        what = L["Gier"]
    elseif kind and tonumber(value) then
        what = ("%d, %s"):format(tonumber(value), kind)
    end
    if what then return L["Gewinner: %s (%s)"]:format(winner, what) end
    return L["Gewinner: %s"]:format(winner)
end

-- The end of round rid from lead (WE), or of the own round (own = true). The sender must be the
-- round's lead (ns.SameNameIn: "Fraktur Stein" never ends the round of "Fraktur").
local function endRound(rid, lead, winner, res, own, how)
    local roster = ns.GroupRoster()
    for _, r in ipairs(rounds) do
        if r.rid == rid and not r.done and not r.test
            and ((own and r.own) or (not own and not r.own and lead and r.lead and ns.SameNameIn(r.lead, lead, roster))) then
            r.done = true
            r.result = resultText(winner, res, how)
            r.closeAt = now() + WINNER_FOR
            refresh()
            return r
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The loot lead's side
---------------------------------------------------------------------------
-- A comma list of the names that fit room bytes (at most max), or "-".
local function nameList(names, max, room)
    local out, used = {}, 0
    for _, n in ipairs(names or {}) do
        n = ns.FullName(n)
        if okName(n) and #out < max then
            local add = #n + (#out > 0 and 1 or 0)
            if used + add > room then break end
            out[#out + 1] = n
            used = used + add
        end
    end
    return #out > 0 and table.concat(out, ",") or "-"
end

local function amount(n)
    n = tonumber(n)
    if not n or n < 0 or n > 9999999 then return "-" end
    return tostring(math.floor(n + 0.5))
end

-- The fields of WS for round r, at most 250 bytes: the tie-break's names first, then as many
-- reservers as fit.
local function wsFields(r)
    local art = r.mode == "bid" and "B" or (r.mode == "pr" and "N") or "R"
    local flags = (r.only and "T" or "") .. (r.seal and "S" or "")
    local f7 = r.mode == "bid" and amount(r.min or 0) or (r.mode == "pr" and amount(r.cost)) or "-"
    local f8 = r.mode == "pr" and amount(r.costOS) or "-"
    local fields = { r.wid, itemString(r.link) or ("item:" .. tostring(r.item)), tostring(r.seconds), art,
                     flags ~= "" and flags or "-", "-", f7, f8, "-" }
    local function room() return MSG_BYTES - #("1WS\t" .. table.concat(fields, "\t")) + 1 end
    if r.onlyList then fields[9] = nameList(r.onlyList, MAX_TIE, room()) end
    fields[6] = nameList(r.reserved, MAX_RESERVERS, room())
    return fields
end

-- Whether name is among the tie-break's names of round r.
local function tiedIn(r, name)
    if not r.only then return true end
    local roster = r.roster or ns.GroupRoster()
    for n in pairs(r.only) do
        if ns.SameNameIn(n, name, roster) then return true end
    end
    return false
end

local function changed(r)
    if ns.OnRollChanged then ns.OnRollChanged(r) end
    if ns.CurrentPage and ns.CurrentPage() == "rolls" and ns.Refresh then ns.Refresh() end
end

-- An answer from a raider's window (or the lead's own) in round r: a pass is noted for the tally (and
-- in a need/greed round takes the entry out, as !pass); need, greed and a bid go through the very
-- functions of the whispered words, with their checks and replies (PointsRounds.lua). sender is the
-- raw sender (the reply goes there), name its group spelling (who the entry is: a realm ending on
-- the sender must not lose the answer).
takeAnswer = function(r, sender, name, what, value)
    if not tiedIn(r, name) then return end
    r.passed = r.passed or {}
    if what == "P" then
        r.passed[name] = true
        if r.mode == "pr" and ns.PointsChatWord then ns.PointsChatWord("pass", sender, "", "WHISPER", name) end
    elseif (what == "N" or what == "G") and r.mode == "pr" then
        r.passed[name] = nil
        if ns.PointsChatWord then ns.PointsChatWord(what == "N" and "need" or "greed", sender, "", "WHISPER", name) end
    elseif what == "B" and r.mode == "bid" then
        r.passed[name] = nil
        if ns.PointsChatWord then ns.PointsChatWord("bid", sender, tostring(value or ""), "WHISPER", name) end
    else
        return
    end
    changed(r)
end

-- Rolls.lua: a round started. The verified loot lead in its raid (the checks of "Wer braucht das?")
-- sends it to the raid; the lead's own small window shows it too (rollwin.self).
function ns.RollWindowStarted(r)
    if not r or r.done then return end
    r.wid = ("%04x"):format(math.random(0, 65535))
    r.passed = {}
    if not (ns.NeedCanAsk and ns.NeedCanAsk()) then return end
    local fields = wsFields(r)
    -- held by the lockdown (or the throttle), it falls after a few seconds: the raiders' clocks start
    -- when it arrives, so a late round would show more time than the lead's round has left
    if not ns.CommSend("WS", fields, "RAID", nil, { ttl = math.min(r.seconds, START_TTL), key = "WS" }) then return end
    r.wsSent = true
    if ns.Get("rollwin.enabled") and ns.Get("rollwin.self") then startRound(fields, me(), nil, { own = true }) end
end

-- The result field of WE for finished round r.
local function resultField(r)
    if r.tie then return "T" end
    if not r.winner then return "-" end
    local top = ns.RollRanking(r)[1]
    if not top then return "-" end
    if r.mode == "bid" then return ("%d:BID"):format(tonumber(top.value) or 0) end
    if r.mode == "pr" then return top.kind == "OS" and ":GREED" or ":NEED" end
    local v = tonumber(top.value)
    if not v or v < 0 or v > 9999999 then return "-" end
    return ("%d:%s"):format(v, top.rank or top.kind or "MS")
end

-- Rolls.lua: round r ended (time or Stopp); the raiders' windows show the winner.
function ns.RollWindowEnded(r)
    if not r or not r.wsSent or r.weSent then return end
    r.weSent = true
    local winner = okName(r.winner) and r.winner or "-"
    local res = resultField(r)
    ns.CommSend("WE", { r.wid, "D", winner, res }, "RAID", nil, { ttl = END_TTL, key = "WE:" .. r.wid })
    endRound(r.wid, nil, winner, res, true, "D")
end

-- "passt: 3 · ohne Antwort: 5" for the roll window of the loot lead while the raiders' windows have
-- round r; nil otherwise. Without an answer: raiders with Amisia (from this version on) in the
-- group, among the tied in a tie-break, that neither rolled, bid, said need or greed nor passed.
function ns.RollWindowTally(r)
    if not r or not r.wsSent then return nil end
    local roster = r.roster or ns.GroupRoster()
    local function inSet(set, name)
        for k in pairs(set or {}) do
            if ns.SameNameIn(k, name, roster) then return true end
        end
        return false
    end
    local passed = 0
    for name in pairs(r.passed or {}) do
        if not inSet(r.rolls, name) then passed = passed + 1 end
    end
    local since = ns.CompareVersion and ns.CompareVersion(ns.VERSION or SINCE, SINCE) < 0 and ns.VERSION or SINCE
    local missing = 0
    for _, name in ipairs(ns.AmisiaInGroup and ns.AmisiaInGroup(since) or {}) do
        if tiedIn(r, name) and not inSet(r.rolls, name) and not inSet(r.passed, name) then missing = missing + 1 end
    end
    return L["passt: %d · ohne Antwort: %d"]:format(passed, missing)
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
ns.CommOn("WS", function(sender, f, chan)
    if chan ~= "RAID" or not ns.Get("rollwin.enabled") or inPvP() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local arrived = now()
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.Get("rollwin.enabled") or not ns.InMyGroup(name) then return end
        if not (ns.IsLootLeadName and ns.IsLootLeadName(name)) then return end
        startRound(f, name, sender, nil, arrived)
    end)
end)

ns.CommOn("WE", function(sender, f, chan)
    if chan ~= "RAID" then return end
    local name = ns.TrustName(sender)
    if name then endRound(f[1], name, f[3], f[4], false, f[2]) end
end)

ns.CommOn("WA", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    local r = ns.CurrentRoll and ns.CurrentRoll()
    if not r or r.done or not r.wsSent or r.wid ~= f[1] then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        local cur = ns.CurrentRoll and ns.CurrentRoll()
        if cur ~= r or r.done then return end
        takeAnswer(r, sender, name, f[2], f[3])
    end)
end)

-- The own roll from the server's system line: the number for the status line; a /roll typed in
-- the chat counts as the click (a second roll would not count at the loot lead either).
ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    if #rounds == 0 then return end
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    if not matcher then matcher = ns.BuildMatcher(RANDOM_ROLL_RESULT) end
    local a = matcher(text)
    -- the own line only: a first name alone counts while only one raider carries it (another
    -- raider's number never shows as the own, nor closes the own buttons)
    if not a or not ns.SameNameIn(a[1], me(), ns.GroupRoster()) then return end
    local value, low, high = tonumber(a[2]), tonumber(a[3]), tonumber(a[4])
    local kind = (low == 1 and high == 100 and "MS") or (low == 1 and high == 99 and "OS") or nil
    if not kind or not value then return end
    for _, r in ipairs(rounds) do
        if not r.done and (r.art == "R" or r.tie) and not r.rolled then
            if r.choice ~= "MS" and r.choice ~= "OS" then r.choice = kind end
            if r.choice == kind then r.rolled = value end
            refresh()
            return
        end
    end
end)

ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    refresh()
    -- the state is final only after the dispatch
    C_Timer.After(0, refresh)
end)
-- an item the client just loaded: its name, and the hints that need it (the upgrade)
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if not (F and F:IsShown()) then return end
    for _, r in ipairs(rounds) do
        if not r.name and not r.done then
            local ok, hints = pcall(hintsOf, r)
            if ok then r.hints = hints end
        end
    end
    refresh()
end)

---------------------------------------------------------------------------
-- The test round, settings, command
---------------------------------------------------------------------------
local TEST_ART = { dkp = "B", gebot = "B", bid = "B", bedarf = "N", need = "N", epgp = "N" } -- l10n-ok: typed sub-words

-- A round only on this client, with an item (a link, else the hearthstone) and art "R", "B" or "N":
-- nothing is sent; Mainspec and Offspec roll for real (only the own chat shows it when alone).
function ns.RollWindowTest(link, art)
    art = art or "R"
    local my = me()
    local item = itemString(link) or ("item:" .. TEST_ITEM)
    local f = { "7e57", item, tostring(TEST_SECONDS), art, "-", okName(my) and my or "-",
                art == "B" and "10" or (art == "N" and "50") or "-", art == "N" and "25" or "-", "-" }
    local r = startRound(f, nil, nil, { test = true })
    return r and F or nil
end

-- What tests and the snapshot scene reach: start and end a round as the messages do.
ns._rollWindow = { start = startRound, finish = endRound, rounds = function() return rounds end, refresh = function() refresh() end }

ns.RegisterSettings{ key = "rollwin", label = L["Würfel-Fenster"], order = 21, items = {
    { key = "rollwin.enabled", type = "toggle", label = L["Würfel-Fenster zeigen, wenn die Lootleitung eine Runde startet"], default = true,
      tip = L["Ein kleines Fenster mit dem Item und den Knöpfen Mainspec (1-100), Offspec (1-99) und Passen. Gewürfelt wird über das Spiel, Passen geht nur an die Lootleitung."] },
    { key = "rollwin.onlyMine", type = "toggle", label = L["Nur zeigen, wenn reserviert, Upgrade oder Wunsch"], default = false },
    { key = "rollwin.sound", type = "toggle", label = L["Ton, wenn das Fenster aufgeht"], default = true },
    { key = "rollwin.self", type = "toggle", label = L["Auch bei eigenen Runden (Lootleitung)"], default = true, officer = true },
    { key = "rollwin.scale", type = "slider", label = L["Größe des Würfel-Fensters (%)"], default = 100, min = 70, max = 150, step = 5,
      onChange = function() applyScale() end },
    { key = "rollwin.reset", type = "button", label = L["Position zurücksetzen##Würfel-Fenster"],
      run = function()
          ns.ResetRollWindowPosition()
          ns.msg(L["Würfel-Fenster: Position zurückgesetzt."])
      end },
}}

ns.RegisterSlash("wuerfeln", { en = "rolltest", args = L["[test [Item-Link] [dkp|bedarf]|an|aus]"],   -- l10n-ok: the German command word
    desc = L["Würfel-Fenster: Probe nur bei dir, an- oder ausschalten"], run = function(rest, word)
        rest = ns.Plain(rest)
        rest = type(rest) == "string" and rest or ""
        local sub, tail = rest:match("^%s*(%S*)%s*(.-)%s*$")
        sub = (sub or ""):lower()
        if word == "rolltest" and sub ~= "on" and sub ~= "off" then sub, tail = "test", rest end
        if sub == "an" or sub == "on" then -- l10n-ok: typed sub-words
            ns.Set("rollwin.enabled", true)
            ns.msg(L["Würfel-Fenster an."])
        elseif sub == "aus" or sub == "off" then -- l10n-ok: typed sub-words
            ns.Set("rollwin.enabled", false)
            ns.msg(L["Würfel-Fenster aus. Runden der Lootleitung zeigen kein Fenster mehr; /amisia wuerfeln an schaltet es wieder ein."])
        elseif sub == "test" then -- l10n-ok: typed sub-word
            local art = "R"
            for w in (tail or ""):gmatch("%S+") do
                if TEST_ART[w:lower()] then art = TEST_ART[w:lower()] end
            end
            if not ns.Get("rollwin.enabled") then ns.msg(L["Das Würfel-Fenster ist aus (Einstellungen, Würfel-Fenster); die Probe zeigt es trotzdem."]) end
            ns.RollWindowTest(tail, art)
            ns.msg(L["Probe-Runde nur bei dir: nichts wird gesendet. Mainspec und Offspec würfeln wirklich (allein sieht das nur dein Chat)."])
        elseif ns.ShowSettings then
            ns.ShowSettings(L["Würfel-Fenster"])
        end
    end })
