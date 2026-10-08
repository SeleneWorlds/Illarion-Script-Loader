local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

local function loadEffectScript(def)
    if def:getField("enabled") == false then
        return false, nil
    end
    return xpcall(require, def:getField("script"))
end

function m.WrapLongTimeEffect(def, entity, data)
    return setmetatable({SeleneEffectDefinition = def, SeleneEntity = entity, SeleneEffectData = data}, LongTimeEffect.SeleneMetatable)
end

function m.EnsureSeleneEffectData(effect)
    local data = effect.SeleneEffectData
    if not data then
        data = tablex.observable({})
        effect.SeleneEffectData = data
    end
    return data
end

function m.AddEffect(user, effect)
    local found, existing = user.effects:find(effect.id)
    if found then
        local status, effectScript = loadEffectScript(effect.SeleneEffectDefinition)
        if status and effectScript and type(effectScript.doubleEffect) == "function" then
            effectScript.doubleEffect(existing, user)
        end
    else
        local status, effectScript = loadEffectScript(effect.SeleneEffectDefinition)
        local data = m.EnsureSeleneEffectData(effect)
        if status and effectScript and type(effectScript.addEffect) == "function" and not data.addEffectCalled then
            effectScript.addEffect(effect, user)
        end
        data.addEffectCalled = true
        local effects = user.SeleneEntity:getRuntimeData(DataKeys.Effects)
        effects[effect.SeleneEffectDefinition:getName()] = data
    end
end

function m.Tick(user)
    local entity = user.SeleneEntity
    local effects = entity:getRuntimeData(DataKeys.Effects)
    local removedEffects = {}
    for effectName, effectData in pairs(effects) do
        effectData.nextCalled = (effectData.nextCalled or 0) - 1
        if effectData.nextCalled <= 0 then
            effectData.numberCalled = (effectData.numberCalled or 0) + 1
            local effectDef = Registries.findByName("illarion:ltes", tostring(effectName))
            if effectDef and effectDef:getField("enabled") == false then
                -- Keep disabled effects without invoking their scripts.
            elseif effectDef then
                local status, effectScript = loadEffectScript(effectDef)
                if status and effectScript and type(effectScript.callEffect) == "function" then
                    local effect = m.WrapLongTimeEffect(effectDef, entity, effectData)
                    if not effectScript.callEffect(effect, user) then
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
end

function m.FindEffect(user, idOrName)
    local effects = user.SeleneEntity:getRuntimeData(DataKeys.Effects)
    local effectDef = nil
    if type(idOrName) == "number" then
        effectDef = Registries.findByMetadata("illarion:ltes", "id", idOrName)
    elseif type(idOrName) == "string" then
        effectDef = Registries.findByMetadata("illarion:ltes", "name", idOrName)
    end
    if effectDef and effects[effectDef:getName()] then
        return true, m.WrapLongTimeEffect(effectDef, user.SeleneEntity, effects[effectDef:getName()])
    end
    return false, nil
end

function m.RemoveEffect(user, effect)
   local effects = user.SeleneEntity:getRuntimeData(DataKeys.Effects)
   local effectDef = Registries.findByMetadata("illarion:ltes", "id", effect.id)
   if effectDef then
       local status, effectScript = loadEffectScript(effectDef)
       if status and effectScript and type(effectScript.removeEffect) == "function" then
           effectScript.removeEffect(effect, user)
       end
   end
   effects[effectDef:getName()] = nil
   return true
end

return m
