Character.SeleneMethods.callAttackScript = function(attacker, defender)
    local weaponId = attacker:GetItemAt(Character.right_tool).id
    -- TODO look weapon up in registry
    -- TODO call "onAttack" entrypoint in weapon script if exists

    require("server.standardfighting").onAttack(attacker, defender)
end
