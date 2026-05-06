local Registries = require("selene.registries")
local Entities = require("selene.entities")

local m = {}

function m.TickEntity(Entity, Data, Delta)
    Data.RotTimePassed = (Data.RotTimePassed or 0) + Delta
    local itemDef = Registries.FindByMetadata("illarion:items", "id", Entity.EntityDefinition:GetMetadata("itemId"))
    local RotTicks = itemDef:GetField("agingSpeed")
    if Data.RotTimePassed >= RotTicks then
        local itemNameAfterRot = itemDef:GetField("objectAfterRot")
        local itemDefAfterRot = itemNameAfterRot and Registries.FindByName("illarion:items", itemDef:GetField("objectAfterRot")) or nil
        local EntityAfterRot = nil
        if itemDefAfterRot then
            local itemId = itemDefAfterRot:GetMetadata("id")
            local entityType = Registries.FindByMetadata("entities", "itemId", itemId)
            if not entityType then
                error("Unknown item entity for item id " .. tostring(itemId))
            end

            EntityAfterRot = Entities.Create(entityType)
            EntityAfterRot:SetCoordinate(Entity.Coordinate)
            EntityAfterRot:Spawn(Entity.Dimension)
        end

        local triggerfieldAnnotation = Entity.Dimension:GetAnnotationAt(Entity.Coordinate, "illarion:triggerfield", Entity.Collision)
        if triggerfieldAnnotation then
            local scriptName = triggerfieldAnnotation.script
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.ItemRotsOnField) == "function" then
                    script.ItemRotsOnField(Item.fromSeleneEntity(Entity), EntityAfterRot and Item.fromSeleneEntity(EntityAfterRot) or Item.fromSeleneEmpty())
                end
            end
        end

        Entity:Despawn()
    end
end

return m