local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ItemEntity = require("illarion-script-loader.server.lua.lib.itemEntity")

local PERMANENT_WEAR = 255

world.SeleneMethods.getItemStatsFromId = function(world, itemId)
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if itemDef then
        return {
          AgeingSpeed = tonumber(itemDef:getField("agingSpeed") or 0),
          Brightness = tonumber(itemDef:getField("brightness") or 0),
          BuyStack = tonumber(itemDef:getField("buyStack") or 0),
          English = itemDef:getField("nameEnglish"),
          EnglishDescription = itemDef:getField("descriptionEnglish"),
          German = itemDef:getField("nameGerman"),
          GermanDescription = itemDef:getField("descriptionGerman"),
          id = tonumber(itemDef:getField("itemId") or 0),
          Level = tonumber(itemDef:getField("level") or 0),
          MaxStack = tonumber(itemDef:getField("maxStack") or 0),
          ObjectAfterRot = tonumber(itemDef:getField("objectAfterRot") or 0),
          Rareness = tonumber(itemDef:getField("rareness") or 0),
          rotsInInventory = itemDef:getField("rotsInInventory"),
          Weight = tonumber(itemDef:getField("weight") or 0),
          Worth = tonumber(itemDef:getField("worth") or 0)
        }
    end
    return ItemStruct()
end

world.SeleneMethods.getItemOnField = function(world, position)
    local dimension = Dimensions.getDefault()
    local entities = dimension:getEntitiesAt(position)
    for _, entity in ipairs(entities) do
        if entity:hasTag("illarion:item") then
            return Item.fromSeleneEntity(entity)
        end
    end


    local tiles = dimension:getTilesAt(position)
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        if tile:hasTag("illarion:item") then
            return Item.fromSeleneTile(tile)
        end
    end

    return Item.fromSeleneEmpty()
end

world.SeleneMethods.isItemOnField = function(world, position)
    local dimension = Dimensions.getDefault()
    local tiles = dimension:getTilesAt(position)
    for _, tile in ipairs(tiles) do
        if tile:hasTag("illarion:item") then
            return true
        end
    end
    local entities = dimension:getEntitiesAt(position)
    for _, entity in ipairs(entities) do
        if entity:hasTag("illarion:item") then
            return true
        end
    end
    return false
end

world.SeleneMethods.erase = function(world, item, amount)
    if item:getType() == scriptItem.field then
        if item.SeleneEntity ~= nil then
            local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item) or {}
            local currentCount = itemData[DataFields.Count] or 1
            local newCount = currentCount - amount
            if newCount > 0 then
                itemData[DataFields.Count] = newCount
                item.SeleneEntity:updateVisuals()
            else
                item.SeleneEntity:despawn()
            end
            return true
        end

        local TileDef = Registries.findByMetadata("tiles", "itemId", item.id)
        if TileDef == nil then
            error("Missing tile for item " .. item.id)
        end

        local dimension = Dimensions.getDefault()
        if dimension:hasTile(item.pos, TileDef) then
            dimension:getMap():removeTile(item.pos, TileDef)
            return true
        end
    elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
        local blockedItemId = 228
        if item.itempos == Character.right_tool and (item.owner:getItemAt(Character.left_tool)).id == blockedItemId then
            item.owner:increaseAtPos(Character.left_tool, -250);
        elseif item.itempos == Character.left_tool and (item.owner:getItemAt(Character.right_tool)).id == blockedItemId then
            item.owner:increaseAtPos(Character.right_tool, -250);
        end

        item.owner:increaseAtPos(item.itempos, -amount);
        return true
    elseif item:getType() == scriptItem.container then
        item.inside:increaseAtPos(item.itempos, -amount)
    end
end

