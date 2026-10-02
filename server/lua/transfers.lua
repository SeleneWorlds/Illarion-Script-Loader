local Network = require("selene.network")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local InventoryItem = require("moonlight-inventory.server.lua.inventory_item")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ItemMovement = require("illarion-script-loader.server.lua.lib.itemMovement")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local function validViewAndSlot(payload, viewKey, slotKey)
    local viewId = PayloadValidation.string(payload[viewKey], 64)
    local slotId = PayloadValidation.integer(payload[slotKey], 0)
    return viewId, slotId
end

local function validCount(value)
    return PayloadValidation.integer(value, 1)
end

local function closeMovedContainer(character, item)
    for _, showcaseId in ipairs(InventoryManager.CloseShowcasesForItem(character, item)) do
        Network.sendToEntity(character.SeleneEntity, "illarion:close_showcase", { showcaseId = showcaseId })
    end
end

local function CreateItemFromEntity(entity)
    local itemId = entity:getEntityDefinition():getMetadata("itemId")
    if itemId == nil then
        return nil
    end

    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        return nil
    end
    local itemData = entity:getRuntimeData(DataKeys.Item)

    return {
        def = itemDef,
        count = itemData[DataFields.Count] or 1,
        quality = itemData[DataFields.Quality],
        wear = itemData[DataFields.Wear],
        data = itemData[DataFields.Data] or {},
        content = itemData[DataFields.Content]
    }
end

Network.handlePayload("illarion:move_slot_to_slot", function(player, payload)
    local fromViewId, fromSlotId = validViewAndSlot(payload, "fromViewId", "fromSlotId")
    local toViewId, toSlotId = validViewAndSlot(payload, "toViewId", "toSlotId")
    local count = validCount(payload.count)
    if not fromViewId or not fromSlotId or not toViewId or not toSlotId or not count then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local fromInventory = InventoryManager.GetInventoryAtView(character, fromViewId)
    local toInventory = InventoryManager.GetInventoryAtView(character, toViewId)
    if not fromInventory or not toInventory then
        return
    end

    if not fromInventory:hasSlot(fromSlotId) or not toInventory:hasSlot(toSlotId) then
        return
    end
    fromInventory:moveItemTo(toInventory, fromSlotId, toSlotId, count, {
        character = character,
        beforeMove = function(context, fromInventory, fromSlotId, fromItem, toInventory, toSlotId, toItem)
            local scriptName = fromItem.def:getField("script")
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.MoveItemBeforeMove) == "function" then
                    local sourceItem = Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(fromInventory, fromSlotId, fromItem))
                    local targetItem = Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(toInventory, toSlotId, toItem))
                    return script.MoveItemBeforeMove(context.character, sourceItem, targetItem)
                end
            end
            return true
        end,
        afterMove = function(context, fromInventory, fromSlotId, fromItem, toInventory, toSlotId, toItem)
            closeMovedContainer(context.character, fromItem)
            closeMovedContainer(context.character, toItem)
            local scriptName = fromItem.def:getField("script")
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.MoveItemAfterMove) == "function" then
                    local sourceItem = Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(fromInventory, fromSlotId, fromItem))
                    local targetItem = Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(toInventory, toSlotId, toItem))
                    script.MoveItemAfterMove(context.character, sourceItem, targetItem)
                end
            end
        end
    })
end)

Network.handlePayload("illarion:move_coordinate_to_slot", function(player, payload)
    local fromX, fromY, fromZ = PayloadValidation.coordinateInRange(player, payload, "from", 1)
    local toViewId, toSlotId = validViewAndSlot(payload, "toViewId", "toSlotId")
    local requestedCount = validCount(payload.count)
    if not fromX or not toViewId or not toSlotId or not requestedCount then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local targetInventory = InventoryManager.GetInventoryAtView(character, toViewId)
    if not targetInventory or not targetInventory:hasSlot(toSlotId) then
        return
    end

    local sourceEntity = nil
    local sourceEntities = character.SeleneEntity:getDimension():getEntitiesAt(fromX, fromY, fromZ, character.SeleneEntity:getCollisionViewer())
    for i = #sourceEntities, 1, -1 do
        local entity = sourceEntities[i]
        if entity:hasTag("illarion:item") then
            sourceEntity = entity
            break
        end
    end

    if not sourceEntity then
        return
    end

    local item = CreateItemFromEntity(sourceEntity)
    if not item or ItemMovement.isImmovable(item.def, item.wear) then
        return
    end
    local sourceCount = item.count
    local count = math.min(sourceCount, requestedCount)
    item.count = count
    local rest = targetInventory:addItemAt(toSlotId, item)
    local movedCount = count - rest
    if movedCount <= 0 then
        return
    end

    if movedCount < sourceCount then
        local itemData = sourceEntity:getRuntimeData(DataKeys.Item)
        itemData[DataFields.Count] = sourceCount - movedCount
        sourceEntity:updateVisuals()
    else
        local triggerfieldAnnotation = sourceEntity:getDimension():getAnnotationAt(sourceEntity:getCoordinate(), "illarion:triggerfield", sourceEntity.Collision)
        if triggerfieldAnnotation then
            local scriptName = triggerfieldAnnotation.script
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.TakeItemFromField) == "function" then
                    script.TakeItemFromField(Item.fromSeleneEntity(sourceEntity), character)
                end
            end
        end
        sourceEntity:despawn()
    end
end)

