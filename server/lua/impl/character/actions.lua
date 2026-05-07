local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ActionManager = require("illarion-script-loader.server.lua.lib.actionManager")

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

    local actionHandle = Schedules.setTimeout(duration, function()
        local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
        if currentAction and type(currentAction.Function) == "function" and currentAction.Args then
            pcall(currentAction.Function, table.unpack(currentAction.Args), Action.success)
        end
        ActionManager.ClearAction(user)
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
        entity:removeRuntimeData(DataKeys.CurrentAction)
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
     if currentAction and type(currentAction.Function) == "function" then
         pcall(currentAction.Function, table.unpack(currentAction.Args), Action.success)
     end

    ActionManager.ClearAction(user)
end

Character.SeleneMethods.abortAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    if currentAction and type(currentAction.Function) == "function" then
        pcall(currentAction.Function, table.unpack(currentAction.Args), Action.abort)
    end

    ActionManager.ClearAction(user)
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
    local item = Registries.findByMetadata("illarion:items", "id", itemId)
    if item == nil then
        error("changeSource target tile is missing item definition")
    end
    local scriptName = item:getField("script")
    if item == nil then
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
    -- action.Args = { user, item }
    action.Args = { 1, 2 }
end
