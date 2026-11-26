--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Lia_Weide]]
--[[preload
-- a guild bank with two visible tabs and the transaction logs of the client (as in test_bank_log.lua)
STUB.gbTabs = { { "Mats", true }, { "Rüstung", true } }
STUB.gblog = { {}, {} }
STUB.gbmoney = {}
GetNumGuildBankTabs = function() return #STUB.gbTabs end
GetGuildBankTabInfo = function(tab) local t = STUB.gbTabs[tab]; return t and t[1], 134, t and t[2] end
QueryGuildBankTab = function() end
GetCurrentGuildBankTab = function() return 1 end
GetGuildBankItemLink = function() return nil end
GetGuildBankItemInfo = function() return 134, 0 end
MAX_GUILDBANK_TABS = 8
QueryGuildBankLog = function() end
GetNumGuildBankTransactions = function(tab) return STUB.gblog[tab] and #STUB.gblog[tab] or 0 end
GetGuildBankTransaction = function(tab, i)
    local e = STUB.gblog[tab] and STUB.gblog[tab][i]
    if not e then return nil end
    return unpack(e, 1, 10)
end
GetNumGuildBankMoneyTransactions = function() return #STUB.gbmoney end
GetGuildBankMoneyTransaction = function(i)
    local e = STUB.gbmoney[i]
    if not e then return nil end
    return unpack(e, 1, 7)
end
]]
-- F-238 (D-171, spec docs/specs/2026-11-26-gildenbank-abgleich.md): the guild bank log and the last count
-- reach every Amisia user of the guild. Officers send (BE after a read, BC after a count), everyone takes
-- them from officers only; a fresh client asks after the login (BQ ?), the officers with more offer (BH),
-- one is pulled by whisper, in rounds of at most 100 entries.
local VULO, FRAK, KIM, LIA = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Lia Weide"
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = LIA, rank = 4 } })
for _, name in ipairs({ KIM, LIA }) do C(name, "STUB.officer = false") end
-- Frak's PC clock runs 10 minutes ahead of the realm's
C(FRAK, [[_G.time = function(t) if type(t) == "table" then return os.time(t) end return STUB.now + 600 end; return true]])
for _, name in ipairs(CLIENTS) do
    C(name, [[
        STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.ore = STUB.item(61001, "Feuerkern", 3); STUB.cloth = STUB.item(61002, "Runenstoff", 1)
        -- the raid sync switch stops only the raid state (D-165): this goes on without it
        NS.Set("sync.enabled", false)
        return true]])
end
BUS.tick(1)

-- A visit at the guild bank: the reader asks every tab's log (3 s each without an answer), then the bank closes.
local function visit(name)
    C(name, "STUB.fire('GUILDBANKFRAME_OPENED')")
    BUS.tick(12)
    C(name, "STUB.fire('GUILDBANKFRAME_CLOSED')")
    BUS.tick(1)
end
local function count(name) return C(name, "#NS.BankLog().list") end
local function sent(kind, sender, chan) return BUS.count({ kind = kind, sender = sender, chan = chan }) end

---------------------------------------------------------------------------
-- the setting: everyone's, on by default
---------------------------------------------------------------------------
local it = C(KIM, "local it = NS.SettingItem('bank.share'); return { it.type, it.default }")
assert(it[1] == "toggle" and it[2] == true, "bank.share is a toggle, on")
assert(C(KIM, "NS.Set('ui.view', 'raider'); local ok = false; for _, g in ipairs(NS.SettingsGroups()) do for _, s in ipairs(g.sections) do if s.key == 'bank' then ok = true end end end; return ok"),
    "the raider view shows the Gildenbank section (everybody receives)")

---------------------------------------------------------------------------
-- an officer's read reaches everybody
---------------------------------------------------------------------------
C(VULO, [[
    STUB.gblog[1] = { { "deposit", "Anna Bergmann", STUB.ore, 20, nil, nil, 0, 0, 0, 2 },
                      { "deposit", "Anna Bergmann", STUB.ore, 20, nil, nil, 0, 0, 0, 2 },
                      { "withdraw", "Chorf", STUB.cloth, 5, nil, nil, 0, 0, 0, 5 },
                      { "move", "Fraktur", STUB.ore, 3, 1, 2, 0, 0, 0, 7 } }
    STUB.gbmoney = { { "deposit", "Fraktur", 1234567, 0, 0, 0, 4 }, { "repair", "Chorf", 50000, 0, 1, 2, 0 } }
    return true]])
