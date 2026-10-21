local Registries = require("selene.registries")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")

Character.SeleneMethods.getDepot = function(user, depotId)
    depotId = assert(tonumber(depotId), "depotId must be a number, was " .. tostring(depotId))
    return Container.fromSeleneInventory(InventoryManager.GetDepot(user, depotId))
end

Character.SeleneMethods.moveDepotContentFrom = function(user, sourcecharid, targetdepotid, sourcedepotid)
    local function id(value, name)
        local number = tonumber(value)
        assert(number and math.tointeger(number) and number >= 0 and number <= 4294967295,
            name .. " must be an unsigned integer")
        return math.tointeger(number)
    end
    sourcecharid = id(sourcecharid, "sourcecharid")
    targetdepotid = id(targetdepotid, "targetdepotid")
    sourcedepotid = id(sourcedepotid, "sourcedepotid")
    if user:getType() ~= Character.player then return false end
    return CharacterPersistence.moveDepotContentFrom(user, sourcecharid, targetdepotid, sourcedepotid)
end

Character.SeleneMethods.getBackPack = function(user, itemId)
    if itemId ~= nil then
        itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    end
    return Container.fromSeleneInventory(InventoryManager.GetBackpack(user))
end

Character.SeleneMethods.countItem = function(user, itemId)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    local count = 0
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        return 0
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
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    local count = 0
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        return 0
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
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    local inventory = InventoryManager.GetInventoryAtSlot(user, slotId)
    local inventoryItem = inventory:getInventoryItem(slotId)
    return Item.fromSeleneInventoryItem(inventoryItem)
end

Character.SeleneMethods.changeQualityAt = function(user, slotId, amount)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    amount = assert(tonumber(amount), "amount must be a number, was " .. tostring(amount))
    local inventory = InventoryManager.GetInventoryAtSlot(user, slotId)
    local inventoryItem = inventory:getInventoryItem(slotId)
    local item = Item.fromSeleneInventoryItem(inventoryItem)
    world:changeQuality(item, amount)
end

Character.SeleneMethods.increaseAtPos = function(user, slotId, amount)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    amount = assert(tonumber(amount), "amount must be a number, was " .. tostring(amount))
    local inventory = InventoryManager.GetInventoryAtSlot(user, slotId)
    local rest = inventory:increaseCountAt(slotId, amount)
    InventoryManager.UpdateBlockedHand(inventory)
    return rest
end

Character.SeleneMethods.createItem = function(user, itemId, count, quality, data, durability)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    count = assert(tonumber(count), "count must be a number, was " .. tostring(count))
    quality = assert(tonumber(quality), "quality must be a number, was " .. tostring(quality))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        return 0
    end
    local itemData = type(data) == "table" and data or {data = tonumber(data) ~= 0 and tonumber(data) or nil}
    local rest = InventoryManager.GetBelt(user):addItem({
        def = itemDef,
        count = count,
        quality = quality,
        durability = tonumber(durability) or 99,
        wear = InventoryManager.InitialWear(itemDef),
        data = itemData
    })
    if rest <= 0 then
        return 0
    end

    local backpack = InventoryManager.GetBackpack(user)
    if backpack then
        rest = backpack:addItem({
            def = itemDef,
            count = rest,
            quality = quality,
            durability = tonumber(durability) or 99,
            wear = InventoryManager.InitialWear(itemDef),
            data = itemData
        })
    end
    return rest
end

Character.SeleneMethods.createAtPos = function(user, slotId, itemId, count)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    count = assert(tonumber(count), "count must be a number, was " .. tostring(count))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to create unknown item id " .. itemId)
    end
    local inventory = InventoryManager.GetInventoryAtSlot(user, slotId)
    local item = {
        def = itemDef,
        count = count,
        wear = InventoryManager.InitialWear(itemDef)
    }
    if inventory.isEquipment
            and (not InventoryManager.CanEquipInHand(inventory, item, slotId)
                or (InventoryManager.IsTwoHandedItem(item) and count ~= 1)) then
        return count
    end
    local rest = inventory:addItemAt(slotId, item)
    InventoryManager.UpdateBlockedHand(inventory)
    return rest
end

Character.SeleneMethods.eraseItem = function(user, itemId, count, data)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    count = assert(tonumber(count), "count must be a number, was " .. tostring(count))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to erase unknown item id " .. itemId)
    end
    local filter = InventoryManager.ItemMatchesFilter(itemDef, data)
    local rest = InventoryManager.GetBelt(user):removeItem(filter, count)
    if rest > 0 then
        -- TODO Illarion skips backpack slot here
        local equipment = InventoryManager.GetEquipment(user)
        rest = equipment:removeItem(filter, rest)
        InventoryManager.UpdateBlockedHand(equipment)
    end
    if rest > 0 then
        local backpack = InventoryManager.GetBackpack(user)
        if backpack then
            rest = backpack:removeItem(filter, rest)
        end
    end
    return rest
end

