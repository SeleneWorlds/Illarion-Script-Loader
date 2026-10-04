local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

local MapPersistenceManager = require("illarion-script-loader.server.lua.lib.mapPersistenceManager")

world.SeleneMethods.getField = function(world, pos)
    local dimension = Dimensions.getDefault()
    return Field.fromSelenePosition(dimension, pos)
end

world.SeleneMethods.makePersistentAt = function(world, pos)
    local dimension = Dimensions.getDefault()
    local tiles = dimension:getTilesAt(pos)
    for _,tile in ipairs(tiles) do
        dimension:placeTile(pos, tile:getDefinition(), "persisted")
    end
    local annotations = dimension:getAnnotationsAt(pos)
    for key,data in pairs(annotations) do
        dimension:annotateTile(pos, key, data, "persisted")
    end
end

world.SeleneMethods.removePersistenceAt = function(world, pos)
    local dimension = Dimensions.getDefault()
    dimension:getMap():resetTile(pos, "persisted")
end

world.SeleneMethods.isPersistentAt = function(world, pos)
    local dimension = Dimensions.getDefault()
    local persistedTiles = dimension:getTilesAt(pos, "persisted")
    return #persistedTiles > 0
end

world.SeleneMethods.createSavedArea = function(tileId, origin, height, width)
    tileId = assert(tonumber(tileId), "tileId must be a number, was " .. tostring(tileId))
    height = assert(tonumber(height), "height must be a number, was " .. tostring(height))
    width = assert(tonumber(width), "width must be a number, was " .. tostring(width))
    local tileDef = Registries.findByMetadata("illarion:tiles", "tileId", tileId)
    if not tileDef then
        error("Unknown tile id " .. tileId)
    end
    local dimension = Dimensions.getDefault()
    for y = origin.y, origin.y + height - 1 do
        for x = origin.x, origin.x + width - 1 do
            dimension:placeTile({ x = x, y = y, z = origin.z }, tileDef, "default")
        end
    end
end

world.SeleneMethods.changeTile = function(world, tileId, pos)
    tileId = assert(tonumber(tileId), "tileId must be a number, was " .. tostring(tileId))
    local tileDef = Registries.findByMetadata("tiles", "tileId", tileId)
    if not tileDef then
        error("Unknown tile id " .. tileId)
    end
    local dimension = Dimensions.getDefault()
    local tiles = dimension:getTilesAt(pos)
    if #tiles == 0 then
        dimension:placeTile(pos, tileDef, MapPersistenceManager.getLayerFor(pos))
    else
        tiles[1]:swap(tileDef, MapPersistenceManager.getLayerFor(pos))
    end
end
