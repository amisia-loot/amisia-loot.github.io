-- The settings in their sections (spec 2026-10-13-einstellungen-abschnitte, migration step 2, D-48):
-- a file of 2.31 keeps every changed value at the new path, the old paths are gone, the sections are
-- there with unique orders, "gear" is gone, and /amisia einstellungen finds the new ones.
local MOVED = {
    { "sync.shareUpgrades", "need.share", false },
    { "sync.askUpgrades", "need.ask", false },
    { "sync.needTooltip", "need.tooltip", false },
    { "awards.plusScope", "rolls.plusScope", "week" },
    { "awards.plusOrder", "rolls.plusOrder", true },
    { "gear.kind", "bis.kind", "Hardcore" },
    { "gear.upgradeDot", "bis.upgradeDot", false },
    { "bis.guildTooltip", "wishes.tooltip", false },
    { "bis.guildLootMark", "wishes.lootMark", false },
    { "bis.guildAward", "wishes.award", false },
    { "raidlog.benchChat", "bench.chat", false },
    { "raidlog.benchGuildOnly", "bench.guildOnly", false },
    { "raidlog.benchNotify", "bench.notify", false },
    { "raidlog.discordWipes", "discord.wipes", false },
    { "raidlog.discordLoot", "discord.loot", false },
    { "raidlog.discordNames", "discord.names", true },
    { "raidlog.discordHead", "discord.head", "@Raid heute" },
}
local core
for f in pairs(STUB.frames) do
    if f.events.PLAYER_ENTERING_WORLD and f.events.CHAT_MSG_LOOT then core = f end
end
local s = AmisiaDB.settings
for _, m in ipairs(MOVED) do
    local sec, key = m[1]:match("^(%w+)%.(%w+)$")
    s[sec] = s[sec] or {}
    s[sec][key] = m[3]
end
s.gear.class, s.gear.view = "MAGE", "list"   -- the gear table's window state stays
AmisiaDB.schema = 1
core:RegisterEvent("ADDON_LOADED")
STUB.fire("ADDON_LOADED", "Amisia")
assert(AmisiaDB.schema == #NS.MIGRATIONS)
for _, m in ipairs(MOVED) do
    local sec, key = m[1]:match("^(%w+)%.(%w+)$")
    assert(s[sec][key] == nil, "gone: " .. m[1])
    assert(NS.Get(m[2]) == m[3], m[2] .. " = " .. tostring(NS.Get(m[2])))
    assert(NS.SettingItem(m[2]), "registered: " .. m[2])
    assert(not NS.SettingItem(m[1]), "not registered any more: " .. m[1])
end
assert(s.gear.class == "MAGE" and s.gear.view == "list", "window state untouched")

-- the sections, their orders unique; no section "gear"
local orders, keys = {}, {}
for _, sec in ipairs(NS.schema) do
    assert(not orders[sec.order], ("order %s twice: %s and %s"):format(sec.order, tostring(orders[sec.order]), sec.key))
    orders[sec.order] = sec.key
    keys[sec.key] = sec
end
assert(not keys.gear, "the section gear is gone")
for _, k in ipairs({ "need", "bench", "discord", "wishes" }) do assert(keys[k], "section " .. k) end
assert(keys.bench.officer and keys.discord.officer and keys.wishes.officer and not keys.need.officer)
NS.Set("ui.view", "officer")
assert(NS.SettingsSection(NS.L["Ersatzbank"]).key == "bench")
assert(NS.SettingsSection("discord").key == "discord")
