local Registries = require("selene.registries")
local Schedules = require("selene.schedules")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ActionManager = require("illarion-script-loader.server.lua.lib.actionManager")

local function callActionFunction(actionFunction, actionArgs, actionState)
    local argumentCount = actionArgs.n or #actionArgs
    local args = table.pack(table.unpack(actionArgs, 1, argumentCount))
    args.n = argumentCount + 1
    args[args.n] = actionState
    pcall(actionFunction, table.unpack(args, 1, args.n))
end

Character.SeleneMethods.startAction = function(user, duration, gfxId, gfxInterval, sfxId, sfxInterval)
    local entity = user.SeleneEntity
    local gfxHandle = nil
    local sfxHandle = nil
    if gfxId ~= 0 then
        gfxHandle = Schedules.setInterval(100, function()
            world:gfx(gfxId, user)
        end, { immediate = true })
    end
    if sfxId ~= 0 then
        sfxHandle = Schedules.setInterval(100, function()
            world:makeSound(sfxId, user.pos)
        end, { immediate = true })
    end

    -- Duration is in deciseconds for whatever reason
    local actionHandle = Schedules.setTimeout(duration * 100, function()
        local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
        if currentAction and type(currentAction.Function) == "function" and currentAction.Args then
            local actionFunction = currentAction.Function
            local actionArgs = currentAction.Args
            ActionManager.ClearAction(user)
            callActionFunction(actionFunction, actionArgs, Action.success)
        else
            ActionManager.ClearAction(user)
        end
    end)
    local action = entity:getRuntimeData(DataKeys.CurrentAction)
    local lastAction = entity:getRuntimeData(DataKeys.LastAction)
    action.Script = lastAction[DataFields.LastActionScript]
    action.Function = lastAction[DataFields.LastActionFunction]
    action.Args = lastAction[DataFields.LastActionArgs]
    action.ActionHandle = actionHandle
    action.GfxHandle = gfxHandle
    action.SfxHandle = sfxHandle
end

Character.SeleneMethods.disturbAction = function(user, disturber)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local shouldAbort = false
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    if currentAction and currentAction.Script and type(currentAction.Script.actionDisturbed) == "function" then
        shouldAbort = currentAction.Script.actionDisturbed(user, disturber)
    end

    if shouldAbort then
        user:abortAction()
        return true
    end

    return false
end

Character.SeleneMethods.successAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    local actionFunction = currentAction and currentAction.Function
    local actionArgs = currentAction and currentAction.Args
    ActionManager.ClearAction(user)
    if type(actionFunction) == "function" and actionArgs then
        callActionFunction(actionFunction, actionArgs, Action.success)
    end
end

Character.SeleneMethods.abortAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    local actionFunction = currentAction and currentAction.Function
    local actionArgs = currentAction and currentAction.Args
    ActionManager.ClearAction(user)
    if type(actionFunction) == "function" and actionArgs then
        callActionFunction(actionFunction, actionArgs, Action.abort)
    end
end

Character.SeleneMethods.isActionRunning = function(user)
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    return currentAction and currentAction.ActionHandle ~= nil
end

Character.SeleneMethods.changeSource = function(user, item)
    local entity = user.SeleneEntity
    local itemId = item.SeleneTile:getMetadata("itemId")
    if itemId == nil then
        error("changeSource target tile does not have an item id")
    end
    local itemDefinition = Registries.findByMetadata("illarion:items", "id", itemId)
    if itemDefinition == nil then
        error("changeSource target tile is missing item definition")
    end
    local scriptName = itemDefinition:getField("script")
    if scriptName == nil then
        error("changeSource target item does not have a script")
    end
    local status, script = pcall(require, scriptName)
    if not status then
        error("changeSource target item script failed to load")
    end
    if type(script.UseItem) ~= "function" then
        error("changeSource target item script has no UseItem function")
    end
    local action = entity:getRuntimeData(DataKeys.CurrentAction)
    action.Script = script
    action.Function = script.UseItem
    if Config.getProperty("useLegacyUseItem") == "true" then
        action.Args = table.pack(user, item, nil, nil, nil)
    else
        action.Args = { user, item }
    end
end
