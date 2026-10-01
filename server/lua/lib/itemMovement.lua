local ItemMovement = {}

local PERMANENT_WEAR = 255
local IMMOVABLE_WEIGHT = 30000

function ItemMovement.isImmovable(itemDef, wear)
    local itemWear = tonumber(wear) or 0
    local itemWeight = tonumber(itemDef and itemDef:getField("weight")) or 0
    return itemWear == PERMANENT_WEAR or itemWeight >= IMMOVABLE_WEIGHT
end

return ItemMovement
