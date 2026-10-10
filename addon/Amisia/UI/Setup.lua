-- Amisia setup assistant (DECISIONS D-40): "/amisia einrichten" (en "setup") and, for an officer
-- (officer rank or the officer view) who has neither finished nor declined it, a one-time offer at
-- the first open of the main window after a login ("Los" / "Später" / "Nicht mehr fragen").
-- Six steps in one window, each with the existing settings only (never a setting of its own):
--   1 Bank-Charakter and Entzauberer (awards.bankName, awards.deName)
--   2 Lootleitung (loot.lead, D-27)
--   3 Lootart (points.system; for DKP points.dkpMode, minBid, price; for EPGP gpBase, gpScale, minEp)
--   4 Roll-Dauer (rolls.seconds, rolls.countdown)
--   5 first loot rules: presets through ns.AddLootRule (LootRules.lua), lootrules.mode
--   6 the summary, each line with "Ändern" back to its step; "Fertig" saves the done mark
-- A change writes at once through ns.Set (the normal onChange paths run); "Weiter", "Überspringen"
-- and "Zurück" write nothing. Saved: AmisiaDB.setup = { done = epoch, never = epoch }.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.SETUP
local PAD = T.WINDOW_PAD
local CW = S.W - 2 * PAD      -- the content's width
local STEPS = 6

local DB                      -- AmisiaDB
local F, offerFrame           -- the window and the offer, built on first use
local step = 1
local offered                 -- the offer was considered since this login
local steps                   -- the step definitions (below)

---------------------------------------------------------------------------
-- Saved: the done and the "never ask" mark
---------------------------------------------------------------------------
local function epoch(v)
    v = tonumber(v)
    if v and v > 0 and v % 1 == 0 then return v end
    return nil
end

function ns.SetupLoaded(root)
    local s = type(root.setup) == "table" and root.setup or {}
    root.setup = { done = epoch(s.done), never = epoch(s.never) }
    DB = root
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.SetupLoaded(AmisiaDB) end
end)

function ns.SetupState()
    return DB and DB.setup or {}
end

-- Who the setup is for: an officer rank, or the officer view.
local function officer()
    if ns.IsOfficerView() then return true end
    return ns.SelfIsOfficer and ns.SelfIsOfficer(true) or false
end

---------------------------------------------------------------------------
-- Settings: labels and values from the registry
---------------------------------------------------------------------------
local function item(path) return ns.SettingItem(path) end
local function label(path)
    local it = item(path)
    return it and it.label or path
end

-- The value of a setting as the settings page shows it.
local function valueText(path)
    local it, v = item(path), ns.Get(path)
    if not it then return tostring(v) end
    if it.type == "toggle" then return v and L["an"] or L["aus"] end
    if it.type == "text" then return (v == nil or v == "") and L["leer"] or tostring(v) end
    if it.type == "choice" then
        for _, c in ipairs(it.values) do if c[1] == v then return c[2] end end
    end
    return tostring(v)
end

local refresh

local function say(text, bad)
    if not F then return end
    F.status:SetText(text and ((bad and T.RED or T.GREEN) .. text .. "|r") or "")
end

-- Writes one setting through ns.Set; a refused value names why in the status line.
local function set(path, v)
    local ok, why = ns.Set(path, v)
    if ok then say(nil) else say(why, true) end
    if refresh then refresh() end
    return ok
end

---------------------------------------------------------------------------
-- Parts of a step
---------------------------------------------------------------------------
local function textBlock(parent, lines, font)
    local fs = W.Text(parent, font or T.FONT.text, CW, true)
    fs:SetHeight(lines * S.LINE_H)
    fs:SetMaxLines(lines)
    fs:SetJustifyV("TOP")
    return fs
end

-- A row of one setting: its label, the controls after the label column.
local function newRow(parent, path)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(CW, S.ROW_H)
    r.label = W.Text(r, T.FONT.text, S.LABEL_W)
    r.label:SetPoint("LEFT", 0, 0)
    r.label:SetText(path and label(path) or "")
    r.path = path
    r:Show()
    return r
end

local function placeControls(r, list, gap)
    W.Row(r, list, gap or T.LAYOUT.ITEM_GAP, S.LABEL_W + S.LABEL_GAP, 0, { point = "LEFT" })
