local Network = require("selene.network")
local Schedules = require("selene.schedules")
local Players = require("selene.players")
local Config = require("selene.config")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")
local CombatManager = require("illarion-script-loader.server.lua.lib.combatManager")

local useLegacyCombat = Config.getProperty("useLegacyCombat") == "true"

Network.handlePayload("illarion:set_combat_target", function(player, payload)
    local networkId = PayloadValidation.integer(payload.networkId, -1)
    if not networkId then
        return
    end
    local user = Character.fromSelenePlayer(player)
    if networkId == -1 then
        user:abortAction()
        user:stopAttack()
        return
    end
    local target = PayloadValidation.characterInRange(player, networkId, 14)
    if target and target:getType() ~= Character.npc and target.SeleneEntity ~= user.SeleneEntity then
        user:abortAction()
        CombatManager.SetAttackTarget(user, target)
    end
end)

Schedules.setInterval(100, function()
    local players = Players.getOnlinePlayers()
    for _, player in ipairs(players) do
        if player:getControlledEntity() then
            local user = Character.fromSelenePlayer(player)
            if not user.SeleneEntity:isMoving() then
                user.movepoints = user.movepoints + 1
            end
            user.fightpoints = user.fightpoints + 1
            local canAttack
            if useLegacyCombat then
                canAttack = user.movepoints >= 21
            else
                canAttack = user.fightpoints >= 0
            end
            if user.attackmode and canAttack then
                CombatManager.Attack(user)
            end
        end
    end
end)