world.SeleneMethods.changeItem = function(world, item)
    local newId = tonumber(item.id) or 0
    local newNumber = tonumber(item.number) or 0
    local newQuality = tonumber(item.quality) or 0
    local newWear = tonumber(item.wear) or 0

    if item.SeleneTile ~= nil then
        local tile = item.SeleneTile
        local dimension = tile:getDimension()
        local coordinate = tile:getCoordinate()
        local tileDef = tile:getDefinition()
        if newId ~= tonumber(tile:getMetadata("itemId")) then
            tileDef = Registries.findByMetadata("tiles", "itemId", newId)
            if tileDef == nil then
                error("Unknown tile id " .. tostring(newId))
            end
            dimension:getMap():swapTile(coordinate, tile:getDefinition(), tileDef)
        end
        local data = dimension:getAnnotationAt(coordinate, tileDef:getName()) or {}
        data[DataFields.Quality] = newQuality
        data[DataFields.Wear] = newWear
        dimension:annotateTile(coordinate, tileDef:getName(), data)
    elseif item.SeleneEntity ~= nil then
        local oldId = tonumber(item.SeleneEntity:getEntityDefinition():getMetadata("itemId"))
        if newId ~= oldId then
            world:swap(item, newId, newQuality)
        end
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        itemData[DataFields.Count] = newNumber
        itemData[DataFields.Quality] = newQuality
        itemData[DataFields.Wear] = newWear
        item.SeleneEntity:updateVisuals()
    elseif item.SeleneItem ~= nil then
        local itemDef = Registries.findByMetadata("illarion:items", "id", newId)
        if itemDef == nil then
            error("Unknown item id " .. tostring(newId))
        end
        item.SeleneItem.def = itemDef
        item.SeleneItem.count = newNumber
        item.SeleneItem.quality = newQuality
        item.SeleneItem.wear = newWear
        item.SeleneInventory:slotUpdated(item.SeleneInventoryItem.slotId)
    end
end

world.SeleneMethods.getItemName = function(world, itemId, language)
    if getmetatable(itemId) == Item.SeleneMetatable then
        itemId = itemId.id
    end

    local item = Registries.findByMetadata("illarion:items", "id", itemId)
    if item then
        if language == Player.german then
            return I18n.get("item." .. stringx.substringAfter(item:getName(), "illarion:"), "de") or item:getName()
        else
            return I18n.get("item." .. stringx.substringAfter(item:getName(), "illarion:"), "en") or item:getName()
        end
    end

    error("Unknown item id " .. itemId)
end

world.SeleneMethods.swap = function(world, item, newId, newQuality)
    if item:getType() == scriptItem.field then
        if item.SeleneTile ~= nil then
            local NewTileDef = Registries.findByMetadata("tiles", "itemId", newId)
            if NewTileDef == nil then
                error("Unknown tile id " .. tostring(newId))
            end
            local map = item.SeleneTile:getDimension():getMap()
            map:swapTile(item.SeleneTile:getCoordinate(), item.SeleneTile:getDefinition(), NewTileDef)
        elseif item.SeleneEntity ~= nil then
            local itemDef = Registries.findByMetadata("illarion:items", "id", newId)
            local entityDef = Registries.findByMetadata("entities", "itemId", newId)
            if itemDef == nil or entityDef == nil then
                error("Unknown item entity for item id " .. tostring(newId))
            end

            local oldEntity = item.SeleneEntity
            local dimension = oldEntity:getDimension()
            local oldData = oldEntity:getRuntimeData(DataKeys.Item)
            local newEntity = ItemEntity.Create(entityDef)
            local newData = newEntity:getRuntimeData(DataKeys.Item)
            newData[DataFields.Count] = oldData[DataFields.Count] or 1
            newData[DataFields.Quality] = tonumber(newQuality) or 333
            newData[DataFields.Wear] = tonumber(itemDef:getField("agingSpeed")) or 0
            newData[DataFields.Data] = oldData[DataFields.Data] or {}
            newEntity:setCoordinate(oldEntity:getCoordinate())

            oldEntity:despawn()
            newEntity:spawn(dimension)
            item.SeleneEntity = newEntity
        end
    elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
        item.owner:swapAtPos(item.itempos, newId, newQuality)
    elseif item:getType() == scriptItem.container then
        item.inside:swapAtPos(item.itempos, newId, newQuality)
    end
end

world.SeleneMethods.createItemFromId = function(world, itemId, count, pos, always, quality, data)
    local dimension = Dimensions.getDefault()
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. tostring(itemId))
    end

    local agingSpeed = tonumber(itemDef:getField("agingSpeed")) or 0
    local item
    if agingSpeed == PERMANENT_WEAR then
        local tileDef = Registries.findByMetadata("tiles", "itemId", itemId)
        if not tileDef then
            error("Unknown tile for item id " .. tostring(itemId))
        end
        item = Item.fromSeleneTile(dimension:placeTile(pos, tileDef))
    else
        local entityType = Registries.findByMetadata("entities", "itemId", itemId)
        if not entityType then
            error("Unknown item entity for item id " .. tostring(itemId))
        end
        local entity = ItemEntity.Create(entityType)
        local itemData = entity:getRuntimeData(DataKeys.Item)
        itemData[DataFields.Count] = tonumber(count) or 1
        itemData[DataFields.Quality] = tonumber(quality) or 333
        itemData[DataFields.Wear] = agingSpeed
        itemData[DataFields.Data] = {}
        entity:setCoordinate(pos)
        entity:spawn(dimension)
        item = Item.fromSeleneEntity(entity)
    end

    item.quality = tonumber(quality) or 333
    item.wear = agingSpeed
    if type(data) == "table" then
        for key, value in pairs(data) do
            item:setData(key, value)
        end
    else
        local legacyData = tonumber(data)
        if legacyData and legacyData ~= 0 then
            item.data = legacyData
        end
    end
    return item
