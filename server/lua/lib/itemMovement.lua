local ItemMovement = {}

local PERMANENT_WEAR = 255
local IMMOVABLE_WEIGHT = 30000

function ItemMovement.isImmovable(itemDef, wear)
    local itemWear = tonumber(wear) or 0
    local itemWeight = tonumber(itemDef and itemDef:getField("weight")) or 0
    return itemWear == PERMANENT_WEAR or itemWeight >= IMMOVABLE_WEIGHT
end

function ItemMovement.isOccupied(dimension, coordinate, pickerEntity)
    -- Check all characters, including those hidden from the interacting player.
    for _, entity in ipairs(dimension:getEntitiesAt(coordinate)) do
        if entity ~= pickerEntity and entity:hasTag("illarion:character") then
            return true
        end
    end
    return false
end

return ItemMovement
