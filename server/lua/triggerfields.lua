local Registries = require("selene.registries")
local Entities = require("selene.entities")
local Dimensions = require("selene.dimensions")

-- On startup, we annotate all locations that have registered trigger fields
local allTriggerFields = Registries.findAll("illarion:triggerfields")
for _, field in pairs(allTriggerFields) do
    local dimension = Dimensions.getDefault()
    dimension:getMap():annotateTile(field:getField("x"), field:getField("y"), field:getField("z"), "illarion:triggerfield", {
        script = field:getField("script")
    })
end

local function notifyItemCharacterOnField(itemId, character)
    if not itemId then
        return
    end

    local item = Registries.findByMetadata("illarion:items", "id", itemId)
    if not item or item:getField("specialItem") ~= 1 then
        return
    end

    local scriptName = item:getField("script")
    if scriptName and scriptName ~= "" then
        local status, script = xpcall(require, scriptName)
        if status and type(script.CharacterOnField) == "function" then
            script.CharacterOnField(character)
        end
    end
end

Entities.steppedOnTile:connect(function(entity, coordinate)
    local dimension = entity:getDimension()

    -- Warps are already annotated by illarion-*-map bundles
    local warpAnnotation = dimension:getAnnotationAt(coordinate, "illarion:warp", entity:getCollisionViewer())
    if warpAnnotation then
        if type(warpAnnotation.x) == "number" and type(warpAnnotation.y) == "number" and type(warpAnnotation.z) == "number" then
            entity:setCoordinate(warpAnnotation.x, warpAnnotation.y, warpAnnotation.z)
        else
            error("Invalid warp annotation at " .. coordinate)
        end
        return
    end

    -- Items with a special flag receive "CharacterOnField" events
    local character = Character.fromSeleneEntity(entity)
    local itemEntities = dimension:getEntitiesAt(coordinate, entity:getCollisionViewer())
    for _, itemEntity in ipairs(itemEntities) do
        if itemEntity:hasTag("illarion:item") then
            notifyItemCharacterOnField(itemEntity:getEntityDefinition():getMetadata("itemId"), character)
        end
    end

    local tiles = dimension:getTilesAt(coordinate, entity:getCollisionViewer())
    for _, tile in ipairs(tiles) do
        notifyItemCharacterOnField(tile:getDefinition():getMetadata("itemId"), character)
    end

    -- Trigger fields receive events when characters move onto them
    -- TODO We use this pattern a lot, it would be nice to have a helper that just gives us the script or nil.
    local triggerfieldAnnotation = dimension:getAnnotationAt(coordinate, "illarion:triggerfield", entity.Collision)
    if triggerfieldAnnotation then
        local scriptName = triggerfieldAnnotation.script
        if scriptName and scriptName ~= "" then
            local status, script = xpcall(require, scriptName)
            if status and type(script.MoveToField) == "function" then
                script.MoveToField(character)
            end
            -- Not sure what the realistic purpose of this one is.
            -- TODO In Illarion, this also fires if a character is standing on a trigger script and an item gets dropped onto it.
            if status and type(script.CharacterOnField) == "function" then
                script.CharacterOnField(character)
            end
        end
    end
end)

Entities.steppedOffTile:connect(function(entity, coordinate)
    local dimension = entity:getDimension()
    local triggerfieldAnnotation = dimension:getAnnotationAt(coordinate, "illarion:triggerfield", entity:getCollisionViewer())
    if triggerfieldAnnotation then
        local scriptName = triggerfieldAnnotation.script
        if scriptName and scriptName ~= "" then
            local status, script = xpcall(require, scriptName)
            if status and type(script.MoveFromField) == "function" then
                script.MoveFromField(Character.fromSeleneEntity(entity))
            end
        end
    end
end)
