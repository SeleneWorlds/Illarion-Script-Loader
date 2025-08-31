local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local EffectManager = require("illarion-script-loader.server.lua.lib.effectManager")

Schedules.EverySecond:Connect(function()
    local players = world:getPlayersOnline()
    for _, player in pairs(players) do
        local entity = player.SeleneEntity
        if entity then
            local effects = entity.CustomData[DataKeys.Effects] or tablex.managed({})
            local removedEffects = {}
            for effectName, effectData in effects:Pairs() do
                effectData.nextCalled = (effectData.nextCalled or 0) - 1
                if effectData.nextCalled <= 0 then
                    effectData.numberCalled = (effectData.numberCalled or 0) + 1
                    local effectDef = Registries.FindByName("illarion:effects", tostring(effectName))
                    if effectDef then
                        local effectScriptName = effectDef:GetField("script")
                        local status, effectScript = pcall(require, effectScriptName)
                        if status and effectScript and type(effectScript.callEffect) == "function" then
                            local effect = EffectManager.WrapLongTimeEffect(effectDef, entity, effectData)
                            if not effectScript.callEffect(effect, player) then
                                table.insert(removedEffects, effectName)
                            end
                        else
                            print("Missing script for long time effect " .. effectName)
                            table.insert(removedEffects, effectName)
                        end
                    else
                        print("Unknown long time effect " .. effectName)
                        table.insert(removedEffects, effectName)
                    end
                end
            end
            for _, effectName in pairs(removedEffects) do
                effects[effectName] = nil
            end
            entity.CustomData[DataKeys.Effects] = effects
        end
    end
end)
