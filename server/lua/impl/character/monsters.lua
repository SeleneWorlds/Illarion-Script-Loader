local Registries = require("selene.registries")
local Rolls = require("moonlight-rolls.server.lua.rolls")

local roller = Rolls:new()
roller:registerType("nothing", function() end)
roller:registerType("item", function(entry)
    local item = entry.data
    local itemDef = Registries.findByName("illarion:items", item.item)
    assert(itemDef, "Unknown loot item " .. tostring(item.item))
    return {
        itemId = itemDef:getMetadata("id"),
        probability = 1,
        minAmount = item.count.min,
        maxAmount = item.count.max,
        minQuality = item.quality.min,
        maxQuality = item.quality.max,
        minDurability = item.durability.min,
        maxDurability = item.durability.max,
        data = item.data or {}
    }
end)

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
    local monsterDef = user.SeleneCharacterData[DataFields.Monster]
    local loot = {}
    if monsterDef then
        local drops = monsterDef:getField("drops")
        if drops then
            for _, result in ipairs(roller:roll(drops)) do
                if result.value then loot[#loot + 1] = { result.value } end
            end
        end
    end
    return loot
end
