local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
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

    m.Attack(user)
end

local function notifyMonsterAttacked(target, attacker)
    if target:getType() ~= Character.monster then
        return
    end

    local characterData = target.SeleneEntity:getRuntimeData(DataKeys.Character)
    local scriptName = characterData[DataFields.Script]
    if scriptName then
        local status, script = pcall(require, scriptName)
        if status and type(script.onAttacked) == "function" then
            script.onAttacked(target, attacker)
        end
    end
end

function m.Attack(user)
    if CharacterManager.IsDead(user) then
        user:stopAttack()
        return false
    end

    local target = user:getAttackTarget()
    if not target then
        return false
    end

    if CharacterManager.IsDead(target) then
        user:stopAttack()
        return false
    end

    if user.SeleneEntity:getDimension() ~= target.SeleneEntity:getDimension()
            or not user:isInRange(target, 14) then
        return false
    end

    notifyMonsterAttacked(target, user)
    if not user:isActionRunning() then
        user:callAttackScript(target)
    end

    if CharacterManager.IsDead(target) then
        user:stopAttack()
        if target:getType() == Character.player then
            target:stopAttack()
        end
        return false
    end

    return true
end

return m
