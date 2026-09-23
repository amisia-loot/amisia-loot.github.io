-- Amisia awards: what the master looter hands out. A hand-out is remembered when GiveMasterLoot
-- runs and written as an award once the client confirms it: the loot chat line for that player
-- and item, or the loot slot being emptied. Without confirmation it is dropped after a few seconds.
-- Every loot slot keeps its own open hand-out, so a second one before the first is confirmed does
-- not push the first out.
local ADDON, ns = ...

local PENDING_TTL = 5
local pending = {}   -- loot slot -> { slot, name, item, link, src, t, token }
local lastSlot       -- slot of the latest hand-out

-- The open hand-out of a loot slot, or of the latest hand-out when no slot is given.
function ns.PendingAward(slot) return pending[slot or lastSlot or 0] end

-- Short name without the realm part.
local function shortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or nil
end

-- Name of what a loot slot came from: the drop recorded for its source, else the current target.
function ns.LootSourceName(slot)
    local s = ns.Active()
    local guid = (slot and slot > 0 and GetLootSourceInfo) and GetLootSourceInfo(slot) or nil
    if s and guid and s.drops[guid] and s.drops[guid].src ~= "?" then return s.drops[guid].src end
    local target = UnitName("target")
    if target and (not guid or guid == (UnitGUID and UnitGUID("target"))) then return target end
    return "?"
end


local function commit(a)
    local kind = ns.RollKind and ns.RollKind(a.item, a.name) or "-"
    local ok, why = ns.AddAward(a.name, a.item, kind, a.src, time())
    if ok then
        ns.msg(("Vergabe gespeichert: %s an %s (%s)."):format(a.link or ("Item " .. a.item), a.name, kind))
    elseif why then
        ns.msg(why)
    end
end

local function onGive(slot, candidate)
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local id = ns.ItemID(link)
    local name = shortName(GetMasterLootCandidate and GetMasterLootCandidate(slot, candidate))
    if not id or not name then return end
    local token = {}
    -- a new hand-out of the same slot replaces the old one: that one never arrived
    pending[slot] = { slot = slot, name = name, item = id, link = link, src = ns.LootSourceName(slot), t = time(), token = token }
    lastSlot = slot
    C_Timer.After(PENDING_TTL, function()
        if pending[slot] and pending[slot].token == token then pending[slot] = nil end
    end)
end

if type(GiveMasterLoot) == "function" then
    hooksecurefunc("GiveMasterLoot", onGive)
end

ns.OnEvent("CHAT_MSG_LOOT", function(text)
    if not next(pending) then return end
    local who, id = ns.ParseLoot(text)
    who = shortName(who)
    if not who then return end
    -- the oldest open hand-out of that item to that player: two copies of one token leave in order
    local found
    for _, a in pairs(pending) do
        if a.name == who and a.item == id and (not found or a.t < found.t or (a.t == found.t and a.slot < found.slot)) then
            found = a
        end
    end
    if found then
        pending[found.slot] = nil
        commit(found)
    end
end)

ns.OnEvent("LOOT_SLOT_CLEARED", function(slot)
    local a = slot and pending[slot]
    if a then
        pending[slot] = nil
        commit(a)
    end
end)

ns.OnEvent("LOOT_CLOSED", function() wipe(pending) end)

-- "/amisia award <Name> <Item-Link oder ID> [ms|os|sr]" and "/amisia unaward"
function ns.AwardCommand(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    if rest:lower() == "unaward" then
        local a = ns.RemoveLastAward()
        ns.msg(a and ("Vergabe entfernt: Item %d an %s."):format(a.item, a.name) or "Keine Vergabe in der laufenden Aufnahme.")
        return
    end
    local name, tail = rest:match("^(%S+)%s*(.*)$")
    if not name or name == "" then
        ns.msg("Aufruf: /amisia award <Name> <Item-Link oder ID> [ms|os|sr]")
        return
    end
    local id = ns.ItemID(tail) or tonumber(tail:match("^(%d+)"))
    if not id then
        ns.msg("Item fehlt: Link einfügen oder Item-ID angeben.")
        return
    end
    local kind = (tail:match("%s(%a%a)%s*$") or ""):upper()
    if kind ~= "MS" and kind ~= "OS" and kind ~= "SR" then kind = "-" end
    local ok, why = ns.AddAward(shortName(name), id, kind, ns.LootSourceName(0), time())
    if ok then
        ns.msg(("Vergabe gespeichert: Item %d an %s (%s)."):format(id, shortName(name), kind))
    else
        ns.msg(why)
    end
end
