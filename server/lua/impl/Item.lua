local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

Item.SeleneGetters.id = function(item)
    if item.SeleneTile then
        return tonumber(item.SeleneTile:getMetadata("itemId"))
    elseif item.SeleneEntity then
        return tonumber(item.SeleneEntity:getEntityDefinition():getMetadata("itemId"))
    elseif item.SeleneItem then
        return item.SeleneItem.def:getMetadata("id")
    end
    return 0
end

Item.SeleneGetters.pos = function(item)
    if item.SeleneTile then
        return position.FromSeleneCoordinate(item.SeleneTile:getCoordinate())
    elseif item.SeleneEntity then
        return position.FromSeleneCoordinate(item.SeleneEntity:getCoordinate())
    elseif item.owner then
        return item.owner.pos
    end
    return position(0, 0, 0)
end

Item.SeleneGetters.owner = function(item)
    if item.SeleneInventory then
        return item.SeleneInventory.owner
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
    elseif item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        return itemData and itemData[DataFields.Count] or 0
    elseif item.SeleneItem then
        return item.SeleneItem.count
    end
    return 0
end

Item.SeleneGetters.isLarge = function(item)
    if item.SeleneTile then
        local itemDef = Registries.findByMetadata("illarion:items", "id", item.SeleneTile:getMetadata("itemId"))
        return itemDef and itemDef:getField("volume") >= 5000 or false
    elseif item.SeleneEntity then
        local itemDef = Registries.findByMetadata("illarion:items", "id", item.SeleneEntity:getEntityDefinition():getMetadata("itemId"))
        return itemDef and itemDef:getField("volume") >= 5000 or false
    elseif item.SeleneItem then
        return item.SeleneItem.def:getField("volume") >= 5000 or false
    end
    return false
end

Item.SeleneGetters.wear = function(item)
    if item.SeleneTile then
        local data = item.SeleneTile:getDimension():getAnnotationAt(item.SeleneTile:getCoordinate(), item.SeleneTile:getName())
        return tonumber(data and data[DataFields.Wear]) or 0
    elseif item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        return tonumber(itemData and itemData[DataFields.Wear]) or 0
    elseif item.SeleneItem then
        return tonumber(item.SeleneItem.wear) or 0
    end
    return 0
end

Item.SeleneSetters.wear = function(item, wear)
    if item.SeleneTile then
        local dimension = item.SeleneTile:getDimension()
        local data = dimension:getAnnotationAt(item.SeleneTile:getCoordinate(), item.SeleneTile:getName()) or {}
        data[DataFields.Wear] = wear
        dimension:annotateTile(item.SeleneTile:getCoordinate(), item.SeleneTile:getName(), data)
    elseif item.SeleneEntity then
        item.SeleneEntity:getRuntimeData(DataKeys.Item)[DataFields.Wear] = wear
    elseif item.SeleneItem then
        item.SeleneItem.wear = wear
    end
end

Item.SeleneGetters.quality = function(item)
    if item.SeleneTile then
        local data = item.SeleneTile:getDimension():getAnnotationAt(item.SeleneTile:getCoordinate(), item.SeleneTile:getName())
        return tonumber(data and data[DataFields.Quality]) or 333
    elseif item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        return tonumber(itemData and itemData[DataFields.Quality]) or 333
    elseif item.SeleneItem then
        return tonumber(item.SeleneItem.quality) or 333
    end
    return 333
end

Item.SeleneSetters.quality = function(item, quality)
    if item.SeleneTile then
        local dimension = item.SeleneTile:getDimension()
        local data = dimension:getAnnotationAt(item.SeleneTile:getCoordinate(), item.SeleneTile:getName()) or {}
        data[DataFields.Quality] = quality
        dimension:annotateTile(item.SeleneTile:getCoordinate(), item.SeleneTile:getName(), data)
    elseif item.SeleneEntity then
        item.SeleneEntity:getRuntimeData(DataKeys.Item)[DataFields.Quality] = quality
    elseif item.SeleneItem then
        item.SeleneItem.quality = quality
    end
end

Item.SeleneGetters.durability = function(item)
    return item.quality % 100
end

Item.SeleneGetters.data = function(item)
    return tonumber(item:getData("data")) or 0
end

Item.SeleneSetters.data = function(item, data)
    local value = tonumber(data)
    item:setData("data", value ~= 0 and value or nil)
end

Item.SeleneMethods.getType = function(item)
    if item.SeleneTile or item.SeleneEntity then
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
        local dimension = item.SeleneTile:getDimension()
        local data = dimension:getAnnotationAt(item.SeleneTile:getCoordinate(), item.SeleneTile:getName())
        return data and data[key] or ""
    elseif item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        local itemDataMap = itemData and itemData[DataFields.Data]
        return itemDataMap and itemDataMap[key] or ""
    elseif item.SeleneItem then
        return item.SeleneItem.data and item.SeleneItem.data[key] or ""
    end
    return ""
end

Item.SeleneMethods.setData = function(item, key, value)
    if item.SeleneTile then
        local dimension = item.SeleneTile:getDimension()
        local data = dimension:getAnnotationAt(item.SeleneTile:getCoordinate(), item.SeleneTile:getName()) or {}
        data[key] = value ~= nil and tostring(value) or nil
        dimension:annotateTile(item.SeleneTile:getCoordinate(), item.SeleneTile:getName(), data)
    elseif item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        local itemDataMap = itemData[DataFields.Data] or {}
        itemDataMap[key] = value ~= nil and tostring(value) or nil
        itemData[DataFields.Data] = itemDataMap
    elseif item.SeleneItem then
        local data = item.SeleneItem.data or {}
        data[key] = value ~= nil and tostring(value) or nil
        item.SeleneItem.data = data
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

function Item.fromSeleneEntity(entity)
    if entity == nil then
        return Item.fromSeleneEmpty()
    end
   return setmetatable({SeleneEntity = entity}, Item.SeleneMetatable)
end

function Item.fromSeleneEmpty()
   return setmetatable({}, Item.SeleneMetatable)
end
