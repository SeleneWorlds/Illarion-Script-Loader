local Server = require("selene.server")
local Saves = require("selene.saves")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local SCRIPT_VARS_SAVE_PATH = "scriptvars.json"
local scriptVarsLoaded = false

local function getScriptVars()
    local scriptVars = Server.getCustomData(DataKeys.ScriptVars)
    if not scriptVars then
        scriptVars = tablex.observable({})
        Server.setCustomData(DataKeys.ScriptVars, scriptVars)
    end
    return scriptVars
end

local function loadScriptVars()
    if scriptVarsLoaded then
        return
    end

    scriptVarsLoaded = true
    if not Saves.has(SCRIPT_VARS_SAVE_PATH) then
        return
    end

    local loaded = Saves.load(SCRIPT_VARS_SAVE_PATH)
    if not loaded then
        return
    end

    Server.setCustomData(DataKeys.ScriptVars, loaded)
end

ScriptVars.find = function(self, key)
    loadScriptVars()
    local value = getScriptVars()[key]
    return value ~= nil, value
end

ScriptVars.set = function(self, key, value)
    loadScriptVars()
    getScriptVars()[key] = value
end

ScriptVars.remove = function(self, key)
    loadScriptVars()
    getScriptVars()[key] = nil
end

ScriptVars.save = function(self)
    loadScriptVars()
    Saves.Save(getScriptVars(), SCRIPT_VARS_SAVE_PATH)
end
