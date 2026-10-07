local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

Character.SeleneMethods.getMonsterType = function(user)
    local entity = user.SeleneEntity
    local charData = entity:getRuntimeData(DataKeys.Character)
    local monsterDef = charData[DataFields.Monster]
    if monsterDef then
        return monsterDef:getMetadata("id")
    end
    return 0
end
Character.SeleneMethods.get_mon_type = Character.SeleneMethods.getMonsterType

Character.SeleneMethods.getLoot = function(user)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    local monsterDef = charData[DataFields.Monster]
    if monsterDef then
        local drops = monsterDef:getField("drops")
        local loot = {}
        for categoryId, items in pairs(drops) do
            local category = {}
            for lootId, item in pairs(items) do
                local itemDef = Registries.findByName("illarion:items", item.item)
                if not itemDef then
                    error("Unknown item " .. item.item .. " in loot of " .. monsterDef:getName())
                end
                local itemTable = {}
                itemTable.probability = item.chance
                itemTable.itemId = itemDef:getMetadata("id")
                itemTable.minAmount = item.count.min
                itemTable.maxAmount = item.count.max
                itemTable.minQuality = item.quality.min
                itemTable.maxQuality = item.quality.max
                itemTable.minDurability = item.durability.min
                itemTable.maxDurability = item.durability.max
                itemTable.data = item.data
                category[tonumber(lootId)] = itemTable
            end
            loot[tonumber(categoryId)] = category
        end
        return loot
    end
    return {}
end
