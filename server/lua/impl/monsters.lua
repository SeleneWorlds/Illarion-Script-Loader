local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getMonsterType = function(user)
    local entity = user.SeleneEntity
    local monsterDef = user.CustomData[DataKeys.Monster]
    if monsterDef then
        return monsterDef:GetMetadata("id")
    end
    return 0
end

Character.SeleneMethods.getLoot = function(user)
    local monsterDef = user.CustomData[DataKeys.Monster]
    if monsterDef then
        local drops = monsterDef:GetField("drops")
        local loot = {}
        for categoryId, items in pairs(drops) do
            local category = {}
            for lootId, item in pairs(items) do
                local itemDef = Registries.FindByName("illarion:items", item.item)
                if not itemDef then
                    error("Unknown item " .. item.item .. " in loot of " .. monsterDef.Name)
                end
                local itemTable = {}
                itemTable.probability = item.chance
                itemTable.itemId = itemDef:GetMetadata("id")
                itemTable.minAmount = item.minCount
                itemTable.maxAmount = item.maxCount
                itemTable.minQuality = item.minQuality
                itemTable.maxQuality = item.maxQuality
                itemTable.minDurability = item.minDurability
                itemTable.maxDurability = item.maxDurability
                itemTable.data = item.data
                category[item.lootId] = itemTable
            end
            loot[tonumber(categoryId)] = category
        end
        return loot
    end
    return {}
end

world.createMonster = function(world, monsterId, pos, movePoints)
    local monsterDef = Registries.FindByMetadata("illarion:monsters", "id", monsterId)
    if not monsterDef then
         error("Unknown monster id " .. monsterId)
    end

    local raceName = monsterDef:GetField("race")
    local race = Registries.FindByName("illarion:races", raceName)
    if not race then
        error("Unknown monster race " .. raceName)
    end

    local entity = Entities.Create(race.Name .. "_0")
    entity.CustomData[DataKeys.CharacterType] = Character.monster
    entity.CustomData[DataKeys.Race] = race
    entity.CustomData[DataKeys.Monster] = monsterDef
    entity:SetCoordinate(pos)
    entity:Spawn()
end