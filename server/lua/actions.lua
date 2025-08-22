local Schedules = require("selene.schedules")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Actions.StartAction = function(user, duration, gfxId, gfxInterval, sfxId, sfxInterval)
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
        local script = entity:GetCustomData(DataKeys.LastActionScript)
        local args = entity:GetCustomData(DataKeys.LastActionArgs)
        if type(script) == "function" and args then
            script(table.unpack(args), Action.success)
        end
    end)
    entity:SetCustomData(DataKeys.CurrentAction, {
        ActionHandle = actionHandle,
        GfxHandle = gfxHandle,
        SfxHandle = sfxHandle
    })
end