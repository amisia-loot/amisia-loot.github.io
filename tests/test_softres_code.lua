-- The softres.it code (its "Gargul" export, spec docs/specs/2026-10-11-softres-gargul.md, A2):
-- Base64 -> C_EncodingUtil.DecompressString(zlib) -> DeserializeJSON. The made-up codes are in
-- tests/fixtures (run.py unpacks them with Python for the stub; tools/tests/test_softres_samples.py
-- proves them valid). Decoding, the preview, storing (data model 3), notes and the softres +1 as hints
-- only, hard reserves ("HR" in the tooltip and the loot window, the question at the round's start, no
-- loot rule), bonus rolls left out, untrusted fields cleaned, a broken code, a missing client
-- function, an empty code, and "/amisia sr <code>".
assert(NS.Set("drops.tooltip", false))
local function fixture(name)
    local fh = assert(io.open(ADDON_DIR .. "/../tests/fixtures/" .. name, "rb"))
    local text = fh:read("*a")
    fh:close()
    return (text:gsub("%s+$", ""))
end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local SAMPLE, MESSY, EMPTY, NOTJSON = fixture("softres_sample.txt"), fixture("softres_messy.txt"),
    fixture("softres_empty.txt"), fixture("softres_notjson.txt")
STUB.item(18814, "Choker of the Fire Lord", 4)
STUB.item(17076, "Bonereaver's Edge", 4)
local hrLink = STUB.item(17204, "Eye of Sulfuras", 5)
NS.Set("ui.view", "officer")

---------------------------------------------------------------------------
-- recognising a code
---------------------------------------------------------------------------
assert(NS.SoftResCode(SAMPLE) == SAMPLE and NS.SoftResCode("  " .. SAMPLE .. "\n") == SAMPLE, "trimmed")
assert(NS.SoftResCode("Anna 18814") == nil and NS.SoftResCode("Item,ItemId,From,Name") == nil, "lines and a CSV are no code")
assert(NS.SoftResCode("Anna18814") == nil, "too short for a code")

