local Registries = require("selene.registries")
local Network = require("selene.network")
local Entities = require("selene.entities")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local CombatManager = require("illarion-script-loader.server.lua.lib.combatManager")

Character.SeleneMethods.stopAttack = function(user)
    user.SeleneEntity.CustomData[DataKeys.CombatTarget] = nil
    Network.SendToEntity(user.SeleneEntity, "illarion:set_combat_target", {
        networkId = -1
    })
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
