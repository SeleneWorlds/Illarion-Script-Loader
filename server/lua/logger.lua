local Interface = require("illarion-api.server.lua.interface")

Interface.Logger.Log = function(message)
    print("[Log] " .. message)
end

Interface.Logger.LogDebug = function(message)
    print("[Debug] " .. message)
end

Interface.Logger.LogError = function(message)
    print("[Error] " .. message)
end