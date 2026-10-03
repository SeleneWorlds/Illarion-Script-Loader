local Schedules = require("selene.schedules")
local Entities = require("selene.entities")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local EffectManager = require("illarion-script-loader.server.lua.lib.effectManager")

Schedules.everySecond:connect(function()
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.player or not charData[DataFields.Dead] then
            EffectManager.Tick(Character.fromSeleneEntity(entity))
        end
    end
end)
