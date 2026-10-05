--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Anna Bob Pug]]
-- "Wer braucht das?" (Need.lua): the loot lead (Vulo Sturmwind, master looter and officer) asks
-- while announcing; every raider client answers from its own gear (Kim Eisherz and Anna, warriors
-- with different gear; Fraktur, a mage officer who cannot wear plate; Bob with sharing off; Pug, a
-- guest outside the guild). The answers show in the award dialog, the winner picker (upgrade askers
-- right after the guild wishers) and an officer tooltip line; never in the raid chat. Questions only
-- from the elected loot lead with officer rank, answers only from guild members in the group, the
-- lockdown holds the question, the answers expire, /amisia wer.
local VULO, FRAK, KIM, ANNA, BOB, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Anna", "Bob", "Pug"

local function count(name, text)
    return C(name, ("local n = 0; for _, m in ipairs(STUB.messages) do if m:find(%q, 1, true) then n = n + 1 end end; return n"):format(text))
end
local function last(list, kind, sender)
    local out
    for _, m in ipairs(BUS.sent) do
        if m.kind == kind and (not sender or m.sender == sender) then out = m end
    end
    return out
end
local function fields(m)
    local out = {}
    for f in (m.text:sub(4) .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = f end
    table.remove(out, 1)   -- the empty field before the first tab
    return out
end

---------------------------------------------------------------------------
-- the raid, the guild and the gear of every client
---------------------------------------------------------------------------
BUS.setRaid({ VULO, FRAK, KIM, ANNA, BOB, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 }, { name = ANNA, rank = 4 },
               { name = BOB, rank = 4 } })
local GEAR = [[
local Gear = NS.Gear
NS.GEAR = { game = "forever", cap = 60, built = "test-need", I = {}, Z = {},
    S = { { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 0, 0 } } }
Gear._reset()
local function gear(id, name, loc, str)
    STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 4
    it.stats, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = str }, 60
    NS.GEAR.I[id] = { loc, 4, 4, 60, 4, 1, 70, 0, 0, 0, 1 }
end
gear(301, "Helm A", "HEAD", 40)
gear(302, "Helm B", "HEAD", 30)
gear(304, "Brust A", "CHEST", 50)
gear(305, "Brust B", "CHEST", 60)
STUB.items[307] = { name = "Marke", quality = 4, link = STUB.link(307, "Marke", 4), equipLoc = "", classID = 15 }
STUB.class, STUB.level = STUB.player == "Fraktur" and "MAGE" or "WARRIOR", 60
]]
for i, name in ipairs(CLIENTS) do
    C(name, GEAR)
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
-- Kim wears the weaker helm and no chest; Anna wears helm A and the better chest and wishes chest A
C(KIM, "STUB.worn[1] = STUB.items[302].link; STUB.fire('PLAYER_EQUIPMENT_CHANGED')")
C(ANNA, "STUB.worn[1] = STUB.items[301].link; STUB.worn[5] = STUB.items[305].link; STUB.fire('PLAYER_EQUIPMENT_CHANGED')")
assert(C(ANNA, "NS.WishAdd(304, 3) ~= nil"), "Anna wishes chest A")
assert(C(BOB, "NS.Set('sync.shareUpgrades', false)"))
BUS.tick(30)
assert(C(VULO, "NS.IsLootLead()") == true and C(KIM, "NS.IsLootLead()") == false)
assert(C(VULO, "NS.IsVerifiedMember('Bob')") == true and C(VULO, "NS.IsVerifiedMember('Pug')") == false)

-- the settings of the section
assert(C(KIM, "NS.SettingItem('sync.shareUpgrades').default") == true)
assert(C(KIM, "NS.SettingItem('sync.askUpgrades').default") == true and C(KIM, "NS.SettingItem('sync.askUpgrades').officer") == true)
assert(C(KIM, "NS.SettingItem('sync.needTooltip').default") == true)

-- what Kim's own gear says about the items
local kGain, kSlot, kMine = C(KIM, "NS.BisGain(301)")
assert(kSlot == "HEAD" and kGain > 0 and kMine > 0, "Kim: helm A beats helm B")
local kPct = math.floor(kGain / kMine * 100 + 0.5)
local kGain4, kSlot4, kMine4 = C(KIM, "NS.BisGain(304)")
assert(kSlot4 == "CHEST" and kMine4 == 0 and kGain4 > 0, "Kim has no chest")
assert(C(ANNA, "NS.BisOwned(301)") == "worn")
assert(not C(ANNA, "local g, _, m = NS.BisGain(304); return NS.BisIsUpgrade(g, m)"), "chest A is no upgrade for Anna")

