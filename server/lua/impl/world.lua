local Entities = require("selene.entities")
local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")
local Sounds = require("selene.sounds")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")

world.SeleneMethods.gfx = function(world, gfxId, pos)
    local entityType = Registries.FindByMetadata("entities", "gfxId", gfxId)
    if entityType == nil then
        print("Unknown gfx id " .. gfxId)
        return
    end

    local entity = Entities.CreateTransient(entityType)
    entity:SetCoordinate(pos)
    entity:Spawn()
end

world.SeleneMethods.makeSound = function(world, soundId, pos)
    local sound = Registries.FindByMetadata("sounds", "soundId", soundId)
    if sound ~= nil then
        Sounds.PlaySoundAt(pos.x, pos.y, pos.z, sound)
    end
end

world.SeleneMethods.getField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    return Field.fromSelenePosition(dimension, pos)
end

world.SeleneMethods.isCharacterOnField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesAt(pos)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:character") then
            return true
        end
    end
    return false
end

world.SeleneMethods.getCharacterOnField = function(world, pos)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesAt(pos)
    for _, entity in ipairs(entities) do
        if entity:HasTag("illarion:character") then
            return Character.fromSeleneEntity(entity)
        end
    end
    return nil
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

world.SeleneMethods.getTime = function(world, timeType)
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

world.SeleneMethods.getMonstersInRangeOf = function(world, pos, range)
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

world.SeleneMethods.getNPCSInRangeOf = function(world, pos, range)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesInRange(pos, range)
    local npcs = {}
    for _, entity in ipairs(entities) do
        if entity.CustomData[DataKeys.CharacterType] == Character.npc then
            table.insert(npcs, Character.fromSeleneEntity(entity))
        end
    end
    return npcs
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
            Absorb = armor.absorb
            Stiffness = armor.stiffness
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

world.SeleneMethods.getNaturalArmor = function(world, raceId)
     local race = Registries.FindByMetadata("illarion:races", "id", raceId)
     local naturalArmor = race and race:GetField("naturalArmor") or nil
     if naturalArmor then
         return true, {
             strokeArmor = naturalArmor.strokeArmor,
             punctureArmor = naturalArmor.thrustArmor,
             thrustArmor = naturalArmor.punctureArmor
         }
     end
     return false, nil
end

world.SeleneMethods.getMonsterAttack = function(world, raceId)
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    local monsterAttack = race and race:GetField("monsterAttack") or nil
    if monsterAttack then
        return true, {
            attackType = monsterAttack.attackType,
            attackValue = monsterAttack.attackValue,
            actionPointsLost = monsterAttack.actionPointsLost,
        }
    end
    return false, nil
end

world.SeleneMethods.getItemStats = function(world, item)
    return world:getItemStatsFromId(itemOrItemId.id)
end

world.SeleneMethods.getPlayerIdByName = function(world, name)
    local player = PlayerManager.getPlayerByCharacterName(name)
    if player and player.ControlledEntity then
        return true, player.ControlledEntity.CustomData[DataKeys.ID]
    end
    return false, nil
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

world.SeleneMethods.getCharactersInRangeOf = function(world)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesInRange(pos, range)
    local characters = {}
    for _, entity in ipairs(entities) do
        if entity.HasTag("illarion:character") then
            table.insert(characters, Character.fromSeleneEntity(entity))
        end
    end
    return characters
end

world.SeleneMethods.changeTile = function(world, tileId, pos)
    local tileDef = Registries.FindByMetadata("illarion:tiles", "tileId", tileId)
    if not tileDef then
        error("Unknown tile id " .. tileId)
    end
    local dimension = Dimensions.GetDefault()
    dimension:PlaceTile(pos, tileDef)
end

world.SeleneMethods.sendMonitoringMessage = function(world, message, type)
    local webhookUrl = Config.GetProperty("notifyAdminDiscordWebhook")
    HTTP.Post(webhookUrl, { content = message })
end
