--[[preload
_G.GetBuildInfo = function() return "1.60.1", "71037", "Nov 20 2026", STUB.toc end
]]
-- F-229 (D-159): game build 71037 and the other layer addon's newest rules. Where every creature carries a number
-- of its own (LY.Private): the first calm creature sets the own number, no creature replaces it, no letters and no
-- list; at the move in a helper's group its answered number is taken (LY.Take "host"); the game's phase mark on the
-- helper 3 s after the join: no mark = it stands with us (left at once, its number taken, the old one still ours,
-- the helper skipped), sharding = the game refused (left at once, the hour held); no mark from the game: no move
-- 15 s after the join is "not moved". The hour's limit of ten moves (per character, through /reload and login),
-- no ask in a fight and 6 s after it, dead or on a flight path; a fight ends the search. The number through a
-- /reload, never a login. The ask's "r2" read and sent; no blind invite; the event field; the saved keys cleaned.
local SW, LY, LW, LF = NS.LayerChange, NS.Layer, NS.LayerWindow, NS.LayerForeign
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function guid(server, npc, spawn, zuid) return ("Creature-0-%d-0-%d-%d-%s"):format(server, zuid or 5250, npc, spawn) end
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
STUB.roster = {}
local LEFT, ACCEPTED = 0, 0
C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 end
_G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
_G.StaticPopup_Hide = function() end
-- the helper in the group: party1, its phase mark and zone as the test sets them
local HOST, MARK, HOSTMAP = nil, "none", 1429
local unitName = _G.UnitName
_G.UnitName = function(u) if u == "party1" and HOST then return HOST end return unitName(u) end
_G.UnitExists = function(u) return u == "party1" and HOST ~= nil end
_G.UnitPhaseReason = function(u)
    if u ~= "party1" then return nil end
    if MARK == "apart" then return 1 end
    if MARK == "other" then return 2 end
    return nil
end
local bestMap = C_Map.GetBestMapForUnit
C_Map.GetBestMapForUnit = function(u) if u == "party1" then return HOSTMAP end return bestMap(u) end
local function join(host)
    HOST = host
    STUB.party = true
    STUB.roster = { { name = STUB.player }, { name = host } }
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function part()
    HOST = nil
    STUB.party, STUB.roster = nil, {}
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function pending(uid, zuid)
    SW._reset({ pending = { name = "Hela Helfer", uid = uid, zuid = zuid, map = 1429, from = LY.Current(), at = GetTime(),
        invited = GetTime(), answered = true } })
    LEFT = 0
end

