-- The stub's frame tree as JSON for tools/ui_layout.py: every frame and region under UIParent (the
-- stub keeps them in kids), with its anchors, size, text, font object, atlas and colours. No geometry
-- here: the Python side solves the anchors, draws the snapshot and checks the layout rules.
-- Load with dofile(ADDON_DIR .. "/../tests/uidump.lua"); it returns dump(root, marks) -> JSON text
-- { "nodes": [...], "marks": { name: id } } (root is node 1; marks names frames the rules need).
-- Parts of the page scaffold (W.Page) carry lrole (layoutRole) and lband (the id of their band).
local function esc(s)
    s = tostring(s)
    s = s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
        return ("\\u%04x"):format(c:byte())
    end)
    return '"' .. s .. '"'
end

local function num(v)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "null" end
    return ("%.6g"):format(v)
end

local function list(t, enc)
    if type(t) ~= "table" then return "null" end
    local out = {}
    for i = 1, #t do out[i] = enc(t[i]) end
    return "[" .. table.concat(out, ",") .. "]"
end

-- the stub's kind of a frame or region (_kind: an addon may keep a field "kind" of its own)
local function K(f) return f._kind or (type(f.kind) == "string" and f.kind) or nil end

-- what a frame is to the rules: a chip (W.Chip), a list (W.List), a picker, a button, an edit box, a
-- check box, a scroll frame; nil for plain frames and regions
local function role(f)
    if K(f) == "FontString" or K(f) == "Texture" then return nil end
    if f.SetOn and f.UpdateChip then return "chip" end
    if f.rows and f.Redraw and f.SetItems then return "list" end
    if f.SetValues and f.arrow and f.Open then return "picker" end
    if f.arrowSet then return "arrow" end
    if K(f) == "EditBox" then return "edit" end
    if K(f) == "CheckButton" then return "check" end
    if K(f) == "ScrollFrame" then return "scroll" end
    if K(f) == "Button" then
        local t = f.template or ""
        if t:find("SharedButtonSmallTemplate", 1, true) or t:find("UIPanelButtonTemplate", 1, true) then return "button" end
        return "plain"
    end
    if f.SetCustomOnMouseUpHandler then return "tab" end
    return nil
end

-- Shown as in the client: a region until it is hidden; a frame the addon made until it is hidden (the
-- stub's frames start with shown = false, vis records the addon's own Show and Hide); a template's
-- part as the template leaves it.
local function shown(f)
    if K(f) == "FontString" or K(f) == "Texture" then return f.shown and true or false end
    if f.vis ~= nil then return f.vis end
    if f.tplPart then return f.shown and true or false end
    return true
end

return function(root, marks)
    local ids, order = {}, {}
    local function visit(f)
        if ids[f] then return end
        order[#order + 1] = f
        ids[f] = #order
        for _, k in ipairs(f.kids or {}) do visit(k) end
    end
    visit(root)
    local out = {}
    for i, f in ipairs(order) do
        local pts = {}
        for p, a in pairs(f.points or {}) do
            local rel = a.rel
            pts[#pts + 1] = ("[%s,%s,%s,%s,%s]"):format(esc(p), rel and (ids[rel] or -1) or "null",
                esc(a.relPoint or p), num(a.x), num(a.y))
        end
        table.sort(pts)
        local fields = {
            '"id":' .. i,
            '"parent":' .. (f.parent and ids[f.parent] or "null"),
            '"kind":' .. esc(K(f) or "?"),
            '"shown":' .. tostring(shown(f)),
            '"points":[' .. table.concat(pts, ",") .. "]",
        }
        local function add(k, v) if v ~= nil then fields[#fields + 1] = esc(k) .. ":" .. v end end
        add("name", type(f.name) == "string" and esc(f.name) or nil)
        add("tplPart", f.tplPart and "true" or nil)
        add("template", f.template and esc(f.template))
        add("role", role(f) and esc(role(f)))
        add("w", f._w and num(f._w))
        add("h", f._h and num(f._h))
        add("tplW", f.tplW and num(f.tplW))
        add("tplH", f.tplH and num(f.tplH))
        add("layer", f.layer and esc(f.layer))
        add("font", f.font and esc(f.font))
        add("wordWrap", f.wordWrap ~= nil and tostring(f.wordWrap) or nil)
        add("maxLines", f.maxLines and num(f.maxLines))
        add("justifyH", f.justifyH and esc(f.justifyH))
        add("atlas", f.atlas and esc(f.atlas))
        add("texture", f.texture and esc(f.texture))
        add("color", f.color and list(f.color, num))
        add("vertexColor", f.vertexColor and list(f.vertexColor, num))
        add("textColor", f.textColor and list(f.textColor, num))
        add("alpha", f.alpha and num(f.alpha))
        add("strata", f.strata and esc(f.strata))
        add("level", f._level and num(f._level))
        add("scrollChild", f.scrollChild and ids[f.scrollChild] and tostring(ids[f.scrollChild]))
        add("enabled", f.enabled ~= nil and tostring(f.enabled) or nil)
        add("on", f.on ~= nil and f.UpdateChip and tostring(f.on and true or false) or nil)
        add("scale", f._scale and num(f._scale))
        -- the page scaffold's parts (W.Page): their role and the band they sit in
        add("lrole", type(f.layoutRole) == "string" and esc(f.layoutRole) or nil)
        add("lband", f.layoutBand and ids[f.layoutBand] and tostring(ids[f.layoutBand]) or nil)
        add("emptyState", f.isEmptyState and "true" or nil)
        local text = f.text
        if type(text) == "number" then text = tostring(text) end
        if type(text) == "string" and text ~= "" then add("text", esc(text)) end
        out[i] = "{" .. table.concat(fields, ",") .. "}"
    end
    local m = {}
    for k, f in pairs(marks or {}) do
        if ids[f] then m[#m + 1] = esc(k) .. ":" .. ids[f] end
    end
    table.sort(m)
    return '{"nodes":[' .. table.concat(out, ",\n") .. '],"marks":{' .. table.concat(m, ",") .. "}}"
end
