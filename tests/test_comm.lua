-- Addon message layer (Comm.lua): prefixes, envelope, chunks and their reassembly, the send queue
-- with its throttle per prefix, result codes, the lockdown, battlegrounds, receive limits, debug.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Kim Eisherz", class = "WARRIOR" } }
-- data parts are only read from members of the own guild
STUB.guild = { { name = "Vuloo", rank = 1 }, { name = "Fraktur", rank = 2 }, { name = "Kim Eisherz", rank = 4 } }
local KEY = "2026-10-05:409"

local function fresh()
    STUB.tick(120)
    STUB.addon, STUB.addonTries = {}, {}
end
local function recv(prefix, text, chan, sender)
    STUB.fire("CHAT_MSG_ADDON", prefix, text, chan or "RAID", sender or "Fraktur", "", 0, 0, "", 0)
end
local function texts(prefix)
    local out = {}
    for _, m in ipairs(STUB.addon) do
        if not prefix or m.prefix == prefix then out[#out + 1] = m.text end
    end
    return out
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

---------------------------------------------------------------------------
-- prefixes and state
---------------------------------------------------------------------------
assert(STUB.prefixes.Amisia and STUB.prefixes.AmisiaD, "both prefixes registered while loading")
assert(NS.SYNC_PROTO == 1 and NS.SYNC_MIN_PROTO == 1)
assert(NS.CommAvailable() == true and NS.CommPacking() == true)
assert(NS.CommReady() == true, "sync is on by default")
NS.Set("sync.enabled", false)
assert(NS.CommReady() == false and NS.CommAvailable() == true)
NS.Set("sync.enabled", true)
assert(NS.CommQueueSize() == 0 and NS.CommHeld() == false)

---------------------------------------------------------------------------
-- envelope: writing
---------------------------------------------------------------------------
fresh()
assert(NS.CommSend("HI", { "2.1.0", "1", "O", KEY }, "RAID") == true)
assert(#STUB.addon == 1)
local m = STUB.addon[1]
assert(m.prefix == "Amisia" and m.chan == "RAID" and m.target == nil, m.prefix)
assert(m.text == "1HI\t2.1.0\t1\tO\t" .. KEY, m.text)
-- refusals: bad kind, bad fields, too long, channels that are never used
local function refused(...)
    local ok, why = NS.CommSend(...)
    return ok == nil and type(why) == "string" and why ~= ""
end
assert(refused("hi", { "x" }, "RAID"), "kind is two capitals")
assert(refused("HI", { "a\tb" }, "RAID"), "no tab inside a field")
assert(refused("HI", { "a\nb" }, "RAID"), "no line break inside a field")
assert(refused("HI", { "a|b" }, "RAID"), "no pipe inside a field")
assert(refused("HI", { string.rep("x", 247) }, "RAID"), "at most 250 bytes")
assert(NS.CommSend("HI", { string.rep("x", 246) }, "RAID") == true, "250 bytes fit")
assert(#STUB.addon[#STUB.addon].text == 250)
for _, chan in ipairs({ "INSTANCE_CHAT", "PARTY", "SAY", "CHANNEL", "OFFICER", "BATTLEGROUND" }) do
    assert(refused("HI", { "2.1.0" }, chan), chan .. " is never used")
end
assert(refused("HI", { "2.1.0" }, "WHISPER"), "a whisper needs a target")
assert(refused("HI", { "2.1.0" }, "WHISPER", "Niemand Fremdes"), "a whisper only to a name of group or guild")
assert(NS.CommSend("HI", { "2.1.0" }, "WHISPER", "Fraktur-Realm") == true, "the raw sender text of a group member")
assert(STUB.addon[#STUB.addon].target == "Fraktur-Realm" and STUB.addon[#STUB.addon].chan == "WHISPER")
STUB.inGuild = false
assert(refused("HI", { "2.1.0" }, "GUILD"), "GUILD only in a guild")
STUB.inGuild = nil
assert(NS.CommSend("HI", { "2.1.0" }, "GUILD") == true)
-- RAID only in an own raid group: never in an instance group, never alone
STUB.instanceGroup = true
assert(refused("HI", { "2.1.0" }, "RAID"), "no RAID in an instance group")
STUB.instanceGroup = nil
local roster = STUB.roster
STUB.roster = {}
assert(refused("HI", { "2.1.0" }, "RAID"), "no RAID without a raid")
STUB.roster = roster
for _, a in ipairs(STUB.addonTries) do
    assert(a.chan ~= "INSTANCE_CHAT" and a.chan ~= "PARTY", "never the instance or party channel")
end

---------------------------------------------------------------------------
-- envelope: reading
---------------------------------------------------------------------------
local got = {}
NS.CommOn("HI", function(sender, fields, chan, raw) got[#got + 1] = { sender = sender, fields = fields, chan = chan, raw = raw } end)
recv("Amisia", "1HI\t2.1.0\t1\tO\t" .. KEY, "RAID", "Fraktur")
assert(#got == 1 and got[1].sender == "Fraktur" and got[1].chan == "RAID", #got)
assert(same(got[1].fields, { "2.1.0", "1", "O", KEY }) and got[1].raw == "1HI\t2.1.0\t1\tO\t" .. KEY)
local bad0 = NS.CommStats().bad
-- a newer or older protocol is not read; the newer one is remembered
recv("Amisia", "2HI\t2.2.0\t2\t-\t-", "RAID", "Fraktur")
assert(#got == 1 and NS.CommNewerProto() == 2, "a newer protocol is not read")
recv("Amisia", "0HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
assert(#got == 1, "an older protocol is not read")
-- the wrong prefix, another addon's prefix, bad fields
recv("AmisiaD", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
recv("Fremd", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
recv("Amisia", "1HI\t2.1\t1\t-\t-", "RAID", "Fraktur")
recv("Amisia", "1HI\t2.1.0\t1\tO\t2026-10-05", "RAID", "Fraktur")
recv("Amisia", "1HI\t2.1.0\t1\tX\t-", "RAID", "Fraktur")
recv("Amisia", "1ZZ\tfoo", "RAID", "Fraktur")
recv("Amisia", "garbage", "RAID", "Fraktur")
assert(#got == 1, "nothing of that is read")
assert(NS.CommStats().bad >= bad0 + 5, "bad messages are counted")
-- field checks of the other kinds
local seenKinds = {}
for _, k in ipairs({ "VQ", "ST", "RQ", "OK", "NO", "UQ", "UA" }) do
    NS.CommOn(k, function(_, f) seenKinds[k] = (seenKinds[k] or 0) + 1 end)
end
recv("Amisia", "1VQ\t0a1F", "GUILD", "Fraktur")
recv("Amisia", "1VQ\tzz12", "GUILD", "Kim Eisherz")
recv("Amisia", "1ST\t" .. KEY .. "\t17\t0123456789abcdef\tK", "RAID", "Fraktur")
recv("Amisia", "1ST\t" .. KEY .. "\t1000000\t0123456789abcdef\tK", "RAID", "Fraktur")
recv("Amisia", "1ST\t" .. KEY .. "\t17\t0123456789abcde\tK", "RAID", "Fraktur")
recv("Amisia", "1RQ\t" .. KEY .. "\t0\tPO", "WHISPER", "Fraktur")
recv("Amisia", "1RQ\t" .. KEY .. "\t0\tX", "WHISPER", "Kim Eisherz")
recv("Amisia", "1OK\t" .. KEY .. "\ta1b2c3d4e5f6\t3", "WHISPER", "Fraktur")
recv("Amisia", "1NO\t" .. KEY .. "\ta1b2c3d4e5f6\tCONFLICT\t4", "WHISPER", "Fraktur")
recv("Amisia", "1NO\t" .. KEY .. "\ta1b2c3d4e5f6\tWHY\t4", "WHISPER", "Fraktur")
recv("Amisia", "1UQ\t00ff\t32235,32236", "RAID", "Fraktur")
recv("Amisia", "1UQ\t00fe\t32235,0", "RAID", "Kim Eisherz")
recv("Amisia", "1UA\t00ff\t32235:U:12:8:chest,32236:-:0:0:-", "WHISPER", "Fraktur")
assert(seenKinds.VQ == 1 and seenKinds.ST == 1 and seenKinds.RQ == 1 and seenKinds.OK == 1 and seenKinds.NO == 1
    and seenKinds.UQ == 1 and seenKinds.UA == 1, "only the well-formed ones are read")

-- the own echo in raid and guild is ignored
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Vuloo")
assert(#got == 1, "own echo")
-- a secret value drops the message
local secretText = "1HI\t2.1.0\t1\t-\t-"
STUB.secret[secretText] = true
recv("Amisia", secretText, "RAID", "Kim Eisherz")
STUB.secret[secretText] = nil
assert(#got == 1, "a secret text is never read")
STUB.secret["Kim Eisherz"] = true
recv("Amisia", "1HI\t2.1.0\t1\tL\t-", "RAID", "Kim Eisherz")
STUB.secret["Kim Eisherz"] = nil
assert(#got == 1, "a secret sender is never read")
-- the echo is the exact own name, also with the own realm; never a first name alone or another realm
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Vuloo-Realm")
assert(#got == 1, "own echo with the own realm")
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Vuloo Sturm")
assert(#got == 2 and got[2].sender == "Vuloo Sturm", "another character with the own first name is heard")
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Vuloo-Anderswo")
assert(#got == 3, "the own name on another realm is not the echo")

-- a failing handler goes to the error handler and does not stop the others
local caught
local handler = geterrorhandler
_G.geterrorhandler = function() return function(e) caught = e end end
local second = 0
local boom = true
NS.CommOn("VQ", function() if boom then boom = false; error("kaputt") end end)
NS.CommOn("VQ", function() second = second + 1 end)
recv("Amisia", "1VQ\tbeef", "GUILD", "Kim Eisherz")
_G.geterrorhandler = handler
assert(caught and tostring(caught):find("kaputt"), "the error reached the error handler")
assert(second == 1, "the next handler still ran")

---------------------------------------------------------------------------
-- limits per type: VQ once in 5 minutes, RQ once in 20 s, UQ once in 5 s per sender
---------------------------------------------------------------------------
fresh()
STUB.tick(301)
seenKinds = {}
recv("Amisia", "1VQ\t0001", "GUILD", "Fraktur")
recv("Amisia", "1VQ\t0002", "GUILD", "Fraktur")
assert(seenKinds.VQ == 1, "one VQ per sender in 5 minutes")
recv("Amisia", "1VQ\t0003", "GUILD", "Kim Eisherz")
assert(seenKinds.VQ == 2, "another sender is answered")
STUB.tick(301)
recv("Amisia", "1VQ\t0004", "GUILD", "Fraktur")
assert(seenKinds.VQ == 3, "after 5 minutes again")
recv("Amisia", "1RQ\t" .. KEY .. "\t0\tP", "WHISPER", "Fraktur")
recv("Amisia", "1RQ\t" .. KEY .. "\t0\tP", "WHISPER", "Fraktur")
STUB.tick(19)
recv("Amisia", "1RQ\t" .. KEY .. "\t0\tP", "WHISPER", "Fraktur")
assert(seenKinds.RQ == 1, "one RQ per sender in 20 s")
STUB.tick(1.5)
recv("Amisia", "1RQ\t" .. KEY .. "\t0\tP", "WHISPER", "Fraktur")
assert(seenKinds.RQ == 2)
recv("Amisia", "1UQ\t0010\t32235", "RAID", "Fraktur")
STUB.tick(4)
recv("Amisia", "1UQ\t0011\t32235", "RAID", "Fraktur")
assert(seenKinds.UQ == 1, "one UQ per sender in 5 s")
STUB.tick(1.5)
recv("Amisia", "1UQ\t0012\t32235", "RAID", "Fraktur")
assert(seenKinds.UQ == 2)

---------------------------------------------------------------------------
-- limits per sender: 40 messages in 10 s, 20 KB a minute
---------------------------------------------------------------------------
fresh()
got = {}
for i = 1, 41 do recv("Amisia", "1HI\t2.1." .. i .. "\t1\t-\t-", "RAID", "Fraktur") end
assert(#got == 40, "40 messages in 10 s: " .. #got)
STUB.tick(5)
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
assert(#got == 40, "ignored for 60 s")
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Kim Eisherz")
assert(#got == 41, "another sender is not affected")
STUB.tick(56)
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
assert(#got == 42, "heard again after 60 s")
fresh()
got = {}
local long = "1HI\t" .. string.rep("x", 240)
for i = 1, 80 do
    recv("Amisia", long, "RAID", "Fraktur")
    STUB.tick(0.5)
end
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
assert(#got == 1, "under 20 KB a minute: still heard")
for i = 1, 5 do
    recv("Amisia", long, "RAID", "Fraktur")
    STUB.tick(0.5)
end
recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur")
assert(#got == 1, "over 20 KB a minute: ignored")
assert(NS.CommStats().limited > 0)

---------------------------------------------------------------------------
-- chunks
---------------------------------------------------------------------------
assert(#NS.CommChunks(string.rep("A", 199)) == 1)
assert(#NS.CommChunks(string.rep("A", 200)) == 1)
local c201 = NS.CommChunks(string.rep("A", 199) .. "BC")
assert(#c201 == 2 and #c201[1] == 200 and c201[2] == "C")
assert(#NS.CommChunks(string.rep("A", 12000)) == 60)
assert(#NS.CommChunks(string.rep("A", 12001)) == 61)

-- packing round trip
local tbl = { k = KEY, r = 17, a = { { "651f3a2c9b04", "Fraktur", 32235, 1214, "MS" } }, p = { s = "week", n = { Fraktur = 2 } }, ok = true }
local packed = NS.CommPack(tbl)
assert(type(packed) == "string" and packed:match("^[A-Za-z0-9+/=]+$"), "Base64")
assert(same(NS.CommUnpack(packed), tbl), "unpacked as it was")
assert(NS.CommUnpack("@@@@") == nil and NS.CommUnpack("AAAA") == nil, "bad data unpacks to nothing")

-- a blob goes out in parts of 200 characters with a header
fresh()
local big = {}
for i = 1, 40 do big[i] = { ("%012x"):format(i), "Spieler " .. i, 30000 + i, i * 10, "MS", "Ragnaros", "player", 1, 0 } end
assert(NS.CommSendBlob("SP", KEY, big, "RAID") == true)
local parts = texts("AmisiaD")
assert(NS.CommQueueSize() + #parts > 1, "more than one part")
STUB.tick(30)
parts = texts("AmisiaD")
local n = tonumber(parts[1]:match("^1BL\tSP\t" .. KEY:gsub("%-", "%%-") .. "\t%d+\t1\t(%d+)\t"))
assert(n and n == #parts and n > 1, "header with i and n: " .. tostring(parts[1]:sub(1, 50)))
for i, p in ipairs(parts) do
    assert(#p <= 250, "a part fits: " .. #p)
    local pi, pn = p:match("^1BL\tSP\t[^\t]+\t%d+\t(%d+)\t(%d+)\t")
    assert(tonumber(pi) == i and tonumber(pn) == n)
end
-- too big: more than 60 parts are refused
local huge = { x = string.rep("a", 9500) }
local ok, why = NS.CommSendBlob("SP", KEY, huge, "RAID")
assert(ok == nil and why, "more than 60 parts are refused")
assert(NS.CommSendBlob("XX", KEY, tbl, "RAID") == nil, "unknown kind")
assert(NS.CommSendBlob("SP", "2026-10-05", tbl, "RAID") == nil, "bad raid key")
assert(NS.CommSendBlob("OP", KEY, big, "WHISPER", "Fraktur") == nil, "OP has at most 8 parts")

-- reassembly: any order, doubles, once
local blobs = {}
NS.CommOnBlob("SP", function(sender, t, chan, key) blobs[#blobs + 1] = { sender = sender, t = t, chan = chan, key = key } end)
local function asFrom(list, sender, order)
    for _, i in ipairs(order) do recv("AmisiaD", list[i], "RAID", sender) end
end
local order = {}
for i = n, 1, -1 do order[#order + 1] = i end
order[#order + 1] = 1
order[#order + 1] = n
asFrom(parts, "Fraktur", order)
assert(#blobs == 1, "one complete blob: " .. #blobs)
assert(blobs[1].sender == "Fraktur" and blobs[1].chan == "RAID" and blobs[1].key == KEY)
assert(same(blobs[1].t, big), "the table arrived whole")
asFrom(parts, "Fraktur", { 1 })
STUB.tick(1)
assert(#blobs == 1, "a late double of a finished set starts nothing")

-- a set expires 30 s after its last part; the loss is announced
local lost = {}
NS.Listen("COMM_BLOB_LOST", function(sender, art, key) lost[#lost + 1] = sender .. " " .. art .. " " .. key end)
local seq = 900
local function partsOf(t, art, key, s)
    local b64 = NS.CommPack(t)
    local ch = NS.CommChunks(b64)
    local out = {}
    for i, c in ipairs(ch) do out[i] = ("1BL\t%s\t%s\t%d\t%d\t%d\t%s"):format(art, key, s, i, #ch, c) end
    return out
end
local p2 = partsOf({ a = string.rep("q", 200) }, "SP", KEY, seq)
assert(#p2 == 2)
recv("AmisiaD", p2[1], "RAID", "Kim Eisherz")
STUB.tick(31)
recv("AmisiaD", p2[2], "RAID", "Kim Eisherz")
assert(#blobs == 1, "the expired set is gone")
assert(lost[1] == "Kim Eisherz SP " .. KEY, tostring(lost[1]))
-- a part within 30 s keeps the set
STUB.tick(31)
p2 = partsOf({ a = string.rep("q", 200) }, "SP", KEY, seq + 1)
recv("AmisiaD", p2[1], "RAID", "Kim Eisherz")
STUB.tick(25)
recv("AmisiaD", p2[2], "RAID", "Kim Eisherz")
assert(#blobs == 2)
-- at most 3 open sets per sender: the oldest goes
local open = {}
for s = 1, 4 do open[s] = partsOf({ a = string.rep("r", 200), s = s }, "SP", KEY, 500 + s) end
for s = 1, 4 do recv("AmisiaD", open[s][1], "RAID", "Fraktur"); STUB.tick(0.1) end
for s = 2, 4 do recv("AmisiaD", open[s][2], "RAID", "Fraktur") end
recv("AmisiaD", open[1][2], "RAID", "Fraktur")
assert(#blobs == 5, "three of four sets completed: " .. #blobs)
assert(blobs[3].t.s == 2 and blobs[5].t.s == 4)
-- bad data drops the whole set
local bad1 = NS.CommStats().bad
recv("AmisiaD", ("1BL\tSP\t%s\t%d\t1\t1\t%s"):format(KEY, 700, "!!notbase64!!"), "RAID", "Fraktur")
recv("AmisiaD", ("1BL\tSP\t%s\t%d\t1\t1\t%s"):format(KEY, 701, "AAAA"), "RAID", "Fraktur")
local notTable = NS.CommChunks(C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR("text"), 0)))
recv("AmisiaD", ("1BL\tSP\t%s\t%d\t1\t1\t%s"):format(KEY, 702, notTable[1]), "RAID", "Fraktur")
assert(#blobs == 5 and NS.CommStats().bad >= bad1 + 3, "nothing of a bad set is used")
-- part numbers are checked: i <= n <= 60, OP at most 8
recv("AmisiaD", ("1BL\tSP\t%s\t%d\t3\t2\tAAAA"):format(KEY, 710), "RAID", "Fraktur")
recv("AmisiaD", ("1BL\tSP\t%s\t%d\t1\t61\tAAAA"):format(KEY, 711), "RAID", "Fraktur")
recv("AmisiaD", ("1BL\tOP\t%s\t%d\t1\t9\tAAAA"):format(KEY, 712), "WHISPER", "Fraktur")
recv("AmisiaD", ("1BL\tSP\t%s\t%d\t0\t2\tAAAA"):format(KEY, 713), "RAID", "Fraktur")
assert(NS.CommStats().bad >= bad1 + 7)
-- a blob on the control prefix is not read
local before = #blobs
local one = partsOf({ z = 1 }, "SP", KEY, 720)
recv("Amisia", one[1], "RAID", "Fraktur")
assert(#blobs == before)
recv("AmisiaD", one[1], "RAID", "Fraktur")
assert(#blobs == before + 1)
-- data only from members of the own guild: the parts of a group member outside the guild are
-- dropped from the first on and never unpacked
local unpacked = 0
local decompress = C_EncodingUtil.DecompressString
C_EncodingUtil.DecompressString = function(...) unpacked = unpacked + 1 return decompress(...) end
table.insert(STUB.roster, { name = "Pug Fremd", class = "ROGUE" })
before = #blobs
local badOut = NS.CommStats().bad
local stranger = partsOf({ z = 2 }, "SP", KEY, 730)
recv("AmisiaD", stranger[1], "RAID", "Pug Fremd")
local stranger2 = partsOf({ a = string.rep("p", 200) }, "SP", KEY, 731)
assert(#stranger2 == 2)
recv("AmisiaD", stranger2[1], "RAID", "Pug Fremd")
recv("AmisiaD", stranger2[2], "RAID", "Pug Fremd")
assert(#blobs == before and unpacked == 0, "an outsider's sets are never unpacked")
assert(NS.CommStats().bad == badOut + 1, "counted once, the rest dropped unread")
table.remove(STUB.roster)
-- the open parts of one sender are bounded before anything is unpacked: three sets of 40 parts
-- sent slowly (within the receive limits) reach 90 open parts, the next part drops its set
STUB.tick(120)
local wide = {}
for k = 1, 3 do
    wide[k] = partsOf({ a = string.rep(string.char(96 + k), 5980) }, "SP", KEY, 740 + k)
    assert(#wide[k] == 40, #wide[k])
end
local badWide, limitedWide = NS.CommStats().bad, NS.CommStats().limited
for i = 1, 30 do
    for k = 1, 3 do
        recv("AmisiaD", wide[k][i], "RAID", "Kim Eisherz")
        STUB.tick(0.8)
    end
end
assert(NS.CommStats().limited == limitedWide, "within the receive limits")
assert(NS.CommStats().bad == badWide, "90 open parts are allowed")
recv("AmisiaD", wide[3][31], "RAID", "Kim Eisherz")
assert(NS.CommStats().bad == badWide + 1, "the 91st open part drops its set")
before = #blobs
for i = 31, 40 do recv("AmisiaD", wide[1][i], "RAID", "Kim Eisherz"); STUB.tick(0.8) end
assert(#blobs == before + 1 and blobs[#blobs].t.a:sub(1, 1) == "a", "the other sets go on")
C_EncodingUtil.DecompressString = decompress

---------------------------------------------------------------------------
-- throttle: 10 per prefix at once, then 1 a second; control before data
---------------------------------------------------------------------------
fresh()
for i = 1, 15 do assert(NS.CommSend("HI", { "2.1." .. i, "1", "-", "-" }, "RAID") == true) end
assert(#STUB.addon == 10 and NS.CommQueueSize() == 5, #STUB.addon)
STUB.tick(1)
assert(#STUB.addon == 11)
STUB.tick(4)
assert(#STUB.addon == 15 and NS.CommQueueSize() == 0)
for i = 2, 15 do assert(STUB.addon[i].text == "1HI\t2.1." .. i .. "\t1\t-\t-", "order kept") end
assert(STUB.addon[11].t - STUB.addon[1].t >= 1 - 1e-9)
for _, a in ipairs(STUB.addonTries) do assert(a.result == 0, "the client never throttles us") end
-- 30 at once never reach the client's limit
fresh()
for i = 1, 30 do NS.CommSend("HI", { "2.1." .. i, "1", "-", "-" }, "RAID") end
STUB.tick(25)
assert(#STUB.addon == 30)
for _, a in ipairs(STUB.addonTries) do assert(a.result == 0) end
-- the data prefix has its own allowance, and a control message goes before the next data part
fresh()
assert(NS.CommSendBlob("SP", KEY, big, "RAID") == true)
local dataFirst = #texts("AmisiaD")
assert(dataFirst >= 1 and dataFirst < n, "the byte allowance stops the data parts: " .. dataFirst)
for i = 1, 3 do NS.CommSend("HI", { "2.1." .. i, "1", "-", "-" }, "RAID") end
STUB.tick(30)
assert(#texts("AmisiaD") == n and #texts("Amisia") == 3)
local lastCtrl, firstLateData
for i, a in ipairs(STUB.addon) do
    if a.prefix == "Amisia" then lastCtrl = i end
    if a.prefix == "AmisiaD" and i > dataFirst and not firstLateData then firstLateData = i end
end
assert(lastCtrl < firstLateData, "control before data")
-- a control message waiting for its allowance finds the bytes it needs: data parts leave them
fresh()
for i = 1, 10 do NS.CommSend("HI", { "2.1." .. i, "1", "-", "-" }, "RAID") end
local t0 = STUB.clock
local longCtrl = "1HI\t" .. string.rep("v", 240)
NS.CommSend("HI", { string.rep("v", 240) }, "RAID")
NS.CommSendBlob("SP", KEY, big, "RAID")
STUB.tick(1)
local vq
for _, a in ipairs(STUB.addon) do if a.text == longCtrl then vq = a end end
assert(vq and math.abs(vq.t - (t0 + 1)) < 1e-6, "the control message goes with its first allowance")

---------------------------------------------------------------------------
-- result codes
---------------------------------------------------------------------------
-- 3 and 8: the entry stays in front, the queue pauses 2, 4, 8, 16 s, after 5 tries it is gone
fresh()
STUB.addonResult = 3
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
assert(#STUB.addonTries == 1 and NS.CommQueueSize() == 1)
NS.CommSend("VQ", { "abcd" }, "RAID")
STUB.tick(1.9)
assert(#STUB.addonTries == 1, "pause of 2 s")
STUB.tick(0.2)
assert(#STUB.addonTries == 2)
STUB.tick(3.8)
assert(#STUB.addonTries == 2, "then 4 s")
STUB.tick(0.3)
assert(#STUB.addonTries == 3)
STUB.tick(8)
assert(#STUB.addonTries == 4, "then 8 s")
STUB.tick(16)
assert(#STUB.addonTries == 5, "then 16 s: " .. #STUB.addonTries)
for _, a in ipairs(STUB.addonTries) do assert(a.text:find("^1HI"), "the throttled entry stays in front") end
STUB.addonResult = nil
STUB.tick(1.5)
assert(#STUB.addonTries == 5, "after giving up the queue still pauses 2 s")
STUB.tick(0.5)
assert(#STUB.addon == 1 and STUB.addon[1].text == "1VQ\tabcd", "after 5 tries the entry is gone, the next goes")
assert(NS.CommQueueSize() == 0)
-- 8 behaves the same and a success ends the pause
fresh()
STUB.addonResult = 8
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
STUB.tick(2.1)
assert(#STUB.addonTries == 2)
STUB.addonResult = nil
STUB.tick(4.2)
assert(#STUB.addon == 1 and NS.CommQueueSize() == 0)
-- 5, 10, 12 drop quietly; 1, 2, 4, 6, 7, 9 drop and count; an error counts as 9
for _, code in ipairs({ 5, 10, 12, 1, 2, 4, 6, 7, 9 }) do
    fresh()
    STUB.addonResult = code
    NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
    STUB.addonResult = nil
    assert(NS.CommQueueSize() == 0 and #STUB.addonTries == 1, "result " .. code .. " drops the entry")
end
fresh()
local real = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function() error("boom") end
local failed0 = NS.CommStats().failed
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
assert(NS.CommQueueSize() == 0 and NS.CommStats().failed == failed0 + 1, "an error drops like 9")
-- an old client answering true counts as success
C_ChatInfo.SendAddonMessage = function() return true end
local sent0 = NS.CommStats().sent
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
assert(NS.CommQueueSize() == 0 and NS.CommStats().sent == sent0 + 1)
C_ChatInfo.SendAddonMessage = real

-- 11: the queue holds like in the lockdown and tries again with the 2 s check
fresh()
STUB.addonResult = 11
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
assert(NS.CommQueueSize() == 1 and NS.CommHeld() == true, "result 11 holds")
STUB.addonResult = nil
STUB.tick(1)
assert(#STUB.addon == 0, "held until the next check")
STUB.tick(1.25)
assert(#STUB.addon == 1 and NS.CommHeld() == false)

---------------------------------------------------------------------------
-- the lockdown
---------------------------------------------------------------------------
fresh()
STUB.chatLock = true
assert(NS.CommHeld() == true)
assert(NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID") == true, "queued")
STUB.tick(5)
assert(#STUB.addonTries == 0, "nothing is even tried in the lockdown")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
assert(#STUB.addon == 0, "not during the event")
STUB.tick(0)
assert(#STUB.addon == 1, "released one tick after the event with state 0")
-- the restriction query alone holds too
local realRestricted = C_RestrictedActions.IsAddOnRestrictionActive
C_RestrictedActions.IsAddOnRestrictionActive = function(kind) return kind == 5 end
assert(NS.ChatLocked() == false and NS.CommHeld() == true, "restriction type 5 holds")
NS.CommSend("HI", { "2.1.1", "1", "-", "-" }, "RAID")
STUB.tick(3)
assert(#STUB.addon == 1)
C_RestrictedActions.IsAddOnRestrictionActive = realRestricted
-- without the event the 2 s check releases it
STUB.tick(2.25)
assert(#STUB.addon == 2, "released by the 2 s check")
-- ttl runs out in the lockdown
fresh()
STUB.chatLock = true
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID", nil, { ttl = 5 })
NS.CommSend("VQ", { "abcd" }, "RAID")
STUB.tick(10)
STUB.chatLock = false
STUB.tick(2.25)
assert(#STUB.addon == 1 and STUB.addon[1].text == "1VQ\tabcd", "the expired entry fell out")
-- the same key replaces a waiting entry, also all waiting parts of a blob
fresh()
STUB.chatLock = true
NS.CommSend("ST", { KEY, "17", "0123456789abcdef", "K" }, "RAID", nil, { key = "ST:" .. KEY })
NS.CommSend("ST", { KEY, "18", "0123456789abcdef", "K" }, "RAID", nil, { key = "ST:" .. KEY })
assert(NS.CommQueueSize() == 1, "replaced")
NS.CommSendBlob("SP", KEY, big, "RAID", nil, { key = "SP:" .. KEY })
local withBig = NS.CommQueueSize()
assert(withBig == 1 + n)
NS.CommSendBlob("SP", KEY, { small = true }, "RAID", nil, { key = "SP:" .. KEY })
assert(NS.CommQueueSize() == 2, "the old parts went with it: " .. NS.CommQueueSize())
STUB.chatLock = false
STUB.tick(2.25)
assert(#STUB.addon == 2 and STUB.addon[1].text:find("\t18\t"), "the newest state")
blobs = {}
recv("AmisiaD", STUB.addon[2].text, "RAID", "Fraktur")
assert(#blobs == 1 and blobs[1].t.small == true, "the newest blob")

---------------------------------------------------------------------------
-- battlegrounds and arenas: nothing is sent
---------------------------------------------------------------------------
for _, case in ipairs({ { type = "pvp" }, { type = "arena" }, { battlefield = true } }) do
    fresh()
    local inst = STUB.instance
    if case.type then STUB.instance = { name = "Kriegshymnenschlucht", type = case.type, id = 489 } end
    STUB.battlefield = case.battlefield
    assert(NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "GUILD", nil, { ttl = 10 }) == true, "waits")
    STUB.tick(5)
    assert(#STUB.addonTries == 0, "nothing in a battleground: " .. tostring(case.type))
    STUB.tick(10)
    STUB.instance, STUB.battlefield = inst, nil
    STUB.tick(3)
    assert(#STUB.addonTries == 0 and NS.CommQueueSize() == 0, "the entry expired")
end

---------------------------------------------------------------------------
-- jitter, the queue limit
---------------------------------------------------------------------------
fresh()
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "WHISPER", "Fraktur", { jitter = 3 })
NS.CommSend("VQ", { "abcd" }, "RAID")
assert(#STUB.addon == 1 and STUB.addon[1].text == "1VQ\tabcd", "a delayed entry does not block the others")
STUB.tick(3.3)
assert(#STUB.addon == 2)
fresh()
STUB.chatLock = true
for i = 1, 200 do NS.CommSend("HI", { "2.1." .. i, "1", "-", "-" }, "RAID") end
NS.CommSendBlob("SP", KEY, big, "RAID")
assert(NS.CommQueueSize() == 200)
STUB.chatLock = false
STUB.tick(2.25)
for _, a in ipairs(STUB.addon) do assert(a.prefix == "Amisia", "the data parts went first") end
STUB.chatLock = true
STUB.tick(120)
STUB.addon = {}
for i = 1, 201 do NS.CommSend("VQ", { ("%04x"):format(i) }, "RAID") end
assert(NS.CommQueueSize() == 200)
STUB.chatLock = false
STUB.tick(2.25)
assert(STUB.addon[1].text == "1VQ\t0002", "the oldest control message went: " .. STUB.addon[1].text)
STUB.tick(300)
assert(NS.CommQueueSize() == 0)

---------------------------------------------------------------------------
-- debug lines
---------------------------------------------------------------------------
fresh()
STUB.messages = {}
NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
recv("Amisia", "1HI\t2.1.0\t1\tL\t-", "RAID", "Fraktur")
assert(#STUB.messages == 0, "quiet without sync.debug")
NS.Set("sync.debug", true)
NS.CommSend("ST", { KEY, "17", "0123456789abcdef", "K" }, "RAID")
recv("Amisia", "1HI\t2.1.0\t1\tL\t-", "RAID", "Fraktur")
local joined = table.concat(STUB.messages, "\n")
assert(joined:find("Amisia Sync: > RAID ST " .. KEY:gsub("%-", "%%-") .. " 17"), joined)
assert(joined:find("Amisia Sync: < Fraktur HI 2%.1%.0"), joined)
assert(STUB.messages[1]:find("^|cff"), "a grey line")
STUB.messages = {}
for i = 1, 30 do NS.CommSend("VQ", { ("%04x"):format(i) }, "RAID") end
STUB.tick(40)
assert(#STUB.messages <= 20, "at most 20 lines a minute: " .. #STUB.messages)
-- too much from one sender is noted
fresh()
STUB.messages = {}
for i = 1, 41 do recv("Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Kim Eisherz") end
assert(table.concat(STUB.messages, "\n"):find("Amisia Sync: Kim Eisherz sendet zu viel, 60 s ignoriert%."))
NS.Set("sync.debug", false)

-- all texts of the file are Latin-1
local src = assert(io.open(ADDON_DIR .. "/Core/Comm.lua", "rb")):read("*a")
for ch in src:gmatch("[\194-\244][\128-\191]*") do
    local b1, b2 = ch:byte(1, 2)
    assert(b1 <= 195, "a character beyond Latin-1 in Comm.lua")
end
