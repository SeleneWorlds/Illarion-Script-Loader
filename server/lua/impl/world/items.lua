local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")
local I18n = require("selene.i18n")

world.SeleneMethods.getItemStatsFromId = function(world, itemId)
    local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
    if itemDef then
        return {
          AgeingSpeed = tonumber(itemDef:GetField("agingSpeed") or 0),
          Brightness = tonumber(itemDef:GetField("brightness") or 0),
          BuyStack = tonumber(itemDef:GetField("buyStack") or 0),
          English = itemDef:GetField("nameEnglish"),
          EnglishDescription = itemDef:GetField("descriptionEnglish"),
          German = itemDef:GetField("nameGerman"),
          GermanDescription = itemDef:GetField("descriptionGerman"),
          id = tonumber(itemDef:GetField("itemId") or 0),
          Level = tonumber(itemDef:GetField("level") or 0),
          MaxStack = tonumber(itemDef:GetField("maxStack") or 0),
          ObjectAfterRot = tonumber(itemDef:GetField("objectAfterRot") or 0),
          Rareness = tonumber(itemDef:GetField("rareness") or 0),
          rotsInInventory = itemDef:GetField("rotsInInventory"),
          Weight = tonumber(itemDef:GetField("weight") or 0),
          Worth = tonumber(itemDef:GetField("worth") or 0)
        }
    end
    return ItemStruct()
end

world.SeleneMethods.getItemOnField = function(world, position)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesAt(position)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:item") then
            return Item.fromSeleneEntity(entity)
        end
    end

    local tiles = dimension:GetTilesAt(position)
    for _, tile in ipairs(tiles) do
        if tile:HasTag("illarion:item") then
            return Item.fromSeleneTile(tile)
        end
    end

    return Item.fromSeleneEmpty()
end

world.SeleneMethods.isItemOnField = function(world, position)
    local dimension = Dimensions.GetDefault()
    local tiles = dimension:GetTilesAt(position)
    for _, tile in ipairs(tiles) do
        if tile:HasTag("illarion:item") then
            return true
        end
    end
    local entities = dimension:GetEntitiesAt(position)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:item") then
            return true
        end
    end
    return false
end

world.SeleneMethods.erase = function(world, item, amount)
    local TileDef = Registries.FindByMetadata("tiles", "itemId", item.id)
    if TileDef == nil then
        error("Missing tile for item " .. item.id)
    end

    if item:getType() == scriptItem.field then
        local dimension = Dimensions.GetDefault()
        -- TODO erase from entity items if found
        if dimension:HasTile(item.pos, TileDef) then
            dimension.Map:RemoveTile(item.pos, TileDef)
            return true
        end
    elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
        local blockedItemId = 228
        if item.itempos == Character.right_tool and (item.owner:GetItemAt(Character.left_tool)).id == blockedItemId then
            item.owner:increaseAtPos(Character.left_tool, -250);
        elseif item.itempos == Character.left_tool and (item.owner:GetItemAt(Character.right_tool)).id == blockedItemId then
            item.owner:increaseAtPos(Character.right_tool, -250);
        end

        item.owner:increaseAtPos(item.itempos, -amount);
        return true
    elseif item:getType() == scriptItem.container then
        item.inside:increaseAtPos(item.itempos, -amount)
    end
end

world.SeleneMethods.changeItem = function(world, item)
    if item.SeleneEntity ~= nil then
        item.SeleneEntity:UpdateVisuals()
    end
end

world.SeleneMethods.getItemName = function(world, itemId, language)
    local item = Registries.FindByMetadata("illarion:items", "id", itemId)
    if item then
        if language == Player.german then
            return I18n.Get("item." .. stringx.substringAfter(item.Name, "illarion:"), "de") or item.Name
        else
            return I18n.Get("item." .. stringx.substringAfter(item.Name, "illarion:"), "en") or item.Name
        end
    end

    error("Unknown item id " .. itemId)
end

world.SeleneMethods.swap = function(world, item, newId, newQuality)
    local NewTileDef = Registries.FindByMetadata("tiles", "itemId", newId)
    if NewTileDef == nil then
        error("Unknown tile id " .. newId)
        return
    end

    if item:getType() == scriptItem.field then
        if item.SeleneTile ~= nil then
            local map = item.SeleneTile.Dimension.Map
            map:SwapTile(item.SeleneTile.Coordinate, item.SeleneTile.Definition, NewTileDef)
        end
    elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
        item.owner:swapAtPos(item.itempos, newId, newQuality)
    elseif item:getType() == scriptItem.container then
        item.inside:swapAtPos(item.itempos, newId, newQuality)
    end
end

world.SeleneMethods.createItemFromId = function(world, itemId, count, pos, always, quality, data)
    local dimension = Dimensions.GetDefault()
    local tileDef = Registries.FindByMetadata("tiles", "itemId", itemId)
    if not tileDef then
        error("Unknown tile for item id " .. itemId)
    end
    local tile = dimension:PlaceTile(pos, tileDef)
    return Item.fromSeleneTile(tile)
end

world.SeleneMethods.createItemFromItem = function(world, item, pos, always)
    return world:createItemFromId(item.id, item.count, pos, always)
end

world.SeleneMethods.getArmorStruct = function(world, itemId)
    local item = Registries.FindByMetadata("illarion:items", "id", itemId)
    local armor = item and item:GetField("armor") or nil
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
    local item = Registries.FindByMetadata("illarion:items", "id", itemId)
    local weapon = item and item:GetField("weapon") or nil
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