-- The roll window for raiders (RollWindow.lua, D-38) on one client: a round from the trusted loot
-- lead (Fraktur, officer and master looter) opens it, spoofed and malformed rounds do not; Mainspec
-- and Offspec call RandomRoll with 1-100 and 1-99 and show the server's number; the lockdown disables
-- the buttons until ADDON_RESTRICTION_STATE_CHANGED; several items stack (a new round replaces the
-- running one, results stay 5 s); the clock closes it; the test command sends nothing; the setting
-- off shows nothing.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local function recv(text, chan, sender)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", text, chan or "RAID", sender or "Fraktur", "", 0, 0, "", 0)
end
local function ws(fields) return "1WS\t" .. table.concat(fields, "\t") end
local function sent(kind)
    local out = {}
    for _, m in ipairs(STUB.addon) do
        if m.text:sub(2, 3) == kind then out[#out + 1] = m end
    end
    return out
end
local rolls = {}
RandomRoll = function(lo, hi) rolls[#rolls + 1] = { lo, hi } end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Chorf", class = "WARRIOR" }, { name = "Kim Eisherz", class = "MAGE" } }
STUB.playerRaidIndex = 1
STUB.guild = { { name = "Vuloo", rank = 4 }, { name = "Fraktur", rank = 1 }, { name = "Chorf", rank = 4 }, { name = "Kim Eisherz", rank = 2 } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.officer = false
STUB.lootMethod, STUB.mlRaidID = 2, 2
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
local link3 = STUB.item(30000, "Brustplatte", 4)
STUB.addon = {}

local function win() return AmisiaRollWindow end
local function shown() return win() ~= nil and win():IsShown() end
local function row(i) return win().rows[i or 1] end

-- the settings and the command
assert(NS.SettingItem("rollwin.enabled").default == true and NS.SettingItem("rollwin.onlyMine").default == false)
assert(NS.SettingItem("rollwin.self").officer == true and NS.SettingItem("rollwin.sound").default == true)
assert(NS.Visible(NS.SettingItem("rollwin.enabled").section), "the section is everyone's")

---------------------------------------------------------------------------
-- the test command: a window, nothing sent; the dice roll only when clicked
---------------------------------------------------------------------------
NS.Dispatch("wuerfeln test")
assert(shown(), "/amisia wuerfeln test shows the window")
assert(#STUB.addon == 0 and #STUB.chat == 0 and #rolls == 0, "nothing sent, nothing rolled")
assert(has(row().hint:GetText(), "Reserviert von dir"), row().hint:GetText())
assert(row().ms:IsShown() and row().os:IsShown() and row().pass:IsShown() and not row().need:IsShown(), "three buttons")
assert(row().ms:GetText() == "Mainspec" and row().os:GetText() == "Offspec" and row().pass:GetText() == "Passen")
row().os:Click()
assert(#rolls == 1 and rolls[1][1] == 1 and rolls[1][2] == 99, "Offspec rolls 1-99")
assert(not row().ms:IsEnabled() and not row().os:IsEnabled(), "a roll is final")
assert(has(row().status:GetText(), "Gewürfelt: Offspec"), row().status:GetText())
-- the number only from the server's line
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo", 42, 1, 99))
assert(has(row().status:GetText(), "Gewürfelt: Offspec 42"), row().status:GetText())
row().pass:Click()
assert(#STUB.addon == 0, "a test pass sends nothing")
win().CloseButton:Click()
assert(not shown(), "the X closes it")
-- the English word and a points test
NS.Dispatch("rolltest dkp")
assert(shown() and row().bidBtn:IsShown() and row().bidEdit:IsShown() and not row().ms:IsShown(), "a bid round test")
row().bidEdit:SetText("15"); row().bidBtn:Click()
assert(#STUB.addon == 0 and has(row().status:GetText(), "Geboten: 15"), row().status:GetText())
win().CloseButton:Click()
rolls = {}

---------------------------------------------------------------------------
-- a round from the trusted loot lead
---------------------------------------------------------------------------
recv(ws({ "a1b2", "item:32235::::::::70", "20", "R", "-", "Vuloo,Chorf", "-", "-", "-" }))
assert(shown(), "the loot lead's round opens the window")
assert(has(row().name:GetText(), "Cursed Vision"), row().name:GetText())
assert(has(row().hint:GetText(), "Reserviert von dir und einem anderen"), row().hint:GetText())
row().ms:Click()
assert(#rolls == 1 and rolls[1][1] == 1 and rolls[1][2] == 100, "Mainspec rolls 1-100")
assert(#sent("WA") == 0, "a roll sends no addon message")
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo", 87, 1, 100))
assert(has(row().status:GetText(), "Gewürfelt: Mainspec 87"), row().status:GetText())

-- a second round replaces the running one; the end message shows the winner 5 s
recv("1WE\ta1b2\tD\tChorf\t95:MS")
assert(has(row().status:GetText(), "Gewinner: Chorf (95, MS)"), row().status:GetText())
assert(not row().ms:IsShown(), "no buttons after the end")
STUB.tick(1.1)
recv(ws({ "c3d4", "item:32837", "20", "R", "-", "-", "-", "-", "-" }))
assert(#NS._rollWindow.rounds() == 2 and row(1).r.rid == "c3d4" and row(2).r.rid == "a1b2", "the new round on top, the result under it")
assert(row(2):IsShown() and has(row(2).status:GetText(), "Gewinner: Chorf"))
STUB.tick(1.1)
recv(ws({ "e5f6", "item:30000", "20", "R", "-", "-", "-", "-", "-" }))
local list = NS._rollWindow.rounds()
assert(#list == 2 and list[1].rid == "e5f6" and list[2].rid == "a1b2", "the running round c3d4 is replaced, never two running")
STUB.tick(4)
assert(#NS._rollWindow.rounds() == 1 and NS._rollWindow.rounds()[1].rid == "e5f6", "the result left after 5 s")
-- no end message: the window closes 3 s after its own clock
STUB.tick(16)
assert(shown(), "still running")
STUB.tick(3.5)
assert(not shown(), "closed 3 s after the clock")

---------------------------------------------------------------------------
-- the lockdown disables the buttons and the restriction's end enables them again
---------------------------------------------------------------------------
STUB.tick(1.1)
recv(ws({ "0101", "item:32235", "30", "R", "-", "-", "-", "-", "-" }))
assert(shown() and row().ms:IsEnabled())
STUB.chatLock = true
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED"); STUB.tick(0.2)
assert(not row().ms:IsEnabled() and not row().os:IsEnabled() and not row().pass:IsEnabled(), "locked")
assert(has(row().status:GetText(), "Würfeln erst nach dem Kampf"), row().status:GetText())
rolls = {}
row().ms:Click()
assert(#rolls == 0, "no roll in the lockdown")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED"); STUB.tick(0.2)
assert(row().ms:IsEnabled() and row().pass:IsEnabled(), "enabled again")
row().pass:Click()
local wa = sent("WA")
assert(#wa == 1 and wa[1].chan == "WHISPER" and wa[1].target == "Fraktur" and wa[1].text == "1WA\t0101\tP", "Passen whispers WA to the lead only")
assert(#STUB.chat == 0, "nothing in the chat")
assert(has(row().status:GetText(), "Gepasst") and row().ms:IsEnabled(), "after a pass the roll is still open")
win().CloseButton:Click()

---------------------------------------------------------------------------
-- spoofed and malformed rounds open nothing
---------------------------------------------------------------------------
local function none(text, chan, sender, why)
    STUB.tick(1.1)
    recv(text, chan, sender)
    STUB.tick(0.1)
    assert(not shown(), why)
end
local good = { "0202", "item:32235", "20", "R", "-", "-", "-", "-", "-" }
none(ws(good), "RAID", "Chorf", "a raider without officer rank")
none(ws(good), "RAID", "Kim Eisherz", "an officer who does not lead the loot")
none(ws(good), "RAID", "Fremder", "someone outside group and guild")
none(ws(good), "WHISPER", "Fraktur", "a whispered round")
none(ws(good), "GUILD", "Fraktur", "a round in the guild channel")
for i, bad in ipairs({
    { "xyz1", "item:32235", "20", "R", "-", "-" },              -- round id not hex
    { "0202", "|cff|Hitem:1|h", "20", "R", "-", "-" },          -- a coloured link
    { "0202", "item:32235", "999", "R", "-", "-" },             -- seconds out of range
    { "0202", "item:32235", "4", "R", "-", "-" },
    { "0202", "item:32235", "20", "X", "-", "-" },              -- unknown art
    { "0202", "item:32235", "20", "R", "Q", "-" },              -- unknown flag
    { "0202", "item:32235", "20", "R", "-", "A,B,C,D,E,F,G,H,I" }, -- nine reservers
    { "0202", "item:32235", "20", "R", "-", "Anna5" },           -- a digit in a name
    { "0202", "item:32235", "20", "B", "-", "-", "-1" },        -- a negative minimum
    { "0202", "item:" .. ("1"):rep(130), "20", "R", "-", "-" },  -- too long
    { "0202", "item:32235", "20" },                             -- too few fields
}) do
    none(ws(bad), "RAID", "Fraktur", "malformed " .. i)
end
recv(ws(good))
assert(shown(), "the good round still opens it")
win().CloseButton:Click()

---------------------------------------------------------------------------
-- a tie-break only for those tied; the settings
---------------------------------------------------------------------------
STUB.tick(1.1)
recv(ws({ "0303", "item:32235", "10", "R", "T", "-", "-", "-", "Chorf,Kim Eisherz" }))
assert(not shown(), "not tied: no window")
STUB.tick(1.1)
recv(ws({ "0404", "item:32235", "10", "R", "T", "-", "-", "-", "Chorf,Vuloo" }))
assert(shown() and has(row().hint:GetText(), "Stechen: Chorf, Vuloo"), "tied: the window with the names")
win().CloseButton:Click()

NS.Set("rollwin.enabled", false)
STUB.tick(1.1)
recv(ws({ "0505", "item:32235", "20", "R", "-", "-", "-", "-", "-" }))
assert(not shown(), "switched off: no window")
NS.Dispatch("wuerfeln an")
assert(NS.Get("rollwin.enabled") == true and said("Würfel-Fenster an."))
NS.Set("rollwin.onlyMine", true)
STUB.tick(1.1)
recv(ws({ "0606", "item:32235", "20", "R", "-", "Chorf", "-", "-", "-" }))
assert(not shown(), "only mine: not reserved, no upgrade, no wish")
STUB.tick(1.1)
recv(ws({ "0707", "item:32235", "20", "R", "-", "Vuloo", "-", "-", "-" }))
assert(shown(), "only mine: reserved by me")
win().CloseButton:Click()
NS.Set("rollwin.onlyMine", false)

-- need/greed buttons with prices; a malformed end changes nothing
STUB.tick(1.1)
recv(ws({ "0808", "item:30000", "20", "N", "-", "-", "50", "25", "-" }))
assert(row().need:IsShown() and row().need:GetText() == "Bedarf (Preis 50)" and row().greed:GetText() == "Gier (Preis 25)", row().need:GetText())
recv("1WE\t0808\tD\tAnna|r\t1:MS")
assert(not row().r.done, "a malformed end is dropped")
recv("1WE\t0808\tD\tAnna\t:NEED", "RAID", "Chorf")
assert(not row().r.done, "an end from someone else is ignored")
recv("1WE\t0808\tD\tAnna\t:NEED")
assert(row().r.done and has(row().status:GetText(), "Gewinner: Anna (Bedarf)"), row().status:GetText())
STUB.tick(6)
assert(not shown(), "gone after the winner's 5 s")

-- the position goes back with the reset
NS.RollWindowTest()
AmisiaDB.settings.rollWindow = { point = "TOPLEFT", x = 10, y = -10 }
NS.ResetRollWindowPosition()
assert(AmisiaDB.settings.rollWindow.point == nil)
win().CloseButton:Click()
print("roll window ok")
