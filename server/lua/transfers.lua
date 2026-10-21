local Network = require("selene.network")
local Registries = require("selene.registries")

local InventoryItem = require("moonlight-inventory.server.lua.inventory_item")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ItemEntity = require("illarion-script-loader.server.lua.lib.itemEntity")
local ItemPickup = require("illarion-script-loader.server.lua.lib.itemPickup")
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

local closeWorldContainer = ItemPickup.closeWorldContainer
local CreateItemFromEntity = ItemPickup.CreateItemFromEntity
local CreateItemSnapshot = ItemPickup.CreateItemSnapshot
local callMoveItemBeforeMove = ItemPickup.callMoveItemBeforeMove
local callMoveItemAfterMove = ItemPickup.callMoveItemAfterMove

Network.handlePayload("illarion:push_character", function(player, payload)
    local target = PayloadValidation.characterInRange(player, payload.networkId, 1)
    local x, y, z = PayloadValidation.coordinates(payload)
    if not target or target:getType() ~= Character.player or not x then
        return
    end

    local entity = target.SeleneEntity
    local source = entity:getCoordinate()
    if source:getZ() ~= z
            or math.max(math.abs(source:getX() - x), math.abs(source:getY() - y)) ~= 1 then
        return
    end

    local dimension = entity:getDimension()
    local destination = position(x, y, z)
    if not dimension or (entity:hasCollisions() and dimension:hasCollisionAt(
        destination,
        entity:getInteractionViewer()
    )) then
        return
    end

    local cost = 7
    local character = Character.fromSelenePlayer(player)
    if character.movepoints < cost then
        return
    end

    character.movepoints = character.movepoints - cost
    character:abortAction()
    entity:setCoordinate(destination)
end)

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
    local fromItem = fromInventory:getItem(fromSlotId)
    local toItem = toInventory:getItem(toSlotId)
    if (toViewId == "equipment" and not InventoryManager.ItemFitsEquipmentSlot(fromItem, toSlotId))
            or (toItem and fromViewId == "equipment" and not InventoryManager.ItemFitsEquipmentSlot(toItem, fromSlotId)) then
        return
    end
    if not InventoryManager.CanMoveWithHands(fromInventory, fromSlotId, toInventory, toSlotId) then
        return
    end
    local sourceSnapshot
    fromInventory:moveItemTo(toInventory, fromSlotId, toSlotId, count, {
        character = character,
        beforeMove = function(context, fromInventory, fromSlotId, fromItem, toInventory, toSlotId, toItem)
            local movedItem = Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(fromInventory, fromSlotId, fromItem))
            sourceSnapshot = CreateItemSnapshot(movedItem)
            local targetItem = CreateItemSnapshot(movedItem)
            targetItem.pos = toInventory.owner and toInventory.owner.pos or context.character.pos
            targetItem.owner = toInventory.owner
            targetItem.itempos = toSlotId
            targetItem.inside = toInventory.isContainer and Container.fromSeleneInventory(toInventory) or nil
            targetItem.getType = function()
                if toInventory.isContainer then
                    return scriptItem.container
                end
                return toSlotId < 12 and scriptItem.inventory or scriptItem.belt
            end
            local scriptName = fromItem.def:getField("script")
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, debug.traceback, scriptName)
                if status and type(script.MoveItemBeforeMove) == "function" then
                    return script.MoveItemBeforeMove(context.character, movedItem, targetItem)
                end
            end
            return true
        end,
        afterMove = function(context, fromInventory, fromSlotId, fromItem, toInventory, toSlotId, toItem)
            InventoryManager.UpdateBlockedHand(fromInventory)
            if toInventory ~= fromInventory then
                InventoryManager.UpdateBlockedHand(toInventory)
            end
            closeMovedContainer(context.character, fromItem)
            closeMovedContainer(context.character, toItem)
            local scriptName = fromItem.def:getField("script")
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, debug.traceback, scriptName)
                if status and type(script.MoveItemAfterMove) == "function" then
                    local targetItem = Item.fromSeleneInventoryItem(toInventory:getInventoryItem(toSlotId))
                    script.MoveItemAfterMove(context.character, sourceSnapshot, targetItem)
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
    local sourceEntities = character.SeleneEntity:getDimension():getEntitiesAt(fromX, fromY, fromZ, character.SeleneEntity:getInteractionViewer())
    for i = #sourceEntities, 1, -1 do
        local entity = sourceEntities[i]
        if entity:hasTag("illarion:item") then
            sourceEntity = entity
            break
        end
    end

    ItemPickup.pickup(character, sourceEntity, targetInventory, toSlotId, requestedCount)
