local Registries = require("selene.registries")
local Network = require("selene.network")
local Entities = require("selene.entities")
local Players = require("selene.players")
local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

Character.SeleneMethods.stopAttack = function(user)
    user.SeleneEntity.CustomData[DataKeys.CombatTarget] = nil
    Network.SendToEntity(user.SeleneEntity, "illarion:set_combat_target", {
        networkId = -1
    })
end

local function SetAttackTarget(user, target)
    local currentTargetId = user.SeleneEntity.CustomData[DataKeys.CombatTarget]
    local newTargetId = target.SeleneEntity.NetworkId
    if currentTargetId == newTargetId then
        return
    end

    user.SeleneEntity.CustomData[DataKeys.CombatTarget] = newTargetId
end

Character.SeleneMethods.getAttackTarget = function(user)
    local networkId = user.SeleneEntity.CustomData[DataKeys.CombatTarget]
    if networkId then
        return Entities.GetEntityById(networkId)
    end
    return nil
end

Character.SeleneGetters.attackmode = function(user)
    return user.SeleneEntity.CustomData[DataKeys.CombatTarget] ~= nil
end

Character.SeleneMethods.callAttackScript = function(attacker, defender)
    local weaponId = attacker:GetItemAt(Character.right_tool).id
    local itemDef = Registries.FindByMetadata("illarion:items", "id", weaponId)
    if itemDef then
        local weapon = itemDef:GetField("weapon")
        if weapon and weapon.fightingScript then
            local status, script = pcall(require, weapon.fightingScript)
            if status and type(script.onAttack) == "function" then
                script.onAttack(attacker, defender)
            end
        end
    end

    require("server.standardfighting").onAttack(attacker, defender)
end

Character.SeleneGetters.fightpoints = function(user)
    return AttributeManager.GetAttribute(user, "fightpoints").EffectiveValue
end

Character.SeleneSetters.fightpoints = function(user, value)
    AttributeManager.GetAttribute(user, "fightpoints").Value = value
end

Network.HandlePayload("illarion:set_combat_target", function(player, payload)
    local entity = Entities.GetEntityById(payload.networkId)
    if entity then
        SetAttackTarget(user, entity)
    end
end)

Schedules.SetInterval(100, function()
    local players = Players.GetOnlinePlayers()
    for _, player in ipairs(players) do
        if player.ControlledEntity then
            local user = Character.fromSelenePlayer(player)
            user.movepoints = user.movepoints + 1
            user.fightpoints = user.fightpoints + 1
        end
    end
end)