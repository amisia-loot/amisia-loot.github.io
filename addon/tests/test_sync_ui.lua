--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- The sync on the pages: the sync line of the awards page in every state, the "wartet" mark, the
-- conflict bar with its buttons, the raider view "Alle Vergaben", the overview card, the settings
-- section "sync" and the /amisia sync commands; the layout at 602 x 478 for officer and raider.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"

local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function settle() BUS.tick(8) end
local function count(name, text)
    return C(name, ("local n = 0; for _, m in ipairs(STUB.messages) do if m:find(%q, 1, true) then n = n + 1 end end; return n"):format(text))
end
-- the officer page of a client, refreshed
local function officer(name, code)
    return C(name, [[NS.ShowPage("awards"); NS.Refresh()
        local f = NS.AwardsPageFrame(); local O = f.officer; local s = NS.Active()
        ]] .. code)
end
local function syncLine(name) return officer(name, "return O.sync:GetText()") end
-- the lines of the sync line's tooltip
local function syncTip(name)
    return officer(name, [[local out, add = {}, GameTooltip.AddLine
        GameTooltip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
        O.syncHit:GetScript("OnEnter")(O.syncHit)
        GameTooltip.AddLine = add
        GameTooltip:Hide(); return table.concat(out, "\n")]])
end

---------------------------------------------------------------------------
-- the raid
---------------------------------------------------------------------------
BUS.setRaid({ VULO, FRAK, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player ~= "Kim Eisherz"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.item(32235, "Fluchsicht des Sargeras", 4)
        STUB.item(30000, "Stiefel der Gezeiten", 4)
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true and C(FRAK, "NS.SyncKeeperName()") == VULO)
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 32235, kind = 'MS', src = 'Ragnaros', note = 'Tausch', t = time() }).id")
local a2 = S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30000, kind = 'OS', src = 'Ragnaros', t = time() }).id")
settle()

---------------------------------------------------------------------------
-- the sync line in every state
---------------------------------------------------------------------------
local line = syncLine(VULO)
assert(line == "Sync: du bist Hüter · 1 Offizier", line)
assert(officer(VULO, "return O.sync.color") == "green")
local rev = S(FRAK, "s.sync.rev")
line = syncLine(FRAK)
assert(line:find("Sync: Hüter Vulo Sturmwind · Stand " .. rev .. " · vor ", 1, true), line)
-- the tooltip has the details
local tip = syncTip(FRAK)
assert(tip:find("Hüter: Vulo Sturmwind", 1, true) and tip:find("Wartende Änderungen: 0", 1, true) and tip:find("Konflikte: 0", 1, true), tip)
-- a waiting wish: gold line, the row says "wartet"
BUS.drop(function(m) return m.sender == FRAK and m.kind == "BL" end)
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { kind = 'MS' })")
line = syncLine(FRAK)
assert(line:find("Sync: 1 Änderung wartet auf Vulo Sturmwind", 1, true) and officer(FRAK, "return O.sync.color") == "gold", line)
local rows = officer(FRAK, [[local out = {}
    for i, r in ipairs(O.list.rows) do if r:IsShown() then out[i] = r.name:GetText() end end
    return out]])
