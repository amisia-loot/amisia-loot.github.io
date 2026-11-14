-- The window "Layer" (F-185, D-117, ns.LayerWindow, AmisiaLayerFrame, tokens T.LAYER) and the layer chip
-- (AmisiaLayerChip, layer.chip). The window: large the current layer ("Layer B", else "unbekannt"), grey
-- under it the zone or "Ziele oder überfahre einen NPC."; "Gesehen in dieser Zone" with a row per layer of
-- the zone ("Layer A · hier · vor 3 Min.", "Gilde" for one only the guild reported); "Layer wechseln"
-- with the red button "Gilde fragen" and the link "Im Gildenchat fragen", under them the link "Im Kanal
-- fragen" (players outside the guild, F-191), a status line, the answers ("Name · Layer C" with the link
-- "Einladung erbitten") and "Gruppe verlassen" once a swap group stands (Gear/LayerChange.lua). Movable, its
-- place in settings.layerWindow, the x closes it; never shown in an instance (it closes on entering one).
-- Opened by /amisia layer, the minimap menu (its own entry) and its row in the side bar of the tab Gilde.
-- The client's "-" left of the x folds it to the bar AmisiaLayerMiniBar (F-204): the window's symbol, the
-- layer ("Layer B", "Layer ?") over a grey line (the zone, "Antworten: 2" while answers wait, "Ziele einen
-- NPC an." while the layer is unknown); a click opens the window again with its top right corner where the
-- bar's is, the x closes the bar. Folded, it stays through /reload (settings.layerWindow.mini, the bar on
-- the window's place); hidden in instances.
-- The chip: a small box "Layer B" ("Layer ?"), movable (settings.layerChip), a click opens the window;
-- hidden in instances. A plain frame, nothing protected.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.LAYER
local LY, SW = ns.Layer, ns.LayerChange

local LW = {}
ns.LayerWindow = LW

local F, chip, mini
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
    if mini then W.PlaceWindow(mini, state("layerWindow"), "RIGHT", UIParent, "RIGHT", -60, 220) end
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
    local a, b = state("layerWindow"), state("layerChip")
    if a then a.point, a.x, a.y = nil, nil, nil end
    if b then b.point, b.x, b.y = nil, nil, nil end
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

local function build()
    if F then return F end
    F = W.Window("AmisiaLayerFrame", S.W, S.TOP + S.BOTTOM, { title = L["Layer"], strata = "MEDIUM",
        onDragStop = function(f) W.SaveWindowPlace(f, state("layerWindow")) end,
        -- its row in the side bar of the tab Gilde lights while it is open (D-68)
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end })
    F.value = W.Text(F, T.FONT.big, S.W - 2 * S.PAD)
    F.value:SetPoint("TOPLEFT", S.PAD, -S.TOP)
    F.sub = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.sub:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.VALUE_H))
    F.seenHead = W.Text(F, T.FONT.head, S.W - 2 * S.PAD)
    F.seenHead:SetText(L["Gesehen in dieser Zone"])
    F.seen = {}
    for i = 1, S.ROWS do
        F.seen[i] = W.Text(F, T.FONT.text, S.W - 2 * S.PAD)
    end
    F.more = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.swapHead = W.Text(F, T.FONT.head, S.W - 2 * S.PAD)
    F.swapHead:SetText(L["Layer wechseln"])
    F.ask = W.Button(F, L["Gilde fragen"], nil, function() say(SW.Ask()) end)
    W.FitChip(F.ask)
    W.Tooltip(F.ask, L["Gilde fragen"], L["Fragt die Gildenmitglieder mit Amisia, wer in dieser Zone auf einem anderen Layer ist. Nur wer allein ist, kann danach eingeladen werden."])
    F.chat = W.Link(F, L["Im Gildenchat fragen"], function() say(SW.AskChat()) end)
    W.Tooltip(F.chat, L["Im Gildenchat fragen"], L["Öffnet den Gildenchat mit deiner Bitte (Einstellung \"Text für Im Gildenchat fragen\"); du schickst sie mit Enter ab. So erreichst du Gildenmitglieder mit anderen Layer-Addons. Eine Minute lang nimmt Amisia dann die Einladung eines Gildenmitglieds an."])
    F.channel = W.Link(F, L["Im Kanal fragen"], function() say(SW.AskChannel()) end)
    W.Tooltip(F.channel, L["Im Kanal fragen"], L["Öffnet den Chatkanal aus den Einstellungen (Layer: Kanal, sonst 1, meist Allgemein) mit deiner Bitte; du schickst sie mit Enter ab. So erreichst du alle Spieler der Zone, mit und ohne Layer-Addon. Eine Minute lang nimmt Amisia dann die nächste Einladung an, egal von wem."])
    F.status = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD, true)
    F.status:SetHeight(2 * S.LINE_H)
    F.status:SetJustifyV("TOP")
    F.answers = {}
    for i = 1, S.ANSWERS do F.answers[i] = buildAnswer() end
    F.minBtn = buildMinButton()
    F.leave = W.Link(F, L["Gruppe verlassen"], function() say(SW.Leave()) end)
    W.Tooltip(F.leave, L["Gruppe verlassen"], L["Verlässt die Gruppe, die für den Layer-Wechsel entstand. Der Layer bleibt meist, bis du die Zone wechselst."])
    local acc = 0
    F:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate LayerWindow", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < S.TICK then return end
        acc = 0
        LW.Refresh()
    end))
    place()
    return F
