local Interface = require("illarion-api.server.lua.interface")

local illaFighting = require("server.standardfighting")

Interface.Combat.IsInCombat = function(user)
    print("IsInCombat", user.name)
    return false
end

Interface.Combat.StopCombat = function(user)
    print("StopCombat", user.name)
end

Interface.Combat.GetTarget = function(user)
    print("GetTarget", user.name)
    return nil
end

Interface.Combat.GetFightPoints = function(user)
    print("GetFightPoints", user.name)
    return 0
end

Interface.Combat.SetFightPoints = function(user, value)
    print("SetFightPoints", user.name, value)
end

Interface.Combat.CallAttackScript = function(attacker, defender)
    local weaponId = attacker:GetItemAt(Character.right_tool).id
    -- TODO look weapon up in registry
    -- TODO call "onAttack" entrypoint in weapon script if exists

    illaFighting.onAttack(attacker, defender)
end
