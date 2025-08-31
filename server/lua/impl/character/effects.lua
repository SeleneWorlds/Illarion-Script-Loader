local EffectManager = require("illarion-script-loader.server.lua.lib.effectManager")

Character.SeleneGetters.effects = function(user)
    return {
        addEffect = function(self, effect)
            return EffectManager.AddEffect(user, effect)
        end,
        find = function(self, idOrName)
            return EffectManager.FindEffect(user, idOrName)
        end,
        removeEffect = function(self, idOrNameOrEffect)
            local effect = idOrNameOrEffect
            if type(idOrNameOrEffect) == "number" or type(idOrNameOrEffect) == "string" then
                effect = self:find(idOrNameOrEffect)
            end
            if not effect then
                return false
            end
            return EffectManager.RemoveEffect(user, effect)
        end
    }
end
