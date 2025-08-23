local Schedules = require("selene.schedules")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local function ClearAction(user)
    local entity = user.SeleneEntity()
    local action = entity:GetCustomData(DataKeys.CurrentAction, {})
     if action.ActionHandle then
         Schedules.ClearTimeout(action.ActionHandle)
     end
     if action.GfxHandle then
         Schedules.ClearInterval(action.GfxHandle)
     end
     if action.SfxHandle then
         Schedules.ClearInterval(action.SfxHandle)
     end
    entity:SetCustomData(DataKeys.CurrentAction, nil)
end

Character.SeleneMethods.startAction = function(user, duration, gfxId, gfxInterval, sfxId, sfxInterval)
    local entity = user.SeleneEntity()
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
        local func = entity:GetCustomData(DataKeys.LastActionFunction)
        local args = entity:GetCustomData(DataKeys.LastActionArgs)
        if type(func) == "function" and args then
            pcall(func, table.unpack(args), Action.success)
        end
        ClearAction(user)
    end)
    entity:SetCustomData(DataKeys.CurrentAction, {
        ActionHandle = actionHandle,
        GfxHandle = gfxHandle,
        SfxHandle = sfxHandle
    })
end

Character.SeleneMethods.disturbAction = function(user, disturber)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local shouldAbort = false
    local entity = user.SeleneEntity()
    local script = entity:GetCustomData(DataKeys.LastActionScript)
    if script and type(script.actionDisturbed) == "function" then
        shouldAbort = script.actionDisturbed(user, disturber)
        entity:SetCustomData(DataKeys.CurrentAction, nil)
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
    local entity = user.SeleneEntity()
    local func = entity:GetCustomData(DataKeys.LastActionFunction)
     if type(func) == "function" then
         pcall(func, table.unpack(args), Action.success)
     end

    ClearAction(user)
end

Character.SeleneMethods.abortAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local entity = user.SeleneEntity()
    local func = entity:GetCustomData(DataKeys.LastActionFunction)
    if type(func) == "function" then
        pcall(func, table.unpack(args), Action.abort)
    end

    ClearAction(user)
end

Character.SeleneMethods.isActionRunning = function(user)
    local entity = user.SeleneEntity()
    return entity:GetCustomData(DataKeys.CurrentAction) ~= nil
end
