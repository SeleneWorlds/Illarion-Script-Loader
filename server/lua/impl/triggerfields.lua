local Registries = require("selene.registries")
local Entities = require("selene.entities")
local Dimensions = require("selene.dimensions")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")

local allTriggerFields = Registries.FindAll("illarion:triggerfields")
for _, field in pairs(allTriggerFields) do
    local dimension = Dimensions.GetDefault()
    dimension.Map:AnnotateTile(field:GetField("x"), field:GetField("y"), field:GetField("z"), "illarion:triggerfield", {
        script = field:GetField("script")
    })
end

Entities.SteppedOnTile:Connect(function(entity, coordinate)
    local dimension = entity.Dimension
    local warpAnnotation = entity:CollisionMap(coordinate):GetAnnotation(coordinate, "illarion:warp")
    if warpAnnotation then
        entity:SetCoordinate(warpAnnotation.ToX, warpAnnotation.ToY, warpAnnotation.ToLevel)
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

    local triggerfieldAnnotation = entity:CollisionMap(coordinate):GetAnnotation(coordinate, "illarion:triggerfield")
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
    local triggerfieldAnnotation = entity:CollisionMap(coordinate):GetAnnotation(coordinate, "illarion:triggerfield")
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