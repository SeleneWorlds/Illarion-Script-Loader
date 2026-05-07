local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")

world.SeleneMethods.createMonster = function(world, monsterId, pos, movePoints)
    local monsterDef = Registries.findByMetadata("illarion:monsters", "id", monsterId)
    if not monsterDef then
         error("Unknown monster id " .. monsterId)
    end

    return MonsterManager.Spawn(monsterDef, pos)
end

world.SeleneMethods.getMonsterAttack = function(world, raceId)
    local race = Registries.findByMetadata("illarion:races", "id", raceId)
    local monsterAttack = race and race:getField("monsterAttack") or nil
    if monsterAttack then
        return true, {
            attackType = monsterAttack.attackType,
            attackValue = monsterAttack.attackValue,
            actionPointsLost = monsterAttack.actionPointsLost,
        }
    end
    return false, nil
end

world.SeleneMethods.getMonstersInRangeOf = function(world, pos, range)
    local dimension = Dimensions.getDefault()
    local entities = dimension:getEntitiesInRange(pos, range)
    local monsters = {}
    for _, entity in ipairs(entities) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.monster then
            table.insert(monsters, Character.fromSeleneEntity(entity))
        end
    end
    return monsters
end