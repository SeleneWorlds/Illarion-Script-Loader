local illaFighting = require("server.standardfighting")

Character.SeleneMethods.callAttackScript = function(attacker, defender)
    local weaponId = attacker:GetItemAt(Character.right_tool).id
    -- TODO look weapon up in registry
    -- TODO call "onAttack" entrypoint in weapon script if exists

    illaFighting.onAttack(attacker, defender)
end
