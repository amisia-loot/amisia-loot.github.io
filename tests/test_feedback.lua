--[[clients Vulo_Vultrox Kim_Eisherz Pug Ann_Ally]]
--[[preload
ERR_CHAT_PLAYER_NOT_FOUND_S = "Kein Spieler namens '%s' ist derzeit online."
STUB.filters = {}
ChatFrame_AddMessageEventFilter = function(event, fn) STUB.filters[#STUB.filters + 1] = { event = event, fn = fn } end
-- an error handler that can be replaced (Amisia chains itself in front of it); it still raises
STUB.handler = function(e) STUB.lastError = e; error(e, 0) end
geterrorhandler = function() return STUB.handler end
seterrorhandler = function(fn) STUB.handler = fn end
]]
-- Feedback (F-130, D-61): Kim Eisherz and Pug (strangers, no guild) send reports to the author Vulo
-- Vultrox; Ann Ally plays the other faction. Online and offline, the retry, "angekommen", the limits on
-- both sides, stripped codes, only the author takes FB, FA only from the author, the page's controls,
-- the inbox with "Erledigt" kept over a /reload, the error capture and the author's chat summary.
local VULO, KIM, PUG, ANN = "Vulo Vultrox", "Kim Eisherz", "Pug", "Ann Ally"

for _, name in ipairs(CLIENTS) do
    C(name, ([[STUB.faction = %q; STUB.class = "MAGE"; STUB.level = 23; STUB.inGuild = false
        STUB.fire("PLAYER_LOGIN")]]):format(name == ANN and "Alliance" or "Horde"))
end
local function said(name, text)
    return C(name, ([[for _, m in ipairs(STUB.messages) do if m:find(%q, 1, true) then return true end end return false]]):format(text))
end
local function inbox(n) return C(VULO, "#AmisiaDB.feedback.inbox") == n end
local function outState(name, i) return C(name, ("NS.Feedback.Out()[%d].state"):format(i or 1)) end

assert(C(VULO, "NS.Feedback.IsAuthor()") == true and C(KIM, "NS.Feedback.IsAuthor()") == false)
assert(C(KIM, "NS.Feedback.Reachable()") == true, "same faction, Forever: reachable")
assert(C(ANN, "NS.Feedback.Reachable()") == false, "the other faction cannot reach the author")

-- 1. the author online: within seconds in his inbox, "angekommen" at the sender
assert(C(KIM, [[return NS.Feedback.Submit("B", "Rangliste zeigt falsche Stufe")]]) == true)
assert(said(KIM, "Meldung an den Autor unterwegs."))
BUS.tick(3)
assert(inbox(1), "in the author's inbox")
local e = C(VULO, "AmisiaDB.feedback.inbox[1]")
assert(e.from == KIM and e.kind == "B" and e.text == "Rangliste zeigt falsche Stufe" and e.new == true)
assert(e.meta.v and e.meta.g == "f" and e.meta.loc == "deDE" and e.meta.cls == "MAGE" and e.meta.lvl == 23, "the details came along")
assert(outState(KIM) == "done" and said(KIM, "Deine Meldung ist beim Autor angekommen."))
assert(BUS.count({ kind = "FB", sender = KIM, target = VULO, chan = "WHISPER" }) == 2, "details and one text part")
assert(BUS.count({ kind = "FA", sender = VULO, target = KIM }) == 1)

-- 2. the author offline: the server's line is swallowed, the report waits
BUS.drop(function(m) return m.kind == "FB" end)
assert(C(KIM, [[return NS.Feedback.Submit("W", "Bitte eine Suche\nmit zwei Zeilen")]]) == true)
BUS.tick(1)
assert(outState(KIM) == "sent")
local line = "Kein Spieler namens 'Vulo Vultrox' ist derzeit online."
assert(C(KIM, ([[return STUB.filters[1].fn(nil, "CHAT_MSG_SYSTEM", %q)]]):format(line)) == true, "swallowed")
assert(C(KIM, [[return STUB.filters[1].fn(nil, "CHAT_MSG_SYSTEM", "Kein Spieler namens 'Bob' ist derzeit online.")]]) == false)
C(KIM, ([[STUB.fire("CHAT_MSG_SYSTEM", %q)]]):format(line))
assert(outState(KIM) == "wait" and said(KIM, "Der Autor ist gerade nicht online"))
assert(C(KIM, "NS.Feedback.Out()[1].tries") == 1)
-- 3. no retry before 30 minutes; then it goes, now that the author is there
BUS.drop(nil)
BUS.tick(120)
assert(outState(KIM) == "wait", "30 minutes between tries")
C(KIM, "STUB.combat = true")
C(KIM, "NS.Feedback.Out()[1].next = 0")
BUS.tick(20)
assert(outState(KIM) == "wait", "nothing in combat")
C(KIM, "STUB.combat = false; STUB.instance = { type = 'party', name = 'Dungeon' }")
BUS.tick(20)
assert(outState(KIM) == "wait", "a retry never in an instance")
C(KIM, "STUB.instance = { type = 'none' }")
BUS.tick(20)
assert(outState(KIM) == "done", "retried and delivered")
assert(inbox(2) and C(VULO, [[return NS.Feedback.Inbox("all")[1].text == "Bitte eine Suche" .. string.char(10) .. "mit zwei Zeilen"]]), "the line break kept")

-- 4. no answer at all (no "not online" line): after 30 s it waits; a /reload, a login, 2-5 minutes, there
BUS.drop(function(m) return m.kind == "FB" end)
assert(C(KIM, [[return NS.Feedback.Submit("W", "|cffff0000Rot|r und |Hitem:19019|h[Donnerzorn]|h|T:0|t ok")]]) == true)
BUS.tick(31)
assert(outState(KIM) == "wait")
assert(C(KIM, "NS.Feedback.Out()[1].text") == "Rot und [Donnerzorn] ok", "codes, links and textures stripped")
BUS.reload(KIM)
C(KIM, [[STUB.faction = "Horde"; STUB.class = "MAGE"; STUB.level = 23]])
assert(C(KIM, "NS.Feedback.Out()[1].state") == "wait", "kept over the reload")
BUS.drop(nil)
C(KIM, [[STUB.fire("PLAYER_LOGIN")]])
BUS.tick(100)
assert(C(KIM, "NS.Feedback.Out()[1].state") == "wait", "not in the first 2 minutes")
BUS.tick(210)
assert(C(KIM, "NS.Feedback.Out()[1].state") == "done", "after the login")
assert(inbox(3))

-- 5. three a day at most (the page says it in the chat)
C(KIM, [[NS.ShowFeedback(); local f = NS.PageFrame("feedback").write
    f.edit.box:SetText("Noch eine"); f.send:GetScript("OnClick")(f.send)]])
assert(said(KIM, "Höchstens 3 Meldungen am Tag."), "the fourth is refused")
assert(C(KIM, "#AmisiaDB.feedback.out") == 3 and inbox(3))

-- 6. ten tries, then "nicht zugestellt"; "Nochmal" starts over (a new day for both)
C(KIM, "AmisiaDB.feedback.day.n = 0")
C(VULO, "AmisiaDB.feedback.recv.n = {}")
BUS.drop(function(m) return m.kind == "FB" end)
assert(C(KIM, [[return NS.Feedback.Submit("B", "Geht nie an")]]) == true)
BUS.tick(31)
for _ = 2, 10 do
    C(KIM, "NS.Feedback.Out()[1].next = 0")
    BUS.tick(16)
    BUS.tick(31)
end
assert(C(KIM, "NS.Feedback.Out()[1].tries") == 10 and outState(KIM) == "lost", "lost after 10 tries")
C(KIM, "NS.Feedback.Out()[1].next = 0")
BUS.tick(20)
assert(outState(KIM) == "lost", "a lost one is not tried again by itself")
C(KIM, [[NS.ShowFeedback(); NS.Refresh()]])
assert(C(KIM, [[local r = NS.PageFrame("feedback").write.out.rows[1]; return r.retry:IsShown() and r.state:GetText():find("nicht zugestellt", 1, true) ~= nil]]), "Nochmal on the row")
BUS.drop(nil)
C(KIM, [[local r = NS.PageFrame("feedback").write.out.rows[1]; r.retry:GetScript("OnClick")(r.retry)]])
BUS.tick(3)
assert(outState(KIM) == "done" and inbox(4), "Nochmal delivered it")

-- 7. the other faction: the hint, "Abschicken" off, nothing sent
C(ANN, [[NS.ShowFeedback(); local f = NS.PageFrame("feedback").write; f.edit.box:SetText("Hallo")]])
assert(C(ANN, [[local f = NS.PageFrame("feedback").write; return f.hint:GetText():find("Auf diesem Server kann Amisia den Autor nicht erreichen.", 1, true) ~= nil
    and not f.send:IsEnabled()]]), "the hint and Abschicken off")
assert(C(ANN, [[return NS.Feedback.Submit("W", "Hallo")]]) == nil and BUS.count({ sender = ANN }) == 0)

-- 8. the receiver's limits (Pug sends raw messages, past his own client's checks)
local function raw(id, parts)
    C(PUG, ([[local parts = %s
        for i, p in ipairs(parts) do C_ChatInfo.SendAddonMessage("Amisia", "1FB\t" .. %q .. "\t" .. i .. "\t" .. #parts .. "\t" .. p, "WHISPER", "Vulo Vultrox") end]])
        :format(parts, id))
end
local META = [["W\t2.52.0\tf\tdeDE\tROGUE\t40\t-\t-"]]
raw("100-1", "{ " .. META .. ", 'eins' }")
raw("100-2", "{ " .. META .. ", 'zwei' }")
raw("100-3", "{ " .. META .. ", 'drei' }")
BUS.tick(6)
raw("100-4", "{ " .. META .. ", 'vier' }")
BUS.tick(6)
assert(C(VULO, [[local n = 0; for _, e in ipairs(AmisiaDB.feedback.inbox) do if e.from == "Pug" then n = n + 1 end end return n]]) == 3, "3 per sender and day")
assert(BUS.count({ kind = "FA", sender = VULO, target = PUG }) == 3)
-- the same report again: only the answer again
raw("100-1", "{ " .. META .. ", 'eins' }")
BUS.tick(6)
assert(BUS.count({ kind = "FA", sender = VULO, target = PUG }) == 4 and inbox(7))
C(VULO, "AmisiaDB.feedback.recv.n = {}")
-- over 500 characters, a bar, five parts, parts over a minute apart: dropped
raw("101-1", ("{ %s, %q, %q, %q }"):format(META, ("a"):rep(200), ("b"):rep(200), ("c"):rep(150)))
raw("101-2", "{ " .. META .. ", 'mit |cffff0000Farbe' }")
raw("101-3", "{ " .. META .. ", 'a', 'b', 'c', 'd' }")
C(PUG, [[C_ChatInfo.SendAddonMessage("Amisia", "1FB\t101-4\t1\t2\t" .. ]] .. META .. [[, "WHISPER", "Vulo Vultrox")]])
BUS.tick(61)
C(PUG, [[C_ChatInfo.SendAddonMessage("Amisia", "1FB\t101-4\t2\t2\tspaet", "WHISPER", "Vulo Vultrox")]])
BUS.tick(6)
assert(inbox(7), "long, coded, too many parts, too late: all dropped")
-- only the author's client takes FB; FA only from the author for an own report
C(PUG, [[C_ChatInfo.SendAddonMessage("Amisia", "1FB\t102-1\t1\t2\t" .. ]] .. META .. [[, "WHISPER", "Kim Eisherz")
    C_ChatInfo.SendAddonMessage("Amisia", "1FB\t102-1\t2\t2\thallo", "WHISPER", "Kim Eisherz")]])
BUS.tick(3)
assert(C(KIM, "#AmisiaDB.feedback.inbox") == 0, "not the author: dropped")
C(KIM, "AmisiaDB.feedback.day.n = 0")
BUS.drop(function(m) return m.kind == "FB" end)
C(KIM, [[NS.Feedback.Submit("W", "Wartet")]])
local id = C(KIM, "NS.Feedback.Out()[1].id")
C(PUG, ([[C_ChatInfo.SendAddonMessage("Amisia", "1FA\t%s", "WHISPER", "Kim Eisherz")]]):format(id))
BUS.tick(3)
assert(outState(KIM) == "sent", "FA from someone else does nothing")
C(VULO, ([[C_ChatInfo.SendAddonMessage("Amisia", "1FA\t999-9", "WHISPER", "Kim Eisherz")]]))
BUS.tick(3)
assert(outState(KIM) == "sent", "FA for no own report does nothing")
BUS.drop(nil)
-- a blocked sender is dropped
C(VULO, [[NS.Feedback.Block("Pug", true)]])
raw("103-1", "{ " .. META .. ", 'geblockt' }")
BUS.tick(6)
assert(inbox(7), "blocked")
C(VULO, [[NS.Feedback.Block("Pug", false)]])
-- the inbox keeps 300: the oldest done one goes first
C(VULO, [[local list = AmisiaDB.feedback.inbox
    for i = #list + 1, 300 do list[i] = { id = "1-" .. i, from = "Alt" .. i, kind = "W", text = "x", meta = {}, at = 1000 + i, done = (i == 200) or nil } end]])
BUS.tick(61)   -- the half report of 101-4 holds Pug's one open report for a minute
raw("104-1", "{ " .. META .. ", 'neu' }")
BUS.tick(6)
assert(inbox(300), "300 at most")
assert(C(VULO, [[for _, e in ipairs(AmisiaDB.feedback.inbox) do if e.id == "1-200" then return false end end return true]]), "the oldest done one went")
assert(C(VULO, [[return NS.Feedback.Inbox("all")[1].text]]) == "neu")
C(VULO, [[local keep = {}; for _, e in ipairs(AmisiaDB.feedback.inbox) do if not e.from:find("^Alt") then keep[#keep + 1] = e end end
    AmisiaDB.feedback.inbox = keep]])

-- 9. the error capture: the last error naming Amisia goes along with a bug
C(KIM, [[pcall(geterrorhandler(), "Interface/AddOns/Amisia/Core/Bad.lua:12: attempt to index nil")
    pcall(geterrorhandler(), "Interface/AddOns/Other/x.lua:1: not ours")]])
assert(C(KIM, "NS.Feedback.LastError()") == "Amisia/Core/Bad.lua:12: attempt to index nil", "noted, the folder cut")
assert(C(KIM, "STUB.lastError") == "Interface/AddOns/Other/x.lua:1: not ours", "the handler before still gets every error")
C(KIM, "AmisiaDB.feedback.day.n = 0")
C(VULO, "AmisiaDB.feedback.recv.n = {}")
C(KIM, [[NS.Feedback.Submit("B", "Mit Fehler", true)]])
BUS.tick(3)
assert(C(VULO, [[return NS.Feedback.Inbox("all")[1].meta.err]]) == "Amisia/Core/Bad.lua:12: attempt to index nil")

-- 10. the page: Bug/Wunsch, counter, Abschicken off without text, what goes along
C(KIM, [[NS.ShowPage("members"); NS.ShowFeedback()]])
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; f.edit.box:SetText(""); NS.Refresh()
    return f.kinds.B.label:GetText() == "Bug" and f.kinds.W.label:GetText() == "Wunsch" and f.count:GetText() == "0/500" and not f.send:IsEnabled()]]), "the empty field")
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; return f.meta:GetText()]]):find("Seite: Mitglieder", 1, true), "the page before")
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; return f.meta:GetText()]]):find("WoW Forever · deDE", 1, true))
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; return f.errBox:IsShown() and f.errText:GetText()]]):find("Bad.lua", 1, true))
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; f.edit.box:SetText("Hallöchen"); f.edit.box:GetScript("OnTextChanged")(f.edit.box, true)
    return f.count:GetText() == "9/500" and f.send:IsEnabled()]]), "counted in characters")
