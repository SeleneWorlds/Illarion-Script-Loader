Item.SeleneGetters.id = function(item)
    if item.SeleneTile then
        return tonumber(item.SeleneTile:GetMetadata("itemId"))
    end
    return 0
end

Item.SeleneGetters.pos = function(item)
    if item.SeleneTile then
        return position.FromSeleneCoordinate(item.SeleneTile.Coordinate)
    end
    return position(0, 0, 0)
end

Item.SeleneGetters.number = function(item)
    if item.SeleneTile then
        return 1
    end
    return 0
end

Item.SeleneGetters.isLarge = function(item)
    if item.SeleneTile then
        local itemDef = Registries.FindByMetadata("illarion:items", "id", item.SeleneTile:GetMetadata("itemId"))
        return itemDef and itemDef:GetField("volume") >= 5000 or false
    end
    return false
end

Item.SeleneMethods.getType = function(item)
    if item.SeleneTile then
        return scriptItem.field
    end
    return scriptItem.notdefined
end

Item.SeleneMethods.getData = function(item, key)
    if item.SeleneTile then
        local dimension = item.SeleneTile.Dimension
        local data = dimension:GetAnnotationAt(item.SeleneTile.Coordinate, item.SeleneTile.Name)
        return data and data[key] or 0
    end
    return 0
end

Item.SeleneMethods.setData = function(item, key, value)
    if item.SeleneTile then
        local dimension = item.SeleneTile.Dimension
        local data = dimension:GetAnnotationAt(item.SeleneTile.Coordinate, item.SeleneTile.Name) or {}
        data[key] = value
        dimension:AnnotateTile(item.SeleneTile.Coordinate, item.SeleneTile.Name, data)
    end
end

function Item.fromSeleneTile(Tile)
   return setmetatable({SeleneTile = Tile}, Item.SeleneMetatable)
end

function Item.fromSeleneEmpty()
   return setmetatable({}, Item.SeleneMetatable)
end
