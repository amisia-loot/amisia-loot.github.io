--[[locale enUS]]
-- English for the raid area: the loot announcement, soft reserves (page, import window, !sr
-- answers, chat), rolls (round, roll window, page), the award dialog, the awards, raids and raid
-- log pages, the bench, materials, the Discord text and the sync state speak English; the English
-- slash words work beside the German ones; dates are English; no German umlaut word shows.
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function german(text) return type(text) == "string" and text:find("[\195][\164\182\188\132\150\156\159]") ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

-- every text a frame tree shows, joined
local function texts(frame, out, seen)
    out, seen = out or {}, seen or {}
    if type(frame) ~= "table" or seen[frame] then return out end
    seen[frame] = true
    if frame.GetText and frame.IsShown and frame:IsShown() then
        local ok, t = pcall(frame.GetText, frame)
        if ok and type(t) == "string" and t ~= "" then out[#out + 1] = t end
    end
    for _, v in pairs(frame) do
        if type(v) == "table" and v ~= frame and (v.GetText or v.GetObjectType or #v > 0) then texts(v, out, seen) end
    end
    return out
end
local function shown(frame) return table.concat(texts(frame), "\n") end

local tip = {}
GameTooltip.AddLine = function(_, t) tip[#tip + 1] = t end
local function tipText() return table.concat(tip, "\n") end

STUB.officer = true
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")

local l1 = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local l2 = STUB.item(32837, "Warglaive of Azzinoth", 5)

---------------------------------------------------------------------------
-- dates and the soft-reserve list
---------------------------------------------------------------------------
assert(NS.SoftResShortDate("2026-10-05") == "Oct 5", NS.SoftResShortDate("2026-10-05"))
NS.SetSoftRes("Fraktur 32235\nGustav 32235\nChorf 32837\nChorf 32837\n")
assert(NS.SoftResTooltipText(32235) == "Reserved: Fraktur (+1 outside)", NS.SoftResTooltipText(32235))

---------------------------------------------------------------------------
-- loot announcement (raid chat in the sender's language)
---------------------------------------------------------------------------
local BOSS = "Creature-0-1-1-1-22917-1"
STUB.target, STUB.targetGUID = "Illidan Stormrage", BOSS
STUB.loot = { { link = l1, name = "x", src = BOSS }, { link = l2, name = "x", src = BOSS } }
STUB.tick(10); STUB.chat = {}
STUB.fire("LOOT_OPENED", false)
assert(STUB.chat[1] and STUB.chat[1].text == "Amisia Loot (Illidan Stormrage): 2 items", STUB.chat[1] and STUB.chat[1].text)
assert(STUB.chat[2].text == "1. " .. l1 .. " SR: Fraktur (+1 not in the raid)", STUB.chat[2].text)
assert(STUB.chat[3].text == "2. " .. l2 .. " SR: Chorf x2", STUB.chat[3].text)
NS.Dispatch("announce")
assert(lastMsg() ~= "" and not has(lastMsg(), "Unknown command"), "the English word works: " .. lastMsg())
STUB.fire("LOOT_CLOSED")
NS.Dispatch("ansage")
assert(has(lastMsg(), "No loot window open."), lastMsg())
local la = NS.SettingItem("loot.announce")
assert(la.label == "Announce loot in raid chat" and la.section.label == "Loot announcement", la.label)

---------------------------------------------------------------------------
-- slash help: English words and arguments
---------------------------------------------------------------------------
local help = table.concat(NS.SlashHelpLines(true), "\n")
for _, w in ipairs({ "/amisia announce - announce the open loot window again", "/amisia awards - open the Awards page",
                     "/amisia sr [check|remind|post|forget [name]] - show soft reserves",
                     "/amisia mats [add|remove <link>] - show raid materials",
                     "/amisia bench [name] [note] | remove <name>", "/amisia addroll <name> <number> [os]",
                     "/amisia rolltime <5-120>", "/amisia log [events|rolls] - the raid's raid log",
                     "/amisia boss <name> [wipe] - enter a boss kill or wipe by hand", "/amisia alts [name|clear]" }) do
    assert(has(help, w), w .. "\n" .. help)
end
NS.Dispatch("sr check")
assert(has(table.concat(STUB.messages, "\n"), "Check against Raid (3): 2 reserved, 1 without a reserve, 1 not in the raid"),
    table.concat(STUB.messages, "\n"))
NS.Dispatch("mats")
assert(has(lastMsg(), "No raid materials yet."), lastMsg())
NS.Dispatch("mats frob")
assert(has(lastMsg(), "Usage: /amisia mats [add|remove <link>]"), lastMsg())
NS.Dispatch("boss")
assert(has(lastMsg(), "Usage: /amisia boss <name> [wipe]"), lastMsg())

---------------------------------------------------------------------------
-- !sr answers by whisper
---------------------------------------------------------------------------
NS.Set("loot.lead", "me")
STUB.tick(20); STUB.chat = {}
STUB.fire("CHAT_MSG_WHISPER", "!sr", "Fraktur")
local ans = STUB.chat[1] and STUB.chat[1].text or ""
assert(has(ans, "Amisia: Your reserves (list of " .. NS.FmtDay(time()) .. "): "), ans)
NS.Reset("loot.lead")

---------------------------------------------------------------------------
-- soft-reserve page, import window and card
---------------------------------------------------------------------------
NS.ShowPage("softres")
local sp = NS.SoftResPageFrame()
assert(has(sp.state:GetText(), "List of " .. NS.FmtDay(time()) .. ":|r 4 reserves from 3 raiders"), sp.state:GetText())
assert(sp.import:GetText() == "Import" and sp.clear:GetText() == "Delete", sp.import:GetText())
assert(sp.views.raider.label:GetText() == "Raiders" and sp.views.check.label:GetText() == "Check")
assert(sp.remind:GetText() == "Remind (0)" and sp.post:GetText() == "Post in raid", sp.remind:GetText())
assert(not german(shown(sp)), shown(sp))
NS.ToggleSoftResFrame()
local SF = NS.SoftResFrame
assert(SF.applyBtn:GetText() == "Apply" and SF.clearBtn:GetText() == "Clear")
assert(has(SF.dateText:GetText(), "Today's list:|r 4 reserves"), SF.dateText:GetText())
assert(NS.SoftResPreviewText("Vuloo 32235") == "Preview against Raid (3): 1 raiders, 1 reserve · 2 without a reserve",
    NS.SoftResPreviewText("Vuloo 32235"))
NS.ToggleSoftResFrame()
assert(StaticPopupDialogs.AMISIA_SR_REMIND.text == "Whisper %d raiders without a reserve?"
    and StaticPopupDialogs.AMISIA_SR_REMIND.button1 == "Whisper")

---------------------------------------------------------------------------
-- rolls: the round in the raid chat, the roll window, the page
---------------------------------------------------------------------------
STUB.tick(20); STUB.chat = {}
NS.Dispatch("roll " .. l1 .. " 20")
local r = NS.CurrentRoll()
assert(r, "the round runs")
STUB.tick(2)
local said = {}
for _, c in ipairs(STUB.chat) do said[#said + 1] = c.text end
said = table.concat(said, "\n")
assert(has(said, "/roll for main spec, /roll 99 for off spec. 20 seconds."), said)
assert(has(said, "Reserved by Fraktur, Gustav."), said)
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 77, 1, 100))
NS.Dispatch("addroll Chorf 50")
assert(has(lastMsg(), "Roll entered: Chorf 50"), lastMsg())
NS.ShowRollFrame()
local RF = NS.RollFrame
local rf = shown(RF)
assert(has(rf, "Stop") and has(rf, "Add"), rf)
assert(not german(rf), rf)
NS.ShowPage("rolls")
local rp = NS.RollsPageFrame()
assert(has(rp.current:GetText(), "Running round: ") and has(rp.current:GetText(), "running, "), rp.current:GetText())
assert(has(shown(rp), "Roll window") and has(shown(rp), "Last rounds"), shown(rp))
assert(not german(shown(rp)), shown(rp))
STUB.tick(25)
assert(r.done, "the round is over")
NS.Refresh()
assert(has(rp.list.rows[1].text:GetText(), "Fraktur"), rp.list.rows[1].text:GetText())
RF:Hide()

---------------------------------------------------------------------------
-- award dialog and the awards page
---------------------------------------------------------------------------
NS.ShowAwardDialog(l2, s)
local D = AmisiaAwardDialog
assert(D and D:IsShown(), "the dialog opens")
assert((D.give:GetText() == "Award" or D.give:GetText() == "Add") and D.de:GetText() == "Disenchant" and D.cancel:GetText() == "Cancel", D.give:GetText())
assert(D.raidText:GetText():match("^Raid: .+, %a%a%a %d+$"), "an English date: " .. D.raidText:GetText())
assert(not german(shown(D)), shown(D))
D:Hide()
NS.AddAwardTo(s, { name = "Chorf", item = 32837, kind = "MS", src = "Illidan Stormrage" })
NS.AddAwardTo(s, { name = "bank", to = "bank", item = 32235, kind = "-", src = "Illidan Stormrage" })
NS.Dispatch("awards")
assert(NS.CurrentPage() == "awards", "/amisia awards opens the page")
local ap = NS.AwardsPageFrame().officer
assert(ap.undo:GetText() == "Undo" and ap.add:GetText() == "Add", ap.add:GetText())
assert(has(ap.head:GetText(), "2 awards") and has(ap.head:GetText(), "1 bank") and has(ap.head:GetText(), "Raid not exported"),
    ap.head:GetText())
assert(not german(shown(ap)), shown(ap))
NS.Dispatch("vergaben")
assert(NS.CurrentPage() == "awards", "the German word still works")

---------------------------------------------------------------------------
-- raids page and raid log page
---------------------------------------------------------------------------
NS.ShowPage("raids")
local rs = NS.RaidsPageFrame()
assert(rs.del:GetText() == "Delete" and rs.all:GetText() == "Select all", rs.del:GetText())
assert(rs.pageText:GetText() == "1 raid", rs.pageText:GetText())
local det = NS.RaidDetailText(s)
assert(has(det, "Raiders (3):") and has(det, "Bosses:|r none") and has(det, "Warglaive of Azzinoth to Chorf (MS)"), det)
assert(not german(shown(rs)), shown(rs))
assert(StaticPopupDialogs.AMISIA_DELETE.text == "Delete the ticked raids from Amisia?")

NS.Dispatch("bench Bob Twink")
assert(has(lastMsg(), "Bob is on the bench (") and has(lastMsg(), ", note: Twink"), lastMsg())
NS.Dispatch("log")
local rl = NS.RaidLogPageFrame()
assert(rl.views.verlauf.label:GetText() == "Timeline" and rl.views.bench.label:GetText() == "Bench (1)",
    rl.views.bench.label:GetText())
assert(rl.addBoss:GetText() == "Add boss" and rl.discordBtn:GetText() == "Discord text")
local first = rl.log.list.rows[1]
assert(first.event:GetText() == "Recording started", first.event:GetText())
assert(has(rl.counts:GetText(), "3 raiders") and has(rl.counts:GetText(), "1 bench"), rl.counts:GetText())
assert(not german(shown(rl)), shown(rl))
NS.ShowRaidLog("bench")
assert(has(rl.bench.label:GetText(), "Bench: "), rl.bench.label:GetText())
assert(has(shown(rl.bench), "by Vuloo"), shown(rl.bench))
NS.ShowRaidLog("discord")
assert(has(rl.discord.hint:GetText(), "Ctrl+A, Ctrl+C, paste into Discord."), rl.discord.hint:GetText())
NS.Dispatch("bench remove Bob")
assert(has(lastMsg(), "Bob is no longer on the bench."), lastMsg())

---------------------------------------------------------------------------
-- the sync state line
---------------------------------------------------------------------------
local text = NS.SyncStatus(s)
assert(has(text, "Sync: "), text)
assert(not german(text), text)
