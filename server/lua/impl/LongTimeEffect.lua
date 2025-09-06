local Registries = require("selene.registries")

local EffectManager = require("illarion-script-loader.server.lua.lib.effectManager")

LongTimeEffect.SeleneConstructor = function(id, nextCalled)
    local effectDef = Registries.FindByMetadata("illarion:effects", "id", id)
    if effectDef == nil then
        error("No such effect " .. id)
    end
    local effect = EffectManager.WrapLongTimeEffect(effectDef)
    effect.nextCalled = nextCalled
    return effect
end

LongTimeEffect.SeleneSetters.nextCalled = function(effect, value)
    local data = EffectManager.EnsureSeleneEffectData(effect)
    data.nextCalled = value
end

LongTimeEffect.SeleneGetters.effectId = function(effect)
    return tonumber(effect.SeleneEffectDefinition:GetMetadata("id"))
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
    local data = EffectManager.EnsureSeleneEffectData(effect)
    if not data.values then
        data.values = tablex.observable({})
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