local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getMonsterType = function(user)
    local entity = user.SeleneEntity
    local monsterDef = entity:getCustomData(DataKeys.Monster)
    if monsterDef then
        return monsterDef:getMetadata("id")
    end
    return 0
end

Character.SeleneMethods.getLoot = function(user)
    local monsterDef = user:getCustomData(DataKeys.Monster)
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