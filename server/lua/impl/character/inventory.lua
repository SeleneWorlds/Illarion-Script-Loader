local Registries = require("selene.registries")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Character.SeleneMethods.getDepot = function(user, depotId)
    return Container.fromSeleneInventory(InventoryManager.GetDepot(user, depotId))
end

Character.SeleneMethods.getBackPack = function(user, itemId)
    return Container.fromSeleneInventory(InventoryManager.GetBackpack(user))
end

Character.SeleneMethods.countItem = function(user, itemId)
    local count = 0
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef)
    count = count + InventoryManager.GetBelt(user):countItem(filter)
    count = count + InventoryManager.GetEquipment(user):countItem(filter)
    local backpack = InventoryManager.GetBackpack(user)
    if backpack then
        count = count + backpack:countItem(filter)
    end
    return count
end

Character.SeleneMethods.countItemAt = function(user, where, itemId, data)
    local count = 0
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef, data)
    if where == "all" or where == "belt" then
        local belt = InventoryManager.GetBelt(user)
        count = count + belt:countItem(filter)
    end
    if where == "all" or where == "body" then
        local equipment = InventoryManager.GetEquipment(user)
        count = count + equipment:countItem(filter)
    end
    if where == "all" or where == "backpack" then
        local backpack = InventoryManager.GetBackpack(user)
        if backpack then
            count = count + backpack:countItem(filter)
        end
    end
    return count
end

Character.SeleneMethods.getItemAt = function(user, slotId)
    local inventory = InventoryManager.GetInventory(user)
    local inventoryItem = inventory:getInventoryItem(slotId)
    return Item.fromSeleneInventoryItem(inventoryItem)
end

Character.SeleneMethods.changeQualityAt = function(user, slotId, amount)
    local inventory = InventoryManager.GetInventory(user)
    local item = inventory:getItem(slotId)
    world:changeQuality(item, amount)
end

Character.SeleneMethods.increaseAtPos = function(user, slotId, amount)
    local inventory = InventoryManager.GetInventory(user)
    return inventory:increaseCountAt(slotId, amount)
end

Character.SeleneMethods.createItem = function(user, itemId, count, quality, data)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to create unknown item id " .. itemId)
    end
    local rest = InventoryManager.GetBelt(user):addItem({
        def = itemDef,
        count = count,
        quality = quality,
        data = data
    })
    if rest <= 0 then
        return 0
    end

    local backpack = InventoryManager.GetBackpack(user)
    if backpack then
        rest = backpack:addItem({
            def = itemDef,
            count = count,
            quality = quality,
            data = data
        })
    end
    return rest
end

Character.SeleneMethods.createAtPos = function(user, slotId, itemId, count)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to create unknown item id " .. itemId)
    end
    local inventory = InventoryManager.GetInventory(user)
    return inventory:addItemAt(slotId, {
        def = itemDef,
        count = count
    })
end

Character.SeleneMethods.eraseItem = function(user, itemId, count, data)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to erase unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef, data)
    local inventory = InventoryManager.GetInventory(user)
    return inventory:removeItem(filter, count)
end

Character.SeleneMethods.swapAtPos = function(user, slotId, newId, newQuality)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", newId)
    if not itemDef then
        error("Tried to swap to unknown item id " .. newId)
    end
    local item = inventory:getItem(slotId)
    if item ~= nil then
        item.def = itemDef
        if newQuality > 0 then
            item.quality = newQuality
        end
    else
        inventory:setItem(slotId, {
            def = itemDef,
            count = 1,
            quality = newQuality
        })
    end
    return true
end

Character.SeleneMethods.getItemList = function(user, itemId)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to list unknown item id " .. itemId)
    end
    local result = {}
    local filter = InventoryManager.ItemMatchesFilter(itemDef)
    local inventory = InventoryManager.GetInventory(user)
    for _, inventoryItem in ipairs(inventory:findInventoryItems(filter)) do
        table.insert(result, Item.fromSeleneInventoryItem(inventoryItem))
    end
    local backpack = InventoryManager.GetBackpack(user)
    if backpack then
        for _, inventoryItem in ipairs(backpack:findInventoryItems(filter)) do
            table.insert(result, Item.fromSeleneInventoryItem(inventoryItem))
        end
    end
    return result
end