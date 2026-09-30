local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local Network = require("selene.network")

local m = {}

function m.SetAttackTarget(user, target)
    local combatData = user.SeleneEntity:getRuntimeData(DataKeys.Combat)
    local currentTargetId = combatData[DataFields.TargetId]
    local newTargetId = target.SeleneEntity:getNetworkId()
    if currentTargetId == newTargetId then
        return
    end

    combatData[DataFields.TargetId] = newTargetId
    Network.sendToEntity(user.SeleneEntity, "illarion:set_combat_target", {
        networkId = newTargetId
    })
end

return m
