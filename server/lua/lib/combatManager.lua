local m = {}

function m.SetAttackTarget(user, target)
    local combatData = user.SeleneEntity:getRuntimeData(DataKeys.Combat)
    local currentTargetId = combatData[DataFields.TargetId]
    local newTargetId = target.SeleneEntity.NetworkId
    if currentTargetId == newTargetId then
        return
    end

    combatData[DataFields.TargetId] = newTargetId
end

return m