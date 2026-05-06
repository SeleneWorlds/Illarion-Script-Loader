local Registries = require("selene.registries")
local Entities = require("selene.entities")

local m = {}

function m.TickEntity(Entity, Data, Delta)
    Data.RotTimePassed = (Data.RotTimePassed or 0) + Delta
    local itemDef = Registries.findByMetadata("illarion:items", "id", Entity:getEntityDefinition():getMetadata("itemId"))
    local RotTicks = itemDef:getField("agingSpeed")
    if Data.RotTimePassed >= RotTicks then
        local itemNameAfterRot = itemDef:getField("objectAfterRot")
        local itemDefAfterRot = itemNameAfterRot and Registries.findByName("illarion:items", itemDef:getField("objectAfterRot")) or nil
        local EntityAfterRot = nil
        if itemDefAfterRot then
            local itemId = itemDefAfterRot:getMetadata("id")
            local entityType = Registries.findByMetadata("entities", "itemId", itemId)
            if not entityType then
                error("Unknown item entity for item id " .. tostring(itemId))
            end

            EntityAfterRot = Entities.create(entityType)
            EntityAfterRot:setCoordinate(Entity:getCoordinate())
            EntityAfterRot:spawn(Entity:getDimension())
        end

        local triggerfieldAnnotation = Entity:getDimension():getAnnotationAt(Entity:getCoordinate(), "illarion:triggerfield", Entity:getCollisionViewer())
        if triggerfieldAnnotation then
            local scriptName = triggerfieldAnnotation.script
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.ItemRotsOnField) == "function" then
                    script.ItemRotsOnField(Item.fromSeleneEntity(Entity), EntityAfterRot and Item.fromSeleneEntity(EntityAfterRot) or Item.fromSeleneEmpty())
                end
            end
        end

        Entity:despawn()
    end
end

return m