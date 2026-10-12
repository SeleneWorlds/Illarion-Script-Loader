local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

local m = {}

local function inventoryWeight(inventory, seen)
    if not inventory or seen[inventory] then return 0 end
    seen[inventory] = true
    local weight = 0
    for _, slot in ipairs(inventory:getSlots()) do
        local item = inventory:getItem(slot)
        if item then
            weight = weight + (tonumber(item.def:getField("weight")) or 0) * inventory:getItemCount(item)
            if item.content then
                weight = weight + inventoryWeight(InventoryManager.GetContentsContainer({
                    SeleneItem = item, owner = inventory.owner
                }), seen)
            end
        end
    end
    return weight
end

-- Character stats modify move duration for players, NPCs and monsters.
function m.GetMultiplier(character)
    local agility = math.min(character:increaseAttrib("agility", 0), 20)
    local seen = {}
    local weight = inventoryWeight(InventoryManager.GetEquipment(character), seen)
        + inventoryWeight(InventoryManager.GetBelt(character), seen)
    local capacity = character:increaseAttrib("strength", 0) * 500 + 5000
    local load = math.max(0, math.min(30000, weight)) / math.max(1, capacity)
    local speed = character.speed
    if speed <= 0 then speed = 1 end
    return (1 + (10 - agility) * 0.01 + load * 0.3) / speed
end

local function carriedInventories(character)
    local inventories = {}
    local function visit(inventory)
        if not inventory or inventories[inventory] then return end
        inventories[inventory] = true
        for _, slotId in ipairs(inventory:getSlots()) do
            local item = inventory:getItem(slotId)
            if item then
                -- Subscribe even to empty containers before their first item is added.
                visit(InventoryManager.GetContentsContainer({ SeleneItem = item, owner = character }))
            end
        end
    end
    visit(InventoryManager.GetEquipment(character))
    visit(InventoryManager.GetBelt(character))
    return inventories
end

function m.Configure(character)
    local entity = character.SeleneEntity
    local state = entity:getRuntimeData("illarion:movement")
    if state.cleanup then state.cleanup() end
    local inventoryObservers, attributeObservers = {}, {}
    local active = true

    local function update()
        if not active then return end
        local multiplier = m.GetMultiplier(character)
        if multiplier ~= multiplier or multiplier <= 0 or multiplier == math.huge then
            multiplier = 1
        end
        entity:setMovementDurationMultiplier(multiplier)
    end

    local function inventoryChanged()
        if not active then return end
        local inventories = carriedInventories(character)
        for inventory, observer in pairs(inventoryObservers) do
            if not inventories[inventory] then
                inventory:unsubscribe(observer)
                inventoryObservers[inventory] = nil
            end
        end
        for inventory in pairs(inventories) do
            if not inventoryObservers[inventory] then
                inventoryObservers[inventory] = inventory:subscribe(inventoryChanged)
            end
        end
        update()
    end

    state.cleanup = function()
        active = false
        for inventory, observer in pairs(inventoryObservers) do inventory:unsubscribe(observer) end
        for attribute, observer in pairs(attributeObservers) do attribute:unsubscribe(observer) end
    end
    for _, name in ipairs({ "agility", "agilityOffset", "strength", "strengthOffset", "speed" }) do
        local attribute = AttributeManager.GetAttribute(character, name)
        attributeObservers[attribute] = attribute:subscribe(update)
    end
    inventoryChanged()
end

return m
