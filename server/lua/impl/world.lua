local Entities = require("selene.entities")
local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")
local Sounds = require("selene.sounds")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

world.gfx = function(world, gfxId, pos)
    local entityType = Registries.FindByMetadata("entities", "gfxId", gfxId)
    if entityType == nil then
        print("Unknown gfx id " .. gfxId)
        return
    end

    local entity = Entities.CreateTransient(entityType)
    entity:SetCoordinate(pos)
    entity:Spawn()
end

world.makeSound = function(world, soundId, pos)
    local sound = Registries.FindByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.PlaySoundAt(pos.x, pos.y, pos.z, sound)
    end
end

world.getField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    return Field.fromSelenePosition(dimension, pos)
end

world.isCharacterOnField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesAt(pos)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:player") then
            return true
        end
    end
    return false
end

world.getItemName = function(world, ItemId, Language)
    local tile = Registries.FindByMetadata("tiles", "itemId", ItemId)
    if tile then
        if Language == Player.german then
            return tile:GetMetadata("nameGerman")
        elseif Language == Player.english then
            return tile:GetMetadata("nameEnglish")
        else
            return tile:GetMetadata("nameEnglish")
        end
    end

    return "unknown_item_" .. ItemId
end

world.swap = function(world, item, newId, newQuality)
    local NewTileDef = Registries.FindByMetadata("tiles", "itemId", newId)
    if NewTileDef == nil then
        print("No such tile " .. newId) -- TODO throw an error
        return
    end

    if item:getType() == scriptItem.field then
        if item.SeleneTile ~= nil then
            local map = item.SeleneTile.Dimension.Map
            map:SwapTile(item.SeleneTile.Coordinate, item.SeleneTile, NewTileDef)
        end
    elseif item:getType() == scriptItem.inventory or item:getType() == scriptItem.belt then
        item.owner:swapAtPos(item.itempos, newId, newQuality)
    elseif item:getType() == scriptItem.container then
        item.inside:swapAtPos(item.itempos, newId, newQuality)
    end
end

world.erase = function(world, item, amount)
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

world.changeItem = function(world, item)
    if item.SeleneEntity ~= nil then
        item.SeleneEntity:UpdateVisuals()
    end
end

world.getItemOnField = function(world, position)
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

world.isItemOnField = function(world, position)
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

world.getItemStatsFromId = function(world, itemId)
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

world.getTime = function(world, timeType)
    local illarionBirthTime = 950742000
    local illarionTimeFactor = 3

    if timeType == "unix" then
        return os.time()
    end

    local curr_unixtime = os.time()
    local timestamp = os.date("*t", curr_unixtime)
    local illaTime = curr_unixtime
    local secondsInHour = 60 * 60

    if timestamp.isdst then
        illaTime = illaTime + secondsInHour
    end

    illaTime = (illaTime - illarionBirthTime) * illarionTimeFactor

    if timeType == "illarion" then
        return illaTime
    end

    local secondsInYear = 60 * 60 * 24 * 365
    local year = math.floor(illaTime / secondsInYear)
    illaTime = illaTime - year * secondsInYear

    local secondsInDay = 60 * 60 * 24
    local day = math.floor(illaTime / secondsInDay)
    illaTime = illaTime - day * secondsInDay
    day = day + 1

    local daysInIllarionMonth = 24
    local daysInLastIllarionMonth = 5
    local monthsInIllarionYear = 16
    local month = math.floor(day / daysInIllarionMonth)
    day = day - month * daysInIllarionMonth

    if day == 0 then
        if month > 0 and month < monthsInIllarionYear then
            day = daysInIllarionMonth
        else
            day = daysInLastIllarionMonth
        end
    else
        month = month + 1
    end

    if month == 0 then
        month = monthsInIllarionYear
        year = year - 1
    end

    if timeType == "year" then
        return year
    elseif timeType == "month" then
        return month
    elseif timeType == "day" then
        return day
    end

    local hour = math.floor(illaTime / secondsInHour)
    illaTime = illaTime - hour * secondsInHour

    local secondsInMinute = 60
    local minute = math.floor(illaTime / secondsInMinute)
    illaTime = illaTime - minute * secondsInMinute

    if timeType == "hour" then
        return hour
    elseif timeType == "minute" then
        return minute
    elseif timeType == "second" then
        return illaTime
    end

    return -1
end

world.createItemFromId = function(world, itemId, count, pos, always, quality, data)
    local dimension = Dimensions.GetDefault()
    local tileDef = Registries.FindByMetadata("tiles", "itemId", itemId)
    if not tileDef then
        error("Unknown tile for item id " .. itemId)
    end
    local tile = dimension:PlaceTile(pos, tileDef)
    return Item.fromSeleneTile(tile)
end

world.getMonstersInRangeOf = function(world, pos, range)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesInRange(pos, range)
    local monsters = {}
    for _, entity in ipairs(entities) do
        if entity.CustomData[DataKeys.CharacterType] == Character.monster then
            table.insert(monsters, Character.fromSeleneEntity(entity))
        end
    end
    return monsters
end