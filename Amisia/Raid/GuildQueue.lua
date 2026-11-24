-- Gilden-Warteschlange (F-227, D-155, ns.GuildQueue, spec docs/specs/2026-11-19-gilden-warteschlange.md; all three
-- clients): who of the guild waits for a battleground right now. The own queues come from the client
-- (UPDATE_BATTLEFIELD_STATUS, GetBattlefieldStatus per slot); each battleground goes as its number (battlegroundID,
-- which the client gives its own name: C_PvP.GetBattlegroundInfo on Forever, the returns of GetBattlegroundInfo on
-- TBC and Era), so German and English clients mean the same one; a name the client gives no number is passed over.
-- The own state goes to the guild as QW (fields "1", then up to 6 "<id>:<W|P|J|L>:<seconds>"): 2 s after a change
-- (10.5 s after the last plain one), at once when a queue pops, is joined (a hook on AcceptBattlefieldPort, before
-- the loading screen) or declined (1.1 s after the last such one), every 75 s while something is in it, once empty
-- when nothing is any more (also when bgqueue.share is switched off). Never in a battleground (the waiting QW
-- dropped) or in the chat lockdown and a boss fight's restriction (it goes once they are over; combat holds
-- nothing back), never without a guild.
-- The others' states only from members by the roster (class from it, not from the message), in memory only, 60 at
-- most, dropped 180 s after their last QW or when the client says they went offline; a popped one shows until its
-- port runs out (+3 s, 150 s without a time), "Beigetreten" 10 s, "Abgelehnt" 5 s.
-- The window "Gilden-Warteschlange" (AmisiaGuildQueue, tokens T.BGQUEUE): opens by itself while the own queue runs
-- (bgqueue.window; bgqueue.onlyOthers: only while someone of the guild is in a queue too), closes when it ends or in
-- a battleground; "/amisia warteschlange" opens it without an own queue too (view only). A bar per battleground
-- (the own first, then by members waiting, then by name) with the own wait ("4:12 / ~6 min"), under it the members
-- in their class colour (popped first, then the longest waiting, then by name). Folds to its title bar, movable,
-- its place in settings.bgQueueWindow; repainted every second while it shows.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.BGQUEUE

local GQ = {}
ns.GuildQueue = GQ

local CHANGE_WAIT = 2         -- seconds after a change before the state goes
local GAP = 10.5              -- seconds between two plain QW (the receivers drop one within 10 s)
local NEWS_GAP = 1.1          -- seconds between two QW with a P, J or L (the receivers: 1 s)
local RESEND = 75             -- seconds between two QW while something is in the queue
local LIFE = 180              -- seconds another's state lives after its last QW
local MAX_MATES = 60
local MAX_ENTRIES, MAX_WAIT, MAX_POP = 6, 3, 2
local SHOW_JOIN, SHOW_LEFT = 10, 5
local POP_EXTRA, POP_DEFAULT = 3, 150
local NEWS_KEEP = 60          -- seconds an own "joined" or "declined" waits for its message at most
local MAX_SLOTS, MAX_TYPES = 8, 32
local REBUILD_GAP = 30        -- seconds between two reads of the battleground list for an unknown name
local SOUND_GAP = 10
local TICK = 1

GQ.LIFE, GQ.MAX_MATES, GQ.RESEND = LIFE, MAX_MATES, RESEND

local function now() return GetTime() end
local function share() return ns.Get("bgqueue.share") ~= false end

local function num(v)
    v = ns.Plain(v)
    return type(v) == "number" and v or tonumber(v)
end

local function clamp(v, lo, hi)
    v = math.floor(tonumber(v) or 0)
    return math.max(lo, math.min(hi, v))
end

-- pcall of a client function that may be missing: ok and its returns, false without it.
local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- Whether this client is in a battleground (or an arena): nothing is sent there, the window is closed.
local function inBattleground()
    return ns.InPvPInstance() or ns.InBattlefield()
end
GQ.InBattleground = inBattleground

