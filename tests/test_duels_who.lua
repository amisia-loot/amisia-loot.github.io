-- Duels, /who on a click (F-106, D-52, Core/Duels.lua): the client's who list, closed at the question,
-- is closed again after Amisia's answer, but not when the player opened it himself while the answer
-- was awaited, nor after the player's own /who in between (his answer, no Amisia message).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local D = NS.Duels

_G.DUEL_WINNER_KNOCKOUT = "%1$s hat %2$s in einem Duell besiegt."
_G.DUEL_WINNER_RETREAT = "%2$s ist vor %1$s aus einem Duell geflohen."
STUB.zone = "Durotar"
_G.GetRealZoneText = function() return STUB.zone end
STUB.player = "Vuloo"
local function say(text) STUB.fire("CHAT_MSG_SYSTEM", text) end

local sent, toUi = {}, {}
STUB.who = {}
_G.C_FriendList.SendWho = function(q) sent[#sent + 1] = q end
_G.C_FriendList.SetWhoToUi = function(on) toUi[#toUi + 1] = on end
_G.C_FriendList.GetNumWhoResults = function() return #STUB.who, #STUB.who end
_G.C_FriendList.GetWhoInfo = function(i) return STUB.who[i] end

-- the who window with its scripts: Show and Hide run OnShow and OnHide
local hidden = 0
local fr = { shown = false, scripts = {} }
function fr:IsShown() return self.shown end
function fr:HookScript(k, fn) self.scripts[k] = self.scripts[k] or {}; table.insert(self.scripts[k], fn) end
local function run(k) for _, fn in ipairs(fr.scripts[k] or {}) do fn(fr) end end
function fr:Show() if not self.shown then self.shown = true run("OnShow") end end
function fr:Hide() if self.shown then self.shown = false run("OnHide") end end
_G.LFGParentFrame = fr
_G.HideUIPanel = function(f) hidden = hidden + 1 f:Hide() end
-- the client's handler opens the list on every answer (it runs before Amisia's)
local function answer(list)
    STUB.who = list
    fr:Show()
    STUB.fire("WHO_LIST_UPDATE")
    STUB.tick(0.1)
end

local n = 0
local function unknownDuel()
    n = n + 1
    STUB.tick(6)
    say(("Fremd%s hat Vuloo in einem Duell besiegt."):format(string.char(96 + n)))
    STUB.tick(6)
end

-- 1. Amisia's answer opens the closed list: closed again
unknownDuel()
assert(D.WhoAsk(), "asked")
STUB.messages = {}
answer({ { fullName = "Zed", filename = "MAGE" } })
assert(hidden == 1 and not fr.shown, "the list Amisia's answer opened is closed again")
assert(has(STUB.messages[#STUB.messages], "brachte"), "Amisia's message")

-- 2. the player opens the list himself while the answer is awaited: it stays open
STUB.tick(6)
assert(D.WhoAsk(), "asked again")
STUB.tick(1)
fr:Show()                              -- the player's click
STUB.tick(1)
answer({ { fullName = "Fremda", filename = "ROGUE" } })
assert(hidden == 1 and fr.shown, "the list the player opened stays open")
assert(D.ClassOf("Fremda") == "ROGUE", "the answer still teaches the class")
fr:Hide()

-- 3. opened by the player and closed again before the answer: the answer's opening is closed
unknownDuel()
assert(D.WhoAsk(), "asked a third time")
STUB.tick(1)
fr:Show()
STUB.tick(1)
fr:Hide()
STUB.tick(1)
answer({ { fullName = "Fremdb", filename = "DRUID" } })
assert(hidden == 2 and not fr.shown, "closed by the player before: Amisia's answer closes again")

-- 4. the player's own /who while Amisia's question waits: his answer, the list stays, no message
unknownDuel()
local before = #sent
assert(D.WhoAsk() and #sent == before + 1, "asked a fourth time")
STUB.tick(1)
C_FriendList.SendWho('n-"Freund"')     -- the player's /who
assert(#sent == before + 2, "his /who went out")
STUB.messages = {}
answer({ { fullName = "Fremdc", filename = "HUNTER" } })
assert(hidden == 2 and fr.shown, "after the player's own /who the list stays open")
assert(D.ClassOf("Fremdc") == "HUNTER", "his answer teaches the class too")
for _, m in ipairs(STUB.messages) do assert(not has(m, "brachte"), "no Amisia message for his answer") end
fr:Hide()

-- 5. after that, Amisia's own question is Amisia's again
unknownDuel()
assert(D.WhoAsk(), "asked a fifth time")
answer({ { fullName = "Fremdd", filename = "PALADIN" } })
assert(hidden == 3 and not fr.shown, "Amisia's own question: closed again")
assert(toUi[#toUi] == false, "SetWhoToUi back")
