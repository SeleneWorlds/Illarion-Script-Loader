local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")

world.SeleneMethods.createMonster = function(world, monsterId, pos, movePoints)
    local monsterDef = Registries.FindByMetadata("illarion:monsters", "id", monsterId)
    if not monsterDef then
         error("Unknown monster id " .. monsterId)
    end

    return MonsterManager.Spawn(monsterDef, pos)
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