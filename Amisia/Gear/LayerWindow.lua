-- The window "Layer" (F-185, D-117, F-214, ns.LayerWindow, AmisiaLayerFrame, tokens T.LAYER) and the layer
-- chip (AmisiaLayerChip, layer.chip). The window: "Dein Layer", large the current layer ("Layer B", else
-- "unbekannt"), grey under it "Kennung <zoneUID> · <zone>" or "Ziele oder überfahre einen NPC.";
-- "Gesehen in dieser Zone" with a row per layer of the zone ("Layer A · hier · vor 3 Min.", "Gilde" for one
-- only the guild reported), a row of another layer a button (SW.Swap(uid)); two rows with a symbol, "Im
-- Gildenchat fragen" (only in a guild) and "Im Kanal fragen" (players outside the guild, F-191); the red
-- buttons "Layer wechseln" (SW.Swap; "Warte ...", "Im Kanal fragen" by SW.SwapStep) and "Helfen: AN/AUS"
-- (SW.SetHosting) with a grey line under them and the green count "Geholfen: ..." (SW.Helped); a status
-- line, the answers ("Name · Layer C" with the link "Einladung erbitten") and "Gruppe verlassen" once a swap
-- group stands (Gear/LayerChange.lua). Movable, its place in settings.layerWindow, the x closes it; never
-- shown in an instance (it closes on entering one).
-- Opened by /amisia layer, the minimap menu (its own entry) and its row in the side bar of the tab Gilde.
-- The client's "-" left of the x folds it to the bar AmisiaLayerMiniBar (F-204): the window's symbol, the
-- layer ("Layer B", "Layer ?") over a grey line (the zone, "Antworten: 2" while answers wait, "Ziele einen
-- NPC an." while the layer is unknown); a click opens the window again with its top right corner where the
-- bar's is, the x closes the bar, a right click opens a menu ("Layer wechseln", "Helfen an/aus", "Fenster
-- öffnen"). While an own swap runs the grey line tells its stage, else the zone with a green " · Helfen"
-- while helping is on (F-214). Folded, it stays through /reload (settings.layerWindow.mini, the bar on the
-- window's place); hidden in instances.
-- F-216: "Layer wechseln" also asks the zone; the grey line "Erreicht: n · gehört: m · auf anderem Layer: k"
-- (LW.ZoneText) under the status; the button "Weiter fragen: <class>" while another click reaches new players;
-- the grey line under the buttons names an invite pause; the bar's symbol gold while helping, grey with helping
-- off, green while an own search runs (LW.MiniState); in an instance the bar names the place instead of
-- vanishing; its right click menu lists the known layers to swap to and "Suche stoppen". /amisia layer swap
-- [B|neu], gilde, stopp, helfen, kick (LW.Command).
-- F-220: the world restart (LY.RefreshText: "Neustart in 4:12", then "Neustart gleich") in the grey line under
-- the buttons (helping pauses meanwhile) and in the bar's grey line; the bar on one line (layer.barOneLine:
-- "Layer B · Wald von Elwynn", MINI_ONE_H high) and its ground as dark as layer.barShade (percent).
-- The chip: a small box "Layer B" ("Layer ?"), movable (settings.layerChip), a click opens the window;
-- hidden in instances. A plain frame, nothing protected.
-- F-221 (D-146): the red button by SW.SwapStep: "Layer wechseln", "Suche stoppen" (from its first second on),
-- "Gruppe verlassen", "Verlassen und neu fragen", "Weiter fragen: <Klasse>", "Im Kanal fragen" (SW.Press);
-- "Helfen: AN 3:41" while the lock runs, "Helfen: PAUSIERT" (grey, still a switch) with the reason in the grey
-- line, a refused "off" says there "Helfen bleibt noch 3:41 an."; every row of another layer is a button, the one
-- asked for says "fragt ..."; in an instance the window says "Keine Layer in <Instanz>". The bar stands by itself
-- (layer.bar, on; its place settings.layerBar): line 1 the layer, line 2 the state (LW.MiniSub); a click opens or
-- closes the window, a right click on its symbol the layers of the zone (LW.MiniMenu), elsewhere it hides the bar
-- (layer.bar off). /amisia layer an, aus, status.
-- F-229 (D-159): no lock on "Helfen" any more. The red button says why no ask goes ("Warten 12:34" for the game's
-- hourly limit, "Im Kampf", "Kampf 0:04", "Tot", "Im Flug"; disabled) and counts the last moves of the hour
-- ("Layer wechseln (noch 3)"). Where the numbers are private (LY.Private) the list "Gesehen in dieser Zone" is
-- gone; in its place the event field (SW.Event): a symbol, a heading in its colour with a time at the right, a few
-- lines and the hour's moves as ten squares, empty while nothing happens. The key binding "Layer wechseln"
-- (Bindings.xml of the core, AmisiaLayerKey) presses the red button.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.LAYER
local LY, SW = ns.Layer, ns.LayerChange

local LW = {}
ns.LayerWindow = LW

local F, chip, mini
local styleMini
local GREY, GREEN = T.GREY, T.GREEN

local function state(key)
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings[key]) ~= "table" then AmisiaDB.settings[key] = {} end
    return AmisiaDB.settings[key]
end

local function place()
    if F then W.PlaceWindow(F, state("layerWindow"), "RIGHT", UIParent, "RIGHT", -60, 220) end
    if chip then W.PlaceWindow(chip, state("layerChip"), "TOP", UIParent, "TOP", 0, -120) end
    if mini then W.PlaceWindow(mini, state("layerBar"), "TOP", UIParent, "TOP", 0, -160) end
end

-- The place's name in an instance (the bar's first line there, the window's "Keine Layer in ...").
local function placeName()
    local f = rawget(_G, "GetInstanceInfo")
    local ok, name = false, nil
    if type(f) == "function" then ok, name = pcall(f) end
    name = ok and ns.Plain(name) or nil
    return type(name) == "string" and name ~= "" and name or L["Instanz"]
end

