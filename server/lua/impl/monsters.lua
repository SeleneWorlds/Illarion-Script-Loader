local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getMonsterType = function(user)
    local entity = user.SeleneEntity
    return user.CustomData[DataKeys.MonsterType] or 0
end

Character.SeleneMethods.getLoot = function(user)
    local monsterId = user:getMonsterType()
    local monsterDef = Registries.FindByMetadata("illarion:monsters", "id", monsterId)
    if monsterDef then
        -- TODO monsters.json missing loot right now
        error("Not yet implemented")
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
    entity:SetCoordinate(pos)
    entity:Spawn()
end