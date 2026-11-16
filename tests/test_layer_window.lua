--[[clients Anna_Bergmann Vulo_Sturmwind Lena_Kraus Kai_Lindner]]
-- The window Layer with one button to swap and helping on and off (F-214): "Layer wechseln" asks the guild
-- and asks the first fitting answer for the invite by itself (a clicked layer's row: only that layer); no
-- answer: the next click opens the channel line, never the chat by itself; "Helfen" off answers nobody,
-- takes no request and no chat line, closes an open question and is on again after a reset; the count of
-- this session's helping.
local A, V, Lk, K = "Anna Bergmann", "Vulo Sturmwind", "Lena Kraus", "Kai Lindner"
BUS.setGuild({ { A, 3 }, { V, 3 }, { Lk, 3 }, { K, 3 } })
local function guid(zone, npc, spawn) return ("Creature-0-%d-0-5250-%d-%s"):format(zone, npc, spawn) end
local function world(name, zone)
    C(name, ([[STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
        STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
        STUB.place.map = 1429
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        INVITED, ACCEPTED, OPENED = {}, 0, nil
        C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end
        _G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
        _G.StaticPopup_Hide = function() end
        _G.ChatFrame_OpenChat = function(l) OPENED = l end
        _G.GetChannelName = function(n) if n == 1 then return 1, "Allgemein - Wald von Elwynn" end return 0 end]]):format(
        guid(zone, 1, "0A1"), guid(zone, 2, "0A2")))
end
-- the question first (layer.autoInvite is on by default since F-216)
assert(C(V, "NS.Get('layer.autoInvite')") == true)
for _, n in ipairs({ A, V, Lk, K }) do C(n, "NS.Set('layer.autoInvite', false)") end
world(A, 4012)
world(V, 3999)
world(Lk, 3998)
world(K, 4012)
BUS.tick(15)
local function step(name) return C(name, "NS.LayerChange.SwapStep()") end
local function fresh()
    for _, n in ipairs({ A, V, Lk, K }) do
        C(n, [[STUB.targetGUID = STUB.targetGUID:gsub("%x%x%x$", function(x) return ("%03X"):format((tonumber(x, 16) + 1) % 4096) end)
            STUB.fire("PLAYER_TARGET_CHANGED")]])
    end
end

-- 1. "Layer wechseln": the guild is asked, the button waits, then the first answer is asked for the invite
assert(step(A) == "ask")
C(A, "NS.LayerWindow.Show()")
assert(C(A, "AmisiaLayerFrame.swap:GetText()") == "Layer wechseln" and C(A, "AmisiaLayerFrame.host:GetText()") == "Helfen: AN")
assert(C(A, "AmisiaLayerFrame.guildRow:IsShown() and AmisiaLayerFrame.channelRow:IsShown()"), "both chat rows in a guild")
C(A, "AmisiaLayerFrame.swap:Click()")
-- F-221: the running search's button stops it, from its first second on
assert(step(A) == "stop" and C(A, "AmisiaLayerFrame.swap:GetText()") == "Suche stoppen")
assert(not C(A, "AmisiaLayerFrame.swap:IsEnabled()"), "not in the first second")
BUS.tick(1.1)
C(A, "NS.LayerWindow.Refresh()")
assert(C(A, "AmisiaLayerFrame.swap:IsEnabled()"), "then it stops the search")
assert(BUS.count({ kind = "YI", sender = A }) == 0, "no pick before PICK_WAIT")
BUS.tick(6)
assert(BUS.count({ kind = "YA", sender = V, target = A }) == 1 and BUS.count({ kind = "YA", sender = Lk, target = A }) == 1)
assert(BUS.count({ kind = "YI", sender = A }) == 1, "one request for an invite, by itself")
assert(BUS.count({ kind = "YI", sender = A, target = Lk }) == 1, "the first in the answers' order: Lena's Layer A")
assert(step(A) == "stop" and C(A, "NS.LayerChange.State().pending.name") == Lk)
assert(C(Lk, "AmisiaConfirmFrame:IsShown()"), "Lena is asked")
-- the host's count: one asked; the invite; the join
assert(C(Lk, "NS.LayerChange.Helped().asked") == 1 and C(Lk, "NS.LayerChange.Helped().invited") == 0)
C(Lk, "AmisiaConfirmFrame.ok:Click()")
assert(C(Lk, "INVITED[1]") == A and C(Lk, "NS.LayerChange.Helped().invited") == 1)
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Lena Kraus")]])
assert(C(A, "ACCEPTED") == 1, "the picked host's invite is accepted")
BUS.setRaid({ A, Lk })
for _, n in ipairs({ A, Lk }) do C(n, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')") end
assert(C(Lk, "NS.LayerChange.Helped().joined") == 1)
C(A, "NS.LayerWindow.Refresh()")
assert(step(A) == "leave" and C(A, "AmisiaLayerFrame.swap:GetText()") == "Gruppe verlassen", "in the helper's group: leave")
C(Lk, "NS.LayerWindow.Show()")
local helped = C(Lk, "AmisiaLayerFrame.helped:IsShown() and AmisiaLayerFrame.helped:GetText()")
assert(helped == "|cff4fbf7aGeholfen: 1 haben gefragt, 1 eingeladen, 1 gekommen.|r", tostring(helped))
assert(not C(A, "AmisiaLayerFrame.helped:IsShown()"), "nothing helped: no green line")
BUS.setRaid({})
for _, n in ipairs({ A, Lk }) do C(n, "STUB.party = nil; STUB.roster = {}; STUB.fire('GROUP_ROSTER_UPDATE')") end
C(A, "NS.LayerChange._reset()")

-- 2. a clicked layer's row: only that layer's answer counts
BUS.tick(11)
fresh()
local rowUid = C(A, [[NS.LayerWindow.Refresh()
    for _, r in ipairs(AmisiaLayerFrame.seen) do if r:IsShown() and r.uid == 3999 then r:Click() return r.uid end end]])
assert(rowUid == 3999, "Vulo's layer has a row (heard from the guild)")
BUS.tick(7)
assert(BUS.count({ kind = "YI", sender = A }) == 2 and BUS.count({ kind = "YI", sender = A, target = V }) == 1, "only Vulo's layer")
local ok, why = C(A, "return NS.LayerChange.Swap(4012)")
assert(not ok, "a swap runs: " .. tostring(why))
C(A, "NS.LayerChange._reset()")
C(V, "AmisiaConfirmFrame:Hide()")

-- 3. helping off: Vulo and Lena answer nothing; no answer: the button turns to the channel
BUS.tick(11)
fresh()
C(V, "NS.LayerChange.SetHosting(false)")
C(Lk, "NS.LayerChange.SetHosting(false)")
assert(C(V, "NS.LayerWindow.HostText(NS.LayerChange.Hosting())"):find("Helfen aus", 1, true))
local before = BUS.count({ kind = "YA" })
C(A, "AmisiaLayerFrame.swap:Click()")
BUS.tick(11)
assert(BUS.count({ kind = "YA" }) == before, "nobody answers with helping off")
assert(step(A) == "channel" and C(A, "OPENED") == nil, "never opens the chat by itself")
C(A, "NS.LayerWindow.Refresh()")
assert(C(A, "AmisiaLayerFrame.swap:GetText()") == "Im Kanal fragen")
assert(C(A, "AmisiaLayerFrame.status:GetText()") == "Keine Antwort von einem anderen Layer: frag im Kanal.")
assert(C(A, "NS.LayerWindow.MiniState(NS.LayerChange.State())") == "host", "no answer: the search is over")
C(A, "AmisiaLayerFrame.swap:Click()")
assert(C(A, "OPENED") == "/1 inv layer" and C(A, "NS.LayerChange.State().chatAll") == true, "the second click opens the channel")

-- helping off: a whispered request line and a YI are dropped; an open question closes when it goes off
local asked = C(V, "NS.LayerChange.Helped().asked")
assert(asked == 1, "Vulo was asked once (the row's request)")
C(V, [[STUB.fire("CHAT_MSG_WHISPER", "inv layer", "Kai Lindner")]])
BUS.tick(1)
assert(not C(V, "AmisiaConfirmFrame:IsShown()") and C(V, "NS.LayerChange.Helped().asked") == asked)
C(V, "NS.LayerChange.SetHosting(true)")
C(V, [[STUB.fire("CHAT_MSG_WHISPER", "inv layer", "Kai Lindner")]])
BUS.tick(1)
assert(C(V, "AmisiaConfirmFrame:IsShown()"), "on again: Kai's whisper is asked")
C(V, "NS.LayerChange.SetHosting(false)")
assert(not C(V, "AmisiaConfirmFrame:IsShown()"), "helping off closes the question")
assert(C(V, "#INVITED") == 0)
-- a question that is not the layer's stays
C(V, [[NS.W.Confirm("X", "anderes", "OK", function() end)]])
C(V, "NS.LayerChange.SetHosting(true)"); C(V, "NS.LayerChange.SetHosting(false)")
assert(C(V, "AmisiaConfirmFrame:IsShown()"), "another question stays open")
C(V, "AmisiaConfirmFrame:Hide()")
-- a reset (login) turns it on again
C(V, "NS.LayerChange._reset()")
assert(C(V, "NS.LayerChange.Hosting()") == true)

-- 4. outside a guild the first click opens the channel; the guild row hides
C(K, [[NS.LayerChange._reset(); NS.InGuild = function() return false end; NS.LayerWindow.Show()]])
assert(step(K) == "channel" and not C(K, "AmisiaLayerFrame.guildRow:IsShown()"))
C(K, "AmisiaLayerFrame.swap:Click()")
assert(C(K, "OPENED") == "/1 inv layer")

-- 5. review fixes: two players pressing "Layer wechseln" together neither answer nor ask each other;
-- a chat row ends the running swap's pick (the channel's invite counts, no guild YI on top)
BUS.tick(61)
fresh()
for _, n in ipairs({ A, V, Lk }) do C(n, "NS.LayerChange._reset(); OPENED = nil") end
local va, lv = BUS.count({ kind = "YA", sender = V, target = Lk }), BUS.count({ kind = "YA", sender = Lk, target = V })
C(V, "NS.LayerChange.Swap()")
C(Lk, "NS.LayerChange.Swap()")
BUS.tick(8)
assert(BUS.count({ kind = "YA", sender = V, target = Lk }) == va and BUS.count({ kind = "YA", sender = Lk, target = V }) == lv,
    "two askers do not answer each other")
assert(not C(V, "AmisiaConfirmFrame:IsShown()"), "nobody asks an asker")
for _, n in ipairs({ V, Lk }) do C(n, "NS.LayerChange._reset()") end
BUS.tick(11)
fresh()
local yi = BUS.count({ kind = "YI", sender = A })
C(A, "NS.LayerChange.Swap()")
C(A, "NS.LayerChange.AskChannel()")
assert(C(A, "NS.LayerChange.State().auto") == nil and C(A, "OPENED") == "/1 inv layer")
BUS.tick(8)
assert(BUS.count({ kind = "YI", sender = A }) == yi, "no guild request on top of the channel's")