---------------------------------------------------------------------------
-- The client's battlegrounds: name <-> number
---------------------------------------------------------------------------
local byName, byId = {}, {}   -- [lower name] = id; [id] = the client's name
local builtAt

local function addType(name, id)
    name, id = ns.Plain(name), num(id)
    if type(name) ~= "string" or name == "" or not id or id < 1 or id > 99999 or id ~= math.floor(id) then return end
    byName[name:lower()] = id
    if not byId[id] then byId[id] = name end
end

-- Reads the client's list of battlegrounds again (on entering the world, for a name not in it).
function GQ.Rebuild()
    byName, byId = {}, {}
    builtAt = now()
    local pvp = rawget(_G, "C_PvP")
    local asTable = type(pvp) == "table" and pvp.GetBattlegroundInfo or nil
    local asValues = rawget(_G, "GetBattlegroundInfo")
    local okN, n = call(rawget(_G, "GetNumBattlegroundTypes"))
    n = okN and num(n) or nil
    n = clamp(n or MAX_TYPES, 0, MAX_TYPES)
    for i = 1, n do
        local done = false
        if asTable then
            local ok, info = call(asTable, i)
            if ok and type(info) == "table" then
                addType(info.name, info.battlegroundID)
                done = true
            end
        end
        if not done and asValues then
            local ok, name, _, _, _, id = call(asValues, i)
            if ok then addType(name, id) end
        end
    end
end

-- The number of a battleground by its name in this client's language, nil for a name the client gives none.
function GQ.IdOf(name)
    name = ns.Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not builtAt then GQ.Rebuild() end
    local id = byName[name:lower()]
    if not id and now() - builtAt >= REBUILD_GAP then
        GQ.Rebuild()
        id = byName[name:lower()]
    end
    return id
end

-- A battleground's name in this client's language ("Schlachtfeld 7" for a number it does not know).
function GQ.Name(id)
    if not builtAt then GQ.Rebuild() end
    return byId[id] or L["Schlachtfeld %d"]:format(id)
end

