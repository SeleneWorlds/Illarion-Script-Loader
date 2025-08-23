local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getMonsterType = function(user)
    local entity = user.SeleneEntity()
    return user:GetCustomData(DataKeys.MonsterType, 0)
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