assert(rows[2]:find("Fraktur", 1, true) and rows[2]:find(" · wartet", 1, true), rows[2])
assert(not rows[1]:find("wartet", 1, true), "only the row with the wish")
BUS.tick(200)
line = syncLine(FRAK)
assert(line:find("Sync: 1 Änderung nicht abgeglichen", 1, true), line)
BUS.drop(nil)
C(FRAK, "NS.Dispatch('sync jetzt')")
BUS.tick(20)
assert(syncLine(FRAK):find("Sync: Hüter Vulo Sturmwind", 1, true), syncLine(FRAK))
rows = officer(FRAK, "return O.list.rows[2].name:GetText()")
assert(not rows:find("wartet", 1, true), "the mark is gone with the wish")
-- the keeper's edit panel names who changed the award
local status = officer(VULO, [[O.list.rows[2]:Click(); return O.edit.status:GetText()]])
assert(status:find("geändert von Fraktur", 1, true), status)
-- the lockdown
BUS.lock(true)
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { note = 'im Kampf' })")
line = syncLine(FRAK)
assert(line:find("Sync: wartet auf Kampfende (1 Nachricht)", 1, true), line)
BUS.lock(false)
settle()
-- no keeper, sync off
C(VULO, "NS.Set('sync.enabled', false)")
BUS.tick(15)
assert(syncLine(VULO):find("Sync: aus", 1, true), syncLine(VULO))
line = syncLine(FRAK)
assert(line:find("Sync: kein Hüter im Raid", 1, true) and officer(FRAK, "return O.sync.color") == "grey", line)
tip = syncTip(FRAK)
assert(tip:find("Die Lootleitung hat kein Amisia 2.1 oder keinen Offiziersrang.", 1, true), tip)
C(VULO, "NS.Reset('sync.enabled')")
BUS.tick(20)
settle()
-- a client without the pack functions
local saved = C(FRAK, "local keep = C_EncodingUtil; C_EncodingUtil = nil; NS.Refresh(); local t = NS.AwardsPageFrame().officer.sync:GetText(); C_EncodingUtil = keep; return t")
assert(saved:find("Sync: dieser Client kann nicht packen", 1, true), saved)
-- an older raid
line = officer(FRAK, [[table.insert(AmisiaDB.sessions, 1, { id = "alt", date = "2026-09-01", instanceID = 409, zone = "Alt", start = 1700000000,
        last = 1700000100, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {} })
    O.raid.onPick("alt"); local t = O.sync:GetText(); O.raid.onPick(s.id); return t]])
assert(line:find("Sync: älterer Raid, Änderungen bleiben lokal", 1, true), line)

---------------------------------------------------------------------------
-- layout of the officer view: the head line and the sync line side by side
---------------------------------------------------------------------------
officer(FRAK, [[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("officer head", O.head, O.sync)
    local l, r = L.span(O.sync)
    local h1, h2 = L.span(O.head)
    -- 2.1: the sync line takes the space the counts leave, 12 px after them
    assert(h1 == 6 and h2 <= 336 and h2 - h1 >= math.min(330, O.head:GetStringWidth()), "the counts on at most 330 px: " .. h1 .. ".." .. h2)
    assert(r == 596 and l == h2 + 12, "the sync line right-aligned after the counts: " .. l .. ".." .. r)
    local hl, hr = L.span(O.syncHit)
    assert(hl == l and hr == r, "the tooltip area covers the line")
    for _, t in ipairs({ "Sync: aus", "Sync: kein Hüter im Raid", "Sync: du bist Hüter · 3 Offiziere", "Sync: dieser Client kann nicht packen",
                         "Sync: wartet auf Kampfende (4 Nachrichten)" }) do
        O.sync:SetText(t); L.fits(O.sync)
    end
    NS.Refresh()]])

---------------------------------------------------------------------------
-- the conflict bar
---------------------------------------------------------------------------
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { kind = 'SR' })")
S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { kind = 'OS' })")
S(VULO, "NS.EditAward(s, '" .. a2 .. "', { name = 'Kim Eisherz' })")
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { name = 'Vulo Sturmwind' })")
settle()
assert(S(FRAK, "#s.sync.conflicts") == 2)
local bar = officer(FRAK, [[return { shown = O.conflict:IsShown(), text = O.conflict.text:GetText(), mine = O.conflict.mine:GetText(),
    take = O.conflict.take:GetText(), drop = O.conflict.drop:GetText(), hint = O.edit.hint:IsShown() }]])
assert(bar.shown, "the bar is there")
assert(bar.text == "Konflikt (1 von 2): Vulo Sturmwind hat diese Vergabe zuerst geändert: an Kim Eisherz (SR).", bar.text)
assert(bar.mine == "Deine Änderung: an Kim Eisherz (OS).", bar.mine)
assert(bar.take == "Meine übernehmen" and bar.drop == "Verwerfen")
assert(not bar.hint, "the bar takes the place of the name hint")
-- a click on the bar chooses the award
assert(officer(FRAK, [[O.conflict:Click(); return O.edit:IsShown() and O.edit.title:GetText():find("Fluchsicht", 1, true) ~= nil]]) == true)
-- layout with the bar and the edit panel
officer(FRAK, [[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("conflict bar", O.conflict.mine, O.conflict.take, O.conflict.drop)
    L.column("officer page", O.head, O.list, O.edit.bank, O.conflict)
    local l, r = L.span(O.conflict)
    assert(l == 0 and r == 602, "the bar spans the content: " .. l .. ".." .. r)
    local t, b = L.vspan(O.conflict)
    assert(t - b == 40 and b >= -478, "40 px inside the page: " .. t .. ".." .. b)
    L.inside("conflict bar", O.conflict)
    -- 2.2: Forever's inset with a gold ground instead of an area with a gold frame
    assert(O.conflict.border and O.conflict.border.atlas == "common-insideframe" and O.conflict.ground, "the bar is an inset")
    L.fits(O.conflict.text); L.fits(O.conflict.mine)]])
