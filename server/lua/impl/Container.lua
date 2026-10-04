local Registries = require("selene.registries")
local Network = require("selene.network")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Container.SeleneMethods.countItem = function(container, itemId, data)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef, data)
    return container.SeleneInventory:countItem(filter)
end

Container.SeleneMethods.getSlotCount = function(container)
    return container.SeleneInventory:getSlotCount()
end

Container.SeleneMethods.weight = function(container)
    local weight = 0
    local items = container.SeleneInventory:findInventoryItems()
    for _, item in ipairs(items) do
        if item.def then
            weight = weight + item.def:getField("weight")
        end
    end
    return weight
end

Container.SeleneMethods.takeItemNr = function(container, slotId, amount)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    amount = assert(tonumber(amount), "amount must be a number, was " .. tostring(amount))
    local inventoryItem = container.SeleneInventory:getInventoryItem(slotId)
    if inventoryItem then
        inventoryItem.item:decrease(amount)
        local illaItem = Item.fromSeleneInventoryItem(inventoryItem)
        return true, illaItem, Container.fromSeleneInventory(InventoryManager.GetContentsContainer(illaItem))
    end
    return false, nil, nil
end

Container.SeleneMethods.viewItemNr = function(container, slotId, amount)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    local inventoryItem = container.SeleneInventory:getInventoryItem(slotId)
    if inventoryItem then
        local illaItem = Item.fromSeleneInventoryItem(inventoryItem)
        return true, illaItem, Container.fromSeleneInventory(InventoryManager.GetContentsContainer(illaItem))
    end
    return false, nil
end

Container.SeleneMethods.changeQualityAt = function(container, slotId, amount)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    amount = assert(tonumber(amount), "amount must be a number, was " .. tostring(amount))
    local inventoryItem = container.SeleneInventory:getInventoryItem(slotId)
    if inventoryItem then
        world:changeQuality(Item.fromSeleneInventoryItem(inventoryItem), amount)
        return true
    end
    return false
end

Container.SeleneMethods.insertContainer = function(container, item, childContainer, slotId)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    return container:insertItem(item, slotId)
end

Container.SeleneMethods.insertItem = function(container, item, mergeOrSlotId)
    local inventory = container.SeleneInventory
    if type(mergeOrSlotId) == "number" then
        local slotId = mergeOrSlotId
        container:addItemAt(slotId)
    else
        local merge = mergeOrSlotId or true
        if merge then
            inventory:addItem(item:toSeleneItem())
        else
            for _, slotId in ipairs(inventory:getSlots()) do
                local slotItem = inventory:getItem(slotId)
                if slotItem == nil then
                    inventory:addItemAt(slotId, item:toSeleneItem())
                    break
                end
            end
        end
    end
    return true
end

Container.SeleneMethods.eraseItem = function(container, itemId, amount, data)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    amount = assert(tonumber(amount), "amount must be a number, was " .. tostring(amount))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to erase unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef, data)
    return container.SeleneInventory.removeItem(filter, amount)
end

Container.SeleneMethods.increaseAtPos = function(container, slotId, amount)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    amount = assert(tonumber(amount), "amount must be a number, was " .. tostring(amount))
    return container.SeleneInventory:increaseCountAt(slotId, amount)
end

Container.SeleneMethods.swapAtPos = function(container, slotId, newId, newQuality)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    newId = assert(tonumber(newId), "newId must be a number, was " .. tostring(newId))
    newQuality = assert(tonumber(newQuality), "newQuality must be a number, was " .. tostring(newQuality))
    local itemDef = Registries.findByMetadata("illarion:items", "id", newId)
    if not itemDef then
        error("Tried to swap to unknown item id " .. newId)
    end
    local inventory = container.SeleneInventory
    local inventoryItem = inventory:getInventoryItem(slotId)
    local item = inventoryItem and inventoryItem:getItem()
    if item ~= nil then
        item.def = itemDef
        item.wear = InventoryManager.InitialWear(itemDef)
        if newQuality > 0 then
            Item.fromSeleneInventoryItem(inventoryItem).quality = newQuality
        end
        inventory:slotUpdated(slotId)
    else
        inventory:setItem(slotId, {
            def = itemDef,
            count = 1,
            wear = InventoryManager.InitialWear(itemDef)
        })
        Item.fromSeleneInventoryItem(inventory:getInventoryItem(slotId)).quality = newQuality
    end
    return true
end

function Container.fromSeleneInventory(inventory)
    if inventory == nil then
        return nil
    end
    return setmetatable({SeleneInventory = inventory}, Container.SeleneMetatable)
end
