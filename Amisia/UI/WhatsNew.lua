-- "Neu in Amisia X.Y.Z" (F-236, D-168, spec docs/specs/2026-11-25-was-ist-neu.md): after an update, once, a
-- small window with the news of the versions since the one this account saw last (AmisiaDB.seenVersion); the
-- texts come from Data/WhatsNew.lua, which tools/build_whatsnew.py writes at the release from docs/FEATURES.md
-- (German titles) and CHANGELOG.md (English summaries). A first install shows nothing; an install from before
-- the key shows the running version's news. Never in combat or a boss fight: it waits until both are over.
-- Off with ui.whatsNew; the About page's link "Neuigkeiten" and /amisia neu (en "news") open it any time.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme

local SHOW_AFTER = 6   -- seconds after entering the world (the login's chat lines first)

local DB
local F
local since          -- after the load: the version to show the news after; false: the running one's only
local waiting        -- the window waits for the end of combat or a boss fight

local function isVersion(v)
    return type(v) == "string" and #v <= 20 and v:match("^%d+%.%d+%.%d+$") ~= nil
end

-- The items of the versions after `after` (nil: every version in the file; false: the running version's only)
-- up to the running one, newest version first: { { v = "2.110.0", list = { text, ... } }, ... }.
function ns.WhatsNewItems(after)
    local data = ns.Data and ns.Data("WHATSNEW")
    local out = {}
    if type(data) ~= "table" or type(data.versions) ~= "table" then return out end
    local running = ns.VERSION or "0.0.0"
    for _, entry in ipairs(data.versions) do
        local v, items = entry[1], entry[2]
        local take = isVersion(v) and type(items) == "table" and ns.CompareVersion(v, running) <= 0
        if take and after == false then
            take = ns.CompareVersion(v, running) == 0
        elseif take and after then
            take = ns.CompareVersion(v, after) > 0
        end
        if take then
            local list = {}
            for _, it in ipairs(items) do
                local text = ns.GERMAN and it[2] or it[3]
                if type(text) == "string" and text ~= "" then list[#list + 1] = text end
            end
            if #list > 0 then out[#out + 1] = { v = v, list = list } end
        end
    end
    return out
end

local function textOf(groups)
    if #groups == 0 then return T.GREY .. L["Keine Neuigkeiten gespeichert."] .. "|r" end
    local lines = {}
    for i, g in ipairs(groups) do
        if #groups > 1 then
            if i > 1 then lines[#lines + 1] = "" end
            lines[#lines + 1] = T.GOLD_TEXT .. L["Version %s"]:format(g.v) .. "|r"
        end
        for _, text in ipairs(g.list) do lines[#lines + 1] = "· " .. text end
    end
    return table.concat(lines, "\n")
end

local function build()
    local C = T.NEWS
    local pad = T.WINDOW_PAD
    local textH = C.LINES * C.LINE_H
    F = W.Window("AmisiaWhatsNewFrame", C.W, C.TEXT_Y + textH + C.GAP + T.BUTTON_H + C.BOTTOM,
        { strata = "DIALOG" })
    F:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    F.text = W.ScrollText(F)
    F.text:SetPoint("TOPLEFT", pad, -C.TEXT_Y)
    -- a fixed size: the text wraps to the frame's width, which two anchors give only after the first layout
    F.text:SetSize(C.W - 2 * pad - T.SCROLL_ROOM, textH)
    F.settings = W.SettingsLink(F, "ui")
    F.close = W.Button(F, L["Schließen"], C.BUTTON_W, function() F:Hide() end)
    W.FitChip(F.close, C.BUTTON_W)
    W.Row(F, { F.settings }, T.LAYOUT.ITEM_GAP, pad, C.BOTTOM, { point = "BOTTOMLEFT" })
    W.Row(F, { F.close }, T.LAYOUT.ITEM_GAP, pad, C.BOTTOM, { point = "BOTTOMRIGHT", right = true })
end

-- Opens the window with the news after `after` (see ns.WhatsNewItems); returns it.
function ns.ShowWhatsNew(after)
    if not F then build() end
    F:SetTitle(L["Neu in Amisia %s"]:format(ns.VERSION or ""))
    F.text:SetText(textOf(ns.WhatsNewItems(after)))
    if F.text.SetVerticalScroll then F.text:SetVerticalScroll(0) end
    F:Show()
    if F.Raise then F:Raise() end
    return F
end

local function encounter()
    local ce = _G.C_InstanceEncounter
    local api = ce and ce.IsEncounterInProgress or _G.IsEncounterInProgress
    if type(api) ~= "function" then return false end
    local ok, on = pcall(api)
    return ok and on == true
end

local function busy()
    return (type(InCombatLockdown) == "function" and InCombatLockdown()) or encounter()
end

local function markSeen()
    if DB and isVersion(ns.VERSION) then DB.seenVersion = ns.VERSION end
end

-- The check after the login: news to show, the switch on, not busy (else it waits). Returns whether it showed.
function ns.WhatsNewCheck()
    if since == nil then return false end
    local groups = ns.WhatsNewItems(since)
    if #groups == 0 or ns.Get("ui.whatsNew") == false then
        since = nil
        markSeen()
        return false
    end
    if busy() then
        waiting = true
        return false
    end
    waiting = nil
    ns.ShowWhatsNew(since)
    since = nil
    markSeen()
    return true
end

-- AmisiaDB.seenVersion: a version string or nothing. Decides what the login shows.
function ns.WhatsNewLoaded(root)
    DB = root
    if type(DB) ~= "table" then return end
    local seen = DB.seenVersion
    if not isVersion(seen) then seen = nil end
    DB.seenVersion = seen
    since = nil
    if not isVersion(ns.VERSION) then return end
    if not seen then
        -- a first install learns the version and shows nothing; an install from before this key (2.109.0 and
        -- older) shows the running version's news
        if ns.NEW_INSTALL then markSeen() else since = false end
    elseif ns.CompareVersion(seen, ns.VERSION) < 0 then
        since = seen
    end
end
ns.OnEvent("ADDON_LOADED", function() ns.WhatsNewLoaded(AmisiaDB) end)

local checked = false
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    if checked then return end
    checked = true
    if since == nil then return end
    if C_Timer and C_Timer.After then C_Timer.After(SHOW_AFTER, ns.WhatsNewCheck) else ns.WhatsNewCheck() end
end)

local function retry()
    if waiting then ns.WhatsNewCheck() end
end
ns.OnEvent("PLAYER_REGEN_ENABLED", retry)
ns.OnEvent("ENCOUNTER_END", retry)

ns.RegisterSlash("neu", { en = "news", desc = L["Neuigkeiten der letzten Versionen"], run = function()   -- l10n-ok: the command word
    ns.ShowWhatsNew(nil)
end })

-- test hooks
ns._whatsNew = {
    frame = function() return F end,
    since = function() return since end,
    waiting = function() return waiting end,
    reset = function() checked, waiting = false, nil end,
}
end)