-- "Meine übernehmen" wins
officer(FRAK, "O.conflict.take:Click()")
settle()
assert(S(VULO, "NS.FindAward(s, '" .. a1 .. "').kind") == "OS" and S(FRAK, "#s.sync.conflicts") == 1)
bar = officer(FRAK, "return { text = O.conflict.text:GetText(), mine = O.conflict.mine:GetText() }")
assert(bar.text == "Konflikt: Vulo Sturmwind hat diese Vergabe zuerst geändert: an Kim Eisherz (MS).", bar.text)
assert(bar.mine == "Deine Änderung: an Vulo Sturmwind (MS).", bar.mine)
-- "Verwerfen" drops it
officer(FRAK, "O.conflict.drop:Click()")
settle()
assert(S(FRAK, "#s.sync.conflicts") == 0 and officer(FRAK, "return O.conflict:IsShown()") == false)
assert(S(FRAK, "NS.FindAward(s, '" .. a2 .. "').name") == KIM)
-- a deleted award: "Wiederherstellen und ändern"
S(VULO, "NS.DeleteAward(s, '" .. a2 .. "')")
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { kind = 'SR' })")
settle()
bar = officer(FRAK, "return { text = O.conflict.text:GetText(), mine = O.conflict.mine:GetText(), take = O.conflict.take:GetText() }")
assert(bar.text == "Konflikt: Vulo Sturmwind hat diese Vergabe gelöscht.", bar.text)
assert(bar.mine == "Deine Änderung: an Kim Eisherz (SR).", bar.mine)
assert(bar.take == "Wiederherstellen und ändern", bar.take)
officer(FRAK, [[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("conflict bar gone", O.conflict.mine, O.conflict.take, O.conflict.drop)]])
officer(FRAK, "O.conflict.take:Click()")
settle()
local back = S(VULO, "local a, _, gone = NS.FindAward(s, '" .. a2 .. "'); return { gone = gone, kind = a.kind }")
assert(back.gone == false and back.kind == "SR", "restored and changed")

---------------------------------------------------------------------------
-- the raider view: "Deine Items" and "Alle Vergaben"
---------------------------------------------------------------------------
local function raider(code)
    return C(KIM, [[NS.ShowPage("awards"); NS.Refresh()
        local f = NS.AwardsPageFrame(); local R = f.raider; local A = R.all; local s = NS.Active()
        ]] .. code)
end
local r = raider([[return { raider = R:IsShown(), officer = f.officer:IsShown(), mine = R.mineChip:IsShown(), all = R.allChip:IsShown(),
    text = R.text:GetText() }]])
assert(r.raider and not r.officer and r.mine and r.all, "both chips with a snapshot")
assert(r.text == "Alle Vergaben deines Raids siehst du unter Alle Vergaben, ältere auf der Amisia-Loot-Seite.", r.text)
r = raider([[R.allChip:Click()
    local rows = {}
    for i, row in ipairs(A.list.rows) do
        if row:IsShown() then rows[i] = { time = row.time:GetText(), item = row.itemText:GetText(), name = row.name:GetText(), kind = row.kind:GetText(),
            plus = row.plus:GetText() } end
    end
    return { view = AmisiaDB.settings.awards.raiderView, shown = A:IsShown(), mineShown = R.mine:IsShown(), raid = A.raid:GetValue(),
             values = #A.raid.values, rows = rows, foot = A.foot:GetText(), empty = A.empty:IsShown(), allOn = R.allChip.on,
             title = R.title:GetText() }]])
