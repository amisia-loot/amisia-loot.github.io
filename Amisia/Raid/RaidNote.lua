-- Amisia raid note (F-196, spec docs/specs/2026-11-13-raid-notiz.md, D-126): a note for cooldowns and
-- assignments that an officer, the raid leader or an assistant (a guild member in the own raid) sends to
-- the raid. The sender announces it "NV <id> <hash> <lines>" into the raid after sending, every 240 s and
-- soon after someone joins; a client without it asks by whisper "NQ <id> <own hash>" and gets the blob
-- "RN" ({ v = 1, id, at, t }); the first send goes into the raid unasked. A note is taken only from a
-- sender allowed by the receiver's own roster, checked whole, its hash the text's. Shown in the window
-- (Raid/RaidNoteWindow.lua) with raid marks for {stern}/{star}/{rt1} ..., raid members in their class
-- colour and the own lines in gold; the text from outside is defused first (every "|" doubled).
-- Saved: AmisiaDB.raidNote = { v = 1, sets = { { name, text, at } } (30), cur = { id, at, by, text, h },
-- party = { id, at, by, text, h }, draft, own } (the own note never travels).
-- The group note (F-213, D-138, spec docs/specs/2026-11-15-gruppen-notiz.md): in an own party (not a raid) the
-- party leader sends the note (RN.PARTY_CHARS bytes, RN.PARTY_LINES lines) to the party as up to RN.PARTY_PARTS
-- control messages "TN <id> <i> <n> <hash> <piece>" (no blob: those stay the guild's, D-12); taken from the leader
-- by the receiver's own party, also outside the guild (raidnote.party), checked whole by its hash. A member who
-- joins or reloads asks "TQ <id> <hash>"; the leader sends it again (also soon after a join). Leaving the party
-- drops it. The window shows it in a party, the raid note in a raid.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local RN = {}
ns.RaidNote = RN

RN.MAX_CHARS, RN.MAX_LINES, RN.MAX_OWN, RN.MAX_SETS, RN.MAX_SET_NAME = 4000, 120, 1000, 30, 24
RN.PARTY_CHARS, RN.PARTY_LINES, RN.PARTY_PARTS, RN.PIECE = 1000, 20, 6, 180
local PARTS_TTL = 30          -- seconds a group note's parts wait for the rest
local RESEND_GAP = 10         -- the leader sends his group note again at most this often
local TQ_GAP = 30             -- a member asks for the group note at most this often
local NV_EVERY = 240          -- the sender repeats his announcement this often
local NV_GAP = 10             -- and not more often than this
local SEND_GAP = 10           -- one note per sender this often (the receivers keep the same)
local ANSWER_EVERY = 30       -- one blob per asker and note this often
local NOTE_TTL = 12 * 3600    -- a note older than this is no longer announced nor taken
local NOTE_AHEAD = 300        -- nor one dated more than this ahead of the own clock

local lastNV                  -- { id, h, t }: the last own announcement
local lastSend = -1e9         -- GetTime() of the last own note
local asks = {}               -- asker -> note id
local answered = {}           -- asker -> { h, t }
local wanted = {}             -- sender -> { id, h }: the note asked for
local pendingShow = false     -- a new note came in a fight while the window was closed
local lastTaken = {}          -- sender -> GetTime() of the last note taken from him
local stats = { sent = 0, taken = 0, refused = 0 }

local function now() return GetTime() end
local report = ns.ReportError

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function clip(s, max)
    if type(s) ~= "string" then return "" end
    s = s:gsub("\r\n?", "\n"):gsub("[%z\1-\9\11-\31\127]", "")
    if #s > max then
        s = s:sub(1, max)
        -- not in the middle of a UTF-8 letter
        s = s:gsub("[\192-\255][\128-\191]*$", "")
    end
    return s
end
RN.Clip = clip

local function lineCount(s)
    if s == "" then return 0 end
    local _, n = s:gsub("\n", "")
    return n + 1
end
RN.LineCount = lineCount

-- The text as the note may carry it: control characters out, at most MAX_LINES lines and MAX_CHARS bytes
-- (maxChars, maxLines: other bounds, the group note's).
function RN.CleanText(s, maxChars, maxLines)
    maxChars, maxLines = maxChars or RN.MAX_CHARS, maxLines or RN.MAX_LINES
    s = clip(s, maxChars)
    if lineCount(s) > maxLines then
        local out, n = {}, 0
        for line in (s .. "\n"):gmatch("(.-)\n") do
            n = n + 1
            if n > maxLines then break end
            out[n] = line
        end
        s = table.concat(out, "\n")
    end
    return s
end

-- The text as a group note may carry it (F-213).
function RN.CleanParty(s) return RN.CleanText(s, RN.PARTY_CHARS, RN.PARTY_LINES) end

local function validCur(c)
    return type(c) == "table" and type(c.id) == "number" and type(c.at) == "number" and type(c.by) == "string"
        and type(c.text) == "string" and #c.text <= RN.MAX_CHARS and type(c.h) == "string"
end

function RN.DB()
    if not AmisiaDB then return nil end
    local d = AmisiaDB.raidNote
    if type(d) ~= "table" or d.v ~= 1 then
        d = { v = 1 }
        AmisiaDB.raidNote = d
    end
    if type(d.sets) ~= "table" then d.sets = {} end
    for i = #d.sets, 1, -1 do
        local s = d.sets[i]
        if type(s) ~= "table" or type(s.name) ~= "string" or s.name == "" or type(s.text) ~= "string" then
            table.remove(d.sets, i)
        end
    end
    while #d.sets > RN.MAX_SETS do table.remove(d.sets) end
    if d.cur ~= nil and not validCur(d.cur) then d.cur = nil end
    if d.party ~= nil and not (validCur(d.party) and #d.party.text <= RN.PARTY_CHARS) then d.party = nil end
    if type(d.draft) ~= "string" then d.draft = nil end
    if type(d.own) ~= "string" then d.own = nil end
    return d
end

function RN.Current() local d = RN.DB() return d and d.cur end
function RN.Party() local d = RN.DB() return d and d.party end

-- "raid" in an own raid, "party" in an own party of five, else nil (F-213).
function RN.Mode()
    if ns.HomeRaid() then return "raid" end
    if ns.HomeGroup() then return "party" end
    return nil
end

-- The note the window and the page show now: the group note in a party, else the raid note.
function RN.Shown()
    if RN.Mode() == "party" then return RN.Party() end
    return RN.Current()
end
function RN.Draft() local d = RN.DB() return d and d.draft or "" end
function RN.Own() local d = RN.DB() return d and d.own or "" end

function RN.SetDraft(text)
    local d = RN.DB()
    if d then d.draft = RN.CleanText(text) end
end

function RN.SetOwn(text)
    local d = RN.DB()
    if not d then return end
    text = clip(text, RN.MAX_OWN)
    d.own = text ~= "" and text or nil
    ns.Fire("RAIDNOTE", "own")
end

-- The templates by name: { { name, text, at } }, sorted by name.
function RN.Sets()
    local d = RN.DB()
    local out = {}
    for _, s in ipairs(d and d.sets or {}) do out[#out + 1] = s end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

local function setIndex(name)
    local d = RN.DB()
    for i, s in ipairs(d and d.sets or {}) do
        if s.name:lower() == name:lower() then return i end
    end
    return nil
end

-- Saves text as the template name (the same name: replaced). true, or nil and the reason.
function RN.SaveSet(name, text)
    local d = RN.DB()
    if not d then return nil, L["Amisia ist noch nicht geladen."] end
    name = clip(name, RN.MAX_SET_NAME):gsub("|", ""):match("^%s*(.-)%s*$")
    if name == "" then return nil, L["Die Vorlage braucht einen Namen."] end
    text = RN.CleanText(text)
    if text == "" then return nil, L["Die Notiz ist leer."] end
    local i = setIndex(name)
    if not i and #d.sets >= RN.MAX_SETS then return nil, L["Höchstens %d Vorlagen."]:format(RN.MAX_SETS) end
    local entry = { name = name, text = text, at = ns.ServerTime() }
    if i then d.sets[i] = entry else d.sets[#d.sets + 1] = entry end
    ns.Fire("RAIDNOTE", "sets")
    return true, name
end

function RN.SetText(name)
    local i = type(name) == "string" and setIndex(name)
    return i and RN.DB().sets[i].text or nil
end

function RN.DeleteSet(name)
    local i = type(name) == "string" and setIndex(name)
    if not i then return false end
    table.remove(RN.DB().sets, i)
    ns.Fire("RAIDNOTE", "sets")
    return true
end

---------------------------------------------------------------------------
-- Who may send
---------------------------------------------------------------------------
-- The raid rank of a name in the own raid: 2 leader, 1 assistant, 0 member, nil not in it.
local function raidRank(name)
    if not ns.HomeRaid() then return nil end
    for i = 1, GetNumGroupMembers() or 0 do
        local raw, rank = GetRaidRosterInfo(i)
        local n = ns.FullName(ns.Plain(raw))
        if n and ns.SameNameInGroup(n, name) then return tonumber(ns.Plain(rank)) or 0 end
    end
    return nil
end
RN.RaidRank = raidRank

local function me() return ns.UnitFullName("player") end

-- Whether name leads the own party (not a raid), by the own roster (GetRaidRosterInfo: rank 2 the leader, as
-- the group index reads a party too).
local function partyLeader(name)
    if ns.HomeRaid() or not ns.HomeGroup() or type(name) ~= "string" then return false end
    for i = 1, GetNumGroupMembers() or 0 do
        local raw, rank = GetRaidRosterInfo(i)
        local n = ns.FullName(ns.Plain(raw))
        if n and ns.SameNameInGroup(n, name) then return tonumber(ns.Plain(rank)) == 2 end
    end
    return false
end
RN.PartyLeader = partyLeader

local function selfLeads()
    return not ns.HomeRaid() and ns.HomeGroup() and ns.Plain(UnitIsGroupLeader("player")) and true or false
end

-- Whether this client may send a note now: true, or false and the reason. In a party: its leader (F-213).
function RN.CanSend()
    if RN.Mode() == "party" then
        if not selfLeads() then return false, L["Senden kann nur der Gruppenleiter."] end
        return true
    end
    if not ns.HomeRaid() then return false, L["Nur in Raid oder Gruppe."] end
    local name = me()
    if not name then return false, L["Nur im Raid."] end
    if ns.IsVerifiedMember(name) == false then
        return false, L["Senden können nur Gildenmitglieder: andere Amisia nehmen Daten nur aus der Gilde an."]
    end
    local officer = ns.IsVerifiedOfficer(name) == true
    if not officer and (raidRank(name) or 0) < 1 then
        return false, L["Senden können Offiziere, der Raidleiter und Assistenten."]
    end
    return true
end

-- Whether this client may write the note and its templates: whoever may send, and an officer (or the
-- author's character, ns.SelfMayOfficer) anywhere, to prepare them before the raid. true, or false;
-- the second value: why it may not send now (nil when it may).
function RN.CanEdit()
    local ok, why = RN.CanSend()
    if ok then return true end
    if ns.SelfMayOfficer and ns.SelfMayOfficer(true) then return true, why end
    return false, why
end

-- Whether sending is held now (a fight, the lockdown): the reason, or nil.
function RN.SendHeld()
    if InCombatLockdown() then return L["Nicht im Kampf."] end
    if ns.ChatLocked and ns.ChatLocked() then return L["Nicht im Bosskampf."] end
    local wait = SEND_GAP - (now() - lastSend)
    if wait > 0 then return L["Noch %d s."]:format(math.ceil(wait)) end
    return nil
end

---------------------------------------------------------------------------
-- The text as the window shows it
---------------------------------------------------------------------------
local MARKS = {
    stern = 1, star = 1, kreis = 2, circle = 2, diamant = 3, diamond = 3, dreieck = 4, triangle = 4,
    mond = 5, moon = 5, quadrat = 6, square = 6, kreuz = 7, cross = 7, x = 7, totenkopf = 8, skull = 8,
}
for i = 1, 8 do MARKS["rt" .. i] = i end
RN.MARKS = MARKS

local function mark(word)
    local i = MARKS[word:lower()]
    if not i then return "{" .. word .. "}" end
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(i)
end

-- The raid marks of an own text (its codes stay as they are: the own dungeon note's item links, F-213).
function RN.Marks(text) return (tostring(text or ""):gsub("{(%w+)}", mark)) end

local function pattern(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- The names to colour: { { text, class } }, the longest first (a full name before its first name; a
-- first name only when one member carries it). roster: { { name, class } }, default the own raid.
local function colourNames(roster)
    if not roster then
        roster = {}
        local idx = ns.GroupIndex()
        for k, n in ipairs(idx.list) do roster[k] = { name = n, class = idx.class[k] } end
    end
    local out, firsts = {}, {}
    for _, r in ipairs(roster) do
        if type(r.name) == "string" and r.name ~= "" then
            out[#out + 1] = { r.name, r.class }
            local first = r.name:match("^(%S+) ")
            if first then
                local low = first:lower()
                firsts[low] = firsts[low] and { false } or { first, r.class }
            end
        end
    end
    for _, f in pairs(firsts) do
        if f[1] then out[#out + 1] = { f[1], f[2] } end
    end
    table.sort(out, function(a, b) return #a[1] > #b[1] end)
    return out
end

local GOLD = "|cffffd100"
-- word edges that count the bytes of UTF-8 letters as letters (a name may start or end with "Ö" or "ë")
local WORD_START, WORD_END = "%f[%w\128-\255]", "%f[^%w\128-\255]"

-- The note's text for the window: defused, the marks and the names in their colours, the lines that
-- name the player in gold. opts: roster ({ { name, class } }), self (the player's name).
function RN.Render(text, opts)
    opts = opts or {}
    if type(text) ~= "string" or text == "" then return "" end
    local names = colourNames(opts.roster)
    local self = opts.self or me()
    -- the gold by the first name alone only when one raid member carries it (as the colours)
    local selfFirst = self and self:match("^(%S+) ")
    if selfFirst then
        local unique = false
        for _, n in ipairs(names) do
            if n[1] == selfFirst then unique = true break end
        end
        if not unique and opts.roster ~= nil and #opts.roster > 0 then selfFirst = nil end
    end
    local selfPat = self and (WORD_START .. pattern(self:lower()) .. WORD_END)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local plain = line:lower()
        local mine = self and (plain:find(selfPat)
            or (selfFirst and plain:find(WORD_START .. pattern(selfFirst:lower()) .. WORD_END))) and true or false
        line = line:gsub("|", "||")
        -- the names first, as placeholders, so a name inside another is not coloured twice
        local held = {}
        for _, n in ipairs(names) do
            line = line:gsub(WORD_START .. pattern(n[1]) .. WORD_END, function(hit)
                held[#held + 1] = ns.ClassColored(hit, n[2])
                return "\1" .. #held .. "\2"
            end)
        end
        line = line:gsub("{(%w+)}", mark)
        line = line:gsub("\1(%d+)\2", function(k) return held[tonumber(k)] end)
        if mine then
            line = GOLD .. line:gsub("|r", "|r" .. GOLD) .. "|r"
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function keyOf(id) return date("%Y-%m-%d") .. ":" .. id end

local function payloadOf(c) return { v = 1, id = c.id, at = c.at, t = c.text } end

local function sendNV(force)
    local c = RN.Current()
    if not c or c.by ~= me() or not ns.HomeRaid() or InCombatLockdown() then return end
    if ns.ServerTime() - c.id > NOTE_TTL then return end
    local t = now()
    if lastNV and not force then
        if t - lastNV.t < NV_GAP then return end
        if lastNV.id == c.id and lastNV.h == c.h and t - lastNV.t < NV_EVERY then return end
    end
    if ns.CommSend("NV", { tostring(c.id), c.h, tostring(lineCount(c.text)) }, "RAID", nil, { ttl = 60, key = "NV" }) then
        lastNV = { id = c.id, h = c.h, t = t }
    end
end

-- Sends text to the raid as the current note. true, or nil and the reason.
function RN.Send(text)
    local ok, why = RN.CanSend()
    if not ok then return nil, why end
    local held = RN.SendHeld()
    if held then return nil, held end
    if type(text) ~= "string" or text:match("^%s*$") then return nil, L["Die Notiz ist leer."] end
    if RN.Mode() == "party" then return RN.SendParty(text) end
    if RN.CleanText(text) ~= text then
        return nil, L["Zu lang: höchstens %d Zeichen und %d Zeilen."]:format(RN.MAX_CHARS, RN.MAX_LINES)
    end
    local id = ns.ServerTime()
    local c = { id = id, at = id, by = me(), text = text, h = ns.Checksum(text) }
    local sent, err = ns.CommSendBlob("RN", keyOf(id), payloadOf(c), "RAID", nil, { ttl = 60 })
    if not sent then return nil, err end
    RN.DB().cur = c
    lastSend = now()
    lastNV = { id = c.id, h = c.h, t = now() }
    answered = {}
    stats.sent = stats.sent + 1
    ns.Fire("RAIDNOTE", "cur")
    C_Timer.After(SEND_GAP + 0.1, function() ns.Fire("RAIDNOTE", "gap") end)
    return true
end

local function sendNotes()
    local c = RN.Current()
    local who = {}
    for s, id in pairs(asks) do
        if c and id == c.id then who[#who + 1] = s end
    end
    asks = {}
    if not c or c.by ~= me() then return end
    local t, fresh = now(), {}
    for _, w in ipairs(who) do
        local last = answered[w]
        if not (last and last.h == c.h and t - last.t < ANSWER_EVERY) then
            fresh[#fresh + 1] = w
            answered[w] = { h = c.h, t = t }
        end
    end
    if #fresh == 0 then return end
    local tbl = payloadOf(c)
    ns.AnswerAskers(fresh, "RN", function(chan, target, opts)
        ns.CommSendBlob("RN", keyOf(c.id), tbl, chan, target, opts)
    end)
end
local askNote = ns.AnswerBatch(sendNotes)

---------------------------------------------------------------------------
-- The group note (F-213): sending
---------------------------------------------------------------------------
-- The text for the messages: %, |, line end and tab as %XX.
local function encode(s) return (s:gsub("[%%|\n\t]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function decode(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
RN.Encode, RN.Decode = encode, decode

-- The encoded text in pieces of at most RN.PIECE bytes, never cut inside an escape or a UTF-8 letter.
function RN.Pieces(enc)
    local out, pos = {}, 1
    while pos <= #enc do
        local e = math.min(#enc, pos + RN.PIECE - 1)
        if e < #enc then
            if enc:sub(e, e) == "%" then e = e - 1 elseif enc:sub(e - 1, e - 1) == "%" then e = e - 2 end
            while e > pos and (enc:byte(e + 1) or 0) >= 128 and (enc:byte(e + 1) or 0) < 192 do e = e - 1 end
        end
        out[#out + 1] = enc:sub(pos, e)
        pos = e + 1
    end
    return out
end

local lastResend = -1e9
local resendPending = false
local resendWanted = false    -- a join or a question waits for the next resend
local resendLocked = false    -- a resend waits for the end of the chat lockdown

-- The own group note's parts to the party; true when every part was queued.
local function sendParts(c)
    local ps = RN.Pieces(encode(c.text))
    if #ps == 0 or #ps > RN.PARTY_PARTS then return false end
    local all = true
    for i, piece in ipairs(ps) do
        if not ns.CommSend("TN", { tostring(c.id), tostring(i), tostring(#ps), c.h, piece }, "PARTY", nil,
            { ttl = 60, key = "TN:" .. i }) then all = false end
    end
    return all
end

-- Sends text to the party as the group note. true, or nil and the reason.
function RN.SendParty(text)
    if RN.CleanParty(text) ~= text then
        return nil, L["Zu lang: höchstens %d Zeichen und %d Zeilen."]:format(RN.PARTY_CHARS, RN.PARTY_LINES)
    end
    -- line ends and the characters % and | take three bytes each on the way
    if #RN.Pieces(encode(text)) > RN.PARTY_PARTS then
        return nil, L["Zu lang für eine Gruppen-Notiz: Zeilenumbrüche und Sonderzeichen zählen auf dem Weg dreifach."]
    end
    local id = ns.ServerTime()
    local old = RN.Party()
    if old and old.id >= id then id = old.id + 1 end
    local c = { id = id, at = id, by = me(), text = text, h = ns.Checksum(text) }
    if not sendParts(c) then return nil, L["Senden ging nicht."] end
    RN.DB().party = c
    lastSend, lastResend = now(), now()
    stats.sent = stats.sent + 1
    ns.Fire("RAIDNOTE", "party")
    C_Timer.After(SEND_GAP + 0.1, function() ns.Fire("RAIDNOTE", "gap") end)
    return true
end

-- The leader sends his group note again (a member asked or joined), at most every RESEND_GAP s; in the chat
-- lockdown once it is over (a fight alone holds nothing: addon messages go in a fight).
local function resend(again)
    if not again then resendWanted = true end
    if not resendWanted then return end
    local c = RN.Party()
    if not (c and c.by == me() and selfLeads() and RN.Fresh(c.id)) then
        resendWanted = false
        return
    end
    if ns.ChatLocked and ns.ChatLocked() then
        resendLocked = true
        return
    end
    local wait = RESEND_GAP - (now() - lastResend)
    if wait > 0 then
        if not resendPending then
            resendPending = true
            C_Timer.After(wait + 0.1, function() resendPending = false resend(true) end)
        end
        return
    end
    resendWanted = false
    lastResend = now()
    sendParts(c)
end
RN.Resend = function() resend() end

ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    if resendLocked and not (ns.ChatLocked and ns.ChatLocked()) then
        resendLocked = false
        resend(true)
    end
end)

local lastAsk = -1e9
-- A member asks the party for the group note (after joining, a login or a /reload).
local function ask()
    if RN.Mode() ~= "party" or selfLeads() or ns.Get("raidnote.party") == false then return end
    if now() - lastAsk < TQ_GAP then return end
    lastAsk = now()
    local c = RN.Party()
    ns.CommSend("TQ", { c and tostring(c.id) or "-", c and c.h or "-" }, "PARTY", nil, { ttl = 20, key = "TQ" })
end
RN.Ask = ask

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
-- Calls fn(true) when name may send notes to this client: a guild member in the own raid who is an
-- officer, the leader or an assistant.
local function allowed(name, fn)
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) or not ns.HomeRaid() then return fn(false) end
        if ns.IsVerifiedOfficer(name) == true or (raidRank(name) or 0) >= 1 then return fn(true) end
        fn(false)
    end)
end

-- A received note checked whole: the note { id, at, by, text, h }, or nil.
local function checkNote(tbl, name, key)
    if type(tbl) ~= "table" or tbl.v ~= 1 or type(tbl.t) ~= "string" then return nil end
    local id, at = tbl.id, tbl.at
    if type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > 4e9 or type(at) ~= "number" or at ~= id then return nil end
    if not RN.Fresh(id) then return nil end
    if type(key) ~= "string" or not key:match(":" .. id .. "$") then return nil end
    if tbl.t == "" or RN.CleanText(tbl.t) ~= tbl.t then return nil end
    return { id = id, at = at, by = name, text = tbl.t, h = ns.Checksum(tbl.t) }
end

-- Whether a note id (its sender's clock) is recent: not older than NOTE_TTL, not far ahead.
function RN.Fresh(id)
    local t = ns.ServerTime()
    return type(id) == "number" and id >= t - NOTE_TTL and id <= t + NOTE_AHEAD
end

local function take(c)
    local d = RN.DB()
    if not d then return end
    d.cur = c
    stats.taken = stats.taken + 1
    lastTaken[c.by] = now()
    ns.Fire("RAIDNOTE", "cur")
    if ns.Get("raidnote.chat") then
        ns.msg(L["Raid-Notiz von %s (%d Zeilen). /amisia notiz zeigt sie."]:format(c.by, lineCount(c.text)))
    end
    if ns.Get("raidnote.autoShow") and RN.Window and not RN.Window.Shown() then
        if InCombatLockdown() then pendingShow = true else RN.Window.Show() end
    end
end

-- Whether a note (id, by) is newer than the held one.
local function newer(id, by)
    local c = RN.Current()
    if not c then return true end
    if c.id == id and c.by == by then return false end
    return id >= c.id
end

ns.CommOn("NV", function(sender, f, chan)
    if chan ~= "RAID" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local id, h = tonumber(f[1]), f[2]
    if not RN.Fresh(id) then return end
    allowed(name, function(ok)
        if not ok then return end
        local c = RN.Current()
        if c and c.id == id and c.h == h then return end
        if not newer(id, name) and not (c and c.id == id and c.by == name) then return end
        wanted[name] = { id = id, h = h }
        ns.CommSend("NQ", { tostring(id), (c and c.h) or "-" }, "WHISPER", sender,
            { jitter = 2.75, ttl = 60, key = "NQ:" .. name })
    end)
end)

ns.CommOn("NQ", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        local c = RN.Current()
        if not c or c.by ~= me() or c.id ~= tonumber(f[1]) then return end
        asks[sender] = c.id
        askNote()
    end)
end)

ns.CommOnBlob("RN", function(sender, tbl, chan, key)
    local name = ns.TrustName(sender)
    if not name then return end
    allowed(name, function(ok)
        if not ok then stats.refused = stats.refused + 1 return end
        local c = checkNote(tbl, name, key)
        if not c then stats.refused = stats.refused + 1 return end
        local want = wanted[name]
        if want and want.id == c.id then
            -- asked for: it must be the one announced
            if want.h ~= c.h then stats.refused = stats.refused + 1 return end
            wanted[name] = nil
        elseif chan ~= "RAID" then
            -- a whisper nobody asked for
            stats.refused = stats.refused + 1
            return
        elseif lastTaken[name] and now() - lastTaken[name] < SEND_GAP - 1 then
            stats.refused = stats.refused + 1
            return
        end
        if not newer(c.id, name) then return end
        take(c)
    end)
end)

-- The group note (F-213): parts from the leader of the own party, put together and checked whole.
local partial = {}            -- "<sender>:<id>:<hash>" -> { by, id, h, n, parts, got, t } (two notes of one sender may cross)

local function takeParty(c)
    local d = RN.DB()
    if not d then return end
    d.party = c
    stats.taken = stats.taken + 1
    ns.Fire("RAIDNOTE", "party")
    if ns.Get("raidnote.chat") then
        ns.msg(L["Gruppen-Notiz von %s (%d Zeilen). /amisia notiz zeigt sie."]:format(c.by, lineCount(c.text)))
    end
    if ns.Get("raidnote.autoShow") and RN.Window and not RN.Window.Shown() then
        if InCombatLockdown() then pendingShow = true else RN.Window.Show() end
    end
end

ns.CommOn("TN", function(sender, f, chan)
    if chan ~= "PARTY" or ns.Get("raidnote.party") == false then return end
    local name = ns.TrustName(sender)
    if not name then return end
    if not partyLeader(name) then stats.refused = stats.refused + 1 return end
    local id, i, n, h = tonumber(f[1]), tonumber(f[2]), tonumber(f[3]), f[4]
    if not RN.Fresh(id) then return end
    local cur = RN.Party()
    if cur and cur.by == name and cur.id == id and cur.h == h then return end
    if cur and cur.by == name and cur.id > id then return end
    -- the sets of parts: old ones go, at most two per sender
    local t, mine = now(), 0
    for k, x in pairs(partial) do
        if t - x.t > PARTS_TTL then partial[k] = nil elseif x.by == name then mine = mine + 1 end
    end
    local key = name .. ":" .. id .. ":" .. h
    local p = partial[key]
    if p and p.n ~= n then return end
    if not p then
        if mine >= 2 then return end
        p = { by = name, id = id, h = h, n = n, parts = {}, got = 0, t = t }
        partial[key] = p
    end
    if not p.parts[i] then
        p.parts[i] = f[5]
        p.got = p.got + 1
    end
    if p.got < n then return end
    partial[key] = nil
    local text = decode(table.concat(p.parts))
    if text:match("^%s*$") or ns.Checksum(text) ~= h or RN.CleanParty(text) ~= text then
        stats.refused = stats.refused + 1
        return
    end
    -- a newer note of the same leader came first
    cur = RN.Party()
    if cur and cur.by == name and cur.id > id then return end
    takeParty({ id = id, at = id, by = name, text = text, h = h })
end)

ns.CommOn("TQ", function(sender, f, chan)
    if chan ~= "PARTY" then return end
    local name = ns.TrustName(sender)
    if not name or not ns.InMyGroup(name) then return end
    local c = RN.Party()
    if not c or c.by ~= me() then return end
    if f[1] == tostring(c.id) and f[2] == c.h then return end
    resend()
end)

function RN.Stats() return stats end

-- someone joined: the next tick announces again
local members = 0
local wasParty = false
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    local n = GetNumGroupMembers() or 0
    if n > members and lastNV then lastNV.h = nil end
    local mode = RN.Mode()
    -- the group note (F-213): the leader sends it to a newcomer, a new member asks, out of the party it goes
    if mode == "party" and n > members then C_Timer.After(3, function() resend() end) end
    local d = RN.DB()
    if mode == "party" and not wasParty then
        C_Timer.After(4, ask)
        -- a note kept from another party (a logout in it) is not this party's
        local c = d and d.party
        if c and c.by ~= me() and not ns.InMyGroup(c.by) then
            d.party = nil
            ns.Fire("RAIDNOTE", "party")
        end
    end
    -- a real leave (not a roster read before the group is known): the note goes
    if wasParty and not ns.HomeGroup() and d and d.party then
        d.party = nil
        partial = {}
        ns.Fire("RAIDNOTE", "party")
    end
    wasParty = mode == "party"
    members = n
end)

ns.OnEvent("PLAYER_ENTERING_WORLD", function(login, reload)
    if login or reload then C_Timer.After(5, ask) end
    wasParty = RN.Mode() == "party"
    -- after a login or /reload the group is no newcomer
    members = GetNumGroupMembers() or 0
end)

-- Opens the window now, or after the fight when one is on.
function RN.ShowSoon()
    if not RN.Window or RN.Window.Shown() then return end
    if InCombatLockdown() then pendingShow = true else RN.Window.Show() end
end

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
    if pendingShow then
        pendingShow = false
        if RN.Window and not RN.Window.Shown() then RN.Window.Show() end
    end
end)

C_Timer.NewTicker(5, ns.Perf.Wrap("Ticker RaidNote", function()
    local ok, err = pcall(sendNV)
    if not ok then report(err) end
end))

---------------------------------------------------------------------------
-- Command and settings
---------------------------------------------------------------------------
ns.RegisterSlash("notiz", { en = "note", desc = L["Raid- und Gruppen-Notiz: das Fenster zeigen oder schließen"],
    run = function()
        if RN.Window then RN.Window.Toggle() end
    end })

ns.RegisterSettings{ key = "raidnote", label = L["Raid- und Gruppen-Notiz"], order = 17, group = "raid", pages = { "raidnote" }, items = {
    { key = "raidnote.autoShow", type = "toggle", label = L["Bei neuer Raid-Notiz das Fenster öffnen"], default = true,
      tip = L["Kommt eine neue Raid-Notiz, öffnet sich ihr Fenster von selbst (im Kampf erst danach)."] },
    { key = "raidnote.chat", type = "toggle", label = L["Chatzeile bei neuer Raid-Notiz"], default = true,
      tip = L["Eine Zeile im Chat, wenn eine neue Raid-Notiz ankommt: von wem und wie viele Zeilen."] },
    { key = "raidnote.party", type = "toggle", label = L["Gruppen-Notiz annehmen"], default = true,
      tip = L["In einer Gruppe nimmt Amisia die Notiz des Gruppenleiters an, auch wenn er nicht in der Gilde ist (nur Text, ohne Links)."] },
    { key = "raidnote.dungeonOpen", type = "toggle", label = L["Fenster beim Betreten eines Dungeons öffnen"], default = true,
      tip = L["Betrittst du einen Dungeon und gibt es eine Gruppen-Notiz oder deine eigene Notiz zu ihm, öffnet sich das Fenster (im Kampf erst danach)."] },
    { key = "raidnote.font", type = "slider", label = L["Schriftgröße der Raid-Notiz"], default = 12, min = 10, max = 18, step = 1,
      tip = L["Die Schriftgröße im Fenster Raid-Notiz."],
      onChange = function() if RN.Window then RN.Window.Restyle() end end },
    { key = "raidnote.alpha", type = "slider", label = L["Hintergrund der Raid-Notiz (%)"], default = 70, min = 0, max = 100, step = 10,
      tip = L["Wie dunkel der Hintergrund des Fensters Raid-Notiz ist: 0 durchsichtig, 100 deckend."],
      onChange = function() if RN.Window then RN.Window.Restyle() end end },
    { key = "raidnote.resetPos", type = "button", label = L["Fenster Raid-Notiz zurücksetzen"],
      tip = L["Setzt Stelle, Größe und Schloss des Fensters Raid-Notiz zurück."],
      run = function() if ns.ResetRaidNotePosition then ns.ResetRaidNotePosition() end end },
} }
end)
