-- The raid sign-up (D-42, Raid/Signup.lua) on screen: the card "Raid-Anmeldung" on the overview
-- (for everyone: the next three dates of the game calendar with the own sign-up, "noch offen"
-- where there is none) and the small window "Raid-Anmeldung" (AmisiaSignupFrame): the date, the own
-- state, the role T/H/N/F, a note of at most 40 characters and the buttons Anmelden, Vorläufig and
-- Abmelden. Raiders see only their own sign-ups (and those of their other characters); the list
-- of who signed up is the officers' lineup.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.SIGNUP
local PAD = T.WINDOW_PAD
local CW = S.W - 2 * PAD
local GREY, GREEN, ORANGE = T.GREY, T.GREEN, T.ORANGE

local F               -- the window, built on first use
local cur             -- the night chosen in the window
local role            -- the role chosen in the window

local STATE_COLOR = { A = GREEN, V = ORANGE, X = GREY }

local function colored(rec)
    local text = ns.SignupStateText(rec)
    local c = rec and STATE_COLOR[rec.s]
    return c and (c .. text .. "|r") or text
end

-- "Fr 20:00 Molten Core · angemeldet (H)"
local function termLine(t)
    return ("%s · %s"):format(ns.SignupTermText(t), colored(ns.SignupOf()[t.night]))
end

