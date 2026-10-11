--[[preload
C_AddOns = nil
function GetAddOnMetadata(addon, field) return addon == "Amisia" and STUB.tocMeta[field] or nil end
]]
-- The version stands only in the TOC: Core.lua reads it with C_AddOns.GetAddOnMetadata, or with the
-- old global GetAddOnMetadata on a client without C_AddOns (this file), and holds no number itself.
local fh = assert(io.open(ADDON_DIR .. "/Amisia.toc", "rb"))
local toc = fh:read("*a")
fh:close()
local version = toc:match("## Version:%s*([^\r\n]+)")
assert(version and version:match("^%d+%.%d+%.%d+$"), "a version X.Y.Z in the TOC: " .. tostring(version))
assert(NS.VERSION == version, "the fallback reads the TOC too: " .. tostring(NS.VERSION))

fh = assert(io.open(ADDON_DIR .. "/Core/Core.lua", "rb"))
local core = fh:read("*a")
fh:close()
assert(not core:find('ns%.VERSION%s*=%s*"'), "no version literal in Core.lua")
print("version from the TOC: " .. version)
