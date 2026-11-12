--[[clients Anna_Bergmann Vulo_Sturmwind Kai_Lindner Udo_Fremd]]
-- The layer change inside the guild (F-185, D-117): Anna asks the guild (YQ on GUILD), Vulo on another layer
-- of the same zone answers by whisper (YA), Kai on Anna's layer stays silent; Anna asks Vulo for the
-- invite (YI), Vulo is asked (W.Confirm) or invites at once (layer.autoInvite); Anna's Amisia accepts
-- only Vulo's invite (an invite of anyone else stays untouched), sees the change and leaves the two-player
-- group by itself only with layer.autoLeave and only that group. Udo outside the guild gets nothing; a
-- foreign prefix is ignored; the host's limits (once a minute per player, six in ten minutes).
local A, V, K, U = "Anna Bergmann", "Vulo Sturmwind", "Kai Lindner", "Udo Fremd"
BUS.setGuild({ { A, 3 }, { V, 3 }, { K, 3 } })
local function guid(zone, npc, spawn) return ("Creature-0-5250-0-%d-%d-%s"):format(zone, npc, spawn) end
-- every client in Elwynn Forest; each reads two creatures of its layer
local function world(name, zone)
    C(name, ([[STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
        STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
        STUB.place.map = 1429
        STUB.fire("PLAYER_ENTERING_WORLD")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        STUB.targetGUID = "%s"; STUB.fire("PLAYER_TARGET_CHANGED")
        INVITED, ACCEPTED, LEFT, HIDDEN = {}, 0, 0, {}
        C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end
        C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 end
        _G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
        _G.StaticPopup_Hide = function(w) HIDDEN[#HIDDEN + 1] = w end]]):format(guid(zone, 1, "0A1"), guid(zone, 2, "0A2")))
end
world(A, 4012)
world(V, 3999)
world(K, 4012)
world(U, 3999)
BUS.tick(15)
assert(C(A, "NS.Layer.Current()") == 4012 and C(V, "NS.Layer.Current()") == 3999)

-- in a group Anna cannot ask
C(A, [[STUB.roster = { { name = "Anna Bergmann" }, { name = "Kai Lindner" } }]])
local ok, why = C(A, "return NS.LayerChange.Ask()")
assert(not ok and why:find("Erst die Gruppe verlassen", 1, true), tostring(why))
C(A, "STUB.roster = {}")

-- Anna asks: one YQ to the guild; only Vulo answers, by whisper
assert(C(A, "return NS.LayerChange.Ask()") == true)
local ok2, why2 = C(A, "return NS.LayerChange.Ask()")
assert(not ok2 and why2:find("10 Sekunden", 1, true), "once in 10 s")
BUS.tick(4)
assert(BUS.count({ kind = "YQ", chan = "GUILD", sender = A }) == 1)
assert(BUS.count({ kind = "YA", chan = "WHISPER", sender = V, target = A }) == 1, "Vulo answers")
assert(BUS.count({ kind = "YA", sender = K }) == 0, "Kai on the same layer stays silent")
assert(BUS.count({ kind = "YA", sender = U }) == 0, "Udo outside the guild hears nothing")
local answers = C(A, "NS.LayerChange.Answers()")
assert(#answers == 1 and answers[1].name == V and answers[1].layer == "Layer A" and not answers[1].seen, tostring(answers[1] and answers[1].layer))
assert(C(A, "NS.Layer.Name(1429, 4012)") == "Layer B", "the guild's lower id shifts Anna's letter")
-- the window lists Vulo with the link
C(A, "NS.LayerWindow.Show()")
assert(C(A, "AmisiaLayerFrame.answers[1]:IsShown() and AmisiaLayerFrame.answers[1].text:GetText()") == "Vulo Sturmwind · Layer A |cff4fbf7aneu|r")

-- a stranger's question (not in the guild) and a foreign prefix get nothing
C(V, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1YQ\t1429\t4012\tbeef", "GUILD", "Udo Fremd")
       STUB.fire("CHAT_MSG_ADDON", "AnderesAddon", "1YQ\t1429\t4012\tbeef", "GUILD", "Kai Lindner")
       STUB.fire("CHAT_MSG_ADDON", "AnderesAddon", "LAYER?", "GUILD", "Kai Lindner")]])
BUS.tick(65)
assert(BUS.count({ kind = "YA", sender = V }) == 1, "no answer to a stranger or another addon")

-- a request of someone Vulo did not answer is dropped
C(V, [[STUB.fire("CHAT_MSG_ADDON", "Amisia", "1YI\tbeef\t1429\t3999", "WHISPER", "Kai Lindner")]])
BUS.tick(1)
assert(C(V, "#INVITED") == 0 and not C(V, "AmisiaConfirmFrame ~= nil and AmisiaConfirmFrame:IsShown()"), "nobody asked Kai")

-- the answers are older than a minute now: ask again
local ok3, why3 = C(A, "return NS.LayerChange.RequestInvite('Vulo Sturmwind')")
assert(not ok3 and why3:find("älter als eine Minute", 1, true), tostring(why3))
-- the layers must be fresh: read again
for _, n in ipairs({ A, V, K }) do C(n, [[STUB.targetGUID = STUB.targetGUID:gsub("0A2$", "0B2"); STUB.fire("PLAYER_TARGET_CHANGED")]]) end
assert(C(A, "return NS.LayerChange.Ask()") == true)
BUS.tick(4)
assert(BUS.count({ kind = "YA", sender = V }) == 2)
-- the request: Vulo is asked (no auto invite by default)
assert(C(A, "return NS.LayerChange.RequestInvite('Vulo Sturmwind')") == true)
BUS.tick(1)
assert(BUS.count({ kind = "YI", chan = "WHISPER", sender = A, target = V }) == 1)
assert(C(V, "AmisiaConfirmFrame:IsShown()"), "Vulo is asked")
local q = C(V, "AmisiaConfirmFrame.text:GetText()")
assert(q == "Anna Bergmann möchte auf deinen Layer wechseln (Layer A). Einladen?", q)
C(V, "AmisiaConfirmFrame.ok:Click()")
assert(C(V, "INVITED[1]") == A and C(V, "#INVITED") == 1, "invited")
-- a second invite of the same player within a minute is refused
local okI, whyI = C(V, "return NS.LayerChange.Invite('Anna Bergmann')")
assert(not okI and whyI:find("gerade erst eingeladen", 1, true), tostring(whyI))

-- Anna: an invite from someone else stays untouched; Vulo's is accepted
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Kai Lindner")]])
assert(C(A, "ACCEPTED") == 0 and C(A, "#HIDDEN") == 0, "Kai's invite stays the game's question")
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Vulo Sturmwind")]])
assert(C(A, "ACCEPTED") == 1 and C(A, "HIDDEN[1]") == "PARTY_INVITE", "Vulo's invite accepted")
-- the group of two forms
BUS.setRaid({ A, V })
for _, n in ipairs({ A, V }) do C(n, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')") end
assert(C(A, "NS.LayerChange.State().swap.host") == V)
assert(C(A, "NS.LayerWindow.StatusText(NS.LayerChange.State())"):find("In der Gruppe mit Vulo Sturmwind", 1, true))
-- the change: Anna reads a creature of Vulo's id (known from the answer: one is enough)
C(A, [[STUB.targetGUID = "]] .. guid(3999, 7, "0C1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "NS.LayerChange.State().swap.changed ~= nil"), "the change is seen")
assert(C(A, "STUB.messages[#STUB.messages]"):find("Gewechselt: Layer A", 1, true))
-- without layer.autoLeave nothing leaves; the link does
BUS.tick(40)
assert(C(A, "LEFT") == 0, "no auto leave by default")
assert(C(A, "return NS.LayerChange.Leave()") == true and C(A, "LEFT") == 1)
assert(C(V, "LEFT") == 0, "the host changes nothing")

-- the group ends; a second swap with auto invite and auto leave
for _, n in ipairs({ A, V }) do C(n, "STUB.roster = {}; STUB.party = nil; STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.setRaid({})
assert(C(A, "NS.LayerChange.State().swap") == nil)
C(V, "NS.Set('layer.autoInvite', true)")
C(A, "NS.Set('layer.autoLeave', true); NS.Set('layer.leaveSeconds', 10)")
-- Anna is back on her old layer (a new zone resets, her id is known)
C(A, [[STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.targetGUID = "]] .. guid(4012, 8, "0D1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
BUS.tick(61)
for _, n in ipairs({ V }) do C(n, [[STUB.targetGUID = STUB.targetGUID:gsub("0B2$", "0E2"); STUB.fire("PLAYER_TARGET_CHANGED")]]) end
assert(C(A, "return NS.LayerChange.Ask()") == true)
BUS.tick(4)
assert(C(A, "return NS.LayerChange.RequestInvite('Vulo Sturmwind')") == true)
BUS.tick(1)
assert(C(V, "#INVITED") == 2 and not C(V, "AmisiaConfirmFrame:IsShown()"), "invited at once")
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Vulo Sturmwind")]])
assert(C(A, "ACCEPTED") == 2)
BUS.setRaid({ A, V })
for _, n in ipairs({ A, V }) do C(n, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')") end
C(A, [[STUB.targetGUID = "]] .. guid(3999, 9, "0F1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
BUS.tick(11)
assert(C(A, "LEFT") == 2, "left the two-player group by itself")
-- a group of three is never left by itself
for _, n in ipairs({ A, V }) do C(n, "STUB.roster = {}; STUB.party = nil; STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.setRaid({})
C(A, [[STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.targetGUID = "]] .. guid(4012, 10, "1A1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
BUS.tick(61)
C(V, [[STUB.targetGUID = STUB.targetGUID:gsub("0E2$", "1B2"); STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "return NS.LayerChange.Ask()") == true)
BUS.tick(4)
assert(C(A, "return NS.LayerChange.RequestInvite('Vulo Sturmwind')") == true)
BUS.tick(1)
assert(C(V, "#INVITED") == 3)
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Vulo Sturmwind")]])
BUS.setRaid({ A, V, K })
for _, n in ipairs({ A, V, K }) do C(n, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')") end
C(A, [[STUB.targetGUID = "]] .. guid(3999, 11, "1C1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "NS.LayerChange.State().swap.changed ~= nil"))
BUS.tick(11)
assert(C(A, "LEFT") == 2, "three in the group: not left by itself")
for _, n in ipairs({ A, V, K }) do C(n, "STUB.roster = {}; STUB.party = nil; STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.setRaid({})

-- no change after a minute: "Kein Wechsel"
C(A, [[STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.targetGUID = "]] .. guid(4012, 12, "1D1") .. [["; STUB.fire("PLAYER_TARGET_CHANGED")]])
BUS.tick(61)
C(V, [[STUB.targetGUID = STUB.targetGUID:gsub("1B2$", "1E2"); STUB.fire("PLAYER_TARGET_CHANGED")]])
assert(C(A, "return NS.LayerChange.Ask()") == true)
BUS.tick(4)
assert(C(A, "return NS.LayerChange.RequestInvite('Vulo Sturmwind')") == true)
BUS.tick(1)
C(A, [[STUB.fire("PARTY_INVITE_REQUEST", "Vulo Sturmwind")]])
BUS.setRaid({ A, V })
for _, n in ipairs({ A, V }) do C(n, "STUB.party = true; STUB.fire('GROUP_ROSTER_UPDATE')") end
BUS.tick(61)
local text, leave = C(A, "return NS.LayerWindow.StatusText(NS.LayerChange.State())")
assert(text == "Kein Wechsel: der Layer ist derselbe geblieben." and leave == true, tostring(text))
assert(C(A, "LEFT") == 2, "no change: nothing left by itself")

-- the host's limit: six invites in ten minutes
local refused = C(V, [[for i = 1, 6 do NS.LayerChange.Invite("Gast Nummer" .. string.char(64 + i)) end
    local ok, why = NS.LayerChange.Invite("Gast Zuviel")
    return why]])
assert(type(refused) == "string" and refused:find("sechs Layer-Einladungen", 1, true), tostring(refused))
