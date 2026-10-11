-- Review of the softres.it code (spec docs/specs/2026-10-11-softres-gargul.md, A2; D-44): the pasted
-- code is untrusted. A long run of spaces inside a field must not freeze the client (the old trim
-- was quadratic); a code too long to bound its unpacked size is refused before DecompressString
-- (zlib packs up to 1032:1, the client's call has no limit); JSON nested deeper than the code ever
-- is never reaches the client's reader.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.item(18814, "Choker of the Fire Lord", 4)

-- a made-up code the stub unpacks to text (run.py does the same for the fixtures)
local seq = 0
local function code(text)
    seq = seq + 1
    local c = C_EncodingUtil.EncodeBase64(("review-code-raw-bytes-%04d"):format(seq))
    STUB.addInflate(c, text)
    assert(NS.SoftResCode(c) == c, "a code")
    return c
end

---------------------------------------------------------------------------
-- a long run of spaces inside a note, a name and a hard reserve: linear, cleaned as before
---------------------------------------------------------------------------
local gap = (" "):rep(40000)
local spaced = code('{"softreserves":[{"name":"Anna","note":"x' .. gap .. 'y","items":[18814]},'
    .. '{"name":"B' .. gap .. 'c","items":[18814]}],"hardreserves":[{"id":17204,"for":"G' .. gap .. 'h"}]}')
local t0 = os.clock()
local byItem, _, _, _, total, _, extra = NS.ParseSoftRes(spaced)
local took = os.clock() - t0
assert(took < 0.5, ("a run of spaces in the code took %.2f s"):format(took))
assert(not extra.err and total == 2 and byItem[18814][1] == "Anna" and byItem[18814][2] == "B", tostring(extra.err))
assert(extra.notes.Anna == "x", tostring(extra.notes.Anna))
assert(extra.hard[17204].to == "G", tostring(extra.hard[17204].to))
-- the pasted text itself: spaces inside a long line
t0 = os.clock()
NS.SoftResCode("x" .. gap .. "y")
assert(os.clock() - t0 < 0.5, "recognising a code is linear")
-- trimming as before
assert(NS.SoftResCode("  \n" .. spaced .. " \r\n ") == spaced)

---------------------------------------------------------------------------
-- the size: a code that could unpack to more than about 19 MB never reaches DecompressString
---------------------------------------------------------------------------
local real = C_EncodingUtil.DecompressString
local unpacked = 0
C_EncodingUtil.DecompressString = function(...) unpacked = unpacked + 1 return real(...) end
local big = ("A"):rep(30000)
assert(select(2, NS.DecodeSoftResCode(big)) == "big", "too long")
assert(unpacked == 0, "refused before unpacking")
assert(NS.SoftResPreviewText(big) == "Code zu groß.", NS.SoftResPreviewText(big))
-- a code of normal size still unpacks
assert(NS.DecodeSoftResCode(spaced) and unpacked == 1)
C_EncodingUtil.DecompressString = real

---------------------------------------------------------------------------
-- the nesting: deep JSON never reaches the client's reader; brackets in a text do not count
---------------------------------------------------------------------------
local realJSON = C_EncodingUtil.DeserializeJSON
local read = 0
C_EncodingUtil.DeserializeJSON = function(s) read = read + 1 return realJSON(s) end
local deep = code(('{"softreserves":' .. ("["):rep(40) .. ("]"):rep(40) .. "}"))
local data, why = NS.DecodeSoftResCode(deep)
assert(data == nil and why == "broken" and read == 0, "too deep: " .. tostring(why))
assert(has(NS.SoftResPreviewText(deep), "unvollständig oder verändert"))
local bracketNote = code('{"softreserves":[{"name":"Anna","note":"' .. ("[{"):rep(30) .. '\\"]","items":[18814]}]}')
_, _, _, _, total, _, extra = NS.ParseSoftRes(bracketNote)
assert(not extra.err and total == 1 and read == 1, "brackets inside a text: " .. tostring(extra.err))
C_EncodingUtil.DeserializeJSON = realJSON
