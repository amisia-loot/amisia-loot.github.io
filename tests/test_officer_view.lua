-- The officer view only for officers (D-87, F-156): an officer rank of the guild (the rank rule of
-- the rights), whoever the client lets edit officer notes, and the author's character; everyone
-- else has the raider view only, even with "officer" saved, through the menu, the setting and
-- /amisia ansicht. An officer can still switch to the raider view and back; a rank read later
-- shows the view without a /reload.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function slash(text) SlashCmdList.AMISIA(text) end

-- a raider: no officer note rights, a raider rank
STUB.officer = false
STUB.guild = { { name = STUB.player, class = "MAGE", rank = 4 }, { name = "Chef", class = "WARRIOR", rank = 1 } }
STUB.fire("GUILD_ROSTER_UPDATE")
assert(NS.SelfIsOfficer() == false, "rank 4 is no officer rank")
assert(not NS.MayOfficerView() and not NS.IsOfficerView(), "a raider has the raider view")

-- a saved "officer" from before does not count
NS.Set("ui.view", "officer")
assert(not NS.IsOfficerView(), "a forced officer view is ignored without an officer rank")
NS.Reset("ui.view")

-- the toggle does nothing, the command says why
NS.ToggleView()
assert(NS.Get("ui.view") == "auto", "toggle refused: " .. tostring(NS.Get("ui.view")))
slash("ansicht offizier")
assert(has(lastMsg(), "nur Offiziere"), "command refused: " .. lastMsg())
assert(NS.Get("ui.view") == "auto" and not NS.IsOfficerView())
slash("ansicht raider")
assert(NS.Get("ui.view") == "raider", "the raider view can always be chosen")
NS.Reset("ui.view")

-- the setting "Ansicht" is not offered to a raider
local item = NS.SettingItem("ui.view")
assert(item and not NS.Visible(item), "setting hidden for a raider")

-- officer pages stay hidden
NS.RegisterPanel{ key = "ov_test", label = "O", order = 98, officer = true, create = function(p) return CreateFrame("Frame", nil, p) end }
assert(not NS.Visible(NS.Panel("ov_test")))

-- the rank read later: rank 2 is an officer rank (fallback: guild master and the rank below)
STUB.guild[1].rank = 2
STUB.clock = STUB.clock + 30
STUB.fire("GUILD_ROSTER_UPDATE")
assert(NS.SelfIsOfficer(true) == true, "rank 2 is an officer rank")
assert(NS.MayOfficerView() and NS.IsOfficerView(), "an officer by rank has the officer view without the note right")
assert(NS.Visible(NS.Panel("ov_test")) and NS.Visible(item), "officer page and setting shown")

-- an officer can switch to the raider view and back
NS.ToggleView()
assert(NS.Get("ui.view") == "raider" and not NS.IsOfficerView(), "officer chose the raider view")
NS.ToggleView()
assert(NS.IsOfficerView(), "and back")
slash("ansicht auto")
assert(NS.IsOfficerView())

-- out of the officer rank again: back to the raider view
STUB.guild[1].rank = 3
STUB.clock = STUB.clock + 30
STUB.fire("GUILD_ROSTER_UPDATE")
assert(not NS.IsOfficerView(), "rank 3 again: raider view")

-- the officer note right of the client is enough (as before)
STUB.officer = true
assert(NS.IsOfficerView(), "officer note right")
STUB.officer = false

-- the author's character, whatever his rank, even outside a guild
STUB.player = "Vulo Vultrox"
STUB.inGuild = false
STUB.clock = STUB.clock + 30
STUB.fire("PLAYER_GUILD_UPDATE")
assert(NS.Feedback.IsAuthor(), "the author")
assert(NS.MayOfficerView() and NS.IsOfficerView(), "the author has the officer view")
NS.Set("ui.view", "raider")
assert(not NS.IsOfficerView(), "the author can choose the raider view")
NS.Reset("ui.view")

-- another Vulo is not the author
STUB.player = "Vulo Sturmwind"
assert(not NS.Feedback.IsAuthor() and not NS.IsOfficerView(), "only Vulo Vultrox")