-- A frame on UIParent with its top right corner at right, top (UIParent's coordinates), anchored to
-- UIParent's top right so that W.PlaceWindow puts it back there.
local function topRightAt(f, right, top)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", right - UIParent:GetRight(), top - UIParent:GetTop())
end

local function zoneName(zone)
    local info = zone and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(zone)
    return type(info) == "table" and ns.Plain(info.name) or ""
end

function ns.ResetLayerPosition()
    for _, key in ipairs({ "layerWindow", "layerChip", "layerBar" }) do
        local a = state(key)
        if a then a.point, a.x, a.y = nil, nil, nil end
    end
    place()
end

local function say(ok, why) if not ok and why then ns.msg(why) end end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function buildAnswer()
    local r = CreateFrame("Frame", nil, F)
    r:SetSize(S.W - 2 * S.PAD, S.ANSWER_H)
    r.text = W.Text(r, T.FONT.text, S.NAME_W)
    r.text:SetPoint("LEFT", 0, 0)
    r.link = W.Link(r, L["Einladung erbitten"], function()
        if r.name then say(SW.RequestInvite(r.name)) end
    end)
    r.link:SetPoint("RIGHT", 0, 0)
    W.Tooltip(r.link, L["Einladung erbitten"], L["Bittet dieses Gildenmitglied, dich in seine Gruppe einzuladen; die Einladung bringt dich auf seinen Layer."])
    return r
end

-- The minimize button (as the main window's, D-71, D-84): the client's red "-" (UIPanelHideButtonNoScripts)
-- left of the close button with the frame's corner art for two buttons; without the template the old
-- client's smaller-window button.
local function buildMinButton()
    local modern = F.NineSlice ~= nil
    local ok, b = pcall(CreateFrame, "Button", nil, F, "UIPanelHideButtonNoScripts")
    if not ok or not b then
        b = CreateFrame("Button", nil, F)
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Highlight", "ADD")
    end
    local size = modern and S.MIN or S.MIN_OLD
    b:SetSize(size, size)
    if F.CloseButton and modern then
        b:SetPoint("TOPRIGHT", F.CloseButton, "TOPLEFT", 0, -1)
        if F.SetBorder then
            if not pcall(F.SetBorder, F, "ButtonFrameTemplateNoPortraitMinimizable") then
                pcall(F.SetBorder, F, "ButtonFrameTemplateNoPortrait")
            end
        end
    elseif F.CloseButton then
        b:SetPoint("RIGHT", F.CloseButton, "LEFT", 0, 0)
    else
        b:SetPoint("TOPRIGHT", -S.MIN, 0)
    end
    b:SetScript("OnClick", function() LW.Minimize() end)
    W.Tooltip(b, L["Minimieren"], L["Klappt das Fenster zu einer kleinen Leiste zusammen; ein Klick darauf öffnet es wieder."])
    return b
end

-- A row of "Gesehen in dieser Zone": a button with its text; a click on another layer's row asks for it.
local function buildSeen()
    local r = CreateFrame("Button", nil, F)
    r:SetSize(S.W - 2 * S.PAD, S.ROW_H)
    r.text = W.Text(r, T.FONT.text, S.W - 2 * S.PAD)
    r.text:SetPoint("LEFT", 0, 0)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, S.HOVER)
    r:SetScript("OnClick", function(self) if self.uid then say(SW.Swap(self.uid)) end end)
    r:SetScript("OnEnter", function(self)
        if not self.uid or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.name or L["Layer"])
        GameTooltip:AddLine(L["Klick: fragen, wer auf %s ist, und dorthin wechseln."]:format(self.name or "?"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return r
end

-- A row with a symbol, a gold title and a grey line under it; a click runs fn.
local function buildAskRow(art, title, line, tip, fn)
    local r = CreateFrame("Button", nil, F)
    r:SetSize(S.W - 2 * S.PAD, S.ASK_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(S.ASK_ICON, S.ASK_ICON)
    r.icon:SetPoint("LEFT", 0, 0)
    if art and art.file then r.icon:SetTexture(art.file) else r.icon:Hide() end
    r.title = W.Text(r, T.FONT.head, S.W - 2 * S.PAD - S.ASK_TEXT_X)
    r.title:SetPoint("TOPLEFT", S.ASK_TEXT_X, -S.ASK_TITLE_Y)
    r.title:SetText(title)
    r.line = W.Text(r, T.FONT.hint, S.W - 2 * S.PAD - S.ASK_TEXT_X)
    r.line:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -S.ASK_LINE_GAP)
    r.line:SetText(line)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, S.HOVER)
    r:SetScript("OnClick", function() say(fn()) end)
    W.Tooltip(r, title, tip)
    return r
end

local function build()
    if F then return F end
    F = W.Window("AmisiaLayerFrame", S.W, S.TOP + S.BOTTOM, { title = L["Layer"], strata = "MEDIUM",
        onDragStop = function(f) W.SaveWindowPlace(f, state("layerWindow")) end,
        -- its row in the side bar of the tab Gilde lights while it is open (D-68)
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end })
    F.head = W.Text(F, T.FONT.head, S.W - 2 * S.PAD - S.SET_W)
    F.head:SetText(L["Dein Layer"])
    F.head:SetPoint("TOPLEFT", S.PAD, -S.TOP)
    -- the way to its switches (D-166): the section "Layer: Helfen"
    F.settings = W.SettingsLink(F, "layer")
    F.settings:SetPoint("RIGHT", F, "TOPRIGHT", -S.PAD, -(S.TOP + S.HEAD_H / 2))
    F.value = W.Text(F, T.FONT.big, S.W - 2 * S.PAD)
    F.value:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.HEAD_H))
    F.sub = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.sub:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.HEAD_H + S.VALUE_H))
    F.seenHead = W.Text(F, T.FONT.head, S.W - 2 * S.PAD)
    F.seenHead:SetText(L["Gesehen in dieser Zone"])
    F.seen = {}
    for i = 1, S.ROWS do F.seen[i] = buildSeen() end
    F.more = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    -- F-229: the event field
    F.ev = CreateFrame("Frame", nil, F)
    F.ev:SetWidth(S.W - 2 * S.PAD)
    F.ev.icon = F.ev:CreateTexture(nil, "ARTWORK")
    F.ev.icon:SetSize(S.EV_ICON, S.EV_ICON)
    F.ev.icon:SetPoint("TOPLEFT", 0, 0)
    F.ev.head = W.Text(F.ev, T.FONT.head, S.W - 2 * S.PAD - S.EV_TEXT_X - S.EV_TAG_W)
    F.ev.head:SetPoint("TOPLEFT", S.EV_TEXT_X, 0)
    F.ev.tag = W.Text(F.ev, T.FONT.head, S.EV_TAG_W)
    F.ev.tag:SetPoint("TOPRIGHT", 0, 0)
    F.ev.tag:SetJustifyH("RIGHT")
    F.ev.body = W.Text(F.ev, T.FONT.hint, S.W - 2 * S.PAD - S.EV_TEXT_X, true)
    F.ev.body:SetJustifyV("TOP")
    F.ev.pips = {}
    for i = 1, S.EV_PIPS do
        local pip = F.ev:CreateTexture(nil, "ARTWORK")
        pip:SetSize(S.EV_PIP, S.EV_PIP)
        F.ev.pips[i] = pip
    end
    F.ev:Hide()
    F.guildRow = buildAskRow(T.TAB_ICONS.guild, L["Im Gildenchat fragen"], L["Der Gildenchat erreicht jeden Layer."],
        L["Öffnet den Gildenchat mit deiner Bitte (Einstellung \"Text für Im Gildenchat fragen\"); du schickst sie mit Enter ab. So erreichst du Gildenmitglieder mit anderen Layer-Addons. Eine Minute lang nimmt Amisia dann die Einladung eines Gildenmitglieds an."],
        function() return SW.AskChat() end)
    F.channelRow = buildAskRow(T.NAV_ICONS.calls, L["Im Kanal fragen"], L["Erreicht alle Spieler der Zone, mit und ohne Addon."],
        L["Öffnet den Chatkanal aus den Einstellungen (Layer: Kanal, sonst 1, meist Allgemein) mit deiner Bitte; du schickst sie mit Enter ab. So erreichst du alle Spieler der Zone, mit und ohne Layer-Addon. Eine Minute lang nimmt Amisia dann die nächste Einladung an, egal von wem."],
        function() return SW.AskChannel() end)
    F.swap = W.Button(F, L["Layer wechseln"], S.BTN_W, function()
        say(SW.Press())
        LW.Refresh()
    end)
    W.Tooltip(F.swap, L["Layer wechseln"], L["Fragt die Spieler der Zone und die Gilde, wer auf einem anderen Layer ist und dich einladen kann; die erste Einladung bringt dich hinüber, nach 8 Sekunden ohne Einladung endet die Frage. Während die Frage läuft, stoppt ein Klick sie; in der Gruppe des Helfers verlässt ein Klick die Gruppe. Nicht im Kampf, tot oder im Flug; das Spiel erlaubt zehn Wechsel je Stunde. Nur wer allein ist, kann eingeladen werden. Eine Taste dafür: Tastenbelegung, AddOns, Amisia."])
    F.host = W.Button(F, L["Helfen: AN"], S.BTN_W, function()
        SW.SetHosting(not SW.Hosting())
        LW.Refresh()
    end)
    W.Tooltip(F.host, L["Helfen"], L["An: Amisia beantwortet Layer-Fragen und lädt Fragende ein, wie unter \"Einstellungen\" oben rechts eingestellt. Aus: Amisia antwortet niemandem und lädt niemanden ein, bis du es wieder anschaltest oder dich neu einloggst; über /reload bleibt es aus."])
    F.hostInfo = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD, true)
    F.hostInfo:SetJustifyV("TOP")
    F.helped = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD, true)
    F.helped:SetJustifyV("TOP")
    F.zone = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD, true)
    F.zone:SetJustifyV("TOP")
    F.status = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD, true)
    F.status:SetHeight(2 * S.LINE_H)
    F.status:SetJustifyV("TOP")
    F.answers = {}
    for i = 1, S.ANSWERS do F.answers[i] = buildAnswer() end
    F.minBtn = buildMinButton()
    local acc = 0
    F:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate LayerWindow", function(_, elapsed)
        acc = acc + (elapsed or 0)
        -- the world restart's countdown, a running search and (F-229) a wait every second
        if acc < (LW.Ticking() and 1 or S.TICK) then return end
        acc = 0
        LW.Refresh()
    end))
    place()
    return F
