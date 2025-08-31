Field.SeleneMethods.tile = function(field)
    local tiles = field.SeleneDimension:GetTilesAt(field.SelenePosition)
    if #tiles > 0 then
        return tiles[1]:GetMetadata("tileId")
    end
    return 0
end

Field.SeleneMethods.isPassable = function(field)
    return not field.SeleneDimension:HasCollisionAt(field.SelenePosition)
end

Field.SeleneMethods.isWarp = function(field)
    return field.SeleneDimension:GetAnnotationAt(field.SelenePosition, "illarion:warp") ~= nil
end

Field.SeleneMethods.setWarp = function(field, position)
    field.SeleneDimension:AnnotateTile(field.SelenePosition, "illarion:warp", {
        ToX = position.x,
        ToY = position.y,
        ToLevel = position.z
    })
end

Field.SeleneMethods.removeWarp = function(field)
    field.SeleneDimension:AnnotateTile(field.SelenePosition, "illarion:warp", nil)
end

Field.SeleneMethods.countItems = function(field)
    local tiles = field.SeleneDimension:GetTilesAt(field.SelenePosition)
    local count = 0
    for _, tile in ipairs(tiles) do
        if tile:GetMetadata("itemId") ~= nil then
            count = count + 1
        end
    end
    return count
end

Field.SeleneMethods.getStackItem = function(field, index)
    local tiles = field.SeleneDimension:GetTilesAt(field.SelenePosition)
    local i = -1
    for _, tile in ipairs(tiles) do
        if tile:GetMetadata("itemId") ~= nil then
            i = i + 1
            if i == index then
                return Item.fromSeleneTile(tile)
            end
        end
    end
    return Item.fromSeleneEmpty()
end

Field.SeleneMethods.getContainer = function(field, index)
    -- Illarion has a separate index for containers and abuses the item count to reference it ???
    -- This function unsurprisingly isn't used, so we're going to diverge from the API here to make it sane
    local item = field:getStackItem(index)
    local inventory = InventoryManager.GetContentsContainer(item)
    return Container.fromSeleneInventory(inventory)
end

function Field.fromSelenePosition(Dimension, Position)
    return setmetatable({ SeleneDimension = Dimension, SelenePosition = Position }, Field.SeleneMetatable)
end
