local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

function m.SetAttackTarget(user, target)
    local combatData = user.SeleneEntity:getRuntimeData(DataKeys.Combat)
    local currentTargetId = combatData[DataFields.TargetId]
    local newTargetId = target.SeleneEntity:getNetworkId()
    if currentTargetId == newTargetId then
        return
    end

    combatData[DataFields.TargetId] = newTargetId
end

return m