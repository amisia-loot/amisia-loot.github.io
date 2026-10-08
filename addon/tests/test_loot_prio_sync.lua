--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- The loot prio shared in the raid (LootPrio.lua): Vulo Sturmwind is master looter, officer and the
-- sync keeper and holds the officers' list; Fraktur is an officer, Kim Eisherz a raider, Pug a
-- guest outside the guild. The keeper announces its state (LV), the others ask (LQ) and get the
-- whole list (LC); a raider then sees it in the tooltip and on the roll frames. An in-game edit of
-- the keeper goes out again; a list from a raider, from someone outside the group, or a broken one is
-- refused; a client with prio.share off neither asks nor takes.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local LIST = "#AMISIA-LC 1 forever 2026-10-07\nC 32235 1788000000 p:Kim_Eisherz:Tank,c:WARRIOR:Furor,o Erst Tanks\nC 32837 1788000100 p:Fraktur\n#END"

BUS.setRaid({ VULO, FRAK, KIM, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        if not STUB.officer then NS.Set("ui.view", "raider") end
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true, "Vulo keeps the raid")
assert(BUS.count({ kind = "LV" }) == 0, "nothing to share, nothing announced")

-- the keeper pastes the site's list: LV into the raid, the others ask, the list arrives
C(VULO, [[local send = NS.CommSendBlob
    LC_OPTS = {}
    NS.CommSendBlob = function(art, key, tbl, chan, target, opts)
        if art == "LC" then LC_OPTS[#LC_OPTS + 1] = opts or {} end
        return send(art, key, tbl, chan, target, opts)
    end]])
assert(C(VULO, ("return NS.SetLootPrio(%q) ~= nil"):format(LIST)))
BUS.tick(20)
assert(C(VULO, "#LC_OPTS >= 1 and LC_OPTS[1].low == true"), "the list goes at the lowest priority (the raid sync first)")
assert(BUS.count({ kind = "LV", sender = VULO, chan = "RAID" }) >= 1, "the keeper announced it")
assert(BUS.count({ kind = "LV", sender = FRAK }) == 0 and BUS.count({ kind = "LV", sender = KIM }) == 0, "only the keeper announces")
assert(BUS.count({ kind = "LQ", sender = KIM, chan = "WHISPER" }) >= 1, "the raider asked")
assert(C(KIM, "NS.LootPrioOf(32235) ~= nil"), "the raider has the officers' list")
assert(C(KIM, "NS.LootPrioOf(32235).src") == "shared")
assert(C(KIM, "NS.LootPrioOf(32235).note") == "Erst Tanks")
assert(C(KIM, "NS.LootPrioRank(32235, 'Kim Eisherz')") == 1)
assert(C(FRAK, "NS.LootPrioOf(32837).prio[1].name") == FRAK, "the officer too")
assert(C(PUG, "NS.LootPrioOf(32235) == nil"), "the guest outside the guild gets nothing")
assert(C(KIM, "NS.LootPrioInfo().from") == VULO)

-- the raider sees it in the tooltip and on the roll frame
assert(C(KIM, [[local lines = {}
    GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
    local l = STUB.item(32235, "Cursed Vision of Sargeras", 4)
    GameTooltip.GetItem = function() return "x", l end
    if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
    NS.Set("bis.tooltip", false); NS.Set("drops.tooltip", false)
    STUB.showTooltip(GameTooltip)
    for _, t in ipairs(lines) do if t:find("Prio: 1. Kim Eisherz (Tank)", 1, true) then return true end end
    return false]]), "the tooltip line")
assert(C(KIM, [[STUB.rolls[7] = STUB.item(32235, "Cursed Vision of Sargeras", 4)
    GroupLootFrame1.rollID = 7; GroupLootFrame1:Show()
    return NS.LootPrioRollMarkText(GroupLootFrame1)]]) == "P1", "the own place on the roll frame")

-- nothing new: the repeat brings no second list
local lc = BUS.count({ prefix = "AmisiaD" })
BUS.tick(250)
assert(BUS.count({ kind = "LV", sender = VULO }) >= 2, "the state is repeated")
assert(BUS.count({ prefix = "AmisiaD" }) == lc, "the same state is not sent again")

-- an edit of the keeper in game goes out
assert(C(VULO, "return NS.EditLootPrio(32235, 'Fraktur, offen', 'getauscht') ~= nil"))
BUS.tick(30)
assert(C(KIM, "NS.LootPrioOf(32235).prio[1].name") == FRAK, "the edit arrived")
assert(C(KIM, "NS.LootPrioOf(32235).note") == "getauscht")
-- an officer's own edit that is newer stays his until the keeper has a newer one
assert(C(FRAK, "return NS.EditLootPrio(32837, 'Vulo Sturmwind', '') ~= nil"))
assert(C(FRAK, "NS.LootPrioOf(32837).src") == "edit")
assert(C(KIM, "NS.LootPrioOf(32837).prio[1].name") == FRAK, "a non-keeper's edit is not shared")

-- forged lists: from a raider, from a guest, broken ones
local before = C(KIM, "NS.LootPrioOf(32235).prio[1].name")
local KEY = C(VULO, "NS.RaidKey(NS.Active())")
local forged = [[return NS.CommSendBlob("LC", %q, { v = 1, l = { { 32235, 1788500000, "", "p:Pug", "" } } }, "WHISPER", %q)]]
C(KIM, forged:format(KEY, FRAK))
BUS.tick(5)
assert(C(FRAK, "NS.LootPrioOf(32235).prio[1].name") == FRAK, "a raider's list is refused")
C(PUG, forged:format(KEY, KIM))
BUS.tick(5)
assert(C(KIM, "NS.LootPrioOf(32235).prio[1].name") == before, "a guest's list is refused")
local broken = [[return NS.CommSendBlob("LC", %q, { v = 1, l = { { 32235, 1788000000, "", "p:X1", "" } } }, "WHISPER", %q)]]
local refused = C(KIM, "NS.LootPrioStats().refused")
C(FRAK, broken:format(KEY, KIM))
BUS.tick(5)
assert(C(KIM, "NS.LootPrioOf(32235).prio[1].name") == before, "a broken list is refused whole")
assert(C(KIM, "NS.LootPrioStats().refused") == refused + 1)
-- an officer outside the group: refused
BUS.setRaid({ VULO, KIM, PUG })
C(FRAK, ([[return NS.CommSendBlob("LC", %q, { v = 1, l = { { 32235, 1788500000, "", "p:Pug", "" } } }, "GUILD")]]):format(KEY))
BUS.tick(5)
assert(C(KIM, "NS.LootPrioOf(32235).prio[1].name") == before, "an officer outside the group is not listened to")
BUS.setRaid({ VULO, FRAK, KIM, PUG })
BUS.tick(5)

-- prio.share off: no asking, no taking
C(KIM, "NS.Set('prio.share', false)")
local asked = BUS.count({ kind = "LQ", sender = KIM })
assert(C(VULO, "return NS.EditLootPrio(32235, 'Kim Eisherz', '') ~= nil"))
BUS.tick(30)
assert(BUS.count({ kind = "LQ", sender = KIM }) == asked, "no question with sharing off")
assert(C(KIM, "NS.LootPrioOf(32235).prio[1].name") == before)
assert(C(FRAK, "NS.LootPrioOf(32235).prio[1].name") == KIM, "the others still follow")

-- a list too big for one blob: the newest part of it goes out
C(KIM, "NS.Set('prio.share', true)")
C(VULO, [[local lines = { "#AMISIA-LC 1 forever 2026-10-07" }
    for i = 1, 150 do lines[#lines + 1] = ("C %d %d p:Anna_Bergmann:Tank,c:WARRIOR:Furor,p:Kimtaro,c:MAGE,o Erst Tanks, dann DPS"):format(40000 + i, 1788000000 + i) end
    lines[#lines + 1] = "#END"
    return NS.SetLootPrio(table.concat(lines, "\n")) ~= nil]])
BUS.tick(60)
local got = C(KIM, "local n = 0; for id = 40001, 40150 do if NS.LootPrioOf(id) then n = n + 1 end end; return n")
assert(got >= 10 and got < 150, "a part of the big list: " .. tostring(got))
assert(C(KIM, "NS.LootPrioOf(40150) ~= nil"), "the newest item is in it")
local asks = BUS.count({ kind = "LQ", sender = KIM })
BUS.tick(250)
assert(BUS.count({ kind = "LV", sender = VULO }) >= 1 and BUS.count({ kind = "LQ", sender = KIM }) == asks,
    "the cut list is not asked for again on the next announcement")
