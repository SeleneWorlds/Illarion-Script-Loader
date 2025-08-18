local Registries = require("selene.registries")
local illaInterface = require("illarion-api.server.lua.interface")

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

illaInterface.LTE.Create = function(id, nextCalled)
    local effectDef = Registries.FindByMetadata("illarion:lte", "id", tostring(id))
    if effectDef == nil then
        print("No such effect " .. id) -- TODO throw an error
        return nil
    end
    local effect = WrapLongTimeEffect(effectDef)
    effect.nextCalled = nextCalled
    return effect
end

illaInterface.LTE.SetNextCalled = function(effect, value)
    local data = EnsureSeleneEffectData(effect)
    data.nextCalled = value
end

illaInterface.LTE.GetNextCalled = function(effect)
    return effect.SeleneEffectData and effect.SeleneEffectData.nextCalled or 0
end

illaInterface.LTE.GetNumberCalled = function(effect)
    return effect.SeleneEffectData and effect.SeleneEffectData.numberCalled or 0
end

illaInterface.LTE.AddValue = function(effect, key, value)
    local data = EnsureSeleneEffectData(effect)
    if not data.values then
        data.values = {}
    end
    data.values[key] = value
end

illaInterface.LTE.FindValue = function(effect, key)
    local data = effect.SeleneEffectData
    if data and data.values and data.values[key] then
        return true, data.values[key]
    end
    return false, nil
end

illaInterface.LTE.RemoveValue = function(effect, key)
    local data = effect.SeleneEffectData
    if data and data.values then
        data.values[key] = nil
    end
end

illaInterface.LTE.AddEffect = function(user, effect)
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
        local effects = user.SeleneEntity():GetCustomData("Effects", {})
        effects[effect.SeleneEffectDefinition.Name] = data
    end
end

illaInterface.LTE.FindEffect = function(user, idOrName)
    local effects = user.SeleneEntity():GetCustomData("Effects", {})
    local effectDef = nil
    if type(idOrName) == "number" then
        effectDef = Registries.FindByMetadata("illarion:lte", "id", tostring(idOrName))
    elseif type(idOrName) == "string" then
        effectDef = Registries.FindByMetadata("illarion:lte", "name", idOrName)
    end
    if effectDef and effects[effectDef.Name] then
        return true, WrapLongTimeEffect(effectDef, user.SeleneEntity(), effects[effectDef.Name])
    end
    return false, nil
end

illaInterface.LTE.RemoveEffect = function(user, effect)
   local effect = idOrNameOrEffect
   if type(idOrNameOrEffect) == "number" or type(idOrNameOrEffect) == "string" then
       effect = self:find(idOrNameOrEffect)
   end
   if effect then
       local effects = user.SeleneEntity():GetCustomData("Effects", {})
       local effectDef = Registries.FindByMetadata("illarion:lte", "id", tostring(effect.id))
       if effectDef then
           local effectScriptName = effectDef:GetMetadata("script")
           local status, effectScript = pcall(require, effectScriptName)
           if status and effectScript and type(effectScript.removeEffect) == "function" then
               effectScript.removeEffect(effect, user)
           end
       end
       effects[idOrNameOrEffect] = nil
       return true
   end
   return false
end