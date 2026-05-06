local m = {}

function m.SetAttackTarget(user, target)
    local currentTargetId = user.SeleneEntity:getCustomData(DataKeys.CombatTarget)
    local newTargetId = target.SeleneEntity.NetworkId
    if currentTargetId == newTargetId then
        return
    end

    user.SeleneEntity:setCustomData(DataKeys.CombatTarget, newTargetId)
end

return m