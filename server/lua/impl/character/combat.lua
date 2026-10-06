local Registries = require("selene.registries")
local Network = require("selene.network")
local Entities = require("selene.entities")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local CombatManager = require("illarion-script-loader.server.lua.lib.combatManager")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local useLegacyDualHandCombat = Config.getProperty("useLegacyDualHandCombat") == "true"

Character.SeleneMethods.stopAttack = function(user)
    user.SeleneEntity:removeRuntimeData(DataKeys.Combat)
    Network.sendToEntity(user.SeleneEntity, "illarion:set_combat_target", {
        networkId = -1
    })
end

Character.SeleneMethods.getAttackTarget = function(user)
    local combatData = user.SeleneEntity:getRuntimeData(DataKeys.Combat)
    local networkId = combatData[DataFields.TargetId]
    if networkId then
        local entity = Entities.getByNetworkId(networkId)
        if entity and entity:getRuntimeData(DataKeys.Character)[DataFields.CharacterType] then
            return Character.fromSeleneEntity(entity)
        end
    end
    return nil
end

Character.SeleneGetters.attackmode = function(user)
    local combatData = user.SeleneEntity:getRuntimeData(DataKeys.Combat)
    return combatData[DataFields.TargetId] ~= nil
end

local function callWeaponScript(attacker, defender, attackPosition)
    local weaponId = attacker:getItemAt(attackPosition).id
    local itemDef = Registries.findByMetadata("illarion:items", "id", weaponId)
    if itemDef then
        local weapon = itemDef:getField("weapon")
        if weapon and weapon.fightingScript and weapon.fightingScript ~= "" then
            local status, script = xpcall(require, weapon.fightingScript)
            if status and type(script.onAttack) == "function" then
                if useLegacyDualHandCombat then
                    script.onAttack(attacker, defender, attackPosition)
                else
                    script.onAttack(attacker, defender)
                end
                return true
            end
        end
    end
    return false
end

Character.SeleneMethods.callAttackScript = function(attacker, defender)
    local attackPositions = useLegacyDualHandCombat
        and { Character.right_tool, Character.left_tool }
        or { Character.right_tool }

    for _, attackPosition in ipairs(attackPositions) do
        local defenderIsPlayer = defender:getType() == Character.player
        local defenderHitpoints = defenderIsPlayer and defender:increaseAttrib("hitpoints", 0)

        if defenderIsPlayer then
            defender:disturbAction(attacker)
        end

        local weaponScriptCalled = callWeaponScript(attacker, defender, attackPosition)
        if useLegacyDualHandCombat then
            if not weaponScriptCalled then
                require("server.standardfighting").onAttack(attacker, defender, attackPosition)
            end
        else
            require("server.standardfighting").onAttack(attacker, defender)
        end

        if defenderIsPlayer
                and defenderHitpoints ~= 1
                and defender:increaseAttrib("hitpoints", 0) == 1 then
            CombatManager.StopFighting(defender)
        end

        if CharacterManager.IsDead(defender) then
            break
        end
    end
end

Character.SeleneGetters.fightpoints = function(user)
    return AttributeManager.GetAttribute(user, "fightpoints"):getEffectiveValue()
end

Character.SeleneSetters.fightpoints = function(user, value)
    AttributeManager.GetAttribute(user, "fightpoints"):setValue(value)
end
