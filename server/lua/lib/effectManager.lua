local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

function m.WrapLongTimeEffect(def, entity, data)
    return setmetatable({SeleneEffectDefinition = def, SeleneEntity = entity, SeleneEffectData = data}, LongTimeEffect.SeleneMetatable)
end

function m.EnsureSeleneEffectData(effect)
    local data = effect.SeleneEffectData
    if not data then
        data = tablex.managed({})
        effect.SeleneEffectData = data
    end
    return data
end

function m.AddEffect(user, effect)
    local found, existing = user.effects:find(effect.id)
    if found then
        local status, effectScript = pcall(require, effectScriptName)
        if status and effectScript and type(effectScript.doubleEffect) == "function" then
            effectScript.doubleEffect(existing, user)
        end
    else
        local effectScriptName = effect.SeleneEffectDefinition:GetField("script")
        local status, effectScript = pcall(require, effectScriptName)
        local data = m.EnsureSeleneEffectData(effect)
        if status and effectScript and type(effectScript.addEffect) == "function" and not data.addEffectCalled then
            effectScript.addEffect(effect, user)
        end
        data.addEffectCalled = true
        local effects = user.SeleneEntity.CustomData[DataKeys.Effects] or tablex.managed({})
        effects[effect.SeleneEffectDefinition.Name] = data
        user.SeleneEntity.CustomData[DataKeys.Effects] = effects
    end
end

function m.FindEffect(user, idOrName)
    local effects = user.SeleneEntity.CustomData[DataKeys.Effects] or {}
    local effectDef = nil
    if type(idOrName) == "number" then
        effectDef = Registries.FindByMetadata("illarion:effects", "id", idOrName)
    elseif type(idOrName) == "string" then
        effectDef = Registries.FindByMetadata("illarion:effects", "name", idOrName)
    end
    if effectDef and effects[effectDef.Name] then
        return true, m.WrapLongTimeEffect(effectDef, user.SeleneEntity, effects[effectDef.Name])
    end
    return false, nil
end

function m.RemoveEffect(user, effect)
   local effects = user.SeleneEntity.CustomData[DataKeys.Effects] or tablex.managed({})
   local effectDef = Registries.FindByMetadata("illarion:effects", "id", effect.id)
   if effectDef then
       local effectScriptName = effectDef:GetField("script")
       local status, effectScript = pcall(require, effectScriptName)
       if status and effectScript and type(effectScript.removeEffect) == "function" then
           effectScript.removeEffect(effect, user)
       end
   end
   effects[effectDef.Name] = nil
   user.SeleneEntity.CustomData[DataKeys.Effects] = effects
   return true
end

return m