Character.SeleneMethods.swapAtPos = function(user, slotId, newId, newQuality, durability)
    slotId = assert(tonumber(slotId), "slotId must be a number, was " .. tostring(slotId))
    newId = assert(tonumber(newId), "newId must be a number, was " .. tostring(newId))
    newQuality = assert(tonumber(newQuality), "newQuality must be a number, was " .. tostring(newQuality))
    local itemDef = Registries.findByMetadata("illarion:items", "id", newId)
    if not itemDef then
        error("Tried to swap to unknown item id " .. newId)
    end
    local inventory = InventoryManager.GetInventoryAtSlot(user, slotId)
    local replacement = { def = itemDef }
    if inventory.isEquipment and not InventoryManager.CanEquipInHand(inventory, replacement, slotId) then
        return false
    end
    local inventoryItem = inventory:getInventoryItem(slotId)
    local item = inventoryItem and inventoryItem:getItem()
    if item ~= nil then
        item.def = itemDef
        item.wear = InventoryManager.InitialWear(itemDef)
        if newQuality > 0 then item.quality = newQuality end
        if durability ~= nil then item.durability = durability end
        inventory:slotUpdated(slotId)
    else
        inventory:setItem(slotId, {
            def = itemDef,
            count = 1,
            quality = newQuality,
            durability = durability or 99,
            wear = InventoryManager.InitialWear(itemDef)
        })
    end
    InventoryManager.UpdateBlockedHand(inventory)
    return true
end

Character.SeleneMethods.getItemList = function(user, itemId)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Tried to list unknown item id " .. itemId)
    end
    local result = {}
    local filter = InventoryManager.ItemMatchesFilter(itemDef)
    local equipment = InventoryManager.GetEquipment(user)
    for _, inventoryItem in ipairs(equipment:findInventoryItems(filter)) do
        table.insert(result, Item.fromSeleneInventoryItem(inventoryItem))
    end
    local belt = InventoryManager.GetBelt(user)
    for _, inventoryItem in ipairs(belt:findInventoryItems(filter)) do
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

--- Returns "picked_up" for map pickup, "equipped" for carried/already held
--- items, "failed_to_pickup" for map failures, or "failed_to_equip" otherwise.
--- Updates itemRef to point to the held item on success.
Character.SeleneMethods.equipItem = function(user, itemRef)
    if type(itemRef) ~= "table" then return "failed_to_equip" end
    local equipment = InventoryManager.GetEquipment(user)
    if itemRef.SeleneEntity then
        local entity = itemRef.SeleneEntity
        local dimension = user.SeleneEntity:getDimension()
        local pos, userPos = itemRef.pos, user.pos
        if entity:getDimension() ~= dimension or pos.z ~= userPos.z
                or math.abs(pos.x - userPos.x) > 1 or math.abs(pos.y - userPos.y) > 1 then
            return "failed_to_pickup"
        end
        -- Only pick the visible top item, just as with a manual map pickup.
        local entities = dimension:getEntitiesAt(pos.x, pos.y, pos.z, user.SeleneEntity:getInteractionViewer())
        local topItem
        for i = #entities, 1, -1 do
            if entities[i]:hasTag("illarion:item") then topItem = entities[i]; break end
        end
        if topItem ~= entity then return "failed_to_pickup" end
        local pickup = require("illarion-script-loader.server.lua.lib.itemPickup")
        for _, slot in ipairs({Character.right_tool, Character.left_tool}) do
            if equipment:getItem(slot) == nil then
                local held = pickup.pickup(user, entity, equipment, slot, 1)
                if held then
                    itemRef.SeleneEntity = nil
                    itemRef.SeleneItem = held.SeleneItem
                    itemRef.SeleneInventory = held.SeleneInventory
                    itemRef.SeleneInventoryItem = held.SeleneInventoryItem
                    return "picked_up"
                end
            end
        end
        return "failed_to_pickup"
    end
    local source = itemRef.SeleneInventory
    local reference = itemRef.SeleneInventoryItem
    local item = itemRef.SeleneItem
    if source and reference and item and source:getItem(reference.slotId) == item
            and source.owner == user then
        if source == equipment and (reference.slotId == Character.right_tool
                or reference.slotId == Character.left_tool) then
            return "equipped"
        end
        -- Try empty hands before swapping a held item into the tool's old slot.
        for _, emptyOnly in ipairs({true, false}) do
            for _, slot in ipairs({Character.right_tool, Character.left_tool}) do
                local held = equipment:getItem(slot)
                if (not emptyOnly or held == nil)
                        and InventoryManager.ItemFitsEquipmentSlot(item, slot)
                        and (not held or not source.isEquipment
                            or InventoryManager.ItemFitsEquipmentSlot(held, reference.slotId))
                        and InventoryManager.CanMoveWithHands(source, reference.slotId, equipment, slot)
                        and source:moveItemTo(equipment, reference.slotId, slot, 1) then
                    InventoryManager.UpdateBlockedHand(equipment)
                    itemRef.SeleneInventory = equipment
                    itemRef.SeleneInventoryItem = equipment:getInventoryItem(slot)
                    itemRef.SeleneItem = equipment:getItem(slot)
                    return "equipped"
                end
            end
        end
    end
    return "failed_to_equip"
end
