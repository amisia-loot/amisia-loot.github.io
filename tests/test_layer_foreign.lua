--[[clients Anna_Bergmann Udo_Fremd Kai_Lindner]]
-- The other layer addon (F-220, D-145): its users are played by lines fired into a client, its prefix comes from
-- the addon (NS.LayerForeign.PREFIX), never written here. Anna asks the zone: ZQ only to Kai (a known Amisia
-- user), the plain ask to everyone else, one whisper per name; Udo (Amisia, another layer) answers it the other
-- addon's way and invites by himself; the answers (heard, same) count in the window; a helper without a layer gets
-- the ask without one; only an answerer's invite is accepted; SHARD_TRANSFER is the change, Amisia leaves. Udo as a
-- host: heard/same, the invite and its limits, bad lines, flood, the other addon loaded, helping off, skip near,
-- the world restart. The layer is the GUID's server part; guild last; the self-test line; the offline line.
local A, U, K = "Anna Bergmann", "Udo Fremd", "Kai Lindner"
local P = C(A, "NS.LayerForeign.PREFIX")
assert(type(P) == "string" and P ~= "" and P ~= "Amisia")
local function guid(server, npc, spawn, zuid) return ("Creature-0-%d-0-%d-%d-%s"):format(server, zuid or 5250, npc, spawn) end
local function world(name, server)
    C(name, ([[STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
        STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3, world = { 0, 0, 0, 1000, 1000 } }
        STUB.place.map = 1429
        STUB.map.pos = { x = 0.482, y = 0.425 }
        _G.GetRealZoneText = function() return "Wald von Elwynn" end
        NS.InGuild = function() return false end
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        INVITED, ACCEPTED, LEFT, WHO, WHORESULT = {}, 0, 0, {}, {}
        C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end
        C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 end
        C_PartyInfo.SetLootMethod = function() return true end
        _G.UnitIsGroupLeader = function() return STUB.leader == true end
        _G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
        _G.StaticPopup_Hide = function() end
        C_FriendList.SendWho = function(f) WHO[#WHO + 1] = f end
        C_FriendList.SetWhoToUi = function() end
        C_FriendList.GetNumWhoResults = function() return #WHORESULT, #WHORESULT end
        C_FriendList.GetWhoInfo = function(i)
            local n = WHORESULT[i]
            return n and { fullName = n, area = "Wald von Elwynn", classStr = "Krieger", level = 30 } or nil
        end]]):format(guid(server, 1, "0A1"), guid(server, 2, "0A2")))
end
world(A, 4012)
world(U, 3999)
world(K, 4012)
BUS.tick(15)
local function sentTo(sender, target)
    local out = {}
    for _, m in ipairs(BUS.sent) do
        if m.prefix == P and m.sender == sender and m.target == target then out[#out + 1] = m.text end
    end
    return out
end
local function fire(name, from, text)
    C(name, ("STUB.fire('CHAT_MSG_ADDON', %q, %q, 'WHISPER', %q)"):format(P, text, from))
end

-- 1. the defaults
assert(C(A, "NS.Get('layer.foreign') == true and NS.Get('layer.guildLast') == true and NS.Get('layer.skipNear') == false"))
assert(C(A, "NS.Get('layer.skipNearYards') == 150 and NS.Get('layer.barOneLine') == false"))
assert(C(A, "NS.LayerForeign.Active()") == true, "on, the prefix registered, the other addon not loaded")

-- 2. the layer is the GUID's server part: two zoneUIDs of one server part are one layer; the wire id keeps both
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(4012, 3, "0A3", 7)))
assert(C(A, "NS.Layer.Current()") == 4012 and #C(A, "NS.Layer.List()") == 1, "another zoneUID, the same layer")
assert(C(A, "NS.Layer.CurrentWire()") == "4012-7", tostring(C(A, "NS.Layer.CurrentWire()")))
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(4012, 4, "0A4")))
assert(C(A, "NS.Layer.CurrentWire()") == "4012-5250")
assert(C(A, "select(2, NS.Layer.ParseWire('6843-8'))") == 8 and C(A, "NS.Layer.ParseWire('6843-x')") == nil)