end

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------
-- The grey line under the layer: "Kennung 105 · Un'Goro-Krater" (a long zone is cut, never the number).
function LW.SubText(uid, zone)
    if zone and zone ~= "" then return L["Kennung %s · %s"]:format(tostring(uid), zone) end
    return L["Kennung %s"]:format(tostring(uid))
end

-- Whether the window and the bar count every second: the world restart, a running search, a wait (F-229).
function LW.Ticking()
    return (LY.Refresh() or SW.OwnAsk() or SW.CapLeft() > 0 or SW.FightLeft()) and true or false
end

-- The red button's word for SW.SwapStep's step (with nextClass: what another search asks; age: seconds the
-- running search has run), and whether it is enabled (F-221: "Suche stoppen" from its first second on). F-229:
-- st (SW.State, optional): why no ask may go now, and the moves left in the hour.
function LW.SwapLabel(step, nextClass, age, st)
    if step == "stop" then return L["Suche stoppen"], (age or SW.STOP_GUARD) >= SW.STOP_GUARD end
    if step == "leave" then return L["Gruppe verlassen"], true end
    if step == "leaveAsk" then return L["Verlassen und neu fragen"], true end
    if st and st.blocked then
        local _, kind = SW.Blocked()
        if kind == "cap" then return L["Warten %s"]:format(SW.Clock(SW.CapLeft())), false end
        if kind == "fight" then
            local left = SW.FightLeft()
            if left == true then return L["Im Kampf"], false end
            return L["Kampf %s"]:format(SW.Clock(left or 0)), false
        end
        if kind == "dead" then return L["Tot"], false end
        if kind == "taxi" then return L["Im Flug"], false end
    end
    if step == "more" and nextClass then return L["Weiter fragen: %s"]:format(nextClass), true end
    if step == "channel" then return L["Im Kanal fragen"], true end
    local left = st and SW.CAP - (st.capUsed or 0)
    if left and left > 0 and left <= SW.CAP_WARN and step ~= "busy" then
        return L["Layer wechseln (noch %d)"]:format(left), true
    end
    return L["Layer wechseln"], step ~= "busy"
end

-- The word on "Helfen" (F-221): "PAUSIERT" (grey) while it waits, "AN", "AUS".
function LW.HostLabel(st)
    if not st.hosting then return L["Helfen: AUS"] end
    if st.why then return GREY .. L["Helfen: PAUSIERT"] .. "|r" end
    return L["Helfen: AN"]
end