-- 1. the own number: one creature sets it, no other replaces it; no letters, no list
assert(LY.Private() == true, "build 71037: private numbers")
STUB.fire("PLAYER_ENTERING_WORLD", true, false)
STUB.tick(1)
read(4012)
assert(LY.Current() == 4012, "one calm creature sets the number")
read(5001); read(5002); read(5002); read(5002)
assert(LY.Current() == 4012, "no creature replaces it")
assert(#LY.List() == 0 and select(3, LY.Current()) == "Layer bekannt" and LY.Name(1429, 5002) == "anderer Layer")
assert(not LY.Taken() and LY.Ours(4012) and not LY.Ours(5002))
-- a zone border: nothing within 15 s, then the next creature
STUB.fire("ZONE_CHANGED_NEW_AREA")
read(6001)
assert(LY.Current() == nil, "not within 15 s of a border")
STUB.tick(15.5)
read(6002)
assert(LY.Current() == 6002)
-- the command's letter and the window's list ask for nothing here
assert(LW.Command("swap b") == "private")

-- 2. the move in the helper's group: its answered number at once, the hour counts it, left 4 s after the join
pending(7000, 33)
join("Hela Helfer")
STUB.tick(1)
STUB.fire("SHARD_TRANSFER")
assert(LY.Current() == 7000 and LY.Taken() and LY.CurrentWire() == "7000-33", "the helper's number: " .. tostring(LY.CurrentWire()))
assert(SW.State().swap.changed and SW.CapUsed() == 1, "changed and counted")
assert(SW.Event().kind == "moved" and SW.Event().used == 1)
read(8001); read(8001); read(8001)
assert(LY.Current() == 7000, "creatures never replace a taken number")
STUB.tick(3.1)
assert(LEFT == 1, "left 4 s after the join")
part()

-- 3. the game shows the helper with us (no mark) 3 s after the join: left at once, its number taken unless ours is
-- a taken one, the old one still ours, the helper skipped
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(16); read(4100)
assert(LY.Current() == 4100 and not LY.Taken())
pending(4200, 9)
MARK = "none"
join("Hela Helfer")
STUB.tick(2.9)
assert(LEFT == 0)
STUB.tick(0.2)
assert(LEFT == 1 and SW.State().swap.sameMark, "left at once")
assert(LY.Current() == 4200 and LY.Taken() and LY.Ours(4100) and LY.Ours(4200), "the helper's number, the old one kept as ours")
assert(SW.Event().kind == "same" and SW.CapUsed() == 1, "no move used (still the one of 2.)")
assert(has(LW.StatusText(SW.State()), "stand auf deinem Layer"))
part()
-- with a taken number already, a second helper with another number does not change it
pending(4300, 9)
join("Zweiter Helfer")
STUB.tick(3.1)
assert(LY.Current() == 4200, "a taken number stays")
part()

-- 4. the game refuses (sharding mark, the helper in our zone): left at once, held 15 min with fewer than ten known
pending(4400, 9)
MARK = "apart"
join("Hela Helfer")
STUB.tick(3.1)
assert(LEFT == 1 and SW.State().swap.refused, "left at once")
assert(math.abs(SW.CapLeft() - 900) < 1 and SW.CapRefused(), "held 15 minutes: " .. SW.CapLeft())
local why, kind = SW.Blocked()
assert(kind == "cap" and has(why, "noch 15:00"), tostring(why))
assert(SW.Swap() == nil, "no ask while held")
assert(SW.Event().kind == "refused" and SW.Event().tag == "15:00")
local st = SW.State()
assert(LW.SwapLabel("ask", nil, nil, st) == "Warten 15:00", tostring((LW.SwapLabel("ask", nil, nil, st))))
part()
STUB.tick(901)
assert(SW.CapLeft() == 0)
-- the helper in another zone: marked the same way, but no refusal
pending(4500, 9)
MARK, HOSTMAP = "apart", 1430
join("Hela Helfer")
STUB.tick(3.1)
assert(LEFT == 1 and SW.State().swap.elsewhere and SW.CapLeft() == 0, "another zone: no refusal")
assert(SW.Event().kind == "elsewhere")
part()
MARK, HOSTMAP = "none", 1429

-- 5. no answer from the game: no move 15 s after the join is "not moved"
_G.UnitPhaseReason = nil
pending(4600, 9)
join("Hela Helfer")
STUB.tick(14)
assert(LEFT == 0 and not SW.State().swap.failed)
STUB.tick(2)
assert(SW.State().swap.failed and LEFT == 1, "silent: not moved at 15 s")
part()

-- 6. the hour: ten moves, then held until the hour is over; kept through /reload and a login, per character
AmisiaDB.layerCap = nil
for i = 1, 10 do
    pending(9000 + i, 1)
    join("Hela Helfer")
    STUB.fire("SHARD_TRANSFER")
    STUB.tick(5)
    part()
    STUB.tick(60)
end
assert(SW.CapUsed() == 10 and SW.CapLeft() > 0, "ten moves: held " .. SW.CapLeft())
local left = SW.CapLeft()
assert(SW.Event().kind == "full")
SW._loaded()
assert(SW.CapLeft() == left, "through the load")
local mine = AmisiaDB.layerCap[STUB.player]
AmisiaDB.layerCap["Anderer Charakter"] = mine
AmisiaDB.layerCap[STUB.player] = nil
assert(SW.CapLeft() == 0, "another character's count holds nothing here")
AmisiaDB.layerCap[STUB.player] = mine
STUB.tick(left + 1)
assert(SW.CapLeft() == 0 and SW.CapUsed() == 0, "the hour over")
-- three left: counted on the button
AmisiaDB.layerCap = { [STUB.player] = { start = time(), moves = { time(), time(), time(), time(), time(), time(), time(), time() } } }
st = SW.State()
assert(LW.SwapLabel("ask", nil, nil, st) == "Layer wechseln (noch 2)", tostring((LW.SwapLabel("ask", nil, nil, st))))
AmisiaDB.layerCap = nil
-- the saved counts cleaned
local db = { layerCap = { [""] = {}, ["X|Y"] = { start = 1, moves = {} }, ["Alt"] = { start = time() - 9999, moves = { time() - 9999 } },
    ["Neu"] = { start = time(), moves = { time(), "x" }, hold = time() + 99999, junk = 1 } } }
SW.LoadedCap(db)
assert(db.layerCap["Neu"] and not db.layerCap["Alt"] and not db.layerCap[""] and not db.layerCap["X|Y"])
assert(#db.layerCap["Neu"].moves == 1 and db.layerCap["Neu"].hold == nil and db.layerCap["Neu"].junk == nil)

-- 7. a fight: no ask, the search ends; 6 s after it still none; dead and a flight path too
SW._reset()
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(16); read(4700)
_G.C_FriendList.SendWho = function() end
assert(SW.Swap() == true and SW.SwapStep() == "stop")
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
assert(SW.SwapStep() ~= "stop", "the fight ended the search")
local ok, whyF = SW.Swap()
assert(not ok and has(whyF, "im Kampf"), tostring(whyF))
assert(LW.SwapLabel("ask", nil, nil, SW.State()) == "Im Kampf")
assert(SW.PauseReason() == "im Kampf", "helping pauses in a fight by default")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(2)
assert(not SW.HostResting(), "helping back 2 s after the fight")
assert(LW.SwapLabel("ask", nil, nil, SW.State()) == "Kampf 0:04", tostring((LW.SwapLabel("ask", nil, nil, SW.State()))))
assert(SW.Event().kind == "fight")
STUB.tick(4.1)
assert(SW.Blocked() == nil)
_G.UnitIsDeadOrGhost = function(u) return u == "player" end
assert(select(2, SW.Blocked()) == "dead" and select(1, SW.AskChannel()) == nil)
_G.UnitIsDeadOrGhost = nil
_G.UnitOnTaxi = function(u) return u == "player" end
assert(select(2, SW.Blocked()) == "taxi")
_G.UnitOnTaxi = nil
STUB.tick(11)

-- 8. the number through a /reload in the same zone, never a login
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(16); read(4800)
pending(4900, 7)
join("Hela Helfer")
STUB.fire("SHARD_TRANSFER")
assert(LY.Current() == 4900 and LY.Taken())
STUB.fire("PLAYER_LOGOUT")
assert(AmisiaDB.layerOwn and AmisiaDB.layerOwn.id == 4900 and AmisiaDB.layerOwn.taken == true)
part()
LY._reset()
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
assert(LY.Current() == 4900 and LY.Taken() and AmisiaDB.layerOwn == nil, "taken up after the /reload")
STUB.fire("PLAYER_LOGOUT")
LY._reset()
STUB.targetGUID = nil
STUB.fire("PLAYER_ENTERING_WORLD", true, false)
assert(LY.Current() == nil, "not after a login")
-- in the helper's group before the move nothing is written down
STUB.targetGUID = nil
STUB.tick(3); read(5100)
pending(5200, 7)
join("Hela Helfer")
STUB.fire("PLAYER_LOGOUT")
assert(AmisiaDB.layerOwn == nil, "between the join and the move: nothing kept")
part()
assert(LY.LoadedOwn({ layerOwn = { id = 1, map = 1429, who = "X", at = time() - 500 } }) == false, "too old")

-- 9. the other layer addon's ask with "r2": read and answered; Amisia sends it; no blind invite
SW._reset(); LF._reset()
local P = LF.PREFIX
local ask = LF.ParseAsk("inv layer <LS 1429 not 7088-2 r2 48.2,42.5>")
assert(ask and ask.rules == 2 and ask.nots[1][1] == 7088 and ask.x == 48.2, "r2 read")
assert(LF.ParseAsk("inv layer <LS 1429 r2>").rules == 2 and LF.ParseAsk("inv layer <LS 1429 r2 not 1-2>") == nil)
assert(LF.AskText(1429, { nots = { "7088-2" }, x = 1, y = 2 }) == "inv layer <LS 1429 not 7088-2 r2 1.0,2.0>")
local before = #STUB.addon
STUB.fire("CHAT_MSG_ADDON", P, "inv layer <LS 1429 not 7088-2 r2 48.2,42.5>", "WHISPER", "Lisa Laufend")
local heard
for i = before + 1, #STUB.addon do if STUB.addon[i].prefix == P then heard = STUB.addon[i].text end end
assert(has(heard, "heard Lisa Laufend|5100-5250|1429|h"), tostring(heard))
-- the same asker again without a layer, the own layer unknown after the reads: no invite (a whisper)
local INVITED = {}
C_PartyInfo.InviteUnit = function(name) INVITED[#INVITED + 1] = name end
NS.Set("layer.others", true); NS.Set("layer.othersAuto", true)
STUB.tick(61)
-- the control: with the own layer known a stranger's ask is invited
STUB.fire("CHAT_MSG_ADDON", P, "inv layer <LS 1429 not 6000-2 r2>", "WHISPER", "Vera Vorher")
STUB.tick(2)
assert(INVITED[1] == "Vera Vorher", "the control: invited")
STUB.tick(61)
LY._reset()
STUB.targetGUID = nil
STUB.fire("CHAT_MSG_ADDON", P, "inv layer <LS 1429 not 6000-2>", "WHISPER", "Udo Unbekannt")
STUB.tick(11)
STUB.fire("CHAT_MSG_ADDON", P, "inv layer <LS 1429 r2>", "WHISPER", "Udo Unbekannt")
STUB.tick(3)
assert(#INVITED == 1, "no blind invite: " .. tostring(INVITED[2]))
NS.Set("layer.others", false); NS.Set("layer.othersAuto", false)

-- 10. the window: the event field in the list's place
SW._reset()
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(16); read(5300)
SW._note("same", "Hela Helfer")
LW.Show()
assert(AmisiaLayerFrame.ev:IsShown() and not AmisiaLayerFrame.seenHead:IsShown(), "the event field instead of the list")
assert(has(AmisiaLayerFrame.ev.head:GetText(), "Der Helfer stand auf deinem Layer"))
STUB.tick(61)
LW.Refresh()
assert(not AmisiaLayerFrame.ev:IsShown(), "empty once it is over")
-- the key binding presses the button
assert(type(AmisiaLayerKey) == "function" and BINDING_NAME_AMISIA_LAYER_SWAP == "Layer wechseln")
AmisiaLayerKey()
assert(SW.SwapStep() == "stop", "the key asks")

-- 11. review fixes: a read while the kept number waits for the map; an Amisia helper's number (no zoneUID) survives a
-- /reload; a chat ask ends in a fight and nothing is accepted then; the leader decides whose number is taken; a move
-- just after a verdict of refusal takes the hold back
SW._reset()
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(16); read(6100)
pending(6200)   -- an Amisia helper: no zoneUID
join("Hela Helfer")
STUB.fire("SHARD_TRANSFER")
assert(LY.Current() == 6200 and LY.CurrentWire() == "6200-5250", "the zoneUID read in the zone stands in: " .. tostring(LY.CurrentWire()))
STUB.fire("PLAYER_LOGOUT")
part()
LY._reset()
STUB.place.map = nil
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
STUB.place.map = 1429
read(6300)
assert(LY.Current() == 6200 and LY.Taken(), "taken up at the first read, no error")
-- the chat ask: a fight ends it; an invite in a fight is not accepted
SW._reset()
_G.GetChannelName = function(i) if i == 1 then return 1, "Allgemein" end return 0, nil end
_G.ChatFrame_OpenChat = function() end
assert(SW.AskChannel() == true and SW.State().chat)
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
assert(not SW.State().chat, "the fight ended the chat ask")
SW._reset({ pending = { name = "Hela Helfer", map = 1429, from = LY.Current(), at = GetTime(), answered = true } })
local acc = ACCEPTED
STUB.fire("PARTY_INVITE_REQUEST", "Hela Helfer")
assert(ACCEPTED == acc, "not accepted in a fight")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(7)
-- the leader is not the one who answered: its number is not taken
pending(6400, 3)
join("Hela Helfer")
local leader = _G.UnitIsGroupLeader
_G.UnitIsGroupLeader = function(u) return u == "party1" end
local un = _G.UnitName
_G.UnitName = function(u) if u == "party1" then return "Echte Leiterin" end return un(u) end
STUB.fire("SHARD_TRANSFER")
assert(LY.Current() ~= 6400, "another leader: the answer's number is not taken")
_G.UnitIsGroupLeader, _G.UnitName = leader, un
part()
-- the game's verdict of refusal, then the move comes after all: counted, the hold taken back
STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.tick(16); read(6500)
AmisiaDB.layerCap = nil
_G.UnitPhaseReason = function(u) if u == "party1" then return 1 end end
pending(6600, 3)
join("Hela Helfer")
STUB.tick(3.1)
assert(SW.CapLeft() > 0 and SW.State().swap.refused)
STUB.fire("SHARD_TRANSFER")
assert(SW.CapLeft() == 0 and SW.CapUsed() == 1 and SW.State().swap.changed, "the late move counts, the hold is gone")
part()
-- "Gilde fragen" in a fight: refused
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
local okG, whyG = SW.CanAsk()
assert(not okG, "no guild ask in a fight: " .. tostring(whyG))
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
print("layer private: number, helper's word, phase marks, hour, fight, reload, r2, no blind invite, event field, key")
