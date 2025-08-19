local Interface = require("illarion-api.server.lua.interface")

Interface.Movement.GetMovePoints = function(user)
    print("GetMovePoints", user.name)
    return 0
end

Interface.Movement.SetMovePoints = function(user, value)
    print("SetMovePoints", user.name, value)
end

Interface.Movement.GetSpeed = function(user)
    print("GetSpeed", user.name)
    return 0
end

Interface.Movement.SetSpeed = function(user, value)
    print("SetSpeed", user.name, value)
end