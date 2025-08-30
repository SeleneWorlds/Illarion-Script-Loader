local Registries = require("selene.registries")

local Inventory = require("moonlight-inventory.server.lua.inventory")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.countItem = function(user, itemId)
    local count = 0
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = function(item)
        return item.def == itemDef
    end
    count = count + user.SeleneBelt:countItem(filter)
    count = count + user.SeleneEquipment:countItem(filter)
    count = count + user.SeleneBackpack:countItem(filter)
    return count
end

Character.SeleneMethods.countItemAt = (user, where, itemId, data)
    local count = 0
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to count unknown item id " .. itemId)
    end
    local filter = function(item)
        return item.def == itemDef
    end
    if where == "all" or where == "belt" then
        local belt = user.SeleneBelt
        count = count + belt:countItem(filter)
    end
    if where == "all" or where == "body" then
        local equipment = user.SeleneEquipment
        count = count + equipment:countItem(filter)
    end
    if where == "all" or where == "backpack" then
        local inventory = user.SeleneBackpack
        count = count + inventory:countItem(filter)
    end
    return count
end

Character.SeleneMethods.getItemAt = function(user, slot)
    local inventory = user:GetSeleneInventoryByPos(pos)
    local item = inventory:getItem("inventory:" .. pos)
    -- TODO
    return Item.fromSeleneEmpty()
end

Character.SeleneMethods.changeQualityAt = function(user, pos, amount)
    local inventory = user:GetSeleneInventoryByPos(pos)
    if not inventory then
        return
    end

    local item = inventory:getItem("inventory:" .. pos)
    -- TODO changeQualityAt
    print("changeQualityAt", tablex.tostring(item), amount)
end

Character.SeleneMethods.increaseAtPos = function(user, pos, amount)
    local inventory = user:GetSeleneInventoryByPos(pos)
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
    local rest = user.SeleneBelt:addItem({
        def = itemDef,
        count = count,
        quality = quality,
        data = data
    })
    if rest then
        rest = user.SeleneBackpack:addItem({
            def = itemDef,
            count = count,
            quality = quality,
            data = data
        })
    end
    return rest and rest.count or 0
end

Character.SeleneMethods.createAtPos = function(user, pos, itemId, count)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to create unknown item id " .. itemId)
    end
    local inventory = user:GetSeleneInventoryByPos(pos)
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

Character.SeleneMethods.getBackPack = function(user, itemId)
    return Container.fromMoonlightInventory(user.SeleneBackpack)
end

Character.SeleneMethods.getDepot = function(user, depotId)
    return Container.fromMoonlightInventory(user:GetSeleneInventory("depot:" .. depotId), DepotSlotIds(depotId))
end

local equipmentSlotIds = { "inventory:0", "inventory:1", "inventory:2", "inventory:3", "inventory:4", "inventory:5", "inventory:6", "inventory:7", "inventory:8", "inventory:9", "inventory:10", "inventory:11" }
local beltSlotIds = { "inventory:12", "inventory:13", "inventory:14", "inventory:15", "inventory:16", "inventory:17" }
local backpackSlotIds = {}
local function DepotSlotIds(depotId)
    return {}
end

Character.SeleneMethods.GetSeleneInventoryByPos = function(user, pos)
    if pos < 12 then
        return user.SeleneEquipment
    elseif pos < 18 then
        return user.SeleneBelt
    end
    return nil
end

Character.SeleneMethods.GetSeleneInventory = function(user, inventoryName, slotIds)
    user.SeleneInventories = user.SeleneInventories or {}
    local inventory = user.SeleneInventories[inventoryName]
    if not inventory then
        inventory = Inventory:fromEntityAttributes(user.SeleneEntity, slotIds)
        user.SeleneInventories[inventoryName] = inventory
    end
    return inventory
end

Character.SeleneGetters.SeleneBelt = function(user)
    return user:GetSeleneInventory("belt", beltSlotIds)
end

Character.SeleneGetters.SeleneEquipment = function(user)
    return user:GetSeleneInventory("equipment", equipmentSlotIds)
end

Character.SeleneGetters.SeleneBackpack = function(user)
    return user:GetSeleneInventory("backpack", backpackSlotIds)
end