local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

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
    for _, tile in ipairs(tiles) do
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
    -- Legacy scripts change an item's id on the scriptItem and then call
    -- changeItem. The id assignment is stored directly on the Lua wrapper,
    -- while the backing Selene tile or inventory item still has its old id.
    local newId = rawget(item, "id")
    if newId ~= nil then
        if item.SeleneTile ~= nil then
            local oldId = tonumber(item.SeleneTile:getMetadata("itemId"))
            if newId ~= oldId then
                world:swap(item, newId, item.quality)
                return
            end
        elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
            item.owner:swapAtPos(item.itempos, newId, item.quality)
            return
        elseif item:getType() == scriptItem.container then
            item.inside:swapAtPos(item.itempos, newId, item.quality)
            return
        end
    end

    if item.SeleneEntity ~= nil then
        item.SeleneEntity:updateVisuals()
    end
end

world.SeleneMethods.getItemName = function(world, itemId, language)
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
    local NewTileDef = Registries.findByMetadata("tiles", "itemId", newId)
    if NewTileDef == nil then
        error("Unknown tile id " .. newId)
        return
    end

    if item:getType() == scriptItem.field then
        if item.SeleneTile ~= nil then
            local map = item.SeleneTile:getDimension():getMap()
            map:swapTile(item.SeleneTile:getCoordinate(), item.SeleneTile:getDefinition(), NewTileDef)
        end
    elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
        item.owner:swapAtPos(item.itempos, newId, newQuality)
    elseif item:getType() == scriptItem.container then
        item.inside:swapAtPos(item.itempos, newId, newQuality)
    end
end

world.SeleneMethods.createItemFromId = function(world, itemId, count, pos, always, quality, data)
    local dimension = Dimensions.getDefault()
    local tileDef = Registries.findByMetadata("tiles", "itemId", itemId)
    if not tileDef then
        error("Unknown tile for item id " .. itemId)
    end
    local tile = dimension:placeTile(pos, tileDef)
    local item = Item.fromSeleneTile(tile)
    item.quality = tonumber(quality) or 333
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
    return false, nil
end

world.SeleneMethods.getWeaponStruct = function(world, item)
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
    return false, nil
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

    if item.SeleneEntity then
        payload.networkId = item.SeleneEntity:getNetworkId()
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at_entity", payload)
    elseif item.SeleneTile then
        local coordinate = item.SeleneTile:getCoordinate()
        payload.x = coordinate.x
        payload.y = coordinate.y
        payload.z = coordinate.z
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at_coordinate", payload)
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