assert(r.view == "all" and r.shown and not r.mineShown and r.allOn, "the view is remembered")
assert(r.raid == S(KIM, "s.id") and r.values == 1, "the running raid is chosen")
assert(#r.rows == 2 and not r.empty, "two awards")
assert(r.rows[1].item:find("Fluchsicht", 1, true) and r.rows[1].name:find("Kim Eisherz", 1, true) and r.rows[1].name:find("e2b857", 1, true),
    "the own name in gold: " .. r.rows[1].name)
assert(r.rows[1].kind == "OS" and r.rows[1].plus == "", r.rows[1].kind)
assert(r.rows[2].name:find("Kim Eisherz", 1, true) and r.rows[2].kind == "SR")
assert(r.rows[1].time:match("^%d%d:%d%d$"))
for _, row in ipairs(r.rows) do assert(not row.name:find("Tausch", 1, true) and not row.item:find("Tausch", 1, true), "no notes") end
assert(r.foot:find("^Stand von Vulo Sturmwind, %d%d:%d%d · Notizen sehen nur Offiziere%.$"), r.foot)
-- the plus-one of the keeper
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { kind = 'MS' })")
settle()
r = raider("return A.list.rows[1].plus:GetText()")
assert(r == "1", "plus-one from the snapshot: " .. tostring(r))
-- layout of the raider view
raider([[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("raider head", R.title, R.mineChip, R.allChip)
    L.row("raider columns", A.cols.time, A.cols.item, A.cols.name, A.cols.kind, A.cols.plus)
    L.column("raider all", A.raid, A.cols.time, A.list, A.foot)
    L.fits(A.foot)
    local l, r = L.span(A.raid)
    assert(r - l == 240, "the raid choice is 240 px")]])
-- a raid with a snapshot but no awards: the empty text
r = raider([[table.insert(AmisiaDB.sessions, 1, { id = "leer", date = "2026-09-02", instanceID = 409, zone = "Leer", start = 1700100000,
        last = 1700100100, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {},
        sync = { key = "2026-09-02:409", rev = 3, keeper = "Vulo Sturmwind", at = 1700100100 } })
    NS.Refresh()
    local n = #A.raid.values
    A.raid.onPick("leer")
    return { n = n, empty = A.empty:IsShown(), text = A.empty:GetText(), rows = A.list.rows[1]:IsShown() }]])
assert(r.n == 2 and r.empty and not r.rows, "the empty raid")
assert(r.text == "Für diesen Raid hat Amisia noch keine Vergaben von der Lootleitung bekommen.", r.text)
raider([[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.fits(A.empty)
    table.remove(AmisiaDB.sessions, 1); A.raid.onPick(s.id)]])
-- back to "Deine Items"
r = raider([[R.mineChip:Click(); return { view = AmisiaDB.settings.awards.raiderView, list = R.mine:IsShown(), all = A:IsShown() }]])
assert(r.view == "mine" and r.list and not r.all)
raider([[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.column("raider mine", R.title, R.list, R.text)]])
-- without any snapshot: no chip "Alle Vergaben", the old text
r = raider([[local keep = s.sync; s.sync = nil; AmisiaDB.settings.awards.raiderView = "all"; NS.Refresh()
    local out = { all = R.allChip:IsShown(), text = R.text:GetText(), list = R.mine:IsShown() }
    s.sync = keep; AmisiaDB.settings.awards.raiderView = "mine"; NS.Refresh(); return out]])
assert(not r.all and r.list and r.text == "Vergaben anderer siehst du auf der Amisia-Loot-Seite.", r.text)

---------------------------------------------------------------------------
-- the overview card of the raider: the own plus-one
---------------------------------------------------------------------------
r = C(KIM, [[local spec; for _, c in ipairs(NS.cards) do if c.key == "awards" then spec = c end end
    local card = NS.W.Card(UIParent, 296, 112); card:SetAction(nil); spec.fill(card)
    return { title = card.title:GetText(), line2 = card.line2:GetText() }]])
assert(r.title == "Deine Items letzte Nacht" and r.line2 == "Dein Plus-Eins: 1", tostring(r.line2))

---------------------------------------------------------------------------
-- the settings section "sync"
---------------------------------------------------------------------------
local items = C(FRAK, [[for _, sec in ipairs(NS.schema) do if sec.key == "sync" then
        local out = {}
        for i, it in ipairs(sec.items) do out[i] = { key = it.key, officer = it.officer, expert = it.expert, default = it.default, label = it.label } end
        return { label = sec.label, order = sec.order, items = out }
    end end]])
