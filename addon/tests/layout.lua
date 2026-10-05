-- Layout checks for page tests: load with dofile(ADDON_DIR .. "/../tests/layout.lua")(root, w, h).
-- span/vspan follow the anchors the stub records (points[point] = { rel, relPoint, x, y }) up to
-- the root; row() checks that frames sit left to right inside the root without overlapping,
-- column() the same from top to bottom, fits() that a font string's text fits its width.
local Hx = { LEFT = "L", TOPLEFT = "L", BOTTOMLEFT = "L", RIGHT = "R", TOPRIGHT = "R", BOTTOMRIGHT = "R" }
local Vx = { TOP = "T", TOPLEFT = "T", TOPRIGHT = "T", BOTTOM = "B", BOTTOMLEFT = "B", BOTTOMRIGHT = "B" }

return function(root, rootW, rootH)
    local L = {}
    local span, vspan
    local function edge(rel, relPoint, owner)
        rel = rel or owner.parent
        local l, r = span(rel)
        local c = Hx[relPoint] or "C"
        if c == "L" then return l elseif c == "R" then return r end
        return (l + r) / 2
    end
    span = function(fr)
        if fr == root then return 0, rootW end
        assert(fr ~= UIParent and fr ~= nil, "laid out outside the root")
        local Lx, R, C
        for p, a in pairs(fr.points or {}) do
            local x = edge(a.rel, a.relPoint, fr) + a.x
            local c = Hx[p] or "C"
            if c == "L" then Lx = x elseif c == "R" then R = x else C = x end
        end
        -- a template's own width (the stub's tplW: a scroll bar 8, a side tab 43) until one is set
        local w = fr._w or fr.tplW
        if Lx and R then return Lx, R end
        assert(w, "a width for " .. tostring(fr.name or fr.text))
        if Lx then return Lx, Lx + w end
        if R then return R - w, R end
        assert(C, "an anchor for " .. tostring(fr.name or fr.text))
        return C - w / 2, C + w / 2
    end
    local function vedge(rel, relPoint, owner)
        rel = rel or owner.parent
        local t, b = vspan(rel)
        local c = Vx[relPoint] or "C"
        if c == "T" then return t elseif c == "B" then return b end
        return (t + b) / 2
    end
    vspan = function(fr)
        if fr == root then return 0, -rootH end
        assert(fr ~= UIParent and fr ~= nil, "laid out outside the root")
        local T, Bt, C
        for p, a in pairs(fr.points or {}) do
            local y = vedge(a.rel, a.relPoint, fr) + a.y
            local c = Vx[p] or "C"
            if c == "T" then T = y elseif c == "B" then Bt = y else C = y end
        end
        local h = fr._h or fr.tplH or 14
        if T and Bt then return T, Bt end
        if T then return T, T - h end
        if Bt then return Bt + h, Bt end
        assert(C, "an anchor for " .. tostring(fr.name or fr.text))
        return C + h / 2, C - h / 2
    end
    L.span, L.vspan = span, vspan
    function L.row(name, ...)
        local prevR
        for i, fr in ipairs({ ... }) do
            local l, r = span(fr)
            assert(l >= 0 and r <= rootW, ("%s #%d leaves its frame: %d..%d of %d"):format(name, i, l, r, rootW))
            if prevR then assert(l >= prevR, ("%s #%d overlaps #%d: %d < %d"):format(name, i, i - 1, l, prevR)) end
            prevR = r
        end
    end
    function L.column(name, ...)
        local prevB
        for i, fr in ipairs({ ... }) do
            local t, b = vspan(fr)
            assert(t <= 0 and b >= -rootH, ("%s #%d leaves its frame: %d..%d of %d"):format(name, i, t, b, rootH))
            if prevB then assert(t <= prevB, ("%s #%d overlaps #%d: %d > %d"):format(name, i, i - 1, t, prevB)) end
            prevB = b
        end
    end
    -- a part lies wholly inside the root (a scroll bar, a field)
    function L.inside(name, fr)
        local l, r = span(fr)
        local t, b = vspan(fr)
        assert(l >= 0 and r <= rootW and t <= 0 and b >= -rootH,
            ("%s leaves its frame: x %d..%d of %d, y %d..%d of %d"):format(name, l, r, rootW, t, b, rootH))
    end
    function L.fits(fs)
        assert(fs:GetStringWidth() <= fs._w, ("'%s' fits %s px"):format(tostring(fs:GetText()), tostring(fs._w)))
    end
    return L
end
