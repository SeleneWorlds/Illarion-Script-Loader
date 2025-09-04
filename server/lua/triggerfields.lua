local Registries = require("selene.registries")
local Entities = require("selene.entities")
local Dimensions = require("selene.dimensions")

local allTriggerFields = Registries.FindAll("illarion:triggerfields")
for _, field in pairs(allTriggerFields) do
    local dimension = Dimensions.GetDefault()
    dimension.Map:AnnotateTile(field:GetField("x"), field:GetField("y"), field:GetField("z"), "illarion:triggerfield", {
        script = field:GetField("script")
    })
end

Entities.SteppedOnTile:Connect(function(entity, coordinate)
    local dimension = entity.Dimension
    local warpAnnotation = dimension:GetAnnotationAt(coordinate, "illarion:warp", entity.Collision)
    if warpAnnotation then
        if type(warpAnnotation.x) == "number" and type(warpAnnotation.y) == "number" and type(warpAnnotation.z) == "number" then
            entity:SetCoordinate(warpAnnotation.x, warpAnnotation.y, warpAnnotation.z)
        else
            error("Invalid warp annotation at " .. coordinate)
        end
        return
    end

    local tiles = dimension:GetTilesAt(coordinate, entity.Collision)
    for _, tile in ipairs(tiles) do
        local itemId = tile.Definition:GetMetadata("itemId")
        if itemId then
            local item = Registries.FindByMetadata("illarion:items", "id", itemId)
            if item and item:GetField("specialItem") == 1 then
                local scriptName = item:GetField("script")
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.CharacterOnField) == "function" then
                        script.CharacterOnField(Character.fromSeleneEntity(entity))
                    end
                end
            end
        end
    end

    local triggerfieldAnnotation = dimension:GetAnnotationAt(coordinate, "illarion:triggerfield", entity.Collision)
    if triggerfieldAnnotation then
        local scriptName = triggerfieldAnnotation.script
        if scriptName then
            local status, script = pcall(require, scriptName)
            if status and type(script.MoveToField) == "function" then
                script.MoveToField(Character.fromSeleneEntity(entity))
            end
            if status and type(script.CharacterOnField) == "function" then
                script.CharacterOnField(Character.fromSeleneEntity(entity))
            end
        end
    end
end)

Entities.SteppedOffTile:Connect(function(entity, coordinate)
    local dimension = entity.Dimension
    local triggerfieldAnnotation = dimension:GetAnnotationAt(coordinate, "illarion:triggerfield", entity.Collision)
    if triggerfieldAnnotation then
        local scriptName = triggerfieldAnnotation.script
        if scriptName then
            local status, script = pcall(require, scriptName)
            if status and type(script.MoveFromField) == "function" then
                script.MoveFromField(Character.fromSeleneEntity(entity))
            end
        end
    end
end)