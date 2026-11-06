-- Duels, /who on a click (F-106, D-52, Core/Duels.lua): Amisia never closes the client's who list
-- (HideUIPanel from an addon taints the client's panel manager, D-64). The list the answer opens stays;
-- SetWhoToUi goes back once it closes. After the player's own /who in between the answer is his (no
-- Amisia message).
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

-- 1. Amisia's answer opens the closed list: it stays open, SetWhoToUi goes back when it closes
unknownDuel()
assert(D.WhoAsk(), "asked")
assert(toUi[#toUi] == true, "the answer goes to the list")
STUB.messages = {}
answer({ { fullName = "Zed", filename = "MAGE" } })
assert(hidden == 0 and fr.shown, "Amisia closes no client window")
assert(has(STUB.messages[#STUB.messages], "brachte"), "Amisia's message")
assert(toUi[#toUi] == true, "SetWhoToUi stays on while the list shows")
fr:Hide()                              -- the player closes it
assert(toUi[#toUi] == false, "SetWhoToUi back once the list closes")

-- 2. the player's own /who while Amisia's question waits: his answer, no message
unknownDuel()
local before = #sent
assert(D.WhoAsk() and #sent == before + 1, "asked again")
STUB.tick(1)
C_FriendList.SendWho('n-"Freund"')     -- the player's /who
assert(#sent == before + 2, "his /who went out")
STUB.messages = {}
answer({ { fullName = "Fremdb", filename = "HUNTER" } })
assert(hidden == 0 and fr.shown, "the list stays open")
assert(D.ClassOf("Fremdb") == "HUNTER", "his answer teaches the class too")
for _, m in ipairs(STUB.messages) do assert(not has(m, "brachte"), "no Amisia message for his answer") end
fr:Hide()

-- 3. after that, Amisia's own question is Amisia's again
unknownDuel()
assert(D.WhoAsk(), "asked a third time")
STUB.messages = {}
answer({ { fullName = "Fremdc", filename = "PALADIN" } })
assert(has(STUB.messages[#STUB.messages], "brachte"), "Amisia's message again")
assert(hidden == 0, "never closed by Amisia")
fr:Hide()
assert(toUi[#toUi] == false, "SetWhoToUi back")
