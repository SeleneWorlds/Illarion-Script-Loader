local Registries = require("selene.registries")
local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Character.SeleneMethods.getDepot = function(user, depotId)
    return Container.fromSeleneInventory(InventoryManager.GetDepot(user, depotId))
end

Character.SeleneMethods.getBackPack = function(user, itemId)
    return Container.fromSeleneInventory(InventoryManager.GetBackpack(user))
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
    local inventoryItem = container.SeleneInventory:getInventoryItem(slotId)
    if inventoryItem then
        inventoryItem.item:decrease(amount)
        local illaItem = Item.fromSeleneInventoryItem(inventoryItem)
        return true, illaItem, Container.fromSeleneInventory(InventoryManager.GetContentsContainer(illaItem))
    end
    return false, nil, nil
end

Container.SeleneMethods.viewItemNr = function(container, slotId, amount)
    local inventoryItem = container.SeleneInventory:getInventoryItem(slotId)
    if inventoryItem then
        local illaItem = Item.fromSeleneInventoryItem(inventoryItem)
        return true, illaItem, Container.fromSeleneInventory(InventoryManager.GetContentsContainer(illaItem))
    end
    return false, nil
end

Container.SeleneMethods.changeQualityAt = function(container, slotId, amount)
    local item = container.SeleneInventory:getItem(slotId)
    if item then
        world:changeQuality(item, amount)
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

function Container.fromSeleneInventory(inventory)
    if inventory == nil then
        return nil
    end
    return setmetatable({SeleneInventory = inventory}, Container.SeleneMetatable)
end

local illaDepot = require("server.depot")

Network.HandlePayload("illarion:open_container_at", function(player, payload)
    local playerEntity = player.ControlledEntity
    local dimension = playerEntity.Dimension
    local entities = dimension:GetEntitiesAt(payload.x, payload.y, payload.z, playerEntity.Collision)
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:HasTag("illarion:item") then
            -- TODO entity items
        end
    end
    local tiles = dimension:GetTilesAt(payload.x, payload.y, payload.z, playerEntity.Collision)
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:GetMetadata("itemId")
        if itemId then
            local isDepot = itemId == 321 or itemId == 4817
            local item = Item.fromSeleneTile(tile)
            if isDepot then
                local character = Character.fromSelenePlayer(player)
                if illaDepot.onOpenDepot(character, item) then
                    local inventory = InventoryManager.GetDepot(tonumber(item:getData("depot")))
                    print("opening depot " .. tablex.tostring(inventory))
                    -- TODO
                end
            else
                local inventory = InventoryManager.GetContentsContainer(item)
                -- TODO
                print("opening container " .. tablex.tostring(inventory))
            end
        end
    end
end)

Network.HandlePayload("illarion:open_container_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local inventory = nil
    if payload.viewId == "inventory" then
        inventory = InventoryManager.GetInventory(character)
    end
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(payload.slotId)
    if inventoryItem then
        local inventory = InventoryManager.GetContentsContainer(item)
        -- TODO
        print("opening item container " .. tablex.tostring(inventory))
    end
end)