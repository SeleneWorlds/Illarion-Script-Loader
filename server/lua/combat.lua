local Network = require("selene.network")
local Schedules = require("selene.schedules")
local Players = require("selene.players")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")
local CombatManager = require("illarion-script-loader.server.lua.lib.combatManager")

Network.handlePayload("illarion:set_combat_target", function(player, payload)
    local networkId = PayloadValidation.integer(payload.networkId, -1)
    if not networkId then
        return
    end
    local user = Character.fromSelenePlayer(player)
    user:abortAction()
    if networkId == -1 then
        user:stopAttack()
        return
    end
    local target = PayloadValidation.characterInRange(player, networkId, 14)
    if target and target.SeleneEntity ~= user.SeleneEntity then
        CombatManager.SetAttackTarget(user, target)
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