---------------------------------------------------------------------------
-- The card on the overview
---------------------------------------------------------------------------
ns.RegisterCard{ key = "signup", order = 15, available = function() return ns.Get("signup.card") ~= false end, fill = function(c)
    c.title:SetText(L["Raid-Anmeldung"])
    if not IsInGuild() then
        c.line1:SetText(L["Nur in einer Gilde"])
        return
    end
    if not ns.Cal.Available() then
        c.line1:SetText(L["Kalender nicht verfügbar."])
        return
    end
    local terms, loading = ns.SignupTerms()
    if not terms then
        c.line1:SetText(L["Termine werden gelesen ..."])
        -- on the next frame: an answer at once would refresh the page inside its own refresh
        if not loading then C_Timer.After(0, function() ns.SignupLoadTerms() end) end
        return
    end
    if #terms == 0 then
        c.line1:SetText(L["Keine Raidtermine in den nächsten 14 Tagen."])
        c.line2:SetText(L["Die Termine kommen aus dem Spielkalender (Gildenereignisse)."])
        return
    end
    c.line1:SetText(termLine(terms[1]))
    local more = {}
    for i = 2, math.min(3, #terms) do more[#more + 1] = termLine(terms[i]) end
    -- the other characters of the account, so nobody signs up twice (only while there is room)
    if #more < 2 then
        for _, a in ipairs(ns.SignupAlts(terms[1].night)) do
            if #more >= 2 then break end
            more[#more + 1] = ("%s: %s"):format(a.name, colored(a.rec))
        end
    end
    c.line2:SetText(table.concat(more, "\n"))
    -- "Ändern" when the player has a sign-up for the date the card shows first
    local first = terms[1].night
    c:SetAction(ns.SignupOf()[first] and L["Ändern##Anmeldung"] or L["Anmelden"], function() ns.ShowSignup(first) end)
    -- part I: who comes, for everyone in the guild
    c:SetAction2(L["Kalender"], function() ns.ShowRaidCalendar(first) end)
end }

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local refresh

local function termNow()
    local terms = ns.SignupTerms() or {}
    for _, t in ipairs(terms) do
        if t.night == cur then return t end
    end
    return nil
end

local function send(status)
    local t = termNow()
    if not t then return end
    local ok, line = ns.SignupSet(t, status, role, F.note:GetText(), { click = true })
    if line then ns.msg(line) end
    if ok then F.note:ClearFocus() end
    refresh()
end

local function build()
    F = W.Window("AmisiaSignupFrame", S.W, S.H, { title = L["Raid-Anmeldung"], strata = "DIALOG",
        onShow = function(self) if self.Raise then self:Raise() end refresh() end })
    F:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    -- "Kalender" beside the date picker: the raid calendar window (part I) at the chosen date
    F.calOpen = W.Button(F, L["Kalender"], S.CAL_OPEN_W, function() ns.ShowRaidCalendar(cur) end)
    local calW = W.FitChip(F.calOpen, S.CAL_OPEN_W)
    F.calOpen:SetPoint("TOPRIGHT", -PAD, -(S.PICK_Y - (T.BUTTON_H - T.FIELD_H) / 2))
    W.Tooltip(F.calOpen, L["Raid-Kalender"], L["Wer zu den Terminen kommt: angemeldet, vorläufig, abgemeldet, mit Rolle und Notiz."])
    F.pick = W.Picker(F, CW - calW - T.LAYOUT.ITEM_GAP, function(v)
        cur = v
        local rec = ns.SignupOf()[cur]
        role = rec and rec.r or role
        F.note:SetText(rec and rec.w or "")
        refresh()
    end)
    F.pick:SetPoint("TOPLEFT", PAD, -S.PICK_Y)
    F.state = W.Text(F, T.FONT.body, CW)
    F.state:SetPoint("TOPLEFT", PAD, -S.STATE_Y)
    F.roleLabel = W.Text(F, T.FONT.head, S.LABEL_W)
    F.roleLabel:SetText(L["Rolle"])
    F.roleLabel:SetHeight(T.CHIP_H)
    F.roleLabel:SetJustifyV("MIDDLE")
    F.roleLabel:SetPoint("TOPLEFT", PAD, -S.ROLE_Y)
    F.roles = {}
    local names = { T = L["Tank"], H = L["Heiler"], M = L["Nahkampf"], R = L["Fernkampf"] }
    for _, r in ipairs(ns.LINEUP_ROLES) do
        local b = W.Chip(F, ns.SIGNUP_ROLE_SHORT[r], S.ROLE_W, function()
            role = r
            refresh()
        end)
        b.role = r
        W.Tooltip(b, names[r])
        F.roles[#F.roles + 1] = b
    end
    W.Row(F, F.roles, T.CHIP_GAP, PAD + S.LABEL_W + S.LABEL_GAP, -S.ROLE_Y)
    F.noteLabel = W.Text(F, T.FONT.head, S.LABEL_W)
    F.noteLabel:SetText(L["Notiz"])
    F.noteLabel:SetHeight(T.FIELD_H)
    F.noteLabel:SetJustifyV("MIDDLE")
    F.noteLabel:SetPoint("TOPLEFT", PAD, -S.NOTE_Y)
    F.note = W.LineEdit(F, CW - S.LABEL_W - S.LABEL_GAP)
    if F.note.SetMaxBytes then F.note:SetMaxBytes(41) end
    if F.note.SetMaxLetters then F.note:SetMaxLetters(40) end
    F.note:SetPoint("TOPLEFT", PAD + S.LABEL_W + S.LABEL_GAP, -S.NOTE_Y)
    F.hint = W.Text(F, T.FONT.hint, CW - S.LABEL_W - S.LABEL_GAP)
    F.hint:SetPoint("TOPLEFT", PAD + S.LABEL_W + S.LABEL_GAP, -S.HINT_Y)
    F.hint:SetText(L["Für die Gilde lesbar."])
    F.alts = W.Text(F, T.FONT.hint, CW, true)
    F.alts:SetJustifyV("TOP")
    F.calHint = W.Text(F, T.FONT.text, CW - S.CAL_W - T.LAYOUT.ITEM_GAP, true)
    F.calHint:SetText(L["Bitte auch im Kalender eintragen."])
    F.calBtn = W.Button(F, L["Kalender öffnen"], S.CAL_W, function()
        if InCombatLockdown() then
            ns.msg(L["Im Kampf öffnet Amisia den Kalender nicht. Nach dem Kampf noch einmal."])
        elseif type(ToggleCalendar) == "function" then
            ToggleCalendar()
        end
    end)
    W.FitChip(F.calBtn, S.CAL_W)
    F.calHint:SetHeight(T.BUTTON_H)
    F.calHint:SetJustifyV("MIDDLE")
    -- the tooltip names why the calendar entry of the last click did not work
    F.calBtn:HookScript("OnEnter", function(self)
        local _, why = ns.SignupCalendarState(cur)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Kalender öffnen"], 1, 0.82, 0)
        GameTooltip:AddLine(why or L["Amisia hat dich nicht im Spielkalender eingetragen. Dort sehen es auch Spieler ohne Amisia."], 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    F.calBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    F.yes = W.Button(F, L["Anmelden"], S.BUTTON_W, function() send("A") end)
    F.maybe = W.Button(F, L["Vorläufig"], S.BUTTON_W, function() send("V") end)
    F.no = W.Button(F, L["Abmelden"], S.BUTTON_W, function() send("X") end)
    for _, b in ipairs({ F.yes, F.maybe, F.no }) do W.FitChip(b, S.BUTTON_W) end
    W.Row(F, { F.yes, F.maybe, F.no }, T.LAYOUT.ITEM_GAP, PAD, S.BOTTOM, { point = "BOTTOMLEFT" })
end

-- Compact: under the note hint only what is shown follows (the other characters, the calendar
-- hint), S.GAP apart; the window ends S.BOTTOM under the buttons, so no empty band stays between.
local function layout()
    local y = S.HINT_Y + S.LINE_H
    if F.alts:IsShown() then
        -- one line, two when the names do not fit the width
        local lines = (F.alts:GetStringWidth() or 0) > CW and 2 or 1
        F.alts:SetHeight(lines * S.LINE_H)
        F.alts:ClearAllPoints()
        F.alts:SetPoint("TOPLEFT", PAD, -(y + S.LINE_GAP))
        y = y + S.LINE_GAP + lines * S.LINE_H
    end
    if F.calHint:IsShown() then
        F.calHint:ClearAllPoints()
        F.calHint:SetPoint("TOPLEFT", PAD, -(y + S.GAP))
        F.calBtn:ClearAllPoints()
        F.calBtn:SetPoint("TOPRIGHT", -PAD, -(y + S.GAP))
        y = y + S.GAP + T.BUTTON_H
    end
    F:SetHeight(y + S.GAP + T.BUTTON_H + S.BOTTOM)
end

refresh = function()
    if not F or not F:IsShown() then return end
    local terms = ns.SignupTerms() or {}
    local values = {}
    for _, t in ipairs(terms) do values[#values + 1] = { value = t.night, text = ns.SignupTermText(t) } end
    F.pick:SetValues(values)
    if not termNow() then
        local t = ns.SignupNextTerm()
        cur = t and t.night or nil
    end
    F.pick:SetValue(cur)
    local t = termNow()
    local rec = t and ns.SignupOf()[t.night]
    role = role or (rec and rec.r) or ns.SignupDefaultRole()
    for _, b in ipairs(F.roles) do b:SetOn(b.role == role) end
    if not IsInGuild() then
        F.state:SetText(L["Nur in einer Gilde"])
    elseif not t then
        F.state:SetText(ns.SignupTerms() and L["Keine Raidtermine in den nächsten 14 Tagen."] or L["Termine werden gelesen ..."])
    else
        F.state:SetText(L["Deine Anmeldung: %s"]:format(colored(rec)))
    end
    local alts = {}
    for _, a in ipairs(t and ns.SignupAlts(t.night) or {}) do alts[#alts + 1] = ("%s: %s"):format(a.name, colored(a.rec)) end
    F.alts:SetText(#alts > 0 and (L["Deine anderen Charaktere: %s"]:format(table.concat(alts, ", "))) or "")
    F.alts:SetShown(#alts > 0)
    -- part H3: after a click whose calendar entry did not work (or with signup.calendar off) the
    -- player does it there; while the entry runs a grey line says so
    local pending = t ~= nil and ns.SignupCalendarState(t.night)
    local calendar = rec ~= nil and rec.k ~= "ok" and not pending
    F.calHint:SetText(pending and (T.GREY .. L["Wird im Spielkalender eingetragen ..."] .. "|r") or L["Bitte auch im Kalender eintragen."])
    F.calHint:SetShown(calendar or pending)
    F.calBtn:SetShown(calendar and type(ToggleCalendar) == "function")
    for _, b in ipairs({ F.yes, F.maybe, F.no }) do b:SetEnabled(t ~= nil) end
    layout()
end

-- Opens the window at night (default: the next date); the dates are read first when they are not.
function ns.ShowSignup(night)
    if not F then build() end
    if night then cur = night end
    local rec = cur and ns.SignupOf()[cur]
    role = rec and rec.r or nil
    F.note:SetText(rec and rec.w or "")
    if F:IsShown() then refresh() else F:Show() end
    if not ns.SignupTerms() then
        ns.SignupLoadTerms(function()
            local r2 = cur and ns.SignupOf()[cur]
            if r2 then F.note:SetText(r2.w or "") end
            refresh()
        end)
    end
    return F
end

ns.Listen("SIGNUP", function()
    refresh()
    if ns.CurrentPage and ns.CurrentPage() == "overview" and ns.Refresh then ns.Refresh() end
end)

-- for the tests
ns._signupUI = { frame = function() return F end }
