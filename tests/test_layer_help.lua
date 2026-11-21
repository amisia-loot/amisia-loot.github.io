-- F-221 (D-146), F-229 (D-159): Amisia behaves as the other layer addon does. Helfen: off is off (no lock, no "on
-- while the own ask runs"; an old forced "on" goes off at load); off stays through /reload, a real login turns it on; the pause on the button; open
-- invites and a late accept. The layer: rescans after entering the world and for an ask. A swap: SHARD_TRANSFER
-- alone is no success, a restart that kept the layer is "not moved", three old creatures after five seconds are
-- "not moved" (leaving at 15 s), the real leader is the host, a verdict after the group ended, leaving only from
-- a helper who answered; warnings on invites. The guild's tagged line; the commands; the saved lists.
local SW, LY, LW, LF = NS.LayerChange, NS.Layer, NS.LayerWindow, NS.LayerForeign
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function guid(server, npc, spawn) return ("Creature-0-%d-0-5250-%d-%s"):format(server, npc, spawn) end
local n = 0
local function read(server)
    n = n + 1
    STUB.targetGUID = guid(server, 100 + n, ("%03X"):format(n))
    STUB.fire("PLAYER_TARGET_CHANGED")
end

STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.place.map = 1429
_G.GetRealZoneText = function() return "Wald von Elwynn" end
STUB.guild = { { name = "Vuloo", rank = 2 }, { name = "Anna Bergmann", rank = 3, zone = "Wald von Elwynn" } }
STUB.roster = {}
STUB.fire("PLAYER_ENTERING_WORLD", true, false); STUB.tick(15)
local INVITED, ACCEPTED, LEFT, KICKED, OPENED = {}, 0, 0, {}, {}
C_PartyInfo.InviteUnit = function(name) INVITED[#INVITED + 1] = name end
C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 end
C_PartyInfo.UninviteUnit = function(name) KICKED[#KICKED + 1] = name end
_G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
_G.StaticPopup_Hide = function() end
_G.ChatFrame_OpenChat = function(text) OPENED[#OPENED + 1] = text end
_G.GetChannelName = function(i) if i == 1 then return 1, "Allgemein" end return 0, nil end
read(4012); read(4012)
assert(LY.Current() == 4012)
local function join(host)
    STUB.party = true
    STUB.roster = { { name = "Vuloo" }, { name = host } }
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function part()
    STUB.party, STUB.roster = nil, {}
    STUB.fire("GROUP_ROSTER_UPDATE")
end

-- 1. F-229: Helfen off stays off: an own ask does not turn it on, "off" is never refused
assert(SW.Hosting() and select(2, SW.SetHosting(false)) == nil and not SW.Hosting())
assert(AmisiaDB.layerHelp.off == true, "off is saved")
assert(SW.AskChannel() == true and not SW.Hosting(), "the own ask leaves Helfen off")
assert(SW.Stop() == true)
SW.SetHosting(true)
assert(SW.AskChannel() == true and select(1, SW.SetHosting(false)) == false and not SW.Hosting(), "off during the own ask")
SW.Stop()

-- 2. a swap that worked holds nothing on; left 4 s after the join (the helper answered the ask)
SW._reset({ pending = { name = "Anna Bergmann", uid = 3999, map = 1429, from = 4012, at = GetTime(), invited = GetTime(), answered = true } })
AmisiaDB.layerHelp = { off = true }
SW._loaded()
assert(not SW.Hosting())
join("Anna Bergmann")
assert(SW.State().swap and SW.SwapStep() == "leave")
read(3999); read(3999); read(3999)
assert(SW.State().swap.changed and not SW.Hosting(), "no lock: Helfen stays off")
LW.Show()
assert(AmisiaLayerFrame.host:GetText() == "Helfen: AUS", AmisiaLayerFrame.host:GetText())
STUB.tick(5)
assert(LEFT == 1, "left by itself")
part()
assert(has(STUB.messages[#STUB.messages], "du bleibst auf deinem neuen Layer"))
LW.Command("an")
assert(SW.Hosting() and AmisiaDB.layerHelp.off == nil)

-- 3. an "on" Amisia had forced before F-229 goes off at load (as it said it would); an old lock is dropped
AmisiaDB.layerHelp = { forced = "Vuloo", lock = { untilAt = time() + 100, who = "Vuloo" } }
SW._loaded()
assert(not SW.Hosting() and AmisiaDB.layerHelp.off == true and AmisiaDB.layerHelp.lock == nil and AmisiaDB.layerHelp.forced == nil)
AmisiaDB.layerHelp = { forced = "Anderer Charakter" }
SW._loaded()
assert(SW.Hosting() and AmisiaDB.layerHelp.forced == nil, "another character's: left as it was")

-- 4. off stays through /reload; only a real login turns it on
SW.SetHosting(false)
SW._loaded()
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
assert(not SW.Hosting(), "a /reload keeps it off")
STUB.fire("PLAYER_ENTERING_WORLD", true, false)
assert(SW.Hosting() and AmisiaDB.layerHelp.off == nil, "a login turns it on")
-- the saved switch is cleaned on load
local db = { layerHelp = { off = "ja", lock = { untilAt = time() + 9999, who = "X" }, forced = 7, junk = 1 } }
SW.LoadedHelp(db)
assert(db.layerHelp.off == nil and db.layerHelp.lock == nil and db.layerHelp.forced == nil and db.layerHelp.junk == nil)
db = { layerHelp = "kaputt" }
SW.LoadedHelp(db)
assert(db.layerHelp == nil)

-- 5. the button's pause and the reasons
SW._reset()
NS.Set("layer.combatPause", true)
_G.InCombatLockdown = function() return true end
LW.Refresh()
assert(AmisiaLayerFrame.host:GetText() == "|cff9d9d9dHelfen: PAUSIERT|r" or has(AmisiaLayerFrame.host:GetText(), "Helfen: PAUSIERT"), AmisiaLayerFrame.host:GetText())
assert(AmisiaLayerFrame.hostInfo:GetText() == "Helfen pausiert: im Kampf.", AmisiaLayerFrame.hostInfo:GetText())
assert(SW.PauseReason() == "im Kampf")
_G.InCombatLockdown = function() return false end
NS.Set("layer.combatPause", false)
_G.GetLFGMode = function(c) if c == 1 then return "queued" end end
_G.NUM_LE_LFG_CATEGORYS = 2
assert(SW.PauseReason() == "in der Gruppensuche oder Dungeonsuche" and not SW.CanHelp(), "the dungeon finder's queue pauses")
_G.GetLFGMode = nil

-- 6. a late accept after Helfen off is taken out again
SW._reset()
assert(SW.Invite("Spaet Kommer") == true)
SW.SetHosting(false)
STUB.leader = true
join("Spaet Kommer")
assert(KICKED[#KICKED] == "Spaet Kommer" and has(STUB.messages[#STUB.messages], "wieder aus der Gruppe"), "removed")
part()
SW.SetHosting(true)

-- 7. judging a swap: the move without the helper's word is no success, but the group is left 4 s after the join
-- (F-229); a restart that kept the layer is "not moved"
SW._reset({ pending = { name = "Anna Bergmann", map = 1429, from = 4012, at = GetTime(), invited = GetTime(), answered = true } })
LEFT = 0
join("Anna Bergmann")
STUB.fire("SHARD_TRANSFER")
assert(not SW.State().swap.changed and SW.State().swap.moved, "the move alone is no success")
STUB.tick(4.1)
assert(LEFT == 1, "left 4 s after the join, the layer read or not")
STUB.tick(7)
read(4012); read(4012)
assert(SW.State().swap.failed and SW.SwapStep() == "leaveAsk", "the restart kept the layer: not moved")
STUB.tick(5)
assert(LEFT == 1 and has(STUB.messages[#STUB.messages], "nicht geklappt"), "said, not left twice")
LW.Refresh()
assert(AmisiaLayerFrame.swap:GetText() == "Verlassen und neu fragen")
part()
-- that host: a warning on its next invite (10 minutes), not taken by itself
assert(SW.AskChannel() == true)
local acc = ACCEPTED
STUB.fire("PARTY_INVITE_REQUEST", "Anna Bergmann")
assert(ACCEPTED == acc and has(SW.Warning(), "nicht bewegt"), "the warning: " .. tostring(SW.Warning()))
SW.Stop()

-- 8. three old creatures after five seconds: not moved; the real leader is the host; a chat ask is not left by itself
SW._reset({ pending = { name = "Erster Einlader", map = 1429, from = 4012, at = GetTime(), invited = GetTime(), chat = true } })
STUB.leader = false
_G.UnitIsGroupLeader = function(u) return u == "party1" end
local unitName = _G.UnitName
_G.UnitName = function(u) if u == "party1" then return "Echter Leiter" end return unitName(u) end
LEFT = 0
STUB.targetGUID = nil
join("Erster Einlader")
STUB.roster[3] = { name = "Echter Leiter" }
read(4012)
STUB.tick(5.5)
assert(SW.State().swap.host == "Echter Leiter", "the leader after five seconds: " .. tostring(SW.State().swap.host))
read(4012)
assert(not SW.State().swap.failed, "two old creatures: not yet")
read(4012)
assert(SW.State().swap.failed, "three old creatures after five seconds: not moved " .. tostring(SW.State().swap.freshN) .. " " .. tostring(SW.State().swap.from) .. " " .. tostring(LY.Current()))
STUB.tick(10)
assert(LEFT == 1, "left at 15 s")
_G.UnitName = unitName
_G.UnitIsGroupLeader = function(u) return STUB.leader == true and u == "player" end
part()
-- the chat ask: changed, but no leaving by itself (the inviter did not answer an ask of Amisia's)
SW._reset({ pending = { name = "Anna Bergmann", map = 1429, from = 4012, at = GetTime(), invited = GetTime(), chat = true } })
LEFT = 0
join("Anna Bergmann")
read(3999); read(3999); read(3999)
assert(SW.State().swap.changed)
STUB.tick(10)
assert(LEFT == 0, "no leaving by itself after a chat ask")
-- the group ends before the verdict: a new layer read within 30 s still counts
part()
STUB.fire("ZONE_CHANGED_NEW_AREA"); read(4012); read(4012)
SW._reset({ pending = { name = "Anna Bergmann", uid = 7000, map = 1429, from = 4012, at = GetTime(), invited = GetTime(), answered = true } })
join("Anna Bergmann")
part()
read(7000); read(7000); read(7000)
assert(has(STUB.messages[#STUB.messages], "Gewechselt"), "the verdict after the group ended")

-- 9. rescans: after entering the world (2, 5, 12 s) the plates are read; an ask with the own layer unknown reads them
LY._reset(); SW._reset()
STUB.unitGUIDs.nameplate1 = guid(5000, 1, "AA1")
STUB.unitGUIDs.nameplate2 = guid(5000, 2, "AA2")
STUB.fire("PLAYER_ENTERING_WORLD")
assert(LY.Current() == nil)
STUB.tick(2.1)
assert(LY.Current() == 5000, "the rescan two seconds after entering the world")
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(0.5)
local P = LF.PREFIX
STUB.fire("CHAT_MSG_ADDON", P, "inv layer <LS 1429 not 4012-5250>", "WHISPER", "Fremde Frau")
local heard
for _, m in ipairs(STUB.addon) do if m.prefix == P and m.target == "Fremde Frau" then heard = m.text end end
assert(heard == "heard Fremde Frau|5000-5250|1429|h", "the ask read the units first: " .. tostring(heard))
STUB.unitGUIDs.nameplate1, STUB.unitGUIDs.nameplate2 = nil, nil

-- 10. the guild's tagged line: "Im Gildenchat fragen" writes it; a member's line is answered over GUILD
SW._reset()
LF._reset()
STUB.tick(11)
assert(SW.AskChat() == true and OPENED[#OPENED] == "/g inv layer <LS 1429 not 5000-5250 r2>", tostring(OPENED[#OPENED]))
SW.Stop()
SW._reset()
INVITED = {}
local before = #STUB.addon
STUB.fire("CHAT_MSG_GUILD", "inv layer <LS 1429 not 4012-5250 40.0,40.0>", "Anna Bergmann")
STUB.tick(1)
local guildHeard
for i = before + 1, #STUB.addon do
    local m = STUB.addon[i]
    if m.prefix == P and m.chan == "GUILD" then guildHeard = m.text end
end
assert(guildHeard == "heard Anna Bergmann|5000-5250|1429|h", tostring(guildHeard))
assert(INVITED[#INVITED] == "Anna Bergmann", "the member invited")
-- a stranger's line, a broken line: nothing
before = #STUB.addon
STUB.fire("CHAT_MSG_GUILD", "inv layer <LS 1429 not 4012-5250>", "Udo Fremd")
STUB.fire("CHAT_MSG_GUILD", "inv layer <LS 1429 foo>", "Anna Bergmann")
STUB.tick(11)
assert(#STUB.addon == before, "a stranger and a broken line get nothing")

-- 11. the saved lists: layerAsked cleaned on load; layerHosts at most 300, old numbers turned into entries
local adb = { layerAsked = { ["alt"] = time() - 7 * 3600, ["neu"] = time(), [""] = time(), ["x|y"] = time(), ["zahl"] = "x" } }
SW.LoadedAsked(adb)
assert(adb.layerAsked["neu"] and not adb.layerAsked["alt"] and not adb.layerAsked[""] and not adb.layerAsked["x|y"] and not adb.layerAsked["zahl"])
local hdb = { layerHosts = { ["alt"] = time(), ["neu"] = { t = -time(), h = 1 } } }
for i = 1, 400 do hdb.layerHosts["name" .. i] = { t = time() } end
SW.LoadedHosts(hdb)
local count = 0
for _ in pairs(hdb.layerHosts) do count = count + 1 end
assert(count == 300 and (not hdb.layerHosts["alt"] or hdb.layerHosts["alt"].t == time()), "300 at most: " .. count)
print("layer help: lock, reload, login, pause, late accept, judging, leader, after group, rescans, guild line, lists")
