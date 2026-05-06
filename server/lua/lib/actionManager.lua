local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

function m.ClearAction(character)
    local entity = character.SeleneEntity
    local action = entity:getCustomData(DataKeys.CurrentAction) or {}
     if action.ActionHandle then
         Schedules.clearTimeout(action.ActionHandle)
     end
     if action.GfxHandle then
         Schedules.clearInterval(action.GfxHandle)
     end
     if action.SfxHandle then
         Schedules.clearInterval(action.SfxHandle)
     end
    entity:setCustomData(DataKeys.CurrentAction, nil)
end

return m