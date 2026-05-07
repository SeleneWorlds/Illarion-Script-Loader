local Server = require("selene.server")
local Saves = require("selene.saves")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local scriptVars = Server.getRuntimeData(DataKeys.ScriptVars)

ScriptVars.find = function(self, key)
    local value = scriptVars[key]
    return value ~= nil, value
end

ScriptVars.set = function(self, key, value)
    scriptVars[key] = value
end

ScriptVars.remove = function(self, key)
    scriptVars[key] = nil
end

ScriptVars.save = function(self)
    Saves.Save(scriptVars, SCRIPT_VARS_SAVE_PATH)
end

local SCRIPT_VARS_SAVE_PATH = "scriptvars.json"
if Saves.has(SCRIPT_VARS_SAVE_PATH) then
    local loaded = Saves.loadTable(SCRIPT_VARS_SAVE_PATH)
    if not loaded then
        return
    end

    for k,v in pairs(loaded) do
        scriptVars[k] = v
    end
end