end

world.SeleneMethods.createItemFromItem = function(world, item, pos, always)
    local data = item.SeleneItem and item.SeleneItem.data or item.data
    return world:createItemFromId(item.id, item.number, pos, always, item.quality, data)
end

world.SeleneMethods.getArmorStruct = function(world, itemId)
    local item = Registries.findByMetadata("illarion:items", "id", itemId)
    local armor = item and item:getField("armor") or nil
    if armor then
        return true, {
            BodyParts = armor.bodyParts,
            PunctureArmor = armor.puncture,
            StrokeArmor = armor.stroke,
            ThrustArmor = armor.thrust,
            MagicDisturbance = armor.magicDisturbance,
            Absorb = armor.absorb,
            Stiffness = armor.stiffness,
            Type = armor.type
        }
    end
    return false, {
        BodyParts = 0,
        PunctureArmor = 0,
        StrokeArmor = 0,
        ThrustArmor = 0,
        MagicDisturbance = 0,
        Absorb = 0,
        Stiffness = 0,
        Type = 0
    }
end

world.SeleneMethods.getWeaponStruct = function(world, itemId)
    local item = Registries.findByMetadata("illarion:items", "id", itemId)
    local weapon = item and item:getField("weapon") or nil
    if weapon then
        return true, {
            Attack = weapon.attack,
            Defence = weapon.defense,
            Accuracy = weapon.accuracy,
            Range = weapon.range,
            WeaponType = weapon.weaponType,
            AmmunitionType = weapon.ammunitionType,
            ActionPoints = weapon.actionPoints,
            MagicDisturbance = weapon.magicDisturbance,
            PoisonStrength = weapon.poison
        }
    end
    return false, {
        Attack = 0,
        Defence = 0,
        Accuracy = 0,
        Range = 0,
        WeaponType = 0,
        AmmunitionType = 0,
        ActionPoints = 0,
        MagicDisturbance = 0,
        PoisonStrength = 0
    }
end

world.SeleneMethods.getItemStats = function(world, item)
    return world:getItemStatsFromId(itemOrItemId.id)
end

world.SeleneMethods.changeQuality = function(world, item, amount)
    item.quality = amount + item.durability <= 99 and amount + item.quality or item.quality - item.durability + 99
end

world.SeleneMethods.increase = function(world, item, count)
    if item.SeleneInventoryItem then
        item.SeleneInventoryItem:increase(count)
        return true
    end

    if item.SeleneTile then
        -- TODO we would have to transform the tile into an item entity at this point
    end
    return false
end

world.SeleneMethods.itemInform = function(world, user, item, text)
    local payload = {
        tooltip = {
            name = text
        }
    }

    if item.SeleneMenuItem then
        payload.id = item.SeleneMenuItem.dialogId
        payload.slotIndex = item.SeleneMenuItem.slotIndex
        payload.itemId = item.SeleneMenuItem.itemId
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at_menu_item", payload)
    elseif item.SeleneEntity then
        payload.networkId = item.SeleneEntity:getNetworkId()
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at_entity", payload)
    elseif item.SeleneTile then
        local coordinate = item.SeleneTile:getCoordinate()
        payload.x = coordinate.x
        payload.y = coordinate.y
        payload.z = coordinate.z
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at", payload)
    elseif item.SeleneInventoryItem then
        local itemType = item:getType()
        local viewId = itemType == scriptItem.belt and "belt" or itemType == scriptItem.inventory and "equipment" or nil
        if viewId then
            payload.viewId = viewId
            payload.slotId = item.SeleneInventoryItem.slotId
            Network.sendToEntity(user.SeleneEntity, "illarion:look_at_slot", payload)
        else
            Network.sendToEntity(user.SeleneEntity, "illarion:look_at", payload)
        end
    else
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at", payload)
    end
end
