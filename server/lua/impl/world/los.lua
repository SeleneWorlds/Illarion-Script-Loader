local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

world.SeleneMethods.LoS = function(world, startPos, endPos)
    local dimension = Dimensions.GetDefault()
    local result = {}

    local steep = math.abs(startPos.y - endPos.y) > math.abs(startPos.x - endPos.x)
    local startX = startPos.x
    local startY = startPos.y
    local endX = endPos.x
    local endY = endPos.y

    if steep then
        local swap = startX
        startX = startY
        startY = swap
        swap = endX
        endX = endY
        endY = swap
    end

    local swapped = startX > endX
    if swapped then
        local swap = startX
        startX = endX
        endX = swap
        swap = startY
        startY = endY
        endY = swap
    end

    local deltaX = endX - startX
    local deltaY = math.abs(endY - startY)
    local error = 0
    local ystep = 1
    local y = startY
    if startY > endY then
        ystep = -1
    end

    for x = startX, endX do
        if not (x == startX and y == startY) and not (x == endX and y == endY) then
            local pos = { x = x, y = y, z = startPos.z }
            if steep then
                pos.x = y
                pos.y = x
            end

            local hasCharacter = false
            local entities = dimension:GetEntitiesAt(pos)
            for _, entity in ipairs(entities) do
                if entity:HasTag("illarion:character") then
                    local blockingObject = {
                        TYPE = "CHARACTER",
                        OBJECT = Character.fromSeleneEntity(characterEntity)
                    }
                    if swapped then
                        table.insert(result, blockingObject)
                    else
                        table.insert(result, 1, blockingObject)
                    end
                    hasCharacter = true
                    break
                end
            end
            if not hasCharacter then
                local highestVolumeTile = nil
                local highestVolume = 0
                local tiles = dimension:GetTilesAt(pos)
                for _, tile in ipairs(tiles) do
                    local itemId = tile:GetMetadata("itemId")
                    if itemId then
                        local itemDef = Registries.FindByMetadata("illarion:items", "itemId", itemId)
                        local volume = itemDef:GetField("volume")
                        if volume > highestVolume then
                            highestVolume = volume
                            highestVolumeTile = tile
                        end
                    end
                end

                if highestVolume >= 5000 then
                    local blockingObject = {
                        TYPE = "ITEM",
                        OBJECT = Item.fromSeleneTile(highestVolumeTile)
                    }
                    if swapped then
                        table.insert(result, blockingObject)
                    else
                        table.insert(result, 1, blockingObject)
                    end
                end
            end
        end

        error = error + deltaY

        if 2 * error >= deltaX then
            y = y + ystep
            error = error - deltaX
        end
    end

    return result
end