end)

Network.handlePayload("illarion:move_coordinate_to_coordinate", function(player, payload)
    local fromX, fromY, fromZ = PayloadValidation.coordinateInRange(player, payload, "from", 1)
    local toX, toY, toZ = PayloadValidation.coordinateInRange(player, payload, "to", 14)
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
    if dimension:hasCollisionAt(toX, toY, toZ) then
        return
    end

    local sourceEntity = nil
    local sourceEntities = dimension:getEntitiesAt(
        fromX, fromY, fromZ,
        character.SeleneEntity:getInteractionViewer()
    )
    for i = #sourceEntities, 1, -1 do
        local entity = sourceEntities[i]
        if entity:hasTag("illarion:item") then
            sourceEntity = entity
            break
        end
    end

    if not sourceEntity or ItemMovement.isOccupied(
        sourceEntity:getDimension(), sourceEntity:getCoordinate(), character.SeleneEntity
    ) then
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

    local sourceSnapshot = CreateItemSnapshot(Item.fromSeleneEntity(sourceEntity))
    sourceSnapshot.pos = position.FromSeleneCoordinate(sourceCoordinate)
    sourceSnapshot.owner = character
    local itemData = sourceEntity:getRuntimeData(DataKeys.Item)
    local sourceCount = itemData[DataFields.Count] or 1
    local count = math.min(sourceCount, requestedCount)
    local movedEntity = ItemEntity.Create(sourceEntity:getEntityDefinition())
    local movedItemData = movedEntity:getRuntimeData(DataKeys.Item)
    movedItemData[DataFields.Count] = count
    movedItemData[DataFields.Quality] = itemData[DataFields.Quality]
    movedItemData[DataFields.Durability] = itemData[DataFields.Durability] or 99
    movedItemData[DataFields.Wear] = itemData[DataFields.Wear]
    movedItemData[DataFields.Data] = itemData[DataFields.Data] or {}
    movedItemData[DataFields.Content] = itemData[DataFields.Content]
    movedEntity:setCoordinate(toX, toY, toZ)
    local targetScriptItem = CreateItemSnapshot(Item.fromSeleneEntity(movedEntity))
    targetScriptItem.owner = character
    if not callMoveItemBeforeMove(
        character,
        sourceItem.def,
        Item.fromSeleneEntity(sourceEntity),
        targetScriptItem
    ) then
        return
    end

    if count < sourceCount then
        itemData[DataFields.Count] = sourceCount - count
        sourceEntity:updateVisuals()
    else
        sourceEntity:despawn()
    end
    movedEntity:spawn(dimension)
    closeWorldContainer(sourceItem)

    callMoveItemAfterMove(
        character,
        sourceItem.def,
        sourceSnapshot,
        Item.fromSeleneEntity(movedEntity)
    )

    local targetCoordinate = movedEntity:getCoordinate()

    local sourceTriggerfield = dimension:getAnnotationAt(
        sourceCoordinate,
        "illarion:triggerfield",
        sourceEntity.Collision
    )
    local sourceTriggerfieldEntry = sourceTriggerfield and Registries.findByName("illarion:triggerfields", sourceTriggerfield.triggerfield)
    local sourceScriptName = sourceTriggerfieldEntry and sourceTriggerfieldEntry:getField("script")
    if sourceScriptName and sourceScriptName ~= "" then
        local status, script = xpcall(require, debug.traceback, sourceScriptName)
        if status and type(script.TakeItemFromField) == "function" then
            script.TakeItemFromField(Item.fromSeleneEntity(sourceEntity), character, sourceTriggerfieldEntry)
        end
    end

    local targetTriggerfield = dimension:getAnnotationAt(
        targetCoordinate,
        "illarion:triggerfield",
        movedEntity.Collision
    )
    local targetTriggerfieldEntry = targetTriggerfield and Registries.findByName("illarion:triggerfields", targetTriggerfield.triggerfield)
    local targetScriptName = targetTriggerfieldEntry and targetTriggerfieldEntry:getField("script")
    if targetScriptName and targetScriptName ~= "" then
        local status, script = xpcall(require, debug.traceback, targetScriptName)
        if status and type(script.PutItemOnField) == "function" then
            script.PutItemOnField(Item.fromSeleneEntity(movedEntity), character, targetTriggerfieldEntry)
        end
    end
end)

