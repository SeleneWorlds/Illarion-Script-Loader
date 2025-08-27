local Registries = require("selene.registries")

local Inventory = require("moonlight-inventory.server.lua.inventory")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.countItem = function(user, itemId)
    local count = 0
    local items = user.SeleneEntity:GetCustomData(DataKeys.Inventory, {})
    for _, item in pairs(items) do
        if item.id == itemId then
            count = count + item.count
        end
    end
    local backpackItem = items[Character.backpack]
    if backpackItem and backpackItem.container then
        local backpack = Container.fromSeleneEntityData(user.SeleneEntity, backpackItem.container)
        count = count + backpack:countItem()
    end
    return count
end

Character.SeleneMethods.getItemAt = function(user, slot)
    local items = user.SeleneEntity:GetCustomData(DataKeys.Inventory, {})
    local item = items[slot]
    if item then
        return Item.fromSeleneEntityData(user.SeleneEntity, items, slot, item)
    end
    return Item.fromSeleneEmpty()
end

Character.SeleneMethods.createItem = function(user, itemId, count, quality, data)
    local belt = user.SeleneBelt
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to create unknown item id " .. itemId)
    end
    belt:addItem({
        name = itemDef.Name,
        count = count,
        quality = quality,
        data = data
    })
    return 0
end

local beltSlotIds = { "inventory:12", "inventory:13", "inventory:14", "inventory:15", "inventory:16", "inventory:17" }

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
