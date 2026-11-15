-- The own notes of dungeons and raids (F-212, D-137, ns.DungeonNotes, spec docs/specs/2026-11-15-dungeon-notiz.md):
-- per dungeon or raid key a text (N.MAX_TEXT bytes) and per boss a line (N.MAX_BOSS bytes), account-wide in
-- AmisiaDB.dungeonNotes = { v = 1, list = { [dkey] = { text, at, boss = { [boss key] = text } } } }. A boss's
-- key is its encounter id as a string, or "n:" and its folded name when the facts know no encounter. Item
-- links stay; every other code, texture and control character goes (N.Clean). Nothing is ever sent.
-- Once per entry into an instance with a note (not after a /reload) a chat line with its first line and
-- the link [Notiz] (dungeonbar.noteChat); the link opens the part Notiz of the page Dungeons or Raids.
-- Fires "DUNGEON_NOTES" on every change (the pages and the dungeon bar refresh; a typed text half a second later).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local R = ns.Runs

local N = {}
ns.DungeonNotes = N

N.MAX_TEXT, N.MAX_BOSS, N.MAX_NOTES, N.MAX_BOSSES = 1000, 120, 300, 60
N.CHAT_DELAY = 3          -- seconds after the loading screen before the chat line
N.CHAT_MAX = 120          -- bytes of the note in the chat line
N.ICON = "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:12:12|t"
local LINK = "addon:Amisia:note:"
local LINK_COLOUR = "|cff4fb8ff"

local function now() return time() end

---------------------------------------------------------------------------
-- Cleaning
---------------------------------------------------------------------------
-- An item link the client writes: colour (|cff...... or |cnIQ4:), |Hitem:...|h[Name]|h|r.
local ITEM_LINK = "|c[^|]*|Hitem:[^|]+|h%[[^|%]]*%]|h|r"

-- Cuts s to max bytes without leaving half a UTF-8 letter.
local function cutBytes(s, max)
    if #s <= max then return s end
    s = s:sub(1, max)
    -- a lead byte without all its continuation bytes at the end goes
    local i = #s
    while i > 0 and s:byte(i) >= 128 and s:byte(i) < 192 do i = i - 1 end
    if i > 0 and s:byte(i) >= 192 then
        local need = s:byte(i) >= 240 and 4 or s:byte(i) >= 224 and 3 or 2
        if #s - i + 1 < need then s = s:sub(1, i - 1) end
    end
    return s
end