---------------------------------------------------------------------------
-- The own queues
---------------------------------------------------------------------------
-- { { id, slot, state = "W" waiting | "P" popped | "A" inside, wait = s, est = s (0 unknown), left = s } } by
-- slot, each battleground once, unknown names and arenas left out.
function GQ.ReadOwn()
    local out, seen = {}, {}
    local okM, max = call(rawget(_G, "GetMaxBattlefieldID"))
    max = okM and num(max) or nil
    max = clamp(max or 3, 1, MAX_SLOTS)
    local status = rawget(_G, "GetBattlefieldStatus")
    for i = 1, max do
        local ok, st, mapName, teamSize = call(status, i)
        st = ok and ns.Plain(st) or nil
        -- an arena (a team size, TBC) is passed over: only battlegrounds
        if (num(teamSize) or 0) > 0 then st = nil end
        if st == "queued" or st == "confirm" or st == "active" then
            local id = GQ.IdOf(mapName)
            if id and not seen[id] then
                seen[id] = true
                local e = { id = id, slot = i, state = st == "queued" and "W" or st == "confirm" and "P" or "A", wait = 0, est = 0, left = 0 }
                if e.state == "W" then
                    local okW, waited = call(rawget(_G, "GetBattlefieldTimeWaited"), i)
                    e.wait = clamp((okW and num(waited) or 0) / 1000, 0, 86400)
                    local okE, est = call(rawget(_G, "GetBattlefieldEstimatedWaitTime"), i)
                    e.est = clamp((okE and num(est) or 0) / 1000, 0, 86400)
                elseif e.state == "P" then
                    local okP, left = call(rawget(_G, "GetBattlefieldPortExpiration"), i)
                    e.left = clamp(okP and num(left) or 0, 0, 600)
                end
                out[#out + 1] = e
            end
        end
    end
    return out
end

local own = {}               -- the last read of GQ.ReadOwn
local ownState = {}          -- [id] = "W"/"P"/"A" of the last read
local news = {}              -- [id] = { s = "J"/"L", at, sent }: an own join or decline
local function readOwn()
    own = GQ.ReadOwn()
    local seen = {}
    for _, e in ipairs(own) do
        seen[e.id] = e.state
        -- popped and now inside without the hook: joined
        if ownState[e.id] == "P" and e.state == "A" and not news[e.id] then news[e.id] = { s = "J", at = now() } end
    end
    for id, was in pairs(ownState) do
        -- popped and gone without a click on "Betreten": declined or run out
        if was == "P" and not seen[id] and not news[id] then news[id] = { s = "L", at = now() } end
    end
    ownState = seen
    return own
end

-- Whether the own queue holds the battleground id (waiting or popped).
local function ownWaits(id)
    local s = ownState[id]
    return s == "W" or s == "P"
end
function GQ.OwnWaiting()
    local n = 0
    for _, s in pairs(ownState) do
        if s == "W" or s == "P" then n = n + 1 end
    end
    return n
end
function GQ.Own() return own end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local lastSig = ""          -- the state the guild has from this client ("" nothing)
local lastSentAt = -1e9     -- GetTime() of the last QW
local lastPlainAt, lastNewsAt = -1e9, -1e9
local changeSeenAt          -- GetTime() a change of the state was first seen

-- The entries to send: J and L first, then the popped, then the waiting; at most 6 (3 waiting, 2 popped).
-- { { id, s, sec } } and their signature (without the seconds).
local function entries()
    local list = {}
    if not share() then return list, "" end
    local t = now()
    local used, nWait, nPop = {}, 0, 0
    for id, x in pairs(news) do
        local keep = t - x.at <= NEWS_KEEP
        -- a join stays the state while the client still shows the port or the inside (one not sent before the
        -- battleground never goes after it); a decline goes once
        if x.s == "J" and not (ownState[id] == "P" or ownState[id] == "A") then keep = false end
        if x.s == "L" and x.sent then keep = false end
        if ownState[id] == "W" then keep = false end
        if not keep then
            news[id] = nil
        elseif #list < MAX_ENTRIES then
            list[#list + 1] = { id = id, s = x.s, sec = 0 }
            used[id] = true
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    for _, e in ipairs(own) do
        if e.state == "P" and not used[e.id] and nPop < MAX_POP and #list < MAX_ENTRIES then
            list[#list + 1] = { id = e.id, s = "P", sec = e.left }
            used[e.id], nPop = true, nPop + 1
        end
    end
    for _, e in ipairs(own) do
        if e.state == "W" and not used[e.id] and nWait < MAX_WAIT and #list < MAX_ENTRIES then
            list[#list + 1] = { id = e.id, s = "W", sec = e.wait }
            used[e.id], nWait = true, nWait + 1
        end
    end
    local parts = {}
    for i, e in ipairs(list) do parts[i] = e.id .. ":" .. e.s end
    return list, table.concat(parts, ",")
end

local function hasNews(list)
    for _, e in ipairs(list) do
        if e.s ~= "W" then return true end
    end
    return false
end

-- Whether a P, J or L of list is not in the state the guild has (it goes at once).
local function freshNews(list)
    local had = {}
    for part in lastSig:gmatch("[^,]+") do had[part] = true end
    for _, e in ipairs(list) do
        if e.s ~= "W" and not had[e.id .. ":" .. e.s] then return true end
    end
    return false
end

-- Combat holds nothing back (F-227): only a battleground, the chat lockdown and the encounter
-- restriction of a boss fight do.
local function heldBack()
    if not ns.CommAvailable() or not ns.InGuild() or inBattleground() then return true end
    if ns.CommHeld() or ns.ChatLocked() or ns.AddOnRestricted(1) then return true end
    return false
end

-- The fields of a QW for list.
function GQ.Fields(list)
    local fields = { "1" }
    for _, e in ipairs(list) do fields[#fields + 1] = ("%d:%s:%d"):format(e.id, e.s, e.sec) end
    return fields
end

-- Sends the own state when it is due. true when a QW went.
local function update()
    if inBattleground() then
        ns.CommCancel("QW")
        return false
    end
    local list, sig = entries()
    local t = now()
    local due
    if sig ~= lastSig then
        changeSeenAt = changeSeenAt or t
        due = freshNews(list) and t or changeSeenAt + CHANGE_WAIT
    elseif #list > 0 and t - lastSentAt >= RESEND then
        due = t
    else
        changeSeenAt = nil
        return false
    end
    if t < due then return false end
    local newsMsg = hasNews(list)
    if newsMsg then
        if t - lastNewsAt < NEWS_GAP then return false end
    elseif t - lastPlainAt < GAP then
        return false
    end
    if heldBack() then return false end
    local ttl = newsMsg and 10 or 30
    if not ns.CommSend("QW", GQ.Fields(list), "GUILD", nil, { key = "QW", ttl = ttl }) then return false end
    lastSig, lastSentAt, changeSeenAt = sig, t, nil
    if newsMsg then lastNewsAt = t else lastPlainAt = t end
    for _, e in ipairs(list) do
        if news[e.id] then news[e.id].sent = true end
    end
    return true
end
GQ.Update = update

---------------------------------------------------------------------------
-- The others' states
---------------------------------------------------------------------------
local mates = {}             -- [lower name] = { name, class, heard, entries = { [id] = { s, sec, at, ends } } }
local soundAt = -1e9

local function changed() ns.FireSoon("GUILD_QUEUE") end

local function sound()
    if ns.Get("bgqueue.sound") ~= true or now() - soundAt < SOUND_GAP then return end
    soundAt = now()
    local kit = rawget(_G, "SOUNDKIT")
    pcall(PlaySound, type(kit) == "table" and kit.TELL_MESSAGE or 3081)
end

local function dropOldest()
    local oldest
    for _, m in pairs(mates) do
        if not oldest or m.heard < oldest.heard then oldest = m end
    end
    if oldest then mates[oldest.low] = nil end
end

local function take(name, f)
    local low, t = name:lower(), now()
    local old = mates[low]
    local was = old and old.entries or {}
    local list, nWait, nPop = {}, 0, 0
    for i = 2, math.min(#f, MAX_ENTRIES + 1) do
        local id, s, sec = f[i]:match("^(%d+):([WPJL]):(%d+)$")
        id, sec = tonumber(id), tonumber(sec)
        if id and not list[id] then
            local prev = was[id]
            if s == "W" then
                if nWait < MAX_WAIT then
                    nWait = nWait + 1
                    list[id] = { s = "W", sec = sec, at = t }
                end
            elseif s == "P" then
                if nPop < MAX_POP then
                    nPop = nPop + 1
                    list[id] = { s = "P", sec = sec, at = t, ends = t + (sec > 0 and sec + POP_EXTRA or POP_DEFAULT) }
                end
            elseif prev and prev.s == s then
                list[id] = prev                -- the same join or decline again: its time is not lengthened
            else
                list[id] = { s = s, sec = 0, at = t, ends = t + (s == "J" and SHOW_JOIN or SHOW_LEFT) }
            end
        end
    end
    -- a join or decline shown keeps its time when the next message leaves it out
    for id, e in pairs(was) do
        if (e.s == "J" or e.s == "L") and not list[id] and e.ends > t then list[id] = e end
    end
    local starts = false
    for id, e in pairs(list) do
        if e.s == "W" and not (was[id] and was[id].s == "W") and ownWaits(id) then starts = true end
    end
    if next(list) == nil then
        mates[low] = nil
    else
        if not old and ns.Count(mates) >= MAX_MATES then dropOldest() end
        local m = ns.GuildMember(name)
        mates[low] = { low = low, name = name, class = m and m.class ~= "" and m.class or (old and old.class) or nil,
                       heard = t, entries = list }
    end
    if starts then sound() end
    changed()
end

ns.CommOn("QW", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok then take(name, f) end
    end)
end)

local function drop(low)
    if mates[low] then
        mates[low] = nil
        changed()
    end
end

-- Another's state ran out: the whole 180 s after its last QW, a popped one after its port, a join or decline
-- after its time; a member the roster says is offline.
local function expire(t)
    for low, m in pairs(mates) do
        local gm = ns.GuildMember(m.name)
        if t - m.heard > LIFE or (gm and gm.online == false) then
            drop(low)
        else
            local any = false
            for id, e in pairs(m.entries) do
                if e.ends and t > e.ends then
                    m.entries[id] = nil
                    changed()
                else
                    any = true
                end
            end
            if not any then drop(low) end
        end
    end
end

function GQ.Get(name) return mates[tostring(name or ""):lower()] end
-- The members in a queue (waiting or popped).
function GQ.Count()
    local n = 0
    for _, m in pairs(mates) do
        for _, e in pairs(m.entries) do
            if e.s == "W" or e.s == "P" then n = n + 1 break end
        end
    end
    return n
end

-- The client's "<name> ist jetzt offline." of a guild member: its state goes.
local offPattern, offFrom
ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    text = ns.Plain(text)
    if type(text) ~= "string" or not next(mates) then return end
    local fmt = rawget(_G, "ERR_FRIEND_OFFLINE_S")
    if offFrom ~= fmt then offPattern, offFrom = ns.TemplatePattern(fmt), fmt end
    local name = offPattern and text:match(offPattern)
    name = name and ns.TemplateName(name)
    if not name then return end
    local low = name:lower()
    if mates[low] then return drop(low) end
    -- the line may name the first name only
    for k, m in pairs(mates) do
        if m.name:match("^(%S+)"):lower() == low then drop(k) end
    end
end)

---------------------------------------------------------------------------
-- What the window shows
---------------------------------------------------------------------------
local function clock(s)
    s = math.max(0, math.floor(s))
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end
GQ.Clock = clock

local RANK = { P = 1, J = 2, L = 3, W = 4 }

-- The rows: { kind = "bar", id, left, right, mine } per battleground, { kind = "mate", left, right } per member
-- under it, { kind = "foot", left } when nobody of the guild waits.
function GQ.Rows()
    local t = now()
    local bars = {}
    local function bar(id)
        if not bars[id] then bars[id] = { id = id, name = GQ.Name(id), mates = {}, waiting = 0 } end
        return bars[id]
    end
    for _, e in ipairs(own) do
        if e.state == "W" or e.state == "P" then bar(e.id).mine = e end
    end
    for _, m in pairs(mates) do
        for id, e in pairs(m.entries) do
            local b = bar(id)
            b.mates[#b.mates + 1] = { m = m, e = e, wait = e.s == "W" and e.sec + (t - e.at) or 0 }
            if e.s == "W" or e.s == "P" then b.waiting = b.waiting + 1 end
        end
    end
    local list = {}
    for _, b in pairs(bars) do list[#list + 1] = b end
    table.sort(list, function(a, b)
        if (a.mine ~= nil) ~= (b.mine ~= nil) then return a.mine ~= nil end
        if a.waiting ~= b.waiting then return a.waiting > b.waiting end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    local rows, any = {}, false
    for _, b in ipairs(list) do
        local right = ""
        local e = b.mine
        if e and e.state == "P" then
            right = T.GREEN .. L["Aufgegangen"] .. "|r"
        elseif e then
            right = clock(e.wait)
            if e.est > 0 then right = right .. L[" / ~%d min"]:format(math.max(1, math.ceil(e.est / 60))) end
        end
        rows[#rows + 1] = { kind = "bar", id = b.id, left = b.name, right = right, mine = e ~= nil }
        table.sort(b.mates, function(x, y)
            local rx, ry = RANK[x.e.s], RANK[y.e.s]
            if rx ~= ry then return rx < ry end
            if x.wait ~= y.wait then return x.wait > y.wait end
            return x.m.name < y.m.name
        end)
        for _, x in ipairs(b.mates) do
            any = true
            local s = x.e.s
            local r = s == "W" and clock(x.wait) or s == "P" and (T.GREEN .. L["Aufgegangen"] .. "|r")
                or s == "J" and L["Beigetreten"] or (T.GREY .. L["Abgelehnt"] .. "|r")
            rows[#rows + 1] = { kind = "mate", id = b.id, name = x.m.name, left = ns.ClassColored(x.m.name, x.m.class), right = r }
        end
    end
    if not any then rows[#rows + 1] = { kind = "foot", left = L["Niemand aus der Gilde wartet"] } end
    return rows
end

function GQ.Title()
    return L["Gilden-Warteschlange (%d)"]:format(GQ.Count())
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local F
local manual                -- opened by the command (also without an own queue)
local dismissed             -- the own queues' signature when the player closed the window
local hiding                -- the window hides by Amisia's own call, not the player's

local function state()
    if type(AmisiaDB) ~= "table" then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.bgQueueWindow) ~= "table" then AmisiaDB.settings.bgQueueWindow = {} end
    return AmisiaDB.settings.bgQueueWindow
end

local function ownSig()
    local parts = {}
    for _, e in ipairs(own) do
        if e.state == "W" or e.state == "P" then parts[#parts + 1] = tostring(e.id) end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

local function folded()
    local st = state()
    return st ~= nil and st.folded == true
end

local function buildRow()
    local r = CreateFrame("Frame", nil, F)
    r:SetSize(S.W - 2 * S.PAD, S.ROW_H)
    r.ground = W.Flat(r, 1, 1, 1, S.BAR_SHADE)
    r.left = W.Text(r, T.FONT.text, S.W - 2 * S.PAD - S.RIGHT_W)
    r.right = W.Text(r, T.FONT.text, S.RIGHT_W)
    r.right:SetJustifyH("RIGHT")
    r.right:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    return r
end

-- Fills a pooled row with one row of GQ.Rows: every field set anew.
local function fillRow(r, row)
    local bar, foot = row.kind == "bar", row.kind == "foot"
    r:SetHeight(bar and S.BAR_H or foot and S.FOOT_H or S.ROW_H)
    r.ground:SetShown(bar)
    r.left:SetFontObject(bar and T.FONT.head or foot and T.FONT.hint or T.FONT.text)
    r.left:ClearAllPoints()
    local indent = row.kind == "mate" and S.INDENT or 0
    r.left:SetPoint("LEFT", r, "LEFT", indent + (bar and 4 or 0), 0)
    r.left:SetWidth(S.W - 2 * S.PAD - S.RIGHT_W - indent - (bar and 4 or 0))
    r.left:SetText(row.left or "")
    r.right:SetFontObject(bar and T.FONT.body or T.FONT.text)
    r.right:SetText(row.right or "")
    r.right:SetShown(not foot)
    r.kind, r.id, r.name = row.kind, row.id, row.name
    r:Show()
end

local function refresh()
    if not F or not F:IsShown() then return end
    readOwn()
    if F.SetTitle then F:SetTitle(GQ.Title()) end
    F.minBtn.tipFolded = folded()
    F.settings:SetShown(not folded())
    if folded() then
        for _, r in ipairs(F.rows) do r:Hide() end
        F:SetHeight(S.FOLD_H)
        return
    end
    local rows = GQ.Rows()
    local items = {}
    for i = 1, math.min(#rows, S.ROWS) do
        local r = F.rows[i]
        if not r then
            r = buildRow()
            F.rows[i] = r
        end
        fillRow(r, rows[i])
        items[#items + 1] = r
    end
    for i = #items + 1, #F.rows do
        local r = F.rows[i]
        r:Hide()
        r.kind, r.id, r.name = nil, nil, nil
        r.left:SetText("")
        r.right:SetText("")
    end
    local bottom = W.Column(F, items, 0, S.PAD, -S.TOP, { right = S.PAD })
    F:SetHeight(S.TOP - bottom + S.LINK_GAP + T.CHIP_H + S.BOTTOM)
end
GQ.Refresh = refresh

local function place()
    if F then W.PlaceWindow(F, state(), "TOP", UIParent, "TOP", S.EDGE_X, -140) end
end

-- The client's red "-" (as the layer window's) left of the close button; without the template the old
-- client's smaller-window button. A click folds the window to its title bar or opens it again.
local function buildMinButton()
    local modern = F.NineSlice ~= nil
    local ok, b = pcall(CreateFrame, "Button", nil, F, "UIPanelHideButtonNoScripts")
    if not ok or not b then
        b = CreateFrame("Button", nil, F)
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Highlight", "ADD")
    end
    local size = modern and S.MIN or S.MIN_OLD
    b:SetSize(size, size)
    if F.CloseButton and modern then
        b:SetPoint("TOPRIGHT", F.CloseButton, "TOPLEFT", 0, -1)
        if F.SetBorder and not pcall(F.SetBorder, F, "ButtonFrameTemplateNoPortraitMinimizable") then
            pcall(F.SetBorder, F, "ButtonFrameTemplateNoPortrait")
        end
    elseif F.CloseButton then
        b:SetPoint("RIGHT", F.CloseButton, "LEFT", 0, 0)
    else
        b:SetPoint("TOPRIGHT", -S.MIN, 0)
    end
    b:SetScript("OnClick", function() GQ.Fold(not folded()) end)
    W.Tooltip(b, L["Einklappen"], function(self)
        return self.tipFolded and L["Klappt die Liste wieder auf."] or L["Klappt das Fenster auf seine Titelleiste zusammen."]
    end)
    return b
end

local function build()
    if F then return F end
    F = W.Window("AmisiaGuildQueue", S.W, S.FOLD_H, { title = L["Gilden-Warteschlange"], strata = "MEDIUM",
        onDragStop = function(f) W.SaveWindowPlace(f, state()) end })
    F.rows = {}
    F.minBtn = buildMinButton()
    -- the way to its switches (D-166): the section "Gilden-Warteschlange", under the rows
    F.settings = W.SettingsLink(F, "bgqueue")
    F.settings:SetPoint("BOTTOMRIGHT", -S.PAD, S.BOTTOM)
    F:HookScript("OnHide", function()
        -- closed by the player (the x, Escape): it stays closed while these own queues run
        if not hiding then
            manual = nil
            dismissed = ownSig()
        end
    end)
    place()
    return F
end

function GQ.Fold(on)
    local st = state()
    if st then st.folded = on and true or nil end
    refresh()
end

-- Whether the window should show now by itself or by the command.
function GQ.ShouldShow()
    if inBattleground() then return false end
    if manual then return true end
    if ns.Get("bgqueue.window") == false or GQ.OwnWaiting() == 0 then return false end
    if dismissed and dismissed == ownSig() then return false end
    if ns.Get("bgqueue.onlyOthers") == true and GQ.Count() == 0 then return false end
    return true
end

local function showHide()
    if GQ.OwnWaiting() == 0 or (dismissed and dismissed ~= ownSig()) then dismissed = nil end
    if inBattleground() then manual = nil end
    local want = GQ.ShouldShow()
    if want then
        build()
        if not F:IsShown() then F:Show() end
        refresh()
    elseif F and F:IsShown() then
        hiding = true
        F:Hide()
        hiding = nil
    end
end
GQ.ShowHide = showHide

function GQ.Shown() return F ~= nil and F:IsShown() end

-- /amisia warteschlange: opens the window (also without an own queue) or closes it.
function GQ.Toggle()
    if GQ.Shown() then
        F:Hide()
        return
    end
    if inBattleground() then
        ns.msg(L["Im Schlachtfeld zeigt Amisia die Gilden-Warteschlange nicht."])
        return
    end
    readOwn()
    manual, dismissed = true, nil
    showHide()
end

function ns.ResetGuildQueuePosition()
    local st = state()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

---------------------------------------------------------------------------
-- Events and the clock
---------------------------------------------------------------------------
local function step()
    readOwn()
    update()
    showHide()
end
GQ.Step = step

ns.OnEvent("UPDATE_BATTLEFIELD_STATUS", function() step() end)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function() C_Timer.After(0, function() step() end) end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    GQ.Rebuild()
    if inBattleground() then ns.CommCancel("QW") end
    step()
end)
ns.Listen("GUILD_QUEUE", function() if F and F:IsShown() then refresh() else showHide() end end)
ns.Listen("SETTING", function(path)
    if type(path) == "string" and path:find("^bgqueue%.") then step() end
end)

-- "Betreten" (accept) or "Verlassen" on the port: the state goes at once, before the loading screen.
local function onPort(slot, accept)
    local ok, st, mapName = call(rawget(_G, "GetBattlefieldStatus"), slot)
    if not ok or ns.Plain(st) ~= "confirm" then return end
    local id = GQ.IdOf(mapName)
    if not id then return end
    news[id] = { s = accept and "J" or "L", at = now() }
    -- the client's status may still say "confirm": the join is the state from now on
    if not update() then
        C_Timer.After(NEWS_GAP, function() update() end)
    end
end
if type(rawget(_G, "AcceptBattlefieldPort")) == "function" and type(hooksecurefunc) == "function" then
    hooksecurefunc("AcceptBattlefieldPort", function(slot, accept)
        local ok, err = pcall(onPort, slot, accept)
        if not ok then ns.ReportError(err) end
    end)
end

local function tick()
    local t = now()
    expire(t)
    readOwn()
    update()
    showHide()
end
C_Timer.NewTicker(TICK, ns.Perf.Wrap("Ticker GuildQueue", tick))
GQ.Tick = tick

-- for the tests
function GQ._reset()
    mates, news, own, ownState = {}, {}, {}, {}
    lastSig, lastSentAt, lastPlainAt, lastNewsAt, changeSeenAt = "", -1e9, -1e9, -1e9, nil
    manual, dismissed = nil, nil
end

---------------------------------------------------------------------------
-- Command and settings
---------------------------------------------------------------------------
ns.RegisterSlash("warteschlange", { en = "queue", desc = L["Gilden-Warteschlange für Schlachtfelder: das Fenster zeigen oder schließen"],
    run = function() GQ.Toggle() end })

ns.RegisterSettings{ key = "bgqueue", label = L["Gilden-Warteschlange"], order = 68, group = "guild", items = {
    { key = "bgqueue.share", type = "toggle", label = L["Eigene Warteschlange mit der Gilde teilen"], default = true,
      tip = L["Sagt den Gildenmitgliedern mit Amisia, für welches Schlachtfeld du wartest, wie lange schon und wann deine Warteschlange aufgeht. Nur an die eigene Gilde, nie im Schlachtfeld. Aus: die anderen sehen dich nicht mehr, du siehst sie weiter."] },
    { key = "bgqueue.window", type = "toggle", label = L["Fenster zeigen"], default = true,
      tip = L["Öffnet das Fenster \"Gilden-Warteschlange\", solange du für ein Schlachtfeld wartest, und schließt es, wenn die Warteschlange endet. /amisia warteschlange öffnet es auch so."] },
    { key = "bgqueue.onlyOthers", type = "toggle", label = L["Nur wenn noch jemand aus der Gilde wartet"], default = false,
      tip = L["Das Fenster geht von selbst erst auf, wenn außer dir noch jemand aus der Gilde in einer Warteschlange steht."] },
    { key = "bgqueue.sound", type = "toggle", label = L["Ton, wenn jemand aus der Gilde in meine Warteschlange kommt"], default = false,
      tip = L["Ein kurzer Ton, wenn ein Gildenmitglied anfängt, auf ein Schlachtfeld zu warten, auf das du auch wartest."] },
} }
end)