visit(VULO)
assert(count(VULO) == 6, count(VULO))
assert(sent("BE", VULO, "GUILD") >= 1, "the new entries went to the guild")
for _, name in ipairs({ FRAK, KIM, LIA }) do
    assert(count(name) == 6, name .. " has the six entries: " .. count(name))
    assert(C(name, "NS.BankLog().got and NS.BankLog().got.by") == VULO, name .. ": heard from Vulo")
end
local e = C(KIM, [[for _, e in ipairs(NS.BankLog().list) do if e.y == "move" then return { e.r, e.a, e.b, e.c, e.i } end end]])
assert(e[1] == VULO and e[2] == 1 and e[3] == 2 and e[4] == 3 and e[5] == 61001, "a move with its tabs, reported by Vulo")
local money = C(KIM, [[for _, e in ipairs(NS.BankLog().list) do if e.k == 0 and e.y == "repair" then return { e.c, e.hi - e.lo } end end]])
assert(money[1] == 50000 and money[2] > 86400, "the month-old repair keeps its wide window")
-- the windows on both sides are the same (the realm's clock on the wire)
assert(C(KIM, "local t = 0; for _, e in ipairs(NS.BankLog().list) do t = t + e.lo + e.hi end; return t")
    == C(VULO, "local t = 0; for _, e in ipairs(NS.BankLog().list) do t = t + e.lo + e.hi end; return t"), "same windows")

-- the page: the line of the guild, "gemeldet von" in each entry's tooltip
local page = C(KIM, [[NS.ShowPage("bank"); local f = NS.PageFrame("bank"); f.views.log:Click()
    local G = f.log
    local row = G.list.rows[1]
    local tip = {}
    GameTooltip.AddLine = function(_, text) tip[#tip + 1] = text end
    row:GetScript("OnEnter")(row)
    return { G.share:GetText(), table.concat(tip, "\n") }]])
assert(has(page[1], "Abgeglichen mit der Gilde · zuletzt von Vulo Sturmwind"), tostring(page[1]))
assert(has(page[2], "Gemeldet von Vulo Sturmwind") and has(page[2], "Zwischen"), page[2])
local own = C(VULO, [[NS.ShowPage("bank"); local f = NS.PageFrame("bank"); f.views.log:Click()
    local row = f.log.list.rows[1]
    local tip = {}
    GameTooltip.AddLine = function(_, text) tip[#tip + 1] = text end
    row:GetScript("OnEnter")(row)
    return { f.log.share:GetText(), table.concat(tip, "\n") }]])
assert(has(own[2], "Selbst gelesen"), own[2])
assert(has(own[1], "noch nichts von einem Offizier gehört"), own[1])

---------------------------------------------------------------------------
-- a second officer reads the same log a little later (his clock 10 minutes ahead): only the new one goes
---------------------------------------------------------------------------
BUS.tick(1800)
C(FRAK, [[
    STUB.gblog[1] = { { "deposit", "Anna Bergmann", STUB.ore, 20, nil, nil, 0, 0, 0, 2 },
                      { "deposit", "Anna Bergmann", STUB.ore, 20, nil, nil, 0, 0, 0, 2 },
                      { "withdraw", "Chorf", STUB.cloth, 5, nil, nil, 0, 0, 0, 5 },
                      { "move", "Fraktur", STUB.ore, 3, 1, 2, 0, 0, 0, 7 },
                      { "deposit", "Kimtaro", STUB.cloth, 9, nil, nil, 0, 0, 0, 0 } }
    STUB.gbmoney = { { "deposit", "Fraktur", 1234567, 0, 0, 0, 4 }, { "repair", "Chorf", 50000, 0, 1, 2, 0 } }
    return true]])
local before = #BUS.sent
visit(FRAK)
assert(count(FRAK) == 7, "Frak's read matched the six he heard: " .. count(FRAK))
local beFromFrak = 0
for i = before + 1, #BUS.sent do
    local m = BUS.sent[i]
    if m.kind == "BE" and m.sender == FRAK then beFromFrak = beFromFrak + select(2, m.text:gsub("\t%d:%l:", "")) end
end
assert(beFromFrak == 1, "only the new entry went: " .. beFromFrak)
for _, name in ipairs({ VULO, KIM, LIA }) do
    assert(count(name) == 7, name .. ": the two equal deposits stay two, nothing doubled: " .. count(name))
end
assert(C(KIM, "NS.BankLog().got.by") == FRAK)

---------------------------------------------------------------------------
-- an untrusted sender: a member without the officer rank, a demoted officer, a stranger
---------------------------------------------------------------------------
local base = C(KIM, "NS.ServerTime()")
C(KIM, ("NS.CommSend('BE', { 'abcd', '1', '1', '%d', '-', '1:d:1bb5:k::0:2s0:Erfunden' }, 'GUILD')"):format(base))
BUS.tick(2)
for _, name in ipairs({ VULO, FRAK, LIA }) do assert(count(name) == 7, name .. ": a member's entries are not taken") end
-- Frak demoted on Lia's roster: his entries count no more there
C(LIA, [[STUB.guild[2].rank = 4; STUB.fire("GUILD_ROSTER_UPDATE")]])
BUS.tick(12)
C(FRAK, ("NS.CommSend('BE', { 'abce', '1', '1', '%d', '-', '1:d:1bb5:k::0:2s0:Erfunden' }, 'GUILD')"):format(base))
BUS.tick(2)
assert(count(LIA) == 7 and count(KIM) == 8, "the rank by the receiver's own roster decides")
C(LIA, [[STUB.guild[2].rank = 2; STUB.fire("GUILD_ROSTER_UPDATE")]])
-- Frak not in Kim's roster at all (a stranger to Kim): nothing taken
C(KIM, [[table.remove(STUB.guild, 2); STUB.fire("GUILD_ROSTER_UPDATE")]])
BUS.tick(12)
C(FRAK, ("NS.CommSend('BE', { 'abcf', '1', '1', '%d', '-', '1:d:1bb5:k::0:2s0:Fremd' }, 'GUILD')"):format(base))
BUS.tick(3)
assert(C(KIM, [[for _, e in ipairs(NS.BankLog().list) do if e.n == "Fremd" then return false end end; return true]]), "a stranger's entries are dropped")
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = LIA, rank = 4 } })
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('GUILD_ROSTER_UPDATE')") end
for _, name in ipairs({ VULO, LIA }) do
    C(name, [[local keep = {}; for _, e in ipairs(AmisiaDB.bankLog.list) do if e.n ~= "Fremd" then keep[#keep + 1] = e end end
        AmisiaDB.bankLog.list = keep; return #keep]])
end
for _, name in ipairs({ VULO, KIM }) do
    C(name, [[local keep = {}; for _, e in ipairs(AmisiaDB.bankLog.list) do if e.n ~= "Erfunden" then keep[#keep + 1] = e end end
        AmisiaDB.bankLog.list = keep; return #keep]])
end
BUS.tick(12)

---------------------------------------------------------------------------
-- malformed fields drop the whole message
---------------------------------------------------------------------------
local bad = {
    "1:x:1bb5:k::0:2s0:Name",           -- unknown kind
    "0:d:1bb5:k::0:2s0:Name",           -- money with an item
    "1:m:1bb5:k::0:2s0:Name",           -- a move without its tabs
    "1:d:1bb5:k:12:0:2s0:Name",         -- tabs on a deposit
    "1:d:1bb5:k::zzzzzzz:2s0:Name",     -- older than 400 days
    "1:d:1bb5:k::0:zzzzz:Name",         -- a window wider than 8 days
    "1:d:0:k::0:2s0:Name",              -- an item deposit without an item
    "1:d:1bb5:k::0:2s0:" .. ("x"):rep(60), -- a name too long
}
for i, entry in ipairs(bad) do
    C(VULO, ("NS.CommSend('BE', { '%04x', '1', '1', '%d', '-', '1:d:1bb5:k::0:2s0:Gut', %q }, 'GUILD')"):format(4096 + i, base, entry))
end
C(VULO, ("NS.CommSend('BE', { 'ffff', '1', '1', '%d', '-', '1:d:1bb5:k::0:2s0:Gut' }, 'GUILD')"):format(base + 7200))
BUS.tick(2)
for _, name in ipairs({ FRAK, KIM, LIA }) do assert(count(name) == 7, name .. ": no part of a bad message is taken: " .. count(name)) end
C(VULO, ("NS.CommSend('BC', { '%d', '1', '1', 'Vulo_Sturmwind', '2', '2', '2', '1bb5:k,xx' }, 'GUILD')"):format(base))
BUS.tick(2)
assert(C(KIM, "AmisiaDB.bank == nil"), "a bad count is dropped")

---------------------------------------------------------------------------
-- the chat lockdown: what a read sends waits until it lifts
---------------------------------------------------------------------------
BUS.lock(true)
C(VULO, [[table.insert(STUB.gblog[2], { "deposit", "Lia Weide", STUB.cloth, 11, nil, nil, 0, 0, 0, 0 }); return true]])
local lockFrom = #BUS.sent
visit(VULO)
local during = 0
for i = lockFrom + 1, #BUS.sent do if BUS.sent[i].kind == "BE" then during = during + 1 end end
assert(during == 0, "nothing goes in the lockdown")
assert(count(KIM) == 7)
BUS.lock(false)
BUS.tick(4)
assert(count(KIM) == 8 and count(LIA) == 8, "it goes once the lockdown lifts")

---------------------------------------------------------------------------
-- bank.share off: nothing taken; on an officer: nothing sent
---------------------------------------------------------------------------
C(KIM, "NS.Set('bank.share', false)")
C(VULO, [[table.insert(STUB.gblog[2], { "withdraw", "Chorf", STUB.ore, 2, nil, nil, 0, 0, 0, 0 }); return true]])
visit(VULO)
assert(count(KIM) == 8 and count(LIA) == 9, "Kim takes nothing with bank.share off, Lia does")
C(KIM, "NS.Reset('bank.share')")
C(VULO, "NS.Set('bank.share', false)")
before = sent("BE", VULO)
C(VULO, [[table.insert(STUB.gblog[2], { "withdraw", "Chorf", STUB.ore, 4, nil, nil, 0, 0, 0, 0 }); return true]])
visit(VULO)
assert(count(VULO) == 10 and sent("BE", VULO) == before, "an officer with bank.share off reads for himself only: " .. count(VULO) .. " " .. sent("BE", VULO) .. " " .. before)
C(VULO, "NS.Reset('bank.share')")
-- bank.log off: no log kept, nothing taken
C(LIA, "NS.Set('bank.log', false)")
C(FRAK, [[table.insert(STUB.gblog[2], { "deposit", "Kimtaro", STUB.ore, 1, nil, nil, 0, 0, 0, 0 }); return true]])
visit(FRAK)
assert(count(LIA) == 9, "bank.log off takes no entries")
C(LIA, "NS.Reset('bank.log')")

---------------------------------------------------------------------------
-- the count: newest wins, with who counted and who sent it
---------------------------------------------------------------------------
local bcBefore = sent("BC", VULO, "GUILD")
C(VULO, [[AmisiaDB.bank = { at = STUB.now - 60, by = "Vulo Sturmwind", counts = { [61001] = 12, [61002] = 80 }, tabs = 2, filled = 2, total = 2 }
    NS.BankShareCounted(); return true]])
BUS.tick(7)
assert(sent("BC", VULO, "GUILD") == bcBefore + 1, "the count went once the counting was over")
for _, name in ipairs({ FRAK, KIM, LIA }) do
    local b = C(name, "local b = AmisiaDB.bank; return b and { b.counts[61001], b.counts[61002], b.by, b.via, b.tabs }")
    assert(b and b[1] == 12 and b[2] == 80 and b[3] == VULO and b[4] == VULO and b[5] == 2, name .. " has Vulo's count")
end
-- an older count (Frak's clock is ahead, but his count is from before) does not replace it
C(FRAK, [[AmisiaDB.bank = { at = STUB.now + 600 - 3600, by = "Fraktur", counts = { [61001] = 1 }, tabs = 1, filled = 1, total = 2 }
    NS.BankShareCounted(); return true]])
BUS.tick(7)
assert(C(KIM, "AmisiaDB.bank.counts[61001]") == 12, "older count ignored")
-- a newer one does
C(FRAK, [[AmisiaDB.bank = { at = STUB.now + 600, by = "Fraktur", counts = { [61001] = 30, [61002] = 0 }, tabs = 2, filled = 2, total = 2 }
    NS.BankShareCounted(); return true]])
BUS.tick(7)
assert(C(KIM, "AmisiaDB.bank.counts[61001]") == 30 and C(KIM, "AmisiaDB.bank.counts[61002]") == 0 and C(KIM, "AmisiaDB.bank.by") == FRAK, "newer count taken")
assert(math.abs(C(KIM, "AmisiaDB.bank.at") - C(KIM, "STUB.now") + 7) <= 1, "on the receiver's own clock")
-- a member's count is not taken
C(KIM, ("NS.CommSend('BC', { '%d', '1', '1', 'Kim_Eisherz', '2', '2', '2', '1bb5:zz' }, 'GUILD')"):format(base + 3000))
BUS.tick(2)
assert(C(LIA, "AmisiaDB.bank.counts[61001]") == 30, "only officers' counts")

---------------------------------------------------------------------------
-- after a login: a fresh client asks, one officer is pulled
---------------------------------------------------------------------------
C(LIA, "AmisiaDB.bankLog = nil; AmisiaDB.bank = nil; NS.BankLogLoaded(AmisiaDB); return true")
assert(count(LIA) == 0)
before = #BUS.sent
assert(C(LIA, "NS.AskBankShare()") == true)
BUS.tick(30)
local offers, whispers = 0, {}
for i = before + 1, #BUS.sent do
    local m = BUS.sent[i]
    if m.kind == "BH" and m.target == LIA then offers = offers + 1 end
    if m.kind == "BE" and m.chan == "WHISPER" and m.target == LIA then whispers[m.sender] = true end
end
assert(sent("BQ", LIA, "GUILD") == 1, "one question to the guild")
assert(offers == 2, "both officers offer: " .. offers)
local answerers = 0
for _ in pairs(whispers) do answerers = answerers + 1 end
assert(answerers == 1, "one officer answers")
assert(count(LIA) == count(VULO), "Lia has the whole log: " .. count(LIA) .. " of " .. count(VULO))
assert(C(LIA, "AmisiaDB.bank and AmisiaDB.bank.counts[61001]") == 30, "and the newest count")
-- a member never offers
for i = before + 1, #BUS.sent do assert(not (BUS.sent[i].kind == "BH" and BUS.sent[i].sender == KIM), "Kim does not offer") end
-- asked again with nothing missing: nobody offers
BUS.tick(61)
before = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(20)
local again = 0
for i = before + 1, #BUS.sent do if BUS.sent[i].kind == "BH" then again = again + 1 end end
assert(again == 0, "nothing newer, no offer: " .. again)

---------------------------------------------------------------------------
-- a long log goes in rounds of at most 100 entries
---------------------------------------------------------------------------
C(VULO, [[
    local rows = {}
    for i = 1, 250 do rows[#rows + 1] = { k = 1 + i % 2, y = "deposit", n = "Spender" .. i, i = 61001, c = i, ago = i % 200 } end
    NS.MergeBankLog(rows, STUB.now)
    return true]])
local total = count(VULO)
assert(total >= 250, total)
C(LIA, "AmisiaDB.bankLog = nil; NS.BankLogLoaded(AmisiaDB); return true")
BUS.tick(61)
before = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(200)
local batches = {}
for i = before + 1, #BUS.sent do
    local m = BUS.sent[i]
    if m.kind == "BE" and m.target == LIA then
        local id = m.text:match("^1BE\t(%x+)")
        batches[id] = (batches[id] or 0) + select(2, m.text:gsub("\t%d:%l:", ""))
    end
end
local nb = 0
for _, n in pairs(batches) do
    nb = nb + 1
    assert(n <= 100, "an answer holds at most 100 entries: " .. n)
end
assert(nb >= 3, "several rounds: " .. nb)
assert(count(LIA) == total, "after the rounds Lia has everything: " .. count(LIA) .. " of " .. total)

---------------------------------------------------------------------------
-- review 2026-11-26 (regressions): helpers
---------------------------------------------------------------------------
local function reset(name) C(name, "AmisiaDB.bankLog = nil; AmisiaDB.bank = nil; NS.BankLogLoaded(AmisiaDB); return true") end
local function since(from, f)
    local n = 0
    for i = from + 1, #BUS.sent do if f(BUS.sent[i]) then n = n + 1 end end
    return n
end
local function entriesTo(from, target)
    local n = 0
    for i = from + 1, #BUS.sent do
        local m = BUS.sent[i]
        if m.kind == "BE" and m.target == target then n = n + select(2, m.text:gsub("\t%d:%l:", "")) end
    end
    return n
end
-- rows of n deposits on tab 1 named prefix..i, i hours ago (ago(i) when given)
local function rows(prefix, n, ago, skip)
    return ([[local rows = {}
        for i = 1, %d do if i ~= %d then rows[#rows + 1] = { k = 1, y = "deposit", n = %q .. i, i = 61001, c = i, ago = %s } end end
        NS.MergeBankLog(rows, STUB.now); return #NS.BankLog().list]]):format(n, skip or -1, prefix, ago or "i")
end
BUS.tick(61)

---------------------------------------------------------------------------
-- R1: the first pull never falls to the officer's gap of the question, also when the "?" left late
---------------------------------------------------------------------------
for _, delay in ipairs({ 2, 6 }) do
    reset(LIA)
    BUS.tick(61)
    -- other traffic in Lia's queue: the "?" waits about `delay` seconds behind it
    C(LIA, ([[for i = 1, %d do NS.CommSend("GQ", { tostring(i) }, "GUILD", nil, { key = "x" .. i }) end; return true]]):format(10 + delay))
    C(LIA, "NS.AskBankShare()")
    BUS.tick(100)
    assert(count(LIA) == count(VULO), "R1 delay " .. delay .. ": Lia has the log after a late question: " .. count(LIA) .. " of " .. count(VULO))
end

---------------------------------------------------------------------------
-- R2: nothing the asker would drop at once (its horizon, its cap); a merge counts only what it keeps
---------------------------------------------------------------------------
BUS.tick(61)
C(VULO, "NS.Set('bank.logDays', 365)")
C(VULO, rows("Alt", 150, "(100 + i % 100) * 24"))
for _ = 1, 2 do
    BUS.tick(61)
    local from = #BUS.sent
    C(LIA, "NS.AskBankShare()")
    BUS.tick(120)
    assert(since(from, function(m) return m.kind == "BH" and m.target == LIA end) == 0, "R2: no offer of entries beyond Lia's 90 days")
    assert(entriesTo(from, LIA) == 0, "R2: none sent")
end
-- a long horizon: the question stays within one message
C(LIA, "NS.Set('bank.logDays', 365)")
BUS.tick(61)
local from2 = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(2)
for i = from2 + 1, #BUS.sent do
    local m = BUS.sent[i]
    if m.kind == "BQ" then assert(#m.text <= 250, "R2: a BQ fits one message: " .. #m.text) end
end
assert(since(from2, function(m) return m.kind == "BQ" and m.sender == LIA end) == 1, "R2: the question went")
BUS.tick(200)
C(LIA, "NS.Reset('bank.logDays')")
C(VULO, "NS.Reset('bank.logDays')")
for _, n in ipairs(CLIENTS) do C(n, "AmisiaDB.bankLog.list = {}; return true") end
-- Lia full (1000) with newer entries of her own: Vulo's older ones would fall at once, nothing is pulled
C(VULO, rows("C", 1000))
C(LIA, rows("C", 850))
C(LIA, [[local rows = {}
    for i = 1, 150 do rows[#rows + 1] = { k = 2, y = "deposit", n = "X" .. i, i = 61001, c = i, ago = 0 } end
    NS.MergeBankLog(rows, STUB.now); return #NS.BankLog().list]])
assert(count(LIA) == 1000)
BUS.tick(61)
local from3 = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(200)
assert(since(from3, function(m) return m.kind == "BQ" and m.sender == LIA and m.chan == "WHISPER" end) == 0, "R2: a full Lia pulls nothing")
-- a merge into the full log: an entry older than all is pruned at once and is no new entry
assert(C(LIA, [[local old = NS.BankLog().list[1].hi
    for _, e in ipairs(NS.BankLog().list) do if e.hi < old then old = e.hi end end
    return #NS.MergeBankLogRead({ { k = 1, y = "deposit", n = "Uralt", i = 61001, c = 1, lo = old - 7200, hi = old - 3600 } }, 120, "Vulo Sturmwind")]]) == 0,
    "R2: an entry pruned at once is not returned as added")

---------------------------------------------------------------------------
-- R5/R7: a whole log of 1000 entries goes to a fresh client (its own budget), another asker still gets served
---------------------------------------------------------------------------
for _, n in ipairs(CLIENTS) do C(n, "AmisiaDB.bankLog.list = {}; return true") end
C(VULO, rows("C", 1000))
BUS.tick(601)
local from5 = #BUS.sent
C(KIM, "NS.AskBankShare()")
BUS.tick(600)
assert(count(KIM) == 1000, "R5: the whole log arrived: " .. count(KIM))
local batches5 = since(from5, function(m) return m.kind == "BQ" and m.sender == KIM and m.chan == "WHISPER" end)
assert(batches5 <= 13, "R5: within one transfer's rounds: " .. batches5)

---------------------------------------------------------------------------
-- R7: one asker spamming pulls gets at most one transfer in ten minutes; another asker is still served
---------------------------------------------------------------------------
BUS.tick(601)
reset(KIM)
local from7 = #BUS.sent
for _ = 1, 20 do
    -- the pull of a client of the first F-238 build (no summary; this build drops it) and the current one
    C(KIM, [[local keep = NS.ServerTime() - 90 * 86400
        NS.CommSend("BQ", { "L", "0" }, "WHISPER", "Vulo Sturmwind", { key = "old" })
        NS.CommSend("BQ", { "L", "0", tostring(keep), "0", "0", tostring(math.floor(NS.ServerTime() / 86400)), "90", "-" }, "WHISPER", "Vulo Sturmwind", { key = "new" })
        return true]])
    BUS.tick(11)
end
BUS.tick(60)
local spam = {}
for i = from7 + 1, #BUS.sent do
    local m = BUS.sent[i]
    if m.kind == "BE" and m.target == KIM then spam[m.text:match("^1BE\t(%x+)")] = true end
end
local spamN = 0
for _ in pairs(spam) do spamN = spamN + 1 end
assert(spamN <= 13, "R7: at most one transfer to a spamming asker: " .. spamN)
reset(LIA)
BUS.tick(61)
C(LIA, "NS.AskBankShare()")
BUS.tick(400)
assert(count(LIA) == count(VULO), "R7: another asker is still served: " .. count(LIA) .. " of " .. count(VULO))

---------------------------------------------------------------------------
-- R4: a gap deep inside a shared range is found (per-day counts) and filled; then nothing more is pulled
---------------------------------------------------------------------------
for _, n in ipairs(CLIENTS) do C(n, "AmisiaDB.bankLog.list = {}; return true") end
C(VULO, rows("M", 300))
C(LIA, rows("M", 300, nil, 250))
BUS.tick(601)
BUS.tick(61)
local from4 = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(150)
assert(C(LIA, [[for _, e in ipairs(NS.BankLog().list) do if e.n == "M250" then return true end end return false]]), "R4: the gap is filled")
assert(entriesTo(from4, LIA) <= 48, "R4: only the days that differ: " .. entriesTo(from4, LIA))
BUS.tick(61)
from4 = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(150)
assert(entriesTo(from4, LIA) == 0, "R4: nothing more once equal")

---------------------------------------------------------------------------
-- R8: a client keeping no log asks for the count alone ("?C"); no officer offers its log
---------------------------------------------------------------------------
reset(LIA)
C(LIA, "NS.Set('bank.log', false)")
BUS.tick(61)
local from8 = #BUS.sent
C(LIA, "NS.AskBankShare()")
BUS.tick(60)
local q8
for i = from8 + 1, #BUS.sent do
    local m = BUS.sent[i]
    if m.kind == "BQ" and m.sender == LIA and m.chan == "GUILD" then q8 = m.text end
    if m.kind == "BH" and m.target == LIA then assert(m.text:match("^1BH\t0\t"), "R8: an offer of the count only: " .. m.text) end
end
assert(q8 and q8:match("^1BQ\t%?C\t%d+$"), "R8: the question for the count only: " .. tostring(q8))
assert(entriesTo(from8, LIA) == 0, "R8: no entries")
assert(C(LIA, "AmisiaDB.bank and AmisiaDB.bank.counts[61001]") == 30, "R8: the count came")
C(LIA, "NS.Reset('bank.log')")

---------------------------------------------------------------------------
-- R3: a receiver in the lockdown (roster unreadable) holds an officer's batch and checks him once
---------------------------------------------------------------------------
C(KIM, [[STUB.chatLock = true
  local orig = NS.TrustWait
  _G.TW = 0
  NS.TrustWait = function(name, need, fn) TW = TW + 1; return orig(name, need, fn) end
  return true]])
C(VULO, [[
    STUB.gblog[1] = {}
    for i = 1, 100 do STUB.gblog[1][i] = { "deposit", "Lockname" .. i, STUB.ore, i, nil, nil, 0, 0, 0, 0 } end
    STUB.gblog[2] = {}
    for i = 1, 20 do STUB.gblog[2][i] = { "withdraw", "Lockname" .. i, STUB.cloth, i, nil, nil, 0, 0, 0, 0 } end
    return true]])
local k3 = count(KIM)
visit(VULO)
BUS.tick(30)
assert(count(KIM) == k3, "R3: nothing merged in the lockdown")
C(KIM, "STUB.chatLock = false; STUB.fire('ADDON_RESTRICTION_STATE_CHANGED'); return true")
BUS.tick(70)
assert(count(KIM) - k3 == 120, "R3: the held batch is merged once the roster reads: " .. (count(KIM) - k3))
assert(C(KIM, "TW") == 1, "R3: the sender is checked once per batch: " .. C(KIM, "TW"))
assert(C(KIM, [[for _, e in ipairs(NS.BankLog().list) do if e.n == "Lockname1" then return e.r end end]]) == VULO, "R3: reported by Vulo")

---------------------------------------------------------------------------
-- R6: a guild broadcast of the officer being pulled does not end the pull
---------------------------------------------------------------------------
for _, n in ipairs(CLIENTS) do C(n, "AmisiaDB.bankLog.list = {}; return true") end
C(VULO, rows("P", 250))
BUS.tick(601)
BUS.tick(61)
local from6 = #BUS.sent
C(LIA, "NS.AskBankShare()")
-- until Lia's first pull went
for _ = 1, 300 do
    BUS.tick(0.1)
    if since(from6, function(m) return m.kind == "BQ" and m.sender == LIA and m.chan == "WHISPER" end) > 0 then break end
end
-- Vulo reads a new entry meanwhile: its guild batch arrives before the whispered answer
C(VULO, [[local n, new = NS.MergeBankLog({ { k = 2, y = "deposit", n = "Mitten", i = 61002, c = 1, ago = 0 } }, STUB.now)
    return NS.BankShareRead(new)]])
BUS.tick(300)
assert(count(LIA) == count(VULO), "R6: the pull went on after the guild batch: " .. count(LIA) .. " of " .. count(VULO))

---------------------------------------------------------------------------
-- R9: the Bank page's link "Jetzt abgleichen" asks at once, then waits a minute
---------------------------------------------------------------------------
BUS.tick(61)
local from9 = #BUS.sent
local link = C(KIM, [[NS.ShowPage("bank"); local f = NS.PageFrame("bank"); f.views.log:Click()
    local b = f.log.shareNow
    if not b or not b:IsShown() then return { false } end
    b:Click()
    local n = #STUB.messages
    b:Click()
    return { true, STUB.messages[n + 1] }]])
assert(link[1], "R9: the link is shown")
BUS.tick(1)
assert(since(from9, function(m) return m.kind == "BQ" and m.sender == KIM and m.chan == "GUILD" end) == 1, "R9: one question went")
assert(has(link[2], "gerade erst gefragt"), "R9: a second click within the minute waits: " .. tostring(link[2]))
BUS.tick(60)

---------------------------------------------------------------------------
-- extras A: a name is cut on a character's boundary (BankLog cleanName)
---------------------------------------------------------------------------
C(VULO, [[STUB.gblog[1] = { { "deposit", ("a"):rep(47) .. "ü", STUB.ore, 3, nil, nil, 0, 0, 0, 0 } }; STUB.gblog[2] = {}; return true]])
visit(VULO)
assert(C(VULO, [[for _, e in ipairs(NS.BankLog().list) do if e.n:sub(1, 5) == "aaaaa" then return e.n end end]]) == ("a"):rep(47), "a name is cut before a split character")
assert(C(KIM, [[for _, e in ipairs(NS.BankLog().list) do if e.n:sub(1, 5) == "aaaaa" then return e.n end end]]) == ("a"):rep(47), "and shared so")

---------------------------------------------------------------------------
-- extras B: an officer whose roster is not built yet at the read: the read waits for it
---------------------------------------------------------------------------
C(VULO, [[_G.SAVED_GUILD = STUB.guild; STUB.guild = {}; STUB.fire("GUILD_ROSTER_UPDATE"); return true]])
BUS.tick(12)
assert(C(VULO, "NS.GuildRoster() == nil"), "Vulo's roster cannot be read")
C(VULO, [[STUB.gblog[1] = { { "deposit", "Spaetleser", STUB.ore, 4, nil, nil, 0, 0, 0, 0 } }; return true]])
visit(VULO)
C(VULO, [[STUB.guild = SAVED_GUILD; STUB.fire("GUILD_ROSTER_UPDATE"); return true]])
BUS.tick(20)
assert(C(KIM, [[for _, e in ipairs(NS.BankLog().list) do if e.n == "Spaetleser" then return true end end return false]]), "the read went once Vulo's roster told his rank")

---------------------------------------------------------------------------
-- extras C: a received count shows on Bestand although Kim learned no material
---------------------------------------------------------------------------
assert(C(KIM, "#NS.MAT_ORDER") == 0)
local stock = C(KIM, [[NS.ShowPage("bank"); local f = NS.PageFrame("bank"); f.views.bestand:Click()
    local first = f.list.rows[1]
    return { f.state:GetText(), first and first:IsShown() and first.count:GetText() }]])
assert(has(stock[1], "erhalten von"), "the received count shows: " .. tostring(stock[1]))
assert(stock[2] ~= nil and stock[2] ~= "-", "with its counts: " .. tostring(stock[2]))
