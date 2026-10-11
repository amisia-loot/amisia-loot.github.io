--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- 2.1 UI review: the guild bank list keeps 18 rows on the page and scrolls; the award dialog
-- shows "Fragen" only where asking works; the conflict bar cuts notes and has both sentences as
-- tooltip; the sync line takes the space the counts leave; a gold mark for conflicts of the
-- running raid while another raid is shown; the shorter settings label; the scroll hint on the
-- About page.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"

local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function settle() BUS.tick(8) end
local function officer(name, code)
    return C(name, [[NS.ShowPage("awards"); NS.Refresh()
        local f = NS.AwardsPageFrame(); local O = f.officer; local s = NS.Active()
        ]] .. code)
end

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
assert(C(VULO, "NS.SyncIsKeeper()") == true)

---------------------------------------------------------------------------
-- 1. the guild bank: 18 rows on the 478 px page (2.10: 17 under the view chips), the wheel for the rest
---------------------------------------------------------------------------
local bank = C(VULO, [[
    local function page(n)
        for i = 1, 40 do AmisiaDB.mats[20000 + i] = nil end
        for i = 1, n do
            STUB.item(20000 + i, "Material " .. i, 2)
            AmisiaDB.mats[20000 + i] = { name = "Material " .. i, q = 2, first = i }
        end
        NS.RebuildMats()
        local p = NS.Panel("bank")
        local root = CreateFrame("Frame", nil, UIParent); root:SetSize(602, 478)
        local f = p.create(root); f:SetAllPoints(root)
        p.refresh(f)
        return f, root
    end
    local f, root = page(30)
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(root, 602, 478)
    local shown = 0
    for _, r in ipairs(f.list.rows) do if r:IsShown() then shown = shown + 1 end end
    -- every row of the list on the page
    L.column("bank rows", f.list.rows[1], f.list.rows[#f.list.rows])
    local out = { rows = #f.list.rows, shown = shown, state = f.state:GetText() }
    for _ = 1, 20 do f.list:GetScript("OnMouseWheel")(f.list, -1) end
    out.last = f.list.rows[17].item and f.list.rows[17].item.id
    local g = page(10)
    out.small = g.state:GetText()
    return out]])
assert(bank.rows == 17 and bank.shown == 17, "17 rows: " .. bank.rows .. " / " .. bank.shown)
assert(bank.state:find("17 von 30 sichtbar, Mausrad", 1, true), bank.state)
assert(bank.last == 20030, "the wheel reaches the last material")
assert(not bank.small:find("Mausrad", 1, true), "no hint while all fit: " .. bank.small)

---------------------------------------------------------------------------
-- 2. "Fragen" only where asking works (ns.NeedCanAsk)
---------------------------------------------------------------------------
local function dialog(name)
    return C(name, [[local D = NS.ShowAwardDialog(32235)
        local out = { can = NS.NeedCanAsk() and true or false, ask = D.ask:IsShown(), need = D.need:GetText(),
            w = D.need._w }
        D:Hide()
        return out]])
end
local frak = dialog(FRAK)
assert(frak.can == false, "Fraktur is no loot lead")
assert(not frak.ask, "no Fragen button for an officer who cannot ask")
assert(frak.need == "" and frak.w == 356, "no need line without answers: '" .. tostring(frak.need) .. "'")
local vulo = dialog(VULO)
assert(vulo.can == true, "the master looter can ask")
assert(vulo.ask and vulo.need == "Upgrade für: noch nicht gefragt", tostring(vulo.need))

---------------------------------------------------------------------------
-- 3. the conflict bar: notes cut to 20 characters plus "...", both sentences in full as tooltip
---------------------------------------------------------------------------
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 32235, kind = 'MS', src = 'Ragnaros', t = time() }).id")
settle()
local KEEPER_NOTE = "Tausch gegen die Brust aus dem Schwarzen Tempel"
local MY_NOTE = "Für den Tank, weil er sonst nichts bekommt"
S(VULO, "NS.EditAward(s, '" .. a1 .. "', { note = '" .. KEEPER_NOTE .. "' })")
S(FRAK, "NS.EditAward(s, '" .. a1 .. "', { note = '" .. MY_NOTE .. "' })")
settle()
assert(S(FRAK, "#s.sync.conflicts") == 1, "one conflict")
local bar = officer(FRAK, [[local B = O.conflict
    local out, add = {}, GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
    local enter = B:GetScript("OnEnter")
    if enter then enter(B) end
    GameTooltip.AddLine = add
    GameTooltip:Hide()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.fits(B.text); L.fits(B.mine)
    return { shown = B:IsShown(), text = B.text:GetText(), mine = B.mine:GetText(), tip = out }]])
assert(bar.shown, "the bar is there")
assert(bar.text == 'Konflikt: Vulo Sturmwind hat diese Vergabe zuerst geändert: Notiz "Tausch gegen die Bru...".', bar.text)
assert(bar.mine == 'Deine Änderung: Notiz "Für den Tank, weil e...".', bar.mine)
assert(#bar.tip == 3 and bar.tip[1] == "Konflikt", "a tooltip with a title and two lines: " .. #bar.tip)
assert(bar.tip[2] == 'Konflikt: Vulo Sturmwind hat diese Vergabe zuerst geändert: Notiz "' .. KEEPER_NOTE .. '".', tostring(bar.tip[2]))
assert(bar.tip[3] == 'Deine Änderung: Notiz "' .. MY_NOTE .. '".', tostring(bar.tip[3]))

---------------------------------------------------------------------------
-- 4. the sync line takes the space the counts leave: the keeper's long name fits
---------------------------------------------------------------------------
local sync = officer(FRAK, [[local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("officer head", O.head, O.sync)
    L.fits(O.sync)
    local l, r = L.span(O.sync)
    local hl, hr = L.span(O.syncHit)
    return { text = O.sync:GetText(), l = l, r = r, hl = hl, hr = hr,
        want = 590 - math.min(330, math.ceil(O.head:GetStringWidth())) - 12 }]])
assert(sync.text:find("Sync: Hüter Vulo Sturmwind · Stand ", 1, true), sync.text)
assert(sync.r == 596 and sync.r - sync.l >= sync.want, ("%d..%d, want %d"):format(sync.l, sync.r, sync.want))
assert(sync.hl == sync.l and sync.hr == sync.r, "the tooltip area covers the line")

---------------------------------------------------------------------------
-- (B) a gold mark in the head for conflicts of the running raid while another raid is shown
---------------------------------------------------------------------------
local heads = officer(FRAK, [[table.insert(AmisiaDB.sessions, 1, { id = "alt", date = "2026-09-01", instanceID = 409, zone = "Alt",
        start = 1700000000, last = 1700000100, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {} })
    local out = {}
    O.raid.onPick("alt"); out.alt = O.head:GetText(); out.altBar = O.conflict:IsShown()
    O.raid.onPick("all"); out.all = O.head:GetText()
    O.raid.onPick(s.id); out.running = O.head:GetText(); out.bar = O.conflict:IsShown()
    return out]])
assert(heads.alt:find("|cffe2b857 1 Konflikt im laufenden Raid|r", 1, true) == nil, "no space inside the colour")
assert(heads.alt:find("1 Konflikt im laufenden Raid", 1, true) and heads.alt:find("|cffe2b857", 1, true), heads.alt)
assert(not heads.altBar, "the bar belongs to the running raid")
assert(heads.all:find("1 Konflikt im laufenden Raid", 1, true), heads.all)
assert(not heads.running:find("Konflikt", 1, true) and heads.bar, "the running raid shows the bar instead: " .. heads.running)

---------------------------------------------------------------------------
-- the settings label and the About page
---------------------------------------------------------------------------
assert(C(KIM, "NS.SettingItem('sync.shareUpgrades').label") == "Der Lootleitung meine Upgrades nennen")
local about = C(VULO, [[local rows = {}
    for i = 1, 12 do rows[i] = { name = "Spieler" .. i, where = "guild", v = "2.1" } end
    rows[1].self = true
    local keep = NS.VersionRows
    NS.VersionRows = function() return rows end
    local p = NS.Panel("about")
    local root = CreateFrame("Frame", nil, UIParent); root:SetSize(602, 478)
    local f = p.create(root); f:SetAllPoints(root)
    p.refresh(f)
    local many = f.summary:GetText()
    for i = 9, 12 do rows[i] = nil end
    p.refresh(f)
    local few = f.summary:GetText()
    NS.VersionRows = keep
    return { many = many, few = few }]])
assert(about.many:find("8 von 12, Mausrad", 1, true), about.many)
assert(not about.few:find("Mausrad", 1, true), about.few)