Network.handlePayload("illarion:move_coordinate_to_coordinate", function(player, payload)
    local fromX, fromY, fromZ = PayloadValidation.coordinateInRange(player, payload, "from", 1)
    local toX, toY, toZ = PayloadValidation.coordinateInRange(player, payload, "to", 1)
    local requestedCount = validCount(payload.count)
    if not fromX or not toX or not requestedCount then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local dimension = character.SeleneEntity:getDimension()
    if not dimension then
        return
    end

    local sourceEntity = nil
    local sourceEntities = dimension:getEntitiesAt(
        fromX, fromY, fromZ,
        character.SeleneEntity:getCollisionViewer()
    )
    for i = #sourceEntities, 1, -1 do
        local entity = sourceEntities[i]
        if entity:hasTag("illarion:item") then
            sourceEntity = entity
            break
        end
    end

    if not sourceEntity then
        return
    end

    local sourceItem = CreateItemFromEntity(sourceEntity)
    if not sourceItem or ItemMovement.isImmovable(sourceItem.def, sourceItem.wear) then
        return
    end

    local sourceCoordinate = sourceEntity:getCoordinate()
    if sourceCoordinate:getX() == toX
            and sourceCoordinate:getY() == toY
            and sourceCoordinate:getZ() == toZ then
        return
    end

    local itemData = sourceEntity:getRuntimeData(DataKeys.Item)
    local sourceCount = itemData[DataFields.Count] or 1
    local count = math.min(sourceCount, requestedCount)
    local movedEntity = sourceEntity

    if count < sourceCount then
        itemData[DataFields.Count] = sourceCount - count
        sourceEntity:updateVisuals()

        movedEntity = Entities.create(sourceEntity:getEntityDefinition())
        local movedItemData = movedEntity:getRuntimeData(DataKeys.Item)
        movedItemData[DataFields.Count] = count
        movedItemData[DataFields.Quality] = itemData[DataFields.Quality]
        movedItemData[DataFields.Wear] = itemData[DataFields.Wear]
        movedItemData[DataFields.Data] = itemData[DataFields.Data] or {}
        movedItemData[DataFields.Content] = itemData[DataFields.Content]
        movedEntity:setCoordinate(toX, toY, toZ)
        movedEntity:spawn(dimension)
    else
        sourceEntity:setCoordinate(toX, toY, toZ)
    end

    local targetCoordinate = movedEntity:getCoordinate()

    local sourceTriggerfield = dimension:getAnnotationAt(
        sourceCoordinate,
        "illarion:triggerfield",
        sourceEntity.Collision
    )
    if sourceTriggerfield and sourceTriggerfield.script then
        local status, script = pcall(require, sourceTriggerfield.script)
        if status and type(script.TakeItemFromField) == "function" then
            script.TakeItemFromField(Item.fromSeleneEntity(sourceEntity), character)
        end
    end

    local targetTriggerfield = dimension:getAnnotationAt(
        targetCoordinate,
        "illarion:triggerfield",
        movedEntity.Collision
    )
    if targetTriggerfield and targetTriggerfield.script then
        local status, script = pcall(require, targetTriggerfield.script)
        if status and type(script.PutItemOnField) == "function" then
            script.PutItemOnField(Item.fromSeleneEntity(movedEntity), character)
        end
    end
end)

Network.handlePayload("illarion:move_slot_to_coordinate", function(player, payload)
    local fromViewId, fromSlotId = validViewAndSlot(payload, "fromViewId", "fromSlotId")
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 14)
    local requestedCount = validCount(payload.count)
    if not fromViewId or not fromSlotId or not x or not requestedCount then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local fromInventory = InventoryManager.GetInventoryAtView(character, fromViewId)
    if not fromInventory or not fromInventory:hasSlot(fromSlotId) then
        return
    end

    local item = fromInventory:getItem(fromSlotId)
    if not item then
        return
    end
    local itemId = item.def:getMetadata("id")
    local entityType = Registries.findByMetadata("entities", "itemId", itemId)
    if not entityType then
        error("Unknown item entity for item id " .. tostring(itemId))
    end

    local sourceCount = fromInventory:getItemCount(item)
    local count = math.min(sourceCount, requestedCount)
    if count == sourceCount then
        fromInventory:setItem(fromSlotId, nil)
    else
        fromInventory:setItemCount(item, sourceCount - count)
        fromInventory:slotUpdated(fromSlotId)
    end

    local entity = Entities.create(entityType)
    local entityItemData = entity:getRuntimeData(DataKeys.Item)
    local customData = item.data or {}
    entityItemData[DataFields.Count] = count
    entityItemData[DataFields.Quality] = item.quality
    entityItemData[DataFields.Wear] = item.wear
    entityItemData[DataFields.Data] = customData
    entityItemData[DataFields.Content] = item.content
    entity:setCoordinate(x, y, z)
    entity:spawn(character.SeleneEntity:getDimension())
    closeMovedContainer(character, item)

    local triggerfieldAnnotation = entity:getDimension():getAnnotationAt(entity:getCoordinate(), "illarion:triggerfield", entity.Collision)
    if triggerfieldAnnotation then
        local scriptName = triggerfieldAnnotation.script
        if scriptName then
            local status, script = pcall(require, scriptName)
            if status and type(script.PutItemOnField) == "function" then
                script.PutItemOnField(Item.fromSeleneEntity(entity), Character.fromSeleneEntity(entity))
            end
        end
    end
end)