end

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------
-- The status line of the swap and whether the link "Gruppe verlassen" shows.
function LW.StatusText(st)
    local s, p, r = st.swap, st.pending, st.req
    if s then
        if s.changed then return GREEN .. L["Gewechselt: %s"]:format(LY.Name(s.map, s.target)) .. "|r", true end
        if s.failed then return L["Kein Wechsel: der Layer ist derselbe geblieben."], true end
        if s.unknown then return L["Dein Layer war vor der Anfrage unbekannt: ob du gewechselt hast, ist nicht zu sehen."], true end
        return L["In der Gruppe mit %s: ziele einen NPC an, sobald du gewechselt bist."]:format(s.host), true
    end
    if p then
        if p.chat then return L["Einladung von %s kam."]:format(p.name), false end
        if p.invited then return L["Einladung von %s kam."]:format(p.name), false end
        return L["Einladung bei %s erbeten."]:format(p.name), false
    end
    if st.chatAll then return L["Im Kanal gefragt: eine Minute lang nimmt Amisia die nächste Einladung an."], false end
    if st.chat then return L["Im Gildenchat gefragt: eine Minute lang nimmt Amisia die Einladung eines Gildenmitglieds an."], false end
    if r and GetTime() - r.at <= SW.REQ_LIFE then
        if #st.answers > 0 then return L["Antworten von anderen Layern: %d"]:format(#st.answers), false end
        if GetTime() - r.at < SW.ANSWER_WAIT then return L["Gefragt, warte auf Antworten ..."], false end
        return L["Keine Antwort von einem anderen Layer."], false
    end
    local ok, why = SW.CanAsk()
    -- without a guild the channel is the way: its reason would only name the guild
    if not ok and not ns.InGuild() then return L["Frag im Kanal: wer dich einlädt, bringt dich auf seinen Layer."], false end
    if not ok then return why, false end
    return L["Frag die Gilde, wer auf einem anderen Layer ist."], false
end

