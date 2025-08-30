local Registries = require("selene.registries")

local Inventory = require("moonlight-inventory.server.lua.inventory")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Character.SeleneMethods.countItem = function(user, itemId)
    local count = 0
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = function(item)
        return item.def == itemDef
    end
    count = count + InventoryManager.GetBelt(user):countItem(filter)
    count = count + InventoryManager.GetEquipment(user):countItem(filter)
    count = count + InventoryManager.GetBackpack(user):countItem(filter)
    return count
end

Character.SeleneMethods.countItemAt = function(user, where, itemId, data)
    local count = 0
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = function(item)
        return item.def == itemDef -- TODO check data too
    end
    if where == "all" or where == "belt" then
        local belt = InventoryManager.GetBelt(user)
        count = count + belt:countItem(filter)
    end
    if where == "all" or where == "body" then
        local equipment = InventoryManager.GetEquipment(user)
        count = count + equipment:countItem(filter)
    end
    if where == "all" or where == "backpack" then
        local inventory = InventoryManager.GetBackpack(user)
        count = count + inventory:countItem(filter)
    end
    return count
end

Character.SeleneMethods.getItemAt = function(user, pos)
    local inventory = InventoryManager.GetInventoryByPos(user, pos)
    if inventory then
        local item = inventory:getItem("inventory:" .. pos)
        -- TODO getItemAt
    else
        -- TODO why can this be nil?
    end
    return Item.fromSeleneEmpty()
end

Character.SeleneMethods.changeQualityAt = function(user, pos, amount)
    local inventory = InventoryManager.GetInventoryByPos(user, pos)
    if not inventory then
        return
    end

    local item = inventory:getItem("inventory:" .. pos)
    -- TODO changeQualityAt
    print("changeQualityAt", tablex.tostring(item), amount)
end

Character.SeleneMethods.increaseAtPos = function(user, pos, amount)
    local inventory = InventoryManager.GetInventoryByPos(user, pos)
    if not inventory then
        return
    end

    return inventory:increaseItemAt("inventory:" .. pos, amount)
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
    if rest > 0 then
        rest = InventoryManager.GetBackpack(user):addItem({
            def = itemDef,
            count = count,
            quality = quality,
            data = data
        })
    end
    return rest
end

Character.SeleneMethods.createAtPos = function(user, pos, itemId, count)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to create unknown item id " .. itemId)
    end
    local inventory = InventoryManager.GetInventoryByPos(user, pos)
    -- TODO createAtPos
    return 0
end

Character.SeleneMethods.eraseItem = function(user, itemId, count, data)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to erase unknown item id " .. itemId)
    end
    -- TODO eraseItem
    return 0
end

Character.SeleneMethods.swapAtPos = function(user, pos, newId, newQuality)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", newId)
    if not itemDef then
        error("Tried to swap to unknown item id " .. newId)
    end
    -- TODO swapAtPos
    return 0
end

Character.SeleneMethods.getItemList = function(user, itemId)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to list unknown item id " .. itemId)
    end
    -- TODO getItemList
    return 0
end

