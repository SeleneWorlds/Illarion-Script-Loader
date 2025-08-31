local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

world.SeleneMethods.getField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    return Field.fromSelenePosition(dimension, pos)
end

world.SeleneMethods.changeTile = function(world, tileId, pos)
    local tileDef = Registries.FindByMetadata("illarion:tiles", "tileId", tileId)
    if not tileDef then
        error("Unknown tile id " .. tileId)
    end
    local dimension = Dimensions.GetDefault()
    dimension:PlaceTile(pos, tileDef)
end