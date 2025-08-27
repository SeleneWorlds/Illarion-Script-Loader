local Server = require("selene.server")

ScriptVars.find = function(self, key)
    local value = Server.CustomData[key]
    return value ~= nil, value
end

ScriptVars.set = function(self, key, value)
    Server.CustomData[key] = value
end

ScriptVars.remove = function(self, key)
    Server.CustomData[key] = nil
end

ScriptVars.save = function(self)
    print("scriptVars.save called - noop")
end