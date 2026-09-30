local Entities = require("selene.entities")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local PayloadValidation = {}

function PayloadValidation.integer(value, minimum, maximum)
    if type(value) ~= "number" or value % 1 ~= 0 or value ~= value
            or value == math.huge or value == -math.huge then
        return nil
    end
    if minimum ~= nil and value < minimum then
        return nil
    end
    if maximum ~= nil and value > maximum then
        return nil
    end
    return value
end

function PayloadValidation.string(value, maximumLength)
    if type(value) ~= "string" or #value > maximumLength then
        return nil
    end
    return value
end

function PayloadValidation.boolean(value)
    if type(value) ~= "boolean" then
        return nil
    end
    return value
end

function PayloadValidation.oneOf(value, allowed)
    if type(value) ~= "string" or not allowed[value] then
        return nil
    end
    return value
end

function PayloadValidation.coordinates(payload, prefix)
    prefix = prefix or ""
    local xKey = prefix == "" and "x" or prefix .. "X"
    local yKey = prefix == "" and "y" or prefix .. "Y"
    local zKey = prefix == "" and "z" or prefix .. "Z"
    local x = PayloadValidation.integer(payload[xKey])
    local y = PayloadValidation.integer(payload[yKey])
    local z = PayloadValidation.integer(payload[zKey])
    if x == nil or y == nil or z == nil then
        return nil
    end
    return x, y, z
end

function PayloadValidation.coordinateInRange(player, payload, prefix, maximumRange)
    local x, y, z = PayloadValidation.coordinates(payload, prefix)
    local playerEntity = player:getControlledEntity()
    if not x or not playerEntity or type(maximumRange) ~= "number" or maximumRange < 0 then
        return nil
    end

    local coordinate = playerEntity:getCoordinate()
    if coordinate:getZ() ~= z
            or math.abs(coordinate:getX() - x) > maximumRange
            or math.abs(coordinate:getY() - y) > maximumRange then
        return nil
    end
    return x, y, z
end

function PayloadValidation.entityInRange(player, networkIdValue, maximumRange)
    local networkId = PayloadValidation.integer(networkIdValue, 0)
    local playerEntity = player:getControlledEntity()
    if not networkId or not playerEntity or type(maximumRange) ~= "number" or maximumRange < 0 then
        return nil
    end

    local entity = Entities.getByNetworkId(networkId)
    if not entity or entity:getDimension() ~= playerEntity:getDimension() then
        return nil
    end

    local coordinate = entity:getCoordinate()
    local playerCoordinate = playerEntity:getCoordinate()
    if coordinate:getZ() ~= playerCoordinate:getZ()
            or math.abs(coordinate:getX() - playerCoordinate:getX()) > maximumRange
            or math.abs(coordinate:getY() - playerCoordinate:getY()) > maximumRange then
        return nil
    end
    return entity
end

function PayloadValidation.characterInRange(player, networkIdValue, maximumRange)
    local entity = PayloadValidation.entityInRange(player, networkIdValue, maximumRange)
    local characterData = entity and entity:getRuntimeData(DataKeys.Character)
    if not characterData or not characterData[DataFields.CharacterType] then
        return nil
    end
    return Character.fromSeleneEntity(entity)
end

return PayloadValidation