-- 3. asking: ZQ to the known Amisia user only, the plain ask to everyone else, one whisper per name
C(A, [[AmisiaDB.layerHosts = { ["kai lindner"] = time() }
    WHORESULT = { "Anna Bergmann", "Udo Fremd", "Kai Lindner", "Ole Fremd", "Pia Weit", "Rolf Leer" }]])
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, "STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
local ask = "inv layer <LS 1429 not 4012-5250 48.2,42.5>"
for _, n in ipairs({ U, "Ole Fremd", "Pia Weit", "Rolf Leer" }) do
    local t = sentTo(A, n)
    assert(#t == 1 and t[1] == ask, n .. ": " .. tostring(t[1]))
    assert(BUS.count({ kind = "ZQ", sender = A, target = n }) == 0, "never both to " .. n)
end
assert(#sentTo(A, K) == 0 and BUS.count({ kind = "ZQ", sender = A, target = K }) == 1, "Kai, a known Amisia user, gets ZQ alone")
assert(#sentTo(A, A) == 0)
BUS.tick(3)
-- Udo (Amisia from this version, another layer) answers the other addon's way and invites by himself
local heard = sentTo(U, A)
assert(heard[1] == "heard Anna Bergmann|3999-5250|1429|h", tostring(heard[1]))
assert(C(U, "INVITED[1]") == A, "Udo invites without a question")
assert(BUS.count({ kind = "ZA", sender = K, target = A }) == 1, "Kai answers ZA")
-- players of the other addon: a helper of another layer, one on the own layer, one without a layer
fire(A, "Ole Fremd", "heard Anna Bergmann|7000-3|1429|h")
fire(A, "Pia Weit", "same")
fire(A, "Rolf Leer", "heard Anna Bergmann|-|1429|h")
fire(A, "Zoe Niemand", "heard Anna Bergmann|7001-3|1429|h")
fire(A, "Ole Fremd", "heard Somebody Else|7000-3|1429|h")
local z = C(A, "NS.LayerChange.State().zone")
assert(z.reached == 5 and z.heardN == 5 and z.hosts == 4 and z.other == 2, ("%d %d %d %d"):format(z.reached, z.heardN, z.hosts, z.other))
C(A, "NS.LayerWindow.Show()")
assert(C(A, "AmisiaLayerFrame.zone:GetText()") == "Erreicht: 5 · gehört: 5 · auf anderem Layer: 2", C(A, "AmisiaLayerFrame.zone:GetText()"))
-- F-221: the ask without a layer goes in rounds 3 s and 10 s after the burst; the first waits while a helper of
-- another layer answered
BUS.tick(4)
assert(#sentTo(A, "Rolf Leer") == 1, "not in the first round: helpers of another layer answered")
BUS.tick(6)
local re = sentTo(A, "Rolf Leer")
assert(#re == 2 and re[2] == "inv layer <LS 1429 48.2,42.5>", "the helper without a layer gets the ask without one: " .. tostring(re[2]))
assert(#sentTo(A, "Ole Fremd") == 1, "once per name")
local hosts = C(A, "AmisiaDB.layerHosts")
assert(hosts["udo fremd"].t < 0 and hosts["ole fremd"].t < 0 and hosts["kai lindner"].t > 0 and not hosts["zoe niemand"], "answerers kept")
-- F-221: the helper mark: who answered as a helper goes first next time
assert(hosts["ole fremd"].h == 1 and hosts["pia weit"].h == 1 and hosts["udo fremd"].h == 1, "helpers marked")
assert(C(A, "NS.LayerChange.LoadedHosts(AmisiaDB); return AmisiaDB.layerHosts['ole fremd'].t") < 0, "kept through the load")

-- 4. only an answerer's invite: a stranger's stays the client's, one that named the own layer too
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Zoe Niemand")]])
assert(C(A, "ACCEPTED") == 0 and C(A, "NS.LayerChange.State().pending") == nil, "not asked: not accepted")
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Pia Weit")]])
assert(C(A, "ACCEPTED") == 0, "a helper on the own layer: not accepted")
-- F-221: and a warning in the window
assert(C(A, "NS.LayerWindow.StatusText(NS.LayerChange.State())") == "Pia Weit ist auf deinem Layer: ablehnen und warten.")
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd")]])
assert(C(A, "ACCEPTED") == 1 and C(A, "NS.LayerChange.State().pending.foreign") == true, "Udo answered: accepted")
-- 5. the group; F-221: SHARD_TRANSFER alone is no success, the new layer read is; Amisia leaves 4 s after it
BUS.setRaid({ U, A })
C(A, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')")
assert(C(A, "NS.LayerChange.State().swap.host") == U)
C(A, "STUB.fire('SHARD_TRANSFER')")
assert(C(A, "NS.LayerChange.State().swap.changed") == nil and C(A, "NS.LayerChange.State().swap.moved") == true
    and C(A, "NS.Layer.Current()") == nil, "moved; the layer to be read again")
assert(C(A, "NS.LayerWindow.StatusText(NS.LayerChange.State())"):find("bewegt", 1, true))
C(A, "STUB.fire('PLAYER_TARGET_CHANGED')")
assert(C(A, "NS.Layer.Current()") == nil, "the old layer's creature in view does not count")
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(3999, 5, "0B1")))
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(3999, 6, "0B2")))
assert(C(A, "NS.LayerChange.State().swap.changed ~= nil"), "the new layer read: changed")
BUS.tick(5)
assert(C(A, "LEFT") == 1, "left 4 s after the change")
C(A, "STUB.party = nil; STUB.roster = {}; STUB.fire('GROUP_ROSTER_UPDATE')")
BUS.setRaid({})

-- 6. Udo as a host: heard and same, the invite, bad lines, the limits
C(U, "NS.LayerChange._reset(); NS.LayerForeign._reset(); INVITED = {}")
fire(U, "Lea Gleich", "inv layer <LS 1429 not 3999-1 50.0,50.0>")
BUS.tick(1)
local t = sentTo(U, "Lea Gleich")
-- F-221: "h" says "helping and able to invite", whatever layer the ask names
assert(#t == 2 and t[1] == "heard Lea Gleich|3999-5250|1429|h" and t[2] == "same", "on the asker's layer: same, no invite")
assert(C(U, "#INVITED") == 0)
fire(U, "Max Weg-Anderswo", "inv layer <LS 1429 not 4012-5250 10.0,10.0>")
BUS.tick(1)
t = sentTo(U, "Max Weg-Anderswo")
assert(t[1] == "heard Max Weg|3999-5250|1429|h" and C(U, "INVITED[1]") == "Max Weg-Anderswo", tostring(t[1]))
fire(U, "Max Weg-Anderswo", "inv layer <LS 1429 not 4012-5250 10.0,10.0>")
BUS.tick(1)
assert(#sentTo(U, "Max Weg-Anderswo") == 1, "one answer per asker in 10 s")
-- want: only the layer asked for
fire(U, "Nina Will", "inv layer <LS 1429 want 4012-5250>")
BUS.tick(1)
assert(sentTo(U, "Nina Will")[1] == "heard Nina Will|3999-5250|1429|h" and C(U, "#INVITED") == 1, "another layer wanted")
-- bad lines and another zone get nothing
local before = #BUS.sent
for _, bad in ipairs({ "inv layer <LS abc>", "inv layer <LS 1429 foo 1-2>", "inv layer <LS 1429 not 12>",
    "inv layer <LS 1429 want 1-2 not 3-4>", "inv layer <LS 1429 not 1-2> extra", "inv layer", "claim Lea Gleich",
    "inv layer <LS " .. string.rep("1", 130) .. ">", "inv layer <LS 1430 not 4012-5250>", "pos 1429 1 2" }) do
    fire(U, "Bert Boese", bad)
end
C(U, ("STUB.fire('CHAT_MSG_ADDON', %q, 'inv layer <LS 1429 not 4012-5250>', 'GUILD', 'Bert Boese')"):format(P))
BUS.tick(1)
assert(#BUS.sent == before, "bad lines, another zone, another channel: nothing")
-- the flood: 20 answers a minute at most
C(U, ([[for i = 1, 25 do STUB.fire("CHAT_MSG_ADDON", %q, "inv layer <LS 1429 not 4012-5250>", "WHISPER", "Gast " .. string.char(64 + i)) end]]):format(P))
BUS.tick(5)
local n = BUS.count(function(m) return m.sender == U and m.prefix == P and m.text:find("^heard Gast") ~= nil end)
assert(n <= 20 - 3 and n > 0, "20 answers a minute: " .. n)
assert(C(U, "#INVITED") <= 6, "six invites in ten minutes at most: " .. C(U, "#INVITED"))
BUS.tick(61)

-- 7. the other addon loaded: Amisia neither answers nor asks that way
C(U, "NS.LayerChange._reset(); NS.LayerForeign._reset(); INVITED = {}")
C(U, ("STUB.loaded[%q] = true"):format(P))
assert(C(U, "NS.LayerForeign.Active()") == false)
fire(U, "Lea Gleich", "inv layer <LS 1429 not 4012-5250>")
BUS.tick(1)
assert(#sentTo(U, "Lea Gleich") == 2 and C(U, "#INVITED") == 0, "no answer while it is loaded")
local mark, text = C(U, "return NS.SelfTest.Layer.ForeignLine(NS.LayerForeign.Status())")
assert(mark == "WERT" and text:find("selbst ist geladen", 1, true), text)
C(U, ("STUB.loaded[%q] = nil"):format(P))
-- the switch off: the same
C(U, "NS.Set('layer.foreign', false)")
fire(U, "Lea Gleich", "inv layer <LS 1429 not 4012-5250>")
BUS.tick(1)
assert(#sentTo(U, "Lea Gleich") == 2, "off: no answer")
C(U, "NS.Set('layer.foreign', true)")

-- 8. helping off: heard without "h", no invite; skip near; the world restart
C(U, "NS.LayerChange.SetHosting(false)")
fire(U, "Olga Aus", "inv layer <LS 1429 not 4012-5250 90.0,90.0>")
BUS.tick(1)
assert(sentTo(U, "Olga Aus")[1] == "heard Olga Aus|3999-5250|1429|-" and C(U, "#INVITED") == 0, "helping off")
C(U, "NS.LayerChange.SetHosting(true); NS.Set('layer.skipNear', true)")
fire(U, "Pit Nah", "inv layer <LS 1429 not 4012-5250 49.0,43.0>")
fire(U, "Quinn Ohne", "inv layer <LS 1429 not 4012-5250>")
fire(U, "Rita Fern", "inv layer <LS 1429 not 4012-5250 90.0,90.0>")
BUS.tick(1)
assert(sentTo(U, "Pit Nah")[1]:sub(-2) == "|-" and sentTo(U, "Quinn Ohne")[1]:sub(-2) == "|-", "near and without a position: skipped")
assert(sentTo(U, "Rita Fern")[1]:sub(-2) == "|h" and C(U, "INVITED[1]") == "Rita Fern", "far: invited")
C(U, "NS.Set('layer.skipNear', false); NS.LayerChange._reset(); INVITED = {}")
C(U, "STUB.eviction = 252; STUB.fire('SHARD_TRANSFER_IMMINENT')")
assert(C(U, "NS.Layer.RefreshText()") == "Neustart in 4:12", C(U, "NS.Layer.RefreshText()"))
assert(C(U, "NS.LayerWindow.HostText(true, false, 0, NS.Layer.RefreshText())"):find("Neustart in 4:12: Helfen", 1, true))
C(U, "NS.LayerWindow.Show(); NS.LayerWindow.Minimize()")
assert(C(U, "AmisiaLayerMiniBar.sub:GetText()") == "Neustart in 4:12", "the bar counts down")
fire(U, "Sven Spaet", "inv layer <LS 1429 not 4012-5250>")
BUS.tick(1)
assert(sentTo(U, "Sven Spaet")[1]:sub(-2) == "|-" and C(U, "#INVITED") == 0, "no invites while the restart is announced")
C(U, "STUB.tick(252)")
assert(C(U, "NS.Layer.RefreshText()") == "Neustart gleich")
C(U, "STUB.tick(121)")
assert(C(U, "NS.Layer.RefreshText()") == nil, "gone 2 minutes after")
C(U, "STUB.eviction = 100; STUB.fire('SHARD_TRANSFER_IMMINENT'); STUB.eviction = nil; STUB.fire('SHARD_TRANSFER_CANCELLED')")
assert(C(U, "NS.Layer.RefreshText()") == nil, "cancelled")
-- the bar on one line
C(U, "NS.Set('layer.barOneLine', true); NS.LayerWindow.UpdateMini()")
assert(C(U, "AmisiaLayerMiniBar:GetHeight()") == C(U, "NS.Theme.LAYER.MINI_ONE_H") and C(U, "AmisiaLayerMiniBar.name:GetText()"):find(" · ", 1, true))
C(U, "NS.Set('layer.barOneLine', false); NS.LayerWindow.Restore(); NS.LayerWindow.Hide()")

-- 9. guild last: the guild's names of the /who get the plain ask only when no helper of another layer answered
C(A, "NS.LayerChange._reset(); NS.LayerForeign._reset(); AmisiaDB.layerHosts = {}")
BUS.tick(11)
C(A, [[NS.GuildMember = function(n) if n == "Gil Gilde" then return { name = n } end end
    NS.InGuild = function() return true end
    WHORESULT = { "Gil Gilde", "Tom Tal" }]])
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(4012, 6, "0C1")))
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, "STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
assert(#sentTo(A, "Tom Tal") == 1 and #sentTo(A, "Gil Gilde") == 0, "the guild last")
BUS.tick(5)
assert(#sentTo(A, "Gil Gilde") == 1, "nobody else answered: the guild now")
C(A, "NS.LayerChange.Stop(); NS.LayerChange._reset(); NS.LayerForeign._reset()")
BUS.tick(11)
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(4012, 7, "0C2")))
C(A, [[WHORESULT = { "Gil Zwei", "Tom Zwei" }
    NS.GuildMember = function(n) if n == "Gil Zwei" then return { name = n } end end]])
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, "STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
fire(A, "Tom Zwei", "heard Anna Bergmann|7000-3|1429|h")
BUS.tick(6)
assert(#sentTo(A, "Gil Zwei") == 0, "a helper of another layer answered: the guild is not asked that way")
C(A, "NS.LayerChange.Stop(); NS.InGuild = function() return false end")

-- 10. the self-test line, the client refusing the whispers, the offline line
mark, text = C(A, "return NS.SelfTest.Layer.ForeignLine(NS.LayerForeign.Status())")
assert(mark == "OK" and text:find("gehen raus", 1, true), text)
C(A, "NS.LayerChange._reset(); NS.LayerForeign._reset()")
BUS.tick(11)
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(4012, 8, "0C3")))
C(A, [[_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "Kein Spieler namens '%s' ist zurzeit online."
    WHORESULT = { "Uwe Offline", "Vera Voll" }]])
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, "STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
assert(C(A, [[NS.CommOfflineLine("Kein Spieler namens 'Uwe Offline' ist zurzeit online.")]]) == true, "the offline line stays out")
C(A, "NS.LayerChange._reset(); NS.LayerForeign._reset()")
BUS.tick(11)
C(A, ([[STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")]]):format(guid(4012, 9, "0C4")))
C(A, [[WHORESULT = { "Wim Eins", "Xia Zwei" }; STUB.addonResult = 4]])
assert(C(A, "return NS.LayerChange.Swap()") == true)
C(A, "STUB.fire('WHO_LIST_UPDATE')")
BUS.tick(1)
C(A, "STUB.addonResult = nil")
mark, text = C(A, "return NS.SelfTest.Layer.ForeignLine(NS.LayerForeign.Status())")
assert(mark == "FEHLER" and text:find("lehnt", 1, true) and C(A, "NS.LayerForeign.Active()") == false, text)
C(A, "SlashCmdList.AMISIA('selbsttest layer')")
BUS.tick(9)
assert(C(A, "NS.SelfTest.Frame().area.box:GetText()"):find("Anderes Layer-Addon: das Spiel lehnt", 1, true), "the report's line")
assert(C(A, "STUB.messages[#STUB.messages]"):find("anderes Layer-Addon gesperrt", 1, true), C(A, "STUB.messages[#STUB.messages]"))
print("layer foreign ok")