---------------------------------------------------------------------------
-- the announcement asks: one question for the batch, through the raid channel
---------------------------------------------------------------------------
local BOSS = "Creature-0-1-1-1-22917-1"
C(VULO, ([[STUB.target, STUB.targetGUID = "Ragnaros", %q
    STUB.loot = {}
    for i, id in ipairs({ 301, 304, 307 }) do STUB.loot[i] = { link = STUB.items[id].link, name = "x", src = %q } end
    STUB.chat = {}
    STUB.fire("LOOT_OPENED", false)]]):format(BOSS, BOSS))
local uq = last(BUS.sent, "UQ", VULO)
assert(uq and uq.chan == "RAID" and uq.prefix == "Amisia", "the question goes into the raid")
local f = fields(uq)
local QID = f[1]
assert(QID:match("^%x%x%x%x$") and f[2] == "301,304,307", uq.text)
assert(BUS.count({ kind = "UQ" }) == 1, "one question for the batch")
BUS.tick(4)
assert(C(VULO, "#STUB.chat") == 4, "the announcement in the raid chat")

-- the answers: by whisper to the lead, one per client and question
local ua = last(BUS.sent, "UA", KIM)
assert(ua and ua.chan == "WHISPER" and ua.target == VULO, "Kim whispers the lead")
f = fields(ua)
assert(f[1] == QID, "the answer names the question")
local want = ("301:U:%d:%d:HEAD,304:U:%d:999:CHEST,307:-:0:0:-"):format(math.floor(kGain + 0.5), kPct, math.floor(kGain4 + 0.5))
assert(f[2] == want, f[2] .. " / " .. want)
ua = last(BUS.sent, "UA", ANNA)
assert(ua and fields(ua)[2] == "301:-:0:0:-,304:W:3:0:-,307:-:0:0:-", "Anna: owned, wish, nothing: " .. (ua and ua.text or "none"))
ua = last(BUS.sent, "UA", FRAK)
assert(ua and fields(ua)[2] == "301:-:0:0:-,304:-:0:0:-,307:-:0:0:-", "Fraktur cannot wear it")
assert(BUS.count({ kind = "UA", sender = BOB }) == 0, "sharing off: no answer")
assert(BUS.count({ kind = "UA", sender = PUG }) == 0, "the guest cannot check the lead")
assert(BUS.count({ kind = "UA" }) == 3)
assert(BUS.count(function(m) return m.kind == "UA" and m.chan ~= "WHISPER" end) == 0)
-- never in the raid chat
for _, name in ipairs(CLIENTS) do
    assert(C(name, "local n = 0; for _, c in ipairs(STUB.chat) do if c.text:find('Upgrade', 1, true) then n = n + 1 end end; return n") == 0, name)
end

