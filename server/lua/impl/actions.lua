local Registries = require("selene.registries")
local Schedules = require("selene.schedules")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local function ClearAction(user)
    local entity = user.SeleneEntity
    local action = entity.CustomData:Lookup(DataKeys.CurrentAction) or {}
     if action.ActionHandle then
         Schedules.ClearTimeout(action.ActionHandle)
     end
     if action.GfxHandle then
         Schedules.ClearInterval(action.GfxHandle)
     end
     if action.SfxHandle then
         Schedules.ClearInterval(action.SfxHandle)
     end
    entity.CustomData[DataKeys.CurrentAction] = nil
end

Character.SeleneMethods.startAction = function(user, duration, gfxId, gfxInterval, sfxId, sfxInterval)
    local entity = user.SeleneEntity
    local gfxHandle = nil
    local sfxHandle = nil
    if gfxId ~= 0 then
        gfxHandle = Schedules.SetInterval(100, function()
            world:gfx(gfxId, user)
        end, { immediate = true })
    end
    if sfxId ~= 0 then
        sfxHandle = Schedules.SetInterval(100, function()
            world:makeSound(sfxId, user.position)
        end, { immediate = true })
    end

    local actionHandle = Schedules.SetTimeout(duration, function()
        local func = entity.CustomData[DataKeys.LastActionFunction]
        local args = entity.CustomData:Lookup(DataKeys.LastActionArgs)
        if type(func) == "function" and args then
            pcall(func, table.unpack(args), Action.success)
        end
        ClearAction(user)
    end)
    entity.CustomData[DataKeys.CurrentAction] = {
        ActionHandle = actionHandle,
        GfxHandle = gfxHandle,
        SfxHandle = sfxHandle
    }
end

Character.SeleneMethods.disturbAction = function(user, disturber)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local shouldAbort = false
    local entity = user.SeleneEntity
    local script = entity.CustomData[DataKeys.LastActionScript]
    if script and type(script.actionDisturbed) == "function" then
        shouldAbort = script.actionDisturbed(user, disturber)
        entity.CustomData[DataKeys.CurrentAction] = nil
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
    local func = entity.CustomData[DataKeys.LastActionFunction]
     if type(func) == "function" then
         pcall(func, table.unpack(args), Action.success)
     end

    ClearAction(user)
end

Character.SeleneMethods.abortAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local entity = user.SeleneEntity
    local func = entity.CustomData[DataKeys.LastActionFunction]
    if type(func) == "function" then
        pcall(func, table.unpack(args), Action.abort)
    end

    ClearAction(user)
end

Character.SeleneMethods.isActionRunning = function(user)
    local entity = user.SeleneEntity
    return entity.CustomData[DataKeys.CurrentAction] ~= nil
end

Character.SeleneMethods.changeSource = function(user, item)
    local entity = user.SeleneEntity
    local itemId = item.SeleneTile:GetMetadata("itemId")
    if itemId == nil then
        error("changeSource target tile does not have an item id")
    end
    local item = Registries.FindByMetadata("illarion:items", "id", itemId)
    if item == nil then
        error("changeSource target tile is missing item definition")
    end
    local scriptName = item:GetField("script")
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
    entity.CustomData[DataKeys.LastActionScript] = script
    entity.CustomData[DataKeys.LastActionFunction] = script.UseItem
    entity.CustomData[DataKeys.LastActionArgs] = { user, item }
end