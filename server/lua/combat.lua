local Interface = require("illarion-api.server.lua.interface")

local illaFighting = require("server.standardfighting")

Interface.Combat.CallAttackScript = function(attacker, defender)
    local weaponId = attacker:GetItemAt(Character.right_tool).id
    -- TODO look weapon up in registry
    -- TODO call "onAttack" entrypoint in weapon script if exists

    illaFighting.onAttack(attacker, defender)
end
