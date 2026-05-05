local Network = require("selene.network")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

Network.HandlePayload("illarion:move_slot_to_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local fromInventory = InventoryManager.GetInventoryAtView(character, payload.fromViewId)
    local toInventory = InventoryManager.GetInventoryAtView(character, payload.toViewId)
    if not fromInventory or not toInventory then
        return
    end

    fromInventory:moveItemTo(toInventory, payload.fromSlotId, payload.toSlotId)
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