C(KIM, [[local f = NS.PageFrame("feedback").write; f.kinds.W:GetScript("OnClick")(f.kinds.W)]])
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; return f.kinds.W.on and not f.errBox:IsShown()]]), "a wish has no error box")
assert(C(KIM, [[local f = NS.PageFrame("feedback").write; return f.out.rows[1]:IsShown() and f.out.rows[1].state:GetText()]]):find("angekommen", 1, true))

-- 11. the author's page: the inbox, a click, Erledigt, the filter; kept over a /reload
C(VULO, [[NS.ShowFeedback()]])
assert(C(VULO, [[local f = NS.PageFrame("feedback"); return f.views.inbox.on and f.inbox:IsShown() and not f.write:IsShown()]]))
assert(C(VULO, [[return NS.Panel("feedback").label]]):find("Feedback (", 1, true), "the open count at the page's name")
local open = C(VULO, "NS.Feedback.OpenCount()")
assert(C(VULO, [[local f = NS.PageFrame("feedback"); local r = f.inbox.list.rows[1]
    r:GetScript("OnClick")(r, "LeftButton")
    return f.inbox.detail.body.fs:GetText() .. f.inbox.detail.title:GetText()]]):find("Mit Fehler", 1, true), "the whole text in the detail")
local doneId = C(VULO, [[return NS.Feedback.Inbox("open")[1].id]])
C(VULO, [[local f = NS.PageFrame("feedback"); f.inbox.done:GetScript("OnClick")(f.inbox.done)]])
assert(C(VULO, "NS.Feedback.OpenCount()") == open - 1)
assert(C(VULO, ([[for _, e in ipairs(NS.Feedback.Inbox("open")) do if e.id == %q then return false end end return true]]):format(doneId)), "not under Offen")
assert(C(VULO, [[local f = NS.PageFrame("feedback"); for _, r in ipairs(f.inbox.list.rows) do if r:IsShown() and r.item.done then return false end end return true]]))
BUS.reload(VULO)
C(VULO, [[STUB.faction = "Horde"]])
assert(C(VULO, ([[for _, e in ipairs(NS.Feedback.Inbox("done")) do if e.id == %q then return true end end return false]]):format(doneId)), "Erledigt kept")
assert(C(VULO, "NS.Feedback.OpenCount()") == open - 1)
-- the right click: block the sender
C(VULO, [[NS.ShowFeedback(); local f = NS.PageFrame("feedback"); local r = f.inbox.list.rows[1]
    r:GetScript("OnClick")(r, "RightButton"); local b = AmisiaMenu.buttons[3]; b:GetScript("OnClick")(b)]])
