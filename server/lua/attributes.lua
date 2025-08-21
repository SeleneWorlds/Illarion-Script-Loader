local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Attributes.GetAttributeOffset = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.AttributeOffsets .. attribute, 0)
end

Interface.Attributes.SetAttributeOffset = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.AttributeOffsets .. attribute, value)
end

Interface.Attributes.GetBaseAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.BaseAttributes .. attribute, 0)
end

Interface.Attributes.SetBaseAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.BaseAttributes .. attribute, value)
end

Interface.Attributes.GetTransientBaseAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.TransientBaseAttributes .. attribute, 0)
end

Interface.Attributes.SetTransientBaseAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.TransientBaseAttributes .. attribute, value)
end

Interface.Attributes.ClampAttribute = function(user, attribute, value)
    local max = 0
    if attribute == "hitpoints" or attribute == "mana" then
        max = 10000
    elseif attribute == "food" then
        max = 60000
    elseif attribute == "strength" or attribute == "dexterity" or attribute == "constitution" or attribute == "agility" or attribute == "intelligence" or attribute == "essence" or attribute == "perception" or attribute == "willpower" then
        max = 255
    end
    return max ~= 0 and math.clamp(value, 0, max) or math.max(value, 0)
end

Interface.Attributes.IsBaseAttributeValid = function(user, attribute, value)
    local raceId = Interface.Character.GetRace(user)
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    if not race then
        return false
    end

    local titlecaseAttribute = attribute:gsub("^%l", string.upper, 1)
    local minValue = race:GetField("min" .. titlecaseAttribute)
    local maxValue = race:GetField("max" .. titlecaseAttribute)
    if not minValue or not maxValue then
        return false
    end

    return value >= minValue and value <= maxValue
end

Interface.Attributes.GetMaxAttributePoints = function(user)
    local raceId = Interface.Character.GetRace(user)
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    if not race then
        return 0
    end

    return race:GetField("maxAttributePoints")
end

Interface.Attributes.GetPoisonValue = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.PoisonValue, 0)
end

Interface.Attributes.SetPoisonValue = function(user, value)
    user.SeleneEntity():SetCustomData(DataKeys.PoisonValue, value)
end

Interface.Attributes.GetMentalCapacity = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.MentalCapacity, 0)
end

Interface.Attributes.SetMentalCapacity = function(user, value)
    user.SeleneEntity():SetCustomData(DataKeys.MentalCapacity, value)
end