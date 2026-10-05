--[[preload
STUB.prefixResult = 3
]]
-- The client refuses the prefixes (too many registered): the message layer stays off and says so once.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
assert(NS.CommAvailable() == false and NS.CommReady() == false)
local n = 0
for _, m in ipairs(STUB.messages) do
    if m:find("Addon-Nachrichten sind nicht verfügbar (Präfix nicht angemeldet). Sync und Versionsprüfung sind aus.", 1, true) then n = n + 1 end
end
assert(n == 1, "said once: " .. n)
local ok, why = NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID")
assert(ok == nil and why, "nothing is sent")
assert(NS.CommSendBlob("SP", "2026-10-05:409", { a = 1 }, "RAID") == nil)
assert(#STUB.addonTries == 0)
-- nothing is read either
local got = 0
NS.CommOn("HI", function() got = got + 1 end)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur", "", 0, 0, "", 0)
assert(got == 0)
-- the version check says so too: on the page and when asked
local okAsk, whyAsk = NS.VersionAsk("raid")
assert(okAsk == nil and whyAsk == "Addon-Nachrichten sind nicht verfügbar.")
_G.UnitClass = function() return "Priester", "PRIEST" end
_G.UnitLevel = function() return 24 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function() return nil end
NS.ShowPage("about")
local f = NS.AboutPageFrame()
assert(f.empty:IsShown() and f.empty:GetText() == "Addon-Nachrichten sind nicht verfügbar.")
assert(not f.askRaid:IsEnabled() and not f.askGuild:IsEnabled())
