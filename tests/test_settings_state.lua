-- Window state may live beside a section's settings (settings.<section>.<field>, D-48), but never
-- under the name of a registered setting: ns.ApplySettings would check it as that setting and drop
-- it, or a new setting would read the window's value. The fields the pages and windows keep there:
local STATE = {
    bis = { "view", "slot", "place", "sources", "sim", "dungeon", "dsort", "dpart" },   -- UI/Pages/Gear.lua, Gear/Bis.lua, Gear/Dungeons.lua
    gear = { "class", "view", "sources", "faction", "col", "specs" },                    -- Gear/GearFrame.lua
    map = { "zone" },                                                                    -- UI/Pages/Map.lua
    professions = { "view", "sel", "search", "known" },                                  -- UI/Pages/Professions.lua
    window = { "point", "rel", "x", "y", "tab", "pages" },                               -- UI/MainFrame.lua
}
for sec, fields in pairs(STATE) do
    for _, f in ipairs(fields) do
        local path = sec .. "." .. f
        assert(NS.SettingItem(path) == nil, "window state under the name of a setting: " .. path)
    end
end
-- and the window state survives a load (the settings check leaves it alone)
AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.view, AmisiaDB.settings.bis.slot = "wish", "HEAD"
NS.ApplySettings(AmisiaDB)
assert(AmisiaDB.settings.bis.view == "wish" and AmisiaDB.settings.bis.slot == "HEAD")
