--[[preload
STUB.noEncoding = true
TooltipDataProcessor, ChatFrameUtil, ChatFrame_OpenChat = nil, nil, nil
]]
-- Guild crafters on a client without C_EncodingUtil, the tooltip processor and the chat functions:
-- nothing is announced or asked, the page still shows the own crafters and the heard ones, the ask
-- button opens nothing and breaks nothing.
local Cr = NS.Crafters
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.guild = { { name = "Vulo Sturmwind", rank = 1 }, { name = "Anna Amboss", rank = 3 } }
STUB.fire("GUILD_ROSTER_UPDATE")
local D = NS.DropsToday()
AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = D, known = { [2663] = true } } } } }
local ix = Cr._index(164)
AmisiaDB.crafters = { v = 1, src = {}, c = { ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D,
    p = { [164] = { r = 300, m = 300, h = ix.hash, b = Cr._toBits(ix, { [2663] = true }) } } } } }
Cr.Changed()
assert(NS.CraftersCanTalk() == false, "no packing, no exchange")
STUB.fire("PLAYER_LOGIN")
STUB.tick(600)
assert(NS.CraftersStats().pv == 0 and NS.CraftersStats().bytes == 0, "nothing sent")
NS.Dispatch("berufe schmied")
local f = NS.ProfessionsPageFrame()
f.list.rows[1]:Click()
assert(has(f.detail.body.fs:GetText(), "Anna Amboss (300)"), f.detail.body.fs:GetText())
assert(f.detail.ask:IsEnabled())
f.detail.ask:Click()   -- no chat function: nothing happens, no error
assert(Cr.TooltipLine(2853) == "Kann herstellen: Anna Amboss (300), Vulo Sturmwind (45)", tostring(Cr.TooltipLine(2853)))