assert(items.label == "Sync und Version" and items.order == 85)
local want = { { "sync.enabled", true }, { "sync.raiderAwards", true }, { "sync.shareUpgrades", true }, { "sync.versionCheck", true },
               { "sync.outdatedWarn", true }, { "sync.askUpgrades", true, "officer" }, { "sync.needTooltip", true, "officer" },
               { "sync.notify", true, "officer" }, { "sync.officerRanks", "auto", "expert" }, { "sync.debug", false, "expert" } }
assert(#items.items == #want, "ten entries: " .. #items.items)
for i, w in ipairs(want) do
    local it = items.items[i]
    assert(it.key == w[1] and it.default == w[2], i .. ": " .. tostring(it.key))
    assert((w[3] == "officer") == (it.officer == true) and (w[3] == "expert") == (it.expert == true), it.key)
end
assert(items.items[3].label == "Der Lootleitung meine Upgrades nennen")
assert(items.items[6].label == "Beim Ansagen fragen, für wen ein Item ein Upgrade ist" and items.items[7].label == "Tooltip-Zeile Upgrade für")
-- the rows on the settings page: officer items for officers, not for raiders
assert(C(FRAK, "NS.ShowPage('settings'); NS.Refresh(); return NS.SettingsRows()['sync.askUpgrades']:IsShown()") == true)
assert(C(KIM, "NS.ShowPage('settings'); NS.Refresh(); local r = NS.SettingsRows()['sync.askUpgrades']; return r ~= nil and r:IsShown()") == false)
assert(C(KIM, "return NS.SettingsRows()['sync.shareUpgrades']:IsShown()") == true)

---------------------------------------------------------------------------
-- the commands
---------------------------------------------------------------------------
C(FRAK, "STUB.messages = {}; NS.Dispatch('sync')")
local out = C(FRAK, "return table.concat(STUB.messages, '\\n')")
assert(out:find("Sync: Hüter Vulo Sturmwind", 1, true) and out:find("Prüfsumme", 1, true) and out:find("Wartende Änderungen: 0", 1, true)
    and out:find("Konflikte: 0", 1, true) and out:find("Schlange:", 1, true), out)
C(VULO, "STUB.messages = {}; NS.Dispatch('sync jetzt')")
assert(count(VULO, "Raid-Stand gesendet.") == 1)
C(KIM, "STUB.messages = {}; NS.Dispatch('sync jetzt')")
assert(count(KIM, "Nur in der Offiziersansicht.") == 1)
C(FRAK, "STUB.messages = {}; NS.Dispatch('sync aus')")
assert(C(FRAK, "NS.Get('sync.enabled')") == false and count(FRAK, "Raid-Abgleich aus.") == 1)
C(FRAK, "NS.Dispatch('sync an')")
assert(C(FRAK, "NS.Get('sync.enabled')") == true and count(FRAK, "Raid-Abgleich an.") == 1)
C(FRAK, "STUB.messages = {}; NS.Dispatch('sync raenge')")
assert(count(FRAK, "Gildenränge (Quelle: Rangrechte):") == 1)
C(FRAK, "STUB.messages = {}; NS.Dispatch('sync selbsttest')")
assert(count(FRAK, "Nur im Expertenmodus.") == 1)
C(FRAK, "NS.Set('ui.expert', true); STUB.messages = {}; NS.Dispatch('sync selbsttest')")
out = C(FRAK, "return table.concat(STUB.messages, '\\n')")
assert(out:find("Selbsttest: Abbild gepackt und entpackt, gleich.", 1, true) and out:find("Teile", 1, true), out)
C(FRAK, "local keep = C_EncodingUtil; C_EncodingUtil = nil; STUB.messages = {}; NS.Dispatch('sync selbsttest'); C_EncodingUtil = keep")
assert(count(FRAK, "Selbsttest: dieser Client kann nicht packen") == 1)
C(FRAK, "NS.Reset('ui.expert'); STUB.messages = {}; NS.Dispatch('sync quatsch')")
assert(count(FRAK, "Aufruf: /amisia sync [jetzt|an|aus|raenge|debug|selbsttest]") == 1)
C(FRAK, "STUB.messages = {}; NS.Dispatch('version')")
assert(count(FRAK, "Frage den Raid nach Amisia-Versionen.") == 1)
BUS.tick(12)

for _, file in ipairs({ "Raid/Sync.lua", "Core/Comm.lua", "Raid/Awards.lua", "UI/Pages/Awards.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for ch in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. ch) end
end
