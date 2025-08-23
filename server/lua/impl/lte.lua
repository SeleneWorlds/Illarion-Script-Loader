local Registries = require("selene.registries")
local Schedules = require("selene.schedules")
local Players = require("selene.players")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local function WrapLongTimeEffect(def, entity, data)
    return setmetatable({SeleneEffectDefinition = def, SeleneEntity = entity, SeleneEffectData = data}, LongTimeEffectMT)
end

local function EnsureSeleneEffectData(effect)
    local data = effect.SeleneEffectData
    if not data then
        data = {}
        effect.SeleneEffectData = data
    end
    return data
end


local function AddEffect(user, effect)
    local found, existing = user.effects:find(effect.id)
    if found then
        local status, effectScript = pcall(require, effectScriptName)
        if status and effectScript and type(effectScript.doubleEffect) == "function" then
            effectScript.doubleEffect(existing, user)
        end
    else
        local effectScriptName = effect.SeleneEffectDefinition:GetMetadata("script")
        local status, effectScript = pcall(require, effectScriptName)
        local data = EnsureSeleneEffectData(effect)
        if status and effectScript and type(effectScript.addEffect) == "function" and not data.addEffectCalled then
            effectScript.addEffect(effect, user)
        end
        data.addEffectCalled = true
        local effects = user.SeleneEntity:GetCustomData(DataKeys.Effects, {})
        effects[effect.SeleneEffectDefinition.Name] = data
        user.SeleneEntity:SetCustomData(DataKeys.Effects, effects)
    end
end

local function FindEffect(user, idOrName)
    local effects = user.SeleneEntity:GetCustomData(DataKeys.Effects, {})
    local effectDef = nil
    if type(idOrName) == "number" then
        effectDef = Registries.FindByMetadata("illarion:effects", "id", idOrName)
    elseif type(idOrName) == "string" then
        effectDef = Registries.FindByMetadata("illarion:effects", "name", idOrName)
    end
    if effectDef and effects[effectDef.Name] then
        return true, WrapLongTimeEffect(effectDef, user.SeleneEntity, effects[effectDef.Name])
    end
    return false, nil
end

local function RemoveEffect(user, effect)
   local effects = user.SeleneEntity:GetCustomData(DataKeys.Effects, {})
   local effectDef = Registries.FindByMetadata("illarion:effects", "id", effect.id)
   if effectDef then
       local effectScriptName = effectDef:GetMetadata("script")
       local status, effectScript = pcall(require, effectScriptName)
       if status and effectScript and type(effectScript.removeEffect) == "function" then
           effectScript.removeEffect(effect, user)
       end
   end
   effects[effectDef.Name] = nil
   user.SeleneEntity:SetCustomData(DataKeys.Effects, effects)
   return true
end

Character.SeleneGetters.effects = function(user)
    return {
        addEffect = function(self, effect)
            return AddEffect(user, effect)
        end,
        find = function(self, idOrName)
            return FindEffect(user, idOrName)
        end,
        removeEffect = function(self, idOrNameOrEffect)
            local effect = idOrNameOrEffect
            if type(idOrNameOrEffect) == "number" or type(idOrNameOrEffect) == "string" then
                effect = self:find(idOrNameOrEffect)
            end
            if not effect then
                return false
            end
            return RemoveEffect(user, effect)
        end
    }
end

LongTimeEffect.SeleneConstructor = function(id, nextCalled)
    local effectDef = Registries.FindByMetadata("illarion:effects", "id", id)
    if effectDef == nil then
        error("No such effect " .. id)
    end
    local effect = WrapLongTimeEffect(effectDef)
    effect.nextCalled = nextCalled
    return effect
end

LongTimeEffect.SeleneSetters.nextCalled = function(effect, value)
    local data = EnsureSeleneEffectData(effect)
    data.nextCalled = value
end

LongTimeEffect.SeleneGetters.effectId = function(effect)
    return tonumber(effect.SeleneEffectDefinition:GetMetadata("lteId"))
end

LongTimeEffect.SeleneGetters.effectName = function(effect)
    return effect.SeleneEffectDefinition:GetMetadata("name")
end

LongTimeEffect.SeleneGetters.nextCalled = function(effect)
    return effect.SeleneEffectData and effect.SeleneEffectData.nextCalled or 0
end

LongTimeEffect.SeleneGetters.numberCalled = function(effect)
    return effect.SeleneEffectData and effect.SeleneEffectData.numberCalled or 0
end

LongTimeEffect.SeleneMethods.addValue = function(effect, key, value)
    local data = EnsureSeleneEffectData(effect)
    if not data.values then
        data.values = {}
    end
    data.values[key] = value
end

LongTimeEffect.SeleneMethods.findValue = function(effect, key)
    local data = effect.SeleneEffectData
    if data and data.values and data.values[key] then
        return true, data.values[key]
    end
    return false, 0
end

LongTimeEffect.SeleneMethods.removeValue = function(effect, key)
    local data = effect.SeleneEffectData
    if data and data.values then
        data.values[key] = nil
    end
end

Schedules.EverySecond:Connect(function()
    local players = world:getPlayersOnline()
    for _, player in pairs(players) do
        local entity = player.SeleneEntity
        if entity then
            local effects = entity:GetCustomData(DataKeys.Effects, {})
            local removedEffects = {}
            for effectName, effectData in pairs(effects) do
                effectData.nextCalled = (effectData.nextCalled or 0) - 1
                if effectData.nextCalled <= 0 then
                    effectData.numberCalled = (effectData.numberCalled or 0) + 1
                    local effectDef = Registries.FindByName("illarion:effects", tostring(effectName))
                    if effectDef then
                        local effectScriptName = effectDef:GetMetadata("script")
                        local status, effectScript = pcall(require, effectScriptName)
                        if status and effectScript and type(effectScript.callEffect) == "function" then
                            local effect = WrapLongTimeEffect(effectDef, entity, effectData)
                            if not effectScript.callEffect(effect, player) then
                                table.insert(removedEffects, effectName)
                            end
                        end
                    end
                end
            end
            for _, effectName in pairs(removedEffects) do
                effects[effectName] = nil
            end
            entity:SetCustomData(DataKeys.Effects, effects)
        end
    end
end)