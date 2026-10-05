--[[preload
STUB.noEncoding = true
]]
-- Without C_EncodingUtil no blob is packed or read; plain text messages still work.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
assert(C_EncodingUtil == nil)
assert(NS.CommAvailable() == true and NS.CommPacking() == false)
local ok, why = NS.CommSendBlob("SP", "2026-10-05:409", { a = 1 }, "RAID")
assert(ok == nil and why, "no blob without packing")
assert(NS.CommPack({ a = 1 }) == nil and NS.CommUnpack("AAAA") == nil)
assert(NS.CommSend("HI", { "2.1.0", "1", "-", "-" }, "RAID") == true)
assert(#STUB.addon == 1)
local blobs = 0
NS.CommOnBlob("SP", function() blobs = blobs + 1 end)
STUB.fire("CHAT_MSG_ADDON", "AmisiaD", "1BL\tSP\t2026-10-05:409\t1\t1\t1\tAAAA", "RAID", "Fraktur", "", 0, 0, "", 0)
assert(blobs == 0)
local got = 0
NS.CommOn("HI", function() got = got + 1 end)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t2.1.0\t1\t-\t-", "RAID", "Fraktur", "", 0, 0, "", 0)
assert(got == 1, "text messages are read")
