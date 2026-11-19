--[[clients Anna_Bergmann Udo_Fremd Kai_Lindner Lena_Kraus]]
-- The layer change with the Amisia users of the zone (F-216, D-141): nobody in a guild. "Layer wechseln" asks
-- /who for the zone (the client's who window kept shut for that answer), whispers ZQ to every name but the own;
-- every Amisia user of the zone answers ZA (Udo on another layer helps, Kai on the same layer, Lena with helping
-- off); the window counts reached / heard / other layer; the pick asks Udo (YI to a stranger), Udo invites without
-- a question (the default), sets the party to free for all; Anna leaves 5 s after the change; the hosts are kept
-- for a week. Then: no helper: "Weiter fragen: <class>" asks the next class; a host that does not move the
-- player: Amisia leaves after 15 s; "Helfen" off takes the guests out; bad and foreign ZQ/ZA; the offline line;
-- the commands; the saved list cleaned on load.
local A, U, K, Lk = "Anna Bergmann", "Udo Fremd", "Kai Lindner", "Lena Kraus"
local function guid(zone, npc, spawn) return ("Creature-0-%d-0-5250-%d-%s"):format(zone, npc, spawn) end
local function world(name, zone)
    C(name, ([[STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
        STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
        STUB.place.map = 1429
        _G.GetRealZoneText = function() return "Wald von Elwynn" end
        NS.InGuild = function() return false end
        -- Amisia's own zone questions alone (F-216); the other layer addon's way: tests/test_layer_foreign.lua
        NS.Set("layer.foreign", false)
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        INVITED, ACCEPTED, LEFT, KICKED, LOOT, WHO, WHORESULT, SHOWN = {}, 0, 0, {}, {}, {}, {}, false
        C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end
        C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 end
        C_PartyInfo.UninviteUnit = function(n) KICKED[#KICKED + 1] = n end
        C_PartyInfo.SetLootMethod = function(m) LOOT[#LOOT + 1] = m return true end
        _G.UnitIsGroupLeader = function(u) return STUB.leader == true end
        _G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
        _G.StaticPopup_Hide = function() end
        WHOF = {}
        C_FriendList.SendWho = function(f, origin, filter) WHO[#WHO + 1] = f; WHOF[#WHO] = filter end
        C_FriendList.SetWhoToUi = function(v) WHOUI = v end
        C_FriendList.GetNumWhoResults = function() return #WHORESULT, #WHORESULT end
        C_FriendList.GetWhoInfo = function(i)
            local n = WHORESULT[i]
            return n and { fullName = n, area = "Wald von Elwynn", classStr = "Krieger", level = 30 } or nil
        end
        _G.FriendsFrame = { ev = { WHO_LIST_UPDATE = true }, IsShown = function() return SHOWN end,
            IsEventRegistered = function(self, e) return self.ev[e] == true end,
            UnregisterEvent = function(self, e) self.ev[e] = nil end, RegisterEvent = function(self, e) self.ev[e] = true end }]]):format(
        guid(zone, 1, "0A1"), guid(zone, 2, "0A2")))
end
world(A, 4012)
world(U, 3999)
world(K, 4012)
world(Lk, 3998)
-- D-145 since 2026-11-19: strangers are helped only with layer.others, without a question only with layer.othersAuto
for _, n in ipairs({ A, U, K, Lk }) do C(n, "NS.Set('layer.others', true); NS.Set('layer.othersAuto', true)") end
BUS.tick(15)
C(Lk, "NS.LayerChange.SetHosting(false)")
local function step(n) return C(n, "NS.LayerChange.SwapStep()") end
local everyone = ([[WHORESULT = { %q, %q, %q, %q, "Pia Offline" }]]):format(A, U, K, Lk)

-- 1. without a guild the zone is asked: one /who, the who window shut for that answer
assert(not C(A, "NS.InGuild()") and step(A) == "ask", "the zone can be asked without a guild")
assert(C(A, "return NS.LayerChange.Swap()") == true)
assert(C(A, "WHO[1]") == 'z-"Wald von Elwynn"' and C(A, "WHOUI") == true, tostring(C(A, "WHO[1]")))
-- F-221: the map filter of the zone (SendWho's third argument), no class at first
assert(C(A, "WHOF[1].uiMapIDs[1]") == 1429 and C(A, "#WHOF[1].classIDs") == 0 and C(A, "#WHOF[1].raceIDs") == 0)
assert(C(A, "FriendsFrame.ev.WHO_LIST_UPDATE") == nil, "the client's who window does not hear this answer")
assert(step(A) == "stop")
C(A, everyone .. "; STUB.fire('WHO_LIST_UPDATE')")
assert(C(A, "FriendsFrame.ev.WHO_LIST_UPDATE") == nil, "the answer itself still goes past the window")
BUS.tick(1)
assert(C(A, "FriendsFrame.ev.WHO_LIST_UPDATE") == true and C(A, "WHOUI") == false, "the who window back, chat output back")
assert(BUS.count({ kind = "ZQ", sender = A }) == 4, "a quiet question to everyone but the own name")
assert(BUS.count({ kind = "ZQ", sender = A, target = A }) == 0)
BUS.tick(3)
assert(BUS.count({ kind = "ZA", sender = U, target = A }) == 1 and BUS.count({ kind = "ZA", sender = K, target = A }) == 1
    and BUS.count({ kind = "ZA", sender = Lk, target = A }) == 1, "every Amisia user of the zone answers")
local z = C(A, "NS.LayerChange.State().zone")
assert(z.reached == 4 and z.heardN == 3 and z.hosts == 1 and z.other == 1, ("%d %d %d %d"):format(z.reached, z.heardN, z.hosts, z.other))
C(A, "NS.LayerWindow.Show()")
assert(C(A, "AmisiaLayerFrame.zone:GetText()") == "Erreicht: 4 · gehört: 3 · auf anderem Layer: 1", C(A, "AmisiaLayerFrame.zone:GetText()"))
-- the pick: Udo, a stranger, asked for the invite; he invites without a question (the default)
BUS.tick(4)
assert(BUS.count({ kind = "YI", sender = A, target = U }) == 1, "the request for the invite goes to the stranger")
assert(C(U, "INVITED[1]") == A and not C(U, "AmisiaConfirmFrame ~= nil and AmisiaConfirmFrame:IsShown()"), "invited without a question")
assert(C(U, "NS.LayerChange.Helped().invited") == 1)
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd")]])
assert(C(A, "ACCEPTED") == 1)
BUS.setRaid({ U, A })
C(U, "STUB.leader = true; STUB.lootMethod = 3")
for _, n in ipairs({ A, U }) do C(n, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')") end
assert(C(U, "LOOT[1]") == 0 and C(U, "#LOOT") == 1, "the swap party set to free for all (Enum.LootMethod.Freeforall), once")
for _, n in ipairs({ A, U }) do C(n, "STUB.fire('GROUP_ROSTER_UPDATE')") end
assert(C(U, "#LOOT") == 1, "not twice")
-- F-221: a player Amisia did not invite joins: the loot as before, once
BUS.setRaid({ U, A, K })
C(U, "STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(U, "LOOT[2]") == 3 and C(U, "#LOOT") == 2, "the loot back: " .. tostring(C(U, "LOOT[2]")))
BUS.setRaid({ U, A })
C(U, "STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(U, "#LOOT") == 2)
-- the change (three creatures of the new layer, F-221), then leaving after 4 s by itself (Udo answered the ask)
for i = 1, 3 do C(A, [[STUB.targetGUID = "]] .. guid(3999, 6 + i, "0C" .. i) .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]]) end
assert(C(A, "NS.LayerChange.State().swap.changed ~= nil"))
assert(C(A, "NS.LayerChange.LockLeft()") == 240, "Helfen held on for four minutes")
BUS.tick(3)
assert(C(A, "LEFT") == 0)
BUS.tick(2)
assert(C(A, "LEFT") == 1, "left 4 s after the change")
for _, n in ipairs({ A, U }) do C(n, "STUB.party = nil; STUB.roster = {}; STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.setRaid({})
C(U, "STUB.leader = false")
local hosts = C(A, "AmisiaDB.layerHosts")
assert(hosts["udo fremd"] and hosts["kai lindner"] and hosts["lena kraus"] and not hosts["pia offline"], "who answered is kept")

-- 2. nobody helps: no answer from another layer, the next search asks the next class (F-221: one /who per search,
-- the map and a class; who did not answer within 6 h is not asked again, kept through /reload)
C(A, "NS.LayerChange._reset(); WHO = {}")
C(A, [[STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.targetGUID = "]] .. guid(4012, 8, "0D1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
C(A, [[STUB.targetGUID = "]] .. guid(4012, 9, "0D2") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
C(U, "NS.LayerChange.SetHosting(false)")
-- (ZQ's receive gap is 30 s)
BUS.tick(31)
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, everyone .. "; STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(4)
BUS.tick(8)
local first = C(A, "NS.LayerChange.ZoneNext()")
assert(step(A) == "more" and type(first) == "string" and first ~= "Wald von Elwynn", "no answer: the next class: " .. tostring(step(A)) .. " " .. tostring(first))
local lbl = C(A, "NS.LayerWindow.SwapLabel(NS.LayerChange.SwapStep(), NS.LayerChange.ZoneNext())")
assert(lbl == "Weiter fragen: " .. first, tostring(lbl))
local stx = C(A, "NS.LayerWindow.StatusText(NS.LayerChange.State())")
assert(stx:find("Klick noch einmal, um mehr Spieler zu fragen", 1, true), stx)
assert(C(A, "AmisiaDB.layerAsked['pia offline']") ~= nil, "asked without an answer: kept")
C(A, "NS.LayerChange._loaded()")
assert(C(A, "AmisiaDB.layerAsked['pia offline']") ~= nil, "through /reload")
local toPia = BUS.count({ kind = "ZQ", sender = A, target = "Pia Offline" })
assert(C(A, "return NS.LayerChange.Swap()") == true)
assert(C(A, "WHO[2]") == 'z-"Wald von Elwynn"' and C(A, "WHOF[2].classIDs[1]") == 1, tostring(C(A, "WHO[2]")))
C(A, everyone .. "; STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
assert(BUS.count({ kind = "ZQ", sender = A, target = "Pia Offline" }) == toPia, "not asked again within 6 h")
assert(BUS.count({ kind = "ZQ", sender = A, target = K }) == 3, "who answered is asked again")
assert(C(A, "return NS.LayerChange.Stop()") == true and C(A, "NS.LayerChange.State().zone") == nil, "Stopp ends the search")
-- the map filter refused: the zone by name with the client's zone word and level bands
C(A, [[NS.LayerChange._reset(); WHO = {}; _G.WHO_TAG_ZONE = "zone-"
    C_FriendList.SendWho = function(f, origin, filter) if filter then error("no map") end WHO[#WHO + 1] = f end]])
BUS.tick(11)
assert(C(A, "return NS.LayerChange.Swap()") == true and C(A, "WHO[1]") == 'zone-"Wald von Elwynn"', tostring(C(A, "WHO[1]")))
C(A, "NS.LayerChange.Stop()")
assert(C(A, "NS.LayerChange.ZoneNext()") == "Stufe 1-10", tostring(C(A, "NS.LayerChange.ZoneNext()")))
BUS.tick(11)
assert(C(A, "return NS.LayerChange.Swap()") == true and C(A, "WHO[2]") == 'zone-"Wald von Elwynn" 1-10', tostring(C(A, "WHO[2]")))
C(A, [[NS.LayerChange.Stop(); NS.LayerChange._reset(); _G.WHO_TAG_ZONE = nil
    C_FriendList.SendWho = function(f, origin, filter) WHO[#WHO + 1] = f; WHOF[#WHO] = filter end]])
C(U, "NS.LayerChange.SetHosting(true)")

-- 3. a host that does not move the player: after 15 s with the old layer Amisia leaves
C(A, "NS.LayerChange._reset({ pending = { name = 'Udo Fremd', uid = 3999, map = 1429, from = 4012, at = GetTime(), invited = GetTime() } })")
BUS.setRaid({ U, A })
C(A, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(A, "NS.LayerChange.State().swap") ~= nil)
C(A, "LEFT = 0")
BUS.tick(10)
C(A, [[STUB.targetGUID = "]] .. guid(4012, 11, "1B1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "LEFT") == 0, "not before 15 s")
BUS.tick(7)
C(A, [[STUB.targetGUID = "]] .. guid(4012, 12, "1B2") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
BUS.tick(6)
assert(C(A, "LEFT") == 1, "left: not moved")
assert(C(A, [[for i = #STUB.messages, math.max(1, #STUB.messages - 3), -1 do
    if STUB.messages[i]:find("nicht geklappt", 1, true) then return true end end return false]]), "and says why")
C(A, "STUB.party = nil; STUB.roster = {}; STUB.fire('GROUP_ROSTER_UPDATE')")
BUS.setRaid({})

-- 4. "Helfen" off takes the guests out (the leader of a party Amisia filled)
C(U, "NS.LayerChange._reset(); INVITED = {}")
C(U, "NS.LayerChange.Invite('Anna Bergmann')")
BUS.setRaid({ U, A })
C(U, "STUB.leader = true; STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(U, "NS.LayerChange.CanInvite()") == true, "a party of guests: may invite more")
C(U, "NS.LayerChange.SetHosting(false)")
assert(C(U, "KICKED[1]") == A, "the guest taken out")
-- a party with a player Amisia did not invite: no invites
BUS.setRaid({ U, A, K })
C(U, "STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(U, "NS.LayerChange.CanInvite()") == false, "not the leader of an own party: Kai came another way")
C(U, "STUB.leader = false; STUB.party = nil; STUB.roster = {}; STUB.fire('GROUP_ROSTER_UPDATE')")
BUS.setRaid({})
C(U, "NS.LayerChange._reset()")

-- 5. foreign and bad questions: another zone, a broken field, the flood limit
local za = BUS.count({ kind = "ZA", sender = U })
C(U, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZQ\tbeef\t1430\t4012", "WHISPER", "Fremder Eins")]])
C(U, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZQ\tbeef\t1429\tzz", "WHISPER", "Fremder Zwei")]])
C(U, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZA\tbeef\t1429\t4012\t7", "WHISPER", "Fremder Drei")]])
BUS.tick(2)
assert(BUS.count({ kind = "ZA", sender = U }) == za, "another zone and a broken field get nothing")
C(U, [[for i = 1, 25 do STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZQ\tbeef\t1429\t4012", "WHISPER", "Gast " .. string.char(64 + i)) end]])
BUS.tick(3)
local answered = 0
for _, m in ipairs(BUS.sent) do if m.kind == "ZQ" or (m.kind == "ZA" and m.sender == U) then answered = answered + (m.kind == "ZA" and 1 or 0) end end
assert(answered - za <= 20, "20 quiet questions a minute at most: " .. (answered - za))
-- a YI from a stranger nobody answered is dropped
local inv = C(U, "#INVITED")
C(U, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1YI\tbeef\t1429\t3999", "WHISPER", "Fremder Vier")]])
BUS.tick(1)
assert(C(U, "#INVITED") == inv, "nobody invited")

-- 6. the server's line for an offline name Amisia just whispered stays out of the chat
C(A, [[_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "Kein Spieler namens '%s' ist zurzeit online."]])
C(A, "NS.LayerChange._reset(); WHO = {}")
BUS.tick(11)

C(A, [[STUB.targetGUID = "]] .. guid(4012, 13, "1C1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, everyone .. "; STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
assert(C(A, [[NS.CommOfflineLine("Kein Spieler namens 'Pia Offline' ist zurzeit online.")]]) == true)
assert(C(A, [[NS.CommOfflineLine("Kein Spieler namens 'Otto Anders' ist zurzeit online.")]]) == false)

-- 7. the commands
C(A, "NS.LayerChange._reset()")
assert(C(A, "NS.LayerWindow.Command('stopp')") == "stop")
assert(C(A, "NS.LayerWindow.Command('helfen')") == "host" and C(A, "NS.LayerChange.Hosting()") == false)
assert(C(A, "NS.LayerWindow.Command('helfen')") == "host" and C(A, "NS.LayerChange.Hosting()") == true)
assert(C(A, "NS.LayerWindow.Command('swap z')") == "unknown")
assert(C(A, "NS.LayerWindow.Command('kick')") == "kick")
assert(C(A, "NS.LayerWindow.Command('quatsch')") == "help")
BUS.tick(11)
assert(C(A, "NS.LayerWindow.Command('swap neu')") == "swap-new" and C(A, "NS.LayerChange.State().auto.recent") ~= nil)

-- 8. the saved list cleaned on load: old, bad and too many go
C(A, [[local db = { layerHosts = { ["alt"] = time() - 8 * 86400, ["neu"] = time(), [""] = time(), ["x|y"] = time(), ["zahl"] = "x" } }
    NS.LayerChange.LoadedHosts(db); LOADED = db.layerHosts]])
local loaded = C(A, "LOADED")
assert(loaded["neu"] and not loaded["alt"] and not loaded[""] and not loaded["x|y"] and not loaded["zahl"])
C(A, [[local db = { layerHosts = "kaputt" }; NS.LayerChange.LoadedHosts(db); LOADED = db.layerHosts]])
assert(C(A, "LOADED") == nil)
-- 9. review fixes: the who window hears again whatever happens to the search; a late answer still picks; the
-- Friends window open at the first click: the next click asks the zone
C(A, "NS.LayerChange._reset(); WHO = {}")
BUS.tick(11)
C(A, [[STUB.targetGUID = "]] .. guid(4012, 14, "1E1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "return NS.LayerChange.Swap()") == true and C(A, "FriendsFrame.ev.WHO_LIST_UPDATE") == nil)
assert(C(A, "return NS.LayerChange.Stop()") == true)
BUS.tick(6)
assert(C(A, "FriendsFrame.ev.WHO_LIST_UPDATE") == true and C(A, "WHOUI") == false, "stopped while waiting: the window hears again")
-- F-221: the Friends window open: the /who goes, the open window keeps its event (it shows the answer)
C(A, "NS.LayerChange._reset(); WHO = {}; SHOWN = true")
BUS.tick(11)
C(A, [[STUB.targetGUID = "]] .. guid(4012, 15, "1E2") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "return NS.LayerChange.Swap()") == true and C(A, "#WHO") == 1, "the Friends window open: the /who goes")
assert(C(A, "FriendsFrame.ev.WHO_LIST_UPDATE") == true, "an open window is not muted")
C(A, "SHOWN = false")
-- a helping answer after "none" still picks
C(U, "NS.LayerChange._reset(); INVITED = {}")
C(U, [[STUB.targetGUID = "]] .. guid(3999, 16, "1F1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
C(A, "WHORESULT = {}; STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(12)
assert(C(A, "NS.LayerChange.State().auto.none") == true)
C(A, [[local r = NS.LayerChange.State().req
    NS.LayerChange._zoneSent("Udo Fremd")
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZA\t" .. r.id .. "\t1429\t3999\t1", "WHISPER", "Udo Fremd")]])
BUS.tick(4)
assert(BUS.count({ kind = "YI", sender = A, target = U }) == 2, "the late answer is asked for the invite")
-- D-145 since 2026-11-19: without layer.others a stranger's quiet question gets "does not help"; a member is helped
C(U, "NS.Set('layer.others', false); NS.LayerChange._reset(); INVITED = {}")
C(U, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZQ\tabcd\t1429\t4012", "WHISPER", "Zed Fremd")]])
BUS.tick(3)
local function za(to, helps)
    return BUS.count(function(m) return m.kind == "ZA" and m.sender == U and m.target == to and m.text:sub(-2) == "\t" .. helps end)
end
assert(za("Zed Fremd", 0) == 1 and za("Zed Fremd", 1) == 0, "a stranger is not helped without layer.others")
C(U, "NS.Set('layer.others', true)")
C(U, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1ZQ\tabce\t1429\t4012", "WHISPER", "Ute Fremd")]])
BUS.tick(3)
assert(za("Ute Fremd", 1) == 1, "with layer.others the stranger is helped")
print("layer zone ok")
