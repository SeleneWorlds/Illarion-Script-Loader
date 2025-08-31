local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

function m.ClearAction(character)
    local entity = character.SeleneEntity
    local action = entity.CustomData:RawLookup(DataKeys.CurrentAction) or {}
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

return m