local function moveSlotToCoordinate(player, payload)
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
    if not item or InventoryManager.IsBlockedHandItem(item) then
        return
    end
    local itemId = item.def:getMetadata("id")
    local entityType = Registries.findByMetadata("entities", "itemId", itemId)
    if not entityType then
        error("Unknown item entity for item id " .. tostring(itemId))
    end

    local dimension = character.SeleneEntity:getDimension()
    if not dimension or dimension:hasCollisionAt(x, y, z) then
        return
    end
    local sourceSnapshot = CreateItemSnapshot(
        Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(fromInventory, fromSlotId, item))
    )
    local sourceCount = fromInventory:getItemCount(item)
    local count = math.min(sourceCount, requestedCount)
    local entity = ItemEntity.Create(entityType)
    local entityItemData = entity:getRuntimeData(DataKeys.Item)
    local customData = item.data or {}
    entityItemData[DataFields.Count] = count
    entityItemData[DataFields.Quality] = item.quality
    entityItemData[DataFields.Durability] = item.durability or 99
    entityItemData[DataFields.Wear] = item.wear
    entityItemData[DataFields.Data] = customData
    entityItemData[DataFields.Content] = item.content
    entity:setCoordinate(x, y, z)
    local targetScriptItem = CreateItemSnapshot(Item.fromSeleneEntity(entity))
    targetScriptItem.owner = character
    if not callMoveItemBeforeMove(
        character,
        item.def,
        Item.fromSeleneInventoryItem(InventoryItem:fromInventorySlot(fromInventory, fromSlotId, item)),
        targetScriptItem
    ) then
        return
    end

    if count == sourceCount then
        fromInventory:setItem(fromSlotId, nil)
    else
        fromInventory:setItemCount(item, sourceCount - count)
        fromInventory:slotUpdated(fromSlotId)
    end
    InventoryManager.UpdateBlockedHand(fromInventory)

    entity:spawn(dimension)
    closeMovedContainer(character, item)

    callMoveItemAfterMove(
        character,
        item.def,
        sourceSnapshot,
        Item.fromSeleneEntity(entity)
    )

    local targetDimension = entity:getDimension()
    if not targetDimension then
        -- If we despawned in a move callback, abort here
        return
    end

    local triggerfieldAnnotation = targetDimension:getAnnotationAt(entity:getCoordinate(), "illarion:triggerfield", entity.Collision)
    if triggerfieldAnnotation then
        local triggerfield = Registries.findByName("illarion:triggerfields", triggerfieldAnnotation.triggerfield)
        local scriptName = triggerfield and triggerfield:getField("script")
        if scriptName and scriptName ~= "" then
            local status, script = xpcall(require, debug.traceback, scriptName)
            if status and type(script.PutItemOnField) == "function" then
                script.PutItemOnField(Item.fromSeleneEntity(entity), character, triggerfield)
            end
        end
    end
end

Network.handlePayload("illarion:move_slot_to_coordinate", moveSlotToCoordinate)

Network.handlePayload("illarion:drop_slot_in_front", function(player, payload)
    local entity = player:getControlledEntity()
    local facing = entity and entity:getFacing()
    if not facing then
        return
    end

    local target = entity:getCoordinate():offset(facing)
    moveSlotToCoordinate(player, {
        fromViewId = payload.viewId,
        fromSlotId = payload.slotId,
        x = target:getX(),
        y = target:getY(),
        z = target:getZ(),
        count = payload.count
    })
end)
