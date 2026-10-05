--[[preload
-- the saved data of a WoW Forever character from 1.9 with settings that only the TBC data used,
-- and a guild list of another game
AmisiaDB = {
    settings = { bis = { phase = 2, sources = { H = true, F = true, X = true, D = false }, view = "goals" } },
    bis = { v = 1, chars = { ["Vuloo"] = { class = "WARRIOR", wish = { [301] = { t = 5, prio = 3, note = "bitte" } },
                                          ex = { item = {}, boss = {}, place = { ["I:532"] = true } }, bag = {}, bank = {} } },
            guild = { game = "tbc", date = "2026-10-01", at = 1, by = "Vuloo", n = 1, list = { [28830] = { { name = "Anna", prio = 3 } } } } },
    sessions = { { id = "20261001200000-409", date = "2026-10-01", zone = "Geschmolzener Kern", instanceID = 409, start = 1, last = 2,
                   members = { Vuloo = { class = "WARRIOR", first = 1, last = 2 } }, loot = {}, items = {}, drops = {}, awards = {} } },
}
-- a guild bank with two tabs: an item 12345 x 7 in tab 1, x 5 in tab 2
STUB.gbank = { { [1] = { 12345, 7 }, [2] = { 999, 1 } }, { [3] = { 12345, 5 } } }
GetNumGuildBankTabs = function() return #STUB.gbank end
GetGuildBankTabInfo = function(tab) return "Tab " .. tab, 0, true end
QueryGuildBankTab = function() end
GetCurrentGuildBankTab = function() return 1 end
GetGuildBankItemLink = function(tab, slot)
    local e = STUB.gbank[tab] and STUB.gbank[tab][slot]
    return e and ("|cffffffff|Hitem:%d::::::::60:::::|h[x]|h|r"):format(e[1])
end
GetGuildBankItemInfo = function(tab, slot)
    local e = STUB.gbank[tab] and STUB.gbank[tab][slot]
    return 134, e and e[2] or 0
end
]]
-- Amisia is WoW Forever only (2.0): the TOC, no file or code path of the TBC client, the removed
-- helpers, the move of the saved settings (twice changes nothing), the ignore list and the empty
-- list of guild materials with the mechanism that comes back with a list.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function readFile(path)
    local fh = assert(io.open(path, "rb"))
    local s = fh:read("*a")
    fh:close()
    return s
end

