local Dimensions = require("selene.dimensions")

world.SeleneMethods.isCharacterOnField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesAt(pos)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:character") then
            return true
        end
    end
    return false
end

world.SeleneMethods.getCharacterOnField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesAt(pos)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:character") then
            return Character.fromSeleneEntity(entity)
        end
    end
    return nil
end

world.SeleneMethods.getCharactersInRangeOf = function(world)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesInRange(pos, range)
    local characters = {}
    for _, entity in ipairs(entities) do
        if entity.HasTag("illarion:character") then
            table.insert(characters, Character.fromSeleneEntity(entity))
        end
    end
    return characters
end