-- The grey line under the buttons: helping on or off, paused, or waiting out the invite limit (pause seconds);
-- refresh: the world restart's text (F-220); why: the pause's reason.
function LW.HostText(on, helping, pause, refresh, why)
    if not on then return L["Helfen aus: Amisia antwortet niemandem und lädt niemanden ein, bis du es wieder anschaltest oder dich neu einloggst."] end
    if refresh then return L["%s: Helfen lädt bis nach dem Neustart der Welt niemanden ein."]:format(refresh) end
    if (tonumber(pause) or 0) > 0 then
        return L["Helfen an, Pause: sechs Einladungen in zehn Minuten, die nächste in %d Min."]:format(math.ceil(pause / 60))
    end
    if why then return L["Helfen pausiert: %s."]:format(why) end
    if helping == false then return L["Helfen an, gerade pausiert (im Kampf oder in der Gruppensuche)."] end
    return L["Helfen an: Amisia lädt Fragende ein, wie unter \"Einstellungen\" oben rechts eingestellt. Aus gilt bis zum Ausloggen."]
end

-- The grey line of the zone search, nil without one.
function LW.ZoneText(z)
    if not z then return nil end
    local text = L["Erreicht: %d · gehört: %d · auf anderem Layer: %d"]:format(z.reached or 0, z.heardN or 0, z.other or 0)
    if z.err then return text .. "\n" .. z.err end
    if z.waiting then return L["Fragt das Spiel nach den Spielern der Zone ..."] end
    return text
end

-- The green count of this session's helping, nil while nothing happened.
function LW.HelpedText(h)
    if not h or (h.asked == 0 and h.invited == 0 and h.joined == 0) then return nil end
    return GREEN .. L["Geholfen: %d haben gefragt, %d eingeladen, %d gekommen."]:format(h.asked, h.invited, h.joined) .. "|r"
end

-- The status line of the swap and whether the swap's group stands (its button leaves it).
function LW.StatusText(st)
    local s, p, r, a, z = st.swap, st.pending, st.req, st.auto, st.zone
    if s then
        if s.changed and LY.Private() then return GREEN .. L["Gewechselt auf einen anderen Layer."] .. "|r", true end
        if s.changed then return GREEN .. L["Gewechselt: %s"]:format(LY.Name(s.map, s.target)) .. "|r", true end
        if s.refused then return L["Das Spiel hat dich nicht bewegt (zehn Wechsel je Stunde)."], true end
        if s.sameMark then return L["%s stand auf deinem Layer: kein Wechsel verbraucht."]:format(s.host), true end
        if s.elsewhere then return L["%s war in einer anderen Zone: kein Wechsel."]:format(s.host), true end
        if s.failed then return L["Kein Wechsel: der Layer ist derselbe geblieben."], true end
        if s.unknown then return L["Dein Layer war vor der Anfrage unbekannt: ob du gewechselt hast, ist nicht zu sehen."], true end
        if s.moved then return L["Das Spiel hat dich bewegt; Amisia liest den neuen Layer ..."], true end
        if LY.Private() then return L["In der Gruppe mit %s: das Spiel bewegt dich gleich ..."]:format(s.host), true end
        return L["In der Gruppe mit %s: ziele einen NPC an, sobald du gewechselt bist."]:format(s.host), true
    end
    if st.warning then return st.warning, false end
    if p then
        if p.chat then return L["Einladung von %s kam."]:format(p.name), false end
        if p.invited then return L["Einladung von %s kam."]:format(p.name), false end
        return L["Einladung bei %s erbeten."]:format(p.name), false
    end
    if st.chatAll then return L["Im Kanal gefragt: eine Minute lang nimmt Amisia die nächste Einladung an."], false end
    if st.chat then return L["Im Gildenchat gefragt: eine Minute lang nimmt Amisia die Einladung eines Gildenmitglieds an."], false end
    if a and r and GetTime() - r.at <= SW.REQ_LIFE then
        if st.step ~= "stop" then
            -- F-221: the search ended without an invite
            if z and z.full then
                return L["Niemand auf einem anderen Layer hat geantwortet. Die Wer-Liste war voll: ein weiterer Klick erreicht andere Spieler."], false
            end
            if z and (z.reached or 0) > 0 and (z.heardN or 0) == 0 then
                return L["Niemand in der Zone hat geantwortet: hier nutzt wohl niemand ein Layer-Addon. Versuch es in einer belebteren Zone."], false
            end
            if st.zoneNext then return L["Niemand auf einem anderen Layer hat geantwortet. Klick noch einmal, um mehr Spieler zu fragen."], false end
            if a.target then return L["Niemand aus der Gilde auf %s. Frag im Kanal."]:format(LY.Name(r.map, a.target)), false end
            return L["Keine Antwort von einem anderen Layer: frag im Kanal."], false
        end
        if #st.answers > 0 then return L["Antworten von anderen Layern: %d"]:format(#st.answers), false end
        if z and (z.reached or 0) > 0 then
            return L["An %d Spieler gesendet (%s): warte auf eine Einladung ..."]:format(z.reached, SW.Clock(GetTime() - r.at)), false
        end
        return L["Gefragt, warte auf Antworten ..."], false
    end
    local blockedWhy = st.blocked
    if blockedWhy then return blockedWhy, false end
    local ok, why = SW.CanAsk()
    -- without a guild the channel is the way: its reason would only name the guild
    if not ok and not ns.InGuild() then return L["Frag im Kanal: wer dich einlädt, bringt dich auf seinen Layer."], false end
    if not ok then return why, false end
    return L["Frag die Gilde, wer auf einem anderen Layer ist."], false
end

-- The height a wrapping text takes: the client's, at least its width over the line's in LINE_H lines.
local function textHeight(fs)
    local h = tonumber(fs:GetStringHeight()) or 0
    local lines = math.ceil((tonumber(fs:GetStringWidth()) or 0) / (S.W - 2 * S.PAD))
    return math.max(S.LINE_H, math.ceil(h), lines * S.LINE_H)
end