-- The text as Amisia keeps it: line ends as "\n" (oneLine: spaces), no control characters, no codes
-- but whole item links, no blanks at the ends, at most max bytes (a link is never cut: it goes whole).
function N.Clean(s, max, oneLine)
    if type(s) ~= "string" then return "" end
    s = s:gsub("\r\n?", "\n"):gsub("[%z\1-\9\11-\31\127]", "")
    if oneLine then s = s:gsub("\n", " ") end
    -- the links aside (as \1n\2), every other bar away, the links back
    local links = {}
    s = s:gsub(ITEM_LINK, function(l)
        links[#links + 1] = l
        return "\1" .. #links .. "\2"
    end)
    -- the other codes whole: colours, textures, atlases, other links (their text stays), then any bar left
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", ""):gsub("|", "")
    s = s:match("^%s*(.-)%s*$") or ""
    local out, size = {}, 0
    local pos = 1
    while pos <= #s do
        local a, b, n = s:find("\1(%d+)\2", pos)
        local plain = s:sub(pos, (a or #s + 1) - 1)
        if plain ~= "" then
            local piece = cutBytes(plain, max - size)
            out[#out + 1] = piece
            size = size + #piece
            if #piece < #plain then break end
        end
        if not a then break end
        local l = links[tonumber(n)] or ""
        if size + #l > max then break end
        out[#out + 1] = l
        size = size + #l
        pos = b + 1
    end
    return (table.concat(out):match("^(.-)%s*$"))
end

---------------------------------------------------------------------------
-- The saved notes
---------------------------------------------------------------------------
local function validKey(k) return type(k) == "string" and #k >= 1 and #k <= 40 and k:find("^[%w_:%-]+$") ~= nil end
local function validBossKey(k)
    return type(k) == "string" and #k <= 64 and (k:find("^%d+$") ~= nil or k:find("^n:[^|%c]+$") ~= nil)
end

-- Shapes AmisiaDB.dungeonNotes (ADDON_LOADED): keys and texts checked and cleaned, an entry without
-- any text dropped, the MAX_NOTES newest.
function N.Loaded()
    if not AmisiaDB then return nil end
    local src = AmisiaDB.dungeonNotes
    local list = type(src) == "table" and type(src.list) == "table" and src.list or {}
    local all = {}
    for k, e in pairs(list) do
        if validKey(k) and type(e) == "table" then
            local c = { text = N.Clean(e.text, N.MAX_TEXT), boss = {} }
            local at = tonumber(e.at)
            c.at = (at and at >= 0 and at <= 4e9) and math.floor(at) or 0
            local nb = 0
            if type(e.boss) == "table" then
                for bk, t in pairs(e.boss) do
                    local ct = validBossKey(bk) and N.Clean(t, N.MAX_BOSS, true) or ""
                    if ct ~= "" and nb < N.MAX_BOSSES then
                        c.boss[bk] = ct
                        nb = nb + 1
                    end
                end
            end
            if c.text ~= "" or nb > 0 then all[#all + 1] = { k = k, e = c } end
        end
    end
    table.sort(all, function(a, b)
        if a.e.at ~= b.e.at then return a.e.at > b.e.at end
        return a.k < b.k
    end)
    local out = {}
    for i = 1, math.min(#all, N.MAX_NOTES) do out[all[i].k] = all[i].e end
    AmisiaDB.dungeonNotes = { v = 1, list = out }
    return AmisiaDB.dungeonNotes
end

local function store()
    if not AmisiaDB then return nil end
    local t = AmisiaDB.dungeonNotes
    if type(t) ~= "table" or type(t.list) ~= "table" or t.v ~= 1 then t = N.Loaded() end
    return t
end

local function entry(dkey)
    local t = store()
    return t and validKey(dkey) and t.list[dkey] or nil
end

-- The note of dkey ("" without one).
function N.Get(dkey)
    local e = entry(dkey)
    return e and e.text or ""
end

-- The note of boss key bkey of dkey ("" without one).
function N.Boss(dkey, bkey)
    local e = entry(dkey)
    return e and type(e.boss) == "table" and e.boss[bkey] or ""
end

-- Whether dkey has a note or a boss note.
function N.Has(dkey)
    local e = entry(dkey)
    return e ~= nil and (e.text ~= "" or next(e.boss or {}) ~= nil)
end

-- The key of the i-th boss (name) of dkey's order: its encounter id, else "n:" and its folded name.
function N.BossKey(dkey, i, name)
    local enc = R.Encounters(dkey)
    if enc and enc[i] then return tostring(enc[i]) end
    local k = ns.Fold(name):gsub("[^%w]", "")
    return "n:" .. (k ~= "" and k or tostring(i))
end

-- Drops an entry without text; keeps at most MAX_NOTES (the oldest goes); fires.
local function changed(t, dkey, soon)
    local e = t.list[dkey]
    if e and e.text == "" and next(e.boss) == nil then t.list[dkey] = nil end
    local n, oldest = 0, nil
    for k, x in pairs(t.list) do
        n = n + 1
        if k ~= dkey and (not oldest or x.at < t.list[oldest].at) then oldest = k end
    end
    if n > N.MAX_NOTES and oldest then t.list[oldest] = nil end
    if soon then ns.FireSoon("DUNGEON_NOTES") else ns.Fire("DUNGEON_NOTES", dkey) end
end

local function ensure(t, dkey)
    local e = t.list[dkey]
    if not e then
        e = { text = "", at = now(), boss = {} }
        t.list[dkey] = e
    end
    return e
end

-- Sets the note of dkey (cleaned); "" deletes it. Returns the text kept, or nil for a bad key.
function N.Set(dkey, text)
    local t = store()
    if not (t and validKey(dkey)) then return nil end
    text = N.Clean(text, N.MAX_TEXT)
    local e = t.list[dkey]
    if (e and e.text or "") == text then return text end
    e = ensure(t, dkey)
    e.text, e.at = text, now()
    -- typed letter by letter: the others hear of it once a moment later
    changed(t, dkey, true)
    return text
end

-- Sets the note of boss key bkey of dkey (one line, cleaned); "" deletes it.
function N.SetBoss(dkey, bkey, text)
    local t = store()
    if not (t and validKey(dkey) and validBossKey(bkey)) then return nil end
    text = N.Clean(text, N.MAX_BOSS, true)
    local e = t.list[dkey]
    if (e and e.boss[bkey] or "") == text then return text end
    e = ensure(t, dkey)
    local n = 0
    for _ in pairs(e.boss) do n = n + 1 end
    if text ~= "" and not e.boss[bkey] and n >= N.MAX_BOSSES then return nil end
    e.boss[bkey] = text ~= "" and text or nil
    e.at = now()
    changed(t, dkey)
    return text
end

-- Deletes the note of dkey with its boss notes.
function N.Clear(dkey)
    local t = store()
    if not (t and t.list[dkey]) then return end
    t.list[dkey] = nil
    ns.Fire("DUNGEON_NOTES", dkey)
end

-- The bosses of dkey in the game's order: { { i, name, key, text } }, then the boss notes no boss of
-- the order has any more (a renamed or removed boss): { key, name = nil, text }.
function N.Bosses(dkey)
    local out, seen = {}, {}
    local order = ns.Dungeons and ns.Dungeons.BossOrder(dkey) or nil
    for i, name in ipairs(order or {}) do
        local k = N.BossKey(dkey, i, name)
        seen[k] = true
        out[#out + 1] = { i = i, name = name, key = k, text = N.Boss(dkey, k) }
    end
    local e = entry(dkey)
    local rest = {}
    for k, t in pairs(e and e.boss or {}) do
        if not seen[k] then rest[#rest + 1] = { key = k, text = t } end
    end
    table.sort(rest, function(a, b) return a.key < b.key end)
    for _, b in ipairs(rest) do out[#out + 1] = b end
    return out
end

-- The boss notes of dkey that are set: { { name, text } } in the game's order (a gone boss: "?").
function N.BossNotes(dkey)
    local out = {}
    for _, b in ipairs(N.Bosses(dkey)) do
        if b.text ~= "" then out[#out + 1] = { name = b.name or "?", text = b.text } end
    end
    return out
end

-- The first line of the note of dkey with text, cut to max bytes (a link whole or not at all), or "".
function N.FirstLine(dkey, max)
    for line in (N.Get(dkey) .. "\n"):gmatch("(.-)\n") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local cut = N.Clean(line, max or N.CHAT_MAX, true)
            return #cut < #line and (cut .. " ...") or cut
        end
    end
    return ""
end

-- Up to n lines of the note of dkey for a tooltip (then "...", the boss notes counted).
function N.Preview(dkey, n)
    local out = {}
    local lines = {}
    for line in (N.Get(dkey) .. "\n"):gmatch("(.-)\n") do
        if line:match("%S") then lines[#lines + 1] = line end
    end
    for i = 1, math.min(#lines, n or 3) do out[#out + 1] = lines[i] end
    if #lines > (n or 3) then out[#out + 1] = "..." end
    local nb = #N.BossNotes(dkey)
    if nb > 0 then out[#out + 1] = L["Boss-Notizen: %d"]:format(nb) end
    return out
end

-- The tooltip lines of the note of dkey (GameTooltip is open): a head and the preview.
function N.AddTooltip(dkey)
    if not N.Has(dkey) then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(N.ICON .. " " .. L["Deine Notiz"], 1, 0.82, 0)
    for _, line in ipairs(N.Preview(dkey, 3)) do GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
end

---------------------------------------------------------------------------
-- The chat line on entering, the link
---------------------------------------------------------------------------
-- The key with a note among the instance stood in (sure) or its candidates, or nil.
function N.HereKey()
    local k, sure, keys = R.Here()
    if not k then return nil end
    if N.Has(k) then return k end
    if sure == false and keys then
        for _, c in ipairs(keys) do
            if N.Has(c) then return c end
        end
        return nil
    end
    return N.Has(k) and k or nil
end

function N.ChatLine(dkey)
    local f = R.Fact(dkey)
    local name = f and ns.Dungeons.Name(f) or dkey
    local first = N.FirstLine(dkey)
    if first == "" then first = L["Boss-Notizen: %d"]:format(#N.BossNotes(dkey)) end
    return L["Notiz zu %s: %s"]:format(name, first) .. " " .. ("%s|H%s%s|h[%s]|h|r"):format(LINK_COLOUR, LINK, dkey, L["Notiz##Link"])
end

local announced          -- R.entry of the last entry looked at
-- After a loading screen: the chat line once per entry into an instance with a note (reload: the entry
-- is only marked, so a /reload inside says nothing again).
function N.Announce(reload)
    local inst = R.Here()
    if not inst or R.entry == announced then return end
    announced = R.entry
    if reload or ns.Get("dungeonbar.noteChat") == false then return end
    local k = N.HereKey()
    if k then ns.msg(N.ChatLine(k)) end
end

ns.OnEvent("PLAYER_ENTERING_WORLD", function(_, reload)
    C_Timer.After(N.CHAT_DELAY, function() N.Announce(reload) end)
end)

-- A click on [Notiz]: the part Notiz of the page Dungeons or Raids.
function N.OnLink(_, link)
    if type(link) ~= "string" or link:sub(1, #LINK) ~= LINK then return end
    local dkey = link:sub(#LINK + 1)
    if validKey(dkey) and ns.ShowDungeon then ns.ShowDungeon(dkey, "note") end
end

do
    local reg = _G.EventRegistry
    if type(reg) == "table" and type(reg.RegisterCallback) == "function" then
        pcall(reg.RegisterCallback, reg, "SetItemRef", N.OnLink, N)
    end
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then N.Loaded() end
end)

-- for the tests
function N._reset() announced = nil end
end)