-- collected per item at the lead
local need = C(VULO, "NS.NeedOf(301)")
assert(#need.up == 1 and need.up[1].name == KIM and need.up[1].pct == kPct and need.up[1].slot == "HEAD", "Kim's upgrade")
assert(#need.wish == 0 and need.none == 2 and need.missing == 1 and need.asked == 4, "two without upgrade, Bob without answer")
need = C(VULO, "NS.NeedOf(304)")
assert(#need.up == 1 and need.up[1].pct == 999 and #need.wish == 1 and need.wish[1].name == ANNA and need.wish[1].prio == 3)
local text301 = ("Kim Eisherz +%d %% (Kopf) · 2 ohne Upgrade · 1 ohne Antwort"):format(kPct)
assert(C(VULO, "NS.NeedText(301)") == text301, C(VULO, "NS.NeedText(301)"))
assert(C(VULO, "NS.NeedText(304)") == "Kim Eisherz +999 % (Brust), Anna Wunsch (hoch) · 1 ohne Upgrade · 1 ohne Antwort",
    C(VULO, "NS.NeedText(304)"))
assert(C(VULO, "NS.NeedText(307)") == "niemand · 3 ohne Upgrade · 1 ohne Antwort", C(VULO, "NS.NeedText(307)"))
assert(C(VULO, "NS.NeedOf(302)") == nil and C(VULO, "NS.NeedText(302)") == nil, "never asked")

---------------------------------------------------------------------------
-- rate limits: the same list not twice in 2 minutes, one answer per question
---------------------------------------------------------------------------
C(VULO, "NS.Dispatch('ansage')")
assert(BUS.count({ kind = "UQ" }) == 1, "the same list again within 2 minutes: no question")
local q, why = C(VULO, "NS.NeedAsk({ 301, 304, 307 })")
assert(q == nil and why:find("gerade", 1, true), tostring(why))
-- the same question again (as a client would repeat it): every client answers once
BUS.tick(6)
C(VULO, ("NS.CommSend('UQ', { %q, '301,304,307' }, 'RAID')"):format(QID))
BUS.tick(4)
assert(BUS.count({ kind = "UA", sender = KIM }) == 1, "one answer per question")
-- questions from anyone but the elected loot lead are ignored: an officer that does not lead, a raider
local before = BUS.count({ kind = "UA" })
C(FRAK, "NS.CommSend('UQ', { 'beef', '301' }, 'RAID')")
BUS.tick(6)
C(KIM, "NS.CommSend('UQ', { 'cafe', '301' }, 'RAID')")
BUS.tick(4)
assert(BUS.count({ kind = "UA" }) == before, "no answer to Fraktur or Kim")
local q2, why2 = C(KIM, "NS.NeedAsk({ 301 })")
assert(q2 == nil and type(why2) == "string", "a raider cannot ask")
-- a forged answer of the guest and an answer to a question nobody asked are ignored
C(PUG, ("NS.CommSend('UA', { %q, '301:U:500:500:HEAD' }, 'WHISPER', 'Vulo Sturmwind')"):format(QID))
C(KIM, "NS.CommSend('UA', { 'dead', '301:U:500:500:HEAD' }, 'WHISPER', 'Vulo Sturmwind')")
BUS.tick(2)
assert(BUS.count({ kind = "UA", sender = PUG }) == 1, "the forged answer went out")
need = C(VULO, "NS.NeedOf(301)")
assert(#need.up == 1 and need.up[1].name == KIM and need.up[1].pct == kPct, "the guest's answer is ignored")

---------------------------------------------------------------------------
-- the award dialog: the line "Upgrade für:", the picker, the button "Fragen"
---------------------------------------------------------------------------
C(VULO, [[NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-05\nW 301 2 Fraktur\n#END")]])
local dlg = C(VULO, [[local D = NS.ShowAwardDialog(STUB.items[301].link)
    local vals, texts = {}, {}
    for i, v in ipairs(D.winner.values) do vals[i], texts[i] = v.value, v.text end
    return { need = D.need:GetText(), vals = table.concat(vals, ","), texts = table.concat(texts, ","),
             ask = D.ask:IsShown(), roll = D.roll:GetText(), h = D:GetHeight() }]])
assert(dlg.need == "Upgrade für: " .. text301, dlg.need)
assert(dlg.vals == "Fraktur,Kim Eisherz,Anna,Bob,Pug,Vulo Sturmwind", "guild wisher, upgrade, the rest: " .. dlg.vals)
assert(dlg.texts == ("Fraktur (Wunsch mittel),Kim Eisherz (Upgrade +%d %%),Anna,Bob,Pug,Vulo Sturmwind"):format(kPct), dlg.texts)
assert(not dlg.ask, "answers there: no button")
assert(not dlg.roll:find("Upgrade", 1, true), "the roll line stays")
assert(dlg.h == 248, "the window is taller")
-- the tooltip of the line names everything
local tipLines = C(VULO, [[local D = AmisiaAwardDialog
    local out, add = {}, GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
    D.needHit:GetScript("OnEnter")(D.needHit)
    GameTooltip.AddLine = add
    return table.concat(out, "\n")]])
assert(tipLines:find("Kim Eisherz +" .. kPct .. " % (Kopf)", 1, true) and tipLines:find("ohne Antwort: Bob", 1, true), tipLines)
-- an item nobody was asked about: the button asks
dlg = C(VULO, [[local D = NS.ShowAwardDialog(STUB.items[302].link)
    return { need = D.need:GetText(), ask = D.ask:IsShown(), texts = (function()
        local t = {}; for i, v in ipairs(D.winner.values) do t[i] = v.text end; return table.concat(t, ",") end)() }]])
assert(dlg.ask and dlg.need == "Upgrade für: noch nicht gefragt", dlg.need)
assert(dlg.texts == "Anna,Bob,Fraktur,Kim Eisherz,Pug,Vulo Sturmwind", "no answers: as before")
-- the lockdown holds the question until the fight ends
local uqBefore = BUS.count({ kind = "UQ" })
BUS.lock(true)
C(VULO, "AmisiaAwardDialog.ask:Click()")
BUS.tick(3)
assert(BUS.count({ kind = "UQ" }) == uqBefore, "nothing in the lockdown")
assert(C(VULO, "NS.NeedText(302)") == "noch keine Antworten · 4 ohne Antwort", C(VULO, "NS.NeedText(302)"))
assert(C(VULO, "AmisiaAwardDialog.ask:IsShown()") == false, "asked: the button goes")
BUS.lock(false)
BUS.tick(4)
assert(BUS.count({ kind = "UQ" }) == uqBefore + 1, "after the fight")
need = C(VULO, "NS.NeedOf(302)")
assert(#need.up == 0 and need.none == 3, "helm B is no upgrade for anyone")
assert(C(VULO, "AmisiaAwardDialog.need:GetText()") == "Upgrade für: niemand · 3 ohne Upgrade · 1 ohne Antwort", "the dialog follows the answers")
C(VULO, "AmisiaAwardDialog:Hide()")

---------------------------------------------------------------------------
-- the officer tooltip line
---------------------------------------------------------------------------
local TIP = [[local tip = CreateFrame("GameTooltip")
    local out = {}
    tip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
    STUB.showTooltip(tip, STUB.items[%d].link)
    for _, l in ipairs(out) do if l:find("^Upgrade für:") then return l end end
    return nil]]
assert(C(VULO, TIP:format(301)) == ("Upgrade für: Kim Eisherz +%d %%"):format(kPct), tostring(C(VULO, TIP:format(301))))
assert(C(VULO, TIP:format(304)) == "Upgrade für: Kim Eisherz +999 %, Anna", tostring(C(VULO, TIP:format(304))))
assert(C(VULO, TIP:format(307)) == nil, "nobody needs it: no line")
assert(C(VULO, "NS.Set('sync.needTooltip', false)"))
assert(C(VULO, TIP:format(301)) == nil, "switched off")
C(VULO, "NS.Reset('sync.needTooltip')")
assert(C(KIM, TIP:format(301)) == nil, "raiders get no line")

---------------------------------------------------------------------------
-- sync.askUpgrades off: the announcement asks nothing
---------------------------------------------------------------------------
BUS.tick(6)
uqBefore = BUS.count({ kind = "UQ" })
assert(C(VULO, "NS.Set('sync.askUpgrades', false)"))
C(VULO, [[STUB.loot = { { link = STUB.items[305].link, name = "x", src = "Creature-0-1-1-1-22917-2" } }
    STUB.chat = {}
    STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED", false)]])
BUS.tick(3)
assert(C(VULO, "#STUB.chat") == 2, "announced")
assert(BUS.count({ kind = "UQ" }) == uqBefore, "but not asked")
C(VULO, "NS.Reset('sync.askUpgrades')")

---------------------------------------------------------------------------
-- /amisia wer
---------------------------------------------------------------------------
C(VULO, "STUB.messages = {}")
C(VULO, "NS.Dispatch('wer ' .. STUB.items[305].link)")
assert(BUS.count({ kind = "UQ" }) == uqBefore + 1, "the command asks")
assert(count(VULO, "Antworten in 5 s") == 1)
BUS.tick(5.5)
local kGain5 = C(KIM, "NS.BisGain(305)")
local line = C(VULO, "STUB.messages[#STUB.messages]")
assert(line:find(("Upgrade für %s: Kim Eisherz +999 %% (Brust) · 2 ohne Upgrade · 1 ohne Antwort"):format(C(VULO, "STUB.items[305].link")), 1, true),
    line .. " " .. tostring(kGain5))
C(VULO, "NS.Dispatch('upgrade')")
assert(count(VULO, "Aufruf: /amisia wer <Item-Link>") == 1, "the alias without an item")
assert(C(KIM, "NS.Dispatch('wer 301'); return #STUB.messages > 0"))

---------------------------------------------------------------------------
-- the answers expire with the loot: 30 minutes, then nothing is shown and late answers are ignored
---------------------------------------------------------------------------
C(VULO, "STUB.tick(1801)")
assert(C(VULO, "NS.NeedOf(301)") == nil and C(VULO, "NS.NeedText(301)") == nil, "expired")
assert(C(VULO, TIP:format(304)) == nil, "no tooltip line after 30 minutes")
C(KIM, ("NS.CommSend('UA', { %q, '301:U:20:33:HEAD' }, 'WHISPER', 'Vulo Sturmwind')"):format(QID))
BUS.tick(1)
assert(C(VULO, "NS.NeedOf(301)") == nil, "a late answer starts nothing")
local dlg2 = C(VULO, "local D = NS.ShowAwardDialog(STUB.items[301].link); return { D.need:GetText(), D.ask:IsShown() }")
assert(dlg2[1] == "Upgrade für: noch nicht gefragt" and dlg2[2] == true)
C(VULO, "AmisiaAwardDialog:Hide()")

-- Latin-1 only
for _, file in ipairs({ "Need.lua", "AwardDialog.lua", "LootAnnounce.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for c in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. c) end
end