---------------------------------------------------------------------------
-- the TOC
---------------------------------------------------------------------------
local toc = readFile(ADDON_DIR .. "/Amisia.toc")
local interface = {}
for v in toc:gmatch("## Interface:%s*([^\r\n]+)") do interface[#interface + 1] = v end
assert(#interface == 1 and interface[1] == "16001", "## Interface: 16001 alone: " .. table.concat(interface, "|"))
assert(not toc:find("TBC", 1, true) and not toc:find("AllowLoadGameType tbc", 1, true), "no TBC line")
for _, name in ipairs({ "GearData.lua", "GearWeights.lua", "MapData.lua" }) do
    assert(toc:find("\n" .. name .. " [AllowLoadGameType camelot]", 1, true), name .. " keeps its load condition")
end
assert(not toc:find("## AllowLoadGameType", 1, true), "no TOC-wide load condition")
local version = toc:match("## Version:%s*([^\r\n]+)")
assert(version and version == NS.VERSION, "TOC version and ns.VERSION agree: " .. tostring(version) .. " / " .. tostring(NS.VERSION))

---------------------------------------------------------------------------
-- no TBC file, no TBC code path
---------------------------------------------------------------------------
-- every file the TOC loads (the test runtime has no directory listing), and the TBC files of 1.9
local files = {}
for line in toc:gmatch("[^\r\n]+") do
    if not line:find("^#") and line:find("%S") then
        files[#files + 1] = (line:gsub("%s*%[[^%]]*%]", ""):gsub("\\", "/"):match("^%s*(.-)%s*$"))
    end
end
assert(#files > 30, "the addon files: " .. #files)
local MAP_LATER = { ["MapDataTBC.lua"] = true }   -- the map goes Forever only in its own step
for _, name in ipairs({ "BisDataTBC.lua", "BisWeightsTBC.lua", "MapDataTBC.lua" }) do
    if not MAP_LATER[name] then assert(io.open(ADDON_DIR .. "/" .. name, "rb") == nil, name .. " is gone") end
end
for _, name in ipairs(files) do
    if not MAP_LATER[name] then
        assert(not name:find("TBC", 1, true), "a file with TBC in its name: " .. name)
        if name:find("%.lua$") then
            local src = readFile(ADDON_DIR .. "/" .. name)
            for _, word in ipairs({ "IsForever", "LootButton", "LootFrame_Update", "BANK_CONTAINER", "OnTooltipSetItem", "20506",
                                    "NUM_BANKBAGSLOTS", "LOOTFRAME_NUMBUTTONS", "AmisiaScanTip" }) do
                assert(not src:find(word, 1, true), name .. " still has " .. word)
            end
            assert(not src:find("[^%.:%w_]GetSkillLineInfo%(") and not src:find("_G%.GetSkillLineInfo"),
                name .. " calls the global GetSkillLineInfo")
            assert(not src:find("_G%.GetItemInfo") and not src:find("_G%.GetItemStats") and not src:find("_G%.SendChatMessage")
                and not src:find("_G%.ChatEdit_InsertLink") and not src:find("_G%.GetContainer"), name .. " falls back to a global")
        end
    end
end

---------------------------------------------------------------------------
-- the helpers of two clients are gone
---------------------------------------------------------------------------
assert(NS.IsForever == nil and NS.Gear.Game == nil and NS.Gear.PlannerAvailable == nil, "no client switch")
assert(NS.Gear.PhaseOf == nil and NS.Gear.FillRow == nil and NS.Gear.TooltipStats == nil, "no TBC data helpers")
assert(NS.SettingItem("bis.phase") == nil, "no phase setting")
assert(NS.Gear.Available(), "the Forever data loads")

---------------------------------------------------------------------------
-- the move on load
---------------------------------------------------------------------------
local s = AmisiaDB.settings.bis
assert(s.phase == nil, "the phase setting is gone")
assert(s.sources.H == nil and s.sources.F == nil, "the heroic and reputation switches are gone")
assert(s.sources.X == true and s.sources.D == false and s.view == "goals", "the rest stays")
assert(AmisiaDB.bis.guild == nil, "a guild list of another game is gone")
local me = AmisiaDB.bis.chars.Vuloo
assert(me.wish[301] and me.wish[301].prio == 3 and me.wish[301].note == "bitte", "the wishes stay")
assert(me.ex.place["I:532"], "excluded places stay")
assert(#AmisiaDB.sessions == 1 and AmisiaDB.sessions[1].id == "20261001200000-409", "the raids stay")
local function dump(t)
    if type(t) ~= "table" then return tostring(t) end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(t[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
local once = dump(AmisiaDB)
NS.BisMigrate(AmisiaDB)
NS.BisMigrate(AmisiaDB)
assert(dump(AmisiaDB) == once, "loading again changes nothing")
-- a Forever guild list stays
assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-05\nW 28830 3 Anna\n#END"))
NS.BisMigrate(AmisiaDB)
assert(AmisiaDB.bis.guild and AmisiaDB.bis.guild.game == "forever", "the own game's list stays")

---------------------------------------------------------------------------
-- the ignore list and the guild materials
---------------------------------------------------------------------------
for _, id in ipairs({ 29434, 22450, 22449, 22448 }) do assert(not NS.IGNORE[id], "no TBC entry " .. id) end
assert(NS.IGNORE[20725] and NS.IGNORE[14344] and NS.IGNORE[14343], "the Classic disenchanting results stay")
assert(next(NS.MATS) == nil and #NS.MAT_ORDER == 0 and next(NS.GEMS) == nil, "no tracked material")

-- the empty list: opening the guild bank counts nothing, the export has no bank lines
assert(NS.Get("bank.count"), "counting is on")
STUB.fire("GUILDBANKFRAME_OPENED"); STUB.tick(1)
STUB.fire("GUILDBANKFRAME_CLOSED")
assert(AmisiaDB.bank == nil and NS.Bank() == nil and not NS.BankPending(), "no count without materials")
local txt = NS.ExportText({})
assert(not txt:find("\nK ", 1, true) and not txt:find("\nB ", 1, true), "no bank lines: " .. txt)
-- an old count of materials no longer tracked is kept, but neither shown nor exported
AmisiaDB.bank = { at = STUB.now, by = "Vuloo", counts = { [32897] = 3 }, tabs = 1, filled = 1, total = 1 }
assert(NS.Bank() == nil and not NS.BankPending() and not NS.ExportText({}):find("\nB ", 1, true), "the old count stays out")
AmisiaDB.bank = nil

-- a list set in the test: the mechanism works as before
NS.MATS[12345], NS.MAT_ORDER[1] = "Testerz", 12345
STUB.messages = {}
STUB.fire("GUILDBANKFRAME_OPENED"); STUB.tick(1)
STUB.fire("GUILDBANKFRAME_CLOSED")
assert(AmisiaDB.bank and AmisiaDB.bank.counts[12345] == 12 and not AmisiaDB.bank.counts[999], "counted: 7 + 5")
assert(has(table.concat(STUB.messages, "\n"), "Gildenbank gezählt: "), table.concat(STUB.messages, "\n"))
assert(NS.Bank() == AmisiaDB.bank and NS.BankPending(), "shown and pending")
txt = NS.ExportText({})
assert(txt:find("\nB 12345 12\n", 1, true) and txt:find("\nK ", 1, true), "the B line: " .. txt)
NS.MATS[12345], NS.MAT_ORDER[1] = nil, nil