assert(C(VULO, [[return NS.Feedback.IsBlocked(NS.Feedback.Inbox("open")[1].from)]]) == true, "blocked from the menu")

-- 12. the author's own report goes straight into his inbox; the chat summary once a session
local before = C(VULO, "#AmisiaDB.feedback.inbox")
assert(C(VULO, [[return NS.Feedback.Submit("W", "Eigener Test")]]) == true)
assert(C(VULO, "#AmisiaDB.feedback.inbox") == before + 1 and BUS.count({ kind = "FB", sender = VULO }) == 0)
C(VULO, [[for _, e in ipairs(AmisiaDB.feedback.inbox) do e.new = nil end
    AmisiaDB.feedback.inbox[1].new = true; AmisiaDB.feedback.inbox[1].kind = "B"; AmisiaDB.feedback.inbox[2].new = true; AmisiaDB.feedback.inbox[2].kind = "W"]])
BUS.reload(VULO)
C(VULO, [[STUB.faction = "Horde"; STUB.fire("PLAYER_LOGIN")]])
BUS.tick(21)
assert(said(VULO, "Amisia:|r 2 neue Meldungen (1 Bug, 1 Wunsch). /amisia feedback"))
C(VULO, [[NS.Dispatch("feedback")]])
assert(C(VULO, "NS.CurrentPage()") == "feedback", "/amisia feedback opens the page")