end

-- One chip per value of a choice setting; the current one is on.
local function choiceRow(parent, path)
    local r = newRow(parent, path)
    r.chips = {}
    for _, v in ipairs(item(path).values) do
        local c = W.Chip(r, v[2], nil, function() set(path, v[1]) end)
        W.FitChip(c, 60)
        c.value = v[1]
        r.chips[#r.chips + 1] = c
    end
    placeControls(r, r.chips, T.CHIP_GAP)
    function r:Fill()
        local cur = ns.Get(self.path)
        for _, c in ipairs(self.chips) do c:SetOn(c.value == cur) end
    end
    return r
end

local function stepperRow(parent, path)
    local r = newRow(parent, path)
    local it = item(path)
    r.control = W.Stepper(r, 130, function(v) set(path, v) end)
    r.control:Configure(it.min, it.max, it.step)
    placeControls(r, { r.control })
    function r:Fill() self.control:SetValue(ns.Get(self.path)) end
    return r
end

local function toggleRow(parent, path)
    local r = newRow(parent, path)
    r.control = W.Toggle(r, function(v) set(path, v) end)
    placeControls(r, { r.control })
    function r:Fill() self.control:SetChecked(ns.Get(self.path) and true or false) end
    return r
end

-- The group and the online guild members (and oneself), sorted, each once.
local function namesNear()
    local out, seen = {}, {}
    local function add(n)
        n = ns.FullName(n)
        if n and not seen[n:lower()] then
            seen[n:lower()] = true
            out[#out + 1] = n
        end
    end
    add(ns.UnitFullName("player"))
    for _, n in ipairs(ns.GroupRoster()) do add(n) end
    for _, m in ipairs(ns.GuildRoster and ns.GuildRoster() or {}) do
        if m.online then add(m.name) end
    end
    table.sort(out)
    local values = {}
    for i, n in ipairs(out) do values[i] = { value = n, text = n } end
    return values
end

-- A name: a picker of the group and guild (free text at its end), "Mich eintragen", the red X.
local function nameRow(parent, path)
    local r = newRow(parent, path)
    r.pick = W.Picker(r, S.PICK_W, function(v) set(path, v) end)
    r.me = W.Button(r, L["Mich eintragen"], nil, function() set(path, ns.UnitFullName("player") or "") end,
        { height = T.ROW_BUTTON_H })
    W.FitChip(r.me, 90)
    r.clear = W.ResetButton(r, T.RESET, function() set(path, "") end)
    W.Tooltip(r.clear, L["Name entfernen"], nil)
    function r:Fill()
        local v = ns.Get(self.path)
        self.pick:SetValues(namesNear(), L["Anderer Name"])
        if v == nil or v == "" then
            self.pick:SetValue(nil)
            self.pick.label:SetText(T.GREY .. L["leer"] .. "|r")
            self.clear:Hide()
        else
            self.pick:SetValue(v)
            self.clear:Show()
        end
        local list = { self.pick, self.me }
        if v ~= nil and v ~= "" then list[3] = self.clear end
        placeControls(self, list)
    end
    return r
end

---------------------------------------------------------------------------
-- Step 5: the presets of the loot rules
---------------------------------------------------------------------------
local PRESETS = {
    { label = L["Grünes zum Entzaubern"], rule = { k = "q", q = 2, to = "de" } },
    { label = L["Grünes und Blaues zum Entzaubern"], rule = { k = "q", q = 3, to = "de" } },
    { label = L["Raidmaterialien an die Bank"], rule = { k = "m", to = "bank" } },
}

local function hasRule(spec)
    for _, r in ipairs(ns.LootRules().list) do
        if r.k == spec.k and r.to == spec.to and (spec.k ~= "q" or r.q == spec.q) then return r end
    end
    return nil
end

-- Creates the preset's rule once. The raid materials go above the quality rules: a quality rule
-- would else take a green or blue material to the disenchanter first.
local function addPreset(p)
    if hasRule(p.rule) then
        say(L["Diese Regel gibt es schon."], true)
        return nil
    end
    local r, why = ns.AddLootRule({ k = p.rule.k, q = p.rule.q, to = p.rule.to })
    if not r then
        say(why, true)
        return nil
    end
    if r.k == "m" then
        local list = ns.LootRules().list
        for _ = 1, #list do
            local i
            for j, x in ipairs(list) do if x.id == r.id then i = j end end
            if not i or i == 1 or list[i - 1].k ~= "q" then break end
            ns.MoveLootRule(r.id, -1)
        end
    end
    say(L["Regel angelegt: %s"]:format(ns.LootRuleLabel(r)))
    if refresh then refresh() end
    return r
end

local function rulesText()
    local list = ns.LootRules().list
    if #list == 0 then return T.GREY .. L["Noch keine Regeln. Ohne Regeln verteilt Amisia nichts von selbst."] .. "|r" end
    local lines = {}
    for i, r in ipairs(list) do
        if i > S.RULE_ROWS then
            lines[#lines + 1] = T.GREY .. L["+%d weitere"]:format(#list - S.RULE_ROWS) .. "|r"
            break
        end
        local problem = ns.LootRuleProblem(r)
        local who = problem and (T.RED .. L["Name fehlt"] .. "|r")
            or (r.k ~= "p" and (T.GREY .. ns.Get(r.to == "bank" and "awards.bankName" or "awards.deName") .. "|r")) or ""
        lines[#lines + 1] = ("%d. %s  %s"):format(i, ns.LootRuleLabel(r), who)
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- The steps: title, build(frame) puts its parts into frame.parts, fill(frame) shows the values,
-- summary() the lines of step 6 ({ text } each)
---------------------------------------------------------------------------
local function summaryLine(path) return L["%s: %s"]:format(label(path), valueText(path)) end

steps = {
    { title = L["Bank und Entzauberer"],
      build = function(f)
          f.intro = textBlock(f, 3)
          f.intro:SetText(L["Master Loot an diese Namen zählt als Bank bzw. Entzaubern, und die Lootregeln geben dorthin. Wähle einen Namen aus Gruppe oder Gilde, oder trage unter \"Anderer Name\" einen ein."])
          f.bank = nameRow(f, "awards.bankName")
          f.de = nameRow(f, "awards.deName")
          f.parts = { f.intro, f.bank, f.de }
      end,
      summary = function() return { summaryLine("awards.bankName"), summaryLine("awards.deName") } end },
    { title = L["Lootleitung"],
      build = function(f)
          f.intro = textBlock(f, 3)
          f.intro:SetText(L["Genau ein Amisia im Raid sagt Loot an und beantwortet !sr und !bench, damit zwei Offiziere nicht doppelt posten: der Plündermeister, sonst der Schlachtzugsleiter."])
          f.lead = choiceRow(f, "loot.lead")
          f.hint = textBlock(f, 2, T.FONT.hint)
          f.hint:SetText(L["\"Immer ich\" nimmst du, wenn der Leiter Amisia nicht hat. Antworten gehen immer per Flüstern."])
          f.parts = { f.intro, f.lead, f.hint }
      end,
      summary = function() return { summaryLine("loot.lead") } end },
    { title = L["Lootart"],
      build = function(f)
          f.system = choiceRow(f, "points.system")
          f.about = {}
          for i, text in ipairs({ L["Würfeln: Mainspec 1-100, Offspec 1-99, der höchste Wurf gewinnt."],
                                  L["DKP: Punkte für Raid und Bosse; Items per Gebot oder zu festen Preisen."],
                                  L["EPGP: EP für Anwesenheit, GP für Items; vorne liegt das höhere EP/GP."] }) do
              f.about[i] = textBlock(f, 1)
              f.about[i].text = text
          end
          f.dkp = { choiceRow(f, "points.dkpMode"), stepperRow(f, "points.minBid"), stepperRow(f, "points.price") }
          f.epgp = { stepperRow(f, "points.gpBase"), stepperRow(f, "points.gpScale"), stepperRow(f, "points.minEp") }
          f.hint = textBlock(f, 2, T.FONT.hint)
          f.hint:SetText(item("points.system").tip or "")
      end,
      fill = function(f)
          local sys = ns.Get("points.system")
          local order = { "roll", "dkp", "epgp" }
          for i, fs in ipairs(f.about) do
              fs:SetText(order[i] == sys and fs.text or (T.GREY .. fs.text .. "|r"))
          end
          -- the rows of the chosen system only
          f.parts = { f.system, f.about[1], f.about[2], f.about[3] }
          for _, r in ipairs(f.dkp) do
              r:SetShown(sys == "dkp")
              if sys == "dkp" then f.parts[#f.parts + 1] = r end
          end
          for _, r in ipairs(f.epgp) do
              r:SetShown(sys == "epgp")
              if sys == "epgp" then f.parts[#f.parts + 1] = r end
          end
          f.parts[#f.parts + 1] = f.hint
      end,
      summary = function()
          local sys = ns.Get("points.system")
          local line = summaryLine("points.system")
          if sys == "dkp" then line = line .. " · " .. valueText("points.dkpMode") .. ", " .. summaryLine("points.minBid")
          elseif sys == "epgp" then line = line .. " · " .. summaryLine("points.gpBase") end
          return { line }
      end },
    { title = L["Roll-Dauer"],
      build = function(f)
          f.intro = textBlock(f, 2)
          f.intro:SetText(L["Wie lange eine Roll-Runde läuft und ob Amisia die Restzeit im Raid ansagt. Das Würfel-Fenster der Raider zeigt dieselbe Zeit."])
          f.seconds = stepperRow(f, "rolls.seconds")
          f.countdown = toggleRow(f, "rolls.countdown")
          f.hint = textBlock(f, 1, T.FONT.hint)
          f.hint:SetText(item("rolls.countdown").tip or "")
          f.parts = { f.intro, f.seconds, f.countdown, f.hint }
      end,
      summary = function() return { summaryLine("rolls.seconds") .. " · " .. summaryLine("rolls.countdown") } end },
    { title = L["Erste Lootregeln"],
      build = function(f)
          f.intro = textBlock(f, 3)
          f.intro:SetText(L["Kleinkram verteilt Amisia als Plündermeister nach Regeln an Bank oder Entzauberer. Ein Klick legt eine Regel an; Reserviertes, Priorisiertes und Gewünschtes fasst keine Regel an."])
          f.presetRow = CreateFrame("Frame", nil, f)
          f.presetRow:SetSize(CW, S.ROW_H)
          f.presetRow:Show()
          f.presets = {}
          for i, p in ipairs(PRESETS) do
              local b = W.Button(f.presetRow, p.label, nil, function() addPreset(p) end, { height = T.ROW_BUTTON_H })
              W.FitChip(b, 80)
              f.presets[i] = b
          end
          -- the buttons in a row, a second row when they do not fit the width (the German texts)
          local x, y = 0, 0
          for _, btn in ipairs(f.presets) do
              if x > 0 and x + btn:GetWidth() > CW then x, y = 0, y - S.ROW_H end
              btn:ClearAllPoints()
              btn:SetPoint("TOPLEFT", f.presetRow, "TOPLEFT", x, y - (S.ROW_H - T.ROW_BUTTON_H) / 2)
              x = x + btn:GetWidth() + T.LAYOUT.ITEM_GAP
          end
          f.presetRow:SetHeight(S.ROW_H - y)
          f.head = W.Text(f, T.FONT.head, CW)
          f.head:SetHeight(S.LINE_H)
          f.head:SetText(label("lootrules.list"))
          f.rules = textBlock(f, S.RULE_ROWS + 1)
          f.mode = choiceRow(f, "lootrules.mode")
          f.parts = { f.intro, f.presetRow, f.head, f.rules, f.mode }
      end,
      fill = function(f) f.rules:SetText(rulesText()) end,
      summary = function()
          return { L["Lootregeln: %d"]:format(#ns.LootRules().list) .. " · " .. summaryLine("lootrules.mode") }
      end },
    { title = L["Zusammenfassung"],
      build = function(f)
          f.intro = textBlock(f, 2)
          f.intro:SetText(L["Das ist jetzt eingestellt. \"Ändern\" führt zurück zu seinem Schritt; alles steht auch unter Einstellungen."])
          f.parts = { f.intro }
          f.lines = {}
      end,
      fill = function(f)
          local n = 0
          for k = 1, STEPS - 1 do
              for _, text in ipairs(steps[k].summary()) do
                  n = n + 1
                  local r = f.lines[n]
                  if not r then
                      r = CreateFrame("Frame", nil, f)
                      r:SetSize(CW, S.ROW_H)
                      r.text = W.Text(r, T.FONT.text, CW - S.CHANGE_W - T.LAYOUT.ITEM_GAP)
                      r.text:SetPoint("LEFT", 0, 0)
                      r.change = W.Button(r, L["Ändern##Knopf"], nil, function(self) ns.ShowSetup(self:GetParent().step) end,
                          { height = T.ROW_BUTTON_H })
                      W.FitChip(r.change, S.CHANGE_W, S.CHANGE_W)
                      r.change:SetPoint("RIGHT", 0, 0)
                      f.lines[n] = r
                  end
                  r.step = k
                  r.text:SetText(text)
                  r:Show()
              end
          end
          for i = n + 1, #f.lines do f.lines[i]:Hide() end
          f.parts = { f.intro }
          for i = 1, n do f.parts[#f.parts + 1] = f.lines[i] end
      end },
}

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function stepFrame(k)
    F.pages = F.pages or {}
    local f = F.pages[k]
    if not f then
        f = CreateFrame("Frame", nil, F.body)
        f:SetAllPoints(F.body)
        steps[k].build(f)
        F.pages[k] = f
    end
    return f
end

refresh = function()
    if not F or not F:IsShown() then return end
    local def = steps[step]
    F.stepText:SetText(L["Schritt %d von %d"]:format(step, STEPS))
    F.title:SetText(def.title)
    for k, f in pairs(F.pages or {}) do if k ~= step then f:Hide() end end
    local f = stepFrame(step)
    f:Show()
    if def.fill then def.fill(f) end
    for _, part in ipairs(f.parts) do
        if part.Fill then part:Fill() end
    end
    W.Column(f, f.parts, S.ROW_GAP, 0, 0)
    F.back:SetEnabled(step > 1)
    local last = step == STEPS
    F.skip:SetShown(not last)
    F.next:SetShown(not last)
    F.done:SetShown(last)
end

local function goTo(k)
    step = math.max(1, math.min(STEPS, k))
    say(nil)
    refresh()
end

local function finish()
    if DB then DB.setup.done = math.floor(time()) end
    F:Hide()
    ns.msg(L["Einrichtung fertig. Alles lässt sich unter Einstellungen ändern; /amisia einrichten öffnet sie wieder."])
end

local function build()
    F = W.Window("AmisiaSetupFrame", S.W, S.H, { title = L["Amisia einrichten"], strata = "FULLSCREEN_DIALOG",
        onShow = function(self) if self.Raise then self:Raise() end refresh() end })
    F:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    F.stepText = W.Text(F, T.FONT.hint, CW)
    F.stepText:SetPoint("TOPLEFT", PAD, -S.STEP_Y)
    F.title = W.Text(F, T.FONT.title, CW)
    F.title:SetPoint("TOPLEFT", PAD, -S.TITLE_Y)
    F.body = CreateFrame("Frame", nil, F)
    F.body:SetPoint("TOPLEFT", PAD, -S.BODY_Y)
    F.body:SetPoint("BOTTOMRIGHT", -PAD, S.BOTTOM + T.BUTTON_H + S.STATUS_GAP + S.LINE_H + S.STATUS_GAP)
    F.status = W.Text(F, T.FONT.text, CW)
    F.status:SetPoint("BOTTOMLEFT", PAD, S.BOTTOM + T.BUTTON_H + S.STATUS_GAP)
    F.status:SetHeight(S.LINE_H)
    F.back = W.Button(F, L["Zurück"], nil, function() goTo(step - 1) end)
    F.skip = W.Button(F, L["Überspringen"], nil, function() goTo(step + 1) end)
    F.next = W.Button(F, L["Weiter"], nil, function() goTo(step + 1) end)
    F.done = W.Button(F, L["Fertig"], nil, finish)
    for _, b in ipairs({ F.back, F.skip, F.next, F.done }) do W.FitChip(b, S.NAV_W) end
    W.Tooltip(F.skip, L["Überspringen"], L["Lässt diesen Schritt, wie er ist, und geht weiter."])
    F.back:SetPoint("BOTTOMLEFT", PAD, S.BOTTOM)
    F.next:SetPoint("BOTTOMRIGHT", -PAD, S.BOTTOM)
    F.done:SetPoint("BOTTOMRIGHT", -PAD, S.BOTTOM)
    F.skip:SetPoint("BOTTOMRIGHT", F.next, "BOTTOMLEFT", -T.LAYOUT.ITEM_GAP, 0)
end

-- Opens the setup at a step (1 when none); the values always come from the settings.
function ns.ShowSetup(k)
    if not F then build() end
    if offerFrame then offerFrame:Hide() end
    step = math.max(1, math.min(STEPS, tonumber(k) or 1))
    say(nil)
    if F:IsShown() then refresh() else F:Show() end
    return F
end

ns.Listen("SETTING", function() refresh() end)
ns.Listen("LOOT_RULES", function() refresh() end)

---------------------------------------------------------------------------
-- The offer at the first open of the main window after a login
---------------------------------------------------------------------------
local function buildOffer()
    local o = W.Window("AmisiaSetupOffer", S.OFFER_W, S.OFFER_H, { title = L["Amisia einrichten"], strata = "FULLSCREEN_DIALOG" })
    o.text = W.Text(o, T.FONT.body, S.OFFER_W - 2 * PAD, true)
    o.text:SetHeight(2 * S.LINE_H + 4)
    o.text:SetMaxLines(2)
    o.text:SetJustifyV("TOP")
    o.text:SetPoint("TOPLEFT", PAD, -S.OFFER_TEXT_Y)
    o.text:SetText(L["Amisia einrichten? Ein paar Schritte vor dem ersten Raid."])
    o.go = W.Button(o, L["Los"], nil, function() ns.ShowSetup(1) end)
    o.later = W.Button(o, L["Später"], nil, function() o:Hide() end)
    o.never = W.Button(o, L["Nicht mehr fragen"], nil, function()
        if DB then DB.setup.never = math.floor(time()) end
        o:Hide()
        ns.msg(L["Amisia fragt nicht mehr. /amisia einrichten startet die Einrichtung jederzeit."])
    end)
    for _, b in ipairs({ o.go, o.later }) do W.FitChip(b, S.NAV_W) end
    W.FitChip(o.never, S.NAV_W)
    W.Row(o, { o.go, o.later, o.never }, T.LAYOUT.ITEM_GAP, PAD, S.BOTTOM, { point = "BOTTOMLEFT" })
    return o
end

local function showOffer()
    offerFrame = offerFrame or buildOffer()
    offerFrame:ClearAllPoints()
    local main = _G.AmisiaFrame
    if main and main:IsShown() then
        offerFrame:SetPoint("CENTER", main, "CENTER", 0, 60)
    else
        offerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
    offerFrame:Show()
    return offerFrame
end

-- Once per login, at the first open of the main window: the offer, for an officer who has neither
-- finished the setup nor declined it. Returns whether it was shown.
function ns.SetupOfferCheck()
    if offered then return false end
    offered = true
    local st = ns.SetupState()
    if st.done or st.never or not officer() then return false end
    if F and F:IsShown() then return false end
    showOffer()
    return true
end

ns.Listen("MAIN_SHOWN", function() ns.SetupOfferCheck() end)
ns.OnEvent("PLAYER_LOGIN", function() offered = false end)

ns.RegisterSlash("einrichten", { en = "setup", officer = true,
    desc = L["Einrichtungshilfe: Bank, Lootleitung, Lootart, Roll-Dauer, erste Lootregeln"], run = function()
        if not officer() then
            ns.msg(L["Die Einrichtung ist für Offiziere. Für dich: Einstellungen, Würfel-Fenster."])
            return
        end
        ns.ShowSetup(1)
    end })

-- test hooks
ns._setup = {
    frame = function() return F end,
    offer = function() return offerFrame end,
    step = function() return step end,
    presets = PRESETS,
    addPreset = addPreset,
    showOffer = showOffer,
}