-- F-229: the event field at y (the list's place), filled from SW.Event's e; empty (hidden) while nothing happens.
-- Returns the y under it.
function LW.FillEvent(e, y)
    local ev = F.ev
    if not e then
        ev:Hide()
        return y
    end
    local col = S.EV_COL[e.col] or S.EV_COL.info
    ev.icon:SetTexture(S.EV_TEX[e.col] or S.EV_TEX.info)
    ev.head:SetText(col .. (e.head or "") .. "|r")
    ev.tag:SetText(e.tag and (col .. e.tag .. "|r") or "")
    ev.body:SetHeight(0)
    ev.body:SetText(e.body or "")
    ev.body:ClearAllPoints()
    ev.body:SetPoint("TOPLEFT", S.EV_TEXT_X, -S.HEAD_H)
    local h = textHeight(ev.body)
    ev.body:SetHeight(h)
    local pipY = -(S.HEAD_H + h + S.GAP / 2)
    local used = tonumber(e.used) or 0
    for i, pip in ipairs(ev.pips) do
        local c = i <= used and S.EV_PIP_ON or S.EV_PIP_OFF
        pip:SetColorTexture(c[1], c[2], c[3], c[4])
        pip:ClearAllPoints()
        pip:SetPoint("TOPLEFT", S.EV_TEXT_X + (i - 1) * (S.EV_PIP + S.EV_PIP_GAP), pipY)
    end
    local total = S.HEAD_H + h + S.GAP / 2 + S.EV_PIP
    ev:SetHeight(total)
    ev:ClearAllPoints()
    ev:SetPoint("TOPLEFT", S.PAD, y)
    ev:Show()
    return y - total
end

function LW.Refresh()
    if not F or not F:IsShown() then return end
    local uid, _, name = LY.Current()
    local zone = LY.Map()
    -- F-221: in an instance the window stays and says so
    local inside = LY.InInstance()
    local st = SW.State()
    if inside then
        F.value:SetText(L["Keine Layer in %s"]:format(placeName()))
        F.sub:SetText(L["In Instanzen gibt es keine Layer."])
    elseif uid then
        F.value:SetText(name)
        F.sub:SetText(LW.SubText(uid, zoneName(zone)))
    else
        F.value:SetText(L["unbekannt"])
        F.sub:SetText(L["Ziele oder überfahre einen NPC."])
    end
    local y = -(S.TOP + S.HEAD_H + S.VALUE_H + S.LINE_H + S.GAP)
    F.seenHead:ClearAllPoints()
    F.seenHead:SetPoint("TOPLEFT", S.PAD, y)
    if not (LY.Private() and not inside) then y = y - S.HEAD_H end
    -- F-229: where the numbers are private the event field takes the list's place
    local private = LY.Private() and not inside
    local list = (inside or private) and {} or LY.List(zone)
    local asked = st.step == "stop" and st.auto and st.auto.target or nil
    for i, r in ipairs(F.seen) do
        local e = list[i]
        if e then
            local parts = { e.name }
            if e.current then parts[#parts + 1] = L["hier"] end
            if not e.own then parts[#parts + 1] = L["Gilde"] end
            if asked == e.uid then parts[#parts + 1] = L["fragt ..."] end
            parts[#parts + 1] = LY.Age(e.age)
            r.text:SetText((e.current and "" or GREY) .. table.concat(parts, " · ") .. (e.current and "" or "|r"))
            -- another layer's row asks for it (F-221: for everyone, the zone too); the own one is no button
            r.uid, r.name = (not e.current) and e.uid or nil, e.name
            r:EnableMouse(r.uid ~= nil)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", S.PAD, y)
            r:Show()
            y = y - S.ROW_H
        else
            r.uid, r.name = nil, nil
            r:Hide()
        end
    end
    if inside or private then
        F.more:SetText("")
    elseif #list == 0 then
        F.more:SetText(L["Noch keiner."])
    elseif #list > #F.seen then
        F.more:SetText(L["und %d weitere"]:format(#list - #F.seen))
    else
        F.more:SetText("")
    end
    F.more:SetShown(F.more:GetText() ~= "")
    if F.more:IsShown() then
        F.more:ClearAllPoints()
        F.more:SetPoint("TOPLEFT", S.PAD, y)
        y = y - S.ROW_H
    end
    if private then y = LW.FillEvent(st.event, y) else F.ev:Hide() end
    y = y - S.GAP
    local guild = ns.InGuild() and not inside
    F.seenHead:SetShown(not inside and not private)
    F.guildRow:SetShown(guild and true or false)
    if guild then
        F.guildRow:ClearAllPoints()
        F.guildRow:SetPoint("TOPLEFT", S.PAD, y)
        y = y - S.ASK_H
    end
    F.channelRow:SetShown(not inside)
    if not inside then
        F.channelRow:ClearAllPoints()
        F.channelRow:SetPoint("TOPLEFT", S.PAD, y)
        y = y - S.ASK_H - S.GAP
    end
    local label, enabled = LW.SwapLabel(st.step, st.zoneNext, st.age, st)
    F.swap:SetText(label)
    if enabled and not (inside and st.step ~= "leave" and st.step ~= "leaveAsk") then F.swap:Enable() else F.swap:Disable() end
    F.host:SetText(LW.HostLabel(st))
    W.Row(F, { F.swap, F.host }, S.GAP, S.PAD, y)
    y = y - T.BUTTON_H - S.GAP
    F.hostInfo:SetHeight(0)
    F.hostInfo:SetText(LW.HostText(st.hosting, st.helping, st.pause, st.refresh, st.why))
    F.hostInfo:ClearAllPoints()
    F.hostInfo:SetPoint("TOPLEFT", S.PAD, y)
    local h = textHeight(F.hostInfo)
    F.hostInfo:SetHeight(h)
    y = y - h - S.GAP
    local helped = LW.HelpedText(st.helped)
    F.helped:SetShown(helped ~= nil)
    if helped then
        F.helped:SetHeight(0)
        F.helped:SetText(helped)
        F.helped:ClearAllPoints()
        F.helped:SetPoint("TOPLEFT", S.PAD, y)
        h = textHeight(F.helped)
        F.helped:SetHeight(h)
        y = y - h - S.GAP
    end
    local zoneText = LW.ZoneText(st.zone)
    F.zone:SetShown(zoneText ~= nil)
    if zoneText then
        F.zone:SetHeight(0)
        F.zone:SetText(zoneText)
        F.zone:ClearAllPoints()
        F.zone:SetPoint("TOPLEFT", S.PAD, y)
        h = textHeight(F.zone)
        F.zone:SetHeight(h)
        y = y - h - S.GAP
    end
    local text = LW.StatusText(st)
    F.status:SetText(text or "")
    F.status:ClearAllPoints()
    F.status:SetPoint("TOPLEFT", S.PAD, y)
    y = y - 2 * S.LINE_H
    local showAnswers = not st.swap and not st.pending
    for i, r in ipairs(F.answers) do
        local a = showAnswers and st.answers[i]
        if a then
            r.name = a.name
            r.text:SetText(("%s · %s"):format(a.name, a.layer) .. (a.seen and "" or (" " .. GREEN .. L["neu"] .. "|r")))
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", S.PAD, y)
            r:Show()
            y = y - S.ANSWER_H
        else
            r.name = nil
            r:Hide()
        end
    end
    F:SetHeight(-y + S.BOTTOM)
end

function LW.Show()
    local st = state("layerWindow")
    if st then st.mini = nil end
    build()
    F:Show()
    LW.Refresh()
    LW.UpdateBar()
    return true
end

function LW.Hide() if F then F:Hide() end end
function LW.Shown() return F ~= nil and F:IsShown() end
function LW.Toggle()
    if LW.Shown() then LW.Hide() else LW.Show() end
end

---------------------------------------------------------------------------
-- The bar (F-204; F-221: a bar of its own, layer.bar)
---------------------------------------------------------------------------
-- Whether the bar is wanted: layer.bar, or the window folded to it (settings.layerWindow.mini).
local function barWanted()
    local st = state("layerWindow")
    return ns.Get("layer.bar") ~= false or (st ~= nil and st.mini == true)
end

-- Hides the bar for good: layer.bar off and the window no longer folded.
local function hideBar()
    local st = state("layerWindow")
    if st then st.mini = nil end
    if mini then mini:Hide() end
    if ns.Get("layer.bar") ~= false then
        ns.Set("layer.bar", false)
        ns.msg(L["Leiste Layer ausgeblendet; Einstellungen, Layer: Anzeige, \"Leiste zeigen\" bringt sie zurück."])
    end
end

local function buildMini()
    if mini then return mini end
    local ok, bar = pcall(CreateFrame, "Button", "AmisiaLayerMiniBar", UIParent, "TooltipBackdropTemplate")
    if not ok or not bar then
        bar = CreateFrame("Button", "AmisiaLayerMiniBar", UIParent)
        bar.flat = W.Flat(bar, 0.05, 0.05, 0.06, 0.95)
    end
    bar:SetSize(S.MINI_W, S.MINI_H)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    -- a drag is no click (moved, cleared at every press)
    bar:SetScript("OnMouseDown", function(self) self.moved = nil end)
    bar:SetScript("OnDragStart", function(self) self.moved = true self:StartMoving() end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        W.SaveWindowPlace(self, state("layerBar"))
    end)
    bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar:SetScript("OnClick", function(self, button)
        if self.moved then self.moved = nil return end
        if button == "RightButton" then return hideBar() end
        LW.Restore()
    end)
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(S.MINI_ICON, S.MINI_ICON)
    bar.icon:SetPoint("LEFT", S.MINI_ICON_X, 0)
    local art = T.NAV_ICONS["win:layer"]
    if art and art.file then bar.icon:SetTexture(art.file) else bar.icon:Hide() end
    -- the symbol: a right click lists the zone's layers
    bar.iconBtn = CreateFrame("Button", nil, bar)
    bar.iconBtn:SetAllPoints(bar.icon)
    bar.iconBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar.iconBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return W.Menu(bar, LW.MiniMenu()) end
        LW.Restore()
    end)
    W.Tooltip(bar.iconBtn, L["Layer"], L["Klick: das Fenster Layer. Rechtsklick: die Layer dieser Zone, Layer wechseln, Helfen an oder aus."])
    bar.name = W.Text(bar, T.FONT.title, S.MINI_TEXT_W)
    bar.name:SetPoint("LEFT", S.MINI_TEXT_X, S.MINI_NAME_Y)
    bar.sub = W.Text(bar, T.FONT.hint, S.MINI_TEXT_W)
    bar.sub:SetPoint("LEFT", S.MINI_TEXT_X, S.MINI_SUB_Y)
    local okX, x = pcall(CreateFrame, "Button", nil, bar, "UIPanelCloseButtonNoScripts")
    if not okX or not x then
        x = CreateFrame("Button", nil, bar)
        local t = W.Text(x, T.FONT.title)
        t:SetPoint("CENTER")
        t:SetText("x")
    end
    x:SetSize(S.MINI_X, S.MINI_X)
    x:SetPoint("RIGHT", -S.MINI_X_R, 0)
    x:SetScript("OnClick", function() hideBar() end)
    W.Tooltip(x, L["Schließen"], L["Blendet die Leiste aus; \"Leiste zeigen\" unter Einstellungen, Layer: Anzeige bringt sie zurück."])
    W.Tooltip(bar, L["Layer"], L["Klick: das Fenster Layer öffnen oder schließen. Rechtsklick: die Leiste ausblenden. Rechtsklick auf das Symbol: die Layer dieser Zone. Ziehen: die Leiste verschieben."])
    bar.close = x
    local acc = 0
    bar:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate LayerMiniBar", function(_, elapsed)
        acc = acc + (elapsed or 0)
        -- the world restart's countdown (F-220), a running search (F-221) and a wait (F-229) every second
        if acc < (LW.Ticking() and 1 or S.TICK) then return end
        acc = 0
        LW.UpdateMini()
    end))
    bar:Hide()
    mini = bar
    styleMini()
    place()
    return bar
end

-- The bar's second line (F-221): the state. An own swap ("In der Gruppe des Helfers", "Verlasse in 4 s",
-- "Gewechselt", "Kein Wechsel"), the request, the search ("Frage, 3 gehört"), the world restart, else helping:
-- "Pausiert", "Helfen", "Helfen aus"; while the layer is unknown how to learn it. F-229: a wait ("Warten 12:34",
-- "Kampf 0:04") before helping.
function LW.MiniSub(known, _, st)
    st = st or {}
    local s, p = st.swap, st.pending
    if s then
        if s.changed and s.leaveAt and s.leaveAt > GetTime() then
            return GREEN .. L["Verlasse in %d s"]:format(math.ceil(s.leaveAt - GetTime())) .. "|r"
        end
        if s.changed then return GREEN .. L["Gewechselt"] .. "|r" end
        if s.failed then return L["Kein Wechsel"] end
        if not s.unknown then return L["In der Gruppe des Helfers"] end
    elseif p then
        return p.invited and L["Einladung kam"] or L["Einladung erbeten"]
    elseif st.chat then
        return L["Gefragt ..."]
    elseif st.step == "stop" then
        if st.answers and #st.answers > 0 then return GREEN .. L["Antworten: %d"]:format(#st.answers) .. "|r" end
        return L["Frage, %d gehört"]:format(st.zone and st.zone.heardN or 0)
    end
    -- F-220: the world restart counts down
    if st.refresh then return st.refresh end
    if st.blocked then
        local label = LW.SwapLabel("ask", nil, nil, st)
        return label
    end
    if not known then return L["Ziele einen NPC an."] end
    if not st.hosting then return L["Helfen aus"] end
    if st.why then return L["Pausiert"] end
    return GREEN .. L["Helfen"] .. "|r"
end

-- The bar's look (F-220): one line or two (layer.barOneLine), the ground's darkness (layer.barShade, percent).
styleMini = function()
    if not mini then return end
    local one = ns.Get("layer.barOneLine") and true or false
    if mini.oneLine ~= one then
        mini.oneLine = one
        mini:SetHeight(one and S.MINI_ONE_H or S.MINI_H)
        mini.name:ClearAllPoints()
        mini.name:SetPoint("LEFT", S.MINI_TEXT_X, one and 0 or S.MINI_NAME_Y)
        mini.sub:SetShown(not one)
    end
    local a = math.max(0, math.min(100, tonumber(ns.Get("layer.barShade")) or 55)) / 100
    if mini.shade ~= a then
        mini.shade = a
        -- the template's own colour, only its alpha changed
        if not mini.rgb then
            local ok, r, g, b = false, nil, nil, nil
            if mini.GetBackdropColor then ok, r, g, b = pcall(mini.GetBackdropColor, mini) end
            mini.rgb = (ok and tonumber(r) and tonumber(g) and tonumber(b)) and { r, g, b } or { 0, 0, 0 }
        end
        local c = mini.rgb
        if mini.SetBackdropColor then pcall(mini.SetBackdropColor, mini, c[1], c[2], c[3], a) end
        if type(mini.NineSlice) == "table" and mini.NineSlice.SetCenterColor then pcall(mini.NineSlice.SetCenterColor, mini.NineSlice, c[1], c[2], c[3], a) end
        if mini.flat and mini.flat.SetAlpha then mini.flat:SetAlpha(a) end
    end
end
LW.StyleMini = styleMini

-- The menu of the bar's symbol: the swap, the zone's other layers (each a swap to exactly that one, with its age),
-- stopping the search, helping, the window.
function LW.MiniMenu()
    local st = SW.State()
    local label, enabled = LW.SwapLabel(st.step, st.zoneNext, st.age, st)
    local out = { { label, enabled and function() say(SW.Press()) end or nil } }
    if st.step == "ask" or st.step == "more" or st.step == "channel" then
        for _, e in ipairs(LY.InInstance() and {} or LY.List()) do
            if not e.current then
                local uid = e.uid
                out[#out + 1] = { L["Zu %s wechseln"]:format(e.name) .. " · " .. LY.Age(e.age), function() say(SW.Swap(uid)) end }
            end
        end
    end
    out[#out + 1] = { st.hosting and L["Helfen ausschalten"] or L["Helfen anschalten"], function()
        local _, why = SW.SetHosting(not SW.Hosting())
        if why then ns.msg(why) end
    end }
    out[#out + 1] = { L["Fenster öffnen"], function() LW.Show() end }
    return out
end

-- The bar's symbol: "search" (green) while an own search or swap runs, "off" (grey) with helping off, else
-- "host" (gold, the art as it is).
function LW.MiniState(st)
    if st.step == "stop" or st.pending or st.swap or st.chat then return "search" end
    if not st.hosting then return "off" end
    return "host"
end

function LW.UpdateMini()
    if not mini or not mini:IsShown() then return end
    local st = SW.State()
    local look = LW.MiniState(st)
    mini.state = look
    if mini.icon.SetDesaturated then mini.icon:SetDesaturated(look == "off") end
    if look == "search" then mini.icon:SetVertexColor(0.45, 1, 0.45) else mini.icon:SetVertexColor(1, 1, 1) end
    local first, sub
    if LY.InInstance() then
        first, sub = placeName(), L["In Instanzen gibt es keine Layer."]
    else
        local uid, _, name = LY.Current()
        first, sub = uid and name or L["Layer %s"]:format("?"), LW.MiniSub(uid ~= nil, LY.Map(), st)
    end
    if mini.oneLine then
        mini.name:SetText(first .. " · " .. sub)
        mini.sub:SetText("")
    else
        mini.name:SetText(first)
        mini.sub:SetText(sub)
    end
end

-- The bar shown or hidden as wanted (layer.bar or the folded window).
function LW.UpdateBar()
    if barWanted() then
        buildMini()
        if not mini:IsShown() then mini:Show() end
        LW.UpdateMini()
    elseif mini then
        mini:Hide()
    end
end

-- The window folds to the bar, the bar's top right corner where the window's is; kept through /reload.
function LW.Minimize()
    if not F or not F:IsShown() then return end
    local right, top = F:GetRight(), F:GetTop()
    buildMini()
    F:Hide()
    local st = state("layerWindow")
    if right and top then
        topRightAt(mini, right, top)
        W.SaveWindowPlace(mini, state("layerBar"))
    end
    if st then st.mini = true end
    mini:Show()
    LW.UpdateMini()
end

-- The bar's click: the window opens (its top right corner where the bar's is, while folded) or closes.
function LW.Restore()
    if LW.Shown() then
        LW.Hide()
        return
    end
    local folded = (state("layerWindow") or {}).mini
    local right, top
    if mini and mini:IsShown() then right, top = mini:GetRight(), mini:GetTop() end
    if LW.Show() and folded and right and top then
        topRightAt(F, right, top)
        W.SaveWindowPlace(F, state("layerWindow"))
    end
end

---------------------------------------------------------------------------
-- The chip
---------------------------------------------------------------------------
local function buildChip()
    if chip then return chip end
    chip = CreateFrame("Button", "AmisiaLayerChip", UIParent)
    chip:SetSize(S.CHIP_W, S.CHIP_H)
    chip:SetFrameStrata("MEDIUM")
    chip:SetClampedToScreen(true)
    chip:SetMovable(true)
    chip:EnableMouse(true)
    chip:RegisterForDrag("LeftButton")
    W.Flat(chip, 0, 0, 0, S.SHADE)
    W.Border(chip, T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.5)
    chip.text = W.Text(chip, T.FONT.head, S.CHIP_W - 2 * S.CHIP_PAD)
    chip.text:SetPoint("CENTER", 0, 0)
    chip.text:SetJustifyH("CENTER")
    chip:SetScript("OnDragStart", function(self) self:StartMoving() end)
    chip:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        W.SaveWindowPlace(self, state("layerChip"))
    end)
    chip:SetScript("OnClick", function() LW.Toggle() end)
    W.Tooltip(chip, L["Layer"], L["Klick: das Fenster Layer. Ziehen: verschieben."])
    chip:Hide()
    place()
    return chip
end

function LW.UpdateChip()
    local on = ns.Get("layer.chip") and not LY.InInstance()
    if not on then
        if chip then chip:Hide() end
        return
    end
    buildChip()
    local uid, _, name = LY.Current()
    chip.text:SetText(uid and name or L["Layer %s"]:format("?"))
    chip:Show()
end
LW.Chip = function() return chip end

ns.Listen("LAYER", function()
    LW.UpdateChip()
    LW.Refresh()
    LW.UpdateMini()
end)
ns.Listen("LAYER_CHANGE", function()
    LW.Refresh()
    LW.UpdateMini()
end)
ns.Listen("SETTING", function(path)
    if path == "layer.chip" then LW.UpdateChip() end
    if path == "layer.bar" then LW.UpdateBar() end
    if path == "layer.barOneLine" or path == "layer.barShade" then
        styleMini()
        LW.UpdateMini()
    end
end)

local function world()
    -- in an instance the bar names the place (F-216) and the window says so (F-221)
    LW.UpdateBar()
    LW.Refresh()
    LW.UpdateChip()
end
ns.OnEvent("PLAYER_ENTERING_WORLD", world)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", world)

-- The lines of /amisia layer status (F-221): the layer, helping, the own search.
function LW.StatusLines()
    local st = SW.State()
    local out = {}
    if LY.InInstance() then
        out[#out + 1] = L["Layer: %s"]:format(L["Keine Layer in %s"]:format(placeName()))
    else
        local uid, map, name = LY.Current()
        out[#out + 1] = uid and L["Layer: %s"]:format(name .. " (" .. LW.SubText(uid, zoneName(map)) .. ")") or L["Layer: %s"]:format(L["unbekannt"])
    end
    local help
    if not st.hosting then help = L["aus bis zum nächsten Einloggen"]
    elseif st.why then help = L["pausiert: %s"]:format(st.why)
    else help = L["an"] end
    out[#out + 1] = L["Helfen: %s"]:format(help)
    local h = st.helped
    out[#out + 1] = L["Geholfen: %d haben gefragt, %d eingeladen, %d gekommen."]:format(h.asked, h.invited, h.joined)
    out[#out + 1] = L["Frage: %s"]:format((LW.StatusText(st)))
    -- F-229: the game's hourly limit
    out[#out + 1] = L["Wechsel in dieser Stunde: %d von %d"]:format(st.capUsed or 0, SW.CAP)
        .. ((st.cap or 0) > 0 and (" · " .. L["Warten %s"]:format(SW.Clock(st.cap))) or "")
    if st.refresh then out[#out + 1] = st.refresh end
    return out
end

-- "/amisia layer <words>": nothing toggles the window; swap [<letter>], gilde, stopp, an, aus, status, helfen,
-- kick (and the English words swap, guild, stop, on, off, host). Returns what it did for the tests. F-229: "neu"
-- is gone, and where the numbers are private a letter asks for nothing.
local WORDS = { swap = "swap", wechseln = "swap", gilde = "guild", guild = "guild", stopp = "stop", stop = "stop",
    helfen = "host", host = "host", kick = "kick", an = "on", on = "on", aus = "off", off = "off", status = "status" }
function LW.Command(rest)
    local word, arg = tostring(rest or ""):lower():match("^%s*(%S*)%s*(%S*)")
    local what = WORDS[word or ""]
    if not what then
        if word ~= "" then ns.msg(L["/amisia layer: swap [B], gilde, stopp, an, aus, status, helfen, kick"]) return "help" end
        LW.Toggle()
        return "window"
    end
    if what == "status" then
        for _, line in ipairs(LW.StatusLines()) do ns.msg(line) end
        return "status"
    end
    if what == "on" or what == "off" or what == "host" then
        local want = what == "on" or (what == "host" and not SW.Hosting())
        local on, why = SW.SetHosting(want)
        ns.msg(why or (on and L["Helfen ist an."] or L["Helfen ist aus, bis du dich neu einloggst."]))
        return what
    end
    if what == "swap" then
        if arg ~= "" and LY.Private() then
            ns.msg(L["Layer wechseln bringt dich auf einen anderen Layer."])
            return "private"
        end
        if arg ~= "" then
            for _, e in ipairs(LY.List()) do
                if e.letter:lower() == arg then say(SW.Swap(e.uid)) return "swap-" .. e.letter end
            end
            ns.msg(L["Layer %s ist in dieser Zone nicht bekannt."]:format(arg:upper()))
            return "unknown"
        end
        say(SW.Swap())
        return "swap"
    end
    if what == "guild" then say(SW.AskChat()) return "guild" end
    if what == "stop" then say(SW.Stop()) return "stop" end
    local n, why = SW.Kick()
    if not n and why then ns.msg(why) end
    return "kick"
end

-- F-229: the key binding "Layer wechseln" (Bindings.xml of the core): a key press is a click for the game (the /who)
_G.BINDING_HEADER_AMISIA = "Amisia"
_G.BINDING_NAME_AMISIA_LAYER_SWAP = L["Layer wechseln"]
_G.AmisiaLayerKey = function()
    if LY.InInstance() then return end
    say(SW.Press())
    LW.Refresh()
    LW.UpdateMini()
end

ns.RegisterSlash("layer", { desc = L["Fenster Layer: dein Layer in dieser Zone, Wechsel in Gilde, Zone und Kanal"], forever = true,
    args = "[swap [B]|gilde|stopp|an|aus|status|helfen|kick]", -- l10n-ok: command words
    run = function(rest) LW.Command(rest) end })
end)
