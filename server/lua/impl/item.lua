Item.SeleneGetters.id = function(item)
    if item.SeleneTile then
        return tonumber(item.SeleneTile:GetMetadata("itemId"))
    elseif item.SeleneItem then
        return item.SeleneItem.def:GetMetadata("itemId")
    end
    return 0
end

Item.SeleneGetters.pos = function(item)
    if item.SeleneTile then
        return position.FromSeleneCoordinate(item.SeleneTile.Coordinate)
    elseif item.owner then
        return item.owner.pos
    end
    return position(0, 0, 0)
end

Item.SeleneGetters.owner = function(item)
    if item.SeleneInventory then
        return item.SeleneInventoryItem.owner
    end
    return nil
end

Item.SeleneGetters.itempos = function(item)
    if item.SeleneInventoryItem then
        return item.SeleneInventoryItem.slotId
    end
    return 0
end

Item.SeleneGetters.inside = function(item)
    if item.SeleneInventory and item.SeleneInventory.isContainer then
        return Container.fromSeleneInventory(item.SeleneInventory)
    end
    return nil
end

Item.SeleneGetters.number = function(item)
    if item.SeleneTile then
        return 1
    elseif item.SeleneItem then
        return item.SeleneItem.count
    end
    return 0
end

Item.SeleneGetters.isLarge = function(item)
    if item.SeleneTile then
        local itemDef = Registries.FindByMetadata("illarion:items", "id", item.SeleneTile:GetMetadata("itemId"))
        return itemDef and itemDef:GetField("volume") >= 5000 or false
    elseif item.SeleneItem then
        return item.SeleneItem.def:GetField("volume") >= 5000 or false
    end
    return false
end

Item.SeleneMethods.getType = function(item)
    if item.SeleneTile then
        return scriptItem.field
    elseif item.SeleneInventory and item.SeleneInventory.isContainer then
        return scriptItem.container
    elseif item.owner then
        local slotId = item.itempos
        return slotId < 12 and scriptItem.inventory or scriptItem.belt
    end
    return scriptItem.notdefined
end

Item.SeleneMethods.getData = function(item, key)
    if item.SeleneTile then
        local dimension = item.SeleneTile.Dimension
        local data = dimension:GetAnnotationAt(item.SeleneTile.Coordinate, item.SeleneTile.Name)
        return data and data[key] or ""
    elseif item.SeleneItem then
        return item.SeleneItem.data[key] or ""
    end
    return ""
end

Item.SeleneMethods.setData = function(item, key, value)
    if item.SeleneTile then
        local dimension = item.SeleneTile.Dimension
        local data = dimension:GetAnnotationAt(item.SeleneTile.Coordinate, item.SeleneTile.Name) or {}
        data[key] = tostring(value)
        dimension:AnnotateTile(item.SeleneTile.Coordinate, item.SeleneTile.Name, data)
    elseif item.SeleneItem then
        item.SeleneItem.data[key] = tostring(value)
    end
end

function Item.fromSeleneInventoryItem(inventoryItem)
    if inventoryItem == nil then
        return Item.fromSeleneEmpty()
    end
    return setmetatable({
        SeleneItem = inventoryItem.item,
        SeleneInventory = inventoryItem.inventory,
        SeleneInventoryItem = inventoryItem
    }, Item.SeleneMetatable)
end

function Item.fromSeleneTile(tile)
    if tile == nil then
        return Item.fromSeleneEmpty()
    end
   return setmetatable({SeleneTile = tile}, Item.SeleneMetatable)
end

function Item.fromSeleneEmpty()
   return setmetatable({}, Item.SeleneMetatable)
end
