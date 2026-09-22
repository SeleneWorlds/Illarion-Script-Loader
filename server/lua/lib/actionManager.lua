local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

function m.ClearAction(character)
    local entity = character.SeleneEntity
    if not entity:hasRuntimeData(DataKeys.CurrentAction) then
        return
    end

    local action = entity:getRuntimeData(DataKeys.CurrentAction)
    if action.ActionHandle then
        Schedules.clearTimeout(action.ActionHandle)
    end
    if action.GfxHandle then
        Schedules.clearInterval(action.GfxHandle)
    end
    if action.SfxHandle then
        Schedules.clearInterval(action.SfxHandle)
    end
    entity:removeRuntimeData(DataKeys.CurrentAction)
end

function m.CallActionFunction(actionFunction, actionArgs, actionState)
    local argumentCount = actionArgs.n or #actionArgs
    local args = table.pack(table.unpack(actionArgs, 1, argumentCount))
    args.n = argumentCount + 1
    args[args.n] = actionState
    pcall(actionFunction, table.unpack(args, 1, args.n))
end

function m.AbortAction(character)
    local entity = character.SeleneEntity
    if not entity:hasRuntimeData(DataKeys.CurrentAction) then
        return false
    end

    local action = entity:getRuntimeData(DataKeys.CurrentAction)
    local actionFunction = action.Function
    local actionArgs = action.Args
    local wasRunning = action.ActionHandle ~= nil
    m.ClearAction(character)
    if type(actionFunction) == "function" and actionArgs then
        m.CallActionFunction(actionFunction, actionArgs, Action.abort)
    end
    return wasRunning
end

return m