function LW.Refresh()
    if not F or not F:IsShown() then return end
    local uid, _, name = LY.Current()
    local zone = LY.Map()
    if uid then
        F.value:SetText(name)
        F.sub:SetText(zoneName(zone))
    else
        F.value:SetText(L["unbekannt"])
        F.sub:SetText(L["Ziele oder überfahre einen NPC."])
    end
    local y = -(S.TOP + S.VALUE_H + S.LINE_H + S.GAP)
    F.seenHead:ClearAllPoints()
    F.seenHead:SetPoint("TOPLEFT", S.PAD, y)
    y = y - S.HEAD_H
    local list = LY.List(zone)
    for i, fs in ipairs(F.seen) do
        local e = list[i]
        if e then
            local parts = { e.name }
            if e.current then parts[#parts + 1] = L["hier"] end
            if not e.own then parts[#parts + 1] = L["Gilde"] end
            parts[#parts + 1] = LY.Age(e.age)
            fs:SetText((e.current and "" or GREY) .. table.concat(parts, " · ") .. (e.current and "" or "|r"))
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", S.PAD, y)
            fs:Show()
            y = y - S.ROW_H
        else
            fs:Hide()
        end
    end
    if #list == 0 then
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
    y = y - S.GAP
    F.swapHead:ClearAllPoints()
    F.swapHead:SetPoint("TOPLEFT", S.PAD, y)
    y = y - S.HEAD_H
    local st = SW.State()
    W.Row(F, { F.ask, F.chat }, S.GAP, S.PAD, y)
    F.chat:ClearAllPoints()
    F.chat:SetPoint("LEFT", F.ask, "RIGHT", S.GAP, 0)
    y = y - T.BUTTON_H - S.GAP
    F.channel:ClearAllPoints()
    F.channel:SetPoint("TOPLEFT", S.PAD, y)
    y = y - S.ROW_H
    local text, leave = LW.StatusText(st)
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
    F.leave:SetShown(leave and true or false)
    if leave then
        F.leave:ClearAllPoints()
        F.leave:SetPoint("TOPLEFT", S.PAD, y)
        y = y - S.ROW_H
    end
    F:SetHeight(-y + S.BOTTOM)
end

function LW.Show()
    if LY.InInstance() then
        ns.msg(L["Das Fenster Layer gibt es nicht in Instanzen."])
        return false
    end
    local st = state("layerWindow")
    if st then st.mini = nil end
    if mini then mini:Hide() end
    build()
    F:Show()
    LW.Refresh()
    return true
end

function LW.Hide() if F then F:Hide() end end
function LW.Shown() return F ~= nil and F:IsShown() end
function LW.Toggle()
    if LW.MiniShown() then LW.Restore()
    elseif LW.Shown() then LW.Hide() else LW.Show() end
end

---------------------------------------------------------------------------
-- The bar (F-204): the window folded
---------------------------------------------------------------------------
local function buildMini()
    if mini then return mini end
    local ok, bar = pcall(CreateFrame, "Button", "AmisiaLayerMiniBar", UIParent, "TooltipBackdropTemplate")
    if not ok or not bar then
        bar = CreateFrame("Button", "AmisiaLayerMiniBar", UIParent)
        W.Flat(bar, 0.05, 0.05, 0.06, 0.95)
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
        W.SaveWindowPlace(self, state("layerWindow"))
    end)
    bar:SetScript("OnClick", function(self)
        if self.moved then self.moved = nil return end
        LW.Restore()
    end)
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(S.MINI_ICON, S.MINI_ICON)
    bar.icon:SetPoint("LEFT", S.MINI_ICON_X, 0)
    local art = T.NAV_ICONS["win:layer"]
    if art and art.file then bar.icon:SetTexture(art.file) else bar.icon:Hide() end
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
    x:SetScript("OnClick", function()
        local st = state("layerWindow")
        if st then st.mini = nil end
        bar:Hide()
    end)
    W.Tooltip(x, L["Schließen"], L["Schließt die Leiste; /amisia layer öffnet das Fenster wieder."])
    W.Tooltip(bar, L["Layer"], L["Klick: das Fenster Layer wieder öffnen. Ziehen: die Leiste verschieben."])
    bar.close = x
    local acc = 0
    bar:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate LayerMiniBar", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < S.TICK then return end
        acc = 0
        LW.UpdateMini()
    end))
    bar:Hide()
    mini = bar
    place()
    return bar
end

-- The bar's grey line: answers waiting, else the zone, else how to learn the layer.
function LW.MiniSub(known, zone, st)
    local r = st and st.req
    if r and not st.swap and not st.pending and #st.answers > 0 and GetTime() - r.at <= SW.REQ_LIFE then
        return GREEN .. L["Antworten: %d"]:format(#st.answers) .. "|r"
    end
    if known then return zoneName(zone) end
    return L["Ziele einen NPC an."]
end

function LW.UpdateMini()
    if not mini or not mini:IsShown() then return end
    local uid, _, name = LY.Current()
    mini.name:SetText(uid and name or L["Layer %s"]:format("?"))
    mini.sub:SetText(LW.MiniSub(uid ~= nil, LY.Map(), SW.State()))
end

function LW.MiniShown() return mini ~= nil and mini:IsShown() end
LW.Mini = function() return mini end

-- The window folds to the bar, the bar's top right corner where the window's is; kept through /reload.
function LW.Minimize()
    if not F or not F:IsShown() then return end
    local right, top = F:GetRight(), F:GetTop()
    buildMini()
    F:Hide()
    local st = state("layerWindow")
    if right and top then
        topRightAt(mini, right, top)
        W.SaveWindowPlace(mini, st)
    end
    if st then st.mini = true end
    mini:Show()
    LW.UpdateMini()
end

-- The bar's click: the window again, its top right corner where the bar's is.
function LW.Restore()
    if not LW.MiniShown() then return end
    local right, top = mini:GetRight(), mini:GetTop()
    if LW.Show() and right and top then
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
end)

local function world()
    if LY.InInstance() then
        if F and F:IsShown() then F:Hide() end
        if mini then mini:Hide() end
    else
        local st = state("layerWindow")
        if st and st.mini and not LW.Shown() and not LW.MiniShown() then
            buildMini()
            mini:Show()
            LW.UpdateMini()
        end
    end
    LW.UpdateChip()
end
ns.OnEvent("PLAYER_ENTERING_WORLD", world)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", world)

ns.RegisterSlash("layer", { desc = L["Fenster Layer: dein Layer in dieser Zone, Wechsel in der Gilde und im Kanal"], forever = true,
    run = function() LW.Toggle() end })
end)
