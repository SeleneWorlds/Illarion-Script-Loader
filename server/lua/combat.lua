local Network = require("selene.network")
local Schedules = require("selene.schedules")
local Entities = require("selene.entities")
local Players = require("selene.players")

Network.handlePayload("illarion:set_combat_target", function(player, payload)
    local user = Character.fromSelenePlayer(player)
    user:abortAction()
    if payload.networkId == -1 then
        user:stopAttack()
        return
    end
    local entity = Entities.getByNetworkId(payload.networkId)
    if entity then
        CombatManager.SetAttackTarget(user, Character.fromSeleneEntity(entity))
    end
end)

Schedules.setInterval(100, function()
    local players = Players.getOnlinePlayers()
    for _, player in ipairs(players) do
        if player:getControlledEntity() then
            local user = Character.fromSelenePlayer(player)
            user.movepoints = user.movepoints + 1
            user.fightpoints = user.fightpoints + 1
        end
    end
end)