---------------------------------------------------------------------------
-- the spec's sample: Anna 18814 twice, Bob 17076 (note Tank, softres +1: 1), HR 17204 for Gilde
---------------------------------------------------------------------------
local byItem, count, bad, times, total, _, extra = NS.ParseSoftRes(SAMPLE)
assert(extra.src == "code" and not extra.err, tostring(extra.err))
assert(total == 3 and count == 2 and #bad == 0, ("total %d count %d"):format(total, count))
assert(byItem[18814][1] == "Anna" and times[18814].Anna == 2, "a double reservation counts as 2x")
assert(byItem[17076][1] == "Bob" and extra.notes.Bob == "Tank" and extra.plus.Bob == 1 and extra.plus.Anna == nil)
assert(extra.classes.Anna == "Priest" and extra.classes.Bob == "Warrior")
assert(extra.hardCount == 1 and extra.hard[17204].to == "Gilde" and extra.hard[17204].note == "")
assert(extra.sid == "ab12cd" and extra.updated == 1791651000 and extra.bonus == 0)

local preview = NS.SoftResPreviewText(SAMPLE)
assert(has(preview, "Gargul-Code erkannt: 3 Reservierungen, 1 Hard-Reserve"), preview)
assert(has(preview, "kein Raid zum Abgleichen"), preview)

local n, _, err, ex = NS.SetSoftRes(SAMPLE)
assert(n == 3 and err == nil and ex.hardCount == 1)
local sr = AmisiaDB.softres
assert(sr.version == 3 and sr.src == "code" and sr.sid == "ab12cd" and sr.count == 3 and sr.raw == SAMPLE)
assert(sr.notes.Bob == "Tank" and sr.classes.Anna == "Priest" and sr.plus.Bob == 1 and sr.hard[17204].to == "Gilde")
-- the migration keeps all of it, twice
NS.MigrateSoftRes(AmisiaDB); NS.MigrateSoftRes(AmisiaDB)
assert(AmisiaDB.softres.hard[17204].to == "Gilde" and AmisiaDB.softres.plus.Bob == 1 and AmisiaDB.softres.version == 3)
-- the same raid again
assert(has(NS.SoftResPreviewText(SAMPLE), "gleicher Raid wie die geladene Liste"), NS.SoftResPreviewText(SAMPLE))

-- the softres +1 is a hint only: Amisia's plus-one stays its own count (D-22)
assert(NS.PlusCount("Bob") == 0, "the softres +1 is not Amisia's plus-one")

-- the tooltip: the note and the softres +1 beside the name; "HR: Gilde" on the hard reserve
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
GameTooltip.GetItem = function() return "Bonereaver's Edge", STUB.item(17076, "Bonereaver's Edge", 4) end
STUB.showTooltip(GameTooltip)
assert(has(table.concat(lines, "\n"), "Reserviert: Bob (Tank, softres +1: 1)"), table.concat(lines, "\n"))
lines = {}
GameTooltip.GetItem = function() return "Eye of Sulfuras", hrLink end
STUB.showTooltip(GameTooltip)
assert(lines[1] == "HR: Gilde", tostring(lines[1]))
assert(NS.HardReserveText(17204) == "HR: Gilde" and NS.HardReserveText(17076) == nil)

-- no loot rule touches a hard reserve (D-37)
assert(NS.LootRuleGuard(17204, 4) == "Hard-Reserve", tostring(NS.LootRuleGuard(17204, 4)))

---------------------------------------------------------------------------
-- the hard reserve at the round's start: Amisia asks first
---------------------------------------------------------------------------
STUB.popup = nil
local ok, why = NS.StartRoll(hrLink, 20)
assert(not ok and has(why, "Hard-Reserve für Gilde"), tostring(why))
assert(STUB.popup and STUB.popup.which == "AMISIA_HR_ROLL" and STUB.popup.a1 == "Gilde", "the question")
assert(StaticPopupDialogs.AMISIA_HR_ROLL.text == "Hard-Reserve für %s. Trotzdem würfeln?")
assert(NS.CurrentRoll() == nil, "no round before the answer")
STUB.acceptPopup()
local r = NS.CurrentRoll()
assert(r and r.item == 17204 and not r.done and not r.foreign, "the answer starts the round")
NS.StopRoll()
-- a tie-break never asks
STUB.popup = nil
assert(NS.StartRoll(hrLink, 10, { "Anna", "Bob" }) == true and STUB.popup == nil)
NS.StopRoll()
-- an item without a hard reserve starts at once
assert(NS.StartRoll(STUB.item(17076, "Bonereaver's Edge", 4), 20) == true and STUB.popup == nil)
NS.StopRoll()

---------------------------------------------------------------------------
-- untrusted fields: codes, bars, a realm, long notes, ids out of range, bonus rolls, unknown fields
---------------------------------------------------------------------------
byItem, count, bad, times, total, _, extra = NS.ParseSoftRes(MESSY)
assert(not extra.err, tostring(extra.err))
assert(byItem[19019] and byItem[19019][1] == "Carl" and byItem[19019][2] == "Dörte", table.concat(byItem[19019] or {}, ","))
assert(byItem[18814] and #byItem[18814] == 1 and byItem[18814][1] == "Dörte", "no empty name, no name with a digit")
assert(total == 3, "ids 0, 1000000 and 'abc' are dropped: " .. total)
assert(extra.plus.Carl == nil and extra.plus["Dörte"] == 2, "a negative +1 is none")
local note = extra.notes.Carl
assert(note and not note:find("|", 1, true), tostring(note))
local chars = 0
for _ in note:gmatch("[%z\1-\127\192-\253][\128-\191]*") do chars = chars + 1 end
assert(chars <= 60, "the note is cut to 60 characters: " .. chars)
assert(extra.bonus == 3 and extra.hardCount == 2 and extra.hard[19019].to == "Tank" and extra.hard[17204].note == "Bank")
assert(extra.sid == "zz99yy")
preview = NS.SoftResPreviewText(MESSY)
assert(has(preview, "Gargul-Code erkannt: 3 Reservierungen, 2 Hard-Reserves") and has(preview, "3 Bonus-Würfe nicht übernommen"), preview)
assert(not has(preview, "gleicher Raid"), preview)

---------------------------------------------------------------------------
-- a broken code, a text that is no JSON, an empty code: nothing is stored
---------------------------------------------------------------------------
local broken = SAMPLE:sub(1, 150) .. SAMPLE:sub(152)
preview = NS.SoftResPreviewText(broken)
assert(has(preview, "Der Code ist unvollständig oder verändert"), preview)
n, bad, err = NS.SetSoftRes(broken)
assert(n == 0 and #bad == 0 and has(err, "unvollständig"), tostring(err))
assert(AmisiaDB.softres.sid == "ab12cd" and AmisiaDB.softres.count == 3, "the loaded list stays")
assert(has(NS.SoftResPreviewText(NOTJSON), "unvollständig oder verändert"), "bad JSON is a broken code")
assert(NS.SoftResPreviewText(EMPTY) == "Code gelesen, aber keine Reservierungen darin.", NS.SoftResPreviewText(EMPTY))
n, _, err = NS.SetSoftRes(EMPTY)
assert(n == 0 and err == "Code gelesen, aber keine Reservierungen darin." and AmisiaDB.softres.sid == "ab12cd")
-- a client function that throws is caught
local real = C_EncodingUtil.DeserializeJSON
C_EncodingUtil.DeserializeJSON = function() error("boom") end
assert(has(NS.SoftResPreviewText(SAMPLE), "unvollständig"))
-- a client without DeserializeJSON
C_EncodingUtil.DeserializeJSON = nil
assert(NS.SoftResPreviewText(SAMPLE) == "Dieser Client kann den Code nicht entpacken. Bitte den CSV-Export nehmen.")
n, _, err = NS.SetSoftRes(SAMPLE)
assert(n == 0 and has(err, "nicht entpacken"))
C_EncodingUtil.DeserializeJSON = real
-- too big
assert(select(2, NS.DecodeSoftResCode(("A"):rep(70000))) == "big")

---------------------------------------------------------------------------
-- the import window and /amisia sr <code>
---------------------------------------------------------------------------
NS.ClearSoftRes()
NS.ToggleSoftResFrame()
local F = AmisiaSoftResFrame
F.editBox:SetText(SAMPLE)
F.editBox.scripts.OnTextChanged(F.editBox, true)
STUB.tick(0.5)
assert(has(F.previewText:GetText(), "Gargul-Code erkannt: 3 Reservierungen, 1 Hard-Reserve"), F.previewText:GetText())
F.applyBtn:Click()
assert(F.resultText:GetText() == "3 Reservierungen übernommen, Hard-Reserves: 1.", F.resultText:GetText())
F.editBox:SetText(broken)
F.applyBtn:Click()
assert(has(F.resultText:GetText(), "unvollständig"), F.resultText:GetText())
assert(AmisiaDB.softres.count == 3)
F:Hide()

NS.ClearSoftRes()
NS.Dispatch("sr " .. SAMPLE)
assert(said("3 Reservierungen übernommen, Hard-Reserves: 1."), "the slash command imports a code")
assert(AmisiaDB.softres.sid == "ab12cd")
NS.Dispatch("sr " .. broken)
assert(said("Der Code ist unvollständig"))
NS.Set("ui.view", "raider")
NS.ClearSoftRes()
NS.Dispatch("sr " .. SAMPLE)
assert(said("Importieren nur in der Offiziersansicht.") and AmisiaDB.softres == nil)
