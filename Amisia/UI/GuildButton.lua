-- The button "Amisia" at the game's guild window (F-210): Forever's guild and communities window
-- (CommunitiesFrame, Blizzard_Communities, loaded on demand) and the classic guild frame in the friends
-- window (GuildFrame, TBC and Era). A red button of Amisia's own, a child of that frame: it shows and
-- hides with it and never touches the frame's own controls or functions (no hook, nothing replaced).
-- Under the frame's bottom right corner (the communities window has nothing there); in the friends
-- window right of its last tab, where the tab row below the frame has room. A click opens the members
-- page, without the raid module the main window.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local G = T.GUILDBUTTON

local buttons = {}           -- frame name -> the button
ns.GuildButtons = buttons

local function open()
    if ns.Panel("members") and ns.ShowPage then
        ns.ShowPage("members")
    elseif ns.ShowPage then
        -- without the raid module: the main window (ShowPage falls back on its start page)
        ns.ShowPage("overview")
    end
end
ns.GuildButtonClick = open

-- The last tab of the friends window (its tab row hangs below the frame), nil when it has none.
local function lastFriendsTab()
    local f = _G.FriendsFrame
    local n = f and tonumber(f.numTabs)
    return n and _G["FriendsFrameTab" .. n] or nil
end

local function attach(frameName)
    if buttons[frameName] then return buttons[frameName] end
    local parent = _G[frameName]
    if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then return nil end
    local b = W.Button(parent, "Amisia", G.W, open, { height = G.H })
    b:ClearAllPoints()
    local tab = frameName == "GuildFrame" and lastFriendsTab()
    if tab then
        b:SetPoint("LEFT", tab, "RIGHT", G.TAB_GAP, 0)
    else
        b:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", G.X, G.Y)
    end
    W.Tooltip(b, "Amisia", L["Öffnet Amisia auf der Seite Mitglieder: Twinks und Itemlevel der Gilde."])
    buttons[frameName] = b
    return b
end

local function check()
    for _, name in ipairs({ "CommunitiesFrame", "GuildFrame" }) do
        if _G[name] then attach(name) end
    end
end
ns.GuildButtonCheck = check

-- Blizzard_Communities loads on demand (the guild key), long after Amisia: the core's ADDON_LOADED is
-- unregistered by then, so a frame of its own listens.
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:RegisterEvent("PLAYER_LOGIN")
local function safeCheck()
    local ok, err = pcall(check)
    if not ok then ns.ReportError(err) end
end
watch:SetScript("OnEvent", safeCheck)
safeCheck()
end)
