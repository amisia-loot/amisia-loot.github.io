-- Review of 1.6, the windows: one check per roster burst on the soft-reserve page, the import
-- window's preview and result lines in rooms of their own, the tooltip of a fixed list name, and
-- reasons that fit the roll window.
local failed = {}
local function check(label, fn)
    local ok, err = pcall(fn)
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(err) end
end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

STUB.instance = { name = "Dalaran", type = "none", id = 0 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
NS.SetSoftRes("Vuloo 32235\nFrak 32235\n")

---------------------------------------------------------------------------
-- 4. a burst of roster updates: one refresh, one check
---------------------------------------------------------------------------
check("4 one check per roster burst", function()
    NS.ShowPage("softres")
    local orig, calls = NS.SoftResCheck, 0
    NS.SoftResCheck = function(...) calls = calls + 1; return orig(...) end
    for _ = 1, 20 do STUB.fire("GROUP_ROSTER_UPDATE") end
    local now = calls
    STUB.tick(1)
    NS.SoftResCheck = orig
    assert(now == 0 and calls == 1, ("%d checks during the burst, %d in all"):format(now, calls))
end)

---------------------------------------------------------------------------
-- 7a. the tooltip of a fixed list name says how to forget the fix
---------------------------------------------------------------------------
check("7a tooltip of (Liste: Frak)", function()
    assert(NS.RenameReserve("Frak", "Fraktur", true) == 1)
    NS.ShowSoftRes("raider")
    local f = NS.SoftResPageFrame()
    local row
    for _, r in ipairs(f.list.rows) do
        if r.item and r.item.name == "Fraktur" then row = r end
    end
    assert(row and has(row.a:GetText(), "(Liste: Frak)"), "the marker")
    local lines = {}
    local add = GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
    row.scripts.OnEnter(row)
    GameTooltip.AddLine = add
    local all = table.concat(lines, "\n")
    assert(has(all, "/amisia sr vergessen Frak"), all)
    NS.ShowSoftRes("items")
end)

---------------------------------------------------------------------------
-- 5. import window: preview and result never share a line
---------------------------------------------------------------------------
check("5 import window rooms", function()
    NS.ToggleSoftResFrame()
    local F = NS.SoftResFrame
    local p, r, box = F.previewText, F.resultText, F.box
    assert(p._h and r._h and box, "fixed heights")
    local py, ry = p.points.BOTTOMLEFT.y, r.points.BOTTOMLEFT.y
    assert(ry >= 10 + 22, "the result above the buttons")
    assert(ry + r._h <= py, "the result below the preview")
    assert(py + p._h <= box.points.BOTTOMRIGHT.y, "the preview below the text box")
    assert(p._h >= 24 and r._h >= 24, "two lines each")
    NS.ToggleSoftResFrame()
end)

---------------------------------------------------------------------------
-- 7d. the reason of an ignored roll fits its column
---------------------------------------------------------------------------
check("7d reasons fit", function()
    STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
    assert(NS.StartRoll(link, 20))
    NS.ShowRollFrame()
    local F = NS.RollFrame
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 50, 1, 100))
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 60, 1, 100))      -- schon gewürfelt
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Gustavson", 70, 1, 100))    -- nicht in der Gruppe
    STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Chorf", 7, 1, 1000))        -- Bereich 1-1000
    local seen = 0
    for i = 2, 4 do
        local row = F.rows[i]
        local fs = row.reason
        assert(fs, "a column for the reason")
        local text = fs:GetText()
        assert(text ~= "" and fs:GetStringWidth() <= fs._w, ("'%s' fits %s px"):format(tostring(text), tostring(fs._w)))
        local x = fs.points.LEFT.x
        assert(x >= row.value.points.LEFT.x + row.value._w and x + fs._w <= row._w, "inside the row, after the roll")
        seen = seen + 1
    end
    -- the longest reason, of a tie-break
    local probe = F.rows[2].reason
    for _, why in ipairs({ "nicht in der Gruppe", "nicht im Stechen", "schon gewürfelt", "Bereich 1-1000" }) do
        probe:SetText(why)
        assert(probe:GetStringWidth() <= probe._w, why .. " fits")
    end
    assert(seen == 3)
    NS.StopRoll()
end)

assert(#failed == 0, #failed .. " failed: " .. table.concat(failed, " | "))
