local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

world.SeleneMethods.getField = function(world, pos)
    local dimension = Dimensions.getDefault()
    return Field.fromSelenePosition(dimension, pos)
end

world.SeleneMethods.changeTile = function(world, tileId, pos)
    local tileDef = Registries.findByMetadata("illarion:tiles", "tileId", tileId)
    if not tileDef then
        error("Unknown tile id " .. tileId)
    end
    local dimension = Dimensions.getDefault()
    dimension:placeTile(pos, tileDef)
end