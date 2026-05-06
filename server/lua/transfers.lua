local Network = require("selene.network")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local InventoryItem = require("moonlight-inventory.server.lua.inventory_item")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local function CreateItemFromEntity(entity)
    local itemId = entity.EntityDefinition:GetMetadata("itemId")
    if itemId == nil then
        return nil
    end

    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        return nil
    end

    return {
        def = itemDef,
        count = entity.CustomData[DataKeys.Count] or 1,
        data = entity.CustomData[DataKeys.ItemData] or {}
    }
end

Network.HandlePayload("illarion:move_slot_to_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local fromInventory = InventoryManager.GetInventoryAtView(character, payload.fromViewId)
    local toInventory = InventoryManager.GetInventoryAtView(character, payload.toViewId)
    if not fromInventory or not toInventory then
        return
    end

    fromInventory:moveItemTo(toInventory, payload.fromSlotId, payload.toSlotId, {
        character = character,
        beforeMove = function(context, fromInventory, fromSlotId, fromItem, toInventory, toSlotId, toItem)
            local scriptName = fromItem.def:GetField("script")
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
        afterMove = function(context, fromInventory, fromSlotId, sourceItem, toInventory, toSlotId, targetItem)
            local scriptName = fromItem.def:GetField("script")
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

Network.HandlePayload("illarion:move_coordinate_to_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local targetInventory = InventoryManager.GetInventoryAtView(character, payload.toViewId)
    if not targetInventory or not targetInventory:hasSlot(payload.toSlotId) then
        return
    end

    local sourceEntity = nil
    local sourceEntities = character.SeleneEntity.Dimension:GetEntitiesAt(payload.fromX, payload.fromY, payload.fromZ, character.SeleneEntity.Collision)
    for i = #sourceEntities, 1, -1 do
        local entity = sourceEntities[i]
        if entity:HasTag("illarion:item") then
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
        sourceEntity.CustomData[DataKeys.Count] = rest
    else
        sourceEntity:Despawn()
    end
end)

Network.HandlePayload("illarion:move_slot_to_coordinate", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local fromInventory = InventoryManager.GetInventoryAtView(character, payload.fromViewId)
    if not fromInventory then
        return
    end

    local item = fromInventory:getItem(payload.fromSlotId)
    if not item then
        return
    end

    local itemId = item.def:GetMetadata("id")
    local entityType = Registries.FindByMetadata("entities", "itemId", itemId)
    if not entityType then
        error("Unknown item entity for item id " .. tostring(itemId))
    end

    fromInventory:setItem(payload.fromSlotId, nil)

    local entity = Entities.Create(entityType)
    entity:SetCoordinate(payload.x, payload.y, payload.z)
    entity:Spawn(character.SeleneEntity.Dimension)

    local triggerfieldAnnotation = entity.Dimension:GetAnnotationAt(entity.Coordinate, "illarion:triggerfield", entity.Collision)
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
