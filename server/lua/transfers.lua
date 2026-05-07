local Network = require("selene.network")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local InventoryItem = require("moonlight-inventory.server.lua.inventory_item")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

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
        data = itemData[DataFields.Data] or {}
    }
end

Network.handlePayload("illarion:move_slot_to_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local fromInventory = InventoryManager.GetInventoryAtView(character, payload.fromViewId)
    local toInventory = InventoryManager.GetInventoryAtView(character, payload.toViewId)
    if not fromInventory or not toInventory then
        return
    end

    fromInventory:moveItemTo(toInventory, payload.fromSlotId, payload.toSlotId, {
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
    local character = Character.fromSelenePlayer(player)
    local targetInventory = InventoryManager.GetInventoryAtView(character, payload.toViewId)
    if not targetInventory or not targetInventory:hasSlot(payload.toSlotId) then
        return
    end

    local sourceEntity = nil
    local sourceEntities = character.SeleneEntity:getDimension():getEntitiesAt(payload.fromX, payload.fromY, payload.fromZ, character.SeleneEntity.Collision)
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
    local rest = targetInventory:addItemAt(payload.toSlotId, item)
    if rest > 0 then
        local itemData = sourceEntity:getRuntimeData(DataKeys.Item)
        itemData[DataFields.Count] = rest
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

Network.handlePayload("illarion:move_slot_to_coordinate", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local fromInventory = InventoryManager.GetInventoryAtView(character, payload.fromViewId)
    if not fromInventory then
        return
    end

    local item = fromInventory:getItem(payload.fromSlotId)
    if not item then
        return
    end

    local itemId = item.def:getMetadata("id")
    local entityType = Registries.findByMetadata("entities", "itemId", itemId)
    if not entityType then
        error("Unknown item entity for item id " .. tostring(itemId))
    end

    fromInventory:setItem(payload.fromSlotId, nil)

    local entity = Entities.create(entityType)
    entity:setCoordinate(payload.x, payload.y, payload.z)
    entity:spawn(character.SeleneEntity:getDimension())

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
