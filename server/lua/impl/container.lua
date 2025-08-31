local Registries = require("selene.registries")
local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Character.SeleneMethods.getDepot = function(user, depotId)
    return Container.fromMoonlightInventory(InventoryManager.GetDepot(user, depotId))
end

Character.SeleneMethods.getBackPack = function(user, itemId)
    return Container.fromMoonlightInventory(InventoryManager.GetBackpack(user))
end

Container.SeleneMethods.countItem = function(container, itemId, data)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
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
            weight = weight + item.def:GetField("weight")
        end
    end
    return weight
end

Container.SeleneMethods.takeItemNr = function(container, slotId, amount)
    local item = container.SeleneInventory:getItem(slotId)
    if item then
        item:decrease(amount)
        return true, item, Container.fromMoonlightInventory(InventoryManager.GetItemChildInventory(item))
    end
    return false, nil, nil
end

Container.SeleneMethods.viewItemNr = function(container, slotId, amount)
    local item = container.SeleneInventory:getItem(slotId)
    if item then
        return true, item, Container.fromMoonlightInventory(InventoryManager.GetItemChildInventory(item))
    end
    return false, nil
end

Container.SeleneMethods.changeQualityAt = function(container, slotId, amount)
    local item = container.SeleneInventory:getItem(slotId)
    if item then
        InventoryManager.SetItemQuality(item, amount)
        return true
    end
    return false
end

Container.SeleneMethods.insertContainer = function(container, item, childContainer, slotId)
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
            inventory:addItem(item:ToSeleneItem())
        else
            for _, slotId in ipairs(inventory:getSlots()) do
                local slotItem = inventory:getItem(slotId)
                if slotItem == nil then
                    inventory:addItemAt(slotId, item:ToSeleneItem())
                    break
                end
            end
        end
    end
    return true
end

Container.SeleneMethods.eraseItem = function(container, itemId, amount, data)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to erase unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef, data)
    return container.SeleneInventory.removeItem(filter, amount)
end

Container.SeleneMethods.increaseAtPos = function(container, slotId, amount)
    return container.SeleneInventory:increaseCountAt(slotId, amount)
end

Container.SeleneMethods.swapAtPos = function(container, slotId, newId, newQuality)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", newId)
    if not itemDef then
        error("Tried to swap to unknown item id " .. newId)
    end
    local inventory = container.SeleneInventory
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

function Container.fromMoonlightInventory(inventory)
    return setmetatable({SeleneInventory = inventory}, Container.SeleneMetatable)
end

Network.HandlePayload("illarion:open_container_at", function(player, payload)
    -- TODO open_container_at
end)

Network.HandlePayload("illarion:open_container_slot", function(player, payload)
    -- TODO open_container_slot
end)